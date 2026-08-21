using System.Collections.Generic;
using UnityEngine;

namespace BattleOfAgents.Core
{
    public class AgentDef
    {
        public string Id;
        public string Name;
        public string Role;
        public string Blurb;
        public string AbilityName;
        public string AbilityDesc;
        public float Health = 100f;
        public float MoveSpeed = 6f;
        public float FireRate = 8f;      // shots / second
        public float Damage = 12f;
        public string AccentHex = "#3BE8FF";

        public Color Accent { get { return UI.Theme.Hex(AccentHex); } }
    }

    /// <summary>The playable roster. Kept as plain C# (not ScriptableObjects) so the
    /// data is diffable in git and costs no serialized assets in the APK.</summary>
    public static class AgentCatalog
    {
        public static readonly List<AgentDef> All = new List<AgentDef>
        {
            new AgentDef {
                Id = "vanguard", Name = "Vanguard", Role = "Assault",
                Blurb = "Front-line breacher. Trades range for raw pressure and a shield dash.",
                AbilityName = "Bulwark Dash", AbilityDesc = "Dash forward behind a hard-light shield for 2s.",
                Health = 120f, MoveSpeed = 6.2f, FireRate = 9f, Damage = 11f, AccentHex = "#3BE8FF" },
            new AgentDef {
                Id = "spectre", Name = "Spectre", Role = "Recon",
                Blurb = "Silent flanker. Sees heat signatures through thin walls.",
                AbilityName = "Thermal Sweep", AbilityDesc = "Reveal every enemy within 30m for 4s.",
                Health = 90f, MoveSpeed = 7.4f, FireRate = 11f, Damage = 9f, AccentHex = "#B58CFF" },
            new AgentDef {
                Id = "forge", Name = "Forge", Role = "Engineer",
                Blurb = "Holds ground. Deploys cover and repairs squad armour on the move.",
                AbilityName = "Deploy Barricade", AbilityDesc = "Drop a 3m energy wall that blocks fire.",
                Health = 110f, MoveSpeed = 5.6f, FireRate = 7f, Damage = 13f, AccentHex = "#FFB23B" },
            new AgentDef {
                Id = "reaper", Name = "Reaper", Role = "Marksman",
                Blurb = "One breath, one shot. Devastating at range, fragile up close.",
                AbilityName = "Steady Aim", AbilityDesc = "Slow time locally and lock the crosshair for 3s.",
                Health = 80f, MoveSpeed = 6.0f, FireRate = 1.6f, Damage = 65f, AccentHex = "#FF4D5E" },
            new AgentDef {
                Id = "medic", Name = "Halo", Role = "Support",
                Blurb = "Keeps the squad breathing. Field of regeneration, no offence to speak of.",
                AbilityName = "Nano Field", AbilityDesc = "Heal allies in a 6m field for 5s.",
                Health = 100f, MoveSpeed = 6.4f, FireRate = 8f, Damage = 8f, AccentHex = "#4DFFA6" },
            new AgentDef {
                Id = "havoc", Name = "Havoc", Role = "Demolition",
                Blurb = "Area denial specialist. Everything he touches ends up on fire.",
                AbilityName = "Cluster Volley", AbilityDesc = "Arc three incendiary charges downrange.",
                Health = 105f, MoveSpeed = 5.8f, FireRate = 5f, Damage = 22f, AccentHex = "#FF7A3B" },
        };

        public static AgentDef Get(string id)
        {
            for (int i = 0; i < All.Count; i++)
                if (All[i].Id == id) return All[i];
            return All[0];
        }
    }
}
