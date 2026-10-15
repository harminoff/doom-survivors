"""Run the packaged MAP06 P020 entity and engine-save fixture."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tools.build import build
from tools.run_persistence_bench import config_text, read_log, run_engine
from tools.run_probe import run

BOOT_RE = re.compile(r"DS_P020_BOOT map=MAP06 ticrate=35")
SAVE_RE = re.compile(r"DS_P020_SAVE_READY tic=(\d+) hash=(-?\d+) entities=(\d+) order_hash=(-?\d+)")
CANDIDATE_RE = re.compile(r"DS_P020_SAVE_CANDIDATE tic=(\d+) hash=(-?\d+) entities=(\d+) order_hash=(-?\d+)")
RESTORE_RE = re.compile(r"DS_P020_RESTORE first_tick=1 tic=(\d+) hash=(-?\d+) entities=(\d+) order_hash=(-?\d+) live=(\d+)")
FP_RE = re.compile(r"DS_P020_FP_RESTORE coherent=(\d+).*first_person_live=(\d+)")
COMPLETE_RE = re.compile(
    r"DS_P020_COMPLETE tic=(\d+) hash=(-?\d+) order_hash=(-?\d+) "
    r"stale_rejected=(\d+) cleanup_refs=(\d+) damage_refs=(\d+) drop_refs=(\d+) "
    r"hit_history_refs=(\d+) status_refs=(\d+) timer_refs=(\d+) live_proxy_refs=(\d+) "
    r"stale_proxy_refs=(\d+) native_health_used=(\d+)"
)


def _metadata(package: Path, compile_result: dict) -> dict:
    lock = json.loads((ROOT / "toolchain/lock.json").read_text(encoding="utf-8"))
    engine = ROOT / lock["uzdoom"]["executable"]["path"]
    return {
        "package_sha256": hashlib.sha256(package.read_bytes()).hexdigest(),
        "compile_package_sha256": compile_result.get("package_sha256"),
        "engine_sha256": hashlib.sha256(engine.read_bytes()).hexdigest(),
        "source_commit": lock["uzdoom"]["source"]["commit"],
    }


def validate(first: str, restored: str, package: Path, compile_result: dict,
             save_file: Path, uninterrupted: str = "") -> dict:
    errors: list[str] = []
    save_matches = list(SAVE_RE.finditer(first))
    save = save_matches[-1] if save_matches else None
    candidates = {(m.group(1), m.group(2), m.group(3), m.group(4)) for m in CANDIDATE_RE.finditer(first)}
    first_complete = COMPLETE_RE.search(first)
    restore = RESTORE_RE.search(restored)
    complete = COMPLETE_RE.search(restored)
    uninterrupted_complete = COMPLETE_RE.search(uninterrupted)
    if not BOOT_RE.search(first): errors.append("fresh run is missing the MAP06 P020 boot marker")
    if save is None: errors.append("fresh run is missing the save-ready snapshot")
    if uninterrupted and first_complete is None:
        errors.append("save process is missing the P020 completion marker")
    if restore is None: errors.append("load run is missing the restored entity graph snapshot")
    if FP_RE.search(restored) is None or FP_RE.search(restored).group(1) != "1" or FP_RE.search(restored).group(2) != "1":
        errors.append("load run did not restore a coherent live first-person context")
    if complete is None: errors.append("load run is missing the P020 completion marker")
    if uninterrupted and uninterrupted_complete is None:
        errors.append("uninterrupted fresh run is missing the P020 completion marker")
    if not save_file.exists(): errors.append("engine did not create the P020 savegame")
    if restore and (restore.group(1), restore.group(2), restore.group(3), restore.group(4)) not in candidates:
        errors.append("restored state does not match any fresh-process save candidate")
    if "DS_P020_TARGET_REUSE" not in first or "old_rejected=1" not in first or "stale_source_target_valid=0" not in first or "rebound_target_valid=1" not in first:
        errors.append("target reuse did not fail closed on the stale generation-tagged reference")
    if "DS_P020_REBASE" not in first or "logical_preserved=1" not in first or "target_preserved=1" not in first or "collision_preserved=1" not in first:
        errors.append("origin rebase did not preserve logical position, target, and collision")
    if "DS_P020_CLEANUP" not in first or "damage_refs=0" not in first or "drop_refs=0" not in first or "hit_history_refs=0" not in first or "status_refs=0" not in first or "timer_refs=0" not in first or "presentation_refs=0" not in first:
        errors.append("destroyed entity retained a live damage/drop/status/timer/presentation reference")
    if complete and any(complete.group(i) != expected for i, expected in ((4, "1"), (6, "0"), (7, "0"), (8, "0"), (9, "0"), (10, "0"), (11, "3"), (12, "0"), (13, "0"))):
        errors.append("completion marker reports invalid stale-reference or proxy state")
    if first_complete and complete and uninterrupted_complete:
        canonical = first_complete.groups()
        if complete.groups() != canonical or uninterrupted_complete.groups() != canonical:
            errors.append("restored continuation diverged from the uninterrupted canonical final state")
    metadata = _metadata(package, compile_result)
    if metadata["package_sha256"] != metadata["compile_package_sha256"]:
        errors.append("package changed between compile and runtime")
    if "Script error" in first + restored or "Execution could not continue" in first + restored:
        errors.append("engine log contains a script/runtime failure")
    return {
        "status": "PASS" if not errors else "FAIL",
        "classification": "P020_PACKAGED_UZDOOM_ENTITY_RUN_SAVE",
        "errors": errors,
        "save_snapshot": save.groups() if save else None,
        "save_candidates": sorted(candidates),
        "restore_snapshot": restore.groups() if restore else None,
        "save_completion": first_complete.groups() if first_complete else None,
        "uninterrupted_completion": uninterrupted_complete.groups() if uninterrupted_complete else None,
        "completion": complete.groups() if complete else None,
        "save_file": str(save_file),
        **metadata,
    }


def run_probe(*, package: Path | None = None, seconds: float = 20.0) -> dict:
    if not 8.0 <= seconds <= 120.0:
        raise ValueError("seconds must be between 8 and 120")
    if package is None:
        package = Path(build(ROOT, room_spec=ROOT / "maps/source/p020-entities/room.json")["package"])
    package = Path(package)
    compile_result = run(package, seconds, True, False, "P020", 60, 1280, 720, map_name="MAP06", completion_marker="DS_P020_COMPLETE")
    if compile_result["status"] != "COMPILE_PASS":
        return {"status": "FAIL", "classification": "P020_PACKAGED_UZDOOM_ENTITY_RUN_SAVE", "errors": ["compile gate failed"], "compile": compile_result}

    lock = json.loads((ROOT / "toolchain/lock.json").read_text(encoding="utf-8"))
    executable = ROOT / lock["uzdoom"]["executable"]["path"]
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    evidence = ROOT / "evidence" / "P020" / f"{stamp}-entity-run-save"
    profile = ROOT / ".local" / "probes" / f"{stamp}-p020-entity"
    evidence.mkdir(parents=True)
    profile.mkdir(parents=True)
    (profile / "config.ini").write_text(config_text(evidence), encoding="utf-8", newline="\n")
    (profile / "save.cfg").write_text('wait 20; save ds_p020_roundtrip "P020 entity graph"; wait 25; quit\n', encoding="utf-8", newline="\n")
    (profile / "load.cfg").write_text("wait 35; quit\n", encoding="utf-8", newline="\n")
    fresh_profile = ROOT / ".local" / "probes" / f"{stamp}-p020-fresh"
    fresh_profile.mkdir(parents=True)
    (fresh_profile / "config.ini").write_text(config_text(evidence), encoding="utf-8", newline="\n")
    (fresh_profile / "fresh.cfg").write_text("wait 50; quit\n", encoding="utf-8", newline="\n")
    save_rc = run_engine(executable, package, profile, "save.log", ["+map", "MAP06", "+exec", "save.cfg"], timeout=seconds)
    first = read_log(profile, "save.log")
    fresh_rc = run_engine(executable, package, fresh_profile, "fresh.log", ["+map", "MAP06", "+exec", "fresh.cfg"], timeout=seconds)
    uninterrupted = read_log(fresh_profile, "fresh.log")
    saves = sorted(path for path in profile.glob("ds_p020_roundtrip*") if path.is_file())
    save_file = saves[0] if saves else profile / "ds_p020_roundtrip.zds"
    load_rc = None
    restored = ""
    if save_file.exists():
        load_rc = run_engine(executable, package, profile, "load.log", ["-loadgame", save_file.stem, "+exec", "load.cfg"], timeout=seconds)
        restored = read_log(profile, "load.log")
    (evidence / "save-engine.log").write_text(first, encoding="utf-8", newline="\n")
    (evidence / "load-engine.log").write_text(restored, encoding="utf-8", newline="\n")
    (evidence / "fresh-engine.log").write_text(uninterrupted, encoding="utf-8", newline="\n")
    result = validate(first, restored, package, compile_result, save_file, uninterrupted)
    result.update({"compile": compile_result, "save_exit_code": save_rc, "load_exit_code": load_rc,
                   "fresh_exit_code": fresh_rc, "evidence": str(evidence)})
    if save_rc != 0:
        result["errors"].append(f"save process exited with unexpected status {save_rc}")
    if load_rc != 0:
        result["errors"].append(f"load process exited with unexpected status {load_rc}")
    if fresh_rc != 0:
        result["errors"].append(f"uninterrupted fresh process exited with unexpected status {fresh_rc}")
    if result["errors"]:
        result["status"] = "FAIL"
    (evidence / "p020-result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps(result, indent=2, sort_keys=True))
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path)
    parser.add_argument("--seconds", type=float, default=20.0)
    args = parser.parse_args(argv)
    try:
        result = run_probe(package=args.package, seconds=args.seconds)
    except (OSError, ValueError, RuntimeError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    return 0 if result.get("status") == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
