#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if command -v pwsh >/dev/null 2>&1; then
  PS=(pwsh -NoProfile)
elif command -v powershell.exe >/dev/null 2>&1; then
  PS=(powershell.exe -NoProfile -ExecutionPolicy Bypass)
else
  echo "PowerShell 7 or Windows PowerShell is required for the verified installer." >&2
  exit 1
fi

args=(-File "$SCRIPT_DIR/install_test.ps1")
[[ -n "${1:-}" ]] && args+=(-AddOnsPath "$1")
[[ -n "${2:-}" ]] && args+=(-PackagePath "$2")
"${PS[@]}" "${args[@]}"
