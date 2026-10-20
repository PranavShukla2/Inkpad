//
//  PageNavigatorView.swift
//  Inkpad
//

import SwiftUI

/// All pages at a glance. Tap to jump, drag to reorder, long-press for options.
struct PageNavigatorView: View {
    let model: NotebookEditorModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130, maximum: 170), spacing: 24)], spacing: 28) {
                    ForEach(Array(model.pages.enumerated()), id: \.element.persistentModelID) { index, page in
                        pageCell(page, at: index)
                    }
                }
                .padding(24)
            }
            .background(Theme.desk)
            .navigationTitle("Pages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Page", systemImage: "plus") {
                        model.insertPage(at: model.pages.count)
                    }
                }
            }
        }
        .tint(Theme.stamp)
    }

    private func pageCell(_ page: Page, at index: Int) -> some View {
        let isCurrent = index == model.currentPageIndex
        return VStack(spacing: 8) {
            PageThumbnail(spec: page.spec, paperColor: model.notebook.paperColor, pdf: model.pdf)
                .overlay {
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(isCurrent ? Theme.stamp : .clear, lineWidth: 2.5)
                        .padding(-5)
                }
            Text("\(index + 1)")
                .font(.serif(.footnote, weight: isCurrent ? .bold : .regular))
                .foregroundStyle(isCurrent ? Theme.stamp : Theme.inkSecondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            model.scrollToPage(index)
            dismiss()
        }
        .contextMenu {
            pageMenu(page, at: index)
        }
        .draggable("\(index)") {
            PageThumbnail(spec: page.spec, paperColor: model.notebook.paperColor, pdf: model.pdf)
                .frame(width: 110)
        }
        .dropDestination(for: String.self) { items, _ in
            guard let source = items.first.flatMap(Int.init) else { return false }
            withAnimation {
                model.movePage(from: source, to: index)
            }
            return true
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Page \(index + 1)")
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    @ViewBuilder
    private func pageMenu(_ page: Page, at index: Int) -> some View {
        Button("Insert Page Before", systemImage: "arrow.up.doc") {
            model.insertPage(at: index)
        }
        Button("Insert Page After", systemImage: "arrow.down.doc") {
            model.insertPage(at: index + 1)
        }
        Button("Duplicate", systemImage: "plus.square.on.square") {
            model.duplicatePage(at: index)
        }
        if page.pdfPageIndex == nil {
            Picker("Paper", selection: Binding(
                get: { page.paperStyle },
                set: { model.setPaperStyle($0, forPageAt: index) }
            )) {
                ForEach(PaperStyle.allCases) { style in
                    Text(style.name).tag(style)
                }
            }
            .pickerStyle(.menu)
        }
        Divider()
        Button("Delete Page", systemImage: "trash", role: .destructive) {
            withAnimation {
                model.deletePage(at: index)
            }
        }
        .disabled(model.pages.count <= 1)
    }
}

/// Renders a page preview off the main thread.
struct PageThumbnail: View {
    let spec: PageSpec
    let paperColor: PaperColor
    let pdf: CGPDFDocument?
    @State private var image: UIImage?

    var body: some View {
        Rectangle()
            .fill(Color(paperColor.background))
            .aspectRatio(spec.size.width / spec.size.height, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .transition(.opacity)
                }
            }
            .shadow(color: .black.opacity(0.14), radius: 4, y: 2)
            .task(id: ThumbnailKey(spec: spec, paperColor: paperColor)) {
                let spec = spec
                let paperColor = paperColor
                let pdf = pdf
                let rendered = await Task.detached(priority: .utility) {
                    PageRenderer.image(of: spec, paperColor: paperColor, pdf: pdf, width: 300)
                }.value
                withAnimation(.easeOut(duration: 0.15)) {
                    image = rendered
                }
            }
    }

    private struct ThumbnailKey: Equatable {
        let drawingData: Data?
        let paperStyle: PaperStyle
        let paperColor: PaperColor

        init(spec: PageSpec, paperColor: PaperColor) {
            drawingData = spec.drawingData
            paperStyle = spec.paperStyle
            self.paperColor = paperColor
        }
    }
}
