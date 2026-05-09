# ============================================================
# Watched Playlist Cleaner - Emby Plugin Updater
# ============================================================
# Right-click this file and select "Run with PowerShell"
# ============================================================

$pluginName = "WatchedPlaylistCleaner"
$manifestUrl = "https://raw.githubusercontent.com/pieterf8587-ui/Emby---WatchedPlaylistCleaner/main/manifest.json"
$dllUrl = "https://raw.githubusercontent.com/pieterf8587-ui/Emby---WatchedPlaylistCleaner/main/WatchedPlaylistCleaner.dll"
$pluginsFolder = "$env:APPDATA\Emby-Server\programdata\plugins"
$dllPath = "$pluginsFolder\$pluginName.dll"
$backupPath = "$pluginsFolder\$pluginName.dll.backup"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Watched Playlist Cleaner - Updater" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check plugin is already installed
if (-not (Test-Path $dllPath)) {
    Write-Host "Plugin not found at: $dllPath" -ForegroundColor Red
    Write-Host "Please run the Installer first." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit
}

# Step 1 - Check current installed version
Write-Host "Step 1: Checking versions..." -ForegroundColor Yellow

$installedVersion = (Get-Item $dllPath).VersionInfo.FileVersion
if ([string]::IsNullOrEmpty($installedVersion)) {
    $installedVersion = "Unknown"
}
Write-Host "         Installed version: $installedVersion" -ForegroundColor White

# Fetch latest version from GitHub manifest
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $manifest = Invoke-WebRequest -Uri $manifestUrl -UseBasicParsing | ConvertFrom-Json
    $latestVersion = $manifest[0].versions[0].version
    Write-Host "         Latest version:    $latestVersion" -ForegroundColor White
} catch {
    Write-Host "         ERROR: Could not fetch version info from GitHub." -ForegroundColor Red
    Write-Host "         Please check your internet connection and try again." -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit
}

# Compare versions
if ($installedVersion -eq $latestVersion) {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  You are already on the latest version!" -ForegroundColor Green
    Write-Host "  No update needed." -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit
}

Write-Host ""
Write-Host "  A new version is available: $latestVersion" -ForegroundColor Yellow
Write-Host "  Proceeding with update..." -ForegroundColor Yellow
Write-Host ""

# Step 2 - Stop ALL Emby related processes
Write-Host "Step 2: Stopping Emby Server..." -ForegroundColor Yellow
$embyProcessNames = @("EmbyServer", "embytray")
foreach ($procName in $embyProcessNames) {
    $proc = Get-Process -Name $procName -ErrorAction SilentlyContinue
    if ($proc) {
        Stop-Process -Name $procName -Force
        Write-Host "         Stopped process: $procName" -ForegroundColor Green
    }
}
Start-Sleep -Seconds 5

$remaining = Get-Process | Where-Object { $_.Name -like "*emby*" -or $_.Name -like "*Emby*" }
if ($remaining) {
    $remaining | Stop-Process -Force
}
Start-Sleep -Seconds 2
Write-Host "         Emby Server stopped." -ForegroundColor Green

# Step 3 - Back up existing DLL
Write-Host "Step 3: Backing up existing plugin..." -ForegroundColor Yellow
Copy-Item -Path $dllPath -Destination $backupPath -Force
Write-Host "         Backup created." -ForegroundColor Green

# Step 4 - Download the new DLL
Write-Host "Step 4: Downloading v$latestVersion ..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $dllUrl -OutFile $dllPath -UseBasicParsing
    if (Test-Path $dllPath) {
        Write-Host "         Downloaded successfully." -ForegroundColor Green
    } else {
        throw "File not found after download"
    }
} catch {
    Write-Host "         ERROR: Could not download update." -ForegroundColor Red
    Write-Host "         Restoring previous version..." -ForegroundColor Yellow
    Copy-Item -Path $backupPath -Destination $dllPath -Force
    Write-Host "         Previous version restored." -ForegroundColor Green
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit
}

# Step 5 - Remove backup
Remove-Item $backupPath -Force

# Step 6 - Start Emby Server
Write-Host "Step 5: Starting Emby Server..." -ForegroundColor Yellow
$embyExe = "$env:APPDATA\Emby-Server\system\EmbyServer.exe"
if (Test-Path $embyExe) {
    Start-Process $embyExe
    Write-Host "         Emby Server started." -ForegroundColor Green
} else {
    Write-Host "         Could not find Emby Server at: $embyExe" -ForegroundColor Red
    Write-Host "         Please start Emby Server manually." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Update complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  Updated from v$installedVersion to v$latestVersion" -ForegroundColor White
Write-Host "  Open Emby > Dashboard > Plugins to confirm." -ForegroundColor White
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Read-Host "Press Enter to exit"
