using System;
using System.Collections.Generic;
using BattleOfAgents.Core;
using UnityEngine;

namespace BattleOfAgents.Gameplay
{
    [Serializable]
    public class ScoreEntry
    {
        public string PlayerId;
        public string Name;
        public Team Team;
        public string AgentId;
        public int Kills;
        public int Deaths;
        public int Assists;
        public int Score;
        public int PingMs;
    }

    /// <summary>Authoritative-on-the-host view of the running match. The HUD and the
    /// results page both read from here, so there is exactly one scoring model.</summary>
    public class MatchState : MonoBehaviour
    {
        public static MatchState Instance { get; private set; }

        public MatchMode Mode = MatchMode.TeamDeathmatch;
        public string MapName = "Kandahar Rooftops";
        public bool IsRunning;

        public float TimeRemaining = GameConfig.DefaultMatchSeconds;
        public int ScoreAlpha;
        public int ScoreBravo;
        public int ScoreGoal = GameConfig.DefaultScoreGoal;

        // local player vitals, mirrored by the HUD
        public float Health = 100f;
        public float MaxHealth = 100f;
        public float Shield = 50f;
        public int AmmoInClip = 30;
        public int ClipSize = 30;
        public int AmmoReserve = 120;
        public float AbilityCharge01 = 0.4f;
        public int KillStreak;

        public readonly List<ScoreEntry> Scoreboard = new List<ScoreEntry>();
        public readonly List<string> KillFeed = new List<string>();

        public event Action Changed;

        void Awake() { Instance = this; }

        public void BeginMatch(MatchMode mode, string map, IEnumerable<PlayerProfile> players)
        {
            Mode = mode;
            MapName = map;
            TimeRemaining = GameConfig.DefaultMatchSeconds;
            ScoreAlpha = ScoreBravo = 0;
            KillFeed.Clear();
            Scoreboard.Clear();

            foreach (var p in players)
            {
                Scoreboard.Add(new ScoreEntry
                {
                    PlayerId = p.PlayerId, Name = p.DisplayName,
                    Team = p.Team, AgentId = p.AgentId
                });
            }

            var def = AgentCatalog.Get(GameBootstrap.Session.Local.AgentId);
            MaxHealth = def.Health;
            Health = def.Health;
            IsRunning = true;
            Raise();
        }

        public void RegisterKill(string killerId, string victimId, string weapon)
        {
            var killer = Find(killerId);
            var victim = Find(victimId);
            if (killer != null)
            {
                killer.Kills++;
                killer.Score += 100;
                if (killer.Team == Team.Alpha) ScoreAlpha++; else ScoreBravo++;
            }
            if (victim != null) victim.Deaths++;

            KillFeed.Add((killer != null ? killer.Name : "?") + "  ⟶  " +
                         (victim != null ? victim.Name : "?") + "   " + weapon);
            if (KillFeed.Count > 5) KillFeed.RemoveAt(0);

            if (ScoreAlpha >= ScoreGoal || ScoreBravo >= ScoreGoal) EndMatch();
            Raise();
        }

        public void EndMatch()
        {
            IsRunning = false;
            Scoreboard.Sort((a, b) => b.Score.CompareTo(a.Score));
            Raise();
        }

        ScoreEntry Find(string playerId)
        {
            for (int i = 0; i < Scoreboard.Count; i++)
                if (Scoreboard[i].PlayerId == playerId) return Scoreboard[i];
            return null;
        }

        void Update()
        {
            if (!IsRunning) return;
            TimeRemaining -= Time.deltaTime;
            if (TimeRemaining <= 0f) { TimeRemaining = 0f; EndMatch(); }
        }

        void Raise() { if (Changed != null) Changed(); }

        public static string Clock(float seconds)
        {
            var s = Mathf.Max(0, Mathf.FloorToInt(seconds));
            return (s / 60).ToString("00") + ":" + (s % 60).ToString("00");
        }
    }
}
