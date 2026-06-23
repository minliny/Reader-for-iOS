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
        .iOS(.v17),
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
                "ReaderAppSupport",
                .product(name: "ReaderCoreFoundation", package: "Reader-Core"),
                .product(name: "ReaderCoreModels", package: "Reader-Core"),
                .product(name: "ReaderCoreProtocols", package: "Reader-Core"),
                .product(name: "ReaderCoreParser", package: "Reader-Core"),
                .product(name: "ReaderCoreNetwork", package: "Reader-Core"),
                .product(name: "ReaderCoreServices", package: "Reader-Core"),
                .product(name: "ReaderCoreAPI", package: "Reader-Core"),
                .product(name: "ReaderPlatformAdapters", package: "Reader-Core")
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
            ],
            sources: [
                "CoreIntegration",
                "CoreBridge",
                "Shell"
            ]
        ),
        .target(
        name: "ReaderAppSupport",
        dependencies: [
            .product(name: "ReaderCoreModels", package: "Reader-Core")
        ],
        path: "AppSupport/Sources",
        sources: [
            "ReaderAppSupportMarker.swift",
            "ReaderDisplaySettings.swift",
            "ReadingProgress.swift",
            "ChapterCacheEntry.swift",
            "BookshelfItem.swift",
            "SourceIdentity.swift",
            "BookshelfItemFactory.swift"
        ]
    ),
        .target(
        name: "ReaderAppPersistence",
        dependencies: [
            "ReaderAppSupport",
            .product(name: "ReaderCoreModels", package: "Reader-Core")
        ],
        path: "App/Persistence"
    ),
        .target(
            name: "ReaderApp",
            dependencies: [
                "ReaderShellValidation",
                "ReaderAppSupport",
                "ReaderAppPersistence"
            ],
            path: ".",
            exclude: [
                "App/Persistence",
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
        .testTarget(
            name: "ShellSmokeTests",
            dependencies: [
                "ReaderShellValidation",
                "ReaderAppSupport",
                .product(name: "ReaderCoreModels", package: "Reader-Core"),
                .product(name: "ReaderCoreProtocols", package: "Reader-Core"),
                .product(name: "ReaderCoreParser", package: "Reader-Core"),
                .product(name: "ReaderCoreNetwork", package: "Reader-Core"),
                .product(name: "ReaderCoreServices", package: "Reader-Core")
            ],
            path: "Tests/ShellSmokeTests"
        ),
        .testTarget(
            name: "ReaderAppPersistenceTests",
            dependencies: [
                "ReaderAppPersistence",
                "ReaderAppSupport"
            ],
            path: "Tests/ReaderAppPersistenceTests"
        ),
        .executableTarget(
            name: "ReaderAppPersistenceTestRunner",
            dependencies: [
                "ReaderAppPersistence",
                "ReaderAppSupport"
            ],
            path: "Tests/ReaderAppPersistenceTestRunner"
        ),
        .testTarget(
            name: "ReaderAppTests",
            dependencies: [
                "ReaderApp",
                "ReaderAppSupport",
                "ReaderAppPersistence",
                "ReaderShellValidation",
                .product(name: "ReaderCoreModels", package: "Reader-Core")
            ],
            path: "Tests/ReaderAppTests"
        )
    ]
)
