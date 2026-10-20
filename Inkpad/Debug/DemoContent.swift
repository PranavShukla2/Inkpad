//
//  DemoContent.swift
//  Inkpad
//
//  Debug-only sample notebooks for checking layouts in the simulator.
//  Launch with -seedDemo to replace the library, and -openNotebook "Title" to open one.
//

#if DEBUG
import UIKit
import CoreText
import PencilKit
import SwiftData

enum DemoContent {
    /// Launch arguments like `-openNotebook Diary` land in user defaults.
    static var notebookTitleToOpen: String? {
        UserDefaults.standard.string(forKey: "openNotebook")
    }

    static func seedIfRequested(in context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-seedDemo") else { return }
        // Batch deletes fail on relationships, so remove items one by one.
        for notebook in (try? context.fetch(FetchDescriptor<Notebook>())) ?? [] {
            context.delete(notebook)
        }
        for folder in (try? context.fetch(FetchDescriptor<Folder>())) ?? [] {
            context.delete(folder)
        }
        let university = Folder(name: "University")
        let personal = Folder(name: "Personal")
        context.insert(university)
        context.insert(personal)

        let samples: [(String, CoverStyle, PaperStyle, PaperColor)] = [
            ("Physics", .ink, .grid, .white),
            ("Diary", .stamp, .lined, .ivory),
            ("Ideas", .moss, .dots, .white),
            ("Music Theory", .plum, .music, .white),
            ("Night Sketches", .charcoal, .blank, .dusk),
            ("Lecture Notes", .ochre, .cornell, .ivory),
            ("Geometry", .slate, .isometric, .white),
            ("Travel", .sand, .wideLined, .ivory),
        ]
        for (index, sample) in samples.enumerated() {
            let notebook = Notebook.create(in: context, title: sample.0, cover: sample.1, paperStyle: sample.2, paperColor: sample.3)
            notebook.sortedPages.first?.drawingData = scribbles().dataRepresentation()
            notebook.insertPage(at: 1)
            notebook.isFavorite = index == 1 || index == 3
            notebook.folder = [0, 3, 5].contains(index) ? university : [1, 7].contains(index) ? personal : nil
            notebook.updatedAt = .now.addingTimeInterval(-Double(index) * 5400)
            let designs: [CoverDesign] = [.cloth, .leather, .terrazzo, .stripes, .linen, .waves, .grid, .dots]
            let labels: [CoverLabelStyle] = [.plate, .plate, .corner, .band, .plate, .corner, .band, .plate]
            notebook.coverDesignRaw = designs[index].rawValue
            notebook.coverLabelRaw = labels[index].rawValue
            notebook.coverEmblem = ["🔭", "", "💡", "🎵", "", "", "📐", "✈️"][index]
        }
        let lecture = Notebook.create(in: context, title: "Handwriting Test", cover: .ochre, paperStyle: .lined, paperColor: .white)
        lecture.sortedPages.first?.drawingData = textInk(["Meeting notes", "Buy milk tomorrow", "Call Sam at 5pm"]).dataRepresentation()
        lecture.updatedAt = .now.addingTimeInterval(-10)

        let board = Notebook.createCanvas(in: context, title: "Project Board", cover: .moss, paperStyle: .dots, paperColor: .white)
        board.sortedPages.first?.drawingData = scribbles()
            .transformed(using: CGAffineTransform(translationX: 7600, y: 7700))
            .dataRepresentation()
        board.sortedPages.first?.items = demoBoardItems(for: board, in: context)
        board.updatedAt = .now.addingTimeInterval(-30)

        if let notebook = try? PDFImporter.makeNotebook(from: samplePDF(), in: context) {
            notebook.sortedPages.first?.drawingData = scribbles().dataRepresentation()
            notebook.updatedAt = .now.addingTimeInterval(-60)
        }
        try? context.save()
    }

