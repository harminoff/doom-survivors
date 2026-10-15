"""How well a sound matches its description, with LAION CLAP (laion/larger_clap_general).

Runs in the audio environment (see tools/audio/sa3_generate.py); the model comes from the
local Hugging Face cache. Used by sa3_sfx.py / sa3_music.py to rank generated candidates:
the spectral metrics catch broken takes (noise, wrong length, stray sounds), CLAP catches
takes that are clean but are not the thing that was asked for.

    clap = Clap(); sims = clap.similarity("a coin pickup ding", [audio1, audio2], 44100)
"""
from __future__ import annotations

import os

os.environ.setdefault("HF_HUB_OFFLINE", "1")

import numpy as np
import torch
from scipy import signal
from transformers import ClapModel, ClapProcessor

REPO = "laion/larger_clap_general"
CLAP_RATE = 48000
TARGET_RMS = 0.1


def _tensor(out):
    # transformers 5 returns a model output (the projected embedding is pooler_output)
    return out if isinstance(out, torch.Tensor) else out.pooler_output


class Clap:
    def __init__(self, device: str | None = None):
        self.device = device or ("cuda" if torch.cuda.is_available() else "cpu")
        self.model = ClapModel.from_pretrained(REPO).to(self.device).eval()
        self.processor = ClapProcessor.from_pretrained(REPO)

    @torch.no_grad()
    def similarity(self, text: str, clips: list[np.ndarray], rate: int) -> list[float]:
        """Cosine similarity between the text and each clip (mono or (samples, channels))."""
        audio = []
        for clip in clips:
            x = clip.mean(axis=1) if clip.ndim == 2 else clip
            # CLAP's features are not level-invariant (the same take at 0.4x gain reads as a
            # different instrument mix), so every clip is scored at the same RMS
            rms = float(np.sqrt(np.mean(x ** 2)))
            if rms > 1e-6:
                x = x * (TARGET_RMS / rms)
            audio.append(signal.resample_poly(x, CLAP_RATE, rate).astype(np.float32))
        t = self.processor(text=[text], return_tensors="pt", padding=True).to(self.device)
        a = self.processor(audio=audio, sampling_rate=CLAP_RATE, return_tensors="pt").to(self.device)
        te = _tensor(self.model.get_text_features(**t))
        ae = _tensor(self.model.get_audio_features(**a))
        te = te / te.norm(dim=-1, keepdim=True)
        ae = ae / ae.norm(dim=-1, keepdim=True)
        return (ae @ te.T).squeeze(-1).float().cpu().tolist()
