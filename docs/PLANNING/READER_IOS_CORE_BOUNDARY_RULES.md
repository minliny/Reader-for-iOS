# Reader for iOS — Core Boundary Rules

Generated: 2026-05-12T23:55+08:00
Status: ENFORCED
Last boundary check: PASS (56 files, 0 violations)

---

## 1. Allowed Core Public API Imports

These Reader-Core products MAY be imported in iOS source files:

| Product | Purpose | Example usage |
|---|---|---|
| `ReaderCoreModels` | Core DTO types | `BookSource`, `SearchResultItem`, `TOCItem`, `ContentPage`, `ReaderError` |
| `ReaderCoreProtocols` | Core service contracts | `SearchService`, `TOCService`, `ContentService` |
| `ReaderCoreFoundation` | Core foundation types | Utility types shared across Core |
| `ReaderPlatformAdapters` | Platform adapter protocols | WKWebView adapter, iOS platform utilities |
| `ReaderAppSupport` | iOS-side app support models | `BookshelfItem`, `ReadingProgress`, `ReaderDisplaySettings`, `SourceIdentity` |

### Import examples (COMPLIANT)

```swift
// ✅ Allowed: Core DTO types
import ReaderCoreModels

// ✅ Allowed: Core protocol contracts
import ReaderCoreProtocols

// ✅ Allowed: Platform adapter protocols
import ReaderPlatformAdapters

// ✅ Allowed: iOS app support models
import ReaderAppSupport

// ✅ Allowed: Using Core types
let bookSource: BookSource = ...
let items: [SearchResultItem] = ...
let error: ReaderError = ...
```

---

## 2. Forbidden Core Internal Imports

These Reader-Core products MUST NOT be imported in iOS source files within restricted paths:

| Product | Reason |
|---|---|
| `ReaderCoreParser` | Contains parser internals (SelectorEngine, NonJSRuleScheduler, NonJSParserEngine, etc.) |
| `ReaderCoreNetwork` | Contains network internals (URLSessionHTTPClient, BasicCookieJar, etc.) |
| `ReaderCoreCache` | Contains cache internals |
| `ReaderCoreExecution` | Contains execution internals |

### Restricted paths (where forbidden imports are checked)

- `iOS/App/`
- `iOS/CoreIntegration/`
- `iOS/Features/`
- `iOS/Modules/`
- `iOS/Shell/`
- `iOS/Tests/`

### Import examples (VIOLATION)

```swift
// ❌ Forbidden: Core parser internals
import ReaderCoreParser

// ❌ Forbidden: Core network internals
import ReaderCoreNetwork

// ❌ Forbidden: Core cache internals
import ReaderCoreCache

// ❌ Forbidden: Referencing internal symbols
let engine = NonJSRuleScheduler()        // NEVER in iOS
let selector = SelectorEngine()          // NEVER in iOS
let evaluator = SimpleXPathEvaluator()   // NEVER in iOS
```

---

## 3. Forbidden: Copy/Translate/Rewrite Legado Android Source

- Do NOT copy Kotlin/Java source from Legado Android into Reader for iOS.
- Do NOT translate Legado Android parsing logic into Swift.
- Do NOT rewrite Legado Android algorithms as iOS-native implementations.

All parser/runtime logic belongs in Reader-Core. If a capability exists in Legado Android but not in Reader-Core, it is a Core gap — not something to reimplement in iOS.

---

## 4. Forbidden: Implement Core Parser/Runtime in iOS

The following implementations MUST NOT exist in Reader for iOS:

- Book source URL DSL parser
- Rule engine / rule evaluator
- CSS/XPath selector engine
- JSONPath evaluator
- HTTP request builder for book sources
- Cookie jar / session manager for book sources
- JavaScript runtime for book source rules
- Content extractor / text decoder
- Chapter list parser
- Search result parser
- Book detail parser
- Login flow handler

All of the above are Reader-Core responsibilities.

---

## 5. Core Gap Handling Process

When a needed Core public API is missing:

```
1. IDENTIFY: What exactly is missing?
2. DOCUMENT: Write gap in docs/PLANNING/ with MOVED_TO_CORE tag
3. STOP: Do NOT implement in iOS
4. HANDOFF: Report gap to Reader-Core repo
5. PROCEED: Work on iOS tasks that don't depend on this gap
6. MARK: Dependent iOS task as BLOCKED or MOVED_TO_CORE
```

### Example (COMPLIANT gap handling)

```yaml
# In LOOP_BACKLOG.yml
- id: CORE-GAP-XXX
  title: "Missing Core public API for X"
  status: MOVED_TO_CORE
  implementation_scope: "Core needs to expose X as public API"
```

### Example (VIOLATION — do NOT do this)

```swift
// ❌ NEVER: Work around missing Core API by implementing it locally
public final class MyOwnBookSourceParser {
    func parseSearchHTML(_ html: String) -> [SearchResultItem] {
        // Copying Core logic into iOS — FORBIDDEN
    }
}
```

