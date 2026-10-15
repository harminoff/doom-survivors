"""Generate the game's sound effects with Stable Audio 3 Medium (every sound in sound_table.py).

Per sound: generate candidates (two prompt styles x two guidance values x SEEDS takes, in
batches), cut each to its event (tools/audio/sfx_metrics.py), score its shape against the
table entry (length, attack, cleanliness, single event), score how well it matches the
description with CLAP (tools/audio/clap_score.py), and keep the best TOP as raw review takes
under the review folder. tools/audio/sfx_mix.py then makes the final game files (filtering,
loudness, limiting), SNDINFO and the ZScript table. Listen in game and swap with --use.

Prompting (Stable Audio 3 prompt guide + testing): "TrackType: SFX, " + a description of the
source, the action and the production; ~2 s clips for one-shots (longer clips add stray
sounds), 4 s for stingers. The distilled Medium model wants 8 steps; guidance 1 and 2.5 are
both tried because each helps different sounds.

Run (needs the audio environment, see tools/audio/sa3_generate.py):
    %USERPROFILE%\\sa3-env\\Scripts\\python.exe tools/audio/sa3_sfx.py              # all
    ... tools/audio/sa3_sfx.py W_KNIFE COIN                                           # some
    ... tools/audio/sa3_sfx.py --missing                                              # not yet generated
    ... tools/audio/sa3_sfx.py --use COIN 2                                           # pick take 2
then   python tools/audio/sfx_mix.py                                                  # final mix
"""
from __future__ import annotations

import json
import zlib
import sys
import time
from pathlib import Path

import numpy as np
import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parent))
from paths import REVIEW_ROOT   # noqa: E402
from sfx_metrics import analyse, finish_event   # noqa: E402
from sound_table import SOUNDS, SYNTH, clip_seconds   # noqa: E402

REVIEW = REVIEW_ROOT / "sfx3m"
RATE = 44100
SEEDS = 6          # takes per prompt style and guidance value (one batch)
GUIDANCE = (1.0, 2.5)
TOP = 3
CLAP_WEIGHT = 1.2  # weight of the (pool-normalised) CLAP match against the shape score
NEGATIVE = "music, melody, speech, voice, background noise, hum, reverb tail, distortion, low quality"


def prompts(key: str) -> list[str]:
    desc = SOUNDS[key].prompt
    return [f"TrackType: SFX, {desc}",
            f"TrackType: SFX, {desc}, isolated one-shot, clean studio recording, no background noise, no music"]


def shape_score(info: dict, key: str) -> float:
    snd = SOUNDS[key]
    lo, hi = snd.length
    length = info["len24"]
    mid = (lo * hi) ** 0.5
    s = -abs(np.log(max(length, 0.02) / mid))
    if length < lo or length > hi * 1.15:
        s -= 1.0
    s -= (1.0 - info["single"]) * (3.0 if snd.kind != "wash" else 1.5)
    s -= max(0.0, info["floor_db"] + 50.0) / 10.0
    if snd.kind == "impact":
        s -= max(0.0, info["attack_ms"] - 40.0) / 100.0
    elif snd.kind == "tonal":
        s -= max(0.0, info["flat"] - 0.35) * 1.5
    if snd.role in ("weapon", "hit", "death", "pickup", "ui"):
        s -= max(0.0, info["attack_ms"] - 120.0) / 150.0      # frequent sounds must land on the beat
    return float(s)


def render(model, clap, key: str) -> None:
    snd = SOUNDS[key]
    folder = REVIEW / key
    folder.mkdir(parents=True, exist_ok=True)
    for old in folder.glob("take*.wav"):
        old.unlink()
    secs = clip_seconds(key)
    gap = 350.0 if snd.kind == "wash" else 150.0
    pool = []
    t0 = time.time()
    for style, prompt in enumerate(prompts(key)):
        for cfg in GUIDANCE:
            seed = (zlib.crc32(key.encode()) % 100000) * 10 + style * 3 + int(cfg)
            for raw in model.generate_batch(prompt, secs, SEEDS, cfg_scale=cfg, seed=seed, negative=NEGATIVE):
                info = analyse(raw, RATE, gap_ms=gap)
                if info["event"].size < RATE * 0.03:
                    continue
                event = info["event"][: int(snd.length[1] * 1.15 * RATE)]   # tails past the spec are cut
                pool.append({"shape": shape_score(info, key), "info": info, "event": event, "style": style, "cfg": cfg})
    if not pool:
        print(f"{key}: no usable takes", flush=True)
        return
    sims = clap.similarity(snd.prompt, [p["event"] for p in pool], RATE)
    sims = np.array(sims)
    z = (sims - sims.mean()) / (sims.std() or 1.0)
    for p, sim, zz in zip(pool, sims, z):
        p["clap"] = float(sim)
        p["score"] = p["shape"] + CLAP_WEIGHT * float(zz)
    pool.sort(key=lambda p: -p["score"])
    record = []
    for take, p in enumerate(pool[:TOP], 1):
        info = p["info"]
        clip = finish_event(p["event"], RATE, fade_out_ms=120.0 if len(p["event"]) > RATE * 0.5 else 30.0)
        sf.write(folder / f"take{take}.wav", clip, RATE, subtype="PCM_16")
        record.append({"take": take, "score": round(p["score"], 3), "shape": round(p["shape"], 3), "clap": round(p["clap"], 3),
                       "len24": round(info["len24"], 3), "attack_ms": round(info["attack_ms"]), "centroid": round(info["centroid"]),
                       "flat": round(info["flat"], 3), "floor_db": round(info["floor_db"]), "style": p["style"], "cfg": p["cfg"]})
    (folder / "takes.json").write_text(json.dumps(record, indent=1), encoding="utf-8")
    if not (folder / "picked.txt").exists():
        (folder / "picked.txt").write_text("1\n", encoding="utf-8")
    best = record[0]
    print(f"{key:22s} {len(pool):2d} cands {time.time() - t0:5.1f}s  best score {best['score']:5.2f} clap {best['clap']:.2f} "
          f"len {best['len24']:.2f}s attack {best['attack_ms']}ms floor {best['floor_db']}dB", flush=True)


def main() -> None:
    args = sys.argv[1:]
    if args and args[0] == "--use":
        (REVIEW / args[1] / "picked.txt").write_text(f"{int(args[2])}\n", encoding="utf-8")
        print(f"{args[1]}: take {args[2]} chosen; run tools/audio/sfx_mix.py to build the game file")
        return
    keys = [k for k in SOUNDS if k not in SYNTH]
    if args and args[0] == "--missing":
        keys = [k for k in keys if not (REVIEW / k / "take1.wav").exists()]
    elif args:
        keys = args
    from sa3_generate import Sa3   # noqa: E402  (needs the audio environment)
    from clap_score import Clap    # noqa: E402
    model = Sa3("medium")
    clap = Clap()
    for key in keys:
        render(model, clap, key)


if __name__ == "__main__":
    main()
