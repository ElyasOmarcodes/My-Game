using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using BattleOfAgents.Core;
using UnityEngine;

namespace BattleOfAgents.Net
{
    /// <summary>The lobby control channel: a newline-delimited JSON protocol over TCP.
    /// The host is authoritative — it owns the roster and re-broadcasts the full room
    /// state after every change, so clients never have to merge partial updates.</summary>
    public class LobbyService : MonoBehaviour
    {
        public static LobbyService Instance { get; private set; }

        public event Action RoomStateChanged;
        public event Action<string, string> ChatReceived;          // from, text
        public event Action<string> Disconnected;                  // reason
        public event Action<StartMsg> MatchStarting;

        public bool IsHost { get; private set; }
        public bool IsConnected { get; private set; }
        public RoomStateMsg State { get; private set; }

        LanDiscovery _discovery;

        // host state
        TcpListener _listener;
        Thread _acceptThread;
        readonly List<Connection> _clients = new List<Connection>();
        string _roomId;

        // client state
        Connection _server;

        volatile bool _running;

        class Connection
        {
            public TcpClient Tcp;
            public StreamWriter Writer;
            public Thread Reader;
            public string PlayerId;
            public string Name;
        }

        void Awake()
        {
            Instance = this;
            _discovery = gameObject.GetComponent<LanDiscovery>();
            if (_discovery == null) _discovery = gameObject.AddComponent<LanDiscovery>();
            State = new RoomStateMsg();
        }

        public LanDiscovery Discovery { get { return _discovery; } }

        // =====================================================================
        //  HOST
        // =====================================================================

        public bool HostRoom(string roomName, MatchMode mode, string map, int maxPlayers)
        {
            Shutdown();
            var me = GameBootstrap.Session.Local;
            _roomId = Guid.NewGuid().ToString("N").Substring(0, 8);

            State = new RoomStateMsg
            {
                roomName = roomName,
                hostName = me.DisplayName,
                mode = (int)mode,
                mapName = map,
                maxPlayers = Mathf.Clamp(maxPlayers, GameConfig.MinPlayers, GameConfig.MaxPlayers),
                players = new[]
                {
                    new PlayerEntry
                    {
                        playerId = me.PlayerId, name = me.DisplayName, agentId = me.AgentId,
                        team = (int)Team.Alpha, ready = true, isHost = true, pingMs = 0
                    }
                }
            };

            try
            {
                _listener = new TcpListener(IPAddress.Any, GameConfig.GamePort);
                _listener.Start();
                _running = true;
                _acceptThread = new Thread(AcceptLoop) { IsBackground = true, Name = "BOA-Accept" };
                _acceptThread.Start();
            }
            catch (Exception e)
            {
                Debug.LogError("[Lobby] cannot host on tcp/" + GameConfig.GamePort + ": " + e.Message);
                return false;
            }

            IsHost = true;
            IsConnected = true;
            me.IsHost = true;
            me.Team = Team.Alpha;
            me.IsReady = true;

            _discovery.StartAdvertising(new BeaconMsg
            {
                roomId = _roomId,
                roomName = roomName,
                hostName = me.DisplayName,
                port = GameConfig.GamePort,
                players = 1,
                maxPlayers = State.maxPlayers,
                mode = (int)mode,
                map = map
            });

            Debug.Log("[Lobby] hosting '" + roomName + "' on " + LanUtility.LocalIPv4() + ":" + GameConfig.GamePort);
            Raise(RoomStateChanged);
            return true;
        }

        void AcceptLoop()
        {
            while (_running)
            {
                try
                {
                    var tcp = _listener.AcceptTcpClient();
                    tcp.NoDelay = true;
                    var conn = new Connection
                    {
                        Tcp = tcp,
                        Writer = new StreamWriter(tcp.GetStream(), Encoding.UTF8) { AutoFlush = true }
                    };
                    conn.Reader = new Thread(() => ReadLoop(conn, true)) { IsBackground = true };
                    lock (_clients) _clients.Add(conn);
                    conn.Reader.Start();
                }
                catch (SocketException) { return; }
                catch (ObjectDisposedException) { return; }
                catch (Exception e) { Debug.LogWarning("[Lobby] accept: " + e.Message); }
            }
        }

