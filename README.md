# Watched Playlist Cleaner — Emby Plugin

Automatically sorts your Emby playlists so that unwatched items always appear first, sorted by release date. Watched items move to the bottom. Works per user, triggers automatically when items are watched, unplayed, or added to a playlist.

## Features
- Unwatched items at the top, sorted by release date
- Watched items move to the bottom automatically
- Triggers when an episode or movie is marked as watched or unplayed
- Triggers when playback finishes on any Emby client
- Triggers when new items are added to a playlist
- Each user's playlist is sorted independently based on their own watch history
- Nightly scheduled task as a safety net

## Requirements
- Emby Server running .NET 8
- Windows

## Installation
1. Download `Install-WatchedPlaylistCleaner.ps1`
2. Right-click it and select **Run with PowerShell**
3. The script will automatically install the plugin and restart Emby

## Updating
1. Download `Update-WatchedPlaylistCleaner.ps1`
2. Right-click it and select **Run with PowerShell**
3. The script will automatically update the plugin and restart Emby

## Manual Installation
If you prefer to install manually:
1. Download `WatchedPlaylistCleaner.dll`
2. Create a folder called `WatchedPlaylistCleaner` inside:
   `C:\Users\[your username]\AppData\Roaming\Emby-Server\plugins\`
3. Copy the DLL into that folder
4. Restart Emby Server

## Version
Current version: 0.9.1.5





