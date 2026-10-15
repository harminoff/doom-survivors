"""Run and validate the P015 logical-entity feasibility benchmark.

Every scenario runs in one engine process at a fixed render cap so results are
comparable. The runner records hardware, renderer, settings and package hash
alongside the per-scenario measurements, and measures working set from the
operating system because the pinned engine exposes no ZScript memory statistic.
"""
from __future__ import annotations

import argparse
import json
import platform
import re
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.bench.sampler import MemoryTrace, describe, working_set_bytes
from tools.build import build
from tools.run_probe import run

SCENARIO_RE = re.compile(
    r"DS_P015_SCENARIO name=(?P<name>\S+) mode=(?P<mode>\S+) result=(?P<result>\S+) "
    r"reason=(?P<reason>\S+) enemies=(?P<enemies>\d+) active=(?P<active>\d+) "
    r"projectiles=(?P<projectiles>\d+) pickups=(?P<pickups>\d+) tics=(?P<tics>\d+) "
    r"pair_checks=(?P<pair_checks>\d+) hits=(?P<hits>\d+) hit_signature=(?P<hit_signature>\d+) "
    r"moved=(?P<moved>\d+) grid=(?P<grid>\d+) grid_cells=(?P<grid_cells>\d+) "
    r"proxies=(?P<proxies>\d+) store_items=(?P<store_items>\d+) drops=(?P<drops>\d+) "
    r"collected=(?P<collected>\d+)(?: ms=(?P<ms>[0-9.]+) mean_work_ms=(?P<mean_work_ms>[0-9.]+) "
    r"worst_tick_ms=(?P<worst_tick_ms>[0-9.]+))?"
)
COMPLETE_RE = re.compile(
    r"DS_P015_COMPLETE scenarios=(?P<scenarios>\d+) failures=(?P<failures>\d+) "
    r"total_ms=(?P<total_ms>[0-9.]+) peak_store_items=(?P<peak_store_items>\d+) "
    r"peak_proxies=(?P<peak_proxies>\d+) final_store_items=(?P<final_store_items>\d+) "
    r"final_proxies=(?P<final_proxies>\d+)"
)

EXPECTED_SCENARIOS = 12
MODES = {
    "equivalence_brute": "brute",
    "equivalence_grid": "grid",
    "equivalence_grid_large_store": "grid",
    "sweep_500": "grid",
    "sweep_1000": "grid",
    "sweep_2000": "grid",
    "sweep_3000": "grid",
    "sweep_5000": "grid",
    "orientation_front": "grid",
    "orientation_rear": "grid",
    "churn": "grid",
    "cleanup": "none",
}


