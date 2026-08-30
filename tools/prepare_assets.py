#!/usr/bin/env python3
"""Turns the supplied art archives into a bundle the game can ship.

The uploaded models are authored for a desktop renderer: one M4A4 texture alone
is a 16 MB uncompressed TGA, and the Dragon Lore carries two 16 MB bitmaps. Put
straight into an APK that is 50 MB of texture nobody's phone needs. This
downscales every texture to a sane size, rewrites the .mtl files to point at the
results, trims the pointless precision out of the .obj vertex data, and splits
the thirteen-weapon pack into one model per weapon.

Run it once against the extracted archives; the output is committed, because
these files exist nowhere the build could fetch them from.

    tools/prepare_assets.py <extracted-upload-dir> assets_bundled
"""
import os
import re
import shutil
import sys

from PIL import Image

MAX_TEXTURE = 1024          # plenty at the size a gun is drawn on a phone
JPEG_QUALITY = 86


def convert_texture(source: str, target_dir: str) -> str:
    """Downscales one texture to a JPEG and returns its new filename."""
    name = os.path.splitext(os.path.basename(source))[0] + ".jpg"
    target = os.path.join(target_dir, name)

    with Image.open(source) as image:
        image = image.convert("RGB")
        if max(image.size) > MAX_TEXTURE:
            scale = MAX_TEXTURE / max(image.size)
            image = image.resize(
                (max(1, int(image.width * scale)), max(1, int(image.height * scale))),
                Image.LANCZOS)
        image.save(target, "JPEG", quality=JPEG_QUALITY, optimize=True)

    print("    texture %-28s %8d -> %7d bytes  %s"
          % (os.path.basename(source), os.path.getsize(source),
             os.path.getsize(target), image.size))
    return name


NUMBER = re.compile(r"-?\d+\.\d{6,}")


def trim(match: "re.Match") -> str:
    return "%.5f" % float(match.group(0))


def copy_obj(source: str, target: str, texture_map: dict) -> None:
    """Copies an .obj, shortening its numbers and repointing its .mtl."""
    lines = []
    with open(source, "r", errors="replace") as handle:
        for line in handle:
            if line[:2] in ("v ", "vn", "vt"):
                line = NUMBER.sub(trim, line)
            elif line.startswith("mtllib"):
                line = "mtllib %s\n" % os.path.basename(texture_map["mtl"])
            lines.append(line)
    with open(target, "w") as handle:
        handle.writelines(lines)


def split_pack(source: str, target_dir: str, prefix: str) -> int:
    """Splits a multi-object .obj into one file per object.

    The thirteen-weapon pack is a single .obj with thirteen `o` groups. Loading
    it whole would put every gun in the game at once, in one mesh.
    """
    header, groups, current = [], {}, None
    with open(source, "r", errors="replace") as handle:
        for line in handle:
            if line.startswith("o "):
                current = line[2:].strip()
                groups[current] = []
                continue
            if current is None:
                if not line.startswith("mtllib"):
                    header.append(line)
                continue
            groups[current].append(line)

    written = 0
    for index, (name, body) in enumerate(sorted(groups.items())):
        if not any(line.startswith("f ") for line in body):
            continue
        path = os.path.join(target_dir, "%s%02d.obj" % (prefix, index + 1))
        with open(path, "w") as handle:
            handle.writelines(NUMBER.sub(trim, line) if line[:2] in ("v ", "vn", "vt")
                              else line for line in header)
            handle.writelines(NUMBER.sub(trim, line) if line[:2] in ("v ", "vn", "vt")
                              else line for line in body)
        written += 1
    print("    split %s into %d weapons" % (os.path.basename(source), written))
    return written


