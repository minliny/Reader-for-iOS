# Core Public API Snapshot

```yaml
version: "1.0.0"
generatedAt: "2026-04-11"
baseline: "Reader-Core freeze gate CI VERIFIED (run 24279408481)"
scope: "frozen_baseline_snapshot"
freezeStatus: "READY_TO_FREEZE"
cleanRoom: true
```

---

## Overview

This document enumerates all public protocols, types, and entrypoints exposed by the Reader-Core frozen baseline. Every symbol is classified by stability boundary: **frozen**, **internal**, or **unstable**.

### Classification Definitions

| Boundary | Meaning |
|----------|---------|
| **frozen** | Contract locked. Breaking changes require explicit baseline re-open + regression pass. |
| **internal** | Used across module boundaries within Core but not intended for external consumers. May evolve with module-level coordination. |
| **unstable** | Experimental or transitional. May change without baseline re-open; consumers must not rely on stability. |

---

## Module: ReaderCoreFoundation

**Boundary**: frozen
**Dependencies**: (none)

| Symbol | Kind | Boundary | Notes |
|--------|------|----------|-------|
| `JSONValue` | enum | frozen | Recursive JSON value type. Equatable, Codable, Sendable. Cases: string, number, bool, object, array, null. |

---

## Module: ReaderCoreModels

**Boundary**: frozen
**Dependencies**: ReaderCoreFoundation

### Data Models

| Symbol | Kind | Boundary | Notes |
|--------|------|----------|-------|
| `BookSource` | struct | frozen | Primary input model. Codable, Equatable, Sendable. Contains LoginDescriptor, DynamicCodingKey. |
| `BookSource.LoginDescriptor` | struct | frozen | Login form descriptor nested in BookSource. |
| `BookSource.DynamicCodingKey` | struct | frozen | Custom CodingKey for dynamic JSON fields. |
| `SearchQuery` | struct | frozen | Search input: keyword, page, pageSize. |
| `SearchResultItem` | struct | frozen | Search output: title, detailURL, author, coverURL, intro, unknownFields. |
| `TOCItem` | struct | frozen | TOC output: chapterTitle, chapterURL, chapterIndex, isVip, unknownFields. |
| `ContentPage` | struct | frozen | Content output: title, content, chapterURL, nextChapterURL, unknownFields. |
| `CSSNode` | struct | frozen | CSS DOM node: type, tagName, textContent, attributes, children. Contains innerHTML/outerHTML/innerText computed properties. |
| `CSSNode.NodeType` | enum | frozen | element, text, comment, document. |

### Compatibility & Failure

| Symbol | Kind | Boundary | Notes |
|--------|------|----------|-------|
| `CompatibilityLevel` | enum | frozen | A, B, C, D. CaseIterable. Not modifiable per project rules. |
| `CompatibilityStatus` | enum | frozen | pass, degraded, fail. |
| `CompatibilityMark` | struct | frozen | level + status + notes. |
| `FailureType` | enum | frozen | 14 values: JSON_INVALID, FIELD_MISSING, RULE_INVALID, RULE_UNSUPPORTED, SEARCH_FAILED, TOC_FAILED, CONTENT_FAILED, NETWORK_POLICY_MISMATCH, COOKIE_REQUIRED, LOGIN_REQUIRED, JS_DEGRADED, JS_UNSUPPORTED, OUTPUT_MISMATCH, CRASH. CaseIterable. Must sync with failure_taxonomy.yml. |
| `Stage` | enum | frozen | NETWORK, REQUEST_BUILD, RESPONSE_PARSE, SEARCH_PARSE, TOC_PARSE, CONTENT_PARSE. |
| `FailureRecord` | struct | frozen | type + reason + sampleId + detail. |

### Error Types (Legacy)

| Symbol | Kind | Boundary | Notes |
|--------|------|----------|-------|
| `ReaderErrorCode` (models) | enum | frozen | Legacy coarse-grained: invalidInput, decodeFailed, networkFailed, parsingFailed, unsupported, unknown. |
| `ReaderError` | struct | frozen | Legacy error: code + message + failure + context. Factory methods: .network(), .config(). |

### Error Mapping

| Symbol | Kind | Boundary | Notes |
|--------|------|----------|-------|
| `ErrorMappingInput` | enum | frozen | httpStatus(Int), networkError(String?), timeout, emptyResponse, selectorMiss(String). |
| `ErrorMappingResult` | struct | frozen | failureType + errorCode + message. |
| `ErrorMapper` | enum | frozen | Static .map() and .readerError(for:) methods. Pure function mapping. |

