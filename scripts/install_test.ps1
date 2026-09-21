<# Safely install a verified release ZIP, preserving the previous installation. #>
[CmdletBinding()]
param(
    [Parameter(Position = 0)] [string] $AddOnsPath,
    [Parameter(Position = 1)] [string] $PackagePath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$AddonName = 'RotaAssist'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$Verifier = Join-Path $ScriptDir 'verify_package.py'
$Python = Get-Command python -ErrorAction SilentlyContinue
if ($null -eq $Python) { throw 'Python 3 is required for package verification.' }

if ([string]::IsNullOrWhiteSpace($PackagePath)) {
    $toc = [IO.File]::ReadAllText((Join-Path $RepoRoot 'addon\RotaAssist.toc'))
    $match = [regex]::Match($toc, '(?m)^##\s*Version:\s*(\S+)\s*$')
    if (-not $match.Success) { throw 'Cannot resolve the default package version from the TOC.' }
    $version = $match.Groups[1].Value
    $PackagePath = Join-Path (Join-Path (Join-Path $RepoRoot 'dist') $version) "$AddonName-$version.zip"
}
$PackagePath = (Resolve-Path -LiteralPath $PackagePath -ErrorAction Stop).Path

if ([string]::IsNullOrWhiteSpace($AddOnsPath)) {
    $candidates = @(
        'C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns',
        'C:\Program Files\World of Warcraft\_retail_\Interface\AddOns',
        'D:\Games\World of Warcraft\_retail_\Interface\AddOns'
    )
    $AddOnsPath = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Container } | Select-Object -First 1
}
if ([string]::IsNullOrWhiteSpace($AddOnsPath)) { throw 'WoW AddOns directory not found; pass -AddOnsPath explicitly.' }
$AddOnsPath = (Resolve-Path -LiteralPath $AddOnsPath -ErrorAction Stop).Path
$parentItem = Get-Item -LiteralPath $AddOnsPath -Force
if (-not $parentItem.PSIsContainer) { throw "AddOnsPath is not a directory: $AddOnsPath" }
if (($parentItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw "Refusing a reparse-point AddOns directory: $AddOnsPath"
}

$Destination = Join-Path $AddOnsPath $AddonName
if (Test-Path -LiteralPath $Destination) {
    $destinationItem = Get-Item -LiteralPath $Destination -Force
    if (($destinationItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Refusing to replace a reparse-point installation: $Destination"
    }
}

Write-Host 'Validating package before touching the installation...' -ForegroundColor Cyan
& $Python.Source $Verifier --archive $PackagePath --require-manifest
if ($LASTEXITCODE -ne 0) { throw 'Package verification failed; installation was not changed.' }

$TempRoot = Join-Path ([IO.Path]::GetTempPath()) ('rota-install-' + [guid]::NewGuid().ToString('N'))
$ExtractRoot = Join-Path $TempRoot 'payload'
$BackupPath = $null
$Installed = $false

function Get-TreeDigest([string] $Path) {
    $lines = Get-ChildItem -LiteralPath $Path -Recurse -Force -File | ForEach-Object {
        $relative = $_.FullName.Substring($Path.Length + 1).Replace('\', '/')
        $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        "$hash  $relative"
    } | Sort-Object
    $joined = $lines -join "`n"
    $bytes = [Text.Encoding]::UTF8.GetBytes($joined)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

try {
    [IO.Directory]::CreateDirectory($ExtractRoot) | Out-Null
    Expand-Archive -LiteralPath $PackagePath -DestinationPath $ExtractRoot
    $ExtractedAddon = Join-Path $ExtractRoot $AddonName
    & $Python.Source $Verifier --addon-dir $ExtractedAddon --require-manifest
    if ($LASTEXITCODE -ne 0) { throw 'Extracted payload verification failed; installation was not changed.' }

    if (Test-Path -LiteralPath $Destination) {
        $beforeDigest = Get-TreeDigest $Destination
        do {
            $suffix = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss-fff')
            $BackupPath = Join-Path $AddOnsPath "$AddonName.backup.$suffix"
        } while (Test-Path -LiteralPath $BackupPath)
        Move-Item -LiteralPath $Destination -Destination $BackupPath
        $afterDigest = Get-TreeDigest $BackupPath
        if ($beforeDigest -ne $afterDigest) {
            Move-Item -LiteralPath $BackupPath -Destination $Destination
            $BackupPath = $null
            throw 'Backup verification failed; the original installation was restored.'
        }
        Write-Host "Backup: $BackupPath" -ForegroundColor Yellow
    }

    try {
        Copy-Item -LiteralPath $ExtractedAddon -Destination $Destination -Recurse
        & $Python.Source $Verifier --addon-dir $Destination --require-manifest
        if ($LASTEXITCODE -ne 0) { throw 'Installed payload verification failed.' }
        $Installed = $true
    } catch {
        if (Test-Path -LiteralPath $Destination) {
            $resolvedDestination = (Resolve-Path -LiteralPath $Destination).Path
            if ($resolvedDestination -ne $Destination) { throw "Refusing rollback cleanup of unexpected path: $resolvedDestination" }
            Remove-Item -LiteralPath $Destination -Recurse -Force
        }
        if ($null -ne $BackupPath -and (Test-Path -LiteralPath $BackupPath)) {
            Move-Item -LiteralPath $BackupPath -Destination $Destination
            $BackupPath = $null
        }
        throw
    }

    Write-Host "Installed and verified: $Destination" -ForegroundColor Green
    if ($null -ne $BackupPath) { Write-Host "Previous version retained at: $BackupPath" }
} finally {
    if (Test-Path -LiteralPath $TempRoot) {
        $resolvedTemp = (Resolve-Path -LiteralPath $TempRoot).Path
        $systemTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
        if (-not $resolvedTemp.StartsWith($systemTemp + '\', [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing cleanup outside the system temp directory: $resolvedTemp"
        }
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}

if (-not $Installed) { exit 1 }
