# ============================================================
# Watched Playlist Cleaner - Emby Plugin Installer / Updater
# ============================================================
# Right-click this file and select "Run with PowerShell"
# ============================================================

$pluginName    = "WatchedPlaylistCleaner"
$manifestUrl   = "https://raw.githubusercontent.com/pieterf8587-ui/Emby---WatchedPlaylistCleaner/main/manifest.json"
$dllUrl        = "https://raw.githubusercontent.com/pieterf8587-ui/Emby---WatchedPlaylistCleaner/main/WatchedPlaylistCleaner.dll"
$pluginsFolder = "$env:APPDATA\Emby-Server\programdata\plugins"
$dllPath       = "$pluginsFolder\$pluginName.dll"
$backupPath    = "$pluginsFolder\$pluginName.dll.backup"
$embyExe       = "$env:APPDATA\Emby-Server\system\EmbyServer.exe"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Watched Playlist Cleaner" -ForegroundColor Cyan
Write-Host "  Installer / Updater" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# -------------------------------------------------------
# Step 1 - Fetch latest version from GitHub manifest
# -------------------------------------------------------
Write-Host "Step 1: Checking latest version on GitHub..." -ForegroundColor Yellow
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $manifest = Invoke-WebRequest -Uri $manifestUrl -UseBasicParsing | ConvertFrom-Json
    $latestVersion = $manifest[0].versions[0].version
    Write-Host "         Latest version on GitHub: $latestVersion" -ForegroundColor White
} catch {
    Write-Host "         ERROR: Could not reach GitHub." -ForegroundColor Red
    Write-Host "         Please check your internet connection and try again." -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit
}

# -------------------------------------------------------
# Step 2 - Determine action based on installed state
# -------------------------------------------------------
$action = ""

if (-not (Test-Path $dllPath)) {
    # DLL not present — fresh install
    $action = "install"
    Write-Host "         Plugin not installed — will perform fresh install." -ForegroundColor Yellow
} else {
    # DLL present — check version
    $installedVersion = (Get-Item $dllPath).VersionInfo.FileVersion
    if ([string]::IsNullOrEmpty($installedVersion)) {
        $installedVersion = "0.0.0.0"
    }
    Write-Host "         Installed version:         $installedVersion" -ForegroundColor White

    $installed = [System.Version]$installedVersion
    $latest    = [System.Version]$latestVersion

    if ($installed -eq $latest) {
        Write-Host ""
        Write-Host "============================================" -ForegroundColor Cyan
        Write-Host "  You are already on the latest version!" -ForegroundColor Green
        Write-Host "  No action needed." -ForegroundColor Green
        Write-Host "============================================" -ForegroundColor Cyan
        Write-Host ""
        Read-Host "Press Enter to exit"
        exit
    } elseif ($installed -gt $latest) {
        Write-Host ""
        Write-Host "============================================" -ForegroundColor Cyan
        Write-Host "  Newer version already installed." -ForegroundColor Yellow
        Write-Host "  Installed: $installedVersion" -ForegroundColor White
        Write-Host "  GitHub:    $latestVersion" -ForegroundColor White
        Write-Host "  No action taken." -ForegroundColor Yellow
        Write-Host "============================================" -ForegroundColor Cyan
        Write-Host ""
        Read-Host "Press Enter to exit"
        exit
    } else {
        # Installed version is older — update
        $action = "update"
        Write-Host "         Update available: $installedVersion -> $latestVersion" -ForegroundColor Yellow
    }
}

Write-Host ""

# -------------------------------------------------------
# Step 3 - Stop Emby
# -------------------------------------------------------
Write-Host "Step 2: Stopping Emby Server..." -ForegroundColor Yellow
$embyProcessNames = @("EmbyServer", "embytray")
foreach ($procName in $embyProcessNames) {
    $proc = Get-Process -Name $procName -ErrorAction SilentlyContinue
    if ($proc) {
        Stop-Process -Name $procName -Force
        Write-Host "         Stopped: $procName" -ForegroundColor Green
    }
}
Start-Sleep -Seconds 5

$remaining = Get-Process | Where-Object { $_.Name -like "*emby*" -or $_.Name -like "*Emby*" }
if ($remaining) { $remaining | Stop-Process -Force }
Start-Sleep -Seconds 2
Write-Host "         Emby Server stopped." -ForegroundColor Green

# -------------------------------------------------------
# Step 4 - Verify plugins folder exists (install only)
# -------------------------------------------------------
if ($action -eq "install") {
    Write-Host "Step 3: Locating plugins folder..." -ForegroundColor Yellow
    if (-not (Test-Path $pluginsFolder)) {
        Write-Host "         ERROR: Plugins folder not found at:" -ForegroundColor Red
        Write-Host "         $pluginsFolder" -ForegroundColor Red
        Write-Host "         Ensure Emby has been run at least once." -ForegroundColor Yellow
        Write-Host ""
        Read-Host "Press Enter to exit"
        exit
    }
    Write-Host "         Plugins folder found." -ForegroundColor Green
}

# -------------------------------------------------------
# Step 5 - Back up existing DLL (update only)
# -------------------------------------------------------
if ($action -eq "update") {
    Write-Host "Step 3: Backing up existing plugin..." -ForegroundColor Yellow
    Copy-Item -Path $dllPath -Destination $backupPath -Force
    Write-Host "         Backup created." -ForegroundColor Green
}

# -------------------------------------------------------
# Step 6 - Download DLL
# -------------------------------------------------------
$stepLabel = if ($action -eq "install") { "Step 4" } else { "Step 4" }
Write-Host "$stepLabel`: Downloading v$latestVersion ..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $dllUrl -OutFile $dllPath -UseBasicParsing
    if (Test-Path $dllPath) {
        Write-Host "         Downloaded successfully." -ForegroundColor Green
    } else {
        throw "File not found after download"
    }
} catch {
    Write-Host "         ERROR: Could not download plugin." -ForegroundColor Red

    if ($action -eq "update" -and (Test-Path $backupPath)) {
        Write-Host "         Restoring previous version..." -ForegroundColor Yellow
        Copy-Item -Path $backupPath -Destination $dllPath -Force
        Remove-Item $backupPath -Force
        Write-Host "         Previous version restored." -ForegroundColor Green
    }

    Write-Host ""
    Read-Host "Press Enter to exit"
    exit
}

# Remove backup if update succeeded
if ($action -eq "update" -and (Test-Path $backupPath)) {
    Remove-Item $backupPath -Force
}

# -------------------------------------------------------
# Step 7 - Start Emby
# -------------------------------------------------------
Write-Host "Step 5: Starting Emby Server..." -ForegroundColor Yellow
if (Test-Path $embyExe) {
    Start-Process $embyExe
    Write-Host "         Emby Server started." -ForegroundColor Green
} else {
    Write-Host "         Could not find Emby Server at: $embyExe" -ForegroundColor Red
    Write-Host "         Please start Emby Server manually." -ForegroundColor Yellow
}

# -------------------------------------------------------
# Done
# -------------------------------------------------------
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
if ($action -eq "install") {
    Write-Host "  Installation complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Watched Playlist Cleaner v$latestVersion" -ForegroundColor White
    Write-Host "  has been installed." -ForegroundColor White
} else {
    Write-Host "  Update complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Watched Playlist Cleaner updated" -ForegroundColor White
    Write-Host "  to v$latestVersion" -ForegroundColor White
}
Write-Host ""
Write-Host "  Open Emby > Dashboard > Plugins" -ForegroundColor White
Write-Host "  to confirm." -ForegroundColor White
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Read-Host "Press Enter to exit"
