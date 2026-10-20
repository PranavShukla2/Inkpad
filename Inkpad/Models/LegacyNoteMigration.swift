//
//  LegacyNoteMigration.swift
//  Inkpad
//

import Foundation
import PencilKit
import SwiftData

/// Converts single-page notes from the first version of Inkpad into notebooks.
enum LegacyNoteMigration {
    static func run(in context: ModelContext) {
        guard let notes = try? context.fetch(FetchDescriptor<Note>()), !notes.isEmpty else { return }

        for note in notes {
            let notebook = Notebook(title: note.displayTitle, cover: .ink, paperStyle: .blank, createdAt: note.createdAt)
            context.insert(notebook)

            if let pdfData = note.pdfData,
               let provider = CGDataProvider(data: pdfData as CFData),
               let pdf = CGPDFDocument(provider) {
                notebook.pdfData = pdfData
                let drawings = note.pageDrawingData
                for index in 0..<pdf.numberOfPages {
                    guard let pdfPage = pdf.page(at: index + 1) else { continue }
                    let page = notebook.insertPage(
                        at: index,
                        paperStyle: .blank,
                        size: PageRenderer.displayedSize(of: pdfPage),
                        pdfPageIndex: index
                    )
                    page.drawingData = drawings[index]
                }
                notebook.updateCoverImage()
            } else {
                for (index, drawing) in pages(from: note.drawing).enumerated() {
                    let page = notebook.insertPage(at: index, paperStyle: .blank)
                    page.drawingData = drawing.dataRepresentation()
                }
            }

            notebook.updatedAt = note.updatedAt
            context.delete(note)
        }

        do {
            try context.save()
        } catch {
            print("Failed to migrate notes: \(error)")
        }
    }

    /// Old notes were one long canvas as wide as the screen. Fit it to the page
    /// width, then cut it into page-height pieces.
    private static func pages(from drawing: PKDrawing) -> [PKDrawing] {
        let pageSize = Page.standardSize
        let bounds = drawing.bounds
        guard !bounds.isNull, !bounds.isEmpty else { return [PKDrawing()] }

        var drawing = drawing
        let contentWidth = bounds.maxX + 24
        if contentWidth > pageSize.width {
            let scale = pageSize.width / contentWidth
            drawing = drawing.transformed(using: CGAffineTransform(scaleX: scale, y: scale))
        }

        let pageCount = max(1, Int((drawing.bounds.maxY / pageSize.height).rounded(.up)))
        var buckets = Array(repeating: [PKStroke](), count: pageCount)
        for var stroke in drawing.strokes {
            let index = min(pageCount - 1, max(0, Int(stroke.renderBounds.midY / pageSize.height)))
            stroke.transform = stroke.transform.concatenating(
                CGAffineTransform(translationX: 0, y: -CGFloat(index) * pageSize.height)
            )
            buckets[index].append(stroke)
        }
        return buckets.map { PKDrawing(strokes: $0) }
    }
}
