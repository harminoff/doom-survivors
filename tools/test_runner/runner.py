"""Run deterministic P019 scenarios in the packaged UZDoom executable.

The runner is intentionally a thin process/evidence boundary. Gameplay state,
input application, counters and canonical hashing live in ``P019Harness.zs``;
this module only selects a scenario, captures logs and validates the contract.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import platform
import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from tools.build import build
from tools.run_probe import run

SCENARIOS = (
    "hash_replay",
    "camera_invariance",
    "telemetry_neutrality",
    "wrong_damage",
    "missing_completion",
)
SUCCESS_SCENARIOS = {"hash_replay", "camera_invariance", "telemetry_neutrality"}
FAULT_SCENARIOS = {"wrong_damage", "missing_completion"}
COMPLETE_RE = re.compile(
    r"DS_P019_COMPLETE scenario=(?P<scenario>\S+) input_tape=(?P<tape>\S+) "
    r"telemetry=(?P<telemetry>[01]) tics=(?P<tics>\d+) "
    r"canonical_hash=(?P<hash>-?\d+) rng=\((?P<spawn>-?\d+),(?P<attack>-?\d+),(?P<drop>-?\d+),(?P<draft>-?\d+)\) "
    r"spawn_attempts=(?P<spawn_attempts>\d+) spawn_admissions=(?P<spawn_admissions>\d+) "
    r"alive=(?P<alive>\d+) attacks=(?P<attacks>\d+) hits=(?P<hits>\d+) "
    r"damage=(?P<damage>\d+) xp=(?P<xp>\d+) drops=(?P<drops>\d+) "
    r"drafts=(?P<drafts>\d+) durable=(?P<durable>\d+) offscreen=(?P<offscreen>\d+) "
    r"camera_is_presentation=true"
)
STATE_RE = re.compile(
    r"DS_P019_STATE tic=(?P<tic>\d+) hash=(?P<hash>-?\d+) "
    r"player=\((?P<x>-?\d+\.\d+),(?P<y>-?\d+\.\d+)\) "
    r"alive=(?P<alive>\d+) spawn_attempts=(?P<spawn_attempts>\d+) "
    r"spawn_admissions=(?P<spawn_admissions>\d+) attacks=(?P<attacks>\d+) "
    r"hits=(?P<hits>\d+) damage=(?P<damage>\d+) xp=(?P<xp>\d+) "
    r"drops=(?P<drops>\d+) drafts=(?P<drafts>\d+) durable=(?P<durable>\d+) "
    r"rng=\((?P<spawn>-?\d+),(?P<attack>-?\d+),(?P<drop>-?\d+),(?P<draft>-?\d+)\) "
    r"offscreen=(?P<offscreen>\d+)"
)
CANONICAL_TRACE_RE = re.compile(r"DS_P019_CANONICAL_TRACE tic=(?P<tic>\d+) hash=(?P<hash>-?\d+)")
CAMERA_RE = re.compile(
    r"DS_P019_CAMERA tic=(?P<tic>\d+) yaw=(?P<yaw>-?\d+\.\d+) "
    r"pitch=(?P<pitch>-?\d+\.\d+) fov=(?P<fov>-?\d+\.\d+) "
    r"offscreen=(?P<offscreen>\d+) canonical_hash=(?P<hash>-?\d+)"
)


def _int_groups(match: re.Match[str]) -> dict[str, Any]:
    values: dict[str, Any] = {}
    for key, value in match.groupdict().items():
        if key in {"scenario", "tape"}:
            values[key] = value
        elif key in {"x", "y", "yaw", "pitch", "fov"}:
            values[key] = float(value)
        elif key in {"hash", "spawn", "attack", "drop", "draft"}:
            values[key] = int(value)
        else:
            values[key] = int(value)
    return values


def completion(log: str) -> dict[str, Any] | None:
    matches = list(COMPLETE_RE.finditer(log))
    return _int_groups(matches[-1]) if matches else None


def state_trace(log: str) -> list[dict[str, Any]]:
    trace = []
    for match in STATE_RE.finditer(log):
        row = _int_groups(match)
        row["x"] = float(match.group("x"))
        row["y"] = float(match.group("y"))
        trace.append(row)
    return trace


def canonical_trace(log: str) -> list[dict[str, int]]:
    return [{"tic": int(match.group("tic")), "hash": int(match.group("hash"))}
            for match in CANONICAL_TRACE_RE.finditer(log)]


def _common_errors(log: str) -> list[str]:
    errors: list[str] = []
    for marker in ("VM execution aborted", "Script error", "Unknown identifier", "Execution could not continue"):
        if marker in log:
            errors.append(f"engine failure: {marker}")
    return errors


def validate_log(log: str, scenario: str, *, expected_failure: bool = False,
                 telemetry: int | None = None, require_visual: bool = False) -> dict[str, Any]:
    """Validate one captured P019 engine log, failing closed on omissions."""
    errors = _common_errors(log)
    expected_boot = f"DS_P019_BOOT map=MAP05 ticrate=35 scenario={scenario}"
    for marker in (expected_boot, "DS_P019_CANONICAL schema=gameplay-v1",
                   "execution=REALTIME"):
        if marker not in log:
            errors.append(f"missing marker: {marker}")
    hash_trace = canonical_trace(log)

    if expected_failure and scenario == "wrong_damage":
        if "DS_P019_DAMAGE expected=3 observed=4" not in log:
            errors.append("wrong damage mutation was not observed")
        if "DS_ASSERT_FAIL wrong_damage_detected" not in log:
            errors.append("engine did not assert on wrong damage")
        if completion(log) is not None:
            errors.append("wrong damage run incorrectly completed")
        return {
            "status": "PASS" if not errors else "FAIL",
            "scenario": scenario,
            "expected_failure": True,
            "failure_kind": "assertion",
            "errors": errors,
            "trace": state_trace(log),
            "canonical_trace": hash_trace,
            "completion": None,
        }

    if expected_failure and scenario == "missing_completion":
        if "DS_P019_INTENTIONAL_MISSING_COMPLETION" not in log:
            errors.append("missing-completion fixture did not reach its bounded end")
        if "DS_P019_COMPLETE" in log:
            errors.append("missing-completion fixture emitted completion")
        return {
            "status": "PASS" if not errors else "FAIL",
            "scenario": scenario,
            "expected_failure": True,
            "failure_kind": "completion_timeout",
            "errors": errors,
            "trace": state_trace(log),
            "canonical_trace": hash_trace,
            "completion": None,
        }

    if len(hash_trace) < 12:
        errors.append(f"expected 12 canonical hash snapshots, observed {len(hash_trace)}")

    row = completion(log)
    if row is None:
        errors.append("missing P019 completion marker")
    else:
        if row["scenario"] != scenario:
            errors.append(f"completion scenario mismatch: {row['scenario']}")
        if row["tape"] != "spiral-v1":
            errors.append(f"unexpected input tape: {row['tape']}")
        if row["tics"] != 120:
            errors.append(f"expected 120 logical tics, observed {row['tics']}")
        if telemetry is not None and row["telemetry"] != telemetry:
            errors.append(f"telemetry marker mismatch: expected {telemetry}, observed {row['telemetry']}")
        expected = {
            "spawn_attempts": 4, "spawn_admissions": 4, "alive": 0,
            "attacks": 17, "hits": 16, "damage": 48, "xp": 48,
            "drops": 4, "drafts": 2, "durable": 2, "offscreen": 2,
        }
        for key, value in expected.items():
            if row.get(key) != value:
                errors.append(f"counter {key}: expected {value}, observed {row.get(key)}")

    trace = state_trace(log)
    if telemetry:
        if len(trace) < 12:
            errors.append(f"telemetry enabled but only {len(trace)} state snapshots were emitted")
    elif telemetry == 0 and trace:
        errors.append("telemetry disabled but state snapshots were emitted")
    if scenario == "camera_invariance":
        if "DS_P019_FRAMEBUFFER_CAPTURE scenario=camera_invariance tic=60" not in log:
            errors.append("camera scenario did not request its first-person framebuffer capture")
        cameras = [_int_groups(match) for match in CAMERA_RE.finditer(log)]
        if len(cameras) != 6:
            errors.append(f"expected six camera/FOV observations, observed {len(cameras)}")
        if len({row["hash"] for row in cameras}) != 6:
            errors.append("camera fixture did not expose changing canonical snapshots")
        if any(row["offscreen"] != 2 for row in cameras):
            errors.append("offscreen state changed with camera settings")
    return {
        "status": "PASS" if not errors else "FAIL",
        "scenario": scenario,
        "expected_failure": False,
        "errors": errors,
        "trace": trace,
        "canonical_trace": hash_trace,
        "completion": row,
    }


def _runtime_metadata(runtime: dict[str, Any], *, scenario: str, tape: str, telemetry: int) -> dict[str, Any]:
    return {
        "scenario": scenario,
        "input_tape": tape,
        "input_tape_sha256": hashlib.sha256(tape.encode("utf-8")).hexdigest(),
        "telemetry_requested": bool(telemetry),
        "execution_mode": runtime.get("execution_mode", "realtime"),
        "logical_accelerated": bool(runtime.get("logical_accelerated", False)),
        "visual_capture": bool(runtime.get("visual_capture", False)),
        "gui_status": "SUPPORTED_CAPTURE" if runtime.get("captures") else "UNSUPPORTED",
        "package_sha256": runtime["package_sha256"],
        "engine_sha256": runtime["engine_sha256"],
        "source_commit": runtime["source_commit"],
        "runtime_status": runtime["status"],
        "evidence": runtime["evidence"],
        "captures": runtime.get("captures", []),
        "command": runtime.get("command", []),
    }


def compare_engine_runs(first: dict[str, Any], second: dict[str, Any], *, label: str) -> dict[str, Any]:
    """Compare canonical output from two completed real-engine runs."""
    first_completion = first.get("completion") or {}
    second_completion = second.get("completion") or {}
    errors: list[str] = []
    first_trace = first.get("canonical_trace", [])
    second_trace = second.get("canonical_trace", [])
    if not first_trace or not second_trace:
        errors.append(f"{label} comparison is missing a canonical hash trace")
    elif first_trace != second_trace:
        errors.append(f"{label} changed the normalized canonical hash trace")
    if first_completion.get("hash") is None or second_completion.get("hash") is None:
        errors.append(f"{label} comparison is missing a final canonical hash")
    elif first_completion.get("hash") != second_completion.get("hash"):
        errors.append(f"{label} changed the final canonical hash")
    first_rng = tuple(first_completion.get(key) for key in ("spawn", "attack", "drop", "draft"))
    second_rng = tuple(second_completion.get(key) for key in ("spawn", "attack", "drop", "draft"))
    if first_rng != second_rng:
        errors.append(f"{label} changed gameplay RNG state")
    for field, display in (("package_sha256", "package"), ("engine_sha256", "engine"),
                           ("source_commit", "engine source")):
        first_value = first.get(field)
        second_value = second.get(field)
        if first_value is not None and second_value is not None and first_value != second_value:
            errors.append(f"{label} changed {display} identity")
    return {
        "canonical_trace_equal": bool(first_trace) and first_trace == second_trace,
        "canonical_hash_a": first_completion.get("hash"),
        "canonical_hash_b": second_completion.get("hash"),
        "rng_a": first_rng,
        "rng_b": second_rng,
        "errors": errors,
    }


def finalize_result(result: dict[str, Any]) -> dict[str, Any]:
    """Recompute status after runtime metadata and gate errors are attached."""
    result["status"] = "PASS" if not result.get("errors") else "FAIL"
    return result


def ensure_package_identity(result: dict[str, Any], expected_sha256: str, *, label: str) -> dict[str, Any]:
    """Keep every runtime result bound to the package that passed compilation."""
    actual_sha256 = result.get("package_sha256")
    if actual_sha256 != expected_sha256:
        result.setdefault("errors", []).append(
            f"{label} package identity changed: expected {expected_sha256}, observed {actual_sha256}"
        )
        finalize_result(result)
    return result


def _run_one(package: Path, *, scenario: str, tape: str, telemetry: int,
             seconds: float, require_visual: bool) -> dict[str, Any]:
    runtime = run(
        package, seconds, False, False, "P019", 60, 1280, 720,
        map_name="MAP05", completion_marker="DS_P019_COMPLETE",
        active_in_background=True, vsync=True,
        startup_commands=[
            "+ds_p019_scenario", scenario,
            "+ds_p019_input_tape", tape,
            "+ds_p019_telemetry", str(telemetry),
        ],
    )
    evidence = Path(runtime["evidence"])
    log = (evidence / "engine.log").read_text(encoding="utf-8", errors="replace")
    parsed = validate_log(log, scenario, telemetry=telemetry, require_visual=require_visual)
    if runtime["status"] != "RUNTIME_PASS":
        parsed["errors"].append(f"runtime status was {runtime['status']}")
    if require_visual and not runtime.get("captures"):
        parsed["errors"].append("required framebuffer capture is missing")
    finalize_result(parsed)
    parsed.update(_runtime_metadata(runtime, scenario=scenario, tape=tape, telemetry=telemetry))
    parsed["evidence"] = str(evidence)
    (evidence / "p019-result.json").write_text(json.dumps(parsed, indent=2) + "\n", encoding="utf-8")
    return parsed


def _run_fault(package: Path, *, scenario: str, tape: str, seconds: float) -> dict[str, Any]:
    runtime = run(
        package, seconds, False, False, "P019", 60, 1280, 720,
        map_name="MAP05", completion_marker="DS_P019_COMPLETE",
        active_in_background=True, vsync=True,
        startup_commands=[
            "+ds_p019_scenario", scenario,
            "+ds_p019_input_tape", tape,
            "+ds_p019_telemetry", "1",
        ],
    )
    evidence = Path(runtime["evidence"])
    log = (evidence / "engine.log").read_text(encoding="utf-8", errors="replace")
    parsed = validate_log(log, scenario, expected_failure=True, telemetry=1)
    wanted_status = "ASSERTION_FAILURE" if scenario == "wrong_damage" else "TIMEOUT"
    if runtime["status"] != wanted_status:
        parsed["errors"].append(f"fault status was {runtime['status']}, expected {wanted_status}")
    finalize_result(parsed)
    parsed.update(_runtime_metadata(runtime, scenario=scenario, tape=tape, telemetry=1))
    parsed["expected_runtime_status"] = wanted_status
    parsed["evidence"] = str(evidence)
    (evidence / "p019-result.json").write_text(json.dumps(parsed, indent=2) + "\n", encoding="utf-8")
    return parsed


def run_harness(*, scenario: str = "hash_replay", package: Path | None = None,
                seconds: float = 12.0, no_build: bool = False,
                tape: str = "spiral-v1") -> dict[str, Any]:
    if scenario not in SCENARIOS:
        raise ValueError(f"unsupported scenario: {scenario}")
    if not 5.0 <= seconds <= 120.0:
        raise ValueError("seconds must be between 5 and 120")
    if tape != "spiral-v1":
        raise ValueError("P019 acceptance uses the locked spiral-v1 input tape")
    if package is None:
        package = ROOT / "build/doom-survivors.ipk3"
    package = Path(package)
    if not no_build:
        package = Path(build(ROOT, room_spec=ROOT / "maps/source/p019-harness/room.json")["package"])
    if not package.is_file():
        raise ValueError(f"missing packaged artifact: {package}")

    compile_runtime = run(
        package, seconds, True, False, "P019", 60, 1280, 720,
        map_name="MAP05", completion_marker="DS_P019_COMPLETE",
    )
    compile_ok = compile_runtime["status"] == "COMPILE_PASS"
    if not compile_ok:
        return {
            "status": "FAIL",
            "scenario": scenario,
            "classification": "P019_PACKAGED_UZDOOM_HARNESS",
            "errors": [f"compile gate was {compile_runtime['status']}"],
            "compile": compile_runtime,
            "package_sha256": hashlib.sha256(package.read_bytes()).hexdigest(),
        }
    compile_package_sha256 = compile_runtime["package_sha256"]

    if scenario in SUCCESS_SCENARIOS and scenario == "telemetry_neutrality":
        enabled = _run_one(package, scenario=scenario, tape=tape, telemetry=1, seconds=seconds, require_visual=False)
        disabled = _run_one(package, scenario=scenario, tape=tape, telemetry=0, seconds=seconds, require_visual=False)
        ensure_package_identity(enabled, compile_package_sha256, label="telemetry enabled")
        ensure_package_identity(disabled, compile_package_sha256, label="telemetry disabled")
        comparison = compare_engine_runs(enabled, disabled, label="telemetry")
        result = {
            "status": "PASS" if enabled["status"] == disabled["status"] == "PASS" and not comparison["errors"] else "FAIL",
            "classification": "P019_PACKAGED_UZDOOM_HARNESS",
            "scenario": scenario,
            "compile": {"status": compile_runtime["status"], "evidence": compile_runtime["evidence"], "package_sha256": compile_runtime["package_sha256"]},
            "telemetry_comparison": {
                "enabled": enabled,
                "disabled": disabled,
                "canonical_hash_enabled": comparison["canonical_hash_a"],
                "canonical_hash_disabled": comparison["canonical_hash_b"],
                "rng_enabled": comparison["rng_a"],
                "rng_disabled": comparison["rng_b"],
                "normalized_trace_equal": comparison["canonical_trace_equal"],
                "errors": comparison["errors"],
            },
            "package_sha256": hashlib.sha256(package.read_bytes()).hexdigest(),
            "engine_sha256": enabled.get("engine_sha256"),
            "source_commit": enabled.get("source_commit"),
            "environment": {"platform": platform.platform(), "python": platform.python_version(), "renderer": "vulkan"},
        }
    elif scenario in SUCCESS_SCENARIOS:
        if scenario == "camera_invariance":
            baseline = _run_one(package, scenario="hash_replay", tape=tape, telemetry=1,
                                seconds=seconds, require_visual=False)
            camera = _run_one(package, scenario=scenario, tape=tape, telemetry=1,
                              seconds=seconds, require_visual=True)
            ensure_package_identity(baseline, compile_package_sha256, label="camera baseline")
            ensure_package_identity(camera, compile_package_sha256, label="camera")
            comparison = compare_engine_runs(baseline, camera, label="camera")
            result = {
                "status": "PASS" if baseline["status"] == camera["status"] == "PASS" and not comparison["errors"] else "FAIL",
                "classification": "P019_PACKAGED_UZDOOM_HARNESS",
                "scenario": scenario,
                "baseline": baseline,
                "camera": camera,
                "camera_comparison": {
                    "baseline_hash": comparison["canonical_hash_a"],
                    "camera_hash": comparison["canonical_hash_b"],
                    "canonical_trace_equal": comparison["canonical_trace_equal"],
                    "errors": comparison["errors"],
                },
                "package_sha256": hashlib.sha256(package.read_bytes()).hexdigest(),
                "engine_sha256": camera.get("engine_sha256"),
                "source_commit": camera.get("source_commit"),
                "environment": {"platform": platform.platform(), "python": platform.python_version(), "renderer": "vulkan"},
            }
        elif scenario == "hash_replay":
            first = _run_one(package, scenario=scenario, tape=tape, telemetry=1,
                             seconds=seconds, require_visual=False)
            second = _run_one(package, scenario=scenario, tape=tape, telemetry=1,
                             seconds=seconds, require_visual=False)
            ensure_package_identity(first, compile_package_sha256, label="replay A")
            ensure_package_identity(second, compile_package_sha256, label="replay B")
            comparison = compare_engine_runs(first, second, label="replay")
            result = {
                "status": "PASS" if first["status"] == second["status"] == "PASS" and not comparison["errors"] else "FAIL",
                "classification": "P019_PACKAGED_UZDOOM_HARNESS",
                "scenario": scenario,
                "replay_a": first,
                "replay_b": second,
                "replay_comparison": {
                    **comparison,
                },
                "package_sha256": hashlib.sha256(package.read_bytes()).hexdigest(),
                "engine_sha256": first.get("engine_sha256"),
                "source_commit": first.get("source_commit"),
                "environment": {"platform": platform.platform(), "python": platform.python_version(), "renderer": "vulkan"},
            }
        else:
            result = _run_one(package, scenario=scenario, tape=tape, telemetry=1, seconds=seconds,
                              require_visual=False)
            result.update({
                "classification": "P019_PACKAGED_UZDOOM_HARNESS",
                "environment": {"platform": platform.platform(), "python": platform.python_version(), "renderer": "vulkan"},
            })
    else:
        result = _run_fault(package, scenario=scenario, tape=tape, seconds=seconds)
        ensure_package_identity(result, compile_package_sha256, label=scenario)
        result.update({
            "classification": "P019_PACKAGED_UZDOOM_HARNESS_EXPECTED_FAILURE",
            "environment": {"platform": platform.platform(), "python": platform.python_version(), "renderer": "vulkan"},
        })
    print(json.dumps(result, indent=2, sort_keys=True))
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scenario", choices=SCENARIOS, default="hash_replay")
    parser.add_argument("--package", type=Path)
    parser.add_argument("--seconds", type=float, default=12.0)
    parser.add_argument("--no-build", action="store_true")
    parser.add_argument("--tape", default="spiral-v1")
    args = parser.parse_args(argv)
    try:
        result = run_harness(scenario=args.scenario, package=args.package, seconds=args.seconds,
                             no_build=args.no_build, tape=args.tape)
    except (OSError, ValueError, RuntimeError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    return 0 if result.get("status") == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
