param(
  [string]$RepoRoot = ".",
  [string]$CompatMatrixPath = "samples/matrix/compat_matrix.yml",
  [string]$SummaryPath = "samples/reports/latest/fixture_toc_regression_summary.yml",
  [string]$ValidationScriptPath = "tools/validators/validate_fixture_toc_min_samples.ps1",
  [string]$OutputPath = ""
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

$repoRootAbs = [System.IO.Path]::GetFullPath($RepoRoot)
$compatMatrixAbs = Resolve-NormalizedPath -Base $repoRootAbs -Path $CompatMatrixPath
$summaryAbs = Resolve-NormalizedPath -Base $repoRootAbs -Path $SummaryPath
$validatorAbs = Resolve-NormalizedPath -Base $repoRootAbs -Path $ValidationScriptPath

if (-not (Test-Path -LiteralPath $validatorAbs)) {
  throw "validator script not found: $validatorAbs"
}

$validationRaw = & $validatorAbs -RepoRoot $repoRootAbs -CompatMatrixPath $compatMatrixAbs -SummaryPath $summaryAbs
if ($LASTEXITCODE -ne 0) {
  # still parse and emit a structured dry-run result
  $validation = $validationRaw | ConvertFrom-Json -Depth 100
  $failed = [pscustomobject]@{
    mode = "dry_run"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    executorVerified = $false
    execution = [pscustomobject]@{
      performed = $false
      reason = "structure_validation_failed"
    }
    validation = $validation
    summary = [pscustomobject]@{
      totalSamples = 4
      passed = 0
      failed = 0
      skipped = 4
    }
    sampleResults = @()
  }
  $failedJson = $failed | ConvertTo-Json -Depth 20
  if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $outAbs = Resolve-NormalizedPath -Base $repoRootAbs -Path $OutputPath
    $outDir = Split-Path -Parent $outAbs
    if (-not (Test-Path -LiteralPath $outDir)) {
      New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }
    Set-Content -LiteralPath $outAbs -Value $failedJson -Encoding UTF8
  }
  $failedJson
  exit 2
}

$validation = $validationRaw | ConvertFrom-Json -Depth 100
$summaryDoc = Read-YamlFile -Path $summaryAbs
$matrixDoc = Read-YamlFile -Path $compatMatrixAbs

$sampleResults = @()
if ($summaryDoc.sampleResults) {
  foreach ($s in @($summaryDoc.sampleResults)) {
    $sampleResults += [pscustomobject]@{
      regressionSampleId = [string]$s.regressionSampleId
      sampleId = [string]$s.sampleId
      status = "pending"
      expectedPath = [string]$s.expectedPath
    }
  }
}

$dryRun = [pscustomobject]@{
  mode = "dry_run"
  generatedAt = (Get-Date).ToUniversalTime().ToString("o")
  executorVerified = $false
  execution = [pscustomobject]@{
    performed = $false
    reason = "swift-missing; dry-run only"
  }
  validation = [pscustomobject]@{
    ok = [bool]$validation.ok
    errorCount = @($validation.errors).Count
    warningCount = @($validation.warnings).Count
  }
  matrix = [pscustomobject]@{
    scope = [string]$matrixDoc.scope
    totalSamples = [int]$matrixDoc.summary.totalSamples
  }
  summary = [pscustomobject]@{
    totalSamples = @($sampleResults).Count
    passed = 0
    failed = 0
    skipped = @($sampleResults).Count
  }
  sampleResults = $sampleResults
}

$json = $dryRun | ConvertTo-Json -Depth 20
if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
  $outAbs = Resolve-NormalizedPath -Base $repoRootAbs -Path $OutputPath
  $outDir = Split-Path -Parent $outAbs
  if (-not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
  }
  Set-Content -LiteralPath $outAbs -Value $json -Encoding UTF8
}

$json
exit 0

