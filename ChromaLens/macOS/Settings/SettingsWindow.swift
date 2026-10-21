//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI

/// Show settings window by using a SettingsLink SwiftUI view.
struct SettingsWindow: Scene {

    private enum Tabs: Hashable {
        case general
        case shortcuts
    }

    var body: some Scene {
        Settings {
            tabs
                .appEnvironment(.default)
        }
    }
    
    @ViewBuilder var tabs: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(Tabs.general)
            ShortcutsSettingsTab()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
                .tag(Tabs.shortcuts)
        }
        .padding(20)
        .frame(width: 520, height: 300)
    }    
}
