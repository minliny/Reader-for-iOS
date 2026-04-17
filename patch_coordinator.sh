#!/bin/bash
set -e

# Patch ReadingFlowCoordinator.swift
sed -i.bak 's/public let searchService: SearchService/public let readingFlowFacade: ReadingFlowFacade/' /workspace/iOS/CoreIntegration/ReadingFlowCoordinator.swift
sed -i.bak '/public let tocService: TOCService/d' /workspace/iOS/CoreIntegration/ReadingFlowCoordinator.swift
sed -i.bak '/public let contentService: ContentService/d' /workspace/iOS/CoreIntegration/ReadingFlowCoordinator.swift

sed -i.bak 's/searchService: SearchService,/readingFlowFacade: ReadingFlowFacade,/' /workspace/iOS/CoreIntegration/ReadingFlowCoordinator.swift
sed -i.bak '/tocService: TOCService,/d' /workspace/iOS/CoreIntegration/ReadingFlowCoordinator.swift
sed -i.bak '/contentService: ContentService,/d' /workspace/iOS/CoreIntegration/ReadingFlowCoordinator.swift

sed -i.bak 's/self.searchService = searchService/self.readingFlowFacade = readingFlowFacade/' /workspace/iOS/CoreIntegration/ReadingFlowCoordinator.swift
sed -i.bak '/self.tocService = tocService/d' /workspace/iOS/CoreIntegration/ReadingFlowCoordinator.swift
sed -i.bak '/self.contentService = contentService/d' /workspace/iOS/CoreIntegration/ReadingFlowCoordinator.swift

sed -i.bak 's/try await searchService.search/try await readingFlowFacade.search/' /workspace/iOS/CoreIntegration/ReadingFlowCoordinator.swift
sed -i.bak 's/try await tocService.fetchTOC/try await readingFlowFacade.fetchTOC/' /workspace/iOS/CoreIntegration/ReadingFlowCoordinator.swift
sed -i.bak 's/try await contentService.fetchContent/try await readingFlowFacade.fetchContent/' /workspace/iOS/CoreIntegration/ReadingFlowCoordinator.swift

# Patch iOS/ValidationSupport/ShellAssembly.swift
sed -i.bak 's/searchService: DefaultSearchService(facade: coreFacade),/readingFlowFacade: coreFacade,/' /workspace/iOS/ValidationSupport/ShellAssembly.swift
sed -i.bak '/tocService: DefaultTOCService(facade: coreFacade),/d' /workspace/iOS/ValidationSupport/ShellAssembly.swift
sed -i.bak '/contentService: DefaultContentService(facade: coreFacade),/d' /workspace/iOS/ValidationSupport/ShellAssembly.swift

# Patch iOS/Tests/ShellSmokeTests/ReaderFlowFunctionalValidationTests.swift
sed -i.bak 's/searchService: DefaultSearchService(/readingFlowFacade: coreFacade,/' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowFunctionalValidationTests.swift
sed -i.bak '/facade: coreFacade/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowFunctionalValidationTests.swift
sed -i.bak '/tocService: DefaultTOCService(/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowFunctionalValidationTests.swift
sed -i.bak '/contentService: DefaultContentService(/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowFunctionalValidationTests.swift
sed -i.bak '/),/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowFunctionalValidationTests.swift
sed -i.bak 's/        readingFlowFacade: coreFacade/            readingFlowFacade: coreFacade,/' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowFunctionalValidationTests.swift

# Patch iOS/Tests/ShellSmokeTests/ReaderFlowHardeningTests.swift
sed -i.bak 's/searchService: DefaultSearchService(/readingFlowFacade: coreFacade,/' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowHardeningTests.swift
sed -i.bak '/facade: coreFacade/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowHardeningTests.swift
sed -i.bak '/tocService: DefaultTOCService(/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowHardeningTests.swift
sed -i.bak '/contentService: DefaultContentService(/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowHardeningTests.swift
sed -i.bak '/),/d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowHardeningTests.swift
sed -i.bak 's/        readingFlowFacade: coreFacade/            readingFlowFacade: coreFacade,/' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowHardeningTests.swift

# Patch iOS/Tests/ShellSmokeTests/ShellAssemblySmokeTests.swift
sed -i.bak 's/XCTAssertTrue(coordinator.searchService is DefaultSearchService)/XCTAssertNotNil(coordinator.readingFlowFacade)/' /workspace/iOS/Tests/ShellSmokeTests/ShellAssemblySmokeTests.swift
sed -i.bak '/XCTAssertTrue(coordinator.tocService is DefaultTOCService)/d' /workspace/iOS/Tests/ShellSmokeTests/ShellAssemblySmokeTests.swift
sed -i.bak '/XCTAssertTrue(coordinator.contentService is DefaultContentService)/d' /workspace/iOS/Tests/ShellSmokeTests/ShellAssemblySmokeTests.swift

