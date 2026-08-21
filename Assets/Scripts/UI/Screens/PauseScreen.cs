using BattleOfAgents.Core;
using BattleOfAgents.Gameplay;
using BattleOfAgents.Net;
using UnityEngine;
using UnityEngine.UI;

namespace BattleOfAgents.UI.Screens
{
    /// <summary>Mid-match menu. Time keeps running for everyone else — this is a LAN
    /// match, so pausing is local only, and the copy says so.</summary>
    public class PauseScreen : ScreenBase
    {
        public override ScreenId Id { get { return ScreenId.Pause; } }

        protected override void Build()
        {
            var dim = UIKit.Panel(Root, Theme.WithAlpha(Theme.Void, 0.86f), "Dim");
            UIKit.Fill((RectTransform)dim.transform);

            var panel = UIKit.Panel(Root, Theme.WithAlpha(Theme.Surface, 0.95f), "PausePanel");
            var prt = (RectTransform)panel.transform;
            prt.anchorMin = prt.anchorMax = new Vector2(0.5f, 0.5f);
            prt.pivot = new Vector2(0.5f, 0.5f);
            prt.sizeDelta = new Vector2(720f, 620f);
            var edge = panel.gameObject.AddComponent<Outline>();
            edge.effectColor = Theme.Line;
            edge.effectDistance = new Vector2(1f, -1f);

            var col = UIKit.Column(panel.transform, 14f, new RectOffset(44, 44, 40, 40), "PauseBody");
            UIKit.Fill((RectTransform)col.transform);

            UIKit.Label(col.transform, "PAUSED", 52, Theme.TextHi, FontStyle.Bold, TextAnchor.MiddleCenter)
                .gameObject.AddComponent<LayoutElement>().preferredHeight = 66f;
            UIKit.Label(col.transform, "The match keeps running — your squad still needs you.",
                22, Theme.TextMid, FontStyle.Normal, TextAnchor.MiddleCenter)
                .gameObject.AddComponent<LayoutElement>().preferredHeight = 34f;

            UIKit.Spacer(col.transform, 16f);
            UIKit.Divider(col.transform);
            UIKit.Spacer(col.transform, 16f);

            var m = MatchState.Instance;
            InfoRow(col.transform, "MAP", m != null ? m.MapName : Session.SelectedMap);
            InfoRow(col.transform, "TIME LEFT", m != null ? MatchState.Clock(m.TimeRemaining) : "—");
            InfoRow(col.transform, "HOST", LobbyService.Instance.State.hostName ?? "—");
            InfoRow(col.transform, "PING", "12 ms  ·  LAN");

            UIKit.Flex(col.transform);

            UIKit.PrimaryButton(col.transform, "Resume", () => Router.Go(ScreenId.Hud, false), 84f, Theme.Cyan);
            UIKit.GhostButton(col.transform, "Settings", () => Router.Go(ScreenId.Settings), 68f);
            UIKit.PrimaryButton(col.transform, "Leave match", () =>
            {
                LobbyService.Instance.Leave();
                Router.Go(ScreenId.MainMenu, false);
            }, 68f, Theme.Danger);
        }

        static void InfoRow(Transform parent, string key, string value)
        {
            var row = UIKit.Row(parent, 10f, null, "Info_" + key);
            row.gameObject.AddComponent<LayoutElement>().preferredHeight = 38f;
            UIKit.Label(row.transform, key, 21, Theme.TextLow, FontStyle.Bold);
            UIKit.Label(row.transform, value, 23, Theme.TextHi, FontStyle.Normal, TextAnchor.MiddleRight);
        }
    }
}
