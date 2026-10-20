//
//  BoardItemRenderer.swift
//  Inkpad
//

import UIKit

/// Draws sticky notes, shapes, photos and graphs. Used on screen, in
/// previews and in exported PDFs, so they look the same everywhere.
nonisolated enum BoardItemRenderer {
    /// Draws an item into `rect` of a top-left-origin context.
    static func draw(_ item: BoardItem, image: UIImage?, in rect: CGRect, context: CGContext, drawsShadow: Bool) {
        UIGraphicsPushContext(context)
        defer { UIGraphicsPopContext() }
        context.saveGState()
        defer { context.restoreGState() }

        switch item.kind {
        case .sticky:
            drawSticky(item, in: rect, context: context, drawsShadow: drawsShadow)
        case .shape:
            drawShape(item, in: rect, context: context)
        case .image:
            drawImage(image, in: rect, context: context, drawsShadow: drawsShadow)
        case .graph:
            drawGraph(item, in: rect, context: context, drawsShadow: drawsShadow)
        }
    }

    static func color(_ item: BoardItem) -> UIColor {
        UIColor(hexString: item.colorHex) ?? .systemYellow
    }

    // MARK: - Sticky notes

    private static func drawSticky(_ item: BoardItem, in rect: CGRect, context: CGContext, drawsShadow: Bool) {
        let fold = min(rect.width, rect.height) * 0.12
        let body = UIBezierPath()
        body.move(to: CGPoint(x: rect.minX, y: rect.minY))
        body.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        body.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - fold))
        body.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.maxY))
        body.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        body.close()

        if drawsShadow {
            context.setShadow(offset: CGSize(width: 0, height: 3), blur: 8, color: UIColor.black.withAlphaComponent(0.18).cgColor)
        }
        color(item).setFill()
        body.fill()
        context.setShadow(offset: .zero, blur: 0, color: nil)

        // Folded corner
        let corner = UIBezierPath()
        corner.move(to: CGPoint(x: rect.maxX, y: rect.maxY - fold))
        corner.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.maxY - fold))
        corner.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.maxY))
        corner.close()
        UIColor.black.withAlphaComponent(0.12).setFill()
        corner.fill()

        let fontSize = max(12, min(rect.width, rect.height) * 0.1)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let text = NSAttributedString(string: item.text, attributes: [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: UIColor(hex: 0x24221F),
            .paragraphStyle: paragraph,
        ])
        text.draw(with: rect.insetBy(dx: fontSize * 0.8, dy: fontSize * 0.8), options: [.usesLineFragmentOrigin, .usesFontLeading, .truncatesLastVisibleLine], context: nil)
    }

    // MARK: - Shapes

    static func path(for shape: BoardItem.Shape, in rect: CGRect) -> UIBezierPath {
        switch shape {
        case .rectangle:
            return UIBezierPath(rect: rect)
        case .roundedRectangle:
            return UIBezierPath(roundedRect: rect, cornerRadius: min(rect.width, rect.height) * 0.18)
        case .ellipse:
            return UIBezierPath(ovalIn: rect)
        case .triangle:
            let path = UIBezierPath()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.close()
            return path
        case .diamond:
            let path = UIBezierPath()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.close()
            return path
        case .star:
            let path = UIBezierPath()
            let center = CGPoint(x: rect.midX, y: rect.midY)
            for index in 0..<10 {
                let radius = index.isMultiple(of: 2) ? 0.5 : 0.21
                let angle = CGFloat(index) * .pi / 5 - .pi / 2
                let point = CGPoint(
                    x: center.x + cos(angle) * rect.width * radius,
                    y: center.y + sin(angle) * rect.height * radius
                )
                index == 0 ? path.move(to: point) : path.addLine(to: point)
            }
            path.close()
            return path
        case .arrow:
            let path = UIBezierPath()
            let shaftTop = rect.minY + rect.height * 0.3
            let shaftBottom = rect.maxY - rect.height * 0.3
            let headStart = rect.maxX - min(rect.width * 0.4, rect.height)
            path.move(to: CGPoint(x: rect.minX, y: shaftTop))
            path.addLine(to: CGPoint(x: headStart, y: shaftTop))
            path.addLine(to: CGPoint(x: headStart, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: headStart, y: rect.maxY))
            path.addLine(to: CGPoint(x: headStart, y: shaftBottom))
            path.addLine(to: CGPoint(x: rect.minX, y: shaftBottom))
            path.close()
            return path
        }
    }

    private static func drawShape(_ item: BoardItem, in rect: CGRect, context: CGContext) {
        let path = path(for: item.shape ?? .roundedRectangle, in: rect.insetBy(dx: 1.5, dy: 1.5))
        let fill = color(item)
        fill.withAlphaComponent(0.88).setFill()
        path.fill()
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        fill.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        UIColor(hue: hue, saturation: saturation, brightness: brightness * 0.72, alpha: 1).setStroke()
        path.lineWidth = 2.5
        path.lineJoinStyle = .round
        path.stroke()
    }

    // MARK: - Photos

    private static func drawImage(_ image: UIImage?, in rect: CGRect, context: CGContext, drawsShadow: Bool) {
        let rounded = UIBezierPath(roundedRect: rect, cornerRadius: 6)
        if drawsShadow {
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: 3), blur: 8, color: UIColor.black.withAlphaComponent(0.2).cgColor)
            UIColor.white.setFill()
            rounded.fill()
            context.restoreGState()
        }
        rounded.addClip()
        guard let image, image.size.width > 0, image.size.height > 0 else {
            UIColor(white: 0.88, alpha: 1).setFill()
            rounded.fill()
            return
        }
        // Aspect fill
        let scale = max(rect.width / image.size.width, rect.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        image.draw(in: CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height))
    }

    // MARK: - Graphs

    static let graphColors = [UIColor(hex: 0xD2462A), UIColor(hex: 0x2C55C9), UIColor(hex: 0x3F8A55)]

    private static func drawGraph(_ item: BoardItem, in rect: CGRect, context: CGContext, drawsShadow: Bool) {
        let card = UIBezierPath(roundedRect: rect, cornerRadius: 10)
        if drawsShadow {
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: 3), blur: 8, color: UIColor.black.withAlphaComponent(0.15).cgColor)
            UIColor.white.setFill()
            card.fill()
            context.restoreGState()
        }
        UIColor.white.setFill()
        card.fill()
        UIColor(hex: 0xD8D0C2).setStroke()
        card.lineWidth = 1
        card.stroke()

        let expressions = item.text
            .split(separator: "\n")
            .compactMap { MathExpression(String($0)) }
            .prefix(graphColors.count)

        // Legend
        var legendX = rect.minX + 14
        for (index, expression) in expressions.enumerated() {
            let label = NSAttributedString(string: expression.source, attributes: [
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: graphColors[index],
            ])
            label.draw(at: CGPoint(x: legendX, y: rect.minY + 10))
            legendX += label.size().width + 16
        }

        let plot = CGRect(x: rect.minX + 34, y: rect.minY + 36, width: rect.width - 48, height: rect.height - 58)
        guard plot.width > 20, plot.height > 20 else { return }
        let xMin = min(item.domainMin, item.domainMax - 0.001)
        let xMax = max(item.domainMax, xMin + 0.001)
        let samples = max(200, Int(plot.width * 1.5))

        var curves: [[Double]] = []
        var finiteValues: [Double] = []
        for expression in expressions {
            let values = (0...samples).map { step in
                expression.evaluate(x: xMin + (xMax - xMin) * Double(step) / Double(samples))
            }
            curves.append(values)
            finiteValues += values.filter(\.isFinite)
        }

        // Fit the y range to the curves, ignoring runaway values like tan's asymptotes.
        var yMin = -5.0
        var yMax = 5.0
        if !finiteValues.isEmpty {
            let sorted = finiteValues.sorted()
            yMin = sorted[Int(Double(sorted.count - 1) * 0.02)]
            yMax = sorted[Int(Double(sorted.count - 1) * 0.98)]
            if yMax - yMin < 1e-6 {
                yMin -= 1
                yMax += 1
            }
            let padding = (yMax - yMin) * 0.1
            yMin -= padding
            yMax += padding
        }

        func point(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(
                x: plot.minX + CGFloat((x - xMin) / (xMax - xMin)) * plot.width,
                y: plot.maxY - CGFloat((y - yMin) / (yMax - yMin)) * plot.height
            )
        }

        // Grid and labels
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular),
            .foregroundColor: UIColor(hex: 0x8A8378),
        ]
        let grid = UIBezierPath()
        let xStep = niceStep((xMax - xMin) / 6)
        var gridX = (xMin / xStep).rounded(.up) * xStep
        while gridX <= xMax {
            grid.move(to: point(gridX, yMin))
            grid.addLine(to: point(gridX, yMax))
            NSAttributedString(string: format(gridX), attributes: labelAttributes).draw(at: CGPoint(x: point(gridX, 0).x - 6, y: plot.maxY + 3))
            gridX += xStep
        }
        let yStep = niceStep((yMax - yMin) / 5)
        var gridY = (yMin / yStep).rounded(.up) * yStep
        while gridY <= yMax {
            grid.move(to: point(xMin, gridY))
            grid.addLine(to: point(xMax, gridY))
            let label = NSAttributedString(string: format(gridY), attributes: labelAttributes)
            label.draw(at: CGPoint(x: plot.minX - label.size().width - 4, y: point(0, gridY).y - 6))
            gridY += yStep
        }
        UIColor(hex: 0xEDE7DC).setStroke()
        grid.lineWidth = 0.75
        grid.stroke()

        let axes = UIBezierPath()
        if xMin <= 0 && xMax >= 0 {
            axes.move(to: point(0, yMin))
            axes.addLine(to: point(0, yMax))
        }
        if yMin <= 0 && yMax >= 0 {
            axes.move(to: point(xMin, 0))
            axes.addLine(to: point(xMax, 0))
        }
        UIColor(hex: 0x8A8378).setStroke()
        axes.lineWidth = 1.2
        axes.stroke()

        // Curves, broken at gaps and asymptotes
        context.saveGState()
        UIBezierPath(rect: plot).addClip()
        for (index, values) in curves.enumerated() {
            let curve = UIBezierPath()
            var previous: Double?
            for (step, y) in values.enumerated() {
                let x = xMin + (xMax - xMin) * Double(step) / Double(samples)
                guard y.isFinite else {
                    previous = nil
                    continue
                }
                if let previous, abs(y - previous) < (yMax - yMin) * 2 {
                    curve.addLine(to: point(x, y))
                } else {
                    curve.move(to: point(x, y))
                }
                previous = y
            }
            graphColors[index].setStroke()
            curve.lineWidth = 2.2
            curve.lineCapStyle = .round
            curve.lineJoinStyle = .round
            curve.stroke()
        }
        context.restoreGState()

        if expressions.isEmpty {
            NSAttributedString(string: "Type a function like y = sin(x)", attributes: [
                .font: UIFont.systemFont(ofSize: 13),
                .foregroundColor: UIColor(hex: 0x8A8378),
            ]).draw(at: CGPoint(x: plot.minX + 8, y: plot.midY - 8))
        }
    }

    /// 1, 2 or 5 times a power of ten, so grid labels are round numbers.
    private static func niceStep(_ rough: Double) -> Double {
        guard rough > 0, rough.isFinite else { return 1 }
        let magnitude = pow(10, floor(log10(rough)))
        let fraction = rough / magnitude
        let nice: Double = fraction < 1.5 ? 1 : fraction < 3.5 ? 2 : fraction < 7.5 ? 5 : 10
        return nice * magnitude
    }

    private static func format(_ value: Double) -> String {
        let rounded = (value * 1000).rounded() / 1000
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
    }
}
