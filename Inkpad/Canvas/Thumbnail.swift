//
//  Thumbnail.swift
//  Inkpad
//

import UIKit
import PencilKit

enum Thumbnail {
    static let size = CGSize(width: 160, height: 120)

    /// Renders the top of the page, so the preview matches the note's layout.
    static func image(for drawing: PKDrawing) -> UIImage {
        let drawingBounds = drawing.bounds
        let pageWidth = max(drawingBounds.isNull ? 0 : drawingBounds.maxX + 20, 600)
        let region = CGRect(x: 0, y: 0, width: pageWidth, height: pageWidth * size.height / size.width)
        let scale = size.width / pageWidth

        var ink = UIImage()
        // Always render ink as it looks on white paper, even in Dark Mode.
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            ink = drawing.image(from: region, scale: scale * 2)
        }

        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            ink.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
