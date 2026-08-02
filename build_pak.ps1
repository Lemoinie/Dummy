# build_pak.ps1 - Dummy Mod PAK Builder
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$pakSource  = Join-Path $scriptDir "pak_source"
$outDir     = Join-Path $scriptDir "Data"
$gameModDir = "C:\Games\Kingdom Come - Deliverance II\mods\Dummy"

if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

# ── 1. DATA PAK (Scripts + Libs) ────────────────────────
Write-Host "[1/2] Building data pak ..."
$dataPak = Join-Path $outDir "dummy.pak"
if (Test-Path $dataPak) { Remove-Item $dataPak -Force }

$zip = [System.IO.Compression.ZipFile]::Open($dataPak, [System.IO.Compression.ZipArchiveMode]::Create)

# defaultProfile.xml
$xmlPath = Join-Path $pakSource "Libs\Config\defaultProfile.xml"
if (Test-Path $xmlPath) {
    $xmlContent = Get-Content $xmlPath -Raw
    $e = $zip.CreateEntry("Libs/Config/defaultProfile.xml")
    $w = New-Object System.IO.StreamWriter($e.Open())
    $w.Write($xmlContent); $w.Flush(); $w.Close()
}

# All Lua scripts under Scripts/mods, registered under multiple prefixes
$luaFiles = Get-ChildItem -Path (Join-Path $pakSource "Scripts\mods") -Filter "*.lua"
$prefixes = @("Scripts/Systems", "Scripts/Utils", "Scripts/mods", "scripts/mods", "Scripts/Startup")
foreach ($f in $luaFiles) {
    $luaContent = Get-Content $f.FullName -Raw
    foreach ($prefix in $prefixes) {
        $entryPath = "$prefix/$($f.Name)"
        $e = $zip.CreateEntry($entryPath)
        $w = New-Object System.IO.StreamWriter($e.Open())
        $w.Write($luaContent); $w.Flush(); $w.Close()
    }
}
$zip.Dispose()
Write-Host "  -> $dataPak"

# ── 2. LOCALIZATION PAK ──────────────────────────────────
Write-Host "[2/2] Building localization pak ..."
$locPak = Join-Path $outDir "English_xml.pak"
if (Test-Path $locPak) { Remove-Item $locPak -Force }

$locXmlPath = Join-Path $pakSource "localization\English_xml.xml"
if (Test-Path $locXmlPath) {
    $zip = [System.IO.Compression.ZipFile]::Open($locPak, [System.IO.Compression.ZipArchiveMode]::Create)
    $xmlContent = Get-Content $locXmlPath -Raw
    $e = $zip.CreateEntry("English_xml.xml")
    $w = New-Object System.IO.StreamWriter($e.Open())
    $w.Write($xmlContent); $w.Flush(); $w.Close()
    $zip.Dispose()
    Write-Host "  -> $locPak"
} else {
    Write-Host "  (no localization XML found, skipping)"
}

# ── 3. INSTALL TO GAME ───────────────────────────────────
Write-Host "Installing to $gameModDir ..."
$gameData = Join-Path $gameModDir "Data"
$gameLoc  = Join-Path $gameModDir "localization"
if (-not (Test-Path $gameData)) { New-Item -ItemType Directory -Path $gameData | Out-Null }
if (-not (Test-Path $gameLoc))  { New-Item -ItemType Directory -Path $gameLoc  | Out-Null }

Copy-Item $dataPak                          -Destination (Join-Path $gameData "dummy.pak")       -Force
Copy-Item $locPak                           -Destination (Join-Path $gameLoc  "English_xml.pak") -Force
Copy-Item (Join-Path $scriptDir "mod.manifest") -Destination (Join-Path $gameModDir "mod.manifest")  -Force

Write-Host ""
Write-Host "SUCCESS: Built and installed to $gameModDir!" -ForegroundColor Green
