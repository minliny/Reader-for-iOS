// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ReaderPlatformAdapters",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ReaderPlatformAdapters", targets: ["ReaderPlatformAdapters"])
    ],
    dependencies: [
        .package(name: "ReaderCore", path: "../../Core")
    ],
    targets: [
        .target(
            name: "ReaderPlatformAdapters",
            dependencies: [
                .product(name: "ReaderCoreProtocols", package: "ReaderCore"),
                .product(name: "ReaderCoreModels", package: "ReaderCore")
            ],
            path: "Sources/ReaderPlatformAdapters"
        )
    ]
)
