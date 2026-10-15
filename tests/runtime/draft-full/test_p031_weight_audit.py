"""Strict validation for P031's in-engine weighted-selector audit."""
from __future__ import annotations

import math
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SAMPLE_COUNT = 100_000
SEED_FIRST = 1_000_001
SEED_STEP = 7_919


def _audit_fields(log: str) -> dict[str, str] | None:
    match = re.search(r"DS_P031_WEIGHT_AUDIT\s+([^\r\n]*)", log)
    if match is None:
        return None
    return dict(re.findall(r"([A-Za-z_][A-Za-z0-9_]*)=([^\s]+)", match.group(1)))


def validate_weight_audit(log: str) -> dict[str, object]:
    fields = _audit_fields(log)
    errors: list[str] = []
    if fields is None:
        return {"status": "FAIL", "errors": ["missing in-engine weight audit"]}
    expected = {
        "samples": SAMPLE_COUNT,
        "seeds_distinct": 1,
        "seed_first": SEED_FIRST,
        "seed_step": SEED_STEP,
        "seed_last": SEED_FIRST + (SAMPLE_COUNT - 1) * SEED_STEP,
        "weight_1": 1,
        "weight_2": 2,
        "weight_3": 4,
        "duplicates": 0,
        "rng_restored": 1,
    }
    for key, value in expected.items():
        try:
            actual = int(fields[key])
        except (KeyError, ValueError):
            errors.append(f"{key} is missing or not an integer")
            continue
        if actual != value:
            errors.append(f"{key} is {actual}, expected {value}")

    frequencies: list[int] = []
    for key in ("first_1", "first_2", "first_3"):
        try:
            frequencies.append(int(fields[key]))
        except (KeyError, ValueError):
            errors.append(f"{key} is missing or not an integer")
            frequencies.append(-1)
    if all(value >= 0 for value in frequencies) and sum(frequencies) != SAMPLE_COUNT:
        errors.append("first-offer frequencies do not sum to the declared sample count")

    weights = (1, 2, 4)
    if all(value >= 0 for value in frequencies):
        for index, (count, weight) in enumerate(zip(frequencies, weights), 1):
            probability = weight / sum(weights)
            sigma = math.sqrt(probability * (1 - probability) / SAMPLE_COUNT)
            tolerance = max(6 * sigma, 0.005)
            observed = count / SAMPLE_COUNT
            if abs(observed - probability) > tolerance:
                errors.append(
                    f"candidate {index} frequency {observed:.6f} differs from "
                    f"{probability:.6f} by more than {tolerance:.6f}"
                )
    return {"status": "PASS" if not errors else "FAIL", "errors": errors, "fields": fields}


def _signed32(value: int) -> int:
    value &= 0xFFFFFFFF
    return value - 0x100000000 if value >= 0x80000000 else value


def _next_rng(state: int) -> int:
    state = _signed32(state ^ _signed32(state << 13))
    state = _signed32(state ^ _signed32(state >> 17))
    state = _signed32(state ^ _signed32(state << 5))
    return 1_831_568_133 if state == 0 else state


def run_independent_weight_fixture(samples: int = SAMPLE_COUNT) -> tuple[list[int], int]:
    """Mirror the integer draw contract with independent 1:2:4 test weights."""
    frequencies = [0, 0, 0]
    duplicates = 0
    for sample in range(samples):
        rng = SEED_FIRST + sample * SEED_STEP
        chosen: set[int] = set()
        for offer in range(3):
            candidates = [(1, 1), (2, 2), (3, 4)]
            total = sum(weight for item, weight in candidates if item not in chosen)
            rng = _next_rng(rng)
            roll = rng % total
            selected = 0
            cumulative = 0
            for item, weight in candidates:
                if item in chosen:
                    continue
                cumulative += weight
                if roll < cumulative:
                    selected = item
                    break
            if selected in chosen or selected == 0:
                duplicates += 1
            chosen.add(selected)
            if offer == 0:
                frequencies[selected - 1] += 1
    return frequencies, duplicates


