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

    var textBoxes: [TextBox] {
        get { TextBox.decode(textBoxesData) }
        set { textBoxesData = TextBox.encode(newValue) }
    }

    /// Everything typed on the page, for search.
    var typedText: String {
        textBoxes.map(\.text).joined(separator: "\n")
    }

    var paperStyle: PaperStyle {
        get { PaperStyle(rawValue: paperStyleRaw) ?? .blank }
        set { paperStyleRaw = newValue.rawValue }
    }
}
