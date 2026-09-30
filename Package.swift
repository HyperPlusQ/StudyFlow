// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StudyFlow",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "StudyFlowKit", targets: ["StudyFlowKit"]),
        .library(name: "StudyFlowWidgetShared", targets: ["StudyFlowWidgetShared"])
    ],
    targets: [
        .target(
            name: "StudyFlowWidgetShared",
            path: "Sources/StudyFlowWidgetShared"
        ),
        .target(
            name: "StudyFlowKit",
            dependencies: ["StudyFlowWidgetShared"],
            path: "Sources/StudyFlowKit"
        ),
        .testTarget(
            name: "StudyFlowKitTests",
            dependencies: ["StudyFlowKit"],
            path: "Tests/StudyFlowKitTests"
        )
    ]
)
