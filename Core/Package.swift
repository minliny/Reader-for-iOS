// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ReaderCore",
    platforms: [
        .iOS(.v15),
        .macOS(.v13)
    ],
    dependencies: [
        .package(name: "ReaderPlatformAdapters", path: "../Adapters/HTTP")
    ],
    products: [
        .library(name: "ReaderCoreFoundation", targets: ["ReaderCoreFoundation"]),
        .library(name: "ReaderCoreModels", targets: ["ReaderCoreModels"]),
        .library(name: "ReaderCoreProtocols", targets: ["ReaderCoreProtocols"]),
        .library(name: "ReaderCoreParser", targets: ["ReaderCoreParser"]),
        .library(name: "ReaderCoreNetwork", targets: ["ReaderCoreNetwork"]),
        .library(name: "ReaderCoreCache", targets: ["ReaderCoreCache"]),
        .executable(name: "FixtureTocRegressionCLI", targets: ["FixtureTocRegressionCLI"]),
        .executable(name: "Sample001NonJSSmokeRunner", targets: ["Sample001NonJSSmokeRunner"]),
        .executable(name: "Sample002NonJSSmokeRunner", targets: ["Sample002NonJSSmokeRunner"]),
        .executable(name: "Sample003NonJSSmokeRunner", targets: ["Sample003NonJSSmokeRunner"]),
        .executable(name: "Sample004NonJSSmokeRunner", targets: ["Sample004NonJSSmokeRunner"]),
        .executable(name: "Sample005NonJSSmokeRunner", targets: ["Sample005NonJSSmokeRunner"]),
        .executable(name: "SampleCookie001FetchRunner", targets: ["SampleCookie001FetchRunner"]),
        .executable(name: "SampleCookie001IsolationRunner", targets: ["SampleCookie001IsolationRunner"]),
        .executable(name: "SampleCookie002FetchRunner", targets: ["SampleCookie002FetchRunner"]),
        .executable(name: "SampleCookie002IsolationRunner", targets: ["SampleCookie002IsolationRunner"]),
        .executable(name: "SampleLogin001FetchRunner", targets: ["SampleLogin001FetchRunner"]),
        .executable(name: "SampleLogin001IsolationRunner", targets: ["SampleLogin001IsolationRunner"]),
        .executable(name: "SampleLogin002FetchRunner", targets: ["SampleLogin002FetchRunner"]),
        .executable(name: "SampleLogin002IsolationRunner", targets: ["SampleLogin002IsolationRunner"]),
        .executable(name: "SampleLogin003FetchRunner", targets: ["SampleLogin003FetchRunner"]),
        .executable(name: "SampleLogin003IsolationRunner", targets: ["SampleLogin003IsolationRunner"]),
        .executable(name: "AutoSampleExtractorRunner", targets: ["AutoSampleExtractorRunner"]),
        .library(name: "ReaderCoreJSRenderer", targets: ["ReaderCoreJSRenderer"])
    ],
    targets: [
        .target(
            name: "ReaderCoreFoundation",
            dependencies: []
        ),
        .target(
            name: "ReaderCoreModels",
            dependencies: ["ReaderCoreFoundation"]
        ),
        .target(
            name: "ReaderCoreProtocols",
            dependencies: ["ReaderCoreModels"]
        ),
        .target(
            name: "ReaderCoreParser",
            dependencies: ["ReaderCoreModels", "ReaderCoreProtocols", "ReaderCoreFoundation"]
        ),
        .target(
            name: "ReaderCoreNetwork",
            dependencies: ["ReaderCoreModels", "ReaderCoreProtocols", "ReaderCoreFoundation"]
        ),
        .target(
            name: "ReaderCoreCache",
            dependencies: ["ReaderCoreModels", "ReaderCoreProtocols", "ReaderCoreFoundation"]
        ),
        .executableTarget(
            name: "FixtureTocRegressionCLI",
            dependencies: ["ReaderCoreParser"]
        ),
        .executableTarget(
            name: "Sample001NonJSSmokeRunner",
            dependencies: ["ReaderCoreModels", "ReaderCoreParser"]
        ),
        .executableTarget(
            name: "Sample002NonJSSmokeRunner",
            dependencies: ["ReaderCoreModels", "ReaderCoreParser"]
        ),
        .executableTarget(
            name: "Sample003NonJSSmokeRunner",
            dependencies: ["ReaderCoreModels", "ReaderCoreParser"]
        ),
        .executableTarget(
            name: "Sample004NonJSSmokeRunner",
            dependencies: ["ReaderCoreModels", "ReaderCoreParser"]
        ),
        .executableTarget(
            name: "Sample005NonJSSmokeRunner",
            dependencies: ["ReaderCoreModels", "ReaderCoreParser"]
        ),
        .executableTarget(
            name: "SampleCookie001FetchRunner",
            dependencies: ["ReaderCoreModels", "ReaderCoreNetwork", "ReaderCoreProtocols", .product(name: "ReaderPlatformAdapters", package: "ReaderPlatformAdapters")]
        ),
        .executableTarget(
            name: "SampleCookie001IsolationRunner",
            dependencies: ["ReaderCoreModels", "ReaderCoreNetwork", "ReaderCoreProtocols", .product(name: "ReaderPlatformAdapters", package: "ReaderPlatformAdapters")]
        ),
        .executableTarget(
            name: "SampleCookie002FetchRunner",
            dependencies: ["ReaderCoreModels", "ReaderCoreNetwork", "ReaderCoreProtocols", .product(name: "ReaderPlatformAdapters", package: "ReaderPlatformAdapters")]
        ),
        .executableTarget(
            name: "SampleCookie002IsolationRunner",
            dependencies: ["ReaderCoreModels", "ReaderCoreNetwork", "ReaderCoreProtocols", .product(name: "ReaderPlatformAdapters", package: "ReaderPlatformAdapters")]
        ),
        .executableTarget(
            name: "SampleLogin001FetchRunner",
            dependencies: ["ReaderCoreModels", "ReaderCoreNetwork", "ReaderCoreProtocols", .product(name: "ReaderPlatformAdapters", package: "ReaderPlatformAdapters")]
        ),
        .executableTarget(
            name: "SampleLogin001IsolationRunner",
            dependencies: ["ReaderCoreModels", "ReaderCoreNetwork", "ReaderCoreProtocols", .product(name: "ReaderPlatformAdapters", package: "ReaderPlatformAdapters")]
        ),
        .executableTarget(
            name: "SampleLogin002FetchRunner",
            dependencies: ["ReaderCoreModels", "ReaderCoreNetwork", "ReaderCoreProtocols", "ReaderCoreFoundation", .product(name: "ReaderPlatformAdapters", package: "ReaderPlatformAdapters")]
        ),
        .executableTarget(
            name: "SampleLogin002IsolationRunner",
            dependencies: ["ReaderCoreModels", "ReaderCoreNetwork", "ReaderCoreProtocols", "ReaderCoreFoundation", .product(name: "ReaderPlatformAdapters", package: "ReaderPlatformAdapters")]
        ),
        .executableTarget(
            name: "SampleLogin003FetchRunner",
            dependencies: ["ReaderCoreModels", "ReaderCoreNetwork", "ReaderCoreProtocols", "ReaderCoreFoundation", .product(name: "ReaderPlatformAdapters", package: "ReaderPlatformAdapters")]
        ),
        .executableTarget(
            name: "SampleLogin003IsolationRunner",
            dependencies: ["ReaderCoreModels", "ReaderCoreNetwork", "ReaderCoreProtocols", "ReaderCoreFoundation", .product(name: "ReaderPlatformAdapters", package: "ReaderPlatformAdapters")]
        ),
        .executableTarget(
            name: "AutoSampleExtractorRunner",
            dependencies: ["ReaderCoreModels", "ReaderCoreProtocols", .product(name: "ReaderPlatformAdapters", package: "ReaderPlatformAdapters")]
        ),
        .target(
            name: "ReaderCoreJSRenderer",
            dependencies: []
        ),
        .testTarget(
            name: "ReaderCoreModelsTests",
            dependencies: ["ReaderCoreModels"]
        ),
        .testTarget(
            name: "ReaderCoreParserTests",
            dependencies: ["ReaderCoreParser", "ReaderCoreModels"]
        ),
        .testTarget(
            name: "ReaderCoreNetworkTests",
            dependencies: ["ReaderCoreNetwork", "ReaderCoreModels", "ReaderCoreProtocols"]
        ),
        .testTarget(
            name: "ReaderCoreCacheTests",
            dependencies: ["ReaderCoreCache", "ReaderCoreModels", "ReaderCoreProtocols"]
        ),
        .testTarget(
            name: "ReaderPlatformAdaptersTests",
            dependencies: [.product(name: "ReaderPlatformAdapters", package: "ReaderPlatformAdapters"), "ReaderCoreParser", "ReaderCoreModels", "ReaderCoreProtocols"]
        ),
        .testTarget(
            name: "ReaderCoreJSRendererTests",
            dependencies: ["ReaderCoreJSRenderer"]
        )
    ]
)
