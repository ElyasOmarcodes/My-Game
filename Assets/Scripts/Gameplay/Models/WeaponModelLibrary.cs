using System.Collections.Generic;
using UnityEngine;
using BattleOfAgents.Gameplay.World;

namespace BattleOfAgents.Gameplay.Models
{
    public class WeaponDef
    {
        public string Id;
        public string Name;
        public string Class;
        public float Damage;
        public float FireRate;       // rounds per second
        public float Spread;
        public int ClipSize;
        public int Reserve;
        public float ReloadSeconds;
        public float Range;
        public float RecoilKick;
    }

    /// <summary>Five weapon models and their handling stats.
    ///
    /// Each is a different silhouette rather than a re-skin, because a weapon has to
    /// be identifiable in the loadout screen at thumbnail size and in someone else's
    /// hands at thirty metres.</summary>
    public static class WeaponModelLibrary
    {
        public static readonly List<WeaponDef> All = new List<WeaponDef>
        {
            new WeaponDef { Id = "carbine", Name = "MK-7 Carbine", Class = "Assault rifle",
                Damage = 22f, FireRate = 8.5f, Spread = 0.016f, ClipSize = 30, Reserve = 150,
                ReloadSeconds = 1.7f, Range = 110f, RecoilKick = 1.1f },
            new WeaponDef { Id = "smg", Name = "Wasp SMG", Class = "Submachine gun",
                Damage = 15f, FireRate = 14f, Spread = 0.030f, ClipSize = 35, Reserve = 175,
                ReloadSeconds = 1.4f, Range = 55f, RecoilKick = 0.8f },
            new WeaponDef { Id = "sniper", Name = "Longbow DMR", Class = "Marksman rifle",
                Damage = 78f, FireRate = 1.4f, Spread = 0.002f, ClipSize = 6, Reserve = 36,
                ReloadSeconds = 2.4f, Range = 220f, RecoilKick = 3.4f },
            new WeaponDef { Id = "shotgun", Name = "Breaker 12", Class = "Shotgun",
                Damage = 14f, FireRate = 1.6f, Spread = 0.075f, ClipSize = 7, Reserve = 42,
                ReloadSeconds = 2.8f, Range = 26f, RecoilKick = 3.0f },
            new WeaponDef { Id = "pistol", Name = "Vector Sidearm", Class = "Sidearm",
                Damage = 26f, FireRate = 4.5f, Spread = 0.020f, ClipSize = 15, Reserve = 90,
                ReloadSeconds = 1.2f, Range = 45f, RecoilKick = 1.4f },
        };

        public static WeaponDef Get(string id)
        {
            for (int i = 0; i < All.Count; i++) if (All[i].Id == id) return All[i];
            return All[0];
        }

        /// <summary>Which weapon each roster agent carries by default.</summary>
        public static string DefaultFor(string agentId)
        {
            switch (agentId)
            {
                case "spectre": return "smg";
                case "reaper":  return "sniper";
                case "havoc":   return "shotgun";
                case "medic":   return "pistol";
                default:        return "carbine";
            }
        }

        /// <summary>Builds the weapon under <paramref name="mount"/> and returns its
        /// muzzle transform, which is where tracers and the flash originate.</summary>
        public static Transform Build(Transform mount, string weaponId, Color accentColor)
        {
            var metal = MaterialLibrary.Gunmetal;
            var polymer = MaterialLibrary.Polymer;
            var accent = MaterialLibrary.Accent(accentColor);

            var root = new GameObject("Weapon_" + weaponId);
            root.transform.SetParent(mount, false);

            var body = new BoxMeshBuilder();
            var shell = new BoxMeshBuilder();
            var glow = new BoxMeshBuilder();
            float muzzleZ;

            switch (weaponId)
            {
                case "smg":       muzzleZ = Smg(body, shell, glow); break;
                case "sniper":    muzzleZ = Sniper(body, shell, glow); break;
                case "shotgun":   muzzleZ = Shotgun(body, shell, glow); break;
                case "pistol":    muzzleZ = Pistol(body, shell, glow); break;
                default:          muzzleZ = Carbine(body, shell, glow); break;
            }

            body.Emit(root.transform, "Metal", metal, false, false);
            shell.Emit(root.transform, "Shell", polymer, false, false);
            glow.Emit(root.transform, "Accent", accent, false, false);

            var muzzle = new GameObject("Muzzle");
            muzzle.transform.SetParent(root.transform, false);
            muzzle.transform.localPosition = new Vector3(0f, 0f, muzzleZ);
            return muzzle.transform;
        }

        // Each builder returns the muzzle's local Z so tracers start at the barrel tip.

        static float Carbine(BoxMeshBuilder metal, BoxMeshBuilder shell, BoxMeshBuilder glow)
        {
            metal.Add(new Vector3(0f, 0f, 0.06f), new Vector3(0.075f, 0.115f, 0.44f));   // receiver
            metal.Add(new Vector3(0f, 0.012f, 0.44f), new Vector3(0.045f, 0.045f, 0.40f)); // barrel
            metal.Add(new Vector3(0f, 0.030f, 0.30f), new Vector3(0.055f, 0.030f, 0.16f)); // gas block
            shell.Add(new Vector3(0f, -0.10f, -0.02f), new Vector3(0.060f, 0.20f, 0.10f)); // magazine
            shell.Add(new Vector3(0f, -0.08f, -0.16f), new Vector3(0.055f, 0.15f, 0.09f)); // grip
            shell.Add(new Vector3(0f, 0.005f, -0.30f), new Vector3(0.065f, 0.105f, 0.26f)); // stock
            shell.Add(new Vector3(0f, 0.070f, 0.10f), new Vector3(0.050f, 0.022f, 0.30f)); // rail
            glow.Add(new Vector3(0f, 0.088f, 0.20f), new Vector3(0.020f, 0.016f, 0.045f)); // sight dot
            glow.Add(new Vector3(0.039f, 0.0f, 0.10f), new Vector3(0.004f, 0.020f, 0.20f)); // side strip
            return 0.66f;
        }

