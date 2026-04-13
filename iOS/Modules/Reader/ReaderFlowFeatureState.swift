import Foundation
import ReaderShellValidation

public struct ReaderFlowFeatureState {
    public let hasSelectedSource: Bool
    public let canStartSearch: Bool
    public let hasSearchResults: Bool
    public let hasSelectedBook: Bool
    public let hasTOCItems: Bool
    public let hasSelectedChapter: Bool
    public let hasContentPage: Bool
    public let currentStageTitle: String

    public init(
        coordinator: ReadingFlowCoordinator,
        boundary: ReaderModuleBoundary = ReaderModuleBoundary()
    ) {
        hasSelectedSource = coordinator.selectedSource != nil
        canStartSearch = boundary.canSearch && hasSelectedSource
        hasSearchResults = !coordinator.searchResults.isEmpty
        hasSelectedBook = coordinator.selectedBook != nil
        hasTOCItems = !coordinator.tocItems.isEmpty
        hasSelectedChapter = coordinator.selectedChapter != nil
        hasContentPage = coordinator.contentPage != nil
        currentStageTitle = Self.resolveStageTitle(
            coordinator: coordinator,
            boundary: boundary
        )
    }

    private static func resolveStageTitle(
        coordinator: ReadingFlowCoordinator,
        boundary: ReaderModuleBoundary
    ) -> String {
        if coordinator.isLoading {
            if coordinator.selectedChapter != nil {
                return "正文加载中"
            }

            if coordinator.selectedBook != nil {
                return "目录加载中"
            }

            if coordinator.selectedSource != nil {
                return "搜索中"
            }

            return "书源导入中"
        }

        if coordinator.currentError != nil {
            if coordinator.selectedChapter != nil {
                return "正文加载失败"
            }

            if coordinator.selectedBook != nil {
                return "目录加载失败"
            }

            if coordinator.selectedSource != nil {
                return "搜索失败"
            }

            return "书源导入失败"
        }

        if coordinator.contentPage != nil {
            return "正文已加载"
        }

        if coordinator.selectedChapter != nil {
            return "章节已选择"
        }

        if !coordinator.tocItems.isEmpty {
            return "目录已加载"
        }

        if coordinator.selectedBook != nil {
            return "书籍已选择"
        }

        if !coordinator.searchResults.isEmpty {
            return "搜索结果已就绪"
        }

        if boundary.canSearch && coordinator.selectedSource != nil {
            return "可开始搜索"
        }

        return "等待导入书源"
    }
}
