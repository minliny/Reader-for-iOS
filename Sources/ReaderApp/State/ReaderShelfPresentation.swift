import Foundation
import Combine
import os

/// A projection is valid only for the complete Core query and the exact
/// confirmed library snapshot from which the view requested it. Hashing is
/// only SwiftUI's task identity; equality still compares every book field.
struct ReaderShelfProjectionKey: Hashable {
    let query: ReaderShelfQuery
    let librarySnapshot: [ReaderBook]

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.query == rhs.query && lhs.librarySnapshot == rhs.librarySnapshot &&
        zip(lhs.librarySnapshot, rhs.librarySnapshot).allSatisfy {
            textIdentity($0.0) == textIdentity($0.1)
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(query)
        hasher.combine(librarySnapshot)
        for book in librarySnapshot { hasher.combine(Self.textIdentity(book)) }
    }

    /// Keep the existing complete Book value for its scalar fields, while
    /// retaining Core's bytes for every text field in this projection only.
    private static func textIdentity(_ book: ReaderBook) -> [Data?] {
        let fields: [String?] = [book.sourceId, book.bookId, book.title, book.author, book.currentChapterTitle,
                                book.coverUrl, book.intro, book.kind, book.group, book.sourceName]
        return fields.map { $0.map { Data($0.utf8) } }
    }

    fileprivate var logSummary: String {
        let group = query.group.map { $0.isEmpty ? "ungrouped" : "named:\(Data($0.utf8).hashValue)" } ?? "all"
        return "keywordLength=\(query.keyword?.count ?? 0),group=\(group),sort=\(query.sortBy.rawValue),descending=\(query.descending),libraryCount=\(librarySnapshot.count),projection=\(hashValue)"
    }
}

struct ReaderShelfGroupOption: Identifiable {
    let name: String
    let id: Data
    init(name: String) { self.name = name; id = Data(name.utf8) }
}

/// Retained view projection, not another book store. All membership and group
/// mutations are acknowledged by Core through ReaderLibraryFeatures.
@MainActor
final class ReaderShelfPresentation: ObservableObject {
    @Published var group: String?
    @Published var sort: ReaderShelfSort = .lastReadAt
    @Published var descending = true
    @Published var selecting = false
    @Published var selection = Set<String>()
    /// Unsaved group form belongs to the retained shelf presentation, so
    /// closing its sheet or visiting another Root route does not erase input.
    let groupDraft = ReaderGroupDraftOwner()
    @Published private(set) var groups: [ReaderBookGroup] = []
    private struct Projection {
        let key: ReaderShelfProjectionKey
        let books: [ReaderBook]
    }
    private struct Request {
        let id: UUID
        let key: ReaderShelfProjectionKey
        var loading: Bool
        var error: String?
    }
    @Published private var projection: Projection?
    @Published private var request: Request?
    private var generation = UUID()
    private static let logger = Logger(subsystem: "io.reader.minliny", category: "reader-shelf")
    #if DEBUG
    private let diagnosticOwnerID = UUID()
    #endif

    /// Lifecycle observations only; never changes the query, search binding,
    /// projection or request owner. No user text is included in the key summary.
    func traceSearchPresentation(_ event: String, searching: Bool,
                                 key: ReaderShelfProjectionKey, previous: Bool? = nil) {
        #if DEBUG
        let old = previous.map { $0 ? "true" : "false" } ?? "none"
        let requestID = request?.id.uuidString ?? "none"
        let loading = request?.loading ?? false
        let count = books(for: key)?.count ?? -1
        Self.logger.info("search.\(event, privacy: .public) owner=\(self.diagnosticOwnerID.uuidString, privacy: .public) generation=\(self.generation.uuidString, privacy: .public) request=\(requestID, privacy: .public) previous=\(old, privacy: .public) searching=\(searching, privacy: .public) loading=\(loading, privacy: .public) visibleCount=\(count, privacy: .public) key=\(key.logSummary, privacy: .public)")
        #endif
    }

    func key(model: ReaderApplicationModel, keyword: String) -> ReaderShelfProjectionKey {
        let keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        return ReaderShelfProjectionKey(query: ReaderShelfQuery(sourceId: nil,
            keyword: keyword.isEmpty ? nil : keyword,
            group: group?.trimmingCharacters(in: .whitespacesAndNewlines),
            sortBy: sort, descending: descending), librarySnapshot: model.books)
    }

