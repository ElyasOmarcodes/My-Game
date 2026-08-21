#if UNITY_EDITOR
using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;

namespace BattleOfAgents.EditorTools
{
    /// <summary>Head-less Android build entry point used by CI.
    ///
    ///   Unity -batchmode -quit -projectPath . \
    ///         -executeMethod BattleOfAgents.EditorTools.BuildScript.BuildAndroid
    ///
    /// Every player setting that affects APK size is set here rather than in
    /// ProjectSettings.asset, so the build is reproducible from a clean clone.</summary>
    public static class BuildScript
    {
        const string OutputDir = "build/android";
        const string ApkName = "BattleOfAgents.apk";

        public static void BuildAndroid()
        {
            ProjectConfigurator.ConfigureAll();
            ApplySizeSettings();

            Directory.CreateDirectory(OutputDir);
            var apkPath = Path.Combine(OutputDir, ApkName);

            var options = new BuildPlayerOptions
            {
                scenes = ScenePaths(),
                locationPathName = apkPath,
                target = BuildTarget.Android,
                targetGroup = BuildTargetGroup.Android,
                options = BuildOptions.CompressWithLz4HC   // smallest runtime archive
            };

            if (IsDevelopmentBuild()) options.options |= BuildOptions.Development;

            var report = BuildPipeline.BuildPlayer(options);
            var summary = report.summary;

            Debug.Log("[Build] result=" + summary.result +
                      " size=" + (summary.totalSize / 1024f / 1024f).ToString("0.00") + " MB" +
                      " errors=" + summary.totalErrors +
                      " time=" + summary.totalTime);

            if (summary.result != BuildResult.Succeeded)
            {
                Debug.LogError("[Build] FAILED");
                EditorApplication.Exit(1);
                return;
            }
            EditorApplication.Exit(0);
        }

        /// <summary>Everything that shrinks the APK. Ordered roughly by impact.</summary>
        static void ApplySizeSettings()
        {
            // 64-bit only: halves the native payload versus a fat APK, and Play
            // Store has required arm64 since 2019 anyway.
            PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64;
            PlayerSettings.SetScriptingBackend(BuildTargetGroup.Android, ScriptingImplementation.IL2CPP);
            PlayerSettings.SetApiCompatibilityLevel(BuildTargetGroup.Android, ApiCompatibilityLevel.NET_Standard_2_0);
            PlayerSettings.SetManagedStrippingLevel(BuildTargetGroup.Android, ManagedStrippingLevel.High);
            PlayerSettings.stripEngineCode = true;
            PlayerSettings.stripUnusedMeshComponents = true;

            PlayerSettings.SetIl2CppCompilerConfiguration(BuildTargetGroup.Android,
                Il2CppCompilerConfiguration.Master);            // optimise for size+speed
#if UNITY_2021_2_OR_NEWER
            PlayerSettings.SetIl2CppCodeGeneration(UnityEditor.Build.NamedBuildTarget.Android,
                UnityEditor.Build.Il2CppCodeGeneration.OptimizeSize);
#endif

            // Texture / asset compression
            EditorUserBuildSettings.androidBuildSubtarget = MobileTextureSubtarget.ASTC;
            EditorUserBuildSettings.androidCreateSymbols = AndroidCreateSymbols.Disabled;
            EditorUserBuildSettings.buildAppBundle = false;      // we ship a single APK

            // Runtime trimming
            PlayerSettings.Android.androidTVCompatibility = false;
            PlayerSettings.Android.forceInternetPermission = false;
            PlayerSettings.Android.forceSDCardPermission = false;
            PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel24;
            PlayerSettings.Android.optimizedFramePacing = true;
            PlayerSettings.gpuSkinning = true;
            PlayerSettings.MTRendering = true;

            PlayerSettings.companyName = "Elyas Omar";
            PlayerSettings.productName = "Battle of Agents";
            PlayerSettings.applicationIdentifier = "com.elyasomar.battleofagents";
            PlayerSettings.bundleVersion = Version();
            PlayerSettings.Android.bundleVersionCode = BuildNumber();

            PlayerSettings.defaultInterfaceOrientation = UIOrientation.LandscapeLeft;
            PlayerSettings.allowedAutorotateToPortrait = false;
            PlayerSettings.allowedAutorotateToPortraitUpsideDown = false;
            PlayerSettings.allowedAutorotateToLandscapeLeft = true;
            PlayerSettings.allowedAutorotateToLandscapeRight = true;

            PlayerSettings.colorSpace = ColorSpace.Linear;
            PlayerSettings.SetGraphicsAPIs(BuildTarget.Android, new[]
            {
                UnityEngine.Rendering.GraphicsDeviceType.Vulkan,
                UnityEngine.Rendering.GraphicsDeviceType.OpenGLES3
            });

            ApplyKeystore();
        }

        /// <summary>Debug-key signing.
        ///
        /// Unity's built-in debug keystore is used deliberately: the APK installs on
        /// any phone with "unknown sources" enabled, and nobody has to manage a
        /// release key to test a build. Swap to a custom keystore only when the game
        /// is going to the Play Store — Google will not accept a debug-signed upload.</summary>
        static void ApplyKeystore()
        {
            PlayerSettings.Android.useCustomKeystore = false;
            PlayerSettings.Android.keystoreName = string.Empty;
            PlayerSettings.Android.keyaliasName = string.Empty;
            Debug.Log("[Build] signing with Unity's debug key (sideload-ready, not Play Store-ready)");
        }

        static string[] ScenePaths()
        {
            var scenes = EditorBuildSettings.scenes
                .Where(s => s.enabled)
                .Select(s => s.path)
                .ToArray();

            if (scenes.Length > 0) return scenes;

            // The game builds its content at runtime, so a single (empty) boot scene
            // is all the player needs.
            const string boot = "Assets/Scenes/Boot.unity";
            if (File.Exists(boot)) return new[] { boot };

            Debug.LogWarning("[Build] no scenes found — building with an empty scene list");
            return new string[0];
        }

        static bool IsDevelopmentBuild()
        {
            return Environment.GetEnvironmentVariable("BOA_DEV_BUILD") == "1";
        }

        static string Version()
        {
            var v = Environment.GetEnvironmentVariable("BOA_VERSION");
            return string.IsNullOrEmpty(v) ? "0.1.0" : v;
        }

        static int BuildNumber()
        {
            var raw = Environment.GetEnvironmentVariable("BOA_BUILD_NUMBER");
            int parsed;
            return int.TryParse(raw, out parsed) && parsed > 0 ? parsed : 1;
        }
    }
}
#endif
