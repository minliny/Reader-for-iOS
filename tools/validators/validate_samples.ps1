param(
  [string]$RepoRoot = ".",
  [string]$CompatMatrixPath = "",
  [string]$FailureTaxonomyPath = "",
  [string]$ReportOutputPath = "",
  [switch]$FailOnMissingExpected,
  [switch]$FailOnEmpty
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

function Is-PlaceholderFile {
  param([System.IO.FileInfo]$File)
  return $File.Name -eq ".gitkeep"
}

function Get-SampleKey {
  param([System.IO.FileInfo]$File, [string]$Root)
  $rel = [System.IO.Path]::GetRelativePath($Root, $File.FullName)
  $rel = $rel.Replace("\", "/")
  $noExt = [System.IO.Path]::ChangeExtension($rel, $null)
  return $noExt.TrimEnd(".")
}

function Add-Issue {
  param(
    [ref]$Issues,
    [string]$Type,
    [string]$Code,
    [string]$Message,
    [string]$Path = "",
    [string]$SampleId = ""
  )
  $Issues.Value += [pscustomobject]@{
    type = $Type
    code = $Code
    message = $Message
    path = $Path
    sampleId = $SampleId
  }
}

$repoRootAbs = [System.IO.Path]::GetFullPath($RepoRoot)
$samplesRoot = Join-Path $repoRootAbs "samples"
$booksourcesRoot = Join-Path $samplesRoot "booksources"
$metadataRoot = Join-Path $samplesRoot "metadata"
$expectedRoot = Join-Path $samplesRoot "expected"
$matrixPath = if ([string]::IsNullOrWhiteSpace($CompatMatrixPath)) { Join-Path $samplesRoot "matrix/compat_matrix.yml" } else { Resolve-NormalizedPath -Base $repoRootAbs -Path $CompatMatrixPath }
$taxonomyPath = if ([string]::IsNullOrWhiteSpace($FailureTaxonomyPath)) { Join-Path $samplesRoot "matrix/failure_taxonomy.yml" } else { Resolve-NormalizedPath -Base $repoRootAbs -Path $FailureTaxonomyPath }

$issues = @()
$warnings = @()

if (-not (Test-Path -LiteralPath $booksourcesRoot)) {
  throw "booksources 目录不存在: $booksourcesRoot"
}
if (-not (Test-Path -LiteralPath $metadataRoot)) {
  throw "metadata 目录不存在: $metadataRoot"
}
if (-not (Test-Path -LiteralPath $expectedRoot)) {
  throw "expected 目录不存在: $expectedRoot"
}
if (-not (Test-Path -LiteralPath $matrixPath)) {
  throw "compat_matrix 不存在: $matrixPath"
}
if (-not (Test-Path -LiteralPath $taxonomyPath)) {
  throw "failure_taxonomy 不存在: $taxonomyPath"
}

$compatMatrix = Read-YamlFile -Path $matrixPath
$failureTaxonomy = Read-YamlFile -Path $taxonomyPath
$knownFailureTypes = @()
if ($failureTaxonomy.failureTypes) {
  $knownFailureTypes = @($failureTaxonomy.failureTypes)
}

$bookFiles = @(Get-ChildItem -LiteralPath $booksourcesRoot -Recurse -File | Where-Object { -not (Is-PlaceholderFile $_) })
$metaFiles = @(Get-ChildItem -LiteralPath $metadataRoot -Recurse -File | Where-Object { -not (Is-PlaceholderFile $_) })
$expectedFiles = @(Get-ChildItem -LiteralPath $expectedRoot -Recurse -File | Where-Object { -not (Is-PlaceholderFile $_) })

if ($FailOnEmpty -and $bookFiles.Count -eq 0) {
  Add-Issue -Issues ([ref]$issues) -Type "error" -Code "EMPTY_SAMPLE_SET" -Message "booksources 为空，无法执行样本校验。"
}

$bookMap = @{}
foreach ($f in $bookFiles) {
  $key = Get-SampleKey -File $f -Root $booksourcesRoot
  if ($bookMap.ContainsKey($key)) {
    Add-Issue -Issues ([ref]$issues) -Type "error" -Code "BOOKSOURCE_DUPLICATED_FILE" -Message "booksources 存在重复键: $key" -Path $f.FullName
  } else {
    $bookMap[$key] = $f
  }
}

$metaMap = @{}
foreach ($f in $metaFiles) {
  $key = Get-SampleKey -File $f -Root $metadataRoot
  if ($metaMap.ContainsKey($key)) {
    Add-Issue -Issues ([ref]$issues) -Type "error" -Code "METADATA_DUPLICATED_FILE" -Message "metadata 存在重复键: $key" -Path $f.FullName
  } else {
    $metaMap[$key] = $f
  }
}

foreach ($k in $bookMap.Keys) {
  if (-not $metaMap.ContainsKey($k)) {
    Add-Issue -Issues ([ref]$issues) -Type "error" -Code "MISSING_METADATA" -Message "booksource 缺少对应 metadata: $k" -Path $bookMap[$k].FullName
  }
}

foreach ($k in $metaMap.Keys) {
  if (-not $bookMap.ContainsKey($k)) {
    Add-Issue -Issues ([ref]$issues) -Type "error" -Code "ORPHAN_METADATA" -Message "metadata 找不到对应 booksource: $k" -Path $metaMap[$k].FullName
  }
}

$sampleIdTracker = @{}
$requiredMetadataFields = @("sampleId", "stage", "flow", "sourcePath", "expectedPath", "compatLevel")

foreach ($k in $metaMap.Keys) {
  $mf = $metaMap[$k]
  $metaObj = $null
  try {
    $metaObj = Read-YamlFile -Path $mf.FullName
  } catch {
    Add-Issue -Issues ([ref]$issues) -Type "error" -Code "METADATA_PARSE_ERROR" -Message "metadata 解析失败: $($_.Exception.Message)" -Path $mf.FullName
    continue
  }

  foreach ($field in $requiredMetadataFields) {
    $v = $metaObj.$field
    if ($null -eq $v -or [string]::IsNullOrWhiteSpace([string]$v)) {
      Add-Issue -Issues ([ref]$issues) -Type "error" -Code "METADATA_REQUIRED_FIELD_MISSING" -Message "metadata 缺少必填字段: $field" -Path $mf.FullName
    }
  }

  $sampleId = [string]$metaObj.sampleId
  if (-not [string]::IsNullOrWhiteSpace($sampleId)) {
    if ($sampleIdTracker.ContainsKey($sampleId)) {
      Add-Issue -Issues ([ref]$issues) -Type "error" -Code "SAMPLE_ID_DUPLICATED" -Message "sampleId 重复: $sampleId" -Path $mf.FullName -SampleId $sampleId
    } else {
      $sampleIdTracker[$sampleId] = $mf.FullName
    }
  }

  $expectedPath = [string]$metaObj.expectedPath
  if (-not [string]::IsNullOrWhiteSpace($expectedPath)) {
    $absExpected = Resolve-NormalizedPath -Base $repoRootAbs -Path $expectedPath
    if (-not (Test-Path -LiteralPath $absExpected)) {
      $msg = "expected 文件缺失: $expectedPath"
      if ($FailOnMissingExpected) {
        Add-Issue -Issues ([ref]$issues) -Type "error" -Code "MISSING_EXPECTED" -Message $msg -Path $mf.FullName -SampleId $sampleId
      } else {
        Add-Issue -Issues ([ref]$warnings) -Type "warning" -Code "MISSING_EXPECTED" -Message $msg -Path $mf.FullName -SampleId $sampleId
      }
    }
  }

  $compatLevel = [string]$metaObj.compatLevel
  if (-not [string]::IsNullOrWhiteSpace($compatLevel) -and @("A","B","C","D") -notcontains $compatLevel) {
    Add-Issue -Issues ([ref]$issues) -Type "error" -Code "INVALID_COMPAT_LEVEL" -Message "compatLevel 非法，仅允许 A/B/C/D。" -Path $mf.FullName -SampleId $sampleId
  }
}

$matrixSamples = @()
if ($compatMatrix.samples) {
  $matrixSamples = @($compatMatrix.samples)
}

$matrixSampleIds = @{}
foreach ($s in $matrixSamples) {
  $id = [string]$s.sampleId
  if ([string]::IsNullOrWhiteSpace($id)) {
    Add-Issue -Issues ([ref]$issues) -Type "error" -Code "MATRIX_SAMPLE_ID_MISSING" -Message "compat_matrix 存在缺失 sampleId 的条目。"
    continue
  }
  if ($matrixSampleIds.ContainsKey($id)) {
    Add-Issue -Issues ([ref]$issues) -Type "error" -Code "MATRIX_SAMPLE_ID_DUPLICATED" -Message "compat_matrix sampleId 重复: $id" -SampleId $id
  } else {
    $matrixSampleIds[$id] = $true
  }
  $failureType = [string]$s.failureType
  if (-not [string]::IsNullOrWhiteSpace($failureType) -and $knownFailureTypes.Count -gt 0 -and $knownFailureTypes -notcontains $failureType) {
    Add-Issue -Issues ([ref]$issues) -Type "error" -Code "UNKNOWN_FAILURE_TYPE" -Message "failureType 未在 failure_taxonomy 定义: $failureType" -SampleId $id
  }
  $metaPathFromMatrix = [string]$s.metadataPath
  if ([string]::IsNullOrWhiteSpace($metaPathFromMatrix)) {
    Add-Issue -Issues ([ref]$issues) -Type "error" -Code "MATRIX_METADATA_PATH_MISSING" -Message "compat_matrix 条目缺少 metadataPath。" -SampleId $id
  } else {
    $metaAbs = Resolve-NormalizedPath -Base $repoRootAbs -Path $metaPathFromMatrix
    if (-not (Test-Path -LiteralPath $metaAbs)) {
      Add-Issue -Issues ([ref]$issues) -Type "error" -Code "MATRIX_METADATA_FILE_MISSING" -Message "compat_matrix 指向的 metadata 文件不存在: $metaPathFromMatrix" -SampleId $id
    }
  }
  $expectedPathFromMatrix = [string]$s.expectedPath
  if ([string]::IsNullOrWhiteSpace($expectedPathFromMatrix)) {
    Add-Issue -Issues ([ref]$issues) -Type "error" -Code "MATRIX_EXPECTED_PATH_MISSING" -Message "compat_matrix 条目缺少 expectedPath。" -SampleId $id
  } else {
    $expectedAbs = Resolve-NormalizedPath -Base $repoRootAbs -Path $expectedPathFromMatrix
    if (-not (Test-Path -LiteralPath $expectedAbs)) {
      $msgExpected = "compat_matrix 指向的 expected 文件不存在: $expectedPathFromMatrix"
      if ($FailOnMissingExpected) {
        Add-Issue -Issues ([ref]$issues) -Type "error" -Code "MATRIX_EXPECTED_FILE_MISSING" -Message $msgExpected -SampleId $id
      } else {
        Add-Issue -Issues ([ref]$warnings) -Type "warning" -Code "MATRIX_EXPECTED_FILE_MISSING" -Message $msgExpected -SampleId $id
      }
    }
  }
  $sourcePathFromMatrix = [string]$s.sourcePath
  if ([string]::IsNullOrWhiteSpace($sourcePathFromMatrix)) {
    Add-Issue -Issues ([ref]$issues) -Type "error" -Code "MATRIX_SOURCE_PATH_MISSING" -Message "compat_matrix 条目缺少 sourcePath。" -SampleId $id
  } else {
    $sourceAbs = Resolve-NormalizedPath -Base $repoRootAbs -Path $sourcePathFromMatrix
    if (-not (Test-Path -LiteralPath $sourceAbs)) {
      Add-Issue -Issues ([ref]$issues) -Type "error" -Code "MATRIX_SOURCE_FILE_MISSING" -Message "compat_matrix 指向的 source 文件不存在: $sourcePathFromMatrix" -SampleId $id
    }
  }
  $cl = [string]$s.compatLevel
  if (-not [string]::IsNullOrWhiteSpace($cl) -and @("A","B","C","D") -notcontains $cl) {
    Add-Issue -Issues ([ref]$issues) -Type "error" -Code "MATRIX_INVALID_COMPAT_LEVEL" -Message "compat_matrix compatLevel 非法，仅允许 A/B/C/D。" -SampleId $id
  }
}

foreach ($sampleId in $sampleIdTracker.Keys) {
  if (-not $matrixSampleIds.ContainsKey($sampleId)) {
    Add-Issue -Issues ([ref]$issues) -Type "error" -Code "SAMPLE_NOT_MAPPED_IN_MATRIX" -Message "metadata 样本未映射到 compat_matrix: $sampleId" -SampleId $sampleId
  }
}

$result = [pscustomobject]@{
  ok = ($issues.Count -eq 0)
  generatedAt = (Get-Date).ToUniversalTime().ToString("o")
  summary = [pscustomobject]@{
    booksourceCount = $bookFiles.Count
    metadataCount = $metaFiles.Count
    expectedCount = $expectedFiles.Count
    matrixSampleCount = $matrixSamples.Count
    errorCount = $issues.Count
    warningCount = $warnings.Count
  }
  errors = $issues
  warnings = $warnings
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
if (-not $result.ok) {
  exit 2
}
exit 0
