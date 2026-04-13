import Foundation
import ReaderCoreModels
import ReaderShellValidation

public enum ReaderUXSurfaceKind: String, Equatable {
    case loading
    case empty
    case error
    case content
}

@MainActor
public struct ReaderUXFoundationState: Equatable {
    public let stageTitle: String
    public let stageDetail: String
    public let surfaceKind: ReaderUXSurfaceKind
    public let sourceName: String?
    public let bookTitle: String?
    public let chapterTitle: String?
    public let contentTitle: String?
    public let contentBody: String?
    public let errorMessage: String?
    public let chapterIndex: Int?
    public let chapterCount: Int
    public let progressPercentage: Double?

    public init(
        coordinator: ReadingFlowCoordinator,
        chapter: TOCItem? = nil,
        boundary: ReaderModuleBoundary = ReaderModuleBoundary()
    ) {
        let featureState = ReaderFlowFeatureState(
            coordinator: coordinator,
            boundary: boundary
        )

        stageTitle = featureState.currentStageTitle
        sourceName = coordinator.selectedSource?.bookSourceName
        bookTitle = coordinator.selectedBook?.title
        
        let targetChapter = chapter ?? coordinator.selectedChapter
        chapterTitle = targetChapter?.chapterTitle
        
        chapterCount = coordinator.tocItems.count
        if let targetChapter = targetChapter,
           let index = coordinator.tocItems.firstIndex(where: { $0.chapterURL == targetChapter.chapterURL }) {
            chapterIndex = index
            progressPercentage = chapterCount > 0 ? Double(index + 1) / Double(chapterCount) : nil
        } else {
            chapterIndex = nil
            progressPercentage = nil
        }

        if coordinator.isLoading {
            surfaceKind = .loading
            stageDetail = "正在准备当前阅读阶段。"
            contentTitle = nil
            contentBody = nil
            errorMessage = nil
            return
        }

        if let error = coordinator.currentError {
            surfaceKind = .error
            stageDetail = "当前阅读阶段遇到错误，可保持上下文并重试。"
            contentTitle = nil
            contentBody = nil
            errorMessage = error.message
            return
        }

        if let contentPage = coordinator.contentPage,
           !contentPage.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            surfaceKind = .content
            stageDetail = "正文已就绪，可继续停留在当前章节上下文中阅读。"
            contentTitle = contentPage.title
            contentBody = contentPage.content
            errorMessage = nil
            return
        }

        surfaceKind = .empty
        if chapterTitle != nil {
            stageDetail = "当前章节暂无正文，可返回目录或重新加载。"
        } else {
            stageDetail = "请先从目录中选择章节，再进入正文阅读。"
        }
        contentTitle = nil
        contentBody = nil
        errorMessage = nil
    }
}
