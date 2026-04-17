#!/bin/bash
set -e

# Fix ReaderFlowFunctionalValidationTests
sed -i.bak 's/                readingFlowFacade: coreFacade,,/            bookSourceRepository: InMemoryBookSourceRepository(),\
            bookSourceDecoder: DefaultBookSourceDecoder(),\
            readingFlowFacade: coreFacade,\
/' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowFunctionalValidationTests.swift

sed -i.bak 's/        let httpClient = FixtureHTTPClient(/        let httpClient = FixtureHTTPClient(\
            searchURLPrefix: (fixture.bookSource.bookSourceUrl ?? "") + "\/search",\
            searchRoute: .ok(data: fixture.searchFixtureData),\
            routes: [\
            fixture.expectedSearch.expected.items[0].detailURL: .ok(data: fixture.tocFixtureData),\
/' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowFunctionalValidationTests.swift
sed -i.bak '79,81d' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowFunctionalValidationTests.swift

# Fix ReaderFlowHardeningTests
sed -i.bak 's/                readingFlowFacade: coreFacade,,/            bookSourceRepository: InMemoryBookSourceRepository(),\
            bookSourceDecoder: DefaultBookSourceDecoder(),\
            readingFlowFacade: coreFacade,\
/' /workspace/iOS/Tests/ShellSmokeTests/ReaderFlowHardeningTests.swift

