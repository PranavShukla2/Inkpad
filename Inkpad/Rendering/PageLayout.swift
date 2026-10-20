//
//  PageLayout.swift
//  Inkpad
//

import CoreGraphics
import PencilKit

/// Stacks a notebook's pages vertically on one canvas, and moves ink between
/// canvas coordinates and each page's own coordinates.
nonisolated struct PageLayout: Sendable {
    /// A4 proportions, sized so a page fills an iPad screen at about 100%.
    static let standardPageSize = CGSize(width: 768, height: 1086)
    static let gap: CGFloat = 24
    static let sideMargin: CGFloat = 10
    static let topMargin: CGFloat = 12
    static let bottomMargin: CGFloat = 40

    let frames: [CGRect]
    let contentSize: CGSize

    init(sizes: [CGSize]) {
        let width = (sizes.map(\.width).max() ?? PageLayout.standardPageSize.width) + PageLayout.sideMargin * 2
        var y = PageLayout.topMargin
        var frames: [CGRect] = []
        for size in sizes {
            frames.append(CGRect(x: (width - size.width) / 2, y: y, width: size.width, height: size.height))
            y += size.height + PageLayout.gap
        }
        self.frames = frames
        self.contentSize = CGSize(width: width, height: y - PageLayout.gap + PageLayout.bottomMargin)
    }

    /// The page that owns a point, splitting the gaps between pages down the middle.
    func pageIndex(at y: CGFloat) -> Int {
        var low = 0
        var high = frames.count - 1
        while low < high {
            let mid = (low + high) / 2
            if y < frames[mid].maxY + PageLayout.gap / 2 {
                high = mid
            } else {
                low = mid + 1
            }
        }
        return max(low, 0)
    }

    /// Pages that intersect a rect in canvas coordinates.
    func pageIndices(in rect: CGRect) -> Range<Int> {
        guard !frames.isEmpty else { return 0..<0 }
        let first = pageIndex(at: rect.minY)
        let last = pageIndex(at: rect.maxY)
        return first..<(last + 1)
    }

    /// Splits a whole-notebook drawing into one drawing per page, in page coordinates.
    func split(_ drawing: PKDrawing) -> [PKDrawing] {
        guard !frames.isEmpty else { return [] }
        var buckets = Array(repeating: [PKStroke](), count: frames.count)
        for stroke in drawing.strokes {
            let index = pageIndex(at: stroke.renderBounds.midY)
            let origin = frames[index].origin
            var stroke = stroke
            stroke.transform = stroke.transform.concatenating(CGAffineTransform(translationX: -origin.x, y: -origin.y))
            buckets[index].append(stroke)
        }
        return buckets.map { PKDrawing(strokes: $0) }
    }

    /// Joins per-page drawings into one drawing in canvas coordinates.
    func merge(_ drawings: [PKDrawing]) -> PKDrawing {
        var strokes: [PKStroke] = []
        for (index, drawing) in drawings.enumerated() where index < frames.count {
            let origin = frames[index].origin
            for var stroke in drawing.strokes {
                stroke.transform = stroke.transform.concatenating(CGAffineTransform(translationX: origin.x, y: origin.y))
                strokes.append(stroke)
            }
        }
        return PKDrawing(strokes: strokes)
    }
}
