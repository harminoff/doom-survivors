"""Generate a preview picture per stage for the stage select screen (original pixel art).

48x32 scenes (sky, ground, a motif) scaled 2x to graphics/STG00.png ... in stage-index
order (the STAGES list in tools/gen_stages.py). Presentation only.
Run: python tools/art/stage_art.py
"""
from __future__ import annotations

import random
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
GRAPHICS = ROOT / "src/resources/graphics"
W, H = 48, 32
HORIZON = 20


def rgb(h: int):
    return ((h >> 16) & 255, (h >> 8) & 255, h & 255, 255)


# slug order = STAGES order: sky top, sky bottom, ground, motif, detail colour
SCENES = [
    (0x1C2848, 0x3C5A70, 0x2E6A2E, "trees", 0x1A3A1A),       # Mad Forest
    (0x2A1C14, 0x5A4030, 0x4A3020, "shelves", 0x8A5A30),      # Inlaid Library
    (0x6AA8D8, 0xB8D8F0, 0x6AA030, "barn", 0xB03030),         # Dairy Plant
    (0x181830, 0x3A3A68, 0x5A5A70, "tower", 0x8888A8),        # Gallo Tower
    (0x2A1A40, 0x6A4A80, 0x4A4A5A, "church", 0x9A8AB0),       # Cappella Magna
    (0x70B0E0, 0xC0E0F0, 0x3A9A3A, "trees", 0x2A7A2A),        # Green Acres
    (0x201010, 0x501818, 0x3A2A2A, "bones", 0xE0E0D0),        # Bone Zone
    (0x4A5A7A, 0x8AA0B8, 0x6A7A5A, "still", 0x4A5A3A),        # Il Molise
    (0x080818, 0x202850, 0x1A3A5A, "moon", 0xE8E8C0),         # Moongolow
    (0x301010, 0x703020, 0x3A2020, "bones", 0xE04040),        # Boss Rash
    (0x90B0D0, 0xE8F0F8, 0xE8F0F8, "snow", 0xB0C8E0),         # Whiteout
    (0x101820, 0x284050, 0x203038, "shelves", 0x60A0B0),      # Lycaeum
    (0x78B0E0, 0xD0E8F0, 0xC8B060, "barn", 0x906030),         # The Coop
    (0x000010, 0x181048, 0x2A2A50, "space", 0x60F080),        # Space 54
    (0x101820, 0x305048, 0x405858, "lab", 0x60E0A0),          # Laborratory
    (0x142818, 0x305838, 0x204820, "trees", 0xE0C040),        # Westwoods
    (0x1A1030, 0x402850, 0x302030, "bats", 0x8A3A8A),         # Bat Country
    (0x000010, 0x2A1858, 0x3A3A70, "stairs", 0xF0E8A0),       # Astral Stair
    (0x2A5A2A, 0x5A8A4A, 0x3A6A30, "maze", 0x205020),         # Mazerella
    (0x182848, 0x486898, 0x2A4A78, "bridge", 0x8A6A40),       # Tiny Bridge
    (0x783020, 0xE09040, 0x5A4A3A, "cart", 0xB0B0B0),         # Carlo Cart
    (0x080808, 0x201818, 0x181010, "void", 0x805050),         # Room 1665
    (0x201028, 0x604060, 0x403050, "church", 0xE0C0E0),       # Holy Forbidden
    (0x080810, 0x182030, 0x303848, "lab", 0xA0A0F0),          # Eudaimonia Machine
    (0x050404, 0x181210, 0x2A2420, "dungeon", 0xE0A040),      # The Depths
]


