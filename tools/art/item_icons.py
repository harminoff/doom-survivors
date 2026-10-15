"""Generate HUD item icons (original pixel art), one per catalog item.

Reads ids and names from ItemCatalog.zs, picks a motif by keyword in the
name and a palette from the name's hash, and writes 32x32 PNGs named
HI<id> (three digits) to src/resources/graphics/. Evolutions and unions
(single-rank weapons) get a gold frame. Presentation only.
Run: python tools/art/item_icons.py
"""
from __future__ import annotations

import hashlib
import math
import re
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "src/zscript/gameplay/catalog/ItemCatalog.zs"
OUT = ROOT / "src/resources/graphics"
OUTLINE = (24, 14, 30, 255)
WHITE = (255, 255, 255, 255)
GOLD = (250, 205, 60, 255)
S = 16


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c[:3]) + (255,)


def pal(name: str):
    h = hashlib.md5(name.encode()).digest()
    hue = h[0] / 255.0
    def hsv(hh, s, v):
        import colorsys
        r, g, b = colorsys.hsv_to_rgb(hh % 1.0, s, v)
        return (int(r * 255), int(g * 255), int(b * 255), 255)
    return hsv(hue, 0.65, 0.95), hsv(hue + 0.08, 0.3, 1.0), hsv(hue, 0.75, 0.55)


# Each motif draws into a 16x16 canvas with (main, light, dark) colours.
def blade(d, m, l, k):
    d.polygon([(11, 1), (14, 2), (5, 11), (3, 9)], fill=l)
    d.line([(4, 10), (13, 2)], fill=m, width=1)
    d.line([(2, 8), (7, 13)], fill=k, width=2)
    d.rectangle([1, 12, 4, 15], fill=k)


def wand(d, m, l, k):
    d.line([(3, 13), (11, 5)], fill=(150, 100, 60, 255), width=2)
    d.ellipse([9, 1, 14, 6], fill=m)
    d.point([(10, 2)], fill=WHITE)


def axe(d, m, l, k):
    d.line([(4, 14), (11, 3)], fill=(150, 100, 60, 255), width=2)
    d.polygon([(8, 2), (14, 4), (13, 9), (9, 6)], fill=l)
    d.polygon([(9, 3), (13, 5), (12, 8)], fill=m)


def cross(d, m, l, k):
    d.rectangle([6, 1, 9, 14], fill=m)
    d.rectangle([2, 5, 13, 8], fill=m)
    d.rectangle([7, 2, 8, 13], fill=l)


def book(d, m, l, k):
    d.rectangle([2, 2, 13, 14], fill=m)
    d.rectangle([2, 2, 4, 14], fill=k)
    d.rectangle([6, 5, 11, 6], fill=l)
    d.rectangle([6, 8, 11, 9], fill=l)


def drop(d, m, l, k):
    d.polygon([(8, 1), (13, 9), (8, 15), (3, 9)], fill=m)
    d.ellipse([3, 6, 12, 15], fill=m)
    d.point([(6, 9), (6, 10)], fill=WHITE)


def flask(d, m, l, k):
    d.rectangle([6, 1, 9, 5], fill=l)
    d.polygon([(6, 5), (9, 5), (13, 14), (2, 14)], fill=m)
    d.polygon([(4, 10), (11, 10), (13, 14), (2, 14)], fill=k)


def garlic(d, m, l, k):
    d.ellipse([2, 5, 13, 15], fill=(235, 235, 215, 255))
    d.polygon([(8, 1), (10, 6), (6, 6)], fill=(200, 210, 170, 255))
    d.line([(8, 6), (8, 14)], fill=(190, 190, 170, 255))


def bolt(d, m, l, k):
    d.polygon([(9, 1), (3, 9), (7, 9), (5, 15), (13, 6), (8, 6)], fill=GOLD if m[2] < 180 else m)
    d.polygon([(9, 3), (6, 8), (8, 8)], fill=WHITE)