def validate(log: str) -> dict:
    errors: list[str] = []
    if "DS_P015_BEGIN" not in log:
        errors.append("missing benchmark begin marker")
    if "counts_are_source_caps=false" not in log:
        errors.append("missing the marker that denies source-cap claims")
    rows = [match.groupdict() for match in SCENARIO_RE.finditer(log)]
    completed = [row for row in rows if row["result"] != "BEGIN"]
    begin = [row for row in rows if row["result"] == "BEGIN"]
    names = [row["name"] for row in completed]
    if len(begin) != EXPECTED_SCENARIOS:
        errors.append(f"expected {EXPECTED_SCENARIOS} scenario starts, observed {len(begin)}")
    if len(completed) != EXPECTED_SCENARIOS:
        errors.append(f"expected {EXPECTED_SCENARIOS} scenario results, observed {len(completed)}")
    for row in completed:
        if row["result"] != "OK":
            errors.append(f"scenario {row['name']} reported {row['result']}: {row['reason']}")
        if MODES.get(row["name"]) != row["mode"]:
            errors.append(f"scenario {row['name']} ran in unexpected mode {row['mode']}")
        if int(row["tics"]) <= 0:
            errors.append(f"scenario {row['name']} ran no tics")
        # P015-A01: real combat work, not static rendering. Every load-bearing
        # scenario must actually check collisions, hit something and move
        # something. The cleanup scenario is the one deliberate exception: it
        # exists to prove that stores and proxies return to zero, so it has no
        # entities and therefore no work by design.
        if row["name"] != "cleanup":
            if int(row["pair_checks"]) <= 0:
                errors.append(f"scenario {row['name']} performed no collision work")
            if int(row["hits"]) <= 0:
                errors.append(f"scenario {row['name']} produced no hits")
            if int(row["moved"]) <= 0:
                errors.append(f"scenario {row['name']} moved nothing")
    completion = COMPLETE_RE.search(log)
    if completion is None:
        errors.append("missing benchmark completion marker")
        values = None
    else:
        values = {key: (float(value) if "." in value else int(value)) for key, value in completion.groupdict().items()}
        if values["failures"] != 0:
            errors.append(f"benchmark reported {values['failures']} internal failures")
        # P015-A03: stores and proxies return to zero after cleanup.
        if values["final_store_items"] != 0:
            errors.append(f"store not empty after cleanup: {values['final_store_items']}")
        if values["final_proxies"] != 0:
            errors.append(f"proxy pool not empty after cleanup: {values['final_proxies']}")
        if values["peak_proxies"] > values["peak_store_items"]:
            errors.append("proxy pool exceeded the logical store size")
    if "VM execution aborted" in log or "Script error" in log:
        errors.append("runtime script failure")
    return {
        "status": "PASS" if not errors else "FAIL",
        "errors": errors,
        "scenarios": [
            {
                key: (float(value) if value is not None and key in ("hits", "pair_checks", "hit_signature", "moved", "ms", "mean_work_ms", "worst_tick_ms") else value)
                for key, value in row.items()
            }
            for row in completed
        ],
        "completion": values,
        "scenario_names": names,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seconds", type=float, default=180, help="deadline for the whole benchmark run")
    parser.add_argument("--max-fps", type=int, default=60, help="requested render cap (held constant for comparability)")
    parser.add_argument("--width", type=int, default=1280)
    parser.add_argument("--height", type=int, default=720)
    parser.add_argument("--no-build", action="store_true", help="reuse the existing package")
    args = parser.parse_args()

    if args.no_build:
        package = ROOT / "build/doom-survivors.ipk3"
        if not package.exists():
            print("FAIL: no package to reuse", file=sys.stderr)
            return 1
    else:
        package = Path(build(ROOT, room_spec=ROOT / "maps/source/stress/room.json")["package"])

    # Sample the live working set while the benchmark runs. The engine exposes
    # no ZScript memory statistic, so this is the only honest source.
    trace = MemoryTrace(supported=False, note="not_sampled")
    last_sample = [0.0]

    def sample(pid: int, elapsed: float) -> None:
        if elapsed - last_sample[0] < 1.0:
            return
        last_sample[0] = elapsed
        value = working_set_bytes(pid)
        if value is None:
            return
        trace.supported = True
        trace.note = "windows_working_set_sampled_during_run"
        trace.record(elapsed, value)

    runtime = run(package, args.seconds, False, False, "P015", args.max_fps,
                  args.width, args.height, "MAP04", "DS_P015_COMPLETE", True, True, sample)
    evidence = Path(runtime["evidence"])
    log = (evidence / "engine.log").read_text(encoding="utf-8", errors="replace")

    result = validate(log)
    result["memory"] = trace.summary()
    result.update({
        "classification": "P015_SYNTHETIC_ENTITY_BENCHMARK",
        "runtime_status": runtime["status"],
        "elapsed_seconds": runtime["elapsed_seconds"],
        "package_sha256": runtime["package_sha256"],
        "engine_sha256": runtime["engine_sha256"],
        "source_commit": runtime["source_commit"],
        "requested_max_fps": args.max_fps,
        "requested_window_width": args.width,
        "requested_window_height": args.height,
        "captures": runtime["captures"],
        "environment": {
            "platform": platform.platform(),
            "processor": platform.processor(),
            "python": platform.python_version(),
            "renderer": "vulkan",
        },
        "source_parity": "OPEN_SYNTHETIC_BENCHMARK",
        "counts_are_source_caps": False,
        "evidence": str(evidence),
    })
    (evidence / "bench-result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 0 if result["status"] == "PASS" and runtime["status"] == "RUNTIME_PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
