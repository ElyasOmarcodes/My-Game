using System.Collections.Generic;
using BattleOfAgents.UI;
using UnityEngine;

namespace BattleOfAgents.Gameplay
{
    /// <summary>Builds a playable arena out of primitives at runtime.
    ///
    /// A procedural arena costs nothing in the APK (no meshes, no lightmaps) and the
    /// same seed produces the same layout on every device, which is exactly what a
    /// LAN match needs — the host only has to send the seed, never the geometry.</summary>
    public class ArenaBuilder : MonoBehaviour
    {
        public readonly List<Transform> SpawnsAlpha = new List<Transform>();
        public readonly List<Transform> SpawnsBravo = new List<Transform>();

        const float ArenaHalfSize = 34f;

        Material _floorMat, _wallMat, _crateMat, _accentAlpha, _accentBravo;

        public void Build(int seed, string mapName)
        {
            var random = new System.Random(seed);
            CreateMaterials();
            CreateLighting();
            CreateFloor();
            CreatePerimeter();
            CreateCover(random);
            CreateSpawns();
            gameObject.name = "[Arena] " + mapName;
        }

        // --- materials --------------------------------------------------------

        static Material Lit(Color color, float smoothness, float metallic, Color? emission = null)
        {
            var shader = Shader.Find("Universal Render Pipeline/Lit") ?? Shader.Find("Standard");
            var mat = new Material(shader);
            mat.color = color;
            if (mat.HasProperty("_Smoothness")) mat.SetFloat("_Smoothness", smoothness);
            if (mat.HasProperty("_Metallic")) mat.SetFloat("_Metallic", metallic);

            if (emission.HasValue)
            {
                mat.EnableKeyword("_EMISSION");
                mat.SetColor("_EmissionColor", emission.Value * 3.2f);   // >1 so bloom catches it
            }
            return mat;
        }

        void CreateMaterials()
        {
            _floorMat    = Lit(new Color(0.055f, 0.070f, 0.095f), 0.62f, 0.10f);
            _wallMat     = Lit(new Color(0.085f, 0.105f, 0.135f), 0.35f, 0.05f);
            _crateMat    = Lit(new Color(0.12f, 0.14f, 0.17f), 0.30f, 0.20f);
            _accentAlpha = Lit(Color.black, 0.9f, 0f, Theme.TeamAlpha);
            _accentBravo = Lit(Color.black, 0.9f, 0f, Theme.TeamBravo);
        }

        // --- environment ------------------------------------------------------

        void CreateLighting()
        {
            var sunGo = new GameObject("KeyLight");
            sunGo.transform.SetParent(transform, false);
            sunGo.transform.rotation = Quaternion.Euler(48f, 38f, 0f);

            var sun = sunGo.AddComponent<Light>();
            sun.type = LightType.Directional;
            sun.color = new Color(1f, 0.86f, 0.72f);      // warm key
            sun.intensity = 1.35f;
            sun.shadows = LightShadows.Soft;
            sun.shadowStrength = 0.85f;

            var fillGo = new GameObject("FillLight");
            fillGo.transform.SetParent(transform, false);
            fillGo.transform.rotation = Quaternion.Euler(-18f, -140f, 0f);
            var fill = fillGo.AddComponent<Light>();
            fill.type = LightType.Directional;
            fill.color = new Color(0.42f, 0.68f, 1f);     // cool bounce, no shadows
            fill.intensity = 0.55f;
            fill.shadows = LightShadows.None;

            RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = new Color(0.10f, 0.16f, 0.24f);
            RenderSettings.ambientEquatorColor = new Color(0.06f, 0.08f, 0.12f);
            RenderSettings.ambientGroundColor = new Color(0.03f, 0.03f, 0.05f);
            RenderSettings.fog = true;
            RenderSettings.fogMode = FogMode.ExponentialSquared;
            RenderSettings.fogColor = new Color(0.04f, 0.06f, 0.10f);
            RenderSettings.fogDensity = 0.012f;
        }

