//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Sparkle
import SwiftUI

// MARK: - LensMenuBarExtra

struct LensMenuBarExtra: Scene {

    let updater: SPUUpdater

    var body: some Scene {
        MenuBarExtra {
            LensMenuBarPopup(updater: updater)
                .appEnvironment(.default)
        } label: {
            LensMenuBarIcon()
                .appEnvironment(.default)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - LensMenuBarIcon

private struct LensMenuBarIcon: View {

    @Environment(LensCoordinator.self) private var coordinator

    var body: some View {
        Image(systemName: coordinator.captureState.isCapturing ? "eye.circle.fill" : "eye.circle")
            .accessibilityLabel("ChromaLens, \(coordinator.captureState.description)")
    }
}
