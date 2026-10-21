//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - OnboardingWindowController

/// Shows the Screen Recording onboarding window. Managed in AppKit so the
/// coordinator can present it at launch and on permission revocation.
@MainActor final class OnboardingWindowController {

    enum Reason {
        case firstLaunch
        case permissionNeeded
        case revoked
    }

    private let settings: AppSettings
    private var window: NSWindow?

    init(settings: AppSettings) {
        self.settings = settings
    }

    func show(reason: Reason) {
        let window = window ?? makeWindow()
        self.window = window
        window.contentView = NSHostingView(rootView: OnboardingView(
            reason: reason,
            onRelaunch: { [weak self] in
                self?.relaunch()
            },
            onDismiss: { [weak self] in
                self?.window?.close()
            }
        ))
        window.center()
        // Activation is only a request for a background menu bar app, so
        // also order the window front explicitly.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to ChromaLens"
        window.isReleasedWhenClosed = false
        return window
    }

    private func relaunch() {
        settings.hasCompletedOnboarding = true
        settings.lensVisible = true
        ScreenCapturePermission.relaunch()
    }
}

// MARK: - OnboardingView

struct OnboardingView: View {

    let reason: OnboardingWindowController.Reason
    let onRelaunch: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "eye.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title2.weight(.semibold))
                    Text("ChromaLens needs Screen Recording access.")
                        .foregroundStyle(.secondary)
                }
            }

            Text("""
            The lens shows the area beneath it through a color vision simulation. \
            To do that, ChromaLens captures only the region under the lens. \
            Frames are processed in memory on your Mac and are never saved or uploaded.
            """)
            .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                step(1, "Click Grant Access, or open System Settings.")
                step(2, "Turn on ChromaLens under Privacy & Security › Screen & System Audio Recording.")
                step(3, "Relaunch ChromaLens so macOS applies the change.")
            }

            Spacer(minLength: 0)

            HStack {
                Button("Not Now", action: onDismiss)
                Spacer()
                Button("Grant Access") {
                    ScreenCapturePermission.request()
                }
                Button("Open System Settings") {
                    ScreenCapturePermission.openSystemSettings()
                }
                Button("Relaunch ChromaLens", action: onRelaunch)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 620, height: 400)
    }

    private var title: String {
        switch reason {
        case .firstLaunch: "Welcome to ChromaLens"
        case .permissionNeeded: "Permission Needed"
        case .revoked: "Screen Recording Was Turned Off"
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(number).")
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
