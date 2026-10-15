"""Run the N2 evolution-evidence soak on MAP16.

Boots the manual-route controller (ds_p030_mode soak_n2) with the labelled,
fixture-only ds_n2_evolve_fixture=1 cvar set (N2_EVOLUTION_EVIDENCE_FIXTURE):
this grants every recipe's inputs through the real AcquireWeapon/
SetWeaponRank dispatcher and the real DSP031Acquire draft/inventory
authority (VerticalSlice.zs N2MaintainEvolutionFixture), in weapon batches
of at most 6 concurrently-owned custom weapons, so the real interim-chest
cadence (N2MaintainChestCadence/N2OpenInterimChest) applies every one of the
36 recipes (1, 201-205, 301-311, N3 401-419) exactly once through an actual chest
pickup/open. This is the deliverable-2 evidence for N2's evolution/chest
route, not the generic weapon-dispatcher soak (that is
tools/run_n2_dispatch.py's narrow scope).
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

# recipe id -> (input systems that must stop emitting new dispatch-rank/
# dispatch-acquire rows for that system after the recipe's own evolve tic,
# output N2 dispatch system id that must land >=1 accepted hit afterwards).
# Recipe 1 (Whip -> Bloody Tear) and 201/202/203 (paired unions) are not
# routed through EvolveWeapon for a *new* dispatcher system id the way
# 204/205/301-311 are (see N2OpenInterimChest: inputA == WHIP skips
# EvolveWeapon; the paired unions' output ids are new DSP042 system ids that
# EvolveWeapon does reassign in place), so all of them still produce a
# DS_N2_DISPATCH_RANK/ACQUIRE trail through the shared N2 dispatcher engines
# once N2EngineForSystem maps the evolved id.
ALL_RECIPE_IDS = [1, 201, 202, 203, 204, 205,
                   301, 302, 303, 304, 305, 306, 307, 308, 309, 310, 311,
                   # N3 Track A: recipe 402 (Song of Mana + Skull O'Maniac
                   # -> Mannajja), added alongside VerticalSlice.zs's
                   # N2NextEligibleRecipeId/N2MaintainEvolutionFixture
                   # extension for this same recipe.
                   402,
                   # N3 Track A (bounce engine, this worker): 406 (Celestial
                   # Dusting + Chaos Altemanna -> Profusione D'Amore), 417
                   # (Bone + Chaos Malachite -> Anima of Mortaccio), 418
                   # (Cherry Bomb + Chaos Rosalia -> Yatta Daikarin), 419
                   # (Carréllo + Chaos Lazulia -> Carrozza!).
                   406, 417, 418, 419,
                   # The other 14 N3 evolutions: 414 (Magi-Stone -> Kyra-
                   # Stones, ballistic) and 13 generic-engine ones.
                   401, 403, 404, 405, 407, 408, 409, 410, 411, 412, 413,
                   414, 415, 416]

# Output engine (DS_N2_DISPATCH_SUMMARY engine id) each recipe's result
# system belongs to, so we can check for >=1 accepted hit after the recipe's
# evolve tic. Whip/Bloody Tear (recipe 1) and the pure-union outputs
# (201/202/203, which stay on N2_ENGINE_PAIRED like their inputs) still
# report through N2LogDispatchSummary via the paired engine; recipe 1's
# Bloody Tear itself is WHIP-special-cased in N2OpenInterimChest and is
# credited through ProcessWhip's own damage path, not a DS_N2_DISPATCH_*
# row, so it is checked separately (DS_P032_TRANSFORM output=6 accepted).
RECIPE_OUTPUT_SYSTEM = {
    201: 61,   # DSP032_ID_VANDALIER
    202: 64,   # DSP032_ID_PHIERAGGI
    203: 66,   # DSP032_ID_FUWALAFUWALOO
    204: 68,   # DSP032_ID_BI_BRACELET
    205: 69,   # DSP032_ID_TRI_BRACELET
    301: 35, 302: 37, 303: 39, 304: 41, 305: 43, 306: 45,
    307: 47, 308: 49, 309: 51, 310: 53, 311: 55,
    402: 79,   # DSN3Rows.SYSTEM_MANNAJJA
    406: 87,   # DSN3Rows.SYSTEM_PROFUSIONE_DAMORE
    401: 77, 403: 81, 404: 83, 405: 85, 407: 93, 408: 95, 409: 97,
    410: 99, 411: 103, 412: 113, 413: 115,
    414: 117,  # DSN3Rows.SYSTEM_KYRA_STONES
    415: 119, 416: 121,
    417: 123,  # DSN3Rows.SYSTEM_ANIMA_OF_MORTACCIO
    418: 124,  # DSN3Rows.SYSTEM_YATTA_DAIKARIN
    419: 125,  # DSN3Rows.SYSTEM_CARROZZA
}

RECIPE_INPUT_SYSTEM = {
    201: 59, 202: 62, 203: 65, 204: 67, 205: 68,
    301: 34, 302: 36, 303: 38, 304: 40, 305: 42, 306: 44,
    307: 46, 308: 48, 309: 50, 310: 52, 311: 54,
    402: 78,   # DSN3Rows.SYSTEM_SONG_OF_MANA
    406: 86,   # DSN3Rows.SYSTEM_CELESTIAL_DUSTING
    401: 76, 403: 80, 404: 82, 405: 84, 407: 92, 408: 94, 409: 96,
    410: 98, 411: 102, 412: 112, 413: 114,
    414: 116,  # DSN3Rows.SYSTEM_MAGI_STONE
    415: 118, 416: 120,
    417: 56,   # DSP041BounceRows.SYSTEM_BONE
    418: 57,   # DSP041BounceRows.SYSTEM_CHERRY
    419: 58,   # DSP041BounceRows.SYSTEM_CARRELLO
}


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

    # Lead's fixture-handler map-gating fix (2026-09-28): PairedMap28Runtime
    # and BounceMap27Runtime must never boot on MAP16. Any of these markers
    # in a MAP16 log means the evidence is contaminated and must be rerun.
    if re.search(r"DS_P042_MAP28_ROW|DS_P041_MAP27_ROW", log):
        errors.append(
            "log contains DS_P042_MAP28_*/DS_P041_MAP27_* rows: evidence "
            "was contaminated by the unmapgated fixture-handler defect")

    if re.search(r"DS_RUNTIME_ASSERT_FAIL", log):
        errors.append("at least one DS_RUNTIME_ASSERT_FAIL was logged")

    spawns = _rows(log, "DS_N2_INTERIM_CHEST_SPAWN")
    opens = _rows(log, "DS_N2_INTERIM_CHEST_OPEN")
    if not spawns:
        errors.append("no interim chest was ever spawned")
    if not opens:
        errors.append("no interim chest was ever opened (pickup path never fired)")

    # Requirement: each of the 18 recipes applied exactly once via a chest-
    # open marker (DS_P032_TRANSFORM accepted=1 recipe=<id>, tx encodes the
    # chest id that opened it -- N2OpenInterimChest's own tx=chestId*10+1).
    transforms = [r for r in _rows(log, "DS_P032_TRANSFORM") if r.get("accepted") == "1"]
    recipe_apply_count: dict[int, int] = {}
    for row in transforms:
        rid = int(row.get("recipe", "-1"))
        recipe_apply_count[rid] = recipe_apply_count.get(rid, 0) + 1

    for rid in ALL_RECIPE_IDS:
        count = recipe_apply_count.get(rid, 0)
        if count != 1:
            errors.append(f"recipe {rid} applied {count} times via a chest open (expected exactly 1)")

    unexpected_recipes = set(recipe_apply_count) - set(ALL_RECIPE_IDS)
    if unexpected_recipes:
        errors.append(f"unexpected recipe ids applied: {sorted(unexpected_recipes)}")

    # Each chest-open marker must correspond 1:1 to an applied recipe or the
    # documented rank-up fallback (when no recipe was eligible yet); either
    # way, applied=1 with a matching recipe id is required for every open
    # this fixture is expected to drive through a recipe (recipe>0).
    interim_recipe_opens = [r for r in opens if int(r.get("recipe", "0")) > 0]
    for row in interim_recipe_opens:
        if row.get("applied") != "1":
            errors.append(f"an interim chest open for recipe {row.get('recipe')} did not apply (row={row})")

    # Whip -> Bloody Tear (recipe 1) is credited through ProcessWhip's own
    # damage path (WHIP special case in N2OpenInterimChest), not a
    # DS_N2_DISPATCH_* row; require its own accepted hit/erasure evidence
    # instead of the generic per-system check below.
    bloody_tear_owned = any(
        row.get("output") == "6" and row.get("recipe") == "1" for row in transforms)
    if not bloody_tear_owned:
        errors.append("recipe 1 (Whip -> Bloody Tear, output id 6) never landed an accepted transform")

    # Output-system acceptance: after its evolve tic, each recipe's output
    # system must land >=1 accepted DS_N2_DISPATCH_RANK/ACQUIRE-owned hit
    # (DS_N2_DISPATCH_SUMMARY accepted_hits>0 or erased>0), and neither of
    # its two input systems may emit a new DS_N2_DISPATCH_ACQUIRE/RANK row
    # after that tic (already-emitted children -- i.e. rows at or before the
    # evolve tic -- are allowed).
    summary_rows = _rows(log, "DS_N2_DISPATCH_SUMMARY")
    summary_by_system: dict[int, dict[str, str]] = {}
    for row in summary_rows:
        summary_by_system[int(row["system_id"])] = row

    acquire_rows = _rows(log, "DS_N2_DISPATCH_ACQUIRE")
    rank_rows = _rows(log, "DS_N2_DISPATCH_RANK")

    def _tic_of(row: dict[str, str]) -> int:
        try:
            return int(row.get("tic", "-1"))
        except ValueError:
            return -1

    transform_tic_by_recipe: dict[int, int] = {}
    for i, line in enumerate(log.splitlines()):
        if line.startswith("DS_P032_TRANSFORM accepted=1"):
            fields = dict(re.findall(r"([A-Za-z_][A-Za-z0-9_]*)=(\S+)", line))
            rid = int(fields.get("recipe", "-1"))
            # DS_P032_TRANSFORM has no tic field; use the interim-chest-open
            # marker immediately following it (same N2OpenInterimChest call)
            # to recover the tic via the nearest DS_N2_INTERIM_CHEST_OPEN's
            # own position -- fall back to line index as an ordering proxy
            # since only relative ordering (before/after) is required below.
            transform_tic_by_recipe[rid] = i

    # DS_N2_DISPATCH_SUMMARY is a final-state snapshot over currently-owned
    # systems only, so a transient intermediate output (Bi-Bracelet, evolved
    # again into Tri-Bracelet by recipe 205 before the run ends) never gets
    # a row there even though it landed real hits (confirmed by an actual
    # run's own DS_P042_HIT kind=BRACELET system_id=68 rows). Any per-engine
    # "*_HIT ... system_id=<id>" line is direct, stronger evidence of a
    # landed hit than the summary snapshot, so it is checked first; the
    # global-erase engine's own erasure marker carries no system_id, so a
    # generic post-evolve DS_P040_ERASE_ENEMY line is accepted for it.
    # Recipe 1 skips EvolveWeapon (Whip is special-cased) and logs evolved=1.
    # The owned weapon must actually switch form, not just the graph: an
    # applied recipe whose EvolveWeapon was refused (e.g. input and output
    # on different engines) reports dispatch_evolved=0.
    for row in _rows(log, "DS_N2_INTERIM_CHEST_RECIPE"):
        if row.get("dispatch_evolved") != "1":
            errors.append(
                f"recipe {row.get('recipe')}: applied in the graph but the dispatcher "
                f"did not evolve the owned weapon (dispatch_evolved={row.get('dispatch_evolved')})")

    # The generic engine (engine=11) only ticks in shell runs (rsActive), so
    # on this soak route its outputs can't land hits; an accepted dispatcher
    # evolve into the output is the evidence for those.
    generic_evolved = {
        int(row["evolved_system_id"]) for row in _rows(log, "DS_N2_DISPATCH_EVOLVE")
        if row.get("accepted") == "1" and row.get("engine") == "11"}
    hit_line_re = re.compile(r"^DS_P0\d\d_HIT\b")
    for rid, output_system in RECIPE_OUTPUT_SYSTEM.items():
        landed = output_system in generic_evolved or any(
            hit_line_re.match(line) and f"system_id={output_system} " in line + " "
            for line in log.splitlines())
        if not landed:
            row = summary_by_system.get(output_system)
            if row is not None:
                accepted_hits = int(row.get("accepted_hits", "0"))
                erased = int(row.get("erased", "0"))
                landed = accepted_hits > 0 or erased > 0
        # Gorgeous Moon's erase marker carries no system id. (No Future used
        # to share this fallback, which hid recipe 311 never evolving.)
        if not landed and output_system == 53:
            cutoff = transform_tic_by_recipe.get(rid, -1)
            landed = any(
                line.startswith("DS_P040_ERASE_ENEMY accepted=1")
                for line in log.splitlines()[cutoff if cutoff >= 0 else 0:])
        if not landed:
            errors.append(
                f"recipe {rid}: output system {output_system} produced no accepted hit/erasure "
                "(checked per-hit markers, final dispatch summary, and erase-engine fallback)")

    # Input systems must not emit a *new* DS_N2_DISPATCH_ACQUIRE/RANK line
    # after the recipe's own transform line (already-emitted children -
    # i.e. rows before that point in the log - are allowed).
    log_lines = log.splitlines()
    for rid, input_system in RECIPE_INPUT_SYSTEM.items():
        cutoff = transform_tic_by_recipe.get(rid)
        if cutoff is None:
            continue
        for i, line in enumerate(log_lines):
            if i <= cutoff:
                continue
            if not (line.startswith("DS_N2_DISPATCH_ACQUIRE") or line.startswith("DS_N2_DISPATCH_RANK")):
                continue
            fields = dict(re.findall(r"([A-Za-z_][A-Za-z0-9_]*)=(\S+)", line))
            if int(fields.get("system_id", "-1")) == input_system and fields.get("accepted") == "1":
                errors.append(
                    f"recipe {rid}: consumed input system {input_system} emitted a new "
                    f"accepted dispatch row after its evolve point: {line}")

    # Unions (201, 202, 203) free exactly one slot: two inputs removed, one
    # output inserted. DSP032InventoryHash rows aren't logged per-slot, so
    # this is checked structurally against DS_P032_TRANSFORM's own kind=2
    # (DSP032_KIND_UNION) marker plus input_a/input_b both present.
    union_rows = [r for r in transforms if r.get("recipe") in ("201", "202", "203")]
    for row in union_rows:
        if row.get("kind") != "2":
            errors.append(f"union recipe {row.get('recipe')} did not report kind=2 (DSP032_KIND_UNION): {row}")
        if row.get("input_a", "0") == "0" or row.get("input_b", "0") == "0":
            errors.append(f"union recipe {row.get('recipe')} missing an input id: {row}")

    results = _rows(log, "DS_P030_COMPLETE")
    if len(results) != 1:
        errors.append("run did not reach a completed results screen (DS_P030_COMPLETE)")

    if not captures or not any(bool(row.get("nonblank")) for row in captures):
        errors.append("run produced no nonblank capture")

    return {
        "status": "PASS" if not errors else "FAIL",
        "errors": errors,
        "recipe_apply_count": recipe_apply_count,
        "runtime_status": runtime_status,
    }


def run_full(package: Path, seconds: float) -> dict[str, object]:
    package = package.resolve()
    package_sha = hashlib.sha256(package.read_bytes()).hexdigest()
    started = run(
        package, seconds, False, False, "P900", map_name="MAP16",
        completion_marker="DS_P030_COMPLETE",
        startup_commands=[
            "+set", "ds_p030_mode", "soak_n2",
            "+set", "ds_n2_evolve_fixture", "1",
            "+set", "ds_p030_duration_tics", "10500",
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
        "classification": "N2_EVOLUTION_EVIDENCE_FIXTURE",
        "package": str(package),
        "package_sha256": package_sha,
        "engine_sha256": started.get("engine_sha256"),
        "run_status": started.get("status"),
        "captures": started.get("captures", []),
        "evidence": str(evidence),
        "build_performed": False,
    }
    (evidence / "n2-evolution-validation.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, default=ROOT / "build/doom-survivors.ipk3")
    parser.add_argument("--seconds", type=float, default=500.0)
    args = parser.parse_args()
    # 10500 tics at the nominal 35 tics/sec is 300s of *logical* time; the
    # 22 chest-open cycles (spaced 105 tics apart under ds_n2_evolve_fixture:
    # the original 18 -- 1/201-205/301-311/N3's 402 -- plus this worker's
    # four bounce-engine recipes 406/417/418/419) only need ~66s of that
    # logical budget. The real-time cap below is wall-clock, not logical
    # tics: this worker's fourth weapon batch (Bone/Cherry Bomb/Carréllo/
    # Celestial Dusting, all at rank 8 simultaneously) measurably increases
    # per-tic simulation cost (more concurrent bounce projectiles), which an
    # actual run showed pushing the prior 480s wall-clock cap into TIMEOUT
    # before DS_P030_COMPLETE, so the cap is raised to keep headroom.
    result = run_full(args.package, min(max(args.seconds, 60.0), 650.0))
    print(json.dumps(result, indent=2), flush=True)
    return 0 if result.get("status") == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
