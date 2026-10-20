//
//  Note+Thumbnail.swift
//  Inkpad
//

import UIKit
import PDFKit
import PencilKit
import SwiftData

extension Note {
    func updateThumbnail() {
        // The editor can disappear because its note was just deleted.
        guard !isDeleted, modelContext != nil else { return }
        let image: UIImage
        if let pdfData, let firstPage = PDFDocument(data: pdfData)?.page(at: 0) {
            let drawing = pageDrawingData[0].flatMap { try? PKDrawing(data: $0) } ?? PKDrawing()
            image = Thumbnail.image(for: firstPage, drawing: drawing)
        } else {
            image = Thumbnail.image(for: drawing)
        }
        thumbnailData = image.jpegData(compressionQuality: 0.8)
    }
}
