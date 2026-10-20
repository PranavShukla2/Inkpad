//
//  NotebookCanvas.swift
//  Inkpad
//

import SwiftUI

struct NotebookCanvas: UIViewRepresentable {
    let model: NotebookEditorModel
    let tools: ToolState
    let topInset: CGFloat

    func makeUIView(context: Context) -> NotebookCanvasView {
        let canvas = NotebookCanvasView()
        canvas.topInset = topInset
        canvas.onPencilTap = { [tools] action in
            tools.handlePencilTap(action)
        }
        model.attach(canvas)
        return canvas
    }

    func updateUIView(_ canvas: NotebookCanvasView, context: Context) {
        canvas.topInset = topInset
        canvas.apply(
            tool: tools.pkTool,
            isRulerActive: tools.isRulerActive,
            allowsFingerDrawing: tools.allowsFingerDrawing,
            snapsShapes: tools.tool == .shape
        )
    }
}
