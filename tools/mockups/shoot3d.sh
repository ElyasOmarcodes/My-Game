#!/usr/bin/env bash
# Renders the WebGL scenes to docs/screenshots/3d-*.png.
#
# Served over http rather than file:// — ES modules are blocked on file origins.
# Chromium also only paints the layout viewport (87px shorter than the window),
# so we shoot taller and trim, exactly as the UI mockups do.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CHROME="${CHROME:-/opt/pw-browsers/chromium-1194/chrome-linux/chrome}"
OUT="$ROOT/docs/screenshots"
PORT="${PORT:-8731}"
W=1920; H=1080; OFFSET=87
mkdir -p "$OUT"

python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$ROOT" >/dev/null 2>&1 &
SERVER=$!
trap 'kill $SERVER 2>/dev/null || true' EXIT
until curl -s --noproxy '*' "http://127.0.0.1:$PORT/engine/shots.html" >/dev/null; do sleep 0.2; done

shots=("$@")
if [ ${#shots[@]} -eq 0 ]; then
  shots=(city-aerial city-street city-park city-industrial agents weapons)
fi

for shot in "${shots[@]}"; do
  "$CHROME" --headless --no-sandbox --hide-scrollbars \
    --use-gl=angle --use-angle=swiftshader --enable-unsafe-swiftshader \
    --force-device-scale-factor=1 --window-size="$W,$((H + OFFSET))" \
    --virtual-time-budget=10000 --no-proxy-server \
    --screenshot="$OUT/3d-$shot.png" \
    "http://127.0.0.1:$PORT/engine/shots.html?shot=$shot&w=$W&h=$H" >/dev/null 2>&1
  python3 "$ROOT/tools/mockups/crop_png.py" "$OUT/3d-$shot.png" "$H"
  echo "shot 3d-$shot.png"
done
