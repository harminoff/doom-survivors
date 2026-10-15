"""Strict MAP16 validator for the opt-in P036 returning weapon route.

Synthetic logs test the validator only; acceptance requires normal-speed pinned
UZDoom process logs and the final results ledger.
"""
from __future__ import annotations

import re
import unittest
from collections import Counter, defaultdict


def _rows(log: str, marker: str) -> list[dict[str, str]]:
    result: list[dict[str, str]] = []
    pattern = rf"{re.escape(marker)}[ \t]+([^\r\n]*)"
    for match in re.finditer(pattern, log):
        result.append(dict(re.findall(
            r"([A-Za-z_][A-Za-z0-9_]*)=([^\s]+)", match.group(1))))
    return result


def _int(row: dict[str, str], key: str, default: int | None = None) -> int | None:
    try:
        return int(row[key])
    except (KeyError, TypeError, ValueError):
        return default


def _startup_value(commands: list[str] | None, cvar: str) -> str | None:
    if commands is None:
        return None
    for index, token in enumerate(commands[:-1]):
        if token == cvar:
            return commands[index + 1]
    return None


def validate_p036_map16(
    log: str,
    run_status: str,
    logical_accelerated: bool | None,
    startup_commands: list[str] | None,
) -> dict:
    """Require real two-leg P025 hits, transformation, concurrency and credit."""
    errors: list[str] = []
    if run_status != "RUNTIME_PASS":
        errors.append(f"MAP16 status was {run_status}, expected RUNTIME_PASS")
    if logical_accelerated is not False:
        errors.append("MAP16 evidence was not a normal-speed run")
    if _startup_value(startup_commands, "ds_p030_mode") != "p036":
        errors.append("startup did not select the opt-in P036 MAP16 route")
    if _startup_value(startup_commands, "ds_p032_mode") != "evolution":
        errors.append("startup did not enable the qualified controlled evolution tape")
    if "DS_ASSERT_FAIL" in log or "DS_RUNTIME_ASSERT_FAIL" in log:
        errors.append("engine log contains an assertion failure")
    if re.search(r"VM execution aborted|Script error|Unknown identifier|Fatal error", log, re.I):
        errors.append("engine log contains a script/runtime failure")

    boots = _rows(log, "DS_P030_BOOT")
    if (len(boots) != 1 or boots[0].get("map") != "MAP16"
            or boots[0].get("mode") != "p036"
            or _int(boots[0], "logical_steps") != 1
            or _int(boots[0], "normal_speed") != 1):
        errors.append("MAP16 did not start once in P036 mode at normal speed")
    p036_boots = _rows(log, "DS_P036_MAP16_BOOT")
    if (len(p036_boots) != 1
            or p036_boots[0].get("route") != "OPT_IN_P036"
            or p036_boots[0].get("default_manual_preserved") != "1"
            or p036_boots[0].get("equipment") != "CONTROLLED_MAP16_FIXTURE"
            or p036_boots[0].get("clover") != "CONTROLLED_INGREDIENT_FIXTURE"
            or p036_boots[0].get("no_natural_acquisition_claim") != "1"):
        errors.append("P036 MAP16 boot/provenance marker is missing or duplicated")
    fixtures = _rows(log, "DS_P036_MAP16_FIXTURE")
    if (len(fixtures) != 1 or _int(fixtures[0], "accepted") != 1
            or _int(fixtures[0], "cross_rank") != 8
            or fixtures[0].get("equipment") != "CONTROLLED_MAP16_FIXTURE"
            or fixtures[0].get("clover") != "CONTROLLED_INGREDIENT_FIXTURE"
            or fixtures[0].get("source_inventory_claim") != "0"):
        errors.append("controlled Cross/Clover MAP16 fixture was not accepted explicitly")

    p031_arms = _rows(log, "DS_P031_MAP16_ARMS")
    if len(p031_arms) != 1:
        errors.append("P031 concurrent diagnostic schedule is not present")
    elif not any(_int(row, "accepted") == 1
                 for row in _rows(log, "DS_P031_MAP16_DIAGNOSTIC_HIT")):
        errors.append("P031 automatic diagnostic has no accepted logical hit")
    p032_replacements = [row for row in _rows(log, "DS_P032_MAP16_WEAPON_REPLACE")
                         if _int(row, "accepted") == 1]
    if len(p032_replacements) != 1:
        errors.append("P032 Whip-to-Bloody-Tear route did not commit once")
    elif not any(_int(row, "accepted") == 1
                 for row in _rows(log, "DS_P032_BLOODY_TEAR_HIT")):
        errors.append("automatic Bloody Tear has no accepted hit alongside P036")
    for marker, ids in (("DS_P034_HIT", {34, 36}), ("DS_P035_HIT", {38, 39, 40, 41})):
        accepted_ids = {_int(row, "system_id") for row in _rows(log, marker)
                        if _int(row, "accepted") == 1}
        if not ids.issubset(accepted_ids):
            errors.append(f"concurrent {marker} systems missing accepted hits: {sorted(ids - accepted_ids)}")

    equips = [row for row in _rows(log, "DS_P036_EQUIP")
              if _int(row, "system_id") == 42]
    if (len(equips) != 1 or _int(equips[0], "accepted") != 1
            or _int(equips[0], "rank") != 8
            or equips[0].get("source") != "CONTROLLED_MAP16_FIXTURE"
            or equips[0].get("source_inventory_claim") != "0"):
        errors.append("rank-eight controlled Cross equipment is missing")
    transforms = [row for row in _rows(log, "DS_P036_MAP16_TRANSFORM")
                  if (_int(row, "source_system_id"), _int(row, "evolved_system_id")) == (42, 43)]
    if (len(transforms) != 1 or _int(transforms[0], "accepted") != 1
            or _int(transforms[0], "source_rank") != 8
            or _int(transforms[0], "output_rank") != 1
            or _int(transforms[0], "dependency_kind") != 3
            or _int(transforms[0], "dependency_min_rank") != 1
            or _int(transforms[0], "dependency_rank") != 1
            or transforms[0].get("dependency_source") != "CONTROLLED_CLOVER_FIXTURE"
            or transforms[0].get("source_inventory_claim") != "0"):
        errors.append("controlled Cross-to-Heaven Sword transformation was not accepted")
    form_commits = [row for row in _rows(log, "DS_P036_FORM_REPLACE")
                    if _int(row, "source_system_id") == 42
                    and _int(row, "evolved_system_id") == 43]
    if len(form_commits) != 1 or _int(form_commits[0], "accepted") != 1:
        errors.append("returning authority did not commit the form replacement once")
    transform_tic = _int(transforms[0], "tic") if len(transforms) == 1 else None
    if transform_tic is None:
        errors.append("P036 transformation marker has no tic")

    volleys = { _int(row, "event_id", -1): row
                for row in _rows(log, "DS_P036_VOLLEY")
                if (_int(row, "event_id", -1) or -1) > 0 }
    projectiles = { _int(row, "event_id", -1): row
                    for row in _rows(log, "DS_P036_PROJECTILE")
                    if (_int(row, "event_id", -1) or -1) > 0 }
    accepted_hits: list[dict[str, str]] = []
    damage_by_tic: Counter[int] = Counter()
    hits_by_system: Counter[int] = Counter()
    leg_hits: dict[tuple[int, int], set[int]] = defaultdict(set)
    hit_keys: set[tuple[int, int, int]] = set()
    for hit in _rows(log, "DS_P036_HIT"):
        if _int(hit, "accepted") != 1:
            continue
        system_id = _int(hit, "system_id", -1)
        if system_id not in (42, 43):
            errors.append(f"P036 accepted hit has unexpected adapter system {system_id}")
            continue
        accepted_hits.append(hit)
        hits_by_system[system_id] += 1
        event_id = _int(hit, "event_id", -1)
        projectile = projectiles.get(event_id)
        volley_id = _int(hit, "parent_event_id", -1)
        volley = volleys.get(volley_id)
        if (projectile is None or volley is None
                or _int(projectile, "system_id") != system_id
                or _int(projectile, "parent_event_id") != volley_id
                or _int(volley, "system_id") != system_id
                or _int(projectile, "rank") != _int(hit, "rank")
                or _int(projectile, "child_ordinal") != _int(hit, "child_ordinal")
                or _int(projectile, "rank_hash") != _int(hit, "rank_hash")):
            errors.append(f"P036 accepted hit {event_id} does not join to its volley/projectile snapshot")
        before = _int(hit, "before")
        after = _int(hit, "after")
        damage = _int(hit, "damage_milli")
        actual = min(before, damage) if before is not None and damage is not None else None
        if (hit.get("authority") != "P025_CHECKED_LOGICAL_HIT"
                or before is None or before <= 0 or after is None or damage is None
                or damage <= 0 or actual is None or before - after != actual
                or after != max(0, before - damage)):
            errors.append(f"P036 accepted hit {event_id} is inconsistent with clamped P025 damage")
        logical_tic = _int(hit, "tic")
        if logical_tic is None:
            errors.append(f"P036 hit {event_id} lacks logical tic")
        else:
            damage_by_tic[logical_tic] += actual or 0
        leg = _int(hit, "leg")
        target_id = _int(hit, "target_id")
        if leg not in (1, 2) or target_id is None:
            errors.append(f"P036 hit {event_id} has invalid leg or target identity")
            continue
        key = (event_id, leg, target_id)
        if key in hit_keys:
            errors.append(f"P036 child {event_id} damaged target {target_id} more than once on leg {leg}")
        hit_keys.add(key)
        leg_hits[(event_id, target_id)].add(leg)

    for system_id in (42, 43):
        if not any(_int(row, "system_id") == system_id for row in accepted_hits):
            errors.append(f"no accepted checked hit exists for P036 system {system_id}")
        source_rows = [row for row in accepted_hits
                       if _int(row, "system_id") == system_id]
        if system_id == 42 and transform_tic is not None and not any(
                (_int(row, "tic") or 0) < transform_tic for row in source_rows):
            errors.append("Cross has no accepted hit before its controlled transformation")
        if system_id == 43 and transform_tic is not None and not any(
                (_int(row, "tic") or 0) > transform_tic for row in source_rows):
            errors.append("Heaven Sword has no accepted hit after its controlled transformation")
    if not any(len(legs) == 2 for legs in leg_hits.values()):
        errors.append("no projectile has one accepted hit on each outbound/reverse leg")

    # Validate actual path direction and the explicit turn marker for at least
    # one child. A nonblank room or a marker-only claim is insufficient.
    paths = _rows(log, "DS_P036_PATH_STEP")
    paths_by_event: dict[int, list[dict[str, str]]] = defaultdict(list)
    for row in paths:
        event_id = _int(row, "event_id")
        if event_id is not None:
            paths_by_event[event_id].append(row)
    turns = _rows(log, "DS_P036_TURN")
    if not any(_int(row, "event_id") in projectiles for row in turns):
        errors.append("no actual returning projectile emitted a turnaround marker")
    observed_path_pair = False
    for event_id, rows in paths_by_event.items():
        outbound = next((row for row in rows if row.get("leg") == "OUTBOUND"), None)
        reverse = next((row for row in rows if row.get("leg") == "REVERSE"), None)
        projectile = projectiles.get(event_id)
        if outbound is None or reverse is None or projectile is None:
            continue
        dx = float(projectile.get("direction_x", "0"))
        dy = float(projectile.get("direction_y", "0"))
        out_dx = float(outbound.get("end_x", "0")) - float(outbound.get("start_x", "0"))
        out_dy = float(outbound.get("end_y", "0")) - float(outbound.get("start_y", "0"))
        rev_dx = float(reverse.get("end_x", "0")) - float(reverse.get("start_x", "0"))
        rev_dy = float(reverse.get("end_y", "0")) - float(reverse.get("start_y", "0"))
        if dx * out_dx + dy * out_dy > 0 and dx * rev_dx + dy * rev_dy < 0:
            observed_path_pair = True
            break
    if not observed_path_pair:
        errors.append("no child shows outbound motion then motion on the opposite frozen heading")

    credits = _rows(log, "DS_P036_MAP16_DAMAGE_CREDIT")
    credited_by_tic: Counter[int] = Counter()
    previous_total = -1
    for row in credits:
        tic = _int(row, "tic")
        delta = _int(row, "accepted_delta_milli")
        total = _int(row, "total_milli")
        if (tic is None or delta is None or delta <= 0 or total is None
                or row.get("authority") != "DSP036_P025_CHECKED_LOGICAL_HITS"):
            errors.append("P036 damage-credit row is incomplete or invalid")
            continue
        if total < previous_total:
            errors.append("MAP16 P036 damage total moved backwards")
        previous_total = total
        credited_by_tic[tic] += delta
    if damage_by_tic != credited_by_tic:
        errors.append("P036 accepted hit health deltas do not equal per-tic results credit")
    p036_damage = sum(damage_by_tic.values())
    results = _rows(log, "DS_P030_RESULTS")
    complete = _rows(log, "DS_P030_COMPLETE")
    if (len(results) != 1 or _int(results[0], "damage", 0) < p036_damage
            or results[0].get("entities") != "0"):
        errors.append("final MAP16 result ledger omits accepted P036 damage or live entities")
    if (len(complete) != 1 or complete[0].get("state") != "RESULTS"
            or _int(complete[0], "logical_accelerated") != 0):
        errors.append("normal-speed MAP16 route did not reach results")

    return {
        "status": "PASS" if not errors else "FAIL",
        "errors": errors,
        "accepted_hits": len(accepted_hits),
        "accepted_hits_by_system": {str(key): hits_by_system[key]
                                     for key in sorted(hits_by_system)},
        "accepted_damage_milli": p036_damage,
        "credited_damage_milli": sum(credited_by_tic.values()),
        "credit_mismatched_tics": sorted(
            tic for tic in set(damage_by_tic) | set(credited_by_tic)
            if damage_by_tic[tic] != credited_by_tic[tic]),
        "double_leg_target_joins": sum(1 for legs in leg_hits.values()
                                        if len(legs) == 2),
    }


