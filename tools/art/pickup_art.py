"""Generate pickup, chest and light-source sprites (original pixel art).

Drawn small, outlined, and scaled 2x with nearest-neighbour sampling, like
tools/art/enemy_art.py. Outputs PNGs to src/resources/sprites/ with a
bottom-centre origin. Presentation only.
Run: python tools/art/pickup_art.py
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SPRITES = ROOT / "src/resources/sprites"
OUTLINE = (24, 14, 30, 255)


def outline(img: Image.Image) -> Image.Image:
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


def add_grab(path: Path, gx: int, gy: int) -> None:
    import struct
    import zlib
    data = path.read_bytes()
    if b"grAb" in data:
        return
    payload = struct.pack(">ii", gx, gy)
    chunk = struct.pack(">I", len(payload)) + b"grAb" + payload
    chunk += struct.pack(">I", zlib.crc32(b"grAb" + payload) & 0xFFFFFFFF)
    path.write_bytes(data[:33] + chunk + data[33:])


def save(img: Image.Image, name: str) -> None:
    img = outline(img)
    img = img.resize((img.width * 2, img.height * 2), Image.NEAREST)
    path = SPRITES / f"{name}.png"
    img.save(path, optimize=True)
    add_grab(path, img.width // 2, img.height)


def canvas(w: int, h: int):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def gem(name: str, main, light, dark) -> None:
    for frame in (0, 1):
        img, d = canvas(12, 16)
        d.polygon([(6, 1), (11, 7), (6, 15), (1, 7)], fill=main)
        d.polygon([(6, 1), (11, 7), (6, 8)], fill=light)
        d.polygon([(1, 7), (6, 15), (6, 8)], fill=dark)
        if frame:
            d.point([(4, 4), (5, 3), (3, 5)], fill=(255, 255, 255, 255))
        else:
            d.point([(4, 5)], fill=(255, 255, 255, 255))
        save(img, f"{name}{'AB'[frame]}0")


def coin() -> None:
    for frame in (0, 1):
        img, d = canvas(12, 12)
        w = 5 if frame == 0 else 2
        d.ellipse([6 - w, 1, 6 + w, 11], fill=(250, 205, 50, 255))
        if w > 3:
            d.ellipse([6 - w + 2, 3, 6 + w - 2, 9], outline=(200, 140, 30, 255))
            d.point([(4, 3)], fill=(255, 250, 200, 255))
        save(img, f"ICOI{'AB'[frame]}0")


def bag(name: str, colour, coins) -> None:
    img, d = canvas(16, 16)
    d.ellipse([2, 5, 14, 15], fill=colour)
    d.polygon([(5, 6), (8, 2), (11, 6)], fill=colour)
    d.rectangle([5, 5, 11, 6], fill=(120, 70, 30, 255))
    for x, y in coins:
        d.ellipse([x, y, x + 3, y + 3], fill=(250, 210, 60, 255))
    save(img, f"{name}A0")


def chicken() -> None:
    img, d = canvas(20, 14)
    d.ellipse([2, 3, 15, 13], fill=(200, 110, 50, 255))
    d.ellipse([4, 4, 10, 8], fill=(240, 160, 80, 255))
    d.line([(14, 6), (18, 3)], fill=(245, 240, 225, 255), width=2)
    d.ellipse([16, 1, 19, 4], fill=(245, 240, 225, 255))
    save(img, "ICHKA0")


def rosary() -> None:
    img, d = canvas(14, 18)
    for i in range(10):
        import math
        a = i / 10 * 6.283
        x = 7 + int(5 * math.cos(a)); y = 6 + int(5 * math.sin(a))
        d.point((x, y), fill=(200, 200, 230, 255))
    d.rectangle([6, 9, 7, 17], fill=(240, 240, 250, 255))
    d.rectangle([4, 11, 9, 12], fill=(240, 240, 250, 255))
    save(img, "IROSA0")


def orologion() -> None:
    img, d = canvas(16, 16)
    d.ellipse([1, 2, 15, 15], fill=(120, 200, 250, 255))
    d.ellipse([3, 4, 13, 13], fill=(235, 245, 255, 255))
    d.line([(8, 8), (8, 5)], fill=(40, 40, 70, 255))
    d.line([(8, 8), (11, 9)], fill=(40, 40, 70, 255))
    d.rectangle([7, 0, 9, 2], fill=(250, 210, 60, 255))
    save(img, "IOROA0")


def vacuum() -> None:
    img, d = canvas(16, 16)
    d.arc([1, 1, 15, 15], 180, 360, fill=(230, 60, 60, 255), width=4)
    d.rectangle([1, 8, 4, 14], fill=(230, 60, 60, 255))
    d.rectangle([12, 8, 15, 14], fill=(230, 60, 60, 255))
    d.rectangle([1, 12, 4, 14], fill=(220, 225, 235, 255))
    d.rectangle([12, 12, 15, 14], fill=(220, 225, 235, 255))
    save(img, "IVACA0")


def clover(name: str, leaf, light, leaves: int) -> None:
    img, d = canvas(16, 16)
    spots = [(8, 4), (4, 8), (12, 8)] if leaves == 3 else [(8, 4), (4, 8), (12, 8), (8, 12)]
    for cx, cy in spots:
        d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=leaf)
        d.point([(cx - 1, cy - 1)], fill=light)
    d.line([(8, 9), (8, 15)], fill=leaf, width=1)
    save(img, name)


def nduja() -> None:
    img, d = canvas(18, 16)
    d.rounded_rectangle([1, 6, 16, 13], radius=3, fill=(190, 40, 30, 255))
    d.line([(3, 8), (14, 8)], fill=(235, 100, 70, 255))
    d.polygon([(4, 6), (8, 0), (12, 6)], fill=(250, 140, 30, 255))
    d.polygon([(6, 6), (8, 3), (10, 6)], fill=(255, 225, 90, 255))
    save(img, "INDJA0")


def rerollo() -> None:
    img, d = canvas(16, 16)
    d.rounded_rectangle([1, 1, 14, 14], radius=3, fill=(90, 210, 245, 255))
    for px, py in ((4, 4), (11, 4), (8, 8), (4, 11), (11, 11)):
        d.rectangle([px - 1, py - 1, px, py], fill=(20, 60, 90, 255))
    save(img, "IRRLA0")


def sorbetto() -> None:
    img, d = canvas(14, 20)
    d.polygon([(2, 8), (12, 8), (7, 19)], fill=(225, 175, 105, 255))
    d.line([(4, 10), (9, 10)], fill=(190, 140, 80, 255))
    d.ellipse([1, 1, 12, 10], fill=(170, 225, 255, 255))
    d.ellipse([3, 2, 7, 5], fill=(240, 250, 255, 255))
    save(img, "ISRBA0")


def chest(name: str, body, trim, gem_colour) -> None:
    for frame in (0, 1):
        img, d = canvas(24, 20)
        d.rectangle([2, 8, 21, 19], fill=body)
        d.ellipse([2, 1, 21, 9], fill=body)
        d.rectangle([2, 5, 21, 9], fill=body)
        d.rectangle([2, 8, 21, 9], fill=trim)
        d.rectangle([10, 1, 13, 19], fill=trim)
        d.rectangle([9, 9, 14, 13], fill=gem_colour if frame else trim)
        d.point([(4, 4), (5, 3)], fill=(255, 255, 255, 180))
        save(img, f"{name}{'AB'[frame]}0")


def brazier() -> None:
    for frame in (0, 1):
        img, d = canvas(16, 28)
        d.rectangle([7, 14, 8, 27], fill=(110, 80, 50, 255))
        d.rectangle([4, 25, 11, 27], fill=(110, 80, 50, 255))
        d.polygon([(2, 11), (13, 11), (11, 15), (4, 15)], fill=(150, 120, 90, 255))
        s = 1 if frame else 0
        d.polygon([(3, 11), (8 - s, 1 + s), (12, 11)], fill=(250, 140, 30, 255))
        d.polygon([(5, 11), (8 + s, 4 - s), (10, 11)], fill=(255, 225, 90, 255))
        save(img, f"LSRC{'AB'[frame]}0")


def main() -> None:
    SPRITES.mkdir(parents=True, exist_ok=True)
    gem("GEMB", (70, 130, 250, 255), (160, 200, 255, 255), (40, 70, 170, 255))
    gem("GEMG", (60, 200, 90, 255), (160, 250, 170, 255), (30, 120, 50, 255))
    gem("GEMR", (230, 50, 60, 255), (255, 150, 150, 255), (140, 20, 30, 255))
    coin()
    bag("IBAG", (170, 110, 60, 255), [(6, 9)])
    bag("IRIC", (200, 60, 70, 255), [(4, 9), (8, 8), (7, 11)])
    chicken(); rosary(); orologion(); vacuum()
    clover("ICLVA0", (70, 190, 90, 255), (170, 245, 170, 255), 3)
    clover("IGLCA0", (235, 190, 50, 255), (255, 240, 150, 255), 4)
    nduja(); rerollo(); sorbetto()
    chest("CHST", (170, 100, 40, 255), (250, 205, 60, 255), (90, 220, 250, 255))
    chest("CHSR", (90, 40, 130, 255), (220, 180, 250, 255), (250, 90, 200, 255))
    brazier()
    print("wrote pickup sprites")


if __name__ == "__main__":
    main()
