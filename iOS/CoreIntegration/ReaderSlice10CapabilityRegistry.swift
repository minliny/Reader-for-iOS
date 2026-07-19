import Foundation

/// Contract maturity is recorded separately from implementation state so an
/// executable bridge cannot accidentally promote an examples-only or
/// compatibility-only wire shape into a frozen public contract.
public enum ReaderSlice10ContractMaturity: String, Codable, Sendable {
    case typedCommandSchema = "typed-command-schema"
    case schemaExamplesOnly = "schema-examples-only"
    case runtimeOnly = "runtime-only"
    case readerUICompatibilityOnly = "reader-ui-compatibility-only"
    case storageOnly = "storage-only"
    case absent
}

public enum ReaderSlice10CapabilityID: String, Codable, CaseIterable, Sendable {
    case aggregateStorage = "storage.aggregate"
    case bookmarks = "reading.bookmarks"
    case readRecords = "reading.read-records"
    case searchHistory = "search.history"
    case contentSearch = "search.content"
    case contentEdit = "content.edit"
    case replaceRuleCRUD = "rules.replace.crud"
    case replaceCompatibility = "rules.replace.compatibility"
    case txtTocRuleCRUD = "rules.txt-toc.crud"
    case dictionaryQuery = "dictionary.query"
    case dictionaryRuleCRUD = "dictionary.rule.crud"
    case sourceCandidateDiscovery = "source.switch.candidates"
    case sourceSwitchTransaction = "source.switch.transaction"
    case coverCandidateDiscovery = "cover.candidates"
    case coverApply = "cover.apply"
    case chapterReviewsRead = "chapter-reviews.read"
    case chapterReviewsWrite = "chapter-reviews.write"
    case httpTTSConfig = "http-tts.config"
    case httpTTSRequest = "http-tts.request"
    case httpTTSPlayback = "http-tts.playback"
    case ttsQueue = "tts.queue"
    case uniqueActiveSession = "reader.session.unique-active"
}

public enum ReaderSlice10CapabilityState: String, Codable, Sendable {
    case executable
    case partial
    case blocked
}

public struct ReaderSlice10Capability: Codable, Equatable, Sendable {
    public let id: ReaderSlice10CapabilityID
    public let state: ReaderSlice10CapabilityState
    public let contractMaturity: ReaderSlice10ContractMaturity
    public let implementedContracts: [String]
    public let implementationFiles: [String]
    public let automatedTests: [String]
    public let blockerCodes: [String]
    public let boundaryNote: String

    public init(
        id: ReaderSlice10CapabilityID,
        state: ReaderSlice10CapabilityState,
        contractMaturity: ReaderSlice10ContractMaturity,
        implementedContracts: [String],
        implementationFiles: [String],
        automatedTests: [String],
        blockerCodes: [String] = [],
        boundaryNote: String
    ) {
        self.id = id
        self.state = state
        self.contractMaturity = contractMaturity
        self.implementedContracts = implementedContracts
        self.implementationFiles = implementationFiles
        self.automatedTests = automatedTests
        self.blockerCodes = blockerCodes
        self.boundaryNote = boundaryNote
    }
}

