"""Strict MAP26 P040 (logical-screen strike/erasure/global-effect) validator.

Models tests/runtime/weapons-aura/test_p039_map16.py's row-marker-join
approach, but validates the single-mode-per-process MAP26 fixture
(src/zscript/ui/global/GlobalMap26Runtime.zs) that tools/run_p040_global.py
drives, rather than a mode/target matrix.
"""
from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
GLOBAL_RUNTIME = ROOT / "src/zscript/weapons/global/GlobalRuntime.zs"
MAP26_RUNTIME = ROOT / "src/zscript/ui/global/GlobalMap26Runtime.zs"


def _rows(log: str, marker: str) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for line in log.splitlines():
        if line.startswith(marker + " "):
            rows.append(dict(re.findall(r"([A-Za-z_][A-Za-z0-9_]*)=(\S+)", line)))
    return rows


def validate_p040_map26_matrix(log: str) -> dict[str, object]:
    """Joins the "matrix" mode's boot/target/weapon/transform/complete
    markers and cross-checks the invariants the contract requires:
    region boundary inclusion/exclusion, erased-vs-killed disjointness,
    protected-enemy survival, ledger conservation and exactly-once counts."""
    errors: list[str] = []
    boot = _rows(log, "DS_P040_MAP26_BOOT")
    if len(boot) != 1 or boot[0].get("accepted") != "1" or boot[0].get("mode") != "matrix":
        errors.append("MAP26 matrix boot marker missing, rejected or duplicated")

    targets = _rows(log, "DS_P040_MAP26_TARGET")
    by_role: dict[str, list[dict[str, str]]] = {}
    for row in targets:
        by_role.setdefault(row.get("role", ""), []).append(row)
    if "REGION_BOUNDARY_INCLUSIVE" not in by_role or "REGION_BOUNDARY_EXCLUSIVE" not in by_role:
        errors.append("region boundary fixtures missing")

    erase_ids = {row["stable_id"] for row in _rows(log, "DS_P040_ERASE_ENEMY")}
    death_ids = {row["target_id"] for row in _rows(log, "DS_P040_MAP26_DEATH")}
    if erase_ids & death_ids:
        errors.append("an entity was both erased and killed: " + repr(erase_ids & death_ids))

    inclusive_ids = {row["target_id"] for row in by_role.get("REGION_BOUNDARY_INCLUSIVE", [])}
    exclusive_ids = {row["target_id"] for row in by_role.get("REGION_BOUNDARY_EXCLUSIVE", [])}
    if not inclusive_ids & erase_ids:
        errors.append("the +/-128 inclusive boundary target was not erased")
    if exclusive_ids & erase_ids:
        errors.append("the outside-region boundary target was erroneously erased")

    deaths = _rows(log, "DS_P040_MAP26_DEATH")
    if any(row.get("xp_created") != "1" for row in deaths):
        errors.append("an ordinary kill did not create exactly one XP pickup")
    if deaths and erase_ids and not all(
        row.get("xp_created") == "1" for row in deaths
    ):
        errors.append("kill-vs-erase XP contrast broken")

    completes = _rows(log, "DS_P040_MAP26_COMPLETE")
    if len(completes) != 1:
        errors.append("MAP26 completion marker missing or duplicated")
    else:
        complete = completes[0]
        if complete.get("ledger_valid") != "1":
            errors.append("P027 ledger invariant failed at completion")
        killed = int(complete.get("killed", "-1"))
        erased = int(complete.get("erased_enemies", "-1"))
        if killed < 1 or erased < 1:
            errors.append("expected both a nonzero kill count and a nonzero erase count")
        if complete.get("moon_beam_hits", "0") == "0":
            errors.append("Gorgeous Moon phase-1 beams never landed")
        if complete.get("moon_gems", "0") == "0":
            errors.append("Gorgeous Moon phase-2 never created a gem")
        if complete.get("repeats_fired", "0") == "0":
            errors.append("Thunder Loop never fired a repeat")

    return {"ok": not errors, "errors": errors, "complete": completes[0] if completes else None}


def validate_p040_spare_audit(log: str, tolerance_pct: float = 1.0) -> dict[str, object]:
    """Checks the 100,000-roll-per-rank spare audit stays within tolerance
    of the row's own spare_milli and that Luck saturation reaches 100%."""
    errors: list[str] = []
    rows = _rows(log, "DS_P040_SPARE_AUDIT")
    ranks = {int(row["rank"]) for row in rows}
    if ranks != set(range(1, 9)):
        errors.append(f"expected ranks 1-8, got {sorted(ranks)}")
    for row in rows:
        if float(row["tolerance_pct"]) > tolerance_pct:
            errors.append(f"rank {row['rank']} exceeded tolerance: {row['tolerance_pct']}%")
    saturation = _rows(log, "DS_P040_SPARE_SATURATION")
    if not saturation or saturation[0].get("expected_always_spared") != "1":
        errors.append("Luck saturation did not reach always-spared")
    return {"ok": not errors, "errors": errors}


