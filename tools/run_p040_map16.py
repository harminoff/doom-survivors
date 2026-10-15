"""Run strict opt-in MAP16 P040 (logical-screen strike/erasure/global-effect)
and serialized continuation probes.

Modeled directly on tools/run_p039_map16.py, mirroring its full/save-load/
default-smoke structure exactly.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tools.run_persistence_bench import read_log, run_engine
from tools.run_probe import config_text, run
from tools.run_p033_stats import _capture_manifest


def _validator_module():
    path = ROOT / "tests/runtime/weapons-global/test_p040_map16.py"
    spec = importlib.util.spec_from_file_location("p040_map16_validator", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load MAP16 validator: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _write_report(evidence: Path, report: dict[str, object]) -> None:
    (evidence / "p040-map16-validation.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8")


def run_full(package: Path, seconds: float = 80.0) -> dict[str, object]:
    package = package.resolve()
    package_sha = hashlib.sha256(package.read_bytes()).hexdigest()
    started = run(
        package, seconds, False, False, "P040", map_name="MAP16",
        completion_marker="DS_P030_COMPLETE",
        startup_commands=[
            "+set", "ds_p030_mode", "p040",
            "+set", "ds_p032_mode", "evolution",
            "+set", "ds_p030_duration_tics", "2100",
            "+set", "ds_p030_speed", "1",
            "+set", "ds_p030_camera_variant", "0",
            "+set", "ds_p030_telemetry", "1",
            "+set", "ds_p033_save_snapshot_request", "0",
        ],
    )
    evidence = Path(started["evidence"])
    log = (evidence / "engine.log").read_text(encoding="utf-8", errors="replace")
    validation = _validator_module().validate_p040_map16_runtime(
        log, str(started.get("status", "MISSING")), started.get("captures", []))
    if started.get("package_sha256") != package_sha:
        validation["errors"].append("runtime package SHA differs from supplied package")
        validation["status"] = "FAIL"
    report = {
        **validation,
        "classification": "P040_MAP16_CONTROLLED_PLAYABLE_INTEGRATION",
        "package": str(package),
        "package_sha256": package_sha,
        "engine_sha256": started.get("engine_sha256"),
        "run_status": started.get("status"),
        "captures": started.get("captures", []),
        "evidence": str(evidence),
        "build_performed": False,
    }
    _write_report(evidence, report)
    return report


def run_default_smoke(package: Path, seconds: float = 30.0) -> dict[str, object]:
    package = package.resolve()
    package_sha = hashlib.sha256(package.read_bytes()).hexdigest()
    started = run(
        package, seconds, False, False, "P040", map_name="MAP16",
        completion_marker="DS_P030_COMPLETE",
        startup_commands=[
            "+set", "ds_p030_mode", "manual",
            "+set", "ds_p030_duration_tics", "2100",
            "+set", "ds_p030_speed", "1",
            "+set", "ds_p030_camera_variant", "0",
            "+set", "ds_p030_telemetry", "1",
        ],
    )
    evidence = Path(started["evidence"])
    log = (evidence / "engine.log").read_text(encoding="utf-8", errors="replace")
    validation = _validator_module().validate_p040_map16_default(log)
    if not started.get("captures") or not any(
            bool(row.get("nonblank")) for row in started.get("captures", [])):
        validation["errors"].append("default-route smoke lacks a nonblank capture")
    if started.get("package_sha256") != package_sha:
        validation["errors"].append("smoke package SHA differs from supplied package")
    status = "PASS_BOUNDED_DEFAULT" if not validation["errors"] else "FAIL"
    report = {
        **validation,
        "status": status,
        "classification": "P030_DEFAULT_MANUAL_ROUTE_EXCLUSION_SMOKE",
        "package": str(package),
        "package_sha256": package_sha,
        "run_status": started.get("status"),
        "captures": started.get("captures", []),
        "evidence": str(evidence),
        "build_performed": False,
        "complete_run_claim": False,
    }
    _write_report(evidence, report)
    return report


def run_roundtrip(package: Path, timeout: float = 105.0,
                  wait_tics: int = 500) -> dict[str, object]:
    package = package.resolve()
    if not package.is_file():
        return {"status": "FAIL", "errors": [f"missing package: {package}"]}
    package_sha = hashlib.sha256(package.read_bytes()).hexdigest()
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    name = f"{stamp}-p040-map16-save-load"
    evidence = ROOT / "evidence/P040" / name
    evidence.mkdir(parents=True)
    profile = ROOT / ".local/probes" / name
    profile.mkdir(parents=True)
    save_capture = evidence / "save-captures"
    restore_capture = evidence / "restore-captures"
    save_capture.mkdir()
    restore_capture.mkdir()
    save_name = "ds_p040_map16"
    save_script = profile / "save.cfg"
    restore_script = profile / "restore.cfg"
    save_script.write_text(
        f"set ds_p033_save_snapshot_request 1; wait {wait_tics}; "
        f'screenshot; save {save_name} "P040 global-strike runtime state"; '
        "set ds_p033_save_snapshot_request 0; wait 8; quit\n",
        encoding="utf-8", newline="\n")
    restore_script.write_text(
        "wait 150; screenshot; wait 120; quit\n",
        encoding="utf-8", newline="\n")
    (profile / "config.ini").write_text(config_text(save_capture, vsync=False),
                                        encoding="utf-8", newline="\n")
    lock = json.loads((ROOT / "toolchain/lock.json").read_text(encoding="utf-8"))
    executable = ROOT / lock["uzdoom"]["executable"]["path"]
    save_args = ["+enablescriptscreenshot", "true",
                 "+set", "ds_p030_mode", "p040",
                 "+set", "ds_p032_mode", "evolution",
                 "+set", "ds_p030_duration_tics", "2100",
                 "+set", "ds_p030_speed", "1",
                 "+set", "ds_p030_camera_variant", "0",
                 "+set", "ds_p030_telemetry", "1",
                 "+set", "ds_p033_save_snapshot_request", "0",
                 "+map", "MAP16", "+exec", save_script.name]
    save_rc = run_engine(executable, package, profile, "p040-map16-save.log",
                         save_args, timeout=timeout)
    save_log = read_log(profile, "p040-map16-save.log")
    saves = sorted((path for path in profile.glob(f"{save_name}*") if path.is_file()),
                   key=lambda path: path.stat().st_mtime_ns)
    save_file = saves[-1] if saves else None

    restore_rc: int | None = None
    restore_log = ""
    if save_file is not None:
        (profile / "config.ini").write_text(config_text(restore_capture, vsync=False),
                                            encoding="utf-8", newline="\n")
        restore_args = ["-loadgame", save_file.stem,
                        "+enablescriptscreenshot", "true",
                        "+set", "ds_p030_mode", "p040",
                        "+set", "ds_p032_mode", "evolution",
                        "+set", "ds_p030_speed", "1",
                        "+set", "ds_p030_camera_variant", "0",
                        "+set", "ds_p030_telemetry", "1",
                        "+exec", restore_script.name]
        restore_rc = run_engine(executable, package, profile,
                                "p040-map16-restore.log", restore_args,
                                timeout=timeout)
        restore_log = read_log(profile, "p040-map16-restore.log")

    (evidence / "save-engine.log").write_text(save_log, encoding="utf-8", newline="\n")
    (evidence / "restore-engine.log").write_text(restore_log, encoding="utf-8", newline="\n")
    shutil.copy2(save_script, evidence / save_script.name)
    shutil.copy2(restore_script, evidence / restore_script.name)
    validation = _validator_module().validate_p040_map16_save_roundtrip(
        save_log, restore_log, save_rc, restore_rc)
    captures = _capture_manifest([save_capture, restore_capture], evidence)
    errors = list(validation["errors"])
    if save_file is None or save_file.stat().st_size <= 0:
        errors.append("UZDoom did not create a nonempty serialized MAP16 save")
    if len(captures) < 2 or any(not row["nonblank"] for row in captures):
        errors.append("save/restore sessions lack two nonblank UZDoom captures")
    if save_file is not None:
        shutil.copy2(save_file, evidence / save_file.name)
    report = {
        "status": "PASS" if not errors else "FAIL",
        "classification": "P040_MAP16_SERIALIZED_GLOBAL_STRIKE_CONTINUATION",
        "package": str(package),
        "package_sha256": package_sha,
        "source_rebuild_performed": False,
        "save_exit_code": save_rc,
        "restore_exit_code": restore_rc,
        "save_file_size": save_file.stat().st_size if save_file else None,
        "validation": validation,
        "screenshots": captures,
        "evidence": str(evidence),
        "errors": errors,
    }
    (evidence / "roundtrip.json").write_text(json.dumps(report, indent=2) + "\n",
                                             encoding="utf-8")
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path,
                        default=ROOT / "build/doom-survivors.ipk3")
    parser.add_argument("--mode", choices=("full", "save-load", "default-smoke"),
                        default="full")
    parser.add_argument("--seconds", type=float, default=80.0)
    parser.add_argument("--timeout", type=float, default=105.0)
    parser.add_argument("--wait-tics", type=int, default=500)
    args = parser.parse_args()
    if args.mode == "save-load":
        result = run_roundtrip(args.package, args.timeout, args.wait_tics)
    elif args.mode == "default-smoke":
        result = run_default_smoke(args.package, min(max(args.seconds, 20.0), 180.0))
    else:
        result = run_full(args.package, min(max(args.seconds, 20.0), 180.0))
    print(json.dumps(result, indent=2), flush=True)
    return 0 if result.get("status") in ("PASS", "PASS_BOUNDED_STREAM",
                                          "PASS_BOUNDED_DEFAULT") else 1


if __name__ == "__main__":
    raise SystemExit(main())
