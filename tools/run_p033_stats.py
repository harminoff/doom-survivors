"""Validate a supplied package in pinned UZDoom; source packaging is separate.

Rebuild first with ``python tools/build.py --room-spec
maps/source/p033-stats/room.json`` (and any desired additional room specs), then
pass the resulting package with ``--package``. The compile gate below compiles
that exact IPK3; it does not rebuild it from the working tree.
"""
from __future__ import annotations

import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tests.runtime.stats.test_p033_stats import validate_p033_runtime
from tools.run_persistence_bench import read_log, run_engine
from tools.run_probe import config_text, run


def _run_log(result: dict) -> str:
    path = Path(result["evidence"]) / "engine.log"
    return path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""


def _capture_manifest(source_dirs: list[Path], evidence: Path) -> list[dict]:
    from tools.run_probe import png_nonblank

    captures = []
    for source_dir in source_dirs:
        for path in sorted(source_dir.glob("*.png")):
            target_dir = evidence / source_dir.name
            target_dir.mkdir(parents=True, exist_ok=True)
            target = target_dir / path.name
            if path.resolve() != target.resolve():
                shutil.copy2(path, target)
            data = target.read_bytes()
            captures.append({"file": target.relative_to(evidence).as_posix(),
                             "bytes": len(data),
                             "sha256": hashlib.sha256(data).hexdigest(),
                             "nonblank": png_nonblank(data)})
    return captures


def _save_roundtrip(package: Path, timeout: float = 30.0) -> dict:
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    name = f"{stamp}-p033-stat-save-load"
    evidence = ROOT / "evidence/P033" / name
    evidence.mkdir(parents=True)
    profile = ROOT / ".local/probes" / name
    profile.mkdir(parents=True)
    save_capture = evidence / "save-captures"
    load_capture = evidence / "load-captures"
    save_capture.mkdir()
    load_capture.mkdir()
    (profile / "config.ini").write_text(config_text(evidence, vsync=False),
                                        encoding="utf-8", newline="\n")
    (profile / "save.cfg").write_text(
        'wait 100; save ds_p033_stats "P033 Stats"; wait 4; quit\n',
        encoding="utf-8", newline="\n")
    (profile / "load.cfg").write_text("wait 40; quit\n", encoding="utf-8", newline="\n")
    lock = json.loads((ROOT / "toolchain/lock.json").read_text(encoding="utf-8"))
    executable = ROOT / lock["uzdoom"]["executable"]["path"]
    save_common = ["+enablescriptscreenshot", "true", "+screenshot_dir", save_capture.as_posix()]
    load_common = ["+enablescriptscreenshot", "true", "+screenshot_dir", load_capture.as_posix()]
    save_args = save_common + ["+set", "ds_p033_mode", "save_prepare", "+map", "MAP19",
                          "+exec", "save.cfg"]
    save_rc = run_engine(executable, package, profile, "p033-save.log", save_args,
                         timeout=timeout)
    save_log = read_log(profile, "p033-save.log")
    save_files = sorted(path for path in profile.glob("ds_p033_stats*") if path.is_file())
    save_file = save_files[0] if save_files else None
    load_rc = None
    load_log = ""
    if save_file is not None:
        load_args = ["-loadgame", save_file.stem] + load_common + ["+set", "ds_p033_mode",
            "restore", "+exec", "load.cfg"]
        load_rc = run_engine(executable, package, profile, "p033-load.log", load_args,
                             timeout=timeout)
        load_log = read_log(profile, "p033-load.log")
    (evidence / "save-engine.log").write_text(save_log, encoding="utf-8", newline="\n")
    (evidence / "load-engine.log").write_text(load_log, encoding="utf-8", newline="\n")
    shutil.copy2(profile / "save.cfg", evidence / "save.cfg")
    shutil.copy2(profile / "load.cfg", evidence / "load.cfg")
    save_rows = _rows(save_log, "DS_P033_SAVE_READY")
    restore_rows = _rows(load_log, "DS_P033_SAVE_RESTORE")
    pass_rows = _rows(load_log, "DS_P033_SAVE_RUNTIME_PASS")
    errors: list[str] = []
    if save_rc != 0:
        errors.append(f"save process exit was {save_rc}, expected clean quit")
    if save_file is None or save_file.stat().st_size <= 0:
        errors.append("UZDoom did not create a non-empty run save")
    if len(save_rows) != 1:
        errors.append("save process did not publish exactly one resolved-state snapshot")
    elif (save_rows[0].get("source_ranks") != "2,3,1,2"
          or save_rows[0].get("rank_hash") != "2063135"
          or save_rows[0].get("might_milli") != "1200"
          or save_rows[0].get("armor_points") != "4"
          or save_rows[0].get("max_health_milli") != "144000"
          or save_rows[0].get("cooldown_multiplier_milli") != "840"):
        errors.append("saved resolved values/source ranks differ from the controlled fixture")
    if load_rc != 0:
        errors.append(f"load process exit was {load_rc}, expected clean quit")
    if len(restore_rows) != 1 or restore_rows[0].get("accepted") != "1" or restore_rows[0].get("stable") != "1":
        errors.append("restored source ranks did not recompute to the same resolved snapshot")
    if len(pass_rows) != 1 or pass_rows[0].get("stable") != "1":
        errors.append("restored stat runtime did not complete the stable-state probe")
    captures = _capture_manifest([save_capture, load_capture], evidence)
    if len(captures) < 2 or any(not row["nonblank"] for row in captures):
        errors.append("save and restored run did not produce nonblank UZDoom framebuffer captures")
    result = {"status": "PASS" if not errors else "FAIL", "evidence": str(evidence),
              "save_file": str(save_file) if save_file else None,
              "save_rc": save_rc, "load_rc": load_rc,
              "save_ready": save_rows[-1] if save_rows else None,
              "restore": restore_rows[-1] if restore_rows else None,
              "screenshots": captures, "errors": errors}
    if save_file is not None:
        shutil.copy2(save_file, evidence / save_file.name)
    (evidence / "roundtrip.json").write_text(json.dumps(result, indent=2) + "\n",
                                             encoding="utf-8")
    return result


