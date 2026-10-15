import json
import re
import unittest
from pathlib import Path

from tools.run_p025_attacks import expected_candidates, expected_emissions, expected_schedule, validate


ROOT = Path(__file__).resolve().parents[3]


def _latest_runtime_log() -> str | None:
    evidence_root = ROOT / "evidence" / "P025"
    latest = evidence_root / "latest-result.json"
    if latest.exists():
        try:
            result = json.loads(latest.read_text(encoding="utf-8"))
            for run in result.get("runs", []):
                if (run.get("variant"), run.get("effects"), run.get("telemetry")) != (0, 1, 1):
                    continue
                path = Path(run.get("engine_log", ""))
                if path.exists():
                    return path.read_text(encoding="utf-8", errors="replace")
        except (OSError, ValueError, TypeError):
            pass
    logs = sorted(evidence_root.glob("*/engine.log"), key=lambda p: p.stat().st_mtime, reverse=True)
    for path in logs:
        log = path.read_text(encoding="utf-8", errors="replace")
        if "DS_P025_COMPLETE" in log and "camera_variant=0 effects=1 telemetry=1" in log:
            return log
    return None


class P025AttackValidatorTests(unittest.TestCase):
    def test_schedule_has_distinct_clocks_and_concurrent_emissions(self):
        rows = expected_schedule()
        self.assertEqual(rows[(2, 10, 1)], (1, "TOP"))
        self.assertEqual(rows[(3, 20, 1)], (1, "TOP"))
        self.assertEqual(rows[(7, 10, 1)], (1, "TOP"))
        self.assertEqual(rows[(7, 20, 1)], (1, "TOP"))
        self.assertNotIn((8, 10, 1), rows)
        self.assertEqual(rows[(10, 30, 2)], (1, "TOP"))

    def test_oracle_contains_snapshot_and_lifecycle_cases(self):
        events = expected_emissions()
        self.assertEqual(len(events), 14)
        self.assertEqual([row["kind"] for row in events[:4]], ["TOP", "CHILD", "TOP", "CHILD"])
        candidates = expected_candidates()
        self.assertEqual(candidates[1][-1], (2, 1, 102))
        self.assertEqual(candidates[11], [(0, 2, 104)])
        self.assertEqual(candidates[12], [(0, 3, 105)])

    def test_marker_only_fails_closed(self):
        result = validate("DS_BOOT map=MAP11\nDS_P025_COMPLETE tics=16 events=14")
        self.assertEqual(result["status"], "FAIL")
        self.assertTrue(result["errors"])

    def test_runtime_negative_mutations_are_rejected(self):
        good = _latest_runtime_log()
        if good is None:
            self.skipTest("run tools/run_p025_attacks.py first to supply a packaged runtime log")
        self.assertEqual(validate(good, expected_variant=0, expected_effects=1, expected_telemetry=1)["status"], "PASS")
        mutations = {
            "truncated-candidate": re.sub(
                r"DS_P025_CANDIDATE event_id=1 ordinal=2[^\n]*\n", "", good, count=1),
            "reordered-hit": re.sub(
                r"(DS_P025_HIT tic=2 transaction_ordinal=1[^\n]*\n)(DS_P025_DAMAGE[^\n]*\n)(DS_P025_DEATH[^\n]*\n)(DS_P025_CLEANUP[^\n]*\n)(DS_P025_HIT tic=2 transaction_ordinal=2[^\n]*\n)",
                r"\5\2\3\4\1", good, count=1),
            "camera-dependent-damage": good.replace("aim_yaw_milli=0", "aim_yaw_milli=12345", 1),
            "telemetry-completion": good.replace("telemetry=1 camera_invariant", "telemetry=0 camera_invariant", 1),
            "stale-accepted": good.replace("accepted=0 reason=STALE_GENERATION", "accepted=1 reason=STALE_GENERATION", 1),
        }
        for name, mutated in mutations.items():
            with self.subTest(name=name):
                self.assertEqual(validate(mutated, expected_variant=0, expected_effects=1, expected_telemetry=1)["status"], "FAIL")


if __name__ == "__main__":
    unittest.main()
