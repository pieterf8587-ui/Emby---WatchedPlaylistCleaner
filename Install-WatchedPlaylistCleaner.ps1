# ============================================================
# Watched Playlist Cleaner - Emby Plugin Installer
# ============================================================
# Right-click this file and select "Run with PowerShell"
# ============================================================

$pluginName = "WatchedPlaylistCleaner"
$dllUrl = "https://raw.githubusercontent.com/pieterf8587-ui/Emby---WatchedPlaylistCleaner/main/WatchedPlaylistCleaner.dll"
$pluginFolder = Join-Path $env:APPDATA "Emby-Server\plugins\$pluginName"
$dllPath = Join-Path $pluginFolder "$pluginName.dll"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Watched Playlist Cleaner - Installer" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

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

# Step 2 - Create plugin folder
Write-Host "Step 2: Creating plugin folder..." -ForegroundColor Yellow
if (-not (Test-Path $pluginFolder)) {
    New-Item -ItemType Directory -Path $pluginFolder | Out-Null
    Write-Host "         Folder created: $pluginFolder" -ForegroundColor Green
} else {
    Write-Host "         Folder already exists." -ForegroundColor Green
}

# Step 3 - Download the DLL
Write-Host "Step 3: Downloading plugin..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $dllUrl -OutFile $dllPath
    Write-Host "         Plugin downloaded successfully." -ForegroundColor Green
} catch {
    Write-Host "         ERROR: Could not download plugin." -ForegroundColor Red
    Write-Host "         Please check your internet connection and try again." -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit
}

# Step 4 - Start Emby Server
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
Write-Host "  Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  The Watched Playlist Cleaner plugin has" -ForegroundColor White
Write-Host "  been installed. Open Emby and go to:" -ForegroundColor White
Write-Host "  Dashboard > Plugins to confirm." -ForegroundColor White
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Read-Host "Press Enter to exit"
