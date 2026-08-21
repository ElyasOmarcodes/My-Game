using UnityEngine;
using BattleOfAgents.Gameplay.World;

namespace BattleOfAgents.Gameplay.Models
{
    /// <summary>The four body archetypes every agent is built from.
    ///
    /// Four silhouettes rather than six models is a deliberate readability choice: a
    /// player has to identify a threat in half a second at forty metres, and shape
    /// reads long before colour does. The six roster agents map onto these four
    /// shapes and are told apart by their accent colour and gear trim.</summary>
    public enum BodyArchetype
    {
        Heavy,    // Vanguard, Havoc — armoured, wide shoulders, chest plate
        Scout,    // Spectre, Halo   — slim, hooded, coat tails
        Engineer, // Forge           — backpack tanks, welding mask, tool belt
        Marksman  // Reaper          — tall, lean, long coat, monocular sight
    }

    /// <summary>The assembled body: limb transforms an animator can drive, plus the
    /// mount the weapon model is parented to.</summary>
    public class CharacterRig : MonoBehaviour
    {
        public Transform Hips, Torso, Head, ArmLeft, ArmRight, LegLeft, LegRight, WeaponMount;
        public BodyArchetype Archetype;
        public float Height = 1.8f;

        Renderer[] _renderers;
        Material _accentMaterial;

        public void CacheRenderers(Material accent)
        {
            _renderers = GetComponentsInChildren<Renderer>();
            _accentMaterial = accent;
        }

        public void SetVisible(bool visible)
        {
            if (_renderers == null) return;
            for (int i = 0; i < _renderers.Length; i++)
                if (_renderers[i] != null) _renderers[i].enabled = visible;
        }

        public Material AccentMaterial { get { return _accentMaterial; } }
    }

    public static class AgentModelLibrary
    {
        public static BodyArchetype ArchetypeFor(string agentId)
        {
            switch (agentId)
            {
                case "spectre":
                case "medic":   return BodyArchetype.Scout;
                case "forge":
                case "havoc":   return BodyArchetype.Engineer;
                case "reaper":  return BodyArchetype.Marksman;
                default:        return BodyArchetype.Heavy;
            }
        }

        public static CharacterRig Build(Transform parent, BodyArchetype archetype,
            Color accentColor, Color teamColor)
        {
            var root = new GameObject("Rig_" + archetype);
            root.transform.SetParent(parent, false);
            var rig = root.AddComponent<CharacterRig>();
            rig.Archetype = archetype;

            var accent = MaterialLibrary.Accent(accentColor);
            var team = MaterialLibrary.TeamTrim(teamColor);

            switch (archetype)
            {
                case BodyArchetype.Scout:    BuildScout(rig, accent, team); break;
                case BodyArchetype.Engineer: BuildEngineer(rig, accent, team); break;
                case BodyArchetype.Marksman: BuildMarksman(rig, accent, team); break;
                default:                     BuildHeavy(rig, accent, team); break;
            }

            rig.CacheRenderers(accent);
            return rig;
        }

        // --- shared skeleton -------------------------------------------------

        /// <summary>Creates the joint hierarchy. Limb pivots sit at the shoulder and
        /// hip rather than at the limb's centre, so a plain rotation swings the limb
        /// the way a joint would — that is all the walk cycle needs.</summary>
        static void Skeleton(CharacterRig rig, float hipHeight, float shoulderHeight,
            float shoulderWidth, float hipWidth)
        {
            rig.Hips = Child(rig.transform, "Hips", new Vector3(0f, hipHeight, 0f));
            rig.Torso = Child(rig.Hips, "Torso", Vector3.zero);
            rig.Head = Child(rig.Torso, "Head", new Vector3(0f, shoulderHeight - hipHeight + 0.24f, 0f));
            rig.ArmLeft = Child(rig.Torso, "ArmL",
                new Vector3(-shoulderWidth, shoulderHeight - hipHeight, 0f));
            rig.ArmRight = Child(rig.Torso, "ArmR",
                new Vector3(shoulderWidth, shoulderHeight - hipHeight, 0f));
            rig.LegLeft = Child(rig.Hips, "LegL", new Vector3(-hipWidth, 0f, 0f));
            rig.LegRight = Child(rig.Hips, "LegR", new Vector3(hipWidth, 0f, 0f));

            rig.WeaponMount = Child(rig.ArmRight, "WeaponMount", new Vector3(0.02f, -0.30f, 0.30f));
        }