    /// Group records and stored shelf labels have independent Core lifetimes.
    /// A renamed/deleted definition must not hide the books' retained label.
    func groupNameOptions(model: ReaderApplicationModel) -> [String] {
        groupOptions(model: model).map(\.name)
    }

    func groupOptions(model: ReaderApplicationModel) -> [ReaderShelfGroupOption] {
        func name(_ value: String?) -> String? {
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
            return value
        }
        var seen = Set<Data>()
        var options: [ReaderShelfGroupOption] = []
        for definition in groups {
            if let value = name(definition.groupName), seen.insert(Data(value.utf8)).inserted {
                options.append(ReaderShelfGroupOption(name: value))
            }
        }
        // Use the complete confirmed library, not this query's visible subset.
        var labels: [Data: String] = [:]
        for book in model.books {
            if let value = name(book.group) { labels[Data(value.utf8)] = value }
        }
        if let selected = name(group) { labels[Data(selected.utf8)] = selected }
        for id in labels.keys.sorted(by: { $0.lexicographicallyPrecedes($1) }) where seen.insert(id).inserted {
            if let value = labels[id] { options.append(ReaderShelfGroupOption(name: value)) }
        }
        return options
    }

    func books(for key: ReaderShelfProjectionKey) -> [ReaderBook]? {
        guard projection?.key == key else { return nil }
        return projection?.books
    }

    func failure(for key: ReaderShelfProjectionKey) -> String? {
        guard request?.key == key else { return nil }
        return request?.error
    }

    func recordLayout(key: ReaderShelfProjectionKey, grid: Bool) {
        let count = books(for: key)?.count ?? -1
        Self.logger.info("layout request=\(self.generation.uuidString, privacy: .public) grid=\(grid, privacy: .public) count=\(count, privacy: .public) key=\(key.logSummary, privacy: .public)")
    }

    func reload(model: ReaderApplicationModel, keyword: String, grid: Bool? = nil) async {
        guard let service = model.libraryService as? any ReaderLibraryFeatures else { return }
        let key = key(model: model, keyword: keyword)
        let current = UUID()
        generation = current
        request = Request(id: current, key: key, loading: true, error: nil)
        let layout = grid.map { $0 ? "grid" : "list" } ?? "unspecified"
        Self.logger.info("reload.begin request=\(current.uuidString, privacy: .public) layout=\(layout, privacy: .public) key=\(key.logSummary, privacy: .public)")
        defer {
            if generation == current { request?.loading = false }
        }
        do {
            let result = try await service.listBooks(query: key.query)
            guard generation == current, !Task.isCancelled,
                  self.key(model: model, keyword: keyword) == key else {
                Self.logger.info("reload.retired request=\(current.uuidString, privacy: .public) count=\(result.count, privacy: .public) key=\(key.logSummary, privacy: .public)")
                return
            }
            // Publish books and their applied identity together. A same-key
            // refresh retains this value until its replacement is confirmed.
            projection = Projection(key: key, books: result)
            model.ensureShelfFormats(for: result)
            Self.logger.info("reload.confirmed request=\(current.uuidString, privacy: .public) count=\(result.count, privacy: .public) layout=\(layout, privacy: .public) key=\(key.logSummary, privacy: .public)")
            if let result = try? await service.groups(), generation == current, !Task.isCancelled {
                groups = result
            }
        } catch {
            guard generation == current, !Task.isCancelled,
                  self.key(model: model, keyword: keyword) == key else { return }
            request?.error = error.localizedDescription
            let kind = String(reflecting: type(of: error))
            Self.logger.error("reload.failed request=\(current.uuidString, privacy: .public) errorType=\(kind, privacy: .public) key=\(key.logSummary, privacy: .public)")
        }
    }
    func toggle(_ book: ReaderBook) {
        if selection.contains(book.id) { selection.remove(book.id) } else { selection.insert(book.id) }
    }

    /// Selection follows the original removal's confirmed completion, including
    /// a later resume. Other selected books do not belong to this operation.
    func removeSelectedBooks(_ targets: [ReaderBook], using actions: ReaderLibraryActionOwner,
                             action: @escaping (String) async throws -> Void) async -> Bool {
        let targetIDs = Set(targets.map(\.id))
        guard !targetIDs.isEmpty else { return false }
        return await actions.perform("移出书架", scope: "shelf", ended: { [weak self] _, confirmed in
            guard confirmed else { return }
            self?.selection.subtract(targetIDs)
        }, action: action)
    }
}