    /// Launch with `-seedLegacyNotes YES` to add first-version notes before migration runs.
    static func seedLegacyNotesIfRequested(in context: ModelContext) {
        guard UserDefaults.standard.bool(forKey: "seedLegacyNotes") else { return }
        let drawingNote = Note(title: "Old Drawing Note")
        // Wider than a page and taller than one, like a landscape canvas.
        var drawing = scribbles()
        drawing.append(scribbles().transformed(using: CGAffineTransform(translationX: 400, y: 1300)))
        drawingNote.drawingData = drawing.dataRepresentation()
        context.insert(drawingNote)

        let pdfNote = Note(title: "Old PDF Note")
        pdfNote.pdfData = try? Data(contentsOf: samplePDF())
        pdfNote.pageDrawingData = [1: scribbles().dataRepresentation()]
        context.insert(pdfNote)
        try? context.save()
    }

    /// Launch with `-exportNotebook Title` to write that notebook's PDF to Documents.
    static func exportIfRequested(from notebooks: [Notebook]) {
        guard let title = UserDefaults.standard.string(forKey: "exportNotebook"),
              let notebook = notebooks.first(where: { $0.title == title }) else { return }
        let url = URL.documentsDirectory.appending(path: "export.pdf")
        try? NotebookPDFRenderer.render(notebook.snapshot).write(to: url)
    }

