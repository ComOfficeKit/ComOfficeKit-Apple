// swift-tools-version:5.9
// ComOffice for Apple platforms 1.12.0. Both products are binary targets: SwiftPM downloads
// them from this repository's Releases and verifies them by checksum.
import PackageDescription

let version = "1.12.0"
let base = "https://github.com/ComOfficeKit/ComOfficeKit-Apple/releases/download/\(version)"

let package = Package(
    name: "ComOfficeKit",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "DocumentCore", targets: ["DocumentCore"]),
        .library(name: "AppleRender", targets: ["AppleRender"]),
    ],
    targets: [
        .binaryTarget(name: "DocumentCore", url: "\(base)/DocumentCore.xcframework.zip", checksum: "46087e12c9c6d51c2babf52ce5aa4fbacdb5722ec00fffc749b9bd071aeefec7"),
        .binaryTarget(name: "AppleRender", url: "\(base)/AppleRender.xcframework.zip", checksum: "b634c071e3e0d3ae980f4145cc15973c9d1a8e4f6e259c526b53d8f46f6cc110"),
    ]
)
