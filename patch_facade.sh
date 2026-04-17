#!/bin/bash
set -e

sed -i.bak '/.library(name: "ReaderCoreParser",       targets: \["ReaderCoreParser"\]),/a\
        .library(name: "ReaderCoreFacade",       targets: ["ReaderCoreFacade"]),\
' /workspace/Reader-Core/Package.swift

sed -i.bak '/.target(/i\
        .target(\
            name: "ReaderCoreFacade",\
            dependencies: ["ReaderCoreNetwork", "ReaderCoreParser", "ReaderCoreProtocols", "ReaderCoreModels"],\
            path: "Core/Sources/ReaderCoreFacade"\
        ),\
' /workspace/Reader-Core/Package.swift
