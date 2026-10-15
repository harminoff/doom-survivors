"""Compose the stage music (original, generated in code) as MIDI files.

Seven looping tracks in a gothic-arcade style: minor-key chord
progressions, a driving bass, arpeggiated chords, a motif-based lead
melody and drums, played by the engine's General MIDI synth. Writes
src/resources/music/<NAME>.mid; ZMAPINFO names a track per stage map.
Run: python tools/art/music_art.py
"""
from __future__ import annotations

import random
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MUSIC = ROOT / "assets/music-midi"   # fallback MIDI; the game plays the generated OGGs in src/resources/music
PPQ = 480

# name: tempo, key root (MIDI note), progression (scale degrees of a
# natural minor key), lead / arp / bass / pad GM programs, seed.
TRACKS = {
    "DSFIELD": (148, 57, [0, 5, 2, 6], 80, 4, 38, 48, 11),     # A minor, square lead, e-piano
    "DSLIBRA": (124, 62, [0, 3, 5, 4], 73, 19, 32, 52, 12),    # D minor, flute, church organ
    "DSGOTHC": (138, 52, [0, 5, 3, 4], 81, 19, 38, 49, 13),    # E minor, saw lead, organ
    "DSNIGHT": (118, 60, [0, 6, 5, 4], 88, 11, 33, 89, 14),    # C minor, pad lead, vibraphone
    "DSFROST": (130, 64, [0, 2, 5, 6], 10, 8, 32, 89, 15),     # E minor high, music box, celesta
    "DSCOSMC": (126, 55, [0, 5, 6, 4], 87, 99, 39, 91, 16),    # G minor, bass+lead, crystal
    "DSBATTL": (156, 50, [0, 6, 5, 6], 30, 19, 38, 48, 17),    # D minor, distortion guitar, organ
    "DSTITLE": (104, 57, [0, 5, 3, 6], 71, 46, 32, 49, 18),    # A minor, clarinet, harp, strings
}
THEME_MUSIC = {
    "forest": "DSFIELD", "meadow": "DSFIELD", "farm": "DSFIELD", "coop": "DSFIELD",
    "maze": "DSFIELD", "bridge": "DSFIELD", "track": "DSFIELD", "woods": "DSFIELD",
    "library": "DSLIBRA", "sunken": "DSLIBRA", "lab": "DSLIBRA",
    "tower": "DSGOTHC", "cathedral": "DSGOTHC", "dark": "DSGOTHC", "plant": "DSGOTHC",
    "moon": "DSNIGHT", "batland": "DSNIGHT",
    "snow": "DSFROST",
    "space": "DSCOSMC", "astral": "DSCOSMC",
    "bones": "DSBATTL", "arena": "DSBATTL",
}

MINOR = [0, 2, 3, 5, 7, 8, 10]


def vlq(n: int) -> bytes:
    out = [n & 0x7F]
    n >>= 7
    while n:
        out.append(0x80 | (n & 0x7F))
        n >>= 7
    return bytes(reversed(out))


class Track:
    def __init__(self):
        self.events: list[tuple[int, bytes]] = []

    def note(self, start, length, ch, pitch, vel):
        pitch = max(0, min(127, pitch))
        self.events.append((start, bytes([0x90 | ch, pitch, vel])))
        self.events.append((start + max(1, length - 10), bytes([0x80 | ch, pitch, 0])))

    def raw(self, start, data):
        self.events.append((start, data))

    def encode(self) -> bytes:
        body = bytearray()
        last = 0
        for tick, data in sorted(self.events, key=lambda e: (e[0], e[1][0] & 0xF0 != 0x80)):
            body += vlq(tick - last) + data
            last = tick
        body += vlq(0) + b"\xff\x2f\x00"
        return b"MTrk" + struct.pack(">I", len(body)) + bytes(body)


