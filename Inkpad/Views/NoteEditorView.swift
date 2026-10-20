//
//  NoteEditorView.swift
//  Inkpad
//

import SwiftUI
import PencilKit

struct NoteEditorView: View {
    let note: Note

    var body: some View {
        CanvasView(drawing: PKDrawing())
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(note.title)
            .navigationBarTitleDisplayMode(.inline)
    }
}