### Error Logging

| Symbol | Kind | Boundary | Notes |
|--------|------|----------|-------|
| `StructuredErrorLog` | struct | frozen | Structured error record: id, timestamp, errorCode, failureType, stage, ruleField, targetUrl, sampleId, message, context. |
| `ErrorLogger` | protocol | frozen | log(), getErrors(since:), clear(). |
| `InMemoryErrorLogger` | class | frozen | Default implementation with actor-backed store. |

### Environment

| Symbol | Kind | Boundary | Notes |
|--------|------|----------|-------|
| `Environment` | enum | frozen | Static config: siteURL, isDebug, timeoutInterval from env vars. |

---

## Module: ReaderCoreProtocols

**Boundary**: frozen
**Dependencies**: ReaderCoreModels

### Service Contracts

| Symbol | Kind | Boundary | Notes |
|--------|------|----------|-------|
| `BookSourceRepository` | protocol | frozen | save(), allSources(), source(id:). |
| `BookSourceDecoder` | protocol | frozen | decodeBookSource(from:). |
| `SearchService` | protocol | frozen | search(source:query:). |
| `TOCService` | protocol | frozen | fetchTOC(source:detailURL:). |
| `ContentService` | protocol | frozen | fetchContent(source:chapterURL:). |

### Parser Contracts

| Symbol | Kind | Boundary | Notes |
|--------|------|----------|-------|
| `ParseFlow` | enum | frozen | search, toc, content. |
| `ParseRuleSet` | struct | frozen | searchRule, bookInfoRule, tocRule, contentRule. |
| `RuleScheduler` | protocol | frozen | evaluate(rule:data:flow:source:). |
| `SearchParser` | protocol | frozen | parseSearchResponse(_:source:query:). |
| `TOCParser` | protocol | frozen | parseTOCResponse(_:source:detailURL:). |
| `ContentParser` | protocol | frozen | parseContentResponse(_:source:chapterURL:). |

### Network Contracts

| Symbol | Kind | Boundary | Notes |
|--------|------|----------|-------|
| `Cookie` | struct | frozen | name, value, domain, path, expiresAt, secure, httpOnly. Methods: isExpired, matches(domain:path:), matches(path:). |
| `CookieJar` | protocol | frozen | getCookies(for:), setCookie(_:), setCookies(from:domain:), clear(). |
| `CookieJarScopeKey` | struct | frozen | sourceId + host. Hashable, Codable. Static .default sentinel. |
| `ScopedCookieJar` | protocol | frozen | Extends CookieJar with per-scope operations + clearAll(). |
| `CookieScopeManaging` | protocol | frozen | clearCookies(in:). Narrow adapter-side access. |
| `HTTPRequest` | struct | frozen | url, method, headers, requiredHeaders, body, timeout, useCookieJar, requiresCookieJar, cookieScopeKey. |
| `HTTPResponse` | struct | frozen | statusCode, headers, data. |
| `HTTPClient` | protocol | frozen | send(_:). |
| `RequestBuilder` | protocol | frozen | makeSearchRequest(source:query:), makeTOCRequest(source:detailURL:), makeContentRequest(source:chapterURL:). |

### Platform Adapter Contracts

| Symbol | Kind | Boundary | Notes |
|--------|------|----------|-------|
| `HTTPAdapterProtocol` | protocol | frozen | Extends HTTPClient. Marker protocol for adapter registration. |
| `StorageAdapterProtocol` | protocol | frozen | read(key:), write(_:key:), remove(key:). |
| `SchedulerAdapterProtocol` | protocol | frozen | schedule(taskId:executeAfter:), cancel(taskId:). |
| `LogLevel` | enum | frozen | debug, info, warning, error. |
| `LoggingAdapterProtocol` | protocol | frozen | log(_:message:metadata:). |
| `ReaderErrorLoggingProtocol` | protocol | frozen | log(_:), getErrors(since:), clear(). |
| `CoreAdapterDependencies` | struct | frozen | http + storage? + scheduler? + logger?. Dependency injection container. |

### Error Mapping (Contract Layer)