def degree(root, d, octave=0):
    return root + MINOR[d % 7] + 12 * (d // 7 + octave)


def chord(root, d):
    return [degree(root, d), degree(root, d + 2), degree(root, d + 4)]


def compose(name, tempo, root, prog, lead_p, arp_p, bass_p, pad_p, seed):
    rng = random.Random(seed)
    bar = PPQ * 4
    conductor = Track()
    conductor.raw(0, b"\xff\x51\x03" + struct.pack(">I", 60000000 // tempo)[1:])
    conductor.raw(0, b"\xff\x58\x04\x04\x02\x18\x08")
    tracks = {k: Track() for k in ("lead", "arp", "bass", "pad", "drums")}
    for ch, (key, prog_no) in enumerate([("lead", lead_p), ("arp", arp_p), ("bass", bass_p), ("pad", pad_p)]):
        tracks[key].raw(0, bytes([0xC0 | ch, prog_no]))
        tracks[key].raw(0, bytes([0xB0 | ch, 7, [100, 78, 105, 60][ch]]))
        tracks[key].raw(0, bytes([0xB0 | ch, 91, [50, 40, 20, 70][ch]]))
    # Structure: intro (4 bars, no lead), A (8), B (8, lifted), A' (8).
    # A/B as before, then a bridge (C: reversed chords, drum breakdown, long
    # high notes) and a lifted variation (D) before the last A, ~50 bars.
    sections = [("intro", 4, 0), ("A", 8, 0), ("B", 8, 1), ("A", 8, 0), ("C", 8, 1), ("D", 8, 1), ("A", 8, 0)]
    motif_a = [rng.choice([0, 2, 4, 1, 3]) for _ in range(8)]
    rhythm_a = rng.choice([[2, 1, 1, 2, 2, 4, 2, 2], [1, 1, 2, 1, 1, 2, 4, 4], [3, 1, 2, 2, 3, 1, 2, 2]])
    motif_b = [m + rng.choice([2, 3, 4]) for m in motif_a]
    motif_c = [rng.choice([0, 2, 4, 5, 6]) for _ in range(8)]
    rhythm_c = [4, 2, 2, 4, 2, 2, 4, 4]
    rhythm_d = rng.choice([[1, 1, 1, 1, 2, 2, 4, 4], [2, 2, 1, 1, 2, 2, 3, 3]])
    bar_no = 0
    for kind, bars, lift in sections:
        for b in range(bars):
            start = bar_no * bar
            d = (prog[::-1] if kind == "C" else prog)[b % len(prog)]
            quiet = kind == "intro" or (kind == "C" and b < 4)
            ch_notes = chord(root, d)
            # Pad: whole-bar chord.
            for p in ch_notes:
                tracks["pad"].note(start, bar, 3, p, 52)
            # Bass: driving eighths, root with octave jumps.
            for i in range(8):
                p = ch_notes[0] - 24 + (12 if i % 4 == 3 else 0)
                tracks["bass"].note(start + i * PPQ // 2, PPQ // 2, 2, p, 96 if i % 2 == 0 else 80)
            # Arp: sixteenths through the chord.
            pattern = [0, 1, 2, 1, 0, 2, 1, 2]
            for i in range(16):
                p = ch_notes[pattern[i % 8]] + 12
                tracks["arp"].note(start + i * PPQ // 4, PPQ // 4, 1, p, 70 if i % 4 == 0 else 55)
            # Drums (channel 10 = index 9): kick, snare, hats.
            for i in range(8):
                t = start + i * PPQ // 2
                tracks["drums"].note(t, PPQ // 4, 9, 42, 60)
                if i in (0, 4) and not (kind == "C" and b < 4) or (not quiet and i == 5 and b % 2):
                    tracks["drums"].note(t, PPQ // 4, 9, 36, 110)
                if i in (2, 6) and not quiet:
                    tracks["drums"].note(t, PPQ // 4, 9, 38, 100)
            if b % 4 == 3 and not quiet:
                for k in range(4):
                    tracks["drums"].note(start + bar - PPQ + k * PPQ // 4, PPQ // 4, 9, 38, 70 + k * 10)
            # Lead: the motif over 2 bars, answered with a variation.
            if kind != "intro":
                motif = {"B": motif_b, "C": motif_c}.get(kind, motif_a)
                half = b % 2
                pos = start
                unit = PPQ // 2
                notes = motif[half * 4:(half + 1) * 4] + motif[half * 4:(half + 1) * 4][::-1]
                durs = (rhythm_c if kind == "C" else rhythm_d if kind == "D" else rhythm_a)[:]
                t0 = 0
                for i, (m, dur) in enumerate(zip(notes, durs)):
                    if t0 >= 8:
                        break
                    dur = min(dur, 8 - t0)
                    tone = degree(root, d + m, 1 + lift)
                    if b % 4 == 3 and i == len(notes) - 1:
                        tone = ch_notes[0] + 12 * (1 + lift)
                    tracks["lead"].note(pos + t0 * unit, dur * unit, 0, tone, 100)
                    t0 += dur
            bar_no += 1
    data = b"MThd" + struct.pack(">IHHH", 6, 1, 1 + len(tracks), PPQ) + conductor.encode()
    for tr in tracks.values():
        data += tr.encode()
    (MUSIC / f"{name}.mid").write_bytes(data)


def main():
    MUSIC.mkdir(parents=True, exist_ok=True)
    for name, spec in TRACKS.items():
        compose(name, *spec)
    print(f"wrote {len(TRACKS)} music tracks")


if __name__ == "__main__":
    main()
