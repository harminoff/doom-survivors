"""Generate ground-decoration sprites for the non-forest stages (original pixel art).

Leafy and snowy trees, mushrooms, snowmen, ice, skulls and bones, crystals,
asteroids and planets, statues, columns, furniture, farm and dairy props,
candelabra, sea plants and lab glass. Same conventions as decor_art.py:
outlined, scaled 2x, bottom-centre origin. Presentation only.
Run: python tools/art/decor_art2.py
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from decor_art import save  # noqa: E402


def blank(w, h):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c[:3]) + (255,)


def leafy_tree(name, canopy, light, trunk=(84, 58, 40, 255), fruit=None, seed=0):
    r = random.Random(seed)
    img, d = blank(40, 52)
    d.rectangle([17, 30, 22, 51], fill=trunk)
    d.line([(19, 34), (19, 50)], fill=shade(trunk, 1.4))
    for _ in range(14):
        x = r.randint(8, 31); y = r.randint(8, 30); rad = r.randint(5, 9)
        d.ellipse([x - rad, y - rad, x + rad, y + rad], fill=canopy)
    for _ in range(18):
        d.point((r.randint(6, 33), r.randint(4, 30)), fill=light)
    if fruit:
        for _ in range(8):
            x = r.randint(9, 30); y = r.randint(9, 28)
            d.ellipse([x, y, x + 2, y + 2], fill=fruit)
    save(img, name)


def pine(name, snow=False):
    img, d = blank(32, 54)
    d.rectangle([14, 44, 17, 53], fill=(70, 50, 36, 255))
    for w, y in ((13, 38), (11, 28), (9, 18), (6, 9)):
        d.polygon([(16 - w, y + 9), (16, y - 7), (16 + w, y + 9)], fill=(34, 86, 50, 255))
        if snow:
            d.polygon([(16 - w + 2, y + 5), (16, y - 7), (16 + w - 2, y + 5)], fill=(236, 244, 255, 255))
    save(img, name)


def mushroom(name, cap):
    img, d = blank(16, 16)
    d.rectangle([6, 8, 9, 15], fill=(236, 226, 206, 255))
    d.ellipse([1, 2, 14, 11], fill=cap)
    d.point([(4, 5), (9, 4), (11, 7), (6, 7)], fill=(250, 250, 240, 255))
    save(img, name)


def snowman(name):
    img, d = blank(20, 32)
    d.ellipse([3, 15, 16, 30], fill=(240, 246, 255, 255))
    d.ellipse([5, 4, 14, 14], fill=(240, 246, 255, 255))
    d.rectangle([4, 3, 15, 4], fill=(50, 50, 70, 255))
    d.rectangle([6, 0, 13, 3], fill=(50, 50, 70, 255))
    d.point([(7, 8), (11, 8)], fill=(30, 30, 40, 255))
    d.polygon([(9, 10), (14, 11), (9, 12)], fill=(240, 130, 50, 255))
    d.point([(9, 18), (9, 22), (9, 26)], fill=(50, 50, 60, 255))
    save(img, name)


def ice(name):
    img, d = blank(24, 26)
    for x0, top in ((4, 8), (10, 2), (16, 10)):
        d.polygon([(x0, 25), (x0 + 3, top), (x0 + 7, 25)], fill=(170, 214, 250, 255))
        d.polygon([(x0 + 3, top), (x0 + 7, 25), (x0 + 3, 25)], fill=(120, 176, 230, 255))
    save(img, name)


def skull(name):
    img, d = blank(18, 16)
    w = (234, 228, 210, 255)
    d.ellipse([3, 1, 14, 11], fill=w)
    d.rectangle([6, 9, 11, 14], fill=w)
    d.rectangle([5, 5, 7, 7], fill=(40, 30, 34, 255))
    d.rectangle([10, 5, 12, 7], fill=(40, 30, 34, 255))
    save(img, name)


def bones(name, seed):
    r = random.Random(seed)
    img, d = blank(26, 12)
    w = (232, 226, 206, 255)
    for _ in range(4):
        x = r.randint(3, 20); y = r.randint(3, 9)
        d.line([(x, y), (x + r.randint(3, 6), y + r.randint(-2, 2))], fill=w, width=2)
        d.ellipse([x - 1, y - 1, x + 1, y + 1], fill=w)
    save(img, name)


def crystal(name, main, light):
    img, d = blank(22, 30)
    d.polygon([(11, 0), (18, 10), (15, 29), (7, 29), (4, 10)], fill=main)
    d.polygon([(11, 0), (18, 10), (11, 12)], fill=light)
    d.polygon([(4, 10), (11, 12), (7, 29)], fill=shade(main, 0.6))
    save(img, name)


def asteroid(name, seed):
    r = random.Random(seed)
    img, d = blank(28, 22)
    pts = [(14 + 12 * math.cos(math.radians(a)), 11 + 9 * math.sin(math.radians(a)) + r.randint(-2, 2)) for a in range(0, 360, 40)]
    d.polygon(pts, fill=(96, 90, 106, 255))
    d.polygon(pts[:4] + [(14, 11)], fill=(130, 124, 140, 255))
    d.ellipse([16, 12, 20, 16], fill=(70, 66, 80, 255))
    save(img, name)


def planet(name, main, ring):
    img, d = blank(40, 28)
    d.ellipse([10, 2, 30, 22], fill=main)
    d.ellipse([10, 2, 22, 14], fill=shade(main, 1.25))
    d.arc([0, 9, 39, 25], 200, 340, fill=ring, width=2)
    d.arc([0, 9, 39, 25], 20, 160, fill=ring, width=2)
    save(img, name)


def statue(name):
    img, d = blank(20, 40)
    g = (150, 152, 162, 255); dk = (104, 106, 118, 255)
    d.rectangle([3, 34, 16, 39], fill=dk)
    d.rectangle([5, 14, 14, 34], fill=g)
    d.ellipse([6, 3, 13, 12], fill=g)
    d.rectangle([2, 15, 5, 26], fill=g)
    d.rectangle([14, 15, 17, 26], fill=g)
    d.line([(17, 8), (17, 30)], fill=(190, 190, 200, 255))
    d.rectangle([9, 14, 10, 34], fill=dk)
    save(img, name)


def column(name):
    img, d = blank(18, 40)
    g = (176, 172, 168, 255)
    d.rectangle([2, 34, 15, 39], fill=(130, 126, 124, 255))
    d.rectangle([4, 6, 13, 34], fill=g)
    d.rectangle([9, 6, 13, 34], fill=(140, 136, 132, 255))
    d.rectangle([2, 2, 15, 6], fill=(130, 126, 124, 255))
    save(img, name)


def piano(name):
    img, d = blank(40, 26)
    d.rectangle([2, 6, 37, 22], fill=(34, 28, 40, 255))
    d.rectangle([2, 4, 37, 8], fill=(60, 52, 70, 255))
    for x in range(4, 36, 3):
        d.rectangle([x, 14, x + 1, 20], fill=(238, 236, 228, 255))
    d.rectangle([4, 22, 6, 25], fill=(24, 20, 28, 255))
    d.rectangle([33, 22, 35, 25], fill=(24, 20, 28, 255))
    save(img, name)


def table(name, cloth):
    img, d = blank(28, 20)
    d.ellipse([2, 4, 25, 14], fill=cloth)
    d.rectangle([12, 12, 15, 19], fill=(90, 64, 44, 255))
    d.ellipse([10, 5, 15, 9], fill=(250, 226, 130, 255))
    save(img, name)


def bookstack(name):
    img, d = blank(20, 14)
    cols = [(150, 40, 40, 255), (40, 90, 150, 255), (40, 120, 70, 255), (170, 140, 50, 255)]
    for i, c in enumerate(cols):
        d.rectangle([2 + (i % 2) * 2, 11 - i * 3, 16 + (i % 2) * 2, 13 - i * 3], fill=c)
    save(img, name)


def chicken(name):
    img, d = blank(20, 18)
    d.ellipse([3, 6, 15, 16], fill=(246, 244, 236, 255))
    d.ellipse([11, 2, 17, 8], fill=(246, 244, 236, 255))
    d.point([(15, 4)], fill=(30, 30, 30, 255))
    d.polygon([(17, 4), (19, 5), (17, 6)], fill=(240, 170, 40, 255))
    d.rectangle([12, 0, 14, 3], fill=(216, 50, 50, 255))
    d.line([(7, 16), (7, 17)], fill=(240, 170, 40, 255))
    d.line([(11, 16), (11, 17)], fill=(240, 170, 40, 255))
    save(img, name)


def hay(name):
    img, d = blank(26, 20)
    d.ellipse([1, 2, 24, 18], fill=(222, 190, 92, 255))
    d.ellipse([4, 5, 21, 15], fill=(240, 212, 120, 255))
    d.line([(3, 10), (22, 10)], fill=(168, 134, 60, 255))
    save(img, name)


def fence(name):
    img, d = blank(30, 18)
    for x in (2, 14, 26):
        d.rectangle([x, 2, x + 2, 17], fill=(136, 100, 62, 255))
    d.rectangle([0, 5, 29, 7], fill=(164, 124, 78, 255))
    d.rectangle([0, 11, 29, 13], fill=(164, 124, 78, 255))
    save(img, name)


def milk_can(name):
    img, d = blank(14, 20)
    d.rectangle([2, 6, 11, 19], fill=(206, 210, 218, 255))
    d.rectangle([2, 6, 5, 19], fill=(240, 244, 250, 255))
    d.rectangle([3, 2, 10, 6], fill=(170, 176, 188, 255))
    d.rectangle([2, 10, 11, 11], fill=(180, 60, 60, 255))
    save(img, name)


def lamp(name):
    img, d = blank(14, 44)
    d.rectangle([6, 6, 7, 43], fill=(90, 92, 100, 255))
    d.rectangle([3, 42, 10, 43], fill=(70, 72, 80, 255))
    d.rectangle([2, 0, 11, 7], fill=(255, 226, 140, 255))
    d.rectangle([4, 2, 9, 5], fill=(255, 252, 214, 255))
    save(img, name)


def candelabra(name):
    img, d = blank(22, 42)
    g = (200, 170, 70, 255)
    d.rectangle([10, 14, 11, 40], fill=g)
    d.rectangle([6, 39, 15, 41], fill=g)
    d.line([(3, 12), (10, 18), (18, 12)], fill=g, width=1)
    for x in (2, 10, 18):
        d.rectangle([x, 8, x + 1, 13], fill=(240, 236, 220, 255))
        d.polygon([(x + 1, 2), (x + 2, 8), (x - 1, 8)], fill=(255, 190, 70, 255))
    save(img, name)


def seaweed(name, col):
    img, d = blank(18, 30)
    for x0 in (4, 9, 14):
        for y in range(29, 4, -3):
            x = x0 + (2 if (y // 3) % 2 else -2)
            d.rectangle([x, y, x + 1, y + 2], fill=col)
    save(img, name)


def urn(name):
    img, d = blank(16, 24)
    d.ellipse([2, 6, 13, 22], fill=(74, 130, 136, 255))
    d.rectangle([5, 2, 10, 7], fill=(60, 110, 116, 255))
    d.rectangle([3, 12, 12, 13], fill=(200, 210, 210, 255))
    save(img, name)


def beaker(name, col):
    img, d = blank(14, 20)
    d.rectangle([4, 2, 9, 7], fill=(200, 226, 236, 255))
    d.polygon([(4, 7), (9, 7), (13, 19), (0, 19)], fill=(200, 226, 236, 255))
    d.polygon([(3, 12), (10, 12), (13, 19), (0, 19)], fill=col)
    save(img, name)


def shrub_dark(name, seed):
    r = random.Random(seed)
    img, d = blank(30, 22)
    for _ in range(9):
        x = r.randint(5, 24); y = r.randint(8, 16); rad = r.randint(4, 7)
        d.ellipse([x - rad, y - rad, x + rad, y + rad], fill=r.choice(((30, 60, 52, 255), (38, 76, 64, 255), (24, 50, 46, 255))))
    save(img, name)


def door(name):
    img, d = blank(26, 40)
    d.rectangle([2, 4, 23, 39], fill=(58, 38, 28, 255))
    d.rectangle([5, 7, 20, 39], fill=(92, 62, 42, 255))
    d.rectangle([5, 7, 12, 39], fill=(110, 76, 52, 255))
    d.arc([2, 0, 23, 14], 180, 360, fill=(58, 38, 28, 255), width=4)
    d.ellipse([16, 22, 18, 24], fill=(220, 190, 90, 255))
    d.line([(12, 8), (12, 38)], fill=(60, 40, 28, 255))
    save(img, name)


def merchant(name):
    img, d = blank(24, 40)
    d.polygon([(4, 39), (6, 14), (18, 14), (20, 39)], fill=(120, 50, 130, 255))
    d.polygon([(12, 14), (18, 14), (20, 39), (12, 39)], fill=(90, 36, 100, 255))
    d.ellipse([6, 2, 17, 15], fill=(120, 50, 130, 255))
    d.ellipse([8, 6, 15, 13], fill=(240, 200, 160, 255))
    d.point([(10, 9), (13, 9)], fill=(30, 20, 30, 255))
    d.rectangle([2, 22, 21, 24], fill=(220, 180, 70, 255))
    save(img, name)


def window(name):
    img, d = blank(24, 36)
    d.rectangle([2, 4, 21, 35], fill=(60, 60, 76, 255))
    d.ellipse([2, 0, 21, 14], fill=(60, 60, 76, 255))
    cols = [(220, 60, 70, 255), (70, 120, 230, 255), (240, 200, 70, 255), (80, 200, 120, 255)]
    for i, y in enumerate(range(6, 33, 7)):
        d.rectangle([5, y, 11, y + 5], fill=cols[i % 4])
        d.rectangle([12, y, 18, y + 5], fill=cols[(i + 1) % 4])
    d.rectangle([11, 4, 12, 35], fill=(210, 210, 224, 255))
    d.rectangle([5, 14, 18, 15], fill=(210, 210, 224, 255))
    save(img, name)


def cart(name):
    img, d = blank(34, 24)
    d.polygon([(2, 6), (31, 6), (28, 18), (5, 18)], fill=(206, 210, 218, 255))
    d.polygon([(2, 6), (31, 6), (30, 9), (3, 9)], fill=(240, 244, 250, 255))
    d.rectangle([4, 11, 29, 12], fill=(190, 60, 60, 255))
    d.ellipse([5, 17, 12, 23], fill=(60, 60, 70, 255))
    d.ellipse([21, 17, 28, 23], fill=(60, 60, 70, 255))
    save(img, name)


def coffin(name):
    img, d = blank(22, 40)
    d.polygon([(6, 2), (15, 2), (19, 12), (17, 38), (4, 38), (2, 12)], fill=(74, 50, 38, 255))
    d.polygon([(10, 2), (15, 2), (19, 12), (17, 38), (10, 38)], fill=(56, 38, 28, 255))
    d.line([(10, 8), (10, 30)], fill=(200, 170, 80, 255))
    d.line([(6, 15), (14, 15)], fill=(200, 170, 80, 255))
    save(img, name)


def main():
    leafy_tree("DTLA", (42, 120, 52, 255), (96, 168, 84, 255), seed=11)
    leafy_tree("DTLB", (52, 140, 60, 255), (120, 190, 96, 255), seed=12)
    leafy_tree("DTFR", (46, 124, 54, 255), (98, 170, 86, 255), fruit=(240, 140, 40, 255), seed=13)
    leafy_tree("DTDK", (24, 62, 54, 255), (52, 100, 82, 255), trunk=(52, 40, 36, 255), seed=14)
    pine("DPNE")
    pine("DPNS", snow=True)
    mushroom("DMSH", (214, 60, 60, 255))
    mushroom("DMSI", (232, 160, 60, 255))
    snowman("DSNW")
    ice("DICE")
    skull("DSKL")
    bones("DBNE", 1)
    bones("DBNF", 2)
    crystal("DCRY", (70, 140, 250, 255), (170, 210, 255, 255))
    crystal("DCRZ", (200, 90, 240, 255), (240, 190, 255, 255))
    asteroid("DAST", 1)
    asteroid("DASU", 2)
    planet("DPLN", (150, 90, 210, 255), (230, 200, 120, 255))
    planet("DPLO", (70, 170, 190, 255), (220, 220, 240, 255))
    statue("DSTA")
    column("DCOL")
    piano("DPNO")
    table("DTBL", (150, 40, 50, 255))
    table("DTBM", (230, 226, 212, 255))
    bookstack("DBKS")
    chicken("DCHK")
    hay("DHAY")
    fence("DFNC")
    milk_can("DMLK")
    lamp("DLMP")
    candelabra("DCND")
    seaweed("DSWD", (52, 150, 120, 255))
    urn("DURN")
    beaker("DBKR", (90, 220, 120, 255))
    shrub_dark("DSHD", 21)
    shrub_dark("DSHE", 22)
    coffin("DCFN")
    door("DDOR")
    merchant("DMRC")
    window("DWND")
    cart("DCRT")
    print("wrote extra decor sprites")


if __name__ == "__main__":
    main()
