#if READER_IOS_SHELL_CI
import Foundation
import ReaderCoreModels
import ReaderCoreProtocols

struct ShellCIRealSearchService: SearchService {
    func search(source: BookSource, query: SearchQuery) async throws -> [SearchResultItem] {
        []
    }
}

struct ShellCIRealTOCService: TOCService {
    func fetchTOC(source: BookSource, detailURL: String) async throws -> [TOCItem] {
        []
    }
}

struct ShellCIRealContentService: ContentService {
    func fetchContent(source: BookSource, chapterURL: String) async throws -> ContentPage {
        ContentPage(
            title: "Shell CI content placeholder",
            content: "",
            chapterURL: chapterURL
        )
    }
}
#endif
