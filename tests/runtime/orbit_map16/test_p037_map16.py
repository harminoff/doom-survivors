"""Strict MAP16 P037 evidence validators and fail-closed fixtures."""
from __future__ import annotations

import re
import unittest
from collections import defaultdict


def _rows(log: str, marker: str) -> list[dict[str, str]]:
    parsed: list[dict[str, str]] = []
    for line in log.splitlines():
        if not line.startswith(marker + " "):
            continue
        parsed.append(dict(re.findall(r"([A-Za-z_][A-Za-z0-9_]*)=([^\s]+)", line)))
    return parsed


def validate_p037_map16_runtime(log: str, runtime_status: str,
                                captures: list[dict[str, object]] | None = None
                                ) -> dict[str, object]:
    """Validate real MAP16 rows, evolution, P025 hits, credits and coexistence.

    TIMEOUT is accepted only as explicitly bounded stream evidence when actual
    state/hit markers are present and completion was not emitted. It never
    upgrades such evidence to a full-run pass.
    """
    errors: list[str] = []
    boot = _rows(log, "DS_P030_BOOT")
    route = _rows(log, "DS_P037_MAP16_BOOT")
    fixtures = _rows(log, "DS_P037_MAP16_FIXTURE")
    transforms = _rows(log, "DS_P037_MAP16_TRANSFORM")
    if len(boot) != 1 or boot[0].get("map") != "MAP16" or boot[0].get("mode") != "p037":
        errors.append("the process did not boot the opt-in P037 route on MAP16")
    if len(route) != 1 or route[0].get("route") != "OPT_IN_P037":
        errors.append("P037 MAP16 boot marker is missing or duplicated")
    if len(fixtures) != 1 or fixtures[0].get("accepted") != "1":
        errors.append("controlled King Bible fixture was not accepted exactly once")
    if len(transforms) != 1:
        errors.append("the controlled King Bible to Vespers transition was not unique")
    transform_tic = -1
    if len(transforms) == 1:
        row = transforms[0]
        try:
            transform_tic = int(row["tic"])
            if (row.get("accepted") != "1" or row.get("source_system_id") != "44"
                    or row.get("source_rank") != "8"
                    or row.get("evolved_system_id") != "45"
                    or row.get("output_rank") != "1"
                    or row.get("source_inventory_claim") != "0"):
                errors.append("the fixture transformation did not match the controlled 44 rank-8 to 45 rank-1 recipe")
        except (KeyError, ValueError):
            errors.append("the transformation marker omitted its source/output ranks or tic")

    hits = _rows(log, "DS_P037_HIT")
    accepted_hits = [row for row in hits if row.get("accepted") == "1"]
    event_ids: set[str] = set()
    per_tic: dict[int, int] = defaultdict(int)
    by_form: dict[int, int] = defaultdict(int)
    for row in accepted_hits:
        try:
            event_id = row["event_id"]
            tic = int(row["tic"])
            system_id = int(row["system_id"])
            before = int(row["before"])
            after = int(row["after"])
            requested = int(row["damage_milli"])
            delta = int(row["accepted_delta_milli"])
            if event_id in event_ids:
                errors.append(f"duplicate accepted P037 hit event id {event_id}")
            event_ids.add(event_id)
            if row.get("authority") != "P025_CHECKED_LOGICAL_HIT":
                errors.append(f"event {event_id} bypassed the checked P025 logical-hit authority")
            if system_id not in (44, 45):
                errors.append(f"event {event_id} used an unscoped P037 system {system_id}")
            if system_id == 44 and transform_tic >= 0 and tic >= transform_tic:
                errors.append(f"old King Bible hit {event_id} survived the form replacement")
            if system_id == 45 and transform_tic >= 0 and tic < transform_tic:
                errors.append(f"Vespers hit {event_id} predates the accepted transformation")
            # P025 clamps a hit to the target's remaining health. The runtime
            # records both the requested amount and the accepted before/after
            # delta, so lethal hits may legitimately accept less than requested.
            if delta <= 0 or before - after != delta or delta > requested:
                errors.append(f"event {event_id} has inconsistent before/after damage")
            per_tic[tic] += delta
            by_form[system_id] += 1
        except (KeyError, ValueError):
            errors.append("an accepted orbit hit omitted its checked-damage join fields")
    if by_form[44] < 1:
        errors.append("no accepted pre-transformation King Bible hit was observed")
    if by_form[45] < 1:
        errors.append("no accepted post-transformation Vespers hit was observed")

    credits = _rows(log, "DS_P037_MAP16_DAMAGE_CREDIT")
    credited_per_tic: dict[int, int] = defaultdict(int)
    for row in credits:
        try:
            if row.get("authority") != "DSP037_P025_CHECKED_LOGICAL_HITS":
                errors.append("P037 damage credit names a noncanonical authority")
            credited_per_tic[int(row["tic"])] += int(row["accepted_delta_milli"])
        except (KeyError, ValueError):
            errors.append("a P037 damage-credit row is malformed")
    if dict(credited_per_tic) != dict(per_tic):
        errors.append("per-tic P037 accepted hit damage does not reconcile to credited damage")

    # The opt-in MAP16 path composes every already playable automatic family.
    coexistence_markers = {
        "P032/Bloody Tear": _rows(log, "DS_P032_BLOODY_TEAR_HIT"),
        "P034 aimed": [r for r in _rows(log, "DS_P034_HIT") if r.get("accepted") == "1"],
        "P035 ballistic": [r for r in _rows(log, "DS_P035_HIT") if r.get("accepted") == "1"],
        "P036 returning": [r for r in _rows(log, "DS_P036_HIT") if r.get("accepted") == "1"],
    }
    for family, rows in coexistence_markers.items():
        if not rows:
            errors.append(f"concurrent playable schedule has no accepted {family} hit")

    complete = _rows(log, "DS_P030_COMPLETE")
    if runtime_status == "RUNTIME_PASS":
        if len(complete) != 1 or int(complete[0].get("tics", "0")) != 2100:
            errors.append("full-run status lacks the accepted 2100-tic completion marker")
    elif runtime_status == "TIMEOUT":
        if complete:
            errors.append("runner reported TIMEOUT after an apparent full completion")
        if not accepted_hits:
            errors.append("bounded stream timeout contains no accepted P037 hits")
    else:
        errors.append(f"unsupported or unsuccessful runtime status {runtime_status}")
    capture_rows = captures or []
    if capture_rows and not any(bool(row.get("nonblank")) for row in capture_rows):
        errors.append("runtime capture is blank")
    status = "PASS" if not errors and runtime_status == "RUNTIME_PASS" else (
        "PASS_BOUNDED_STREAM" if not errors and runtime_status == "TIMEOUT" else "FAIL")
    return {
        "status": status,
        "runtime_status": runtime_status,
        "accepted_hits": len(accepted_hits),
        "hits_by_system": {str(key): by_form[key] for key in sorted(by_form)},
        "accepted_damage_milli": sum(per_tic.values()),
        "credited_damage_milli": sum(credited_per_tic.values()),
        "coexistence_hit_counts": {key: len(value) for key, value in coexistence_markers.items()},
        "errors": errors,
    }


