using BattleOfAgents.Core;
using BattleOfAgents.Gameplay;
using UnityEngine;
using UnityEngine.UI;

namespace BattleOfAgents.UI.Screens
{
    /// <summary>In-match overlay. Deliberately sparse in the centre — the readable
    /// area of a phone in landscape — with vitals bottom-left and objective top-centre.</summary>
    public class HudScreen : ScreenBase
    {
        public override ScreenId Id { get { return ScreenId.Hud; } }

        Text _clock, _scoreA, _scoreB, _health, _ammo, _streak;
        Image _healthBar, _shieldBar, _abilityBar;
        RectTransform _feed;

        protected override void Build()
        {
            // no Backdrop() here: the 3D scene renders behind the HUD

            TopBar();
            Vitals();
            KillFeed();
            TouchControls();
            Crosshair();

            var pause = UIKit.Rect("PauseHolder", Root);
            pause.anchorMin = new Vector2(1f, 1f);
            pause.anchorMax = new Vector2(1f, 1f);
            pause.pivot = new Vector2(1f, 1f);
            pause.sizeDelta = new Vector2(96f, 64f);
            pause.anchoredPosition = new Vector2(-24f, -24f);
            var btn = UIKit.GhostButton(pause, "II", () => Router.Go(ScreenId.Pause), 64f);
            UIKit.Fill((RectTransform)btn.transform);
        }

        void TopBar()
        {
            var bar = UIKit.Rect("TopBar", Root);
            bar.anchorMin = new Vector2(0.5f, 1f);
            bar.anchorMax = new Vector2(0.5f, 1f);
            bar.pivot = new Vector2(0.5f, 1f);
            bar.sizeDelta = new Vector2(680f, 104f);
            bar.anchoredPosition = new Vector2(0f, -20f);

            var bg = bar.gameObject.AddComponent<Image>();
            bg.color = Theme.WithAlpha(Theme.Void, 0.55f);

            var row = UIKit.Row(bar, 24f, new RectOffset(28, 28, 0, 0), "TopCells");
            UIKit.Fill((RectTransform)row.transform);

            _scoreA = UIKit.Label(row.transform, "0", 54, Theme.TeamAlpha, FontStyle.Bold, TextAnchor.MiddleCenter);
            _scoreA.gameObject.AddComponent<LayoutElement>().preferredWidth = 120f;

            var mid = UIKit.Column(row.transform, 0f, null, "Clock");
            _clock = UIKit.Label(mid.transform, "05:00", 46, Theme.TextHi, FontStyle.Bold, TextAnchor.MiddleCenter);
            _clock.gameObject.AddComponent<LayoutElement>().preferredHeight = 56f;
            var mode = UIKit.Label(mid.transform, "TEAM DEATHMATCH", 18, Theme.TextLow,
                FontStyle.Bold, TextAnchor.MiddleCenter);
            mode.gameObject.AddComponent<LayoutElement>().preferredHeight = 24f;

            _scoreB = UIKit.Label(row.transform, "0", 54, Theme.TeamBravo, FontStyle.Bold, TextAnchor.MiddleCenter);
            _scoreB.gameObject.AddComponent<LayoutElement>().preferredWidth = 120f;
        }

        void Vitals()
        {
            var box = UIKit.Rect("Vitals", Root);
            box.anchorMin = new Vector2(0f, 0f);
            box.anchorMax = new Vector2(0f, 0f);
            box.pivot = new Vector2(0f, 0f);
            box.sizeDelta = new Vector2(520f, 190f);
            box.anchoredPosition = new Vector2(36f, 34f);

            var col = UIKit.Column(box, 8f, null, "VitalsBody");
            UIKit.Fill((RectTransform)col.transform);

            var nameRow = UIKit.Row(col.transform, 10f, null, "NameRow");
            nameRow.gameObject.AddComponent<LayoutElement>().preferredHeight = 34f;
            var def = AgentCatalog.Get(Session.Local.AgentId);
            UIKit.Label(nameRow.transform, def.Name.ToUpperInvariant(), 26, def.Accent, FontStyle.Bold);
            _streak = UIKit.Label(nameRow.transform, "", 22, Theme.Amber, FontStyle.Bold, TextAnchor.MiddleRight);

            _health = UIKit.Label(col.transform, "100", 44, Theme.TextHi, FontStyle.Bold);
            _health.gameObject.AddComponent<LayoutElement>().preferredHeight = 54f;
            _healthBar = UIKit.Bar(col.transform, 1f, Theme.Success, 10f);
            _shieldBar = UIKit.Bar(col.transform, 0.5f, Theme.Cyan, 6f);

            UIKit.Spacer(col.transform, 6f);
            var abilityRow = UIKit.Row(col.transform, 10f, null, "AbilityRow");
            abilityRow.gameObject.AddComponent<LayoutElement>().preferredHeight = 26f;
            UIKit.Label(abilityRow.transform, def.AbilityName.ToUpperInvariant(), 19, Theme.TextLow, FontStyle.Bold);
            _abilityBar = UIKit.Bar(col.transform, 0.4f, Theme.Amber, 6f);
        }

