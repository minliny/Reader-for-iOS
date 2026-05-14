# Reader for iOS — Network E2E Policy

Generated: 2026-05-14
Status: ACTIVE

---

## 1. Policy

Network access for real Core E2E validation is **ALLOWED_ONCE per source** under strict controls:

| Rule | Value |
|------|-------|
| Max requests per cycle | 1 search OR 1 TOC OR 1 content |
| Max retries | 1 |
| Allowed protocols | HTTPS only |
| Cookie/Login | DENIED |
| JS required | DENIED |
| WebView required | DENIED |
| Recursive/pagination | DENIED until fixture replay verified |
| Crawling/discovery | DENIED |
| Snapshot required | YES — every network response must be saved as local fixture |
| Snapshot sensitivity check | YES — strip cookies/tokens/personal data |
| Offline replay first | YES — if snapshot exists, replay from fixture, do NOT re-fetch |

---

## 2. Whitelist

| Source ID | Name | Host | Status |
|-----------|------|------|--------|
| `qianfanxs_user_provided` | 千帆小说 | `www.qianfanxs.com` | APPROVED for WebView render only |

**Missing for search/TOC/content E2E**: Book source JSON with search/TOC/content rules.

---

## 3. Required Book Source JSON

To enable real SearchService E2E, user must provide or create a book source JSON file containing:

```json
{
  "bookSourceName": "千帆小说",
  "bookSourceUrl": "https://www.qianfanxs.com",
  "bookSourceGroup": "测试",
  "ruleSearch": {
    "searchUrl": "https://www.qianfanxs.com/search.html?keyword={{key}}",
    "bookList": "...",
    "name": "...",
    "author": "...",
    "detailURL": "..."
  },
  "ruleTOC": {
    "chapterList": "...",
    "chapterName": "...",
    "chapterURL": "..."
  },
  "ruleContent": {
    "content": "..."
  }
}
```

Or a pre-built fixture file at: `iOS/Tests/Fixtures/BookSources/qianfanxs.json`

---

## 4. Snapshot Directory

```
iOS/Tests/Fixtures/NetworkSnapshots/
  ├── {source_id}/
  │   ├── search_{keyword}_{timestamp}.json
  │   ├── toc_{book_url_hash}_{timestamp}.json
  │   ├── content_{chapter_url_hash}_{timestamp}.json
  │   └── metadata.yml
```

---

## 5. E2E Task Sequence

| Order | Task | Depends On | Network |
|-------|------|-----------|---------|
| 1 | IOS-3A-NET-001 | Book source JSON | ALLOWED_ONCE |
| 2 | IOS-3A-FIXTURE-001 | IOS-3A-NET-001 | DENIED |
| 3 | IOS-4A-NET-001 | Book source JSON | ALLOWED_ONCE |
| 4 | IOS-4A-FIXTURE-001 | IOS-4A-NET-001 | DENIED |
| 5 | IOS-5A-NET-001 | Book source JSON | ALLOWED_ONCE |
| 6 | IOS-5A-FIXTURE-001 | IOS-5A-NET-001 | DENIED |
