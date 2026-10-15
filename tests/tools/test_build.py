from __future__ import annotations

import json
import math
import struct
from pathlib import Path

from tools.build import map_wad, png


ROOT = Path(__file__).resolve().parents[2]


def load_room() -> dict:
    return json.loads((ROOT / "maps/source/fp-calibration/room.json").read_text(encoding="utf-8"))


def load_gallery_room() -> dict:
    return json.loads((ROOT / "maps/source/asset-gallery/room.json").read_text(encoding="utf-8"))


def png_chunks(data: bytes) -> list[tuple[bytes, bytes]]:
    chunks = []
    offset = 8
    while offset < len(data):
        size = struct.unpack(">I", data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        chunks.append((kind, data[offset + 8:offset + 8 + size]))
        offset += 12 + size
    return chunks


def test_generated_sprite_png_grab_offsets_are_stable_and_optional():
    pixel = lambda _x, _y: (10, 20, 30)
    assert [payload for kind, payload in png_chunks(png(64, 96, pixel, grab=(32, 96))) if kind == b"grAb"] == [struct.pack(">ii", 32, 96)]
    assert not [payload for kind, payload in png_chunks(png(8, 8, pixel)) if kind == b"grAb"]


def test_adapter_owned_fixtures_are_not_emitted_as_duplicate_map_things():
    room = load_room()
    textmap = map_wad(room)

    assert b"type = 1" in textmap
    for fixture in room["presentation_fixtures"]:
        assert f"type = {fixture['type']}".encode("ascii") not in textmap


def test_map_owned_fixture_mode_remains_available_for_other_room_specs():
    room = load_room()
    room["presentation_fixture_ownership"] = "MAP_THINGS_EMITTED_BY_BUILD"
    textmap = map_wad(room)

    for fixture in room["presentation_fixtures"]:
        assert f"type = {fixture['type']}".encode("ascii") in textmap


def test_p013_gallery_wad_keeps_adapter_owned_fixtures_out_of_map_things():
    room = load_gallery_room()
    textmap = map_wad(room)

    assert b"MAP02" in textmap
    assert room["presentation_fixture_ownership"] == "ADAPTER_WORLD_LOADED"
    for fixture in room["presentation_fixtures"]:
        marker = f"type = {fixture['type']}".encode("ascii")
        assert marker not in textmap


def test_p013_gallery_metadata_describes_dense_effects_and_stable_walk_ring():
    room = load_gallery_room()
    cases = room["gallery_cases"]
    target = tuple(cases[0]["target"])
    radii = [math.hypot(case["position"][0] - target[0], case["position"][1] - target[1]) for case in cases]

    assert len(cases) == 8
    assert len({tuple(case["position"]) for case in cases}) == 8
    assert max(radii) - min(radii) < 0.5
    assert sum(fixture["asset_id"] == "projectile" for fixture in room["presentation_fixtures"]) == 3
    assert sum(fixture["asset_id"] == "ground_aura" for fixture in room["presentation_fixtures"]) == 3
    assert all(item["engineering_reference_shape"]["status"] == "ENGINEERING_PLACEHOLDER_NOT_SOURCE" for item in room["collision_overlay"])
