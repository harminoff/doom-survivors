"""Render a spectrogram strip (PNG) for audio files so they can be judged by eye.

    python tools/audio/inspect_audio.py out.png a.wav b.wav ...
Each row is one file: loudness envelope on top, log-frequency spectrogram below.
"""
from __future__ import annotations

import sys

import numpy as np
import soundfile as sf
from PIL import Image, ImageDraw
from scipy import signal


def strip(path: str, width: int = 640, height: int = 150) -> Image.Image:
    data, rate = sf.read(path)
    if data.ndim == 2:
        data = data.mean(axis=1)
    f, t, spec = signal.spectrogram(data, rate, nperseg=1024, noverlap=768)
    spec = 10 * np.log10(spec + 1e-12)
    spec = np.clip((spec - spec.max() + 80) / 80, 0, 1)
    keep = f < 12000
    spec = spec[keep][::-1]
    img = Image.fromarray((spec * 255).astype(np.uint8)).resize((width, height - 40), Image.BILINEAR).convert("RGB")
    out = Image.new("RGB", (width, height), (20, 20, 30))
    out.paste(img, (0, 40))
    env = np.abs(data)
    cols = np.array_split(env, width)
    peak = max(float(env.max()), 1e-6)
    d = ImageDraw.Draw(out)
    for x, c in enumerate(cols):
        h = int(float(c.max()) / peak * 36)
        d.line([(x, 38), (x, 38 - h)], fill=(240, 200, 80))
    d.text((4, 2), f"{path.split(chr(92))[-1].split('/')[-1]}  {len(data) / rate:.2f}s  peak {env.max():.2f}", fill=(255, 255, 255))
    return out


if __name__ == "__main__":
    out, files = sys.argv[1], sys.argv[2:]
    rows = [strip(f) for f in files]
    sheet = Image.new("RGB", (rows[0].width, sum(r.height for r in rows)))
    y = 0
    for r in rows:
        sheet.paste(r, (0, y))
        y += r.height
    sheet.save(out)