def scene(spec, seed: int) -> Image.Image:
    top, bot, ground, motif, detail = (rgb(spec[0]), rgb(spec[1]), rgb(spec[2]), spec[3], rgb(spec[4]))
    rng = random.Random(seed)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    d = ImageDraw.Draw(img)
    for y in range(HORIZON):
        t = y / (HORIZON - 1)
        d.line([(0, y), (W, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (255,))
    d.rectangle([0, HORIZON, W, H], fill=ground)
    dark = tuple(int(c * 0.7) for c in ground[:3]) + (255,)
    for y in range(HORIZON + 2, H, 3):
        for x in range(rng.randint(0, 3), W, 5):
            d.point([x, y], fill=dark)
    if motif in ("trees", "bats"):
        for x in range(2, W, 7):
            h = rng.randint(7, 13)
            d.rectangle([x, HORIZON - h // 2, x + 1, HORIZON + 1], fill=(60, 40, 30, 255))
            d.polygon([(x - 3, HORIZON - h // 2 + 2), (x + 4, HORIZON - h // 2 + 2), (x + 1, HORIZON - h)], fill=detail)
        if motif == "bats":
            for bx, by in ((10, 6), (28, 4), (38, 9)):
                d.line([(bx - 2, by), (bx, by + 1), (bx + 2, by)], fill=detail)
    elif motif == "shelves":
        for x in range(1, W - 4, 8):
            d.rectangle([x, 4, x + 5, HORIZON + 6], fill=detail)
            for y in range(6, HORIZON + 4, 4):
                d.line([(x, y), (x + 5, y)], fill=tuple(int(c * 0.55) for c in detail[:3]) + (255,))
    elif motif == "barn":
        d.rectangle([14, 10, 32, HORIZON + 2], fill=detail)
        d.polygon([(12, 11), (34, 11), (23, 4)], fill=tuple(int(c * 0.7) for c in detail[:3]) + (255,))
        d.rectangle([20, 14, 26, HORIZON + 2], fill=(240, 230, 210, 255))
        for x in range(0, W, 4): d.line([(x, HORIZON + 4), (x, HORIZON + 7)], fill=(230, 220, 190, 255))
    elif motif == "tower":
        d.rectangle([19, 2, 29, HORIZON + 2], fill=detail)
        d.rectangle([17, 2, 31, 4], fill=tuple(int(c * 0.8) for c in detail[:3]) + (255,))
        for y in range(6, HORIZON, 4): d.point([24, y], fill=(255, 230, 120, 255))
    elif motif == "church":
        d.rectangle([12, 10, 36, HORIZON + 2], fill=detail)
        d.polygon([(10, 11), (38, 11), (24, 3)], fill=tuple(int(c * 0.7) for c in detail[:3]) + (255,))
        d.ellipse([21, 12, 27, 18], fill=(255, 220, 140, 255))
    elif motif == "bones":
        for x in range(3, W, 9):
            d.ellipse([x, HORIZON + 3, x + 4, HORIZON + 7], fill=detail)
            d.line([(x + 5, HORIZON + 5), (x + 8, HORIZON + 2)], fill=detail)
    elif motif == "moon":
        d.ellipse([30, 3, 40, 13], fill=detail)
        for _ in range(16): d.point([rng.randint(0, W - 1), rng.randint(0, HORIZON - 3)], fill=(220, 220, 255, 255))
    elif motif in ("space", "stairs"):
        for _ in range(26): d.point([rng.randint(0, W - 1), rng.randint(0, HORIZON)], fill=(230, 230, 255, 255))
        if motif == "stairs":
            for i in range(7): d.rectangle([8 + i * 5, HORIZON + 6 - i * 2, 12 + i * 5, HORIZON + 7 - i * 2], fill=detail)
        else:
            d.ellipse([10, 8, 24, 20], fill=detail)
    elif motif == "snow":
        for _ in range(34): d.point([rng.randint(0, W - 1), rng.randint(0, H - 1)], fill=(255, 255, 255, 255))
        for x in (8, 22, 36):
            d.polygon([(x - 5, HORIZON + 1), (x + 5, HORIZON + 1), (x, HORIZON - 9)], fill=detail)
    elif motif == "lab":
        for x in range(4, W, 12):
            d.rectangle([x, 8, x + 6, HORIZON + 1], fill=tuple(int(c * 0.5) for c in detail[:3]) + (255,))
            d.rectangle([x + 1, 9, x + 5, 14], fill=detail)
    elif motif == "maze":
        for x in range(0, W, 8): d.rectangle([x, 6, x + 2, H], fill=detail)
        for y in range(10, H, 8): d.rectangle([0, y, 30, y + 2], fill=detail)
    elif motif == "bridge":
        d.rectangle([0, 17, W, 20], fill=detail)
        for x in range(2, W, 6): d.line([(x, 17), (x, 12)], fill=detail)
        d.line([(0, 12), (W, 12)], fill=detail)
    elif motif == "cart":
        d.rectangle([0, HORIZON + 4, W, HORIZON + 6], fill=detail)
        d.rectangle([16, HORIZON - 3, 32, HORIZON + 3], fill=(150, 90, 40, 255))
        d.ellipse([18, HORIZON + 2, 22, HORIZON + 6], fill=(30, 30, 30, 255)); d.ellipse([26, HORIZON + 2, 30, HORIZON + 6], fill=(30, 30, 30, 255))
    elif motif == "void":
        d.rectangle([20, 6, 28, HORIZON + 2], fill=detail)
        d.rectangle([22, 9, 26, HORIZON + 2], fill=(0, 0, 0, 255))
    elif motif == "dungeon":
        # A stone archway over stairs going down, with a torch either side.
        stone = (74, 66, 60, 255)
        d.rectangle([0, 0, W, H], fill=(22, 18, 16, 255))
        for y in range(0, H, 4):
            for x in range((y // 4) % 2 * 4, W, 8):
                d.rectangle([x, y, x + 6, y + 2], fill=(46, 40, 36, 255))
        d.rectangle([14, 6, 34, H], fill=stone)
        d.ellipse([16, 4, 32, 18], fill=(0, 0, 0, 255))
        d.rectangle([16, 11, 32, H], fill=(0, 0, 0, 255))
        for i in range(6):
            shade = 90 - i * 14
            d.rectangle([17 + i, 18 + i * 2, 31 - i, 19 + i * 2], fill=(shade, shade - 6, shade - 12, 255))
        for tx in (8, 40):
            d.rectangle([tx, 12, tx + 1, 18], fill=(90, 60, 40, 255))
            d.ellipse([tx - 1, 8, tx + 2, 12], fill=detail)
            d.point([tx, 7], fill=(255, 240, 160, 255))
    return img


def main() -> None:
    GRAPHICS.mkdir(parents=True, exist_ok=True)
    for i, spec in enumerate(SCENES):
        art = scene(spec, i + 1).resize((W * 2, H * 2), Image.NEAREST)
        art.save(GRAPHICS / f"STG{i:02d}.png", optimize=True)
    print(f"wrote {len(SCENES)} stage pictures")


if __name__ == "__main__":
    main()
