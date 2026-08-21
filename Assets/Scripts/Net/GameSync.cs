using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using BattleOfAgents.Core;
using BattleOfAgents.Gameplay;
using UnityEngine;

namespace BattleOfAgents.Net
{
    /// <summary>The in-match replication channel: UDP on port 47779, 20 Hz.
    ///
    /// Clients push their own transform to the host; the host answers with one
    /// snapshot containing everybody. Movement is client-authoritative (it has to be,
    /// or the game feels rubbery on a phone), while damage and scoring are decided by
    /// the host — so the worst a bad client can do is misplace itself, not invent kills.
    ///
    /// UDP is deliberate: a lost snapshot is replaced by the next one 50 ms later, so
    /// retransmitting it would only add latency.</summary>
    public class GameSync : MonoBehaviour
    {
        public static GameSync Instance { get; private set; }

        const byte MsgClientState = 1;
        const byte MsgSnapshot    = 2;
        const byte MsgHitReport   = 3;
        const byte MsgKill        = 4;

        public const float SendInterval = 0.05f;   // 20 Hz

        UdpClient _socket;
        Thread _receiveThread;
        volatile bool _running;

        IPEndPoint _hostEndpoint;                       // client → host
        readonly Dictionary<int, IPEndPoint> _clients = new Dictionary<int, IPEndPoint>();
        readonly Dictionary<int, RemoteAgent> _agents = new Dictionary<int, RemoteAgent>();
        readonly Dictionary<int, PlayerProfile> _roster = new Dictionary<int, PlayerProfile>();
        readonly Dictionary<int, float> _health = new Dictionary<int, float>();

        readonly SnapshotWriter _writer = new SnapshotWriter();
        float _nextSendAt;
        int _localHash;
        bool _isHost;

        PlayerController _local;

        void Awake() { Instance = this; }

        public void Begin(bool isHost, string hostAddress, PlayerController local,
            IEnumerable<PlayerProfile> roster, Transform agentParent)
        {
            Stop();

            _isHost = isHost;
            _local = local;
            _localHash = SnapshotWriter.HashId(GameBootstrap.Session.Local.PlayerId);

            foreach (var profile in roster)
            {
                var hash = SnapshotWriter.HashId(profile.PlayerId);
                _roster[hash] = profile;
                _health[hash] = AgentCatalog.Get(profile.AgentId).Health;

                if (profile.PlayerId == GameBootstrap.Session.Local.PlayerId) continue;
                _agents[hash] = RemoteAgent.Create(agentParent, profile);
            }

            try
            {
                _socket = new UdpClient();
                _socket.Client.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.ReuseAddress, true);
                _socket.Client.Bind(new IPEndPoint(IPAddress.Any, isHost ? GameConfig.SyncPort : 0));

                if (!isHost)
                    _hostEndpoint = new IPEndPoint(IPAddress.Parse(hostAddress), GameConfig.SyncPort);

                _running = true;
                _receiveThread = new Thread(ReceiveLoop) { IsBackground = true, Name = "BOA-Sync" };
                _receiveThread.Start();
                Debug.Log("[Sync] started as " + (isHost ? "host" : "client"));
            }
            catch (Exception e)
            {
                Debug.LogError("[Sync] cannot open udp/" + GameConfig.SyncPort + ": " + e.Message);
            }
        }

        void ReceiveLoop()
        {
            var sender = new IPEndPoint(IPAddress.Any, 0);
            while (_running)
            {
                try
                {
                    var data = _socket.Receive(ref sender);
                    var from = new IPEndPoint(sender.Address, sender.Port);
                    MainThreadDispatcher.Enqueue(() => Handle(data, from));
                }
                catch (SocketException) { }
                catch (ObjectDisposedException) { return; }
                catch (Exception e) { Debug.LogWarning("[Sync] receive: " + e.Message); }
            }
        }

        void Handle(byte[] data, IPEndPoint from)
        {
            if (data.Length < 1) return;
            var reader = new SnapshotReader(data, data.Length);

            switch (reader.Byte())
            {
                case MsgClientState:
                {
                    if (!_isHost) return;
                    var hash = reader.Int();
                    _clients[hash] = from;                 // learn the endpoint on first packet

                    float x, y, z;
                    reader.Position(out x, out y, out z);
                    var yaw = reader.Angle();

                    RemoteAgent agent;
                    if (_agents.TryGetValue(hash, out agent))
                        agent.ReceiveState(new Vector3(x, y, z), yaw);
                    break;
                }

                case MsgSnapshot:
                {
                    if (_isHost) return;
                    var count = reader.Byte();
                    for (int i = 0; i < count; i++)
                    {
                        var hash = reader.Int();
                        float x, y, z;
                        reader.Position(out x, out y, out z);
                        var yaw = reader.Angle();
                        var health = reader.Byte();

                        if (hash == _localHash)
                        {
                            // The host is authoritative on health, so accept its number.
                            MatchState.Instance.Health = health;
                            continue;
                        }

                        RemoteAgent agent;
                        if (_agents.TryGetValue(hash, out agent))
                        {
                            agent.ReceiveState(new Vector3(x, y, z), yaw);
                            agent.SetAlive(health > 0);
                        }
                    }
                    break;
                }

                case MsgHitReport:
                {
                    if (!_isHost) return;                  // only the host resolves damage
                    var attacker = reader.Int();
                    var victim = reader.Int();
                    var damage = reader.Float();
                    ResolveDamage(attacker, victim, damage);
                    break;
                }

                case MsgKill:
                {
                    var killer = reader.Int();
                    var victim = reader.Int();
                    var killerProfile = Lookup(killer);
                    var victimProfile = Lookup(victim);
                    if (killerProfile != null && victimProfile != null)
                        MatchState.Instance.RegisterKill(killerProfile.PlayerId,
                            victimProfile.PlayerId, "eliminated");
                    break;
                }
            }
        }

