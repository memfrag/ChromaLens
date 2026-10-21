//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import AppKit
import CoreGraphics

// MARK: - ScreenCapturePermission

/// Screen Recording consent helpers.
enum ScreenCapturePermission {

    /// Whether the process currently has Screen Recording access. macOS may
    /// keep reporting the old value until relaunch after a change.
    static var isGranted: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Shows the system consent prompt (first time) or does nothing if the
    /// user already decided; returns the current state.
    @discardableResult
    static func request() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    static let systemSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
    )

    static func openSystemSettings() {
        guard let url = systemSettingsURL else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    /// Launches a fresh instance of the app and terminates this one. Needed
    /// after granting access, which macOS often applies only on relaunch.
    @MainActor static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            Task { @MainActor in
                NSApp.terminate(nil)
            }
        }
    }
}
