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
            PageDrawings.decode(pageDrawingsData)
        }
        set {
            pageDrawingsData = PageDrawings.encode(newValue)
            updatedAt = .now
        }
    }
}
