# Fixture Infrastructure Specification

```yaml
version: "1.0.0"
generatedAt: "2026-04-11"
baseline: "Reader-Core freeze gate CI VERIFIED (run 24279408481)"
scope: "fixture_infrastructure_definition"
status: "spec_only — no implementation in M1"
```

---

## Overview

This document defines the fixture infrastructure specification for the Reader-Core project. It formalizes naming conventions, directory structure, fixture types, and binding rules between fixtures, compat_matrix, and reports.

All conventions are derived from the existing 729 sample files in the `samples/` directory. This spec does not invent new conventions — it codifies existing patterns.

---

## fixtureInfra

### fixtureTypes

```yaml
fixtureTypes:
  - type: html
    description: "HTML response fixture for parser input"
    fileExtensions: [".html"]
    contentKind: "raw_http_response_body"
    usage: "Parser input for search/toc/content flow testing"
    examples:
      - "samples/fixtures/html/sample_001_search.html"
      - "samples/fixtures/html/wensang_search.html"
      - "samples/fixtures/html/cookie_session_first_set_cookie.html"

  - type: json
    description: "JSON fixture for structured data input"
    fileExtensions: [".json"]
    contentKind: "structured_json"
    usage: "Error mapping test input, API response simulation"
    examples:
      - "samples/fixtures/json/error_http_404.json"
      - "samples/fixtures/json/policy_http_404.json"

  - type: text
    description: "Plain text fixture for simple input"
    fileExtensions: [".txt"]
    contentKind: "plain_text"
    usage: "Policy header text, timeout simulation, cache content"
    examples:
      - "samples/fixtures/text/error_timeout.txt"
      - "samples/fixtures/text/policy_header_search.txt"
      - "samples/fixtures/text/cache_content_first.txt"

  - type: toc
    description: "TOC-specific fixture (JSON or HTML)"
    fileExtensions: [".json", ".html"]
    contentKind: "toc_structure_or_response"
    usage: "TOC parser regression and contract testing"
    examples:
      - "samples/fixtures/toc/fixture_toc_selector_miss.json"
      - "samples/fixtures/toc/fixture_toc_count_mismatch.html"

  - type: booksource
    description: "BookSource JSON configuration"
    fileExtensions: [".json"]
    contentKind: "booksource_config"
    usage: "Source definition for integration testing"
    directory: "samples/booksources/"
    examples:
      - "samples/booksources/sample_001.json"

  - type: redirect
    description: "HTTP redirect chain fixture (placeholder)"
    fileExtensions: [".yml"]
    contentKind: "redirect_sequence"
    usage: "Redirect handling test input"
    directory: "samples/fixtures/redirects/"
    current_state: "empty — not yet populated"
```

### expectedTypes

```yaml
expectedTypes:
  - type: search_expected
    description: "Expected search result output"
    fileExtensions: [".json"]
    directory: "samples/expected/search/"
    schema: "Array of SearchResultItem JSON"

  - type: toc_expected
    description: "Expected TOC output"
    fileExtensions: [".json"]
    directory: "samples/expected/toc/"
    schema: "Array of TOCItem JSON"

  - type: content_expected
    description: "Expected content output"
    fileExtensions: [".json"]
    directory: "samples/expected/content/"
    schema: "ContentPage JSON"

  - type: error_expected
    description: "Expected error mapping output"
    fileExtensions: [".json"]
    directory: "samples/expected/error/"
    schema: "Error mapping result JSON"
```

---

### namingConvention

