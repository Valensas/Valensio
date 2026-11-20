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
    dependencies: [
        // Test-only: an embedded HTTP server used to stub httpbin endpoints.
        // Not referenced by the `Valensio` library target, so it is never
        // resolved or built for downstream consumers of the package.
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "Valensio"
        ),
        .testTarget(
            name: "ValensioTests",
            dependencies: [
                "Valensio",
                .product(name: "Hummingbird", package: "hummingbird"),
            ],
            resources: [
                .copy("Resources/Sample File.txt")
            ]
        ),
    ],
    swiftLanguageModes: [.v5, .v6]
)
