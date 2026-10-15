"""Quick check that weapon on-hit effects fire in a normal run.

Runs the soak_n2 controller on a stage map with the given items granted at
tic 70 (ds_n2_grant_ids), the draft bot answering level-ups, and prints the
end-of-run DS_FX_COUNT tallies (knockback, crit, heal, ...) plus each owned
weapon's accepted hits. A manual aid for item-effect work, not a test.

    python tools/run_effect_check.py --grant 48,1 --tics 2100
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tools.run_probe import run


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--grant", required=True, help="comma-separated item ids granted at tic 70")
    parser.add_argument("--tics", type=int, default=2100, help="run length in logical tics")
    parser.add_argument("--map", default="MAP16")
    parser.add_argument("--speed", type=int, default=2)
    parser.add_argument("--seconds", type=float, default=150.0)
    parser.add_argument("--extra", nargs="*", default=[], help="extra 'cvar=value' settings")
    args = parser.parse_args()
    commands = ["+set", "ds_p030_mode", "soak_n2",
                "+set", "ds_n2_draft_bot", "1",
                "+set", "ds_n2_soak_mover", "1",
                "+set", "ds_n2_grant_ids", args.grant,
                # Only fixed lengths are accepted here; ds_mf_end_tics ends the
                # stage run at any tic.
                "+set", "ds_p030_duration_tics", "2100",
                "+set", "ds_mf_end_tics", str(args.tics),
                "+set", "ds_p030_speed", str(args.speed)]
    for item in args.extra:
        name, _, value = item.partition("=")
        commands += ["+set", name, value]
    started = run((ROOT / "build/doom-survivors.ipk3").resolve(), args.seconds, False, False, "P900",
                  map_name=args.map, completion_marker="DS_P030_COMPLETE", startup_commands=commands)
    evidence = Path(started["evidence"])
    log = (evidence / "engine.log").read_text(encoding="utf-8", errors="replace")
    fx = {m.group(1): int(m.group(2)) for m in re.finditer(r"DS_FX_COUNT effect=(\S+) count=(-?\d+)", log)}
    hits = {m.group(1): int(m.group(2)) for m in
            re.finditer(r"DS_N2_DISPATCH_SUMMARY system_id=(\d+) rank=\d+ engine=\d+ accepted_hits=(\d+)", log)}
    errors = sorted(set(re.findall(r"(Script error.*|VM execution aborted.*|DS_RUNTIME_ASSERT_FAIL kind=\S+)", log)))
    print(json.dumps({"status": started.get("status"), "fx": fx, "hits_by_system": hits,
                      "errors": errors[:10], "evidence": str(evidence)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
