//
//  InkRail.swift
//  Inkpad
//

import SwiftUI

/// The floating vertical toolbar: tools on top, the current tool's options
/// below, then the ruler and finger-drawing toggles.
struct InkRail: View {
    @Bindable var tools: ToolState
    @Namespace private var selection

    var body: some View {
        Group {
            if tools.isRailCollapsed {
                collapsed
                    .transition(.scale(scale: 0.6, anchor: .top).combined(with: .opacity))
            } else {
                expanded
                    .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
            }
        }
        .sensoryFeedback(.selection, trigger: tools.tool)
        .animation(.snappy(duration: 0.22), value: tools.tool)
        .animation(.snappy(duration: 0.28), value: tools.isRailCollapsed)
    }

    private var expanded: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView(.vertical, showsIndicators: false) {
                content
            }
        }
        .frame(width: 52)
        .background(RailBackground())
    }

    /// Just the current tool, so the page is free to write on.
    private var collapsed: some View {
        Button {
            tools.isRailCollapsed = false
        } label: {
            VStack(spacing: 6) {
                Image(systemName: tools.symbol(for: tools.tool))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.stamp))
                if tools.tool.isInking {
                    Circle()
                        .fill(Color(tools.color))
                        .overlay(Circle().strokeBorder(Theme.inkSecondary.opacity(0.45), lineWidth: 1))
                        .frame(width: 14, height: 14)
                }
                Image(systemName: tools.railOnRight ? "chevron.compact.left" : "chevron.compact.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkSecondary)
            }
            .padding(.vertical, 6)
            .frame(width: 52)
            .background(RailBackground())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show tools")
    }

    private var content: some View {
        VStack(spacing: 4) {
            Button {
                tools.isRailCollapsed = true
            } label: {
                Image(systemName: "chevron.compact.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.inkSecondary)
                    .frame(width: 40, height: 22)
                    .padding(.top, 4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hide tools")

            ForEach(InkTool.allCases) { tool in
                RailButton(
                    symbol: tools.symbol(for: tool),
                    label: tool == .eraser ? tools.toolDisplayName : tool.name,
                    isSelected: tools.tool == tool,
                    selection: selection
                ) {
                    tools.select(tool)
                }
            }

            if tools.tool != .lasso {
                RailDivider()
                options
            }
            RailDivider()

            RailButton(symbol: "ruler", label: "Ruler", isSelected: tools.isRulerActive, style: .toggle) {
                tools.isRulerActive.toggle()
            }
            RailButton(symbol: "hand.draw", label: "Draw with Finger", isSelected: tools.allowsFingerDrawing, style: .toggle) {
                tools.allowsFingerDrawing.toggle()
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var options: some View {
        if tools.tool.hasColors {
            ForEach(Array(tools.tool.palette.enumerated()), id: \.offset) { _, color in
                ColorDrop(color: Color(color), isSelected: tools.color.hexString == color.hexString) {
                    tools.setColor(color)
                }
            }
            ColorPicker(
                "Custom Colour",
                selection: Binding(get: { Color(tools.color) }, set: { tools.setColor(UIColor($0)) }),
                supportsOpacity: false
            )
            .labelsHidden()
            .scaleEffect(0.85)
            .frame(width: 32, height: 32)
            if tools.tool.isInking {
                RailDivider()
                widthOptions(color: tools.color.isVeryDark ? Theme.ink : Color(tools.color))
            } else if tools.tool == .text {
                RailDivider()
                textSizeOptions
            }
        } else if tools.tool == .eraser {
            RailButton(symbol: "scribble", label: "Object Eraser", caption: "Object", isSelected: !tools.eraserIsPartial, style: .toggle) {
                tools.eraserIsPartial = false
            }
            RailButton(symbol: "eraser.line.dashed", label: "Pixel Eraser", caption: "Pixel", isSelected: tools.eraserIsPartial, style: .toggle) {
                tools.eraserIsPartial = true
            }
            if tools.eraserIsPartial {
                RailDivider()
                widthOptions(color: Theme.inkSecondary)
            }
        }
    }

    private var textSizeOptions: some View {
        ForEach(0..<3, id: \.self) { index in
            Button {
                tools.setWidthIndex(index)
            } label: {
                Text("A")
                    .font(.system(size: CGFloat(11 + index * 5), weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 32, height: 30)
                    .background {
                        if tools.widthIndex == index {
                            Circle().strokeBorder(Theme.ink.opacity(0.7), lineWidth: 1.5)
                                .frame(width: 28, height: 28)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(["Small Text", "Medium Text", "Large Text"][index])
        }
    }

    private func widthOptions(color: Color) -> some View {
        ForEach(0..<3, id: \.self) { index in
            Button {
                tools.setWidthIndex(index)
            } label: {
                Circle()
                    .fill(color)
                    .frame(width: CGFloat(5 + index * 5), height: CGFloat(5 + index * 5))
                    .frame(width: 32, height: 30)
                    .background {
                        if tools.widthIndex == index {
                            Circle().strokeBorder(Theme.ink.opacity(0.7), lineWidth: 1.5)
                                .frame(width: 28, height: 28)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(["Thin", "Medium", "Thick"][index])
        }
    }
}

private struct RailBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(Theme.deskRaised)
            .shadow(color: .black.opacity(0.14), radius: 14, y: 4)
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 0.5)
            }
    }
}

private struct RailButton: View {
    enum Style {
        case tool
        case toggle
    }

    let symbol: String
    let label: String
    var caption: String? = nil
    let isSelected: Bool
    var style: Style = .tool
    /// Lets the selected tool's stamp disc slide between tools.
    var selection: Namespace.ID? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                icon
                if let caption {
                    Text(caption)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(isSelected ? Theme.stamp : Theme.inkSecondary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help(label)
    }

    private var icon: some View {
        Image(systemName: symbol)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(foreground)
            .frame(width: 40, height: caption == nil ? 40 : 30)
            .background {
                if isSelected {
                    if style == .tool, let selection {
                        Circle()
                            .fill(Theme.stamp)
                            .matchedGeometryEffect(id: "selectedTool", in: selection)
                    } else {
                        Circle().fill(style == .tool ? Theme.stamp : Theme.ink.opacity(0.1))
                    }
                }
            }
            .contentShape(Circle())
    }

    private var foreground: Color {
        switch (style, isSelected) {
        case (.tool, true): .white
        case (.toggle, true): Theme.stamp
        default: Theme.ink
        }
    }
}

private struct ColorDrop: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .overlay {
                    // A rim keeps dark inks visible on the dark rail.
                    Circle().strokeBorder(Theme.inkSecondary.opacity(0.45), lineWidth: 1)
                }
                .frame(width: 22, height: 22)
                .padding(3)
                .overlay {
                    if isSelected {
                        Circle().strokeBorder(Theme.ink, lineWidth: 2)
                    }
                }
                .frame(width: 32, height: 30)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Colour")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct RailDivider: View {
    var body: some View {
        Capsule()
            .fill(Theme.hairline)
            .frame(width: 24, height: 1)
            .padding(.vertical, 4)
    }
}

private extension UIColor {
    var isVeryDark: Bool {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return 0.299 * red + 0.587 * green + 0.114 * blue < 0.2
    }
}
