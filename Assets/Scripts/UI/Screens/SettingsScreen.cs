using BattleOfAgents.Core;
using UnityEngine;
using UnityEngine.UI;

namespace BattleOfAgents.UI.Screens
{
    /// <summary>Player identity plus the graphics/performance switches that matter on
    /// Android: quality tier, frame cap, post-processing and haptics.</summary>
    public class SettingsScreen : ScreenBase
    {
        public override ScreenId Id { get { return ScreenId.Settings; } }

        static readonly string[] QualityTiers = { "Performance", "Balanced", "Cinematic" };
        static readonly string[] FrameCaps = { "30 fps", "60 fps", "90 fps" };

        InputField _nameField;
        Text _qualityLabel, _fpsLabel, _postLabel, _hapticsLabel;

        int _quality = 2;
        int _fps = 1;
        bool _post = true;
        bool _haptics = true;

        protected override void Build()
        {
            LoadPrefs();
            Backdrop();
            Header("Settings", "Tune identity, visuals and performance", ScreenId.MainMenu);

            var panel = UIKit.Panel(Root, Theme.WithAlpha(Theme.Surface, Theme.PanelAlpha), "Settings");
            var prt = (RectTransform)panel.transform;
            prt.anchorMin = new Vector2(0.08f, 0.10f);
            prt.anchorMax = new Vector2(0.62f, 0.82f);
            prt.offsetMin = Vector2.zero;
            prt.offsetMax = Vector2.zero;
            var edge = panel.gameObject.AddComponent<Outline>();
            edge.effectColor = Theme.Line;
            edge.effectDistance = new Vector2(1f, -1f);

            var col = UIKit.Column(panel.transform, 12f, new RectOffset(36, 36, 30, 30), "Body");
            UIKit.Fill((RectTransform)col.transform);

            Caption(col.transform, "CALLSIGN");
            _nameField = UIKit.TextField(col.transform, "Your name in the lobby", Session.Local.DisplayName);
            _nameField.onEndEdit.AddListener(SaveName);

            UIKit.Spacer(col.transform, 10f);
            Caption(col.transform, "GRAPHICS TIER");
            _qualityLabel = Toggle(col.transform, QualityTiers[_quality], () =>
            {
                _quality = (_quality + 1) % QualityTiers.Length;
                _qualityLabel.text = QualityTiers[_quality];
                ApplyQuality();
            });

            Caption(col.transform, "FRAME RATE");
            _fpsLabel = Toggle(col.transform, FrameCaps[_fps], () =>
            {
                _fps = (_fps + 1) % FrameCaps.Length;
                _fpsLabel.text = FrameCaps[_fps];
                ApplyQuality();
            });

            Caption(col.transform, "CINEMATIC POST-PROCESSING");
            _postLabel = Toggle(col.transform, _post ? "On" : "Off", () =>
            {
                _post = !_post;
                _postLabel.text = _post ? "On" : "Off";
                ApplyQuality();
            });

            Caption(col.transform, "HAPTICS");
            _hapticsLabel = Toggle(col.transform, _haptics ? "On" : "Off", () =>
            {
                _haptics = !_haptics;
                _hapticsLabel.text = _haptics ? "On" : "Off";
                Save();
            });

            UIKit.Flex(col.transform);
            UIKit.PrimaryButton(col.transform, "Save and go back", () =>
            {
                Save();
                Router.Back();
            }, 84f, Theme.Cyan);

            // --- diagnostics side panel -------------------------------------------
            var side = UIKit.Column(Root, 10f, null, "Diag");
            var srt = (RectTransform)side.transform;
            srt.anchorMin = new Vector2(0.66f, 0.10f);
            srt.anchorMax = new Vector2(0.92f, 0.82f);
            srt.offsetMin = Vector2.zero;
            srt.offsetMax = Vector2.zero;

            Caption(side.transform, "DEVICE");
            Info(side.transform, "MODEL", SystemInfo.deviceModel);
            Info(side.transform, "GPU", SystemInfo.graphicsDeviceName);
            Info(side.transform, "MEMORY", SystemInfo.systemMemorySize + " MB");
            Info(side.transform, "LOCAL IP", Net.LanUtility.LocalIPv4());
            Info(side.transform, "BUILD", GameConfig.GameVersion + " (" + GameConfig.ProtocolId + ")");
        }

        void SaveName(string value)
        {
            if (string.IsNullOrEmpty(value)) return;
            Session.Local.DisplayName = value;
            PlayerPrefs.SetString("boa.playername", value);
        }

        void ApplyQuality()
        {
            Application.targetFrameRate = _fps == 0 ? 30 : (_fps == 1 ? 60 : 90);
            QualitySettings.SetQualityLevel(Mathf.Clamp(_quality, 0, QualitySettings.names.Length - 1), true);
            QualitySettings.shadowDistance = _quality == 0 ? 25f : (_quality == 1 ? 45f : 70f);

            var rig = Visual.CinematicRig.Instance;
            if (rig != null && rig.Volume != null) rig.Volume.weight = _post ? 1f : 0f;
            Save();
        }

        void Save()
        {
            PlayerPrefs.SetInt("boa.quality", _quality);
            PlayerPrefs.SetInt("boa.fps", _fps);
            PlayerPrefs.SetInt("boa.post", _post ? 1 : 0);
            PlayerPrefs.SetInt("boa.haptics", _haptics ? 1 : 0);
            PlayerPrefs.Save();
        }

        void LoadPrefs()
        {
            _quality = PlayerPrefs.GetInt("boa.quality", 2);
            _fps = PlayerPrefs.GetInt("boa.fps", 1);
            _post = PlayerPrefs.GetInt("boa.post", 1) == 1;
            _haptics = PlayerPrefs.GetInt("boa.haptics", 1) == 1;
        }

        static void Caption(Transform parent, string text)
        {
            UIKit.Label(parent, text, 20, Theme.TextLow, FontStyle.Bold)
                .gameObject.AddComponent<LayoutElement>().preferredHeight = 26f;
        }

        static void Info(Transform parent, string key, string value)
        {
            var row = UIKit.Row(parent, 10f, null, "Info_" + key);
            row.gameObject.AddComponent<LayoutElement>().preferredHeight = 36f;
            UIKit.Label(row.transform, key, 20, Theme.TextLow, FontStyle.Bold);
            UIKit.Label(row.transform, value, 21, Theme.TextMid, FontStyle.Normal, TextAnchor.MiddleRight);
        }

        static Text Toggle(Transform parent, string value, System.Action onNext)
        {
            var rt = UIKit.Rect("Toggle", parent);
            rt.gameObject.AddComponent<LayoutElement>().preferredHeight = 70f;

            var bg = rt.gameObject.AddComponent<Image>();
            bg.color = Theme.WithAlpha(Theme.Void, 0.85f);
            var outline = rt.gameObject.AddComponent<Outline>();
            outline.effectColor = Theme.Line;
            outline.effectDistance = new Vector2(1f, -1f);

            var label = UIKit.Label(rt, value, 27, Theme.TextHi);
            var lrt = UIKit.Fill((RectTransform)label.transform, 18f);
            lrt.offsetMax = new Vector2(-70f, lrt.offsetMax.y);

            var chevron = UIKit.Label(rt, ">", 28, Theme.Cyan, FontStyle.Bold, TextAnchor.MiddleRight);
            UIKit.Fill((RectTransform)chevron.transform, 18f);

            var btn = rt.gameObject.AddComponent<Button>();
            btn.targetGraphic = bg;
            btn.onClick.AddListener(() => onNext());
            return label;
        }
    }
}