def bundle_model(source_dir: str, obj_name: str, out_dir: str, stem: str,
                 texture: str = "", colour: str = "0.62 0.62 0.64") -> None:
    """Copies one .obj out with a material that actually points at its texture.

    Three of the four supplied guns ship no usable material at all — the AK and
    the M4 have UVs and a texture file but no .mtl, and the AWP's .mtl names a
    flat gold colour and never mentions its texture. Left alone they import as
    untextured grey, which is the whole reason for doing this by hand.
    """
    os.makedirs(out_dir, exist_ok=True)
    obj = os.path.join(source_dir, obj_name)

    texture_file = ""
    if texture:
        texture_file = convert_texture(os.path.join(source_dir, texture), out_dir)

    material = stem + "_mat"
    with open(os.path.join(out_dir, stem + ".mtl"), "w") as handle:
        handle.write("newmtl %s\n" % material)
        handle.write("Ka 1 1 1\nKd %s\nKs 0.35 0.35 0.35\nNs 48\nd 1\nillum 2\n"
                     % ("1 1 1" if texture_file else colour))
        if texture_file:
            handle.write("map_Kd %s\n" % texture_file)

    # The .mtl reference and the material selection are written in rather than
    # patched, because in two of these files there is nothing there to patch.
    body = []
    with open(obj, "r", errors="replace") as handle:
        for line in handle:
            if line.startswith(("mtllib", "usemtl")):
                continue
            if line[:2] in ("v ", "vn", "vt"):
                line = NUMBER.sub(trim, line)
            body.append(line)

    with open(os.path.join(out_dir, stem + ".obj"), "w") as handle:
        handle.write("mtllib %s.mtl\nusemtl %s\n" % (stem, material))
        handle.writelines(body)

    print("    model   %-10s %8d bytes%s" % (
        stem, os.path.getsize(os.path.join(out_dir, stem + ".obj")),
        "  + " + texture_file if texture_file else "  (untextured)"))


def main() -> int:
    source = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else "assets_bundled"

    extracted = os.path.join(source, "extracted")
    weapons = os.path.join(out, "weapons")
    characters = os.path.join(out, "characters")
    throwables = os.path.join(out, "throwables")
    for folder in (weapons, characters, throwables):
        os.makedirs(folder, exist_ok=True)

    print("=== characters ===")
    swat = os.path.join(source, "assets", "character", "SWAT+Operator.fbx")
    if os.path.exists(swat):
        shutil.copy(swat, os.path.join(characters, "SwatOperator.fbx"))
        print("    SwatOperator.fbx  %d bytes" % os.path.getsize(swat))

    print("=== weapons ===")
    bundle_model(os.path.join(extracted, "zgav5t4puc-Ak_47", "Ak_47"),
                 "Ak-47.obj", weapons, "ak47", texture="ak-47.jpg")
    bundle_model(os.path.join(extracted, "88yrcjq4775s-M4A4", "88yrcjq4775s-M4A4"),
                 "m4a1.obj", weapons, "m4a4", texture="rif_m4a1.tga")
    bundle_model(os.path.join(extracted, "app4qddbo5xc-Dragon_Lore",
                              "app4qddbo5xc-Dragon_Lore", "Dragon_Lore"),
                 "AWP_Dragon_Lore.obj", weapons, "awp", texture="Color.bmp")

    pack = os.path.join(extracted, "94-weapons", "94-weapons")
    if os.path.exists(os.path.join(pack, "all weapons.obj")):
        shutil.copy(os.path.join(pack, "all weapons.mtl"),
                    os.path.join(weapons, "pack.mtl"))
        split_pack(os.path.join(pack, "all weapons.obj"), weapons, "pack")

    print("=== throwables ===")
    grenade = os.path.join(extracted, "68-grenade-model", "Grenade model")
    if os.path.exists(os.path.join(grenade, "Grenade.obj")):
        bundle_model(grenade, "Grenade.obj", throwables, "grenade",
                     colour="0.13 0.18 0.12")

    total = 0
    for root, _, files in os.walk(out):
        for file in files:
            total += os.path.getsize(os.path.join(root, file))
    print("\nbundle: %d files, %.1f MB" % (
        sum(len(f) for _, _, f in os.walk(out)), total / 1048576.0))
    return 0


if __name__ == "__main__":
    sys.exit(main())
