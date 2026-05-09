# Watched Playlist Cleaner — Emby Plugin

Automatically sorts your Emby playlists so that unwatched items always appear first, sorted by release date. Watched items move to the bottom. Each user's playlist is sorted independently based on their own watch history.

---

## Background and Inspiration

Emby is excellent for managing personal media libraries, but it has a significant limitation when watching content that spans multiple series and seasons within the same shared universe — such as the **Marvel Defenders Saga**, which weaves together Daredevil, Jessica Jones, Luke Cage, Iron Fist, The Defenders, The Punisher, Hawkeye, Echo, and Daredevil: Born Again across dozens of seasons in a specific intended viewing order.

The problem is that Emby treats each series independently. When you finish the last episode of one show, Emby's "Continue Watching" section will suggest the next episode of that same series rather than the next show in the correct cross-series viewing order. There is also no native way to track your progress through a hand-curated cross-series playlist — watched episodes remain mixed in with unwatched ones, making it difficult to know where you are.

This plugin was built specifically to address that limitation. By maintaining playlists sorted with unwatched content at the top and watched content at the bottom — respecting both release date order and season/episode sequencing — it gives you a clear, always up-to-date view of exactly where you are in any multi-series viewing journey, regardless of how many shows and seasons are involved.

While inspired by the Marvel Defenders Saga, the plugin works for any cross-series playlist — whether that's the DC Arrowverse, the Star Wars timeline, James Bond films in release order, or any other universe you want to watch in a specific sequence.

---

## Features

- **Unwatched items at the top** — sorted by release date, oldest first
- **Watched items at the bottom** — sorted by release date, oldest first
- **Per-user sorting** — each user's playlist is sorted based only on their own watched status
- **Season and episode tiebreaking** — for streaming content where all episodes share the same release date, sort order falls back to season and episode number
- **Automatic triggers** — sorts immediately when an item is marked as watched or unplayed, when playback finishes on any Emby client, or when items are added to a playlist
- **Nightly scheduled task** — runs at 3 AM as a safety net to catch anything missed
- **Original playlists are never deleted** — only the sort order is changed

---

## Requirements

- Windows
- Emby Server running .NET 8

---

## Installation and Updates

Download and double-click **`WatchedPlaylistCleaner-Setup.bat`** from this repository.

The script will automatically:
- Check whether the plugin is already installed
- Compare your installed version against the latest version on GitHub
- Install or update as needed
- Stop and restart Emby Server

### What the setup script does — step by step

For transparency, here is exactly what the script does so you can verify it before running it:

1. Fetches the latest version number from the `manifest.json` file in this repository
2. Checks whether `WatchedPlaylistCleaner.dll` exists in your Emby plugins folder
3. If not installed — downloads and installs the plugin
4. If already installed — compares version numbers:
   - **Same version** → does nothing, displays "already on latest version"
   - **GitHub is newer** → downloads and installs the update
   - **Your version is newer** → does nothing, displays "newer version already installed"
5. Stops the `EmbyServer` and `embytray` processes before making any changes
6. Downloads `WatchedPlaylistCleaner.dll` directly from this GitHub repository into your Emby plugins folder at:
   `%APPDATA%\Emby-Server\programdata\plugins\`
7. Restarts Emby Server

> **Note:** Windows may show a SmartScreen warning when running the `.bat` file for the first time since it was downloaded from the internet. Click **"Run anyway"** to proceed — the script only touches your Emby plugins folder and Emby processes.

---

## Manual Installation

If you prefer to install manually:

1. Download `WatchedPlaylistCleaner.dll` from this repository
2. Stop Emby Server
3. Copy the DLL into:
   ```
   C:\Users\[your username]\AppData\Roaming\Emby-Server\programdata\plugins\
   ```
4. Start Emby Server
5. Go to **Dashboard → Plugins** to confirm it appears

---

## Configuration — Choosing Which Playlists to Manage

The plugin will only sort playlists that you explicitly opt in to. This protects any playlists you have carefully curated and don't want automatically reordered.

**Option 1 — Via the Emby Dashboard (recommended)**

1. Go to **Dashboard → Plugins**
2. Click the **three dots (⋯)** next to Watched Playlist Cleaner
3. Click **Settings**
4. Move playlists between **Available** and **Managed** using the **+ Manage** and **✕ Remove** buttons
5. Click **Save**

**Option 2 — Via the config text file (fallback)**

If the dashboard settings page is not available, the plugin will fall back to reading from a text file at:
```
C:\Users\[your username]\AppData\Roaming\Emby-Server\programdata\plugins\WatchedPlaylistCleaner.config
```

Open this file in Notepad and add your playlist names one per line.

> **Important:** Playlist names are case-sensitive and must match exactly as they appear in Emby. Any playlist not listed will be left completely untouched.

Changes take effect immediately — no restart needed.

---

After installing, run the scheduled task once to sort any playlists that existed before the plugin was installed:

1. Go to **Dashboard → Scheduled Tasks**
2. Find **"Clean Watched Items from Playlists"**
3. Click the **Run (▶)** button

---

## How Sorting Works

The plugin sorts each playlist in this order:

| Priority | Rule |
|----------|------|
| 1st | Unwatched items before watched items |
| 2nd | Oldest release date first within each group |
| 3rd | Season number (tiebreaker for same release date) |
| 4th | Episode number (tiebreaker for same season) |

Movies are sorted by release date only — season and episode numbers do not apply.

---

## Compatibility

| Emby Version | .NET Version | Status |
|---|---|---|
| 4.9.x (2025+) | .NET 8 | ✅ Supported |
| 4.7.x / 4.8.x | .NET 6 | ⚠️ Requires code change — see below |
| Below 4.7 | .NET 5 or earlier | ⚠️ Not supported |

To run on an older Emby version, change `<TargetFramework>net8.0</TargetFramework>` to `net6.0` in `WatchedPlaylistCleaner.csproj` and rebuild.

To check your Emby version: **Dashboard → About**.

---

## Uninstalling

1. Stop Emby Server
2. Delete `WatchedPlaylistCleaner.dll` from:
   ```
   C:\Users\[your username]\AppData\Roaming\Emby-Server\programdata\plugins\
   ```
3. Start Emby Server

---

## FAQ

**Q: Does it modify my original playlists permanently?**
Yes — the sort order of the M3U playlist file on disk is updated. Your original playlists are never deleted, only reordered. You can always manually reorder items in Emby if needed.

**Q: What happens if I mark something as unwatched?**
The plugin detects the change and immediately moves the item back to the top of the unwatched section, sorted by its release date.

**Q: Will one user's watch history affect another user's playlist?**
No. Each user's playlist is sorted independently based only on their own watched status.

**Q: Does it work with movies and TV shows in the same playlist?**
Yes. Movies sort by release date. TV episodes sort by release date, then season, then episode number.

**Q: The plugin is installed but I don't see any sorting happening.**
Run the scheduled task manually from **Dashboard → Scheduled Tasks → Clean Watched Items from Playlists**. Also check the debug log at:
`%APPDATA%\Emby-Server\logs\WatchedPlaylistCleaner_debug.txt`

---

## Version

Current version: **0.9.2.0**

---

## License

MIT License — see [LICENSE](LICENSE) for details.
