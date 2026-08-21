#!/usr/bin/env bash
# Fetches the CC0 model kits the game builds its world from.
#
# The kits are not committed: they are several megabytes of binary that would
# bloat every clone, and their upstream repositories are stable enough to pin.
# Everything here is CC0 (public domain) — see the CREDITS.md this writes.
#
# Which kits are used is declared in godot/assets.json, so swapping art is a
# one-file edit rather than a code change.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/godot/assets"
WORK="${TMPDIR:-/tmp}/boa-assets"
CONFIG="$ROOT/godot/assets.json"

rm -rf "$WORK"
mkdir -p "$WORK" "$DEST"

# --- helpers -----------------------------------------------------------------

## Blobless sparse clone: fetches only the directories asked for, not the whole
## repository. A 280 MB mirror costs a few MB this way.
sparse_clone() {
  local url="$1" name="$2"; shift 2
  echo "==> $name"
  git clone --quiet --filter=blob:none --no-checkout --depth 1 "$url" "$WORK/$name"
  git -C "$WORK/$name" sparse-checkout init --cone >/dev/null
  git -C "$WORK/$name" sparse-checkout set "$@" >/dev/null
  git -C "$WORK/$name" checkout --quiet
}

## Copies files matching a pattern into a category folder, flattening the tree.
collect() {
  local source_dir="$1" category="$2" pattern="$3" limit="${4:-9999}"
  local target="$DEST/$category"
  mkdir -p "$target"

  local copied=0
  while IFS= read -r file; do
    [ "$copied" -ge "$limit" ] && break
    cp "$file" "$target/" 2>/dev/null || continue
    copied=$((copied + 1))
  done < <(find "$source_dir" -type f -iname "$pattern" 2>/dev/null | sort)

  echo "    $category  +$copied  ($pattern)"
}

# --- sources ------------------------------------------------------------------

# Kenney's kits, via a community mirror of kenney.nl. Every Kenney asset is CC0.
sparse_clone "https://github.com/ETdoFresh/kenney.nl.git" kenney \
  "fantasy-town-kit-1.0" "kenney_natureKit_2.1" "carkit_v1.4"

# KayKit by Kay Lousberg: rigged characters with animation clips, also CC0.
sparse_clone "https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0.git" \
  kaykit "addons"

# --- buildings and streets ----------------------------------------------------

TOWN="$WORK/kenney/fantasy-town-kit-1.0"
collect "$TOWN" buildings "building*.glb"
collect "$TOWN" buildings "house*.glb"
collect "$TOWN" buildings "tower*.glb"
collect "$TOWN" buildings "market*.glb"
collect "$TOWN" buildings "chimney*.glb" 0     # roof detail, not a building

collect "$TOWN" props "barrel*.glb"
collect "$TOWN" props "crate*.glb"
collect "$TOWN" props "box*.glb"
collect "$TOWN" props "bench*.glb"
collect "$TOWN" props "lantern*.glb"
collect "$TOWN" props "streetlight*.glb"
collect "$TOWN" props "sign*.glb"
collect "$TOWN" props "well*.glb"
collect "$TOWN" props "fence*.glb" 12
collect "$TOWN" props "cart*.glb"

NATURE="$WORK/kenney/kenney_natureKit_2.1"
collect "$NATURE" props "tree*.glb" 14
collect "$NATURE" props "rock*.glb" 8
collect "$NATURE" props "grass*.glb" 4
collect "$NATURE" props "campfire*.glb" 2

# --- characters and weapons ---------------------------------------------------

KAY="$WORK/kaykit"
collect "$KAY" characters "*.glb"
collect "$KAY" weapons "sword*.gltf"
collect "$KAY" weapons "axe*.gltf"
collect "$KAY" weapons "crossbow*.gltf"
collect "$KAY" weapons "dagger*.gltf"
collect "$KAY" weapons "staff*.gltf"
collect "$KAY" weapons "*.bin"          # gltf buffers must sit beside the .gltf
collect "$KAY" weapons "*texture*.png"

# --- manifest -----------------------------------------------------------------

python3 - "$DEST" "$CONFIG" <<'PY'
import json, os, sys

dest, config_path = sys.argv[1], sys.argv[2]
categories = {}

for category in sorted(os.listdir(dest)):
    folder = os.path.join(dest, category)
    if not os.path.isdir(folder):
        continue
    models = sorted(
        "res://assets/%s/%s" % (category, name)
        for name in os.listdir(folder)
        if name.lower().endswith((".glb", ".gltf"))
    )
    if models:
        categories[category] = models

attribution = (
    "Models: Kenney (kenney.nl) Fantasy Town Kit and Nature Kit; "
    "KayKit Adventurers by Kay Lousberg (kaylousberg.com). All CC0 1.0."
)

manifest = {"attribution": attribution, "categories": categories}
with open(os.path.join(dest, "manifest.json"), "w") as handle:
    json.dump(manifest, handle, indent=2)

print()
for category, models in categories.items():
    print("  %-12s %d models" % (category, len(models)))
print("  total        %d" % sum(len(v) for v in categories.values()))
PY

cat > "$DEST/CREDITS.md" <<'CREDITS'
# Art credits

Every model in this folder is **CC0 1.0 (public domain)** — free to use, modify
and redistribute, commercially or not, with no attribution required. It is given
here anyway, because these artists made the game look like a game.

| Kit | Author | Source | Licence |
| --- | --- | --- | --- |
| Fantasy Town Kit | Kenney | kenney.nl | CC0 1.0 |
| Nature Kit | Kenney | kenney.nl | CC0 1.0 |
| Car Kit | Kenney | kenney.nl | CC0 1.0 |
| Adventurers Character Pack | Kay Lousberg | kaylousberg.com | CC0 1.0 |

Fetched at build time by `tools/fetch_assets.sh`; not committed to this
repository. Which kits are used is declared in `godot/assets.json`.
CREDITS

echo
echo "Assets ready in $DEST"
