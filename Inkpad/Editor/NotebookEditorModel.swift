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
    private(set) var scrollAxis: ScrollAxis

    @ObservationIgnored private weak var canvas: NotebookCanvasView?
    /// The notebook's PDF, if any. Safe to read from background threads.
    @ObservationIgnored let pdf: CGPDFDocument?
    /// Fingerprints of each page's ink as last saved, to skip unchanged pages.
    @ObservationIgnored private var savedSignatures: [Int] = []
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    /// Bumped whenever pages are added, removed or reordered, so an in-flight
    /// background save can't write ink to the wrong page.
    @ObservationIgnored private var layoutVersion = 0
    @ObservationIgnored private var pagesNeedingRecognition: [Page] = []
    @ObservationIgnored private var recognitionTask: Task<Void, Never>?

    init(notebook: Notebook, scrollAxis: ScrollAxis) {
        self.notebook = notebook
        self.scrollAxis = scrollAxis
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
        if !notebook.isCanvas {
            canvas.onAddPageRequested = { [weak self] in
                self?.appendPage()
            }
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
        let saved = savedSignatures
        let version = layoutVersion
        let changes = await Task.detached(priority: .userInitiated) {
            Self.changedPages(in: layout.split(drawing), comparedTo: saved)
        }.value
        guard version == layoutVersion else { return }
        apply(changes)
    }

    /// Writes any pending ink immediately.
    func saveNow() {
        saveTask?.cancel()
        guard let canvas else { return }
        apply(Self.changedPages(in: canvas.pageDrawings(), comparedTo: savedSignatures))
    }

    private struct PageChange: Sendable {
        let index: Int
        let signature: Int
        let data: Data
    }

    /// Encodes only the pages whose ink differs from what was last saved.
    nonisolated private static func changedPages(in drawings: [PKDrawing], comparedTo saved: [Int]) -> [PageChange] {
        guard drawings.count == saved.count else { return [] }
        return drawings.enumerated().compactMap { index, drawing in
            let signature = drawing.contentSignature
            guard signature != saved[index] else { return nil }
            return PageChange(index: index, signature: signature, data: drawing.dataRepresentation())
        }
    }

    private func apply(_ changes: [PageChange]) {
        var changedPages: [Page] = []
        for change in changes where pages.indices.contains(change.index) {
            let page = pages[change.index]
            page.drawingData = change.data
            page.updatedAt = .now
            savedSignatures[change.index] = change.signature
            changedPages.append(page)
        }
        if !changedPages.isEmpty {
            notebook.updatedAt = .now
            scheduleRecognition(for: changedPages)
            growBoardIfNeeded()
        }
    }

    /// Canvas boards grow right and down when ink gets near an edge.
    private func growBoardIfNeeded() {
        guard notebook.isCanvas, let page = pages.first, let canvas else { return }
        let bounds = canvas.pageDrawings().first?.bounds ?? .null
        guard !bounds.isNull else { return }
        let margin = Notebook.canvasGrowth / 2
        var size = page.size
        if bounds.maxX > size.width - margin {
            size.width += Notebook.canvasGrowth
        }
        if bounds.maxY > size.height - margin {
            size.height += Notebook.canvasGrowth
        }
        guard size != page.size else { return }
        page.width = size.width
        page.height = size.height
        canvas.resizeBoard(to: size)
    }

    /// Reads handwriting a couple of seconds after writing stops.
    private func scheduleRecognition(for changedPages: [Page]) {
        for page in changedPages where !pagesNeedingRecognition.contains(page) {
            pagesNeedingRecognition.append(page)
        }
        recognitionTask?.cancel()
        recognitionTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.recognizePendingPages()
        }
    }

    private func recognizePendingPages() {
        let pending = pagesNeedingRecognition
        pagesNeedingRecognition = []
        guard !pending.isEmpty else { return }
        // Not tied to the editor, so it finishes even after the notebook closes.
        Task {
            await HandwritingRecognizer.update(pending)
        }
    }

    func close() {
        saveNow()
        recognitionTask?.cancel()
        recognizePendingPages()
        if notebook.isPDF {
            notebook.updateCoverImage()
        }
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

    /// Adds a page at the end in place, so the canvas doesn't reload or jump.
    func appendPage() {
        saveNow()
        let style = pages.last.map { $0.pdfPageIndex == nil ? $0.paperStyle : notebook.paperStyle } ?? notebook.paperStyle
        let page = notebook.insertPage(at: pages.count, paperStyle: style)
        notebook.updatedAt = .now
        pages = notebook.sortedPages
        savedSignatures.append(PKDrawing().contentSignature)
        let appended = canvas?.appendPage(page.spec, paperColor: notebook.paperColor, pdf: pdf) ?? false
        if !appended {
            reloadCanvas(scrollTo: pages.count - 1)
        }
    }

    func addPage(after index: Int? = nil) {
        if (index ?? currentPageIndex) == pages.count - 1 {
            appendPage()
            return
        }
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
            copy.documentText = source.documentText
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

    func setScrollAxis(_ axis: ScrollAxis) {
        guard axis != scrollAxis else { return }
        scrollAxis = axis
        changePages(scrollTo: currentPageIndex) {}
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
        // Boards stay where you were looking; notebooks jump to the affected page.
        reloadCanvas(scrollTo: index, keepViewport: notebook.isCanvas)
    }

    private func reloadCanvas(scrollTo index: Int, keepViewport: Bool = false) {
        layoutVersion += 1
        pages = notebook.sortedPages
        currentPageIndex = min(max(index, 0), max(pages.count - 1, 0))
        canvas?.load(
            specs: pages.map(\.spec),
            paperColor: notebook.paperColor,
            pdf: pdf,
            axis: scrollAxis,
            isBoard: notebook.isCanvas,
            scrollTo: currentPageIndex,
            keepViewport: keepViewport
        )
        // Fingerprint through the same split that saves use, so untouched pages match.
        savedSignatures = canvas?.pageDrawings().map(\.contentSignature) ?? []
        updateUndoState()
    }
}
