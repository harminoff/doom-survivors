import json
import unittest
from pathlib import Path

from tools.run_p029_lifecycle import validate, validate_negative_mutations, validate_return_menu

ROOT = Path(__file__).resolve().parents[3]


def latest_artifact() -> dict | None:
    path = ROOT / "evidence/P029/latest-result.json"
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, TypeError, ValueError):
        return None


def latest_log() -> str | None:
    artifact = latest_artifact()
    if not artifact:
        return None
    for result in artifact.get("runs", []):
        if result.get("variant") == 0 and result.get("telemetry") == 1:
            path = Path(result.get("engine_log", ""))
            if path.exists():
                return path.read_text(encoding="utf-8", errors="replace")
    return None


class P029RunLifecycleValidatorTests(unittest.TestCase):
    def test_marker_only_fails_closed(self):
        result = validate("DS_P029_BOOT map=MAP15 DS_P029_COMPLETE cycles=3 state=RESULTS")
        self.assertEqual(result["status"], "FAIL")
        self.assertTrue(result["errors"])

    def test_packaged_artifact_proves_matrix_and_restart(self):
        artifact = latest_artifact()
        if artifact is None:
            self.skipTest("run tools/run_p029_lifecycle.py first to supply packaged evidence")
        self.assertEqual(artifact.get("status"), "PASS", artifact.get("errors"))
        self.assertEqual(len(artifact.get("runs", [])), 6)
        self.assertTrue(all(run.get("status") == "PASS" for run in artifact["runs"]))
        self.assertTrue(all(capture.get("nonblank") for run in artifact["runs"]
                            for capture in run.get("runtime", {}).get("captures", [])))
        self.assertEqual([mutation.get("status") for mutation in artifact["profile_mutations"]],
                         ["PASS", "PASS"])
        self.assertEqual(artifact.get("restart", {}).get("status"), "PASS")
        self.assertEqual(artifact.get("return_menu", {}).get("status"), "PASS")
        log = latest_log()
        self.assertIsNotNone(log)
        self.assertEqual(validate(log)["status"], "PASS")

    def test_negative_mutations_all_fail_closed(self):
        log = latest_log()
        if log is None:
            self.skipTest("run tools/run_p029_lifecycle.py first to supply packaged evidence")
        outcomes = validate_negative_mutations(log)
        self.assertEqual(len(outcomes), 11)
        self.assertTrue(all(status == "FAIL" for status in outcomes.values()), outcomes)

    def test_return_menu_requires_frozen_clean_results_boundary(self):
        log = latest_log()
        if log is None:
            self.skipTest("run tools/run_p029_lifecycle.py first to supply packaged evidence")
        artifact = latest_artifact() or {}
        return_log_path = Path(artifact.get("return_menu", {}).get("engine_log", ""))
        if not return_log_path.exists():
            self.skipTest("return-menu runtime evidence is unavailable")
        result = validate_return_menu(return_log_path.read_text(encoding="utf-8", errors="replace"))
        self.assertEqual(result["status"], "PASS", result["errors"])


if __name__ == "__main__":
    unittest.main()
