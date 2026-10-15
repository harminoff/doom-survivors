from __future__ import annotations

import hashlib
import json
from pathlib import Path

from tools.assetpipe.build_representative import MANIFEST, build, png, validate_manifest


ROOT = Path(__file__).resolve().parents[2]


def test_representative_generator_is_deterministic(tmp_path):
    first = build(tmp_path)
    hashes_one = {path: hashlib.sha256((tmp_path / path).read_bytes()).hexdigest() for asset in first["assets"] for path in [out["path"] for out in asset["outputs"]]}
    second = build(tmp_path)
    hashes_two = {path: hashlib.sha256((tmp_path / path).read_bytes()).hexdigest() for asset in second["assets"] for path in [out["path"] for out in asset["outputs"]]}
    assert hashes_one == hashes_two
    assert json.dumps(first, sort_keys=True) == json.dumps(second, sort_keys=True)


def test_manifest_has_exactly_seven_safe_assets_and_valid_hashes(tmp_path):
    manifest = build(tmp_path)
    assert len(manifest["assets"]) == 7
    assert validate_manifest(manifest, tmp_path) == []
    assert all(asset["classification"] == "GENERATED_PLACEHOLDER" for asset in manifest["assets"])
    assert all(asset["rights"]["raw_proprietary_asset"] is False for asset in manifest["assets"])
    assert all(asset["collision_class"].startswith("ENGINEERING_") or asset["collision_class"] == "ENGINEERING_PRESENTATION_ONLY" for asset in manifest["assets"])


def test_validator_rejects_unknown_rights_and_missing_anchor(tmp_path):
    manifest = build(tmp_path)
    manifest["assets"][0]["rights"]["route"] = "UNKNOWN"
    manifest["assets"][1]["pivot"] = [-1, 0]
    errors = validate_manifest(manifest, tmp_path)
    assert any("rights route" in error for error in errors)
    assert any("invalid pivot" in error for error in errors)


def test_png_is_rgba_and_has_big_endian_grab_for_sprites():
    data = png(4, 4, [(1, 2, 3, 255)] * 16, grab=(2, 3))
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    assert b"grAb" in data and b"\x00\x00\x00\x02\x00\x00\x00\x03" in data
