//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

// MARK: - FrameStats

/// Rolling capture-to-present statistics for the performance HUD.
public struct FrameStats: Sendable, Equatable {

    public let capacity: Int

    private var latencies: [Double] = []
    private var presentTimes: [Double] = []
    private var nextLatencyIndex = 0
    private var nextPresentIndex = 0

    /// Frames dropped before rendering (newest-frame-wins policy).
    public private(set) var droppedFrames: Int = 0

    public init(capacity: Int = 240) {
        self.capacity = max(capacity, 2)
    }

    /// Records a presented frame.
    ///
    /// - Parameters:
    ///   - latency: Seconds from capture to presentation.
    ///   - presentTime: Presentation time in seconds (monotonic clock).
    ///
    public mutating func recordPresented(latency: Double, presentTime: Double) {
        Self.insert(latency, into: &latencies, index: &nextLatencyIndex, capacity: capacity)
        Self.insert(presentTime, into: &presentTimes, index: &nextPresentIndex, capacity: capacity)
    }

    public mutating func recordDropped(count: Int = 1) {
        droppedFrames += count
    }

    public mutating func reset() {
        self = FrameStats(capacity: capacity)
    }

    /// Frames per second over the recorded window.
    public var framesPerSecond: Double {
        guard presentTimes.count >= 2,
              let first = presentTimes.min(),
              let last = presentTimes.max(),
              last > first else {
            return 0
        }
        return Double(presentTimes.count - 1) / (last - first)
    }

    /// Median latency in seconds.
    public var medianLatency: Double { percentile(0.5) }

    /// 95th percentile latency in seconds.
    public var p95Latency: Double { percentile(0.95) }

    /// Nearest-rank percentile of recorded latencies, `0` when empty.
    public func percentile(_ fraction: Double) -> Double {
        guard !latencies.isEmpty else {
            return 0
        }
        let sorted = latencies.sorted()
        let rank = Int((fraction * Double(sorted.count)).rounded(.up))
        return sorted[min(max(rank - 1, 0), sorted.count - 1)]
    }

    private static func insert(_ value: Double, into buffer: inout [Double], index: inout Int, capacity: Int) {
        if buffer.count < capacity {
            buffer.append(value)
        } else {
            buffer[index] = value
        }
        index = (index + 1) % capacity
    }
}
