//
//  NotebookCoverView.swift
//  Inkpad
//

import SwiftUI

/// A notebook as a physical object: a cover with a block of pages behind it and
/// a ribbon bookmark, in one of several designs. PDFs show their first page on
/// a little stack of paper; canvases look like a taped-up board.
struct NotebookCoverView: View {
    let title: String
    var draft = CoverDraft()
    var coverImageData: Data? = nil
    var isPDF = false
    var isCanvas = false
    var isFavorite = false

    static let aspectRatio: CGFloat = 0.76

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let coverSize = CGSize(width: size.width * 0.95, height: size.height * 0.94)
            ZStack(alignment: .topLeading) {
                pageBlock(coverSize: coverSize, width: size.width)

                Group {
                    if isPDF {
                        documentCover(width: coverSize.width)
                    } else if isCanvas {
                        boardCover(width: coverSize.width, height: coverSize.height)
                    } else {
                        bookCover(size: coverSize)
                    }
                }
                .frame(width: coverSize.width, height: coverSize.height)
                .clipShape(coverShape(width: coverSize.width))
                .shadow(color: .black.opacity(0.10), radius: 1, x: 0, y: 1)
                .shadow(color: .black.opacity(0.16), radius: 10, x: 3, y: 8)

                if draft.hasRibbon && !isPDF && !isCanvas {
                    ribbon(coverSize: coverSize, height: size.height)
                }

                if isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: size.width * 0.075))
                        .foregroundStyle(Theme.stamp)
                        .padding(size.width * 0.045)
                        .background(Circle().fill(.white.opacity(0.92)).padding(size.width * 0.02))
                        .frame(width: coverSize.width, alignment: .trailing)
                        .padding(.top, size.width * 0.03)
                        .offset(x: -size.width * 0.03)
                }
            }
        }
        .aspectRatio(NotebookCoverView.aspectRatio, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(title)
    }

    private func coverShape(width: CGFloat) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: width * 0.02,
            bottomLeadingRadius: width * 0.02,
            bottomTrailingRadius: isPDF ? width * 0.02 : width * 0.06,
            topTrailingRadius: isPDF ? width * 0.02 : width * 0.06,
            style: .continuous
        )
    }

    // MARK: - Pages and ribbon

    /// The edges of the pages peeking out behind the cover give it thickness.
    private func pageBlock(coverSize: CGSize, width: CGFloat) -> some View {
        let offset = CGSize(width: width * 0.04, height: width * 0.025)
        return ZStack(alignment: .topLeading) {
            ForEach(0..<2) { sheet in
                coverShape(width: coverSize.width)
                    .fill(Color(UIColor(hex: sheet == 0 ? 0xE9E2D4 : 0xF6F1E6)))
                    .overlay {
                        coverShape(width: coverSize.width)
                            .strokeBorder(Color(UIColor(hex: 0xCFC5B2)), lineWidth: 0.5)
                    }
                    .frame(width: coverSize.width, height: coverSize.height)
                    .offset(x: offset.width * CGFloat(2 - sheet) / 2, y: offset.height * CGFloat(2 - sheet) / 2)
            }
        }
        .shadow(color: .black.opacity(0.12), radius: 6, x: 2, y: 5)
    }

    private func ribbon(coverSize: CGSize, height: CGFloat) -> some View {
        let ribbonWidth = coverSize.width * 0.065
        let color = draft.preset == .stamp && draft.customColorHex == nil ? Color(CoverStyle.ink.color) : Theme.stamp
        return Path { path in
            let top = coverSize.height - 4
            let bottom = height - 1
            path.move(to: CGPoint(x: 0, y: top))
            path.addLine(to: CGPoint(x: ribbonWidth, y: top))
            path.addLine(to: CGPoint(x: ribbonWidth, y: bottom))
            path.addLine(to: CGPoint(x: ribbonWidth / 2, y: bottom - ribbonWidth * 0.6))
            path.addLine(to: CGPoint(x: 0, y: bottom))
            path.closeSubpath()
        }
        .fill(color)
        .frame(width: ribbonWidth)
        .offset(x: coverSize.width * 0.7)
        .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
    }

    // MARK: - Book cover

    private func bookCover(size: CGSize) -> some View {
        let width = size.width
        let base = Color(draft.color)
        let spineWidth = width * 0.1
        let hasPhoto = draft.photoData.flatMap(UIImage.init(data:)) != nil
        return ZStack(alignment: .topLeading) {
            if let data = draft.photoData, let photo = UIImage(data: data) {
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else {
                base
                CoverPattern(design: draft.design, color: draft.color)
            }
            LinearGradient(
                colors: [.white.opacity(0.14), .clear, .black.opacity(0.14)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // Spine and stitching
            Rectangle()
                .fill(.black.opacity(0.2))
                .frame(width: spineWidth)
            Path { path in
                path.move(to: CGPoint(x: spineWidth + 4, y: 6))
                path.addLine(to: CGPoint(x: spineWidth + 4, y: size.height - 6))
            }
            .stroke(.white.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            if draft.design == .leather && !hasPhoto {
                leatherDetails(size: size)
            }
            // Elastic band
            Rectangle()
                .fill(.black.opacity(0.26))
                .frame(width: max(3, width * 0.035))
                .offset(x: width * 0.84)

            label(size: size, spineWidth: spineWidth, onPhoto: hasPhoto)
        }
    }

    private func leatherDetails(size: CGSize) -> some View {
        let width = size.width
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: width * 0.04, style: .continuous)
                .strokeBorder(.white.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .padding(EdgeInsets(top: width * 0.05, leading: width * 0.15, bottom: width * 0.05, trailing: width * 0.05))
            // Brass corner guards
            ForEach([0.0, 1.0], id: \.self) { corner in
                Path { path in
                    let guardSize = width * 0.16
                    let y = corner == 0 ? 0 : size.height
                    let dy = corner == 0 ? guardSize : -guardSize
                    path.move(to: CGPoint(x: width, y: y))
                    path.addLine(to: CGPoint(x: width - guardSize, y: y))
                    path.addLine(to: CGPoint(x: width, y: y + dy))
                    path.closeSubpath()
                }
                .fill(Color(UIColor(hex: 0xC9A35B)))
            }
        }
    }

    @ViewBuilder
    private func label(size: CGSize, spineWidth: CGFloat, onPhoto: Bool) -> some View {
        let width = size.width
        let titleFont = Font.system(size: max(9, width * 0.085), weight: .semibold, design: .serif)
        let emblem = draft.emblem.isEmpty ? nil : Text(draft.emblem).font(.system(size: width * 0.17))
        let faceWidth = width * 0.84 - spineWidth
        switch draft.labelStyle {
        case .plate:
            VStack(spacing: width * 0.05) {
                Text(title)
                    .font(titleFont)
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
                emblem
            }
            .frame(width: faceWidth)
            .offset(x: spineWidth, y: size.height * 0.2)
        case .band:
            VStack(spacing: width * 0.06) {
                emblem
                Text(title)
                    .font(titleFont)
                    .foregroundStyle(Theme.ink)
                    .environment(\.colorScheme, .light)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, width * 0.06)
                    .frame(width: width - spineWidth, height: width * 0.24)
                    .background(Color(UIColor(hex: 0xF8F3E7)).opacity(0.95))
            }
            .frame(width: width - spineWidth)
            .offset(x: spineWidth, y: size.height * 0.5 - (emblem == nil ? 0 : width * 0.2))
        case .corner:
            VStack(alignment: .leading, spacing: width * 0.03) {
                emblem
                Text(title)
                    .font(.system(size: max(10, width * 0.1), weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                    .shadow(color: .black.opacity(onPhoto ? 0.5 : 0.2), radius: 2, y: 1)
            }
            .frame(width: faceWidth - width * 0.08, alignment: .leading)
            .frame(height: size.height - width * 0.12, alignment: .bottomLeading)
            .offset(x: spineWidth + width * 0.08, y: width * 0.06)
        case .none:
            emblem
                .frame(width: faceWidth, height: size.height)
                .offset(x: spineWidth)
        }
    }

    /// A dotted whiteboard pinned up with two strips of tape in the cover colour.
    private func boardCover(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            Color(UIColor(hex: 0xFCFBF8))
            Canvas { context, size in
                let spacing = size.width / 11
                var y = spacing / 2
                while y < size.height {
                    var x = spacing / 2
                    while x < size.width {
                        context.fill(Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)), with: .color(Color(UIColor(hex: 0xC9C2B4))))
                        x += spacing
                    }
                    y += spacing
                }
            }
            // A few strokes so it reads as a sketchpad.
            Path { path in
                path.move(to: CGPoint(x: width * 0.18, y: height * 0.42))
                path.addCurve(to: CGPoint(x: width * 0.55, y: height * 0.30), control1: CGPoint(x: width * 0.28, y: height * 0.22), control2: CGPoint(x: width * 0.42, y: height * 0.48))
                path.addCurve(to: CGPoint(x: width * 0.82, y: height * 0.36), control1: CGPoint(x: width * 0.66, y: height * 0.16), control2: CGPoint(x: width * 0.74, y: height * 0.30))
            }
            .stroke(Color(draft.color), style: StrokeStyle(lineWidth: max(2, width * 0.025), lineCap: .round))
            Circle()
                .stroke(Theme.stamp.opacity(0.8), lineWidth: max(1.5, width * 0.015))
                .frame(width: width * 0.22, height: width * 0.22)
                .offset(x: width * 0.6, y: -height * 0.32)
            Text(title)
                .font(.system(size: max(9, width * 0.085), weight: .semibold, design: .serif))
                .foregroundStyle(Theme.ink)
                .environment(\.colorScheme, .light)
                .lineLimit(2)
                .padding(width * 0.08)
            // Tape
            ForEach([-1.0, 1.0], id: \.self) { side in
                Rectangle()
                    .fill(Color(draft.color).opacity(0.75))
                    .frame(width: width * 0.3, height: width * 0.09)
                    .rotationEffect(.degrees(side * 28))
                    .position(x: side < 0 ? width * 0.08 : width * 0.92, y: width * 0.05)
            }
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

/// The printed or woven texture on a cover.
private struct CoverPattern: View {
    let design: CoverDesign
    let color: UIColor

    var body: some View {
        Canvas { context, size in
            let light = Color.white.opacity(0.16)
            let dark = Color.black.opacity(0.12)
            switch design {
            case .cloth, .leather:
                break
            case .linen:
                var path = Path()
                var position: CGFloat = 0
                while position < max(size.width, size.height) {
                    path.move(to: CGPoint(x: position, y: 0))
                    path.addLine(to: CGPoint(x: position, y: size.height))
                    path.move(to: CGPoint(x: 0, y: position))
                    path.addLine(to: CGPoint(x: size.width, y: position))
                    position += 2.5
                }
                context.stroke(path, with: .color(dark.opacity(0.5)), lineWidth: 0.5)
            case .stripes:
                var path = Path()
                let spacing = size.width / 7
                var x = -size.height
                while x < size.width {
                    path.move(to: CGPoint(x: x, y: size.height))
                    path.addLine(to: CGPoint(x: x + size.height, y: 0))
                    x += spacing
                }
                context.stroke(path, with: .color(light), lineWidth: spacing / 3)
            case .grid:
                var path = Path()
                let spacing = size.width / 9
                var position = spacing
                while position < max(size.width, size.height) {
                    path.move(to: CGPoint(x: position, y: 0))
                    path.addLine(to: CGPoint(x: position, y: size.height))
                    path.move(to: CGPoint(x: 0, y: position))
                    path.addLine(to: CGPoint(x: size.width, y: position))
                    position += spacing
                }
                context.stroke(path, with: .color(light), lineWidth: 1)
            case .dots:
                let spacing = size.width / 7
                var row = 0
                var y = spacing / 2
                while y < size.height {
                    var x = row.isMultiple(of: 2) ? spacing / 2 : spacing
                    while x < size.width {
                        context.fill(Path(ellipseIn: CGRect(x: x - spacing / 6, y: y - spacing / 6, width: spacing / 3, height: spacing / 3)), with: .color(light))
                        x += spacing
                    }
                    y += spacing / 2
                    row += 1
                }
            case .waves:
                var path = Path()
                let spacing = size.width / 8
                var y = spacing / 2
                while y < size.height + spacing {
                    path.move(to: CGPoint(x: 0, y: y))
                    var x: CGFloat = 0
                    while x < size.width {
                        path.addQuadCurve(to: CGPoint(x: x + spacing, y: y), control: CGPoint(x: x + spacing / 2, y: y - spacing / 2.5))
                        x += spacing
                    }
                    y += spacing
                }
                context.stroke(path, with: .color(light), lineWidth: 1.5)
            case .terrazzo:
                // Fixed pseudo-random chips so the cover never changes between renders.
                var seed: UInt64 = 0x9E37_79B9
                func next() -> CGFloat {
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    return CGFloat(seed >> 33) / CGFloat(UInt32.max >> 1)
                }
                let palette: [Color] = [light, dark, Color(UIColor(hex: 0xF3E6CF)).opacity(0.5), Color(Palette.stamp).opacity(0.35)]
                for index in 0..<70 {
                    let chip = size.width * (0.015 + next() * 0.035)
                    let rect = CGRect(x: next() * size.width, y: next() * size.height, width: chip, height: chip * (0.6 + next() * 0.6))
                    context.fill(Path(roundedRect: rect, cornerRadius: chip / 3), with: .color(palette[index % palette.count]))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// A small page showing a paper pattern.
struct PaperSwatch: View {
    let style: PaperStyle
    let color: PaperColor
    var pageSize = PageLayout.standardPageSize

    var body: some View {
        Canvas { context, size in
            context.withCGContext { cgContext in
                let scale = size.width / pageSize.width
                cgContext.scaleBy(x: scale, y: scale)
                PaperRenderer.draw(style, color: color, in: cgContext, size: pageSize)
            }
        }
        .aspectRatio(pageSize.width / pageSize.height, contentMode: .fit)
        .animation(.snappy, value: pageSize)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
    }
}
