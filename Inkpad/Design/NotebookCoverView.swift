//
//  NotebookCoverView.swift
//  Inkpad
//

import SwiftUI

/// A cloth-bound notebook: darker spine with stitching, an elastic band and a
/// paper label. PDF notebooks show their first page with a stamp tab instead.
struct NotebookCoverView: View {
    let title: String
    let cover: CoverStyle
    var coverImageData: Data? = nil
    var isPDF = false
    var isFavorite = false

    static let aspectRatio: CGFloat = 0.76

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .topLeading) {
                if isPDF {
                    documentCover(width: width)
                } else {
                    clothCover(width: width, height: proxy.size.height)
                }
                if isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: width * 0.08))
                        .foregroundStyle(Theme.stamp)
                        .padding(width * 0.05)
                        .background(Circle().fill(.white.opacity(0.9)).padding(width * 0.025))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(width * 0.03)
                }
            }
            .clipShape(shape(width: width))
            .shadow(color: .black.opacity(0.10), radius: 1, x: 0, y: 1)
            .shadow(color: .black.opacity(0.16), radius: 10, x: 3, y: 8)
        }
        .aspectRatio(NotebookCoverView.aspectRatio, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(title)
    }

    private func shape(width: CGFloat) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: width * 0.02,
            bottomLeadingRadius: width * 0.02,
            bottomTrailingRadius: width * 0.07,
            topTrailingRadius: width * 0.07,
            style: .continuous
        )
    }

    private func clothCover(width: CGFloat, height: CGFloat) -> some View {
        let base = Color(cover.color)
        let spineWidth = width * 0.1
        return ZStack(alignment: .topLeading) {
            base
            LinearGradient(
                colors: [.white.opacity(0.14), .clear, .black.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // Spine
            Rectangle()
                .fill(.black.opacity(0.2))
                .frame(width: spineWidth)
            Path { path in
                path.move(to: CGPoint(x: spineWidth + 4, y: 6))
                path.addLine(to: CGPoint(x: spineWidth + 4, y: height - 6))
            }
            .stroke(.white.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            // Elastic band
            Rectangle()
                .fill(.black.opacity(0.24))
                .frame(width: max(3, width * 0.035))
                .offset(x: width * 0.84)
            // Label
            Text(title)
                .font(.system(size: max(9, width * 0.085), weight: .semibold, design: .serif))
                .foregroundStyle(Theme.ink)
                .environment(\.colorScheme, .light)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, width * 0.05)
                .padding(.vertical, width * 0.04)
                .frame(width: width * 0.58, height: width * 0.36)
                .background(
                    RoundedRectangle(cornerRadius: width * 0.03, style: .continuous)
                        .fill(Color(UIColor(hex: 0xF8F3E7)))
                        .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
                )
                .offset(x: spineWidth + (width * 0.74 - spineWidth - width * 0.58) / 2 + width * 0.04, y: height * 0.22)
        }
    }

    private func documentCover(width: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            Color.white
            if let coverImageData, let image = UIImage(data: coverImageData) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .clipped()
            }
            Text("PDF")
                .font(.system(size: max(8, width * 0.07), weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, width * 0.05)
                .padding(.vertical, width * 0.02)
                .background(Theme.stamp, in: Capsule())
                .padding(width * 0.06)
        }
    }
}

/// A small page showing a paper pattern.
struct PaperSwatch: View {
    let style: PaperStyle
    let color: PaperColor

    var body: some View {
        Canvas { context, size in
            context.withCGContext { cgContext in
                let page = PageLayout.standardPageSize
                let scale = size.width / page.width
                cgContext.scaleBy(x: scale, y: scale)
                PaperRenderer.draw(style, color: color, in: cgContext, size: page)
            }
        }
        .aspectRatio(PageLayout.standardPageSize.width / PageLayout.standardPageSize.height, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
    }
}
