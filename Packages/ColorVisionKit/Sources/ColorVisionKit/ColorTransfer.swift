//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import simd

// MARK: - ColorTransfer

/// sRGB transfer functions and luminance, as used by the renderer's color
/// contract: captured frames are 8-bit sRGB, simulation happens in linear
/// sRGB, results are re-encoded to sRGB.
public enum ColorTransfer {

    /// Rec. 709 / sRGB luminance coefficients for linear RGB.
    public static let luminanceCoefficients = SIMD3<Float>(0.2126, 0.7152, 0.0722)

    /// sRGB EOTF: encoded value to linear light.
    public static func linear(fromEncoded value: Float) -> Float {
        value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }

    /// sRGB inverse EOTF: linear light to encoded value.
    public static func encoded(fromLinear value: Float) -> Float {
        value <= 0.0031308 ? value * 12.92 : 1.055 * pow(value, 1 / 2.4) - 0.055
    }

    public static func linear(fromEncoded rgb: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3(linear(fromEncoded: rgb.x), linear(fromEncoded: rgb.y), linear(fromEncoded: rgb.z))
    }

    public static func encoded(fromLinear rgb: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3(encoded(fromLinear: rgb.x), encoded(fromLinear: rgb.y), encoded(fromLinear: rgb.z))
    }
}
