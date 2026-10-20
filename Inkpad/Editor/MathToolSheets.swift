//
//  MathToolSheets.swift
//  Inkpad
//

import SwiftUI

/// Edits an equation's LaTeX with a live preview and one-tap templates.
struct EquationEditor: View {
    @Binding var latex: String

    private static let templates: [(label: String, latex: String)] = [
        ("a⁄b", "\\frac{a}{b}"), ("√x", "\\sqrt{x}"), ("ⁿ√x", "\\sqrt[n]{x}"), ("xⁿ", "x^{n}"), ("xᵢ", "x_{i}"),
        ("Σ", "\\sum_{i=1}^{n}"), ("∫", "\\int_{a}^{b}"), ("lim", "\\lim_{x \\to 0}"), ("d/dx", "\\frac{d}{dx}"),
        ("( )", "\\left( x \\right)"), ("matrix", "\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}"),
        ("π", "\\pi"), ("θ", "\\theta"), ("α", "\\alpha"), ("β", "\\beta"), ("λ", "\\lambda"), ("Δ", "\\Delta"),
        ("∞", "\\infty"), ("±", "\\pm"), ("·", "\\cdot"), ("×", "\\times"), ("≤", "\\leq"), ("≥", "\\geq"),
        ("≠", "\\neq"), ("≈", "\\approx"), ("→", "\\to"), ("∈", "\\in"), ("∂", "\\partial"),
    ]

