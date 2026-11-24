// swift-tools-version:5.9
// ComOffice for Apple platforms 1.14.0. Both products are binary targets: SwiftPM downloads
// them from this repository's Releases and verifies them by checksum.
import PackageDescription

let version = "1.14.0"
let base = "https://github.com/ComOfficeKit/ComOfficeKit-Apple/releases/download/\(version)"

let package = Package(
    name: "ComOfficeKit",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "DocumentCore", targets: ["DocumentCore"]),
        .library(name: "AppleRender", targets: ["AppleRender"]),
    ],
    targets: [
        .binaryTarget(name: "DocumentCore", url: "\(base)/DocumentCore.xcframework.zip", checksum: "f6265a190ac3e1ce09138c8de862636a20a4f3ad7ee61c4e2de923507b746175"),
        .binaryTarget(name: "AppleRender", url: "\(base)/AppleRender.xcframework.zip", checksum: "f945d50ff8c4ad228ab06e2ba7c3c1371170a0e930e0911656f708b43aad29fa"),
    ]
)
