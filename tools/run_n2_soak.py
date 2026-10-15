"""N2 normal-flow soak on MAP16 (docs/contracts/normal-play-integration.md).

Runs the manual-route controller (ds_p030_mode soak_n2) with no grant or
evidence-ring fixtures. The only automation is labelled and recorded:
- N2_DRAFT_BOT answers the real level-up modal through ApplyChoice;
- N2_SOAK_MOVER walks toward the nearest XP pickup through the real P021
  body-movement path;
- N2_XP_ACCELERATION_FIXTURE multiplies collected XP;
- ds_p030_speed runs several logical tics per world tic.
Spawns, XP drops, level curve, draft offers, interim chest cadence and recipes
are the real manual-route systems.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tools.run_probe import run

WHIP = 1
PASSIVE_IDS = {2, 3, 5, 7, 8, 9, 10, 70, 71, 72, 73, 74, 75}
ERASE_SYSTEMS = {52, 53}  # Pentagram, Gorgeous Moon
# No-damage weapons (Clock Lancet freezes, Laurel shields): firing counts.
UTILITY_SYSTEMS = {82, 84}
XP_MULTIPLIER_MILLI = 60000
SPEED = 4
DURATION_TICS = 10500


def _rows(log: str, marker: str) -> list[dict[str, str]]:
    flat = re.sub(r"\s+", " ", log)
    return [dict(re.findall(r"([A-Za-z_][A-Za-z0-9_]*)=(\S+)", m.group(1)))
            for m in re.finditer(rf"{re.escape(marker)}\s+(.*?)(?=\sDS_[A-Z0-9_]+\s|$)", flat)]


def validate(log: str, runtime_status: str, captures: list | None = None) -> dict[str, object]:
    errors: list[str] = []
    if runtime_status != "RUNTIME_PASS":
        errors.append(f"UZDoom run status was {runtime_status}, expected RUNTIME_PASS")
    boot = _rows(log, "DS_P030_BOOT")
    if not boot or boot[0].get("map") != "MAP16" or boot[0].get("mode") != "soak_n2":
        errors.append("process did not boot the soak_n2 MAP16 manual-route controller")
    for forbidden in ("DS_N2_GRANT_ALL_ACQUIRE", "DS_N2_EVOLUTION_FIXTURE", "N2_DISPATCH_EVIDENCE_FIXTURE",
                      "DS_P042_MAP28_", "DS_P041_MAP27_"):
        if forbidden in log:
            errors.append(f"forbidden fixture/foreign-handler marker present: {forbidden}")

    choices = _rows(log, "DS_N2_DRAFT_BOT")
    chosen_ids = [int(r["offer_id"]) for r in choices if r.get("offer_id", "").lstrip("-").isdigit()]
    acquired = sorted({int(r["system_id"]) for r in _rows(log, "DS_N2_DISPATCH_ACQUIRE")
                       if r.get("accepted") == "1"})
    drafted_weapons = sorted({i for i in chosen_ids if i not in PASSIVE_IDS and i in acquired})
    drafted_passives = sorted({i for i in chosen_ids if i in PASSIVE_IDS})
    if len(drafted_weapons) < 5:
        errors.append(f"fewer than 5 base weapons acquired through real draft choices: {drafted_weapons}")
    if not drafted_passives:
        errors.append("no passive was drafted")

    summary = {int(r["system_id"]): r for r in _rows(log, "DS_N2_DISPATCH_SUMMARY")}
    # A weapon that evolves mid-run reports its final hits under the evolved
    # system (e.g. Axe 38 -> Death Spiral 39); follow the evolution chain.
    evolved_into = {int(r["source_system_id"]): int(r["evolved_system_id"])
                    for r in _rows(log, "DS_N2_DISPATCH_EVOLVE") if r.get("accepted") == "1"}
    hits_by_system: dict[int, int] = {}
    for system in acquired:
        final = system
        while final not in summary and final in evolved_into:
            final = evolved_into[final]
        row = summary.get(final)
        if row is None:
            errors.append(f"no DS_N2_DISPATCH_SUMMARY row for acquired system {system}")
            continue
        hits = int(row.get("accepted_hits", "0")) + int(row.get("erased", "0"))
        hits_by_system[system] = hits
        fired = re.search(rf"DS_GW_FIRE tic=\d+ system_id={system} ", log)
        erase_ok = system in ERASE_SYSTEMS and re.search(r"DS_P040_ACTIVATION", log)
        if hits <= 0 and not erase_ok and not (system in UTILITY_SYSTEMS and fired):
            errors.append(f"acquired system {system} produced no accepted hit, erase or activation")
    whip_rows = _rows(log, "DS_P030_WHIP")
    whip_hits = sum(int(r.get("hits", "0")) for r in whip_rows)
    hits_by_system[WHIP] = whip_hits
    # The starter must keep firing automatically. Its hits are recorded but not
    # required: a strong ranged weapon can kill everything before it reaches
    # the Whip's 128-unit strip (observed 2026-09-28: ~0.6 candidates/swing).
    if not whip_rows:
        errors.append("the Whip starter never fired")
    if len(acquired) + 1 < 6:
        errors.append(f"weapon slots not filled: starter + {len(acquired)} acquired")

    spawns = _rows(log, "DS_N2_INTERIM_CHEST_SPAWN")
    opens = _rows(log, "DS_N2_INTERIM_CHEST_OPEN")
    # Mad Forest bosses roll wiki chest chances (the minute-1 and minute-3
    # bosses are 30%/45%), so a 5-minute run may legitimately drop none; it
    # must still kill a boss and roll. Chests that do drop must all open.
    boss_rolls = _rows(log, "DS_MF_BOSS_CHEST")
    if not spawns and not boss_rolls:
        errors.append("no boss chest was rolled or spawned")
    if len(opens) != len(spawns) or any(r.get("applied") != "1" for r in opens):
        errors.append(f"not every interim chest opened with an applied reward: spawns={len(spawns)} opens={len(opens)}")
    evolutions = [r for r in opens if r.get("recipe", "0") != "0"]

    credit_rows = _rows(log, "DS_N2_DISPATCH_DAMAGE_CREDIT")
    prior = 0
    for row in credit_rows:
        delta, total = int(row["accepted_delta_milli"]), int(row["total_milli"])
        if delta <= 0 or total < prior + delta:
            errors.append(f"damage credit ledger inconsistent at tic={row.get('tic')}")
            break
        prior = total
    if "DS_RUNTIME_ASSERT_FAIL" in log:
        errors.append("at least one DS_RUNTIME_ASSERT_FAIL was logged")
    if len(_rows(log, "DS_P030_COMPLETE")) != 1:
        errors.append("run did not reach a completed results screen")
    results = _rows(log, "DS_P030_RESULTS")
    if not captures or not any(bool(c.get("nonblank")) for c in captures):
        errors.append("run produced no nonblank capture")
    return {
        "status": "PASS" if not errors else "FAIL",
        "errors": errors,
        "drafted_weapons": drafted_weapons,
        "drafted_passives": drafted_passives,
        "acquired_systems": acquired,
        "hits_by_system": {str(k): v for k, v in sorted(hits_by_system.items())},
        "interim_chests": len(spawns),
        "evolutions_in_run": [r.get("recipe") for r in evolutions],
        "level_up_choices": len(choices),
        "results": results[0] if results else None,
        "accelerations": {"ds_p030_speed": SPEED, "ds_n2_xp_multiplier_milli": XP_MULTIPLIER_MILLI,
                          "draft_bot": "N2_DRAFT_BOT", "mover": "N2_SOAK_MOVER"},
    }


def run_soak(package: Path, seconds: float) -> dict[str, object]:
    package = package.resolve()
    sha = hashlib.sha256(package.read_bytes()).hexdigest()
    started = run(package, seconds, False, False, "P900", map_name="MAP16",
                  completion_marker="DS_P030_COMPLETE",
                  startup_commands=["+set", "ds_p030_mode", "soak_n2",
                                    "+set", "ds_n2_draft_bot", "1",
                                    "+set", "ds_n2_soak_mover", "1",
                                    "+set", "ds_n2_xp_multiplier_milli", str(XP_MULTIPLIER_MILLI),
                                    "+set", "ds_p030_duration_tics", str(DURATION_TICS),
                                    "+set", "ds_p030_speed", str(SPEED),
                                    "+set", "ds_p030_telemetry", "1"])
    evidence = Path(started["evidence"])
    log = (evidence / "engine.log").read_text(encoding="utf-8", errors="replace")
    report = {**validate(log, str(started.get("status")), started.get("captures", [])),
              "classification": "N2_NORMAL_FLOW_SOAK", "package_sha256": sha,
              "wall_seconds": started.get("elapsed_seconds"), "evidence": str(evidence)}
    if started.get("package_sha256") != sha:
        report["errors"].append("runtime package SHA differs from supplied package")
        report["status"] = "FAIL"
    (evidence / "n2-soak-validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, default=ROOT / "build/doom-survivors.ipk3")
    parser.add_argument("--seconds", type=float, default=180.0)
    args = parser.parse_args()
    report = run_soak(args.package, args.seconds)
    print(json.dumps({k: report[k] for k in ("status", "errors", "drafted_weapons", "hits_by_system",
                                              "interim_chests", "evolutions_in_run", "wall_seconds",
                                              "evidence")}, indent=2))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
