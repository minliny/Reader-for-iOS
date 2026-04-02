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
        let manifestData = try Data(contentsOf: URL(fileURLWithPath: manifestPath))
        let manifest = try JSONDecoder().decode(FixtureTocRegressionManifest.self, from: manifestData)
        let result = try FixtureTocRegressionRunner.run(manifest: manifest)
        let outputData = try JSONEncoder.pretty.encode(result)
        try outputData.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
        FileHandle.standardOutput.write(outputData)
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
