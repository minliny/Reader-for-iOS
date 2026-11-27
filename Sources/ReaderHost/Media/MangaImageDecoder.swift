import CoreGraphics
import Foundation
import ImageIO
import os
import ReaderCoreBridge

public enum MangaImageFailure: Error, Sendable {
    case header
    case codecMismatch
    case pixelBudget
    case decode
}

public struct MangaTileGeometry: Sendable {
    public let displayPixels: CGRect
    public let normalizedStart: Double
    public let normalizedEnd: Double
}

/// Retains the shared process reservation until the last reference is dropped.
public final class MangaTileImage: Sendable {
    public let encodedSize: CGSize
    public let pixelSize: CGSize
    public let orientation: Int
    public let tiles: [MangaTileGeometry]
    private let bitmaps: [CGImage]
    private let reservation: MangaPixelReservation

    fileprivate init(encodedSize: CGSize, pixelSize: CGSize, orientation: Int, tiles: [MangaTileGeometry],
                     bitmaps: [CGImage], reservation: MangaPixelReservation) {
        self.encodedSize = encodedSize
        self.pixelSize = pixelSize
        self.orientation = orientation
        self.tiles = tiles
        self.bitmaps = bitmaps
        self.reservation = reservation
    }

    public var aspectRatio: Double { pixelSize.width / pixelSize.height }

    /// The target is expressed in the caller's Quartz coordinates, with a
    /// bottom-left origin. Only tiles intersecting the supplied clip are drawn.
    public func draw(in context: CGContext, target: CGRect, clip: CGRect) {
        let scaleX = target.width / pixelSize.width
        let scaleY = target.height / pixelSize.height
        for (index, tile) in tiles.enumerated() {
            let rect = tile.displayPixels
            let destination = CGRect(x: target.minX + rect.minX * scaleX,
                                     y: target.maxY - rect.maxY * scaleY,
                                     width: rect.width * scaleX, height: rect.height * scaleY)
            if destination.intersects(clip) { context.draw(bitmaps[index], in: destination) }
        }
    }

    /// Use original image coordinates in Core even after EXIF presentation.
    public func originalPoint(forDisplay point: CGPoint) -> CGPoint {
        let x = point.x
        let y = point.y
        switch orientation {
        case 2: return CGPoint(x: 1 - x, y: y)
        case 3: return CGPoint(x: 1 - x, y: 1 - y)
        case 4: return CGPoint(x: x, y: 1 - y)
        case 5: return CGPoint(x: y, y: x)
        case 6: return CGPoint(x: y, y: 1 - x)
        case 7: return CGPoint(x: 1 - y, y: 1 - x)
        case 8: return CGPoint(x: 1 - y, y: x)
        default: return point
        }
    }
}

