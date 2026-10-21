//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import ColorVisionKit
import SwiftUI

// MARK: - LensSlidersView

/// Simulation severity / desaturation and compare blend. Physiological
/// severity, desaturation and blend are deliberately separate, labeled controls.
struct LensSlidersView: View {

    @Environment(LensCoordinator.self) private var coordinator

    var body: some View {
        @Bindable var coordinator = coordinator

        VStack(alignment: .leading, spacing: 12) {
            if coordinator.preset.slider != .none {
                LabeledSlider(
                    title: coordinator.preset.slider.label,
                    value: $coordinator.sliderValue,
                    range: CVDSlider.range
                )
            } else if coordinator.preset.fixedSeverity != nil {
                Text("Dichromacy presets use the model at full severity.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LabeledSlider(
                title: "Blend with Original",
                value: $coordinator.compareBlend,
                range: 0...1
            )

            if coordinator.preset.isApproximation {
                Text("Achromatic modes are color-only approximations, not physiological models.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - LabeledSlider

struct LabeledSlider: View {

    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(value, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            Slider(value: $value, in: range)
                .accessibilityLabel(title)
                .accessibilityValue(Text(value, format: .percent.precision(.fractionLength(0))))
        }
    }
}