        static Transform Child(Transform parent, string name, Vector3 localPosition)
        {
            var go = new GameObject(name);
            go.transform.SetParent(parent, false);
            go.transform.localPosition = localPosition;
            return go.transform;
        }

        static void Emit(Transform bone, string name, Material material, BoxMeshBuilder builder)
        {
            builder.Emit(bone, name, material, false, false);
        }

        // --- archetypes -------------------------------------------------------

        static void BuildHeavy(CharacterRig rig, Material accent, Material team)
        {
            rig.Height = 1.86f;
            Skeleton(rig, 0.92f, 1.46f, 0.30f, 0.13f);

            var armour = MaterialLibrary.Surface("armour_heavy", new Color(0.115f, 0.125f, 0.145f), 0.42f, 0.35f);
            var under = MaterialLibrary.Fabric;

            var torso = new BoxMeshBuilder();
            torso.Add(new Vector3(0f, 0.28f, 0f), new Vector3(0.60f, 0.56f, 0.36f));   // chest
            torso.Add(new Vector3(0f, 0.52f, 0.02f), new Vector3(0.66f, 0.20f, 0.40f)); // plate
            torso.Add(new Vector3(-0.34f, 0.50f, 0f), new Vector3(0.20f, 0.24f, 0.34f)); // pauldron L
            torso.Add(new Vector3(0.34f, 0.50f, 0f), new Vector3(0.20f, 0.24f, 0.34f));  // pauldron R
            torso.Add(new Vector3(0f, -0.02f, 0f), new Vector3(0.44f, 0.24f, 0.30f));    // belt block
            Emit(rig.Torso, "Torso", armour, torso);

            var trim = new BoxMeshBuilder();
            trim.Add(new Vector3(0f, 0.60f, 0.19f), new Vector3(0.34f, 0.05f, 0.03f));   // team stripe
            trim.Add(new Vector3(-0.34f, 0.60f, 0f), new Vector3(0.16f, 0.03f, 0.28f));
            Emit(rig.Torso, "TeamTrim", team, trim);

            var head = new BoxMeshBuilder();
            head.Add(Vector3.zero, new Vector3(0.30f, 0.30f, 0.32f));                    // helmet
            head.Add(new Vector3(0f, 0.15f, -0.02f), new Vector3(0.32f, 0.06f, 0.34f));  // crest
            Emit(rig.Head, "Helmet", armour, head);

            var visor = new BoxMeshBuilder();
            visor.Add(new Vector3(0f, 0.01f, 0.16f), new Vector3(0.24f, 0.08f, 0.04f));
            Emit(rig.Head, "Visor", accent, visor);

            Limb(rig.ArmLeft, "ArmL", armour, 0.19f, 0.62f);
            Limb(rig.ArmRight, "ArmR", armour, 0.19f, 0.62f);
            Limb(rig.LegLeft, "LegL", under, 0.22f, 0.86f, true);
            Limb(rig.LegRight, "LegR", under, 0.22f, 0.86f, true);
        }

