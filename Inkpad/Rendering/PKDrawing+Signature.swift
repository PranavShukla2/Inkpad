//
//  PKDrawing+Signature.swift
//  Inkpad
//

import PencilKit

nonisolated extension PKDrawing {
    /// A cheap fingerprint of the strokes, used to tell which pages changed.
    /// PencilKit's data encoding differs between saves of identical ink, so
    /// comparing bytes can't be used. Values are rounded to absorb float noise
    /// from moving strokes between canvas and page coordinates.
    var contentSignature: Int {
        var hasher = Hasher()
        hasher.combine(strokes.count)
        for stroke in strokes {
            let bounds = stroke.renderBounds
            let transform = stroke.transform
            for value in [bounds.minX, bounds.minY, bounds.width, bounds.height,
                          transform.a, transform.b, transform.c, transform.d, transform.tx, transform.ty] {
                hasher.combine((value * 100).rounded())
            }
            hasher.combine(stroke.path.count)
            hasher.combine(stroke.ink.inkType.rawValue)
            hasher.combine(stroke.ink.color.hexString)
            if let mask = stroke.mask {
                let maskBounds = mask.bounds
                for value in [maskBounds.minX, maskBounds.minY, maskBounds.width, maskBounds.height] {
                    hasher.combine((value * 100).rounded())
                }
            }
        }
        return hasher.finalize()
    }
}