/// Machine-verifiable Slice 10 boundary for iOS.
///
/// `executable` means a narrow source path exists and is covered by source
/// tests. It never means simulator, physical-device, restart, credential, or
/// release proof. Partial and blocked rows name every known admission gap.
public enum ReaderSlice10CapabilityRegistry {
    public static let records: [ReaderSlice10Capability] = [
        .init(
            id: .aggregateStorage,
            state: .partial,
            contractMaturity: .runtimeOnly,
            implementedContracts: ["runtime.storage.restore", "runtime.storage.flush", "persistence.get", "persistence.put"],
            implementationFiles: ["RustCoreAggregateStorageService.swift", "ReaderApp.swift"],
            automatedTests: ["RustCoreAggregateStorageServiceTests", "ReaderSlice10CapabilityRegistryTests"],
            blockerCodes: ["SLICE10_STORAGE_RELAUNCH_DEVICE_PROOF_MISSING"],
            boundaryNote: "Core owns one opaque aggregate and Host persists bytes; no per-entity UserDefaults mirror is admitted. Relaunch durability still needs device proof."
        ),
        .init(
            id: .bookmarks,
            state: .partial,
            contractMaturity: .schemaExamplesOnly,
            implementedContracts: ["bookmark.create", "bookmark.list", "bookmark.update", "bookmark.delete"],
            implementationFiles: ["ReaderSlice10CoreService.swift", "BookmarksListView.swift", "ReaderViewModel.swift"],
            automatedTests: ["ReaderSlice10CoreServiceTests", "ReaderSlice10CapabilityRegistryTests"],
            blockerCodes: ["SLICE10_BOOKMARK_CANONICAL_LOCATOR_MISSING", "SLICE10_BOOKMARK_RESPONSE_SCHEMA_NOT_FROZEN"],
            boundaryNote: "Core is the bookmark owner. Direct reopen fails closed because the entity has no sourceId/bookId/chapterURL locator."
        ),
        .init(
            id: .readRecords,
            state: .partial,
            contractMaturity: .schemaExamplesOnly,
            implementedContracts: ["read-record.create", "read-record.list", "read-record.update", "read-record.delete"],
            implementationFiles: ["ReaderSlice10CoreService.swift", "ReaderViewModel.swift"],
            automatedTests: ["ReaderSlice10CoreServiceTests", "ReaderSlice10CapabilityRegistryTests"],
            blockerCodes: ["SLICE10_READ_RECORD_CHAPTER_LOCATOR_MISSING", "SLICE10_STABLE_DEVICE_ID_CONTRACT_MISSING"],
            boundaryNote: "The Core entity is aggregate book time, not chapter navigation history. iOS does not invent missing locators or device identity."
        ),
        .init(
            id: .searchHistory,
            state: .executable,
            contractMaturity: .typedCommandSchema,
            implementedContracts: ["search.history.list", "search.history.add", "search.history.clear"],
            implementationFiles: ["ReaderSlice10CoreService.swift", "SearchView.swift"],
            automatedTests: ["ReaderSlice10CoreServiceTests"],
            boundaryNote: "SearchView reads and writes only the Core-owned history after aggregate storage is ready."
        ),
        .init(
            id: .contentSearch,
            state: .partial,
            contractMaturity: .typedCommandSchema,
            implementedContracts: ["search.content"],
            implementationFiles: ["ReaderSlice10CoreService.swift"],
            automatedTests: ["ReaderSlice10CoreServiceTests", "ReaderSlice10CapabilityRegistryTests"],
            blockerCodes: ["SLICE10_CONTENT_SEARCH_NATIVE_CONSUMER_MISSING"],
            boundaryNote: "Typed results preserve source/book/chapter/offset locators; the native in-reader search surface is not yet connected."
        ),
        .init(
            id: .contentEdit,
            state: .partial,
            contractMaturity: .runtimeOnly,
            implementedContracts: ["content-edit.put", "content-edit.get", "content-edit.list", "content-edit.delete"],
            implementationFiles: ["ReaderSlice10CoreService.swift"],
            automatedTests: ["ReaderSlice10CoreServiceTests", "ReaderSlice10CapabilityRegistryTests"],
            blockerCodes: ["SLICE10_CONTENT_EDIT_VERSION_CONTRACT_MISSING", "SLICE10_CONTENT_EDIT_UNDO_CONTRACT_MISSING", "SLICE10_CONTENT_EDIT_NATIVE_CONSUMER_MISSING"],
            boundaryNote: "The bridge exposes exact runtime commands but does not label delete as restore or invent concurrency and undo semantics."
        ),
        .init(
            id: .replaceRuleCRUD,
            state: .partial,
            contractMaturity: .typedCommandSchema,
            implementedContracts: ["replace-rule.create", "replace-rule.list", "replace-rule.update", "replace-rule.delete"],
            implementationFiles: ["ReaderSlice10CoreService.swift"],
            automatedTests: ["ReaderSlice10CoreServiceTests", "ReaderSlice10CapabilityRegistryTests"],
            blockerCodes: ["SLICE10_REPLACE_RULE_NATIVE_MANAGEMENT_CONSUMER_MISSING"],
            boundaryNote: "Core owns stored rules and iOS validates regex/timeout before dispatch. The existing visual panel is not claimed as a CRUD consumer."
        ),
        .init(
            id: .replaceCompatibility,
            state: .partial,
            contractMaturity: .readerUICompatibilityOnly,
            implementedContracts: ["replace.apply", "replace.persist", "replace.validate"],
            implementationFiles: ["ReaderSlice10CompatibilityCoreExecutor.swift", "ReaderReplaceRulePilotCoordinator.swift", "AppShellView.swift"],
            automatedTests: ["ReaderSlice10CompatibilityCoreExecutorTests", "ReaderReplaceRulePilotTests"],
            blockerCodes: ["SLICE10_REPLACE_COMPATIBILITY_SCHEMA_NOT_FROZEN", "SLICE10_REPLACE_CONSUMER_LOCK_SHADOW"],
            boundaryNote: "A real request-scoped executor is wired, while the unchanged consumer lock keeps production rollout in Shadow."
        ),
        .init(
            id: .txtTocRuleCRUD,
            state: .partial,
            contractMaturity: .typedCommandSchema,
            implementedContracts: ["txt-toc-rule.create", "txt-toc-rule.list", "txt-toc-rule.update", "txt-toc-rule.delete"],
            implementationFiles: ["ReaderSlice10CoreService.swift"],
            automatedTests: ["ReaderSlice10CoreServiceTests", "ReaderSlice10CapabilityRegistryTests"],
            blockerCodes: ["SLICE10_TXT_TOC_NATIVE_MANAGEMENT_CONSUMER_MISSING"],
            boundaryNote: "Core CRUD is bridged with regex validation; no visual-only screen is promoted to a production editor."
        ),
        .init(
            id: .dictionaryQuery,
            state: .partial,
            contractMaturity: .typedCommandSchema,
            implementedContracts: ["dict-rule.query"],
            implementationFiles: ["ReaderSlice10CoreService.swift"],
            automatedTests: ["ReaderSlice10CoreServiceTests", "ReaderSlice10CapabilityRegistryTests"],
            blockerCodes: ["SLICE10_DICTIONARY_NATIVE_CONSUMER_MISSING"],
            boundaryNote: "Only the wire-level query command is admitted."
        ),
        .init(
            id: .dictionaryRuleCRUD,
            state: .blocked,
            contractMaturity: .storageOnly,
            implementedContracts: [],
            implementationFiles: [],
            automatedTests: ["ReaderSlice10CapabilityRegistryTests"],
            blockerCodes: ["SLICE10_DICTIONARY_RULE_WIRE_CRUD_MISSING"],
            boundaryNote: "Core storage internals do not authorize iOS to bypass the missing command boundary."
        ),
        .init(
            id: .sourceCandidateDiscovery,
            state: .partial,
            contractMaturity: .typedCommandSchema,
            implementedContracts: ["change.bookSource"],
            implementationFiles: ["ReaderSlice10CoreService.swift"],
            automatedTests: ["ReaderSlice10CoreServiceTests", "ReaderSlice10CapabilityRegistryTests"],
            blockerCodes: ["SLICE10_SOURCE_CANDIDATE_NATIVE_CONSUMER_MISSING"],
            boundaryNote: "Candidate discovery is not a source mutation transaction."
        ),
        .init(
            id: .sourceSwitchTransaction,
            state: .partial,
            contractMaturity: .readerUICompatibilityOnly,
            implementedContracts: ["source.switch.commit", "source.switch.rollback"],
            implementationFiles: ["ReaderSlice10CompatibilityCoreExecutor.swift", "ReaderSourceSwitchPilotCoordinator.swift", "AppShellView.swift"],
            automatedTests: ["ReaderSlice10CompatibilityCoreExecutorTests", "ReaderSourceSwitchPilotTests"],
            blockerCodes: ["SLICE10_SOURCE_SWITCH_SCHEMA_NOT_FROZEN", "SLICE10_SOURCE_SWITCH_CONSUMER_LOCK_SHADOW", "SLICE10_SOURCE_SWITCH_DEVICE_TRANSACTION_PROOF_MISSING"],
            boundaryNote: "Commit and rollback are real compatibility commands, but rollout remains Shadow and cannot be promoted here."
        ),
        .init(
            id: .coverCandidateDiscovery,
            state: .partial,
            contractMaturity: .runtimeOnly,
            implementedContracts: ["change.cover", "search.cover"],
            implementationFiles: ["ReaderSlice10CoreService.swift"],
            automatedTests: ["ReaderSlice10CoreServiceTests", "ReaderSlice10CapabilityRegistryTests"],
            blockerCodes: ["SLICE10_COVER_NATIVE_CONSUMER_MISSING"],
            boundaryNote: "Only candidate URLs are returned; no mutation is inferred."
        ),
        .init(
            id: .coverApply,
            state: .blocked,
            contractMaturity: .absent,
            implementedContracts: [],
            implementationFiles: [],
            automatedTests: ["ReaderSlice10CapabilityRegistryTests"],
            blockerCodes: ["SLICE10_COVER_APPLY_TRANSACTION_CONTRACT_MISSING"],
            boundaryNote: "No Core-owned cover selection/apply transaction exists."
        ),
        .init(
            id: .chapterReviewsRead,
            state: .partial,
            contractMaturity: .typedCommandSchema,
            implementedContracts: ["book.chapterReview"],
            implementationFiles: ["ReaderSlice10CoreService.swift"],
            automatedTests: ["ReaderSlice10CoreServiceTests", "ReaderSlice10CapabilityRegistryTests"],
            blockerCodes: ["SLICE10_CHAPTER_REVIEW_NATIVE_CONSUMER_MISSING"],
            boundaryNote: "The available V1 review path is read-only."
        ),
        .init(
            id: .chapterReviewsWrite,
            state: .blocked,
            contractMaturity: .absent,
            implementedContracts: [],
            implementationFiles: [],
            automatedTests: ["ReaderSlice10CapabilityRegistryTests"],
            blockerCodes: ["SLICE10_CHAPTER_REVIEW_WRITE_CONTRACT_MISSING"],
            boundaryNote: "No create/update/delete review contract exists."
        ),
        .init(
            id: .httpTTSConfig,
            state: .partial,
            contractMaturity: .schemaExamplesOnly,
            implementedContracts: ["http-tts.put", "http-tts.get", "http-tts.list", "http-tts.delete"],
            implementationFiles: ["ReaderSlice10CoreService.swift"],
            automatedTests: ["ReaderSlice10CoreServiceTests", "ReaderSlice10CapabilityRegistryTests"],
            blockerCodes: ["SLICE10_HTTP_TTS_CREDENTIAL_REFERENCE_CONTRACT_MISSING", "SLICE10_HTTP_TTS_RESPONSE_SCHEMA_NOT_FROZEN"],
            boundaryNote: "iOS admits only credential-free HTTPS configs and never projects stored header/login secrets."
        ),
        .init(
            id: .httpTTSRequest,
            state: .partial,
            contractMaturity: .schemaExamplesOnly,
            implementedContracts: ["http-tts.build-request"],
            implementationFiles: ["ReaderSlice10CoreService.swift"],
            automatedTests: ["ReaderSlice10CoreServiceTests", "ReaderSlice10CapabilityRegistryTests"],
            blockerCodes: ["SLICE10_HTTP_TTS_CREDENTIAL_BINDING_REQUIRED"],
            boundaryNote: "Descriptors with headers, credentials, non-HTTPS URLs, or URL userinfo fail closed."
        ),
        .init(
            id: .httpTTSPlayback,
            state: .blocked,
            contractMaturity: .absent,
            implementedContracts: [],
            implementationFiles: [],
            automatedTests: ["ReaderSlice10CapabilityRegistryTests"],
            blockerCodes: ["SLICE10_HTTP_TTS_AUDIO_PLAYER_CONTRACT_MISSING", "SLICE10_HTTP_TTS_AUDIO_FOCUS_CONTRACT_MISSING", "SLICE10_HTTP_TTS_BACKGROUND_MEDIA_CONTROLS_MISSING"],
            boundaryNote: "A request descriptor is not audio playback, focus, interruption, media-key, or background proof."
        ),
        .init(
            id: .ttsQueue,
            state: .partial,
            contractMaturity: .typedCommandSchema,
            implementedContracts: ["tts.slice", "tts.queue.play", "tts.queue.report-status", "tts.queue.next", "tts.queue.stop"],
            implementationFiles: ["RustCoreTTSService.swift", "ReaderPlaybackPilotCoordinator.swift", "ReaderTTSPlayer.swift"],
            automatedTests: ["RustCoreTTSServiceTests", "ReaderPlaybackPilotCoordinatorTests", "ReaderSlice10CapabilityRegistryTests"],
            blockerCodes: ["SLICE10_TTS_BACKGROUND_MEDIA_CONTROLS_MISSING", "SLICE10_TTS_DEVICE_RESTART_PROOF_MISSING"],
            boundaryNote: "Core queue and system-TTS execution exist; content-audio and HttpTTS are separate capabilities."
        ),
        .init(
            id: .uniqueActiveSession,
            state: .partial,
            contractMaturity: .readerUICompatibilityOnly,
            implementedContracts: ["reader.session.ttsStart", "reader.session.autoPageStart", "reader.session.capsuleExit"],
            implementationFiles: ["ReaderReducer.swift", "ReaderPlaybackPilotCoordinator.swift", "ReaderUIRuntimeShadow.swift"],
            automatedTests: ["ReaderPlaybackPilotCoordinatorTests", "ReaderUIRuntimeShadowParityTests", "ReaderSlice10CapabilityRegistryTests"],
            blockerCodes: ["SLICE10_SESSION_RELAUNCH_DEVICE_PROOF_MISSING"],
            boundaryNote: "The reducer enforces one active TTS/auto-page session in-process; cross-relaunch behavior is not claimed."
        ),
    ]

