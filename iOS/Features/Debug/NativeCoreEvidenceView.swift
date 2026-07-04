#if DEBUG && canImport(ReaderCoreNativeAdapter)

import Foundation
import ReaderCoreNativeAdapter
import SwiftUI

public struct NativeCoreEvidenceAutorunConfiguration: Sendable, Equatable {
    public let isEnabled: Bool
    public let isValid: Bool
    public let invalidReason: String?
    public let outputDirectory: String
    public let exitAfterRun: Bool

    private init(
        isEnabled: Bool,
        isValid: Bool,
        invalidReason: String?,
        outputDirectory: String,
        exitAfterRun: Bool
    ) {
        self.isEnabled = isEnabled
        self.isValid = isValid
        self.invalidReason = invalidReason
        self.outputDirectory = outputDirectory
        self.exitAfterRun = exitAfterRun
    }

    public static func parse(_ arguments: [String]) -> NativeCoreEvidenceAutorunConfiguration {
        guard arguments.contains("--native-core-evidence-autorun") else {
            return disabled()
        }

        var outputDirectory = ""
        var exitAfterRun = false

        for (index, argument) in arguments.enumerated() {
            switch argument {
            case "--native-core-evidence-output-dir":
                if index + 1 < arguments.count {
                    outputDirectory = arguments[index + 1]
                }
            case "--native-core-evidence-exit-after-run":
                exitAfterRun = true
            default:
                break
            }
        }

        return NativeCoreEvidenceAutorunConfiguration(
            isEnabled: true,
            isValid: true,
            invalidReason: nil,
            outputDirectory: outputDirectory,
            exitAfterRun: exitAfterRun
        )
    }

    private static func disabled() -> NativeCoreEvidenceAutorunConfiguration {
        NativeCoreEvidenceAutorunConfiguration(
            isEnabled: false,
            isValid: true,
            invalidReason: nil,
            outputDirectory: "",
            exitAfterRun: false
        )
    }
}

public struct NativeCoreEvidenceView: View {
    @State private var report: ReaderCoreNativeAppEvidenceReport?
    @State private var isRunning = false

    public init() {}

    public var body: some View {
        DemoBackScreen(title: "Native Core Evidence") {
            NativeCoreEvidenceSection(title: "Native Core") {
                NativeCoreEvidenceRow(
                    icon: .code,
                    title: "ABI",
                    subtitle: "ReaderCoreNativeRuntime",
                    value: "\(ReaderCoreNativeRuntime.abiVersion)"
                )
                NativeCoreEvidenceRow(
                    icon: .activity,
                    title: "App Launch",
                    subtitle: "App launch observed",
                    value: statusValue(for: .appLaunch),
                    isPassing: statusIsPassing(for: .appLaunch)
                )
                NativeCoreEvidenceRow(
                    icon: .sourceStack,
                    title: "Host Loop",
                    subtitle: "Host request bridge",
                    value: statusValue(for: .hostRequestLoop),
                    isPassing: statusIsPassing(for: .hostRequestLoop)
                )
            }

            NativeCoreEvidenceSection(title: "Evidence") {
                NativeCoreEvidenceActionButton(
                    icon: .sourceStack,
                    title: "Run Host Request Loop",
                    subtitle: "Run native adapter evidence and capture host-loop metrics",
                    isRunning: isRunning
                ) {
                    runHostLoop()
                }

                if let host = report?.hostRequestLoop {
                    NativeCoreEvidenceRow(icon: .source, title: "Capability", subtitle: "Native host request", value: host.capability)
                    NativeCoreEvidenceRow(icon: .link, title: "Operation", subtitle: "HostRequestEvent.operationId", value: "\(host.operationId)")
                    NativeCoreEvidenceRow(icon: .bookOpen, title: "Books", subtitle: "Result count", value: "\(host.resultBookCount)")
                    NativeCoreEvidenceRow(icon: .text, title: "First Title", subtitle: "First returned book title", value: host.firstBookTitle ?? "-")
                }
            }

            NativeCoreEvidenceSection(title: "Wrapper Smoke") {
                NativeCoreEvidenceRow(
                    icon: .shield,
                    title: "Wrapper Smoke",
                    subtitle: "ReaderCoreNativeAdapter smoke layer",
                    value: statusValue(for: .wrapperSmoke),
                    isPassing: statusIsPassing(for: .wrapperSmoke)
                )
            }
        }
    }

    private func statusValue(for layer: ReaderCoreNativeEvidenceLayer) -> String {
        if let layerResult = report?.layers.first(where: { $0.layer == layer }) {
            return layerResult.status.rawValue
        }
        return "notRun"
    }

    private func statusIsPassing(for layer: ReaderCoreNativeEvidenceLayer) -> Bool? {
        report?.layers.first(where: { $0.layer == layer })?.status == .measuredPass
    }

    private func runHostLoop() {
        guard !isRunning else { return }
        isRunning = true
        let bundleId = Bundle.main.bundleIdentifier
        Task {
            let nextReport = await Task.detached {
                ReaderCoreNativeAppEvidenceRunner.run(
                    processName: "ReaderForIOSApp",
                    bundleIdentifier: bundleId,
                    appLaunchObserved: true
                )
            }.value
            report = nextReport
            isRunning = false
        }
    }
}

public struct NativeCoreEvidenceAutorunView: View {
    @StateObject private var viewModel: NativeCoreEvidenceAutorunViewModel

    public init(configuration: NativeCoreEvidenceAutorunConfiguration) {
        _viewModel = StateObject(wrappedValue: NativeCoreEvidenceAutorunViewModel(configuration: configuration))
    }

