//
//  NoteEditorView.swift
//  Inkpad
//

import SwiftUI

struct NoteEditorView: View {
    let note: Note

    var body: some View {
        Text(note.title)
            .navigationTitle(note.title)
            .navigationBarTitleDisplayMode(.inline)
    }
}
