//
//  ToolState.swift
//  Inkpad
//

import SwiftUI
import PencilKit

enum InkTool: String, CaseIterable, Identifiable {
    case pen
    case fountain
    case pencil
    case highlighter
    case shape
    case eraser
    case lasso

    var id: String { rawValue }

    var name: String {
        switch self {
        case .pen: "Pen"
        case .fountain: "Fountain Pen"
        case .pencil: "Pencil"
        case .highlighter: "Highlighter"
        case .shape: "Shapes"
        case .eraser: "Eraser"
        case .lasso: "Lasso"
        }
    }

    var symbol: String {
        switch self {
        case .pen: "pencil.tip"
        case .fountain: "signature"
        case .pencil: "pencil"
        case .highlighter: "highlighter"
        case .shape: "square.on.circle"
        case .eraser: "eraser"
        case .lasso: "lasso"
        }
    }

    var isInking: Bool {
        switch self {
        case .eraser, .lasso: false
        default: true
        }
    }

    var inkType: PKInkingTool.InkType {
        switch self {
        case .fountain: .fountainPen
        case .pencil: .pencil
        case .highlighter: .marker
        case .shape: .monoline
        default: .pen
        }
    }

    var widths: [CGFloat] {
        switch self {
        case .pen: [1.5, 3, 5.5]
        case .fountain: [2, 4, 7]
        case .pencil: [2, 4, 8]
        case .highlighter: [12, 20, 30]
        case .shape: [1.5, 3, 5.5]
        case .eraser: [8, 20, 40]
        case .lasso: []
        }
    }

    var palette: [UIColor] {
        self == .highlighter ? InkPalette.highlighters : InkPalette.inks
    }
}

nonisolated enum InkPalette {
    static let inks: [UIColor] = [
        UIColor(hex: 0x1E1D1B),
        UIColor(hex: 0xD2462A),
        UIColor(hex: 0x2C55C9),
        UIColor(hex: 0x3F8A55),
        UIColor(hex: 0x7B4BB0),
    ]
    static let highlighters: [UIColor] = [
        UIColor(hex: 0xF7D046),
        UIColor(hex: 0xF7A072),
        UIColor(hex: 0x8EDBA8),
        UIColor(hex: 0x8CC8F2),
        UIColor(hex: 0xC9A4F0),
    ]
}

/// The selected tool and each tool's colour and width. Shared by every notebook
/// and remembered between launches.
@Observable
final class ToolState {
    private(set) var tool: InkTool = .pen
    private(set) var previousTool: InkTool = .pen
    private var colors: [InkTool: UIColor] = [:]
    private var widthIndices: [InkTool: Int] = [:]
    var eraserIsPartial = false { didSet { persist() } }
    var isRulerActive = false
    var allowsFingerDrawing = false { didSet { persist() } }
    /// Left-handed layout: the Ink Rail sits on the right.
    var railOnRight = false { didSet { persist() } }
    /// The rail folds down to a single button to free up the page.
    var isRailCollapsed = false { didSet { persist() } }

    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private var isRestoring = false

    init() {
        restore()
    }

    var color: UIColor {
        colors[tool] ?? tool.palette[0]
    }

    var widthIndex: Int {
        widthIndices[tool] ?? 1
    }

    func select(_ newTool: InkTool) {
        guard newTool != tool else { return }
        previousTool = tool
        tool = newTool
        persist()
    }

    func setColor(_ color: UIColor) {
        colors[tool] = color
        persist()
    }

    func setWidthIndex(_ index: Int) {
        widthIndices[tool] = index
        persist()
    }

    /// Apple Pencil double-tap, following the user's system preference.
    func handlePencilTap(_ action: UIPencilPreferredAction) {
        switch action {
        case .switchEraser:
            select(tool == .eraser ? previousTool : .eraser)
        case .switchPrevious:
            select(previousTool)
        default:
            break
        }
    }

    /// Identifies the current tool configuration, so the canvas only swaps tools when it changes.
    var toolKey: String {
        "\(tool.rawValue)|\(color.hexString)|\(widthIndex)|\(eraserIsPartial)"
    }

    var pkTool: PKTool {
        let widths = tool.widths
        let width = widths.isEmpty ? 0 : widths[min(widthIndex, widths.count - 1)]
        switch tool {
        case .eraser:
            return eraserIsPartial ? PKEraserTool(.bitmap, width: width) : PKEraserTool(.vector)
        case .lasso:
            return PKLassoTool()
        default:
            return PKInkingTool(tool.inkType, color: color, width: width)
        }
    }

    // MARK: - Persistence

    private func persist() {
        guard !isRestoring else { return }
        defaults.set(tool.rawValue, forKey: "tool")
        defaults.set(Dictionary(uniqueKeysWithValues: colors.map { ($0.key.rawValue, $0.value.hexString) }), forKey: "toolColors")
        defaults.set(Dictionary(uniqueKeysWithValues: widthIndices.map { ($0.key.rawValue, $0.value) }), forKey: "toolWidths")
        defaults.set(eraserIsPartial, forKey: "eraserIsPartial")
        defaults.set(allowsFingerDrawing, forKey: "allowsFingerDrawing")
        defaults.set(railOnRight, forKey: "railOnRight")
        defaults.set(isRailCollapsed, forKey: "isRailCollapsed")
    }

    private func restore() {
        isRestoring = true
        defer { isRestoring = false }
        tool = defaults.string(forKey: "tool").flatMap(InkTool.init(rawValue:)) ?? .pen
        previousTool = tool
        for (key, hex) in defaults.dictionary(forKey: "toolColors") as? [String: String] ?? [:] {
            if let tool = InkTool(rawValue: key), let color = UIColor(hexString: hex) {
                colors[tool] = color
            }
        }
        for (key, index) in defaults.dictionary(forKey: "toolWidths") as? [String: Int] ?? [:] {
            if let tool = InkTool(rawValue: key) {
                widthIndices[tool] = index
            }
        }
        eraserIsPartial = defaults.bool(forKey: "eraserIsPartial")
        allowsFingerDrawing = defaults.bool(forKey: "allowsFingerDrawing")
        railOnRight = defaults.bool(forKey: "railOnRight")
        isRailCollapsed = defaults.bool(forKey: "isRailCollapsed")
    }
}

nonisolated extension UIColor {
    var hexString: String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }

    convenience init?(hexString: String) {
        guard let value = UInt32(hexString, radix: 16) else { return nil }
        self.init(hex: value)
    }
}
