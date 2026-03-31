import XCTest
@testable import ReaderCoreModels

final class EnvironmentTests: XCTestCase {
    private let originalEnvironment = ProcessInfo.processInfo.environment
    
    override func setUp() {
        super.setUp()
        // 保存原始环境变量
        ProcessInfo.processInfo.environment["SITE_URL"] = nil
        ProcessInfo.processInfo.environment["DEBUG"] = nil
        ProcessInfo.processInfo.environment["TIMEOUT_INTERVAL"] = nil
    }
    
    override func tearDown() {
        // 恢复原始环境变量
        ProcessInfo.processInfo.environment = originalEnvironment
        super.tearDown()
    }
    
    /// 测试默认siteURL
    func testDefaultSiteURL() {
        XCTAssertEqual(Environment.siteURL, "https://example.com")
    }
    
    /// 测试自定义siteURL
    func testCustomSiteURL() {
        ProcessInfo.processInfo.environment["SITE_URL"] = "https://blog.minliny.com"
        XCTAssertEqual(Environment.siteURL, "https://blog.minliny.com")
    }
    
    /// 测试带空格的siteURL
    func testSiteURLWithWhitespace() {
        ProcessInfo.processInfo.environment["SITE_URL"] = "  https://blog.minliny.com  "
        XCTAssertEqual(Environment.siteURL, "https://blog.minliny.com")
    }
    
    /// 测试默认debug模式
    func testDefaultDebugMode() {
        XCTAssertFalse(Environment.isDebug)
    }
    
    /// 测试开启debug模式
    func testDebugModeEnabled() {
        ProcessInfo.processInfo.environment["DEBUG"] = "true"
        XCTAssertTrue(Environment.isDebug)
    }
    
    /// 测试关闭debug模式
    func testDebugModeDisabled() {
        ProcessInfo.processInfo.environment["DEBUG"] = "false"
        XCTAssertFalse(Environment.isDebug)
    }
    
    /// 测试默认超时时间
    func testDefaultTimeoutInterval() {
        XCTAssertEqual(Environment.timeoutInterval, 30.0)
    }
    
    /// 测试自定义超时时间
    func testCustomTimeoutInterval() {
        ProcessInfo.processInfo.environment["TIMEOUT_INTERVAL"] = "60"
        XCTAssertEqual(Environment.timeoutInterval, 60.0)
    }
    
    /// 测试无效超时时间
    func testInvalidTimeoutInterval() {
        ProcessInfo.processInfo.environment["TIMEOUT_INTERVAL"] = "invalid"
        XCTAssertEqual(Environment.timeoutInterval, 30.0)
    }
}