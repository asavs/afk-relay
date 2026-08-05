#!/usr/bin/env python3
"""Compose and render AFK Relay's original 90-second lobby piece.

The cue is through-composed across thirty bars. Its central gesture passes a
steady, footstep-like pulse into a clean electronic pulse: real movement being
relayed into digital agency. No bar reuses an identical lead melody.
"""

from __future__ import annotations

import math
import random
import struct
import subprocess
import tempfile
import wave
from array import array
from pathlib import Path

SAMPLE_RATE = 44_100
BPM = 80
BEAT = 60 / BPM
BAR = 4 * BEAT
BARS = 30
DURATION = BARS * BAR
OUTPUT = Path(__file__).resolve().parents[1] / "AFKRelay" / "Audio" / "lobby-relay.m4a"
# Ninety seconds of stereo PCM is 15 MB; the same loop as AAC is 1.4 MB. The
# track fades from and to silence, so the encoder's padding leaves no seam.
AAC_BITRATE = 128_000
TAU = 2 * math.pi

left = array("f", [0.0]) * round(DURATION * SAMPLE_RATE)
right = array("f", [0.0]) * len(left)


def hz(midi_note: float) -> float:
    return 440.0 * 2 ** ((midi_note - 69) / 12)


def smoothstep(value: float) -> float:
    value = max(0.0, min(1.0, value))
    return value * value * (3 - 2 * value)


def pan_gains(pan: float) -> tuple[float, float]:
    angle = (max(-1.0, min(1.0, pan)) + 1) * math.pi / 4
    return math.cos(angle), math.sin(angle)


def add_tone(
    start: float,
    duration: float,
    note: float,
    amplitude: float,
    pan: float,
    voice: str,
) -> None:
    first = max(0, round(start * SAMPLE_RATE))
    final = min(len(left), round((start + duration) * SAMPLE_RATE))
    if final <= first:
        return

    frequency = hz(note)
    gain_l, gain_r = pan_gains(pan)
    phase_seed = (note * 0.173 + start * 0.071) % 1.0
    phase = TAU * phase_seed

    for index in range(first, final):
        t = index / SAMPLE_RATE - start
        progress = t / duration

        if voice == "pad":
            attack = smoothstep(t / 0.72)
            release = smoothstep((duration - t) / 1.15)
            breath = 0.92 + 0.08 * math.sin(TAU * 0.083 * t + phase)
            sample = (
                math.sin(TAU * frequency * t + phase)
                + 0.19 * math.sin(TAU * frequency * 2.003 * t + phase * 0.7)
            ) * attack * release * breath
        elif voice == "felt":
            attack = smoothstep(t / 0.012)
            release = math.exp(-3.7 * progress)
            sample = (
                math.sin(TAU * frequency * t + phase)
                + 0.22 * math.sin(TAU * frequency * 2 * t + phase)
                + 0.08 * math.sin(TAU * frequency * 3.01 * t)
            ) * attack * release
        elif voice == "glass":
            attack = smoothstep(t / 0.045)
            release = math.exp(-2.25 * progress)
            shimmer = 0.82 + 0.18 * math.sin(TAU * 4.2 * t)
            sample = (
                0.72 * math.sin(TAU * frequency * t + phase)
                + 0.24 * math.sin(TAU * frequency * 2.01 * t)
                + 0.12 * math.sin(TAU * frequency * 3.98 * t + phase)
            ) * attack * release * shimmer
        elif voice == "relay":
            attack = smoothstep(t / 0.004)
            release = math.exp(-8.5 * progress)
            sample = (
                math.sin(TAU * frequency * t + phase)
                + 0.13 * math.sin(TAU * frequency * 1.5 * t)
            ) * attack * release
        else:
            raise ValueError(f"Unknown voice: {voice}")

        value = amplitude * sample
        left[index] += value * gain_l
        right[index] += value * gain_r


def add_lead_note(
    beat: float,
    note: float,
    beats_long: float,
    amplitude: float,
    pan: float,
    voice: str = "felt",
) -> None:
    start = beat * BEAT
    duration = beats_long * BEAT
    add_tone(start, duration, note, amplitude, pan, voice)


def add_step(beat: float, strength: float, pan: float, seed: int) -> None:
    start = beat * BEAT
    duration = 0.19
    first = round(start * SAMPLE_RATE)
    final = min(len(left), round((start + duration) * SAMPLE_RATE))
    gain_l, gain_r = pan_gains(pan)
    noise = random.Random(seed)

    phase = 0.0
    for index in range(first, final):
        t = index / SAMPLE_RATE - start
        progress = t / duration
        frequency = 76 - 29 * smoothstep(progress)
        phase += TAU * frequency / SAMPLE_RATE
        body = math.sin(phase) * math.exp(-17 * t)
        sole = noise.uniform(-1, 1) * math.exp(-42 * t)
        value = strength * (0.74 * body + 0.12 * sole)
        left[index] += value * gain_l
        right[index] += value * gain_r


