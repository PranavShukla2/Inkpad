//
//  Page.swift
//  Inkpad
//

import Foundation
import SwiftData

@Model
final class Page {
    var index: Int
    var width: Double
    var height: Double
    var paperStyleRaw: String
    /// Set when the page shows a page of the notebook's PDF behind the ink.
    var pdfPageIndex: Int?
    @Attribute(.externalStorage) var drawingData: Data?
    /// Typed text boxes on the page, encoded as JSON.
    var textBoxesData: Data?
    /// Sticky notes, shapes, photos and graphs, encoded as JSON.
    var itemsData: Data?
    /// Handwriting found on the page, used by search.
    var recognizedText: String = ""
    /// Text from the imported PDF page, used by search.
    var documentText: String = ""
    var updatedAt: Date
    var notebook: Notebook?

    static let standardSize = PageLayout.standardPageSize

    init(index: Int, size: CGSize = Page.standardSize, paperStyle: PaperStyle, pdfPageIndex: Int? = nil) {
        self.index = index
        self.width = size.width
        self.height = size.height
        self.paperStyleRaw = paperStyle.rawValue
        self.pdfPageIndex = pdfPageIndex
        self.updatedAt = .now
    }

    var size: CGSize {
        CGSize(width: width, height: height)
    }

    var items: [BoardItem] {
        get { BoardItem.decode(itemsData) }
        set { itemsData = BoardItem.encode(newValue) }
    }

    var textBoxes: [TextBox] {
        get { TextBox.decode(textBoxesData) }
        set { textBoxesData = TextBox.encode(newValue) }
    }

    /// Everything typed on the page, for search.
    var typedText: String {
        (textBoxes.map(\.text) + items.filter { $0.kind == .sticky }.map(\.text)).joined(separator: "\n")
    }

    var paperStyle: PaperStyle {
        get { PaperStyle(rawValue: paperStyleRaw) ?? .blank }
        set { paperStyleRaw = newValue.rawValue }
    }
}
