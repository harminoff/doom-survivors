"""Run and strictly validate opt-in P035 gameplay on an existing MAP16 package.

This runner never builds or changes the package. It writes runtime evidence and
the strict report beside each UZDoom capture. The default-manual smoke is only
run after P035 passes, preserving the project's fail-fast check order.
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
    path = ROOT / "tests/runtime/ballistic/test_p035_map16.py"
    spec = importlib.util.spec_from_file_location("p035_map16_validator", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load MAP16 validator: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def validate_run(result: dict, package_sha256: str, validator, route: str) -> dict:
    evidence = Path(result.get("evidence", ""))
    log_path = evidence / "process.log"
    log = log_path.read_text(encoding="utf-8", errors="replace") if log_path.is_file() else ""
    errors: list[str] = []
    if result.get("package_sha256") != package_sha256:
        errors.append("runtime package SHA differs from the supplied package")
    captures = result.get("captures", [])
    if not any(row.get("nonblank") is True for row in captures):
        errors.append("no nonblank UZDoom framebuffer capture was recorded")
    if route == "p035":
        checked = validator.validate_p035_map16(
            log,
            result.get("status", "MISSING"),
            result.get("logical_accelerated"),
            result.get("startup_commands"),
        )
    else:
        checked = validator.validate_p035_default_manual(
            log,
            result.get("status", "MISSING"),
            result.get("logical_accelerated"),
        )
    errors.extend(checked.get("errors", []))
    report = {
        "status": "PASS" if not errors and checked.get("status") == "PASS" else "FAIL",
        "route": route,
        "package_sha256": package_sha256,
        "engine_sha256": result.get("engine_sha256"),
        "run_status": result.get("status"),
        "validation": checked,
        "captures": captures,
        "capture_visual_review_required": True,
        "evidence": str(evidence),
        "errors": errors,
    }
    report_name = ("p035-map16-validation.json" if route == "p035"
                   else "p035-map16-default-manual-validation.json")
    evidence.mkdir(parents=True, exist_ok=True)
    (evidence / report_name).write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return report


def _run_route(package: Path, seconds: float, route: str) -> dict:
    if route == "p035":
        startup_commands = [
            "+set", "ds_p030_mode", "p035",
            "+set", "ds_p032_mode", "evolution",
            "+set", "ds_p030_speed", "1",
            "+set", "ds_p030_duration_tics", "2100",
        ]
    else:
        startup_commands = [
            "+set", "ds_p030_mode", "manual",
            "+set", "ds_p032_mode", "manual",
            "+set", "ds_p030_speed", "1",
            "+set", "ds_p030_duration_tics", "2100",
        ]
    return run(
        package, seconds, False, False, "P035",
        map_name="MAP16", completion_marker="DS_P030_COMPLETE",
        active_in_background=True, vsync=False,
        startup_commands=startup_commands,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path,
                        default=ROOT / "build/doom-survivors.ipk3",
                        help="already-built combined package; this runner never builds")
    parser.add_argument("--seconds", type=float, default=90.0,
                        help="bounded normal-speed runtime deadline (65-180 seconds)")
    parser.add_argument("--manual-smoke", action="store_true",
                        help="after P035 passes, run default-route manual MAP16 completion")
    parser.add_argument("--validate-evidence", type=Path,
                        help="validate an existing P035 evidence directory without launching")
    parser.add_argument("--manual-evidence", type=Path,
                        help="with --validate-evidence, validate an existing manual evidence directory too")
    args = parser.parse_args()
    if not 65.0 <= args.seconds <= 180.0:
        parser.error("--seconds must be between 65 and 180 for a complete 2,100-tic run")
    package = args.package.resolve()
    if not package.is_file():
        parser.error(f"package does not exist: {package}")
    package_sha256 = hashlib.sha256(package.read_bytes()).hexdigest()
    validator = load_validator()

    if args.validate_evidence:
        evidence = args.validate_evidence.resolve()
        result_path = evidence / "result.json"
        if not result_path.is_file():
            parser.error(f"evidence directory has no result.json: {evidence}")
        p035_result = json.loads(result_path.read_text(encoding="utf-8"))
    else:
        p035_result = _run_route(package, args.seconds, "p035")
    p035_report = validate_run(p035_result, package_sha256, validator, "p035")
    print(json.dumps(p035_report, indent=2), flush=True)
    if p035_report["status"] != "PASS":
        return 1

    if args.manual_evidence:
        evidence = args.manual_evidence.resolve()
        result_path = evidence / "result.json"
        if not result_path.is_file():
            parser.error(f"manual evidence directory has no result.json: {evidence}")
        manual_result = json.loads(result_path.read_text(encoding="utf-8"))
    elif args.manual_smoke and not args.validate_evidence:
        manual_result = _run_route(package, args.seconds, "manual")
    else:
        return 0
    manual_report = validate_run(manual_result, package_sha256, validator, "manual")
    print(json.dumps(manual_report, indent=2), flush=True)
    return 0 if manual_report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
