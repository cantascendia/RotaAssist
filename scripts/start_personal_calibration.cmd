@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\run_personal_calibration.ps1" -Profile "%~1"
pause
