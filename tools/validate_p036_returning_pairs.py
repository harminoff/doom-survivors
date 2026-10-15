"""Strictly compare already-recorded MAP22 camera and rebase runs."""
from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))


def _validator_module():
    path = ROOT / "tests/runtime/weapons-returning/test_p036_returning_runtime.py"
    spec = importlib.util.spec_from_file_location("p036_returning_runtime_validator", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load MAP22 validator: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--variant0", type=Path, required=True,
                        help="strict default-camera flight evidence")
    parser.add_argument("--variant1", type=Path, required=True,
                        help="strict yaw-90 flight evidence")
    parser.add_argument("--variant2", type=Path, required=True,
                        help="strict pitch/FOV-only flight evidence")
    parser.add_argument("--baseline-flight", type=Path, required=True,
                        help="variant-0 flight path used to normalize the rebase run")
    parser.add_argument("--move-rebase", type=Path, required=True,
                        help="strict moving-player/world-rebase evidence")
    args = parser.parse_args()

    variant_paths = {0: args.variant0.resolve(), 1: args.variant1.resolve(),
                      2: args.variant2.resolve()}
    report = _validator_module().validate_p036_cross_run(
        variant_paths, args.baseline_flight.resolve(), args.move_rebase.resolve())
    report["evidence_paths"] = {
        "camera_variants": {str(key): str(path) for key, path in variant_paths.items()},
        "baseline_flight": str(args.baseline_flight.resolve()),
        "move_rebase": str(args.move_rebase.resolve()),
    }
    output = args.variant0.resolve() / "p036-cross-run-validation.json"
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
