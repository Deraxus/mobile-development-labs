import SwiftUI

@main
struct AdvancedCalculatorApp: App {
    @State private var calculator = CalculatorStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(calculator: calculator)
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active { calculator.save() }
                }
        }
    }
}
