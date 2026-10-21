//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import ColorVisionKit
import CoreVideo
import Metal
import MetalKit
import OSLog
import Synchronization

// MARK: - LensRenderer

/// Draws the newest captured frame into the lens `MTKView`, cropped to the
/// lens and transformed by the simulation shader. Redraws only when a new
/// frame arrives or parameters/geometry change.
@MainActor final class LensRenderer: NSObject, MTKViewDelegate {

    /// Simulation parameters; changing them triggers a redraw.
    var parameters: SimulationParameters {
        didSet {
            if parameters != oldValue {
                matrix = parameters.matrix
                needsRedraw = true
            }
        }
    }

    /// The lens content rect in global coordinates.
    var lensContentRect: CGRect = .zero {
        didSet {
            if lensContentRect != oldValue {
                needsRedraw = true
            }
        }
    }

    /// When `false`, the view is cleared instead of showing captured content
    /// (capture paused, permission missing, switching display).
    var showsFrames = true {
        didSet {
            if showsFrames != oldValue {
                needsRedraw = true
            }
        }
    }

    private let frameBox: LatestFrameBox
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let textureCache: CVMetalTextureCache
    private var matrix: simd_float3x3
    private var lastFrame: CaptureFrame?
    private var needsRedraw = true

    private let statsStore = StatsStore()

    /// A snapshot of rendering statistics for the performance HUD.
    var stats: FrameStats {
        let dropped = frameBox.takeDroppedCount()
        return statsStore.stats.withLock { stats in
            stats.recordDropped(count: dropped)
            return stats
        }
    }

    init?(view: MTKView, frameBox: LatestFrameBox, parameters: SimulationParameters) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary() else {
            Logger.render.error("Metal is unavailable")
            return nil
        }
        var cache: CVMetalTextureCache?
        guard CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cache) == kCVReturnSuccess,
              let cache else {
            Logger.render.error("Could not create texture cache")
            return nil
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "lensVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "lensFragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        do {
            pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            Logger.render.error("Pipeline creation failed: \(error.localizedDescription)")
            return nil
        }

        self.device = device
        self.commandQueue = commandQueue
        self.textureCache = cache
        self.frameBox = frameBox
        self.parameters = parameters
        self.matrix = parameters.matrix
        super.init()

        view.device = device
        view.colorPixelFormat = .bgra8Unorm
        view.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        view.framebufferOnly = true
        view.preferredFramesPerSecond = 60
        view.enableSetNeedsDisplay = false
        view.isPaused = true
        view.autoResizeDrawable = true
        view.clearColor = MTLClearColor(red: 0.16, green: 0.16, blue: 0.17, alpha: 1)
        view.delegate = self
    }

    func resetStats() {
        _ = frameBox.takeDroppedCount()
        statsStore.stats.withLock { $0.reset() }
    }

    // MARK: MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        needsRedraw = true
    }

    func draw(in view: MTKView) {
        let (newFrame, isNew) = frameBox.take()
        lastFrame = newFrame
        guard isNew || needsRedraw else {
            return
        }
        needsRedraw = false

        guard let passDescriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else {
            return
        }

        var frameTexture: CVMetalTexture?
        if showsFrames, let frame = lastFrame, let texture = makeTexture(frame.pixelBuffer, cvTexture: &frameTexture) {
            let crop = LensGeometry.textureCrop(
                lensContent: lensContentRect,
                capturedRect: frame.region.rect,
                screenFrame: frame.region.screenFrame
            )
            var uniforms = LensUniforms(
                matrix: matrix,
                uvOrigin: crop.uvOrigin,
                uvSize: crop.uvSize,
                blend: parameters.blend
            )
            encoder.setRenderPipelineState(pipeline)
            encoder.setFragmentTexture(texture, index: 0)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<LensUniforms>.stride, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

            if isNew {
                let captureTime = frame.captureTime
                drawable.addPresentedHandler { [statsStore] presented in
                    let presentedTime = presented.presentedTime
                    guard presentedTime > 0 else {
                        return
                    }
                    statsStore.stats.withLock { stats in
                        stats.recordPresented(latency: presentedTime - captureTime, presentTime: presentedTime)
                    }
                }
            }
        }
        encoder.endEncoding()

        // Keep the CoreVideo texture alive until the GPU is done with it.
        let retainedTexture = RetainedTexture(texture: frameTexture)
        commandBuffer.addCompletedHandler { _ in
            _ = retainedTexture
        }
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func makeTexture(_ pixelBuffer: CVPixelBuffer, cvTexture: inout CVMetalTexture?) -> MTLTexture? {
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            CVPixelBufferGetWidth(pixelBuffer),
            CVPixelBufferGetHeight(pixelBuffer),
            0,
            &cvTexture
        )
        guard status == kCVReturnSuccess, let cvTexture else {
            return nil
        }
        return CVMetalTextureGetTexture(cvTexture)
    }
}

// MARK: - Helpers

/// Thread-safe statistics shared with the drawable presented handler.
private nonisolated final class StatsStore: Sendable {
    let stats = Mutex(FrameStats())
}

/// Keeps a CoreVideo texture alive until a command buffer completes.
private nonisolated struct RetainedTexture: @unchecked Sendable {
    let texture: CVMetalTexture?
}

// MARK: - Logger

extension Logger {
    static let render = Logger(subsystem: "io.apparata.ChromaLens", category: "Render")
}
