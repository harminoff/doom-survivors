"""Run and strictly validate the controlled MAP24 ground-field fixture."""
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


def _capture_manifest(source_dirs: list[Path], evidence: Path) -> list[dict]:
    from tools.run_probe import png_nonblank

    captures = []
    for source_dir in source_dirs:
        target_dir = evidence / source_dir.name
        target_dir.mkdir(parents=True, exist_ok=True)
        for path in sorted(source_dir.glob("*.png")):
            target = target_dir / path.name
            if path.resolve() != target.resolve():
                shutil.copy2(path, target)
            data = target.read_bytes()
            captures.append({"file": target.relative_to(evidence).as_posix(),
                             "bytes": len(data),
                             "sha256": hashlib.sha256(data).hexdigest(),
                             "nonblank": png_nonblank(data)})
    return captures


def _save_roundtrip(package: Path, package_sha: str, timeout: float,
                    camera_variant: int, vfx: int) -> dict[str, object]:
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    name = f"{stamp}-p038-map24-save-load"
    evidence = ROOT / "evidence/P038" / name
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
        'wait 100; screenshot; save ds_p038_ground "P038 Ground Fields"; wait 4; quit\n',
        encoding="utf-8", newline="\n")
    (profile / "load.cfg").write_text(
        'wait 100; screenshot; quit\n', encoding="utf-8", newline="\n")
    lock = json.loads((ROOT / "toolchain/lock.json").read_text(encoding="utf-8"))
    executable = ROOT / lock["uzdoom"]["executable"]["path"]
    common = ["+enablescriptscreenshot", "true", "+set", "ds_p038_mode", "save",
              "+set", "ds_p038_camera_variant", str(camera_variant),
              "+set", "ds_p038_vfx", str(vfx)]
    save_args = common + ["+screenshot_dir", save_capture.as_posix(),
                          "+map", "MAP24", "+exec", "save.cfg"]
    save_rc = run_engine(executable, package, profile, "p038-save.log", save_args,
                         timeout=timeout)
    save_log = read_log(profile, "p038-save.log")
    save_files = sorted(path for path in profile.glob("ds_p038_ground*") if path.is_file())
    save_file = save_files[0] if save_files else None
    load_rc = None
    load_log = ""
    if save_file is not None:
        (profile / "config.ini").write_text(config_text(load_capture, vsync=False),
                                            encoding="utf-8", newline="\n")
        load_args = ["-loadgame", save_file.stem] + common + [
            "+screenshot_dir", load_capture.as_posix(), "+exec", "load.cfg"]
        load_rc = run_engine(executable, package, profile, "p038-load.log", load_args,
                             timeout=timeout)
        load_log = read_log(profile, "p038-load.log")
    (evidence / "save-engine.log").write_text(save_log, encoding="utf-8", newline="\n")
    (evidence / "load-engine.log").write_text(load_log, encoding="utf-8", newline="\n")
    shutil.copy2(profile / "save.cfg", evidence / "save.cfg")
    shutil.copy2(profile / "load.cfg", evidence / "load.cfg")
    if save_file is not None:
        shutil.copy2(save_file, evidence / save_file.name)
    captures = _capture_manifest([save_capture, load_capture], evidence)
    validator = _validator_module()
    combined = save_log + "\n" + load_log
    runtime_validation = validator.validate_p038_map24_runtime(
        combined, "RUNTIME_PASS" if "DS_P038_MAP24_RUNTIME_PASS" in load_log else "MISSING",
        captures, camera_variant, vfx, "save")
    save_rows = validator._log_rows(save_log, "DS_P038_MAP24_SAVE_STATE")
    restore_rows = validator._log_rows(load_log, "DS_P038_MAP24_RESTORE")
    errors = list(runtime_validation["errors"])
    if save_rc != 0:
        errors.append(f"save process exit was {save_rc}, expected clean quit")
    if save_file is None or save_file.stat().st_size <= 0:
        errors.append("UZDoom did not create a non-empty MAP24 run save")
    if len(save_rows) != 1 or save_rows[0].get("accepted") != "1":
        errors.append("active field/hit-ledger save boundary was not recorded exactly once")
    if len(restore_rows) != 1:
        errors.append("restored EventHandler did not report its first-tick state")
    else:
        try:
            saved = save_rows[0]
            restored = restore_rows[0]
            if (restored.get("accepted") != "1" or restored.get("first_tick") != "1"
                    or restored.get("logical_tic") != saved.get("logical_tic")
                    or restored.get("saved_tic") != saved.get("logical_tic")
                    or restored.get("state_hash") != saved.get("state_hash")
                    or restored.get("saved_hash") != saved.get("state_hash")
                    or restored.get("fields") != saved.get("fields")
                    or restored.get("bottles") != saved.get("bottles")
                    or restored.get("hit_ledger") != saved.get("hit_ledger")):
                errors.append("restore did not preserve the exact active field, bottle, ledger and logical-tic snapshot")
            marker_index = load_log.find("DS_P038_MAP24_RESTORE")
            continuation = [row for row in validator._log_rows(load_log, "DS_P038_FIELD_HIT")
                            if row.get("source_system") == "46"
                            and int(row.get("tic", "-1")) > int(saved["logical_tic"])]
            continuation_offset = min(
                (match.start() for match in re.finditer(
                    r"DS_P038_FIELD_HIT[^\r\n]*tic=51(?:\s|$)", load_log)),
                default=-1)
            pre_save_hits = [row for row in validator._log_rows(save_log, "DS_P038_FIELD_HIT")
                             if row.get("source_system") == "46"
                             and int(row.get("tic", "-1")) <= int(saved["logical_tic"])]
            latest_pre_save = max(pre_save_hits, key=lambda row: int(row["tic"])) if pre_save_hits else {}
            if (marker_index < 0 or not continuation
                    or int(saved["logical_tic"]) != 35
                    or int(saved["fields"]) < 1
                    or int(saved["hit_ledger"]) < 1
                    or latest_pre_save.get("ready_tic") != "51"
                    or min(int(row["tic"]) for row in continuation) != 51
                    or any(row.get("field_id") != latest_pre_save.get("field_id")
                           for row in continuation)
                    or continuation_offset <= marker_index):
                errors.append("restored Holy Water field did not resume its saved rehit deadline and damage schedule")
        except (KeyError, ValueError, TypeError):
            errors.append("save/restore marker payload is malformed")
    if load_rc != 0:
        errors.append(f"restore process exit was {load_rc}, expected clean quit")
    capture_groups = {Path(str(row.get("file", ""))).parts[0]
                      for row in captures if row.get("nonblank") is True}
    if (len(captures) < 2 or any(row.get("nonblank") is not True for row in captures)
            or not {"save-captures", "load-captures"} <= capture_groups):
        errors.append("save and restored process did not provide nonblank UZDoom frames")
    result = {
        "status": "PASS" if not errors else "FAIL",
        "claim": "MAP24 EventHandler field, bottle, cadence ledger and next-hit schedule survive engine save/reload",
        "package": str(package), "package_sha256": package_sha,
        "engine_sha256": lock["uzdoom"]["executable"]["sha256"],
        "save_rc": save_rc, "load_rc": load_rc,
        "save_file_size": save_file.stat().st_size if save_file else None,
        "source_rebuild_performed": False,
        "save_state": save_rows[-1] if save_rows else None,
        "restore_state": restore_rows[-1] if restore_rows else None,
        "captures": captures, "errors": errors, "evidence": str(evidence),
    }
    (evidence / "p038-map24-save-roundtrip.json").write_text(
        json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2), flush=True)
    return result


