//
//  PDFExporter.swift
//  Inkpad
//

import UIKit
import PDFKit
import PencilKit

nonisolated enum PDFExporter {
    private static let inkScale: CGFloat = 3

    /// The imported PDF with each page's annotations flattened onto it.
    static func annotatedPDF(from pdfData: Data, pageDrawingData: [Int: Data]) -> Data? {
        guard let document = PDFDocument(data: pdfData), document.pageCount > 0 else { return nil }

        return UIGraphicsPDFRenderer(bounds: .zero).pdfData { context in
            for index in 0..<document.pageCount {
                guard let page = document.page(at: index) else { continue }
                let pageRect = CGRect(origin: .zero, size: Thumbnail.displayedSize(of: page))
                context.beginPage(withBounds: pageRect, pageInfo: [:])

                let cgContext = context.cgContext
                cgContext.saveGState()
                // PDF pages draw with a bottom-left origin.
                cgContext.translateBy(x: 0, y: pageRect.height)
                cgContext.scaleBy(x: 1, y: -1)
                page.draw(with: .cropBox, to: cgContext)
                cgContext.restoreGState()

                if let data = pageDrawingData[index], let drawing = try? PKDrawing(data: data) {
                    drawing.lightImage(from: pageRect, scale: inkScale).draw(in: pageRect)
                }
            }
        }
    }

    /// A drawing note as a single page sized to fit everything written on it.
    static func pdf(from drawing: PKDrawing) -> Data {
        let margin: CGFloat = 40
        let drawingBounds = drawing.bounds
        let contentSize = drawingBounds.isNull ? .zero : CGSize(width: drawingBounds.maxX, height: drawingBounds.maxY)
        let pageRect = CGRect(
            x: 0,
            y: 0,
            width: max(contentSize.width + margin, 612),
            height: max(contentSize.height + margin, 792)
        )

        return UIGraphicsPDFRenderer(bounds: pageRect).pdfData { context in
            context.beginPage()
            UIColor.white.setFill()
            context.fill(pageRect)
            drawing.lightImage(from: pageRect, scale: inkScale).draw(in: pageRect)
        }
    }
}
