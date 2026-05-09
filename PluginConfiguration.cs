using MediaBrowser.Model.Plugins;

namespace WatchedPlaylistCleaner
{
    public class PluginConfiguration : BasePluginConfiguration
    {
        /// <summary>
        /// Newline-separated list of playlist names to manage.
        /// Stored as a single string for reliable XML serialisation.
        /// </summary>
        public string ManagedPlaylists { get; set; } = string.Empty;
    }
}
