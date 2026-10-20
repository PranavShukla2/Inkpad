//
//  PDFImporter.swift
//  Inkpad
//

import Foundation
import PDFKit
import SwiftData

enum PDFImporter {
    enum ImportError: LocalizedError {
        case unreadable(String)

        var errorDescription: String? {
            switch self {
            case .unreadable(let name):
                "“\(name)” may be damaged or password-protected."
            }
        }
    }

    /// Creates a notebook whose pages show the PDF underneath the ink.
    static func makeNotebook(from url: URL, in context: ModelContext) throws -> Notebook {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        guard let document = PDFDocument(data: data),
              !document.isLocked,
              document.pageCount > 0,
              let provider = CGDataProvider(data: data as CFData),
              let pdf = CGPDFDocument(provider) else {
            throw ImportError.unreadable(url.lastPathComponent)
        }

        let notebook = Notebook(title: url.deletingPathExtension().lastPathComponent, cover: .slate, paperStyle: .blank)
        notebook.pdfData = data
        context.insert(notebook)

        for index in 0..<pdf.numberOfPages {
            guard let pdfPage = pdf.page(at: index + 1) else { continue }
            let page = notebook.insertPage(
                at: index,
                paperStyle: .blank,
                size: PageRenderer.displayedSize(of: pdfPage),
                pdfPageIndex: index
            )
            // The PDF's own text makes imported documents searchable.
            page.recognizedText = document.page(at: index)?.string ?? ""
        }
        notebook.updateCoverImage()
        return notebook
    }
}
