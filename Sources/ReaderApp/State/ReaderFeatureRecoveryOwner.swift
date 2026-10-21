import Foundation
import Combine

/// Projects the Runtime's durable original-operation journal. This use case
/// invokes only its registered typed recovery lane; it neither reconstructs
/// command payloads nor finishes Core receipts from UI observations.
@MainActor
final class ReaderFeatureRecoveryOwner: ObservableObject {
    @Published private(set) var operations: [ReaderPendingCoreCommand] = []
    @Published private(set) var loading = false
    @Published private(set) var busyID: String?
    @Published private(set) var failure: String?
    @Published private(set) var details: [String: String] = [:]
    @Published private(set) var lastResult: ReaderFeatureRecoveryResult?
    private let service: any ReaderLibraryServing
    private var generation = UUID()
    init(service: any ReaderLibraryServing) { self.service = service }

    var blocksNewReader: Bool {
        failure != nil || operations.contains { $0.method == "source.switch.commit" || $0.method.contains("reprocess") }
    }
    func reload() async {
        guard let feature = service as? any ReaderLibraryFeatures else { return }
        let current = UUID(); generation = current; loading = true
        defer { if generation == current { loading = false } }
        do {
            let values = try await feature.pendingFeatureOperations()
            guard current == generation else { return }
            operations = values; failure = nil
        } catch {
            guard current == generation else { return }
            failure = "原操作列表暂时无法核对，已保留现有结果"
        }
    }
    func resume(_ operationID: String) async -> ReaderFeatureRecoveryResult? {
        guard busyID == nil, operations.contains(where: { $0.id == operationID }),
              let feature = service as? any ReaderLibraryFeatures else { return nil }
        busyID = operationID
        defer { busyID = nil }
        do {
            let result = try await feature.resumePendingFeatureOperation(operationID)
            guard result.operationID == operationID else { throw ReaderLibraryError.invalidResponse("recovery identity") }
            lastResult = result
            details[operationID] = result.message
            if !result.remaining { operations.removeAll { $0.id == operationID } }
            await reload()
            return result
        } catch {
            details[operationID] = error.localizedDescription
            // A failed read or timeout cannot remove the original operation.
            await reload()
            return nil
        }
    }
    func label(for operation: ReaderPendingCoreCommand) -> String {
        switch operation.method {
        case "source.switch.commit": return "切换书源"
        case "bookshelf.removeBatch": return "移出书架"
        case "bookshelf.group.assign": return "保存书籍分组"
        case "book-group.create": return "创建分组"
        case "book-group.update": return "编辑分组"
        case "book-group.delete": return "删除分组"
        case "bookmark.create": return "创建书签"
        case "bookmark.update": return "保存书签"
        case "bookmark.delete": return "删除书签"
        default:
            if operation.method.contains("reprocess") { return "重新处理原书" }
            if operation.method.contains("bookmark") { return "书签操作" }
            if operation.method.contains("highlight") { return "笔记操作" }
            if operation.method.contains("replace") { return "保存替换规则" }
            if operation.method.contains("txt-toc") { return "保存 TXT 目录规则" }
            if operation.method.contains("dictionary") { return "保存字典规则" }
            if operation.method.contains("rule-sub") { return "规则订阅变更" }
            if operation.method.contains("source") { return "书源变更" }
            if operation.method.contains("download") || operation.method.contains("cache") { return "下载或缓存操作" }
            if operation.method.contains("record") { return "阅读记录变更" }
            return "原功能操作"
        }
    }
}
