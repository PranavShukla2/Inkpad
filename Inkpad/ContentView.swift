//
//  ContentView.swift
//  Inkpad
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedNote: Note?

    var body: some View {
        NavigationSplitView {
            NotesListView(selection: $selectedNote)
        } detail: {
            if let selectedNote {
                NoteEditorView(note: selectedNote)
                    .id(selectedNote.id)
            } else {
                ContentUnavailableView(
                    "No Note Selected",
                    systemImage: "pencil.and.scribble",
                    description: Text("Pick a note from the sidebar or create a new one.")
                )
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // SwiftData autosaves, but don't risk losing the last strokes if the app is killed.
            if phase == .background {
                saveChanges()
            }
        }
    }

    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            print("Failed to save notes: \(error)")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Note.self, inMemory: true)
}
