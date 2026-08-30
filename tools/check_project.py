#!/usr/bin/env python3
"""Guards the project settings a headless test cannot check.

The smoke test runs with no screen and no finger, so it cannot notice that
nothing on screen is clickable. One setting did exactly that: turning off
touch-to-mouse emulation stopped a tap firing the weapon and, in the same
stroke, stopped every button in the game responding to a tap at all — because
Godot's Controls are driven by mouse events and a phone has no mouse.

Anything asserted here is something that shipped broken once.
"""
import re
import sys

PROJECT = "godot/project.godot"

# setting -> (required value, why)
REQUIRED = {
    "pointing/emulate_mouse_from_touch": (
        "true",
        "every Button in the game needs it; without it a phone cannot click "
        "anything. Stop the weapon firing on stray taps in the weapon code, "
        "which ignores the mouse on a touch device.",
    ),
}


def main() -> int:
    text = open(PROJECT).read()
    failed = False

    for setting, (wanted, why) in REQUIRED.items():
        found = re.search(
            r"^%s\s*=\s*(\S+)\s*$" % re.escape(setting), text, re.MULTILINE)
        actual = found.group(1) if found else "(unset)"

        # Unset is fine when the engine default already matches.
        if actual == "(unset)" and wanted == "true":
            print("  %-42s default (true)" % setting)
            continue

        print("  %-42s %s" % (setting, actual))
        if actual != wanted:
            print("::error::%s must be %s — %s" % (setting, wanted, why))
            failed = True

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
