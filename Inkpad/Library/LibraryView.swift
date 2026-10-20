//
//  LibraryView.swift
//  Inkpad
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum LibrarySection: Hashable {
    case all
    case favorites
    case documents
    case folder(Folder)
}

enum LibrarySort: String, CaseIterable, Identifiable {
    case modified
    case created
    case title

    var id: String { rawValue }

    var name: String {
        switch self {
        case .modified: "Date Modified"
        case .created: "Date Created"
        case .title: "Title"
        }
    }
}

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ToolState.self) private var tools
    @Query(sort: \Notebook.updatedAt, order: .reverse) private var notebooks: [Notebook]
    @Query(sort: \Folder.name) private var folders: [Folder]
    @AppStorage("librarySort") private var sort = LibrarySort.modified
    @State private var section: LibrarySection? = .all
    @State private var searchText = ""
    @State private var openNotebook: Notebook?
    @State private var notebookToOpenAfterSheet: Notebook?
    @State private var isCreatingNotebook = false
    @State private var notebookBeingRenamed: Notebook?
    @State private var renameText = ""
    @State private var notebookToDelete: Notebook?
    @State private var isImportingPDF = false
    @State private var isCreatingFolder = false
    @State private var notebookToFileInNewFolder: Notebook?
    @State private var folderBeingRenamed: Folder?
    @State private var folderToDelete: Folder?
    @State private var folderNameText = ""
    @State private var importErrorMessage: String?
    @Namespace private var transitionNamespace

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            shelf
        }
        .tint(Theme.stamp)
        .sheet(isPresented: $isCreatingNotebook, onDismiss: openCreatedNotebook) {
            NewNotebookSheet { title, cover, paperStyle, paperColor, pageSize in
                let notebook = Notebook.create(
                    in: modelContext,
                    title: title,
                    cover: cover,
                    paperStyle: paperStyle,
                    paperColor: paperColor,
                    pageSize: pageSize
                )
                notebook.folder = selectedFolder
                notebookToOpenAfterSheet = notebook
            }
        }
        .fullScreenCover(item: $openNotebook) { notebook in
            NotebookEditorView(notebook: notebook)
                .environment(tools)
                .zoomTransition(sourceID: notebook.persistentModelID, in: transitionNamespace)
        }
        .alert("Rename Notebook", isPresented: isRenaming, presenting: notebookBeingRenamed) { notebook in
            TextField("Title", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                let title = renameText.trimmingCharacters(in: .whitespaces)
                notebook.title = title.isEmpty ? Notebook.defaultTitle : title
            }
        }
        .confirmationDialog(
            "Delete this notebook?",
            isPresented: isDeleting,
            titleVisibility: .visible,
            presenting: notebookToDelete
        ) { notebook in
            Button("Delete “\(notebook.displayTitle)”", role: .destructive) {
                withAnimation {
                    modelContext.delete(notebook)
                }
            }
        } message: { _ in
            Text("All of its pages will be deleted. This can't be undone.")
        }
        .alert("New Folder", isPresented: $isCreatingFolder) {
            TextField("Name", text: $folderNameText)
            Button("Cancel", role: .cancel) {
                notebookToFileInNewFolder = nil
            }
            Button("Create", action: createFolder)
        }
        .alert("Rename Folder", isPresented: isRenamingFolder, presenting: folderBeingRenamed) { folder in
            TextField("Name", text: $folderNameText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                let name = folderNameText.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    folder.name = name
                }
            }
        }
        .confirmationDialog(
            "Delete this folder?",
            isPresented: isDeletingFolder,
            titleVisibility: .visible,
            presenting: folderToDelete
        ) { folder in
            Button("Delete “\(folder.name)”", role: .destructive) {
                if section == .folder(folder) {
                    section = .all
                }
                modelContext.delete(folder)
            }
        } message: { _ in
            Text("Notebooks inside it are kept and move back to All Notebooks.")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                saveChanges()
            }
        }
        #if DEBUG
        .task {
            DemoContent.exportIfRequested(from: notebooks)
            if let text = UserDefaults.standard.string(forKey: "searchText") {
                searchText = text
            }
            if let title = DemoContent.notebookTitleToOpen {
                openNotebook = notebooks.first { $0.title == title }
            }
        }
        #endif
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $section) {
            Label("All Notebooks", systemImage: "books.vertical")
                .tag(LibrarySection.all)
            Label("Favourites", systemImage: "star")
                .tag(LibrarySection.favorites)
            Label("Documents", systemImage: "doc.richtext")
                .tag(LibrarySection.documents)

            Section {
                ForEach(folders) { folder in
                    Label(folder.name, systemImage: "folder")
                        .badge(folder.notebooks.count)
                        .tag(LibrarySection.folder(folder))
                        .contextMenu {
                            Button("Rename", systemImage: "pencil") {
                                folderNameText = folder.name
                                folderBeingRenamed = folder
                            }
                            Button("Delete Folder", systemImage: "trash", role: .destructive) {
                                folderToDelete = folder
                            }
                        }
                }
                Button {
                    startCreatingFolder()
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                        .foregroundStyle(Theme.stamp)
                }
                .buttonStyle(.plain)
            } header: {
                Text("Folders")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.deskRaised)
        .navigationTitle("Inkpad")
    }

    // MARK: - Shelf

    private var shelf: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text(sectionTitle)
                    .font(.serif(.largeTitle, weight: .bold))
                    .foregroundStyle(Theme.ink)

                if visibleNotebooks.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 32, alignment: .top)],
                        alignment: .leading,
                        spacing: 36
                    ) {
                        ForEach(visibleNotebooks) { notebook in
                            notebookCell(notebook)
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
        }
        .background(Theme.desk)
        .searchable(text: $searchText, prompt: "Search")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("")
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Picker("Sort By", selection: $sort) {
                        ForEach(LibrarySort.allCases) { sort in
                            Text(sort.name).tag(sort)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
                Button {
                    isImportingPDF = true
                } label: {
                    Label("Import PDF", systemImage: "doc.badge.arrow.up")
                }
                Button {
                    isCreatingNotebook = true
                } label: {
                    Label("New Notebook", systemImage: "plus")
                }
            }
        }
        .fileImporter(isPresented: $isImportingPDF, allowedContentTypes: [.pdf], onCompletion: importPDF)
        .alert(
            "Couldn't Import PDF",
            isPresented: Binding(get: { importErrorMessage != nil }, set: { if !$0 { importErrorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage ?? "")
        }
    }

    private func notebookCell(_ notebook: Notebook) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                openNotebook = notebook
            } label: {
                NotebookCoverView(
                    title: notebook.displayTitle,
                    cover: notebook.cover,
                    coverImageData: notebook.coverImageData,
                    isPDF: notebook.isPDF,
                    isFavorite: notebook.isFavorite
                )
            }
            .buttonStyle(PressableButtonStyle())
            .zoomTransitionSource(id: notebook.persistentModelID, in: transitionNamespace)

            VStack(alignment: .leading, spacing: 2) {
                Text(notebook.displayTitle)
                    .font(.serif(.subheadline))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                if let snippet = searchSnippet(for: notebook) {
                    Text(snippet)
                        .font(.caption)
                        .foregroundStyle(Theme.stamp)
                        .lineLimit(2)
                } else {
                    Text(notebook.updatedAt, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
        }
        .contextMenu {
            notebookMenu(notebook)
        }
    }

    @ViewBuilder
    private func notebookMenu(_ notebook: Notebook) -> some View {
        Button("Open", systemImage: "book") {
            openNotebook = notebook
        }
        Button("Rename", systemImage: "pencil") {
            renameText = notebook.title
            notebookBeingRenamed = notebook
        }
        Button(notebook.isFavorite ? "Remove from Favourites" : "Add to Favourites", systemImage: notebook.isFavorite ? "star.slash" : "star") {
            notebook.isFavorite.toggle()
        }
        if !notebook.isPDF {
            Picker("Cover", selection: Binding(get: { notebook.cover }, set: { notebook.cover = $0 })) {
                ForEach(CoverStyle.allCases) { style in
                    Text(style.name).tag(style)
                }
            }
            .pickerStyle(.menu)
        }
        Menu("Move to Folder", systemImage: "folder") {
            Button("None") {
                notebook.folder = nil
            }
            .disabled(notebook.folder == nil)
            ForEach(folders) { folder in
                Button(folder.name) {
                    notebook.folder = folder
                }
                .disabled(notebook.folder == folder)
            }
            Divider()
            Button("New Folder…", systemImage: "folder.badge.plus") {
                notebookToFileInNewFolder = notebook
                startCreatingFolder()
            }
        }
        ShareLink(
            item: NotebookExport(title: notebook.displayTitle) { notebook.snapshot },
            preview: SharePreview(notebook.displayTitle)
        ) {
            Label("Export PDF", systemImage: "square.and.arrow.up")
        }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) {
            notebookToDelete = notebook
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !searchText.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            ContentUnavailableView {
                Label(emptyTitle, systemImage: "book.closed")
                    .font(.serif(.title2))
            } description: {
                Text(emptyMessage)
            } actions: {
                if section == .documents {
                    Button("Import PDF") {
                        isImportingPDF = true
                    }
                    .buttonStyle(.borderedProminent)
                } else if section != .favorites {
                    Button("New Notebook") {
                        isCreatingNotebook = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    // MARK: - Filtering

    private var visibleNotebooks: [Notebook] {
        let inSection = notebooks.filter { notebook in
            switch section ?? .all {
            case .all: true
            case .favorites: notebook.isFavorite
            case .documents: notebook.isPDF
            case .folder(let folder): notebook.folder == folder
            }
        }
        let matching = searchText.isEmpty
            ? inSection
            : inSection.filter { notebook in
                notebook.displayTitle.localizedStandardContains(searchText) || searchSnippet(for: notebook) != nil
            }
        switch sort {
        case .modified:
            return matching
        case .created:
            return matching.sorted { $0.createdAt > $1.createdAt }
        case .title:
            return matching.sorted { $0.displayTitle.localizedStandardCompare($1.displayTitle) == .orderedAscending }
        }
    }

    /// A short excerpt around the first handwriting or PDF text match.
    private func searchSnippet(for notebook: Notebook) -> String? {
        guard !searchText.isEmpty else { return nil }
        for page in notebook.sortedPages {
            for text in [page.recognizedText, page.documentText] where !text.isEmpty {
                guard let range = text.range(of: searchText, options: [.caseInsensitive, .diacriticInsensitive]) else { continue }
                let start = text.index(range.lowerBound, offsetBy: -24, limitedBy: text.startIndex) ?? text.startIndex
                let end = text.index(range.upperBound, offsetBy: 40, limitedBy: text.endIndex) ?? text.endIndex
                let excerpt = text[start..<end].replacingOccurrences(of: "\n", with: " ")
                return "p. \(page.index + 1): " + (start > text.startIndex ? "…" : "") + excerpt + (end < text.endIndex ? "…" : "")
            }
        }
        return nil
    }

    private var sectionTitle: String {
        switch section ?? .all {
        case .all: "All Notebooks"
        case .favorites: "Favourites"
        case .documents: "Documents"
        case .folder(let folder): folder.name
        }
    }

    private var emptyTitle: String {
        switch section ?? .all {
        case .all: "Your shelf is empty"
        case .favorites: "No favourites yet"
        case .documents: "No documents yet"
        case .folder: "This folder is empty"
        }
    }

    private var emptyMessage: String {
        switch section ?? .all {
        case .all: "Create a notebook to start writing."
        case .favorites: "Long-press a notebook and add it to your favourites."
        case .documents: "Imported PDFs appear here."
        case .folder: "Long-press a notebook and choose Move to Folder."
        }
    }

    // MARK: - Actions

    private var isRenaming: Binding<Bool> {
        Binding(get: { notebookBeingRenamed != nil }, set: { if !$0 { notebookBeingRenamed = nil } })
    }

    private var selectedFolder: Folder? {
        if case .folder(let folder) = section {
            return folder
        }
        return nil
    }

    private var isRenamingFolder: Binding<Bool> {
        Binding(get: { folderBeingRenamed != nil }, set: { if !$0 { folderBeingRenamed = nil } })
    }

    private var isDeletingFolder: Binding<Bool> {
        Binding(get: { folderToDelete != nil }, set: { if !$0 { folderToDelete = nil } })
    }

    private func startCreatingFolder() {
        folderNameText = ""
        isCreatingFolder = true
    }

    private func createFolder() {
        let name = folderNameText.trimmingCharacters(in: .whitespaces)
        let folder = Folder(name: name.isEmpty ? "New Folder" : name)
        modelContext.insert(folder)
        if let notebook = notebookToFileInNewFolder {
            notebook.folder = folder
            notebookToFileInNewFolder = nil
        }
    }

    private var isDeleting: Binding<Bool> {
        Binding(get: { notebookToDelete != nil }, set: { if !$0 { notebookToDelete = nil } })
    }

    private func importPDF(_ result: Result<URL, Error>) {
        do {
            let notebook = try PDFImporter.makeNotebook(from: result.get(), in: modelContext)
            openNotebook = notebook
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }

    private func openCreatedNotebook() {
        if let notebook = notebookToOpenAfterSheet {
            notebookToOpenAfterSheet = nil
            openNotebook = notebook
        }
    }

    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            print("Failed to save notebooks: \(error)")
        }
    }
}

/// Covers dip slightly when pressed.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}