def validate_p037_map16_save_roundtrip(save_log: str, restore_log: str,
                                       save_exit_code: int | None,
                                       restore_exit_code: int | None
                                       ) -> dict[str, object]:
    """Validate P037's serialized orbit window/phase/ledger and real continuation."""
    errors: list[str] = []
    if save_exit_code != 0:
        errors.append(f"save session exited {save_exit_code}, expected clean quit (0)")
    if restore_exit_code != 0:
        errors.append(f"restore session exited {restore_exit_code}, expected clean quit (0)")
    # A loaded UZDoom save resumes serialized handlers without replaying the
    # fresh-run P030/P037 boot markers. The accepted restore-state and joined
    # hit below are the stronger route proof for that process.
    if "DS_P030_BOOT map=MAP16" not in save_log:
        errors.append("save process did not boot MAP16")
    if "DS_P037_MAP16_BOOT" not in save_log:
        errors.append("save process did not opt into P037")
    saved_rows = _rows(save_log, "DS_P037_MAP16_SAVE_STATE")
    restored_rows = _rows(restore_log, "DS_P037_MAP16_RESTORE_STATE")
    if len(saved_rows) != 1 or len(restored_rows) != 1:
        errors.append("save/restore did not emit exactly one accepted orbit-state marker each")
    saved = saved_rows[0] if len(saved_rows) == 1 else {}
    restored = restored_rows[0] if len(restored_rows) == 1 else {}
    keys = (
        "system_id", "rank", "weapon_id", "weapon_generation", "form_generation",
        "source_rank_hash", "resolved_rank_hash", "p031_hash", "p032_hash",
        "spinach_rank", "armor_rank", "hollow_heart_rank", "empty_tome_rank",
        "might_milli", "cooldown_multiplier_milli", "active_members",
        "active_cohorts", "ledger_entries", "cohort_id", "cohort_generation",
        "member", "member_generation", "phase_micro_rad", "phase_remainder",
        "window_start_tic", "window_end_tic", "last_phase_tic", "logical_tic",
        "run_state",
    )
    if saved:
        if (saved.get("accepted") != "1" or saved.get("source") != "POST_TRANSFORM"
                or saved.get("system_id") != "45" or saved.get("rank") != "1"
                or saved.get("run_state") != "ACTIVE"):
            errors.append("save snapshot is not an active post-transformation Vespers state")
        try:
            if int(saved["logical_tic"]) < 350 or int(saved["active_members"]) < 1:
                errors.append("save snapshot predates the transformation or has no live orbit members")
            if int(saved["active_cohorts"]) < 1:
                errors.append("save snapshot has no live cohort")
        except (KeyError, ValueError):
            errors.append("save snapshot omitted the active member/cohort checkpoint")
    if restored:
        if (restored.get("accepted") != "1" or restored.get("source") != "POST_TRANSFORM"
                or restored.get("system_id") != "45" or restored.get("rank") != "1"
                or restored.get("run_state") != "ACTIVE"):
            errors.append("restore did not accept an active post-transformation Vespers state")
    if saved and restored:
        for field in keys:
            if field not in saved or field not in restored or saved[field] != restored[field]:
                errors.append(f"serialized orbit/stat field {field} changed across save/load")
        coordinate_fields = ("rebased_from_x_milli", "rebased_from_y_milli",
                             "player_x_milli", "player_y_milli")
        try:
            dx = int(restored["player_x_milli"]) - int(restored["rebased_from_x_milli"])
            dy = int(restored["player_y_milli"]) - int(restored["rebased_from_y_milli"])
            for field, delta in (("anchor_x_milli", dx), ("member_x_milli", dx),
                                 ("anchor_y_milli", dy), ("member_y_milli", dy)):
                if int(restored[field]) != int(saved[field]) + delta:
                    errors.append(f"world-space orbit field {field} did not follow the load rebase")
            # The composite hash includes world coordinates; it is comparable
            # only when the restore performed no spatial translation.
            if dx == 0 and dy == 0 and saved.get("orbit_hash") != restored.get("orbit_hash"):
                errors.append("orbit state hash changed across a zero-delta save/load")
            if dx != 0 or dy != 0:
                if saved.get("orbit_hash") == restored.get("orbit_hash"):
                    errors.append("translated orbit coordinates did not alter the world-space hash")
        except (KeyError, ValueError):
            errors.append("restore omitted its rebase and representative orbit geometry fields")

    restore_hits = _rows(restore_log, "DS_P037_MAP16_RESTORE_ATTACK")
    accepted_restore_hits = [row for row in restore_hits if row.get("accepted") == "1"]
    p037_hits = {row.get("event_id"): row for row in _rows(restore_log, "DS_P037_HIT")
                 if row.get("accepted") == "1"}
    if len(accepted_restore_hits) != 1:
        errors.append("restore session lacks exactly one joined automatic orbit hit")
    else:
        row = accepted_restore_hits[0]
        hit = p037_hits.get(row.get("event_id"))
        if (row.get("joined_marker") != "DS_P037_HIT" or hit is None
                or hit.get("system_id") != "45" or row.get("system_id") != "45"
                or row.get("tic") != (hit or {}).get("tic")
                or row.get("weapon_id") != (hit or {}).get("weapon_id")
                or row.get("weapon_generation") != (hit or {}).get("weapon_generation")):
            errors.append("restore attack marker does not join the real accepted P025 Vespers hit")
    return {
        "status": "PASS" if not errors else "FAIL",
        "saved": saved or None,
        "restored": restored or None,
        "restore_attack_hits": len(accepted_restore_hits),
        "errors": errors,
    }


