"""Run and strictly validate the MAP22 Cross/Heaven Sword runtime fixture."""
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


def _validator_module():
    path = ROOT / "tests/runtime/weapons-returning/test_p036_returning_runtime.py"
    spec = importlib.util.spec_from_file_location("p036_returning_runtime_validator", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load MAP22 validator: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, default=ROOT / "build/doom-survivors.ipk3",
                        help="already-built package; this command never builds")
    parser.add_argument("--camera-variant", type=int, choices=(0, 1, 2), default=0,
                        help="0=default; 1=yaw90; 2=pitch/FOV only")
    parser.add_argument("--mode", choices=("matrix", "flight", "move_rebase",
                                             "transform", "selection", "no_target", "crit"),
                        default="matrix",
                        help="bounded actual-engine returning-family scenario")
    parser.add_argument("--seed", type=int,
                        help="dedicated returning crit seed; defaults to 11 for crit mode and 360036 otherwise")
    parser.add_argument("--seconds", type=float, default=30.0,
                        help="bounded real-time UZDoom deadline")
    parser.add_argument("--validate-evidence", type=Path,
                        help="validate an existing engine run directory without launching")
    args = parser.parse_args()
    package = args.package.resolve()
    if not package.is_file():
        parser.error(f"package does not exist: {package}")
    package_sha = hashlib.sha256(package.read_bytes()).hexdigest()
    seed = args.seed if args.seed is not None else (11 if args.mode == "crit" else 360036)

    if args.validate_evidence:
        evidence = args.validate_evidence.resolve()
        result_path = evidence / "result.json"
        if not result_path.is_file():
            parser.error(f"evidence directory has no result.json: {evidence}")
        result = json.loads(result_path.read_text(encoding="utf-8"))
    else:
        result = run(
            package, args.seconds, False, False, "P036", map_name="MAP22",
            completion_marker="DS_P036_MAP22_RUNTIME_PASS",
            startup_commands=["+set", "ds_p036_mode", args.mode, "+set",
                              "ds_p036_camera_variant", str(args.camera_variant),
                              "+set", "ds_p036_seed", str(seed)],
        )
        evidence = Path(result["evidence"])

    log_path = evidence / "process.log"
    log = log_path.read_text(encoding="utf-8", errors="replace") if log_path.is_file() else ""
    run_status = result.get("status", "MISSING")
    recorded_variant = args.camera_variant
    errors = []
    if result.get("package_sha256") != package_sha:
        errors.append("evidence package SHA differs from supplied package")
    if args.validate_evidence:
        commands = result.get("startup_commands", [])
        try:
            recorded_mode = commands[commands.index("ds_p036_mode") + 1]
        except (ValueError, IndexError, TypeError):
            recorded_mode = None
        if recorded_mode != args.mode:
            errors.append("recorded mode is missing or does not match requested mode")
        try:
            recorded_variant = int(commands[commands.index("ds_p036_camera_variant") + 1])
        except (ValueError, IndexError, TypeError):
            errors.append("recorded camera variant is missing")
        try:
            recorded_seed = int(commands[commands.index("ds_p036_seed") + 1])
        except (ValueError, IndexError, TypeError):
            errors.append("recorded seed is missing")
            recorded_seed = None
        if recorded_seed != seed:
            errors.append("recorded seed does not match requested seed")
    else:
        recorded_seed = seed
    if recorded_variant != args.camera_variant:
        errors.append("recorded camera variant does not match requested variant")
    captures = result.get("captures", [])
    validation = _validator_module().validate_p036_runtime(
        log, run_status, captures, recorded_variant, args.mode, recorded_seed)
    if errors:
        validation["errors"].extend(errors)
        validation["status"] = "FAIL"
    report = {
        "status": validation["status"],
        "claim": validation["claim"],
        "package": str(package),
        "package_sha256": package_sha,
        "engine_package_sha256": result.get("package_sha256"),
        "engine_sha256": result.get("engine_sha256"),
        "mode": args.mode,
        "seed": recorded_seed,
        "camera_variant": args.camera_variant,
        "run_status": run_status,
        "validation": validation,
        "captures": captures,
        "evidence": str(evidence),
    }
    report_path = evidence / "p036-returning-validation.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0 if validation["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
