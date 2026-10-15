"""Generate The Depths (MAP53): a roguelike dungeon whose plan is new every run.

UZDoom cannot build walls while the game runs, so the map holds a "superset"
dungeon and the run picks a subset of it (after The Binding of Isaac, but with
continuous corridors instead of screen-to-screen doors):

- Five floors lie side by side, each 128 units lower than the last, joined by
  real staircases (no teleporting).
- Each floor is a 5 x 4 grid of room slots. Every pair of neighbouring slots
  has a corridor between them, with a door sector at each end; the room boxes
  are jittered inside their slots, so corridors jog.
- Every room is 5 x 5 blocks (2 x 2 cells each). Each block is its own sector
  that the run can raise to the ceiling, so a room takes the shape of a
  template (pillars, a ring, a cross, ...), like Isaac's hand-made rooms.
- Every east-column room has a staircase to the west-column room in the same
  row of the next floor; floor 1's west-column rooms have stairs up and out.

At run start SliceDungeon.zs grows an Isaac-style plan per floor (rooms by
breadth-first growth plus a few loops; the stairs down go in the farthest
east-column room, the Amulet in the farthest dead end of the bottom floor),
closes every door not in the plan and raises each room's template blocks.

Outputs maps/source/the-depths/room.json (cell sectors for tools/build.py via
tools/dungeon_udmf.py) and src/zscript/gameplay/stages/DungeonTables.zs.
Run: python tools/gen_dungeon.py
"""
from __future__ import annotations

import json
import random
import sys
from collections import deque
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tools.decor_types import ednum  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
SPEC = ROOT / "maps/source/the-depths/room.json"
TABLES = ROOT / "src/zscript/gameplay/stages/DungeonTables.zs"

CELL = 128
FLOORS = 5
SX, SY = 5, 4          # room slots per floor
PITCH = 16             # slot size in cells
ROOM = 10              # room box in cells (5 x 5 blocks of 2 x 2)
JITTER = 1           # keeps every gap between rooms >= 4 cells, room for a jog
GAP_FLOORS = 12        # cells between floors (the staircases)
MARGIN = 12            # west margin (floor 1's stairs out)
FLOOR_DZ = 128         # each floor is this much lower than the one above
ROOM_CEIL = 224
CORRIDOR_CEIL = 128
STAIR_CEIL = 160
FLOOR_W = SX * PITCH
W = MARGIN + FLOORS * FLOOR_W + (FLOORS - 1) * GAP_FLOORS + 2
H = SY * PITCH + 4
SEED = 5301
E, N, WEST, S = 0, 1, 2, 3   # door directions

# Room templates (Isaac-style): 5 x 5 blocks, row 0 is the south row. 'X'
# blocks are raised into pillars, 'P' blocks sink into spike pits; the four
# doorway blocks (the middle of each side) always stay open and the open
# blocks must stay connected. The first is the plain room.
TEMPLATES = [
    [".....", ".....", ".....", ".....", "....."],   # open hall
    [".....", ".X.X.", ".....", ".X.X.", "....."],   # four pillars
    [".....", ".....", "..X..", ".....", "....."],   # centre pillar
    ["X...X", ".....", ".....", ".....", "X...X"],   # rounded
    ["XX.XX", "XX.XX", ".....", "XX.XX", "XX.XX"],   # cross
    ["XX.XX", "X...X", ".....", "X...X", "XX.XX"],   # small chamber
    [".....", ".XXX.", ".XXX.", ".XXX.", "....."],   # ring round a big block
    [".....", ".X.X.", "..X..", ".X.X.", "....."],   # quincunx
    [".....", ".X.X.", ".X.X.", ".X.X.", "....."],   # three lanes
    ["XX..X", "X....", ".....", "....X", "X..XX"],   # cave-ish
    ["XX.XX", ".....", ".....", ".....", "XX.XX"],   # wide hall
    ["X...X", "X...X", ".....", "X...X", "X...X"],   # tall hall
    [".....", ".XX..", ".X...", "...X.", "...XX"],   # broken walls
    ["X...X", "..X..", ".XXX.", "..X..", "X...X"],   # plus-shaped block
    # Spike pits ('P'): sunken blocks of spikes that hurt the player badly;
    # enemies go round them.
    [".....", ".PPP.", ".PXP.", ".PPP.", "....."],   # pit moat round a pillar
    ["PP.PP", ".....", ".....", ".....", "PP.PP"],   # pit trenches
    ["P...P", ".....", ".....", ".....", "P...P"],   # pit corners
    [".....", ".P...", "...P.", ".P...", "....."],   # scattered pits
    [".....", ".X.P.", ".....", ".P.X.", "....."],   # pillars and pits
    [".....", "..P..", ".PXP.", "..P..", "....."],   # pit diamond round a pillar
]
DOORWAY_BLOCKS = ((4, 2), (2, 4), (0, 2), (2, 0))   # E, N, W, S as (bi, bj)


