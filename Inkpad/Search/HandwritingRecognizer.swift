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
        guard let drawingData,
              let drawing = try? PKDrawing(data: drawingData),
              !drawing.strokes.isEmpty else { return "" }

        // Dark ink on white reads best, whatever the paper colour.
        let pageRect = CGRect(origin: .zero, size: pageSize)
        let ink = drawing.image(from: pageRect, scale: 2, style: .light)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let image = UIGraphicsImageRenderer(size: pageSize, format: format).image { context in
            UIColor.white.setFill()
            context.fill(pageRect)
            ink.draw(in: pageRect)
        }
        guard let cgImage = image.cgImage else { return "" }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        do {
            try VNImageRequestHandler(cgImage: cgImage).perform([request])
        } catch {
            return ""
        }
        return (request.results ?? [])
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
