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

    init(title: String = "Untitled", createdAt: Date = .now) {
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}
