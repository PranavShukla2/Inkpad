//
//  PageRenderer.swift
//  Inkpad
//

import UIKit
import PencilKit

/// Everything needed to draw a page, as plain values that can cross threads.
nonisolated struct PageSpec: Sendable {
    var size: CGSize
    var paperStyle: PaperStyle
    var pdfPageIndex: Int?
    var drawingData: Data?

    var drawing: PKDrawing {
        drawingData.flatMap { try? PKDrawing(data: $0) } ?? PKDrawing()
    }
}

nonisolated enum PageRenderer {
    /// Draws the paper or PDF page into a top-left-origin context.
    static func drawBackground(of spec: PageSpec, paperColor: PaperColor, pdf: CGPDFDocument?, in context: CGContext) {
        if let pdfPageIndex = spec.pdfPageIndex, let page = pdf?.page(at: pdfPageIndex + 1) {
            drawPDFPage(page, size: spec.size, in: context)
        } else {
            PaperRenderer.draw(spec.paperStyle, color: paperColor, in: context, size: spec.size)
        }
    }

    static func drawPDFPage(_ page: CGPDFPage, size: CGSize, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        // PDF pages draw with a bottom-left origin.
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        context.concatenate(page.getDrawingTransform(.cropBox, rect: CGRect(origin: .zero, size: size), rotate: 0, preserveAspectRatio: true))
        context.drawPDFPage(page)
    }

    /// The size PDFKit shows a page at, accounting for rotation.
    static func displayedSize(of page: CGPDFPage) -> CGSize {
        let box = page.getBoxRect(.cropBox).size
        return page.rotationAngle % 180 == 0 ? box : CGSize(width: box.height, height: box.width)
    }

    static func image(of spec: PageSpec, paperColor: PaperColor, pdf: CGPDFDocument?, width: CGFloat) -> UIImage {
        let scale = width / spec.size.width
        let size = CGSize(width: width, height: spec.size.height * scale)
        let pageRect = CGRect(origin: .zero, size: spec.size)
        let ink = spec.drawing.image(
            from: pageRect,
            scale: scale * 2,
            style: paperColor.isDark ? .dark : .light
        )

        return UIGraphicsImageRenderer(size: size).image { context in
            context.cgContext.scaleBy(x: scale, y: scale)
            drawBackground(of: spec, paperColor: paperColor, pdf: pdf, in: context.cgContext)
            ink.draw(in: pageRect)
        }
    }
}
