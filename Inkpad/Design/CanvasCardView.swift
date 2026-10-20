//
//  CanvasCardView.swift
//  Inkpad
//

import SwiftUI

/// A landscape card showing a snapshot of a canvas board.
struct CanvasCardView: View {
    let title: String
    let previewData: Data?
    var accent: Color = Theme.stamp
    var isFavorite = false

    static let aspectRatio: CGFloat = 640 / 440

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let previewData, let image = UIImage(data: previewData) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    DotBoard()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            if isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.stamp)
                    .padding(6)
                    .background(Circle().fill(.white.opacity(0.92)))
                    .padding(8)
            }
        }
        .aspectRatio(Self.aspectRatio, contentMode: .fit)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
        .accessibilityElement()
        .accessibilityLabel("Canvas \(title)")
    }
}

/// An empty dotted board, for canvases with nothing on them yet.
struct DotBoard: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 16
            var y = spacing / 2
            while y < size.height {
                var x = spacing / 2
                while x < size.width {
                    context.fill(Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)), with: .color(Color(UIColor(hex: 0xCFC8BA))))
                    x += spacing
                }
                y += spacing
            }
        }
        .background(Color(UIColor(hex: 0xFCFBF8)))
    }
}

/// The big Canvases entry at the top of the Library: a portfolio holding the
/// latest boards, so canvases stay apart from notebooks.
struct CanvasesBanner: View {
    let canvases: [Notebook]
    let onOpen: () -> Void
    let onCreate: () -> Void

    var body: some View {
        Button(action: canvases.isEmpty ? onCreate : onOpen) {
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Canvases", systemImage: "square.dashed")
                        .font(.serif(.title2, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text(canvases.isEmpty
                         ? "Endless boards for sketching, planning and sticky notes."
                         : canvases.count == 1 ? "1 canvas" : "\(canvases.count) canvases")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSecondary)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Label(canvases.isEmpty ? "New Canvas" : "Open", systemImage: canvases.isEmpty ? "plus" : "arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.stamp)
                }
                .frame(maxWidth: 260, alignment: .leading)

                Spacer(minLength: 0)

                // The latest boards, fanned out like prints on a desk.
                ZStack {
                    ForEach(Array(canvases.prefix(3).enumerated().reversed()), id: \.element.persistentModelID) { index, canvas in
                        CanvasCardView(title: canvas.displayTitle, previewData: canvas.coverImageData)
                            .frame(width: 200)
                            .rotationEffect(.degrees(Double(index) * -5))
                            .offset(x: CGFloat(index) * -46, y: CGFloat(index) * 6)
                    }
                    if canvases.isEmpty {
                        CanvasCardView(title: "", previewData: nil)
                            .frame(width: 200)
                            .opacity(0.7)
                    }
                }
                .padding(.trailing, 8)
            }
            .padding(24)
            .frame(height: 190)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.deskRaised)
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
            }
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(canvases.isEmpty ? "Create a canvas" : "Canvases, \(canvases.count)")
    }
}
