"""Simulate a busy minute of play (music + effects) with the game's playback rules and report
whether the mix stays readable.

Reads the game files (src/resources/music, src/resources/sounds) and asks for sounds tic by
tic at the rates of a SCENARIO (late game: eight weapons, a crowd dying, a gem stream, plus
level-ups, a chest, an evolution, a boss and getting hurt). The asks go through the same
rules as SliceAudio.zs: per-sound gap and SNDINFO voice limit, the per-category budget and
gap, the effects-bus gain, combat ducked under feedback / stingers, and the music duck.
--rules old replays the rules (and the role loudness) from before the 2026-10-14 mix pass,
for comparison.

Reports:
  voices      combat sounds playing at once (mean / 95th percentile)
  combat      loudness of the combat bus against the music (LU; below 0 = under the music)
  salience    for each feedback sound / stinger: its loudness over its first 0.6 s against
              everything else in that moment (LU; +6 or more = it clearly stands out)
  peak        peak of the whole mix and clipped samples
and writes the mix to a WAV so it can be listened to.

    python tools/audio/mix_check.py [TRACK] [out.wav] [--rules old|new]
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parent))
from paths import REVIEW_ROOT   # noqa: E402
import mixer   # noqa: E402
from sound_table import COMBAT, SOUNDS, file_stem, setting   # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
RATE = 44100
TIC = 35
SECONDS = 60

# asks per second (late game) and the caller's per-sound gap in tics (SliceAudio callers)
SCENARIO = {
    "W_WHIP": (1.0, 0), "W_MAGIC_WAND": (1.5, 4), "W_KNIFE": (2.0, 4), "W_GARLIC": (2.0, 4),
    "W_KING_BIBLE": (0.5, 4), "W_LIGHTNING_RING": (0.5, 4), "W_SANTA_WATER": (0.7, 4), "W_RUNETRACER": (0.7, 4),
    "H_WHIP": (4, 4), "H_AIMED": (8, 4), "H_AURA": (8, 4), "H_ORBIT": (4, 4), "H_GLOBAL": (2, 4),
    "H_GROUND": (3, 4), "H_BOUNCE": (3, 4),
    "D_BAT": (6, 3), "D_ZOMBIE": (4, 3), "D_SKELETON": (4, 3), "D_GHOST": (3, 3), "D_MUMMY": (2, 3),
    "GEM": (15, 2), "COIN": (1.5, 2), "HURT": (0.4, 12),
}
EVENTS = [(6.0, "LEVELUP"), (18.0, "LEVELUP"), (25.0, "CHEST"), (36.0, "E_EVOLUTION"), (31.0, "LEVELUP"),
          (40.0, "BOSS"), (47.0, "LEVELUP"), (53.0, "I_ROSARY")]

# the new rules (SliceAudio.zs; tests/tools/test_sound_table.py keeps them equal)
BUDGET_WINDOW = 10
FOCUS_GAIN = 0.45
CAT_MAX = {"weapon": 3, "hit": 2, "death": 2, "pickup": 1}
CAT_GAP = {"weapon": 2, "hit": 4, "death": 4, "pickup": 3}
# before the 2026-10-14 pass: no category budget or focus duck, bus gain 1/sqrt(1+0.6n) floor
# 0.3 over every frequent sound, voice limit 3 for hits/deaths/pickups, and louder roles
OLD_LIMIT = {"weapon": 2, "hit": 3, "death": 3, "pickup": 3}
OLD_GAIN_DB = {"weapon": 1.0, "hit": 5.0, "death": 3.0, "pickup": 2.0}


def load(name: str, kind: str) -> np.ndarray:
    if kind == "music":
        path = ROOT / "src/resources/music" / f"{name}.ogg"
    else:
        path = ROOT / "src/resources/sounds" / SOUNDS[name].group / f"{file_stem(name)}.ogg"
    data, rate = sf.read(path, dtype="float32")
    assert rate == RATE
    return data if data.ndim == 2 else np.stack([data, data], axis=1)


def schedule(rules: str, rng) -> list[tuple[int, str, float]]:
    """(tic, sound, gain) of every sound the rules let through."""
    asks = []
    for name, (per_s, gap) in SCENARIO.items():
        for t in np.flatnonzero(rng.random(SECONDS * TIC) < per_s / TIC):
            asks.append((int(t), name, gap))
    asks += [(int(t * TIC), name, 0) for t, name in EVENTS]
    asks.sort()
    last_id: dict[str, int] = {}
    voices: dict[str, list[int]] = {}
    cat_last: dict[str, int] = {}
    bus: list[tuple[int, str]] = []
    duck_until = -1
    out = []
    lengths = {n: int(len(load(n, "sfx")) / RATE * TIC) + 1 for n in {a[1] for a in asks}}
    for tic, name, gap in asks:
        role = SOUNDS[name].role
        if tic - last_id.get(name, -10**6) < gap:
            continue
        limit = (OLD_LIMIT.get(role) if rules == "old" else None) or setting(name, "limit") or 99
        live = [end for end in voices.get(name, []) if end > tic]
        if len(live) >= limit:
            continue
        gain = 1.0
        if role in COMBAT:
            bus = [(t, c) for t, c in bus if tic - t < BUDGET_WINDOW]
            if rules == "new":
                if tic - cat_last.get(role, -10**6) < CAT_GAP[role]:
                    continue
                if sum(1 for _, c in bus if c == role) >= CAT_MAX[role]:
                    continue
                gain = max(0.35, 1.0 / np.sqrt(1.0 + 0.5 * len(bus)))
                if tic < duck_until:
                    gain *= FOCUS_GAIN
            else:
                gain = max(0.3, 1.0 / np.sqrt(1.0 + 0.6 * len(bus))) * mixer.from_db(OLD_GAIN_DB[role])
            bus.append((tic, role))
            cat_last[role] = tic
        last_id[name] = tic
        voices[name] = live + [tic + lengths[name]]
        out.append((tic, name, gain))
        if setting(name, "duck") < 1.0:
            duck_until = max(duck_until, tic + setting(name, "hold"))
    return out


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    rules = "old" if "--rules" in sys.argv and sys.argv[sys.argv.index("--rules") + 1] == "old" else "new"
    args = [a for a in args if a not in ("old", "new")]
    track = args[0] if args else "DSFOREST"
    out_path = args[1] if len(args) > 1 else str(REVIEW_ROOT / f"mix_{track}_{rules}.wav")
    n = SECONDS * RATE
    music = load(track, "music")
    bed = np.tile(music, (n // len(music) + 1, 1))[:n].copy()
    played = schedule(rules, np.random.default_rng(3))

    duck = np.ones(n, dtype=np.float32)
    for tic, name, _g in played:
        depth = setting(name, "duck")
        if depth >= 1.0:
            continue
        a, b = int(tic / TIC * RATE), int((tic + setting(name, "hold")) / TIC * RATE)
        ramp, rel = int(0.15 * RATE), np.linspace(depth, 1.0, int(0.7 * RATE))
        duck[a:b] = np.minimum(duck[a:b], depth)
        duck[a:a + ramp] = np.minimum(duck[a:a + ramp], np.linspace(1.0, depth, len(duck[a:a + ramp])))
        duck[b:b + len(rel)] = np.minimum(duck[b:b + len(rel)], rel[: len(duck[b:b + len(rel)])])
    mix_music = bed * duck[:, None]

    combat = np.zeros_like(bed)
    other = np.zeros_like(bed)
    count = np.zeros(n // 441 + 1)
    focus = []
    for tic, name, gain in played:
        clip = load(name, "sfx") * gain
        i = int(tic / TIC * RATE)
        seg = clip[: n - i]
        if SOUNDS[name].role in COMBAT:
            combat[i:i + len(seg)] += seg
            count[i // 441: (i + len(seg)) // 441] += 1
        else:
            other[i:i + len(seg)] += seg
            focus.append((i, name, seg))
    mix = mix_music + combat + other

    def lufs_window(x):
        return mixer.event_lufs(x, RATE) if np.any(x) else -120.0

    print(f"track {track}, rules {rules}: {sum(1 for p in played if SOUNDS[p[1]].role in COMBAT)} combat sounds played "
          f"in {SECONDS}s ({len(played)} total)")
    print(f"  voices: mean {count.mean():.1f}, 95th percentile {np.percentile(count, 95):.0f}, max {count.max():.0f}")
    print(f"  combat bus {mixer.lufs(combat, RATE):.1f} LUFS vs music {mixer.lufs(mix_music, RATE):.1f} LUFS "
          f"(combat - music {mixer.lufs(combat, RATE) - mixer.lufs(mix_music, RATE):+.1f} LU); whole mix {mixer.lufs(mix, RATE):.1f} LUFS")
    sal: dict[str, list[float]] = {}
    for i, name, seg in focus:
        w = min(len(seg), int(0.6 * RATE))
        rest = mix[i:i + w] - seg[:w]
        sal.setdefault(name, []).append(lufs_window(seg[:w]) - lufs_window(rest))
    print("  salience (LU above everything else in its first 0.6 s; +6 or more stands out):")
    for name, vals in sal.items():
        print(f"    {name:12s} {np.median(vals):+5.1f}  ({len(vals)}x)")
    peak = mixer.peak_db(mix)
    print(f"  peak {peak:.1f} dB, clipped samples {float(np.mean(np.abs(mix) > 0.999)) * 100:.3f}%")
    if peak > -0.5:
        mix = mixer.limit(mix, RATE, ceiling_db=-1.0)
    sf.write(out_path, mix, RATE, subtype="PCM_16")
    print("  wrote", out_path)


if __name__ == "__main__":
    main()
