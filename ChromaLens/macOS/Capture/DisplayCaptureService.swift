//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import AppKit
import CoreMedia
import OSLog
import ScreenCaptureKit

// MARK: - DisplayCaptureService

/// Owns the ScreenCaptureKit stream for one display region.
///
/// The whole ChromaLens process is excluded from capture so the lens never
/// sees itself. Frames are BGRA 8-bit sRGB at native pixel density.
@MainActor final class DisplayCaptureService {

    enum CaptureError: Error {
        case displayNotFound
    }

    let frameBox = LatestFrameBox()

    /// Called on the main actor when the stream stops on its own.
    var onStop: ((Error) -> Void)?

    private(set) var isRunning = false
    private(set) var displayID: CGDirectDisplayID?

    /// The region currently configured (or being configured).
    private(set) var region: CaptureRegion?

    private var stream: SCStream?
    private var receiver: CaptureFrameReceiver?
    private var scale: CGFloat = 2
    private var isUpdatingRegion = false
    private var pendingRegion: CaptureRegion?

    private let sampleQueue = DispatchQueue(label: "io.apparata.ChromaLens.capture", qos: .userInteractive)

    // MARK: Start / Stop

    /// Starts capturing `rect` (display-local points) on a display, replacing
    /// any running stream.
    func start(displayID: CGDirectDisplayID, screenFrame: CGRect, scale: CGFloat, rect: CGRect) async throws {
        await stop()

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw CaptureError.displayNotFound
        }
        let filter = Self.makeFilter(display: display, content: content)

        let region = CaptureRegion(rect: rect, scale: scale, screenFrame: screenFrame, displayID: displayID)
        let receiver = CaptureFrameReceiver(region: region, frameBox: frameBox) { [weak self] error in
            Task { @MainActor in
                self?.streamDidStop(error)
            }
        }
        let stream = SCStream(filter: filter, configuration: Self.makeConfiguration(region), delegate: receiver)
        try stream.addStreamOutput(receiver, type: .screen, sampleHandlerQueue: sampleQueue)

        self.stream = stream
        self.receiver = receiver
        self.scale = scale
        self.region = region
        self.displayID = displayID

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            stream.startCapture { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        guard self.stream === stream else {
            // Stopped or restarted while starting.
            throw CancellationError()
        }
        isRunning = true
        Logger.capture.info("Capture started on display \(displayID)")
    }

    /// Stops capture and clears the last frame.
    func stop() async {
        guard let stream else {
            return
        }
        self.stream = nil
        receiver = nil
        isRunning = false
        isUpdatingRegion = false
        pendingRegion = nil
        region = nil
        displayID = nil
        frameBox.clear()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            stream.stopCapture { _ in
                continuation.resume()
            }
        }
        Logger.capture.info("Capture stopped")
    }

    // MARK: Region Updates

    /// Moves the captured region on the current display. Updates are
    /// coalesced: one in flight, the latest request queued.
    func requestRegion(_ rect: CGRect, screenFrame: CGRect) {
        guard let displayID, stream != nil else {
            return
        }
        let newRegion = CaptureRegion(rect: rect, scale: scale, screenFrame: screenFrame, displayID: displayID)
        guard newRegion != (pendingRegion ?? region) else {
            return
        }
        if isUpdatingRegion {
            pendingRegion = newRegion
        } else {
            apply(newRegion)
        }
    }

    private func apply(_ newRegion: CaptureRegion) {
        guard let stream, let receiver else {
            return
        }
        isUpdatingRegion = true
        receiver.beginTransition(to: newRegion, at: CACurrentMediaTime())
        stream.updateConfiguration(Self.makeConfiguration(newRegion)) { [weak self] error in
            Task { @MainActor in
                self?.regionUpdateFinished(newRegion, error: error)
            }
        }
    }

    private func regionUpdateFinished(_ newRegion: CaptureRegion, error: Error?) {
        guard let receiver, isUpdatingRegion else {
            return
        }
        isUpdatingRegion = false
        if let error {
            Logger.capture.error("Region update failed: \(error.localizedDescription)")
            receiver.cancelTransition()
        } else {
            // One and a half frame intervals for in-flight frames to drain.
            receiver.settleTransition(at: CACurrentMediaTime() + 1.5 / 60)
            region = newRegion
        }
        if let pending = pendingRegion {
            pendingRegion = nil
            if pending != region {
                apply(pending)
            }
        }
    }

    // MARK: Stream Events

    private func streamDidStop(_ error: Error) {
        guard stream != nil else {
            return
        }
        Logger.capture.error("Stream stopped: \(error.localizedDescription)")
        stream = nil
        receiver = nil
        isRunning = false
        isUpdatingRegion = false
        pendingRegion = nil
        region = nil
        displayID = nil
        frameBox.clear()
        onStop?(error)
    }

    // MARK: Configuration

    private static func makeFilter(display: SCDisplay, content: SCShareableContent) -> SCContentFilter {
        let pid = ProcessInfo.processInfo.processIdentifier
        let ownApplications = content.applications.filter { $0.processID == pid }
        let ownWindowCount = content.windows.filter { $0.owningApplication?.processID == pid }.count
        Logger.capture.info("""
            Exclusion: pid \(pid), bundle \(Bundle.main.bundleIdentifier ?? "-"), \
            own apps \(ownApplications.count) of \(content.applications.count), own windows \(ownWindowCount)
            """)
        if !ownApplications.isEmpty {
            return SCContentFilter(display: display, excludingApplications: ownApplications, exceptingWindows: [])
        }
        // Fallback: exclude our individual windows if the app isn't listed.
        let ownWindows = content.windows.filter { $0.owningApplication?.processID == pid }
        return SCContentFilter(display: display, excludingWindows: ownWindows)
    }

    private static func makeConfiguration(_ region: CaptureRegion) -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = region.rect
        configuration.width = region.pixelWidth
        configuration.height = region.pixelHeight
        configuration.scalesToFit = false
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.colorSpaceName = CGColorSpace.sRGB
        configuration.showsCursor = false
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        configuration.queueDepth = 3
        configuration.capturesAudio = false
        return configuration
    }
}

// MARK: - Errors

extension Error {

    /// Whether the error means Screen Recording permission is missing or was revoked.
    var isScreenCapturePermissionError: Bool {
        let nsError = self as NSError
        return nsError.domain == SCStreamErrorDomain
            && nsError.code == SCStreamError.Code.userDeclined.rawValue
    }
}

// MARK: - Logger

extension Logger {
    static let capture = Logger(subsystem: "io.apparata.ChromaLens", category: "Capture")
}
