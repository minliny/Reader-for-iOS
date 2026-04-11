import XCTest
import ReaderCoreNetwork
import ReaderCoreProtocols

final class BasicCookieJarTests: XCTestCase {
    var jar: BasicCookieJar!

    override func setUp() {
        super.setUp()
        jar = BasicCookieJar()
    }

    override func tearDown() {
        jar = nil
        super.tearDown()
    }

    // MARK: - Legacy unscoped tests (must remain green)

    func testSetAndGetCookie() async throws {
        let cookie = Cookie(name: "session", value: "abc123", domain: "example.com", path: "/")
        await jar.setCookie(cookie)

        let cookies = await jar.getCookies(for: "example.com", path: "/")
        XCTAssertEqual(cookies.count, 1)
        XCTAssertEqual(cookies.first?.name, "session")
        XCTAssertEqual(cookies.first?.value, "abc123")
    }

    func testDomainMatchExact() async throws {
        await jar.setCookie(Cookie(name: "test", value: "val", domain: "example.com", path: "/"))
        let cookies = await jar.getCookies(for: "example.com", path: "/")
        XCTAssertEqual(cookies.count, 1)
    }

    func testDomainMatchDotPrefix() async throws {
        await jar.setCookie(Cookie(name: "test", value: "val", domain: ".example.com", path: "/"))
        let exact = await jar.getCookies(for: "example.com",     path: "/")
        let sub   = await jar.getCookies(for: "sub.example.com", path: "/")
        XCTAssertEqual(exact.count, 1)
        XCTAssertEqual(sub.count, 1)
    }

    func testPathMatch() async throws {
        await jar.setCookie(Cookie(name: "test", value: "val", domain: "example.com", path: "/api"))
        let child  = await jar.getCookies(for: "example.com", path: "/api/v1")
        let other  = await jar.getCookies(for: "example.com", path: "/other")
        XCTAssertEqual(child.count, 1)
        XCTAssertEqual(other.count, 0)
    }

    func testClear() async throws {
        await jar.setCookie(Cookie(name: "test", value: "val", domain: "example.com", path: "/"))
        await jar.clear()
        let after = await jar.getCookies(for: "example.com", path: "/")
        XCTAssertEqual(after.count, 0)
    }

    // MARK: - Isolation tests (new in P3 cookie_jar_isolation)

