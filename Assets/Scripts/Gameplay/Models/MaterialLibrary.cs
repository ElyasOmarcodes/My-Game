using System.Collections.Generic;
using UnityEngine;

namespace BattleOfAgents.Gameplay.Models
{
    /// <summary>Shared, cached materials.
    ///
    /// Every material here is created once and reused by every mesh that needs it, so
    /// the renderer can batch a whole district together. Creating a material per
    /// object is the single easiest way to destroy mobile performance.</summary>
    public static class MaterialLibrary
    {
        static readonly Dictionary<string, Material> Cache = new Dictionary<string, Material>();

        static Shader _lit, _unlit;

        static Shader Lit
        {
            get
            {
                if (_lit == null)
                    _lit = Shader.Find("Universal Render Pipeline/Lit") ?? Shader.Find("Standard");
                return _lit;
            }
        }

        public static Material Surface(string key, Color albedo, float smoothness = 0.35f,
            float metallic = 0f)
        {
            Material cached;
            if (Cache.TryGetValue(key, out cached) && cached != null) return cached;

            var mat = new Material(Lit) { name = key, color = albedo };
            if (mat.HasProperty("_BaseColor")) mat.SetColor("_BaseColor", albedo);
            if (mat.HasProperty("_Smoothness")) mat.SetFloat("_Smoothness", smoothness);
            if (mat.HasProperty("_Metallic")) mat.SetFloat("_Metallic", metallic);
            mat.enableInstancing = true;

            Cache[key] = mat;
            return mat;
        }

        /// <summary>Emissive material. Intensity above 1 is what the bloom pass picks
        /// up — that is where the neon look comes from.</summary>
        public static Material Emissive(string key, Color color, float intensity = 3f)
        {
            Material cached;
            if (Cache.TryGetValue(key, out cached) && cached != null) return cached;

            var mat = new Material(Lit) { name = key, color = Color.black };
            if (mat.HasProperty("_BaseColor")) mat.SetColor("_BaseColor", new Color(0.02f, 0.02f, 0.03f));
            if (mat.HasProperty("_Smoothness")) mat.SetFloat("_Smoothness", 0.8f);
            mat.EnableKeyword("_EMISSION");
            mat.globalIlluminationFlags = MaterialGlobalIlluminationFlags.RealtimeEmissive;
            mat.SetColor("_EmissionColor", color * intensity);
            mat.enableInstancing = true;

            Cache[key] = mat;
            return mat;
        }

        // --- the palette every builder draws from ----------------------------

        public static Material Asphalt   { get { return Surface("asphalt",  new Color(0.045f, 0.050f, 0.062f), 0.45f); } }
        public static Material Pavement  { get { return Surface("pavement", new Color(0.105f, 0.112f, 0.128f), 0.25f); } }
        public static Material Concrete  { get { return Surface("concrete", new Color(0.145f, 0.152f, 0.168f), 0.20f); } }
        public static Material Brick     { get { return Surface("brick",    new Color(0.165f, 0.108f, 0.092f), 0.18f); } }
        public static Material Steel     { get { return Surface("steel",    new Color(0.118f, 0.130f, 0.152f), 0.62f, 0.75f); } }
        public static Material Glass     { get { return Surface("glass",    new Color(0.055f, 0.085f, 0.115f), 0.92f, 0.35f); } }
        public static Material Grass     { get { return Surface("grass",    new Color(0.062f, 0.115f, 0.072f), 0.15f); } }
        public static Material Foliage   { get { return Surface("foliage",  new Color(0.075f, 0.145f, 0.085f), 0.20f); } }
        public static Material Bark      { get { return Surface("bark",     new Color(0.085f, 0.070f, 0.058f), 0.15f); } }
        public static Material Water     { get { return Surface("water",    new Color(0.030f, 0.075f, 0.105f), 0.95f, 0.10f); } }
        public static Material Gunmetal  { get { return Surface("gunmetal", new Color(0.070f, 0.075f, 0.088f), 0.55f, 0.60f); } }
        public static Material Polymer   { get { return Surface("polymer",  new Color(0.045f, 0.048f, 0.055f), 0.30f); } }
        public static Material Fabric    { get { return Surface("fabric",   new Color(0.095f, 0.098f, 0.110f), 0.12f); } }
        public static Material Skin      { get { return Surface("skin",     new Color(0.365f, 0.255f, 0.205f), 0.22f); } }

        public static Material Windows      { get { return Emissive("win_warm",  new Color(1f, 0.78f, 0.45f), 2.2f); } }
        public static Material WindowsCool  { get { return Emissive("win_cool",  new Color(0.55f, 0.80f, 1f), 2.0f); } }
        public static Material StreetLight  { get { return Emissive("lamp",      new Color(1f, 0.85f, 0.60f), 4.0f); } }
        public static Material RoadMarking  { get { return Surface ("marking",   new Color(0.55f, 0.52f, 0.42f), 0.30f); } }
        public static Material NeonCyan     { get { return Emissive("neon_cyan", UI.Theme.Cyan, 3.4f); } }
        public static Material NeonAmber    { get { return Emissive("neon_amber", UI.Theme.Amber, 3.4f); } }
        public static Material NeonPink     { get { return Emissive("neon_pink", new Color(1f, 0.30f, 0.62f), 3.4f); } }

        public static Material Accent(Color color) { return Emissive("accent_" + ColorUtility.ToHtmlStringRGB(color), color, 2.8f); }
        public static Material TeamTrim(Color color) { return Emissive("team_" + ColorUtility.ToHtmlStringRGB(color), color, 2.2f); }
    }
}
