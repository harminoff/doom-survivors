import re
import unittest

from tools.run_p024_spatial import (
    exact_radius,
    expected_results,
    result_digest,
    validate,
    world_digest,
)


def _record(entity):
    return (
        f'DS_P024_WORLD version=1 slot={entity["slot"]} generation={entity["generation"]} '
        f'stable_id={entity["stable_id"]} live=1 x={entity["x"]:.6f} y={entity["y"]:.6f} radius={entity["radius"]:.6f}\n'
    )


def _mini_log():
    world = {
        0: {"slot": 0, "generation": 1, "stable_id": 1000, "live": 1, "x": -0.01, "y": 0.0, "radius": 0.0},
        1: {"slot": 1, "generation": 1, "stable_id": 1001, "live": 1, "x": -128.0, "y": 0.0, "radius": 0.0},
        2: {"slot": 2, "generation": 1, "stable_id": 1002, "live": 1, "x": -128.01, "y": 0.0, "radius": 0.0},
        3: {"slot": 3, "generation": 1, "stable_id": 1003, "live": 1, "x": 0.0, "y": 0.0, "radius": 260.0},
        4: {"slot": 4, "generation": 1, "stable_id": 1006, "live": 1, "x": 1990.0, "y": 2000.0, "radius": 0.0},
        5: {"slot": 5, "generation": 1, "stable_id": 1007, "live": 1, "x": 2010.0, "y": 2000.0, "radius": 0.0},
    }
    lines = [
        "DS_BOOT map=MAP10",
        "DS_P024_BOOT map=MAP10 ticrate=35 cell_size=128.000 floor=MATHEMATICAL grid=UNIFORM_CSR handles=FULL_GENERATION_STABLE_ID exact_narrow=SEPARATE randomized_worlds=DETERMINISTIC_ENGINEERING",
        "DS_P024_AUTHORITY logical_store=DSP020EntityStore query_input=LOGICAL_XY_RADIUS proxy_input=NONE camera_input=NONE random_seed=240924 source_parity=ENGINEERING_APPROXIMATION",
        "DS_P024_PROXY variant=0 hidden=0 culled=0 allocation_order=stable_ascending allocated=6 gameplay_input=0",
        "DS_P024_WORLD_BEGIN version=1 slots=6 live=6 digest=" + str(world_digest(world)),
    ]
    lines.extend(_record(entity).rstrip() for entity in world.values())
    lines.append(f'DS_P024_WORLD_END version=1 records=6 digest={world_digest(world)}')
    queries = [
        (1, "radius", -128.0, 0.0, 0.0, 0.0),
        (2, "rectangle", 64.0, -64.0, 64.0, -64.0),
        (3, "swept", -128.0, -128.0, -128.0, -128.0),
        (4, "nearest", -128.0, 0.0, 300.0, 0.0),
        (5, "nearest", 2000.0, 2000.0, 100.0, 0.0),
    ]
    for qid, kind, a, b, c, d in queries:
        expected = expected_results(world, kind, a, b, c, d)
        digest = result_digest(expected)
        lines.append(
            f"DS_P024_QUERY qid={qid} world=1 kind={kind} a={a:.6f} b={b:.6f} c={c:.6f} d={d:.6f} "
            f"brute_count={len(expected)} optimized_count={len(expected)} candidate_count={len(expected)} candidate_visits={len(expected)} "
            f"brute_checks=6 optimized_narrow_checks={len(expected)} brute_digest={digest} optimized_digest={digest} parity=1 "
            f"nearest_slot={expected[0][0] if kind == 'nearest' and expected else -1} nearest_generation={expected[0][1] if kind == 'nearest' and expected else 0} nearest_id={expected[0][2] if kind == 'nearest' and expected else 0}"
        )
        for path in ("brute", "optimized"):
            for ordinal, (slot, generation, stable_id) in enumerate(expected):
                lines.append(f"DS_P024_RESULT qid={qid} path={path} ordinal={ordinal} slot={slot} generation={generation} stable_id={stable_id}")
    lines.extend(
        [
            "DS_P024_NEAREST_TIE_CHECK query=(2000.000,2000.000) max_radius=100.000 equal_distance=1 lower_stable_id_wins=1",
            "DS_P024_STALE old_slot=1 old_generation=1 old_stable_id=1001 replacement_slot=1 replacement_generation=2 replacement_stable_id=2001 stale_rejected=1 update_after_reuse=1",
            "DS_P024_REBASE old_origin=(32.500,-71.250) new_origin=(-400.000,203.000) logical_digest_before=1 logical_digest_after=1 query_unchanged=1",
            "DS_P024_PERF_WORKLOAD ordinal=0 kind=0 a=-128.000000 b=0.000000 c=0.000000 d=0.000000",
            "DS_P024_PERF entity_count=6 query_count=1 repeat_count=1 brute_checks=6 optimized_candidates=2 optimized_narrow_checks=2 brute_ms=2.000 optimized_ms=1.000 brute_digest=2068564606 optimized_digest=2068564606 workload_digest=65142086 parity=1 timing_scope=QUERY_ONLY index_rebuild_excluded=1",
            "DS_P024_COMPLETE worlds=1 queries=5 failures=0 stale_rejected=1 proxy_variant=0 performance_workload=DECLARED_ENGINEERING_WORLD timing_scope=QUERY_ONLY",
        ]
    )
    return "\n".join(lines) + "\n"


