// swift-tools-version:5.9
// The cookbook: every code sample in docs/ lives here as a function and is
// compiled against the release frameworks, so a sample that no longer builds
// fails `swift build` instead of misleading a reader. The frameworks are
// expected at ../../XCFrameworks, which is where the delivery bundle keeps them.
import PackageDescription
let package = Package(
    name: "Sample-Cookbook",
    platforms: [.macOS(.v13)],
    targets: [
        .binaryTarget(name: "DocumentCore", path: "../../XCFrameworks/DocumentCore.xcframework"),
        .binaryTarget(name: "AppleRender", path: "../../XCFrameworks/AppleRender.xcframework"),
        .executableTarget(name: "cookbook", dependencies: ["DocumentCore", "AppleRender"], path: "Sources"),
    ]
)
