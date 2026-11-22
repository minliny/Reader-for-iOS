import XCTest
import UIKit
import QuartzCore

/// Captures Reader's two initial verification cases through the normal UI.
/// The host seals the XCTest attachments together with the matching app-owner
/// journal and the exact tested App and Runner build identities.
@MainActor
final class ReaderUIVerificationJourneyTests: XCTestCase {
    private let publicBookID = "book-local:60f22eced47c50661c3263a5c509a2532b5d2cf2acc88dcace6dd4e120b6b0e3"
    private enum CaptureError: Error { case invalidPrerequisite }

    private struct NativeNode: Encodable {
        let identifier: String
        let label: String
        let elementType: UInt
        let frame: CGRect?
        let enabled: Bool
        let hasFocus: Bool
        let valueLengthUTF16: Int?
        let children: [NativeNode]

        @MainActor init(_ snapshot: any XCUIElementSnapshot) {
            identifier = snapshot.identifier
            label = snapshot.label
            elementType = snapshot.elementType.rawValue
            let rect = snapshot.frame
            frame = [rect.origin.x, rect.origin.y, rect.width, rect.height].allSatisfy(\.isFinite) ? rect : nil
            enabled = snapshot.isEnabled
            hasFocus = snapshot.hasFocus
            valueLengthUTF16 = (snapshot.value as? String)?.utf16.count
            children = snapshot.children.map(NativeNode.init)
        }
    }

    private struct Sample: Encodable {
        let name: String
        let beforeSeconds: Double
        let afterSeconds: Double
        let pixelsWide: Int?
        let pixelsHigh: Int?
        let application: NativeNode
        let keyboard: NativeNode?
    }

    private struct Action: Encodable {
        let name: String
        let elementID: String
        let beforeSeconds: Double
        let afterSeconds: Double
    }

    private struct Capture: Encodable {
        let schema = "reader-ui-native-ios-v1"
        let sessionID: UUID
        let caseID: String
        let bundleID = "io.reader.minliny"
        let clock = "CACurrentMediaTime"
        let layoutUnit = "pt"
        let osVersion: String
        let deviceModel = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"]
        var samples: [String] = []
        var actions: [Action] = []

        @MainActor init(sessionID: UUID, caseID: String) {
            self.sessionID = sessionID
            self.caseID = caseID
            self.osVersion = UIDevice.current.systemVersion
        }
    }

    private func require(_ condition: Bool, _ detail: String,
                         file: StaticString = #filePath, line: UInt = #line) throws {
        guard condition else {
            XCTFail(detail, file: file, line: line)
            throw CaptureError.invalidPrerequisite
        }
    }

