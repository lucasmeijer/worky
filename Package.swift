// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Worky",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Worky", targets: ["WorkyApp"]),
        .executable(name: "worky-cli", targets: ["WorkyCLI"]),
        .executable(name: "worky-click", targets: ["WorkyClick"]),
        .executable(name: "worky-screenshot", targets: ["WorkyScreenshot"])
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "WorkyApp",
            path: "Sources/WorkyApp"
        ),
        .executableTarget(
            name: "WorkyScreenshot",
            path: "Sources/WorkyScreenshot"
        ),
        .executableTarget(
            name: "WorkyClick",
            path: "Sources/WorkyClick"
        ),
        .executableTarget(
            name: "WorkyCLI",
            path: "Sources/WorkyCLI"
        ),
        .testTarget(
            name: "WorkyAppTests",
            dependencies: ["WorkyApp"],
            path: "Tests/WorkyAppTests"
        ),
    ]
)
