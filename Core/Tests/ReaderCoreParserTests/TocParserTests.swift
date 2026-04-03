import XCTest
import Foundation
@testable import ReaderCoreParser
import ReaderCoreModels
import ReaderCoreProtocols

final class TocParserTests: XCTestCase {
    private var parser: TocParser!
    private var mockScheduler: MockRuleScheduler!
    
    override func setUp() {
        super.setUp()
        mockScheduler = MockRuleScheduler()
        parser = DefaultTocParser(scheduler: mockScheduler)
    }
    
    override func tearDown() {
        parser = nil
        mockScheduler = nil
        super.tearDown()
    }
    
    // MARK: - 基础功能测试
    
    /// 测试仅解析章节标题
    func testParseOnlyTitles() throws {
        // 准备测试数据
        let html = """
        <div class="chapter-list">
            <div class="chapter-item">第一章 测试标题</div>
            <div class="chapter-item">第二章 测试标题</div>
        </div>
        """
        
        // 设置预期结果
        mockScheduler.titleRule = "css:.chapter-item"
        mockScheduler.mockTitles = ["第一章 测试标题", "第二章 测试标题"]
        
        // 执行测试
        let titles = try parser.parseTitles(
            html: html,
            titleRule: "css:.chapter-item"
        )
        
        // 验证结果
        XCTAssertEqual(titles.count, 2)
        XCTAssertEqual(titles[0], "第一章 测试标题")
        XCTAssertEqual(titles[1], "第二章 测试标题")
    }
    