        PlayerProfile Lookup(int hash)
        {
            PlayerProfile profile;
            return _roster.TryGetValue(hash, out profile) ? profile : null;
        }

        /// <summary>Host-side damage resolution — the single place a hit counts.</summary>
        void ResolveDamage(int attackerHash, int victimHash, float damage)
        {
            float current;
            if (!_health.TryGetValue(victimHash, out current) || current <= 0f) return;

            current = Mathf.Max(0f, current - damage);
            _health[victimHash] = current;

            if (victimHash == _localHash && _local != null)
                _local.TakeDamage(damage, Lookup(attackerHash) != null
                    ? Lookup(attackerHash).PlayerId : string.Empty);

            if (current > 0f) return;

            var killer = Lookup(attackerHash);
            var victim = Lookup(victimHash);
            if (killer != null && victim != null)
                MatchState.Instance.RegisterKill(killer.PlayerId, victim.PlayerId, "eliminated");

            Broadcast(w =>
            {
                w.Byte(MsgKill);
                w.Int(attackerHash);
                w.Int(victimHash);
            });

            // Respawn the victim on the host's clock so both sides agree.
            var hash = victimHash;
            var maxHealth = victim != null ? AgentCatalog.Get(victim.AgentId).Health : 100f;
            StartCoroutine(RespawnAfter(hash, maxHealth, 4f));
        }

        System.Collections.IEnumerator RespawnAfter(int hash, float health, float delay)
        {
            yield return new WaitForSeconds(delay);
            _health[hash] = health;
        }

        /// <summary>Called by the local weapon whenever its ray lands on someone.</summary>
        public void ReportHit(string victimPlayerId, float damage, Vector3 point)
        {
            var victimHash = SnapshotWriter.HashId(victimPlayerId);

            if (_isHost)
            {
                ResolveDamage(_localHash, victimHash, damage);
                return;
            }

            _writer.Reset();
            _writer.Byte(MsgHitReport);
            _writer.Int(_localHash);
            _writer.Int(victimHash);
            _writer.Float(damage);
            SendTo(_hostEndpoint);
        }

        void Update()
        {
            if (!_running || Time.time < _nextSendAt) return;
            _nextSendAt = Time.time + SendInterval;

            if (_isHost) SendSnapshot();
            else SendLocalState();
        }

        void SendLocalState()
        {
            if (_local == null || _hostEndpoint == null) return;

            _writer.Reset();
            _writer.Byte(MsgClientState);
            _writer.Int(_localHash);
            var p = _local.transform.position;
            _writer.Position(p.x, p.y, p.z);
            _writer.Angle(_local.Yaw);
            SendTo(_hostEndpoint);
        }

        void SendSnapshot()
        {
            if (_clients.Count == 0) return;

            _writer.Reset();
            _writer.Byte(MsgSnapshot);
            _writer.Byte((byte)(_agents.Count + 1));

            // the host's own agent
            _writer.Int(_localHash);
            if (_local != null)
            {
                var p = _local.transform.position;
                _writer.Position(p.x, p.y, p.z);
                _writer.Angle(_local.Yaw);
            }
            else
            {
                _writer.Position(0f, 0f, 0f);
                _writer.Angle(0f);
            }
            _writer.Byte((byte)Mathf.Clamp(Mathf.RoundToInt(MatchState.Instance.Health), 0, 255));

            foreach (var pair in _agents)
            {
                _writer.Int(pair.Key);
                var p = pair.Value.transform.position;
                _writer.Position(p.x, p.y, p.z);
                _writer.Angle(pair.Value.Yaw);

                float health;
                _health.TryGetValue(pair.Key, out health);
                _writer.Byte((byte)Mathf.Clamp(Mathf.RoundToInt(health), 0, 255));
            }

            foreach (var endpoint in _clients.Values) SendTo(endpoint);
        }

        void Broadcast(Action<SnapshotWriter> write)
        {
            _writer.Reset();
            write(_writer);
            foreach (var endpoint in _clients.Values) SendTo(endpoint);
        }

        void SendTo(IPEndPoint endpoint)
        {
            if (_socket == null || endpoint == null) return;
            try { _socket.Send(_writer.Buffer, _writer.Length, endpoint); }
            catch (Exception e) { Debug.LogWarning("[Sync] send: " + e.Message); }
        }

        public void Stop()
        {
            _running = false;
            if (_socket != null) { _socket.Close(); _socket = null; }
            _receiveThread = null;

            foreach (var agent in _agents.Values)
                if (agent != null) Destroy(agent.gameObject);

            _agents.Clear();
            _clients.Clear();
            _roster.Clear();
            _health.Clear();
        }

        void OnDestroy() { Stop(); }
    }
}
