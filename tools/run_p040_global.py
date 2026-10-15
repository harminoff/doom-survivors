"""Build and run the controlled MAP26 P040 global-strike/erasure fixture.

Modelled on tools/run_p039_aura.py, but deliberately simpler: this fixture
(src/zscript/ui/global/GlobalMap26Runtime.zs) is a single scripted timeline
per mode rather than a full mode/target matrix, so this runner just builds
the MAP26 package once, runs the requested modes in sequence (each mode is
an independent engine process), and extracts the DS_P040_* markers each
mode's own Console.Printf lines already emit as evidence.

Usage:
    python tools/run_p040_global.py --modes matrix,spare_audit,mass
    python tools/run_p040_global.py --camera-invariance
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tools.build import build
from tools.run_probe import run, config_text
from tools.run_persistence_bench import read_log, run_engine

ALL_MODES = ("matrix", "spare_audit", "mass")
COMPLETE_RE = re.compile(r"DS_P040_MAP26_COMPLETE (\S.*)")
KV_RE = re.compile(r"(\w+)=(\S+)")


def _parse_complete(log: str) -> dict[str, str] | None:
    match = COMPLETE_RE.search(log)
    if match is None:
        return None
    return dict(KV_RE.findall(match.group(1)))


STRIKE_HIT_RE = re.compile(r"DS_P040_STRIKE_HIT (\S.*)")
ERASE_ENEMY_RE = re.compile(r"DS_P040_ERASE_ENEMY (\S.*)")
MOON_BEAM_RE = re.compile(r"DS_P040_MOON_BEAM (\S.*)")
STRIKE_TUPLE_KEYS = ("tic", "system_id", "rank", "weapon_id", "target_slot",
                      "target_generation", "target_id", "damage_milli",
                      "before", "after", "killed")
ERASE_TUPLE_KEYS = ("slot", "generation", "stable_id")
MOON_TUPLE_KEYS = ("tic", "target_slot", "target_generation", "target_id", "before", "after")


def _tuples(text: str, pattern: re.Pattern, keys: tuple[str, ...]) -> list[tuple[str, ...]]:
    rows = [dict(KV_RE.findall(m.group(1))) for m in pattern.finditer(text)]
    return [tuple(row.get(k, "") for k in keys) for row in rows]


def run_mode(package: Path, mode: str, camera_variant: int = 0, vfx: int = 1,
             seconds: float = 30) -> dict:
    startup = ["+set", "ds_p040_mode", mode, "+set", "ds_p040_vfx", str(vfx)]
    if camera_variant:
        startup += ["+set", "ds_p040_camera_variant", str(camera_variant)]
    result = run(package, seconds=seconds, compile_only=False, evidence_phase="P040",
                 map_name="MAP26", completion_marker="DS_P040_MAP26_COMPLETE",
                 startup_commands=startup)
    log = Path(result["evidence"]) / "engine.log"
    text = log.read_text(encoding="utf-8", errors="replace")
    result["p040_complete"] = _parse_complete(text)
    result["mode"] = mode
    result["camera_variant"] = camera_variant
    result["vfx"] = vfx
    result["strike_hit_tuples"] = _tuples(text, STRIKE_HIT_RE, STRIKE_TUPLE_KEYS)
    result["erase_enemy_tuples"] = _tuples(text, ERASE_ENEMY_RE, ERASE_TUPLE_KEYS)
    result["moon_beam_tuples"] = _tuples(text, MOON_BEAM_RE, MOON_TUPLE_KEYS)
    if mode == "spare_audit":
        result["spare_audit_rows"] = re.findall(r"DS_P040_SPARE_AUDIT (\S.*)", text)
        result["spare_saturation"] = re.findall(r"DS_P040_SPARE_SATURATION (\S.*)", text)
    if mode == "target_audit":
        result["target_audit_row"] = re.findall(r"DS_P040_TARGET_AUDIT (\S.*)", text)
        result["target_audit_shrunk"] = re.findall(r"DS_P040_TARGET_AUDIT_SHRUNK (\S.*)", text)
    return result


def camera_invariance(package: Path, seconds: float = 30) -> dict:
    """Runs "matrix" mode across the real engine camera (contract: "Narrow/
    wide FOV, 180-degree yaw and flash on/off producing identical logical
    target sets"), mirroring run_p039_aura.py's own four-run camera
    comparison exactly: (cam0,vfx1), (cam1,vfx1), (cam2,vfx1), (cam0,vfx0).
    Compares the FULL logical strike-hit/erase-enemy/moon-beam tuple
    sequences, not only the final aggregate hash -- a divergence in any one
    event, not just the summary, fails this check."""
    plan = [(0, 1), (1, 1), (2, 1), (0, 0)]
    runs = [run_mode(package, "matrix", camera, vfx, seconds=seconds) for camera, vfx in plan]
    errors: list[str] = []
    baseline = runs[0]
    per_run_summary = []
    for run_result, (camera, vfx) in zip(runs, plan):
        per_run_summary.append({
            "camera_variant": camera, "vfx": vfx,
            "evidence": run_result.get("evidence"),
            "package_sha256": run_result.get("package_sha256"),
            "p040_complete": run_result.get("p040_complete"),
            "strike_hit_tuple_count": len(run_result.get("strike_hit_tuples", [])),
            "erase_enemy_tuple_count": len(run_result.get("erase_enemy_tuples", [])),
            "moon_beam_tuple_count": len(run_result.get("moon_beam_tuples", [])),
        })
    for other in runs[1:]:
        label = f"camera={other['camera_variant']} vfx={other['vfx']}"
        if other["p040_complete"] is None or baseline["p040_complete"] is None:
            errors.append(f"{label}: missing completion marker")
            continue
        base_complete = {k: v for k, v in baseline["p040_complete"].items() if k != "camera_variant"}
        other_complete = {k: v for k, v in other["p040_complete"].items() if k != "camera_variant"}
        if base_complete != other_complete:
            errors.append(f"{label}: final counters diverged: {other_complete} != {base_complete}")
        if other["strike_hit_tuples"] != baseline["strike_hit_tuples"]:
            errors.append(f"{label}: strike-hit tuple sequence diverged")
        if other["erase_enemy_tuples"] != baseline["erase_enemy_tuples"]:
            errors.append(f"{label}: erase-enemy tuple sequence diverged")
        if other["moon_beam_tuples"] != baseline["moon_beam_tuples"]:
            errors.append(f"{label}: moon-beam tuple sequence diverged")
    report = {
        "status": "PASS" if not errors else "FAIL",
        "ok": not errors,
        "claim": "MAP26 accepted strike-hit/erase-enemy/moon-beam tuple sequences are invariant across yaw/FOV and the real flash/bolt-proxy toggle",
        "plan": [{"camera_variant": c, "vfx": v} for c, v in plan],
        "runs": per_run_summary,
        "errors": errors,
    }
    first_evidence = runs[0].get("evidence") if runs else None
    if first_evidence:
        report_path = Path(first_evidence) / "p040-camera-vfx-invariance.json"
        report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        report["report_path"] = str(report_path)
    report["runs_full"] = runs
    return report


SAVE_FROZEN_RE = re.compile(r"DS_P040_MAP26_SAVE_FROZEN accepted=1 tic=(\d+) hash=(-?\d+) pending_thunder_repeat=1 pending_moon_phase2=1")
RESTORE_RE = re.compile(r"DS_P040_MAP26_RESTORE first_tick=1 tic=(\d+) hash=(-?\d+) continuation=1 pending_thunder_repeat=(\d+) pending_moon_phase2=(\d+)")


def validate_save_roundtrip(save_log: str, restore_log: str) -> dict[str, object]:
    """Save leg: the fixture freezes itself the moment a Thunder Loop repeat
    AND a Moon phase-2 are BOTH pending (see GlobalMap26Runtime.zs's
    ds_p040_save_snapshot_request freeze), so the save script's own `wait`
    only needs to be generous, never exact. Restore leg: the reloaded state
    must reproduce the identical hash pre-rebase (no rebase in this fixture,
    so exact equality applies directly), still have both pending events
    outstanding, and then actually fire them (contract: "the pending events
    then firing after load")."""
    errors: list[str] = []
    frozen = SAVE_FROZEN_RE.search(save_log)
    if frozen is None:
        errors.append("save leg never froze with both a pending repeat and a pending Moon phase-2")
        return {"ok": False, "errors": errors}
    frozen_tic, frozen_hash = int(frozen.group(1)), int(frozen.group(2))

    restored = RESTORE_RE.search(restore_log)
    if restored is None:
        errors.append("restore leg never emitted its first-tick continuation marker")
        return {"ok": False, "errors": errors, "frozen_tic": frozen_tic, "frozen_hash": frozen_hash}
    restored_tic, restored_hash = int(restored.group(1)), int(restored.group(2))
    pending_repeat, pending_moon = int(restored.group(3)), int(restored.group(4))

    if restored_tic != frozen_tic:
        errors.append(f"restored tic {restored_tic} != frozen tic {frozen_tic}")
    if restored_hash != frozen_hash:
        errors.append(f"restored hash {restored_hash} != frozen hash {frozen_hash} (exact equality required)")
    if pending_repeat != 1:
        errors.append("Thunder Loop repeat was not still pending immediately after load")
    if pending_moon != 1:
        errors.append("Moon phase-2 was not still pending immediately after load")

    repeat_fired = "DS_P040_REPEAT_FIRED" in restore_log
    moon_phase2_fired = "DS_P040_MOON_PHASE2" in restore_log
    if not repeat_fired:
        errors.append("Thunder Loop repeat never fired after load")
    if not moon_phase2_fired:
        errors.append("Moon phase-2 never fired after load")

    return {
        "ok": not errors, "errors": errors,
        "frozen_tic": frozen_tic, "frozen_hash": frozen_hash,
        "restored_tic": restored_tic, "restored_hash": restored_hash,
        "repeat_fired_after_load": repeat_fired,
        "moon_phase2_fired_after_load": moon_phase2_fired,
    }


def run_roundtrip(package: Path, wait_tics: int = 60, restore_wait_tics: int = 60,
                   timeout: float = 60.0) -> dict[str, object]:
    """Native save/load, mirroring tools/run_p039_map16.py's run_roundtrip:
    a `+exec`'d console script drives `save`/`-loadgame` directly rather
    than going through tools.run_probe.run's own polling loop."""
    package = package.resolve()
    package_sha = hashlib.sha256(package.read_bytes()).hexdigest()
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    name = f"{stamp}-p040-map26-save-load"
    evidence = ROOT / "evidence/P040" / name
    evidence.mkdir(parents=True)
    profile = ROOT / ".local/probes" / name
    profile.mkdir(parents=True)
    save_capture = evidence / "save-captures"
    restore_capture = evidence / "restore-captures"
    save_capture.mkdir()
    restore_capture.mkdir()
    save_name = "ds_p040_map26"
    save_script = profile / "save.cfg"
    restore_script = profile / "restore.cfg"
    save_script.write_text(
        f'wait {wait_tics}; screenshot; save {save_name} "P040 global-strike state"; wait 8; quit\n',
        encoding="utf-8", newline="\n")
    restore_script.write_text(
        f"wait {restore_wait_tics}; screenshot; wait 20; quit\n",
        encoding="utf-8", newline="\n")
    (profile / "config.ini").write_text(config_text(save_capture, vsync=False),
                                        encoding="utf-8", newline="\n")
    lock = json.loads((ROOT / "toolchain/lock.json").read_text(encoding="utf-8"))
    executable = ROOT / lock["uzdoom"]["executable"]["path"]
    save_args = ["+enablescriptscreenshot", "true",
                 "+set", "ds_p040_mode", "save",
                 "+set", "ds_p040_save_snapshot_request", "1",
                 "+map", "MAP26", "+exec", save_script.name]
    save_rc = run_engine(executable, package, profile, "p040-map26-save.log",
                         save_args, timeout=timeout)
    save_log = read_log(profile, "p040-map26-save.log")
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
                        "+set", "ds_p040_mode", "save",
                        "+set", "ds_p040_save_snapshot_request", "0",
                        "+exec", restore_script.name]
        restore_rc = run_engine(executable, package, profile,
                                "p040-map26-restore.log", restore_args,
                                timeout=timeout)
        restore_log = read_log(profile, "p040-map26-restore.log")

    (evidence / "save-engine.log").write_text(save_log, encoding="utf-8", newline="\n")
    (evidence / "restore-engine.log").write_text(restore_log, encoding="utf-8", newline="\n")
    shutil.copy2(save_script, evidence / save_script.name)
    shutil.copy2(restore_script, evidence / restore_script.name)
    validation = validate_save_roundtrip(save_log, restore_log)
    errors = list(validation["errors"])
    if save_file is None or save_file.stat().st_size <= 0:
        errors.append("UZDoom did not create a nonempty serialized MAP26 save")
    if save_file is not None:
        shutil.copy2(save_file, evidence / save_file.name)
    report = {
        "status": "PASS" if not errors else "FAIL",
        "classification": "P040_MAP26_SERIALIZED_STRIKE_ERASE_CONTINUATION",
        "package": str(package),
        "package_sha256": package_sha,
        "save_exit_code": save_rc,
        "restore_exit_code": restore_rc,
        "save_file_size": save_file.stat().st_size if save_file else None,
        "validation": validation,
        "evidence": str(evidence),
        "errors": errors,
    }
    (evidence / "roundtrip.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--modes", default="matrix,spare_audit,mass")
    parser.add_argument("--camera-invariance", action="store_true")
    parser.add_argument("--save-roundtrip", action="store_true")
    parser.add_argument("--seconds", type=float, default=30)
    options = parser.parse_args()

    build(ROOT, "none", ROOT / "maps/source/p040-global/room.json")
    package = ROOT / "build/doom-survivors.ipk3"

    report: dict[str, object] = {}
    if options.camera_invariance:
        report["camera_invariance"] = camera_invariance(package, options.seconds)
    if options.save_roundtrip:
        report["save_roundtrip"] = run_roundtrip(package)
    for mode in options.modes.split(","):
        mode = mode.strip()
        if not mode:
            continue
        report[mode] = run_mode(package, mode, seconds=options.seconds)
    print(json.dumps(report, indent=2, default=str))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
