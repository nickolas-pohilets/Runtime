// swift-tools-version:5.0
import PackageDescription
let package = Package(
    name: "Runtime",
    products: [
        .library(
            name: "Runtime",
            targets: ["Runtime"]),
        .library(
            name: "CRuntime",
            type: .static,
            targets: ["CRuntime"]),
        ],
    targets: [
        .target(
            name: "CRuntime",
            dependencies: []),
        .target(
            name: "Runtime",
            dependencies: ["CRuntime"]),
        .testTarget(
            name: "RuntimeTests",
            dependencies: ["Runtime"])
    ],
    swiftLanguageVersions: [.v5]
)
