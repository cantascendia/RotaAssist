<#
.SYNOPSIS
    RotaAssist release packager for Windows / PowerShell 5.1+.
    RotaAssist 发布打包脚本（Windows / PowerShell 5.1+）。

.DESCRIPTION
    Functional parity with scripts/package.sh, but uses Compress-Archive instead of
    the `zip` binary (git-bash on this machine has no `zip`). Adds pre-flight release
    checks and exits non-zero when any of them fail.

    与 scripts/package.sh 功能对齐，但用 Compress-Archive 代替 `zip`
    （本机 git-bash 没有 zip）。额外做发布前检查，任一失败即以非零码退出。

    Checks / 检查项:
      1. addon/RotaAssist.toc exists                    TOC 存在
      2. TOC declares `## Interface: 120100`            TOC 声明 Interface 120100
      3. Staged package contains no dev residue         暂存包内无开发残留
         (.git / tests / training / scripts / *.py / *.sh / *.ps1 / editor junk;
          *.md is allowed)

.PARAMETER Version
    Override the version. Defaults to `## Version:` from the TOC.
    覆盖版本号。默认读 TOC 的 `## Version:`。

.PARAMETER OutputDir
    Directory to write the zip into. Defaults to the repository root.
    zip 输出目录。默认为仓库根目录。

