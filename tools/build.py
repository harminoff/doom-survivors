"""Build the original P003 room and standalone package using only stdlib."""
from __future__ import annotations

import argparse
import json
import shutil
import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.package.build_package import build_package
from tools.assetpipe.build_representative import build as build_representative
from tools.art.themes import THEMES, THEME_FOR_MAP, tex_name, sky_name
from tools.dungeon_udmf import dungeon_blocks

# Original diagnostic compatibility images for the engine's built-in menu parser.
# These are generated pixels, never Doom assets. The active menu is text-based.
MENU_ALIASES = ("M_SKULL1", "M_SKULL2", "M_DOOM", "M_NGAME", "M_OPTION", "M_LOADG", "M_SAVEG", "M_QUITG", "M_EPISOD", "M_NEWG", "M_SKILL")
MENU_ALIASES += ("brdr_tl", "brdr_t", "brdr_tr", "brdr_l", "brdr_r", "brdr_bl", "brdr_b", "brdr_br")


def png(width: int, height: int, pixel, grab: tuple[int, int] | None = None) -> bytes:
    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    raw = b"".join(b"\0" + bytes(c for x in range(width) for c in pixel(x, y)) for y in range(height))
    chunks = [chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))]
    if grab is not None:
        chunks.append(chunk(b"grAb", struct.pack(">ii", *grab)))
    chunks.extend((chunk(b"IDAT", zlib.compress(raw, 9)), chunk(b"IEND", b"")))
    return b"\x89PNG\r\n\x1a\n" + b"".join(chunks)


def png_rgba(width: int, height: int, pixel, grab: tuple[int, int] | None = None) -> bytes:
    """Encode a diagnostic sprite with transparent pixels outside its glyph."""
    raw = b"".join(
        b"\0" + bytes(channel for x in range(width) for channel in pixel(x, y))
        for y in range(height)
    )
    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    chunks = [chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))]
    if grab is not None:
        chunks.append(chunk(b"grAb", struct.pack(">ii", *grab)))
    chunks.extend((chunk(b"IDAT", zlib.compress(raw, 9)), chunk(b"IEND", b"")))
    return b"\x89PNG\r\n\x1a\n" + b"".join(chunks)


def signed_area(polygon) -> float:
    return sum(x1 * y2 - x2 * y1 for (x1, y1), (x2, y2) in zip(polygon, polygon[1:] + polygon[:1])) / 2.0


