// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "StudioController",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "StudioController", targets: ["StudioController"]),
    ],
    targets: [
        .executableTarget(
            name: "StudioController",
            linkerSettings: [
                .linkedFramework("IOBluetooth"),
            ]
        ),
    ]
)
