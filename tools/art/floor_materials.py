"""Full-resolution floor materials for the stage maps (original procedural art).

Each returns an RGB float array (size x size, tileable). Used by
texture_art.big_material. Names are the kinds in tools/art/themes.py (at most
seven characters so the lump name T<KIND> fits eight). Presentation only.
"""
from __future__ import annotations

import numpy as np

S = 128


def _noise(w, h, scale, seed):
    from PIL import Image
    r = np.random.default_rng(seed)
    gw, gh = max(2, w // scale), max(2, h // scale)
    small = np.tile(r.random((gh, gw)), (3, 3))
    img = Image.fromarray((small * 255).astype(np.uint8)).resize((w * 3, h * 3), Image.BICUBIC)
    return np.asarray(img, dtype=np.float32)[h:2 * h, w:2 * w] / 255.0


def fine(seed, octaves=((1, 0.5), (4, 0.3), (12, 0.2)), size=S):
    total = np.zeros((size, size), np.float32)
    for scale, weight in octaves:
        total += _noise(size, size, scale, seed + scale) * weight
    return total / sum(w for _, w in octaves)


def ramp(n, dark, light):
    dark = np.array(dark, np.float32)
    light = np.array(light, np.float32)
    return dark + (light - dark) * n[..., None]


def specks(a, seed, density_dark, density_light, dark, light):
    r = np.random.default_rng(seed)
    v = r.random(a.shape[:2])
    a[v < density_dark] = dark
    a[v > 1 - density_light] = light
    return a


def tile_lines(a, step, colour, width=1):
    c = np.array(colour, np.float32)
    for i in range(0, a.shape[0], step):
        a[i:i + width, :] = c
        a[:, i:i + width] = c
    return a


def grass(seed, dark, light, flecks=((24, 58, 30), (78, 128, 62))):
    a = ramp(fine(seed), dark, light)
    return specks(a, seed, 0.06, 0.05, flecks[0], flecks[1])


def material(kind):
    s = sum(ord(c) for c in kind) * 7
    if kind == "acresa":
        return grass(s, (52, 92, 42), (70, 112, 54), ((44, 80, 36), (84, 126, 64)))
    if kind == "acresb":
        return grass(s, (40, 74, 34), (56, 92, 44), ((34, 64, 30), (70, 106, 56)))
    if kind == "molgras":
        a = grass(s, (56, 128, 58), (98, 170, 78), ((40, 100, 48), (130, 196, 96)))
        r = np.random.default_rng(s + 1)
        v = r.random((S, S))
        a[v < 0.004] = (240, 140, 70)
        a[(v > 0.004) & (v < 0.008)] = (250, 240, 120)
        a[(v > 0.008) & (v < 0.011)] = (236, 110, 170)
        return a
    if kind == "bonedrt":
        a = ramp(fine(s), (88, 62, 42), (132, 96, 62))
        a = specks(a, s, 0.05, 0.03, (62, 44, 30), (214, 204, 180))
        return a
    if kind == "batrock":
        a = ramp(fine(s, ((2, 0.6), (8, 0.4))), (104, 88, 70), (150, 128, 100))
        return specks(a, s, 0.05, 0.04, (80, 66, 52), (184, 162, 128))
    if kind == "snowfin":
        a = ramp(fine(s, ((2, 0.6), (10, 0.4))), (206, 220, 242), (250, 253, 255))
        return specks(a, s, 0.04, 0.0, (176, 196, 226), (255, 255, 255))
    if kind == "tealtil":
        a = ramp(fine(s, ((4, 0.7), (16, 0.3))), (38, 86, 104), (72, 134, 150))
        a = tile_lines(a, 64, (22, 50, 66), 2)
        for cx in (32, 96):
            for cy in (32, 96):
                a[cy - 3:cy + 3, cx - 3:cx + 3] = (112, 176, 184)
        return a
    if kind == "starflr":
        a = ramp(fine(s, ((8, 0.6), (32, 0.4))), (10, 8, 26), (30, 18, 58))
        return specks(a, s, 0.0, 0.012, (0, 0, 0), (236, 232, 255))
    if kind == "westgrs":
        return grass(s, (26, 64, 54), (42, 88, 70), ((20, 48, 42), (64, 118, 92)))
    if kind == "wtrdark":
        n = fine(s, ((2, 0.6), (8, 0.4)))
        a = ramp(n, (20, 50, 92), (46, 92, 146))
        a[(n > 0.62) & (n < 0.66)] = (120, 160, 210)
        return a
    if kind == "sandst":
        a = ramp(fine(s, ((4, 0.6), (16, 0.4))), (170, 158, 130), (200, 188, 160))
        return tile_lines(a, 64, (138, 126, 102), 1)
    if kind == "redbord":
        a = ramp(fine(s, ((4, 0.6), (16, 0.4))), (118, 30, 32), (150, 46, 42))
        a[::16, :] = (92, 22, 26)
        return a
    if kind == "cloudpl":
        n = fine(s, ((8, 0.5), (16, 0.5)))
        a = ramp(n, (70, 196, 240), (150, 228, 252))
        c = fine(s + 5, ((10, 0.6), (24, 0.4)))
        a[c > 0.6] = (240, 250, 255)
        return a
    if kind == "concret":
        a = ramp(fine(s, ((4, 0.6), (16, 0.4))), (104, 108, 106), (134, 138, 136))
        a = tile_lines(a, 32, (84, 88, 88), 1)
        return specks(a, s, 0.03, 0.02, (78, 80, 80), (158, 160, 158))
    if kind == "milk":
        n = fine(s, ((4, 0.6), (16, 0.4)))
        return ramp(n, (226, 232, 230), (250, 252, 248))
    if kind == "wrehous":
        a = ramp(fine(s, ((2, 0.5), (8, 0.5))), (58, 42, 30), (86, 62, 44))
        a[::16, :] = (40, 28, 20)
        return a
    if kind == "parquet":
        a = ramp(fine(s, ((2, 0.5), (8, 0.5))), (148, 86, 58), (182, 112, 76))
        for y in range(0, S, 16):
            off = 32 if (y // 16) % 2 else 0
            a[y, :] = (110, 62, 44)
            for x in range(off, S, 64):
                a[y:y + 16, x] = (110, 62, 44)
        return a
    if kind == "rugred":
        a = ramp(fine(s), (92, 30, 46), (124, 46, 62))
        a[::32, :] = (170, 130, 70)
        a[:, ::32] = (170, 130, 70)
        return a
    if kind == "galflr":
        a = ramp(fine(s, ((4, 0.6), (16, 0.4))), (36, 34, 80), (60, 54, 108))
        a = tile_lines(a, 32, (24, 22, 56), 1)
        return specks(a, s, 0.02, 0.01, (26, 24, 60), (96, 90, 150))
    if kind == "carpetr":
        a = ramp(fine(s), (112, 30, 38), (150, 48, 52))
        a[::64, :] = (196, 160, 80)
        a[:, ::64] = (196, 160, 80)
        return a
    if kind == "labfine":
        a = ramp(fine(s, ((4, 0.6), (16, 0.4))), (118, 130, 138), (158, 170, 176))
        a = tile_lines(a, 32, (84, 94, 102), 1)
        return specks(a, s, 0.02, 0.0, (70, 80, 88), (0, 0, 0))
    if kind == "stonefn":
        a = ramp(fine(s, ((4, 0.6), (16, 0.4))), (92, 92, 104), (130, 130, 142))
        return tile_lines(a, 64, (66, 66, 78), 2)
    return None


KINDS = ("acresa", "acresb", "molgras", "bonedrt", "batrock", "snowfin", "tealtil", "starflr", "westgrs",
         "wtrdark", "sandst", "redbord", "cloudpl", "concret", "milk", "wrehous", "parquet", "rugred",
         "galflr", "carpetr", "labfine", "stonefn")
