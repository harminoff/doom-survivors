"""Generate the title-screen background (original pixel art, 320x200 x2).

Night sky with a moon, a castle silhouette, bats, gems and a forest floor,
plus a chunky DOOM SURVIVORS logo. Written to
src/resources/graphics/DSMENUBG.png (640x400). Presentation only.
Run: python tools/art/title_art.py
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "src/resources/graphics/DSMENUBG.png"
W, H = 320, 200
OUTLINE = (20, 10, 26, 255)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def sky(d):
    top, mid, low = (10, 8, 32), (48, 24, 80), (150, 60, 90)
    for y in range(140):
        t = y / 140
        c = lerp(top, mid, t / 0.6) if t < 0.6 else lerp(mid, low, (t - 0.6) / 0.4)
        d.line([(0, y), (W, y)], fill=c + (255,))
    # dithered bands
    for y in range(110, 140):
        for x in range((y % 2), W, 2):
            if random.random() < 0.3:
                d.point((x, y), fill=lerp(mid, low, (y - 110) / 30) + (255,))


def stars(d):
    for _ in range(90):
        x, y = random.randrange(W), random.randrange(90)
        b = random.choice((120, 170, 230))
        d.point((x, y), fill=(b, b, min(255, b + 20), 255))


def moon(d):
    cx, cy, r = 232, 46, 26
    for i in range(6, 0, -1):
        rr = r + i * 4
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=(70 + i * 6, 40 + i * 4, 110 + i * 5, 255))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(250, 235, 190, 255))
    for x, y, rr in ((-8, -6, 6), (7, 4, 8), (-2, 12, 4), (10, -12, 3)):
        d.ellipse([cx + x - rr, cy + y - rr, cx + x + rr, cy + y + rr], fill=(226, 208, 160, 255))


def hills(d):
    col = (26, 14, 44, 255)
    pts = [(0, 200)]
    for x in range(0, W + 1, 4):
        pts.append((x, 130 + 8 * math.sin(x / 30) + 5 * math.sin(x / 11 + 1)))
    pts.append((W, 200))
    d.polygon(pts, fill=col)


def castle(d):
    c = (14, 8, 26, 255)
    x0 = 60
    d.rectangle([x0, 92, x0 + 80, 138], fill=c)
    for tx, th in ((x0 - 6, 70), (x0 + 30, 58), (x0 + 60, 74), (x0 + 84, 84)):
        d.rectangle([tx, 138 - th, tx + 14, 138], fill=c)
        d.polygon([(tx - 2, 138 - th), (tx + 7, 138 - th - 16), (tx + 16, 138 - th)], fill=c)
    for bx in range(x0, x0 + 80, 8):
        d.rectangle([bx, 88, bx + 4, 92], fill=c)
    for wx, wy in ((x0 + 4, 108), (x0 + 36, 90), (x0 + 66, 102), (x0 + 30, 118), (x0 + 12, 124)):
        d.rectangle([wx, wy, wx + 2, wy + 4], fill=(255, 190, 70, 255))


def trees(d):
    for base, col in ((150, (16, 30, 40, 255)), (172, (10, 24, 30, 255))):
        x = -6
        while x < W + 6:
            h = random.randrange(26, 46)
            d.polygon([(x, base), (x + 9, base - h), (x + 18, base)], fill=col)
            d.polygon([(x + 3, base - h * 0.5), (x + 9, base - h - 4), (x + 15, base - h * 0.5)], fill=col)
            x += random.randrange(9, 15)
        d.rectangle([0, base - 2, W, 200], fill=col)


def ground(d):
    d.rectangle([0, 176, W, 200], fill=(20, 40, 30, 255))
    for _ in range(400):
        x, y = random.randrange(W), random.randrange(176, 200)
        d.point((x, y), fill=random.choice(((30, 62, 40, 255), (40, 80, 48, 255), (16, 30, 24, 255))))


def bat(d, x, y, s=1):
    c = (90, 50, 130, 255)
    d.ellipse([x - 3 * s, y - 2 * s, x + 3 * s, y + 3 * s], fill=c)
    d.polygon([(x - 3 * s, y), (x - 12 * s, y - 4 * s), (x - 9 * s, y + 2 * s), (x - 6 * s, y + 1 * s)], fill=c)
    d.polygon([(x + 3 * s, y), (x + 12 * s, y - 4 * s), (x + 9 * s, y + 2 * s), (x + 6 * s, y + 1 * s)], fill=c)
    d.point([(x - 1 * s, y - 1 * s), (x + 1 * s, y - 1 * s)], fill=(255, 60, 60, 255))


def gem(d, x, y):
    d.polygon([(x, y - 5), (x + 4, y), (x, y + 6), (x - 4, y)], fill=(70, 130, 250, 255))
    d.polygon([(x, y - 5), (x + 4, y), (x, y)], fill=(160, 200, 255, 255))


def outline_text(img, xy, text, font, fill, scale):
    tmp = Image.new("RGBA", (W, 60), (0, 0, 0, 0))
    td = ImageDraw.Draw(tmp)
    td.text((0, 0), text, font=font, fill=fill)
    bbox = tmp.getbbox()
    tmp = tmp.crop(bbox)
    tmp = tmp.resize((tmp.width * scale, tmp.height * scale), Image.NEAREST)
    x = xy[0] - tmp.width // 2
    y = xy[1]
    mask = tmp.split()[3]
    for dx in range(-1, 2):
        for dy in range(-1, 2):
            img.paste(OUTLINE, (x + dx, y + dy), mask)
    img.paste(OUTLINE, (x + 2, y + 3), mask)
    img.paste(tmp, (x, y), tmp)
    return tmp.height


def main() -> None:
    random.seed(7)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    d = ImageDraw.Draw(img)
    sky(d); stars(d); moon(d); hills(d); castle(d); trees(d); ground(d)
    for x, y, s in ((40, 30, 1), (120, 22, 1), (200, 84, 1), (270, 100, 1), (90, 60, 1), (20, 100, 2)):
        bat(d, x, y, s)
    for x, y in ((30, 186), (80, 192), (150, 184), (210, 190), (280, 186), (250, 194)):
        gem(d, x, y)
    try:
        font = ImageFont.truetype("arialbd.ttf", 22)
    except OSError:
        font = ImageFont.load_default()
    h1 = outline_text(img, (W // 2, 10), "DOOM", font, (220, 30, 40, 255), 2)
    outline_text(img, (W // 2, 10 + h1 + 4), "SURVIVORS", font, (250, 205, 60, 255), 1 if False else 2)
    img = img.resize((W * 2, H * 2), Image.NEAREST)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, optimize=True)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
