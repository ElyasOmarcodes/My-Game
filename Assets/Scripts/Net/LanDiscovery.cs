using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using BattleOfAgents.Core;
using UnityEngine;

namespace BattleOfAgents.Net
{
    /// <summary>Zero-configuration room discovery on the local Wi-Fi.
    /// The host broadcasts a small JSON beacon on UDP <see cref="GameConfig.DiscoveryPort"/>
    /// once a second; clients listen on the same port and keep a live room list.
    /// No server, no internet, no account — just the router everyone is joined to.</summary>
    public class LanDiscovery : MonoBehaviour
    {
        public event Action<List<RoomInfo>> RoomsChanged;

        readonly Dictionary<string, RoomInfo> _rooms = new Dictionary<string, RoomInfo>();
        public IEnumerable<RoomInfo> Rooms { get { return _rooms.Values; } }

        UdpClient _broadcaster;
        UdpClient _listener;
        Thread _listenThread;
        volatile bool _running;

        BeaconMsg _beacon;
        float _nextBeaconAt;

        public bool IsAdvertising { get; private set; }
        public bool IsScanning { get; private set; }

        // --- host side --------------------------------------------------------

        public void StartAdvertising(BeaconMsg beacon)
        {
            _beacon = beacon;
            try
            {
                if (_broadcaster == null)
                {
                    _broadcaster = new UdpClient();
                    _broadcaster.EnableBroadcast = true;
                }
                IsAdvertising = true;
                _nextBeaconAt = 0f;
                Debug.Log("[LAN] advertising room '" + beacon.roomName + "' on udp/" + GameConfig.DiscoveryPort);
            }
            catch (Exception e)
            {
                Debug.LogError("[LAN] cannot advertise: " + e.Message);
                IsAdvertising = false;
            }
        }

        public void UpdateBeacon(int playerCount)
        {
            if (_beacon != null) _beacon.players = playerCount;
        }

        public void StopAdvertising()
        {
            IsAdvertising = false;
            if (_broadcaster != null) { _broadcaster.Close(); _broadcaster = null; }
        }

        // --- client side ------------------------------------------------------

        public void StartScanning()
        {
            if (IsScanning) return;
            _rooms.Clear();
            _running = true;
            IsScanning = true;

            try
            {
                _listener = new UdpClient();
                _listener.Client.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.ReuseAddress, true);
                _listener.Client.Bind(new IPEndPoint(IPAddress.Any, GameConfig.DiscoveryPort));
                _listener.EnableBroadcast = true;

                _listenThread = new Thread(ListenLoop) { IsBackground = true, Name = "BOA-LanScan" };
                _listenThread.Start();
                Debug.Log("[LAN] scanning udp/" + GameConfig.DiscoveryPort);
            }
            catch (Exception e)
            {
                Debug.LogError("[LAN] cannot scan: " + e.Message);
                IsScanning = false;
            }
        }

        public void StopScanning()
        {
            IsScanning = false;
            _running = false;
            if (_listener != null) { _listener.Close(); _listener = null; }
            _listenThread = null;
        }

        void ListenLoop()
        {
            var any = new IPEndPoint(IPAddress.Any, 0);
            while (_running)
            {
                try
                {
                    var data = _listener.Receive(ref any);
                    var json = Encoding.UTF8.GetString(data);
                    var senderIp = any.Address.ToString();
                    MainThreadDispatcher.Enqueue(() => OnBeacon(json, senderIp));
                }
                catch (SocketException) { /* closed while blocking — expected on stop */ }
                catch (ObjectDisposedException) { return; }
                catch (Exception e)
                {
                    Debug.LogWarning("[LAN] listen error: " + e.Message);
                }
            }
        }

        void OnBeacon(string json, string senderIp)
        {
            BeaconMsg b;
            try { b = JsonUtility.FromJson<BeaconMsg>(json); }
            catch { return; }
            if (b == null || b.proto != GameConfig.ProtocolId) return;

            RoomInfo room;
            if (!_rooms.TryGetValue(b.roomId, out room))
            {
                room = new RoomInfo { RoomId = b.roomId };
                _rooms[b.roomId] = room;
            }

            room.RoomName    = b.roomName;
            room.HostName    = b.hostName;
            room.HostAddress = senderIp;
            room.Port        = b.port;
            room.PlayerCount = b.players;
            room.MaxPlayers  = b.maxPlayers;
            room.Mode        = (MatchMode)b.mode;
            room.MapName     = b.map;
            room.HasPassword = b.locked;
            room.LastSeen    = Time.realtimeSinceStartup;

            RaiseChanged();
        }

        void Update()
        {
            // host: emit the beacon on a fixed cadence
            if (IsAdvertising && _broadcaster != null && Time.realtimeSinceStartup >= _nextBeaconAt)
            {
                _nextBeaconAt = Time.realtimeSinceStartup + GameConfig.BeaconInterval;
                try
                {
                    var bytes = Encoding.UTF8.GetBytes(JsonUtility.ToJson(_beacon));
                    var target = new IPEndPoint(LanUtility.BroadcastAddress(), GameConfig.DiscoveryPort);
                    _broadcaster.Send(bytes, bytes.Length, target);
                }
                catch (Exception e)
                {
                    Debug.LogWarning("[LAN] beacon send failed: " + e.Message);
                }
            }

            // client: expire rooms whose host went quiet
            if (IsScanning && _rooms.Count > 0)
            {
                List<string> dead = null;
                foreach (var kv in _rooms)
                {
                    if (Time.realtimeSinceStartup - kv.Value.LastSeen <= GameConfig.BeaconTimeout) continue;
                    (dead ?? (dead = new List<string>())).Add(kv.Key);
                }
                if (dead != null)
                {
                    for (int i = 0; i < dead.Count; i++) _rooms.Remove(dead[i]);
                    RaiseChanged();
                }
            }
        }

        void RaiseChanged()
        {
            if (RoomsChanged == null) return;
            RoomsChanged(new List<RoomInfo>(_rooms.Values));
        }

        void OnDestroy()
        {
            StopAdvertising();
            StopScanning();
        }
    }
}
