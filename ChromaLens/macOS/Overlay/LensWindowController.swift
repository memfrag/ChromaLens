//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import AppKit
import ColorVisionKit
import MetalKit
import SwiftUI

// MARK: - LensWindowController

/// Owns the lens windows and keeps them aligned to one content rect:
///
/// - a click-through render panel exactly over the filtered area,
/// - four interactive border strips around it (resize, and the visible outline),
/// - a toolbar panel above the lens (or below when there's no room).
///
/// When controls are hidden, only the render panel remains and draws a thin
/// non-interactive outline.
@MainActor final class LensWindowController: LensInteractionHandler {

    static let borderWidth: CGFloat = 6
    static let toolbarHeight: CGFloat = 34
    static let toolbarMinimumWidth: CGFloat = 380
    static let toolbarGap: CGFloat = 2

    let metalView: MTKView

    /// Called continuously while the lens is dragged or resized.
    var onGeometryChanged: ((CGRect) -> Void)?

    /// Called when a drag or resize ends.
    var onGeometryChangeEnded: ((CGRect) -> Void)?

    private(set) var contentRect: CGRect = .zero
    private(set) var isVisible = false

    var areControlsHidden = false {
        didSet {
            applyControlsVisibility()
        }
    }

    private let renderPanel = LensPanel(isInteractive: false)
    private let toolbarPanel = LensPanel(isInteractive: true)
    private let borderViews: [ResizeHandleView] = [
        ResizeHandleView(side: .top),
        ResizeHandleView(side: .bottom),
        ResizeHandleView(side: .left),
        ResizeHandleView(side: .right)
    ]
    private lazy var borderPanels: [LensPanel] = borderViews.map { view in
        let panel = LensPanel(isInteractive: true)
        panel.contentView = view
        return panel
    }

    private let renderContainer = NSView()
    private var interactionStartRect: CGRect?

    init<Overlay: View, Toolbar: View>(overlay: Overlay, toolbar: Toolbar) {
        metalView = MTKView(frame: .zero)

        renderContainer.wantsLayer = true
        renderContainer.layer?.borderColor = NSColor.white.withAlphaComponent(0.55).cgColor

        metalView.translatesAutoresizingMaskIntoConstraints = false
        renderContainer.addSubview(metalView)

        let overlayView = NSHostingView(rootView: overlay)
        // The overlay is often empty; don't let its SwiftUI size drive the
        // panel's size (it would collapse the lens to zero).
        overlayView.sizingOptions = []
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        renderContainer.addSubview(overlayView)

        NSLayoutConstraint.activate([
            metalView.leadingAnchor.constraint(equalTo: renderContainer.leadingAnchor),
            metalView.trailingAnchor.constraint(equalTo: renderContainer.trailingAnchor),
            metalView.topAnchor.constraint(equalTo: renderContainer.topAnchor),
            metalView.bottomAnchor.constraint(equalTo: renderContainer.bottomAnchor),
            overlayView.leadingAnchor.constraint(equalTo: renderContainer.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: renderContainer.trailingAnchor),
            overlayView.topAnchor.constraint(equalTo: renderContainer.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: renderContainer.bottomAnchor)
        ])
        renderPanel.contentView = renderContainer
        renderPanel.setAccessibilityLabel("ChromaLens lens")

        let toolbarView = FirstMouseHostingView(rootView: toolbar)
        toolbarView.sizingOptions = []
        toolbarPanel.contentView = toolbarView
        toolbarPanel.setAccessibilityLabel("ChromaLens lens controls")

        for view in borderViews {
            view.cornerLength = Self.borderWidth + 14
            view.handler = self
        }
    }

    // MARK: Visibility

    func show(contentRect rect: CGRect) {
        setContentRect(rect)
        isVisible = true
        renderPanel.orderFrontRegardless()
        applyControlsVisibility()
    }

    func hide() {
        isVisible = false
        renderPanel.orderOut(nil)
        toolbarPanel.orderOut(nil)
        for panel in borderPanels {
            panel.orderOut(nil)
        }
    }

    /// Re-orders the panels to the front, e.g. after a Space change.
    func bringToFront() {
        guard isVisible else {
            return
        }
        renderPanel.orderFrontRegardless()
        applyControlsVisibility()
    }

    /// The panels' window numbers, for diagnostics.
    var windowNumbers: [Int] {
        ([renderPanel, toolbarPanel] + borderPanels).map(\.windowNumber)
    }

    private func applyControlsVisibility() {
        renderContainer.layer?.borderWidth = areControlsHidden ? 1 : 0
        let showChrome = isVisible && !areControlsHidden
        for panel in borderPanels + [toolbarPanel] {
            if showChrome {
                panel.orderFrontRegardless()
            } else {
                panel.orderOut(nil)
            }
        }
    }

    // MARK: Layout

    func setContentRect(_ rect: CGRect) {
        contentRect = rect
        renderPanel.setFrame(rect, display: false)

        let border = Self.borderWidth
        let outer = rect.insetBy(dx: -border, dy: -border)
        let borderFrames = [
            CGRect(x: outer.minX, y: rect.maxY, width: outer.width, height: border),
            CGRect(x: outer.minX, y: outer.minY, width: outer.width, height: border),
            CGRect(x: outer.minX, y: rect.minY, width: border, height: rect.height),
            CGRect(x: rect.maxX, y: rect.minY, width: border, height: rect.height)
        ]
        for (panel, frame) in zip(borderPanels, borderFrames) {
            panel.setFrame(frame, display: false)
        }

        let visibleFrame = screen(for: rect)?.visibleFrame ?? outer
        let toolbarHeight = Self.toolbarHeight
        let toolbarWidth = max(outer.width, Self.toolbarMinimumWidth)
        let placement = LensGeometry.toolbarPlacement(
            outerFrame: outer,
            toolbarHeight: toolbarHeight + Self.toolbarGap,
            visibleFrame: visibleFrame
        )
        let toolbarY = switch placement {
        case .above: outer.maxY + Self.toolbarGap
        case .below: outer.minY - toolbarHeight - Self.toolbarGap
        }
        toolbarPanel.setFrame(
            CGRect(x: outer.minX, y: toolbarY, width: toolbarWidth, height: toolbarHeight),
            display: false
        )
    }

    private func screen(for rect: CGRect) -> NSScreen? {
        let screens = NSScreen.screens
        guard let index = LensGeometry.bestScreenIndex(for: rect, among: screens.map(\.frame)) else {
            return nil
        }
        return screens[index]
    }

    // MARK: LensInteractionHandler

    func interactionBegan() {
        interactionStartRect = contentRect
    }

    func dragMoved(by translation: CGVector) {
        guard let start = interactionStartRect else {
            return
        }
        updateDuringInteraction(LensGeometry.rounded(start.offsetBy(dx: translation.dx, dy: translation.dy)))
    }

    func resizeMoved(edges: LensGeometry.Edges, translation: CGVector) {
        guard let start = interactionStartRect else {
            return
        }
        updateDuringInteraction(LensGeometry.rounded(LensGeometry.resized(start, edges: edges, translation: translation)))
    }

    func interactionEnded() {
        guard interactionStartRect != nil else {
            return
        }
        interactionStartRect = nil
        onGeometryChangeEnded?(contentRect)
    }

    private func updateDuringInteraction(_ rect: CGRect) {
        guard rect != contentRect else {
            return
        }
        setContentRect(rect)
        onGeometryChanged?(rect)
    }
}
