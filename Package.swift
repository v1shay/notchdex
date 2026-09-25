// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "NotchCodex",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "NotchCodex", targets: ["NotchCodex"])
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0")
    ],
    targets: [
        .executableTarget(
            name: "NotchCodex",
            dependencies: ["SwiftTerm"],
            path: "Sources/NotchCodex"
        )
    ]
)
