"""Run and validate the synthetic preliminary P012 camera matrix in UZDoom."""
from __future__ import annotations

import json
import re
from pathlib import Path

from tools.build import ROOT, build
from tools.run_probe import run


CASE_RE = re.compile(
    r"DS_FP_CAMERA case=(?P<case>\d+) yaw=(?P<yaw>-?[\d.]+) "
    r"pitch=(?P<pitch>-?[\d.]+) fov=(?P<fov>[\d.]+) "
    r"x=(?P<x>-?[\d.]+) y=(?P<y>-?[\d.]+) logical_count=(?P<count>\d+)"
)
ADAPTER_RE = re.compile(
    r"DS_FP_ADAPTER_STATE tic=(?P<tic>\d+) body=\((?P<body_x>-?[\d.]+),(?P<body_y>-?[\d.]+),(?P<body_z>-?[\d.]+)\) "
    r"eye_z=(?P<eye_z>-?[\d.]+) view_height=(?P<view_height>-?[\d.]+) "
    r"yaw=(?P<yaw>-?[\d.]+) pitch=(?P<pitch>-?[\d.]+) desired_fov=(?P<desired_fov>[\d.]+) "
    r"fov=(?P<fov>[\d.]+) cmd_yaw=(?P<cmd_yaw>-?\d+) cmd_pitch=(?P<cmd_pitch>-?\d+) "
    r"cmd_forward=(?P<cmd_forward>-?\d+) cmd_side=(?P<cmd_side>-?\d+) logical_count=(?P<count>\d+)"
)
BASELINE_RE = re.compile(
    r"DS_FP_INTERACTIVE_BASELINE yaw=(?P<yaw>-?[\d.]+) pitch=(?P<pitch>-?[\d.]+) fov=(?P<fov>[\d.]+) "
    r"body=\((?P<body_x>-?[\d.]+),(?P<body_y>-?[\d.]+),(?P<body_z>-?[\d.]+)\)"
)
FIXTURE_RE = re.compile(
    r"DS_FP_FIXTURE actor=(?P<actor>close_billboard|solid_prop|foot_pickup) "
    r"pos=\((?P<x>-?[\d.]+),(?P<y>-?[\d.]+),(?P<z>-?[\d.]+)\) "
    r"radius=(?P<radius>[\d.]+) height=(?P<height>[\d.]+)"
)
EXPECTED = [
    (0.0, 0.0, 90.0),
    (90.0, 0.0, 90.0),
    (180.0, 0.0, 90.0),
    (270.0, 0.0, 90.0),
    (0.0, 45.0, 70.0),
    (0.0, -45.0, 120.0),
]


