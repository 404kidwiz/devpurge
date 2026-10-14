// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DevPurgeApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DevPurge", targets: ["DevPurge"])
    ],
    targets: [
        .executableTarget(
            name: "DevPurge",
            path: "Sources/DevPurge"
        ),
        .testTarget(
            name: "DevPurgeTests",
            dependencies: ["DevPurge"],
            path: "Tests/DevPurgeTests"
        )
    ]
)
