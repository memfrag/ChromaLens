// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ColorVisionKit",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "ColorVisionKit", targets: ["ColorVisionKit"])
    ],
    targets: [
        .target(name: "ColorVisionKit", dependencies: []),
        .testTarget(name: "ColorVisionKitTests", dependencies: ["ColorVisionKit"])
    ]
)
