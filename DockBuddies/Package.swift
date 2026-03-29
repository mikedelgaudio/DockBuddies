// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DockBuddies",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DockBuddies",
            path: "Sources/DockBuddies",
            resources: [.process("../../Resources")]
        ),
        .testTarget(
            name: "DockBuddiesTests",
            dependencies: ["DockBuddies"],
            path: "Tests/DockBuddiesTests"
        )
    ]
)