def validate_p037_map16_pause(log: str) -> dict[str, object]:
    errors: list[str] = []
    rows = _rows(log, "DS_P037_MAP16_PAUSE")
    opened = [row for row in rows if row.get("open") == "1"]
    closed = [row for row in rows if row.get("open") == "0"]
    if not opened or not closed:
        errors.append("actual native pause open and resume markers were not both observed")
    if opened and closed:
        first, last = opened[0], closed[-1]
        if first.get("world_tic") != last.get("world_tic"):
            errors.append("world logical tic advanced while the native pause was held")
        if first.get("orbit_hash") != last.get("orbit_hash"):
            errors.append("orbit state changed while the native pause was held")
        if first.get("source_clock_frozen") != "1" or last.get("source_clock_frozen") != "1":
            errors.append("pause transition did not identify the UZDoom world clock as frozen")
    return {"status": "PASS" if not errors else "FAIL", "samples": len(rows), "errors": errors}


def validate_p037_map16_default(log: str) -> dict[str, object]:
    errors: list[str] = []
    boot = _rows(log, "DS_P030_BOOT")
    if len(boot) != 1 or boot[0].get("map") != "MAP16" or boot[0].get("mode") != "manual":
        errors.append("default regression did not boot the P030 manual path")
    for marker in ("DS_P037_MAP16_BOOT", "DS_P037_MAP16_FIXTURE",
                   "DS_P037_MAP16_TRANSFORM", "DS_P037_HIT",
                   "DS_P037_MAP16_DAMAGE_CREDIT"):
        if _rows(log, marker):
            errors.append(f"default manual route unexpectedly emitted {marker}")
    return {"status": "PASS" if not errors else "FAIL", "errors": errors}


