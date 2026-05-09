@echo off
setlocal

:: Write the PowerShell script to a temp file and run it
set TEMPSCRIPT=%TEMP%\WatchedPlaylistCleanerSetup.ps1

(
echo $pluginName    = 'WatchedPlaylistCleaner'
echo $manifestUrl   = 'https://raw.githubusercontent.com/pieterf8587-ui/Emby---WatchedPlaylistCleaner/main/manifest.json'
echo $dllUrl        = 'https://raw.githubusercontent.com/pieterf8587-ui/Emby---WatchedPlaylistCleaner/main/WatchedPlaylistCleaner.dll'
echo $pluginsFolder = "$env:APPDATA\Emby-Server\programdata\plugins"
echo $dllPath       = "$pluginsFolder\WatchedPlaylistCleaner.dll"
echo $embyExe       = "$env:APPDATA\Emby-Server\system\EmbyServer.exe"
echo.
echo Write-Host ''
echo Write-Host '============================================' -ForegroundColor Cyan
echo Write-Host '  Watched Playlist Cleaner - Setup' -ForegroundColor Cyan
echo Write-Host '============================================' -ForegroundColor Cyan
echo Write-Host ''
echo Write-Host 'Step 1: Checking latest version on GitHub...' -ForegroundColor Yellow
echo try {
echo     [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
echo     $manifest = Invoke-WebRequest -Uri $manifestUrl -UseBasicParsing ^| ConvertFrom-Json
echo     $latestVersion = $manifest[0].versions[0].version
echo     Write-Host "         Latest version on GitHub: $latestVersion" -ForegroundColor White
echo } catch {
echo     Write-Host '         ERROR: Could not reach GitHub.' -ForegroundColor Red
echo     Read-Host 'Press Enter to exit'; exit
echo }
echo $action = ''
echo if (-not (Test-Path $dllPath^)^) {
echo     $action = 'install'
echo     Write-Host '         Plugin not installed - will perform fresh install.' -ForegroundColor Yellow
echo } else {
echo     try { $installedVersion = (Get-Item $dllPath -ErrorAction Stop^).VersionInfo.FileVersion } catch { $installedVersion = $null }
echo     if ([string]::IsNullOrEmpty($installedVersion^)^) { $installedVersion = '0.0.0.0' }
echo     Write-Host "         Installed version:         $installedVersion" -ForegroundColor White
echo     $installed = [System.Version]$installedVersion
echo     $latest    = [System.Version]$latestVersion
echo     if ($installed -eq $latest^) {
echo         Write-Host ''; Write-Host '  You already have the latest version!' -ForegroundColor Green
echo         Read-Host 'Press Enter to exit'; exit
echo     } elseif ($installed -gt $latest^) {
echo         Write-Host "  Newer version already installed. Installed: $installedVersion  GitHub: $latestVersion" -ForegroundColor Yellow
echo         Read-Host 'Press Enter to exit'; exit
echo     } else {
echo         $action = 'update'
echo         Write-Host "         Update available: $installedVersion to $latestVersion" -ForegroundColor Yellow
echo     }
echo }
echo Write-Host ''
echo Write-Host 'Step 2: Stopping Emby Server...' -ForegroundColor Yellow
echo foreach ($procName in @('EmbyServer', 'embytray'^)^) {
echo     $proc = Get-Process -Name $procName -ErrorAction SilentlyContinue
echo     if ($proc^) { Stop-Process -Name $procName -Force; Write-Host "         Stopped: $procName" -ForegroundColor Green }
echo }
echo Start-Sleep -Seconds 5
echo Get-Process ^| Where-Object { $_.Name -like '*emby*' } ^| Stop-Process -Force -ErrorAction SilentlyContinue
echo Start-Sleep -Seconds 2
echo Write-Host '         Emby Server stopped.' -ForegroundColor Green
echo if ($action -eq 'install'^) {
echo     Write-Host 'Step 3: Locating plugins folder...' -ForegroundColor Yellow
echo     if (-not (Test-Path $pluginsFolder^)^) {
echo         Write-Host '         ERROR: Plugins folder not found.' -ForegroundColor Red
echo         Read-Host 'Press Enter to exit'; exit
echo     }
echo     Write-Host '         Plugins folder found.' -ForegroundColor Green
echo }
echo Write-Host "Step 4: Downloading v$latestVersion ..." -ForegroundColor Yellow
echo try {
echo     Invoke-WebRequest -Uri $dllUrl -OutFile $dllPath -UseBasicParsing
echo     if (Test-Path $dllPath^) { Write-Host '         Downloaded successfully.' -ForegroundColor Green }
echo     else { throw 'File not found after download' }
echo } catch {
echo     Write-Host "         ERROR: $_" -ForegroundColor Red
echo     Read-Host 'Press Enter to exit'; exit
echo }
echo Write-Host 'Step 5: Starting Emby Server...' -ForegroundColor Yellow
echo if (Test-Path $embyExe^) { Start-Process $embyExe; Write-Host '         Emby Server started.' -ForegroundColor Green }
echo else { Write-Host '         Please start Emby manually.' -ForegroundColor Yellow }
echo Write-Host ''
echo Write-Host '============================================' -ForegroundColor Cyan
echo if ($action -eq 'install'^) { Write-Host "  Installation complete! v$latestVersion installed." -ForegroundColor Green }
echo else { Write-Host "  Update complete! Updated to v$latestVersion" -ForegroundColor Green }
echo Write-Host '  Open Emby > Dashboard > Plugins to confirm.' -ForegroundColor White
echo Write-Host '============================================' -ForegroundColor Cyan
echo Read-Host 'Press Enter to exit'
) > "%TEMPSCRIPT%"

PowerShell -ExecutionPolicy Bypass -NoExit -File "%TEMPSCRIPT%"
del "%TEMPSCRIPT%"
