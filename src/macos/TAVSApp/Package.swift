// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TAVSApp",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "TAVSApp",
            path: "Sources/TAVSApp",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "TAVSAppTests",
            dependencies: ["TAVSApp"],
            path: "Tests/TAVSAppTests",
            resources: [
                .copy("Fixtures")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
