import Foundation

public enum CalculatorError: Error, LocalizedError, Equatable {
    case emptyExpression, divisionByZero, mismatchedParentheses
    case consecutiveOperators, multipleDecimalPoints, trailingOperator
    case invalidExpression, invalidCharacter(String), nonFiniteResult, tooLong

    public var errorDescription: String? {
        switch self {
        case .emptyExpression: "Введите выражение."
        case .divisionByZero: "Делить на ноль нельзя."
        case .mismatchedParentheses: "Проверьте количество и порядок скобок."
        case .consecutiveOperators: "Два арифметических оператора подряд."
        case .multipleDecimalPoints: "В одном числе может быть только одна точка."
        case .trailingOperator: "После оператора нужно число или выражение в скобках."
        case .invalidExpression: "Проверьте выражение: между числами нужен оператор."
        case .invalidCharacter(let character): "Недопустимый символ: \(character)."
        case .nonFiniteResult: "Результат слишком велик."
        case .tooLong: "Выражение слишком длинное или содержит слишком много вложенных скобок."
        }
    }
}

/// Recursive descent: sum -> product -> factor; percent is a postfix operator.
/// No UI dependencies. Negative operands after a binary operator require parentheses.
public struct ExpressionEvaluator {
    public init() {}

    public func evaluate(_ expression: String) throws -> Double {
        let normalized = expression
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: ",", with: ".")
        guard normalized.count <= 4096 else { throw CalculatorError.tooLong }
        var lexer = Lexer(characters: Array(normalized))
        let tokens = try lexer.tokenize()
        guard !tokens.isEmpty else { throw CalculatorError.emptyExpression }
        var balance = 0
        for token in tokens {
            if token == .left { balance += 1 }
            if token == .right { balance -= 1 }
            guard balance >= 0 else { throw CalculatorError.mismatchedParentheses }
            guard balance <= 128 else { throw CalculatorError.tooLong }
        }
        guard balance == 0 else { throw CalculatorError.mismatchedParentheses }
        for (a, b) in zip(tokens, tokens.dropFirst()) where a.isBinary && b.isBinary {
            throw CalculatorError.consecutiveOperators
        }
        if tokens.last?.isBinary == true { throw CalculatorError.trailingOperator }
        var parser = Parser(tokens: tokens)
        let result = try parser.sum()
        guard parser.index == tokens.count else { throw CalculatorError.invalidExpression }
        guard result.isFinite else { throw CalculatorError.nonFiniteResult }
        return result == 0 ? 0 : result
    }

    public static func format(_ number: Double) -> String {
        // Scientific notation remains valid input; do not silently round small values to zero.
        number == 0 ? "0" : String(format: "%.15g", locale: Locale(identifier: "en_US_POSIX"), number)
    }
}

private enum Token: Equatable {
    case number(Double), plus, minus, multiply, divide, left, right, percent
    var isBinary: Bool {
        switch self {
        case .plus, .minus, .multiply, .divide: true
        default: false
        }
    }
}

private struct Lexer {
    let characters: [Character]
    var index = 0

    mutating func tokenize() throws -> [Token] {
        var tokens: [Token] = []
        while index < characters.count {
            let c = characters[index]
            if c.isWhitespace { index += 1; continue }
            if c.isASCIIDigit || c == "." {
                tokens.append(.number(try number()))
                continue
            }
            let token: Token
            switch c {
            case "+": token = .plus
            case "-": token = .minus
            case "*": token = .multiply
            case "/": token = .divide
            case "(": token = .left
            case ")": token = .right
            case "%": token = .percent
            default: throw CalculatorError.invalidCharacter(String(c))
            }
            tokens.append(token)
            index += 1
        }
        return tokens
    }

    mutating func number() throws -> Double {
        let start = index
        var dots = 0
        var digits = 0
        while index < characters.count {
            let c = characters[index]
            if c == "." {
                dots += 1
                guard dots <= 1 else { throw CalculatorError.multipleDecimalPoints }
            } else if c.isASCIIDigit {
                digits += 1
            } else { break }
            index += 1
        }
        guard digits > 0 else { throw CalculatorError.invalidExpression }
        if index < characters.count && (characters[index] == "e" || characters[index] == "E") {
            index += 1
            if index < characters.count && (characters[index] == "+" || characters[index] == "-") {
                index += 1
            }
            let exponentStart = index
            while index < characters.count && characters[index].isASCIIDigit { index += 1 }
            guard index > exponentStart else { throw CalculatorError.invalidExpression }
        }
        guard let value = Double(String(characters[start..<index])), value.isFinite else {
            throw CalculatorError.nonFiniteResult
        }
        return value
    }
}

private extension Character {
    var isASCIIDigit: Bool { self >= "0" && self <= "9" }
}

private struct Parser {
    let tokens: [Token]
    var index = 0
    var current: Token? { index < tokens.count ? tokens[index] : nil }

    mutating func sum() throws -> Double {
        var result = try product()
        while current == .plus || current == .minus {
            let operation = current
            index += 1
            let rhs = try product()
            result = operation == .plus ? result + rhs : result - rhs
            try check(result)
        }
        return result
    }

    mutating func product() throws -> Double {
        var result = try factor()
        while current == .multiply || current == .divide {
            let operation = current
            index += 1
            let rhs = try factor()
            if operation == .divide && rhs == 0 { throw CalculatorError.divisionByZero }
            result = operation == .multiply ? result * rhs : result / rhs
            try check(result)
        }
        return result
    }

    mutating func factor() throws -> Double {
        var negative = false
        if current == .minus {
            negative = true
            index += 1
        }
        var result: Double
        switch current {
        case .number(let value):
            result = value
            index += 1
        case .left:
            index += 1
            result = try sum()
            guard current == .right else { throw CalculatorError.invalidExpression }
            index += 1
        default: throw CalculatorError.invalidExpression
        }
        if current == .percent {
            result /= 100
            index += 1
        }
        return negative ? -result : result
    }

    func check(_ value: Double) throws {
        guard value.isFinite else { throw CalculatorError.nonFiniteResult }
    }
}
