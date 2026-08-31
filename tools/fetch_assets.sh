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

# --- the supplied map ----------------------------------------------------------
#
# A whole level beats a generated one, so if godot/assets.json names a map the
# build downloads it here. The URL is not reachable from the development sandbox
# (the egress policy blocks it) — the runner is the only place this can be
# fetched and identified, so it reports loudly what it got.

MAP_URLS="$(python3 - "$CONFIG" <<'MAPCFG'
import json, sys
config = json.load(open(sys.argv[1]))
entry = config.get("map", {})
urls = entry.get("urls") or ([entry["url"]] if entry.get("url") else [])
print("\n".join(urls))
MAPCFG
)"

## Downloads one candidate and stages whatever models it holds. Returns 0 only
## when something Godot can import actually landed.
try_map() {
  local url="$1"
  echo "==> map  $url"
  rm -rf "$WORK/map"; mkdir -p "$WORK/map"
  local blob="$WORK/map/download.bin"

  if ! curl -fsSL --retry 2 --retry-delay 2 --max-time 600 -o "$blob" "$url"; then
    echo "    download failed"
    return 1
  fi

  echo "    $(stat -c%s "$blob") bytes — $(file -b "$blob")"

  # The links carry no filename, so unpack by sniffing the content.
  case "$(file -b --mime-type "$blob")" in
    application/zip) (cd "$WORK/map" && unzip -q -o download.bin) || true ;;
    application/x-7z-compressed) 7z x -y -o"$WORK/map" "$blob" >/dev/null || true ;;
    application/gzip|application/x-gzip|application/x-tar)
      tar -xf "$blob" -C "$WORK/map" 2>/dev/null || true ;;
  esac

  echo "    contents:"
  find "$WORK/map" -type f -printf '      %10s  %P\n' 2>/dev/null | sort -k2 | head -60
  echo "      ($(find "$WORK/map" -type f | wc -l) files)"

  # A .gltf and an .fbx both need their sidecar buffers and textures, so the
  # tree is kept rather than flattened the way the module kits are.
  local found=0
  while IFS= read -r file; do
    rel="${file#"$WORK/map/"}"
    mkdir -p "$DEST/map/$(dirname "$rel")"
    cp "$file" "$DEST/map/$rel" && found=$((found + 1))
  done < <(find "$WORK/map" -type f \
    \( -iname '*.glb' -o -iname '*.gltf' -o -iname '*.fbx' -o -iname '*.obj' \
       -o -iname '*.mtl' -o -iname '*.bin' -o -iname '*.png' -o -iname '*.jpg' \
       -o -iname '*.jpeg' -o -iname '*.tga' -o -iname '*.webp' \) 2>/dev/null)

  # The blob may itself be a bare model with no extension to go on.
  if [ "$found" -eq 0 ]; then
    case "$(head -c 20 "$blob" | tr -d '\0')" in
      glTF*)          cp "$blob" "$DEST/map/level.glb"; found=1 ;;
      "Kaydara FBX"*) cp "$blob" "$DEST/map/level.fbx"; found=1 ;;
    esac
    [ "$found" -gt 0 ] && echo "    bare model, named by its magic bytes"
  fi

  echo "    staged $found file(s)"
  [ "$found" -gt 0 ]
}

fetch_map() {
  mkdir -p "$DEST/map"

  # A map committed to the repository wins outright: no link to expire, no host
  # to go down. Drop the .fbx or .glb (and its textures) into maps/ and it is
  # simply used.
  if [ -d "$ROOT/maps" ] && [ -n "$(find "$ROOT/maps" -type f 2>/dev/null)" ]; then
    echo "==> map  from the repository's maps/ folder"
    cp -r "$ROOT/maps/." "$DEST/map/"
    find "$DEST/map" -type f -printf '      %10s  %P\n' | sort -k2 | head -40
    return 0
  fi
  [ -n "$MAP_URLS" ] || { echo "==> no map url configured"; return 0; }
  while IFS= read -r url; do
    [ -n "$url" ] || continue
    if try_map "$url"; then
      echo "    map ready"
      return 0
    fi
  done <<< "$MAP_URLS"
  echo "::warning::no configured map could be fetched — the town will be generated"
}

