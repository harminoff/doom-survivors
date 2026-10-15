"""Generate the UI kit: two pixel fonts and the panel/bar/slot/icon textures.

Original pixel art in a Doom-ish style: gunmetal bevelled frames with
rivets, a hellfire (orange) focus state, blood-red and XP-blue bar fills.

Fonts are written as UZDoom font folders, which replace the engine's
fallback SmallFont and BigFont everywhere:
  src/resources/fonts/smallfont/<hex>.png   5x7 glyphs with a 1px outline
  src/resources/fonts/bigfont/<hex>.png     the same glyphs at 2x, bevelled
Glyphs are greyscale so the engine's text colours (Font.CR_*) tint them.

Textures go to src/resources/graphics/DSUI*.png and DSIC*.png; the HUD and
menus draw the frames as 9-slices (src/zscript/ui/shell/UiKit.zs).
Run: python tools/art/ui_art.py
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
RES = ROOT / "src/resources"
GFX = RES / "graphics"

# ---- glyphs ---------------------------------------------------------------
# Seven rows (cap height 7, baseline under row 6); DESC adds two rows below
# the baseline for descenders.
G: dict[str, list[str]] = {
    "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
    "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
    "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
    "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"],
    "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "I": ["###", ".#.", ".#.", ".#.", ".#.", ".#.", "###"],
    "J": ["..###", "...#.", "...#.", "...#.", "#..#.", "#..#.", ".##.."],
    "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
    "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
    "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
    "N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
    "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
    "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
    "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
    "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "V": ["#...#", "#...#", "#...#", ".#.#.", ".#.#.", "..#..", "..#.."],
    "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
    "X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
    "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
    "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
    "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
    "1": [".#.", "##.", ".#.", ".#.", ".#.", ".#.", "###"],
    "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
    "3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
    "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
    "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
    "6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
    "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
    "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
    "9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
    "a": [".....", ".....", ".###.", "....#", ".####", "#...#", ".####"],
    "b": ["#....", "#....", "####.", "#...#", "#...#", "#...#", "####."],
    "c": ["....", "....", ".###", "#...", "#...", "#...", ".###"],
    "d": ["....#", "....#", ".####", "#...#", "#...#", "#...#", ".####"],
    "e": [".....", ".....", ".###.", "#...#", "#####", "#....", ".###."],
    "f": [".##", "#..", "###", "#..", "#..", "#..", "#.."],
    "g": [".....", ".....", ".####", "#...#", "#...#", ".####", "....#"],
    "h": ["#....", "#....", "####.", "#...#", "#...#", "#...#", "#...#"],
    "i": ["#", ".", "#", "#", "#", "#", "#"],
    "j": ["..#", "...", "..#", "..#", "..#", "..#", "..#"],
    "k": ["#...", "#...", "#..#", "#.#.", "##..", "#.#.", "#..#"],
    "l": ["#.", "#.", "#.", "#.", "#.", "#.", ".#"],
    "m": [".....", ".....", "##.#.", "#.#.#", "#.#.#", "#.#.#", "#.#.#"],
    "n": [".....", ".....", "####.", "#...#", "#...#", "#...#", "#...#"],
    "o": [".....", ".....", ".###.", "#...#", "#...#", "#...#", ".###."],
    "p": [".....", ".....", "####.", "#...#", "#...#", "####.", "#...."],
    "q": [".....", ".....", ".####", "#...#", "#...#", ".####", "....#"],
    "r": ["....", "....", "#.##", "##..", "#...", "#...", "#..."],
    "s": [".....", ".....", ".####", "#....", ".###.", "....#", "####."],
    "t": [".#..", ".#..", "####", ".#..", ".#..", ".#..", "..##"],
    "u": [".....", ".....", "#...#", "#...#", "#...#", "#...#", ".####"],
    "v": [".....", ".....", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
    "w": [".....", ".....", "#...#", "#...#", "#.#.#", "#.#.#", ".#.#."],
    "x": [".....", ".....", "#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
    "y": [".....", ".....", "#...#", "#...#", "#...#", ".####", "....#"],
    "z": [".....", ".....", "#####", "...#.", "..#..", ".#...", "#####"],
    "!": ["#", "#", "#", "#", "#", ".", "#"],
    '"': ["#.#", "#.#", "...", "...", "...", "...", "..."],
    "#": [".#.#.", "#####", ".#.#.", ".#.#.", "#####", ".#.#.", "....."],
    "$": ["..#..", ".####", "#.#..", ".###.", "..#.#", "####.", "..#.."],
    "%": ["##..#", "##..#", "...#.", "..#..", ".#...", "#..##", "#..##"],
    "&": [".##..", "#..#.", "#.#..", ".#...", "#.#.#", "#..#.", ".##.#"],
    "'": ["#", "#", ".", ".", ".", ".", "."],
    "(": [".#", "#.", "#.", "#.", "#.", "#.", ".#"],
    ")": ["#.", ".#", ".#", ".#", ".#", ".#", "#."],
    "*": [".....", "..#..", "#.#.#", ".###.", "#.#.#", "..#..", "....."],
    "+": [".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."],
    ",": ["..", "..", "..", "..", "..", ".#", ".#"],
    "-": ["....", "....", "....", "####", "....", "....", "...."],
    ".": [".", ".", ".", ".", ".", ".", "#"],
    "/": ["....#", "....#", "...#.", "..#..", ".#...", "#....", "#...."],
    ":": [".", ".", "#", ".", ".", "#", "."],
    ";": ["..", "..", ".#", "..", "..", ".#", ".#"],
    "<": ["...#", "..#.", ".#..", "#...", ".#..", "..#.", "...#"],
    "=": ["....", "....", "####", "....", "####", "....", "...."],
    ">": ["#...", ".#..", "..#.", "...#", "..#.", ".#..", "#..."],
    "?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
    "@": [".###.", "#...#", "#.###", "#.#.#", "#.###", "#....", ".###."],
    "[": ["##", "#.", "#.", "#.", "#.", "#.", "##"],
    "\\": ["#....", "#....", ".#...", "..#..", "...#.", "....#", "....#"],
    "]": ["##", ".#", ".#", ".#", ".#", ".#", "##"],
    "^": ["..#..", ".#.#.", "#...#", ".....", ".....", ".....", "....."],
    "_": [".....", ".....", ".....", ".....", ".....", ".....", "#####"],
    "`": ["#.", ".#", "..", "..", "..", "..", ".."],
    "{": [".##", "#..", "#..", "##.", "#..", "#..", ".##"],
    "|": ["#", "#", "#", "#", "#", "#", "#"],
    "}": ["##.", "..#", "..#", ".##", "..#", "..#", "##."],
    "~": [".....", ".....", ".#...", "#.#.#", "...#.", ".....", "....."],
}
DESC = {
    "g": [".###."], "j": ["##."], "p": ["#...."], "q": ["....#"], "y": [".###."],
    ",": ["#."], ";": ["#."],
}


def rows_of(ch: str) -> list[str]:
    rows = list(G[ch]) + list(DESC.get(ch, []))
    width = len(rows[0])
    return rows + ["." * width] * (9 - len(rows))


def outline(body: set[tuple[int, int]], w: int, h: int, shadow: bool) -> set[tuple[int, int]]:
    edge = set()
    for (x, y) in body:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                p = (x + dx, y + dy)
                if p not in body and 0 <= p[0] < w and 0 <= p[1] < h:
                    edge.add(p)
        if shadow and (x + 1, y + 1) not in body and x + 1 < w and y + 1 < h:
            edge.add((x + 1, y + 1))
    return edge


def write_font(folder: Path, scale: int, upper_only: bool, info: str) -> None:
    folder.mkdir(parents=True, exist_ok=True)
    for old in folder.glob("*.png"):
        old.unlink()
    pad = 1
    shadow = scale > 1
    for code in range(33, 127):
        ch = chr(code)
        src = ch.upper() if upper_only and ch.isalpha() else ch
        rows = rows_of(src)
        if upper_only:
            rows = rows[:7]   # capitals only: no descender rows
        gw, gh = len(rows[0]) * scale, len(rows) * scale
        w, h = gw + pad * 2 + (1 if shadow else 0), gh + pad * 2 + (1 if shadow else 0)
        body = {(pad + x * scale + sx, pad + y * scale + sy)
                for y, row in enumerate(rows) for x, c in enumerate(row) if c == "#"
                for sx in range(scale) for sy in range(scale)}
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        px = img.load()
        for p in outline(body, w, h, shadow):
            px[p] = (0, 0, 0, 255)
        top, bottom = pad, pad + (7 * scale if upper_only else 7) - 1
        for (x, y) in body:
            if scale == 1:
                lum = 255 if y < bottom else 205
            else:
                t = (y - top) / max(1, bottom - top)
                lum = int(255 - 115 * t)
                if (x, y - 1) not in body:
                    lum = 255
                elif (x, y + 1) not in body:
                    lum = max(90, lum - 50)
            px[x, y] = (lum, lum, lum, 255)
        img.save(folder / f"{code:04X}.png", optimize=True)
    (folder / "font.inf").write_text(info, encoding="ascii", newline="\n")


# ---- textures -------------------------------------------------------------

BLACK = (0, 0, 0, 255)


def frame(size: int, rings: list[tuple], fill: tuple, rivets: tuple | None = None, gradient: tuple | None = None) -> Image.Image:
    """Concentric rings from the outside in; each ring is (light, dark) for a
    bevel (top/left light, bottom/right dark) or a single colour."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    n = len(rings)
    for y in range(size):
        for x in range(size):
            d = min(x, y, size - 1 - x, size - 1 - y)
            if d < n:
                ring = rings[d]
                if isinstance(ring[0], tuple):
                    light = (x == d or y == d) and x < size - 1 - d and y < size - 1 - d
                    px[x, y] = ring[0] if light else ring[1]
                else:
                    px[x, y] = ring
            else:
                if gradient:
                    t = (y - n) / max(1, size - 2 * n - 1)
                    c = tuple(int(gradient[0][i] + (gradient[1][i] - gradient[0][i]) * t) for i in range(4))
                    px[x, y] = c
                else:
                    px[x, y] = fill
    if rivets:
        light, dark, at = rivets
        for cx, cy in ((at, at), (size - 1 - at - 1, at), (at, size - 1 - at - 1), (size - 1 - at - 1, size - 1 - at - 1)):
            px[cx, cy] = light
            px[cx + 1, cy] = light
            px[cx, cy + 1] = light
            px[cx + 1, cy + 1] = dark
    return img


