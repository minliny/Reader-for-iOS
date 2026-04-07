param(
  [string]$RepoRoot = ".",
  [string]$CompatMatrixPath = "samples/matrix/compat_matrix.yml",
  [string]$SummaryPath = "samples/reports/latest/fixture_toc_regression_summary.yml"
)

$ErrorActionPreference = "Stop"

function Resolve-NormalizedPath {
  param([string]$Base, [string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) {
    return ""
  }
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $Base $Path))
}

function Read-YamlFile {
  param([string]$Path)
  if (Get-Command -Name ConvertFrom-Yaml -ErrorAction SilentlyContinue) {
    return ((Get-Content -LiteralPath $Path -Raw -Encoding UTF8) | ConvertFrom-Yaml)
  }
  $pythonOut = python -c "import json,sys,yaml; print(json.dumps(yaml.safe_load(open(sys.argv[1],encoding='utf-8').read()), ensure_ascii=False))" $Path
  if ($LASTEXITCODE -ne 0) {
    throw "YAML parse failed: $Path"
  }
  return ($pythonOut | ConvertFrom-Json -Depth 100)
}

function Read-JsonFile {
  param([string]$Path)
  return ((Get-Content -LiteralPath $Path -Raw -Encoding UTF8) | ConvertFrom-Json -Depth 100)
}

function Add-Issue {
  param(
    [ref]$Issues,
    [string]$Code,
    [string]$Message,
    [string]$Path = "",
    [string]$SampleId = ""
  )
  $Issues.Value += [pscustomobject]@{
    code = $Code
    message = $Message
    path = $Path
    sampleId = $SampleId
  }
}

$repoRootAbs = [System.IO.Path]::GetFullPath($RepoRoot)
$compatMatrixAbs = Resolve-NormalizedPath -Base $repoRootAbs -Path $CompatMatrixPath
$summaryAbs = Resolve-NormalizedPath -Base $repoRootAbs -Path $SummaryPath

$expectedIds = @(
  "fixture_toc_title_rule_miss",
  "fixture_toc_url_rule_miss",
  "fixture_toc_count_mismatch",
  "fixture_toc_non_selector_error"
)

$errors = @()
$warnings = @()
$sampleChecks = @()

