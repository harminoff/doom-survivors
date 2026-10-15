"""Build and validate the seven generated P013 representative assets."""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = Path("assets/manifests/p013-representative.json")
CONTACT_SHEET = Path("generated/contact-sheets/p013-representative.png")

ASSET_SPECS = (
    {"id": "enemy_directional", "kind": "enemy", "outputs": [f"generated/sprites/P13EA{i}.png" for i in range(1, 9)], "width": 48, "height": 64, "pivot": [24, 56], "scale": 1.0, "aliases": ["P13E"], "frame_names": ["A1", "A2", "A3", "A4", "A5", "A6", "A7", "A8"], "frame_tics": 4, "direction_policy": "EIGHT_DIRECTIONAL_SPRITE", "collision_class": "ENGINEERING_ENEMY_BODY_PLACEHOLDER"},
    {"id": "player_identity", "kind": "player", "outputs": ["generated/sprites/P13PA0.png"], "width": 48, "height": 64, "pivot": [24, 60], "scale": 1.0, "aliases": ["P13P"], "frame_names": ["A0"], "frame_tics": -1, "direction_policy": "FRONT_BILLBOARD_PLACEHOLDER", "collision_class": "ENGINEERING_PLAYER_BODY_PLACEHOLDER"},
    {"id": "projectile", "kind": "projectile", "outputs": ["generated/sprites/P13RA0.png"], "width": 16, "height": 16, "pivot": [8, 8], "scale": 1.0, "aliases": ["P13R"], "frame_names": ["A0"], "frame_tics": 1, "direction_policy": "BILLBOARD_PLACEHOLDER", "collision_class": "ENGINEERING_PROJECTILE_PLACEHOLDER"},
    {"id": "ground_aura", "kind": "ground_effect", "outputs": ["generated/textures/P13AURA.png", "generated/sprites/P13AA0.png"], "width": 96, "height": 32, "pivot": [48, 16], "scale": 1.0, "aliases": ["P13AURA", "P13A"], "frame_names": ["A0"], "frame_tics": 2, "direction_policy": "GROUND_ALIGNED_EFFECT", "collision_class": "ENGINEERING_AREA_EFFECT_PLACEHOLDER"},
    {"id": "foot_pickup", "kind": "pickup", "outputs": ["generated/sprites/P13KA0.png"], "width": 24, "height": 16, "pivot": [12, 16], "scale": 1.0, "aliases": ["P13K"], "frame_names": ["A0"], "frame_tics": 4, "direction_policy": "BILLBOARD_PLACEHOLDER", "collision_class": "ENGINEERING_PICKUP_PLACEHOLDER"},
    {"id": "world_prop", "kind": "world_prop", "outputs": ["generated/sprites/P13WA0.png"], "width": 64, "height": 96, "pivot": [32, 96], "scale": 1.0, "aliases": ["P13W"], "frame_names": ["A0"], "frame_tics": -1, "direction_policy": "BILLBOARD_PLACEHOLDER", "collision_class": "ENGINEERING_WORLD_PROP_PLACEHOLDER"},
    {"id": "ui_icon", "kind": "ui", "outputs": ["generated/ui/P13ICON.png"], "width": 32, "height": 32, "pivot": [16, 16], "scale": 1.0, "aliases": ["P13ICON"], "frame_names": ["A0"], "frame_tics": -1, "direction_policy": "SCREEN_ALIGNED_ICON", "collision_class": "ENGINEERING_PRESENTATION_ONLY"},
)


def _chunk(kind: bytes, payload: bytes) -> bytes:
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)


def png(width: int, height: int, pixels: list[tuple[int, int, int, int]], grab: tuple[int, int] | None = None) -> bytes:
    raw = b"".join(b"\0" + bytes(channel for pixel in pixels[row * width:(row + 1) * width] for channel in pixel) for row in range(height))
    chunks = [_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))]
    if grab is not None:
        chunks.append(_chunk(b"grAb", struct.pack(">ii", *grab)))
    chunks.extend((_chunk(b"IDAT", zlib.compress(raw, 9)), _chunk(b"IEND", b"")))
    return b"\x89PNG\r\n\x1a\n" + b"".join(chunks)


def _canvas(width: int, height: int) -> list[tuple[int, int, int, int]]:
    return [(0, 0, 0, 0)] * (width * height)


