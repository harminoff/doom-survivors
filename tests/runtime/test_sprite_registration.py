"""Every sprite name ZScript looks up at runtime must be used by some state.

``Actor.GetSpriteIndex`` only finds sprite names that a state definition
registered and returns -1 otherwise. An actor rendered with sprite -1 reads
out of bounds in the hardware renderer's worker thread; when that crashes,
the engine's crash handler parks the worker forever while the main thread
waits for it, so the game silently freezes (seen 2026-09-30 as intermittent
soak and save/load timeouts right after a Mad Forest coin bag dropped).
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STATE_SPRITE = re.compile(r"(?<![A-Za-z0-9_\"])([A-Z0-9]{4}) [A-Z\[\]\\]+ -?\d+")
QUOTED = re.compile(r'"([A-Z0-9]{4})"')


class SpriteRegistrationTests(unittest.TestCase):
    def test_runtime_sprite_names_are_registered_by_states(self):
        registered: set[str] = set()
        quoted: set[str] = set()
        for path in (ROOT / "src/zscript").rglob("*.zs"):
            text = path.read_text(encoding="utf-8", errors="replace")
            for line in text.splitlines():
                code = line.split("//", 1)[0]
                registered.update(STATE_SPRITE.findall(code))
            quoted.update(QUOTED.findall(text))
        lumps = {p.name[:4] for p in (ROOT / "src/resources/sprites").glob("*.png")}
        missing = sorted(name for name in quoted & lumps if name not in registered)
        self.assertEqual(missing, [], "sprite names used at runtime but in no state "
                         "(GetSpriteIndex returns -1): add them to a Register: state")


if __name__ == "__main__":
    unittest.main()
