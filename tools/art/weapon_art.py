"""Generate weapon projectile / effect sprites (original pixel art).

16x16 art (20x20 for big ones) outlined and scaled 2x, centre origin, written
to src/resources/sprites/. Coloured sprites are used as-is; the white "W*"
shape sprites (WORB, WRNG, WBLT, WFLM, WJAV, WBUL, WSLS) are tinted per weapon
at runtime by SetShade. Presentation only.
Run: python tools/art/weapon_art.py
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pickup_art import OUTLINE, add_grab, outline  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SPRITES = ROOT / "src/resources/sprites"
W = (255, 255, 255, 255)
LIGHT = (225, 225, 235, 255)
MID = (170, 170, 190, 255)
GOLD = (250, 205, 60, 255)


def canvas(n: int = 16):
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def save(img: Image.Image, name: str, keep_outline: bool = True) -> None:
    if keep_outline:
        img = outline(img)
    img = img.resize((img.width * 2, img.height * 2), Image.NEAREST)
    path = SPRITES / f"{name}A0.png"
    img.save(path, optimize=True)
    add_grab(path, img.width // 2, img.height // 2)


def knife(name, blade, edge):
    img, d = canvas()
    d.polygon([(8, 0), (11, 9), (5, 9)], fill=blade)
    d.polygon([(8, 0), (11, 9), (8, 9)], fill=edge)
    d.rectangle([4, 9, 11, 10], fill=(150, 100, 60, 255))
    d.rectangle([7, 10, 8, 15], fill=(110, 70, 40, 255))
    save(img, name)


def axe():
    img, d = canvas()
    d.line([(4, 15), (11, 2)], fill=(150, 100, 60, 255), width=2)
    d.polygon([(6, 1), (14, 3), (14, 9), (9, 7), (8, 4)], fill=(200, 205, 220, 255))
    d.polygon([(9, 2), (14, 3), (14, 9)], fill=(240, 245, 255, 255))
    save(img, "WAXE")


def scythe():
    img, d = canvas()
    d.arc([1, 1, 14, 14], 200, 20, fill=(180, 60, 220, 255), width=3)
    d.arc([3, 3, 14, 14], 200, 20, fill=(240, 200, 255, 255), width=1)
    d.line([(2, 14), (8, 8)], fill=(110, 70, 40, 255), width=2)
    save(img, "WSCY")


def fireball(name, outer, inner):
    img, d = canvas()
    d.polygon([(2, 12), (8, 4), (5, 14)], fill=outer)
    d.ellipse([4, 3, 14, 13], fill=outer)
    d.ellipse([6, 5, 12, 11], fill=inner)
    d.point([(8, 7)], fill=W)
    save(img, name)


def cross(name, main, light):
    img, d = canvas()
    d.rectangle([6, 1, 9, 14], fill=main)
    d.rectangle([2, 5, 13, 8], fill=main)
    d.rectangle([7, 2, 7, 13], fill=light)
    d.rectangle([3, 6, 12, 6], fill=light)
    save(img, name)


def sword(name, blade, hilt):
    img, d = canvas()
    d.polygon([(8, 0), (10, 3), (10, 11), (6, 11), (6, 3)], fill=blade)
    d.rectangle([7, 1, 7, 10], fill=W)
    d.rectangle([3, 11, 12, 12], fill=hilt)
    d.rectangle([7, 12, 8, 15], fill=hilt)
    save(img, name)


def bolt_orb(name, main, glow):
    img, d = canvas()
    d.ellipse([2, 2, 13, 13], fill=glow)
    d.ellipse([4, 4, 11, 11], fill=main)
    d.ellipse([6, 6, 9, 9], fill=W)
    save(img, name)


def rune(name, main, dark):
    img, d = canvas()
    d.polygon([(8, 0), (14, 8), (8, 15), (2, 8)], fill=dark)
    d.polygon([(8, 2), (12, 8), (8, 13), (4, 8)], fill=main)
    d.line([(8, 4), (8, 11)], fill=W)
    d.line([(6, 7), (10, 7)], fill=W)
    save(img, name)


def bone():
    img, d = canvas()
    w = (245, 240, 220, 255)
    d.line([(4, 12), (12, 4)], fill=w, width=3)
    for p in ((3, 11), (5, 13), (11, 3), (13, 5)):
        d.ellipse([p[0] - 1, p[1] - 1, p[0] + 2, p[1] + 2], fill=w)
    save(img, "WBON")


def cherry():
    img, d = canvas()
    r = (225, 30, 60, 255)
    d.ellipse([1, 7, 7, 14], fill=r)
    d.ellipse([8, 8, 14, 15], fill=r)
    d.line([(4, 7), (9, 1)], fill=(60, 170, 60, 255))
    d.line([(11, 8), (9, 1)], fill=(60, 170, 60, 255))
    d.point([(3, 9), (10, 10)], fill=W)
    save(img, "WCHR")


def bird(name, body, wing):
    img, d = canvas()
    d.ellipse([4, 6, 11, 12], fill=body)
    d.polygon([(11, 7), (15, 8), (11, 10)], fill=GOLD)
    d.polygon([(3, 3), (9, 8), (4, 9)], fill=wing)
    d.polygon([(4, 10), (0, 13), (5, 12)], fill=wing)
    d.point([(10, 7)], fill=OUTLINE)
    save(img, name)


def cart():
    img, d = canvas()
    d.rectangle([2, 4, 13, 10], fill=(150, 100, 60, 255))
    d.rectangle([2, 4, 13, 5], fill=(200, 150, 90, 255))
    d.ellipse([3, 9, 7, 13], fill=(60, 60, 70, 255))
    d.ellipse([9, 9, 13, 13], fill=(60, 60, 70, 255))
    save(img, "WCAR")


def star(name, main, glow):
    img, d = canvas()
    d.polygon([(8, 0), (10, 6), (16, 8), (10, 10), (8, 16), (6, 10), (0, 8), (6, 6)], fill=glow)
    d.polygon([(8, 3), (9, 7), (13, 8), (9, 9), (8, 13), (7, 9), (3, 8), (7, 7)], fill=main)
    d.point([(8, 8)], fill=W)
    save(img, name)


def heart(name, main, light):
    img, d = canvas()
    d.ellipse([1, 2, 8, 9], fill=main)
    d.ellipse([7, 2, 14, 9], fill=main)
    d.polygon([(1, 6), (14, 6), (8, 14)], fill=main)
    d.ellipse([3, 4, 5, 6], fill=light)
    save(img, name)


def beam(name, core, glow, width):
    """Tall light column (Song of Mana / Mannajja), 2x scaled like the rest."""
    img = Image.new("RGBA", (width, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, width - 1, 47], fill=glow)
    d.rectangle([width // 4, 0, width - 1 - width // 4, 47], fill=core)
    d.line([(width // 2, 0), (width // 2, 47)], fill=W)
    save(img, name, keep_outline=False)


# ---- white shape sprites (tinted at runtime) -------------------------------

def orb():
    img, d = canvas()
    d.ellipse([1, 1, 14, 14], fill=MID)
    d.ellipse([3, 3, 12, 12], fill=LIGHT)
    d.ellipse([5, 5, 9, 9], fill=W)
    save(img, "WORB", keep_outline=False)


def cat():
    # A sitting cat silhouette (tinted at runtime): Gatti Amari's companions.
    img, d = canvas()
    d.ellipse([3, 7, 12, 15], fill=W)                       # body
    d.ellipse([4, 2, 11, 9], fill=W)                        # head
    d.polygon([(4, 4), (4, 0), (7, 3)], fill=W)             # ears
    d.polygon([(11, 4), (11, 0), (8, 3)], fill=W)
    d.line([(12, 13), (15, 10), (15, 7)], fill=LIGHT, width=2)   # tail
    d.point([(6, 5), (9, 5)], fill=MID)                     # eyes
    save(img, "WCAT", keep_outline=False)


def familiar():
    # A small winged imp: Pako Battiliar / Mazo Familiar's bursts.
    img, d = canvas()
    d.polygon([(1, 5), (6, 8), (6, 12), (2, 10)], fill=LIGHT)       # wings
    d.polygon([(14, 5), (9, 8), (9, 12), (13, 10)], fill=LIGHT)
    d.ellipse([4, 5, 11, 14], fill=W)                                # body
    d.polygon([(4, 6), (3, 2), (6, 5)], fill=W)                      # horns
    d.polygon([(11, 6), (12, 2), (9, 5)], fill=W)
    d.point([(6, 8), (9, 8)], fill=MID)
    save(img, "WFAM", keep_outline=False)


def laurel():
    # A wreath of leaves: Laurel / Crimson Shroud's shield.
    import math
    img, d = canvas()
    for i in range(12):
        a = i / 12 * 6.283
        cx = 8 + 5.5 * math.cos(a); cy = 8 + 5.5 * math.sin(a)
        d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=W if i % 2 == 0 else LIGHT)
    d.ellipse([4, 4, 11, 11], outline=MID)
    save(img, "WLRL", keep_outline=False)


def clock():
    # A clock face: Clock Lancet / Infinite Corridor.
    import math
    img, d = canvas()
    d.ellipse([0, 0, 15, 15], fill=MID)
    d.ellipse([2, 2, 13, 13], fill=LIGHT)
    for i in range(12):
        a = i / 12 * 6.283
        d.point((int(7.5 + 5 * math.cos(a)), int(7.5 + 5 * math.sin(a))), fill=MID)
    d.line([(8, 8), (8, 3)], fill=W)
    d.line([(8, 8), (11, 9)], fill=W)
    save(img, "WCLK", keep_outline=False)


def wings():
    # A pair of feathered wings: Shadow Pinion / Valkyrie Turner.
    img, d = canvas()
    d.polygon([(8, 9), (0, 3), (1, 8), (3, 10), (5, 12)], fill=W)
    d.polygon([(8, 9), (15, 3), (14, 8), (12, 10), (10, 12)], fill=W)
    d.line([(2, 4), (7, 9)], fill=MID)
    d.line([(13, 4), (8, 9)], fill=MID)
    d.ellipse([6, 7, 9, 12], fill=LIGHT)
    save(img, "WWNG", keep_outline=False)


def ring():
    img, d = canvas()
    d.ellipse([0, 0, 15, 15], outline=LIGHT, width=2)
    d.ellipse([3, 3, 12, 12], outline=MID, width=1)
    for a in range(0, 360, 60):
        x = 7.5 + 6.5 * math.cos(math.radians(a)); y = 7.5 + 6.5 * math.sin(math.radians(a))
        d.point((int(x), int(y)), fill=W)
    save(img, "WRNG", keep_outline=False)


def lightning():
    img, d = canvas()
    d.polygon([(9, 0), (3, 8), (7, 8), (5, 15), (13, 6), (8, 6)], fill=LIGHT)
    d.polygon([(9, 2), (6, 7), (8, 7)], fill=W)
    save(img, "WBLT", keep_outline=False)


def flame():
    img, d = canvas()
    d.polygon([(8, 0), (13, 7), (12, 13), (8, 15), (4, 13), (3, 7), (6, 4)], fill=MID)
    d.polygon([(8, 4), (11, 9), (8, 14), (5, 9)], fill=LIGHT)
    d.polygon([(8, 8), (9, 11), (7, 11)], fill=W)
    save(img, "WFLM", keep_outline=False)


def javelin():
    img, d = canvas()
    d.polygon([(8, 0), (10, 4), (9, 14), (7, 14), (6, 4)], fill=LIGHT)
    d.rectangle([7, 3, 8, 13], fill=W)
    d.polygon([(5, 14), (8, 11), (11, 14)], fill=MID)
    save(img, "WJAV", keep_outline=False)


def bullet():
    img, d = canvas()
    d.ellipse([5, 2, 10, 13], fill=LIGHT)
    d.ellipse([6, 3, 9, 8], fill=W)
    save(img, "WBUL", keep_outline=False)


def slash():
    img, d = canvas()
    d.arc([-4, 0, 15, 15], 280, 80, fill=LIGHT, width=3)
    d.arc([-2, 2, 15, 13], 290, 70, fill=W, width=1)
    save(img, "WSLS", keep_outline=False)


def tome(name, cover, trim):
    img, d = canvas()
    d.rectangle([2, 1, 13, 14], fill=cover)
    d.rectangle([2, 1, 4, 14], fill=trim)
    d.rectangle([12, 2, 13, 13], fill=(245, 240, 220, 255))
    d.rectangle([7, 4, 10, 11], outline=trim)
    d.line([(8, 5), (8, 10)], fill=trim)
    save(img, name)


def whip():
    # Wide crescent lying on the floor, opening toward the player (up = forward).
    img, d = canvas(32)
    d.arc([0, 2, 31, 60], 195, 345, fill=(255, 210, 80, 255), width=6)
    d.arc([3, 6, 28, 54], 200, 340, fill=(255, 245, 190, 255), width=3)
    d.arc([6, 9, 25, 48], 205, 335, fill=W, width=1)
    img = img.crop((0, 0, 32, 32))
    save(img, "WWHP", keep_outline=False)


def main() -> None:
    SPRITES.mkdir(parents=True, exist_ok=True)
    knife("WKNF", (215, 220, 235, 255), (250, 252, 255, 255))
    knife("WEDG", (250, 210, 90, 255), (255, 245, 190, 255))
    axe(); scythe()
    fireball("WFIR", (250, 120, 30, 255), (255, 220, 80, 255))
    fireball("WHFR", (170, 30, 40, 255), (255, 120, 60, 255))
    cross("WCRS", (240, 200, 60, 255), (255, 250, 200, 255))
    sword("WSWD", (150, 210, 255, 255), (250, 205, 60, 255))
    bolt_orb("WWND", (110, 230, 255, 255), (50, 130, 220, 255))
    bolt_orb("WHWN", (255, 250, 200, 255), (250, 200, 70, 255))
    rune("WRUN", (110, 200, 255, 255), (50, 90, 190, 255))
    rune("WNOF", (255, 110, 200, 255), (150, 40, 120, 255))
    bone(); cherry(); cart()
    bird("WBRD", (245, 245, 250, 255), (200, 210, 230, 255))
    bird("WBRK", (60, 50, 80, 255), (110, 90, 140, 255))
    bird("WBRW", (200, 190, 230, 255), (110, 90, 140, 255))
    tome("WBIB", (60, 90, 200, 255), GOLD)
    tome("WVES", (170, 30, 50, 255), (255, 220, 120, 255))
    star("WDST", (255, 240, 150, 255), (250, 170, 220, 255))
    heart("WPRF", (240, 70, 130, 255), (255, 200, 220, 255))
    rune("WROB", (255, 215, 90, 255), (190, 120, 40, 255))
    beam("WMNA", (200, 240, 255, 230), (90, 160, 255, 140), 8)
    beam("WMNJ", (255, 220, 255, 230), (200, 80, 255, 140), 12)
    cat(); familiar(); laurel(); clock(); wings(); orb(); ring(); lightning(); flame(); javelin(); bullet(); slash(); whip()
    print("wrote weapon sprites")


if __name__ == "__main__":
    main()
