// GENERATED FILE — DO NOT EDIT.
// Generator: scripts/generate-protocol-bindings.mjs
// Inputs and SHA-256 fingerprints:
//   protocol/reader-command.schema.json  ee756bfe7985af16beb3712fd9449ce5a690374285ec300b853a1a7c4d5177bb
//   protocol/reader-event.schema.json  42a2f08a71f67f30e55bda18ca129651e02ed841769255c284822f5ad08ea56b
//   protocol/reader-runtime-config.schema.json  7f80c3a548f71ab2b5d4415af83579f03c725cb0bec0fc72a1e7dc6e91368afa
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

/// Params schema `SourceImportParams` (6 declared properties).
public struct SourceImportParams: Codable, Sendable {
    public let sourceId: String?
    public let name: String?
    public let baseUrl: String?
    public let rules: ReaderJSONValue?
    public let bookSource: ReaderJSONValue?
    public let useSourceReplacement: Bool?

    public init(sourceId: String? = nil, name: String? = nil, baseUrl: String? = nil, rules: ReaderJSONValue? = nil, bookSource: ReaderJSONValue? = nil, useSourceReplacement: Bool? = nil) {
        self.sourceId = sourceId
        self.name = name
        self.baseUrl = baseUrl
        self.rules = rules
        self.bookSource = bookSource
        self.useSourceReplacement = useSourceReplacement
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
