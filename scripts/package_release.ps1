<# Build a verified, self-contained RotaAssist release ZIP. #>
[CmdletBinding()]
param([string] $Version, [string] $OutputDir, [switch] $KeepStage)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
function Fail([string] $Message) { throw $Message }
function Write-Step([string] $Message) { Write-Host "==> $Message" -ForegroundColor Cyan }

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$AddonName = 'RotaAssist'
$SourceDir = Join-Path $RepoRoot 'addon'
$SourceToc = Join-Path $SourceDir "$AddonName.toc"
$Verifier = Join-Path $ScriptDir 'verify_package.py'
if (-not (Test-Path -LiteralPath $SourceToc -PathType Leaf)) { Fail "Missing TOC: $SourceToc" }
if (-not (Test-Path -LiteralPath $Verifier -PathType Leaf)) { Fail "Missing verifier: $Verifier" }
$Python = Get-Command python -ErrorAction SilentlyContinue
if ($null -eq $Python) { Fail 'Python 3 is required for recursive package verification.' }
$LuaCandidates = @(
    $env:ROTAASSIST_LUA,
    'C:\Program Files (x86)\Lua\5.1\lua.exe',
    'lua5.1',
    'lua'
) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
$Lua = $null
foreach ($candidate in $LuaCandidates) {
    $command = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($null -ne $command) { $Lua = $command.Source; break }
}
if ($null -eq $Lua) { Fail 'Lua 5.1 is required for the offline ordered-load smoke test.' }

$TocText = [IO.File]::ReadAllText($SourceToc)
$VersionMatch = [regex]::Match($TocText, '(?m)^##\s*Version:\s*(\S+)\s*$')
$InterfaceMatch = [regex]::Match($TocText, '(?m)^##\s*Interface:\s*(\S+)\s*$')
if (-not $VersionMatch.Success) { Fail 'TOC has no Version metadata.' }
if (-not $InterfaceMatch.Success) { Fail 'TOC has no Interface metadata.' }
$TocVersion = $VersionMatch.Groups[1].Value
if ([string]::IsNullOrWhiteSpace($Version)) { $Version = $TocVersion }
if ($Version -notmatch '^[0-9A-Za-z][0-9A-Za-z._-]*$') { Fail "Unsafe version: $Version" }

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path (Join-Path $RepoRoot 'dist') $Version
}
[IO.Directory]::CreateDirectory($OutputDir) | Out-Null
$OutputDir = (Resolve-Path -LiteralPath $OutputDir).Path
$StageRoot = Join-Path $OutputDir ('.stage-' + [guid]::NewGuid().ToString('N'))
$StageAddon = Join-Path $StageRoot $AddonName
$ZipPath = Join-Path $OutputDir "$AddonName-$Version.zip"
$CandidateZip = Join-Path $OutputDir ('.candidate-' + [guid]::NewGuid().ToString('N') + '.zip')

