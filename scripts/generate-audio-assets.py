#!/usr/bin/env python3
"""Generate AFK Relay's original diagnostic gameplay sounds."""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 44_100
OUTPUT = Path(__file__).resolve().parents[1] / "AFKRelay" / "Audio"


def envelope(t: float, duration: float, attack: float = 0.008, release: float = 0.08) -> float:
    return min(1.0, t / attack) * min(1.0, (duration - t) / release)


def chirp(t: float, duration: float, start: float, end: float) -> float:
    sweep = (end - start) / duration
    return math.sin(2 * math.pi * (start * t + 0.5 * sweep * t * t))


def write(name: str, duration: float, sample) -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    frames = []
    peak = 0.0
    values = []
    for index in range(round(duration * SAMPLE_RATE)):
        t = index / SAMPLE_RATE
        value = sample(t, duration)
        values.append(value)
        peak = max(peak, abs(value))
    gain = 0.82 / max(peak, 1.0)
    for value in values:
        frames.append(struct.pack("<h", round(max(-1, min(1, value * gain)) * 32767)))
    with wave.open(str(OUTPUT / name), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(b"".join(frames))


def main() -> None:
    noise = random.Random(0xAF4E1A7)
    noise_values = [noise.uniform(-1, 1) for _ in range(SAMPLE_RATE)]

    write(
        "button-press.wav",
        0.09,
        lambda t, d: envelope(t, d, attack=0.001, release=0.055)
        * (0.62 * chirp(t, d, 980, 620)
           + 0.25 * noise_values[int(t * SAMPLE_RATE)] * math.exp(-45 * t)),
    )
    write(
        "game-over.wav",
        0.82,
        lambda t, d: envelope(t, d, attack=0.004, release=0.30)
        * (0.42 * chirp(t, d, 330, 110)
           + 0.28 * chirp(t, d, 247, 82)
           + 0.20 * chirp(t, d, 196, 65)
           + 0.10 * noise_values[int(t * SAMPLE_RATE)] * math.exp(-24 * t)),
    )

    write(
        "sweep-telegraph.wav",
        0.34,
        lambda t, d: envelope(t, d, release=0.06)
        * (0.72 * chirp(t, d, 240, 520) + 0.18 * math.sin(2 * math.pi * 960 * t)),
    )
    write(
        "sweep-active.wav",
        0.25,
        lambda t, d: envelope(t, d, attack=0.003, release=0.11)
        * (0.55 * chirp(t, d, 760, 150) + 0.32 * noise_values[int(t * SAMPLE_RATE)]),
    )
    write(
        "shot-telegraph.wav",
        0.30,
        lambda t, d: envelope(t, d, attack=0.004, release=0.04)
        * (0.62 * chirp(t, d, 580, 920) + 0.22 * math.sin(2 * math.pi * 1160 * t))
        * (1.0 if int(t / 0.075) % 2 == 0 else 0.32),
    )
    write(
        "shot-active.wav",
        0.17,
        lambda t, d: envelope(t, d, attack=0.0015, release=0.07)
        * (0.76 * chirp(t, d, 1700, 430) + 0.18 * noise_values[int(t * SAMPLE_RATE)]),
    )
    write(
        "player-damage.wav",
        0.24,
        lambda t, d: envelope(t, d, attack=0.002, release=0.13)
        * (0.68 * chirp(t, d, 125, 52) + 0.28 * noise_values[int(t * SAMPLE_RATE)] * math.exp(-18 * t)),
    )
    write(
        "friendly-fire.wav",
        0.22,
        lambda t, d: envelope(t, d, attack=0.0015, release=0.10)
        * (0.48 * math.sin(2 * math.pi * 720 * t) + 0.34 * math.sin(2 * math.pi * 1080 * t)
           + 0.16 * noise_values[int(t * SAMPLE_RATE)] * math.exp(-22 * t)),
    )
    write(
        "friendly-fire-discovery.wav",
        0.58,
        lambda t, d: envelope(t, d, attack=0.003, release=0.22)
        * (0.38 * math.sin(2 * math.pi * 540 * t) + 0.31 * math.sin(2 * math.pi * 810 * t)
           + 0.23 * math.sin(2 * math.pi * 1080 * t) + 0.10 * chirp(t, d, 900, 1500)),
    )
    # A relay being severed: a dry conductor snap, a descending two-tone
    # break, then a compact low confirmation. Kept short so a kill reads as
    # final without masking the next telegraph.
    write(
        "friendly-fire-defeat.wav",
        0.46,
        lambda t, d: envelope(t, d, attack=0.001, release=0.18)
        * (0.30 * noise_values[int(t * SAMPLE_RATE)] * math.exp(-52 * t)
           + 0.38 * chirp(t, d, 610, 138)
           + 0.24 * chirp(t, d, 457, 92)
           + 0.18 * math.sin(2 * math.pi * 73 * t) * min(1.0, t / 0.055)),
    )


if __name__ == "__main__":
    main()
