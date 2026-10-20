//
//  Notebook.swift
//  Inkpad
//

import Foundation
import SwiftData

@Model
final class Notebook {
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var coverRaw: String
    var paperStyleRaw: String
    var paperColorRaw: String
    var isFavorite: Bool = false
    var currentPageIndex: Int = 0
    /// The imported document for PDF notebooks; pages reference it by index.
    @Attribute(.externalStorage) var pdfData: Data?
    /// First-page preview shown instead of a fabric cover for PDF notebooks.
    @Attribute(.externalStorage) var coverImageData: Data?
    var folder: Folder?
    @Relationship(deleteRule: .cascade, inverse: \Page.notebook) var pages: [Page] = []
    @Relationship(deleteRule: .cascade, inverse: \Recording.notebook) var recordings: [Recording] = []

    static let defaultTitle = "Untitled Notebook"

    init(
        title: String = Notebook.defaultTitle,
        cover: CoverStyle = .ink,
        paperStyle: PaperStyle = .lined,
        paperColor: PaperColor = .white,
        createdAt: Date = .now
    ) {
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.coverRaw = cover.rawValue
        self.paperStyleRaw = paperStyle.rawValue
        self.paperColorRaw = paperColor.rawValue
    }

    var cover: CoverStyle {
        get { CoverStyle(rawValue: coverRaw) ?? .ink }
        set { coverRaw = newValue.rawValue }
    }

    /// The paper new pages get.
    var paperStyle: PaperStyle {
        get { PaperStyle(rawValue: paperStyleRaw) ?? .blank }
        set { paperStyleRaw = newValue.rawValue }
    }

    var paperColor: PaperColor {
        get { PaperColor(rawValue: paperColorRaw) ?? .white }
        set { paperColorRaw = newValue.rawValue }
    }

    var isPDF: Bool { pdfData != nil }

    var displayTitle: String {
        title.trimmingCharacters(in: .whitespaces).isEmpty ? Notebook.defaultTitle : title
    }

    var sortedPages: [Page] {
        pages.sorted { $0.index < $1.index }
    }
}
