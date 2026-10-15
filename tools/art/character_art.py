"""Generate a front-facing portrait per playable character (original pixel art).

Variations of the survivor figure (palette plus a head style and an extra) so the
select screen can show who you are picking. 24x32 art, outlined, scaled 4x to
graphics/CHP00.png ... in DSCharacters order. Presentation only.
Run: python tools/art/character_art.py
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pickup_art import outline  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
GRAPHICS = ROOT / "src/resources/graphics"
EYE = (30, 20, 30, 255)
MOUTH = (170, 90, 80, 255)

def rgb(h: int) -> tuple[int, int, int, int]:
    return ((h >> 16) & 255, (h >> 8) & 255, h & 255, 255)

def shade(c, f):
    return (min(255, int(c[0] * f)), min(255, int(c[1] * f)), min(255, int(c[2] * f)), 255)

# name: cloak, hair, skin, accent, head style, extra
SKIN = [0xF0C8A0, 0xE8B890, 0xC89070, 0x8A5A3C, 0xF4D4B8]
CHARS = [
    ("Antonio",      0x7A2E2E, 0x2A1A14, 0, 0xD8A030, "bare", "scar"),
    ("Imelda",       0x5A3C8C, 0x7A3A20, 1, 0xE8C050, "long", ""),
    ("Pasqualina",   0x2E7A5C, 0x3A2A20, 0, 0xE8E060, "hood", ""),
    ("Gennaro",      0x3C5C8C, 0x1A1410, 4, 0xC0C8D0, "bare", "stubble"),
    ("Arca",         0xB0481C, 0xC03020, 1, 0xF0A030, "wild", ""),
    ("Porta",        0x3C70B0, 0xE0E0F0, 4, 0x60C8F0, "hat", ""),
    ("Lama",         0x6A5A3C, 0x4A3A2A, 2, 0xB8A070, "bare", "stubble"),
    ("Poe",          0x4A4A5A, 0xD8D8D8, 0, 0x8080A0, "hood", "beard"),
    ("Clerici",      0x2A6AAA, 0x6A4A2A, 0, 0xF0F0F0, "hood", ""),
    ("Dommario",     0x6A2A6A, 0x907040, 4, 0xE0C060, "hat", "beard"),
    ("Krochi",       0xA02828, 0x1A1A1A, 1, 0xE8E8E8, "bare", ""),
    ("Christine",    0x7A3A7A, 0xF0E0A0, 4, 0xE06090, "long", ""),
    ("Pugnala",      0x5A5A2A, 0x1A1410, 4, 0xC0A030, "long", "mask"),
    ("Poppea",       0x3A8A7A, 0xB08050, 0, 0xF0E8C0, "long", ""),
    ("Mortaccio",    0x4A4A3A, 0, 4, 0xB0B090, "skull", ""),
    ("Yatta Cavallo",0x8A5A2A, 0x5A3A1A, 2, 0xE8C080, "horse", ""),
    ("Bianca Ramba", 0xB0B0C8, 0xF0F0F0, 4, 0xE06070, "long", ""),
    ("O'Sole",       0xE0A020, 0x2A1A10, 1, 0xF0F040, "wild", ""),
    ("Zi'Assunta",   0x2A2A3A, 0xC8C8C8, 0, 0xB05050, "hood", "wrinkle"),
    ("Sir Ambrojoe", 0x808898, 0x6A4A30, 0, 0xC0C0D0, "helm", ""),
    ("Exdash",       0x4A6A4A, 0x3A5A2A, 0, 0xF0B040, "bare", "wing"),
    ("Toastie",      0xC89040, 0x6A3A1A, 1, 0xF0D090, "bare", ""),
    ("Giovanna",     0xA02A5A, 0x2A1A20, 3, 0xF0B0C0, "long", ""),
    ("Concetta",     0x3A3A8A, 0x181830, 3, 0xA0A0F0, "long", ""),
    ("Iguana",       0x3A8A3A, 0x205020, 0, 0xB0E050, "hood", "scale"),
    ("Divano",       0x7A6AB0, 0xC0B060, 4, 0xF0E070, "hat", ""),
]


def portrait(spec) -> Image.Image:
    name, cl, hr, sk, ac, head, extra = spec
    cloak = rgb(cl); dark = shade(cloak, 0.65); light = shade(cloak, 1.3)
    hair = rgb(hr) if hr else (0, 0, 0, 255)
    skin = rgb(SKIN[sk]); accent = rgb(ac)
    img = Image.new("RGBA", (28, 34), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ox, oy = 2, 1
    def R(x0, y0, x1, y1, c): d.rectangle([x0 + ox, y0 + oy, x1 + ox, y1 + oy], fill=c)
    def P(pts, c): d.polygon([(x + ox, y + oy) for x, y in pts], fill=c)
    def E(x0, y0, x1, y1, c): d.ellipse([x0 + ox, y0 + oy, x1 + ox, y1 + oy], fill=c)
    # boots, cloak, belt, arms
    R(8, 27, 11, 31, (70, 44, 32, 255)); R(13, 27, 16, 31, (70, 44, 32, 255))
    P([(6, 12), (17, 12), (19, 28), (4, 28)], cloak); P([(6, 12), (11, 12), (11, 28), (4, 28)], dark)
    d.line([(11 + ox, 13 + oy), (11 + ox, 27 + oy)], fill=light)
    R(5, 19, 18, 20, (200, 150, 60, 255)); R(10, 19, 13, 20, accent)
    R(3, 13, 5, 21, dark); R(18, 13, 20, 21, dark); R(3, 21, 5, 22, skin); R(18, 21, 20, 22, skin)
    P([(8, 12), (15, 12), (14, 17), (9, 17)], accent)
    # head styles
    if head == "skull":
        E(7, 3, 16, 12, (230, 230, 214, 255)); R(8, 6, 10, 8, EYE); R(13, 6, 15, 8, EYE); R(11, 9, 12, 10, EYE)
        R(9, 11, 14, 11, (200, 200, 184, 255))
    elif head == "horse":
        E(6, 2, 17, 13, cloak); P([(9, 2), (11, 0), (12, 4)], hair); P([(14, 2), (13, 0), (12, 4)], hair)
        R(8, 5, 15, 12, skin); R(9, 10, 14, 12, shade(skin, 0.85)); R(10, 11, 10, 11, EYE); R(13, 11, 13, 11, EYE)
        d.point([(9 + ox, 7 + oy), (14 + ox, 7 + oy)], fill=EYE); R(8, 1, 15, 3, hair)
    else:
        if head == "hood":
            E(6, 2, 17, 13, cloak)
        elif head == "long":
            R(5, 4, 18, 18, hair); E(6, 2, 17, 12, hair)
        elif head == "wild":
            E(4, 1, 19, 12, hair); P([(5, 3), (3, 0), (8, 2)], hair); P([(18, 3), (20, 0), (15, 2)], hair)
        elif head == "helm":
            E(6, 2, 17, 13, (150, 156, 170, 255)); R(8, 7, 15, 8, (30, 30, 40, 255)); R(11, 2, 12, 6, accent)
        else:
            E(6, 3, 17, 13, hair)
        E(8, 4, 15, 12, skin) if head not in ("helm",) else R(8, 9, 15, 12, skin)
        if head in ("bare", "hood"): R(8, 4, 15, 6, hair)
        if head == "hat":
            P([(5, 6), (18, 6), (14, 4), (12, -1), (9, 4)], cloak); R(5, 5, 18, 6, accent)
        if head == "wild": R(8, 4, 15, 5, hair)
        if head == "long": R(8, 4, 15, 5, hair)
        if head != "helm":
            d.point([(10 + ox, 8 + oy), (13 + ox, 8 + oy)], fill=EYE)
        else:
            d.point([(10 + ox, 10 + oy), (13 + ox, 10 + oy)], fill=EYE)
        if extra == "beard": R(9, 10, 14, 13, (220, 220, 220, 255) if sum(hair[:3]) > 500 else hair)
        elif extra == "stubble": R(9, 11, 14, 11, shade(skin, 0.7))
        elif extra == "scar": d.line([(9 + ox, 5 + oy), (11 + ox, 9 + oy)], fill=(190, 80, 80, 255))
        elif extra == "mask": R(8, 7, 15, 9, (30, 30, 40, 255)); d.point([(10 + ox, 8 + oy), (13 + ox, 8 + oy)], fill=(240, 240, 240, 255))
        elif extra == "wrinkle": d.line([(9 + ox, 6 + oy), (14 + ox, 6 + oy)], fill=shade(skin, 0.75))
        elif extra == "scale": R(8, 4, 15, 5, (100, 180, 60, 255))
        elif extra == "wing": P([(4, 6), (0, 3), (2, 10)], (240, 240, 240, 255)); P([(19, 6), (23, 3), (21, 10)], (240, 240, 240, 255))
        d.line([(10 + ox, 10 + oy), (13 + ox, 10 + oy)], fill=MOUTH) if extra not in ("beard", "mask") and head != "helm" else None
    return img


def main() -> None:
    GRAPHICS.mkdir(parents=True, exist_ok=True)
    for i, spec in enumerate(CHARS):
        img = outline(portrait(spec)).resize((28 * 4, 34 * 4), Image.NEAREST)
        img.save(GRAPHICS / f"CHP{i:02d}.png", optimize=True)
    print(f"wrote {len(CHARS)} portraits")


if __name__ == "__main__":
    main()
