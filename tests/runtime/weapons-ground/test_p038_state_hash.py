"""Static completeness checks for the P038 serialized-state fingerprint."""
from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
RUNTIME = ROOT / "src/zscript/weapons/ground/GroundFieldRuntime.zs"


class P038GroundStateHashTests(unittest.TestCase):
    def test_hash_covers_all_persistent_arrays_and_runtime_counters(self) -> None:
        source = RUNTIME.read_text(encoding="utf-8")
        hash_start = source.index("    int DSP038HashMixDoubleMilli(")
        hash_end = source.index("    void DSP038ProcessGroundTic(", hash_start)
        hash_source = source[hash_start:hash_end]

        arrays = set(re.findall(r"\bArray<(?:int|double)>\s+(dsp038\w+)\s*;", source))
        transient_scratch = {
            "dsp038ContactDistanceSquared",
            "dsp038ContactFractions",
            "dsp038ContactSlots",
            "dsp038ContactGenerations",
            "dsp038ContactIds",
        }
        covered_arrays = set(re.findall(r"\b(dsp038\w+)\s*\[i\]", hash_source))
        self.assertEqual(
            arrays - transient_scratch - covered_arrays,
            set(),
            "Every persistent P038 array must contribute to the state hash",
        )

        counters = set(re.findall(r"\bint\s+(dsp038\w+)\s*;", source))
        covered_counters = set(re.findall(r"\b(dsp038\w+)\b", hash_source))
        self.assertEqual(
            counters - covered_counters,
            set(),
            "Every P038 scalar runtime counter must contribute to the state hash",
        )

    def test_hash_mix_and_double_quantization_are_bounded(self) -> None:
        source = RUNTIME.read_text(encoding="utf-8")
        mix = source.split("    int DSP038HashMix(int hash, int value)", 1)[1].split(
            "    int DSP038HashMixDoubleMilli", 1
        )[0]
        double_mix = source.split("    int DSP038HashMixDoubleMilli", 1)[1].split(
            "    int DSP038HashWeaponState", 1
        )[0]
        self.assertIn("value % 1000003", mix)
        self.assertIn("(hash * 31 + normalized) % 1000003", mix)
        self.assertIn("2000000000", double_mix)
        self.assertIn("int(value * 1000.0)", double_mix)


if __name__ == "__main__":
    unittest.main()