    private static func samplePDF() -> URL {
        let url = URL.temporaryDirectory.appending(path: "Sample Reading.pdf")
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let data = UIGraphicsPDFRenderer(bounds: pageRect).pdfData { context in
            for page in 1...3 {
                context.beginPage()
                let title = "Chapter \(page): Notes on Ink" as NSString
                title.draw(at: CGPoint(x: 72, y: 72), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 26)])
                let body = String(repeating: "The quick brown fox jumps over the lazy dog. ", count: 30) as NSString
                body.draw(in: pageRect.insetBy(dx: 72, dy: 130), withAttributes: [.font: UIFont.systemFont(ofSize: 13)])
            }
        }
        try? data.write(to: url)
        return url
    }

    /// Sticky notes, shapes, a photo and a graph around the middle of a board.
    private static func demoBoardItems(for board: Notebook, in context: ModelContext) -> [BoardItem] {
        let origin = CGPoint(x: 7600, y: 7300)
        var items: [BoardItem] = []
        for (index, text) in ["Launch plan", "Ask Sam about the budget", "Sketch the logo"].enumerated() {
            var note = BoardItem(kind: .sticky, x: origin.x + Double(index) * 250, y: origin.y, width: 220, height: 220, colorHex: BoardItem.stickyColors[index])
            note.text = text
            items.append(note)
        }
        for (index, shape) in [BoardItem.Shape.ellipse, .star, .arrow].enumerated() {
            var item = BoardItem(kind: .shape, x: origin.x + Double(index) * 230, y: origin.y + 820, width: shape == .arrow ? 220 : 180, height: shape == .arrow ? 100 : 180, colorHex: BoardItem.shapeColors[index])
            item.shape = shape
            items.append(item)
        }
        var graph = BoardItem(kind: .graph, x: origin.x + 780, y: origin.y, width: 440, height: 320, colorHex: "FFFFFF")
        graph.text = "y = sin(x)\ny = x^2/10 - 2"
        items.append(graph)

        let photo = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 400)).image { context in
            let colors = [UIColor(hex: 0xF4A259).cgColor, UIColor(hex: 0x5B8E7D).cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: 400), options: [])
            UIColor(hex: 0xFFF3D6).setFill()
            UIBezierPath(ovalIn: CGRect(x: 380, y: 60, width: 110, height: 110)).fill()
            UIColor(hex: 0x2F4858).setFill()
            let hills = UIBezierPath()
            hills.move(to: CGPoint(x: 0, y: 400))
            hills.addCurve(to: CGPoint(x: 600, y: 300), controlPoint1: CGPoint(x: 150, y: 180), controlPoint2: CGPoint(x: 380, y: 380))
            hills.addLine(to: CGPoint(x: 600, y: 400))
            hills.fill()
        }
        if let data = photo.jpegData(compressionQuality: 0.85) {
            let attachment = Attachment(data: data)
            context.insert(attachment)
            board.attachments.append(attachment)
            var item = BoardItem(kind: .image, x: origin.x + 780, y: origin.y + 400, width: 330, height: 220, colorHex: "FFFFFF")
            item.imageID = attachment.id
            items.append(item)
        }
        return items
    }

    /// Ink that traces a handwriting-style font, for testing text recognition.
    private static func textInk(_ lines: [String]) -> PKDrawing {
        let font = CTFontCreateWithName("Noteworthy-Light" as CFString, 44, nil)
        let ink = PKInk(.pen, color: .black)
        var strokes: [PKStroke] = []
        for (row, line) in lines.enumerated() {
            let attributed = NSAttributedString(string: line, attributes: [.font: font])
            let ctLine = CTLineCreateWithAttributedString(attributed)
            for run in CTLineGetGlyphRuns(ctLine) as! [CTRun] {
                let count = CTRunGetGlyphCount(run)
                var glyphs = Array(repeating: CGGlyph(), count: count)
                var positions = Array(repeating: CGPoint.zero, count: count)
                CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
                CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
                for (glyph, position) in zip(glyphs, positions) {
                    guard let path = CTFontCreatePathForGlyph(font, glyph, nil) else { continue }
                    // Font paths are y-up; flip onto the page.
                    let origin = CGPoint(x: 100 + position.x, y: 150 + CGFloat(row) * 78)
                    var points: [CGPoint] = []
                    func flush() {
                        if points.count > 1 {
                            let strokePoints = points.enumerated().map { index, point in
                                PKStrokePoint(location: point, timeOffset: Double(index) * 0.01, size: CGSize(width: 2.5, height: 2.5), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
                            }
                            strokes.append(PKStroke(ink: ink, path: PKStrokePath(controlPoints: strokePoints, creationDate: .now)))
                        }
                        points = []
                    }
                    path.applyWithBlock { element in
                        let p = element.pointee.points
                        func map(_ point: CGPoint) -> CGPoint { CGPoint(x: origin.x + point.x, y: origin.y - point.y) }
                        switch element.pointee.type {
                        case .moveToPoint:
                            flush()
                            points.append(map(p[0]))
                        case .addLineToPoint:
                            points.append(map(p[0]))
                        case .addQuadCurveToPoint:
                            points.append(map(p[0]))
                            points.append(map(p[1]))
                        case .addCurveToPoint:
                            points.append(map(p[0]))
                            points.append(map(p[1]))
                            points.append(map(p[2]))
                        case .closeSubpath:
                            if let first = points.first { points.append(first) }
                            flush()
                        @unknown default:
                            break
                        }
                    }
                    flush()
                }
            }
        }
        return PKDrawing(strokes: strokes)
    }

    /// Wavy lines that look roughly like handwriting.
    private static func scribbles() -> PKDrawing {
        var strokes: [PKStroke] = []
        let ink = PKInk(.pen, color: .black)
        for row in 0..<7 {
            let y = 160 + CGFloat(row) * 52
            var points: [PKStrokePoint] = []
            let length = CGFloat([520, 470, 560, 380, 500, 430, 300][row])
            for step in stride(from: 0, through: length, by: 4) {
                let wobble = sin(step / 9) * 7 + sin(step / 23) * 4
                points.append(PKStrokePoint(
                    location: CGPoint(x: 110 + step, y: y + wobble),
                    timeOffset: TimeInterval(step) / 400,
                    size: CGSize(width: 2.6, height: 2.6),
                    opacity: 1,
                    force: 1,
                    azimuth: 0,
                    altitude: .pi / 2
                ))
            }
            strokes.append(PKStroke(ink: ink, path: PKStrokePath(controlPoints: points, creationDate: .now)))
        }
        return PKDrawing(strokes: strokes)
    }
}
#endif
