#if UNITY_EDITOR
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace BattleOfAgents.EditorTools
{
    /// <summary>Creates the render-pipeline assets and the boot scene from code.
    ///
    /// Doing this in a script instead of committing Unity's .asset/.unity YAML keeps
    /// the repository free of large binary-ish files that nobody can review, and means
    /// a fresh clone plus one CI run produces an identical project every time.</summary>
    public static class ProjectConfigurator
    {
        const string SettingsDir = "Assets/Settings";
        const string RendererPath = SettingsDir + "/BOA_Renderer.asset";
        const string PipelinePath = SettingsDir + "/BOA_Pipeline.asset";
        const string ScenePath = "Assets/Scenes/Boot.unity";

        [MenuItem("Battle of Agents/Configure project")]
        public static void ConfigureAll()
        {
            EnsureFolders();
            var pipeline = EnsurePipeline();
            AssignPipeline(pipeline);
            EnsureBootScene();
            AssetDatabase.SaveAssets();
            Debug.Log("[Configure] project ready");
        }

        static void EnsureFolders()
        {
            Directory.CreateDirectory(SettingsDir);
            Directory.CreateDirectory("Assets/Scenes");
            AssetDatabase.Refresh();
        }

        static UniversalRenderPipelineAsset EnsurePipeline()
        {
            var existing = AssetDatabase.LoadAssetAtPath<UniversalRenderPipelineAsset>(PipelinePath);
            if (existing != null) return existing;

            var rendererData = ScriptableObject.CreateInstance<UniversalRendererData>();
            rendererData.name = "BOA_Renderer";
            rendererData.postProcessData = ScriptableObject.CreateInstance<PostProcessData>();
            AssetDatabase.CreateAsset(rendererData, RendererPath);

            var pipeline = UniversalRenderPipelineAsset.Create(rendererData);
            pipeline.name = "BOA_Pipeline";

            // Mobile-first quality targets: one cascade, tight shadow distance, HDR on
            // (the bloom and the ACES curve need headroom above 1.0).
            pipeline.supportsHDR = true;
            pipeline.msaaSampleCount = 1;                 // FXAA in post is cheaper
            pipeline.renderScale = 1f;
            pipeline.shadowDistance = 60f;
            pipeline.shadowCascadeCount = 1;
            pipeline.supportsCameraDepthTexture = true;   // depth of field / soft particles
            pipeline.supportsCameraOpaqueTexture = false;

            AssetDatabase.CreateAsset(pipeline, PipelinePath);
            return pipeline;
        }

        static void AssignPipeline(UniversalRenderPipelineAsset pipeline)
        {
            GraphicsSettings.defaultRenderPipeline = pipeline;
            QualitySettings.renderPipeline = pipeline;

            for (int i = 0; i < QualitySettings.names.Length; i++)
            {
                QualitySettings.SetQualityLevel(i, false);
                QualitySettings.renderPipeline = pipeline;
            }
        }

        /// <summary>The boot scene is intentionally empty: <c>GameBootstrap</c> runs on
        /// <c>RuntimeInitializeOnLoadMethod</c> and constructs everything in code.</summary>
        static void EnsureBootScene()
        {
            if (File.Exists(ScenePath))
            {
                RegisterScene();
                return;
            }

            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            EditorSceneManager.SaveScene(scene, ScenePath);
            RegisterScene();
        }

        static void RegisterScene()
        {
            EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(ScenePath, true) };
        }
    }
}
#endif
