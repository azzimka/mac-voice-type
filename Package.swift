// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Froggy",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Froggy",
            targets: ["Froggy"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Froggy",
            dependencies: [],
            path: "Sources/Froggy",
            resources: [
                .copy("../../Resources/AppIcon.jpg")
            ]
        )
    ]
)
