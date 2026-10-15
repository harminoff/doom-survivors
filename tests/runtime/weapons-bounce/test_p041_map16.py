"""Strict MAP16 P041 (ricochet: Runetracer/NO FUTURE, Bone, Cherry Bomb,
Carrello) run and save/reload validators.

Models tests/runtime/weapons-global/test_p040_map16.py's structure and rigor
level for the new opt-in P041 MAP16 route (VerticalSlice.zs
ProcessP041BounceWeapons/TryP041Map16NoFutureTransform/TryP041ContactFixture
and the four-weapon controlled fixture + logical wall).
"""
from __future__ import annotations

import re
import unittest
from collections import defaultdict
from pathlib import Path
from tools import slice_source

ROOT = Path(__file__).resolve().parents[3]
VERTICAL_SLICE = ROOT / "src/zscript/gameplay/VerticalSlice.zs"

SYSTEM_RUNETRACER = 54
SYSTEM_NO_FUTURE = 55
SYSTEM_BONE = 56
SYSTEM_CHERRY = 57
SYSTEM_CARRELLO = 58
ALL_SYSTEMS = (SYSTEM_RUNETRACER, SYSTEM_NO_FUTURE, SYSTEM_BONE,
               SYSTEM_CHERRY, SYSTEM_CARRELLO)
NO_FUTURE_GATE_TICS = 18


def _rows(log: str, marker: str) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for line in log.splitlines():
        if line.startswith(marker + " "):
            rows.append(dict(re.findall(r"([A-Za-z_][A-Za-z0-9_]*)=(\S+)", line)))
    return rows


