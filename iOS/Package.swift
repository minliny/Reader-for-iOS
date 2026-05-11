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
                .product(name: "ReaderPlatformAdapters", package: "Reader-Core"),
                "ReaderIOSPlatformAdapters"
            ],
            path: ".",
            exclude: [
                "App",
                "AppSupport",
                "Features",
                "Modules",
                "Navigation",
                "Surface",
                "Tests",
                "PlatformAdapters"
            ],
            sources: [
                "CoreIntegration",
                "CoreBridge",
                "Shell"
            ]
        ),
        .target(
        name: "ReaderAppSupport",
        dependencies: [],
        path: "AppSupport/Sources",
        sources: [
            "ReaderAppSupportMarker.swift",
            "ReaderDisplaySettings.swift",
            "ReadingProgress.swift"
        ]
    ),
        .target(
            name: "ReaderApp",
            dependencies: [
                "ReaderShellValidation",
                "ReaderAppSupport"
            ],
            path: ".",
            exclude: [
                "AppSupport",
                "CoreIntegration",
                "CoreBridge",
                "Shell",
                "Tests",
            ],
            sources: [
                "App",
                "Features",
                "Modules",
                "Navigation",
                "Surface"
            ]
        ),
        .target(
            name: "ReaderIOSPlatformAdapters",
            dependencies: [],
            path: "PlatformAdapters",
            sources: [
                "IOSHTTPAdapter.swift",
                "IOSStorageAdapter.swift",
                "IOSKeychainCredentialStore.swift",
                "IOSLoggerAdapter.swift",
                "IOSSnapshotStore.swift"
            ]
        ),
        .testTarget(
            name: "ShellSmokeTests",
            dependencies: [
                "ReaderShellValidation",
                "ReaderAppSupport",
                .product(name: "ReaderCoreModels", package: "Reader-Core"),
                .product(name: "ReaderCoreProtocols", package: "Reader-Core")
            ],
            path: "Tests/ShellSmokeTests"
        ),
        .testTarget(
            name: "PlatformAdapterTests",
            dependencies: [
                "ReaderIOSPlatformAdapters"
            ],
            path: "Tests/PlatformAdapterTests"
        ),
        .testTarget(
            name: "LinuxValidationTests",
            dependencies: [
                "ReaderShellValidation",
                "ReaderIOSPlatformAdapters",
                "ReaderAppSupport",
                .product(name: "ReaderCoreModels", package: "Reader-Core"),
                .product(name: "ReaderCoreProtocols", package: "Reader-Core")
            ],
            path: "Tests/LinuxValidationTests"
        )
    ]
)
