//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import CoreGraphics
import simd

// MARK: - LensGeometry

/// Pure geometry for the lens.
///
/// Coordinate spaces:
/// - **Global**: Cocoa screen coordinates in points, origin at the bottom-left
///   of the primary display, y up (`NSScreen.frame`, `NSWindow.frame`).
///   May be negative for displays left of / below the primary display.
/// - **Display-local**: points relative to one display, origin at its
///   top-left, y down. This is what `SCStreamConfiguration.sourceRect` uses.
/// - **UV**: normalized `0...1` coordinates in a captured texture, origin at
///   the top-left (first row of the pixel buffer).
///
public enum LensGeometry {

    /// Minimum size of the filtered lens area (spec L-02).
    public static let minimumContentSize = CGSize(width: 240, height: 160)

    /// Padding added around the lens on each side when capturing a region,
    /// as a fraction of the lens size.
    public static let defaultMarginFraction: CGFloat = 0.25

    // MARK: Coordinate Conversion

    /// Converts a global rect to display-local coordinates.
    public static func displayLocal(_ rect: CGRect, screenFrame: CGRect) -> CGRect {
        CGRect(
            x: rect.minX - screenFrame.minX,
            y: screenFrame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    /// Converts a display-local rect to global coordinates.
    public static func global(fromDisplayLocal rect: CGRect, screenFrame: CGRect) -> CGRect {
        CGRect(
            x: rect.minX + screenFrame.minX,
            y: screenFrame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    // MARK: Region Capture

    /// The display-local region to capture for a lens: the lens plus a margin
    /// on every side, clamped to the display and snapped outward to whole
    /// points. Returns `.zero` when the lens isn't on the display at all.
    public static func paddedCaptureRect(
        lensContent: CGRect,
        screenFrame: CGRect,
        marginFraction: CGFloat = defaultMarginFraction
    ) -> CGRect {
        let local = displayLocal(lensContent, screenFrame: screenFrame)
        let padded = local.insetBy(dx: -local.width * marginFraction, dy: -local.height * marginFraction)
        let bounds = CGRect(origin: .zero, size: screenFrame.size)
        let clipped = padded.intersection(bounds)
        guard !clipped.isNull, !clipped.isEmpty else {
            return .zero
        }
        return snappedOutward(clipped)
    }

    /// Whether the capture region should be updated for the current lens
    /// position: the lens left the captured region, came too close to an edge
    /// of it that isn't pinned to the display edge, or the region is much
    /// larger than needed.
    public static func needsReconfigure(
        lensContent: CGRect,
        capturedRect: CGRect,
        screenFrame: CGRect,
        marginFraction: CGFloat = defaultMarginFraction
    ) -> Bool {
        let bounds = CGRect(origin: .zero, size: screenFrame.size)
        let local = displayLocal(lensContent, screenFrame: screenFrame).intersection(bounds)
        guard !local.isNull, !local.isEmpty else {
            return false
        }
        guard !capturedRect.isEmpty, capturedRect.contains(local) else {
            return true
        }

        let thresholdX = local.width * marginFraction * 0.35
        let thresholdY = local.height * marginFraction * 0.35
        let tolerance: CGFloat = 0.5

        let left = local.minX - capturedRect.minX
        let right = capturedRect.maxX - local.maxX
        let top = local.minY - capturedRect.minY
        let bottom = capturedRect.maxY - local.maxY

        // An edge that's pinned to the display edge can't be extended, so a
        // small margin there is expected.
        let tooCloseToEdge = (left < thresholdX && capturedRect.minX > tolerance)
            || (right < thresholdX && capturedRect.maxX < bounds.maxX - tolerance)
            || (top < thresholdY && capturedRect.minY > tolerance)
            || (bottom < thresholdY && capturedRect.maxY < bounds.maxY - tolerance)

        let ideal = paddedCaptureRect(lensContent: lensContent, screenFrame: screenFrame, marginFraction: marginFraction)
        let wastefullyLarge = capturedRect.width > ideal.width * 1.6 || capturedRect.height > ideal.height * 1.6

        return tooCloseToEdge || wastefullyLarge
    }

    // MARK: Texture Crop

    /// Where the lens lies within a frame captured for `capturedRect`.
    public struct TextureCrop: Equatable, Sendable {
        public var uvOrigin: SIMD2<Float>
        public var uvSize: SIMD2<Float>

        /// Whether the whole lens is inside the captured texture. When `false`,
        /// the shader fills the uncovered part with a neutral hatch.
        public var isFullyCovered: Bool {
            uvOrigin.x >= -1e-4 && uvOrigin.y >= -1e-4
                && uvOrigin.x + uvSize.x <= 1 + 1e-4
                && uvOrigin.y + uvSize.y <= 1 + 1e-4
        }
    }

    /// The UV crop of the lens within a frame captured for `capturedRect`
    /// (display-local) on the display with `screenFrame`.
    public static func textureCrop(
        lensContent: CGRect,
        capturedRect: CGRect,
        screenFrame: CGRect
    ) -> TextureCrop {
        guard capturedRect.width > 0, capturedRect.height > 0 else {
            return TextureCrop(uvOrigin: SIMD2(2, 2), uvSize: .zero)
        }
        let local = displayLocal(lensContent, screenFrame: screenFrame)
        return TextureCrop(
            uvOrigin: SIMD2(
                Float((local.minX - capturedRect.minX) / capturedRect.width),
                Float((local.minY - capturedRect.minY) / capturedRect.height)
            ),
            uvSize: SIMD2(
                Float(local.width / capturedRect.width),
                Float(local.height / capturedRect.height)
            )
        )
    }

    // MARK: Displays

    /// Index of the screen with the largest intersection with `rect`, or
    /// `nil` if it intersects none.
    public static func bestScreenIndex(for rect: CGRect, among screenFrames: [CGRect]) -> Int? {
        var best: (index: Int, area: CGFloat)?
        for (index, frame) in screenFrames.enumerated() {
            let intersection = rect.intersection(frame)
            guard !intersection.isNull else {
                continue
            }
            let area = intersection.width * intersection.height
            if area > 0, area > (best?.area ?? 0) {
                best = (index, area)
            }
        }
        return best?.index
    }

    /// Moves (and if necessary shrinks) `rect` so it lies entirely within `bounds`.
    public static func clamp(_ rect: CGRect, to bounds: CGRect) -> CGRect {
        let width = min(rect.width, bounds.width)
        let height = min(rect.height, bounds.height)
        let x = min(max(rect.minX, bounds.minX), bounds.maxX - width)
        let y = min(max(rect.minY, bounds.minY), bounds.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// A rect of `size` (shrunk to fit if needed) centered in `bounds`.
    public static func centered(_ size: CGSize, in bounds: CGRect) -> CGRect {
        let width = min(size.width, bounds.width)
        let height = min(size.height, bounds.height)
        return rounded(CGRect(
            x: bounds.midX - width / 2,
            y: bounds.midY - height / 2,
            width: width,
            height: height
        ))
    }

    /// Rounds origin and size to whole points so lens pixels align with
    /// captured pixels on 1× and 2× displays.
    public static func rounded(_ rect: CGRect) -> CGRect {
        CGRect(
            x: rect.minX.rounded(),
            y: rect.minY.rounded(),
            width: rect.width.rounded(),
            height: rect.height.rounded()
        )
    }

    private static func snappedOutward(_ rect: CGRect) -> CGRect {
        let minX = rect.minX.rounded(.down)
        let minY = rect.minY.rounded(.down)
        let maxX = rect.maxX.rounded(.up)
        let maxY = rect.maxY.rounded(.up)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    // MARK: Resizing

    /// Edges being dragged during a resize.
    public struct Edges: OptionSet, Sendable, Hashable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let left = Edges(rawValue: 1 << 0)
        public static let right = Edges(rawValue: 1 << 1)
        public static let top = Edges(rawValue: 1 << 2)
        public static let bottom = Edges(rawValue: 1 << 3)
    }

    /// Resizes a global rect by dragging `edges` by `translation` (global,
    /// y up), keeping the opposite edges fixed and enforcing `minimum`.
    public static func resized(
        _ rect: CGRect,
        edges: Edges,
        translation: CGVector,
        minimum: CGSize = minimumContentSize
    ) -> CGRect {
        var minX = rect.minX
        var maxX = rect.maxX
        var minY = rect.minY
        var maxY = rect.maxY

        if edges.contains(.left) {
            minX = min(minX + translation.dx, maxX - minimum.width)
        }
        if edges.contains(.right) {
            maxX = max(maxX + translation.dx, minX + minimum.width)
        }
        if edges.contains(.bottom) {
            minY = min(minY + translation.dy, maxY - minimum.height)
        }
        if edges.contains(.top) {
            maxY = max(maxY + translation.dy, minY + minimum.height)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Enforces the minimum size, growing from the top-left corner.
    public static func enforcingMinimumSize(_ rect: CGRect, minimum: CGSize = minimumContentSize) -> CGRect {
        let width = max(rect.width, minimum.width)
        let height = max(rect.height, minimum.height)
        return CGRect(x: rect.minX, y: rect.maxY - height, width: width, height: height)
    }

    // MARK: Toolbar

    public enum ToolbarPlacement: Sendable, Equatable {
        case above
        case below
    }

    /// Places the toolbar above the lens unless there isn't room within
    /// `visibleFrame`, in which case it goes below.
    ///
    /// - Parameters:
    ///   - outerFrame: Global frame of the lens including its border ring.
    ///   - toolbarHeight: Height of the toolbar panel.
    ///   - visibleFrame: The screen's visible frame (excludes the menu bar).
    ///
    public static func toolbarPlacement(
        outerFrame: CGRect,
        toolbarHeight: CGFloat,
        visibleFrame: CGRect
    ) -> ToolbarPlacement {
        outerFrame.maxY + toolbarHeight <= visibleFrame.maxY ? .above : .below
    }
}
