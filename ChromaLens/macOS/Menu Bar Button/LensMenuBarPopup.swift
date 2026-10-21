//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import ColorVisionKit
import Sparkle
import SwiftUI
import SwiftUIToolbox

// MARK: - LensMenuBarPopup

/// The fully keyboard-accessible control surface for the lens.
struct LensMenuBarPopup: View {

    let updater: SPUUpdater

    @Environment(LensCoordinator.self) private var coordinator
    @Environment(EngineeringMode.self) private var engineeringMode
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        @Bindable var coordinator = coordinator
        @Bindable var engineeringMode = engineeringMode

        VStack(alignment: .leading, spacing: 12) {
            header

            HStack {
                Button(coordinator.isLensVisible ? "Hide Lens" : "Show Lens") {
                    coordinator.toggleLens()
                }
                .keyboardShortcut(.defaultAction)
                Button(coordinator.areControlsHidden ? "Show Controls" : "Hide Controls") {
                    coordinator.toggleControls()
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Picker("Simulation", selection: $coordinator.preset) {
                    ForEach(CVDPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                Text(coordinator.preset.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LensSlidersView()

            Toggle("Show Original Colors", isOn: $coordinator.isShowingOriginal)

            Button(role: .destructive) {
                coordinator.stopCapture()
            } label: {
                Label("Stop Capture", systemImage: "stop.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(!coordinator.captureState.isCapturing && !coordinator.isLensVisible)
            .accessibilityHint("Hides the lens and stops screen capture immediately")

            if engineeringMode.isEnabled {
                Divider()
                Text("Engineering")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Toggle("Performance HUD", isOn: $engineeringMode.showPerformanceHUD)
            }

            Divider()

            VStack(alignment: .leading, spacing: 2) {
                menuButton("Settings…") {
                    NSApp.activate()
                    openSettings()
                }
                menuButton("ChromaLens Help") {
                    NSApp.activate()
                    openWindow(id: HelpWindow.windowID)
                }
                menuButton("About ChromaLens") {
                    NSApp.activate()
                    openWindow(id: AboutWindow.windowID)
                }
                menuButton("Check for Updates…") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)
                menuButton("Quit ChromaLens") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(16)
        .frame(width: 320)
        .onAppear {
            // Hidden reveal of the engineering section in Release builds.
            if NSEvent.modifierFlags.contains(.option) {
                engineeringMode.reveal()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("ChromaLens")
                .font(.headline)
            Spacer()
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(coordinator.captureState.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var statusColor: Color {
        switch coordinator.captureState {
        case .running: .red
        case .starting, .switchingDisplay: .orange
        case .paused, .permissionDenied: .yellow
        case .idle: .secondary
        }
    }

    private func menuButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .padding(.vertical, 2)
    }
}
