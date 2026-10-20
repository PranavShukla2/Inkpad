//
//  InsertControls.swift
//  Inkpad
//

import SwiftUI
import PhotosUI

/// Freeform-style bar at the bottom of a canvas: sticky notes, shapes, text,
/// photos and graphs, plus the zoom level with a tap to fit everything.
struct CanvasInsertBar: View {
    let model: NotebookEditorModel
    let tools: ToolState
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 2) {
                insertButton("note.text", label: "Sticky Note") {
                    model.insertSticky()
                }
                Menu {
                    ShapeMenuItems(model: model)
                } label: {
                    InsertIcon(symbol: "square.on.circle")
                }
                .accessibilityLabel("Shape")
                insertButton("textformat", label: "Text") {
                    tools.select(.text)
                }
                PhotosPicker(selection: $photoItem, matching: .images) {
                    InsertIcon(symbol: "photo.on.rectangle.angled")
                }
                .accessibilityLabel("Photo")
                insertButton("function", label: "Graph") {
                    model.insertGraph()
                }
                insertButton("x.squareroot", label: "Equation") {
                    model.insertEquation()
                }
                insertButton("tablecells", label: "Table") {
                    model.insertTable()
                }
                insertButton("arrow.left.arrow.right", label: "Unit Converter") {
                    model.isShowingConverter = true
                }
            }
            .padding(.horizontal, 6)
            .frame(height: 50)
            .background(InsertBackground())

            Button {
                model.zoomToFit()
            } label: {
                Text("\(model.zoomPercent)%")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(minWidth: 64)
                    .frame(height: 50)
                    .background(InsertBackground())
                    .contentTransition(.numericText())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Zoom \(model.zoomPercent) percent. Zoom to fit.")
        }
        .onChange(of: photoItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    model.insertPhoto(data)
                }
                photoItem = nil
            }
        }
    }

    private func insertButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            InsertIcon(symbol: symbol)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// The Insert menu for notebooks, in the top bar.
struct NotebookInsertMenu: View {
    let model: NotebookEditorModel
    @State private var photoItem: PhotosPickerItem?
    @State private var isPickingPhoto = false

    var body: some View {
        Menu {
            Button("Sticky Note", systemImage: "note.text") {
                model.insertSticky()
            }
            Menu("Shape", systemImage: "square.on.circle") {
                ShapeMenuItems(model: model)
            }
            Button("Photo", systemImage: "photo.on.rectangle.angled") {
                isPickingPhoto = true
            }
            Button("Graph", systemImage: "function") {
                model.insertGraph()
            }
            Button("Equation (LaTeX)", systemImage: "x.squareroot") {
                model.insertEquation()
            }
            Button("Table", systemImage: "tablecells") {
                model.insertTable()
            }
            Divider()
            Button("Unit Converter", systemImage: "arrow.left.arrow.right") {
                model.isShowingConverter = true
            }
        } label: {
            Image(systemName: "plus.square.on.square")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Theme.ink)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Insert")
        .photosPicker(isPresented: $isPickingPhoto, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    model.insertPhoto(data)
                }
                photoItem = nil
            }
        }
    }
}

private struct ShapeMenuItems: View {
    let model: NotebookEditorModel

    var body: some View {
        ForEach(BoardItem.Shape.allCases) { shape in
            Button(shape.name, systemImage: shape.symbol) {
                model.insertShape(shape)
            }
        }
    }
}

private struct InsertIcon: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 19, weight: .medium))
            .foregroundStyle(Theme.ink)
            .frame(width: 46, height: 46)
            .contentShape(Rectangle())
    }
}

private struct InsertBackground: View {
    var body: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .overlay(Capsule().fill(Theme.deskRaised.opacity(0.8)))
            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 0.5))
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }
}