```yaml
namingConvention:
  html_fixtures:
    pattern: "{sample_id}_{flow}.html"
    components:
      sample_id: "Lowercase sample identifier (e.g., sample_001, wensang, cookie_session)"
      flow: "One of: search, toc, content"
    variants:
      multi_step: "{capability}_{scenario}_{step_descriptor}.html"
      examples:
        - "sample_001_search.html"
        - "cache_search_first.html"
        - "cache_search_second_changed.html"
        - "cookie_session_first_set_cookie.html"
        - "cookie_session_without_cookie.html"
        - "cookie_session_with_cookie_success.html"
        - "cookie_login_required.html"
        - "cookie_login_success_set_cookie.html"
        - "cookie_login_search_success.html"

  json_fixtures:
    pattern: "{descriptor}.json"
    examples:
      - "error_http_404.json"
      - "policy_http_404.json"

  text_fixtures:
    pattern: "{descriptor}.txt"
    examples:
      - "error_timeout.txt"
      - "policy_header_search.txt"
      - "cache_content_first.txt"

  toc_fixtures:
    pattern: "fixture_toc_{descriptor}.{json|html}"
    examples:
      - "fixture_toc_selector_miss.json"
      - "fixture_toc_count_mismatch.html"

  expected_files:
    pattern: "{descriptor}_expected.json"
    variants:
      search: "{sample_or_descriptor}_search_expected.json"
      toc: "{sample_or_descriptor}_toc_expected.json"
      content: "{sample_or_descriptor}_content_expected.json"
      error: "error_{scenario}_expected.json"
    examples:
      - "sample_001.json"
      - "wensang_search_expected.json"
      - "cache_search_expected.json"
      - "error_http_404_expected.json"

  p1_sample_ids:
    pattern: "SAMPLE-P1-{CAPABILITY}-{SEQUENCE}"
    examples:
      - "SAMPLE-P1-HEADER-001"
      - "SAMPLE-P1-COOKIE-001"
      - "SAMPLE-P1-ERROR-001"
      - "SAMPLE-P1-CACHE-001"
      - "SAMPLE-P1-POLICY-001"
```

---

### directoryConvention

```yaml
directoryConvention:
  root: "samples/"

  structure:
    fixtures:
      html: "samples/fixtures/html/"
      json: "samples/fixtures/json/"
      text: "samples/fixtures/text/"
      toc: "samples/fixtures/toc/"
      redirects: "samples/fixtures/redirects/"

    expected:
      search: "samples/expected/search/"
      toc: "samples/expected/toc/"
      content: "samples/expected/content/"
      error: "samples/expected/error/"

    matrix: "samples/matrix/"
    metadata: "samples/metadata/"
    reports: "samples/reports/"
    templates: "samples/templates/"
    booksources: "samples/booksources/"
    classification: "samples/classification/"

  metadata_subdirs:
    p0: "samples/metadata/p0_non_js/"
    p1_cookie: "samples/metadata/p1_cookie/"
    p1_js: "samples/metadata/p1_js/"
    p1_login: "samples/metadata/p1_login/"
    p1_cache: "samples/metadata/p1_cache/"
    p1_error: "samples/metadata/p1_error/"
    p1_policy: "samples/metadata/p1_policy/"

  report_subdirs:
    latest: "samples/reports/latest/"
    writebacks: "docs/process/writebacks/"

  template_files:
    - "samples/templates/sample_template.yml"
    - "samples/templates/search_expected_template.json"
    - "samples/templates/toc_expected_template.json"
    - "samples/templates/content_expected_template.json"
```

---

### matrixBindingRule

```yaml
matrixBindingRule:
  description: |
    Rules that bind fixture/expected files to compat_matrix.yml entries.
    Every fixture-backed sample must have a corresponding entry in compat_matrix.yml
    with correct paths populated.

  binding_fields:
    fixturePaths:
      location: "compat_matrix.yml → samples[].fixturePaths"
      type: "map of flow → path, or single path"
      required: false
      validation: "Referenced file must exist in samples/fixtures/"

    expectedPaths:
      location: "compat_matrix.yml → samples[].expectedPaths / expectedPath"
      type: "map of flow → path, or single path"
      required: false
      validation: "Referenced file must exist in samples/expected/"

    metadataPath:
      location: "compat_matrix.yml → samples[].metadataPath"
      type: "single path"
      required: true
      validation: "Referenced file must exist in samples/metadata/"

    reportPaths:
      location: "compat_matrix.yml → samples[].reportPaths"
      type: "map of report_type → path"
      required: false
      validation: "Referenced file should exist in samples/reports/"

  consistency_rules:
    - rule: "Every sampleId in compat_matrix.yml must have a metadataPath"
      severity: "blocking"

    - rule: "If fixturePaths is present, referenced fixture files must exist"
      severity: "blocking"

    - rule: "If expectedPaths is present, referenced expected files must exist"
      severity: "blocking"

    - rule: "actualLevel and failureType must be consistent with fixture test results"
      severity: "warning"

    - rule: "New samples must be added to compat_matrix.yml before fixture files are created"
      severity: "blocking"

  binding_flow:
    - step: 1
      action: "Define sampleId and metadata in samples/metadata/"
    - step: 2
      action: "Add sampleId entry to compat_matrix.yml with metadataPath"
    - step: 3
      action: "Create fixture files in samples/fixtures/"
    - step: 4
      action: "Create expected files in samples/expected/"
    - step: 5
      action: "Update compat_matrix.yml with fixturePaths and expectedPaths"
    - step: 6
      action: "Run regression and update actualLevel/failureType"
    - step: 7
      action: "Generate report in samples/reports/latest/"
```

