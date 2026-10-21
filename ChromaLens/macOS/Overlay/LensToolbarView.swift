//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import ColorVisionKit
import SwiftUI

// MARK: - LensToolbarView

/// Compact toolbar shown above (or below) the lens. Its background is the
/// drag handle for moving the lens.
struct LensToolbarView: View {

    @Environment(LensCoordinator.self) private var coordinator

    @State private var isShowingSliders = false

    var body: some View {
        @Bindable var coordinator = coordinator

        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Picker("Simulation", selection: $coordinator.preset) {
                ForEach(CVDPreset.allCases) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
            .accessibilityLabel("Simulation")
            .help(coordinator.preset.summary)

            if coordinator.preset.isApproximation {
                Text("Approximation")
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: Capsule())
                    .help("Achromatic modes are color-only approximations, not physiological models.")
            }

            Toggle(isOn: $coordinator.isShowingOriginal) {
                Label("Original", systemImage: coordinator.isShowingOriginal ? "eye.slash" : "eye")
                    .labelStyle(.titleAndIcon)
            }
            .toggleStyle(.button)
            .help("Show original colors")
            .accessibilityLabel("Show original colors")

            Button {
                isShowingSliders.toggle()
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .help("Adjust simulation")
            .accessibilityLabel("Adjust simulation")
            .popover(isPresented: $isShowingSliders, arrowEdge: .bottom) {
                LensSlidersView()
                    .environment(coordinator)
                    .padding(16)
                    .frame(width: 300)
            }

            Spacer(minLength: 0)

            Button {
                coordinator.areControlsHidden = true
            } label: {
                Image(systemName: "rectangle.dashed")
            }
            .help("Hide lens controls")
            .accessibilityLabel("Hide lens controls")

            Button {
                coordinator.hideLens()
            } label: {
                Image(systemName: "xmark")
            }
            .help("Hide lens")
            .accessibilityLabel("Hide lens")
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.regularMaterial)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.85), lineWidth: 1)
                DragHandle(handler: coordinator.interactionHandler)
            }
        }
    }
}
