"""Helpers for the stage room generators (standard library only).

A RoomBuilder wraps a room.json spec and collects floor patches (paths,
ponds, rugs), solid blocks and non-solid decor props, keeping props out of
patches, blocks and the start area.
"""
from __future__ import annotations

import json
import math
import random
from pathlib import Path

from tools.decor_types import DECOR, ednum

ROOT = Path(__file__).resolve().parents[1]


# First-person eye height is 41, so props need to be dense to read as a
# populated field; scatter counts in the stage scripts are multiplied by this.
DENSITY = 2.6


def rect(x0, y0, x1, y1):
    """Counter-clockwise rectangle."""
    return [[x0, y0], [x1, y0], [x1, y1], [x0, y1]]


def ellipse(cx, cy, rx, ry, n=16):
    return [[int(cx + rx * math.cos(2 * math.pi * i / n)), int(cy + ry * math.sin(2 * math.pi * i / n))] for i in range(n)]


class RoomBuilder:
    def __init__(self, slug, seed):
        self.slug = slug
        self.path = ROOT / f"maps/source/{slug}/room.json"
        self.spec = json.loads(self.path.read_text(encoding="utf-8"))
        self.rng = random.Random(seed)
        self.patches = []
        self.blocks = []
        self.decor = []
        self.shapes = []          # (kind, geometry, margin) exclusion shapes
        room = self.spec["room"]
        xs = [p[0] for p in room]
        ys = [p[1] for p in room]
        self.x0, self.x1, self.y0, self.y1 = min(xs), max(xs), min(ys), max(ys)
        self.start = (self.spec["player"]["x"], self.spec["player"]["y"])

    # -- geometry ----------------------------------------------------------
    def set_room(self, polygon):
        self.spec["room"] = [list(p) for p in polygon]
        xs = [p[0] for p in polygon]
        ys = [p[1] for p in polygon]
        self.x0, self.x1, self.y0, self.y1 = min(xs), max(xs), min(ys), max(ys)

    def patch(self, floor, polygon, blocking=False, exclude=True):
        self.patches.append({"floor": floor, "polygon": [list(p) for p in polygon], "blocking": blocking})
        if exclude and blocking:
            self.shapes.append(("poly", polygon, 60))

    def block(self, polygon, margin=60):
        self.blocks.append([list(p) for p in polygon])
        self.shapes.append(("poly", polygon, margin))

    def keep_clear(self, polygon, margin=0):
        self.shapes.append(("poly", polygon, margin))

    def _inside(self, x, y, shape):
        kind, geo, margin = shape
        xs = [p[0] for p in geo]
        ys = [p[1] for p in geo]
        return min(xs) - margin < x < max(xs) + margin and min(ys) - margin < y < max(ys) + margin

    def free(self, x, y, clear=250):
        if math.hypot(x - self.start[0], y - self.start[1]) < clear:
            return False
        return not any(self._inside(x, y, s) for s in self.shapes)

    # -- props -------------------------------------------------------------
    def prop(self, name, x, y):
        self.decor.append({"x": int(x), "y": int(y), "type": ednum(name)})

    def scatter(self, names, count, margin=300, clear=250, box=None):
        if isinstance(names, str):
            names = [names]
        bx0, by0, bx1, by1 = box or (self.x0 + margin, self.y0 + margin, self.x1 - margin, self.y1 - margin)
        count = int(count * DENSITY)
        placed = attempts = 0
        while placed < count and attempts < count * 60:
            attempts += 1
            x = self.rng.randint(bx0, bx1)
            y = self.rng.randint(by0, by1)
            if not self.free(x, y, clear):
                continue
            self.prop(self.rng.choice(names), x, y)
            placed += 1

    def line(self, name, x0, y0, x1, y1, step):
        length = math.hypot(x1 - x0, y1 - y0)
        n = max(1, int(length // step))
        for i in range(n + 1):
            t = i / n
            self.prop(name, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t)

    def edge_ring(self, names, step, inset=(120, 330)):
        """A row of props just inside the boundary (a treeline)."""
        if isinstance(names, str):
            names = [names]
        r = self.rng
        x = self.x0 + 100
        while x < self.x1 - 99:
            for edge in (self.y0, self.y1):
                off = r.randint(*inset)
                y = edge + off if edge == self.y0 else edge - off
                self.prop(r.choice(names), x + r.randint(-30, 30), y)
            x += step
        y = self.y0 + 100
        while y < self.y1 - 99:
            for edge in (self.x0, self.x1):
                off = r.randint(*inset)
                x2 = edge + off if edge == self.x0 else edge - off
                self.prop(r.choice(names), x2, y + r.randint(-30, 30))
            y += step

    # -- output ------------------------------------------------------------
    def save(self, note, **overrides):
        s = self.spec
        s["obstacles"] = self.blocks
        s["patches"] = self.patches
        s["decor"] = self.decor
        s["notes"] = [note]
        s.update(overrides)
        self.path.write_text(json.dumps(s, indent=1) + "\n", encoding="utf-8")
        return len(self.decor), len(self.blocks), len(self.patches)
