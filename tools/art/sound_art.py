"""Generate the sound effects (original, synthesized in code).

Retro-style effects made from oscillators, noise and envelopes, written as
22050 Hz mono 16-bit WAV files to src/resources/sounds/, plus the SNDINFO
lump that names them (ds/<name>). Presentation only.
Run: python tools/art/sound_art.py
"""
from __future__ import annotations

import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
SOUNDS = ROOT / "src/resources/sounds"
SNDINFO = ROOT / "src/resources/SNDINFO"
RATE = 22050


def t(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def env(n, attack=0.005, release=0.1, total=None):
    total = total or n / RATE
    x = np.arange(n) / RATE
    a = np.clip(x / max(attack, 1e-4), 0, 1)
    r = np.clip((total - x) / max(release, 1e-4), 0, 1)
    return a * r


def square(freq, x):
    return np.sign(np.sin(2 * np.pi * np.cumsum(np.broadcast_to(freq, x.shape)) / RATE))


def tri(freq, x):
    phase = np.cumsum(np.broadcast_to(freq, x.shape)) / RATE
    return 2 * np.abs(2 * (phase % 1) - 1) - 1


def sine(freq, x):
    return np.sin(2 * np.pi * np.cumsum(np.broadcast_to(freq, x.shape)) / RATE)


def noise(x, seed=1):
    return np.random.default_rng(seed).uniform(-1, 1, x.shape)


def lowpass(sig, k=4):
    kernel = np.ones(k) / k
    return np.convolve(sig, kernel, mode="same")


def tone_seq(notes, dur, wave_fn=square, vol=0.35, gap=0.0):
    out = []
    for f in notes:
        x = t(dur)
        s = wave_fn(np.full(x.shape, f), x) * env(len(x), 0.003, dur * 0.6)
        out.append(s)
        if gap:
            out.append(np.zeros(int(RATE * gap)))
    return np.concatenate(out) * vol


def hz(note):
    return 440.0 * 2 ** ((note - 69) / 12)


def make():
    s = {}
    x = t(0.07)
    s["hit"] = lowpass(noise(x, 2), 3) * env(len(x), 0.001, 0.06) * 0.35 + square(np.linspace(300, 120, len(x)), x) * env(len(x), 0.001, 0.05) * 0.15
    x = t(0.16)
    s["death"] = square(np.linspace(520, 90, len(x)), x) * env(len(x), 0.002, 0.14) * 0.22 + lowpass(noise(x, 3), 6) * env(len(x), 0.001, 0.1) * 0.2
    x = t(0.09)
    s["gem"] = sine(np.linspace(1500, 2300, len(x)), x) * env(len(x), 0.002, 0.07) * 0.3
    s["coin"] = tone_seq([hz(88), hz(95)], 0.06, square, 0.22)
    s["levelup"] = tone_seq([hz(n) for n in (72, 76, 79, 84, 88)], 0.075, square, 0.25)
    s["chest"] = tone_seq([hz(n) for n in (67, 71, 74, 79, 83, 86, 91)], 0.06, tri, 0.4)
    x = t(0.22)
    s["hurt"] = square(np.linspace(180, 60, len(x)), x) * env(len(x), 0.002, 0.2) * 0.3 + lowpass(noise(x, 4), 8) * env(len(x), 0.001, 0.15) * 0.25
    s["heal"] = tone_seq([hz(n) for n in (76, 81, 88)], 0.08, sine, 0.3)
    x = t(0.12)
    s["whip"] = lowpass(noise(x, 5), 2) * env(len(x), 0.03, 0.08) * 0.28
    x = t(0.08)
    s["shoot"] = square(np.linspace(900, 400, len(x)), x) * env(len(x), 0.001, 0.07) * 0.12
    x = t(0.9)
    shimmer = sum(sine(np.full(x.shape, hz(n)), x) for n in (79, 83, 86, 91)) / 4
    s["arcana"] = shimmer * env(len(x), 0.2, 0.6) * 0.35 * (0.6 + 0.4 * sine(np.full(x.shape, 7.0), x))
    x = t(1.8)
    hit = (square(np.full(x.shape, hz(40)), x) * 0.5 + square(np.full(x.shape, hz(47)), x) * 0.35
           + square(np.full(x.shape, hz(52)), x) * 0.25)
    drop = square(np.linspace(hz(64), hz(40), len(x)), x) * 0.25
    s["boss"] = lowpass(hit + drop, 3) * env(len(x), 0.02, 1.2) * 0.3
    x = t(1.6)
    drone = square(np.full(x.shape, hz(33)), x) * 0.5 + tri(np.full(x.shape, hz(34)), x) * 0.5
    s["reaper"] = lowpass(drone, 6) * env(len(x), 0.4, 0.8) * 0.4
    fan = [hz(n) for n in (67, 71, 74, 79, 74, 79, 83, 86)]
    x = t(0.16)
    lead = np.concatenate([square(np.full(t(0.16).shape, f), t(0.16)) * env(len(t(0.16)), 0.004, 0.1) for f in fan]) * 0.22
    y = t(0.5); tail = sum(square(np.full(y.shape, hz(n)), y) for n in (67, 71, 74, 86)) / 4 * env(len(y), 0.01, 0.45) * 0.3
    s["victory"] = np.concatenate([lead, tail])
    down = [hz(n) for n in (67, 63, 60, 55, 51, 48)]
    lead = np.concatenate([tri(np.full(t(0.28).shape, f), t(0.28)) * env(len(t(0.28)), 0.01, 0.2) for f in down]) * 0.4
    y = t(0.9); tail = sum(tri(np.full(y.shape, hz(n)), y) for n in (36, 43, 51)) / 3 * env(len(y), 0.02, 0.85) * 0.5
    s["defeat"] = np.concatenate([lead, tail])
    s["menu"] = tone_seq([hz(84)], 0.04, square, 0.15)
    s["confirm"] = tone_seq([hz(79), hz(86)], 0.05, square, 0.18)
    x = t(0.5)
    s["revive"] = sine(np.linspace(300, 1200, len(x)), x) * env(len(x), 0.05, 0.3) * 0.35
    x = t(0.35)
    s["freeze"] = sum(sine(np.full(x.shape, f), x) for f in (1800, 2400, 3100)) / 3 * env(len(x), 0.005, 0.3) * 0.25
    return s


def write(name, sig):
    sig = np.clip(sig, -1, 1)
    data = (sig * 32767).astype("<i2").tobytes()
    with wave.open(str(SOUNDS / f"ds{name}.wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(data)


def main():
    SOUNDS.mkdir(parents=True, exist_ok=True)
    sounds = make()
    lines = ["// GENERATED by tools/art/sound_art.py. Do not edit.", ""]
    for name, sig in sounds.items():
        write(name, sig)
        lines.append(f"ds/{name} ds{name}")
    # The shell menu's built-in sound names use the same blips.
    lines += ["", "menu/cursor dsmenu", "menu/choose dsconfirm", "menu/backup dsmenu", "menu/change dsconfirm"]
    lines += ["", "$limit ds/hit 4", "$limit ds/death 4", "$limit ds/gem 3", "$limit ds/shoot 3", ""]
    SNDINFO.write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {len(sounds)} sounds and SNDINFO")


if __name__ == "__main__":
    main()
