"""P041 ricochet runtime validators, plus an independent Python reference
reflection-path implementation used by tools/run_p041_bounce.py to cross
check the actual UZDoom MAP27 fixture's DS_P041_BOUNCE sequence (contract
requirement A01: "exact reflection paths ... compared with a Python
reference path computed independently from the same inputs").

Following the tests/runtime/weapons-ballistic/test_p035_ballistic_runtime.py
pattern: the `test_*` functions here exercise the validators/reference
implementation against fixed, hand-checked log text (including one captured
from an actual pinned-UZDoom MAP27 "reflection" run, recorded below), so
pytest itself never launches the engine. The real per-mode engine runs and
their PASS/FAIL verdict JSON are produced separately by
tools/run_p041_bounce.py; a pytest PASS here only proves the parser and the
reference implementation agree with themselves and with one captured
real-engine transcript, not that every mode has been re-run.
"""
from __future__ import annotations

import math
import re

TICRATE = 35
BOUNDARY_HALF_EXTENT = 128.0
MAX_REFLECTIONS_PER_TIC = 8


def _rows(log: str, marker: str) -> list[dict[str, str]]:
    return [
        dict(re.findall(r"([A-Za-z_][A-Za-z0-9_]*)=([^\s]+)", match.group(1)))
        for match in re.finditer(rf"{re.escape(marker)}[ \t]+([^\r\n]*)", log)
    ]


def _int(row: dict[str, str], key: str, default: int | None = None) -> int | None:
    try:
        return int(row[key])
    except (KeyError, TypeError, ValueError):
        return default


def _float(row: dict[str, str], key: str, default: float = math.nan) -> float:
    try:
        return float(row[key])
    except (KeyError, TypeError, ValueError):
        return default


