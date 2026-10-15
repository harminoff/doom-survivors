"""Run and strictly validate the controlled MAP23 orbit fixture in UZDoom."""
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
    path = ROOT / "tests/runtime/weapons-orbit/test_p037_orbit_data.py"
    spec = importlib.util.spec_from_file_location("p037_orbit_validator", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load MAP23 validator: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path,
                        default=ROOT / "build/doom-survivors.ipk3",
                        help="already-built package; this runner never builds")
    parser.add_argument("--mode", choices=("rotation", "stress", "members",
                        "cohorts", "bible_gap", "overlap", "transform", "rebase", "pause"),
                        default="rotation", help="controlled actual-engine MAP23 scenario")
    parser.add_argument("--camera-variant", type=int, choices=(0, 1, 2), default=0,
                        help="0=default; 1=yaw90; 2=pitch/FOV only")
    parser.add_argument("--seed", type=int, default=370037)
    parser.add_argument("--seconds", type=float, default=30.0,
                        help="bounded real-time UZDoom deadline")
    parser.add_argument("--validate-evidence", type=Path,
                        help="validate one existing run directory without launching")
    parser.add_argument("--compare-camera-evidence", nargs=3, type=Path,
                        metavar=("VARIANT0_DIR", "VARIANT1_DIR", "VARIANT2_DIR"),
                        help="strictly compare existing default/yaw90/pitch-FOV run evidence")
    parser.add_argument("--compare-rebase-evidence", nargs=2, type=Path,
                        metavar=("REBASE_DIR", "ROTATION_DIR"),
                        help="compare rebased accepted-hit path to its baseline rotation run")
    args = parser.parse_args()
    package = args.package.resolve()
    if not package.is_file():
        parser.error(f"package does not exist: {package}")
    package_sha = hashlib.sha256(package.read_bytes()).hexdigest()
    if args.compare_camera_evidence:
        module = _validator_module()
        variants = (0, 1, 2)
        logs: dict[int, str] = {}
        package_shas: set[str] = set()
        evidence_rows: list[dict[str, object]] = []
        errors: list[str] = []
        for variant, raw_path in zip(variants, args.compare_camera_evidence):
            evidence = raw_path.resolve()
            result_path = evidence / "result.json"
            log_path = evidence / "process.log"
            if not result_path.is_file() or not log_path.is_file():
                errors.append(f"camera variant {variant} evidence is missing result.json or process.log")
                continue
            result = json.loads(result_path.read_text(encoding="utf-8"))
            log = log_path.read_text(encoding="utf-8", errors="replace")
            logs[variant] = log
            run_sha = str(result.get("package_sha256", ""))
            package_shas.add(run_sha)
            status = str(result.get("status", "MISSING"))
            single = module.validate_p037_map23_runtime(
                log, status, result.get("captures", []), variant)
            validation_path = evidence / "p037-orbit-validation.json"
            if not validation_path.is_file():
                errors.append(f"camera variant {variant} has no persisted strict run validation")
            else:
                persisted = json.loads(validation_path.read_text(encoding="utf-8"))
                if persisted.get("status") != "PASS" or persisted.get("package_sha256") != run_sha:
                    errors.append(f"camera variant {variant} persisted validation is not PASS for its package")
            if single["status"] != "PASS":
                errors.extend(f"camera variant {variant}: {error}" for error in single["errors"])
            evidence_rows.append({
                "variant": variant, "status": status, "package_sha256": run_sha,
                "engine_sha256": result.get("engine_sha256"),
                "evidence": str(evidence), "strict_validation": single,
            })
        if len(package_shas) != 1 or "" in package_shas:
            errors.append("camera variants do not all use one identified package SHA")
        pair = module.validate_p037_camera_pair(logs)
        errors.extend(pair["errors"])
        if errors:
            pair["errors"] = errors
            pair["status"] = "FAIL"
        report = {
            **pair,
            "package_sha256": next(iter(package_shas)) if len(package_shas) == 1 else None,
            "engine_sha256": evidence_rows[0].get("engine_sha256") if evidence_rows else None,
            "runs": evidence_rows,
        }
        if args.compare_camera_evidence:
            report_path = args.compare_camera_evidence[0].resolve() / "p037-camera-pair-validation.json"
            report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(report, indent=2))
        return 0 if report["status"] == "PASS" else 1
    if args.compare_rebase_evidence:
        module = _validator_module()
        modes = ("rebase", "rotation")
        logs: list[str] = []
        package_shas: set[str] = set()
        runs: list[dict[str, object]] = []
        errors: list[str] = []
        for mode, raw_path in zip(modes, args.compare_rebase_evidence):
            evidence = raw_path.resolve()
            result_path = evidence / "result.json"
            log_path = evidence / "process.log"
            if not result_path.is_file() or not log_path.is_file():
                errors.append(f"{mode} evidence is missing result.json or process.log")
                continue
            result = json.loads(result_path.read_text(encoding="utf-8"))
            log = log_path.read_text(encoding="utf-8", errors="replace")
            logs.append(log)
            run_sha = str(result.get("package_sha256", ""))
            package_shas.add(run_sha)
            single = module.validate_p037_map23_runtime(
                log, str(result.get("status", "MISSING")),
                result.get("captures", []), 0, mode)
            validation_path = evidence / "p037-orbit-validation.json"
            if not validation_path.is_file():
                errors.append(f"{mode} evidence has no persisted strict validation")
            else:
                persisted = json.loads(validation_path.read_text(encoding="utf-8"))
                if (persisted.get("status") != "PASS"
                        or persisted.get("package_sha256") != run_sha
                        or persisted.get("mode") != mode):
                    errors.append(f"{mode} persisted validation does not match run package/mode")
            if single["status"] != "PASS":
                errors.extend(f"{mode}: {error}" for error in single["errors"])
            runs.append({"mode": mode, "status": result.get("status"),
                         "package_sha256": run_sha, "evidence": str(evidence),
                         "strict_validation": single})
        if len(package_shas) != 1 or "" in package_shas:
            errors.append("rebase and baseline runs do not share one identified package SHA")
        pair = (module.validate_p037_rebase_pair(logs[0], logs[1])
                if len(logs) == 2 else {"status": "FAIL", "errors": ["both logs are required"]})
        errors.extend(pair["errors"])
        if errors:
            pair["errors"] = errors
            pair["status"] = "FAIL"
        report = {
            **pair,
            "package_sha256": next(iter(package_shas)) if len(package_shas) == 1 else None,
            "runs": runs,
        }
        report_path = args.compare_rebase_evidence[0].resolve() / "p037-rebase-pair-validation.json"
        report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(report, indent=2))
        return 0 if report["status"] == "PASS" else 1
    startup_commands = [
        "+set", "ds_p037_mode", args.mode,
        "+set", "ds_p037_camera_variant", str(args.camera_variant),
        "+set", "ds_p037_seed", str(args.seed),
    ]

    if args.validate_evidence:
        evidence = args.validate_evidence.resolve()
        result_path = evidence / "result.json"
        if not result_path.is_file():
            parser.error(f"evidence directory has no result.json: {evidence}")
        result = json.loads(result_path.read_text(encoding="utf-8"))
    else:
        result = run(
            package, args.seconds, False, False, "P037", map_name="MAP23",
            completion_marker="DS_P037_MAP23_RUNTIME_PASS",
            startup_commands=startup_commands,
        )
        evidence = Path(result["evidence"])

    errors: list[str] = []
    if result.get("package_sha256") != package_sha:
        errors.append("evidence package SHA differs from supplied package")
    recorded_variant = args.camera_variant
    recorded_seed = args.seed
    if args.validate_evidence:
        commands = result.get("startup_commands", [])
        for key, expected, converter in (
            ("ds_p037_mode", args.mode, str),
            ("ds_p037_camera_variant", args.camera_variant, int),
            ("ds_p037_seed", args.seed, int),
        ):
            try:
                actual = converter(commands[commands.index(key) + 1])
            except (ValueError, IndexError, TypeError):
                actual = None
                errors.append(f"recorded startup command {key} is missing or malformed")
            if actual != expected:
                errors.append(f"recorded startup command {key} differs from requested value")
        try:
            recorded_variant = int(commands[commands.index("ds_p037_camera_variant") + 1])
            recorded_seed = int(commands[commands.index("ds_p037_seed") + 1])
        except (ValueError, IndexError, TypeError):
            pass

    log_path = evidence / "process.log"
    log = log_path.read_text(encoding="utf-8", errors="replace") if log_path.is_file() else ""
    validation = _validator_module().validate_p037_map23_runtime(
        log, result.get("status", "MISSING"), result.get("captures", []),
        recorded_variant, args.mode,
    )
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
        "camera_variant": recorded_variant,
        "run_status": result.get("status", "MISSING"),
        "validation": validation,
        "captures": result.get("captures", []),
        "evidence": str(evidence),
    }
    report_path = evidence / "p037-orbit-validation.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0 if validation["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
