//
//  Folder.swift
//  Inkpad
//

import Foundation
import SwiftData

@Model
final class Folder {
    var name: String
    var createdAt: Date
    @Relationship(deleteRule: .nullify, inverse: \Notebook.folder) var notebooks: [Notebook] = []

    init(name: String, createdAt: Date = .now) {
        self.name = name
        self.createdAt = createdAt
    }
}
