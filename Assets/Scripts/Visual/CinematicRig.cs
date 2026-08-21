using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace BattleOfAgents.Visual
{
    /// <summary>Builds the camera and the full-screen post-processing stack in code.
    /// This is what gives the game its "cinematic" look: filmic tonemapping, bloom
    /// on emissive tech surfaces, a cool-shadow / warm-highlight split, gentle grain
    /// and a vignette — all tuned to stay cheap enough for mobile GPUs.</summary>
    [DisallowMultipleComponent]
    public class CinematicRig : MonoBehaviour
    {
        public static CinematicRig Instance { get; private set; }

        public Camera MainCamera { get; private set; }
        public Volume Volume { get; private set; }

        VolumeProfile _profile;
        Vignette _vignette;
        ChromaticAberration _aberration;
        FilmGrain _grain;
        ColorAdjustments _color;

        // camera-shake state
        float _shakeAmplitude;
        float _shakeDecay = 6f;
        Vector3 _basePosition;

        void Awake()
        {
            Instance = this;
            BuildCamera();
            BuildPostProcessing();
        }

        void BuildCamera()
        {
            var go = new GameObject("CinematicCamera", typeof(Camera), typeof(AudioListener));
            go.transform.SetParent(transform, false);
            go.transform.position = new Vector3(0f, 6f, -9f);
            go.transform.rotation = Quaternion.Euler(22f, 0f, 0f);
            _basePosition = go.transform.localPosition;

            MainCamera = go.GetComponent<Camera>();
            MainCamera.tag = "MainCamera";
            MainCamera.clearFlags = CameraClearFlags.SolidColor;
            MainCamera.backgroundColor = new Color(0.02f, 0.027f, 0.047f, 1f);
            MainCamera.fieldOfView = 62f;
            MainCamera.nearClipPlane = 0.05f;
            MainCamera.farClipPlane = 260f;
            MainCamera.allowHDR = true;
            MainCamera.allowMSAA = false;   // post-processing handles edges cheaper

            var data = MainCamera.GetUniversalAdditionalCameraData();
            if (data != null)
            {
                data.renderPostProcessing = true;
                data.antialiasing = AntialiasingMode.FastApproximateAntialiasing;
                data.renderShadows = true;
            }
        }

        void BuildPostProcessing()
        {
            var go = new GameObject("GlobalVolume");
            go.transform.SetParent(transform, false);

            Volume = go.AddComponent<Volume>();
            Volume.isGlobal = true;
            Volume.priority = 10f;

            _profile = ScriptableObject.CreateInstance<VolumeProfile>();
            _profile.name = "BOA_Cinematic";
            Volume.sharedProfile = _profile;

            var tonemap = _profile.Add<Tonemapping>(true);
            tonemap.mode.overrideState = true;
            tonemap.mode.value = TonemappingMode.ACES;          // filmic contrast roll-off

            var bloom = _profile.Add<Bloom>(true);
            bloom.intensity.overrideState = true;
            bloom.intensity.value = 1.25f;
            bloom.threshold.overrideState = true;
            bloom.threshold.value = 1.05f;
            bloom.scatter.overrideState = true;
            bloom.scatter.value = 0.68f;
            bloom.tint.overrideState = true;
            bloom.tint.value = new Color(0.55f, 0.85f, 1f);
            bloom.highQualityFiltering.overrideState = true;
            bloom.highQualityFiltering.value = false;           // mobile budget

            _color = _profile.Add<ColorAdjustments>(true);
            _color.postExposure.overrideState = true;
            _color.postExposure.value = 0.15f;
            _color.contrast.overrideState = true;
            _color.contrast.value = 16f;
            _color.saturation.overrideState = true;
            _color.saturation.value = -6f;

            var split = _profile.Add<SplitToning>(true);
            split.shadows.overrideState = true;
            split.shadows.value = new Color(0.16f, 0.42f, 0.62f);  // cool shadows
            split.highlights.overrideState = true;
            split.highlights.value = new Color(0.72f, 0.55f, 0.30f); // warm highlights
            split.balance.overrideState = true;
            split.balance.value = -12f;

            _vignette = _profile.Add<Vignette>(true);
            _vignette.intensity.overrideState = true;
            _vignette.intensity.value = 0.32f;
            _vignette.smoothness.overrideState = true;
            _vignette.smoothness.value = 0.45f;

            _aberration = _profile.Add<ChromaticAberration>(true);
            _aberration.intensity.overrideState = true;
            _aberration.intensity.value = 0.06f;

            _grain = _profile.Add<FilmGrain>(true);
            _grain.type.overrideState = true;
            _grain.type.value = FilmGrainLookup.Thin1;
            _grain.intensity.overrideState = true;
            _grain.intensity.value = 0.22f;
            _grain.response.overrideState = true;
            _grain.response.value = 0.8f;
        }

        // --- juice ------------------------------------------------------------

        /// <summary>Kick the camera — call on explosions, heavy hits, ability casts.</summary>
        public void Shake(float amplitude, float decay = 6f)
        {
            _shakeAmplitude = Mathf.Max(_shakeAmplitude, amplitude);
            _shakeDecay = decay;
        }

        /// <summary>Red-shift + tighter vignette while the local player is hurt.</summary>
        public void SetDamageState(float t01)
        {
            if (_vignette == null) return;
            _vignette.intensity.value = Mathf.Lerp(0.32f, 0.62f, t01);
            _vignette.color.overrideState = true;
            _vignette.color.value = Color.Lerp(Color.black, new Color(0.6f, 0.05f, 0.1f), t01);
            _aberration.intensity.value = Mathf.Lerp(0.06f, 0.55f, t01);
            _color.saturation.value = Mathf.Lerp(-6f, -35f, t01);
        }

        void LateUpdate()
        {
            if (MainCamera == null) return;

            if (_shakeAmplitude > 0.0001f)
            {
                var offset = new Vector3(
                    (Mathf.PerlinNoise(Time.time * 37f, 0f) - 0.5f),
                    (Mathf.PerlinNoise(0f, Time.time * 41f) - 0.5f),
                    0f) * _shakeAmplitude;

                MainCamera.transform.localPosition = _basePosition + offset;
                _shakeAmplitude = Mathf.Lerp(_shakeAmplitude, 0f, Time.unscaledDeltaTime * _shakeDecay);
            }
            else if (MainCamera.transform.localPosition != _basePosition)
            {
                MainCamera.transform.localPosition = _basePosition;
            }
        }
    }
}
