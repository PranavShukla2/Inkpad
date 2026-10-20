//
//  NewNotebookSheet.swift
//  Inkpad
//

import SwiftUI

struct NewNotebookSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var cover = CoverStyle.allCases.randomElement() ?? .ink
    @State private var paperStyle = PaperStyle.lined
    @State private var paperColor = PaperColor.white
    @State private var pageSize = PageSizeOption.fitScreen
    @FocusState private var isTitleFocused: Bool

    let onCreate: (String, CoverStyle, PaperStyle, PaperColor, CGSize) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack(alignment: .top, spacing: 28) {
                        NotebookCoverView(title: displayTitle, cover: cover)
                            .frame(width: 150)
                            .animation(.snappy, value: cover)

                        VStack(alignment: .leading, spacing: 18) {
                            TextField("Notebook title", text: $title)
                                .font(.serif(.title2))
                                .focused($isTitleFocused)
                                .submitLabel(.done)
                                .padding(.vertical, 8)
                                .overlay(alignment: .bottom) {
                                    Rectangle().fill(Theme.hairline).frame(height: 1)
                                }

                            Text("Cover")
                                .font(.serif(.headline))
                            LazyVGrid(columns: Array(repeating: GridItem(.fixed(36), spacing: 12), count: 4), alignment: .leading, spacing: 12) {
                                ForEach(CoverStyle.allCases) { style in
                                    Button {
                                        cover = style
                                    } label: {
                                        Circle()
                                            .fill(Color(style.color))
                                            .frame(width: 30, height: 30)
                                            .padding(3)
                                            .overlay {
                                                if cover == style {
                                                    Circle().strokeBorder(Theme.ink, lineWidth: 2)
                                                }
                                            }
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(style.name)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Paper")
                                .font(.serif(.headline))
                            Spacer()
                            Picker("Paper Colour", selection: $paperColor) {
                                ForEach(PaperColor.allCases) { color in
                                    Text(color.name).tag(color)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 260)
                        }

                        Picker("Page Size", selection: $pageSize) {
                            ForEach(PageSizeOption.allCases) { option in
                                Text(option.name).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96, maximum: 120), spacing: 18)], spacing: 18) {
                            ForEach(PaperStyle.allCases) { style in
                                Button {
                                    paperStyle = style
                                } label: {
                                    VStack(spacing: 8) {
                                        PaperSwatch(style: style, color: paperColor, pageSize: pageSize.size(forScreen: screenSize))
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                    .strokeBorder(paperStyle == style ? Theme.stamp : .clear, lineWidth: 2.5)
                                                    .padding(-4)
                                            }
                                        Text(style.name)
                                            .font(.footnote)
                                            .foregroundStyle(paperStyle == style ? Theme.stamp : Theme.inkSecondary)
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(paperStyle == style ? .isSelected : [])
                            }
                        }
                    }
                }
                .padding(28)
            }
            .background(Theme.desk)
            .navigationTitle("New Notebook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(displayTitle, cover, paperStyle, paperColor, pageSize.size(forScreen: screenSize))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: paperStyle)
        .sensoryFeedback(.selection, trigger: cover)
    }

    private var screenSize: CGSize {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen.bounds.size }
            .first ?? PageLayout.standardPageSize
    }

    private var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? Notebook.defaultTitle : trimmed
    }
}
