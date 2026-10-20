//
//  DemoContent.swift
//  Inkpad
//
//  Debug-only sample notebooks for checking layouts in the simulator.
//  Launch with -seedDemo to replace the library, and -openFirstNotebook to open one.
//

#if DEBUG
import Foundation
import PencilKit
import SwiftData

enum DemoContent {
    static var shouldOpenFirstNotebook: Bool {
        ProcessInfo.processInfo.arguments.contains("-openFirstNotebook")
    }

    static func seedIfRequested(in context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-seedDemo") else { return }
        try? context.delete(model: Notebook.self)

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
            notebook.updatedAt = .now.addingTimeInterval(-Double(index) * 5400)
        }
        try? context.save()
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