def ring(d, m, l, k):
    d.ellipse([2, 2, 13, 13], outline=m, width=3)
    d.ellipse([6, 0, 9, 3], fill=l)


def star(d, m, l, k):
    pts = []
    for i in range(5):
        a = -math.pi / 2 + i * 2 * math.pi / 5 * 2
        pts.append((7.5 + 7 * math.cos(a), 8 + 7 * math.sin(a)))
    d.polygon(pts, fill=m)
    d.ellipse([5, 5, 10, 10], fill=l)


def orb(d, m, l, k):
    d.ellipse([2, 2, 13, 13], fill=m)
    d.ellipse([4, 4, 8, 8], fill=l)
    d.arc([2, 2, 13, 13], 20, 160, fill=k, width=2)


def wing(d, m, l, k):
    d.polygon([(2, 12), (3, 4), (7, 6), (9, 2), (11, 6), (14, 3), (13, 12), (8, 14)], fill=m)
    d.line([(4, 11), (12, 5)], fill=l)
    d.line([(6, 12), (12, 8)], fill=l)


def heart(d, m, l, k):
    d.ellipse([1, 2, 8, 9], fill=m)
    d.ellipse([7, 2, 14, 9], fill=m)
    d.polygon([(2, 7), (13, 7), (8, 14)], fill=m)
    d.point([(4, 4)], fill=WHITE)


def bird(d, m, l, k):
    d.ellipse([3, 6, 11, 12], fill=m)
    d.polygon([(11, 7), (15, 8), (11, 10)], fill=GOLD)
    d.polygon([(4, 7), (7, 1), (9, 8)], fill=l)
    d.polygon([(3, 10), (0, 12), (4, 12)], fill=k)


def shield(d, m, l, k):
    d.polygon([(2, 2), (13, 2), (13, 9), (8, 15), (2, 9)], fill=m)
    d.polygon([(8, 2), (13, 2), (13, 9), (8, 15)], fill=k)
    d.line([(8, 4), (8, 12)], fill=l)


def crown(d, m, l, k):
    d.polygon([(1, 12), (1, 4), (5, 8), (8, 2), (11, 8), (15, 4), (15, 12)], fill=GOLD)
    d.rectangle([1, 11, 14, 13], fill=shade(GOLD, 0.7))
    d.point([(8, 9), (4, 10), (12, 10)], fill=m)


def clover(d, m, l, k):
    g = (60, 190, 90, 255)
    for cx, cy in ((5, 5), (10, 5), (5, 10), (10, 10)):
        d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=g)
    d.line([(8, 8), (11, 15)], fill=shade(g, 0.6), width=1)


def gem(d, m, l, k):
    d.polygon([(8, 1), (14, 7), (8, 15), (2, 7)], fill=m)
    d.polygon([(8, 1), (14, 7), (8, 8)], fill=l)
    d.polygon([(2, 7), (8, 15), (8, 8)], fill=k)


def clock(d, m, l, k):
    d.ellipse([1, 1, 14, 14], fill=(235, 235, 245, 255), outline=m)
    d.line([(8, 8), (8, 3)], fill=k)
    d.line([(8, 8), (12, 9)], fill=k)


def bone(d, m, l, k):
    w = (240, 235, 215, 255)
    d.line([(4, 12), (12, 4)], fill=w, width=3)
    for p in ((3, 11), (5, 13), (11, 3), (13, 5)):
        d.ellipse([p[0] - 1, p[1] - 1, p[0] + 2, p[1] + 2], fill=w)


def cherry(d, m, l, k):
    r = (220, 30, 60, 255)
    d.ellipse([1, 8, 7, 14], fill=r)
    d.ellipse([8, 9, 14, 15], fill=r)
    d.line([(4, 8), (9, 1)], fill=(60, 150, 60, 255))
    d.line([(11, 9), (9, 1)], fill=(60, 150, 60, 255))


