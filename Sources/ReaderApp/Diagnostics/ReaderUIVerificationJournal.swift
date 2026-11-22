#if DEBUG && targetEnvironment(simulator)
import Foundation
import QuartzCore

/// Same-process observations from ordinary Reader owners, enabled for one
/// explicitly selected XCTest session. The private journal contains no text
/// from the shelf, search editor or reader.
@MainActor
enum ReaderUIVerificationJournal {
    static let search = "bookshelf.search-input-ime"
    static let reading = "reading.control-open-motion"

    private struct Session {
        let id: UUID
        let caseID: String
        let file: URL
    }

    private struct Event: Encodable {
        let sessionID: UUID
        let caseID: String
        let sequence: Int
        let monotonicSeconds: Double
        let kind: String
        let tags: [String: String]
        let values: [String: Double]
        let flags: [String: Bool]
    }

    private static let session: Session? = {
        let environment = ProcessInfo.processInfo.environment
        guard let value = environment["READER_UI_VERIFICATION_SESSION"],
              let id = UUID(uuidString: value),
              let caseID = environment["READER_UI_VERIFICATION_CASE"],
              [search, reading].contains(caseID),
              let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let file = cache.appendingPathComponent("ReaderUIVerification", isDirectory: true)
            .appendingPathComponent(id.uuidString).appendingPathExtension("jsonl")
        guard !FileManager.default.fileExists(atPath: file.path) else { return nil }
        return Session(id: id, caseID: caseID, file: file)
    }()

    private static let writer = DispatchQueue(label: "io.reader.minliny.ui-verification-journal", qos: .utility)
    private static var sequence = 0

    static func observes(_ caseID: String) -> Bool { session?.caseID == caseID }

    static func record(_ caseID: String, _ kind: String, tags: [String: String] = [:],
                       values: [String: Double] = [:], flags: [String: Bool] = [:]) {
        guard let session, session.caseID == caseID, sequence < 512 else { return }
        sequence += 1
        let event = Event(sessionID: session.id, caseID: caseID, sequence: sequence,
                          monotonicSeconds: CACurrentMediaTime(), kind: kind, tags: tags,
                          values: values, flags: flags)
        let file = session.file
        writer.async {
            do {
                let data = try JSONEncoder().encode(event) + Data([0x0A])
                if event.sequence == 1 {
                    try FileManager.default.createDirectory(at: file.deletingLastPathComponent(),
                                                            withIntermediateDirectories: true)
                    // Each Runner uses one new UUID. A stale file cannot be a
                    // continuation of a different app lifetime.
                    try data.write(to: file, options: .withoutOverwriting)
                    return
                }
                let handle = try FileHandle(forWritingTo: file)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } catch {
                // Observation failures appear as a missing record or gap.
            }
        }
    }
}
#endif
