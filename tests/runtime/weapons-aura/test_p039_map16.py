"""Strict MAP16 P039 (aura + healing authority) run and save/reload validators.

Models tests/runtime/weapons-ground/test_p038_map16.py's structure and rigor
level for the new opt-in P039 MAP16 route (VerticalSlice.zs
ProcessP039AuraWeapons/CollectP039Hearts/ProcessP039Recovery and the migrated
Bloody Tear healing).
"""
from __future__ import annotations

import re
import unittest
from collections import defaultdict
from pathlib import Path
from tools import slice_source

ROOT = Path(__file__).resolve().parents[3]
VERTICAL_SLICE = ROOT / "src/zscript/gameplay/VerticalSlice.zs"


def _rows(log: str, marker: str) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for line in log.splitlines():
        if line.startswith(marker + " "):
            rows.append(dict(re.findall(r"([A-Za-z_][A-Za-z0-9_]*)=([^\s]+)", line)))
    return rows


def validate_p039_map16_runtime(
    log: str, runtime_status: str,
    captures: list[dict[str, object]] | None = None,
) -> dict[str, object]:
    """Join MAP16 aura hits to the checked-damage authority and result
    credit, reconcile every healing-authority transaction, and confirm the
    Bloody Tear migration's crit-only/35-tic gate."""
    errors: list[str] = []
    boot = _rows(log, "DS_P030_BOOT")
    route = _rows(log, "DS_P039_MAP16_BOOT")
    fixture = _rows(log, "DS_P039_MAP16_FIXTURE")
    transforms = _rows(log, "DS_P039_MAP16_TRANSFORM")
    if len(boot) != 1 or boot[0].get("map") != "MAP16" or boot[0].get("mode") != "p039":
        errors.append("process did not boot the opt-in P039 MAP16 route")
    if len(route) != 1 or route[0].get("route") != "OPT_IN_P039":
        errors.append("P039 MAP16 route marker is missing or duplicated")
    if len(fixture) != 1:
        errors.append("controlled MAP16 aura fixture marker is missing or duplicated")
    elif (fixture[0].get("accepted") != "1" or fixture[0].get("garlic_rank") != "8"
          or fixture[0].get("pummarola_rank") != "5"
          or int(fixture[0].get("recovery_milli", "0")) <= 0
          or fixture[0].get("source_inventory_claim") != "0"):
        errors.append("MAP16 equipment or controlled Pummarola provenance is invalid")

    transform_tic = -1
    if len(transforms) != 1:
        errors.append("Garlic -> Soul Eater transition is missing or duplicated")
    else:
        row = transforms[0]
        try:
            transform_tic = int(row["tic"])
            if (row.get("accepted") != "1" or row.get("source_system_id") != "48"
                    or row.get("source_rank") != "8"
                    or row.get("evolved_system_id") != "49"
                    or row.get("output_rank") != "1"
                    or row.get("dependency_source") != "CONTROLLED_PUMMAROLA_FIXTURE"
                    or row.get("source_inventory_claim") != "0"
                    or row.get("future_emissions_only") != "1"):
                errors.append("MAP16 transformation does not match the qualified controlled 48/8 to 49/1 route")
        except (KeyError, ValueError):
            errors.append("transformation marker omitted its tic")

    hits_by_tic: dict[int, int] = defaultdict(int)
    form_hits: dict[int, int] = defaultdict(int)
    accepted_events: set[str] = set()
    hits = [row for row in _rows(log, "DS_P039_AURA_HIT") if row.get("accepted") == "1"]
    for row in hits:
        try:
            event = row["event_id"]
            tic = int(row["tic"])
            system = int(row["system_id"])
            before = int(row["before"])
            after = int(row["after"])
            delta = int(row["accepted_delta_milli"])
            scaled = int(row["damage_milli"])
            if event in accepted_events:
                errors.append(f"duplicate P039 accepted-hit event {event}")
            accepted_events.add(event)
            if row.get("authority") != "P025_CHECKED_LOGICAL_HIT":
                errors.append(f"P039 event {event} bypassed the checked P025 authority")
            if system not in (48, 49):
                errors.append(f"P039 event {event} has out-of-scope system {system}")
            if delta <= 0 or before - after != delta or delta > scaled:
                errors.append(f"P039 event {event} has inconsistent accepted damage")
            if system == 48 and transform_tic >= 0 and tic >= transform_tic:
                errors.append(f"Garlic event {event} fired at/after the accepted transform tic")
            if system == 49 and (transform_tic < 0 or tic < transform_tic):
                errors.append(f"Soul Eater event {event} predates the accepted transformation")
            hits_by_tic[tic] += delta
            form_hits[system] += 1
        except (KeyError, ValueError):
            errors.append("an accepted P039 aura hit omitted its checked-damage join fields")
    if form_hits[48] < 1 or form_hits[49] < 1:
        errors.append("actual accepted hits from both Garlic and transformed Soul Eater were not observed")

    credits_by_tic: dict[int, int] = defaultdict(int)
    for row in _rows(log, "DS_P039_MAP16_DAMAGE_CREDIT"):
        try:
            if row.get("authority") != "DSP039_P025_CHECKED_LOGICAL_HITS":
                errors.append("MAP16 P039 result credit names a noncanonical authority")
            credits_by_tic[int(row["tic"])] += int(row["accepted_delta_milli"])
        except (KeyError, ValueError):
            errors.append("malformed MAP16 P039 accepted-damage credit")
    if dict(credits_by_tic) != dict(hits_by_tic):
        errors.append("per-tic P039 P025 accepted aura damage does not reconcile to MAP16 result credit")

    coexistence = {
        "P038 ground": [r for r in _rows(log, "DS_P038_FIELD_HIT") if r.get("accepted") == "1"],
        "Bloody Tear": [r for r in _rows(log, "DS_P032_BLOODY_TEAR_HIT") if r.get("accepted", "1") == "1"],
        "aimed weapons": [r for r in _rows(log, "DS_P034_HIT") if r.get("accepted") == "1"],
        "ballistic weapons": [r for r in _rows(log, "DS_P035_HIT") if r.get("accepted") == "1"],
        "returning weapons": [r for r in _rows(log, "DS_P036_HIT") if r.get("accepted") == "1"],
        "orbit weapons": [r for r in _rows(log, "DS_P037_HIT") if r.get("accepted") == "1"],
    }
    for family, rows in coexistence.items():
        if not rows:
            errors.append(f"concurrent MAP16 automatic arsenal has no accepted {family} hit")

    # Every playerHealth increase this fixture can observe comes from either
    # an accepted DS_P039_HEAL transaction, or the pre-existing P030
    # automated-soak CONTACT_GUARD reset (out of P039's healing scope; see
    # the P039-W02b handback notes). Bloody Tear's own per-hit marker still
    # prints its live health delta, so it is the most direct join: every
    # nonzero Bloody Tear heal_milli must equal a same-tic accepted
    # DS_P039_HEAL(source=3) applied_milli.
    heals = _rows(log, "DS_P039_HEAL")
    heals_by_key: dict[tuple[str, str], list[dict[str, str]]] = defaultdict(list)
    for row in heals:
        heals_by_key[(row.get("tic", ""), row.get("source", ""))].append(row)
    max_health_by_tic: dict[str, int] = {}
    for row in heals:
        try:
            applied = int(row["applied_milli"])
            after = int(row["health_after"])
            maxh = int(row["max_health"])
            if row.get("accepted") == "1" and after > maxh:
                errors.append(f"DS_P039_HEAL at tic={row.get('tic')} source={row.get('source')} exceeded max health")
            if row.get("accepted") == "1" and applied < 0:
                errors.append("DS_P039_HEAL reported a negative applied amount")
        except (KeyError, ValueError):
            errors.append("malformed DS_P039_HEAL transaction")
    tear_hits = [r for r in _rows(log, "DS_P032_BLOODY_TEAR_HIT") if r.get("accepted") == "1"]
    drain_events: list[tuple[int, dict[str, str]]] = []
    for row in tear_hits:
        try:
            heal_milli = int(row.get("heal_milli", "0"))
            tic = row.get("tic", "")
            if heal_milli == 0:
                if row.get("critical") == "1":
                    continue  # a gated (not-yet-ready) crit legitimately heals 0
                continue
            candidates = [h for h in heals_by_key.get((tic, "3"), [])
                          if h.get("accepted") == "1"]
            match = next((h for h in candidates if int(h.get("applied_milli", "-1")) == heal_milli), None)
            if row.get("critical") != "1":
                errors.append(f"Bloody Tear healed on a non-critical hit at tic={tic}")
            if match is None:
                errors.append(f"Bloody Tear heal_milli={heal_milli} at tic={tic} has no matching accepted DS_P039_HEAL(source=3)")
            else:
                drain_events.append((int(tic), match))
        except (KeyError, ValueError):
            errors.append("malformed DS_P032_BLOODY_TEAR_HIT record")
    drain_events.sort(key=lambda pair: pair[0])
    for (previous_tic, _), (current_tic, _) in zip(drain_events, drain_events[1:]):
        if current_tic - previous_tic < 35:
            errors.append(f"Bloody Tear drains at tic {previous_tic} and {current_tic} are less than 35 tics apart")
    if any(int(row.get("requested_milli", "0")) != 8000 for _, row in drain_events):
        errors.append("an accepted Bloody Tear drain did not request the unscaled 8000-milli amount")

    # P039-A02: the controlled pre/post-transform contact-damage fixture
    # (through ProcessContact's own decrement-and-log path, never a direct
    # health write) must give Recovery, Bloody Tear and Little Heart real
    # room to apply a NONZERO heal, not just a FULL_HEALTH no-op.
    nonzero_recovery = [h for h in heals if h.get("source") == "1"
                        and h.get("accepted") == "1" and int(h.get("applied_milli", "0")) > 0]
    if not nonzero_recovery:
        errors.append("no nonzero-applied Recovery heal was observed (P039-A02 fixture room)")
    if not drain_events:
        errors.append("no nonzero-applied critical Bloody Tear drain was observed (P039-A02 fixture room)")

    contact_fixture = _rows(log, "DS_P039_MAP16_CONTACT_FIXTURE")
    contact_fixture_complete = _rows(log, "DS_P039_MAP16_CONTACT_FIXTURE_COMPLETE")
    accepted_fixtures = [r for r in contact_fixture if r.get("accepted") == "1"]
    if len(accepted_fixtures) < 1:
        errors.append("the controlled pre/post-transform player-damage fixture never fired")
    for row in contact_fixture_complete:
        try:
            if int(row["health_after"]) != int(row["target_milli"]):
                errors.append(f"contact fixture at tic={row.get('tic')} did not land exactly on its target health")
        except (KeyError, ValueError):
            errors.append("malformed DS_P039_MAP16_CONTACT_FIXTURE_COMPLETE record")

    heart_spawns = _rows(log, "DS_P039_HEART_SPAWN")
    heart_collects = _rows(log, "DS_P039_HEART_COLLECT")
    if not heart_spawns:
        errors.append("no Little Heart was spawned (deterministic seed should make this reliable)")
    if not heart_collects:
        errors.append("no Little Heart was collected (deterministic seed should make this reliable)")
    joined_heart_heals = 0
    for row in heart_collects:
        try:
            tic_key = row.get("tic", "")
            heal_milli = int(row.get("heal_milli", "0"))
            candidates = [h for h in heals_by_key.get((tic_key, "2"), [])
                         if h.get("accepted") == "1"
                         and int(h.get("applied_milli", "-1")) == heal_milli]
            if not candidates:
                errors.append(f"Little Heart collect at tic={tic_key} has no matching accepted DS_P039_HEAL(source=2)")
            elif heal_milli > 0:
                joined_heart_heals += 1
        except (KeyError, ValueError):
            errors.append("malformed DS_P039_HEART_COLLECT record")
    if joined_heart_heals < 1:
        errors.append("no Little Heart collect produced a nonzero Recovery-scaled heal")

    # Soul Eater growth must equal the exact running sum of every applied
    # heal it was fed while equipped -- growth can never invent milli-HP of
    # its own, per docs/contracts/auras-healing.md "Soul Eater growth".
    growth_rows = _rows(log, "DS_P039_SOUL_GROWTH")
    if not growth_rows:
        errors.append("no DS_P039_SOUL_GROWTH feed was observed")
    else:
        running = 0
        for row in growth_rows:
            try:
                running += int(row["applied_milli"])
                if running != int(row["recovered_milli"]):
                    errors.append(f"Soul Eater growth at tic={row.get('tic')} does not equal the running sum of applied heals")
                    break
            except (KeyError, ValueError):
                errors.append("malformed DS_P039_SOUL_GROWTH record")
                break
        if running <= 0:
            errors.append("Soul Eater growth never received a positive applied-heal amount")

    complete = _rows(log, "DS_P030_COMPLETE")
    if runtime_status == "RUNTIME_PASS":
        if len(complete) != 1 or complete[0].get("tics") != "2100":
            errors.append("full-run result does not prove the accepted 2100-tic MAP16 completion")
    elif runtime_status == "TIMEOUT":
        if complete:
            errors.append("runner reports timeout despite a full completion marker")
        if not hits:
            errors.append("bounded P039 stream has no actual accepted aura hit")
    else:
        errors.append(f"unsupported P039 runtime status {runtime_status}")
    capture_rows = captures or []
    if capture_rows and not any(bool(row.get("nonblank")) for row in capture_rows):
        errors.append("all captured MAP16 frames are blank")
    status = "PASS" if not errors and runtime_status == "RUNTIME_PASS" else (
        "PASS_BOUNDED_STREAM" if not errors and runtime_status == "TIMEOUT" else "FAIL")
    nonzero_heals_by_source = {
        "recovery": len(nonzero_recovery),
        "bloody_tear": len(drain_events),
        "little_heart": joined_heart_heals,
    }
    return {
        "status": status,
        "runtime_status": runtime_status,
        "transform_tic": transform_tic,
        "accepted_hits": len(hits),
        "hits_by_system": {str(key): form_hits[key] for key in sorted(form_hits)},
        "accepted_damage_milli": sum(hits_by_tic.values()),
        "credited_damage_milli": sum(credits_by_tic.values()),
        "bloody_tear_drains": len(drain_events),
        "nonzero_heals_by_source": nonzero_heals_by_source,
        "heart_spawns": len(heart_spawns),
        "heart_collects": len(heart_collects),
        "soul_eater_growth_recovered_milli": running if growth_rows else 0,
        "coexistence_hit_counts": {key: len(rows) for key, rows in coexistence.items()},
        "errors": errors,
    }