def check_templates() -> None:
    for t, rows in enumerate(TEMPLATES):
        open_blocks = {(i, j) for j in range(5) for i in range(5) if rows[j][i] == "."}
        assert all(d in open_blocks for d in DOORWAY_BLOCKS), f"template {t} blocks a doorway"
        seen = {DOORWAY_BLOCKS[0]}
        queue = deque(seen)
        while queue:
            i, j = queue.popleft()
            for n in ((i + 1, j), (i - 1, j), (i, j + 1), (i, j - 1)):
                if n in open_blocks and n not in seen:
                    seen.add(n)
                    queue.append(n)
        assert seen == open_blocks, f"template {t} is split"


def floor_x0(k: int) -> int:
    return MARGIN + k * (FLOOR_W + GAP_FLOORS)


def gslot(k: int, c: int, r: int) -> int:
    return k * SX * SY + r * SX + c


def place_rooms(rng: random.Random):
    """Room box origins (cells) per global slot, jittered; neighbours whose
    doorways are offset need room for a 2-cell jog."""
    while True:
        rooms = {}
        for k in range(FLOORS):
            for r in range(SY):
                for c in range(SX):
                    rooms[gslot(k, c, r)] = (floor_x0(k) + c * PITCH + 3 + rng.randint(-JITTER, JITTER),
                                             2 + r * PITCH + 3 + rng.randint(-JITTER, JITTER))
        ok = True
        for k in range(FLOORS):
            for r in range(SY):
                for c in range(SX):
                    ax, ay = rooms[gslot(k, c, r)]
                    if c + 1 < SX:
                        bx, by = rooms[gslot(k, c + 1, r)]
                        ok &= ay == by or bx - (ax + ROOM) >= 4
                    if r + 1 < SY:
                        bx, by = rooms[gslot(k, c, r + 1)]
                        ok &= ax == bx or by - (ay + ROOM) >= 4
        if ok:
            return rooms


def route(start: int, end: int, lane_a: int, lane_b: int, rng: random.Random, swap: bool):
    """Ordered 2-cell slices from start to end along u (inclusive), moving
    from lane lane_a to lane_b with one jog. swap=True means u is y."""
    slices = []
    if lane_a == lane_b:
        mid = end + 1
    else:
        mid = rng.randint(start + 1, end - 2)
    for u in range(start, min(mid, end + 1)):
        slices.append([(u, lane_a), (u, lane_a + 1)])
    if lane_a != lane_b:
        step = 1 if lane_b > lane_a else -1
        v = lane_a if step > 0 else lane_a + 1
        last = lane_b + 1 if step > 0 else lane_b
        while True:
            slices.append([(mid, v), (mid + 1, v)])
            if v == last:
                break
            v += step
        for u in range(mid + 2, end + 1):
            slices.append([(u, lane_b), (u, lane_b + 1)])
    if swap:
        slices = [[(b, a) for a, b in s] for s in slices]
    return slices


