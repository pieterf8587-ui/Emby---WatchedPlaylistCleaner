# ============================================================
# Watched Playlist Cleaner - Emby Plugin Installer
# ============================================================
# Right-click this file and select "Run with PowerShell"
# ============================================================

$pluginName = "WatchedPlaylistCleaner"
$dllUrl = "https://raw.githubusercontent.com/pieterf8587-ui/Emby---WatchedPlaylistCleaner/main/WatchedPlaylistCleaner.dll"
$pluginsFolder = "$env:APPDATA\Emby-Server\programdata\plugins"
$dllPath = "$pluginsFolder\$pluginName.dll"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Watched Playlist Cleaner - Installer" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Step 1 - Stop ALL Emby related processes
Write-Host "Step 1: Stopping Emby Server..." -ForegroundColor Yellow
$embyProcessNames = @("EmbyServer", "embytray")
foreach ($procName in $embyProcessNames) {
    $proc = Get-Process -Name $procName -ErrorAction SilentlyContinue
    if ($proc) {
        Stop-Process -Name $procName -Force
        Write-Host "         Stopped process: $procName" -ForegroundColor Green
    }
}
Start-Sleep -Seconds 5

# Double-check no Emby processes remain
$remaining = Get-Process | Where-Object { $_.Name -like "*emby*" -or $_.Name -like "*Emby*" }
if ($remaining) {
    $remaining | Stop-Process -Force
    Write-Host "         Stopped additional Emby processes." -ForegroundColor Green
}
Start-Sleep -Seconds 2
Write-Host "         Emby Server stopped." -ForegroundColor Green

# Step 2 - Verify plugins folder exists
Write-Host "Step 2: Locating plugins folder..." -ForegroundColor Yellow
Write-Host "         Target path: $pluginsFolder" -ForegroundColor Gray
if (-not (Test-Path $pluginsFolder)) {
    Write-Host "         ERROR: Plugins folder not found." -ForegroundColor Red
    Write-Host "         Expected: $pluginsFolder" -ForegroundColor Yellow
    Write-Host "         Please ensure Emby Server is installed and has been run at least once." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit
}
Write-Host "         Plugins folder found." -ForegroundColor Green

# Step 3 - Download the DLL directly into plugins folder
Write-Host "Step 3: Downloading plugin to $dllPath ..." -ForegroundColor Yellow
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $dllUrl -OutFile $dllPath -UseBasicParsing
    if (Test-Path $dllPath) {
        Write-Host "         Plugin downloaded successfully to:" -ForegroundColor Green
        Write-Host "         $dllPath" -ForegroundColor Green
    } else {
        throw "File not found after download"
    }
} catch {
    Write-Host "         ERROR: Could not download plugin." -ForegroundColor Red
    Write-Host "         Details: $_" -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit
}

# Step 4 - Start Emby Server
Write-Host "Step 4: Starting Emby Server..." -ForegroundColor Yellow
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
Write-Host "  Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  The Watched Playlist Cleaner plugin has" -ForegroundColor White
Write-Host "  been installed. Open Emby and go to:" -ForegroundColor White
Write-Host "  Dashboard > Plugins to confirm." -ForegroundColor White
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Read-Host "Press Enter to exit"