fetch_map

# --- sources ------------------------------------------------------------------

# Kenney's kits, via a community mirror of kenney.nl. Every Kenney asset is CC0.
#
# Which folders the mirror uses is not something to guess at — an earlier build
# shipped a city of grey boxes because a guessed path matched nothing. Clone
# without a checkout, read the real directory names, then ask for what is there.
echo "==> kenney (listing)"
git clone --quiet --filter=blob:none --no-checkout --depth 1 \
  "https://github.com/ETdoFresh/kenney.nl.git" "$WORK/kenney"
KENNEY_DIRS="$(git -C "$WORK/kenney" ls-tree -d --name-only HEAD)"
echo "=== kits in the mirror ($(echo "$KENNEY_DIRS" | wc -l)) ==="
echo "$KENNEY_DIRS" | paste -sd' ' -
echo

WANTED="fantasy-town-kit-1.0 kenney_natureKit_2.1 carkit_v1.4 onscreencontrols gameicons"

git -C "$WORK/kenney" sparse-checkout init --cone >/dev/null
# shellcheck disable=SC2086
git -C "$WORK/kenney" sparse-checkout set $WANTED >/dev/null
git -C "$WORK/kenney" checkout --quiet

# KayKit by Kay Lousberg: rigged characters with animation clips, also CC0.
sparse_clone "https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0.git" \
  kaykit "addons"

# A realistic rigged body. The adventurers are charming but chibi, and the
# animation library turned out to ship clips with no mesh at all, so these come
# down as single files rather than as a repository.
fetch_model() {
  local url="$1" name="$2"
  if curl -fsSL --retry 3 --retry-delay 2 -o "$DEST/characters/$name" "$url"; then
    echo "    characters  +1  ($name)"
  else
    echo "::warning::could not fetch $name"
  fi
}

mkdir -p "$DEST/characters"
fetch_model \
  "https://raw.githubusercontent.com/mrdoob/three.js/dev/examples/models/gltf/Soldier.glb" \
  "Soldier.glb"

# Quaternius's Universal Animation Library: one rig carrying 46 clips — idle,
# walk, jog, sprint, crouch idle and crouch walk, the jump broken into start,
# loop and land, and a whole pistol set (idle, aim up and down, shoot, reload).
# CC0. This is the body the agents wear, because a body and its animations have
# to come from the same rig; retargeting between two is where it falls apart.
sparse_clone "https://github.com/J-Ponzo/gltf-universal-animation-library.git" \
  ual "glTF"
if [ -d "$WORK/ual/glTF" ]; then
  echo "=== animation library ==="
  cp "$WORK/ual/glTF/AnimationLibrary_Godot_Standard.gltf" \
     "$DEST/characters/Universal.gltf"
  cp "$WORK/ual/glTF/AnimationLibrary_Godot_Standard.bin" \
     "$DEST/characters/AnimationLibrary_Godot_Standard.bin"
  echo "    characters  +1  (Universal.gltf, 46 clips)"
else
  echo "::warning::animation library unavailable — agents fall back to Soldier"
fi

# --- what the kits actually contain -------------------------------------------

TOWN="$WORK/kenney/fantasy-town-kit-1.0"
KAY="$WORK/kaykit"

echo
echo "=== town kit models ($(find "$TOWN" -iname '*.glb' 2>/dev/null | wc -l)) ==="
find "$TOWN" -iname '*.glb' -printf '%f\n' 2>/dev/null | sort | paste -sd' ' -
echo
echo "=== character kit models ==="
find "$KAY" \( -iname '*.glb' -o -iname '*.gltf' \) -printf '%f\n' 2>/dev/null | sort | paste -sd' ' -
echo