def validate_p041_map16_runtime(
    log: str, runtime_status: str,
    captures: list[dict[str, object]] | None = None,
) -> dict[str, object]:
    """Join MAP16 bounce hits to the checked-damage authority and result
    credit, confirm the NO FUTURE transform and its player-hit explosion
    gate, boundary bounces, and coexistence with the rest of the automatic
    arsenal."""
    errors: list[str] = []
    boot = _rows(log, "DS_P030_BOOT")
    route = _rows(log, "DS_P041_MAP16_BOOT")
    fixture = _rows(log, "DS_P041_MAP16_FIXTURE")
    transforms = [r for r in _rows(log, "DS_P041_MAP16_TRANSFORM")
                  if r.get("kind") == "NO_FUTURE"]
    if len(boot) != 1 or boot[0].get("map") != "MAP16" or boot[0].get("mode") != "p041":
        errors.append("process did not boot the opt-in P041 MAP16 route")
    if len(route) != 1 or route[0].get("route") != "OPT_IN_P041":
        errors.append("P041 MAP16 route marker is missing or duplicated")
    if len(fixture) != 1:
        errors.append("controlled MAP16 bounce fixture marker is missing or duplicated")
    elif (fixture[0].get("accepted") != "1"
          or fixture[0].get("runetracer_rank") != "8"
          or fixture[0].get("bone_rank") != "8"
          or fixture[0].get("cherry_rank") != "8"
          or fixture[0].get("carrello_rank") != "8"
          or fixture[0].get("source_inventory_claim") != "0"):
        errors.append("MAP16 bounce equipment provenance is invalid")

    transform_tic = -1
    if len(transforms) != 1 or transforms[0].get("accepted") != "1":
        errors.append("Runetracer -> NO FUTURE transform is missing, rejected or duplicated")
    else:
        transform_tic = int(transforms[0].get("tic", "-1"))

    if any(r.get("kind", "").startswith("P041") for r in _rows(log, "DS_RUNTIME_ASSERT_FAIL")):
        pass  # collected generically below
    assert_fails = _rows(log, "DS_RUNTIME_ASSERT_FAIL")
    if assert_fails:
        errors.append(f"runtime asserted {len(assert_fails)} failure(s): "
                       + ", ".join(sorted({r.get('kind', '?') for r in assert_fails})))

    hits_by_tic: dict[int, int] = defaultdict(int)
    accepted_events: set[str] = set()
    direct_hits = [(row, False) for row in _rows(log, "DS_P041_HIT")]
    explosion_hits = [(row, True) for row in _rows(log, "DS_P041_EXPLOSION_HIT")]
    hit_rows = direct_hits + explosion_hits
    kind_to_system = {"CHERRY": SYSTEM_CHERRY, "NO_FUTURE": SYSTEM_NO_FUTURE}
    systems_hit: set[int] = set()
    runetracer_hit_tics: list[int] = []
    no_future_hit_tics: list[int] = []
    for row, is_explosion in hit_rows:
        try:
            event = row["event_id"]
            tic = int(row["tic"])
            system = kind_to_system.get(row.get("kind", ""), -1) if is_explosion \
                else int(row["system_id"])
            before = int(row["health_before"])
            after = int(row["health_after"])
            delta = before - after
            key = event + ":" + row.get("target_id", "")
        except (KeyError, ValueError):
            errors.append("malformed P041 hit row")
            continue
        if system not in ALL_SYSTEMS:
            errors.append(f"P041 hit event {event} has out-of-scope system {system}")
        systems_hit.add(system)
        if system == SYSTEM_RUNETRACER:
            runetracer_hit_tics.append(tic)
        if system == SYSTEM_NO_FUTURE:
            no_future_hit_tics.append(tic)
        if delta < 0:
            errors.append(f"P041 event {event} has negative accepted damage")
        hits_by_tic[tic] += delta
        accepted_events.add(key)

    missing_systems = set(ALL_SYSTEMS) - systems_hit
    if missing_systems:
        errors.append(f"no accepted hit was observed from system(s) {sorted(missing_systems)}")

    if transform_tic >= 0:
        if runetracer_hit_tics and min(runetracer_hit_tics) >= transform_tic:
            errors.append("no Runetracer hit was observed before the NO FUTURE transform")
        if no_future_hit_tics and min(no_future_hit_tics) < transform_tic:
            errors.append("a NO FUTURE hit was observed before its own transform tic")

    bounce_rows = _rows(log, "DS_P041_BOUNCE")
    boundary_bounces = [r for r in bounce_rows if r.get("kind") == "BOUNDARY"]
    if not boundary_bounces:
        errors.append("no boundary bounce was ever observed")

    no_future_explosions = _rows(log, "DS_P041_NO_FUTURE_EXPLOSION")
    accepted_no_future = [r for r in no_future_explosions
                           if int(r.get("live_projectiles", "0")) > 0]
    if not accepted_no_future:
        errors.append("no NO FUTURE player-hit explosion was ever observed")
    else:
        gate_ticks = sorted(int(r["tic"]) for r in accepted_no_future)
        for earlier, later in zip(gate_ticks, gate_ticks[1:]):
            if later - earlier < NO_FUTURE_GATE_TICS:
                errors.append(
                    f"NO FUTURE explosion gate violated: tics {earlier} and {later} "
                    f"are closer than {NO_FUTURE_GATE_TICS} tics")

    contact_fixture = _rows(log, "DS_P041_MAP16_CONTACT_FIXTURE")
    if not contact_fixture or contact_fixture[0].get("accepted") != "1":
        errors.append("the labelled NO FUTURE contact fixture was never spawned")

    credits_by_tic: dict[int, int] = defaultdict(int)
    for row in _rows(log, "DS_P041_MAP16_DAMAGE_CREDIT"):
        try:
            if row.get("authority") != "DSP041_P025_CHECKED_LOGICAL_HITS":
                errors.append("MAP16 P041 result credit names a noncanonical authority")
            credits_by_tic[int(row["tic"])] += int(row["accepted_delta_milli"])
        except (KeyError, ValueError):
            errors.append("malformed MAP16 P041 accepted-damage credit")
    if dict(credits_by_tic) != dict(hits_by_tic):
        errors.append("per-tic P041 P025 accepted bounce damage does not reconcile to MAP16 result credit")

    # Concurrency with the rest of the automatic arsenal already layered
    # under this route (Bloody Tear/Whip, P039 aura, P040 global strikes).
    coexistence = {
        "whip-or-bloody-tear": _rows(log, "DS_P030_WHIP")
            + [r for r in _rows(log, "DS_P032_BLOODY_TEAR_HIT") if r.get("accepted", "1") == "1"],
        "aura": [r for r in _rows(log, "DS_P039_AURA_HIT") if r.get("accepted") == "1"],
        "global strikes": [r for r in _rows(log, "DS_P040_STRIKE_HIT") if r.get("accepted") == "1"],
    }
    for family, rows in coexistence.items():
        if not rows:
            errors.append(f"concurrent MAP16 automatic arsenal has no accepted {family} hit")

    return {
        "status": "PASS" if not errors else "FAIL", "errors": errors,
        "no_future_transform_tic": transform_tic,
        "bounce_hits": len(hit_rows), "boundary_bounces": len(boundary_bounces),
        "no_future_explosions": len(accepted_no_future),
    }