def flame(d, m, l, k):
    d.polygon([(8, 0), (13, 8), (12, 13), (8, 15), (4, 13), (3, 8), (6, 5)], fill=(250, 130, 30, 255))
    d.polygon([(8, 6), (11, 11), (8, 14), (5, 11)], fill=(255, 225, 90, 255))


def skull(d, m, l, k):
    w = (235, 232, 220, 255)
    d.ellipse([2, 1, 13, 11], fill=w)
    d.rectangle([5, 9, 10, 14], fill=w)
    d.rectangle([4, 5, 6, 7], fill=OUTLINE)
    d.rectangle([9, 5, 11, 7], fill=OUTLINE)


def moon(d, m, l, k):
    d.ellipse([2, 1, 14, 14], fill=l)
    d.ellipse([6, 0, 17, 13], fill=(0, 0, 0, 0))


def arrow(d, m, l, k):
    d.line([(2, 13), (12, 3)], fill=m, width=2)
    d.polygon([(14, 1), (14, 8), (7, 1)], fill=l)


def note(d, m, l, k):
    d.ellipse([2, 10, 7, 14], fill=m)
    d.ellipse([9, 8, 14, 12], fill=m)
    d.line([(6, 11), (6, 2)], fill=m, width=1)
    d.line([(13, 9), (13, 1)], fill=m, width=1)
    d.line([(6, 2), (13, 1)], fill=m, width=2)


def box(d, m, l, k):
    d.rectangle([2, 5, 13, 14], fill=m)
    d.rectangle([2, 5, 13, 7], fill=l)
    d.rectangle([7, 5, 8, 14], fill=GOLD)


def mask(d, m, l, k):
    d.ellipse([1, 2, 14, 14], fill=m)
    d.polygon([(3, 6), (7, 7), (6, 9), (3, 8)], fill=OUTLINE)
    d.polygon([(12, 6), (8, 7), (9, 9), (12, 8)], fill=OUTLINE)


def spiral(d, m, l, k):
    for r, a0 in ((6, 0), (4, 90), (2, 180)):
        d.arc([8 - r, 8 - r, 8 + r, 8 + r], a0, a0 + 250, fill=m, width=2)


def leaf(d, m, l, k):
    d.polygon([(2, 14), (3, 4), (11, 2), (14, 3), (12, 11), (4, 14)], fill=(70, 190, 90, 255))
    d.line([(3, 13), (12, 4)], fill=(30, 110, 50, 255))


def dagger(d, m, l, k):
    d.polygon([(8, 0), (10, 9), (6, 9)], fill=l)
    d.rectangle([4, 9, 11, 10], fill=k)
    d.rectangle([7, 10, 8, 15], fill=(150, 100, 60, 255))


def eye(d, m, l, k):
    d.ellipse([1, 4, 14, 11], fill=(240, 240, 240, 255))
    d.ellipse([5, 4, 10, 11], fill=m)
    d.point([(7, 6)], fill=WHITE)


def bell(d, m, l, k):
    d.polygon([(3, 12), (4, 6), (8, 2), (12, 6), (13, 12)], fill=GOLD)
    d.ellipse([6, 12, 9, 15], fill=k)


def gun(d, m, l, k):
    d.rectangle([2, 4, 13, 8], fill=(170, 175, 190, 255))
    d.rectangle([2, 8, 6, 14], fill=(110, 80, 50, 255))
    d.rectangle([12, 3, 14, 5], fill=k)


def candle(d, m, l, k):
    d.rectangle([6, 6, 9, 15], fill=(240, 235, 215, 255))
    d.polygon([(8, 0), (10, 5), (6, 5)], fill=(255, 190, 60, 255))


def fist(d, m, l, k):
    d.rectangle([3, 5, 12, 13], fill=m)
    for x in (3, 6, 9):
        d.rectangle([x, 2, x + 2, 6], fill=l)


