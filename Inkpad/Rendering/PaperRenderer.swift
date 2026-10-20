//
//  PaperRenderer.swift
//  Inkpad
//

import UIKit

/// Draws paper patterns as vectors, so they stay sharp at any zoom.
/// Safe to call from background threads (CATiledLayer, export, thumbnails).
nonisolated enum PaperRenderer {
    static func draw(_ style: PaperStyle, color: PaperColor, in context: CGContext, size: CGSize) {
        let page = CGRect(origin: .zero, size: size)
        let clip = context.boundingBoxOfClipPath.intersection(page)
        guard !clip.isNull, !clip.isEmpty else { return }

        context.saveGState()
        defer { context.restoreGState() }

        context.setFillColor(color.background.cgColor)
        context.fill(clip)
        context.setStrokeColor(color.rule.cgColor)
        context.setFillColor(color.rule.cgColor)
        context.setLineWidth(0.75)

        switch style {
        case .blank:
            break
        case .lined:
            drawRules(spacing: 26, from: 104, to: size.height - 48, width: size.width, clip: clip, in: context)
            drawMargin(x: 76, height: size.height, color: color, in: context)
        case .wideLined:
            drawRules(spacing: 34, from: 104, to: size.height - 48, width: size.width, clip: clip, in: context)
            drawMargin(x: 76, height: size.height, color: color, in: context)
        case .grid:
            drawGrid(spacing: 24, majorEvery: nil, size: size, clip: clip, in: context)
        case .smallGrid:
            drawGrid(spacing: 12, majorEvery: 5, size: size, clip: clip, in: context)
        case .dots:
            drawDots(spacing: 24, size: size, clip: clip, in: context)
        case .cornell:
            drawCornell(size: size, clip: clip, color: color, in: context)
        case .music:
            drawMusic(size: size, clip: clip, in: context)
        case .isometric:
            drawIsometric(spacing: 24, size: size, clip: clip, in: context)
        }
    }

    // MARK: - Patterns

    private static func drawRules(spacing: CGFloat, from top: CGFloat, to bottom: CGFloat, width: CGFloat, clip: CGRect, in context: CGContext) {
        let first = max(0, Int(((clip.minY - top) / spacing).rounded(.down)))
        var y = top + CGFloat(first) * spacing
        while y <= min(bottom, clip.maxY + 1) {
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: width, y: y))
            y += spacing
        }
        context.strokePath()
    }

    private static func drawMargin(x: CGFloat, height: CGFloat, color: PaperColor, in context: CGContext) {
        context.saveGState()
        context.setStrokeColor(color.margin.cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: x, y: 0))
        context.addLine(to: CGPoint(x: x, y: height))
        context.strokePath()
        context.restoreGState()
    }

    private static func drawGrid(spacing: CGFloat, majorEvery: Int?, size: CGSize, clip: CGRect, in context: CGContext) {
        let originX = size.width.truncatingRemainder(dividingBy: spacing) / 2
        let originY = size.height.truncatingRemainder(dividingBy: spacing) / 2
        let minor = CGMutablePath()
        let major = CGMutablePath()

        func add(_ index: Int, from start: CGPoint, to end: CGPoint) {
            if let majorEvery, index % majorEvery == 0 {
                major.move(to: start)
                major.addLine(to: end)
            } else {
                minor.move(to: start)
                minor.addLine(to: end)
            }
        }

        var column = Int(((clip.minX - originX) / spacing).rounded(.down))
        while originX + CGFloat(column) * spacing <= clip.maxX {
            let x = originX + CGFloat(column) * spacing
            add(column, from: CGPoint(x: x, y: clip.minY), to: CGPoint(x: x, y: clip.maxY))
            column += 1
        }
        var row = Int(((clip.minY - originY) / spacing).rounded(.down))
        while originY + CGFloat(row) * spacing <= clip.maxY {
            let y = originY + CGFloat(row) * spacing
            add(row, from: CGPoint(x: clip.minX, y: y), to: CGPoint(x: clip.maxX, y: y))
            row += 1
        }

        context.addPath(minor)
        context.setLineWidth(majorEvery == nil ? 0.75 : 0.5)
        context.strokePath()
        if !major.isEmpty {
            context.addPath(major)
            context.setLineWidth(1)
            context.strokePath()
        }
    }

    private static func drawDots(spacing: CGFloat, size: CGSize, clip: CGRect, in context: CGContext) {
        let radius: CGFloat = 1.3
        let originX = size.width.truncatingRemainder(dividingBy: spacing) / 2
        let originY = size.height.truncatingRemainder(dividingBy: spacing) / 2
        var row = Int(((clip.minY - originY - radius) / spacing).rounded(.down))
        while originY + CGFloat(row) * spacing <= clip.maxY + radius {
            let y = originY + CGFloat(row) * spacing
            var column = Int(((clip.minX - originX - radius) / spacing).rounded(.down))
            while originX + CGFloat(column) * spacing <= clip.maxX + radius {
                let x = originX + CGFloat(column) * spacing
                context.addEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                column += 1
            }
            row += 1
        }
        context.fillPath()
    }

    private static func drawCornell(size: CGSize, clip: CGRect, color: PaperColor, in context: CGContext) {
        let headerBottom: CGFloat = 112
        let summaryTop = size.height - 230
        let cueWidth: CGFloat = 210

        drawRules(spacing: 26, from: headerBottom + 26, to: summaryTop - 13, width: size.width, clip: clip, in: context)

        context.saveGState()
        context.setStrokeColor(color.margin.cgColor)
        context.setLineWidth(1.25)
        context.move(to: CGPoint(x: 0, y: headerBottom))
        context.addLine(to: CGPoint(x: size.width, y: headerBottom))
        context.move(to: CGPoint(x: cueWidth, y: headerBottom))
        context.addLine(to: CGPoint(x: cueWidth, y: summaryTop))
        context.move(to: CGPoint(x: 0, y: summaryTop))
        context.addLine(to: CGPoint(x: size.width, y: summaryTop))
        context.strokePath()
        context.restoreGState()
    }

    private static func drawMusic(size: CGSize, clip: CGRect, in context: CGContext) {
        let lineSpacing: CGFloat = 9
        let staffHeight = lineSpacing * 4
        let staffSpacing: CGFloat = 64
        let inset: CGFloat = 48
        var top: CGFloat = 96
        while top + staffHeight <= size.height - 48 {
            if top <= clip.maxY && top + staffHeight >= clip.minY {
                for line in 0..<5 {
                    let y = top + CGFloat(line) * lineSpacing
                    context.move(to: CGPoint(x: inset, y: y))
                    context.addLine(to: CGPoint(x: size.width - inset, y: y))
                }
                context.move(to: CGPoint(x: inset, y: top))
                context.addLine(to: CGPoint(x: inset, y: top + staffHeight))
                context.move(to: CGPoint(x: size.width - inset, y: top))
                context.addLine(to: CGPoint(x: size.width - inset, y: top + staffHeight))
            }
            top += staffHeight + staffSpacing
        }
        context.strokePath()
    }

    private static func drawIsometric(spacing: CGFloat, size: CGSize, clip: CGRect, in context: CGContext) {
        let radius: CGFloat = 1.2
        let rowHeight = spacing * sqrt(3) / 2
        var row = max(0, Int(((clip.minY - radius) / rowHeight).rounded(.down)))
        while CGFloat(row) * rowHeight <= clip.maxY + radius {
            let y = CGFloat(row) * rowHeight
            let offset = row.isMultiple(of: 2) ? 0 : spacing / 2
            var column = Int(((clip.minX - offset - radius) / spacing).rounded(.down))
            while offset + CGFloat(column) * spacing <= clip.maxX + radius {
                let x = offset + CGFloat(column) * spacing
                context.addEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                column += 1
            }
            row += 1
        }
        context.fillPath()
    }
}
