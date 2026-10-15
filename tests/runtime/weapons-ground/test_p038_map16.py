"""Strict MAP16 P038 run and save/reload validators."""
from __future__ import annotations

import re
import unittest
from collections import defaultdict


def _rows(log: str, marker: str) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for line in log.splitlines():
        if line.startswith(marker + " "):
            rows.append(dict(re.findall(r"([A-Za-z_][A-Za-z0-9_]*)=([^\s]+)", line)))
    return rows


def validate_p038_map16_runtime(
    log: str, runtime_status: str,
    captures: list[dict[str, object]] | None = None,
) -> dict[str, object]:
    """Join MAP16 field hits to their persistent field and P025 damage credit."""
    errors: list[str] = []
    boot = _rows(log, "DS_P030_BOOT")
    route = _rows(log, "DS_P038_MAP16_BOOT")
    fixture = _rows(log, "DS_P038_MAP16_FIXTURE")
    transforms = _rows(log, "DS_P038_MAP16_TRANSFORM")
    if len(boot) != 1 or boot[0].get("map") != "MAP16" or boot[0].get("mode") != "p038":
        errors.append("process did not boot the opt-in P038 MAP16 route")
    if len(route) != 1 or route[0].get("route") != "OPT_IN_P038":
        errors.append("P038 MAP16 route marker is missing or duplicated")
    if len(fixture) != 1:
        errors.append("controlled MAP16 fixture marker is missing or duplicated")
    elif (fixture[0].get("accepted") != "1"
          or fixture[0].get("holywater_rank") != "8"
          or fixture[0].get("attractorb") != "CONTROLLED_INGREDIENT_FIXTURE"
          or fixture[0].get("source_inventory_claim") != "0"):
        errors.append("MAP16 equipment or controlled Attractorb provenance is invalid")

    transform_tic = -1
    if len(transforms) != 1:
        errors.append("Holy Water to La Borra transition is missing or duplicated")
    else:
        row = transforms[0]
        try:
            transform_tic = int(row["tic"])
            if (row.get("accepted") != "1" or row.get("source_system_id") != "46"
                    or row.get("source_rank") != "8"
                    or row.get("evolved_system_id") != "47"
                    or row.get("output_rank") != "1"
                    or row.get("dependency_source") != "CONTROLLED_ATTRACTORB_FIXTURE"
                    or row.get("source_inventory_claim") != "0"
                    or row.get("future_emissions_only") != "1"):
                errors.append("MAP16 transformation does not match the qualified controlled 46/8 to 47/1 route")
            if int(row.get("old_holywater_fields_before", "0")) < 1:
                errors.append("no deposited Holy Water field existed at the transformation boundary")
            if row.get("old_holywater_fields_before") != row.get("old_holywater_fields_after"):
                errors.append("transformation altered the already deposited Holy Water field set")
        except (KeyError, ValueError):
            errors.append("transformation marker omitted tic or retained-field counts")

    fields: dict[tuple[str, str], dict[str, str]] = {}
    for row in _rows(log, "DS_P038_FIELD_CREATE"):
        key = (row.get("field_id", ""), row.get("field_generation", ""))
        if not all(key) or key in fields:
            errors.append("field create has a malformed or duplicate stable field handle")
            continue
        fields[key] = row
    hits_by_tic: dict[int, int] = defaultdict(int)
    form_hits: dict[int, int] = defaultdict(int)
    accepted_events: set[str] = set()
    hits = [row for row in _rows(log, "DS_P038_FIELD_HIT") if row.get("accepted") == "1"]
    for row in hits:
        try:
            event = row["event_id"]
            tic = int(row["tic"])
            system = int(row["source_system"])
            requested = int(row["damage_milli"])
            before = int(row["before"])
            after = int(row["after"])
            delta = int(row["accepted_delta_milli"])
            key = (row["field_id"], row["field_generation"])
            field = fields.get(key)
            if event in accepted_events:
                errors.append(f"duplicate P038 accepted-hit event {event}")
            accepted_events.add(event)
            if row.get("authority") != "P025_CHECKED_LOGICAL_HIT":
                errors.append(f"P038 event {event} bypassed the checked P025 authority")
            if system not in (46, 47):
                errors.append(f"P038 event {event} has out-of-scope system {system}")
            if delta <= 0 or before - after != delta or delta > requested:
                errors.append(f"P038 event {event} has inconsistent accepted damage")
            if field is None:
                errors.append(f"P038 event {event} does not join a created field handle")
            elif (field.get("source_system") != str(system)
                  or field.get("weapon_id") != row.get("weapon_id")
                  or field.get("form_generation") != row.get("form_generation")):
                errors.append(f"P038 event {event} changed field source provenance")
            if system == 46:
                if field is not None and int(field.get("created_tic", "-1")) >= transform_tic:
                    errors.append(f"post-transform Holy Water field {key} was newly created")
            elif transform_tic < 0 or tic < transform_tic:
                errors.append(f"La Borra event {event} predates accepted transformation")
            hits_by_tic[tic] += delta
            form_hits[system] += 1
        except (KeyError, ValueError):
            errors.append("an accepted P038 hit omitted its field, target or checked-damage join")
    if form_hits[46] < 1 or form_hits[47] < 1:
        errors.append("actual accepted hits from both Holy Water and transformed La Borra were not observed")

    emitted = _rows(log, "DS_P038_BOTTLE_EMIT")
    if not any(row.get("system_id") == "46" and int(row.get("tic", "-1")) < transform_tic
               for row in emitted):
        errors.append("pre-transform Holy Water bottle emission was not observed")
    if not any(row.get("system_id") == "47" and int(row.get("tic", "-1")) >= transform_tic
               for row in emitted):
        errors.append("post-transform La Borra bottle emission was not observed")

    credits_by_tic: dict[int, int] = defaultdict(int)
    for row in _rows(log, "DS_P038_MAP16_DAMAGE_CREDIT"):
        try:
            if row.get("authority") != "DSP038_P025_CHECKED_LOGICAL_HITS":
                errors.append("MAP16 P038 result credit names a noncanonical authority")
            credits_by_tic[int(row["tic"])] += int(row["accepted_delta_milli"])
        except (KeyError, ValueError):
            errors.append("malformed MAP16 P038 accepted-damage credit")
    if dict(credits_by_tic) != dict(hits_by_tic):
        errors.append("per-tic P038 P025 accepted damage does not reconcile to MAP16 result credit")

    coexistence = {
        "Bloody Tear": [r for r in _rows(log, "DS_P032_BLOODY_TEAR_HIT")
                        if r.get("accepted", "1") == "1"],
        "aimed weapons": [r for r in _rows(log, "DS_P034_HIT") if r.get("accepted") == "1"],
        "ballistic weapons": [r for r in _rows(log, "DS_P035_HIT") if r.get("accepted") == "1"],
        "returning weapons": [r for r in _rows(log, "DS_P036_HIT") if r.get("accepted") == "1"],
        "orbit weapons": [r for r in _rows(log, "DS_P037_HIT") if r.get("accepted") == "1"],
    }
    for family, rows in coexistence.items():
        if not rows:
            errors.append(f"concurrent MAP16 automatic arsenal has no accepted {family} hit")

    complete = _rows(log, "DS_P030_COMPLETE")
    if runtime_status == "RUNTIME_PASS":
        if len(complete) != 1 or complete[0].get("tics") != "2100":
            errors.append("full-run result does not prove the accepted 2100-tic MAP16 completion")
    elif runtime_status == "TIMEOUT":
        if complete:
            errors.append("runner reports timeout despite a full completion marker")
        if not hits:
            errors.append("bounded P038 stream has no actual accepted field hit")
    else:
        errors.append(f"unsupported P038 runtime status {runtime_status}")
    capture_rows = captures or []
    if capture_rows and not any(bool(row.get("nonblank")) for row in capture_rows):
        errors.append("all captured MAP16 frames are blank")
    status = "PASS" if not errors and runtime_status == "RUNTIME_PASS" else (
        "PASS_BOUNDED_STREAM" if not errors and runtime_status == "TIMEOUT" else "FAIL")
    return {
        "status": status,
        "runtime_status": runtime_status,
        "transform_tic": transform_tic,
        "accepted_hits": len(hits),
        "hits_by_system": {str(key): form_hits[key] for key in sorted(form_hits)},
        "accepted_damage_milli": sum(hits_by_tic.values()),
        "credited_damage_milli": sum(credits_by_tic.values()),
        "coexistence_hit_counts": {key: len(rows) for key, rows in coexistence.items()},
        "errors": errors,
    }


