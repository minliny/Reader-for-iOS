// swift-tools-version: 5.9
// Reverse Split Dependency Patch (2026-04-14):
// Reader-iOS now depends on the independent Reader-Core repo.
//
// Local dev: .package(path: "../Reader-Core")
//   Requires Reader-Core checked out as sibling: ../Reader-Core
//
// Canonical (CI / remote): .package(url: "https://github.com/minliny/Reader-Core.git", exact: "0.1.0")
//   Switch to URL-based dependency once Reader-Core remote is stable as primary.
//
// Reader-iOS MUST only depend on Reader-Core public products.
// Direct source imports from Core/Sources/** are FORBIDDEN.
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
        // Local dev: Reader-Core sibling checkout
        .package(path: "../Reader-Core")
    ],
    targets: [
        .target(
            name: "ReaderShellValidation",
            dependencies: [
                .product(name: "ReaderCoreFoundation", package: "Reader-Core"),
                .product(name: "ReaderCoreModels", package: "Reader-Core"),
                .product(name: "ReaderCoreProtocols", package: "Reader-Core"),
                .product(name: "ReaderCoreParser", package: "Reader-Core"),
                .product(name: "ReaderCoreNetwork", package: "Reader-Core"),
                .product(name: "ReaderCoreFacade", package: "Reader-Core"),
                .product(name: "ReaderPlatformAdapters", package: "Reader-Core")
            ],
            path: ".",
            exclude: [
                "App",
                "Features",
                "Modules",
                "Shell",
                "Navigation",
                "Surface",
                "Tests",
            ],
            sources: [
                "CoreIntegration",
                "ValidationSupport"
            ]
        ),
        .target(
            name: "ReaderApp",
            dependencies: [
                "ReaderShellValidation",
                .product(name: "ReaderCoreModels", package: "Reader-Core"),
                .product(name: "ReaderCoreProtocols", package: "Reader-Core"),
                .product(name: "ReaderCoreParser", package: "Reader-Core"),
                .product(name: "ReaderCoreNetwork", package: "Reader-Core"),
                .product(name: "ReaderCoreFacade", package: "Reader-Core"),
                .product(name: "ReaderPlatformAdapters", package: "Reader-Core")
            ],
            path: ".",
            exclude: [
                "CoreIntegration",
                "Tests",
            ],
            sources: [
                "App",
                "Features",
                "Shell",
                "Modules",
                "Navigation",
                "Surface"
            ]
        ),
        .testTarget(
            name: "ShellSmokeTests",
            dependencies: [
                "ReaderShellValidation",
                .product(name: "ReaderCoreModels", package: "Reader-Core"),
                .product(name: "ReaderCoreProtocols", package: "Reader-Core"),
                .product(name: "ReaderCoreParser", package: "Reader-Core"),
                .product(name: "ReaderCoreNetwork", package: "Reader-Core"),
                .product(name: "ReaderCoreFacade", package: "Reader-Core")
            ],
            path: "Tests/ShellSmokeTests"
        )
    ]
)
