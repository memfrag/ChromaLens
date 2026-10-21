//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import SwiftUI
import AppRouting

/// An application-wide environment container.
///
/// This type centralizes access to shared app state and dependencies that are safe to
/// read from anywhere in the app, such as `AppSettings`. Prefer injecting instances via
/// SwiftUI's `@Environment`.
///
/// Use ``AppEnvironment/shared`` for the process-global environment that is created
/// lazily at launch based on build configuration and the `APP_ENVIRONMENT` process
/// environment variable.
///
/// - Important: Avoid creating your own instances unless you are writing previews or tests.
///
public final class AppEnvironment {

    // MARK: - Properties

    /// Application settings used throughout the app.
    public let appSettings: AppSettings
    
    /// Engineering mode
    internal let engineeringMode: EngineeringMode

    /// Owns the lens, capture and shortcuts.
    internal let lensCoordinator: LensCoordinator

    // MARK: - Init

    /// Creates an environment with the provided dependencies.
    ///
    /// - Parameters:
    ///    - appSettings: The application settings to expose.
    ///    - engineeringMode: The engineering mode state.
    /// - Note: Use ``live()``/``mock()`` rather than this initializer.
    ///
    internal init(
        appSettings: AppSettings,
        engineeringMode: EngineeringMode
    ) {
        self.appSettings = appSettings
        self.engineeringMode = engineeringMode
        self.lensCoordinator = LensCoordinator(settings: appSettings, engineeringMode: engineeringMode)
    }
}