def add_air() -> None:
    """A quiet deterministic room tone that slowly opens, then recedes."""
    noise = random.Random(0xAF4E1A7)
    low = 0.0
    for index in range(len(left)):
        t = index / SAMPLE_RATE
        low += 0.018 * (noise.uniform(-1, 1) - low)
        arc = math.sin(math.pi * t / DURATION) ** 1.4
        drift = 0.72 + 0.28 * math.sin(TAU * 0.017 * t)
        value = low * 0.011 * arc * drift
        left[index] += value
        right[index] -= value * 0.64


# Thirty related voicings in D major / B minor. Every change lands exactly on
# a bar line, and the lead uses only chord tones or consonant scale neighbours.
CHORDS = [
    (38, 45, 52, 64), (37, 45, 52, 61), (35, 42, 50, 62), (31, 38, 47, 54),
    (33, 45, 52, 57), (28, 35, 47, 52), (31, 38, 45, 50), (33, 40, 45, 52),
    (35, 42, 50, 57), (31, 38, 47, 54), (38, 45, 52, 64), (33, 40, 45, 50),
    (28, 35, 47, 52), (38, 42, 50, 57), (31, 38, 47, 54), (33, 40, 45, 52),
    (38, 45, 52, 64), (30, 37, 45, 52), (31, 38, 47, 54), (33, 40, 45, 52),
    (35, 42, 50, 57), (37, 45, 52, 61), (42, 45, 50, 57), (31, 38, 47, 54),
    (28, 35, 47, 52), (33, 40, 45, 50), (42, 45, 50, 57), (35, 42, 50, 57),
    (31, 38, 45, 54), (38, 45, 52, 64),
]


# Hand-shaped, grid-locked lead. Strong beats are chord tones, passing notes
# stay in D major, and every bar has a different rhythmic or interval contour.
MELODY = {
    2: ((0.0, 62, 1.0), (1.5, 66, 0.5), (2.0, 69, 1.5)),
    3: ((0.0, 67, 1.5), (2.0, 66, 0.5), (3.0, 62, 1.0)),
    4: ((0.0, 69, 1.0), (1.0, 66, 1.0), (2.5, 64, 1.0)),
    5: ((0.0, 64, 1.5), (2.0, 67, 1.0), (3.0, 71, 1.0)),
    6: ((0.0, 67, 0.5), (0.5, 69, 0.5), (1.0, 71, 1.0), (2.5, 69, 1.0)),
    7: ((0.0, 69, 1.0), (1.5, 73, 0.5), (2.0, 76, 1.5)),
    8: ((0.0, 71, 1.5), (2.0, 69, 0.5), (2.5, 66, 1.0)),
    9: ((0.0, 67, 1.0), (1.0, 71, 1.0), (2.5, 74, 1.0)),
    10: ((0.0, 74, 0.5), (0.5, 73, 0.5), (1.0, 69, 1.0), (2.0, 66, 1.5)),
    11: ((0.0, 69, 1.5), (2.0, 64, 1.0), (3.0, 61, 1.0)),
    12: ((0.0, 64, 1.0), (1.0, 67, 0.5), (1.5, 71, 0.5), (2.0, 76, 1.5)),
    13: ((0.0, 74, 1.0), (1.5, 71, 0.5), (2.0, 66, 1.5)),
    14: ((0.0, 67, 0.5), (0.5, 69, 0.5), (1.0, 74, 1.0), (2.5, 71, 1.0)),
    15: ((0.0, 69, 1.0), (1.0, 73, 1.0), (2.0, 76, 0.5), (3.0, 73, 1.0)),
    16: ((0.0, 74, 1.5), (2.0, 69, 0.5), (2.5, 66, 1.0)),
    17: ((0.0, 73, 0.5), (0.5, 76, 0.5), (1.0, 78, 1.0), (2.0, 76, 1.5)),
    18: ((0.0, 74, 1.0), (1.5, 71, 0.5), (2.0, 67, 1.5)),
    19: ((0.0, 69, 1.5), (2.0, 73, 1.0), (3.0, 76, 1.0)),
    20: ((0.0, 71, 0.5), (0.5, 74, 0.5), (1.0, 78, 1.0), (2.5, 74, 1.0)),
    21: ((0.0, 73, 1.0), (1.0, 76, 1.0), (2.0, 69, 1.5)),
    22: ((0.0, 69, 1.5), (2.0, 66, 0.5), (2.5, 62, 1.0)),
    23: ((0.0, 67, 1.0), (1.5, 71, 0.5), (2.0, 74, 1.5)),
    24: ((0.0, 64, 0.5), (0.5, 67, 0.5), (1.0, 71, 1.0), (2.0, 76, 1.5)),
    25: ((0.0, 73, 1.0), (1.0, 69, 1.0), (2.5, 64, 1.0)),
    26: ((0.0, 66, 1.5), (2.0, 69, 0.5), (2.5, 74, 1.0)),
    27: ((0.0, 71, 1.0), (1.5, 69, 0.5), (2.0, 66, 1.5)),
    28: ((0.0, 67, 0.5), (0.5, 69, 0.5), (1.0, 74, 1.0), (2.5, 69, 1.0)),
    29: ((0.0, 66, 1.0), (1.0, 64, 1.0), (2.0, 62, 2.0)),
}


