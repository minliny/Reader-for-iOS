#!/bin/bash
set -e

# Fix ReaderFlowFunctionalValidationTests
sed -i.bak 's/searchService: DefaultSearchService(/readingFlowFacade: coreFacade,/' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowFunctionalValidationTests.swift
sed -i.bak '/facade: coreFacade/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowFunctionalValidationTests.swift
sed -i.bak '/tocService: DefaultTOCService(/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowFunctionalValidationTests.swift
sed -i.bak '/contentService: DefaultContentService(/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowFunctionalValidationTests.swift
sed -i.bak '/),/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowFunctionalValidationTests.swift
sed -i.bak 's/        readingFlowFacade: coreFacade/            readingFlowFacade: coreFacade,/' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowFunctionalValidationTests.swift

# Fix ReaderFlowHardeningTests
sed -i.bak 's/searchService: DefaultSearchService(/readingFlowFacade: coreFacade,/' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowHardeningTests.swift
sed -i.bak '/facade: coreFacade/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowHardeningTests.swift
sed -i.bak '/tocService: DefaultTOCService(/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowHardeningTests.swift
sed -i.bak '/contentService: DefaultContentService(/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowHardeningTests.swift
sed -i.bak '/),/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowHardeningTests.swift
sed -i.bak 's/        readingFlowFacade: coreFacade/            readingFlowFacade: coreFacade,/' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowHardeningTests.swift

