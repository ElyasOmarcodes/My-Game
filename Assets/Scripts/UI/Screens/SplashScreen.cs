using BattleOfAgents.Core;
using UnityEngine;
using UnityEngine.UI;

namespace BattleOfAgents.UI.Screens
{
    /// <summary>Boot page: logo lockup, a determinate loading bar and the build stamp.</summary>
    public class SplashScreen : ScreenBase
    {
        public override ScreenId Id { get { return ScreenId.Splash; } }

        Image _bar;
        Text _status;
        float _progress;

        static readonly string[] Steps =
        {
            "INITIALISING RENDER PIPELINE",
            "LOADING AGENT ROSTER",
            "BINDING NETWORK INTERFACE",
            "SCANNING WI-FI ADAPTER",
            "READY"
        };

        protected override void Build()
        {
            Backdrop();

            var center = UIKit.Column(Root, 18f, new RectOffset(0, 0, 0, 0), "Center");
            var crt = (RectTransform)center.transform;
            crt.anchorMin = new Vector2(0.5f, 0.5f);
            crt.anchorMax = new Vector2(0.5f, 0.5f);
            crt.pivot = new Vector2(0.5f, 0.5f);
            crt.sizeDelta = new Vector2(900f, 320f);

            var mark = UIKit.Label(center.transform, "// B O A", 26, Theme.Cyan,
                FontStyle.Bold, TextAnchor.MiddleCenter);
            mark.gameObject.AddComponent<LayoutElement>().preferredHeight = 34f;

            var title = UIKit.Label(center.transform, GameConfig.GameName, 88, Theme.TextHi,
                FontStyle.Bold, TextAnchor.MiddleCenter);
            title.gameObject.AddComponent<LayoutElement>().preferredHeight = 110f;

            var sub = UIKit.Label(center.transform, "T A C T I C A L   S K I R M I S H", 24,
                Theme.TextMid, FontStyle.Normal, TextAnchor.MiddleCenter);
            sub.gameObject.AddComponent<LayoutElement>().preferredHeight = 32f;

            UIKit.Spacer(center.transform, 28f);
            _bar = UIKit.Bar(center.transform, 0f, Theme.Cyan, 6f);

            _status = UIKit.Label(center.transform, Steps[0], 22, Theme.TextLow,
                FontStyle.Normal, TextAnchor.MiddleCenter);
            _status.gameObject.AddComponent<LayoutElement>().preferredHeight = 30f;

            var stamp = UIKit.Label(Root, "build " + GameConfig.GameVersion +
                "  ·  proto " + GameConfig.ProtocolId, 20, Theme.TextLow);
            var srt = (RectTransform)stamp.transform;
            srt.anchorMin = new Vector2(0f, 0f);
            srt.anchorMax = new Vector2(0f, 0f);
            srt.pivot = new Vector2(0f, 0f);
            srt.anchoredPosition = new Vector2(Theme.Gutter * 2f, Theme.Gutter);
        }

        public override void OnShow()
        {
            _progress = 0f;
        }

        void Update()
        {
            if (Router == null || Router.Current != Id || _bar == null) return;

            _progress = Mathf.Min(1f, _progress + Time.unscaledDeltaTime * 0.55f);
            var frt = (RectTransform)_bar.transform;
            frt.anchorMax = new Vector2(_progress, 1f);

            var step = Mathf.Clamp(Mathf.FloorToInt(_progress * Steps.Length), 0, Steps.Length - 1);
            _status.text = Steps[step];

            if (_progress >= 1f) Router.Go(ScreenId.MainMenu, false);
        }
    }
}
