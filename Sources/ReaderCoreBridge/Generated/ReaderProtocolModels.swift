// GENERATED FILE — DO NOT EDIT.
// Generator: scripts/generate-protocol-bindings.mjs
// Inputs and SHA-256 fingerprints:
//   protocol/reader-command.schema.json  0ba9a587929fe7612886bc54fd463ba1cea382cf9cb0a979b37e96c0cd7fbad0
//   protocol/reader-event.schema.json  e0a79f46acfa62370dcc48311c03636e3b034c8e9207e6d176450bf65f45c695
//   protocol/reader-runtime-config.schema.json  7f80c3a548f71ab2b5d4415af83579f03c725cb0bec0fc72a1e7dc6e91368afa
//   protocol/reader-m2-bindings.schema.json  ec399b07871736546c2d0277ee9f9dda42b98229b978624c705e9b783b907716
//   protocol/reader-m2-host.schema.json  bc2232be1379902bdb1b56313f301e1f23454c3d7f67980b5e7b8028d48ad8b5
//   protocol/reader-m2-sources.schema.json  9c18d4b3f6f9d69fa1bfbc2652afca6d247b1f4660dce8a9afc766d041786e60
//   protocol/reader-m2-source-receipts.schema.json  ec7eb3696e653992272bd7cbf8117fa525704a73ec384e2183dbec716aa786cc
//   protocol/reader-m2-search.schema.json  64f69b9b22522f5af679db85e0510f7779cffcfddbd294b7c52408bde5accd81
//   protocol/reader-m2-download.schema.json  ad1dcd655280eff33ad53c099fa5a8d4a670e76306f0472243465408cf108554
//   protocol/reader-m2-reading.schema.json  8add0b72bea24ee8aa696684b219f1a931ab869691154ee80e601fb5c675650c
// Module: ReaderCoreClient / Generated. Types are Codable + Sendable so a
// host can hand them between its own queues without shared mutable state.

import Foundation

/// Dynamic JSON payload used where the v1 schema is method-polymorphic.
public enum ReaderJSONValue: Codable, Sendable, Equatable {
    case null
    case bool(Bool)
    case integer(Int64)
    case number(Double)
    case string(String)
    case array([ReaderJSONValue])
    case object([String: ReaderJSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([ReaderJSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: ReaderJSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "ReaderJSONValue cannot decode this token"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

/// Every command method declared by reader-command.schema.json (242).
public enum ReaderCommandMethod: String, Codable, Sendable, CaseIterable {
    case bookHighlightCreate = "book-highlight.create"
    case bookHighlightUpdate = "book-highlight.update"
    case bookChapterReview = "book.chapterReview"
    case bookDetail = "book.detail"
    case bookSearch = "book.search"
    case bookToc = "book.toc"
    case bookmarkCreate = "bookmark.create"
    case bookmarkDelete = "bookmark.delete"
    case bookmarkList = "bookmark.list"
    case bookmarkOperationQuery = "bookmark.operation.query"
    case bookmarkOperationSettle = "bookmark.operation.settle"
    case bookmarkUpdate = "bookmark.update"
    case bookshelfAdd = "bookshelf.add"
    case bookshelfBookUpdate = "bookshelf.book.update"
    case bookshelfGet = "bookshelf.get"
    case bookshelfGroupAssign = "bookshelf.group.assign"
    case bookshelfList = "bookshelf.list"
    case bookshelfManagementMutationApply = "bookshelf.management.mutation.apply"
    case bookshelfManagementMutationQuery = "bookshelf.management.mutation.query"
    case bookshelfRemove = "bookshelf.remove"
    case bookshelfRemoveBatch = "bookshelf.removeBatch"
    case cacheBookPrefetch = "cache.book.prefetch"
    case cacheBookStatus = "cache.book.status"
    case cacheChapterMaterializationReport = "cache.chapter.materialization.report"
    case cacheClear = "cache.clear"
    case cacheClearOperationQuery = "cache.clear.operation.query"
    case cacheClearOperationSettle = "cache.clear.operation.settle"
    case cacheDownloadCancel = "cache.download.cancel"
    case cacheDownloadOperationQuery = "cache.download.operation.query"
    case cacheDownloadOperationSettle = "cache.download.operation.settle"
    case cacheDownloadPause = "cache.download.pause"
    case cacheDownloadResume = "cache.download.resume"
    case cacheStorageCleanup = "cache.storage.cleanup"
    case cacheStorageSummary = "cache.storage.summary"
    case changeBookSource = "change.bookSource"
    case changeCover = "change.cover"
    case chapterContent = "chapter.content"
    case contentEditDelete = "content-edit.delete"
    case contentEditGet = "content-edit.get"
    case contentEditList = "content-edit.list"
    case contentEditPut = "content-edit.put"
    case coreInfo = "core.info"
    case dictRuleDelete = "dict-rule.delete"
    case dictRuleList = "dict-rule.list"
    case dictRulePut = "dict-rule.put"
    case dictRuleQuery = "dict-rule.query"
    case hostComplete = "host.complete"
    case hostError = "host.error"
    case importFinalize = "import.finalize"
    case importParse = "import.parse"
    case importPersist = "import.persist"
    case importRollback = "import.rollback"
    case localBookPositionArchiveList = "local.book.positionArchive.list"
    case localBookCatalog = "local_book.catalog"
    case localBookChapterContent = "local_book.chapter.content"
    case localBookChapterPresentationV1 = "local_book.chapter.presentation.v1"
    case localBookContentMetrics = "local_book.content.metrics"
    case localBookImport = "local_book.import"
    case localBookNavigationBackfillV1 = "local_book.navigation.backfill.v1"
    case localBookParse = "local_book.parse"
    case localBookPresentationKindV1 = "local_book.presentation.kind.v1"
    case localBookToc = "local_book.toc"
    case mangaCacheClassify = "manga.cache.classify"
    case mangaCacheClassifyBatch = "manga.cache.classifyBatch"
    case mangaCacheEvict = "manga.cache.evict"
    case mangaCacheEvictionClaim = "manga.cache.eviction.claim"
    case mangaCacheEvictionComplete = "manga.cache.eviction.complete"
    case mangaCacheEvictionPending = "manga.cache.eviction.pending"
    case mangaCacheMaterializationAbort = "manga.cache.materialization.abort"
    case mangaCacheMaterializationComplete = "manga.cache.materialization.complete"
    case mangaCacheMaterializationPrepare = "manga.cache.materialization.prepare"
    case mangaCacheRecordRead = "manga.cache.recordRead"
    case mangaChapterGet = "manga.chapter.get"
    case mangaEntryGet = "manga.entry.get"
    case mangaPagesExtract = "manga.pages.extract"
    case mangaPagesWindow = "manga.pages.window"
    case mangaResourceInspect = "manga.resource.inspect"
    case mangaResourcePrepare = "manga.resource.prepare"
    case mangaRetentionGet = "manga.retention.get"
    case mangaRetentionList = "manga.retention.list"
    case mangaRetentionSet = "manga.retention.set"
    case mangaSessionProtect = "manga.session.protect"
    case mangaSessionRelease = "manga.session.release"
    case mangaSessionReplace = "manga.session.replace"
    case mangaSessionRuntime = "manga.session.runtime"
    case mangaSourceSwitchCommit = "manga.sourceSwitch.commit"
    case mangaSourceSwitchCommitV2 = "manga.sourceSwitch.commit.v2"
    case mangaSourceSwitchOperationQueryV1 = "manga.sourceSwitch.operation.query.v1"
    case readRecordAccumulate = "read-record.accumulate"
    case readRecordAccumulateReceipt = "read-record.accumulate-receipt"
    case readRecordClear = "read-record.clear"
    case readRecordCreate = "read-record.create"
    case readRecordDelete = "read-record.delete"
    case readRecordDeleteByBook = "read-record.deleteByBook"
    case readRecordList = "read-record.list"
    case readRecordSummary = "read-record.summary"
    case readRecordUpdate = "read-record.update"
    case readerChineseConversionGet = "reader.chinese-conversion.get"
    case readerChineseConversionPut = "reader.chinese-conversion.put"
    case readerLocationResolve = "reader.location.resolve"
    case readingCatalogPage = "reading.catalog.page"
    case readingDirectoryRulesApplyV2 = "reading.directory.rules.apply.v2"
    case readingDirectoryRulesGetV2 = "reading.directory.rules.get.v2"
    case readingDirectoryRulesPrepareV2 = "reading.directory.rules.prepare.v2"
    case readingDirectoryRulesPreviewV2 = "reading.directory.rules.preview.v2"
    case readingDirectoryTargetResolveV2 = "reading.directory.target.resolve.v2"
    case readingDirectoryViewOpenV1 = "reading.directory.view.open.v1"
    case readingDirectoryViewOpenV2 = "reading.directory.view.open.v2"
    case readingDirectoryViewPageV1 = "reading.directory.view.page.v1"
    case readingDirectoryViewPageV2 = "reading.directory.view.page.v2"
    case readingDirectoryViewTargetResolveV1 = "reading.directory.view.target.resolve.v1"
    case readingDocumentWindow = "reading.document.window"
    case readingEntryPrepare = "reading.entry.prepare"
    case readingEntrySnapshot = "reading.entry.snapshot"
    case readingPreparation = "reading.preparation"
    case readingProgressGet = "reading.progress.get"
    case readingProgressUpdate = "reading.progress.update"
    case replaceRuleCreate = "replace-rule.create"
    case replaceRuleDelete = "replace-rule.delete"
    case replaceRuleList = "replace-rule.list"
    case replaceRuleUpdate = "replace-rule.update"
    case replaceApply = "replace.apply"
    case replacePersist = "replace.persist"
    case replacePreview = "replace.preview"
    case replaceUndo = "replace.undo"
    case replaceValidate = "replace.validate"
    case rssSourceExport = "rss-source.export"
    case rssSourceImport = "rss-source.import"
    case rssSourceList = "rss-source.list"
    case rssSourcePut = "rss-source.put"
    case rssFavoriteList = "rss.favorite.list"
    case rssItemRead = "rss.item.read"
    case rssList = "rss.list"
    case rssParse = "rss.parse"
    case rssRefresh = "rss.refresh"
    case rssSubscriptionAdd = "rss.subscription.add"
    case rssSubscriptionCreate = "rss.subscription.create"
    case rssSubscriptionDelete = "rss.subscription.delete"
    case rssSubscriptionItems = "rss.subscription.items"
    case rssSubscriptionList = "rss.subscription.list"
    case rssSubscriptionRefresh = "rss.subscription.refresh"
    case rssSubscriptionUpdate = "rss.subscription.update"
    case ruleBundleExport = "rule-bundle.export"
    case ruleBundleImport = "rule-bundle.import"
    case ruleSubDelete = "rule-sub.delete"
    case ruleSubGet = "rule-sub.get"
    case ruleSubList = "rule-sub.list"
    case ruleSubPut = "rule-sub.put"
    case ruleSubUpdatePreviewV1 = "rule-sub.update.preview.v1"
    case rulesMutationApply = "rules.mutation.apply"
    case rulesMutationQuery = "rules.mutation.query"
    case runtimeCancel = "runtime.cancel"
    case runtimeHostSmoke = "runtime.hostSmoke"
    case runtimePing = "runtime.ping"
    case runtimeSetHostCapabilities = "runtime.setHostCapabilities"
    case runtimeShutdown = "runtime.shutdown"
    case runtimeStatus = "runtime.status"
    case runtimeStorageApply = "runtime.storage.apply"
    case runtimeStorageBackupCreate = "runtime.storage.backup.create"
    case runtimeStorageBackupRestore = "runtime.storage.backup.restore"
    case runtimeStorageExport = "runtime.storage.export"
    case runtimeStorageFlush = "runtime.storage.flush"
    case runtimeStorageRestore = "runtime.storage.restore"
    case searchBookBatchGet = "search-book.batch.get"
    case searchBookDelete = "search-book.delete"
    case searchBookGet = "search-book.get"
    case searchBookList = "search-book.list"
    case searchBookPut = "search-book.put"
    case searchBookRelated = "search-book.related"
    case searchKeywordDelete = "search-keyword.delete"
    case searchKeywordGet = "search-keyword.get"
    case searchKeywordList = "search-keyword.list"
    case searchKeywordPut = "search-keyword.put"
    case searchContent = "search.content"
    case searchCover = "search.cover"
    case searchHistoryAdd = "search.history.add"
    case searchHistoryClear = "search.history.clear"
    case searchHistoryList = "search.history.list"
    case sourceCheck = "source.check"
    case sourceCheckEphemeralRun = "source.check.ephemeral.run"
    case sourceCheckReportClear = "source.check.report.clear"
    case sourceCheckRun = "source.check.run"
    case sourceDebug = "source.debug"
    case sourceDelete = "source.delete"
    case sourceExplore = "source.explore"
    case sourceExploreKinds = "source.exploreKinds"
    case sourceExport = "source.export"
    case sourceGroupCatalog = "source.group.catalog"
    case sourceImageRequest = "source.imageRequest"
    case sourceImport = "source.import"
    case sourceList = "source.list"
    case sourceSupply = "source.supply"
    case sourceSwitchCommit = "source.switch.commit"
    case sourceSwitchFinalize = "source.switch.finalize"
    case sourceSwitchPendingList = "source.switch.pending.list"
    case sourceSwitchRecover = "source.switch.recover"
    case sourceSwitchRollback = "source.switch.rollback"
    case sourceSwitchTransactionQuery = "source.switch.transaction.query"
    case sourceUpdate = "source.update"
    case syncBackup = "sync.backup"
    case syncBackupAutoDecision = "sync.backup.auto.decision"
    case syncBackupContentPlan = "sync.backup.content.plan"
    case syncBackupRestoreScopePlan = "sync.backup.restore.scope.plan"
    case syncBackupRetention = "sync.backup.retention"
    case syncConflictResolve = "sync.conflict.resolve"
    case syncMerge = "sync.merge"
    case syncWebdavBackupReceiptQuery = "sync.webdav.backup.receipt.query"
    case syncWebdavBackupRetentionSkip = "sync.webdav.backup.retention.skip"
    case syncWebdavDirectoryListPlan = "sync.webdav.directory.list.plan"
    case syncWebdavMultistatusParse = "sync.webdav.multistatus.parse"
    case syncWebdavPlan = "sync.webdav.plan"
    case syncWebdavProgressMerge = "sync.webdav.progress.merge"
    case syncWebdavProgressPushPlan = "sync.webdav.progress.push.plan"
    case syncWebdavRemoteBookLocalImportPlan = "sync.webdav.remote-book.local-import.plan"
    case syncWebdavRemoteBookPlan = "sync.webdav.remote-book.plan"
    case syncWebdavRemoteBookResult = "sync.webdav.remote-book.result"
    case syncWebdavTransactionAbort = "sync.webdav.transaction.abort"
    case syncWebdavTransactionAdvance = "sync.webdav.transaction.advance"
    case syncWebdavTransactionCommit = "sync.webdav.transaction.commit"
    case syncWebdavTransactionResolve = "sync.webdav.transaction.resolve"
    case syncWebdavTransactionStart = "sync.webdav.transaction.start"
    case ttsChapterPlan = "tts.chapter.plan"
    case ttsConfigGet = "tts.config.get"
    case ttsConfigPut = "tts.config.put"
    case ttsQueueNext = "tts.queue.next"
    case ttsQueuePause = "tts.queue.pause"
    case ttsQueuePlay = "tts.queue.play"
    case ttsQueuePrev = "tts.queue.prev"
    case ttsQueueReportCallback = "tts.queue.report-callback"
    case ttsQueueReportStatus = "tts.queue.report-status"
    case ttsQueueResume = "tts.queue.resume"
    case ttsQueueSeek = "tts.queue.seek"
    case ttsQueueSetRate = "tts.queue.set-rate"
    case ttsQueueSkip = "tts.queue.skip"
    case ttsQueueStatus = "tts.queue.status"
    case ttsQueueStop = "tts.queue.stop"
    case ttsSlice = "tts.slice"
    case txtTocRuleCreate = "txt-toc-rule.create"
    case txtTocRuleDelete = "txt-toc-rule.delete"
    case txtTocRuleList = "txt-toc-rule.list"
    case txtTocRulePreview = "txt-toc-rule.preview"
    case txtTocRuleUpdate = "txt-toc-rule.update"
}

/// Host capabilities declared by reader-command.schema.json (16).
public enum ReaderHostCapability: String, Codable, Sendable, CaseIterable {
    case cacheGet = "cache.get"
    case cachePut = "cache.put"
    case cookieGet = "cookie.get"
    case cookieSet = "cookie.set"
    case fileRead = "file.read"
    case fileWrite = "file.write"
    case hostSmokeEcho = "host.smoke.echo"
    case httpExecute = "http.execute"
    case logEmit = "log.emit"
    case mangaResourceTransfer = "manga.resource.transfer"
    case mediaDownload = "media.download"
    case persistenceGet = "persistence.get"
    case persistencePut = "persistence.put"
    case systemInfo = "system.info"
    case timeNow = "time.now"
    case webviewEvaluateJavaScript = "webview.evaluateJavaScript"
}

/// ErrorCode vocabulary from reader-event.schema.json (11).
public enum ReaderErrorCode: String, Codable, Sendable, CaseIterable {
    case bookAlreadyOnShelf = "BOOK_ALREADY_ON_SHELF"
    case busy = "BUSY"
    case cancelled = "CANCELLED"
    case `internal` = "INTERNAL"
    case invalidMessage = "INVALID_MESSAGE"
    case invalidParams = "INVALID_PARAMS"
    case invalidProtocolVersion = "INVALID_PROTOCOL_VERSION"
    case resourceExhausted = "RESOURCE_EXHAUSTED"
    case timeout = "TIMEOUT"
    case transactionPending = "TRANSACTION_PENDING"
    case unknownMethod = "UNKNOWN_METHOD"
}

/// Advertised feature-gate names (x-reader-core-v1-capabilities).
/// These are capability gates, not 1:1 method names; keep them as raw wire strings.
public enum ReaderAdvertisedCapabilities {
    public static let names: [String] = [
        "core.info",
        "runtime.ping",
        "runtime.hostSmoke",
        "runtime.cancel",
        "runtime.status",
        "runtime.storage.restore",
        "runtime.storage.flush",
        "runtime.storage.export",
        "runtime.storage.apply",
        "runtime.shutdown",
        "runtime.setHostCapabilities",
        "host.complete",
        "host.error",
        "manga.chapter.v1",
        "manga.resource.prepare.v1",
        "manga.offline.v1",
        "manga.entry.v1",
        "manga.sourceSwitch.receipt.v1",
        "host.bus.v1",
        "http.execute",
        "runtime.config.v1",
        "remote.reading.v1",
        "rss.v1",
        "sync.v1",
        "local_book.v1",
        "bookshelf.v1",
        "search.content.cursor.v1",
        "chapter.content.cacheOnly.v1",
        "reading.document.window.v1",
        "reading.progress.compareAndSet.v1",
        "reading.progress.sourceFinalizeReceipt.v1",
        "reading.catalog.page.v1",
        "reading.directory.view.v1",
        "reading.directory.view.v2",
        "local_book.navigation.v1",
        "bookshelf.pageProjection.v1",
        "bookshelf.anchorPage.v1",
        "bookshelf.contentKindFilter.v1",
        "reading.preparation.v1",
        "reading.entry.prepare.v1",
        "reading.entry.localImageStyle.v1",
        "reading.entry.snapshot.v1",
        "reading.entry.firstFrame.v1",
        "reading.entry.snapshot.window.v1",
        "source.supply.v1",
        "source.list.byId.v1",
        "source.check.mode.v1",
        "host.http.timeout.v1",
        "source.check.report.v1",
        "source.check.report.v2",
        "rules.mutation.exact.v1",
        "rules.mutation.subscription.v1",
        "rules.mutation.conversion.v1",
        "bookshelf.managementMutation.v1",
        "rules.mutation.source-management.v1",
        "source.group.metadata.v1",
        "rules.mutation.source-groups.v1",
        "bookshelf.removalMutation.v1",
        "rules.mutation.rss-management.v1",
        "rules.mutation.directory-rules.v1",
        "library.metadataRestore.status.v1",
        "library.metadataRestore.apply.v1",
        "library.metadataExport.v1",
        "library.metadataInspect.v1",
        "sync.webdav.restoreSelection.v1",
        "local_book.originalExpectation.v1",
        "library.resourceBundle.v1",
        "library.resourceRestore.v1",
        "runtime.storage.backup.create",
        "runtime.storage.backup.restore",
        "source.check.keyword_override.v1",
        "source.check.ephemeral.v1",
        "source.check.report.clear.v1",
        "source.import.conditional.v1",
    ]
}

/// Method -> result data $ref name, from x-reader-core-v1-result-data-defs.
public enum ReaderResultDataDefs {
    public static let defByMethod: [String: String] = [
        "book-highlight.create": "BookHighlightCreateData",
        "book-highlight.list": "BookHighlightListData",
        "book-highlight.update": "BookHighlightUpdateData",
        "bookmark.create": "BookmarkCreateData",
        "bookmark.delete": "BookmarkDeleteData",
        "bookmark.list": "BookmarkListData",
        "bookmark.operation.query": "BookmarkOperationQueryData",
        "bookmark.operation.settle": "BookmarkOperationReceipt",
        "bookmark.update": "BookmarkUpdateData",
        "bookshelf.add": "BookshelfAddData",
        "bookshelf.book.update": "BookshelfBookUpdateData",
        "bookshelf.get": "BookshelfGetData",
        "bookshelf.list": "BookshelfListData",
        "bookshelf.management.mutation.apply": "BookshelfManagementReceipt",
        "bookshelf.management.mutation.query": "BookshelfManagementQueryData",
        "bookshelf.remove": "BookshelfRemoveData",
        "bookshelf.removeBatch": "BookshelfRemoveBatchData",
        "cache.book.prefetch": "CacheBookPrefetchData",
        "cache.book.status": "CacheBookStatusData",
        "cache.chapter.materialization.report": "CacheChapterMaterializationReportData",
        "cache.clear": "CacheClearData",
        "cache.clear.operation.query": "CacheClearOperationQueryData",
        "cache.clear.operation.settle": "CacheClearOperationReceipt",
        "cache.download.cancel": "CacheDownloadTaskResult",
        "cache.download.operation.query": "DownloadOperationQueryData",
        "cache.download.operation.settle": "DownloadOperationReceipt",
        "cache.download.pause": "CacheDownloadTaskResult",
        "cache.download.resume": "CacheDownloadTaskResult",
        "cache.storage.cleanup": "CacheStorageData",
        "cache.storage.summary": "CacheStorageData",
        "chapter.content": "ChapterContentData",
        "core.info": "CoreInfoData",
        "local.book.positionArchive.list": "LocalBookPositionArchiveListData",
        "local_book.chapter.content": "LocalBookChapterContentData",
        "local_book.chapter.presentation.v1": "LocalBookChapterPresentationData",
        "local_book.content.metrics": "LocalBookContentMetricsData",
        "local_book.navigation.backfill.v1": "LocalBookNavigationBackfillData",
        "local_book.presentation.kind.v1": "LocalBookPresentationKindData",
        "local_book.toc": "LocalBookTocData",
        "manga.cache.classify": "MangaCacheClassifyResult",
        "manga.cache.classifyBatch": "MangaCacheClassifyBatchResult",
        "manga.cache.evict": "MangaCacheEvictResult",
        "manga.cache.eviction.claim": "MangaCacheEvictionClaimResult",
        "manga.cache.eviction.complete": "MangaCacheEvictionCompleteResult",
        "manga.cache.eviction.pending": "MangaCacheEvictionPendingResult",
        "manga.cache.materialization.abort": "MangaCacheMaterializationAbortResult",
        "manga.cache.materialization.complete": "MangaCacheMaterializationCompleteResult",
        "manga.cache.materialization.prepare": "MangaCacheMaterializationPrepareResult",
        "manga.cache.recordRead": "MangaCacheRecordReadResult",
        "manga.chapter.get": "MangaChapterData",
        "manga.entry.get": "MangaEntryData",
        "manga.pages.window": "MangaChapterWindow",
        "manga.resource.inspect": "MangaResourceInspectData",
        "manga.resource.prepare": "MangaResourcePrepareData",
        "manga.retention.get": "MangaRetentionSetResult",
        "manga.retention.list": "MangaRetentionListResult",
        "manga.retention.set": "MangaRetentionSetResult",
        "manga.session.protect": "MangaSessionProtectResult",
        "manga.session.release": "MangaSessionReleaseResult",
        "manga.session.replace": "MangaSessionReplaceResult",
        "manga.session.runtime": "MangaSessionRuntimeResult",
        "manga.sourceSwitch.commit": "MangaSourceSwitchData",
        "manga.sourceSwitch.commit.v2": "MangaSourceSwitchOperationReceipt",
        "manga.sourceSwitch.operation.query.v1": "MangaSourceSwitchOperationQueryData",
        "read-record.accumulate": "ReadRecordAccumulateData",
        "read-record.accumulate-receipt": "ReadRecordAccumulateReceiptData",
        "read-record.clear": "ReadRecordClearData",
        "read-record.create": "ReadRecordCreateData",
        "read-record.delete": "ReadRecordDeleteData",
        "read-record.deleteByBook": "ReadRecordDeleteByBookData",
        "read-record.list": "ReadRecordListData",
        "read-record.summary": "ReadRecordSummaryData",
        "read-record.update": "ReadRecordUpdateData",
        "reading.directory.rules.apply.v2": "DirectoryRulesDataV2",
        "reading.directory.rules.get.v2": "DirectoryRulesDataV2",
        "reading.directory.rules.prepare.v2": "DirectoryRulesDataV2",
        "reading.directory.rules.preview.v2": "DirectoryRulesDataV2",
        "reading.directory.target.resolve.v2": "DirectoryTargetResolveDataV2",
        "reading.directory.view.open.v1": "DirectoryViewOpenData",
        "reading.directory.view.open.v2": "DirectoryViewOpenDataV2",
        "reading.directory.view.page.v1": "DirectoryViewPageData",
        "reading.directory.view.page.v2": "DirectoryViewPageDataV2",
        "reading.directory.view.target.resolve.v1": "DirectoryViewTargetResolveData",
        "reading.progress.get": "ReadingProgressGetData",
        "reading.progress.update": "ReadingProgressUpdateData",
        "replace.apply": "ReplaceApplyData",
        "replace.persist": "ReplacePersistData",
        "replace.preview": "ReplacePreviewData",
        "replace.undo": "ReplaceUndoData",
        "replace.validate": "ReplaceValidateData",
        "rules.mutation.apply": "RulesMutationReceipt",
        "rules.mutation.query": "RulesMutationQueryData",
        "runtime.setHostCapabilities": "RuntimeSetHostCapabilitiesData",
        "runtime.status": "RuntimeStatusData",
        "runtime.storage.backup.create": "RuntimeStorageBackupCreateData",
        "runtime.storage.backup.restore": "RuntimeStorageBackupRestoreData",
        "search-book.batch.get": "SearchBookBatchGetData",
        "search-book.related": "SearchBookRelatedData",
        "search.content": "SearchContentData",
        "source.check.ephemeral.run": "SourceCheckResultData",
        "source.check.report.clear": "SourceCheckReportClearData",
        "source.check.run": "SourceCheckResultData",
        "source.group.catalog": "SourceGroupCatalogData",
        "source.switch.commit": "SourceSwitchCommitData",
        "source.switch.finalize": "SourceSwitchFinalizeData",
        "source.switch.pending.list": "SourceSwitchPendingListData",
        "source.switch.recover": "SourceSwitchRecoverData",
        "source.switch.rollback": "SourceSwitchRollbackData",
        "source.switch.transaction.query": "SourceSwitchTransactionQueryData",
        "sync.backup.auto.decision": "SyncBackupAutoDecisionData",
        "sync.backup.content.plan": "SyncBackupContentPlanData",
        "sync.backup.restore.scope.plan": "SyncBackupRestoreScopePlanData",
        "sync.webdav.backup.receipt.query": "SyncWebDavBackupReceiptData",
        "sync.webdav.backup.retention.skip": "SyncWebDavBackupReceiptData",
        "sync.webdav.directory.list.plan": "SyncWebDavDirectoryListPlanData",
        "sync.webdav.multistatus.parse": "SyncWebDavMultistatusParseData",
        "sync.webdav.progress.merge": "SyncWebDavProgressMergeData",
        "sync.webdav.progress.push.plan": "SyncWebDavProgressPushPlanData",
        "sync.webdav.remote-book.local-import.plan": "SyncWebDavRemoteBookLocalImportPlanData",
        "sync.webdav.remote-book.plan": "SyncWebDavRemoteBookPlanData",
        "sync.webdav.remote-book.result": "SyncWebDavRemoteBookResultData",
        "sync.webdav.transaction.abort": "SyncWebDavTransactionData",
        "sync.webdav.transaction.advance": "SyncWebDavTransactionData",
        "sync.webdav.transaction.commit": "SyncWebDavTransactionData",
        "sync.webdav.transaction.resolve": "SyncWebDavTransactionData",
        "sync.webdav.transaction.start": "SyncWebDavTransactionData",
    ]
}

/// Structured Core error carried by `error` events.
public struct ReaderCoreError: Codable, Sendable, Equatable {
    public let code: ReaderErrorCode
    public let message: String
    public let retryable: Bool
    public let details: [String: ReaderJSONValue]?

    public init(code: ReaderErrorCode, message: String, retryable: Bool, details: [String: ReaderJSONValue]? = nil) {
        self.code = code
        self.message = message
        self.retryable = retryable
        self.details = details
    }
}

/// Command envelope. `params` is a dynamic object because v1 is method-polymorphic;
/// typed bodies are published below and selected by ReaderCommandMethod.
public struct ReaderCommandEnvelope: Codable, Sendable {
    public let protocolVersion: Int
    public let requestId: Int64
    public let method: ReaderCommandMethod
    public let params: [String: ReaderJSONValue]?

    public init(requestId: Int64, method: ReaderCommandMethod, params: [String: ReaderJSONValue]? = nil, protocolVersion: Int = 1) {
        self.protocolVersion = protocolVersion
        self.requestId = requestId
        self.method = method
        self.params = params
    }
}

/// Event envelopes from reader-event.schema.json (oneOf over 3 shapes).
public struct ReaderResultEvent: Codable, Sendable {
    public let deliveryId: Int64?
    public let protocolVersion: Int
    public let requestId: Int64
    public let type: String
    public let data: [String: ReaderJSONValue]
}

public struct ReaderErrorEvent: Codable, Sendable {
    public let deliveryId: Int64?
    public let protocolVersion: Int
    public let requestId: Int64
    public let type: String
    public let error: ReaderCoreError
}

public struct ReaderHostRequestEvent: Codable, Sendable {
    public let deliveryId: Int64?
    public let protocolVersion: Int
    public let requestId: Int64
    public let type: String
    public let operationId: Int64
    public let capability: ReaderHostCapability
    public let params: [String: ReaderJSONValue]
}

/// Event kinds declared by the schema: result, error, host.request.
public enum ReaderEventKinds {
    public static let wires: [String] = ["result", "error", "host.request"]
}

/// Storage format selection for a fresh runtime directory.
public enum ReaderFreshStorageFormat: String, Codable, Sendable, CaseIterable {
    case library47 = "library47"
}

/// Runtime config (reader-runtime-config.schema.json).
public struct ReaderRuntimeConfig: Codable, Sendable {
    public let dataDirectory: String?
    public let cacheDirectory: String?
    public let storageMigration: ReaderStorageMigration?
    public let freshStorageFormat: ReaderFreshStorageFormat?
    public init(dataDirectory: String? = nil, cacheDirectory: String? = nil, storageMigration: ReaderStorageMigration? = nil, freshStorageFormat: ReaderFreshStorageFormat? = nil) {
        self.dataDirectory = dataDirectory
        self.cacheDirectory = cacheDirectory
        self.storageMigration = storageMigration
        self.freshStorageFormat = freshStorageFormat
    }
}

public struct ReaderStorageMigration: Codable, Sendable {
    public let sourceSchemaVersion: Int64
    public let targetSchemaVersion: Int64
    public init(sourceSchemaVersion: Int64, targetSchemaVersion: Int64) {
        self.sourceSchemaVersion = sourceSchemaVersion
        self.targetSchemaVersion = targetSchemaVersion
    }
}

// Command params models: 230 definitions.
/// Params schema `BookChapterReviewParams` (7 declared properties).
public struct BookChapterReviewParams: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterUrl: String?
    public let reviewResponse: String?
    public let reviewRequest: ReaderJSONValue?
    public let source: ReaderJSONValue?
    public let reviewUrl: String?

    public init(sourceId: String, bookId: String, chapterUrl: String? = nil, reviewResponse: String? = nil, reviewRequest: ReaderJSONValue? = nil, source: ReaderJSONValue? = nil, reviewUrl: String? = nil) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterUrl = chapterUrl
        self.reviewResponse = reviewResponse
        self.reviewRequest = reviewRequest
        self.source = source
        self.reviewUrl = reviewUrl
    }
}

/// Params schema `BookDetailParams` (6 declared properties).
public struct BookDetailParams: Codable, Sendable {
    public let preparationRevision: Int64?
    public let sourceId: String
    public let book: ReaderJSONValue
    public let detailResponse: String?
    public let detailRequest: ReaderJSONValue?
    public let source: ReaderJSONValue?

    public init(preparationRevision: Int64? = nil, sourceId: String, book: ReaderJSONValue, detailResponse: String? = nil, detailRequest: ReaderJSONValue? = nil, source: ReaderJSONValue? = nil) {
        self.preparationRevision = preparationRevision
        self.sourceId = sourceId
        self.book = book
        self.detailResponse = detailResponse
        self.detailRequest = detailRequest
        self.source = source
    }
}

/// Params schema `BookHighlightCreateParams` (14 declared properties).
public struct BookHighlightCreateParams: Codable, Sendable {
    public let time: ReaderJSONValue?
    public let bookUrl: String?
    public let chapterUrl: String?
    public let bookName: String?
    public let bookAuthor: String?
    public let chapterIndex: Int64?
    public let chapterPos: Int64?
    public let chapterPosEnd: Int64?
    public let layoutTitleLength: Int64?
    public let chapterName: String?
    public let bookText: String?
    public let style: String?
    public let note: String?
    public let positionScope: ReaderJSONValue?

    public init(time: ReaderJSONValue? = nil, bookUrl: String? = nil, chapterUrl: String? = nil, bookName: String? = nil, bookAuthor: String? = nil, chapterIndex: Int64? = nil, chapterPos: Int64? = nil, chapterPosEnd: Int64? = nil, layoutTitleLength: Int64? = nil, chapterName: String? = nil, bookText: String? = nil, style: String? = nil, note: String? = nil, positionScope: ReaderJSONValue? = nil) {
        self.time = time
        self.bookUrl = bookUrl
        self.chapterUrl = chapterUrl
        self.bookName = bookName
        self.bookAuthor = bookAuthor
        self.chapterIndex = chapterIndex
        self.chapterPos = chapterPos
        self.chapterPosEnd = chapterPosEnd
        self.layoutTitleLength = layoutTitleLength
        self.chapterName = chapterName
        self.bookText = bookText
        self.style = style
        self.note = note
        self.positionScope = positionScope
    }
}

/// Params schema `BookHighlightUpdateParams` (14 declared properties).
public struct BookHighlightUpdateParams: Codable, Sendable {
    public let time: Int64
    public let bookUrl: ReaderJSONValue?
    public let chapterUrl: ReaderJSONValue?
    public let bookName: ReaderJSONValue?
    public let bookAuthor: ReaderJSONValue?
    public let chapterIndex: ReaderJSONValue?
    public let chapterPos: ReaderJSONValue?
    public let chapterPosEnd: ReaderJSONValue?
    public let layoutTitleLength: ReaderJSONValue?
    public let chapterName: ReaderJSONValue?
    public let bookText: ReaderJSONValue?
    public let style: ReaderJSONValue?
    public let note: ReaderJSONValue?
    public let positionScope: ReaderJSONValue?

    public init(time: Int64, bookUrl: ReaderJSONValue? = nil, chapterUrl: ReaderJSONValue? = nil, bookName: ReaderJSONValue? = nil, bookAuthor: ReaderJSONValue? = nil, chapterIndex: ReaderJSONValue? = nil, chapterPos: ReaderJSONValue? = nil, chapterPosEnd: ReaderJSONValue? = nil, layoutTitleLength: ReaderJSONValue? = nil, chapterName: ReaderJSONValue? = nil, bookText: ReaderJSONValue? = nil, style: ReaderJSONValue? = nil, note: ReaderJSONValue? = nil, positionScope: ReaderJSONValue? = nil) {
        self.time = time
        self.bookUrl = bookUrl
        self.chapterUrl = chapterUrl
        self.bookName = bookName
        self.bookAuthor = bookAuthor
        self.chapterIndex = chapterIndex
        self.chapterPos = chapterPos
        self.chapterPosEnd = chapterPosEnd
        self.layoutTitleLength = layoutTitleLength
        self.chapterName = chapterName
        self.bookText = bookText
        self.style = style
        self.note = note
        self.positionScope = positionScope
    }
}

/// Params schema `BookSearchParams` (6 declared properties).
public struct BookSearchParams: Codable, Sendable {
    public let sourceId: String
    public let searchResponse: String?
    public let searchRequest: ReaderJSONValue?
    public let source: ReaderJSONValue?
    public let keyword: String?
    public let page: Int64?

    public init(sourceId: String, searchResponse: String? = nil, searchRequest: ReaderJSONValue? = nil, source: ReaderJSONValue? = nil, keyword: String? = nil, page: Int64? = nil) {
        self.sourceId = sourceId
        self.searchResponse = searchResponse
        self.searchRequest = searchRequest
        self.source = source
        self.keyword = keyword
        self.page = page
    }
}

/// Params schema `BookTocParams` (8 declared properties).
public struct BookTocParams: Codable, Sendable {
    public let preparationRevision: Int64?
    public let sourceId: String
    public let bookId: String
    public let tocResponse: String?
    public let tocRequest: ReaderJSONValue?
    public let source: ReaderJSONValue?
    public let tocUrl: String?
    public let variables: ReaderJSONValue?

    public init(preparationRevision: Int64? = nil, sourceId: String, bookId: String, tocResponse: String? = nil, tocRequest: ReaderJSONValue? = nil, source: ReaderJSONValue? = nil, tocUrl: String? = nil, variables: ReaderJSONValue? = nil) {
        self.preparationRevision = preparationRevision
        self.sourceId = sourceId
        self.bookId = bookId
        self.tocResponse = tocResponse
        self.tocRequest = tocRequest
        self.source = source
        self.tocUrl = tocUrl
        self.variables = variables
    }
}

/// Params schema `BookshelfGroupAssignParams` (3 declared properties).
public struct BookshelfGroupAssignParams: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let group: String

    public init(sourceId: String, bookId: String, group: String) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.group = group
    }
}

/// Params schema `BookshelfManagementApplyParams` (3 declared properties).
public struct BookshelfManagementApplyParams: Codable, Sendable {
    public let operationId: String
    public let sequence: Int64
    public let mutation: ReaderJSONValue

    public init(operationId: String, sequence: Int64, mutation: ReaderJSONValue) {
        self.operationId = operationId
        self.sequence = sequence
        self.mutation = mutation
    }
}

/// Params schema `BookshelfManagementQueryParams` (2 declared properties).
public struct BookshelfManagementQueryParams: Codable, Sendable {
    public let operationId: ReaderJSONValue?
    public let expected: ReaderJSONValue?

    public init(operationId: ReaderJSONValue? = nil, expected: ReaderJSONValue? = nil) {
        self.operationId = operationId
        self.expected = expected
    }
}

/// Params schema `CacheBookPrefetchParams` (9 declared properties).
public struct CacheBookPrefetchParams: Codable, Sendable {
    public let preparationRevision: Int64?
    public let sourceId: String
    public let bookId: String
    public let chapterRange: [ReaderJSONValue]
    public let priority: Int64?
    public let requestedAt: Int64?
    public let contentKind: String?
    public let operationId: String?
    public let sequence: Int64?

    public init(preparationRevision: Int64? = nil, sourceId: String, bookId: String, chapterRange: [ReaderJSONValue], priority: Int64? = nil, requestedAt: Int64? = nil, contentKind: String? = nil, operationId: String? = nil, sequence: Int64? = nil) {
        self.preparationRevision = preparationRevision
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterRange = chapterRange
        self.priority = priority
        self.requestedAt = requestedAt
        self.contentKind = contentKind
        self.operationId = operationId
        self.sequence = sequence
    }
}

/// Params schema `CacheBookStatusParams` (2 declared properties).
public struct CacheBookStatusParams: Codable, Sendable {
    public let sourceId: String
    public let bookId: String

    public init(sourceId: String, bookId: String) {
        self.sourceId = sourceId
        self.bookId = bookId
    }
}

/// Params schema `CacheChapterMaterializationReportParams` (10 declared properties).
public struct CacheChapterMaterializationReportParams: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: Int64
    public let token: String
    public let outcome: String
    public let errorCode: String?
    public let reportedAt: Int64?
    public let manga: ReaderJSONValue?
    public let operationId: String?
    public let sequence: Int64?

    public init(sourceId: String, bookId: String, chapterIndex: Int64, token: String, outcome: String, errorCode: String? = nil, reportedAt: Int64? = nil, manga: ReaderJSONValue? = nil, operationId: String? = nil, sequence: Int64? = nil) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterIndex = chapterIndex
        self.token = token
        self.outcome = outcome
        self.errorCode = errorCode
        self.reportedAt = reportedAt
        self.manga = manga
        self.operationId = operationId
        self.sequence = sequence
    }
}

/// Params schema `CacheClearOperationQueryParams` (2 declared properties).
public struct CacheClearOperationQueryParams: Codable, Sendable {
    public let operationId: ReaderJSONValue?
    public let expected: ReaderJSONValue?

    public init(operationId: ReaderJSONValue? = nil, expected: ReaderJSONValue? = nil) {
        self.operationId = operationId
        self.expected = expected
    }
}

/// Params schema `CacheClearParams` has no declared properties.
public struct CacheClearParams: Codable, Sendable {
    public init() {}
}

/// Params schema `CacheDownloadTaskParams` (6 declared properties).
public struct CacheDownloadTaskParams: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: Int64
    public let now: Int64?
    public let operationId: String?
    public let sequence: Int64?

    public init(sourceId: String, bookId: String, chapterIndex: Int64, now: Int64? = nil, operationId: String? = nil, sequence: Int64? = nil) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterIndex = chapterIndex
        self.now = now
        self.operationId = operationId
        self.sequence = sequence
    }
}

/// Params schema `CacheStorageParams` (10 declared properties).
public struct CacheStorageParams: Codable, Sendable {
    public let retainCompletedQueue: Bool?
    public let retainedChapters: [ReaderJSONValue]?
    public let protectedChapters: [ReaderJSONValue]?
    public let reason: String?
    public let nowSeconds: ReaderJSONValue?
    public let ttlSeconds: ReaderJSONValue?
    public let capacityBytes: ReaderJSONValue?
    public let hostImageChapters: [ReaderJSONValue]?
    public let completedQueueAfter: ReaderJSONValue?
    public let contentScope: String?

    public init(retainCompletedQueue: Bool? = nil, retainedChapters: [ReaderJSONValue]? = nil, protectedChapters: [ReaderJSONValue]? = nil, reason: String? = nil, nowSeconds: ReaderJSONValue? = nil, ttlSeconds: ReaderJSONValue? = nil, capacityBytes: ReaderJSONValue? = nil, hostImageChapters: [ReaderJSONValue]? = nil, completedQueueAfter: ReaderJSONValue? = nil, contentScope: String? = nil) {
        self.retainCompletedQueue = retainCompletedQueue
        self.retainedChapters = retainedChapters
        self.protectedChapters = protectedChapters
        self.reason = reason
        self.nowSeconds = nowSeconds
        self.ttlSeconds = ttlSeconds
        self.capacityBytes = capacityBytes
        self.hostImageChapters = hostImageChapters
        self.completedQueueAfter = completedQueueAfter
        self.contentScope = contentScope
    }
}

/// Params schema `ChangeBookSourceParams` (4 declared properties).
public struct ChangeBookSourceParams: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let keyword: String?
    public let sourceIds: [String]

    public init(sourceId: String, bookId: String, keyword: String? = nil, sourceIds: [String]) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.keyword = keyword
        self.sourceIds = sourceIds
    }
}

/// Params schema `ChangeCoverParams` (3 declared properties).
public struct ChangeCoverParams: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let sourceIds: [String]

    public init(sourceId: String, bookId: String, sourceIds: [String]) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.sourceIds = sourceIds
    }
}

/// Params schema `ChapterContentParams` (16 declared properties).
public struct ChapterContentParams: Codable, Sendable {
    public let directoryTargetProof: ReaderJSONValue?
    public let preparationRevision: Int64?
    public let cacheOnly: Bool?
    public let forceRefresh: Bool?
    public let sourceId: String
    public let bookId: String
    public let chapterTitle: String?
    public let chapterIndex: Int64?
    public let chapterResponse: String?
    public let chapterRequest: ReaderJSONValue?
    public let jsRule: String?
    public let source: ReaderJSONValue?
    public let chapterUrl: String?
    public let variables: ReaderJSONValue?
    public let upgradeCachedContent: Bool?
    public let positionContext: ReaderJSONValue?

    public init(directoryTargetProof: ReaderJSONValue? = nil, preparationRevision: Int64? = nil, cacheOnly: Bool? = nil, forceRefresh: Bool? = nil, sourceId: String, bookId: String, chapterTitle: String? = nil, chapterIndex: Int64? = nil, chapterResponse: String? = nil, chapterRequest: ReaderJSONValue? = nil, jsRule: String? = nil, source: ReaderJSONValue? = nil, chapterUrl: String? = nil, variables: ReaderJSONValue? = nil, upgradeCachedContent: Bool? = nil, positionContext: ReaderJSONValue? = nil) {
        self.directoryTargetProof = directoryTargetProof
        self.preparationRevision = preparationRevision
        self.cacheOnly = cacheOnly
        self.forceRefresh = forceRefresh
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterTitle = chapterTitle
        self.chapterIndex = chapterIndex
        self.chapterResponse = chapterResponse
        self.chapterRequest = chapterRequest
        self.jsRule = jsRule
        self.source = source
        self.chapterUrl = chapterUrl
        self.variables = variables
        self.upgradeCachedContent = upgradeCachedContent
        self.positionContext = positionContext
    }
}

/// Params schema `ChineseConversionPutParams` (1 declared properties).
public struct ChineseConversionPutParams: Codable, Sendable {
    public let mode: ReaderJSONValue

    public init(mode: ReaderJSONValue) {
        self.mode = mode
    }
}

/// Params schema `ContentEditDeleteParams` (3 declared properties).
public struct ContentEditDeleteParams: Codable, Sendable {
    public let editId: Int64?
    public let sourceId: String?
    public let bookId: String?

    public init(editId: Int64? = nil, sourceId: String? = nil, bookId: String? = nil) {
        self.editId = editId
        self.sourceId = sourceId
        self.bookId = bookId
    }
}

/// Params schema `ContentEditGetParams` (3 declared properties).
public struct ContentEditGetParams: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: Int64

    public init(sourceId: String, bookId: String, chapterIndex: Int64) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterIndex = chapterIndex
    }
}

/// Params schema `ContentEditListParams` (2 declared properties).
public struct ContentEditListParams: Codable, Sendable {
    public let sourceId: String
    public let bookId: String

    public init(sourceId: String, bookId: String) {
        self.sourceId = sourceId
        self.bookId = bookId
    }
}

/// Params schema `ContentEditPutParams` (5 declared properties).
public struct ContentEditPutParams: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: Int64
    public let editedContent: String?
    public let editedAt: Int64?

    public init(sourceId: String, bookId: String, chapterIndex: Int64, editedContent: String? = nil, editedAt: Int64? = nil) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterIndex = chapterIndex
        self.editedContent = editedContent
        self.editedAt = editedAt
    }
}

/// Params schema `DictRuleDeleteParams` (1 declared properties).
public struct DictRuleDeleteParams: Codable, Sendable {
    public let name: String

    public init(name: String) {
        self.name = name
    }
}

/// Params schema `DictRulePutParams` (5 declared properties).
public struct DictRulePutParams: Codable, Sendable {
    public let name: String
    public let urlRule: String?
    public let showRule: String?
    public let enabled: Bool?
    public let sortNumber: Int64?

    public init(name: String, urlRule: String? = nil, showRule: String? = nil, enabled: Bool? = nil, sortNumber: Int64? = nil) {
        self.name = name
        self.urlRule = urlRule
        self.showRule = showRule
        self.enabled = enabled
        self.sortNumber = sortNumber
    }
}

/// Params schema `DictRuleQueryParams` (4 declared properties).
public struct DictRuleQueryParams: Codable, Sendable {
    public let ruleName: String
    public let word: String
    public let dictResponse: String?
    public let dictRequest: ReaderJSONValue?

    public init(ruleName: String, word: String, dictResponse: String? = nil, dictRequest: ReaderJSONValue? = nil) {
        self.ruleName = ruleName
        self.word = word
        self.dictResponse = dictResponse
        self.dictRequest = dictRequest
    }
}

/// Params schema `DirectoryRulesParamsV2` (3 declared properties).
public struct DirectoryRulesParamsV2: Codable, Sendable {
    public let sourceId: ReaderJSONValue
    public let bookId: String
    public let rules: [ReaderJSONValue]

    public init(sourceId: ReaderJSONValue, bookId: String, rules: [ReaderJSONValue]) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.rules = rules
    }
}

/// Params schema `DirectoryRulesPrepareParamsV2` (3 declared properties).
public struct DirectoryRulesPrepareParamsV2: Codable, Sendable {
    public let sourceId: ReaderJSONValue
    public let bookId: String
    public let rules: [ReaderJSONValue]?

    public init(sourceId: ReaderJSONValue, bookId: String, rules: [ReaderJSONValue]? = nil) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.rules = rules
    }
}

/// Params schema `DirectoryTargetResolveParamsV2` (6 declared properties).
public struct DirectoryTargetResolveParamsV2: Codable, Sendable {
    public let bookId: String
    public let viewId: String
    public let nodeId: String
    public let sourceId: String
    public let catalogRevision: String
    public let structureRevision: String

    public init(bookId: String, viewId: String, nodeId: String, sourceId: String, catalogRevision: String, structureRevision: String) {
        self.bookId = bookId
        self.viewId = viewId
        self.nodeId = nodeId
        self.sourceId = sourceId
        self.catalogRevision = catalogRevision
        self.structureRevision = structureRevision
    }
}

/// Params schema `DirectoryViewOpenParams` (8 declared properties).
public struct DirectoryViewOpenParams: Codable, Sendable {
    public let bookId: String
    public let collapsedNodeIds: [String]?
    public let query: String?
    public let descending: Bool?
    public let chapterIndex: Int64?
    public let chapterOffsetScalar: Int64?
    public let anchorNodeId: String?
    public let limit: Int64?

    public init(bookId: String, collapsedNodeIds: [String]? = nil, query: String? = nil, descending: Bool? = nil, chapterIndex: Int64? = nil, chapterOffsetScalar: Int64? = nil, anchorNodeId: String? = nil, limit: Int64? = nil) {
        self.bookId = bookId
        self.collapsedNodeIds = collapsedNodeIds
        self.query = query
        self.descending = descending
        self.chapterIndex = chapterIndex
        self.chapterOffsetScalar = chapterOffsetScalar
        self.anchorNodeId = anchorNodeId
        self.limit = limit
    }
}

/// Params schema `DirectoryViewOpenParamsV2` (9 declared properties).
public struct DirectoryViewOpenParamsV2: Codable, Sendable {
    public let bookId: String
    public let collapsedNodeIds: [String]?
    public let query: String?
    public let descending: Bool?
    public let chapterIndex: Int64?
    public let chapterOffsetScalar: Int64?
    public let anchorNodeId: String?
    public let limit: Int64?
    public let sourceId: String

    public init(bookId: String, collapsedNodeIds: [String]? = nil, query: String? = nil, descending: Bool? = nil, chapterIndex: Int64? = nil, chapterOffsetScalar: Int64? = nil, anchorNodeId: String? = nil, limit: Int64? = nil, sourceId: String) {
        self.bookId = bookId
        self.collapsedNodeIds = collapsedNodeIds
        self.query = query
        self.descending = descending
        self.chapterIndex = chapterIndex
        self.chapterOffsetScalar = chapterOffsetScalar
        self.anchorNodeId = anchorNodeId
        self.limit = limit
        self.sourceId = sourceId
    }
}

/// Params schema `DirectoryViewPageParams` (4 declared properties).
public struct DirectoryViewPageParams: Codable, Sendable {
    public let bookId: String
    public let viewId: String
    public let offset: Int64
    public let limit: Int64

    public init(bookId: String, viewId: String, offset: Int64, limit: Int64) {
        self.bookId = bookId
        self.viewId = viewId
        self.offset = offset
        self.limit = limit
    }
}

/// Params schema `DirectoryViewPageParamsV2` (7 declared properties).
public struct DirectoryViewPageParamsV2: Codable, Sendable {
    public let bookId: String
    public let viewId: String
    public let offset: Int64
    public let limit: Int64
    public let sourceId: String
    public let catalogRevision: String
    public let structureRevision: String

    public init(bookId: String, viewId: String, offset: Int64, limit: Int64, sourceId: String, catalogRevision: String, structureRevision: String) {
        self.bookId = bookId
        self.viewId = viewId
        self.offset = offset
        self.limit = limit
        self.sourceId = sourceId
        self.catalogRevision = catalogRevision
        self.structureRevision = structureRevision
    }
}

/// Params schema `DirectoryViewTargetResolveParams` (3 declared properties).
public struct DirectoryViewTargetResolveParams: Codable, Sendable {
    public let bookId: String
    public let viewId: String
    public let nodeId: String

    public init(bookId: String, viewId: String, nodeId: String) {
        self.bookId = bookId
        self.viewId = viewId
        self.nodeId = nodeId
    }
}

/// Params schema `DownloadOperationQueryParams` (6 declared properties).
public struct DownloadOperationQueryParams: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let operationId: String?
    public let expected: ReaderJSONValue?
    public let action: String
    public let chapterIndex: Int64?

    public init(sourceId: String, bookId: String, operationId: String? = nil, expected: ReaderJSONValue? = nil, action: String, chapterIndex: Int64? = nil) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.operationId = operationId
        self.expected = expected
        self.action = action
        self.chapterIndex = chapterIndex
    }
}

/// Params schema `DownloadOperationSettleParams` (7 declared properties).
public struct DownloadOperationSettleParams: Codable, Sendable {
    public let operationId: String
    public let sequence: Int64
    public let payloadFingerprint: String
    public let sourceId: String
    public let bookId: String
    public let action: String
    public let chapterIndex: Int64?

    public init(operationId: String, sequence: Int64, payloadFingerprint: String, sourceId: String, bookId: String, action: String, chapterIndex: Int64? = nil) {
        self.operationId = operationId
        self.sequence = sequence
        self.payloadFingerprint = payloadFingerprint
        self.sourceId = sourceId
        self.bookId = bookId
        self.action = action
        self.chapterIndex = chapterIndex
    }
}

/// Params schema `HostCacheGetRequest` (2 declared properties).
public struct HostCacheGetRequest: Codable, Sendable {
    public let namespace: String
    public let key: String

    public init(namespace: String, key: String) {
        self.namespace = namespace
        self.key = key
    }
}

/// Params schema `HostCachePutRequest` (5 declared properties).
public struct HostCachePutRequest: Codable, Sendable {
    public let namespace: String
    public let key: String
    public let value: String?
    public let valueBase64: String?
    public let ttlMillis: Int64?

    public init(namespace: String, key: String, value: String? = nil, valueBase64: String? = nil, ttlMillis: Int64? = nil) {
        self.namespace = namespace
        self.key = key
        self.value = value
        self.valueBase64 = valueBase64
        self.ttlMillis = ttlMillis
    }
}

/// Params schema `HostCompleteParams` (2 declared properties).
public struct HostCompleteParams: Codable, Sendable {
    public let operationId: Int64
    public let result: ReaderJSONValue

    public init(operationId: Int64, result: ReaderJSONValue) {
        self.operationId = operationId
        self.result = result
    }
}

/// Params schema `HostCookieSetRequest` (3 declared properties).
public struct HostCookieSetRequest: Codable, Sendable {
    public let cookie: ReaderJSONValue
    public let url: String?
    public let sessionId: String?

    public init(cookie: ReaderJSONValue, url: String? = nil, sessionId: String? = nil) {
        self.cookie = cookie
        self.url = url
        self.sessionId = sessionId
    }
}

/// Params schema `HostFileReadRequest` (4 declared properties).
public struct HostFileReadRequest: Codable, Sendable {
    public let path: String
    public let encoding: String?
    public let byteOffset: Int64?
    public let maxBytes: Int64?

    public init(path: String, encoding: String? = nil, byteOffset: Int64? = nil, maxBytes: Int64? = nil) {
        self.path = path
        self.encoding = encoding
        self.byteOffset = byteOffset
        self.maxBytes = maxBytes
    }
}

/// Params schema `HostFileWriteRequest` (6 declared properties).
public struct HostFileWriteRequest: Codable, Sendable {
    public let path: String
    public let content: String?
    public let contentBase64: String?
    public let encoding: String?
    public let createDirectories: Bool?
    public let append: Bool?

    public init(path: String, content: String? = nil, contentBase64: String? = nil, encoding: String? = nil, createDirectories: Bool? = nil, append: Bool? = nil) {
        self.path = path
        self.content = content
        self.contentBase64 = contentBase64
        self.encoding = encoding
        self.createDirectories = createDirectories
        self.append = append
    }
}

/// Params schema `HostLogEmitRequest` (4 declared properties).
public struct HostLogEmitRequest: Codable, Sendable {
    public let level: ReaderJSONValue
    public let message: String
    public let target: String?
    public let fields: ReaderJSONValue?

    public init(level: ReaderJSONValue, message: String, target: String? = nil, fields: ReaderJSONValue? = nil) {
        self.level = level
        self.message = message
        self.target = target
        self.fields = fields
    }
}

/// Params schema `HostPersistenceGetRequest` (2 declared properties).
public struct HostPersistenceGetRequest: Codable, Sendable {
    public let namespace: String
    public let key: String

    public init(namespace: String, key: String) {
        self.namespace = namespace
        self.key = key
    }
}

/// Params schema `HostPersistencePutRequest` (5 declared properties).
public struct HostPersistencePutRequest: Codable, Sendable {
    public let namespace: String
    public let key: String
    public let value: String?
    public let valueBase64: String?
    public let expectedRevision: String?

    public init(namespace: String, key: String, value: String? = nil, valueBase64: String? = nil, expectedRevision: String? = nil) {
        self.namespace = namespace
        self.key = key
        self.value = value
        self.valueBase64 = valueBase64
        self.expectedRevision = expectedRevision
    }
}

/// Params schema `HostSmokeParams` (2 declared properties).
public struct HostSmokeParams: Codable, Sendable {
    public let capability: ReaderJSONValue?
    public let params: ReaderJSONValue?

    public init(capability: ReaderJSONValue? = nil, params: ReaderJSONValue? = nil) {
        self.capability = capability
        self.params = params
    }
}

/// Params schema `HostSystemInfoRequest` (1 declared properties).
public struct HostSystemInfoRequest: Codable, Sendable {
    public let keys: [String]?

    public init(keys: [String]? = nil) {
        self.keys = keys
    }
}

/// Params schema `HostWebViewEvaluateJavaScriptRequest` (7 declared properties).
public struct HostWebViewEvaluateJavaScriptRequest: Codable, Sendable {
    public let resourceUrlMatcherJavaScript: String?
    public let document: ReaderJSONValue
    public let javaScript: String
    public let headers: ReaderJSONValue?
    public let settleDelayMillis: Int64?
    public let timeoutMillis: Int64?
    public let profileId: String?

    public init(resourceUrlMatcherJavaScript: String? = nil, document: ReaderJSONValue, javaScript: String, headers: ReaderJSONValue? = nil, settleDelayMillis: Int64? = nil, timeoutMillis: Int64? = nil, profileId: String? = nil) {
        self.resourceUrlMatcherJavaScript = resourceUrlMatcherJavaScript
        self.document = document
        self.javaScript = javaScript
        self.headers = headers
        self.settleDelayMillis = settleDelayMillis
        self.timeoutMillis = timeoutMillis
        self.profileId = profileId
    }
}

/// Params schema `ImportFinalizeParams` has no declared properties.
public struct ImportFinalizeParams: Codable, Sendable {
    public init() {}
}

/// Params schema `ImportParseParams` has no declared properties.
public struct ImportParseParams: Codable, Sendable {
    public init() {}
}

/// Params schema `ImportPersistParams` has no declared properties.
public struct ImportPersistParams: Codable, Sendable {
    public init() {}
}

/// Params schema `ImportRollbackParams` has no declared properties.
public struct ImportRollbackParams: Codable, Sendable {
    public init() {}
}

/// Params schema `LocalBookCatalogParams` (4 declared properties).
public struct LocalBookCatalogParams: Codable, Sendable {
    public let catalog: ReaderJSONValue
    public let entry: ReaderJSONValue
    public let chapters: [ReaderJSONValue]?
    public let resources: [ReaderJSONValue]?

    public init(catalog: ReaderJSONValue, entry: ReaderJSONValue, chapters: [ReaderJSONValue]? = nil, resources: [ReaderJSONValue]? = nil) {
        self.catalog = catalog
        self.entry = entry
        self.chapters = chapters
        self.resources = resources
    }
}

/// Params schema `LocalBookContentMetricsParams` (1 declared properties).
public struct LocalBookContentMetricsParams: Codable, Sendable {
    public let bookId: String

    public init(bookId: String) {
        self.bookId = bookId
    }
}

/// Params schema `LocalBookNavigationBackfillParams` (2 declared properties).
public struct LocalBookNavigationBackfillParams: Codable, Sendable {
    public let bookId: String
    public let filePath: String

    public init(bookId: String, filePath: String) {
        self.bookId = bookId
        self.filePath = filePath
    }
}

/// Params schema `LocalBookPositionArchiveListParams` (3 declared properties).
public struct LocalBookPositionArchiveListParams: Codable, Sendable {
    public let bookId: String
    public let offset: Int64?
    public let limit: Int64?

    public init(bookId: String, offset: Int64? = nil, limit: Int64? = nil) {
        self.bookId = bookId
        self.offset = offset
        self.limit = limit
    }
}

/// Params schema `MangaCacheClassifyBatchParams` (1 declared properties).
public struct MangaCacheClassifyBatchParams: Codable, Sendable {
    public let versions: [ReaderJSONValue]

    public init(versions: [ReaderJSONValue]) {
        self.versions = versions
    }
}

/// Params schema `MangaCacheEvictParams` (2 declared properties).
public struct MangaCacheEvictParams: Codable, Sendable {
    public let nowSeconds: Int64
    public let ttlSeconds: Int64

    public init(nowSeconds: Int64, ttlSeconds: Int64) {
        self.nowSeconds = nowSeconds
        self.ttlSeconds = ttlSeconds
    }
}

/// Params schema `MangaCacheEvictionClaimParams` (4 declared properties).
public struct MangaCacheEvictionClaimParams: Codable, Sendable {
    public let chapter: ReaderJSONValue
    public let manifestVersion: String
    public let nowSeconds: Int64?
    public let ttlSeconds: Int64?

    public init(chapter: ReaderJSONValue, manifestVersion: String, nowSeconds: Int64? = nil, ttlSeconds: Int64? = nil) {
        self.chapter = chapter
        self.manifestVersion = manifestVersion
        self.nowSeconds = nowSeconds
        self.ttlSeconds = ttlSeconds
    }
}

/// Params schema `MangaCacheEvictionCompleteParams` (2 declared properties).
public struct MangaCacheEvictionCompleteParams: Codable, Sendable {
    public let token: String
    public let removed: Bool

    public init(token: String, removed: Bool) {
        self.token = token
        self.removed = removed
    }
}

/// Params schema `MangaCacheEvictionPendingParams` has no declared properties.
public struct MangaCacheEvictionPendingParams: Codable, Sendable {
    public init() {}
}

/// Params schema `MangaCacheMaterializationAbortParams` (1 declared properties).
public struct MangaCacheMaterializationAbortParams: Codable, Sendable {
    public let token: String

    public init(token: String) {
        self.token = token
    }
}

/// Params schema `MangaCacheMaterializationCompleteParams` (4 declared properties).
public struct MangaCacheMaterializationCompleteParams: Codable, Sendable {
    public let chapter: ReaderJSONValue
    public let manifestVersion: String
    public let token: String
    public let resourceRefs: [String]

    public init(chapter: ReaderJSONValue, manifestVersion: String, token: String, resourceRefs: [String]) {
        self.chapter = chapter
        self.manifestVersion = manifestVersion
        self.token = token
        self.resourceRefs = resourceRefs
    }
}

/// Params schema `MangaCacheMaterializationPrepareParams` (3 declared properties).
public struct MangaCacheMaterializationPrepareParams: Codable, Sendable {
    public let chapter: ReaderJSONValue
    public let manifestVersion: String
    public let intent: String

    public init(chapter: ReaderJSONValue, manifestVersion: String, intent: String) {
        self.chapter = chapter
        self.manifestVersion = manifestVersion
        self.intent = intent
    }
}

/// Params schema `MangaCacheRecordReadParams` (3 declared properties).
public struct MangaCacheRecordReadParams: Codable, Sendable {
    public let chapter: ReaderJSONValue
    public let manifestVersion: String
    public let readAt: Int64

    public init(chapter: ReaderJSONValue, manifestVersion: String, readAt: Int64) {
        self.chapter = chapter
        self.manifestVersion = manifestVersion
        self.readAt = readAt
    }
}

/// Params schema `MangaCacheVersionParams` (2 declared properties).
public struct MangaCacheVersionParams: Codable, Sendable {
    public let chapter: ReaderJSONValue
    public let manifestVersion: String

    public init(chapter: ReaderJSONValue, manifestVersion: String) {
        self.chapter = chapter
        self.manifestVersion = manifestVersion
    }
}

/// Params schema `MangaChapterGetParams` (8 declared properties).
public struct MangaChapterGetParams: Codable, Sendable {
    public let directoryTargetProof: ReaderJSONValue?
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: Int64
    public let policy: String?
    public let expectedManifestVersion: String?
    public let preparationRevision: Int64?
    public let anchor: ReaderJSONValue?

    public init(directoryTargetProof: ReaderJSONValue? = nil, sourceId: String, bookId: String, chapterIndex: Int64, policy: String? = nil, expectedManifestVersion: String? = nil, preparationRevision: Int64? = nil, anchor: ReaderJSONValue? = nil) {
        self.directoryTargetProof = directoryTargetProof
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterIndex = chapterIndex
        self.policy = policy
        self.expectedManifestVersion = expectedManifestVersion
        self.preparationRevision = preparationRevision
        self.anchor = anchor
    }
}

/// Params schema `MangaEntryGetParams` (4 declared properties).
public struct MangaEntryGetParams: Codable, Sendable {
    public let directoryTargetProof: ReaderJSONValue?
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: Int64?

    public init(directoryTargetProof: ReaderJSONValue? = nil, sourceId: String, bookId: String, chapterIndex: Int64? = nil) {
        self.directoryTargetProof = directoryTargetProof
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterIndex = chapterIndex
    }
}

/// Params schema `MangaPagesExtractParams` (8 declared properties).
public struct MangaPagesExtractParams: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterTitle: String?
    public let chapterResponse: String?
    public let chapterRequest: ReaderJSONValue?
    public let source: ReaderJSONValue?
    public let chapterUrl: String?
    public let variables: ReaderJSONValue?

    public init(sourceId: String, bookId: String, chapterTitle: String? = nil, chapterResponse: String? = nil, chapterRequest: ReaderJSONValue? = nil, source: ReaderJSONValue? = nil, chapterUrl: String? = nil, variables: ReaderJSONValue? = nil) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterTitle = chapterTitle
        self.chapterResponse = chapterResponse
        self.chapterRequest = chapterRequest
        self.source = source
        self.chapterUrl = chapterUrl
        self.variables = variables
    }
}

/// Params schema `MangaPagesWindowParams` (6 declared properties).
public struct MangaPagesWindowParams: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterId: String
    public let manifestVersion: String
    public let start: Int64
    public let limit: Int64

    public init(sourceId: String, bookId: String, chapterId: String, manifestVersion: String, start: Int64, limit: Int64) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterId = chapterId
        self.manifestVersion = manifestVersion
        self.start = start
        self.limit = limit
    }
}

/// Params schema `MangaResourceInspectParams` (3 declared properties).
public struct MangaResourceInspectParams: Codable, Sendable {
    public let transferId: String
    public let sha256: String
    public let bytes: Int64

    public init(transferId: String, sha256: String, bytes: Int64) {
        self.transferId = transferId
        self.sha256 = sha256
        self.bytes = bytes
    }
}

/// Params schema `MangaResourcePrepareParams` (5 declared properties).
public struct MangaResourcePrepareParams: Codable, Sendable {
    public let chapter: ReaderJSONValue
    public let manifestVersion: String
    public let resourceRef: String
    public let sourceRuleVersion: String
    public let transferId: String

    public init(chapter: ReaderJSONValue, manifestVersion: String, resourceRef: String, sourceRuleVersion: String, transferId: String) {
        self.chapter = chapter
        self.manifestVersion = manifestVersion
        self.resourceRef = resourceRef
        self.sourceRuleVersion = sourceRuleVersion
        self.transferId = transferId
    }
}

/// Params schema `MangaRetentionGetParams` (1 declared properties).
public struct MangaRetentionGetParams: Codable, Sendable {
    public let chapter: ReaderJSONValue

    public init(chapter: ReaderJSONValue) {
        self.chapter = chapter
    }
}

/// Params schema `MangaRetentionListParams` (2 declared properties).
public struct MangaRetentionListParams: Codable, Sendable {
    public let sourceId: String
    public let bookId: String

    public init(sourceId: String, bookId: String) {
        self.sourceId = sourceId
        self.bookId = bookId
    }
}

/// Params schema `MangaRetentionSetParams` (3 declared properties).
public struct MangaRetentionSetParams: Codable, Sendable {
    public let chapter: ReaderJSONValue
    public let retain: Bool
    public let retainedAt: Int64?

    public init(chapter: ReaderJSONValue, retain: Bool, retainedAt: Int64? = nil) {
        self.chapter = chapter
        self.retain = retain
        self.retainedAt = retainedAt
    }
}

/// Params schema `MangaSessionProtectParams` (2 declared properties).
public struct MangaSessionProtectParams: Codable, Sendable {
    public let chapters: [ReaderJSONValue]
    public let sessionEpoch: Int64

    public init(chapters: [ReaderJSONValue], sessionEpoch: Int64) {
        self.chapters = chapters
        self.sessionEpoch = sessionEpoch
    }
}

/// Params schema `MangaSessionReleaseParams` (2 declared properties).
public struct MangaSessionReleaseParams: Codable, Sendable {
    public let sessionEpoch: Int64
    public let expectedRuntimeEpoch: Int64?

    public init(sessionEpoch: Int64, expectedRuntimeEpoch: Int64? = nil) {
        self.sessionEpoch = sessionEpoch
        self.expectedRuntimeEpoch = expectedRuntimeEpoch
    }
}

/// Params schema `MangaSessionReplaceParams` (3 declared properties).
public struct MangaSessionReplaceParams: Codable, Sendable {
    public let chapters: [ReaderJSONValue]
    public let sessionEpoch: Int64
    public let expectedRuntimeEpoch: Int64

    public init(chapters: [ReaderJSONValue], sessionEpoch: Int64, expectedRuntimeEpoch: Int64) {
        self.chapters = chapters
        self.sessionEpoch = sessionEpoch
        self.expectedRuntimeEpoch = expectedRuntimeEpoch
    }
}

/// Params schema `MangaSessionRuntimeParams` has no declared properties.
public struct MangaSessionRuntimeParams: Codable, Sendable {
    public init() {}
}

/// Params schema `MangaSourceSwitchOperationParams` (9 declared properties).
public struct MangaSourceSwitchOperationParams: Codable, Sendable {
    public let operationId: String
    public let sequence: Int64
    public let fromSourceId: String
    public let fromBookId: String
    public let expectedFrom: ReaderJSONValue
    public let expectedTarget: ReaderJSONValue
    public let firstImage: ReaderJSONValue
    public let targetPageOrdinal: Int64
    public let acceptApproximate: ReaderJSONValue

    public init(operationId: String, sequence: Int64, fromSourceId: String, fromBookId: String, expectedFrom: ReaderJSONValue, expectedTarget: ReaderJSONValue, firstImage: ReaderJSONValue, targetPageOrdinal: Int64, acceptApproximate: ReaderJSONValue) {
        self.operationId = operationId
        self.sequence = sequence
        self.fromSourceId = fromSourceId
        self.fromBookId = fromBookId
        self.expectedFrom = expectedFrom
        self.expectedTarget = expectedTarget
        self.firstImage = firstImage
        self.targetPageOrdinal = targetPageOrdinal
        self.acceptApproximate = acceptApproximate
    }
}

/// Params schema `MangaSourceSwitchOperationQueryParams` (2 declared properties).
public struct MangaSourceSwitchOperationQueryParams: Codable, Sendable {
    public let operationId: String?
    public let expected: ReaderJSONValue?

    public init(operationId: String? = nil, expected: ReaderJSONValue? = nil) {
        self.operationId = operationId
        self.expected = expected
    }
}

/// Params schema `MangaSourceSwitchParams` (7 declared properties).
public struct MangaSourceSwitchParams: Codable, Sendable {
    public let fromSourceId: String
    public let fromBookId: String
    public let expectedFrom: ReaderJSONValue
    public let expectedTarget: ReaderJSONValue
    public let firstImage: ReaderJSONValue
    public let targetPageOrdinal: Int64
    public let acceptApproximate: ReaderJSONValue

    public init(fromSourceId: String, fromBookId: String, expectedFrom: ReaderJSONValue, expectedTarget: ReaderJSONValue, firstImage: ReaderJSONValue, targetPageOrdinal: Int64, acceptApproximate: ReaderJSONValue) {
        self.fromSourceId = fromSourceId
        self.fromBookId = fromBookId
        self.expectedFrom = expectedFrom
        self.expectedTarget = expectedTarget
        self.firstImage = firstImage
        self.targetPageOrdinal = targetPageOrdinal
        self.acceptApproximate = acceptApproximate
    }
}

/// Params schema `ReadRecordAccumulateParams` (7 declared properties).
public struct ReadRecordAccumulateParams: Codable, Sendable {
    public let deviceId: String
    public let bookName: String
    public let author: String?
    public let elapsedMillis: Int64
    public let readAt: Int64
    public let operationId: String?
    public let sequence: Int64?

    public init(deviceId: String, bookName: String, author: String? = nil, elapsedMillis: Int64, readAt: Int64, operationId: String? = nil, sequence: Int64? = nil) {
        self.deviceId = deviceId
        self.bookName = bookName
        self.author = author
        self.elapsedMillis = elapsedMillis
        self.readAt = readAt
        self.operationId = operationId
        self.sequence = sequence
    }
}

/// Params schema `ReadRecordClearParams` has no declared properties.
public struct ReadRecordClearParams: Codable, Sendable {
    public init() {}
}

/// Params schema `ReadRecordCreateParams` (5 declared properties).
public struct ReadRecordCreateParams: Codable, Sendable {
    public let deviceId: String?
    public let bookName: String
    public let author: String?
    public let readTime: Int64?
    public let lastRead: Int64?

    public init(deviceId: String? = nil, bookName: String, author: String? = nil, readTime: Int64? = nil, lastRead: Int64? = nil) {
        self.deviceId = deviceId
        self.bookName = bookName
        self.author = author
        self.readTime = readTime
        self.lastRead = lastRead
    }
}

/// Params schema `ReadRecordDeleteByBookParams` (1 declared properties).
public struct ReadRecordDeleteByBookParams: Codable, Sendable {
    public let bookName: String

    public init(bookName: String) {
        self.bookName = bookName
    }
}

/// Params schema `ReadRecordDeleteParams` (2 declared properties).
public struct ReadRecordDeleteParams: Codable, Sendable {
    public let deviceId: String
    public let bookName: String

    public init(deviceId: String, bookName: String) {
        self.deviceId = deviceId
        self.bookName = bookName
    }
}

/// Params schema `ReadRecordListParams` (1 declared properties).
public struct ReadRecordListParams: Codable, Sendable {
    public let deviceId: String?

    public init(deviceId: String? = nil) {
        self.deviceId = deviceId
    }
}

/// Params schema `ReadRecordSummaryParams` (2 declared properties).
public struct ReadRecordSummaryParams: Codable, Sendable {
    public let query: String?
    public let sortBy: String?

    public init(query: String? = nil, sortBy: String? = nil) {
        self.query = query
        self.sortBy = sortBy
    }
}

/// Params schema `ReadRecordUpdateParams` (5 declared properties).
public struct ReadRecordUpdateParams: Codable, Sendable {
    public let deviceId: String
    public let bookName: String
    public let author: String?
    public let readTime: Int64?
    public let lastRead: Int64?

    public init(deviceId: String, bookName: String, author: String? = nil, readTime: Int64? = nil, lastRead: Int64? = nil) {
        self.deviceId = deviceId
        self.bookName = bookName
        self.author = author
        self.readTime = readTime
        self.lastRead = lastRead
    }
}

/// Params schema `ReaderLocationResolveParams` (6 declared properties).
public struct ReaderLocationResolveParams: Codable, Sendable {
    public let sourceId: String?
    public let bookId: String
    public let chapterIndex: Int64
    public let chapterTitle: String?
    public let anchor: ReaderJSONValue
    public let layout: ReaderJSONValue

    public init(sourceId: String? = nil, bookId: String, chapterIndex: Int64, chapterTitle: String? = nil, anchor: ReaderJSONValue, layout: ReaderJSONValue) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterIndex = chapterIndex
        self.chapterTitle = chapterTitle
        self.anchor = anchor
        self.layout = layout
    }
}

/// Params schema `ReadingCatalogPageParams` (5 declared properties).
public struct ReadingCatalogPageParams: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let offset: Int64?
    public let limit: Int64
    public let revision: String?

    public init(sourceId: String, bookId: String, offset: Int64? = nil, limit: Int64, revision: String? = nil) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.offset = offset
        self.limit = limit
        self.revision = revision
    }
}

/// Params schema `ReadingDocumentWindowParams` (6 declared properties).
public struct ReadingDocumentWindowParams: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: Int64
    public let startScalar: Int64
    public let scalarLimit: Int64
    public let positionContext: ReaderJSONValue

    public init(sourceId: String, bookId: String, chapterIndex: Int64, startScalar: Int64, scalarLimit: Int64, positionContext: ReaderJSONValue) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterIndex = chapterIndex
        self.startScalar = startScalar
        self.scalarLimit = scalarLimit
        self.positionContext = positionContext
    }
}

/// Params schema `ReadingEntryPrepareParams` (5 declared properties).
public struct ReadingEntryPrepareParams: Codable, Sendable {
    public let localSourcePath: String?
    public let chapterIndex: Int64?
    public let sourceId: String
    public let bookId: String
    public let neighborOffset: Int64

    public init(localSourcePath: String? = nil, chapterIndex: Int64? = nil, sourceId: String, bookId: String, neighborOffset: Int64) {
        self.localSourcePath = localSourcePath
        self.chapterIndex = chapterIndex
        self.sourceId = sourceId
        self.bookId = bookId
        self.neighborOffset = neighborOffset
    }
}

/// Params schema `ReadingEntrySnapshotParams` (6 declared properties).
public struct ReadingEntrySnapshotParams: Codable, Sendable {
    public let directoryTargetProof: ReaderJSONValue?
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: Int64?
    public let windowScalarLimit: Int64?
    public let positionContext: ReaderJSONValue?

    public init(directoryTargetProof: ReaderJSONValue? = nil, sourceId: String, bookId: String, chapterIndex: Int64? = nil, windowScalarLimit: Int64? = nil, positionContext: ReaderJSONValue? = nil) {
        self.directoryTargetProof = directoryTargetProof
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterIndex = chapterIndex
        self.windowScalarLimit = windowScalarLimit
        self.positionContext = positionContext
    }
}

/// Params schema `ReadingPreparationParams` (9 declared properties).
public struct ReadingPreparationParams: Codable, Sendable {
    public let action: String
    public let sourceId: String?
    public let bookId: String?
    public let reason: String?
    public let revision: Int64?
    public let blockReason: String?
    public let pendingAdd: ReaderJSONValue?
    public let offset: Int64?
    public let limit: Int64?

    public init(action: String, sourceId: String? = nil, bookId: String? = nil, reason: String? = nil, revision: Int64? = nil, blockReason: String? = nil, pendingAdd: ReaderJSONValue? = nil, offset: Int64? = nil, limit: Int64? = nil) {
        self.action = action
        self.sourceId = sourceId
        self.bookId = bookId
        self.reason = reason
        self.revision = revision
        self.blockReason = blockReason
        self.pendingAdd = pendingAdd
        self.offset = offset
        self.limit = limit
    }
}

/// Params schema `ReplaceApplyParams` (4 declared properties).
public struct ReplaceApplyParams: Codable, Sendable {
    public let text: String
    public let bookName: String
    public let bookOrigin: String
    public let target: String

    public init(text: String, bookName: String, bookOrigin: String, target: String) {
        self.text = text
        self.bookName = bookName
        self.bookOrigin = bookOrigin
        self.target = target
    }
}

/// Params schema `ReplacePersistParams` has no declared properties.
public struct ReplacePersistParams: Codable, Sendable {
    public init() {}
}

/// Params schema `ReplacePreviewParams` (4 declared properties).
public struct ReplacePreviewParams: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: Int64
    public let maxScalars: Int64?

    public init(sourceId: String, bookId: String, chapterIndex: Int64, maxScalars: Int64? = nil) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterIndex = chapterIndex
        self.maxScalars = maxScalars
    }
}

/// Params schema `ReplaceRuleCreateParams` (14 declared properties).
public struct ReplaceRuleCreateParams: Codable, Sendable {
    public let id: Int64?
    public let name: String?
    public let group: String?
    public let pattern: String?
    public let replacement: String?
    public let scope: String?
    public let scopeTitle: Bool?
    public let scopeSource: Bool?
    public let scopeContent: Bool?
    public let excludeScope: String?
    public let isEnabled: Bool?
    public let isRegex: Bool?
    public let timeoutMillisecond: Int64?
    public let order: Int64?

    public init(id: Int64? = nil, name: String? = nil, group: String? = nil, pattern: String? = nil, replacement: String? = nil, scope: String? = nil, scopeTitle: Bool? = nil, scopeSource: Bool? = nil, scopeContent: Bool? = nil, excludeScope: String? = nil, isEnabled: Bool? = nil, isRegex: Bool? = nil, timeoutMillisecond: Int64? = nil, order: Int64? = nil) {
        self.id = id
        self.name = name
        self.group = group
        self.pattern = pattern
        self.replacement = replacement
        self.scope = scope
        self.scopeTitle = scopeTitle
        self.scopeSource = scopeSource
        self.scopeContent = scopeContent
        self.excludeScope = excludeScope
        self.isEnabled = isEnabled
        self.isRegex = isRegex
        self.timeoutMillisecond = timeoutMillisecond
        self.order = order
    }
}

/// Params schema `ReplaceRuleDeleteParams` (1 declared properties).
public struct ReplaceRuleDeleteParams: Codable, Sendable {
    public let id: Int64

    public init(id: Int64) {
        self.id = id
    }
}

/// Params schema `ReplaceRuleListParams` (1 declared properties).
public struct ReplaceRuleListParams: Codable, Sendable {
    public let enabledOnly: Bool?

    public init(enabledOnly: Bool? = nil) {
        self.enabledOnly = enabledOnly
    }
}

/// Params schema `ReplaceRuleUpdateParams` (14 declared properties).
public struct ReplaceRuleUpdateParams: Codable, Sendable {
    public let id: Int64
    public let name: String?
    public let group: String?
    public let pattern: String?
    public let replacement: String?
    public let scope: String?
    public let scopeTitle: Bool?
    public let scopeSource: Bool?
    public let scopeContent: Bool?
    public let excludeScope: String?
    public let isEnabled: Bool?
    public let isRegex: Bool?
    public let timeoutMillisecond: Int64?
    public let order: Int64?

    public init(id: Int64, name: String? = nil, group: String? = nil, pattern: String? = nil, replacement: String? = nil, scope: String? = nil, scopeTitle: Bool? = nil, scopeSource: Bool? = nil, scopeContent: Bool? = nil, excludeScope: String? = nil, isEnabled: Bool? = nil, isRegex: Bool? = nil, timeoutMillisecond: Int64? = nil, order: Int64? = nil) {
        self.id = id
        self.name = name
        self.group = group
        self.pattern = pattern
        self.replacement = replacement
        self.scope = scope
        self.scopeTitle = scopeTitle
        self.scopeSource = scopeSource
        self.scopeContent = scopeContent
        self.excludeScope = excludeScope
        self.isEnabled = isEnabled
        self.isRegex = isRegex
        self.timeoutMillisecond = timeoutMillisecond
        self.order = order
    }
}

/// Params schema `ReplaceUndoParams` (1 declared properties).
public struct ReplaceUndoParams: Codable, Sendable {
    public let undoToken: ReaderJSONValue

    public init(undoToken: ReaderJSONValue) {
        self.undoToken = undoToken
    }
}

/// Params schema `ReplaceValidateParams` (3 declared properties).
public struct ReplaceValidateParams: Codable, Sendable {
    public let pattern: String
    public let isRegex: Bool?
    public let scope: [String]

    public init(pattern: String, isRegex: Bool? = nil, scope: [String]) {
        self.pattern = pattern
        self.isRegex = isRegex
        self.scope = scope
    }
}

/// Params schema `RssFavoriteListParams` (2 declared properties).
public struct RssFavoriteListParams: Codable, Sendable {
    public let subscriptionId: String?
    public let limit: Int64?

    public init(subscriptionId: String? = nil, limit: Int64? = nil) {
        self.subscriptionId = subscriptionId
        self.limit = limit
    }
}

/// Params schema `RssItemReadParams` (3 declared properties).
public struct RssItemReadParams: Codable, Sendable {
    public let guid: String
    public let read: Bool
    public let subscriptionId: String?

    public init(guid: String, read: Bool, subscriptionId: String? = nil) {
        self.guid = guid
        self.read = read
        self.subscriptionId = subscriptionId
    }
}

/// Params schema `RssListParams` (4 declared properties).
public struct RssListParams: Codable, Sendable {
    public let feedUrl: String?
    public let xml: String
    public let unreadOnly: Bool?
    public let limit: Int64?

    public init(feedUrl: String? = nil, xml: String, unreadOnly: Bool? = nil, limit: Int64? = nil) {
        self.feedUrl = feedUrl
        self.xml = xml
        self.unreadOnly = unreadOnly
        self.limit = limit
    }
}

/// Params schema `RssParseParams` (2 declared properties).
public struct RssParseParams: Codable, Sendable {
    public let feedUrl: String?
    public let xml: String

    public init(feedUrl: String? = nil, xml: String) {
        self.feedUrl = feedUrl
        self.xml = xml
    }
}

/// Params schema `RssRefreshParams` (6 declared properties).
public struct RssRefreshParams: Codable, Sendable {
    public let subscriptionId: String
    public let enabled: Bool?
    public let updateIntervalMinutes: Int64?
    public let lastFetchedAt: Int64?
    public let forceRefresh: Bool?
    public let evaluatedAt: Int64

    public init(subscriptionId: String, enabled: Bool? = nil, updateIntervalMinutes: Int64? = nil, lastFetchedAt: Int64? = nil, forceRefresh: Bool? = nil, evaluatedAt: Int64) {
        self.subscriptionId = subscriptionId
        self.enabled = enabled
        self.updateIntervalMinutes = updateIntervalMinutes
        self.lastFetchedAt = lastFetchedAt
        self.forceRefresh = forceRefresh
        self.evaluatedAt = evaluatedAt
    }
}

/// Params schema `RssSourceExportParams` (1 declared properties).
public struct RssSourceExportParams: Codable, Sendable {
    public let exportedAt: Int64?

    public init(exportedAt: Int64? = nil) {
        self.exportedAt = exportedAt
    }
}

/// Params schema `RssSourceImportParams` (2 declared properties).
public struct RssSourceImportParams: Codable, Sendable {
    public let json: String
    public let replaceExisting: Bool?

    public init(json: String, replaceExisting: Bool? = nil) {
        self.json = json
        self.replaceExisting = replaceExisting
    }
}

/// Params schema `RssSourcePutParams` (2 declared properties).
public struct RssSourcePutParams: Codable, Sendable {
    public let subscriptionId: String?
    public let source: ReaderJSONValue

    public init(subscriptionId: String? = nil, source: ReaderJSONValue) {
        self.subscriptionId = subscriptionId
        self.source = source
    }
}

/// Params schema `RssSubscriptionAddParams` (5 declared properties).
public struct RssSubscriptionAddParams: Codable, Sendable {
    public let subscriptionId: String
    public let feedUrl: String
    public let title: String?
    public let siteUrl: String?
    public let enabled: Bool?

    public init(subscriptionId: String, feedUrl: String, title: String? = nil, siteUrl: String? = nil, enabled: Bool? = nil) {
        self.subscriptionId = subscriptionId
        self.feedUrl = feedUrl
        self.title = title
        self.siteUrl = siteUrl
        self.enabled = enabled
    }
}

/// Params schema `RssSubscriptionCreateParams` (3 declared properties).
public struct RssSubscriptionCreateParams: Codable, Sendable {
    public let feedUrl: String
    public let title: String?
    public let enabled: Bool?

    public init(feedUrl: String, title: String? = nil, enabled: Bool? = nil) {
        self.feedUrl = feedUrl
        self.title = title
        self.enabled = enabled
    }
}

/// Params schema `RssSubscriptionDeleteParams` (1 declared properties).
public struct RssSubscriptionDeleteParams: Codable, Sendable {
    public let subscriptionId: String

    public init(subscriptionId: String) {
        self.subscriptionId = subscriptionId
    }
}

/// Params schema `RssSubscriptionItemsParams` (3 declared properties).
public struct RssSubscriptionItemsParams: Codable, Sendable {
    public let subscriptionId: String
    public let unreadOnly: Bool?
    public let limit: Int64?

    public init(subscriptionId: String, unreadOnly: Bool? = nil, limit: Int64? = nil) {
        self.subscriptionId = subscriptionId
        self.unreadOnly = unreadOnly
        self.limit = limit
    }
}

/// Params schema `RssSubscriptionListParams` has no declared properties.
public struct RssSubscriptionListParams: Codable, Sendable {
    public init() {}
}

/// Params schema `RssSubscriptionRefreshParams` (2 declared properties).
public struct RssSubscriptionRefreshParams: Codable, Sendable {
    public let subscriptionId: String
    public let evaluatedAt: Int64?

    public init(subscriptionId: String, evaluatedAt: Int64? = nil) {
        self.subscriptionId = subscriptionId
        self.evaluatedAt = evaluatedAt
    }
}

/// Params schema `RssSubscriptionUpdateParams` (4 declared properties).
public struct RssSubscriptionUpdateParams: Codable, Sendable {
    public let subscriptionId: String
    public let feedUrl: String?
    public let title: String?
    public let enabled: Bool?

    public init(subscriptionId: String, feedUrl: String? = nil, title: String? = nil, enabled: Bool? = nil) {
        self.subscriptionId = subscriptionId
        self.feedUrl = feedUrl
        self.title = title
        self.enabled = enabled
    }
}

/// Params schema `RuleBundleImportParams` (2 declared properties).
public struct RuleBundleImportParams: Codable, Sendable {
    public let json: String
    public let replaceExisting: Bool?

    public init(json: String, replaceExisting: Bool? = nil) {
        self.json = json
        self.replaceExisting = replaceExisting
    }
}

/// Params schema `RuleSubKeyParams` (1 declared properties).
public struct RuleSubKeyParams: Codable, Sendable {
    public let id: Int64

    public init(id: Int64) {
        self.id = id
    }
}

/// Params schema `RuleSubPutParams` (7 declared properties).
public struct RuleSubPutParams: Codable, Sendable {
    public let id: Int64
    public let name: String?
    public let url: String?
    public let type: Int64?
    public let customOrder: Int64?
    public let autoUpdate: Bool?
    public let update: Int64?

    public init(id: Int64, name: String? = nil, url: String? = nil, type: Int64? = nil, customOrder: Int64? = nil, autoUpdate: Bool? = nil, update: Int64? = nil) {
        self.id = id
        self.name = name
        self.url = url
        self.type = type
        self.customOrder = customOrder
        self.autoUpdate = autoUpdate
        self.update = update
    }
}

/// Params schema `RuleSubUpdatePreviewParams` (3 declared properties).
public struct RuleSubUpdatePreviewParams: Codable, Sendable {
    public let subscriptionId: Int64
    public let remoteJson: String
    public let expected: ReaderJSONValue?

    public init(subscriptionId: Int64, remoteJson: String, expected: ReaderJSONValue? = nil) {
        self.subscriptionId = subscriptionId
        self.remoteJson = remoteJson
        self.expected = expected
    }
}

/// Params schema `RulesMutationApplyParams` (3 declared properties).
public struct RulesMutationApplyParams: Codable, Sendable {
    public let operationId: String
    public let sequence: Int64
    public let mutation: ReaderJSONValue

    public init(operationId: String, sequence: Int64, mutation: ReaderJSONValue) {
        self.operationId = operationId
        self.sequence = sequence
        self.mutation = mutation
    }
}

/// Params schema `RulesMutationQueryParams` (2 declared properties).
public struct RulesMutationQueryParams: Codable, Sendable {
    public let operationId: ReaderJSONValue?
    public let expected: ReaderJSONValue?

    public init(operationId: ReaderJSONValue? = nil, expected: ReaderJSONValue? = nil) {
        self.operationId = operationId
        self.expected = expected
    }
}

/// Params schema `RuntimeCancelParams` (1 declared properties).
public struct RuntimeCancelParams: Codable, Sendable {
    public let requestId: Int64

    public init(requestId: Int64) {
        self.requestId = requestId
    }
}

/// Params schema `RuntimeShutdownParams` has no declared properties.
public struct RuntimeShutdownParams: Codable, Sendable {
    public init() {}
}

/// Params schema `RuntimeStorageApplyParams` (2 declared properties).
public struct RuntimeStorageApplyParams: Codable, Sendable {
    public let manifest: ReaderJSONValue
    public let payload: String

    public init(manifest: ReaderJSONValue, payload: String) {
        self.manifest = manifest
        self.payload = payload
    }
}

/// Params schema `RuntimeStorageBackupCreateParams` has no declared properties.
public struct RuntimeStorageBackupCreateParams: Codable, Sendable {
    public init() {}
}

/// Params schema `RuntimeStorageBackupRestoreParams` (2 declared properties).
public struct RuntimeStorageBackupRestoreParams: Codable, Sendable {
    public let backupId: String
    public let expectedSha256: String

    public init(backupId: String, expectedSha256: String) {
        self.backupId = backupId
        self.expectedSha256 = expectedSha256
    }
}

/// Params schema `RuntimeStorageExportParams` has no declared properties.
public struct RuntimeStorageExportParams: Codable, Sendable {
    public init() {}
}

/// Params schema `RuntimeStorageFlushParams` has no declared properties.
public struct RuntimeStorageFlushParams: Codable, Sendable {
    public init() {}
}

/// Params schema `RuntimeStorageRestoreParams` has no declared properties.
public struct RuntimeStorageRestoreParams: Codable, Sendable {
    public init() {}
}

/// Params schema `SearchBookBatchGetParams` (1 declared properties).
public struct SearchBookBatchGetParams: Codable, Sendable {
    public let identities: [ReaderJSONValue]

    public init(identities: [ReaderJSONValue]) {
        self.identities = identities
    }
}

/// Params schema `SearchBookKeyParams` (2 declared properties).
public struct SearchBookKeyParams: Codable, Sendable {
    public let bookUrl: String
    public let origin: String?

    public init(bookUrl: String, origin: String? = nil) {
        self.bookUrl = bookUrl
        self.origin = origin
    }
}

/// Params schema `SearchBookListParams` (1 declared properties).
public struct SearchBookListParams: Codable, Sendable {
    public let origin: String?

    public init(origin: String? = nil) {
        self.origin = origin
    }
}

/// Params schema `SearchBookPutParams` (19 declared properties).
public struct SearchBookPutParams: Codable, Sendable {
    public let bookUrl: String
    public let origin: String?
    public let originName: String?
    public let type: Int64?
    public let name: String?
    public let author: String?
    public let kind: String?
    public let coverUrl: String?
    public let intro: String?
    public let wordCount: String?
    public let latestChapterTitle: String?
    public let tocUrl: String?
    public let time: Int64?
    public let variable: String?
    public let originOrder: Int64?
    public let chapterWordCountText: String?
    public let chapterWordCount: Int64?
    public let respondTime: Int64?
    public let acquisition: ReaderJSONValue?

    public init(bookUrl: String, origin: String? = nil, originName: String? = nil, type: Int64? = nil, name: String? = nil, author: String? = nil, kind: String? = nil, coverUrl: String? = nil, intro: String? = nil, wordCount: String? = nil, latestChapterTitle: String? = nil, tocUrl: String? = nil, time: Int64? = nil, variable: String? = nil, originOrder: Int64? = nil, chapterWordCountText: String? = nil, chapterWordCount: Int64? = nil, respondTime: Int64? = nil, acquisition: ReaderJSONValue? = nil) {
        self.bookUrl = bookUrl
        self.origin = origin
        self.originName = originName
        self.type = type
        self.name = name
        self.author = author
        self.kind = kind
        self.coverUrl = coverUrl
        self.intro = intro
        self.wordCount = wordCount
        self.latestChapterTitle = latestChapterTitle
        self.tocUrl = tocUrl
        self.time = time
        self.variable = variable
        self.originOrder = originOrder
        self.chapterWordCountText = chapterWordCountText
        self.chapterWordCount = chapterWordCount
        self.respondTime = respondTime
        self.acquisition = acquisition
    }
}

/// Params schema `SearchBookRelatedParams` (6 declared properties).
public struct SearchBookRelatedParams: Codable, Sendable {
    public let mode: String?
    public let identity: ReaderJSONValue?
    public let name: String?
    public let author: String?
    public let limit: Int64?
    public let cursor: String?

    public init(mode: String? = nil, identity: ReaderJSONValue? = nil, name: String? = nil, author: String? = nil, limit: Int64? = nil, cursor: String? = nil) {
        self.mode = mode
        self.identity = identity
        self.name = name
        self.author = author
        self.limit = limit
        self.cursor = cursor
    }
}

/// Params schema `SearchContentParams` (8 declared properties).
public struct SearchContentParams: Codable, Sendable {
    public let keyword: String
    public let sourceId: String?
    public let bookId: String?
    public let maxResults: Int64?
    public let offset: Int64?
    public let useCursor: Bool?
    public let cursor: String?
    public let closeCursor: Bool?

    public init(keyword: String, sourceId: String? = nil, bookId: String? = nil, maxResults: Int64? = nil, offset: Int64? = nil, useCursor: Bool? = nil, cursor: String? = nil, closeCursor: Bool? = nil) {
        self.keyword = keyword
        self.sourceId = sourceId
        self.bookId = bookId
        self.maxResults = maxResults
        self.offset = offset
        self.useCursor = useCursor
        self.cursor = cursor
        self.closeCursor = closeCursor
    }
}

/// Params schema `SearchCoverParams` (3 declared properties).
public struct SearchCoverParams: Codable, Sendable {
    public let bookName: String
    public let author: String?
    public let sourceIds: [String]

    public init(bookName: String, author: String? = nil, sourceIds: [String]) {
        self.bookName = bookName
        self.author = author
        self.sourceIds = sourceIds
    }
}

/// Params schema `SearchHistoryAddParams` (1 declared properties).
public struct SearchHistoryAddParams: Codable, Sendable {
    public let keyword: String

    public init(keyword: String) {
        self.keyword = keyword
    }
}

/// Params schema `SearchHistoryClearParams` has no declared properties.
public struct SearchHistoryClearParams: Codable, Sendable {
    public init() {}
}

/// Params schema `SearchHistoryListParams` (1 declared properties).
public struct SearchHistoryListParams: Codable, Sendable {
    public let limit: Int64?

    public init(limit: Int64? = nil) {
        self.limit = limit
    }
}

/// Params schema `SearchKeywordKeyParams` (1 declared properties).
public struct SearchKeywordKeyParams: Codable, Sendable {
    public let word: String

    public init(word: String) {
        self.word = word
    }
}

/// Params schema `SearchKeywordPutParams` (3 declared properties).
public struct SearchKeywordPutParams: Codable, Sendable {
    public let word: String
    public let usage: Int64?
    public let lastUseTime: Int64?

    public init(word: String, usage: Int64? = nil, lastUseTime: Int64? = nil) {
        self.word = word
        self.usage = usage
        self.lastUseTime = lastUseTime
    }
}

/// Params schema `SourceCheckEphemeralRunParams` (7 declared properties).
public struct SourceCheckEphemeralRunParams: Codable, Sendable {
    public let reportVersion: Int64?
    public let sources: [ReaderJSONValue]
    public let mode: String?
    public let keyword: ReaderJSONValue?
    public let keywordOverride: ReaderJSONValue?
    public let timeoutMs: ReaderJSONValue?
    public let levels: ReaderJSONValue?

    public init(reportVersion: Int64? = nil, sources: [ReaderJSONValue], mode: String? = nil, keyword: ReaderJSONValue? = nil, keywordOverride: ReaderJSONValue? = nil, timeoutMs: ReaderJSONValue? = nil, levels: ReaderJSONValue? = nil) {
        self.reportVersion = reportVersion
        self.sources = sources
        self.mode = mode
        self.keyword = keyword
        self.keywordOverride = keywordOverride
        self.timeoutMs = timeoutMs
        self.levels = levels
    }
}

/// Params schema `SourceCheckParams` (5 declared properties).
public struct SourceCheckParams: Codable, Sendable {
    public let sourceIds: [String]
    public let keyword: String?
    public let timeoutMs: Int64?
    public let levels: [String]?
    public let responses: [ReaderJSONValue]?

    public init(sourceIds: [String], keyword: String? = nil, timeoutMs: Int64? = nil, levels: [String]? = nil, responses: [ReaderJSONValue]? = nil) {
        self.sourceIds = sourceIds
        self.keyword = keyword
        self.timeoutMs = timeoutMs
        self.levels = levels
        self.responses = responses
    }
}

/// Params schema `SourceCheckReportClearParams` (1 declared properties).
public struct SourceCheckReportClearParams: Codable, Sendable {
    public let sourceIds: [String]

    public init(sourceIds: [String]) {
        self.sourceIds = sourceIds
    }
}

/// Params schema `SourceCheckRunParams` (7 declared properties).
public struct SourceCheckRunParams: Codable, Sendable {
    public let reportVersion: String?
    public let mode: String?
    public let sourceIds: [String]
    public let keyword: String?
    public let keywordOverride: Bool?
    public let timeoutMs: Int64?
    public let levels: [String]?

    public init(reportVersion: String? = nil, mode: String? = nil, sourceIds: [String], keyword: String? = nil, keywordOverride: Bool? = nil, timeoutMs: Int64? = nil, levels: [String]? = nil) {
        self.reportVersion = reportVersion
        self.mode = mode
        self.sourceIds = sourceIds
        self.keyword = keyword
        self.keywordOverride = keywordOverride
        self.timeoutMs = timeoutMs
        self.levels = levels
    }
}

/// Params schema `SourceDebugParams` (3 declared properties).
public struct SourceDebugParams: Codable, Sendable {
    public let sourceId: String
    public let key: String?
    public let responses: ReaderJSONValue?

    public init(sourceId: String, key: String? = nil, responses: ReaderJSONValue? = nil) {
        self.sourceId = sourceId
        self.key = key
        self.responses = responses
    }
}

/// Params schema `SourceDeleteParams` (1 declared properties).
public struct SourceDeleteParams: Codable, Sendable {
    public let sourceIds: [String]

    public init(sourceIds: [String]) {
        self.sourceIds = sourceIds
    }
}

/// Params schema `SourceExploreKindsParams` (3 declared properties).
public struct SourceExploreKindsParams: Codable, Sendable {
    public let source: ReaderJSONValue?
    public let sourceId: String?
    public let exploreUrl: String?

    public init(source: ReaderJSONValue? = nil, sourceId: String? = nil, exploreUrl: String? = nil) {
        self.source = source
        self.sourceId = sourceId
        self.exploreUrl = exploreUrl
    }
}

/// Params schema `SourceExploreParams` (6 declared properties).
public struct SourceExploreParams: Codable, Sendable {
    public let source: ReaderJSONValue?
    public let sourceId: String?
    public let url: String?
    public let page: Int64?
    public let exploreResponse: String?
    public let exploreRequest: ReaderJSONValue?

    public init(source: ReaderJSONValue? = nil, sourceId: String? = nil, url: String? = nil, page: Int64? = nil, exploreResponse: String? = nil, exploreRequest: ReaderJSONValue? = nil) {
        self.source = source
        self.sourceId = sourceId
        self.url = url
        self.page = page
        self.exploreResponse = exploreResponse
        self.exploreRequest = exploreRequest
    }
}

/// Params schema `SourceExportParams` (3 declared properties).
public struct SourceExportParams: Codable, Sendable {
    public let sourceIds: [String]?
    public let format: String?
    public let encryptKey: String?

    public init(sourceIds: [String]? = nil, format: String? = nil, encryptKey: String? = nil) {
        self.sourceIds = sourceIds
        self.format = format
        self.encryptKey = encryptKey
    }
}

/// Params schema `SourceGroupCatalogParams` (1 declared properties).
public struct SourceGroupCatalogParams: Codable, Sendable {
    public let reportVersion: ReaderJSONValue

    public init(reportVersion: ReaderJSONValue) {
        self.reportVersion = reportVersion
    }
}

/// Params schema `SourceImageRequestParams` (5 declared properties).
public struct SourceImageRequestParams: Codable, Sendable {
    public let sourceId: String
    public let imageUrl: String
    public let baseUrl: String?
    public let source: ReaderJSONValue?
    public let expectedSourceVersion: String?

    public init(sourceId: String, imageUrl: String, baseUrl: String? = nil, source: ReaderJSONValue? = nil, expectedSourceVersion: String? = nil) {
        self.sourceId = sourceId
        self.imageUrl = imageUrl
        self.baseUrl = baseUrl
        self.source = source
        self.expectedSourceVersion = expectedSourceVersion
    }
}

/// Params schema `SourceImportParams` (7 declared properties).
public struct SourceImportParams: Codable, Sendable {
    public let sourceId: String?
    public let name: String?
    public let baseUrl: String?
    public let rules: ReaderJSONValue?
    public let bookSource: ReaderJSONValue?
    public let useSourceReplacement: Bool?
    public let expectedVersion: String?

    public init(sourceId: String? = nil, name: String? = nil, baseUrl: String? = nil, rules: ReaderJSONValue? = nil, bookSource: ReaderJSONValue? = nil, useSourceReplacement: Bool? = nil, expectedVersion: String? = nil) {
        self.sourceId = sourceId
        self.name = name
        self.baseUrl = baseUrl
        self.rules = rules
        self.bookSource = bookSource
        self.useSourceReplacement = useSourceReplacement
        self.expectedVersion = expectedVersion
    }
}

/// Params schema `SourceListParams` (4 declared properties).
public struct SourceListParams: Codable, Sendable {
    public let includeCheckReports: Bool?
    public let checkReportVersion: String?
    public let sourceId: String?
    public let enabledOnly: Bool?

    public init(includeCheckReports: Bool? = nil, checkReportVersion: String? = nil, sourceId: String? = nil, enabledOnly: Bool? = nil) {
        self.includeCheckReports = includeCheckReports
        self.checkReportVersion = checkReportVersion
        self.sourceId = sourceId
        self.enabledOnly = enabledOnly
    }
}

/// Params schema `SourceSupplyParams` has no declared properties.
public struct SourceSupplyParams: Codable, Sendable {
    public init() {}
}

/// Params schema `SourceSwitchCommitParams` (8 declared properties).
public struct SourceSwitchCommitParams: Codable, Sendable {
    public let operationId: String?
    public let sequence: Int64?
    public let from: ReaderJSONValue
    public let target: ReaderJSONValue
    public let newToc: [ReaderJSONValue]
    public let currentChapterTitle: String
    public let currentChapterIndex: Int64
    public let updatedAt: Int64

    public init(operationId: String? = nil, sequence: Int64? = nil, from: ReaderJSONValue, target: ReaderJSONValue, newToc: [ReaderJSONValue], currentChapterTitle: String, currentChapterIndex: Int64, updatedAt: Int64) {
        self.operationId = operationId
        self.sequence = sequence
        self.from = from
        self.target = target
        self.newToc = newToc
        self.currentChapterTitle = currentChapterTitle
        self.currentChapterIndex = currentChapterIndex
        self.updatedAt = updatedAt
    }
}

/// Params schema `SourceSwitchTransactionParams` (3 declared properties).
public struct SourceSwitchTransactionParams: Codable, Sendable {
    public let transactionId: String
    public let operationId: String?
    public let sequence: Int64?

    public init(transactionId: String, operationId: String? = nil, sequence: Int64? = nil) {
        self.transactionId = transactionId
        self.operationId = operationId
        self.sequence = sequence
    }
}

/// Params schema `SourceSwitchTransactionQueryParams` (4 declared properties).
public struct SourceSwitchTransactionQueryParams: Codable, Sendable {
    public let operationId: String
    public let expected: ReaderJSONValue?
    public let expectedStage: ReaderJSONValue?
    public let expectedCanonical: ReaderJSONValue?

    public init(operationId: String, expected: ReaderJSONValue? = nil, expectedStage: ReaderJSONValue? = nil, expectedCanonical: ReaderJSONValue? = nil) {
        self.operationId = operationId
        self.expected = expected
        self.expectedStage = expectedStage
        self.expectedCanonical = expectedCanonical
    }
}

/// Params schema `SourceUpdateParams` (2 declared properties).
public struct SourceUpdateParams: Codable, Sendable {
    public let sourceId: String
    public let enabled: Bool

    public init(sourceId: String, enabled: Bool) {
        self.sourceId = sourceId
        self.enabled = enabled
    }
}

/// Params schema `SyncBackupAutoDecisionParams` (3 declared properties).
public struct SyncBackupAutoDecisionParams: Codable, Sendable {
    public let enabled: Bool
    public let lastBackupAt: Int64?
    public let evaluatedAt: Int64

    public init(enabled: Bool, lastBackupAt: Int64? = nil, evaluatedAt: Int64) {
        self.enabled = enabled
        self.lastBackupAt = lastBackupAt
        self.evaluatedAt = evaluatedAt
    }
}

/// Params schema `SyncBackupContentPlanParams` (1 declared properties).
public struct SyncBackupContentPlanParams: Codable, Sendable {
    public let request: ReaderJSONValue

    public init(request: ReaderJSONValue) {
        self.request = request
    }
}

/// Params schema `SyncBackupParams` (2 declared properties).
public struct SyncBackupParams: Codable, Sendable {
    public let package: ReaderJSONValue
    public let policy: ReaderJSONValue

    public init(package: ReaderJSONValue, policy: ReaderJSONValue) {
        self.package = package
        self.policy = policy
    }
}

/// Params schema `SyncBackupRestoreScopePlanParams` (1 declared properties).
public struct SyncBackupRestoreScopePlanParams: Codable, Sendable {
    public let request: ReaderJSONValue

    public init(request: ReaderJSONValue) {
        self.request = request
    }
}

/// Params schema `SyncBackupRetentionParams` (4 declared properties).
public struct SyncBackupRetentionParams: Codable, Sendable {
    public let config: ReaderJSONValue
    public let preservingBackupId: String
    public let evaluatedAt: Int64
    public let candidates: [ReaderJSONValue]?

    public init(config: ReaderJSONValue, preservingBackupId: String, evaluatedAt: Int64, candidates: [ReaderJSONValue]? = nil) {
        self.config = config
        self.preservingBackupId = preservingBackupId
        self.evaluatedAt = evaluatedAt
        self.candidates = candidates
    }
}

/// Params schema `SyncConflictResolveParams` (6 declared properties).
public struct SyncConflictResolveParams: Codable, Sendable {
    public let local: ReaderJSONValue
    public let remote: ReaderJSONValue
    public let mergedSnapshotId: String?
    public let mergedDeviceId: String?
    public let mergedCreatedAt: Int64?
    public let resolutions: [ReaderJSONValue]

    public init(local: ReaderJSONValue, remote: ReaderJSONValue, mergedSnapshotId: String? = nil, mergedDeviceId: String? = nil, mergedCreatedAt: Int64? = nil, resolutions: [ReaderJSONValue]) {
        self.local = local
        self.remote = remote
        self.mergedSnapshotId = mergedSnapshotId
        self.mergedDeviceId = mergedDeviceId
        self.mergedCreatedAt = mergedCreatedAt
        self.resolutions = resolutions
    }
}

/// Params schema `SyncMergeParams` (5 declared properties).
public struct SyncMergeParams: Codable, Sendable {
    public let local: ReaderJSONValue
    public let remote: ReaderJSONValue
    public let mergedSnapshotId: String?
    public let mergedDeviceId: String?
    public let mergedCreatedAt: Int64?

    public init(local: ReaderJSONValue, remote: ReaderJSONValue, mergedSnapshotId: String? = nil, mergedDeviceId: String? = nil, mergedCreatedAt: Int64? = nil) {
        self.local = local
        self.remote = remote
        self.mergedSnapshotId = mergedSnapshotId
        self.mergedDeviceId = mergedDeviceId
        self.mergedCreatedAt = mergedCreatedAt
    }
}

/// Params schema `SyncWebDavBackupReceiptQueryParams` (3 declared properties).
public struct SyncWebDavBackupReceiptQueryParams: Codable, Sendable {
    public let transactionId: String
    public let auth: String?
    public let response: ReaderJSONValue?

    public init(transactionId: String, auth: String? = nil, response: ReaderJSONValue? = nil) {
        self.transactionId = transactionId
        self.auth = auth
        self.response = response
    }
}

/// Params schema `SyncWebDavBackupRetentionSkipParams` (2 declared properties).
public struct SyncWebDavBackupRetentionSkipParams: Codable, Sendable {
    public let transactionId: String
    public let response: ReaderJSONValue?

    public init(transactionId: String, response: ReaderJSONValue? = nil) {
        self.transactionId = transactionId
        self.response = response
    }
}

/// Params schema `SyncWebDavDirectoryListPlanParams` (3 declared properties).
public struct SyncWebDavDirectoryListPlanParams: Codable, Sendable {
    public let baseUrl: String
    public let directory: String
    public let auth: String?

    public init(baseUrl: String, directory: String, auth: String? = nil) {
        self.baseUrl = baseUrl
        self.directory = directory
        self.auth = auth
    }
}

/// Params schema `SyncWebDavMultistatusParseParams` (1 declared properties).
public struct SyncWebDavMultistatusParseParams: Codable, Sendable {
    public let response: ReaderJSONValue

    public init(response: ReaderJSONValue) {
        self.response = response
    }
}

/// Params schema `SyncWebDavPlanParams` (3 declared properties).
public struct SyncWebDavPlanParams: Codable, Sendable {
    public let baseUrl: String
    public let auth: String?
    public let requests: [ReaderJSONValue]?

    public init(baseUrl: String, auth: String? = nil, requests: [ReaderJSONValue]? = nil) {
        self.baseUrl = baseUrl
        self.auth = auth
        self.requests = requests
    }
}

/// Params schema `SyncWebDavProgressMergeParams` (3 declared properties).
public struct SyncWebDavProgressMergeParams: Codable, Sendable {
    public let localRecords: [ReaderJSONValue]
    public let remoteRecords: [ReaderJSONValue]
    public let config: ReaderJSONValue

    public init(localRecords: [ReaderJSONValue], remoteRecords: [ReaderJSONValue], config: ReaderJSONValue) {
        self.localRecords = localRecords
        self.remoteRecords = remoteRecords
        self.config = config
    }
}

/// Params schema `SyncWebDavProgressPushPlanParams` (3 declared properties).
public struct SyncWebDavProgressPushPlanParams: Codable, Sendable {
    public let localRecords: [ReaderJSONValue]
    public let remoteRecords: [ReaderJSONValue]
    public let conflictPolicy: String

    public init(localRecords: [ReaderJSONValue], remoteRecords: [ReaderJSONValue], conflictPolicy: String) {
        self.localRecords = localRecords
        self.remoteRecords = remoteRecords
        self.conflictPolicy = conflictPolicy
    }
}

/// Params schema `SyncWebDavRemoteBookLocalImportPlanParams` (2 declared properties).
public struct SyncWebDavRemoteBookLocalImportPlanParams: Codable, Sendable {
    public let book: ReaderJSONValue
    public let downloadedByteCount: Int64

    public init(book: ReaderJSONValue, downloadedByteCount: Int64) {
        self.book = book
        self.downloadedByteCount = downloadedByteCount
    }
}

/// Params schema `SyncWebDavRemoteBookPlanParams` (1 declared properties).
public struct SyncWebDavRemoteBookPlanParams: Codable, Sendable {
    public let request: ReaderJSONValue

    public init(request: ReaderJSONValue) {
        self.request = request
    }
}

/// Params schema `SyncWebDavRemoteBookResultParams` (1 declared properties).
public struct SyncWebDavRemoteBookResultParams: Codable, Sendable {
    public let request: ReaderJSONValue

    public init(request: ReaderJSONValue) {
        self.request = request
    }
}

/// Params schema `SyncWebDavTransactionAbortParams` (2 declared properties).
public struct SyncWebDavTransactionAbortParams: Codable, Sendable {
    public let transactionId: String
    public let publisherUndispatched: Bool?

    public init(transactionId: String, publisherUndispatched: Bool? = nil) {
        self.transactionId = transactionId
        self.publisherUndispatched = publisherUndispatched
    }
}

/// Params schema `SyncWebDavTransactionAdvanceParams` (2 declared properties).
public struct SyncWebDavTransactionAdvanceParams: Codable, Sendable {
    public let transactionId: String
    public let responses: [ReaderJSONValue]

    public init(transactionId: String, responses: [ReaderJSONValue]) {
        self.transactionId = transactionId
        self.responses = responses
    }
}

/// Params schema `SyncWebDavTransactionCommitParams` (4 declared properties).
public struct SyncWebDavTransactionCommitParams: Codable, Sendable {
    public let hostConfigApplied: Bool?
    public let queryOnly: Bool?
    public let transactionId: String
    public let appliedChecksum: String

    public init(hostConfigApplied: Bool? = nil, queryOnly: Bool? = nil, transactionId: String, appliedChecksum: String) {
        self.hostConfigApplied = hostConfigApplied
        self.queryOnly = queryOnly
        self.transactionId = transactionId
        self.appliedChecksum = appliedChecksum
    }
}

/// Params schema `SyncWebDavTransactionResolveParams` (2 declared properties).
public struct SyncWebDavTransactionResolveParams: Codable, Sendable {
    public let transactionId: String
    public let choice: String

    public init(transactionId: String, choice: String) {
        self.transactionId = transactionId
        self.choice = choice
    }
}

/// Params schema `SyncWebDavTransactionStartParams` (10 declared properties).
public struct SyncWebDavTransactionStartParams: Codable, Sendable {
    public let systemScheme: String?
    public let hostConfig: ReaderJSONValue?
    public let operation: String
    public let baseUrl: String
    public let auth: String?
    public let directory: String
    public let encryptionKey: String?
    public let maxBackups: Int64?
    public let maxAgeDays: Int64?
    public let operationId: String?

    public init(systemScheme: String? = nil, hostConfig: ReaderJSONValue? = nil, operation: String, baseUrl: String, auth: String? = nil, directory: String, encryptionKey: String? = nil, maxBackups: Int64? = nil, maxAgeDays: Int64? = nil, operationId: String? = nil) {
        self.systemScheme = systemScheme
        self.hostConfig = hostConfig
        self.operation = operation
        self.baseUrl = baseUrl
        self.auth = auth
        self.directory = directory
        self.encryptionKey = encryptionKey
        self.maxBackups = maxBackups
        self.maxAgeDays = maxAgeDays
        self.operationId = operationId
    }
}

/// Params schema `TtsChapterPlanParams` (3 declared properties).
public struct TtsChapterPlanParams: Codable, Sendable {
    public let chapter: ReaderJSONValue
    public let drainBehavior: ReaderJSONValue?
    public let nextChapter: ReaderJSONValue?

    public init(chapter: ReaderJSONValue, drainBehavior: ReaderJSONValue? = nil, nextChapter: ReaderJSONValue? = nil) {
        self.chapter = chapter
        self.drainBehavior = drainBehavior
        self.nextChapter = nextChapter
    }
}

/// Params schema `TtsConfigPutParams` (5 declared properties).
public struct TtsConfigPutParams: Codable, Sendable {
    public let engine: String?
    public let rate: Int64
    public let pitch: Int64
    public let followSys: Bool
    public let ratePercent: Int64?

    public init(engine: String? = nil, rate: Int64, pitch: Int64, followSys: Bool, ratePercent: Int64? = nil) {
        self.engine = engine
        self.rate = rate
        self.pitch = pitch
        self.followSys = followSys
        self.ratePercent = ratePercent
    }
}

/// Params schema `TtsQueueNextParams` (1 declared properties).
public struct TtsQueueNextParams: Codable, Sendable {
    public let chapter: ReaderJSONValue

    public init(chapter: ReaderJSONValue) {
        self.chapter = chapter
    }
}

/// Params schema `TtsQueuePauseParams` (1 declared properties).
public struct TtsQueuePauseParams: Codable, Sendable {
    public let chapter: ReaderJSONValue

    public init(chapter: ReaderJSONValue) {
        self.chapter = chapter
    }
}

/// Params schema `TtsQueuePlayParams` (2 declared properties).
public struct TtsQueuePlayParams: Codable, Sendable {
    public let plan: ReaderJSONValue
    public let startSliceIndex: Int64?

    public init(plan: ReaderJSONValue, startSliceIndex: Int64? = nil) {
        self.plan = plan
        self.startSliceIndex = startSliceIndex
    }
}

/// Params schema `TtsQueuePrevParams` (1 declared properties).
public struct TtsQueuePrevParams: Codable, Sendable {
    public let chapter: ReaderJSONValue

    public init(chapter: ReaderJSONValue) {
        self.chapter = chapter
    }
}

/// Params schema `TtsQueueReportCallbackParams` (6 declared properties).
public struct TtsQueueReportCallbackParams: Codable, Sendable {
    public let chapter: ReaderJSONValue
    public let sliceIndex: Int64
    public let status: ReaderJSONValue
    public let callbackId: String
    public let failurePolicy: ReaderJSONValue?
    public let failureLimit: Int64?

    public init(chapter: ReaderJSONValue, sliceIndex: Int64, status: ReaderJSONValue, callbackId: String, failurePolicy: ReaderJSONValue? = nil, failureLimit: Int64? = nil) {
        self.chapter = chapter
        self.sliceIndex = sliceIndex
        self.status = status
        self.callbackId = callbackId
        self.failurePolicy = failurePolicy
        self.failureLimit = failureLimit
    }
}

/// Params schema `TtsQueueReportStatusParams` (3 declared properties).
public struct TtsQueueReportStatusParams: Codable, Sendable {
    public let chapter: ReaderJSONValue
    public let sliceIndex: Int64
    public let status: ReaderJSONValue

    public init(chapter: ReaderJSONValue, sliceIndex: Int64, status: ReaderJSONValue) {
        self.chapter = chapter
        self.sliceIndex = sliceIndex
        self.status = status
    }
}

/// Params schema `TtsQueueResumeParams` (1 declared properties).
public struct TtsQueueResumeParams: Codable, Sendable {
    public let chapter: ReaderJSONValue

    public init(chapter: ReaderJSONValue) {
        self.chapter = chapter
    }
}

/// Params schema `TtsQueueSeekParams` (2 declared properties).
public struct TtsQueueSeekParams: Codable, Sendable {
    public let chapter: ReaderJSONValue
    public let sliceIndex: Int64

    public init(chapter: ReaderJSONValue, sliceIndex: Int64) {
        self.chapter = chapter
        self.sliceIndex = sliceIndex
    }
}

/// Params schema `TtsQueueSetRateParams` (2 declared properties).
public struct TtsQueueSetRateParams: Codable, Sendable {
    public let chapter: ReaderJSONValue
    public let rate: Int64

    public init(chapter: ReaderJSONValue, rate: Int64) {
        self.chapter = chapter
        self.rate = rate
    }
}

/// Params schema `TtsQueueSkipParams` (1 declared properties).
public struct TtsQueueSkipParams: Codable, Sendable {
    public let chapter: ReaderJSONValue

    public init(chapter: ReaderJSONValue) {
        self.chapter = chapter
    }
}

/// Params schema `TtsQueueStatusParams` (1 declared properties).
public struct TtsQueueStatusParams: Codable, Sendable {
    public let chapter: ReaderJSONValue

    public init(chapter: ReaderJSONValue) {
        self.chapter = chapter
    }
}

/// Params schema `TtsQueueStopParams` (1 declared properties).
public struct TtsQueueStopParams: Codable, Sendable {
    public let chapter: ReaderJSONValue

    public init(chapter: ReaderJSONValue) {
        self.chapter = chapter
    }
}

/// Params schema `TtsSliceParams` (3 declared properties).
public struct TtsSliceParams: Codable, Sendable {
    public let chapter: ReaderJSONValue
    public let content: String
    public let strategy: ReaderJSONValue?

    public init(chapter: ReaderJSONValue, content: String, strategy: ReaderJSONValue? = nil) {
        self.chapter = chapter
        self.content = content
        self.strategy = strategy
    }
}

/// Params schema `TxtTocRuleCreateParams` (6 declared properties).
public struct TxtTocRuleCreateParams: Codable, Sendable {
    public let id: Int64?
    public let name: String
    public let rule: String
    public let example: String?
    public let serialNumber: Int64?
    public let enable: Bool?

    public init(id: Int64? = nil, name: String, rule: String, example: String? = nil, serialNumber: Int64? = nil, enable: Bool? = nil) {
        self.id = id
        self.name = name
        self.rule = rule
        self.example = example
        self.serialNumber = serialNumber
        self.enable = enable
    }
}

/// Params schema `TxtTocRuleDeleteParams` (1 declared properties).
public struct TxtTocRuleDeleteParams: Codable, Sendable {
    public let id: Int64

    public init(id: Int64) {
        self.id = id
    }
}

/// Params schema `TxtTocRuleListParams` (1 declared properties).
public struct TxtTocRuleListParams: Codable, Sendable {
    public let enabledOnly: Bool?

    public init(enabledOnly: Bool? = nil) {
        self.enabledOnly = enabledOnly
    }
}

/// Params schema `TxtTocRulePreviewParams` (5 declared properties).
public struct TxtTocRulePreviewParams: Codable, Sendable {
    public let bookId: String
    public let filePath: String
    public let draft: ReaderJSONValue
    public let editingRuleId: Int64?
    public let limit: Int64?

    public init(bookId: String, filePath: String, draft: ReaderJSONValue, editingRuleId: Int64? = nil, limit: Int64? = nil) {
        self.bookId = bookId
        self.filePath = filePath
        self.draft = draft
        self.editingRuleId = editingRuleId
        self.limit = limit
    }
}

/// Params schema `TxtTocRuleUpdateParams` (6 declared properties).
public struct TxtTocRuleUpdateParams: Codable, Sendable {
    public let id: Int64
    public let name: String?
    public let rule: String?
    public let example: String?
    public let serialNumber: Int64?
    public let enable: Bool?

    public init(id: Int64, name: String? = nil, rule: String? = nil, example: String? = nil, serialNumber: Int64? = nil, enable: Bool? = nil) {
        self.id = id
        self.name = name
        self.rule = rule
        self.example = example
        self.serialNumber = serialNumber
        self.enable = enable
    }
}

/// Losslessly carries open objects owned by Core, including import journals.
public enum ReaderM1JSONValue: Codable, Sendable, Equatable {
    case null
    case bool(Bool)
    case integer(Int64)
    case unsignedInteger(UInt64)
    case number(Double)
    case string(String)
    case array([ReaderM1JSONValue])
    case object([String: ReaderM1JSONValue])

    public init(from decoder: any Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() { self = .null }
        else if let boolean = try? value.decode(Bool.self) { self = .bool(boolean) }
        else if let integer = try? value.decode(Int64.self) { self = .integer(integer) }
        else if let integer = try? value.decode(UInt64.self) { self = .unsignedInteger(integer) }
        else if let number = try? value.decode(Double.self) { self = .number(number) }
        else if let string = try? value.decode(String.self) { self = .string(string) }
        else if let array = try? value.decode([ReaderM1JSONValue].self) { self = .array(array) }
        else { self = .object(try value.decode([String: ReaderM1JSONValue].self)) }
    }

    public func encode(to encoder: any Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case .null: try value.encodeNil()
        case .bool(let boolean): try value.encode(boolean)
        case .integer(let integer): try value.encode(integer)
        case .unsignedInteger(let integer): try value.encode(integer)
        case .number(let number): try value.encode(number)
        case .string(let string): try value.encode(string)
        case .array(let array): try value.encode(array)
        case .object(let object): try value.encode(object)
        }
    }
}

/// An optional property whose explicit null is a business operation.
public enum PatchField<Value: Codable & Sendable>: Sendable {
    case absent
    case null
    case value(Value)
}

private extension KeyedDecodingContainer {
    func decodePatchField<Value: Codable & Sendable>(
        _ valueType: Value.Type, forKey key: Key
    ) throws -> PatchField<Value> {
        guard contains(key) else { return .absent }
        if try decodeNil(forKey: key) { return .null }
        return .value(try decode(valueType, forKey: key))
    }
}

private extension KeyedEncodingContainer {
    mutating func encodePatchField<Value: Codable & Sendable>(
        _ field: PatchField<Value>, forKey key: Key
    ) throws {
        switch field {
        case .absent: break
        case .null: try encodeNil(forKey: key)
        case .value(let value): try encode(value, forKey: key)
        }
    }
}

public struct ReaderTypedCommand<Params: Codable & Sendable>: Codable, Sendable {
    public let protocolVersion: Int
    public let requestId: Int64
    public let method: ReaderCommandMethod
    public let params: Params

    public init(requestId: Int64, method: ReaderCommandMethod, params: Params) {
        self.protocolVersion = 1
        self.requestId = requestId
        self.method = method
        self.params = params
    }
}

public struct ReaderTypedResult<Payload: Codable & Sendable>: Codable, Sendable {
    public let deliveryId: Int64?
    public let protocolVersion: Int
    public let requestId: Int64
    public let type: String
    public let data: Payload
}

public struct ReaderTypedHostRequest<Params: Codable & Sendable>: Codable, Sendable {
    public let deliveryId: Int64?
    public let protocolVersion: Int
    public let requestId: Int64
    public let type: String
    public let operationId: Int64
    public let capability: ReaderHostCapability
    public let params: Params
}

/// The method identity and codec types retained by the original pending request.
public struct ReaderRPC<Params: Codable & Sendable, Payload: Codable & Sendable>: Sendable {
    public let method: ReaderCommandMethod

    public func encode(requestId: Int64, params: Params) throws -> Data {
        try JSONEncoder().encode(ReaderTypedCommand(requestId: requestId, method: method, params: params))
    }

    public func decode(_ bytes: Data) throws -> ReaderTypedResult<Payload> {
        try JSONDecoder().decode(ReaderTypedResult<Payload>.self, from: bytes)
    }
}

public enum ReaderM1 {
    public static let coreInfo = ReaderRPC<EmptyParams, CoreInfoData>(method: .coreInfo)
    public static let runtimeStatus = ReaderRPC<RuntimeStatusParams, RuntimeStatusData>(method: .runtimeStatus)
    public static let runtimeSetHostCapabilities = ReaderRPC<RuntimeSetHostCapabilitiesParams, RuntimeSetHostCapabilitiesData>(method: .runtimeSetHostCapabilities)
    public static let runtimeHostSmoke = ReaderRPC<M1HostSmokeParams, M1HostEchoData>(method: .runtimeHostSmoke)
    public static let hostComplete = ReaderRPC<M1HostCompleteParams, EmptyParams>(method: .hostComplete)
    public static let hostError = ReaderRPC<HostErrorParams, EmptyParams>(method: .hostError)
    public static let importParse = ReaderRPC<ImportLocalBookParseParams, ImportLocalBookParseData>(method: .importParse)
    public static let importPersist = ReaderRPC<ImportLocalBookPersistParams, ImportLocalBookPersistData>(method: .importPersist)
    public static let importRollback = ReaderRPC<ImportLocalBookRollbackParams, ImportLocalBookRollbackData>(method: .importRollback)
    public static let importFinalize = ReaderRPC<ImportLocalBookFinalizeParams, ImportLocalBookFinalizeData>(method: .importFinalize)
    public static let bookshelfAdd = ReaderRPC<BookshelfAddParams, BookshelfAddData>(method: .bookshelfAdd)
    public static let bookshelfList = ReaderRPC<BookshelfListParams, BookshelfListData>(method: .bookshelfList)
    public static let bookshelfGet = ReaderRPC<BookshelfGetParams, BookshelfGetData>(method: .bookshelfGet)
    public static let bookshelfBookUpdate = ReaderRPC<BookshelfBookUpdateParams, BookshelfBookUpdateData>(method: .bookshelfBookUpdate)
    public static let localBookToc = ReaderRPC<LocalBookTocParams, LocalBookTocData>(method: .localBookToc)
    public static let localBookChapterContent = ReaderRPC<LocalBookChapterContentParams, LocalBookChapterContentData>(method: .localBookChapterContent)
    public static let localBookChapterPresentationV1 = ReaderRPC<LocalBookChapterPresentationParams, LocalBookChapterPresentationData>(method: .localBookChapterPresentationV1)
    public static let localBookPresentationKindV1 = ReaderRPC<LocalBookTocParams, LocalBookPresentationKindData>(method: .localBookPresentationKindV1)
    public static let readingProgressGet = ReaderRPC<TextReadingProgressGetParams, ReadingProgressGetData>(method: .readingProgressGet)
    public static let readingProgressUpdate = ReaderRPC<TextReadingProgressUpdateParams, ReadingProgressUpdateData>(method: .readingProgressUpdate)
    public static let bookmarkCreate = ReaderRPC<BookmarkCreateParams, BookmarkCreateData>(method: .bookmarkCreate)
    public static let bookmarkList = ReaderRPC<BookmarkListParams, BookmarkListData>(method: .bookmarkList)
    public static let bookmarkUpdate = ReaderRPC<BookmarkUpdateParams, BookmarkUpdateData>(method: .bookmarkUpdate)
    public static let bookmarkDelete = ReaderRPC<BookmarkDeleteParams, BookmarkDeleteData>(method: .bookmarkDelete)
    public static let bookmarkOperationQuery = ReaderRPC<BookmarkOperationQueryParams, BookmarkOperationQueryData>(method: .bookmarkOperationQuery)
    public static let runtimeHostSmokeTimeNow = ReaderRPC<M1TimeNowSmokeParams, HostTimeNowResponse>(method: .runtimeHostSmoke)
    public static let runtimeHostSmokeCookieGet = ReaderRPC<M1CookieGetSmokeParams, HostCookieGetResponse>(method: .runtimeHostSmoke)
    public static let hostCompleteTimeNow = ReaderRPC<M1HostTimeCompleteParams, EmptyParams>(method: .hostComplete)
    public static let bookshelfRemove = ReaderRPC<BookshelfRemoveParams, BookshelfRemoveData>(method: .bookshelfRemove)
    public static let bookshelfRemoveBatch = ReaderRPC<BookshelfRemoveBatchParams, BookshelfRemoveBatchData>(method: .bookshelfRemoveBatch)
    public static let bookmarkOperationSettle = ReaderRPC<ReadingOperationBinding, BookmarkOperationReceipt>(method: .bookmarkOperationSettle)
    public static let readingProgressGetManga = ReaderRPC<MangaProgressGetParams, MangaProgressState>(method: .readingProgressGet)
    public static let readingProgressUpdateManga = ReaderRPC<MangaProgressUpdateParams, MangaProgressState>(method: .readingProgressUpdate)
}

public struct EmptyParams: Codable, Sendable {
    public init() {
    }
}

public struct CoreInfoData: Codable, Sendable {
    public let abiVersion: Int64
    public let protocolVersion: Int64
    public let buildVersion: String
    public let buildIdentity: CoreBuildIdentity
    public let capabilities: [String]
    public let sqliteUserVersion: Int64?
    public let storageFormat: CoreStorageFormatInfo?

    public init(abiVersion: Int64, protocolVersion: Int64, buildVersion: String, buildIdentity: CoreBuildIdentity, capabilities: [String], sqliteUserVersion: Int64? = nil, storageFormat: CoreStorageFormatInfo? = nil) {
        self.abiVersion = abiVersion
        self.protocolVersion = protocolVersion
        self.buildVersion = buildVersion
        self.buildIdentity = buildIdentity
        self.capabilities = capabilities
        self.sqliteUserVersion = sqliteUserVersion
        self.storageFormat = storageFormat
    }
}

public struct CoreBuildIdentity: Codable, Sendable {
    public let schemaVersion: Int64
    public let buildId: String
    public let gitCommit: String
    public let gitDirty: Bool
    public let cargoLockSha256: String
    public let protocolSha256: String
    public let rustProfile: String
    public let storageCompatibility: CoreBuildIdentityStorageCompatibility?

    public init(schemaVersion: Int64, buildId: String, gitCommit: String, gitDirty: Bool, cargoLockSha256: String, protocolSha256: String, rustProfile: String, storageCompatibility: CoreBuildIdentityStorageCompatibility? = nil) {
        self.schemaVersion = schemaVersion
        self.buildId = buildId
        self.gitCommit = gitCommit
        self.gitDirty = gitDirty
        self.cargoLockSha256 = cargoLockSha256
        self.protocolSha256 = protocolSha256
        self.rustProfile = rustProfile
        self.storageCompatibility = storageCompatibility
    }
}

public struct CoreBuildIdentityStorageCompatibility: Codable, Sendable {
    public let sqliteMaxUserVersion: Int64
    public let sqliteStorageSourceSha256: String

    public init(sqliteMaxUserVersion: Int64, sqliteStorageSourceSha256: String) {
        self.sqliteMaxUserVersion = sqliteMaxUserVersion
        self.sqliteStorageSourceSha256 = sqliteStorageSourceSha256
    }
}

public struct CoreStorageFormatInfo: Codable, Sendable {
    public let format: CoreStorageFormatInfoFormat
    public let portableSnapshotSupported: Bool
    public let capabilities: CoreStorageCapabilities?

    public init(format: CoreStorageFormatInfoFormat, portableSnapshotSupported: Bool, capabilities: CoreStorageCapabilities? = nil) {
        self.format = format
        self.portableSnapshotSupported = portableSnapshotSupported
        self.capabilities = capabilities
    }
}

/// Wire values of CoreStorageFormatInfoFormat.
public enum CoreStorageFormatInfoFormat: String, Codable, Sendable, CaseIterable {
    case legacy = "legacy"
    case library47 = "library47"
}

public struct CoreStorageCapabilities: Codable, Sendable {
    public let logicalExport: Bool
    public let logicalRestore: Bool
    public let legacyHostImport: Bool
    public let physicalBackup: Bool
    public let physicalRestore: Bool
    public let webdavConfigRestore: Bool
    public let activeLibrarySync: Bool
    public let logicalExportRequiresDataPreflight: Bool
    public let logicalRestoreRequiresCompleteCoverage: Bool
    public let resourceEvidenceOnly: Bool
    public let externalFilesIncluded: Bool

    public init(logicalExport: Bool, logicalRestore: Bool, legacyHostImport: Bool, physicalBackup: Bool, physicalRestore: Bool, webdavConfigRestore: Bool, activeLibrarySync: Bool, logicalExportRequiresDataPreflight: Bool, logicalRestoreRequiresCompleteCoverage: Bool, resourceEvidenceOnly: Bool, externalFilesIncluded: Bool) {
        self.logicalExport = logicalExport
        self.logicalRestore = logicalRestore
        self.legacyHostImport = legacyHostImport
        self.physicalBackup = physicalBackup
        self.physicalRestore = physicalRestore
        self.webdavConfigRestore = webdavConfigRestore
        self.activeLibrarySync = activeLibrarySync
        self.logicalExportRequiresDataPreflight = logicalExportRequiresDataPreflight
        self.logicalRestoreRequiresCompleteCoverage = logicalRestoreRequiresCompleteCoverage
        self.resourceEvidenceOnly = resourceEvidenceOnly
        self.externalFilesIncluded = externalFilesIncluded
    }
}

public struct RuntimeStatusParams: Codable, Sendable {
    public let includeCapacity: Bool?

    public init(includeCapacity: Bool? = nil) {
        self.includeCapacity = includeCapacity
    }
}

public struct RuntimeStatusData: Codable, Sendable {
    public let activeRequestCount: Int64
    public let activeRequestIds: [Int64]
    public let pendingHostOperationCount: Int64
    public let pendingHostOperations: [PendingHostOperationStatus]
    public let shuttingDown: Bool
    public let capacity: RuntimeCapacityStatusData?

    public init(activeRequestCount: Int64, activeRequestIds: [Int64], pendingHostOperationCount: Int64, pendingHostOperations: [PendingHostOperationStatus], shuttingDown: Bool, capacity: RuntimeCapacityStatusData? = nil) {
        self.activeRequestCount = activeRequestCount
        self.activeRequestIds = activeRequestIds
        self.pendingHostOperationCount = pendingHostOperationCount
        self.pendingHostOperations = pendingHostOperations
        self.shuttingDown = shuttingDown
        self.capacity = capacity
    }
}

public struct PendingHostOperationStatus: Codable, Sendable {
    public let operationId: Int64
    public let requestId: Int64
    public let capability: ReaderHostCapability
    public let state: String

    public init(operationId: Int64, requestId: Int64, capability: ReaderHostCapability, state: String) {
        self.operationId = operationId
        self.requestId = requestId
        self.capability = capability
        self.state = state
    }
}

public struct RuntimeCapacityStatusData: Codable, Sendable {
    public let current: RuntimeCapacityUsageData
    public let peak: RuntimeCapacityUsageData

    public init(current: RuntimeCapacityUsageData, peak: RuntimeCapacityUsageData) {
        self.current = current
        self.peak = peak
    }
}

public struct RuntimeCapacityUsageData: Codable, Sendable {
    public let retainedRequestCount: Int64
    public let queuedCommandCount: Int64
    public let queuedInputBytes: Int64
    public let inputReservedBytes: Int64
    public let resultReservedBytes: Int64
    public let hostReservedBytes: Int64
    public let pendingDeliveryCount: Int64
    public let hostOperationCount: Int64

    public init(retainedRequestCount: Int64, queuedCommandCount: Int64, queuedInputBytes: Int64, inputReservedBytes: Int64, resultReservedBytes: Int64, hostReservedBytes: Int64, pendingDeliveryCount: Int64, hostOperationCount: Int64) {
        self.retainedRequestCount = retainedRequestCount
        self.queuedCommandCount = queuedCommandCount
        self.queuedInputBytes = queuedInputBytes
        self.inputReservedBytes = inputReservedBytes
        self.resultReservedBytes = resultReservedBytes
        self.hostReservedBytes = hostReservedBytes
        self.pendingDeliveryCount = pendingDeliveryCount
        self.hostOperationCount = hostOperationCount
    }
}

public struct RuntimeSetHostCapabilitiesParams: Codable, Sendable {
    public let extensions: [String]?
    public let capabilities: [ReaderHostCapability]
    public let lanes: [HostLane]?
    public let platform: String?
    public let platformVersion: String?

    public init(extensions: [String]? = nil, capabilities: [ReaderHostCapability], lanes: [HostLane]? = nil, platform: String? = nil, platformVersion: String? = nil) {
        self.extensions = extensions
        self.capabilities = capabilities
        self.lanes = lanes
        self.platform = platform
        self.platformVersion = platformVersion
    }
}

/// Wire values of HostLane.
public enum HostLane: String, Codable, Sendable, CaseIterable {
    case antiBot = "anti_bot"
    case loginCookie = "login_cookie"
    case webviewRender = "webview_render"
    case mediaDownload = "media_download"
}

public struct RuntimeSetHostCapabilitiesData: Codable, Sendable {
    public let applied: Bool
    public let capabilities: Int64
    public let lanes: Int64

    public init(applied: Bool, capabilities: Int64, lanes: Int64) {
        self.applied = applied
        self.capabilities = capabilities
        self.lanes = lanes
    }
}

public struct M1HostSmokeParams: Codable, Sendable {
    public let capability: M1HostSmokeParamsCapability
    public let params: M1HostSmokePayload

    public init(capability: M1HostSmokeParamsCapability = .hostSmokeEcho, params: M1HostSmokePayload) {
        self.capability = capability
        self.params = params
    }
}

/// Wire values of M1HostSmokeParamsCapability.
public enum M1HostSmokeParamsCapability: String, Codable, Sendable, CaseIterable {
    case hostSmokeEcho = "host.smoke.echo"
}

public struct M1HostSmokePayload: Codable, Sendable {
    public let message: String?
    public let clock: String?
    public let timezone: String?

    public init(message: String? = nil, clock: String? = nil, timezone: String? = nil) {
        self.message = message
        self.clock = clock
        self.timezone = timezone
    }
}

public struct M1HostEchoData: Codable, Sendable {
    public let message: String

    public init(message: String) {
        self.message = message
    }
}

public struct M1HostCompleteParams: Codable, Sendable {
    public let operationId: Int64
    public let result: M1HostEchoData

    public init(operationId: Int64, result: M1HostEchoData) {
        self.operationId = operationId
        self.result = result
    }
}

public struct HostErrorParams: Codable, Sendable {
    public let operationId: Int64
    public let error: ReaderCoreError
    public let diagnostics: HostErrorDiagnostics?

    public init(operationId: Int64, error: ReaderCoreError, diagnostics: HostErrorDiagnostics? = nil) {
        self.operationId = operationId
        self.error = error
        self.diagnostics = diagnostics
    }
}

public struct HostErrorDiagnostics: Codable, Sendable {
    public let code: HostErrorCode
    public let phase: HostErrorPhase
    public let message: String?
    public let details: [String: ReaderM1JSONValue]?

    public init(code: HostErrorCode, phase: HostErrorPhase, message: String? = nil, details: [String: ReaderM1JSONValue]? = nil) {
        self.code = code
        self.phase = phase
        self.message = message
        self.details = details
    }
}

/// Wire values of HostErrorCode.
public enum HostErrorCode: String, Codable, Sendable, CaseIterable {
    case capabilityUnavailable = "CAPABILITY_UNAVAILABLE"
    case permissionDenied = "PERMISSION_DENIED"
    case timeout = "TIMEOUT"
    case networkError = "NETWORK_ERROR"
    case tlsError = "TLS_ERROR"
    case httpError = "HTTP_ERROR"
    case invalidResponse = "INVALID_RESPONSE"
    case cancelled = "CANCELLED"
    case challengeRequired = "CHALLENGE_REQUIRED"
    case `internal` = "INTERNAL"
}

/// Wire values of HostErrorPhase.
public enum HostErrorPhase: String, Codable, Sendable, CaseIterable {
    case request = "request"
    case transport = "transport"
    case response = "response"
    case decode = "decode"
    case storage = "storage"
    case runtime = "runtime"
}

public struct ImportLocalBookParseParams: Codable, Sendable {
    public let kind: ImportLocalBookParseParamsKind
    public let input: LocalBookParseParams

    public init(kind: ImportLocalBookParseParamsKind = .localBook, input: LocalBookParseParams) {
        self.kind = kind
        self.input = input
    }
}

/// Wire values of ImportLocalBookParseParamsKind.
public enum ImportLocalBookParseParamsKind: String, Codable, Sendable, CaseIterable {
    case localBook = "localBook"
}

public struct LocalBookParseParams: Codable, Sendable {
    public let bookId: String
    public let title: String?
    public let author: String?
    public let fileName: String?
    public let filePath: String?
    public let text: String?
    public let bytesBase64: String?
    public let format: String?

    public init(bookId: String, title: String? = nil, author: String? = nil, fileName: String? = nil, filePath: String? = nil, text: String? = nil, bytesBase64: String? = nil, format: String? = nil) {
        self.bookId = bookId
        self.title = title
        self.author = author
        self.fileName = fileName
        self.filePath = filePath
        self.text = text
        self.bytesBase64 = bytesBase64
        self.format = format
    }
}

public struct ImportLocalBookParseData: Codable, Sendable {
    public let kind: ImportLocalBookParseDataKind
    public let preview: ImportLocalBookPreview

    public init(kind: ImportLocalBookParseDataKind = .localBook, preview: ImportLocalBookPreview) {
        self.kind = kind
        self.preview = preview
    }
}

/// Wire values of ImportLocalBookParseDataKind.
public enum ImportLocalBookParseDataKind: String, Codable, Sendable, CaseIterable {
    case localBook = "localBook"
}

public struct ImportLocalBookPreview: Codable, Sendable {
    public let input: LocalBookParseParams
    public let summary: LocalBookImportData
    public let contentSha256: String

    public init(input: LocalBookParseParams, summary: LocalBookImportData, contentSha256: String) {
        self.input = input
        self.summary = summary
        self.contentSha256 = contentSha256
    }
}

public struct LocalBookImportData: Codable, Sendable {
    public let integrity: LocalBookIntegrity?
    public let book: LocalBookImportBook
    public let format: String
    public let encoding: String
    public let byteLen: Int64
    public let charLen: Int64
    public let chapterCount: Int64
    public let toc: [BookTocEntryData]

    public init(integrity: LocalBookIntegrity? = nil, book: LocalBookImportBook, format: String, encoding: String, byteLen: Int64, charLen: Int64, chapterCount: Int64, toc: [BookTocEntryData]) {
        self.integrity = integrity
        self.book = book
        self.format = format
        self.encoding = encoding
        self.byteLen = byteLen
        self.charLen = charLen
        self.chapterCount = chapterCount
        self.toc = toc
    }
}

public struct LocalBookIntegrity: Codable, Sendable {
    public let schemaVersion: Int64
    public let parserVersion: String
    public let readability: LocalBookIntegrityReadability
    public let sourceDocumentCount: Int64
    public let warnings: [String]

    public init(schemaVersion: Int64, parserVersion: String, readability: LocalBookIntegrityReadability, sourceDocumentCount: Int64, warnings: [String]) {
        self.schemaVersion = schemaVersion
        self.parserVersion = parserVersion
        self.readability = readability
        self.sourceDocumentCount = sourceDocumentCount
        self.warnings = warnings
    }
}

/// Wire values of LocalBookIntegrityReadability.
public enum LocalBookIntegrityReadability: String, Codable, Sendable, CaseIterable {
    case complete = "complete"
    case recoverable = "recoverable"
    case metadataOnly = "metadataOnly"
    case unreadable = "unreadable"
    case unverified = "unverified"
}

public struct LocalBookImportBook: Codable, Sendable {
    public let bookId: String
    public let title: String
    public let author: String
    public let coverUrl: String?
    public let intro: String?
    public let kind: String?
    public let lastChapter: String?
    public let variables: [String: String]?

    public init(bookId: String, title: String, author: String, coverUrl: String? = nil, intro: String? = nil, kind: String? = nil, lastChapter: String? = nil, variables: [String: String]? = nil) {
        self.bookId = bookId
        self.title = title
        self.author = author
        self.coverUrl = coverUrl
        self.intro = intro
        self.kind = kind
        self.lastChapter = lastChapter
        self.variables = variables
    }
}

public struct BookTocEntryData: Codable, Sendable {
    public let displayTitle: String?
    public let contextTitle: String?
    public let isVip: Bool?
    public let isPay: Bool?
    public let index: Int64
    public let title: String
    public let url: String
    public let level: Int64?
    public let variables: [String: String]?

    public init(displayTitle: String? = nil, contextTitle: String? = nil, isVip: Bool? = nil, isPay: Bool? = nil, index: Int64, title: String, url: String, level: Int64? = nil, variables: [String: String]? = nil) {
        self.displayTitle = displayTitle
        self.contextTitle = contextTitle
        self.isVip = isVip
        self.isPay = isPay
        self.index = index
        self.title = title
        self.url = url
        self.level = level
        self.variables = variables
    }
}

public struct ImportLocalBookPersistParams: Codable, Sendable {
    public let transactionId: String
    public let parsed: ImportLocalBookParseData

    public init(transactionId: String, parsed: ImportLocalBookParseData) {
        self.transactionId = transactionId
        self.parsed = parsed
    }
}

public struct ImportLocalBookPersistData: Codable, Sendable {
    public let persisted: ImportLocalBookPersistedData
    public let rollbackToken: ImportLocalBookRollbackToken

    public init(persisted: ImportLocalBookPersistedData, rollbackToken: ImportLocalBookRollbackToken) {
        self.persisted = persisted
        self.rollbackToken = rollbackToken
    }
}

public struct ImportLocalBookPersistedData: Codable, Sendable {
    public let kind: ImportLocalBookPersistedDataKind
    public let data: LocalBookImportData

    public init(kind: ImportLocalBookPersistedDataKind = .localBook, data: LocalBookImportData) {
        self.kind = kind
        self.data = data
    }
}

/// Wire values of ImportLocalBookPersistedDataKind.
public enum ImportLocalBookPersistedDataKind: String, Codable, Sendable, CaseIterable {
    case localBook = "localBook"
}

public struct ImportLocalBookRollbackToken: Codable, Sendable {
    public let kind: ImportLocalBookRollbackTokenKind
    public let token: ImportRollbackTokenBody

    public init(kind: ImportLocalBookRollbackTokenKind = .localBook, token: ImportRollbackTokenBody) {
        self.kind = kind
        self.token = token
    }
}

/// Wire values of ImportLocalBookRollbackTokenKind.
public enum ImportLocalBookRollbackTokenKind: String, Codable, Sendable, CaseIterable {
    case localBook = "localBook"
}

public struct ImportRollbackTokenBody: Codable, Sendable {
    public let transactionId: String
    public let journal: ReaderM1JSONValue

    public init(transactionId: String, journal: ReaderM1JSONValue) {
        self.transactionId = transactionId
        self.journal = journal
    }
}

public struct ImportLocalBookRollbackParams: Codable, Sendable {
    public let rollbackToken: ImportLocalBookRollbackToken

    public init(rollbackToken: ImportLocalBookRollbackToken) {
        self.rollbackToken = rollbackToken
    }
}

public struct ImportLocalBookRollbackData: Codable, Sendable {
    public let kind: ImportLocalBookRollbackDataKind
    public let data: ImportLocalBookRollbackDataData

    public init(kind: ImportLocalBookRollbackDataKind = .localBook, data: ImportLocalBookRollbackDataData) {
        self.kind = kind
        self.data = data
    }
}

/// Wire values of ImportLocalBookRollbackDataKind.
public enum ImportLocalBookRollbackDataKind: String, Codable, Sendable, CaseIterable {
    case localBook = "localBook"
}

public struct ImportLocalBookRollbackDataData: Codable, Sendable {
    public let bookId: String
    public let restored: Bool

    public init(bookId: String, restored: Bool) {
        self.bookId = bookId
        self.restored = restored
    }

    private enum CodingKeys: String, CodingKey {
        case bookId = "book_id"
        case restored = "restored"
    }
}

public struct ImportLocalBookFinalizeParams: Codable, Sendable {
    public let rollbackToken: ImportLocalBookRollbackToken

    public init(rollbackToken: ImportLocalBookRollbackToken) {
        self.rollbackToken = rollbackToken
    }
}

public struct ImportLocalBookFinalizeData: Codable, Sendable {
    public let kind: ImportLocalBookFinalizeDataKind
    public let data: ImportLocalBookFinalizeDataData

    public init(kind: ImportLocalBookFinalizeDataKind = .localBook, data: ImportLocalBookFinalizeDataData) {
        self.kind = kind
        self.data = data
    }
}

/// Wire values of ImportLocalBookFinalizeDataKind.
public enum ImportLocalBookFinalizeDataKind: String, Codable, Sendable, CaseIterable {
    case localBook = "localBook"
}

public struct ImportLocalBookFinalizeDataData: Codable, Sendable {
    public let bookId: String
    public let finalized: Bool

    public init(bookId: String, finalized: Bool) {
        self.bookId = bookId
        self.finalized = finalized
    }
}

public struct BookshelfAddParams: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let title: String
    public let author: String
    public let coverUrl: String?
    public let intro: String?
    public let kind: String?
    public let lastChapter: String?
    public let group: String?
    public let sortIndex: Int64?
    public let mangaFirstImage: MangaFirstImageReceipt?
    public let preparationRevision: Int64?
    public let requireReadable: Bool?

    public init(sourceId: String, bookId: String, title: String, author: String, coverUrl: String? = nil, intro: String? = nil, kind: String? = nil, lastChapter: String? = nil, group: String? = nil, sortIndex: Int64? = nil, mangaFirstImage: MangaFirstImageReceipt? = nil, preparationRevision: Int64? = nil, requireReadable: Bool? = nil) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.title = title
        self.author = author
        self.coverUrl = coverUrl
        self.intro = intro
        self.kind = kind
        self.lastChapter = lastChapter
        self.group = group
        self.sortIndex = sortIndex
        self.mangaFirstImage = mangaFirstImage
        self.preparationRevision = preparationRevision
        self.requireReadable = requireReadable
    }
}

public struct MangaFirstImageReceipt: Codable, Sendable {
    public let chapter: MangaChapterIdentity
    public let chapterIndex: Int64
    public let width: Int64
    public let height: Int64
    public let manifestVersion: String
    public let sourceRuleVersion: String
    public let decodeRevision: String
    public let pageId: String
    public let resourceRef: String
    public let imageRevision: String

    public init(chapter: MangaChapterIdentity, chapterIndex: Int64, width: Int64, height: Int64, manifestVersion: String, sourceRuleVersion: String, decodeRevision: String, pageId: String, resourceRef: String, imageRevision: String) {
        self.chapter = chapter
        self.chapterIndex = chapterIndex
        self.width = width
        self.height = height
        self.manifestVersion = manifestVersion
        self.sourceRuleVersion = sourceRuleVersion
        self.decodeRevision = decodeRevision
        self.pageId = pageId
        self.resourceRef = resourceRef
        self.imageRevision = imageRevision
    }
}

public struct MangaChapterIdentity: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterId: String

    public init(sourceId: String, bookId: String, chapterId: String) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterId = chapterId
    }
}

public struct BookshelfAddData: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let created: Bool
    public let addedAt: Int64

    public init(sourceId: String, bookId: String, created: Bool, addedAt: Int64) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.created = created
        self.addedAt = addedAt
    }
}

public struct BookshelfListParams: Codable, Sendable {
    public let anchor: BookshelfGetParams?
    public let pageProjection: Bool?
    public let membershipOnly: Bool?
    public let projectionRevision: String?
    public let readingState: BookshelfListParamsReadingState?
    public let sourceKind: BookshelfListParamsSourceKind?
    public let contentKind: BookshelfListParamsContentKind?
    public let sourceId: String?
    public let bookId: String?
    public let group: String?
    public let keyword: String?
    public let hasReadingProgress: Bool?
    public let sortBy: BookshelfListParamsSortBy?
    public let sortDirection: BookshelfListParamsSortDirection?
    public let offset: Int64?
    public let limit: Int64?
    public let hasGroup: Bool?

    public init(anchor: BookshelfGetParams? = nil, pageProjection: Bool? = nil, membershipOnly: Bool? = nil, projectionRevision: String? = nil, readingState: BookshelfListParamsReadingState? = nil, sourceKind: BookshelfListParamsSourceKind? = nil, contentKind: BookshelfListParamsContentKind? = nil, sourceId: String? = nil, bookId: String? = nil, group: String? = nil, keyword: String? = nil, hasReadingProgress: Bool? = nil, sortBy: BookshelfListParamsSortBy? = nil, sortDirection: BookshelfListParamsSortDirection? = nil, offset: Int64? = nil, limit: Int64? = nil, hasGroup: Bool? = nil) {
        self.anchor = anchor
        self.pageProjection = pageProjection
        self.membershipOnly = membershipOnly
        self.projectionRevision = projectionRevision
        self.readingState = readingState
        self.sourceKind = sourceKind
        self.contentKind = contentKind
        self.sourceId = sourceId
        self.bookId = bookId
        self.group = group
        self.keyword = keyword
        self.hasReadingProgress = hasReadingProgress
        self.sortBy = sortBy
        self.sortDirection = sortDirection
        self.offset = offset
        self.limit = limit
        self.hasGroup = hasGroup
    }
}

public struct BookshelfGetParams: Codable, Sendable {
    public let sourceId: String
    public let bookId: String

    public init(sourceId: String, bookId: String) {
        self.sourceId = sourceId
        self.bookId = bookId
    }
}

/// Wire values of BookshelfListParamsReadingState.
public enum BookshelfListParamsReadingState: String, Codable, Sendable, CaseIterable {
    case all = "all"
    case unread = "unread"
    case reading = "reading"
    case finished = "finished"
}

/// Wire values of BookshelfListParamsSourceKind.
public enum BookshelfListParamsSourceKind: String, Codable, Sendable, CaseIterable {
    case all = "all"
    case local = "local"
    case online = "online"
}

/// Wire values of BookshelfListParamsContentKind.
public enum BookshelfListParamsContentKind: String, Codable, Sendable, CaseIterable {
    case all = "all"
    case text = "text"
    case manga = "manga"
}

/// Wire values of BookshelfListParamsSortBy.
public enum BookshelfListParamsSortBy: String, Codable, Sendable, CaseIterable {
    case manual = "manual"
    case addedAt = "addedAt"
    case lastReadAt = "lastReadAt"
    case title = "title"
    case author = "author"
}

/// Wire values of BookshelfListParamsSortDirection.
public enum BookshelfListParamsSortDirection: String, Codable, Sendable, CaseIterable {
    case ascending = "ascending"
    case descending = "descending"
}

public struct BookshelfListData: Codable, Sendable {
    public let offset: Int64?
    public let anchorFound: Bool?
    public let unfilteredTotal: Int64?
    public let unfilteredOnlineTotal: Int64?
    public let projectionRevision: String?
    public let changed: Bool?
    public let books: [BookshelfEntryData]
    public let total: Int64

    public init(offset: Int64? = nil, anchorFound: Bool? = nil, unfilteredTotal: Int64? = nil, unfilteredOnlineTotal: Int64? = nil, projectionRevision: String? = nil, changed: Bool? = nil, books: [BookshelfEntryData], total: Int64) {
        self.offset = offset
        self.anchorFound = anchorFound
        self.unfilteredTotal = unfilteredTotal
        self.unfilteredOnlineTotal = unfilteredOnlineTotal
        self.projectionRevision = projectionRevision
        self.changed = changed
        self.books = books
        self.total = total
    }
}

public struct BookshelfEntryData: Codable, Sendable {
    public let readingPosition: BookshelfReadingPositionData?
    public let sourceName: String?
    public let sourceId: String
    public let bookId: String
    public let title: String
    public let author: String
    public let coverUrl: String?
    public let intro: String?
    public let kind: String?
    public let lastChapter: String?
    public let addedAt: Int64
    public let lastReadAt: Int64?
    public let group: String?
    public let sortIndex: Int64
    public let contentKind: BookshelfEntryDataContentKind?
    public let unreadCount: Int64?
    public let lastCheckAt: Int64?
    public let currentChapterTitle: String?
    public let currentChapterIndex: Int64?
    public let chapterCount: Int64?
    public let readProgress: Int64?

    public init(readingPosition: BookshelfReadingPositionData? = nil, sourceName: String? = nil, sourceId: String, bookId: String, title: String, author: String, coverUrl: String? = nil, intro: String? = nil, kind: String? = nil, lastChapter: String? = nil, addedAt: Int64, lastReadAt: Int64? = nil, group: String? = nil, sortIndex: Int64, contentKind: BookshelfEntryDataContentKind? = nil, unreadCount: Int64? = nil, lastCheckAt: Int64? = nil, currentChapterTitle: String? = nil, currentChapterIndex: Int64? = nil, chapterCount: Int64? = nil, readProgress: Int64? = nil) {
        self.readingPosition = readingPosition
        self.sourceName = sourceName
        self.sourceId = sourceId
        self.bookId = bookId
        self.title = title
        self.author = author
        self.coverUrl = coverUrl
        self.intro = intro
        self.kind = kind
        self.lastChapter = lastChapter
        self.addedAt = addedAt
        self.lastReadAt = lastReadAt
        self.group = group
        self.sortIndex = sortIndex
        self.contentKind = contentKind
        self.unreadCount = unreadCount
        self.lastCheckAt = lastCheckAt
        self.currentChapterTitle = currentChapterTitle
        self.currentChapterIndex = currentChapterIndex
        self.chapterCount = chapterCount
        self.readProgress = readProgress
    }
}

public struct BookshelfReadingPositionData: Codable, Sendable {
    public let chapterIndex: Int64
    public let chapterOffset: Int64
    public let updatedAt: Int64
    public let locationRevision: String?
    public let bodyVersion: String?
    public let processingVersion: String?

    public init(chapterIndex: Int64, chapterOffset: Int64, updatedAt: Int64, locationRevision: String? = nil, bodyVersion: String? = nil, processingVersion: String? = nil) {
        self.chapterIndex = chapterIndex
        self.chapterOffset = chapterOffset
        self.updatedAt = updatedAt
        self.locationRevision = locationRevision
        self.bodyVersion = bodyVersion
        self.processingVersion = processingVersion
    }
}

/// Wire values of BookshelfEntryDataContentKind.
public enum BookshelfEntryDataContentKind: String, Codable, Sendable, CaseIterable {
    case text = "text"
    case manga = "manga"
    case audio = "audio"
}

public struct BookshelfGetData: Codable, Sendable {
    public let book: BookshelfEntryData?
    public let original: LocalBookOriginalData?
    public let originalExpectation: LocalBookOriginalExpectationData?

    public init(book: BookshelfEntryData?, original: LocalBookOriginalData? = nil, originalExpectation: LocalBookOriginalExpectationData? = nil) {
        self.book = book
        self.original = original
        self.originalExpectation = originalExpectation
    }

    private enum CodingKeys: String, CodingKey {
        case book = "book"
        case original = "original"
        case originalExpectation = "originalExpectation"
    }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        book = try fields.decode(BookshelfEntryData?.self, forKey: .book)
        original = try fields.decodeIfPresent(LocalBookOriginalData.self, forKey: .original)
        originalExpectation = try fields.decodeIfPresent(LocalBookOriginalExpectationData.self, forKey: .originalExpectation)
    }

    public func encode(to encoder: any Encoder) throws {
        var fields = encoder.container(keyedBy: CodingKeys.self)
        try fields.encode(book, forKey: .book)
        try fields.encodeIfPresent(original, forKey: .original)
        try fields.encodeIfPresent(originalExpectation, forKey: .originalExpectation)
    }
}

public struct LocalBookOriginalData: Codable, Sendable {
    public let schemaVersion: Int64
    public let provenance: String
    public let bookId: String
    public let sha256: String
    public let byteLength: Int64
    public let sourceFormat: String
    public let fileName: String?

    public init(schemaVersion: Int64, provenance: String, bookId: String, sha256: String, byteLength: Int64, sourceFormat: String, fileName: String? = nil) {
        self.schemaVersion = schemaVersion
        self.provenance = provenance
        self.bookId = bookId
        self.sha256 = sha256
        self.byteLength = byteLength
        self.sourceFormat = sourceFormat
        self.fileName = fileName
    }
}

public struct LocalBookOriginalExpectationData: Codable, Sendable {
    public let schemaVersion: Int64
    public let original: LocalBookOriginalData
    public let basis: String

    public init(schemaVersion: Int64, original: LocalBookOriginalData, basis: String) {
        self.schemaVersion = schemaVersion
        self.original = original
        self.basis = basis
    }
}

public struct BookshelfBookUpdateParams: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let title: String?
    public let author: PatchField<String>
    public let coverUrl: PatchField<String>
    public let intro: PatchField<String>
    public let kind: PatchField<String>
    public let lastChapter: PatchField<String>

    public init(sourceId: String, bookId: String, title: String? = nil, author: PatchField<String> = .absent, coverUrl: PatchField<String> = .absent, intro: PatchField<String> = .absent, kind: PatchField<String> = .absent, lastChapter: PatchField<String> = .absent) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.title = title
        self.author = author
        self.coverUrl = coverUrl
        self.intro = intro
        self.kind = kind
        self.lastChapter = lastChapter
    }

    private enum CodingKeys: String, CodingKey {
        case sourceId = "sourceId"
        case bookId = "bookId"
        case title = "title"
        case author = "author"
        case coverUrl = "coverUrl"
        case intro = "intro"
        case kind = "kind"
        case lastChapter = "lastChapter"
    }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        sourceId = try fields.decode(String.self, forKey: .sourceId)
        bookId = try fields.decode(String.self, forKey: .bookId)
        title = try fields.decodeIfPresent(String.self, forKey: .title)
        author = try fields.decodePatchField(String.self, forKey: .author)
        coverUrl = try fields.decodePatchField(String.self, forKey: .coverUrl)
        intro = try fields.decodePatchField(String.self, forKey: .intro)
        kind = try fields.decodePatchField(String.self, forKey: .kind)
        lastChapter = try fields.decodePatchField(String.self, forKey: .lastChapter)
    }

    public func encode(to encoder: any Encoder) throws {
        var fields = encoder.container(keyedBy: CodingKeys.self)
        try fields.encode(sourceId, forKey: .sourceId)
        try fields.encode(bookId, forKey: .bookId)
        try fields.encodeIfPresent(title, forKey: .title)
        try fields.encodePatchField(author, forKey: .author)
        try fields.encodePatchField(coverUrl, forKey: .coverUrl)
        try fields.encodePatchField(intro, forKey: .intro)
        try fields.encodePatchField(kind, forKey: .kind)
        try fields.encodePatchField(lastChapter, forKey: .lastChapter)
    }
}

public struct BookshelfBookUpdateData: Codable, Sendable {
    public let book: BookshelfEntryData

    public init(book: BookshelfEntryData) {
        self.book = book
    }
}

public struct LocalBookTocParams: Codable, Sendable {
    public let bookId: String

    public init(bookId: String) {
        self.bookId = bookId
    }
}

public struct LocalBookTocData: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let toc: [BookTocEntryData]

    public init(sourceId: String, bookId: String, toc: [BookTocEntryData]) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.toc = toc
    }
}

public struct LocalBookChapterContentParams: Codable, Sendable {
    public let directoryTargetProof: DirectoryTargetProof?
    public let bookId: String
    public let chapterIndex: Int64

    public init(directoryTargetProof: DirectoryTargetProof? = nil, bookId: String, chapterIndex: Int64) {
        self.directoryTargetProof = directoryTargetProof
        self.bookId = bookId
        self.chapterIndex = chapterIndex
    }
}

public struct DirectoryTargetProof: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let catalogRevision: String
    public let structureRevision: String
    public let nodeId: String
    public let chapterIndex: Int64
    public let url: String

    public init(sourceId: String, bookId: String, catalogRevision: String, structureRevision: String, nodeId: String, chapterIndex: Int64, url: String) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.catalogRevision = catalogRevision
        self.structureRevision = structureRevision
        self.nodeId = nodeId
        self.chapterIndex = chapterIndex
        self.url = url
    }
}

public struct LocalBookChapterContentData: Codable, Sendable {
    public let bodyVersion: String?
    public let processingVersion: String?
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: Int64
    public let chapterTitle: String
    public let content: String
    public let blocks: [ReadingDocumentBlockData]?

    public init(bodyVersion: String? = nil, processingVersion: String? = nil, sourceId: String, bookId: String, chapterIndex: Int64, chapterTitle: String, content: String, blocks: [ReadingDocumentBlockData]? = nil) {
        self.bodyVersion = bodyVersion
        self.processingVersion = processingVersion
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterIndex = chapterIndex
        self.chapterTitle = chapterTitle
        self.content = content
        self.blocks = blocks
    }
}

public enum ReadingDocumentBlockData: Codable, Sendable {
    case text(ReadingDocumentBlockDataText)
    case image(ReadingDocumentBlockDataImage)

    private enum CodingKeys: String, CodingKey { case kind }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        let tag = fields.contains(.kind) ? try fields.decode(String.self, forKey: .kind) : nil
        switch tag {
        case "text": self = .text(try ReadingDocumentBlockDataText(from: decoder))
        case "image": self = .image(try ReadingDocumentBlockDataImage(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: fields, debugDescription: "Unknown ReadingDocumentBlockData tag")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .text(let value): try value.encode(to: encoder)
        case .image(let value): try value.encode(to: encoder)
        }
    }
}

public struct ReadingDocumentBlockDataText: Codable, Sendable {
    public let kind: ReadingDocumentBlockDataTextKind
    public let text: String
    public let startScalar: Int64
    public let endScalar: Int64

    public init(kind: ReadingDocumentBlockDataTextKind = .text, text: String, startScalar: Int64, endScalar: Int64) {
        self.kind = kind
        self.text = text
        self.startScalar = startScalar
        self.endScalar = endScalar
    }
}

/// Wire values of ReadingDocumentBlockDataTextKind.
public enum ReadingDocumentBlockDataTextKind: String, Codable, Sendable, CaseIterable {
    case text = "text"
}

public struct ReadingDocumentBlockDataImage: Codable, Sendable {
    public let kind: ReadingDocumentBlockDataImageKind
    public let source: String
    public let imageWidthBasisPoints: Int64?
    public let imageIntrinsicWidth: Int64?
    public let imageIntrinsicHeight: Int64?
    public let startScalar: Int64
    public let endScalar: Int64

    public init(kind: ReadingDocumentBlockDataImageKind = .image, source: String, imageWidthBasisPoints: Int64? = nil, imageIntrinsicWidth: Int64? = nil, imageIntrinsicHeight: Int64? = nil, startScalar: Int64, endScalar: Int64) {
        self.kind = kind
        self.source = source
        self.imageWidthBasisPoints = imageWidthBasisPoints
        self.imageIntrinsicWidth = imageIntrinsicWidth
        self.imageIntrinsicHeight = imageIntrinsicHeight
        self.startScalar = startScalar
        self.endScalar = endScalar
    }
}

/// Wire values of ReadingDocumentBlockDataImageKind.
public enum ReadingDocumentBlockDataImageKind: String, Codable, Sendable, CaseIterable {
    case image = "image"
}

public struct LocalBookChapterPresentationParams: Codable, Sendable {
    public let bookId: String
    public let chapterIndex: Int64
    public let localSourcePath: String

    public init(bookId: String, chapterIndex: Int64, localSourcePath: String) {
        self.bookId = bookId
        self.chapterIndex = chapterIndex
        self.localSourcePath = localSourcePath
    }
}

public struct LocalBookChapterPresentationData: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: Int64
    public let bodyVersion: String
    public let processingVersion: String
    public let entryPath: String
    public let documentCanonicalContent: String
    public let chapterStartScalar: Int64
    public let chapterEndScalar: Int64

    public init(sourceId: String, bookId: String, chapterIndex: Int64, bodyVersion: String, processingVersion: String, entryPath: String, documentCanonicalContent: String, chapterStartScalar: Int64, chapterEndScalar: Int64) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterIndex = chapterIndex
        self.bodyVersion = bodyVersion
        self.processingVersion = processingVersion
        self.entryPath = entryPath
        self.documentCanonicalContent = documentCanonicalContent
        self.chapterStartScalar = chapterStartScalar
        self.chapterEndScalar = chapterEndScalar
    }
}

public struct LocalBookPresentationKindData: Codable, Sendable {
    public let sourceId: LocalBookPresentationKindDataSourceId
    public let bookId: String
    public let kind: LocalBookPresentationKindDataKind
    public let format: String
    public let reimportRequired: Bool

    public init(sourceId: LocalBookPresentationKindDataSourceId = .local, bookId: String, kind: LocalBookPresentationKindDataKind, format: String, reimportRequired: Bool) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.kind = kind
        self.format = format
        self.reimportRequired = reimportRequired
    }
}

/// Wire values of LocalBookPresentationKindDataSourceId.
public enum LocalBookPresentationKindDataSourceId: String, Codable, Sendable, CaseIterable {
    case local = "local"
}

/// Wire values of LocalBookPresentationKindDataKind.
public enum LocalBookPresentationKindDataKind: String, Codable, Sendable, CaseIterable {
    case text = "text"
    case ebook = "ebook"
}

public struct TextReadingProgressGetParams: Codable, Sendable {
    public let bookId: String
    public let sourceId: String?

    public init(bookId: String, sourceId: String? = nil) {
        self.bookId = bookId
        self.sourceId = sourceId
    }
}

public struct ReadingProgressGetData: Codable, Sendable {
    public let progressRevision: String?
    public let found: Bool
    public let progress: ReadingProgressData?
    public let pendingRestore: LocalPositionPendingRestoreData?

    public init(progressRevision: String? = nil, found: Bool, progress: ReadingProgressData?, pendingRestore: LocalPositionPendingRestoreData? = nil) {
        self.progressRevision = progressRevision
        self.found = found
        self.progress = progress
        self.pendingRestore = pendingRestore
    }

    private enum CodingKeys: String, CodingKey {
        case progressRevision = "progressRevision"
        case found = "found"
        case progress = "progress"
        case pendingRestore = "pendingRestore"
    }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        progressRevision = try fields.decodeIfPresent(String.self, forKey: .progressRevision)
        found = try fields.decode(Bool.self, forKey: .found)
        progress = try fields.decode(ReadingProgressData?.self, forKey: .progress)
        pendingRestore = try fields.decodeIfPresent(LocalPositionPendingRestoreData.self, forKey: .pendingRestore)
    }

    public func encode(to encoder: any Encoder) throws {
        var fields = encoder.container(keyedBy: CodingKeys.self)
        try fields.encodeIfPresent(progressRevision, forKey: .progressRevision)
        try fields.encode(found, forKey: .found)
        try fields.encode(progress, forKey: .progress)
        try fields.encodeIfPresent(pendingRestore, forKey: .pendingRestore)
    }
}

public struct ReadingProgressData: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: Int64
    public let chapterOffset: Int64
    public let chapterProgress: Double
    public let updatedAt: Int64
    public let deviceId: String?
    public let locationRevision: String?
    public let bodyVersion: String?
    public let processingVersion: String?

    public init(sourceId: String, bookId: String, chapterIndex: Int64, chapterOffset: Int64, chapterProgress: Double, updatedAt: Int64, deviceId: String? = nil, locationRevision: String? = nil, bodyVersion: String? = nil, processingVersion: String? = nil) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterIndex = chapterIndex
        self.chapterOffset = chapterOffset
        self.chapterProgress = chapterProgress
        self.updatedAt = updatedAt
        self.deviceId = deviceId
        self.locationRevision = locationRevision
        self.bodyVersion = bodyVersion
        self.processingVersion = processingVersion
    }
}

public struct LocalPositionPendingRestoreData: Codable, Sendable {
    public let archiveIds: [String]
    public let progressEntries: Int64
    public let legacyProgressEntries: Int64
    public let historyEntries: Int64
    public let bookmarkEntries: Int64
    public let highlightEntries: Int64
    public let currentProgressUnverified: Bool

    public init(archiveIds: [String], progressEntries: Int64, legacyProgressEntries: Int64, historyEntries: Int64, bookmarkEntries: Int64, highlightEntries: Int64, currentProgressUnverified: Bool) {
        self.archiveIds = archiveIds
        self.progressEntries = progressEntries
        self.legacyProgressEntries = legacyProgressEntries
        self.historyEntries = historyEntries
        self.bookmarkEntries = bookmarkEntries
        self.highlightEntries = highlightEntries
        self.currentProgressUnverified = currentProgressUnverified
    }
}

public struct TextReadingProgressUpdateParams: Codable, Sendable {
    public let directoryTargetProof: DirectoryTargetProof?
    public let expectedProgressRevision: String?
    public let bookId: String
    public let sourceId: String?
    public let deviceId: String?
    public let updatedAt: Int64?
    public let chapterIndex: Int64?
    public let chapterOffset: Int64?
    public let chapterProgress: Double?
    public let anchor: ReaderLocationAnchorData?
    public let layout: ReaderLocationLayoutData?
    public let chapterTitle: String?
    public let locationRevision: String?
    public let transactionId: String?
    public let expectedBodyVersion: String?
    public let expectedProcessingVersion: String?

    public init(directoryTargetProof: DirectoryTargetProof? = nil, expectedProgressRevision: String? = nil, bookId: String, sourceId: String? = nil, deviceId: String? = nil, updatedAt: Int64? = nil, chapterIndex: Int64? = nil, chapterOffset: Int64? = nil, chapterProgress: Double? = nil, anchor: ReaderLocationAnchorData? = nil, layout: ReaderLocationLayoutData? = nil, chapterTitle: String? = nil, locationRevision: String? = nil, transactionId: String? = nil, expectedBodyVersion: String? = nil, expectedProcessingVersion: String? = nil) {
        self.directoryTargetProof = directoryTargetProof
        self.expectedProgressRevision = expectedProgressRevision
        self.bookId = bookId
        self.sourceId = sourceId
        self.deviceId = deviceId
        self.updatedAt = updatedAt
        self.chapterIndex = chapterIndex
        self.chapterOffset = chapterOffset
        self.chapterProgress = chapterProgress
        self.anchor = anchor
        self.layout = layout
        self.chapterTitle = chapterTitle
        self.locationRevision = locationRevision
        self.transactionId = transactionId
        self.expectedBodyVersion = expectedBodyVersion
        self.expectedProcessingVersion = expectedProcessingVersion
    }
}

public struct ReaderLocationAnchorData: Codable, Sendable {
    public let chapterOffset: Int64
    public let chapterProgress: Double

    public init(chapterOffset: Int64, chapterProgress: Double) {
        self.chapterOffset = chapterOffset
        self.chapterProgress = chapterProgress
    }
}

public struct ReaderLocationLayoutData: Codable, Sendable {
    public let viewportWidth: Int64
    public let viewportHeight: Int64
    public let fontScale: Double
    public let lineHeight: Double?
    public let pageIndex: Int64?
    public let pageCount: Int64?

    public init(viewportWidth: Int64, viewportHeight: Int64, fontScale: Double, lineHeight: Double? = nil, pageIndex: Int64? = nil, pageCount: Int64? = nil) {
        self.viewportWidth = viewportWidth
        self.viewportHeight = viewportHeight
        self.fontScale = fontScale
        self.lineHeight = lineHeight
        self.pageIndex = pageIndex
        self.pageCount = pageCount
    }
}

public struct ReadingProgressUpdateData: Codable, Sendable {
    public let progressRevision: String?
    public let bookId: String
    public let sourceId: String
    public let deviceId: String?
    public let updatedAt: Int64
    public let chapterIndex: Int64
    public let chapterOffset: Int64
    public let chapterProgress: Double
    public let stored: Bool
    public let locationRevision: String?
    public let transactionId: String?
    public let sourceSwitchFinalized: Bool?
    public let bodyVersion: String?
    public let processingVersion: String?

    public init(progressRevision: String? = nil, bookId: String, sourceId: String, deviceId: String? = nil, updatedAt: Int64, chapterIndex: Int64, chapterOffset: Int64, chapterProgress: Double, stored: Bool, locationRevision: String? = nil, transactionId: String? = nil, sourceSwitchFinalized: Bool? = nil, bodyVersion: String? = nil, processingVersion: String? = nil) {
        self.progressRevision = progressRevision
        self.bookId = bookId
        self.sourceId = sourceId
        self.deviceId = deviceId
        self.updatedAt = updatedAt
        self.chapterIndex = chapterIndex
        self.chapterOffset = chapterOffset
        self.chapterProgress = chapterProgress
        self.stored = stored
        self.locationRevision = locationRevision
        self.transactionId = transactionId
        self.sourceSwitchFinalized = sourceSwitchFinalized
        self.bodyVersion = bodyVersion
        self.processingVersion = processingVersion
    }
}

public struct BookmarkCreateParams: Codable, Sendable {
    public let time: Int64?
    public let bookName: String?
    public let bookAuthor: String?
    public let chapterIndex: Int64?
    public let chapterPos: Int64?
    public let chapterName: String?
    public let bookText: String?
    public let content: String?
    public let positionScope: RemoteContentPositionScope?
    public let operationId: String?
    public let sequence: Int64?

    public init(time: Int64? = nil, bookName: String? = nil, bookAuthor: String? = nil, chapterIndex: Int64? = nil, chapterPos: Int64? = nil, chapterName: String? = nil, bookText: String? = nil, content: String? = nil, positionScope: RemoteContentPositionScope? = nil, operationId: String? = nil, sequence: Int64? = nil) {
        self.time = time
        self.bookName = bookName
        self.bookAuthor = bookAuthor
        self.chapterIndex = chapterIndex
        self.chapterPos = chapterPos
        self.chapterName = chapterName
        self.bookText = bookText
        self.content = content
        self.positionScope = positionScope
        self.operationId = operationId
        self.sequence = sequence
    }
}

public struct RemoteContentPositionScope: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: Int64
    public let bodyVersion: String
    public let processingVersion: String

    public init(sourceId: String, bookId: String, chapterIndex: Int64, bodyVersion: String, processingVersion: String) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterIndex = chapterIndex
        self.bodyVersion = bodyVersion
        self.processingVersion = processingVersion
    }
}

public struct BookmarkCreateData: Codable, Sendable {
    public let bookmark: BookmarkData

    public init(bookmark: BookmarkData) {
        self.bookmark = bookmark
    }
}

public struct BookmarkData: Codable, Sendable {
    public let time: Int64
    public let bookName: String
    public let bookAuthor: String
    public let chapterIndex: Int64
    public let chapterPos: Int64
    public let chapterName: String
    public let bookText: String
    public let content: String
    public let positionScope: RemoteContentPositionScope?

    public init(time: Int64, bookName: String, bookAuthor: String, chapterIndex: Int64, chapterPos: Int64, chapterName: String, bookText: String, content: String, positionScope: RemoteContentPositionScope? = nil) {
        self.time = time
        self.bookName = bookName
        self.bookAuthor = bookAuthor
        self.chapterIndex = chapterIndex
        self.chapterPos = chapterPos
        self.chapterName = chapterName
        self.bookText = bookText
        self.content = content
        self.positionScope = positionScope
    }
}

public struct BookmarkListParams: Codable, Sendable {
    public let bookName: String?
    public let bookAuthor: String?
    public let query: String?
    public let sortBy: BookmarkListParamsSortBy?

    public init(bookName: String? = nil, bookAuthor: String? = nil, query: String? = nil, sortBy: BookmarkListParamsSortBy? = nil) {
        self.bookName = bookName
        self.bookAuthor = bookAuthor
        self.query = query
        self.sortBy = sortBy
    }
}

/// Wire values of BookmarkListParamsSortBy.
public enum BookmarkListParamsSortBy: String, Codable, Sendable, CaseIterable {
    case time = "time"
    case bookLocation = "bookLocation"
}

public struct BookmarkListData: Codable, Sendable {
    public let bookmarks: [BookmarkData]

    public init(bookmarks: [BookmarkData]) {
        self.bookmarks = bookmarks
    }
}

public struct BookmarkUpdateParams: Codable, Sendable {
    public let time: Int64
    public let bookName: String?
    public let bookAuthor: String?
    public let chapterIndex: Int64?
    public let chapterPos: Int64?
    public let chapterName: String?
    public let bookText: String?
    public let content: String?
    public let positionScope: RemoteContentPositionScope?

    public init(time: Int64, bookName: String? = nil, bookAuthor: String? = nil, chapterIndex: Int64? = nil, chapterPos: Int64? = nil, chapterName: String? = nil, bookText: String? = nil, content: String? = nil, positionScope: RemoteContentPositionScope? = nil) {
        self.time = time
        self.bookName = bookName
        self.bookAuthor = bookAuthor
        self.chapterIndex = chapterIndex
        self.chapterPos = chapterPos
        self.chapterName = chapterName
        self.bookText = bookText
        self.content = content
        self.positionScope = positionScope
    }
}

public struct BookmarkUpdateData: Codable, Sendable {
    public let bookmark: BookmarkData

    public init(bookmark: BookmarkData) {
        self.bookmark = bookmark
    }
}

public struct BookmarkDeleteParams: Codable, Sendable {
    public let time: Int64
    public let operationId: String?
    public let sequence: Int64?

    public init(time: Int64, operationId: String? = nil, sequence: Int64? = nil) {
        self.time = time
        self.operationId = operationId
        self.sequence = sequence
    }
}

public struct BookmarkDeleteData: Codable, Sendable {
    public let time: Int64
    public let deleted: Bool

    public init(time: Int64, deleted: Bool) {
        self.time = time
        self.deleted = deleted
    }
}

public struct BookmarkOperationQueryParams: Codable, Sendable {
    public let operationId: String?
    public let expected: BookmarkOperationExpected?

    public init(operationId: String? = nil, expected: BookmarkOperationExpected? = nil) {
        self.operationId = operationId
        self.expected = expected
    }
}

public enum BookmarkOperationExpected: Codable, Sendable {
    case create(BookmarkOperationExpectedCreate)
    case delete(BookmarkOperationExpectedDelete)

    private enum CodingKeys: String, CodingKey { case action }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        let tag = fields.contains(.action) ? try fields.decode(String.self, forKey: .action) : nil
        switch tag {
        case "create": self = .create(try BookmarkOperationExpectedCreate(from: decoder))
        case "delete": self = .delete(try BookmarkOperationExpectedDelete(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .action, in: fields, debugDescription: "Unknown BookmarkOperationExpected tag")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .create(let value): try value.encode(to: encoder)
        case .delete(let value): try value.encode(to: encoder)
        }
    }
}

public struct BookmarkOperationExpectedCreate: Codable, Sendable {
    public let action: BookmarkOperationExpectedCreateAction
    public let params: BookmarkCreateParams

    public init(action: BookmarkOperationExpectedCreateAction = .create, params: BookmarkCreateParams) {
        self.action = action
        self.params = params
    }
}

/// Wire values of BookmarkOperationExpectedCreateAction.
public enum BookmarkOperationExpectedCreateAction: String, Codable, Sendable, CaseIterable {
    case create = "create"
}

public struct BookmarkOperationExpectedDelete: Codable, Sendable {
    public let action: BookmarkOperationExpectedDeleteAction
    public let params: BookmarkDeleteParams

    public init(action: BookmarkOperationExpectedDeleteAction = .delete, params: BookmarkDeleteParams) {
        self.action = action
        self.params = params
    }
}

/// Wire values of BookmarkOperationExpectedDeleteAction.
public enum BookmarkOperationExpectedDeleteAction: String, Codable, Sendable, CaseIterable {
    case delete = "delete"
}

public struct BookmarkOperationQueryData: Codable, Sendable {
    public let head: ReadingOperationBinding?
    public let receipt: BookmarkOperationReceipt?

    public init(head: ReadingOperationBinding?, receipt: BookmarkOperationReceipt?) {
        self.head = head
        self.receipt = receipt
    }

    private enum CodingKeys: String, CodingKey {
        case head = "head"
        case receipt = "receipt"
    }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        head = try fields.decode(ReadingOperationBinding?.self, forKey: .head)
        receipt = try fields.decode(BookmarkOperationReceipt?.self, forKey: .receipt)
    }

    public func encode(to encoder: any Encoder) throws {
        var fields = encoder.container(keyedBy: CodingKeys.self)
        try fields.encode(head, forKey: .head)
        try fields.encode(receipt, forKey: .receipt)
    }
}

public struct ReadingOperationBinding: Codable, Sendable {
    public let operationId: String
    public let sequence: Int64
    public let payloadFingerprint: String

    public init(operationId: String, sequence: Int64, payloadFingerprint: String) {
        self.operationId = operationId
        self.sequence = sequence
        self.payloadFingerprint = payloadFingerprint
    }
}

public struct BookmarkOperationReceipt: Codable, Sendable {
    public let binding: ReadingOperationBinding
    public let phase: BookmarkOperationReceiptPhase
    public let outcome: BookmarkOperationResult

    public init(binding: ReadingOperationBinding, phase: BookmarkOperationReceiptPhase, outcome: BookmarkOperationResult) {
        self.binding = binding
        self.phase = phase
        self.outcome = outcome
    }
}

/// Wire values of BookmarkOperationReceiptPhase.
public enum BookmarkOperationReceiptPhase: String, Codable, Sendable, CaseIterable {
    case committed = "committed"
    case settled = "settled"
}

public enum BookmarkOperationResult: Codable, Sendable {
    case create(BookmarkOperationResultCreate)
    case delete(BookmarkOperationResultDelete)

    private enum CodingKeys: String, CodingKey { case action }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        let tag = fields.contains(.action) ? try fields.decode(String.self, forKey: .action) : nil
        switch tag {
        case "create": self = .create(try BookmarkOperationResultCreate(from: decoder))
        case "delete": self = .delete(try BookmarkOperationResultDelete(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .action, in: fields, debugDescription: "Unknown BookmarkOperationResult tag")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .create(let value): try value.encode(to: encoder)
        case .delete(let value): try value.encode(to: encoder)
        }
    }
}

public struct BookmarkOperationResultCreate: Codable, Sendable {
    public let action: BookmarkOperationResultCreateAction
    public let result: BookmarkCreateData

    public init(action: BookmarkOperationResultCreateAction = .create, result: BookmarkCreateData) {
        self.action = action
        self.result = result
    }
}

/// Wire values of BookmarkOperationResultCreateAction.
public enum BookmarkOperationResultCreateAction: String, Codable, Sendable, CaseIterable {
    case create = "create"
}

public struct BookmarkOperationResultDelete: Codable, Sendable {
    public let action: BookmarkOperationResultDeleteAction
    public let result: BookmarkDeleteData

    public init(action: BookmarkOperationResultDeleteAction = .delete, result: BookmarkDeleteData) {
        self.action = action
        self.result = result
    }
}

/// Wire values of BookmarkOperationResultDeleteAction.
public enum BookmarkOperationResultDeleteAction: String, Codable, Sendable, CaseIterable {
    case delete = "delete"
}

public struct M1TimeNowSmokeParams: Codable, Sendable {
    public let capability: M1TimeNowSmokeParamsCapability
    public let params: HostTimeNowRequest

    public init(capability: M1TimeNowSmokeParamsCapability = .timeNow, params: HostTimeNowRequest) {
        self.capability = capability
        self.params = params
    }
}

/// Wire values of M1TimeNowSmokeParamsCapability.
public enum M1TimeNowSmokeParamsCapability: String, Codable, Sendable, CaseIterable {
    case timeNow = "time.now"
}

public struct HostTimeNowRequest: Codable, Sendable {
    public let clock: String?
    public let timezone: String?

    public init(clock: String? = nil, timezone: String? = nil) {
        self.clock = clock
        self.timezone = timezone
    }
}

public struct HostTimeNowResponse: Codable, Sendable {
    public let unixMillis: Int64
    public let iso8601: String
    public let timezone: String?

    public init(unixMillis: Int64, iso8601: String, timezone: String? = nil) {
        self.unixMillis = unixMillis
        self.iso8601 = iso8601
        self.timezone = timezone
    }
}

public struct M1CookieGetSmokeParams: Codable, Sendable {
    public let capability: M1CookieGetSmokeParamsCapability
    public let params: HostCookieGetRequest

    public init(capability: M1CookieGetSmokeParamsCapability = .cookieGet, params: HostCookieGetRequest) {
        self.capability = capability
        self.params = params
    }
}

/// Wire values of M1CookieGetSmokeParamsCapability.
public enum M1CookieGetSmokeParamsCapability: String, Codable, Sendable, CaseIterable {
    case cookieGet = "cookie.get"
}

public struct HostCookieGetRequest: Codable, Sendable {
    public let url: String?
    public let domain: String?
    public let name: String?
    public let sessionId: String?

    public init(url: String? = nil, domain: String? = nil, name: String? = nil, sessionId: String? = nil) {
        self.url = url
        self.domain = domain
        self.name = name
        self.sessionId = sessionId
    }
}

public struct HostCookieGetResponse: Codable, Sendable {
    public let cookies: [HostCookieRecord]

    public init(cookies: [HostCookieRecord]) {
        self.cookies = cookies
    }
}

public struct HostCookieRecord: Codable, Sendable {
    public let name: String
    public let value: String?
    public let domain: String?
    public let path: String?
    public let expiresAt: String?
    public let httpOnly: Bool?
    public let secure: Bool?
    public let sameSite: String?

    public init(name: String, value: String? = nil, domain: String? = nil, path: String? = nil, expiresAt: String? = nil, httpOnly: Bool? = nil, secure: Bool? = nil, sameSite: String? = nil) {
        self.name = name
        self.value = value
        self.domain = domain
        self.path = path
        self.expiresAt = expiresAt
        self.httpOnly = httpOnly
        self.secure = secure
        self.sameSite = sameSite
    }
}

public struct M1HostTimeCompleteParams: Codable, Sendable {
    public let operationId: Int64
    public let result: HostTimeNowResponse

    public init(operationId: Int64, result: HostTimeNowResponse) {
        self.operationId = operationId
        self.result = result
    }
}

public struct BookshelfRemoveParams: Codable, Sendable {
    public let sourceId: String
    public let bookId: String

    public init(sourceId: String, bookId: String) {
        self.sourceId = sourceId
        self.bookId = bookId
    }
}

public struct BookshelfRemoveData: Codable, Sendable {
    public let removed: Bool

    public init(removed: Bool) {
        self.removed = removed
    }
}

public struct BookshelfRemoveBatchParams: Codable, Sendable {
    public let targets: [BookshelfRemoveBatchTarget]

    public init(targets: [BookshelfRemoveBatchTarget]) {
        self.targets = targets
    }
}

public struct BookshelfRemoveBatchTarget: Codable, Sendable {
    public let sourceId: String
    public let bookId: String

    public init(sourceId: String, bookId: String) {
        self.sourceId = sourceId
        self.bookId = bookId
    }
}

public struct BookshelfRemoveBatchData: Codable, Sendable {
    public let requestedCount: Int64
    public let uniqueCount: Int64
    public let removedTargets: [BookshelfRemoveBatchTarget]
    public let missingTargets: [BookshelfRemoveBatchTarget]
    public let duplicateTargets: [BookshelfRemoveBatchTarget]

    public init(requestedCount: Int64, uniqueCount: Int64, removedTargets: [BookshelfRemoveBatchTarget], missingTargets: [BookshelfRemoveBatchTarget], duplicateTargets: [BookshelfRemoveBatchTarget]) {
        self.requestedCount = requestedCount
        self.uniqueCount = uniqueCount
        self.removedTargets = removedTargets
        self.missingTargets = missingTargets
        self.duplicateTargets = duplicateTargets
    }
}

public struct MangaProgressGetParams: Codable, Sendable {
    public let kind: MangaProgressGetParamsKind
    public let sourceId: String
    public let bookId: String

    public init(kind: MangaProgressGetParamsKind = .manga, sourceId: String, bookId: String) {
        self.kind = kind
        self.sourceId = sourceId
        self.bookId = bookId
    }
}

/// Wire values of MangaProgressGetParamsKind.
public enum MangaProgressGetParamsKind: String, Codable, Sendable, CaseIterable {
    case manga = "manga"
}

public struct MangaProgressState: Codable, Sendable {
    public let token: MangaProgressToken
    public let location: MangaLocation?

    public init(token: MangaProgressToken, location: MangaLocation?) {
        self.token = token
        self.location = location
    }

    private enum CodingKeys: String, CodingKey {
        case token = "token"
        case location = "location"
    }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        token = try fields.decode(MangaProgressToken.self, forKey: .token)
        location = try fields.decode(MangaLocation?.self, forKey: .location)
    }

    public func encode(to encoder: any Encoder) throws {
        var fields = encoder.container(keyedBy: CodingKeys.self)
        try fields.encode(token, forKey: .token)
        try fields.encode(location, forKey: .location)
    }
}

public struct MangaProgressToken: Codable, Sendable {
    public let epoch: Int64
    public let revision: Int64

    public init(epoch: Int64, revision: Int64) {
        self.epoch = epoch
        self.revision = revision
    }
}

public struct MangaLocation: Codable, Sendable {
    public let kind: MangaLocationKind
    public let chapter: MangaChapterIdentity
    public let manifestVersion: String
    public let pageId: String
    public let pageOrdinalFallback: Int64
    public let x: Double
    public let y: Double
    public let progressRevision: Int64

    public init(kind: MangaLocationKind = .manga, chapter: MangaChapterIdentity, manifestVersion: String, pageId: String, pageOrdinalFallback: Int64, x: Double, y: Double, progressRevision: Int64) {
        self.kind = kind
        self.chapter = chapter
        self.manifestVersion = manifestVersion
        self.pageId = pageId
        self.pageOrdinalFallback = pageOrdinalFallback
        self.x = x
        self.y = y
        self.progressRevision = progressRevision
    }
}

/// Wire values of MangaLocationKind.
public enum MangaLocationKind: String, Codable, Sendable, CaseIterable {
    case manga = "manga"
}

public struct MangaProgressUpdateParams: Codable, Sendable {
    public let kind: MangaProgressUpdateParamsKind
    public let location: MangaLocation
    public let expectedEpoch: Int64
    public let expectedRevision: Int64

    public init(kind: MangaProgressUpdateParamsKind = .manga, location: MangaLocation, expectedEpoch: Int64, expectedRevision: Int64) {
        self.kind = kind
        self.location = location
        self.expectedEpoch = expectedEpoch
        self.expectedRevision = expectedRevision
    }
}

/// Wire values of MangaProgressUpdateParamsKind.
public enum MangaProgressUpdateParamsKind: String, Codable, Sendable, CaseIterable {
    case manga = "manga"
}

public enum ReadingProgressGetParams: Codable, Sendable {
    case text(TextReadingProgressGetParams)
    case manga(MangaProgressGetParams)

    private enum CodingKeys: String, CodingKey { case kind }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        let tag = fields.contains(.kind) ? try fields.decode(String.self, forKey: .kind) : nil
        switch tag {
        case nil: self = .text(try TextReadingProgressGetParams(from: decoder))
        case "manga": self = .manga(try MangaProgressGetParams(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: fields, debugDescription: "Unknown ReadingProgressGetParams tag")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .text(let value): try value.encode(to: encoder)
        case .manga(let value): try value.encode(to: encoder)
        }
    }
}

public enum ReadingProgressUpdateParams: Codable, Sendable {
    case text(TextReadingProgressUpdateParams)
    case manga(MangaProgressUpdateParams)

    private enum CodingKeys: String, CodingKey { case kind }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        let tag = fields.contains(.kind) ? try fields.decode(String.self, forKey: .kind) : nil
        switch tag {
        case nil: self = .text(try TextReadingProgressUpdateParams(from: decoder))
        case "manga": self = .manga(try MangaProgressUpdateParams(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: fields, debugDescription: "Unknown ReadingProgressUpdateParams tag")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .text(let value): try value.encode(to: encoder)
        case .manga(let value): try value.encode(to: encoder)
        }
    }
}

public struct ReaderM1ErrorEvent: Codable, Sendable {
    public let deliveryId: Int64?
    public let protocolVersion: Int64
    public let requestId: Int64
    public let type: String
    public let error: ReaderM1Error

    public init(deliveryId: Int64? = nil, protocolVersion: Int64, requestId: Int64, type: String, error: ReaderM1Error) {
        self.deliveryId = deliveryId
        self.protocolVersion = protocolVersion
        self.requestId = requestId
        self.type = type
        self.error = error
    }
}

public struct ReaderM1Error: Codable, Sendable {
    public let code: ReaderErrorCode
    public let message: String
    public let retryable: Bool
    public let details: ReaderM1ErrorDetails?

    public init(code: ReaderErrorCode, message: String, retryable: Bool, details: ReaderM1ErrorDetails? = nil) {
        self.code = code
        self.message = message
        self.retryable = retryable
        self.details = details
    }
}

public struct ReaderM1ErrorDetails: Codable, Sendable {
    public let reason: String?
    public let host: ReaderM1HostErrorDetails?

    public init(reason: String? = nil, host: ReaderM1HostErrorDetails? = nil) {
        self.reason = reason
        self.host = host
    }
}

public struct ReaderM1HostErrorDetails: Codable, Sendable {
    public let capability: ReaderHostCapability
    public let operationId: Int64?
    public let requestId: Int64?
    public let diagnostics: HostErrorDiagnostics?

    public init(capability: ReaderHostCapability, operationId: Int64? = nil, requestId: Int64? = nil, diagnostics: HostErrorDiagnostics? = nil) {
        self.capability = capability
        self.operationId = operationId
        self.requestId = requestId
        self.diagnostics = diagnostics
    }
}

public enum ReaderM2 {
    public static let runtimeHostSmokeHttpExecute = ReaderRPC<M2HttpExecuteSmokeParams, M2HostHttpResponse>(method: .runtimeHostSmoke)
    public static let hostCompleteHttpExecute = ReaderRPC<M2HttpExecuteCompleteParams, M2EmptyParams>(method: .hostComplete)
    public static let runtimeHostSmokeCookieGet = ReaderRPC<M2CookieGetSmokeParams, M2HostCookieGetResponse>(method: .runtimeHostSmoke)
    public static let hostCompleteCookieGet = ReaderRPC<M2CookieGetCompleteParams, M2EmptyParams>(method: .hostComplete)
    public static let runtimeHostSmokeCookieSet = ReaderRPC<M2CookieSetSmokeParams, M2HostCookieSetResponse>(method: .runtimeHostSmoke)
    public static let hostCompleteCookieSet = ReaderRPC<M2CookieSetCompleteParams, M2EmptyParams>(method: .hostComplete)
    public static let runtimeHostSmokeWebViewEvaluateJavaScript = ReaderRPC<M2WebViewEvaluateJavaScriptSmokeParams, M2HostWebViewEvaluateJavaScriptResponse>(method: .runtimeHostSmoke)
    public static let hostCompleteWebViewEvaluateJavaScript = ReaderRPC<M2WebViewEvaluateJavaScriptCompleteParams, M2EmptyParams>(method: .hostComplete)
    public static let runtimeHostSmokeMediaDownload = ReaderRPC<M2MediaDownloadSmokeParams, M2HostMediaDownloadResponse>(method: .runtimeHostSmoke)
    public static let hostCompleteMediaDownload = ReaderRPC<M2MediaDownloadCompleteParams, M2EmptyParams>(method: .hostComplete)
    public static let hostError = ReaderRPC<M2HostErrorParams, M2EmptyParams>(method: .hostError)
    public static let runtimeCancel = ReaderRPC<M2RuntimeCancelParams, M2RuntimeCancelData>(method: .runtimeCancel)
    public static let runtimeSetHostCapabilities = ReaderRPC<M2RuntimeSetHostCapabilitiesParams, M2RuntimeSetHostCapabilitiesData>(method: .runtimeSetHostCapabilities)
    public static let sourceImport = ReaderRPC<M2SourceImportParams, M2SourceImportData>(method: .sourceImport)
    public static let bookToc = ReaderRPC<M2BookTocParams, M2BookTocData>(method: .bookToc)
    public static let cacheBookPrefetch = ReaderRPC<M2CacheBookPrefetchParams, M2CacheBookPrefetchData>(method: .cacheBookPrefetch)
    public static let cacheDownloadOperationQuery = ReaderRPC<M2CacheDownloadOperationQueryParams, M2DownloadOperationQueryData>(method: .cacheDownloadOperationQuery)
    public static let cacheDownloadOperationSettle = ReaderRPC<M2CacheDownloadOperationSettleParams, M2DownloadOperationReceipt>(method: .cacheDownloadOperationSettle)
    public static let sourceList = ReaderRPC<M2SourceListParams, M2SourceListData>(method: .sourceList)
    public static let sourceUpdate = ReaderRPC<M2SourceUpdateParams, M2SourceUpdateData>(method: .sourceUpdate)
    public static let sourceDelete = ReaderRPC<M2SourceDeleteParams, M2SourceDeleteData>(method: .sourceDelete)
    public static let sourceCheck = ReaderRPC<M2SourceCheckParams, M2SourceCheckResultData>(method: .sourceCheck)
    public static let sourceCheckRun = ReaderRPC<M2SourceCheckRunParams, M2SourceCheckResultData>(method: .sourceCheckRun)
    public static let sourceCheckEphemeralRun = ReaderRPC<M2SourceCheckEphemeralRunParams, M2SourceCheckResultData>(method: .sourceCheckEphemeralRun)
    public static let sourceCheckReportClear = ReaderRPC<M2SourceCheckReportClearParams, M2SourceCheckReportClearData>(method: .sourceCheckReportClear)
    public static let sourceGroupCatalog = ReaderRPC<M2SourceGroupCatalogParams, M2SourceGroupCatalogData>(method: .sourceGroupCatalog)
    public static let ruleSubUpdatePreviewV1 = ReaderRPC<M2RuleSubUpdatePreviewParams, M2RuleSubUpdatePreviewData>(method: .ruleSubUpdatePreviewV1)
    public static let bookDetail = ReaderRPC<M2BookDetailParams, M2BookDetailData>(method: .bookDetail)
    public static let chapterContent = ReaderRPC<M2ChapterContentParams, M2ChapterContentData>(method: .chapterContent)
    public static let changeBookSource = ReaderRPC<M2ChangeBookSourceParams, M2ChangeBookSourceData>(method: .changeBookSource)
    public static let sourceSwitchCommit = ReaderRPC<M2SourceSwitchCommitParams, M2SourceSwitchCommitData>(method: .sourceSwitchCommit)
    public static let sourceSwitchPendingList = ReaderRPC<M2EmptyParams, M2SourceSwitchPendingListData>(method: .sourceSwitchPendingList)
    public static let sourceSwitchTransactionQuery = ReaderRPC<M2SourceSwitchTransactionQueryParams, M2SourceSwitchTransactionQueryData>(method: .sourceSwitchTransactionQuery)
    public static let sourceSwitchFinalize = ReaderRPC<M2SourceSwitchTransactionParams, M2SourceSwitchFinalizeData>(method: .sourceSwitchFinalize)
    public static let sourceSwitchRecover = ReaderRPC<M2EmptyParams, M2SourceSwitchRecoverData>(method: .sourceSwitchRecover)
    public static let sourceSwitchRollback = ReaderRPC<M2SourceSwitchTransactionParams, M2SourceSwitchRollbackData>(method: .sourceSwitchRollback)
    public static let cacheBookStatus = ReaderRPC<M2CacheBookStatusParams, M2CacheBookStatusData>(method: .cacheBookStatus)
    public static let cacheDownloadPause = ReaderRPC<M2CacheDownloadTaskParams, M2CacheDownloadTaskResult>(method: .cacheDownloadPause)
    public static let cacheDownloadResume = ReaderRPC<M2CacheDownloadTaskParams, M2CacheDownloadTaskResult>(method: .cacheDownloadResume)
    public static let cacheDownloadCancel = ReaderRPC<M2CacheDownloadTaskParams, M2CacheDownloadTaskResult>(method: .cacheDownloadCancel)
    public static let cacheChapterMaterializationReport = ReaderRPC<M2CacheChapterMaterializationReportParams, M2CacheChapterMaterializationReportData>(method: .cacheChapterMaterializationReport)
    public static let cacheStorageSummary = ReaderRPC<M2CacheStorageParams, M2CacheStorageData>(method: .cacheStorageSummary)
    public static let cacheStorageCleanup = ReaderRPC<M2CacheStorageParams, M2CacheStorageData>(method: .cacheStorageCleanup)
    public static let readingDirectoryViewOpenV2 = ReaderRPC<M2DirectoryViewOpenParamsV2, M2DirectoryViewOpenDataV2>(method: .readingDirectoryViewOpenV2)
    public static let readingDirectoryViewPageV2 = ReaderRPC<M2DirectoryViewPageParamsV2, M2DirectoryViewPageDataV2>(method: .readingDirectoryViewPageV2)
    public static let readingDirectoryTargetResolveV2 = ReaderRPC<M2DirectoryTargetResolveParamsV2, M2DirectoryTargetResolveDataV2>(method: .readingDirectoryTargetResolveV2)
    public static let sourceExport = ReaderRPC<M2SourceExportParams, M2SourceExportData>(method: .sourceExport)
    public static let sourceDebug = ReaderRPC<M2SourceDebugParams, M2SourceDebugData>(method: .sourceDebug)
    public static let ruleSubList = ReaderRPC<M2EmptyParams, M2RuleSubListData>(method: .ruleSubList)
    public static let ruleSubPut = ReaderRPC<M2RuleSubPutParams, M2RuleSubPutData>(method: .ruleSubPut)
    public static let ruleSubGet = ReaderRPC<M2RuleSubKeyParams, M2RuleSubGetData>(method: .ruleSubGet)
    public static let ruleSubDelete = ReaderRPC<M2RuleSubKeyParams, M2RuleSubDeleteData>(method: .ruleSubDelete)
    public static let bookSearch = ReaderRPC<M2BookSearchParams, M2BookSearchData>(method: .bookSearch)
    public static let searchBookPut = ReaderRPC<M2SearchBookPutParams, M2SearchBookPutData>(method: .searchBookPut)
    public static let searchBookGet = ReaderRPC<M2SearchBookKeyParams, M2SearchBookGetData>(method: .searchBookGet)
    public static let searchBookBatchGet = ReaderRPC<M2SearchBookBatchGetParams, M2SearchBookBatchGetData>(method: .searchBookBatchGet)
    public static let searchBookRelated = ReaderRPC<M2SearchBookRelatedParams, M2SearchBookRelatedData>(method: .searchBookRelated)
    public static let searchBookDelete = ReaderRPC<M2SearchBookKeyParams, M2SearchBookDeleteData>(method: .searchBookDelete)
    public static let searchBookList = ReaderRPC<M2SearchBookListParams, M2SearchBookListData>(method: .searchBookList)
    public static let searchHistoryList = ReaderRPC<M2SearchHistoryListParams, M2SearchHistoryListData>(method: .searchHistoryList)
    public static let searchHistoryAdd = ReaderRPC<M2SearchHistoryAddParams, M2SearchHistoryAddData>(method: .searchHistoryAdd)
    public static let searchHistoryClear = ReaderRPC<M2SearchHistoryClearParams, M2SearchHistoryClearData>(method: .searchHistoryClear)
    public static let searchKeywordDelete = ReaderRPC<M2SearchKeywordKeyParams, M2SearchKeywordDeleteData>(method: .searchKeywordDelete)
    public static let readingPreparation = ReaderRPC<M2ReadingPreparationParams, M2ReadingPreparationData>(method: .readingPreparation)
    public static let readingEntryPrepare = ReaderRPC<M2ReadingEntryPrepareParams, M2ReadingEntryPrepareData>(method: .readingEntryPrepare)
    public static let rulesMutationApply = ReaderRPC<M2RulesMutationApplyParams, M2RulesMutationReceipt>(method: .rulesMutationApply)
    public static let rulesMutationQuery = ReaderRPC<M2RulesMutationQueryParams, M2RulesMutationQueryData>(method: .rulesMutationQuery)
    public static let readingEntrySnapshot = ReaderRPC<M2ReadingEntrySnapshotParams, M2ReadingEntrySnapshotData>(method: .readingEntrySnapshot)
    public static let readingCatalogPage = ReaderRPC<M2ReadingCatalogPageParams, M2ReadingCatalogPageData>(method: .readingCatalogPage)
    public static let readingDocumentWindow = ReaderRPC<M2ReadingDocumentWindowParams, M2ReadingDocumentWindowData>(method: .readingDocumentWindow)
    public static let sourceImageRequest = ReaderRPC<M2SourceImageRequestParams, M2SourceImageRequestData>(method: .sourceImageRequest)
    public static let cacheClear = ReaderRPC<M2CacheClearParams, M2CacheClearData>(method: .cacheClear)
    public static let cacheClearOperationQuery = ReaderRPC<M2CacheClearOperationQueryParams, M2CacheClearOperationQueryData>(method: .cacheClearOperationQuery)
    public static let cacheClearOperationSettle = ReaderRPC<M2ReadingOperationBinding, M2CacheClearOperationReceipt>(method: .cacheClearOperationSettle)
}

public struct M2HttpExecuteSmokeParams: Codable, Sendable {
    public let capability: M2HttpExecuteSmokeParamsCapability
    public let params: M2HostHttpRequest

    public init(capability: M2HttpExecuteSmokeParamsCapability = .httpExecute, params: M2HostHttpRequest) {
        self.capability = capability
        self.params = params
    }
}

/// Wire values of M2HttpExecuteSmokeParamsCapability.
public enum M2HttpExecuteSmokeParamsCapability: String, Codable, Sendable, CaseIterable {
    case httpExecute = "http.execute"
}

public struct M2HostHttpRequest: Codable, Sendable {
    public let timeoutMs: Int64?
    public let url: String
    public let method: String?
    public let headers: [String: ReaderM1JSONValue]?
    public let body: String?
    public let charset: String?
    public let followRedirects: Bool?
    public let maxRedirects: Int64?
    public let retry: M2HostHttpRetryPolicy?
    public let usePlatformCookieJar: Bool?
    public let session: M2HostHttpSession?
    public let responseAsset: Bool?
    public let diagnostic: M2HostHttpDiagnostic?

    public init(timeoutMs: Int64? = nil, url: String, method: String? = nil, headers: [String: ReaderM1JSONValue]? = nil, body: String? = nil, charset: String? = nil, followRedirects: Bool? = nil, maxRedirects: Int64? = nil, retry: M2HostHttpRetryPolicy? = nil, usePlatformCookieJar: Bool? = nil, session: M2HostHttpSession? = nil, responseAsset: Bool? = nil, diagnostic: M2HostHttpDiagnostic? = nil) {
        self.timeoutMs = timeoutMs
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.charset = charset
        self.followRedirects = followRedirects
        self.maxRedirects = maxRedirects
        self.retry = retry
        self.usePlatformCookieJar = usePlatformCookieJar
        self.session = session
        self.responseAsset = responseAsset
        self.diagnostic = diagnostic
    }
}

public struct M2HostHttpRetryPolicy: Codable, Sendable {
    public let maxAttempts: Int64
    public let backoffMillis: Int64?

    public init(maxAttempts: Int64, backoffMillis: Int64? = nil) {
        self.maxAttempts = maxAttempts
        self.backoffMillis = backoffMillis
    }
}

public struct M2HostHttpSession: Codable, Sendable {
    public let id: String

    public init(id: String) {
        self.id = id
    }
}

public struct M2HostHttpDiagnostic: Codable, Sendable {
    public let traceId: String
    public let requestId: Int64
    public let sourceId: String
    public let stage: M2HostHttpDiagnosticStage

    public init(traceId: String, requestId: Int64, sourceId: String, stage: M2HostHttpDiagnosticStage) {
        self.traceId = traceId
        self.requestId = requestId
        self.sourceId = sourceId
        self.stage = stage
    }
}

/// Wire values of M2HostHttpDiagnosticStage.
public enum M2HostHttpDiagnosticStage: String, Codable, Sendable, CaseIterable {
    case l2 = "L2"
    case l3 = "L3"
    case l4 = "L4"
    case l5 = "L5"
}

public struct M2HostHttpResponse: Codable, Sendable {
    public let body: String
    public let status: Int64?
    public let headers: [String: ReaderM1JSONValue]?
    public let finalUrl: String?
    public let charsetHint: String?
    public let bodyBase64: String?
    public let bodyAsset: M2HostHttpResponseBodyAsset?
    public let session: M2HostHttpSession?
    public let redirects: [M2HostHttpRedirect]?
    public let cookies: [M2HostHttpCookie]?

    public init(body: String, status: Int64? = nil, headers: [String: ReaderM1JSONValue]? = nil, finalUrl: String? = nil, charsetHint: String? = nil, bodyBase64: String? = nil, bodyAsset: M2HostHttpResponseBodyAsset? = nil, session: M2HostHttpSession? = nil, redirects: [M2HostHttpRedirect]? = nil, cookies: [M2HostHttpCookie]? = nil) {
        self.body = body
        self.status = status
        self.headers = headers
        self.finalUrl = finalUrl
        self.charsetHint = charsetHint
        self.bodyBase64 = bodyBase64
        self.bodyAsset = bodyAsset
        self.session = session
        self.redirects = redirects
        self.cookies = cookies
    }
}

public struct M2HostHttpResponseBodyAsset: Codable, Sendable {
    public let assetId: Int64
    public let operationId: Int64
    public let bytes: Int64
    public let contentType: String?

    public init(assetId: Int64, operationId: Int64, bytes: Int64, contentType: String? = nil) {
        self.assetId = assetId
        self.operationId = operationId
        self.bytes = bytes
        self.contentType = contentType
    }
}

public struct M2HostHttpRedirect: Codable, Sendable {
    public let status: Int64
    public let fromUrl: String
    public let toUrl: String
    public let headers: [String: ReaderM1JSONValue]?

    public init(status: Int64, fromUrl: String, toUrl: String, headers: [String: ReaderM1JSONValue]? = nil) {
        self.status = status
        self.fromUrl = fromUrl
        self.toUrl = toUrl
        self.headers = headers
    }
}

public struct M2HostHttpCookie: Codable, Sendable {
    public let name: String
    public let value: String?
    public let domain: String?
    public let path: String?
    public let expiresAt: String?
    public let httpOnly: Bool?
    public let secure: Bool?
    public let sameSite: String?

    public init(name: String, value: String? = nil, domain: String? = nil, path: String? = nil, expiresAt: String? = nil, httpOnly: Bool? = nil, secure: Bool? = nil, sameSite: String? = nil) {
        self.name = name
        self.value = value
        self.domain = domain
        self.path = path
        self.expiresAt = expiresAt
        self.httpOnly = httpOnly
        self.secure = secure
        self.sameSite = sameSite
    }
}

public struct M2HttpExecuteCompleteParams: Codable, Sendable {
    public let operationId: Int64
    public let result: M2HostHttpResponse

    public init(operationId: Int64, result: M2HostHttpResponse) {
        self.operationId = operationId
        self.result = result
    }
}

public struct M2EmptyParams: Codable, Sendable {
    public init() {
    }
}

public struct M2CookieGetSmokeParams: Codable, Sendable {
    public let capability: M2CookieGetSmokeParamsCapability
    public let params: M2HostCookieGetRequest

    public init(capability: M2CookieGetSmokeParamsCapability = .cookieGet, params: M2HostCookieGetRequest) {
        self.capability = capability
        self.params = params
    }
}

/// Wire values of M2CookieGetSmokeParamsCapability.
public enum M2CookieGetSmokeParamsCapability: String, Codable, Sendable, CaseIterable {
    case cookieGet = "cookie.get"
}

public struct M2HostCookieGetRequest: Codable, Sendable {
    public let url: String?
    public let domain: String?
    public let name: String?
    public let sessionId: String?

    public init(url: String? = nil, domain: String? = nil, name: String? = nil, sessionId: String? = nil) {
        self.url = url
        self.domain = domain
        self.name = name
        self.sessionId = sessionId
    }
}

public struct M2HostCookieGetResponse: Codable, Sendable {
    public let cookies: [M2HostCookieRecord]

    public init(cookies: [M2HostCookieRecord]) {
        self.cookies = cookies
    }
}

public struct M2HostCookieRecord: Codable, Sendable {
    public let name: String
    public let value: String?
    public let domain: String?
    public let path: String?
    public let expiresAt: String?
    public let httpOnly: Bool?
    public let secure: Bool?
    public let sameSite: String?

    public init(name: String, value: String? = nil, domain: String? = nil, path: String? = nil, expiresAt: String? = nil, httpOnly: Bool? = nil, secure: Bool? = nil, sameSite: String? = nil) {
        self.name = name
        self.value = value
        self.domain = domain
        self.path = path
        self.expiresAt = expiresAt
        self.httpOnly = httpOnly
        self.secure = secure
        self.sameSite = sameSite
    }
}

public struct M2CookieGetCompleteParams: Codable, Sendable {
    public let operationId: Int64
    public let result: M2HostCookieGetResponse

    public init(operationId: Int64, result: M2HostCookieGetResponse) {
        self.operationId = operationId
        self.result = result
    }
}

public struct M2CookieSetSmokeParams: Codable, Sendable {
    public let capability: M2CookieSetSmokeParamsCapability
    public let params: M2HostCookieSetRequest

    public init(capability: M2CookieSetSmokeParamsCapability = .cookieSet, params: M2HostCookieSetRequest) {
        self.capability = capability
        self.params = params
    }
}

/// Wire values of M2CookieSetSmokeParamsCapability.
public enum M2CookieSetSmokeParamsCapability: String, Codable, Sendable, CaseIterable {
    case cookieSet = "cookie.set"
}

public struct M2HostCookieSetRequest: Codable, Sendable {
    public let cookie: M2HostCookieRecord
    public let url: String?
    public let sessionId: String?

    public init(cookie: M2HostCookieRecord, url: String? = nil, sessionId: String? = nil) {
        self.cookie = cookie
        self.url = url
        self.sessionId = sessionId
    }
}

public struct M2HostCookieSetResponse: Codable, Sendable {
    public let stored: Bool

    public init(stored: Bool) {
        self.stored = stored
    }
}

public struct M2CookieSetCompleteParams: Codable, Sendable {
    public let operationId: Int64
    public let result: M2HostCookieSetResponse

    public init(operationId: Int64, result: M2HostCookieSetResponse) {
        self.operationId = operationId
        self.result = result
    }
}

public struct M2WebViewEvaluateJavaScriptSmokeParams: Codable, Sendable {
    public let capability: M2WebViewEvaluateJavaScriptSmokeParamsCapability
    public let params: M2HostWebViewEvaluateJavaScriptRequest

    public init(capability: M2WebViewEvaluateJavaScriptSmokeParamsCapability = .webviewEvaluateJavaScript, params: M2HostWebViewEvaluateJavaScriptRequest) {
        self.capability = capability
        self.params = params
    }
}

/// Wire values of M2WebViewEvaluateJavaScriptSmokeParamsCapability.
public enum M2WebViewEvaluateJavaScriptSmokeParamsCapability: String, Codable, Sendable, CaseIterable {
    case webviewEvaluateJavaScript = "webview.evaluateJavaScript"
}

public struct M2HostWebViewEvaluateJavaScriptRequest: Codable, Sendable {
    public let resourceUrlMatcherJavaScript: String?
    public let document: M2HostWebViewDocument
    public let javaScript: String
    public let headers: [String: ReaderM1JSONValue]?
    public let settleDelayMillis: Int64?
    public let timeoutMillis: Int64?
    public let profileId: String?

    public init(resourceUrlMatcherJavaScript: String? = nil, document: M2HostWebViewDocument, javaScript: String, headers: [String: ReaderM1JSONValue]? = nil, settleDelayMillis: Int64? = nil, timeoutMillis: Int64? = nil, profileId: String? = nil) {
        self.resourceUrlMatcherJavaScript = resourceUrlMatcherJavaScript
        self.document = document
        self.javaScript = javaScript
        self.headers = headers
        self.settleDelayMillis = settleDelayMillis
        self.timeoutMillis = timeoutMillis
        self.profileId = profileId
    }
}

public enum M2HostWebViewDocument: Codable, Sendable {
    case html(M2HostWebViewDocumentHtml)
    case url(M2HostWebViewDocumentUrl)

    private enum CodingKeys: String, CodingKey { case kind }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        let tag = fields.contains(.kind) ? try fields.decode(String.self, forKey: .kind) : nil
        switch tag {
        case "html": self = .html(try M2HostWebViewDocumentHtml(from: decoder))
        case "url": self = .url(try M2HostWebViewDocumentUrl(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: fields, debugDescription: "Unknown M2HostWebViewDocument tag")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .html(let value): try value.encode(to: encoder)
        case .url(let value): try value.encode(to: encoder)
        }
    }
}

public struct M2HostWebViewDocumentHtml: Codable, Sendable {
    public let kind: M2HostWebViewDocumentHtmlKind
    public let body: String
    public let baseUrl: String?

    public init(kind: M2HostWebViewDocumentHtmlKind = .html, body: String, baseUrl: String? = nil) {
        self.kind = kind
        self.body = body
        self.baseUrl = baseUrl
    }
}

/// Wire values of M2HostWebViewDocumentHtmlKind.
public enum M2HostWebViewDocumentHtmlKind: String, Codable, Sendable, CaseIterable {
    case html = "html"
}

public struct M2HostWebViewDocumentUrl: Codable, Sendable {
    public let kind: M2HostWebViewDocumentUrlKind
    public let url: String

    public init(kind: M2HostWebViewDocumentUrlKind = .url, url: String) {
        self.kind = kind
        self.url = url
    }
}

/// Wire values of M2HostWebViewDocumentUrlKind.
public enum M2HostWebViewDocumentUrlKind: String, Codable, Sendable, CaseIterable {
    case url = "url"
}

public struct M2HostWebViewEvaluateJavaScriptResponse: Codable, Sendable {
    public let resourceUrl: String?
    public let value: ReaderM1JSONValue
    public let finalUrl: String?
    public let title: String?

    public init(resourceUrl: String? = nil, value: ReaderM1JSONValue, finalUrl: String? = nil, title: String? = nil) {
        self.resourceUrl = resourceUrl
        self.value = value
        self.finalUrl = finalUrl
        self.title = title
    }
}

public struct M2WebViewEvaluateJavaScriptCompleteParams: Codable, Sendable {
    public let operationId: Int64
    public let result: M2HostWebViewEvaluateJavaScriptResponse

    public init(operationId: Int64, result: M2HostWebViewEvaluateJavaScriptResponse) {
        self.operationId = operationId
        self.result = result
    }
}

public struct M2MediaDownloadSmokeParams: Codable, Sendable {
    public let capability: M2MediaDownloadSmokeParamsCapability
    public let params: M2HostMediaDownloadRequest

    public init(capability: M2MediaDownloadSmokeParamsCapability = .mediaDownload, params: M2HostMediaDownloadRequest) {
        self.capability = capability
        self.params = params
    }
}

/// Wire values of M2MediaDownloadSmokeParamsCapability.
public enum M2MediaDownloadSmokeParamsCapability: String, Codable, Sendable, CaseIterable {
    case mediaDownload = "media.download"
}

public struct M2HostMediaDownloadRequest: Codable, Sendable {
    public let url: String
    public let method: M2HostMediaDownloadRequestMethod?
    public let headers: [String: String]?
    public let rangeStart: Int64?
    public let rangeEnd: Int64?
    public let ifNoneMatch: String?
    public let ifModifiedSince: String?
    public let cacheKey: String?
    public let savePath: String?
    public let maxBytes: Int64?
    public let sessionId: String?
    public let timeoutMillis: Int64?

    public init(url: String, method: M2HostMediaDownloadRequestMethod? = nil, headers: [String: String]? = nil, rangeStart: Int64? = nil, rangeEnd: Int64? = nil, ifNoneMatch: String? = nil, ifModifiedSince: String? = nil, cacheKey: String? = nil, savePath: String? = nil, maxBytes: Int64? = nil, sessionId: String? = nil, timeoutMillis: Int64? = nil) {
        self.url = url
        self.method = method
        self.headers = headers
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
        self.ifNoneMatch = ifNoneMatch
        self.ifModifiedSince = ifModifiedSince
        self.cacheKey = cacheKey
        self.savePath = savePath
        self.maxBytes = maxBytes
        self.sessionId = sessionId
        self.timeoutMillis = timeoutMillis
    }
}

/// Wire values of M2HostMediaDownloadRequestMethod.
public enum M2HostMediaDownloadRequestMethod: String, Codable, Sendable, CaseIterable {
    case get = "GET"
    case head = "HEAD"
}

public struct M2HostMediaDownloadResponse: Codable, Sendable {
    public let resourceId: String
    public let tempPath: String?
    public let statusCode: Int64
    public let contentType: String?
    public let contentLength: Int64?
    public let etag: String?
    public let byteLength: Int64
    public let sha256: String?
    public let fromCache: Bool?
    public let finalUrl: String?

    public init(resourceId: String, tempPath: String? = nil, statusCode: Int64, contentType: String? = nil, contentLength: Int64? = nil, etag: String? = nil, byteLength: Int64, sha256: String? = nil, fromCache: Bool? = nil, finalUrl: String? = nil) {
        self.resourceId = resourceId
        self.tempPath = tempPath
        self.statusCode = statusCode
        self.contentType = contentType
        self.contentLength = contentLength
        self.etag = etag
        self.byteLength = byteLength
        self.sha256 = sha256
        self.fromCache = fromCache
        self.finalUrl = finalUrl
    }
}

public struct M2MediaDownloadCompleteParams: Codable, Sendable {
    public let operationId: Int64
    public let result: M2HostMediaDownloadResponse

    public init(operationId: Int64, result: M2HostMediaDownloadResponse) {
        self.operationId = operationId
        self.result = result
    }
}

public struct M2HostErrorParams: Codable, Sendable {
    public let operationId: Int64
    public let error: ReaderCoreError
    public let diagnostics: M2HostErrorDiagnostics?

    public init(operationId: Int64, error: ReaderCoreError, diagnostics: M2HostErrorDiagnostics? = nil) {
        self.operationId = operationId
        self.error = error
        self.diagnostics = diagnostics
    }
}

public struct M2HostErrorDiagnostics: Codable, Sendable {
    public let code: M2HostErrorCode
    public let phase: M2HostErrorPhase
    public let message: String?
    public let details: [String: ReaderM1JSONValue]?

    public init(code: M2HostErrorCode, phase: M2HostErrorPhase, message: String? = nil, details: [String: ReaderM1JSONValue]? = nil) {
        self.code = code
        self.phase = phase
        self.message = message
        self.details = details
    }
}

/// Wire values of M2HostErrorCode.
public enum M2HostErrorCode: String, Codable, Sendable, CaseIterable {
    case capabilityUnavailable = "CAPABILITY_UNAVAILABLE"
    case permissionDenied = "PERMISSION_DENIED"
    case timeout = "TIMEOUT"
    case networkError = "NETWORK_ERROR"
    case tlsError = "TLS_ERROR"
    case httpError = "HTTP_ERROR"
    case invalidResponse = "INVALID_RESPONSE"
    case cancelled = "CANCELLED"
    case challengeRequired = "CHALLENGE_REQUIRED"
    case `internal` = "INTERNAL"
}

/// Wire values of M2HostErrorPhase.
public enum M2HostErrorPhase: String, Codable, Sendable, CaseIterable {
    case request = "request"
    case transport = "transport"
    case response = "response"
    case decode = "decode"
    case storage = "storage"
    case runtime = "runtime"
}

public struct M2RuntimeCancelParams: Codable, Sendable {
    public let requestId: Int64

    public init(requestId: Int64) {
        self.requestId = requestId
    }
}

public struct M2RuntimeCancelData: Codable, Sendable {
    public let cancelled: Bool

    public init(cancelled: Bool) {
        self.cancelled = cancelled
    }
}

public struct M2RuntimeSetHostCapabilitiesParams: Codable, Sendable {
    public let extensions: [String]?
    public let capabilities: [ReaderHostCapability]
    public let lanes: [M2HostLane]?
    public let platform: String?
    public let platformVersion: String?

    public init(extensions: [String]? = nil, capabilities: [ReaderHostCapability], lanes: [M2HostLane]? = nil, platform: String? = nil, platformVersion: String? = nil) {
        self.extensions = extensions
        self.capabilities = capabilities
        self.lanes = lanes
        self.platform = platform
        self.platformVersion = platformVersion
    }
}

/// Wire values of M2HostLane.
public enum M2HostLane: String, Codable, Sendable, CaseIterable {
    case antiBot = "anti_bot"
    case loginCookie = "login_cookie"
    case webviewRender = "webview_render"
    case mediaDownload = "media_download"
}

public struct M2RuntimeSetHostCapabilitiesData: Codable, Sendable {
    public let applied: Bool
    public let capabilities: Int64
    public let lanes: Int64

    public init(applied: Bool, capabilities: Int64, lanes: Int64) {
        self.applied = applied
        self.capabilities = capabilities
        self.lanes = lanes
    }
}

public struct M2SourceImportParams: Codable, Sendable {
    public let sourceId: String?
    public let name: String?
    public let baseUrl: String?
    public let rules: [String: ReaderM1JSONValue]?
    public let bookSource: [String: ReaderM1JSONValue]?
    public let useSourceReplacement: Bool?
    public let expectedVersion: String?

    public init(sourceId: String? = nil, name: String? = nil, baseUrl: String? = nil, rules: [String: ReaderM1JSONValue]? = nil, bookSource: [String: ReaderM1JSONValue]? = nil, useSourceReplacement: Bool? = nil, expectedVersion: String? = nil) {
        self.sourceId = sourceId
        self.name = name
        self.baseUrl = baseUrl
        self.rules = rules
        self.bookSource = bookSource
        self.useSourceReplacement = useSourceReplacement
        self.expectedVersion = expectedVersion
    }
}

public struct M2SourceImportData: Codable, Sendable {
    public let sourceId: String
    public let name: String
    public let imported: Bool

    public init(sourceId: String, name: String, imported: Bool) {
        self.sourceId = sourceId
        self.name = name
        self.imported = imported
    }
}

public struct M2BookTocParams: Codable, Sendable {
    public let preparationRevision: Int64?
    public let sourceId: String
    public let bookId: String
    public let tocResponse: String?
    public let tocRequest: M2HostHttpRequest?
    public let source: [String: ReaderM1JSONValue]?
    public let tocUrl: String?
    public let variables: [String: String]?

    public init(preparationRevision: Int64? = nil, sourceId: String, bookId: String, tocResponse: String? = nil, tocRequest: M2HostHttpRequest? = nil, source: [String: ReaderM1JSONValue]? = nil, tocUrl: String? = nil, variables: [String: String]? = nil) {
        self.preparationRevision = preparationRevision
        self.sourceId = sourceId
        self.bookId = bookId
        self.tocResponse = tocResponse
        self.tocRequest = tocRequest
        self.source = source
        self.tocUrl = tocUrl
        self.variables = variables
    }
}

public struct M2BookTocData: Codable, Sendable {
    public let sourceVersion: String?
    public let catalogAt: Int64?
    public let catalogVersion: String?
    public let contextVersion: String?
    public let continuationVariables: [String: String]?
    public let catalogInstalled: Bool?
    public let sourceId: String
    public let bookId: String
    public let toc: [M2BookTocEntryData]
    public let http: M2RemoteHttpDiagnosticsData?
    public let readableChapterIndexes: [Int64]?
    public let directoryProofState: M2BookTocDataDirectoryProofState?
    public let catalogDeferredReason: M2BookTocDataCatalogDeferredReason?

    public init(sourceVersion: String? = nil, catalogAt: Int64? = nil, catalogVersion: String? = nil, contextVersion: String? = nil, continuationVariables: [String: String]? = nil, catalogInstalled: Bool? = nil, sourceId: String, bookId: String, toc: [M2BookTocEntryData], http: M2RemoteHttpDiagnosticsData? = nil, readableChapterIndexes: [Int64]? = nil, directoryProofState: M2BookTocDataDirectoryProofState? = nil, catalogDeferredReason: M2BookTocDataCatalogDeferredReason? = nil) {
        self.sourceVersion = sourceVersion
        self.catalogAt = catalogAt
        self.catalogVersion = catalogVersion
        self.contextVersion = contextVersion
        self.continuationVariables = continuationVariables
        self.catalogInstalled = catalogInstalled
        self.sourceId = sourceId
        self.bookId = bookId
        self.toc = toc
        self.http = http
        self.readableChapterIndexes = readableChapterIndexes
        self.directoryProofState = directoryProofState
        self.catalogDeferredReason = catalogDeferredReason
    }
}

public struct M2BookTocEntryData: Codable, Sendable {
    public let displayTitle: String?
    public let contextTitle: String?
    public let isVip: Bool?
    public let isPay: Bool?
    public let index: Int64
    public let title: String
    public let url: String
    public let level: Int64?
    public let variables: [String: String]?

    public init(displayTitle: String? = nil, contextTitle: String? = nil, isVip: Bool? = nil, isPay: Bool? = nil, index: Int64, title: String, url: String, level: Int64? = nil, variables: [String: String]? = nil) {
        self.displayTitle = displayTitle
        self.contextTitle = contextTitle
        self.isVip = isVip
        self.isPay = isPay
        self.index = index
        self.title = title
        self.url = url
        self.level = level
        self.variables = variables
    }
}

public struct M2RemoteHttpDiagnosticsData: Codable, Sendable {
    public let responseBytes: Int64?
    public let firstResponseBytes: Int64?
    public let responseDigest: String?
    public let firstResponseDigest: String?
    public let finalUrlDigest: String?
    public let status: Int64?
    public let headers: [String: ReaderM1JSONValue]?
    public let finalUrl: String?
    public let charsetHint: String?
    public let session: M2HostHttpSession?
    public let redirects: [M2HostHttpRedirect]?
    public let cookies: [M2HostHttpCookie]?

    public init(responseBytes: Int64? = nil, firstResponseBytes: Int64? = nil, responseDigest: String? = nil, firstResponseDigest: String? = nil, finalUrlDigest: String? = nil, status: Int64? = nil, headers: [String: ReaderM1JSONValue]? = nil, finalUrl: String? = nil, charsetHint: String? = nil, session: M2HostHttpSession? = nil, redirects: [M2HostHttpRedirect]? = nil, cookies: [M2HostHttpCookie]? = nil) {
        self.responseBytes = responseBytes
        self.firstResponseBytes = firstResponseBytes
        self.responseDigest = responseDigest
        self.firstResponseDigest = firstResponseDigest
        self.finalUrlDigest = finalUrlDigest
        self.status = status
        self.headers = headers
        self.finalUrl = finalUrl
        self.charsetHint = charsetHint
        self.session = session
        self.redirects = redirects
        self.cookies = cookies
    }
}

/// Wire values of M2BookTocDataDirectoryProofState.
public enum M2BookTocDataDirectoryProofState: String, Codable, Sendable, CaseIterable {
    case verified = "verified"
    case legacyUnknown = "legacyUnknown"
    case invalid = "invalid"
}

/// Wire values of M2BookTocDataCatalogDeferredReason.
public enum M2BookTocDataCatalogDeferredReason: String, Codable, Sendable, CaseIterable {
    case sourceSwitchPending = "sourceSwitchPending"
}

public struct M2CacheBookPrefetchParams: Codable, Sendable {
    public let preparationRevision: Int64?
    public let sourceId: String
    public let bookId: String
    public let chapterRange: [Int64]
    public let priority: Int64?
    public let requestedAt: Int64?
    public let contentKind: M2CacheBookPrefetchParamsContentKind?
    public let operationId: String?
    public let sequence: Int64?

    public init(preparationRevision: Int64? = nil, sourceId: String, bookId: String, chapterRange: [Int64], priority: Int64? = nil, requestedAt: Int64? = nil, contentKind: M2CacheBookPrefetchParamsContentKind? = nil, operationId: String? = nil, sequence: Int64? = nil) {
        self.preparationRevision = preparationRevision
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterRange = chapterRange
        self.priority = priority
        self.requestedAt = requestedAt
        self.contentKind = contentKind
        self.operationId = operationId
        self.sequence = sequence
    }
}

/// Wire values of M2CacheBookPrefetchParamsContentKind.
public enum M2CacheBookPrefetchParamsContentKind: String, Codable, Sendable, CaseIterable {
    case text = "text"
    case manga = "manga"
}

public struct M2CacheBookPrefetchData: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterRange: [Int64]
    public let chapterCount: Int64
    public let prefetchedCount: Int64
    public let queuedIndexes: [Int64]
    public let alreadyQueuedIndexes: [Int64]
    public let skippedCachedIndexes: [Int64]
    public let materializations: [M2CacheChapterMaterializationData]

    public init(sourceId: String, bookId: String, chapterRange: [Int64], chapterCount: Int64, prefetchedCount: Int64, queuedIndexes: [Int64], alreadyQueuedIndexes: [Int64], skippedCachedIndexes: [Int64], materializations: [M2CacheChapterMaterializationData]) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterRange = chapterRange
        self.chapterCount = chapterCount
        self.prefetchedCount = prefetchedCount
        self.queuedIndexes = queuedIndexes
        self.alreadyQueuedIndexes = alreadyQueuedIndexes
        self.skippedCachedIndexes = skippedCachedIndexes
        self.materializations = materializations
    }
}

public struct M2CacheChapterMaterializationData: Codable, Sendable {
    public let chapterIndex: Int64
    public let token: String
    public let manga: M2MangaChapterData?

    public init(chapterIndex: Int64, token: String, manga: M2MangaChapterData? = nil) {
        self.chapterIndex = chapterIndex
        self.token = token
        self.manga = manga
    }
}

public struct M2MangaChapterData: Codable, Sendable {
    public let manifest: M2MangaManifest
    public let chapterIndex: Int64
    public let chapterTitle: String
    public let cached: Bool
    public let resources: [M2MangaResourceData]
    public let progressMapping: M2MangaProgressMapping?
    public let anchorMapping: M2MangaAnchorMapping?

    public init(manifest: M2MangaManifest, chapterIndex: Int64, chapterTitle: String, cached: Bool, resources: [M2MangaResourceData], progressMapping: M2MangaProgressMapping? = nil, anchorMapping: M2MangaAnchorMapping? = nil) {
        self.manifest = manifest
        self.chapterIndex = chapterIndex
        self.chapterTitle = chapterTitle
        self.cached = cached
        self.resources = resources
        self.progressMapping = progressMapping
        self.anchorMapping = anchorMapping
    }
}

public struct M2MangaManifest: Codable, Sendable {
    public let chapter: M2MangaChapterIdentity
    public let sourceRuleVersion: String
    public let manifestVersion: String
    public let decodeRevision: String
    public let pages: [M2MangaManifestPage]
    public let displayHints: M2MangaDisplayHints?

    public init(chapter: M2MangaChapterIdentity, sourceRuleVersion: String, manifestVersion: String, decodeRevision: String, pages: [M2MangaManifestPage], displayHints: M2MangaDisplayHints? = nil) {
        self.chapter = chapter
        self.sourceRuleVersion = sourceRuleVersion
        self.manifestVersion = manifestVersion
        self.decodeRevision = decodeRevision
        self.pages = pages
        self.displayHints = displayHints
    }
}

public struct M2MangaChapterIdentity: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterId: String

    public init(sourceId: String, bookId: String, chapterId: String) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterId = chapterId
    }
}

public struct M2MangaManifestPage: Codable, Sendable {
    public let pageId: String
    public let ordinal: Int64
    public let resourceRef: String
    public let identity: M2MangaPageIdentity?

    public init(pageId: String, ordinal: Int64, resourceRef: String, identity: M2MangaPageIdentity? = nil) {
        self.pageId = pageId
        self.ordinal = ordinal
        self.resourceRef = resourceRef
        self.identity = identity
    }
}

public struct M2MangaPageIdentity: Codable, Sendable {
    public let kind: M2MangaPageIdentityKind
    public let value: String

    public init(kind: M2MangaPageIdentityKind, value: String) {
        self.kind = kind
        self.value = value
    }
}

/// Wire values of M2MangaPageIdentityKind.
public enum M2MangaPageIdentityKind: String, Codable, Sendable, CaseIterable {
    case sourceId = "sourceId"
    case request = "request"
}

public struct M2MangaDisplayHints: Codable, Sendable {
    public let sourceImageStyle: String
    public let fit: M2MangaDisplayHintsFit?

    public init(sourceImageStyle: String, fit: M2MangaDisplayHintsFit? = nil) {
        self.sourceImageStyle = sourceImageStyle
        self.fit = fit
    }
}

/// Wire values of M2MangaDisplayHintsFit.
public enum M2MangaDisplayHintsFit: String, Codable, Sendable, CaseIterable {
    case width = "width"
    case contain = "contain"
}

public struct M2MangaResourceData: Codable, Sendable {
    public let resourceRef: String
    public let request: M2MangaResourceDataRequest

    public init(resourceRef: String, request: M2MangaResourceDataRequest) {
        self.resourceRef = resourceRef
        self.request = request
    }
}

public struct M2MangaResourceDataRequest: Codable, Sendable {
    public let url: String
    public let requestRule: String?
    public let referrer: String?
    public let headers: [String: String]?
    public let sourcePageId: String?

    public init(url: String, requestRule: String? = nil, referrer: String? = nil, headers: [String: String]? = nil, sourcePageId: String? = nil) {
        self.url = url
        self.requestRule = requestRule
        self.referrer = referrer
        self.headers = headers
        self.sourcePageId = sourcePageId
    }
}

public struct M2MangaProgressMapping: Codable, Sendable {
    public let status: M2MangaProgressMappingStatus
    public let reason: String
    public let fromManifestVersion: String
    public let fromPageId: String
    public let progressRevision: Int64
    public let targetPageId: String?
    public let targetOrdinal: Int64?

    public init(status: M2MangaProgressMappingStatus, reason: String, fromManifestVersion: String, fromPageId: String, progressRevision: Int64, targetPageId: String? = nil, targetOrdinal: Int64? = nil) {
        self.status = status
        self.reason = reason
        self.fromManifestVersion = fromManifestVersion
        self.fromPageId = fromPageId
        self.progressRevision = progressRevision
        self.targetPageId = targetPageId
        self.targetOrdinal = targetOrdinal
    }
}

/// Wire values of M2MangaProgressMappingStatus.
public enum M2MangaProgressMappingStatus: String, Codable, Sendable, CaseIterable {
    case exact = "exact"
    case approximate = "approximate"
    case unresolved = "unresolved"
}

public struct M2MangaAnchorMapping: Codable, Sendable {
    public let status: M2MangaAnchorMappingStatus
    public let reason: String
    public let fromManifestVersion: String
    public let fromPageId: String
    public let targetPageId: String?
    public let targetOrdinal: Int64?

    public init(status: M2MangaAnchorMappingStatus, reason: String, fromManifestVersion: String, fromPageId: String, targetPageId: String? = nil, targetOrdinal: Int64? = nil) {
        self.status = status
        self.reason = reason
        self.fromManifestVersion = fromManifestVersion
        self.fromPageId = fromPageId
        self.targetPageId = targetPageId
        self.targetOrdinal = targetOrdinal
    }
}

/// Wire values of M2MangaAnchorMappingStatus.
public enum M2MangaAnchorMappingStatus: String, Codable, Sendable, CaseIterable {
    case exact = "exact"
    case approximate = "approximate"
    case unresolved = "unresolved"
}

public struct M2CacheDownloadOperationQueryParams: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let operationId: String?
    public let expected: M2DownloadOperationExpected?
    public let action: M2CacheDownloadOperationQueryParamsAction
    public let chapterIndex: Int64?

    public init(sourceId: String, bookId: String, operationId: String? = nil, expected: M2DownloadOperationExpected? = nil, action: M2CacheDownloadOperationQueryParamsAction, chapterIndex: Int64? = nil) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.operationId = operationId
        self.expected = expected
        self.action = action
        self.chapterIndex = chapterIndex
    }
}

public enum M2DownloadOperationExpected: Codable, Sendable {
    case prefetch(M2DownloadOperationExpectedPrefetch)
    case pause(M2DownloadOperationExpectedPause)
    case resume(M2DownloadOperationExpectedResume)
    case cancel(M2DownloadOperationExpectedCancel)
    case report(M2DownloadOperationExpectedReport)

    private enum CodingKeys: String, CodingKey { case action }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        let tag = fields.contains(.action) ? try fields.decode(String.self, forKey: .action) : nil
        switch tag {
        case "prefetch": self = .prefetch(try M2DownloadOperationExpectedPrefetch(from: decoder))
        case "pause": self = .pause(try M2DownloadOperationExpectedPause(from: decoder))
        case "resume": self = .resume(try M2DownloadOperationExpectedResume(from: decoder))
        case "cancel": self = .cancel(try M2DownloadOperationExpectedCancel(from: decoder))
        case "report": self = .report(try M2DownloadOperationExpectedReport(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .action, in: fields, debugDescription: "Unknown M2DownloadOperationExpected tag")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .prefetch(let value): try value.encode(to: encoder)
        case .pause(let value): try value.encode(to: encoder)
        case .resume(let value): try value.encode(to: encoder)
        case .cancel(let value): try value.encode(to: encoder)
        case .report(let value): try value.encode(to: encoder)
        }
    }
}

public struct M2DownloadOperationExpectedPrefetch: Codable, Sendable {
    public let action: M2DownloadOperationExpectedPrefetchAction
    public let params: M2DownloadOperationExpectedPrefetchParams

    public init(action: M2DownloadOperationExpectedPrefetchAction = .prefetch, params: M2DownloadOperationExpectedPrefetchParams) {
        self.action = action
        self.params = params
    }
}

/// Wire values of M2DownloadOperationExpectedPrefetchAction.
public enum M2DownloadOperationExpectedPrefetchAction: String, Codable, Sendable, CaseIterable {
    case prefetch = "prefetch"
}

public struct M2DownloadOperationExpectedPrefetchParams: Codable, Sendable {
    public let preparationRevision: Int64?
    public let sourceId: String
    public let bookId: String
    public let chapterRange: [Int64]
    public let priority: Int64?
    public let requestedAt: Int64?
    public let contentKind: M2DownloadOperationExpectedPrefetchParamsContentKind?
    public let operationId: String
    public let sequence: Int64

    public init(preparationRevision: Int64? = nil, sourceId: String, bookId: String, chapterRange: [Int64], priority: Int64? = nil, requestedAt: Int64? = nil, contentKind: M2DownloadOperationExpectedPrefetchParamsContentKind? = nil, operationId: String, sequence: Int64) {
        self.preparationRevision = preparationRevision
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterRange = chapterRange
        self.priority = priority
        self.requestedAt = requestedAt
        self.contentKind = contentKind
        self.operationId = operationId
        self.sequence = sequence
    }
}

/// Wire values of M2DownloadOperationExpectedPrefetchParamsContentKind.
public enum M2DownloadOperationExpectedPrefetchParamsContentKind: String, Codable, Sendable, CaseIterable {
    case text = "text"
    case manga = "manga"
}

public struct M2DownloadOperationExpectedPause: Codable, Sendable {
    public let action: M2DownloadOperationExpectedPauseAction
    public let params: M2DownloadOperationExpectedPauseParams

    public init(action: M2DownloadOperationExpectedPauseAction = .pause, params: M2DownloadOperationExpectedPauseParams) {
        self.action = action
        self.params = params
    }
}

/// Wire values of M2DownloadOperationExpectedPauseAction.
public enum M2DownloadOperationExpectedPauseAction: String, Codable, Sendable, CaseIterable {
    case pause = "pause"
}

public struct M2DownloadOperationExpectedPauseParams: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: Int64
    public let now: Int64?
    public let operationId: String
    public let sequence: Int64

    public init(sourceId: String, bookId: String, chapterIndex: Int64, now: Int64? = nil, operationId: String, sequence: Int64) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterIndex = chapterIndex
        self.now = now
        self.operationId = operationId
        self.sequence = sequence
    }
}

public struct M2DownloadOperationExpectedResume: Codable, Sendable {
    public let action: M2DownloadOperationExpectedResumeAction
    public let params: M2DownloadOperationExpectedResumeParams

    public init(action: M2DownloadOperationExpectedResumeAction = .resume, params: M2DownloadOperationExpectedResumeParams) {
        self.action = action
        self.params = params
    }
}

/// Wire values of M2DownloadOperationExpectedResumeAction.
public enum M2DownloadOperationExpectedResumeAction: String, Codable, Sendable, CaseIterable {
    case resume = "resume"
}

public struct M2DownloadOperationExpectedResumeParams: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: Int64
    public let now: Int64?
    public let operationId: String
    public let sequence: Int64

    public init(sourceId: String, bookId: String, chapterIndex: Int64, now: Int64? = nil, operationId: String, sequence: Int64) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterIndex = chapterIndex
        self.now = now
        self.operationId = operationId
        self.sequence = sequence
    }
}

public struct M2DownloadOperationExpectedCancel: Codable, Sendable {
    public let action: M2DownloadOperationExpectedCancelAction
    public let params: M2DownloadOperationExpectedCancelParams

    public init(action: M2DownloadOperationExpectedCancelAction = .cancel, params: M2DownloadOperationExpectedCancelParams) {
        self.action = action
        self.params = params
    }
}

/// Wire values of M2DownloadOperationExpectedCancelAction.
public enum M2DownloadOperationExpectedCancelAction: String, Codable, Sendable, CaseIterable {
    case cancel = "cancel"
}

public struct M2DownloadOperationExpectedCancelParams: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: Int64
    public let now: Int64?
    public let operationId: String
    public let sequence: Int64

    public init(sourceId: String, bookId: String, chapterIndex: Int64, now: Int64? = nil, operationId: String, sequence: Int64) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterIndex = chapterIndex
        self.now = now
        self.operationId = operationId
        self.sequence = sequence
    }
}

public struct M2DownloadOperationExpectedReport: Codable, Sendable {
    public let action: M2DownloadOperationExpectedReportAction
    public let params: M2DownloadOperationExpectedReportParams

    public init(action: M2DownloadOperationExpectedReportAction = .report, params: M2DownloadOperationExpectedReportParams) {
        self.action = action
        self.params = params
    }
}

/// Wire values of M2DownloadOperationExpectedReportAction.
public enum M2DownloadOperationExpectedReportAction: String, Codable, Sendable, CaseIterable {
    case report = "report"
}

public struct M2DownloadOperationExpectedReportParams: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: Int64
    public let token: String
    public let outcome: M2DownloadOperationExpectedReportParamsOutcome
    public let errorCode: String?
    public let reportedAt: Int64?
    public let manga: M2MangaOfflineReceipt?
    public let operationId: String
    public let sequence: Int64

    public init(sourceId: String, bookId: String, chapterIndex: Int64, token: String, outcome: M2DownloadOperationExpectedReportParamsOutcome, errorCode: String? = nil, reportedAt: Int64? = nil, manga: M2MangaOfflineReceipt? = nil, operationId: String, sequence: Int64) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterIndex = chapterIndex
        self.token = token
        self.outcome = outcome
        self.errorCode = errorCode
        self.reportedAt = reportedAt
        self.manga = manga
        self.operationId = operationId
        self.sequence = sequence
    }
}

/// Wire values of M2DownloadOperationExpectedReportParamsOutcome.
public enum M2DownloadOperationExpectedReportParamsOutcome: String, Codable, Sendable, CaseIterable {
    case completed = "completed"
    case failed = "failed"
}

public struct M2MangaOfflineReceipt: Codable, Sendable {
    public let chapter: M2MangaChapterIdentity
    public let manifestVersion: String
    public let resourceRefs: [String]

    public init(chapter: M2MangaChapterIdentity, manifestVersion: String, resourceRefs: [String]) {
        self.chapter = chapter
        self.manifestVersion = manifestVersion
        self.resourceRefs = resourceRefs
    }
}

/// Wire values of M2CacheDownloadOperationQueryParamsAction.
public enum M2CacheDownloadOperationQueryParamsAction: String, Codable, Sendable, CaseIterable {
    case prefetch = "prefetch"
    case pause = "pause"
    case resume = "resume"
    case cancel = "cancel"
    case report = "report"
}

public struct M2DownloadOperationQueryData: Codable, Sendable {
    public let head: M2ReadingOperationBinding?
    public let receipt: M2DownloadOperationReceipt?
    public let canResumeOriginal: Bool

    public init(head: M2ReadingOperationBinding?, receipt: M2DownloadOperationReceipt?, canResumeOriginal: Bool) {
        self.head = head
        self.receipt = receipt
        self.canResumeOriginal = canResumeOriginal
    }

    private enum CodingKeys: String, CodingKey {
        case head = "head"
        case receipt = "receipt"
        case canResumeOriginal = "canResumeOriginal"
    }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        head = try fields.decode(M2ReadingOperationBinding?.self, forKey: .head)
        receipt = try fields.decode(M2DownloadOperationReceipt?.self, forKey: .receipt)
        canResumeOriginal = try fields.decode(Bool.self, forKey: .canResumeOriginal)
    }

    public func encode(to encoder: any Encoder) throws {
        var fields = encoder.container(keyedBy: CodingKeys.self)
        try fields.encode(head, forKey: .head)
        try fields.encode(receipt, forKey: .receipt)
        try fields.encode(canResumeOriginal, forKey: .canResumeOriginal)
    }
}

public struct M2ReadingOperationBinding: Codable, Sendable {
    public let operationId: String
    public let sequence: Int64
    public let payloadFingerprint: String

    public init(operationId: String, sequence: Int64, payloadFingerprint: String) {
        self.operationId = operationId
        self.sequence = sequence
        self.payloadFingerprint = payloadFingerprint
    }
}

public struct M2DownloadOperationReceipt: Codable, Sendable {
    public let binding: M2ReadingOperationBinding
    public let phase: M2DownloadOperationReceiptPhase
    public let action: M2DownloadOperationReceiptAction
    public let data: M2DownloadOperationData?

    public init(binding: M2ReadingOperationBinding, phase: M2DownloadOperationReceiptPhase, action: M2DownloadOperationReceiptAction, data: M2DownloadOperationData?) {
        self.binding = binding
        self.phase = phase
        self.action = action
        self.data = data
    }

    private enum CodingKeys: String, CodingKey {
        case binding = "binding"
        case phase = "phase"
        case action = "action"
        case data = "data"
    }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        binding = try fields.decode(M2ReadingOperationBinding.self, forKey: .binding)
        phase = try fields.decode(M2DownloadOperationReceiptPhase.self, forKey: .phase)
        action = try fields.decode(M2DownloadOperationReceiptAction.self, forKey: .action)
        data = try fields.decode(M2DownloadOperationData?.self, forKey: .data)
    }

    public func encode(to encoder: any Encoder) throws {
        var fields = encoder.container(keyedBy: CodingKeys.self)
        try fields.encode(binding, forKey: .binding)
        try fields.encode(phase, forKey: .phase)
        try fields.encode(action, forKey: .action)
        try fields.encode(data, forKey: .data)
    }
}

/// Wire values of M2DownloadOperationReceiptPhase.
public enum M2DownloadOperationReceiptPhase: String, Codable, Sendable, CaseIterable {
    case pending = "pending"
    case committed = "committed"
    case settled = "settled"
}

/// Wire values of M2DownloadOperationReceiptAction.
public enum M2DownloadOperationReceiptAction: String, Codable, Sendable, CaseIterable {
    case prefetch = "prefetch"
    case pause = "pause"
    case resume = "resume"
    case cancel = "cancel"
    case report = "report"
}

public enum M2DownloadOperationData: Codable, Sendable {
    case prefetch(M2CacheBookPrefetchData)
    case task(M2CacheDownloadTaskResult)
    case report(M2CacheChapterMaterializationReportData)

    private enum CodingKeys: String, CodingKey { case chapterRange, status, state }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        let matches = [
            fields.contains(.chapterRange),
            fields.contains(.status),
            fields.contains(.state),
        ]
        guard matches.filter({ $0 }).count == 1, let index = matches.firstIndex(of: true) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown or ambiguous M2DownloadOperationData variant"))
        }
        switch index {
        case 0: self = .prefetch(try M2CacheBookPrefetchData(from: decoder))
        case 1: self = .task(try M2CacheDownloadTaskResult(from: decoder))
        case 2: self = .report(try M2CacheChapterMaterializationReportData(from: decoder))
        default:
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown M2DownloadOperationData variant index"))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .prefetch(let value): try value.encode(to: encoder)
        case .task(let value): try value.encode(to: encoder)
        case .report(let value): try value.encode(to: encoder)
        }
    }
}

public struct M2CacheDownloadTaskResult: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: Int64
    public let status: M2CacheDownloadTaskResultStatus
    public let attempts: Int64
    public let maxAttempts: Int64

    public init(sourceId: String, bookId: String, chapterIndex: Int64, status: M2CacheDownloadTaskResultStatus, attempts: Int64, maxAttempts: Int64) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterIndex = chapterIndex
        self.status = status
        self.attempts = attempts
        self.maxAttempts = maxAttempts
    }
}

/// Wire values of M2CacheDownloadTaskResultStatus.
public enum M2CacheDownloadTaskResultStatus: String, Codable, Sendable, CaseIterable {
    case pending = "pending"
    case paused = "paused"
    case inProgress = "inProgress"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
}

public struct M2CacheChapterMaterializationReportData: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: Int64
    public let state: M2CacheChapterState
    public let retainedCachedBody: Bool

    public init(sourceId: String, bookId: String, chapterIndex: Int64, state: M2CacheChapterState, retainedCachedBody: Bool) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterIndex = chapterIndex
        self.state = state
        self.retainedCachedBody = retainedCachedBody
    }
}

/// Wire values of M2CacheChapterState.
public enum M2CacheChapterState: String, Codable, Sendable, CaseIterable {
    case missing = "missing"
    case queued = "queued"
    case paused = "paused"
    case inProgress = "inProgress"
    case cached = "cached"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
}

public struct M2CacheDownloadOperationSettleParams: Codable, Sendable {
    public let operationId: String
    public let sequence: Int64
    public let payloadFingerprint: String
    public let sourceId: String
    public let bookId: String
    public let action: M2CacheDownloadOperationSettleParamsAction
    public let chapterIndex: Int64?

    public init(operationId: String, sequence: Int64, payloadFingerprint: String, sourceId: String, bookId: String, action: M2CacheDownloadOperationSettleParamsAction, chapterIndex: Int64? = nil) {
        self.operationId = operationId
        self.sequence = sequence
        self.payloadFingerprint = payloadFingerprint
        self.sourceId = sourceId
        self.bookId = bookId
        self.action = action
        self.chapterIndex = chapterIndex
    }
}

/// Wire values of M2CacheDownloadOperationSettleParamsAction.
public enum M2CacheDownloadOperationSettleParamsAction: String, Codable, Sendable, CaseIterable {
    case prefetch = "prefetch"
    case pause = "pause"
    case resume = "resume"
    case cancel = "cancel"
    case report = "report"
}

public struct M2SourceListParams: Codable, Sendable {
    public let includeCheckReports: Bool?
    public let checkReportVersion: M2SourceListParamsCheckReportVersion?
    public let sourceId: String?
    public let enabledOnly: Bool?

    public init(includeCheckReports: Bool? = nil, checkReportVersion: M2SourceListParamsCheckReportVersion? = nil, sourceId: String? = nil, enabledOnly: Bool? = nil) {
        self.includeCheckReports = includeCheckReports
        self.checkReportVersion = checkReportVersion
        self.sourceId = sourceId
        self.enabledOnly = enabledOnly
    }
}

public enum M2SourceListParamsCheckReportVersion: Int64, Codable, Sendable, CaseIterable {
    case v1 = 1
    case v2 = 2
}

public struct M2SourceListData: Codable, Sendable {
    public let sources: [M2SourceListEntry]
    public let total: Int64

    public init(sources: [M2SourceListEntry], total: Int64) {
        self.sources = sources
        self.total = total
    }
}

public struct M2SourceListEntry: Codable, Sendable {
    public let checkReports: [M2SourceCheckHistoryEntry]?
    public let sourceVersion: String?
    public let sourceId: String
    public let name: String
    public let baseUrl: String
    public let enabled: Bool
    public let enabledExplore: Bool
    public let bookSource: [String: ReaderM1JSONValue]?

    public init(checkReports: [M2SourceCheckHistoryEntry]? = nil, sourceVersion: String? = nil, sourceId: String, name: String, baseUrl: String, enabled: Bool, enabledExplore: Bool, bookSource: [String: ReaderM1JSONValue]? = nil) {
        self.checkReports = checkReports
        self.sourceVersion = sourceVersion
        self.sourceId = sourceId
        self.name = name
        self.baseUrl = baseUrl
        self.enabled = enabled
        self.enabledExplore = enabledExplore
        self.bookSource = bookSource
    }
}

public struct M2SourceCheckHistoryEntry: Codable, Sendable {
    public let checkedAtMs: Int64
    public let stale: Bool
    public let report: M2SourceCheckReport

    public init(checkedAtMs: Int64, stale: Bool, report: M2SourceCheckReport) {
        self.checkedAtMs = checkedAtMs
        self.stale = stale
        self.report = report
    }
}

public struct M2SourceCheckReport: Codable, Sendable {
    public let version: M2SourceCheckReportVersion
    public let mode: M2SourceCheckReportMode
    public let traceId: String
    public let ruleDigest: String?
    public let inputDigest: String
    public let executionOptions: M2SourceCheckExecutionOptions?
    public let executionOptionsDigest: String?
    public let contentKind: M2SourceCheckReportContentKind?
    public let steps: [M2SourceCheckReportStepsItem]

    public init(version: M2SourceCheckReportVersion, mode: M2SourceCheckReportMode, traceId: String, ruleDigest: String? = nil, inputDigest: String, executionOptions: M2SourceCheckExecutionOptions? = nil, executionOptionsDigest: String? = nil, contentKind: M2SourceCheckReportContentKind? = nil, steps: [M2SourceCheckReportStepsItem]) {
        self.version = version
        self.mode = mode
        self.traceId = traceId
        self.ruleDigest = ruleDigest
        self.inputDigest = inputDigest
        self.executionOptions = executionOptions
        self.executionOptionsDigest = executionOptionsDigest
        self.contentKind = contentKind
        self.steps = steps
    }
}

public enum M2SourceCheckReportVersion: Int64, Codable, Sendable, CaseIterable {
    case v1 = 1
    case v2 = 2
}

/// Wire values of M2SourceCheckReportMode.
public enum M2SourceCheckReportMode: String, Codable, Sendable, CaseIterable {
    case legacy = "legacy"
    case search = "search"
    case explore = "explore"
}

public struct M2SourceCheckExecutionOptions: Codable, Sendable {
    public let timeoutMs: Int64

    public init(timeoutMs: Int64) {
        self.timeoutMs = timeoutMs
    }
}

/// Wire values of M2SourceCheckReportContentKind.
public enum M2SourceCheckReportContentKind: String, Codable, Sendable, CaseIterable {
    case text = "text"
    case urlOnly = "url_only"
    case image = "image"
    case audio = "audio"
    case empty = "empty"
    case unsupported = "unsupported"
}

public struct M2SourceCheckReportStepsItem: Codable, Sendable {
    public let level: M2SourceCheckReportStepsItemLevel
    public let requested: Bool
    public let executed: Bool
    public let status: M2SourceCheckReportStepsItemStatus
    public let durationMs: Int64
    public let reason: String?

    public init(level: M2SourceCheckReportStepsItemLevel, requested: Bool, executed: Bool, status: M2SourceCheckReportStepsItemStatus, durationMs: Int64, reason: String? = nil) {
        self.level = level
        self.requested = requested
        self.executed = executed
        self.status = status
        self.durationMs = durationMs
        self.reason = reason
    }
}

/// Wire values of M2SourceCheckReportStepsItemLevel.
public enum M2SourceCheckReportStepsItemLevel: String, Codable, Sendable, CaseIterable {
    case l1 = "L1"
    case l2 = "L2"
    case l3 = "L3"
    case l4 = "L4"
    case l5 = "L5"
}

/// Wire values of M2SourceCheckReportStepsItemStatus.
public enum M2SourceCheckReportStepsItemStatus: String, Codable, Sendable, CaseIterable {
    case pass = "pass"
    case fail = "fail"
    case notRequested = "not_requested"
    case notSupported = "not_supported"
    case blocked = "blocked"
    case cancelled = "cancelled"
}

public struct M2SourceUpdateParams: Codable, Sendable {
    public let sourceId: String
    public let enabled: Bool

    public init(sourceId: String, enabled: Bool) {
        self.sourceId = sourceId
        self.enabled = enabled
    }
}

public struct M2SourceUpdateData: Codable, Sendable {
    public let source: M2SourceListEntry

    public init(source: M2SourceListEntry) {
        self.source = source
    }
}

public struct M2SourceDeleteParams: Codable, Sendable {
    public let sourceIds: [String]

    public init(sourceIds: [String]) {
        self.sourceIds = sourceIds
    }
}

public struct M2SourceDeleteData: Codable, Sendable {
    public let deleted: Int64

    public init(deleted: Int64) {
        self.deleted = deleted
    }
}

public struct M2SourceCheckParams: Codable, Sendable {
    public let sourceIds: [String]
    public let keyword: String?
    public let timeoutMs: Int64?
    public let levels: [M2SourceCheckParamsLevelsItem]?
    public let responses: [M2SourceCheckInput]?

    public init(sourceIds: [String], keyword: String? = nil, timeoutMs: Int64? = nil, levels: [M2SourceCheckParamsLevelsItem]? = nil, responses: [M2SourceCheckInput]? = nil) {
        self.sourceIds = sourceIds
        self.keyword = keyword
        self.timeoutMs = timeoutMs
        self.levels = levels
        self.responses = responses
    }
}

/// Wire values of M2SourceCheckParamsLevelsItem.
public enum M2SourceCheckParamsLevelsItem: String, Codable, Sendable, CaseIterable {
    case l1 = "L1"
    case l2 = "L2"
    case l3 = "L3"
    case l4 = "L4"
    case l5 = "L5"
}

public struct M2SourceCheckInput: Codable, Sendable {
    public let sourceId: String
    public let searchResponse: String?
    public let detailResponse: String?
    public let tocResponse: String?
    public let contentResponse: String?
    public let book: [String: ReaderM1JSONValue]?
    public let bookId: String?
    public let chapterTitle: String?

    public init(sourceId: String, searchResponse: String? = nil, detailResponse: String? = nil, tocResponse: String? = nil, contentResponse: String? = nil, book: [String: ReaderM1JSONValue]? = nil, bookId: String? = nil, chapterTitle: String? = nil) {
        self.sourceId = sourceId
        self.searchResponse = searchResponse
        self.detailResponse = detailResponse
        self.tocResponse = tocResponse
        self.contentResponse = contentResponse
        self.book = book
        self.bookId = bookId
        self.chapterTitle = chapterTitle
    }
}

public struct M2SourceCheckResultData: Codable, Sendable {
    public let results: [M2SourceCheckResult]
    public let traceId: String?

    public init(results: [M2SourceCheckResult], traceId: String? = nil) {
        self.results = results
        self.traceId = traceId
    }
}

public struct M2SourceCheckResult: Codable, Sendable {
    public let sourceId: String
    public let available: Bool
    public let levelsPassed: [M2SourceCheckResultLevelsPassedItem]
    public let failureReason: String?
    public let durationMs: Int64
    public let report: M2SourceCheckReport?
    public let debugLogs: [M2DebugLogEntry]?

    public init(sourceId: String, available: Bool, levelsPassed: [M2SourceCheckResultLevelsPassedItem], failureReason: String? = nil, durationMs: Int64, report: M2SourceCheckReport? = nil, debugLogs: [M2DebugLogEntry]? = nil) {
        self.sourceId = sourceId
        self.available = available
        self.levelsPassed = levelsPassed
        self.failureReason = failureReason
        self.durationMs = durationMs
        self.report = report
        self.debugLogs = debugLogs
    }
}

/// Wire values of M2SourceCheckResultLevelsPassedItem.
public enum M2SourceCheckResultLevelsPassedItem: String, Codable, Sendable, CaseIterable {
    case l1 = "L1"
    case l2 = "L2"
    case l3 = "L3"
    case l4 = "L4"
    case l5 = "L5"
}

public struct M2DebugLogEntry: Codable, Sendable {
    public let state: Int64
    public let msg: String
    public let timestampMs: Int64
    public let step: String?
    public let rule: String?
    public let extractedCount: Int64?
    public let errorKind: String?

    public init(state: Int64, msg: String, timestampMs: Int64, step: String? = nil, rule: String? = nil, extractedCount: Int64? = nil, errorKind: String? = nil) {
        self.state = state
        self.msg = msg
        self.timestampMs = timestampMs
        self.step = step
        self.rule = rule
        self.extractedCount = extractedCount
        self.errorKind = errorKind
    }
}

public struct M2SourceCheckRunParams: Codable, Sendable {
    public let reportVersion: M2SourceCheckRunParamsReportVersion?
    public let mode: M2SourceCheckRunParamsMode?
    public let sourceIds: [String]
    public let keyword: String?
    public let keywordOverride: Bool?
    public let timeoutMs: Int64?
    public let levels: [M2SourceCheckRunParamsLevelsItem]?

    public init(reportVersion: M2SourceCheckRunParamsReportVersion? = nil, mode: M2SourceCheckRunParamsMode? = nil, sourceIds: [String], keyword: String? = nil, keywordOverride: Bool? = nil, timeoutMs: Int64? = nil, levels: [M2SourceCheckRunParamsLevelsItem]? = nil) {
        self.reportVersion = reportVersion
        self.mode = mode
        self.sourceIds = sourceIds
        self.keyword = keyword
        self.keywordOverride = keywordOverride
        self.timeoutMs = timeoutMs
        self.levels = levels
    }
}

public enum M2SourceCheckRunParamsReportVersion: Int64, Codable, Sendable, CaseIterable {
    case v1 = 1
    case v2 = 2
}

/// Wire values of M2SourceCheckRunParamsMode.
public enum M2SourceCheckRunParamsMode: String, Codable, Sendable, CaseIterable {
    case legacy = "legacy"
    case search = "search"
    case explore = "explore"
}

/// Wire values of M2SourceCheckRunParamsLevelsItem.
public enum M2SourceCheckRunParamsLevelsItem: String, Codable, Sendable, CaseIterable {
    case l1 = "L1"
    case l2 = "L2"
    case l3 = "L3"
    case l4 = "L4"
    case l5 = "L5"
}

public struct M2SourceCheckEphemeralRunParams: Codable, Sendable {
    public let reportVersion: Int64?
    public let sources: [ReaderM1JSONValue]
    public let mode: M2SourceCheckEphemeralRunParamsMode?
    public let keyword: String?
    public let keywordOverride: Bool?
    public let timeoutMs: Int64?
    public let levels: [M2SourceCheckRunParamsItem]?

    public init(reportVersion: Int64? = nil, sources: [ReaderM1JSONValue], mode: M2SourceCheckEphemeralRunParamsMode? = nil, keyword: String? = nil, keywordOverride: Bool? = nil, timeoutMs: Int64? = nil, levels: [M2SourceCheckRunParamsItem]? = nil) {
        self.reportVersion = reportVersion
        self.sources = sources
        self.mode = mode
        self.keyword = keyword
        self.keywordOverride = keywordOverride
        self.timeoutMs = timeoutMs
        self.levels = levels
    }
}

/// Wire values of M2SourceCheckEphemeralRunParamsMode.
public enum M2SourceCheckEphemeralRunParamsMode: String, Codable, Sendable, CaseIterable {
    case legacy = "legacy"
    case search = "search"
    case explore = "explore"
}

/// Wire values of M2SourceCheckRunParamsItem.
public enum M2SourceCheckRunParamsItem: String, Codable, Sendable, CaseIterable {
    case l1 = "L1"
    case l2 = "L2"
    case l3 = "L3"
    case l4 = "L4"
    case l5 = "L5"
}

public struct M2SourceCheckReportClearParams: Codable, Sendable {
    public let sourceIds: [String]

    public init(sourceIds: [String]) {
        self.sourceIds = sourceIds
    }
}

public struct M2SourceCheckReportClearData: Codable, Sendable {
    public let clearedCount: Int64
    public let sourceIds: [String]

    public init(clearedCount: Int64, sourceIds: [String]) {
        self.clearedCount = clearedCount
        self.sourceIds = sourceIds
    }
}

public struct M2SourceGroupCatalogParams: Codable, Sendable {
    public let reportVersion: M2SourceGroupCatalogParamsReportVersion

    public init(reportVersion: M2SourceGroupCatalogParamsReportVersion = .v1) {
        self.reportVersion = reportVersion
    }
}

public enum M2SourceGroupCatalogParamsReportVersion: Int64, Codable, Sendable, CaseIterable {
    case v1 = 1
}

public struct M2SourceGroupCatalogData: Codable, Sendable {
    public let version: M2SourceGroupCatalogDataVersion
    public let revision: Int64
    public let groups: [M2SourceGroupRecord]
    public let memberships: [M2SourceGroupMembership]

    public init(version: M2SourceGroupCatalogDataVersion = .v1, revision: Int64, groups: [M2SourceGroupRecord], memberships: [M2SourceGroupMembership]) {
        self.version = version
        self.revision = revision
        self.groups = groups
        self.memberships = memberships
    }
}

public enum M2SourceGroupCatalogDataVersion: Int64, Codable, Sendable, CaseIterable {
    case v1 = 1
}

public struct M2SourceGroupRecord: Codable, Sendable {
    public let groupId: String
    public let name: String

    public init(groupId: String, name: String) {
        self.groupId = groupId
        self.name = name
    }
}

public struct M2SourceGroupMembership: Codable, Sendable {
    public let sourceId: String
    public let groupId: String
    public let locallyAssigned: Bool

    public init(sourceId: String, groupId: String, locallyAssigned: Bool) {
        self.sourceId = sourceId
        self.groupId = groupId
        self.locallyAssigned = locallyAssigned
    }
}

public struct M2RuleSubUpdatePreviewParams: Codable, Sendable {
    public let subscriptionId: Int64
    public let remoteJson: String
    public let expected: M2RuleSubUpdatePreviewExpected?

    public init(subscriptionId: Int64, remoteJson: String, expected: M2RuleSubUpdatePreviewExpected? = nil) {
        self.subscriptionId = subscriptionId
        self.remoteJson = remoteJson
        self.expected = expected
    }
}

public struct M2RuleSubUpdatePreviewExpected: Codable, Sendable {
    public let subscription: M2RuleSubPutParams
    public let rulesHead: M2ReadingOperationBinding?

    public init(subscription: M2RuleSubPutParams, rulesHead: M2ReadingOperationBinding? = nil) {
        self.subscription = subscription
        self.rulesHead = rulesHead
    }
}

public struct M2RuleSubPutParams: Codable, Sendable {
    public let id: Int64
    public let name: String?
    public let url: String?
    public let type: Int64?
    public let customOrder: Int64?
    public let autoUpdate: Bool?
    public let update: Int64?

    public init(id: Int64, name: String? = nil, url: String? = nil, type: Int64? = nil, customOrder: Int64? = nil, autoUpdate: Bool? = nil, update: Int64? = nil) {
        self.id = id
        self.name = name
        self.url = url
        self.type = type
        self.customOrder = customOrder
        self.autoUpdate = autoUpdate
        self.update = update
    }
}

public struct M2RuleSubUpdatePreviewData: Codable, Sendable {
    public let planId: String
    public let subscriptionId: Int64
    public let remoteDigest: String
    public let expiresAt: Int64
    public let changes: [M2RuleSubUpdateChange]

    public init(planId: String, subscriptionId: Int64, remoteDigest: String, expiresAt: Int64, changes: [M2RuleSubUpdateChange]) {
        self.planId = planId
        self.subscriptionId = subscriptionId
        self.remoteDigest = remoteDigest
        self.expiresAt = expiresAt
        self.changes = changes
    }
}

public struct M2RuleSubUpdateChange: Codable, Sendable {
    public let sourceId: String
    public let name: String
    public let kind: M2RuleSubUpdateChangeKind

    public init(sourceId: String, name: String, kind: M2RuleSubUpdateChangeKind) {
        self.sourceId = sourceId
        self.name = name
        self.kind = kind
    }
}

/// Wire values of M2RuleSubUpdateChangeKind.
public enum M2RuleSubUpdateChangeKind: String, Codable, Sendable, CaseIterable {
    case added = "added"
    case update = "update"
    case unchanged = "unchanged"
    case localOnly = "localOnly"
    case conflict = "conflict"
    case removedRemote = "removedRemote"
}

public struct M2BookDetailParams: Codable, Sendable {
    public let preparationRevision: Int64?
    public let sourceId: String
    public let book: M2BookDetailBookInput
    public let detailResponse: String?
    public let detailRequest: M2HostHttpRequest?
    public let source: [String: ReaderM1JSONValue]?
    public let bookUrl: String?

    public init(preparationRevision: Int64? = nil, sourceId: String, book: M2BookDetailBookInput, detailResponse: String? = nil, detailRequest: M2HostHttpRequest? = nil, source: [String: ReaderM1JSONValue]? = nil, bookUrl: String? = nil) {
        self.preparationRevision = preparationRevision
        self.sourceId = sourceId
        self.book = book
        self.detailResponse = detailResponse
        self.detailRequest = detailRequest
        self.source = source
        self.bookUrl = bookUrl
    }
}

public struct M2BookDetailBookInput: Codable, Sendable {
    public let bookId: String
    public let title: String?
    public let author: String?
    public let coverUrl: String?
    public let intro: String?
    public let kind: String?
    public let lastChapter: String?
    public let variables: [String: String]?

    public init(bookId: String, title: String? = nil, author: String? = nil, coverUrl: String? = nil, intro: String? = nil, kind: String? = nil, lastChapter: String? = nil, variables: [String: String]? = nil) {
        self.bookId = bookId
        self.title = title
        self.author = author
        self.coverUrl = coverUrl
        self.intro = intro
        self.kind = kind
        self.lastChapter = lastChapter
        self.variables = variables
    }
}

public struct M2BookDetailData: Codable, Sendable {
    public let sourceVersion: String?
    public let sourceId: String
    public let book: M2BookDetailBookData
    public let tocUrl: String?
    public let http: M2RemoteHttpDiagnosticsData?
    public let contentKind: M2BookDetailDataContentKind?
    public let variables: [String: String]?

    public init(sourceVersion: String? = nil, sourceId: String, book: M2BookDetailBookData, tocUrl: String? = nil, http: M2RemoteHttpDiagnosticsData? = nil, contentKind: M2BookDetailDataContentKind? = nil, variables: [String: String]? = nil) {
        self.sourceVersion = sourceVersion
        self.sourceId = sourceId
        self.book = book
        self.tocUrl = tocUrl
        self.http = http
        self.contentKind = contentKind
        self.variables = variables
    }
}

public struct M2BookDetailBookData: Codable, Sendable {
    public let bookId: String
    public let title: String
    public let author: String
    public let authorIdentity: M2BookAuthorIdentityData?
    public let coverUrl: String?
    public let intro: String?
    public let kind: String?
    public let lastChapter: String?

    public init(bookId: String, title: String, author: String, authorIdentity: M2BookAuthorIdentityData? = nil, coverUrl: String? = nil, intro: String? = nil, kind: String? = nil, lastChapter: String? = nil) {
        self.bookId = bookId
        self.title = title
        self.author = author
        self.authorIdentity = authorIdentity
        self.coverUrl = coverUrl
        self.intro = intro
        self.kind = kind
        self.lastChapter = lastChapter
    }
}

public struct M2BookAuthorIdentityData: Codable, Sendable {
    public let schemaVersion: M2BookAuthorIdentityDataSchemaVersion
    public let sourceVersion: String
    public let field: M2BookAuthorIdentityDataField
    public let raw: String
    public let label: String
    public let rule: M2BookAuthorIdentityDataRule

    public init(schemaVersion: M2BookAuthorIdentityDataSchemaVersion = .v1, sourceVersion: String, field: M2BookAuthorIdentityDataField, raw: String, label: String, rule: M2BookAuthorIdentityDataRule = .authorNicknameAtV1) {
        self.schemaVersion = schemaVersion
        self.sourceVersion = sourceVersion
        self.field = field
        self.raw = raw
        self.label = label
        self.rule = rule
    }
}

public enum M2BookAuthorIdentityDataSchemaVersion: Int64, Codable, Sendable, CaseIterable {
    case v1 = 1
}

/// Wire values of M2BookAuthorIdentityDataField.
public enum M2BookAuthorIdentityDataField: String, Codable, Sendable, CaseIterable {
    case search = "search"
    case detail = "detail"
}

/// Wire values of M2BookAuthorIdentityDataRule.
public enum M2BookAuthorIdentityDataRule: String, Codable, Sendable, CaseIterable {
    case authorNicknameAtV1 = "author-nickname-at-v1"
}

/// Wire values of M2BookDetailDataContentKind.
public enum M2BookDetailDataContentKind: String, Codable, Sendable, CaseIterable {
    case text = "text"
    case manga = "manga"
    case audio = "audio"
}

public struct M2ChapterContentParams: Codable, Sendable {
    public let directoryTargetProof: M2DirectoryTargetProof?
    public let preparationRevision: Int64?
    public let cacheOnly: Bool?
    public let forceRefresh: Bool?
    public let sourceId: String
    public let bookId: String
    public let chapterTitle: String?
    public let chapterIndex: Int64?
    public let chapterResponse: String?
    public let chapterRequest: M2HostHttpRequest?
    public let jsRule: String?
    public let source: [String: ReaderM1JSONValue]?
    public let chapterUrl: String?
    public let variables: [String: String]?
    public let upgradeCachedContent: Bool?
    public let positionContext: M2RemoteContentPositionContext?

    public init(directoryTargetProof: M2DirectoryTargetProof? = nil, preparationRevision: Int64? = nil, cacheOnly: Bool? = nil, forceRefresh: Bool? = nil, sourceId: String, bookId: String, chapterTitle: String? = nil, chapterIndex: Int64? = nil, chapterResponse: String? = nil, chapterRequest: M2HostHttpRequest? = nil, jsRule: String? = nil, source: [String: ReaderM1JSONValue]? = nil, chapterUrl: String? = nil, variables: [String: String]? = nil, upgradeCachedContent: Bool? = nil, positionContext: M2RemoteContentPositionContext? = nil) {
        self.directoryTargetProof = directoryTargetProof
        self.preparationRevision = preparationRevision
        self.cacheOnly = cacheOnly
        self.forceRefresh = forceRefresh
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterTitle = chapterTitle
        self.chapterIndex = chapterIndex
        self.chapterResponse = chapterResponse
        self.chapterRequest = chapterRequest
        self.jsRule = jsRule
        self.source = source
        self.chapterUrl = chapterUrl
        self.variables = variables
        self.upgradeCachedContent = upgradeCachedContent
        self.positionContext = positionContext
    }
}

public struct M2DirectoryTargetProof: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let catalogRevision: String
    public let structureRevision: String
    public let nodeId: String
    public let chapterIndex: Int64
    public let url: String

    public init(sourceId: String, bookId: String, catalogRevision: String, structureRevision: String, nodeId: String, chapterIndex: Int64, url: String) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.catalogRevision = catalogRevision
        self.structureRevision = structureRevision
        self.nodeId = nodeId
        self.chapterIndex = chapterIndex
        self.url = url
    }
}

public struct M2RemoteContentPositionContext: Codable, Sendable {
    public let bodyVersion: String
    public let processingVersion: String
    public let anchors: [M2RemoteContentPositionAnchor]

    public init(bodyVersion: String, processingVersion: String, anchors: [M2RemoteContentPositionAnchor]) {
        self.bodyVersion = bodyVersion
        self.processingVersion = processingVersion
        self.anchors = anchors
    }
}

public struct M2RemoteContentPositionAnchor: Codable, Sendable {
    public let id: String
    public let offset: Int64

    public init(id: String, offset: Int64) {
        self.id = id
        self.offset = offset
    }
}

public struct M2ChapterContentData: Codable, Sendable {
    public let bodyVersion: String?
    public let processingVersion: String?
    public let sourceId: String
    public let bookId: String
    public let chapterTitle: String
    public let content: ReaderM1JSONValue
    public let blocks: [M2ReadingDocumentBlockData]?
    public let contentFormatVersion: Int64?
    public let contentRefreshRequired: Bool?
    public let sourceCorrectionRequired: Bool?
    public let via: M2ChapterContentDataVia
    public let http: M2RemoteHttpDiagnosticsData?
    public let positionMigration: M2RemoteContentPositionMigrationData?

    public init(bodyVersion: String? = nil, processingVersion: String? = nil, sourceId: String, bookId: String, chapterTitle: String, content: ReaderM1JSONValue, blocks: [M2ReadingDocumentBlockData]? = nil, contentFormatVersion: Int64? = nil, contentRefreshRequired: Bool? = nil, sourceCorrectionRequired: Bool? = nil, via: M2ChapterContentDataVia, http: M2RemoteHttpDiagnosticsData? = nil, positionMigration: M2RemoteContentPositionMigrationData? = nil) {
        self.bodyVersion = bodyVersion
        self.processingVersion = processingVersion
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterTitle = chapterTitle
        self.content = content
        self.blocks = blocks
        self.contentFormatVersion = contentFormatVersion
        self.contentRefreshRequired = contentRefreshRequired
        self.sourceCorrectionRequired = sourceCorrectionRequired
        self.via = via
        self.http = http
        self.positionMigration = positionMigration
    }
}

public enum M2ReadingDocumentBlockData: Codable, Sendable {
    case text(M2ReadingDocumentBlockDataText)
    case image(M2ReadingDocumentBlockDataImage)

    private enum CodingKeys: String, CodingKey { case kind }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        let tag = fields.contains(.kind) ? try fields.decode(String.self, forKey: .kind) : nil
        switch tag {
        case "text": self = .text(try M2ReadingDocumentBlockDataText(from: decoder))
        case "image": self = .image(try M2ReadingDocumentBlockDataImage(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: fields, debugDescription: "Unknown M2ReadingDocumentBlockData tag")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .text(let value): try value.encode(to: encoder)
        case .image(let value): try value.encode(to: encoder)
        }
    }
}

public struct M2ReadingDocumentBlockDataText: Codable, Sendable {
    public let kind: M2ReadingDocumentBlockDataTextKind
    public let text: String
    public let startScalar: Int64
    public let endScalar: Int64

    public init(kind: M2ReadingDocumentBlockDataTextKind = .text, text: String, startScalar: Int64, endScalar: Int64) {
        self.kind = kind
        self.text = text
        self.startScalar = startScalar
        self.endScalar = endScalar
    }
}

/// Wire values of M2ReadingDocumentBlockDataTextKind.
public enum M2ReadingDocumentBlockDataTextKind: String, Codable, Sendable, CaseIterable {
    case text = "text"
}

public struct M2ReadingDocumentBlockDataImage: Codable, Sendable {
    public let kind: M2ReadingDocumentBlockDataImageKind
    public let source: String
    public let imageWidthBasisPoints: Int64?
    public let imageIntrinsicWidth: Int64?
    public let imageIntrinsicHeight: Int64?
    public let startScalar: Int64
    public let endScalar: Int64

    public init(kind: M2ReadingDocumentBlockDataImageKind = .image, source: String, imageWidthBasisPoints: Int64? = nil, imageIntrinsicWidth: Int64? = nil, imageIntrinsicHeight: Int64? = nil, startScalar: Int64, endScalar: Int64) {
        self.kind = kind
        self.source = source
        self.imageWidthBasisPoints = imageWidthBasisPoints
        self.imageIntrinsicWidth = imageIntrinsicWidth
        self.imageIntrinsicHeight = imageIntrinsicHeight
        self.startScalar = startScalar
        self.endScalar = endScalar
    }
}

/// Wire values of M2ReadingDocumentBlockDataImageKind.
public enum M2ReadingDocumentBlockDataImageKind: String, Codable, Sendable, CaseIterable {
    case image = "image"
}

/// Wire values of M2ChapterContentDataVia.
public enum M2ChapterContentDataVia: String, Codable, Sendable, CaseIterable {
    case rule = "rule"
    case js = "js"
    case cache = "cache"
}

public struct M2RemoteContentPositionMigrationData: Codable, Sendable {
    public let status: M2RemoteContentPositionMigrationDataStatus
    public let reason: String?
    public let previousBodyVersion: String
    public let bodyVersion: String
    public let previousProcessingVersion: String
    public let processingVersion: String
    public let anchors: [M2RemoteContentMappedAnchor]
    public let progress: M2ReadingProgressData?

    public init(status: M2RemoteContentPositionMigrationDataStatus, reason: String? = nil, previousBodyVersion: String, bodyVersion: String, previousProcessingVersion: String, processingVersion: String, anchors: [M2RemoteContentMappedAnchor], progress: M2ReadingProgressData? = nil) {
        self.status = status
        self.reason = reason
        self.previousBodyVersion = previousBodyVersion
        self.bodyVersion = bodyVersion
        self.previousProcessingVersion = previousProcessingVersion
        self.processingVersion = processingVersion
        self.anchors = anchors
        self.progress = progress
    }
}

/// Wire values of M2RemoteContentPositionMigrationDataStatus.
public enum M2RemoteContentPositionMigrationDataStatus: String, Codable, Sendable, CaseIterable {
    case committed = "committed"
    case unchanged = "unchanged"
    case preserved = "preserved"
}

public struct M2RemoteContentMappedAnchor: Codable, Sendable {
    public let id: String
    public let previousOffset: Int64
    public let offset: Int64

    public init(id: String, previousOffset: Int64, offset: Int64) {
        self.id = id
        self.previousOffset = previousOffset
        self.offset = offset
    }
}

public struct M2ReadingProgressData: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: Int64
    public let chapterOffset: Int64
    public let chapterProgress: Double
    public let updatedAt: Int64
    public let deviceId: String?
    public let locationRevision: String?
    public let bodyVersion: String?
    public let processingVersion: String?

    public init(sourceId: String, bookId: String, chapterIndex: Int64, chapterOffset: Int64, chapterProgress: Double, updatedAt: Int64, deviceId: String? = nil, locationRevision: String? = nil, bodyVersion: String? = nil, processingVersion: String? = nil) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterIndex = chapterIndex
        self.chapterOffset = chapterOffset
        self.chapterProgress = chapterProgress
        self.updatedAt = updatedAt
        self.deviceId = deviceId
        self.locationRevision = locationRevision
        self.bodyVersion = bodyVersion
        self.processingVersion = processingVersion
    }
}

public struct M2ChangeBookSourceParams: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let keyword: String?
    public let sourceIds: [String]

    public init(sourceId: String, bookId: String, keyword: String? = nil, sourceIds: [String]) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.keyword = keyword
        self.sourceIds = sourceIds
    }
}

public struct M2ChangeBookSourceData: Codable, Sendable {
    public let candidates: [M2ChangeBookSourceCandidate]

    public init(candidates: [M2ChangeBookSourceCandidate]) {
        self.candidates = candidates
    }
}

public struct M2ChangeBookSourceCandidate: Codable, Sendable {
    public let sourceId: String
    public let bookUrl: String
    public let bookName: String
    public let author: String?
    public let authorIdentity: M2BookAuthorIdentityData?
    public let coverUrl: String?

    public init(sourceId: String, bookUrl: String, bookName: String, author: String? = nil, authorIdentity: M2BookAuthorIdentityData? = nil, coverUrl: String? = nil) {
        self.sourceId = sourceId
        self.bookUrl = bookUrl
        self.bookName = bookName
        self.author = author
        self.authorIdentity = authorIdentity
        self.coverUrl = coverUrl
    }
}

public struct M2SourceSwitchCommitParams: Codable, Sendable {
    public let operationId: String?
    public let sequence: Int64?
    public let from: M2SourceSwitchBookKey
    public let target: M2SourceSwitchTargetBookData
    public let newToc: [M2SourceSwitchChapterData]
    public let currentChapterTitle: String
    public let currentChapterIndex: Int64
    public let updatedAt: Int64

    public init(operationId: String? = nil, sequence: Int64? = nil, from: M2SourceSwitchBookKey, target: M2SourceSwitchTargetBookData, newToc: [M2SourceSwitchChapterData], currentChapterTitle: String, currentChapterIndex: Int64, updatedAt: Int64) {
        self.operationId = operationId
        self.sequence = sequence
        self.from = from
        self.target = target
        self.newToc = newToc
        self.currentChapterTitle = currentChapterTitle
        self.currentChapterIndex = currentChapterIndex
        self.updatedAt = updatedAt
    }
}

public struct M2SourceSwitchBookKey: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let includeGlobalStats: Bool?
    public let includeChapterStates: Bool?

    public init(sourceId: String, bookId: String, includeGlobalStats: Bool? = nil, includeChapterStates: Bool? = nil) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.includeGlobalStats = includeGlobalStats
        self.includeChapterStates = includeChapterStates
    }
}

public struct M2SourceSwitchTargetBookData: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let title: String
    public let author: String?
    public let coverUrl: String?
    public let intro: String?
    public let kind: String?
    public let lastChapter: String?

    public init(sourceId: String, bookId: String, title: String, author: String? = nil, coverUrl: String? = nil, intro: String? = nil, kind: String? = nil, lastChapter: String? = nil) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.title = title
        self.author = author
        self.coverUrl = coverUrl
        self.intro = intro
        self.kind = kind
        self.lastChapter = lastChapter
    }
}

public struct M2SourceSwitchChapterData: Codable, Sendable {
    public let chapterId: String
    public let chapterTitle: String
    public let chapterUrl: String
    public let order: Int64

    public init(chapterId: String, chapterTitle: String, chapterUrl: String, order: Int64) {
        self.chapterId = chapterId
        self.chapterTitle = chapterTitle
        self.chapterUrl = chapterUrl
        self.order = order
    }
}

public struct M2SourceSwitchCommitData: Codable, Sendable {
    public let transactionId: String
    public let phase: M2SourceSwitchTransactionPhase
    public let book: M2BookshelfEntryData
    public let progress: M2ReadingProgressData?
    public let matchedChapter: M2SourceSwitchChapterData
    public let strategy: M2SourceSwitchCommitDataStrategy

    public init(transactionId: String, phase: M2SourceSwitchTransactionPhase, book: M2BookshelfEntryData, progress: M2ReadingProgressData? = nil, matchedChapter: M2SourceSwitchChapterData, strategy: M2SourceSwitchCommitDataStrategy) {
        self.transactionId = transactionId
        self.phase = phase
        self.book = book
        self.progress = progress
        self.matchedChapter = matchedChapter
        self.strategy = strategy
    }
}

/// Wire values of M2SourceSwitchTransactionPhase.
public enum M2SourceSwitchTransactionPhase: String, Codable, Sendable, CaseIterable {
    case pending = "pending"
    case finalized = "finalized"
    case rolledBack = "rolledBack"
}

public struct M2BookshelfEntryData: Codable, Sendable {
    public let readingPosition: M2BookshelfReadingPositionData?
    public let sourceName: String?
    public let sourceId: String
    public let bookId: String
    public let title: String
    public let author: String
    public let coverUrl: String?
    public let intro: String?
    public let kind: String?
    public let lastChapter: String?
    public let addedAt: Int64
    public let lastReadAt: Int64?
    public let group: String?
    public let sortIndex: Int64
    public let contentKind: M2BookshelfEntryDataContentKind?

    public init(readingPosition: M2BookshelfReadingPositionData? = nil, sourceName: String? = nil, sourceId: String, bookId: String, title: String, author: String, coverUrl: String? = nil, intro: String? = nil, kind: String? = nil, lastChapter: String? = nil, addedAt: Int64, lastReadAt: Int64? = nil, group: String? = nil, sortIndex: Int64, contentKind: M2BookshelfEntryDataContentKind? = nil) {
        self.readingPosition = readingPosition
        self.sourceName = sourceName
        self.sourceId = sourceId
        self.bookId = bookId
        self.title = title
        self.author = author
        self.coverUrl = coverUrl
        self.intro = intro
        self.kind = kind
        self.lastChapter = lastChapter
        self.addedAt = addedAt
        self.lastReadAt = lastReadAt
        self.group = group
        self.sortIndex = sortIndex
        self.contentKind = contentKind
    }
}

public struct M2BookshelfReadingPositionData: Codable, Sendable {
    public let chapterIndex: Int64
    public let chapterOffset: Int64
    public let updatedAt: Int64
    public let locationRevision: String?
    public let bodyVersion: String?
    public let processingVersion: String?

    public init(chapterIndex: Int64, chapterOffset: Int64, updatedAt: Int64, locationRevision: String? = nil, bodyVersion: String? = nil, processingVersion: String? = nil) {
        self.chapterIndex = chapterIndex
        self.chapterOffset = chapterOffset
        self.updatedAt = updatedAt
        self.locationRevision = locationRevision
        self.bodyVersion = bodyVersion
        self.processingVersion = processingVersion
    }
}

/// Wire values of M2BookshelfEntryDataContentKind.
public enum M2BookshelfEntryDataContentKind: String, Codable, Sendable, CaseIterable {
    case text = "text"
    case manga = "manga"
    case audio = "audio"
}

/// Wire values of M2SourceSwitchCommitDataStrategy.
public enum M2SourceSwitchCommitDataStrategy: String, Codable, Sendable, CaseIterable {
    case exactTitleMatch = "exactTitleMatch"
    case orderIndexMatch = "orderIndexMatch"
    case fuzzyTitleMatch = "fuzzyTitleMatch"
    case lastReadFallback = "lastReadFallback"
}

public struct M2SourceSwitchPendingListData: Codable, Sendable {
    public let pending: [M2PendingSourceSwitchData]

    public init(pending: [M2PendingSourceSwitchData]) {
        self.pending = pending
    }
}

public struct M2PendingSourceSwitchData: Codable, Sendable {
    public let transactionId: String
    public let phase: M2PendingSourceSwitchDataPhase
    public let createdAt: Int64
    public let from: M2SourceSwitchBookKey
    public let target: M2SourceSwitchBookKey

    public init(transactionId: String, phase: M2PendingSourceSwitchDataPhase = .pending, createdAt: Int64, from: M2SourceSwitchBookKey, target: M2SourceSwitchBookKey) {
        self.transactionId = transactionId
        self.phase = phase
        self.createdAt = createdAt
        self.from = from
        self.target = target
    }
}

/// Wire values of M2PendingSourceSwitchDataPhase.
public enum M2PendingSourceSwitchDataPhase: String, Codable, Sendable, CaseIterable {
    case pending = "pending"
}

public struct M2SourceSwitchTransactionQueryParams: Codable, Sendable {
    public let operationId: String
    public let expected: M2SourceSwitchCommitParams?
    public let expectedStage: M2SourceSwitchStageExpected?
    public let expectedCanonical: M2ReadingProgressUpdateParams?

    public init(operationId: String, expected: M2SourceSwitchCommitParams? = nil, expectedStage: M2SourceSwitchStageExpected? = nil, expectedCanonical: M2ReadingProgressUpdateParams? = nil) {
        self.operationId = operationId
        self.expected = expected
        self.expectedStage = expectedStage
        self.expectedCanonical = expectedCanonical
    }
}

public struct M2SourceSwitchStageExpected: Codable, Sendable {
    public let method: M2SourceSwitchStageExpectedMethod
    public let params: M2SourceSwitchTransactionParams

    public init(method: M2SourceSwitchStageExpectedMethod, params: M2SourceSwitchTransactionParams) {
        self.method = method
        self.params = params
    }
}

/// Wire values of M2SourceSwitchStageExpectedMethod.
public enum M2SourceSwitchStageExpectedMethod: String, Codable, Sendable, CaseIterable {
    case sourceSwitchFinalize = "source.switch.finalize"
    case sourceSwitchRollback = "source.switch.rollback"
}

public struct M2SourceSwitchTransactionParams: Codable, Sendable {
    public let transactionId: String
    public let operationId: String?
    public let sequence: Int64?

    public init(transactionId: String, operationId: String? = nil, sequence: Int64? = nil) {
        self.transactionId = transactionId
        self.operationId = operationId
        self.sequence = sequence
    }
}

public enum M2ReadingProgressUpdateParams: Codable, Sendable {
    case text(M2TextReadingProgressUpdateParams)
    case manga(M2MangaProgressUpdateParams)

    private enum CodingKeys: String, CodingKey { case kind }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        let tag = fields.contains(.kind) ? try fields.decode(String.self, forKey: .kind) : nil
        switch tag {
        case nil: self = .text(try M2TextReadingProgressUpdateParams(from: decoder))
        case "manga": self = .manga(try M2MangaProgressUpdateParams(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: fields, debugDescription: "Unknown M2ReadingProgressUpdateParams tag")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .text(let value): try value.encode(to: encoder)
        case .manga(let value): try value.encode(to: encoder)
        }
    }
}

public struct M2TextReadingProgressUpdateParams: Codable, Sendable {
    public let directoryTargetProof: M2DirectoryTargetProof?
    public let expectedProgressRevision: String?
    public let bookId: String
    public let sourceId: String?
    public let deviceId: String?
    public let updatedAt: Int64?
    public let chapterIndex: Int64?
    public let chapterOffset: Int64?
    public let chapterProgress: Double?
    public let anchor: M2ReaderLocationAnchorData?
    public let layout: M2ReaderLocationLayoutData?
    public let chapterTitle: String?
    public let locationRevision: String?
    public let transactionId: String?
    public let expectedBodyVersion: String?
    public let expectedProcessingVersion: String?

    public init(directoryTargetProof: M2DirectoryTargetProof? = nil, expectedProgressRevision: String? = nil, bookId: String, sourceId: String? = nil, deviceId: String? = nil, updatedAt: Int64? = nil, chapterIndex: Int64? = nil, chapterOffset: Int64? = nil, chapterProgress: Double? = nil, anchor: M2ReaderLocationAnchorData? = nil, layout: M2ReaderLocationLayoutData? = nil, chapterTitle: String? = nil, locationRevision: String? = nil, transactionId: String? = nil, expectedBodyVersion: String? = nil, expectedProcessingVersion: String? = nil) {
        self.directoryTargetProof = directoryTargetProof
        self.expectedProgressRevision = expectedProgressRevision
        self.bookId = bookId
        self.sourceId = sourceId
        self.deviceId = deviceId
        self.updatedAt = updatedAt
        self.chapterIndex = chapterIndex
        self.chapterOffset = chapterOffset
        self.chapterProgress = chapterProgress
        self.anchor = anchor
        self.layout = layout
        self.chapterTitle = chapterTitle
        self.locationRevision = locationRevision
        self.transactionId = transactionId
        self.expectedBodyVersion = expectedBodyVersion
        self.expectedProcessingVersion = expectedProcessingVersion
    }
}

public struct M2ReaderLocationAnchorData: Codable, Sendable {
    public let chapterOffset: Int64
    public let chapterProgress: Double

    public init(chapterOffset: Int64, chapterProgress: Double) {
        self.chapterOffset = chapterOffset
        self.chapterProgress = chapterProgress
    }
}

public struct M2ReaderLocationLayoutData: Codable, Sendable {
    public let viewportWidth: Int64
    public let viewportHeight: Int64
    public let fontScale: Double
    public let lineHeight: Double?
    public let pageIndex: Int64?
    public let pageCount: Int64?

    public init(viewportWidth: Int64, viewportHeight: Int64, fontScale: Double, lineHeight: Double? = nil, pageIndex: Int64? = nil, pageCount: Int64? = nil) {
        self.viewportWidth = viewportWidth
        self.viewportHeight = viewportHeight
        self.fontScale = fontScale
        self.lineHeight = lineHeight
        self.pageIndex = pageIndex
        self.pageCount = pageCount
    }
}

public struct M2MangaProgressUpdateParams: Codable, Sendable {
    public let kind: M2MangaProgressUpdateParamsKind
    public let location: M2MangaLocation
    public let expectedEpoch: Int64
    public let expectedRevision: Int64

    public init(kind: M2MangaProgressUpdateParamsKind = .manga, location: M2MangaLocation, expectedEpoch: Int64, expectedRevision: Int64) {
        self.kind = kind
        self.location = location
        self.expectedEpoch = expectedEpoch
        self.expectedRevision = expectedRevision
    }
}

/// Wire values of M2MangaProgressUpdateParamsKind.
public enum M2MangaProgressUpdateParamsKind: String, Codable, Sendable, CaseIterable {
    case manga = "manga"
}

public struct M2MangaLocation: Codable, Sendable {
    public let kind: M2MangaLocationKind
    public let chapter: M2MangaChapterIdentity
    public let manifestVersion: String
    public let pageId: String
    public let pageOrdinalFallback: Int64
    public let x: Double
    public let y: Double
    public let progressRevision: Int64

    public init(kind: M2MangaLocationKind = .manga, chapter: M2MangaChapterIdentity, manifestVersion: String, pageId: String, pageOrdinalFallback: Int64, x: Double, y: Double, progressRevision: Int64) {
        self.kind = kind
        self.chapter = chapter
        self.manifestVersion = manifestVersion
        self.pageId = pageId
        self.pageOrdinalFallback = pageOrdinalFallback
        self.x = x
        self.y = y
        self.progressRevision = progressRevision
    }
}

/// Wire values of M2MangaLocationKind.
public enum M2MangaLocationKind: String, Codable, Sendable, CaseIterable {
    case manga = "manga"
}

public struct M2SourceSwitchTransactionQueryData: Codable, Sendable {
    public let head: M2SourceSwitchHeadData?
    public let transaction: M2SourceSwitchTransactionReceiptData?

    public init(head: M2SourceSwitchHeadData?, transaction: M2SourceSwitchTransactionReceiptData?) {
        self.head = head
        self.transaction = transaction
    }

    private enum CodingKeys: String, CodingKey {
        case head = "head"
        case transaction = "transaction"
    }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        head = try fields.decode(M2SourceSwitchHeadData?.self, forKey: .head)
        transaction = try fields.decode(M2SourceSwitchTransactionReceiptData?.self, forKey: .transaction)
    }

    public func encode(to encoder: any Encoder) throws {
        var fields = encoder.container(keyedBy: CodingKeys.self)
        try fields.encode(head, forKey: .head)
        try fields.encode(transaction, forKey: .transaction)
    }
}

public struct M2SourceSwitchHeadData: Codable, Sendable {
    public let operationId: String
    public let sequence: Int64

    public init(operationId: String, sequence: Int64) {
        self.operationId = operationId
        self.sequence = sequence
    }
}

public struct M2SourceSwitchTransactionReceiptData: Codable, Sendable {
    public let operationId: String
    public let sequence: Int64
    public let payloadFingerprint: String
    public let from: M2SourceSwitchBookKey
    public let target: M2SourceSwitchBookKey
    public let phase: M2SourceSwitchTransactionPhase
    public let commit: M2SourceSwitchCommitData
    public let restoredBook: M2BookshelfEntryData?
    public let restoredProgress: M2ReadingProgressData?
    public let originalCommit: M2SourceSwitchCommitData?
    public let stage: M2SourceSwitchStageReceiptData?
    public let canonicalProgress: M2ReadingProgressUpdateData?

    public init(operationId: String, sequence: Int64, payloadFingerprint: String, from: M2SourceSwitchBookKey, target: M2SourceSwitchBookKey, phase: M2SourceSwitchTransactionPhase, commit: M2SourceSwitchCommitData, restoredBook: M2BookshelfEntryData? = nil, restoredProgress: M2ReadingProgressData? = nil, originalCommit: M2SourceSwitchCommitData? = nil, stage: M2SourceSwitchStageReceiptData? = nil, canonicalProgress: M2ReadingProgressUpdateData? = nil) {
        self.operationId = operationId
        self.sequence = sequence
        self.payloadFingerprint = payloadFingerprint
        self.from = from
        self.target = target
        self.phase = phase
        self.commit = commit
        self.restoredBook = restoredBook
        self.restoredProgress = restoredProgress
        self.originalCommit = originalCommit
        self.stage = stage
        self.canonicalProgress = canonicalProgress
    }
}

public struct M2SourceSwitchStageReceiptData: Codable, Sendable {
    public let operationId: String
    public let sequence: Int64
    public let method: M2SourceSwitchStageReceiptDataMethod
    public let payloadFingerprint: String
    public let result: M2SourceSwitchStageReceiptDataResult?
    public let error: ReaderCoreError?

    public init(operationId: String, sequence: Int64, method: M2SourceSwitchStageReceiptDataMethod, payloadFingerprint: String, result: M2SourceSwitchStageReceiptDataResult? = nil, error: ReaderCoreError? = nil) {
        self.operationId = operationId
        self.sequence = sequence
        self.method = method
        self.payloadFingerprint = payloadFingerprint
        self.result = result
        self.error = error
    }
}

/// Wire values of M2SourceSwitchStageReceiptDataMethod.
public enum M2SourceSwitchStageReceiptDataMethod: String, Codable, Sendable, CaseIterable {
    case sourceSwitchFinalize = "source.switch.finalize"
    case sourceSwitchRollback = "source.switch.rollback"
}

public enum M2SourceSwitchStageReceiptDataResult: Codable, Sendable {
    case finalized(M2SourceSwitchFinalizeData)
    case rolledBack(M2SourceSwitchRollbackData)

    private enum CodingKeys: String, CodingKey { case phase }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        let tag = fields.contains(.phase) ? try fields.decode(String.self, forKey: .phase) : nil
        switch tag {
        case "finalized": self = .finalized(try M2SourceSwitchFinalizeData(from: decoder))
        case "rolledBack": self = .rolledBack(try M2SourceSwitchRollbackData(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .phase, in: fields, debugDescription: "Unknown M2SourceSwitchStageReceiptDataResult tag")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .finalized(let value): try value.encode(to: encoder)
        case .rolledBack(let value): try value.encode(to: encoder)
        }
    }
}

public struct M2SourceSwitchFinalizeData: Codable, Sendable {
    public let transactionId: String
    public let phase: M2SourceSwitchFinalizeDataPhase
    public let changed: Bool

    public init(transactionId: String, phase: M2SourceSwitchFinalizeDataPhase = .finalized, changed: Bool) {
        self.transactionId = transactionId
        self.phase = phase
        self.changed = changed
    }
}

/// Wire values of M2SourceSwitchFinalizeDataPhase.
public enum M2SourceSwitchFinalizeDataPhase: String, Codable, Sendable, CaseIterable {
    case finalized = "finalized"
}

public struct M2SourceSwitchRollbackData: Codable, Sendable {
    public let transactionId: String
    public let phase: M2SourceSwitchRollbackDataPhase
    public let changed: Bool
    public let restoredBook: M2BookshelfEntryData
    public let restoredProgress: M2ReadingProgressData?
    public let reinstatedTargetBook: M2BookshelfEntryData?
    public let reinstatedTargetProgress: M2ReadingProgressData?

    public init(transactionId: String, phase: M2SourceSwitchRollbackDataPhase = .rolledBack, changed: Bool, restoredBook: M2BookshelfEntryData, restoredProgress: M2ReadingProgressData? = nil, reinstatedTargetBook: M2BookshelfEntryData? = nil, reinstatedTargetProgress: M2ReadingProgressData? = nil) {
        self.transactionId = transactionId
        self.phase = phase
        self.changed = changed
        self.restoredBook = restoredBook
        self.restoredProgress = restoredProgress
        self.reinstatedTargetBook = reinstatedTargetBook
        self.reinstatedTargetProgress = reinstatedTargetProgress
    }
}

/// Wire values of M2SourceSwitchRollbackDataPhase.
public enum M2SourceSwitchRollbackDataPhase: String, Codable, Sendable, CaseIterable {
    case rolledBack = "rolledBack"
}

public struct M2ReadingProgressUpdateData: Codable, Sendable {
    public let progressRevision: String?
    public let bookId: String
    public let sourceId: String
    public let deviceId: String?
    public let updatedAt: Int64
    public let chapterIndex: Int64
    public let chapterOffset: Int64
    public let chapterProgress: Double
    public let stored: Bool
    public let locationRevision: String?
    public let transactionId: String?
    public let sourceSwitchFinalized: Bool?
    public let bodyVersion: String?
    public let processingVersion: String?

    public init(progressRevision: String? = nil, bookId: String, sourceId: String, deviceId: String? = nil, updatedAt: Int64, chapterIndex: Int64, chapterOffset: Int64, chapterProgress: Double, stored: Bool, locationRevision: String? = nil, transactionId: String? = nil, sourceSwitchFinalized: Bool? = nil, bodyVersion: String? = nil, processingVersion: String? = nil) {
        self.progressRevision = progressRevision
        self.bookId = bookId
        self.sourceId = sourceId
        self.deviceId = deviceId
        self.updatedAt = updatedAt
        self.chapterIndex = chapterIndex
        self.chapterOffset = chapterOffset
        self.chapterProgress = chapterProgress
        self.stored = stored
        self.locationRevision = locationRevision
        self.transactionId = transactionId
        self.sourceSwitchFinalized = sourceSwitchFinalized
        self.bodyVersion = bodyVersion
        self.processingVersion = processingVersion
    }
}

public struct M2SourceSwitchRecoverData: Codable, Sendable {
    public let recovered: [M2SourceSwitchRollbackData]

    public init(recovered: [M2SourceSwitchRollbackData]) {
        self.recovered = recovered
    }
}

public struct M2CacheBookStatusParams: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let includeGlobalStats: Bool?
    public let includeChapterStates: Bool?

    public init(sourceId: String, bookId: String, includeGlobalStats: Bool? = nil, includeChapterStates: Bool? = nil) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.includeGlobalStats = includeGlobalStats
        self.includeChapterStates = includeChapterStates
    }
}

public struct M2CacheBookStatusData: Codable, Sendable {
    public let sourceVersion: String?
    public let catalogAt: Int64?
    public let catalogVersion: String?
    public let contextVersion: String?
    public let continuationVariables: [String: String]?
    public let sourceId: String
    public let bookId: String
    public let tocAvailable: Bool
    public let chapterCount: Int64
    public let chapters: [M2CacheChapterStatusData]
    public let cachedCount: Int64
    public let queuedCount: Int64
    public let inProgressCount: Int64
    public let completedCount: Int64
    public let failedCount: Int64
    public let cancelledCount: Int64
    public let missingCount: Int64
    public let globalStats: M2CacheGlobalStatsData
    public let readableChapterCount: Int64?

    public init(sourceVersion: String? = nil, catalogAt: Int64? = nil, catalogVersion: String? = nil, contextVersion: String? = nil, continuationVariables: [String: String]? = nil, sourceId: String, bookId: String, tocAvailable: Bool, chapterCount: Int64, chapters: [M2CacheChapterStatusData], cachedCount: Int64, queuedCount: Int64, inProgressCount: Int64, completedCount: Int64, failedCount: Int64, cancelledCount: Int64, missingCount: Int64, globalStats: M2CacheGlobalStatsData, readableChapterCount: Int64? = nil) {
        self.sourceVersion = sourceVersion
        self.catalogAt = catalogAt
        self.catalogVersion = catalogVersion
        self.contextVersion = contextVersion
        self.continuationVariables = continuationVariables
        self.sourceId = sourceId
        self.bookId = bookId
        self.tocAvailable = tocAvailable
        self.chapterCount = chapterCount
        self.chapters = chapters
        self.cachedCount = cachedCount
        self.queuedCount = queuedCount
        self.inProgressCount = inProgressCount
        self.completedCount = completedCount
        self.failedCount = failedCount
        self.cancelledCount = cancelledCount
        self.missingCount = missingCount
        self.globalStats = globalStats
        self.readableChapterCount = readableChapterCount
    }
}

public struct M2CacheChapterStatusData: Codable, Sendable {
    public let level: Int64?
    public let displayTitle: String?
    public let contextTitle: String?
    public let isVip: Bool?
    public let isPay: Bool?
    public let chapterIndex: Int64
    public let title: String
    public let url: String
    public let state: M2CacheChapterState
    public let cachedBytes: Int64
    public let attempts: Int64
    public let maxAttempts: Int64
    public let lastError: String?
    public let navigable: Bool?
    public let proofState: M2CacheChapterStatusDataProofState?
    public let resumeOnly: Bool?
    public let mangaManifestVersion: String?

    public init(level: Int64? = nil, displayTitle: String? = nil, contextTitle: String? = nil, isVip: Bool? = nil, isPay: Bool? = nil, chapterIndex: Int64, title: String, url: String, state: M2CacheChapterState, cachedBytes: Int64, attempts: Int64, maxAttempts: Int64, lastError: String? = nil, navigable: Bool? = nil, proofState: M2CacheChapterStatusDataProofState? = nil, resumeOnly: Bool? = nil, mangaManifestVersion: String? = nil) {
        self.level = level
        self.displayTitle = displayTitle
        self.contextTitle = contextTitle
        self.isVip = isVip
        self.isPay = isPay
        self.chapterIndex = chapterIndex
        self.title = title
        self.url = url
        self.state = state
        self.cachedBytes = cachedBytes
        self.attempts = attempts
        self.maxAttempts = maxAttempts
        self.lastError = lastError
        self.navigable = navigable
        self.proofState = proofState
        self.resumeOnly = resumeOnly
        self.mangaManifestVersion = mangaManifestVersion
    }
}

/// Wire values of M2CacheChapterStatusDataProofState.
public enum M2CacheChapterStatusDataProofState: String, Codable, Sendable, CaseIterable {
    case verified = "verified"
    case legacyUnknown = "legacyUnknown"
    case invalid = "invalid"
}

public struct M2CacheGlobalStatsData: Codable, Sendable {
    public let entryCount: Int64
    public let totalContentBytes: Int64
    public let oldestCachedAt: Int64?
    public let newestCachedAt: Int64?
    public let queueEntryCount: Int64
    public let queuedCount: Int64
    public let inProgressCount: Int64
    public let completedCount: Int64
    public let failedCount: Int64
    public let cancelledCount: Int64

    public init(entryCount: Int64, totalContentBytes: Int64, oldestCachedAt: Int64? = nil, newestCachedAt: Int64? = nil, queueEntryCount: Int64, queuedCount: Int64, inProgressCount: Int64, completedCount: Int64, failedCount: Int64, cancelledCount: Int64) {
        self.entryCount = entryCount
        self.totalContentBytes = totalContentBytes
        self.oldestCachedAt = oldestCachedAt
        self.newestCachedAt = newestCachedAt
        self.queueEntryCount = queueEntryCount
        self.queuedCount = queuedCount
        self.inProgressCount = inProgressCount
        self.completedCount = completedCount
        self.failedCount = failedCount
        self.cancelledCount = cancelledCount
    }
}

public struct M2CacheDownloadTaskParams: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: Int64
    public let now: Int64?
    public let operationId: String?
    public let sequence: Int64?

    public init(sourceId: String, bookId: String, chapterIndex: Int64, now: Int64? = nil, operationId: String? = nil, sequence: Int64? = nil) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterIndex = chapterIndex
        self.now = now
        self.operationId = operationId
        self.sequence = sequence
    }
}

public struct M2CacheChapterMaterializationReportParams: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: Int64
    public let token: String
    public let outcome: M2CacheChapterMaterializationReportParamsOutcome
    public let errorCode: String?
    public let reportedAt: Int64?
    public let manga: M2MangaOfflineReceipt?
    public let operationId: String?
    public let sequence: Int64?

    public init(sourceId: String, bookId: String, chapterIndex: Int64, token: String, outcome: M2CacheChapterMaterializationReportParamsOutcome, errorCode: String? = nil, reportedAt: Int64? = nil, manga: M2MangaOfflineReceipt? = nil, operationId: String? = nil, sequence: Int64? = nil) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterIndex = chapterIndex
        self.token = token
        self.outcome = outcome
        self.errorCode = errorCode
        self.reportedAt = reportedAt
        self.manga = manga
        self.operationId = operationId
        self.sequence = sequence
    }
}

/// Wire values of M2CacheChapterMaterializationReportParamsOutcome.
public enum M2CacheChapterMaterializationReportParamsOutcome: String, Codable, Sendable, CaseIterable {
    case completed = "completed"
    case failed = "failed"
}

public struct M2CacheStorageParams: Codable, Sendable {
    public let retainCompletedQueue: Bool?
    public let retainedChapters: [M2CacheStorageChapter]?
    public let protectedChapters: [M2CacheStorageChapter]?
    public let reason: M2CacheStorageParamsReason?
    public let nowSeconds: Int64?
    public let ttlSeconds: Int64?
    public let capacityBytes: Int64?
    public let hostImageChapters: [M2CacheStorageImageChapter]?
    public let completedQueueAfter: M2CacheStorageChapter?
    public let contentScope: M2CacheStorageParamsContentScope?

    public init(retainCompletedQueue: Bool? = nil, retainedChapters: [M2CacheStorageChapter]? = nil, protectedChapters: [M2CacheStorageChapter]? = nil, reason: M2CacheStorageParamsReason? = nil, nowSeconds: Int64? = nil, ttlSeconds: Int64? = nil, capacityBytes: Int64? = nil, hostImageChapters: [M2CacheStorageImageChapter]? = nil, completedQueueAfter: M2CacheStorageChapter? = nil, contentScope: M2CacheStorageParamsContentScope? = nil) {
        self.retainCompletedQueue = retainCompletedQueue
        self.retainedChapters = retainedChapters
        self.protectedChapters = protectedChapters
        self.reason = reason
        self.nowSeconds = nowSeconds
        self.ttlSeconds = ttlSeconds
        self.capacityBytes = capacityBytes
        self.hostImageChapters = hostImageChapters
        self.completedQueueAfter = completedQueueAfter
        self.contentScope = contentScope
    }
}

public struct M2CacheStorageChapter: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: Int64

    public init(sourceId: String, bookId: String, chapterIndex: Int64) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterIndex = chapterIndex
    }
}

/// Wire values of M2CacheStorageParamsReason.
public enum M2CacheStorageParamsReason: String, Codable, Sendable, CaseIterable {
    case clear = "clear"
    case expiry = "expiry"
    case capacity = "capacity"
}

public struct M2CacheStorageImageChapter: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: Int64
    public let contentBytes: Int64
    public let cachedAtSeconds: Int64?

    public init(sourceId: String, bookId: String, chapterIndex: Int64, contentBytes: Int64, cachedAtSeconds: Int64? = nil) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterIndex = chapterIndex
        self.contentBytes = contentBytes
        self.cachedAtSeconds = cachedAtSeconds
    }
}

/// Wire values of M2CacheStorageParamsContentScope.
public enum M2CacheStorageParamsContentScope: String, Codable, Sendable, CaseIterable {
    case all = "all"
    case text = "text"
}

public struct M2CacheStorageData: Codable, Sendable {
    public let totalBytes: Int64
    public let retainedBytes: Int64
    public let automaticBytes: Int64
    public let cleanableBytes: Int64
    public let protectedChapters: [M2CacheStorageChapter]
    public let removedChapters: [M2CacheStorageChapter]
    public let hasMore: Bool
    public let cleanupError: String?
    public let removedContentBytes: Int64
    public let completedQueueChapters: [M2CacheStorageChapter]
    public let completedQueueHasMore: Bool

    public init(totalBytes: Int64, retainedBytes: Int64, automaticBytes: Int64, cleanableBytes: Int64, protectedChapters: [M2CacheStorageChapter], removedChapters: [M2CacheStorageChapter], hasMore: Bool, cleanupError: String? = nil, removedContentBytes: Int64, completedQueueChapters: [M2CacheStorageChapter], completedQueueHasMore: Bool) {
        self.totalBytes = totalBytes
        self.retainedBytes = retainedBytes
        self.automaticBytes = automaticBytes
        self.cleanableBytes = cleanableBytes
        self.protectedChapters = protectedChapters
        self.removedChapters = removedChapters
        self.hasMore = hasMore
        self.cleanupError = cleanupError
        self.removedContentBytes = removedContentBytes
        self.completedQueueChapters = completedQueueChapters
        self.completedQueueHasMore = completedQueueHasMore
    }
}

public struct M2DirectoryViewOpenParamsV2: Codable, Sendable {
    public let bookId: String
    public let collapsedNodeIds: [String]?
    public let query: String?
    public let descending: Bool?
    public let chapterIndex: Int64?
    public let chapterOffsetScalar: Int64?
    public let anchorNodeId: String?
    public let limit: Int64?
    public let sourceId: String

    public init(bookId: String, collapsedNodeIds: [String]? = nil, query: String? = nil, descending: Bool? = nil, chapterIndex: Int64? = nil, chapterOffsetScalar: Int64? = nil, anchorNodeId: String? = nil, limit: Int64? = nil, sourceId: String) {
        self.bookId = bookId
        self.collapsedNodeIds = collapsedNodeIds
        self.query = query
        self.descending = descending
        self.chapterIndex = chapterIndex
        self.chapterOffsetScalar = chapterOffsetScalar
        self.anchorNodeId = anchorNodeId
        self.limit = limit
        self.sourceId = sourceId
    }
}

public struct M2DirectoryViewOpenDataV2: Codable, Sendable {
    public let status: M2DirectoryViewOpenDataV2Status
    public let reason: String?
    public let viewId: String?
    public let navigationRevision: String?
    public let visibleTotal: Int64?
    public let nodes: [M2DirectoryViewNodeV2]?
    public let nextOffset: Int64?
    public let currentVisibleIndex: Int64?
    public let currentAncestorNodeId: String?
    public let anchorVisibleIndex: Int64?
    public let sourceId: String?
    public let bookId: String?
    public let catalogRevision: String?
    public let structureRevision: String?

    public init(status: M2DirectoryViewOpenDataV2Status, reason: String? = nil, viewId: String? = nil, navigationRevision: String? = nil, visibleTotal: Int64? = nil, nodes: [M2DirectoryViewNodeV2]? = nil, nextOffset: Int64? = nil, currentVisibleIndex: Int64? = nil, currentAncestorNodeId: String? = nil, anchorVisibleIndex: Int64? = nil, sourceId: String? = nil, bookId: String? = nil, catalogRevision: String? = nil, structureRevision: String? = nil) {
        self.status = status
        self.reason = reason
        self.viewId = viewId
        self.navigationRevision = navigationRevision
        self.visibleTotal = visibleTotal
        self.nodes = nodes
        self.nextOffset = nextOffset
        self.currentVisibleIndex = currentVisibleIndex
        self.currentAncestorNodeId = currentAncestorNodeId
        self.anchorVisibleIndex = anchorVisibleIndex
        self.sourceId = sourceId
        self.bookId = bookId
        self.catalogRevision = catalogRevision
        self.structureRevision = structureRevision
    }
}

/// Wire values of M2DirectoryViewOpenDataV2Status.
public enum M2DirectoryViewOpenDataV2Status: String, Codable, Sendable, CaseIterable {
    case ready = "ready"
    case unavailable = "unavailable"
}

public struct M2DirectoryViewNodeV2: Codable, Sendable {
    public let displayTitle: String?
    public let contextTitle: String?
    public let isVip: Bool?
    public let isPay: Bool?
    public let parentTitle: String?
    public let readableDescendantCount: Int64?
    public let nodeId: String
    public let parentId: String?
    public let depth: Int64
    public let title: String
    public let kind: M2DirectoryViewNodeV2Kind
    public let chapterIndex: Int64?
    public let chapterOffsetScalar: Int64?
    public let hasChildren: Bool
    public let expanded: Bool

    public init(displayTitle: String? = nil, contextTitle: String? = nil, isVip: Bool? = nil, isPay: Bool? = nil, parentTitle: String? = nil, readableDescendantCount: Int64? = nil, nodeId: String, parentId: String? = nil, depth: Int64, title: String, kind: M2DirectoryViewNodeV2Kind, chapterIndex: Int64? = nil, chapterOffsetScalar: Int64? = nil, hasChildren: Bool, expanded: Bool) {
        self.displayTitle = displayTitle
        self.contextTitle = contextTitle
        self.isVip = isVip
        self.isPay = isPay
        self.parentTitle = parentTitle
        self.readableDescendantCount = readableDescendantCount
        self.nodeId = nodeId
        self.parentId = parentId
        self.depth = depth
        self.title = title
        self.kind = kind
        self.chapterIndex = chapterIndex
        self.chapterOffsetScalar = chapterOffsetScalar
        self.hasChildren = hasChildren
        self.expanded = expanded
    }
}

/// Wire values of M2DirectoryViewNodeV2Kind.
public enum M2DirectoryViewNodeV2Kind: String, Codable, Sendable, CaseIterable {
    case group = "group"
    case target = "target"
    case disabled = "disabled"
}

public struct M2DirectoryViewPageParamsV2: Codable, Sendable {
    public let bookId: String
    public let viewId: String
    public let offset: Int64
    public let limit: Int64
    public let sourceId: String
    public let catalogRevision: String
    public let structureRevision: String

    public init(bookId: String, viewId: String, offset: Int64, limit: Int64, sourceId: String, catalogRevision: String, structureRevision: String) {
        self.bookId = bookId
        self.viewId = viewId
        self.offset = offset
        self.limit = limit
        self.sourceId = sourceId
        self.catalogRevision = catalogRevision
        self.structureRevision = structureRevision
    }
}

public struct M2DirectoryViewPageDataV2: Codable, Sendable {
    public let viewId: String
    public let navigationRevision: String
    public let visibleTotal: Int64
    public let nodes: [M2DirectoryViewNodeV2]
    public let nextOffset: Int64?
    public let sourceId: String
    public let bookId: String
    public let catalogRevision: String
    public let structureRevision: String

    public init(viewId: String, navigationRevision: String, visibleTotal: Int64, nodes: [M2DirectoryViewNodeV2], nextOffset: Int64?, sourceId: String, bookId: String, catalogRevision: String, structureRevision: String) {
        self.viewId = viewId
        self.navigationRevision = navigationRevision
        self.visibleTotal = visibleTotal
        self.nodes = nodes
        self.nextOffset = nextOffset
        self.sourceId = sourceId
        self.bookId = bookId
        self.catalogRevision = catalogRevision
        self.structureRevision = structureRevision
    }

    private enum CodingKeys: String, CodingKey {
        case viewId = "viewId"
        case navigationRevision = "navigationRevision"
        case visibleTotal = "visibleTotal"
        case nodes = "nodes"
        case nextOffset = "nextOffset"
        case sourceId = "sourceId"
        case bookId = "bookId"
        case catalogRevision = "catalogRevision"
        case structureRevision = "structureRevision"
    }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        viewId = try fields.decode(String.self, forKey: .viewId)
        navigationRevision = try fields.decode(String.self, forKey: .navigationRevision)
        visibleTotal = try fields.decode(Int64.self, forKey: .visibleTotal)
        nodes = try fields.decode([M2DirectoryViewNodeV2].self, forKey: .nodes)
        nextOffset = try fields.decode(Int64?.self, forKey: .nextOffset)
        sourceId = try fields.decode(String.self, forKey: .sourceId)
        bookId = try fields.decode(String.self, forKey: .bookId)
        catalogRevision = try fields.decode(String.self, forKey: .catalogRevision)
        structureRevision = try fields.decode(String.self, forKey: .structureRevision)
    }

    public func encode(to encoder: any Encoder) throws {
        var fields = encoder.container(keyedBy: CodingKeys.self)
        try fields.encode(viewId, forKey: .viewId)
        try fields.encode(navigationRevision, forKey: .navigationRevision)
        try fields.encode(visibleTotal, forKey: .visibleTotal)
        try fields.encode(nodes, forKey: .nodes)
        try fields.encode(nextOffset, forKey: .nextOffset)
        try fields.encode(sourceId, forKey: .sourceId)
        try fields.encode(bookId, forKey: .bookId)
        try fields.encode(catalogRevision, forKey: .catalogRevision)
        try fields.encode(structureRevision, forKey: .structureRevision)
    }
}

public struct M2DirectoryTargetResolveParamsV2: Codable, Sendable {
    public let bookId: String
    public let viewId: String
    public let nodeId: String
    public let sourceId: String
    public let catalogRevision: String
    public let structureRevision: String

    public init(bookId: String, viewId: String, nodeId: String, sourceId: String, catalogRevision: String, structureRevision: String) {
        self.bookId = bookId
        self.viewId = viewId
        self.nodeId = nodeId
        self.sourceId = sourceId
        self.catalogRevision = catalogRevision
        self.structureRevision = structureRevision
    }
}

public struct M2DirectoryTargetResolveDataV2: Codable, Sendable {
    public let chapterIndex: Int64
    public let chapterOffsetScalar: Int64?
    public let positionScope: M2RemoteContentPositionScope?
    public let sourceId: String
    public let bookId: String
    public let catalogRevision: String
    public let structureRevision: String
    public let kind: M2DirectoryTargetResolveDataV2Kind
    public let viewId: String
    public let nodeId: String
    public let directoryTargetProof: M2DirectoryTargetProof
    public let navigationRevision: String?

    public init(chapterIndex: Int64, chapterOffsetScalar: Int64? = nil, positionScope: M2RemoteContentPositionScope? = nil, sourceId: String, bookId: String, catalogRevision: String, structureRevision: String, kind: M2DirectoryTargetResolveDataV2Kind, viewId: String, nodeId: String, directoryTargetProof: M2DirectoryTargetProof, navigationRevision: String? = nil) {
        self.chapterIndex = chapterIndex
        self.chapterOffsetScalar = chapterOffsetScalar
        self.positionScope = positionScope
        self.sourceId = sourceId
        self.bookId = bookId
        self.catalogRevision = catalogRevision
        self.structureRevision = structureRevision
        self.kind = kind
        self.viewId = viewId
        self.nodeId = nodeId
        self.directoryTargetProof = directoryTargetProof
        self.navigationRevision = navigationRevision
    }
}

public struct M2RemoteContentPositionScope: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: Int64
    public let bodyVersion: String
    public let processingVersion: String

    public init(sourceId: String, bookId: String, chapterIndex: Int64, bodyVersion: String, processingVersion: String) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterIndex = chapterIndex
        self.bodyVersion = bodyVersion
        self.processingVersion = processingVersion
    }
}

/// Wire values of M2DirectoryTargetResolveDataV2Kind.
public enum M2DirectoryTargetResolveDataV2Kind: String, Codable, Sendable, CaseIterable {
    case chapterStart = "chapterStart"
    case exact = "exact"
}

public struct M2SourceExportParams: Codable, Sendable {
    public let sourceIds: [String]?
    public let format: M2SourceExportParamsFormat?
    public let encryptKey: String?

    public init(sourceIds: [String]? = nil, format: M2SourceExportParamsFormat? = nil, encryptKey: String? = nil) {
        self.sourceIds = sourceIds
        self.format = format
        self.encryptKey = encryptKey
    }
}

/// Wire values of M2SourceExportParamsFormat.
public enum M2SourceExportParamsFormat: String, Codable, Sendable, CaseIterable {
    case json = "json"
    case encryptedJson = "encrypted-json"
}

public struct M2SourceExportData: Codable, Sendable {
    public let data: String
    public let count: Int64
    public let format: M2SourceExportDataFormat

    public init(data: String, count: Int64, format: M2SourceExportDataFormat) {
        self.data = data
        self.count = count
        self.format = format
    }
}

/// Wire values of M2SourceExportDataFormat.
public enum M2SourceExportDataFormat: String, Codable, Sendable, CaseIterable {
    case json = "json"
    case encryptedJson = "encrypted-json"
}

public struct M2SourceDebugParams: Codable, Sendable {
    public let sourceId: String
    public let key: String?
    public let responses: M2SourceCheckInput?

    public init(sourceId: String, key: String? = nil, responses: M2SourceCheckInput? = nil) {
        self.sourceId = sourceId
        self.key = key
        self.responses = responses
    }
}

public struct M2SourceDebugData: Codable, Sendable {
    public let logs: [M2SourceDebugLog]
    public let finalState: Int64
    public let durationMs: Int64

    public init(logs: [M2SourceDebugLog], finalState: Int64, durationMs: Int64) {
        self.logs = logs
        self.finalState = finalState
        self.durationMs = durationMs
    }
}

public struct M2SourceDebugLog: Codable, Sendable {
    public let state: Int64
    public let msg: String
    public let timestampMs: Int64
    public let step: String?

    public init(state: Int64, msg: String, timestampMs: Int64, step: String? = nil) {
        self.state = state
        self.msg = msg
        self.timestampMs = timestampMs
        self.step = step
    }
}

public struct M2RuleSubListData: Codable, Sendable {
    public let subs: [M2RuleSubData]

    public init(subs: [M2RuleSubData]) {
        self.subs = subs
    }
}

public struct M2RuleSubData: Codable, Sendable {
    public let id: Int64
    public let name: String
    public let url: String
    public let type: Int64
    public let customOrder: Int64
    public let autoUpdate: Bool
    public let update: Int64

    public init(id: Int64, name: String, url: String, type: Int64, customOrder: Int64, autoUpdate: Bool, update: Int64) {
        self.id = id
        self.name = name
        self.url = url
        self.type = type
        self.customOrder = customOrder
        self.autoUpdate = autoUpdate
        self.update = update
    }
}

public struct M2RuleSubPutData: Codable, Sendable {
    public let sub: M2RuleSubData

    public init(sub: M2RuleSubData) {
        self.sub = sub
    }
}

public struct M2RuleSubKeyParams: Codable, Sendable {
    public let id: Int64

    public init(id: Int64) {
        self.id = id
    }
}

public struct M2RuleSubGetData: Codable, Sendable {
    public let sub: M2RuleSubData?

    public init(sub: M2RuleSubData?) {
        self.sub = sub
    }

    private enum CodingKeys: String, CodingKey {
        case sub = "sub"
    }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        sub = try fields.decode(M2RuleSubData?.self, forKey: .sub)
    }

    public func encode(to encoder: any Encoder) throws {
        var fields = encoder.container(keyedBy: CodingKeys.self)
        try fields.encode(sub, forKey: .sub)
    }
}

public struct M2RuleSubDeleteData: Codable, Sendable {
    public let id: Int64
    public let deleted: Bool

    public init(id: Int64, deleted: Bool) {
        self.id = id
        self.deleted = deleted
    }
}

public struct M2BookSearchParams: Codable, Sendable {
    public let sourceId: String
    public let searchResponse: String?
    public let searchRequest: M2HostHttpRequest?
    public let source: [String: ReaderM1JSONValue]?
    public let keyword: String?
    public let page: Int64?

    public init(sourceId: String, searchResponse: String? = nil, searchRequest: M2HostHttpRequest? = nil, source: [String: ReaderM1JSONValue]? = nil, keyword: String? = nil, page: Int64? = nil) {
        self.sourceId = sourceId
        self.searchResponse = searchResponse
        self.searchRequest = searchRequest
        self.source = source
        self.keyword = keyword
        self.page = page
    }
}

public struct M2BookSearchData: Codable, Sendable {
    public let searchTiming: M2BookSearchDataSearchTiming?
    public let sourceVersion: String?
    public let sourceId: String
    public let books: [M2BookSearchBookData]
    public let http: M2RemoteHttpDiagnosticsData?
    public let contentKind: M2BookSearchDataContentKind?

    public init(searchTiming: M2BookSearchDataSearchTiming? = nil, sourceVersion: String? = nil, sourceId: String, books: [M2BookSearchBookData], http: M2RemoteHttpDiagnosticsData? = nil, contentKind: M2BookSearchDataContentKind? = nil) {
        self.searchTiming = searchTiming
        self.sourceVersion = sourceVersion
        self.sourceId = sourceId
        self.books = books
        self.http = http
        self.contentKind = contentKind
    }
}

public struct M2BookSearchDataSearchTiming: Codable, Sendable {
    public let kind: M2BookSearchDataSearchTimingKind
    public let durationMs: Int64
    public let measuredAt: Int64
    public let sourceVersion: String

    public init(kind: M2BookSearchDataSearchTimingKind = .search, durationMs: Int64, measuredAt: Int64, sourceVersion: String) {
        self.kind = kind
        self.durationMs = durationMs
        self.measuredAt = measuredAt
        self.sourceVersion = sourceVersion
    }
}

/// Wire values of M2BookSearchDataSearchTimingKind.
public enum M2BookSearchDataSearchTimingKind: String, Codable, Sendable, CaseIterable {
    case search = "search"
}

public struct M2BookSearchBookData: Codable, Sendable {
    public let bookId: String
    public let title: String
    public let authorIdentity: M2BookAuthorIdentityData?
    public let author: String?
    public let coverUrl: String?
    public let intro: String?
    public let tocUrl: String?
    public let kind: String?
    public let lastChapter: String?
    public let wordCount: String?
    public let variables: [String: String]?

    public init(bookId: String, title: String, authorIdentity: M2BookAuthorIdentityData? = nil, author: String? = nil, coverUrl: String? = nil, intro: String? = nil, tocUrl: String? = nil, kind: String? = nil, lastChapter: String? = nil, wordCount: String? = nil, variables: [String: String]? = nil) {
        self.bookId = bookId
        self.title = title
        self.authorIdentity = authorIdentity
        self.author = author
        self.coverUrl = coverUrl
        self.intro = intro
        self.tocUrl = tocUrl
        self.kind = kind
        self.lastChapter = lastChapter
        self.wordCount = wordCount
        self.variables = variables
    }
}

/// Wire values of M2BookSearchDataContentKind.
public enum M2BookSearchDataContentKind: String, Codable, Sendable, CaseIterable {
    case text = "text"
    case manga = "manga"
    case audio = "audio"
}

public struct M2SearchBookPutParams: Codable, Sendable {
    public let bookUrl: String
    public let origin: String?
    public let originName: String?
    public let type: Int64?
    public let name: String?
    public let author: String?
    public let kind: String?
    public let coverUrl: String?
    public let intro: String?
    public let wordCount: String?
    public let latestChapterTitle: String?
    public let tocUrl: String?
    public let time: Int64?
    public let variable: String?
    public let originOrder: Int64?
    public let chapterWordCountText: String?
    public let chapterWordCount: Int64?
    public let respondTime: Int64?
    public let acquisition: M2BookAcquisitionVerdict?

    public init(bookUrl: String, origin: String? = nil, originName: String? = nil, type: Int64? = nil, name: String? = nil, author: String? = nil, kind: String? = nil, coverUrl: String? = nil, intro: String? = nil, wordCount: String? = nil, latestChapterTitle: String? = nil, tocUrl: String? = nil, time: Int64? = nil, variable: String? = nil, originOrder: Int64? = nil, chapterWordCountText: String? = nil, chapterWordCount: Int64? = nil, respondTime: Int64? = nil, acquisition: M2BookAcquisitionVerdict? = nil) {
        self.bookUrl = bookUrl
        self.origin = origin
        self.originName = originName
        self.type = type
        self.name = name
        self.author = author
        self.kind = kind
        self.coverUrl = coverUrl
        self.intro = intro
        self.wordCount = wordCount
        self.latestChapterTitle = latestChapterTitle
        self.tocUrl = tocUrl
        self.time = time
        self.variable = variable
        self.originOrder = originOrder
        self.chapterWordCountText = chapterWordCountText
        self.chapterWordCount = chapterWordCount
        self.respondTime = respondTime
        self.acquisition = acquisition
    }
}

public enum M2BookAcquisitionVerdict: Codable, Sendable {
    case v1(M2BookAcquisitionVerdictV1)
    case v2(M2BookAcquisitionVerdictV2)

    private enum CodingKeys: String, CodingKey { case schemaVersion }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        let tag = fields.contains(.schemaVersion) ? try fields.decode(Int64.self, forKey: .schemaVersion) : nil
        switch tag {
        case 1: self = .v1(try M2BookAcquisitionVerdictV1(from: decoder))
        case 2: self = .v2(try M2BookAcquisitionVerdictV2(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .schemaVersion, in: fields, debugDescription: "Unknown M2BookAcquisitionVerdict tag")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .v1(let value): try value.encode(to: encoder)
        case .v2(let value): try value.encode(to: encoder)
        }
    }
}

public struct M2BookAcquisitionVerdictV1: Codable, Sendable {
    public let schemaVersion: M2BookAcquisitionVerdictV1SchemaVersion
    public let sourceVersion: String
    public let stage: M2BookAcquisitionVerdictV1Stage
    public let checkedAt: Int64
    public let chapterUrl: String?
    public let message: String?

    public init(schemaVersion: M2BookAcquisitionVerdictV1SchemaVersion = .v1, sourceVersion: String, stage: M2BookAcquisitionVerdictV1Stage, checkedAt: Int64, chapterUrl: String? = nil, message: String? = nil) {
        self.schemaVersion = schemaVersion
        self.sourceVersion = sourceVersion
        self.stage = stage
        self.checkedAt = checkedAt
        self.chapterUrl = chapterUrl
        self.message = message
    }
}

public enum M2BookAcquisitionVerdictV1SchemaVersion: Int64, Codable, Sendable, CaseIterable {
    case v1 = 1
}

/// Wire values of M2BookAcquisitionVerdictV1Stage.
public enum M2BookAcquisitionVerdictV1Stage: String, Codable, Sendable, CaseIterable {
    case readable = "readable"
    case failed = "failed"
}

public struct M2BookAcquisitionVerdictV2: Codable, Sendable {
    public let schemaVersion: M2BookAcquisitionVerdictV2SchemaVersion
    public let sourceVersion: String
    public let stage: M2BookAcquisitionVerdictV2Stage
    public let checkedAt: Int64
    public let catalogVersion: String?
    public let contextVersion: String?
    public let chapterIndex: Int64?
    public let chapterUrl: String?
    public let bodyVersion: String?
    public let processingVersion: String?
    public let contentVersion: String?
    public let projectionVersion: String?
    public let failureStage: M2BookAcquisitionVerdictV2FailureStage?
    public let failureCategory: M2BookAcquisitionVerdictV2FailureCategory?
    public let message: String?

    public init(schemaVersion: M2BookAcquisitionVerdictV2SchemaVersion = .v2, sourceVersion: String, stage: M2BookAcquisitionVerdictV2Stage, checkedAt: Int64, catalogVersion: String? = nil, contextVersion: String? = nil, chapterIndex: Int64? = nil, chapterUrl: String? = nil, bodyVersion: String? = nil, processingVersion: String? = nil, contentVersion: String? = nil, projectionVersion: String? = nil, failureStage: M2BookAcquisitionVerdictV2FailureStage? = nil, failureCategory: M2BookAcquisitionVerdictV2FailureCategory? = nil, message: String? = nil) {
        self.schemaVersion = schemaVersion
        self.sourceVersion = sourceVersion
        self.stage = stage
        self.checkedAt = checkedAt
        self.catalogVersion = catalogVersion
        self.contextVersion = contextVersion
        self.chapterIndex = chapterIndex
        self.chapterUrl = chapterUrl
        self.bodyVersion = bodyVersion
        self.processingVersion = processingVersion
        self.contentVersion = contentVersion
        self.projectionVersion = projectionVersion
        self.failureStage = failureStage
        self.failureCategory = failureCategory
        self.message = message
    }
}

public enum M2BookAcquisitionVerdictV2SchemaVersion: Int64, Codable, Sendable, CaseIterable {
    case v2 = 2
}

/// Wire values of M2BookAcquisitionVerdictV2Stage.
public enum M2BookAcquisitionVerdictV2Stage: String, Codable, Sendable, CaseIterable {
    case readable = "readable"
    case failed = "failed"
}

/// Wire values of M2BookAcquisitionVerdictV2FailureStage.
public enum M2BookAcquisitionVerdictV2FailureStage: String, Codable, Sendable, CaseIterable {
    case detail = "detail"
    case catalog = "catalog"
    case chapter = "chapter"
    case refresh = "refresh"
}

/// Wire values of M2BookAcquisitionVerdictV2FailureCategory.
public enum M2BookAcquisitionVerdictV2FailureCategory: String, Codable, Sendable, CaseIterable {
    case cacheMissing = "CACHE_MISSING"
    case cacheDerivedCorrupt = "CACHE_DERIVED_CORRUPT"
    case storageFailure = "STORAGE_FAILURE"
    case cancelled = "CANCELLED"
    case identityMismatch = "IDENTITY_MISMATCH"
    case sourceVersionChanged = "SOURCE_VERSION_CHANGED"
    case sourceHttpFailed = "SOURCE_HTTP_FAILED"
    case sourceResponseFormat = "SOURCE_RESPONSE_FORMAT"
    case sourceRuleFailed = "SOURCE_RULE_FAILED"
    case sourceTocEmpty = "SOURCE_TOC_EMPTY"
    case sourceContentEmpty = "SOURCE_CONTENT_EMPTY"
    case positionContextStale = "POSITION_CONTEXT_STALE"
    case networkEnvironment = "NETWORK_ENVIRONMENT"
}

public struct M2SearchBookPutData: Codable, Sendable {
    public let book: M2SearchBookData

    public init(book: M2SearchBookData) {
        self.book = book
    }
}

public struct M2SearchBookData: Codable, Sendable {
    public let bookUrl: String
    public let origin: String
    public let originName: String
    public let type: Int64
    public let name: String
    public let author: String
    public let kind: String?
    public let coverUrl: String?
    public let intro: String?
    public let wordCount: String?
    public let latestChapterTitle: String?
    public let tocUrl: String
    public let time: Int64
    public let variable: String?
    public let originOrder: Int64
    public let chapterWordCountText: String?
    public let chapterWordCount: Int64
    public let respondTime: Int64
    public let acquisition: M2BookAcquisitionVerdict?
    public let relationKey: String?
    public let relationRevision: String?

    public init(bookUrl: String, origin: String, originName: String, type: Int64, name: String, author: String, kind: String? = nil, coverUrl: String? = nil, intro: String? = nil, wordCount: String? = nil, latestChapterTitle: String? = nil, tocUrl: String, time: Int64, variable: String? = nil, originOrder: Int64, chapterWordCountText: String? = nil, chapterWordCount: Int64, respondTime: Int64, acquisition: M2BookAcquisitionVerdict? = nil, relationKey: String? = nil, relationRevision: String? = nil) {
        self.bookUrl = bookUrl
        self.origin = origin
        self.originName = originName
        self.type = type
        self.name = name
        self.author = author
        self.kind = kind
        self.coverUrl = coverUrl
        self.intro = intro
        self.wordCount = wordCount
        self.latestChapterTitle = latestChapterTitle
        self.tocUrl = tocUrl
        self.time = time
        self.variable = variable
        self.originOrder = originOrder
        self.chapterWordCountText = chapterWordCountText
        self.chapterWordCount = chapterWordCount
        self.respondTime = respondTime
        self.acquisition = acquisition
        self.relationKey = relationKey
        self.relationRevision = relationRevision
    }
}

public struct M2SearchBookKeyParams: Codable, Sendable {
    public let bookUrl: String
    public let origin: String?

    public init(bookUrl: String, origin: String? = nil) {
        self.bookUrl = bookUrl
        self.origin = origin
    }
}

public struct M2SearchBookGetData: Codable, Sendable {
    public let book: M2SearchBookData?

    public init(book: M2SearchBookData?) {
        self.book = book
    }

    private enum CodingKeys: String, CodingKey {
        case book = "book"
    }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        book = try fields.decode(M2SearchBookData?.self, forKey: .book)
    }

    public func encode(to encoder: any Encoder) throws {
        var fields = encoder.container(keyedBy: CodingKeys.self)
        try fields.encode(book, forKey: .book)
    }
}

public struct M2SearchBookBatchGetParams: Codable, Sendable {
    public let identities: [M2SearchBookIdentity]

    public init(identities: [M2SearchBookIdentity]) {
        self.identities = identities
    }
}

public struct M2SearchBookIdentity: Codable, Sendable {
    public let sourceId: String
    public let bookId: String

    public init(sourceId: String, bookId: String) {
        self.sourceId = sourceId
        self.bookId = bookId
    }
}

public struct M2SearchBookBatchGetData: Codable, Sendable {
    public let books: [M2SearchBookData]
    public let missing: [M2SearchBookIdentity]
    public let sourceVersions: [M2SearchBookSourceVersion]
    public let snapshotRevision: String
    public let complete: Bool

    public init(books: [M2SearchBookData], missing: [M2SearchBookIdentity], sourceVersions: [M2SearchBookSourceVersion], snapshotRevision: String, complete: Bool) {
        self.books = books
        self.missing = missing
        self.sourceVersions = sourceVersions
        self.snapshotRevision = snapshotRevision
        self.complete = complete
    }
}

public struct M2SearchBookSourceVersion: Codable, Sendable {
    public let sourceId: String
    public let sourceVersion: String
    public let enabled: Bool

    public init(sourceId: String, sourceVersion: String, enabled: Bool) {
        self.sourceId = sourceId
        self.sourceVersion = sourceVersion
        self.enabled = enabled
    }
}

public struct M2SearchBookRelatedParams: Codable, Sendable {
    public let mode: M2SearchBookRelatedParamsMode?
    public let identity: M2SearchBookIdentity?
    public let name: String?
    public let author: String?
    public let limit: Int64?
    public let cursor: String?

    public init(mode: M2SearchBookRelatedParamsMode? = nil, identity: M2SearchBookIdentity? = nil, name: String? = nil, author: String? = nil, limit: Int64? = nil, cursor: String? = nil) {
        self.mode = mode
        self.identity = identity
        self.name = name
        self.author = author
        self.limit = limit
        self.cursor = cursor
    }
}

/// Wire values of M2SearchBookRelatedParamsMode.
public enum M2SearchBookRelatedParamsMode: String, Codable, Sendable, CaseIterable {
    case mangaCandidates = "mangaCandidates"
}

public struct M2SearchBookRelatedData: Codable, Sendable {
    public let books: [M2SearchBookData]
    public let sourceVersions: [M2SearchBookSourceVersion]
    public let snapshotRevision: String
    public let complete: Bool
    public let nextCursor: String?

    public init(books: [M2SearchBookData], sourceVersions: [M2SearchBookSourceVersion], snapshotRevision: String, complete: Bool, nextCursor: String? = nil) {
        self.books = books
        self.sourceVersions = sourceVersions
        self.snapshotRevision = snapshotRevision
        self.complete = complete
        self.nextCursor = nextCursor
    }
}

public struct M2SearchBookDeleteData: Codable, Sendable {
    public let bookUrl: String
    public let deleted: Bool

    public init(bookUrl: String, deleted: Bool) {
        self.bookUrl = bookUrl
        self.deleted = deleted
    }
}

public struct M2SearchBookListParams: Codable, Sendable {
    public let origin: String?

    public init(origin: String? = nil) {
        self.origin = origin
    }
}

public struct M2SearchBookListData: Codable, Sendable {
    public let books: [M2SearchBookData]

    public init(books: [M2SearchBookData]) {
        self.books = books
    }
}

public struct M2SearchHistoryListParams: Codable, Sendable {
    public let limit: Int64?

    public init(limit: Int64? = nil) {
        self.limit = limit
    }
}

public struct M2SearchHistoryListData: Codable, Sendable {
    public let keywords: [String]
    public let count: Int64

    public init(keywords: [String], count: Int64) {
        self.keywords = keywords
        self.count = count
    }
}

public struct M2SearchHistoryAddParams: Codable, Sendable {
    public let keyword: String

    public init(keyword: String) {
        self.keyword = keyword
    }
}

public struct M2SearchHistoryAddData: Codable, Sendable {
    public let added: Bool
    public let keyword: String

    public init(added: Bool, keyword: String) {
        self.added = added
        self.keyword = keyword
    }
}

public struct M2SearchHistoryClearParams: Codable, Sendable {
    public init() {
    }
}

public struct M2SearchHistoryClearData: Codable, Sendable {
    public let cleared: Int64

    public init(cleared: Int64) {
        self.cleared = cleared
    }
}

public struct M2SearchKeywordKeyParams: Codable, Sendable {
    public let word: String

    public init(word: String) {
        self.word = word
    }
}

public struct M2SearchKeywordDeleteData: Codable, Sendable {
    public let word: String
    public let deleted: Bool

    public init(word: String, deleted: Bool) {
        self.word = word
        self.deleted = deleted
    }
}

public struct M2ReadingPreparationParams: Codable, Sendable {
    public let action: M2ReadingPreparationParamsAction
    public let sourceId: String?
    public let bookId: String?
    public let reason: M2ReadingPreparationParamsReason?
    public let revision: Int64?
    public let blockReason: String?
    public let pendingAdd: [String: ReaderM1JSONValue]?
    public let offset: Int64?
    public let limit: Int64?

    public init(action: M2ReadingPreparationParamsAction, sourceId: String? = nil, bookId: String? = nil, reason: M2ReadingPreparationParamsReason? = nil, revision: Int64? = nil, blockReason: String? = nil, pendingAdd: [String: ReaderM1JSONValue]? = nil, offset: Int64? = nil, limit: Int64? = nil) {
        self.action = action
        self.sourceId = sourceId
        self.bookId = bookId
        self.reason = reason
        self.revision = revision
        self.blockReason = blockReason
        self.pendingAdd = pendingAdd
        self.offset = offset
        self.limit = limit
    }
}

/// Wire values of M2ReadingPreparationParamsAction.
public enum M2ReadingPreparationParamsAction: String, Codable, Sendable, CaseIterable {
    case begin = "begin"
    case list = "list"
    case status = "status"
    case pause = "pause"
    case resume = "resume"
    case cancel = "cancel"
    case block = "block"
}

/// Wire values of M2ReadingPreparationParamsReason.
public enum M2ReadingPreparationParamsReason: String, Codable, Sendable, CaseIterable {
    case add = "add"
    case read = "read"
    case download = "download"
}

public struct M2ReadingPreparationData: Codable, Sendable {
    public let intents: [M2ReadingPreparationIntent]
    public let total: Int64?
    public let issues: [M2ReadingPreparationIssue]?

    public init(intents: [M2ReadingPreparationIntent], total: Int64? = nil, issues: [M2ReadingPreparationIssue]? = nil) {
        self.intents = intents
        self.total = total
        self.issues = issues
    }
}

public struct M2ReadingPreparationIntent: Codable, Sendable {
    public let schemaVersion: Int64
    public let sourceId: String
    public let bookId: String
    public let revision: Int64
    public let sourceVersion: String
    public let reason: String
    public let state: String
    public let updatedAt: Int64
    public let blockReason: String?
    public let pendingAdd: M2BookshelfAddParams?
    public let entryChapterIndex: Int64?

    public init(schemaVersion: Int64, sourceId: String, bookId: String, revision: Int64, sourceVersion: String, reason: String, state: String, updatedAt: Int64, blockReason: String? = nil, pendingAdd: M2BookshelfAddParams? = nil, entryChapterIndex: Int64? = nil) {
        self.schemaVersion = schemaVersion
        self.sourceId = sourceId
        self.bookId = bookId
        self.revision = revision
        self.sourceVersion = sourceVersion
        self.reason = reason
        self.state = state
        self.updatedAt = updatedAt
        self.blockReason = blockReason
        self.pendingAdd = pendingAdd
        self.entryChapterIndex = entryChapterIndex
    }
}

public struct M2BookshelfAddParams: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let title: String
    public let author: String
    public let coverUrl: String?
    public let intro: String?
    public let kind: String?
    public let lastChapter: String?
    public let group: String?
    public let sortIndex: Int64?
    public let mangaFirstImage: M2MangaFirstImageReceipt?
    public let preparationRevision: Int64?
    public let requireReadable: Bool?

    public init(sourceId: String, bookId: String, title: String, author: String, coverUrl: String? = nil, intro: String? = nil, kind: String? = nil, lastChapter: String? = nil, group: String? = nil, sortIndex: Int64? = nil, mangaFirstImage: M2MangaFirstImageReceipt? = nil, preparationRevision: Int64? = nil, requireReadable: Bool? = nil) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.title = title
        self.author = author
        self.coverUrl = coverUrl
        self.intro = intro
        self.kind = kind
        self.lastChapter = lastChapter
        self.group = group
        self.sortIndex = sortIndex
        self.mangaFirstImage = mangaFirstImage
        self.preparationRevision = preparationRevision
        self.requireReadable = requireReadable
    }
}

public struct M2MangaFirstImageReceipt: Codable, Sendable {
    public let chapter: M2MangaChapterIdentity
    public let chapterIndex: Int64
    public let width: Int64
    public let height: Int64
    public let manifestVersion: String
    public let sourceRuleVersion: String
    public let decodeRevision: String
    public let pageId: String
    public let resourceRef: String
    public let imageRevision: String

    public init(chapter: M2MangaChapterIdentity, chapterIndex: Int64, width: Int64, height: Int64, manifestVersion: String, sourceRuleVersion: String, decodeRevision: String, pageId: String, resourceRef: String, imageRevision: String) {
        self.chapter = chapter
        self.chapterIndex = chapterIndex
        self.width = width
        self.height = height
        self.manifestVersion = manifestVersion
        self.sourceRuleVersion = sourceRuleVersion
        self.decodeRevision = decodeRevision
        self.pageId = pageId
        self.resourceRef = resourceRef
        self.imageRevision = imageRevision
    }
}

public struct M2ReadingPreparationIssue: Codable, Sendable {
    public let sourceId: String?
    public let bookId: String?
    public let reason: String?

    public init(sourceId: String? = nil, bookId: String? = nil, reason: String? = nil) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.reason = reason
    }
}

public struct M2ReadingEntryPrepareParams: Codable, Sendable {
    public let localSourcePath: String?
    public let chapterIndex: Int64?
    public let sourceId: String
    public let bookId: String
    public let neighborOffset: Int64

    public init(localSourcePath: String? = nil, chapterIndex: Int64? = nil, sourceId: String, bookId: String, neighborOffset: Int64) {
        self.localSourcePath = localSourcePath
        self.chapterIndex = chapterIndex
        self.sourceId = sourceId
        self.bookId = bookId
        self.neighborOffset = neighborOffset
    }
}

public struct M2ReadingEntryPrepareData: Codable, Sendable {
    public let kind: String
    public let reason: String
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: Int64?
    public let imagePresentationChanged: Bool?
    public let pendingRestore: M2LocalPositionPendingRestoreData?

    public init(kind: String, reason: String, sourceId: String, bookId: String, chapterIndex: Int64?, imagePresentationChanged: Bool? = nil, pendingRestore: M2LocalPositionPendingRestoreData? = nil) {
        self.kind = kind
        self.reason = reason
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterIndex = chapterIndex
        self.imagePresentationChanged = imagePresentationChanged
        self.pendingRestore = pendingRestore
    }

    private enum CodingKeys: String, CodingKey {
        case kind = "kind"
        case reason = "reason"
        case sourceId = "sourceId"
        case bookId = "bookId"
        case chapterIndex = "chapterIndex"
        case imagePresentationChanged = "imagePresentationChanged"
        case pendingRestore = "pendingRestore"
    }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        kind = try fields.decode(String.self, forKey: .kind)
        reason = try fields.decode(String.self, forKey: .reason)
        sourceId = try fields.decode(String.self, forKey: .sourceId)
        bookId = try fields.decode(String.self, forKey: .bookId)
        chapterIndex = try fields.decode(Int64?.self, forKey: .chapterIndex)
        imagePresentationChanged = try fields.decodeIfPresent(Bool.self, forKey: .imagePresentationChanged)
        pendingRestore = try fields.decodeIfPresent(M2LocalPositionPendingRestoreData.self, forKey: .pendingRestore)
    }

    public func encode(to encoder: any Encoder) throws {
        var fields = encoder.container(keyedBy: CodingKeys.self)
        try fields.encode(kind, forKey: .kind)
        try fields.encode(reason, forKey: .reason)
        try fields.encode(sourceId, forKey: .sourceId)
        try fields.encode(bookId, forKey: .bookId)
        try fields.encode(chapterIndex, forKey: .chapterIndex)
        try fields.encodeIfPresent(imagePresentationChanged, forKey: .imagePresentationChanged)
        try fields.encodeIfPresent(pendingRestore, forKey: .pendingRestore)
    }
}

public struct M2LocalPositionPendingRestoreData: Codable, Sendable {
    public let archiveIds: [String]
    public let progressEntries: Int64
    public let legacyProgressEntries: Int64
    public let historyEntries: Int64
    public let bookmarkEntries: Int64
    public let highlightEntries: Int64
    public let currentProgressUnverified: Bool

    public init(archiveIds: [String], progressEntries: Int64, legacyProgressEntries: Int64, historyEntries: Int64, bookmarkEntries: Int64, highlightEntries: Int64, currentProgressUnverified: Bool) {
        self.archiveIds = archiveIds
        self.progressEntries = progressEntries
        self.legacyProgressEntries = legacyProgressEntries
        self.historyEntries = historyEntries
        self.bookmarkEntries = bookmarkEntries
        self.highlightEntries = highlightEntries
        self.currentProgressUnverified = currentProgressUnverified
    }
}

public struct M2RulesMutationApplyParams: Codable, Sendable {
    public let operationId: String
    public let sequence: Int64
    public let mutation: M2RulesMutation

    public init(operationId: String, sequence: Int64, mutation: M2RulesMutation) {
        self.operationId = operationId
        self.sequence = sequence
        self.mutation = mutation
    }
}

public enum M2RulesMutation: Codable, Sendable {
    case ruleSubPut(M2RulesMutationRuleSubPut)
    case ruleSubDelete(M2RulesMutationRuleSubDelete)
    case sourceImport(M2RulesMutationSourceImport)
    case sourceUpdate(M2RulesMutationSourceUpdate)
    case sourceDelete(M2RulesMutationSourceDelete)
    case ruleSubUpdateApplyV1(M2RulesMutationRuleSubUpdateApplyV1)
    case sourceGroupMutate(M2RulesMutationSourceGroupMutate)
    case sourceImportGrouped(M2RulesMutationSourceImportGrouped)

    private enum CodingKeys: String, CodingKey { case method }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        let tag = fields.contains(.method) ? try fields.decode(String.self, forKey: .method) : nil
        switch tag {
        case "rule-sub.put": self = .ruleSubPut(try M2RulesMutationRuleSubPut(from: decoder))
        case "rule-sub.delete": self = .ruleSubDelete(try M2RulesMutationRuleSubDelete(from: decoder))
        case "source.import": self = .sourceImport(try M2RulesMutationSourceImport(from: decoder))
        case "source.update": self = .sourceUpdate(try M2RulesMutationSourceUpdate(from: decoder))
        case "source.delete": self = .sourceDelete(try M2RulesMutationSourceDelete(from: decoder))
        case "rule-sub.update.apply.v1": self = .ruleSubUpdateApplyV1(try M2RulesMutationRuleSubUpdateApplyV1(from: decoder))
        case "source.group.mutate": self = .sourceGroupMutate(try M2RulesMutationSourceGroupMutate(from: decoder))
        case "source.import.grouped": self = .sourceImportGrouped(try M2RulesMutationSourceImportGrouped(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .method, in: fields, debugDescription: "Unknown M2RulesMutation tag")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .ruleSubPut(let value): try value.encode(to: encoder)
        case .ruleSubDelete(let value): try value.encode(to: encoder)
        case .sourceImport(let value): try value.encode(to: encoder)
        case .sourceUpdate(let value): try value.encode(to: encoder)
        case .sourceDelete(let value): try value.encode(to: encoder)
        case .ruleSubUpdateApplyV1(let value): try value.encode(to: encoder)
        case .sourceGroupMutate(let value): try value.encode(to: encoder)
        case .sourceImportGrouped(let value): try value.encode(to: encoder)
        }
    }
}

public struct M2RulesMutationRuleSubPut: Codable, Sendable {
    public let method: M2RulesMutationRuleSubPutMethod
    public let params: M2RuleSubPutParams

    public init(method: M2RulesMutationRuleSubPutMethod = .ruleSubPut, params: M2RuleSubPutParams) {
        self.method = method
        self.params = params
    }
}

/// Wire values of M2RulesMutationRuleSubPutMethod.
public enum M2RulesMutationRuleSubPutMethod: String, Codable, Sendable, CaseIterable {
    case ruleSubPut = "rule-sub.put"
}

public struct M2RulesMutationRuleSubDelete: Codable, Sendable {
    public let method: M2RulesMutationRuleSubDeleteMethod
    public let params: M2RuleSubKeyParams

    public init(method: M2RulesMutationRuleSubDeleteMethod = .ruleSubDelete, params: M2RuleSubKeyParams) {
        self.method = method
        self.params = params
    }
}

/// Wire values of M2RulesMutationRuleSubDeleteMethod.
public enum M2RulesMutationRuleSubDeleteMethod: String, Codable, Sendable, CaseIterable {
    case ruleSubDelete = "rule-sub.delete"
}

public struct M2RulesMutationSourceImport: Codable, Sendable {
    public let method: M2RulesMutationSourceImportMethod
    public let params: M2SourceImportParams

    public init(method: M2RulesMutationSourceImportMethod = .sourceImport, params: M2SourceImportParams) {
        self.method = method
        self.params = params
    }
}

/// Wire values of M2RulesMutationSourceImportMethod.
public enum M2RulesMutationSourceImportMethod: String, Codable, Sendable, CaseIterable {
    case sourceImport = "source.import"
}

public struct M2RulesMutationSourceUpdate: Codable, Sendable {
    public let method: M2RulesMutationSourceUpdateMethod
    public let params: M2SourceUpdateParams

    public init(method: M2RulesMutationSourceUpdateMethod = .sourceUpdate, params: M2SourceUpdateParams) {
        self.method = method
        self.params = params
    }
}

/// Wire values of M2RulesMutationSourceUpdateMethod.
public enum M2RulesMutationSourceUpdateMethod: String, Codable, Sendable, CaseIterable {
    case sourceUpdate = "source.update"
}

public struct M2RulesMutationSourceDelete: Codable, Sendable {
    public let method: M2RulesMutationSourceDeleteMethod
    public let params: M2SourceDeleteParams

    public init(method: M2RulesMutationSourceDeleteMethod = .sourceDelete, params: M2SourceDeleteParams) {
        self.method = method
        self.params = params
    }
}

/// Wire values of M2RulesMutationSourceDeleteMethod.
public enum M2RulesMutationSourceDeleteMethod: String, Codable, Sendable, CaseIterable {
    case sourceDelete = "source.delete"
}

public struct M2RulesMutationRuleSubUpdateApplyV1: Codable, Sendable {
    public let method: M2RulesMutationRuleSubUpdateApplyV1Method
    public let params: M2RuleSubUpdateApplyParams

    public init(method: M2RulesMutationRuleSubUpdateApplyV1Method = .ruleSubUpdateApplyV1, params: M2RuleSubUpdateApplyParams) {
        self.method = method
        self.params = params
    }
}

/// Wire values of M2RulesMutationRuleSubUpdateApplyV1Method.
public enum M2RulesMutationRuleSubUpdateApplyV1Method: String, Codable, Sendable, CaseIterable {
    case ruleSubUpdateApplyV1 = "rule-sub.update.apply.v1"
}

public struct M2RuleSubUpdateApplyParams: Codable, Sendable {
    public let planId: String
    public let sourceIds: [String]

    public init(planId: String, sourceIds: [String]) {
        self.planId = planId
        self.sourceIds = sourceIds
    }
}

public struct M2RulesMutationSourceGroupMutate: Codable, Sendable {
    public let method: M2RulesMutationSourceGroupMutateMethod
    public let params: M2SourceGroupMutateParams

    public init(method: M2RulesMutationSourceGroupMutateMethod = .sourceGroupMutate, params: M2SourceGroupMutateParams) {
        self.method = method
        self.params = params
    }
}

/// Wire values of M2RulesMutationSourceGroupMutateMethod.
public enum M2RulesMutationSourceGroupMutateMethod: String, Codable, Sendable, CaseIterable {
    case sourceGroupMutate = "source.group.mutate"
}

public struct M2SourceGroupMutateParams: Codable, Sendable {
    public let expectedRevision: Int64
    public let action: M2SourceGroupMutateParamsAction
    public let groupId: String?
    public let name: String?
    public let targetGroupId: String?
    public let sourceIds: [String]?

    public init(expectedRevision: Int64, action: M2SourceGroupMutateParamsAction, groupId: String? = nil, name: String? = nil, targetGroupId: String? = nil, sourceIds: [String]? = nil) {
        self.expectedRevision = expectedRevision
        self.action = action
        self.groupId = groupId
        self.name = name
        self.targetGroupId = targetGroupId
        self.sourceIds = sourceIds
    }
}

/// Wire values of M2SourceGroupMutateParamsAction.
public enum M2SourceGroupMutateParamsAction: String, Codable, Sendable, CaseIterable {
    case create = "create"
    case rename = "rename"
    case delete = "delete"
    case assign = "assign"
}

public struct M2RulesMutationSourceImportGrouped: Codable, Sendable {
    public let method: M2RulesMutationSourceImportGroupedMethod
    public let params: M2SourceGroupedImportParams

    public init(method: M2RulesMutationSourceImportGroupedMethod = .sourceImportGrouped, params: M2SourceGroupedImportParams) {
        self.method = method
        self.params = params
    }
}

/// Wire values of M2RulesMutationSourceImportGroupedMethod.
public enum M2RulesMutationSourceImportGroupedMethod: String, Codable, Sendable, CaseIterable {
    case sourceImportGrouped = "source.import.grouped"
}

public struct M2SourceGroupedImportParams: Codable, Sendable {
    public let expectedRevision: Int64
    public let strategy: M2SourceGroupedImportParamsStrategy
    public let targetGroupId: String?
    public let targetGroupName: String?
    public let items: [M2SourceImportParams]

    public init(expectedRevision: Int64, strategy: M2SourceGroupedImportParamsStrategy, targetGroupId: String? = nil, targetGroupName: String? = nil, items: [M2SourceImportParams]) {
        self.expectedRevision = expectedRevision
        self.strategy = strategy
        self.targetGroupId = targetGroupId
        self.targetGroupName = targetGroupName
        self.items = items
    }
}

/// Wire values of M2SourceGroupedImportParamsStrategy.
public enum M2SourceGroupedImportParamsStrategy: String, Codable, Sendable, CaseIterable {
    case preserve = "preserve"
    case fill = "fill"
    case all = "all"
}

public enum M2RulesMutationReceipt: Codable, Sendable {
    case sourceImport(M2RulesMutationReceiptSourceImport)
    case sourceUpdate(M2RulesMutationReceiptSourceUpdate)
    case sourceDelete(M2RulesMutationReceiptSourceDelete)
    case sourceGroupMutate(M2RulesMutationReceiptSourceGroupMutate)
    case sourceImportGrouped(M2RulesMutationReceiptSourceImportGrouped)
    case ruleSubPut(M2RulesMutationReceiptRuleSubPut)
    case ruleSubDelete(M2RulesMutationReceiptRuleSubDelete)
    case ruleSubUpdateApplyV1(M2RulesMutationReceiptRuleSubUpdateApplyV1)
    case rejected(M2RulesMutationReceiptRejected)

    private enum CodingKeys: String, CodingKey { case method, outcome }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        let method = try fields.decodeIfPresent(String.self, forKey: .method)
        let outcome = try fields.decodeIfPresent(String.self, forKey: .outcome)
        let matches = [
            method == "source.import" && outcome == "applied",
            method == "source.update" && outcome == "applied",
            method == "source.delete" && outcome == "applied",
            method == "source.group.mutate" && outcome == "applied",
            method == "source.import.grouped" && outcome == "applied",
            method == "rule-sub.put" && outcome == "applied",
            method == "rule-sub.delete" && outcome == "applied",
            method == "rule-sub.update.apply.v1" && outcome == "applied",
            outcome == "rejected",
        ]
        guard matches.filter({ $0 }).count == 1, let index = matches.firstIndex(of: true) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown or ambiguous M2RulesMutationReceipt variant"))
        }
        switch index {
        case 0: self = .sourceImport(try M2RulesMutationReceiptSourceImport(from: decoder))
        case 1: self = .sourceUpdate(try M2RulesMutationReceiptSourceUpdate(from: decoder))
        case 2: self = .sourceDelete(try M2RulesMutationReceiptSourceDelete(from: decoder))
        case 3: self = .sourceGroupMutate(try M2RulesMutationReceiptSourceGroupMutate(from: decoder))
        case 4: self = .sourceImportGrouped(try M2RulesMutationReceiptSourceImportGrouped(from: decoder))
        case 5: self = .ruleSubPut(try M2RulesMutationReceiptRuleSubPut(from: decoder))
        case 6: self = .ruleSubDelete(try M2RulesMutationReceiptRuleSubDelete(from: decoder))
        case 7: self = .ruleSubUpdateApplyV1(try M2RulesMutationReceiptRuleSubUpdateApplyV1(from: decoder))
        case 8: self = .rejected(try M2RulesMutationReceiptRejected(from: decoder))
        default:
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown M2RulesMutationReceipt variant index"))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .sourceImport(let value): try value.encode(to: encoder)
        case .sourceUpdate(let value): try value.encode(to: encoder)
        case .sourceDelete(let value): try value.encode(to: encoder)
        case .sourceGroupMutate(let value): try value.encode(to: encoder)
        case .sourceImportGrouped(let value): try value.encode(to: encoder)
        case .ruleSubPut(let value): try value.encode(to: encoder)
        case .ruleSubDelete(let value): try value.encode(to: encoder)
        case .ruleSubUpdateApplyV1(let value): try value.encode(to: encoder)
        case .rejected(let value): try value.encode(to: encoder)
        }
    }
}

public struct M2RulesMutationReceiptSourceImport: Codable, Sendable {
    public let binding: M2RulesMutationBinding
    public let ackFingerprint: String
    public let method: M2RulesMutationReceiptSourceImportMethod
    public let outcome: M2RulesMutationReceiptSourceImportOutcome
    public let data: M2SourceImportData

    public init(binding: M2RulesMutationBinding, ackFingerprint: String, method: M2RulesMutationReceiptSourceImportMethod = .sourceImport, outcome: M2RulesMutationReceiptSourceImportOutcome = .applied, data: M2SourceImportData) {
        self.binding = binding
        self.ackFingerprint = ackFingerprint
        self.method = method
        self.outcome = outcome
        self.data = data
    }
}

public struct M2RulesMutationBinding: Codable, Sendable {
    public let operationId: String
    public let sequence: Int64
    public let payloadFingerprint: String

    public init(operationId: String, sequence: Int64, payloadFingerprint: String) {
        self.operationId = operationId
        self.sequence = sequence
        self.payloadFingerprint = payloadFingerprint
    }
}

/// Wire values of M2RulesMutationReceiptSourceImportMethod.
public enum M2RulesMutationReceiptSourceImportMethod: String, Codable, Sendable, CaseIterable {
    case sourceImport = "source.import"
}

/// Wire values of M2RulesMutationReceiptSourceImportOutcome.
public enum M2RulesMutationReceiptSourceImportOutcome: String, Codable, Sendable, CaseIterable {
    case applied = "applied"
}

public struct M2RulesMutationReceiptSourceUpdate: Codable, Sendable {
    public let binding: M2RulesMutationBinding
    public let ackFingerprint: String
    public let method: M2RulesMutationReceiptSourceUpdateMethod
    public let outcome: M2RulesMutationReceiptSourceUpdateOutcome
    public let data: M2SourceUpdateData

    public init(binding: M2RulesMutationBinding, ackFingerprint: String, method: M2RulesMutationReceiptSourceUpdateMethod = .sourceUpdate, outcome: M2RulesMutationReceiptSourceUpdateOutcome = .applied, data: M2SourceUpdateData) {
        self.binding = binding
        self.ackFingerprint = ackFingerprint
        self.method = method
        self.outcome = outcome
        self.data = data
    }
}

/// Wire values of M2RulesMutationReceiptSourceUpdateMethod.
public enum M2RulesMutationReceiptSourceUpdateMethod: String, Codable, Sendable, CaseIterable {
    case sourceUpdate = "source.update"
}

/// Wire values of M2RulesMutationReceiptSourceUpdateOutcome.
public enum M2RulesMutationReceiptSourceUpdateOutcome: String, Codable, Sendable, CaseIterable {
    case applied = "applied"
}

public struct M2RulesMutationReceiptSourceDelete: Codable, Sendable {
    public let binding: M2RulesMutationBinding
    public let ackFingerprint: String
    public let method: M2RulesMutationReceiptSourceDeleteMethod
    public let outcome: M2RulesMutationReceiptSourceDeleteOutcome
    public let data: M2SourceDeleteData

    public init(binding: M2RulesMutationBinding, ackFingerprint: String, method: M2RulesMutationReceiptSourceDeleteMethod = .sourceDelete, outcome: M2RulesMutationReceiptSourceDeleteOutcome = .applied, data: M2SourceDeleteData) {
        self.binding = binding
        self.ackFingerprint = ackFingerprint
        self.method = method
        self.outcome = outcome
        self.data = data
    }
}

/// Wire values of M2RulesMutationReceiptSourceDeleteMethod.
public enum M2RulesMutationReceiptSourceDeleteMethod: String, Codable, Sendable, CaseIterable {
    case sourceDelete = "source.delete"
}

/// Wire values of M2RulesMutationReceiptSourceDeleteOutcome.
public enum M2RulesMutationReceiptSourceDeleteOutcome: String, Codable, Sendable, CaseIterable {
    case applied = "applied"
}

public struct M2RulesMutationReceiptSourceGroupMutate: Codable, Sendable {
    public let binding: M2RulesMutationBinding
    public let ackFingerprint: String
    public let method: M2RulesMutationReceiptSourceGroupMutateMethod
    public let outcome: M2RulesMutationReceiptSourceGroupMutateOutcome
    public let data: M2SourceGroupMutateData

    public init(binding: M2RulesMutationBinding, ackFingerprint: String, method: M2RulesMutationReceiptSourceGroupMutateMethod = .sourceGroupMutate, outcome: M2RulesMutationReceiptSourceGroupMutateOutcome = .applied, data: M2SourceGroupMutateData) {
        self.binding = binding
        self.ackFingerprint = ackFingerprint
        self.method = method
        self.outcome = outcome
        self.data = data
    }
}

/// Wire values of M2RulesMutationReceiptSourceGroupMutateMethod.
public enum M2RulesMutationReceiptSourceGroupMutateMethod: String, Codable, Sendable, CaseIterable {
    case sourceGroupMutate = "source.group.mutate"
}

/// Wire values of M2RulesMutationReceiptSourceGroupMutateOutcome.
public enum M2RulesMutationReceiptSourceGroupMutateOutcome: String, Codable, Sendable, CaseIterable {
    case applied = "applied"
}

public struct M2SourceGroupMutateData: Codable, Sendable {
    public let version: M2SourceGroupMutateDataVersion
    public let revision: Int64
    public let action: M2SourceGroupMutateDataAction
    public let groupId: String
    public let affectedSourceIds: [String]

    public init(version: M2SourceGroupMutateDataVersion = .v1, revision: Int64, action: M2SourceGroupMutateDataAction, groupId: String, affectedSourceIds: [String]) {
        self.version = version
        self.revision = revision
        self.action = action
        self.groupId = groupId
        self.affectedSourceIds = affectedSourceIds
    }
}

public enum M2SourceGroupMutateDataVersion: Int64, Codable, Sendable, CaseIterable {
    case v1 = 1
}

/// Wire values of M2SourceGroupMutateDataAction.
public enum M2SourceGroupMutateDataAction: String, Codable, Sendable, CaseIterable {
    case create = "create"
    case rename = "rename"
    case delete = "delete"
    case assign = "assign"
}

public struct M2RulesMutationReceiptSourceImportGrouped: Codable, Sendable {
    public let binding: M2RulesMutationBinding
    public let ackFingerprint: String
    public let method: M2RulesMutationReceiptSourceImportGroupedMethod
    public let outcome: M2RulesMutationReceiptSourceImportGroupedOutcome
    public let data: M2SourceGroupedImportData

    public init(binding: M2RulesMutationBinding, ackFingerprint: String, method: M2RulesMutationReceiptSourceImportGroupedMethod = .sourceImportGrouped, outcome: M2RulesMutationReceiptSourceImportGroupedOutcome = .applied, data: M2SourceGroupedImportData) {
        self.binding = binding
        self.ackFingerprint = ackFingerprint
        self.method = method
        self.outcome = outcome
        self.data = data
    }
}

/// Wire values of M2RulesMutationReceiptSourceImportGroupedMethod.
public enum M2RulesMutationReceiptSourceImportGroupedMethod: String, Codable, Sendable, CaseIterable {
    case sourceImportGrouped = "source.import.grouped"
}

/// Wire values of M2RulesMutationReceiptSourceImportGroupedOutcome.
public enum M2RulesMutationReceiptSourceImportGroupedOutcome: String, Codable, Sendable, CaseIterable {
    case applied = "applied"
}

public struct M2SourceGroupedImportData: Codable, Sendable {
    public let version: M2SourceGroupedImportDataVersion
    public let revision: Int64
    public let importedCount: Int64
    public let failedCount: Int64
    public let results: [M2SourceGroupedImportResult]

    public init(version: M2SourceGroupedImportDataVersion = .v1, revision: Int64, importedCount: Int64, failedCount: Int64, results: [M2SourceGroupedImportResult]) {
        self.version = version
        self.revision = revision
        self.importedCount = importedCount
        self.failedCount = failedCount
        self.results = results
    }
}

public enum M2SourceGroupedImportDataVersion: Int64, Codable, Sendable, CaseIterable {
    case v1 = 1
}

public struct M2SourceGroupedImportResult: Codable, Sendable {
    public let index: Int64
    public let sourceId: String
    public let status: M2SourceGroupedImportResultStatus
    public let name: String?
    public let groupId: String?
    public let locallyAssigned: Bool?
    public let error: String?

    public init(index: Int64, sourceId: String, status: M2SourceGroupedImportResultStatus, name: String? = nil, groupId: String? = nil, locallyAssigned: Bool? = nil, error: String? = nil) {
        self.index = index
        self.sourceId = sourceId
        self.status = status
        self.name = name
        self.groupId = groupId
        self.locallyAssigned = locallyAssigned
        self.error = error
    }
}

/// Wire values of M2SourceGroupedImportResultStatus.
public enum M2SourceGroupedImportResultStatus: String, Codable, Sendable, CaseIterable {
    case imported = "imported"
    case failed = "failed"
}

public struct M2RulesMutationReceiptRuleSubPut: Codable, Sendable {
    public let binding: M2RulesMutationBinding
    public let ackFingerprint: String
    public let method: M2RulesMutationReceiptRuleSubPutMethod
    public let outcome: M2RulesMutationReceiptRuleSubPutOutcome
    public let data: M2RuleSubPutData

    public init(binding: M2RulesMutationBinding, ackFingerprint: String, method: M2RulesMutationReceiptRuleSubPutMethod = .ruleSubPut, outcome: M2RulesMutationReceiptRuleSubPutOutcome = .applied, data: M2RuleSubPutData) {
        self.binding = binding
        self.ackFingerprint = ackFingerprint
        self.method = method
        self.outcome = outcome
        self.data = data
    }
}

/// Wire values of M2RulesMutationReceiptRuleSubPutMethod.
public enum M2RulesMutationReceiptRuleSubPutMethod: String, Codable, Sendable, CaseIterable {
    case ruleSubPut = "rule-sub.put"
}

/// Wire values of M2RulesMutationReceiptRuleSubPutOutcome.
public enum M2RulesMutationReceiptRuleSubPutOutcome: String, Codable, Sendable, CaseIterable {
    case applied = "applied"
}

public struct M2RulesMutationReceiptRuleSubDelete: Codable, Sendable {
    public let binding: M2RulesMutationBinding
    public let ackFingerprint: String
    public let method: M2RulesMutationReceiptRuleSubDeleteMethod
    public let outcome: M2RulesMutationReceiptRuleSubDeleteOutcome
    public let data: M2RuleSubDeleteData

    public init(binding: M2RulesMutationBinding, ackFingerprint: String, method: M2RulesMutationReceiptRuleSubDeleteMethod = .ruleSubDelete, outcome: M2RulesMutationReceiptRuleSubDeleteOutcome = .applied, data: M2RuleSubDeleteData) {
        self.binding = binding
        self.ackFingerprint = ackFingerprint
        self.method = method
        self.outcome = outcome
        self.data = data
    }
}

/// Wire values of M2RulesMutationReceiptRuleSubDeleteMethod.
public enum M2RulesMutationReceiptRuleSubDeleteMethod: String, Codable, Sendable, CaseIterable {
    case ruleSubDelete = "rule-sub.delete"
}

/// Wire values of M2RulesMutationReceiptRuleSubDeleteOutcome.
public enum M2RulesMutationReceiptRuleSubDeleteOutcome: String, Codable, Sendable, CaseIterable {
    case applied = "applied"
}

public struct M2RulesMutationReceiptRuleSubUpdateApplyV1: Codable, Sendable {
    public let binding: M2RulesMutationBinding
    public let ackFingerprint: String
    public let method: M2RulesMutationReceiptRuleSubUpdateApplyV1Method
    public let outcome: M2RulesMutationReceiptRuleSubUpdateApplyV1Outcome
    public let data: M2RuleSubUpdateApplyData

    public init(binding: M2RulesMutationBinding, ackFingerprint: String, method: M2RulesMutationReceiptRuleSubUpdateApplyV1Method = .ruleSubUpdateApplyV1, outcome: M2RulesMutationReceiptRuleSubUpdateApplyV1Outcome = .applied, data: M2RuleSubUpdateApplyData) {
        self.binding = binding
        self.ackFingerprint = ackFingerprint
        self.method = method
        self.outcome = outcome
        self.data = data
    }
}

/// Wire values of M2RulesMutationReceiptRuleSubUpdateApplyV1Method.
public enum M2RulesMutationReceiptRuleSubUpdateApplyV1Method: String, Codable, Sendable, CaseIterable {
    case ruleSubUpdateApplyV1 = "rule-sub.update.apply.v1"
}

/// Wire values of M2RulesMutationReceiptRuleSubUpdateApplyV1Outcome.
public enum M2RulesMutationReceiptRuleSubUpdateApplyV1Outcome: String, Codable, Sendable, CaseIterable {
    case applied = "applied"
}

public struct M2RuleSubUpdateApplyData: Codable, Sendable {
    public let subscriptionId: Int64
    public let remoteDigest: String
    public let appliedSourceIds: [String]
    public let skippedSourceIds: [String]
    public let updatedAt: Int64

    public init(subscriptionId: Int64, remoteDigest: String, appliedSourceIds: [String], skippedSourceIds: [String], updatedAt: Int64) {
        self.subscriptionId = subscriptionId
        self.remoteDigest = remoteDigest
        self.appliedSourceIds = appliedSourceIds
        self.skippedSourceIds = skippedSourceIds
        self.updatedAt = updatedAt
    }
}

public struct M2RulesMutationReceiptRejected: Codable, Sendable {
    public let binding: M2RulesMutationBinding
    public let ackFingerprint: String
    public let method: M2RulesMutationReceiptRejectedMethod
    public let outcome: M2RulesMutationReceiptRejectedOutcome
    public let data: M2RulesMutationReceiptRejectedData

    public init(binding: M2RulesMutationBinding, ackFingerprint: String, method: M2RulesMutationReceiptRejectedMethod, outcome: M2RulesMutationReceiptRejectedOutcome = .rejected, data: M2RulesMutationReceiptRejectedData) {
        self.binding = binding
        self.ackFingerprint = ackFingerprint
        self.method = method
        self.outcome = outcome
        self.data = data
    }
}

/// Wire values of M2RulesMutationReceiptRejectedMethod.
public enum M2RulesMutationReceiptRejectedMethod: String, Codable, Sendable, CaseIterable {
    case sourceImport = "source.import"
    case sourceUpdate = "source.update"
    case sourceDelete = "source.delete"
    case sourceGroupMutate = "source.group.mutate"
    case sourceImportGrouped = "source.import.grouped"
    case ruleSubPut = "rule-sub.put"
    case ruleSubDelete = "rule-sub.delete"
    case ruleSubUpdateApplyV1 = "rule-sub.update.apply.v1"
}

/// Wire values of M2RulesMutationReceiptRejectedOutcome.
public enum M2RulesMutationReceiptRejectedOutcome: String, Codable, Sendable, CaseIterable {
    case rejected = "rejected"
}

public struct M2RulesMutationReceiptRejectedData: Codable, Sendable {
    public let error: M2ProtocolError

    public init(error: M2ProtocolError) {
        self.error = error
    }
}

public struct M2ProtocolError: Codable, Sendable {
    public let code: ReaderErrorCode
    public let message: String
    public let retryable: Bool
    public let details: M2ProtocolErrorDetails?

    public init(code: ReaderErrorCode, message: String, retryable: Bool, details: M2ProtocolErrorDetails? = nil) {
        self.code = code
        self.message = message
        self.retryable = retryable
        self.details = details
    }
}

public struct M2ProtocolErrorDetails: Codable, Sendable {
    public let reason: String?
    public let category: String?
    public let domain: String?
    public let stage: String?
    public let httpStatus: Int64?
    public let originalPending: Bool?
    public let nonExecution: Bool?
    public let binding: M2ProtocolErrorDetailsBinding?
    public let host: M2ProtocolHostErrorDetails?

    public init(reason: String? = nil, category: String? = nil, domain: String? = nil, stage: String? = nil, httpStatus: Int64? = nil, originalPending: Bool? = nil, nonExecution: Bool? = nil, binding: M2ProtocolErrorDetailsBinding? = nil, host: M2ProtocolHostErrorDetails? = nil) {
        self.reason = reason
        self.category = category
        self.domain = domain
        self.stage = stage
        self.httpStatus = httpStatus
        self.originalPending = originalPending
        self.nonExecution = nonExecution
        self.binding = binding
        self.host = host
    }
}

public struct M2ProtocolErrorDetailsBinding: Codable, Sendable {
    public let operationId: String?
    public let sequence: Int64?
    public let payloadFingerprint: String?

    public init(operationId: String? = nil, sequence: Int64? = nil, payloadFingerprint: String? = nil) {
        self.operationId = operationId
        self.sequence = sequence
        self.payloadFingerprint = payloadFingerprint
    }
}

public struct M2ProtocolHostErrorDetails: Codable, Sendable {
    public let capability: ReaderHostCapability
    public let operationId: Int64?
    public let requestId: Int64?
    public let diagnostics: M2HostErrorDiagnostics?

    public init(capability: ReaderHostCapability, operationId: Int64? = nil, requestId: Int64? = nil, diagnostics: M2HostErrorDiagnostics? = nil) {
        self.capability = capability
        self.operationId = operationId
        self.requestId = requestId
        self.diagnostics = diagnostics
    }
}

public struct M2RulesMutationQueryParams: Codable, Sendable {
    public let operationId: String?
    public let expected: M2RulesMutationApplyParams?

    public init(operationId: String? = nil, expected: M2RulesMutationApplyParams? = nil) {
        self.operationId = operationId
        self.expected = expected
    }
}

public struct M2RulesMutationQueryData: Codable, Sendable {
    public let head: M2RulesMutationBinding?
    public let receipt: M2RulesMutationReceipt?

    public init(head: M2RulesMutationBinding?, receipt: M2RulesMutationReceipt?) {
        self.head = head
        self.receipt = receipt
    }

    private enum CodingKeys: String, CodingKey {
        case head = "head"
        case receipt = "receipt"
    }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        head = try fields.decode(M2RulesMutationBinding?.self, forKey: .head)
        receipt = try fields.decode(M2RulesMutationReceipt?.self, forKey: .receipt)
    }

    public func encode(to encoder: any Encoder) throws {
        var fields = encoder.container(keyedBy: CodingKeys.self)
        try fields.encode(head, forKey: .head)
        try fields.encode(receipt, forKey: .receipt)
    }
}

public struct M2ReadingEntrySnapshotParams: Codable, Sendable {
    public let directoryTargetProof: M2DirectoryTargetProof?
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: Int64?
    public let windowScalarLimit: Int64?
    public let positionContext: M2RemoteContentPositionContext?

    public init(directoryTargetProof: M2DirectoryTargetProof? = nil, sourceId: String, bookId: String, chapterIndex: Int64? = nil, windowScalarLimit: Int64? = nil, positionContext: M2RemoteContentPositionContext? = nil) {
        self.directoryTargetProof = directoryTargetProof
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterIndex = chapterIndex
        self.windowScalarLimit = windowScalarLimit
        self.positionContext = positionContext
    }
}

public enum M2ReadingEntrySnapshotData: Codable, Sendable {
    case missing(M2ReadingEntrySnapshotDataMissing)
    case ready(M2ReadingEntrySnapshotDataReady)

    private enum CodingKeys: String, CodingKey { case kind }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        let tag = fields.contains(.kind) ? try fields.decode(String.self, forKey: .kind) : nil
        switch tag {
        case "missing": self = .missing(try M2ReadingEntrySnapshotDataMissing(from: decoder))
        case "ready": self = .ready(try M2ReadingEntrySnapshotDataReady(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: fields, debugDescription: "Unknown M2ReadingEntrySnapshotData tag")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .missing(let value): try value.encode(to: encoder)
        case .ready(let value): try value.encode(to: encoder)
        }
    }
}

public struct M2ReadingEntrySnapshotDataMissing: Codable, Sendable {
    public let kind: M2ReadingEntrySnapshotDataMissingKind
    public let sourceId: String
    public let bookId: String
    public let reason: String
    public let pendingRestore: M2LocalPositionPendingRestoreData?

    public init(kind: M2ReadingEntrySnapshotDataMissingKind = .missing, sourceId: String, bookId: String, reason: String, pendingRestore: M2LocalPositionPendingRestoreData? = nil) {
        self.kind = kind
        self.sourceId = sourceId
        self.bookId = bookId
        self.reason = reason
        self.pendingRestore = pendingRestore
    }
}

/// Wire values of M2ReadingEntrySnapshotDataMissingKind.
public enum M2ReadingEntrySnapshotDataMissingKind: String, Codable, Sendable, CaseIterable {
    case missing = "missing"
}

public struct M2ReadingEntrySnapshotDataReady: Codable, Sendable {
    public let kind: M2ReadingEntrySnapshotDataReadyKind
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: Int64
    public let chapterTitle: String
    public let resumeOnly: Bool?
    public let content: String
    public let blocks: [M2ReadingDocumentBlockData]
    public let positionScope: M2RemoteContentPositionScope
    public let progress: M2ReadingProgressData?
    public let pendingRestore: M2LocalPositionPendingRestoreData?
    public let navigation: M2ReadingNavigation?
    public let baseUrl: String?
    public let contentFormatVersion: Int64
    public let contentRefreshRequired: Bool
    public let sourceCorrectionRequired: Bool
    public let imagePresentationVersion: String?
    public let documentWindow: M2ReadingEntryWindow?

    public init(kind: M2ReadingEntrySnapshotDataReadyKind = .ready, sourceId: String, bookId: String, chapterIndex: Int64, chapterTitle: String, resumeOnly: Bool? = nil, content: String, blocks: [M2ReadingDocumentBlockData], positionScope: M2RemoteContentPositionScope, progress: M2ReadingProgressData?, pendingRestore: M2LocalPositionPendingRestoreData?, navigation: M2ReadingNavigation?, baseUrl: String?, contentFormatVersion: Int64, contentRefreshRequired: Bool, sourceCorrectionRequired: Bool, imagePresentationVersion: String? = nil, documentWindow: M2ReadingEntryWindow?) {
        self.kind = kind
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterIndex = chapterIndex
        self.chapterTitle = chapterTitle
        self.resumeOnly = resumeOnly
        self.content = content
        self.blocks = blocks
        self.positionScope = positionScope
        self.progress = progress
        self.pendingRestore = pendingRestore
        self.navigation = navigation
        self.baseUrl = baseUrl
        self.contentFormatVersion = contentFormatVersion
        self.contentRefreshRequired = contentRefreshRequired
        self.sourceCorrectionRequired = sourceCorrectionRequired
        self.imagePresentationVersion = imagePresentationVersion
        self.documentWindow = documentWindow
    }

    private enum CodingKeys: String, CodingKey {
        case kind = "kind"
        case sourceId = "sourceId"
        case bookId = "bookId"
        case chapterIndex = "chapterIndex"
        case chapterTitle = "chapterTitle"
        case resumeOnly = "resumeOnly"
        case content = "content"
        case blocks = "blocks"
        case positionScope = "positionScope"
        case progress = "progress"
        case pendingRestore = "pendingRestore"
        case navigation = "navigation"
        case baseUrl = "baseUrl"
        case contentFormatVersion = "contentFormatVersion"
        case contentRefreshRequired = "contentRefreshRequired"
        case sourceCorrectionRequired = "sourceCorrectionRequired"
        case imagePresentationVersion = "imagePresentationVersion"
        case documentWindow = "documentWindow"
    }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        kind = try fields.decode(M2ReadingEntrySnapshotDataReadyKind.self, forKey: .kind)
        sourceId = try fields.decode(String.self, forKey: .sourceId)
        bookId = try fields.decode(String.self, forKey: .bookId)
        chapterIndex = try fields.decode(Int64.self, forKey: .chapterIndex)
        chapterTitle = try fields.decode(String.self, forKey: .chapterTitle)
        resumeOnly = try fields.decodeIfPresent(Bool.self, forKey: .resumeOnly)
        content = try fields.decode(String.self, forKey: .content)
        blocks = try fields.decode([M2ReadingDocumentBlockData].self, forKey: .blocks)
        positionScope = try fields.decode(M2RemoteContentPositionScope.self, forKey: .positionScope)
        progress = try fields.decode(M2ReadingProgressData?.self, forKey: .progress)
        pendingRestore = try fields.decode(M2LocalPositionPendingRestoreData?.self, forKey: .pendingRestore)
        navigation = try fields.decode(M2ReadingNavigation?.self, forKey: .navigation)
        baseUrl = try fields.decode(String?.self, forKey: .baseUrl)
        contentFormatVersion = try fields.decode(Int64.self, forKey: .contentFormatVersion)
        contentRefreshRequired = try fields.decode(Bool.self, forKey: .contentRefreshRequired)
        sourceCorrectionRequired = try fields.decode(Bool.self, forKey: .sourceCorrectionRequired)
        imagePresentationVersion = try fields.decodeIfPresent(String.self, forKey: .imagePresentationVersion)
        documentWindow = try fields.decode(M2ReadingEntryWindow?.self, forKey: .documentWindow)
    }

    public func encode(to encoder: any Encoder) throws {
        var fields = encoder.container(keyedBy: CodingKeys.self)
        try fields.encode(kind, forKey: .kind)
        try fields.encode(sourceId, forKey: .sourceId)
        try fields.encode(bookId, forKey: .bookId)
        try fields.encode(chapterIndex, forKey: .chapterIndex)
        try fields.encode(chapterTitle, forKey: .chapterTitle)
        try fields.encodeIfPresent(resumeOnly, forKey: .resumeOnly)
        try fields.encode(content, forKey: .content)
        try fields.encode(blocks, forKey: .blocks)
        try fields.encode(positionScope, forKey: .positionScope)
        try fields.encode(progress, forKey: .progress)
        try fields.encode(pendingRestore, forKey: .pendingRestore)
        try fields.encode(navigation, forKey: .navigation)
        try fields.encode(baseUrl, forKey: .baseUrl)
        try fields.encode(contentFormatVersion, forKey: .contentFormatVersion)
        try fields.encode(contentRefreshRequired, forKey: .contentRefreshRequired)
        try fields.encode(sourceCorrectionRequired, forKey: .sourceCorrectionRequired)
        try fields.encodeIfPresent(imagePresentationVersion, forKey: .imagePresentationVersion)
        try fields.encode(documentWindow, forKey: .documentWindow)
    }
}

/// Wire values of M2ReadingEntrySnapshotDataReadyKind.
public enum M2ReadingEntrySnapshotDataReadyKind: String, Codable, Sendable, CaseIterable {
    case ready = "ready"
}

public struct M2ReadingNavigation: Codable, Sendable {
    public let revision: String
    public let chapterCount: Int64
    public let readableChapterCount: Int64
    public let current: M2ReadingCatalogChapter
    public let before: [M2ReadingCatalogChapter]
    public let after: [M2ReadingCatalogChapter]

    public init(revision: String, chapterCount: Int64, readableChapterCount: Int64, current: M2ReadingCatalogChapter, before: [M2ReadingCatalogChapter], after: [M2ReadingCatalogChapter]) {
        self.revision = revision
        self.chapterCount = chapterCount
        self.readableChapterCount = readableChapterCount
        self.current = current
        self.before = before
        self.after = after
    }
}

public struct M2ReadingCatalogChapter: Codable, Sendable {
    public let index: Int64
    public let position: Int64
    public let readablePosition: Int64?
    public let title: String
    public let navigable: Bool
    public let level: Int64?

    public init(index: Int64, position: Int64, readablePosition: Int64?, title: String, navigable: Bool, level: Int64? = nil) {
        self.index = index
        self.position = position
        self.readablePosition = readablePosition
        self.title = title
        self.navigable = navigable
        self.level = level
    }

    private enum CodingKeys: String, CodingKey {
        case index = "index"
        case position = "position"
        case readablePosition = "readablePosition"
        case title = "title"
        case navigable = "navigable"
        case level = "level"
    }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        index = try fields.decode(Int64.self, forKey: .index)
        position = try fields.decode(Int64.self, forKey: .position)
        readablePosition = try fields.decode(Int64?.self, forKey: .readablePosition)
        title = try fields.decode(String.self, forKey: .title)
        navigable = try fields.decode(Bool.self, forKey: .navigable)
        level = try fields.decodeIfPresent(Int64.self, forKey: .level)
    }

    public func encode(to encoder: any Encoder) throws {
        var fields = encoder.container(keyedBy: CodingKeys.self)
        try fields.encode(index, forKey: .index)
        try fields.encode(position, forKey: .position)
        try fields.encode(readablePosition, forKey: .readablePosition)
        try fields.encode(title, forKey: .title)
        try fields.encode(navigable, forKey: .navigable)
        try fields.encodeIfPresent(level, forKey: .level)
    }
}

public struct M2ReadingEntryWindow: Codable, Sendable {
    public let startScalar: Int64
    public let endScalar: Int64
    public let totalScalars: Int64
    public let requestedScalar: Int64

    public init(startScalar: Int64, endScalar: Int64, totalScalars: Int64, requestedScalar: Int64) {
        self.startScalar = startScalar
        self.endScalar = endScalar
        self.totalScalars = totalScalars
        self.requestedScalar = requestedScalar
    }
}

public struct M2ReadingCatalogPageParams: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let offset: Int64?
    public let limit: Int64
    public let revision: String?

    public init(sourceId: String, bookId: String, offset: Int64? = nil, limit: Int64, revision: String? = nil) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.offset = offset
        self.limit = limit
        self.revision = revision
    }
}

public enum M2ReadingCatalogPageData: Codable, Sendable {
    case missing(M2ReadingCatalogPageDataMissing)
    case changed(M2ReadingCatalogPageDataChanged)
    case ready(M2ReadingCatalogPageDataReady)

    private enum CodingKeys: String, CodingKey { case kind }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        let tag = fields.contains(.kind) ? try fields.decode(String.self, forKey: .kind) : nil
        switch tag {
        case "missing": self = .missing(try M2ReadingCatalogPageDataMissing(from: decoder))
        case "changed": self = .changed(try M2ReadingCatalogPageDataChanged(from: decoder))
        case "ready": self = .ready(try M2ReadingCatalogPageDataReady(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: fields, debugDescription: "Unknown M2ReadingCatalogPageData tag")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .missing(let value): try value.encode(to: encoder)
        case .changed(let value): try value.encode(to: encoder)
        case .ready(let value): try value.encode(to: encoder)
        }
    }
}

public struct M2ReadingCatalogPageDataMissing: Codable, Sendable {
    public let kind: M2ReadingCatalogPageDataMissingKind
    public let sourceId: String
    public let bookId: String

    public init(kind: M2ReadingCatalogPageDataMissingKind = .missing, sourceId: String, bookId: String) {
        self.kind = kind
        self.sourceId = sourceId
        self.bookId = bookId
    }
}

/// Wire values of M2ReadingCatalogPageDataMissingKind.
public enum M2ReadingCatalogPageDataMissingKind: String, Codable, Sendable, CaseIterable {
    case missing = "missing"
}

public struct M2ReadingCatalogPageDataChanged: Codable, Sendable {
    public let kind: M2ReadingCatalogPageDataChangedKind
    public let sourceId: String
    public let bookId: String
    public let revision: String

    public init(kind: M2ReadingCatalogPageDataChangedKind = .changed, sourceId: String, bookId: String, revision: String) {
        self.kind = kind
        self.sourceId = sourceId
        self.bookId = bookId
        self.revision = revision
    }
}

/// Wire values of M2ReadingCatalogPageDataChangedKind.
public enum M2ReadingCatalogPageDataChangedKind: String, Codable, Sendable, CaseIterable {
    case changed = "changed"
}

public struct M2ReadingCatalogPageDataReady: Codable, Sendable {
    public let kind: M2ReadingCatalogPageDataReadyKind
    public let sourceId: String
    public let bookId: String
    public let revision: String
    public let offset: Int64
    public let chapterCount: Int64
    public let readableChapterCount: Int64
    public let entries: [M2ReadingCatalogChapter]

    public init(kind: M2ReadingCatalogPageDataReadyKind = .ready, sourceId: String, bookId: String, revision: String, offset: Int64, chapterCount: Int64, readableChapterCount: Int64, entries: [M2ReadingCatalogChapter]) {
        self.kind = kind
        self.sourceId = sourceId
        self.bookId = bookId
        self.revision = revision
        self.offset = offset
        self.chapterCount = chapterCount
        self.readableChapterCount = readableChapterCount
        self.entries = entries
    }
}

/// Wire values of M2ReadingCatalogPageDataReadyKind.
public enum M2ReadingCatalogPageDataReadyKind: String, Codable, Sendable, CaseIterable {
    case ready = "ready"
}

public struct M2ReadingDocumentWindowParams: Codable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: Int64
    public let startScalar: Int64
    public let scalarLimit: Int64
    public let positionContext: M2RemoteContentPositionContext

    public init(sourceId: String, bookId: String, chapterIndex: Int64, startScalar: Int64, scalarLimit: Int64, positionContext: M2RemoteContentPositionContext) {
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterIndex = chapterIndex
        self.startScalar = startScalar
        self.scalarLimit = scalarLimit
        self.positionContext = positionContext
    }
}

public enum M2ReadingDocumentWindowData: Codable, Sendable {
    case missing(M2ReadingDocumentWindowDataMissing)
    case ready(M2ReadingDocumentWindowDataReady)

    private enum CodingKeys: String, CodingKey { case kind }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        let tag = fields.contains(.kind) ? try fields.decode(String.self, forKey: .kind) : nil
        switch tag {
        case "missing": self = .missing(try M2ReadingDocumentWindowDataMissing(from: decoder))
        case "ready": self = .ready(try M2ReadingDocumentWindowDataReady(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: fields, debugDescription: "Unknown M2ReadingDocumentWindowData tag")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .missing(let value): try value.encode(to: encoder)
        case .ready(let value): try value.encode(to: encoder)
        }
    }
}

public struct M2ReadingDocumentWindowDataMissing: Codable, Sendable {
    public let kind: M2ReadingDocumentWindowDataMissingKind
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: Int64
    public let reason: String

    public init(kind: M2ReadingDocumentWindowDataMissingKind = .missing, sourceId: String, bookId: String, chapterIndex: Int64, reason: String) {
        self.kind = kind
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterIndex = chapterIndex
        self.reason = reason
    }
}

/// Wire values of M2ReadingDocumentWindowDataMissingKind.
public enum M2ReadingDocumentWindowDataMissingKind: String, Codable, Sendable, CaseIterable {
    case missing = "missing"
}

public struct M2ReadingDocumentWindowDataReady: Codable, Sendable {
    public let kind: M2ReadingDocumentWindowDataReadyKind
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: Int64
    public let positionScope: M2RemoteContentPositionScope
    public let startScalar: Int64
    public let endScalar: Int64
    public let totalScalars: Int64
    public let hasMore: Bool
    public let content: String
    public let blocks: [M2ReadingDocumentBlockData]
    public let baseUrl: String?
    public let chapterTitle: String

    public init(kind: M2ReadingDocumentWindowDataReadyKind = .ready, sourceId: String, bookId: String, chapterIndex: Int64, positionScope: M2RemoteContentPositionScope, startScalar: Int64, endScalar: Int64, totalScalars: Int64, hasMore: Bool, content: String, blocks: [M2ReadingDocumentBlockData], baseUrl: String?, chapterTitle: String) {
        self.kind = kind
        self.sourceId = sourceId
        self.bookId = bookId
        self.chapterIndex = chapterIndex
        self.positionScope = positionScope
        self.startScalar = startScalar
        self.endScalar = endScalar
        self.totalScalars = totalScalars
        self.hasMore = hasMore
        self.content = content
        self.blocks = blocks
        self.baseUrl = baseUrl
        self.chapterTitle = chapterTitle
    }

    private enum CodingKeys: String, CodingKey {
        case kind = "kind"
        case sourceId = "sourceId"
        case bookId = "bookId"
        case chapterIndex = "chapterIndex"
        case positionScope = "positionScope"
        case startScalar = "startScalar"
        case endScalar = "endScalar"
        case totalScalars = "totalScalars"
        case hasMore = "hasMore"
        case content = "content"
        case blocks = "blocks"
        case baseUrl = "baseUrl"
        case chapterTitle = "chapterTitle"
    }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        kind = try fields.decode(M2ReadingDocumentWindowDataReadyKind.self, forKey: .kind)
        sourceId = try fields.decode(String.self, forKey: .sourceId)
        bookId = try fields.decode(String.self, forKey: .bookId)
        chapterIndex = try fields.decode(Int64.self, forKey: .chapterIndex)
        positionScope = try fields.decode(M2RemoteContentPositionScope.self, forKey: .positionScope)
        startScalar = try fields.decode(Int64.self, forKey: .startScalar)
        endScalar = try fields.decode(Int64.self, forKey: .endScalar)
        totalScalars = try fields.decode(Int64.self, forKey: .totalScalars)
        hasMore = try fields.decode(Bool.self, forKey: .hasMore)
        content = try fields.decode(String.self, forKey: .content)
        blocks = try fields.decode([M2ReadingDocumentBlockData].self, forKey: .blocks)
        baseUrl = try fields.decode(String?.self, forKey: .baseUrl)
        chapterTitle = try fields.decode(String.self, forKey: .chapterTitle)
    }

    public func encode(to encoder: any Encoder) throws {
        var fields = encoder.container(keyedBy: CodingKeys.self)
        try fields.encode(kind, forKey: .kind)
        try fields.encode(sourceId, forKey: .sourceId)
        try fields.encode(bookId, forKey: .bookId)
        try fields.encode(chapterIndex, forKey: .chapterIndex)
        try fields.encode(positionScope, forKey: .positionScope)
        try fields.encode(startScalar, forKey: .startScalar)
        try fields.encode(endScalar, forKey: .endScalar)
        try fields.encode(totalScalars, forKey: .totalScalars)
        try fields.encode(hasMore, forKey: .hasMore)
        try fields.encode(content, forKey: .content)
        try fields.encode(blocks, forKey: .blocks)
        try fields.encode(baseUrl, forKey: .baseUrl)
        try fields.encode(chapterTitle, forKey: .chapterTitle)
    }
}

/// Wire values of M2ReadingDocumentWindowDataReadyKind.
public enum M2ReadingDocumentWindowDataReadyKind: String, Codable, Sendable, CaseIterable {
    case ready = "ready"
}

public struct M2SourceImageRequestParams: Codable, Sendable {
    public let sourceId: String
    public let imageUrl: String
    public let baseUrl: String?
    public let source: [String: ReaderM1JSONValue]?
    public let expectedSourceVersion: String?

    public init(sourceId: String, imageUrl: String, baseUrl: String? = nil, source: [String: ReaderM1JSONValue]? = nil, expectedSourceVersion: String? = nil) {
        self.sourceId = sourceId
        self.imageUrl = imageUrl
        self.baseUrl = baseUrl
        self.source = source
        self.expectedSourceVersion = expectedSourceVersion
    }
}

public struct M2SourceImageRequestData: Codable, Sendable {
    public let request: M2HostHttpRequest

    public init(request: M2HostHttpRequest) {
        self.request = request
    }
}

public enum M2CacheClearParams: Codable, Sendable {
    case all(M2CacheClearParamsAll)
    case cache(M2CacheClearParamsCache)
    case book(M2CacheClearParamsBook)
    case chapter(M2CacheClearParamsChapter)

    private enum CodingKeys: String, CodingKey { case scope }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        let tag = fields.contains(.scope) ? try fields.decode(String.self, forKey: .scope) : nil
        switch tag {
        case "all": self = .all(try M2CacheClearParamsAll(from: decoder))
        case "cache": self = .cache(try M2CacheClearParamsCache(from: decoder))
        case "book": self = .book(try M2CacheClearParamsBook(from: decoder))
        case "chapter": self = .chapter(try M2CacheClearParamsChapter(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .scope, in: fields, debugDescription: "Unknown M2CacheClearParams tag")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .all(let value): try value.encode(to: encoder)
        case .cache(let value): try value.encode(to: encoder)
        case .book(let value): try value.encode(to: encoder)
        case .chapter(let value): try value.encode(to: encoder)
        }
    }
}

public struct M2CacheClearParamsAll: Codable, Sendable {
    public let scope: M2CacheClearParamsAllScope
    public let operationId: String?
    public let sequence: Int64?

    public init(scope: M2CacheClearParamsAllScope = .all, operationId: String? = nil, sequence: Int64? = nil) {
        self.scope = scope
        self.operationId = operationId
        self.sequence = sequence
    }
}

/// Wire values of M2CacheClearParamsAllScope.
public enum M2CacheClearParamsAllScope: String, Codable, Sendable, CaseIterable {
    case all = "all"
}

public struct M2CacheClearParamsCache: Codable, Sendable {
    public let scope: M2CacheClearParamsCacheScope
    public let operationId: String?
    public let sequence: Int64?

    public init(scope: M2CacheClearParamsCacheScope = .cache, operationId: String? = nil, sequence: Int64? = nil) {
        self.scope = scope
        self.operationId = operationId
        self.sequence = sequence
    }
}

/// Wire values of M2CacheClearParamsCacheScope.
public enum M2CacheClearParamsCacheScope: String, Codable, Sendable, CaseIterable {
    case cache = "cache"
}

public struct M2CacheClearParamsBook: Codable, Sendable {
    public let scope: M2CacheClearParamsBookScope
    public let sourceId: String
    public let bookId: String
    public let operationId: String?
    public let sequence: Int64?

    public init(scope: M2CacheClearParamsBookScope = .book, sourceId: String, bookId: String, operationId: String? = nil, sequence: Int64? = nil) {
        self.scope = scope
        self.sourceId = sourceId
        self.bookId = bookId
        self.operationId = operationId
        self.sequence = sequence
    }
}

/// Wire values of M2CacheClearParamsBookScope.
public enum M2CacheClearParamsBookScope: String, Codable, Sendable, CaseIterable {
    case book = "book"
}

public struct M2CacheClearParamsChapter: Codable, Sendable {
    public let scope: M2CacheClearParamsChapterScope
    public let sourceId: String
    public let bookId: String
    public let operationId: String?
    public let sequence: Int64?
    public let chapterIndex: Int64

    public init(scope: M2CacheClearParamsChapterScope = .chapter, sourceId: String, bookId: String, operationId: String? = nil, sequence: Int64? = nil, chapterIndex: Int64) {
        self.scope = scope
        self.sourceId = sourceId
        self.bookId = bookId
        self.operationId = operationId
        self.sequence = sequence
        self.chapterIndex = chapterIndex
    }
}

/// Wire values of M2CacheClearParamsChapterScope.
public enum M2CacheClearParamsChapterScope: String, Codable, Sendable, CaseIterable {
    case chapter = "chapter"
}

public struct M2CacheClearData: Codable, Sendable {
    public let scope: M2CacheClearScope
    public let cacheEntriesRemoved: Int64
    public let chapterEntriesRemoved: Int64
    public let queueEntriesRemoved: Int64
    public let removedContentBytes: Int64

    public init(scope: M2CacheClearScope, cacheEntriesRemoved: Int64, chapterEntriesRemoved: Int64, queueEntriesRemoved: Int64, removedContentBytes: Int64) {
        self.scope = scope
        self.cacheEntriesRemoved = cacheEntriesRemoved
        self.chapterEntriesRemoved = chapterEntriesRemoved
        self.queueEntriesRemoved = queueEntriesRemoved
        self.removedContentBytes = removedContentBytes
    }
}

/// Wire values of M2CacheClearScope.
public enum M2CacheClearScope: String, Codable, Sendable, CaseIterable {
    case all = "all"
    case cache = "cache"
    case book = "book"
    case chapter = "chapter"
}

public struct M2CacheClearOperationQueryParams: Codable, Sendable {
    public let operationId: String?
    public let expected: M2CacheClearParams?

    public init(operationId: String? = nil, expected: M2CacheClearParams? = nil) {
        self.operationId = operationId
        self.expected = expected
    }
}

public struct M2CacheClearOperationQueryData: Codable, Sendable {
    public let head: M2ReadingOperationBinding?
    public let receipt: M2CacheClearOperationReceipt?

    public init(head: M2ReadingOperationBinding?, receipt: M2CacheClearOperationReceipt?) {
        self.head = head
        self.receipt = receipt
    }

    private enum CodingKeys: String, CodingKey {
        case head = "head"
        case receipt = "receipt"
    }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        head = try fields.decode(M2ReadingOperationBinding?.self, forKey: .head)
        receipt = try fields.decode(M2CacheClearOperationReceipt?.self, forKey: .receipt)
    }

    public func encode(to encoder: any Encoder) throws {
        var fields = encoder.container(keyedBy: CodingKeys.self)
        try fields.encode(head, forKey: .head)
        try fields.encode(receipt, forKey: .receipt)
    }
}

public struct M2CacheClearOperationReceipt: Codable, Sendable {
    public let binding: M2ReadingOperationBinding
    public let phase: M2CacheClearOperationReceiptPhase
    public let result: M2CacheClearData

    public init(binding: M2ReadingOperationBinding, phase: M2CacheClearOperationReceiptPhase, result: M2CacheClearData) {
        self.binding = binding
        self.phase = phase
        self.result = result
    }
}

/// Wire values of M2CacheClearOperationReceiptPhase.
public enum M2CacheClearOperationReceiptPhase: String, Codable, Sendable, CaseIterable {
    case committed = "committed"
    case settled = "settled"
}

public struct M2HttpExecuteHostRequest: Codable, Sendable {
    public let protocolVersion: Int64
    public let requestId: Int64
    public let type: M2HttpExecuteHostRequestType
    public let operationId: Int64
    public let capability: M2HttpExecuteHostRequestCapability
    public let params: M2HostHttpRequest
    public let deliveryId: Int64?

    public init(protocolVersion: Int64, requestId: Int64, type: M2HttpExecuteHostRequestType = .hostRequest, operationId: Int64, capability: M2HttpExecuteHostRequestCapability = .httpExecute, params: M2HostHttpRequest, deliveryId: Int64? = nil) {
        self.protocolVersion = protocolVersion
        self.requestId = requestId
        self.type = type
        self.operationId = operationId
        self.capability = capability
        self.params = params
        self.deliveryId = deliveryId
    }
}

/// Wire values of M2HttpExecuteHostRequestType.
public enum M2HttpExecuteHostRequestType: String, Codable, Sendable, CaseIterable {
    case hostRequest = "host.request"
}

/// Wire values of M2HttpExecuteHostRequestCapability.
public enum M2HttpExecuteHostRequestCapability: String, Codable, Sendable, CaseIterable {
    case httpExecute = "http.execute"
}

public struct M2CookieGetHostRequest: Codable, Sendable {
    public let protocolVersion: Int64
    public let requestId: Int64
    public let type: M2CookieGetHostRequestType
    public let operationId: Int64
    public let capability: M2CookieGetHostRequestCapability
    public let params: M2HostCookieGetRequest
    public let deliveryId: Int64?

    public init(protocolVersion: Int64, requestId: Int64, type: M2CookieGetHostRequestType = .hostRequest, operationId: Int64, capability: M2CookieGetHostRequestCapability = .cookieGet, params: M2HostCookieGetRequest, deliveryId: Int64? = nil) {
        self.protocolVersion = protocolVersion
        self.requestId = requestId
        self.type = type
        self.operationId = operationId
        self.capability = capability
        self.params = params
        self.deliveryId = deliveryId
    }
}

/// Wire values of M2CookieGetHostRequestType.
public enum M2CookieGetHostRequestType: String, Codable, Sendable, CaseIterable {
    case hostRequest = "host.request"
}

/// Wire values of M2CookieGetHostRequestCapability.
public enum M2CookieGetHostRequestCapability: String, Codable, Sendable, CaseIterable {
    case cookieGet = "cookie.get"
}

public struct M2CookieSetHostRequest: Codable, Sendable {
    public let protocolVersion: Int64
    public let requestId: Int64
    public let type: M2CookieSetHostRequestType
    public let operationId: Int64
    public let capability: M2CookieSetHostRequestCapability
    public let params: M2HostCookieSetRequest
    public let deliveryId: Int64?

    public init(protocolVersion: Int64, requestId: Int64, type: M2CookieSetHostRequestType = .hostRequest, operationId: Int64, capability: M2CookieSetHostRequestCapability = .cookieSet, params: M2HostCookieSetRequest, deliveryId: Int64? = nil) {
        self.protocolVersion = protocolVersion
        self.requestId = requestId
        self.type = type
        self.operationId = operationId
        self.capability = capability
        self.params = params
        self.deliveryId = deliveryId
    }
}

/// Wire values of M2CookieSetHostRequestType.
public enum M2CookieSetHostRequestType: String, Codable, Sendable, CaseIterable {
    case hostRequest = "host.request"
}

/// Wire values of M2CookieSetHostRequestCapability.
public enum M2CookieSetHostRequestCapability: String, Codable, Sendable, CaseIterable {
    case cookieSet = "cookie.set"
}

public struct M2WebViewEvaluateJavaScriptHostRequest: Codable, Sendable {
    public let protocolVersion: Int64
    public let requestId: Int64
    public let type: M2WebViewEvaluateJavaScriptHostRequestType
    public let operationId: Int64
    public let capability: M2WebViewEvaluateJavaScriptHostRequestCapability
    public let params: M2HostWebViewEvaluateJavaScriptRequest
    public let deliveryId: Int64?

    public init(protocolVersion: Int64, requestId: Int64, type: M2WebViewEvaluateJavaScriptHostRequestType = .hostRequest, operationId: Int64, capability: M2WebViewEvaluateJavaScriptHostRequestCapability = .webviewEvaluateJavaScript, params: M2HostWebViewEvaluateJavaScriptRequest, deliveryId: Int64? = nil) {
        self.protocolVersion = protocolVersion
        self.requestId = requestId
        self.type = type
        self.operationId = operationId
        self.capability = capability
        self.params = params
        self.deliveryId = deliveryId
    }
}

/// Wire values of M2WebViewEvaluateJavaScriptHostRequestType.
public enum M2WebViewEvaluateJavaScriptHostRequestType: String, Codable, Sendable, CaseIterable {
    case hostRequest = "host.request"
}

/// Wire values of M2WebViewEvaluateJavaScriptHostRequestCapability.
public enum M2WebViewEvaluateJavaScriptHostRequestCapability: String, Codable, Sendable, CaseIterable {
    case webviewEvaluateJavaScript = "webview.evaluateJavaScript"
}

public struct M2MediaDownloadHostRequest: Codable, Sendable {
    public let protocolVersion: Int64
    public let requestId: Int64
    public let type: M2MediaDownloadHostRequestType
    public let operationId: Int64
    public let capability: M2MediaDownloadHostRequestCapability
    public let params: M2HostMediaDownloadRequest
    public let deliveryId: Int64?

    public init(protocolVersion: Int64, requestId: Int64, type: M2MediaDownloadHostRequestType = .hostRequest, operationId: Int64, capability: M2MediaDownloadHostRequestCapability = .mediaDownload, params: M2HostMediaDownloadRequest, deliveryId: Int64? = nil) {
        self.protocolVersion = protocolVersion
        self.requestId = requestId
        self.type = type
        self.operationId = operationId
        self.capability = capability
        self.params = params
        self.deliveryId = deliveryId
    }
}

/// Wire values of M2MediaDownloadHostRequestType.
public enum M2MediaDownloadHostRequestType: String, Codable, Sendable, CaseIterable {
    case hostRequest = "host.request"
}

/// Wire values of M2MediaDownloadHostRequestCapability.
public enum M2MediaDownloadHostRequestCapability: String, Codable, Sendable, CaseIterable {
    case mediaDownload = "media.download"
}

public struct M2ProtocolErrorEvent: Codable, Sendable {
    public let deliveryId: Int64?
    public let protocolVersion: Int64
    public let requestId: Int64
    public let type: M2ProtocolErrorEventType
    public let error: M2ProtocolError

    public init(deliveryId: Int64? = nil, protocolVersion: Int64, requestId: Int64, type: M2ProtocolErrorEventType = .error, error: M2ProtocolError) {
        self.deliveryId = deliveryId
        self.protocolVersion = protocolVersion
        self.requestId = requestId
        self.type = type
        self.error = error
    }
}

/// Wire values of M2ProtocolErrorEventType.
public enum M2ProtocolErrorEventType: String, Codable, Sendable, CaseIterable {
    case error = "error"
}