# Keyword -> motif; the first match wins.
KEYWORDS = [
    ("whip", blade), ("bloody", blade), ("sword", blade), ("edge", blade), ("blade", blade),
    ("lancet", blade), ("javelin", arrow), ("voulge", arrow), ("knife", dagger), ("dagger", dagger),
    ("axe", axe), ("spiral", spiral), ("wand", wand), ("cross", cross), ("heaven", cross),
    ("bible", book), ("vespers", book), ("tome", book), ("book", book), ("song", note),
    ("water", flask), ("borra", drop), ("garlic", garlic), ("soul", garlic), ("lightning", bolt),
    ("thunder", bolt), ("bolt", bolt), ("tonn", bolt), ("pentagram", star), ("moon", moon),
    ("runetracer", star), ("no future", star), ("rune", star), ("peachone", bird), ("ebony", wing),
    ("vandalier", wing), ("wings", wing), ("pinion", wing), ("valkyrie", wing), ("phiera", star),
    ("eight", bird), ("sparrow", bird), ("vento", wing), ("fuwala", wing), ("bracelet", ring),
    ("ring", ring), ("silver", ring), ("spinach", leaf), ("laurel", leaf), ("armor", shield),
    ("aegis", shield), ("heart", heart), ("pummarola", heart), ("duplicator", ring), ("crown", crown),
    ("tirajis", heart), ("attractorb", orb), ("candelabrador", candle), ("candle", candle), ("clover", clover),
    ("bracer", arrow), ("spellbinder", clock), ("clock", clock), ("corridor", clock), ("bone", bone),
    ("cherry", cherry), ("carr", box), ("box", box), ("candy", box), ("fire", flame), ("flame", flame),
    ("hellfire", flame), ("ashes", flame), ("hunger", skull), ("skull", skull), ("mask", mask),
    ("gaea", eye), ("gaze", eye), ("phas", eye), ("photon", eye), ("gun", gun), ("ammo", gun),
    ("mana", note), ("stone", gem), ("kyra", gem), ("chaos", gem), ("malachite", gem), ("rosalia", gem),
    ("lazulia", gem), ("jubilee", bell), ("bell", bell), ("meta", fist), ("fist", fist),
    ("crimson", drop), ("gatti", eye), ("dusting", star), ("robba", ring), ("mortaccio", skull),
    ("carrozza", box), ("amore", heart), ("daikarin", star),
]
FALLBACK = [orb, gem, star, ring]


def parse():
    text = CATALOG.read_text(encoding="utf8")
    consts = dict(re.findall(r"const (ID_\w+) = (\d+);", text))
    body = text[text.index("static String DisplayName"):]
    names = re.findall(r'if \(id == (ID_\w+)\) return "([^"]+)";', body)
    max1 = set(re.findall(r"if \(id == (ID_\w+)\) return 1;", text))
    return [(int(consts[k]), n, k in max1) for k, n in names]


def motif_for(name: str):
    low = name.lower()
    for kw, fn in KEYWORDS:
        if kw in low:
            return fn
    return FALLBACK[hashlib.md5(name.encode()).digest()[1] % len(FALLBACK)]


def outline(img):
    w, h = img.size
    px = img.load()
    out = img.copy()
    po = out.load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] and px[nx, ny] != OUTLINE:
                    po[x, y] = OUTLINE
                    break
    return out


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    items = parse()
    for item_id, name, single in items:
        img = Image.new("RGBA", (S + 2, S + 2), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        m, l, k = pal(name)
        motif_for(name)(d, m, l, k)
        img = outline(img)
        if single and item_id >= 6 and item_id not in (56, 57, 58):
            # evolution / union: gold sparkle corners
            px = img.load()
            for x, y in ((0, 0), (1, 0), (0, 1), (S + 1, 0), (S, 0), (S + 1, 1)):
                px[x, y] = GOLD
        img = img.resize((img.width * 2, img.height * 2), Image.NEAREST)
        img.save(OUT / f"HI{item_id:03d}.png", optimize=True)
    print(f"wrote {len(items)} item icons")


if __name__ == "__main__":
    main()
