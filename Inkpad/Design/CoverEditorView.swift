//
//  CoverEditorView.swift
//  Inkpad
//

import SwiftUI
import PhotosUI

/// Customise a cover: colour, design, label, emblem, ribbon or your own photo.
struct CoverEditorView: View {
    @Binding var draft: CoverDraft
    let title: String
    var isCanvas = false
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                NotebookCoverView(title: title, draft: draft, isCanvas: isCanvas)
                    .frame(width: 190)
                    .frame(maxWidth: .infinity)
                    .animation(.snappy, value: draft)

                section("Colour") {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(40), spacing: 12), count: 9), alignment: .leading, spacing: 12) {
                        ForEach(CoverStyle.allCases) { style in
                            swatch(Color(style.color), isSelected: draft.customColorHex == nil && draft.preset == style) {
                                draft.preset = style
                                draft.customColorHex = nil
                            }
                            .accessibilityLabel(style.name)
                        }
                        ColorPicker(
                            "Custom Colour",
                            selection: Binding(
                                get: { Color(draft.color) },
                                set: { draft.customColorHex = UIColor($0).hexString }
                            ),
                            supportsOpacity: false
                        )
                        .labelsHidden()
                    }
                }

                if !isCanvas {
                    section("Design") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 74, maximum: 90), spacing: 16)], spacing: 16) {
                            ForEach(CoverDesign.allCases) { design in
                                Button {
                                    draft.design = design
                                    draft.photoData = nil
                                } label: {
                                    VStack(spacing: 6) {
                                        NotebookCoverView(
                                            title: "",
                                            draft: CoverDraft(preset: draft.preset, customColorHex: draft.customColorHex, design: design, labelStyle: .none, hasRibbon: false)
                                        )
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 6)
                                                .strokeBorder(isSelected(design) ? Theme.stamp : .clear, lineWidth: 2.5)
                                                .padding(-4)
                                        }
                                        Text(design.name)
                                            .font(.caption)
                                            .foregroundStyle(isSelected(design) ? Theme.stamp : Theme.inkSecondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    section("Label") {
                        Picker("Label", selection: $draft.labelStyle) {
                            ForEach(CoverLabelStyle.allCases) { style in
                                Text(style.name).tag(style)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    section("Details") {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Emblem")
                                Spacer()
                                TextField("Emoji", text: Binding(
                                    get: { draft.emblem },
                                    set: { draft.emblem = String($0.suffix(1)) }
                                ))
                                .multilineTextAlignment(.center)
                                .font(.title2)
                                .frame(width: 60, height: 40)
                                .background(Theme.desk, in: RoundedRectangle(cornerRadius: 10))
                                if !draft.emblem.isEmpty {
                                    Button("Remove", role: .destructive) {
                                        draft.emblem = ""
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                            Toggle("Ribbon Bookmark", isOn: $draft.hasRibbon)
                            HStack {
                                PhotosPicker(selection: $photoItem, matching: .images) {
                                    Label(draft.photoData == nil ? "Use a Photo" : "Choose Another Photo", systemImage: "photo")
                                }
                                Spacer()
                                if draft.photoData != nil {
                                    Button("Remove Photo", role: .destructive) {
                                        draft.photoData = nil
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    }
                }
            }
            .padding(28)
        }
        .background(Theme.desk)
        .navigationTitle("Cover")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: draft)
        .onChange(of: photoItem) { _, item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self) else { return }
                draft.photoData = Self.coverPhotoData(from: data)
            }
        }
    }

    private func isSelected(_ design: CoverDesign) -> Bool {
        draft.photoData == nil && draft.design == design
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.serif(.headline))
                .foregroundStyle(Theme.ink)
            content()
        }
    }

    private func swatch(_ color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 32, height: 32)
                .padding(3)
                .overlay {
                    if isSelected {
                        Circle().strokeBorder(Theme.ink, lineWidth: 2)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    /// Photos are shrunk so covers stay light to store and quick to draw.
    private static func coverPhotoData(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let maxSide: CGFloat = 900
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }.jpegData(compressionQuality: 0.85)
    }
}
