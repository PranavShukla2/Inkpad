//
//  PKDrawing+Image.swift
//  Inkpad
//

import UIKit
import PencilKit

nonisolated extension PKDrawing {
    /// Renders ink as it looks on white paper, even in Dark Mode.
    func lightImage(from rect: CGRect, scale: CGFloat) -> UIImage {
        var image = UIImage()
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            image = self.image(from: rect, scale: scale)
        }
        return image
    }
}