def _rect(pixels, width, x0, y0, x1, y1, color):
    for y in range(max(0, y0), min(len(pixels) // width, y1)):
        for x in range(max(0, x0), min(width, x1)):
            pixels[y * width + x] = color


def _ellipse(pixels, width, height, cx, cy, rx, ry, color):
    for y in range(height):
        for x in range(width):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1:
                pixels[y * width + x] = color


def _asset_pixels(kind: str, width: int, height: int, frame: int = 0):
    pixels = _canvas(width, height)
    if kind == "enemy":
        _ellipse(pixels, width, height, width // 2, height // 2, 16, 23, (215, 70, 92, 255))
        _rect(pixels, width, 15, 15, 21, 21, (255, 235, 165, 255))
        _rect(pixels, width, 27, 15, 33, 21, (255, 235, 165, 255))
        for i in range(10):
            x = width // 2 + int((frame - 3.5) * 2)
            y = 7 + i * 2
            if 0 <= x < width and 0 <= y < height:
                pixels[y * width + x] = (255, 196, 70, 255)
    elif kind == "player":
        _ellipse(pixels, width, height, width // 2, 30, 15, 18, (76, 163, 232, 255))
        _rect(pixels, width, 16, 12, 32, 20, (255, 220, 124, 255))
        _rect(pixels, width, 19, 26, 23, 30, (20, 30, 55, 255))
        _rect(pixels, width, 25, 26, 29, 30, (20, 30, 55, 255))
    elif kind == "projectile":
        _ellipse(pixels, width, height, width // 2, height // 2, 6, 6, (255, 213, 74, 255))
        _ellipse(pixels, width, height, width // 2, height // 2, 2, 2, (255, 252, 208, 255))
    elif kind == "ground_effect":
        for y in range(height):
            for x in range(width):
                edge = ((x - width / 2) / (width / 2)) ** 2 + ((y - height / 2) / (height / 2)) ** 2
                if 0.55 <= edge <= 1.0:
                    pixels[y * width + x] = (80, 225, 170, 170)
    elif kind == "pickup":
        for y in range(2, height - 2):
            span = max(1, int((1 - abs(y - height / 2) / (height / 2)) * width / 2))
            _rect(pixels, width, width // 2 - span, y, width // 2 + span, y + 1, (112, 242, 190, 255))
    elif kind == "world_prop":
        _rect(pixels, width, 8, 12, width - 8, height - 4, (116, 72, 45, 255))
        _rect(pixels, width, 13, 18, width - 13, height - 10, (196, 108, 58, 255))
        _rect(pixels, width, 20, 28, width - 20, 36, (245, 192, 83, 255))
    elif kind == "ui":
        _ellipse(pixels, width, height, width // 2, height // 2, 13, 13, (58, 219, 167, 255))
        _rect(pixels, width, 14, 7, 18, 25, (15, 50, 62, 255))
        _rect(pixels, width, 7, 14, 25, 18, (15, 50, 62, 255))
    return pixels


def _write_contact_sheet(root: Path, rendered: dict[str, tuple[int, int, list[tuple[int, int, int, int]]]]) -> str:
    width, height, tile = 640, 480, 120
    pixels = _canvas(width, height)
    _rect(pixels, width, 0, 0, width, height, (17, 25, 35, 255))
    for index, (name, (asset_width, asset_height, source)) in enumerate(rendered.items()):
        ox = (index % 5) * tile + (tile - min(asset_width, 96)) // 2
        oy = (index // 5) * tile + (tile - min(asset_height, 96)) // 2
        scale = min(1.0, 96 / max(asset_width, asset_height))
        for y in range(asset_height):
            for x in range(asset_width):
                pixel = source[y * asset_width + x]
                if pixel[3] == 0:
                    continue
                dx = ox + int(x * scale)
                dy = oy + int(y * scale)
                if 0 <= dx < width and 0 <= dy < height:
                    pixels[dy * width + dx] = pixel
        _rect(pixels, width, (index % 5) * tile + 8, (index // 5) * tile + 104, (index % 5) * tile + 112, (index // 5) * tile + 108, (102, 214, 175, 255))
    output = root / CONTACT_SHEET
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(png(width, height, pixels))
    return hashlib.sha256(output.read_bytes()).hexdigest()


def _manifest(root: Path, rendered: dict[str, tuple[int, int, list[tuple[int, int, int, int]]]], contact_hash: str) -> dict:
    assets = []
    for spec in ASSET_SPECS:
        outputs = []
        for index, relative in enumerate(spec["outputs"]):
            path = root / relative
            outputs.append({"path": relative, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "frame": spec["frame_names"][index] if index < len(spec["frame_names"]) else spec["frame_names"][0]})
        assets.append({
            "id": spec["id"], "kind": spec["kind"], "classification": "GENERATED_PLACEHOLDER",
            "source": {"status": "UNRESOLVED_SOURCE_IDENTITY", "creator": "OpenAI Codex for Doom Survivors", "created_date": "2026-09-11", "note": "Procedurally generated in-repo placeholder; no proprietary raw asset or copied pixels were used."},
            "rights": {"route": "PROJECT_GENERATED_IN_REPO", "raw_proprietary_asset": False, "redistribution": "PROJECT_TERMS_UNSPECIFIED"},
            "dimensions": [spec["width"], spec["height"]], "pivot": spec["pivot"], "scale": spec["scale"],
            "aliases": spec["aliases"], "frame_names": spec["frame_names"], "frame_tics": spec["frame_tics"],
            "transparency": "RGBA_ALPHA_ZERO", "direction_policy": spec["direction_policy"],
            "collision_class": spec["collision_class"], "outputs": outputs,
        })
    return {
        "schema_version": 1, "phase": "P013", "classification": "P013_GENERATED_REPRESENTATIVE_ASSETS",
        "reference_build": "1.16.107", "rights_note": "All seven outputs are project-generated in-repo placeholders by OpenAI Codex for Doom Survivors; no proprietary raw asset or copied pixels was used, and redistribution terms remain unspecified.",
        "conversion": {"tool": "tools/assetpipe/build_representative.py", "version": "p013-representative-v1", "seed": 13013, "filter": "none", "color_type": "RGBA", "nearest_sampling": True},
        "contact_sheet": {"path": str(CONTACT_SHEET).replace("\\", "/"), "sha256": contact_hash}, "assets": assets,
    }


def validate_manifest(manifest: dict, root: Path) -> list[str]:
    errors = []
    assets = manifest.get("assets")
    if manifest.get("classification") != "P013_GENERATED_REPRESENTATIVE_ASSETS": errors.append("manifest classification is not P013_GENERATED_REPRESENTATIVE_ASSETS")
    if not isinstance(assets, list) or len(assets) != 7: errors.append("manifest must contain exactly seven representative assets")
    seen = set()
    for asset in assets or []:
        asset_id = asset.get("id")
        if asset_id in seen: errors.append(f"duplicate asset id: {asset_id}")
        seen.add(asset_id)
        if asset.get("classification") != "GENERATED_PLACEHOLDER": errors.append(f"{asset_id}: invalid classification")
        if asset.get("rights", {}).get("route") != "PROJECT_GENERATED_IN_REPO" or asset.get("rights", {}).get("raw_proprietary_asset") is not False: errors.append(f"{asset_id}: unknown or unsafe rights route")
        dimensions, pivot = asset.get("dimensions", []), asset.get("pivot", [])
        if len(dimensions) != 2 or len(pivot) != 2 or not (0 <= pivot[0] <= dimensions[0] and 0 <= pivot[1] <= dimensions[1]): errors.append(f"{asset_id}: missing or invalid pivot")
        if not asset.get("outputs") or not asset.get("aliases") or asset.get("frame_tics") is None: errors.append(f"{asset_id}: missing output/alias/timing metadata")
        for output in asset.get("outputs", []):
            path = root / output.get("path", "")
            if not str(path).replace("\\", "/").startswith(str(root / "generated").replace("\\", "/")): errors.append(f"{asset_id}: output escapes generated directory")
            elif not path.is_file(): errors.append(f"{asset_id}: missing output {output.get('path')}")
            elif hashlib.sha256(path.read_bytes()).hexdigest() != output.get("sha256"): errors.append(f"{asset_id}: output hash mismatch")
    return errors


def build(root: Path = ROOT) -> dict:
    root = Path(root).resolve()
    rendered = {}
    for spec in ASSET_SPECS:
        for index, relative in enumerate(spec["outputs"]):
            path = root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            pixels = _asset_pixels(spec["kind"], spec["width"], spec["height"], index)
            path.write_bytes(png(spec["width"], spec["height"], pixels, tuple(spec["pivot"]) if relative.startswith("generated/sprites/") else None))
            rendered.setdefault(spec["id"], (spec["width"], spec["height"], pixels))
    contact_hash = _write_contact_sheet(root, rendered)
    manifest = _manifest(root, rendered, contact_hash)
    manifest_path = root / MANIFEST
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
    errors = validate_manifest(manifest, root)
    if errors: raise ValueError("; ".join(errors))
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--validate", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    if args.validate:
        manifest = json.loads((root / MANIFEST).read_text(encoding="utf-8"))
        errors = validate_manifest(manifest, root)
        if errors: raise SystemExit("FAIL: " + "; ".join(errors))
        print(json.dumps({"status": "PASS", "manifest": str(root / MANIFEST), "assets": len(manifest["assets"])}))
    else:
        manifest = build(root)
        print(json.dumps({"status": "PASS", "manifest": str(root / MANIFEST), "assets": len(manifest["assets"]), "contact_sheet": manifest["contact_sheet"]}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
