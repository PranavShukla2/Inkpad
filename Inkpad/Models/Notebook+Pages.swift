//
//  Notebook+Pages.swift
//  Inkpad
//

import Foundation
import SwiftData

extension Notebook {
    /// Creates a notebook with one blank page and adds it to the context.
    static func create(
        in context: ModelContext,
        title: String = Notebook.defaultTitle,
        cover: CoverStyle = .ink,
        paperStyle: PaperStyle = .lined,
        paperColor: PaperColor = .white
    ) -> Notebook {
        let notebook = Notebook(title: title, cover: cover, paperStyle: paperStyle, paperColor: paperColor)
        context.insert(notebook)
        notebook.insertPage(at: 0)
        return notebook
    }

    /// New pages match the width of a PDF's pages, or use the standard size.
    var newPageSize: CGSize {
        guard isPDF, let last = sortedPages.last else { return Page.standardSize }
        let standard = Page.standardSize
        return CGSize(width: last.width, height: last.width * standard.height / standard.width)
    }

    @discardableResult
    func insertPage(at index: Int, paperStyle: PaperStyle? = nil, size: CGSize? = nil, pdfPageIndex: Int? = nil) -> Page {
        for page in pages where page.index >= index {
            page.index += 1
        }
        let page = Page(
            index: index,
            size: size ?? newPageSize,
            paperStyle: paperStyle ?? self.paperStyle,
            pdfPageIndex: pdfPageIndex
        )
        modelContext?.insert(page)
        pages.append(page)
        updatedAt = .now
        return page
    }

    func removePage(_ page: Page) {
        let removedIndex = page.index
        pages.removeAll { $0 == page }
        modelContext?.delete(page)
        for other in pages where other.index > removedIndex {
            other.index -= 1
        }
        updatedAt = .now
    }

    func movePage(from source: Int, to destination: Int) {
        var ordered = sortedPages
        guard ordered.indices.contains(source), ordered.indices.contains(destination) else { return }
        let page = ordered.remove(at: source)
        ordered.insert(page, at: destination)
        for (index, page) in ordered.enumerated() {
            page.index = index
        }
        updatedAt = .now
    }
}

extension Page {
    var spec: PageSpec {
        PageSpec(size: size, paperStyle: paperStyle, pdfPageIndex: pdfPageIndex, drawingData: drawingData)
    }
}
