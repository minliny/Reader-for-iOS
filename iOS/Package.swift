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
                .product(name: "ReaderCoreFoundation", package: "ReaderCore"),
                .product(name: "ReaderCoreModels", package: "ReaderCore"),
                .product(name: "ReaderCoreProtocols", package: "ReaderCore"),
                .product(name: "ReaderCoreParser", package: "ReaderCore"),
                .product(name: "ReaderCoreNetwork", package: "ReaderCore")
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
