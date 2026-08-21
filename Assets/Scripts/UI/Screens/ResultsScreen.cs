using BattleOfAgents.Core;
using BattleOfAgents.Gameplay;
using BattleOfAgents.Net;
using UnityEngine;
using UnityEngine.UI;

namespace BattleOfAgents.UI.Screens
{
    /// <summary>Post-match scoreboard with the outcome banner and per-agent rows.</summary>
    public class ResultsScreen : ScreenBase
    {
        public override ScreenId Id { get { return ScreenId.Results; } }

        protected override void Build()
        {
            Backdrop();

            var m = MatchState.Instance;
            var alpha = m != null ? m.ScoreAlpha : 0;
            var bravo = m != null ? m.ScoreBravo : 0;
            var myTeam = Session.Local.Team;
            var won = myTeam == Team.Alpha ? alpha > bravo : bravo > alpha;
            var draw = alpha == bravo;

            var bannerColor = draw ? Theme.Amber : (won ? Theme.Success : Theme.Danger);
            var bannerText = draw ? "STALEMATE" : (won ? "VICTORY" : "DEFEAT");

            var banner = UIKit.Panel(Root, Theme.WithAlpha(bannerColor, 0.14f), "Banner");
            var brt = (RectTransform)banner.transform;
            brt.anchorMin = new Vector2(0f, 0.80f);
            brt.anchorMax = new Vector2(1f, 0.98f);
            brt.offsetMin = Vector2.zero;
            brt.offsetMax = Vector2.zero;

            var bcol = UIKit.Column(banner.transform, 2f, new RectOffset(0, 0, 18, 18), "BannerBody");
            UIKit.Fill((RectTransform)bcol.transform);
            UIKit.Label(bcol.transform, bannerText, 68, bannerColor, FontStyle.Bold, TextAnchor.MiddleCenter)
                .gameObject.AddComponent<LayoutElement>().preferredHeight = 82f;
            UIKit.Label(bcol.transform, "ALPHA " + alpha + "   —   " + bravo + " BRAVO",
                26, Theme.TextMid, FontStyle.Normal, TextAnchor.MiddleCenter)
                .gameObject.AddComponent<LayoutElement>().preferredHeight = 34f;

            // --- scoreboard ------------------------------------------------------
            var panel = UIKit.Panel(Root, Theme.WithAlpha(Theme.Surface, Theme.PanelAlpha), "Board");
            var prt = (RectTransform)panel.transform;
            prt.anchorMin = new Vector2(0.06f, 0.16f);
            prt.anchorMax = new Vector2(0.94f, 0.76f);
            prt.offsetMin = Vector2.zero;
            prt.offsetMax = Vector2.zero;
            var edge = panel.gameObject.AddComponent<Outline>();
            edge.effectColor = Theme.Line;
            edge.effectDistance = new Vector2(1f, -1f);

            var col = UIKit.Column(panel.transform, 8f, new RectOffset(30, 30, 24, 24), "BoardBody");
            UIKit.Fill((RectTransform)col.transform);

            var head = UIKit.Row(col.transform, 12f, null, "Head");
            head.gameObject.AddComponent<LayoutElement>().preferredHeight = 32f;
            Cell(head.transform, "AGENT", 240f, Theme.TextLow);
            Cell(head.transform, "OPERATOR", 320f, Theme.TextLow);
            Cell(head.transform, "K", 90f, Theme.TextLow, TextAnchor.MiddleRight);
            Cell(head.transform, "D", 90f, Theme.TextLow, TextAnchor.MiddleRight);
            Cell(head.transform, "A", 90f, Theme.TextLow, TextAnchor.MiddleRight);
            Cell(head.transform, "SCORE", 140f, Theme.TextLow, TextAnchor.MiddleRight);
            UIKit.Divider(col.transform);

            if (m != null)
            {
                for (int i = 0; i < m.Scoreboard.Count; i++) ScoreRow(col.transform, m.Scoreboard[i]);
            }
            else
            {
                UIKit.Label(col.transform, "No match data.", 22, Theme.TextLow,
                    FontStyle.Italic, TextAnchor.MiddleCenter)
                    .gameObject.AddComponent<LayoutElement>().preferredHeight = 80f;
            }
            UIKit.Flex(col.transform);

            // --- actions ----------------------------------------------------------
            var bar = UIKit.Row(Root, 16f, null, "Actions");
            var arrt = (RectTransform)bar.transform;
            arrt.anchorMin = new Vector2(0.06f, 0.04f);
            arrt.anchorMax = new Vector2(0.94f, 0.13f);
            arrt.offsetMin = Vector2.zero;
            arrt.offsetMax = Vector2.zero;

            if (LobbyService.Instance.IsHost)
                UIKit.PrimaryButton(bar.transform, "Rematch",
                    () => LobbyService.Instance.StartMatch(), 82f, Theme.Cyan);

            UIKit.GhostButton(bar.transform, "Back to lobby", () => Router.Go(ScreenId.RoomLobby, false), 82f);
            UIKit.GhostButton(bar.transform, "Leave squad", () =>
            {
                LobbyService.Instance.Leave();
                Router.Go(ScreenId.MainMenu, false);
            }, 82f);
        }

        void ScoreRow(Transform parent, ScoreEntry e)
        {
            var isMe = e.PlayerId == Session.Local.PlayerId;
            var teamColor = e.Team == Team.Alpha ? Theme.TeamAlpha : Theme.TeamBravo;

            var rowRt = UIKit.Rect("Row_" + e.PlayerId, parent);
            rowRt.gameObject.AddComponent<LayoutElement>().preferredHeight = 58f;
            var bg = rowRt.gameObject.AddComponent<Image>();
            bg.color = isMe ? Theme.WithAlpha(teamColor, 0.12f) : Theme.WithAlpha(Theme.Void, 0.45f);
            bg.raycastTarget = false;

            var row = UIKit.Row(rowRt, 12f, new RectOffset(18, 18, 0, 0), "Cells");
            UIKit.Fill((RectTransform)row.transform);

            Cell(row.transform, AgentCatalog.Get(e.AgentId).Name, 240f, teamColor, TextAnchor.MiddleLeft, FontStyle.Bold);
            Cell(row.transform, e.Name + (isMe ? "  (you)" : ""), 320f, Theme.TextHi);
            Cell(row.transform, e.Kills.ToString(), 90f, Theme.TextHi, TextAnchor.MiddleRight);
            Cell(row.transform, e.Deaths.ToString(), 90f, Theme.TextMid, TextAnchor.MiddleRight);
            Cell(row.transform, e.Assists.ToString(), 90f, Theme.TextMid, TextAnchor.MiddleRight);
            Cell(row.transform, e.Score.ToString(), 140f, Theme.Amber, TextAnchor.MiddleRight, FontStyle.Bold);
        }

        static void Cell(Transform parent, string text, float width, Color color,
            TextAnchor anchor = TextAnchor.MiddleLeft, FontStyle style = FontStyle.Normal)
        {
            var t = UIKit.Label(parent, text, 23, color, style, anchor);
            var le = t.gameObject.AddComponent<LayoutElement>();
            le.preferredWidth = width;
            le.flexibleWidth = 0f;
        }
    }
}