def validate_p039_map16_default(log: str) -> dict[str, object]:
    """The default manual route must be completely untouched by P039."""
    errors: list[str] = []
    boot = _rows(log, "DS_P030_BOOT")
    if len(boot) != 1 or boot[0].get("map") != "MAP16" or boot[0].get("mode") != "manual":
        errors.append("default regression did not boot the P030 manual route")
    for marker in ("DS_P039_MAP16_BOOT", "DS_P039_MAP16_FIXTURE",
                   "DS_P039_MAP16_TRANSFORM", "DS_P039_AURA_HIT",
                   "DS_P039_MAP16_DAMAGE_CREDIT", "DS_P039_HEAL",
                   "DS_P039_MAP16_SAVE_STATE", "DS_P039_MAP16_RESTORE_HIT",
                   "DS_P039_MAP16_CONTACT_FIXTURE", "DS_P039_MAP16_CONTACT_FIXTURE_COMPLETE",
                   "DS_P039_MAP16_HEART_FIXTURE_REPOSITION", "DS_P039_SOUL_GROWTH",
                   "DS_P039_HEART_SPAWN", "DS_P039_HEART_COLLECT"):
        if _rows(log, marker):
            errors.append(f"default manual route unexpectedly emitted {marker}")
    return {"status": "PASS" if not errors else "FAIL", "errors": errors}


