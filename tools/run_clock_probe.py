"""Build and run the MAP03 P014 timing probe at two requested render caps."""
from __future__ import annotations

import argparse
import json
import re
import sys
from fractions import Fraction
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.build import ROOT, build
from tools.run_probe import run
from tools.timing.scheduler import ClockSpec, RationalClock, RationalScheduler


EVENT_RE = re.compile(
    r"DS_P014_EVENT clock=(\S+) priority=(\d+) event_index=(\d+) "
    r"simulation_tic=(\d+) engine_world_tick=(\d+)"
)
MODAL_RE = re.compile(
    r"DS_P014_MODAL_(BEGIN|END) kind=(\S+) engine_world_tick=(\d+) simulation_tic=(\d+)"
)
COMPLETE_RE = re.compile(
    r"DS_P014_COMPLETE engine_world_ticks=(\d+) simulation_tics=(\d+) "
    r"events_100ms=(\d+) events_250ms=(\d+) events_third=(\d+) "
    r"modal_backlog=0 render_frames=(\S+) input_observations=(\S+)"
)
UI_RE = re.compile(r"DS_P014_UI_OBSERVATION ui_ticks=(\d+)")
RENDER_RE = re.compile(r"DS_P014_RENDER_OBSERVATION render_frames=(\d+)")
INPUT_RE = re.compile(r"DS_P014_INPUT_OBSERVATION input_events=(\d+)")
MEASURED_RE = re.compile(r"DS_P014_RENDER_MEASURED frames=(\d+) elapsed_ms=([0-9.]+)")
NATIVE_PAUSE_RE = re.compile(
    r"DS_P014_NATIVE_PAUSE_BEGIN ui_ticks=(\d+) engine_world_tick=(\d+) simulation_tic=(\d+)"
)
NATIVE_RESUME_RE = re.compile(
    r"DS_P014_NATIVE_RESUME ui_ticks=(\d+) engine_world_tick=(\d+) simulation_tic=(\d+) "
    r"paused_engine_ticks=(\d+) paused_sim_ticks=(\d+)"
)

CLOCK_SPECS = (
    ClockSpec("100ms", RationalClock(Fraction(1, 10)), 0, 94),
    ClockSpec("250ms", RationalClock(Fraction(1, 4)), 1, 37),
    ClockSpec("third", RationalClock(Fraction(1, 3)), 2, 28),
)


def expected_events() -> list[tuple[str, int, int, int, int]]:
    """Return ``clock, priority, index, simulation_tic, engine_tick`` tuples."""

    scheduler = RationalScheduler(CLOCK_SPECS)
    events = []
    for engine_tick in range(1, 351):
        paused = 72 <= engine_tick <= 81 or 100 <= engine_tick <= 109
        for event in scheduler.accept_world_tick(paused=paused):
            events.append((event.clock_name, event.priority, event.event_index,
                           event.simulation_tic, engine_tick))
    return events


EXPECTED_EVENTS = expected_events()


