"""Strict parser for the packaged P021 MAP07 movement runtime."""
from __future__ import annotations

import math
import re
from pathlib import Path
import argparse
import json


STATE_RE = re.compile(
    r"DS_P021_STATE tic=(?P<tic>\d+) owned=(?P<owned>[01]) menu=(?P<menu>[01]) paused=(?P<paused>[01]) "
    r"x=(?P<x>-?\d+(?:\.\d+)?) y=(?P<y>-?\d+(?:\.\d+)?) view_yaw=(?P<yaw>-?\d+(?:\.\d+)?) "
    r"pitch=(?P<pitch>-?\d+(?:\.\d+)?) forward=(?P<forward>-?\d+(?:\.\d+)?) side=(?P<side>-?\d+(?:\.\d+)?) "
    r"magnitude=(?P<magnitude>-?\d+(?:\.\d+)?) movement_direction=(?P<movement>-?\d+(?:\.\d+)?) "
    r"source_facing_basis=(?P<facing>-?\d+(?:\.\d+)?) attack_basis=(?P<attack>-?\d+(?:\.\d+)?) "
    r"speed_changed_by_look=(?P<speed_changed>[01]) native_movement=(?P<native>[01])"
)
COMPLETE_RE = re.compile(
    r"DS_P021_COMPLETE tics=(?P<tics>\d+) menu_owned_tics=(?P<menu>\d+) paused_tics=(?P<paused>\d+) "
    r"suppressed_tics=(?P<suppressed>\d+) device_changes=(?P<device>\S+) "
    r"logical_xy=\((?P<x>-?\d+(?:\.\d+)?),(?P<y>-?\d+(?:\.\d+)?)\) "
    r"movement_route=ONE_AUTHORITATIVE_BODY_COLLISION source_speed=ENGINEERING_APPROXIMATION "
    r"view_facing_attack=SEPARATE controller=UNTESTED"
)


def normalize_axes(forward: float, side: float) -> tuple[float, float, float]:
    """Clamp the native axes and normalize only when their combined magnitude exceeds one."""
    f = max(-1.0, min(1.0, forward))
    s = max(-1.0, min(1.0, side))
    raw = math.hypot(f, s)
    if raw > 1.0:
        f /= raw
        s /= raw
    return f, s, min(raw, 1.0)


def movement_vector(view_yaw: float, forward: float, side: float) -> tuple[float, float, float, float]:
    """Return logical dx/dy, magnitude and direction in the fp-ground-v1 basis."""
    f, s, magnitude = normalize_axes(forward, side)
    yaw = math.radians(view_yaw)
    right_yaw = math.radians(view_yaw - 90.0)
    dx = math.cos(yaw) * f + math.cos(right_yaw) * s
    dy = math.sin(yaw) * f + math.sin(right_yaw) * s
    direction = math.degrees(math.atan2(dy, dx)) % 360.0 if magnitude > 1e-9 else view_yaw % 360.0
    return dx, dy, magnitude, direction


def input_owned(menu_active: bool, paused: bool) -> bool:
    return not menu_active and not paused