Write-Host "RotaAssist $Version (Interface $($InterfaceMatch.Groups[1].Value))"
try {
    Write-Step 'Validating source TOC/XML graph'
    & $Python.Source $Verifier --addon-dir $SourceDir
    if ($LASTEXITCODE -ne 0) { Fail 'Source dependency verification failed.' }
    $loadOrder = @(& $Python.Source $Verifier --addon-dir $SourceDir --print-lua-order)
    if ($LASTEXITCODE -ne 0) { Fail 'Could not resolve the Lua load order.' }
    & $Lua (Join-Path $ScriptDir 'smoke_load_addon.lua') $SourceDir (Join-Path $RepoRoot 'tests\mock_wow_api.lua') @loadOrder
    if ($LASTEXITCODE -ne 0) { Fail 'Offline TOC/XML ordered-load smoke test failed.' }

    Write-Step 'Staging in a unique dist directory'
    [IO.Directory]::CreateDirectory($StageAddon) | Out-Null
    Get-ChildItem -LiteralPath $SourceDir -Force | Copy-Item -Destination $StageAddon -Recurse -Force
    if ($Version -ne $TocVersion) {
        $stagedTocPath = Join-Path $StageAddon "$AddonName.toc"
        $stagedToc = [IO.File]::ReadAllText($stagedTocPath)
        $versionRegex = New-Object regex('(?m)^(##\s*Version:\s*)\S+(\s*)$')
        $stagedToc = $versionRegex.Replace($stagedToc, ('${1}' + $Version + '${2}'), 1)
        [IO.File]::WriteAllText($stagedTocPath, $stagedToc, (New-Object Text.UTF8Encoding($false)))
    }

    $docs = @(
        @((Join-Path $RepoRoot 'README.en.md'), 'README.en.md'),
        @((Join-Path $RepoRoot 'docs\assets\hero.svg'), 'docs\assets\hero.svg'),
        @((Join-Path $RepoRoot 'docs\assets\experience.svg'), 'docs\assets\experience.svg'),
        @((Join-Path $RepoRoot 'docs\USER_QUICK_START.md'), 'START-HERE.md'),
        @((Join-Path $RepoRoot 'docs\USER_QUICK_START.md'), 'docs\USER_QUICK_START.md'),
        @((Join-Path $RepoRoot 'docs\RELEASE_1.1.1-rc.17.md'), 'docs\RELEASE_1.1.1-rc.17.md'),
        @((Join-Path $RepoRoot 'docs\ux-readiness.md'), 'docs\ux-readiness.md'),
        @((Join-Path $RepoRoot 'docs\ux-preview.html'), 'docs\ux-preview.html'),
        @((Join-Path $RepoRoot 'README.md'), 'README.md'),
        @((Join-Path $RepoRoot 'LICENSE'), 'LICENSE'),
        @((Join-Path $RepoRoot 'CHANGELOG.md'), 'CHANGELOG.md'),
        @((Join-Path $RepoRoot 'docs\QUALITY_BASELINE.md'), 'docs\QUALITY_BASELINE.md'),
        @((Join-Path $RepoRoot 'docs\DEPENDENCIES.md'), 'docs\DEPENDENCIES.md'),
        @((Join-Path $RepoRoot 'docs\ADAPTIVE_RESEARCH_2026-09-22.md'), 'docs\ADAPTIVE_RESEARCH_2026-09-22.md'),
        @((Join-Path $RepoRoot 'docs\HAVOC_MODEL_VALIDATION_2026-09-22.md'), 'docs\HAVOC_MODEL_VALIDATION_2026-09-22.md'),
        @((Join-Path $RepoRoot 'docs\RELEASE_1.1.1-rc.1.md'), 'docs\RELEASE_1.1.1-rc.1.md'),
        @((Join-Path $RepoRoot 'docs\RELEASE_1.1.1-rc.2.md'), 'docs\RELEASE_1.1.1-rc.2.md'),
        @((Join-Path $RepoRoot 'docs\RELEASE_1.1.1-rc.3.md'), 'docs\RELEASE_1.1.1-rc.3.md'),
        @((Join-Path $RepoRoot 'docs\RELEASE_1.1.1-rc.4.md'), 'docs\RELEASE_1.1.1-rc.4.md'),
        @((Join-Path $RepoRoot 'docs\RELEASE_1.1.1-rc.5.md'), 'docs\RELEASE_1.1.1-rc.5.md'),
        @((Join-Path $RepoRoot 'docs\RELEASE_1.1.1-rc.6.md'), 'docs\RELEASE_1.1.1-rc.6.md'),
        @((Join-Path $RepoRoot 'docs\RELEASE_1.1.1-rc.7.md'), 'docs\RELEASE_1.1.1-rc.7.md'),
        @((Join-Path $RepoRoot 'docs\RELEASE_1.1.1-rc.8.md'), 'docs\RELEASE_1.1.1-rc.8.md'),
        @((Join-Path $RepoRoot 'docs\RELEASE_1.1.1-rc.9.md'), 'docs\RELEASE_1.1.1-rc.9.md'),
        @((Join-Path $RepoRoot 'docs\RELEASE_1.1.1-rc.10.md'), 'docs\RELEASE_1.1.1-rc.10.md'),
        @((Join-Path $RepoRoot 'docs\RELEASE_1.1.1-rc.11.md'), 'docs\RELEASE_1.1.1-rc.11.md'),
        @((Join-Path $RepoRoot 'docs\RELEASE_1.1.1-rc.12.md'), 'docs\RELEASE_1.1.1-rc.12.md'),
        @((Join-Path $RepoRoot 'docs\RELEASE_1.1.1-rc.13.md'), 'docs\RELEASE_1.1.1-rc.13.md'),
        @((Join-Path $RepoRoot 'docs\RELEASE_1.1.1-rc.16.md'), 'docs\RELEASE_1.1.1-rc.16.md'),
        @((Join-Path $RepoRoot 'docs\OPTIMALITY_EVIDENCE_SPEC.md'), 'docs\OPTIMALITY_EVIDENCE_SPEC.md'),
        @((Join-Path $RepoRoot 'research\optimality-evidence\README.md'), 'docs\research\optimality-evidence\README.md'),
        @((Join-Path $RepoRoot 'research\optimality-evidence\verification.json'), 'docs\research\optimality-evidence\verification.json'),
        @((Join-Path $RepoRoot 'research\optimality-evidence\mutations.json'), 'docs\research\optimality-evidence\mutations.json'),
        @((Join-Path $RepoRoot 'research\optimality-evidence\existing-benchmark-audit.json'), 'docs\research\optimality-evidence\existing-benchmark-audit.json'),
        @((Join-Path $RepoRoot 'research\optimality-evidence\shipped-policy-witnesses.tsv'), 'docs\research\optimality-evidence\shipped-policy-witnesses.tsv'),
        @((Join-Path $RepoRoot 'research\optimality-evidence\synthetic-certificates.json'), 'docs\research\optimality-evidence\synthetic-certificates.json'),
        @((Join-Path $RepoRoot 'research\optimality-evidence\synthetic-worlds.json'), 'docs\research\optimality-evidence\synthetic-worlds.json'),
        @((Join-Path $RepoRoot 'research\optimality-evidence\synthetic-dominance.json'), 'docs\research\optimality-evidence\synthetic-dominance.json'),
        @((Join-Path $RepoRoot 'docs\RELEASE_1.1.1-rc.15.md'), 'docs\RELEASE_1.1.1-rc.15.md'),
        @((Join-Path $RepoRoot 'docs\HAVOC_ACTION_TIMING_SPEC.md'), 'docs\HAVOC_ACTION_TIMING_SPEC.md'),
        @((Join-Path $RepoRoot 'research\action-timing\README.md'), 'docs\research\action-timing\README.md'),
        @((Join-Path $RepoRoot 'research\action-timing\sources.json'), 'docs\research\action-timing\sources.json'),
        @((Join-Path $RepoRoot 'research\action-timing\verification.json'), 'docs\research\action-timing\verification.json'),
        @((Join-Path $RepoRoot 'research\action-timing\mutations.json'), 'docs\research\action-timing\mutations.json'),
        @((Join-Path $RepoRoot 'docs\RELEASE_1.1.1-rc.14.md'), 'docs\RELEASE_1.1.1-rc.14.md'),
        @((Join-Path $RepoRoot 'docs\HAVOC_ADAPTIVE_BURST_SPEC.md'), 'docs\HAVOC_ADAPTIVE_BURST_SPEC.md'),
        @((Join-Path $RepoRoot 'research\adaptive-burst\README.md'), 'research\adaptive-burst\README.md'),
        @((Join-Path $RepoRoot 'research\adaptive-burst\adoption.json'), 'research\adaptive-burst\adoption.json'),
        @((Join-Path $RepoRoot 'research\adaptive-burst\verification.json'), 'research\adaptive-burst\verification.json'),
        @((Join-Path $RepoRoot 'docs\HAVOC_ENCOUNTER_READINESS_SPEC.md'), 'docs\HAVOC_ENCOUNTER_READINESS_SPEC.md'),
        @((Join-Path $RepoRoot 'research\havoc-encounters\README.md'), 'research\havoc-encounters\README.md'),
        @((Join-Path $RepoRoot 'research\havoc-encounters\holdout.json'), 'research\havoc-encounters\holdout.json'),
        @((Join-Path $RepoRoot 'research\havoc-encounters\verification.json'), 'research\havoc-encounters\verification.json'),
        @((Join-Path $RepoRoot 'docs\HAVOC_ALDRACHI_SPEC.md'), 'docs\HAVOC_ALDRACHI_SPEC.md'),
        @((Join-Path $RepoRoot 'research\aldrachi-policy\README.md'), 'research\aldrachi-policy\README.md'),
        @((Join-Path $RepoRoot 'research\aldrachi-policy\candidate.json'), 'research\aldrachi-policy\candidate.json'),
        @((Join-Path $RepoRoot 'research\aldrachi-policy\holdout.json'), 'research\aldrachi-policy\holdout.json'),
        @((Join-Path $RepoRoot 'research\aldrachi-policy\verification.json'), 'research\aldrachi-policy\verification.json'),
        @((Join-Path $RepoRoot 'docs\HAVOC_SURGE_SPEC.md'), 'docs\HAVOC_SURGE_SPEC.md'),
        @((Join-Path $RepoRoot 'research\havoc-surge\README.md'), 'docs\research\havoc-surge\README.md'),
        @((Join-Path $RepoRoot 'research\havoc-surge\verification.json'), 'docs\research\havoc-surge\verification.json'),
        @((Join-Path $RepoRoot 'docs\AUTOMATIC_RUNTIME_SPEC.md'), 'docs\AUTOMATIC_RUNTIME_SPEC.md'),
        @((Join-Path $RepoRoot 'research\runtime-context\README.md'), 'docs\research\runtime-context\README.md'),
        @((Join-Path $RepoRoot 'research\runtime-context\verification.json'), 'docs\research\runtime-context\verification.json'),
        @((Join-Path $RepoRoot 'docs\TALENT_TRANSITIONS_SPEC.md'), 'docs\TALENT_TRANSITIONS_SPEC.md'),
        @((Join-Path $RepoRoot 'research\talent-transitions\README.md'), 'docs\research\talent-transitions\README.md'),
        @((Join-Path $RepoRoot 'research\talent-transitions\verification.json'), 'docs\research\talent-transitions\verification.json'),
        @((Join-Path $RepoRoot 'docs\CHARACTER_CONTEXT_SPEC.md'), 'docs\CHARACTER_CONTEXT_SPEC.md'),
        @((Join-Path $RepoRoot 'research\character-build\README.md'), 'docs\research\character-build\README.md'),
        @((Join-Path $RepoRoot 'research\character-build\sources.json'), 'docs\research\character-build\sources.json'),
        @((Join-Path $RepoRoot 'research\character-build\verification.json'), 'docs\research\character-build\verification.json'),
        @((Join-Path $RepoRoot 'research\character-build\build-sensitivity.json'), 'docs\research\character-build\build-sensitivity.json'),
        @((Join-Path $RepoRoot 'docs\ROBUST_CONSENSUS_SPEC.md'), 'docs\ROBUST_CONSENSUS_SPEC.md'),
        @((Join-Path $RepoRoot 'research\robust-consensus\README.md'), 'docs\research\robust-consensus\README.md'),
        @((Join-Path $RepoRoot 'research\robust-consensus\verification.json'), 'docs\research\robust-consensus\verification.json'),
        @((Join-Path $RepoRoot 'research\robust-consensus\discovery-summary.json'), 'docs\research\robust-consensus\discovery-summary.json'),
        @((Join-Path $RepoRoot 'research\robust-consensus\candidate.json'), 'docs\research\robust-consensus\candidate.json'),
        @((Join-Path $RepoRoot 'research\robust-consensus\holdout.json'), 'docs\research\robust-consensus\holdout.json'),
        @((Join-Path $RepoRoot 'research\robust-consensus\phase\candidate.json'), 'docs\research\robust-consensus\phase\candidate.json'),
        @((Join-Path $RepoRoot 'research\robust-consensus\phase\holdout.json'), 'docs\research\robust-consensus\phase\holdout.json'),
        @((Join-Path $RepoRoot 'docs\PUBLIC_SIGNAL_DECISION_SPEC.md'), 'docs\PUBLIC_SIGNAL_DECISION_SPEC.md'),
        @((Join-Path $RepoRoot 'research\public-signals\README.md'), 'docs\research\public-signals\README.md'),
        @((Join-Path $RepoRoot 'research\public-signals\sources.json'), 'docs\research\public-signals\sources.json'),
        @((Join-Path $RepoRoot 'research\public-signals\verification.json'), 'docs\research\public-signals\verification.json'),
        @((Join-Path $RepoRoot 'docs\INDEPENDENT_POLICY_SPEC.md'), 'docs\INDEPENDENT_POLICY_SPEC.md'),
        @((Join-Path $RepoRoot 'research\independent-policy\README.md'), 'docs\research\independent-policy\README.md'),
        @((Join-Path $RepoRoot 'research\independent-policy\candidate.json'), 'docs\research\independent-policy\candidate.json'),
        @((Join-Path $RepoRoot 'research\independent-policy\holdout.json'), 'docs\research\independent-policy\holdout.json'),
        @((Join-Path $RepoRoot 'docs\TARGET_CONTEXT_SPEC.md'), 'docs\TARGET_CONTEXT_SPEC.md'),
        @((Join-Path $RepoRoot 'docs\SMOKE_TEST_12.1.md'), 'docs\SMOKE_TEST_12.1.md')
    )
    foreach ($doc in $docs) {
        if (-not (Test-Path -LiteralPath $doc[0] -PathType Leaf)) { Fail "Missing release document: $($doc[0])" }
        $docDestination = Join-Path $StageAddon $doc[1]
        [IO.Directory]::CreateDirectory((Split-Path -Parent $docDestination)) | Out-Null
        Copy-Item -LiteralPath $doc[0] -Destination $docDestination -Force
    }

    Write-Step 'Writing SHA-256 payload manifest'
    $manifestPath = Join-Path $StageAddon 'SHA256SUMS.txt'
    $manifestLines = Get-ChildItem -LiteralPath $StageAddon -Recurse -File |
        Where-Object { $_.FullName -ne $manifestPath } |
        ForEach-Object {
            $relative = $_.FullName.Substring($StageAddon.Length + 1).Replace('\', '/')
            $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            "$hash  $relative"
        } | Sort-Object
    [IO.File]::WriteAllLines($manifestPath, $manifestLines, (New-Object Text.UTF8Encoding($false)))

    Write-Step 'Creating ZIP with a single forward-slash RotaAssist/ root'
    Add-Type -AssemblyName System.IO.Compression
    $stream = [IO.File]::Open($CandidateZip, [IO.FileMode]::CreateNew)
    $archive = New-Object IO.Compression.ZipArchive($stream, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($file in @(Get-ChildItem -LiteralPath $StageAddon -Recurse -File | Sort-Object FullName)) {
            $relative = $file.FullName.Substring($StageAddon.Length + 1).Replace('\', '/')
            $entry = $archive.CreateEntry("$AddonName/$relative", [IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime = New-Object DateTimeOffset(1980, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
            $input = [IO.File]::OpenRead($file.FullName); $output = $entry.Open()
            try { $input.CopyTo($output) } finally { $output.Dispose(); $input.Dispose() }
        }
    } finally { $archive.Dispose(); $stream.Dispose() }

    Write-Step 'Verifying archive and all manifest hashes'
    & $Python.Source $Verifier --archive $CandidateZip --require-manifest
    if ($LASTEXITCODE -ne 0) { Fail 'Release ZIP verification failed.' }
    Move-Item -LiteralPath $CandidateZip -Destination $ZipPath -Force
    $zip = Get-Item -LiteralPath $ZipPath
    $hash = (Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText("$ZipPath.sha256", "$hash  $([IO.Path]::GetFileName($ZipPath))`n", (New-Object Text.UTF8Encoding($false)))
    Write-Host "READY: $($zip.FullName)" -ForegroundColor Green
    Write-Host "BYTES: $($zip.Length)"
    Write-Host "SHA256: $hash"
    Write-Host 'BOUNDARY: offline structure/load-graph verification; no WoW client runtime'
} finally {
    if (Test-Path -LiteralPath $CandidateZip) { Remove-Item -LiteralPath $CandidateZip -Force }
    if (-not $KeepStage -and (Test-Path -LiteralPath $StageRoot)) {
        $resolvedStage = (Resolve-Path -LiteralPath $StageRoot).Path
        $resolvedOutput = (Resolve-Path -LiteralPath $OutputDir).Path
        if (-not $resolvedStage.StartsWith($resolvedOutput + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing cleanup outside output directory: $resolvedStage"
        }
        Remove-Item -LiteralPath $resolvedStage -Recurse -Force
    }
}