        static void BuildScout(CharacterRig rig, Material accent, Material team)
        {
            rig.Height = 1.74f;
            Skeleton(rig, 0.88f, 1.40f, 0.24f, 0.11f);

            var suit = MaterialLibrary.Surface("suit_scout", new Color(0.078f, 0.085f, 0.100f), 0.30f);
            var cloth = MaterialLibrary.Fabric;

            var torso = new BoxMeshBuilder();
            torso.Add(new Vector3(0f, 0.26f, 0f), new Vector3(0.46f, 0.54f, 0.28f));
            torso.Add(new Vector3(0f, 0.44f, -0.02f), new Vector3(0.50f, 0.16f, 0.30f)); // shoulder wrap
            torso.Add(new Vector3(0f, -0.18f, -0.10f), new Vector3(0.44f, 0.46f, 0.08f)); // coat tail
            torso.Add(new Vector3(0.16f, 0.10f, 0.15f), new Vector3(0.12f, 0.20f, 0.06f)); // chest pouch
            Emit(rig.Torso, "Torso", suit, torso);

            var trim = new BoxMeshBuilder();
            trim.Add(new Vector3(0f, 0.05f, 0.145f), new Vector3(0.30f, 0.03f, 0.02f));
            trim.Add(new Vector3(-0.24f, 0.44f, 0f), new Vector3(0.03f, 0.10f, 0.24f));
            Emit(rig.Torso, "TeamTrim", team, trim);

            var head = new BoxMeshBuilder();
            head.Add(Vector3.zero, new Vector3(0.24f, 0.28f, 0.26f));                     // masked head
            head.Add(new Vector3(0f, 0.10f, -0.10f), new Vector3(0.32f, 0.26f, 0.20f));   // hood back
            head.Add(new Vector3(0f, 0.19f, 0.02f), new Vector3(0.30f, 0.10f, 0.30f));    // hood crown
            Emit(rig.Head, "Hood", cloth, head);

            var visor = new BoxMeshBuilder();
            visor.Add(new Vector3(0f, 0.0f, 0.135f), new Vector3(0.18f, 0.05f, 0.03f));
            Emit(rig.Head, "Visor", accent, visor);

            Limb(rig.ArmLeft, "ArmL", suit, 0.14f, 0.60f);
            Limb(rig.ArmRight, "ArmR", suit, 0.14f, 0.60f);
            Limb(rig.LegLeft, "LegL", suit, 0.17f, 0.84f, true);
            Limb(rig.LegRight, "LegR", suit, 0.17f, 0.84f, true);
        }

        static void BuildEngineer(CharacterRig rig, Material accent, Material team)
        {
            rig.Height = 1.80f;
            Skeleton(rig, 0.90f, 1.42f, 0.29f, 0.13f);

            var overall = MaterialLibrary.Surface("overall", new Color(0.135f, 0.100f, 0.055f), 0.22f);
            var steel = MaterialLibrary.Steel;

            var torso = new BoxMeshBuilder();
            torso.Add(new Vector3(0f, 0.26f, 0f), new Vector3(0.56f, 0.54f, 0.34f));
            torso.Add(new Vector3(0f, 0.02f, 0f), new Vector3(0.52f, 0.14f, 0.36f));      // tool belt
            Emit(rig.Torso, "Torso", overall, torso);

            var pack = new BoxMeshBuilder();
            pack.Add(new Vector3(0f, 0.30f, -0.26f), new Vector3(0.44f, 0.44f, 0.20f));   // backpack
            pack.Add(new Vector3(-0.13f, 0.34f, -0.40f), new Vector3(0.14f, 0.46f, 0.14f)); // tank L
            pack.Add(new Vector3(0.13f, 0.34f, -0.40f), new Vector3(0.14f, 0.46f, 0.14f));  // tank R
            pack.Add(new Vector3(0f, 0.60f, -0.34f), new Vector3(0.34f, 0.06f, 0.10f));   // manifold
            Emit(rig.Torso, "Backpack", steel, pack);

            var trim = new BoxMeshBuilder();
            trim.Add(new Vector3(0f, 0.09f, 0.175f), new Vector3(0.34f, 0.04f, 0.02f));
            trim.Add(new Vector3(0f, 0.57f, -0.30f), new Vector3(0.20f, 0.03f, 0.02f));
            Emit(rig.Torso, "TeamTrim", team, trim);

            var head = new BoxMeshBuilder();
            head.Add(Vector3.zero, new Vector3(0.28f, 0.30f, 0.28f));
            head.Add(new Vector3(0f, 0.17f, 0.06f), new Vector3(0.34f, 0.05f, 0.40f));    // hard-hat brim
            Emit(rig.Head, "Mask", MaterialLibrary.Surface("hardhat", new Color(0.30f, 0.20f, 0.05f), 0.4f), head);

            var visor = new BoxMeshBuilder();
            visor.Add(new Vector3(0f, 0.0f, 0.145f), new Vector3(0.22f, 0.11f, 0.03f));   // wide welding visor
            Emit(rig.Head, "Visor", accent, visor);

            Limb(rig.ArmLeft, "ArmL", overall, 0.18f, 0.60f);
            Limb(rig.ArmRight, "ArmR", overall, 0.18f, 0.60f);
            Limb(rig.LegLeft, "LegL", overall, 0.21f, 0.84f, true);
            Limb(rig.LegRight, "LegR", overall, 0.21f, 0.84f, true);
        }

