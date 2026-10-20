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
    @State private var noteBeingRenamed: Note?
    @State private var renameText = ""

    var body: some View {
        List(selection: $selection) {
            ForEach(notes) { note in
                NavigationLink(value: note) {
                    NoteRow(note: note)
                }
                .contextMenu {
                    Button {
                        startRenaming(note)
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        withAnimation {
                            delete(note)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
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
        .alert("Rename Note", isPresented: isRenaming, presenting: noteBeingRenamed) { note in
            TextField("Title", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                let title = renameText.trimmingCharacters(in: .whitespaces)
                note.title = title.isEmpty ? Note.defaultTitle : title
            }
        }
    }

    private var isRenaming: Binding<Bool> {
        Binding(
            get: { noteBeingRenamed != nil },
            set: { if !$0 { noteBeingRenamed = nil } }
        )
    }

    private func startRenaming(_ note: Note) {
        renameText = note.title
        noteBeingRenamed = note
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
