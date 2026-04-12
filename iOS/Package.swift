// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ReaderApp",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "ReaderApp", targets: ["ReaderApp"])
    ],
    dependencies: [
        .package(path: "../Core")
    ],
    targets: [
        .target(
            name: "ReaderApp",
            dependencies: [
                .product(name: "ReaderCoreFoundation", package: "Core"),
                .product(name: "ReaderCoreModels", package: "Core"),
                .product(name: "ReaderCoreProtocols", package: "Core"),
                .product(name: "ReaderCoreParser", package: "Core"),
                .product(name: "ReaderCoreNetwork", package: "Core")
            ],
            path: ".",
            sources: [
                "App",
                "CoreIntegration",
                "Features",
                "Modules",
                "Shell"
            ]
        ),
        .testTarget(
            name: "ShellSmokeTests",
            dependencies: ["ReaderApp"],
            path: "Tests/ShellSmokeTests"
        )
    ]
)
