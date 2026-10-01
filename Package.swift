// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AdvancedCalculator",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "CalculatorCore", targets: ["CalculatorCore"])],
    targets: [
        .target(name: "CalculatorCore"),
        .testTarget(name: "CalculatorCoreTests", dependencies: ["CalculatorCore"])
    ]
)
