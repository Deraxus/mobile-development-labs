import SwiftUI

struct ContentView: View {
    @Bindable var calculator: CalculatorStore
    @State private var showHistory = false
    @FocusState private var editing: Bool
    private let accent = Color(red: 0.23, green: 0.37, blue: 0.87)
    private let rows = [
        ["C", "⌫", "(", ")"],
        ["7", "8", "9", "÷"],
        ["4", "5", "6", "×"],
        ["1", "2", "3", "−"],
        ["±", "0", ".", "+"]
    ]

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width > geometry.size.height
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Калькулятор").font(.title2.bold())
                            Text("Выражения со скобками").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if !wide {
                            Button { editing = false; showHistory = true } label: {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.title3).padding(12)
                                    .background(accent.opacity(0.1), in: Circle())
                            }
                            .accessibilityLabel("История вычислений")
                            .accessibilityIdentifier("history")
                        }
                    }
                    HStack(alignment: .top, spacing: 24) {
                        calculatorPanel(compact: wide)
                        if wide {
                            HistoryView(calculator: calculator)
                                .frame(width: geometry.size.width * 0.36)
                        }
                    }
                }
                .padding(wide ? 16 : 20)
                .frame(maxWidth: 1000)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(uiColor: .systemGroupedBackground))
        }
        .tint(accent)
        .sheet(isPresented: $showHistory) {
            NavigationStack {
                ScrollView {
                    HistoryView(calculator: calculator) { showHistory = false }.padding(20)
                }
                    .navigationTitle("История")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Готово") { showHistory = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Готово") { editing = false }
            }
        }
    }

    private func calculatorPanel(compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 14) {
            VStack(alignment: .trailing, spacing: 10) {
                HStack {
                    Text("ВЫРАЖЕНИЕ").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    Spacer()
                    Text("M: \(ExpressionEvaluator.format(calculator.memory))")
                        .font(.caption.monospacedDigit()).foregroundStyle(accent)
                        .accessibilityIdentifier("memoryValue")
                }
                TextField("0", text: $calculator.expression, axis: .vertical)
                    .font(.system(size: compact ? 25 : 32, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1...3)
                    .keyboardType(.asciiCapable)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($editing)
                    .accessibilityLabel("Арифметическое выражение")
                    .accessibilityIdentifier("expression")
                if let error = calculator.errorMessage {
                    Label(error, systemImage: "exclamationmark.circle.fill")
                        .font(.callout).foregroundStyle(.red)
                        .accessibilityIdentifier("error")
                } else if let result = calculator.lastResult {
                    HStack(alignment: .firstTextBaseline) {
                        Text(calculator.showingResult ? "Результат" : "Последний результат")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(ExpressionEvaluator.format(result))
                            .font(.system(size: compact ? 25 : 34, weight: .semibold, design: .rounded))
                            .foregroundStyle(accent)
                            .minimumScaleFactor(0.5).lineLimit(1)
                            .accessibilityIdentifier("result")
                    }
                } else {
                    Text("Введите выражение и нажмите =")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(compact ? 12 : 20)
            .frame(maxWidth: .infinity, minHeight: compact ? 100 : 145, alignment: .bottomTrailing)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))

            HStack(spacing: 8) {
                ForEach(["MC", "MR", "M−", "M+"], id: \.self) { title in
                    Button { perform(title) } label: {
                        Text(title).font(.callout.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: compact ? 32 : 42)
                            .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .accessibilityIdentifier(title)
                    .accessibilityLabel(memoryLabel(title))
                }
            }
            VStack(spacing: compact ? 6 : 10) {
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: compact ? 6 : 10) {
                        ForEach(row, id: \.self) { title in key(title, compact: compact) }
                    }
                }
                GeometryReader { size in
                  HStack(spacing: compact ? 6 : 10) {
                    key("%", compact: compact)
                        .frame(width: (size.size.width - (compact ? 18 : 30)) / 4)
                    Button { perform("=") } label: {
                        Text("=").font(.system(size: 28, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: compact ? 38 : 56)
                            .foregroundStyle(.white)
                            .background(accent, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .accessibilityLabel("Вычислить")
                    .accessibilityIdentifier("equals")
                    .frame(maxWidth: .infinity)
                  }
                }
                .frame(height: compact ? 38 : 56)
            }
            Text("% — деление на 100 · ± — знак последнего числа")
                .font(.caption2).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }

    private func key(_ title: String, compact: Bool) -> some View {
        let operation = ["÷", "×", "−", "+"].contains(title)
        return Button { perform(title) } label: {
            Text(title).font(.system(size: compact ? 22 : 26, weight: .medium, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: compact ? 38 : 56)
                .foregroundStyle(operation ? accent : Color.primary)
                .background(operation ? accent.opacity(0.12) : Color(uiColor: .secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 16))
        }
        .accessibilityIdentifier("key_\(title)")
        .accessibilityLabel(title == "⌫" ? "Удалить последний символ" : title == "C" ? "Очистить ввод" : title)
    }

    private func perform(_ title: String) {
        editing = false
        switch title {
        case "=": calculator.calculate()
        case "C": calculator.clear()
        case "⌫": calculator.deleteLast()
        case "±": calculator.toggleSign()
        case "MC": calculator.clearMemory()
        case "MR": calculator.recallMemory()
        case "M+": calculator.addToMemory()
        case "M−": calculator.subtractFromMemory()
        default: calculator.input(title)
        }
    }

    private func memoryLabel(_ title: String) -> String {
        switch title {
        case "MC": "Очистить память"
        case "MR": "Вставить значение из памяти"
        case "M+": "Добавить текущее значение в память"
        default: "Вычесть текущее значение из памяти"
        }
    }
}

struct HistoryView: View {
    @Bindable var calculator: CalculatorStore
    var onSelect: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Последние вычисления").font(.headline)
                Spacer()
                Text("\(calculator.history.count)/10").font(.caption).foregroundStyle(.secondary)
            }
            if calculator.history.isEmpty {
                ContentUnavailableView("История пуста", systemImage: "clock",
                                       description: Text("Здесь появятся последние 10 вычислений."))
            } else {
                Text("Нажмите, чтобы вернуть выражение").font(.caption).foregroundStyle(.secondary)
                ForEach(calculator.history) { item in
                    Button {
                        calculator.restore(item)
                        onSelect()
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.expression).font(.body).foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            Text("= " + ExpressionEvaluator.format(item.result))
                                .font(.title3.weight(.semibold)).foregroundStyle(.tint)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .accessibilityIdentifier("history_\(item.id)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
