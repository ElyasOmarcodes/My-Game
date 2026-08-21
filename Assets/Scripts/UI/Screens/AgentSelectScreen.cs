using BattleOfAgents.Core;
using BattleOfAgents.Net;
using UnityEngine;
using UnityEngine.UI;

namespace BattleOfAgents.UI.Screens
{
    /// <summary>Roster page: pick an agent, read its kit, confirm. Selection is pushed
    /// to the lobby immediately so teammates see the change while they wait.</summary>
    public class AgentSelectScreen : ScreenBase
    {
        public override ScreenId Id { get { return ScreenId.AgentSelect; } }

        string _preview;

        protected override void Build()
        {
            if (string.IsNullOrEmpty(_preview)) _preview = Session.Local.AgentId;

            Backdrop();
            Header("Agents", "Pick the operator you deploy with",
                LobbyService.Instance.IsConnected ? ScreenId.RoomLobby : ScreenId.MainMenu);

            // --- roster grid ----------------------------------------------------
            var grid = UIKit.Rect("Roster", Root);
            grid.anchorMin = new Vector2(0.04f, 0.08f);
            grid.anchorMax = new Vector2(0.52f, 0.82f);
            grid.offsetMin = Vector2.zero;
            grid.offsetMax = Vector2.zero;

            var layout = grid.gameObject.AddComponent<GridLayoutGroup>();
            layout.cellSize = new Vector2(280f, 150f);
            layout.spacing = new Vector2(16f, 16f);
            layout.constraint = GridLayoutGroup.Constraint.FixedColumnCount;
            layout.constraintCount = 3;

            for (int i = 0; i < AgentCatalog.All.Count; i++) AgentCard(grid, AgentCatalog.All[i]);

            // --- detail panel ----------------------------------------------------
            var def = AgentCatalog.Get(_preview);
            var panel = UIKit.Panel(Root, Theme.WithAlpha(Theme.Surface, Theme.PanelAlpha), "Detail");
            var prt = (RectTransform)panel.transform;
            prt.anchorMin = new Vector2(0.56f, 0.08f);
            prt.anchorMax = new Vector2(0.96f, 0.82f);
            prt.offsetMin = Vector2.zero;
            prt.offsetMax = Vector2.zero;
            var edge = panel.gameObject.AddComponent<Outline>();
            edge.effectColor = Theme.WithAlpha(def.Accent, 0.5f);
            edge.effectDistance = new Vector2(1.5f, -1.5f);

            var col = UIKit.Column(panel.transform, 10f, new RectOffset(34, 34, 30, 30), "DetailBody");
            UIKit.Fill((RectTransform)col.transform);

            UIKit.Label(col.transform, def.Role.ToUpperInvariant(), 22, def.Accent, FontStyle.Bold)
                .gameObject.AddComponent<LayoutElement>().preferredHeight = 28f;
            UIKit.Label(col.transform, def.Name.ToUpperInvariant(), 62, Theme.TextHi, FontStyle.Bold)
                .gameObject.AddComponent<LayoutElement>().preferredHeight = 78f;
            UIKit.Label(col.transform, def.Blurb, 23, Theme.TextMid)
                .gameObject.AddComponent<LayoutElement>().preferredHeight = 60f;

            UIKit.Spacer(col.transform, 10f);
            UIKit.Divider(col.transform);
            UIKit.Spacer(col.transform, 10f);

            StatBar(col.transform, "HEALTH", def.Health / 130f, def.Accent, Mathf.RoundToInt(def.Health).ToString());
            StatBar(col.transform, "SPEED", def.MoveSpeed / 8f, def.Accent, def.MoveSpeed.ToString("0.0"));
            StatBar(col.transform, "FIRE RATE", def.FireRate / 12f, def.Accent, def.FireRate.ToString("0.0") + "/s");
            StatBar(col.transform, "DAMAGE", def.Damage / 70f, def.Accent, Mathf.RoundToInt(def.Damage).ToString());

            UIKit.Spacer(col.transform, 14f);
            UIKit.Label(col.transform, "SIGNATURE ABILITY", 20, Theme.TextLow, FontStyle.Bold)
                .gameObject.AddComponent<LayoutElement>().preferredHeight = 26f;
            UIKit.Label(col.transform, def.AbilityName, 30, def.Accent, FontStyle.Bold)
                .gameObject.AddComponent<LayoutElement>().preferredHeight = 40f;
            UIKit.Label(col.transform, def.AbilityDesc, 22, Theme.TextMid)
                .gameObject.AddComponent<LayoutElement>().preferredHeight = 50f;

            UIKit.Flex(col.transform);

            var isCurrent = Session.Local.AgentId == def.Id;
            var confirm = UIKit.PrimaryButton(col.transform,
                isCurrent ? "Deployed agent" : "Select " + def.Name,
                () => Select(def.Id), 84f, isCurrent ? Theme.Success : def.Accent);
            confirm.interactable = !isCurrent;
        }

