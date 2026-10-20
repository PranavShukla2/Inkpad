//
//  ContentView.swift
//  Inkpad
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedNote: Note?

    var body: some View {
        NavigationSplitView {
            NotesListView(selection: $selectedNote)
        } detail: {
            if let selectedNote {
                NoteEditorView(note: selectedNote)
            } else {
                ContentUnavailableView(
                    "No Note Selected",
                    systemImage: "pencil.and.scribble",
                    description: Text("Pick a note from the sidebar or create a new one.")
                )
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Note.self, inMemory: true)
}