def gradient_bar(colours: list[tuple]) -> Image.Image:
    img = Image.new("RGBA", (4, len(colours)), (0, 0, 0, 0))
    for y, c in enumerate(colours):
        for x in range(4):
            img.putpixel((x, y), c + (255,) if len(c) == 3 else c)
    return img


def icon(art: list[str], palette: dict[str, tuple]) -> Image.Image:
    img = Image.new("RGBA", (len(art[0]), len(art)), (0, 0, 0, 0))
    for y, row in enumerate(art):
        for x, c in enumerate(row):
            if c in palette:
                img.putpixel((x, y), palette[c])
    return img


SKULL = [
    "...######...",
    "..########..",
    ".##########.",
    ".##########.",
    ".#..##..###.",
    ".#..##..###.",
    ".####..####.",
    "..###..###..",
    "...######...",
    "...#.##.#...",
    "...######...",
    "....####....",
]
COIN = [
    "....####....",
    "..##hhhh##..",
    ".#hhyyyyhh#.",
    ".#hyyyyyyo#.",
    "#hyyy##yyyo#",
    "#hyy#yyyyyo#",
    "#hyy#yyyyyo#",
    "#hyyy##yyyo#",
    ".#yyyyyyoo#.",
    ".#ooyyyooo#.",
    "..##oooo##..",
    "....####....",
]
HEART = [
    "............",
    ".##.....##..",
    "#hh#...#rr#.",
    "#hrr#.#rrrr#",
    "#hrrr#rrrrr#",
    "#rrrrrrrrrd#",
    ".#rrrrrrrd#.",
    "..#rrrrrd#..",
    "...#rrrd#...",
    "....#rd#....",
    ".....##.....",
    "............",
]


