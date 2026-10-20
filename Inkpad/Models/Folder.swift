//
//  Folder.swift
//  Inkpad
//

import UIKit
import SwiftData

@Model
final class Folder {
    var name: String
    var createdAt: Date
    var colorHex: String?
    @Relationship(deleteRule: .nullify, inverse: \Notebook.folder) var notebooks: [Notebook] = []

    init(name: String, createdAt: Date = .now) {
        self.name = name
        self.createdAt = createdAt
    }

    /// Kraft-paper brown unless the user picks a colour.
    static let defaultColor = UIColor(hex: 0xC9A06A)

    var color: UIColor {
        colorHex.flatMap(UIColor.init(hexString:)) ?? Folder.defaultColor
    }
}