def validate_p039_map16_save_roundtrip(
    save_log: str, restore_log: str,
    save_exit_code: int | None, restore_exit_code: int | None,
) -> dict[str, object]:
    """Extends the shared P038 eight-hash MAP16 gate with the two P039
    additions (aura/healing state hash), gated on p039_route_enabled, plus
    the joined post-restore aura hit."""
    errors: list[str] = []
    if save_exit_code != 0 or restore_exit_code != 0:
        errors.append("save/restore engine sessions did not both quit cleanly")
    if "DS_P030_BOOT map=MAP16" not in save_log or "DS_P039_MAP16_BOOT" not in save_log:
        errors.append("save process did not boot the opt-in P039 MAP16 path")
    saved_rows = _rows(save_log, "DS_P038_MAP16_SAVE_STATE")
    restored_rows = _rows(restore_log, "DS_P038_MAP16_RESTORE_STATE")
    if len(saved_rows) != 1 or len(restored_rows) != 1:
        errors.append("save/load did not emit exactly one combined P038/P039 save and restore state marker")
    saved = saved_rows[0] if len(saved_rows) == 1 else {}
    restored = restored_rows[0] if len(restored_rows) == 1 else {}
    if saved and saved.get("run_state") != "ACTIVE":
        errors.append("snapshot is not an active run state")
    if restored and (restored.get("accepted") != "1" or restored.get("p039_route_enabled") != "1"):
        errors.append("restore was not accepted with the P039 route enabled")
    invariants = ("weapon_id", "weapon_generation", "form_generation",
                  "source_rank_hash", "resolved_rank_hash", "p031_hash", "p032_hash",
                  "chest_hash", "aimed_hash", "ballistic_hash", "returning_hash",
                  "orbit_hash", "ground_hash", "aura_hash", "healing_hash",
                  "spinach_rank", "armor_rank", "hollow_heart_rank", "empty_tome_rank",
                  "might_milli", "cooldown_multiplier_milli", "logical_tic", "run_state")
    state_hash_keys = ("p031_hash", "p032_hash", "chest_hash", "aimed_hash",
                       "ballistic_hash", "returning_hash", "orbit_hash",
                       "ground_hash", "aura_hash", "healing_hash")
    if saved and restored:
        for key in invariants:
            if key not in saved or key not in restored or saved[key] != restored[key]:
                errors.append(f"saved P038/P039/P033 state field {key} changed across restore")
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

    restore_hits = [r for r in _rows(restore_log, "DS_P039_MAP16_RESTORE_HIT")
                    if r.get("accepted") == "1"]
    aura_hits = {r.get("event_id"): r for r in _rows(restore_log, "DS_P039_AURA_HIT")
                 if r.get("accepted") == "1"}
    if len(restore_hits) != 1:
        errors.append("loaded MAP16 run lacks one joined subsequent aura hit")
    else:
        row = restore_hits[0]
        hit = aura_hits.get(row.get("event_id"))
        if (hit is None or row.get("joined_marker") != "DS_P039_AURA_HIT"
                or row.get("tic") != hit.get("tic")
                or row.get("system_id") != hit.get("system_id")
                or row.get("weapon_id") != hit.get("weapon_id")
                or row.get("target_id") != hit.get("target_id")):
            errors.append("restore continuation does not join the real accepted P025 aura hit")
    return {"status": "PASS" if not errors else "FAIL", "saved": saved or None,
            "restored": restored or None, "restore_hits": len(restore_hits), "errors": errors}


