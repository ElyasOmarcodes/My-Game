#!/usr/bin/env bash
# Renders every mockup page to docs/screenshots/*.png at the game's reference
# resolution (1920x1080 landscape — the CanvasScaler reference in Theme.cs).
#
# Headless Chrome only paints the layout viewport, which is 87px shorter than
# the requested window, so we shoot 1920x1167 and trim the strip afterwards.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CHROME="${CHROME:-/opt/pw-browsers/chromium-1194/chrome-linux/chrome}"
OUT="$ROOT/docs/screenshots"
WIDTH=1920; HEIGHT=1080; CHROME_OFFSET=87
mkdir -p "$OUT"

for f in "$ROOT"/tools/mockups/*.html; do
  name="$(basename "$f" .html)"
  "$CHROME" --headless --disable-gpu --no-sandbox --hide-scrollbars \
    --force-device-scale-factor=1 --window-size="$WIDTH,$((HEIGHT + CHROME_OFFSET))" \
    --screenshot="$OUT/$name.png" "file://$f" >/dev/null 2>&1
  python3 "$ROOT/tools/mockups/crop_png.py" "$OUT/$name.png" "$HEIGHT"
  echo "shot $name.png"
done
