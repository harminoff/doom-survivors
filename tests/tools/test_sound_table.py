"""The sound table, its generated files and the game's sound names must agree.

A missing file or a stale table plays silence in UZDoom without any warning, so these
are checked here (the run itself reports DS_AUDIO_CHECK missing=N at each run start).
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/audio"))

import sfx_mix   # noqa: E402
import sound_table   # noqa: E402


def test_every_sound_has_its_game_file():
    missing = [k for k in sound_table.SOUNDS if not sfx_mix.game_path(k).exists()]
    assert missing == []


def test_generated_sndinfo_and_zscript_table_are_current():
    assert (ROOT / "src/resources/SNDINFO").read_text(encoding="utf-8") == sfx_mix.build_sndinfo()
    assert sfx_mix.ZTABLE.read_text(encoding="utf-8") == sfx_mix.build_ztable()


def test_zscript_only_names_sounds_in_the_table():
    used = set()
    for path in (ROOT / "src/zscript").rglob("*.zs"):
        if path == sfx_mix.ZTABLE:
            continue
        used |= set(re.findall(r"DSSfx\.([A-Z][A-Z0-9_]*)\b", path.read_text(encoding="utf-8")))
    known = set(sound_table.SOUNDS) | {"SFX_COUNT", "NAMES", "DUCK", "HOLD", "CAT", "CAT_COUNT", "COMBAT_CATS", "DUCK_RELEASE"} | {f"CAT_{c.upper()}" for c in sound_table.CATEGORIES}
    assert sorted(used - known) == []


def test_lookup_maps_point_at_real_sounds():
    keys = set(sound_table.SOUNDS)
    refs = (list(sound_table.WEAPON.values()) + list(sound_table.HIT.values()) + sound_table.FAMILY
            + sound_table.ITEM + list(sound_table.MENU_ALIASES.values()))
    assert sorted(set(refs) - keys) == []


def test_mix_simulator_uses_the_game_rules():
    import mix_check
    zs = (ROOT / "src/zscript/gameplay/slice/SliceAudio.zs").read_text(encoding="utf-8")

    def ints(name):
        return [int(v) for v in re.search(name + r"\[\] = \{([^}]*)\}", zs).group(1).split(",")]

    order = ["weapon", "hit", "death", "pickup"]
    assert ints("CAT_MAX") == [mix_check.CAT_MAX[c] for c in order]
    assert ints("CAT_GAP") == [mix_check.CAT_GAP[c] for c in order]
    assert float(re.search(r"FOCUS_GAIN = ([0-9.]+);", zs).group(1)) == mix_check.FOCUS_GAIN
    assert int(re.search(r"BUDGET_WINDOW = (\d+);", zs).group(1)) == mix_check.BUDGET_WINDOW
