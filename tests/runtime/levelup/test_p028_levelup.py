import json
import re
import unittest
from pathlib import Path

from tools.run_p028_levelup import expected_rng_rows, validate

ROOT = Path(__file__).resolve().parents[3]


def latest_log() -> str | None:
    latest = ROOT / "evidence/P028/latest-result.json"
    if not latest.exists():
        return None
    try:
        data = json.loads(latest.read_text(encoding="utf-8"))
        for result in data.get("runs", []):
            if result.get("mode") == "demo" and result.get("variant") == 0 and result.get("telemetry") == 1:
                path = Path(result.get("engine_log", ""))
                if path.exists():
                    return path.read_text(encoding="utf-8", errors="replace")
    except (OSError, ValueError, TypeError):
        return None
    return None


class P028LevelUpValidatorTests(unittest.TestCase):
    def test_draft_rng_is_one_step_per_queue_entry(self):
        self.assertEqual(expected_rng_rows(), [
            (730201, -192481991, 1),
            (-192481991, 1847182601, 2),
        ])

    def test_marker_only_fails_closed(self):
        result = validate("DS_P028_BOOT map=MAP14 DS_P028_COMPLETE tics=72")
        self.assertEqual(result["status"], "FAIL")
        self.assertTrue(result["errors"])

    def test_strict_negative_mutations(self):
        good = latest_log()
        if good is None:
            self.skipTest("run tools/run_p028_levelup.py first to supply a packaged runtime log")
        self.assertEqual(validate(good)["status"], "PASS")
        first_enqueue = "DS_P028_DRAFT_ENQUEUE queue_index=0 target_level=2"
        mutations = {
            "wrong-threshold": good.replace(first_enqueue, "DS_P028_DRAFT_ENQUEUE queue_index=0 target_level=4", 1),
            "rng-draw": good.replace("rng_after=-192481991", "rng_after=-192481990", 1),
            "illegal-offer": good.replace("offer0_id=2", "offer0_id=9", 1),
            "duplicate-offer": good.replace("offer1_id=3", "offer1_id=2", 1),
            "shared-armor": good.replace("armor=2 authority=SHARED_INVENTORY_STATS", "armor=1 authority=SHARED_INVENTORY_STATS", 1),
            "clock-advance": good.replace("PAUSE_SAMPLE ui_tick=1 world_tic=1 ui_time_advances=1 stage_clock=1", "PAUSE_SAMPLE ui_tick=1 world_tic=1 ui_time_advances=1 stage_clock=2", 1),
            "stale-token": good.replace("DS_P028_SNAPSHOT level=3 xp_remainder=0 queue_count=2 target_level=2 token=0", "DS_P028_SNAPSHOT level=3 xp_remainder=0 queue_count=2 target_level=2 token=9", 1),
            "illegal-command": good.replace("offer_id=POWER (Spinach) rank=1 target_level=2", "offer_id=BOGUS rank=1 target_level=2", 1),
            "duplicate-command": good.replace("DS_P028_CONFIRM_APPLIED source=NETWORK_PROCESS", "DS_P028_CONFIRM_APPLIED source=NETWORK_PROCESS\nDS_P028_CONFIRM_APPLIED source=NETWORK_PROCESS", 1),
            "missing-apply": re.sub(r"DS_P028_APPLY[^\n]*\n", "", good, count=1),
            "missing-neutral": re.sub(r"DS_P028_NEUTRAL_FRAME[^\n]*\n", "", good, count=1),
            "truncated": good[: good.find("DS_P028_COMPLETE")],
        }
        for name, mutated in mutations.items():
            with self.subTest(name=name):
                self.assertEqual(validate(mutated)["status"], "FAIL")


if __name__ == "__main__":
    unittest.main()