def validate_p036_default_manual(log: str, run_status: str,
                                 logical_accelerated: bool | None) -> dict:
    errors: list[str] = []
    if run_status != "RUNTIME_PASS":
        errors.append(f"default manual status was {run_status}, expected RUNTIME_PASS")
    if logical_accelerated is not False:
        errors.append("default manual evidence was not normal speed")
    boots = _rows(log, "DS_P030_BOOT")
    if (len(boots) != 1 or boots[0].get("map") != "MAP16"
            or boots[0].get("mode") != "manual"):
        errors.append("default route did not start in manual MAP16 mode")
    if not any(row.get("state") == "RESULTS" for row in _rows(log, "DS_P030_COMPLETE")):
        errors.append("default manual route did not complete")
    active_prefixes = (
        "DS_P036_MAP16_BOOT", "DS_P036_MAP16_FIXTURE", "DS_P036_EQUIP ",
        "DS_P036_VOLLEY ", "DS_P036_PROJECTILE ", "DS_P036_HIT ",
        "DS_P036_TURN ", "DS_P036_MAP16_TRANSFORM ",
        "DS_P036_MAP16_DAMAGE_CREDIT ",
    )
    if any(marker in log for marker in active_prefixes):
        errors.append("default manual route activated P036 gameplay")
    return {"status": "PASS" if not errors else "FAIL", "errors": errors}


