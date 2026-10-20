//
//  Note+PDF.swift
//  Inkpad
//

import Foundation

extension Note {
    var isPDF: Bool {
        pdfData != nil
    }

    /// Serialized PencilKit drawings for an imported PDF, keyed by page index.
    var pageDrawingData: [Int: Data] {
        get {
            guard let pageDrawingsData,
                  let pages = try? PropertyListDecoder().decode([Int: Data].self, from: pageDrawingsData) else {
                return [:]
            }
            return pages
        }
        set {
            pageDrawingsData = try? PropertyListEncoder().encode(newValue)
            updatedAt = .now
        }
    }
}
