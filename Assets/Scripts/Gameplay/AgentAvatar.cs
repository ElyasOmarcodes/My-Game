using BattleOfAgents.Core;
using UnityEngine;

namespace BattleOfAgents.Gameplay
{
    /// <summary>The visual body of an agent, assembled from primitives and tinted with
    /// the agent's accent colour. Emissive trim means every silhouette reads at a
    /// glance through the bloom — which is what "who am I shooting at" comes down to.</summary>
    public class AgentAvatar : MonoBehaviour
    {
        public Transform MuzzlePoint { get; private set; }
        public Transform Head { get; private set; }

        Material _accentMat;
        Renderer[] _renderers;

        public static AgentAvatar Create(Transform parent, AgentDef def, Team team, string label)
        {
            var root = new GameObject("Avatar_" + def.Id);
            root.transform.SetParent(parent, false);
            var avatar = root.AddComponent<AgentAvatar>();
            avatar.Assemble(def, team, label);
            return avatar;
        }

        void Assemble(AgentDef def, Team team, string label)
        {
            var teamColor = team == Team.Bravo ? UI.Theme.TeamBravo : UI.Theme.TeamAlpha;
            var bodyMat = MakeMaterial(new Color(0.09f, 0.10f, 0.13f), Color.black);
            _accentMat = MakeMaterial(new Color(0.02f, 0.02f, 0.03f), def.Accent * 2.6f);
            var teamMat = MakeMaterial(new Color(0.03f, 0.03f, 0.04f), teamColor * 2.2f);

            Part(PrimitiveType.Capsule, "Torso", new Vector3(0f, 0.95f, 0f),
                new Vector3(0.62f, 0.62f, 0.62f), bodyMat);

            Head = Part(PrimitiveType.Sphere, "Head", new Vector3(0f, 1.62f, 0f),
                new Vector3(0.42f, 0.42f, 0.42f), bodyMat).transform;

            // visor: the emissive band that identifies the agent at distance
            Part(PrimitiveType.Cube, "Visor", new Vector3(0f, 1.64f, 0.18f),
                new Vector3(0.30f, 0.09f, 0.10f), _accentMat);

            // team band on the shoulders
            Part(PrimitiveType.Cube, "TeamBand", new Vector3(0f, 1.28f, 0f),
                new Vector3(0.68f, 0.08f, 0.42f), teamMat);

            Part(PrimitiveType.Cube, "LegL", new Vector3(-0.17f, 0.32f, 0f),
                new Vector3(0.20f, 0.64f, 0.22f), bodyMat);
            Part(PrimitiveType.Cube, "LegR", new Vector3(0.17f, 0.32f, 0f),
                new Vector3(0.20f, 0.64f, 0.22f), bodyMat);

            var weapon = Part(PrimitiveType.Cube, "Weapon", new Vector3(0.28f, 1.05f, 0.42f),
                new Vector3(0.12f, 0.14f, 0.86f), bodyMat);

            var muzzle = new GameObject("Muzzle");
            muzzle.transform.SetParent(weapon.transform, false);
            muzzle.transform.localPosition = new Vector3(0f, 0f, 0.55f);
            MuzzlePoint = muzzle.transform;

            _renderers = GetComponentsInChildren<Renderer>();
            NameTag.Attach(transform, label, teamColor);
        }

        GameObject Part(PrimitiveType type, string name, Vector3 localPos, Vector3 scale, Material mat)
        {
            var go = GameObject.CreatePrimitive(type);
            go.name = name;
            go.transform.SetParent(transform, false);
            go.transform.localPosition = localPos;
            go.transform.localScale = scale;
            go.GetComponent<Renderer>().sharedMaterial = mat;
            Destroy(go.GetComponent<Collider>());   // the CharacterController is the hitbox
            return go;
        }

        static Material MakeMaterial(Color albedo, Color emission)
        {
            var shader = Shader.Find("Universal Render Pipeline/Lit") ?? Shader.Find("Standard");
            var mat = new Material(shader) { color = albedo };
            if (mat.HasProperty("_Smoothness")) mat.SetFloat("_Smoothness", 0.45f);
            if (emission != Color.black)
            {
                mat.EnableKeyword("_EMISSION");
                mat.SetColor("_EmissionColor", emission);
            }
            return mat;
        }

        /// <summary>Flash the whole body white for a frame or two when hit.</summary>
        public void FlashHit()
        {
            CancelInvoke("ClearFlash");
            SetEmissionBoost(4f);
            Invoke("ClearFlash", 0.08f);
        }

        void ClearFlash() { SetEmissionBoost(1f); }

        void SetEmissionBoost(float multiplier)
        {
            if (_accentMat == null || !_accentMat.HasProperty("_EmissionColor")) return;
            var baseColor = _accentMat.GetColor("_EmissionColor").normalized * 2.6f;
            _accentMat.SetColor("_EmissionColor", baseColor * multiplier);
        }

        public void SetVisible(bool visible)
        {
            if (_renderers == null) return;
            for (int i = 0; i < _renderers.Length; i++) _renderers[i].enabled = visible;
        }
    }
}