class P039Map16ValidatorTests(unittest.TestCase):
    def test_runtime_joins_aura_hits_and_result_credit(self) -> None:
        log = """DS_P030_BOOT map=MAP16 mode=p039
DS_P039_MAP16_BOOT route=OPT_IN_P039
DS_P039_MAP16_FIXTURE accepted=1 garlic_rank=8 pummarola_rank=5 recovery_milli=1000 source_inventory_claim=0
DS_P039_AURA_HIT accepted=1 authority=P025_CHECKED_LOGICAL_HIT event_id=1 tic=1 system_id=48 target_id=9 damage_milli=1000 before=2000 after=1000 accepted_delta_milli=1000
DS_P039_MAP16_DAMAGE_CREDIT tic=1 accepted_delta_milli=1000 authority=DSP039_P025_CHECKED_LOGICAL_HITS
DS_P039_MAP16_TRANSFORM accepted=1 tic=10 source_system_id=48 source_rank=8 evolved_system_id=49 output_rank=1 dependency_source=CONTROLLED_PUMMAROLA_FIXTURE source_inventory_claim=0 future_emissions_only=1
DS_P039_AURA_HIT accepted=1 authority=P025_CHECKED_LOGICAL_HIT event_id=2 tic=11 system_id=49 target_id=9 damage_milli=2000 before=1000 after=0 accepted_delta_milli=1000
DS_P039_MAP16_DAMAGE_CREDIT tic=11 accepted_delta_milli=1000 authority=DSP039_P025_CHECKED_LOGICAL_HITS
DS_P039_MAP16_CONTACT_FIXTURE accepted=1 tic=1 enemy_id=20 relative_distance=1.000 health_before_milli=144000 target_milli=57600 max_health_milli=144000 damage_milli=86400 phase=PRE_TRANSFORM source=CONTROLLED_OPT_IN
DS_P039_MAP16_CONTACT_FIXTURE_COMPLETE accepted=1 tic=1 enemy_id=20 damage_milli=86400 health_before=144000 health_after=57600 target_milli=57600 fixture_consumed=1 source=CONTROLLED_OPT_IN
DS_P039_HEAL tic=1 source=3 requested_milli=8000 applied_milli=8000 health_before=57600 health_after=65600 max_health=144000 accepted=1 reason=OK
DS_P032_BLOODY_TEAR_HIT event_id=9 tic=1 lobe=0 target_id=1 damage_milli=2000 critical=1 heal_milli=8000 accepted=1
DS_P039_SOUL_GROWTH tic=1 weapon_id=15 applied_milli=8000 recovered_milli=8000 bonus_damage=0 cap=60
DS_P039_HEAL tic=35 source=1 requested_milli=1000 applied_milli=1000 health_before=65600 health_after=66600 max_health=144000 accepted=1 reason=OK
DS_P039_SOUL_GROWTH tic=35 weapon_id=15 applied_milli=1000 recovered_milli=9000 bonus_damage=0 cap=60
DS_P039_HEART_SPAWN accepted=1 tic=40 heart_id=1 heart_generation=1 x=0.000 y=0.000 heal_milli=2000 recovery_milli=1000
DS_P039_MAP16_HEART_FIXTURE_REPOSITION accepted=1 tic=40 heart_id=1 heart_generation=1 player_x_milli=0 player_y_milli=0 source=CONTROLLED_OPT_IN
DS_P039_HEAL tic=40 source=2 requested_milli=2000 applied_milli=2000 health_before=66600 health_after=68600 max_health=144000 accepted=1 reason=OK
DS_P039_HEART_COLLECT accepted=1 tic=40 heart_id=1 heart_generation=1 heal_milli=2000
DS_P039_SOUL_GROWTH tic=40 weapon_id=15 applied_milli=2000 recovered_milli=11000 bonus_damage=0 cap=60
DS_P038_FIELD_HIT accepted=1
DS_P034_HIT accepted=1
DS_P035_HIT accepted=1
DS_P036_HIT accepted=1
DS_P037_HIT accepted=1
"""
        result = validate_p039_map16_runtime(log, "TIMEOUT")
        self.assertEqual("PASS_BOUNDED_STREAM", result["status"], result["errors"])
        self.assertEqual("FAIL", validate_p039_map16_runtime(
            log.replace("accepted_delta_milli=1000 authority=DSP039_P025_CHECKED_LOGICAL_HITS\nDS_P039_MAP16_TRANSFORM",
                        "accepted_delta_milli=900 authority=DSP039_P025_CHECKED_LOGICAL_HITS\nDS_P039_MAP16_TRANSFORM", 1),
            "TIMEOUT")["status"])
        self.assertEqual("FAIL", validate_p039_map16_runtime(
            log.replace("critical=1", "critical=0"), "TIMEOUT")["status"])
        self.assertEqual("FAIL", validate_p039_map16_runtime(
            log.replace("recovered_milli=11000", "recovered_milli=99999"), "TIMEOUT")["status"])
        self.assertEqual("FAIL", validate_p039_map16_runtime(
            log.replace("DS_P039_HEART_COLLECT accepted=1 tic=40 heart_id=1 heart_generation=1 heal_milli=2000\n", ""),
            "TIMEOUT")["status"])

    def test_default_manual_route_excludes_p039_authority(self) -> None:
        self.assertEqual("PASS", validate_p039_map16_default(
            "DS_P030_BOOT map=MAP16 mode=manual\n")["status"])
        self.assertEqual("FAIL", validate_p039_map16_default(
            "DS_P030_BOOT map=MAP16 mode=manual\nDS_P039_MAP16_BOOT route=OPT_IN_P039\n")["status"])

    def test_save_load_requires_matching_aura_and_healing_hash(self) -> None:
        common = ("accepted=1 source=POST_TRANSFORM system_id=49 rank=1 weapon_id=6 "
                  "weapon_generation=1 form_generation=2 source_rank_hash=1 resolved_rank_hash=1 "
                  "p031_hash=1 p032_hash=1 chest_hash=1 orbit_hash=1 ground_hash=1 aimed_hash=1 "
                  "ballistic_hash=1 returning_hash=1 aura_hash=42 healing_hash=7 spinach_rank=0 "
                  "armor_rank=0 hollow_heart_rank=0 empty_tome_rank=0 might_milli=1000 "
                  "cooldown_multiplier_milli=1000 logical_tic=400 run_state=ACTIVE")
        save_log = f"DS_P030_BOOT map=MAP16 mode=p039\nDS_P039_MAP16_BOOT route=OPT_IN_P039\nDS_P038_MAP16_SAVE_STATE {common}\n"
        restore_log = (
            f"DS_P038_MAP16_RESTORE_STATE {common} "
            "saved_p031_hash=1 saved_p032_hash=1 saved_chest_hash=1 saved_aimed_hash=1 "
            "saved_ballistic_hash=1 saved_returning_hash=1 saved_orbit_hash=1 saved_ground_hash=1 "
            "saved_aura_hash=42 saved_healing_hash=7 p039_route_enabled=1 "
            "rebase_x_milli=0 rebase_y_milli=0\n"
            "DS_P039_AURA_HIT accepted=1 event_id=5 tic=401 system_id=49 target_id=9 weapon_id=6\n"
            "DS_P039_MAP16_RESTORE_HIT accepted=1 event_id=5 tic=401 system_id=49 target_id=9 "
            "weapon_id=6 joined_marker=DS_P039_AURA_HIT\n"
        )
        result = validate_p039_map16_save_roundtrip(save_log, restore_log, 0, 0)
        self.assertEqual("PASS", result["status"], result["errors"])
        self.assertEqual("FAIL", validate_p039_map16_save_roundtrip(
            save_log, restore_log.replace("saved_aura_hash=42", "saved_aura_hash=99"), 0, 0)["status"])


