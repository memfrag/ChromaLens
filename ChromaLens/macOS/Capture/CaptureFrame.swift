//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import CoreGraphics
import CoreVideo
import Synchronization

// MARK: - CaptureRegion

/// The region a stream configuration captures.
nonisolated struct CaptureRegion: Equatable, Sendable {

    /// Display-local rect in points (top-left origin), the stream's `sourceRect`.
    var rect: CGRect

    /// Output size in pixels.
    var pixelWidth: Int
    var pixelHeight: Int

    /// Global Cocoa frame of the captured display when the region was set.
    var screenFrame: CGRect

    var displayID: CGDirectDisplayID

    init(rect: CGRect, scale: CGFloat, screenFrame: CGRect, displayID: CGDirectDisplayID) {
        self.rect = rect
        self.pixelWidth = max(Int((rect.width * scale).rounded()), 1)
        self.pixelHeight = max(Int((rect.height * scale).rounded()), 1)
        self.screenFrame = screenFrame
        self.displayID = displayID
    }
}

// MARK: - CaptureFrame

/// One captured frame together with the region it was captured for, so the
/// renderer always crops with matching geometry.
nonisolated struct CaptureFrame: @unchecked Sendable {
    let pixelBuffer: CVPixelBuffer
    let region: CaptureRegion

    /// Capture time in host seconds (same clock as `CACurrentMediaTime`).
    let captureTime: Double
}

// MARK: - LatestFrameBox

/// Newest-frame-wins slot shared between the capture queue and the renderer.
/// Older unrendered frames are dropped and counted, never queued.
nonisolated final class LatestFrameBox: Sendable {

    private struct State {
        var frame: CaptureFrame?
        var isNew = false
        var droppedCount = 0
    }

    private let state = Mutex(State())

    func put(_ frame: CaptureFrame) {
        state.withLock { state in
            if state.isNew {
                state.droppedCount += 1
            }
            state.frame = frame
            state.isNew = true
        }
    }

    /// Returns the newest frame and whether it hasn't been taken before.
    func take() -> (frame: CaptureFrame?, isNew: Bool) {
        state.withLock { state in
            let result = (state.frame, state.isNew)
            state.isNew = false
            return result
        }
    }

    /// Drops the last frame so nothing stale can be shown.
    func clear() {
        state.withLock { state in
            state.frame = nil
            state.isNew = false
        }
    }

    /// Returns and resets the dropped-frame counter.
    func takeDroppedCount() -> Int {
        state.withLock { state in
            let count = state.droppedCount
            state.droppedCount = 0
            return count
        }
    }
}