def validate_p041_map16_default(log: str) -> dict[str, object]:
    """The default manual route must be completely untouched by P041."""
    errors: list[str] = []
    boot = _rows(log, "DS_P030_BOOT")
    if len(boot) != 1 or boot[0].get("map") != "MAP16" or boot[0].get("mode") != "manual":
        errors.append("default regression did not boot the P030 manual route")
    for marker in ("DS_P041_MAP16_BOOT", "DS_P041_MAP16_FIXTURE",
                   "DS_P041_MAP16_TRANSFORM", "DS_P041_HIT",
                   "DS_P041_EXPLOSION_HIT", "DS_P041_BOUNCE",
                   "DS_P041_NO_FUTURE_EXPLOSION", "DS_P041_MAP16_DAMAGE_CREDIT",
                   "DS_P041_MAP16_CONTACT_FIXTURE"):
        if _rows(log, marker):
            errors.append(f"default manual route unexpectedly emitted {marker}")
    return {"status": "PASS" if not errors else "FAIL", "errors": errors}


def validate_p041_map16_save_roundtrip(
    save_log: str, restore_log: str,
    save_exit_code: int | None, restore_exit_code: int | None,
) -> dict[str, object]:
    """Extends the shared P038 hash gate with the P041 addition (bounce
    persistence hash), gated on p041_route_enabled, and confirms a live
    bounce hit is observed after restore."""
    errors: list[str] = []
    if save_exit_code != 0 or restore_exit_code != 0:
        errors.append("save/restore engine sessions did not both quit cleanly")
    if "DS_P030_BOOT map=MAP16" not in save_log or "DS_P041_MAP16_BOOT" not in save_log:
        errors.append("save process did not boot the opt-in P041 MAP16 path")
    saved_rows = _rows(save_log, "DS_P041_MAP16_SAVE_STATE")
    restored_rows = _rows(restore_log, "DS_P041_MAP16_RESTORE_STATE")
    if len(saved_rows) != 1 or len(restored_rows) != 1:
        errors.append("save/load did not emit exactly one P041 save and restore state marker")
    saved = saved_rows[0] if len(saved_rows) == 1 else {}
    restored = restored_rows[0] if len(restored_rows) == 1 else {}
    if restored and restored.get("accepted") != "1":
        errors.append("P041 restore was not accepted")
    if saved and restored:
        if restored.get("saved_bounce_hash") != saved.get("bounce_hash"):
            errors.append("restored marker lost the original saved bounce_hash")
        if restored.get("bounce_hash") != restored.get("saved_bounce_hash"):
            errors.append("restored bounce_hash does not equal its saved value (exact-equality gate failed)")
    post_restore_hits = _rows(restore_log, "DS_P041_HIT") + _rows(restore_log, "DS_P041_EXPLOSION_HIT")
    if not post_restore_hits:
        errors.append("no P041 bounce hit was observed after restore")
    assert_fails = _rows(restore_log, "DS_RUNTIME_ASSERT_FAIL") + _rows(save_log, "DS_RUNTIME_ASSERT_FAIL")
    if assert_fails:
        errors.append(f"save/restore session asserted {len(assert_fails)} failure(s)")
    return {"status": "PASS" if not errors else "FAIL", "errors": errors}


class TestP041Map16Validators(unittest.TestCase):
    def test_vertical_slice_has_p041_route(self) -> None:
        text = slice_source.read()
        self.assertIn("p041RouteEnabled", text)
        self.assertIn("mixin DSP041Bounce", text)
        self.assertIn("ProcessP041BounceWeapons", text)
        self.assertIn("DSP041PersistenceHash", text)
        self.assertIn("DSP041NotifyPlayerContactDamage", text)

    def test_default_validator_flags_unexpected_marker(self) -> None:
        log = 'DS_P030_BOOT map=MAP16 mode=manual\nDS_P041_MAP16_BOOT route=OPT_IN_P041\n'
        report = validate_p041_map16_default(log)
        self.assertFalse(report["errors"] == [])

    def test_default_validator_accepts_clean_manual_route(self) -> None:
        log = "DS_P030_BOOT map=MAP16 mode=manual\n"
        report = validate_p041_map16_default(log)
        self.assertEqual(report["status"], "PASS")

    def test_runtime_validator_requires_boot(self) -> None:
        report = validate_p041_map16_runtime("no markers here", "RUNTIME_PASS")
        self.assertFalse(report["status"] == "PASS")


if __name__ == "__main__":
    unittest.main()
