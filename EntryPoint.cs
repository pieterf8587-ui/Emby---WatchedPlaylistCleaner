using MediaBrowser.Controller.Entities;
using MediaBrowser.Controller.Library;
using MediaBrowser.Controller.Plugins;
using MediaBrowser.Controller.Playlists;
using MediaBrowser.Model.Entities;
using MediaBrowser.Model.Logging;
using System;
using System.Threading;
using System.Threading.Tasks;

namespace WatchedPlaylistCleaner
{
    public class EntryPoint : IServerEntryPoint
    {
        private readonly IUserDataManager _userDataManager;
        private readonly ILibraryManager _libraryManager;
        private readonly PlaylistCleaner _cleaner;
        private readonly ILogger _logger;

        // Debounce fields — prevents multiple rapid events from triggering
        // simultaneous runs when adding several items to a playlist at once
        private CancellationTokenSource? _debounceCts;
        private readonly object _debounceLock = new object();
        private const int DebounceMilliseconds = 10000; // Wait 10 seconds after last event

        public EntryPoint(
            IUserDataManager userDataManager,
            ILibraryManager libraryManager,
            IPlaylistManager playlistManager,
            IUserManager userManager,
            ILibraryMonitor libraryMonitor,
            MediaBrowser.Model.IO.IFileSystem fileSystem,
            ILogManager logManager)
        {
            _userDataManager = userDataManager;
            _libraryManager = libraryManager;
            _logger = logManager.GetLogger(Plugin.Instance.Name);

            _cleaner = new PlaylistCleaner(libraryManager, playlistManager, userManager, userDataManager, libraryMonitor, fileSystem, logManager);
        }

        public void Run()
        {
            _userDataManager.UserDataSaved += OnUserDataSaved;
            _libraryManager.ItemAdded += OnLibraryItemChanged;
            _libraryManager.ItemUpdated += OnLibraryItemChanged;
            _logger.Info("[WatchedPlaylistCleaner] Plugin started — subscribed to UserDataSaved, ItemAdded and ItemUpdated events.");
        }

        /// <summary>
        /// Fires when a playlist item is added or updated.
        /// Uses a debounce so that adding multiple items rapidly only triggers one resort.
        /// </summary>
        private void OnLibraryItemChanged(object? sender, ItemChangeEventArgs e)
        {
            if (e.Item is not Playlist)
                return;

            _logger.Info($"[WatchedPlaylistCleaner] Playlist changed: {e.Item.Name} — scheduling debounced resort");

            lock (_debounceLock)
            {
                // Cancel any previously scheduled run
                _debounceCts?.Cancel();
                _debounceCts?.Dispose();
                _debounceCts = new CancellationTokenSource();
                var token = _debounceCts.Token;

                // Schedule a new run after the debounce delay
                Task.Delay(DebounceMilliseconds, token).ContinueWith(t =>
                {
                    if (!t.IsCanceled)
                    {
                        _logger.Info("[WatchedPlaylistCleaner] Debounce complete — running resort for all users");
                        _ = _cleaner.CleanAllPlaylistsForAllUsers(new Progress<double>(), CancellationToken.None);
                    }
                }, token);
            }
        }

        private void OnUserDataSaved(object? sender, UserDataSaveEventArgs e)
        {
            var itemName = e.Item?.Name ?? "unknown";
            var reason = e.SaveReason.ToString();
            var played = e.UserData?.Played.ToString() ?? "null";
            var userName = e.User?.Name ?? "unknown";

            _logger.Info($"[WatchedPlaylistCleaner] UserDataSaved fired — Item: '{itemName}' | Reason: {reason} | Played: {played} | User: {userName}");

            try
            {
                var debugLine = $"{DateTime.Now:yyyy-MM-dd HH:mm:ss} UserDataSaved — Item: '{itemName}' | Reason: {reason} | Played: {played} | User: {userName}{Environment.NewLine}";
                System.IO.File.AppendAllText(
                    System.IO.Path.Combine(
                        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                        "Emby-Server", "logs", "WatchedPlaylistCleaner_debug.txt"),
                    debugLine);
            }
            catch { }

            if (e.SaveReason != UserDataSaveReason.TogglePlayed &&
                e.SaveReason != UserDataSaveReason.PlaybackFinished)
                return;

            if (e.SaveReason == UserDataSaveReason.PlaybackFinished && !e.UserData.Played)
                return;

            var item = e.Item;
            if (item == null)
                return;

            var userId = e.User.Id;

            _logger.Info($"[WatchedPlaylistCleaner] Triggering resort for '{item.Name}'");

            _ = _cleaner.RemoveWatchedItemFromAllPlaylists(item, userId, CancellationToken.None);
        }

        public void Dispose()
        {
            _userDataManager.UserDataSaved -= OnUserDataSaved;
            _libraryManager.ItemAdded -= OnLibraryItemChanged;
            _libraryManager.ItemUpdated -= OnLibraryItemChanged;

            lock (_debounceLock)
            {
                _debounceCts?.Cancel();
                _debounceCts?.Dispose();
            }
        }
    }
}
