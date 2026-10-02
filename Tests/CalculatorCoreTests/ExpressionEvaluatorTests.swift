import XCTest
@testable import CalculatorCore

final class ExpressionEvaluatorTests: XCTestCase {
    private let evaluator = ExpressionEvaluator()

    func testExamplesFromSpecification() throws {
        for (expression, result) in [("12 + 5 × 3", 27.0), ("(12 + 5) × 3", 51),
                                     ("20 ÷ 4 + 7", 12), ("15.5 × 2", 31)] {
            XCTAssertEqual(try evaluator.evaluate(expression), result, accuracy: 1e-12, expression)
        }
    }

    func testPrecedenceAssociativityAndDecimals() throws {
        for (expression, result) in [("2*(3+(4*5))", 46.0), ("20/4/5", 1), ("10-3-2", 5),
                                     (".5 + 1.25", 1.75), ("1,5×2", 3), ("-5+2", -3),
                                     ("2×(-3)", -6), ("1e-8*1e8", 1), ("2 + (−5)", -3)] {
            XCTAssertEqual(try evaluator.evaluate(expression), result, accuracy: 1e-12, expression)
        }
    }

    func testPercent() throws {
        for (expression, result) in [("50%", 0.5), ("200×10%", 20), ("(20+30)%", 0.5),
                                     ("100+10%", 100.1), ("(−50%)", -0.5)] {
            XCTAssertEqual(try evaluator.evaluate(expression), result, accuracy: 1e-12, expression)
        }
    }

    func testAllRequiredErrors() {
        let cases: [(String, CalculatorError)] = [
            ("", .emptyExpression), (" \n ", .emptyExpression),
            ("1/0", .divisionByZero), ("5/(2-2)", .divisionByZero),
            ("(1+2", .mismatchedParentheses), ("1+2)", .mismatchedParentheses),
            (")(1+2)", .mismatchedParentheses), ("1++2", .consecutiveOperators),
            ("1*-2", .consecutiveOperators), ("1+−2", .consecutiveOperators),
            ("1..2", .multipleDecimalPoints), ("1.2.3+4", .multipleDecimalPoints),
            ("1+", .trailingOperator), ("12÷", .trailingOperator)
        ]
        for (expression, error) in cases {
            XCTAssertThrowsError(try evaluator.evaluate(expression), expression) {
                XCTAssertEqual($0 as? CalculatorError, error, expression)
            }
        }
    }

    func testOtherInvalidInputAndLimits() {
        for expression in ["()", "1 2", "2(3)", ".", "%%", "5%%", "abc", "1e", "1e999", "1e308*10"] {
            XCTAssertThrowsError(try evaluator.evaluate(expression), expression)
        }
        XCTAssertThrowsError(try evaluator.evaluate(String(repeating: "(", count: 129) + "1" + String(repeating: ")", count: 129)))
        XCTAssertThrowsError(try evaluator.evaluate(String(repeating: "1", count: 4097)))
    }

    func testFormatIsValidInputEvenForTinyAndHugeValues() throws {
        for value in [1e-20, -1e-20, 1e100, -42.0, 0, 0.1 + 0.2] {
            let result = try evaluator.evaluate(ExpressionEvaluator.format(value))
            XCTAssertEqual(result, value, accuracy: max(abs(value) * 1e-14, 1e-35))
        }
    }
}
