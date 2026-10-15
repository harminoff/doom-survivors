import json
import re
import unittest
from pathlib import Path

from tools.run_p027_xp import validate

ROOT = Path(__file__).resolve().parents[3]


def latest_log() -> str | None:
    result = ROOT / "evidence/P027/latest-result.json"
    if not result.exists():
        return None
    try:
        data = json.loads(result.read_text(encoding="utf-8"))
        path = Path(data.get("canonical_run", {}).get("evidence", "")) / "process.log"
        return path.read_text(encoding="utf-8", errors="replace") if path.exists() else None
    except (OSError, TypeError, ValueError):
        return None


class P027ExperienceValidatorTests(unittest.TestCase):
    def test_marker_only_fails_closed(self):
        result = validate("DS_BOOT map=MAP13 DS_P027_COMPLETE tics=105")
        self.assertEqual(result["status"], "FAIL")
        self.assertTrue(result["errors"])

    def test_gem_record_and_production_trace_pass(self):
        log = latest_log()
        if log is None:
            self.skipTest("run tools/run_p027_xp.py first to supply a packaged runtime log")
        result = validate(log)
        self.assertEqual(result["status"], "PASS", result["errors"])
        self.assertEqual(result["request_count"], 23)
        self.assertEqual(result["merge_count"], 15)

    def test_strict_negative_mutations(self):
        log = latest_log()
        if log is None:
            self.skipTest("run tools/run_p027_xp.py first to supply a packaged runtime log")
        self.assertEqual(validate(log)["status"], "PASS")
        first_collection = re.search(r"DS_P027_COLLECTION[^\n]*accepted=1[^\n]*\n", log)
        self.assertIsNotNone(first_collection)
        duplicated_collection = log.replace(first_collection.group(0), first_collection.group(0) + first_collection.group(0), 1)
        mutations = {
            "missing-collection": re.sub(r"DS_P027_COLLECTION[^\n]*\n", "", log, count=1),
            "double-collection": duplicated_collection,
            "changed-value": log.replace("DS_P027_CREATE tic=1", "DS_P027_CREATE tic=1", 1).replace("value=1000", "value=999", 1),
            "outside-radius": log.replace("radius=24.000 inclusive=1", "radius=23.000 inclusive=1", 1),
            "illegal-near-merge": log.replace("near_merge=0", "near_merge=1", 1),
            "stale-accepted": log.replace("DS_P027_STALE_COLLECTION tic=26", "DS_P027_STALE_COLLECTION tic=26", 1).replace("accepted=0 reason=STALE_GENERATION", "accepted=1 reason=STALE_GENERATION", 1),
            "proxy-authored-xp": log.replace("proxy_authored_xp=0", "proxy_authored_xp=1", 1),
            "rebase-drift": log.replace("handles_preserved=1", "handles_preserved=0", 1),
            "truncated-ledger": re.sub(r"DS_P027_LEDGER transaction=1[^\n]*\n", "", log, count=1),
            "truncated-complete": log[: log.find("DS_P027_COMPLETE")],
        }
        for name, mutated in mutations.items():
            with self.subTest(name=name):
                self.assertEqual(validate(mutated)["status"], "FAIL")


if __name__ == "__main__":
    unittest.main()
