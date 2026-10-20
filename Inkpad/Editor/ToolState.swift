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
    case laser
    case text
    case textPen
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
        case .laser: "Laser Pen"
        case .text: "Text"
        case .textPen: "Text Pen"
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
        case .laser: "laser.burst"
        case .text: "textformat"
        case .textPen: "pencil.and.scribble"
        case .eraser: "eraser"
        case .lasso: "lasso"
        }
    }

    /// Tools that add ink to the page.
    var isInking: Bool {
        switch self {
        case .eraser, .lasso, .laser, .text: false
        default: true
        }
    }

    var hasColors: Bool {
        isInking || self == .laser || self == .text
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
        case .textPen: [2, 3, 4.5]
        case .eraser: [8, 20, 40, 72]
        case .lasso, .laser: []
        // Font sizes for typed text.
        case .text: [16, 22, 32]
        }
    }

    var palette: [UIColor] {
        switch self {
        case .highlighter: InkPalette.highlighters
        case .laser: InkPalette.lasers
        default: InkPalette.inks
        }
    }
}

enum LaserMode: String, CaseIterable, Identifiable {
    /// Everything stays until you pause, then the whole sentence fades.
    case trail
    /// Each stroke fades on its own shortly after you lift the Pencil.
    case fade
    /// A glowing dot that follows the Pencil, for pointing at things.
    case dot

    var id: String { rawValue }

    var name: String {
        switch self {
        case .trail: "Trail"
        case .fade: "Fade"
        case .dot: "Dot"
        }
    }

    var symbol: String {
        switch self {
        case .trail: "scribble.variable"
        case .fade: "wand.and.rays"
        case .dot: "smallcircle.filled.circle"
        }
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
    static let lasers: [UIColor] = [
        UIColor(hex: 0xFF3B30),
        UIColor(hex: 0x0A84FF),
        UIColor(hex: 0x30D158),
        UIColor(hex: 0xFFD60A),
        UIColor(hex: 0xBF5AF2),
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
    var laserMode = LaserMode.trail { didSet { persist() } }
    var isRulerActive = false
    var allowsFingerDrawing = false { didSet { persist() } }
    /// Left-handed layout: the Ink Rail sits on the right.
    var railOnRight = false { didSet { persist() } }
    /// The rail folds down to a single button to free up the page.
    var isRailCollapsed = false { didSet { persist() } }
    /// Pages in a column, or side by side and swiped one at a time.
    var scrollAxis = ScrollAxis.vertical { didSet { persist() } }

    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private var isRestoring = false

    init() {
        restore()
    }

    var color: UIColor {
        colors[tool] ?? tool.palette[0]
    }

    /// The tool's name as shown to the user, including the eraser mode.
    var toolDisplayName: String {
        guard tool == .eraser else { return tool.name }
        return eraserIsPartial ? "Pixel Eraser" : "Object Eraser"
    }

    func symbol(for tool: InkTool) -> String {
        tool == .eraser && eraserIsPartial ? "eraser.line.dashed" : tool.symbol
    }

    /// How wide the eraser is, for erasing text boxes too.
    var eraserWidth: CGFloat {
        eraserIsPartial ? InkTool.eraser.widths[min(widthIndices[.eraser] ?? 1, InkTool.eraser.widths.count - 1)] : 12
    }

    /// Font size for the Text tool.
    var textSize: CGFloat {
        InkTool.text.widths[min(widthIndices[.text] ?? 1, 2)]
    }

    var widthIndex: Int {
        widthIndices[tool] ?? 1
    }

    /// Tapping the selected eraser switches between Object and Pixel, like Notes.
    func select(_ newTool: InkTool) {
        guard newTool != tool else {
            if tool == .eraser {
                eraserIsPartial.toggle()
            }
            return
        }
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
            guard eraserIsPartial else { return PKEraserTool(.vector) }
            let range = PKEraserTool.EraserType.bitmap.validWidthRange
            let clamped = range.upperBound > 0 ? min(max(width, range.lowerBound), range.upperBound) : width
            return PKEraserTool(.bitmap, width: clamped)
        case .lasso:
            return PKLassoTool()
        case .laser, .text:
            // Not used for drawing: these tools work on their own overlays.
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
        defaults.set(laserMode.rawValue, forKey: "laserMode")
        defaults.set(allowsFingerDrawing, forKey: "allowsFingerDrawing")
        defaults.set(railOnRight, forKey: "railOnRight")
        defaults.set(isRailCollapsed, forKey: "isRailCollapsed")
        defaults.set(scrollAxis.rawValue, forKey: "scrollAxis")
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
        laserMode = defaults.string(forKey: "laserMode").flatMap(LaserMode.init(rawValue:)) ?? .trail
        allowsFingerDrawing = defaults.bool(forKey: "allowsFingerDrawing")
        railOnRight = defaults.bool(forKey: "railOnRight")
        isRailCollapsed = defaults.bool(forKey: "isRailCollapsed")
        scrollAxis = defaults.string(forKey: "scrollAxis").flatMap(ScrollAxis.init(rawValue:)) ?? .vertical
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
