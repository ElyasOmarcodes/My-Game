using BattleOfAgents.Core;
using UnityEngine;
using UnityEngine.UI;

namespace BattleOfAgents.UI
{
    public enum ScreenId
    {
        Splash, MainMenu, CreateRoom, LanBrowser, RoomLobby,
        AgentSelect, Hud, Pause, Results, Settings
    }

    /// <summary>Base class for every full-screen page. A screen owns one root
    /// RectTransform and rebuilds its content when shown.</summary>
    public abstract class ScreenBase : MonoBehaviour
    {
        public abstract ScreenId Id { get; }

        protected AppRouter Router { get; private set; }
        protected SessionState Session { get { return Router.Session; } }
        protected RectTransform Root { get; private set; }

        CanvasGroup _group;

        public void Init(AppRouter router, RectTransform root)
        {
            Router = router;
            Root = root;
            _group = Root.gameObject.GetComponent<CanvasGroup>();
            if (_group == null) _group = Root.gameObject.AddComponent<CanvasGroup>();
            SetVisible(false);
        }

        /// <summary>Build the widget tree. Called once on first show, then on every
        /// <see cref="Rebuild"/>.</summary>
        protected abstract void Build();

        public virtual void OnShow() { }
        public virtual void OnHide() { }

        bool _built;

        public void Show()
        {
            if (!_built) { Build(); _built = true; }
            SetVisible(true);
            OnShow();
        }

        public void Hide()
        {
            SetVisible(false);
            OnHide();
        }

        /// <summary>Tears the page down and rebuilds it — used when data changed
        /// (new room in the list, a player readied up, ...).</summary>
        public void Rebuild()
        {
            for (int i = Root.childCount - 1; i >= 0; i--)
                Destroy(Root.GetChild(i).gameObject);
            Build();
            _built = true;
        }

        void SetVisible(bool visible)
        {
            _group.alpha = visible ? 1f : 0f;
            _group.interactable = visible;
            _group.blocksRaycasts = visible;
            Root.gameObject.SetActive(visible);
        }

        // --- shared page furniture ------------------------------------------

        /// <summary>Dark cinematic backdrop: deep base + vignette-ish gradient bands.</summary>
        protected Image Backdrop()
        {
            var bg = UIKit.Panel(Root, Theme.Void, "Backdrop");
            UIKit.Fill((RectTransform)bg.transform);

            var glow = UIKit.Panel(bg.transform, Theme.WithAlpha(Theme.CyanDim, 0.10f), "Glow");
            var grt = (RectTransform)glow.transform;
            grt.anchorMin = new Vector2(0f, 0.35f);
            grt.anchorMax = new Vector2(0.65f, 1f);
            grt.offsetMin = Vector2.zero;
            grt.offsetMax = Vector2.zero;
            return bg;
        }

        /// <summary>Standard page header with title, subtitle and an optional back action.</summary>
        protected RectTransform Header(string title, string subtitle, ScreenId? back = null)
        {
            var bar = UIKit.Rect("Header", Root);
            bar.anchorMin = new Vector2(0f, 1f);
            bar.anchorMax = new Vector2(1f, 1f);
            bar.pivot = new Vector2(0.5f, 1f);
            bar.sizeDelta = new Vector2(0f, 140f);
            bar.anchoredPosition = new Vector2(0f, 0f);

            var t = UIKit.Label(bar, title.ToUpperInvariant(), 46, Theme.TextHi, FontStyle.Bold);
            var trt = (RectTransform)t.transform;
            trt.anchorMin = new Vector2(0f, 0.5f);
            trt.anchorMax = new Vector2(0f, 0.5f);
            trt.pivot = new Vector2(0f, 0.5f);
            trt.anchoredPosition = new Vector2(Theme.Gutter * 2f, 14f);

            var s = UIKit.Label(bar, subtitle, 24, Theme.TextMid);
            var srt = (RectTransform)s.transform;
            srt.anchorMin = new Vector2(0f, 0.5f);
            srt.anchorMax = new Vector2(0f, 0.5f);
            srt.pivot = new Vector2(0f, 0.5f);
            srt.anchoredPosition = new Vector2(Theme.Gutter * 2f, -26f);

            if (back.HasValue)
            {
                var holder = UIKit.Rect("BackHolder", bar);
                holder.anchorMin = new Vector2(1f, 0.5f);
                holder.anchorMax = new Vector2(1f, 0.5f);
                holder.pivot = new Vector2(1f, 0.5f);
                holder.sizeDelta = new Vector2(220f, 64f);
                holder.anchoredPosition = new Vector2(-Theme.Gutter * 2f, 0f);
                var target = back.Value;
                var btn = UIKit.GhostButton(holder, "BACK", () => Router.Go(target));
                UIKit.Fill((RectTransform)btn.transform);
            }
            return bar;
        }
    }
}
