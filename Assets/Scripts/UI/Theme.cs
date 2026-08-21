using UnityEngine;

namespace BattleOfAgents.UI
{
    /// <summary>The single source of truth for the visual language.
    /// The HTML mockups in /tools/mockups mirror these exact values.</summary>
    public static class Theme
    {
        // Base surfaces -------------------------------------------------------
        public static readonly Color Void       = Hex("#05070C");
        public static readonly Color Surface    = Hex("#0B1119");
        public static readonly Color SurfaceAlt = Hex("#111A25");
        public static readonly Color Line       = Hex("#1E2C3C");

        // Accents -------------------------------------------------------------
        public static readonly Color Cyan       = Hex("#3BE8FF");
        public static readonly Color CyanDim    = Hex("#1B7F94");
        public static readonly Color Amber      = Hex("#FFB23B");
        public static readonly Color Danger     = Hex("#FF4D5E");
        public static readonly Color Success    = Hex("#4DFFA6");
        public static readonly Color TeamAlpha  = Hex("#3BE8FF");
        public static readonly Color TeamBravo  = Hex("#FF7A3B");

        // Text ----------------------------------------------------------------
        public static readonly Color TextHi     = Hex("#E8F4FF");
        public static readonly Color TextMid    = Hex("#93A6BC");
        public static readonly Color TextLow    = Hex("#55677D");

        // Metrics -------------------------------------------------------------
        public const int RadiusS = 6;
        public const int RadiusM = 12;
        public const float Gutter = 24f;
        public const float PanelAlpha = 0.72f;

        // Reference resolution used by the CanvasScaler (landscape phone).
        public static readonly Vector2 ReferenceResolution = new Vector2(1920f, 1080f);

        public static Color Hex(string hex)
        {
            Color c;
            return ColorUtility.TryParseHtmlString(hex, out c) ? c : Color.magenta;
        }

        public static Color WithAlpha(Color c, float a)
        {
            c.a = a;
            return c;
        }
    }
}
