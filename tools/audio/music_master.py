"""Master the generated music so it sits under the effects.

Reads the picked take of each track from the review folder (tools/audio/sa3_music.py),
and writes the game file src/resources/music/<NAME>.ogg:
  - high-pass at 30 Hz (rumble) and a soft high shelf cut (-2 dB at 8 kHz) to take the edge
    off generation artifacts;
  - a "pocket": -2.5 dB around 3 kHz and -1.5 dB around 1.2 kHz, where the effects' attacks
    live, so they cut through without being louder;
  - level to MUSIC_LUFS integrated (-28 LUFS; the engine plays music at full file level and
    the effects are balanced against this, see tools/audio/sfx_mix.py);
  - a gentle limiter at -2 dBFS.
The track is tiled three times while filtering and the middle copy kept, so the loop point
stays seamless (no filter ringing at the join).

Run (numpy/scipy/soundfile):  python tools/audio/music_master.py [NAME ...]
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parent))
import mixer   # noqa: E402
from sa3_music import REVIEW, TRACKS   # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
MUSIC_DIR = ROOT / "src/resources/music"

MUSIC_LUFS = -28.0
NAMES = list(TRACKS)


def write_ogg(path: Path, audio: np.ndarray, rate: int) -> None:
    # libsndfile's Vorbis encoder crashes on float input and on one big write on this
    # setup; 16-bit data written in small blocks is fine.
    pcm = np.clip(audio * 32767.0, -32768, 32767).astype(np.int16)
    with sf.SoundFile(path, "w", samplerate=rate, channels=pcm.shape[1], format="OGG", subtype="VORBIS") as out:
        for start in range(0, len(pcm), 4096):
            out.write(pcm[start: start + 4096])


def master(audio: np.ndarray, rate: int) -> np.ndarray:
    n = audio.shape[0]
    x = np.concatenate([audio, audio, audio], axis=0).astype(np.float32)
    x = mixer.highpass(x, rate, 30.0, order=2)
    x = mixer.apply(x, "highshelf", rate, 8000.0, 0.7071, -2.0)
    x = mixer.apply(x, "peak", rate, 3000.0, 0.9, -2.5)
    x = mixer.apply(x, "peak", rate, 1200.0, 0.9, -1.5)
    x = x[n: 2 * n]
    for _ in range(2):
        x = x * mixer.from_db(MUSIC_LUFS - mixer.lufs(x, rate))
        x = mixer.limit(x, rate, ceiling_db=-2.0, lookahead_ms=5.0, release_ms=120.0)
    return x


def main() -> None:
    for name in sys.argv[1:] or NAMES:
        folder = REVIEW / name
        picked = int((folder / "picked.txt").read_text().strip() or 1)
        audio, rate = sf.read(folder / f"take{picked}.ogg", dtype="float32")
        out = master(audio, rate)
        write_ogg(MUSIC_DIR / f"{name}.ogg", out, rate)
        print(f"{name} take{picked}: {mixer.lufs(out, rate):.1f} LUFS  peak {mixer.peak_db(out):.1f} dB", flush=True)


if __name__ == "__main__":
    main()
