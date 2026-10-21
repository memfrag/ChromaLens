//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import Carbon.HIToolbox

// MARK: - ShortcutRecorderView

/// A button that records a new global shortcut. While recording, ⎋ cancels
/// and ⌫ clears the shortcut. Shortcuts need ⌘, ⌃ or ⌥.
struct ShortcutRecorderView: View {

    @Binding var hotKey: HotKey?

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button {
                isRecording ? stopRecording() : startRecording()
            } label: {
                Text(label)
                    .monospaced()
                    .frame(minWidth: 110)
            }
            .accessibilityLabel(isRecording ? "Recording shortcut" : "Shortcut \(hotKey?.displayString ?? "none")")
            .accessibilityHint("Press to record a new shortcut")

            if hotKey != nil, !isRecording {
                Button {
                    hotKey = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear shortcut")
                .help("Clear shortcut")
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private var label: String {
        if isRecording {
            return "Type Shortcut…"
        }
        return hotKey?.displayString ?? "None"
    }

    private func startRecording() {
        HotKeyCenter.shared.suspend()
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch Int(event.keyCode) {
            case kVK_Escape:
                stopRecording()
            case kVK_Delete, kVK_ForwardDelete:
                hotKey = nil
                stopRecording()
            default:
                if let recorded = HotKey(event: event) {
                    hotKey = recorded
                    stopRecording()
                } else {
                    NSSound.beep()
                }
            }
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        if isRecording {
            isRecording = false
            HotKeyCenter.shared.resume()
        }
    }
}