/// ImageIO is the sole codec. It receives bounded original frame geometry before
/// decoding; a thumbnail and its copied display strips share the same reservation.
public actor MangaImageDecoder {
    public static let shared = MangaImageDecoder()

    private static let processPixels = 24_000_000
    private static let usedPixels = OSAllocatedUnfairLock(initialState: 0)
    private init() {}

    public func decode(_ file: MangaResourceFile, inspection: M3MangaResourceInspectData,
                       preferredWidth: Int) throws -> MangaTileImage {
        try Task.checkCancellation()
        let profile: M3MangaImageDecodeProfile
        let orientation: Int
        switch inspection {
        case .present(let value):
            guard value.sha256 == file.sha256, value.bytes == file.bytes, (1...8).contains(value.orientation) else {
                throw MangaImageFailure.codecMismatch
            }
            profile = value.decodeProfile
            orientation = Int(value.orientation)
        case .absent(let value):
            guard value.sha256 == file.sha256, value.bytes == file.bytes else { throw MangaImageFailure.codecMismatch }
            profile = value.decodeProfile
            orientation = 1
        }
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(file.url as CFURL, options),
              CGImageSourceGetCount(source) == 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options) as? [CFString: Any],
              let w = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let h = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
              (1...65_535).contains(w), (1...65_535).contains(h) else { throw MangaImageFailure.header }
        let actualOrientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        guard actualOrientation == orientation,
              profile.encodedWidth.map({ $0 == w }) ?? true, profile.encodedHeight.map({ $0 == h }) ?? true else {
            throw MangaImageFailure.codecMismatch
        }
        let originalPixels = w * h
        let frameLimit = profile.allocationClass == .scanline ? 20_000_000 : 8_000_000
        guard originalPixels <= frameLimit, preferredWidth > 0 else { throw MangaImageFailure.pixelBudget }
        let outputWidth = orientation >= 5 ? h : w
        let scale = min(1, Double(preferredWidth) / Double(outputWidth), 16_384 / Double(max(w, h)),
                        sqrt(4_000_000 / Double(originalPixels)))
        let maximum = max(1, Int(Double(max(w, h)) * scale))
        let boundW = max(1, Int(ceil(Double(w) * scale)))
        let boundH = max(1, Int(ceil(Double(h) * scale)))
        let thumbnailBudget = (boundW + 1) * (boundH + 1)
        let reservation = try Self.reserve(originalPixels + thumbnailBudget * 2)
        let (size, geometry, bitmaps) = try autoreleasepool {
            try Self.makeTiles(source, maxSize: maximum, pixelBudget: thumbnailBudget)
        }
        reservation.shrink(to: Int(size.width * size.height))
        return MangaTileImage(encodedSize: CGSize(width: w, height: h), pixelSize: size, orientation: orientation,
                              tiles: geometry, bitmaps: bitmaps, reservation: reservation)
    }

    static func reserve(_ count: Int) throws -> MangaPixelReservation {
        try usedPixels.withLock { pixels in
            guard count > 0, count <= processPixels - pixels else { throw MangaImageFailure.pixelBudget }
            pixels += count
        }
        return MangaPixelReservation(count: count) { relinquished in
            Self.usedPixels.withLock { $0 -= relinquished }
        }
    }

    private static func makeTiles(_ source: CGImageSource, maxSize: Int, pixelBudget: Int)
    throws -> (CGSize, [MangaTileGeometry], [CGImage]) {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSize, kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              CGImageSourceGetStatus(source) == .statusComplete, image.width * image.height <= pixelBudget else {
            throw MangaImageFailure.decode
        }
        var geometry: [MangaTileGeometry] = []
        var tiles: [CGImage] = []
        for top in stride(from: 0, to: image.height, by: 1_024) {
            try Task.checkCancellation()
            let height = min(1_024, image.height - top)
            let rectangle = CGRect(x: 0, y: top, width: image.width, height: height)
            guard let crop = image.cropping(to: rectangle),
                  let context = CGContext(data: nil, width: image.width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                throw MangaImageFailure.decode
            }
            context.draw(crop, in: CGRect(origin: .zero, size: rectangle.size))
            guard let tile = context.makeImage() else { throw MangaImageFailure.decode }
            geometry.append(MangaTileGeometry(displayPixels: rectangle,
                                              normalizedStart: Double(top) / Double(image.height),
                                              normalizedEnd: Double(top + height) / Double(image.height)))
            tiles.append(tile)
        }
        return (CGSize(width: image.width, height: image.height), geometry, tiles)
    }
}

final class MangaPixelReservation: Sendable {
    private let count: OSAllocatedUnfairLock<Int>
    private let release: @Sendable (Int) -> Void

    init(count: Int, release: @escaping @Sendable (Int) -> Void) {
        self.count = OSAllocatedUnfairLock(initialState: count)
        self.release = release
    }

    func shrink(to remaining: Int) {
        let relinquished = count.withLock { existing in
            let delta = existing - remaining
            existing = remaining
            return delta
        }
        release(relinquished)
    }

    deinit { release(count.withLock { $0 }) }
}
