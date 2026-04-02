# Fixture TOC Minimal Regression Scaffold

## Scope
- Only validates and dry-runs these 4 regression IDs:
  - `fixture_toc_title_rule_miss`
  - `fixture_toc_url_rule_miss`
  - `fixture_toc_count_mismatch`
  - `fixture_toc_non_selector_error`
- Does not execute real parser runtime results in this host (`swift-missing`).

## Scripts
- Validate sample structure:
  - `tools/validators/validate_fixture_toc_min_samples.ps1`
- Produce unified dry-run output:
  - `tools/regression/dry_run_fixture_toc_min_regression.ps1`

## Input Contracts
- `samples/metadata/p0_non_js/<sampleId>/metadata.yml`
- `samples/fixtures/toc/<sampleId>/input.html`
- `samples/fixtures/toc/<sampleId>/rule.json`
- `samples/expected/toc/<sampleId>.json`
- `samples/matrix/compat_matrix.yml`
- `samples/reports/latest/fixture_toc_regression_summary.yml`

## Output Contract (dry-run JSON)
- `mode`: always `dry_run`
- `executorVerified`: always `false`
- `execution.performed`: always `false`
- `validation`: validation summary
- `summary`: pass/fail/skipped counters for structure phase
- `sampleResults`: aligned with 4 regression sample IDs

## Usage
```powershell
pwsh tools/validators/validate_fixture_toc_min_samples.ps1 -RepoRoot .
pwsh tools/regression/dry_run_fixture_toc_min_regression.ps1 -RepoRoot . -OutputPath samples/reports/latest/fixture_toc_dry_run.json
```

