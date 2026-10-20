//
//  Notebook+Cover.swift
//  Inkpad
//

import UIKit

extension Notebook {
    /// PDF notebooks show their first page on the shelf instead of a fabric cover.
    func updateCoverImage() {
        guard let pdfData,
              let provider = CGDataProvider(data: pdfData as CFData),
              let pdf = CGPDFDocument(provider),
              let firstPage = sortedPages.first else {
            coverImageData = nil
            return
        }
        let image = PageRenderer.image(of: firstPage.spec, paperColor: paperColor, pdf: pdf, width: 360)
        coverImageData = image.jpegData(compressionQuality: 0.8)
    }
}
