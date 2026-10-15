"""Generate room specs (maps/source/<slug>/room.json) for the newer stages.

The first four stages have hand-made rooms; stages added from TODO step 6
on are described here and generated. Layouts are approximations of each
stage's wiki description (data/stages/<slug>.json stage.layout): an open
field, or a horizontal or vertical hall, with scattered square obstacles.
Run: python tools/gen_rooms.py
"""
from __future__ import annotations

import json
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# slug, map, stage id, half width, half height, obstacle count, obstacle
# size range, pattern ("scatter" or "aisles"), sky, light, seed, purpose.
ROOMS = [
    ("cappella-magna", "MAP33", "CAPPELLA", 6144, 6144, 180, (96, 192), "scatter", False, 176, 3301,
     "Cappella Magna-style cathedral grounds with pillars"),
    ("green-acres", "MAP34", "ACRES", 6144, 6144, 90, (64, 160), "scatter", True, 212, 3401,
     "Green Acres-style farmland with scattered hay bales"),
    ("bone-zone", "MAP35", "BONEZONE", 6144, 6144, 160, (48, 128), "scatter", True, 150, 3501,
     "The Bone Zone-style wasteland with bone piles"),
    ("il-molise", "MAP36", "MOLISE", 6144, 6144, 0, (64, 64), "scatter", True, 216, 3601,
     "Il Molise-style open meadow with no obstacles"),
    ("moongolow", "MAP37", "MOONGOLOW", 6144, 6144, 70, (64, 128), "scatter", True, 144, 3701,
     "Moongolow-style moonlit field"),
    ("boss-rash", "MAP38", "BOSSRASH", 2048, 2048, 12, (96, 160), "scatter", False, 160, 3801,
     "Boss Rash-style arena"),
    ("whiteout", "MAP39", "WHITEOUT", 6144, 6144, 70, (64, 192), "scatter", True, 232, 3901,
     "Whiteout-style snowfield with ice blocks"),
    ("lycaeum", "MAP40", "LYCAEUM", 3072, 6144, 90, (128, 256), "aisles", False, 150, 4001,
     "The Lycaeum-style sunken library with bookshelf rows"),
    ("the-coop", "MAP41", "COOP", 12288, 1024, 50, (64, 128), "scatter", True, 212, 4101,
     "The Coop-style long farm strip with fences"),
    ("space-54", "MAP42", "SPACE54", 6144, 6144, 60, (96, 192), "scatter", True, 120, 4201,
     "Space 54-style dark void with debris"),
    ("laborratory", "MAP43", "LABORRATORY", 4096, 4096, 110, (96, 224), "scatter", False, 176, 4301,
     "Laborratory-style lab rooms and machinery"),
    ("westwoods", "MAP44", "WESTWOODS", 6144, 6144, 260, (48, 96), "scatter", True, 196, 4401,
     "Westwoods-style dense forest"),
    ("bat-country", "MAP45", "BATCOUNTRY", 6144, 6144, 50, (64, 160), "scatter", True, 150, 4501,
     "Bat Country-style dusk plain"),
    ("astral-stair", "MAP46", "ASTRAL", 1536, 10240, 60, (96, 160), "aisles", False, 150, 4601,
     "Astral Stair-style tall starry hallway"),
    ("mazerella", "MAP47", "MAZERELLA", 4096, 4096, 0, (192, 192), "maze", False, 170, 4701,
     "Mazerella-style walled maze"),
    ("tiny-bridge", "MAP48", "TINYBRIDGE", 12288, 384, 0, (64, 64), "scatter", True, 208, 4801,
     "Tiny Bridge-style very narrow bridge"),
    ("carlo-cart", "MAP49", "CARLOCART", 30720, 1024, 120, (64, 160), "scatter", True, 200, 4901,
     "Carlo Cart-style long scrolling track"),
    ("room-1665", "MAP50", "ROOM1665", 1024, 12288, 40, (96, 160), "scatter", False, 110, 5001,
     "Room 1665-style dark stacked rooms"),
    ("holy-forbidden", "MAP51", "HOLYFORBIDDEN", 2048, 2048, 14, (96, 160), "scatter", False, 150, 5101,
     "Holy Forbidden-style small forbidden hall"),
    ("eudaimonia-machine", "MAP52", "EUDAIMONIA", 8192, 8192, 70, (96, 224), "scatter", False, 140, 5201,
     "Eudaimonia Machine-style endless machine floor"),
]