def _validator_module():
    path = ROOT / "tests/runtime/weapons-ground/test_p038_ground_data.py"
    spec = importlib.util.spec_from_file_location("p038_ground_validator", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load MAP24 validator: {path}")
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
    rows = _validator_module()._log_rows(log, "DS_P038_FIELD_HIT")
    return [tuple(row.get(key, "") for key in (
        "tic", "field_id", "field_generation", "source_system", "rank",
        "target_id", "accepted_delta_milli", "damage_milli", "before", "after"))
        for row in rows]


def _compare_runs(directories: list[Path]) -> dict[str, object]:
    errors: list[str] = []
    expected = [(0, 1), (1, 1), (2, 1), (0, 0)]
    logs: list[str] = []
    package_shas: set[str] = set()
    runs: list[dict[str, object]] = []
    validator = _validator_module()
    for directory, (camera, vfx) in zip(directories, expected):
        try:
            result, log = _load_evidence(directory.resolve())
        except (OSError, ValueError, json.JSONDecodeError) as exc:
            errors.append(str(exc))
            continue
        package_shas.add(str(result.get("package_sha256", "")))
        logs.append(log)
        commands = result.get("startup_commands", [])
        try:
            recorded_camera = int(commands[commands.index("ds_p038_camera_variant") + 1])
            recorded_vfx = int(commands[commands.index("ds_p038_vfx") + 1])
            recorded_mode = str(commands[commands.index("ds_p038_mode") + 1])
        except (ValueError, IndexError, TypeError):
            recorded_camera, recorded_vfx, recorded_mode = -1, -1, ""
        if (recorded_camera, recorded_vfx, recorded_mode) != (camera, vfx, "matrix"):
            errors.append(f"{directory}: recorded MAP24 startup fixture differs from expected {(camera, vfx, 'matrix')}")
        single = validator.validate_p038_map24_runtime(
            log, str(result.get("status", "MISSING")), result.get("captures", []), camera, vfx)
        persisted_path = directory.resolve() / "p038-map24-validation.json"
        if not persisted_path.is_file():
            errors.append(f"{directory}: strict MAP24 validation artifact is missing")
        else:
            persisted = json.loads(persisted_path.read_text(encoding="utf-8"))
            if (persisted.get("status") != "PASS"
                    or persisted.get("package_sha256") != result.get("package_sha256")
                    or persisted.get("camera_variant") != camera
                    or persisted.get("vfx") != vfx):
                errors.append(f"{directory}: persisted strict validation does not match this run")
        if single["status"] != "PASS":
            errors.extend(f"{directory.name}: {error}" for error in single["errors"])
        runs.append({"evidence": str(directory.resolve()), "camera_variant": camera,
                     "vfx": vfx, "run_status": result.get("status"),
                     "package_sha256": result.get("package_sha256"), "validation": single})
    if len(package_shas) != 1 or "" in package_shas:
        errors.append("all four camera/VFX runs must use one identified package SHA")
    tuples = [_hit_tuples(log) for log in logs]
    if len(tuples) != 4 or any(not row for row in tuples):
        errors.append("one or more camera/VFX runs lack actual accepted field-hit records")
    elif any(row != tuples[0] for row in tuples[1:]):
        errors.append("accepted logical hit tuples changed with camera or cosmetic VFX")
    return {
        "status": "PASS" if not errors else "FAIL",
        "claim": "MAP24 accepted logical hit tuples are invariant across yaw, pitch/FOV, and cosmetic VFX toggle",
        "package_sha256": next(iter(package_shas)) if len(package_shas) == 1 else None,
        "hit_tuple_count": len(tuples[0]) if tuples else 0,
        "hit_tuples": [list(row) for row in tuples[0]] if tuples else [],
        "runs": runs,
        "errors": errors,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, default=ROOT / "build/doom-survivors.ipk3",
                        help="already-built package; this runner never builds")
    parser.add_argument("--camera-variant", type=int, choices=(0, 1, 2), default=0,
                        help="0=default, 1=yaw90, 2=pitch22/FOV115")
    parser.add_argument("--mode", choices=("matrix", "tie_ring", "overlap", "pool",
                        "bora_motion", "transform", "high_area_duration",
                        "pause", "save"), default="matrix",
                        help="controlled MAP24 actual-engine scenario")
    parser.add_argument("--vfx", type=int, choices=(0, 1), default=1,
                        help="controlled field-proxy toggle; must not change logical damage")
    parser.add_argument("--seed", type=int, default=380038)
    parser.add_argument("--seconds", type=float, default=30.0,
                        help="bounded real-time UZDoom deadline")
    parser.add_argument("--validate-evidence", type=Path,
                        help="validate one existing evidence directory without launching")
    parser.add_argument("--compare-invariance-evidence", nargs=4, type=Path,
                        metavar=("CAM0_VFX1", "CAM1_VFX1", "CAM2_VFX1", "CAM0_VFX0"),
                        help="validate and compare four existing same-package runs")
    args = parser.parse_args()

    if args.compare_invariance_evidence:
        report = _compare_runs(args.compare_invariance_evidence)
        report_path = args.compare_invariance_evidence[0].resolve() / "p038-camera-vfx-invariance.json"
        report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(report, indent=2))
        return 0 if report["status"] == "PASS" else 1

    package = args.package.resolve()
    if not package.is_file():
        parser.error(f"package does not exist: {package}")
    package_sha = hashlib.sha256(package.read_bytes()).hexdigest()
    if args.mode == "save":
        if args.validate_evidence or args.compare_invariance_evidence:
            parser.error("save mode owns its paired save/restore evidence and cannot use single-run validation options")
        report = _save_roundtrip(package, package_sha, args.seconds,
                                 args.camera_variant, args.vfx)
        return 0 if report.get("status") == "PASS" else 1
    startup_commands = [
        "+set", "ds_p038_mode", args.mode,
        "+set", "ds_p038_camera_variant", str(args.camera_variant),
        "+set", "ds_p038_seed", str(args.seed),
        "+set", "ds_p038_vfx", str(args.vfx),
    ]
    if args.validate_evidence:
        evidence = args.validate_evidence.resolve()
        result, log = _load_evidence(evidence)
        commands = result.get("startup_commands", [])
        for key, expected, converter in (
            ("ds_p038_mode", args.mode, str),
            ("ds_p038_camera_variant", args.camera_variant, int),
            ("ds_p038_seed", args.seed, int),
            ("ds_p038_vfx", args.vfx, int),
        ):
            try:
                actual = converter(commands[commands.index(key) + 1])
            except (ValueError, IndexError, TypeError):
                actual = None
            if actual != expected:
                parser.error(f"recorded startup command {key} differs from requested fixture")
    else:
        result = run(
            package, args.seconds, False, False, "P038", map_name="MAP24",
            completion_marker="DS_P038_MAP24_RUNTIME_PASS",
            startup_commands=startup_commands,
        )
        evidence = Path(result["evidence"])
        log = (evidence / "process.log").read_text(encoding="utf-8", errors="replace")

    validation = _validator_module().validate_p038_map24_runtime(
        log, str(result.get("status", "MISSING")), result.get("captures", []),
        args.camera_variant, args.vfx, args.mode)
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
    (evidence / "p038-map24-validation.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0 if validation["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
