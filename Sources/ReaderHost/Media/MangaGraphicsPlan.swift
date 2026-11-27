import CoreGraphics
import Foundation
import ImageIO
import ReaderCoreBridge
import UniformTypeIdentifiers

extension MangaImageDecoder {
    /// Core owns the strip assignment. Apple codecs unpack and repack it;
    /// the same process reservation covers this transformation and page tiles.
    func transform(_ input: URL, plan: M3MangaGraphicsPlan, byteLimit: Int) throws -> Data {
        try Task.checkCancellation()
        guard plan.readerMangaGraphicsPlan, (1...4096).contains(plan.width), (1...65_535).contains(plan.height),
              (1...64).contains(plan.strips.count), plan.width * plan.height <= 8_000_000,
              plan.strips.allSatisfy({ (0..<plan.height).contains($0.sourceY) && (0..<plan.height).contains($0.targetY)
                  && (1...plan.height).contains($0.height)
                  && $0.height <= plan.height - $0.sourceY && $0.height <= plan.height - $0.targetY }),
              Self.coversFrame(plan.strips, order: \.sourceY, height: plan.height),
              Self.coversFrame(plan.strips, order: \.targetY, height: plan.height) else {
            throw MangaImageFailure.pixelBudget
        }
        let width = Int(plan.width)
        let height = Int(plan.height)
        let reservation = try Self.reserve(width * height * 3)
        return try withExtendedLifetime(reservation) {
            try autoreleasepool {
                let options = [kCGImageSourceShouldCache: false] as CFDictionary
                guard let source = CGImageSourceCreateWithURL(input as CFURL, options),
                      CGImageSourceGetCount(source) == 1,
                      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options) as? [CFString: Any],
                      (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue == width,
                      (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue == height,
                      let image = CGImageSourceCreateImageAtIndex(source, 0, options),
                      CGImageSourceGetStatus(source) == .statusComplete,
                      let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                              bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
                    throw MangaImageFailure.decode
                }
                for strip in plan.strips {
                    try Task.checkCancellation()
                    let raw = CGRect(x: 0, y: Int(strip.sourceY), width: width, height: Int(strip.height))
                    guard let pixels = image.cropping(to: raw) else { throw MangaImageFailure.decode }
                    let targetY = height - Int(strip.targetY + strip.height)
                    context.draw(pixels, in: CGRect(x: 0, y: targetY, width: width, height: Int(strip.height)))
                }
                let bytes = NSMutableData()
                guard let matrix = context.makeImage(),
                      let encoder = CGImageDestinationCreateWithData(bytes as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
                    throw MangaImageFailure.decode
                }
                CGImageDestinationAddImage(encoder, matrix, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
                guard CGImageDestinationFinalize(encoder), (1...byteLimit).contains(bytes.length) else {
                    throw MangaImageFailure.decode
                }
                return bytes as Data
            }
        }
    }

    private static func coversFrame(_ strips: [M3MangaGraphicsPlanStripsItem],
                                    order: KeyPath<M3MangaGraphicsPlanStripsItem, Int64>, height: Int64) -> Bool {
        var end: Int64 = 0
        for strip in strips.sorted(by: { $0[keyPath: order] < $1[keyPath: order] }) {
            guard strip[keyPath: order] == end else { return false }
            end += strip.height
        }
        return end == height
    }
}
