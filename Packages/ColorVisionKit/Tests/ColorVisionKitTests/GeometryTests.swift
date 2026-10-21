//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import CoreGraphics
@testable import ColorVisionKit

@Suite("Lens geometry")
struct GeometryTests {

    /// Primary 1512×982 laptop display at the origin.
    let primary = CGRect(x: 0, y: 0, width: 1512, height: 982)

    /// External display to the left and slightly below, negative origin.
    let external = CGRect(x: -2560, y: -300, width: 2560, height: 1440)

    @Test func displayLocalRoundTrip() {
        let lens = CGRect(x: -2000, y: 100, width: 400, height: 300)
        let local = LensGeometry.displayLocal(lens, screenFrame: external)
        #expect(local == CGRect(x: 560, y: 1440 - 400 - 300, width: 400, height: 300))
        #expect(LensGeometry.global(fromDisplayLocal: local, screenFrame: external) == lens)
    }

    @Test func topLeftOfDisplayMapsToOrigin() {
        let lens = CGRect(x: 0, y: primary.maxY - 200, width: 300, height: 200)
        #expect(LensGeometry.displayLocal(lens, screenFrame: primary).origin == .zero)
    }

    @Test func paddedRectAddsMarginAndClampsAtEdges() {
        let centered = CGRect(x: 500, y: 400, width: 400, height: 200)
        let padded = LensGeometry.paddedCaptureRect(lensContent: centered, screenFrame: primary)
        let local = LensGeometry.displayLocal(centered, screenFrame: primary)
        #expect(padded == local.insetBy(dx: -100, dy: -50))

        // Lens at the bottom-left corner: margin is clamped by the display.
        let corner = CGRect(x: 0, y: 0, width: 400, height: 200)
        let clamped = LensGeometry.paddedCaptureRect(lensContent: corner, screenFrame: primary)
        #expect(clamped.minX == 0)
        #expect(clamped.maxY == primary.height)
        #expect(clamped.width == 500)
        #expect(clamped.height == 250)
    }

    @Test func paddedRectIsEmptyOffDisplay() {
        let offscreen = CGRect(x: 3000, y: 0, width: 400, height: 200)
        #expect(LensGeometry.paddedCaptureRect(lensContent: offscreen, screenFrame: primary) == .zero)
    }

    @Test func paddedRectSnapsToWholePoints() {
        let lens = CGRect(x: 100.3, y: 200.7, width: 300.2, height: 200.1)
        let padded = LensGeometry.paddedCaptureRect(lensContent: lens, screenFrame: primary)
        #expect(padded.minX == padded.minX.rounded())
        #expect(padded.minY == padded.minY.rounded())
        #expect(padded.width == padded.width.rounded())
        #expect(padded.contains(LensGeometry.displayLocal(lens, screenFrame: primary)))
    }

    @Test func reconfigureTriggers() {
        let lens = CGRect(x: 500, y: 400, width: 400, height: 200)
        let captured = LensGeometry.paddedCaptureRect(lensContent: lens, screenFrame: primary)
        #expect(!LensGeometry.needsReconfigure(lensContent: lens, capturedRect: captured, screenFrame: primary))

        // Small move stays within the safe area.
        let nudged = lens.offsetBy(dx: 20, dy: 10)
        #expect(!LensGeometry.needsReconfigure(lensContent: nudged, capturedRect: captured, screenFrame: primary))

        // Approaching the right edge of the captured region.
        let nearEdge = lens.offsetBy(dx: 80, dy: 0)
        #expect(LensGeometry.needsReconfigure(lensContent: nearEdge, capturedRect: captured, screenFrame: primary))

        // Leaving the captured region.
        let outside = lens.offsetBy(dx: 300, dy: 0)
        #expect(LensGeometry.needsReconfigure(lensContent: outside, capturedRect: captured, screenFrame: primary))

        // Much smaller lens: captured region is wastefully large.
        let shrunk = CGRect(x: 600, y: 450, width: 240, height: 160)
        let big = LensGeometry.paddedCaptureRect(
            lensContent: CGRect(x: 300, y: 200, width: 900, height: 600),
            screenFrame: primary
        )
        #expect(LensGeometry.needsReconfigure(lensContent: shrunk, capturedRect: big, screenFrame: primary))
    }

    @Test func pinnedEdgesDoNotTriggerReconfigure() {
        let lens = CGRect(x: 0, y: 0, width: 400, height: 200)
        let captured = LensGeometry.paddedCaptureRect(lensContent: lens, screenFrame: primary)
        #expect(!LensGeometry.needsReconfigure(lensContent: lens, capturedRect: captured, screenFrame: primary))
    }