class P036Map16ValidatorTests(unittest.TestCase):
    def test_marker_only_and_wrong_mode_fail_closed(self) -> None:
        marker_only = """DS_P030_BOOT map=MAP16 mode=p036 logical_steps=1 normal_speed=1
DS_P036_MAP16_BOOT route=OPT_IN_P036 default_manual_preserved=1 equipment=CONTROLLED_MAP16_FIXTURE clover=CONTROLLED_INGREDIENT_FIXTURE no_natural_acquisition_claim=1
DS_P036_MAP16_FIXTURE accepted=1 cross_rank=8 equipment=CONTROLLED_MAP16_FIXTURE clover=CONTROLLED_INGREDIENT_FIXTURE source_inventory_claim=0
"""
        commands = ["+set", "ds_p030_mode", "p036", "+set", "ds_p032_mode", "evolution"]
        result = validate_p036_map16(marker_only, "RUNTIME_PASS", False, commands)
        self.assertEqual("FAIL", result["status"])
        self.assertTrue(result["errors"])
        wrong = validate_p036_map16(marker_only, "RUNTIME_PASS", True,
                                    ["+set", "ds_p030_mode", "p035"])
        self.assertTrue(any("normal-speed" in error for error in wrong["errors"]))

    def test_default_manual_excludes_p036_activation(self) -> None:
        log = """DS_P030_BOOT map=MAP16 mode=manual logical_steps=1 normal_speed=1
DS_P030_COMPLETE state=RESULTS tics=2100 logical_accelerated=0
"""
        self.assertEqual("PASS", validate_p036_default_manual(
            log, "RUNTIME_PASS", False)["status"])
        altered = log + "DS_P036_PROJECTILE event_id=3600001 system_id=42\n"
        self.assertEqual("FAIL", validate_p036_default_manual(
            altered, "RUNTIME_PASS", False)["status"])


if __name__ == "__main__":
    unittest.main()
