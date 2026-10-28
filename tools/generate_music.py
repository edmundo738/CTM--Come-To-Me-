"""Render the original Come To Me score and synchronized danger layer."""

from __future__ import annotations

import math
import struct
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "audio"
RATE = 44_100
BPM = 98.0
BEAT = 60.0 / BPM
BAR = BEAT * 4.0
TAU = math.tau
CHORDS = [
    (146.83, 174.61, 220.0, 261.63),
    (116.54, 146.83, 174.61, 220.0),
    (87.31, 110.0, 130.81, 164.81),
    (130.81, 164.81, 196.0, 246.94),
    (146.83, 174.61, 220.0, 261.63),
    (130.81, 164.81, 196.0, 246.94),
    (116.54, 146.83, 174.61, 220.0),
    (110.0, 138.59, 164.81, 207.65),
    (98.0, 116.54, 146.83, 174.61),
    (116.54, 146.83, 174.61, 220.0),
    (146.83, 174.61, 220.0, 261.63),
    (130.81, 164.81, 196.0, 246.94),
    (87.31, 110.0, 130.81, 164.81),
    (130.81, 164.81, 196.0, 246.94),
    (116.54, 146.83, 174.61, 220.0),
    (146.83, 174.61, 220.0, 293.66),
]
MELODY = (0, -1, 2, -1, 3, 2, -1, 4, 5, -1, 3, -1, 2, 0, -1, -1)
MELODY_SCALE = (293.66, 349.23, 392.0, 440.0, 523.25, 587.33, 659.25, 783.99)
ARP_ORDER = (0, 2, 1, 2, 3, 2, 1, 2)


def pcm16(value: float) -> int:
    return int(max(-0.95, min(0.95, value)) * 32767.0)


def render_main_theme(path: Path) -> None:
    duration = BAR * len(CHORDS)
    frames = bytearray()
    frame_count = round(RATE * duration)
    for index in range(frame_count):
        t = index / RATE
        bar_index = min(int(t / BAR), len(CHORDS) - 1)
        bar_position = t % BAR
        beat_index = int(bar_position / BEAT)
        beat_position = bar_position % BEAT
        step_duration = BEAT * 0.5
        step_index = int(bar_position / step_duration) % len(ARP_ORDER)
        step_position = bar_position % step_duration
        section = bar_index // 4
        chord = CHORDS[bar_index]
        pad_breath = 0.72 + math.sin(TAU * t / (BAR * 2.0)) * 0.12

        pad_left = 0.0
        pad_right = 0.0
        for note_index, frequency in enumerate(chord):
            gain = 0.018 if note_index < 3 else 0.011
            pad_left += math.sin(TAU * frequency * t) * gain * pad_breath
            pad_right += math.sin(TAU * frequency * 1.0025 * t) * gain * pad_breath

        arp_frequency = chord[ARP_ORDER[step_index]] * 2.0
        arp_envelope = min(1.0, step_position / 0.025) * max(0.0, 1.0 - step_position / 0.22)
        arp = (
            math.sin(TAU * arp_frequency * t) * 0.038
            + math.sin(TAU * arp_frequency * 2.01 * t) * 0.009
        ) * arp_envelope * (0.72 if section == 0 else 1.0)
        pan = 0.34 if step_index % 2 == 0 else 0.66

        bass = 0.0
        if beat_index in (0, 2):
            bass_envelope = math.exp(-beat_position * 5.5)
            bass = math.asin(math.sin(TAU * (chord[0] * 0.5) * t)) * (2.0 / math.pi) * 0.11 * bass_envelope

        lead_left = 0.0
        lead_right = 0.0
        melody_step = int(((bar_index % 2) * BAR + bar_position) / step_duration) % len(MELODY)
        melody_note = MELODY[melody_step]
        if 0 < section < 4 and melody_note >= 0:
            frequency = MELODY_SCALE[melody_note]
            envelope = math.exp(-step_position * 5.0) * min(1.0, step_position / 0.018)
            gain = 0.046 if section == 1 else 0.066 if section == 2 else 0.054
            lead_left = (math.sin(TAU * frequency * t) + math.sin(TAU * frequency * 2.0 * t) * 0.22) * gain * envelope
            lead_right = (math.sin(TAU * frequency * 1.003 * t) + math.sin(TAU * frequency * 2.006 * t) * 0.2) * gain * envelope

        kick = 0.0
        if section >= 1 and beat_index in (0, 2) and beat_position < 0.19:
            envelope = math.exp(-beat_position * 19.0)
            phase = TAU * (76.0 * beat_position - 75.0 * beat_position * beat_position)
            kick = math.sin(phase) * (0.14 if section < 3 else 0.09) * envelope

        snare = 0.0
        if section >= 1 and beat_index in (1, 3) and beat_position < 0.13:
            envelope = math.exp(-beat_position * 23.0)
            noise = (
                math.sin(TAU * 2417.0 * t) * 0.45
                + math.sin(TAU * 3121.0 * t) * 0.35
                + math.sin(TAU * 1749.0 * t) * 0.2
            )
            snare = noise * (0.075 if section == 2 else 0.052) * envelope

        hat = 0.0
        if section >= 1 and step_position < 0.032:
            envelope = max(0.0, 1.0 - step_position / 0.032)
            hat = math.sin(TAU * (5100.0 + (step_index % 2) * 380.0) * step_position) * 0.026 * envelope

        left = pad_left + arp * (1.0 - pan) * 1.35 + bass + lead_left * 0.94 + kick + snare + hat
        right = pad_right + arp * pan * 1.35 + bass + lead_right * 0.94 + kick + snare + hat
        fade = min(1.0, t / 0.025, (duration - t) / 0.025)
        frames.extend(struct.pack("<hh", pcm16(left * fade), pcm16(right * fade)))

    write_wave(path, frames)


def render_threat_layer(path: Path) -> None:
    roots = tuple(chord[0] for chord in CHORDS)
    duration = BAR * len(roots)
    frames = bytearray()
    frame_count = round(RATE * duration)
    for index in range(frame_count):
        t = index / RATE
        bar_index = min(int(t / BAR), len(roots) - 1)
        bar_position = t % BAR
        step_duration = BEAT * 0.5
        step_index = int(bar_position / step_duration) % 8
        step_position = bar_position % step_duration
        interval = 1.0 if step_index in (0, 3, 4, 7) else 1.5
        frequency = roots[bar_index] * interval
        envelope = math.exp(-step_position * 5.2) * min(1.0, step_position / 0.018)
        pulse = math.sin(TAU * frequency * t) * 0.045 + math.sin(TAU * frequency * 0.5 * t) * 0.034
        edge = math.sin(TAU * frequency * 2.0 * t) * 0.012
        value = (pulse + edge) * envelope
        fade = min(1.0, t / 0.025, (duration - t) / 0.025)
        frames.extend(struct.pack("<hh", pcm16(value * fade), pcm16(value * 0.84 * fade)))

    write_wave(path, frames)


def write_wave(path: Path, frames: bytearray) -> None:
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(frames)
    print(f"Wrote {path.relative_to(ROOT)} ({len(frames):,} bytes)")


if __name__ == "__main__":
    OUTPUT.mkdir(parents=True, exist_ok=True)
    render_main_theme(OUTPUT / "main_theme.wav")
    render_threat_layer(OUTPUT / "threat_layer.wav")
