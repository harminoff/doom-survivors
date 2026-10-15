"""Small mixing toolkit (numpy + scipy): loudness measurement, EQ filters, limiter.

Loudness follows ITU-R BS.1770 closely enough for balancing: K-weighting (a high
shelf and a high-pass), mean-square, -0.691 offset. `lufs` is gated integrated
loudness for long material (music); `event_lufs` is the loudness of a short sound
over its own length (the 400 ms gating window would under-read it).
"""
from __future__ import annotations

import numpy as np
from scipy import signal


def _biquad(kind: str, rate: int, f0: float, q: float = 0.7071, gain_db: float = 0.0):
    a_lin = 10 ** (gain_db / 40)
    w0 = 2 * np.pi * f0 / rate
    cw, sw = np.cos(w0), np.sin(w0)
    alpha = sw / (2 * q)
    if kind == "peak":
        b = [1 + alpha * a_lin, -2 * cw, 1 - alpha * a_lin]
        a = [1 + alpha / a_lin, -2 * cw, 1 - alpha / a_lin]
    elif kind == "highshelf":
        s = 2 * np.sqrt(a_lin) * alpha
        b = [a_lin * ((a_lin + 1) + (a_lin - 1) * cw + s), -2 * a_lin * ((a_lin - 1) + (a_lin + 1) * cw),
             a_lin * ((a_lin + 1) + (a_lin - 1) * cw - s)]
        a = [(a_lin + 1) - (a_lin - 1) * cw + s, 2 * ((a_lin - 1) - (a_lin + 1) * cw),
             (a_lin + 1) - (a_lin - 1) * cw - s]
    elif kind == "lowshelf":
        s = 2 * np.sqrt(a_lin) * alpha
        b = [a_lin * ((a_lin + 1) - (a_lin - 1) * cw + s), 2 * a_lin * ((a_lin - 1) - (a_lin + 1) * cw),
             a_lin * ((a_lin + 1) - (a_lin - 1) * cw - s)]
        a = [(a_lin + 1) + (a_lin - 1) * cw + s, -2 * ((a_lin - 1) + (a_lin + 1) * cw),
             (a_lin + 1) + (a_lin - 1) * cw - s]
    elif kind == "highpass":
        b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "lowpass":
        b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    else:
        raise ValueError(kind)
    b = np.array(b) / a[0]
    a = np.array(a) / a[0]
    return b, a


def apply(x: np.ndarray, kind: str, rate: int, f0: float, q: float = 0.7071, gain_db: float = 0.0) -> np.ndarray:
    """One biquad over (samples,) or (samples, channels)."""
    b, a = _biquad(kind, rate, f0, q, gain_db)
    return signal.lfilter(b, a, x, axis=0).astype(np.float32)


def highpass(x, rate, f0, order: int = 2):
    for _ in range(order // 2 or 1):
        x = apply(x, "highpass", rate, f0, 0.7071)
    return x


def k_weight(x: np.ndarray, rate: int) -> np.ndarray:
    x = apply(x, "highshelf", rate, 1681.97, 0.7071, 3.99984)
    return apply(x, "highpass", rate, 38.1355, 0.5003)


def _mean_square(x: np.ndarray) -> float:
    ms = np.mean(x.astype(np.float64) ** 2, axis=0)
    return float(np.sum(ms))          # channels summed, as in BS.1770 for L/R


def event_lufs(x: np.ndarray, rate: int) -> float:
    """Loudness of a short sound over its own length."""
    ms = _mean_square(k_weight(x, rate))
    return -0.691 + 10 * np.log10(ms + 1e-12)


def lufs(x: np.ndarray, rate: int) -> float:
    """Gated integrated loudness (400 ms blocks, 75% overlap, -70 abs / -10 LU relative gate)."""
    k = k_weight(x, rate)
    block, hop = int(0.4 * rate), int(0.1 * rate)
    if len(k) < block:
        return event_lufs(x, rate)
    ms = np.array([_mean_square(k[i:i + block]) for i in range(0, len(k) - block + 1, hop)])
    loud = -0.691 + 10 * np.log10(ms + 1e-12)
    keep = loud > -70.0
    if not keep.any():
        return -70.0
    rel = -0.691 + 10 * np.log10(np.mean(ms[keep]) + 1e-12) - 10.0
    keep &= loud > rel
    return float(-0.691 + 10 * np.log10(np.mean(ms[keep]) + 1e-12))


def peak_db(x: np.ndarray) -> float:
    return 20 * np.log10(float(np.max(np.abs(x))) + 1e-12)


def limit(x: np.ndarray, rate: int, ceiling_db: float = -1.0, lookahead_ms: float = 3.0,
          release_ms: float = 80.0) -> np.ndarray:
    """Look-ahead peak limiter: never exceeds the ceiling, smooth gain changes."""
    ceiling = 10 ** (ceiling_db / 20)
    env = np.max(np.abs(x), axis=1) if x.ndim == 2 else np.abs(x)
    need = np.minimum(1.0, ceiling / (env + 1e-12))
    la = max(1, int(rate * lookahead_ms / 1000))
    from scipy.ndimage import minimum_filter1d
    gain = minimum_filter1d(need, size=2 * la + 1, mode="nearest")
    rel = np.exp(-1.0 / (rate * release_ms / 1000))
    out = np.empty_like(gain)
    g = 1.0
    for i, target in enumerate(gain):          # instant attack (already look-ahead), smooth release
        g = target if target < g else g * rel + target * (1 - rel)
        out[i] = min(g, target) if target < g else g
    out = np.minimum(out, need)
    return (x * (out[:, None] if x.ndim == 2 else out)).astype(np.float32)


def to_db(gain: float) -> float:
    return 20 * np.log10(gain + 1e-12)


def from_db(db: float) -> float:
    return 10 ** (db / 20)


def band_levels(x: np.ndarray, rate: int, edges=(40, 100, 200, 400, 800, 1600, 3200, 6400, 12800)) -> list[float]:
    """Energy share (%) of each octave band."""
    mono = x.mean(axis=1) if x.ndim == 2 else x
    spec = np.abs(np.fft.rfft(mono * np.hanning(len(mono)))) ** 2
    freqs = np.fft.rfftfreq(len(mono), 1 / rate)
    total = spec.sum() or 1.0
    return [float(spec[(freqs >= lo) & (freqs < hi)].sum() / total * 100) for lo, hi in zip(edges[:-1], edges[1:])]
