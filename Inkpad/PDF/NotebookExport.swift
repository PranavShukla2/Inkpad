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
    /// Canvas boards export just the area with ink, not the whole huge board.
    var cropsToInk = false
}

extension Notebook {
    var snapshot: NotebookSnapshot {
        NotebookSnapshot(pages: sortedPages.map(\.spec), paperColor: paperColor, pdfData: pdfData, cropsToInk: isCanvas)
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

    /// The inked part of a board, with a margin, at least a page in size.
    private static func inkArea(of drawing: PKDrawing, textBoxes: [TextBox], on boardSize: CGSize) -> CGRect {
        let minimum = PageLayout.standardPageSize
        var area = textBoxes.reduce(drawing.bounds) { $0.union($1.frame) }
        if area.isNull || area.isEmpty {
            area = CGRect(x: boardSize.width / 2, y: boardSize.height / 2, width: 0, height: 0)
        }
        area = area.insetBy(dx: -48, dy: -48)
        area = area.insetBy(dx: min(0, (area.width - minimum.width) / 2), dy: min(0, (area.height - minimum.height) / 2))
        return area.intersection(CGRect(origin: .zero, size: boardSize))
    }

    static func render(_ snapshot: NotebookSnapshot) -> Data {
        let pdf = snapshot.pdfData
            .flatMap { CGDataProvider(data: $0 as CFData) }
            .flatMap { CGPDFDocument($0) }
        let inkStyle: UIUserInterfaceStyle = snapshot.paperColor.isDark ? .dark : .light

        return UIGraphicsPDFRenderer(bounds: .zero).pdfData { context in
            for spec in snapshot.pages {
                let drawing = spec.drawing
                let area = snapshot.cropsToInk ? inkArea(of: drawing, textBoxes: spec.textBoxes, on: spec.size) : CGRect(origin: .zero, size: spec.size)
                let pageRect = CGRect(origin: .zero, size: area.size)
                context.beginPage(withBounds: pageRect, pageInfo: [:])
                context.cgContext.saveGState()
                context.cgContext.clip(to: pageRect)
                context.cgContext.translateBy(x: -area.minX, y: -area.minY)
                PageRenderer.drawBackground(of: spec, paperColor: snapshot.paperColor, pdf: pdf, in: context.cgContext)
                context.cgContext.restoreGState()
                if !drawing.strokes.isEmpty {
                    drawing.image(from: area, scale: inkScale, style: inkStyle).draw(in: pageRect)
                }
                context.cgContext.saveGState()
                context.cgContext.translateBy(x: -area.minX, y: -area.minY)
                PageRenderer.drawTextBoxes(spec.textBoxes, onDarkPaper: snapshot.paperColor.isDark, in: context.cgContext)
                context.cgContext.restoreGState()
            }
        }
    }
}
