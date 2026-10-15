"""Generate stage textures and skies (original, procedural pixel art).

Each theme has a floor, a boundary wall, an obstacle side and top, and a
sky. tools/build.py reads THEME_FOR_MAP to texture each stage map; the
ZMAPINFO map blocks name the sky. Outputs go to src/resources/textures/.
Presentation only.
Run: python tools/art/texture_art.py
"""
from __future__ import annotations

import math
import random
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
TEXTURES = ROOT / "src/resources/textures"

import sys  # noqa: E402
sys.path.insert(0, str(ROOT))
from tools.art.themes import THEMES, THEME_FOR_MAP, EXTRA_KINDS, tex_name, sky_name  # noqa: E402


rng = np.random.default_rng(7)


def noise(w, h, scale, seed):
    """Smooth value noise that tiles: the random grid is tiled 3x3 before
    resizing and the centre copy is kept."""
    r = np.random.default_rng(seed)
    gw, gh = max(2, w // scale), max(2, h // scale)
    small = np.tile(r.random((gh, gw)), (3, 3))
    img = Image.fromarray((small * 255).astype(np.uint8)).resize((w * 3, h * 3), Image.BICUBIC)
    return np.asarray(img, dtype=np.float32)[h:2 * h, w:2 * w] / 255.0


def tileable(a):
    """Blend edges so the texture tiles."""
    h, w = a.shape[:2]
    return a


def colorize(n, dark, light):
    dark = np.array(dark, np.float32); light = np.array(light, np.float32)
    return (dark + (light - dark) * n[..., None]).clip(0, 255)


def quantize(arr, levels=6):
    return (np.round(arr / 255 * levels) / levels * 255).clip(0, 255)


def save(arr, name, w, h):
    img = Image.fromarray(arr.astype(np.uint8), "RGB")
    img = img.resize((w, h), Image.NEAREST)
    img.save(TEXTURES / f"{name}.png", optimize=True)


def speckle(base, seed, density, colour):
    r = np.random.default_rng(seed)
    mask = r.random(base.shape[:2]) < density
    base[mask] = colour
    return base


def fine_noise(w, h, seed, octaves=((1, 0.5), (4, 0.3), (12, 0.2))):
    """Tileable multi-scale noise in [0, 1] at full resolution."""
    total = np.zeros((h, w), np.float32)
    for scale, weight in octaves:
        total += noise(w, h, scale, seed + scale) * weight
    return total / sum(wt for _, wt in octaves)


def big_material(kind):
    """Full-resolution (no pixel doubling) textures: (array, w, h) or None."""
    from tools.art import floor_materials
    if kind in floor_materials.KINDS:
        return floor_materials.material(kind), floor_materials.S, floor_materials.S
    s = sum(ord(c) for c in kind)
    if kind == "mfgrass":
        # Dark mossy grass with fine noise, like the source stage's ground.
        n = fine_noise(128, 128, s)
        a = colorize(n, (34, 74, 38), (58, 108, 52))
        r = np.random.default_rng(s)
        blades = r.random((128, 128))
        a[blades < 0.06] = (24, 58, 30)
        a[blades > 0.95] = (78, 128, 62)
        return a, 128, 128
    if kind == "path":
        n = fine_noise(128, 128, s)
        a = colorize(n, (98, 78, 58), (138, 112, 84))
        r = np.random.default_rng(s)
        a[r.random((128, 128)) < 0.05] = (70, 54, 40)
        a[r.random((128, 128)) > 0.96] = (168, 140, 108)
        return a, 128, 128
    if kind == "water":
        n = fine_noise(128, 128, s, ((2, 0.6), (8, 0.4)))
        a = colorize(n, (28, 62, 96), (60, 110, 150))
        a[(n > 0.62) & (n < 0.66)] = (140, 180, 210)
        return a, 128, 128
    if kind.startswith("pn_"):
        return panorama(kind[3:]), 1024, 256
    return None


# sky kind -> (treeline colour, treeline style) for the distant wall panorama.
PANORAMA = {"forest": ((16, 34, 30), "trees"), "day": ((40, 90, 50), "trees"),
            "dusk": ((40, 25, 60), "trees"), "night": ((14, 22, 40), "trees"),
            "blood": ((40, 10, 20), "spikes"), "snowsky": ((190, 205, 225), "hills"),
            "space": ((10, 6, 24), "none"), "indoor": ((20, 15, 20), "none")}


def panorama(kind):
    """1024x256 wall texture: horizon-coloured haze with a treeline at the
    bottom. It is stretched (x4, y8 in the map) over the boundary wall, so
    the silhouette is drawn half height to look natural."""
    w, h = 1024, 256
    top, bottom = SKY_COLOURS[kind]
    t = np.linspace(0, 1, h)[:, None, None]
    # top of the wall meets the ceiling sky; the bottom is the horizon haze
    # Flat horizon haze: the same colour as the sky's last row, so the wall
    # dissolves into the sky above it.
    a = np.zeros((h, w, 3), np.float32) + (np.array(bottom, np.float32) * 0.72 + np.array(top, np.float32) * 0.28)
    colour, style = PANORAMA[kind]
    r = random.Random(kind)
    base = h - 4
    if style == "trees":
        x = 0
        while x < w:
            tw = r.randint(14, 30); th = r.randint(10, 26)
            for i in range(tw):
                # a pointed conifer outline
                height = int(th * (1 - abs(i - tw / 2) / (tw / 2)) ** 0.8) + 3
                a[max(0, base - height):h, (x + i) % w] = colour
            x += r.randint(6, 18)
    elif style == "hills":
        xs = np.arange(w)
        edge = base - 6 - (6 * np.sin(xs / 90.0) + 4 * np.sin(xs / 37.0)).astype(int)
        for x in range(w):
            a[edge[x]:h, x] = colour
    elif style == "spikes":
        x = 0
        while x < w:
            tw = r.randint(3, 8); th = r.randint(8, 34)
            for i in range(tw):
                height = int(th * (1 - abs(i - tw / 2) / (tw / 2)))
                a[max(0, base - height):h, (x + i) % w] = colour
            x += r.randint(4, 14)
    a[h - 3:, :] = colour
    return a


def material(kind):
    """Returns (array at 32x32 or 32x64 pixel scale, out width, out height)."""
    s = sum(ord(c) for c in kind)
    if kind in ("grass", "grass_dark", "moongrass", "field", "meadow"):
        tint = {"grass": ((40, 110, 45), (90, 170, 70)), "grass_dark": ((25, 70, 35), (60, 120, 55)),
                "moongrass": ((30, 50, 90), (70, 110, 160)), "field": ((90, 130, 50), (160, 190, 80))}[kind]
        a = colorize(noise(32, 32, 4, s), *tint)
        a = speckle(a, s + 1, 0.05, np.array(tint[1]) * 1.15)
        return quantize(a), 64, 64
    if kind in ("dirt", "ash", "straw", "snow"):
        tint = {"dirt": ((90, 60, 35), (150, 105, 60)), "ash": ((50, 45, 50), (95, 85, 90)),
                "straw": ((170, 140, 60), (230, 200, 100)), "snow": ((200, 215, 235), (250, 252, 255))}[kind]
        a = colorize(noise(32, 32, 3, s), *tint)
        a = speckle(a, s + 2, 0.04, np.array(tint[0]) * 0.8)
        return quantize(a), 64, 64
    if kind in ("planks", "planks_dark", "planks_teal", "barnwood", "fence", "track"):
        tint = {"planks": ((110, 70, 40), (170, 115, 65)), "planks_dark": ((60, 38, 25), (100, 65, 40)),
                "planks_teal": ((40, 80, 85), (70, 130, 130)), "barnwood": ((110, 40, 35), (160, 60, 50)),
                "fence": ((120, 85, 50), (180, 135, 80)), "track": ((80, 70, 65), (120, 105, 95))}[kind]
        n = noise(32, 32, 2, s) * 0.5 + 0.25
        a = colorize(n, *tint)
        for y in range(0, 32, 8):
            a[y, :] = np.array(tint[0]) * 0.6
        for i, y in enumerate(range(0, 32, 8)):
            x = (i * 13 + s) % 32
            a[y:y + 8, x] = np.array(tint[0]) * 0.6
        if kind == "track":
            a[:, 6:9] = (150, 150, 160); a[:, 23:26] = (150, 150, 160)
        return quantize(a), 64, 64
    if kind in ("flagstone", "marble", "labtile", "metal", "metal_dark", "starfloor"):
        tint = {"flagstone": ((85, 85, 95), (130, 130, 140)), "marble": ((200, 195, 205), (245, 240, 245)),
                "labtile": ((170, 190, 190), (215, 230, 230)), "metal": ((110, 120, 135), (160, 170, 185)),
                "metal_dark": ((50, 55, 65), (90, 95, 110)), "starfloor": ((25, 15, 55), (60, 35, 110))}[kind]
        a = colorize(noise(32, 32, 4, s) * 0.6 + 0.2, *tint)
        step = 16
        for i in range(0, 32, step):
            a[i, :] = np.array(tint[0]) * 0.7; a[:, i] = np.array(tint[0]) * 0.7
        if kind == "starfloor":
            a = speckle(a, s, 0.03, (250, 240, 200))
        if kind in ("metal", "metal_dark"):
            for (x, y) in ((3, 3), (12, 3), (3, 12), (12, 12)):
                a[y, x] = (200, 205, 215); a[y + 16, x + 16] = (200, 205, 215)
        return quantize(a), 64, 64
    if kind in ("brick", "stonewall", "starwall"):
        tint = {"brick": ((100, 45, 40), (160, 75, 60)), "stonewall": ((70, 70, 80), (120, 120, 130)),
                "starwall": ((40, 25, 80), (90, 60, 150))}[kind]
        a = colorize(noise(32, 64, 3, s) * 0.6 + 0.2, *tint)
        mortar = np.array(tint[0]) * 0.55
        for row, y in enumerate(range(0, 64, 8)):
            a[y, :] = mortar
            off = 8 if row % 2 else 0
            for x in range(off, 32, 16):
                a[y:y + 8, x] = mortar
        if kind == "starwall":
            a = speckle(a, s, 0.02, (250, 240, 200))
        return quantize(a), 64, 128
    if kind == "shelf":
        a = np.zeros((64, 32, 3), np.float32) + (70, 45, 28)
        r = random.Random(s)
        for shelf in range(0, 64, 16):
            a[shelf:shelf + 2, :] = (110, 72, 40)
            x = 1
            while x < 31:
                w = r.randint(2, 4); hgt = r.randint(9, 13)
                col = r.choice([(160, 40, 40), (40, 70, 150), (40, 120, 60), (170, 140, 50), (110, 50, 120), (200, 190, 170)])
                a[shelf + 16 - hgt:shelf + 16, x:x + w] = col
                a[shelf + 16 - hgt:shelf + 16, x] = np.array(col) * 0.7
                x += w
        return a, 64, 128
    if kind in ("hedge", "hedge_night", "leaves", "leaves_night"):
        tint = {"hedge": ((20, 70, 30), (60, 140, 55)), "hedge_night": ((15, 30, 50), (40, 70, 100)),
                "leaves": ((25, 90, 35), (80, 170, 70)), "leaves_night": ((20, 40, 70), (50, 90, 130))}[kind]
        tall = kind.startswith("hedge")
        a = colorize(noise(32, 64 if tall else 32, 2, s), *tint)
        a = speckle(a, s + 3, 0.08, np.array(tint[1]) * 1.2)
        a = speckle(a, s + 4, 0.08, np.array(tint[0]) * 0.7)
        return quantize(a), 64, 128 if tall else 64
    if kind == "bark":
        a = colorize(noise(32, 64, 2, s), (60, 40, 25), (110, 75, 45))
        for x in range(0, 32, 5):
            a[:, x] = (45, 30, 20)
        return quantize(a), 64, 128
    if kind in ("crate", "crate_top"):
        a = colorize(noise(32, 32, 2, s) * 0.5 + 0.25, (130, 90, 45), (185, 135, 70))
        a[0:2, :] = a[-2:, :] = a[:, 0:2] = a[:, -2:] = (90, 60, 30)
        if kind == "crate":
            for i in range(32):
                a[i, i] = a[i, 31 - i] = (100, 68, 35)
        return quantize(a), 64, 64
    if kind in ("hay", "hay_top"):
        a = colorize(noise(32, 32, 1, s), (180, 150, 60), (240, 210, 110))
        for y in range(3, 32, 10):
            a[y, :] = (140, 110, 40)
        return quantize(a), 64, 64
    if kind == "pillar":
        a = colorize(noise(32, 64, 4, s) * 0.4 + 0.3, (170, 165, 175), (230, 225, 235))
        for x in (4, 10, 16, 22, 28):
            a[:, x] = (140, 135, 150)
        a[0:4, :] = a[-4:, :] = (150, 145, 160)
        return quantize(a), 64, 128
    if kind == "ice":
        a = colorize(noise(32, 64, 4, s), (120, 170, 220), (210, 235, 255))
        return quantize(a), 64, 128
    if kind == "bones":
        a = colorize(noise(32, 64, 2, s) * 0.3, (40, 35, 40), (80, 70, 75))
        r = random.Random(s)
        for _ in range(28):
            x, y = r.randint(2, 29), r.randint(2, 61)
            a[y, x - 2:x + 3] = (230, 225, 205); a[y - 1:y + 2, x - 2] = (230, 225, 205); a[y - 1:y + 2, x + 2] = (230, 225, 205)
        return quantize(a), 64, 128
    raise ValueError(kind)


SKY_COLOURS = {"day": ((70, 130, 220), (190, 225, 250)), "dusk": ((60, 40, 110), (240, 140, 90)),
               "night": ((10, 12, 40), (40, 50, 100)), "blood": ((40, 5, 15), (150, 40, 40)),
               "snowsky": ((150, 170, 200), (230, 235, 245)), "space": ((5, 3, 15), (30, 15, 60)),
               "indoor": ((20, 15, 20), (50, 35, 40)),
               # Mad Forest: a teal night that fades into the haze at the horizon.
               "forest": ((14, 20, 56), (74, 112, 110))}


def sky(kind):
    w, h = 512, 256
    top, bottom = SKY_COLOURS[kind]
    t = np.linspace(0, 1, h)[:, None, None]
    a = (np.array(top, np.float32) * (1 - t) + np.array(bottom, np.float32) * t).repeat(w, axis=1)
    r = random.Random(kind)
    if kind in ("night", "space", "blood", "forest"):
        for _ in range(160 if kind == "forest" else 400):
            a[r.randint(0, h // 2 + 60), r.randint(0, w - 1)] = (255, 250, 220) if kind != "forest" else (150, 170, 190)
        if kind in ("night", "forest"):
            yy, xx = np.ogrid[:h, :w]
            a[(xx - 380) ** 2 + (yy - 60) ** 2 < 500] = (245, 240, 210)
        if kind == "blood":
            yy, xx = np.ogrid[:h, :w]
            a[(xx - 120) ** 2 + (yy - 56) ** 2 < 600] = (230, 60, 50)
    if kind in ("day", "dusk", "snowsky"):
        cloud = noise(w, h, 32, 3) ** 3
        c = np.array((255, 245, 235) if kind != "dusk" else (250, 180, 150), np.float32)
        a = a * (1 - cloud[..., None] * 0.8) + c * cloud[..., None] * 0.8
    if kind == "indoor":
        for x in range(0, w, 64):
            a[:, x:x + 5] = (15, 10, 12)
    img = Image.fromarray(quantize(a, 64).astype(np.uint8), "RGB")
    img.save(TEXTURES / f"{sky_name(kind)}.png", optimize=True)


def main():
    TEXTURES.mkdir(parents=True, exist_ok=True)
    kinds = sorted({k for t in THEMES.values() for k in t[:4]} | set(EXTRA_KINDS))
    for kind in kinds:
        big = big_material(kind)
        if big is not None:
            arr, w, h = big
            Image.fromarray(arr.astype(np.uint8), "RGB").save(TEXTURES / f"{tex_name(kind)}.png", optimize=True)
            continue
        arr, w, h = material(kind)
        save(arr, tex_name(kind), w, h)
    for kind in sorted({t[4] for t in THEMES.values()}):
        sky(kind)
    print(f"wrote {len(kinds)} textures and skies")


if __name__ == "__main__":
    main()