def validate(log: str) -> dict:
    rows = []
    for match in CASE_RE.finditer(log):
        rows.append({key: float(value) for key, value in match.groupdict().items()})
    errors = []
    fixtures = {}
    for match in FIXTURE_RE.finditer(log):
        fixture = {key: value for key, value in match.groupdict().items()}
        fixture.update({key: float(fixture[key]) for key in ("x", "y", "z", "radius", "height")})
        fixtures[fixture["actor"]] = fixture
    expected_fixtures = {
        "close_billboard": (8.0, 64.0),
        "solid_prop": (24.0, 96.0),
        "foot_pickup": (8.0, 8.0),
    }
    for name, (radius, height) in expected_fixtures.items():
        if name not in fixtures:
            errors.append(f"missing presentation fixture marker: {name}")
        elif abs(fixtures[name]["radius"] - radius) > 0.01 or abs(fixtures[name]["height"] - height) > 0.01:
            errors.append(f"presentation fixture dimensions changed: {name}")
    adapter_match = ADAPTER_RE.search(log)
    baseline_match = BASELINE_RE.search(log)
    adapter = None
    baseline = None
    if "DS_FP_ADAPTER_CONTRACT player_cmd=verified source_window=logical_xy eye_body=separate fov=player_info" not in log:
        errors.append("missing first-person adapter contract marker")
    if adapter_match is None:
        errors.append("missing first-person adapter state")
    else:
        adapter = adapter_match.groupdict()
        for key in ("tic", "cmd_yaw", "cmd_pitch", "cmd_forward", "cmd_side", "count"):
            adapter[key] = int(adapter[key])
        for key in ("body_x", "body_y", "body_z", "eye_z", "view_height", "yaw", "pitch", "desired_fov", "fov"):
            adapter[key] = float(adapter[key])
        if adapter["count"] != 4:
            errors.append(f"adapter logical count changed to {adapter['count']}")
        if abs(adapter["eye_z"] - adapter["body_z"] - adapter["view_height"]) > 0.01:
            errors.append("adapter eye/body relationship is inconsistent")
    if baseline_match is None:
        errors.append("missing interactive baseline marker")
    else:
        baseline = baseline_match.groupdict()
        for key in ("yaw", "pitch", "fov", "body_x", "body_y", "body_z"):
            baseline[key] = float(baseline[key])
        for name, expected in (("yaw", 0.0), ("pitch", 0.0), ("fov", 90.0), ("body_x", -200.0), ("body_y", 0.0)):
            if abs(baseline[name] - expected) > 0.01:
                errors.append(f"interactive baseline {name} expected {expected}, observed {baseline[name]}")
    if len(rows) != len(EXPECTED):
        errors.append(f"expected 6 camera cases, observed {len(rows)}")
    for index, row in enumerate(rows[: len(EXPECTED)]):
        yaw, pitch, fov = EXPECTED[index]
        if int(row["case"]) != index:
            errors.append(f"case order mismatch at row {index}")
        for name, expected in (("yaw", yaw), ("pitch", pitch), ("fov", fov)):
            if abs(row[name] - expected) > 0.01:
                errors.append(f"case {index} {name} expected {expected}, observed {row[name]}")
        if int(row["count"]) != 4:
            errors.append(f"case {index} logical count changed to {int(row['count'])}")
    if rows:
        origin = (rows[0]["x"], rows[0]["y"])
        if any((row["x"], row["y"]) != origin for row in rows):
            errors.append("player body X/Y changed during camera-only matrix")
    if "DS_FP_CAMERA_COMPLETE cases=6 logical_count=4 fixtures=3" not in log:
        errors.append("missing camera completion marker")
    if "DS_FP_ADAPTER_COMPLETE body_stable=true logical_stable=true" not in log:
        errors.append("missing first-person adapter completion marker")
    return {"status": "PASS" if not errors else "FAIL", "cases": rows, "adapter": adapter, "baseline": baseline, "fixtures": fixtures, "errors": errors}


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--width", type=int, default=1280)
    parser.add_argument("--height", type=int, default=720)
    args = parser.parse_args()
    package = Path(build(ROOT, room_spec=ROOT / "maps/source/fp-calibration/room.json")["package"])
    runtime = run(package, 30, False, False, "P012", 60, args.width, args.height)
    evidence = Path(runtime["evidence"])
    log = (evidence / "engine.log").read_text(encoding="utf-8", errors="replace")
    result = validate(log)
    result.update({
        "classification": "P012_RUNTIME_ENGINE_PROBE_WITH_SYNTHETIC_LOGICAL_ENTITIES",
        "source_game_parity": "OPEN",
        "runtime_status": runtime["status"],
        "package_sha256": runtime["package_sha256"],
        "engine_sha256": runtime["engine_sha256"],
        "source_commit": runtime["source_commit"],
        "captures": runtime["captures"],
        "requested_resolution": {"width": runtime["requested_window_width"], "height": runtime["requested_window_height"]},
        "observed_capture_dimensions": sorted({(capture["observed_width"], capture["observed_height"]) for capture in runtime["captures"]}),
    })
    if not all(capture.get("nonblank") for capture in runtime["captures"]):
        result["status"] = "FAIL"
        result["errors"].append("one or more framebuffer captures are blank or unsupported")
    (evidence / "camera-result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 0 if result["status"] == "PASS" and runtime["status"] == "RUNTIME_PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
