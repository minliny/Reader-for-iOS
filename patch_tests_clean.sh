#!/bin/bash
set -e

# Fix ReaderFlowFunctionalValidationTests
sed -i.bak '/searchService: DefaultSearchService(/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowFunctionalValidationTests.swift
sed -i.bak '/tocService: DefaultTOCService(/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowFunctionalValidationTests.swift
sed -i.bak '/contentService: DefaultContentService(/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowFunctionalValidationTests.swift
sed -i.bak 's/facade: coreFacade,//' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowFunctionalValidationTests.swift
sed -i.bak 's/readingFlowFacade: coreFacade,/readingFlowFacade: coreFacade/' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowFunctionalValidationTests.swift
sed -i.bak '/errorLogger: InMemoryErrorLogger()/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowFunctionalValidationTests.swift
sed -i.bak 's/readingFlowFacade: coreFacade/readingFlowFacade: coreFacade,\
            errorLogger: InMemoryErrorLogger()/' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowFunctionalValidationTests.swift

# Fix ReaderFlowHardeningTests
sed -i.bak '/searchService: DefaultSearchService(/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowHardeningTests.swift
sed -i.bak '/tocService: DefaultTOCService(/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowHardeningTests.swift
sed -i.bak '/contentService: DefaultContentService(/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowHardeningTests.swift
sed -i.bak 's/facade: coreFacade,//' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowHardeningTests.swift
sed -i.bak 's/readingFlowFacade: coreFacade,/readingFlowFacade: coreFacade/' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowHardeningTests.swift
sed -i.bak '/errorLogger: InMemoryErrorLogger()/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowHardeningTests.swift
sed -i.bak 's/readingFlowFacade: coreFacade/readingFlowFacade: coreFacade,\
            errorLogger: InMemoryErrorLogger()/' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowHardeningTests.swift