class P037Map16RuntimeValidatorTests(unittest.TestCase):
    def test_bounded_stream_requires_p025_hits_transform_and_exact_credit(self) -> None:
        log = """DS_P030_BOOT map=MAP16 mode=p037
DS_P037_MAP16_BOOT route=OPT_IN_P037
DS_P037_MAP16_FIXTURE accepted=1
DS_P037_MAP16_TRANSFORM accepted=1 tic=350 source_system_id=44 source_rank=8 evolved_system_id=45 output_rank=1 source_inventory_claim=0
DS_P037_HIT accepted=1 authority=P025_CHECKED_LOGICAL_HIT event_id=1 tic=349 system_id=44 damage_milli=15000 before=100000 after=85000 accepted_delta_milli=15000
DS_P037_MAP16_DAMAGE_CREDIT tic=349 accepted_delta_milli=15000 authority=DSP037_P025_CHECKED_LOGICAL_HITS
DS_P037_HIT accepted=1 authority=P025_CHECKED_LOGICAL_HIT event_id=2 tic=351 system_id=45 damage_milli=45000 before=85000 after=40000 accepted_delta_milli=45000
DS_P037_MAP16_DAMAGE_CREDIT tic=351 accepted_delta_milli=45000 authority=DSP037_P025_CHECKED_LOGICAL_HITS
DS_P037_HIT accepted=1 authority=P025_CHECKED_LOGICAL_HIT event_id=3 tic=352 system_id=45 damage_milli=45000 before=1000 after=0 accepted_delta_milli=1000
DS_P037_MAP16_DAMAGE_CREDIT tic=352 accepted_delta_milli=1000 authority=DSP037_P025_CHECKED_LOGICAL_HITS
DS_P032_BLOODY_TEAR_HIT accepted=1
DS_P034_HIT accepted=1 system_id=34
DS_P035_HIT accepted=1 system_id=39
DS_P036_HIT accepted=1 system_id=43
"""
        result = validate_p037_map16_runtime(log, "TIMEOUT")
        self.assertEqual("PASS_BOUNDED_STREAM", result["status"])
        self.assertEqual(61000, result["accepted_damage_milli"])
        self.assertEqual("FAIL", validate_p037_map16_runtime(
            log.replace("accepted_delta_milli=45000", "accepted_delta_milli=44000", 1),
            "TIMEOUT")["status"])
        self.assertEqual("FAIL", validate_p037_map16_runtime(
            log.replace("system_id=45 damage_milli", "system_id=44 damage_milli"),
            "TIMEOUT")["status"])
        self.assertEqual("FAIL", validate_p037_map16_runtime(
            log.replace("event_id=2 tic=351 system_id=45 damage_milli=45000",
                        "event_id=2 tic=351 system_id=45 damage_milli=40000"),
            "TIMEOUT")["status"])

    def test_default_route_excludes_p037_markers(self) -> None:
        log = "DS_P030_BOOT map=MAP16 mode=manual\n"
        self.assertEqual("PASS", validate_p037_map16_default(log)["status"])
        self.assertEqual("FAIL", validate_p037_map16_default(
            log + "DS_P037_MAP16_BOOT route=OPT_IN_P037\n")["status"])

    def test_pause_requires_same_clock_and_orbit_snapshot(self) -> None:
        log = """DS_P037_MAP16_PAUSE open=1 world_tic=800 orbit_hash=123 source_clock_frozen=1
DS_P037_MAP16_PAUSE open=0 world_tic=800 orbit_hash=123 source_clock_frozen=1
"""
        self.assertEqual("PASS", validate_p037_map16_pause(log)["status"])
        self.assertEqual("FAIL", validate_p037_map16_pause(
            log.replace("world_tic=800 orbit_hash=123 source_clock_frozen=1\nDS_P037_MAP16_PAUSE open=0 world_tic=800",
                        "world_tic=800 orbit_hash=123 source_clock_frozen=1\nDS_P037_MAP16_PAUSE open=0 world_tic=801"))["status"])

    def test_save_restore_requires_identical_serialized_orbit_and_real_hit_join(self) -> None:
        fields = {
            "accepted": "1", "source": "POST_TRANSFORM", "system_id": "45",
            "rank": "1", "weapon_id": "12", "weapon_generation": "1",
            "form_generation": "2", "source_rank_hash": "20",
            "resolved_rank_hash": "20", "p031_hash": "31", "p032_hash": "32",
            "spinach_rank": "1", "armor_rank": "2", "hollow_heart_rank": "0",
            "empty_tome_rank": "0", "might_milli": "1500",
            "cooldown_multiplier_milli": "1000", "active_members": "4",
            "active_cohorts": "1", "ledger_entries": "6", "cohort_id": "8",
            "cohort_generation": "3", "member": "2", "member_generation": "3",
            "phase_micro_rad": "1200000", "phase_remainder": "35",
            "window_start_tic": "340", "window_end_tic": "445",
            "last_phase_tic": "350", "logical_tic": "350", "run_state": "ACTIVE",
            "orbit_hash": "99", "anchor_x_milli": "1000", "anchor_y_milli": "2000",
            "member_x_milli": "49000", "member_y_milli": "2000",
        }
        restored = dict(fields, rebased_from_x_milli="0", rebased_from_y_milli="0",
                        player_x_milli="0", player_y_milli="0")
        save_log = (
            "DS_P030_BOOT map=MAP16 mode=p037\nDS_P037_MAP16_BOOT route=OPT_IN_P037\n"
            "DS_P037_MAP16_SAVE_STATE "
            + " ".join(f"{key}={value}" for key, value in fields.items()) + "\n")
        restore_log = (
            "DS_P030_BOOT map=MAP16 mode=p037\nDS_P037_MAP16_BOOT route=OPT_IN_P037\n"
            "DS_P037_MAP16_RESTORE_STATE "
            + " ".join(f"{key}={value}" for key, value in restored.items()) + "\n"
            "DS_P037_MAP16_RESTORE_ATTACK accepted=1 event_id=9 tic=420 system_id=45 "
            "weapon_id=12 weapon_generation=1 joined_marker=DS_P037_HIT\n"
            "DS_P037_HIT accepted=1 event_id=9 tic=420 system_id=45 weapon_id=12 "
            "weapon_generation=1\n")
        self.assertEqual("PASS", validate_p037_map16_save_roundtrip(
            save_log, restore_log, 0, 0)["status"])
        self.assertEqual("FAIL", validate_p037_map16_save_roundtrip(
            save_log, restore_log.replace("phase_micro_rad=1200000",
                                           "phase_micro_rad=1200001", 1), 0, 0)["status"])
        self.assertEqual("FAIL", validate_p037_map16_save_roundtrip(
            save_log, restore_log.replace("event_id=9 tic=420 system_id=45",
                                           "event_id=10 tic=420 system_id=45", 1), 0, 0)["status"])


if __name__ == "__main__":
    unittest.main()
