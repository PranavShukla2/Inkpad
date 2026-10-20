//
//  NotebookExport.swift
//  Inkpad
//

import CoreTransferable
import PencilKit
import UIKit
import UniformTypeIdentifiers

/// A notebook's content as plain values, so a PDF can be rendered off the main thread.
nonisolated struct NotebookSnapshot: Sendable {
    let pages: [PageSpec]
    let paperColor: PaperColor
    let pdfData: Data?
}

extension Notebook {
    var snapshot: NotebookSnapshot {
        NotebookSnapshot(pages: sortedPages.map(\.spec), paperColor: paperColor, pdfData: pdfData)
    }
}

/// Shares a notebook as a PDF. The snapshot is taken only when the user shares,
/// so showing a share button costs nothing.
nonisolated struct NotebookExport: Transferable {
    let title: String
    let snapshot: @MainActor @Sendable () -> NotebookSnapshot

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { export in
            let snapshot = await export.snapshot()
            return NotebookPDFRenderer.render(snapshot)
        }
        .suggestedFileName { $0.title }
    }
}

nonisolated enum NotebookPDFRenderer {
    private static let inkScale: CGFloat = 3

    static func render(_ snapshot: NotebookSnapshot) -> Data {
        let pdf = snapshot.pdfData
            .flatMap { CGDataProvider(data: $0 as CFData) }
            .flatMap { CGPDFDocument($0) }
        let inkStyle: UIUserInterfaceStyle = snapshot.paperColor.isDark ? .dark : .light

        return UIGraphicsPDFRenderer(bounds: .zero).pdfData { context in
            for spec in snapshot.pages {
                let pageRect = CGRect(origin: .zero, size: spec.size)
                context.beginPage(withBounds: pageRect, pageInfo: [:])
                PageRenderer.drawBackground(of: spec, paperColor: snapshot.paperColor, pdf: pdf, in: context.cgContext)
                let drawing = spec.drawing
                if !drawing.strokes.isEmpty {
                    drawing.image(from: pageRect, scale: inkScale, style: inkStyle).draw(in: pageRect)
                }
            }
        }
    }
}
