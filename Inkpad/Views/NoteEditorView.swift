//
//  NoteEditorView.swift
//  Inkpad
//

import SwiftUI
import PencilKit

struct NoteEditorView: View {
    let note: Note
    // Loaded once so the canvas isn't re-decoded on every stroke.
    @State private var initialDrawing: PKDrawing

    init(note: Note) {
        self.note = note
        _initialDrawing = State(initialValue: note.drawing)
    }

    var body: some View {
        CanvasView(drawing: initialDrawing) { drawing in
            note.drawing = drawing
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationTitle(note.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
