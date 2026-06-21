// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuickNotes",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey.git", from: "0.2.1"),
    ],
    targets: [
        .executableTarget(
            name: "QuickNotes",
            dependencies: ["HotKey"],
            path: "Sources/QuickNotes"
        ),
    ]
)
