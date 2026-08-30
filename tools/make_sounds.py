#!/usr/bin/env python3
"""Synthesises the weapon sounds the game plays.

A gunshot is a pressure spike: a very short burst of broadband noise shaped by
the barrel, over a low thump from the chamber. Building them here rather than
downloading them keeps every sound licence-free, keeps each one under 40 kB, and
lets each weapon differ in the ways that actually distinguish real ones — how
fast the crack decays, how bright it is, and how deep the body under it sits.

Pure standard library: the build runner has no numpy, and this is fast enough.
"""
import math
import os
import random
import struct
import sys
import wave

RATE = 22050

# name: (seconds, brightness 0..1, body Hz, body level, crack level, rattle)
VOICES = {
    "rifle":     (0.34, 0.72, 118.0, 0.55, 1.00, 0.00),
    "smg":       (0.20, 0.86, 165.0, 0.34, 0.86, 0.00),
    "shotgun":   (0.62, 0.40,  74.0, 0.95, 0.90, 0.18),
    "sniper":    (0.85, 0.58,  62.0, 0.80, 1.00, 0.30),
    "pistol":    (0.26, 0.78, 140.0, 0.44, 0.92, 0.00),
    "explosion": (1.40, 0.22,  44.0, 1.00, 0.70, 0.45),
    "reload":    (0.42, 0.95, 320.0, 0.16, 0.30, 0.55),
    "empty":     (0.10, 0.98, 900.0, 0.10, 0.22, 0.00),
}


def render(seconds, brightness, body_hz, body_level, crack_level, rattle):
    total = int(RATE * seconds)
    samples = []

    # One-pole low pass; a higher coefficient keeps more of the noise's top end,
    # which is what makes a rifle read as sharper than a shotgun.
    coefficient = 0.12 + 0.85 * brightness
    filtered = 0.0
    phase = 0.0

    for i in range(total):
        t = i / RATE
        progress = i / total

        noise = random.uniform(-1.0, 1.0)
        filtered += coefficient * (noise - filtered)

        # The crack: near-instant attack, exponential decay.
        crack = math.exp(-t * (26.0 / seconds)) * crack_level * filtered

        # The body: a falling sine, which is the chamber and the barrel.
        sweep = body_hz * (1.0 + 1.6 * math.exp(-t * 18.0))
        phase += TAU * sweep / RATE
        body = math.sin(phase) * math.exp(-t * (7.0 / seconds)) * body_level

        # A tail of slower noise, for mechanism and for the rumble after a blast.
        tail = filtered * rattle * math.exp(-t * (3.4 / seconds)) \
            * (0.4 + 0.6 * math.sin(t * 41.0))

        value = crack + body + tail

        # Soft clip: real recordings saturate, and this keeps the peak honest
        # without the buzz that hard clipping adds.
        value = math.tanh(value * 1.35)

        # Fade the last 8% so the file cannot click when it ends.
        if progress > 0.92:
            value *= (1.0 - progress) / 0.08

        samples.append(int(max(-1.0, min(1.0, value)) * 32000))

    return samples


TAU = math.pi * 2


def write(path, samples):
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(struct.pack("<%dh" % len(samples), *samples))


def main() -> int:
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "godot/assets/audio"
    os.makedirs(out_dir, exist_ok=True)

    # A fixed seed so a rebuild produces byte-identical sounds.
    random.seed(20260830)

    for name, voice in VOICES.items():
        path = os.path.join(out_dir, name + ".wav")
        write(path, render(*voice))
        print("    audio  %-10s %6d bytes" % (name, os.path.getsize(path)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
