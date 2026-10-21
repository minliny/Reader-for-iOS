import SwiftUI
import UIKit
import ImageIO

/// Physical image bytes still belong to ReaderLibraryService's versioned
/// resource store. This owner keeps only bounded native thumbnails for the
/// currently displayed Core chapter; it owns no second resource manifest.
@MainActor
final class ReaderChapterImageOwner: ObservableObject {
    @Published private(set) var assets = ReaderChapterImageAssets.empty
    private var generation = UUID()
    private var work: Task<Void, Never>?

    func cancel() {
        work?.cancel(); work = nil
        generation = UUID()
        assets = .empty
    }

    func load(book: ReaderBook, content: ReaderChapterContent, service: ReaderLibraryService?) async {
        work?.cancel()
        let expected = UUID()
        generation = expected
        let task = Task { [weak self] in
            guard let self else { return }
            await self.loadResources(book: book, content: content, service: service, expected: expected)
        }
        work = task
        await withTaskCancellationHandler(operation: { await task.value }, onCancel: { task.cancel() })
        if generation == expected { work = nil }
    }

    private func loadResources(book: ReaderBook, content: ReaderChapterContent,
                               service: ReaderLibraryService?, expected: UUID) async {
        guard !Task.isCancelled, generation == expected else { return }
        let blocks = content.blocks.filter { $0.kind == "image" }
        let identity = ReaderChapterImageIdentity(content)
        var current = ReaderChapterImageAssets(identity: identity, loading: !blocks.isEmpty)
        assets = current
        guard !blocks.isEmpty else { return }
        // Count original occurrences, including repeated URLs, when assigning
        // the chapter's 8 MP / 32 MiB resident decode budget.
        // Reserve the three shared 240×72 placeholder canvases as well.
        let chapterPixels = 8_000_000 - 3 * 240 * 72
        let perImagePixels = min(2_000_000, chapterPixels / blocks.count)
        var remainingBytes = 32 * 1024 * 1024 - 256 * 1024
        var remainingPixels = chapterPixels
        var sourceBytesRemaining = 32 * 1024 * 1024
        var requestCount = 0
        for block in ReaderChapterImageAssets.validBlocks(in: content) {
            guard !Task.isCancelled, generation == expected else { return }
            guard let url = block.source, !url.isEmpty, current.images[url] == nil else { continue }
            guard requestCount < 32, sourceBytesRemaining >= 8 * 1024 * 1024,
                  perImagePixels > 0, remainingPixels > 0, remainingBytes > 0 else {
                current.images[url] = .budgetExceeded
                continue
            }
            do {
                guard let service,
                      book.sourceId == content.sourceId, book.bookId == content.bookId,
                      content.bodyVersion != nil, content.processingVersion != nil else {
                    throw ReaderLibraryError.invalidResponse("chapter image owner")
                }
                requestCount += 1
                // The existing service bounds one response at 8 MiB. Reserve
                // that full amount before requesting; successful smaller
                // responses return the unused part. Failed requests keep the
                // reservation, so retries cannot bypass the chapter limit.
                sourceBytesRemaining -= 8 * 1024 * 1024
                let data = try await service.chapterImage(book: book, content: content, url: url)
                guard data.count <= 8 * 1024 * 1024 else { throw ReaderLibraryError.invalidResponse("chapter image bytes") }
                sourceBytesRemaining += 8 * 1024 * 1024 - data.count
                try Task.checkCancellation()
                guard generation == expected else { return }
                let pixelLimit = min(perImagePixels, remainingPixels)
                let byteLimit = remainingBytes
                let decode = Task.detached(priority: .utility) {
                    try ReaderChapterImageDecoder.decode(data, maximumPixels: pixelLimit, maximumBytes: byteLimit)
                }
                let decoded = try await withTaskCancellationHandler(operation: { try await decode.value },
                    onCancel: { decode.cancel() })
                try Task.checkCancellation()
                guard generation == expected else { return }
                remainingPixels -= decoded.pixels
                remainingBytes -= decoded.bytes
                current.images[url] = .available(decoded.image)
            } catch is CancellationError { return }
            catch ReaderChapterImageDecodingError.budget {
                guard !Task.isCancelled, generation == expected else { return }
                current.images[url] = .budgetExceeded
            }
            catch {
                guard !Task.isCancelled, generation == expected else { return }
                current.images[url] = .failed
            }
            current.revision = UUID()
            assets = current
        }
        guard !Task.isCancelled, generation == expected else { return }
        current.loading = false
        current.revision = UUID()
        assets = current
    }
}

