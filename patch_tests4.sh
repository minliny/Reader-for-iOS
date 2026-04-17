#!/bin/bash
set -e

# Fix ReaderFlowFunctionalValidationTests
sed -i.bak '/searchService: DefaultSearchService(/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowFunctionalValidationTests.swift
sed -i.bak '/facade: coreFacade/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowFunctionalValidationTests.swift
sed -i.bak '/tocService: DefaultTOCService(/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowFunctionalValidationTests.swift
sed -i.bak '/contentService: DefaultContentService(/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowFunctionalValidationTests.swift
sed -i.bak '/),/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowFunctionalValidationTests.swift
sed -i.bak 's/        let coreFacade = ReaderFlowCoreFacade(httpClient: httpClient)/        let coreFacade = ReaderFlowCoreFacade(httpClient: httpClient)\
\
        return ReadingFlowCoordinator(\
            bookSourceRepository: InMemoryBookSourceRepository(),\
            bookSourceDecoder: DefaultBookSourceDecoder(),\
            readingFlowFacade: coreFacade,\
            errorLogger: InMemoryErrorLogger()\
        )/' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowFunctionalValidationTests.swift

# Fix ReaderFlowHardeningTests
sed -i.bak '/searchService: DefaultSearchService(/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowHardeningTests.swift
sed -i.bak '/facade: coreFacade/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowHardeningTests.swift
sed -i.bak '/tocService: DefaultTOCService(/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowHardeningTests.swift
sed -i.bak '/contentService: DefaultContentService(/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowHardeningTests.swift
sed -i.bak '/),/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowHardeningTests.swift
sed -i.bak 's/        let coreFacade = ReaderFlowCoreFacade(httpClient: httpClient)/        let coreFacade = ReaderFlowCoreFacade(httpClient: httpClient)\
\
        return ReadingFlowCoordinator(\
            bookSourceRepository: InMemoryBookSourceRepository(),\
            bookSourceDecoder: DefaultBookSourceDecoder(),\
            readingFlowFacade: coreFacade,\
            errorLogger: InMemoryErrorLogger()\
        )/' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowHardeningTests.swift

