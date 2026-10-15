"""Run and strictly validate the controlled MAP25 aura/healing fixture."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tools.run_probe import config_text, run
from tools.run_persistence_bench import read_log, run_engine

MODES = ("matrix", "camera", "transform", "heart", "heart_recovery",
          "growth_and_high_stats", "recovery_cap", "bloody_tear",
          "same_tic_order", "pause", "save")


def _validator_module():
    path = ROOT / "tests/runtime/weapons-aura/test_p039_aura_runtime.py"
    spec = importlib.util.spec_from_file_location("p039_aura_validator", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load MAP25 validator: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _load_evidence(directory: Path) -> tuple[dict, str]:
    result_path = directory / "result.json"
    log_path = directory / "process.log"
    if not result_path.is_file() or not log_path.is_file():
        raise ValueError(f"evidence directory must contain result.json and process.log: {directory}")
    return json.loads(result_path.read_text(encoding="utf-8")), log_path.read_text(encoding="utf-8", errors="replace")


def _hit_tuples(log: str) -> list[tuple[str, ...]]:
    rows = _validator_module()._log_rows(log, "DS_P039_AURA_HIT")
    return [tuple(row.get(key, "") for key in (
        "tic", "system_id", "rank", "target_id", "damage_milli",
        "before", "after", "accepted_delta_milli"))
        for row in rows]


def _compare_camera_runs(directories: list[Path]) -> dict[str, object]:
    """Camera yaw/pitch/FOV and ring-toggle invariance across four runs of
    the "camera" mode: (cam0,vfx1), (cam1,vfx1), (cam2,vfx1), (cam0,vfx0)."""
    errors: list[str] = []
    expected = [(0, 1), (1, 1), (2, 1), (0, 0)]
    logs: list[str] = []
    package_shas: set[str] = set()
    validator = _validator_module()
    for directory, (camera, vfx) in zip(directories, expected):
        try:
            result, log = _load_evidence(directory.resolve())
        except (OSError, ValueError, json.JSONDecodeError) as exc:
            errors.append(str(exc))
            continue
        package_shas.add(str(result.get("package_sha256", "")))
        logs.append(log)
        single = validator.validate_p039_map25_runtime(
            log, str(result.get("status", "MISSING")), result.get("captures", []),
            "camera", camera, vfx)
        if single["status"] != "PASS":
            errors.extend(f"{directory.name}: {error}" for error in single["errors"])
    if len(package_shas) != 1 or "" in package_shas:
        errors.append("all four camera/VFX runs must use one identified package SHA")
    tuples = [_hit_tuples(log) for log in logs]
    if len(tuples) != 4 or any(not row for row in tuples):
        errors.append("one or more camera/VFX runs lack actual accepted aura-hit records")
    elif any(row != tuples[0] for row in tuples[1:]):
        errors.append("accepted logical hit tuples changed with camera or presentation-ring toggle")
    return {
        "status": "PASS" if not errors else "FAIL",
        "claim": "MAP25 accepted aura-hit tuples are invariant across yaw/pitch/FOV and the presentation ring toggle",
        "package_sha256": next(iter(package_shas)) if len(package_shas) == 1 else None,
        "hit_tuple_count": len(tuples[0]) if tuples else 0,
        "errors": errors,
    }


def _save_roundtrip(package: Path, package_sha: str, timeout: float) -> dict[str, object]:
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    name = f"{stamp}-p039-map25-save-load"
    evidence = ROOT / "evidence/P039" / name
    profile = ROOT / ".local/probes" / name
    save_capture = evidence / "save-captures"
    load_capture = evidence / "load-captures"
    evidence.mkdir(parents=True)
    profile.mkdir(parents=True)
    save_capture.mkdir()
    load_capture.mkdir()
    (profile / "config.ini").write_text(config_text(save_capture, vsync=False),
                                        encoding="utf-8", newline="\n")
    (profile / "save.cfg").write_text(
        'wait 100; screenshot; save ds_p039_aura "P039 Aura"; wait 4; quit\n',
        encoding="utf-8", newline="\n")
    (profile / "load.cfg").write_text(
        'wait 100; screenshot; quit\n', encoding="utf-8", newline="\n")
    lock = json.loads((ROOT / "toolchain/lock.json").read_text(encoding="utf-8"))
    executable = ROOT / lock["uzdoom"]["executable"]["path"]
    common = ["+enablescriptscreenshot", "true", "+set", "ds_p039_mode", "save"]
    save_args = common + ["+screenshot_dir", save_capture.as_posix(),
                          "+map", "MAP25", "+exec", "save.cfg"]
    save_rc = run_engine(executable, package, profile, "p039-save.log", save_args,
                         timeout=timeout)
    save_log = read_log(profile, "p039-save.log")
    save_files = sorted(path for path in profile.glob("ds_p039_aura*") if path.is_file())
    save_file = save_files[0] if save_files else None
    load_rc = None
    load_log = ""
    if save_file is not None:
        (profile / "config.ini").write_text(config_text(load_capture, vsync=False),
                                            encoding="utf-8", newline="\n")
        load_args = ["-loadgame", save_file.stem] + common + [
            "+screenshot_dir", load_capture.as_posix(), "+exec", "load.cfg"]
        load_rc = run_engine(executable, package, profile, "p039-load.log", load_args,
                             timeout=timeout)
        load_log = read_log(profile, "p039-load.log")
    (evidence / "save-engine.log").write_text(save_log, encoding="utf-8", newline="\n")
    (evidence / "load-engine.log").write_text(load_log, encoding="utf-8", newline="\n")
    if save_file is not None:
        shutil.copy2(save_file, evidence / save_file.name)
    validator = _validator_module()
    save_rows = validator._log_rows(save_log, "DS_P039_MAP25_SAVE_STATE")
    restore_rows = validator._log_rows(load_log, "DS_P039_MAP25_RESTORE")
    errors: list[str] = []
    if save_rc != 0:
        errors.append(f"save process exit was {save_rc}, expected clean quit")
    if save_file is None or save_file.stat().st_size <= 0:
        errors.append("UZDoom did not create a non-empty MAP25 run save")
    if len(save_rows) != 1 or save_rows[0].get("accepted") != "1":
        errors.append("aura/healing save boundary was not recorded exactly once")
    if len(restore_rows) != 1:
        errors.append("restored EventHandler did not report its first-tick state")
    else:
        saved = save_rows[0] if save_rows else {}
        restored = restore_rows[0]
        if (restored.get("accepted") != "1" or restored.get("first_tick") != "1"
                or restored.get("logical_tic") != saved.get("logical_tic")
                or restored.get("saved_tic") != saved.get("logical_tic")
                or restored.get("aura_state_hash") != saved.get("aura_state_hash")
                or restored.get("saved_aura_hash") != saved.get("aura_state_hash")
                or restored.get("healing_state_hash") != saved.get("healing_state_hash")
                or restored.get("saved_healing_hash") != saved.get("healing_state_hash")):
            errors.append("restore did not preserve the exact aura/healing state hash and logical tic")
    if load_rc != 0:
        errors.append(f"restore process exit was {load_rc}, expected clean quit")
    result = {
        "status": "PASS" if not errors else "FAIL",
        "claim": "MAP25 EventHandler aura ledger/debuff/growth/heart and healing-authority state survive engine save/reload",
        "package": str(package), "package_sha256": package_sha,
        "engine_sha256": lock["uzdoom"]["executable"]["sha256"],
        "save_rc": save_rc, "load_rc": load_rc,
        "save_file_size": save_file.stat().st_size if save_file else None,
        "save_state": save_rows[-1] if save_rows else None,
        "restore_state": restore_rows[-1] if restore_rows else None,
        "errors": errors, "evidence": str(evidence),
    }
    (evidence / "p039-map25-save-roundtrip.json").write_text(
        json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2), flush=True)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, default=ROOT / "build/doom-survivors.ipk3",
                        help="already-built package; this runner never builds")
    parser.add_argument("--camera-variant", type=int, choices=(0, 1, 2), default=0)
    parser.add_argument("--mode", choices=MODES, default="matrix")
    parser.add_argument("--vfx", type=int, choices=(0, 1), default=1)
    parser.add_argument("--seed", type=int, default=390039)
    parser.add_argument("--seconds", type=float, default=30.0)
    parser.add_argument("--validate-evidence", type=Path,
                        help="validate one existing evidence directory without launching")
    parser.add_argument("--compare-camera-evidence", nargs=4, type=Path,
                        metavar=("CAM0_VFX1", "CAM1_VFX1", "CAM2_VFX1", "CAM0_VFX0"))
    args = parser.parse_args()

    if args.compare_camera_evidence:
        report = _compare_camera_runs(args.compare_camera_evidence)
        report_path = args.compare_camera_evidence[0].resolve() / "p039-camera-vfx-invariance.json"
        report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(report, indent=2))
        return 0 if report["status"] == "PASS" else 1

    package = args.package.resolve()
    if not package.is_file():
        parser.error(f"package does not exist: {package}")
    package_sha = hashlib.sha256(package.read_bytes()).hexdigest()
    if args.mode == "save":
        if args.validate_evidence or args.compare_camera_evidence:
            parser.error("save mode owns its paired save/restore evidence and cannot use single-run validation options")
        report = _save_roundtrip(package, package_sha, args.seconds)
        return 0 if report.get("status") == "PASS" else 1

    startup_commands = [
        "+set", "ds_p039_mode", args.mode,
        "+set", "ds_p039_camera_variant", str(args.camera_variant),
        "+set", "ds_p039_seed", str(args.seed),
        "+set", "ds_p039_vfx", str(args.vfx),
    ]
    if args.validate_evidence:
        evidence = args.validate_evidence.resolve()
        result, log = _load_evidence(evidence)
        commands = result.get("startup_commands", [])
        for key, expected, converter in (
            ("ds_p039_mode", args.mode, str),
            ("ds_p039_camera_variant", args.camera_variant, int),
            ("ds_p039_seed", args.seed, int),
            ("ds_p039_vfx", args.vfx, int),
        ):
            try:
                actual = converter(commands[commands.index(key) + 1])
            except (ValueError, IndexError, TypeError):
                actual = None
            if actual != expected:
                parser.error(f"recorded startup command {key} differs from requested fixture")
    else:
        result = run(
            package, args.seconds, False, False, "P039", map_name="MAP25",
            completion_marker="DS_P039_MAP25_RUNTIME_PASS",
            startup_commands=startup_commands,
        )
        evidence = Path(result["evidence"])
        log = (evidence / "process.log").read_text(encoding="utf-8", errors="replace")

    validation = _validator_module().validate_p039_map25_runtime(
        log, str(result.get("status", "MISSING")), result.get("captures", []),
        args.mode, args.camera_variant, args.vfx)
    if result.get("package_sha256") != package_sha:
        validation["errors"].append("evidence package SHA differs from supplied package")
        validation["status"] = "FAIL"
    report = {
        **validation,
        "package": str(package),
        "package_sha256": package_sha,
        "engine_sha256": result.get("engine_sha256"),
        "run_status": result.get("status", "MISSING"),
        "camera_variant": args.camera_variant,
        "mode": args.mode,
        "vfx": args.vfx,
        "seed": args.seed,
        "captures": result.get("captures", []),
        "evidence": str(evidence),
    }
    (evidence / "p039-map25-validation.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0 if validation["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
