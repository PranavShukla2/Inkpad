//
//  NotebookEditorModel.swift
//  Inkpad
//

import SwiftUI
import PencilKit

/// Connects a notebook to its canvas: loads pages, saves ink in the background,
/// and performs page operations.
@Observable
final class NotebookEditorModel {
    let notebook: Notebook
    private(set) var pages: [Page]
    private(set) var currentPageIndex: Int
    private(set) var canUndo = false
    private(set) var canRedo = false

    @ObservationIgnored private weak var canvas: NotebookCanvasView?
    /// The notebook's PDF, if any. Safe to read from background threads.
    @ObservationIgnored let pdf: CGPDFDocument?
    /// The last data written for each page, to skip unchanged pages.
    @ObservationIgnored private var savedData: [Data?] = []
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    /// Bumped whenever pages are added, removed or reordered, so an in-flight
    /// background save can't write ink to the wrong page.
    @ObservationIgnored private var layoutVersion = 0

    init(notebook: Notebook) {
        self.notebook = notebook
        let pages = notebook.sortedPages
        self.pages = pages
        self.currentPageIndex = min(max(notebook.currentPageIndex, 0), max(pages.count - 1, 0))
        self.pdf = notebook.pdfData
            .flatMap { CGDataProvider(data: $0 as CFData) }
            .flatMap { CGPDFDocument($0) }
    }

    var currentPage: Page? {
        pages.indices.contains(currentPageIndex) ? pages[currentPageIndex] : nil
    }

    func attach(_ canvas: NotebookCanvasView) {
        self.canvas = canvas
        canvas.onDrawingChanged = { [weak self] in
            self?.drawingChanged()
        }
        canvas.onCurrentPageChanged = { [weak self] index in
            self?.currentPageIndex = index
        }
        reloadCanvas(scrollTo: currentPageIndex)
    }

    // MARK: - Saving

    private func drawingChanged() {
        // Undo state settles after the change that triggered this.
        DispatchQueue.main.async { [weak self] in
            self?.updateUndoState()
        }
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            await self?.save()
        }
    }

    private func save() async {
        guard let canvas else { return }
        let drawing = canvas.canvasView.drawing
        let layout = canvas.layout
        let version = layoutVersion
        let data = await Task.detached(priority: .userInitiated) {
            layout.split(drawing).map { $0.dataRepresentation() }
        }.value
        guard version == layoutVersion else { return }
        apply(data)
    }

    /// Writes any pending ink immediately.
    func saveNow() {
        saveTask?.cancel()
        guard let canvas else { return }
        apply(canvas.pageDrawings().map { $0.dataRepresentation() })
    }

    private func apply(_ data: [Data]) {
        guard data.count == pages.count else { return }
        var changed = false
        for (index, pageData) in data.enumerated() where savedData[index] != pageData {
            pages[index].drawingData = pageData
            pages[index].updatedAt = .now
            savedData[index] = pageData
            changed = true
        }
        if changed {
            notebook.updatedAt = .now
        }
    }

    func close() {
        saveNow()
        notebook.currentPageIndex = currentPageIndex
        canvas?.canvasView.undoManager?.removeAllActions()
    }

    // MARK: - Undo

    func undo() {
        canvas?.canvasView.undoManager?.undo()
        updateUndoState()
    }

    func redo() {
        canvas?.canvasView.undoManager?.redo()
        updateUndoState()
    }

    private func updateUndoState() {
        canUndo = canvas?.canvasView.undoManager?.canUndo ?? false
        canRedo = canvas?.canvasView.undoManager?.canRedo ?? false
    }

    // MARK: - Pages

    func scrollToPage(_ index: Int) {
        canvas?.scrollToPage(index, animated: true)
    }

    func addPage(after index: Int? = nil) {
        insertPage(at: (index ?? currentPageIndex) + 1)
    }

    /// Inserts a blank page using the paper of the page it follows.
    func insertPage(at index: Int) {
        let neighbour = pages.indices.contains(index - 1) ? pages[index - 1] : pages.first
        let style = neighbour.map { $0.pdfPageIndex == nil ? $0.paperStyle : notebook.paperStyle } ?? notebook.paperStyle
        changePages(scrollTo: index) {
            notebook.insertPage(at: index, paperStyle: style)
        }
    }

    func duplicatePage(at index: Int) {
        guard pages.indices.contains(index) else { return }
        changePages(scrollTo: index + 1) {
            let source = pages[index]
            let copy = notebook.insertPage(
                at: index + 1,
                paperStyle: source.paperStyle,
                size: source.size,
                pdfPageIndex: source.pdfPageIndex
            )
            copy.drawingData = source.drawingData
            copy.recognizedText = source.recognizedText
        }
    }

    func deletePage(at index: Int) {
        guard pages.count > 1, pages.indices.contains(index) else { return }
        changePages(scrollTo: min(index, pages.count - 2)) {
            notebook.removePage(pages[index])
        }
    }

    func movePage(from source: Int, to destination: Int) {
        guard source != destination else { return }
        changePages(scrollTo: destination) {
            notebook.movePage(from: source, to: destination)
        }
    }

    func setPaperStyle(_ style: PaperStyle, forPageAt index: Int) {
        guard pages.indices.contains(index), pages[index].pdfPageIndex == nil else { return }
        changePages(scrollTo: index) {
            pages[index].paperStyle = style
        }
    }

    func setPaperStyleForAllPages(_ style: PaperStyle) {
        changePages(scrollTo: currentPageIndex) {
            notebook.paperStyle = style
            for page in pages where page.pdfPageIndex == nil {
                page.paperStyle = style
            }
        }
    }

    func setPaperColor(_ color: PaperColor) {
        changePages(scrollTo: currentPageIndex) {
            notebook.paperColor = color
        }
    }

    /// Saves ink, applies a structural change, then reloads the canvas.
    private func changePages(scrollTo index: Int, _ change: () -> Void) {
        saveNow()
        change()
        notebook.updatedAt = .now
        reloadCanvas(scrollTo: index)
    }

    private func reloadCanvas(scrollTo index: Int) {
        layoutVersion += 1
        pages = notebook.sortedPages
        savedData = pages.map(\.drawingData)
        currentPageIndex = min(max(index, 0), max(pages.count - 1, 0))
        canvas?.load(specs: pages.map(\.spec), paperColor: notebook.paperColor, pdf: pdf, scrollTo: currentPageIndex)
        updateUndoState()
    }
}
