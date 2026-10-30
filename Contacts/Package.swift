// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ContactsBrowser",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "ContactsCore", targets: ["ContactsCore"])],
    targets: [
        .target(name: "ContactsCore"),
        .testTarget(name: "ContactsCoreTests", dependencies: ["ContactsCore"])
    ]
)
