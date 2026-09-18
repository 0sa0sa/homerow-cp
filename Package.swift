// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HomerowCP",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "HomerowCPCore", path: "Sources/HomerowCPCore"),
        .target(
            name: "HomerowCPAccessibility",
            dependencies: ["HomerowCPCore"],
            path: "Sources/HomerowCPAccessibility"
        ),
        .target(
            name: "HomerowCPUI",
            dependencies: ["HomerowCPCore"],
            path: "Sources/HomerowCPUI"
        ),
        .executableTarget(
            name: "HomerowCPApp",
            dependencies: ["HomerowCPCore", "HomerowCPAccessibility", "HomerowCPUI"],
            path: "Sources/HomerowCPApp"
        ),
        .testTarget(
            name: "HomerowCPCoreTests",
            dependencies: ["HomerowCPCore"],
            path: "Tests/HomerowCPCoreTests"
        ),
    ]
)