        static float Smg(BoxMeshBuilder metal, BoxMeshBuilder shell, BoxMeshBuilder glow)
        {
            metal.Add(new Vector3(0f, 0f, 0.02f), new Vector3(0.070f, 0.110f, 0.30f));
            metal.Add(new Vector3(0f, 0.010f, 0.26f), new Vector3(0.040f, 0.040f, 0.20f));
            shell.Add(new Vector3(0f, -0.12f, -0.01f), new Vector3(0.052f, 0.24f, 0.075f)); // long mag
            shell.Add(new Vector3(0f, -0.07f, -0.13f), new Vector3(0.050f, 0.14f, 0.085f));
            shell.Add(new Vector3(0f, 0.065f, -0.14f), new Vector3(0.045f, 0.030f, 0.22f)); // folded stock
            glow.Add(new Vector3(0f, 0.070f, 0.10f), new Vector3(0.018f, 0.014f, 0.040f));
            glow.Add(new Vector3(0.037f, -0.02f, 0.02f), new Vector3(0.004f, 0.045f, 0.12f));
            return 0.38f;
        }

        static float Sniper(BoxMeshBuilder metal, BoxMeshBuilder shell, BoxMeshBuilder glow)
        {
            metal.Add(new Vector3(0f, 0f, 0.08f), new Vector3(0.070f, 0.120f, 0.52f));
            metal.Add(new Vector3(0f, 0.010f, 0.60f), new Vector3(0.040f, 0.040f, 0.66f));  // long barrel
            metal.Add(new Vector3(0f, 0.010f, 0.92f), new Vector3(0.055f, 0.055f, 0.12f));  // muzzle brake
            metal.Add(new Vector3(0f, 0.105f, 0.22f), new Vector3(0.058f, 0.075f, 0.30f));  // scope tube
            shell.Add(new Vector3(0f, -0.08f, 0.00f), new Vector3(0.055f, 0.16f, 0.10f));
            shell.Add(new Vector3(0f, -0.07f, -0.18f), new Vector3(0.052f, 0.14f, 0.09f));
            shell.Add(new Vector3(0f, -0.005f, -0.36f), new Vector3(0.070f, 0.125f, 0.32f)); // heavy stock
            shell.Add(new Vector3(-0.05f, -0.10f, 0.52f), new Vector3(0.016f, 0.20f, 0.016f), 12f); // bipod
            shell.Add(new Vector3(0.05f, -0.10f, 0.52f), new Vector3(0.016f, 0.20f, 0.016f), -12f);
            glow.Add(new Vector3(0f, 0.105f, 0.375f), new Vector3(0.038f, 0.038f, 0.012f)); // lens
            glow.Add(new Vector3(0.036f, 0.0f, 0.14f), new Vector3(0.004f, 0.024f, 0.26f));
            return 1.28f;
        }

        static float Shotgun(BoxMeshBuilder metal, BoxMeshBuilder shell, BoxMeshBuilder glow)
        {
            metal.Add(new Vector3(0f, 0f, 0.04f), new Vector3(0.085f, 0.125f, 0.36f));
            metal.Add(new Vector3(0f, 0.020f, 0.38f), new Vector3(0.070f, 0.070f, 0.44f));  // thick barrel
            metal.Add(new Vector3(0f, -0.045f, 0.38f), new Vector3(0.060f, 0.055f, 0.42f)); // tube magazine
            shell.Add(new Vector3(0f, -0.048f, 0.30f), new Vector3(0.080f, 0.075f, 0.16f)); // pump
            shell.Add(new Vector3(0f, -0.08f, -0.14f), new Vector3(0.055f, 0.15f, 0.09f));
            shell.Add(new Vector3(0f, -0.02f, -0.32f), new Vector3(0.080f, 0.145f, 0.28f)); // wide stock
            glow.Add(new Vector3(0f, 0.070f, 0.14f), new Vector3(0.022f, 0.014f, 0.05f));
            glow.Add(new Vector3(0.044f, 0.0f, 0.06f), new Vector3(0.004f, 0.030f, 0.16f));
            return 0.62f;
        }

        static float Pistol(BoxMeshBuilder metal, BoxMeshBuilder shell, BoxMeshBuilder glow)
        {
            metal.Add(new Vector3(0f, 0.02f, 0.02f), new Vector3(0.055f, 0.095f, 0.22f));   // slide
            metal.Add(new Vector3(0f, 0.015f, 0.14f), new Vector3(0.030f, 0.030f, 0.06f));
            shell.Add(new Vector3(0f, -0.10f, -0.04f), new Vector3(0.048f, 0.17f, 0.075f), 8f); // grip
            glow.Add(new Vector3(0f, 0.062f, 0.06f), new Vector3(0.014f, 0.012f, 0.03f));
            glow.Add(new Vector3(0.029f, 0.02f, 0.02f), new Vector3(0.003f, 0.020f, 0.12f));
            return 0.19f;
        }
    }
}
