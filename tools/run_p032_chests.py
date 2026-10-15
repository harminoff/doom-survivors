"""Build-independent strict UZDoom runner for P032 chest gates."""
from __future__ import annotations

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


def _load_validator():
    path = ROOT / "tests/runtime/chests/test_p032_chests.py"
    spec = importlib.util.spec_from_file_location("p032_chest_validator", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("unable to load strict P032 chest validator")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.validate_p032_run


def _load_graph_validator():
    path = ROOT / "tests/runtime/chests/test_p032_chests.py"
    spec = importlib.util.spec_from_file_location("p032_chest_graph_validator", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("unable to load strict P032 graph matrix validator")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.validate_graph_matrix


def _log(result: dict) -> str:
    path = Path(result["evidence"]) / "engine.log"
    return path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""


def _rows(log: str, marker: str) -> list[dict[str, str]]:
    import re
    rows = []
    for match in re.finditer(rf"{re.escape(marker)}[ \t]+([^\r\n]*)", log):
        rows.append(dict(re.findall(r"([A-Za-z_][A-Za-z0-9_]*)=([^\s]+)", match.group(1))))
    return rows


def _save_load_probe(package: Path, timeout: float) -> dict:
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    name = f"{stamp}-p032-chest-save-load"
    evidence = ROOT / "evidence" / "P032" / name
    evidence.mkdir(parents=True)
    profile = ROOT / ".local/probes" / name
    profile.mkdir(parents=True)
    (profile / "config.ini").write_text(config_text(evidence, vsync=False), encoding="utf-8", newline="\n")
    (profile / "save.cfg").write_text(
        'wait 100; save ds_p032_mid_chest "P032 Mid Chest"; wait 4; quit\n',
        encoding="utf-8", newline="\n",
    )
    (profile / "load.cfg").write_text("wait 100; quit\n", encoding="utf-8", newline="\n")
    lock = json.loads((ROOT / "toolchain/lock.json").read_text(encoding="utf-8"))
    executable = ROOT / lock["uzdoom"]["executable"]["path"]
    setup = ["+enablescriptscreenshot", "true", "+screenshot_dir", evidence.as_posix(),
             "+set", "ds_p032_mode", "save_after_slot", "+map", "MAP18", "+exec", "save.cfg"]
    save_rc = run_engine(executable, package, profile, "p032-save.log", setup, timeout=timeout)
    save_log = read_log(profile, "p032-save.log")
    save_files = sorted(path for path in profile.glob("ds_p032_mid_chest*") if path.is_file())
    save_file = save_files[0] if save_files else None
    load_rc = None
    load_log = ""
    if save_file is not None:
        load_args = ["-loadgame", save_file.stem, "+enablescriptscreenshot", "true",
                     "+screenshot_dir", evidence.as_posix(), "+set", "ds_p032_mode",
                     "restore_duplicate_confirm", "+exec", "load.cfg"]
        load_rc = run_engine(executable, package, profile, "p032-load.log", load_args, timeout=timeout)
        load_log = read_log(profile, "p032-load.log")
    (evidence / "save-engine.log").write_text(save_log, encoding="utf-8", newline="\n")
    (evidence / "load-engine.log").write_text(load_log, encoding="utf-8", newline="\n")
    shutil.copy2(profile / "save.cfg", evidence / "save.cfg")
    shutil.copy2(profile / "load.cfg", evidence / "load.cfg")

    ready = _rows(save_log, "DS_P032_SAVE_READY")
    restored = _rows(load_log, "DS_P032_SAVE_RESTORE")
    errors: list[str] = []
    if save_rc != 0:
        errors.append(f"save process exit was {save_rc}, expected clean quit")
    if save_file is None or save_file.stat().st_size <= 0:
        errors.append("UZDoom did not create a non-empty mid-chest save")
    if len(ready) != 1:
        errors.append("save did not reach exactly one held-modal save-ready marker")
    if not any(row.get("applied") == "1" for row in ready):
        errors.append("save did not occur after exactly one committed reward slot")
    if load_rc != 0:
        errors.append(f"load process exit was {load_rc}, expected clean quit")
    if len(restored) != 1:
        errors.append("load did not restore exactly one active chest modal")
    if ready and restored:
        for key in ("chest_hash", "inventory_hash", "queue", "active_chest"):
            if ready[0].get(key) != restored[0].get(key):
                errors.append(f"restored {key} differs from saved chest state")
        if ready[0].get("applied") != restored[0].get("slot"):
            errors.append("restored applied slot differs from saved chest state")
        if ready[0].get("queue") != "1" or ready[0].get("applied") != "1":
            errors.append("save-ready state did not preserve one active chest and one applied slot")
    if not _rows(load_log, "DS_P032_RESTORE_STALE_INTENT"):
        errors.append("restored runtime did not replay a stale prior-slot intent for rejection")
    if not any(row.get("reason") == "STALE_OR_DUPLICATE" for row in _rows(load_log, "DS_P032_CONFIRM_REJECT")):
        errors.append("restored runtime did not reject the stale prior-slot confirmation")
    if len([row for row in _rows(save_log, "DS_P032_ATOMIC_REWARD") if row.get("accepted") == "1"]) != 1:
        errors.append("save process did not commit exactly one inventory reward")
    if len([row for row in _rows(load_log, "DS_P032_ATOMIC_REWARD") if row.get("accepted") == "1"]) != 2:
        errors.append("post-load run did not commit exactly the two remaining rewards")
    if not any(row.get("mode") == "restore_duplicate_confirm" for row in _rows(load_log, "DS_P032_RUNTIME_PASS")):
        errors.append("restored scenario did not resume to a completed runtime pass")

    captures = sorted(set(profile.glob("*.png")) | set(evidence.glob("*.png")))
    screenshot_manifest = []
    for capture in captures:
        if capture.parent != evidence:
            target = evidence / capture.name
            shutil.copy2(capture, target)
            capture = target
        data = capture.read_bytes()
        screenshot_manifest.append({"file": capture.name, "bytes": len(data),
                                    "sha256": hashlib.sha256(data).hexdigest()})
    if not screenshot_manifest:
        errors.append("save/load did not capture a UZDoom chest modal framebuffer")
    if save_file is not None:
        shutil.copy2(save_file, evidence / save_file.name)
    result = {"status": "PASS" if not errors else "FAIL", "evidence": str(evidence),
              "save_file": str(save_file) if save_file else None, "save_rc": save_rc,
              "load_rc": load_rc, "ready": ready[-1] if ready else None,
              "restore": restored[-1] if restored else None,
              "screenshots": screenshot_manifest, "errors": errors}
    (evidence / "roundtrip.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return result


def run_suite(package: Path, *, timeout: float = 25.0, skip_compile: bool = False) -> dict:
    if not package.is_file():
        return {"status": "FAIL", "errors": [f"missing package: {package}"]}
    compile_result = None if skip_compile else run(package, timeout, True, False, "P032", map_name="MAP18")
    if compile_result is not None and compile_result.get("status") != "COMPILE_PASS":
        return {"status": "FAIL", "compile": compile_result, "errors": ["pinned UZDoom compile failed"]}
    validator = _load_validator()
    modes = ("evolution", "slots1", "slots3", "slots5", "bronze_late", "queue", "duplicate_confirm")
    runs: dict[str, dict] = {}
    errors: list[str] = []
    for mode in modes:
        result = run(package, timeout, False, False, "P032", map_name="MAP18",
                     completion_marker="DS_P032_RUNTIME_PASS",
                     startup_commands=["+set", "ds_p032_mode", mode])
        log = _log(result)
        validation = validator(log, mode, result.get("status", "UNKNOWN"))
        runs[mode] = {"run": result, "validation": validation}
        if validation["status"] != "PASS":
            errors.extend(f"{mode}: {error}" for error in validation["errors"])
        if result.get("status") != "RUNTIME_PASS":
            errors.append(f"{mode}: UZDoom runner status was {result.get('status')}, expected RUNTIME_PASS")

    save_load = _save_load_probe(package, timeout)
    if save_load["status"] != "PASS":
        errors.extend(f"save/load: {error}" for error in save_load["errors"])
    result = {"status": "PASS" if not errors else "FAIL",
              "classification": "P032_PACKAGED_UZDOOM_CHEST_REWARD_TRANSFORMATION",
              "package": str(package), "package_sha256": hashlib.sha256(package.read_bytes()).hexdigest(),
              "compile": compile_result, "runs": runs, "save_load": save_load, "errors": errors}
    out = Path(runs["evolution"]["run"]["evidence"]) / "p032-suite.json"
    out.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    result["suite_result"] = str(out)
    return result


def run_graph_matrix(package: Path, *, timeout: float = 25.0) -> dict:
    """Pinned compile plus one strict MAP18 graph matrix runtime probe."""
    if not package.is_file():
        return {"status": "FAIL", "errors": [f"missing package: {package}"]}
    package_sha = hashlib.sha256(package.read_bytes()).hexdigest()
    compile_result = run(package, timeout, True, False, "P032", map_name="MAP18")
    if compile_result.get("status") != "COMPILE_PASS":
        return {"status": "FAIL", "package": str(package), "package_sha256": package_sha,
                "compile": compile_result, "errors": ["pinned UZDoom compile failed"]}

    run_result = run(package, timeout, False, False, "P032",
                     map_name="MAP18", completion_marker="DS_P032_GRAPH_MATRIX_DONE",
                     startup_commands=["+set", "ds_p032_mode", "graph_matrix"])
    log = _log(run_result)
    validation = _load_graph_validator()(log, run_result.get("status", "UNKNOWN"))
    errors = list(validation["errors"])
    if run_result.get("status") != "RUNTIME_PASS":
        errors.append(f"UZDoom runner status was {run_result.get('status')}, expected RUNTIME_PASS")
    captures = run_result.get("captures", [])
    if not captures or not any(capture.get("nonblank") for capture in captures):
        errors.append("matrix runtime did not produce a nonblank UZDoom framebuffer capture")
    result = {"status": "PASS" if not errors else "FAIL",
              "classification": "P032_CONTROLLED_GRAPH_PREDICATE_AND_TRANSACTION_MATRIX",
              "package": str(package), "package_sha256": package_sha,
              "compile": compile_result, "run": run_result,
              "validation": validation, "errors": errors}
    evidence = Path(run_result["evidence"])
    out = evidence / "p032-graph-matrix.json"
    out.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    result["result_file"] = str(out)
    return result


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, default=ROOT / "build/doom-survivors.ipk3")
    parser.add_argument("--timeout", type=float, default=25.0)
    parser.add_argument("--skip-compile", action="store_true")
    parser.add_argument("--graph-matrix-only", action="store_true",
                        help="run only the pinned compile and focused MAP18 graph matrix probe")
    args = parser.parse_args()
    if args.graph_matrix_only:
        result = run_graph_matrix(args.package, timeout=args.timeout)
    else:
        result = run_suite(args.package, timeout=args.timeout, skip_compile=args.skip_compile)
    print(json.dumps(result, indent=2), flush=True)
    raise SystemExit(0 if result["status"] == "PASS" else 1)
