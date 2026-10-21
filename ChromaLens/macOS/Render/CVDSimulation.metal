//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//
//  Color contract: the captured texture holds 8-bit sRGB-encoded values
//  (BGRA, sampled as non-sRGB so no implicit decoding happens). The fragment
//  shader decodes to linear sRGB, applies the 3x3 simulation matrix, clamps,
//  re-encodes to sRGB and mixes with the original by `blend`. The drawable is
//  tagged sRGB so the compositor converts to the display's color space.
//
//  Must stay in sync with ColorVisionKit's `CPUReference` and `LensUniforms`.
//

#include <metal_stdlib>
using namespace metal;

struct LensUniforms {
    float3x3 matrix;
    float2 uvOrigin;
    float2 uvSize;
    float blend;
};

struct LensVertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex LensVertexOut lensVertex(uint vertexID [[vertex_id]]) {
    const float2 positions[4] = { float2(-1, -1), float2(1, -1), float2(-1, 1), float2(1, 1) };
    const float2 texCoords[4] = { float2(0, 1), float2(1, 1), float2(0, 0), float2(1, 0) };
    LensVertexOut out;
    out.position = float4(positions[vertexID], 0, 1);
    out.texCoord = texCoords[vertexID];
    return out;
}

static float3 srgbToLinear(float3 c) {
    return select(pow((c + 0.055) / 1.055, 2.4), c / 12.92, c <= 0.04045);
}

static float3 linearToSrgb(float3 c) {
    return select(1.055 * pow(c, 1.0 / 2.4) - 0.055, c * 12.92, c <= 0.0031308);
}

static float3 simulateColor(float3 srgb, float3x3 matrix, float blend) {
    float3 simulated = linearToSrgb(clamp(matrix * srgbToLinear(srgb), 0.0, 1.0));
    return mix(simulated, srgb, blend);
}

fragment float4 lensFragment(LensVertexOut in [[stage_in]],
                             texture2d<float> frame [[texture(0)]],
                             constant LensUniforms &uniforms [[buffer(0)]]) {
    float2 uv = uniforms.uvOrigin + in.texCoord * uniforms.uvSize;
    if (any(uv < 0.0) || any(uv > 1.0)) {
        // Part of the lens outside the captured region (e.g. while dragging
        // across displays): neutral diagonal hatch instead of stale pixels.
        float shade = fmod(in.position.x + in.position.y, 16.0) < 8.0 ? 0.40 : 0.47;
        return float4(shade, shade, shade, 1.0);
    }
    constexpr sampler frameSampler(coord::normalized, filter::linear, address::clamp_to_edge);
    float3 srgb = frame.sample(frameSampler, uv).rgb;
    return float4(simulateColor(srgb, uniforms.matrix, uniforms.blend), 1.0);
}
