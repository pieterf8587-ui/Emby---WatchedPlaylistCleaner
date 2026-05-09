# ============================================================
# Watched Playlist Cleaner - Emby Plugin Updater
# ============================================================
# Right-click this file and select "Run with PowerShell"
# ============================================================

$pluginName = "WatchedPlaylistCleaner"
$dllUrl = "https://raw.githubusercontent.com/pieterf8587-ui/Emby---WatchedPlaylistCleaner/main/WatchedPlaylistCleaner.dll"
$pluginsFolder = Join-Path $env:APPDATA "Emby-Server\programdata\plugins"
$dllPath = Join-Path $pluginsFolder "$pluginName.dll"
$backupPath = Join-Path $pluginsFolder "$pluginName.dll.backup"

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

# Step 1 - Stop Emby Server
Write-Host "Step 1: Stopping Emby Server..." -ForegroundColor Yellow
$embyProcess = Get-Process -Name "EmbyServer" -ErrorAction SilentlyContinue
if ($embyProcess) {
    Stop-Process -Name "EmbyServer" -Force
    Start-Sleep -Seconds 3
    Write-Host "         Emby Server stopped." -ForegroundColor Green
} else {
    Write-Host "         Emby Server was not running." -ForegroundColor Green
}

# Step 2 - Back up existing DLL
Write-Host "Step 2: Backing up existing plugin..." -ForegroundColor Yellow
Copy-Item -Path $dllPath -Destination $backupPath -Force
Write-Host "         Backup created." -ForegroundColor Green

# Step 3 - Download the new DLL
Write-Host "Step 3: Downloading latest version..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $dllUrl -OutFile $dllPath
    Write-Host "         Latest version downloaded." -ForegroundColor Green
} catch {
    Write-Host "         ERROR: Could not download update." -ForegroundColor Red
    Write-Host "         Restoring previous version..." -ForegroundColor Yellow
    Copy-Item -Path $backupPath -Destination $dllPath -Force
    Write-Host "         Previous version restored." -ForegroundColor Green
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit
}

# Step 4 - Remove backup
Remove-Item $backupPath -Force

# Step 5 - Start Emby Server
Write-Host "Step 4: Starting Emby Server..." -ForegroundColor Yellow
$embyExe = Join-Path $env:APPDATA "Emby-Server\system\EmbyServer.exe"
if (Test-Path $embyExe) {
    Start-Process $embyExe
    Write-Host "         Emby Server started." -ForegroundColor Green
} else {
    Write-Host "         Could not find Emby Server executable." -ForegroundColor Red
    Write-Host "         Please start Emby Server manually." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Update complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  The Watched Playlist Cleaner plugin has" -ForegroundColor White
Write-Host "  been updated. Open Emby and go to:" -ForegroundColor White
Write-Host "  Dashboard > Plugins to confirm the" -ForegroundColor White
Write-Host "  new version number." -ForegroundColor White
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Read-Host "Press Enter to exit"
