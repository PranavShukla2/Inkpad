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
    var kindRaw: String = NotebookKind.notebook.rawValue
    var coverColorHex: String?
    var coverDesignRaw: String = CoverDesign.cloth.rawValue
    var coverLabelRaw: String = CoverLabelStyle.plate.rawValue
    var coverEmblem: String = ""
    var hasRibbon: Bool = true
    /// A photo the user chose for the cover.
    @Attribute(.externalStorage) var coverPhotoData: Data?
    /// Size for new pages; zero means the standard A4 size.
    var pageWidth: Double = 0
    var pageHeight: Double = 0
    /// The imported document for PDF notebooks; pages reference it by index.
    @Attribute(.externalStorage) var pdfData: Data?
    /// First-page preview shown instead of a fabric cover for PDF notebooks.
    @Attribute(.externalStorage) var coverImageData: Data?
    var folder: Folder?
    @Relationship(deleteRule: .cascade, inverse: \Page.notebook) var pages: [Page] = []
    @Relationship(deleteRule: .cascade, inverse: \Recording.notebook) var recordings: [Recording] = []
    @Relationship(deleteRule: .cascade, inverse: \Attachment.notebook) var attachments: [Attachment] = []

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

    var kind: NotebookKind {
        get { NotebookKind(rawValue: kindRaw) ?? .notebook }
        set { kindRaw = newValue.rawValue }
    }

    var isCanvas: Bool { kind == .canvas }

    /// Identifies the notebook when it's dragged onto a folder.
    var dragID: String {
        (try? JSONEncoder().encode(persistentModelID))?.base64EncodedString() ?? ""
    }

    var coverDraft: CoverDraft {
        get {
            CoverDraft(
                preset: cover,
                customColorHex: coverColorHex,
                design: CoverDesign(rawValue: coverDesignRaw) ?? .cloth,
                labelStyle: CoverLabelStyle(rawValue: coverLabelRaw) ?? .plate,
                emblem: coverEmblem,
                hasRibbon: hasRibbon,
                photoData: coverPhotoData
            )
        }
        set {
            cover = newValue.preset
            coverColorHex = newValue.customColorHex
            coverDesignRaw = newValue.design.rawValue
            coverLabelRaw = newValue.labelStyle.rawValue
            coverEmblem = newValue.emblem
            hasRibbon = newValue.hasRibbon
            coverPhotoData = newValue.photoData
        }
    }

    var displayTitle: String {
        title.trimmingCharacters(in: .whitespaces).isEmpty ? Notebook.defaultTitle : title
    }

    var sortedPages: [Page] {
        pages.sorted { $0.index < $1.index }
    }
}
