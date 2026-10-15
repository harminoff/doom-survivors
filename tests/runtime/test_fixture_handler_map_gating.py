"""Globally registered fixture handlers must not act on maps they do not own.

On 2026-09-28 the MAP27 and MAP28 fixture handlers booted on every map
(resetting player facing/FOV and allocating fixture entities), which broke the
MAP18 facing-away chest proof and touched MAP16 normal play. Every handler in
src/zscript/ui that overrides WorldTick must consult level.MapName.
"""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
UI = ROOT / "src" / "zscript" / "ui"


class FixtureHandlerMapGatingTests(unittest.TestCase):
    def test_every_world_tick_handler_checks_its_map(self):
        offenders = []
        for path in sorted(UI.rglob("*.zs")):
            text = path.read_text(encoding="utf-8", errors="replace")
            if "override void WorldTick" in text and not re.search(r"level\.MapName", text):
                offenders.append(str(path.relative_to(ROOT)))
        self.assertEqual(offenders, [], "WorldTick handlers without a map gate: " + ", ".join(offenders))

    def test_map27_and_map28_gate_before_boot(self):
        for rel, map_name in (("bounce/BounceMap27Runtime.zs", "MAP27"),
                              ("paired/PairedMap28Runtime.zs", "MAP28")):
            text = (UI / rel).read_text(encoding="utf-8")
            body = text[text.index("override void WorldTick"):]
            gate = body.find(f'level.MapName != "{map_name}"')
            boot = body.find("Boot()")
            self.assertGreaterEqual(gate, 0, rel)
            self.assertLess(gate, boot, f"{rel}: map gate must precede Boot()")


if __name__ == "__main__":
    unittest.main()
