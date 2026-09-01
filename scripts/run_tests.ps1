# RotaAssist local test runner wrapper.
# 本地测试运行器包装：定位 Lua 5.1 并从仓库根目录执行 run_tests.lua。
# Usage:  .\scripts\run_tests.ps1            # all tests
#         .\scripts\run_tests.ps1 registry   # filter by substring(s)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$luaCandidates = @(
    "C:\Program Files (x86)\Lua\5.1\lua.exe",
    "C:\Program Files\Lua\5.1\lua.exe"
)
$lua = $null
foreach ($c in $luaCandidates) {
    if (Test-Path $c) { $lua = $c; break }
}
if (-not $lua) {
    $cmd = Get-Command lua -ErrorAction SilentlyContinue
    if ($cmd) { $lua = $cmd.Source }
}
if (-not $lua) {
    Write-Error "Lua 5.1 not found. Install it or edit the candidate list in this script."
    exit 2
}

& $lua "scripts\run_tests.lua" @args
exit $LASTEXITCODE