def validate_p038_map16_default(log: str) -> dict[str, object]:
    errors: list[str] = []
    boot = _rows(log, "DS_P030_BOOT")
    if len(boot) != 1 or boot[0].get("map") != "MAP16" or boot[0].get("mode") != "manual":
        errors.append("default regression did not boot the P030 manual route")
    for marker in ("DS_P038_MAP16_BOOT", "DS_P038_MAP16_FIXTURE",
                   "DS_P038_MAP16_TRANSFORM", "DS_P038_VOLLEY",
                   "DS_P038_BOTTLE_EMIT", "DS_P038_FIELD_CREATE",
                   "DS_P038_FIELD_HIT", "DS_P038_MAP16_DAMAGE_CREDIT"):
        if _rows(log, marker):
            errors.append(f"default manual route unexpectedly emitted {marker}")
    return {"status": "PASS" if not errors else "FAIL", "errors": errors}


def validate_p038_map16_save_roundtrip(
    save_log: str, restore_log: str,
    save_exit_code: int | None, restore_exit_code: int | None,
) -> dict[str, object]:
    errors: list[str] = []
    if save_exit_code != 0 or restore_exit_code != 0:
        errors.append("save/restore engine sessions did not both quit cleanly")
    if "DS_P030_BOOT map=MAP16" not in save_log or "DS_P038_MAP16_BOOT" not in save_log:
        errors.append("save process did not boot the opt-in P038 MAP16 path")
    saved_rows = _rows(save_log, "DS_P038_MAP16_SAVE_STATE")
    restored_rows = _rows(restore_log, "DS_P038_MAP16_RESTORE_STATE")
    if len(saved_rows) != 1 or len(restored_rows) != 1:
        errors.append("save/load did not emit exactly one P038 save and restore state marker")
    saved = saved_rows[0] if len(saved_rows) == 1 else {}
    restored = restored_rows[0] if len(restored_rows) == 1 else {}
    if saved and (saved.get("accepted") != "1" or saved.get("source") != "POST_TRANSFORM"
                  or saved.get("system_id") != "47" or saved.get("rank") != "1"
                  or saved.get("form_generation") != "2" or saved.get("run_state") != "ACTIVE"):
        errors.append("snapshot is not an active post-transform La Borra state")
    if restored and (restored.get("accepted") != "1" or restored.get("source") != "POST_TRANSFORM"
                     or restored.get("system_id") != "47" or restored.get("rank") != "1"
                     or restored.get("form_generation") != "2" or restored.get("run_state") != "ACTIVE"):
        errors.append("loaded state did not restore active La Borra equipment")
    invariants = ("weapon_id", "weapon_generation", "form_generation",
                  "source_rank_hash", "resolved_rank_hash", "p031_hash", "p032_hash",
                  "chest_hash", "aimed_hash", "ballistic_hash", "returning_hash",
                  "orbit_hash", "ground_hash", "spinach_rank", "armor_rank",
                  "hollow_heart_rank", "empty_tome_rank", "might_milli",
                  "cooldown_multiplier_milli", "logical_tic", "run_state")
    # Every logical-state hash must match exactly between the save and the
    # restore markers, regardless of any nonzero world-plane rebase delta:
    # the ZScript gate now computes all eight hashes before the P036/P037/
    # P038 rebase calls run, so a rebase can never mask a real mismatch.
    state_hash_keys = ("p031_hash", "p032_hash", "chest_hash", "aimed_hash",
                       "ballistic_hash", "returning_hash", "orbit_hash",
                       "ground_hash")
    if saved and restored:
        for key in invariants:
            if key not in saved or key not in restored or saved[key] != restored[key]:
                errors.append(f"saved P038/P033 state field {key} changed across restore")
        if saved.get("logical_tic") != restored.get("logical_tic"):
            errors.append("P038 logical clock advanced during serialization")
        try:
            int(restored["rebase_x_milli"])
            int(restored["rebase_y_milli"])
        except (KeyError, ValueError):
            errors.append("restore marker omitted the world rebase delta")
        for key in state_hash_keys:
            saved_key = f"saved_{key}"
            if saved_key not in restored:
                errors.append(f"restore marker omitted {saved_key}")
                continue
            if restored.get(key) != restored.get(saved_key):
                errors.append(f"restored {key} does not equal its saved value")
            if saved.get(key) != restored.get(saved_key):
                errors.append(f"restored marker lost the original saved {key}")

    restore_hits = [r for r in _rows(restore_log, "DS_P038_MAP16_RESTORE_HIT")
                    if r.get("accepted") == "1"]
    field_hits = {r.get("event_id"): r for r in _rows(restore_log, "DS_P038_FIELD_HIT")
                  if r.get("accepted") == "1"}
    if len(restore_hits) != 1:
        errors.append("loaded MAP16 run lacks one joined subsequent field hit")
    else:
        row = restore_hits[0]
        hit = field_hits.get(row.get("event_id"))
        if (hit is None or row.get("joined_marker") != "DS_P038_FIELD_HIT"
                or row.get("tic") != hit.get("tic")
                or row.get("system_id") != hit.get("source_system")
                or row.get("field_id") != hit.get("field_id")
                or row.get("field_generation") != hit.get("field_generation")
                or row.get("weapon_id") != hit.get("weapon_id")):
            errors.append("restore continuation does not join the real accepted P025 field hit")
    return {"status": "PASS" if not errors else "FAIL", "saved": saved or None,
            "restored": restored or None, "restore_hits": len(restore_hits), "errors": errors}


