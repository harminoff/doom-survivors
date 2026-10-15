"""Objective "does this sound like music" measures for generated tracks (numpy + scipy).

None of this replaces listening; it ranks candidates so the obviously bad ones
(noise, no beat, out of key, clipped, dead stretches) are not installed.

    metrics(audio, rate, bpm, tonic, minor) -> dict of measures and a total score

Measures (all roughly 0..1, higher is better):
  key_fit    share of pitch-class energy that falls in the target key's scale
  tonal      1 - spectral flatness: pure tones and chords score high, noise low
  beat       clarity of the strongest pulse in the onset envelope
  tempo      how close that pulse is to the target BPM (or a double/half of it)
  steady     even loudness over time, no dead sections
  clean      no clipping
  stable_key how consistent the key is between the four quarters of the track
"""
from __future__ import annotations

import numpy as np
from scipy import signal

MINOR = (0, 2, 3, 5, 7, 8, 10)
MAJOR = (0, 2, 4, 5, 7, 9, 11)
NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def _mono(audio: np.ndarray, rate: int, target: int = 22050) -> tuple[np.ndarray, int]:
    mono = audio.mean(axis=1) if audio.ndim == 2 else audio
    if rate != target:
        mono = signal.resample_poly(mono, target, rate)
    return mono.astype(np.float64), target


def _stft(mono: np.ndarray, n_fft: int = 2048, hop: int = 512) -> np.ndarray:
    _f, _t, z = signal.stft(mono, nperseg=n_fft, noverlap=n_fft - hop, boundary=None, padded=False)
    return np.abs(z)


def chroma(mag: np.ndarray, rate: int, n_fft: int = 2048) -> np.ndarray:
    """(12, frames) pitch-class energy from 60 Hz to 2.5 kHz."""
    freqs = np.fft.rfftfreq(n_fft, 1 / rate)
    bins = np.flatnonzero((freqs >= 60) & (freqs <= 2500))
    midi = 69 + 12 * np.log2(freqs[bins] / 440.0)
    pc = np.mod(np.round(midi).astype(int), 12)
    out = np.zeros((12, mag.shape[1]))
    for p in range(12):
        out[p] = (mag[bins[pc == p]] ** 2).sum(axis=0)
    return out


def key_fit(chroma_mean: np.ndarray, tonic: int, minor: bool) -> float:
    scale = MINOR if minor else MAJOR
    degrees = [(tonic + d) % 12 for d in scale]
    total = chroma_mean.sum() or 1.0
    return float(chroma_mean[degrees].sum() / total)


def beat_strength(mag: np.ndarray, rate: int, hop: int, bpm: float) -> tuple[float, float, float]:
    """Return (clarity, tempo score, detected bpm)."""
    log = np.log1p(mag * 50.0)
    flux = np.maximum(log[:, 1:] - log[:, :-1], 0).sum(axis=0)
    flux = flux - flux.mean()
    if flux.std() < 1e-9:
        return 0.0, 0.0, 0.0
    ac = signal.correlate(flux, flux, mode="full")[flux.size - 1:]
    ac = ac / (ac[0] or 1.0)
    fps = rate / hop
    lo, hi = int(fps * 60 / 200), int(fps * 60 / 60)
    seg = ac[lo:hi]
    k = int(np.argmax(seg))
    lag = lo + k
    clarity = float(np.clip(seg[k] / 0.5, 0, 1))
    detected = 60.0 * fps / lag
    ratio = detected / bpm
    best = min(abs(np.log2(ratio / r)) for r in (0.5, 1.0, 2.0))
    tempo = float(max(0.0, 1.0 - best * 3.0))
    return clarity, tempo, detected


def metrics(audio: np.ndarray, rate: int, bpm: float, tonic: str, minor: bool) -> dict:
    mono, r = _mono(audio, rate)
    hop = 512
    mag = _stft(mono, 2048, hop)
    freqs = np.fft.rfftfreq(2048, 1 / r)
    band = mag[(freqs >= 100) & (freqs <= 8000)] + 1e-9
    flat = float(np.mean(np.exp(np.mean(np.log(band), axis=0)) / np.mean(band, axis=0)))
    tonal = float(np.clip(1.0 - flat * 3.0, 0, 1))
    ch = chroma(mag, r)
    t0 = NOTE[tonic]
    fit = key_fit(ch.mean(axis=1), t0, minor)
    quarters = np.array_split(ch, 4, axis=1)
    fits = [key_fit(q.mean(axis=1), t0, minor) for q in quarters]
    stable = float(np.clip(1.0 - np.std(fits) * 6.0, 0, 1))
    clarity, tempo, detected = beat_strength(mag, r, hop, bpm)
    windows = np.array_split(np.abs(mono), max(4, int(len(mono) / r / 3)))
    rms = np.array([float(np.sqrt(np.mean(w ** 2))) for w in windows])
    quiet = float(np.mean(rms < 0.2 * (rms.max() or 1.0)))
    steady = float(np.clip(1.0 - np.std(rms) / (np.mean(rms) or 1.0) - quiet * 2.0, 0, 1))
    clean = float(1.0 - np.mean(np.abs(audio) > 0.99))
    scaled_fit = float(np.clip((fit - 0.58) / 0.35, 0, 1))      # 0.58 is what random pitches give
    consistent = tempo_consistency(mag, r, hop, bpm)
    total = (0.30 * scaled_fit + 0.20 * tonal + 0.18 * clarity + 0.12 * tempo
             + 0.10 * steady + 0.05 * stable + 0.05 * clean)
    return {"key_fit": fit, "tonal": tonal, "beat": clarity, "tempo": tempo, "bpm": detected,
            "steady": steady, "stable_key": stable, "clean": clean, "consistent": consistent,
            "score": float(total)}


def tempo_consistency(mag: np.ndarray, rate: int, hop: int, bpm: float, window_s: float = 15.0) -> float:
    """Share of 15 s windows whose pulse is the target tempo (or its half / double).
    A take where windows read as 2/3 or 3/2 of the target has two grooves fighting (a
    triplet layer over a straight one, or sections at different tempos): it sounds like
    several songs at once even when the whole-track tempo looks right."""
    frames = int(window_s * rate / hop)
    if mag.shape[1] < frames * 2:
        return 1.0
    ok = []
    for i in range(0, mag.shape[1] - frames + 1, frames):
        _c, _t, detected = beat_strength(mag[:, i:i + frames], rate, hop, bpm)
        ok.append(detected > 0 and any(abs(detected / (bpm * f) - 1) < 0.06 for f in (0.5, 1.0, 2.0)))
    return float(np.mean(ok))
