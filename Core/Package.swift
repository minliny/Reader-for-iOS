// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ReaderCore",
    platforms: [
        .iOS(.v15),
        .macOS(.v13)
    ],
    products: [
        .library(name: "ReaderCoreFoundation", targets: ["ReaderCoreFoundation"]),
        .library(name: "ReaderCoreModels", targets: ["ReaderCoreModels"]),
        .library(name: "ReaderCoreProtocols", targets: ["ReaderCoreProtocols"]),
        .library(name: "ReaderCoreParser", targets: ["ReaderCoreParser"]),
        .library(name: "ReaderCoreNetwork", targets: ["ReaderCoreNetwork"]),
        .library(name: "ReaderCoreCache", targets: ["ReaderCoreCache"]),
        .executable(name: "FixtureTocRegressionCLI", targets: ["FixtureTocRegressionCLI"]),
        .executable(name: "Sample001NonJSSmokeRunner", targets: ["Sample001NonJSSmokeRunner"])
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
        )
    ]
)
