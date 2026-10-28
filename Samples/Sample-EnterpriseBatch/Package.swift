// swift-tools-version:5.9
// The batch-pipeline shape: a headless command that converts and extracts.
// Consumes the SDK as a licensee does — binary only. The frameworks are
// expected at ../../XCFrameworks, which is where the delivery bundle keeps them.
import PackageDescription
let package = Package(
    name: "Sample-EnterpriseBatch",
    platforms: [.macOS(.v13)],
    targets: [
        .binaryTarget(name: "DocumentCore", path: "../../XCFrameworks/DocumentCore.xcframework"),
        .binaryTarget(name: "AppleRender", path: "../../XCFrameworks/AppleRender.xcframework"),
        .executableTarget(name: "batch", dependencies: ["DocumentCore", "AppleRender"], path: "Sources"),
    ]
)
