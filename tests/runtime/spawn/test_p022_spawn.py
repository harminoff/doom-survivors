import unittest

from tools.run_p022_spawn import deadline, validate, validate_attempt_ledger


class P022SpawnContractTests(unittest.TestCase):
    def test_absolute_deadlines_and_same_tic_alignment(self):
        self.assertEqual([deadline("stage-wave-100ms", i) for i in range(1, 6)], [4, 7, 11, 14, 18])
        self.assertEqual([deadline("stage-refill-250ms", i) for i in range(1, 3)], [9, 18])
        self.assertEqual(deadline("stage-wave-100ms", 5), deadline("stage-refill-250ms", 2))

    def test_strict_validator_rejects_markers_without_actual_trace(self):
        log = "\n".join(
            [
                "DS_P022_BOOT map=MAP08 ticrate=35 stage=FOREST source_build=1.16.107 clock_model=CEIL_ABSOLUTE_DEADLINE region=logical-reference-v1 region_width=256.000 region_height=256.000 camera_frustum=SEPARATE",
                "DS_P022_SOURCE_SCHEDULE stage_key=FOREST",
                "DS_P022_MODE mode=normal",
                "DS_P022_CLOCK name=stage-wave-100ms",
                "DS_P022_CLOCK name=stage-refill-250ms",
                "DS_P022_CLOCK name=stage-event-third",
                "DS_P022_TIE_CHECK tic=18 same_deadline=1 order=stage-wave-100ms,stage-refill-250ms",
                "DS_P022_COMPLETE tics=70 engine_world_ticks=70 attempts=0 admissions=0 rejected=0 refills=0 refill_admissions=0 cap_rejections=0 releases=0 alive=(0,0,0) next_indices=(21,9,7) rng_spawn=101 region=logical-reference-v1 mode=normal camera_invariant=true native_pause=1 backlog=0 source_timing=UNKNOWN geometry=ENGINEERING_APPROXIMATION",
            ]
        )
        result = validate(log, expected_variant=0)
        self.assertEqual(result["status"], "FAIL")
        self.assertIn("actual spawn trace is empty", result["errors"])
        self.assertIn("missing runtime boundary predicate trace", result["errors"])

    def test_strict_validator_rejects_tampered_deadline(self):
        log = "DS_P022_SPAWN event_id=1 tic=5 deadline=5 clock=stage-wave-100ms priority=0 row=0 attempt=0 kind=batch admitted=1 entity_id=1 alive=1 cap=4 x=160.000 y=0.000 side=1 lane=0 region=logical-reference-v1 rng_spawn=101"
        result = validate(log)
        self.assertEqual(result["status"], "FAIL")
        self.assertTrue(any("missing marker" in error for error in result["errors"]))

    def test_population_ledger_rejects_admission_when_cap_is_exhausted(self):
        attempts = [
            {"event_id": 1, "tic": 4, "clock": "stage-wave-100ms", "cap": 4, "admitted": 1, "alive": 1},
            {"event_id": 2, "tic": 4, "clock": "stage-wave-100ms", "cap": 4, "admitted": 1, "alive": 2},
            {"event_id": 3, "tic": 4, "clock": "stage-wave-100ms", "cap": 4, "admitted": 1, "alive": 3},
            {"event_id": 4, "tic": 7, "clock": "stage-wave-100ms", "cap": 4, "admitted": 1, "alive": 4},
            # The forged fifth attempt claims admission even though cap=4.
            {"event_id": 5, "tic": 7, "clock": "stage-wave-100ms", "cap": 4, "admitted": 1, "alive": 5},
        ]
        errors, _ = validate_attempt_ledger(attempts, [], "normal")
        self.assertTrue(any("admission does not match" in error for error in errors))
        self.assertTrue(any("alive transition" in error for error in errors))

    def test_population_ledger_rejects_bad_release_arithmetic(self):
        attempts = [
            {"event_id": 1, "tic": 4, "clock": "stage-wave-100ms", "cap": 4, "admitted": 1, "alive": 1},
            {"event_id": 2, "tic": 18, "clock": "stage-wave-100ms", "cap": 4, "admitted": 1, "alive": 2},
        ]
        releases = [{"tic": 17, "released": 1, "before": 4, "after": 3}]
        errors, _ = validate_attempt_ledger(attempts, releases, "normal")
        self.assertIn("release ledger does not match the derived wave population", errors)


if __name__ == "__main__":
    unittest.main()
