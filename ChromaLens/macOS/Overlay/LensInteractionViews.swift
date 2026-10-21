//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import AppKit
import ColorVisionKit
import SwiftUI

// MARK: - LensInteractionHandler

/// Receives drag and resize gestures from the lens chrome. Positions are in
/// global screen coordinates (`NSEvent.mouseLocation`).
@MainActor protocol LensInteractionHandler: AnyObject {
    func interactionBegan()
    func dragMoved(by translation: CGVector)
    func resizeMoved(edges: LensGeometry.Edges, translation: CGVector)
    func interactionEnded()
}

// MARK: - DragHandleView

/// Moves the lens when dragged. Used as the toolbar background.
final class DragHandleView: NSView {

    weak var handler: LensInteractionHandler?
    private var startLocation: NSPoint?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        startLocation = NSEvent.mouseLocation
        handler?.interactionBegan()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startLocation else {
            return
        }
        let location = NSEvent.mouseLocation
        handler?.dragMoved(by: CGVector(dx: location.x - startLocation.x, dy: location.y - startLocation.y))
    }

    override func mouseUp(with event: NSEvent) {
        guard startLocation != nil else {
            return
        }
        startLocation = nil
        handler?.interactionEnded()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }
}

struct DragHandle: NSViewRepresentable {

    weak var handler: LensInteractionHandler?

    func makeNSView(context: Context) -> DragHandleView {
        let view = DragHandleView()
        view.handler = handler
        return view
    }

    func updateNSView(_ nsView: DragHandleView, context: Context) {
        nsView.handler = handler
    }
}

// MARK: - ResizeHandleView

/// One side of the interactive border ring. Its ends act as corner handles.
final class ResizeHandleView: NSView {

    /// The side of the lens this strip sits on.
    let side: LensGeometry.Edges

    weak var handler: LensInteractionHandler?

    /// Length of the corner zones at each end of the strip.
    var cornerLength: CGFloat = 18

    var fillColor: NSColor = .controlAccentColor.withAlphaComponent(0.85) {
        didSet {
            needsDisplay = true
        }
    }

    private var activeEdges: LensGeometry.Edges = []
    private var startLocation: NSPoint?
    private var trackingArea: NSTrackingArea?

    init(side: LensGeometry.Edges) {
        self.side = side
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        fillColor.setFill()
        bounds.fill()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        cursor(for: edges(at: convert(event.locationInWindow, from: nil))).set()
    }

    override func mouseMoved(with event: NSEvent) {
        cursor(for: edges(at: convert(event.locationInWindow, from: nil))).set()
    }

    override func mouseExited(with event: NSEvent) {
        if startLocation == nil {
            NSCursor.arrow.set()
        }
    }

    override func mouseDown(with event: NSEvent) {
        activeEdges = edges(at: convert(event.locationInWindow, from: nil))
        startLocation = NSEvent.mouseLocation
        handler?.interactionBegan()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startLocation else {
            return
        }
        let location = NSEvent.mouseLocation
        handler?.resizeMoved(
            edges: activeEdges,
            translation: CGVector(dx: location.x - startLocation.x, dy: location.y - startLocation.y)
        )
        cursor(for: activeEdges).set()
    }

    override func mouseUp(with event: NSEvent) {
        guard startLocation != nil else {
            return
        }
        startLocation = nil
        handler?.interactionEnded()
    }

    /// Edges affected by a press at `point`: the strip's side, plus the
    /// perpendicular side when pressed near an end.
    private func edges(at point: NSPoint) -> LensGeometry.Edges {
        var edges = side
        if side == .top || side == .bottom {
            if point.x < cornerLength {
                edges.insert(.left)
            } else if point.x > bounds.width - cornerLength {
                edges.insert(.right)
            }
        } else {
            if point.y < cornerLength {
                edges.insert(.bottom)
            } else if point.y > bounds.height - cornerLength {
                edges.insert(.top)
            }
        }
        return edges
    }

    private func cursor(for edges: LensGeometry.Edges) -> NSCursor {
        let position: NSCursor.FrameResizePosition
        switch edges {
        case [.top, .left]: position = .topLeft
        case [.top, .right]: position = .topRight
        case [.bottom, .left]: position = .bottomLeft
        case [.bottom, .right]: position = .bottomRight
        case .top: position = .top
        case .bottom: position = .bottom
        case .left: position = .left
        default: position = .right
        }
        return NSCursor.frameResize(position: position, directions: .all)
    }
}