def _rows(log: str, marker: str) -> list[dict[str, str]]:
    import re

    rows = []
    for match in re.finditer(rf"{re.escape(marker)}[ \t]+([^\r\n]*)", log):
        rows.append(dict(re.findall(r"([A-Za-z_][A-Za-z0-9_]*)=([^\s]+)", match.group(1))))
    return rows


def run_suite(package: Path, *, timeout: float = 35.0,
              skip_compile: bool = False) -> dict:
    if not package.is_file():
        return {"status": "FAIL", "errors": [f"missing package: {package}"]}
    package_sha = hashlib.sha256(package.read_bytes()).hexdigest()
    compile_result = None
    if not skip_compile:
        compile_result = run(package, timeout, True, False, "P033", map_name="MAP19")
        if compile_result.get("status") != "COMPILE_PASS":
            return {"status": "FAIL", "package": str(package),
                    "package_sha256": package_sha, "compile": compile_result,
                    "errors": ["pinned UZDoom MAP19 compile failed"]}
    run_result = run(package, timeout, False, False, "P033", map_name="MAP19",
                     completion_marker="DS_P033_RUNTIME_PASS")
    log = _run_log(run_result)
    validation = validate_p033_runtime(log, run_result.get("status", "UNKNOWN"))
    errors = list(validation["errors"])
    if run_result.get("status") != "RUNTIME_PASS":
        errors.append(f"MAP19 UZDoom status was {run_result.get('status')}, expected RUNTIME_PASS")
    if not any(capture.get("nonblank") for capture in run_result.get("captures", [])):
        errors.append("MAP19 stat matrix did not produce a nonblank framebuffer")
    save_load = _save_roundtrip(package, timeout)
    if save_load["status"] != "PASS":
        errors.extend(f"save/load: {error}" for error in save_load["errors"])
    result = {"status": "PASS" if not errors else "FAIL",
              "classification": "P033_QUALIFIED_RESOLVED_STATS_ENGINERUN",
              "package": str(package), "package_sha256": package_sha,
              "package_provenance": "SUPPLIED_PACKAGE_VALIDATION_ONLY",
              "source_rebuild_performed": False,
              "compile": compile_result, "run": run_result,
              "validation": validation, "save_load": save_load, "errors": errors}
    evidence = Path(run_result["evidence"])
    output = evidence / "p033-suite.json"
    output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    result["suite_result"] = str(output)
    return result


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, default=ROOT / "build/doom-survivors.ipk3")
    parser.add_argument("--timeout", type=float, default=35.0)
    parser.add_argument("--skip-compile", action="store_true")
    args = parser.parse_args()
    result = run_suite(args.package, timeout=args.timeout, skip_compile=args.skip_compile)
    print(json.dumps(result, indent=2), flush=True)
    raise SystemExit(0 if result["status"] == "PASS" else 1)
