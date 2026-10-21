//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import simd
@testable import ColorVisionKit

private func approximatelyEqual(_ a: SIMD3<Float>, _ b: SIMD3<Float>, tolerance: Float) -> Bool {
    simd_reduce_max(simd_abs(a - b)) <= tolerance
}

private func approximatelyEqual(_ a: simd_float3x3, _ b: simd_float3x3, tolerance: Float = 1e-6) -> Bool {
    approximatelyEqual(a.columns.0, b.columns.0, tolerance: tolerance)
        && approximatelyEqual(a.columns.1, b.columns.1, tolerance: tolerance)
        && approximatelyEqual(a.columns.2, b.columns.2, tolerance: tolerance)
}

private func row(_ matrix: simd_float3x3, _ index: Int) -> SIMD3<Float> {
    SIMD3(matrix.columns.0[index], matrix.columns.1[index], matrix.columns.2[index])
}

@Suite("Presets")
struct PresetTests {

    @Test func everyPresetResolvesToItsAlgorithm() throws {
        let expected: [CVDPreset: (CVDFamily, CVDSlider, Double?)] = [
            .normal: (.none, .none, nil),
            .deuteranomaly: (.deutan, .simulationSeverity, nil),
            .deuteranopia: (.deutan, .none, 1.0),
            .protanomaly: (.protan, .simulationSeverity, nil),
            .protanopia: (.protan, .none, 1.0),
            .tritanomaly: (.tritan, .simulationSeverity, nil),
            .tritanopia: (.tritan, .none, 1.0),
            .achromatomaly: (.achromatic, .desaturationAmount, nil),
            .achromatopsia: (.achromatic, .none, nil)
        ]
        #expect(CVDPreset.allCases.count == 9)
        for preset in CVDPreset.allCases {
            let (family, slider, severity) = try #require(expected[preset])
            #expect(preset.family == family, "\(preset)")
            #expect(preset.slider == slider, "\(preset)")
            #expect(preset.fixedSeverity == severity, "\(preset)")
            #expect(preset.isApproximation == (family == .achromatic))
        }
    }

    @Test func cyclingWrapsAround() {
        #expect(CVDPreset.normal.previous == .achromatopsia)
        #expect(CVDPreset.achromatopsia.next == .normal)
        for preset in CVDPreset.allCases {
            #expect(preset.next.previous == preset)
        }
    }

    @Test func dichromacyIgnoresSeveritySlider() {
        let low = SimulationParameters(preset: .deuteranopia, anomalySeverity: 0.1)
        let high = SimulationParameters(preset: .deuteranopia, anomalySeverity: 0.9)
        #expect(approximatelyEqual(low.matrix, MachadoModel.table(for: .deutan)[10]))
        #expect(approximatelyEqual(low.matrix, high.matrix))
    }

    @Test func anomalySeverityIsClampedToSliderRange() {
        let tooLow = SimulationParameters(preset: .protanomaly, anomalySeverity: 0)
        #expect(approximatelyEqual(tooLow.matrix, MachadoModel.table(for: .protan)[1], tolerance: 1e-5))
    }
}

@Suite("Machado model")
struct MachadoModelTests {

    @Test func tableHasElevenStepsPerDeficiency() {
        for deficiency in MachadoModel.Deficiency.allCases {
            #expect(MachadoModel.table(for: deficiency).count == 11)
        }
    }

    @Test func severityZeroIsIdentity() {
        for deficiency in MachadoModel.Deficiency.allCases {
            #expect(approximatelyEqual(MachadoModel.matrix(for: deficiency, severity: 0), matrix_identity_float3x3))
        }
    }

    @Test func publishedValuesSpotCheck() {
        let protanopia = MachadoModel.matrix(for: .protan, severity: 1)
        #expect(approximatelyEqual(row(protanopia, 0), SIMD3(0.152286, 1.052583, -0.204868), tolerance: 1e-6))
        let deuteranomaly = MachadoModel.matrix(for: .deutan, severity: 0.6)
        #expect(approximatelyEqual(row(deuteranomaly, 1), SIMD3(0.205199, 0.754872, 0.039929), tolerance: 1e-6))
        let tritanopia = MachadoModel.matrix(for: .tritan, severity: 1)
        #expect(approximatelyEqual(row(tritanopia, 2), SIMD3(0.004733, 0.691367, 0.303900), tolerance: 1e-6))
    }

    @Test func interpolatesBetweenSteps() {
        let table = MachadoModel.table(for: .deutan)
        let midpoint = MachadoModel.matrix(for: .deutan, severity: 0.65)
        let expected = table[6] * 0.5 + table[7] * 0.5
        #expect(approximatelyEqual(midpoint, expected, tolerance: 1e-5))
    }

    @Test func rowsSumToOne() {
        for deficiency in MachadoModel.Deficiency.allCases {
            for matrix in MachadoModel.table(for: deficiency) {
                for index in 0..<3 {
                    #expect(abs(simd_reduce_add(row(matrix, index)) - 1) < 1e-4)
                }
            }
        }
    }
}

@Suite("CPU reference")
struct CPUReferenceTests {

