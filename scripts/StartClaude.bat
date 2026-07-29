@echo off
rem Double-click launcher: starts px then Claude Code.
rem Expects start-claude.ps1 in the same folder as this .bat.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-claude.ps1"
pause
