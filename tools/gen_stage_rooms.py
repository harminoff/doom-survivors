"""Generate the stage room specs (maps/source/<slug>/room.json) to mirror the
look and layout of the source stages (wiki tilemaps and stage cards):
open fields with props instead of scattered pillars, patches for paths,
pools and rugs, and solid blocks only where the source has buildings.

Mad Forest has its own script (gen_mad_forest_room.py). Run:
python tools/gen_stage_rooms.py
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tools.roomkit import RoomBuilder, ellipse, rect  # noqa: E402

EDGE = 6080


def green_acres():
    b = RoomBuilder("green-acres", 3401)
    tile = 1536
    for i in range(8):
        for j in range(8):
            if (i + j) % 2 == 1:
                x0 = -6144 + i * tile; y0 = -6144 + j * tile
                b.patch("acresb", rect(max(x0, -EDGE), max(y0, -EDGE), min(x0 + tile, EDGE), min(y0 + tile, EDGE)))
    b.scatter("hay", 14, margin=500)
    b.scatter(["rock_a", "rock_b"], 16, margin=400)
    b.scatter(["bush_a", "bush_b"], 20, margin=400)
    # Density pass: the farm gets flowers, fruit trees, chickens and carts.
    b.scatter(["flowers_a", "flowers_b", "tree_fruit", "chicken", "cart"], 50, margin=400)
    return b.save("Green Acres: an open checkerboard of two dark greens (wiki tilemap), nothing solid.",
                  sky=True, ceiling=512, light=255)


def il_molise():
    b = RoomBuilder("il-molise", 3601)
    b.scatter(["tree_leaf_a", "tree_leaf_b"], 70, margin=350)
    b.scatter("tree_fruit", 30, margin=350)
    b.scatter(["flowers_a", "flowers_b"], 170, margin=200, clear=120)
    b.scatter(["mushroom_red", "mushroom_orange"], 90, margin=250, clear=120)
    b.scatter(["bush_a", "bush_b"], 80, margin=300)
    b.edge_ring(["tree_leaf_a", "tree_leaf_b", "tree_fruit"], 120)
    return b.save("Il Molise: an open flowery meadow with leafy and fruit trees and mushrooms.", sky=True, ceiling=512, light=255)


def bone_zone():
    b = RoomBuilder("bone-zone", 3501)
    for _ in range(9):
        cx = b.rng.randint(-5000, 5000); cy = b.rng.randint(-5000, 5000)
        if abs(cx) + abs(cy) > 900:
            b.patch("batrock", ellipse(cx, cy, b.rng.randint(300, 700), b.rng.randint(240, 520)))
    b.scatter("skull", 150, margin=250, clear=150)
    b.scatter(["bones_a", "bones_b"], 220, margin=250, clear=120)
    b.scatter(["rock_a", "rock_b"], 80, margin=300)
    b.scatter(["tree_dead_a", "tree_dead_b", "tree_dead_c"], 26, margin=400)
    b.edge_ring(["tree_dead_a", "tree_dead_b", "tree_dead_c", "rock_a"], 150)
    return b.save("The Bone Zone: brown dirt and rock strewn with skulls, bones and dead trees.", sky=True, ceiling=512, light=200)


def westwoods():
    b = RoomBuilder("westwoods", 4401)
    for cx, cy, rx, ry in ((-2800, 1800, 1300, 800), (3000, -2600, 1500, 900), (2400, 3600, 900, 600)):
        b.patch("wtrdark", ellipse(cx, cy, rx, ry), blocking=True)
    b.scatter(["tree_dark"], 320, margin=300, clear=200)
    b.scatter(["shrub_dark_a", "shrub_dark_b"], 160, margin=250, clear=150)
    b.scatter(["mushroom_red", "mushroom_orange"], 40, margin=300)
    b.edge_ring(["tree_dark"], 90, inset=(100, 400))
    return b.save("Westwoods: a dark night forest with lakes, dense trees and shrubs.", sky=True, ceiling=512, light=190)


def bat_country():
    b = RoomBuilder("bat-country", 4501)
    road = [[-EDGE, -260], [EDGE, -260], [EDGE, 260], [-EDGE, 260]]
    b.patch("path", road)
    b.keep_clear(road, 100)
    b.scatter(["crystal_blue"], 40, margin=400)
    b.scatter(["rock_a", "rock_b"], 160, margin=300)
    b.scatter(["tree_dead_a", "tree_dead_b", "tree_dead_c"], 40, margin=400)
    b.edge_ring(["rock_a", "rock_b", "tree_dead_a"], 130)
    return b.save("Bat Country: a dusk road through rocky terrain with crystals and dead trees.", sky=True, ceiling=512, light=190)


def whiteout():
    b = RoomBuilder("whiteout", 3901)
    for cx, cy, rx, ry in ((2200, 1500, 520, 380), (-3200, -2800, 600, 440)):
        b.patch("water", ellipse(cx, cy, rx, ry), blocking=True)
    b.scatter("pine_snow", 140, margin=350)
    b.scatter("snowman", 70, margin=300, clear=200)
    b.scatter("ice", 80, margin=300)
    b.scatter(["rock_a", "rock_b"], 30, margin=300)
    b.edge_ring(["pine_snow"], 110)
    return b.save("Whiteout: a snowfield with snowy pines, snowmen, ice and two hot springs.", sky=True, ceiling=512, light=240)


def moongolow():
    b = RoomBuilder("moongolow", 3701)
    for _ in range(10):
        cx = b.rng.randint(-5200, 5200); cy = b.rng.randint(-5200, 5200)
        if abs(cx) + abs(cy) > 1200:
            b.patch("water", ellipse(cx, cy, b.rng.randint(260, 560), b.rng.randint(200, 420)), blocking=False)
    for _ in range(12):
        cx = b.rng.randint(-5200, 5200); cy = b.rng.randint(-5200, 5200)
        if abs(cx) + abs(cy) > 1000:
            w = b.rng.choice((260, 340)); d = 70
            b.block(rect(cx, cy, cx + w, cy + d) if b.rng.random() < 0.5 else rect(cx, cy, cx + d, cy + w))
    b.scatter("column", 50, margin=350)
    b.scatter("urn", 50, margin=300)
    b.scatter("seaweed", 130, margin=250, clear=150)
    b.scatter("statue", 12, margin=400)
    return b.save("Moongolow: a moonlit sunken city of teal tiles, pools, broken columns and low ruin walls.",
                  sky=True, ceiling=512, light=170)


def space_54():
    b = RoomBuilder("space-54", 4201)
    b.scatter(["planet_a", "planet_b"], 14, margin=500, clear=800)
    b.scatter(["asteroid_a", "asteroid_b"], 110, margin=300)
    b.scatter(["crystal_purple"], 30, margin=400)
    return b.save("Space 54: an open starfield with drifting planets, asteroids and crystals.", sky=True, ceiling=512, light=200)


def dairy_plant():
    b = RoomBuilder("dairy-plant", 3101)
    # concrete lots with grey buildings; the warehouse interior and milk
    # pools follow the wiki tilemap (6 units per tilemap pixel).
    for x0, y0, w, h in ((-4900, 5000, 680, 520), (-3000, 2600, 700, 520), (1500, 4700, 1100, 820)):
        b.block(rect(x0, y0, x0 + w, y0 + h), margin=120)
    b.patch("wrehous", rect(1400, -5400, EDGE - 100, -1000))
    for x0, y0, w, h in ((1300, 3300, 600, 140), (2600, 3300, 600, 140), (1300, 2100, 600, 140), (2600, 2100, 600, 140)):
        b.patch("milk", rect(x0, y0, x0 + w, y0 + h), blocking=True)
    # fenced yard with a small plant building in the south-west
    cx, cy = -2400, -3500
    b.block(rect(cx - 200, cy - 160, cx + 200, cy + 160), margin=120)
    for x in range(cx - 700, cx + 701, 120):
        b.prop("fence", x, cy + 640)
        b.prop("fence", x, cy - 640)
    for y in range(cy - 640, cy + 641, 120):
        b.prop("fence", cx - 700, y)
        b.prop("fence", cx + 700, y)
    b.scatter("milk_can", 26, box=(cx - 560, cy - 500, cx + 560, cy + 500), clear=0)
    for gx in range(-4200, 4300, 1050):
        for gy in range(-4200, 4300, 1050):
            if b.free(gx, gy, 300):
                b.prop("lamp", gx, gy)
    b.scatter("milk_can", 40, margin=400)
    return b.save("Dairy Plant: a concrete works with grey buildings, milk pools, a fenced yard and a warehouse hall.",
                  sky=True, ceiling=512, light=210)


def inlaid_library():
    b = RoomBuilder("inlaid-library", 3001)
    # hall is 24576 x 1792; the long walls are bookshelves (wall texture)
    b.patch("sandst", rect(-12200, -110, 12200, 140), exclude=False)
    for cx in (-9000, -1500, 6500):
        b.patch("rugred", rect(cx - 380, -500, cx + 380, -60), exclude=False)
    b.prop("piano", -9000, -300)
    b.prop("table_red", -9200, -200)
    b.prop("table_white", -1500, -300)
    b.prop("table_white", -1650, -250)
    b.prop("table_red", 6500, -300)
    for x in range(-11800, 11801, 700):
        b.prop("candelabra", x, -800 if (x // 700) % 2 else 800)
    for x in range(-11000, 11001, 1500):
        b.block(rect(x, 780, x + 220, 870), margin=40)
        b.block(rect(x + 700, -870, x + 920, -780), margin=40)
    b.scatter("books", 40, margin=150, clear=120, box=(-12000, -700, 12000, 700))
    b.scatter(["table_white", "table_red"], 10, margin=200, clear=200, box=(-12000, -600, 12000, 600))
    return b.save("Inlaid Library: a long hall of shelves with a patterned carpet strip, rugs, a piano and candelabra.")


def gallo_tower():
    b = RoomBuilder("gallo-tower", 3201)
    # a tapering tower: (y0, y1, half width) segments, bottom to top
    segments = [(-12288, -6000, 1500), (-6000, -1500, 1150), (-1500, 3500, 1000), (3500, 7500, 1300), (7500, 12288, 950)]
    left = []
    right = []
    for y0, y1, hw in segments:
        left += [[-hw, y0], [-hw, y1]]
        right += [[hw, y0], [hw, y1]]
    polygon = []
    # counter-clockwise: up the right side, back down the left side
    for y0, y1, hw in segments:
        polygon += [[hw, y0], [hw, y1]]
    for y0, y1, hw in reversed(segments):
        polygon += [[-hw, y1], [-hw, y0]]
    b.set_room(polygon)
    b.patch("carpetr", rect(-160, -11800, 160, -7800), exclude=False)
    b.patch("redbord", ellipse(0, 4200, 320, 320), exclude=False)
    for y in range(-11500, 12000, 1400):
        hw = next(s[2] for s in segments if s[0] <= y < s[1]) if any(s[0] <= y < s[1] for s in segments) else 900
        b.prop("candelabra", -hw + 140, y)
        b.prop("candelabra", hw - 140, y)
        if (y // 1400) % 2:
            b.prop("statue", -hw + 300, y + 400)
            b.prop("statue", hw - 300, y + 400)
    # Density pass: lamps and statues along the whole tower, kept to its narrowest width.
    b.scatter(["lamp", "candelabra", "statue", "column"], 30, margin=200, clear=300, box=(-800, -11500, 800, 11500))
    return b.save("Gallo Tower: a stepped tower of purple stone floating in a starfield, with candelabra and statues.",
                  sky=True, ceiling=160, light=200)


def cappella_magna():
    b = RoomBuilder("cappella-magna", 3301)
    for x0, y0, x1, y1 in ((-EDGE, -EDGE, -EDGE + 300, EDGE), (EDGE - 300, -EDGE, EDGE, EDGE),
                           (-EDGE + 300, EDGE - 300, EDGE - 300, EDGE), (-EDGE + 300, -EDGE, EDGE - 300, -EDGE + 300)):
        b.patch("redbord", rect(x0, y0, x1, y1), exclude=False)
    b.patch("cloudpl", rect(-2000, -1500, 2000, 2500), blocking=True)
    for sx in (-1, 1):
        b.patch("cloudpl", rect(sx * 3800 - 260, -4300, sx * 3800 + 260, -3300), blocking=True)
        b.block(rect(sx * 5000 - 300, 2500, sx * 5000 + 300, 3300), margin=100)
    b.patch("cloudpl", rect(-700, -3900, 700, -3700), blocking=True)
    for sx in (-1, 1):
        for y in range(-2600, 3000, 480):
            b.prop("statue", sx * 3400, y)
    for x in range(-EDGE + 500, EDGE - 400, 900):
        b.prop("column", x, EDGE - 500)
        b.prop("column", x, -EDGE + 500)
    # Density pass: graves, urns and candelabra across the grounds.
    b.scatter(["urn", "candelabra", "grave"], 120, margin=500)
    b.scatter(["statue", "column"], 12, margin=500)
    return b.save("Cappella Magna: a sandstone court with a red border and a great sky-filled pool, statues and columns.",
                  sky=True, ceiling=256, light=215, player={"x": 0, "y": -3000, "angle": 90})


def laborratory():
    b = RoomBuilder("laborratory", 4301)
    for _ in range(14):
        cx = b.rng.randint(-3600, 3600); cy = b.rng.randint(-3600, 3600)
        if abs(cx) + abs(cy) > 900:
            w = b.rng.choice((200, 280)); d = b.rng.choice((120, 160))
            b.block(rect(cx, cy, cx + w, cy + d))
    for y in (-2000, 2000):
        b.patch("stonefn", rect(-3900, y - 120, 3900, y + 120), exclude=False)
    b.scatter("beaker", 50, margin=250, clear=150)
    return b.save("Laborratory: grey lab tile with a few machines, conveyor strips and glassware.")


def carlo_cart():
    b = RoomBuilder("carlo-cart", 4901)
    b.scatter("rock_a", 30, margin=200, clear=300, box=(-30000, -800, 30000, 800))
    return b.save("Carlo Cart: a long dark tunnel of rails; nearly empty.")


def boss_rash():
    b = RoomBuilder("boss-rash", 3801)
    for cx, cy in ((-1300, -1300), (1300, -1300), (-1300, 1300), (1300, 1300), (0, -1500), (0, 1500), (-1500, 0), (1500, 0)):
        b.block(rect(cx - 70, cy - 70, cx + 70, cy + 70))
    b.scatter(["skull", "bones_a", "bones_b", "column"], 8, margin=300)
    return b.save("Boss Rash: a stone arena ringed by eight pillars.")


def astral_stair():
    b = RoomBuilder("astral-stair", 4601)
    for y in range(-9800, 10001, 900):
        b.prop("candelabra", -1300, y)
        b.prop("candelabra", 1300, y)
    b.patch("rugred", rect(-300, -9900, 300, 9900), exclude=False)
    b.scatter(["crystal_blue", "crystal_purple", "candelabra"], 20, margin=300, clear=300, box=(-1100, -9800, 1100, 9800))
    return b.save("Astral Stair: a long red-carpeted hall lined with candelabra.")


def the_coop():
    b = RoomBuilder("the-coop", 4101)
    b.scatter("hay", 14, margin=250, clear=250, box=(-12000, -800, 12000, 800))
    b.scatter("chicken", 60, margin=200, clear=150, box=(-12000, -850, 12000, 850))
    return b.save("The Coop: a long fenced strip of grass with hay bales and chickens.")


def room_1665():
    b = RoomBuilder("room-1665", 5001)
    for y in range(-12000, 12001, 600):
        b.prop("candelabra", -900, y)
        b.prop("candelabra", 900, y)
    b.scatter("skull", 30, margin=200, clear=300)
    return b.save("Room 1665: a dark corridor of rooms that open as you kill (player starts in the north room).",
                  player={"x": 0, "y": 11300, "angle": 270})


def _keep_obstacles(b):
    """Reuse the obstacle blocks gen_rooms.py wrote, and keep props off them."""
    b.blocks = [list(o) for o in b.spec.get("obstacles", [])]
    for o in b.blocks:
        b.keep_clear(o, 120)


def lycaeum():
    b = RoomBuilder("lycaeum", 4001)
    _keep_obstacles(b)
    b.scatter(["books", "lamp", "candelabra", "table_white", "urn"], 35, margin=400)
    return b.save("The Lycaeum: a sunken library with bookshelf rows, tables, lamps and loose books.")


def holy_forbidden():
    b = RoomBuilder("holy-forbidden", 5101)
    _keep_obstacles(b)
    b.scatter(["candelabra", "statue", "skull", "urn", "grave"], 12, margin=300)
    return b.save("Holy Forbidden: a small forbidden hall with candles, statues and graves.")


def eudaimonia_machine():
    b = RoomBuilder("eudaimonia-machine", 5201)
    _keep_obstacles(b)
    b.scatter(["beaker", "lamp", "crystal_blue", "crystal_purple", "asteroid_a"], 150, margin=500)
    return b.save("Eudaimonia Machine: an endless machine floor strewn with beakers, lamps and crystals.")


STAGES = [green_acres, il_molise, bone_zone, westwoods, bat_country, whiteout, moongolow, space_54,
          dairy_plant, inlaid_library, gallo_tower, cappella_magna, laborratory, carlo_cart, boss_rash,
          astral_stair, the_coop, room_1665, lycaeum, holy_forbidden, eudaimonia_machine]


def main():
    import sys
    only = set(sys.argv[1:])
    for fn in STAGES:
        if only and fn.__name__ not in only:
            continue
        print(fn.__name__, fn())


if __name__ == "__main__":
    main()
