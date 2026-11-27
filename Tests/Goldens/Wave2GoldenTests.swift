import CoreGraphics
import CryptoKit
import ReaderDesign
import SwiftUI
import XCTest
@testable import ReaderApp

struct GoldenScene: Codable {
    let id: String
    let state: String
    let reference: String
    let sample: String
    let width: Int
    let height: Int
    let theme: String
    let textSize: String
    let paper: String?
    let platformDifference: String
    var pngSHA256: String?
    var pixelSHA256: String?
}

struct GoldenManifest: Codable {
    let schemaVersion: Int
    let pins: [String: String]
    let runtime: String
    let rendering: String
    var scenes: [GoldenScene]
}

@MainActor
final class Wave2GoldenTests: XCTestCase {
    func testM1Goldens() async throws {
        let mode = ProcessInfo.processInfo.environment["READER_RECORD_GOLDENS"] == "1"
        let source = Bundle(for: Self.self)
        let manifestURL = try XCTUnwrap(source.url(forResource: "manifest", withExtension: "json",
                                                    subdirectory: "Baselines"))
        var manifest = try JSONDecoder().decode(GoldenManifest.self, from: Data(contentsOf: manifestURL))
        XCTAssertEqual(manifest.schemaVersion, 1)
        XCTAssertTrue((15...20).contains(manifest.scenes.count))
        XCTAssertEqual(Set(manifest.scenes.map(\.id)).count, manifest.scenes.count)
        let evidence = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents/ReaderM1Goldens")
        if mode { try FileManager.default.createDirectory(at: evidence, withIntermediateDirectories: true) }

        for index in manifest.scenes.indices {
            let scene = manifest.scenes[index]
            let image = try await render(scene)
            let png = try XCTUnwrap(image.pngData())
            let actual = try pixelSHA(image)
            if mode {
                try png.write(to: evidence.appendingPathComponent(scene.id + ".png"), options: .atomic)
                manifest.scenes[index].pngSHA256 = sha(png)
                manifest.scenes[index].pixelSHA256 = actual
            } else {
                let url = try XCTUnwrap(source.url(forResource: scene.id, withExtension: "png", subdirectory: "Baselines"))
                let expectedPNG = try Data(contentsOf: url)
                XCTAssertEqual(sha(expectedPNG), scene.pngSHA256, "\(scene.id) baseline file")
                let expectedPixels = try pixelSHA(XCTUnwrap(UIImage(data: expectedPNG)))
                XCTAssertEqual(expectedPixels, scene.pixelSHA256, "\(scene.id) baseline pixels")
                if actual != expectedPixels {
                    let attachment = XCTAttachment(image: image)
                    attachment.name = scene.id + "-actual"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
                XCTAssertEqual(actual, expectedPixels, "\(scene.id) \(scene.width)×\(scene.height)")
            }
            print("M1_GOLDEN \(mode ? "record" : "check") \(scene.id) \(scene.width)x\(scene.height) pixel_sha256=\(actual)")
        }

        if mode {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            var data = try encoder.encode(manifest)
            data.append(0x0A)
            try data.write(to: evidence.appendingPathComponent("manifest.json"), options: .atomic)
        }
        print("M1_GOLDEN_TOTAL mode=\(mode ? "record" : "compare") count=\(manifest.scenes.count)")
    }

    private func render(_ scene: GoldenScene) async throws -> UIImage {
        let sh = scene.theme == "night"
        let bounds = CGRect(x: 0, y: 0, width: scene.width, height: scene.height)
        let content = GoldenScenes.view(scene)
            .readerDesign()
            .environment(\.readerTheme, ReaderTheme(night: sh))
            .environment(\.colorScheme, sh ? .dark : .light)
            .environment(\.dynamicTypeSize, scene.textSize == "accessibility2" ? .accessibility2 : .large)
            .environment(\.locale, Locale(identifier: "zh_CN"))
            .frame(width: bounds.width, height: bounds.height)
        let hosting = UIHostingController(rootView: content)
        // The fixed viewport models a content frame. UIKit's device safe
        // area must not translate an already sized snapshot down and crop it.
        hosting.safeAreaRegions = []
        let sceneWindow = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let prior = sceneWindow.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: sceneWindow)
        window.overrideUserInterfaceStyle = sh ? .dark : .light
        window.rootViewController = hosting
        window.frame = bounds
        let priorAnimations = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer {
            hosting.dismiss(animated: false)
            window.isHidden = true
            window.rootViewController = nil
            prior?.makeKey()
            UIView.setAnimationsEnabled(priorAnimations)
        }
        window.makeKeyAndVisible()
        hosting.view.frame = bounds
        hosting.view.setNeedsLayout()
        hosting.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(60))
        let nativeAlert = scene.id == "message-confirmation"
        if nativeAlert {
            for _ in 0..<16 {
                if hasPresentedView(in: hosting) { break }
                try await Task.sleep(for: .milliseconds(40))
            }
            XCTAssertTrue(hasPresentedView(in: hosting), "Native confirmation must be presented by UIKit")
        }
        window.layoutIfNeeded()
        hosting.view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(bounds: bounds, format: format).image { renderer in
            if nativeAlert {
                XCTAssertTrue(window.drawHierarchy(in: bounds, afterScreenUpdates: true))
            } else {
                hosting.view.layer.render(in: renderer.cgContext)
            }
        }
    }

    private func hasPresentedView(in controller: UIViewController) -> Bool {
        controller.presentedViewController != nil || controller.children.contains(where: hasPresentedView(in:))
    }

    private func pixelSHA(_ image: UIImage) throws -> String {
        let decoded = try XCTUnwrap(image.cgImage)
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let bitmap = try XCTUnwrap(CGContext(data: nil, width: decoded.width, height: decoded.height,
                                             bitsPerComponent: 8, bytesPerRow: decoded.width * 4, space: space,
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        bitmap.draw(decoded, in: CGRect(x: 0, y: 0, width: decoded.width, height: decoded.height))
        return sha(Data(bytes: try XCTUnwrap(bitmap.data), count: decoded.width * 4 * decoded.height))
    }

    private func sha(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
