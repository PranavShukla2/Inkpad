//
//  HandwritingRecognizer.swift
//  Inkpad
//

import UIKit
import PencilKit
import SwiftData
import Vision

/// Reads handwriting on a page with on-device Vision text recognition.
nonisolated enum HandwritingRecognizer {
    static func recognizeText(in drawingData: Data?, pageSize: CGSize) -> String {
        guard let drawingData, let drawing = try? PKDrawing(data: drawingData) else { return "" }
        return recognizeText(in: drawing, area: CGRect(origin: .zero, size: pageSize))
    }

    /// Reads the handwriting inside one area, e.g. what the Text Pen just wrote.
    static func recognizeText(in drawing: PKDrawing, area: CGRect) -> String {
        guard !drawing.strokes.isEmpty, !area.isNull, !area.isEmpty else { return "" }

        // Dark ink on white reads best, whatever the paper colour. Small areas
        // are rendered larger so short words have enough pixels.
        let area = area.insetBy(dx: -16, dy: -16)
        let scale = min(max(1200 / max(area.width, area.height), 2), 4)
        let ink = drawing.image(from: area, scale: scale, style: .light)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let canvas = CGRect(origin: .zero, size: area.size)
        let image = UIGraphicsImageRenderer(size: area.size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(canvas)
            ink.draw(in: canvas)
        }
        guard let cgImage = image.cgImage else { return "" }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        do {
            try VNImageRequestHandler(cgImage: cgImage).perform([request])
        } catch {
            return ""
        }
        // Reading order: top to bottom, then left to right within a line.
        // Vision's bounding boxes have their origin at the bottom left.
        let lines = (request.results ?? []).sorted { first, second in
            let a = first.boundingBox
            let b = second.boundingBox
            if abs(a.midY - b.midY) < min(a.height, b.height) / 2 {
                return a.minX < b.minX
            }
            return a.midY > b.midY
        }
        return lines
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }

    /// Recognises each page in the background and stores the text for search.
    @MainActor
    static func update(_ pages: [Page]) async {
        for page in pages {
            let data = page.drawingData
            let size = page.size
            let text = await Task.detached(priority: .utility) {
                recognizeText(in: data, pageSize: size)
            }.value
            guard !page.isDeleted, page.modelContext != nil else { continue }
            page.recognizedText = text
        }
    }
}
