//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import simd

// MARK: - SimulationParameters

/// Everything that determines the per-pixel transform, independent of geometry.
public struct SimulationParameters: Equatable, Sendable {

    public var preset: CVDPreset

    /// Machado severity used by `-omaly` presets (ignored otherwise).
    public var anomalySeverity: Double

    /// Desaturation amount used by achromatomaly (ignored otherwise).
    public var desaturation: Double

    /// Visual mix with the original, `0` = fully simulated, `1` = original.
    public var compareBlend: Double

    /// When `true`, the original is shown regardless of ``compareBlend``.
    public var showOriginal: Bool

    public init(
        preset: CVDPreset,
        anomalySeverity: Double = CVDSlider.defaultValue,
        desaturation: Double = CVDSlider.defaultValue,
        compareBlend: Double = 0,
        showOriginal: Bool = false
    ) {
        self.preset = preset
        self.anomalySeverity = anomalySeverity
        self.desaturation = desaturation
        self.compareBlend = compareBlend
        self.showOriginal = showOriginal
    }

    /// The linear-sRGB matrix for the preset.
    public var matrix: simd_float3x3 {
        switch preset {
        case .normal:
            return matrix_identity_float3x3
        case .achromatopsia:
            return Self.luminanceMatrix
        case .achromatomaly:
            let amount = Float(CVDSlider.clamp(desaturation))
            return matrix_identity_float3x3 * (1 - amount) + Self.luminanceMatrix * amount
        case .deuteranomaly, .deuteranopia, .protanomaly, .protanopia, .tritanomaly, .tritanopia:
            guard let deficiency = preset.machadoDeficiency else {
                return matrix_identity_float3x3
            }
            let severity = preset.fixedSeverity ?? CVDSlider.clamp(anomalySeverity)
            return MachadoModel.matrix(for: deficiency, severity: severity)
        }
    }

    /// The effective blend factor, `0` = simulated, `1` = original.
    public var blend: Float {
        showOriginal ? 1 : Float(min(max(compareBlend, 0), 1))
    }

    /// A matrix mapping linear RGB to its luminance in every channel.
    public static let luminanceMatrix: simd_float3x3 = {
        let row = ColorTransfer.luminanceCoefficients
        return simd_float3x3(rows: [row, row, row])
    }()
}
