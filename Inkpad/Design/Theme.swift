//
//  Theme.swift
//  Inkpad
//
//  "Stamp & Paper": a warm paper desk, ink-black text and a vermilion stamp accent.
//

import SwiftUI
import UIKit

nonisolated extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    convenience init(light: UIColor, dark: UIColor) {
        self.init { $0.userInterfaceStyle == .dark ? dark : light }
    }
}

nonisolated enum Palette {
    static let desk = UIColor(light: UIColor(hex: 0xEFE9DF), dark: UIColor(hex: 0x17181C))
    static let deskRaised = UIColor(light: UIColor(hex: 0xF7F3EC), dark: UIColor(hex: 0x212227))
    static let ink = UIColor(light: UIColor(hex: 0x24221F), dark: UIColor(hex: 0xEFEBE4))
    static let inkSecondary = UIColor(light: UIColor(hex: 0x7A7268), dark: UIColor(hex: 0x9C978F))
    static let stamp = UIColor(light: UIColor(hex: 0xD2462A), dark: UIColor(hex: 0xEE6440))
    static let hairline = UIColor(light: UIColor(hex: 0xDCD3C4), dark: UIColor(hex: 0x34353B))
}

enum Theme {
    static let desk = Color(Palette.desk)
    static let deskRaised = Color(Palette.deskRaised)
    static let ink = Color(Palette.ink)
    static let inkSecondary = Color(Palette.inkSecondary)
    static let stamp = Color(Palette.stamp)
    static let hairline = Color(Palette.hairline)
}

extension Font {
    /// Serif display face (New York) used for titles.
    static func serif(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .serif, weight: weight)
    }
}