        // =====================================================================
        //  CLIENT
        // =====================================================================

        public void JoinRoom(RoomInfo room)
        {
            Shutdown();
            var me = GameBootstrap.Session.Local;
            me.IsHost = false;
            IsHost = false;

            var thread = new Thread(() =>
            {
                try
                {
                    var tcp = new TcpClient();
                    tcp.Connect(room.HostAddress, room.Port);
                    tcp.NoDelay = true;

                    var conn = new Connection
                    {
                        Tcp = tcp,
                        Writer = new StreamWriter(tcp.GetStream(), Encoding.UTF8) { AutoFlush = true }
                    };
                    _server = conn;
                    _running = true;

                    Send(conn, NetEnvelope.Pack(MsgType.Hello, new HelloMsg
                    {
                        playerId = me.PlayerId, name = me.DisplayName, agentId = me.AgentId
                    }));

                    MainThreadDispatcher.Enqueue(() =>
                    {
                        IsConnected = true;
                        GameBootstrap.Session.CurrentRoom = room;
                    });

                    ReadLoop(conn, false);
                }
                catch (Exception e)
                {
                    var reason = e.Message;
                    MainThreadDispatcher.Enqueue(() =>
                    {
                        IsConnected = false;
                        if (Disconnected != null) Disconnected("could not reach host — " + reason);
                    });
                }
            }) { IsBackground = true, Name = "BOA-Join" };
            thread.Start();
        }

        // =====================================================================
        //  SHARED
        // =====================================================================

        void ReadLoop(Connection conn, bool asHost)
        {
            try
            {
                using (var reader = new StreamReader(conn.Tcp.GetStream(), Encoding.UTF8))
                {
                    while (_running)
                    {
                        var line = reader.ReadLine();
                        if (line == null) break;
                        var captured = line;
                        MainThreadDispatcher.Enqueue(() => Handle(captured, conn, asHost));
                    }
                }
            }
            catch (Exception) { /* socket torn down */ }

            MainThreadDispatcher.Enqueue(() =>
            {
                if (asHost) DropClient(conn, "connection lost");
                else
                {
                    IsConnected = false;
                    if (Disconnected != null) Disconnected("host closed the room");
                }
            });
        }