struct ReaderChapterImageIdentity: Equatable {
    let sourceID: String
    let bookID: String
    let chapterIndex: UInt32
    let bodyVersion: String?
    let processingVersion: String?

    init(_ content: ReaderChapterContent) {
        sourceID = content.sourceId; bookID = content.bookId; chapterIndex = content.chapterIndex
        bodyVersion = content.bodyVersion; processingVersion = content.processingVersion
    }
}

enum ReaderChapterImageAsset {
    case available(UIImage), failed, budgetExceeded
}

struct ReaderChapterImageAssets {
    static let empty = ReaderChapterImageAssets(identity: nil, loading: false)
    let identity: ReaderChapterImageIdentity?
    var loading: Bool
    var images: [String: ReaderChapterImageAsset] = [:]
    var revision = UUID()

    func matches(_ content: ReaderChapterContent) -> Bool { identity == ReaderChapterImageIdentity(content) }
    func settled(for content: ReaderChapterContent) -> Bool {
        !content.blocks.contains { $0.kind == "image" } || matches(content) && !loading
    }

    /// Core reading_document projects every image to exactly one U+FFFC.
    /// Invalid/duplicate ranges never gain an attachment or a new character.
    static func validBlocks(in content: ReaderChapterContent) -> [ReaderContentBlock] {
        var placeholders = Set<UInt64>()
        for (index, scalar) in content.content.unicodeScalars.enumerated() where scalar.value == 0xFFFC {
            placeholders.insert(UInt64(index))
        }
        var claimed = Set<UInt64>()
        return content.blocks.filter { block in
            guard block.kind == "image", block.startScalar < UInt64.max,
                  block.endScalar == block.startScalar + 1, placeholders.contains(block.startScalar),
                  claimed.insert(block.startScalar).inserted else { return false }
            return true
        }
    }

    @MainActor
    func attach(to attributed: NSMutableAttributedString, projection: ReaderParagraphProjection,
                content: ReaderChapterContent, viewport: CGSize) {
        guard viewport.width.isFinite, viewport.height.isFinite, viewport.width > 0, viewport.height > 0 else { return }
        let sameChapter = matches(content)
        for block in Self.validBlocks(in: content) {
            let start = projection.displayUTF16Offset(forSourceScalar: block.startScalar)
            let end = projection.displayUTF16Offset(forSourceScalar: block.endScalar)
            let range = NSRange(location: start, length: end - start)
            guard range.length == 1, start >= 0, NSMaxRange(range) <= attributed.length,
                  (attributed.string as NSString).character(at: start) == 0xFFFC else { continue }
            let asset = sameChapter ? block.source.flatMap { images[$0] } : nil
            let image: UIImage
            let label: String
            switch asset {
            case .some(.available(let value)): image = value; label = "插图"
            case .some(.failed): image = ReaderChapterImagePlaceholder.failed; label = "插图无法显示"
            case .some(.budgetExceeded): image = ReaderChapterImagePlaceholder.budget; label = "插图超出当前资源预算"
            case nil:
                let pending = !sameChapter || loading
                image = pending ? ReaderChapterImagePlaceholder.loading : ReaderChapterImagePlaceholder.failed
                label = pending ? "插图加载中" : "插图无法显示"
            }
            let intrinsic: CGSize
            if let width = block.imageIntrinsicWidth, let height = block.imageIntrinsicHeight, width > 0, height > 0 {
                intrinsic = CGSize(width: CGFloat(width), height: CGFloat(height))
            } else if let asset, case .available(let value) = asset { intrinsic = value.size }
            else { intrinsic = CGSize(width: 4, height: 3) }
            let basis = CGFloat(min(10_000, max(1, block.imageWidthBasisPoints ?? 10_000))) / 10_000
            var size = CGSize(width: viewport.width * basis, height: viewport.width * basis * intrinsic.height / intrinsic.width)
            let nativeFont = attributed.attribute(.font, at: start, effectiveRange: nil) as? UIFont
            // Leave one native font line for baseline/descent; an image glyph
            // exactly as tall as a linked container can otherwise fail to fit.
            let availableHeight = max(1, viewport.height - (nativeFont?.lineHeight ?? 24))
            if size.height > availableHeight {
                size.width *= availableHeight / size.height; size.height = availableHeight
            }
            let attachment = NSTextAttachment()
            attachment.image = image
            attachment.bounds = CGRect(origin: .zero, size: size)
            attributed.addAttributes([.attachment: attachment, .readerChapterImageLabel: label], range: range)
            // Native shaping and page layout remain authoritative. A fixed
            // prose maximumLineHeight must not clip the attachment paragraph.
            let paragraph = (attributed.string as NSString).paragraphRange(for: range)
            let baseStyle = attributed.attribute(.paragraphStyle, at: start, effectiveRange: nil) as? NSParagraphStyle
            let style = baseStyle?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            style.minimumLineHeight = 0; style.maximumLineHeight = 0; style.firstLineHeadIndent = 0
            style.alignment = .center
            attributed.addAttribute(.paragraphStyle, value: style, range: paragraph)
        }
    }

