//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import AppKit
import ColorVisionKit
import OSLog
import SwiftUI

// MARK: - LensCoordinator

/// Single source of truth for the lens: visibility, simulation parameters,
/// capture lifecycle, display changes and global shortcuts.
@Observable @MainActor final class LensCoordinator {

    // MARK: Capture State

    enum CaptureState: Equatable {
        case idle
        case starting
        case running
        case switchingDisplay
        case paused(reason: String)
        case permissionDenied

        var description: String {
            switch self {
            case .idle: "Not capturing"
            case .starting: "Starting…"
            case .running: "Capturing"
            case .switchingDisplay: "Switching display…"
            case .paused(let reason): reason
            case .permissionDenied: "Screen Recording permission needed"
            }
        }

        var isCapturing: Bool {
            switch self {
            case .running, .starting, .switchingDisplay: true
            case .idle, .paused, .permissionDenied: false
            }
        }
    }

    // MARK: Observable State

    private(set) var isLensVisible = false

    private(set) var captureState: CaptureState = .idle {
        didSet {
            renderer?.showsFrames = captureState == .running
        }
    }

    /// Latched original/simulated toggle from the lens toolbar.
    var isShowingOriginal = false {
        didSet {
            updateRendererParameters()
        }
    }

    /// Whether the hold-to-compare shortcut is currently held.
    private(set) var isHoldingOriginal = false

    /// Rendering statistics for the performance HUD, refreshed periodically.
    private(set) var stats = FrameStats()

    /// Receives drag/resize gestures from the lens toolbar.
    private(set) var interactionHandler: (any LensInteractionHandler)?

    var preset: CVDPreset {
        get {
            settings.preset
        }
        set {
            settings.preset = newValue
            updateRendererParameters()
        }
    }

    /// Value of the preset's slider: simulation severity for `-omaly`
    /// presets, desaturation amount for achromatomaly.
    var sliderValue: Double {
        get {
            switch preset.slider {
            case .simulationSeverity: settings.anomalySeverity(for: preset.family)
            case .desaturationAmount: settings.desaturation
            case .none: 0
            }
        }
        set {
            switch preset.slider {
            case .simulationSeverity: settings.setAnomalySeverity(newValue, for: preset.family)
            case .desaturationAmount: settings.desaturation = CVDSlider.clamp(newValue)
            case .none: break
            }
            updateRendererParameters()
        }
    }

    var compareBlend: Double {
        get {
            settings.compareBlend
        }
        set {
            settings.compareBlend = min(max(newValue, 0), 1)
            updateRendererParameters()
        }
    }

    var areControlsHidden: Bool {
        get {
            settings.controlsHidden
        }
        set {
            settings.controlsHidden = newValue
            windowController?.areControlsHidden = newValue
        }
    }

    var simulationParameters: SimulationParameters {
        SimulationParameters(
            preset: preset,
            anomalySeverity: settings.anomalySeverity(for: preset.family),
            desaturation: settings.desaturation,
            compareBlend: settings.compareBlend,
            showOriginal: isShowingOriginal || isHoldingOriginal
        )
    }

    let settings: AppSettings
    let engineeringMode: EngineeringMode

    // MARK: Private State

    @ObservationIgnored private let capture = DisplayCaptureService()
    @ObservationIgnored private var windowController: LensWindowController?
    @ObservationIgnored private var renderer: LensRenderer?
    @ObservationIgnored private var onboarding: OnboardingWindowController?
    @ObservationIgnored private var captureTask: Task<Void, Never>?
    @ObservationIgnored private var stopTask: Task<Void, Never>?
    @ObservationIgnored private var retryTask: Task<Void, Never>?
    @ObservationIgnored private var recenterTask: Task<Void, Never>?
    @ObservationIgnored private var screenChangeTask: Task<Void, Never>?
    @ObservationIgnored private var retryCount = 0
    @ObservationIgnored private var statsTimer: Timer?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var hasStarted = false

    private static let defaultLensSize = CGSize(width: 720, height: 450)
    private static let maximumRetries = 5

    init(settings: AppSettings, engineeringMode: EngineeringMode) {
        self.settings = settings
        self.engineeringMode = engineeringMode
    }

    // MARK: Launch

