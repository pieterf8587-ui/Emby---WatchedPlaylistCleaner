using MediaBrowser.Controller.Library;
using MediaBrowser.Controller.Playlists;
using MediaBrowser.Model.Logging;
using MediaBrowser.Model.Querying;
using MediaBrowser.Model.Tasks;
using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace WatchedPlaylistCleaner
{
    /// <summary>
    /// A scheduled task that appears in Emby's "Scheduled Tasks" dashboard page.
    /// You can run it manually at any time, or schedule it to run automatically
    /// (e.g., nightly) to catch items that were watched before the plugin was installed.
    /// </summary>
    public class CleanupTask : IScheduledTask
    {
        // These strings appear in the Emby dashboard under Scheduled Tasks
        public string Name => "Clean Watched Items from Playlists";
        public string Description => "Moves watched movies and TV episodes to the bottom of your playlists, keeping unwatched items at the top.";
        public string Category => "Watched Playlist Cleaner";
        public string Key => "WatchedPlaylistCleanerFullScan";

        private readonly PlaylistCleaner _cleaner;

        public CleanupTask(
            ILibraryManager libraryManager,
            IPlaylistManager playlistManager,
            IUserManager userManager,
            IUserDataManager userDataManager,
            ILibraryMonitor libraryMonitor,
            MediaBrowser.Model.IO.IFileSystem fileSystem,
            ILogManager logManager)
        {
            _cleaner = new PlaylistCleaner(libraryManager, playlistManager, userManager, userDataManager, libraryMonitor, fileSystem, logManager);
        }

        /// <summary>
        /// The main work of the task. Emby calls this when the task runs.
        /// </summary>
        public Task Execute(CancellationToken cancellationToken, IProgress<double> progress)
        {
            return _cleaner.CleanAllPlaylistsForAllUsers(progress, cancellationToken);
        }

        /// <summary>
        /// Default schedule: runs once per day at 3:00 AM.
        /// Users can change this in the Emby dashboard.
        /// </summary>
        public IEnumerable<TaskTriggerInfo> GetDefaultTriggers()
        {
            return new[]
            {
                new TaskTriggerInfo
                {
                    Type = TaskTriggerInfo.TriggerDaily,
                    TimeOfDayTicks = TimeSpan.FromHours(3).Ticks   // 3:00 AM
                }
            };
        }
    }
}
