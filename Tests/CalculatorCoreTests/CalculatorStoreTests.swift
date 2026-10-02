import XCTest
@testable import CalculatorCore

final class CalculatorStoreTests: XCTestCase {
    @MainActor private static func fresh() -> (CalculatorStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: "CalculatorTests." + UUID().uuidString)!
        return (CalculatorStore(defaults: defaults), defaults)
    }

    func testHistoryKeepsTenAndRestoresEditableExpression() async {
        await MainActor.run {
            let (store, _) = Self.fresh()
            for number in 1...12 { store.expression = "\(number)+1"; store.calculate() }
            XCTAssertEqual(store.history.count, 10)
            XCTAssertEqual(store.history.first?.expression, "12+1")
            XCTAssertEqual(store.history.last?.expression, "3+1")
            let item = store.history[2]
            store.restore(item)
            XCTAssertEqual(store.expression, item.expression)
            XCTAssertFalse(store.showingResult)
            store.input("+2")
            store.calculate()
            XCTAssertEqual(store.lastResult, item.result + 2)
        }
    }

    func testMemoryOperations() async {
        await MainActor.run {
            let (store, _) = Self.fresh()
            store.expression = "12+5×3"
            store.addToMemory()
            XCTAssertEqual(store.memory, 27)
            store.expression = "7"
            store.subtractFromMemory()
            XCTAssertEqual(store.memory, 20)
            store.clear()
            store.recallMemory()
            XCTAssertEqual(store.expression, "20")
            store.expression = "2+"
            store.recallMemory()
            store.calculate()
            XCTAssertEqual(store.lastResult, 22)
            store.expression = "1/0"
            store.addToMemory()
            XCTAssertEqual(store.memory, 20)
            XCTAssertNotNil(store.errorMessage)
            store.clearMemory()
            XCTAssertEqual(store.memory, 0)
        }
    }

    func testNegativeMemoryRecallAndImplicitMultiplication() async {
        await MainActor.run {
            let (store, _) = Self.fresh()
            store.expression = "−3"
            store.addToMemory()
            store.expression = "2×"
            store.recallMemory()
            store.calculate()
            XCTAssertEqual(store.lastResult, -6)
            store.expression = "5"
            store.recallMemory()
            store.calculate()
            XCTAssertEqual(store.lastResult, -15)
        }
    }

    func testSignSwitchAndPercent() async throws {
        try await MainActor.run {
            let (store, _) = Self.fresh()
            let evaluator = ExpressionEvaluator()
            for input in ["5", "12+5", "12×5", "0.5", "50%", "2×(3+4)"] {
                store.expression = input
                let value = try evaluator.evaluate(input)
                store.toggleSign()
                XCTAssertNoThrow(try evaluator.evaluate(store.expression), store.expression)
                store.toggleSign()
                XCTAssertEqual(try evaluator.evaluate(store.expression), value, accuracy: 1e-12, input)
            }
            store.expression = "12+5"
            store.toggleSign()
            store.calculate()
            XCTAssertEqual(store.lastResult, 7)
        }
    }

    func testPersistenceIncludesEveryRequiredFieldAndError() async {
        await MainActor.run {
            let (store, defaults) = Self.fresh()
            store.expression = "(12+5)×3"
            store.calculate()
            store.addToMemory()
            store.expression = "1÷0"
            store.calculate()
            let restored = CalculatorStore(defaults: defaults)
            XCTAssertEqual(restored.expression, "1÷0")
            XCTAssertEqual(restored.history, store.history)
            XCTAssertEqual(restored.memory, 51)
            XCTAssertEqual(restored.lastResult, 51)
            XCTAssertEqual(restored.errorMessage, store.errorMessage)
            XCTAssertFalse(restored.showingResult)
            restored.deleteLast()
            XCTAssertNil(restored.errorMessage)
            XCTAssertEqual(restored.expression, "1÷")
        }
    }

    func testContinuationAfterResultAndClear() async {
        await MainActor.run {
            let (store, defaults) = Self.fresh()
            store.expression = "2+3"; store.calculate()
            let restored = CalculatorStore(defaults: defaults)
            XCTAssertTrue(restored.showingResult)
            restored.input("×"); restored.input("2"); restored.calculate()
            XCTAssertEqual(restored.lastResult, 10)
            restored.input("7")
            XCTAssertEqual(restored.expression, "7")
            restored.clear()
            XCTAssertEqual(restored.expression, "")
            XCTAssertNil(restored.lastResult)
            XCTAssertNil(restored.errorMessage)
            XCTAssertEqual(restored.history.count, 2)
        }
    }

    func testInvalidExpressionsDoNotEnterHistory() async {
        await MainActor.run {
            let (store, _) = Self.fresh()
            for input in ["", "1/0", "(2+3", "2++3", "1..5", "2+"] {
                store.expression = input; store.calculate()
                XCTAssertNotNil(store.errorMessage)
                XCTAssertTrue(store.history.isEmpty)
            }
        }
    }
}
