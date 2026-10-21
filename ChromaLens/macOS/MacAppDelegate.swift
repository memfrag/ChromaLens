//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI

class MacAppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppEnvironment.default.lensCoordinator.start()
    }

    // ChromaLens lives in the menu bar; closing windows never quits it.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