    private func addAttachment<T: Encodable>(_ value: T, name: String) throws {
        let data = try JSONEncoder().encode(value)
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func launch(_ capture: Capture) throws -> XCUIApplication {
        #if !targetEnvironment(simulator)
        throw XCTSkip("The UI verification adapter uses the dedicated public-fixture simulator.")
        #endif
        let app = XCUIApplication(bundleIdentifier: capture.bundleID)
        app.launchEnvironment["READER_UI_VERIFICATION_SESSION"] = capture.sessionID.uuidString
        app.launchEnvironment["READER_UI_VERIFICATION_CASE"] = capture.caseID
        app.launch()
        try require(app.buttons["bookshelf-search"].waitForExistence(timeout: 15), "Expected the normal bookshelf")
        let books = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'book-'")).allElementsBoundByIndex
        try require(books.allSatisfy { $0.identifier == publicBookID }, "A book is outside the public fixture scope")
        return app
    }

    private func sample(_ name: String, app: XCUIApplication, capture: inout Capture) throws {
        try require(app.state == .runningForeground, "Reader must be foreground for \(name)")
        let before = CACurrentMediaTime()
        let tree = NativeNode(try app.snapshot())
        let keyboard = app.keyboards.firstMatch
        let input = keyboard.exists ? NativeNode(try keyboard.snapshot()) : nil
        let screenshot = XCUIScreen.main.screenshot()
        let after = CACurrentMediaTime()
        let attachedImage = XCTAttachment(screenshot: screenshot)
        attachedImage.name = "\(name)-screen"
        attachedImage.lifetime = .keepAlways
        add(attachedImage)
        let image = screenshot.image.cgImage
        try addAttachment(Sample(name: name, beforeSeconds: before, afterSeconds: after,
            pixelsWide: image?.width, pixelsHigh: image?.height, application: tree, keyboard: input), name: "\(name)-native")
        capture.samples.append(name)
    }

    private func dispatch(_ name: String, on element: XCUIElement, capture: inout Capture,
                          perform: () -> Void) throws {
        try require(element.exists && element.isEnabled && element.isHittable, "Missing native action target for \(name)")
        let identifier = element.identifier
        let before = CACurrentMediaTime()
        perform()
        capture.actions.append(Action(name: name, elementID: identifier, beforeSeconds: before, afterSeconds: CACurrentMediaTime()))
    }

    func testNativeBookshelfSearchInput() throws {
        var capture = Capture(sessionID: UUID(), caseID: "bookshelf.search-input-ime")
        defer { XCTAssertNoThrow(try addAttachment(capture, name: "reader-ui-capture")) }
        let app = try launch(capture)
        let entry = app.buttons["bookshelf-search"]
        try sample("before", app: app, capture: &capture)
        try dispatch("open-search", on: entry, capture: &capture) { entry.tap() }
        let query = app.textFields["online-search-query"]
        let submit = app.buttons["online-search-submit"]
        try require(query.waitForExistence(timeout: 8), "Expected the online search editor")
        try require((query.value as? String).map { $0.isEmpty || $0 == query.placeholderValue } ?? true,
                    "Unexpected text in the public fixture editor")
        try dispatch("focus-query", on: query, capture: &capture) { query.tap() }
        try require(app.keyboards.firstMatch.waitForExistence(timeout: 6), "The system keyboard did not appear")
        try sample("ime-ready", app: app, capture: &capture)
        try dispatch("input-search", on: query, capture: &capture) { query.typeText("Reader") }
        try require(query.value as? String == "Reader", "The normal editor did not accept the public input")
        try sample("submit-ready", app: app, capture: &capture)
        try dispatch("submit-search", on: submit, capture: &capture) { submit.tap() }
        try require(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "The keyboard did not retire")
        try require(app.buttons["online-search-stop"].waitForNonExistence(timeout: 45), "The selected search did not settle")
        try sample("results-settled", app: app, capture: &capture)
    }

    func testNativeReadingControlMotion() throws {
        var capture = Capture(sessionID: UUID(), caseID: "reading.control-open-motion")
        defer { XCTAssertNoThrow(try addAttachment(capture, name: "reader-ui-capture")) }
        let app = try launch(capture)
        let book = app.buttons[publicBookID]
        try require(book.waitForExistence(timeout: 5), "Import the exact public TXT through the normal reader before this case")
        try dispatch("enter-reading", on: book, capture: &capture) { book.tap() }
        let body = app.textViews["reading-body"]
        let hide = app.buttons["收起阅读控制"]
        try require(body.waitForExistence(timeout: 15) && !hide.exists, "Expected the normal unobscured TXT body")
        try sample("reading-before", app: app, capture: &capture)
        try dispatch("open", on: body, capture: &capture) {
            body.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
        }
        try require(hide.waitForExistence(timeout: 8), "The normal controls did not open")
        try require(app.buttons["control-module-home"].isHittable, "The ordinary Home module is not actionable")
        try sample("control-open", app: app, capture: &capture)
        try dispatch("dismiss", on: hide, capture: &capture) { hide.tap() }
        try require(hide.waitForNonExistence(timeout: 8) && body.isHittable, "The controls did not return to the reading body")
        try sample("control-closed", app: app, capture: &capture)
    }
}