.PARAMETER KeepBuildDir
    Keep build/ after packaging (useful for inspecting what was staged).
    打包后保留 build/（便于检查暂存内容）。

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\package_release.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\package_release.ps1 -Version 1.1.0
#>
[CmdletBinding()]
param(
    [string] $Version,
    [string] $OutputDir,
    [switch] $KeepBuildDir
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Output helpers / 输出辅助
# ---------------------------------------------------------------------------

$script:WarningCount = 0

function Write-Step  { param([string] $Message) Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Ok    { param([string] $Message) Write-Host "  OK   $Message" -ForegroundColor Green }
function Write-Warn  {
    param([string] $Message)
    $script:WarningCount = $script:WarningCount + 1
    Write-Host "  WARN $Message" -ForegroundColor Yellow
}
function Fail {
    param([string] $Message)
    Write-Host "  FAIL $Message" -ForegroundColor Red
    Write-Host ""
    Write-Host "Release packaging aborted. / 打包中止。" -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------------
# Paths / 路径
# ---------------------------------------------------------------------------

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent $ScriptDir
$AddonName = 'RotaAssist'
$AddonDir  = Join-Path $RepoRoot 'addon'
$TocPath   = Join-Path $AddonDir "$AddonName.toc"
$BuildDir  = Join-Path $RepoRoot 'build'
$StageDir  = Join-Path $BuildDir $AddonName

if ([string]::IsNullOrWhiteSpace($OutputDir)) { $OutputDir = $RepoRoot }
if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}
$OutputDir = (Resolve-Path -LiteralPath $OutputDir).Path

Write-Host ""
Write-Host "RotaAssist release packager" -ForegroundColor White
Write-Host "  repo: $RepoRoot"
Write-Host ""

# ---------------------------------------------------------------------------
# Check 1 — TOC exists / TOC 存在
# ---------------------------------------------------------------------------

Write-Step 'Pre-flight checks / 发布前检查'

if (-not (Test-Path -LiteralPath $AddonDir)) {
    Fail "addon directory not found: $AddonDir"
}
if (-not (Test-Path -LiteralPath $TocPath)) {
    Fail "TOC not found: $TocPath"
}
Write-Ok "TOC found: addon/$AddonName.toc"

$TocLines = Get-Content -LiteralPath $TocPath -Encoding UTF8

# ---------------------------------------------------------------------------
# Check 2 — Interface must be 120100 (Midnight 12.1)
# ---------------------------------------------------------------------------

$ExpectedInterface = '120100'
$InterfaceValue = $null
foreach ($line in $TocLines) {
    if ($line -match '^\s*##\s*Interface\s*:\s*(.+?)\s*$') {
        $InterfaceValue = $Matches[1]
        break
    }
}

if ($null -eq $InterfaceValue) {
    Fail "TOC has no '## Interface:' directive."
}
if ($InterfaceValue -ne $ExpectedInterface) {
    Fail "TOC Interface is '$InterfaceValue', expected '$ExpectedInterface' (Midnight 12.1)."
}
Write-Ok "TOC Interface: $InterfaceValue (Midnight 12.1)"

# ---------------------------------------------------------------------------
# Version resolution / 版本解析
# ---------------------------------------------------------------------------

$TocVersion = $null
foreach ($line in $TocLines) {
    if ($line -match '^\s*##\s*Version\s*:\s*(.+?)\s*$') {
        $TocVersion = $Matches[1]
        break
    }
}

if ([string]::IsNullOrWhiteSpace($Version)) {
    if ([string]::IsNullOrWhiteSpace($TocVersion)) {
        Fail "TOC has no '## Version:' directive and no -Version was supplied."
    }
    $Version = $TocVersion
} else {
    if ($Version -ne $TocVersion) {
        Write-Warn "-Version '$Version' does not match TOC '## Version: $TocVersion'. Packaging as '$Version'."
    }
}
Write-Ok "Version: $Version"

# Soft checks on store IDs — placeholders are fine before first upload, but the
# operator should know. / 商店 ID 软检查：首次上架前是占位符属正常，但要提示。
foreach ($line in $TocLines) {
    if ($line -match '^\s*##\s*X-Curse-Project-ID\s*:\s*(.+?)\s*$') {
        if ($Matches[1] -match '^0+$') {
            Write-Warn "X-Curse-Project-ID is still a placeholder ('$($Matches[1])')."
        }
    }
    if ($line -match '^\s*##\s*X-Wago-ID\s*:\s*(.+?)\s*$') {
        if ($Matches[1] -match '^(placeholder|0+)$') {
            Write-Warn "X-Wago-ID is still a placeholder ('$($Matches[1])')."
        }
    }
}

# ---------------------------------------------------------------------------
# Stage / 暂存
# ---------------------------------------------------------------------------

Write-Host ""
Write-Step 'Staging addon files / 暂存插件文件'

if (Test-Path -LiteralPath $BuildDir) {
    Remove-Item -LiteralPath $BuildDir -Recurse -Force
}
New-Item -ItemType Directory -Path $StageDir -Force | Out-Null

Copy-Item -Path (Join-Path $AddonDir '*') -Destination $StageDir -Recurse -Force

# Strip Python build residue that may have leaked in.
# 清理可能混入的 Python 构建残留。
$pycacheDirs = @(Get-ChildItem -LiteralPath $StageDir -Recurse -Force -Directory -Filter '__pycache__' -ErrorAction SilentlyContinue)
foreach ($d in $pycacheDirs) {
    Remove-Item -LiteralPath $d.FullName -Recurse -Force
}
$pycFiles = @(Get-ChildItem -LiteralPath $StageDir -Recurse -Force -File -Filter '*.pyc' -ErrorAction SilentlyContinue)
foreach ($f in $pycFiles) {
    Remove-Item -LiteralPath $f.FullName -Force
}
if ($pycacheDirs.Count -gt 0 -or $pycFiles.Count -gt 0) {
    Write-Warn "Removed Python residue: $($pycacheDirs.Count) __pycache__ dir(s), $($pycFiles.Count) .pyc file(s)."
}

Write-Ok "Staged to build/$AddonName/"

# ---------------------------------------------------------------------------
# Check 3 — no dev residue in the staged package
# 检查 3 — 暂存包内无开发残留
#
# addon/ should already be clean; this is a backstop so a stray tests/ directory
# or a shell script never reaches a store upload.
# addon/ 本身应该是干净的，这里是兜底：绝不让 tests/ 或脚本混进上架包。
# ---------------------------------------------------------------------------

Write-Host ""
Write-Step 'Scanning staged package for dev residue / 扫描开发残留'

# Directory names that must never appear anywhere in the package.
$ForbiddenDirNames = @(
    '.git', '.github', '.svn', '.hg', '.vscode', '.idea', '.claude', '.agents',
    'tests', 'test', '__tests__', 'spec', 'training', 'scripts', 'node_modules',
    '__pycache__', 'build', 'dist', 'evals'
)

# File extensions that must never appear. *.md is deliberately allowed.
$ForbiddenExtensions = @(
    '.py', '.pyc', '.pyo', '.sh', '.ps1', '.bat', '.cmd',
    '.zip', '.7z', '.tar', '.gz', '.rar',
    '.bak', '.orig', '.rej', '.swp', '.tmp', '.log',
    '.csv', '.ipynb', '.pkl', '.joblib'
)

# Exact file names that must never appear.
$ForbiddenFileNames = @(
    '.gitignore', '.gitattributes', '.gitmodules', '.editorconfig',
    '.luacheckrc', '.DS_Store', 'Thumbs.db', 'desktop.ini'
)

$violations = New-Object System.Collections.ArrayList
$stagePrefixLength = $StageDir.Length + 1

$staged = @(Get-ChildItem -LiteralPath $StageDir -Recurse -Force)
foreach ($item in $staged) {
    $relative = $item.FullName.Substring($stagePrefixLength)

    if ($item.PSIsContainer) {
        if ($ForbiddenDirNames -contains $item.Name) {
            [void] $violations.Add("directory: $relative")
        }
        continue
    }

    # A forbidden directory anywhere in the path taints the file too, but the
    # directory entry itself already reported it — skip to avoid duplicate noise.
    $segments = $relative -split '[\\/]'
    $taintedByDir = $false
    for ($i = 0; $i -lt ($segments.Count - 1); $i++) {
        if ($ForbiddenDirNames -contains $segments[$i]) { $taintedByDir = $true; break }
    }
    if ($taintedByDir) { continue }

    if ($ForbiddenFileNames -contains $item.Name) {
        [void] $violations.Add("file: $relative")
        continue
    }

    $ext = $item.Extension.ToLowerInvariant()
    if ($ForbiddenExtensions -contains $ext) {
        [void] $violations.Add("file: $relative")
    }
}

if ($violations.Count -gt 0) {
    Write-Host "  Found $($violations.Count) dev-residue entr(ies) in the staged package:" -ForegroundColor Red
    foreach ($v in $violations) {
        Write-Host "    - $v" -ForegroundColor Red
    }
    Fail 'Staged package contains development residue. Clean addon/ and re-run.'
}
Write-Ok 'No dev residue found.'

# Sanity: the TOC must have survived into the package.
if (-not (Test-Path -LiteralPath (Join-Path $StageDir "$AddonName.toc"))) {
    Fail "Staged package is missing $AddonName.toc"
}

# ---------------------------------------------------------------------------
# Zip / 打包
# ---------------------------------------------------------------------------

Write-Host ""
Write-Step 'Creating zip / 创建 zip'

$ZipName = "$AddonName-$Version.zip"
$ZipPath = Join-Path $OutputDir $ZipName

if (Test-Path -LiteralPath $ZipPath) {
    Remove-Item -LiteralPath $ZipPath -Force
}

$stagedFiles = @(Get-ChildItem -LiteralPath $StageDir -Recurse -Force -File)
if ($stagedFiles.Count -eq 0) {
    Fail 'Staged package is empty.'
}

# NOT Compress-Archive: Windows PowerShell 5.1 writes archive entry names with
# backslashes, which violates the ZIP spec (APPNOTE 4.4.17.1 mandates '/') and can
# make store-side unpackers produce one flat file named "RotaAssist\Core\Init.lua"
# instead of a directory tree. Building the archive by hand lets us guarantee
# forward slashes. Entry paths are relative to build/, so the archive root is
# `RotaAssist/` — extract into Interface/AddOns/ and it is done.
#
# 不用 Compress-Archive：Windows PowerShell 5.1 会把条目名写成反斜杠，违反 ZIP 规范
# （APPNOTE 4.4.17.1 要求 '/'），可能让商店端解包出一个名为
# "RotaAssist\Core\Init.lua" 的扁平文件而不是目录树。手工建档以保证正斜杠。
# 条目路径相对 build/，因此压缩包根目录就是 RotaAssist/。
Add-Type -AssemblyName System.IO.Compression | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null

$buildPrefixLength = $BuildDir.Length + 1
$zipStream  = $null
$zipArchive = $null
try {
    $zipStream  = [System.IO.File]::Open($ZipPath, [System.IO.FileMode]::Create)
    $zipArchive = New-Object System.IO.Compression.ZipArchive($zipStream, [System.IO.Compression.ZipArchiveMode]::Create)

    foreach ($f in $stagedFiles) {
        $entryName = $f.FullName.Substring($buildPrefixLength).Replace('\', '/')
        [void] [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zipArchive, $f.FullName, $entryName,
            [System.IO.Compression.CompressionLevel]::Optimal)
    }
} finally {
    if ($null -ne $zipArchive) { $zipArchive.Dispose() }
    if ($null -ne $zipStream)  { $zipStream.Dispose() }
}

if (-not (Test-Path -LiteralPath $ZipPath)) {
    Fail "Archive creation reported success but $ZipName does not exist."
}

# ---------------------------------------------------------------------------
# Verify the archive round-trips / 校验压缩包可回读
# ---------------------------------------------------------------------------

$verifyArchive = $null
try {
    $verifyArchive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    $entryCount = $verifyArchive.Entries.Count
    $badSeparators = @($verifyArchive.Entries | Where-Object { $_.FullName -like '*\*' })
    $tocEntry = @($verifyArchive.Entries | Where-Object { $_.FullName -eq "$AddonName/$AddonName.toc" })
} finally {
    if ($null -ne $verifyArchive) { $verifyArchive.Dispose() }
}

if ($entryCount -ne $stagedFiles.Count) {
    Fail "Archive has $entryCount entries but $($stagedFiles.Count) files were staged."
}
if ($badSeparators.Count -gt 0) {
    Fail "$($badSeparators.Count) archive entr(ies) use backslash separators."
}
if ($tocEntry.Count -ne 1) {
    Fail "Archive does not contain $AddonName/$AddonName.toc at the expected path."
}
Write-Ok "Archive verified: $entryCount entries, root '$AddonName/', TOC present."

# ---------------------------------------------------------------------------
# Summary / 摘要
# ---------------------------------------------------------------------------

$fileCount = $stagedFiles.Count
$rawBytes  = ($stagedFiles | Measure-Object -Property Length -Sum).Sum
if ($null -eq $rawBytes) { $rawBytes = 0 }

$zipItem  = Get-Item -LiteralPath $ZipPath
$zipBytes = $zipItem.Length

function Format-Size {
    param([long] $Bytes)
    if ($Bytes -ge 1MB) { return ('{0:N2} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N2} KB' -f ($Bytes / 1KB)) }
    return "$Bytes B"
}

$ratio = 0
if ($rawBytes -gt 0) { $ratio = [math]::Round(100 - (($zipBytes / $rawBytes) * 100), 1) }

if (-not $KeepBuildDir) {
    Remove-Item -LiteralPath $BuildDir -Recurse -Force
}

Write-Host ""
Write-Host "==================== PACKAGE SUMMARY ====================" -ForegroundColor White
Write-Host ("  Addon      : {0}" -f $AddonName)
Write-Host ("  Version    : {0}" -f $Version)
Write-Host ("  Interface  : {0}" -f $InterfaceValue)
Write-Host ("  Zip        : {0}" -f $ZipPath)
Write-Host ("  Zip size   : {0} ({1:N0} bytes)" -f (Format-Size $zipBytes), $zipBytes)
Write-Host ("  Files      : {0}" -f $fileCount)
Write-Host ("  Raw size   : {0} ({1:N0} bytes)" -f (Format-Size $rawBytes), $rawBytes)
Write-Host ("  Compression: {0}%" -f $ratio)
Write-Host ("  Warnings   : {0}" -f $script:WarningCount)
Write-Host "=========================================================" -ForegroundColor White
Write-Host ""

if ($script:WarningCount -gt 0) {
    Write-Host "Packaged with $($script:WarningCount) warning(s). Review before uploading." -ForegroundColor Yellow
} else {
    Write-Host "Ready to upload. / 可以上架。" -ForegroundColor Green
}
Write-Host ""

exit 0
