"""Generate The Depths' spike sprite (original pixel art).

A cluster of iron spikes with bloody tips, 24x16 outlined and scaled 2x to
src/resources/sprites/DSPKA0.png with a bottom-centre origin. Presentation
only. Run: python tools/art/dungeon_art.py
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pickup_art import add_grab, outline  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SPRITES = ROOT / "src/resources/sprites"


def spikes() -> None:
    img = Image.new("RGBA", (24, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Back row darker, front row lighter; each spike a narrow triangle.
    for x, h, shade in ((3, 10, 92), (9, 12, 96), (15, 11, 92), (20, 9, 96),
                        (6, 13, 150), (12, 15, 160), (17, 12, 150)):
        base = 15
        d.polygon([(x - 2, base), (x + 2, base), (x, base - h)], fill=(shade, shade, shade + 14, 255))
        d.line([(x, base - h), (x + 1, base - 2)], fill=(min(255, shade + 70),) * 3 + (255,))
        d.point((x, base - h), fill=(170, 20, 20, 255))
        d.point((x, base - h + 1), fill=(120, 16, 16, 255))
    d.line([(0, 15), (23, 15)], fill=(50, 44, 40, 255))
    img = outline(img).resize((48, 32), Image.NEAREST)
    path = SPRITES / "DSPKA0.png"
    img.save(path, optimize=True)
    add_grab(path, 24, 32)


if __name__ == "__main__":
    spikes()
    print("wrote DSPKA0.png")
