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
        paperColor: PaperColor = .white,
        pageSize: CGSize = Page.standardSize
    ) -> Notebook {
        let notebook = Notebook(title: title, cover: cover, paperStyle: paperStyle, paperColor: paperColor)
        notebook.pageWidth = pageSize.width
        notebook.pageHeight = pageSize.height
        context.insert(notebook)
        notebook.insertPage(at: 0)
        return notebook
    }

    /// A canvas is one huge board that you start in the middle of, so it feels
    /// endless in every direction. It still grows if you reach an edge.
    static let canvasStartSize = CGSize(width: 16000, height: 16000)
    static let canvasGrowth: CGFloat = 1024

    static func createCanvas(
        in context: ModelContext,
        title: String,
        cover: CoverStyle,
        paperStyle: PaperStyle,
        paperColor: PaperColor
    ) -> Notebook {
        let notebook = Notebook(title: title, cover: cover, paperStyle: paperStyle, paperColor: paperColor)
        notebook.kind = .canvas
        notebook.pageWidth = canvasStartSize.width
        notebook.pageHeight = canvasStartSize.height
        context.insert(notebook)
        notebook.insertPage(at: 0)
        return notebook
    }

    /// New pages use the notebook's page size, or match the width of a PDF's pages.
    var newPageSize: CGSize {
        if isPDF, let last = sortedPages.last {
            let standard = Page.standardSize
            return CGSize(width: last.width, height: last.width * standard.height / standard.width)
        }
        return pageWidth > 0 && pageHeight > 0 ? CGSize(width: pageWidth, height: pageHeight) : Page.standardSize
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
        PageSpec(size: size, paperStyle: paperStyle, pdfPageIndex: pdfPageIndex, drawingData: drawingData, textBoxes: textBoxes)
    }
}
