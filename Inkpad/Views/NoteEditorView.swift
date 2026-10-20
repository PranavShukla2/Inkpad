//
//  NoteEditorView.swift
//  Inkpad
//

import SwiftUI
import PencilKit
import PDFKit

struct NoteEditorView: View {
    @Bindable var note: Note
    // Loaded once so the canvas isn't re-decoded on every stroke.
    @State private var initialDrawing: PKDrawing
    @State private var document: PDFDocument?

    init(note: Note) {
        _note = Bindable(note)
        _initialDrawing = State(initialValue: note.drawing)
        _document = State(initialValue: note.pdfData.flatMap { PDFDocument(data: $0) })
    }

    var body: some View {
        content
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle($note.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarRole(.editor)
            .task(id: note.updatedAt) {
                // Refresh the sidebar preview once the user pauses writing.
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                note.updateThumbnail()
            }
            .onDisappear {
                note.updateThumbnail()
            }
    }

    @ViewBuilder
    private var content: some View {
        if let document {
            PDFAnnotationView(document: document)
        } else {
            CanvasView(drawing: initialDrawing) { drawing in
                note.drawing = drawing
            }
        }
    }
}
