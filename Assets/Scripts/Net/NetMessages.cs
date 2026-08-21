using System;
using BattleOfAgents.Core;
using UnityEngine;

namespace BattleOfAgents.Net
{
    /// <summary>Wire format. Deliberately plain JSON over the LAN: readable in a
    /// packet capture, trivial to version, and cheap enough at lobby frequencies.
    /// Gameplay snapshots use the binary path in <see cref="SnapshotWriter"/>.</summary>
    public enum MsgType
    {
        Hello = 0,        // client -> host, on connect
        Welcome = 1,      // host -> client, assigns slot
        RoomState = 2,    // host -> all, full lobby state
        SetReady = 3,     // client -> host
        SetTeam = 4,      // client -> host
        SetAgent = 5,     // client -> host
        Chat = 6,         // both ways
        StartMatch = 7,   // host -> all
        Leave = 8,        // client -> host
        Kick = 9,         // host -> client
        Ping = 10,
        Pong = 11
    }

    [Serializable]
    public class NetEnvelope
    {
        public string proto = GameConfig.ProtocolId;
        public int type;
        public string payload;

        public static string Pack<T>(MsgType type, T payload)
        {
            var env = new NetEnvelope
            {
                type = (int)type,
                payload = payload == null ? string.Empty : JsonUtility.ToJson(payload)
            };
            return JsonUtility.ToJson(env);
        }

        public static NetEnvelope Unpack(string json)
        {
            try { return JsonUtility.FromJson<NetEnvelope>(json); }
            catch (Exception e) { Debug.LogWarning("[Net] bad envelope: " + e.Message); return null; }
        }

        public T Read<T>() where T : new()
        {
            if (string.IsNullOrEmpty(payload)) return new T();
            try { return JsonUtility.FromJson<T>(payload); }
            catch (Exception e) { Debug.LogWarning("[Net] bad payload: " + e.Message); return new T(); }
        }
    }

    [Serializable] public class HelloMsg   { public string playerId; public string name; public string agentId; public string proto = GameConfig.ProtocolId; }
    [Serializable] public class WelcomeMsg { public int slot; public bool accepted = true; public string reason; }
    [Serializable] public class ReadyMsg   { public bool ready; }
    [Serializable] public class TeamMsg    { public int team; }
    [Serializable] public class AgentMsg   { public string agentId; }
    [Serializable] public class ChatMsg    { public string from; public string text; }
    [Serializable] public class LeaveMsg   { public string playerId; }
    [Serializable] public class StartMsg   { public string mapName; public int mode; public int seed; }

    [Serializable]
    public class RoomStateMsg
    {
        public string roomName;
        public string hostName;
        public int mode;
        public string mapName;
        public int maxPlayers;
        public PlayerEntry[] players = new PlayerEntry[0];
    }

    [Serializable]
    public class PlayerEntry
    {
        public string playerId;
        public string name;
        public string agentId;
        public int team;
        public bool ready;
        public bool isHost;
        public int pingMs;
    }

    /// <summary>UDP beacon body the host broadcasts once a second.</summary>
    [Serializable]
    public class BeaconMsg
    {
        public string proto = GameConfig.ProtocolId;
        public string roomId;
        public string roomName;
        public string hostName;
        public int port = GameConfig.GamePort;
        public int players;
        public int maxPlayers = GameConfig.MaxPlayers;
        public int mode;
        public string map;
        public bool locked;
    }
}
