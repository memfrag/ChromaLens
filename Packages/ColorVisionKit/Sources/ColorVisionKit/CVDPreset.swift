//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

// MARK: - CVDFamily

/// Groups presets that share a simulation model.
public enum CVDFamily: String, CaseIterable, Codable, Sendable {
    case none
    case protan
    case deutan
    case tritan
    case achromatic
}

// MARK: - CVDSlider

/// The kind of adjustment a preset exposes.
///
/// Physiological severity (Machado model) and desaturation amount (achromatic
/// approximation) are deliberately different controls with different names.
///
public enum CVDSlider: Equatable, Sendable {
    case none
    case simulationSeverity
    case desaturationAmount

    /// The permitted slider range for adjustable presets.
    public static let range: ClosedRange<Double> = 0.1...0.9

    /// The default slider value for adjustable presets.
    public static let defaultValue: Double = 0.6

    /// User-facing slider label.
    public var label: String {
        switch self {
        case .none: ""
        case .simulationSeverity: "Simulation Severity"
        case .desaturationAmount: "Desaturation Amount"
        }
    }

    /// Clamps a value into ``range``.
    public static func clamp(_ value: Double) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

// MARK: - CVDPreset

/// A color vision simulation preset. Cases are declared in cycling order.
public enum CVDPreset: String, CaseIterable, Sendable, Identifiable {
    case normal
    case deuteranomaly
    case deuteranopia
    case protanomaly
    case protanopia
    case tritanomaly
    case tritanopia
    case achromatomaly
    case achromatopsia

    public var id: Self { self }

    /// The preset shown on first launch.
    public static let initial: CVDPreset = .deuteranopia

    /// User-facing name.
    public var displayName: String {
        switch self {
        case .normal: "Original Colors"
        case .deuteranomaly: "Deuteranomaly"
        case .deuteranopia: "Deuteranopia"
        case .protanomaly: "Protanomaly"
        case .protanopia: "Protanopia"
        case .tritanomaly: "Tritanomaly"
        case .tritanopia: "Tritanopia"
        case .achromatomaly: "Achromatomaly"
        case .achromatopsia: "Achromatopsia"
        }
    }

    /// Short explanation of what is simulated.
    public var summary: String {
        switch self {
        case .normal: "No transform"
        case .deuteranomaly: "Reduced green-cone discrimination"
        case .deuteranopia: "Green-cone dichromacy"
        case .protanomaly: "Reduced red-cone discrimination"
        case .protanopia: "Red-cone dichromacy"
        case .tritanomaly: "Reduced blue-cone discrimination"
        case .tritanopia: "Blue-cone dichromacy"
        case .achromatomaly: "Reduced overall color discrimination (approximation)"
        case .achromatopsia: "No perceived hue (approximation)"
        }
    }

    /// The model family the preset belongs to.
    public var family: CVDFamily {
        switch self {
        case .normal: .none
        case .deuteranomaly, .deuteranopia: .deutan
        case .protanomaly, .protanopia: .protan
        case .tritanomaly, .tritanopia: .tritan
        case .achromatomaly, .achromatopsia: .achromatic
        }
    }

    /// The Machado deficiency for cone-related presets.
    public var machadoDeficiency: MachadoModel.Deficiency? {
        switch family {
        case .protan: .protan
        case .deutan: .deutan
        case .tritan: .tritan
        case .none, .achromatic: nil
        }
    }

    /// The adjustment this preset exposes.
    public var slider: CVDSlider {
        switch self {
        case .deuteranomaly, .protanomaly, .tritanomaly: .simulationSeverity
        case .achromatomaly: .desaturationAmount
        case .normal, .deuteranopia, .protanopia, .tritanopia, .achromatopsia: .none
        }
    }

    /// The fixed model severity for dichromacy presets, if any.
    public var fixedSeverity: Double? {
        switch self {
        case .deuteranopia, .protanopia, .tritanopia: 1.0
        default: nil
        }
    }

    /// Whether the preset is a labeled visual approximation rather than a
    /// physiological model.
    public var isApproximation: Bool {
        family == .achromatic
    }

    /// The next preset in cycling order, wrapping around.
    public var next: CVDPreset {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self) else {
            return self
        }
        return all[(index + 1) % all.count]
    }

    /// The previous preset in cycling order, wrapping around.
    public var previous: CVDPreset {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self) else {
            return self
        }
        return all[(index + all.count - 1) % all.count]
    }
}