class P024SpatialValidatorTests(unittest.TestCase):
    def test_exact_radius_is_closed_and_invalid_radius_fails(self):
        entity = {"x": 4.0, "y": 0.0, "radius": 0.0}
        self.assertTrue(exact_radius(entity, 0.0, 0.0, 4.0))
        self.assertFalse(exact_radius(entity, 0.0, 0.0, -1.0))

    def test_full_fixture_validator_accepts_ordered_lists_and_nearest_tie(self):
        result = validate(_mini_log(), expected_variant=0)
        self.assertEqual(result["status"], "PASS", result["errors"])

    def test_marker_only_fails_closed(self):
        result = validate("DS_BOOT map=MAP10\nDS_P024_COMPLETE worlds=5 queries=21 failures=0")
        self.assertEqual(result["status"], "FAIL")
        self.assertTrue(any("marker-only" in error for error in result["errors"]))

    def test_negative_mutations_are_rejected(self):
        good = _mini_log()
        mutations = {
            "truncated-list": good.replace("DS_P024_RESULT qid=1 path=optimized ordinal=1 slot=3 generation=1 stable_id=1003\n", ""),
            "reordered-list": good.replace(
                "DS_P024_RESULT qid=1 path=brute ordinal=0 slot=1 generation=1 stable_id=1001\nDS_P024_RESULT qid=1 path=brute ordinal=1 slot=3 generation=1 stable_id=1003",
                "DS_P024_RESULT qid=1 path=brute ordinal=0 slot=3 generation=1 stable_id=1003\nDS_P024_RESULT qid=1 path=brute ordinal=1 slot=1 generation=1 stable_id=1001",
            ),
            "boundary": good.replace("qid=1 world=1 kind=radius a=-128.000000", "qid=1 world=1 kind=radius a=-127.000000"),
            "stale": good.replace("stale_rejected=1", "stale_rejected=0"),
            "camera-proxy": good.replace("DS_P024_PROXY variant=0", "DS_P024_PROXY variant=1"),
            "workload-mismatch": good.replace("repeat_count=1 brute_checks=6", "repeat_count=2 brute_checks=6"),
            "nearest-tie": good.replace("qid=5 path=optimized ordinal=0 slot=4 generation=1 stable_id=1006", "qid=5 path=optimized ordinal=0 slot=5 generation=1 stable_id=1007"),
        }
        for name, mutated in mutations.items():
            with self.subTest(name=name):
                result = validate(mutated, expected_variant=0)
                self.assertEqual(result["status"], "FAIL", name)


if __name__ == "__main__":
    unittest.main()