    /// Called once at launch: registers shortcuts and system observers, then
    /// shows onboarding or restores the lens.
    func start() {
        guard !hasStarted else {
            return
        }
        hasStarted = true

        capture.onStop = { [weak self] error in
            self?.handleCaptureFailure(error)
        }
        configureShortcuts()
        observeSystemEvents()

        Logger.coordinator.info(
            "Launch: onboarded \(self.settings.hasCompletedOnboarding), visible \(self.settings.lensVisible), permission \(ScreenCapturePermission.isGranted)"
        )
        if !settings.hasCompletedOnboarding {
            if ScreenCapturePermission.isGranted {
                settings.hasCompletedOnboarding = true
                showLens()
            } else {
                showOnboarding(.firstLaunch)
            }
        } else if settings.lensVisible {
            showLens()
        }
    }

    // MARK: Lens Visibility

    func toggleLens() {
        if isLensVisible {
            hideLens()
        } else {
            showLens()
        }
    }

    func showLens() {
        stopTask?.cancel()
        stopTask = nil

        guard ScreenCapturePermission.isGranted else {
            Logger.coordinator.info("Show lens: no Screen Recording permission")
            captureState = .permissionDenied
            showOnboarding(.permissionNeeded)
            return
        }

        let controller = makeWindowControllerIfNeeded()
        let rect = resolvedLensRect()
        controller.areControlsHidden = settings.controlsHidden
        controller.show(contentRect: rect)
        renderer?.lensContentRect = rect
        controller.metalView.isPaused = false

        isLensVisible = true
        settings.lensVisible = true
        settings.lensFrame = rect
        startStatsTimer()
        ensureCapture(for: rect)
    }

    func hideLens() {
        guard isLensVisible else {
            return
        }
        windowController?.hide()
        windowController?.metalView.isPaused = true
        isLensVisible = false
        isHoldingOriginal = false
        settings.lensVisible = false
        stopStatsTimer()

        let grace = settings.captureStopGrace.duration
        if grace == .zero {
            stopCaptureNow()
        } else {
            stopTask = Task { [weak self] in
                try? await Task.sleep(for: grace)
                guard let self, !Task.isCancelled, !self.isLensVisible else {
                    return
                }
                self.stopCaptureNow()
            }
        }
    }

    /// Hides the lens and stops capture immediately, ignoring the grace period.
    func stopCapture() {
        hideLens()
        stopTask?.cancel()
        stopTask = nil
        stopCaptureNow()
    }

    func toggleControls() {
        areControlsHidden.toggle()
    }

    func selectNextPreset() {
        preset = preset.next
    }

    func selectPreviousPreset() {
        preset = preset.previous
    }

    func setHoldingOriginal(_ isHolding: Bool) {
        guard isHoldingOriginal != isHolding else {
            return
        }
        isHoldingOriginal = isHolding
        updateRendererParameters()
    }

    // MARK: Onboarding

    func showOnboarding(_ reason: OnboardingWindowController.Reason) {
        let controller = onboarding ?? OnboardingWindowController(settings: settings)
        onboarding = controller
        controller.show(reason: reason)
    }

    // MARK: Window Controller

    private func makeWindowControllerIfNeeded() -> LensWindowController {
        if let windowController {
            return windowController
        }
        let controller = LensWindowController(
            overlay: LensOverlayView()
                .environment(self)
                .environment(engineeringMode),
            toolbar: LensToolbarView()
                .environment(self)
        )
        controller.onGeometryChanged = { [weak self] rect in
            self?.lensGeometryChanged(rect)
        }
        controller.onGeometryChangeEnded = { [weak self] rect in
            self?.lensGeometryChangeEnded(rect)
        }
        renderer = LensRenderer(view: controller.metalView, frameBox: capture.frameBox, parameters: simulationParameters)
        renderer?.showsFrames = captureState == .running
        if renderer == nil {
            captureState = .paused(reason: "Metal is unavailable on this Mac")
        }
        windowController = controller
        interactionHandler = controller
        return controller
    }

    /// The saved lens frame if it's still on a connected display, otherwise
    /// a default-sized lens centered on the display under the pointer.
    private func resolvedLensRect() -> CGRect {
        let saved = LensGeometry.enforcingMinimumSize(settings.lensFrame)
        if settings.lensFrame != .zero, let screen = Self.screen(for: saved) {
            return LensGeometry.clamp(saved, to: screen.frame)
        }
        let size = settings.lensFrame == .zero ? Self.defaultLensSize : saved.size
        let screen = Self.screenUnderPointer() ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else {
            return CGRect(origin: .zero, size: size)
        }
        return LensGeometry.centered(size, in: screen.visibleFrame)
    }