# --- sorting the town kit ------------------------------------------------------
#
# The kit is modular: walls, roofs and road tiles, no whole houses. The builder
# assembles a house out of wall modules and caps it with roof modules, so those
# two need their own categories — mixing them into one "buildings" pile is what
# produced a town of loose panels. Road tiles are skipped: paving a 180 m grid
# one module at a time costs thousands of draw calls on a phone.

mkdir -p "$DEST/walls" "$DEST/roofs" "$DEST/props"
walls=0; roofs=0; town_props=0; skipped=0

while IFS= read -r file; do
  base="$(basename "$file" | tr '[:upper:]' '[:lower:]')"
  case "$base" in
    wall*) cp "$file" "$DEST/walls/"  && walls=$((walls + 1)) ;;
    roof*) cp "$file" "$DEST/roofs/"  && roofs=$((roofs + 1)) ;;
    road*) skipped=$((skipped + 1)) ;;
    *)     cp "$file" "$DEST/props/"  && town_props=$((town_props + 1)) ;;
  esac
done < <(find "$TOWN" -type f -iname '*.glb' 2>/dev/null | sort)

echo "    town kit split: $walls walls, $roofs roofs, $town_props props, $skipped road tiles skipped"

NATURE="$WORK/kenney/kenney_natureKit_2.1"
collect "$NATURE" props "tree*.glb" 14
collect "$NATURE" props "rock*.glb" 8
collect "$NATURE" props "grass*.glb" 4
collect "$NATURE" props "campfire*.glb" 2

# --- characters and weapons ---------------------------------------------------

collect "$KAY" characters "*.glb"
# Guns and gunfire, from Kenney's own CC0 FPS starter kit.
#
# The mirror's "weapon" folders turned out to be 2D sprite packs — every one
# yielded zero models — and there is no larger free 3D gun pack this build can
# reach. Two real gun bodies is what exists; the five weapons are built from
# them by silhouette, size, colour and voice.
sparse_clone "https://github.com/KenneyNL/Starter-Kit-FPS.git" fps "models" "sounds"

FPS="$WORK/fps"
echo "=== Kenney FPS kit ==="
find "$FPS/models" -iname '*.glb' -printf '%f\n' 2>/dev/null | sort | paste -sd' ' -
collect "$FPS/models" weapons "blaster*.glb"

# Its gunshots are recordings, which beat anything synthesised.
mkdir -p "$DEST/audio"
collect "$FPS/sounds" audio "blaster*.ogg"
collect "$FPS/sounds" audio "weapon_change.ogg"
collect "$FPS/sounds" audio "jump_a.ogg"
collect "$FPS/sounds" audio "land.ogg"
collect "$FPS/sounds" audio "enemy_hurt.ogg"

collect "$KAY" weapons "sword*.gltf"
collect "$KAY" weapons "axe*.gltf"
collect "$KAY" weapons "crossbow*.gltf"
collect "$KAY" weapons "staff*.gltf"
collect "$KAY" weapons "*.bin"          # gltf buffers must sit beside the .gltf
collect "$KAY" weapons "*texture*.png"

# Something to throw.
collect "$KAY" throwables "smokebomb*.gltf"
collect "$KAY" throwables "*.bin"
collect "$KAY" throwables "*texture*.png"

# --- more gunfire -------------------------------------------------------------
#
# Still North Media's weapon library is CC0 and holds a real submachine-gun
# recording, which stands in for the AK far better than anything synthesised.

if git clone --quiet --depth 1 \
    "https://github.com/PanderMusubi/sound-effects-library-weapons.git" \
    "$WORK/gunsfx" 2>/dev/null; then
  echo
  echo "=== firearm recordings ==="
  find "$WORK/gunsfx" -iname '*.ogg' -printf '%f\n' | sort | paste -sd' ' -
  mkdir -p "$DEST/audio"
  for file in "$WORK"/gunsfx/samples/ppsh*.ogg; do
    [ -f "$file" ] || continue
    cp "$file" "$DEST/audio/ak47.ogg" && echo "    audio  ak47.ogg (PPSh, CC0)"
    break
  done
