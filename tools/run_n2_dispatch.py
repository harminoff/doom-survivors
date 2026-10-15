"""Run the N2 weapon-dispatcher evidence soak on MAP16.

Boots the manual-route controller (ds_p030_mode soak_n2, same controller code
as manual per docs/contracts/normal-play-integration.md) with the labelled,
fixture-only ds_n2_grant_all=1 cvar set: this grants one of every draftable
base weapon at rank 1 through the real AcquireWeapon dispatcher shortly after
boot, then ranks each up to max through SetWeaponRank over the run. This is
the deliverable-3 evidence for the generic weapon dispatcher
(AcquireWeapon/SetWeaponRank/ProcessOwnedWeapons/...), not a recipe/chest/
full-soak acceptance run (out of this worker's narrow scope).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tools.run_probe import run

# The 19 non-Whip draftable base-weapon systems the fixture grants (mirrors
# VerticalSlice.zs's N2GrantAllSystems -- kept in sync by name, not value,
# since these are the DSP03xWeaponRows.SYSTEM_*/DSN3Rows.SYSTEM_* ids the
# engines themselves define). Whip (system 1) is excluded: it is equipped
# unconditionally at run start through its own pre-existing path, not
# through AcquireWeapon. N3 Track A adds 2 (Magi-Stone, Song of Mana; their
# evolutions Kyra-Stones/Mannajja are evolution-only and are not part of
# this grant-all fixture -- Mannajja is covered by the evolution fixture).
# This worker's bounce-engine wiring adds 5 more: Bone/Cherry Bomb/Carréllo
# (already-implemented P041 rows never previously routed through the N2
# dispatcher or made draftable) plus the two new draftable base weapons
# Celestial Dusting/La Robba. Their own evolutions (Anima of Mortaccio,
# Carrozza!, Profusione D'Amore, Yatta Daikarin) are evolution-only and are
# instead covered by the evolution fixture (recipes 406/417/418/419).
EXPECTED_SYSTEM_COUNT = 24


def _rows(log: str, marker: str) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for line in log.splitlines():
        if line.startswith(marker + " "):
            rows.append(dict(re.findall(r"([A-Za-z_][A-Za-z0-9_]*)=(\S+)", line)))
    return rows


def validate(log: str, runtime_status: str,
             captures: list[dict[str, object]] | None = None) -> dict[str, object]:
    errors: list[str] = []
    boot = _rows(log, "DS_P030_BOOT")
    if len(boot) != 1 or boot[0].get("map") != "MAP16" or boot[0].get("mode") not in (
            "soak_n2", "manual"):
        errors.append("process did not boot the manual/soak_n2 MAP16 route")

    acquire = _rows(log, "DS_N2_GRANT_ALL_ACQUIRE")
    if len(acquire) != 1:
        errors.append("N2_GRANT_ALL_ACQUIRE fixture marker is missing or duplicated")
    elif (acquire[0].get("requested") != str(EXPECTED_SYSTEM_COUNT)
          or acquire[0].get("accepted") != str(EXPECTED_SYSTEM_COUNT)):
        errors.append(
            "not every draftable base weapon was accepted by AcquireWeapon: "
            f"{acquire[0]}")

    # DSP042PairedRows.RankCount(SYSTEM_BRACELET) == 6: the base Bracelet
    # correctly rejects SetWeaponRank past 6 (Bi/Tri-Bracelet evolution is
    # chest/recipe scope, out of this dispatcher-only worker's narrow
    # scope), so the rank-7 and rank-8 fixture passes legitimately accept
    # only 16 of the 17 granted systems -- confirmed by a real run showing
    # DS_N2_DISPATCH_RANK accepted=0 for system 67 (Bracelet) at exactly
    # those two passes and nowhere else.
    rank_rows = _rows(log, "DS_N2_GRANT_ALL_RANK")
    if len(rank_rows) != 7:
        errors.append(f"expected 7 SetWeaponRank passes (ranks 2..8), saw {len(rank_rows)}")
    for row in rank_rows:
        expected = EXPECTED_SYSTEM_COUNT - 1 if row.get("rank") in ("7", "8") else EXPECTED_SYSTEM_COUNT
        if row.get("requested") != str(EXPECTED_SYSTEM_COUNT) or row.get(
                "accepted") != str(expected):
            errors.append(f"a SetWeaponRank pass did not accept the expected system count: {row}")

    dispatch_acquire = [r for r in _rows(log, "DS_N2_DISPATCH_ACQUIRE") if r.get("accepted") == "1"]
    acquired_systems = {int(r["system_id"]) for r in dispatch_acquire}
    if len(acquired_systems) != EXPECTED_SYSTEM_COUNT:
        errors.append(
            f"expected {EXPECTED_SYSTEM_COUNT} distinct accepted AcquireWeapon systems, "
            f"saw {len(acquired_systems)}: {sorted(acquired_systems)}")

    # DSP042PairedRows.RankCount(SYSTEM_BRACELET) == 6: the base Bracelet
    # only ranks to 6 through SetWeaponRank -- reaching 7/8 requires
    # evolving into Bi-Bracelet/Tri-Bracelet (chest/recipe scope, out of
    # this dispatcher-only worker's narrow scope). The fixture's rank-7/8
    # passes correctly get accepted=0 for it; every other system ranks to 8.
    BRACELET_SYSTEM = 67
    dispatch_rank = [r for r in _rows(log, "DS_N2_DISPATCH_RANK") if r.get("accepted") == "1"]
    rank_changes_by_system: dict[int, int] = defaultdict(int)
    for row in dispatch_rank:
        rank_changes_by_system[int(row["system_id"])] += 1
    for system in acquired_systems:
        expected_changes = 5 if system == BRACELET_SYSTEM else 7
        if rank_changes_by_system.get(system, 0) < expected_changes:
            errors.append(
                f"system {system} had fewer than {expected_changes} accepted "
                f"rank changes ({rank_changes_by_system.get(system, 0)})")

    summary = _rows(log, "DS_N2_DISPATCH_SUMMARY")
    summary_by_system = {int(r["system_id"]): r for r in summary}
    for system in acquired_systems:
        row = summary_by_system.get(system)
        if row is None:
            errors.append(f"no DS_N2_DISPATCH_SUMMARY row for system {system}")
            continue
        expected_rank = "6" if system == BRACELET_SYSTEM else "8"
        if row.get("rank") != expected_rank:
            errors.append(f"system {system} did not end at rank {expected_rank}: {row}")
        accepted_hits = int(row.get("accepted_hits", "0"))
        erased = int(row.get("erased", "0"))
        if accepted_hits <= 0 and erased <= 0:
            errors.append(
                f"system {system} (engine {row.get('engine')}) produced no accepted "
                "hit and no erasure through the manual controller")

    totals = _rows(log, "DS_N2_DISPATCH_TOTALS")
    if len(totals) != 1:
        errors.append("DS_N2_DISPATCH_TOTALS marker is missing or duplicated")
    else:
        if int(totals[0].get("owned", "0")) != EXPECTED_SYSTEM_COUNT:
            errors.append("DS_N2_DISPATCH_TOTALS owned count does not match the grant-all fixture")
        if int(totals[0].get("acquire_count", "0")) != EXPECTED_SYSTEM_COUNT:
            errors.append("DS_N2_DISPATCH_TOTALS acquire_count does not match the grant-all fixture")

    # Damage-credit reconciliation. total_milli is the shared damageDealt
    # running total (Whip and every other family credit into the same
    # counter, per the frozen "credited exactly once" accepted-delta
    # pattern), so N2's own rows cannot be summed in isolation to it -- only
    # checked for internal consistency: never negative, and total_milli
    # strictly increases by at least this row's own delta each time (it may
    # increase by more, if Whip or another family credited in between).
    credit_rows = _rows(log, "DS_N2_DISPATCH_DAMAGE_CREDIT")
    prior_total = 0
    for row in credit_rows:
        delta = int(row["accepted_delta_milli"])
        total = int(row["total_milli"])
        if delta <= 0 or total < prior_total + delta:
            errors.append(
                "N2 damage credit ledger is inconsistent at "
                f"tic={row.get('tic')} engine={row.get('engine')}: "
                f"delta={delta} prior_total={prior_total} total={total}")
            break
        prior_total = total
    running_total = prior_total

    if re.search(r"DS_RUNTIME_ASSERT_FAIL", log):
        errors.append("at least one DS_RUNTIME_ASSERT_FAIL was logged")

    results = _rows(log, "DS_P030_COMPLETE")
    if len(results) != 1:
        errors.append("run did not reach a completed results screen (DS_P030_COMPLETE)")

    if not captures or not any(bool(row.get("nonblank")) for row in captures):
        errors.append("run produced no nonblank capture")

    return {
        "status": "PASS" if not errors else "FAIL",
        "errors": errors,
        "acquired_systems": sorted(acquired_systems),
        "acquired_system_count": len(acquired_systems),
        "rank_pass_count": len(rank_rows),
        "damage_credit_row_count": len(credit_rows),
        "final_credited_damage_milli": running_total,
        "runtime_status": runtime_status,
    }


def run_full(package: Path, seconds: float = 80.0) -> dict[str, object]:
    package = package.resolve()
    package_sha = hashlib.sha256(package.read_bytes()).hexdigest()
    started = run(
        # run_probe.run requires evidence_phase to match "P###"; N2 has no
        # numeric phase id, so P900 is used purely as an evidence-directory
        # label (evidence/P900/...) and is not a claim about phase ordering.
        package, seconds, False, False, "P900", map_name="MAP16",
        completion_marker="DS_P030_COMPLETE",
        startup_commands=[
            "+set", "ds_p030_mode", "soak_n2",
            "+set", "ds_n2_grant_all", "1",
            # VerticalSlice.zs's ConfigureDuration() only accepts exactly
            # MIN_SURVIVAL_TICS (2100) or MAX_SURVIVAL_TICS (10500) for this
            # cvar and silently falls back to the 10500-tic default
            # otherwise (confirmed by an actual run that ignored 500 and
            # kept going toward 10500) -- so 2100 is the shortest duration
            # this route will actually honor.
            "+set", "ds_p030_duration_tics", "2100",
            "+set", "ds_p030_speed", "1",
            "+set", "ds_p030_camera_variant", "0",
            "+set", "ds_p030_telemetry", "1",
        ],
    )
    evidence = Path(started["evidence"])
    log = (evidence / "engine.log").read_text(encoding="utf-8", errors="replace")
    validation = validate(log, str(started.get("status", "MISSING")), started.get("captures", []))
    if started.get("package_sha256") != package_sha:
        validation["errors"].append("runtime package SHA differs from supplied package")
        validation["status"] = "FAIL"
    report = {
        **validation,
        "classification": "N2_WEAPON_DISPATCHER_EVIDENCE",
        "package": str(package),
        "package_sha256": package_sha,
        "engine_sha256": started.get("engine_sha256"),
        "run_status": started.get("status"),
        "captures": started.get("captures", []),
        "evidence": str(evidence),
        "build_performed": False,
    }
    (evidence / "n2-dispatch-validation.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, default=ROOT / "build/doom-survivors.ipk3")
    parser.add_argument("--seconds", type=float, default=90.0)
    args = parser.parse_args()
    # N2-W3 perf fix (docs/contracts/normal-play-integration.md "Weapon
    # dispatcher"): DSP024Rebuild() previously ran an O(m^2) insertion sort
    # and ran once per active engine per tic, which made a 17-weapon
    # grant-all run far slower than real time (~7.5x under real time,
    # measured at ~4.7k log lines over 150s -- log volume was not the
    # cause). DSP024Rebuild() now uses an O(m log m) merge sort
    # (src/zscript/core/spatial/SpatialIndex.zs), restoring real-time
    # throughput (see N2-W3's measured per-engine ms/tic). 2100 tics at the
    # nominal 35 tics/sec is 60s; 90s keeps headroom without resurrecting
    # the earlier 550s budget the lead flagged as papering over the real
    # hotspot.
    result = run_full(args.package, min(max(args.seconds, 20.0), 120.0))
    print(json.dumps(result, indent=2), flush=True)
    return 0 if result.get("status") == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
