//
//  InkRail.swift
//  Inkpad
//

import SwiftUI

/// The floating vertical toolbar: tools on top, the current tool's options
/// below, then the ruler and finger-drawing toggles.
struct InkRail: View {
    @Bindable var tools: ToolState

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView(.vertical, showsIndicators: false) {
                content
            }
        }
        .frame(width: 52)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Theme.deskRaised)
                .shadow(color: .black.opacity(0.14), radius: 14, y: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 0.5)
        }
        .sensoryFeedback(.selection, trigger: tools.tool)
        .animation(.snappy(duration: 0.22), value: tools.tool)
    }

    private var content: some View {
        VStack(spacing: 4) {
            ForEach(InkTool.allCases) { tool in
                RailButton(symbol: tool.symbol, label: tool.name, isSelected: tools.tool == tool) {
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
        if tools.tool.isInking {
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
            RailDivider()
            widthOptions(color: Color(tools.color))
        } else if tools.tool == .eraser {
            RailButton(symbol: "scribble", label: "Erase Whole Strokes", isSelected: !tools.eraserIsPartial, style: .toggle) {
                tools.eraserIsPartial = false
            }
            RailButton(symbol: "eraser.line.dashed", label: "Erase Parts of Strokes", isSelected: tools.eraserIsPartial, style: .toggle) {
                tools.eraserIsPartial = true
            }
            if tools.eraserIsPartial {
                RailDivider()
                widthOptions(color: Theme.inkSecondary)
            }
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

private struct RailButton: View {
    enum Style {
        case tool
        case toggle
    }

    let symbol: String
    let label: String
    let isSelected: Bool
    var style: Style = .tool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(foreground)
                .frame(width: 40, height: 40)
                .background {
                    if isSelected {
                        Circle().fill(style == .tool ? Theme.stamp : Theme.ink.opacity(0.1))
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help(label)
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
                    Circle().strokeBorder(.black.opacity(0.12), lineWidth: 0.5)
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
