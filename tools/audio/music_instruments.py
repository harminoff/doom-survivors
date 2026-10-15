"""Which instruments a generated track actually contains (CLAP zero-shot), and whether they
match what the prompt asked for.

The text-to-music model sometimes swaps an instrument (an organ comes out as an accordion,
a harpsichord as an acoustic guitar, a choir pad as singing). Listening catches it; this
catches the obvious cases automatically so a take can be rejected before it is installed.
Each 10 s window of the track is scored against INSTRUMENTS ("the sound of a <name>");
the per-instrument share is averaged over the track.

    python: from music_instruments import profile, check
    CLI (audio env):  ...\\sa3-env\\Scripts\\python.exe tools/audio/music_instruments.py [NAME ...]
                      (reads src/resources/music/<NAME>.ogg; prints the top instruments and
                      any unwanted ones found)
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np

INSTRUMENTS = [
    "piano", "harpsichord", "church organ", "electric organ", "accordion", "music box", "bells",
    "vibraphone", "harp", "acoustic guitar", "electric guitar", "distorted electric guitar",
    "violin and strings", "pizzicato strings", "brass and trumpets", "flute", "saxophone",
    "choir", "singing voice", "drum kit", "electronic drums", "synth lead", "synth bass",
    "synth pad", "chiptune", "bass guitar", "orchestral percussion", "metal clanking",
]
WINDOW = 10.0


def profile(clap, audio: np.ndarray, rate: int) -> dict[str, float]:
    """Average share of each instrument over the track's 10 s windows."""
    mono = audio.mean(axis=1) if audio.ndim == 2 else audio
    step = int(WINDOW * rate)
    windows = [mono[i:i + step] for i in range(0, max(1, len(mono) - step + 1), step)]
    texts = [f"the sound of a {name}" for name in INSTRUMENTS]
    sims = np.array([clap.similarity(t, windows, rate) for t in texts])      # (instruments, windows)
    share = np.exp(sims * 30.0)                                              # CLAP logit scale
    share /= share.sum(axis=0, keepdims=True)
    return dict(zip(INSTRUMENTS, share.mean(axis=1).round(3).tolist()))


def check(prof: dict[str, float], wanted: list[str], unwanted: list[str], floor: float = 0.08) -> dict:
    """wanted_share: total share of the asked-for instruments; intruders: unwanted ones that
    are clearly present (share above floor)."""
    wanted_share = float(sum(prof.get(w, 0.0) for w in wanted))
    intruders = {u: prof[u] for u in unwanted if prof.get(u, 0.0) >= floor}
    return {"wanted_share": round(wanted_share, 3), "intruders": intruders}


def main() -> None:
    import soundfile as sf
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from clap_score import Clap
    from sa3_music import ALWAYS_UNWANTED, TRACKS
    root = Path(__file__).resolve().parents[2]
    clap = Clap()
    for name in sys.argv[1:] or list(TRACKS):
        audio, rate = sf.read(root / "src/resources/music" / f"{name}.ogg", dtype="float32")
        prof = profile(clap, audio, rate)
        top = sorted(prof.items(), key=lambda kv: -kv[1])[:7]
        line = ", ".join(f"{k} {v:.2f}" for k, v in top)
        spec = TRACKS[name]
        extra = ""
        if len(spec) > 4:
            c = check(prof, spec[4], spec[5] + ALWAYS_UNWANTED)
            extra = f"  | wanted {c['wanted_share']:.2f} intruders {c['intruders']}"
        print(f"{name}: {line}{extra}", flush=True)


if __name__ == "__main__":
    main()
