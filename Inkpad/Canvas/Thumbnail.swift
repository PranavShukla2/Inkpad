//
//  Thumbnail.swift
//  Inkpad
//

import UIKit
import PDFKit
import PencilKit

enum Thumbnail {
    static let size = CGSize(width: 160, height: 120)

    /// Renders the top of the page, so the preview matches the note's layout.
    static func image(for drawing: PKDrawing) -> UIImage {
        let drawingBounds = drawing.bounds
        let pageWidth = max(drawingBounds.isNull ? 0 : drawingBounds.maxX + 20, 600)
        let region = CGRect(x: 0, y: 0, width: pageWidth, height: pageWidth * size.height / size.width)
        let ink = inkImage(of: drawing, in: region, scale: size.width / pageWidth * 2)

        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            ink.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Renders the top of a PDF page with its annotations on top.
    static func image(for page: PDFPage, drawing: PKDrawing) -> UIImage {
        let pageSize = displayedSize(of: page)
        let scaledHeight = size.width * pageSize.height / pageSize.width
        let pageRect = CGRect(x: 0, y: 0, width: size.width, height: scaledHeight)
        let pageImage = page.thumbnail(of: CGSize(width: size.width * 2, height: scaledHeight * 2), for: .cropBox)
        let ink = inkImage(of: drawing, in: CGRect(origin: .zero, size: pageSize), scale: size.width / pageSize.width * 2)

        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            pageImage.draw(in: pageRect)
            ink.draw(in: pageRect)
        }
    }

    /// The page size as PDFView shows it, which is the coordinate space of its overlay canvas.
    static func displayedSize(of page: PDFPage) -> CGSize {
        let size = page.bounds(for: .cropBox).size
        return page.rotation % 180 == 0 ? size : CGSize(width: size.height, height: size.width)
    }

    private static func inkImage(of drawing: PKDrawing, in region: CGRect, scale: CGFloat) -> UIImage {
        var ink = UIImage()
        // Always render ink as it looks on white paper, even in Dark Mode.
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            ink = drawing.image(from: region, scale: scale)
        }
        return ink
    }
}
