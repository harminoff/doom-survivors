"""Build and strictly validate the packaged P026 Antonio/Whip runtime.

The engine emits the authoritative logical stream. This runner independently
reconstructs cardinal rectangle/circle eligibility, rational deadlines,
checked milliunit damage, death and XP requests, and presentation invariants.
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

RUN_TICS = 110
EVENT_TICS = (1, 5, 49, 53, 96, 100)
EVENT_LOBES = ("FRONT", "REAR", "FRONT", "REAR", "FRONT", "REAR")


def flat(log: str) -> str:
    return re.sub(r"\s+", " ", log)


def fields(body: str) -> dict[str, str]:
    return {key: value for key, value in re.findall(r"([A-Za-z_][A-Za-z0-9_]*)=([^\s]+)", body)}


def rows(log: str, kind: str) -> list[dict[str, str]]:
    text = flat(log)
    marker = re.compile(rf"DS_P026_{kind}\s+(.*?)(?=\sDS_[A-Z0-9_]+\s|$)")
    return [fields(match.group(1)) for match in marker.finditer(text)]


def ordered_rows(log: str, kinds: tuple[str, ...]) -> list[tuple[int, str, dict[str, str]]]:
    text = flat(log)
    found: list[tuple[int, str, dict[str, str]]] = []
    for kind in kinds:
        marker = re.compile(rf"DS_P026_{kind}\s+(.*?)(?=\sDS_[A-Z0-9_]+\s|$)")
        found.extend((match.start(), kind, fields(match.group(1))) for match in marker.finditer(text))
    found.sort(key=lambda item: item[0])
    return found


def integer(value: str) -> int:
    return int(value)


def exact_rectangle_circle(x: float, y: float, radius: float, yaw: int, lobe: str) -> bool:
    cardinal = yaw % 360
    if cardinal < 45 or cardinal >= 315:
        forward, lateral = x, y
    elif cardinal < 135:
        forward, lateral = y, -x
    elif cardinal < 225:
        forward, lateral = -x, -y
    else:
        forward, lateral = -y, x
    if lobe == "FRONT":
        low, high = 0.0, 128.0
    else:
        low, high = -128.0, 0.0
    closest_forward = min(high, max(low, forward))
    closest_lateral = min(24.0, max(-24.0, lateral))
    return ((forward - closest_forward) ** 2 + (lateral - closest_lateral) ** 2
            <= radius * radius + 1e-9)


def expected_schedule() -> list[dict[str, Any]]:
    """Reconstruct absolute 189/4 and 7/2 deadlines without float drift."""
    result: list[dict[str, Any]] = []
    next_top = 4
    rear_deadline: int | None = None
    event_id = 0
    for tic in range(1, RUN_TICS + 1):
        if 4 * tic >= next_top:
            event_id += 1
            result.append({"event_id": event_id, "tic": tic, "kind": "TOP", "lobe": "FRONT", "parent": 0, "deadline": next_top})
            rear_deadline = 4 * tic + 14
            next_top += 189
        if rear_deadline is not None and 4 * tic >= rear_deadline:
            event_id += 1
            result.append({"event_id": event_id, "tic": tic, "kind": "CHILD", "lobe": "REAR", "parent": event_id - 1, "deadline": rear_deadline})
            rear_deadline = None
    return result


def promoted_records() -> list[str]:
    errors: list[str] = []
    character = ROOT / "data/verified/base/characters/antonio.json"
    weapon = ROOT / "data/verified/base/weapons/whip.json"
    try:
        documents = [json.loads(character.read_text(encoding="utf-8")), json.loads(weapon.read_text(encoding="utf-8"))]
    except (OSError, ValueError) as exc:
        return [f"promoted record load failed: {exc}"]
    for document in documents:
        if document.get("lifecycle") != "PROMOTED_IMMUTABLE":
            errors.append("promoted record lifecycle is not immutable")
        for name, field in document.get("fields", {}).items():
            if field.get("provenance") not in {"BUILD_EXTRACTED", "ONLINE_REPORTED_CURRENT", "ENGINEERING_APPROXIMATION"}:
                errors.append(f"{document.get('id')} field {name} lacks an approved provenance class")
    source = documents[0]["fields"].get("source_identity", {})
    source2 = documents[1]["fields"].get("source_identity", {})
    if source.get("value") != "ANTONIO" or source2.get("value") != "WHIP":
        errors.append("promoted identity values changed")
    expected_sha = "c930da284e079870242b367f809ba737499ec19b8f53c51e9a03d8e082b61ffe"
    if source.get("source_sha256") != expected_sha or source2.get("source_sha256") != expected_sha:
        errors.append("promoted source hash changed")
    progression = documents[1]["fields"].get("level_progression", {}).get("value", [])
    expected_progression = [(1, 10, 1), (2, 10, 2), (3, 15, 2), (4, 20, 2), (5, 25, 2), (6, 30, 2), (7, 35, 2), (8, 40, 2)]
    observed = [(row.get("level"), row.get("damage"), row.get("amount")) for row in progression]
    if observed != expected_progression:
        errors.append("Whip eight-level progression changed")
    return errors


def gameplay_stream(log: str) -> list[str]:
    ordered = ordered_rows(log, ("EMISSION", "CANDIDATE", "HIT", "DAMAGE", "DEATH", "XP_REQUEST", "STALE_HIT"))
    return [kind + ":" + json.dumps({"type": kind, **data}, sort_keys=True, separators=(",", ":")) for _, kind, data in ordered]


def validate(log: str, *, expected_variant: int = 0, expected_effects: int = 1,
             expected_telemetry: int = 1, expected_body: int = 0) -> dict[str, Any]:
    text = flat(log)
    errors = promoted_records()
    if re.search(r"VM execution aborted|Script error|Unknown identifier|Execution could not continue", text):
        errors.append("engine reported a script/runtime failure")
    for marker in (
        "DS_BOOT map=MAP12",
        "DS_P026_BOOT map=MAP12 ticrate=35 scheduler=P025_SOURCE_MODEL automatic_weapons=1 primary_fire_input=0",
        "logical_store=DSP020EntityStore broad_phase=DSP024SpatialIndex snapshots=DSP025AttackSnapshot",
        "damage=P023_CHECKED_MILLIUNITS xp=P023_REQUEST",
        "facing_sample=TOP_LEVEL_EMISSION_VIEW_YAW pitch=presentation_only fov=presentation_only movement=presentation_only",
        "wall_filter=0 repeat_hit=ONE_PER_LOBE geometry=ORIENTED_RECTANGLE",
        "DS_P026_SOURCE character=ANTONIO character_name=Antonio starting_weapon=WHIP",
        "weapon=WHIP weapon_name=Whip bullet=WHIP frame=Whip.png weapon_provenance=BUILD_EXTRACTED",
        "DS_P026_GEOMETRY shape=ORIENTED_RECTANGLE forward_min=0.000 forward_max=128.000 lateral_min=-24.000 lateral_max=24.000 edges=INCLUSIVE walls=IGNORED provenance=ENGINEERING_APPROXIMATION",
        "DS_P026_TIMING cooldown_num=189 cooldown_den=4 followup_num=7 followup_den=2 tickrate=35",
    ):
        if marker not in text:
            errors.append(f"missing marker: {marker}")

    source_stats = rows(log, "CHARACTER_STATS")
    weapon_stats = rows(log, "WEAPON_STATS")
    if (not source_stats or source_stats[-1].get("base_max_health") != "100"
            or source_stats[-1].get("starting_max_health") != "20"
            or source_stats[-1].get("starting_armor") != "1"
            or source_stats[-1].get("max_health_actual") != "120"
            or source_stats[-1].get("armor_actual") != "1"
            or source_stats[-1].get("might_percent_per_10") != "10"):
        errors.append("Antonio promoted stat snapshot is missing or mutated")
    if (not weapon_stats or weapon_stats[-1].get("base_damage") != "10"
            or weapon_stats[-1].get("base_amount") != "1"
            or weapon_stats[-1].get("level") != "2"
            or weapon_stats[-1].get("amount_at_level") != "2"):
        errors.append("Whip promoted base values are missing or mutated")

    world_rows = rows(log, "WORLD")
    targets: dict[int, dict[str, Any]] = {}
    inventory: dict[str, int] | None = None
    for row in world_rows:
        try:
            if int(row["kind"]) == 1 and int(row["live"]) == 1:
                targets[int(row["stable_id"])] = {"slot": int(row["slot"]), "generation": int(row["generation"]), "x": float(row["x"]), "y": float(row["y"]), "radius": float(row["radius"]), "health": int(row["health"])}
            elif int(row["kind"]) == 2 and int(row["live"]) == 1:
                if inventory is not None:
                    errors.append("multiple live starting weapon inventory entities")
                inventory = {"slot": int(row["slot"]), "generation": int(row["generation"]), "stable_id": int(row["stable_id"])}
        except (KeyError, ValueError):
            errors.append("malformed P020 world target row")
    if len(targets) != 9:
        errors.append(f"expected nine logical P020 targets, observed {len(targets)}")
    if inventory is None:
        errors.append("missing allocated P020 starting weapon inventory entity")

    cameras = rows(log, "CAMERA")
    initial_yaw = 0 if expected_variant == 4 else expected_variant * 90
    expected_pose = (initial_yaw, 22 if expected_variant in (3, 4) else 0, 115 if expected_variant in (3, 4) else 90)
    if not cameras or tuple(int(cameras[0].get(key, "-1")) for key in ("yaw", "pitch", "fov")) != expected_pose:
        errors.append("initial camera pose does not match requested variant")
    if expected_variant in (3, 4) and not any(int(row.get("pitch", "0")) == 22 and int(row.get("fov", "0")) == 115 for row in cameras):
        errors.append("distinct pitch/FOV presentation pose is missing")
    turns = rows(log, "AIM_TURN")
    if not turns or turns[-1].get("stationary") != "1" or turns[-1].get("owner") != "INPUT_ADAPTER":
        errors.append("stationary authoritative view turn is missing")
    bodies = rows(log, "BODY_MOVE")
    if expected_body and (not bodies or bodies[-1].get("direction") != "BACKWARD" or bodies[-1].get("camera_ignored") != "1"):
        errors.append("backward movement case is missing")
    if not expected_body and bodies:
        errors.append("unexpected body movement in stationary baseline")

    expected_events = expected_schedule()
    emissions = rows(log, "EMISSION")
    if len(emissions) != len(expected_events):
        errors.append(f"expected {len(expected_events)} automatic lobe emissions, observed {len(emissions)}")
    active = set(targets)
    expected_candidates: dict[int, list[int]] = {}
    for expected, row in zip(expected_events, emissions):
        try:
            for key, value in (("event_id", expected["event_id"]), ("tic", expected["tic"]), ("deadline_quarter", expected["deadline"]), ("deadline_denominator", 4), ("parent_event_id", expected["parent"]), ("primary_fire_input", 0), ("snapshot", 1), ("cooldown_num", 189), ("cooldown_den", 4), ("followup_num", 7), ("followup_den", 2)):
                if row.get(key) is None or int(row[key]) != value:
                    errors.append(f"event {expected['event_id']} field {key} mismatch")
            if row.get("kind") != expected["kind"] or row.get("lobe") != expected["lobe"]:
                errors.append(f"event {expected['event_id']} front/rear order mismatch")
            if row.get("aim_basis") != "view_yaw" or row.get("weapon_id") != "WHIP":
                errors.append(f"event {expected['event_id']} does not use view-yaw Whip snapshot")
            if (row.get("weapon_level") != "2" or row.get("base_amount") != "1"
                    or row.get("amount") != "2" or row.get("amount_source") != "LEVEL_TABLE"):
                errors.append(f"event {expected['event_id']} does not carry the level-derived Whip amount")
            if inventory is None or any(int(row.get(key, "-1")) != inventory[expected_key]
                                      for key, expected_key in (("inventory_slot", "slot"),
                                                                ("inventory_generation", "generation"),
                                                                ("inventory_stable_id", "stable_id"),
                                                                ("weapon_generation", "generation"))):
                errors.append(f"event {expected['event_id']} does not carry the allocated full weapon handle")
            if int(row.get("damage_base", "-1")) != 10 or int(row.get("multiplier_milli", "-1")) != 1100 or int(row.get("damage_milli", "-1")) != 11000:
                errors.append(f"event {expected['event_id']} source damage/Might snapshot changed")
            yaw = int(row["aim_yaw_milli"]) // 1000
            expected_yaw = (initial_yaw + (90 if expected["event_id"] >= 3 else 0)) % 360
            if yaw != expected_yaw:
                errors.append(f"event {expected['event_id']} authoritative view yaw changed")
        except (KeyError, ValueError):
            errors.append(f"malformed emission {expected['event_id']}")
            yaw = 0
        expected_candidates[expected["event_id"]] = [stable for stable in sorted(active) if exact_rectangle_circle(targets[stable]["x"], targets[stable]["y"], targets[stable]["radius"], yaw, expected["lobe"])]
        active.difference_update(expected_candidates[expected["event_id"]])

    candidate_rows = rows(log, "CANDIDATE")
    candidate_by_event: dict[int, list[int]] = {}
    for row in candidate_rows:
        try:
            event = int(row["event_id"])
            candidate_by_event.setdefault(event, []).append(int(row["target_id"]))
            if row.get("eligible") != "1" or row.get("broad_phase") != "P024":
                errors.append("candidate is not an eligible P024 narrow-phase result")
        except (KeyError, ValueError):
            errors.append("malformed candidate row")
    for expected in expected_events:
        event_id = expected["event_id"]
        observed = candidate_by_event.get(event_id, [])
        if observed != expected_candidates.get(event_id, []):
            errors.append(f"event {event_id} candidate set differs from independent rectangle oracle")
        emission = emissions[event_id - 1] if event_id <= len(emissions) else {}
        if emission.get("candidate_count") is None or int(emission.get("candidate_count", "-1")) != len(observed):
            errors.append(f"event {event_id} candidate count is truncated")
    if any(stable == 3 for stable in candidate_by_event.get(1, [])):
        errors.append("cone-inflated side target was incorrectly admitted")

    hits = rows(log, "HIT")
    damages = rows(log, "DAMAGE")
    deaths = rows(log, "DEATH")
    xp = rows(log, "XP_REQUEST")
    accepted_hits = [row for row in hits if row.get("accepted") == "1"]
    if len(accepted_hits) != sum(len(value) for value in expected_candidates.values()):
        errors.append("accepted hit count does not match complete ordered candidate sets")
    if len(damages) != len(accepted_hits) or len(deaths) != len(accepted_hits) or len(xp) != len(deaths):
        errors.append("damage/death/XP request stream is incomplete")
    if not hits and expected_candidates:
        errors.append("marker-only or missing hit stream")
    for ordinal, row in enumerate(hits, 1):
        if row.get("transaction_ordinal") != str(ordinal) or row.get("one_hit_per_lobe") != "1":
            errors.append("hit transaction order or one-hit-per-lobe rule is invalid")
        if row.get("accepted") == "1" and row.get("reason") != "ACCEPTED":
            errors.append("accepted hit reason is invalid")
    for row in damages:
        if row.get("accepted") != "1" or row.get("arithmetic") != "CHECKED" or row.get("authority") != "P023_DAMAGE" or row.get("native_damage") != "0" or row.get("proxy_authored") != "0" or row.get("amount") != "11000":
            errors.append("damage did not use the shared checked P023 boundary")
    for row in xp:
        if row.get("authority") != "P023_REWARD" or row.get("xp_milliunits") != "1000":
            errors.append("XP request did not use the P023 reward seam")
    if not rows(log, "STALE_HIT") or any(row.get("accepted") != "0" or row.get("reason") != "STALE_GENERATION" for row in rows(log, "STALE_HIT")):
        errors.append("stale full-handle rejection is missing")

    canonical = rows(log, "CANONICAL")
    if len(canonical) != RUN_TICS or [int(row.get("tic", "-1")) for row in canonical] != list(range(1, RUN_TICS + 1)):
        errors.append("canonical gameplay trace is incomplete or reordered")
    trace = rows(log, "TRACE")
    if expected_telemetry and len(trace) != RUN_TICS:
        errors.append("telemetry-enabled trace is incomplete")
    if not expected_telemetry and trace:
        errors.append("telemetry-disabled run emitted trace rows")
    if expected_effects and not rows(log, "PRESENTATION"):
        errors.append("effects-enabled run lacks a readable presentation proxy")
    if expected_effects and not rows(log, "PROXY_RECREATE"):
        errors.append("effects-enabled proxy recreation evidence is missing")

    complete_rows = rows(log, "COMPLETE")
    complete = complete_rows[-1] if complete_rows else None
    if complete is None:
        errors.append("missing P026 completion marker")
    else:
        expected_complete = {"tics": RUN_TICS, "events": len(expected_events), "hits": len(accepted_hits), "damage": len(damages), "deaths": len(deaths), "xp_requests": len(xp), "camera_variant": expected_variant, "effects": expected_effects, "telemetry": expected_telemetry, "automatic": 1, "primary_fire_input": 0, "native_damage": 0, "proxy_authored_damage": 0, "missing_xp": 0}
        for key, value in expected_complete.items():
            if complete.get(key) is None or int(complete[key]) != value:
                errors.append(f"completion field {key} mismatch")
        if complete.get("camera_invariant") != "true" or complete.get("stationary_turn") != "1" or complete.get("backward_body_invariant") != "1":
            errors.append("completion omitted camera/movement invariance claims")

    return {"status": "PASS" if not errors else "FAIL", "errors": errors,
            "emission_count": len(emissions), "candidate_count": len(candidate_rows),
            "hit_count": len(hits), "damage_count": len(damages), "death_count": len(deaths),
            "xp_count": len(xp), "canonical_count": len(canonical), "completion": complete,
            "gameplay_stream": gameplay_stream(log)}


def run_one(package: Path, *, variant: int, effects: int, telemetry: int, body: int, seconds: float) -> dict[str, Any]:
    runtime = run(package, seconds, False, False, "P026", 60, 1280, 720,
                  map_name="MAP12", completion_marker="DS_P026_COMPLETE",
                  active_in_background=True, vsync=False,
                  startup_commands=["+set", "ds_p026_camera_variant", str(variant),
                                    "+set", "ds_p026_effects", str(effects),
                                    "+set", "ds_p026_telemetry", str(telemetry),
                                    "+set", "ds_p026_body_variant", str(body)])
    evidence = Path(runtime["evidence"])
    log_path = evidence / "engine.log"
    log = log_path.read_text(encoding="utf-8", errors="replace") if log_path.exists() else ""
    result = validate(log, expected_variant=variant, expected_effects=effects,
                      expected_telemetry=telemetry, expected_body=body)
    result.update({"variant": variant, "effects": effects, "telemetry": telemetry,
                   "body": body, "runtime": runtime, "engine_log": str(log_path),
                   "package_sha256": runtime.get("package_sha256")})
    if runtime.get("status") != "RUNTIME_PASS":
        result["errors"].append(f"runtime status was {runtime.get('status')}")
    if not runtime.get("captures") or not all(item.get("nonblank") for item in runtime["captures"]):
        result["errors"].append("required nonblank framebuffer capture is missing")
    result["status"] = "PASS" if not result["errors"] else "FAIL"
    (evidence / "p026-result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return result


def compare(first: dict[str, Any], second: dict[str, Any], label: str) -> list[str]:
    errors: list[str] = []
    if first.get("gameplay_stream") != second.get("gameplay_stream"):
        errors.append(f"{label} changed the ordered canonical gameplay stream")
    if (first.get("completion") or {}).get("hits") != (second.get("completion") or {}).get("hits"):
        errors.append(f"{label} changed accepted hit count")
    return errors


def run_probe(*, package: Path | None = None, seconds: float = 10.0) -> dict[str, Any]:
    if not 6.0 <= seconds <= 120.0:
        raise ValueError("seconds must be between 6 and 120")
    if package is None:
        package = Path(build(ROOT, room_spec=ROOT / "maps/source/p026-whip/room.json")["package"])
    package = Path(package)
    compile_runtime = run(package, seconds, True, False, "P026", 60, 1280, 720,
                          map_name="MAP12", completion_marker="DS_P026_COMPLETE",
                          active_in_background=True, vsync=False)
    if compile_runtime.get("status") != "COMPILE_PASS":
        return {"status": "FAIL", "classification": "P026_PACKAGED_UZDOOM_WHIP_RUNTIME", "errors": ["compile gate failed"], "compile": compile_runtime}
    compile_sha = compile_runtime["package_sha256"]
    runs = [run_one(package, variant=i, effects=1, telemetry=1, body=0, seconds=seconds) for i in range(4)]
    runs.extend((run_one(package, variant=4, effects=1, telemetry=1, body=0, seconds=seconds),
                 run_one(package, variant=0, effects=0, telemetry=1, body=0, seconds=seconds),
                 run_one(package, variant=0, effects=1, telemetry=0, body=0, seconds=seconds),
                 run_one(package, variant=0, effects=1, telemetry=1, body=1, seconds=seconds),
                 run_one(package, variant=0, effects=1, telemetry=1, body=0, seconds=seconds)))
    errors = [f"run {index}: {error}" for index, result in enumerate(runs) for error in result["errors"]]
    if any(result.get("package_sha256") != compile_sha for result in runs):
        errors.append("runtime package differs from compile gate")
    for label, left, right in (("pitch_fov", runs[0], runs[4]), ("effects", runs[0], runs[5]), ("telemetry", runs[0], runs[6]), ("backward", runs[0], runs[7]), ("replay", runs[0], runs[8])):
        errors.extend(compare(left, right, label))
    result = {"status": "PASS" if not errors else "FAIL", "classification": "P026_PACKAGED_UZDOOM_WHIP_RUNTIME", "package": str(package), "package_sha256": hashlib.sha256(package.read_bytes()).hexdigest(), "compile": compile_runtime, "runs": runs, "errors": errors}
    evidence_dir = ROOT / "evidence" / "P026"
    evidence_dir.mkdir(parents=True, exist_ok=True)
    result["evidence"] = str(evidence_dir / "latest-result.json")
    (evidence_dir / "latest-result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2, sort_keys=True))
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path)
    parser.add_argument("--seconds", type=float, default=10.0)
    parser.add_argument("--validate-log", type=Path)
    parser.add_argument("--variant", type=int, default=0)
    parser.add_argument("--effects", type=int, default=1)
    parser.add_argument("--telemetry", type=int, default=1)
    parser.add_argument("--body", type=int, default=0)
    args = parser.parse_args(argv)
    try:
        if args.validate_log:
            result = validate(args.validate_log.read_text(encoding="utf-8", errors="replace"), expected_variant=args.variant, expected_effects=args.effects, expected_telemetry=args.telemetry, expected_body=args.body)
        else:
            result = run_probe(package=args.package, seconds=args.seconds)
    except (OSError, ValueError, RuntimeError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    return 0 if result.get("status") == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