foreach ($id in $expectedIds) {
  $metaAbs = Join-Path $repoRootAbs "samples/metadata/p0_non_js/$id/metadata.yml"
  $fixtureDirAbs = Join-Path $repoRootAbs "samples/fixtures/toc/$id"
  $inputAbs = Join-Path $fixtureDirAbs "input.html"
  $ruleAbs = Join-Path $fixtureDirAbs "rule.json"
  $expectedAbs = Join-Path $repoRootAbs "samples/expected/toc/$id.json"

  if (-not (Test-Path -LiteralPath $metaAbs)) {
    Add-Issue -Issues ([ref]$errors) -Code "MISSING_METADATA" -Message "metadata.yml missing" -Path $metaAbs -SampleId $id
    continue
  }
  $meta = Read-YamlFile -Path $metaAbs

  if (-not (Test-Path -LiteralPath $fixtureDirAbs)) {
    Add-Issue -Issues ([ref]$errors) -Code "MISSING_FIXTURE_DIR" -Message "fixture directory missing" -Path $fixtureDirAbs -SampleId $id
  }
  if (-not (Test-Path -LiteralPath $inputAbs)) {
    Add-Issue -Issues ([ref]$errors) -Code "MISSING_FIXTURE_INPUT" -Message "fixture input.html missing" -Path $inputAbs -SampleId $id
  }
  if (-not (Test-Path -LiteralPath $ruleAbs)) {
    Add-Issue -Issues ([ref]$errors) -Code "MISSING_FIXTURE_RULE" -Message "fixture rule.json missing" -Path $ruleAbs -SampleId $id
  }
  if (-not (Test-Path -LiteralPath $expectedAbs)) {
    Add-Issue -Issues ([ref]$errors) -Code "MISSING_EXPECTED" -Message "expected toc json missing" -Path $expectedAbs -SampleId $id
  }

  $metaSampleId = [string]$meta.sampleId
  # regressionSampleId may live at root (v1) or be absent and equal to sampleId (v2)
  $metaRegressionId = if ($null -ne $meta.regressionSampleId) { [string]$meta.regressionSampleId } else { $metaSampleId }
  if ($metaSampleId -ne $id) {
    Add-Issue -Issues ([ref]$errors) -Code "SAMPLE_ID_MISMATCH" -Message "metadata sampleId mismatch" -Path $metaAbs -SampleId $id
  }
  if ($metaRegressionId -ne $id) {
    Add-Issue -Issues ([ref]$errors) -Code "REGRESSION_ID_MISMATCH" -Message "metadata regressionSampleId mismatch" -Path $metaAbs -SampleId $id
  }

  # expected path: v1 uses expected.path, v2 uses expectedOutput.toc
  $expectedRelPath = if ($null -ne $meta.expected -and $null -ne $meta.expected.path) {
    [string]$meta.expected.path
  } elseif ($null -ne $meta.expectedOutput -and $null -ne $meta.expectedOutput.toc) {
    [string]$meta.expectedOutput.toc
  } else {
    ""
  }
  $expectedFromMetaAbs = Resolve-NormalizedPath -Base $repoRootAbs -Path $expectedRelPath
  if ($expectedFromMetaAbs -ne $expectedAbs) {
    Add-Issue -Issues ([ref]$errors) -Code "EXPECTED_PATH_MISMATCH" -Message "metadata expected.path does not match canonical expected file" -Path $metaAbs -SampleId $id
  }

  if (Test-Path -LiteralPath $expectedAbs) {
    $expectedJson = Read-JsonFile -Path $expectedAbs
    if ([string]$expectedJson.sampleId -ne $id) {
      Add-Issue -Issues ([ref]$errors) -Code "EXPECTED_SAMPLE_ID_MISMATCH" -Message "expected json sampleId mismatch" -Path $expectedAbs -SampleId $id
    }
    if ([string]$expectedJson.regressionSampleId -ne $id) {
      Add-Issue -Issues ([ref]$errors) -Code "EXPECTED_REGRESSION_ID_MISMATCH" -Message "expected json regressionSampleId mismatch" -Path $expectedAbs -SampleId $id
    }
  }

  $sampleChecks += [pscustomobject]@{
    regressionSampleId = $id
    metadataPath = [System.IO.Path]::GetRelativePath($repoRootAbs, $metaAbs).Replace("\", "/")
    fixturePath = [System.IO.Path]::GetRelativePath($repoRootAbs, $fixtureDirAbs).Replace("\", "/")
    expectedPath = [System.IO.Path]::GetRelativePath($repoRootAbs, $expectedAbs).Replace("\", "/")
  }
}

if (-not (Test-Path -LiteralPath $compatMatrixAbs)) {
  Add-Issue -Issues ([ref]$errors) -Code "MISSING_COMPAT_MATRIX" -Message "compat_matrix.yml missing" -Path $compatMatrixAbs
} else {
  $matrix = Read-YamlFile -Path $compatMatrixAbs
  $matrixSamples = @()
  if ($matrix.samples) {
    $matrixSamples = @($matrix.samples)
  }

  foreach ($id in $expectedIds) {
    $matches = @($matrixSamples | Where-Object { [string]$_.sampleId -eq $id })
    if ($matches.Count -eq 0) {
      Add-Issue -Issues ([ref]$errors) -Code "MATRIX_SAMPLE_MISSING" -Message "sample missing in compat_matrix" -Path $compatMatrixAbs -SampleId $id
      continue
    }
    if ($matches.Count -gt 1) {
      Add-Issue -Issues ([ref]$errors) -Code "MATRIX_SAMPLE_DUPLICATED" -Message "duplicate sampleId in compat_matrix" -Path $compatMatrixAbs -SampleId $id
    }
    $m = $matches[0]
    # regressionSampleId may be present (v1) or absent and equal to sampleId (v2)
    $matrixRegId = if ($null -ne $m.regressionSampleId) { [string]$m.regressionSampleId } else { [string]$m.sampleId }
    if ($matrixRegId -ne $id) {
      Add-Issue -Issues ([ref]$errors) -Code "MATRIX_REGRESSION_ID_MISMATCH" -Message "matrix regressionSampleId mismatch" -Path $compatMatrixAbs -SampleId $id
    }
  }

  $unexpected = @($matrixSamples | Where-Object { $expectedIds -notcontains [string]$_.sampleId })
  if ($unexpected.Count -gt 0) {
    foreach ($u in $unexpected) {
      Add-Issue -Issues ([ref]$warnings) -Code "MATRIX_EXTRA_SAMPLE" -Message "extra sample found in compat_matrix outside fixture_toc_min set" -Path $compatMatrixAbs -SampleId ([string]$u.sampleId)
    }
  }
}

if (-not (Test-Path -LiteralPath $summaryAbs)) {
  Add-Issue -Issues ([ref]$errors) -Code "MISSING_REGRESSION_SUMMARY" -Message "fixture_toc_regression_summary.yml missing" -Path $summaryAbs
} else {
  $summary = Read-YamlFile -Path $summaryAbs
  $sampleResults = @()
  if ($summary.sampleResults) {
    $sampleResults = @($summary.sampleResults)
  }
  foreach ($id in $expectedIds) {
    $matches = @($sampleResults | Where-Object { [string]$_.regressionSampleId -eq $id })
    if ($matches.Count -eq 0) {
      Add-Issue -Issues ([ref]$errors) -Code "SUMMARY_SAMPLE_MISSING" -Message "sample missing in regression summary" -Path $summaryAbs -SampleId $id
      continue
    }
    if ($matches.Count -gt 1) {
      Add-Issue -Issues ([ref]$errors) -Code "SUMMARY_SAMPLE_DUPLICATED" -Message "duplicate regressionSampleId in summary" -Path $summaryAbs -SampleId $id
    }
    $s = $matches[0]
    if ([string]$s.sampleId -ne $id) {
      Add-Issue -Issues ([ref]$errors) -Code "SUMMARY_SAMPLE_ID_MISMATCH" -Message "summary sampleId mismatch" -Path $summaryAbs -SampleId $id
    }
  }
}

$result = [pscustomobject]@{
  ok = ($errors.Count -eq 0)
  mode = "structure_validation"
  generatedAt = (Get-Date).ToUniversalTime().ToString("o")
  checkedSampleCount = $expectedIds.Count
  checkedRegressionSampleIds = $expectedIds
  samples = $sampleChecks
  errors = $errors
  warnings = $warnings
}

$json = $result | ConvertTo-Json -Depth 20
$json
if (-not $result.ok) {
  exit 2
}
exit 0

