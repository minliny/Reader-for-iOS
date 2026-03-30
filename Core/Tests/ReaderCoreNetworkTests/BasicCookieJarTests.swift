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

    func testSetAndGetCookie() async throws {
        let cookie = Cookie(
            name: "session",
            value: "abc123",
            domain: "example.com",
            path: "/"
        )
        await jar.setCookie(cookie)

        let cookies = await jar.getCookies(for: "example.com", path: "/")
        XCTAssertEqual(cookies.count, 1)
        XCTAssertEqual(cookies.first?.name, "session")
        XCTAssertEqual(cookies.first?.value, "abc123")
    }

    func testDomainMatchExact() async throws {
        let cookie = Cookie(
            name: "test",
            value: "val",
            domain: "example.com",
            path: "/"
        )
        await jar.setCookie(cookie)

        let cookies = await jar.getCookies(for: "example.com", path: "/")
        XCTAssertEqual(cookies.count, 1)
    }

    func testDomainMatchDotPrefix() async throws {
        let cookie = Cookie(
            name: "test",
            value: "val",
            domain: ".example.com",
            path: "/"
        )
        await jar.setCookie(cookie)

        let cookies1 = await jar.getCookies(for: "example.com", path: "/")
        XCTAssertEqual(cookies1.count, 1)

        let cookies2 = await jar.getCookies(for: "sub.example.com", path: "/")
        XCTAssertEqual(cookies2.count, 1)
    }

    func testPathMatch() async throws {
        let cookie = Cookie(
            name: "test",
            value: "val",
            domain: "example.com",
            path: "/api"
        )
        await jar.setCookie(cookie)

        let cookies1 = await jar.getCookies(for: "example.com", path: "/api/v1")
        XCTAssertEqual(cookies1.count, 1)

        let cookies2 = await jar.getCookies(for: "example.com", path: "/other")
        XCTAssertEqual(cookies2.count, 0)
    }

    func testClear() async throws {
        let cookie = Cookie(name: "test", value: "val", domain: "example.com", path: "/")
        await jar.setCookie(cookie)
        await jar.clear()
        let cookies = await jar.getCookies(for: "example.com", path: "/")
        XCTAssertEqual(cookies.count, 0)
    }
}
