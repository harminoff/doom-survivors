"""Generate the enemy sprites (original pixel art, drawn in code).

Each archetype (bat, skeleton, ghost...) is drawn on a 32x32 canvas with
two animation frames and three colour variants, outlined, then scaled 2x
with nearest-neighbour sampling for chunky pixels. Outputs:
- src/resources/sprites/E<code><variant><frame>0.png  (e.g. EBTAA0.png)
- src/zscript/gameplay/presentation/EnemyArt.zs      (sprite names)

Which enemy type uses which archetype and variant is decided in
tools/gen_stages.py (ARCHETYPE_RULES). Presentation only: none of this
changes gameplay.
Run: python tools/art/enemy_art.py
"""
from __future__ import annotations

import colorsys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SPRITES = ROOT / "src/resources/sprites"
ZSCRIPT = ROOT / "src/zscript/gameplay/presentation/EnemyArt.zs"

OUTLINE = (24, 14, 30, 255)
N = 32  # drawing canvas; output is 2x

# Archetype order defines the family numbers (1-based) used by DSStage.Family.
ARCHETYPES = [
    # code, name, base colour, accent colour
    ("BT", "bat", (86, 70, 150), (230, 60, 70)),
    ("ZB", "zombie", (96, 150, 90), (200, 60, 60)),
    ("SK", "skeleton", (232, 226, 206), (220, 60, 50)),
    ("GH", "ghost", (170, 200, 250), (40, 40, 90)),
    ("MD", "mudman", (140, 100, 60), (250, 210, 80)),
    ("BS", "beast", (130, 100, 90), (250, 220, 90)),
    ("IN", "insect", (110, 190, 80), (240, 80, 60)),
    ("MU", "mummy", (220, 200, 150), (90, 200, 230)),
    ("PL", "plant", (80, 170, 70), (240, 90, 170)),
    ("RP", "reaper", (40, 36, 48), (230, 40, 40)),
    ("JL", "jelly", (120, 200, 230), (250, 120, 200)),
    ("CS", "caster", (120, 60, 150), (250, 200, 80)),
    ("KN", "knight", (150, 160, 180), (220, 50, 60)),
    ("DR", "dragon", (200, 90, 60), (250, 220, 90)),
    ("FS", "fish", (70, 150, 170), (250, 200, 90)),
    ("DM", "demon", (170, 40, 50), (250, 210, 60)),
    ("AN", "angel", (240, 230, 200), (250, 200, 60)),
    ("OB", "object", (170, 130, 90), (90, 200, 240)),
    ("CK", "critter", (245, 240, 230), (240, 70, 50)),
    ("BL", "blob", (200, 180, 230), (70, 50, 90)),
]
VARIANTS = "ABCD"  # A normal, B elite (red-shifted), C special (hue-shifted), D boss (crowned)
BOSS_OUTLINE = (170, 24, 36, 255)


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c[:3]) + (255,)


def hue(c, dh, ds=1.0):
    h, l, s = colorsys.rgb_to_hls(*(v / 255 for v in c[:3]))
    r, g, b = colorsys.hls_to_rgb((h + dh) % 1.0, l, min(1.0, s * ds))
    return (int(r * 255), int(g * 255), int(b * 255), 255)


def palette(base, accent, variant):
    if variant == "D":
        base = shade(base, 0.82)
        accent = (255, 215, 70, 255)
    if variant == "B":
        base = hue(base, 0.0 - (colorsys.rgb_to_hls(*(v / 255 for v in base))[0]), 1.3)  # toward red
        base = shade(base, 0.9)
    elif variant == "C":
        base = hue(base, 0.45, 1.2)
    base = base[:3] + (255,)
    return {"b": base, "d": shade(base, 0.62), "l": shade(base, 1.3), "a": accent[:3] + (255,),
            "e": (255, 245, 170, 255), "k": (16, 10, 20, 255), "w": (250, 250, 245, 255)}


