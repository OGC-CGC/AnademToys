// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AnademToys",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AnademToys", targets: ["AnademToys"])
    ],
    targets: [
        .executableTarget(
            name: "AnademToys",
            path: "AnademToys"
        )
    ]
)