class P031WeightAuditTests(unittest.TestCase):
    @staticmethod
    def valid_record() -> str:
        # Rounded-near-expected counts are test data; the production acceptance
        # record must come from the MAP17 UZDoom audit, never from this fixture.
        return (
            "DS_P031_WEIGHT_AUDIT samples=100000 seeds_distinct=1 seed_first=1000001 "
            "seed_step=7919 seed_last=792892082 weight_1=1 weight_2=2 weight_3=4 "
            "first_1=14286 first_2=28571 first_3=57143 duplicates=0 rng_restored=1"
        )

    def test_in_engine_audit_shape_and_sampling_tolerance(self):
        result = validate_weight_audit(self.valid_record())
        self.assertEqual(result["status"], "PASS", result["errors"])

    def test_independent_100k_seed_fixture_meets_locked_statistical_gate(self):
        frequencies, duplicates = run_independent_weight_fixture()
        self.assertEqual(duplicates, 0)
        record = (
            f"DS_P031_WEIGHT_AUDIT samples={SAMPLE_COUNT} seeds_distinct=1 "
            f"seed_first={SEED_FIRST} seed_step={SEED_STEP} "
            f"seed_last={SEED_FIRST + (SAMPLE_COUNT - 1) * SEED_STEP} "
            f"weight_1=1 weight_2=2 weight_3=4 first_1={frequencies[0]} "
            f"first_2={frequencies[1]} first_3={frequencies[2]} "
            f"duplicates={duplicates} rng_restored=1"
        )
        result = validate_weight_audit(record)
        self.assertEqual(result["status"], "PASS", result["errors"])

    def test_missing_or_small_sample_fails_closed(self):
        self.assertEqual(validate_weight_audit("DS_P031_COMPLETE ok=1")["status"], "FAIL")
        small = self.valid_record().replace("samples=100000", "samples=99999", 1)
        self.assertEqual(validate_weight_audit(small)["status"], "FAIL")

    def test_duplicate_and_distribution_mutations_fail(self):
        duplicate = self.valid_record().replace("duplicates=0", "duplicates=1", 1)
        drifted = self.valid_record().replace("first_1=14286", "first_1=20000", 1)
        self.assertEqual(validate_weight_audit(duplicate)["status"], "FAIL")
        self.assertEqual(validate_weight_audit(drifted)["status"], "FAIL")

    def test_seed_construction_must_be_distinct_and_reproducible(self):
        repeated = self.valid_record().replace("seeds_distinct=1", "seeds_distinct=0", 1)
        wrong_last = self.valid_record().replace("seed_last=792892082", "seed_last=792892083", 1)
        self.assertEqual(validate_weight_audit(repeated)["status"], "FAIL")
        self.assertEqual(validate_weight_audit(wrong_last)["status"], "FAIL")

    def test_authority_uses_the_same_selector_for_production_and_audit(self):
        source = (ROOT / "src/zscript/gameplay/progression/DraftFull.zs").read_text(encoding="utf-8")
        generate = source.split("void DSP031GenerateOffers", 1)[1].split("void DSP031QueueDraft", 1)[0]
        audit = source.split("bool DSP031RunWeightAudit", 1)[1].split("void DSP031SetFallbackOffers", 1)[0]
        # N2 generalized the shared selector from an int bitmask third
        # argument to an Array<int> of already-chosen ids (removing the
        # `1 << id` / `id > 30` ceiling); both call sites still share the
        # same selector function and the same chosenIds variable name.
        self.assertIn("DSP031SelectWeighted(candidateIds, candidateWeights, chosenIds", generate)
        self.assertIn("DSP031SelectWeighted(ids, weights, chosenIds", audit)


if __name__ == "__main__":
    unittest.main()