    // 1. Same scope key → read back the cookie set into that scope.
    func testSameScopeStoresAndReadsCookies() async throws {
        let scope = CookieJarScopeKey(sourceId: "source-A", host: "wensang.com")
        let cookie = Cookie(name: "sess", value: "scoped-value", domain: "wensang.com", path: "/")

        await jar.setCookie(cookie, scopeKey: scope)
        let found = await jar.getCookies(for: "wensang.com", path: "/", scopeKey: scope)

        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.first?.value, "scoped-value",
                       "Reading with the same scopeKey must return the stored cookie")
    }

    // 2. Same host, different sourceId → partitions must not bleed into each other.
    func testDifferentSampleIdsDoNotLeakCookies() async throws {
        let scopeA = CookieJarScopeKey(sourceId: "source-WENSANG",  host: "example.com")
        let scopeB = CookieJarScopeKey(sourceId: "source-XIANGSHU", host: "example.com")

        await jar.setCookie(Cookie(name: "sess", value: "wensang-session", domain: "example.com", path: "/"),  scopeKey: scopeA)
        await jar.setCookie(Cookie(name: "sess", value: "xiangshu-session", domain: "example.com", path: "/"), scopeKey: scopeB)

        let fromA = await jar.getCookies(for: "example.com", path: "/", scopeKey: scopeA)
        let fromB = await jar.getCookies(for: "example.com", path: "/", scopeKey: scopeB)

        XCTAssertEqual(fromA.count, 1)
        XCTAssertEqual(fromA.first?.value, "wensang-session",
                       "scopeA must only see wensang-session")
        XCTAssertEqual(fromB.count, 1)
        XCTAssertEqual(fromB.first?.value, "xiangshu-session",
                       "scopeB must only see xiangshu-session")
    }

    // 3. Same sourceId, different host → must not share cookies.
    func testDifferentHostsDoNotLeakCookies() async throws {
        let scopeWensang  = CookieJarScopeKey(sourceId: "source-ABC", host: "wensang.com")
        let scopeXiangshu = CookieJarScopeKey(sourceId: "source-ABC", host: "xiangshu.com")

        await jar.setCookie(Cookie(name: "tok", value: "tok-wensang",  domain: "wensang.com",  path: "/"), scopeKey: scopeWensang)
        await jar.setCookie(Cookie(name: "tok", value: "tok-xiangshu", domain: "xiangshu.com", path: "/"), scopeKey: scopeXiangshu)

        let cookiesWensang  = await jar.getCookies(for: "wensang.com",  path: "/", scopeKey: scopeWensang)
        let cookiesXiangshu = await jar.getCookies(for: "xiangshu.com", path: "/", scopeKey: scopeXiangshu)
        // Cross-check: reading scopeXiangshu's key against wensang.com host
        let crossLeak = await jar.getCookies(for: "wensang.com", path: "/", scopeKey: scopeXiangshu)

        XCTAssertEqual(cookiesWensang.first?.value, "tok-wensang")
        XCTAssertEqual(cookiesXiangshu.first?.value, "tok-xiangshu")
        XCTAssertEqual(crossLeak.count, 0,
                       "scopeXiangshu must produce zero cookies for wensang.com host")
    }

    // 4. clear(scopeKey:) removes only the target scope.
    func testClearScopeRemovesOnlyScopedCookies() async throws {
        let scopeA = CookieJarScopeKey(sourceId: "src-A", host: "site.com")
        let scopeB = CookieJarScopeKey(sourceId: "src-B", host: "site.com")

        await jar.setCookie(Cookie(name: "c", value: "a", domain: "site.com", path: "/"), scopeKey: scopeA)
        await jar.setCookie(Cookie(name: "c", value: "b", domain: "site.com", path: "/"), scopeKey: scopeB)

        await jar.clear(scopeKey: scopeA)

        let afterA = await jar.getCookies(for: "site.com", path: "/", scopeKey: scopeA)
        let afterB = await jar.getCookies(for: "site.com", path: "/", scopeKey: scopeB)

        XCTAssertEqual(afterA.count, 0, "scopeA must be empty after clear(scopeKey: scopeA)")
        XCTAssertEqual(afterB.count, 1, "scopeB must be unaffected by clearing scopeA")
    }

    // 5. clearAll() wipes every scope partition.
    func testClearAllRemovesEverything() async throws {
        let scopeA = CookieJarScopeKey(sourceId: "src-A", host: "a.com")
        let scopeB = CookieJarScopeKey(sourceId: "src-B", host: "b.com")

        await jar.setCookie(Cookie(name: "c", value: "a", domain: "a.com", path: "/"), scopeKey: scopeA)
        await jar.setCookie(Cookie(name: "c", value: "b", domain: "b.com", path: "/"), scopeKey: scopeB)
        // Also write into the default (unscoped) partition.
        await jar.setCookie(Cookie(name: "c", value: "default", domain: "c.com", path: "/"))

        await jar.clearAll()

        let afterA       = await jar.getCookies(for: "a.com", path: "/", scopeKey: scopeA)
        let afterB       = await jar.getCookies(for: "b.com", path: "/", scopeKey: scopeB)
        let afterDefault = await jar.getCookies(for: "c.com", path: "/")

        XCTAssertEqual(afterA.count, 0,       "scopeA must be empty after clearAll()")
        XCTAssertEqual(afterB.count, 0,       "scopeB must be empty after clearAll()")
        XCTAssertEqual(afterDefault.count, 0, "default scope must be empty after clearAll()")
    }
}
