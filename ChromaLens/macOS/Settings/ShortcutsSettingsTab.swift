//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI

struct ShortcutsSettingsTab: View {

    @Environment(AppSettings.self) private var settings

    private let hotKeyCenter = HotKeyCenter.shared

    var body: some View {
        Form {
            Section {
                ForEach(ShortcutAction.allCases) { action in
                    LabeledContent {
                        HStack(spacing: 6) {
                            if hotKeyCenter.unavailableActions.contains(action) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.yellow)
                                    .help("This shortcut is in use by another app or the system.")
                                    .accessibilityLabel("Shortcut unavailable")
                            }
                            ShortcutRecorderView(hotKey: binding(for: action))
                        }
                    } label: {
                        Text(action.title)
                    }
                }
            } footer: {
                HStack {
                    Text("Shortcuts work in every app. Each needs ⌘, ⌃ or ⌥.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Restore Defaults") {
                        settings.shortcuts = ShortcutAction.defaultShortcuts
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func binding(for action: ShortcutAction) -> Binding<HotKey?> {
        Binding {
            settings.shortcuts[action.rawValue]
        } set: { newValue in
            settings.shortcuts[action.rawValue] = newValue
        }
    }
}

#if DEBUG
#Preview {
    ShortcutsSettingsTab()
        .previewEnvironment()
}
#endif
