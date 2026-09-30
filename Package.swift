// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacVoiceType",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "MacVoiceType",
            targets: ["MacVoiceType"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MacVoiceType",
            dependencies: [],
            path: "Sources/MacVoiceType"
        )
    ]
)
