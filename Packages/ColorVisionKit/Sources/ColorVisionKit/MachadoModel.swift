//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import simd

// MARK: - MachadoModel

/// Severity-varying simulation of protan, deutan and tritan color vision
/// deficiencies from Machado, Oliveira & Fernandes (2009),
/// "A Physiologically-based Model for Simulation of Color Vision Deficiency",
/// IEEE TVCG 15(6). https://pubmed.ncbi.nlm.nih.gov/19834201/
///
/// The matrices are the authors' published pre-computed table (severity 0.0
/// to 1.0 in steps of 0.1), as reproduced in the colour-science dataset
/// `colour/blindness/datasets/machado2010.py` (BSD-3-Clause). They operate on
/// **linear** sRGB values. Intermediate severities are linearly interpolated
/// between adjacent table entries, as suggested by the authors.
///
public enum MachadoModel {

    /// The cone class affected by the simulated deficiency.
    public enum Deficiency: Sendable, CaseIterable {
        case protan
        case deutan
        case tritan
    }

    /// Returns the simulation matrix for linear sRGB at the given severity.
    ///
    /// - Parameters:
    ///   - deficiency: The affected cone class.
    ///   - severity: Severity in `0...1`; values outside are clamped.
    ///
    public static func matrix(for deficiency: Deficiency, severity: Double) -> simd_float3x3 {
        let table = table(for: deficiency)
        let clamped = min(max(severity, 0), 1)
        let position = clamped * Double(table.count - 1)
        let lowerIndex = Int(position.rounded(.down))
        let upperIndex = min(lowerIndex + 1, table.count - 1)
        let fraction = Float(position - Double(lowerIndex))
        if fraction < 1e-6 {
            return table[lowerIndex]
        }
        return table[lowerIndex] * (1 - fraction) + table[upperIndex] * fraction
    }

    /// The published table entries for a deficiency, index `i` = severity `i / 10`.
    public static func table(for deficiency: Deficiency) -> [simd_float3x3] {
        switch deficiency {
        case .protan: protan
        case .deutan: deutan
        case .tritan: tritan
        }
    }

    // MARK: Published Table

    /// Protanomaly matrices for severity 0.0, 0.1, ..., 1.0.
    static let protan: [simd_float3x3] = [
        // 0.0
        simd_float3x3(rows: [
            SIMD3<Float>(1.000000, 0.000000, 0.000000),
            SIMD3<Float>(0.000000, 1.000000, 0.000000),
            SIMD3<Float>(0.000000, 0.000000, 1.000000)
        ]),
        // 0.1
        simd_float3x3(rows: [
            SIMD3<Float>(0.856167, 0.182038, -0.038205),
            SIMD3<Float>(0.029342, 0.955115, 0.015544),
            SIMD3<Float>(-0.002880, -0.001563, 1.004443)
        ]),
        // 0.2
        simd_float3x3(rows: [
            SIMD3<Float>(0.734766, 0.334872, -0.069637),
            SIMD3<Float>(0.051840, 0.919198, 0.028963),
            SIMD3<Float>(-0.004928, -0.004209, 1.009137)
        ]),
        // 0.3
        simd_float3x3(rows: [
            SIMD3<Float>(0.630323, 0.465641, -0.095964),
            SIMD3<Float>(0.069181, 0.890046, 0.040773),
            SIMD3<Float>(-0.006308, -0.007724, 1.014032)
        ]),
        // 0.4
        simd_float3x3(rows: [
            SIMD3<Float>(0.539009, 0.579343, -0.118352),
            SIMD3<Float>(0.082546, 0.866121, 0.051332),
            SIMD3<Float>(-0.007136, -0.011959, 1.019095)
        ]),
        // 0.5
        simd_float3x3(rows: [
            SIMD3<Float>(0.458064, 0.679578, -0.137642),
            SIMD3<Float>(0.092785, 0.846313, 0.060902),
            SIMD3<Float>(-0.007494, -0.016807, 1.024301)
        ]),
        // 0.6
        simd_float3x3(rows: [
            SIMD3<Float>(0.385450, 0.769005, -0.154455),
            SIMD3<Float>(0.100526, 0.829802, 0.069673),
            SIMD3<Float>(-0.007442, -0.022190, 1.029632)
        ]),
        // 0.7
        simd_float3x3(rows: [
            SIMD3<Float>(0.319627, 0.849633, -0.169261),
            SIMD3<Float>(0.106241, 0.815969, 0.077790),
            SIMD3<Float>(-0.007025, -0.028051, 1.035076)
        ]),
        // 0.8
        simd_float3x3(rows: [
            SIMD3<Float>(0.259411, 0.923008, -0.182420),
            SIMD3<Float>(0.110296, 0.804340, 0.085364),
            SIMD3<Float>(-0.006276, -0.034346, 1.040622)
        ]),
        // 0.9
        simd_float3x3(rows: [
            SIMD3<Float>(0.203876, 0.990338, -0.194214),
            SIMD3<Float>(0.112975, 0.794542, 0.092483),
            SIMD3<Float>(-0.005222, -0.041043, 1.046265)
        ]),
        // 1.0
        simd_float3x3(rows: [
            SIMD3<Float>(0.152286, 1.052583, -0.204868),
            SIMD3<Float>(0.114503, 0.786281, 0.099216),
            SIMD3<Float>(-0.003882, -0.048116, 1.051998)
        ])
    ]

