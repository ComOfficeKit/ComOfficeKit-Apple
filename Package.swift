// swift-tools-version:5.9
// ComOffice for Apple platforms 1.15.0. Both products are binary targets: SwiftPM downloads
// them from this repository's Releases and verifies them by checksum.
import PackageDescription

let version = "1.15.0"
let base = "https://github.com/ComOfficeKit/ComOfficeKit-Apple/releases/download/\(version)"

let package = Package(
    name: "ComOfficeKit",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "DocumentCore", targets: ["DocumentCore"]),
        .library(name: "AppleRender", targets: ["AppleRender"]),
    ],
    targets: [
        .binaryTarget(name: "DocumentCore", url: "\(base)/DocumentCore.xcframework.zip", checksum: "bd431cc9898e74c5d4c94bbc0474c1c91c80dd80cef77463082717f4fd97eb6e"),
        .binaryTarget(name: "AppleRender", url: "\(base)/AppleRender.xcframework.zip", checksum: "4c4ac7bbc8de5da73f5ae85d002f191e9e1c1230c66045d972ce692cf45fc63a"),
    ]
)
