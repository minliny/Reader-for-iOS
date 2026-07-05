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

let shellCIOnly = ProcessInfo.processInfo.environment["READER_IOS_SHELL_CI"] == "1"
let shellCISwiftSettings: [SwiftSetting] = shellCIOnly ? [.define("READER_IOS_SHELL_CI")] : []
let parserBackedCoreDependencies: [Target.Dependency] = shellCIOnly ? [] : [
    .product(name: "ReaderCoreParser", package: "Reader-Core"),
    .product(name: "ReaderCoreNetwork", package: "Reader-Core"),
    .product(name: "ReaderCoreServices", package: "Reader-Core"),
    .product(name: "ReaderCoreAPI", package: "Reader-Core"),
    .product(name: "ReaderPlatformAdapters", package: "Reader-Core")
]
let shellValidationExcludes: [String] = shellCIOnly ? [
    "CoreIntegration/CoreLocalBookImportService.swift"
] : []
let shellSmokeTestExcludes: [String] = shellCIOnly ? [
    "RealServiceOfflineReplayTests.swift"
] : []

let readerShellValidationDependencies: [Target.Dependency] = [
    "ReaderAppSupport",
    "ReaderCoreNativeAdapter",
    .product(name: "ReaderCoreFoundation", package: "Reader-Core"),
    .product(name: "ReaderCoreModels", package: "Reader-Core"),
    .product(name: "ReaderCoreProtocols", package: "Reader-Core")
] + parserBackedCoreDependencies

let shellSmokeTestDependencies: [Target.Dependency] = [
    "ReaderShellValidation",
    "ReaderAppSupport",
    .product(name: "ReaderCoreModels", package: "Reader-Core"),
    .product(name: "ReaderCoreProtocols", package: "Reader-Core")
] + (shellCIOnly ? [] : [
    .product(name: "ReaderCoreParser", package: "Reader-Core"),
    .product(name: "ReaderCoreNetwork", package: "Reader-Core"),
    .product(name: "ReaderCoreServices", package: "Reader-Core")
])

let baseTargets: [Target] = [
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
            "RustCoreRuntimeHolder.swift"
        ]
    ),
    .target(
        name: "ReaderShellValidation",
        dependencies: readerShellValidationDependencies,
        path: ".",
        exclude: [
            "App",
            "AppSupport",
            "Features",
            "Modules",
            "Navigation",
            "Surface",
            "Tests",
        ] + shellValidationExcludes,
        sources: [
            "CoreIntegration",
            "CoreBridge",
            "Shell"
        ],
        swiftSettings: shellCISwiftSettings
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
            "ReaderAppPersistence",
            "ReaderCoreNativeAdapter"
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
        dependencies: shellSmokeTestDependencies,
        path: "Tests/ShellSmokeTests",
        exclude: shellSmokeTestExcludes,
        swiftSettings: shellCISwiftSettings
    )
]

let nonShellCITargets: [Target] = [
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

let packageTargets: [Target] = shellCIOnly ? baseTargets : baseTargets + nonShellCITargets

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
    targets: packageTargets
)
