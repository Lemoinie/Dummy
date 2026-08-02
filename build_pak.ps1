# build_pak.ps1 - Dummy Mod PAK Builder
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$pakSource  = Join-Path $scriptDir "pak_source"
$outDir     = Join-Path $scriptDir "Data"
$gameModDir = "C:\Games\Kingdom Come - Deliverance II\mods\Dummy"

if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

function Add-FileToZip {
    param (
        [Parameter(Mandatory=$true)] $ZipArchive,
        [Parameter(Mandatory=$true)] [string] $EntryPath,
        [Parameter(Mandatory=$true)] [string] $FilePath
    )
    $content = Get-Content -Path $FilePath -Raw
    $entry   = $ZipArchive.CreateEntry($EntryPath)
    $writer  = New-Object System.IO.StreamWriter($entry.Open())
    $writer.Write($content)
    $writer.Flush()
    $writer.Close()
}

# ── 1. DATA PAK (Scripts + Libs + AI + RPG Tables + Item Tables + Skald Tables) ─
Write-Host "[1/2] Building data pak ..."
$dataPak = Join-Path $outDir "dummy.pak"
if (Test-Path $dataPak) { Remove-Item -Path $dataPak -Force }
$zip = [System.IO.Compression.ZipFile]::Open($dataPak, [System.IO.Compression.ZipArchiveMode]::Create)

# --- defaultProfile.xml ---
$xmlPath = Join-Path $pakSource "Libs\Config\defaultProfile.xml"
if (Test-Path $xmlPath) {
    Add-FileToZip -ZipArchive $zip -EntryPath "Libs/Config/defaultProfile.xml" -FilePath $xmlPath
}

# --- Lua scripts ---
$luaPrefixes = @("Scripts/Systems", "Scripts/Utils", "Scripts/mods", "scripts/mods", "Scripts/Startup")
$luaFiles = Get-ChildItem -Path (Join-Path $pakSource "Scripts\mods") -Filter "*.lua"
foreach ($f in $luaFiles) {
    foreach ($prefix in $luaPrefixes) {
        $entryName = $prefix + "/" + $f.Name
        Add-FileToZip -ZipArchive $zip -EntryPath $entryName -FilePath $f.FullName
    }
}

# --- AI behavior tree XMLs ---
$aiSrcDir = Join-Path $pakSource "AI"
if (Test-Path $aiSrcDir) {
    foreach ($f in Get-ChildItem -Path $aiSrcDir -Filter "*.xml") {
        $entryName = "AI/" + $f.Name
        Add-FileToZip -ZipArchive $zip -EntryPath $entryName -FilePath $f.FullName
    }
}

# --- AI table XMLs (brain / subbrain / switching) ---
$aiTableDir = Join-Path $pakSource "libs\tables\ai"
if (Test-Path $aiTableDir) {
    foreach ($f in Get-ChildItem -Path $aiTableDir -Recurse -Filter "*.xml") {
        $relPath = $f.FullName.Substring($pakSource.Length + 1).Replace("\", "/")
        Add-FileToZip -ZipArchive $zip -EntryPath $relPath -FilePath $f.FullName
    }
}

# --- RPG table XMLs (soul / FactionTree) ---
$rpgTableDir = Join-Path $pakSource "libs\tables\rpg"
if (Test-Path $rpgTableDir) {
    foreach ($f in Get-ChildItem -Path $rpgTableDir -Filter "*.xml") {
        $entryName = "libs/tables/rpg/" + $f.Name
        Add-FileToZip -ZipArchive $zip -EntryPath $entryName -FilePath $f.FullName
    }
}

# --- Item table XMLs (clothing_preset) ---
$itemTableDir = Join-Path $pakSource "libs\tables\item"
if (Test-Path $itemTableDir) {
    foreach ($f in Get-ChildItem -Path $itemTableDir -Filter "*.xml") {
        $entryName = "libs/tables/item/" + $f.Name
        Add-FileToZip -ZipArchive $zip -EntryPath $entryName -FilePath $f.FullName
    }
}

# --- Skald table XMLs (skald_character) ---
$skaldTableDir = Join-Path $pakSource "libs\tables\skald"
if (Test-Path $skaldTableDir) {
    foreach ($f in Get-ChildItem -Path $skaldTableDir -Filter "*.xml") {
        $entryName = "libs/tables/skald/" + $f.Name
        Add-FileToZip -ZipArchive $zip -EntryPath $entryName -FilePath $f.FullName
    }
}

$zip.Dispose()
Write-Host "  -> $dataPak"

# ── 2. LOCALIZATION PAK ──────────────────────────────────
Write-Host "[2/2] Building localization pak ..."
$locPak = Join-Path $outDir "English_xml.pak"
if (Test-Path $locPak) { Remove-Item -Path $locPak -Force }
$locXmlPath = Join-Path $pakSource "localization\English_xml.xml"
if (Test-Path $locXmlPath) {
    $zipLoc = [System.IO.Compression.ZipFile]::Open($locPak, [System.IO.Compression.ZipArchiveMode]::Create)
    Add-FileToZip -ZipArchive $zipLoc -EntryPath "English_xml.xml" -FilePath $locXmlPath
    $zipLoc.Dispose()
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

Copy-Item -Path $dataPak -Destination (Join-Path $gameData "dummy.pak") -Force
Copy-Item -Path $locPak -Destination (Join-Path $gameLoc "English_xml.pak") -Force
Copy-Item -Path (Join-Path $scriptDir "mod.manifest") -Destination (Join-Path $gameModDir "mod.manifest") -Force

Write-Host ""
Write-Host "SUCCESS: Built and installed to $gameModDir!" -ForegroundColor Green
