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

    var body: some View {
        NavigationStack {
            Form {
                if item.kind == .graph {
                    graphEditor
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
            .navigationTitle(item.kind == .graph ? "Graph" : "Sticky Note")
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
                        onSave(item)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                let existing = item.text.split(separator: "\n").map(String.init)
                functions = existing + Array(repeating: "", count: max(0, 3 - existing.count))
            }
        }
        .tint(Theme.stamp)
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
