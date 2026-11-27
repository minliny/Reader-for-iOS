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
    let milestone: String?
    let pins: [String: String]?
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
        try await verify(.local)
    }

    func testM2Goldens() async throws {
        try await verify(.online)
    }

    private enum Milestone {
        case local, online

        var label: String { self == .local ? "M1" : "M2" }
        var recordFlag: String { self == .local ? "READER_RECORD_GOLDENS" : "READER_RECORD_M2_GOLDENS" }
    }

    private func verify(_ milestone: Milestone) async throws {
        let mode = ProcessInfo.processInfo.environment[milestone.recordFlag] == "1"
        let source = Bundle(for: Self.self)
        let manifestURL = try XCTUnwrap(source.url(forResource: "manifest", withExtension: "json",
                                                    subdirectory: "Baselines"))
        var manifest = try JSONDecoder().decode(GoldenManifest.self, from: Data(contentsOf: manifestURL))
        XCTAssertEqual(manifest.schemaVersion, 1)
        XCTAssertEqual(Set(manifest.scenes.map(\.id)).count, manifest.scenes.count)
        XCTAssertTrue(manifest.scenes.allSatisfy { $0.milestone == nil || $0.milestone == "M2" })
        let group = manifest.scenes.indices.filter { (manifest.scenes[$0].milestone ?? "M1") == milestone.label }
        if milestone == .local {
            XCTAssertEqual(group.count, 18)
            XCTAssertTrue(group.allSatisfy { manifest.scenes[$0].pins == nil })
        } else {
            let pinnedURL = try XCTUnwrap(source.url(forResource: "pins", withExtension: "json"))
            let pins = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: pinnedURL))
            XCTAssertEqual(Set(group.map { manifest.scenes[$0].id }), M2GoldenScenes.ids)
            XCTAssertTrue(group.allSatisfy { manifest.scenes[$0].pins == pins })
        }
        var evidence = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Documents/Reader\(milestone.label)Goldens")
        if mode {
            if let run = ProcessInfo.processInfo.environment["READER_GOLDEN_RECORD_RUN"] {
                XCTAssertNotNil(run.wholeMatch(of: /[a-f0-9]{32}/))
                evidence.appendPathComponent(run)
            }
            try FileManager.default.createDirectory(at: evidence, withIntermediateDirectories: true)
        }

        for index in group {
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
            print("\(milestone.label)_GOLDEN \(mode ? "record" : "check") \(scene.id) \(scene.width)x\(scene.height) pixel_sha256=\(actual)")
        }

        if mode {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            var data = try encoder.encode(manifest)
            data.append(0x0A)
            try data.write(to: evidence.appendingPathComponent("manifest.json"), options: .atomic)
        }
        print("\(milestone.label)_GOLDEN_TOTAL mode=\(mode ? "record" : "compare") count=\(group.count)")
    }

    private func render(_ scene: GoldenScene) async throws -> UIImage {
        if scene.milestone == "M2" {
            let document = scene.id == "m2-source-login"
                ? try await GoldenBrowserDocument.render(width: CGFloat(scene.width), height: 430)
                : nil
            return try await render(scene, content: M2GoldenScenes.view(scene.id, browser: document))
        }
        return try await render(scene, content: GoldenScenes.view(scene))
    }

    private func render(_ scene: GoldenScene, content: some View) async throws -> UIImage {
        let sh = scene.theme == "night"
        let bounds = CGRect(x: 0, y: 0, width: scene.width, height: scene.height)
        let mounted = content
            .readerDesign()
            .environment(\.readerTheme, ReaderTheme(night: sh))
            .environment(\.colorScheme, sh ? .dark : .light)
            .environment(\.dynamicTypeSize, scene.textSize == "accessibility2" ? .accessibility2 : .large)
            .environment(\.locale, Locale(identifier: "zh_CN"))
            .frame(width: bounds.width, height: bounds.height)
        let hosting = UIHostingController(rootView: mounted)
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
        let nativePresentation = ["message-confirmation", "m2-source-switch"].contains(scene.id)
        if nativePresentation {
            for _ in 0..<16 {
                if hasPresentedView(in: hosting) { break }
                try await Task.sleep(for: .milliseconds(40))
            }
            XCTAssertTrue(hasPresentedView(in: hosting), "Expected UIKit presentation for \(scene.id)")
        }
        window.layoutIfNeeded()
        hosting.view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(bounds: bounds, format: format).image { renderer in
            if nativePresentation || scene.milestone == "M2" {
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
