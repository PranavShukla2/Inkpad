//
//  NoteEditorView.swift
//  Inkpad
//

import SwiftUI
import PencilKit

struct NoteEditorView: View {
    @Bindable var note: Note
    // Loaded once so the canvas isn't re-decoded on every stroke.
    @State private var initialDrawing: PKDrawing

    init(note: Note) {
        _note = Bindable(note)
        _initialDrawing = State(initialValue: note.drawing)
    }

    var body: some View {
        CanvasView(drawing: initialDrawing) { drawing in
            note.drawing = drawing
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationTitle($note.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarRole(.editor)
    }
}