def validate(log: str, package: Path | None = None, require_physical: bool = False) -> dict:
    errors: list[str] = []
    if "DS_ASSERT_FAIL" in log or "VM execution aborted" in log or "Script error" in log:
        errors.append("engine reported a script/assertion failure")
    required = (
        "DS_P021_BOOT map=MAP07",
        "DS_P021_SPEED source_speed=UNAVAILABLE",
        "status=ENGINEERING_APPROXIMATION",
        "DS_P021_DISABLED jump=1 crouch=1 sprint=1 weapon_switch=1 native_attack_movement=1 mandatory_bob_roll=1",
        "controller=UNTESTED_NO_COMPATIBLE_DEVICE",
        "DS_P021_PRESENTATION eye=body_viewheight_41 pitch=VIEW_ONLY bob=DISABLED roll=DISABLED collision=body_xy",
        "DS_P021_CAMERA_ROUTE camera=PLAYER_INFO",
    )
    for marker in required:
        if marker not in log:
            errors.append(f"missing marker: {marker}")
    states = [STATE_RE.search(line) for line in log.splitlines()]
    states = [match for match in states if match]
    if len(states) < 7:
        errors.append("fewer than seven P021 state samples")
    tics = [int(match.group("tic")) for match in states]
    if tics != sorted(set(tics)) or 70 not in tics:
        errors.append("state sample tics are not unique and ordered through tic 70")
    physical_axes = False
    physical_position_change = False
    physical_diagonal = False
    physical_partial = False
    physical_backpedal = False
    physical_pause_or_menu = "DS_P021_UI_PAUSE" in log and "DS_P021_UI_RESUME" in log
    physical_view_change = False
    previous_yaw: float | None = None
    first_position: tuple[float, float] | None = None
    for match in states:
        if match.group("speed_changed") != "0" or match.group("native") != "0":
            errors.append("look or native movement changed the logical movement route")
            break
        f = float(match.group("forward"))
        s = float(match.group("side"))
        raw_magnitude = math.hypot(f, s)
        physical_axes |= raw_magnitude > 0.001
        position = (float(match.group("x")), float(match.group("y")))
        if first_position is None:
            first_position = position
        elif math.hypot(position[0] - first_position[0], position[1] - first_position[1]) > 0.001:
            physical_position_change = True
        physical_diagonal |= abs(f) > 0.05 and abs(s) > 0.05
        physical_partial |= 0.05 < raw_magnitude < 0.99
        physical_backpedal |= f < -0.05
        yaw = float(match.group("yaw"))
        if previous_yaw is not None and abs(yaw - previous_yaw) > 0.1:
            physical_view_change = True
        previous_yaw = yaw
        expected_f, expected_s, expected_magnitude = normalize_axes(f, s)
        if abs(float(match.group("magnitude")) - expected_magnitude) > 0.001:
            errors.append("state magnitude is not the normalized native-axis magnitude")
            break
        if int(match.group("owned")) == 1 and int(match.group("menu")) == 1:
            errors.append("menu-owned state reports gameplay ownership")
            break
        if int(match.group("owned")) == 1 and int(match.group("paused")) == 1:
            errors.append("paused state reports gameplay ownership")
            break
        if abs(float(match.group("facing")) - float(match.group("attack"))) > 0.001:
            errors.append("view-facing attack basis diverged from sampled view yaw")
            break
    complete = COMPLETE_RE.search(log)
    if complete is None:
        errors.append("missing strict P021 completion marker")
    else:
        if int(complete.group("tics")) != 70:
            errors.append("completion did not cover exactly 70 logical tics")
        if complete.group("device") != "INPUTPROCESS_MARKER_ONLY":
            errors.append("device ownership count is not explicitly qualified")
    physical = {
        # Very short physical key/button presses can fall between the 10-tic
        # command samples. A changed authoritative body position is still an
        # observed movement result, but cannot establish the missed direction.
        "movement": physical_axes or physical_position_change,
        "diagonal": physical_diagonal,
        "subunit_native_axis_observed": physical_partial,
        "backpedal": physical_backpedal,
        "view_change": physical_view_change,
        "menu_or_pause": physical_pause_or_menu,
    }
    # A physical mouse/keyboard session can prove movement, diagonal input,
    # backpedal, view change and an ownership boundary. A sub-unit native axis
    # is reserved for controller analog evidence; it must never be inferred
    # from keyboard input or used as a physical controller claim.
    mouse_keyboard = {
        name: physical[name]
        for name in ("movement", "diagonal", "backpedal", "view_change", "menu_or_pause")
    }
    if require_physical:
        missing = [name for name, present in mouse_keyboard.items() if not present]
        if missing:
            errors.append("physical mouse/keyboard proof is incomplete: " + ", ".join(missing))
    result = {"status": "PASS" if not errors else "FAIL", "errors": errors, "state_samples": len(states)}
    result["physical_input_proof"] = "ESTABLISHED_MOUSE_KEYBOARD" if all(mouse_keyboard.values()) else "NOT_ESTABLISHED_ZERO_OR_PARTIAL_INPUT"
    result["controller_analog_proof"] = "UNTESTED_NO_COMPATIBLE_DEVICE"
    result["physical_observations"] = physical
    if package is not None:
        result["package"] = str(package)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, help="reuse a previously built MAP07 package")
    parser.add_argument("--seconds", type=float, default=180.0, help="bounded physical-session duration")
    parser.add_argument("--validate-log", type=Path, help="strictly validate an existing engine.log")
    parser.add_argument("--require-physical", action="store_true", help="fail unless mouse/keyboard movement, view, diagonal, backpedal and menu/pause observations are present")
    parser.add_argument("--interactive", action="store_true", help="leave the native window open for mouse/menu/focus input")
    args = parser.parse_args()
    if args.validate_log:
        result = validate(args.validate_log.read_text(encoding="utf-8", errors="replace"), require_physical=args.require_physical)
        print(json.dumps(result, indent=2))
        return 0 if result["status"] == "PASS" else 1
    from tools.build import ROOT, build
    from tools.run_probe import run

    package = args.package
    if package is None:
        package = Path(build(ROOT, room_spec=ROOT / "maps/source/p021-movement/room.json")["package"])
    result = run(
        package,
        args.seconds,
        compile_only=False,
        interactive=args.interactive,
        evidence_phase="P021",
        max_fps=60,
        window_width=1280,
        window_height=720,
        map_name="MAP07",
        completion_marker="DS_P021_COMPLETE",
        active_in_background=False,
        vsync=False,
    )
    log_path = Path(result["evidence"]) / "engine.log"
    strict = validate(log_path.read_text(encoding="utf-8", errors="replace"), require_physical=args.require_physical or args.interactive) if log_path.exists() else {"status": "FAIL", "errors": ["missing engine.log"]}
    result["p021_validation"] = strict
    print(json.dumps(result, indent=2))
    return 0 if result["status"] == "RUNTIME_PASS" and strict["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
