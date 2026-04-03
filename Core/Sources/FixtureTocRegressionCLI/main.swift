import Foundation
import ReaderCoreParser

struct CLIError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

@main
struct FixtureTocRegressionCLI {
    static func main() throws {
        let args = CommandLine.arguments
        guard args.count == 3 else {
            throw CLIError(message: "Usage: FixtureTocRegressionCLI <manifest.json> <output.json>")
        }

        let manifestPath = args[1]
        let outputPath = args[2]
        logToStderr("RUNNER_INIT manifest=\(manifestPath) output=\(outputPath)")
        let manifestData = try Data(contentsOf: URL(fileURLWithPath: manifestPath))
        let manifest = try JSONDecoder().decode(FixtureTocRegressionManifest.self, from: manifestData)
        logToStderr("MANIFEST_LOADED runId=\(manifest.runId)")

        let writer = SnapshotWriter(outputPath: outputPath)
        let result = try FixtureTocRegressionRunner.run(
            manifest: manifest,
            sampleTimeout: 30,
            log: logToStderr,
            tocLog: tocDebugToStderr,
            onUpdate: { snapshot in
                writer.write(snapshot)
            }
        )
        writer.write(result)
        let outputData = try JSONEncoder.pretty.encode(result)
        FileHandle.standardOutput.write(outputData)
    }

    private static func logToStderr(_ message: String) {
        let line = "[FixtureRunner] \(message)\n"
        writeToStderr(line)
    }

    private static func tocDebugToStderr(_ message: String) {
        let line = "[TOC_DEBUG] \(message)\n"
        writeToStderr(line)
    }

    private static func writeToStderr(_ line: String) {
        guard let data = line.data(using: .utf8) else {
            return
        }
        FileHandle.standardError.write(data)
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private final class SnapshotWriter {
    private let url: URL
    private let lock = NSLock()

    init(outputPath: String) {
        self.url = URL(fileURLWithPath: outputPath)
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
    }

    func write(_ result: FixtureTocRegressionResult) {
        lock.lock()
        defer { lock.unlock() }

        do {
            let outputData = try JSONEncoder.pretty.encode(result)
            try outputData.write(to: url, options: .atomic)
        } catch {
            let line = "[FixtureRunner] RESULT_WRITE_FAIL error=\(error)\n"
            if let data = line.data(using: .utf8) {
                FileHandle.standardError.write(data)
            }
        }
    }
}