    public static func capability(_ id: ReaderSlice10CapabilityID) -> ReaderSlice10Capability {
        guard let record = records.first(where: { $0.id == id }) else {
            preconditionFailure("Slice 10 registry missing \(id.rawValue)")
        }
        return record
    }

    public static func validate() -> [String] {
        var failures: [String] = []
        let ids = records.map(\.id)
        if Set(ids).count != ids.count {
            failures.append("duplicate capability id")
        }
        let missing = Set(ReaderSlice10CapabilityID.allCases).subtracting(ids)
        if !missing.isEmpty {
            failures.append("missing ids: \(missing.map(\.rawValue).sorted().joined(separator: ","))")
        }
        for record in records {
            if record.state == .blocked && record.blockerCodes.isEmpty {
                failures.append("\(record.id.rawValue) is blocked without a blocker code")
            }
            if record.state == .executable && !record.blockerCodes.isEmpty {
                failures.append("\(record.id.rawValue) is executable but has blocker codes")
            }
            if record.automatedTests.isEmpty {
                failures.append("\(record.id.rawValue) has no automated admission test")
            }
            if record.contractMaturity == .absent && !record.implementedContracts.isEmpty {
                failures.append("\(record.id.rawValue) has absent contract maturity but implemented contracts")
            }
            if record.contractMaturity == .storageOnly && !record.implementedContracts.isEmpty {
                failures.append("\(record.id.rawValue) promotes storage internals to wire contracts")
            }
        }
        return failures
    }
}
