//
//  Note.swift
//  Inkpad
//

import Foundation
import SwiftData

@Model
final class Note {
    var title: String
    var createdAt: Date
    var updatedAt: Date
    @Attribute(.externalStorage) var drawingData: Data?
    @Attribute(.externalStorage) var thumbnailData: Data?
    @Attribute(.externalStorage) var pdfData: Data?
    @Attribute(.externalStorage) var pageDrawingsData: Data?

    static let defaultTitle = "Untitled"

    init(title: String = Note.defaultTitle, createdAt: Date = .now) {
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    var displayTitle: String {
        title.trimmingCharacters(in: .whitespaces).isEmpty ? Note.defaultTitle : title
    }
}