    /// 测试解析标题和URL
    func testParseTitlesAndURLs() throws {
        // 准备测试数据
        let html = """
        <div class="chapter-list">
            <a href="/chapter1.html" class="chapter-link">第一章 测试标题</a>
            <a href="/chapter2.html" class="chapter-link">第二章 测试标题</a>
        </div>
        """
        
        // 设置预期结果
        mockScheduler.titleRule = "css:.chapter-link"
        mockScheduler.urlRule = "css:.chapter-link|attr:href"
        mockScheduler.mockTitles = ["第一章 测试标题", "第二章 测试标题"]
        mockScheduler.mockURLs = ["/chapter1.html", "/chapter2.html"]
        
        // 执行测试
        let items = try parser.parseTitlesAndURLs(
            html: html,
            titleRule: "css:.chapter-link",
            urlRule: "css:.chapter-link|attr:href",
            baseURL: nil
        )
        
        // 验证结果
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].chapterTitle, "第一章 测试标题")
        XCTAssertEqual(items[0].chapterURL, "/chapter1.html")
        XCTAssertEqual(items[1].chapterTitle, "第二章 测试标题")
        XCTAssertEqual(items[1].chapterURL, "/chapter2.html")
    }
    
    /// 测试相对URL转换为绝对URL
    func testRelativeURLToAbsoluteURL() throws {
        // 准备测试数据
        let html = """
        <a href="/chapter1.html" class="chapter-link">第一章 测试标题</a>
        """
        
        // 设置预期结果
        mockScheduler.titleRule = "css:.chapter-link"
        mockScheduler.urlRule = "css:.chapter-link|attr:href"
        mockScheduler.mockTitles = ["第一章 测试标题"]
        mockScheduler.mockURLs = ["/chapter1.html"]
        
        // 执行测试
        let items = try parser.parseTitlesAndURLs(
            html: html,
            titleRule: "css:.chapter-link",
            urlRule: "css:.chapter-link|attr:href",
            baseURL: "https://example.com"
        )
        
        // 验证结果
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].chapterTitle, "第一章 测试标题")
        XCTAssertEqual(items[0].chapterURL, "https://example.com/chapter1.html")
    }
    
    // MARK: - 边界场景测试
    
    /// 测试空HTML输入
    func testEmptyHTMLInput() throws {
        // 准备测试数据
        let html = ""
        
        // 设置预期结果
        mockScheduler.titleRule = "css:.chapter-link"
        mockScheduler.urlRule = "css:.chapter-link|attr:href"
        mockScheduler.mockTitles = []
        mockScheduler.mockURLs = []
        
        // 执行测试
        let items = try parser.parseTitlesAndURLs(
            html: html,
            titleRule: "css:.chapter-link",
            urlRule: "css:.chapter-link|attr:href",
            baseURL: nil
        )
        
        // 验证结果
        XCTAssertEqual(items.count, 0)
    }
    
    /// 测试无匹配结果
    func testNoMatchingResults() throws {
        // 准备测试数据
        let html = """
        <div class="content">
            <p>这是内容区域，没有章节链接</p>
        </div>
        """
        
        // 设置预期结果
        mockScheduler.titleRule = "css:.chapter-link"
        mockScheduler.urlRule = "css:.chapter-link|attr:href"
        mockScheduler.mockTitles = []
        mockScheduler.mockURLs = []
        
        // 执行测试
        let items = try parser.parseTitlesAndURLs(
            html: html,
            titleRule: "css:.chapter-link",
            urlRule: "css:.chapter-link|attr:href",
            baseURL: nil
        )
        
        // 验证结果
        XCTAssertEqual(items.count, 0)
    }
    
    /// 测试部分字段缺失
    func testPartialFieldMissing() throws {
        // 准备测试数据
        let html = """
        <div class="chapter-list">
            <a href="/chapter1.html" class="chapter-link">第一章 测试标题</a>
            <div class="chapter-item">第二章 测试标题</div>
        </div>
        """
        
        // 设置预期结果
        mockScheduler.titleRule = "css:.chapter-item,css:.chapter-link"
        mockScheduler.urlRule = "css:.chapter-link|attr:href"
        mockScheduler.mockTitles = ["第一章 测试标题", "第二章 测试标题"]
        mockScheduler.mockURLs = ["/chapter1.html"]
        
        // 执行测试
        let items = try parser.parseTitlesAndURLs(
            html: html,
            titleRule: "css:.chapter-item,css:.chapter-link",
            urlRule: "css:.chapter-link|attr:href",
            baseURL: nil
        )
        
        // 验证结果
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].chapterURL, "/chapter1.html")
        XCTAssertEqual(items[1].chapterURL, "#") // 缺失URL时使用默认值
    }
    
    /// 测试标题后处理
    func testTitlePostProcessing() throws {
        // 准备测试数据
        let html = """
        <div class="chapter-item">正文卷.第一章 测试标题（求月票）</div>
        <div class="chapter-item">VIP章节.第二章 测试标题【订阅】</div>
        """
        
        // 设置预期结果
        mockScheduler.titleRule = "css:.chapter-item"
        mockScheduler.mockTitles = [
            "正文卷.第一章 测试标题（求月票）",
            "VIP章节.第二章 测试标题【订阅】"
        ]
        
        // 执行测试
        let titles = try parser.parseTitles(
            html: html,
            titleRule: "css:.chapter-item"
        )
        
        // 验证结果
        XCTAssertEqual(titles.count, 2)
        XCTAssertEqual(titles[0], "第一章 测试标题") // 已移除前缀和括号内容
        XCTAssertEqual(titles[1], "第二章 测试标题") // 已移除前缀和括号内容
    }
    
    /// 测试使用章节列表容器规则
    func testWithChapterListRule() throws {
        // 准备测试数据
        let html = """
        <div class="content">
            <p>这是内容区域</p>
        </div>
        <div id="chapter-list">
            <div class="chapter-item">第一章 测试标题</div>
            <div class="chapter-item">第二章 测试标题</div>
        </div>
        """
        
        // 设置预期结果
        mockScheduler.chapterListRule = "css:#chapter-list"
        mockScheduler.titleRule = "css:.chapter-item"
        mockScheduler.urlRule = "css:.chapter-item|attr:href"
        mockScheduler.mockContainers = [
            "<div class=\"chapter-item\">第一章 测试标题</div><div class=\"chapter-item\">第二章 测试标题</div>"
        ]
        mockScheduler.mockTitles = ["第一章 测试标题", "第二章 测试标题"]
        mockScheduler.mockURLs = []
        
        // 创建规则
        let rule = TocRule(
            chapterList: "css:#chapter-list",
            chapterName: "css:.chapter-item",
            chapterUrl: "css:.chapter-item|attr:href"
        )
        
        // 执行测试
        let items = try parser.parse(
            html: html,
            rule: rule,
            baseURL: nil
        )
        
        // 验证结果
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].chapterTitle, "第一章 测试标题")
        XCTAssertEqual(items[1].chapterTitle, "第二章 测试标题")
    }
    
    // MARK: - 错误处理测试
    
    /// 测试无效规则格式
    func testInvalidRuleFormat() throws {
        // 准备测试数据
        let html = "<div class=\"chapter-item\">第一章 测试标题</div>"
        
        // 设置预期结果
        mockScheduler.shouldThrowError = true
        mockScheduler.error = ParserError.ruleExecutionFailed("无效规则")
        
        // 执行测试并验证错误
        XCTAssertThrowsError(try parser.parseTitles(
            html: html,
            titleRule: "invalid-rule"
        )) { error in
            XCTAssertEqual(error as? ParserError, .ruleExecutionFailed("无效规则"))
        }
    }
    
    /// 测试HTML解析失败
    func testHtmlParsingFailed() throws {
        // 准备测试数据
        let html = "<div class=\"chapter-item\">第一章 测试标题" // 不完整的HTML
        
        // 设置预期结果
        mockScheduler.shouldThrowError = true
        mockScheduler.error = ParserError.htmlParsingFailed
        
        // 执行测试并验证错误
        XCTAssertThrowsError(try parser.parseTitles(
            html: html,
            titleRule: "css:.chapter-item"
        )) { error in
            XCTAssertEqual(error as? ParserError, .htmlParsingFailed)
        }
    }
}