def themed_map_blocks(spec: dict, theme: tuple) -> list[str]:
    """Stage map with theme textures (tools/art/texture_art.py): the room
    boundary is a one-sided wall; the landmark and every obstacle is a
    raised solid block (its own sector) with side and top textures."""
    floor, wall, side, top, sky, height = theme
    blocks = ['namespace = "zdoom";']
    # Outdoor stages get a painted sky texture tiled on a high ceiling (the
    # engine sky renders black in this standalone setup).
    # Panorama-walled outdoor stages get a low sky ceiling (a real engine sky,
    # see ZMAPINFO sky1) so the walls read as a distant horizon, not a room.
    pano = wall.startswith("pn_")
    ceiling_height = spec["ceiling"]
    loops = [spec["room"], spec["landmark"]] + list(spec.get("obstacles", []))
    patches = list(spec.get("patches", []))
    for polygon in loops + [p["polygon"] for p in patches]:
        for x, y in polygon:
            blocks.append(f"vertex {{ x = {x}; y = {y}; }}")
    ceiling_texture = "F_SKY1" if spec.get("sky") else tex_name(top)
    blocks.append(f'sector {{ heightfloor = {spec["floor"]}; heightceiling = {ceiling_height}; '
                  f'texturefloor = "{tex_name(floor)}"; textureceiling = "{ceiling_texture}"; lightlevel = {spec["light"]}; }}')
    base = 0; sidedef = 0
    for index, polygon in enumerate(loops):
        count = len(polygon)
        if index == 0:
            for n in range(count):
                # A "pn_" wall is a distant panorama (texture_art.panorama)
                # stretched over the whole boundary wall.
                scale = f" scalex_mid = 0.25; scaley_mid = {256.0 / ceiling_height:.5f};" if pano else ""
                # A panorama wall matches the sky's horizon colour so it blends in.
                middle = tex_name(wall)
                blocks.append(f'sidedef {{ sector = 0; texturemiddle = "{middle}";{scale} }}')
                # The front (right-hand) side must face into the room, or the
                # wall is back-face culled and the boundary renders as a
                # black void: a counter-clockwise loop needs reversed lines.
                a, b = base + n, base + (n + 1) % count
                if signed_area(polygon) > 0:
                    a, b = b, a
                blocks.append(f"linedef {{ v1 = {a}; v2 = {b}; sidefront = {sidedef}; blocking = true; }}")
                sidedef += 1
        else:
            sector = index  # sector 0 is the floor; one sector per block
            blocks.append(f'sector {{ heightfloor = {spec["floor"] + height}; heightceiling = {ceiling_height}; '
                          f'texturefloor = "{tex_name(top)}"; textureceiling = "{ceiling_texture}"; lightlevel = {spec["light"]}; }}')
            # The right-hand side of a counter-clockwise loop is outside.
            outside_front = signed_area(polygon) > 0
            for n in range(count):
                outer = f'sidedef {{ sector = 0; texturebottom = "{tex_name(side)}"; }}'
                inner = f"sidedef {{ sector = {sector}; }}"
                blocks.append(outer if outside_front else inner)
                blocks.append(inner if outside_front else outer)
                blocks.append(f"linedef {{ v1 = {base + n}; v2 = {base + (n + 1) % count}; "
                              f"sidefront = {sidedef}; sideback = {sidedef + 1}; twosided = true; blocking = true; }}")
                sidedef += 2
        base += count
    # Floor patches (paths, ponds): extra sectors at floor height with their
    # own floor texture. Paths are walkable; ponds set "blocking".
    for number, patch in enumerate(patches):
        polygon = patch["polygon"]
        count = len(polygon)
        sector = len(loops) + number
        blocks.append(f'sector {{ heightfloor = {spec["floor"]}; heightceiling = {ceiling_height}; '
                      f'texturefloor = "{tex_name(patch["floor"])}"; textureceiling = "{ceiling_texture}"; lightlevel = {spec["light"]}; }}')
        outside_front = signed_area(polygon) > 0
        blocking = "true" if patch.get("blocking") else "false"
        for n in range(count):
            outer = "sidedef { sector = 0; }"
            inner = f"sidedef {{ sector = {sector}; }}"
            blocks.append(outer if outside_front else inner)
            blocks.append(inner if outside_front else outer)
            blocks.append(f"linedef {{ v1 = {base + n}; v2 = {base + (n + 1) % count}; "
                          f"sidefront = {sidedef}; sideback = {sidedef + 1}; twosided = true; blocking = {blocking}; }}")
            sidedef += 2
        base += count
    return blocks


def map_wad(spec: dict) -> bytes:
    theme = THEMES.get(THEME_FOR_MAP.get(spec.get("map_name", "")))
    # The Depths: grid dungeon geometry (tools/gen_dungeon.py, tools/dungeon_udmf.py).
    if spec.get("dungeon"):
        theme = True
        blocks = dungeon_blocks(spec)
    else:
        blocks = themed_map_blocks(spec, theme) if theme else ['namespace = "zdoom";']
    # Closed blocking loops: the room boundary, the legacy landmark, and any
    # optional extra obstacles (e.g. stage trees). Rooms without "obstacles"
    # produce exactly the same TEXTMAP as before.
    loops = [] if theme else [(spec["room"], "DSWALL"), (spec["landmark"], "DSLAMP")]
    loops += [] if theme else [(polygon, "DSLAMP") for polygon in spec.get("obstacles", [])]
    base = 0
    for polygon, _ in loops:
        for x, y in polygon:
            blocks.append(f"vertex {{ x = {x}; y = {y}; }}")
    sidedef = 0
    for polygon, texture in loops:
        count = len(polygon)
        for n in range(count):
            blocks.append(f'sidedef {{ sector = 0; texturemiddle = "{texture}"; }}')
            blocks.append(f"linedef {{ v1 = {base + n}; v2 = {base + (n + 1) % count}; sidefront = {sidedef}; blocking = true; }}")
            sidedef += 1
        base += count
    ceiling_texture = "F_SKY1" if spec.get("sky") else "DSCEIL"
    if not theme:
        blocks.append(f'sector {{ heightfloor = {spec["floor"]}; heightceiling = {spec["ceiling"]}; texturefloor = "DSFLOOR"; textureceiling = "{ceiling_texture}"; lightlevel = {spec["light"]}; }}')
    player = spec["player"]
    blocks.append(f'thing {{ x = {player["x"]}; y = {player["y"]}; angle = {player["angle"]}; type = 1; skill1 = true; skill2 = true; skill3 = true; skill4 = true; skill5 = true; single = true; coop = true; dm = true; }}')
    if spec.get("presentation_fixture_ownership") != "ADAPTER_WORLD_LOADED":
        for fixture in spec.get("presentation_fixtures", []):
            blocks.append(
                f'thing {{ x = {fixture["x"]}; y = {fixture["y"]}; height = {fixture.get("z", 0)}; '
                f'angle = {fixture.get("angle", 0)}; type = {fixture["type"]}; '
                'skill1 = true; skill2 = true; skill3 = true; skill4 = true; skill5 = true; '
                'single = true; coop = true; dm = true; }'
            )
    for prop in spec.get("decor", []):
        blocks.append(f'thing {{ x = {prop["x"]}; y = {prop["y"]}; angle = 0; type = {prop["type"]}; '
                      'skill1 = true; skill2 = true; skill3 = true; skill4 = true; skill5 = true; '
                      'single = true; coop = true; dm = true; }')
    map_name = spec.get("map_name", "MAP01").encode("ascii")
    lumps = [(map_name, b""), (b"TEXTMAP", ("\n".join(blocks) + "\n").encode()), (b"ENDMAP", b"")]
    payload = bytearray()
    directory = bytearray()
    for name, data in lumps:
        directory += struct.pack("<II8s", 12 + len(payload), len(data), name)
        payload += data
    return struct.pack("<4sII", b"PWAD", len(lumps), 12 + len(payload)) + payload + directory


