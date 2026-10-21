//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import AppRouting

extension AppEnvironment {

    // MARK: - Mock AppEnvironment

    #if DEBUG
    internal static func mock() -> AppEnvironment {
        AppEnvironment(
            appSettings: AppSettings.mock(),
            engineeringMode: EngineeringMode.shared
        )
    }
    #endif
}
