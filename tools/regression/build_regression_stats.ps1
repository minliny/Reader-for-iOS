param(
  [string]$RepoRoot = ".",
  [string]$CompatMatrixPath = "",
  [string]$PreviousCompatMatrixPath = "",
  [string]$ReportOutputPath = "",
  [double]$P0Threshold = 0.95,
  [double]$PocMustPassThreshold = 1.0
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
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    return ($raw | ConvertFrom-Yaml)
  }
  $pythonOut = python -c "import json,sys,yaml; print(json.dumps(yaml.safe_load(open(sys.argv[1],encoding='utf-8').read()), ensure_ascii=False))" $Path
  if ($LASTEXITCODE -ne 0) {
    throw "YAML 解析失败: $Path"
  }
  return ($pythonOut | ConvertFrom-Json -Depth 100)
}

function To-Rate {
  param([int]$Num, [int]$Den)
  if ($Den -le 0) {
    return 0.0
  }
  return [Math]::Round(($Num / $Den) * 100.0, 2)
}

function Is-PassStatus {
  param([string]$Status)
  return @("pass", "passed", "ok", "success") -contains (($Status ?? "").ToLowerInvariant())
}

function Is-FailStatus {
  param([string]$Status)
  return @("fail", "failed", "error", "crash") -contains (($Status ?? "").ToLowerInvariant())
}

function Is-DegradeStatus {
  param([string]$Status)
  return @("degraded", "degrade") -contains (($Status ?? "").ToLowerInvariant())
}

$repoRootAbs = [System.IO.Path]::GetFullPath($RepoRoot)
$matrixPath = if ([string]::IsNullOrWhiteSpace($CompatMatrixPath)) { Join-Path $repoRootAbs "samples/matrix/compat_matrix.yml" } else { Resolve-NormalizedPath -Base $repoRootAbs -Path $CompatMatrixPath }

if (-not (Test-Path -LiteralPath $matrixPath)) {
  throw "compat_matrix 不存在: $matrixPath"
}

$matrix = Read-YamlFile -Path $matrixPath
$samples = @()
if ($matrix.samples) {
  $samples = @($matrix.samples)
}

$prevSamplesById = @{}
if (-not [string]::IsNullOrWhiteSpace($PreviousCompatMatrixPath)) {
  $prevPath = Resolve-NormalizedPath -Base $repoRootAbs -Path $PreviousCompatMatrixPath
  if (Test-Path -LiteralPath $prevPath) {
    $prev = Read-YamlFile -Path $prevPath
    if ($prev.samples) {
      foreach ($p in @($prev.samples)) {
        $pid = [string]$p.sampleId
        if (-not [string]::IsNullOrWhiteSpace($pid)) {
          $prevSamplesById[$pid] = $p
        }
      }
    }
  }
}

$levelA = 0
$levelB = 0
$levelC = 0
$levelD = 0
$p0Total = 0
$p0Pass = 0
$pocMustPassTotal = 0
$pocMustPassPassed = 0
$passCount = 0
$failCount = 0
$degradeCount = 0
$newlyPassed = 0
$newlyFailed = 0
$failureCountMap = @{}

foreach ($s in $samples) {
  $compatLevel = [string]$s.compatLevel
  switch ($compatLevel) {
    "A" { $levelA++ }
    "B" { $levelB++ }
    "C" { $levelC++ }
    "D" { $levelD++ }
    default { }
  }

  $status = [string]$s.status
  $isPass = Is-PassStatus -Status $status
  $isFail = Is-FailStatus -Status $status
  $isDegrade = Is-DegradeStatus -Status $status

  if ($isPass) { $passCount++ }
  if ($isFail) { $failCount++ }
  if ($isDegrade) { $degradeCount++ }

  $stage = [string]$s.stage
  if ($stage -eq "p0_non_js") {
    $p0Total++
    if ($isPass) {
      $p0Pass++
    }
  }

  $mustPass = $false
  if ($null -ne $s.pocMustPass) {
    $mustPass = [bool]$s.pocMustPass
  } elseif ($stage -eq "p0_non_js") {
    $mustPass = $true
  }
  if ($mustPass) {
    $pocMustPassTotal++
    if ($isPass) {
      $pocMustPassPassed++
    }
  }

  if ($isFail -or $isDegrade) {
    $reason = [string]$s.failureType
    if ([string]::IsNullOrWhiteSpace($reason)) {
      $reason = "UNKNOWN"
    }
    if ($failureCountMap.ContainsKey($reason)) {
      $failureCountMap[$reason] = [int]$failureCountMap[$reason] + 1
    } else {
      $failureCountMap[$reason] = 1
    }
  }

  $sid = [string]$s.sampleId
  if (-not [string]::IsNullOrWhiteSpace($sid) -and $prevSamplesById.ContainsKey($sid)) {
    $prevStatus = [string]$prevSamplesById[$sid].status
    $prevPass = Is-PassStatus -Status $prevStatus
    $prevFail = Is-FailStatus -Status $prevStatus
    if (-not $prevPass -and $isPass) {
      $newlyPassed++
    }
    if (-not $prevFail -and $isFail) {
      $newlyFailed++
    }
  }
}

$topFailureReasons = @(
  $failureCountMap.GetEnumerator() |
    Sort-Object -Property Value -Descending |
    Select-Object -First 5 |
    ForEach-Object {
      [pscustomobject]@{
        failureType = $_.Key
        count = $_.Value
      }
    }
)

$total = $samples.Count
$p0PassRate = To-Rate -Num $p0Pass -Den $p0Total
$pocMustPassRate = To-Rate -Num $pocMustPassPassed -Den $pocMustPassTotal
$passRate = To-Rate -Num $passCount -Den $total
$degradeRate = To-Rate -Num $degradeCount -Den $total
$failRate = To-Rate -Num $failCount -Den $total

$stageGate = [pscustomobject]@{
  p0PassRateThreshold = $P0Threshold
  pocMustPassRateThreshold = $PocMustPassThreshold
  p0PassRateActual = [Math]::Round($p0PassRate / 100.0, 4)
  pocMustPassRateActual = [Math]::Round($pocMustPassRate / 100.0, 4)
}
$stageGate | Add-Member -NotePropertyName reached -NotePropertyValue (($stageGate.p0PassRateActual -ge $P0Threshold) -and ($stageGate.pocMustPassRateActual -ge $PocMustPassThreshold))

$result = [pscustomobject]@{
  generatedAt = (Get-Date).ToUniversalTime().ToString("o")
  summary = [pscustomobject]@{
    totalSamples = $total
    levelA = $levelA
    levelB = $levelB
    levelC = $levelC
    levelD = $levelD
    passRate = $passRate
    degradeRate = $degradeRate
    failRate = $failRate
    p0PassRate = $p0PassRate
    pocMustPassRate = $pocMustPassRate
    newlyPassed = $newlyPassed
    newlyFailed = $newlyFailed
  }
  topFailureReasons = $topFailureReasons
  stageGate = $stageGate
}

$json = $result | ConvertTo-Json -Depth 10
if (-not [string]::IsNullOrWhiteSpace($ReportOutputPath)) {
  $outAbs = Resolve-NormalizedPath -Base $repoRootAbs -Path $ReportOutputPath
  $outDir = Split-Path -Parent $outAbs
  if (-not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
  }
  Set-Content -LiteralPath $outAbs -Value $json -Encoding UTF8
}

$json
if (-not $stageGate.reached) {
  exit 3
}
exit 0