    /// Deuteranomaly matrices for severity 0.0, 0.1, ..., 1.0.
    static let deutan: [simd_float3x3] = [
        // 0.0
        simd_float3x3(rows: [
            SIMD3<Float>(1.000000, 0.000000, 0.000000),
            SIMD3<Float>(0.000000, 1.000000, 0.000000),
            SIMD3<Float>(0.000000, 0.000000, 1.000000)
        ]),
        // 0.1
        simd_float3x3(rows: [
            SIMD3<Float>(0.866435, 0.177704, -0.044139),
            SIMD3<Float>(0.049567, 0.939063, 0.011370),
            SIMD3<Float>(-0.003453, 0.007233, 0.996220)
        ]),
        // 0.2
        simd_float3x3(rows: [
            SIMD3<Float>(0.760729, 0.319078, -0.079807),
            SIMD3<Float>(0.090568, 0.889315, 0.020117),
            SIMD3<Float>(-0.006027, 0.013325, 0.992702)
        ]),
        // 0.3
        simd_float3x3(rows: [
            SIMD3<Float>(0.675425, 0.433850, -0.109275),
            SIMD3<Float>(0.125303, 0.847755, 0.026942),
            SIMD3<Float>(-0.007950, 0.018572, 0.989378)
        ]),
        // 0.4
        simd_float3x3(rows: [
            SIMD3<Float>(0.605511, 0.528560, -0.134071),
            SIMD3<Float>(0.155318, 0.812366, 0.032316),
            SIMD3<Float>(-0.009376, 0.023176, 0.986200)
        ]),
        // 0.5
        simd_float3x3(rows: [
            SIMD3<Float>(0.547494, 0.607765, -0.155259),
            SIMD3<Float>(0.181692, 0.781742, 0.036566),
            SIMD3<Float>(-0.010410, 0.027275, 0.983136)
        ]),
        // 0.6
        simd_float3x3(rows: [
            SIMD3<Float>(0.498864, 0.674741, -0.173604),
            SIMD3<Float>(0.205199, 0.754872, 0.039929),
            SIMD3<Float>(-0.011131, 0.030969, 0.980162)
        ]),
        // 0.7
        simd_float3x3(rows: [
            SIMD3<Float>(0.457771, 0.731899, -0.189670),
            SIMD3<Float>(0.226409, 0.731012, 0.042579),
            SIMD3<Float>(-0.011595, 0.034333, 0.977261)
        ]),
        // 0.8
        simd_float3x3(rows: [
            SIMD3<Float>(0.422823, 0.781057, -0.203881),
            SIMD3<Float>(0.245752, 0.709602, 0.044646),
            SIMD3<Float>(-0.011843, 0.037423, 0.974421)
        ]),
        // 0.9
        simd_float3x3(rows: [
            SIMD3<Float>(0.392952, 0.823610, -0.216562),
            SIMD3<Float>(0.263559, 0.690210, 0.046232),
            SIMD3<Float>(-0.011910, 0.040281, 0.971630)
        ]),
        // 1.0
        simd_float3x3(rows: [
            SIMD3<Float>(0.367322, 0.860646, -0.227968),
            SIMD3<Float>(0.280085, 0.672501, 0.047413),
            SIMD3<Float>(-0.011820, 0.042940, 0.968881)
        ])
    ]

