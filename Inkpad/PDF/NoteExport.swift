//
//  NoteExport.swift
//  Inkpad
//

import CoreTransferable
import PencilKit
import UniformTypeIdentifiers

/// A note shared as a PDF. Holds plain data so rendering can happen off the main thread.
nonisolated struct NoteExport: Transferable {
    let title: String
    let drawingData: Data?
    let pdfData: Data?
    let pageDrawingsData: Data?

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { export in
            try export.renderPDF()
        }
        .suggestedFileName { $0.title }
    }

    private func renderPDF() throws -> Data {
        if let pdfData {
            guard let data = PDFExporter.annotatedPDF(from: pdfData, pageDrawingData: PageDrawings.decode(pageDrawingsData)) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return data
        }
        let drawing = drawingData.flatMap { try? PKDrawing(data: $0) } ?? PKDrawing()
        return PDFExporter.pdf(from: drawing)
    }
}
