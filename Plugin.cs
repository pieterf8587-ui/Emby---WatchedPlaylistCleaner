using MediaBrowser.Common.Configuration;
using MediaBrowser.Common.Plugins;
using MediaBrowser.Model.Plugins;
using MediaBrowser.Model.Serialization;
using System;
using System.Collections.Generic;

namespace WatchedPlaylistCleaner
{
    public class Plugin : BasePlugin<PluginConfiguration>, IHasWebPages
    {
        public override Guid Id => new Guid("a3f1e2d4-5b6c-7890-abcd-ef1234567890");
        public override string Name => "Watched Playlist Cleaner";
        public override string Description =>
            "Maintains playlists sorted with unwatched items first, watched items last. Each user's sort is independent.";

        public static Plugin Instance { get; private set; } = null!;

        public Plugin(IApplicationPaths appPaths, IXmlSerializer xmlSerializer)
            : base(appPaths, xmlSerializer)
        {
            Instance = this;
        }

        /// <summary>
        /// Registers the configuration page with Emby's dashboard.
        /// This is the correct modern approach — replaces IPluginConfigurationPage.
        /// </summary>
        public IEnumerable<PluginPageInfo> GetPages()
        {
            return new[]
            {
                new PluginPageInfo
                {
                    Name = "WatchedPlaylistCleaner",
                    EmbeddedResourcePath = GetType().Namespace + ".Configuration.configPage.html"
                },
                new PluginPageInfo
                {
                    Name = "WatchedPlaylistCleanerjs",
                    EmbeddedResourcePath = GetType().Namespace + ".Configuration.configPageController.html"
                }
            };
        }
    }
}
