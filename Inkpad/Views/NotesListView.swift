//
//  NotesListView.swift
//  Inkpad
//

import SwiftUI
import SwiftData
import PDFKit
import UniformTypeIdentifiers

struct NotesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]
    @Binding var selection: Note?
    @State private var noteBeingRenamed: Note?
    @State private var renameText = ""
    @State private var searchText = ""
    @State private var isImportingPDF = false
    @State private var importErrorMessage: String?

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
            ToolbarItemGroup {
                Button {
                    isImportingPDF = true
                } label: {
                    Label("Import PDF", systemImage: "doc.badge.plus")
                }
                Button(action: addNote) {
                    Label("New Note", systemImage: "square.and.pencil")
                }
            }
        }
        .fileImporter(isPresented: $isImportingPDF, allowedContentTypes: [.pdf], onCompletion: importPDF)
        .alert(
            "Couldn't Import PDF",
            isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { if !$0 { importErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage ?? "")
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

    private func importPDF(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let isAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if isAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            guard let document = PDFDocument(data: data), !document.isLocked else {
                importErrorMessage = "\"\(url.lastPathComponent)\" may be damaged or password-protected."
                return
            }

            let note = Note(title: url.deletingPathExtension().lastPathComponent)
            note.pdfData = data
            withAnimation {
                modelContext.insert(note)
                selection = note
            }
        } catch {
            importErrorMessage = error.localizedDescription
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
