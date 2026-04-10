import XCTest
import ReaderCoreProtocols
@testable import ReaderCoreNetwork

final class InMemoryResponseCacheTests: XCTestCase {

    private var cache: InMemoryResponseCache!

    override func setUp() {
        super.setUp()
        cache = InMemoryResponseCache()
    }

    // MARK: - put / get basics

    func testPutThenGetReturnsStoredResponse() async {
        let key = ResponseCacheKey(method: "GET", normalizedURL: "https://example.com/search")
        let response = makeResponse(statusCode: 200, ttl: 300)
        await cache.put(response: response, key: key)

        let result = await cache.get(key: key, now: Date())
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.statusCode, 200)
    }

    func testGetOnEmptyCacheReturnsNil() async {
        let key = ResponseCacheKey(method: "GET", normalizedURL: "https://example.com/missing")
        let result = await cache.get(key: key, now: Date())
        XCTAssertNil(result)
    }

    func testPutOverwritesPreviousEntry() async {
        let key = ResponseCacheKey(method: "GET", normalizedURL: "https://example.com/toc")
        await cache.put(response: makeResponse(statusCode: 200, ttl: 300), key: key)
        await cache.put(response: makeResponse(statusCode: 204, ttl: 300), key: key)

        let result = await cache.get(key: key, now: Date())
        XCTAssertEqual(result?.statusCode, 204)
    }

    // MARK: - TTL / expiry

    func testExpiredEntryReturnsMiss() async {
        let key = ResponseCacheKey(method: "GET", normalizedURL: "https://example.com/expired")
        let past = Date(timeIntervalSinceNow: -400)
        let response = makeResponse(statusCode: 200, ttl: 300, createdAt: past)
        await cache.put(response: response, key: key)

        let result = await cache.get(key: key, now: Date())
        XCTAssertNil(result, "Entry expired 100 s ago must be a miss")
    }

    func testNotYetExpiredEntryReturnsHit() async {
        let key = ResponseCacheKey(method: "GET", normalizedURL: "https://example.com/fresh")
        let past = Date(timeIntervalSinceNow: -100)
        let response = makeResponse(statusCode: 200, ttl: 300, createdAt: past)
        await cache.put(response: response, key: key)

        let result = await cache.get(key: key, now: Date())
        XCTAssertNotNil(result, "Entry with 200 s remaining must be a hit")
    }

    func testEntryExpiresExactlyAtBoundary() async {
        let key = ResponseCacheKey(method: "GET", normalizedURL: "https://example.com/boundary")
        let createdAt = Date(timeIntervalSinceNow: -300)
        let response = makeResponse(statusCode: 200, ttl: 300, createdAt: createdAt)
        await cache.put(response: response, key: key)

        // now == createdAt + 300; timeIntervalSince == 300 > 300 is false → not expired
        let now = createdAt.addingTimeInterval(300)
        let result = await cache.get(key: key, now: now)
        // exactly at boundary: 300 > 300 → false → still valid
        XCTAssertNotNil(result)
    }

    // MARK: - purgeExpired

    func testPurgeExpiredRemovesOnlyExpiredEntries() async {
        let validKey = ResponseCacheKey(method: "GET", normalizedURL: "https://example.com/valid")
        let expiredKey = ResponseCacheKey(method: "GET", normalizedURL: "https://example.com/expired2")

        let past = Date(timeIntervalSinceNow: -600)
        await cache.put(response: makeResponse(statusCode: 200, ttl: 300, createdAt: past), key: expiredKey)
        await cache.put(response: makeResponse(statusCode: 200, ttl: 3600), key: validKey)

        await cache.purgeExpired(now: Date())

        let expiredResult = await cache.get(key: expiredKey, now: Date())
        let validResult = await cache.get(key: validKey, now: Date())

        XCTAssertNil(expiredResult, "Expired entry must be removed by purge")
        XCTAssertNotNil(validResult, "Valid entry must survive purge")
    }

    func testPurgeExpiredOnEmptyCacheIsNoOp() async {
        await cache.purgeExpired(now: Date())
        // Must not crash or hang; no assertions needed beyond reaching this line
    }

    // MARK: - remove

    func testRemoveDeletesSingleEntry() async {
        let key = ResponseCacheKey(method: "GET", normalizedURL: "https://example.com/remove-me")
        await cache.put(response: makeResponse(statusCode: 200, ttl: 300), key: key)
        await cache.remove(key: key)

        let result = await cache.get(key: key, now: Date())
        XCTAssertNil(result)
    }

    func testRemoveDoesNotAffectOtherEntries() async {
        let key1 = ResponseCacheKey(method: "GET", normalizedURL: "https://example.com/one")
        let key2 = ResponseCacheKey(method: "GET", normalizedURL: "https://example.com/two")
        await cache.put(response: makeResponse(statusCode: 200, ttl: 300), key: key1)
        await cache.put(response: makeResponse(statusCode: 200, ttl: 300), key: key2)
        await cache.remove(key: key1)

        let result = await cache.get(key: key2, now: Date())
        XCTAssertNotNil(result, "Removing key1 must not affect key2")
    }

    func testRemoveNonExistentKeyIsNoOp() async {
        let key = ResponseCacheKey(method: "GET", normalizedURL: "https://example.com/ghost")
        await cache.remove(key: key)
        // Must not crash
    }

    // MARK: - removeAll

    func testRemoveAllClearsAllEntries() async {
        let key1 = ResponseCacheKey(method: "GET", normalizedURL: "https://example.com/a")
        let key2 = ResponseCacheKey(method: "POST", normalizedURL: "https://example.com/b")
        await cache.put(response: makeResponse(statusCode: 200, ttl: 300), key: key1)
        await cache.put(response: makeResponse(statusCode: 201, ttl: 300), key: key2)
        await cache.removeAll()

        let r1 = await cache.get(key: key1, now: Date())
        let r2 = await cache.get(key: key2, now: Date())
        XCTAssertNil(r1)
        XCTAssertNil(r2)
    }

    // MARK: - varyHeaders differentiation

    func testDifferentVaryHeadersProduceCacheMiss() async {
        let key1 = ResponseCacheKey(
            method: "GET",
            normalizedURL: "https://example.com/search",
            varyHeaders: ["Accept-Language": "zh-CN"]
        )
        let key2 = ResponseCacheKey(
            method: "GET",
            normalizedURL: "https://example.com/search",
            varyHeaders: ["Accept-Language": "en-US"]
        )
        await cache.put(response: makeResponse(statusCode: 200, ttl: 300, body: Data("zh".utf8)), key: key1)

        let result = await cache.get(key: key2, now: Date())
        XCTAssertNil(result, "Different varyHeaders must not produce a hit")
    }

    func testSameVaryHeadersProduceCacheHit() async {
        let key1 = ResponseCacheKey(
            method: "GET",
            normalizedURL: "https://example.com/toc",
            varyHeaders: ["X-Token": "abc123"]
        )
        let key2 = ResponseCacheKey(
            method: "GET",
            normalizedURL: "https://example.com/toc",
            varyHeaders: ["X-Token": "abc123"]
        )
        await cache.put(response: makeResponse(statusCode: 200, ttl: 300), key: key1)

        let result = await cache.get(key: key2, now: Date())
        XCTAssertNotNil(result, "Identical varyHeaders must produce a hit")
    }

    func testEmptyVaryHeadersProduceCacheHit() async {
        let key1 = ResponseCacheKey(method: "GET", normalizedURL: "https://example.com/content")
        let key2 = ResponseCacheKey(method: "GET", normalizedURL: "https://example.com/content")
        await cache.put(response: makeResponse(statusCode: 200, ttl: 300), key: key1)

        let result = await cache.get(key: key2, now: Date())
        XCTAssertNotNil(result)
    }

    // MARK: - Method normalization

    func testLowercaseMethodEqualsUppercaseMethod() {
        let lower = ResponseCacheKey(method: "get", normalizedURL: "https://example.com")
        let upper = ResponseCacheKey(method: "GET", normalizedURL: "https://example.com")
        XCTAssertEqual(lower, upper, "method must be uppercased in init")
    }

    func testMixedCaseMethodNormalized() async {
        let putKey = ResponseCacheKey(method: "Get", normalizedURL: "https://example.com/norm")
        let getKey = ResponseCacheKey(method: "GET", normalizedURL: "https://example.com/norm")
        await cache.put(response: makeResponse(statusCode: 200, ttl: 300), key: putKey)

        let result = await cache.get(key: getKey, now: Date())
        XCTAssertNotNil(result, "Mixed-case method must normalize to same key as uppercase")
    }

    // MARK: - Helpers

    private func makeResponse(
        statusCode: Int,
        ttl: TimeInterval,
        body: Data = Data("response-body".utf8),
        createdAt: Date = Date()
    ) -> CachedHTTPResponse {
        CachedHTTPResponse(
            statusCode: statusCode,
            headers: ["Content-Type": "text/plain"],
            body: body,
            createdAt: createdAt,
            ttl: ttl
        )
    }
}