| Symbol | Kind | Boundary | Notes |
|--------|------|----------|-------|
| `ReaderErrorCode` (protocols) | enum | frozen | Fine-grained: NETWORK_TIMEOUT, NETWORK_UNREACHABLE, HTTP_STATUS_INVALID, REDIRECT_NOT_HANDLED, HEADER_REQUIRED, COOKIE_REQUIRED, RESPONSE_EMPTY, RESPONSE_DECODING_FAILED, SEARCH_PARSE_FAILED, TOC_PARSE_FAILED, CONTENT_PARSE_FAILED, RULE_UNSUPPORTED, POLICY_REJECTED, UNKNOWN. Distinct from ReaderCoreModels.ReaderErrorCode. |
| `ReaderFailureStage` | enum | frozen | request_build, network_transport, response_validation, decode, search_parse, toc_parse, content_parse, policy_check, cache_lookup, cache_store. |
| `ReaderErrorContext` | struct | frozen | sampleId, sourceURL, statusCode, details. |
| `MappedReaderError` | struct | frozen | Contract-level error: code + stage + message + context. Named to avoid ambiguity with legacy ReaderError. |

### CSS Executor Error

| Symbol | Kind | Boundary | Notes |
|--------|------|----------|-------|
| `CSSExecutorError` | enum | frozen | invalidSelector, htmlParsingFailed, selectorNotFound, unsupportedSelectorSyntax, attributeNotFound. LocalizedError. |

### Cache Contracts

| Symbol | Kind | Boundary | Notes |
|--------|------|----------|-------|
| `CacheScope` | enum | frozen | search, toc, content. |
| `CacheEntry` | struct | frozen | key, scope, createdAt, ttlSeconds, payload. Computed: isExpired. |
| `CacheStore` | protocol | frozen | get(scope:key:), set(_:), remove(scope:key:), clear(scope:). |
| `CacheRepository` | protocol | frozen | getSearchResponse/setSearchResponse, getTOCResponse/setTOCResponse, getContentResponse/setContentResponse, clear(scope:). |
| `ResponseCacheKey` | struct | frozen | method, normalizedURL, varyHeaders. Hashable, Codable. |
| `CachedHTTPResponse` | struct | frozen | statusCode, headers, body, createdAt, ttl. Computed: isExpired(now:). |
| `ResponseCache` | protocol | frozen | get(_:now:), put(_:for:), remove(_:), removeAll(), purgeExpired(now:). |

### Runtime DI

| Symbol | Kind | Boundary | Notes |
|--------|------|----------|-------|
| `CoreRuntimeDependencyInjection` | enum | frozen | makeDependencies(httpAdapterName:), requireHTTPAdapter(named:). Factory with fatalError for missing adapters. |

---

## Module: ReaderCoreParser

**Boundary**: frozen
**Dependencies**: ReaderCoreModels, ReaderCoreProtocols, ReaderCoreFoundation

| Symbol | Kind | Boundary | Notes |
|--------|------|----------|-------|
| `NonJSParserEngine` | class | frozen | Main parser: init(scheduler:, jsGate:). Conforms to SearchParser, TOCParser, ContentParser. |
| `CSSExecutor` | struct | frozen | CSS selector evaluation against CSSNode trees. |
| `HTMLParser` | struct | frozen | Raw HTML string → CSSNode tree. |
| `SelectorEngine` | struct | frozen | CSS selector matching against parsed DOM. |
| `RuleParser` | struct | frozen | Rule string parsing (split, @attr, @href, etc.). |
| `TocParser` | struct | frozen | TOC-specific parsing logic. |
| `FixtureTocParser` | struct | internal | Test fixture TOC parser. |
| `NonJSRuleScheduler` | struct | frozen | Default RuleScheduler implementation. |
| `JSRenderingGate` | protocol | frozen | Abstraction for JS preprocessing injection. |
| `FixtureTocRegressionRunner` | struct | internal | CI regression runner for TOC fixtures. |
| `FixtureTocRegressionManifest` | struct | internal | Codable manifest for TOC regression. |
| `FixtureTocRegressionSample` | struct | internal | Sample descriptor for TOC regression. |
| `FixtureTocRegressionResult` | struct | internal | Result per sample. |
| `FixtureTocRegressionSummary` | struct | internal | Summary of regression run. |
| `FixtureTocSampleExecutionResult` | struct | internal | Execution detail per sample. |

---

## Module: ReaderCoreNetwork

