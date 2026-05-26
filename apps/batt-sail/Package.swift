// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "batt-sail",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "batt-sail", targets: ["BattSail"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0")
    ],
    targets: [
        .executableTarget(
            name: "BattSail",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        )
    ]
)