        void CreateFloor()
        {
            var floor = Block("Floor", Vector3.zero,
                new Vector3(ArenaHalfSize * 2f, 1f, ArenaHalfSize * 2f), _floorMat);
            floor.transform.position = new Vector3(0f, -0.5f, 0f);

            // Two glowing strips mark each team's half — readable at a glance mid-fight.
            var stripA = Block("StripAlpha", new Vector3(0f, 0.01f, -ArenaHalfSize + 6f),
                new Vector3(ArenaHalfSize * 1.6f, 0.02f, 0.35f), _accentAlpha);
            Destroy(stripA.GetComponent<Collider>());

            var stripB = Block("StripBravo", new Vector3(0f, 0.01f, ArenaHalfSize - 6f),
                new Vector3(ArenaHalfSize * 1.6f, 0.02f, 0.35f), _accentBravo);
            Destroy(stripB.GetComponent<Collider>());
        }

        void CreatePerimeter()
        {
            const float h = 7f;
            Block("WallN", new Vector3(0f, h * 0.5f, ArenaHalfSize),
                new Vector3(ArenaHalfSize * 2f, h, 1f), _wallMat);
            Block("WallS", new Vector3(0f, h * 0.5f, -ArenaHalfSize),
                new Vector3(ArenaHalfSize * 2f, h, 1f), _wallMat);
            Block("WallE", new Vector3(ArenaHalfSize, h * 0.5f, 0f),
                new Vector3(1f, h, ArenaHalfSize * 2f), _wallMat);
            Block("WallW", new Vector3(-ArenaHalfSize, h * 0.5f, 0f),
                new Vector3(1f, h, ArenaHalfSize * 2f), _wallMat);
        }

        /// <summary>Cover is mirrored across the centre line so neither team starts with
        /// a better angle — the same reason competitive maps are symmetric.</summary>
        void CreateCover(System.Random random)
        {
            for (int i = 0; i < 14; i++)
            {
                var x = (float)(random.NextDouble() * 2 - 1) * (ArenaHalfSize - 8f);
                var z = (float)(random.NextDouble()) * (ArenaHalfSize - 10f);
                var w = 2f + (float)random.NextDouble() * 4f;
                var h = 1.6f + (float)random.NextDouble() * 3.2f;
                var d = 2f + (float)random.NextDouble() * 4f;

                Block("Cover_" + i + "a", new Vector3(x, h * 0.5f, z), new Vector3(w, h, d), _crateMat);
                Block("Cover_" + i + "b", new Vector3(-x, h * 0.5f, -z), new Vector3(w, h, d), _crateMat);
            }

            // A raised centre platform: the contested ground every mode fights over.
            Block("CentrePlatform", new Vector3(0f, 0.6f, 0f), new Vector3(12f, 1.2f, 12f), _wallMat);
            var ring = Block("CentreRing", new Vector3(0f, 1.22f, 0f), new Vector3(12.4f, 0.06f, 12.4f),
                Lit(Color.black, 0.9f, 0f, Theme.Amber));
            Destroy(ring.GetComponent<Collider>());
        }

        void CreateSpawns()
        {
            for (int i = 0; i < 4; i++)
            {
                SpawnsAlpha.Add(Spawn("SpawnA" + i,
                    new Vector3(-9f + i * 6f, 1f, -ArenaHalfSize + 4f), 0f));
                SpawnsBravo.Add(Spawn("SpawnB" + i,
                    new Vector3(-9f + i * 6f, 1f, ArenaHalfSize - 4f), 180f));
            }
        }

        Transform Spawn(string name, Vector3 position, float yaw)
        {
            var go = new GameObject(name);
            go.transform.SetParent(transform, false);
            go.transform.position = position;
            go.transform.rotation = Quaternion.Euler(0f, yaw, 0f);
            return go.transform;
        }

        GameObject Block(string name, Vector3 position, Vector3 size, Material material)
        {
            var go = GameObject.CreatePrimitive(PrimitiveType.Cube);
            go.name = name;
            go.transform.SetParent(transform, false);
            go.transform.position = position;
            go.transform.localScale = size;
            go.GetComponent<MeshRenderer>().sharedMaterial = material;
            return go;
        }

        public Transform PickSpawn(Core.Team team, int index)
        {
            var list = team == Core.Team.Bravo ? SpawnsBravo : SpawnsAlpha;
            if (list.Count == 0) return transform;
            return list[Mathf.Abs(index) % list.Count];
        }
    }
}
