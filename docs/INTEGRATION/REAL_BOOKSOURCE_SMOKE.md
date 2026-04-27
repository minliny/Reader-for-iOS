# Reader-for-iOS Integration Smoke Test Results

## Overview

This document records the integration test results for Reader-for-iOS. It explicitly distinguishes between:
- **Mock Shell Smoke**: Verifies iOS UI/Store/CoreBridge main flow works with mock data
- **Real BookSource Smoke**: Tests with actual BookSource JSON files (currently PENDING)

## Current Status

- **Mock Shell Smoke**: VERIFIED
- **Real BookSource Smoke**: PENDING_INPUT
- **Test Date**: 2026-04-28

---

## A. Mock Shell Smoke Test (Baseline)

### Purpose

Verify that the iOS shell main flow works correctly with mock services. This does NOT represent real book source parsing capability.

### Results

| Step | Result | Notes |
|------|--------|-------|
| Import BookSource | ✓ | JSON parsing works |
| Validate BookSource | ✓ | Mock validation passes |
| Search Books | ✓ | Returns mock results |
| Get Book Detail | ✓ | Returns mock detail |
| Get Chapter List | ✓ | Returns mock chapters |
| Get Chapter Content | ✓ | Returns mock content |
| Add to Bookshelf | ✓ | Saves to BookshelfStore |
| Update Reading Progress | ✓ | Updates progress in store |

### Conclusion

Mock shell smoke test: **PASS**
This confirms iOS UI, Store, and CoreBridge integration are working correctly with mock data.

---

## B. Real BookSource Smoke Test

### Current Status: PENDING_INPUT

Real book source testing has not yet started. Waiting for valid BookSource JSON files to be placed in `test_inputs/booksources/`.

### Input Requirements

- **Input Directory**: `test_inputs/booksources/`
- **File Format**: `*.json`
- **File Content**: Valid BookSource JSON compatible with Legado format

### Test Execution Requirements

For each real book source, the following must be recorded:

| Field | Description | Required |
|-------|-------------|----------|
| source_file | Path to the BookSource JSON file | Yes |
| source_name | Name from the book source | Yes |
| import_result | Result of importing the JSON | Yes |
| validation_result | Result of validateBookSource | Yes |
| search_keyword | Keyword used for search | Yes |
| search_result | Result of searchBooks | Yes |
| detail_result | Result of getBookDetail | Yes |
| chapter_list_result | Result of getChapterList | Yes |
| chapter_content_result | Result of getChapterContent | Yes |
| bookshelf_result | Result of addToBookshelf | Yes |
| reading_progress_result | Result of progress update | Yes |
| failed_step | Which step failed (if any) | No |
| failure_category | Category of failure (see below) | If failed |
| suspected_owner | Which component owns this issue | If failed |
| next_action | What needs to be done | If failed |

### Failure Category Enumeration

| Category | Description |
|----------|-------------|
| ios_ui_state | iOS UI state handling error |
| corebridge_mapping | CoreBridge DTO mapping error |
| reader_core_facade | Reader-Core facade API issue |
| reader_core_parser | Reader-Core parser rule issue |
| reader_core_network | Reader-Core network issue |
| reader_core_policy | Reader-Core policy violation |
| unsupported_capability | Unsupported feature/capability |
| test_data_invalid | Invalid test data format |
| unknown | Unknown failure cause |

### Record Template

```markdown
#### [Source Name]

| Property | Value |
|----------|-------|
| source_file | |
| source_name | |
| import_result | |
| validation_result | |
| search_keyword | |
| search_result | |
| detail_result | |
| chapter_list_result | |
| chapter_content_result | |
| bookshelf_result | |
| reading_progress_result | |
| failed_step | |
| failure_category | |
| suspected_owner | |
| next_action | |
```

### Test Records

No real book source tests have been executed yet.

---

## C. Failed Steps Summary (Real BookSource)

| Source | Step | Failure Category | Suspected Owner | Next Action |
|--------|------|-----------------|-----------------|-------------|
| N/A | N/A | N/A | N/A | Awaiting real book sources |

---

## D. Test Execution Instructions

### To Run Real BookSource Tests

1. Place valid BookSource JSON files in `test_inputs/booksources/`
2. Launch the iOS app
3. Import the book source
4. Execute the full flow: Search → Detail → Chapter List → Reading → Bookshelf
5. Record results in section B using the template provided
6. Update the Failed Steps Summary if any failures occur

### To Report Issues

**iOS Shell Issues**: Fix in Reader-for-iOS repository

**Reader-Core Issues**: Report to Reader-Core repository with:
- Sample ID
- Source JSON
- Failed step
- Failure reason
- Expected behavior
- Regression requirement

---

## Next Steps

1. **User Action Required**: Add real BookSource JSON files to `test_inputs/booksources/`
2. Run real book source integration tests
3. Document failures and assign ownership
4. Fix iOS-side issues in this repository
5. Report Reader-Core issues to Reader-Core repository