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
    /// Handwriting (or PDF text) found on the page, used by search.
    var recognizedText: String = ""
    var updatedAt: Date
    var notebook: Notebook?

    /// A4 proportions, sized so a page fills an iPad screen at about 100%.
    static let standardSize = CGSize(width: 768, height: 1086)

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

    var paperStyle: PaperStyle {
        get { PaperStyle(rawValue: paperStyleRaw) ?? .blank }
        set { paperStyleRaw = newValue.rawValue }
    }
}
