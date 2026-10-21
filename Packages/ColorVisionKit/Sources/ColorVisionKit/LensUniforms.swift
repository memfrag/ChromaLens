//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import simd

// MARK: - LensUniforms

/// Uniform buffer for the lens fragment shader.
///
/// - Important: Must match `struct LensUniforms` in `CVDSimulation.metal`
///   (float3x3 = 48 bytes, two float2, one float; stride 80).
///
public struct LensUniforms: Equatable, Sendable {

    /// Linear-sRGB simulation matrix.
    public var matrix: simd_float3x3

    /// Top-left of the lens within the captured texture, in UV (0...1).
    public var uvOrigin: SIMD2<Float>

    /// Size of the lens within the captured texture, in UV.
    public var uvSize: SIMD2<Float>

    /// `0` = simulated, `1` = original.
    public var blend: Float

    public init(
        matrix: simd_float3x3 = matrix_identity_float3x3,
        uvOrigin: SIMD2<Float> = .zero,
        uvSize: SIMD2<Float> = .one,
        blend: Float = 0
    ) {
        self.matrix = matrix
        self.uvOrigin = uvOrigin
        self.uvSize = uvSize
        self.blend = blend
    }
}