        void Handle(string json, Connection from, bool asHost)
        {
            var env = NetEnvelope.Unpack(json);
            if (env == null || env.proto != GameConfig.ProtocolId) return;

            switch ((MsgType)env.type)
            {
                case MsgType.Hello:
                {
                    if (!asHost) return;
                    var hello = env.Read<HelloMsg>();
                    if (CountPlayers() >= State.maxPlayers)
                    {
                        Send(from, NetEnvelope.Pack(MsgType.Welcome,
                            new WelcomeMsg { accepted = false, reason = "room is full" }));
                        return;
                    }
                    from.PlayerId = hello.playerId;
                    from.Name = hello.name;
                    AddPlayer(hello);
                    Send(from, NetEnvelope.Pack(MsgType.Welcome, new WelcomeMsg { slot = CountPlayers() - 1 }));
                    BroadcastState();
                    break;
                }
                case MsgType.Welcome:
                {
                    var w = env.Read<WelcomeMsg>();
                    if (!w.accepted)
                    {
                        IsConnected = false;
                        if (Disconnected != null) Disconnected(w.reason);
                    }
                    break;
                }
                case MsgType.RoomState:
                    State = env.Read<RoomStateMsg>();
                    SyncSessionFromState();
                    Raise(RoomStateChanged);
                    break;

                case MsgType.SetReady:
                {
                    if (!asHost) return;
                    var r = env.Read<ReadyMsg>();
                    var p = FindPlayer(from.PlayerId);
                    if (p != null) { p.ready = r.ready; BroadcastState(); }
                    break;
                }
                case MsgType.SetTeam:
                {
                    if (!asHost) return;
                    var t = env.Read<TeamMsg>();
                    var p = FindPlayer(from.PlayerId);
                    if (p != null) { p.team = t.team; BroadcastState(); }
                    break;
                }
                case MsgType.SetAgent:
                {
                    if (!asHost) return;
                    var a = env.Read<AgentMsg>();
                    var p = FindPlayer(from.PlayerId);
                    if (p != null) { p.agentId = a.agentId; BroadcastState(); }
                    break;
                }
                case MsgType.Chat:
                {
                    var c = env.Read<ChatMsg>();
                    if (asHost) BroadcastRaw(NetEnvelope.Pack(MsgType.Chat, c));
                    if (ChatReceived != null) ChatReceived(c.from, c.text);
                    break;
                }
                case MsgType.StartMatch:
                    if (MatchStarting != null) MatchStarting(env.Read<StartMsg>());
                    break;

                case MsgType.Leave:
                    if (asHost) DropClient(from, "left the room");
                    break;
            }
        }

        // --- host roster helpers ---------------------------------------------

        int CountPlayers() { return State.players == null ? 0 : State.players.Length; }

        PlayerEntry FindPlayer(string playerId)
        {
            if (State.players == null || playerId == null) return null;
            for (int i = 0; i < State.players.Length; i++)
                if (State.players[i].playerId == playerId) return State.players[i];
            return null;
        }

        void AddPlayer(HelloMsg hello)
        {
            var list = new List<PlayerEntry>(State.players ?? new PlayerEntry[0]);
            if (list.Exists(p => p.playerId == hello.playerId)) return;

            int alpha = list.FindAll(p => p.team == (int)Team.Alpha).Count;
            int bravo = list.FindAll(p => p.team == (int)Team.Bravo).Count;

            list.Add(new PlayerEntry
            {
                playerId = hello.playerId,
                name = hello.name,
                agentId = hello.agentId,
                team = (int)(alpha <= bravo ? Team.Alpha : Team.Bravo),   // auto-balance
                ready = false,
                isHost = false
            });
            State.players = list.ToArray();
            _discovery.UpdateBeacon(list.Count);
        }

        void DropClient(Connection conn, string reason)
        {
            lock (_clients) _clients.Remove(conn);
            try { conn.Tcp.Close(); } catch { }

            if (!IsHost || State.players == null) return;

            var list = new List<PlayerEntry>(State.players);
            list.RemoveAll(p => p.playerId == conn.PlayerId);
            State.players = list.ToArray();
            _discovery.UpdateBeacon(list.Count);
            BroadcastState();
            Debug.Log("[Lobby] " + (conn.Name ?? "client") + " " + reason);
        }

        void SyncSessionFromState()
        {
            var session = GameBootstrap.Session;
            session.RoomPlayers.Clear();
            if (State.players == null) return;

            for (int i = 0; i < State.players.Length; i++)
            {
                var e = State.players[i];
                session.RoomPlayers.Add(new PlayerProfile
                {
                    PlayerId = e.playerId, DisplayName = e.name, AgentId = e.agentId,
                    Team = (Team)e.team, IsReady = e.ready, IsHost = e.isHost
                });
                if (e.playerId == session.Local.PlayerId)
                {
                    session.Local.Team = (Team)e.team;
                    session.Local.IsReady = e.ready;
                }
            }
        }

        // --- public API used by the UI ----------------------------------------

