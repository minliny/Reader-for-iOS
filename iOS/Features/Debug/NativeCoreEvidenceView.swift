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
        List {
            Section("Native Core") {
                LabeledContent("ABI") {
                    Text("\(ReaderCoreNativeRuntime.abiVersion)")
                        .font(.caption.monospaced())
                }
                LabeledContent("App Launch") {
                    statusText(for: .appLaunch)
                }
                LabeledContent("Host Loop") {
                    statusText(for: .hostRequestLoop)
                }
            }

            Section("Evidence") {
                Button {
                    runHostLoop()
                } label: {
                    if isRunning {
                        ProgressView()
                    } else {
                        Label("Run Host Request Loop", systemImage: "point.3.connected.trianglepath.dotted")
                    }
                }
                .disabled(isRunning)

                if let host = report?.hostRequestLoop {
                    LabeledContent("Capability") {
                        Text(host.capability)
                            .font(.caption.monospaced())
                    }
                    LabeledContent("Operation") {
                        Text("\(host.operationId)")
                            .font(.caption.monospaced())
                    }
                    LabeledContent("Books") {
                        Text("\(host.resultBookCount)")
                            .font(.caption.monospaced())
                    }
                    LabeledContent("First Title") {
                        Text(host.firstBookTitle ?? "-")
                            .font(.caption)
                    }
                }
            }

            Section("Wrapper Smoke") {
                statusText(for: .wrapperSmoke)
            }
        }
        .navigationTitle("Native Core Evidence")
    }

    @ViewBuilder
    private func statusText(for layer: ReaderCoreNativeEvidenceLayer) -> some View {
        if let layerResult = report?.layers.first(where: { $0.layer == layer }) {
            Text(layerResult.status.rawValue)
                .font(.caption.monospaced())
                .foregroundStyle(layerResult.status == .measuredPass ? .green : .secondary)
        } else {
            Text("notRun")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
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
        VStack(spacing: 16) {
            if viewModel.isRunning {
                ProgressView("Running Native Core evidence")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let report = viewModel.report, report.hostRequestLoopPassed {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("Native Core evidence passed")
                        .font(.headline)
                    Text(viewModel.outputDirectory)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "xmark.octagon.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.red)
                    Text("Native Core evidence failed")
                        .font(.headline)
                    Text(viewModel.errorText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .task {
            await viewModel.run()
        }
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
