import Foundation
import UIKit
import ImageIO
import CryptoKit

/// Core's embedded cover contract is a data:image/*;base64 URI capped at
/// 2 MiB (reader-local-book/epub.rs). Foundation decodes base64; ImageIO owns
/// format/orientation decoding and downsampling. No Host image codec is used.
enum ReaderCoverImage {
    private static let cache: NSCache<NSString, UIImage> = {
        let value = NSCache<NSString, UIImage>()
        value.totalCostLimit = 16 * 1024 * 1024
        return value
    }()
    static func embedded(_ uri: String) throws -> UIImage {
        guard uri.utf8.count <= 3 * 1024 * 1024, let separator = uri.firstIndex(of: ",") else { throw ReaderLibraryError.invalidResponse("cover URI") }
        let key = SHA256.hash(data: Data(uri.utf8)).map { String(format: "%02x", $0) }.joined() as NSString
        if let image = cache.object(forKey: key) { return image }
        let header = uri[..<separator].lowercased()
        guard header.hasPrefix("data:image/"), header.hasSuffix(";base64"),
              let data = Data(base64Encoded: String(uri[uri.index(after: separator)...])), data.count <= 2 * 1024 * 1024 else {
            throw ReaderLibraryError.invalidResponse("embedded cover")
        }
        let image = try thumbnail(data)
        cache.setObject(image, forKey: key, cost: image.cgImage.map { $0.bytesPerRow * $0.height } ?? data.count)
        return image
    }
    static func thumbnail(_ data: Data) throws -> UIImage {
        guard data.count <= 8 * 1024 * 1024,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = metadata[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = metadata[kCGImagePropertyPixelHeight] as? NSNumber,
              width.doubleValue > 0, height.doubleValue > 0,
              width.doubleValue * height.doubleValue <= Double(ReaderEbookImageBudget.maximumSourcePixels),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 512,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw ReaderLibraryError.invalidResponse("cover image") }
        return UIImage(cgImage: image)
    }
}