        public void SetReady(bool ready)
        {
            if (IsHost)
            {
                var me = FindPlayer(GameBootstrap.Session.Local.PlayerId);
                if (me != null) me.ready = ready;
                BroadcastState();
            }
            else Send(_server, NetEnvelope.Pack(MsgType.SetReady, new ReadyMsg { ready = ready }));
            GameBootstrap.Session.Local.IsReady = ready;
        }

        public void SetTeam(Team team)
        {
            if (IsHost)
            {
                var me = FindPlayer(GameBootstrap.Session.Local.PlayerId);
                if (me != null) me.team = (int)team;
                BroadcastState();
            }
            else Send(_server, NetEnvelope.Pack(MsgType.SetTeam, new TeamMsg { team = (int)team }));
        }

        public void SetAgent(string agentId)
        {
            GameBootstrap.Session.Local.AgentId = agentId;
            if (!IsConnected) return;

            if (IsHost)
            {
                var me = FindPlayer(GameBootstrap.Session.Local.PlayerId);
                if (me != null) me.agentId = agentId;
                BroadcastState();
            }
            else Send(_server, NetEnvelope.Pack(MsgType.SetAgent, new AgentMsg { agentId = agentId }));
        }

        public void SendChat(string text)
        {
            if (string.IsNullOrEmpty(text)) return;
            var msg = new ChatMsg { from = GameBootstrap.Session.Local.DisplayName, text = text };
            if (IsHost)
            {
                BroadcastRaw(NetEnvelope.Pack(MsgType.Chat, msg));
                if (ChatReceived != null) ChatReceived(msg.from, msg.text);
            }
            else Send(_server, NetEnvelope.Pack(MsgType.Chat, msg));
        }

        public bool CanStart()
        {
            if (!IsHost || State.players == null) return false;
            if (State.players.Length < GameConfig.MinPlayers) return false;
            for (int i = 0; i < State.players.Length; i++)
                if (!State.players[i].ready) return false;
            return true;
        }

        public void StartMatch()
        {
            if (!IsHost) return;
            var start = new StartMsg
            {
                mapName = State.mapName,
                mode = State.mode,
                seed = UnityEngine.Random.Range(1, int.MaxValue)
            };
            BroadcastRaw(NetEnvelope.Pack(MsgType.StartMatch, start));
            if (MatchStarting != null) MatchStarting(start);
        }

        public void Leave()
        {
            if (!IsHost && _server != null)
                Send(_server, NetEnvelope.Pack(MsgType.Leave,
                    new LeaveMsg { playerId = GameBootstrap.Session.Local.PlayerId }));
            Shutdown();
        }

        // --- transport plumbing -----------------------------------------------

        void BroadcastState()
        {
            SyncSessionFromState();
            BroadcastRaw(NetEnvelope.Pack(MsgType.RoomState, State));
            Raise(RoomStateChanged);
        }

        void BroadcastRaw(string json)
        {
            lock (_clients)
                for (int i = _clients.Count - 1; i >= 0; i--)
                    Send(_clients[i], json);
        }

        static void Send(Connection conn, string json)
        {
            if (conn == null || conn.Writer == null) return;
            try { conn.Writer.WriteLine(json); }
            catch (Exception e) { Debug.LogWarning("[Lobby] send failed: " + e.Message); }
        }

        void Raise(Action evt) { if (evt != null) evt(); }

        public void Shutdown()
        {
            _running = false;
            IsConnected = false;

            _discovery.StopAdvertising();

            if (_listener != null) { try { _listener.Stop(); } catch { } _listener = null; }

            lock (_clients)
            {
                for (int i = 0; i < _clients.Count; i++)
                    try { _clients[i].Tcp.Close(); } catch { }
                _clients.Clear();
            }

            if (_server != null) { try { _server.Tcp.Close(); } catch { } _server = null; }

            IsHost = false;
            GameBootstrap.Session.Local.IsHost = false;
            GameBootstrap.Session.RoomPlayers.Clear();
        }

        void OnDestroy() { Shutdown(); }
    }
}
