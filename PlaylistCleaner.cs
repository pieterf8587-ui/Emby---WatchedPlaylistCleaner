using MediaBrowser.Controller.Entities;
using MediaBrowser.Controller.Library;
using MediaBrowser.Controller.Playlists;
using MediaBrowser.Controller.Providers;
using MediaBrowser.Model.IO;
using MediaBrowser.Model.Logging;
using MediaBrowser.Model.Querying;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

namespace WatchedPlaylistCleaner
{
    public class PlaylistCleaner
    {
        private readonly ILibraryManager _libraryManager;
        private readonly IUserManager _userManager;
        private readonly IUserDataManager _userDataManager;
        private readonly ILibraryMonitor _libraryMonitor;
        private readonly IFileSystem _fileSystem;
        private readonly ILogger _logger;

        private static readonly string PlaylistFolder = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "Emby-Server", "programdata", "data", "userplaylists");

        private static readonly string DebugLog = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "Emby-Server", "logs", "WatchedPlaylistCleaner_debug.txt");

        private void Log(string message)
        {
            var line = $"{DateTime.Now:yyyy-MM-dd HH:mm:ss} {message}{Environment.NewLine}";
            try { File.AppendAllText(DebugLog, line); } catch { }
            _logger.Info(message);
        }

        public PlaylistCleaner(
            ILibraryManager libraryManager,
            IPlaylistManager playlistManager,
            IUserManager userManager,
            IUserDataManager userDataManager,
            ILibraryMonitor libraryMonitor,
            IFileSystem fileSystem,
            ILogManager logManager)
        {
            _libraryManager = libraryManager;
            _userManager = userManager;
            _userDataManager = userDataManager;
            _libraryMonitor = libraryMonitor;
            _fileSystem = fileSystem;
            _logger = logManager.GetLogger(Plugin.Instance.Name);
        }

        // -----------------------------------------------------------------------
        // Called by the event listener — only resorts the triggering user's playlists
        // using only that user's watched status
        // -----------------------------------------------------------------------
        public async Task RemoveWatchedItemFromAllPlaylists(
            BaseItem item,
            Guid userId,
            CancellationToken cancellationToken)
        {
            var user = _userManager.GetUserById(userId);
            if (user == null)
            {
                Log($"Could not find user with ID {userId}");
                return;
            }

            Log($"'{item.Name}' played status changed for user '{user.Name}' — resorting their playlists");

            var playlists = GetPlaylistsForUser(user);
            Log($"Found {playlists.Count} playlist(s) for user '{user.Name}'");

            foreach (var m3uPath in playlists)
            {
                cancellationToken.ThrowIfCancellationRequested();
                await ReorderPlaylistForUser(m3uPath, user);
            }
        }

        // -----------------------------------------------------------------------
        // Called by the scheduled task — processes each user independently
        // -----------------------------------------------------------------------
        public async Task CleanAllPlaylistsForAllUsers(
            IProgress<double> progress,
            CancellationToken cancellationToken)
        {
            Log("=== Scheduled playlist reorder started ===");

            var users = _userManager.GetUserList(new UserQuery());
            Log($"Found {users.Length} user(s)");

            int done = 0;
            foreach (var user in users)
            {
                Log($"Processing user: {user.Name}");

                var playlists = GetPlaylistsForUser(user);
                Log($"  Found {playlists.Count} playlist(s)");

                foreach (var m3uPath in playlists)
                {
                    cancellationToken.ThrowIfCancellationRequested();
                    await ReorderPlaylistForUser(m3uPath, user);
                    done++;
                    progress.Report(100.0 * done / Math.Max(users.Length * playlists.Count, 1));
                }
            }

            Log("=== Scheduled playlist reorder finished ===");
        }

        // -----------------------------------------------------------------------
        // Private helpers
        // -----------------------------------------------------------------------

        /// <summary>
        /// Gets the M3U playlist files that belong to a specific user by querying
        /// Emby's playlist library filtered by user, then resolving to file paths.
        /// </summary>
        private List<string> GetPlaylistsForUser(User user)
        {
            var query = new InternalItemsQuery
            {
                IncludeItemTypes = new[] { "Playlist" },
                Recursive = true,
                User = user
            };

            var paths = _libraryManager
                .GetItemList(query)
                .OfType<Playlist>()
                .Where(p => !string.IsNullOrEmpty(p.Path) && File.Exists(p.Path))
                .Select(p => p.Path)
                .ToList();

            Log($"  Playlist paths for '{user.Name}': {string.Join(", ", paths.Select(Path.GetFileName))}");
            return paths;
        }

        /// <summary>
        /// Sorts a playlist M3U file for a specific user:
        ///   - Unwatched items first, sorted by release date ascending
        ///   - Watched items last, sorted by release date ascending
        /// Only that user's watched status is considered.
        /// </summary>
        private async Task ReorderPlaylistForUser(string m3uPath, User user)
        {
            try
            {
                var entries = ParseM3U(m3uPath);
                Log($"  '{Path.GetFileName(m3uPath)}': parsed {entries.Count} entries for user '{user.Name}'");

                var resolved = new List<ResolvedEntry>();

                foreach (var entry in entries)
                {
                    var absolutePath = ResolveRelativePath(m3uPath, entry.FilePath);
                    var libraryItem = _libraryManager.FindByPath(absolutePath, false);

                    bool isWatched = false;
                    DateTimeOffset releaseDate = DateTimeOffset.MinValue;

                    if (libraryItem != null)
                    {
                        // Only check THIS user's watched status
                        isWatched = _userDataManager.GetUserData(user, libraryItem)?.Played == true;
                        releaseDate = libraryItem.PremiereDate ?? DateTimeOffset.MinValue;
                    }

                    resolved.Add(new ResolvedEntry
                    {
                        Entry = entry,
                        IsWatched = isWatched,
                        ReleaseDate = releaseDate
                    });
                }

                var sorted = resolved
                    .OrderBy(r => r.IsWatched ? 1 : 0)
                    .ThenBy(r => r.ReleaseDate)
                    .Select(r => r.Entry)
                    .ToList();

                int watchedCount = resolved.Count(r => r.IsWatched);
                int unwatchedCount = resolved.Count - watchedCount;
                Log($"  '{user.Name}': {unwatchedCount} unwatched at top, {watchedCount} watched at bottom");

                WriteM3U(m3uPath, sorted);

                // Find the playlist item and refresh it directly for faster UI update
                var playlistItem = _libraryManager
                    .GetItemList(new InternalItemsQuery
                    {
                        IncludeItemTypes = new[] { "Playlist" },
                        Recursive = true,
                        User = user
                    })
                    .OfType<Playlist>()
                    .FirstOrDefault(p => string.Equals(p.Path, m3uPath, StringComparison.OrdinalIgnoreCase));

                if (playlistItem != null)
                {
                    await playlistItem.RefreshMetadata(
                        new MetadataRefreshOptions(new DirectoryService(_fileSystem)),
                        CancellationToken.None).ConfigureAwait(false);
                    Log($"  Playlist metadata refreshed directly");
                }
                else
                {
                    _libraryMonitor.ReportFileSystemChanged(m3uPath);
                    Log($"  Playlist item not found — falling back to file system notification");
                }

                await Task.CompletedTask;
            }
            catch (Exception ex)
            {
                Log($"  ERROR reordering '{m3uPath}' for '{user.Name}': {ex.Message}");
            }
        }

        private void WriteM3U(string m3uPath, List<M3UEntry> sortedEntries)
        {
            var lines = new List<string>
            {
                "#EXTM3U",
                $"#PLAYLIST:{Path.GetFileNameWithoutExtension(m3uPath)}"
            };

            foreach (var entry in sortedEntries)
            {
                lines.AddRange(entry.TagLines);
                lines.Add(entry.FilePath);
            }

            File.WriteAllLines(m3uPath, lines);
        }

        private List<M3UEntry> ParseM3U(string m3uPath)
        {
            var entries = new List<M3UEntry>();
            var lines = File.ReadAllLines(m3uPath);
            var pendingLines = new List<string>();

            foreach (var line in lines)
            {
                var trimmed = line.Trim();

                if (trimmed.StartsWith("#EXTM3U") || trimmed.StartsWith("#PLAYLIST:"))
                    continue;

                if (trimmed.StartsWith("#"))
                {
                    pendingLines.Add(line);
                    continue;
                }

                if (!string.IsNullOrWhiteSpace(trimmed))
                {
                    var title = trimmed;
                    var extInf = pendingLines
                        .FirstOrDefault(l => l.TrimStart().StartsWith("#EXTINF:"));
                    if (extInf != null)
                    {
                        var comma = extInf.IndexOf(',');
                        if (comma >= 0)
                            title = extInf.Substring(comma + 1).Trim();
                    }

                    entries.Add(new M3UEntry
                    {
                        TagLines = new List<string>(pendingLines),
                        FilePath = trimmed,
                        Title = title
                    });

                    pendingLines.Clear();
                }
            }

            return entries;
        }

        private string ResolveRelativePath(string m3uPath, string relativePath)
        {
            if (Path.IsPathRooted(relativePath))
                return relativePath;

            var m3uDir = Path.GetDirectoryName(m3uPath) ?? string.Empty;
            return Path.GetFullPath(Path.Combine(m3uDir, relativePath));
        }

        private class M3UEntry
        {
            public List<string> TagLines { get; set; } = new();
            public string FilePath { get; set; } = string.Empty;
            public string Title { get; set; } = string.Empty;
        }

        private class ResolvedEntry
        {
            public M3UEntry Entry { get; set; } = new();
            public bool IsWatched { get; set; }
            public DateTimeOffset ReleaseDate { get; set; }
        }
    }
}