# ---------------------------------------------------------------------------
# Independent Python reference reflection path (A01).
#
# Mirrors src/zscript/weapons/bounce/BounceRuntime.zs's
# DSP041ProcessProjectile boundary/wall sweep exactly, but written from
# scratch in Python rather than shared code, so an agreement between the two
# is real cross-validation rather than the same bug reproduced twice.
# ---------------------------------------------------------------------------
def reference_reflect_path(origin: tuple[float, float], yaw_milli: int,
                            speed_units_per_second: float, duration_tics: int,
                            walls: list[tuple[float, float, float, float]],
                            player_pos: tuple[float, float] = (0.0, 0.0),
                            boundary_half_extent: float = BOUNDARY_HALF_EXTENT,
                            max_reflections_per_tic: int = MAX_REFLECTIONS_PER_TIC,
                            player_pos_at=None
                            ) -> list[dict[str, float | int | str]]:
    """player_pos_at: optional callable(tic) -> (x, y) for a moving-boundary
    reference (P041 item 5); the boundary is recomputed from that tic's
    player position, matching DSP041CurrentBoundary reading the *current*
    playerX/playerY each logical tic. Defaults to the constant player_pos,
    identical to every pre-existing call site."""
    yaw_degrees = (yaw_milli % 360000) / 1000.0
    dir_x = math.cos(math.radians(yaw_degrees))
    dir_y = math.sin(math.radians(yaw_degrees))
    x, y = origin
    previous_player_pos = player_pos_at(1) if player_pos_at is not None else player_pos
    events: list[dict[str, float | int | str]] = []
    for tic in range(1, duration_tics + 1):
        current_player_pos = player_pos_at(tic) if player_pos_at is not None else player_pos
        if player_pos_at is not None and tic > 1:
            # DSP041Rebase translates every live projectile's own position by
            # exactly the player's own movement delta (age/ledger/bounce
            # counts untouched); a player_pos_at that changes between two
            # tics models exactly that rebase, so the reference's tracked
            # (x, y) must shift by the same delta or its trajectory silently
            # diverges from the real (rebased) one from that tic on.
            shift_x = current_player_pos[0] - previous_player_pos[0]
            shift_y = current_player_pos[1] - previous_player_pos[1]
            x += shift_x
            y += shift_y
        previous_player_pos = current_player_pos
        step = speed_units_per_second / TICRATE
        remaining_x = dir_x * step
        remaining_y = dir_y * step
        reflections = 0
        while reflections < max_reflections_per_tic:
            end_x = x + remaining_x
            end_y = y + remaining_y
            min_x = current_player_pos[0] - boundary_half_extent
            max_x = current_player_pos[0] + boundary_half_extent
            min_y = current_player_pos[1] - boundary_half_extent
            max_y = current_player_pos[1] + boundary_half_extent
            dx = end_x - x
            dy = end_y - y
            fx = 2.0
            if dx > 1e-7:
                fx = (max_x - x) / dx
            elif dx < -1e-7:
                fx = (min_x - x) / dx
            fy = 2.0
            if dy > 1e-7:
                fy = (max_y - y) / dy
            elif dy < -1e-7:
                fy = (min_y - y) / dy
            if fx < 0.0 or fx > 1.0:
                fx = 2.0
            if fy < 0.0 or fy > 1.0:
                fy = 2.0
            boundary_fraction = min(fx, fy)
            crosses_boundary = boundary_fraction <= 1.0

            wall_id = None
            wall_fraction = 2.0
            wall_normal = (0.0, 0.0)
            for index, (wsx, wsy, wex, wey) in enumerate(walls, start=1):
                rx, ry = dx, dy
                sx, sy = wex - wsx, wey - wsy
                denominator = rx * sy - ry * sx
                if denominator == 0.0:
                    continue
                qx, qy = wsx - x, wsy - y
                t = (qx * sy - qy * sx) / denominator
                u = (qx * ry - qy * rx) / denominator
                # t's lower bound uses a small epsilon, not 0.0 -- mirrors
                # BounceRuntime.zs's DSP041LineIntersection fix: a segment
                # that starts exactly on the wall's line (left behind by the
                # previous tic's own reflection off it) otherwise satisfies
                # t == 0 for every direction, including one moving away.
                if t <= 1e-7 or t > 1.0 or u < 0.0 or u > 1.0:
                    continue
                better = wall_id is None or t < wall_fraction or (t == wall_fraction and index < wall_id)
                if not better:
                    continue
                wall_fraction = t
                wall_id = index
                length = math.hypot(sx, sy)
                if length > 1e-7:
                    wall_normal = (-sy / length, sx / length)

            best_fraction = 2.0
            if crosses_boundary and boundary_fraction < best_fraction:
                best_fraction = boundary_fraction
            if wall_id is not None and wall_fraction < best_fraction:
                best_fraction = wall_fraction
            if best_fraction > 1.0:
                x, y = end_x, end_y
                break

            hit_x = x + remaining_x * best_fraction
            hit_y = y + remaining_y * best_fraction
            take_boundary = crosses_boundary and boundary_fraction <= best_fraction + 1e-7
            take_wall = wall_id is not None and wall_fraction <= best_fraction + 1e-7

            if take_boundary:
                axis_x = fx <= best_fraction + 1e-7 and fx < 2.0
                axis_y = fy <= best_fraction + 1e-7 and fy < 2.0
                new_dir_x = -remaining_x if axis_x else remaining_x
                new_dir_y = -remaining_y if axis_y else remaining_y
                events.append({"tic": tic, "kind": "BOUNDARY", "axis_x": int(axis_x),
                               "axis_y": int(axis_y), "fraction": best_fraction,
                               "x": hit_x, "y": hit_y})
            elif take_wall:
                nx, ny = wall_normal
                dot = remaining_x * nx + remaining_y * ny
                new_dir_x = remaining_x - 2.0 * dot * nx
                new_dir_y = remaining_y - 2.0 * dot * ny
                events.append({"tic": tic, "kind": "WALL", "wall_id": wall_id,
                               "fraction": best_fraction, "x": hit_x, "y": hit_y})
            else:
                break

            length = math.hypot(new_dir_x, new_dir_y)
            if length > 1e-7:
                dir_x, dir_y = new_dir_x / length, new_dir_y / length
            remaining_fraction = 1.0 - best_fraction
            remaining_x = new_dir_x * remaining_fraction
            remaining_y = new_dir_y * remaining_fraction
            x, y = hit_x, hit_y
            reflections += 1
        else:
            x, y = end_x, end_y
    return events


def validate_p041_reflection_matches_reference(log: str, run_status: str,
                                                 walls: list[tuple[float, float, float, float]],
                                                 player_pos: tuple[float, float] = (0.0, 0.0),
                                                 tolerance: float = 0.01) -> dict:
    errors: list[str] = []
    if run_status not in ("COMPLETE", "COMPILE_PASS", "OK", "TIMEOUT"):
        errors.append(f"unexpected run status: {run_status}")
    spawns = _rows(log, "DS_P041_PROJECTILE")
    if len(spawns) != 1:
        errors.append("expected exactly one spawned projectile for the reflection fixture")
        return {"errors": errors}
    spawn = spawns[0]
    yaw_milli = _int(spawn, "aim_yaw_milli", 0)
    speed = _float(spawn, "speed_ups")
    duration = _int(spawn, "duration_tics", 0)
    bounce_rows = _rows(log, "DS_P041_BOUNCE")
    actual = [{
        "tic": _int(row, "tic"), "kind": row.get("kind"),
        "axis_x": _int(row, "axis_x"), "axis_y": _int(row, "axis_y"),
        "wall_id": _int(row, "wall_id"),
        "fraction": _float(row, "fraction"), "x": _float(row, "x"), "y": _float(row, "y"),
    } for row in bounce_rows]
    reference = reference_reflect_path((0.0, 0.0), yaw_milli, speed, duration,
                                        walls, player_pos)
    if len(actual) != len(reference):
        errors.append(f"bounce event count diverged: engine={len(actual)} reference={len(reference)}")
        return {"errors": errors, "actual": actual, "reference": reference}
    for index, (a, r) in enumerate(zip(actual, reference)):
        if a["tic"] != r["tic"] or a["kind"] != r["kind"]:
            errors.append(f"event {index}: tic/kind diverged: {a} != {r}")
            continue
        if abs(a["x"] - r["x"]) > tolerance or abs(a["y"] - r["y"]) > tolerance:
            errors.append(f"event {index}: position diverged beyond tolerance: {a} != {r}")
        if abs(a["fraction"] - r["fraction"]) > tolerance:
            errors.append(f"event {index}: fraction diverged beyond tolerance: {a} != {r}")
    return {"errors": errors, "actual": actual, "reference": reference}


