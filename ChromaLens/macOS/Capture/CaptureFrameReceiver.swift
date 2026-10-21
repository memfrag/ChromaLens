//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import CoreMedia
import ScreenCaptureKit
import Synchronization

// MARK: - CaptureFrameReceiver

/// Receives frames on the capture queue, tags each with the region it was
/// captured for and hands it to the ``LatestFrameBox``.
///
/// Region attribution across `updateConfiguration`: frames presented before
/// the update was requested belong to the old region; frames presented after
/// the update completed (plus a settle interval) belong to the new region;
/// frames in between are ambiguous and dropped. Frames whose pixel size
/// doesn't match their region are dropped too. The renderer keeps showing the
/// previous (correctly tagged) frame meanwhile, and the capture margin keeps
/// the lens covered.
nonisolated final class CaptureFrameReceiver: NSObject, SCStreamOutput, SCStreamDelegate, Sendable {

    private struct Transition {
        var from: CaptureRegion
        var to: CaptureRegion
        var requestTime: Double
        var settleTime: Double?
    }

    private struct State {
        var region: CaptureRegion
        var transition: Transition?
    }

    let frameBox: LatestFrameBox

    private let state: Mutex<State>
    private let onStop: @Sendable (Error) -> Void

    init(region: CaptureRegion, frameBox: LatestFrameBox, onStop: @escaping @Sendable (Error) -> Void) {
        self.frameBox = frameBox
        self.state = Mutex(State(region: region))
        self.onStop = onStop
    }

    // MARK: Region Transitions

    func beginTransition(to region: CaptureRegion, at time: Double) {
        state.withLock { state in
            let from = state.transition?.to ?? state.region
            state.transition = Transition(from: from, to: region, requestTime: time, settleTime: nil)
        }
    }

    func settleTransition(at time: Double) {
        state.withLock { state in
            state.transition?.settleTime = time
        }
    }

    func cancelTransition() {
        state.withLock { state in
            state.transition = nil
        }
    }

    private func region(forPresentationTime time: Double) -> CaptureRegion? {
        state.withLock { state in
            guard let transition = state.transition else {
                return state.region
            }
            if time < transition.requestTime {
                return transition.from
            }
            if let settleTime = transition.settleTime, time >= settleTime {
                state.region = transition.to
                state.transition = nil
                return transition.to
            }
            return nil
        }
    }

    // MARK: SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              sampleBuffer.isValid,
              Self.isComplete(sampleBuffer),
              let pixelBuffer = sampleBuffer.imageBuffer else {
            return
        }
        let time = sampleBuffer.presentationTimeStamp.seconds
        guard let region = region(forPresentationTime: time),
              CVPixelBufferGetWidth(pixelBuffer) == region.pixelWidth,
              CVPixelBufferGetHeight(pixelBuffer) == region.pixelHeight else {
            return
        }
        frameBox.put(CaptureFrame(pixelBuffer: pixelBuffer, region: region, captureTime: time))
    }

    private static func isComplete(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(
                sampleBuffer,
                createIfNecessary: false
              ) as? [[SCStreamFrameInfo: Any]],
              let rawStatus = attachments.first?[.status] as? Int,
              let status = SCFrameStatus(rawValue: rawStatus) else {
            return false
        }
        return status == .complete
    }

    // MARK: SCStreamDelegate

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        onStop(error)
    }
}
