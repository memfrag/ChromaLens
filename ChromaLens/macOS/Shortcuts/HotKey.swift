//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import AppKit
import Carbon.HIToolbox

// MARK: - HotKey

/// A global keyboard shortcut: a virtual key code plus Carbon modifier flags.
public struct HotKey: Codable, Equatable, Hashable, Sendable {

    public var keyCode: UInt32
    public var carbonModifiers: UInt32

    public init(keyCode: UInt32, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }

    /// Creates a hot key from a key-down event, or `nil` if the event lacks
    /// a ⌘, ⌃ or ⌥ modifier (plain keys would hijack typing system-wide).
    public init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: UInt32 = 0
        if flags.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }
        if flags.contains(.option) {
            modifiers |= UInt32(optionKey)
        }
        if flags.contains(.control) {
            modifiers |= UInt32(controlKey)
        }
        guard modifiers != 0 else {
            return nil
        }
        if flags.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }
        self.init(keyCode: UInt32(event.keyCode), carbonModifiers: modifiers)
    }

    /// Human-readable form such as "⌃⌥⌘L".
    public var displayString: String {
        var result = ""
        if carbonModifiers & UInt32(controlKey) != 0 {
            result += "⌃"
        }
        if carbonModifiers & UInt32(optionKey) != 0 {
            result += "⌥"
        }
        if carbonModifiers & UInt32(shiftKey) != 0 {
            result += "⇧"
        }
        if carbonModifiers & UInt32(cmdKey) != 0 {
            result += "⌘"
        }
        return result + Self.keyName(for: keyCode)
    }

    private static let specialKeyNames: [Int: String] = [
        kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "Space", kVK_Delete: "⌫",
        kVK_Escape: "⎋", kVK_ForwardDelete: "⌦", kVK_LeftArrow: "←",
        kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
        kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
        kVK_F11: "F11", kVK_F12: "F12"
    ]

    /// The character the key produces in the current keyboard layout.
    private static func keyName(for keyCode: UInt32) -> String {
        if let special = specialKeyNames[Int(keyCode)] {
            return special
        }
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutPointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return "#\(keyCode)"
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(layoutPointer).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let status = layoutData.withUnsafeBytes { buffer -> OSStatus in
            guard let layout = buffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else {
                return OSStatus(paramErr)
            }
            return UCKeyTranslate(
                layout,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                characters.count,
                &length,
                &characters
            )
        }
        guard status == noErr, length > 0 else {
            return "#\(keyCode)"
        }
        return String(utf16CodeUnits: characters, count: length).uppercased()
    }
}

// MARK: - ShortcutAction

/// Actions that can be bound to global shortcuts.
public enum ShortcutAction: String, CaseIterable, Identifiable, Sendable {
    case toggleLens
    case holdOriginal
    case nextPreset
    case previousPreset
    case toggleControls

    public var id: Self { self }

    public var title: String {
        switch self {
        case .toggleLens: "Show/Hide Lens"
        case .holdOriginal: "Hold to Show Original Colors"
        case .nextPreset: "Next Simulation"
        case .previousPreset: "Previous Simulation"
        case .toggleControls: "Show/Hide Lens Controls"
        }
    }

    /// Stable identifier passed to Carbon.
    var hotKeyID: UInt32 {
        UInt32(Self.allCases.firstIndex(of: self) ?? 0) + 1
    }

    static func action(forHotKeyID id: UInt32) -> ShortcutAction? {
        let index = Int(id) - 1
        guard allCases.indices.contains(index) else {
            return nil
        }
        return allCases[index]
    }

    private static let controlOptionCommand = UInt32(controlKey | optionKey | cmdKey)

    public static let defaultShortcuts: [String: HotKey] = [
        ShortcutAction.toggleLens.rawValue: HotKey(keyCode: UInt32(kVK_ANSI_L), carbonModifiers: controlOptionCommand),
        ShortcutAction.holdOriginal.rawValue: HotKey(keyCode: UInt32(kVK_ANSI_O), carbonModifiers: controlOptionCommand),
        ShortcutAction.nextPreset.rawValue: HotKey(keyCode: UInt32(kVK_ANSI_RightBracket), carbonModifiers: controlOptionCommand),
        ShortcutAction.previousPreset.rawValue: HotKey(keyCode: UInt32(kVK_ANSI_LeftBracket), carbonModifiers: controlOptionCommand),
        ShortcutAction.toggleControls.rawValue: HotKey(keyCode: UInt32(kVK_ANSI_H), carbonModifiers: controlOptionCommand)
    ]
}