        void AgentCard(Transform parent, AgentDef def)
        {
            var selected = def.Id == _preview;
            var equipped = def.Id == Session.Local.AgentId;

            var cardRt = UIKit.Rect("Agent_" + def.Id, parent);
            var bg = cardRt.gameObject.AddComponent<Image>();
            bg.color = selected
                ? Theme.WithAlpha(def.Accent, 0.16f)
                : Theme.WithAlpha(Theme.SurfaceAlt, 0.85f);

            var edge = cardRt.gameObject.AddComponent<Outline>();
            edge.effectColor = selected ? def.Accent : Theme.Line;
            edge.effectDistance = new Vector2(1.5f, -1.5f);

            var col = UIKit.Column(cardRt, 4f, new RectOffset(18, 18, 16, 16), "CardBody");
            UIKit.Fill((RectTransform)col.transform);

            UIKit.Label(col.transform, def.Role.ToUpperInvariant(), 18, Theme.TextLow, FontStyle.Bold)
                .gameObject.AddComponent<LayoutElement>().preferredHeight = 24f;
            UIKit.Label(col.transform, def.Name.ToUpperInvariant(), 34,
                selected ? def.Accent : Theme.TextHi, FontStyle.Bold)
                .gameObject.AddComponent<LayoutElement>().preferredHeight = 44f;
            UIKit.Flex(col.transform);
            UIKit.Label(col.transform, equipped ? "EQUIPPED" : def.AbilityName, 19,
                equipped ? Theme.Success : Theme.TextMid)
                .gameObject.AddComponent<LayoutElement>().preferredHeight = 26f;

            var btn = cardRt.gameObject.AddComponent<Button>();
            btn.targetGraphic = bg;
            btn.onClick.AddListener(() => { _preview = def.Id; Rebuild(); });
        }

        void Select(string agentId)
        {
            Session.Local.AgentId = agentId;
            LobbyService.Instance.SetAgent(agentId);
            PlayerPrefs.SetString("boa.agent", agentId);
            PlayerPrefs.Save();
            Rebuild();
        }

        static void StatBar(Transform parent, string label, float t01, Color color, string value)
        {
            var row = UIKit.Row(parent, 10f, null, "Stat_" + label);
            row.gameObject.AddComponent<LayoutElement>().preferredHeight = 34f;

            var l = UIKit.Label(row.transform, label, 20, Theme.TextLow, FontStyle.Bold);
            l.gameObject.AddComponent<LayoutElement>().preferredWidth = 150f;

            var barHolder = UIKit.Rect("BarHolder", row.transform);
            barHolder.gameObject.AddComponent<LayoutElement>().flexibleWidth = 1f;
            var inner = UIKit.Column(barHolder, 0f, new RectOffset(0, 0, 13, 13));
            UIKit.Fill((RectTransform)inner.transform);
            UIKit.Bar(inner.transform, Mathf.Clamp01(t01), color, 8f);

            var v = UIKit.Label(row.transform, value, 20, Theme.TextHi,
                FontStyle.Normal, TextAnchor.MiddleRight);
            v.gameObject.AddComponent<LayoutElement>().preferredWidth = 110f;
        }
    }
}