        static void BuildMarksman(CharacterRig rig, Material accent, Material team)
        {
            rig.Height = 1.94f;
            Skeleton(rig, 0.98f, 1.56f, 0.25f, 0.12f);

            var coat = MaterialLibrary.Surface("coat", new Color(0.062f, 0.068f, 0.082f), 0.24f);

            var torso = new BoxMeshBuilder();
            torso.Add(new Vector3(0f, 0.28f, 0f), new Vector3(0.46f, 0.58f, 0.28f));
            torso.Add(new Vector3(0f, -0.30f, -0.03f), new Vector3(0.50f, 0.68f, 0.24f)); // long coat
            torso.Add(new Vector3(0f, 0.50f, 0.04f), new Vector3(0.34f, 0.18f, 0.26f));   // collar/scarf
            Emit(rig.Torso, "Torso", coat, torso);

            var trim = new BoxMeshBuilder();
            trim.Add(new Vector3(0f, 0.02f, 0.145f), new Vector3(0.26f, 0.03f, 0.02f));
            trim.Add(new Vector3(0f, -0.58f, -0.04f), new Vector3(0.46f, 0.03f, 0.22f));  // coat hem
            Emit(rig.Torso, "TeamTrim", team, trim);

            var head = new BoxMeshBuilder();
            head.Add(Vector3.zero, new Vector3(0.24f, 0.28f, 0.26f));
            head.Add(new Vector3(0f, 0.16f, -0.04f), new Vector3(0.26f, 0.06f, 0.30f));   // cap
            Emit(rig.Head, "Head", coat, head);

            var visor = new BoxMeshBuilder();
            visor.Add(new Vector3(0.06f, 0.02f, 0.135f), new Vector3(0.09f, 0.05f, 0.05f)); // monocular
            Emit(rig.Head, "Sight", accent, visor);

            Limb(rig.ArmLeft, "ArmL", coat, 0.14f, 0.64f);
            Limb(rig.ArmRight, "ArmR", coat, 0.14f, 0.64f);
            Limb(rig.LegLeft, "LegL", coat, 0.17f, 0.92f, true);
            Limb(rig.LegRight, "LegR", coat, 0.17f, 0.92f, true);
        }

        /// <summary>A limb hanging from its joint, with a boot block when it is a leg.</summary>
        static void Limb(Transform bone, string name, Material material, float thickness,
            float length, bool isLeg = false)
        {
            var builder = new BoxMeshBuilder();
            builder.Add(new Vector3(0f, -length * 0.5f, 0f),
                new Vector3(thickness, length, thickness));

            if (isLeg)
                builder.Add(new Vector3(0f, -length + 0.04f, 0.04f),
                    new Vector3(thickness + 0.03f, 0.10f, thickness + 0.10f));

            builder.Emit(bone, name, material, false, false);
        }
    }
}
