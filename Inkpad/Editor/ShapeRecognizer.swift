//
//  ShapeRecognizer.swift
//  Inkpad
//

import PencilKit

/// Turns a hand-drawn line, triangle, rectangle, polygon or ellipse into a clean one.
nonisolated enum ShapeRecognizer {
    static func recognize(_ stroke: PKStroke) -> PKStroke? {
        let points = stroke.path.map { $0.location.applying(stroke.transform) }
        guard points.count >= 4 else { return nil }
        let bounds = boundingBox(of: points)
        let size = max(bounds.width, bounds.height)
        guard size >= 16 else { return nil }

        let first = points[0]
        let last = points[points.count - 1]
        let gap = distance(first, last)
        let isClosed = gap < max(24, pathLength(points) * 0.15)

        if !isClosed {
            guard maxDistance(of: points, toLineFrom: first, to: last) < max(5, gap * 0.07) else { return nil }
            return makeStroke(through: [first, last], like: stroke)
        }

        var corners = simplify(points + [first], tolerance: size * 0.09)
        if corners.count > 1, distance(corners[0], corners[corners.count - 1]) < 1 {
            corners.removeLast()
        }
        corners = removeStraightVertices(from: corners, size: size)

        if corners.count == 3 {
            return makeStroke(through: corners + [corners[0]], like: stroke)
        }
        if corners.count == 4, isAxisAligned(corners) {
            let rect = [
                CGPoint(x: bounds.minX, y: bounds.minY),
                CGPoint(x: bounds.maxX, y: bounds.minY),
                CGPoint(x: bounds.maxX, y: bounds.maxY),
                CGPoint(x: bounds.minX, y: bounds.maxY),
            ]
            return makeStroke(through: rect + [rect[0]], like: stroke)
        }
        // Flattened ellipses simplify to a diamond, so check the curve before polygons.
        if fitsEllipse(points, in: bounds) {
            return makeStroke(through: ellipse(in: bounds), like: stroke)
        }
        if corners.count == 4 || corners.count == 5 {
            return makeStroke(through: corners + [corners[0]], like: stroke)
        }
        return nil
    }

    // MARK: - Building strokes

    static func makeStroke(through vertices: [CGPoint], like original: PKStroke) -> PKStroke {
        let sizes = original.path.map(\.size.width).sorted()
        let width = sizes.isEmpty ? 3 : sizes[sizes.count / 2]
        var points: [PKStrokePoint] = []
        var time: TimeInterval = 0

        func append(_ location: CGPoint) {
            points.append(PKStrokePoint(
                location: location,
                timeOffset: time,
                size: CGSize(width: width, height: width),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: .pi / 2
            ))
            time += 0.004
        }

        // Dense points keep edges straight and corners crisp.
        for (start, end) in zip(vertices, vertices.dropFirst()) {
            let steps = max(1, Int(distance(start, end) / 3))
            for step in 0..<steps {
                let t = CGFloat(step) / CGFloat(steps)
                append(CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t))
            }
        }
        if let last = vertices.last {
            append(last)
        }
        return PKStroke(ink: original.ink, path: PKStrokePath(controlPoints: points, creationDate: .now))
    }

    private static func ellipse(in rect: CGRect) -> [CGPoint] {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var radiusX = rect.width / 2
        var radiusY = rect.height / 2
        // Nearly round shapes become circles.
        if abs(radiusX - radiusY) < max(radiusX, radiusY) * 0.12 {
            let radius = (radiusX + radiusY) / 2
            radiusX = radius
            radiusY = radius
        }
        return (0...96).map { step in
            let angle = CGFloat(step) / 96 * 2 * .pi
            return CGPoint(x: center.x + cos(angle) * radiusX, y: center.y + sin(angle) * radiusY)
        }
    }

    // MARK: - Geometry

    private static func fitsEllipse(_ points: [CGPoint], in rect: CGRect) -> Bool {
        let radiusX = rect.width / 2
        let radiusY = rect.height / 2
        guard radiusX > 0, radiusY > 0 else { return false }
        let error = points.reduce(0) { total, point in
            let dx = (point.x - rect.midX) / radiusX
            let dy = (point.y - rect.midY) / radiusY
            return total + abs(sqrt(dx * dx + dy * dy) - 1)
        } / CGFloat(points.count)
        return error < 0.14
    }

    private static func isAxisAligned(_ corners: [CGPoint]) -> Bool {
        for index in corners.indices {
            let start = corners[index]
            let end = corners[(index + 1) % corners.count]
            let angle = abs(atan2(end.y - start.y, end.x - start.x)) * 180 / .pi
            let offAxis = min(angle, abs(angle - 90), abs(angle - 180))
            if offAxis > 15 {
                return false
            }
        }
        return true
    }

    /// Drops vertices where the outline barely turns, or that sit too close to a neighbour.
    private static func removeStraightVertices(from corners: [CGPoint], size: CGFloat) -> [CGPoint] {
        var corners = corners
        var changed = true
        while changed, corners.count > 3 {
            changed = false
            for index in corners.indices {
                let previous = corners[(index - 1 + corners.count) % corners.count]
                let vertex = corners[index]
                let next = corners[(index + 1) % corners.count]
                if angle(at: vertex, from: previous, to: next) > 150 || distance(previous, vertex) < size * 0.12 {
                    corners.remove(at: index)
                    changed = true
                    break
                }
            }
        }
        return corners
    }

    private static func angle(at vertex: CGPoint, from a: CGPoint, to b: CGPoint) -> CGFloat {
        let v1 = CGPoint(x: a.x - vertex.x, y: a.y - vertex.y)
        let v2 = CGPoint(x: b.x - vertex.x, y: b.y - vertex.y)
        let lengths = hypot(v1.x, v1.y) * hypot(v2.x, v2.y)
        guard lengths > 0 else { return 180 }
        let cosine = max(-1, min(1, (v1.x * v2.x + v1.y * v2.y) / lengths))
        return acos(cosine) * 180 / .pi
    }

    /// Ramer–Douglas–Peucker line simplification.
    private static func simplify(_ points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        guard points.count > 2 else { return points }
        let first = points[0]
        let last = points[points.count - 1]
        var farthestIndex = 0
        var farthestDistance: CGFloat = 0
        for index in 1..<(points.count - 1) {
            let d = distance(from: points[index], toLineFrom: first, to: last)
            if d > farthestDistance {
                farthestDistance = d
                farthestIndex = index
            }
        }
        guard farthestDistance > tolerance else { return [first, last] }
        let left = simplify(Array(points[...farthestIndex]), tolerance: tolerance)
        let right = simplify(Array(points[farthestIndex...]), tolerance: tolerance)
        return left.dropLast() + right
    }

    private static func maxDistance(of points: [CGPoint], toLineFrom a: CGPoint, to b: CGPoint) -> CGFloat {
        points.map { distance(from: $0, toLineFrom: a, to: b) }.max() ?? 0
    }

    private static func distance(from point: CGPoint, toLineFrom a: CGPoint, to b: CGPoint) -> CGFloat {
        let length = distance(a, b)
        guard length > 0 else { return distance(point, a) }
        return abs((b.x - a.x) * (a.y - point.y) - (a.x - point.x) * (b.y - a.y)) / length
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(b.x - a.x, b.y - a.y)
    }

    private static func pathLength(_ points: [CGPoint]) -> CGFloat {
        zip(points, points.dropFirst()).reduce(0) { $0 + distance($1.0, $1.1) }
    }

    private static func boundingBox(of points: [CGPoint]) -> CGRect {
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return .null }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
