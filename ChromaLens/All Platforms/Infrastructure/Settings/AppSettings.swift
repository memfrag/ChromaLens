//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import KeyValueStore
import ColorVisionKit

// MARK: - AppSettings

/// A container for application-wide user settings.
///
/// `AppSettings` provides observable properties that represent user preferences
/// and persists them using an underlying key–value store.
/// It is designed to be injected into SwiftUI views and other components
/// that depend on reactive settings.
///
@Observable @MainActor public final class AppSettings {

    // MARK: Key

    /// The keys used to store and retrieve settings from the underlying store.
    public enum Key: String {
        /// The preferred color scheme for the app.
        case colorScheme
        /// The lens content frame in global Cocoa coordinates (`.zero` = unset).
        case lensFrame
        /// Whether the lens was visible when the app last ran.
        case lensVisible
        /// Whether the lens toolbar and border ring are hidden.
        case controlsHidden
        /// The selected simulation preset.
        case preset
        /// Machado severity per family for the `-omaly` presets.
        case anomalySeverityByFamily
        /// Achromatomaly desaturation amount.
        case desaturation
        /// Blend with the original, 0...1.
        case compareBlend
        /// How long capture keeps running after the lens is hidden.
        case captureStopGrace
        /// Global keyboard shortcuts by action.
        case shortcuts
        /// Whether the first-launch onboarding has been completed.
        case hasCompletedOnboarding
    }

    // MARK: Properties

    /// The app's current color scheme preference.
    public var colorScheme: AppColorScheme {
        didSet {
            store.save(colorScheme, for: .colorScheme)
        }
    }

    public var lensFrame: CGRect {
        didSet {
            store.save(lensFrame, for: .lensFrame)
        }
    }

    public var lensVisible: Bool {
        didSet {
            store.save(lensVisible, for: .lensVisible)
        }
    }

    public var controlsHidden: Bool {
        didSet {
            store.save(controlsHidden, for: .controlsHidden)
        }
    }

    public var preset: CVDPreset {
        didSet {
            store.save(preset, for: .preset)
        }
    }

    public var anomalySeverityByFamily: [String: Double] {
        didSet {
            store.save(anomalySeverityByFamily, for: .anomalySeverityByFamily)
        }
    }

    public var desaturation: Double {
        didSet {
            store.save(desaturation, for: .desaturation)
        }
    }

    public var compareBlend: Double {
        didSet {
            store.save(compareBlend, for: .compareBlend)
        }
    }

    public var captureStopGrace: CaptureStopGrace {
        didSet {
            store.save(captureStopGrace, for: .captureStopGrace)
        }
    }

    public var shortcuts: [String: HotKey] {
        didSet {
            store.save(shortcuts, for: .shortcuts)
        }
    }

    public var hasCompletedOnboarding: Bool {
        didSet {
            store.save(hasCompletedOnboarding, for: .hasCompletedOnboarding)
        }
    }

    // MARK: Setup

    /// The key–value store that backs this settings container.
    @ObservationIgnored
    private let store: AnyKeyValueStore<AppSettings.Key>

    /// Creates a new instance of `AppSettings`.
    ///
    /// - Parameter store: The store used to persist values. If `nil`,
    ///   defaults to a `UserDefaults`-backed store.
    ///
    public init(store: AnyKeyValueStore<AppSettings.Key>? = nil) {
        self.store = store ?? .defaultStore
        colorScheme = self.store.load(.colorScheme, default: .system)
        lensFrame = self.store.load(.lensFrame, default: CGRect.zero)
        lensVisible = self.store.load(.lensVisible, default: false)
        controlsHidden = self.store.load(.controlsHidden, default: false)
        preset = self.store.load(.preset, default: CVDPreset.initial)
        anomalySeverityByFamily = self.store.load(.anomalySeverityByFamily, default: [String: Double]())
        desaturation = self.store.load(.desaturation, default: CVDSlider.defaultValue)
        compareBlend = self.store.load(.compareBlend, default: 0.0)
        captureStopGrace = self.store.load(.captureStopGrace, default: CaptureStopGrace.immediately)
        shortcuts = self.store.load(.shortcuts, default: ShortcutAction.defaultShortcuts)
        hasCompletedOnboarding = self.store.load(.hasCompletedOnboarding, default: false)
    }

    // MARK: Derived

    /// The `-omaly` severity for a family, defaulting to ``CVDSlider/defaultValue``.
    public func anomalySeverity(for family: CVDFamily) -> Double {
        CVDSlider.clamp(anomalySeverityByFamily[family.rawValue] ?? CVDSlider.defaultValue)
    }

    public func setAnomalySeverity(_ value: Double, for family: CVDFamily) {
        anomalySeverityByFamily[family.rawValue] = CVDSlider.clamp(value)
    }
}

// MARK: - CaptureStopGrace

/// How long the capture stream keeps running after the lens is hidden.
public enum CaptureStopGrace: String, CaseIterable, Identifiable, Sendable {
    case immediately
    case tenSeconds
    case oneMinute

    public var id: Self { self }

    public var duration: Duration {
        switch self {
        case .immediately: .zero
        case .tenSeconds: .seconds(10)
        case .oneMinute: .seconds(60)
        }
    }

    public var description: String {
        switch self {
        case .immediately: "Immediately"
        case .tenSeconds: "After 10 Seconds"
        case .oneMinute: "After 1 Minute"
        }
    }
}
