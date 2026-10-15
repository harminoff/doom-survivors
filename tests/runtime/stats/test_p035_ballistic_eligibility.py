"""P035 weapon systems participate only in approved P033 stats."""
from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
RULES = ROOT / "src/zscript/gameplay/stats/ResolvedStats.zs"


class P035EligibilityTests(unittest.TestCase):
    def test_ballistic_system_ids_have_only_might_and_cooldown_eligibility(self) -> None:
        source = RULES.read_text(encoding="utf-8")
        expected = {
            "SYSTEM_AXE": 38,
            "SYSTEM_DEATH_SPIRAL": 39,
            "SYSTEM_FIRE_WAND": 40,
            "SYSTEM_HELLFIRE": 41,
        }
        for name, value in expected.items():
            self.assertRegex(source, rf"const\s+{name}\s*=\s*{value}\s*;")

        method = re.search(
            r"static bool StatApplies\(int statId, int systemId\)(.*?)\n    }",
            source,
            re.S,
        )
        self.assertIsNotNone(method, "could not locate the shared eligibility rule")
        body = method.group(1)
        self.assertIn("statId == STAT_MIGHT || statId == STAT_COOLDOWN", body)
        for name in expected:
            self.assertIn(name, body)
        self.assertIn("if (statId == STAT_ARMOR)", body)
        self.assertIn("if (statId == STAT_MAX_HEALTH)", body)
        self.assertIn("return false;", body)
        self.assertNotIn("STAT_DURATION", body)


if __name__ == "__main__":
    unittest.main()
