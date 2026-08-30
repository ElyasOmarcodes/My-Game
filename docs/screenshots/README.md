# Screenshots

These are rendered **by the game itself**, not mocked up. `scenes/Shots.tscn`
builds the same world a match does, drives a camera to a few fixed viewpoints and
saves a PNG at each — so what is in this folder is what the build looks like.

They are produced in CI (`.github/workflows/godot-apk.yml`) on a software
rasteriser under `xvfb`, and committed back to the branch, because the machine
the code is written on has no GPU and cannot reach the art kits.

| File | What it shows |
| --- | --- |
| `godot-town-aerial.png` | The whole map from above |
| `godot-town-street.png` | Standing on a spawn point at head height |
| `godot-town-corner.png` | Buildings and props close up |
| `godot-agents.png` | The four agents with their weapons |
| `godot-weapons.png` | The weapon models close up |

To regenerate them locally:

```bash
tools/fetch_assets.sh
godot --headless --path godot --import
xvfb-run -a godot --path godot --rendering-method gl_compatibility \
  --rendering-driver opengl3 res://scenes/Shots.tscn --quit-after 600
```
