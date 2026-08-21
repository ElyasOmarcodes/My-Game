using System;
using BattleOfAgents.Gameplay;
using BattleOfAgents.Net;
using BattleOfAgents.Visual;
using UnityEngine;

namespace BattleOfAgents.Core
{
    /// <summary>Entry point. Runs before the first scene loads so the game needs
    /// no authored scene content at all — the boot scene can stay empty, which
    /// keeps the APK small and the repo free of binary scene files.</summary>
    public static class GameBootstrap
    {
        public static SessionState Session { get; private set; }

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
        static void Boot()
        {
            Application.targetFrameRate = 60;
            Screen.sleepTimeout = SleepTimeout.NeverSleep;
            QualitySettings.vSyncCount = 0;

            Session = new SessionState();
            Session.Local.PlayerId = Guid.NewGuid().ToString("N").Substring(0, 12);
            Session.Local.DisplayName = LoadOrCreateName();

            var host = new GameObject("[BattleOfAgents]");
            UnityEngine.Object.DontDestroyOnLoad(host);

            host.AddComponent<CinematicRig>();
            host.AddComponent<LanDiscovery>();
            host.AddComponent<LobbyService>();
            host.AddComponent<MatchController>();

            var router = host.AddComponent<AppRouter>();
            router.Boot(Session);

            Debug.Log("[BOA] booted v" + GameConfig.GameVersion +
                      " as " + Session.Local.DisplayName);
        }

        static string LoadOrCreateName()
        {
            const string key = "boa.playername";
            var stored = PlayerPrefs.GetString(key, string.Empty);
            if (!string.IsNullOrEmpty(stored)) return stored;

            var generated = "Agent-" + UnityEngine.Random.Range(100, 999);
            PlayerPrefs.SetString(key, generated);
            PlayerPrefs.Save();
            return generated;
        }
    }
}