    var body: some View {
        Section {
            EquationPreview(latex: latex)
                .frame(maxWidth: .infinity, minHeight: 120)
                .listRowInsets(EdgeInsets())
        }
        Section {
            TextEditor(text: $latex)
                .font(.system(.body, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .frame(minHeight: 90)
            if !latex.isEmpty && BoardItemRenderer.equationImage(latex, color: .black) == nil {
                Label("This LaTeX can't be read yet. Check for missing braces.", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(Theme.stamp)
            }
        } header: {
            Text("LaTeX")
        } footer: {
            Text("For example: x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}")
        }
        Section("Insert") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: 8)], spacing: 8) {
                ForEach(Self.templates, id: \.latex) { template in
                    Button {
                        latex += (latex.isEmpty || latex.hasSuffix(" ") ? "" : " ") + template.latex
                    } label: {
                        Text(template.label)
                            .font(.system(size: 16, weight: .medium, design: .serif))
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(Theme.desk, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(template.latex)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct EquationPreview: View {
    let latex: String

    var body: some View {
        Group {
            if let image = BoardItemRenderer.equationImage(latex, color: UIColor(hex: 0x1E1D1B), fontSize: 30) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: image.size.width, maxHeight: image.size.height)
                    .padding(20)
            } else {
                Text(latex.isEmpty ? "Type LaTeX below" : "…")
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(Color.white)
    }
}

/// Edits a table's size and cell text.
struct TableEditor: View {
    @Binding var cells: [[String]]

    var body: some View {
        Section("Size") {
            Stepper("Rows: \(cells.count)", value: rowCount, in: 1...8)
            Stepper("Columns: \(cells.first?.count ?? 1)", value: columnCount, in: 1...8)
        }
        Section {
            ScrollView(.horizontal) {
                Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                    ForEach(cells.indices, id: \.self) { row in
                        GridRow {
                            ForEach(cells[row].indices, id: \.self) { column in
                                TextField(row == 0 ? "Heading" : "", text: $cells[row][column])
                                    .font(row == 0 ? .body.weight(.semibold) : .body)
                                    .padding(8)
                                    .frame(width: 140)
                                    .background(row == 0 ? Theme.desk : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            }
        } header: {
            Text("Cells")
        } footer: {
            Text("The first row is the header.")
        }
    }

    private var rowCount: Binding<Int> {
        Binding(get: { cells.count }, set: { count in
            let columns = cells.first?.count ?? 1
            while cells.count < count { cells.append(Array(repeating: "", count: columns)) }
            while cells.count > count { cells.removeLast() }
        })
    }

    private var columnCount: Binding<Int> {
        Binding(get: { cells.first?.count ?? 1 }, set: { count in
            for row in cells.indices {
                while cells[row].count < count { cells[row].append("") }
                while cells[row].count > count { cells[row].removeLast() }
            }
        })
    }
}

/// Converts between units and drops the result onto the page as text.
struct UnitConverterSheet: View {
    let onInsert: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var category = UnitCategory.length
    @State private var input = "1"
    @State private var fromIndex = 0
    @State private var toIndex = 1

    var body: some View {
        NavigationStack {
            Form {
                Picker("Measure", selection: $category) {
                    ForEach(UnitCategory.allCases) { category in
                        Text(category.name).tag(category)
                    }
                }
                Section {
                    HStack {
                        TextField("Value", text: $input)
                            .keyboardType(.decimalPad)
                            .font(.title3.monospacedDigit())
                        Picker("From", selection: $fromIndex) {
                            ForEach(category.units.indices, id: \.self) { index in
                                Text(category.units[index].name).tag(index)
                            }
                        }
                        .labelsHidden()
                    }
                    Button {
                        swap(&fromIndex, &toIndex)
                    } label: {
                        Label("Swap", systemImage: "arrow.up.arrow.down")
                    }
                    HStack {
                        Text(resultValue)
                            .font(.title3.monospacedDigit().weight(.semibold))
                            .foregroundStyle(Theme.stamp)
                            .textSelection(.enabled)
                        Spacer()
                        Picker("To", selection: $toIndex) {
                            ForEach(category.units.indices, id: \.self) { index in
                                Text(category.units[index].name).tag(index)
                            }
                        }
                        .labelsHidden()
                    }
                }
            }
            .navigationTitle("Unit Converter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Insert as Text") {
                        onInsert(sentence)
                        dismiss()
                    }
                    .disabled(value == nil)
                }
            }
            .onChange(of: category) {
                fromIndex = 0
                toIndex = min(1, category.units.count - 1)
            }
        }
        .tint(Theme.stamp)
    }

    private var value: Double? {
        Double(input.replacingOccurrences(of: ",", with: "."))
    }

    private var resultValue: String {
        guard let value else { return "—" }
        let from = Measurement(value: value, unit: category.units[fromIndex].unit)
        return Self.format(from.converted(to: category.units[toIndex].unit).value)
    }

    private var sentence: String {
        guard let value else { return "" }
        return "\(Self.format(value)) \(category.units[fromIndex].symbol) = \(resultValue) \(category.units[toIndex].symbol)"
    }

    private static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.significantDigits(1...6)))
    }
}

enum UnitCategory: String, CaseIterable, Identifiable {
    case length, mass, temperature, volume, area, speed, time, energy

    var id: String { rawValue }
    var name: String { rawValue.capitalized }

    struct Option {
        let name: String
        let symbol: String
        let unit: Dimension
    }

    var units: [Option] {
        switch self {
        case .length:
            [Option(name: "Metres", symbol: "m", unit: UnitLength.meters), Option(name: "Feet", symbol: "ft", unit: UnitLength.feet),
             Option(name: "Kilometres", symbol: "km", unit: UnitLength.kilometers), Option(name: "Miles", symbol: "mi", unit: UnitLength.miles),
             Option(name: "Centimetres", symbol: "cm", unit: UnitLength.centimeters), Option(name: "Inches", symbol: "in", unit: UnitLength.inches)]
        case .mass:
            [Option(name: "Kilograms", symbol: "kg", unit: UnitMass.kilograms), Option(name: "Pounds", symbol: "lb", unit: UnitMass.pounds),
             Option(name: "Grams", symbol: "g", unit: UnitMass.grams), Option(name: "Ounces", symbol: "oz", unit: UnitMass.ounces)]
        case .temperature:
            [Option(name: "Celsius", symbol: "°C", unit: UnitTemperature.celsius), Option(name: "Fahrenheit", symbol: "°F", unit: UnitTemperature.fahrenheit),
             Option(name: "Kelvin", symbol: "K", unit: UnitTemperature.kelvin)]
        case .volume:
            [Option(name: "Litres", symbol: "L", unit: UnitVolume.liters), Option(name: "Gallons (US)", symbol: "gal", unit: UnitVolume.gallons),
             Option(name: "Millilitres", symbol: "mL", unit: UnitVolume.milliliters), Option(name: "Cups", symbol: "cup", unit: UnitVolume.cups)]
        case .area:
            [Option(name: "Square metres", symbol: "m²", unit: UnitArea.squareMeters), Option(name: "Square feet", symbol: "ft²", unit: UnitArea.squareFeet),
             Option(name: "Hectares", symbol: "ha", unit: UnitArea.hectares), Option(name: "Acres", symbol: "ac", unit: UnitArea.acres)]
        case .speed:
            [Option(name: "km/h", symbol: "km/h", unit: UnitSpeed.kilometersPerHour), Option(name: "mph", symbol: "mph", unit: UnitSpeed.milesPerHour),
             Option(name: "m/s", symbol: "m/s", unit: UnitSpeed.metersPerSecond), Option(name: "Knots", symbol: "kn", unit: UnitSpeed.knots)]
        case .time:
            [Option(name: "Hours", symbol: "h", unit: UnitDuration.hours), Option(name: "Minutes", symbol: "min", unit: UnitDuration.minutes),
             Option(name: "Seconds", symbol: "s", unit: UnitDuration.seconds)]
        case .energy:
            [Option(name: "Kilojoules", symbol: "kJ", unit: UnitEnergy.kilojoules), Option(name: "Kilocalories", symbol: "kcal", unit: UnitEnergy.kilocalories),
             Option(name: "Kilowatt-hours", symbol: "kWh", unit: UnitEnergy.kilowattHours), Option(name: "Joules", symbol: "J", unit: UnitEnergy.joules)]
        }
    }
}
