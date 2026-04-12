import Foundation
import ReaderShellValidation
import ReaderCoreModels
import ReaderCoreProtocols
import ReaderCoreNetwork
import ReaderCoreParser
import ReaderPlatformAdapters

/// Factory for constructing fully-wired `ReadingFlowCoordinator` instances.
///
/// This is the **only** iOS Shell file permitted to import Core internal modules
/// (`ReaderCoreNetwork`, `ReaderCoreParser`), because it is responsible for
/// wiring concrete implementations into protocol-typed dependencies.
///
/// All other Shell/CoreIntegration files must depend exclusively on
/// `ReaderCoreProtocols` + `ReaderCoreModels`.
@MainActor
public enum ShellAssembly {

    /// Builds a `ReadingFlowCoordinator` with default production dependencies:
    /// - `URLSessionHTTPClient` + `BasicCookieJar` for networking
    /// - `BookSourceRequestBuilder` for request construction
    /// - `NonJSParserEngine` (with `NonJSRuleScheduler`) for parsing
    /// - `InMemoryBookSourceRepository` for book source storage
    /// - `InMemoryErrorLogger` for error logging
    public static func makeDefaultReadingFlowCoordinator() -> ReadingFlowCoordinator {
        let cookieJar = BasicCookieJar()
        let httpClient = URLSessionHTTPClient(cookieJar: cookieJar)
        let requestBuilder = BookSourceRequestBuilder()
        let ruleScheduler = NonJSRuleScheduler()
        let parserEngine = NonJSParserEngine(scheduler: ruleScheduler)
        let errorLogger = InMemoryErrorLogger()

        return ReadingFlowCoordinator(
            bookSourceRepository: InMemoryBookSourceRepository(),
            bookSourceDecoder: DefaultBookSourceDecoder(),
            searchService: DefaultSearchService(
                httpClient: httpClient,
                requestBuilder: requestBuilder,
                searchParser: parserEngine
            ),
            tocService: DefaultTOCService(
                httpClient: httpClient,
                requestBuilder: requestBuilder,
                tocParser: parserEngine
            ),
            contentService: DefaultContentService(
                httpClient: httpClient,
                requestBuilder: requestBuilder,
                contentParser: parserEngine
            ),
            errorLogger: errorLogger
        )
    }
}
