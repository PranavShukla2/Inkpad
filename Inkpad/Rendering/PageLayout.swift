//
//  PageLayout.swift
//  Inkpad
//

import CoreGraphics
import PencilKit

nonisolated enum ScrollAxis: String, CaseIterable, Identifiable, Sendable {
    case vertical
    case horizontal

    var id: String { rawValue }

    var name: String {
        switch self {
        case .vertical: "Vertical"
        case .horizontal: "Horizontal"
        }
    }
}

/// Places a notebook's pages on one canvas, in a column or a row, and moves ink
/// between canvas coordinates and each page's own coordinates.
nonisolated struct PageLayout: Sendable {
    /// A4 proportions, sized so a page fills an iPad screen at about 100%.
    static let standardPageSize = CGSize(width: 768, height: 1086)
    static let gap: CGFloat = 24
    static let sideMargin: CGFloat = 10
    static let topMargin: CGFloat = 12
    static let bottomMargin: CGFloat = 40

    let axis: ScrollAxis
    let frames: [CGRect]
    let contentSize: CGSize

    init(sizes: [CGSize], axis: ScrollAxis = .vertical) {
        self.axis = axis
        let maxWidth = sizes.map(\.width).max() ?? PageLayout.standardPageSize.width
        let maxHeight = sizes.map(\.height).max() ?? PageLayout.standardPageSize.height
        var frames: [CGRect] = []

        switch axis {
        case .vertical:
            let width = maxWidth + PageLayout.sideMargin * 2
            var y = PageLayout.topMargin
            for size in sizes {
                frames.append(CGRect(x: (width - size.width) / 2, y: y, width: size.width, height: size.height))
                y += size.height + PageLayout.gap
            }
            contentSize = CGSize(width: width, height: y - PageLayout.gap + PageLayout.bottomMargin)
        case .horizontal:
            let height = maxHeight + PageLayout.topMargin * 2
            var x = PageLayout.sideMargin
            for size in sizes {
                frames.append(CGRect(x: x, y: (height - size.height) / 2, width: size.width, height: size.height))
                x += size.width + PageLayout.gap
            }
            contentSize = CGSize(width: x - PageLayout.gap + PageLayout.sideMargin, height: height)
        }
        self.frames = frames
    }

    /// The largest page, which sets how far the canvas zooms out.
    var maxPageSize: CGSize {
        CGSize(width: frames.map(\.width).max() ?? 0, height: frames.map(\.height).max() ?? 0)
    }

    /// The page that owns a point, splitting the gaps between pages down the middle.
    func pageIndex(at point: CGPoint) -> Int {
        let value = axis == .vertical ? point.y : point.x
        var low = 0
        var high = frames.count - 1
        while low < high {
            let mid = (low + high) / 2
            let end = axis == .vertical ? frames[mid].maxY : frames[mid].maxX
            if value < end + PageLayout.gap / 2 {
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
        let first = pageIndex(at: CGPoint(x: rect.minX, y: rect.minY))
        let last = pageIndex(at: CGPoint(x: rect.maxX, y: rect.maxY))
        return first..<(last + 1)
    }

    /// Splits a whole-notebook drawing into one drawing per page, in page coordinates.
    func split(_ drawing: PKDrawing) -> [PKDrawing] {
        guard !frames.isEmpty else { return [] }
        var buckets = Array(repeating: [PKStroke](), count: frames.count)
        for stroke in drawing.strokes {
            let bounds = stroke.renderBounds
            let index = pageIndex(at: CGPoint(x: bounds.midX, y: bounds.midY))
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