/// Edits a sticky note's text or a graph's functions, with a live preview.
struct ItemEditorSheet: View {
    @State var item: BoardItem
    let onSave: (BoardItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var functions: [String] = []
    @State private var cells: [[String]] = []
    /// What the item looked like when the sheet opened, to keep its scale.
    @State private var original: BoardItem?

    var body: some View {
        NavigationStack {
            Form {
                if item.kind == .graph {
                    graphEditor
                } else if item.kind == .equation {
                    EquationEditor(latex: $item.text)
                } else if item.kind == .table {
                    TableEditor(cells: $cells)
                } else {
                    Section("Note") {
                        TextEditor(text: $item.text)
                            .frame(minHeight: 160)
                    }
                    Section("Colour") {
                        HStack(spacing: 12) {
                            ForEach(BoardItem.stickyColors, id: \.self) { hex in
                                Button {
                                    item.colorHex = hex
                                } label: {
                                    Circle()
                                        .fill(Color(UIColor(hexString: hex) ?? .yellow))
                                        .frame(width: 30, height: 30)
                                        .overlay {
                                            if item.colorHex == hex {
                                                Circle().strokeBorder(Theme.ink, lineWidth: 2)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if item.kind == .graph {
                            item.text = functions.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: "\n")
                        }
                        if item.kind == .equation {
                            resizeEquation()
                        }
                        if item.kind == .table {
                            resizeTable()
                            item.cells = cells
                        }
                        onSave(item)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                original = item
                let existing = item.text.split(separator: "\n").map(String.init)
                functions = existing + Array(repeating: "", count: max(0, 3 - existing.count))
                cells = item.cells ?? [["", ""], ["", ""]]
            }
        }
        .tint(Theme.stamp)
    }

    private var title: String {
        switch item.kind {
        case .graph: "Graph"
        case .equation: "Equation"
        case .table: "Table"
        default: "Sticky Note"
        }
    }

    /// Fits the box to the new equation, at the size the user had scaled it to.
    private func resizeEquation() {
        guard let natural = BoardItemRenderer.equationSize(item.text) else { return }
        let scale = original.flatMap { BoardItemRenderer.equationSize($0.text) }.map { item.height / $0.height } ?? 1
        item.width = natural.width * scale
        item.height = natural.height * scale
    }

    /// Keeps each row and column the same size when rows or columns are added.
    private func resizeTable() {
        let oldRows = CGFloat(max(original?.cells?.count ?? cells.count, 1))
        let oldColumns = CGFloat(max(original?.cells?.first?.count ?? cells.first?.count ?? 1, 1))
        item.height = item.height / oldRows * CGFloat(cells.count)
        item.width = item.width / oldColumns * CGFloat(cells.first?.count ?? 1)
    }

    @ViewBuilder
    private var graphEditor: some View {
        Section {
            GraphPreview(item: previewItem)
                .frame(height: 260)
                .listRowInsets(EdgeInsets())
        }
        Section {
            ForEach(functions.indices, id: \.self) { index in
                HStack {
                    Circle()
                        .fill(Color(BoardItemRenderer.graphColors[index]))
                        .frame(width: 10, height: 10)
                    TextField(index == 0 ? "y = sin(x)" : "Another function (optional)", text: $functions[index])
                        .font(.system(.body, design: .monospaced))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !functions[index].isEmpty {
                        Image(systemName: MathExpression(functions[index]) == nil ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(MathExpression(functions[index]) == nil ? Theme.stamp : .green)
                            .accessibilityLabel(MathExpression(functions[index]) == nil ? "Can't read this function" : "Valid")
                    }
                }
            }
        } header: {
            Text("Functions")
        } footer: {
            Text("Use x as the variable. Try 2x^2 - 3, sqrt(x), 3cos(2x) + 1, e^x or ln(x). Up to three curves.")
        }
        Section("X Range") {
            Stepper("From \(Int(item.domainMin))", value: $item.domainMin, in: -1000...(item.domainMax - 1))
            Stepper("To \(Int(item.domainMax))", value: $item.domainMax, in: (item.domainMin + 1)...1000)
        }
    }

    private var previewItem: BoardItem {
        var preview = item
        preview.text = functions.joined(separator: "\n")
        return preview
    }
}

private struct GraphPreview: View {
    let item: BoardItem

    var body: some View {
        Canvas { context, size in
            context.withCGContext { cgContext in
                BoardItemRenderer.draw(item, image: nil, in: CGRect(origin: .zero, size: size).insetBy(dx: 12, dy: 12), context: cgContext, drawsShadow: false)
            }
        }
        .background(Theme.desk)
    }
}
