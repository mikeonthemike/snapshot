// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Snapshot",
    platforms: [.macOS("15.0")],
    targets: [
        .executableTarget(
            name: "Snapshot",
            path: "Sources/Snapshot",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "SnapshotTests",
            dependencies: ["Snapshot"],
            path: "Tests/SnapshotTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
