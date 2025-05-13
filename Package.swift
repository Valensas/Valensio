// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Valensio",
    platforms: [
        .iOS(.v15), .macOS(.v13), .watchOS(.v9), .tvOS(.v15), .driverKit(.v19), .visionOS(.v1)
    ],
    products: [
        .library(
            name: "Valensio",
            targets: ["Valensio"]),
    ],
    targets: [
        .target(
            name: "Valensio"
        ),
        .testTarget(
            name: "ValensioTests",
            dependencies: ["Valensio"],
            resources: [
                .copy("Resources/Sample File.txt")
            ]
        ),
    ],
    swiftLanguageModes: [.v5, .v6]
)
