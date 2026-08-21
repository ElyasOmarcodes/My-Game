using BattleOfAgents.Core;
using UnityEngine;
using UnityEngine.UI;

namespace BattleOfAgents.UI.Screens
{
    /// <summary>Hub page. Left column = actions, right column = the local agent card
    /// and the current Wi-Fi status (the game is LAN-only, so that status matters).</summary>
    public class MainMenuScreen : ScreenBase
    {
        public override ScreenId Id { get { return ScreenId.MainMenu; } }

        protected override void Build()
        {
            Backdrop();

            // --- left: identity + actions -----------------------------------
            var left = UIKit.Column(Root, 16f, new RectOffset(0, 0, 0, 0), "Actions");
            var lrt = (RectTransform)left.transform;
            lrt.anchorMin = new Vector2(0f, 0f);
            lrt.anchorMax = new Vector2(0.45f, 1f);
            lrt.offsetMin = new Vector2(Theme.Gutter * 2f, Theme.Gutter * 2f);
            lrt.offsetMax = new Vector2(-Theme.Gutter, -Theme.Gutter * 2f);

            UIKit.Label(left.transform, "// B O A", 24, Theme.Cyan, FontStyle.Bold)
                .gameObject.AddComponent<LayoutElement>().preferredHeight = 30f;
            UIKit.Label(left.transform, GameConfig.GameName, 66, Theme.TextHi, FontStyle.Bold)
                .gameObject.AddComponent<LayoutElement>().preferredHeight = 84f;
            UIKit.Label(left.transform, "Wi-Fi squad combat  ·  2-8 agents", 24, Theme.TextMid)
                .gameObject.AddComponent<LayoutElement>().preferredHeight = 32f;

            UIKit.Spacer(left.transform, 26f);

            UIKit.PrimaryButton(left.transform, "Host a squad",
                () => Router.Go(ScreenId.CreateRoom), 88f, Theme.Cyan);
            UIKit.PrimaryButton(left.transform, "Join over Wi-Fi",
                () => Router.Go(ScreenId.LanBrowser), 88f, Theme.Amber);
            UIKit.GhostButton(left.transform, "Agents & loadout",
                () => Router.Go(ScreenId.AgentSelect), 72f);
            // Lets one person check the build without a second phone on the network.
            UIKit.GhostButton(left.transform, "Solo drill", StartSoloDrill, 72f);
            UIKit.GhostButton(left.transform, "Settings",
                () => Router.Go(ScreenId.Settings), 72f);

            UIKit.Flex(left.transform);
            UIKit.Label(left.transform, "v" + GameConfig.GameVersion +
                "  ·  no internet required", 20, Theme.TextLow)
                .gameObject.AddComponent<LayoutElement>().preferredHeight = 26f;

            // --- right: agent card ------------------------------------------
            var cardBg = UIKit.Panel(Root, Theme.WithAlpha(Theme.Surface, Theme.PanelAlpha), "AgentCard");
            var crt = (RectTransform)cardBg.transform;
            crt.anchorMin = new Vector2(0.47f, 0f);
            crt.anchorMax = new Vector2(1f, 1f);
            crt.offsetMin = new Vector2(0f, Theme.Gutter * 2f);
            crt.offsetMax = new Vector2(-Theme.Gutter * 2f, -Theme.Gutter * 2f);

            var edge = cardBg.gameObject.AddComponent<Outline>();
            edge.effectColor = Theme.Line;
            edge.effectDistance = new Vector2(1f, -1f);

            var card = UIKit.Column(cardBg.transform, 14f, new RectOffset(36, 36, 36, 36), "CardBody");
            UIKit.Fill((RectTransform)card.transform);

            UIKit.Label(card.transform, "OPERATOR", 22, Theme.TextLow, FontStyle.Bold)
                .gameObject.AddComponent<LayoutElement>().preferredHeight = 28f;
            UIKit.Label(card.transform, Session.Local.DisplayName, 54, Theme.TextHi, FontStyle.Bold)
                .gameObject.AddComponent<LayoutElement>().preferredHeight = 70f;

            var agent = AgentCatalog.Get(Session.Local.AgentId);
            UIKit.Label(card.transform, agent.Name.ToUpperInvariant() + "  ·  " + agent.Role,
                26, Theme.Cyan).gameObject.AddComponent<LayoutElement>().preferredHeight = 34f;

            UIKit.Spacer(card.transform, 10f);
            UIKit.Divider(card.transform);
            UIKit.Spacer(card.transform, 10f);

            StatRow(card.transform, "LEVEL", Session.Local.Level.ToString(), Theme.TextHi);
            StatRow(card.transform, "XP", Session.Local.Xp + " / 1200", Theme.Amber);
            StatRow(card.transform, "NETWORK", NetworkStatusLine(), Theme.Success);
            StatRow(card.transform, "LOCAL IP", LanUtility.LocalIPv4(), Theme.TextMid);

            UIKit.Spacer(card.transform, 18f);
            UIKit.Label(card.transform, agent.Blurb, 22, Theme.TextMid)
                .gameObject.AddComponent<LayoutElement>().preferredHeight = 60f;

            UIKit.Flex(card.transform);
            UIKit.GhostButton(card.transform, "Change agent",
                () => Router.Go(ScreenId.AgentSelect), 64f);
        }

        void StartSoloDrill()
        {
            Session.Local.Team = Team.Alpha;
            Gameplay.MatchController.Instance.Begin(Session.SelectedMap,
                Session.SelectedMode, UnityEngine.Random.Range(1, int.MaxValue));
        }

        static string NetworkStatusLine()
        {
            switch (Application.internetReachability)
            {
                case NetworkReachability.ReachableViaLocalAreaNetwork: return "WI-FI CONNECTED";
                case NetworkReachability.ReachableViaCarrierDataNetwork: return "MOBILE DATA (LAN NEEDED)";
                default: return "OFFLINE — ENABLE WI-FI";
            }
        }

        static void StatRow(Transform parent, string key, string value, Color valueColor)
        {
            var row = UIKit.Row(parent, 12f, null, "Stat_" + key);
            row.gameObject.AddComponent<LayoutElement>().preferredHeight = 40f;
            UIKit.Label(row.transform, key, 22, Theme.TextLow, FontStyle.Bold);
            UIKit.Label(row.transform, value, 24, valueColor, FontStyle.Normal, TextAnchor.MiddleRight);
        }
    }
}
