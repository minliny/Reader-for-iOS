import Foundation

public enum ReaderSlice12CapabilityID: String, Codable, CaseIterable, Sendable {
    case initializationRestore = "lifecycle.initialization-restore"
    case onboardingPermissionRecovery = "onboarding.permission-recovery"
    case durableOnboardingOwner = "onboarding.durable-owner"
    case displaySettingsMigration = "settings.display-migration"
    case generalSettingsOwner = "settings.general-owner"
    case responsiveViewports = "layout.responsive-viewports"
    case accessibilityRuntime = "accessibility.runtime"
    case systemIntegration = "host.system-integration"
    case backgroundRecovery = "lifecycle.background-recovery"
    case releaseIdentityAudit = "release.identity-audit"
    case fullProductReleaseGate = "release.full-product"
}

public enum ReaderSlice12CapabilityState: String, Codable, Sendable {
    case executable
    case partial
    case blocked
}

public struct ReaderSlice12Capability: Codable, Equatable, Sendable {
    public let id: ReaderSlice12CapabilityID
    public let state: ReaderSlice12CapabilityState
    public let implementationFiles: [String]
    public let automatedTests: [String]
    public let blockerCodes: [String]
    public let boundaryNote: String
}

/// Local Slice 12 work that can be implemented before device/release closure.
/// `partial` and `blocked` are intentional evidence states; this registry does
/// not turn planned Reader-UI routes or old device artifacts into completion.
public enum ReaderSlice12CapabilityRegistry {
    public static let records: [ReaderSlice12Capability] = [
        .init(
            id: .initializationRestore,
            state: .partial,
            implementationFiles: ["RustCoreAggregateStorageService.swift", "ReaderApp.swift", "ReaderSlice12OnboardingCoordinator.swift"],
            automatedTests: ["RustCoreAggregateStorageServiceTests", "ReaderSlice12OnboardingCoordinatorTests"],
            blockerCodes: ["SLICE12_INITIALIZATION_RELAUNCH_DEVICE_PROOF_MISSING"],
            boundaryNote: "Business entry waits for Core aggregate restore; process death, migration, and relaunch still require App/device proof."
        ),
        .init(
            id: .onboardingPermissionRecovery,
            state: .partial,
            implementationFiles: ["ReaderSlice12OnboardingCoordinator.swift", "HostPermissionCapability.swift"],
            automatedTests: ["ReaderSlice12OnboardingCoordinatorTests", "ReaderSlice12CapabilityRegistryTests"],
            blockerCodes: ["SLICE12_ONBOARDING_NATIVE_ROUTE_WIRING_MISSING", "SLICE12_SYSTEM_SETTINGS_OPEN_CONTRACT_MISSING", "SLICE12_PERMISSION_DEVICE_PROOF_MISSING"],
            boundaryNote: "Education, deny/restricted recovery, request, and app-active recheck are executable; the production route, frozen system-settings-open seam, and system prompt need closure."
        ),
        .init(
            id: .durableOnboardingOwner,
            state: .blocked,
            implementationFiles: ["ReaderSlice12OnboardingCoordinator.swift"],
            automatedTests: ["ReaderSlice12OnboardingCoordinatorTests", "ReaderSlice12CapabilityRegistryTests"],
            blockerCodes: ["SLICE12_ONBOARDING_OWNER_CONTRACT_MISSING"],
            boundaryNote: "Reader-Core-Native does not implement initialization/settings ownership or a migration result, so iOS stores no synthetic completion flag."
        ),
        .init(
            id: .displaySettingsMigration,
            state: .executable,
            implementationFiles: ["ReaderSettingsStore.swift"],
            automatedTests: ["ReaderSlice12SettingsMigrationTests"],
            blockerCodes: [],
            boundaryNote: "The existing Host-owned display settings support schema-0 migration, a versioned envelope, atomic writes, and unknown-schema rejection."
        ),
        .init(
            id: .generalSettingsOwner,
            state: .blocked,
            implementationFiles: [],
            automatedTests: ["ReaderSlice12CapabilityRegistryTests"],
            blockerCodes: ["SLICE12_CORE_CONFIG_COMMANDS_NOT_IMPLEMENTED", "SLICE12_SETTINGS_OWNER_MATRIX_NOT_FROZEN"],
            boundaryNote: "config.loadPersisted/config.savePersisted are schema names but Reader-Core-Native explicitly does not dispatch them; local UI state cannot become the business owner."
        ),
        .init(
            id: .responsiveViewports,
            state: .partial,
            implementationFiles: ["ViewportClassAdapter.swift", "ReaderResponsiveLayout.swift", "DemoPrimitives.swift"],
            automatedTests: ["AppShellAlignmentTests", "DemoComponentPrimitiveAlignmentTests", "ReaderSlice12CapabilityRegistryTests"],
            blockerCodes: ["SLICE12_FOLD_POSTURE_CONTRACT_MISSING", "SLICE12_ALL_ROUTE_VIEWPORT_DEVICE_PROOF_MISSING"],
            boundaryNote: "Phone, compact landscape, expanded, and tablet classes exist; hinge/fold posture and all-route rotation/focus evidence do not."
        ),
        .init(
            id: .accessibilityRuntime,
            state: .partial,
            implementationFiles: ["MotionEnvironment.swift", "DemoPrimitives.swift", "StateContainerView.swift"],
            automatedTests: ["ReaderMotionResolverIntegrationTests", "ReaderSlice12CapabilityRegistryTests"],
            blockerCodes: ["SLICE12_VOICEOVER_ROUTE_MATRIX_MISSING", "SLICE12_DYNAMIC_TYPE_ALL_ROUTE_PROOF_MISSING", "SLICE12_ACCESSIBILITY_DEVICE_PROOF_MISSING"],
            boundaryNote: "Reduced motion and many semantic primitives are implemented; whole-app reading order, focus return, Dynamic Type, announcements, contrast, and target-size evidence remain open."
        ),
        .init(
            id: .systemIntegration,
            state: .partial,
            implementationFiles: ["HostPermissionCapability.swift", "HostNotificationCapability.swift", "HostShareCapability.swift", "HostClipboardCapability.swift", "HostFileSelectionCapability.swift"],
            automatedTests: ["HostAdapterCapabilityMatrixTests", "HostContract25CapabilityTests", "ReaderSlice12CapabilityRegistryTests"],
            blockerCodes: ["SLICE12_SYSTEM_INTEGRATION_BUSINESS_ENTRY_MATRIX_MISSING", "SLICE12_SYSTEM_INTEGRATION_DEVICE_PROOF_MISSING"],
            boundaryNote: "Host handlers exist, but each capability still needs a real product trigger plus permission/cancel/error/device evidence."
        ),
        .init(
            id: .backgroundRecovery,
            state: .blocked,
            implementationFiles: ["HostDeviceCapability.swift"],
            automatedTests: ["HostAdapterCapabilityMatrixTests", "ReaderSlice12CapabilityRegistryTests"],
            blockerCodes: ["SLICE12_BACKGROUND_PRODUCT_TASK_CONTRACT_MISSING", "SLICE12_BACKGROUND_RELAUNCH_DEVICE_PROOF_MISSING"],
            boundaryNote: "A Host primitive is not a durable product job, notification handoff, restart continuation, or iOS background-limit proof."
        ),
        .init(
            id: .releaseIdentityAudit,
            state: .executable,
            implementationFiles: ["ReaderSlice12ReleaseGate.swift"],
            automatedTests: ["ReaderSlice12ReleaseGateTests"],
            blockerCodes: [],
            boundaryNote: "The read-only preflight rehashes the UI inventory, lock identity, Core artifact, and evidence rows and fails closed on templates or planned states."
        ),
        .init(
            id: .fullProductReleaseGate,
            state: .blocked,
            implementationFiles: ["ReaderSlice12ReleaseGate.swift", "ReaderSlice12CapabilityRegistry.swift"],
            automatedTests: ["ReaderSlice12ReleaseGateTests", "ReaderSlice12CapabilityRegistryTests"],
            blockerCodes: ["SLICE12_DEPENDENCY_SLICES_NOT_PASSED", "SLICE12_CONSUMER_LOCK_NOT_CURRENT", "SLICE12_CORPUS_DIFF_MISSING", "SLICE12_COMPLETE_JOURNEY_DEVICE_PROOF_MISSING", "SLICE12_ROLLBACK_DRILL_MISSING"],
            boundaryNote: "Release stays blocked until Slice 9-11 App/device evidence, exact locks/digests, same-corpus diff, migration/rollback, accessibility/performance, and the complete device journey all pass."
        ),
    ]

    public static func capability(_ id: ReaderSlice12CapabilityID) -> ReaderSlice12Capability {
        guard let value = records.first(where: { $0.id == id }) else {
            preconditionFailure("Slice 12 registry missing \(id.rawValue)")
        }
        return value
    }

    public static func validate() -> [String] {
        var failures: [String] = []
        let ids = records.map(\.id)
        if Set(ids).count != ids.count { failures.append("duplicate capability id") }
        let missing = Set(ReaderSlice12CapabilityID.allCases).subtracting(ids)
        if !missing.isEmpty {
            failures.append("missing ids: \(missing.map(\.rawValue).sorted().joined(separator: ","))")
        }
        for record in records {
            if record.state == .blocked && record.blockerCodes.isEmpty {
                failures.append("\(record.id.rawValue) is blocked without blocker codes")
            }
            if record.state == .executable && !record.blockerCodes.isEmpty {
                failures.append("\(record.id.rawValue) is executable but has blocker codes")
            }
            if record.automatedTests.isEmpty {
                failures.append("\(record.id.rawValue) has no automated test")
            }
        }
        return failures
    }
}