def build(root: Path, fault: str = "none", room_spec: Path | None = None,
          additional_room_specs: tuple[Path, ...] = ()) -> dict:
    # Separate staging per fault; source input files are never fault-injected.
    asset_manifest = build_representative(root)
    requested_rooms = (room_spec if room_spec is not None else root / "maps/source/boot-probe/room.json",) + additional_room_specs
    specs: dict[str, dict] = {}
    for requested_room in requested_rooms:
        spec_path = requested_room if requested_room.is_absolute() else root / requested_room
        spec = json.loads(spec_path.read_text())
        map_name = spec.get("map_name", "MAP01")
        if map_name not in {"MAP01", "MAP02", "MAP03", "MAP04", "MAP05", "MAP06", "MAP07", "MAP08", "MAP09", "MAP10", "MAP11", "MAP12", "MAP13", "MAP14", "MAP15", "MAP16", "MAP17", "MAP18", "MAP19", "MAP20", "MAP21", "MAP22", "MAP23", "MAP24", "MAP25", "MAP26", "MAP27", "MAP28", "MAP30", "MAP31", "MAP32", "MAP33", "MAP34", "MAP35", "MAP36", "MAP37", "MAP38", "MAP39", "MAP40", "MAP41", "MAP42", "MAP43", "MAP44", "MAP45", "MAP46", "MAP47", "MAP48", "MAP49", "MAP50", "MAP51", "MAP52", "MAP53"}:
            raise ValueError(f"unsupported generated map name: {map_name}")
        if map_name in specs:
            raise ValueError(f"duplicate generated map name: {map_name}")
        specs[map_name] = spec
    map_name = next(iter(specs))
    staging = root / "build" / f"resources-{fault}"
    staging.mkdir(parents=True, exist_ok=True)
    # A phase-specific room may use MAP02 while the canonical package normally
    # uses MAP01. Remove the other generated map lump before stale-resource
    # validation so sequential focused builds cannot carry a prior map over.
    for stale_map in ("MAP01", "MAP02", "MAP03", "MAP04", "MAP05", "MAP06", "MAP07", "MAP08", "MAP09", "MAP10", "MAP11", "MAP12", "MAP13", "MAP14", "MAP15", "MAP16", "MAP17", "MAP18", "MAP19", "MAP20", "MAP21", "MAP22", "MAP23", "MAP24", "MAP25", "MAP26", "MAP27", "MAP28"):
        if stale_map not in specs:
            (staging / f"maps/{stale_map}.wad").unlink(missing_ok=True)
    resources = root / "src/resources"
    expected = {p.relative_to(resources).as_posix() for p in resources.rglob("*") if p.is_file()}
    zscript_root = root / "src/zscript"
    zscript_sources = [p for p in zscript_root.rglob("*") if p.is_file()]
    generated = {"PLAYPAL", "graphics/DSTITLE.png"} | {f"maps/{name}.wad" for name in specs} | {f"textures/{n}.png" for n in ("DSWALL", "DSFLOOR", "DSCEIL", "DSLAMP", "F_SKY1")}
    generated |= {f"code/{p.relative_to(zscript_root).as_posix()}" for p in zscript_sources}
    generated |= {f"sprites/{n}.png" for n in ("BILLA0", "PROPA0", "PICKA0", "ITEMA0", "BRAZA0")}
    asset_copies = []
    for asset in asset_manifest["assets"]:
        for output in asset["outputs"]:
            source_relative = Path(output["path"])
            if source_relative.parts[1] == "sprites":
                package_relative = Path("sprites") / source_relative.name
            elif source_relative.parts[1] == "textures":
                package_relative = Path("textures") / source_relative.name
            elif source_relative.parts[1] == "ui":
                package_relative = Path("graphics") / source_relative.name
            else:
                raise ValueError(f"unsupported generated asset path: {source_relative}")
            generated.add(package_relative.as_posix())
            asset_copies.append((root / source_relative, staging / package_relative))
    generated |= {f"graphics/{n}.png" for n in MENU_ALIASES}
    for existing in staging.rglob("*"):
        if existing.is_file() and existing.relative_to(staging).as_posix() not in expected | generated:
            raise ValueError(f"Unexpected stale staging resource: {existing}")
    for source in resources.rglob("*"):
        if source.is_file():
            target = staging / source.relative_to(resources)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
    for source in zscript_sources:
        target = staging / "code" / source.relative_to(zscript_root)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
    for source, target in asset_copies:
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
    (staging / "maps").mkdir(exist_ok=True)
    for name, spec in specs.items():
        (staging / f"maps/{name}.wad").write_bytes(map_wad(spec))
    (staging / "PLAYPAL").write_bytes(bytes(c for n in range(256) for c in (n, n, n)))
    textures = {
        "DSWALL": lambda x, y: (33, 44, 57) if x % 32 > 1 and y % 16 > 1 else (12, 19, 27),
        "DSFLOOR": lambda x, y: (45, 55, 61) if ((x // 16 + y // 16) % 2) else (29, 37, 44),
        "DSCEIL": lambda x, y: (20, 27, 35),
        "F_SKY1": lambda x, y: (20, 27, 35),
        "DSLAMP": lambda x, y: (73, 219, 170) if 5 < x % 32 < 27 else (18, 54, 53),
    }
    (staging / "textures").mkdir(exist_ok=True)
    for name, pixel in textures.items():
        (staging / "textures" / f"{name}.png").write_bytes(png(64, 64, pixel))
    (staging / "graphics").mkdir(exist_ok=True)
    (staging / "sprites").mkdir(exist_ok=True)
    (staging / "graphics/DSTITLE.png").write_bytes(png(320, 200, lambda x,y: (15, 29, 35)))
    def bill_sprite(x: int, y: int) -> tuple[int, int, int, int]:
        # A compact bat-like silhouette keeps the close billboard readable
        # while making the diagnostic canvas transparent outside the glyph.
        dx, dy = x - 32, y - 48
        body = (dx / 13.0) ** 2 + (dy / 30.0) ** 2 <= 1.0
        wing_height = 22 <= y <= 70
        wing_span = max(0, 30 - abs(y - 46) // 2)
        wing = wing_height and abs(dx) <= wing_span and abs(dx) >= 9
        eye = 26 <= x <= 38 and 28 <= y <= 34
        if wing or body:
            return (236, 186, 72, 255) if wing else (116, 72, 45, 255)
        if eye:
            return (255, 239, 171, 255)
        return (0, 0, 0, 0)

    def prop_sprite(x: int, y: int) -> tuple[int, int, int, int]:
        # Whip proxies use PROP with additive blending.  Keep a bright slash
        # core and a short translucent-looking tail, with no opaque backdrop.
        dx, dy = x - 36, y - 48
        slash_width = max(2, 13 - abs(dy) // 5)
        if abs(dx - dy // 3) <= slash_width:
            return (255, 213, 74, 255)
        if abs(dx - dy // 3) <= slash_width + 3 and abs(dy) < 34:
            return (204, 93, 75, 150)
        return (0, 0, 0, 0)

    def pickup_sprite(x: int, y: int) -> tuple[int, int, int, int]:
        # Foot pickups remain additive but only the gem silhouette contributes.
        if abs(x - 16) * 7 + abs(y - 8) * 12 <= 84:
            return (93, 233, 181, 255)
        if abs(x - 16) <= 2 and abs(y - 8) <= 5:
            return (205, 255, 232, 255)
        return (0, 0, 0, 0)

    (staging / "sprites/BILLA0.png").write_bytes(png_rgba(64, 96, bill_sprite, grab=(32, 96)))
    (staging / "sprites/PROPA0.png").write_bytes(png_rgba(72, 96, prop_sprite, grab=(36, 96)))
    (staging / "sprites/PICKA0.png").write_bytes(png_rgba(32, 16, pickup_sprite, grab=(16, 16)))

    def item_sprite(x: int, y: int) -> tuple[int, int, int, int]:
        # Floor items: a white disc with a dark rim, tinted per item at runtime.
        d = (x - 12) ** 2 + (y - 12) ** 2
        if d <= 81:
            return (255, 255, 255, 255)
        if d <= 121:
            return (60, 60, 60, 255)
        return (0, 0, 0, 0)

    def brazier_sprite(x: int, y: int) -> tuple[int, int, int, int]:
        # Light source: a stone bowl on a post with a flame on top.
        if 14 <= x <= 18 and 34 <= y <= 48:
            return (90, 80, 70, 255)
        if 26 <= y <= 34 and abs(x - 16) <= 11 - (y - 26) // 2:
            return (140, 120, 100, 255)
        if y < 26 and abs(x - 16) * 26 <= (y - 2) * 9:
            return (255, 210, 80, 255) if abs(x - 16) * 26 <= (y - 2) * 4 else (240, 110, 30, 255)
        return (0, 0, 0, 0)

    (staging / "sprites/ITEMA0.png").write_bytes(png_rgba(24, 24, item_sprite, grab=(12, 24)))
    (staging / "sprites/BRAZA0.png").write_bytes(png_rgba(32, 48, brazier_sprite, grab=(16, 48)))
    for alias in MENU_ALIASES:
        (staging / "graphics" / f"{alias}.png").write_bytes(png(8, 8, lambda x,y: (73, 219, 170) if x == y else (15, 29, 35)))
    script_path = staging / "code/Diagnostic.zs"
    script = script_path.read_text()
    if fault == "compile":
        script += "\nclass DSBroken : DefinitelyMissingClass {}\n"
    elif fault == "assertion":
        script = script.replace('Console.Printf("DS_RUNTIME_COMPLETE', 'Console.Printf("DS_ASSERT_FAIL injected_runtime_assertion')
    elif fault == "timeout":
        script = script.replace("observedTics == 70", "observedTics == 2147483647")
    elif fault == "resource":
        (staging / f"maps/{map_name}.wad").unlink()  # Owned generated fault fixture only.
    script_path.write_text(script, encoding="utf-8", newline="\n")
    output = root / "build" / ("doom-survivors.ipk3" if fault == "none" else f"fault-{fault}.ipk3")
    result = build_package(staging, output)
    result.update({"package": str(output), "fault": fault, "classification": "P003 engineering fixture"})
    (root / "build" / f"manifest-{fault}.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fault", choices=["none", "compile", "resource", "assertion", "timeout"], default="none")
    parser.add_argument("--room-spec", type=Path, help="optional diagnostic room JSON for a phase-specific probe")
    parser.add_argument("--stages", action="store_true",
                        help="build every playable stage map (Mad Forest first, then the others)")
    parser.add_argument("--additional-room-spec", type=Path, action="append", default=[],
                        help="additional generated room JSON to package alongside --room-spec")
    options = parser.parse_args()
    if options.stages:
        stage_dirs = ("mad-forest", "inlaid-library", "dairy-plant", "gallo-tower", "cappella-magna",
                      "green-acres", "bone-zone", "il-molise", "moongolow", "boss-rash",
                      "whiteout", "lycaeum", "the-coop", "space-54", "laborratory", "westwoods", "bat-country", "astral-stair", "mazerella", "tiny-bridge", "carlo-cart", "room-1665", "holy-forbidden", "eudaimonia-machine", "the-depths")
        specs = [ROOT / f"maps/source/{d}/room.json" for d in stage_dirs if (ROOT / f"maps/source/{d}/room.json").exists()]
        options.room_spec = specs[0]
        options.additional_room_spec = specs[1:] + list(options.additional_room_spec)
    print(json.dumps(build(ROOT, options.fault, options.room_spec,
                           tuple(options.additional_room_spec)), indent=2))
