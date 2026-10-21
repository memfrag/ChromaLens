//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import AppKit
import Carbon.HIToolbox
import OSLog

// MARK: - HotKeyCenter

/// Registers system-wide shortcuts with Carbon's `RegisterEventHotKey`, which
/// works in the App Sandbox and needs no Accessibility permission. Delivers
/// both press and release so "hold to compare" can work.
@Observable @MainActor final class HotKeyCenter {

    static let shared = HotKeyCenter()

    /// Called on the main thread when a registered shortcut is pressed.
    @ObservationIgnored var onPress: ((ShortcutAction) -> Void)?

    /// Called on the main thread when a registered shortcut is released.
    @ObservationIgnored var onRelease: ((ShortcutAction) -> Void)?

    /// Actions whose shortcut could not be registered (e.g. taken by another app).
    private(set) var unavailableActions: Set<ShortcutAction> = []

    @ObservationIgnored private var registeredRefs: [ShortcutAction: EventHotKeyRef] = [:]
    @ObservationIgnored private var handlerRef: EventHandlerRef?
    @ObservationIgnored private var currentShortcuts: [String: HotKey] = [:]
    @ObservationIgnored private var isSuspended = false

    private static let signature: OSType = 0x434C_6E73 // 'CLns'

    private init() {}

    /// Replaces all registrations with `shortcuts` (keyed by action raw value).
    func register(_ shortcuts: [String: HotKey]) {
        currentShortcuts = shortcuts
        guard !isSuspended else {
            return
        }
        installHandlerIfNeeded()
        unregisterAll()

        var unavailable: Set<ShortcutAction> = []
        for action in ShortcutAction.allCases {
            guard let hotKey = shortcuts[action.rawValue] else {
                continue
            }
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: Self.signature, id: action.hotKeyID)
            let status = RegisterEventHotKey(
                hotKey.keyCode,
                hotKey.carbonModifiers,
                id,
                GetEventDispatcherTarget(),
                0,
                &ref
            )
            if status == noErr, let ref {
                registeredRefs[action] = ref
            } else {
                Logger.shortcuts.error("Could not register shortcut for \(action.rawValue): \(status)")
                unavailable.insert(action)
            }
        }
        unavailableActions = unavailable
    }

    /// Temporarily unregisters everything, e.g. while recording a new shortcut.
    func suspend() {
        isSuspended = true
        unregisterAll()
    }

    func resume() {
        isSuspended = false
        register(currentShortcuts)
    }

    private func unregisterAll() {
        for ref in registeredRefs.values {
            UnregisterEventHotKey(ref)
        }
        registeredRefs.removeAll()
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else {
            return
        }
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, _ -> OSStatus in
                guard let event else {
                    return OSStatus(eventNotHandledErr)
                }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr, hotKeyID.signature == HotKeyCenter.signature,
                      let action = ShortcutAction.action(forHotKeyID: hotKeyID.id) else {
                    return OSStatus(eventNotHandledErr)
                }
                let isPress = GetEventKind(event) == UInt32(kEventHotKeyPressed)
                // Carbon dispatches hot key events on the main thread.
                MainActor.assumeIsolated {
                    HotKeyCenter.shared.handle(action, isPress: isPress)
                }
                return noErr
            },
            eventTypes.count,
            &eventTypes,
            nil,
            &handlerRef
        )
        if status != noErr {
            Logger.shortcuts.error("Could not install hot key handler: \(status)")
        }
    }

    private func handle(_ action: ShortcutAction, isPress: Bool) {
        if isPress {
            onPress?(action)
        } else {
            onRelease?(action)
        }
    }
}

// MARK: - Logger

extension Logger {
    static let shortcuts = Logger(subsystem: "io.apparata.ChromaLens", category: "Shortcuts")
}
