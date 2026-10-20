//
//  MathExpression.swift
//  Inkpad
//

import Foundation

/// A small parser and evaluator for graphing expressions in x, such as
/// `y = 2x^2 - 3`, `sin(x)/x` or `3cos(2x) + 1`. Supports + − × ÷ ^,
/// implicit multiplication, π and e, and common functions.
nonisolated struct MathExpression: Sendable {
    indirect enum Node: Sendable {
        case number(Double)
        case variable
        case negate(Node)
        case binary(Character, Node, Node)
        case function(String, Node)
    }

    static let functions: Set<String> = [
        "sin", "cos", "tan", "asin", "acos", "atan", "sinh", "cosh", "tanh",
        "sqrt", "abs", "ln", "log", "exp", "floor", "ceil",
    ]

    let root: Node
    let source: String

    /// Returns nil if the text isn't a valid expression.
    init?(_ text: String) {
        // Accept "y = …" and "f(x) = …".
        var body = text
        if let equals = body.lastIndex(of: "=") {
            body = String(body[body.index(after: equals)...])
        }
        body = body.replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "−", with: "-")
        guard !body.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        var parser = Parser(tokens: Self.tokenize(body))
        guard let root = parser.parseExpression(), parser.isAtEnd else { return nil }
        self.root = root
        self.source = text.trimmingCharacters(in: .whitespaces)
    }

    func evaluate(x: Double) -> Double {
        Self.evaluate(root, x: x)
    }

    private static func evaluate(_ node: Node, x: Double) -> Double {
        switch node {
        case .number(let value): return value
        case .variable: return x
        case .negate(let inner): return -evaluate(inner, x: x)
        case .binary(let op, let lhs, let rhs):
            let a = evaluate(lhs, x: x)
            let b = evaluate(rhs, x: x)
            switch op {
            case "+": return a + b
            case "-": return a - b
            case "*": return a * b
            case "/": return a / b
            case "^": return pow(a, b)
            default: return .nan
            }
        case .function(let name, let argument):
            let a = evaluate(argument, x: x)
            switch name {
            case "sin": return sin(a)
            case "cos": return cos(a)
            case "tan": return tan(a)
            case "asin": return asin(a)
            case "acos": return acos(a)
            case "atan": return atan(a)
            case "sinh": return sinh(a)
            case "cosh": return cosh(a)
            case "tanh": return tanh(a)
            case "sqrt": return sqrt(a)
            case "abs": return abs(a)
            case "ln": return log(a)
            case "log": return log10(a)
            case "exp": return exp(a)
            case "floor": return floor(a)
            case "ceil": return ceil(a)
            default: return .nan
            }
        }
    }

    // MARK: - Tokens

    enum Token: Equatable, Sendable {
        case number(Double)
        case identifier(String)
        case symbol(Character)
    }

    static func tokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            if character.isWhitespace {
                index = text.index(after: index)
            } else if character.isNumber || character == "." {
                var end = index
                while end < text.endIndex, text[end].isNumber || text[end] == "." {
                    end = text.index(after: end)
                }
                tokens.append(.number(Double(text[index..<end]) ?? .nan))
                index = end
            } else if character.isLetter || character == "π" {
                var end = index
                while end < text.endIndex, text[end].isLetter || text[end] == "π" {
                    end = text.index(after: end)
                }
                tokens.append(contentsOf: splitIdentifier(String(text[index..<end]).lowercased()))
                index = end
            } else {
                tokens.append(.symbol(character))
                index = text.index(after: index)
            }
        }
        return tokens
    }

    /// Splits runs like "xsin" or "pix" into known names, so "2xsin(x)" works.
    private static func splitIdentifier(_ word: String) -> [Token] {
        var tokens: [Token] = []
        var rest = Substring(word)
        let names = functions.sorted { $0.count > $1.count } + ["pi", "π", "x", "e"]
        while !rest.isEmpty {
            guard let name = names.first(where: { rest.hasPrefix($0) }) else {
                return [.identifier(word)]
            }
            tokens.append(.identifier(name))
            rest = rest.dropFirst(name.count)
        }
        return tokens
    }

    // MARK: - Parser

    private struct Parser {
        let tokens: [Token]
        var position = 0

        var isAtEnd: Bool { position >= tokens.count }

        private var current: Token? {
            position < tokens.count ? tokens[position] : nil
        }

        mutating func parseExpression() -> Node? {
            guard var node = parseTerm() else { return nil }
            while case .symbol(let op) = current, op == "+" || op == "-" {
                position += 1
                guard let rhs = parseTerm() else { return nil }
                node = .binary(op, node, rhs)
            }
            return node
        }

        mutating func parseTerm() -> Node? {
            guard var node = parseUnary() else { return nil }
            while true {
                if case .symbol(let op) = current, op == "*" || op == "/" {
                    position += 1
                    guard let rhs = parseUnary() else { return nil }
                    node = .binary(op, node, rhs)
                } else if startsFactor {
                    // Implicit multiplication: 2x, 3sin(x), (x+1)(x-1).
                    guard let rhs = parsePower() else { return nil }
                    node = .binary("*", node, rhs)
                } else {
                    return node
                }
            }
        }

        private var startsFactor: Bool {
            switch current {
            case .number, .identifier: true
            case .symbol(let symbol): symbol == "("
            case nil: false
            }
        }

        /// A leading minus applies after powers, so -x^2 is -(x^2).
        mutating func parseUnary() -> Node? {
            if case .symbol("-") = current {
                position += 1
                return parseUnary().map { .negate($0) }
            }
            if case .symbol("+") = current {
                position += 1
                return parseUnary()
            }
            return parsePower()
        }

        mutating func parsePower() -> Node? {
            guard let base = parsePrimary() else { return nil }
            if case .symbol("^") = current {
                position += 1
                // Right-associative, and allows 2^-1.
                guard let exponent = parseUnary() else { return nil }
                return .binary("^", base, exponent)
            }
            return base
        }

        mutating func parsePrimary() -> Node? {
            guard let token = current else { return nil }
            position += 1
            switch token {
            case .number(let value):
                return value.isNaN ? nil : .number(value)
            case .identifier(let name):
                switch name {
                case "x": return .variable
                case "pi", "π": return .number(.pi)
                case "e": return .number(M_E)
                default:
                    guard MathExpression.functions.contains(name) else { return nil }
                    // sin(x)^2 squares the sine; sin x (no brackets) also works.
                    let argument = current == .symbol("(") ? parsePrimary() : parsePower()
                    guard let argument else { return nil }
                    return .function(name, argument)
                }
            case .symbol("("):
                guard let inner = parseExpression(), case .symbol(")") = current else { return nil }
                position += 1
                return inner
            case .symbol:
                return nil
            }
        }
    }
}
