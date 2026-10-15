import json
import re
import unittest
from pathlib import Path

from tools.run_p026_whip import expected_schedule, validate

ROOT = Path(__file__).resolve().parents[3]


def latest_log() -> str | None:
    latest = ROOT / "evidence/P026/latest-result.json"
    if latest.exists():
        try:
            data = json.loads(latest.read_text(encoding="utf-8"))
            for result in data.get("runs", []):
                if result.get("variant") == 0 and result.get("effects") == 1 and result.get("telemetry") == 1 and result.get("body") == 0:
                    path = Path(result.get("engine_log", ""))
                    if path.exists():
                        return path.read_text(encoding="utf-8", errors="replace")
        except (OSError, ValueError, TypeError):
            pass
    return None


class P026WhipValidatorTests(unittest.TestCase):
    def test_absolute_deadline_schedule(self):
        rows = expected_schedule()
        self.assertEqual([(row["tic"], row["lobe"]) for row in rows], [(1, "FRONT"), (5, "REAR"), (49, "FRONT"), (53, "REAR"), (96, "FRONT"), (100, "REAR")])
        self.assertEqual([row["deadline"] for row in rows], [4, 18, 193, 210, 382, 398])

    def test_marker_only_fails_closed(self):
        result = validate("DS_BOOT map=MAP12 DS_P026_COMPLETE tics=110 events=6")
        self.assertEqual(result["status"], "FAIL")
        self.assertTrue(result["errors"])

    def test_strict_negative_mutations(self):
        good = latest_log()
        if good is None:
            self.skipTest("run tools/run_p026_whip.py first to supply a packaged runtime log")
        self.assertEqual(validate(good)["status"], "PASS")
        mutations = {
            "truncated-candidate": re.sub(r"DS_P026_CANDIDATE event_id=1 ordinal=1[^\n]*\n", "", good, count=1),
            "reordered-hit": re.sub(r"(DS_P026_HIT tic=1 transaction_ordinal=1[^\n]*\n)(.*?DS_P026_HIT tic=1 transaction_ordinal=2[^\n]*\n)", r"\2\1", good, count=1, flags=re.S),
            "cone-inflated-side": good.replace("DS_P026_EMISSION event_id=1", "DS_P026_CANDIDATE event_id=1 ordinal=2 target_slot=2 target_generation=1 target_id=3 eligible=1 reason=RECTANGLE_CIRCLE_INCLUSIVE broad_phase=P024\nDS_P026_EMISSION event_id=1", 1).replace("candidate_count=2", "candidate_count=3", 1),
            "camera-dependent-set": good.replace("aim_yaw_milli=0", "aim_yaw_milli=12345", 1),
            "pitch-state": good.replace("DS_P026_CAMERA tic=0 variant=0 yaw=0 pitch=0", "DS_P026_CAMERA tic=0 variant=0 yaw=0 pitch=22", 1),
            "source-numeric": good.replace("forward_max=128.000", "forward_max=129.000", 1),
            "inventory-level": good.replace("weapon_level=2", "weapon_level=3", 1),
            "manual-fire-only": good.replace("primary_fire_input=0", "primary_fire_input=1", 1),
            "proxy-authored-damage": good.replace("proxy_authored=0", "proxy_authored=1", 1),
            "missing-xp": re.sub(r"DS_P026_XP_REQUEST[^\n]*\n", "", good, count=1),
            "truncated-log": good[: good.find("DS_P026_COMPLETE")],
        }
        for name, mutated in mutations.items():
            with self.subTest(name=name):
                self.assertEqual(validate(mutated)["status"], "FAIL")


if __name__ == "__main__":
    unittest.main()