def compose() -> None:
    add_air()

    for bar, chord in enumerate(CHORDS):
        start = bar * BAR
        intensity = 0.72 + 0.28 * math.sin(math.pi * bar / (BARS - 1))
        for voice_index, note in enumerate(chord):
            pan = (-0.52, -0.18, 0.20, 0.54)[voice_index]
            level = (0.043, 0.037, 0.030, 0.027)[voice_index] * intensity
            add_tone(start, BAR, note, level, pan, "pad")

    for bar, notes in MELODY.items():
        section = bar // 6
        for note_index, (offset, note, length) in enumerate(notes):
            pan = (-0.32, 0.24, 0.46, -0.12)[(bar + note_index) % 4]
            voice = "glass" if section in (0, 4) else "felt"
            amplitude = 0.072 + 0.007 * min(section, 2)
            add_lead_note(bar * 4 + offset, note, length, amplitude, pan, voice)

    # A steady walking pulse: every onset is on the shared quarter-note grid.
    for beat_index in range(8, BARS * 4 - 5):
        bar = beat_index // 4
        if bar >= 24 and beat_index % 2:
            continue
        strength = 0.052 if beat_index % 2 == 0 else 0.028
        if 12 <= bar < 23:
            strength *= 1.24
        add_step(beat_index, strength, -0.18 if beat_index % 2 else 0.18, 7100 + beat_index)

    # A chord-aware eighth-note relay takes over without fighting the melody.
    patterns = (
        (0, 1, 2, 1, 3, 2, 1, 2),
        (0, 2, 1, 3, 2, 1, 3, 1),
        (0, 1, 3, 2, 1, 2, 3, 2),
    )
    for half_beat in range(48, BARS * 8 - 24):
        beat = half_beat / 2
        bar = int(beat // 4)
        position = half_beat % 8
        chord_index = patterns[bar % len(patterns)][position]
        note = CHORDS[bar][chord_index]
        note += 24 if note < 48 else 12
        level = 0.018 if half_beat % 2 else 0.025
        if 11 <= bar <= 22:
            level *= 1.22
        add_tone(beat * BEAT, 0.18, note, level, 0.36 if half_beat % 2 else -0.36, "relay")

    # Section thresholds answer on beats one and three using target-chord tones.
    for bar in (4, 10, 17, 24):
        chord = CHORDS[bar]
        first = chord[2] + 24
        answer = chord[1] + 24
        add_tone(bar * BAR, 1.5, first, 0.038, -0.58, "glass")
        add_tone(bar * BAR + 2 * BEAT, 1.35, answer, 0.032, 0.58, "glass")


def write_audio() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    peak = max(max(abs(value) for value in left), max(abs(value) for value in right), 1e-9)
    gain = 0.86 / peak
    fade_in = 1.6
    fade_out = 3.8

    frames = bytearray()
    for index, (sample_l, sample_r) in enumerate(zip(left, right)):
        t = index / SAMPLE_RATE
        fade = min(smoothstep(t / fade_in), smoothstep((DURATION - t) / fade_out))
        # Soft saturation keeps layered peaks cohesive without brick-wall clipping.
        value_l = math.tanh(sample_l * gain * 1.18) / math.tanh(1.18) * fade
        value_r = math.tanh(sample_r * gain * 1.18) / math.tanh(1.18) * fade
        frames.extend(struct.pack("<hh", round(value_l * 32767), round(value_r * 32767)))

    with tempfile.TemporaryDirectory() as scratch:
        intermediate = Path(scratch) / "lobby-relay.wav"
        with wave.open(str(intermediate), "wb") as output:
            output.setnchannels(2)
            output.setsampwidth(2)
            output.setframerate(SAMPLE_RATE)
            output.writeframes(frames)
        encode(intermediate, OUTPUT)


def encode(source: Path, destination: Path) -> None:
    subprocess.run(
        [
            "afconvert",
            "-f", "m4af",
            "-d", "aac",
            "-b", str(AAC_BITRATE),
            "-q", "127",
            "-s", "3",
            str(source),
            str(destination),
        ],
        check=True,
    )


if __name__ == "__main__":
    compose()
    write_audio()
    print(f"Wrote {OUTPUT} ({DURATION:.1f}s)")
