"""Install the synthesised blips from tools/art/sound_art.py as the review take for the
sounds where a clean retro tone beats a generated one (sound_table.SYNTH: menu tick, confirm).
Run, then tools/audio/sfx_mix.py:   python tools/audio/sfx_synth_takes.py
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy import signal

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "art"))
import sound_art   # noqa: E402

sys.path.insert(0, str(Path(__file__).resolve().parent))
from paths import REVIEW_ROOT   # noqa: E402
from sound_table import SYNTH   # noqa: E402

REVIEW = REVIEW_ROOT / "sfx3m"


def main() -> None:
    made = sound_art.make()
    for name in sys.argv[1:] or list(SYNTH):
        clip = np.clip(made[SYNTH[name]], -1, 1)
        clip = signal.resample_poly(clip, 44100, sound_art.RATE).astype(np.float32)
        folder = REVIEW / name
        folder.mkdir(parents=True, exist_ok=True)
        sf.write(folder / "take1.wav", clip, 44100, subtype="PCM_16")
        (folder / "picked.txt").write_text("4\n", encoding="utf-8")
        print(f"{name}: synthesised blip installed as take 1 ({len(clip) / 44100:.2f}s)")


if __name__ == "__main__":
    main()