class Builder:
    def __init__(self):
        self.sectors: list[dict] = []
        self.grid = [[-1] * W for _ in range(H)]
        self.exit_cells: set = set()

    def sector(self, fz, cz, ftex, ctex, wtex, light) -> int:
        self.sectors.append({"f": fz, "c": cz, "ft": ftex, "ct": ctex, "w": wtex, "l": light})
        return len(self.sectors) - 1

    def put(self, cells, sec):
        for i, j in cells:
            assert self.grid[j][i] == -1, f"cell {i},{j} used twice"
            self.grid[j][i] = sec


def world(i, j):
    return int((i + 0.5) * CELL) + OX, int((j + 0.5) * CELL) + OY


def slice_centre(sl):
    xs = [world(i, j)[0] for i, j in sl]
    ys = [world(i, j)[1] for i, j in sl]
    return sum(xs) // len(xs), sum(ys) // len(ys)


OX = -(W * CELL) // 2
OY = -(H * CELL) // 2


def build():
    check_templates()
    rng = random.Random(SEED)
    rooms = place_rooms(rng)
    b = Builder()
    room_sector0 = {}
    for g in range(FLOORS * SX * SY):
        k = g // (SX * SY)
        rx, ry = rooms[g]
        room_sector0[g] = len(b.sectors)
        for bj in range(5):
            for bi in range(5):
                sec = b.sector(-FLOOR_DZ * k, -FLOOR_DZ * k + ROOM_CEIL, "TFLAGSTO", "TSTONEFN", "TSTONEWA", 168)
                b.put([(rx + 2 * bi + di, ry + 2 * bj + dj) for di in (0, 1) for dj in (0, 1)], sec)

    conns = []
    slot_conn = [-1] * (FLOORS * SX * SY * 4)

    def connector(kind, a, bslot, dir_a, slices, za, zb, ceil_h, light, floor_index):
        n = len(slices)
        door_a = b.sector(za, za + ceil_h, "TSTONEFN", "TSTONEFN", "TBRICK", light)
        b.put(slices[0], door_a)
        if kind == 2:
            door_b = door_a
            exit_sec = b.sector(za + 96, za + 96 + 192, "TMARBLE", "TMARBLE", "TSTONEWA", 255)
        else:
            door_b = b.sector(zb, zb + ceil_h, "TSTONEFN", "TSTONEFN", "TBRICK", light)
            b.put(slices[-1], door_b)
        middle = slices[1:] if kind == 2 else slices[1:-1]
        if kind == 0 and middle:
            mid = b.sector(za, za + ceil_h, "TSTONEFN", "TSTONEFN", "TBRICK", light)
            b.put([c for s in middle for c in s], mid)
        else:
            for t, sl in enumerate(middle):
                if kind == 2:
                    if t >= 6:
                        b.put(sl, exit_sec)
                        b.exit_cells.update(sl)
                        continue
                    z = za + 16 * (t + 1)
                else:
                    z = za + int(round((t + 1) / (len(middle) + 1) * (zb - za) / 16.0)) * 16
                b.put(sl, b.sector(z, z + ceil_h, "TFLAGSTO", "TSTONEFN", "TBRICK", light))
        ax, ay = slice_centre(slices[0])
        bx, by = slice_centre(slices[-1])
        conns.append({"kind": kind, "floor": floor_index, "a": a, "b": bslot, "door_a": door_a, "door_b": door_b,
                      "za": za, "zb": zb, "ca": za + ceil_h, "cb": zb + ceil_h, "ax": ax, "ay": ay, "bx": bx, "by": by,
                      "cells": [c for s in slices for c in s]})
        cid = len(conns) - 1
        slot_conn[a * 4 + dir_a] = cid
        if bslot >= 0:
            slot_conn[bslot * 4 + (dir_a + 2) % 4] = cid
        return cid

    for k in range(FLOORS):
        z = -FLOOR_DZ * k
        light = 152 - 8 * k
        for r in range(SY):
            for c in range(SX):
                g = gslot(k, c, r)
                ax, ay = rooms[g]
                if c + 1 < SX:
                    h = gslot(k, c + 1, r)
                    bx, by = rooms[h]
                    connector(0, g, h, E, route(ax + ROOM, bx - 1, ay + 4, by + 4, rng, False),
                              z, z, CORRIDOR_CEIL, light, k)
                if r + 1 < SY:
                    h = gslot(k, c, r + 1)
                    bx, by = rooms[h]
                    connector(0, g, h, N, route(ay + ROOM, by - 1, ax + 4, bx + 4, rng, True),
                              z, z, CORRIDOR_CEIL, light, k)
        for r in range(SY):
            g = gslot(k, SX - 1, r)
            ax, ay = rooms[g]
            if k + 1 < FLOORS:
                h = gslot(k + 1, 0, r)
                bx, by = rooms[h]
                connector(1, g, h, E, route(ax + ROOM, bx - 1, ay + 4, by + 4, rng, False),
                          z, z - FLOOR_DZ, STAIR_CEIL, 136, k)
            if k == 0:
                gw = gslot(0, 0, r)
                wx, wy = rooms[gw]
                slices = [[(wx - 1 - t, wy + 4), (wx - 1 - t, wy + 5)] for t in range(9)]
                connector(2, gw, -1, WEST, slices, z, z, STAIR_CEIL, 176, 0)

    # Corridor clutter lies against a wall, never mid-corridor, so it is not
    # mistaken for a pickup.
    decor = []
    for cn in conns:
        if cn["kind"] != 0:
            continue
        for i, j in cn["cells"][4:-4]:
            if rng.random() >= 0.09:
                continue
            walls = [(di, dj) for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1))
                     if b.grid[j + dj][i + di] < 0]
            if not walls:
                continue
            di, dj = rng.choice(walls)
            x, y = world(i, j)
            decor.append({"x": x + di * 44 + (0 if di else rng.randint(-40, 40)),
                          "y": y + dj * 44 + (0 if dj else rng.randint(-40, 40)),
                          "type": ednum(rng.choice(["skull", "bones_a", "bones_b", "rock_a"]))})
    return b, rooms, room_sector0, conns, slot_conn, decor


