"""DSP030VerticalSlice source: the main file plus its `extend class` parts.

Tests that grep the slice's ZScript read this combined text, so moving a
function between gameplay/VerticalSlice.zs and gameplay/slice/*.zs does not
break them. Order: main file first, then the parts in ZSCRIPT include order.
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = ROOT / "src/zscript/gameplay/VerticalSlice.zs"
PARTS = ("SliceProfile", "SliceRunStats", "SliceMadForest", "SliceWeapons",
         "SliceFixtures", "SliceUi", "SliceGeneric", "SliceEffects", "SliceArcana", "SliceAudio")


def read() -> str:
    texts = [MAIN.read_text(encoding="utf-8")]
    texts += [(ROOT / f"src/zscript/gameplay/slice/{p}.zs").read_text(encoding="utf-8") for p in PARTS]
    return "\n".join(texts)