    @Test func transferFunctionsRoundTrip() {
        for step in 0...255 {
            let value = Float(step) / 255
            let roundTrip = ColorTransfer.encoded(fromLinear: ColorTransfer.linear(fromEncoded: value))
            #expect(abs(roundTrip - value) < 1e-5)
        }
    }

    @Test func normalIsIdentity() {
        let parameters = SimulationParameters(preset: .normal)
        for step in stride(from: 0, through: 255, by: 15) {
            let value = Float(step) / 255
            let color = SIMD3<Float>(value, 1 - value, value * 0.5)
            #expect(approximatelyEqual(CPUReference.simulate(srgb: color, parameters: parameters), color, tolerance: 1e-5))
        }
    }

    @Test func neutralsGainNoHueCast() {
        for preset in CVDPreset.allCases {
            for severity in [0.1, 0.5, 0.9] {
                let parameters = SimulationParameters(preset: preset, anomalySeverity: severity, desaturation: severity)
                for step in stride(from: 0, through: 255, by: 5) {
                    let gray = SIMD3<Float>(repeating: Float(step) / 255)
                    let output = CPUReference.simulate(srgb: gray, parameters: parameters)
                    #expect(simd_reduce_max(output) - simd_reduce_min(output) < 1.0 / 255, "\(preset) \(severity) \(step)")
                    #expect(abs(output.x - gray.x) < 1.0 / 255, "\(preset) \(severity) \(step)")
                }
            }
        }
    }

    @Test func achromatopsiaChannelsAreEqual() {
        let parameters = SimulationParameters(preset: .achromatopsia)
        for color in [SIMD3<Float>(1, 0, 0), SIMD3(0, 1, 0), SIMD3(0, 0, 1), SIMD3(0.8, 0.3, 0.6)] {
            let output = CPUReference.simulate(srgb: color, parameters: parameters)
            #expect(simd_reduce_max(output) - simd_reduce_min(output) < 1e-5)
        }
    }

    @Test func achromatomalyMovesMonotonicallyTowardGray() {
        let color = SIMD3<Float>(0.9, 0.2, 0.3)
        var previousSpread = Float.greatestFiniteMagnitude
        for amount in stride(from: 0.1, through: 0.9, by: 0.1) {
            let output = CPUReference.simulate(srgb: color, parameters: SimulationParameters(preset: .achromatomaly, desaturation: amount))
            let spread = simd_reduce_max(output) - simd_reduce_min(output)
            #expect(spread < previousSpread)
            previousSpread = spread
        }
    }

    @Test func blendMixesWithOriginal() {
        let color = SIMD3<Float>(0.9, 0.2, 0.3)
        let simulated = CPUReference.simulate(srgb: color, parameters: SimulationParameters(preset: .protanopia))
        let half = CPUReference.simulate(srgb: color, parameters: SimulationParameters(preset: .protanopia, compareBlend: 0.5))
        let original = CPUReference.simulate(srgb: color, parameters: SimulationParameters(preset: .protanopia, compareBlend: 0.2, showOriginal: true))
        #expect(approximatelyEqual(half, (simulated + color) / 2, tolerance: 1e-5))
        #expect(approximatelyEqual(original, color, tolerance: 1e-6))
    }

    /// Fixed fixtures: pure primaries through the dichromacy presets.
    /// Expected values computed independently from the published 1.0
    /// matrices (linearize, multiply, clamp, encode).
    @Test func primaryFixtures() {
        let fixtures: [(CVDPreset, SIMD3<Float>, SIMD3<Float>)] = [
            (.protanopia, SIMD3(1, 0, 0), SIMD3(0.4266, 0.3727, 0.0)),
            (.deuteranopia, SIMD3(1, 0, 0), SIMD3(0.6401, 0.5658, 0.0)),
            (.tritanopia, SIMD3(0, 0, 1), SIMD3(0.0, 0.4204, 0.5873)),
            (.protanopia, SIMD3(0, 1, 0), SIMD3(1.0, 0.8994, 0.0)),
            (.deuteranopia, SIMD3(0, 0, 1), SIMD3(0.0, 0.2412, 0.9862))
        ]
        for (preset, input, expected) in fixtures {
            let output = CPUReference.simulate(srgb: input, parameters: SimulationParameters(preset: preset))
            #expect(approximatelyEqual(output, expected, tolerance: 1.0 / 255), "\(preset) \(input) → \(output)")
        }
    }
}

@Suite("Frame stats")
struct FrameStatsTests {

    @Test func percentilesAndFPS() {
        var stats = FrameStats(capacity: 100)
        for index in 0..<100 {
            stats.recordPresented(latency: Double(index + 1) / 1000, presentTime: Double(index) / 60)
        }
        #expect(abs(stats.medianLatency - 0.050) < 1e-9)
        #expect(abs(stats.p95Latency - 0.095) < 1e-9)
        #expect(abs(stats.framesPerSecond - 60) < 1e-6)
    }

    @Test func ringBufferKeepsNewest() {
        var stats = FrameStats(capacity: 4)
        for index in 0..<10 {
            stats.recordPresented(latency: Double(index), presentTime: Double(index))
        }
        #expect(stats.percentile(0) == 6)
        #expect(stats.percentile(1) == 9)
    }
}
