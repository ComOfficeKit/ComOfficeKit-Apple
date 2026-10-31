// swift-tools-version:5.9
// ComOfficeKit 1.3.0. Both products are binary targets: SwiftPM downloads
// them from this repository's Releases and verifies them by checksum.
import PackageDescription

let version = "1.3.0"
let base = "https://github.com/ComOfficeKit/ComOfficeKit-Apple/releases/download/\(version)"

let package = Package(
    name: "ComOfficeKit",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "DocumentCore", targets: ["DocumentCore"]),
        .library(name: "AppleRender", targets: ["AppleRender"]),
    ],
    targets: [
        .binaryTarget(name: "DocumentCore", url: "\(base)/DocumentCore.xcframework.zip", checksum: "ed0affc1332f6d46f94120d9e183043d4a1f78c81e8caba03eca00c8d1189500"),
        .binaryTarget(name: "AppleRender", url: "\(base)/AppleRender.xcframework.zip", checksum: "40e2cd4698b57b265c01abe3343b32722a7973b160a601c1b471d1913768245e"),
    ]
)
