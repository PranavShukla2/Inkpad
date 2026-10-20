//
//  CanvasView.swift
//  Inkpad
//

import SwiftUI
import PencilKit

/// A PencilKit canvas with the system tool picker. The page grows downward as you write.
struct CanvasView: UIViewRepresentable {
    let drawing: PKDrawing
    var onDrawingChanged: (PKDrawing) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDrawingChanged: onDrawingChanged)
    }

    func makeUIView(context: Context) -> GrowingCanvasView {
        let canvas = GrowingCanvasView()
        canvas.drawing = drawing
        canvas.delegate = context.coordinator
        canvas.drawingPolicy = .default
        canvas.backgroundColor = .white
        canvas.overrideUserInterfaceStyle = .light
        canvas.alwaysBounceVertical = true

        let toolPicker = context.coordinator.toolPicker
        toolPicker.colorUserInterfaceStyle = .light
        toolPicker.addObserver(canvas)
        toolPicker.setVisible(true, forFirstResponder: canvas)
        DispatchQueue.main.async {
            canvas.becomeFirstResponder()
        }
        return canvas
    }

    func updateUIView(_ canvas: GrowingCanvasView, context: Context) {
        context.coordinator.onDrawingChanged = onDrawingChanged
    }

    static func dismantleUIView(_ canvas: GrowingCanvasView, coordinator: Coordinator) {
        coordinator.toolPicker.setVisible(false, forFirstResponder: canvas)
        coordinator.toolPicker.removeObserver(canvas)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let toolPicker = PKToolPicker()
        var onDrawingChanged: (PKDrawing) -> Void

        init(onDrawingChanged: @escaping (PKDrawing) -> Void) {
            self.onDrawingChanged = onDrawingChanged
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            (canvasView as? GrowingCanvasView)?.updateContentSize()
            onDrawingChanged(canvasView.drawing)
        }
    }
}

/// Keeps at least half a screen of empty space below the lowest stroke.
final class GrowingCanvasView: PKCanvasView {
    override func layoutSubviews() {
        super.layoutSubviews()
        updateContentSize()
    }

    func updateContentSize() {
        let drawingBounds = drawing.bounds
        let drawingBottom = drawingBounds.isNull ? 0 : drawingBounds.maxY
        let size = CGSize(
            width: bounds.width,
            height: max(bounds.height, drawingBottom + bounds.height / 2)
        )
        if contentSize != size {
            contentSize = size
        }
    }
}
