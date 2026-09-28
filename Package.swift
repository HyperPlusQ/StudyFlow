// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StudyFlow",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "StudyFlow",
            path: "Sources/StudyFlow",
            resources: []
        )
    ]
)
