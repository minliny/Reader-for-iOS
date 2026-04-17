import Foundation
import ReaderCoreModels
import ReaderCoreProtocols
import ReaderCoreNetwork
import ReaderCoreFacade
import ReaderPlatformAdapters

@MainActor
public enum ShellAssembly {
    public static func makeDefaultReadingFlowCoordinator() -> ReadingFlowCoordinator {
        let cookieJar = BasicCookieJar()
        let httpClient = URLSessionHTTPClient(cookieJar: cookieJar)
        let errorLogger = InMemoryErrorLogger()
        let coreFacade = ReaderFlowCoreFacade(httpClient: httpClient)

        return ReadingFlowCoordinator(
            bookSourceRepository: InMemoryBookSourceRepository(),
            bookSourceDecoder: DefaultBookSourceDecoder(),
            readingFlowFacade: coreFacade,
            errorLogger: errorLogger
        )
    }
}
