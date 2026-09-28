// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StudyFlow",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "StudyFlowKit", targets: ["StudyFlowKit"]),
        .executable(name: "StudyFlow", targets: ["StudyFlowMacOS"])
    ],
    targets: [
        .target(
            name: "StudyFlowKit",
            path: "Sources/StudyFlowKit"
        ),
        .executableTarget(
            name: "StudyFlowMacOS",
            dependencies: ["StudyFlowKit"],
            path: "Sources/StudyFlowMacOS"
        ),
        .testTarget(
            name: "StudyFlowKitTests",
            dependencies: ["StudyFlowKit"],
            path: "Tests/StudyFlowKitTests"
        )
    ]
)