// MARK: - Mock Rule Scheduler

class MockRuleScheduler: RuleScheduler {
    var titleRule: String?
    var urlRule: String?
    var chapterListRule: String?
    var mockTitles: [String] = []
    var mockURLs: [String] = []
    var mockContainers: [String] = []
    var shouldThrowError = false
    var error: Error?
    var evaluateCallCount = 0
    var lastEvaluatedRule: String?
    
    func evaluate(
        rule: String,
        data: Data,
        flow: ParseFlow,
        source: BookSource
    ) throws -> [String] {
        evaluateCallCount += 1
        lastEvaluatedRule = rule
        
        if shouldThrowError {
            throw error ?? ParserError.ruleExecutionFailed("未知错误")
        }

        switch rule {
        case chapterListRule:
            return mockContainers
        case titleRule:
            return mockTitles
        case urlRule:
            return mockURLs
        default:
            return []
        }
    }
}

// MARK: - TocRule 测试

final class TocRuleTests: XCTestCase {
    /// 测试TocRule初始化
    func testTocRuleInit() {
        let rule = TocRule(
            chapterList: "css:#chapter-list",
            chapterName: "css:.chapter-item",
            chapterUrl: "css:.chapter-item a|attr:href"
        )
        
        XCTAssertEqual(rule.chapterList, "css:#chapter-list")
        XCTAssertEqual(rule.chapterName, "css:.chapter-item")
        XCTAssertEqual(rule.chapterUrl, "css:.chapter-item a|attr:href")
        XCTAssertNil(rule.nextTocUrl)
    }
    
    /// 测试旧格式规则解析
    func testOldFormatRuleParsing() throws {
        let rule = try TocRule(ruleString: "css:.chapter-item|css:.chapter-item a|attr:href")
        
        XCTAssertNil(rule.chapterList)
        XCTAssertEqual(rule.chapterName, "css:.chapter-item")
        XCTAssertEqual(rule.chapterUrl, "css:.chapter-item a|attr:href")
        XCTAssertNil(rule.nextTocUrl)
    }
    
    /// 测试无效旧格式规则
    func testInvalidOldFormatRule() {
        XCTAssertThrowsError(try TocRule(ruleString: "single-rule-only")) { error in
            XCTAssertEqual(error as? ParserError, .invalidRuleFormat)
        }
    }
}

// MARK: - TocItem 测试

final class TocItemTests: XCTestCase {
    /// 测试相对URL转换
    func testRelativeURLConversion() {
        let item = TocItem(
            title: "第一章 测试标题",
            url: "/chapter1.html",
            index: 0
        )
        
        let absoluteItem = item.absoluteURL(baseURL: "https://example.com")
        XCTAssertEqual(absoluteItem.chapterURL, "https://example.com/chapter1.html")
    }
    
    /// 测试无效URL转换
    func testInvalidURLConversion() {
        let item = TocItem(
            title: "第一章 测试标题",
            url: "invalid-url",
            index: 0
        )
        
        let absoluteItem = item.absoluteURL(baseURL: "https://example.com")
        XCTAssertEqual(absoluteItem.chapterURL, "invalid-url") // 无效URL保持不变
    }
    
    /// 测试标题后处理
    func testTitlePostProcessing() {
        let testCases: [(input: String, expected: String)] = [
            ("正文卷.第一章 测试标题", "第一章 测试标题"),
            ("VIP章节.第二章 测试标题", "第二章 测试标题"),
            ("第三章 测试标题（求月票）", "第三章 测试标题"),
            ("第四章 测试标题【订阅】", "第四章 测试标题"),
            ("卷_第五章 测试标题", "第五章 测试标题"),
            ("  第六章 测试标题  ", "第六章 测试标题"),
            ("", "未知章节")
        ]
        
        for testCase in testCases {
            let item = TocItem(
                title: testCase.input,
                url: "/chapter.html",
                index: 0
            )
            XCTAssertEqual(item.processedTitle(), testCase.expected)
        }
    }
}
