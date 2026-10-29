import Foundation

public enum Calculator {
    /// A leading "=" is the advanced calculator. Standard expressions stay available either way.
    public static func allows(_ raw: String, advanced: Bool) -> Bool {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("=") { return advanced }
        return true
    }

    public static func evaluate(_ raw: String) -> Double? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("=") { text.removeFirst() }
        text = text.trimmingCharacters(in: .whitespaces)
        if text.isEmpty { return nil }
        let cleaned = text
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: ",", with: "")
        guard cleaned.contains(where: { "+-*/%^()".contains($0) }) || cleaned.contains(".") else {
            return nil
        }
        guard cleaned.allSatisfy({ character in
            character.isNumber || character.isLetter || " +-*/%^().,".contains(character)
        }) else { return nil }
        var parser = Parser(Array(cleaned.lowercased().filter { !$0.isWhitespace }))
        guard let value = parser.parseExpression(), parser.isDone, value.isFinite else { return nil }
        return value
    }

    public static func format(_ value: Double) -> String {
        if abs(value) < 1e15, abs(value - value.rounded()) < 1e-9 {
            return String(format: "%.0f", value.rounded())
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 10
        formatter.minimumFractionDigits = 0
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

private struct Parser {
    let characters: [Character]
    var index = 0

    init(_ characters: [Character]) { self.characters = characters }

    var isDone: Bool { index >= characters.count }

    mutating func peek() -> Character? {
        index < characters.count ? characters[index] : nil
    }

    mutating func pop() -> Character? {
        guard index < characters.count else { return nil }
        let character = characters[index]
        index += 1
        return character
    }

    mutating func parseExpression() -> Double? { parseAdd() }

    mutating func parseAdd() -> Double? {
        guard var value = parseMul() else { return nil }
        while let op = peek(), op == "+" || op == "-" {
            _ = pop()
            guard let rhs = parseMul() else { return nil }
            value = op == "+" ? value + rhs : value - rhs
        }
        return value
    }

    mutating func parseMul() -> Double? {
        guard var value = parsePow() else { return nil }
        while let op = peek(), op == "*" || op == "/" || op == "%" {
            _ = pop()
            guard let rhs = parsePow() else { return nil }
            switch op {
            case "*": value *= rhs
            case "/": value /= rhs
            default: value = rhs == 0 ? .nan : value.truncatingRemainder(dividingBy: rhs)
            }
        }
        return value
    }

    mutating func parsePow() -> Double? {
        guard var value = parseUnary() else { return nil }
        if peek() == "^" {
            _ = pop()
            guard let rhs = parsePow() else { return nil }
            value = pow(value, rhs)
        }
        return value
    }

    mutating func parseUnary() -> Double? {
        if peek() == "-" {
            _ = pop()
            guard let value = parseUnary() else { return nil }
            return -value
        }
        if peek() == "+" {
            _ = pop()
            return parseUnary()
        }
        return parsePrimary()
    }

    mutating func parsePrimary() -> Double? {
        if peek() == "(" {
            _ = pop()
            guard let value = parseExpression(), pop() == ")" else { return nil }
            return value
        }
        if peek()?.isLetter == true {
            var name = ""
            while let character = peek(), character.isLetter {
                name.append(pop()!)
            }
            if name == "pi" { return Double.pi }
            if name == "e" { return M_E }
            guard pop() == "(", let argument = parseExpression(), pop() == ")" else { return nil }
            switch name {
            case "sqrt": return sqrt(argument)
            case "sin": return sin(argument)
            case "cos": return cos(argument)
            case "tan": return tan(argument)
            case "ln": return log(argument)
            case "log": return log10(argument)
            case "abs": return abs(argument)
            default: return nil
            }
        }
        var number = ""
        while let character = peek(), character.isNumber || character == "." {
            number.append(pop()!)
        }
        return Double(number)
    }
}

private let M_E = 2.718281828459045
