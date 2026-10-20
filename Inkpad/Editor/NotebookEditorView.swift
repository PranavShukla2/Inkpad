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
    @State private var isShowingRecordings = false
    @State private var isConvertingToText = false
    @State private var isShown = false
    @State private var toolAnnouncement: String?
    @State private var announcementTask: Task<Void, Never>?
    @State private var recorder = AudioRecorder()
    @State private var renameText = ""

    private let topBarHeight: CGFloat = 56

    init(notebook: Notebook, scrollAxis: ScrollAxis) {
        _model = State(initialValue: NotebookEditorModel(notebook: notebook, scrollAxis: scrollAxis))
    }

    var body: some View {
        editor
            .scaleEffect(isShown ? 1 : 0.94)
            .opacity(isShown ? 1 : 0)
            .onAppear {
                withAnimation(.snappy(duration: 0.32)) {
                    isShown = true
                }
            }
    }

    private var editor: some View {
        GeometryReader { proxy in
            ZStack {
                Theme.desk.ignoresSafeArea()

                NotebookCanvas(model: model, tools: tools, topInset: proxy.safeAreaInsets.top + topBarHeight) { message in
                    announceTool(message)
                }
                    .ignoresSafeArea()

                // The rail floats over the page and can fold away.
                HStack {
                    if tools.railOnRight { Spacer() }
                    InkRail(tools: tools)
                        .padding(.horizontal, 10)
                    if !tools.railOnRight { Spacer() }
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, topBarHeight + 12)
                .padding(.bottom, 56)

                if let toolAnnouncement {
                    Text(toolAnnouncement)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Theme.deskRaised, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.top, topBarHeight + 64)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                VStack(spacing: 0) {
                    topBar
                    Spacer(minLength: 0)
                    if model.notebook.isCanvas {
                        CanvasInsertBar(model: model, tools: tools)
                            .padding(.bottom, 16)
                    } else {
                        pageIndicator
                    }
                }
            }
        }
        .onChange(of: tools.toolDisplayName) { _, name in
            announceTool(name)
        }
        .onChange(of: tools.allowsFingerDrawing) { _, isOn in
            announceTool(isOn ? "Finger draws · scroll with two fingers" : "Finger scrolls · Pencil draws")
        }
        .onChange(of: tools.scrollAxis) { _, axis in
            model.setScrollAxis(axis)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                model.saveNow()
            }
        }
        .onDisappear {
            recorder.stopRecording(into: model.notebook)
            recorder.stopPlayback()
            model.close()
        }
        .animation(.snappy, value: recorder.isRecording)
        #if DEBUG
        .task {
            if UserDefaults.standard.bool(forKey: "showPages") {
                showPages()
            }
            if UserDefaults.standard.bool(forKey: "scrollToEnd") {
                try? await Task.sleep(for: .seconds(1))
                model.scrollToPage(model.pages.count - 1)
            }
            let undoDelay = UserDefaults.standard.double(forKey: "undoAfterSeconds")
            if undoDelay > 0 {
                try? await Task.sleep(for: .seconds(undoDelay))
                model.undo()
            }
            if UserDefaults.standard.bool(forKey: "editFirstGraph") {
                try? await Task.sleep(for: .seconds(1))
                model.editingItem = model.pages.flatMap(\.items).first { $0.kind == .graph }
            }
            if UserDefaults.standard.bool(forKey: "convertText") {
                isConvertingToText = true
            }
            if UserDefaults.standard.bool(forKey: "showRuler") {
                tools.isRulerActive = true
            }
        }
        #endif
        .sheet(item: $model.editingItem) { item in
            ItemEditorSheet(item: item) { edited in
                model.updateItem(edited)
            }
        }
        .sheet(isPresented: $isShowingPages) {
            PageNavigatorView(model: model)
        }
        .sheet(isPresented: $isConvertingToText) {
            if let page = model.currentPage {
                ConvertToTextView(
                    notebookTitle: model.notebook.displayTitle,
                    currentPage: page.spec,
                    currentPageNumber: model.currentPageIndex + 1,
                    allPages: model.pages.map(\.spec)
                )
            }
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

    /// Floating pill groups instead of a full-width bar, so more page shows.
    private var topBar: some View {
        HStack(spacing: 10) {
            BarPill {
                BarButton(symbol: "chevron.left", label: "Library") {
                    close()
                }
                Button {
                    renameText = model.notebook.title
                    isRenaming = true
                } label: {
                    Text(model.notebook.displayTitle)
                        .font(.serif(.headline))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .padding(.trailing, 14)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Rename")
            }

            Spacer(minLength: 12)

            if recorder.isRecording {
                Button {
                    recorder.stopRecording(into: model.notebook)
                } label: {
                    HStack(spacing: 6) {
                        Circle().fill(.white).frame(width: 8, height: 8)
                        Text(Duration.seconds(recorder.elapsed), format: .time(pattern: .minuteSecond))
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(Theme.stamp, in: Capsule())
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop recording")
                .transition(.scale.combined(with: .opacity))
            }

            BarPill {
                BarButton(symbol: "arrow.uturn.backward", label: "Undo", isEnabled: model.canUndo) {
                    model.undo()
                }
                BarButton(symbol: "arrow.uturn.forward", label: "Redo", isEnabled: model.canRedo) {
                    model.redo()
                }
            }

            BarPill {
                BarButton(symbol: recorder.isRecording ? "waveform" : "mic", label: "Recordings") {
                    isShowingRecordings = true
                }
                .popover(isPresented: $isShowingRecordings) {
                    RecordingsPanel(notebook: model.notebook, recorder: recorder)
                }
                ShareLink(
                    item: NotebookExport(title: model.notebook.displayTitle) { [model] in
                        model.saveNow()
                        return model.notebook.snapshot
                    },
                    preview: SharePreview(model.notebook.displayTitle)
                ) {
                    BarIcon(symbol: "square.and.arrow.up")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Export PDF")
                if !model.notebook.isCanvas {
                    NotebookInsertMenu(model: model)
                    BarButton(symbol: "square.grid.2x2", label: "Pages") {
                        showPages()
                    }
                    BarButton(symbol: "doc.badge.plus", label: "Add Page") {
                        model.addPage()
                    }
                }
                moreMenu
            }
        }
        .padding(.horizontal, 12)
        .frame(height: topBarHeight)
        .background(alignment: .top) {
            // Keeps the status bar readable over the page without a solid bar.
            LinearGradient(colors: [Theme.desk, Theme.desk.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: 36)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
        }
    }

    private var moreMenu: some View {
        @Bindable var tools = tools
        return Menu {
            if let page = model.currentPage, page.pdfPageIndex == nil, !model.notebook.isCanvas {
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
            Menu(model.notebook.isCanvas ? "Board Background" : "All Pages") {
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
            Button("Convert to Text", systemImage: "character.cursor.ibeam") {
                // Recognition reads saved ink, so write the latest strokes first.
                model.saveNow()
                isConvertingToText = true
            }
            Divider()
            if !model.notebook.isCanvas {
                Picker("Scrolling", selection: $tools.scrollAxis) {
                    ForEach(ScrollAxis.allCases) { axis in
                        Label(axis.name, systemImage: axis == .vertical ? "arrow.up.and.down" : "arrow.left.and.right")
                            .tag(axis)
                    }
                }
                .pickerStyle(.menu)
            }
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

    /// Plays the closing animation, then dismisses without the system's own.
    private func close() {
        withAnimation(.easeIn(duration: 0.18)) {
            isShown = false
        } completion: {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                dismiss()
            }
        }
    }

    /// Briefly names the tool you switched to, e.g. "Pixel Eraser".
    private func announceTool(_ name: String) {
        announcementTask?.cancel()
        withAnimation(.snappy) {
            toolAnnouncement = name
        }
        announcementTask = Task {
            try? await Task.sleep(for: .seconds(1.1))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                toolAnnouncement = nil
            }
        }
    }

    private func showPages() {
        // Thumbnails read saved ink, so write the latest strokes first.
        model.saveNow()
        isShowingPages = true
    }
}

private struct BarPill<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 0) {
            content
        }
        .padding(.horizontal, 2)
        .frame(height: 44)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().fill(Theme.deskRaised.opacity(0.78)))
                .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 0.5))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 3)
        }
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