# Player start per stage (default the centre). Carlo Cart starts near the
# west end because the track scrolls east.
START_X = {"carlo-cart": -29696}

CLEAR_RADIUS = 480  # keep the start area free


def square(cx: int, cy: int, size: int) -> list[list[int]]:
    h = size // 2
    return [[cx - h, cy - h], [cx + h, cy - h], [cx + h, cy + h], [cx - h, cy + h]]


def obstacles(half_w: int, half_h: int, count: int, sizes: tuple[int, int], pattern: str,
              seed: int) -> list[list[list[int]]]:
    rng = random.Random(seed)
    placed: list[tuple[int, int, int]] = []
    margin = 256
    tries = 0
    while len(placed) < count and tries < count * 50:
        tries += 1
        size = rng.randrange(sizes[0], sizes[1] + 1, 16)
        if pattern == "aisles":
            # Rows of blocks along the long axis, like shelves or pews.
            if half_w >= half_h:
                cx = rng.randrange(-half_w + margin, half_w - margin, 384)
                cy = rng.choice((-1, 1)) * (half_h // 2)
            else:
                cy = rng.randrange(-half_h + margin, half_h - margin, 384)
                cx = rng.choice((-1, 1)) * (half_w // 2)
        elif pattern == "maze":
            break
        else:
            cx = rng.randint(-half_w + margin, half_w - margin)
            cy = rng.randint(-half_h + margin, half_h - margin)
        if cx * cx + cy * cy < CLEAR_RADIUS * CLEAR_RADIUS:
            continue
        if any(abs(cx - x) < (size + s) // 2 + 96 and abs(cy - y) < (size + s) // 2 + 96 for x, y, s in placed):
            continue
        placed.append((cx, cy, size))
    if pattern == "maze":
        # A grid of wall blocks with about 45% left open, so corridors wind
        # between them (approximation of a maze).
        step = 384
        for gx in range(-half_w + step, half_w, step):
            for gy in range(-half_h + step, half_h, step):
                if gx * gx + gy * gy < CLEAR_RADIUS * CLEAR_RADIUS:
                    continue
                if rng.random() < 0.55:
                    placed.append((gx, gy, sizes[0]))
    return [square(x, y, s) for x, y, s in placed]


def main() -> None:
    import sys
    only = set(sys.argv[1:])
    for slug, map_name, sid, half_w, half_h, count, sizes, pattern, sky, light, seed, purpose in ROOMS:
        if only and slug not in only:
            continue
        spec = {
            "fixture_id": f"{sid}-GENERATED-001",
            "classification": "PLAYABLE_STAGE_APPROXIMATION",
            "map_name": map_name,
            "purpose": f"{purpose} (generated by tools/gen_rooms.py)",
            "room": [[-half_w, -half_h], [half_w, -half_h], [half_w, half_h], [-half_w, half_h]],
            "landmark": square(START_X.get(slug, 0), 740 if half_h > 800 else 0, 80) if half_h > 800 else square(START_X.get(slug, 0) + 740, 0, 40),
            "obstacles": obstacles(half_w, half_h, count, sizes, pattern, seed),
            "sky": sky,
            "floor": 0,
            "ceiling": 512,
            "light": light,
            "player": {"x": START_X.get(slug, 0), "y": 0, "angle": 0 if slug in START_X else 90},
            "presentation_fixture_ownership": "NONE",
            "stage_identity": sid,
            "opening_enemy": "BAT3",
            "notes": ["Generated approximation; see data/stages/" + slug + ".json stage.layout."],
        }
        out = ROOT / "maps/source" / slug / "room.json"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(spec, indent=1) + "\n", encoding="utf-8")
        print(f"wrote {out.relative_to(ROOT)}: {len(spec['obstacles'])} obstacles")


if __name__ == "__main__":
    main()
