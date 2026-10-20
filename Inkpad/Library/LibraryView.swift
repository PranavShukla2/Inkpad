//
//  LibraryView.swift
//  Inkpad
//

import SwiftUI
import SwiftData

enum LibrarySection: Hashable {
    case all
    case favorites
    case documents
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
    @AppStorage("librarySort") private var sort = LibrarySort.modified
    @State private var section: LibrarySection? = .all
    @State private var searchText = ""
    @State private var openNotebook: Notebook?
    @State private var notebookToOpenAfterSheet: Notebook?
    @State private var isCreatingNotebook = false
    @State private var notebookBeingRenamed: Notebook?
    @State private var renameText = ""
    @State private var notebookToDelete: Notebook?
    @Namespace private var transitionNamespace

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            shelf
        }
        .tint(Theme.stamp)
        .sheet(isPresented: $isCreatingNotebook, onDismiss: openCreatedNotebook) {
            NewNotebookSheet { title, cover, paperStyle, paperColor in
                notebookToOpenAfterSheet = Notebook.create(
                    in: modelContext,
                    title: title,
                    cover: cover,
                    paperStyle: paperStyle,
                    paperColor: paperColor
                )
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
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                saveChanges()
            }
        }
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
        .searchable(text: $searchText, prompt: "Search notebooks")
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
                    isCreatingNotebook = true
                } label: {
                    Label("New Notebook", systemImage: "plus")
                }
            }
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
                Text(notebook.updatedAt, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
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
                if section == .all || section == nil {
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
            }
        }
        let matching = searchText.isEmpty
            ? inSection
            : inSection.filter { $0.displayTitle.localizedStandardContains(searchText) }
        switch sort {
        case .modified:
            return matching
        case .created:
            return matching.sorted { $0.createdAt > $1.createdAt }
        case .title:
            return matching.sorted { $0.displayTitle.localizedStandardCompare($1.displayTitle) == .orderedAscending }
        }
    }

    private var sectionTitle: String {
        switch section ?? .all {
        case .all: "All Notebooks"
        case .favorites: "Favourites"
        case .documents: "Documents"
        }
    }

    private var emptyTitle: String {
        switch section ?? .all {
        case .all: "Your shelf is empty"
        case .favorites: "No favourites yet"
        case .documents: "No documents yet"
        }
    }

    private var emptyMessage: String {
        switch section ?? .all {
        case .all: "Create a notebook to start writing."
        case .favorites: "Long-press a notebook and add it to your favourites."
        case .documents: "Imported PDFs appear here."
        }
    }

    // MARK: - Actions

    private var isRenaming: Binding<Bool> {
        Binding(get: { notebookBeingRenamed != nil }, set: { if !$0 { notebookBeingRenamed = nil } })
    }

    private var isDeleting: Binding<Bool> {
        Binding(get: { notebookToDelete != nil }, set: { if !$0 { notebookToDelete = nil } })
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
