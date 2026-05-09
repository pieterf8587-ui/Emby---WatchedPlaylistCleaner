using MediaBrowser.Common.Plugins;
using MediaBrowser.Model.Plugins;
using System;

namespace WatchedPlaylistCleaner
{
    public class Plugin : BasePlugin
    {
        public override Guid Id => new Guid("a3f1e2d4-5b6c-7890-abcd-ef1234567890");
        public override string Name => "Watched Playlist Cleaner";
        public override string Description =>
            "Maintains an (Unwatched) shadow playlist for each of your playlists, keeping only episodes and movies you haven't seen yet.";

        public static Plugin Instance { get; private set; } = null!;

        public Plugin()
        {
            Instance = this;
        }
    }
}
