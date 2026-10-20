//
//  PKDrawing+Image.swift
//  Inkpad
//

import UIKit
import PencilKit

nonisolated extension PKDrawing {
    /// Renders ink with fixed colours. Dark paper uses the dark style so black ink shows up light.
    func image(from rect: CGRect, scale: CGFloat, style: UIUserInterfaceStyle) -> UIImage {
        var image = UIImage()
        UITraitCollection(userInterfaceStyle: style).performAsCurrent {
            image = self.image(from: rect, scale: scale)
        }
        return image
    }

    /// Renders ink as it looks on white paper, even in Dark Mode.
    func lightImage(from rect: CGRect, scale: CGFloat) -> UIImage {
        image(from: rect, scale: scale, style: .light)
    }
}
