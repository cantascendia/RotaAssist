<# Local launcher; no game interaction and no upload. #>
[CmdletBinding()]
param([string]$Profile, [string]$Simc, [string]$Reference,
      [string]$Output, [int]$Iterations=500, [int]$VerifyIterations=2000)
$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Profile)) { $Profile=Join-Path $taskRoot 'character.simc' }
if (-not (Test-Path -LiteralPath $Profile -PathType Leaf)) {
    throw 'Save your /simc export as character.simc beside START.cmd, or drag a .simc file onto START.cmd.'
}
if ([string]::IsNullOrWhiteSpace($Output)) { $Output=Join-Path $taskRoot 'results' }
if ([string]::IsNullOrWhiteSpace($Simc)) {
    $taskCursor=$taskRoot
    for ($taskLevel=0; $taskLevel -lt 6 -and $taskCursor; $taskLevel++) {
        foreach ($taskRelative in @('engine\simc.exe', 'dist\research\simc\extract\simc-1210.01.774babd-win64\simc.exe',
                                     'research\simc\extract\simc-1210.01.774babd-win64\simc.exe')) {
            $taskCandidate=Join-Path $taskCursor $taskRelative
            if (Test-Path -LiteralPath $taskCandidate -PathType Leaf) { $Simc=$taskCandidate; break }
        }
        if ($Simc) { break }
        $taskCursor=Split-Path -Parent $taskCursor
    }
}
if (-not $Simc) { throw 'Pinned SimC not found. Pass -Simc <path-to-simc.exe>; see README.md.' }
if ([string]::IsNullOrWhiteSpace($Reference)) {
    $Reference=Join-Path (Split-Path -Parent $Simc) 'profiles\MID2\MID2_Demon_Hunter_Havoc.simc'
}
$taskPolicy=Join-Path $taskRoot 'policy.json'
if (-not (Test-Path -LiteralPath $taskPolicy)) { $taskPolicy=Join-Path $taskRoot 'research\independent-policy\candidate.json' }
$taskPython=Get-Command python -ErrorAction Stop
& $taskPython.Source (Join-Path $PSScriptRoot 'personal_calibration.py') --profile $Profile --simc $Simc --reference $Reference --policy $taskPolicy --output $Output --iterations $Iterations --verify-iterations $VerifyIterations
if ($LASTEXITCODE -ne 0) { throw 'Calibration failed; inspect the error above. No new completed report was created.' }
Write-Host ('Completed reports: ' + [IO.Path]::GetFullPath($Output))
