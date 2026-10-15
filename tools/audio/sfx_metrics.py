"""Objective measures for generated sound effects (numpy only).

A good game effect is ONE clean event: a fast attack, a decay, no stray extra
sounds, no background hiss. This finds the first event in a clip and scores it.

    analyse(audio, rate) -> dict
      event      the first event as a mono array (leading silence removed)
      single     share of the clip's energy inside that event (1 = nothing else)
      attack_ms  time from the event's start to its peak
      length_s   event length until it falls 40 dB below its peak
      len24      length until it last rises above -24 dB of its peak (the audible part)
      floor_db   background level after the event relative to the peak (lower = cleaner)
      centroid   spectral centroid in Hz (brightness)
      flat       spectral flatness 0..1 (0 = pure tone, 1 = noise)
"""
from __future__ import annotations

import numpy as np


def _mono(audio: np.ndarray) -> np.ndarray:
    return audio.mean(axis=1) if audio.ndim == 2 else audio


def _envelope(x: np.ndarray, rate: int, win_ms: float = 5.0) -> np.ndarray:
    win = max(1, int(rate * win_ms / 1000))
    padded = np.pad(np.abs(x), (0, win - len(x) % win if len(x) % win else 0))
    return padded.reshape(-1, win).max(axis=1)


def analyse(audio: np.ndarray, rate: int, gap_ms: float = 150.0, floor_db: float = -40.0) -> dict:
    x = _mono(audio).astype(np.float64)
    x = x - x.mean()
    peak = float(np.max(np.abs(x))) or 1.0
    env = _envelope(x, rate)
    step = 5.0 / 1000
    db = 20 * np.log10(env / peak + 1e-9)
    live = db > floor_db
    if not live.any():
        return {"event": x[:1], "single": 0.0, "attack_ms": 0.0, "length_s": 0.0, "floor_db": 0.0,
                "centroid": 0.0, "flat": 1.0}
    first = int(np.argmax(live))
    gap = int(gap_ms / 5)
    end = first
    quiet = 0
    for i in range(first, len(live)):
        if live[i]:
            end = i
            quiet = 0
        else:
            quiet += 1
            if quiet >= gap:
                break
    s0, s1 = first * int(rate * step), min(len(x), (end + 1) * int(rate * step))
    event = x[s0:s1]
    total_energy = float(np.sum(x ** 2)) or 1.0
    single = float(np.sum(event ** 2) / total_energy)
    peak_i = int(np.argmax(np.abs(event)))
    attack_ms = peak_i / rate * 1000
    tail = x[s1:]
    floor = 20 * np.log10(float(np.sqrt(np.mean(tail ** 2))) / peak + 1e-9) if tail.size > rate * 0.05 else -90.0
    spectrum = np.abs(np.fft.rfft(event * np.hanning(len(event)))) + 1e-12
    freqs = np.fft.rfftfreq(len(event), 1 / rate)
    centroid = float((spectrum * freqs).sum() / spectrum.sum())
    flat = float(np.exp(np.mean(np.log(spectrum[(freqs > 100) & (freqs < 10000)]))) / np.mean(spectrum[(freqs > 100) & (freqs < 10000)]))
    # effective length: until the event last rises above -24 dB of its peak (tails below that
    # are inaudible next to music and get trimmed)
    ev_env = _envelope(event, rate)
    ev_db = 20 * np.log10(ev_env / (float(np.max(ev_env)) or 1.0) + 1e-9)
    loud = np.flatnonzero(ev_db > -24.0)
    len24 = float((loud[-1] + 1) * 0.005) if loud.size else 0.0
    return {"event": event, "single": single, "attack_ms": attack_ms, "length_s": len(event) / rate, "len24": len24,
            "floor_db": float(floor), "centroid": centroid, "flat": flat}


def finish_event(event: np.ndarray, rate: int, fade_in_ms: float = 2.0, fade_out_ms: float = 40.0) -> np.ndarray:
    """Short fades so the clip starts and ends at zero (no clicks)."""
    out = event.astype(np.float32).copy()
    fi = min(len(out), int(rate * fade_in_ms / 1000))
    fo = min(len(out), int(rate * fade_out_ms / 1000))
    if fi:
        out[:fi] *= np.linspace(0.0, 1.0, fi, dtype=np.float32)
    if fo:
        out[-fo:] *= np.linspace(1.0, 0.0, fo, dtype=np.float32)
    return out
