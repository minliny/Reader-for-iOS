// swift-tools-version: 5.9
// Root-level Package.swift for Reader-Core (minliny/Reader-for-iOS).
// This manifest enables SwiftPM URL-based dependency resolution from Reader-iOS.
// Sources live in Core/Sources/**; the internal Core/Package.swift remains authoritative
// for local development and Core-internal CI.
//
// Public products exposed to Reader-iOS:
//   ReaderCoreFoundation, ReaderCoreModels, ReaderCoreProtocols,
//   ReaderCoreParser, ReaderCoreNetwork, ReaderPlatformAdapters,
//   ReaderCoreCache, ReaderCoreJSRenderer
//
// Core frozen contract is NOT modified by this file.
import PackageDescription

let package = Package(
    name: "ReaderCore",
    platforms: [
        .iOS(.v15),
        .macOS(.v13)
    ],
    products: [
        // Public products — available to Reader-iOS and any downstream consumer
        .library(name: "ReaderCoreFoundation",  targets: ["ReaderCoreFoundation"]),
        .library(name: "ReaderCoreModels",       targets: ["ReaderCoreModels"]),
        .library(name: "ReaderCoreProtocols",    targets: ["ReaderCoreProtocols"]),
        .library(name: "ReaderCoreParser",       targets: ["ReaderCoreParser"]),
        .library(name: "ReaderCoreNetwork",      targets: ["ReaderCoreNetwork"]),
        .library(name: "ReaderCoreCache",        targets: ["ReaderCoreCache"]),
        .library(name: "ReaderCoreJSRenderer",   targets: ["ReaderCoreJSRenderer"]),
        .library(name: "ReaderPlatformAdapters", targets: ["ReaderPlatformAdapters"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ReaderCoreFoundation",
            dependencies: [],
            path: "Core/Sources/ReaderCoreFoundation"
        ),
        .target(
            name: "ReaderCoreModels",
            dependencies: ["ReaderCoreFoundation"],
            path: "Core/Sources/ReaderCoreModels"
        ),
        .target(
            name: "ReaderCoreProtocols",
            dependencies: ["ReaderCoreModels"],
            path: "Core/Sources/ReaderCoreProtocols"
        ),
        .target(
            name: "ReaderCoreParser",
            dependencies: ["ReaderCoreModels", "ReaderCoreProtocols", "ReaderCoreFoundation"],
            path: "Core/Sources/ReaderCoreParser"
        ),
        .target(
            name: "ReaderCoreNetwork",
            dependencies: ["ReaderCoreModels", "ReaderCoreProtocols", "ReaderCoreFoundation"],
            path: "Core/Sources/ReaderCoreNetwork"
        ),
        .target(
            name: "ReaderCoreCache",
            dependencies: ["ReaderCoreModels", "ReaderCoreProtocols", "ReaderCoreFoundation"],
            path: "Core/Sources/ReaderCoreCache"
        ),
        .target(
            name: "ReaderCoreJSRenderer",
            dependencies: ["ReaderCoreParser", "ReaderCoreProtocols"],
            path: "Core/Sources/ReaderCoreJSRenderer"
        ),
        .target(
            name: "ReaderPlatformAdapters",
            dependencies: ["ReaderCoreProtocols", "ReaderCoreModels"],
            path: "Core/Sources/ReaderPlatformAdapters"
        )
    ]
)
