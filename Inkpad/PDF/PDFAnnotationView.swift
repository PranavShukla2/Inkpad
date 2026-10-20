//
//  PDFAnnotationView.swift
//  Inkpad
//

import SwiftUI
import PDFKit
import PencilKit

/// A PDF viewer with a transparent PencilKit canvas over every page.
/// Apple Pencil draws; fingers scroll and zoom.
struct PDFAnnotationView: UIViewRepresentable {
    let document: PDFDocument
    let pageDrawingData: [Int: Data]
    var onPageDrawingsChanged: ([Int: Data]) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(document: document, pageDrawingData: pageDrawingData, onPageDrawingsChanged: onPageDrawingsChanged)
    }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        // Lets the page overlays receive touches instead of PDFView's text selection.
        pdfView.isInMarkupMode = true
        pdfView.pageOverlayViewProvider = context.coordinator
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.autoScales = true
        pdfView.backgroundColor = .secondarySystemBackground
        pdfView.document = document
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        context.coordinator.onPageDrawingsChanged = onPageDrawingsChanged
    }

    final class Coordinator: NSObject, PDFPageOverlayViewProvider, PKCanvasViewDelegate {
        let document: PDFDocument
        let toolPicker = PKToolPicker()
        var pageDrawingData: [Int: Data]
        var onPageDrawingsChanged: ([Int: Data]) -> Void
        /// Overlays for the pages currently on screen, keyed by page index.
        private var canvases: [Int: PKCanvasView] = [:]

        init(document: PDFDocument, pageDrawingData: [Int: Data], onPageDrawingsChanged: @escaping ([Int: Data]) -> Void) {
            self.document = document
            self.pageDrawingData = pageDrawingData
            self.onPageDrawingsChanged = onPageDrawingsChanged
            toolPicker.colorUserInterfaceStyle = .light
        }

        func pdfView(_ view: PDFView, overlayViewFor page: PDFPage) -> UIView? {
            let pageIndex = document.index(for: page)
            if let canvas = canvases[pageIndex] {
                return canvas
            }

            let canvas = PKCanvasView()
            canvas.tag = pageIndex
            canvas.backgroundColor = .clear
            canvas.isOpaque = false
            canvas.overrideUserInterfaceStyle = .light
            canvas.drawingPolicy = .pencilOnly
            // PDFView does the scrolling; the canvas must not swallow finger pans.
            canvas.isScrollEnabled = false
            if let data = pageDrawingData[pageIndex], let drawing = try? PKDrawing(data: data) {
                canvas.drawing = drawing
            }
            canvas.delegate = self

            toolPicker.addObserver(canvas)
            toolPicker.setVisible(true, forFirstResponder: canvas)
            if !canvases.values.contains(where: \.isFirstResponder) {
                DispatchQueue.main.async {
                    canvas.becomeFirstResponder()
                }
            }
            canvases[pageIndex] = canvas
            return canvas
        }

        func pdfView(_ pdfView: PDFView, willEndDisplayingOverlayView overlayView: UIView, for page: PDFPage) {
            guard let canvas = overlayView as? PKCanvasView else { return }
            let wasFirstResponder = canvas.isFirstResponder
            toolPicker.setVisible(false, forFirstResponder: canvas)
            toolPicker.removeObserver(canvas)
            canvases[canvas.tag] = nil
            // Keep the tool picker on screen by handing it to another visible page.
            if wasFirstResponder {
                canvases.values.first?.becomeFirstResponder()
            }
        }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            if !canvasView.isFirstResponder {
                canvasView.becomeFirstResponder()
            }
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let drawing = canvasView.drawing
            pageDrawingData[canvasView.tag] = drawing.strokes.isEmpty ? nil : drawing.dataRepresentation()
            onPageDrawingsChanged(pageDrawingData)
        }
    }
}