    public var body: some View {
        DemoPaperScreen {
            if viewModel.isRunning {
                ReaderStateCard(
                    icon: .sync,
                    title: "Running Native Core evidence",
                    subtitle: "Host request loop evidence is running."
                )
            } else if let report = viewModel.report, report.hostRequestLoopPassed {
                ReaderStateCard(
                    icon: .check,
                    title: "Native Core evidence passed",
                    subtitle: viewModel.outputDirectory
                )
            } else {
                ReaderStateCard(
                    icon: .warning,
                    title: "Native Core evidence failed",
                    subtitle: viewModel.errorText
                )
            }
        }
        .task {
            await viewModel.run()
        }
    }
}

private struct NativeCoreEvidenceSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
                Text(title)
                    .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .black))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)

                VStack(spacing: 0) {
                    content
                }
            }
        }
    }
}

private struct NativeCoreEvidenceRow: View {
    let icon: ReaderAssetIcon
    let title: String
    let subtitle: String
    let value: String
    var isPassing: Bool? = nil

    var body: some View {
        DemoIconRow(icon: icon, title: title, subtitle: subtitle, detail: nil) {
            Text(value)
                .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black, design: .monospaced))
                .foregroundColor(valueColor)
                .lineLimit(1)
        }
    }

    private var valueColor: Color {
        guard let isPassing else {
            return ReaderDesignTokens.Color.primaryDark.opacity(0.74)
        }
        return isPassing ? ReaderDesignTokens.Color.primary : ReaderDesignTokens.Color.Semantic.warning
    }
}

private struct NativeCoreEvidenceActionButton: View {
    let icon: ReaderAssetIcon
    let title: String
    let subtitle: String
    let isRunning: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ReaderDesignTokens.settingsRowGap) {
                if isRunning {
                    // demo `.fd-discover-bottom-loading i`：14×14 旋转圆，
                    // 占位与 icon column 对齐。
                    DemoLoadingSpinner(size: .inline)
                        .frame(width: ReaderDesignTokens.settingsRowIconColumn, height: ReaderDesignTokens.settingsRowIconColumn)
                } else {
                    ReaderIcon(icon, size: 17, accessibilityLabel: title)
                        .frame(width: ReaderDesignTokens.settingsRowIconColumn, height: ReaderDesignTokens.settingsRowIconColumn)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(isRunning ? "Running Host Request Loop" : title)
                        .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, ReaderDesignTokens.settingsRowHorizontalPadding)
            .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.settingsRowMinHeight, alignment: .leading)
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                    .fill(ReaderDesignTokens.Color.primary)
            )
        }
        .buttonStyle(.plain)
        .disabled(isRunning)
        .opacity(isRunning ? 0.65 : 1)
    }
}

@MainActor
public final class NativeCoreEvidenceAutorunViewModel: ObservableObject {
    @Published public private(set) var isRunning = false
    @Published public private(set) var report: ReaderCoreNativeAppEvidenceReport?
    @Published public private(set) var errorText = ""
    @Published public private(set) var outputDirectory = ""

    private let configuration: NativeCoreEvidenceAutorunConfiguration
    private let runId = UUID().uuidString

    public init(configuration: NativeCoreEvidenceAutorunConfiguration) {
        self.configuration = configuration
        self.outputDirectory = Self.resolveOutputDirectory(configuration: configuration, runId: runId)
    }

    public func run() async {
        guard !isRunning else { return }
        isRunning = true
        writeStatus(status: "running", error: nil)

        let bundleId = Bundle.main.bundleIdentifier
        let nextReport = await Task.detached {
            ReaderCoreNativeAppEvidenceRunner.run(
                processName: "ReaderForIOSApp",
                bundleIdentifier: bundleId,
                appLaunchObserved: true
            )
        }.value
        report = nextReport

        let reportURL = URL(fileURLWithPath: outputDirectory)
            .appendingPathComponent("native_core_evidence.json")
        do {
            try ReaderCoreNativeAppEvidenceRunner.write(nextReport, to: reportURL)
            if nextReport.hostRequestLoopPassed {
                writeStatus(status: "success", error: nil)
            } else {
                let blockerText = nextReport.layers
                    .first(where: { $0.layer == .hostRequestLoop })?
                    .blockers
                    .joined(separator: "; ") ?? "host request loop failed"
                errorText = blockerText
                writeStatus(status: "failed", error: blockerText)
            }
        } catch {
            errorText = error.localizedDescription
            writeStatus(status: "failed", error: error.localizedDescription)
        }

        isRunning = false

        if configuration.exitAfterRun {
            try? await Task.sleep(nanoseconds: 500_000_000)
            exit(nextReport.hostRequestLoopPassed ? 0 : 1)
        }
    }

    private static func resolveOutputDirectory(
        configuration: NativeCoreEvidenceAutorunConfiguration,
        runId: String
    ) -> String {
        if !configuration.outputDirectory.isEmpty {
            return URL(fileURLWithPath: configuration.outputDirectory)
                .appendingPathComponent(runId, isDirectory: true)
                .path
        }
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return documents
            .appendingPathComponent("NativeCoreEvidenceRuns", isDirectory: true)
            .appendingPathComponent(runId, isDirectory: true)
            .path
    }

    private func writeStatus(status: String, error: String?) {
        let payload = NativeCoreEvidenceRunStatus(
            status: status,
            runId: runId,
            outputDirectory: outputDirectory,
            error: error,
            updatedAt: Date()
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let url = URL(fileURLWithPath: outputDirectory)
            .appendingPathComponent("native_core_evidence_status.json")
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try encoder.encode(payload).write(to: url, options: .atomic)
        } catch {
            print("[NativeCoreEvidence] failed to write status: \(error)")
        }
    }
}

private struct NativeCoreEvidenceRunStatus: Codable {
    let status: String
    let runId: String
    let outputDirectory: String
    let error: String?
    let updatedAt: Date
}

#endif