---

### reportBindingRule

```yaml
reportBindingRule:
  description: |
    Rules that bind regression reports to compat_matrix and fixture files.
    Reports capture the outcome of running fixtures against Core.

  report_types:
    smoke_report:
      pattern: "samples/reports/latest/{sample_id}_{category}_smoke_result.yml"
      example: "samples/reports/latest/sample_001_nonjs_smoke_result.yml"
      binds_to: "compat_matrix sampleId"
      contains: "pass/fail per flow, actual counts vs expected counts"

    regression_report:
      pattern: "samples/reports/latest/{descriptor}_regression.yml"
      example: "samples/reports/latest/nonjs_sample_004_search_regression.yml"
      binds_to: "compat_matrix sampleId + flow"
      contains: "regression pass/fail, diff details"

    fetch_report:
      pattern: "samples/reports/latest/fixture_fetch_result.yml"
      binds_to: "multiple samples sharing fetch infrastructure"
      contains: "HTTP fetch results for real-network samples"

    writeback_record:
      pattern: "docs/process/writebacks/{date}_{descriptor}.yml"
      example: "docs/process/writebacks/20260406_nonjs_sample_004.yml"
      binds_to: "compat_matrix sampleId"
      contains: "formal writeback of regression result to compat_matrix"

    test_snapshot:
      pattern: "samples/reports/latest/swift_test_snapshot.json"
      binds_to: "CI run"
      contains: "Full XCTest result summary"

  consistency_rules:
    - rule: "Every writeback_record must reference a compat_matrix sampleId"
      severity: "blocking"

    - rule: "smoke_report sampleId must match a compat_matrix entry"
      severity: "blocking"

    - rule: "regression_report must reference both a sampleId and a flow (search/toc/content)"
      severity: "blocking"

    - rule: "Writeback must update compat_matrix actualLevel and failureType"
      severity: "blocking"

    - rule: "Reports must not be deleted — they form the audit trail"
      severity: "warning"

  report_lifecycle:
    - step: 1
      action: "CI runs XCTest / smoke runner"
    - step: 2
      action: "Runner generates report in samples/reports/latest/"
    - step: 3
      action: "Writeback script reads report and updates compat_matrix"
    - step: 4
      action: "Writeback record saved in docs/process/writebacks/"
    - step: 5
      action: "State files updated per AGENTS.md auto-sync rules"
```

---

## Fixture File Format

### HTML Fixture Format

No special format required — raw HTTP response body as captured from network or synthesized.

### JSON Fixture Format

Must be valid JSON parseable by `BookSource.decodeBookSource(from:)` or error mapping test infrastructure.

### Expected Output Format

```json
{
  "$schema": "samples/templates/search_expected_template.json",
  "description": "Expected search result for sample_001",
  "results": [
    {
      "title": "Expected Title",
      "detailURL": "https://example.com/book/1",
      "author": "Expected Author"
    }
  ]
}
```

### Metadata Format

```yaml
sampleId: "sample_001"
priority: "p0"
category: "non_js"
source: "fixture"
ruleTypes:
  - "CSS"
requiresLogin: false
requiresCookieJar: false
requiresHeader: false
requiresJs: false
expectedLevel: "A"
```

---

## Matrix Binding Validation

```yaml
validation:
  tool: "CI matrix validation script"
  checks:
    - "All compat_matrix sampleIds have matching metadata files"
    - "All fixturePaths in compat_matrix reference existing files"
    - "All expectedPaths in compat_matrix reference existing files"
    - "No orphan fixture files (fixture without compat_matrix entry)"
    - "No orphan expected files (expected without compat_matrix entry)"
    - "failureType values match failure_taxonomy.yml"
    - "actualLevel values are valid A/B/C/D"
  frequency: "Every PR that touches samples/ or compat_matrix"
```

---

## Clean-Room Statement

```yaml
cleanRoom:
  basis: "Existing samples/ directory structure and compat_matrix.yml conventions"
  noExternalGplCode: true
  noLegadoAndroidImplementationReference: true
  statement: "本规范仅基于仓库内部现有 729 样本文件的目录结构和命名惯例产出。不引用外部 GPL 代码，不引用 Legado Android 实现。"
```
