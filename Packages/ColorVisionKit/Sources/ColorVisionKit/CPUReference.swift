//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import simd

// MARK: - CPUReference

/// The reference implementation of the per-pixel transform. The Metal shader
/// must produce the same results (verified by the GPU parity test).
public enum CPUReference {

    /// Transforms one sRGB-encoded color (components in `0...1`).
    public static func simulate(
        srgb: SIMD3<Float>,
        matrix: simd_float3x3,
        blend: Float
    ) -> SIMD3<Float> {
        let linear = ColorTransfer.linear(fromEncoded: srgb)
        let transformed = simd_clamp(matrix * linear, SIMD3<Float>(repeating: 0), SIMD3<Float>(repeating: 1))
        let simulated = ColorTransfer.encoded(fromLinear: transformed)
        return simd_mix(simulated, srgb, SIMD3<Float>(repeating: blend))
    }

    public static func simulate(srgb: SIMD3<Float>, parameters: SimulationParameters) -> SIMD3<Float> {
        simulate(srgb: srgb, matrix: parameters.matrix, blend: parameters.blend)
    }
}
