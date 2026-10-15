"""Build, run and independently validate the packaged P025 attack fixture.

The validator reconstructs the bounded scheduler, candidate snapshots, hit
ordering, checked damage, status lifetime and generation cleanup from records
in the UZDoom log.  Presentation and telemetry records are deliberately kept
outside the gameplay digest and are compared separately by ``run_probe``.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.build import build
from tools.run_probe import run

NUMBER = r"-?\d+(?:\.\d+)?"
LINE_RE = re.compile(r"DS_P025_(?P<kind>[A-Z_]+)\s+(?P<body>.*)")
TOKEN_RE = re.compile(r"(?P<key>[a-zA-Z_]+)=(?P<value>\([^)]*\)|\S+)")


def parse_rows(log: str, kind: str) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for match in LINE_RE.finditer(log):
        if match.group("kind") != kind:
            continue
        rows.append({m.group("key"): m.group("value") for m in TOKEN_RE.finditer(match.group("body"))})
    return rows


GAMEPLAY_KINDS = {
    "ARITHMETIC_CHECK", "AIM_TURN", "SCHEDULE", "EMISSION", "CANDIDATE",
    "HIT", "DAMAGE", "DEATH", "STATUS", "STATUS_EXPIRE", "CLEANUP",
    "UPGRADE", "CANCEL", "REPLACE", "REUSE_AFTER_DEATH", "DESPAWN",
    "REUSE", "STALE_HIT", "PAUSE_CHECK",
}


def gameplay_stream(log: str) -> list[tuple[str, tuple[tuple[str, str], ...]]]:
    """Return the ordered gameplay records with presentation-only fields out."""
    stream: list[tuple[str, tuple[tuple[str, str], ...]]] = []
    for match in LINE_RE.finditer(log):
        kind = match.group("kind")
        if kind not in GAMEPLAY_KINDS:
            continue
        fields = tuple(sorted((m.group("key"), m.group("value"))
                              for m in TOKEN_RE.finditer(match.group("body"))))
        stream.append((kind, fields))
    return stream


def _int(row: dict[str, str], key: str) -> int:
    return int(row[key])


def _float(row: dict[str, str], key: str) -> float:
    return float(row[key])


def _errors_common(log: str) -> list[str]:
    return [f"engine failure: {marker}" for marker in
            ("VM execution aborted", "Script error", "Unknown identifier", "Execution could not continue")
            if marker in log]


def expected_schedule() -> dict[tuple[int, int, int], tuple[int, str]]:
    expected: dict[tuple[int, int, int], tuple[int, str]] = {}
    for tic in range(1, 17):
        if tic <= 7:
            expected[(tic, 10, 1)] = (1 if tic in (2, 3, 7) else 0,
                                      "TOP" if tic in (2, 7) else "CHILD" if tic == 3 else "NONE")
        else:
            expected[(tic, 30, 2)] = (1 if tic in (10, 11, 16) else 0,
                                      "TOP" if tic in (10, 16) else "CHILD" if tic == 11 else "NONE")
        expected[(tic, 20, 1)] = (1 if tic in (3, 4, 7, 8, 11, 12, 15, 16) else 0,
                                  "TOP" if tic in (3, 7, 11, 15) else "CHILD" if tic in (4, 8, 12, 16) else "NONE")
    return expected


def expected_emissions() -> list[dict[str, int | str]]:
    rows = [
        (1, 2, 10, 1, "TOP", 0, 5, 0, 5),
        (2, 3, 10, 1, "CHILD", 1, 5, 0, 5),
        (3, 3, 20, 1, "TOP", 0, 4, 0, 4),
        (4, 4, 20, 1, "CHILD", 3, 4, 0, 4),
        (5, 7, 10, 1, "TOP", 0, 5, 3, 8),
        (6, 7, 20, 1, "TOP", 0, 4, 0, 4),
        (7, 8, 20, 1, "CHILD", 6, 4, 0, 4),
        (8, 10, 30, 2, "TOP", 0, 8, 0, 8),
        (9, 11, 30, 2, "CHILD", 8, 8, 0, 8),
        (10, 11, 20, 1, "TOP", 0, 4, 3, 7),
        (11, 12, 20, 1, "CHILD", 10, 4, 3, 7),
        (12, 15, 20, 1, "TOP", 0, 4, 3, 7),
        (13, 16, 30, 2, "TOP", 0, 8, 0, 8),
        (14, 16, 20, 1, "CHILD", 12, 4, 3, 7),
    ]
    return [dict(event_id=e, tic=t, weapon_id=w, generation=g, kind=k, parent=p,
                 base=b, bonus=bo, damage=d) for e, t, w, g, k, p, b, bo, d in rows]


def expected_candidates() -> dict[int, list[tuple[int, int, int]]]:
    # The target snapshot is taken before same-tic transactions are applied.
    return {
        1: [(0, 1, 100), (1, 1, 101), (2, 1, 102)],
        2: [(1, 1, 101), (2, 1, 102)],
        3: [(1, 1, 101), (2, 1, 102)],
        4: [(1, 1, 101)],
        5: [(1, 1, 101), (0, 2, 104)],
        6: [(1, 1, 101), (0, 2, 104)],
        7: [(0, 2, 104)],
        8: [(0, 2, 104)],
        9: [(0, 2, 104)],
        10: [(0, 2, 104)],
        11: [(0, 2, 104)],
        12: [(0, 3, 105)],
        13: [],
        14: [],
    }


def validate(log: str, *, expected_variant: int = 0, expected_effects: int | None = None,
             expected_telemetry: int | None = None) -> dict[str, Any]:
    errors = _errors_common(log)
    if "DS_P025_BOOT map=MAP11 ticrate=35" not in log:
        errors.append("missing MAP11 P025 boot marker")
    for marker in ("scheduler=SOURCE_MODEL", "automatic_weapons=CONCURRENT",
                   "transaction_order=EVENT_ID_THEN_TARGET_STABLE_ID",
                   "broad_phase=DSP024SpatialIndex", "native_damage=0",
                   "status_end=EXCLUSIVE", "status_refresh=MAX"):
        if marker not in log:
            errors.append(f"missing authority/rule marker: {marker}")
    if "DS_P025_ARITHMETIC_CHECK max_value=2000000000 overflow_rejected=1" not in log:
        errors.append("checked arithmetic negative seam is missing")

    defs = parse_rows(log, "WEAPON")
    if len(defs) < 2:
        errors.append("missing two weapon definitions")
    else:
        values = {(int(row.get("weapon_id", "-1")), int(row.get("generation", "-1"))) for row in defs}
        if {(10, 1), (20, 1)} - values:
            errors.append("initial weapon handles are incomplete")
        if defs[0].get("first_fire") == defs[1].get("first_fire"):
            errors.append("weapons do not expose distinct first-fire delays")

    schedule = parse_rows(log, "SCHEDULE")
    expected_sched = expected_schedule()
    observed_sched: dict[tuple[int, int, int], dict[str, str]] = {}
    for row in schedule:
        try:
            key = (_int(row, "tic"), _int(row, "weapon_id"), _int(row, "generation"))
        except (KeyError, ValueError):
            errors.append("malformed scheduler row")
            continue
        if key in observed_sched:
            errors.append(f"duplicate scheduler row {key}")
        observed_sched[key] = row
    if set(observed_sched) != set(expected_sched):
        errors.append("scheduler did not emit exactly one row for every equipped weapon/tic")
    for key, (due, kind) in expected_sched.items():
        row = observed_sched.get(key)
        if row is None:
            continue
        if (_int(row, "due"), row.get("emission_kind")) != (due, kind):
            errors.append(f"scheduler mismatch at {key}: expected {(due, kind)}")
    if not any(_int(row, "tic") == 7 and _int(row, "weapon_id") == 10 and row.get("emission_kind") == "TOP" for row in schedule):
        errors.append("concurrent post-cooldown scheduler emission is missing")

    emissions = parse_rows(log, "EMISSION")
    exp_events = expected_emissions()
    if len(emissions) != len(exp_events):
        errors.append(f"expected {len(exp_events)} emissions, observed {len(emissions)}")
    for row, expected in zip(emissions, exp_events):
        for key, value in (("event_id", expected["event_id"]), ("tic", expected["tic"]),
                           ("weapon_id", expected["weapon_id"]), ("weapon_generation", expected["generation"]),
                           ("kind", expected["kind"]), ("parent_event_id", expected["parent"]),
                           ("damage_base", expected["base"]), ("damage_bonus", expected["bonus"]),
                           ("damage_snapshot", expected["damage"]), ("candidate_count", len(expected_candidates().get(int(expected["event_id"]), []))),
                           ("snapshot", 1)):
            actual = row.get(key)
            if actual is None or (int(actual) if isinstance(value, int) and key != "kind" else actual) != value:
                errors.append(f"emission {expected['event_id']} field {key} mismatch")
                break
        if row.get("aim_basis") != "view_yaw" or row.get("explicit_target_slot") != "-1":
            errors.append(f"emission {expected['event_id']} lacks explicit aim/target snapshot")
        if row.get("owner_slot") != "3" or row.get("owner_generation") != "1" or row.get("owner_id") != "103":
            errors.append(f"emission {expected['event_id']} lacks full owner handle")
    if [int(row.get("event_id", "-1")) for row in emissions] != list(range(1, len(emissions) + 1)):
        errors.append("emission IDs are not monotonic")
    expected_aims = [0, 0, 0, 0, 90000, 90000, 90000, 90000, 90000, 90000, 90000, 90000, 90000, 90000]
    if [int(row.get("aim_yaw_milli", "-1")) for row in emissions] != expected_aims:
        errors.append("emission aim snapshots did not preserve the parent across a view turn")
    if "DS_P025_AIM_TURN tic=4 from_yaw_milli=0 to_yaw_milli=90000" not in log:
        errors.append("view aim turn fixture is missing")

    candidates = parse_rows(log, "CANDIDATE")
    candidate_by_event: dict[int, list[tuple[int, int, int]]] = {}
    for row in candidates:
        try:
            event = _int(row, "event_id")
            value = (_int(row, "target_slot"), _int(row, "target_generation"), _int(row, "target_id"))
            if _int(row, "eligible") != 1 or row.get("reason") != "IN_RANGE" or row.get("broad_phase") != "P024":
                errors.append(f"candidate {event} is not an exact post-P024 record")
            candidate_by_event.setdefault(event, []).append(value)
        except (KeyError, ValueError):
            errors.append("malformed candidate record")
    expected_candidate_rows = expected_candidates()
    if {event: values for event, values in candidate_by_event.items() if values} != {event: values for event, values in expected_candidate_rows.items() if values}:
        errors.append("candidate handle snapshots differ from independent lifecycle oracle")
    for event, values in candidate_by_event.items():
        if values != sorted(values, key=lambda item: item[2]):
            errors.append(f"candidate ordering is not stable-ID order for event {event}")

    hits = parse_rows(log, "HIT")
    damages = parse_rows(log, "DAMAGE")
    statuses = parse_rows(log, "STATUS")
    deaths = parse_rows(log, "DEATH")
    # Reconstruct target health/life, per-event pierce and absolute repeat
    # history from the full candidate snapshots.  This independently predicts
    # every hit and rejects duplicate, reordered or omitted transactions.
    live: dict[tuple[int, int, int], int] = {(0, 1, 100): 5, (1, 1, 101): 10, (2, 1, 102): 6}
    parent_history: dict[tuple[int, tuple[int, int, int]], int] = {}
    expected_hits: list[dict[str, Any]] = []
    expected_damage: list[dict[str, Any]] = []
    expected_status: list[dict[str, Any]] = []
    ordinal = 0
    for event in exp_events:
        event_id = int(event["event_id"])
        tic = int(event["tic"])
        if tic >= 7 and (0, 2, 104) not in live and tic < 12:
            live[(0, 2, 104)] = 50
        if tic >= 12 and (0, 3, 105) not in live:
            live.pop((0, 2, 104), None)
            live[(0, 3, 105)] = 4
            for history_key in list(parent_history):
                if history_key[1] == (0, 2, 104):
                    del parent_history[history_key]
        parent = int(event["parent"]) or event_id
        used = 0
        for candidate_ordinal, target in enumerate(expected_candidates()[event_id]):
            ordinal += 1
            slot, generation, stable_id = target
            key = target
            ready = parent_history.get((parent, key), 0)
            accepted = 0
            reason = "STALE_OR_DEAD"
            if key in live:
                if used >= 2:
                    reason = "PIERCE_EXHAUSTED"
                elif ready > tic:
                    reason = "REHIT_COOLDOWN"
                else:
                    accepted = 1; used += 1; reason = "ACCEPTED"
                    parent_history[(parent, key)] = tic + 2
            expected_hits.append(dict(tic=tic, transaction_ordinal=ordinal, event_id=event_id,
                                      target_slot=slot, target_generation=generation, target_id=stable_id,
                                      candidate_ordinal=candidate_ordinal, accepted=accepted, reason=reason,
                                      pierce_before=used - (1 if accepted else 0), pierce_after=used,
                                      rehit_ready_before=ready, rehit_ready_after=tic + 2 if accepted else ready))
            if accepted:
                amount = int(event["damage"])
                before = live[key]; after = max(0, before - amount)
                live[key] = after
                expected_damage.append(dict(tic=tic, transaction_ordinal=ordinal, event_id=event_id,
                                            target_slot=slot, target_generation=generation, target_id=stable_id,
                                            base_damage=int(event["base"]), upgrade_bonus=int(event["bonus"]),
                                            multiplier_milli=1000, amount=amount, health_before=before, health_after=after))
                if after == 0:
                    del live[key]
                else:
                    expected_status.append(dict(tic=tic, event_id=event_id, target_slot=slot,
                                                target_generation=generation, target_id=stable_id,
                                                accepted=0 if stable_id == 102 else 1,
                                                reason="IMMUNITY" if stable_id == 102 else "APPLIED"))
    if len(hits) != len(expected_hits):
        errors.append(f"expected {len(expected_hits)} hit transactions, observed {len(hits)}")
    for row, expected in zip(hits, expected_hits):
        for key in ("tic", "transaction_ordinal", "event_id", "target_slot", "target_generation", "target_id", "candidate_ordinal", "accepted", "pierce_before", "pierce_after", "rehit_ready_before", "rehit_ready_after"):
            if row.get(key) is None or int(row[key]) != expected[key]:
                errors.append(f"hit transaction mismatch at ordinal {expected['transaction_ordinal']} field {key}")
                break
        if row.get("reason") != expected["reason"]:
            errors.append(f"hit transaction mismatch at ordinal {expected['transaction_ordinal']} reason")
    if [int(r.get("transaction_ordinal", "-1")) for r in hits] != list(range(1, len(hits) + 1)):
        errors.append("hit transaction ordering/ordinals are not contiguous")
    if len(damages) != len(expected_damage):
        errors.append(f"expected {len(expected_damage)} accepted damage records, observed {len(damages)}")
    for row, expected in zip(damages, expected_damage):
        for key in ("tic", "transaction_ordinal", "event_id", "target_slot", "target_generation", "target_id", "base_damage", "upgrade_bonus", "multiplier_milli", "amount", "health_before", "health_after"):
            if row.get(key) is None or int(row[key]) != expected[key]:
                errors.append(f"damage arithmetic mismatch at ordinal {expected['transaction_ordinal']} field {key}")
                break
        if row.get("accepted") != "1" or row.get("arithmetic") != "CHECKED":
            errors.append("damage record is not checked/accepted")

    status_rows = [r for r in statuses if r.get("accepted") == "1"]
    if not any(r.get("reason") == "IMMUNITY" for r in statuses):
        errors.append("status immunity hook is missing")
    if not any(r.get("reason") == "STATUS_WINDOW_CLOSED" for r in statuses):
        errors.append("status window/ownership hook is missing")
    if not any(_int(r, "end_before") > 0 and r.get("refresh") == "max" for r in status_rows):
        errors.append("status refresh with an existing end tic is missing")
    expiry = parse_rows(log, "STATUS_EXPIRE")
    if not expiry or not all(r.get("exclusive") == "1" and r.get("active_after") == "0" for r in expiry):
        errors.append("exclusive status expiry was not emitted")
    if not deaths or not any(_int(r, "tic") == 7 for r in deaths):
        errors.append("target death/later same-tic rejection case is missing")

    cleanups = parse_rows(log, "CLEANUP")
    for row in cleanups:
        if row.get("generation_safe") != "1" or row.get("timer_removed") != "1":
            errors.append("cleanup row is not generation-safe and timer-complete")
    if not any(r.get("kind") == "ATTACK_CANCEL" and r.get("child_removed") == "1" for r in cleanups):
        errors.append("attack cancellation did not clean owned burst children")
    if not any(r.get("kind") == "TARGET_DESPAWN" for r in cleanups):
        errors.append("target despawn cleanup is missing")
    if not parse_rows(log, "REUSE_AFTER_DEATH") or not parse_rows(log, "REUSE"):
        errors.append("death and despawn slot reuse records are incomplete")
    stale = parse_rows(log, "STALE_HIT")
    if not stale or any(r.get("accepted") != "0" or r.get("reason") != "STALE_GENERATION" for r in stale):
        errors.append("stale generation rejection is missing")

    complete_rows = parse_rows(log, "COMPLETE")
    complete = complete_rows[-1] if complete_rows else None
    if complete is None:
        errors.append("missing P025 completion marker")
    else:
        for key, value in (("tics", 16), ("events", 14), ("hits", 11), ("damage", 11), ("deaths", 4), ("camera_variant", expected_variant), ("camera_invariant", "true"), ("pause_invariant", "true"), ("native_damage", 0), ("native_weapon_slot", 0)):
            if complete.get(key) is None or (int(complete[key]) if isinstance(value, int) else complete[key]) != value:
                errors.append(f"completion field {key} mismatch")
        if expected_effects is not None and complete.get("effects") != str(expected_effects):
            errors.append("completion effects mode mismatch")
        if expected_telemetry is not None and complete.get("telemetry") != str(expected_telemetry):
            errors.append("completion telemetry mode mismatch")
    cameras = parse_rows(log, "CAMERA")
    expected_pose = {0: (0, 0, 90), 1: (90, 0, 90), 2: (180, 0, 90), 3: (0, 22, 115)}.get(expected_variant, (0, 0, 90))
    if not cameras or any((int(r.get("yaw", "-1")), int(r.get("pitch", "-1")), int(r.get("fov", "-1"))) != expected_pose for r in cameras):
        errors.append("camera variant changed or omitted presentation pose")
    traces = parse_rows(log, "TRACE")
    if expected_telemetry == 0 and traces:
        errors.append("telemetry-disabled run emitted telemetry trace rows")
    if expected_telemetry == 1 and len(traces) != 16:
        errors.append(f"telemetry-enabled run emitted {len(traces)} trace rows, expected 16")
    canonical = parse_rows(log, "CANONICAL")
    if len(canonical) != 16 or [int(r.get("tic", "-1")) for r in canonical] != list(range(1, 17)):
        errors.append("canonical gameplay hash trace is incomplete or reordered")
    if "DS_P025_PAUSE_CHECK paused_tics=0 backlog=0 schedule_unchanged=1 camera_proxy_invariant=1" not in log:
        errors.append("pause/camera/proxy invariance record is missing")
    proxy = parse_rows(log, "PROXY_RECREATE")
    if not proxy:
        errors.append("visual proxy recreation record is missing")
    return {"status": "PASS" if not errors else "FAIL", "errors": errors,
            "emission_count": len(emissions), "candidate_count": len(candidates),
            "hit_count": len(hits), "damage_count": len(damages),
            "status_count": len(statuses), "expiry_count": len(expiry),
            "canonical_trace": [(int(r["tic"]), int(r["hash"])) for r in canonical if "tic" in r and "hash" in r],
            "gameplay_stream": gameplay_stream(log),
            "completion": complete}


def compare_gameplay(first: dict[str, Any], second: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if first.get("canonical_trace") != second.get("canonical_trace"):
        errors.append("canonical gameplay hash trace changed across presentation modes")
    if first.get("completion", {}).get("events") != second.get("completion", {}).get("events"):
        errors.append("completion event count changed across presentation modes")
    if first.get("gameplay_stream") != second.get("gameplay_stream"):
        errors.append("ordered canonical gameplay event stream changed across presentation modes")
    return errors


def _run_one(package: Path, *, variant: int, effects: int, telemetry: int, seconds: float) -> dict[str, Any]:
    runtime = run(package, seconds, False, False, "P025", 60, 1280, 720,
                  map_name="MAP11", completion_marker="DS_P025_COMPLETE",
                  active_in_background=True, vsync=False,
                  startup_commands=["+set", "ds_p025_camera_variant", str(variant),
                                   "+set", "ds_p025_effects", str(effects),
                                   "+set", "ds_p025_telemetry", str(telemetry)])
    evidence = Path(runtime["evidence"])
    log_path = evidence / "engine.log"
    log = log_path.read_text(encoding="utf-8", errors="replace") if log_path.exists() else ""
    result = validate(log, expected_variant=variant, expected_effects=effects, expected_telemetry=telemetry)
    result.update({"variant": variant, "effects": effects, "telemetry": telemetry,
                   "runtime": runtime, "engine_log": str(log_path),
                   "package_sha256": runtime.get("package_sha256")})
    if runtime.get("status") != "RUNTIME_PASS":
        result["errors"].append(f"runtime status was {runtime.get('status')}")
    if not runtime.get("captures") or not all(item.get("nonblank") for item in runtime["captures"]):
        result["errors"].append("required nonblank framebuffer capture is missing")
    result["status"] = "PASS" if not result["errors"] else "FAIL"
    (evidence / "p025-result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return result


def run_probe(*, package: Path | None = None, seconds: float = 15.0) -> dict[str, Any]:
    if not 10.0 <= seconds <= 120.0:
        raise ValueError("seconds must be between 10 and 120")
    if package is None:
        package = Path(build(ROOT, room_spec=ROOT / "maps/source/p025-attacks/room.json")["package"])
    package = Path(package)
    compile_runtime = run(package, seconds, True, False, "P025", 60, 1280, 720,
                          map_name="MAP11", completion_marker="DS_P025_COMPLETE")
    if compile_runtime["status"] != "COMPILE_PASS":
        return {"status": "FAIL", "classification": "P025_PACKAGED_UZDOOM_ATTACK_RUNTIME",
                "errors": ["compile gate failed"], "compile": compile_runtime}
    compile_sha = compile_runtime["package_sha256"]
    runs = [_run_one(package, variant=0, effects=1, telemetry=1, seconds=seconds),
            _run_one(package, variant=3, effects=1, telemetry=1, seconds=seconds),
            _run_one(package, variant=0, effects=0, telemetry=1, seconds=seconds),
            _run_one(package, variant=0, effects=1, telemetry=0, seconds=seconds),
            _run_one(package, variant=0, effects=1, telemetry=1, seconds=seconds)]
    errors = [f"run {i}: {error}" for i, result in enumerate(runs) for error in result["errors"]]
    if any(result.get("package_sha256") != compile_sha for result in runs):
        errors.append("runtime package differs from compile gate")
    for label, left, right in (("camera", runs[0], runs[1]), ("effects", runs[0], runs[2]), ("telemetry", runs[0], runs[3])):
        errors.extend(f"{label}: {error}" for error in compare_gameplay(left, right))
    errors.extend(f"replay: {error}" for error in compare_gameplay(runs[0], runs[4]))
    result = {"status": "PASS" if not errors else "FAIL",
              "classification": "P025_PACKAGED_UZDOOM_ATTACK_RUNTIME",
              "package": str(package), "package_sha256": hashlib.sha256(package.read_bytes()).hexdigest(),
              "compile": compile_runtime, "runs": runs, "errors": errors}
    evidence_dir = ROOT / "evidence" / "P025"
    evidence_dir.mkdir(parents=True, exist_ok=True)
    result["evidence"] = str(evidence_dir / "latest-result.json")
    (evidence_dir / "latest-result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2, sort_keys=True))
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path)
    parser.add_argument("--seconds", type=float, default=15.0)
    parser.add_argument("--validate-log", type=Path)
    parser.add_argument("--variant", type=int, default=0)
    parser.add_argument("--effects", type=int, default=1)
    parser.add_argument("--telemetry", type=int, default=1)
    args = parser.parse_args(argv)
    try:
        if args.validate_log:
            result = validate(args.validate_log.read_text(encoding="utf-8", errors="replace"),
                              expected_variant=args.variant, expected_effects=args.effects,
                              expected_telemetry=args.telemetry)
        else:
            result = run_probe(package=args.package, seconds=args.seconds)
    except (OSError, ValueError, RuntimeError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    return 0 if result.get("status") == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
