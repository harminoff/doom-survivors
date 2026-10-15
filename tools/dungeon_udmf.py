"""Turn the dungeon cell grid in a room spec (tools/gen_dungeon.py) into UDMF
geometry for tools/build.py (standard library only).

Every open cell names its sector (room blocks, door sectors, corridors, stair
steps); sectors are written in list order, so the runtime can address them by
index. A cell edge between an open cell and rock becomes a one-sided wall; an
edge between two different sectors becomes a two-sided, passable line whose
upper and lower textures show when the run raises a block or shuts a door.
Collinear edges with the same sides are merged into one linedef; a run only
continues while the cells on both sides keep their sectors, so no vertex
lands in the middle of another line.
"""
from __future__ import annotations


def dungeon_blocks(spec: dict) -> list[str]:
    d = spec["dungeon"]
    cell, w, h, ox, oy = d["cell"], d["w"], d["h"], d["ox"], d["oy"]
    sectors = d["sectors"]
    grid = []
    for row in d["rle"]:
        cells = []
        for value, count in row:
            cells += [value] * count
        grid.append(cells)

    def sec(i, j):
        return grid[j][i] if 0 <= i < w and 0 <= j < h else -1

    vertices: dict[tuple[int, int], int] = {}

    def vertex(x, y):
        if (x, y) not in vertices:
            vertices[(x, y)] = len(vertices)
        return vertices[(x, y)]

    # runs[(axis, at, front, back, direction)] = cell indices along the line.
    runs: dict[tuple, list[int]] = {}
    for j in range(h + 1):                 # horizontal edges at y = j
        for i in range(w):
            below, above = sec(i, j - 1), sec(i, j)
            if below == above:
                continue
            if below >= 0:                 # front faces south: run east
                runs.setdefault(("h", j, below, above, 1), []).append(i)
            else:                          # only the cell above is open: run west
                runs.setdefault(("h", j, above, -1, -1), []).append(i)
    for i in range(w + 1):                 # vertical edges at x = i
        for j in range(h):
            left, right = sec(i - 1, j), sec(i, j)
            if left == right:
                continue
            if right >= 0:                 # front faces east: run north
                runs.setdefault(("v", i, right, left, 1), []).append(j)
            else:                          # only the cell to the west is open: run south
                runs.setdefault(("v", i, left, -1, -1), []).append(j)
    lines = []
    for (axis, at, front, back, direction), cells in runs.items():
        cells.sort()
        start = prev = cells[0]
        for c in cells[1:] + [None]:
            if c is not None and c == prev + 1:
                prev = c
                continue
            a, b = start, prev + 1
            if axis == "h":
                p, q = (ox + a * cell, oy + at * cell), (ox + b * cell, oy + at * cell)
            else:
                p, q = (ox + at * cell, oy + a * cell), (ox + at * cell, oy + b * cell)
            if direction < 0:
                p, q = q, p
            lines.append((vertex(*p), vertex(*q), front, back))
            if c is not None:
                start = prev = c

    blocks = ['namespace = "zdoom";']
    for (x, y) in vertices:
        blocks.append(f"vertex {{ x = {x}; y = {y}; }}")
    for s in sectors:
        blocks.append(f'sector {{ heightfloor = {s["f"]}; heightceiling = {s["c"]}; texturefloor = "{s["ft"]}"; '
                      f'textureceiling = "{s["ct"]}"; lightlevel = {s["l"]}; }}')
    side = 0
    for v1, v2, front, back in lines:
        if back < 0:
            blocks.append(f'sidedef {{ sector = {front}; texturemiddle = "{sectors[front]["w"]}"; }}')
            blocks.append(f"linedef {{ v1 = {v1}; v2 = {v2}; sidefront = {side}; blocking = true; }}")
            side += 1
        else:
            for s in (front, back):
                tex = sectors[s]["w"]
                blocks.append(f'sidedef {{ sector = {s}; texturetop = "{tex}"; texturebottom = "{tex}"; }}')
            blocks.append(f"linedef {{ v1 = {v1}; v2 = {v2}; sidefront = {side}; sideback = {side + 1}; twosided = true; }}")
            side += 2
    return blocks
