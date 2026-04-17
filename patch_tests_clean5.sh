#!/bin/bash
set -e

sed -i.bak 's/bookSourceDecoder: DefaultBookSourceDecoder(),/bookSourceDecoder: DefaultBookSourceDecoder(),\
            readingFlowFacade: coreFacade,/' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowFunctionalValidationTests.swift

sed -i.bak 's/bookSourceDecoder: DefaultBookSourceDecoder(),/bookSourceDecoder: DefaultBookSourceDecoder(),\
            readingFlowFacade: coreFacade,/' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowHardeningTests.swift