def validate(log: str) -> dict:
    observed = [
        (clock, int(priority), int(index), int(simulation_tic), int(engine_tick))
        for clock, priority, index, simulation_tic, engine_tick in EVENT_RE.findall(log)
    ]
    errors: list[str] = []
    required_markers = (
        "DS_P014_BEGIN map=MAP03 ticrate=35",
        "clock_model=CEIL_ABSOLUTE_DEADLINE",
        "DS_P014_SOURCE_FACT ticrate=35 worldtick=VALID_LEVEL_UNPAUSED uitick=ALWAYS",
        "input=InputProcess render=RenderOverlay",
    )
    for marker in required_markers:
        if marker not in log:
            errors.append(f"missing marker: {marker}")
    if observed != EXPECTED_EVENTS:
        errors.append(
            f"deadline trace mismatch: expected {len(EXPECTED_EVENTS)} events, observed {len(observed)}"
        )
        for position, (expected, actual) in enumerate(zip(EXPECTED_EVENTS, observed)):
            if expected != actual:
                errors.append(f"first event mismatch at {position}: expected {expected}, observed {actual}")
                break
    modal = [
        (kind, phase, int(engine_tick), int(simulation_tic))
        for phase, kind, engine_tick, simulation_tic in MODAL_RE.findall(log)
    ]
    expected_modal = [
        ("level_up", "BEGIN", 72, 71),
        ("level_up", "END", 82, 71),
        ("chest", "BEGIN", 100, 89),
        ("chest", "END", 110, 89),
    ]
    if modal != expected_modal:
        errors.append(f"modal trace mismatch: expected {expected_modal}, observed {modal}")
    completion = COMPLETE_RE.search(log)
    completion_data = None
    if completion is None:
        errors.append("missing P014 completion marker")
    else:
        engine_ticks, simulation_tics, events_100ms, events_250ms, events_third, render_frames, input_observations = completion.groups()
        completion_data = {
            "engine_world_ticks": int(engine_ticks),
            "simulation_tics": int(simulation_tics),
            "events_100ms": int(events_100ms),
            "events_250ms": int(events_250ms),
            "events_third": int(events_third),
            "render_frames": render_frames,
            "input_observations": input_observations,
            "ui_context_counters_are_separate": True,
            "input_physics_limit": "35HZ_BOUNDARY",
            "render_fps_observed": "NOT_MEASURED",
        }
        if (int(engine_ticks), int(simulation_tics), int(events_100ms), int(events_250ms), int(events_third)) != (350, 330, 94, 37, 28):
            errors.append(f"completion counters mismatch: {(engine_ticks, simulation_tics, events_100ms, events_250ms, events_third)}")
    if "DS_ASSERT_FAIL" in log:
        errors.append("runtime assertion failure")
    # A VM abort kills the event handler mid-run. The completion marker can
    # already be on stdout when that happens, so a truncated trace must fail
    # closed instead of being reported as a passing timing probe.
    for failure in ("VM execution aborted", "Script error", "Unknown identifier"):
        if failure in log:
            errors.append(f"runtime vm failure: {failure}")
    if "DS_P014_UI_WINDOW_COMPLETE ui_ticks=350" not in log:
        errors.append("missing UI window completion marker")
    measured = MEASURED_RE.search(log)
    measured_render = None
    if measured is None:
        errors.append("missing measured render observation")
    else:
        frames = int(measured.group(1))
        elapsed_ms = float(measured.group(2))
        if elapsed_ms <= 0:
            errors.append("measured render window must be positive")
        else:
            measured_render = {
                "frames": frames,
                "elapsed_ms": round(elapsed_ms, 1),
                "measured_fps": round(frames / (elapsed_ms / 1000.0), 1),
            }
    # P014-A02: a real engine pause must freeze logical time while the UI clock
    # keeps running, and resuming must not replay or burst the withheld events.
    pause_begin = NATIVE_PAUSE_RE.search(log)
    pause_resume = NATIVE_RESUME_RE.search(log)
    native_pause = None
    if pause_begin is None or pause_resume is None:
        errors.append("missing native pause/resume cycle")
    else:
        paused_engine_ticks = int(pause_resume.group(4))
        paused_sim_ticks = int(pause_resume.group(5))
        native_pause = {
            "begin_ui_ticks": int(pause_begin.group(1)),
            "resume_ui_ticks": int(pause_resume.group(1)),
            "paused_engine_ticks": paused_engine_ticks,
            "paused_sim_ticks": paused_sim_ticks,
        }
        if paused_engine_ticks != 0:
            errors.append(f"engine world tick advanced during native pause: {paused_engine_ticks}")
        if paused_sim_ticks != 0:
            errors.append(f"logical simulation advanced during native pause: {paused_sim_ticks}")
        if native_pause["resume_ui_ticks"] <= native_pause["begin_ui_ticks"]:
            errors.append("native pause never released")
    return {
        "status": "PASS" if not errors else "FAIL",
        "events": observed,
        "expected_event_count": len(EXPECTED_EVENTS),
        "modal_trace": modal,
        "completion": completion_data,
        "errors": errors,
        "source_parity": "OPEN_SYNTHETIC_ENGINE_PROBE",
        "physical_input_verified": False,
        "ui_observation_ticks": [int(value) for value in UI_RE.findall(log)],
        "render_observation_frames": [int(value) for value in RENDER_RE.findall(log)],
        "input_observation_events": [int(value) for value in INPUT_RE.findall(log)],
        "ui_window_complete": "DS_P014_UI_WINDOW_COMPLETE ui_ticks=350" in log,
        "measured_render": measured_render,
        "native_pause": native_pause,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--interactive", action="store_true", help="keep each run open for native input checks")
    parser.add_argument("--seconds", type=float, default=20)
    args = parser.parse_args()
    if not 5 <= args.seconds <= 600:
        parser.error("--seconds must be between 5 and 600")
    room_spec = ROOT / "maps/source/timing/room.json"
    package = Path(build(ROOT, room_spec=room_spec)["package"])
    rows = []
    for max_fps in (30, 144):
        runtime = run(
            package, args.seconds, False, args.interactive, "P014", max_fps,
            1280, 720, map_name="MAP03", completion_marker="DS_P014_COMPLETE",
            active_in_background=not args.interactive, vsync=False,
        )
        evidence = Path(runtime["evidence"])
        log = (evidence / "engine.log").read_text(encoding="utf-8", errors="replace")
        result = validate(log)
        result.update({
            "classification": "P014_RUNTIME_TIMING_PROBE",
            "requested_max_fps": max_fps,
            "runtime_status": runtime["status"],
            "package_sha256": runtime["package_sha256"],
            "engine_sha256": runtime["engine_sha256"],
            "source_commit": runtime["source_commit"],
            "captures": runtime["captures"],
            "requested_render_cap_is_not_achieved_fps": True,
            "evidence": str(evidence),
        })
        (evidence / "timing-result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        rows.append(result)
    aggregate = {
        "status": "PASS" if all(row["status"] == "PASS" and row["runtime_status"] == "RUNTIME_PASS" for row in rows) else "FAIL",
        "classification": "P014_RUNTIME_TIMING_PROBE",
        "requested_render_caps": [30, 144],
        "requested_render_cap_is_not_achieved_fps": True,
        "runs": rows,
    }
    print(json.dumps(aggregate, indent=2))
    return 0 if aggregate["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
