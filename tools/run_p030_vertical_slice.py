"""Build, run, and independently validate the P030 MAP16 vertical slice.

The validator consumes the production handler's canonical DS_P030 rows.  A
completion marker, a screenshot, or a claimed elapsed time cannot pass on its
own.  Accelerated harness runs are only for deterministic automated gates; the
manual launcher leaves the normal one-tic-per-world-tic route active.
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

MAP_SPEC = ROOT / "maps/source/p030-vertical-slice/room.json"
MAP_NAME = "MAP16"
COMPLETE = "DS_P030_COMPLETE"
SUPPORTED_DURATIONS = (2100, 10500)


def flat(log: str) -> str:
    return re.sub(r"\s+", " ", log)


def fields(body: str) -> dict[str, str]:
    return {k: v for k, v in re.findall(r"([A-Za-z_][A-Za-z0-9_]*)=([^\s]+)", body)}


def rows(log: str, kind: str) -> list[dict[str, str]]:
    text = flat(log)
    pattern = re.compile(rf"DS_P030_{re.escape(kind)}\s+(.*?)(?=DS_[A-Za-z0-9_]+|$)")
    return [fields(m.group(1)) for m in pattern.finditer(text)]


def integer(row: dict[str, str], key: str, default: int = -1) -> int:
    try:
        return int(row.get(key, str(default)))
    except (TypeError, ValueError):
        return default


def _ordered_pairs(log: str) -> list[tuple[str, str]]:
    return [(row.get("from", ""), row.get("to", "")) for row in rows(log, "TRANSITION")]


def _remove_rows(log: str, kind: str) -> str:
    """Remove an entire canonical stream for a fail-closed mutation check."""
    return re.sub(
        rf"DS_P030_{re.escape(kind)}\b.*?(?=DS_[A-Za-z0-9_]+|$)",
        "",
        log,
        flags=re.DOTALL,
    )


def validate(log: str, *, require_complete: bool = True, accelerated: bool | None = None,
             expected_duration: int = 10500) -> dict[str, Any]:
    """Validate production MAP16 rows and fail closed on marker-only output."""
    text = flat(log)
    errors: list[str] = []
    if expected_duration not in SUPPORTED_DURATIONS:
        errors.append(f"unsupported expected duration: {expected_duration}")
        expected_duration = 10500
    expected_seconds = expected_duration // 35
    required = (
        "DS_BOOT map=MAP16",
        "DS_P030_BOOT map=MAP16 ticrate=35 stage=FOREST enemy=BAT3",
        f"DS_P030_RULES duration_tics={expected_duration} duration_seconds={expected_seconds}",
        "DS_P030_NATIVE_GUARD pawn=LIVE_VESSEL native_damage=DISABLED native_death=DISABLED native_respawn=DISABLED map_exit=DISABLED",
    )
    for marker in required:
        if marker not in text:
            errors.append(f"missing required marker: {marker}")
    if not re.search(r"DS_P030_RUN_START run_id=1 generation=\d+ stage=FOREST starter=ANTONIO_WHIP clock=0", text):
        errors.append("missing canonical level-one Antonio/Whip run start")
    if re.search(r"VM execution aborted|Script error|Unknown identifier|Execution could not continue|Fatal error", text, re.I):
        errors.append("engine reported a script/runtime failure")
    if "DS_RUNTIME_ASSERT_FAIL" in text:
        errors.append("engine reported a runtime assertion failure")
    if re.search(r"native_(?:damage|death|respawn|fire)=ENABLED|native_los=ENABLED", text, re.I):
        errors.append("native gameplay ownership was enabled")

    cameras = rows(log, "CAMERA")
    proofs = rows(log, "BASIS_PROOF")
    if len(cameras) != 1:
        errors.append(f"expected one published camera row, observed {len(cameras)}")
    if accelerated is True:
        if len(proofs) != 1:
            errors.append(f"expected one production basis proof, observed {len(proofs)}")
        else:
            proof = proofs[0]
            checked = integer(proof, "checked_damage")
            if integer(proof, "rank") != 2 or integer(proof, "amount") != 2 or checked <= 0:
                errors.append("basis proof did not exercise the rank-two front/rear Whip")
            for direction in ("front", "rear"):
                if (integer(proof, f"{direction}_eligible") != 1
                        or integer(proof, f"{direction}_accepted") != 1
                        or integer(proof, f"{direction}_damage") != checked):
                    errors.append(f"basis proof {direction} lobe was not accepted exactly once")
            for key in ("side_front_eligible", "side_front_accepted", "side_rear_eligible", "side_rear_accepted", "side_damage"):
                if integer(proof, key) != 0:
                    errors.append("basis proof admitted the side negative")
                    break
            if proof.get("query_source") != "P024" or proof.get("damage_source") != "P025":
                errors.append("basis proof bypassed a shared production system")

    transitions = _ordered_pairs(log)
    if not transitions or transitions[0] != ("STARTING", "ACTIVE"):
        errors.append(f"run did not start through the MAP16 state machine: {transitions[:1]!r}")
    if ("ACTIVE", "PAUSED_LEVELUP") not in transitions or ("PAUSED_LEVELUP", "ACTIVE") not in transitions:
        errors.append("a real level-up pause/resume boundary is missing")
    if ("ACTIVE", "ENDING") not in transitions or ("ENDING", "RESULTS") not in transitions:
        errors.append("run end/results boundary is missing")

    spawns = rows(log, "SPAWN")
    if len(spawns) < 3:
        errors.append("spawn ledger is missing opening-wave rows")
    previous_event = 0
    for row in spawns:
        event_id = integer(row, "event_id")
        if event_id != previous_event + 1:
            errors.append("spawn event IDs are not contiguous")
            break
        previous_event = event_id
        if row.get("kind") != "BAT3" or row.get("rng_stream") != "spawn":
            errors.append("spawn row is not the qualified BAT3 spawn stream")
        minute = integer(row, "minute")
        cap = integer(row, "cap")
        expected_cap = 15 if minute == 0 else 30 if minute == 1 else 50
        if cap != expected_cap:
            errors.append(f"spawn cap {cap} does not match minute {minute}")
        if row.get("admitted") == "1" and integer(row, "slot") < 0:
            errors.append("admitted spawn has no logical slot")
    if spawns and not all(integer(spawns[i], "tic") <= integer(spawns[i + 1], "tic") for i in range(len(spawns) - 1)):
        errors.append("spawn tics are not monotonic")
    spawn_tics = {minute: [integer(row, "tic") for row in spawns if integer(row, "minute") == minute]
                  for minute in (0, 1, 2)}
    if spawn_tics[0] != list(range(70, 2100, 70)):
        errors.append("minute-zero spawn deadlines do not match the frozen two-second schedule")
    if expected_duration == 10500:
        if not spawn_tics[1] or spawn_tics[1][0] != 2153 or spawn_tics[1][-1] != 4148 or any(
                delta not in (52, 53) for delta in (b - a for a, b in zip(spawn_tics[1], spawn_tics[1][1:]))):
            errors.append("minute-one spawn deadlines do not match the frozen three-halves-second schedule")
        if spawn_tics[2] != list(range(4235, 10501, 35)):
            errors.append("minute-two spawn deadlines do not match the frozen one-second schedule")
    elif spawn_tics[1] or spawn_tics[2]:
        errors.append("one-minute run emitted spawn rows beyond its selected duration")
    admitted = [row for row in spawns if row.get("admitted") == "1"]
    spawn_ids = [integer(row, "stable_id") for row in admitted]
    if len(spawn_ids) != len(set(spawn_ids)) or any(stable <= 0 for stable in spawn_ids):
        errors.append("admitted spawn identities are missing or reused")

    whips = rows(log, "WHIP")
    hits = rows(log, "HIT")
    deaths = rows(log, "DEATH")
    xp_creates = rows(log, "XP_CREATE")
    xp_collects = rows(log, "XP_COLLECT")
    if not whips or not any(row.get("automatic") == "1" and row.get("concurrent") == "1" for row in whips):
        errors.append("automatic concurrent Whip stream is missing")
    if not hits or not deaths:
        errors.append("canonical hit/death transactions are missing")
    if len(xp_creates) != len(deaths):
        errors.append("XP creation does not cover each accepted death")
    if not xp_collects:
        errors.append("foot pickup collection is missing")
    if not rows(log, "LEVELUP_OPEN") or not rows(log, "LEVELUP_CHOICE") or not rows(log, "LEVELUP_RESUME"):
        errors.append("modal level-up choice stream is incomplete")
    if rows(log, "LEVELUP_CHOICE") and not all(row.get("accepted") == "1" for row in rows(log, "LEVELUP_CHOICE")):
        errors.append("level-up choice was not accepted through the play authority")
    accepted_hits = [row for row in hits if row.get("accepted") == "1"]
    applied_damage = sum(max(0, integer(row, "before") - integer(row, "after")) for row in accepted_hits)
    death_ids = [integer(row, "target_id") for row in deaths if row.get("accepted") == "1"]
    if len(death_ids) != len(set(death_ids)) or any(stable <= 0 for stable in death_ids):
        errors.append("death ledger contains a missing or duplicate full identity")
    if any(integer(row, "value") != 1000 for row in xp_creates):
        errors.append("death-created XP does not use the frozen 1,000-milliunit value")
    collected_xp = sum(integer(row, "value", 0) for row in xp_collects)

    results = rows(log, "RESULTS")
    complete = rows(log, "COMPLETE")
    if not results:
        errors.append("results ledger is missing")
    elif len(results) != 1:
        errors.append(f"expected one results ledger, observed {len(results)}")
    else:
        result_row = results[0]
        if integer(result_row, "kills") != len(death_ids):
            errors.append("results kills do not reconcile with accepted deaths")
        if integer(result_row, "damage") != applied_damage:
            errors.append("results damage does not reconcile with accepted hit transitions")
        if integer(result_row, "collected_xp") != collected_xp:
            errors.append("results XP does not reconcile with collection transactions")
        if integer(result_row, "earned_currency") != len(death_ids):
            errors.append("results currency does not reconcile with the declared one-per-kill policy")
    if require_complete:
        if len(complete) != 1:
            errors.append(f"expected one completion row, observed {len(complete)}")
        else:
            row = complete[0]
            if row.get("state") != "RESULTS" or integer(row, "tics") != expected_duration:
                errors.append(f"completion did not reach exactly {expected_duration} source tics")
            if row.get("native_damage") != "DISABLED" or row.get("native_fire") != "DISABLED":
                errors.append("completion row admits native gameplay ownership")
            peak_whip_proxies = integer(row, "peak_whip_proxies", -1)
            whip_proxy_limit = integer(row, "whip_proxy_limit", -1)
            if whip_proxy_limit != 2 or peak_whip_proxies < 1 or peak_whip_proxies > whip_proxy_limit:
                errors.append("Whip presentation proxies were not bounded to the declared live limit")
            if accelerated is True and row.get("logical_accelerated") != "1":
                errors.append("accelerated harness run was not labeled")
            if accelerated is False and row.get("logical_accelerated") != "0":
                errors.append("normal-speed run was not labeled")
            if results:
                for key in ("kills", "damage", "collected_xp", "earned_currency", "level"):
                    if integer(row, key) != integer(results[0], key):
                        errors.append(f"completion {key} does not match the results ledger")
    teardowns = rows(log, "TEARDOWN")
    if not teardowns or any(row.get(key) != "0" for row in teardowns for key in ("entities", "enemies", "pickups", "pending_attacks", "statuses", "menu_focus", "input_latch", "timers")):
        errors.append("teardown retained canonical state")
    if teardowns and any(row.get("rng_streams_cleared") != "1" for row in teardowns):
        errors.append("teardown did not clear named RNG streams")

    return {
        "status": "PASS" if not errors else "FAIL",
        "errors": errors,
        "spawn_count": len(spawns),
        "whip_count": len(whips),
        "hit_count": len(hits),
        "death_count": len(deaths),
        "xp_create_count": len(xp_creates),
        "xp_collect_count": len(xp_collects),
        "levelup_count": len(rows(log, "LEVELUP_OPEN")),
        "transitions": transitions,
        "results": results,
        "complete": complete,
        "cameras": cameras,
        "basis_proofs": proofs,
    }


NEGATIVE_MUTATIONS = {
    "marker_only": lambda log: "DS_BOOT map=MAP16 DS_P030_COMPLETE tics=10500 state=RESULTS",
    "native_damage": lambda log: log.replace("native_damage=DISABLED", "native_damage=ENABLED", 1),
    "wrong_duration": lambda log: log.replace("duration_tics=10500", "duration_tics=10499", 1),
    "missing_spawn": lambda log: _remove_rows(log, "SPAWN"),
    "missing_hit": lambda log: _remove_rows(log, "HIT"),
    "missing_levelup": lambda log: _remove_rows(log, "LEVELUP_OPEN"),
    "wrong_completion_tic": lambda log: log.replace("DS_P030_COMPLETE tics=10500", "DS_P030_COMPLETE tics=10499", 1),
    "dirty_teardown": lambda log: re.sub(r"(DS_P030_TEARDOWN[^\n]*entities=)0", r"\g<1>1", log, count=1),
}


def validate_negative_mutations(log: str) -> dict[str, str]:
    return {name: validate(mutate(log))["status"] for name, mutate in NEGATIVE_MUTATIONS.items()}


def _run_once(package: Path, *, seconds: float, speed: int, telemetry: int = 1,
              camera_variant: int = 0) -> dict[str, Any]:
    return run(
        package, seconds, False, False, "P030", 60, 1280, 720,
        map_name=MAP_NAME, completion_marker=COMPLETE, active_in_background=True,
        vsync=False, startup_commands=["+con_notifytime", "0", "+set", "ds_p030_mode", "harness", "+set", "ds_p030_speed", str(speed), "+set", "ds_p030_telemetry", str(telemetry), "+set", "ds_p030_camera_variant", str(camera_variant)],
    )


def run_probe(*, package: Path | None = None, seconds: float = 45.0, speed: int = 12, repeat: bool = True) -> dict[str, Any]:
    if not 20.0 <= seconds <= 180.0:
        raise ValueError("seconds must be between 20 and 180")
    if not 1 <= speed <= 50:
        raise ValueError("speed must be between 1 and 50")
    if package is None:
        package = Path(build(ROOT, room_spec=MAP_SPEC)["package"])
    package = Path(package)
    compile_result = run(package, 20.0, True, False, "P030", 60, 1280, 720, map_name=MAP_NAME)
    if compile_result.get("status") != "COMPILE_PASS":
        return {"status": "FAIL", "classification": "P030_PACKAGED_UZDOOM_VERTICAL_SLICE", "errors": ["compile gate failed"], "compile": compile_result}

    runtime_runs = [_run_once(package, seconds=seconds, speed=speed, camera_variant=0)]
    if repeat:
        runtime_runs.append(_run_once(package, seconds=seconds, speed=speed, camera_variant=0))
    runtime_runs.extend([
        _run_once(package, seconds=seconds, speed=speed, camera_variant=1),
        _run_once(package, seconds=seconds, speed=speed, camera_variant=2),
    ])
    errors: list[str] = []
    validations: list[dict[str, Any]] = []
    logs: list[str] = []
    for index, runtime in enumerate(runtime_runs):
        log_path = Path(runtime.get("evidence", "")) / "engine.log"
        log = log_path.read_text(encoding="utf-8", errors="replace") if log_path.exists() else ""
        logs.append(log)
        checked = validate(log, accelerated=True)
        validations.append(checked)
        errors.extend(f"run {index}: {error}" for error in checked["errors"])
        if runtime.get("status") != "RUNTIME_PASS":
            errors.append(f"run {index}: runtime status was {runtime.get('status')}")
        if not runtime.get("captures") or not all(capture.get("nonblank") for capture in runtime.get("captures", [])):
            errors.append(f"run {index}: nonblank MAP16 capture is missing")
        if runtime.get("package_sha256") != compile_result.get("package_sha256"):
            errors.append(f"run {index}: package differs from compile gate")
    if repeat and len(logs) == 2:
        # Compare canonical stream rows only; timestamps, capture names and
        # process noise are intentionally excluded from deterministic replay.
        stream_kinds = ("SPAWN", "WHIP", "HIT", "DEATH", "XP_CREATE", "XP_COLLECT", "LEVELUP_OPEN", "LEVELUP_CHOICE", "RESULTS", "COMPLETE")
        left = [[row for row in rows(logs[0], kind)] for kind in stream_kinds]
        right = [[row for row in rows(logs[1], kind)] for kind in stream_kinds]
        if left != right:
            errors.append("repeat harness changed the canonical MAP16 transaction stream")
    if len(validations) >= 4:
        proof_rows = [validations[index].get("basis_proofs", []) for index in (0, len(validations) - 2, len(validations) - 1)]
        if not all(proof_rows):
            errors.append("camera matrix is missing a basis proof row")
            proof0 = proof1 = proof2 = {}
        else:
            proof0, proof1, proof2 = (proof_rows[0][0], proof_rows[1][0], proof_rows[2][0])
        if integer(proof0, "yaw") == integer(proof1, "yaw"):
            errors.append("camera variant one did not rotate the declared aim yaw")
        if (integer(proof0, "front_id") == integer(proof1, "front_id")
                or integer(proof0, "rear_id") == integer(proof1, "rear_id")):
            errors.append("yaw rotation did not select the rotated world handles")
        invariant_keys = (
            "front_slot", "front_generation", "front_id", "front_x", "front_y",
            "front_eligible", "front_accepted", "front_damage",
            "rear_slot", "rear_generation", "rear_id", "rear_x", "rear_y",
            "rear_eligible", "rear_accepted", "rear_damage",
            "side_slot", "side_generation", "side_id", "side_x", "side_y",
            "side_front_eligible", "side_front_accepted", "side_rear_eligible",
            "side_rear_accepted", "side_damage", "checked_damage",
        )
        if integer(proof0, "yaw") != integer(proof2, "yaw"):
            errors.append("camera variant two changed yaw while testing pitch/FOV invariance")
        if any(proof0.get(key) != proof2.get(key) for key in invariant_keys):
            errors.append("pitch/FOV-only variant changed production lobe identities or damage")
    negatives = validate_negative_mutations(logs[0]) if logs else {}
    if any(status != "FAIL" for status in negatives.values()):
        errors.extend(f"negative mutation {name} was accepted" for name, status in negatives.items() if status != "FAIL")
    result = {
        "status": "PASS" if not errors else "FAIL",
        "classification": "P030_PACKAGED_UZDOOM_VERTICAL_SLICE",
        "package": str(package),
        "package_sha256": hashlib.sha256(package.read_bytes()).hexdigest(),
        "engine_sha256": compile_result.get("engine_sha256"),
        "compile": compile_result,
        "runs": runtime_runs,
        "validations": validations,
        "negative_mutations": negatives,
        "errors": errors,
    }
    evidence = ROOT / "evidence/P030"
    evidence.mkdir(parents=True, exist_ok=True)
    result["evidence"] = str(evidence / "latest-result.json")
    (evidence / "latest-result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2, sort_keys=True))
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path)
    parser.add_argument("--seconds", type=float, default=45.0)
    parser.add_argument("--speed", type=int, default=12)
    parser.add_argument("--no-repeat", action="store_true")
    parser.add_argument("--validate-log", type=Path)
    parser.add_argument("--expected-duration", type=int, choices=SUPPORTED_DURATIONS, default=10500,
                        help="expected source duration in tics when validating an existing log")
    args = parser.parse_args(argv)
    try:
        result = (validate(args.validate_log.read_text(encoding="utf-8", errors="replace"), accelerated=None,
                           expected_duration=args.expected_duration)
                  if args.validate_log else run_probe(package=args.package, seconds=args.seconds, speed=args.speed, repeat=not args.no_repeat))
    except (OSError, ValueError, RuntimeError):
        return 1
    return 0 if result.get("status") == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
