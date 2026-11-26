// swift-tools-version:5.9
// ComOffice for Apple platforms 1.16.0. Both products are binary targets: SwiftPM downloads
// them from this repository's Releases and verifies them by checksum.
import PackageDescription

let version = "1.16.0"
let base = "https://github.com/ComOfficeKit/ComOfficeKit-Apple/releases/download/\(version)"

let package = Package(
    name: "ComOfficeKit",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "DocumentCore", targets: ["DocumentCore"]),
        .library(name: "AppleRender", targets: ["AppleRender"]),
    ],
    targets: [
        .binaryTarget(name: "DocumentCore", url: "\(base)/DocumentCore.xcframework.zip", checksum: "8e1ab53ef8987a0c0ef59f2d8b47554662e89a737b2467b5e4fcabf349875eeb"),
        .binaryTarget(name: "AppleRender", url: "\(base)/AppleRender.xcframework.zip", checksum: "f6a3aa963ef46575eee4f82be604ad1fab380ec20bdb75627ed3af42670ba759"),
    ]
)
