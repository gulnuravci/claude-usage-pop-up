// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeUsagePopup",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ClaudeUsagePopup",
            path: "Sources/ClaudeUsagePopup"
        )
    ]
)
