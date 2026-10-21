//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import ColorVisionKit
import SwiftUI

// MARK: - LensOverlayView

/// Drawn over the lens content: capture status when not showing live
/// content, and the performance HUD when enabled.
struct LensOverlayView: View {

    @Environment(LensCoordinator.self) private var coordinator
    @Environment(EngineeringMode.self) private var engineeringMode

    var body: some View {
        ZStack {
            if coordinator.captureState != .running {
                statusLabel
            }
            if engineeringMode.isEnabled, engineeringMode.showPerformanceHUD {
                PerformanceHUDView(stats: coordinator.stats)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(6)
            }
            if coordinator.isHoldingOriginal || coordinator.isShowingOriginal {
                Text("Original Colors")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.55), in: Capsule())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(6)
            }
        }
        .allowsHitTesting(false)
    }

    private var statusLabel: some View {
        VStack(spacing: 6) {
            Image(systemName: statusIcon)
                .font(.title2)
            Text(coordinator.captureState.description)
                .font(.callout.weight(.medium))
            if coordinator.captureState == .permissionDenied {
                Text("Allow ChromaLens in System Settings › Privacy & Security › Screen & System Audio Recording.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
            }
        }
        .foregroundStyle(.white.opacity(0.85))
        .padding(12)
    }

    private var statusIcon: String {
        switch coordinator.captureState {
        case .permissionDenied: "lock.shield"
        case .paused: "pause.circle"
        case .switchingDisplay: "display.2"
        case .starting, .running, .idle: "eye"
        }
    }
}

// MARK: - PerformanceHUDView

/// Internal QA readout: frame rate, capture-to-present latency, drops.
struct PerformanceHUDView: View {

    let stats: FrameStats

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(stats.framesPerSecond, format: .number.precision(.fractionLength(1))) fps")
            Text("p50 \(stats.medianLatency * 1000, format: .number.precision(.fractionLength(1))) ms")
            Text("p95 \(stats.p95Latency * 1000, format: .number.precision(.fractionLength(1))) ms")
            Text("dropped \(stats.droppedFrames)")
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(.green)
        .padding(5)
        .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 4))
    }
}
