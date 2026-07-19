import Foundation

public enum ReaderSlice11ContractMaturity: String, Codable, Sendable {
    case frozenCommand = "frozen-command"
    case readerUICompatibilityOnly = "reader-ui-compatibility-only"
    case hostRuntime = "host-runtime"
    case absent
}

public enum ReaderSlice11CapabilityState: String, Codable, Sendable {
    case executable
    case partial
    case blocked
}

public enum ReaderSlice11CapabilityID: String, Codable, CaseIterable, Sendable {
    case dynamicSourceCRUD = "source.dynamic.crud"
    case legadoDSLImport = "source.legado-dsl.import"
    case sourceLiveCheck = "source.check.live"
    case sourceDebugReplay = "source.debug.replay"
    case sourceImageRequest = "source.image-request"
    case ruleSubscription = "rules.subscription"
    case ordinaryHTTP = "host.http.ordinary"
    case cookieSessionIsolation = "host.cookie.session-isolation"
    case webViewProfileIsolation = "host.webview.profile-isolation"
    case webViewLoginReturn = "host.webview.login-return"
    case captchaChallengeReturn = "host.challenge.captcha-return"
    case credentialIsolation = "host.credential.isolation"
    case publicRSS = "rss.public"
    case authenticatedRSS = "rss.authenticated"
    case cookieProtectedDownload = "download.cookie-protected"
    case authorizationProtectedDownload = "download.authorization-protected"
    case antiBotHumanChallenge = "host.anti-bot.human-challenge"
}

public struct ReaderSlice11Capability: Codable, Equatable, Sendable {
    public let id: ReaderSlice11CapabilityID
    public let state: ReaderSlice11CapabilityState
    public let contractMaturity: ReaderSlice11ContractMaturity
    public let implementedContracts: [String]
    public let implementationFiles: [String]
    public let automatedTests: [String]
    public let blockerCodes: [String]
    public let boundaryNote: String
}

