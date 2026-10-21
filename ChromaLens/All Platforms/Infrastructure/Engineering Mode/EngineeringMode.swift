//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import KeyValueStore

@Observable final class EngineeringMode {
    
    private enum Key: String {
        case showPerformanceHUD
    }

    /// Shows fps and capture-to-present latency over the lens.
    var showPerformanceHUD: Bool {
        didSet {
            store.save(showPerformanceHUD, for: .showPerformanceHUD)
        }
    }

    private(set) var isEnabled: Bool = false
    
    private let store = UserDefaultsStore(keyedBy: Key.self, prefixedBy: "EngineeringMode")

    #if !os(macOS)    
    private let appStateObserver = AppStateObserver()
    #endif

    private init() {
        showPerformanceHUD = store.load(.showPerformanceHUD, default: false)
        updateEnabledStatus()
    }

    /// Enables engineering mode for the rest of the session. Used by the
    /// hidden ⌥-click reveal in Release builds.
    func reveal() {
        isEnabled = true
    }
    
    // MARK: Enabled Status Changes

    #if !os(macOS)
    private func observeEnabledStatusChanges() {
        appStateObserver.appDidBecomeActive = { [weak self] in
            self?.updateEnabledStatus()
        }
    }
    #endif
    
    private func updateEnabledStatus() {
        #if DEBUG
        isEnabled = true
        #else
        isEnabled = false
        #endif
    }
}

// MARK: - Singleton

extension EngineeringMode {
    /// When possible, use `@Environment(EngineeringMode.self)` rather than
    /// accessing the `shared` property directly.
    static let shared = EngineeringMode()
}
