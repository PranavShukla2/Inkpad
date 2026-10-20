//
//  LibraryView.swift
//  Inkpad
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum LibrarySection: Hashable {
    /// Folders plus the notebooks that aren't in one.
    case library
    /// Everything, newest first.
    case recents
    case favorites
    case documents
    case canvases
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
    @State private var section: LibrarySection? = .library
    @State private var searchText = ""
    @State private var openNotebook: Notebook?
    @State private var notebookToOpenAfterSheet: Notebook?
    @State private var isCreatingNotebook = false
    @State private var notebookBeingRenamed: Notebook?
    @State private var renameText = ""
    @State private var notebookToDelete: Notebook?
    @State private var notebookBeingCustomised: Notebook?
    @State private var isImportingPDF = false
    @State private var isCreatingFolder = false
    @State private var notebookToFileInNewFolder: Notebook?
    @State private var folderBeingRenamed: Folder?
    @State private var folderToDelete: Folder?
    @State private var folderNameText = ""
    @State private var importErrorMessage: String?
    @State private var dropTargetFolder: Folder?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            shelf
        }
        .tint(Theme.stamp)
        .sheet(isPresented: $isCreatingNotebook, onDismiss: openCreatedNotebook) {
            NewNotebookSheet { kind, title, cover, paperStyle, paperColor, pageSize in
                let notebook = switch kind {
                case .notebook:
                    Notebook.create(
                        in: modelContext,
                        title: title,
                        cover: cover.preset,
                        paperStyle: paperStyle,
                        paperColor: paperColor,
                        pageSize: pageSize
                    )
                case .canvas:
                    Notebook.createCanvas(in: modelContext, title: title, cover: cover.preset, paperStyle: paperStyle, paperColor: paperColor)
                }
                notebook.coverDraft = cover
                notebook.folder = selectedFolder
                notebookToOpenAfterSheet = notebook
            }
        }
        .fullScreenCover(item: $openNotebook) { notebook in
            NotebookEditorView(notebook: notebook, scrollAxis: tools.scrollAxis)
                .environment(tools)
                // The editor animates itself in, over the library.
                .presentationBackground(.clear)
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
                    section = .library
                }
                modelContext.delete(folder)
            }
        } message: { _ in
            Text("Notebooks inside it are kept and move back to the Library.")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                saveChanges()
            }
        }
        #if DEBUG
        .task {
            DemoContent.exportIfRequested(from: notebooks)
            if let title = UserDefaults.standard.string(forKey: "customiseCover") {
                notebookBeingCustomised = notebooks.first { $0.title == title }
            }
            if let text = UserDefaults.standard.string(forKey: "searchText") {
                searchText = text
            }
            if let title = DemoContent.notebookTitleToOpen {
                if let notebook = notebooks.first(where: { $0.title == title }) {
                    open(notebook)
                }
            }
        }
        #endif
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $section) {
            HStack(spacing: 10) {
                Image(systemName: "signature")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Theme.stamp, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                Text("Inkpad")
                    .font(.serif(.title2, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
            .padding(.bottom, 8)
            .listRowBackground(Color.clear)
            .selectionDisabled()
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            Label("Library", systemImage: "books.vertical")
                .tag(LibrarySection.library)
            Label("Recents", systemImage: "clock")
                .tag(LibrarySection.recents)
            Label("Favourites", systemImage: "star")
                .tag(LibrarySection.favorites)
            Label("Documents", systemImage: "doc.richtext")
                .tag(LibrarySection.documents)
            Label("Canvases", systemImage: "square.dashed")
                .tag(LibrarySection.canvases)

            Section {
                ForEach(folders) { folder in
                    Label {
                        Text(folder.name)
                    } icon: {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(Color(folder.color))
                    }
                    .badge(folder.notebooks.count)
                    .tag(LibrarySection.folder(folder))
                    .contextMenu {
                        folderMenu(folder)
                    }
                    .dropDestination(for: String.self) { items, _ in
                        file(items, into: folder)
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
        // The brand row at the top of the list stands in for the title.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Shelf

    private var shelf: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 4) {
                    if selectedFolder != nil {
                        Button {
                            withAnimation(.snappy) {
                                section = .library
                            }
                        } label: {
                            Label("Library", systemImage: "chevron.left")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.stamp)
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 4)
                    }
                    Text(sectionTitle)
                        .font(.serif(.largeTitle, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text(sectionSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSecondary)
                        .contentTransition(.numericText())
                }

                if visibleNotebooks.isEmpty && visibleFolders.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 32, alignment: .top)],
                        alignment: .leading,
                        spacing: 36
                    ) {
                        ForEach(visibleFolders) { folder in
                            folderCell(folder)
                        }
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
        .sheet(item: $notebookBeingCustomised) { notebook in
            NavigationStack {
                CoverEditorView(
                    draft: Binding(get: { notebook.coverDraft }, set: { notebook.coverDraft = $0 }),
                    title: notebook.displayTitle,
                    isCanvas: notebook.isCanvas
                )
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            notebookBeingCustomised = nil
                        }
                    }
                }
            }
            .tint(Theme.stamp)
        }
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
                    startCreatingFolder()
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
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
                open(notebook)
            } label: {
                NotebookCoverView(
                    title: notebook.displayTitle,
                    draft: notebook.coverDraft,
                    coverImageData: notebook.coverImageData,
                    isPDF: notebook.isPDF,
                    isCanvas: notebook.isCanvas,
                    isFavorite: notebook.isFavorite
                )
            }
            .buttonStyle(PressableButtonStyle())
            .draggable(notebook.dragID) {
                NotebookCoverView(title: notebook.displayTitle, draft: notebook.coverDraft, coverImageData: notebook.coverImageData, isPDF: notebook.isPDF, isCanvas: notebook.isCanvas)
                    .frame(width: 120)
            }

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

    private func folderCell(_ folder: Folder) -> some View {
        let isTargeted = dropTargetFolder == folder
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                section = .folder(folder)
            } label: {
                FolderTileView(
                    name: folder.name,
                    color: folder.color,
                    notebooks: folder.notebooks.sorted { $0.updatedAt > $1.updatedAt },
                    isDropTargeted: isTargeted
                )
            }
            .buttonStyle(PressableButtonStyle())
            .dropDestination(for: String.self) { items, _ in
                file(items, into: folder)
            } isTargeted: { targeted in
                dropTargetFolder = targeted ? folder : (dropTargetFolder == folder ? nil : dropTargetFolder)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(folder.name)
                    .font(.serif(.subheadline))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(folder.notebooks.count == 1 ? "1 notebook" : "\(folder.notebooks.count) notebooks")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .contextMenu {
            folderMenu(folder)
        }
    }

    @ViewBuilder
    private func folderMenu(_ folder: Folder) -> some View {
        Button("Open", systemImage: "folder") {
            section = .folder(folder)
        }
        Button("Rename", systemImage: "pencil") {
            folderNameText = folder.name
            folderBeingRenamed = folder
        }
        Menu("Colour", systemImage: "paintpalette") {
            Button("Kraft") {
                folder.colorHex = nil
            }
            ForEach(CoverStyle.allCases) { style in
                Button(style.name) {
                    folder.colorHex = style.color.hexString
                }
            }
        }
        Divider()
        Button("Delete Folder", systemImage: "trash", role: .destructive) {
            folderToDelete = folder
        }
    }

    /// Files dragged notebooks into a folder.
    private func file(_ items: [String], into folder: Folder) -> Bool {
        let dropped = items.compactMap(notebook(fromDragID:))
        guard !dropped.isEmpty else { return false }
        withAnimation(.snappy) {
            for notebook in dropped {
                notebook.folder = folder
            }
        }
        dropTargetFolder = nil
        return true
    }

    private func notebook(fromDragID dragID: String) -> Notebook? {
        guard let data = Data(base64Encoded: dragID),
              let id = try? JSONDecoder().decode(PersistentIdentifier.self, from: data) else { return nil }
        return modelContext.model(for: id) as? Notebook
    }

    @ViewBuilder
    private func notebookMenu(_ notebook: Notebook) -> some View {
        Button("Open", systemImage: "book") {
            open(notebook)
        }
        Button("Rename", systemImage: "pencil") {
            renameText = notebook.title
            notebookBeingRenamed = notebook
        }
        Button(notebook.isFavorite ? "Remove from Favourites" : "Add to Favourites", systemImage: notebook.isFavorite ? "star.slash" : "star") {
            notebook.isFavorite.toggle()
        }
        if !notebook.isPDF {
            Button("Customise Cover…", systemImage: "paintpalette") {
                notebookBeingCustomised = notebook
            }
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

    /// Folders sit at the top of the Library, unless searching.
    private var visibleFolders: [Folder] {
        guard (section ?? .library) == .library, searchText.isEmpty else { return [] }
        return folders
    }

    private var visibleNotebooks: [Notebook] {
        let inSection = notebooks.filter { notebook in
            switch section ?? .library {
            // Search the whole library, including inside folders.
            case .library: notebook.folder == nil || !searchText.isEmpty
            case .recents: true
            case .favorites: notebook.isFavorite
            case .documents: notebook.isPDF
            case .canvases: notebook.isCanvas
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

    private var sectionSubtitle: String {
        let notebookCount = visibleNotebooks.count
        let notebooksText = notebookCount == 1 ? "1 notebook" : "\(notebookCount) notebooks"
        guard !visibleFolders.isEmpty else { return notebooksText }
        let foldersText = visibleFolders.count == 1 ? "1 folder" : "\(visibleFolders.count) folders"
        return "\(foldersText) · \(notebooksText)"
    }

    private var sectionTitle: String {
        switch section ?? .library {
        case .library: "Library"
        case .recents: "Recents"
        case .favorites: "Favourites"
        case .documents: "Documents"
        case .canvases: "Canvases"
        case .folder(let folder): folder.name
        }
    }

    private var emptyTitle: String {
        switch section ?? .library {
        case .library, .recents: "Your shelf is empty"
        case .favorites: "No favourites yet"
        case .documents: "No documents yet"
        case .canvases: "No canvases yet"
        case .folder: "This folder is empty"
        }
    }

    private var emptyMessage: String {
        switch section ?? .library {
        case .library, .recents: "Create a notebook to start writing."
        case .favorites: "Long-press a notebook and add it to your favourites."
        case .documents: "Imported PDFs appear here."
        case .canvases: "Create a canvas for an endless board to sketch and plan on."
        case .folder: "Drag a notebook onto this folder, or long-press it and choose Move to Folder."
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
            open(notebook)
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }

    /// Presents the editor without the system's slide or swipe-to-dismiss;
    /// the editor plays its own open and close animation.
    private func open(_ notebook: Notebook) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            openNotebook = notebook
        }
    }

    private func openCreatedNotebook() {
        if let notebook = notebookToOpenAfterSheet {
            notebookToOpenAfterSheet = nil
            open(notebook)
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
