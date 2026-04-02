param(
  [string]$RepoRoot = ".",
  [string]$SummaryPath = "samples/reports/latest/fixture_toc_regression_summary.yml",
  [string]$DryRunOutputPath = "samples/reports/latest/fixture_toc_dry_run.json",
  [string]$ResultOutputPath = "samples/reports/latest/fixture_toc_execution_result.json"
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

function Write-Utf8File {
  param([string]$Path, [string]$Content)
  $dir = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }
  Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8
}

function Convert-SampleResultsToYaml {
  param([array]$SampleResults)
  $lines = @()
  foreach ($sample in $SampleResults) {
    $lines += "  - regressionSampleId: `"$($sample.regressionSampleId)`""
    $lines += "    sampleId: `"$($sample.sampleId)`""
    $lines += "    status: `"$($sample.status)`""
    if ($null -ne $sample.passed) {
      $boolText = if ([bool]$sample.passed) { "true" } else { "false" }
      $lines += "    passed: $boolText"
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$sample.errorType)) {
      $lines += "    errorType: `"$($sample.errorType)`""
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$sample.diffReason)) {
      $escapedReason = ([string]$sample.diffReason).Replace('"', '\"')
      $lines += "    diffReason: `"$escapedReason`""
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$sample.expectedPath)) {
      $lines += "    expectedPath: `"$($sample.expectedPath)`""
    }
  }
  return ($lines -join "`n")
}

function Write-SummaryYaml {
  param(
    [string]$Path,
    [string]$RunId,
    [bool]$ExecutorVerified,
    [string]$Mode,
    [string]$Note,
    [array]$SampleResults,
    [int]$Passed,
    [int]$Failed,
    [int]$Skipped
  )

  $generatedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  $yaml = @(
    "reportId: `"fixture_toc_min_regression_v1`"",
    "generatedAt: `"$generatedAt`"",
    "scope: `"fixture_toc_parser_contract`"",
    "run:",
    "  runId: `"$RunId`"",
    "  mode: `"$Mode`"",
    "  executorVerified: $(if ($ExecutorVerified) { 'true' } else { 'false' })",
    "  note: `"$($Note.Replace('"', '\"'))`"",
    "summary:",
    "  totalSamples: $($SampleResults.Count)",
    "  passed: $Passed",
    "  failed: $Failed",
    "  skipped: $Skipped",
    "sampleResults:",
    (Convert-SampleResultsToYaml -SampleResults $SampleResults)
  ) -join "`n"

  Write-Utf8File -Path $Path -Content $yaml
}

$repoRootAbs = [System.IO.Path]::GetFullPath($RepoRoot)
$summaryAbs = Resolve-NormalizedPath -Base $repoRootAbs -Path $SummaryPath
$dryRunAbs = Resolve-NormalizedPath -Base $repoRootAbs -Path $DryRunOutputPath
$resultAbs = Resolve-NormalizedPath -Base $repoRootAbs -Path $ResultOutputPath
$validatorPath = Resolve-NormalizedPath -Base $repoRootAbs -Path "tools/validators/validate_fixture_toc_min_samples.ps1"
$dryRunScriptPath = Resolve-NormalizedPath -Base $repoRootAbs -Path "tools/regression/dry_run_fixture_toc_min_regression.ps1"
$manifestAbs = Resolve-NormalizedPath -Base $repoRootAbs -Path "samples/reports/latest/fixture_toc_execution_manifest.json"
$coreRootAbs = Resolve-NormalizedPath -Base $repoRootAbs -Path "Core"

$validationRaw = & $validatorPath -RepoRoot $repoRootAbs
if ($LASTEXITCODE -ne 0) {
  throw "sample validation failed"
}
$validation = $validationRaw | ConvertFrom-Json -Depth 100

$runId = "fixture_toc_exec_" + ([Guid]::NewGuid().ToString("N"))

if (-not (Get-Command swift -ErrorAction SilentlyContinue)) {
  $dryRunRaw = & $dryRunScriptPath -RepoRoot $repoRootAbs -OutputPath $dryRunAbs
  if ($LASTEXITCODE -ne 0) {
    throw "dry-run generation failed"
  }
  $dryRun = $dryRunRaw | ConvertFrom-Json -Depth 100
  Write-SummaryYaml `
    -Path $summaryAbs `
    -RunId $runId `
    -ExecutorVerified $false `
    -Mode "dry_structure_only" `
    -Note "swift-missing in current host; execution result pending CI or macOS runner." `
    -SampleResults $dryRun.sampleResults `
    -Passed 0 `
    -Failed 0 `
    -Skipped ([int]$dryRun.summary.skipped)
  $dryRunRaw
  exit 0
}

$manifest = [pscustomobject]@{
  runId = $runId
  generatedAt = (Get-Date).ToUniversalTime().ToString("o")
  samples = @()
}

foreach ($sample in $validation.samples) {
  $rulePath = Join-Path (Resolve-Path (Join-Path $repoRootAbs $sample.fixturePath)).Path "rule.json"
  $inputPath = Join-Path (Resolve-Path (Join-Path $repoRootAbs $sample.fixturePath)).Path "input.html"
  $manifest.samples += [pscustomobject]@{
    sampleId = $sample.regressionSampleId
    regressionSampleId = $sample.regressionSampleId
    inputHTMLPath = $inputPath
    rulePath = $rulePath
    expectedPath = Resolve-NormalizedPath -Base $repoRootAbs -Path $sample.expectedPath
  }
}

$manifestJson = $manifest | ConvertTo-Json -Depth 20
Write-Utf8File -Path $manifestAbs -Content $manifestJson

$execRaw = & swift run --package-path $coreRootAbs FixtureTocRegressionCLI $manifestAbs $resultAbs
if ($LASTEXITCODE -ne 0) {
  throw "swift regression execution failed"
}

$execResult = Get-Content -LiteralPath $resultAbs -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 100
Write-SummaryYaml `
  -Path $summaryAbs `
  -RunId $runId `
  -ExecutorVerified $true `
  -Mode "executor_run" `
  -Note "FixtureTocParser executor run completed from Swift regression entry." `
  -SampleResults $execResult.sampleResults `
  -Passed ([int]$execResult.summary.passed) `
  -Failed ([int]$execResult.summary.failed) `
  -Skipped ([int]$execResult.summary.skipped)

$execRaw
exit 0
