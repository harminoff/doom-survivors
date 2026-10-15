"""Run and validate the bounded P013 first-person representative-asset gallery."""
from __future__ import annotations

import json
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.build import build
from tools.run_probe import run

ROOM_SPEC = json.loads((ROOT / "maps/source/asset-gallery/room.json").read_text(encoding="utf-8"))
MANIFEST = json.loads((ROOT / "assets/manifests/p013-representative.json").read_text(encoding="utf-8"))
CASE_RE = re.compile(r"DS_P013_GALLERY_CASE case=(?P<case>\d+) yaw=(?P<yaw>-?[\d.]+) pitch=(?P<pitch>-?[\d.]+) fov=(?P<fov>[\d.]+) body=\((?P<x>-?[\d.]+),(?P<y>-?[\d.]+),(?P<z>-?[\d.]+)\) target=\((?P<target_x>-?[\d.]+),(?P<target_y>-?[\d.]+)\) ring_radius=(?P<radius>[\d.]+)")
ASSET_RE = re.compile(r"DS_P013_ASSET actor=(?P<actor>[a-z_]+) pos=\((?P<x>-?[\d.]+),(?P<y>-?[\d.]+),(?P<z>-?[\d.]+)\) policy=(?P<policy>[A-Z0-9_]+) collision=(?P<collision>[A-Z0-9_]+) presentation_solid=false presentation_blocking=false presentation_interaction=false")
EXPECTED_CASES = tuple((float(row["position"][0]), float(row["position"][1]), float(row["face_yaw"])) for row in ROOM_SPEC["gallery_cases"])
EXPECTED_TARGET = tuple(float(value) for value in ROOM_SPEC["gallery_cases"][0]["target"])
EXPECTED_RADIUS = math.hypot(EXPECTED_CASES[0][0] - EXPECTED_TARGET[0], EXPECTED_CASES[0][1] - EXPECTED_TARGET[1])
EXPECTED_ASSETS = {asset_id: sum(fixture["asset_id"] == asset_id for fixture in ROOM_SPEC["presentation_fixtures"]) for asset_id in {fixture["asset_id"] for fixture in ROOM_SPEC["presentation_fixtures"]}}
EXPECTED_COLLISIONS = {asset["id"]: asset["collision_class"] for asset in MANIFEST["assets"]}


def validate(log: str) -> dict:
    errors = []
    cases = [{key: float(value) for key, value in match.groupdict().items()} for match in CASE_RE.finditer(log)]
    assets = [{**match.groupdict(), **{key: float(match.group(key)) for key in ("x", "y", "z")}} for match in ASSET_RE.finditer(log)]
    begin_marker = f"DS_P013_GALLERY_BEGIN map={ROOM_SPEC['map_name']} manifest_assets={len(MANIFEST['assets'])} fixture_instances={len(ROOM_SPEC['presentation_fixtures'])} cases={len(EXPECTED_CASES)} ring_radius={EXPECTED_RADIUS:.3f} target=({EXPECTED_TARGET[0]:.3f},{EXPECTED_TARGET[1]:.3f}) collision_overlay=true classification=GENERATED_PLACEHOLDER"
    if begin_marker not in log:
        errors.append("missing gallery begin marker")
    fixture_count = len(ROOM_SPEC["presentation_fixtures"])
    if f"DS_P013_GALLERY_SPAWN count={fixture_count} expected={fixture_count} ownership=ADAPTER_WORLD_LOADED map_things=false" not in log:
        errors.append("missing adapter-owned fixture spawn proof")
    if "DS_P013_COLLISION_OVERLAY presentation_solid=false presentation_blocking=false presentation_interaction=false source_dimensions=UNKNOWN source_geometry_claim=NONE" not in log:
        errors.append("missing collision overlay proof marker")
    if len(cases) != len(EXPECTED_CASES):
        errors.append(f"expected {len(EXPECTED_CASES)} gallery cases, observed {len(cases)}")
    radii = []
    positions = []
    for index, row in enumerate(cases[:len(EXPECTED_CASES)]):
        expected_x, expected_y, expected_yaw = EXPECTED_CASES[index]
        if int(row["case"]) != index or abs(row["yaw"] - expected_yaw) > 0.01:
            errors.append(f"gallery case {index} camera mismatch")
        if abs(row["pitch"]) > 0.01 or abs(row["fov"] - 90.0) > 0.01 or abs(row["x"] - expected_x) > 0.01 or abs(row["y"] - expected_y) > 0.01:
            errors.append(f"gallery case {index} did not visit its ring position")
        if abs(row["target_x"] - EXPECTED_TARGET[0]) > 0.01 or abs(row["target_y"] - EXPECTED_TARGET[1]) > 0.01 or abs(row["radius"] - EXPECTED_RADIUS) > 0.01:
            errors.append(f"gallery case {index} target or declared radius mismatch")
        actual_radius = math.hypot(row["x"] - EXPECTED_TARGET[0], row["y"] - EXPECTED_TARGET[1])
        radii.append(actual_radius)
        positions.append((row["x"], row["y"]))
        if abs(actual_radius - EXPECTED_RADIUS) > 0.5:
            errors.append(f"gallery case {index} ring radius drifted")
    if len(set(positions)) != len(EXPECTED_CASES):
        errors.append("gallery cases did not visit eight distinct positions")
    if radii and max(radii) - min(radii) > 0.5:
        errors.append("gallery ring radius was not stable")
    counts = {name: sum(asset["actor"] == name for asset in assets) for name in EXPECTED_ASSETS}
    for name, expected in EXPECTED_ASSETS.items():
        if counts[name] != expected:
            errors.append(f"asset marker count for {name}: expected {expected}, observed {counts[name]}")
        if any(asset["collision"] != EXPECTED_COLLISIONS[name] for asset in assets if asset["actor"] == name):
            errors.append(f"asset marker collision classification for {name} is not an engineering placeholder")
    if f"DS_P013_GALLERY_COMPLETE cases={len(EXPECTED_CASES)} fixture_instances={fixture_count} collision_overlay=true ring_stable=true body_restored=true" not in log:
        errors.append("missing gallery completion marker")
    if "DS_RUNTIME_COMPLETE tics=65" not in log:
        errors.append("missing runtime completion marker")
    return {"status": "PASS" if not errors else "FAIL", "cases": cases, "assets": assets, "errors": errors}


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--width", type=int, default=1280)
    parser.add_argument("--height", type=int, default=720)
    args = parser.parse_args()
    package = Path(build(ROOT, room_spec=ROOT / "maps/source/asset-gallery/room.json")["package"])
    runtime = run(package, 30, False, False, "P013", 60, args.width, args.height, map_name="MAP02", completion_marker="DS_P013_GALLERY_COMPLETE")
    evidence = Path(runtime["evidence"])
    log = (evidence / "engine.log").read_text(encoding="utf-8", errors="replace")
    result = validate(log)
    result.update({"classification": "P013_RUNTIME_GENERATED_REPRESENTATIVE_GALLERY", "source_parity": "OPEN_GENERATED_PLACEHOLDER_GALLERY", "runtime_status": runtime["status"], "captures": runtime["captures"], "package_sha256": runtime["package_sha256"], "evidence": str(evidence)})
    if not all(capture.get("nonblank") for capture in runtime["captures"]):
        result["status"] = "FAIL"
        result["errors"].append("one or more gallery captures are blank")
    (evidence / "gallery-result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 0 if result["status"] == "PASS" and runtime["status"] == "RUNTIME_PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