# ---------------------------------------------------------------------------
# Unit tests against a captured real-engine transcript.
#
# This transcript was captured from an actual pinned-UZDoom MAP27 run of the
# "reflection" mode (single Runetracer rank 1, wall segment x=60 from
# y=-200..200, boundary +/-128 around the stationary player at the origin).
# ---------------------------------------------------------------------------
CAPTURED_REFLECTION_LOG = """
DS_P041_MAP27_BOOT accepted=1 mode=reflection player_slot=0 camera_variant=0 classification=CONTROLLED_ENGINE_FIXTURE
DS_P041_PROJECTILE event_id=4100001 tic=1 system_id=54 rank=1 ordinal=0 aim_yaw_milli=105680 speed_ups=240.000000 damage_milli=10000 might_milli=1000 area_milli=1000 contact_radius_milli=6000 bounce_budget=-1 duration_tics=79 pierces_enemies=1 bounces_off_enemies=0 rng_before=410401 rng_after=-1003657968 rng_stream=DEDICATED_P041_BOUNCE launch_rule=DEDICATED_STREAM_LABELLED native_motion=VISUAL_ONLY
DS_P041_BOUNCE event_id=4100001 tic=20 kind=BOUNDARY axis_x=0 axis_y=1 fraction=0.388176 x=-35.931 y=128.000
DS_P041_BOUNCE event_id=4100001 tic=59 kind=BOUNDARY axis_x=0 axis_y=1 fraction=0.164527 x=-107.793 y=-128.000
DS_P041_BOUNCE event_id=4100001 tic=70 kind=BOUNDARY axis_x=1 axis_y=0 fraction=0.068173 x=-128.000 y=-56.015
DS_P041_MAP27_COMPLETE mode=reflection tic=120 emitted=1 skipped=0 accepted_hits=0 rejected_hits=0 hash=1469598103 camera_variant=0 classification=CONTROLLED_ENGINE_FIXTURE
"""

FIXTURE_WALLS = [(60.0, -200.0, 60.0, 200.0)]


def test_reference_reflection_matches_captured_engine_transcript() -> None:
    result = validate_p041_reflection_matches_reference(
        CAPTURED_REFLECTION_LOG, "COMPLETE", FIXTURE_WALLS)
    assert result["errors"] == [], result["errors"]
    assert len(result["actual"]) == 3
    assert [row["kind"] for row in result["actual"]] == ["BOUNDARY", "BOUNDARY", "BOUNDARY"]


def test_reference_reflection_detects_a_diverged_transcript() -> None:
    tampered = CAPTURED_REFLECTION_LOG.replace("x=-128.000 y=-56.015", "x=-128.000 y=-90.000")
    result = validate_p041_reflection_matches_reference(tampered, "COMPLETE", FIXTURE_WALLS)
    assert result["errors"] != []


def test_reference_reflection_detects_a_missing_event() -> None:
    lines = [line for line in CAPTURED_REFLECTION_LOG.splitlines()
             if "tic=59" not in line]
    truncated = "\n".join(lines)
    result = validate_p041_reflection_matches_reference(truncated, "COMPLETE", FIXTURE_WALLS)
    assert result["errors"] != []


def test_reference_reflection_hits_the_wall_when_aimed_at_it() -> None:
    # Independent sanity check of the reference implementation itself: aim
    # straight at the fixture wall (yaw 0 = +X) and confirm a WALL bounce is
    # produced at the expected x=60 crossing before any boundary bounce.
    events = reference_reflect_path((0.0, 0.0), 0, 240.0, 40, FIXTURE_WALLS)
    assert events, "expected at least one bounce event when aimed at the wall"
    assert events[0]["kind"] == "WALL"
    assert abs(events[0]["x"] - 60.0) < 0.01


def test_reference_reflection_reflects_exact_corner_on_both_axes() -> None:
    # A launch aimed at the exact top-right corner of the +/-128 boundary
    # (no wall in range) must reflect both velocity components per the
    # contract's corner rule.
    events = reference_reflect_path((0.0, 0.0), 45000, 240.0, 30, [])
    assert events, "expected a boundary bounce at the corner"
    corner = events[0]
    assert corner["kind"] == "BOUNDARY"
    assert corner["axis_x"] == 1 and corner["axis_y"] == 1
    assert abs(corner["x"] - 128.0) < 0.01
    assert abs(corner["y"] - 128.0) < 0.01
