import Foundation
import CoreText

/// CoreText identifies the exact registered face. WebKit receives its original
/// bytes through the per-reader origin because process-local font registration
/// alone does not make imported fonts available in the web content process.
enum ReaderEbookFontAsset {
    static func prepare(postScriptName: String) throws -> (Data, String) {
        let font = CTFontCreateWithName(postScriptName as CFString, 18, nil)
        guard CTFontCopyPostScriptName(font) as String == postScriptName,
              let url = CTFontCopyAttribute(font, kCTFontURLAttribute) as? URL, url.isFileURL else {
            throw ReaderEbookError.invalidDocument
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber, size.intValue > 0,
              size.intValue <= 32 * 1024 * 1024 else { throw ReaderEbookError.resourceLimit }
        let bytes = try Data(contentsOf: url, options: .mappedIfSafe)
        guard bytes.count == size.intValue else { throw ReaderEbookError.sourceChanged }
        // The browser and CoreText own OpenType/TrueType decoding. No font
        // tables are parsed, rewritten or renamed by this adapter.
        return (bytes, ReaderEbookResourcePath.mimeType(url.lastPathComponent))
    }
}