        void KillFeed()
        {
            var box = UIKit.Rect("KillFeed", Root);
            box.anchorMin = new Vector2(1f, 1f);
            box.anchorMax = new Vector2(1f, 1f);
            box.pivot = new Vector2(1f, 1f);
            box.sizeDelta = new Vector2(520f, 200f);
            box.anchoredPosition = new Vector2(-140f, -40f);

            var col = UIKit.Column(box, 6f, null, "FeedBody");
            UIKit.Fill((RectTransform)col.transform);
            _feed = (RectTransform)col.transform;
        }

        /// <summary>Virtual stick + fire/ability buttons. Drawn as HUD affordances here;
        /// the input itself is read by <see cref="TouchInput"/>.</summary>
        void TouchControls()
        {
            var stick = UIKit.Panel(Root, Theme.WithAlpha(Theme.TextLow, 0.10f), "StickBase");
            var srt = (RectTransform)stick.transform;
            srt.anchorMin = new Vector2(0f, 0f);
            srt.anchorMax = new Vector2(0f, 0f);
            srt.pivot = new Vector2(0.5f, 0.5f);
            srt.sizeDelta = new Vector2(230f, 230f);
            srt.anchoredPosition = new Vector2(210f, 250f);

            var knob = UIKit.Panel(stick.transform, Theme.WithAlpha(Theme.Cyan, 0.35f), "StickKnob");
            var krt = (RectTransform)knob.transform;
            krt.sizeDelta = new Vector2(96f, 96f);
            krt.anchoredPosition = Vector2.zero;

            ActionButton("FIRE", new Vector2(-180f, 190f), 200f, Theme.Danger);
            ActionButton("ABILITY", new Vector2(-400f, 300f), 130f, Theme.Amber);
            ActionButton("JUMP", new Vector2(-400f, 140f), 130f, Theme.Cyan);
        }

        void ActionButton(string caption, Vector2 anchoredPos, float size, Color color)
        {
            var rt = UIKit.Rect("Action_" + caption, Root);
            rt.anchorMin = new Vector2(1f, 0f);
            rt.anchorMax = new Vector2(1f, 0f);
            rt.pivot = new Vector2(0.5f, 0.5f);
            rt.sizeDelta = new Vector2(size, size);
            rt.anchoredPosition = anchoredPos;

            var img = rt.gameObject.AddComponent<Image>();
            img.color = Theme.WithAlpha(color, 0.16f);
            var edge = rt.gameObject.AddComponent<Outline>();
            edge.effectColor = Theme.WithAlpha(color, 0.7f);
            edge.effectDistance = new Vector2(2f, -2f);

            var label = UIKit.Label(rt, caption, size > 150f ? 26 : 20, color,
                FontStyle.Bold, TextAnchor.MiddleCenter);
            UIKit.Fill((RectTransform)label.transform);
        }

        void Crosshair()
        {
            var dot = UIKit.Panel(Root, Theme.WithAlpha(Theme.Cyan, 0.9f), "Crosshair");
            var rt = (RectTransform)dot.transform;
            rt.anchorMin = rt.anchorMax = new Vector2(0.5f, 0.5f);
            rt.pivot = new Vector2(0.5f, 0.5f);
            rt.sizeDelta = new Vector2(6f, 6f);
            rt.anchoredPosition = Vector2.zero;

            Tick(new Vector2(0f, 26f), new Vector2(2f, 18f));
            Tick(new Vector2(0f, -26f), new Vector2(2f, 18f));
            Tick(new Vector2(26f, 0f), new Vector2(18f, 2f));
            Tick(new Vector2(-26f, 0f), new Vector2(18f, 2f));
        }

        void Tick(Vector2 offset, Vector2 size)
        {
            var img = UIKit.Panel(Root, Theme.WithAlpha(Theme.Cyan, 0.7f), "Tick");
            var rt = (RectTransform)img.transform;
            rt.anchorMin = rt.anchorMax = new Vector2(0.5f, 0.5f);
            rt.pivot = new Vector2(0.5f, 0.5f);
            rt.sizeDelta = size;
            rt.anchoredPosition = offset;
        }

        void Update()
        {
            var m = MatchState.Instance;
            if (m == null || _clock == null || Router.Current != Id) return;

            _clock.text = MatchState.Clock(m.TimeRemaining);
            _scoreA.text = m.ScoreAlpha.ToString();
            _scoreB.text = m.ScoreBravo.ToString();
            _health.text = Mathf.CeilToInt(m.Health).ToString();
            _streak.text = m.KillStreak > 1 ? m.KillStreak + "x STREAK" : "";

            SetFill(_healthBar, m.Health / Mathf.Max(1f, m.MaxHealth));
            SetFill(_shieldBar, m.Shield / 100f);
            SetFill(_abilityBar, m.AbilityCharge01);

            _healthBar.color = m.Health / m.MaxHealth < 0.3f ? Theme.Danger : Theme.Success;

            if (!m.IsRunning) Router.Go(ScreenId.Results, false);
        }

        static void SetFill(Image bar, float t01)
        {
            if (bar == null) return;
            var rt = (RectTransform)bar.transform;
            rt.anchorMax = new Vector2(Mathf.Clamp01(t01), 1f);
        }
    }
}
