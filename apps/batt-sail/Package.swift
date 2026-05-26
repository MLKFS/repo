// swift-tools-version:5.7
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
        .package(url: "https://github.com/apple/swift-argument-parser.git", exact: "1.7.1")
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