class P038Map16ValidatorTests(unittest.TestCase):
    def test_runtime_joins_fields_hits_and_result_credit(self) -> None:
        log = """DS_P030_BOOT map=MAP16 mode=p038
DS_P038_MAP16_BOOT route=OPT_IN_P038
DS_P038_MAP16_FIXTURE accepted=1 holywater_rank=8 attractorb=CONTROLLED_INGREDIENT_FIXTURE source_inventory_claim=0
DS_P038_BOTTLE_EMIT tic=1 system_id=46
DS_P038_FIELD_CREATE tic=5 field_id=1 field_generation=1 source_system=46 weapon_id=50 form_generation=1 created_tic=5
DS_P038_MAP16_TRANSFORM accepted=1 tic=10 source_system_id=46 source_rank=8 evolved_system_id=47 output_rank=1 dependency_source=CONTROLLED_ATTRACTORB_FIXTURE source_inventory_claim=0 future_emissions_only=1 old_holywater_fields_before=1 old_holywater_fields_after=1
DS_P038_FIELD_HIT accepted=1 authority=P025_CHECKED_LOGICAL_HIT event_id=1 tic=11 field_id=1 field_generation=1 source_system=46 form_generation=1 weapon_id=50 damage_milli=1000 before=2000 after=1000 accepted_delta_milli=1000
DS_P038_MAP16_DAMAGE_CREDIT tic=11 accepted_delta_milli=1000 authority=DSP038_P025_CHECKED_LOGICAL_HITS
DS_P038_BOTTLE_EMIT tic=12 system_id=47
DS_P038_FIELD_CREATE tic=16 field_id=2 field_generation=1 source_system=47 weapon_id=50 form_generation=2 created_tic=16
DS_P038_FIELD_HIT accepted=1 authority=P025_CHECKED_LOGICAL_HIT event_id=2 tic=17 field_id=2 field_generation=1 source_system=47 form_generation=2 weapon_id=50 damage_milli=1000 before=1000 after=0 accepted_delta_milli=1000
DS_P038_MAP16_DAMAGE_CREDIT tic=17 accepted_delta_milli=1000 authority=DSP038_P025_CHECKED_LOGICAL_HITS
DS_P032_BLOODY_TEAR_HIT accepted=1
DS_P034_HIT accepted=1
DS_P035_HIT accepted=1
DS_P036_HIT accepted=1
DS_P037_HIT accepted=1
"""
        self.assertEqual("PASS_BOUNDED_STREAM",
                         validate_p038_map16_runtime(log, "TIMEOUT")["status"])
        self.assertEqual("FAIL", validate_p038_map16_runtime(
            log.replace("accepted_delta_milli=1000 authority=DSP038_P025",
                        "accepted_delta_milli=900 authority=DSP038_P025", 1), "TIMEOUT")["status"])
        self.assertEqual("FAIL", validate_p038_map16_runtime(
            log.replace("old_holywater_fields_after=1", "old_holywater_fields_after=0"), "TIMEOUT")["status"])

    def test_default_manual_route_excludes_p038_authority(self) -> None:
        self.assertEqual("PASS", validate_p038_map16_default(
            "DS_P030_BOOT map=MAP16 mode=manual\n")["status"])
        self.assertEqual("FAIL", validate_p038_map16_default(
            "DS_P030_BOOT map=MAP16 mode=manual\nDS_P038_MAP16_BOOT route=OPT_IN_P038\n")["status"])

    def test_save_load_requires_actual_ground_hit_continuation(self) -> None:
        common = ("accepted=1 source=POST_TRANSFORM system_id=47 rank=1 weapon_id=6 "
                  "weapon_generation=1 form_generation=2 source_rank_hash=8 "
                  "resolved_rank_hash=8 spinach_rank=1 armor_rank=0 hollow_heart_rank=0 "
                  "empty_tome_rank=0 might_milli=1200 cooldown_multiplier_milli=1000 "
                  "active_bottles=0 holywater_fields=0 bora_fields=1 ledger_entries=0 "
                  "accepted_hits=0 accepted_damage_milli=0 logical_tic=500 "
                  "player_x_milli=0 player_y_milli=0 run_state=ACTIVE")
        save_state = (f"{common} p031_hash=4 p032_hash=5 chest_hash=6 orbit_hash=7 "
                      "ground_hash=99 aimed_hash=11 ballistic_hash=12 returning_hash=13")
        restore_state = (f"{common} p031_hash=4 saved_p031_hash=4 p032_hash=5 "
                         "saved_p032_hash=5 chest_hash=6 saved_chest_hash=6 aimed_hash=11 "
                         "saved_aimed_hash=11 ballistic_hash=12 saved_ballistic_hash=12 "
                         "returning_hash=13 saved_returning_hash=13 orbit_hash=7 "
                         "saved_orbit_hash=7 ground_hash=99 saved_ground_hash=99 "
                         "rebase_x_milli=0 rebase_y_milli=0")
        save = ("DS_P030_BOOT map=MAP16 mode=p038\nDS_P038_MAP16_BOOT route=OPT_IN_P038\n"
               "DS_P038_MAP16_SAVE_STATE " + save_state + "\n")
        restore = ("DS_P038_MAP16_RESTORE_STATE " + restore_state
                  + "\nDS_P038_FIELD_HIT accepted=1 event_id=12 tic=501 field_id=3 "
                    "field_generation=1 source_system=47 weapon_id=6 form_generation=2"
                  + "\nDS_P038_MAP16_RESTORE_HIT accepted=1 event_id=12 tic=501 "
                    "system_id=47 field_id=3 field_generation=1 weapon_id=6 "
                    "joined_marker=DS_P038_FIELD_HIT\n")
        self.assertEqual("PASS", validate_p038_map16_save_roundtrip(save, restore, 0, 0)["status"])
        broken_restore = restore.replace(
            "DS_P038_MAP16_RESTORE_HIT accepted=1 event_id=12",
            "DS_P038_MAP16_RESTORE_HIT accepted=1 event_id=13")
        self.assertEqual("FAIL", validate_p038_map16_save_roundtrip(
            save, broken_restore, 0, 0)["status"])

    def test_save_load_rejects_any_mismatched_state_hash(self) -> None:
        # Every one of the eight P031/P032/chest/aimed/ballistic/returning/
        # orbit/ground hashes must be individually enforced: a mismatch on
        # any single one, even with everything else identical, must fail.
        common = ("accepted=1 source=POST_TRANSFORM system_id=47 rank=1 weapon_id=6 "
                  "weapon_generation=1 form_generation=2 source_rank_hash=8 "
                  "resolved_rank_hash=8 spinach_rank=1 armor_rank=0 hollow_heart_rank=0 "
                  "empty_tome_rank=0 might_milli=1200 cooldown_multiplier_milli=1000 "
                  "active_bottles=0 holywater_fields=0 bora_fields=1 ledger_entries=0 "
                  "accepted_hits=0 accepted_damage_milli=0 logical_tic=500 "
                  "player_x_milli=0 player_y_milli=0 run_state=ACTIVE")
        save_state = (f"{common} p031_hash=4 p032_hash=5 chest_hash=6 orbit_hash=7 "
                      "ground_hash=99 aimed_hash=11 ballistic_hash=12 returning_hash=13")
        save = ("DS_P030_BOOT map=MAP16 mode=p038\nDS_P038_MAP16_BOOT route=OPT_IN_P038\n"
               "DS_P038_MAP16_SAVE_STATE " + save_state + "\n")
        restore_tail = ("\nDS_P038_FIELD_HIT accepted=1 event_id=12 tic=501 field_id=3 "
                        "field_generation=1 source_system=47 weapon_id=6 form_generation=2"
                        "\nDS_P038_MAP16_RESTORE_HIT accepted=1 event_id=12 tic=501 "
                        "system_id=47 field_id=3 field_generation=1 weapon_id=6 "
                        "joined_marker=DS_P038_FIELD_HIT\n")
        for mismatched_key in ("aimed_hash", "ballistic_hash", "returning_hash",
                               "orbit_hash", "ground_hash", "p031_hash", "p032_hash",
                               "chest_hash"):
            restore_state = (f"{common} p031_hash=4 saved_p031_hash=4 p032_hash=5 "
                             "saved_p032_hash=5 chest_hash=6 saved_chest_hash=6 "
                             "aimed_hash=11 saved_aimed_hash=11 ballistic_hash=12 "
                             "saved_ballistic_hash=12 returning_hash=13 "
                             "saved_returning_hash=13 orbit_hash=7 saved_orbit_hash=7 "
                             "ground_hash=99 saved_ground_hash=99 rebase_x_milli=0 "
                             "rebase_y_milli=0")
            restore_state = restore_state.replace(f"{mismatched_key}=",
                                                   f"{mismatched_key}=666_", 1)
            restore = "DS_P038_MAP16_RESTORE_STATE " + restore_state + restore_tail
            result = validate_p038_map16_save_roundtrip(save, restore, 0, 0)
            self.assertEqual("FAIL", result["status"],
                             f"expected FAIL when {mismatched_key} mismatches")


if __name__ == "__main__":
    unittest.main()