/// Machine-verifiable Slice 11 admission boundary.
///
/// Source tests prove only the named request/response and isolation behavior.
/// They do not substitute for a licensed source corpus, account credentials,
/// Simulator/physical-device WebKit/Keychain runs, or release evidence.
public enum ReaderSlice11CapabilityRegistry {
    public static let records: [ReaderSlice11Capability] = [
        .init(
            id: .dynamicSourceCRUD,
            state: .partial,
            contractMaturity: .frozenCommand,
            implementedContracts: ["source.import", "source.list", "source.delete", "source.export"],
            implementationFiles: ["ReaderSlice11CoreService.swift", "BookSourceViewModel.swift"],
            automatedTests: ["ReaderSlice11CoreServiceTests", "ReaderSlice11CapabilityRegistryTests"],
            blockerCodes: ["SLICE11_SOURCE_PRODUCTION_ENTRY_WIRING_MISSING"],
            boundaryNote: "Import is Core-first and the local list is only a UI compatibility mirror; list/delete/export still lack complete production screen wiring."
        ),
        .init(
            id: .legadoDSLImport,
            state: .partial,
            contractMaturity: .frozenCommand,
            implementedContracts: ["source.import"],
            implementationFiles: ["ReaderSlice11CoreService.swift"],
            automatedTests: ["ReaderSlice11CoreServiceTests", "ReaderSlice11CapabilityRegistryTests"],
            blockerCodes: ["SLICE11_LEGADO_CORPUS_PROOF_MISSING"],
            boundaryNote: "One caller-supplied BookSource object is imported without rewriting its DSL; production breadth still requires a lawful source corpus."
        ),
        .init(
            id: .sourceLiveCheck,
            state: .partial,
            contractMaturity: .frozenCommand,
            implementedContracts: ["source.check.run", "http.execute"],
            implementationFiles: ["ReaderSlice11CoreService.swift", "HostRequestRouter.swift", "URLSessionHTTPClient.swift"],
            automatedTests: ["ReaderSlice11CoreServiceTests", "URLSessionHTTPClientCapabilitiesTests", "ReaderSlice11CapabilityRegistryTests"],
            blockerCodes: ["SLICE11_LIVE_SOURCE_CORPUS_PROOF_MISSING"],
            boundaryNote: "The real Host HTTP path is wired, but no arbitrary public endpoint is represented as a production BookSource proof."
        ),
        .init(
            id: .sourceDebugReplay,
            state: .executable,
            contractMaturity: .frozenCommand,
            implementedContracts: ["source.debug"],
            implementationFiles: ["ReaderSlice11CoreService.swift"],
            automatedTests: ["ReaderSlice11CoreServiceTests"],
            blockerCodes: [],
            boundaryNote: "Debug is explicitly replay-only and requires non-empty caller-owned response corpus before dispatch."
        ),
        .init(
            id: .sourceImageRequest,
            state: .partial,
            contractMaturity: .frozenCommand,
            implementedContracts: ["source.imageRequest"],
            implementationFiles: ["ReaderSlice11CoreService.swift"],
            automatedTests: ["ReaderSlice11CoreServiceTests", "ReaderSlice11CapabilityRegistryTests"],
            blockerCodes: ["SLICE11_IMAGE_CREDENTIAL_BINDING_CONTRACT_MISSING"],
            boundaryNote: "Credential-free descriptors and opaque cookie sessions are admitted; plaintext sensitive headers fail closed."
        ),
        .init(
            id: .ruleSubscription,
            state: .blocked,
            contractMaturity: .absent,
            implementedContracts: [],
            implementationFiles: ["ReaderSlice11CoreService.swift"],
            automatedTests: ["ReaderSlice11CoreServiceTests", "ReaderSlice11CapabilityRegistryTests"],
            blockerCodes: ["SLICE11_RULE_SUBSCRIPTION_CONTRACT_MISSING"],
            boundaryNote: "Routes are not a Core CRUD/apply contract; iOS does not create a local-only rule owner."
        ),
        .init(
            id: .ordinaryHTTP,
            state: .executable,
            contractMaturity: .hostRuntime,
            implementedContracts: ["http.execute"],
            implementationFiles: ["HostRequestRouter.swift", "URLSessionHTTPClient.swift", "ReaderSlice11HostManifest.swift"],
            automatedTests: ["URLSessionHTTPClientCapabilitiesTests", "ReaderSlice11HostBoundaryTests"],
            blockerCodes: [],
            boundaryNote: "URLSession owns body encoding, charset, redirect caps, bounded retries, and optional opaque cookie sessions."
        ),
        .init(
            id: .cookieSessionIsolation,
            state: .partial,
            contractMaturity: .hostRuntime,
            implementedContracts: ["cookie.get", "cookie.set", "http.execute"],
            implementationFiles: ["CookieGetHandler.swift", "CookieSetHandler.swift", "HostCookieCapability.swift", "HostRequestRouter.swift"],
            automatedTests: ["HostLoginCookieProofTests", "ReaderSlice11HostBoundaryTests", "ReaderSlice11CapabilityRegistryTests"],
            blockerCodes: ["SLICE11_COOKIE_SESSION_DEVICE_PROOF_MISSING"],
            boundaryNote: "Opaque sessions are isolated in source-scoped cookie jars; a physical-device persistence/redirect run is still evidence work."
        ),
        .init(
            id: .webViewProfileIsolation,
            state: .partial,
            contractMaturity: .hostRuntime,
            implementedContracts: ["webview.evaluateJavaScript"],
            implementationFiles: ["WKWebViewExecutor.swift", "WebViewEvaluateJavaScriptHandler.swift", "ReaderSlice11HostManifest.swift"],
            automatedTests: ["HostWebViewRenderProofTests", "ReaderSlice11CapabilityRegistryTests"],
            blockerCodes: ["SLICE11_WEBVIEW_PROFILE_SIMULATOR_DEVICE_PROOF_MISSING"],
            boundaryNote: "Each opaque profile reuses its own nonpersistent website store and process pool; WebKit isolation needs Simulator/device execution."
        ),
        .init(
            id: .webViewLoginReturn,
            state: .blocked,
            contractMaturity: .absent,
            implementedContracts: [],
            implementationFiles: ["ReaderSlice11CoreService.swift"],
            automatedTests: ["ReaderSlice11CoreServiceTests", "ReaderSlice11CapabilityRegistryTests"],
            blockerCodes: ["SLICE11_WEBVIEW_LOGIN_RETURN_CONTRACT_MISSING"],
            boundaryNote: "Evaluation is frozen, but login completion and WebView-cookie handoff are not."
        ),
        .init(
            id: .captchaChallengeReturn,
            state: .blocked,
            contractMaturity: .absent,
            implementedContracts: [],
            implementationFiles: ["ReaderSlice11CoreService.swift"],
            automatedTests: ["ReaderSlice11CoreServiceTests", "ReaderSlice11CapabilityRegistryTests"],
            blockerCodes: ["SLICE11_CAPTCHA_RETURN_CONTRACT_MISSING"],
            boundaryNote: "CHALLENGE_REQUIRED diagnostics do not define captcha submission or request resume."
        ),
        .init(
            id: .credentialIsolation,
            state: .partial,
            contractMaturity: .hostRuntime,
            implementedContracts: ["host-private credential store", "source-login header provider"],
            implementationFiles: ["HostRequestRouter.swift"],
            automatedTests: ["ReaderSlice11CoreServiceTests", "ReaderSlice11HostBoundaryTests", "ReaderSlice11CapabilityRegistryTests"],
            blockerCodes: ["SLICE11_KEYCHAIN_ENTITLEMENT_DEVICE_PROOF_MISSING", "SLICE11_LEGACY_LOGIN_HEADER_MIGRATION_PROOF_MISSING"],
            boundaryNote: "New secrets use fixed Keychain services, hashed account keys, and ThisDeviceOnly accessibility; no generic credential capability is advertised, while legacy UserDefaults header migration still needs a separately verified path."
        ),
        .init(
            id: .publicRSS,
            state: .partial,
            contractMaturity: .frozenCommand,
            implementedContracts: ["rss.subscription.add", "rss.subscription.list", "rss.subscription.update", "rss.subscription.delete", "rss.subscription.refresh", "rss.subscription.items"],
            implementationFiles: ["ReaderSlice11CoreService.swift", "RSSSubscriptionStore.swift"],
            automatedTests: ["ReaderSlice11CoreServiceTests", "ReaderSlice11CompatibilityCoreExecutorTests", "ReaderSlice11CapabilityRegistryTests"],
            blockerCodes: ["SLICE11_RSS_PRODUCTION_PILOT_WIRING_MISSING"],
            boundaryNote: "Only absolute credential-free HTTP(S) URLs are admitted, but the Reader-UI RSS coordinator remains production Shadow and has no live executor assembly."
        ),
        .init(
            id: .authenticatedRSS,
            state: .blocked,
            contractMaturity: .absent,
            implementedContracts: [],
            implementationFiles: ["ReaderSlice11CoreService.swift"],
            automatedTests: ["ReaderSlice11CoreServiceTests", "ReaderSlice11CapabilityRegistryTests"],
            blockerCodes: ["SLICE11_RSS_AUTH_BINDING_CONTRACT_MISSING"],
            boundaryNote: "The frozen RSS DTO has no opaque credential, header, cookie-session, or WebView-profile reference."
        ),
        .init(
            id: .cookieProtectedDownload,
            state: .executable,
            contractMaturity: .hostRuntime,
            implementedContracts: ["media.download", "cookie.get", "cookie.set"],
            implementationFiles: ["URLSessionMediaDownloadExecutor.swift", "RustCoreServiceSupport.swift"],
            automatedTests: ["URLSessionMediaDownloadExecutorProofTests", "ReaderSlice11HostBoundaryTests"],
            blockerCodes: [],
            boundaryNote: "Opaque session cookies are scoped correctly; bytes stream through a bounded staging file and caller-owned save paths cannot be overwritten."
        ),
        .init(
            id: .authorizationProtectedDownload,
            state: .blocked,
            contractMaturity: .absent,
            implementedContracts: [],
            implementationFiles: ["URLSessionMediaDownloadExecutor.swift"],
            automatedTests: ["URLSessionMediaDownloadExecutorProofTests", "ReaderSlice11CapabilityRegistryTests"],
            blockerCodes: ["SLICE11_DOWNLOAD_CREDENTIAL_REFERENCE_CONTRACT_MISSING"],
            boundaryNote: "Authorization and API-key headers are rejected until media.download carries an opaque credential reference."
        ),
        .init(
            id: .antiBotHumanChallenge,
            state: .blocked,
            contractMaturity: .absent,
            implementedContracts: [],
            implementationFiles: ["ReaderSlice11HostManifest.swift"],
            automatedTests: ["ReaderSlice11HostBoundaryTests", "ReaderSlice11CapabilityRegistryTests"],
            blockerCodes: ["SLICE11_ANTI_BOT_HUMAN_CHALLENGE_CONTRACT_MISSING"],
            boundaryNote: "The explicit Host manifest deliberately omits anti_bot rather than inferring it from HTTP, cookie, and WebView primitives."
        ),
    ]

    public static func capability(_ id: ReaderSlice11CapabilityID) -> ReaderSlice11Capability {
        guard let value = records.first(where: { $0.id == id }) else {
            preconditionFailure("Slice 11 registry missing \(id.rawValue)")
        }
        return value
    }

    public static func validate() -> [String] {
        var failures: [String] = []
        let ids = records.map(\.id)
        if Set(ids).count != ids.count { failures.append("duplicate capability id") }
        let missing = Set(ReaderSlice11CapabilityID.allCases).subtracting(ids)
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
                failures.append("\(record.id.rawValue) claims an absent contract")
            }
        }
        return failures
    }
}
