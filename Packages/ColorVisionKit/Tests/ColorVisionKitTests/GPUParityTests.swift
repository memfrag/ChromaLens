//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
import Metal
import simd
@testable import ColorVisionKit

/// Compiles the app's shader source and checks it against `CPUReference`.
@Suite("GPU parity")
struct GPUParityTests {

    static let shaderURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // ColorVisionKitTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // ColorVisionKit
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // repository root
        .appendingPathComponent("ChromaLens/macOS/Render/CVDSimulation.metal")

    static let side = 8

    /// Deterministic sRGB fixture colors, one per texel.
    static let fixture: [SIMD3<UInt8>] = (0..<(side * side)).map { index in
        let r = UInt8((index * 37) % 256)
        let g = UInt8((index * 91 + 40) % 256)
        let b = UInt8((index * 53 + 200) % 256)
        return SIMD3(r, g, b)
    }

    @Test(.enabled(if: MTLCreateSystemDefaultDevice() != nil))
    func shaderMatchesCPUReference() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let source = try String(contentsOf: Self.shaderURL, encoding: .utf8)
        let library = try device.makeLibrary(source: source, options: nil)

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "lensVertex")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "lensFragment")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .rgba32Float
        let pipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)

        let input = try makeInputTexture(device: device)
        let outputDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba32Float, width: Self.side, height: Self.side, mipmapped: false
        )
        outputDescriptor.usage = [.renderTarget, .shaderRead]
        outputDescriptor.storageMode = .shared
        let output = try #require(device.makeTexture(descriptor: outputDescriptor))
        let queue = try #require(device.makeCommandQueue())

        for preset in CVDPreset.allCases {
            for blend in [0.0, 0.35] {
                let parameters = SimulationParameters(preset: preset, anomalySeverity: 0.45, desaturation: 0.7, compareBlend: blend)
                var uniforms = LensUniforms(matrix: parameters.matrix, blend: parameters.blend)

                let pass = MTLRenderPassDescriptor()
                pass.colorAttachments[0].texture = output
                pass.colorAttachments[0].loadAction = .clear
                pass.colorAttachments[0].storeAction = .store
                let commandBuffer = try #require(queue.makeCommandBuffer())
                let encoder = try #require(commandBuffer.makeRenderCommandEncoder(descriptor: pass))
                encoder.setRenderPipelineState(pipeline)
                encoder.setFragmentTexture(input, index: 0)
                encoder.setFragmentBytes(&uniforms, length: MemoryLayout<LensUniforms>.stride, index: 0)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
                encoder.endEncoding()
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()

                var pixels = [SIMD4<Float>](repeating: .zero, count: Self.side * Self.side)
                output.getBytes(
                    &pixels,
                    bytesPerRow: Self.side * MemoryLayout<SIMD4<Float>>.stride,
                    from: MTLRegionMake2D(0, 0, Self.side, Self.side),
                    mipmapLevel: 0
                )

                for (index, color) in Self.fixture.enumerated() {
                    let srgb = SIMD3<Float>(color) / 255
                    let expected = CPUReference.simulate(srgb: srgb, parameters: parameters)
                    let gpu = SIMD3(pixels[index].x, pixels[index].y, pixels[index].z)
                    let difference = simd_reduce_max(simd_abs(gpu - expected))
                    #expect(difference <= 1.0 / 255, "\(preset) blend \(blend) texel \(index): gpu \(gpu) cpu \(expected)")
                }
            }
        }
    }

    @Test func uniformLayoutMatchesShader() {
        #expect(MemoryLayout<LensUniforms>.offset(of: \.uvOrigin) == 48)
        #expect(MemoryLayout<LensUniforms>.offset(of: \.uvSize) == 56)
        #expect(MemoryLayout<LensUniforms>.offset(of: \.blend) == 64)
        #expect(MemoryLayout<LensUniforms>.stride == 80)
    }

    private func makeInputTexture(device: MTLDevice) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: Self.side, height: Self.side, mipmapped: false
        )
        descriptor.usage = .shaderRead
        let texture = try #require(device.makeTexture(descriptor: descriptor))
        var bytes = [UInt8]()
        for color in Self.fixture {
            bytes.append(contentsOf: [color.z, color.y, color.x, 255])
        }
        texture.replace(
            region: MTLRegionMake2D(0, 0, Self.side, Self.side),
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: Self.side * 4
        )
        return texture
    }
}