def main() -> None:
    small = RES / "fonts/smallfont"
    big = RES / "fonts/bigfont"
    write_font(small, 1, False, "Kerning -1\nSpaceWidth 4\nFontHeight 11\n")
    write_font(big, 2, True, "Kerning -1\nSpaceWidth 8\nFontHeight 17\n")

    GFX.mkdir(parents=True, exist_ok=True)
    metal_hi, metal, metal_lo = (168, 162, 154, 255), (104, 98, 92, 255), (52, 48, 46, 255)
    groove = (24, 20, 20, 255)
    fill = (20, 15, 16, 236)
    # Panels: 32x32, 9-slice border 8.
    frame(32, [BLACK, (metal_hi, metal_lo), metal, metal, (metal_lo, metal_hi), groove,
               (88, 24, 20, 255)], fill, rivets=((210, 204, 196, 255), (40, 36, 34, 255), 2)).save(GFX / "DSUIPNL.png")
    hot_hi, hot, hot_lo = (255, 214, 120, 255), (228, 120, 36, 255), (130, 48, 16, 255)
    frame(32, [BLACK, (hot_hi, hot_lo), hot, hot, (hot_lo, hot_hi), groove,
               (255, 150, 50, 255)], (46, 20, 14, 240), rivets=((255, 240, 190, 255), (90, 30, 10, 255), 2)).save(GFX / "DSUIPNLF.png")
    # Buttons and cards: 16x16, border 4, vertical gradient fill.
    frame(16, [BLACK, (metal_hi, metal_lo), metal, (metal_lo, metal_hi)], fill,
          gradient=((44, 38, 38, 240), (22, 18, 18, 240))).save(GFX / "DSUIBTN.png")
    frame(16, [BLACK, (hot_hi, hot_lo), hot, (hot_lo, hot_hi)], fill,
          gradient=((120, 44, 20, 245), (54, 18, 10, 245))).save(GFX / "DSUIBTNF.png")
    frame(16, [BLACK, ((70, 66, 64, 255), (30, 28, 28, 255)), (46, 42, 42, 255), ((30, 28, 28, 255), (70, 66, 64, 255))], fill,
          gradient=((26, 22, 22, 220), (14, 12, 12, 220))).save(GFX / "DSUIBTND.png")
    # Item slots: 16x16, border 4 (maxed items get the gold one).
    frame(16, [BLACK, (metal_hi, metal_lo), metal, (metal_lo, metal_hi)], (12, 10, 12, 215)).save(GFX / "DSUISLOT.png")
    gold_hi, gold, gold_lo = (255, 240, 150, 255), (220, 170, 40, 255), (120, 80, 10, 255)
    frame(16, [BLACK, (gold_hi, gold_lo), gold, (gold_lo, gold_hi)], (30, 22, 8, 220)).save(GFX / "DSUISLTG.png")
    # Bar track: 12x12, border 3.
    frame(12, [BLACK, ((84, 80, 76, 255), (40, 36, 34, 255)), BLACK], (6, 6, 10, 230)).save(GFX / "DSUIBAR.png")
    gradient_bar([(170, 220, 255), (90, 170, 255), (50, 120, 240), (40, 100, 220), (30, 80, 200), (24, 62, 170), (18, 46, 130), (12, 30, 90)]).save(GFX / "DSUIXP.png")
    gradient_bar([(255, 150, 130), (240, 70, 56), (214, 36, 30), (190, 24, 22), (160, 16, 16), (130, 10, 12), (100, 8, 10), (70, 4, 6)]).save(GFX / "DSUIHP.png")
    gradient_bar([(255, 250, 220), (255, 236, 170), (250, 210, 120), (240, 190, 90), (220, 160, 70), (200, 130, 50), (170, 100, 40), (130, 70, 30)]).save(GFX / "DSUITRL.png")
    skull = icon(SKULL, {"#": (232, 224, 204, 255)})
    outline_icon(skull).save(GFX / "DSICSKL.png")
    outline_icon(icon(COIN, {"#": (60, 36, 4, 255), "h": (255, 244, 170, 255), "y": (250, 200, 50, 255), "o": (190, 120, 20, 255)})).save(GFX / "DSICGLD.png")
    outline_icon(icon(HEART, {"#": (40, 4, 4, 255), "h": (255, 190, 180, 255), "r": (220, 30, 30, 255), "d": (130, 10, 10, 255)})).save(GFX / "DSICHP.png")


def outline_icon(img: Image.Image) -> Image.Image:
    """Add a 1px black outline around opaque pixels (grows the canvas by 2)."""
    w, h = img.size
    out = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    out.paste(img, (1, 1))
    src = out.copy().load()
    px = out.load()
    for y in range(h + 2):
        for x in range(w + 2):
            if src[x, y][3] == 0 and any(
                0 <= x + dx < w + 2 and 0 <= y + dy < h + 2 and src[x + dx, y + dy][3] > 0
                for dx in (-1, 0, 1) for dy in (-1, 0, 1)
            ):
                px[x, y] = (0, 0, 0, 255)
    return out


if __name__ == "__main__":
    main()
