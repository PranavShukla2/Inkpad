//
//  FolderTileView.swift
//  Inkpad
//

import SwiftUI

/// A kraft folder with the covers of its first notebooks peeking out.
struct FolderTileView: View {
    let name: String
    let color: UIColor
    let notebooks: [Notebook]
    var isDropTargeted = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let tab = CGSize(width: size.width * 0.38, height: size.height * 0.08)
            ZStack(alignment: .bottom) {
                // Back panel with tab
                FolderBackShape(tabSize: tab)
                    .fill(Color(color).opacity(0.82))
                    .overlay(FolderBackShape(tabSize: tab).fill(.black.opacity(0.08)))

                // Notebooks tucked inside
                HStack(spacing: -size.width * 0.12) {
                    ForEach(Array(notebooks.prefix(3).enumerated()), id: \.element.persistentModelID) { index, notebook in
                        NotebookCoverView(
                            title: notebook.displayTitle,
                            draft: notebook.coverDraft,
                            coverImageData: notebook.coverImageData,
                            isPDF: notebook.isPDF,
                            isCanvas: notebook.isCanvas
                        )
                        .frame(width: size.width * 0.38)
                        .rotationEffect(.degrees(Double(index - 1) * 6))
                        .offset(y: index == 1 ? -size.height * 0.04 : 0)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, tab.height + size.height * 0.08)

                // Front panel
                RoundedRectangle(cornerRadius: size.width * 0.05, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(color), Color(color).opacity(0.88)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(.white.opacity(0.25))
                            .frame(height: 1)
                            .padding(.horizontal, size.width * 0.04)
                    }
                    .overlay(alignment: .bottomLeading) {
                        Text("\(notebooks.count)")
                            .font(.system(size: size.width * 0.1, weight: .bold, design: .serif))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(size.width * 0.07)
                    }
                    .frame(height: size.height * 0.56)
                    .shadow(color: .black.opacity(0.15), radius: 3, y: -1)
            }
            .shadow(color: .black.opacity(0.16), radius: 10, x: 2, y: 8)
            .scaleEffect(isDropTargeted ? 1.06 : 1)
            .animation(.snappy, value: isDropTargeted)
        }
        .aspectRatio(NotebookCoverView.aspectRatio, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("Folder \(name), \(notebooks.count) notebooks")
    }
}

private struct FolderBackShape: Shape {
    let tabSize: CGSize

    func path(in rect: CGRect) -> Path {
        let radius = rect.width * 0.05
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + tabSize.width, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.minX + tabSize.width + tabSize.height, y: rect.minY + tabSize.height), control: CGPoint(x: rect.minX + tabSize.width + tabSize.height * 0.3, y: rect.minY + tabSize.height * 0.1))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY + tabSize.height))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + tabSize.height + radius), control: CGPoint(x: rect.maxX, y: rect.minY + tabSize.height))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
