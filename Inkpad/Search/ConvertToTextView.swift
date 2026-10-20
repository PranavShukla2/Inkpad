//
//  ConvertToTextView.swift
//  Inkpad
//

import SwiftUI
import PencilKit

/// Turns handwriting into editable text you can copy or share.
struct ConvertToTextView: View {
    enum Scope: String, CaseIterable, Identifiable {
        case page
        case notebook

        var id: String { rawValue }
    }

    let notebookTitle: String
    let currentPage: PageSpec
    let currentPageNumber: Int
    let allPages: [PageSpec]

    @Environment(\.dismiss) private var dismiss
    @State private var scope = Scope.page
    @State private var text = ""
    @State private var isConverting = true
    @State private var didCopy = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Convert", selection: $scope) {
                    Text("Page \(currentPageNumber)").tag(Scope.page)
                    if allPages.count > 1 {
                        Text("Whole Notebook").tag(Scope.notebook)
                    }
                }
                .pickerStyle(.segmented)

                ZStack {
                    TextEditor(text: $text)
                        .font(.system(.body, design: .serif))
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .background(Theme.deskRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Theme.hairline, lineWidth: 0.5)
                        }
                        .opacity(isConverting ? 0.3 : 1)

                    if isConverting {
                        ProgressView("Reading your handwriting…")
                    } else if text.isEmpty {
                        ContentUnavailableView(
                            "No Handwriting Found",
                            systemImage: "scribble.variable",
                            description: Text("Write on the page, then try again.")
                        )
                    }
                }

                Text("Recognition happens on your iPad. Edit anything it got wrong before copying.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
            }
            .padding(24)
            .background(Theme.desk)
            .navigationTitle("Convert to Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    ShareLink(item: text, subject: Text(notebookTitle)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .disabled(text.isEmpty)
                    Button {
                        UIPasteboard.general.string = text
                        didCopy = true
                    } label: {
                        Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                    }
                    .disabled(text.isEmpty)
                }
            }
            .task(id: scope) {
                await convert()
            }
            .sensoryFeedback(.success, trigger: didCopy) { _, copied in copied }
        }
        .tint(Theme.stamp)
    }

    private func convert() async {
        isConverting = true
        didCopy = false
        let pages = scope == .page ? [currentPage] : allPages
        let converted = await Task.detached(priority: .userInitiated) {
            pages
                .map { HandwritingRecognizer.recognizeText(in: $0.drawingData, pageSize: $0.size) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n\n")
        }.value
        guard !Task.isCancelled else { return }
        text = converted
        isConverting = false
    }
}
