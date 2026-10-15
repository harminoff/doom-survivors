"""Generate audio with the local Stable Audio 3 models (Medium for everything; Small kept).

Runs in a separate Python 3.10 environment (%USERPROFILE%\\sa3-env) because
stable-audio-tools needs 3.10 and a CUDA PyTorch; the repo's own tools stay
standard-library/numpy only. The models come from the local Hugging Face cache
(stabilityai/stable-audio-3-medium, -small-music, -small-sfx), loaded offline.
Medium (2.3B) runs in bfloat16: about 5 GB of VRAM and ~2 s per clip on an RTX 3080.
In fp32 it spills out of the 12 GB card and crawls; fp16 gives noise with the Small models.

Library use:
    from tools.audio.sa3_generate import Sa3
    sfx = Sa3("medium"); audio = sfx.generate("coin pickup chime", seconds=1.5)

Command line (smoke test):
    %USERPROFILE%\\sa3-env\\Scripts\\python.exe tools/audio/sa3_generate.py medium "TrackType: SFX, coin pickup chime" 1.5 out.wav
"""
from __future__ import annotations

import os
import random
import sys

os.environ.setdefault("HF_HUB_OFFLINE", "1")

import numpy as np
import soundfile as sf
import torch

from stable_audio_tools.inference.generation import generate_diffusion_cond_inpaint
from stable_audio_tools.models.pretrained import get_pretrained_model

REPOS = {
    "music": "stabilityai/stable-audio-3-small-music",
    "sfx": "stabilityai/stable-audio-3-small-sfx",
    "medium": "stabilityai/stable-audio-3-medium",
}


class Sa3:
    """One loaded model. Each generate() returns a float32 (samples, channels) array."""

    def __init__(self, kind: str, half: bool = False):   # fp16 produces white noise with the Small models
        self.kind = kind
        dtype = torch.bfloat16 if kind == "medium" else torch.float32
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        model, config = get_pretrained_model(REPOS[kind])
        self.sample_rate = config["sample_rate"]
        self.max_samples = config["sample_size"]
        self.dtype = dtype if self.device == "cuda" else torch.float32
        self.model = model.to(self.device, dtype=self.dtype).eval()
        if half and self.device == "cuda":
            self.model = self.model.to(torch.float16)

    NEGATIVE = "noise, distortion, harsh, muffled, low quality, clipping, silence"

    @torch.no_grad()
    def generate(self, prompt: str, seconds: float, steps: int = 8, cfg_scale: float = 1.0,
                 seed: int = -1, negative: str | None = None, inpaint: tuple | None = None) -> np.ndarray:
        """Text-to-audio. cfg_scale above 1 uses the negative prompt (default NEGATIVE).

        inpaint=(audio, start_seconds, end_seconds) keeps the given audio outside the
        range and regenerates the range (the models are inpainting-capable).
        """
        samples = min(int(seconds * self.sample_rate), self.max_samples)
        if seed < 0:
            seed = random.randint(0, 2**31 - 1)   # the library's own draw overflows on Windows
        conditioning = [{"prompt": prompt, "seconds_total": seconds}]
        kwargs = {}
        if cfg_scale > 1.0:
            kwargs["negative_conditioning"] = [{"prompt": negative or self.NEGATIVE, "seconds_total": seconds}]
        if inpaint is not None:
            audio, start, end = inpaint
            kwargs["inpaint_audio"] = (self.sample_rate, torch.from_numpy(np.ascontiguousarray(audio.T)).to(self.dtype))
            kwargs["inpaint_mask_start_seconds"] = start
            kwargs["inpaint_mask_end_seconds"] = end
        out = generate_diffusion_cond_inpaint(
            self.model, steps=steps, cfg_scale=cfg_scale, conditioning=conditioning,
            sample_size=samples, seed=seed, device=self.device, sampler_type="pingpong", **kwargs,
        )
        audio = out[0].float().cpu().numpy().T          # (samples, channels)
        peak = float(np.max(np.abs(audio))) or 1.0
        return (audio / max(peak, 1.0)).astype(np.float32)

    @torch.no_grad()
    def generate_batch(self, prompt: str, seconds: float, count: int, steps: int = 8, cfg_scale: float = 1.0,
                       seed: int = -1, negative: str | None = None) -> list[np.ndarray]:
        """count takes of one prompt in a single pass (different noise per take)."""
        samples = min(int(seconds * self.sample_rate), self.max_samples)
        if seed < 0:
            seed = random.randint(0, 2**31 - 1)
        conditioning = [{"prompt": prompt, "seconds_total": seconds}] * count
        kwargs = {}
        if cfg_scale > 1.0:
            kwargs["negative_conditioning"] = [{"prompt": negative or self.NEGATIVE, "seconds_total": seconds}] * count
        out = generate_diffusion_cond_inpaint(
            self.model, steps=steps, cfg_scale=cfg_scale, conditioning=conditioning, batch_size=count,
            sample_size=samples, seed=seed, device=self.device, sampler_type="pingpong", **kwargs,
        )
        takes = []
        for one in out:
            audio = one.float().cpu().numpy().T
            peak = float(np.max(np.abs(audio))) or 1.0
            takes.append((audio / max(peak, 1.0)).astype(np.float32))
        return takes

    def make_loop(self, audio: np.ndarray, prompt: str, seam_seconds: float = 6.0, steps: int = 8,
                  cfg_scale: float = 3.0, seed: int = -1) -> np.ndarray:
        """Turn a track into a seamless loop: shift it by half its length so the old
        end-to-start join sits in the middle, then have the model rewrite that join."""
        seconds = audio.shape[0] / self.sample_rate
        rolled = np.roll(audio, audio.shape[0] // 2, axis=0)
        mid = seconds / 2
        return self.generate(prompt, seconds, steps=steps, cfg_scale=cfg_scale, seed=seed,
                             inpaint=(rolled, mid - seam_seconds / 2, mid + seam_seconds / 2))


def main() -> None:
    kind, prompt, seconds, path = sys.argv[1], sys.argv[2], float(sys.argv[3]), sys.argv[4]
    model = Sa3(kind)
    audio = model.generate(prompt, seconds)
    sf.write(path, audio, model.sample_rate)
    print(f"wrote {path}: {audio.shape[0] / model.sample_rate:.2f}s, peak {np.max(np.abs(audio)):.2f}")


if __name__ == "__main__":
    main()
