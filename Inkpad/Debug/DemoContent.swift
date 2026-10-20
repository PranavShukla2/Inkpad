//
//  DemoContent.swift
//  Inkpad
//
//  Debug-only sample notebooks for checking layouts in the simulator.
//  Launch with -seedDemo to replace the library, and -openNotebook "Title" to open one.
//

#if DEBUG
import UIKit
import PencilKit
import SwiftData

enum DemoContent {
    /// Launch arguments like `-openNotebook Diary` land in user defaults.
    static var notebookTitleToOpen: String? {
        UserDefaults.standard.string(forKey: "openNotebook")
    }

    static func seedIfRequested(in context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-seedDemo") else { return }
        try? context.delete(model: Notebook.self)
        try? context.delete(model: Folder.self)
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
        }
        if let notebook = try? PDFImporter.makeNotebook(from: samplePDF(), in: context) {
            notebook.sortedPages.first?.drawingData = scribbles().dataRepresentation()
            notebook.updatedAt = .now.addingTimeInterval(-60)
        }
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
