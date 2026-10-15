"""Build and run the controlled MAP27 P041 ricochet/boundary fixture.

Modelled on tools/run_p040_global.py: this fixture
(src/zscript/ui/bounce/BounceMap27Runtime.zs) exposes one mode per
acceptance area (boot, reflection, capacity, pierce_vs_bounce, cherry_audit,
no_future, rebase, pause, save) rather than a full mode/target matrix. This
runner builds the MAP27 package once per invocation, runs the requested
modes (each an independent engine process against the pinned UZDoom
runtime), and extracts each mode's own DS_P041_* Console.Printf markers as
evidence. Nothing here is reported PASS unless the parsed markers below
actually satisfy the check -- callers must still look at the written verdict
JSON, per project policy.

Usage:
    python tools/run_p041_bounce.py --modes boot,reflection,capacity
    python tools/run_p041_bounce.py --camera-invariance
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

ALL_MODES = ("boot", "reflection", "capacity", "pierce_vs_bounce",
             "cherry_audit", "no_future", "rebase", "pause", "save",
             "a01", "no_tunnel")
COMPLETE_RE = re.compile(r"DS_P041_MAP27_COMPLETE (\S.*)")
KV_RE = re.compile(r"(\w+)=(\S+)")
BOUNCE_RE = re.compile(r"DS_P041_BOUNCE (\S.*)")
HIT_RE = re.compile(r"DS_P041_HIT (\S.*)")
EXPLOSION_HIT_RE = re.compile(r"DS_P041_EXPLOSION_HIT (\S.*)")
CHERRY_STOP_RE = re.compile(r"DS_P041_CHERRY_STOP (\S.*)")
NO_FUTURE_RE = re.compile(r"DS_P041_NO_FUTURE_EXPLOSION (\S.*)")
REBASE_RE = re.compile(r"DS_P041_REBASE (\S.*)")
ROW_RE = re.compile(r"DS_P041_MAP27_ROW (\S.*)")
SNAPSHOT_RE = re.compile(r"DS_P041_MAP27_SNAPSHOT (\S.*)")
NO_TUNNEL_OVERRIDE_RE = re.compile(r"DS_P041_NO_TUNNEL_OVERRIDE (\S.*)")
PROJECTILE_RE = re.compile(r"DS_P041_PROJECTILE (\S.*)")
PROJECTILE_END_RE = re.compile(r"DS_P041_PROJECTILE_END (\S.*)")
CHERRY_RNG_AUDIT_RE = re.compile(r"DS_P041_CHERRY_RNG_AUDIT (\S.*)")
CHERRY_RNG_AUDIT_LIVE_RE = re.compile(r"DS_P041_CHERRY_RNG_AUDIT_LIVE_STATE (\S.*)")
PAUSE_MARK_RE = re.compile(r"DS_P041_MAP27_PAUSE_MARK (\S.*)")
PAUSE_START_RE = re.compile(r"DS_P041_MAP27_PAUSE_START (\S.*)")
PAUSE_HELD_RE = re.compile(r"DS_P041_MAP27_PAUSE_HELD (\S.*)")
PAUSE_END_RE = re.compile(r"DS_P041_MAP27_PAUSE_END (\S.*)")


def _parse_complete(log: str) -> dict[str, str] | None:
    match = COMPLETE_RE.search(log)
    if match is None:
        return None
    return dict(KV_RE.findall(match.group(1)))


def _rows(text: str, pattern: re.Pattern) -> list[dict[str, str]]:
    return [dict(KV_RE.findall(m.group(1))) for m in pattern.finditer(text)]


def run_mode(package: Path, mode: str, camera_variant: int = 0,
             seconds: float = 30, armor_points: int | None = None,
             window_width: int = 1280, window_height: int = 720) -> dict:
    startup = ["+set", "ds_p041_mode", mode]
    if camera_variant:
        startup += ["+set", "ds_p041_camera_variant", str(camera_variant)]
    if armor_points is not None:
        startup += ["+set", "ds_p041_no_future_armor", str(armor_points)]
    result = run(package, seconds=seconds, compile_only=False, evidence_phase="P041",
                 map_name="MAP27", completion_marker="DS_P041_MAP27_COMPLETE",
                 startup_commands=startup, window_width=window_width,
                 window_height=window_height)
    log = Path(result["evidence"]) / "engine.log"
    text = log.read_text(encoding="utf-8", errors="replace")
    result["p041_complete"] = _parse_complete(text)
    result["mode"] = mode
    result["camera_variant"] = camera_variant
    result["bounce_rows"] = _rows(text, BOUNCE_RE)
    result["hit_rows"] = _rows(text, HIT_RE)
    result["explosion_hit_rows"] = _rows(text, EXPLOSION_HIT_RE)
    result["cherry_stop_rows"] = _rows(text, CHERRY_STOP_RE)
    result["no_future_rows"] = _rows(text, NO_FUTURE_RE)
    result["rebase_rows"] = _rows(text, REBASE_RE)
    result["compiled_rows"] = _rows(text, ROW_RE)
    result["snapshot_rows"] = _rows(text, SNAPSHOT_RE)
    result["no_tunnel_override_rows"] = _rows(text, NO_TUNNEL_OVERRIDE_RE)
    result["projectile_rows"] = _rows(text, PROJECTILE_RE)
    result["projectile_end_rows"] = _rows(text, PROJECTILE_END_RE)
    result["cherry_rng_audit_rows"] = _rows(text, CHERRY_RNG_AUDIT_RE)
    result["cherry_rng_audit_live_rows"] = _rows(text, CHERRY_RNG_AUDIT_LIVE_RE)
    result["pause_mark_rows"] = _rows(text, PAUSE_MARK_RE)
    result["pause_start_rows"] = _rows(text, PAUSE_START_RE)
    result["pause_held_rows"] = _rows(text, PAUSE_HELD_RE)
    result["pause_end_rows"] = _rows(text, PAUSE_END_RE)
    result["log_text"] = text
    return result


def camera_invariance(package: Path, seconds: float = 30) -> dict:
    """Contract A02/FP01: identical logical paths across window-size,
    aspect, FOV and yaw 0/180 variants. Runs "reflection" mode across camera
    variants 0-3 and compares the FULL DS_P041_BOUNCE sequence, not just the
    final hash -- a divergence anywhere fails this check."""
    variants = (0, 1, 2, 3)
    runs = [run_mode(package, "reflection", camera, seconds=seconds) for camera in variants]
    errors: list[str] = []
    baseline = runs[0]
    for other, variant in zip(runs[1:], variants[1:]):
        label = f"camera={variant}"
        if other["p041_complete"] is None or baseline["p041_complete"] is None:
            errors.append(f"{label}: missing completion marker")
            continue
        base_complete = {k: v for k, v in baseline["p041_complete"].items() if k != "camera_variant"}
        other_complete = {k: v for k, v in other["p041_complete"].items() if k != "camera_variant"}
        if base_complete != other_complete:
            errors.append(f"{label}: final counters diverged: {other_complete} != {base_complete}")
        if other["bounce_rows"] != baseline["bounce_rows"]:
            errors.append(f"{label}: bounce-event sequence diverged")
    return {
        "check": "camera_invariance", "passed": not errors, "errors": errors,
        "runs": [{
            "camera_variant": v,
            "evidence": r.get("evidence"),
            "p041_complete": r.get("p041_complete"),
            "bounce_row_count": len(r.get("bounce_rows", [])),
        } for r, v in zip(runs, variants)],
    }


def camera_window_invariance(package: Path, seconds: float = 30) -> dict:
    """Item 6: identical DS_P041_BOUNCE/DS_P041_HIT tuple sequences under
    actual engine window-size variants (different resolutions/aspect
    ratios: 1280x720, 800x600, 1600x900) crossed with camera variants
    (yaw 0 vs 180, narrow FOV 60 vs wide FOV 120), run against the
    "pierce_vs_bounce" mode (fixed CONTROLLED_LAUNCH vectors that produce
    both bounce and hit events on every axis, unlike the single-projectile
    "reflection" mode) so both BOUNCE and HIT tuples are exercised. Every
    variant compares against the same window_width=1280/window_height=720/
    camera_variant=0 baseline; a divergence anywhere in either tuple
    sequence fails this check. Writes p041-camera-window-invariance.json."""
    plan = [
        (1280, 720, 0),   # baseline: yaw 0, FOV 90
        (800, 600, 0),    # window-size variant, same camera
        (1600, 900, 0),   # window-size + aspect-ratio variant, same camera
        (1280, 720, 1),   # camera yaw 180, baseline window
        (1280, 720, 3),   # camera wide FOV 120, baseline window
        (1280, 720, 4),   # camera narrow FOV 60, baseline window
        (1600, 900, 1),   # window + yaw 180 combined
        (800, 600, 4),    # window + narrow FOV combined
    ]
    runs = [run_mode(package, "pierce_vs_bounce", camera, seconds=seconds,
                      window_width=w, window_height=h)
            for w, h, camera in plan]
    errors: list[str] = []
    baseline = runs[0]
    bounce_key = lambda r: [{k: v for k, v in row.items()} for row in r.get("bounce_rows", [])]
    hit_key = lambda r: [{k: v for k, v in row.items()} for row in r.get("hit_rows", [])]
    baseline_bounce = bounce_key(baseline)
    baseline_hit = hit_key(baseline)
    if baseline["p041_complete"] is None:
        errors.append("baseline (1280x720, camera=0): missing completion marker")
    per_run = []
    for (w, h, camera), result in zip(plan, runs):
        label = f"{w}x{h} camera={camera}"
        complete = result.get("p041_complete")
        ok = True
        if complete is None:
            errors.append(f"{label}: missing completion marker")
            ok = False
        else:
            base_complete = {k: v for k, v in baseline["p041_complete"].items() if k not in ("camera_variant",)}
            other_complete = {k: v for k, v in complete.items() if k not in ("camera_variant",)}
            if base_complete != other_complete:
                errors.append(f"{label}: final counters diverged: {other_complete} != {base_complete}")
                ok = False
        this_bounce = bounce_key(result)
        this_hit = hit_key(result)
        if this_bounce != baseline_bounce:
            errors.append(f"{label}: DS_P041_BOUNCE tuple sequence diverged from baseline")
            ok = False
        if this_hit != baseline_hit:
            errors.append(f"{label}: DS_P041_HIT tuple sequence diverged from baseline")
            ok = False
        per_run.append({
            "window_width": w, "window_height": h, "camera_variant": camera,
            "evidence": result.get("evidence"), "p041_complete": complete,
            "bounce_row_count": len(this_bounce), "hit_row_count": len(this_hit),
            "matched_baseline": ok,
        })
    report = {
        "status": "PASS" if not errors else "FAIL",
        "check": "p041_camera_window_invariance",
        "errors": errors,
        "plan": [{"window_width": w, "window_height": h, "camera_variant": c} for w, h, c in plan],
        "runs": per_run,
    }
    baseline_evidence = baseline.get("evidence")
    if baseline_evidence:
        out_path = Path(baseline_evidence) / "p041-camera-window-invariance.json"
        out_path.write_text(json.dumps(report, indent=2, default=str) + "\n", encoding="utf-8")
        report["report_path"] = str(out_path)
    return report


SAVE_FROZEN_RE = re.compile(r"DS_P041_MAP27_SAVE_FROZEN accepted=1 tic=(\d+) hash=(-?\d+) pending_hit_delay=1 mid_flight=1")
SAVE_STATE_RE = re.compile(r"DS_P041_MAP27_SAVE_STATE (\S.*)")
RESTORE_RE = re.compile(r"DS_P041_MAP27_RESTORE first_tick=1 tic=(\d+) hash=(-?\d+) continuation=1 pending_hit_delay=(\d+) mid_flight=(\d+) exact_hash=(\d+)")


def _validate_save_roundtrip_logs(save_log: str, restore_log: str) -> dict[str, object]:
    """Item 5: freeze mid-flight with a pending hit delay, save, load in a
    new process, exact hash equality immediately after load, and bouncing
    continuing afterwards with the next bounce matching the independent
    Python reference (reference_reflect_path, resumed from the exact frozen
    position/direction/speed/age)."""
    errors: list[str] = []
    frozen = SAVE_FROZEN_RE.search(save_log)
    if frozen is None:
        errors.append("save leg never froze with a pending hit delay on a mid-flight projectile")
        return {"ok": False, "errors": errors}
    frozen_tic, frozen_hash = int(frozen.group(1)), int(frozen.group(2))

    restored = RESTORE_RE.search(restore_log)
    if restored is None:
        errors.append("restore leg never emitted its first-tick continuation marker")
        return {"ok": False, "errors": errors, "frozen_tic": frozen_tic, "frozen_hash": frozen_hash}
    restored_tic = int(restored.group(1))
    restored_hash = int(restored.group(2))
    pending_hit_delay = int(restored.group(3))
    mid_flight = int(restored.group(4))
    exact_hash = int(restored.group(5))

    if restored_tic != frozen_tic:
        errors.append(f"restored tic {restored_tic} != frozen tic {frozen_tic}")
    if restored_hash != frozen_hash:
        errors.append(f"restored hash {restored_hash} != frozen hash {frozen_hash} (exact equality required)")
    if exact_hash != 1:
        errors.append("engine's own before/after DS_P041_MAP27_SAVE_RESTORE comparison reported stable=0")
    if pending_hit_delay != 1:
        errors.append("the hit-delay pair was not still pending immediately after load")
    if mid_flight != 1:
        errors.append("the Bone projectile was not still active/mid-flight immediately after load")

    # "Bouncing continues" + "next bounce matches the Python reference":
    # every DS_P041_BOUNCE row at a tic > restored_tic in the restore log is
    # the resumed motion; there must be at least one. Additionally, the exact
    # frozen kinematic state (DS_P041_MAP27_SAVE_STATE, emitted on the save
    # leg) lets an independent Python reference (reference_reflect_path)
    # predict that projectile's NEXT bounce from this precise resumption
    # point, which must match the first later bounce actually observed.
    restore_bounces = _rows(restore_log, BOUNCE_RE)
    later_bounces = [b for b in restore_bounces if _int_or_none(b.get("tic")) is not None and _int_or_none(b.get("tic")) > restored_tic]
    if not later_bounces:
        errors.append("no bounce/motion observed after restore -- motion did not continue")

    reference_prediction = None
    predicted_next_bounce = None
    state_rows = _rows(save_log, SAVE_STATE_RE)
    if state_rows and later_bounces:
        state = state_rows[0]
        import math
        ref = _load_reference_module()
        dir_x = _float_or_none(state.get("dir_x"))
        dir_y = _float_or_none(state.get("dir_y"))
        speed = _float_or_none(state.get("speed_ups"))
        age = _int_or_none(state.get("age_tics"))
        duration = _int_or_none(state.get("duration_tics"))
        sx = _float_or_none(state.get("x"))
        sy = _float_or_none(state.get("y"))
        if None not in (dir_x, dir_y, speed, age, duration, sx, sy) and duration - age > 0:
            yaw_milli = int(round(math.degrees(math.atan2(dir_y, dir_x)) * 1000)) % 360000
            reference_prediction = ref.reference_reflect_path(
                (sx, sy), yaw_milli, speed, duration - age, FIXTURE_WALLS_FOR_A01)
            if reference_prediction:
                predicted_next_bounce = reference_prediction[0]
                first_actual = later_bounces[0]
                actual_x = _float_or_none(first_actual.get("x"))
                actual_y = _float_or_none(first_actual.get("y"))
                if (abs(actual_x - predicted_next_bounce["x"]) > 0.5
                        or abs(actual_y - predicted_next_bounce["y"]) > 0.5):
                    errors.append(f"next bounce after restore {(actual_x, actual_y)} does not match the independent Python reference prediction {(predicted_next_bounce['x'], predicted_next_bounce['y'])} (resumed from the exact frozen state)")

    return {
        "ok": not errors, "errors": errors,
        "frozen_tic": frozen_tic, "frozen_hash": frozen_hash,
        "restored_tic": restored_tic, "restored_hash": restored_hash,
        "pending_hit_delay_after_load": pending_hit_delay == 1,
        "mid_flight_after_load": mid_flight == 1,
        "post_restore_bounce_count": len(later_bounces),
        "post_restore_bounces": later_bounces,
        "reference_prediction": reference_prediction,
        "predicted_next_bounce": predicted_next_bounce,
    }


def run_save_roundtrip(package: Path, wait_tics: int = 30, restore_wait_tics: int = 40,
                        timeout: float = 60.0) -> dict[str, object]:
    """Item 5: native save/load with a P041 projectile mid-bounce, modeled
    directly on tools/run_p040_global.py's run_roundtrip (a `+exec`'d
    console script drives `save`/`-loadgame` directly rather than going
    through tools.run_probe.run's own polling loop)."""
    package = package.resolve()
    package_sha = hashlib.sha256(package.read_bytes()).hexdigest()
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    name = f"{stamp}-p041-map27-save-load"
    evidence = ROOT / "evidence/P041" / name
    evidence.mkdir(parents=True)
    profile = ROOT / ".local/probes" / name
    profile.mkdir(parents=True)
    save_capture = evidence / "save-captures"
    restore_capture = evidence / "restore-captures"
    save_capture.mkdir()
    restore_capture.mkdir()
    save_name = "ds_p041_map27"
    save_script = profile / "save.cfg"
    restore_script = profile / "restore.cfg"
    save_script.write_text(
        f'wait {wait_tics}; screenshot; save {save_name} "P041 bounce mid-flight state"; wait 8; quit\n',
        encoding="utf-8", newline="\n")
    restore_script.write_text(
        f"wait {restore_wait_tics}; screenshot; wait 20; quit\n",
        encoding="utf-8", newline="\n")
    (profile / "config.ini").write_text(config_text(save_capture, vsync=False),
                                        encoding="utf-8", newline="\n")
    lock = json.loads((ROOT / "toolchain/lock.json").read_text(encoding="utf-8"))
    executable = ROOT / lock["uzdoom"]["executable"]["path"]
    save_args = ["+enablescriptscreenshot", "true",
                 "+set", "ds_p041_mode", "save",
                 "+set", "ds_p041_save_snapshot_request", "1",
                 "+map", "MAP27", "+exec", save_script.name]
    save_rc = run_engine(executable, package, profile, "p041-map27-save.log",
                         save_args, timeout=timeout)
    save_log = read_log(profile, "p041-map27-save.log")
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
                        "+set", "ds_p041_mode", "save",
                        "+set", "ds_p041_save_snapshot_request", "0",
                        "+exec", restore_script.name]
        restore_rc = run_engine(executable, package, profile,
                                "p041-map27-restore.log", restore_args,
                                timeout=timeout)
        restore_log = read_log(profile, "p041-map27-restore.log")

    (evidence / "save-engine.log").write_text(save_log, encoding="utf-8", newline="\n")
    (evidence / "restore-engine.log").write_text(restore_log, encoding="utf-8", newline="\n")
    shutil.copy2(save_script, evidence / save_script.name)
    shutil.copy2(restore_script, evidence / restore_script.name)
    validation = _validate_save_roundtrip_logs(save_log, restore_log)
    errors = list(validation["errors"])
    if save_file is None or save_file.stat().st_size <= 0:
        errors.append("UZDoom did not create a nonempty serialized MAP27 save")
    if save_file is not None:
        shutil.copy2(save_file, evidence / save_file.name)
    report = {
        "status": "PASS" if not errors else "FAIL",
        "classification": "P041_MAP27_SERIALIZED_MID_BOUNCE_CONTINUATION",
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


def _load_reference_module():
    """Loads tests/runtime/weapons-bounce/test_p041_runtime.py by file path
    (its directory name has a hyphen, so it cannot be a dotted import) to
    reuse its independent reference_reflect_path (A01) rather than
    duplicating that geometry a third time."""
    import importlib.util
    path = ROOT / "tests" / "runtime" / "weapons-bounce" / "test_p041_runtime.py"
    spec = importlib.util.spec_from_file_location("p041_reference", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _write_verdict(evidence_dir: str | Path, mode: str, report: dict) -> str:
    out_path = Path(evidence_dir) / f"p041-{mode}-validation.json"
    out_path.write_text(json.dumps(report, indent=2, default=str) + "\n", encoding="utf-8")
    return str(out_path)


def _events_by_id(rows: list[dict[str, str]]) -> dict[int, dict[str, str]]:
    out = {}
    for row in rows:
        event_id = _int_or_none(row.get("event_id"))
        if event_id is not None:
            out[event_id] = row
    return out


def _int_or_none(value):
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _float_or_none(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


DATA_DIR = ROOT / "data" / "verified" / "base" / "weapons" / "bounce"
JSON_FILES = {
    54: "runetracer.json",
    55: "no-future.json",
    56: "bone.json",
    57: "cherry-bomb.json",
    58: "carrello.json",
}
# DSP041BounceRows.DSP041_UNBOUNDED_DURATION_TICS (BounceRuntime.zs): the
# fixed engineering substitute used whenever a row's reported duration is
# "not applicable" (0) and its bounce budget is bounded (>=0) -- i.e. only
# Carréllo (58) today. Not read from JSON: Carréllo's duration_seconds/
# duration_tics are null/absent there because the source never reports a
# duration for it at all.
UNBOUNDED_DURATION_TICS = 999999


def _expected_rows_from_json() -> dict[tuple[int, int], dict[str, int]]:
    """Loads every rank row directly from data/verified/base/weapons/bounce/
    *.json (the canonical source mirror) and maps it to the exact field set
    DS_P041_MAP27_ROW emits, so item 1's validator compares engine output
    against the JSON, never against BounceRows.zs itself (which is the file
    under test)."""
    expected: dict[tuple[int, int], dict[str, int]] = {}
    for system_id, filename in JSON_FILES.items():
        doc = json.loads((DATA_DIR / filename).read_text(encoding="utf-8"))
        policy = doc["bounce_policy"]
        pierces = 1 if policy["pierces_enemies"] else 0
        bounces = 1 if policy["bounces_off_enemies"] else 0
        bounce_budget = int(policy["bounce_budget"])
        for row in doc["rank_rows"]:
            rank = int(row["rank"])
            duration_tics = row.get("duration_tics")
            if duration_tics is None:
                # Carréllo only: DSP041BounceRows.DurationTics itself returns
                # the raw "not applicable" 0 (matching the JSON's null); the
                # DSP041_UNBOUNDED_DURATION_TICS substitution only happens
                # later, in DSP041SpawnProjectile's runtime spawn path, not
                # in the compiled row DS_P041_MAP27_ROW reports here.
                duration_tics = 0
            explosion_radius_milli = row.get("explosion_radius_milli_units")
            if explosion_radius_milli is None:
                units = row.get("explosion_radius_units")
                explosion_radius_milli = units * 1000 if units is not None else 0
            expected[(system_id, rank)] = {
                "damage_milli": int(row["damage_milli"]),
                "area_milli": int(row["area_milli"]),
                "speed_milli": int(row["speed_milli"]),
                "amount": int(row["amount"]),
                "duration_tics": int(duration_tics),
                "cooldown_tics": int(row["cooldown_tics"]),
                "child_interval_tics": int(row.get("child_interval_tics", 0)),
                "hit_delay_tics": int(row["hit_delay_tics"]),
                "contact_radius_milli": int(row["contact_radius_milli_units"]),
                "explosion_chance_milli": int(row.get("explosion_chance_milli", 0)),
                "explosion_radius_milli": int(explosion_radius_milli),
                "bounce_budget": int(row.get("bounce_budget", bounce_budget)),
                "pierces_enemies": pierces,
                "bounces_off_enemies": bounces,
            }
    return expected


def validate_boot(package: Path, seconds: float = 20) -> dict:
    """Item 1: every DS_P041_MAP27_ROW the engine's "boot" mode compiles from
    DSP041BounceRows must equal, field by field, the corresponding rank row
    parsed straight out of data/verified/base/weapons/bounce/*.json -- the
    33 rows are 8 (Runetracer) + 1 (NO FUTURE) + 8 (Bone) + 8 (Cherry Bomb)
    + 8 (Carréllo)."""
    expected = _expected_rows_from_json()
    result = run_mode(package, "boot", seconds=seconds)
    errors: list[str] = []
    rows = result["compiled_rows"]
    FIELDS = ("damage_milli", "area_milli", "speed_milli", "amount",
              "duration_tics", "cooldown_tics", "child_interval_tics",
              "hit_delay_tics", "contact_radius_milli", "explosion_chance_milli",
              "explosion_radius_milli", "bounce_budget", "pierces_enemies",
              "bounces_off_enemies")
    seen: set[tuple[int, int]] = set()
    per_row_report = []
    for row in rows:
        system_id = _int_or_none(row.get("system_id"))
        rank = _int_or_none(row.get("rank"))
        key = (system_id, rank)
        seen.add(key)
        want = expected.get(key)
        if want is None:
            errors.append(f"engine emitted unexpected row system_id={system_id} rank={rank}")
            continue
        mismatches = {}
        for field in FIELDS:
            actual_value = _int_or_none(row.get(field))
            expected_value = want[field]
            if actual_value != expected_value:
                mismatches[field] = {"engine": actual_value, "json": expected_value}
        if mismatches:
            errors.append(f"system_id={system_id} rank={rank}: field mismatches: {mismatches}")
        per_row_report.append({"system_id": system_id, "rank": rank, "mismatches": mismatches})
    missing = set(expected.keys()) - seen
    for system_id, rank in sorted(missing):
        errors.append(f"engine never emitted expected row system_id={system_id} rank={rank}")
    if len(rows) != 33:
        errors.append(f"expected exactly 33 compiled rows, engine emitted {len(rows)}")
    report = {
        "status": "PASS" if not errors else "FAIL",
        "check": "p041_boot_rows_match_verified_json",
        "errors": errors,
        "evidence": result.get("evidence"),
        "p041_complete": result.get("p041_complete"),
        "row_count": len(rows),
        "expected_row_count": len(expected),
        "per_row": per_row_report,
    }
    if result.get("evidence"):
        report["report_path"] = _write_verdict(result["evidence"], "boot", report)
    return report


CHERRY_AUDIT_TOLERANCE_MILLI = 15  # +/-1.5 percentage points (~3 sigma at n=10000)


def validate_cherry_audit(package: Path, seconds: float = 20) -> dict:
    """Item 2: RunIsolatedCherryRngAudit (BounceMap27Runtime.zs) now calls
    the real production DSP041RollExplosionChanceOnState formula
    (BounceTargeting.zs) against a dedicated audit-state variable, >=10,000
    rolls each at the three chances actually in the rows (40/50/60%), and
    prints the live gameplay dsp041BounceRng state before/after to prove the
    audit never touched it. Tolerance +/-1.5 percentage points (~3 sigma for
    n=10,000, p in [0.4,0.6]: sigma = sqrt(p(1-p)/n) ~= 0.0049 -> 3 sigma
    ~= 1.47 pct pts)."""
    result = run_mode(package, "cherry_audit", seconds=seconds)
    errors: list[str] = []
    rows = result["cherry_rng_audit_rows"]
    by_chance = {_int_or_none(r.get("chance_milli")): r for r in rows}
    for expected_chance in (400, 500, 600):
        row = by_chance.get(expected_chance)
        if row is None:
            errors.append(f"missing cherry RNG audit row for chance_milli={expected_chance}")
            continue
        trials = _int_or_none(row.get("trials"))
        if trials is None or trials < 10000:
            errors.append(f"chance_milli={expected_chance}: trials={trials} < 10000")
        production_fn = row.get("production_function")
        if production_fn != "DSP041RollExplosionChanceOnState":
            errors.append(f"chance_milli={expected_chance}: did not call the real production roll function (got {production_fn})")
        stream = row.get("rng_stream")
        if stream != "ISOLATED_AUDIT_STATE":
            errors.append(f"chance_milli={expected_chance}: rng_stream={stream}, expected ISOLATED_AUDIT_STATE")
        delta_milli = _float_or_none(row.get("delta_milli"))
        if delta_milli is None or abs(delta_milli) > CHERRY_AUDIT_TOLERANCE_MILLI:
            errors.append(f"chance_milli={expected_chance}: delta_milli={delta_milli} exceeds +/-{CHERRY_AUDIT_TOLERANCE_MILLI}")
    live_rows = result["cherry_rng_audit_live_rows"]
    if not live_rows:
        errors.append("missing DS_P041_CHERRY_RNG_AUDIT_LIVE_STATE marker")
    else:
        live = live_rows[0]
        if _int_or_none(live.get("unchanged")) != 1:
            errors.append(f"live gameplay RNG state changed across the audit: before={live.get('live_rng_before')} after={live.get('live_rng_after')}")
    report = {
        "status": "PASS" if not errors else "FAIL",
        "check": "p041_cherry_audit_production_function_isolated_state",
        "errors": errors,
        "evidence": result.get("evidence"),
        "p041_complete": result.get("p041_complete"),
        "audit_rows": rows,
        "live_state_rows": live_rows,
        "tolerance_milli": CHERRY_AUDIT_TOLERANCE_MILLI,
    }
    if result.get("evidence"):
        report["report_path"] = _write_verdict(result["evidence"], "cherry_audit", report)
    return report


def _expected_no_future_damage(armor_points: int, might_milli: int = 1000) -> int:
    """30 * (1 + 0.1*Armor) * Might, all fixed-point milli math mirroring
    DSP041NotifyPlayerContactDamage/DSP041ScaledDamage exactly:
    scaledDamageMilli = damageMilli * (1000 + 100*Armor) / 1000; then
    amount = scaledDamageMilli * mightMilli / 1000 / 1000."""
    damage_milli = 30000
    armor_bonus_milli = 1000 + 100 * armor_points
    scaled_damage_milli = damage_milli * armor_bonus_milli // 1000
    return scaled_damage_milli * might_milli // 1000 // 1000


def validate_no_future(package: Path, seconds: float = 20) -> dict:
    """Item 3: a player-hit explosion, suppression of a second notification
    inside 18 tics, a later notification exploding again, and explosion
    damage = 30 * (1 + 0.1*Armor) * Might for >=2 Armor values. The
    "no_future" fixture mode fires DSP041NotifyPlayerContactDamage at tic 40
    (gate open -> accepted, explodes) and tic 45 (5 tics later, inside the
    18-tic gate -> suppressed, no second explosion). This validator drives
    two independent engine runs at Armor=1 and Armor=3 (via the
    ds_p041_no_future_armor CONTROLLED_ENGINE_FIXTURE cvar/ReadNoFutureArmorOverride)
    and checks both the gate behavior and the damage formula on each."""
    errors: list[str] = []
    per_armor: dict[int, dict] = {}
    for armor_points in (1, 3):
        result = run_mode(package, "no_future", seconds=seconds, armor_points=armor_points)
        explosions = result["no_future_rows"]
        hit_rows = [h for h in result["explosion_hit_rows"] if h.get("kind") == "NO_FUTURE"]
        hit_tics = sorted(t for t in (_int_or_none(h.get("tic")) for h in hit_rows) if t is not None)
        gate_ready_tics = sorted(set(t for t in (_int_or_none(e.get("gate_ready_tic")) for e in explosions) if t is not None))
        label = f"armor={armor_points}"
        # DSP041NotifyPlayerContactDamage returns early (before printing its
        # own DS_P041_NO_FUTURE_EXPLOSION marker) whenever the gate is
        # closed, so the tic-45 call (suppressed) never emits a notification
        # row at all -- only the two ACCEPTED calls (tic 40, tic 60) do.
        # Suppression itself is proven below via the absence of a tic-45
        # entry in hit_tics.
        if len(explosions) != 2:
            errors.append(f"{label}: expected exactly 2 accepted notifications (tic 40, tic 60 -- the tic-45 gated call emits none), found {len(explosions)}")
        if len(hit_tics) < 1:
            errors.append(f"{label}: no NO_FUTURE explosion hit was ever applied")
        elif hit_tics[0] != 40:
            errors.append(f"{label}: first NO_FUTURE explosion hit landed at tic {hit_tics[0]}, expected tic 40")
        if 45 in hit_tics:
            errors.append(f"{label}: the tic-45 notification (5 tics after tic 40, inside the 18-tic gate) exploded -- expected it suppressed: {hit_tics}")
        if 60 not in hit_tics:
            errors.append(f"{label}: expected a later (well past the 18-tic gate) notification at tic 60 to explode again, hit_tics={hit_tics}")
        if len(gate_ready_tics) < 1:
            errors.append(f"{label}: no gate_ready_tic ever recorded")
        expected_damage = _expected_no_future_damage(armor_points)
        for hit in hit_rows:
            actual_damage = _int_or_none(hit.get("damage"))
            if actual_damage != expected_damage:
                errors.append(f"{label}: tic={hit.get('tic')}: damage={actual_damage} != expected {expected_damage} (30*(1+0.1*{armor_points})*Might)")
        per_armor[armor_points] = {
            "evidence": result.get("evidence"), "p041_complete": result.get("p041_complete"),
            "notification_rows": explosions, "explosion_hit_rows": hit_rows,
            "hit_tics": hit_tics, "gate_ready_tics": gate_ready_tics,
            "expected_damage": expected_damage,
        }
    first_run = per_armor.get(1, {})
    report = {
        "status": "PASS" if not errors else "FAIL",
        "check": "p041_no_future_player_hit_explosion_gate_and_formula",
        "errors": errors,
        "evidence": first_run.get("evidence"),
        "p041_complete": first_run.get("p041_complete"),
        "per_armor": per_armor,
    }
    if first_run.get("evidence"):
        report["report_path"] = _write_verdict(first_run["evidence"], "no_future", report)
    return report


def validate_pause(package: Path, seconds: float = 30) -> dict:
    """Item 4: native pause (real menu, like GlobalMap26Runtime's MAP26
    pattern) with the persistence-hash state identical before/after, and
    motion resuming afterwards (bounce_count/age advancing again once
    resumed)."""
    result = run_mode(package, "pause", seconds=seconds)
    errors: list[str] = []
    starts = result["pause_start_rows"]
    helds = result["pause_held_rows"]
    ends = result["pause_end_rows"]
    if not starts:
        errors.append("missing DS_P041_MAP27_PAUSE_START (native pause was never requested)")
    if not helds:
        errors.append("missing DS_P041_MAP27_PAUSE_HELD (Level.WorldPaused() never observed true)")
    if not ends:
        errors.append("missing DS_P041_MAP27_PAUSE_END (native pause never resumed)")
    accepted = None
    if ends:
        accepted = _int_or_none(ends[0].get("accepted"))
        if accepted != 1:
            errors.append(f"pause end reported accepted={accepted}, expected 1 (hash identical before/after)")
        start_hash = _int_or_none(ends[0].get("start_hash"))
        end_hash = _int_or_none(ends[0].get("end_hash"))
        if start_hash != end_hash:
            errors.append(f"persistence hash changed across pause: {start_hash} != {end_hash}")
    # Motion-resumed proof: bounce/age must still be advancing after the
    # pause window closes, i.e. later BOUNCE rows exist beyond the tic the
    # pause ended at.
    end_tic = _int_or_none(ends[0].get("world_logical_tic")) if ends else None
    later_bounces = [b for b in result["bounce_rows"] if end_tic is not None and _int_or_none(b.get("tic")) is not None and _int_or_none(b.get("tic")) > end_tic]
    if end_tic is not None and not later_bounces:
        errors.append(f"no bounce/motion observed after pause resumed at tic {end_tic} -- motion did not continue")
    report = {
        "status": "PASS" if not errors else "FAIL",
        "check": "p041_native_pause_hash_stable_motion_resumes",
        "errors": errors,
        "evidence": result.get("evidence"),
        "p041_complete": result.get("p041_complete"),
        "pause_start_rows": starts,
        "pause_held_rows": helds,
        "pause_end_rows": ends,
        "later_bounce_count": len(later_bounces),
    }
    if result.get("evidence"):
        report["report_path"] = _write_verdict(result["evidence"], "pause", report)
    return report


def validate_a01(package: Path, seconds: float = 40) -> dict:
    """A01: three fixed-vector Runetracer launches (boundary edge, wall
    segment, exact corner), each compared bounce-for-bounce against the
    independent Python reference_reflect_path, epsilon 0.01 units."""
    ref = _load_reference_module()
    result = run_mode(package, "a01", seconds=seconds)
    errors: list[str] = []
    spawns = _events_by_id(result["projectile_rows"])
    if len(spawns) != 3:
        errors.append(f"expected exactly 3 spawned projectiles, found {len(spawns)}")
    cases = {}
    for event_id, spawn in spawns.items():
        yaw = _int_or_none(spawn.get("aim_yaw_milli"))
        if yaw == 90000:
            cases["edge"] = (event_id, spawn)
        elif yaw == 0:
            cases["wall"] = (event_id, spawn)
        elif yaw == 135000:
            cases["corner"] = (event_id, spawn)
    for expected in ("edge", "wall", "corner"):
        if expected not in cases:
            errors.append(f"missing expected case: {expected}")
    per_case = {}
    for name, (event_id, spawn) in cases.items():
        speed = _float_or_none(spawn.get("speed_ups"))
        duration = _int_or_none(spawn.get("duration_tics"))
        yaw = _int_or_none(spawn.get("aim_yaw_milli"))
        actual = [row for row in result["bounce_rows"] if _int_or_none(row.get("event_id")) == event_id]
        actual_parsed = [{
            "tic": _int_or_none(row.get("tic")), "kind": row.get("kind"),
            "axis_x": _int_or_none(row.get("axis_x")), "axis_y": _int_or_none(row.get("axis_y")),
            "wall_id": _int_or_none(row.get("wall_id")),
            "fraction": _float_or_none(row.get("fraction")),
            "x": _float_or_none(row.get("x")), "y": _float_or_none(row.get("y")),
        } for row in actual]
        reference = ref.reference_reflect_path((0.0, 0.0), yaw, speed, duration, FIXTURE_WALLS_FOR_A01)
        case_report = {"event_id": event_id, "actual": actual_parsed, "reference": reference}
        if len(actual_parsed) != len(reference):
            errors.append(f"{name}: bounce event count diverged: engine={len(actual_parsed)} reference={len(reference)}")
        else:
            for index, (a, r) in enumerate(zip(actual_parsed, reference)):
                if a["tic"] != r["tic"] or a["kind"] != r["kind"]:
                    errors.append(f"{name}[{index}]: tic/kind diverged: {a} != {r}")
                    continue
                if abs(a["x"] - r["x"]) > 0.01 or abs(a["y"] - r["y"]) > 0.01:
                    errors.append(f"{name}[{index}]: position diverged beyond 0.01: {a} != {r}")
                if abs(a["fraction"] - r["fraction"]) > 0.01:
                    errors.append(f"{name}[{index}]: fraction diverged beyond 0.01: {a} != {r}")
        if name == "wall" and not any(row["kind"] == "WALL" for row in actual_parsed):
            errors.append("wall case never produced a WALL bounce")
        if name == "corner" and not any(row["axis_x"] == 1 and row["axis_y"] == 1 for row in actual_parsed):
            errors.append("corner case never produced a both-axes boundary bounce")
        if name == "edge" and any(row["kind"] == "WALL" for row in actual_parsed):
            errors.append("edge case unexpectedly crossed the fixture wall")
        per_case[name] = case_report
    report = {
        "status": "PASS" if not errors else "FAIL",
        "check": "p041_a01_reflection_paths",
        "errors": errors,
        "evidence": result.get("evidence"),
        "p041_complete": result.get("p041_complete"),
        "cases": per_case,
    }
    if result.get("evidence"):
        report["report_path"] = _write_verdict(result["evidence"], "a01", report)
    return report


FIXTURE_WALLS_FOR_A01 = [(60.0, -200.0, 60.0, 200.0)]


def validate_pierce_vs_bounce(package: Path, seconds: float = 30) -> dict:
    """A04: Runetracer/Carréllo (PiercesEnemies) must never produce an ENEMY
    bounce and must accrue >=1 gated pierce hit; Bone/Cherry
    (BouncesOffEnemies) must produce exactly one ENEMY bounce and exactly
    one hit on their target."""
    result = run_mode(package, "pierce_vs_bounce", seconds=seconds)
    errors: list[str] = []
    spawns = _events_by_id(result["projectile_rows"])
    system_of = {event_id: _int_or_none(row.get("system_id")) for event_id, row in spawns.items()}
    PIERCE_SYSTEMS = {54, 58}  # Runetracer, Carréllo
    BOUNCE_SYSTEMS = {56, 57}  # Bone, Cherry
    bounce_kinds = {}
    hit_counts = {}
    hit_tics = {}
    for row in result["bounce_rows"]:
        event_id = _int_or_none(row.get("event_id"))
        bounce_kinds.setdefault(event_id, []).append(row.get("kind"))
    for row in result["hit_rows"]:
        event_id = _int_or_none(row.get("event_id"))
        hit_counts[event_id] = hit_counts.get(event_id, 0) + 1
        hit_tics.setdefault(event_id, []).append(_int_or_none(row.get("tic")))
    per_event = {}
    for event_id, system_id in system_of.items():
        kinds = bounce_kinds.get(event_id, [])
        hits = hit_counts.get(event_id, 0)
        tics = sorted(t for t in hit_tics.get(event_id, []) if t is not None)
        gaps_ok = all(b - a >= 18 for a, b in zip(tics, tics[1:]))
        per_event[event_id] = {"system_id": system_id, "bounce_kinds": kinds,
                                "hit_count": hits, "hit_tics": tics, "gaps_ok": gaps_ok}
        if system_id in PIERCE_SYSTEMS:
            if "ENEMY" in kinds:
                errors.append(f"event {event_id} (system {system_id}) is a pierce weapon but produced an ENEMY bounce")
            if hits < 1:
                errors.append(f"event {event_id} (system {system_id}) is a pierce weapon but never hit its target")
            if not gaps_ok:
                errors.append(f"event {event_id} (system {system_id}) re-hit its target inside the 18-tic gate: {tics}")
        elif system_id in BOUNCE_SYSTEMS:
            if kinds.count("ENEMY") != 1:
                errors.append(f"event {event_id} (system {system_id}) is a bounce weapon but had {kinds.count('ENEMY')} ENEMY bounces, expected exactly 1")
            if hits != 1:
                errors.append(f"event {event_id} (system {system_id}) is a bounce weapon but had {hits} hits, expected exactly 1")
        else:
            errors.append(f"event {event_id}: unrecognized system_id {system_id}")
    for expected_system in PIERCE_SYSTEMS | BOUNCE_SYSTEMS:
        if expected_system not in system_of.values():
            errors.append(f"no spawned projectile for expected system_id {expected_system}")
    report = {
        "status": "PASS" if not errors else "FAIL",
        "check": "p041_a04_pierce_vs_bounce",
        "errors": errors,
        "evidence": result.get("evidence"),
        "p041_complete": result.get("p041_complete"),
        "per_event": per_event,
    }
    if result.get("evidence"):
        report["report_path"] = _write_verdict(result["evidence"], "pierce_vs_bounce", report)
    return report


def validate_capacity(package: Path, seconds: float = 45) -> dict:
    """A03: >=200 total bounces across independent weapon copies of every
    system, with per-pair 18-tic gating on hits and correct expiry reasons
    (DURATION_EXPIRED for Runetracer, BOUNCE_BUDGET_EXHAUSTED for
    Carréllo)."""
    result = run_mode(package, "capacity", seconds=seconds)
    errors: list[str] = []
    total_bounces = len(result["bounce_rows"])
    if total_bounces < 200:
        errors.append(f"total bounces {total_bounces} < 200")
    per_projectile_bounces: dict[int, int] = {}
    for row in result["bounce_rows"]:
        event_id = _int_or_none(row.get("event_id"))
        per_projectile_bounces[event_id] = per_projectile_bounces.get(event_id, 0) + 1
    pair_hit_tics: dict[tuple, list[int]] = {}
    for row in result["hit_rows"]:
        key = (_int_or_none(row.get("event_id")), _int_or_none(row.get("target_id")))
        pair_hit_tics.setdefault(key, []).append(_int_or_none(row.get("tic")))
    gate_violations = []
    for key, tics in pair_hit_tics.items():
        tics_sorted = sorted(t for t in tics if t is not None)
        for a, b in zip(tics_sorted, tics_sorted[1:]):
            if b - a < 18:
                gate_violations.append({"pair": key, "gap": b - a})
    if gate_violations:
        errors.append(f"{len(gate_violations)} hit pairs violated the 18-tic gate")
    spawns = _events_by_id(result["projectile_rows"])
    system_of = {event_id: _int_or_none(row.get("system_id")) for event_id, row in spawns.items()}
    duration_expired_runetracer = 0
    budget_exhausted_carrello = 0
    for row in re.finditer(r"DS_P041_PROJECTILE_END (\S.*)", result["log_text"]):
        parsed = dict(KV_RE.findall(row.group(1)))
        event_id = _int_or_none(parsed.get("event_id"))
        reason = parsed.get("reason")
        system_id = system_of.get(event_id)
        if reason == "DURATION_EXPIRED" and system_id == 54:
            duration_expired_runetracer += 1
        if reason == "BOUNCE_BUDGET_EXHAUSTED" and system_id == 58:
            budget_exhausted_carrello += 1
    if duration_expired_runetracer < 1:
        errors.append("no Runetracer projectile expired via DURATION_EXPIRED")
    if budget_exhausted_carrello < 1:
        errors.append("no Carréllo projectile expired via BOUNCE_BUDGET_EXHAUSTED")
    report = {
        "status": "PASS" if not errors else "FAIL",
        "check": "p041_a03_capacity",
        "errors": errors,
        "evidence": result.get("evidence"),
        "p041_complete": result.get("p041_complete"),
        "total_bounces": total_bounces,
        "per_projectile_bounces": per_projectile_bounces,
        "gate_violations": gate_violations,
        "duration_expired_runetracer_count": duration_expired_runetracer,
        "budget_exhausted_carrello_count": budget_exhausted_carrello,
    }
    if result.get("evidence"):
        report["report_path"] = _write_verdict(result["evidence"], "capacity", report)
    return report


def validate_no_tunnel(package: Path, seconds: float = 20) -> dict:
    """High-speed no-tunnelling: a projectile at 4.5x base speed against a
    thin wall and a small (radius 1) target must still register both the
    pierce hit and the later wall reflection -- neither swept contact may be
    skipped by the large per-tic step."""
    result = run_mode(package, "no_tunnel", seconds=seconds)
    errors: list[str] = []
    overrides = result["no_tunnel_override_rows"]
    if len(overrides) != 1:
        errors.append(f"expected exactly one speed override row, found {len(overrides)}")
    # A pierce weapon on this on-axis fixture legitimately keeps
    # re-crossing the same small target every time it bounces back through
    # the origin (gated to one hit per 18 tics, same as A04/A03) -- so >=1
    # hit is the real expectation, not exactly one; only the *first* hit
    # (the actual no-tunnelling proof) must land at tic 1.
    hit_rows = result["hit_rows"]
    if not hit_rows:
        errors.append("expected at least one hit on the small target, found none")
    hit_tics = sorted(_int_or_none(row.get("tic")) for row in hit_rows)
    if hit_tics and hit_tics[0] != 1:
        errors.append(f"expected the first target hit at tic 1 (swept within the first tic), got {hit_tics[0]}")
    if any(b - a < 18 for a, b in zip(hit_tics, hit_tics[1:])):
        errors.append(f"repeated target hits violated the 18-tic gate: {hit_tics}")
    if hit_rows and _int_or_none(hit_rows[0].get("health_after")) >= _int_or_none(hit_rows[0].get("health_before")):
        errors.append("hit row shows no health decrease -- damage not actually applied")
    wall_bounces = [row for row in result["bounce_rows"] if row.get("kind") == "WALL"]
    if not wall_bounces:
        errors.append("no WALL bounce registered -- possible tunnelling through the fixture wall")
    else:
        wall_tic = _int_or_none(wall_bounces[0].get("tic"))
        if wall_tic is None or wall_tic > 3:
            errors.append(f"WALL bounce occurred later than expected (tic={wall_tic}); check for a missed early crossing")
    report = {
        "status": "PASS" if not errors else "FAIL",
        "check": "p041_high_speed_no_tunnelling",
        "errors": errors,
        "evidence": result.get("evidence"),
        "p041_complete": result.get("p041_complete"),
        "overrides": overrides,
        "hit_rows": hit_rows,
        "wall_bounces": wall_bounces,
    }
    if result.get("evidence"):
        report["report_path"] = _write_verdict(result["evidence"], "no_tunnel", report)
    return report


def validate_rebase(package: Path, seconds: float = 30) -> dict:
    """Item 5: reflections must use the boundary of the player position at
    that tic (moving boundary), and DSP041Rebase must translate position
    only, leaving age/bounce/hit counts unchanged."""
    ref = _load_reference_module()
    result = run_mode(package, "rebase", seconds=seconds)
    errors: list[str] = []
    snapshots = result["snapshot_rows"]
    pre = {row["event_id"]: row for row in snapshots if row.get("label") == "PRE_REBASE"}
    post = {row["event_id"]: row for row in snapshots if row.get("label") == "POST_REBASE"}
    if not pre or not post:
        errors.append("missing PRE_REBASE/POST_REBASE snapshot rows")
    for event_id in pre:
        if event_id not in post:
            errors.append(f"event {event_id}: present pre-rebase, missing post-rebase")
            continue
        before = pre[event_id]
        after = post[event_id]
        for field in ("age_tics", "bounce_count", "hit_count"):
            if before.get(field) != after.get(field):
                errors.append(f"event {event_id}: {field} changed across rebase: {before.get(field)} -> {after.get(field)}")
        dx = _float_or_none(after.get("x")) - _float_or_none(before.get("x"))
        dy = _float_or_none(after.get("y")) - _float_or_none(before.get("y"))
        if abs(dx - 96.0) > 0.01 or abs(dy - 32.0) > 0.01:
            errors.append(f"event {event_id}: position delta {dx},{dy} != expected 96,32")
    spawns = _events_by_id(result["projectile_rows"])
    for event_id, spawn in spawns.items():
        yaw = _int_or_none(spawn.get("aim_yaw_milli"))
        speed = _float_or_none(spawn.get("speed_ups"))
        duration = _int_or_none(spawn.get("duration_tics"))
        def player_pos_at(tic: int, _event_id=event_id):
            return (0.0, 0.0) if tic < 20 else (96.0, 32.0)
        actual = [{
            "tic": _int_or_none(row.get("tic")), "kind": row.get("kind"),
            "axis_x": _int_or_none(row.get("axis_x")), "axis_y": _int_or_none(row.get("axis_y")),
            "wall_id": _int_or_none(row.get("wall_id")),
            "fraction": _float_or_none(row.get("fraction")),
            "x": _float_or_none(row.get("x")), "y": _float_or_none(row.get("y")),
        } for row in result["bounce_rows"] if _int_or_none(row.get("event_id")) == event_id]
        reference = ref.reference_reflect_path((0.0, 0.0), yaw, speed, duration, FIXTURE_WALLS_FOR_A01,
                                                 player_pos_at=player_pos_at)
        if len(actual) != len(reference):
            errors.append(f"event {event_id}: moving-boundary bounce count diverged: engine={len(actual)} reference={len(reference)}")
            continue
        for index, (a, r) in enumerate(zip(actual, reference)):
            if a["tic"] != r["tic"] or a["kind"] != r["kind"]:
                errors.append(f"event {event_id}[{index}]: tic/kind diverged: {a} != {r}")
                continue
            if abs(a["x"] - r["x"]) > 0.01 or abs(a["y"] - r["y"]) > 0.01:
                errors.append(f"event {event_id}[{index}]: position diverged beyond 0.01: {a} != {r}")
    report = {
        "status": "PASS" if not errors else "FAIL",
        "check": "p041_moving_boundary_rebase",
        "errors": errors,
        "evidence": result.get("evidence"),
        "p041_complete": result.get("p041_complete"),
        "pre_rebase_snapshots": pre,
        "post_rebase_snapshots": post,
    }
    if result.get("evidence"):
        report["report_path"] = _write_verdict(result["evidence"], "rebase", report)
    return report


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--modes", default=",".join(ALL_MODES))
    parser.add_argument("--camera-invariance", action="store_true")
    parser.add_argument("--camera-window-invariance", action="store_true")
    parser.add_argument("--save-roundtrip", action="store_true")
    parser.add_argument("--validate", default="",
                         help="comma-separated validators to run instead of --modes: "
                              "boot,a01,pierce_vs_bounce,capacity,no_tunnel,rebase,"
                              "cherry_audit,no_future,pause")
    parser.add_argument("--seconds", type=float, default=30)
    parser.add_argument("--out", type=Path, default=ROOT / "build" / "evidence" / "P041" / "verdict.json")
    args = parser.parse_args()

    build(ROOT, "none", ROOT / "maps/source/p041-bounce/room.json")
    package = ROOT / "build" / "doom-survivors.ipk3"

    VALIDATORS = {
        "boot": validate_boot,
        "a01": validate_a01,
        "pierce_vs_bounce": validate_pierce_vs_bounce,
        "capacity": validate_capacity,
        "no_tunnel": validate_no_tunnel,
        "rebase": validate_rebase,
        "cherry_audit": validate_cherry_audit,
        "no_future": validate_no_future,
        "pause": validate_pause,
    }

    results: dict[str, object] = {}
    if args.camera_invariance:
        results["camera_invariance"] = camera_invariance(package, args.seconds)
    elif args.camera_window_invariance:
        results["camera_window_invariance"] = camera_window_invariance(package, args.seconds)
    elif args.save_roundtrip:
        results["save_roundtrip"] = run_save_roundtrip(package)
    elif args.validate:
        for name in args.validate.split(","):
            name = name.strip()
            if not name:
                continue
            if name not in VALIDATORS:
                raise SystemExit(f"unknown validator: {name}")
            results[name] = VALIDATORS[name](package, seconds=args.seconds)
    else:
        for mode in args.modes.split(","):
            mode = mode.strip()
            if not mode:
                continue
            results[mode] = run_mode(package, mode, seconds=args.seconds)

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(results, indent=2, default=str))
    print(f"wrote {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