    /// Accessibility has its own spoken value. The canonical attributed string,
    /// native selection and every Core scalar keep the original U+FFFC.
    static func accessibilityText(_ attributed: NSAttributedString, range: NSRange? = nil) -> String {
        let range = range ?? NSRange(location: 0, length: attributed.length)
        let value = NSMutableString(string: (attributed.string as NSString).substring(with: range))
        var labels: [(NSRange, String)] = []
        attributed.enumerateAttribute(.readerChapterImageLabel, in: range) { value, location, _ in
            if let label = value as? String {
                labels.append((NSRange(location: location.location - range.location, length: location.length), label))
            }
        }
        for (location, label) in labels.reversed() { value.replaceCharacters(in: location, with: label) }
        return value as String
    }
}

private extension NSAttributedString.Key {
    static let readerChapterImageLabel = NSAttributedString.Key("reader.chapterImage.label")
}

private enum ReaderChapterImagePlaceholder {
    // Shared small native bitmaps; placeholder count cannot allocate a chapter
    // of viewport-sized decoded canvases. Each attachment reserves its own size.
    @MainActor static let loading = make("插图加载中")
    @MainActor static let failed = make("插图无法显示")
    @MainActor static let budget = make("插图超出当前资源预算")
    @MainActor private static func make(_ label: String) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: 240, height: 72), format: format).image { context in
            UIColor.gray.withAlphaComponent(0.2).setStroke()
            context.cgContext.stroke(CGRect(x: 1, y: 1, width: 238, height: 70))
            let style = NSMutableParagraphStyle(); style.alignment = .center
            (label as NSString).draw(in: CGRect(x: 4, y: 26, width: 232, height: 24), withAttributes: [
                .font: UIFont.systemFont(ofSize: 15), .foregroundColor: UIColor.gray, .paragraphStyle: style
            ])
        }
    }
}

private enum ReaderChapterImageDecodingError: Error { case budget }

private enum ReaderChapterImageDecoder {
    struct Decoded { let image: UIImage; let pixels: Int; let bytes: Int }
    static func decode(_ data: Data, maximumPixels: Int, maximumBytes: Int) throws -> Decoded {
        try Task.checkCancellation()
        guard maximumPixels > 0, maximumBytes > 0, !data.isEmpty, data.count <= 8 * 1024 * 1024,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (metadata[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let height = (metadata[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
              width.isFinite, height.isFinite, width > 0, height > 0, width * height <= 40_000_000 else {
            throw ReaderLibraryError.invalidResponse("chapter image dimensions")
        }
        let scale = min(1, sqrt(Double(maximumPixels) / (width * height)))
        let dimension = max(1, min(4096, Int(floor(max(width, height) * scale)) - 1))
        guard let decoded = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: dimension,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary) else { throw ReaderLibraryError.invalidResponse("chapter image decoding") }
        guard decoded.width * decoded.height <= maximumPixels,
              decoded.bytesPerRow <= maximumBytes / max(1, decoded.height) else { throw ReaderChapterImageDecodingError.budget }
        try Task.checkCancellation()
        return Decoded(image: UIImage(cgImage: decoded), pixels: decoded.width * decoded.height,
            bytes: decoded.bytesPerRow * decoded.height)
    }
}
