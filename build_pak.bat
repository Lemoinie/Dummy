@echo off
REM ──────────────────────────────────────────────────────
REM  build_pak.bat  –  Pack the Dummy mod into .pak files
REM ──────────────────────────────────────────────────────
setlocal
set SCRIPT_DIR=%~dp0

echo.
echo ===== Dummy Mod – PAK Builder =====
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%build_pak.ps1"

if %ERRORLEVEL% neq 0 (
    echo ERROR: Build failed.
    pause
    exit /b 1
)

echo.
echo Build complete!
echo.
