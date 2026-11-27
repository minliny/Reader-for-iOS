import ReaderCoreBridge
import ReaderDesign
import SwiftUI

struct FailedOnlineChapter {
    let index: Int64
    let title: String
    let target: M2DirectoryTargetResolveParamsV2?
}

extension ReadingScreen {
    var onlineToolsMenu: some View {
        Menu {
            Button("刷新正文", systemImage: ReaderIconRegistry.refresh.systemName ?? "arrow.clockwise") {
                Task {
                    await sampleSurface()
                    if await model.refreshOnlineChapter() {
                        model.feedback("正文已刷新", key: "online-body-refreshed")
                    } else if model.chapter != nil {
                        model.feedback("正文刷新失败，已保留当前内容和位置", key: "online-body-refresh-failed")
                    }
                }
            }
            .disabled(model.chapter == nil || failedChapter != nil)
            .accessibilityIdentifier("m2-reader-refresh-body")
            Button("在线目录", systemImage: ReaderIconRegistry.directory.systemName ?? "list.bullet") {
                sheet = .directory
            }
            .accessibilityIdentifier("m2-reader-directory")
            Button("换源") {
                guard onlineRecovery.operation == nil else { return }
                sheet = .sourceSwitch
            }
            .disabled(model.chapter == nil || onlineRecovery.operation != nil || failedChapter != nil)
            .accessibilityIdentifier("m2-reader-switch")
            Button("下载", systemImage: ReaderIconRegistry.download.systemName ?? "arrow.down.to.line") {
                sheet = .downloads
            }
            .accessibilityIdentifier("m2-reader-downloads")
        } label: {
            ReaderIcon(ReaderIconRegistry.more)
        }
        .accessibilityLabel("在线阅读操作")
        .accessibilityValue(model.onlineBook?.displaySource ?? "")
        .accessibilityIdentifier("m2-reader-tools")
    }

    func beginOnline(_ context: OnlineReadingContext) async {
        await model.beginOnline(book: book, files: files, startChapter: startChapter)
        guard !Task.isCancelled else { return }
        if let target = context.initialTarget, model.chapter != nil {
            _ = await model.chooseOnlineTarget(target)
        }
        if let current = model.onlineBook {
            await onlineRecovery.inspect(current, online: .init(runtime: model.runtime))
        }
        if context.switchOnOpen, model.chapter != nil, onlineRecovery.operation == nil {
            sheet = .sourceSwitch
        }
    }

    func chooseOnlineDirectoryItem(_ target: M2DirectoryTargetResolveParamsV2, index: Int64, title: String) async throws {
        await sampleSurface()
        if await model.chooseOnlineTarget(target) {
            sheet = nil
            failedChapter = nil
            setControls(.hidden)
        } else if model.onlineUnavailableChapter == index {
            sheet = nil
            setControls(.hidden)
            failedChapter = .init(index: index, title: title, target: target)
        } else {
            throw OnlineReadingCoordinator.Failure.directoryChanged
        }
    }

    func switchSource(_ candidate: SourceSwitchCandidate) async throws {
        guard let context = onlineContext, let current = model.onlineBook, let chapter = model.chapter
        else { throw ReadingProjectionFailure.invalidChapter }
        let online = OnlineReadingCoordinator(runtime: model.runtime)
        let draft = try await online.switchDraft(book: current, chapter: chapter, candidate: candidate)
        do {
            await sampleSurface()
            _ = try await model.switchOnlineSource(draft)
            if var book = model.onlineBook {
                book.sourceName = candidate.book.sourceName ?? book.sourceName
                context.onBookChanged(book)
            }
            sheet = nil
            failedChapter = nil
            setControls(.hidden)
        } catch let OnlineReadingCoordinator.Failure.switchUnresolved(query) {
            onlineRecovery.retain(query, from: draft.from,
                                  target: .init(sourceId: draft.target.sourceId, bookId: draft.target.bookId))
            throw OnlineReadingCoordinator.Failure.switchUnresolved(query)
        }
    }

    func onlineRecoveryNotice(_ operation: OnlineReaderRecovery.Operation, available: Bool) -> some View {
        RecoveryNotice(title: "换源待核对", message: "请核对原换源记录。仍未完成的事务将恢复原书源和位置。",
            generation: operation.generation,
            action: onlineRecovery.verifying ? nil : ReaderRecoveryAction(title: "核对并恢复", generation: operation.generation),
            availability: available) { expected, action in
                guard phase == .active, sheet == nil else { return }
                Task {
                    do {
                        if let entry = try await onlineRecovery.verify(expected: expected, action: action,
                                                                        online: .init(runtime: model.runtime)) {
                            await model.adoptRecoveredOnlineBook(entry)
                            onlineContext?.onBookChanged(.init(shelfBook: entry))
                            failedChapter = nil
                        }
                    } catch {
                        model.feedback("暂时无法确认原换源记录，仍可重新核对", key: "source-switch-recovery-failed")
                    }
                }
            }
    }

    func unavailableChapterPage(_ failure: FailedOnlineChapter) -> some View {
        VStack {
            PageState(state: .failed("《\(failure.title)》尚未缓存，暂时无法读取。", actionGeneration: model.generation)) { current in
                guard current == model.generation else { return }
                if let target = failure.target {
                    Task {
                        do { try await chooseOnlineDirectoryItem(target, index: failure.index, title: failure.title) }
                        catch { model.feedback("请刷新目录后重新打开该章节", key: "offline-target-retry") }
                    }
                } else {
                    choose(failure.index)
                }
            }
            Button("返回当前章节") { failedChapter = nil }
                .padding(CGFloat(ReaderDesignMetrics.spaceMedium))
                .accessibilityIdentifier("m2-reader-retain-current")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("m2-reader-uncached")
    }
}
