import XCTest
import ReaderAppSupport

final class ReaderDisplaySettingsBackwardCompatTests: XCTestCase {

    func testDefaultSettingsHaveNewFieldsDisabled() {
        let settings = ReaderDisplaySettings.default
        XCTAssertTrue(settings.tapZoneEnabled, "Tap zones should default to enabled")
        XCTAssertFalse(settings.brightnessOverrideEnabled, "Brightness override should default to disabled")
        XCTAssertEqual(settings.brightnessLevel, 0.8, accuracy: 0.001)
        XCTAssertFalse(settings.volumeKeyPageTurnEnabled, "Volume key page turn should default to disabled")
        XCTAssertFalse(settings.dualPageEnabled, "Dual page should default to disabled")
    }

    func testDecodingOldSettingsJSONWithoutNewFieldsUsesDefaults() throws {
        // Simulates an old settings file that predates tapZone/brightness/volume/dualPage fields
        let oldJSON = """
        {
            "fontSize": 20,
            "fontFamily": "Georgia",
            "lineSpacing": 10.0,
            "paragraphSpacing": 20.0,
            "horizontalPadding": 12.0,
            "verticalPadding": 12.0,
            "backgroundMode": "sepia",
            "pageTurnMode": "scroll"
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(ReaderDisplaySettings.self, from: oldJSON)
        XCTAssertEqual(decoded.fontSize, 20)
        XCTAssertEqual(decoded.fontFamily, "Georgia")
        XCTAssertEqual(decoded.backgroundMode, .sepia)
        // New fields should fall back to defaults
        XCTAssertTrue(decoded.tapZoneEnabled)
        XCTAssertFalse(decoded.brightnessOverrideEnabled)
        XCTAssertEqual(decoded.brightnessLevel, 0.8, accuracy: 0.001)
        XCTAssertFalse(decoded.volumeKeyPageTurnEnabled)
        XCTAssertFalse(decoded.dualPageEnabled)
    }

    func testRoundTripEncodingPreservesNewFields() throws {
        let settings = ReaderDisplaySettings(
            fontSize: 22,
            fontFamily: "Palatino",
            lineSpacing: 12.0,
            paragraphSpacing: 24.0,
            horizontalPadding: 20.0,
            verticalPadding: 20.0,
            backgroundMode: .dark,
            pageTurnMode: .paginated,
            tapZoneEnabled: false,
            brightnessOverrideEnabled: true,
            brightnessLevel: 0.5,
            volumeKeyPageTurnEnabled: true,
            dualPageEnabled: true
        )
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(ReaderDisplaySettings.self, from: data)
        XCTAssertEqual(settings, decoded)
    }

    func testBrightnessLevelClampsToValidRange() {
        let high = ReaderDisplaySettings(brightnessLevel: 1.5)
        XCTAssertEqual(high.brightnessLevel, 1.0, accuracy: 0.001)

        let low = ReaderDisplaySettings(brightnessLevel: -0.3)
        XCTAssertEqual(low.brightnessLevel, 0.0, accuracy: 0.001)

        let normal = ReaderDisplaySettings(brightnessLevel: 0.65)
        XCTAssertEqual(normal.brightnessLevel, 0.65, accuracy: 0.001)
    }
}