    private func updateRendererParameters() {
        renderer?.parameters = simulationParameters
    }

    // MARK: Geometry

    private func lensGeometryChanged(_ rect: CGRect) {
        recenterTask?.cancel()
        renderer?.lensContentRect = rect
        updateCaptureRegionIfNeeded(for: rect, force: false)
    }

    private func lensGeometryChangeEnded(_ rect: CGRect) {
        guard let screen = Self.screen(for: rect) ?? NSScreen.main else {
            return
        }
        let clamped = LensGeometry.clamp(rect, to: screen.frame)
        if clamped != rect {
            windowController?.setContentRect(clamped)
            renderer?.lensContentRect = clamped
        }
        settings.lensFrame = clamped

        if capture.isRunning, capture.displayID == screen.displayID {
            // Re-center the capture margin around the lens once it settles.
            recenterTask?.cancel()
            recenterTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(150))
                guard let self, !Task.isCancelled else {
                    return
                }
                self.updateCaptureRegionIfNeeded(for: clamped, force: true)
            }
        } else if captureState != .permissionDenied {
            startCapture(on: screen, rect: clamped, isSwitchingDisplay: capture.isRunning)
        }
    }

    private func updateCaptureRegionIfNeeded(for rect: CGRect, force: Bool) {
        guard capture.isRunning,
              let region = capture.region,
              let screen = Self.screen(withDisplayID: region.displayID) else {
            return
        }
        let needsUpdate = force || LensGeometry.needsReconfigure(
            lensContent: rect,
            capturedRect: region.rect,
            screenFrame: screen.frame
        )
        guard needsUpdate else {
            return
        }
        let padded = LensGeometry.paddedCaptureRect(lensContent: rect, screenFrame: screen.frame)
        guard padded != .zero else {
            return
        }
        capture.requestRegion(padded, screenFrame: screen.frame)
    }

    // MARK: Capture

    private func ensureCapture(for rect: CGRect) {
        guard let screen = Self.screen(for: rect) else {
            return
        }
        if capture.isRunning, capture.displayID == screen.displayID {
            captureState = .running
            updateCaptureRegionIfNeeded(for: rect, force: true)
        } else {
            startCapture(on: screen, rect: rect, isSwitchingDisplay: false)
        }
    }

    private func startCapture(on screen: NSScreen, rect: CGRect, isSwitchingDisplay: Bool) {
        retryTask?.cancel()
        captureTask?.cancel()
        let screenFrame = screen.frame
        let region = LensGeometry.paddedCaptureRect(lensContent: rect, screenFrame: screenFrame)
        guard region != .zero else {
            return
        }
        captureState = isSwitchingDisplay ? .switchingDisplay : .starting
        renderer?.resetStats()

        let displayID = screen.displayID
        let scale = screen.backingScaleFactor
        captureTask = Task { [weak self] in
            guard let self else {
                return
            }
            do {
                try await self.capture.start(displayID: displayID, screenFrame: screenFrame, scale: scale, rect: region)
                guard !Task.isCancelled else {
                    return
                }
                self.retryCount = 0
                self.captureState = .running
                if let current = self.windowController?.contentRect {
                    self.updateCaptureRegionIfNeeded(for: current, force: false)
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                self.handleCaptureFailure(error)
            }
        }
    }

    private func stopCaptureNow() {
        captureTask?.cancel()
        retryTask?.cancel()
        recenterTask?.cancel()
        if captureState != .permissionDenied {
            captureState = .idle
        }
        Task {
            await capture.stop()
        }
    }

    private func handleCaptureFailure(_ error: Error) {
        Logger.coordinator.error("Capture failed: \(error.localizedDescription)")
        capture.frameBox.clear()
        if error.isScreenCapturePermissionError || !ScreenCapturePermission.isGranted {
            captureState = .permissionDenied
            showOnboarding(.revoked)
            return
        }
        guard isLensVisible else {
            captureState = .idle
            return
        }
        captureState = .paused(reason: "Capture interrupted")
        scheduleRetry()
    }

    private func scheduleRetry() {
        retryCount += 1
        guard retryCount <= Self.maximumRetries else {
            captureState = .paused(reason: "Capture unavailable")
            return
        }
        let delay = Duration.seconds(min(pow(2, Double(retryCount - 1)), 8))
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled, self.isLensVisible else {
                return
            }
            self.resolveDisplayAndRestart()
        }
    }

    /// Re-resolves which display the lens is on (moving it to the main
    /// display if its display is gone), clamps it and restarts capture.
    private func resolveDisplayAndRestart() {
        guard isLensVisible, let windowController else {
            return
        }
        var rect = windowController.contentRect
        let screen: NSScreen
        if let current = Self.screen(for: rect) {
            screen = current
            rect = LensGeometry.clamp(rect, to: current.frame)
        } else if let main = NSScreen.main ?? NSScreen.screens.first {
            screen = main
            rect = LensGeometry.centered(rect.size, in: main.visibleFrame)
        } else {
            captureState = .paused(reason: "No display available")
            return
        }
        windowController.setContentRect(rect)
        renderer?.lensContentRect = rect
        settings.lensFrame = rect
        startCapture(on: screen, rect: rect, isSwitchingDisplay: false)
    }

    // MARK: System Events

    private func observeSystemEvents() {
        let center = NotificationCenter.default
        let workspaceCenter = NSWorkspace.shared.notificationCenter

        observers.append(center.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.screenParametersChanged()
            }
        })

        observers.append(workspaceCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.systemWillSleep()
            }
        })

        observers.append(workspaceCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.systemDidWake()
            }
        })

        observers.append(workspaceCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.windowController?.bringToFront()
            }
        })
    }

    private func screenParametersChanged() {
        screenChangeTask?.cancel()
        screenChangeTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, !Task.isCancelled else {
                return
            }
            if self.isLensVisible {
                self.resolveDisplayAndRestart()
            } else if self.capture.isRunning {
                self.stopCaptureNow()
            }
        }
    }

    private func systemWillSleep() {
        guard capture.isRunning || captureState.isCapturing else {
            return
        }
        captureTask?.cancel()
        retryTask?.cancel()
        captureState = .paused(reason: "Paused while sleeping")
        Task {
            await capture.stop()
        }
    }

    private func systemDidWake() {
        guard isLensVisible else {
            return
        }
        retryCount = 0
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard let self, !Task.isCancelled else {
                return
            }
            self.resolveDisplayAndRestart()
        }
    }

    // MARK: Shortcuts

    private func configureShortcuts() {
        let center = HotKeyCenter.shared
        center.onPress = { [weak self] action in
            self?.shortcutPressed(action)
        }
        center.onRelease = { [weak self] action in
            if action == .holdOriginal {
                self?.setHoldingOriginal(false)
            }
        }
        observeShortcutSettings()
    }

    private func observeShortcutSettings() {
        let shortcuts = withObservationTracking {
            settings.shortcuts
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.observeShortcutSettings()
            }
        }
        HotKeyCenter.shared.register(shortcuts)
    }

    private func shortcutPressed(_ action: ShortcutAction) {
        switch action {
        case .toggleLens: toggleLens()
        case .holdOriginal: setHoldingOriginal(true)
        case .nextPreset: selectNextPreset()
        case .previousPreset: selectPreviousPreset()
        case .toggleControls: toggleControls()
        }
    }

    // MARK: Stats

    private func startStatsTimer() {
        guard statsTimer == nil else {
            return
        }
        statsTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.engineeringMode.isEnabled, self.engineeringMode.showPerformanceHUD,
                      let renderer = self.renderer else {
                    return
                }
                self.stats = renderer.stats
            }
        }
    }

    private func stopStatsTimer() {
        statsTimer?.invalidate()
        statsTimer = nil
    }

    // MARK: Screens

    static func screen(for rect: CGRect) -> NSScreen? {
        let screens = NSScreen.screens
        guard let index = LensGeometry.bestScreenIndex(for: rect, among: screens.map(\.frame)) else {
            return nil
        }
        return screens[index]
    }

    static func screen(withDisplayID displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { $0.displayID == displayID }
    }

    static func screenUnderPointer() -> NSScreen? {
        let location = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(location) }
    }
}

// MARK: - NSScreen

extension NSScreen {

    /// The CoreGraphics display ID of this screen.
    var displayID: CGDirectDisplayID {
        let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        return number?.uint32Value ?? 0
    }
}

// MARK: - Logger

extension Logger {
    static let coordinator = Logger(subsystem: "io.apparata.ChromaLens", category: "Lens")
}
