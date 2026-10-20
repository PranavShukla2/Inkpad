//
//  Notebook+Cover.swift
//  Inkpad
//

import UIKit
import PencilKit

extension Notebook {
    /// PDF notebooks show their first page on the shelf instead of a fabric cover.
    func updateCoverImage() {
        guard let pdfData,
              let provider = CGDataProvider(data: pdfData as CFData),
              let pdf = CGPDFDocument(provider),
              let firstPage = sortedPages.first else {
            coverImageData = nil
            return
        }
        let image = PageRenderer.image(of: firstPage.spec, paperColor: paperColor, pdf: pdf, width: 360)
        coverImageData = image.jpegData(compressionQuality: 0.8)
    }
}

extension Notebook {
    static let canvasPreviewSize = CGSize(width: 640, height: 440)

    /// Canvases show a snapshot of what's drawn on them in the library.
    func updateCanvasPreview() {
        guard isCanvas, let page = sortedPages.first else { return }
        let spec = page.spec
        var content = spec.drawing.bounds
        content = spec.textBoxes.reduce(content) { $0.union($1.frame) }
        content = spec.items.reduce(content) { $0.union($1.frame) }
        guard !content.isNull, !content.isEmpty else {
            coverImageData = nil
            return
        }

        // Frame the content with some margin at the card's proportions.
        let size = Notebook.canvasPreviewSize
        var area = content.insetBy(dx: -60, dy: -60)
        let aspect = size.width / size.height
        if area.width / area.height > aspect {
            area = area.insetBy(dx: 0, dy: -(area.width / aspect - area.height) / 2)
        } else {
            area = area.insetBy(dx: -(area.height * aspect - area.width) / 2, dy: 0)
        }
        let scale = size.width / area.width
        let images = Dictionary(attachments.map { ($0.id, $0.data) }, uniquingKeysWith: { first, _ in first })
        let ink = spec.drawing.image(from: area, scale: scale * 2, style: paperColor.isDark ? .dark : .light)

        let image = UIGraphicsImageRenderer(size: size).image { context in
            let cgContext = context.cgContext
            cgContext.saveGState()
            cgContext.scaleBy(x: scale, y: scale)
            cgContext.translateBy(x: -area.minX, y: -area.minY)
            cgContext.clip(to: area)
            PageRenderer.drawBackground(of: spec, paperColor: paperColor, pdf: nil, in: cgContext)
            PageRenderer.drawItems(spec.items, images: images, in: cgContext)
            cgContext.restoreGState()
            ink.draw(in: CGRect(origin: .zero, size: size))
            cgContext.scaleBy(x: scale, y: scale)
            cgContext.translateBy(x: -area.minX, y: -area.minY)
            PageRenderer.drawTextBoxes(spec.textBoxes, onDarkPaper: paperColor.isDark, in: cgContext)
        }
        coverImageData = image.jpegData(compressionQuality: 0.8)
    }
}
