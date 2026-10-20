//
//  Note+Drawing.swift
//  Inkpad
//

import Foundation
import PencilKit
import SwiftData

extension Note {
    var drawing: PKDrawing {
        get {
            guard let drawingData, let drawing = try? PKDrawing(data: drawingData) else {
                return PKDrawing()
            }
            return drawing
        }
        set {
            drawingData = newValue.dataRepresentation()
            updatedAt = .now
        }
    }

    func updateThumbnail() {
        // The editor can disappear because its note was just deleted.
        guard !isDeleted, modelContext != nil else { return }
        thumbnailData = Thumbnail.image(for: drawing).jpegData(compressionQuality: 0.8)
    }
}