    /// Tritanomaly matrices for severity 0.0, 0.1, ..., 1.0.
    static let tritan: [simd_float3x3] = [
        // 0.0
        simd_float3x3(rows: [
            SIMD3<Float>(1.000000, 0.000000, 0.000000),
            SIMD3<Float>(0.000000, 1.000000, 0.000000),
            SIMD3<Float>(0.000000, 0.000000, 1.000000)
        ]),
        // 0.1
        simd_float3x3(rows: [
            SIMD3<Float>(0.926670, 0.092514, -0.019184),
            SIMD3<Float>(0.021191, 0.964503, 0.014306),
            SIMD3<Float>(0.008437, 0.054813, 0.936750)
        ]),
        // 0.2
        simd_float3x3(rows: [
            SIMD3<Float>(0.895720, 0.133330, -0.029050),
            SIMD3<Float>(0.029997, 0.945400, 0.024603),
            SIMD3<Float>(0.013027, 0.104707, 0.882266)
        ]),
        // 0.3
        simd_float3x3(rows: [
            SIMD3<Float>(0.905871, 0.127791, -0.033662),
            SIMD3<Float>(0.026856, 0.941251, 0.031893),
            SIMD3<Float>(0.013410, 0.148296, 0.838294)
        ]),
        // 0.4
        simd_float3x3(rows: [
            SIMD3<Float>(0.948035, 0.089490, -0.037526),
            SIMD3<Float>(0.014364, 0.946792, 0.038844),
            SIMD3<Float>(0.010853, 0.193991, 0.795156)
        ]),
        // 0.5
        simd_float3x3(rows: [
            SIMD3<Float>(1.017277, 0.027029, -0.044306),
            SIMD3<Float>(-0.006113, 0.958479, 0.047634),
            SIMD3<Float>(0.006379, 0.248708, 0.744913)
        ]),
        // 0.6
        simd_float3x3(rows: [
            SIMD3<Float>(1.104996, -0.046633, -0.058363),
            SIMD3<Float>(-0.032137, 0.971635, 0.060503),
            SIMD3<Float>(0.001336, 0.317922, 0.680742)
        ]),
        // 0.7
        simd_float3x3(rows: [
            SIMD3<Float>(1.193214, -0.109812, -0.083402),
            SIMD3<Float>(-0.058496, 0.979410, 0.079086),
            SIMD3<Float>(-0.002346, 0.403492, 0.598854)
        ]),
        // 0.8
        simd_float3x3(rows: [
            SIMD3<Float>(1.257728, -0.139648, -0.118081),
            SIMD3<Float>(-0.078003, 0.975409, 0.102594),
            SIMD3<Float>(-0.003316, 0.501214, 0.502102)
        ]),
        // 0.9
        simd_float3x3(rows: [
            SIMD3<Float>(1.278864, -0.125333, -0.153531),
            SIMD3<Float>(-0.084748, 0.957674, 0.127074),
            SIMD3<Float>(-0.000989, 0.601151, 0.399838)
        ]),
        // 1.0
        simd_float3x3(rows: [
            SIMD3<Float>(1.255528, -0.076749, -0.178779),
            SIMD3<Float>(-0.078411, 0.930809, 0.147602),
            SIMD3<Float>(0.004733, 0.691367, 0.303900)
        ])
    ]
}
