// swift-tools-version:5.9
// The "viewer app gaining Office tabs" shape: a SwiftUI document viewer that
// renders pages through the SDK. Binary only — frameworks from ../../XCFrameworks.
import PackageDescription
let package = Package(
    name: "Sample-EmbedInApp",
    platforms: [.macOS(.v13)],
    targets: [
        .binaryTarget(name: "DocumentCore", path: "../../XCFrameworks/DocumentCore.xcframework"),
        .binaryTarget(name: "AppleRender", path: "../../XCFrameworks/AppleRender.xcframework"),
        .executableTarget(name: "EmbedInApp", dependencies: ["DocumentCore", "AppleRender"], path: "Sources"),
    ]
)
