//
//  NotebookEditorView.swift
//  Inkpad
//

import SwiftUI

struct NotebookEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ToolState.self) private var tools
    @State private var model: NotebookEditorModel
    @State private var isRenaming = false
    @State private var isShowingPages = false
    @State private var renameText = ""

    private let topBarHeight: CGFloat = 56
    private let railColumnWidth: CGFloat = 72

    init(notebook: Notebook) {
        _model = State(initialValue: NotebookEditorModel(notebook: notebook))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Theme.desk.ignoresSafeArea()

                HStack(spacing: 0) {
                    if !tools.railOnRight {
                        Color.clear.frame(width: railColumnWidth)
                    }
                    NotebookCanvas(model: model, tools: tools, topInset: proxy.safeAreaInsets.top + topBarHeight)
                    if tools.railOnRight {
                        Color.clear.frame(width: railColumnWidth)
                    }
                }
                .ignoresSafeArea()

                HStack {
                    if tools.railOnRight { Spacer() }
                    InkRail(tools: tools)
                        .padding(.horizontal, 10)
                    if !tools.railOnRight { Spacer() }
                }
                .padding(.top, topBarHeight)

                VStack(spacing: 0) {
                    topBar
                    Spacer(minLength: 0)
                    pageIndicator
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                model.saveNow()
            }
        }
        .onDisappear {
            model.close()
        }
        #if DEBUG
        .task {
            if UserDefaults.standard.bool(forKey: "showPages") {
                showPages()
            }
        }
        #endif
        .sheet(isPresented: $isShowingPages) {
            PageNavigatorView(model: model)
        }
        .alert("Rename Notebook", isPresented: $isRenaming) {
            TextField("Title", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                let title = renameText.trimmingCharacters(in: .whitespaces)
                model.notebook.title = title.isEmpty ? Notebook.defaultTitle : title
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 2) {
            BarButton(symbol: "chevron.left", label: "Library") {
                model.close()
                dismiss()
            }

            Button {
                renameText = model.notebook.title
                isRenaming = true
            } label: {
                Text(model.notebook.displayTitle)
                    .font(.serif(.headline))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Rename")

            Spacer(minLength: 12)

            BarButton(symbol: "arrow.uturn.backward", label: "Undo", isEnabled: model.canUndo) {
                model.undo()
            }
            BarButton(symbol: "arrow.uturn.forward", label: "Redo", isEnabled: model.canRedo) {
                model.redo()
            }

            Rectangle()
                .fill(Theme.hairline)
                .frame(width: 1, height: 22)
                .padding(.horizontal, 6)

            BarButton(symbol: "square.grid.2x2", label: "Pages") {
                showPages()
            }
            BarButton(symbol: "doc.badge.plus", label: "Add Page") {
                model.addPage()
            }
            moreMenu
        }
        .padding(.horizontal, 10)
        .frame(height: topBarHeight)
        .background {
            ZStack(alignment: .bottom) {
                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(Theme.deskRaised.opacity(0.75))
                Rectangle().fill(Theme.hairline).frame(height: 0.5)
            }
            .ignoresSafeArea(edges: .top)
        }
    }

    private var moreMenu: some View {
        @Bindable var tools = tools
        return Menu {
            if let page = model.currentPage, page.pdfPageIndex == nil {
                Picker("This Page", selection: Binding(
                    get: { page.paperStyle },
                    set: { model.setPaperStyle($0, forPageAt: model.currentPageIndex) }
                )) {
                    ForEach(PaperStyle.allCases) { style in
                        Text(style.name).tag(style)
                    }
                }
                .pickerStyle(.menu)
            }
            Menu("All Pages") {
                ForEach(PaperStyle.allCases) { style in
                    Button(style.name) {
                        model.setPaperStyleForAllPages(style)
                    }
                }
            }
            if !model.notebook.isPDF {
                Picker("Paper Colour", selection: Binding(
                    get: { model.notebook.paperColor },
                    set: { model.setPaperColor($0) }
                )) {
                    ForEach(PaperColor.allCases) { color in
                        Text(color.name).tag(color)
                    }
                }
                .pickerStyle(.menu)
            }
            Divider()
            Toggle("Left-Handed Layout", isOn: $tools.railOnRight)
            Button("Rename…", systemImage: "pencil") {
                renameText = model.notebook.title
                isRenaming = true
            }
        } label: {
            BarIcon(symbol: "ellipsis.circle")
        }
        .accessibilityLabel("More")
    }

    // MARK: - Page indicator

    private var pageIndicator: some View {
        Button(action: showPages) {
            Text("\(model.currentPageIndex + 1) of \(model.pages.count)")
                .font(.serif(.footnote, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Theme.inkSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.deskRaised.opacity(0.9), in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 0.5))
                .contentTransition(.numericText())
                .animation(.snappy, value: model.currentPageIndex)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 12)
        .accessibilityLabel("Page \(model.currentPageIndex + 1) of \(model.pages.count). Show all pages.")
    }

    private func showPages() {
        // Thumbnails read saved ink, so write the latest strokes first.
        model.saveNow()
        isShowingPages = true
    }
}

private struct BarButton: View {
    let symbol: String
    let label: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            BarIcon(symbol: symbol)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
        .accessibilityLabel(label)
        .help(label)
    }
}

private struct BarIcon: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(Theme.ink)
            .frame(width: 40, height: 40)
            .contentShape(Rectangle())
    }
}
