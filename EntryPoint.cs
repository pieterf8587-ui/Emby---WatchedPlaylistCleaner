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

        private CancellationTokenSource? _debounceCts;
        private readonly object _debounceLock = new object();
        private const int DebounceMilliseconds = 10000;

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

            // Log version and startup info for easy diagnosis in bug reports
            var version = System.Reflection.Assembly.GetExecutingAssembly().GetName().Version;
            _logger.Info($"[WatchedPlaylistCleaner] v{version} started — subscribed to UserDataSaved, ItemAdded and ItemUpdated events.");
        }

        private void OnLibraryItemChanged(object? sender, ItemChangeEventArgs e)
        {
            if (e.Item is not Playlist)
                return;

            _logger.Info($"[WatchedPlaylistCleaner] Playlist changed: '{e.Item.Name}' — scheduling debounced resort");

            lock (_debounceLock)
            {
                _debounceCts?.Cancel();
                _debounceCts?.Dispose();
                _debounceCts = new CancellationTokenSource();
                var token = _debounceCts.Token;

                Task.Delay(DebounceMilliseconds, token).ContinueWith(t =>
                {
                    if (t.IsCanceled) return;

                    _logger.Info("[WatchedPlaylistCleaner] Debounce complete — running initial resort");
                    _ = _cleaner.CleanAllPlaylistsForAllUsers(new Progress<double>(), CancellationToken.None);

                    Task.Delay(30000).ContinueWith(_ =>
                    {
                        _logger.Info("[WatchedPlaylistCleaner] Running safety net resort");
                        _ = _cleaner.CleanAllPlaylistsForAllUsers(new Progress<double>(), CancellationToken.None);
                    });
                }, token);
            }
        }

        private void OnUserDataSaved(object? sender, UserDataSaveEventArgs e)
        {
            // Log ALL events at Debug level only — avoids flooding the main Emby log
            _logger.Debug($"[WatchedPlaylistCleaner] UserDataSaved — Item: '{e.Item?.Name ?? "unknown"}' | Reason: {e.SaveReason} | Played: {e.UserData?.Played} | User: {e.User?.Name ?? "unknown"}");

            // Only act on watched/unplayed toggles and playback completion
            if (e.SaveReason != UserDataSaveReason.TogglePlayed &&
                e.SaveReason != UserDataSaveReason.PlaybackFinished)
                return;

            if (e.SaveReason == UserDataSaveReason.PlaybackFinished && !e.UserData.Played)
                return;

            var item = e.Item;
            if (item == null)
                return;

            var userId = e.User.Id;
            var userName = e.User?.Name ?? userId.ToString();

            // Log at Info level only when we actually trigger a resort
            _logger.Info($"[WatchedPlaylistCleaner] '{item.Name}' marked {(e.UserData.Played ? "watched" : "unwatched")} by '{userName}' — triggering resort");

            _ = _cleaner.RemoveWatchedItemFromAllPlaylists(item, userId, CancellationToken.None);
        }

        public void Dispose()
        {
            _userDataManager.UserDataSaved -= OnUserDataSaved;
            _libraryManager.ItemAdded -= OnLibraryItemChanged;
            _libraryManager.ItemUpdated -= OnLibraryItemChanged;

            _logger.Info("[WatchedPlaylistCleaner] Plugin disposed — unsubscribed from all events.");

            lock (_debounceLock)
            {
                _debounceCts?.Cancel();
                _debounceCts?.Dispose();
            }
        }
    }
}