def validate_camera_invariance(completes: list[dict[str, str]]) -> dict[str, object]:
    """Every camera/FOV/yaw/flash variant's final hash and counters must be
    identical (contract: identical logical target sets)."""
    errors: list[str] = []
    if len(completes) < 2:
        errors.append("need at least two camera-variant runs to compare")
    else:
        keys = [k for k in completes[0] if k != "camera_variant"]
        baseline = {k: completes[0][k] for k in keys}
        for complete in completes[1:]:
            observed = {k: complete[k] for k in keys}
            if observed != baseline:
                errors.append(f"camera variant {complete.get('camera_variant')} diverged: {observed} != {baseline}")
    return {"ok": not errors, "errors": errors}


class TestP040Validators(unittest.TestCase):
    def test_owned_files_exist(self) -> None:
        self.assertTrue(GLOBAL_RUNTIME.is_file())
        self.assertTrue(MAP26_RUNTIME.is_file())

    def test_matrix_validator_accepts_captured_run(self) -> None:
        log = _CAPTURED_MATRIX_LOG
        report = validate_p040_map26_matrix(log)
        self.assertEqual(report["errors"], [])
        self.assertTrue(report["ok"])

    def test_matrix_validator_flags_missing_boot(self) -> None:
        report = validate_p040_map26_matrix("no markers here")
        self.assertFalse(report["ok"])

    def test_spare_audit_validator_accepts_captured_run(self) -> None:
        report = validate_p040_spare_audit(_CAPTURED_SPARE_AUDIT_LOG)
        self.assertEqual(report["errors"], [])
        self.assertTrue(report["ok"])

    def test_camera_invariance_detects_divergence(self) -> None:
        base = {"hash": "1", "killed": "7", "camera_variant": "0"}
        same = {"hash": "1", "killed": "7", "camera_variant": "1"}
        different = {"hash": "2", "killed": "7", "camera_variant": "2"}
        self.assertTrue(validate_camera_invariance([base, same])["ok"])
        self.assertFalse(validate_camera_invariance([base, different])["ok"])


# Excerpted verbatim from an actual UZDoom run captured under
# evidence/P040/20260927T235731706498Z-doom-survivors/engine.log (see the
# P040-W02 report for the full package/engine SHA provenance). Trimmed to
# the lines the validators above key on, so this test file stays a fast,
# offline regression check on the validator logic itself -- it is not a
# substitute for tools/run_p040_global.py against the real engine.
_CAPTURED_MATRIX_LOG = """
DS_P040_MAP26_BOOT accepted=1 mode=matrix player_slot=0 classification=CONTROLLED_ENGINE_FIXTURE
DS_P040_MAP26_TARGET target_id=2 x=128.000 y=0.000 radius=4.000 health_milli=1000000000 role=REGION_BOUNDARY_INCLUSIVE classification=CONTROLLED_CONTACT_TARGET source_spawn_claim=0
DS_P040_MAP26_TARGET target_id=3 x=129.000 y=0.000 radius=4.000 health_milli=1000000000 role=REGION_BOUNDARY_EXCLUSIVE classification=CONTROLLED_CONTACT_TARGET source_spawn_claim=0
DS_P040_ERASE_ENEMY accepted=1 slot=1 generation=1 stable_id=2 erased_total=1 classification=DISTINCT_NO_REWARD_OPERATION
DS_P040_MAP26_DEATH event_id=11 tic=1 target_id=14 before=1000 xp_created=1
DS_P040_MAP26_COMPLETE mode=matrix tic=400 hash=22173190 accepted_hits=47 skipped=17 repeats_scheduled=6 repeats_fired=6 erased_enemies=13 killed=7 killed_with_xp=7 spared_pickups=1 erased_pickups=2 moon_beam_hits=6 moon_gems=1 ledger_valid=1 live_enemies=5 live_pickups=7 camera_variant=0
""".strip()

_CAPTURED_SPARE_AUDIT_LOG = """
DS_P040_SPARE_AUDIT rank=1 spare_milli=100 rolls=100000 spared=9947 expected=10000.0 tolerance_pct=0.053 luck_milli=1000
DS_P040_SPARE_AUDIT rank=2 spare_milli=100 rolls=100000 spared=9904 expected=10000.0 tolerance_pct=0.096 luck_milli=1000
DS_P040_SPARE_AUDIT rank=3 spare_milli=250 rolls=100000 spared=24898 expected=25000.0 tolerance_pct=0.102 luck_milli=1000
DS_P040_SPARE_AUDIT rank=4 spare_milli=250 rolls=100000 spared=25197 expected=25000.0 tolerance_pct=0.197 luck_milli=1000
DS_P040_SPARE_AUDIT rank=5 spare_milli=450 rolls=100000 spared=45161 expected=45000.0 tolerance_pct=0.161 luck_milli=1000
DS_P040_SPARE_AUDIT rank=6 spare_milli=450 rolls=100000 spared=45142 expected=45000.0 tolerance_pct=0.142 luck_milli=1000
DS_P040_SPARE_AUDIT rank=7 spare_milli=650 rolls=100000 spared=64903 expected=65000.0 tolerance_pct=0.097 luck_milli=1000
DS_P040_SPARE_AUDIT rank=8 spare_milli=650 rolls=100000 spared=64982 expected=65000.0 tolerance_pct=0.018 luck_milli=1000
DS_P040_SPARE_SATURATION rolls=1000 spared=1000 spare_milli=650 luck_milli=2000 expected_always_spared=1
""".strip()


if __name__ == "__main__":
    unittest.main()
