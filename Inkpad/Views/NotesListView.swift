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
    @State private var searchText = ""

    private var filteredNotes: [Note] {
        guard !searchText.isEmpty else { return notes }
        return notes.filter { $0.displayTitle.localizedStandardContains(searchText) }
    }

    var body: some View {
        List(selection: $selection) {
            ForEach(filteredNotes) { note in
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
        .overlay {
            if notes.isEmpty {
                ContentUnavailableView {
                    Label("No Notes", systemImage: "note.text")
                } description: {
                    Text("Create a note to start writing.")
                } actions: {
                    Button("New Note", action: addNote)
                }
            } else if filteredNotes.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .searchable(text: $searchText, prompt: "Search notes")
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
                delete(filteredNotes[index])
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
