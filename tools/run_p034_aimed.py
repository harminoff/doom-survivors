"""Run and strictly validate one pinned-UZDoom MAP20 aimed-weapon probe.

Package construction is intentionally separate: this runner records and tests
the exact package supplied by the caller, so a runtime report cannot hide a
stale build.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tools.run_probe import run


def load_validator():
    path = ROOT / "tests/runtime/weapons-aimed/test_p034_aimed_runtime.py"
    spec = importlib.util.spec_from_file_location("p034_aimed_runtime_validator", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load MAP20 validator: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, default=ROOT / "build/doom-survivors.ipk3",
                        help="already-built package to test; this command never builds")
    parser.add_argument("--camera-variant", type=int, choices=(0, 1, 2), default=0,
                        help="0=east, 1=north yaw, 2=east yaw with pitch/FOV change")
    parser.add_argument("--seconds", type=float, default=75.0,
                        help="bounded real-time engine deadline")
    parser.add_argument("--validate-evidence", type=Path,
                        help="strictly validate an existing run directory without launching UZDoom")
    parser.add_argument("--compare-pitch-reference", type=Path,
                        help="for camera variant 2, compare actual hits against a variant-0 evidence directory")
    args = parser.parse_args()

    package = args.package.resolve()
    if not package.is_file():
        parser.error(f"package does not exist: {package}")
    package_sha256 = hashlib.sha256(package.read_bytes()).hexdigest()
    if args.validate_evidence:
        evidence = args.validate_evidence.resolve()
        result_path = evidence / "result.json"
        if not result_path.is_file():
            parser.error(f"evidence directory has no result.json: {evidence}")
        result = json.loads(result_path.read_text(encoding="utf-8"))
    else:
        result = run(
            package, args.seconds, False, False, "P034", map_name="MAP20",
            completion_marker="DS_P034_MAP20_RUNTIME_PASS",
            startup_commands=["+set", "ds_p034_mode", "matrix", "+set",
                              "ds_p034_camera_variant", str(args.camera_variant)],
        )
        evidence = Path(result["evidence"])
    log_path = evidence / "process.log"
    log = log_path.read_text(encoding="utf-8", errors="replace") if log_path.is_file() else ""
    if result.get("package_sha256") != package_sha256:
        result_status = result.get("status", "MISSING")
        validation = {"status": "FAIL", "camera_variant": args.camera_variant,
                      "row_count": 0, "first_volley_count": 0,
                      "first_child_event_count": 0, "accepted_hit_count": 0,
                      "errors": ["run package SHA does not match supplied package"]}
    else:
        result_status = result.get("status", "MISSING")
        if args.validate_evidence:
            recorded_variant = result.get("startup_commands", [])
            try:
                variant_index = recorded_variant.index("ds_p034_camera_variant") + 1
                recorded_camera_variant = int(recorded_variant[variant_index])
            except (ValueError, IndexError, TypeError):
                recorded_camera_variant = args.camera_variant
        else:
            recorded_camera_variant = args.camera_variant
        if recorded_camera_variant != args.camera_variant:
            result_status = "CAMERA_VARIANT_MISMATCH"
        validation = load_validator().validate_p034_map20(
            log, result_status, args.camera_variant)
    captures = result.get("captures", [])
    nonblank_captures = [row for row in captures if row.get("nonblank") is True]
    if not nonblank_captures:
        validation["errors"].append("no nonblank framebuffer capture was recorded")
        validation["status"] = "FAIL"

    camera_pair = None
    if args.compare_pitch_reference:
        if args.camera_variant != 2:
            validation["errors"].append("pitch/FOV reference comparison requires camera variant 2")
            validation["status"] = "FAIL"
        else:
            reference_dir = args.compare_pitch_reference.resolve()
            reference_result_path = reference_dir / "result.json"
            reference_log_path = reference_dir / "process.log"
            if not reference_result_path.is_file() or not reference_log_path.is_file():
                camera_pair = {"status": "FAIL", "errors": ["camera-0 reference evidence is incomplete"]}
            else:
                reference_result = json.loads(reference_result_path.read_text(encoding="utf-8"))
                if (reference_result.get("package_sha256") != package_sha256
                        or reference_result.get("status") != "RUNTIME_PASS"):
                    camera_pair = {"status": "FAIL", "errors": ["camera-0 evidence package/status differs"]}
                else:
                    reference_commands = reference_result.get("startup_commands", [])
                    try:
                        reference_index = reference_commands.index("ds_p034_camera_variant") + 1
                        reference_variant = int(reference_commands[reference_index])
                    except (ValueError, IndexError, TypeError):
                        reference_variant = -1
                    if reference_variant != 0:
                        camera_pair = {"status": "FAIL", "errors": ["reference run is not camera variant 0"]}
                    else:
                        camera_pair = load_validator().validate_p034_pitch_fov_invariance(
                            reference_log_path.read_text(encoding="utf-8", errors="replace"),
                            log)
            validation["pitch_fov_camera_pair"] = camera_pair
            if camera_pair.get("status") != "PASS":
                validation["errors"].extend(camera_pair.get("errors", ["pitch/FOV camera pair failed"]))
                validation["status"] = "FAIL"

    report = {
        "status": "PASS" if validation["status"] == "PASS" else "FAIL",
        "package": str(package),
        "package_sha256": package_sha256,
        "engine_package_sha256": result.get("package_sha256"),
        "engine_sha256": result.get("engine_sha256"),
        "camera_variant": args.camera_variant,
        "run_status": result_status,
        "validation": validation,
        "pitch_fov_camera_pair": camera_pair,
        "captures": captures,
        "evidence": str(evidence),
    }
    report_path = evidence / "p034-aimed-validation.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
