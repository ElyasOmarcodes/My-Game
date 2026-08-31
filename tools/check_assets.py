#!/usr/bin/env python3
"""Fails the build when an art category came back short.

A total on its own hides the failure this has hit twice: 195 models pass the
count while the walls the town is actually built from never landed, and the game
quietly falls back to grey boxes. Every category the world needs is checked on
its own.
"""
import json
import os
import sys

REQUIRED = {"walls": 5, "roofs": 3, "props": 20, "characters": 2, "weapons": 6}
OPTIONAL = ["map", "throwables"]
MANIFEST = "godot/assets/manifest.json"


def main() -> int:
    catalog = json.load(open(MANIFEST))["categories"]

    short = []
    for category, minimum in sorted(REQUIRED.items()):
        found = len(catalog.get(category, []))
        print("  %-12s %3d  (need %d)" % (category, found, minimum))
        if found < minimum:
            short.append("%s %d<%d" % (category, found, minimum))

    # Icons and audio are files on disk, not models, so they never appear in
    # the manifest — which lists only what the loader can instantiate. Counting
    # them there reported zero for something that was working perfectly well.
    for folder, minimum in (("icons", 3), ("audio", 4)):
        path = os.path.join("godot", "assets", folder)
        found = len(os.listdir(path)) if os.path.isdir(path) else 0
        print("  %-12s %3d  (need %d, on disk)" % (folder, found, minimum))
        if found < minimum:
            short.append("%s %d<%d" % (folder, found, minimum))

    for category in OPTIONAL:
        found = len(catalog.get(category, []))
        print("  %-12s %3d  (optional)" % (category, found))
    if not catalog.get("map"):
        print("::warning::no supplied map landed - the town will be generated")

    if short:
        print("::error::art categories short: " + "; ".join(short))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
