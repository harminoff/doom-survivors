"""Run and strictly validate the supplied pinned-UZDoom MAP21 package."""
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
    path = ROOT / "tests/runtime/weapons-ballistic/test_p035_ballistic_runtime.py"
    spec = importlib.util.spec_from_file_location("p035_ballistic_runtime_validator", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load MAP21 validator: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, default=ROOT / "build/doom-survivors.ipk3",
                        help="already-built package to test; this command never builds")
    parser.add_argument("--camera-variant", type=int, choices=(0, 1, 2), default=0,
                        help="0=default; 1=yaw 90; 2=pitch/FOV only")
    parser.add_argument("--mode", choices=("matrix", "wall", "arc", "edge", "no_target"), default="matrix",
                        help="matrix checks every rank; focused modes prove walls, fall, swept hits/pierce, or empty-target RNG")
    parser.add_argument("--seconds", type=float, default=75.0,
                        help="bounded real-time UZDoom deadline")
    parser.add_argument("--validate-evidence", type=Path,
                        help="strictly validate an existing run directory without launching UZDoom")
    parser.add_argument("--compare-pitch-reference", type=Path,
                        help="for variant 2, compare actual logical hit records with camera-zero evidence")
    args = parser.parse_args()
    package = args.package.resolve()
    if not package.is_file():
        parser.error(f"package does not exist: {package}")
    package_sha = hashlib.sha256(package.read_bytes()).hexdigest()
    if args.validate_evidence:
        evidence = args.validate_evidence.resolve()
        result_path = evidence / "result.json"
        if not result_path.is_file():
            parser.error(f"evidence directory has no result.json: {evidence}")
        result = json.loads(result_path.read_text(encoding="utf-8"))
    else:
        result = run(
            package, args.seconds, False, False, "P035", map_name="MAP21",
            completion_marker=("DS_P035_MAP21_RUNTIME_PASS" if args.mode == "matrix"
                               else "DS_P035_MAP21_EDGE_PASS"),
            startup_commands=["+set", "ds_p035_mode", args.mode, "+set",
                              "ds_p035_camera_variant", str(args.camera_variant)],
        )
        evidence = Path(result["evidence"])
    log_path = evidence / "process.log"
    log = log_path.read_text(encoding="utf-8", errors="replace") if log_path.is_file() else ""
    if result.get("package_sha256") != package_sha:
        run_status = "PACKAGE_SHA_MISMATCH"
        validation = {"status": "FAIL", "mode": "matrix",
                      "camera_variant": args.camera_variant,
                      "errors": ["evidence package SHA differs from supplied package"]}
    else:
        recorded_variant = args.camera_variant
        if args.validate_evidence:
            commands = result.get("startup_commands", [])
            run_status = result.get("status", "MISSING")
            try:
                recorded_mode = commands[commands.index("ds_p035_mode") + 1]
            except (ValueError, IndexError, TypeError):
                recorded_mode = "matrix" if args.mode == "matrix" else None
            if recorded_mode != args.mode:
                run_status = "MODE_MISSING_OR_MISMATCH"
            try:
                recorded_variant = int(commands[commands.index("ds_p035_camera_variant") + 1])
            except (ValueError, IndexError, TypeError):
                # The engine CVar defaults to variant 0. Older first-pass
                # evidence supplied only the mode and therefore records that
                # default implicitly; variants 1/2 must be explicit.
                if args.camera_variant == 0:
                    recorded_variant = 0
                else:
                    run_status = "CAMERA_VARIANT_MISSING"
        else:
            run_status = result.get("status", "MISSING")
        if recorded_variant != args.camera_variant:
            run_status = "CAMERA_VARIANT_MISMATCH"
        validator = load_validator()
        if args.mode == "matrix":
            validation = validator.validate_p035_matrix(log, run_status,
                                                         args.camera_variant)
        elif args.mode == "wall":
            validation = validator.validate_p035_wall_scenario(
                log, run_status, args.camera_variant)
        elif args.mode == "arc":
            validation = validator.validate_p035_arc_scenario(log, run_status)
        elif args.mode == "edge":
            validation = validator.validate_p035_edge_scenario(log, run_status)
        else:
            validation = validator.validate_p035_no_target_scenario(log, run_status)

    captures = result.get("captures", [])
    if not any(row.get("nonblank") is True for row in captures):
        validation["errors"].append("no nonblank framebuffer capture was recorded")
        validation["status"] = "FAIL"
    pitch_pair = None
    if args.compare_pitch_reference:
        if args.camera_variant != 2:
            pitch_pair = {"status": "FAIL", "errors": [
                "pitch/FOV comparison requires camera variant 2"]}
        else:
            reference = args.compare_pitch_reference.resolve()
            ref_result_path = reference / "result.json"
            ref_log_path = reference / "process.log"
            if not ref_result_path.is_file() or not ref_log_path.is_file():
                pitch_pair = {"status": "FAIL", "errors": [
                    "camera-zero reference evidence is incomplete"]}
            else:
                ref_result = json.loads(ref_result_path.read_text(encoding="utf-8"))
                commands = ref_result.get("startup_commands", [])
                try:
                    ref_variant = int(commands[commands.index("ds_p035_camera_variant") + 1])
                except (ValueError, IndexError, TypeError):
                    # The CVar default is zero; the first camera-zero
                    # diagnostic run recorded only the matrix mode.
                    ref_variant = 0 if "matrix" in commands else -1
                if (ref_result.get("package_sha256") != package_sha
                        or ref_result.get("status") != "RUNTIME_PASS"
                        or ref_variant != 0):
                    pitch_pair = {"status": "FAIL", "errors": [
                        "camera-zero reference package, run status, or variant differs"]}
                else:
                    pitch_pair = load_validator().validate_p035_pitch_pair(
                        ref_log_path.read_text(encoding="utf-8", errors="replace"), log)
        validation["pitch_fov_camera_pair"] = pitch_pair
        if pitch_pair.get("status") != "PASS":
            validation["errors"].extend(pitch_pair.get("errors", ["pitch/FOV pair failed"]))
            validation["status"] = "FAIL"

    report = {
        "status": "PASS" if validation["status"] == "PASS" else "FAIL",
        "package": str(package), "package_sha256": package_sha,
        "engine_package_sha256": result.get("package_sha256"),
        "engine_sha256": result.get("engine_sha256"),
        "camera_variant": args.camera_variant, "mode": args.mode,
        "run_status": result.get("status"),
        "validation": validation, "pitch_fov_camera_pair": pitch_pair,
        "captures": captures, "evidence": str(evidence),
    }
    report_path = evidence / "p035-ballistic-validation.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
