"""Run and strictly validate the packaged P022 MAP08 spawn fixture.

The validator consumes actual engine traces. A boot/completion marker alone is
never sufficient: every deadline, attempt, admission, cap rejection, region
boundary and native pause transition is checked from the captured log.
"""
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

from tools.build import build
from tools.run_probe import run

BOOT = "DS_P022_BOOT map=MAP08 ticrate=35"
SPAWN_RE = re.compile(
    r"DS_P022_SPAWN event_id=(?P<event_id>\d+) tic=(?P<tic>\d+) deadline=(?P<deadline>\d+) "
    r"clock=(?P<clock>\S+) priority=(?P<priority>\d+) row=(?P<row>\d+) attempt=(?P<attempt>\d+) "
    r"kind=(?P<kind>batch|refill) admitted=(?P<admitted>[01]) entity_id=(?P<entity_id>\d+) "
    r"alive=(?P<alive>\d+) cap=(?P<cap>\d+) x=(?P<x>-?\d+(?:\.\d+)?) y=(?P<y>-?\d+(?:\.\d+)?) "
    r"side=(?P<side>\d+) lane=(?P<lane>-?\d+) region=(?P<region>\S+) rng_spawn=(?P<rng>-?\d+)"
)
EVENT_RE = re.compile(
    r"DS_P022_EVENT tic=(?P<tic>\d+) deadline=(?P<deadline>\d+) clock=(?P<clock>\S+) "
    r"priority=(?P<priority>\d+) event_index=(?P<index>\d+) row=(?P<row>\d+) "
    r"batch=(?P<batch>\d+) refill=(?P<refill>\d+) cap=(?P<cap>\d+) alive=(?P<alive>\d+) "
    r"attempts=(?P<attempts>\d+) admissions=(?P<admissions>\d+) rejected=(?P<rejected>\d+) "
    r"refill_requests=(?P<refill_requests>\d+) refill_admissions=(?P<refill_admissions>\d+) "
    r"cap_rejections=(?P<cap_rejections>\d+) mode=(?P<mode>\S+)"
)
COMPLETE_RE = re.compile(
    r"DS_P022_COMPLETE tics=(?P<tics>\d+) engine_world_ticks=(?P<engine>\d+) "
    r"attempts=(?P<attempts>\d+) admissions=(?P<admissions>\d+) rejected=(?P<rejected>\d+) "
    r"refills=(?P<refills>\d+) refill_admissions=(?P<refill_admissions>\d+) "
    r"cap_rejections=(?P<cap_rejections>\d+) releases=(?P<releases>\d+) alive=\((?P<alive_wave>\d+),(?P<alive_refill>\d+),(?P<alive_event>\d+)\) "
    r"next_indices=\((?P<next_wave>\d+),(?P<next_refill>\d+),(?P<next_event>\d+)\) "
    r"rng_spawn=(?P<rng>-?\d+) region=(?P<region>\S+) mode=(?P<mode>\S+) camera_invariant=true native_pause=(?P<native_pause>[01]) backlog=0 "
    r"source_timing=UNKNOWN geometry=ENGINEERING_APPROXIMATION"
)
CAMERA_RE = re.compile(
    r"DS_P022_CAMERA_VARIANT variant=(?P<variant>\d+) yaw=(?P<yaw>-?\d+(?:\.\d+)?) "
    r"pitch=(?P<pitch>-?\d+(?:\.\d+)?) fov=(?P<fov>-?\d+(?:\.\d+)?) logical_region=(?P<region>\S+)"
)
PAUSE_BEGIN_RE = re.compile(r"DS_P022_NATIVE_PAUSE_BEGIN ui_ticks=(\d+) simulation_tic=(\d+)")
PAUSE_HELD_RE = re.compile(r"DS_P022_NATIVE_PAUSE_HELD ui_ticks=(\d+) simulation_tic=(\d+) world_paused=1")
RESUME_RE = re.compile(r"DS_P022_NATIVE_RESUME ui_ticks=(\d+) simulation_tic=(\d+) paused_sim_tics=(\d+) backlog=0")
RELEASE_RE = re.compile(r"DS_P022_RELEASE tic=(?P<tic>\d+) row=(?P<row>\d+) released=(?P<released>\d+) alive_before=(?P<before>\d+) alive_after=(?P<after>\d+) reason=DETERMINISTIC_SLOT_RELEASE")
BOUNDARY_RE = re.compile(r"DS_P022_BOUNDARY_TEST reference_left=(?P<reference_left>[01]) reference_right=(?P<reference_right>[01]) inner_excluded=(?P<inner_excluded>[01]) outer_left=(?P<outer_left>[01]) outer_right=(?P<outer_right>[01]) beyond_left=(?P<beyond_left>[01]) beyond_right=(?P<beyond_right>[01]) negative_coordinates=1")

