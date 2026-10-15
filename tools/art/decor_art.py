"""Generate ground-decoration sprites for the stage maps (original pixel art).

Dead trees, bushes, rocks, flower tufts and gravestones: non-solid props
scattered on the open stages. Outlined, scaled 2x, bottom-centre origin.
Presentation only.
Run: python tools/art/decor_art.py
"""
from __future__ import annotations

import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pickup_art import add_grab, outline  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SPRITES = ROOT / "src/resources/sprites"
BARK = (58, 44, 36, 255)
BARK_L = (92, 72, 56, 255)


# Small floor props that could pass for pickups at a glance get a
# "background" grade (desaturated and darker), so the bright, bobbing,
# ringed pickups stand apart from them on every stage.
SMALL_PROPS = {"DRCK", "DRCL", "DSKL", "DBNE", "DBNF", "DBKS", "DMLK", "DURN", "DBKR"}


def background_grade(img):
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            grey = 0.3 * r + 0.59 * g + 0.11 * b
            px[x, y] = tuple(int((c * 0.55 + grey * 0.45) * 0.75) for c in (r, g, b)) + (a,)
    return out


def save(img, name):
    if name in SMALL_PROPS:
        img = background_grade(img)
    img = outline(img)
    img = img.resize((img.width * 2, img.height * 2), Image.NEAREST)
    path = SPRITES / f"{name}A0.png"
    img.save(path, optimize=True)
    add_grab(path, img.width // 2, img.height)


def branch(d, x0, y0, x1, y1, w=1):
    d.line([(x0, y0), (x1, y1)], fill=BARK, width=w)


def dead_tree(name, seed, h=44):
    r = random.Random(seed)
    img = Image.new("RGBA", (36, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = 18
    d.polygon([(cx - 3, h - 1), (cx + 3, h - 1), (cx + 2, h * 0.45), (cx - 2, h * 0.45)], fill=BARK)
    d.line([(cx - 1, h - 2), (cx - 1, h * 0.5)], fill=BARK_L)
    # roots
    d.line([(cx - 3, h - 1), (cx - 7, h - 1)], fill=BARK, width=1)
    d.line([(cx + 3, h - 1), (cx + 7, h - 1)], fill=BARK, width=1)
    for k in range(5):
        y = h * (0.45 - 0.07 * k)
        side = -1 if (k + seed) % 2 else 1
        length = r.randint(6, 12)
        branch(d, cx, y + 3, cx + side * length, y - r.randint(3, 8), 2 if k < 2 else 1)
        d.line([(cx + side * length, y - 5), (cx + side * (length + 3), y - 9)], fill=BARK)
    branch(d, cx, h * 0.45, cx + r.randint(-3, 3), 2, 2)
    save(img, name)


def bush(name, seed):
    r = random.Random(seed)
    img = Image.new("RGBA", (28, 18), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for _ in range(9):
        x = r.randint(4, 22); y = r.randint(6, 13); rad = r.randint(3, 6)
        g = r.choice(((34, 78, 44, 255), (42, 92, 50, 255), (28, 64, 38, 255)))
        d.ellipse([x - rad, y - rad, x + rad, y + rad], fill=g)
    for _ in range(14):
        d.point((r.randint(4, 23), r.randint(3, 15)), fill=(80, 140, 84, 255))
    save(img, name)


def rock(name, seed):
    r = random.Random(seed)
    img = Image.new("RGBA", (22, 14), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(2, 13), (4, 6), (10, 2), (17, 5), (20, 13)], fill=(96, 98, 106, 255))
    d.polygon([(10, 2), (17, 5), (20, 13), (12, 13)], fill=(70, 72, 80, 255))
    d.line([(5, 6), (10, 3)], fill=(140, 142, 150, 255))
    d.point([(r.randint(6, 14), r.randint(6, 11))], fill=(58, 96, 60, 255))
    save(img, name)


def flowers(name, colours, seed):
    r = random.Random(seed)
    img = Image.new("RGBA", (24, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for _ in range(7):
        x = r.randint(2, 21); y = r.randint(4, 10)
        d.line([(x, y), (x, y + 2)], fill=(40, 100, 50, 255))
        d.point([(x, y - 1), (x - 1, y), (x + 1, y)], fill=r.choice(colours))
        d.point([(x, y)], fill=(250, 230, 120, 255))
    save(img, name)


def gravestone(name, seed):
    img = Image.new("RGBA", (16, 22), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([2, 6, 13, 21], fill=(112, 114, 122, 255))
    d.ellipse([2, 1, 13, 11], fill=(112, 114, 122, 255))
    d.rectangle([9, 6, 13, 21], fill=(84, 86, 96, 255))
    d.line([(7, 7), (7, 14)], fill=(60, 60, 70, 255))
    d.line([(5, 10), (10, 10)], fill=(60, 60, 70, 255))
    d.point([(4, 16), (5, 17)], fill=(58, 96, 60, 255))
    save(img, name)


def main():
    SPRITES.mkdir(parents=True, exist_ok=True)
    dead_tree("DTRE", 1, 44); dead_tree("DTRF", 2, 36); dead_tree("DTRG", 3, 52)
    bush("DBSH", 4); bush("DBSI", 5)
    rock("DRCK", 6); rock("DRCL", 7)
    flowers("DFLW", [(230, 90, 120, 255), (240, 240, 250, 255)], 8)
    flowers("DFLX", [(120, 150, 240, 255), (250, 200, 80, 255)], 9)
    gravestone("DGRV", 10)
    print("wrote decor sprites")


if __name__ == "__main__":
    main()
