//
//  NotebookStyle.swift
//  Inkpad
//

import UIKit

nonisolated enum NotebookKind: String, CaseIterable, Identifiable, Sendable {
    /// Pages you flip through.
    case notebook
    /// One endless board that grows as you draw.
    case canvas

    var id: String { rawValue }

    var name: String {
        switch self {
        case .notebook: "Notebook"
        case .canvas: "Canvas"
        }
    }
}

nonisolated enum PaperStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case blank
    case lined
    case wideLined
    case grid
    case smallGrid
    case dots
    case cornell
    case music
    case isometric

    var id: String { rawValue }

    var name: String {
        switch self {
        case .blank: "Blank"
        case .lined: "Lined"
        case .wideLined: "Wide Lined"
        case .grid: "Grid"
        case .smallGrid: "Small Grid"
        case .dots: "Dot Grid"
        case .cornell: "Cornell"
        case .music: "Music"
        case .isometric: "Isometric"
        }
    }
}

nonisolated enum PaperColor: String, CaseIterable, Identifiable, Codable, Sendable {
    case white
    case ivory
    case dusk

    var id: String { rawValue }

    var name: String {
        switch self {
        case .white: "White"
        case .ivory: "Ivory"
        case .dusk: "Dusk"
        }
    }

    /// Dark paper flips the canvas into dark mode so black ink shows up light.
    var isDark: Bool { self == .dusk }

    var background: UIColor {
        switch self {
        case .white: UIColor(hex: 0xFFFFFF)
        case .ivory: UIColor(hex: 0xFBF6EA)
        case .dusk: UIColor(hex: 0x26282E)
        }
    }

    var rule: UIColor {
        switch self {
        case .white: UIColor(hex: 0xC3CEDA)
        case .ivory: UIColor(hex: 0xD8CAB0)
        case .dusk: UIColor(white: 1, alpha: 0.14)
        }
    }

    var margin: UIColor {
        UIColor(hex: 0xD2462A, alpha: isDark ? 0.55 : 0.45)
    }
}

nonisolated enum CoverStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case ink
    case stamp
    case moss
    case ochre
    case plum
    case slate
    case sand
    case charcoal

    var id: String { rawValue }

    var name: String {
        switch self {
        case .ink: "Ink"
        case .stamp: "Stamp"
        case .moss: "Moss"
        case .ochre: "Ochre"
        case .plum: "Plum"
        case .slate: "Slate"
        case .sand: "Sand"
        case .charcoal: "Charcoal"
        }
    }

    var color: UIColor {
        switch self {
        case .ink: UIColor(hex: 0x23365F)
        case .stamp: UIColor(hex: 0xC2412A)
        case .moss: UIColor(hex: 0x4E6B4A)
        case .ochre: UIColor(hex: 0xC8902F)
        case .plum: UIColor(hex: 0x6A3F5E)
        case .slate: UIColor(hex: 0x5B6B78)
        case .sand: UIColor(hex: 0xCDBB9C)
        case .charcoal: UIColor(hex: 0x2E2D2B)
        }
    }

    /// Light covers need dark text on the label.
    var isLight: Bool { self == .sand }
}

nonisolated enum PageSizeOption: String, CaseIterable, Identifiable, Sendable {
    case fitScreen
    case a4
    case letter
    case square

    var id: String { rawValue }

    var name: String {
        switch self {
        case .fitScreen: "Fit Screen"
        case .a4: "A4"
        case .letter: "US Letter"
        case .square: "Square"
        }
    }

    /// Page size in points. "Fit Screen" matches the device's portrait shape,
    /// so one page fills the display.
    func size(forScreen screen: CGSize) -> CGSize {
        let width = PageLayout.standardPageSize.width
        switch self {
        case .fitScreen:
            let short = min(screen.width, screen.height)
            let long = max(screen.width, screen.height)
            guard short > 0 else { return PageLayout.standardPageSize }
            return CGSize(width: width, height: (width * long / short).rounded())
        case .a4:
            return PageLayout.standardPageSize
        case .letter:
            return CGSize(width: width, height: (width * 11 / 8.5).rounded())
        case .square:
            return CGSize(width: width, height: width)
        }
    }
}

nonisolated enum CoverDesign: String, CaseIterable, Identifiable, Sendable {
    case cloth
    case leather
    case linen
    case stripes
    case grid
    case dots
    case waves
    case terrazzo

    var id: String { rawValue }

    var name: String {
        switch self {
        case .cloth: "Cloth"
        case .leather: "Leather"
        case .linen: "Linen"
        case .stripes: "Stripes"
        case .grid: "Grid"
        case .dots: "Dots"
        case .waves: "Waves"
        case .terrazzo: "Terrazzo"
        }
    }
}

nonisolated enum CoverLabelStyle: String, CaseIterable, Identifiable, Sendable {
    case plate
    case band
    case corner
    case none

    var id: String { rawValue }

    var name: String {
        switch self {
        case .plate: "Plate"
        case .band: "Band"
        case .corner: "Corner"
        case .none: "None"
        }
    }
}

/// Everything about how a notebook's cover looks, editable as one value.
nonisolated struct CoverDraft: Equatable, Sendable {
    var preset: CoverStyle = .ink
    /// A custom colour that overrides the preset.
    var customColorHex: String?
    var design: CoverDesign = .cloth
    var labelStyle: CoverLabelStyle = .plate
    var emblem = ""
    var hasRibbon = true
    var photoData: Data?

    var color: UIColor {
        customColorHex.flatMap(UIColor.init(hexString:)) ?? preset.color
    }
}
