#!/usr/bin/env bash
# Screenshots the playable build (engine/index.html) as it appears on a phone.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CHROME="${CHROME:-/opt/pw-browsers/chromium-1194/chrome-linux/chrome}"
OUT="$ROOT/docs/screenshots"
PORT="${PORT:-8732}"
W="${W:-1920}"; H="${H:-1080}"; OFFSET=87
NAME="${NAME:-3d-gameplay}"
mkdir -p "$OUT"

python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$ROOT" >/dev/null 2>&1 &
SERVER=$!
trap 'kill $SERVER 2>/dev/null || true' EXIT
until curl -s --noproxy '*' "http://127.0.0.1:$PORT/engine/index.html" >/dev/null; do sleep 0.2; done

"$CHROME" --headless --no-sandbox --hide-scrollbars \
  --use-gl=angle --use-angle=swiftshader --enable-unsafe-swiftshader \
  --force-device-scale-factor=1 --window-size="$W,$((H + OFFSET))" \
  --virtual-time-budget=12000 --no-proxy-server \
  --screenshot="$OUT/$NAME.png" \
  "http://127.0.0.1:$PORT/engine/index.html" >/dev/null 2>&1
python3 "$ROOT/tools/mockups/crop_png.py" "$OUT/$NAME.png" "$H"
echo "shot $NAME.png"
