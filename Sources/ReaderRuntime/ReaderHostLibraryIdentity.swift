import Foundation

/// Host credential isolation follows the preserved library, not its current
/// sandbox path. The UUID is an identity only; cookies remain in Keychain.
enum ReaderHostLibraryIdentity {
    static let fileName = ".host-library-identity-v1"

    static func loadOrCreate(in operationsURL: URL) throws -> String {
        let manager = FileManager.default
        try manager.createDirectory(at: operationsURL, withIntermediateDirectories: true)
        let url = operationsURL.appendingPathComponent(fileName, isDirectory: false)
        if manager.fileExists(atPath: url.path) { return try read(url) }
        let candidate = UUID().uuidString.lowercased() + "\n"
        do {
            // Exclusive creation prevents a competing runtime from replacing
            // the identity that another owner has already persisted.
            try Data(candidate.utf8).write(to: url, options: .withoutOverwriting)
        } catch {
            if manager.fileExists(atPath: url.path) { return try read(url) }
            throw error
        }
        return try read(url)
    }

    private static func read(_ url: URL) throws -> String {
        let facts = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard facts.isRegularFile == true, facts.isSymbolicLink != true, facts.fileSize == 37,
              let text = String(data: try Data(contentsOf: url), encoding: .utf8), text.last == "\n",
              let identifier = UUID(uuidString: String(text.dropLast())),
              text == identifier.uuidString.lowercased() + "\n" else {
            // Never silently lose a preserved credential namespace by making
            // a new UUID when an existing identity is unreadable/corrupt.
            throw ReaderLibraryError.invalidResponse("Host library identity is invalid; the preserved file was not replaced")
        }
        return "reader-library:" + identifier.uuidString.lowercased()
    }
}
