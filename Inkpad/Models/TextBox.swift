//
//  TextBox.swift
//  Inkpad
//

import UIKit

/// Typed text placed on a page, in page coordinates.
nonisolated struct TextBox: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var x: Double
    var y: Double
    var width: Double
    var text: String
    var fontSize: Double = 22
    var colorHex = "1E1D1B"

    var origin: CGPoint {
        get { CGPoint(x: x, y: y) }
        set {
            x = newValue.x
            y = newValue.y
        }
    }

    var font: UIFont {
        .systemFont(ofSize: fontSize)
    }

    var color: UIColor {
        UIColor(hexString: colorHex) ?? .black
    }

    /// Dark text would vanish on dark paper, so it shows light there, like ink does.
    func displayColor(onDarkPaper: Bool) -> UIColor {
        guard onDarkPaper else { return color }
        var white: CGFloat = 0
        color.getWhite(&white, alpha: nil)
        return white < 0.3 ? UIColor(white: 0.95, alpha: 1) : color
    }

    func attributedText(onDarkPaper: Bool) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: displayColor(onDarkPaper: onDarkPaper)])
    }

    /// Height of the wrapped text at this box's width.
    var height: CGFloat {
        let measured = NSAttributedString(string: text.isEmpty ? " " : text, attributes: [.font: font])
            .boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        return ceil(measured.height)
    }

    var frame: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    static func decode(_ data: Data?) -> [TextBox] {
        guard let data, let boxes = try? JSONDecoder().decode([TextBox].self, from: data) else { return [] }
        return boxes
    }

    static func encode(_ boxes: [TextBox]) -> Data? {
        boxes.isEmpty ? nil : try? JSONEncoder().encode(boxes)
    }
}
