import Foundation
import ReaderCoreModels
import ReaderCoreProtocols
import ReaderCoreNetwork
import ReaderCoreParser

/// Validation-only composition root used by the macOS-hosted shell gate.
///
/// This keeps interim smoke validation focused on the host-compilable
/// composition graph without pulling iOS-only UI sources into the test plan.
@MainActor
public enum ShellAssembly {
    public static func makeDefaultReadingFlowCoordinator() -> ReadingFlowCoordinator {
        let cookieJar = BasicCookieJar()
        let httpClient = URLSessionHTTPClient(cookieJar: cookieJar)
        let requestBuilder = BookSourceRequestBuilder()
        let ruleScheduler = NonJSRuleScheduler()
        let parserEngine = NonJSParserEngine(ruleScheduler: ruleScheduler)
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
