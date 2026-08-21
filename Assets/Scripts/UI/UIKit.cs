using System;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace BattleOfAgents.UI
{
    /// <summary>Code-first widget factory. The whole UI is built at runtime so the
    /// project carries no .prefab / .unity binary blobs — this keeps the repo tiny,
    /// diffable, and buildable head-lessly in CI.</summary>
    public static class UIKit
    {
        static Font _font;
        public static Font DefaultFont
        {
            get
            {
                if (_font == null)
                {
                    _font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
                    if (_font == null) _font = Resources.GetBuiltinResource<Font>("Arial.ttf");
                }
                return _font;
            }
        }

        // --- containers ------------------------------------------------------

        public static RectTransform Rect(string name, Transform parent)
        {
            var go = new GameObject(name, typeof(RectTransform));
            var rt = (RectTransform)go.transform;
            rt.SetParent(parent, false);
            return rt;
        }

        /// <summary>Stretches the rect to fill its parent, with optional padding.</summary>
        public static RectTransform Fill(RectTransform rt, float pad = 0f)
        {
            rt.anchorMin = Vector2.zero;
            rt.anchorMax = Vector2.one;
            rt.offsetMin = new Vector2(pad, pad);
            rt.offsetMax = new Vector2(-pad, -pad);
            return rt;
        }

        public static Image Panel(Transform parent, Color color, string name = "Panel")
        {
            var rt = Rect(name, parent);
            var img = rt.gameObject.AddComponent<Image>();
            img.color = color;
            img.raycastTarget = false;
            return img;
        }

        public static VerticalLayoutGroup Column(Transform parent, float spacing = 12f,
            RectOffset padding = null, string name = "Column")
        {
            var rt = Rect(name, parent);
            var v = rt.gameObject.AddComponent<VerticalLayoutGroup>();
            v.spacing = spacing;
            v.padding = padding ?? new RectOffset(0, 0, 0, 0);
            v.childControlWidth = true;
            v.childControlHeight = true;
            v.childForceExpandWidth = true;
            v.childForceExpandHeight = false;
            return v;
        }

        public static HorizontalLayoutGroup Row(Transform parent, float spacing = 12f,
            RectOffset padding = null, string name = "Row")
        {
            var rt = Rect(name, parent);
            var h = rt.gameObject.AddComponent<HorizontalLayoutGroup>();
            h.spacing = spacing;
            h.padding = padding ?? new RectOffset(0, 0, 0, 0);
            h.childControlWidth = true;
            h.childControlHeight = true;
            h.childForceExpandWidth = true;
            h.childForceExpandHeight = false;
            return h;
        }

        // --- atoms -----------------------------------------------------------

        public static Text Label(Transform parent, string content, int size = 28,
            Color? color = null, FontStyle style = FontStyle.Normal,
            TextAnchor anchor = TextAnchor.MiddleLeft)
        {
            var rt = Rect("Label", parent);
            var t = rt.gameObject.AddComponent<Text>();
            t.font = DefaultFont;
            t.text = content;
            t.fontSize = size;
            t.fontStyle = style;
            t.alignment = anchor;
            t.color = color ?? Theme.TextHi;
            t.horizontalOverflow = HorizontalWrapMode.Overflow;
            t.verticalOverflow = VerticalWrapMode.Overflow;
            t.raycastTarget = false;
            return t;
        }

        /// <summary>Primary action button: hard-edged, accent-filled, uppercase.</summary>
        public static Button PrimaryButton(Transform parent, string caption, Action onClick,
            float height = 84f, Color? tint = null)
        {
            var accent = tint ?? Theme.Cyan;
            var rt = Rect("Button_" + caption, parent);
            var img = rt.gameObject.AddComponent<Image>();
            img.color = Theme.WithAlpha(accent, 0.14f);

            var le = rt.gameObject.AddComponent<LayoutElement>();
            le.minHeight = height;
            le.preferredHeight = height;

            var outline = rt.gameObject.AddComponent<Outline>();
            outline.effectColor = Theme.WithAlpha(accent, 0.85f);
            outline.effectDistance = new Vector2(1.5f, -1.5f);

            var label = Label(rt, caption.ToUpperInvariant(), 30, accent,
                FontStyle.Bold, TextAnchor.MiddleCenter);
            Fill((RectTransform)label.transform);

            var btn = rt.gameObject.AddComponent<Button>();
            btn.targetGraphic = img;
            var colors = btn.colors;
            colors.normalColor      = Color.white;
            colors.highlightedColor = new Color(1.35f, 1.35f, 1.35f, 1f);
            colors.pressedColor     = new Color(0.7f, 0.7f, 0.7f, 1f);
            colors.fadeDuration     = 0.08f;
            btn.colors = colors;
            if (onClick != null) btn.onClick.AddListener(() => onClick());
            return btn;
        }

        public static Button GhostButton(Transform parent, string caption, Action onClick,
            float height = 64f)
        {
            var btn = PrimaryButton(parent, caption, onClick, height, Theme.TextMid);
            btn.targetGraphic.color = Theme.WithAlpha(Theme.SurfaceAlt, 0.9f);
            return btn;
        }

        public static InputField TextField(Transform parent, string placeholder,
            string value = "", float height = 72f)
        {
            var rt = Rect("Field_" + placeholder, parent);
            var bg = rt.gameObject.AddComponent<Image>();
            bg.color = Theme.WithAlpha(Theme.Void, 0.85f);
            var le = rt.gameObject.AddComponent<LayoutElement>();
            le.minHeight = height;
            le.preferredHeight = height;

            var outline = rt.gameObject.AddComponent<Outline>();
            outline.effectColor = Theme.Line;
            outline.effectDistance = new Vector2(1f, -1f);

            var text = Label(rt, value, 28, Theme.TextHi);
            text.supportRichText = false;
            Fill((RectTransform)text.transform, 16f);

            var ph = Label(rt, placeholder, 28, Theme.TextLow, FontStyle.Italic);
            Fill((RectTransform)ph.transform, 16f);

            var field = rt.gameObject.AddComponent<InputField>();
            field.textComponent = text;
            field.placeholder = ph;
            field.targetGraphic = bg;
            field.text = value;
            return field;
        }

        /// <summary>A thin separator line — used a lot by the HUD and panels.</summary>
        public static Image Divider(Transform parent, float thickness = 1f, Color? color = null)
        {
            var img = Panel(parent, color ?? Theme.Line, "Divider");
            var le = img.gameObject.AddComponent<LayoutElement>();
            le.minHeight = thickness;
            le.preferredHeight = thickness;
            return img;
        }

        public static Image Bar(Transform parent, float fill01, Color color, float height = 10f)
        {
            var track = Panel(parent, Theme.WithAlpha(Theme.Void, 0.9f), "BarTrack");
            var le = track.gameObject.AddComponent<LayoutElement>();
            le.minHeight = height;
            le.preferredHeight = height;

            var fillImg = Panel(track.transform, color, "BarFill");
            var frt = (RectTransform)fillImg.transform;
            frt.anchorMin = Vector2.zero;
            frt.anchorMax = new Vector2(Mathf.Clamp01(fill01), 1f);
            frt.offsetMin = Vector2.zero;
            frt.offsetMax = Vector2.zero;
            return fillImg;
        }

        public static void Spacer(Transform parent, float height)
        {
            var rt = Rect("Spacer", parent);
            var le = rt.gameObject.AddComponent<LayoutElement>();
            le.minHeight = height;
            le.preferredHeight = height;
            le.flexibleHeight = 0f;
        }

        public static void Flex(Transform parent)
        {
            var rt = Rect("Flex", parent);
            var le = rt.gameObject.AddComponent<LayoutElement>();
            le.flexibleHeight = 1f;
        }

        /// <summary>Ensures exactly one EventSystem exists (needed for any input).</summary>
        public static void EnsureEventSystem()
        {
            if (UnityEngine.EventSystems.EventSystem.current != null) return;
            var go = new GameObject("EventSystem",
                typeof(EventSystem), typeof(StandaloneInputModule));
            UnityEngine.Object.DontDestroyOnLoad(go);
        }
    }
}
