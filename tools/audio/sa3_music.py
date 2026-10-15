"""Generate the game's music with Stable Audio 3 Medium.

Prompting (Stable Audio 3 prompt guide + testing, 2026-10-14): "TrackType: Music, " then a
short paragraph in the guide's style: genre and setting first, then each instrument with
its role ("a harpsichord plays fast arpeggios while a solo violin carries the melody"),
then mood, key and tempo. The distilled Medium model wants 8 steps; guidance 3 with a
negative prompt keeps it on the brief.
What Medium renders faithfully (isolated-stem test scored with CLAP, 3 seeds each):
harpsichord, music box, vibraphone, harp, flute, acoustic guitar, distorted electric guitar,
pizzicato strings, brass, drum kit, chiptune, a solo violin, a gregorian choir, an 80s
sawtooth synth lead. Unreliable: piano (comes out as vibraphone / harp / music box) and
church or pipe organ (comes out as a cheesy electric organ, whatever the wording). The
track prompts avoid those two, and each track lists the instruments it wants and the ones
that must not appear; tools/audio/music_instruments.py measures both in every candidate.
The negative prompt is per track (a shared "distortion" negative used to remove the
Gallo Tower guitars).

Per track: generate CANDIDATES takes of TRACK_SECONDS, rank them with
tools/audio/music_metrics.py (key fit, tonality, beat clarity, tempo, steadiness), how
well they match the description (CLAP, tools/audio/clap_score.py) and whether the asked
instruments are there without intruders (music_instruments.py), turn the best TOP into
seamless loops by letting the model rewrite the join (Sa3.make_loop), re-score, save them
under the review folder and record the best as picked. tools/audio/music_master.py then
masters the picked take into src/resources/music/<NAME>.ogg. Listen in game and swap a take
with --use. The MIDI versions remain in assets/music-midi.

Run (needs the audio environment, see tools/audio/sa3_generate.py):
    %USERPROFILE%\\sa3-env\\Scripts\\python.exe tools/audio/sa3_music.py              # all
    ... tools/audio/sa3_music.py DSTITLE                                              # some
    ... tools/audio/sa3_music.py --use DSTITLE 2                                      # pick take 2
    ... tools/audio/sa3_music.py --candidates 24 DSGALLO                              # more tries
then   python tools/audio/music_master.py
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parent))
from paths import REVIEW_ROOT   # noqa: E402
from music_metrics import metrics   # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
MUSIC_DIR = ROOT / "src/resources/music"
REVIEW = REVIEW_ROOT / "music3m2"   # music3m: the first Medium set (piano/organ prompts)
CANDIDATES = 16
TOP = 3
TRACK_SECONDS = 120   # two minutes before the loop repeats
TARGET_RMS = 0.10     # all tracks are levelled to the same loudness
MAX_PEAK = 0.9

# lump name: (prompt, bpm, tonic, minor, wanted instruments, unwanted instruments) -- the
# instrument names are music_instruments.INSTRUMENTS. Which map plays which: ZMAPINFO (and
# the title screen, ui/shell/ShellMenu.zs). The four in-scope stages each have their own theme.
ALWAYS_UNWANTED = ["electric organ", "accordion", "saxophone", "singing voice"]
TRACKS = {
    "DSTITLE": ("A gothic fantasy title theme for a vampire-hunting adventure, one steady groove from start to finish. A live drum kit plays a steady driving beat at 110 BPM; a baroque harpsichord plays a dramatic arpeggio motif locked to that beat while a solo violin sings the melody above it, and a gregorian choir hums underneath. Heroic, mysterious and grand. D minor, 110 BPM.",
                110, "D", True, ["harpsichord", "violin and strings", "drum kit", "choir", "orchestral percussion"], ["synth lead", "chiptune", "distorted electric guitar"]),
    "DSFOREST": ("Upbeat gothic action music for a haunted forest at night in a retro action game. Fast baroque harpsichord arpeggios drive the track over a punchy live drum kit and a galloping bass guitar. A retro chiptune square-wave lead plays a catchy heroic melody, answered by a flute. Energetic and adventurous. A minor, 150 BPM.",
                 150, "A", True, ["harpsichord", "drum kit", "chiptune", "bass guitar", "flute"], ["music box", "choir", "synth lead"]),
    "DSLIBRA": ("Mysterious baroque chamber music for a haunted library. A harpsichord plays elegant counterpoint while pizzicato strings tiptoe underneath and a solo violin carries an eerie melody. Soft brushed drums keep a steady pulse and a harp adds sparkling arpeggios. Eerie and elegant. D minor, 132 BPM.",
                132, "D", True, ["harpsichord", "pizzicato strings", "violin and strings", "harp"], ["synth lead", "chiptune", "distorted electric guitar"]),
    "DSDAIRY": ("Quirky industrial action music for a creepy dairy factory. Bouncy pizzicato strings and a plucky bass guitar play a playful riff over a punchy live drum kit, while clanking metal percussion and anvil hits keep a mechanical rhythm. A muted brass section answers with short stabs. Mischievous and driving. E minor, 140 BPM.",
                140, "E", True, ["pizzicato strings", "bass guitar", "drum kit", "metal clanking", "brass and trumpets"], ["music box", "chiptune"]),
    "DSGALLO": ("Epic gothic rock instrumental for climbing a cursed tower. Heavy distorted electric guitar riffs gallop over a thundering live drum kit and bass guitar. An orchestral brass section and a gregorian choir swell behind the riffs, and a solo violin plays a soaring melody in the breaks. Tense and heroic. C minor, 156 BPM.",
                156, "C", True, ["distorted electric guitar", "drum kit", "brass and trumpets", "choir", "violin and strings"], ["music box", "chiptune"]),
    "DSDEPTH": ("Dark dungeon-crawler music for descending into ancient catacombs in a roguelike, one steady groove from start to finish. A deep plucked bass guitar and a steady live drum kit keep a tense marching beat, pizzicato strings creep in the low register, eerie bells toll at the start of each phrase, a harp plays haunting arpeggios and a distant gregorian choir hums. Ominous, adventurous and mysterious. A minor, 120 BPM.",
                120, "A", True, ["bass guitar", "drum kit", "pizzicato strings", "bells", "harp", "choir"], ["synth lead", "chiptune", "distorted electric guitar", "music box"]),
    "DSFIELD": ("Lively adventure music for an overworld in a retro action game. An acoustic guitar strums a bouncy rhythm and a flute plays a cheerful melody, while harp arpeggios sparkle over a light live drum kit and bass guitar. Bright and energetic. A minor, 148 BPM.",
                148, "A", True, ["acoustic guitar", "flute", "harp", "drum kit", "bass guitar"], ["distorted electric guitar", "choir"]),
    "DSGOTHC": ("Dark cinematic gothic music in straight 4/4, one steady groove from start to finish. A live drum kit plays a straight driving rock beat; a string orchestra plays a tense ostinato of even eighth notes locked to that beat, timpani hits mark the downbeats, brass stabs punctuate each phrase, and a gregorian choir chants in the background. No triplets, no swing. Ominous and driving. E minor, 138 BPM.",
                138, "E", True, ["violin and strings", "orchestral percussion", "drum kit", "brass and trumpets", "choir"], ["music box", "chiptune", "synth lead"]),
    "DSNIGHT": ("Dreamy nocturne for a moonlit night. A vibraphone plays a slow mysterious melody over gentle harp arpeggios, soft brushed drums and a warm upright bass. Calm and mysterious. C minor, 118 BPM.",
                118, "C", True, ["vibraphone", "harp", "drum kit", "bass guitar"], ["distorted electric guitar", "chiptune", "brass and trumpets"]),
    "DSFROST": ("Delicate winter music for a cold quiet night. A music box and glassy bells play a fragile melody, a solo violin answers softly, and harp arpeggios drift over light percussion. Cold and calm. E minor, 130 BPM.",
                130, "E", True, ["music box", "bells", "violin and strings", "harp"], ["distorted electric guitar", "drum kit", "brass and trumpets"]),
    "DSCOSMC": ("Retro space exploration music. A pulsing synth bass drives an electronic drum machine beat, while sparkling bell and vibraphone arpeggios shimmer above and a retro chiptune square-wave lead plays a wide wondrous melody. Spacious and dreamy. G minor, 126 BPM.",
                126, "G", True, ["synth bass", "electronic drums", "bells", "vibraphone", "chiptune"], ["acoustic guitar", "harpsichord", "brass and trumpets", "synth lead"]),
    "DSBATTL": ("Relentless cinematic battle music. A string orchestra hammers a staccato ostinato, a brass section blasts heroic stabs, and timpani and a live drum kit pound under it all. Urgent and heroic. D minor, 156 BPM.",
                156, "D", True, ["violin and strings", "brass and trumpets", "orchestral percussion", "drum kit"], ["music box", "chiptune", "vibraphone"]),
}
NEGATIVE = "vocals, lyrics, speech, noise, harsh, muffled, low quality, clipping, silence, organ, hammond organ"
INSTRUMENT_WEIGHT = 0.6   # times the share of the asked instruments (0..1)
INTRUDER_PENALTY = 1.5    # times the share of each unwanted instrument that is clearly present
TEMPO_WEIGHT = 0.8        # times (consistency - 1): a take whose 15 s windows disagree on the pulse sounds like
                          # several songs at once (music_metrics.tempo_consistency)
CLAP_WEIGHT = 0.15    # music_metrics scores are ~0..1; CLAP is added pool-normalised at this weight


def level(audio: np.ndarray) -> np.ndarray:
    """Same loudness for every track, without clipping."""
    rms = float(np.sqrt(np.mean(audio ** 2))) or 1.0
    out = audio * (TARGET_RMS / rms)
    top = float(np.max(np.abs(out)))
    if top > MAX_PEAK:
        out = out * (MAX_PEAK / top)
    return out.astype(np.float32)


def seam_ratio(audio: np.ndarray, rate: int) -> float:
    """How much the sound jumps at the loop point compared with normal movement (1 = same)."""
    win = rate

    def spec(x):
        return np.log1p(np.abs(np.fft.rfft(x.mean(axis=1) * np.hanning(len(x))))[:3000])

    wrap = np.linalg.norm(spec(audio[-win:]) - spec(audio[:win]))
    typical = [np.linalg.norm(spec(audio[i:i + win]) - spec(audio[i + win:i + 2 * win]))
               for i in range(win * 5, audio.shape[0] - win * 3, win * 2)]
    return float(wrap / (np.mean(typical) or 1.0))


def write_ogg(path: Path, audio: np.ndarray, rate: int) -> None:
    # libsndfile's Vorbis encoder crashes on float input and on one big write on this
    # setup; 16-bit data written in small blocks is fine.
    pcm = np.clip(audio * 32767.0, -32768, 32767).astype(np.int16)
    with sf.SoundFile(path, "w", samplerate=rate, channels=pcm.shape[1], format="OGG", subtype="VORBIS") as out:
        for start in range(0, len(pcm), 4096):
            out.write(pcm[start: start + 4096])


def negative_for(unwanted: list[str]) -> str:
    return NEGATIVE + ", " + ", ".join(unwanted)


def render(model, clap, name: str, candidates: int = CANDIDATES) -> None:
    from music_instruments import check, profile   # noqa: E402  (needs CLAP)
    prompt, bpm, tonic, minor, wanted, unwanted = TRACKS[name]
    unwanted = unwanted + ALWAYS_UNWANTED
    full = f"TrackType: Music, {prompt}"
    if "one steady groove" not in prompt:
        # sections that drift to another tempo or a triplet layer sound like several songs at once
        full += " One steady groove from start to finish, every instrument locked to the same beat."
    folder = REVIEW / name
    folder.mkdir(parents=True, exist_ok=True)
    rate = model.sample_rate
    raws = []
    for k in range(candidates):
        raw = model.generate(full, TRACK_SECONDS, cfg_scale=3.0, seed=9000 + k * 37, negative=negative_for(unwanted))
        c = check(profile(clap, raw, rate), wanted, unwanted)
        bonus = INSTRUMENT_WEIGHT * c["wanted_share"] - INTRUDER_PENALTY * sum(c["intruders"].values())
        mm = metrics(raw, rate, bpm, tonic, minor)
        raws.append([mm["score"] + TEMPO_WEIGHT * (mm["consistent"] - 1.0), raw, bonus, c])
    sims = np.array(clap.similarity(prompt, [r[1][: rate * 30] for r in raws], rate))   # first 30 s
    z = (sims - sims.mean()) / (sims.std() or 1.0)
    for r, zz in zip(raws, z):
        r[2] += CLAP_WEIGHT * float(zz)
        r[0] += r[2]
    raws.sort(key=lambda item: -item[0])
    print(f"  {name}: raw scores {[round(r[0], 2) for r in raws]}", flush=True)
    best_score, best_take = -1e18, 0
    for take, (_score, raw, bonus, c) in enumerate(raws[:TOP], 1):
        loop = model.make_loop(raw, full, seed=500 + take)
        m = metrics(loop, rate, bpm, tonic, minor)
        seam = seam_ratio(loop, rate)
        final = m["score"] - max(0.0, seam - 1.2) * 0.15 + bonus + TEMPO_WEIGHT * (m["consistent"] - 1.0)
        write_ogg(folder / f"take{take}.ogg", level(loop), rate)
        print(f"  {name} take{take}: score {m['score']:.2f} key {m['key_fit']:.2f} beat {m['beat']:.2f} "
              f"bpm {m['bpm']:.0f} seam x{seam:.2f} pulse {m['consistent']:.2f} wanted {c['wanted_share']:.2f} intruders {c['intruders']} -> {final:.2f}", flush=True)
        if final > best_score:
            best_score, best_take = final, take
    (folder / "picked.txt").write_text(f"{best_take}\n", encoding="utf-8")
    print(f"{name}: picked take {best_take} (run music_master.py to install)", flush=True)


def main() -> None:
    args = sys.argv[1:]
    if args and args[0] == "--use":
        name, take = args[1], int(args[2])
        (REVIEW / name / "picked.txt").write_text(f"{take}\n", encoding="utf-8")
        print(f"{name}: take {take} picked; run music_master.py to install")
        return
    candidates = CANDIDATES
    if args and args[0] == "--candidates":
        candidates, args = int(args[1]), args[2:]
    from sa3_generate import Sa3   # noqa: E402  (needs the audio environment)
    from clap_score import Clap    # noqa: E402
    model = Sa3("medium")
    clap = Clap()
    for name in args or list(TRACKS):
        render(model, clap, name, candidates)


if __name__ == "__main__":
    main()