CLOCKS = {
    "stage-wave-100ms": (0, 0),
    "stage-refill-250ms": (1, 1),
    "stage-event-third": (2, 2),
}


def deadline(clock: str, index: int) -> int:
    if clock == "stage-wave-100ms":
        return (index * 7 + 1) // 2
    if clock == "stage-refill-250ms":
        return (index * 35 + 3) // 4
    if clock == "stage-event-third":
        return (index * 35 + 2) // 3
    raise ValueError(f"unknown clock {clock}")


def _groups(match: re.Match[str]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in match.groupdict().items():
        if key in {"clock", "kind", "region", "mode"}:
            result[key] = value
        elif key in {"x", "y", "yaw", "pitch", "fov"}:
            result[key] = float(value)
        else:
            result[key] = int(value)
    return result


def parse_spawns(log: str) -> list[dict[str, Any]]:
    return [_groups(match) for match in SPAWN_RE.finditer(log)]


def parse_events(log: str) -> list[dict[str, Any]]:
    return [_groups(match) for match in EVENT_RE.finditer(log)]


def spawn_trace(log: str) -> list[tuple[Any, ...]]:
    """Return camera-independent identity/time/logical-position evidence."""
    return [
        (row["clock"], row["priority"], row["row"], row["attempt"], row["kind"],
         row["admitted"], row["entity_id"], row["deadline"], row["tic"],
         round(row["x"], 3), round(row["y"], 3), row["side"], row["lane"])
        for row in parse_spawns(log)
    ]


def _release_value(release: Any, key: str) -> int:
    if isinstance(release, dict):
        return int(release[key])
    return int(release.group(key))


def validate_attempt_ledger(spawns: list[dict[str, Any]], releases: list[Any], expected_mode: str = "normal") -> tuple[list[str], dict[str, int]]:
    """Derive population transitions from attempts and deterministic releases."""
    errors: list[str] = []
    release_tic = _release_value(releases[0], "tic") if releases else None
    release_applied = False
    derived_alive = {clock: 0 for clock in CLOCKS}
    previous_event_id = 0
    for spawn in spawns:
        if spawn["event_id"] != previous_event_id + 1:
            errors.append("spawn attempt event IDs are not contiguous")
        previous_event_id = spawn["event_id"]
        if release_tic is not None and not release_applied and spawn["tic"] > release_tic:
            before = _release_value(releases[0], "before")
            released = _release_value(releases[0], "released")
            after = _release_value(releases[0], "after")
            if before != derived_alive["stage-wave-100ms"] or released <= 0 or after != before - released or after < 0:
                errors.append("release ledger does not match the derived wave population")
            derived_alive["stage-wave-100ms"] = after
            release_applied = True
        expected_cap = 3 if expected_mode == "override" and spawn["clock"] == "stage-wave-100ms" else (4 if spawn["clock"] == "stage-wave-100ms" else 6)
        prior_alive = derived_alive[spawn["clock"]]
        expected_admitted = int(prior_alive < expected_cap)
        if spawn["cap"] != expected_cap or spawn["admitted"] != expected_admitted:
            errors.append(f"attempt {spawn['event_id']} admission does not match prior population and cap")
        expected_alive = prior_alive + expected_admitted
        if spawn["alive"] != expected_alive:
            errors.append(f"attempt {spawn['event_id']} alive transition is not derived from admission")
        derived_alive[spawn["clock"]] = expected_alive
    if release_tic is not None and not release_applied:
        errors.append("release ledger was not applied before later spawn attempts")
    return errors, derived_alive


def validate(log: str, *, expected_variant: int | None = None, expected_mode: str = "normal") -> dict[str, Any]:
    errors: list[str] = []
    if "Script error" in log or "VM execution aborted" in log or "Execution could not continue" in log:
        errors.append("engine reported a script/runtime failure")
    for marker in (
        BOOT,
        "clock_model=CEIL_ABSOLUTE_DEADLINE",
        "region=logical-reference-v1 region_width=256.000 region_height=256.000 camera_frustum=SEPARATE",
        "DS_P022_SOURCE_SCHEDULE stage_key=FOREST",
        f"DS_P022_MODE mode={expected_mode}",
        "DS_P022_CLOCK name=stage-wave-100ms",
        "DS_P022_CLOCK name=stage-refill-250ms",
        "DS_P022_CLOCK name=stage-event-third",
        "DS_P022_TIE_CHECK tic=18 same_deadline=1 order=stage-wave-100ms,stage-refill-250ms",
    ):
        if marker not in log:
            errors.append(f"missing marker: {marker}")
    boundary = BOUNDARY_RE.search(log)
    if boundary is None:
        errors.append("missing runtime boundary predicate trace")
    elif any(boundary.group(key) != "1" for key in ("reference_left", "reference_right", "inner_excluded", "outer_left", "outer_right", "beyond_left", "beyond_right")):
        errors.append("logical reference/spawn boundary predicate failed")

    spawns = parse_spawns(log)
    events = parse_events(log)
    if not spawns:
        errors.append("actual spawn trace is empty")
    if not events:
        errors.append("actual timeline event trace is empty")

    by_event: dict[tuple[str, int], list[dict[str, Any]]] = {}
    for row in spawns:
        key = (row["clock"], row["deadline"])
        by_event.setdefault(key, []).append(row)
        if row["clock"] not in CLOCKS:
            errors.append(f"unknown clock in spawn trace: {row['clock']}")
            continue
        priority, expected_row = CLOCKS[row["clock"]]
        if row["priority"] != priority or row["row"] != expected_row:
            errors.append(f"clock/row priority mismatch at event {row['event_id']}")
        if row["deadline"] != deadline(row["clock"], next((event["index"] for event in events if event["clock"] == row["clock"] and event["deadline"] == row["deadline"]), 0)):
            errors.append(f"deadline does not match absolute schedule at event {row['event_id']}")
        if row["tic"] != row["deadline"]:
            errors.append(f"spawn released away from its absolute deadline: event {row['event_id']}")
        if row["region"] != "logical-reference-v1":
            errors.append(f"spawn used a non-reference region: event {row['event_id']}")
        if row["side"] not in range(4) or not -128 <= row["lane"] <= 128:
            errors.append(f"placement sampler escaped side/lane bounds: event {row['event_id']}")
        dx, dy = row["x"], row["y"]
        outer = -160.0 <= dx <= 160.0 and -160.0 <= dy <= 160.0
        inner = -128.0 <= dx <= 128.0 and -128.0 <= dy <= 128.0
        if not outer or inner:
            errors.append(f"spawn is outside the inclusive outer/exclusive inner band: event {row['event_id']}")
        if row["admitted"] and row["entity_id"] <= 0:
            errors.append(f"admission has no stable entity identity: event {row['event_id']}")
        if not row["admitted"] and row["entity_id"] != 0:
            errors.append(f"rejected attempt received an entity identity: event {row['event_id']}")

    # The event ledger is the authoritative schedule trace. Every event has a
    # matching set of batch/refill attempts and its counters are monotonic.
    previous = (0, -1, 0)
    cumulative_attempts = 0
    cumulative_admissions = 0
    cumulative_rejected = 0
    cumulative_refills = 0
    cumulative_refill_admissions = 0
    cumulative_cap_rejections = 0
    for row in events:
        if row["clock"] not in CLOCKS:
            errors.append(f"unknown clock in event ledger: {row['clock']}")
            continue
        priority, expected_row = CLOCKS[row["clock"]]
        expected_batch = 1 if expected_mode == "override" and row["clock"] == "stage-wave-100ms" else (2 if row["clock"] == "stage-wave-100ms" else 1)
        expected_refill = 0 if row["clock"] == "stage-event-third" else 1
        expected_cap = 3 if expected_mode == "override" and row["clock"] == "stage-wave-100ms" else (4 if row["clock"] == "stage-wave-100ms" else 6)
        if row["priority"] != priority or row["row"] != expected_row:
            errors.append(f"event ledger priority/row mismatch at index {row['index']}")
        if row["mode"] != expected_mode or row["batch"] != expected_batch or row["refill"] != expected_refill or row["cap"] != expected_cap:
            errors.append(f"event {row['clock']} index {row['index']} changed its mode-specific batch/refill/cap policy")
        expected_deadline = deadline(row["clock"], row["index"])
        if row["deadline"] != expected_deadline or row["tic"] != expected_deadline:
            errors.append(f"event {row['clock']} index {row['index']} violates absolute deadline")
        order = (row["tic"], row["priority"], row["index"])
        if order < previous:
            errors.append("event ledger order is not tic/priority/index stable")
        previous = order
        matching = [spawn for spawn in spawns if spawn["clock"] == row["clock"] and spawn["deadline"] == row["deadline"]]
        expected_attempts = row["batch"] + row["refill"]
        if len(matching) != expected_attempts:
            errors.append(f"event {row['clock']} index {row['index']} has {len(matching)} attempts, expected {expected_attempts}")
        if row["refill"] > 0 and not any(spawn["kind"] == "refill" for spawn in matching):
            errors.append(f"event {row['clock']} index {row['index']} lost its explicit refill attempt")
        if [spawn["attempt"] for spawn in matching] != list(range(expected_attempts)):
            errors.append(f"event {row['clock']} index {row['index']} changed deterministic attempt ordering")
        if any(spawn["kind"] != ("batch" if spawn["attempt"] < row["batch"] else "refill") for spawn in matching):
            errors.append(f"event {row['clock']} index {row['index']} mixed batch and refill attempt kinds")
        cumulative_attempts += len(matching)
        cumulative_admissions += sum(spawn["admitted"] for spawn in matching)
        cumulative_rejected += sum(not spawn["admitted"] for spawn in matching)
        cumulative_refills += sum(spawn["kind"] == "refill" for spawn in matching)
        cumulative_refill_admissions += sum(spawn["kind"] == "refill" and spawn["admitted"] for spawn in matching)
        cumulative_cap_rejections += sum(not spawn["admitted"] for spawn in matching)
        for field, expected_value in (
            ("attempts", cumulative_attempts), ("admissions", cumulative_admissions),
            ("rejected", cumulative_rejected), ("refill_requests", cumulative_refills),
            ("refill_admissions", cumulative_refill_admissions), ("cap_rejections", cumulative_cap_rejections),
        ):
            if row[field] != expected_value:
                errors.append(f"event {row['clock']} index {row['index']} counter {field} is not derived from its attempts")

    tie = [(event["clock"], event["priority"], event["index"]) for event in events if event["tic"] == 18]
    if tie[:2] != [("stage-wave-100ms", 0, 5), ("stage-refill-250ms", 1, 2)]:
        errors.append(f"same-tic deadline tie did not release in priority order: {tie[:2]}")

    # Recompute each row's population from individual attempts, including the
    # explicit tic-17 release. This prevents a forged completion summary or
    # per-event marker from hiding an incorrect admission decision.
    releases = list(RELEASE_RE.finditer(log))
    ledger_errors, derived_alive = validate_attempt_ledger(spawns, releases, expected_mode)
    errors.extend(ledger_errors)

    complete_match = list(COMPLETE_RE.finditer(log))
    if not complete_match:
        errors.append("missing strict P022 completion marker")
        completion: dict[str, Any] | None = None
    else:
        completion = _groups(complete_match[-1])
        if completion["mode"] != expected_mode:
            errors.append(f"completion mode mismatch: expected {expected_mode}, observed {completion['mode']}")
        if completion["tics"] != 70 or completion["engine"] != 70:
            errors.append("completion did not cover exactly 70 unpaused logical/engine tics")
        if completion["attempts"] != len(spawns):
            errors.append("completion attempts do not equal the actual attempt ledger")
        if completion["admissions"] != sum(row["admitted"] for row in spawns):
            errors.append("completion admissions do not equal actual admitted attempts")
        if completion["rejected"] != sum(not row["admitted"] for row in spawns):
            errors.append("completion rejections do not equal actual rejected attempts")
        if completion["refills"] != sum(row["kind"] == "refill" for row in spawns):
            errors.append("completion refills do not equal explicit refill attempts")
        if completion["refill_admissions"] != sum(row["kind"] == "refill" and row["admitted"] for row in spawns):
            errors.append("completion refill admissions do not equal actual refill admissions")
        if completion["cap_rejections"] != completion["rejected"]:
            errors.append("cap rejection accounting does not cover every rejected attempt")
        if completion["native_pause"] != 1:
            errors.append("native pause/resume proof is missing")
        if completion["releases"] != sum(int(match.group("released")) for match in releases):
            errors.append("completion release count does not equal the release ledger")
        if not releases or int(releases[0].group("released")) <= 0:
            errors.append("release ledger did not free a deterministic live slot")
        if releases:
            release_tic = int(releases[0].group("tic"))
            release_after = [event for event in events if event["tic"] > release_tic and event["clock"] == "stage-wave-100ms"]
            if not any(any(spawn["kind"] == "refill" and spawn["admitted"] for spawn in spawns if spawn["clock"] == event["clock"] and spawn["deadline"] == event["deadline"]) for event in release_after):
                errors.append("no refill admission occurred after the deterministic release")
        if completion["region"] != "logical-reference-v1":
            errors.append("completion region identity mismatch")
        if any(completion[key] != derived_alive[clock] for key, clock in (("alive_wave", "stage-wave-100ms"), ("alive_refill", "stage-refill-250ms"), ("alive_event", "stage-event-third"))):
            errors.append("completion populations do not equal the derived attempt/release ledger")
        if completion["next_wave"] <= 1 or completion["next_refill"] <= 1 or completion["next_event"] <= 1:
            errors.append("one or more named clocks emitted no events")

    # A genuine native menu pause has a UI interval while the logical clock is
    # frozen. Paused simulation tics must remain zero and resume cannot burst.
    begin = PAUSE_BEGIN_RE.search(log)
    held = PAUSE_HELD_RE.search(log)
    resume = RESUME_RE.search(log)
    if begin is None or held is None or resume is None:
        errors.append("missing complete native pause/resume transition")
    else:
        if int(held.group(2)) != int(begin.group(2)):
            errors.append("logical simulation advanced between native pause begin and held state")
        if int(resume.group(3)) != 0:
            errors.append("native resume reports logical tic advancement during pause")
        if int(resume.group(2)) != int(held.group(2)):
            errors.append("logical tic changed before native resume was observed")
        if int(resume.group(1)) - int(held.group(1)) < 35:
            errors.append("native pause was not held for a complete UI interval")

    cameras = [_groups(match) for match in CAMERA_RE.finditer(log)]
    if expected_variant is not None:
        if not cameras or cameras[-1]["variant"] != expected_variant:
            errors.append(f"expected camera variant {expected_variant} in actual runtime log")
    elif len({camera["variant"] for camera in cameras}) < 1:
        errors.append("camera presentation trace is missing")

    return {
        "status": "PASS" if not errors else "FAIL",
        "classification": "P022_PACKAGED_UZDOOM_STAGE_SPAWN_RUN",
        "errors": errors,
        "spawn_attempts": len(spawns),
        "timeline_events": len(events),
        "spawn_trace": spawn_trace(log),
        "completion": completion,
        "camera_variants": cameras,
        "native_pause": {"begin": begin.groups() if begin else None, "held": held.groups() if held else None, "resume": resume.groups() if resume else None},
    }


def run_probe(*, package: Path | None = None, seconds: float = 20.0, camera_invariance: bool = True) -> dict[str, Any]:
    if not 8.0 <= seconds <= 120.0:
        raise ValueError("seconds must be between 8 and 120")
    if package is None:
        package = Path(build(ROOT, room_spec=ROOT / "maps/source/p022-spawn/room.json")["package"])
    package = Path(package)
    compile_result = run(package, seconds, True, False, "P022", 60, 1280, 720, map_name="MAP08", completion_marker="DS_P022_COMPLETE")
    if compile_result["status"] != "COMPILE_PASS":
        return {"status": "FAIL", "classification": "P022_PACKAGED_UZDOOM_STAGE_SPAWN_RUN", "errors": ["compile gate failed"], "compile": compile_result}

    variants = range(4) if camera_invariance else range(1)
    runs: list[dict[str, Any]] = []
    for variant in variants:
        runtime = run(
            package, seconds, False, False, "P022", 60, 1280, 720,
            map_name="MAP08", completion_marker="DS_P022_COMPLETE",
            active_in_background=True, vsync=False,
            startup_commands=["+set", "ds_p022_camera_variant", str(variant)],
        )
        log_path = Path(runtime["evidence"]) / "engine.log"
        log = log_path.read_text(encoding="utf-8", errors="replace") if log_path.exists() else ""
        strict = validate(log, expected_variant=variant, expected_mode="normal")
        strict.update({"variant": variant, "runtime": runtime, "engine_log": str(log_path)})
        runs.append(strict)

    # The override is a separate, explicit mode-specific schedule fixture. It
    # changes the wave batch/cap policy and must still preserve the same clock,
    # region, ordering, pause and accounting contracts.
    override_runtime = run(
        package, seconds, False, False, "P022", 60, 1280, 720,
        map_name="MAP08", completion_marker="DS_P022_COMPLETE",
        active_in_background=True, vsync=False,
        startup_commands=["+set", "ds_p022_mode", "override"],
    )
    override_log_path = Path(override_runtime["evidence"]) / "engine.log"
    override_log = override_log_path.read_text(encoding="utf-8", errors="replace") if override_log_path.exists() else ""
    override_strict = validate(override_log, expected_variant=0, expected_mode="override")
    override_strict.update({"variant": 0, "mode": "override", "runtime": override_runtime, "engine_log": str(override_log_path)})
    runs.append(override_strict)

    errors = [f"{run_result.get('mode', 'normal')} variant {run_result['variant']}: {error}" for run_result in runs for error in run_result["errors"]]
    traces = [run_result["spawn_trace"] for run_result in runs if run_result.get("mode", "normal") == "normal"]
    if traces and any(trace != traces[0] for trace in traces[1:]):
        errors.append("camera variants changed admitted spawn identities, times or logical positions")
    if any(run_result["runtime"]["status"] != "RUNTIME_PASS" for run_result in runs):
        errors.append("one or more camera variants did not pass the packaged runtime gate")
    package_sha = hashlib.sha256(package.read_bytes()).hexdigest()
    result = {
        "status": "PASS" if not errors else "FAIL",
        "classification": "P022_PACKAGED_UZDOOM_STAGE_SPAWN_RUN",
        "errors": errors,
        "package": str(package),
        "package_sha256": package_sha,
        "compile": compile_result,
        "runs": runs,
        "camera_invariant_trace": bool(traces) and all(trace == traces[0] for trace in traces[1:]),
        "mode_override_checked": override_strict["status"] == "PASS",
    }
    evidence_dir = ROOT / "evidence" / "P022"
    evidence_dir.mkdir(parents=True, exist_ok=True)
    evidence_path = evidence_dir / "latest-result.json"
    result["evidence"] = str(evidence_path)
    evidence_path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8", newline="\n")
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path)
    parser.add_argument("--seconds", type=float, default=20.0)
    parser.add_argument("--no-camera-invariance", action="store_true")
    parser.add_argument("--validate-log", type=Path)
    parser.add_argument("--variant", type=int)
    parser.add_argument("--mode", choices=["normal", "override"], default="normal")
    args = parser.parse_args(argv)
    if args.validate_log:
        result = validate(args.validate_log.read_text(encoding="utf-8", errors="replace"), expected_variant=args.variant, expected_mode=args.mode)
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0 if result["status"] == "PASS" else 1
    try:
        result = run_probe(package=args.package, seconds=args.seconds, camera_invariance=not args.no_camera_invariance)
    except (OSError, ValueError, RuntimeError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
