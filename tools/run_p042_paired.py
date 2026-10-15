"""Build and run the controlled MAP28 P042 paired-union/chain fixture.

Modelled on tools/run_p041_bounce.py: this fixture
(src/zscript/ui/paired/PairedMap28Runtime.zs) now covers the full
docs/contracts/paired-unions.md acceptance matrix -- boot, chain, the union
A01-A04 matrix/negative/attribution/patterns/burst_union modes, plus P042-N1's
remaining items: vento_streak (movement-streak growth/reset), fuwala_heal
(crit healing through the P039 authority + an isolated crit-rate audit),
pause (real native menu pause) and save (native save/load across a union
with an in-flight child, via --save-roundtrip). This runner builds the
MAP28 package once per invocation, runs the requested mode/validator (each
an independent engine process against the pinned UZDoom runtime), and
extracts the DS_P042_MAP28_*/DS_P042_* Console.Printf markers as evidence.
Nothing here is reported PASS unless the parsed markers actually satisfy the
check -- callers must still look at the written verdict JSON, per project
policy.

Usage:
    python tools/run_p042_paired.py --validate boot,chain
    python tools/run_p042_paired.py --validate vento_streak,fuwala_heal,pause
    python tools/run_p042_paired.py --save-roundtrip
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

ALL_MODES = ("boot", "chain", "union_matrix", "union_negative",
             "attribution", "patterns", "burst_union", "vento_streak",
             "fuwala_heal", "pause")
COMPLETE_RE = re.compile(r"DS_P042_MAP28_COMPLETE (\S.*)")
KV_RE = re.compile(r"(\w+)=(\S+)")
ROW_RE = re.compile(r"DS_P042_MAP28_ROW (\S.*)")
ROW_COUNT_RE = re.compile(r"DS_P042_MAP28_ROW_COUNT (\S.*)")
CHAIN_STEP_RE = re.compile(r"DS_P042_MAP28_CHAIN_STEP (\S.*)")
HIT_RE = re.compile(r"DS_P042_HIT (\S.*)")
TRANSFORM_RE = re.compile(r"DS_P032_TRANSFORM (\S.*)")
CASE_SETUP_RE = re.compile(r"DS_P042_MAP28_CASE_SETUP (\S.*)")
UNION_RE = re.compile(r"DS_P042_MAP28_UNION (\S.*)")
REUSE_RE = re.compile(r"DS_P042_MAP28_REUSE (\S.*)")
FIRE_CHECK_RE = re.compile(r"DS_P042_MAP28_FIRE_CHECK (\S.*)")
SNAPSHOT_RE = re.compile(r"DS_P042_MAP28_SNAPSHOT (\S.*)")
SNAPSHOT_SUMMARY_RE = re.compile(r"DS_P042_MAP28_SNAPSHOT_SUMMARY (\S.*)")
NEG_CASE_RE = re.compile(r"DS_P042_MAP28_NEG_CASE (\S.*)")
GUN_SPAWN_RE = re.compile(r"DS_P042_GUN_SPAWN (\S.*)")
GUN_PENDING_SCHEDULE_RE = re.compile(r"DS_P042_GUN_PENDING_SCHEDULE (\S.*)")
GUN_PENDING_CANCELLED_RE = re.compile(r"DS_P042_GUN_PENDING_CANCELLED (\S.*)")
EVOLVE_IN_PLACE_RE = re.compile(r"DS_P042_EVOLVE_IN_PLACE (\S.*)")
CANCEL_WEAPON_RE = re.compile(r"DS_P042_CANCEL_WEAPON (\S.*)")
PHIERAGGI_VOLLEY_RE = re.compile(r"DS_P042_PHIERAGGI_VOLLEY (\S.*)")
ATTR_UNION_RE = re.compile(r"DS_P042_MAP28_ATTR_UNION (\S.*)")
PATTERNS_SETUP_RE = re.compile(r"DS_P042_MAP28_PATTERNS_SETUP (\S.*)")
BURST_UNION_RE = re.compile(r"DS_P042_MAP28_BURST_UNION (\S.*)")
BURST_UPGRADE_RE = re.compile(r"DS_P042_MAP28_BURST_UPGRADE (\S.*)")
CAMERA_RE = re.compile(r"DS_P042_MAP28_CAMERA (\S.*)")
STREAK_TICK_RE = re.compile(r"DS_P042_MAP28_STREAK_TICK (\S.*)")
HEAL_VOLLEY_RE = re.compile(r"DS_P042_MAP28_HEAL_VOLLEY (\S.*)")
HEAL_CAP_SETUP_RE = re.compile(r"DS_P042_MAP28_HEAL_CAP_SETUP (\S.*)")
CRIT_RNG_AUDIT_RE = re.compile(r"DS_P042_CRIT_RNG_AUDIT (\S.*)")
CRIT_RNG_LIVE_UNCHANGED_RE = re.compile(r"DS_P042_CRIT_RNG_LIVE_UNCHANGED (\S.*)")
PAUSE_START_RE = re.compile(r"DS_P042_MAP28_PAUSE_START (\S.*)")
PAUSE_HELD_RE = re.compile(r"DS_P042_MAP28_PAUSE_HELD (\S.*)")
PAUSE_END_RE = re.compile(r"DS_P042_MAP28_PAUSE_END (\S.*)")
SAVE_UNION_RE = re.compile(r"DS_P042_MAP28_SAVE_UNION (\S.*)")
SAVE_FROZEN_RE = re.compile(
    r"DS_P042_MAP28_SAVE_FROZEN accepted=1 tic=(\d+) hash=(-?\d+) "
    r"inventory_hash=(-?\d+) surviving_weapon_index=(-?\d+) pending_output_schedule=1")
RESTORE_RE = re.compile(
    r"DS_P042_MAP28_RESTORE first_tick=1 tic=(\d+) hash=(-?\d+) inventory_hash=(-?\d+) "
    r"continuation=1 mid_flight=(\d+) exact_hash=(\d+) exact_inventory_hash=(\d+) "
    r"surviving_weapon_index=(-?\d+)")


def _parse_complete(log: str) -> dict[str, str] | None:
    match = COMPLETE_RE.search(log)
    if match is None:
        return None
    return dict(KV_RE.findall(match.group(1)))


def _rows(text: str, pattern: re.Pattern) -> list[dict[str, str]]:
    return [dict(KV_RE.findall(m.group(1))) for m in pattern.finditer(text)]


def _int_or_none(value):
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def run_mode(package: Path, mode: str, seconds: float = 20, body_yaw: int | None = None,
             camera_variant: int | None = None, window_width: int = 1280,
             window_height: int = 720) -> dict:
    startup = ["+set", "ds_p042_mode", mode]
    if body_yaw is not None:
        startup += ["+set", "ds_p042_body_yaw", str(body_yaw)]
    if camera_variant is not None:
        startup += ["+set", "ds_p042_camera_variant", str(camera_variant)]
    result = run(package, seconds=seconds, compile_only=False, evidence_phase="P042",
                 map_name="MAP28", completion_marker="DS_P042_MAP28_COMPLETE",
                 startup_commands=startup, window_width=window_width,
                 window_height=window_height)
    log = Path(result["evidence"]) / "engine.log"
    text = log.read_text(encoding="utf-8", errors="replace")
    result["p042_complete"] = _parse_complete(text)
    result["mode"] = mode
    result["body_yaw"] = body_yaw
    result["camera_variant"] = camera_variant
    result["window_width"] = window_width
    result["window_height"] = window_height
    result["row_rows"] = _rows(text, ROW_RE)
    result["row_count_rows"] = _rows(text, ROW_COUNT_RE)
    result["chain_step_rows"] = _rows(text, CHAIN_STEP_RE)
    result["hit_rows"] = _rows(text, HIT_RE)
    result["transform_rows"] = _rows(text, TRANSFORM_RE)
    result["case_setup_rows"] = _rows(text, CASE_SETUP_RE)
    result["union_rows"] = _rows(text, UNION_RE)
    result["reuse_rows"] = _rows(text, REUSE_RE)
    result["fire_check_rows"] = _rows(text, FIRE_CHECK_RE)
    result["snapshot_rows"] = _rows(text, SNAPSHOT_RE)
    result["snapshot_summary_rows"] = _rows(text, SNAPSHOT_SUMMARY_RE)
    result["neg_case_rows"] = _rows(text, NEG_CASE_RE)
    result["gun_spawn_rows"] = _rows(text, GUN_SPAWN_RE)
    result["gun_pending_schedule_rows"] = _rows(text, GUN_PENDING_SCHEDULE_RE)
    result["gun_pending_cancelled_rows"] = _rows(text, GUN_PENDING_CANCELLED_RE)
    result["evolve_in_place_rows"] = _rows(text, EVOLVE_IN_PLACE_RE)
    result["cancel_weapon_rows"] = _rows(text, CANCEL_WEAPON_RE)
    result["phieraggi_volley_rows"] = _rows(text, PHIERAGGI_VOLLEY_RE)
    result["attr_union_rows"] = _rows(text, ATTR_UNION_RE)
    result["patterns_setup_rows"] = _rows(text, PATTERNS_SETUP_RE)
    result["burst_union_rows"] = _rows(text, BURST_UNION_RE)
    result["burst_upgrade_rows"] = _rows(text, BURST_UPGRADE_RE)
    result["camera_rows"] = _rows(text, CAMERA_RE)
    result["streak_tick_rows"] = _rows(text, STREAK_TICK_RE)
    result["heal_volley_rows"] = _rows(text, HEAL_VOLLEY_RE)
    result["heal_cap_setup_rows"] = _rows(text, HEAL_CAP_SETUP_RE)
    result["crit_rng_audit_rows"] = _rows(text, CRIT_RNG_AUDIT_RE)
    result["crit_rng_live_unchanged_rows"] = _rows(text, CRIT_RNG_LIVE_UNCHANGED_RE)
    result["pause_start_rows"] = _rows(text, PAUSE_START_RE)
    result["pause_held_rows"] = _rows(text, PAUSE_HELD_RE)
    result["pause_end_rows"] = _rows(text, PAUSE_END_RE)
    result["log_text"] = text
    return result


def _write_verdict(evidence_dir: str | Path, mode: str, report: dict) -> str:
    out_path = Path(evidence_dir) / f"p042-{mode}-validation.json"
    out_path.write_text(json.dumps(report, indent=2, default=str) + "\n", encoding="utf-8")
    return str(out_path)


DATA_DIR = ROOT / "data" / "verified" / "base" / "weapons" / "paired"
JSON_FILES = {
    59: "peachone.json",
    60: "ebony-wings.json",
    61: "vandalier.json",
    62: "phiera.json",
    63: "eight.json",
    64: "phieraggi.json",
    65: "vento-sacro.json",
    66: "fuwalafuwaloo.json",
    67: "bracelet.json",
    68: "bi-bracelet.json",
    69: "tri-bracelet.json",
}
EXPECTED_TOTAL_ROWS = 8 + 8 + 8 + 8 + 8 + 1 + 8 + 1 + 6 + 6 + 6  # 68

FIELDS = ("damage_milli", "area_milli", "speed_milli", "amount", "pierce",
          "cooldown_tics", "interval_tics", "duration_tics", "pool",
          "knockback_milli", "crit_chance_milli", "crit_multiplier_milli",
          "movement_streak_cap_milli", "movement_streak_step_milli",
          "hits_wall", "passes_wall", "ignores_duration")


def _expected_rows_from_json() -> dict[tuple[int, int], dict[str, int]]:
    """Loads every rank row directly from
    data/verified/base/weapons/paired/*.json (the canonical source mirror)
    and maps it to the exact field set DS_P042_MAP28_ROW emits, so the boot
    validator compares engine output against the JSON, never against
    PairedRows.zs itself (which is the file under test)."""
    expected: dict[tuple[int, int], dict[str, int]] = {}
    for system_id, filename in JSON_FILES.items():
        doc = json.loads((DATA_DIR / filename).read_text(encoding="utf-8"))
        step_milli = 0
        streak = doc.get("movement_streak")
        if isinstance(streak, dict):
            step_milli = int(streak.get("step_milli_per_period", 0) or 0)
        for row in doc["rank_rows"]:
            rank = int(row["rank"])
            # Birds/Vandalier report a raw "knockback" multiplier (e.g. 2.0);
            # every other system already reports "knockback_milli" directly.
            # DSP042PairedRows.KnockbackMilli always returns milli units, so
            # the raw form must be scaled by 1000 to compare like for like.
            if "knockback_milli" in row:
                knockback = row.get("knockback_milli")
            elif "knockback" in row and row.get("knockback") is not None:
                knockback = row.get("knockback") * 1000
            else:
                knockback = None
            expected[(system_id, rank)] = {
                "damage_milli": int(row["damage_milli"]),
                "area_milli": int(row["area_milli"]),
                "speed_milli": int(row["speed_milli"]),
                "amount": int(row["amount"]),
                "pierce": int(row.get("pierce", 0) or 0),
                "cooldown_tics": int(row["cooldown_tics"]),
                "interval_tics": int(row["interval_tics"]),
                "duration_tics": int(row.get("duration_tics", 0) or 0),
                "pool": int(row["pool"]),
                "knockback_milli": int(knockback) if knockback is not None else 0,
                "crit_chance_milli": int(row.get("crit_chance_milli", 0) or 0),
                "crit_multiplier_milli": int(row.get("crit_multiplier_milli", 0) or 0),
                "movement_streak_cap_milli": int(row.get("movement_streak_cap_milli", 0) or 0),
                "movement_streak_step_milli": step_milli if row.get("movement_streak_cap_milli") else 0,
                "hits_wall": 1 if row.get("hits_wall") else 0,
                "passes_wall": 1 if row.get("passes_wall") else 0,
                "ignores_duration": 1 if row.get("ignores_duration") else 0,
            }
    return expected


def validate_boot(package: Path, seconds: float = 20) -> dict:
    """Item 1 (deliverable 4, boot): every DS_P042_MAP28_ROW the engine's
    "boot" mode compiles from DSP042PairedRows must equal, field by field,
    the corresponding rank row parsed straight out of
    data/verified/base/weapons/paired/*.json -- 68 rows total across the
    eleven systems."""
    expected = _expected_rows_from_json()
    result = run_mode(package, "boot", seconds=seconds)
    errors: list[str] = []
    rows = result["row_rows"]
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
    if len(rows) != EXPECTED_TOTAL_ROWS:
        errors.append(f"expected exactly {EXPECTED_TOTAL_ROWS} compiled rows, engine emitted {len(rows)}")
    report = {
        "status": "PASS" if not errors else "FAIL",
        "check": "p042_boot_rows_match_verified_json",
        "errors": errors,
        "evidence": result.get("evidence"),
        "p042_complete": result.get("p042_complete"),
        "row_count": len(rows),
        "expected_row_count": len(expected),
        "per_row": per_row_report,
    }
    if result.get("evidence"):
        report["report_path"] = _write_verdict(result["evidence"], "boot", report)
    return report


def validate_chain(package: Path, seconds: float = 25) -> dict:
    """Deliverable 4, chain: Bracelet rank 6 -> Bi-Bracelet via recipe 204
    in place (same slot identity index), then Bi rank 6 -> Tri via 205, the
    old form's future firing cancelled (no parent-owned new emissions after
    the evolve tic), and at least one accepted hit from each form
    generation attributed to the correct system."""
    result = run_mode(package, "chain", seconds=seconds)
    errors: list[str] = []
    steps = result["chain_step_rows"]
    if len(steps) != 2:
        errors.append(f"expected exactly 2 DS_P042_MAP28_CHAIN_STEP rows, found {len(steps)}")
    step1 = next((s for s in steps if _int_or_none(s.get("step")) == 1), None)
    step2 = next((s for s in steps if _int_or_none(s.get("step")) == 2), None)
    weapon_index = None
    if step1 is None:
        errors.append("missing chain step 1 (Bracelet -> Bi-Bracelet, recipe 204)")
    else:
        weapon_index = _int_or_none(step1.get("weapon_index"))
        if _int_or_none(step1.get("accepted")) != 1:
            errors.append(f"chain step 1 was not accepted: {step1}")
        if _int_or_none(step1.get("recipe")) != 204:
            errors.append(f"chain step 1 used recipe {step1.get('recipe')}, expected 204")
        if _int_or_none(step1.get("old_system")) != 67:
            errors.append(f"chain step 1 old_system={step1.get('old_system')}, expected 67 (Bracelet)")
        if _int_or_none(step1.get("new_system")) != 68:
            errors.append(f"chain step 1 new_system={step1.get('new_system')}, expected 68 (Bi-Bracelet)")
    step1_tic = _int_or_none(step1.get("tic")) if step1 else None
    if step2 is None:
        errors.append("missing chain step 2 (Bi-Bracelet -> Tri-Bracelet, recipe 205)")
    else:
        if _int_or_none(step2.get("accepted")) != 1:
            errors.append(f"chain step 2 was not accepted: {step2}")
        if _int_or_none(step2.get("recipe")) != 205:
            errors.append(f"chain step 2 used recipe {step2.get('recipe')}, expected 205")
        if _int_or_none(step2.get("old_system")) != 68:
            errors.append(f"chain step 2 old_system={step2.get('old_system')}, expected 68 (Bi-Bracelet)")
        if _int_or_none(step2.get("new_system")) != 69:
            errors.append(f"chain step 2 new_system={step2.get('new_system')}, expected 69 (Tri-Bracelet)")
        if weapon_index is not None and _int_or_none(step2.get("weapon_index")) != weapon_index:
            errors.append(f"chain step 2 weapon_index {step2.get('weapon_index')} != step 1's {weapon_index} (slot identity must be preserved)")
    step2_tic = _int_or_none(step2.get("tic")) if step2 else None

    hits_by_system: dict[int, list[int]] = {}
    for row in result["hit_rows"]:
        system_id = _int_or_none(row.get("system_id"))
        tic = _int_or_none(row.get("tic"))
        hits_by_system.setdefault(system_id, []).append(tic)
    for system_id, label in ((67, "Bracelet"), (68, "Bi-Bracelet"), (69, "Tri-Bracelet")):
        if not hits_by_system.get(system_id):
            errors.append(f"no accepted hit ever attributed to system {system_id} ({label})")

    # "Old attacks are not retained": once a step's evolve tic has passed,
    # no hit may still be attributed to the system it replaced.
    if step1_tic is not None:
        stale = [t for t in hits_by_system.get(67, []) if t is not None and t > step1_tic]
        if stale:
            errors.append(f"Bracelet (67) fired after its own evolve tic {step1_tic}: {stale}")
    if step2_tic is not None:
        stale = [t for t in hits_by_system.get(68, []) if t is not None and t > step2_tic]
        if stale:
            errors.append(f"Bi-Bracelet (68) fired after its own evolve tic {step2_tic}: {stale}")

    report = {
        "status": "PASS" if not errors else "FAIL",
        "check": "p042_bracelet_chain_204_205",
        "errors": errors,
        "evidence": result.get("evidence"),
        "p042_complete": result.get("p042_complete"),
        "chain_step_rows": steps,
        "hits_by_system": hits_by_system,
    }
    if result.get("evidence"):
        report["report_path"] = _write_verdict(result["evidence"], "chain", report)
    return report


# unionIndex -> (label, input_a_system, input_b_system_or_None). Bloody
# Tear (input B of the Fuwalafuwaloo union) has no P042 firing system of its
# own, so it never appears in DS_P042_HIT/DS_P042_GUN_SPAWN system_id.
UNION_SPECS = {
    0: ("VANDALIER", 59, 60),
    1: ("PHIERAGGI", 62, 63),
    2: ("FUWALAFUWALOO", 65, None),
}
DS_UNION_TICS_PER_CASE = 9
DS_UNION_CASE_COUNT = 12


def validate_union_matrix(package: Path, seconds: float = 45) -> dict:
    """A01: each of the three unions completing in both acquisition orders,
    at a full 6-weapon inventory and with an extra stage slot -- 12 cases
    (docs/contracts/paired-unions.md "Required actual-UZDoom evidence").
    Checks per case: exact identities (item_id -> rank, not raw index, since
    the P032 list compacts), exactly one weapon slot freed, output at the
    lower input index, passives unchanged, both acquisition orders producing
    an identical post-state, the reuse-equip succeeding, and no parent-owned
    emission (of any kind other than an already in-flight GUN) after the
    union tic."""
    result = run_mode(package, "union_matrix", seconds=seconds)
    errors: list[str] = []

    setups = {int(r["case_index"]): r for r in result["case_setup_rows"]}
    unions = {int(r["case_index"]): r for r in result["union_rows"]}
    reuses = {int(r["case_index"]): r for r in result["reuse_rows"]}
    fire_checks_by_case: dict[int, list[dict]] = {}
    for r in result["fire_check_rows"]:
        fire_checks_by_case.setdefault(int(r["case_index"]), []).append(r)
    snapshots_by_case_label: dict[tuple[int, str], list[dict]] = {}
    for r in result["snapshot_rows"]:
        snapshots_by_case_label.setdefault((int(r["case_index"]), r["label"]), []).append(r)
    summaries_by_case_label: dict[tuple[int, str], dict] = {}
    for r in result["snapshot_summary_rows"]:
        summaries_by_case_label[(int(r["case_index"]), r["label"])] = r

    if len(setups) != DS_UNION_CASE_COUNT:
        errors.append(f"expected {DS_UNION_CASE_COUNT} DS_P042_MAP28_CASE_SETUP rows, found {len(setups)}")
    if len(unions) != DS_UNION_CASE_COUNT:
        errors.append(f"expected {DS_UNION_CASE_COUNT} DS_P042_MAP28_UNION rows, found {len(unions)}")

    def item_map(case_index: int, label: str) -> dict[int, int]:
        rows = snapshots_by_case_label.get((case_index, label), [])
        m: dict[int, int] = {}
        for row in rows:
            m[_int_or_none(row.get("item_id"))] = _int_or_none(row.get("rank"))
        return m

    for case_index in range(DS_UNION_CASE_COUNT):
        union_index = case_index // 4
        variant = case_index % 4
        order_ab = variant % 2 == 0
        extra = variant >= 2
        label, sys_a, sys_b = UNION_SPECS[union_index]

        union_row = unions.get(case_index)
        setup_row = setups.get(case_index)
        reuse_row = reuses.get(case_index)
        if union_row is None or setup_row is None or reuse_row is None:
            errors.append(f"case {case_index} ({label}): missing setup/union/reuse marker")
            continue

        if _int_or_none(union_row.get("accepted")) != 1:
            errors.append(f"case {case_index} ({label}): union recipe was rejected: {union_row}")
            continue
        if _int_or_none(union_row.get("evolved")) != 1:
            errors.append(f"case {case_index} ({label}): union did not evolve a surviving weapon: {union_row}")

        # Output at the lower input index (contract slot transaction).
        idx_a = _int_or_none(union_row.get("idx_a"))
        idx_b = _int_or_none(union_row.get("idx_b"))
        expected_insert_at = _int_or_none(union_row.get("expected_insert_at"))
        output_index_after = _int_or_none(union_row.get("output_index_after"))
        if expected_insert_at != min(idx_a, idx_b):
            errors.append(f"case {case_index} ({label}): expected_insert_at {expected_insert_at} != min(idx_a,idx_b) {min(idx_a, idx_b)}")
        if output_index_after != expected_insert_at:
            errors.append(f"case {case_index} ({label}): output landed at index {output_index_after}, expected the lower input index {expected_insert_at}")

        # Exactly one weapon slot freed: identities (item_id set), not raw
        # index, since DSP032RemoveIndex compacts the list.
        before_items = item_map(case_index, "BEFORE")
        after_items = item_map(case_index, "AFTER")
        before_summary = summaries_by_case_label.get((case_index, "BEFORE"))
        after_summary = summaries_by_case_label.get((case_index, "AFTER"))
        if before_summary is None or after_summary is None:
            errors.append(f"case {case_index} ({label}): missing BEFORE/AFTER snapshot summary")
        else:
            weapon_before = _int_or_none(before_summary.get("weapon_count"))
            weapon_after = _int_or_none(after_summary.get("weapon_count"))
            if weapon_after != weapon_before - 1:
                errors.append(f"case {case_index} ({label}): weapon occupancy went {weapon_before} -> {weapon_after}, expected exactly one slot freed (-1)")
        # Identity check: inputs removed, output present, every filler
        # untouched (rank unchanged), passive (if any) untouched.
        for item_id, rank in before_items.items():
            if item_id in (sys_a, sys_b if sys_b is not None else -1):
                continue
            if item_id in after_items and after_items[item_id] != rank:
                errors.append(f"case {case_index} ({label}): non-input item {item_id} rank changed {rank} -> {after_items.get(item_id)}")
        if sys_a in after_items:
            errors.append(f"case {case_index} ({label}): input A ({sys_a}) still present after union")
        if sys_b is not None and sys_b in after_items:
            errors.append(f"case {case_index} ({label}): input B ({sys_b}) still present after union")
        output_system = {"VANDALIER": 61, "PHIERAGGI": 64, "FUWALAFUWALOO": 66}[label]
        if output_system not in after_items:
            errors.append(f"case {case_index} ({label}): output {output_system} not present after union")

        # Passives unchanged.
        passive_id = _int_or_none(union_row.get("passive_id"))
        if passive_id:
            passive_before = _int_or_none(union_row.get("passive_rank_before"))
            passive_after = _int_or_none(union_row.get("passive_rank_after"))
            if passive_before != passive_after or passive_before is None or passive_before < 1:
                errors.append(f"case {case_index} ({label}): passive {passive_id} rank changed or missing ({passive_before} -> {passive_after})")

        # Reuse of the freed capacity.
        if _int_or_none(reuse_row.get("can_acquire")) != 1 or _int_or_none(reuse_row.get("acquired")) != 1:
            errors.append(f"case {case_index} ({label}): freed slot was not reusable: {reuse_row}")

        # Fire checks: the cancelled weapon must never fire; the output
        # system and the reused slot must each fire at least once (cooldown
        # legitimately blocks some of the per-tic attempts).
        checks = fire_checks_by_case.get(case_index, [])
        for c in checks:
            if c.get("label") == "CANCELLED_WEAPON_MUST_NOT_FIRE" and _int_or_none(c.get("fired")) != 0:
                errors.append(f"case {case_index} ({label}): cancelled weapon fired: {c}")
        if not any(c.get("label") == "OUTPUT_SYSTEM_VOLLEY" and _int_or_none(c.get("fired")) == 1 for c in checks):
            errors.append(f"case {case_index} ({label}): output system never fired after the union")
        if not any(c.get("label") == "REUSED_SLOT_VOLLEY" and _int_or_none(c.get("fired")) == 1 for c in checks):
            errors.append(f"case {case_index} ({label}): reused slot never fired")

        # A03: no parent-owned emission after the union tic. An already
        # in-flight GUN (spawned before the union, kind=GUN) may keep
        # resolving under the old system/owner; nothing else may.
        union_tic = _int_or_none(union_row.get("tic"))
        case_start = case_index * DS_UNION_TICS_PER_CASE
        case_end = case_start + DS_UNION_TICS_PER_CASE
        old_systems = {s for s in (sys_a, sys_b) if s is not None}
        for hit in result["hit_rows"]:
            tic = _int_or_none(hit.get("tic"))
            if tic is None or tic < case_start or tic >= case_end:
                continue
            system_id = _int_or_none(hit.get("system_id"))
            if system_id in old_systems and tic > union_tic and hit.get("kind") != "GUN":
                errors.append(f"case {case_index} ({label}): non-GUN hit from old system {system_id} at tic {tic} > union tic {union_tic}: {hit}")
        for spawn in result["gun_spawn_rows"]:
            tic = _int_or_none(spawn.get("tic"))
            if tic is None or tic < case_start or tic >= case_end:
                continue
            system_id = _int_or_none(spawn.get("system_id"))
            if system_id in old_systems and tic > union_tic:
                errors.append(f"case {case_index} ({label}): new GUN_SPAWN from old system {system_id} at tic {tic} > union tic {union_tic}: {spawn}")
        if not any(_int_or_none(h.get("tic")) is not None and case_start <= _int_or_none(h.get("tic")) < case_end
                   and _int_or_none(h.get("tic")) > union_tic and _int_or_none(h.get("system_id")) == output_system
                   for h in result["hit_rows"]):
            errors.append(f"case {case_index} ({label}): no hit from the output system {output_system} after the union tic")

    # Both acquisition orders must produce an identical post-state (item_id
    # -> rank), for each (union, config) pair.
    for union_index in range(3):
        for extra_flag, variants in ((0, (0, 1)), (1, (2, 3))):
            case_ab = union_index * 4 + variants[0]
            case_ba = union_index * 4 + variants[1]
            items_ab = item_map(case_ab, "AFTER")
            items_ba = item_map(case_ba, "AFTER")
            if items_ab != items_ba:
                errors.append(f"union {UNION_SPECS[union_index][0]} config={'EXTRA' if extra_flag else 'FULL'}: AB post-state {items_ab} != BA post-state {items_ba}")
            hash_ab = _int_or_none(unions.get(case_ab, {}).get("hash_after"))
            hash_ba = _int_or_none(unions.get(case_ba, {}).get("hash_after"))
            if hash_ab != hash_ba:
                errors.append(f"union {UNION_SPECS[union_index][0]} config={'EXTRA' if extra_flag else 'FULL'}: AB hash_after {hash_ab} != BA hash_after {hash_ba}")

    report = {
        "status": "PASS" if not errors else "FAIL",
        "check": "p042_union_matrix_a01_a03",
        "errors": errors,
        "evidence": result.get("evidence"),
        "p042_complete": result.get("p042_complete"),
        "case_count": len(setups),
    }
    if result.get("evidence"):
        report["report_path"] = _write_verdict(result["evidence"], "union_matrix", report)
    return report


DS_NEG_TICS_PER_CASE = 3
DS_NEG_CASE_COUNT = 4


def validate_union_negative(package: Path, seconds: float = 25) -> dict:
    """Negative cases: a non-max input, a missing required passive
    (Tirajisu), a non-evolution chest context, and a duplicate union attempt
    after a real success -- each must be rejected with the inventory hash
    byte-identical before and after the rejected attempt."""
    result = run_mode(package, "union_negative", seconds=seconds)
    errors: list[str] = []
    rows = result["neg_case_rows"]

    expected_reasons = {
        "NON_MAX_INPUT": 0,
        "MISSING_REQUIRED_PASSIVE": 0,
        "NON_EVOLUTION_CHEST": 0,
        "FIRST_SUCCESS_THEN_DUPLICATE": 1,
        "DUPLICATE_AFTER_SUCCESS": 0,
    }
    if len(rows) != len(expected_reasons):
        errors.append(f"expected {len(expected_reasons)} DS_P042_MAP28_NEG_CASE rows, found {len(rows)}")

    by_reason = {r.get("reason"): r for r in rows}
    for reason, expected_accepted in expected_reasons.items():
        row = by_reason.get(reason)
        if row is None:
            errors.append(f"missing negative case: {reason}")
            continue
        accepted = _int_or_none(row.get("accepted"))
        if accepted != expected_accepted:
            errors.append(f"{reason}: accepted={accepted}, expected {expected_accepted}")
        if expected_accepted == 0:
            if _int_or_none(row.get("hash_unchanged")) != 1:
                errors.append(f"{reason}: inventory hash changed on a rejected attempt: {row}")
            if _int_or_none(row.get("hash_before")) != _int_or_none(row.get("hash_after")):
                errors.append(f"{reason}: hash_before != hash_after: {row}")

    # Sanity: the first-success case must have actually mutated the
    # inventory (proves the duplicate case's "unchanged" check is
    # meaningful, not vacuous).
    success_row = by_reason.get("FIRST_SUCCESS_THEN_DUPLICATE")
    if success_row is not None and _int_or_none(success_row.get("hash_unchanged")) == 1:
        errors.append("FIRST_SUCCESS_THEN_DUPLICATE: hash did not change on a real accepted union")

    report = {
        "status": "PASS" if not errors else "FAIL",
        "check": "p042_union_negative_rejections",
        "errors": errors,
        "evidence": result.get("evidence"),
        "p042_complete": result.get("p042_complete"),
        "neg_case_rows": rows,
    }
    if result.get("evidence"):
        report["report_path"] = _write_verdict(result["evidence"], "union_negative", report)
    return report


ATTR_MIGHT_MILLI = 2000
ATTR_RANKS = {59: 8, 60: 8, 61: 8, 62: 8, 63: 8, 64: 1, 65: 8, 66: 1, 67: 6, 68: 6, 69: 6}
ARC_KINDS = {"VENTO_ARC", "FUWALA_ARC"}


def validate_attribution(package: Path, seconds: float = 70) -> dict:
    """A02: all eleven systems firing concurrently, each hit carrying its
    owner weapon handle/form generation/system; with a controlled 2000-milli
    Might fixture, damage equals row damage x Might for every Might-eligible
    system (all eleven, per P033); Fuwalafuwaloo's movement-streak bonus is
    added AFTER Might scaling and is never itself multiplied by Might
    ('does not increase by Might', verbatim); and a mid-run Vandalier union
    switches attribution to the output system for new emissions only."""
    expected = _expected_rows_from_json()
    result = run_mode(package, "attribution", seconds=seconds)
    errors: list[str] = []

    union_rows = result["attr_union_rows"]
    if len(union_rows) != 1:
        errors.append(f"expected exactly 1 DS_P042_MAP28_ATTR_UNION row, found {len(union_rows)}")
    union_row = union_rows[0] if union_rows else None
    union_tic = _int_or_none(union_row.get("tic")) if union_row else None
    if union_row is not None and (_int_or_none(union_row.get("accepted")) != 1
                                   or _int_or_none(union_row.get("evolved")) != 1):
        errors.append(f"mid-run Vandalier union was not accepted/evolved: {union_row}")

    all_hit_rows = result["hit_rows"]
    if not all_hit_rows:
        errors.append("no DS_P042_HIT rows observed at all")

    seen_systems: set[int] = set()
    for row in all_hit_rows:
        system_id = _int_or_none(row.get("system_id"))
        kind = row.get("kind")
        if system_id is None or system_id not in ATTR_RANKS:
            errors.append(f"hit with unexpected/missing system_id: {row}")
            continue
        seen_systems.add(system_id)
        weapon_id = _int_or_none(row.get("weapon_id"))
        form_generation = _int_or_none(row.get("form_generation"))
        damage = _int_or_none(row.get("damage"))
        if not weapon_id:
            errors.append(f"hit missing owner weapon_id: {row}")
        if form_generation is None or form_generation < 1:
            errors.append(f"hit missing/invalid form_generation: {row}")

        rank = ATTR_RANKS[system_id]
        want = expected.get((system_id, rank))
        if want is None or damage is None:
            continue
        might = ATTR_MIGHT_MILLI
        if kind in ARC_KINDS:
            critical = _int_or_none(row.get("critical")) == 1
            streak_bonus_milli = _int_or_none(row.get("streak_bonus_milli")) or 0
            effective_damage_milli = want["damage_milli"]
            if critical:
                effective_damage_milli = want["damage_milli"] * want["crit_multiplier_milli"] // 1000
            amount_base = effective_damage_milli * might // 1000 // 1000
            expected_total = amount_base + streak_bonus_milli // 1000
            if damage != expected_total:
                errors.append(f"{kind} system={system_id} tic={row.get('tic')}: damage {damage} != expected {expected_total} (Might-scaled base {amount_base} + raw streak {streak_bonus_milli // 1000})")
            if system_id == 66 and streak_bonus_milli > 0 and might != 1000:
                wrong_total = (effective_damage_milli * might // 1000 // 1000) + (streak_bonus_milli * might // 1000 // 1000)
                if damage == wrong_total and expected_total != wrong_total:
                    errors.append(f"Fuwalafuwaloo hit tic={row.get('tic')}: streak bonus appears Might-scaled (matches the wrong formula {wrong_total})")
        else:
            expected_amount = want["damage_milli"] * might // 1000 // 1000
            if damage != expected_amount:
                errors.append(f"{kind} system={system_id} tic={row.get('tic')}: damage {damage} != expected {expected_amount} (row damage x Might)")

    for system_id in ATTR_RANKS:
        if system_id not in seen_systems:
            errors.append(f"system {system_id} never produced a single DS_P042_HIT (not proven concurrently firing)")

    if union_tic is not None:
        for row in all_hit_rows:
            system_id = _int_or_none(row.get("system_id"))
            tic = _int_or_none(row.get("tic"))
            if system_id in (59, 60) and tic is not None and tic > union_tic:
                errors.append(f"old parent system {system_id} produced a hit at tic {tic} > union tic {union_tic}")
        if not any(_int_or_none(r.get("system_id")) == 61 and _int_or_none(r.get("tic")) is not None
                   and _int_or_none(r.get("tic")) > union_tic for r in all_hit_rows):
            errors.append(f"no Vandalier (61) hit observed after the union tic {union_tic}")

    report = {
        "status": "PASS" if not errors else "FAIL",
        "check": "p042_attribution_a02",
        "errors": errors,
        "evidence": result.get("evidence"),
        "p042_complete": result.get("p042_complete"),
        "union_row": union_row,
        "systems_observed": sorted(seen_systems),
    }
    if result.get("evidence"):
        report["report_path"] = _write_verdict(result["evidence"], "attribution", report)
    return report


PATTERNS_YAWS = (0, 90, 180)
PHIERAGGI_STEP_DEG = 15
# Phiera/Eight rank 8's amount is 3 (data/verified/base/weapons/paired/
# phiera.json and eight.json rank_rows), not 4 -- a volley's ordinal loop
# only ever reaches ordinal%4 in {0,1,2}, so the 4th fixed/facing diagonal
# (ordinal%4==3) is never actually fired by this fixture. Expected sets
# below are built from the real reachable ordinals, not the full 4-diagonal
# geometry table.
PATTERNS_GUN_AMOUNT = 3


def _expected_fixed_angle_set(amount: int) -> set[int]:
    fixed_degs = [45, 135, 225, 315]
    return {fixed_degs[o % 4] for o in range(amount)}


def _expected_facing_angle_set(yaw: int, amount: int) -> set[int]:
    result: set[int] = set()
    for o in range(amount):
        m = o % 4
        if m == 0:
            result.add((yaw + 45) % 360)
        elif m == 1:
            result.add((yaw - 45 + 360) % 360)
        elif m == 2:
            result.add((yaw + 135) % 360)
        else:
            result.add((yaw - 135 + 360) % 360)
    return result


def validate_patterns(package: Path, seconds: float = 40) -> dict:
    """FP01: mirrored bird rotation (Peachone clockwise / Ebony Wings
    counterclockwise), Phiera's body-facing-relative diagonals versus
    Eight's fixed source-plane diagonals under body yaw 0/90/180, and
    Phieraggi's 15 deg/volley advance."""
    errors: list[str] = []
    runs = {yaw: run_mode(package, "patterns", seconds=seconds, body_yaw=yaw) for yaw in PATTERNS_YAWS}

    def _wrapped_delta(a: int, b: int) -> int:
        d = (b - a) % 360
        return d if d <= 180 else d - 360

    eight_angle_sets: dict[int, set] = {}
    phiera_angle_sets: dict[int, set] = {}
    for yaw, result in runs.items():
        if result.get("p042_complete") is None:
            errors.append(f"yaw={yaw}: missing completion marker")
        gun_rows = result["gun_spawn_rows"]
        eight_angles = {_int_or_none(r.get("angle_deg")) for r in gun_rows if _int_or_none(r.get("system_id")) == 63}
        phiera_angles = {_int_or_none(r.get("angle_deg")) for r in gun_rows if _int_or_none(r.get("system_id")) == 62}
        eight_angle_sets[yaw] = eight_angles
        phiera_angle_sets[yaw] = phiera_angles
        if not eight_angles:
            errors.append(f"yaw={yaw}: Eight never spawned a shot")
        if not phiera_angles:
            errors.append(f"yaw={yaw}: Phiera never spawned a shot")

        expected_phiera = _expected_facing_angle_set(yaw, PATTERNS_GUN_AMOUNT)
        if phiera_angles and phiera_angles != expected_phiera:
            errors.append(f"yaw={yaw}: Phiera angle set {phiera_angles} != expected facing-relative {expected_phiera}")

        peachone_angles = [_int_or_none(r.get("angle_deg")) for r in result["hit_rows"]
                            if _int_or_none(r.get("system_id")) == 59 and r.get("kind") == "BIRD"]
        ebony_angles = [_int_or_none(r.get("angle_deg")) for r in result["hit_rows"]
                        if _int_or_none(r.get("system_id")) == 60 and r.get("kind") == "BIRD"]
        if len(peachone_angles) < 2:
            errors.append(f"yaw={yaw}: fewer than 2 Peachone BIRD hits observed, cannot prove rotation")
        if len(ebony_angles) < 2:
            errors.append(f"yaw={yaw}: fewer than 2 Ebony Wings BIRD hits observed, cannot prove rotation")
        bad_cw = [(a, b) for a, b in zip(peachone_angles, peachone_angles[1:]) if _wrapped_delta(a, b) < 0]
        if bad_cw:
            errors.append(f"yaw={yaw}: Peachone angle sequence is not clockwise (nondecreasing): {bad_cw}")
        bad_ccw = [(a, b) for a, b in zip(ebony_angles, ebony_angles[1:]) if _wrapped_delta(a, b) > 0]
        if bad_ccw:
            errors.append(f"yaw={yaw}: Ebony Wings angle sequence is not counterclockwise (nonincreasing): {bad_ccw}")

        volleys = result["phieraggi_volley_rows"]
        if len(volleys) < 2:
            errors.append(f"yaw={yaw}: fewer than 2 DS_P042_PHIERAGGI_VOLLEY rows, cannot prove the 15 deg advance")
        else:
            starts = [_int_or_none(v.get("start_deg")) for v in volleys]
            for a, b in zip(starts, starts[1:]):
                delta = (b - a) % 360
                if delta != PHIERAGGI_STEP_DEG:
                    errors.append(f"yaw={yaw}: Phieraggi start_deg advanced by {delta}, expected {PHIERAGGI_STEP_DEG}: {a} -> {b}")

    baseline_set = eight_angle_sets.get(0)
    if baseline_set and any(eight_angle_sets.get(yaw) != baseline_set for yaw in PATTERNS_YAWS[1:]):
        errors.append(f"Eight angle sets diverged across body yaw (must be body-yaw invariant): {eight_angle_sets}")
    expected_eight = _expected_fixed_angle_set(PATTERNS_GUN_AMOUNT)
    if baseline_set and baseline_set != expected_eight:
        errors.append(f"Eight angle set {baseline_set} != expected fixed diagonals {expected_eight}")

    report = {
        "status": "PASS" if not errors else "FAIL",
        "check": "p042_patterns_fp01",
        "errors": errors,
        "eight_angle_sets": {k: sorted(v) for k, v in eight_angle_sets.items()},
        "phiera_angle_sets": {k: sorted(v) for k, v in phiera_angle_sets.items()},
        "runs": {yaw: {"evidence": r.get("evidence"), "p042_complete": r.get("p042_complete")} for yaw, r in runs.items()},
    }
    baseline_evidence = runs[0].get("evidence")
    if baseline_evidence:
        report["report_path"] = _write_verdict(baseline_evidence, "patterns", report)
    return report


def patterns_camera_window_invariance(package: Path, seconds: float = 40) -> dict:
    """Camera/window invariance for the FP01 pattern scenario (mirrors
    tools/run_p041_bounce.py's camera_window_invariance approach): body yaw
    held fixed at 0 while actual engine window-size variants (1280x720,
    800x600, 1600x900) and camera pitch/FOV variants change -- the full
    DS_P042_HIT/DS_P042_GUN_SPAWN/DS_P042_PHIERAGGI_VOLLEY tuple sequences
    must stay byte-identical to the baseline. Writes
    p042-camera-window-invariance.json."""
    plan = [
        (1280, 720, 0),   # baseline: pitch 0, FOV 90
        (800, 600, 0),    # window-size variant, same camera
        (1600, 900, 0),   # window-size + aspect-ratio variant, same camera
        (1280, 720, 1),   # camera pitch 22, baseline window
        (1280, 720, 2),   # camera wide FOV 120, baseline window
        (1280, 720, 3),   # camera narrow FOV 60, baseline window
        (1600, 900, 1),   # window + pitch combined
        (800, 600, 3),    # window + narrow FOV combined
    ]
    runs = [run_mode(package, "patterns", seconds=seconds, body_yaw=0, camera_variant=camera,
                      window_width=w, window_height=h)
            for w, h, camera in plan]
    errors: list[str] = []
    baseline = runs[0]

    def tuple_seq(r: dict):
        hits = [dict(row) for row in r.get("hit_rows", [])]
        spawns = [dict(row) for row in r.get("gun_spawn_rows", [])]
        volleys = [dict(row) for row in r.get("phieraggi_volley_rows", [])]
        return hits, spawns, volleys

    base_hits, base_spawns, base_volleys = tuple_seq(baseline)
    if baseline.get("p042_complete") is None:
        errors.append("baseline (1280x720, camera=0): missing completion marker")
    per_run = []
    for (w, h, camera), result in zip(plan, runs):
        label = f"{w}x{h} camera={camera}"
        ok = True
        if result.get("p042_complete") is None:
            errors.append(f"{label}: missing completion marker"); ok = False
        hits, spawns, volleys = tuple_seq(result)
        if hits != base_hits:
            errors.append(f"{label}: DS_P042_HIT tuple sequence diverged from baseline"); ok = False
        if spawns != base_spawns:
            errors.append(f"{label}: DS_P042_GUN_SPAWN tuple sequence diverged from baseline"); ok = False
        if volleys != base_volleys:
            errors.append(f"{label}: DS_P042_PHIERAGGI_VOLLEY tuple sequence diverged from baseline"); ok = False
        per_run.append({"window_width": w, "window_height": h, "camera_variant": camera,
                         "evidence": result.get("evidence"), "p042_complete": result.get("p042_complete"),
                         "matched_baseline": ok})
    report = {
        "status": "PASS" if not errors else "FAIL",
        "check": "p042_camera_window_invariance",
        "errors": errors,
        "plan": [{"window_width": w, "window_height": h, "camera_variant": c} for w, h, c in plan],
        "runs": per_run,
    }
    baseline_evidence = baseline.get("evidence")
    if baseline_evidence:
        out_path = Path(baseline_evidence) / "p042-camera-window-invariance.json"
        out_path.write_text(json.dumps(report, indent=2, default=str) + "\n", encoding="utf-8")
        report["report_path"] = str(out_path)
    return report


def validate_burst_union(package: Path, seconds: float = 25) -> dict:
    """A union triggered while a parent (Phiera/Eight) is mid-burst --
    ordinals 1/2 of its rank-8 3-shot volley still pending -- must cancel
    every not-yet-emitted child forever (never DS_P042_GUN_SPAWN'd) while
    the already-emitted ordinal-0 shot resolves under the parent owner; a
    simultaneous, unrelated Bracelet rank upgrade must apply exactly once;
    the inventory hash must show one real, consistent state change."""
    result = run_mode(package, "burst_union", seconds=seconds)
    errors: list[str] = []

    union_rows = result["burst_union_rows"]
    if len(union_rows) != 1:
        errors.append(f"expected exactly 1 DS_P042_MAP28_BURST_UNION row, found {len(union_rows)}")
    union_row = union_rows[0] if union_rows else None
    union_tic = _int_or_none(union_row.get("tic")) if union_row else None
    if union_row is not None and (_int_or_none(union_row.get("accepted")) != 1
                                   or _int_or_none(union_row.get("evolved")) != 1):
        errors.append(f"burst mid-run Phieraggi union was not accepted/evolved: {union_row}")

    upgrade_rows = result["burst_upgrade_rows"]
    if len(upgrade_rows) != 1:
        errors.append(f"expected exactly 1 DS_P042_MAP28_BURST_UPGRADE row (applied exactly once), found {len(upgrade_rows)}")
    elif _int_or_none(upgrade_rows[0].get("evolved")) != 1:
        errors.append(f"unrelated Bracelet upgrade was not accepted: {upgrade_rows[0]}")

    gun_spawns = [r for r in result["gun_spawn_rows"] if _int_or_none(r.get("system_id")) in (62, 63)]
    if len(gun_spawns) != 2:
        errors.append(f"expected exactly 2 DS_P042_GUN_SPAWN rows from the parents (ordinal 0 only, one each), found {len(gun_spawns)}: {gun_spawns}")

    cancelled = result["gun_pending_cancelled_rows"]
    if len(cancelled) != 4:
        errors.append(f"expected exactly 4 DS_P042_GUN_PENDING_CANCELLED rows (2 parents x 2 pending ordinals), found {len(cancelled)}: {cancelled}")
    scheduled = result["gun_pending_schedule_rows"]
    if len(scheduled) != 4:
        errors.append(f"expected exactly 4 DS_P042_GUN_PENDING_SCHEDULE rows, found {len(scheduled)}")

    if union_tic is not None:
        late_spawns = [r for r in gun_spawns if _int_or_none(r.get("tic")) is not None and _int_or_none(r.get("tic")) > union_tic]
        if late_spawns:
            errors.append(f"a parent GUN_SPAWN occurred after the union tic {union_tic} (should have been cancelled as pending): {late_spawns}")
        if not any(_int_or_none(r.get("system_id")) == 64 and _int_or_none(r.get("tic")) is not None
                   and _int_or_none(r.get("tic")) > union_tic for r in result["hit_rows"]):
            errors.append(f"no Phieraggi (64) hit observed after the union tic {union_tic}")

    hash_before = _int_or_none(union_row.get("hash_before")) if union_row else None
    hash_after_upgrade = _int_or_none(upgrade_rows[0].get("hash_after")) if upgrade_rows else None
    if hash_before is not None and hash_after_upgrade is not None and hash_before == hash_after_upgrade:
        errors.append(f"inventory hash unchanged across the union+upgrade transaction ({hash_before}) -- expected a real state change")

    report = {
        "status": "PASS" if not errors else "FAIL",
        "check": "p042_burst_union",
        "errors": errors,
        "evidence": result.get("evidence"),
        "p042_complete": result.get("p042_complete"),
        "union_row": union_row,
        "upgrade_rows": upgrade_rows,
        "gun_spawn_count": len(gun_spawns),
        "cancelled_count": len(cancelled),
    }
    if result.get("evidence"):
        report["report_path"] = _write_verdict(result["evidence"], "burst_union", report)
    return report


def _float_or_none(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def validate_vento_streak(package: Path, seconds: float = 40) -> dict:
    """N1/P042 item a: Vento Sacro's +1/35-tic (cap +5) and Fuwalafuwaloo's
    +8/35-tic (cap +40, not Might-scaled) movement-streak bonus, replayed
    independently from the DS_P042_MAP28_STREAK_TICK position trace using
    the exact DSP042TickMoveStreak algorithm (continuous-movement growth,
    reset to zero on a stopped tic), then compared hit-by-hit against every
    DS_P042_HIT (VENTO_ARC/FUWALA_ARC) row's own streak_bonus_milli and
    total damage."""
    expected = _expected_rows_from_json()
    result = run_mode(package, "vento_streak", seconds=seconds)
    errors: list[str] = []

    ticks = sorted(result["streak_tick_rows"], key=lambda r: _int_or_none(r.get("tic")) or 0)
    if not ticks:
        errors.append("no DS_P042_MAP28_STREAK_TICK rows observed")

    # Independent replay of DSP042TickMoveStreak (PairedTargeting.zs): moved
    # requires the ledger to have been seeded by a prior tick AND the
    # (x*1000,y*1000) truncated position to differ; otherwise the streak
    # resets to zero.
    streak_by_tic: dict[int, int] = {}
    seeded = False
    last_x1000 = 0
    last_y1000 = 0
    streak_tics = 0
    for row in ticks:
        tic = _int_or_none(row.get("tic"))
        x = _float_or_none(row.get("x"))
        y = _float_or_none(row.get("y"))
        if tic is None or x is None or y is None:
            continue
        cur_x1000 = int(x * 1000.0)
        cur_y1000 = int(y * 1000.0)
        moved = seeded and (cur_x1000 != last_x1000 or cur_y1000 != last_y1000)
        last_x1000, last_y1000 = cur_x1000, cur_y1000
        seeded = True
        streak_tics = streak_tics + 1 if moved else 0
        streak_by_tic[tic] = streak_tics

    def expected_bonus_milli(system_id: int, tic: int) -> int | None:
        row = expected.get((system_id, 8 if system_id == 65 else 1))
        if row is None or tic not in streak_by_tic:
            return None
        step = row["movement_streak_step_milli"]
        cap = row["movement_streak_cap_milli"]
        if step <= 0:
            return 0
        steps = streak_by_tic[tic] // 35
        return min(cap, steps * step)

    # Growth-then-reset-then-regrowth sanity on the replayed ledger itself.
    move1_end, stop_end, move2_end = 220, 260, 480
    at_220 = streak_by_tic.get(move1_end)
    at_stop = [streak_by_tic.get(t) for t in range(stop_end - 5, stop_end + 1) if t in streak_by_tic]
    at_480 = streak_by_tic.get(move2_end)
    if at_220 is None or at_220 < 35:
        errors.append(f"replayed streak at tic {move1_end} is {at_220}, expected sustained growth (>=35 continuous tics)")
    if at_stop and any(v != 0 for v in at_stop):
        errors.append(f"replayed streak did not reset to 0 during the stop window: {at_stop}")
    if at_480 is None or at_480 < 35:
        errors.append(f"replayed streak at tic {move2_end} is {at_480}, expected regrowth after the stop (>=35 continuous tics)")

    hits_checked = 0
    for row in result["hit_rows"]:
        kind = row.get("kind")
        if kind not in ("VENTO_ARC", "FUWALA_ARC"):
            continue
        system_id = _int_or_none(row.get("system_id"))
        tic = _int_or_none(row.get("tic"))
        damage = _int_or_none(row.get("damage"))
        streak_bonus_milli = _int_or_none(row.get("streak_bonus_milli"))
        critical = _int_or_none(row.get("critical")) == 1
        if system_id not in (65, 66) or tic is None:
            errors.append(f"unexpected streak-mode hit row: {row}")
            continue
        want_bonus = expected_bonus_milli(system_id, tic)
        if want_bonus is None:
            errors.append(f"tic {tic} system {system_id}: no replayed streak state to compare against (trace gap)")
            continue
        if streak_bonus_milli != want_bonus:
            errors.append(f"tic {tic} system {system_id}: streak_bonus_milli {streak_bonus_milli} != replayed expectation {want_bonus}")
        rank = 8 if system_id == 65 else 1
        row_json = expected[(system_id, rank)]
        effective_damage_milli = row_json["damage_milli"]
        if critical:
            effective_damage_milli = row_json["damage_milli"] * row_json["crit_multiplier_milli"] // 1000
        want_damage = effective_damage_milli // 1000 + (want_bonus or 0) // 1000
        if damage != want_damage:
            errors.append(f"tic {tic} system {system_id}: damage {damage} != recomputed expectation {want_damage} (base {effective_damage_milli}, streak {want_bonus}, critical={critical})")
        hits_checked += 1

    if hits_checked == 0:
        errors.append("no VENTO_ARC/FUWALA_ARC hits observed to recompute against the movement trace")
    # Cap must actually be reached at least once for each system (proves the
    # +5/+40 cap, not merely partial growth).
    for system_id, cap_field_rank in ((65, 8), (66, 1)):
        row_json = expected[(system_id, cap_field_rank)]
        cap = row_json["movement_streak_cap_milli"]
        seen_cap = any(_int_or_none(r.get("streak_bonus_milli")) == cap
                       for r in result["hit_rows"]
                       if r.get("kind") in ("VENTO_ARC", "FUWALA_ARC") and _int_or_none(r.get("system_id")) == system_id)
        if not seen_cap:
            errors.append(f"system {system_id}: streak bonus never reached its cap {cap} in any observed hit")

    report = {
        "status": "PASS" if not errors else "FAIL",
        "check": "p042_vento_streak_movement_bonus",
        "errors": errors,
        "evidence": result.get("evidence"),
        "p042_complete": result.get("p042_complete"),
        "hits_checked": hits_checked,
        "streak_at_move1_end": at_220,
        "streak_at_stop_window": at_stop,
        "streak_at_move2_end": at_480,
    }
    if result.get("evidence"):
        report["report_path"] = _write_verdict(result["evidence"], "vento_streak", report)
    return report


def validate_fuwala_heal(package: Path, seconds: float = 60) -> dict:
    """N1/P042 item b: Fuwalafuwaloo crit healing through the P039 authority
    -- 8,000 milli per accepted crit, gated to at most once per 18 tics,
    never on a non-crit, capped at max health -- plus an isolated >=10,000
    trial crit-rate audit of the real production DSP042RollCritOnState
    formula at 5% chance, +/-0.7 percentage points, proving the live
    P042_CRIT gameplay stream is untouched by the audit."""
    result = run_mode(package, "fuwala_heal", seconds=seconds)
    errors: list[str] = []

    volleys = {r.get("label"): r for r in result["heal_volley_rows"]}
    forced_a = volleys.get("FORCED_A")
    forced_b = volleys.get("FORCED_B")
    forced_c = volleys.get("FORCED_C_CAP")
    if forced_a is None or _int_or_none(forced_a.get("healed_milli")) != 8000:
        errors.append(f"FORCED_A: expected healed_milli=8000, got {forced_a}")
    if forced_b is None or _int_or_none(forced_b.get("healed_milli")) != 8000:
        errors.append(f"FORCED_B: expected a second gated-open 8000-milli heal 70 tics later, got {forced_b}")
    cap_setup = result["heal_cap_setup_rows"]
    cap_health_before = _int_or_none(cap_setup[0].get("health_before")) if cap_setup else None
    max_health = _int_or_none(cap_setup[0].get("max_health")) if cap_setup else None
    expected_capped = (max_health - cap_health_before) if (max_health is not None and cap_health_before is not None) else None
    if forced_c is None:
        errors.append("missing FORCED_C_CAP heal volley")
    else:
        healed_c = _int_or_none(forced_c.get("healed_milli"))
        health_after_c = _int_or_none(forced_c.get("health_after"))
        if expected_capped is not None and healed_c != expected_capped:
            errors.append(f"FORCED_C_CAP: healed_milli {healed_c} != expected capped amount {expected_capped} (max-before room)")
        if max_health is not None and health_after_c != max_health:
            errors.append(f"FORCED_C_CAP: health_after {health_after_c} != max_health {max_health} (must cap exactly at max)")

    # Non-crit gate: for every NORMAL volley, a nonzero heal may only occur
    # in a tic that actually produced at least one critical FUWALA_ARC hit;
    # a zero heal is required whenever no critical hit occurred that tic.
    crit_tics = {_int_or_none(r.get("tic")) for r in result["hit_rows"]
                 if r.get("kind") == "FUWALA_ARC" and _int_or_none(r.get("critical")) == 1}
    normal_volleys = [v for label, v in volleys.items() if label == "NORMAL" or (label and label.startswith("NORMAL"))]
    # heal_volley_rows collapses same-label rows into a dict above; re-derive
    # the full ordered list directly since NORMAL appears up to 8 times.
    normal_rows = [r for r in result["heal_volley_rows"] if r.get("label") == "NORMAL"]
    if len(normal_rows) != 8:
        errors.append(f"expected exactly 8 NORMAL heal-volley rows, found {len(normal_rows)}")
    for row in normal_rows:
        tic = _int_or_none(row.get("tic"))
        healed = _int_or_none(row.get("healed_milli"))
        if healed and healed > 0 and tic not in crit_tics:
            errors.append(f"NORMAL volley at tic {tic} healed {healed} milli with no critical FUWALA_ARC hit observed that tic (non-crit healed)")
        if healed is not None and healed > 0 and healed != 8000:
            # Below the cap setup point, room is always >> 8000.
            errors.append(f"NORMAL volley at tic {tic}: healed {healed} != 8000 (uncapped region)")

    # Isolated crit-rate audit: >=10,000 trials at the real 5% (50 milli)
    # production chance, +/-0.7pp, and the live gameplay P042_CRIT stream
    # provably unchanged by the audit.
    audits = result["crit_rng_audit_rows"]
    if not audits:
        errors.append("missing DS_P042_CRIT_RNG_AUDIT row")
    else:
        audit = audits[0]
        trials = _int_or_none(audit.get("trials"))
        chance_milli = _int_or_none(audit.get("chance_milli"))
        observed_rate_milli = _int_or_none(audit.get("observed_rate_milli"))
        if trials is None or trials < 10000:
            errors.append(f"crit audit trials {trials} < required 10000")
        if chance_milli != 50:
            errors.append(f"crit audit chance_milli {chance_milli} != production 5% (50 milli)")
        if observed_rate_milli is None or abs(observed_rate_milli - chance_milli) > 7:
            errors.append(f"crit audit observed_rate_milli {observed_rate_milli} deviates from {chance_milli} by more than 0.7pp (7 milli)")
        if audit.get("production_function") != "DSP042RollCritOnState":
            errors.append(f"crit audit did not use the production roll function: {audit}")
    live = result["crit_rng_live_unchanged_rows"]
    if not live or _int_or_none(live[0].get("equal")) != 1:
        errors.append(f"live P042_CRIT gameplay stream was not proven unchanged by the audit: {live}")

    report = {
        "status": "PASS" if not errors else "FAIL",
        "check": "p042_fuwala_heal_authority_and_crit_audit",
        "errors": errors,
        "evidence": result.get("evidence"),
        "p042_complete": result.get("p042_complete"),
        "forced_a": forced_a, "forced_b": forced_b, "forced_c": forced_c,
        "normal_volleys": normal_rows,
        "audit": audits[0] if audits else None,
        "live_unchanged": live[0] if live else None,
    }
    if result.get("evidence"):
        report["report_path"] = _write_verdict(result["evidence"], "fuwala_heal", report)
    return report


def validate_pause(package: Path, seconds: float = 30) -> dict:
    """N1/P042 item c: real native menu pause (the P041/MAP27 UiTick/
    InterfaceProcess/NetworkProcess bridge), hash identical across the
    pause, firing resumes afterwards."""
    result = run_mode(package, "pause", seconds=seconds)
    errors: list[str] = []
    starts = result["pause_start_rows"]
    helds = result["pause_held_rows"]
    ends = result["pause_end_rows"]
    if not starts:
        errors.append("missing DS_P042_MAP28_PAUSE_START (native pause was never requested)")
    if not helds:
        errors.append("missing DS_P042_MAP28_PAUSE_HELD (Level.WorldPaused() never observed true)")
    if not ends:
        errors.append("missing DS_P042_MAP28_PAUSE_END (native pause never resumed)")
    end_tic = None
    if ends:
        accepted = _int_or_none(ends[0].get("accepted"))
        if accepted != 1:
            errors.append(f"pause end reported accepted={accepted}, expected 1 (hash identical before/after)")
        start_hash = _int_or_none(ends[0].get("start_hash"))
        end_hash = _int_or_none(ends[0].get("end_hash"))
        if start_hash != end_hash:
            errors.append(f"persistence hash changed across pause: {start_hash} != {end_hash}")
        end_tic = _int_or_none(ends[0].get("world_logical_tic"))
    # Firing resumes: the fixture fires the Bracelet at logical tic 1 and 60
    # (RunPauseTic); the pause opens at ui_tic>=5, so a hit attributed to
    # system 67 (Bracelet) at tic 60 (after the pause) proves resumption.
    later_hits = [h for h in result["hit_rows"]
                  if _int_or_none(h.get("system_id")) == 67
                  and end_tic is not None and _int_or_none(h.get("tic")) is not None
                  and _int_or_none(h.get("tic")) >= 60]
    if end_tic is not None and not later_hits:
        errors.append(f"no Bracelet hit observed at/after tic 60 (pause resumed at tic {end_tic}) -- firing did not resume")
    report = {
        "status": "PASS" if not errors else "FAIL",
        "check": "p042_native_pause_hash_stable_firing_resumes",
        "errors": errors,
        "evidence": result.get("evidence"),
        "p042_complete": result.get("p042_complete"),
        "pause_start_rows": starts,
        "pause_held_rows": helds,
        "pause_end_rows": ends,
        "later_hit_count": len(later_hits),
    }
    if result.get("evidence"):
        report["report_path"] = _write_verdict(result["evidence"], "pause", report)
    return report


def _validate_save_roundtrip_logs(save_log: str, restore_log: str) -> dict[str, object]:
    """N1/P042 item d: freeze right after a union with >=1 emitted
    parent-owned gun child in flight and Phieraggi's own next-volley
    schedule pending; save, load in a new process; exact
    DSP042PersistenceHash and P032 inventory-hash equality; after load the
    in-flight child resolves with the parent owner and the output fires."""
    errors: list[str] = []
    frozen = SAVE_FROZEN_RE.search(save_log)
    if frozen is None:
        errors.append("save leg never froze right after the union with an in-flight child (missing DS_P042_MAP28_SAVE_FROZEN)")
        return {"ok": False, "errors": errors}
    frozen_tic = int(frozen.group(1)); frozen_hash = int(frozen.group(2))
    frozen_inv_hash = int(frozen.group(3)); frozen_surviving = int(frozen.group(4))

    restored = RESTORE_RE.search(restore_log)
    if restored is None:
        errors.append("restore leg never emitted its first-tick continuation marker (DS_P042_MAP28_RESTORE)")
        return {"ok": False, "errors": errors, "frozen_tic": frozen_tic, "frozen_hash": frozen_hash}
    restored_tic = int(restored.group(1)); restored_hash = int(restored.group(2))
    restored_inv_hash = int(restored.group(3)); mid_flight = int(restored.group(4))
    exact_hash = int(restored.group(5)); exact_inventory_hash = int(restored.group(6))
    restored_surviving = int(restored.group(7))

    if restored_tic != frozen_tic:
        errors.append(f"restored tic {restored_tic} != frozen tic {frozen_tic}")
    if restored_hash != frozen_hash or exact_hash != 1:
        errors.append(f"DSP042PersistenceHash not exactly equal: frozen {frozen_hash} vs restored {restored_hash} (exact_hash={exact_hash})")
    if restored_inv_hash != frozen_inv_hash or exact_inventory_hash != 1:
        errors.append(f"P032 inventory hash not exactly equal: frozen {frozen_inv_hash} vs restored {restored_inv_hash} (exact_inventory_hash={exact_inventory_hash})")
    if mid_flight != 1:
        errors.append("no Phiera/Eight gun child was still mid-flight immediately after load")
    if restored_surviving != frozen_surviving or restored_surviving < 0:
        errors.append(f"surviving (Phieraggi) weapon index changed or invalid across the roundtrip: frozen {frozen_surviving} vs restored {restored_surviving}")

    # The output (Phieraggi, system 64) must resolve/fire again after
    # restore, using the SAME parent owner id the in-flight child was
    # spawned under (attribution survives the roundtrip).
    restore_hits = _rows(restore_log, HIT_RE)
    output_hits_after = [h for h in restore_hits if _int_or_none(h.get("system_id")) == 64
                          and _int_or_none(h.get("tic")) is not None and _int_or_none(h.get("tic")) >= restored_tic]
    if not output_hits_after:
        errors.append("no Phieraggi (64) hit observed after restore -- the output did not fire")
    gun_hits_after = [h for h in restore_hits if h.get("kind") == "GUN"]
    if not gun_hits_after:
        errors.append("the mid-flight parent-owned gun child never resolved a hit after restore")

    return {
        "ok": not errors, "errors": errors,
        "frozen_tic": frozen_tic, "frozen_hash": frozen_hash, "frozen_inventory_hash": frozen_inv_hash,
        "restored_tic": restored_tic, "restored_hash": restored_hash, "restored_inventory_hash": restored_inv_hash,
        "mid_flight_after_load": mid_flight == 1,
        "surviving_weapon_index": restored_surviving,
        "output_hits_after_restore": output_hits_after,
        "gun_hits_after_restore": gun_hits_after,
    }


def run_save_roundtrip(package: Path, wait_tics: int = 20, restore_wait_tics: int = 175,
                        timeout: float = 90.0) -> dict[str, object]:
    """N1/P042 item d: native save/load with a union completed and a
    parent-owned Phiera/Eight gun child still mid-flight, modeled directly
    on tools/run_p041_bounce.py's run_save_roundtrip (a `+exec`'d console
    script drives `save`/`-loadgame` directly rather than going through
    tools.run_probe.run's own polling loop)."""
    build(ROOT, "none", ROOT / "maps/source/p042-paired/room.json")
    package = package.resolve()
    package_sha = hashlib.sha256(package.read_bytes()).hexdigest()
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    name = f"{stamp}-p042-map28-save-load"
    evidence = ROOT / "evidence/P042" / name
    evidence.mkdir(parents=True)
    profile = ROOT / ".local/probes" / name
    profile.mkdir(parents=True)
    save_capture = evidence / "save-captures"
    restore_capture = evidence / "restore-captures"
    save_capture.mkdir()
    restore_capture.mkdir()
    save_name = "ds_p042_map28"
    save_script = profile / "save.cfg"
    restore_script = profile / "restore.cfg"
    save_script.write_text(
        f'wait {wait_tics}; screenshot; save {save_name} "P042 union mid-flight state"; wait 8; quit\n',
        encoding="utf-8", newline="\n")
    restore_script.write_text(
        f"wait {restore_wait_tics}; screenshot; wait 20; quit\n",
        encoding="utf-8", newline="\n")
    (profile / "config.ini").write_text(config_text(save_capture, vsync=False),
                                        encoding="utf-8", newline="\n")
    lock = json.loads((ROOT / "toolchain/lock.json").read_text(encoding="utf-8"))
    executable = ROOT / lock["uzdoom"]["executable"]["path"]
    save_args = ["+enablescriptscreenshot", "true",
                 "+set", "ds_p042_mode", "save",
                 "+set", "ds_p042_save_snapshot_request", "1",
                 "+map", "MAP28", "+exec", save_script.name]
    save_rc = run_engine(executable, package, profile, "p042-map28-save.log",
                         save_args, timeout=timeout)
    save_log = read_log(profile, "p042-map28-save.log")
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
                        "+set", "ds_p042_mode", "save",
                        "+set", "ds_p042_save_snapshot_request", "0",
                        "+exec", restore_script.name]
        restore_rc = run_engine(executable, package, profile,
                                "p042-map28-restore.log", restore_args,
                                timeout=timeout)
        restore_log = read_log(profile, "p042-map28-restore.log")

    (evidence / "save-engine.log").write_text(save_log, encoding="utf-8", newline="\n")
    (evidence / "restore-engine.log").write_text(restore_log, encoding="utf-8", newline="\n")
    shutil.copy2(save_script, evidence / save_script.name)
    shutil.copy2(restore_script, evidence / restore_script.name)
    validation = _validate_save_roundtrip_logs(save_log, restore_log)
    errors = list(validation["errors"])
    if save_file is None or save_file.stat().st_size <= 0:
        errors.append("UZDoom did not create a nonempty serialized MAP28 save")
    if save_file is not None:
        shutil.copy2(save_file, evidence / save_file.name)
    report = {
        "status": "PASS" if not errors else "FAIL",
        "classification": "P042_MAP28_SERIALIZED_UNION_MID_FLIGHT_CONTINUATION",
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


VALIDATORS = {
    "boot": validate_boot,
    "chain": validate_chain,
    "union_matrix": validate_union_matrix,
    "union_negative": validate_union_negative,
    "attribution": validate_attribution,
    "patterns": validate_patterns,
    "camera_window_invariance": patterns_camera_window_invariance,
    "burst_union": validate_burst_union,
    "vento_streak": validate_vento_streak,
    "fuwala_heal": validate_fuwala_heal,
    "pause": validate_pause,
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--modes", default=",".join(ALL_MODES))
    parser.add_argument("--validate", default="",
                         help="comma-separated validators to run instead of --modes: boot,chain")
    parser.add_argument("--seconds", type=float, default=25)
    parser.add_argument("--save-roundtrip", action="store_true")
    parser.add_argument("--out", type=Path, default=ROOT / "build" / "evidence" / "P042" / "verdict.json")
    args = parser.parse_args()

    build(ROOT, "none", ROOT / "maps/source/p042-paired/room.json")
    package = ROOT / "build" / "doom-survivors.ipk3"

    results: dict[str, object] = {}
    if args.save_roundtrip:
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