    @Test func textureCropForCenteredLens() {
        let lens = CGRect(x: 500, y: 400, width: 400, height: 200)
        let captured = LensGeometry.paddedCaptureRect(lensContent: lens, screenFrame: primary)
        let crop = LensGeometry.textureCrop(lensContent: lens, capturedRect: captured, screenFrame: primary)
        #expect(abs(crop.uvOrigin.x - 1.0 / 6) < 1e-6)
        #expect(abs(crop.uvOrigin.y - 1.0 / 6) < 1e-6)
        #expect(abs(crop.uvSize.x - 4.0 / 6) < 1e-6)
        #expect(crop.isFullyCovered)
    }

    @Test func textureCropDetectsUncoveredArea() {
        let lens = CGRect(x: 500, y: 400, width: 400, height: 200)
        let captured = LensGeometry.paddedCaptureRect(lensContent: lens, screenFrame: primary)
        let moved = lens.offsetBy(dx: 200, dy: 0)
        let crop = LensGeometry.textureCrop(lensContent: moved, capturedRect: captured, screenFrame: primary)
        #expect(!crop.isFullyCovered)
    }

    @Test func textureCropOnNegativeOriginDisplay() {
        let lens = CGRect(x: -1500, y: 200, width: 600, height: 400)
        let captured = LensGeometry.paddedCaptureRect(lensContent: lens, screenFrame: external)
        let crop = LensGeometry.textureCrop(lensContent: lens, capturedRect: captured, screenFrame: external)
        #expect(crop.isFullyCovered)
        #expect(abs(crop.uvSize.x - 600 / Float(captured.width)) < 1e-6)
    }

    @Test func bestScreenPicksLargestIntersection() {
        let screens = [primary, external]
        #expect(LensGeometry.bestScreenIndex(for: CGRect(x: -300, y: 100, width: 400, height: 200), among: screens) == 1)
        #expect(LensGeometry.bestScreenIndex(for: CGRect(x: -100, y: 100, width: 400, height: 200), among: screens) == 0)
        #expect(LensGeometry.bestScreenIndex(for: CGRect(x: 5000, y: 0, width: 10, height: 10), among: screens) == nil)
    }

    @Test func clampMovesAndShrinks() {
        let clamped = LensGeometry.clamp(CGRect(x: 1400, y: -50, width: 400, height: 200), to: primary)
        #expect(clamped == CGRect(x: 1112, y: 0, width: 400, height: 200))
        let huge = LensGeometry.clamp(CGRect(x: 0, y: 0, width: 4000, height: 3000), to: primary)
        #expect(huge == primary)
    }

    @Test func centeredFitsOnMainDisplay() {
        let rect = LensGeometry.centered(CGSize(width: 2000, height: 400), in: primary)
        #expect(rect.width == primary.width)
        #expect(rect.midY == primary.midY)
    }

    @Test func resizeRespectsMinimumAndFixedEdges() {
        let frame = CGRect(x: 100, y: 100, width: 400, height: 300)
        let wider = LensGeometry.resized(frame, edges: [.right], translation: CGVector(dx: 50, dy: 0))
        #expect(wider == CGRect(x: 100, y: 100, width: 450, height: 300))
        let fromLeft = LensGeometry.resized(frame, edges: [.left], translation: CGVector(dx: 500, dy: 0))
        #expect(fromLeft.maxX == frame.maxX)
        #expect(fromLeft.width == LensGeometry.minimumContentSize.width)
        let topLeft = LensGeometry.resized(frame, edges: [.top, .left], translation: CGVector(dx: -20, dy: 30))
        #expect(topLeft == CGRect(x: 80, y: 100, width: 420, height: 330))
        let fromBottom = LensGeometry.resized(frame, edges: [.bottom], translation: CGVector(dx: 0, dy: 400))
        #expect(fromBottom.maxY == frame.maxY)
        #expect(fromBottom.height == LensGeometry.minimumContentSize.height)
    }

    @Test func toolbarFlipsBelowAtScreenTop() {
        let visible = CGRect(x: 0, y: 0, width: 1512, height: 950)
        let low = CGRect(x: 100, y: 100, width: 400, height: 300)
        #expect(LensGeometry.toolbarPlacement(outerFrame: low, toolbarHeight: 32, visibleFrame: visible) == .above)
        let high = CGRect(x: 100, y: 640, width: 400, height: 300)
        #expect(LensGeometry.toolbarPlacement(outerFrame: high, toolbarHeight: 32, visibleFrame: visible) == .below)
    }
}
