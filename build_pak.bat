@echo off
REM ──────────────────────────────────────────────────────
REM  build_pak.bat  –  Pack the Dummy mod into a .pak file
REM ──────────────────────────────────────────────────────

setlocal

set SCRIPT_DIR=%~dp0
set PAK_SOURCE=%SCRIPT_DIR%pak_source
set OUT_DIR=%SCRIPT_DIR%Data
set PAK_FILE=%OUT_DIR%\dummy.pak
set GAME_MOD_DIR=C:\Games\Kingdom Come - Deliverance II\mods\Dummy

echo.
echo ===== Dummy Mod – PAK Builder =====
echo.

if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"
if exist "%PAK_FILE%" del "%PAK_FILE%"

echo Building engine-compatible multi-path Zip pak ...
powershell -NoProfile -Command "Add-Type -AssemblyName System.IO.Compression; Add-Type -AssemblyName System.IO.Compression.FileSystem; $zip = [System.IO.Compression.ZipFile]::Open('%PAK_FILE%', [System.IO.Compression.ZipArchiveMode]::Create); $xmlContent = Get-Content '%PAK_SOURCE%\Libs\Config\defaultProfile.xml' -Raw; $e1 = $zip.CreateEntry('Libs/Config/defaultProfile.xml'); $w1 = New-Object System.IO.StreamWriter($e1.Open()); $w1.Write($xmlContent); $w1.Flush(); $w1.Close(); $luaFiles = Get-ChildItem -Path '%PAK_SOURCE%\Scripts\mods' -Filter '*.lua'; foreach ($f in $luaFiles) { $luaContent = Get-Content $f.FullName -Raw; foreach ($prefix in @('Scripts/Systems', 'Scripts/Utils', 'Scripts/mods', 'scripts/mods', 'Scripts/Startup')) { $entryPath = $prefix + '/' + $f.Name; $e = $zip.CreateEntry($entryPath); $w = New-Object System.IO.StreamWriter($e.Open()); $w.Write($luaContent); $w.Flush(); $w.Close() } }; $zip.Dispose()"

if %ERRORLEVEL% neq 0 (
    echo.
    echo ERROR: Compression failed.
    pause
    exit /b 1
)

echo.
echo Installing to %GAME_MOD_DIR% ...
if not exist "%GAME_MOD_DIR%\Data" mkdir "%GAME_MOD_DIR%\Data"
copy /Y "%PAK_FILE%" "%GAME_MOD_DIR%\Data\dummy.pak"
copy /Y "%SCRIPT_DIR%mod.manifest" "%GAME_MOD_DIR%\mod.manifest"

echo.
echo SUCCESS: %PAK_FILE% built and installed to %GAME_MOD_DIR%!
echo.
