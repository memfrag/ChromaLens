//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import MarkdownUI
import SwiftUI

public struct HelpWindow: Scene {

    public static let windowID = "help"
            
    public var body: some Scene {
        Window("ChromaLens Help", id: Self.windowID) {
            HelpView()
                .frame(minWidth: 560, minHeight: 420)
        }
        .commandsRemoved() // Don't show window in Windows menu
        .defaultPosition(.center)
        .defaultSize(width: 680, height: 720)
        .windowResizability(.contentMinSize)
    }
}

// MARK: - HelpView

/// Renders the bundled `Help.md`: an introduction to color vision
/// deficiency and each type, how to use the lens, the simulation model,
/// privacy and known limitations.
private struct HelpView: View {

    private static let document: MarkdownDocument? = {
        guard let url = Bundle.main.url(forResource: "Help", withExtension: "md"),
              let markdown = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        return try? MarkdownDocument(markdown)
    }()

    var body: some View {
        ScrollView {
            if let document = Self.document {
                Markdown(document, lazy: true)
                    .textSelection(.enabled)
                    .padding(24)
                    .frame(maxWidth: 760, alignment: .leading)
                    .frame(maxWidth: .infinity)
            } else {
                Text("Help is unavailable.")
                    .padding(24)
            }
        }
    }
}
