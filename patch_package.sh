#!/bin/bash
set -e
cat << 'PKG_EOF' > /workspace/Reader-Core/Package.swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ReaderCore",
    platforms: [
        .iOS(.v15),
        .macOS(.v13)
    ],
    products: [
        .library(name: "ReaderCoreFoundation",  targets: ["ReaderCoreFoundation"]),
        .library(name: "ReaderCoreModels",       targets: ["ReaderCoreModels"]),
        .library(name: "ReaderCoreProtocols",    targets: ["ReaderCoreProtocols"]),
        .library(name: "ReaderCoreParser",       targets: ["ReaderCoreParser"]),
        .library(name: "ReaderCoreFacade",       targets: ["ReaderCoreFacade"]),
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
            name: "ReaderCoreFacade",
            dependencies: ["ReaderCoreNetwork", "ReaderCoreParser", "ReaderCoreProtocols", "ReaderCoreModels"],
            path: "Core/Sources/ReaderCoreFacade"
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
PKG_EOF