else
  echo "::warning::firearm recordings unavailable — synthesised voices stand in"
fi

# --- the button icons ---------------------------------------------------------
#
# Drawn glyphs were readable but plainly hand-made. Kenney's on-screen controls
# pack is CC0 art made for exactly this, so the buttons wear real icons.

echo
echo "=== on-screen control icons ==="
for kit in onscreencontrols gameicons; do
  [ -d "$WORK/kenney/$kit" ] || continue
  find "$WORK/kenney/$kit" -iname '*.png' | wc -l | xargs echo "    $kit png files:"
done
# Only the handful the buttons actually wear. The two packs hold 800 PNGs
# between them and all but five would be dead weight in the APK.
# The white set, at 2x. The pack ships black and white variants and the buttons
# tint their icon by multiplying — which leaves a black icon black whatever
# colour it is given, as the last build showed on every button.
for icon in target arrowUp arrowDown return fastForward; do
  for kit in gameicons onscreencontrols; do
    found="$(find "$WORK/kenney/$kit" -ipath '*white*2x*' -iname "$icon.png" \
      2>/dev/null | head -1)"
    [ -n "$found" ] || found="$(find "$WORK/kenney/$kit" -ipath '*white*' \
      -iname "$icon.png" 2>/dev/null | head -1)"
    if [ -n "$found" ]; then
      mkdir -p "$DEST/icons"
      cp "$found" "$DEST/icons/$icon.png" && echo "    icons  $icon.png"
      break
    fi
  done
done

# --- the supplied models ------------------------------------------------------
#
# These came from the owner and exist nowhere the build could fetch them, so
# they are committed. tools/prepare_assets.py is what turned 70 MB of raw
# archives into this.

if [ -d "$ROOT/assets_bundled" ]; then
  echo
  echo "=== supplied models ==="
  cp -r "$ROOT/assets_bundled/." "$DEST/"
  find "$ROOT/assets_bundled" -type f -printf '    %10s  %P\n' | sort -k2
fi

# --- sounds -------------------------------------------------------------------
#
# Synthesised rather than downloaded: nothing to license, nothing to keep in the
# repository, and each weapon still gets a voice of its own.

echo
echo "=== weapon sounds ==="
python3 "$ROOT/tools/make_sounds.py" "$DEST/audio"

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
        if name.lower().endswith((".glb", ".gltf", ".fbx", ".obj"))
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
| Starter-Kit-FPS (guns, gunfire) | Kenney | github.com/KenneyNL | CC0 1.0 |
| On-screen controls, game icons | Kenney | kenney.nl | CC0 1.0 |
| Weapon sound library (PPSh) | Still North Media | github.com/PanderMusubi | CC0 1.0 |
| Universal Animation Library | Quaternius | quaternius.com | CC0 1.0 |
| SWAT Operator, M4A4, AK-47, AWP, grenade | supplied by the repository owner | — | as supplied |
| Soldier.glb, Xbot.glb | Mixamo (Adobe) | three.js examples, MIT repository | see below |

The two realistic bodies come from the three.js examples folder. three.js itself
is MIT; the characters inside it are Mixamo rigs, whose terms allow use in a
project but are not CC0. Everything else here is public domain. To keep the
whole build CC0, remove those two entries from `godot/assets.json` — the game
falls back to the CC0 adventurers on its own.

Fetched at build time by `tools/fetch_assets.sh`; not committed to this
repository. Which kits are used is declared in `godot/assets.json`.
CREDITS

echo
echo "=== wall modules ==="
ls "$DEST/walls" 2>/dev/null | paste -sd' ' -
echo "=== roof modules ==="
ls "$DEST/roofs" 2>/dev/null | paste -sd' ' -
echo
echo "Assets ready in $DEST"
