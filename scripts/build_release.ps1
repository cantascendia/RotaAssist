[CmdletBinding()]
param([string] $Version, [string] $OutputDir)
& (Join-Path $PSScriptRoot 'package_release.ps1') -Version $Version -OutputDir $OutputDir
exit $LASTEXITCODE
