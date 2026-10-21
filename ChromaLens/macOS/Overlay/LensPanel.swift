//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - LensPanel

/// Borderless, non-activating floating panel used for every lens window.
/// The render panel ignores mouse events entirely (click-through); the
/// toolbar and border panels are interactive.
final class LensPanel: NSPanel {

    private let isInteractive: Bool

    init(isInteractive: Bool) {
        self.isInteractive = isInteractive
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = !isInteractive
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
        animationBehavior = .none
        becomesKeyOnlyIfNeeded = true
    }

    override var canBecomeKey: Bool { isInteractive }

    override var canBecomeMain: Bool { false }
}

// MARK: - FirstMouseHostingView

/// Hosting view whose controls respond to the first click even though the
/// panel isn't key and the app isn't active.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
