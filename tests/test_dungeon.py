"""The Depths (MAP53): the superset dungeon is sound. Room blocks only touch
their own room or their own doorways, connector sectors only touch their own
connector or the rooms they join (so closing a door really seals it), and the
generated UDMF sectors are closed. These break silently otherwise."""
from __future__ import annotations

import json
import re
from collections import Counter
from pathlib import Path

from tools import gen_dungeon as gd
from tools.dungeon_udmf import dungeon_blocks

ROOT = Path(__file__).resolve().parents[1]
SPEC = json.loads((ROOT / "maps/source/the-depths/room.json").read_text(encoding="utf-8"))


def owners():
    """Sector -> owner: ("room", slot) or ("conn", id)."""
    b, rooms, room_sector0, conns, slot_conn, _ = gd.build()
    owner = {}
    for g, s0 in room_sector0.items():
        for k in range(25):
            owner[s0 + k] = ("room", g)
    for cid, cn in enumerate(conns):
        for i, j in cn["cells"]:
            owner[b.grid[j][i]] = ("conn", cid)
    return b, conns, owner


def test_sectors_touch_only_what_they_join():
    b, conns, owner = owners()
    bad = []
    for j in range(gd.H):
        for i in range(gd.W):
            s = b.grid[j][i]
            if s < 0:
                continue
            for ni, nj in ((i + 1, j), (i, j + 1)):
                if ni >= gd.W or nj >= gd.H:
                    continue
                t = b.grid[nj][ni]
                if t < 0 or t == s or owner[s] == owner[t]:
                    continue
                pair = {owner[s], owner[t]}
                kinds = {o[0] for o in pair}
                if kinds == {"room", "conn"}:
                    cid = next(o[1] for o in pair if o[0] == "conn")
                    g = next(o[1] for o in pair if o[0] == "room")
                    door = {conns[cid]["door_a"], conns[cid]["door_b"]}
                    if g in (conns[cid]["a"], conns[cid]["b"]) and (s in door or t in door):
                        continue
                bad.append(((i, j), owner[s], owner[t]))
    assert not bad, bad[:10]


def test_every_slot_has_its_doors():
    b, rooms, room_sector0, conns, slot_conn, _ = gd.build()
    for k in range(gd.FLOORS):
        for r in range(gd.SY):
            for c in range(gd.SX):
                g = gd.gslot(k, c, r)
                assert (slot_conn[g * 4 + gd.E] >= 0) == (c + 1 < gd.SX or k + 1 < gd.FLOORS)
                assert (slot_conn[g * 4 + gd.N] >= 0) == (r + 1 < gd.SY)
                assert slot_conn[g * 4 + gd.WEST] >= 0   # a corridor, stairs in, or floor 1's way out
                assert (slot_conn[g * 4 + gd.S] >= 0) == (r > 0)


def test_udmf_sectors_are_closed():
    blocks = dungeon_blocks(SPEC)
    sides = [int(m.group(1)) for blk in blocks for m in [re.match(r"sidedef \{ sector = (\d+);", blk)] if m]
    flow: Counter = Counter()
    for blk in blocks:
        m = re.match(r"linedef \{ v1 = (\d+); v2 = (\d+); sidefront = (\d+);(?: sideback = (\d+);)?", blk)
        if not m:
            continue
        v1, v2, front = int(m.group(1)), int(m.group(2)), int(m.group(3))
        # Walking each sector's boundary with the sector on the right: every
        # vertex must be entered as often as it is left.
        flow[(sides[front], v2)] += 1
        flow[(sides[front], v1)] -= 1
        if m.group(4) is not None:
            back = sides[int(m.group(4))]
            flow[(back, v1)] += 1
            flow[(back, v2)] -= 1
    assert not [k for k, v in flow.items() if v], "open sector boundary"
