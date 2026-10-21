//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import ColorVisionKit
import SwiftUI

struct GeneralSettingsTab: View {
    
    @Environment(AppSettings.self) private var settings
    
    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Picker("Stop capture after hiding the lens:", selection: $settings.captureStopGrace) {
                    ForEach(CaptureStopGrace.allCases) { grace in
                        Text(grace.description).tag(grace)
                    }
                }
                Text("""
                Keeping capture running briefly makes showing the lens again instant. \
                macOS shows the screen recording indicator while capture runs.
                """)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
    }
}

#if DEBUG
#Preview {
    GeneralSettingsTab()
        .previewEnvironment()
}
#endif