**Boundary**: frozen
**Dependencies**: ReaderCoreModels, ReaderCoreProtocols, ReaderCoreFoundation

| Symbol | Kind | Boundary | Notes |
|--------|------|----------|-------|
| `NetworkPolicyLayer` | class | frozen | Orchestrates search/toc/content with policy checks. |
| `BasicCookieJar` | class | frozen | In-memory CookieJar + ScopedCookieJar implementation. |
| `BookSourceRequestBuilder` | struct | frozen | RequestBuilder implementation from BookSource config. |
| `LoginBootstrapService` | class | frozen | Login form bootstrap and session establishment. |
| `InMemoryResponseCache` | actor | frozen | In-memory ResponseCache implementation. |
| `NetworkErrorMapper` | struct | frozen | Maps network/HTTP errors to MappedReaderError. |

---

## Module: ReaderCoreCache

**Boundary**: frozen
**Dependencies**: ReaderCoreModels, ReaderCoreProtocols, ReaderCoreFoundation

| Symbol | Kind | Boundary | Notes |
|--------|------|----------|-------|
| `MinimalCacheHTTPClient` | class | frozen | HTTPClient decorator with in-memory cache. MinimalCacheContract. |
| `MinimalCacheContract` | struct | frozen | Current-phase cache contract: keyFields, storeFields, hitCondition, stalePolicy, refreshPolicy. |

---

## Module: ReaderCoreJSRenderer

**Boundary**: unstable
**Dependencies**: ReaderCoreParser, ReaderCoreProtocols

| Symbol | Kind | Boundary | Notes |
|--------|------|----------|-------|
| `JSRenderClient` | protocol | unstable | Experimental JS-capable HTML fetching. fetchHTML(url:timeout:). |
| `JSRenderError` | enum | unstable | invalidURL, timeout, navigationFailed, htmlExtractionFailed, notAvailable. |
| `JSParserEngineFactory` | enum | unstable | Production factory: makeJSCapableParser(scheduler:timeoutMilliseconds:). Wires JSRuntimeDOMBridge into NonJSParserEngine. |

> **Note**: ReaderCoreJSRenderer is marked **unstable** because it depends on JavaScriptCore DOM polyfill which has known limitations (no fetch/XHR in sandbox). The module is isolated from ReaderCoreParser/ReaderCoreNetwork by contract — they must never import it directly.

---

## Module: ReaderPlatformAdapters

**Boundary**: internal
**Dependencies**: ReaderCoreProtocols, ReaderCoreModels

| Symbol | Kind | Boundary | Notes |
|--------|------|----------|-------|
| `HTTPAdapterFactory` | struct | internal | makeDefault(cookieJar:defaultHeaders:followRedirects:). Creates URLSessionHTTPClient. |
| `URLSessionHTTPClient` | class | internal | URLSession-based HTTPAdapterProtocol. |
| `MinimalHTTPAdapter` | struct | internal | Minimal adapter for Linux/non-URLSession environments. |

> **Note**: ReaderPlatformAdapters is marked **internal** because adapters are expected to be replaced per-platform (iOS URLSession, Android OkHttp, etc.). The factory provides a default macOS implementation but the contract boundary is at the protocol level, not the concrete adapter.

---

## Summary Statistics

```yaml
totalModules: 8
totalPublicSymbols: 84
boundaryBreakdown:
  frozen: 73
  internal: 8
  unstable: 3
```

### Frozen Baseline Contract

The following modules form the **frozen baseline contract** and must not change without explicit baseline re-open:

1. ReaderCoreFoundation
2. ReaderCoreModels
3. ReaderCoreProtocols
4. ReaderCoreParser (public symbols only)
5. ReaderCoreNetwork (public symbols only)
6. ReaderCoreCache (public symbols only)

### Internal Modules (evolvable with module-level coordination)

7. ReaderPlatformAdapters — adapter implementations, replaced per-platform

### Unstable Modules (experimental, may change)

8. ReaderCoreJSRenderer — JS rendering capability, known limitations

---

## Clean-Room Statement

```yaml
cleanRoom:
  basis: "Public protocol signatures, type definitions, and freeze gate CI evidence"
  noExternalGplCode: true
  noLegadoAndroidImplementationReference: true
  statement: "本 API 快照仅基于仓库内部 public 声明和 Package.swift 依赖关系产出。不引用外部 GPL 代码，不引用 Legado Android 实现。"
```