---

## 6. Boundary Check Script

Location: `scripts/check_ios_boundary.sh`

Run before and after every development session:

```bash
bash scripts/check_ios_boundary.sh
```

Expected output:
```
iOS boundary gate
checked_files=56
...
result=PASS
```

If result=FAIL, fix violations before proceeding. Do NOT weaken the check by removing forbidden modules.

### What the script checks

1. **Forbidden root paths**: `Core/`, `samples/`, `tools/`, `Adapters/`, `Platforms/`, `Package.swift` (at repo root)
2. **Forbidden docs**: Core-specific docs that should not leak into iOS repo
3. **Forbidden workflows**: Core-specific CI workflows
4. **Forbidden imports**: `ReaderCoreNetwork`, `ReaderCoreParser`, `ReaderCoreCache`, `ReaderCoreExecution` in restricted paths
5. **Legacy path references**: Old Core path dependencies in Package.swift or CI configs

---

## 7. Violation Examples (from history)

These were previously found and FIXED (April 2026):

| File | Violation | Resolution |
|---|---|---|
| `iOS/CoreIntegration/ReadingFlowCoordinator.swift` | Imported `ReaderCoreNetwork`, `ReaderCoreParser`, `ReaderCoreCache` | Removed illegal imports; kept only `ReaderCoreModels`, `ReaderCoreProtocols` |
| `iOS/CoreIntegration/DefaultSearchService.swift` | Imported `ReaderCoreNetwork`, `ReaderCoreParser` | Removed unused imports |
| `iOS/CoreIntegration/DefaultTOCService.swift` | Imported `ReaderCoreNetwork`, `ReaderCoreParser` | Removed unused imports |
| `iOS/CoreIntegration/DefaultContentService.swift` | Imported `ReaderCoreNetwork`, `ReaderCoreParser` | Removed unused imports |

---

## 8. Compliance Examples

### Example 1: Search feature (COMPLIANT)

```swift
// iOS/Features/Search/SearchViewModel.swift
import ReaderCoreModels        // ✅ For SearchResultItem
// Does NOT import ReaderCoreParser  ✅

final class SearchViewModel: ObservableObject {
    private let provider = ReaderCoreServiceProvider.shared

    func search(keyword: String) async {
        let state = await provider.searchBooks(keyword: keyword, page: 1)
        // Uses CoreBridge facade, NOT direct Core parser
    }
}
```

### Example 2: CoreBridge service facade (COMPLIANT)

```swift
// iOS/CoreBridge/ReaderCoreServiceProvider.swift
import ReaderCoreModels        // ✅ For BookSource, SearchResultItem, etc.
// Does NOT import ReaderCoreParser  ✅
// Does NOT import ReaderCoreNetwork ✅

public final class ReaderCoreServiceProvider {
    // Delegates to mock or real service
    // Never touches Core internals directly
}
```

### Example 3: Shell assembly (COMPLIANT)

```swift
// iOS/Shell/ShellAssembly.swift
import ReaderCoreModels        // ✅ For DTO types
import ReaderCoreProtocols     // ✅ For service protocols
// Does NOT import ReaderCoreParser  ✅

public enum ShellAssembly {
    public static func makeMockReadingFlowCoordinator() -> ReadingFlowCoordinator {
        // Uses ReaderCoreServiceProvider (CoreBridge)
        // Never touches Core internals
    }
}
```

---

## 9. Pre/Post Development Checks

### Before starting development

```bash
# 1. Check boundary
bash scripts/check_ios_boundary.sh

# 2. Check git status
git status --short

# 3. Review what changed
git diff --stat
```

### After completing development

```bash
# 1. Re-run boundary check
bash scripts/check_ios_boundary.sh

# 2. Verify no new forbidden imports
grep -RInE "import[[:space:]]+(ReaderCoreParser|ReaderCoreNetwork|ReaderCoreCache|ReaderCoreExecution)" iOS/ --include="*.swift"

# 3. Verify build
xcodebuild build -project ReaderForIOS.xcodeproj -scheme ReaderForIOSApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# 4. If build fails, attribute failure correctly
#    - Core-side failure → document, do NOT fix Core code in iOS repo
#    - iOS-side failure → fix in iOS code only
```

---

## 10. Quick Reference

| Question | Answer |
|---|---|
| Can I import `ReaderCoreModels`? | YES |
| Can I import `ReaderCoreProtocols`? | YES |
| Can I import `ReaderCoreFoundation`? | YES |
| Can I import `ReaderPlatformAdapters`? | YES |
| Can I import `ReaderCoreParser`? | NO |
| Can I import `ReaderCoreNetwork`? | NO |
| Can I copy Legado Android code? | NO |
| Can I implement a book source parser in iOS? | NO |
| Can I work around a missing Core API? | NO — report gap, work on other tasks |
| Can I add mock data for UI development? | YES — MockReaderCoreService is the approved pattern |
| Can I build UI without real Core? | YES — mock-driven development is approved |
