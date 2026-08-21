using BattleOfAgents.Core;
using BattleOfAgents.Net;
using BattleOfAgents.UI;
using UnityEngine;

namespace BattleOfAgents.Gameplay
{
    /// <summary>Owns a running match: builds the arena from the host's seed, spawns the
    /// local player and the remote bodies, starts replication, and tears it all down
    /// when the match ends.</summary>
    public class MatchController : MonoBehaviour
    {
        public static MatchController Instance { get; private set; }

        ArenaBuilder _arena;
        PlayerController _local;
        MatchState _state;

        void Awake()
        {
            Instance = this;
            _state = gameObject.GetComponent<MatchState>();
            if (_state == null) _state = gameObject.AddComponent<MatchState>();
            gameObject.AddComponent<TouchInput>();
        }

        void Start()
        {
            LobbyService.Instance.MatchStarting += OnMatchStarting;
        }

        void OnDestroy()
        {
            if (LobbyService.Instance != null)
                LobbyService.Instance.MatchStarting -= OnMatchStarting;
        }

        void OnMatchStarting(StartMsg msg)
        {
            Begin(msg.mapName, (MatchMode)msg.mode, msg.seed);
        }

        public void Begin(string mapName, MatchMode mode, int seed)
        {
            Teardown();

            var session = GameBootstrap.Session;
            var roster = session.RoomPlayers.Count > 0
                ? session.RoomPlayers.ToArray()
                : new[] { session.Local };

            var arenaGo = new GameObject("Arena");
            _arena = arenaGo.AddComponent<ArenaBuilder>();
            _arena.Build(seed, mapName);

            var index = System.Array.FindIndex(roster, p => p.PlayerId == session.Local.PlayerId);
            var spawn = _arena.PickSpawn(session.Local.Team, Mathf.Max(0, index));

            _local = PlayerController.Spawn(AgentCatalog.Get(session.Local.AgentId),
                session.Local.Team, spawn, session.Local.DisplayName);

            _state.BeginMatch(mode, mapName, roster);

            var sync = gameObject.GetComponent<GameSync>();
            if (sync == null) sync = gameObject.AddComponent<GameSync>();

            var hostAddress = session.CurrentRoom != null
                ? session.CurrentRoom.HostAddress
                : LanUtility.LocalIPv4();

            sync.Begin(LobbyService.Instance.IsHost, hostAddress, _local, roster, arenaGo.transform);

            AppRouter.Instance.Go(ScreenId.Hud, false);
            Debug.Log("[Match] " + mapName + " · " + mode + " · seed " + seed +
                      " · " + roster.Length + " agents");
        }

        public void Teardown()
        {
            var sync = gameObject.GetComponent<GameSync>();
            if (sync != null) sync.Stop();

            if (_local != null) Destroy(_local.gameObject);
            if (_arena != null) Destroy(_arena.gameObject);

            _local = null;
            _arena = null;
            Time.timeScale = 1f;
        }
    }
}
