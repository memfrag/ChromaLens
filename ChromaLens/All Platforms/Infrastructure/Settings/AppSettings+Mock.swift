//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import KeyValueStore

// MARK: - Mock Store

#if DEBUG

extension AppSettings {

    @MainActor public static func mock() -> AppSettings {
        let store = InMemoryKeyValueStore(keyedBy: Key.self, initialContent: [
            .colorScheme: AppColorScheme.system,
            .hasCompletedOnboarding: true
        ])
        return AppSettings(store: store.eraseToAnyKeyValueStore())
    }
}

#endif