def rle(row):
    out = []
    for v in row:
        if out and out[-1][0] == v:
            out[-1][1] += 1
        else:
            out.append([v, 1])
    return out


def zs_tables(b, rooms, room_sector0, conns, slot_conn) -> str:
    def ints(name, values):
        return f"    static const int {name}[] = {{ {', '.join(str(int(v)) for v in values)} }};\n"

    grid_rows = []
    for j in range(H):
        grid_rows.append("".join("E" if (i, j) in b.exit_cells else ("#" if b.grid[j][i] < 0 else ".")
                                 for i in range(W)))
    starts, cells = [], []
    for cn in conns:
        starts.append(len(cells))
        cells += [j * W + i for i, j in cn["cells"]]
    starts.append(len(cells))
    nslots = FLOORS * SX * SY
    templates = ",\n".join(f'        "{"".join(rows)}"' for rows in TEMPLATES)
    rows = ",\n".join(f'        "{r}"' for r in grid_rows)
    col = lambda key: [cn[key] for cn in conns]  # noqa: E731
    return (
        "// GENERATED by tools/gen_dungeon.py. Do not edit.\n"
        "// The Depths (MAP53): the superset dungeon the run picks its plan from.\n"
        "// GRID rows run south to north, cells west to east: '#' rock, '.' open, 'E'\n"
        "// the way out. Global room slot = floor * SX * SY + row * SX + column; a\n"
        "// room's 25 block sectors start at ROOM_SECTOR0 (block = bj * 5 + bi).\n"
        "// Connector kinds: 0 corridor, 1 stairs down (a on the upper floor),\n"
        "// 2 floor 1's stairs out. SLOT_CONN[slot * 4 + dir], dir 0 E 1 N 2 W 3 S.\n"
        "class DSDungeon\n{\n"
        f"    const CELL = {CELL};\n    const W = {W};\n    const H = {H};\n"
        f"    const OX = {OX};\n    const OY = {OY};\n"
        f"    const FLOORS = {FLOORS};\n    const SX = {SX};\n    const SY = {SY};\n"
        f"    const SLOTS = {nslots};\n    const MARGIN = {MARGIN};\n"
        f"    const FLOOR_W = {FLOOR_W};\n    const GAP_FLOORS = {GAP_FLOORS};\n"
        f"    const FLOOR_DZ = {FLOOR_DZ};\n    const ROOM_CEIL = {ROOM_CEIL};\n"
        f"    const CONN_COUNT = {len(conns)};\n    const TEMPLATE_COUNT = {len(TEMPLATES)};\n"
        f"    static const String TEMPLATES[] =\n    {{\n{templates}\n    }};\n"
        f"    static const String GRID[] =\n    {{\n{rows}\n    }};\n"
        + ints("ROOM_X", [rooms[g][0] for g in range(nslots)])
        + ints("ROOM_Y", [rooms[g][1] for g in range(nslots)])
        + ints("ROOM_SECTOR0", [room_sector0[g] for g in range(nslots)])
        + ints("SLOT_CONN", slot_conn)
        + ints("CONN_KIND", col("kind")) + ints("CONN_A", col("a")) + ints("CONN_B", col("b"))
        + ints("CONN_DOOR_A", col("door_a")) + ints("CONN_DOOR_B", col("door_b"))
        + ints("CONN_ZA", col("za")) + ints("CONN_ZB", col("zb"))
        + ints("CONN_CA", col("ca")) + ints("CONN_CB", col("cb"))
        + ints("CONN_AX", col("ax")) + ints("CONN_AY", col("ay"))
        + ints("CONN_BX", col("bx")) + ints("CONN_BY", col("by"))
        + ints("CONN_CELL0", starts) + ints("CONN_CELLS", cells)
        + "}\n"
    )


