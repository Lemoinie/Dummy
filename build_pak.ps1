# build_pak.ps1 - Dummy Mod PAK Builder with Build Logging
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$pakSource  = Join-Path $scriptDir "pak_source"
$outDir     = Join-Path $scriptDir "Data"
$logsDir    = Join-Path $scriptDir "logs"
$logFile    = Join-Path $logsDir "build.log"
$gameModDir = "C:\Games\Kingdom Come - Deliverance II\mods\Dummy"

if (-not (Test-Path $outDir))  { New-Item -ItemType Directory -Path $outDir  | Out-Null }
if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir | Out-Null }

# Initialize/Clear log file header
$initMsg = "==================== DUMMY MOD BUILD STARTED: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===================="
Out-File -FilePath $logFile -InputObject $initMsg -Encoding utf8

function Write-Log($msg, $color = "White") {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] $msg"
    Write-Host $msg -ForegroundColor $color
    Out-File -FilePath $logFile -InputObject $logLine -Append -Encoding utf8
}

# Helper: add a file to a zip archive at a given entry path
function Add-FileToZip($zip, $entryPath, $filePath) {
    $content = Get-Content $filePath -Raw
    $entry   = $zip.CreateEntry($entryPath)
    $writer  = New-Object System.IO.StreamWriter($entry.Open())
    $writer.Write($content)
    $writer.Flush()
    $writer.Close()
}

Write-Log "[1/3] Building Data PAK (dummy.pak) ..." "Cyan"
$dataPak = Join-Path $outDir "dummy.pak"
if (Test-Path $dataPak) { Remove-Item $dataPak -Force }
$zip = [System.IO.Compression.ZipFile]::Open($dataPak, [System.IO.Compression.ZipArchiveMode]::Create)

# --- defaultProfile.xml ---
$xmlPath = Join-Path $pakSource "Libs\Config\defaultProfile.xml"
if (Test-Path $xmlPath) {
    Add-FileToZip $zip "Libs/Config/defaultProfile.xml" $xmlPath
    Write-Log "  + Added Libs/Config/defaultProfile.xml"
}

# --- Lua scripts ---
$luaPrefixes = @("Scripts/Systems","Scripts/Utils","Scripts/mods","scripts/mods","Scripts/Startup")
$luaFiles = Get-ChildItem -Path (Join-Path $pakSource "Scripts\mods") -Filter "*.lua"
foreach ($f in $luaFiles) {
    foreach ($prefix in $luaPrefixes) {
        Add-FileToZip $zip "$prefix/$($f.Name)" $f.FullName
        Write-Log "  + Added $prefix/$($f.Name)"
    }
}

# --- AI behavior tree XMLs ---
$aiSrcDir = Join-Path $pakSource "AI"
if (Test-Path $aiSrcDir) {
    foreach ($f in Get-ChildItem $aiSrcDir -Filter "*.xml") {
        Add-FileToZip $zip "AI/$($f.Name)" $f.FullName
        Write-Log "  + Added AI/$($f.Name)"
    }
}

