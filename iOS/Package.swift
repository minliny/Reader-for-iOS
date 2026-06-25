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
import Foundation

// Absolute path to the materialized C ABI directory (reader_core.h,
// module.modulemap, libreader_core.a). fetch-cabi.sh materializes the static
// lib here; headers are committed. Absolute path is required because SwiftPM
// linkerSettings unsafeFlags -L must resolve regardless of build cwd.
let packageCabiDir = URL(fileURLWithPath: #file)
    .deletingLastPathComponent()
    .appendingPathComponent("ReaderCoreNativeAdapter/cabi")
    .path

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
        // Rust Reader-Core-Native C ABI for macOS-host testing.
        // reader_core.h + module.modulemap live in cabi/ (committed); the macOS
        // libreader_core.a is materialized by fetch-cabi.sh (gitignored). The cabi
        // target is a header-only C target exposing module "ReaderCoreNative".
        // For iOS device/sim the xcframework path is a future round (blocked by
        // the pre-existing ReaderApp build break). See ReaderCoreNativeAdapter/README.md.
        .target(
            name: "ReaderCoreNative",
            path: "ReaderCoreNativeAdapter/cabi",
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath(".")
            ]
        ),
        .target(
            name: "ReaderCoreNativeAdapter",
            dependencies: [
                "ReaderCoreNative"
            ],
            path: "ReaderCoreNativeAdapter",
            exclude: [
                "cabi",
                "README.md",
                "STATUS.md",
                "fetch-cabi.sh",
                "ReaderCore.xcframework"
            ],
            sources: [
                "ReaderCoreNativeRuntime.swift"
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-L\(packageCabiDir)",
                    "-lreader_core"
                ])
            ]
        ),
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
            name: "ReaderCoreNativeAdapterSmokeTests",
            dependencies: [
                "ReaderCoreNativeAdapter"
            ],
            path: "Tests/ReaderCoreNativeAdapterSmokeTests"
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
