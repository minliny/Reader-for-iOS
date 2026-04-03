import XCTest
@testable import ReaderCoreModels

final class EnvironmentTests: XCTestCase {
    private let trackedKeys = ["SITE_URL", "DEBUG", "TIMEOUT_INTERVAL"]
    private var originalValues: [String: String?] = [:]
    
    override func setUp() {
        super.setUp()
        originalValues = Dictionary(uniqueKeysWithValues: trackedKeys.map { key in
            (key, ProcessInfo.processInfo.environment[key])
        })
        clearTrackedEnvironment()
    }
    
    override func tearDown() {
        restoreTrackedEnvironment()
        super.tearDown()
    }
    
    /// 测试默认siteURL
    func testDefaultSiteURL() {
        XCTAssertEqual(Environment.siteURL, "https://example.com")
    }
    
    /// 测试自定义siteURL
    func testCustomSiteURL() {
        setEnvironmentValue("https://blog.minliny.com", for: "SITE_URL")
        XCTAssertEqual(Environment.siteURL, "https://blog.minliny.com")
    }
    
    /// 测试带空格的siteURL
    func testSiteURLWithWhitespace() {
        setEnvironmentValue("  https://blog.minliny.com  ", for: "SITE_URL")
        XCTAssertEqual(Environment.siteURL, "https://blog.minliny.com")
    }
    
    /// 测试默认debug模式
    func testDefaultDebugMode() {
        XCTAssertFalse(Environment.isDebug)
    }
    
    /// 测试开启debug模式
    func testDebugModeEnabled() {
        setEnvironmentValue("true", for: "DEBUG")
        XCTAssertTrue(Environment.isDebug)
    }
    
    /// 测试关闭debug模式
    func testDebugModeDisabled() {
        setEnvironmentValue("false", for: "DEBUG")
        XCTAssertFalse(Environment.isDebug)
    }
    
    /// 测试默认超时时间
    func testDefaultTimeoutInterval() {
        XCTAssertEqual(Environment.timeoutInterval, 30.0)
    }
    
    /// 测试自定义超时时间
    func testCustomTimeoutInterval() {
        setEnvironmentValue("60", for: "TIMEOUT_INTERVAL")
        XCTAssertEqual(Environment.timeoutInterval, 60.0)
    }
    
    /// 测试无效超时时间
    func testInvalidTimeoutInterval() {
        setEnvironmentValue("invalid", for: "TIMEOUT_INTERVAL")
        XCTAssertEqual(Environment.timeoutInterval, 30.0)
    }

    private func clearTrackedEnvironment() {
        for key in trackedKeys {
            unsetenv(key)
        }
    }

    private func restoreTrackedEnvironment() {
        for key in trackedKeys {
            if let original = originalValues[key] ?? nil {
                setenv(key, original, 1)
            } else {
                unsetenv(key)
            }
        }
    }

    private func setEnvironmentValue(_ value: String, for key: String) {
        setenv(key, value, 1)
    }
}
