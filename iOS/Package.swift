// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ReaderApp",
    platforms: [
        .iOS(.v15),
        .macOS(.v13)
    ],
    products: [
        .library(name: "ReaderApp", targets: ["ReaderApp"])
    ],
    dependencies: [
        .package(path: "../Core")
    ],
    targets: [
        .target(
            name: "ReaderShellValidation",
            dependencies: [
                .product(name: "ReaderCoreFoundation", package: "Core"),
                .product(name: "ReaderCoreModels", package: "Core"),
                .product(name: "ReaderCoreProtocols", package: "Core"),
                .product(name: "ReaderCoreParser", package: "Core"),
                .product(name: "ReaderCoreNetwork", package: "Core")
            ],
            path: ".",
            exclude: [
                "App",
                "Features",
                "Modules",
                "Tests",
                "Shell/ReaderShellEnvironment.swift"
            ],
            sources: [
                "CoreIntegration",
                "Shell"
            ]
        ),
        .target(
            name: "ReaderApp",
            dependencies: [
                "ReaderShellValidation",
                .product(name: "ReaderCoreModels", package: "Core")
            ],
            path: ".",
            exclude: [
                "CoreIntegration",
                "Shell",
                "Tests",
            ],
            sources: [
                "App",
                "Features",
                "Modules"
            ]
        ),
        .testTarget(
            name: "ShellSmokeTests",
            dependencies: ["ReaderShellValidation"],
            path: "Tests/ShellSmokeTests"
        )
    ]
)
