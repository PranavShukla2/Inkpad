//
//  BoardItem.swift
//  Inkpad
//

import CoreGraphics
import Foundation
import SwiftData

/// An object placed on a page or canvas: a sticky note, shape, photo, graph,
/// LaTeX equation or table.
/// Stored with its page, in page coordinates.
nonisolated struct BoardItem: Codable, Identifiable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case sticky
        case shape
        case image
        case graph
        case equation
        case table
    }

    enum Shape: String, Codable, CaseIterable, Identifiable, Sendable {
        case rectangle
        case roundedRectangle
        case ellipse
        case triangle
        case diamond
        case star
        case arrow

        var id: String { rawValue }

        var name: String {
            switch self {
            case .rectangle: "Square"
            case .roundedRectangle: "Rounded"
            case .ellipse: "Circle"
            case .triangle: "Triangle"
            case .diamond: "Diamond"
            case .star: "Star"
            case .arrow: "Arrow"
            }
        }

        var symbol: String {
            switch self {
            case .rectangle: "square"
            case .roundedRectangle: "app"
            case .ellipse: "circle"
            case .triangle: "triangle"
            case .diamond: "diamond"
            case .star: "star"
            case .arrow: "arrow.right"
            }
        }
    }

    var id = UUID()
    var kind: Kind
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var colorHex: String
    /// Sticky note text, a graph's expressions (one per line), or an equation's LaTeX.
    var text = ""
    var shape: Shape?
    /// The photo's ``Attachment`` id.
    var imageID: UUID?
    /// The x range a graph plots.
    var domainMin = -10.0
    var domainMax = 10.0
    /// A table's cells, row by row; the first row is the header.
    var cells: [[String]]?

    var frame: CGRect {
        get { CGRect(x: x, y: y, width: width, height: height) }
        set {
            x = newValue.minX
            y = newValue.minY
            width = newValue.width
            height = newValue.height
        }
    }

    static func decode(_ data: Data?) -> [BoardItem] {
        guard let data, let items = try? JSONDecoder().decode([BoardItem].self, from: data) else { return [] }
        return items
    }

    static func encode(_ items: [BoardItem]) -> Data? {
        items.isEmpty ? nil : try? JSONEncoder().encode(items)
    }

    static let stickyColors = ["F9E27D", "F7B5C4", "B5E6C6", "AED8F2", "D5C4F2", "F9C38B"]
    static let shapeColors = ["D2462A", "2C55C9", "3F8A55", "C8902F", "7B4BB0", "1E1D1B"]
}

/// A photo placed on a page, stored once per notebook.
@Model
final class Attachment {
    @Attribute(.unique) var id: UUID
    @Attribute(.externalStorage) var data: Data
    var notebook: Notebook?

    init(id: UUID = UUID(), data: Data) {
        self.id = id
        self.data = data
    }
}
