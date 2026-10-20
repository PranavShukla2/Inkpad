//
//  Note+Drawing.swift
//  Inkpad
//

import Foundation
import PencilKit

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
}
