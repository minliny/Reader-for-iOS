# Source ID Strategy Document

## Status

**Status**: COMPLETE
**Last Updated**: 2026-04-29

---

## 1. Implementation Summary

### Current Implementation

The source identity strategy has been implemented with the following components:

- `SourceIdentity` struct - unified identity representation
- `SourceIdentityFactory` - factory for creating identities from various sources
- `SourceIdentity.unknown` - fallback for unknown sources
- `BookshelfItem.sourceName` - new field to store source name

### Migration Path

The previous implementation used `bookURL` directly as `sourceID`. This has been replaced with:

```swift
// Before (deprecated)
sourceID: result.detailURL  // bookURL as sourceID

// After (current)
let identity = SourceIdentityFactory.from(searchResult: result)
sourceID: identity.id  // Proper source identity
```

---

## 2. SourceIdentity Data Structure

```swift
public struct SourceIdentity: Codable, Equatable, Hashable {
    public let id: String
    public let name: String?
    public let baseURL: String?

    public static let unknown = SourceIdentity(id: "unknown", name: nil, baseURL: nil)
}
```

### Fields

| Field | Description |
|-------|-------------|
| id | Unique identifier for the source |
| name | Optional source name |
| baseURL | Optional base URL for the source |

---

## 3. SourceIdentityFactory Strategy

```swift
public enum SourceIdentityFactory {
    public static func from(searchResult: SearchResultItem) -> SourceIdentity
    public static func fallback(name: String?, url: String?, rawJSON: String?) -> String
}
```

### ID Generation Strategy

1. **Priority 1**: Use `detailURL` from SearchResultItem as deterministic ID
2. **Fallback**: Generate from `source name` if available
3. **Final Fallback**: Use `"unknown"` identifier

### Deterministic Fallback Examples

| Input | Output |
|-------|--------|
| name="TestSource", url=nil | "source_TestSource" |
| name=nil, url="https://example.com" | "https://example.com" |
| name=nil, url=nil, rawJSON="{...}" | "source_123456" (hash) |
| name=nil, url=nil, rawJSON=nil | "unknown" |

### Determinism Guarantee

- Same input always produces same output
- Different inputs may produce different outputs
- Hash-based fallback uses deterministic hash function
- No randomness involved in ID generation

---

## 4. Unknown Source Policy

When source identity cannot be determined:

```swift
// Use the predefined unknown identity
let identity = SourceIdentity.unknown
// id = "unknown", name = nil, baseURL = nil
```

### Implications of Unknown Source

| Aspect | Impact |
|--------|--------|
| Bookshelf | Item stored with "unknown" source |
| Sync | Cannot sync properly until resolved |
| Deduplication | May cause duplicates |
| Migration | Requires manual intervention |

---

## 5. Why Not Rely on Parser Internal Models

The implementation intentionally does not rely on Reader-Core parser internal models because:

| Reason | Description |
|--------|-------------|
| Clean-room principle | Parser internal models may change without notice |
| Stability | iOS shell should not be coupled to Core internals |
| Maintainability | Changes in Core should not break iOS shell |
| Testability | iOS shell can use mock data independently |

---

## 6. Code Locations

### New Files

- `iOS/App/Models/SourceIdentity.swift`

### Modified Files

- `iOS/App/Models/BookshelfItem.swift` - Added `sourceName` field
- `iOS/Features/BookDetail/BookDetailView.swift` - Uses SourceIdentityFactory
- `iOS/Features/Reader/ReaderViewModel.swift` - Uses SourceIdentity

### Removed Temporary Workarounds

- `sourceID: result.detailURL` in BookDetailView
- `sourceID = bookURL` in ReaderViewModel

---

## 7. Real BookSource Smoke Pre-Check

Before running real book source smoke tests:

### Required Pre-Checks

| Check | Description | Status |
|-------|-------------|--------|
| SourceIdentity | Must be COMPLETE | ✓ |
| CoreBridge | Must be stable | PENDING |
| MockService | Must support all endpoints | ✓ |
| Test Input | Real BookSource JSON needed | PENDING |

### Input Requirements

- Place real BookSource JSON files in `test_inputs/booksources/`
- Each file must be valid JSON
- Each file must contain at least `name` and `bookSourceUrl` fields

---

## 8. Cloud Sync Provider Pre-Conditions

Cloud Sync Provider development requires:

| Condition | Description | Status |
|-----------|-------------|--------|
| SourceIdentity | Must be COMPLETE | ✓ |
| Real BookSource | Must be verified | PENDING |
| Reader-Core | Must be stable | PENDING |
| SyncContract | Must be designed | ✓ |

---

## 9. Remaining Limitations

| Limitation | Description | Mitigation |
|------------|-------------|------------|
| Unknown source | SearchResultItem may not have source info | Use SourceIdentity.unknown |
| Real BookSource ID | Not yet integrated | Wait for real book source integration |

---

## Conclusion

The source identity strategy is now **COMPLETE**. The system uses `SourceIdentity` for proper source identification, with deterministic fallback strategies and clear migration paths for future enhancements.

**Next Steps**:
1. Wait for Reader-Core to stabilize
2. Add real BookSource JSON files to `test_inputs/booksources/`
3. Run real book source smoke tests
4. Evaluate cloud sync provider readiness