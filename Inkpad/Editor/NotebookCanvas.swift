//
//  NotebookCanvas.swift
//  Inkpad
//

import SwiftUI

struct NotebookCanvas: UIViewRepresentable {
    let model: NotebookEditorModel
    let tools: ToolState
    let topInset: CGFloat
    var onMessage: (String) -> Void = { _ in }

    func makeUIView(context: Context) -> NotebookCanvasView {
        let canvas = NotebookCanvasView()
        canvas.topInset = topInset
        canvas.onPencilTap = { [tools] action in
            tools.handlePencilTap(action)
        }
        canvas.onMessage = onMessage
        model.attach(canvas)
        return canvas
    }

    func updateUIView(_ canvas: NotebookCanvasView, context: Context) {
        canvas.topInset = topInset
        canvas.apply(
            tool: tools.pkTool,
            key: tools.toolKey,
            isRulerActive: tools.isRulerActive,
            isProtractorActive: tools.isProtractorActive,
            allowsFingerDrawing: tools.allowsFingerDrawing,
            snapsShapes: tools.tool == .shape,
            laserColor: tools.tool == .laser ? tools.color : nil,
            laserMode: tools.laserMode,
            textStyle: tools.tool == .text ? (tools.textSize, tools.color) : nil,
            isTextPen: tools.tool == .textPen,
            eraserWidth: tools.tool == .eraser ? tools.eraserWidth : nil
        )
    }
}
