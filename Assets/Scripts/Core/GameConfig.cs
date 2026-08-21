using System;
using System.Collections.Generic;

namespace BattleOfAgents.Core
{
    /// <summary>Static, build-wide configuration. Kept in one place so the CI build
    /// script and the runtime agree on ports, versions and limits.</summary>
    public static class GameConfig
    {
        public const string GameName      = "BATTLE OF AGENTS";
        public const string GameVersion   = "0.1.0";
        public const string ProtocolId    = "BOA1";      // bumped on wire-format changes

        // --- LAN networking -------------------------------------------------
        public const int DiscoveryPort    = 47777;       // UDP broadcast beacon
        public const int GamePort         = 47778;       // TCP lobby control channel
        public const int SyncPort         = 47779;       // UDP gameplay snapshots (20 Hz)
        public const float BeaconInterval = 1.0f;        // seconds between host beacons
        public const float BeaconTimeout  = 4.0f;        // drop a room after this silence

        // --- Match rules ----------------------------------------------------
        public const int MinPlayers       = 2;
        public const int MaxPlayers       = 8;
        public const int DefaultScoreGoal = 25;
        public const float DefaultMatchSeconds = 300f;
    }

    public enum MatchMode { TeamDeathmatch = 0, FreeForAll = 1, Domination = 2 }
    public enum Team { None = 0, Alpha = 1, Bravo = 2 }

    [Serializable]
    public class RoomInfo
    {
        public string RoomId;
        public string RoomName;
        public string HostName;
        public string HostAddress;
        public int Port = GameConfig.GamePort;
        public int PlayerCount;
        public int MaxPlayers = GameConfig.MaxPlayers;
        public MatchMode Mode = MatchMode.TeamDeathmatch;
        public string MapName = "Kandahar Rooftops";
        public bool HasPassword;
        public float LastSeen;          // Time.realtimeSinceStartup of last beacon
        public int PingMs = -1;
    }

    [Serializable]
    public class PlayerProfile
    {
        public string PlayerId;
        public string DisplayName = "Agent";
        public string AgentId = "vanguard";
        public int Level = 1;
        public int Xp;
        public Team Team = Team.None;
        public bool IsReady;
        public bool IsHost;
    }

    /// <summary>Everything the screens need to know about "right now".
    /// Lives for the whole app lifetime (created by <see cref="GameBootstrap"/>).</summary>
    public class SessionState
    {
        public PlayerProfile Local = new PlayerProfile();
        public RoomInfo CurrentRoom;
        public readonly List<PlayerProfile> RoomPlayers = new List<PlayerProfile>();
        public MatchMode SelectedMode = MatchMode.TeamDeathmatch;
        public string SelectedMap = "Kandahar Rooftops";
        public bool IsHost => Local.IsHost;
    }
}