def main() -> None:
    b, rooms, room_sector0, conns, slot_conn, decor = build()
    start = rooms[gslot(0, 0, 0)]
    px, py = world(start[0] + 5, start[1] + 5)
    spec = {
        "fixture_id": "DEPTHS-GENERATED-002",
        "classification": "PLAYABLE_STAGE_APPROXIMATION",
        "map_name": "MAP53",
        "purpose": "The Depths: a superset roguelike dungeon; each run picks its plan (tools/gen_dungeon.py)",
        "room": [[OX, OY], [OX + W * CELL, OY], [OX + W * CELL, OY + H * CELL], [OX, OY + H * CELL]],
        "landmark": [[0, 0], [8, 0], [8, 8], [0, 8]],
        "obstacles": [], "patches": [],
        "sky": False, "floor": 0, "ceiling": ROOM_CEIL, "light": 160,
        "player": {"x": px, "y": py, "angle": 0},
        "presentation_fixture_ownership": "NONE",
        "stage_identity": "DEPTHS",
        "opening_enemy": "BAT3",
        "dungeon": {"cell": CELL, "w": W, "h": H, "ox": OX, "oy": OY, "sectors": b.sectors,
                    "rle": [rle(row) for row in b.grid]},
        "decor": decor,
        "notes": ["Generated by tools/gen_dungeon.py; the run opens a plan from this superset (SliceDungeon.zs)."],
    }
    SPEC.parent.mkdir(parents=True, exist_ok=True)
    SPEC.write_text(json.dumps(spec, separators=(",", ":")) + "\n", encoding="utf-8")
    TABLES.write_text(zs_tables(b, rooms, room_sector0, conns, slot_conn), encoding="utf-8")
    print(f"wrote {SPEC.relative_to(ROOT)} and {TABLES.relative_to(ROOT)}: {W}x{H} cells, "
          f"{len(b.sectors)} sectors, {len(conns)} connectors, {len(decor)} props")


if __name__ == "__main__":
    main()