# --- AI table XMLs ---
$aiTableDir = Join-Path $pakSource "libs\tables\ai"
if (Test-Path $aiTableDir) {
    foreach ($f in Get-ChildItem $aiTableDir -Recurse -Filter "*.xml") {
        $relPath = $f.FullName.Substring($pakSource.Length + 1).Replace("\", "/")
        Add-FileToZip $zip $relPath $f.FullName
        Write-Log "  + Added $relPath"
    }
}

# --- RPG table XMLs ---
$rpgTableDir = Join-Path $pakSource "libs\tables\rpg"
if (Test-Path $rpgTableDir) {
    foreach ($f in Get-ChildItem $rpgTableDir -Filter "*.xml") {
        Add-FileToZip $zip "libs/tables/rpg/$($f.Name)" $f.FullName
        Write-Log "  + Added libs/tables/rpg/$($f.Name)"
    }
}

# --- Item table XMLs ---
$itemTableDir = Join-Path $pakSource "libs\tables\item"
if (Test-Path $itemTableDir) {
    foreach ($f in Get-ChildItem $itemTableDir -Filter "*.xml") {
        Add-FileToZip $zip "libs/tables/item/$($f.Name)" $f.FullName
        Write-Log "  + Added libs/tables/item/$($f.Name)"
    }
}

# --- Skald table XMLs ---
$skaldTableDir = Join-Path $pakSource "libs\tables\skald"
if (Test-Path $skaldTableDir) {
    foreach ($f in Get-ChildItem $skaldTableDir -Filter "*.xml") {
        Add-FileToZip $zip "libs/tables/skald/$($f.Name)" $f.FullName
        Write-Log "  + Added libs/tables/skald/$($f.Name)"
    }
}

# --- UI Scaleform Flash files (minimap.gfx & UIElements XML) ---
$uiDir = Join-Path $pakSource "libs\UI"
if (Test-Path $uiDir) {
    foreach ($f in Get-ChildItem $uiDir -Recurse) {
        if (-not $f.PSIsContainer) {
            $relPath = $f.FullName.Substring($pakSource.Length + 1).Replace("\", "/")
            Add-FileToZip $zip $relPath $f.FullName
            Write-Log "  + Added $relPath"
        }
    }
}

$zip.Dispose()
Write-Log "  -> Data PAK Created: $dataPak" "Green"

# ── 2. LOCALIZATION PAK ──────────────────────────────────
Write-Log "[2/3] Building Localization PAK (English_xml.pak) ..." "Cyan"
$locPak = Join-Path $outDir "English_xml.pak"
if (Test-Path $locPak) { Remove-Item $locPak -Force }
$locXmlPath = Join-Path $pakSource "localization\English_xml.xml"
if (Test-Path $locXmlPath) {
    $zip = [System.IO.Compression.ZipFile]::Open($locPak, [System.IO.Compression.ZipArchiveMode]::Create)
    Add-FileToZip $zip "English_xml.xml" $locXmlPath
    $zip.Dispose()
    Write-Log "  -> Localization PAK Created: $locPak" "Green"
} else {
    Write-Log "  (no localization XML found, skipping)" "Yellow"
}

# ── 3. INSTALL TO GAME ───────────────────────────────────
Write-Log "[3/3] Deploying files to $gameModDir ..." "Cyan"
$gameData = Join-Path $gameModDir "Data"
$gameLoc  = Join-Path $gameModDir "localization"
if (-not (Test-Path $gameData)) { New-Item -ItemType Directory -Path $gameData | Out-Null }
if (-not (Test-Path $gameLoc))  { New-Item -ItemType Directory -Path $gameLoc  | Out-Null }

try {
    Copy-Item $dataPak                              -Destination (Join-Path $gameData "dummy.pak")       -Force -ErrorAction Stop
    Copy-Item $locPak                               -Destination (Join-Path $gameLoc  "English_xml.pak") -Force -ErrorAction Stop
    Copy-Item (Join-Path $scriptDir "mod.manifest") -Destination (Join-Path $gameModDir "mod.manifest")  -Force -ErrorAction Stop
    Write-Log "  + Deployed PAKs and mod.manifest"

    # Copy standalone dummy.cfg configuration file to mod folder and game Bin folder
    $cfgSrc = Join-Path $pakSource "Scripts\Mods\dummy.cfg"
    $binDir = "C:\Games\Kingdom Come - Deliverance II\Bin\Win64MasterMasterSteamPGO"
    if (Test-Path $cfgSrc) {
        Copy-Item $cfgSrc -Destination (Join-Path $gameModDir "dummy.cfg") -Force -ErrorAction SilentlyContinue
        if (Test-Path $binDir) {
            Copy-Item $cfgSrc -Destination (Join-Path $binDir "dummy.cfg") -Force -ErrorAction SilentlyContinue
            Write-Log "  + Deployed dummy.cfg to Bin folder ($binDir)"
        }
    }

    # Copy DummyMod.asi to mod folder and game Bin folder
    $asiSrc = Join-Path $scriptDir "DummyMod.asi"
    if (Test-Path $asiSrc) {
        Copy-Item $asiSrc -Destination (Join-Path $gameModDir "DummyMod.asi") -Force -ErrorAction SilentlyContinue
        if (Test-Path $binDir) {
            Copy-Item $asiSrc -Destination (Join-Path $binDir "DummyMod.asi") -Force -ErrorAction SilentlyContinue
            Write-Log "  + Deployed DummyMod.asi to Bin folder ($binDir)"
        }
    }

    Write-Log ""
    Write-Log "SUCCESS: Built and installed successfully to $gameModDir!" "Green"
} catch {
    Write-Log ""
    Write-Log "WARNING: Game process (KingdomCome.exe) is currently active. Close game to overwrite active pak files!" "Yellow"
}

Write-Log "==================== DUMMY MOD BUILD COMPLETED: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===================="
