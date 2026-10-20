//
//  NotesListView.swift
//  Inkpad
//

import SwiftUI
import SwiftData

struct NotesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]
    @Binding var selection: Note?

    var body: some View {
        List(selection: $selection) {
            ForEach(notes) { note in
                NavigationLink(value: note) {
                    NoteRow(note: note)
                }
            }
            .onDelete(perform: deleteNotes)
        }
        .navigationTitle("Notes")
        .toolbar {
            ToolbarItem {
                Button(action: addNote) {
                    Label("New Note", systemImage: "square.and.pencil")
                }
            }
        }
    }

    private func addNote() {
        withAnimation {
            let note = Note()
            modelContext.insert(note)
            selection = note
        }
    }

    private func deleteNotes(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                delete(notes[index])
            }
        }
    }

    private func delete(_ note: Note) {
        if selection == note {
            selection = nil
        }
        modelContext.delete(note)
    }
}
