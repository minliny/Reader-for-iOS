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
        .package(path: "../Reader-Core"),
        // Reader UI Contract（Contract-first Native UI Architecture）
        // 提供 generated Swift 类型：RouteId / UiEvent / UiState / ViewState / Motion / Token /
        // CoreCommand / CoreEvent / HostRequest / ProgressLocation / Content / SyncConflict / StateRule
        // 接入路径：Reader for iOS/iOS/Package.swift -> ../../Reader UI
        .package(path: "../../Reader UI")
    ],
    targets: [
        // Rust Reader-Core-Native C ABI as a merged xcframework binaryTarget.
        // fetch-cabi.sh --xcframework builds ReaderCore.xcframework (macOS +
        // iOS-sim slices, gitignored) from Native's libreader_core.a. A binaryTarget
        // lets a single SwiftPM/xcodebuild configuration link the correct slice per
        // platform without platform-conditional linkerSettings. The module name is
        // `ReaderCore` (from the in-xcframework module.modulemap). Run
        // `bash iOS/ReaderCoreNativeAdapter/fetch-cabi.sh --xcframework` first.
        .binaryTarget(
            name: "ReaderCoreNative",
            path: "ReaderCoreNativeAdapter/cabi/ReaderCore.xcframework"
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
                "run-shell-smoke.sh",
                "run-sim-smoke.sh",
                "ShellSmokeTests",
                "sim-smoke-report.txt"
            ],
            sources: [
                "ReaderCoreNativeRuntime.swift",
                "ReaderCoreNativeEvidenceRunner.swift",
                "RustCoreRuntimeHolder.swift",
                "UnifiedEvidenceArtifact.swift"
            ]
        ),
        .target(
            name: "ReaderShellValidation",
            dependencies: [
                "ReaderAppSupport",
                "ReaderCoreNativeAdapter",
                .product(name: "ReaderCoreFoundation", package: "Reader-Core"),
                .product(name: "ReaderCoreModels", package: "Reader-Core"),
                .product(name: "ReaderCoreProtocols", package: "Reader-Core"),
                .product(name: "ReaderCoreParser", package: "Reader-Core"),
                .product(name: "ReaderCoreNetwork", package: "Reader-Core"),
                .product(name: "ReaderCoreServices", package: "Reader-Core"),
                .product(name: "ReaderCoreAPI", package: "Reader-Core"),
                .product(name: "ReaderPlatformAdapters", package: "Reader-Core"),
                .product(name: "ReaderUIContract", package: "Reader UI")
            ],
            path: ".",
            exclude: [
                "App",
                "AppSupport",
                "build",
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
        exclude: [
            "sample_book_source.json",
            "xingxingxsw.search-only.json"
        ],
        sources: [
            "ReaderAppSupportMarker.swift",
            "ReaderDisplaySettings.swift",
            "ReadingProgress.swift",
            "ChapterCacheEntry.swift",
            "BookshelfItem.swift",
            "DemoBookshelfFixture.swift",
            "DemoReaderFixture.swift",
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
            "ReaderAppPersistence",
            "ReaderCoreNativeAdapter",
            .product(name: "ReaderUIContract", package: "Reader UI")
        ],
            path: ".",
            exclude: [
                "App/Persistence",
                "App/Resources",
                "AppSupport",
                "build",
                "CoreIntegration",
                "CoreBridge",
                "Shell",
                "Modules/Assets/ReaderIcons.xcassets",
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
            .product(name: "ReaderCoreModels", package: "Reader-Core"),
            .product(name: "ReaderUIContract", package: "Reader UI")
        ],
        path: "Tests/ReaderAppTests"
    )
    ]
)