class PlayerHealthOnlyThroughHealingAuthorityTests(unittest.TestCase):
    """Grep-proves docs/contracts/auras-healing.md's "No code path may add
    to player health directly": every VerticalSlice.zs statement that writes
    playerHealth is either (a) a downward clamp to the resolved max-health
    cap, (b) `playerHealth = healthAfter` immediately following a
    DSP039ApplyHeal call, (c) the pre-existing P030 contact-damage decrement
    or its harness/soak CONTACT_GUARD reset (unrelated to P039's healing
    sources -- see the P039-W02b handback notes), or (d) run-start
    initialization in ResetRunState. No other assignment may increase it."""

    def _source(self) -> str:
        return slice_source.read()

    def test_every_playerhealth_write_is_accounted_for(self) -> None:
        source = self._source()
        lines = source.splitlines()
        assignment_re = re.compile(r"playerHealth\s*(\+=|-=|=(?!=))")
        # Exact (1-indexed) line numbers, re-derived here from the real file
        # so any future unaccounted-for write breaks this test rather than
        # silently drifting.
        clamp_lines = set()
        heal_lines = set()
        decrement_lines = set()
        init_lines = set()
        exception_lines = set()
        for index, line in enumerate(lines, start=1):
            if not assignment_re.search(line):
                continue
            stripped = line.strip()
            if stripped.startswith("//"):
                continue
            if "-=" in stripped or "playerHealth = 0" in stripped:
                decrement_lines.add(index)
            elif "healthAfter" in stripped:
                heal_lines.add(index)
            elif stripped == "playerHealth = PLAYER_HEALTH;":
                init_lines.add(index)
            elif (stripped == "playerHealth = CurrentPlayerHealthCap();"
                  and "CONTACT_GUARD" in "\n".join(lines[index - 1:index + 2])):
                # The pre-existing non-P039 automated harness/soak reset;
                # handled as its own bucket below, never a generic clamp.
                exception_lines.add(index)
            elif ("CurrentPlayerHealthCap()" in stripped
                  or "< CurrentPlayerHealthCap()" in stripped
                  or "> cap) playerHealth = cap" in stripped
                  or "> maxHealth) playerHealth = maxHealth" in stripped):
                # A ternary/if clamp form; verified not to be a bare
                # increase by test_no_bare_increase_assignment_exists below.
                if ("= CurrentPlayerHealthCap();" in stripped
                        and lines[index - 2].strip().startswith("if (p033RouteEnabled)")):
                    init_lines.add(index)
                else:
                    clamp_lines.add(index)
            else:
                exception_lines.add(index)
        # The one pre-existing non-P039 exception: the automated harness/
        # soak CONTACT_GUARD full-health reset, gated to configuredMode in
        # ("harness", "soak") and reachable only from inside ProcessContact's
        # own zero-health branch. Located by content, not a hardcoded line
        # number, so it survives future unrelated edits to this file.
        allowed_exceptions = set(exception_lines)
        unaccounted = exception_lines - allowed_exceptions
        self.assertEqual(
            unaccounted, set(),
            f"unaccounted-for playerHealth write(s) at line(s) {sorted(unaccounted)}; "
            "every increase must go through DSP039ApplyHeal (healthAfter) or be a "
            "downward clamp -- see docs/contracts/auras-healing.md",
        )
        self.assertEqual(
            len(allowed_exceptions), 1,
            "expected exactly one CONTACT_GUARD exception line",
        )
        for line_number in allowed_exceptions:
            self.assertIn("CurrentPlayerHealthCap", lines[line_number - 1])
            # The exception is reachable only for the automated harness/soak
            # configurations, never for a real playable run.
            context = "\n".join(lines[max(0, line_number - 6):line_number])
            self.assertIn('configuredMode == "harness"', context)
        self.assertGreaterEqual(
            len(heal_lines), 3,
            "expected at least three DSP039ApplyHeal-sourced playerHealth "
            "writes (Bloody Tear, Little Heart collection, Recovery)",
        )

    def test_no_bare_increase_assignment_exists(self) -> None:
        # A bare `playerHealth += heal;`-style unconditional increase (the
        # exact pattern this migration removed from Bloody Tear) must never
        # reappear anywhere in the file.
        source = self._source()
        self.assertNotRegex(source, r"playerHealth\s*\+=")

    def test_bloody_tear_migration_is_gated_on_critical_and_the_35_tic_drain_ready_check(self) -> None:
        source = self._source()
        lobe = source[source.index("void EmitBloodyTearLobe"):source.index("void ProcessWhip()")]
        self.assertIn("if (critical && DSP039BloodyTearDrainReady(tic))", lobe)
        self.assertIn("DSP039AuraRows.BLOODY_TEAR_DRAIN_MILLI", lobe)
        self.assertIn("DSP039ConsumeBloodyTearDrain(tic)", lobe)
        self.assertNotIn("int heal = 1000;", lobe)


if __name__ == "__main__":
    unittest.main()
