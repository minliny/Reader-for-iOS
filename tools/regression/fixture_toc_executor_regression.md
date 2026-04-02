# Fixture TOC Executor Regression

## Purpose
- Connect the 4 minimal fixture samples to real `FixtureTocParser` execution.
- Keep `compat_matrix`, `metadata`, and sample structure unchanged.
- Update `samples/reports/latest/fixture_toc_regression_summary.yml` after each run.

## Entry Points
- Wrapper:
  - `tools/regression/run_fixture_toc_min_regression.ps1`
- Swift executor:
  - `FixtureTocRegressionCLI`

## Behavior
- If `swift` is unavailable:
  - outputs dry-run JSON
  - rewrites summary with `executorVerified: false`
  - does not fabricate pass/fail
- If `swift` is available:
  - builds a manifest from the 4 validated samples
  - runs `FixtureTocParser.parse`
  - compares actual result with expected JSON
  - rewrites summary with real `passed/failed` counts

## Result Fields
- `status`: `passed` or `failed`
- `passed`: boolean
- `errorType`: normalized failure type when failed
- `diffReason`: structured mismatch reason