def outline(img, colour=OUTLINE):
    px = img.load()
    out = img.copy()
    po = out.load()
    for y in range(N):
        for x in range(N):
            if px[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < N and 0 <= ny < N and px[nx, ny][3] and px[nx, ny] != OUTLINE:
                    po[x, y] = colour
                    break
    return out


def eyes(d, p, x, y, gap=4, colour=None):
    c = colour or p["e"]
    d.rectangle([x - gap // 2 - 1, y, x - gap // 2, y + 1], fill=c)
    d.rectangle([x + gap // 2, y, x + gap // 2 + 1, y + 1], fill=c)


# ---- archetype painters: (draw, palette, frame 0/1) -------------------------

def bat(d, p, f):
    flap = -3 if f else 2
    d.polygon([(16, 14), (2, 10 + flap), (6, 18), (10, 16), (13, 20)], fill=p["b"])
    d.polygon([(16, 14), (30, 10 + flap), (26, 18), (22, 16), (19, 20)], fill=p["b"])
    d.ellipse([11, 11, 21, 22], fill=p["d"])
    d.polygon([(12, 12), (13, 7), (15, 12)], fill=p["d"])
    d.polygon([(17, 12), (19, 7), (20, 12)], fill=p["d"])
    eyes(d, p, 16, 15, 4, p["a"])
    d.point([(15, 20), (17, 20)], fill=p["w"])


def humanoid(d, p, f, head, body, arms_up=False, legs=True):
    bob = 1 if f else 0
    if legs:
        d.rectangle([12, 24, 14, 30], fill=p["d"])
        d.rectangle([18, 24, 20, 30 - bob], fill=p["d"])
    d.rectangle([11, 14 + bob, 21, 25], fill=body)
    arm_y = 10 if arms_up else 15
    d.rectangle([7, arm_y + bob, 10, arm_y + 8], fill=body)
    d.rectangle([22, arm_y - bob, 25, arm_y + 8], fill=body)
    d.ellipse([11, 4 + bob, 21, 14 + bob], fill=head)


def zombie(d, p, f):
    humanoid(d, p, f, p["l"], p["b"], arms_up=True)
    d.rectangle([12, 18, 20, 19], fill=p["d"])
    eyes(d, p, 16, 8 + f, 4, p["a"])


def skeleton(d, p, f):
    bob = f
    for yy in (15, 18, 21):
        d.rectangle([12, yy + bob, 20, yy + bob], fill=p["b"])
    d.rectangle([15, 14 + bob, 17, 24], fill=p["b"])
    d.rectangle([12, 25, 13, 30], fill=p["b"]); d.rectangle([19, 25, 20, 30 - bob], fill=p["b"])
    d.rectangle([8, 15 + bob, 9, 23], fill=p["b"]); d.rectangle([23, 15 - bob, 24, 23], fill=p["b"])
    d.ellipse([11, 3 + bob, 21, 13 + bob], fill=p["b"])
    d.rectangle([13, 7 + bob, 14, 9 + bob], fill=p["k"]); d.rectangle([18, 7 + bob, 19, 9 + bob], fill=p["k"])
    d.point([(14, 8 + bob), (18, 8 + bob)], fill=p["a"])
    d.rectangle([14, 11 + bob, 18, 12 + bob], fill=p["d"])


def ghost(d, p, f):
    w = 1 if f else 0
    d.ellipse([8, 4, 24, 20], fill=p["b"])
    d.rectangle([8, 12, 24, 25], fill=p["b"])
    for i, x in enumerate(range(8, 24, 4)):
        d.polygon([(x, 25), (x + 4, 25), (x + 2 - w * (1 if i % 2 else -1), 30)], fill=p["b"])
    d.ellipse([10, 5, 16, 11], fill=p["l"])
    d.ellipse([12, 10, 15, 14], fill=p["k"]); d.ellipse([17, 10, 20, 14], fill=p["k"])
    d.ellipse([14, 17, 18, 21], fill=p["d"])


def mudman(d, p, f):
    s = 1 if f else 0
    d.ellipse([7 - s, 10, 25 + s, 31], fill=p["b"])
    d.ellipse([10, 4 + s, 22, 18], fill=p["b"])
    d.ellipse([11, 6 + s, 16, 11], fill=p["l"])
    eyes(d, p, 16, 11 + s, 5, p["a"])
    d.rectangle([13, 15 + s, 19, 16 + s], fill=p["d"])
    d.ellipse([6, 16, 11, 24], fill=p["d"]); d.ellipse([21, 16, 26, 24], fill=p["d"])


def beast(d, p, f):
    st = 2 if f else 0
    d.ellipse([7, 12, 26, 25], fill=p["b"])
    d.rectangle([9, 22, 11, 30 - st], fill=p["d"]); d.rectangle([22, 22, 24, 30 - (2 - st)], fill=p["d"])
    d.ellipse([3, 7, 15, 18], fill=p["b"])
    d.polygon([(4, 9), (5, 3), (8, 8)], fill=p["d"]); d.polygon([(10, 8), (13, 3), (14, 9)], fill=p["d"])
    d.rectangle([1, 13, 6, 16], fill=p["l"])
    d.point([(2, 16), (4, 16)], fill=p["w"])
    eyes(d, p, 9, 10, 4, p["a"])
    d.line([(26, 16), (30, 11 + st)], fill=p["d"], width=2)


def insect(d, p, f):
    lg = 1 if f else -1
    for i, y in enumerate((18, 21, 24)):
        d.line([(10, y), (4, y + 3 + lg * (1 if i % 2 else -1))], fill=p["d"])
        d.line([(22, y), (28, y + 3 - lg * (1 if i % 2 else -1))], fill=p["d"])
    d.ellipse([9, 16, 23, 29], fill=p["b"])
    d.ellipse([11, 8, 21, 18], fill=p["b"])
    d.polygon([(10, 10), (4, 4 + lg), (8, 12)], fill=p["l"]); d.polygon([(22, 10), (28, 4 - lg), (24, 12)], fill=p["l"])
    eyes(d, p, 16, 11, 5, p["a"])
    d.line([(13, 8), (10, 2)], fill=p["d"]); d.line([(19, 8), (22, 2)], fill=p["d"])


def mummy(d, p, f):
    humanoid(d, p, f, p["b"], p["b"], arms_up=True)
    for yy in range(6, 26, 3):
        d.line([(10, yy + f), (22, yy + 1 + f)], fill=p["d"])
    eyes(d, p, 16, 8 + f, 4, p["a"])


def plant(d, p, f):
    sw = 1 if f else -1
    d.rectangle([15, 16, 17, 30], fill=(60, 120, 50, 255))
    d.ellipse([7, 20 + sw, 15, 25 + sw], fill=(70, 150, 60, 255)); d.ellipse([17, 21 - sw, 25, 26 - sw], fill=(70, 150, 60, 255))
    for ang in range(8):
        dx = [0, 5, 7, 5, 0, -5, -7, -5][ang]; dy = [-7, -5, 0, 5, 7, 5, 0, -5][ang]
        d.ellipse([16 + dx - 4, 10 + dy - 4 + sw, 16 + dx + 4, 10 + dy + 4 + sw], fill=p["a"])
    d.ellipse([10, 4 + sw, 22, 16 + sw], fill=p["b"])
    d.rectangle([12, 10 + sw, 20, 12 + sw], fill=p["k"])
    d.point([(13, 11 + sw), (15, 11 + sw), (17, 11 + sw), (19, 11 + sw)], fill=p["w"])


def reaper(d, p, f):
    fl = 1 if f else 0
    d.polygon([(16, 3), (26, 14), (27, 31), (5, 31), (6, 14)], fill=p["b"])
    d.ellipse([10, 4, 22, 16], fill=p["d"])
    d.ellipse([12, 7, 20, 15], fill=p["k"])
    eyes(d, p, 16, 10, 4, p["a"])
    d.line([(27, 2), (27, 31)], fill=(140, 110, 80, 255), width=1)
    d.polygon([(27, 2 + fl), (16, 1 + fl), (12, 5 + fl), (20, 4 + fl)], fill=(210, 215, 225, 255))
    for x in range(6, 27, 3):
        d.point((x, 31 - (fl if x % 2 else 0)), fill=(0, 0, 0, 0))


def jelly(d, p, f):
    w = 1 if f else 0
    d.ellipse([6, 4, 26, 20], fill=p["b"])
    d.ellipse([9, 6, 16, 12], fill=p["l"])
    for i, x in enumerate(range(8, 26, 3)):
        off = w if i % 2 else -w
        d.line([(x, 18), (x + off, 24), (x - off, 30)], fill=p["a"])
    eyes(d, p, 16, 12, 5, p["k"])


def caster(d, p, f):
    bob = f
    d.polygon([(16, 12 + bob), (26, 31), (6, 31)], fill=p["b"])
    d.ellipse([11, 7 + bob, 21, 17 + bob], fill=(236, 200, 170, 255))
    d.polygon([(9, 9 + bob), (23, 9 + bob), (16, 0 + bob)], fill=p["d"])
    eyes(d, p, 16, 11 + bob, 4, p["k"])
    d.line([(26, 6), (26, 30)], fill=(140, 100, 60, 255), width=1)
    d.ellipse([24, 3 - bob, 28, 7 - bob], fill=p["a"])


def knight(d, p, f):
    humanoid(d, p, f, p["b"], p["b"])
    d.rectangle([12, 8 + f, 20, 9 + f], fill=p["k"])
    d.polygon([(16, 2 + f), (14, 5 + f), (18, 5 + f)], fill=p["a"])
    d.rectangle([4, 14, 9, 24], fill=p["a"]); d.rectangle([5, 15, 8, 23], fill=p["d"])
    d.line([(25, 26), (25, 6 + 2 * f)], fill=(220, 225, 235, 255), width=2)
    d.rectangle([23, 22, 27, 23], fill=p["d"])


def dragon(d, p, f):
    fl = -3 if f else 1
    d.polygon([(14, 14), (4, 6 + fl), (10, 18)], fill=p["d"]); d.polygon([(20, 14), (30, 6 + fl), (24, 18)], fill=p["d"])
    d.ellipse([9, 12, 25, 26], fill=p["b"])
    d.ellipse([12, 16, 22, 26], fill=p["l"])
    d.ellipse([11, 3, 23, 14], fill=p["b"])
    d.polygon([(12, 5), (10, 0), (15, 4)], fill=p["a"]); d.polygon([(20, 4), (22, 0), (22, 6)], fill=p["a"])
    eyes(d, p, 17, 7, 5, p["e"])
    d.rectangle([14, 11, 20, 12], fill=p["d"])
    d.line([(24, 24), (30, 30)], fill=p["b"], width=2)


def fish(d, p, f):
    t = 2 if f else -2
    d.ellipse([4, 9, 24, 23], fill=p["b"])
    d.polygon([(22, 16), (30, 9 + t), (30, 23 - t)], fill=p["d"])
    d.polygon([(10, 10), (16, 4), (18, 11)], fill=p["a"])
    d.ellipse([7, 12, 12, 17], fill=p["w"]); d.point((9, 14), fill=p["k"])
    for x in range(12, 22, 3):
        d.arc([x, 13, x + 4, 19], 270, 90, fill=p["d"])
    d.rectangle([12, 22, 14, 30], fill=p["d"]); d.rectangle([17, 22, 19, 30 - f], fill=p["d"])


def demon(d, p, f):
    humanoid(d, p, f, p["b"], p["b"])
    d.polygon([(11, 7 + f), (8, 0 + f), (13, 5 + f)], fill=p["a"])
    d.polygon([(21, 7 + f), (24, 0 + f), (19, 5 + f)], fill=p["a"])
    eyes(d, p, 16, 8 + f, 4, p["e"])
    d.polygon([(7, 14), (1, 8 - f), (3, 20)], fill=p["d"]); d.polygon([(25, 14), (31, 8 - f), (29, 20)], fill=p["d"])
    d.line([(20, 26), (26, 30), (28, 27)], fill=p["d"])


def angel(d, p, f):
    fl = -2 if f else 1
    d.ellipse([1, 8 + fl, 12, 22], fill=(250, 250, 255, 255)); d.ellipse([20, 8 + fl, 31, 22], fill=(250, 250, 255, 255))
    d.polygon([(16, 12), (24, 30), (8, 30)], fill=p["b"])
    d.ellipse([11, 5, 21, 15], fill=(240, 205, 170, 255))
    d.ellipse([10, 1, 22, 5], outline=p["a"])
    eyes(d, p, 16, 9, 4, p["k"])


def obj(d, p, f):
    bob = f
    d.rectangle([7, 10 + bob, 25, 28 + bob], fill=p["b"])
    d.rectangle([7, 10 + bob, 25, 13 + bob], fill=p["l"])
    d.rectangle([7, 18 + bob, 25, 19 + bob], fill=p["d"])
    d.rectangle([14, 16 + bob, 18, 21 + bob], fill=p["a"])
    eyes(d, p, 16, 23 + bob, 8, p["e"])
    d.polygon([(9, 25 + bob), (12, 23 + bob), (15, 25 + bob), (18, 23 + bob), (21, 25 + bob), (24, 23 + bob)], fill=p["w"])


def critter(d, p, f):
    st = 2 if f else 0
    d.ellipse([8, 11, 26, 27], fill=p["b"])
    d.ellipse([6, 5, 16, 15], fill=p["b"])
    d.polygon([(8, 5), (10, 1), (12, 5)], fill=p["a"])
    d.polygon([(4, 10), (0, 11), (4, 12)], fill=(250, 190, 60, 255))
    d.point((9, 9), fill=p["k"])
    d.polygon([(24, 14), (30, 10), (28, 18)], fill=p["d"])
    d.line([(14, 26), (13, 31 - st)], fill=(250, 190, 60, 255)); d.line([(20, 26), (21, 31 - (2 - st))], fill=(250, 190, 60, 255))


def blob(d, p, f):
    sq = 2 if f else 0
    d.ellipse([5 - sq, 9 + sq, 27 + sq, 31], fill=p["b"])
    d.ellipse([9, 12 + sq, 16, 18 + sq], fill=p["l"])
    eyes(d, p, 16, 19 + sq, 6, p["k"])
    d.arc([12, 21 + sq, 20, 26 + sq], 20, 160, fill=p["a"])


PAINTERS = [bat, zombie, skeleton, ghost, mudman, beast, insect, mummy, plant, reaper,
            jelly, caster, knight, dragon, fish, demon, angel, obj, critter, blob]


def sprite_name(code: str, variant: str) -> str:
    return f"E{code}{variant}"


def crown(img):
    """A small gold crown on top of whatever was painted (boss variant)."""
    bbox = img.getbbox()
    if bbox is None:
        return
    cx = (bbox[0] + bbox[2]) // 2
    top = bbox[1]
    d = ImageDraw.Draw(img)
    gold = (255, 215, 70, 255)
    d.rectangle([cx - 4, top - 1, cx + 4, top + 1], fill=gold)
    for dx in (-4, 0, 4):
        d.polygon([(cx + dx - 1, top - 1), (cx + dx, top - 4), (cx + dx + 1, top - 1)], fill=gold)
    d.point([(cx - 2, top), (cx + 2, top)], fill=(220, 40, 60, 255))


def render(index: int, variant: str, frame: int) -> Image.Image:
    """Frames 0 and 1 are the two poses; 2 and 3 are the same poses hopping one
    pixel up, so the four-frame cycle A C B D bobs as it moves."""
    code, _name, base, accent = ARCHETYPES[index]
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    PAINTERS[index](ImageDraw.Draw(img), palette(base, accent, variant), frame % 2)
    if frame >= 2:
        img = img.transform(img.size, Image.AFFINE, (1, 0, 0, 0, 1, 1))   # shift up 1px
    if variant == "D":
        crown(img)
    return outline(img, BOSS_OUTLINE if variant == "D" else OUTLINE).resize((N * 2, N * 2), Image.NEAREST)


# ---- per-boss art -------------------------------------------------------------
# Every big enemy (BOSS_* and XL*) gets its own sprite BS00..: its archetype
# recoloured with a unique hue and one of five accessories, so no two bosses
# look the same. tools/gen_stages.py decides the archetype (family).

def boss_ids() -> list[tuple[str, int]]:
    import json
    import sys
    sys.path.insert(0, str(ROOT))
    from tools.gen_stages import STAGES, family
    seen: dict[str, str] = {}
    for slug, *_rest in STAGES:
        path = ROOT / f"data/enemies/{slug}-enemies.json"
        if not path.exists():
            continue
        raw = json.loads(path.read_text(encoding="utf-8"))["enemies"]
        for eid, row in (dict(raw) if isinstance(raw, list) else raw).items():
            seen.setdefault(eid, row.get("name", ""))
    return [(eid, family(eid, name)) for eid, name in seen.items() if eid.startswith(("BOSS_", "XL"))]


def accessory(img: Image.Image, ref: Image.Image, kind: int, col, accent) -> None:
    bbox = ref.getbbox()
    if bbox is None:
        return
    x0, y0, x1, y1 = bbox
    cx = (x0 + x1) // 2
    d = ImageDraw.Draw(img)
    bone = (240, 230, 200, 255)
    if kind == 1:      # horns
        d.polygon([(cx - 5, y0 + 2), (cx - 8, y0 - 4), (cx - 3, y0 + 1)], fill=bone)
        d.polygon([(cx + 5, y0 + 2), (cx + 8, y0 - 4), (cx + 3, y0 + 1)], fill=bone)
    elif kind == 2:    # shoulder spikes
        sy = y0 + (y1 - y0) // 3
        d.polygon([(x0 - 1, sy), (x0 - 5, sy - 4), (x0 + 2, sy - 1)], fill=bone)
        d.polygon([(x1, sy), (x1 + 4, sy - 4), (x1 - 3, sy - 1)], fill=bone)
    elif kind == 3:    # orbiting orbs
        for ox, oy in ((x0 - 3, y0 + 4), (x1 + 2, y0 + 8), (cx, y0 - 3)):
            d.ellipse([ox - 1, oy - 1, ox + 1, oy + 1], fill=accent)
    elif kind == 4:    # a dark mantle behind the shoulders (drawn before the body)
        d.polygon([(x0 - 2, y0 + 8), (cx, y0 + 2), (x1 + 2, y0 + 8), (x1 + 1, y1 - 2), (x0, y1 - 2)], fill=shade(col, 0.5))


def render_boss(index: int, family_number: int, frame: int, number: int) -> Image.Image:
    code, _name, base, accent = ARCHETYPES[family_number - 1]
    shift = (number * 0.381966) % 1.0                  # golden-ratio hue spacing
    hue_base = hue(base, shift, 1.15)
    hue_accent = hue(accent, shift + 0.5)
    pal = palette(hue_base[:3], hue_accent[:3], "A")
    body = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    PAINTERS[family_number - 1](ImageDraw.Draw(body), pal, frame % 2)
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    kind = number % 5
    if kind == 4:
        accessory(img, body, kind, hue_base, hue_accent)
    img.alpha_composite(body)
    if kind in (1, 2, 3):
        accessory(img, body, kind, hue_base, hue_accent)
    if frame >= 2:
        img = img.transform(img.size, Image.AFFINE, (1, 0, 0, 0, 1, 1))
    if ids_with_crown[index]:
        crown(img)
    return outline(img, shade(hue_accent, 0.7) if number % 2 else OUTLINE).resize((N * 2, N * 2), Image.NEAREST)


ids_with_crown: list[bool] = []


def write_boss_sprites() -> tuple[list[str], list[str]]:
    bosses = boss_ids()
    ids_with_crown.clear()
    ids_with_crown.extend(eid.startswith("BOSS_") for eid, _f in bosses)
    names = []
    for number, (eid, fam) in enumerate(bosses):
        name = f"BS{number:02d}"
        names.append(name)
        for frame, letter in enumerate("ABCD"):
            img = render_boss(number, fam, frame, number)
            path = SPRITES / f"{name}{letter}0.png"
            img.save(path, optimize=True)
            add_grab(path, N, N * 2)
    return [eid for eid, _f in bosses], names


def main() -> None:
    SPRITES.mkdir(parents=True, exist_ok=True)
    boss_id_list, boss_names = write_boss_sprites()
    names = []
    for i, (code, _name, _b, _a) in enumerate(ARCHETYPES):
        for v in VARIANTS:
            name = sprite_name(code, v)
            names.append(name)
            for frame, letter in enumerate("ABCD"):
                img = render(i, v, frame)
                path = SPRITES / f"{name}{letter}0.png"
                img.save(path, optimize=True)
                # Sprite origin at the bottom centre (PNG grAb chunk).
                add_grab(path, N, N * 2)
    lines = [
        "// GENERATED by tools/art/enemy_art.py. Do not edit.",
        "// Enemy sprite names per archetype (DSStage.Family, 1-based) and",
        "// colour variant (DSStage.Variant: 0 normal, 1 elite, 2 special, 3 boss).",
        "// Presentation only.",
        "class DSEnemyArt",
        "{",
        f"    const ARCHETYPE_COUNT = {len(ARCHETYPES)};",
        "    static const String SPRITES[] = { " + ", ".join(f'"{n}"' for n in names) + " };",
        "    // Per-boss art: a sprite for every BOSS_* / XL* enemy id (empty if none).",
        "    static const String BOSS_IDS[] = { " + ", ".join(f'"{b}"' for b in boss_id_list) + " };",
        "    static const String BOSS_SPRITES[] = { " + ", ".join(f'"{b}"' for b in boss_names) + " };",
        "    static String BossSprite(String id)",
        "    {",
        "        for (int i = 0; i < DSEnemyArt.BOSS_IDS.Size(); i++)",
        "            if (DSEnemyArt.BOSS_IDS[i] == id) return DSEnemyArt.BOSS_SPRITES[i];",
        "        return \"\";",
        "    }",
        "    static String SpriteFor(int family, int variant)",
        "    {",
        f"        if (family < 1 || family > {len(ARCHETYPES)}) family = 1;",
        "        variant = clamp(variant, 0, 3);",
        "        return DSEnemyArt.SPRITES[(family - 1) * 4 + variant];",
        "    }",
        "}",
        "",
        "// Never spawned: its states register every enemy sprite name so",
        "// GetSpriteIndex can find them at runtime.",
        "class DSEnemyArtRegistry : Actor",
        "{",
        "    States",
        "    {",
        "    Spawn:",
    ]
    for n in names + boss_names:
        lines.append(f"        {n} ABCD 1;")
    lines += ["        Stop;", "    }", "}", ""]
    ZSCRIPT.parent.mkdir(parents=True, exist_ok=True)
    ZSCRIPT.write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {len(names) * 2} enemy sprites and {ZSCRIPT.relative_to(ROOT)}")


def add_grab(path: Path, gx: int, gy: int) -> None:
    """Insert a grAb chunk (sprite offset) after IHDR."""
    import struct
    import zlib
    data = path.read_bytes()
    if b"grAb" in data:
        return
    payload = struct.pack(">ii", gx, gy)
    chunk = struct.pack(">I", len(payload)) + b"grAb" + payload
    chunk += struct.pack(">I", zlib.crc32(b"grAb" + payload) & 0xFFFFFFFF)
    ihdr_end = 8 + 8 + 13 + 4
    path.write_bytes(data[:ihdr_end] + chunk + data[ihdr_end:])


if __name__ == "__main__":
    main()
