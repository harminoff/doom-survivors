"""Strict packaged UZDoom validator for the P023 BAT3 basic-enemy fixture."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

NUMBER = r"-?\d+(?:\.\d+)?"
MOVE_RE = re.compile(
    rf"DS_P023_MOVE\s+tic=(?P<tic>\d+)\s+slot=(?P<slot>\d+)\s+generation=(?P<generation>\d+)\s+stable_id=(?P<stable_id>\d+)\s+kind=BAT3\s+"
    rf"from=\((?P<fx>{NUMBER}),(?P<fy>{NUMBER})\)\s+to=\((?P<tx>{NUMBER}),(?P<ty>{NUMBER})\)\s+target=\((?P<px>{NUMBER}),(?P<py>{NUMBER})\)\s+"
    rf"distance_before=(?P<before>{NUMBER})\s+distance_after=(?P<after>{NUMBER})\s+step=(?P<step>{NUMBER})\s+speed=(?P<speed>{NUMBER})\s+no_overshoot=(?P<no_overshoot>[01])\s+camera_ignored=(?P<camera_ignored>[01])"
)
CONTACT_RE = re.compile(
    rf"DS_P023_CONTACT\s+tic=(?P<tic>\d+)\s+attacker_slot=(?P<slot>\d+)\s+generation=(?P<generation>\d+)\s+stable_id=(?P<stable_id>\d+)\s+target=PLAYER\s+"
    rf"distance=(?P<distance>{NUMBER})\s+radius_sum=(?P<radius_sum>{NUMBER})\s+inclusive=(?P<inclusive>[01])\s+in_contact=(?P<in_contact>[01])\s+eligible=(?P<eligible>[01])\s+accepted=(?P<accepted>[01])\s+reason=(?P<reason>\S+)\s+damage=(?P<damage>\d+)\s+"
    rf"player_health_before=(?P<hb>\d+)\s+player_health_after=(?P<ha>\d+)\s+cooldown_before=(?P<cb>\d+)\s+cooldown_after=(?P<ca>\d+)\s+invuln_before=(?P<ib>\d+)\s+invuln_after=(?P<ia>\d+)\s+camera_ignored=(?P<camera_ignored>[01])"
)
DAMAGE_RE = re.compile(
    r"DS_P023_DAMAGE\s+tic=(?P<tic>\d+)\s+event_id=(?P<event_id>\d+)\s+source=(?P<source>\S+)\s+target_slot=(?P<slot>\d+)\s+target_generation=(?P<generation>\d+)\s+target_id=(?P<stable_id>\d+)\s+amount=(?P<amount>\d+)\s+accepted=(?P<accepted>[01])\s+reason=(?P<reason>\S+)\s+health_before=(?P<hb>\d+)\s+health_after=(?P<ha>\d+)"
)
DEATH_RE = re.compile(
    r"DS_P023_DEATH\s+tic=(?P<tic>\d+)\s+target_slot=(?P<slot>\d+)\s+target_generation=(?P<generation>\d+)\s+target_id=(?P<stable_id>\d+)\s+health=0\s+kill_delta=(?P<kill_delta>\d+)\s+kill_count=(?P<kill_count>\d+)\s+death_count=(?P<death_count>\d+)\s+life_before=LIVE\s+life_after=DEAD"
)
XP_RE = re.compile(
    r"DS_P023_XP_REQUEST\s+tic=(?P<tic>\d+)\s+source_slot=(?P<slot>\d+)\s+source_generation=(?P<generation>\d+)\s+source_id=(?P<stable_id>\d+)\s+xp_milliunits=(?P<xp>\d+)\s+request_count=(?P<count>\d+)"
)
DROP_RE = re.compile(
    r"DS_P023_DROP_REQUEST\s+tic=(?P<tic>\d+)\s+source_slot=(?P<slot>\d+)\s+source_generation=(?P<generation>\d+)\s+source_id=(?P<stable_id>\d+)\s+item=(?P<item>\S+)\s+xp_milliunits=(?P<xp>\d+)\s+rng_stream=drop\s+rng_before=(?P<before>-?\d+)\s+rng_after=(?P<after>-?\d+)\s+draw=1\s+request_count=(?P<count>\d+)"
)
DESPAWN_RE = re.compile(
    r"DS_P023_DESPAWN\s+tic=(?P<tic>\d+)\s+target_slot=(?P<slot>\d+)\s+target_generation=(?P<generation>\d+)\s+target_id=(?P<stable_id>\d+)\s+released=(?P<released>[01])\s+life_before=LIVE\s+life_after=RELEASED\s+damage_delta=(?P<damage>\d+)\s+kill_delta=(?P<kill>\d+)\s+xp_delta=(?P<xp>\d+)\s+drop_delta=(?P<drop>\d+)\s+rng_stream=drop\s+rng_before=(?P<before>-?\d+)\s+rng_after=(?P<after>-?\d+)\s+reward=NONE"
)
REUSE_DEATH_RE = re.compile(
    r"DS_P023_REUSE_AFTER_DEATH\s+tic=(?P<tic>\d+)\s+slot=(?P<slot>\d+)\s+old_generation=(?P<old_generation>\d+)\s+old_id=(?P<old_id>\d+)\s+new_generation=(?P<new_generation>\d+)\s+new_id=(?P<new_id>\d+)\s+reused=1\s+death_reward_already_emitted=1"
)
REPLACEMENT_RE = re.compile(
    r"DS_P023_REPLACEMENT\s+tic=(?P<tic>\d+)\s+slot=(?P<slot>\d+)\s+old_generation=(?P<old_generation>\d+)\s+old_id=(?P<old_id>\d+)\s+new_generation=(?P<new_generation>\d+)\s+new_id=(?P<new_id>\d+)\s+reused=1\s+stale_old_handle=REJECTED"
)
STALE_RE = re.compile(
    r"DS_P023_STALE_HIT\s+tic=(?P<tic>\d+)\s+slot=(?P<slot>\d+)\s+generation=(?P<generation>\d+)\s+stable_id=(?P<stable_id>\d+)\s+replacement_generation=(?P<replacement_generation>\d+)\s+replacement_id=(?P<replacement_id>\d+)\s+accepted=0\s+reason=STALE_GENERATION"
)
TRACE_RE = re.compile(
    rf"DS_P023_TRACE\s+tic=(?P<tic>\d+)\s+player_x=(?P<x>{NUMBER})\s+player_y=(?P<y>{NUMBER})\s+player_health=(?P<health>\d+)\s+player_invuln_until=(?P<invuln>\d+)\s+kill_count=(?P<kills>\d+)\s+xp_requests=(?P<xp>\d+)\s+drop_requests=(?P<drops>\d+)\s+drop_rng=(?P<rng>-?\d+)\s+live=(?P<live>\d+)\s+accepted_contacts=(?P<accepted>\d+)\s+rejected_contacts=(?P<rejected>\d+)\s+stale_rejected=(?P<stale>\d+)\s+camera_ignored=1"
)
CAMERA_RE = re.compile(
    rf"DS_P023_CAMERA\s+variant=(?P<variant>\d+)\s+yaw=(?P<yaw>{NUMBER})\s+pitch=(?P<pitch>{NUMBER})\s+fov=(?P<fov>{NUMBER})\s+logical_xy=\((?P<x>{NUMBER}),(?P<y>{NUMBER})\)\s+camera_role=PRESENTATION_ONLY"
)
COMPLETE_RE = re.compile(
    r"DS_P023_COMPLETE\s+tics=(?P<tics>\d+)\s+movement_records=(?P<moves>\d+)\s+contact_records=(?P<contacts>\d+)\s+accepted_contacts=(?P<accepted>\d+)\s+rejected_contacts=(?P<rejected>\d+)\s+player_health=(?P<health>\d+)\s+player_death_count=(?P<player_death>\d+)\s+kill_count=(?P<kills>\d+)\s+xp_requests=(?P<xp>\d+)\s+drop_requests=(?P<drops>\d+)\s+death_count=(?P<deaths>\d+)\s+despawn_count=(?P<despawn>\d+)\s+stale_rejected=(?P<stale>\d+)\s+drop_rng=(?P<rng>-?\d+)\s+camera_variant=(?P<variant>\d+)\s+camera_invariant=true\s+native_ai=0\s+native_solid=0\s+native_damage=0\s+native_pain=0\s+native_random=0\s+native_target=0\s+visual_capture_required=1\s+source_values=ENGINEERING_APPROXIMATION"
)

CAMERA_POSES: dict[int, tuple[float, float, float]] = {
    0: (0.0, 0.0, 90.0),
    1: (90.0, 0.0, 90.0),
    2: (180.0, 0.0, 90.0),
    3: (270.0, 18.0, 110.0),
}

# These are the gameplay records that form the camera-independent replay
# contract.  CAMERA, COMPLETE, and framebuffer records are intentionally not
# included: they describe presentation or capture plumbing and can contain
# run-specific values such as the screenshot filename.
GAMEPLAY_EVENT_PATTERNS: tuple[tuple[str, re.Pattern[str]], ...] = (
    ("MOVE", MOVE_RE),
    ("CONTACT", CONTACT_RE),
    ("DAMAGE", DAMAGE_RE),
    ("DEATH", DEATH_RE),
    ("XP_REQUEST", XP_RE),
    ("DROP_REQUEST", DROP_RE),
    ("DESPAWN", DESPAWN_RE),
    ("REUSE_AFTER_DEATH", REUSE_DEATH_RE),
    ("REPLACEMENT", REPLACEMENT_RE),
    ("STALE_HIT", STALE_RE),
    ("TRACE", TRACE_RE),
)


def _flat(log: str) -> str:
    """UZDoom wraps long Console.Printf lines; spaces preserve field order."""
    return re.sub(r"\s+", " ", log)


def _groups(pattern: re.Pattern[str], text: str) -> list[dict[str, Any]]:
    return [{key: _number(value) for key, value in match.groupdict().items()} for match in pattern.finditer(text)]


def _number(value: str) -> Any:
    if re.fullmatch(r"-?\d+", value):
        return int(value)
    try:
        return float(value)
    except ValueError:
        return value


def next_rng(state: int) -> int:
    value = state
    value = (value ^ ((value << 13) & 0xFFFFFFFF)) & 0xFFFFFFFF
    value = (value ^ (value >> 17)) & 0xFFFFFFFF
    value = (value ^ ((value << 5) & 0xFFFFFFFF)) & 0xFFFFFFFF
    if value == 0:
        value = 1831565813
    return value if value < 0x80000000 else value - 0x100000000


def parse_trace(log: str) -> list[dict[str, Any]]:
    return _groups(TRACE_RE, _flat(log))


def parse_gameplay_event_trace(log: str) -> list[str]:
    """Return normalized ordered gameplay records, excluding presentation markers.

    UZDoom wraps long Console.Printf lines and also interleaves framework
    markers (for example DS_POSE and DS_RUNTIME_COMPLETE) with fixture output.
    Framing records by the next marker therefore contaminates a gameplay event.
    Instead, each accepted record is parsed from its schema and re-serialized
    from its named fields.  Match offsets retain the original event order while
    ignoring unrelated output and run-specific capture filenames.
    """
    text = _flat(log)
    rows: list[tuple[int, str]] = []
    for kind, pattern in GAMEPLAY_EVENT_PATTERNS:
        for match in pattern.finditer(text):
            payload = {"type": kind, **match.groupdict()}
            rows.append(
                (
                    match.start(),
                    f"{kind}:" + json.dumps(payload, sort_keys=True, separators=(",", ":")),
                )
            )
    rows.sort(key=lambda row: row[0])
    return [event for _, event in rows]


def validate(log: str, *, expected_variant: int | None = None, require_capture: bool = False) -> dict[str, Any]:
    text = _flat(log)
    errors: list[str] = []
    if re.search(r"DS_ASSERT_FAIL|Script error|VM execution aborted|Execution could not continue", text):
        errors.append("engine reported a script/runtime failure")
    for marker in (
        "DS_P023_BOOT map=MAP09 ticrate=35",
        "fixture=bat3-basic-v1 behavior=ENGINEERING_APPROXIMATION",
        "source_path=wiki:Mad_Forest#enemies[0]",
        "DS_P023_RULES movement_speed=0.500 contact_radii=(2.000,2.000) contact_distance=4.000 inclusive=1",
        "native_ai=0 native_solid=0 native_damage=0 native_pain=0 native_random=0 native_target=0",
        "DS_P023_AUTHORITY source_model=LOGICAL_XY_AND_TRANSACTIONS proxy=DSP023BasicEnemyProxy presentation_only=1",
        "DS_P023_CONTACT_PHASE tic=1 mode=ONE_ATTACKER attackers=1 cadence=7",
        "DS_P023_CONTACT_PHASE tic=16 mode=MANY_ATTACKER attackers=2 order=stable_id global_invulnerability=1",
    ):
        if marker not in text:
            errors.append(f"missing marker: {marker}")

    moves = _groups(MOVE_RE, text)
    contacts = _groups(CONTACT_RE, text)
    damages = _groups(DAMAGE_RE, text)
    deaths = _groups(DEATH_RE, text)
    xp_requests = _groups(XP_RE, text)
    drops = _groups(DROP_RE, text)
    despawns = _groups(DESPAWN_RE, text)
    death_reuses = _groups(REUSE_DEATH_RE, text)
    replacements = _groups(REPLACEMENT_RE, text)
    stale_markers = _groups(STALE_RE, text)
    traces = parse_trace(log)
    gameplay_event_trace = parse_gameplay_event_trace(log)
    cameras = _groups(CAMERA_RE, text)
    complete_matches = _groups(COMPLETE_RE, text)

    if not moves:
        errors.append("actual movement trace is empty")
    if not contacts:
        errors.append("actual contact trace is empty")
    if not traces:
        errors.append("actual canonical trace is empty")
    if len(traces) < 70:
        errors.append("canonical trace does not cover all 70 logical tics")
    if len(cameras) < 1:
        errors.append("camera presentation trace is empty")
    else:
        for camera in cameras:
            pose = CAMERA_POSES.get(int(camera["variant"]))
            if pose is None:
                errors.append(f"camera variant {camera['variant']} is outside the accepted pose matrix")
                continue
            if any(abs(float(camera[field]) - expected) > 0.002 for field, expected in zip(("yaw", "pitch", "fov"), pose)):
                errors.append(f"camera variant {camera['variant']} yaw/pitch/FOV does not match the frozen pose matrix")
                break
        if expected_variant is not None and cameras[-1]["variant"] != expected_variant:
            errors.append(f"expected camera variant {expected_variant}, observed {cameras[-1]['variant']}")

    one_phase = [row for row in contacts if int(row["tic"]) <= 15]
    many_phase = [row for row in contacts if 16 <= int(row["tic"]) <= 20]
    if not one_phase or {int(row["stable_id"]) for row in one_phase} != {100}:
        errors.append("isolated one-attacker cadence phase is missing or contains another attacker")
    else:
        one_successes = [int(row["tic"]) for row in one_phase if int(row["accepted"]) == 1]
        if one_successes != [1, 8, 15]:
            errors.append(f"isolated attacker cadence is not seven tics: {one_successes}")
    if not many_phase or any({int(row["stable_id"]) for row in many_phase if int(row["tic"]) == tic} != {100, 101} for tic in range(16, 21)):
        errors.append("multi-attacker stable-ID/global-invulnerability phase is incomplete")

    # Recompute every movement transition from the individual coordinates.
    for row in moves:
        before = float(row["before"])
        after = float(row["after"])
        step = float(row["step"])
        speed = float(row["speed"])
        fx, fy, tx, ty, px, py = (float(row[key]) for key in ("fx", "fy", "tx", "ty", "px", "py"))
        actual_before = math.hypot(fx - px, fy - py)
        actual_after = math.hypot(tx - px, ty - py)
        if abs(actual_before - before) > 0.002 or abs(actual_after - after) > 0.002:
            errors.append(f"movement tic {row['tic']} slot {row['slot']} distances are not derived from coordinates")
            break
        expected_after = max(before - step, 0.0)
        if step < -0.0001 or step > speed + 0.0001 or abs(expected_after - after) > 0.002:
            errors.append(f"movement tic {row['tic']} slot {row['slot']} violates speed/no-overshoot arithmetic")
            break
        if row["no_overshoot"] != 1 or row["camera_ignored"] != 1:
            errors.append("movement record does not prove camera-independent no-overshoot movement")
            break

    # Recompute contact cadence and global invulnerability in stable-ID order.
    cooldown: dict[int, int] = {}
    player_health = 10000
    invulnerable_until = 0
    accepted_contacts = 0
    rejected_contacts = 0
    previous_order: tuple[int, int] | None = None
    for row in contacts:
        order = (int(row["tic"]), int(row["stable_id"]))
        if previous_order is not None and order < previous_order:
            errors.append("contact records are not ordered by tic and attacker stable ID")
            break
        previous_order = order
        tic = int(row["tic"])
        sid = int(row["stable_id"])
        distance = float(row["distance"])
        in_contact = int(distance <= 4.0 + 0.000001)
        ready = tic >= cooldown.get(sid, 0)
        eligible = int(in_contact and ready)
        accepted = int(eligible and player_health > 0 and tic >= invulnerable_until)
        reason = "SUCCESS" if accepted else ("PLAYER_DEAD" if in_contact and eligible and player_health <= 0 else "PLAYER_INVULNERABLE" if eligible and tic < invulnerable_until else "ATTACKER_COOLDOWN" if in_contact and not ready else "OUTSIDE_CONTACT")
        before = player_health
        after = max(before - 1250, 0) if accepted else before
        expected_cooldown = tic + 7 if accepted else cooldown.get(sid, 0)
        expected_invuln = tic + 3 if accepted else invulnerable_until
        fields = (("in_contact", in_contact), ("eligible", eligible), ("accepted", accepted), ("reason", reason),
                  ("damage", 1250), ("hb", before), ("ha", after), ("cb", cooldown.get(sid, 0)),
                  ("ca", expected_cooldown), ("ib", invulnerable_until), ("ia", expected_invuln),
                  ("inclusive", 1), ("camera_ignored", 1))
        for field, expected in fields:
            if row[field] != expected:
                errors.append(f"contact tic {tic} stable ID {sid} field {field} is not independently derived")
                break
        if accepted:
            player_health = after
            cooldown[sid] = expected_cooldown
            invulnerable_until = expected_invuln
            accepted_contacts += 1
        else:
            rejected_contacts += 1

    # Damage/death/drop transactions are separate from contact damage and are
    # checked by handle, health boundary, and named RNG transition.
    death_handles: set[tuple[int, int, int]] = set()
    for row in damages:
        handle = (int(row["slot"]), int(row["generation"]), int(row["stable_id"]))
        if int(row["accepted"]) == 1:
            expected_after = max(int(row["hb"]) - int(row["amount"]), 0)
            if int(row["amount"]) != 3000 or int(row["hb"]) != 3000 or int(row["ha"]) != expected_after:
                errors.append("accepted test-seam damage does not establish the 3000-to-zero health boundary")
            if handle in death_handles:
                errors.append("duplicate accepted damage/death transaction affected one generation")
            death_handles.add(handle)
        elif row["reason"] not in {"STALE_OR_DEAD"}:
            errors.append("rejected damage transaction lacks stale/dead fail-closed reason")
    if len(deaths) != 1 or len(xp_requests) != 1 or len(drops) != 1:
        errors.append("death, XP request, and drop request must each occur exactly once")
    if deaths:
        death = deaths[0]
        if death["kill_delta"] != 1 or death["kill_count"] != 1 or death["death_count"] != 1:
            errors.append("death accounting is not exactly one kill")
    if xp_requests and (xp_requests[0]["xp"] != 1000 or xp_requests[0]["count"] != 1):
        errors.append("XP request value/count is not derived from the death fixture")
    if drops:
        drop = drops[0]
        if drop["item"] != "base.drop.xp-gem-engineering" or drop["xp"] != 1000 or drop["count"] != 1:
            errors.append("drop request identity/value/count is incorrect")
        if next_rng(int(drop["before"])) != int(drop["after"]):
            errors.append("drop request consumed an invalid named drop RNG transition")

    if len(despawns) != 1:
        errors.append("despawn trace must contain exactly one released entity")
    elif any(despawns[0][key] != 0 for key in ("damage", "kill", "xp", "drop")) or despawns[0]["released"] != 1 or despawns[0]["before"] != despawns[0]["after"]:
        errors.append("despawn incorrectly awarded damage, kill, XP, drop, or RNG")
    if len(death_reuses) != 1 or len(replacements) != 1:
        errors.append("death reuse and despawn reuse evidence are incomplete")
    else:
        reused = death_reuses[0]
        replacement = replacements[0]
        if reused["new_generation"] != reused["old_generation"] + 1 or reused["new_id"] == reused["old_id"]:
            errors.append("death slot reuse did not increment generation and stable ID")
        if replacement["new_generation"] != replacement["old_generation"] + 1 or replacement["new_id"] == replacement["old_id"]:
            errors.append("despawn slot reuse did not increment generation and stable ID")
    if len(stale_markers) != 1 or not stale_markers or stale_markers[0]["replacement_generation"] == stale_markers[0]["generation"] or stale_markers[0]["replacement_id"] == stale_markers[0]["stable_id"]:
        errors.append("stale generation hit did not fail closed against the replacement")

    # Independently derive trace counters and ensure the summary cannot hide a
    # missing or reordered transaction record.
    expected_trace = []
    running_live = 4
    for trace in traces:
        tic = int(trace["tic"])
        if tic >= 20:
            running_live = 3
        if tic >= 21:
            running_live = 4
        if tic >= 30:
            running_live = 3
        if tic >= 31:
            running_live = 4
        running_kills = sum(1 for row in deaths if int(row["tic"]) <= tic)
        running_xp = sum(1 for row in xp_requests if int(row["tic"]) <= tic)
        running_drops = sum(1 for row in drops if int(row["tic"]) <= tic)
        running_stale = sum(1 for row in damages if int(row["accepted"]) == 0 and int(row["tic"]) <= tic)
        expected_trace.append((tic, running_kills, running_xp, running_drops, running_stale))
        if trace["kills"] != running_kills or trace["xp"] != running_xp or trace["drops"] != running_drops or trace["stale"] != running_stale or trace["live"] != running_live:
            errors.append(f"canonical trace tic {tic} counters are not derived from transactions")
            break
    if traces and traces[-1]["health"] != player_health:
        errors.append("canonical trace final player health differs from contact arithmetic")
    if traces and traces[-1]["accepted"] != accepted_contacts:
        errors.append("canonical trace accepted-contact count differs from contact arithmetic")
    if traces and traces[-1]["rejected"] != rejected_contacts:
        errors.append("canonical trace rejected-contact count differs from contact arithmetic")

    if not complete_matches:
        errors.append("missing strict P023 completion marker")
        completion = None
    else:
        completion = complete_matches[-1]
        expected = {
            "tics": 70, "moves": len(moves), "contacts": len(contacts),
            "accepted": accepted_contacts, "rejected": rejected_contacts,
            "health": player_health, "player_death": int(player_health == 0),
            "kills": len(deaths), "xp": len(xp_requests), "drops": len(drops),
            "deaths": len(deaths), "despawn": len(despawns), "stale": sum(int(row["accepted"]) == 0 for row in damages),
            "rng": int(drops[0]["after"]) if drops else 303,
        }
        for field, value in expected.items():
            if completion[field] != value:
                errors.append(f"completion field {field} does not match individual traces")
        if expected_variant is not None and completion["variant"] != expected_variant:
            errors.append("completion camera variant mismatch")
    if require_capture and "DS_P023_FRAMEBUFFER_CAPTURE" not in text:
        errors.append("required nonblank framebuffer capture marker is missing")

    return {
        "status": "PASS" if not errors else "FAIL",
        "classification": "P023_PACKAGED_UZDOOM_BASIC_ENEMY_RUN",
        "errors": errors,
        "movement_records": len(moves),
        "contact_records": len(contacts),
        "damage_records": len(damages),
        "trace_records": len(traces),
        "camera_records": len(cameras),
        "gameplay_event_trace": gameplay_event_trace,
        "camera_poses_validated": all(
            int(camera["variant"]) in CAMERA_POSES
            and all(abs(float(camera[field]) - expected) <= 0.002 for field, expected in zip(("yaw", "pitch", "fov"), CAMERA_POSES[int(camera["variant"])]))
            for camera in cameras
        ),
        "completion": completion,
        "trace": traces,
    }


def run_probe(*, package: Path | None = None, seconds: float = 20.0, camera_variants: tuple[int, ...] = (0, 1, 2, 3)) -> dict[str, Any]:
    if not 8.0 <= seconds <= 120.0:
        raise ValueError("seconds must be between 8 and 120")
    from tools.build import build
    from tools.run_probe import run
    if package is None:
        package = Path(build(ROOT, room_spec=ROOT / "maps/source/p023-enemy-basics/room.json")["package"])
    package = Path(package)

    compile_result = run(package, seconds, True, False, "P023", 60, 1280, 720,
                         map_name="MAP09", completion_marker="DS_P023_COMPLETE")
    package_sha = hashlib.sha256(package.read_bytes()).hexdigest()
    if compile_result["status"] != "COMPILE_PASS":
        return {"status": "FAIL", "classification": "P023_PACKAGED_UZDOOM_BASIC_ENEMY_RUN", "errors": ["compile gate failed"], "compile": compile_result, "package_sha256": package_sha}

    runs: list[dict[str, Any]] = []
    for variant in camera_variants:
        runtime = run(package, seconds, False, False, "P023", 60, 1280, 720,
                      map_name="MAP09", completion_marker="DS_P023_COMPLETE",
                      active_in_background=True, vsync=False,
                      startup_commands=["+set", "ds_p023_camera_variant", str(variant)])
        evidence = Path(runtime["evidence"])
        log_path = evidence / "engine.log"
        log = log_path.read_text(encoding="utf-8", errors="replace") if log_path.exists() else ""
        strict = validate(log, expected_variant=variant, require_capture=True)
        strict.update({"variant": variant, "runtime": runtime, "engine_log": str(log_path), "package_sha256": runtime.get("package_sha256")})
        if runtime.get("status") != "RUNTIME_PASS":
            strict["errors"].append(f"runtime status was {runtime.get('status')}")
            strict["status"] = "FAIL"
        if not runtime.get("captures"):
            strict["errors"].append("runtime did not produce a framebuffer capture")
            strict["status"] = "FAIL"
        (evidence / "p023-result.json").write_text(json.dumps(strict, indent=2) + "\n", encoding="utf-8")
        runs.append(strict)

    # Repeat the front run to prove deterministic replay in two actual UZDoom
    # processes using the same package and configuration.
    replay_runtime = run(package, seconds, False, False, "P023", 60, 1280, 720,
                         map_name="MAP09", completion_marker="DS_P023_COMPLETE",
                         active_in_background=True, vsync=False,
                         startup_commands=["+set", "ds_p023_camera_variant", "0"])
    replay_path = Path(replay_runtime["evidence"]) / "engine.log"
    replay_log = replay_path.read_text(encoding="utf-8", errors="replace") if replay_path.exists() else ""
    replay = validate(replay_log, expected_variant=0, require_capture=True)
    replay.update({"runtime": replay_runtime, "engine_log": str(replay_path), "package_sha256": replay_runtime.get("package_sha256")})
    baseline = next((item for item in runs if item["variant"] == 0), None)
    errors = [f"variant {item['variant']}: {error}" for item in runs for error in item["errors"]]
    if baseline is not None and baseline.get("trace") != replay.get("trace"):
        errors.append("deterministic replay changed the canonical trace")
    baseline_complete = baseline.get("completion") if baseline else None
    if baseline_complete and replay.get("completion") != baseline_complete:
        errors.append("deterministic replay changed the canonical completion")
    normal_traces = [item.get("trace") for item in runs]
    if normal_traces and any(trace != normal_traces[0] for trace in normal_traces[1:]):
        errors.append("front/side/rear camera variants changed logical movement or combat")
    normal_event_traces = [item.get("gameplay_event_trace") for item in runs]
    gameplay_event_trace_equal = bool(normal_event_traces) and all(trace == normal_event_traces[0] for trace in normal_event_traces[1:])
    if not gameplay_event_trace_equal:
        errors.append("front/side/rear camera variants changed an ordered gameplay event record")
    replay_event_trace_equal = baseline is not None and baseline.get("gameplay_event_trace") == replay.get("gameplay_event_trace")
    if not replay_event_trace_equal:
        errors.append("deterministic replay changed an ordered gameplay event record")
    if package_sha != compile_result.get("package_sha256"):
        errors.append("package changed between compile and runtime")
    if any(item.get("package_sha256") != compile_result.get("package_sha256") for item in runs + [replay]):
        errors.append("runtime used a package different from the compile gate")
    result = {
        "status": "PASS" if not errors and all(item["status"] == "PASS" for item in runs) and replay["status"] == "PASS" else "FAIL",
        "classification": "P023_PACKAGED_UZDOOM_BASIC_ENEMY_RUN",
        "errors": errors,
        "package": str(package),
        "package_sha256": package_sha,
        "compile": compile_result,
        "runs": runs,
        "replay": replay,
        "camera_invariant_trace": bool(normal_traces) and all(trace == normal_traces[0] for trace in normal_traces[1:]),
        "gameplay_event_trace_equal": gameplay_event_trace_equal,
        "deterministic_replay": baseline is not None and baseline.get("trace") == replay.get("trace"),
        "replay_gameplay_event_trace_equal": replay_event_trace_equal,
    }
    evidence_dir = ROOT / "evidence" / "P023"
    evidence_dir.mkdir(parents=True, exist_ok=True)
    result["evidence"] = str(evidence_dir / "latest-result.json")
    (evidence_dir / "latest-result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path)
    parser.add_argument("--seconds", type=float, default=20.0)
    parser.add_argument("--validate-log", type=Path)
    parser.add_argument("--variant", type=int)
    args = parser.parse_args(argv)
    try:
        if args.validate_log:
            result = validate(args.validate_log.read_text(encoding="utf-8", errors="replace"), expected_variant=args.variant)
        else:
            result = run_probe(package=args.package, seconds=args.seconds)
    except (OSError, ValueError, RuntimeError) as exc:
        print(f"FAIL: {exc}")
        return 1
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
