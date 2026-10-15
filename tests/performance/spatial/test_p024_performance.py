import copy
import unittest

from tools.run_p024_spatial import (
    expected_results,
    multiply_add,
    result_digest,
    validate_performance_record,
)


WORLD = {
    0: {"slot": 0, "generation": 1, "stable_id": 1000, "x": -128.0, "y": 0.0, "radius": 0.0},
    1: {"slot": 1, "generation": 1, "stable_id": 1001, "x": 0.0, "y": 0.0, "radius": 32.0},
    2: {"slot": 2, "generation": 2, "stable_id": 2002, "x": 256.0, "y": 0.0, "radius": 4.0},
}


def _workload():
    return [
        {"ordinal": "0", "kind": "0", "a": "-128.0", "b": "0.0", "c": "0.0", "d": "0.0"},
        {"ordinal": "1", "kind": "1", "a": "32.0", "b": "-32.0", "c": "32.0", "d": "32.0"},
        {"ordinal": "2", "kind": "2", "a": "-64.0", "b": "0.0", "c": "320.0", "d": "0.0"},
        {"ordinal": "3", "kind": "3", "a": "256.0", "b": "0.0", "c": "100.0", "d": "0.0"},
    ]


def _good_perf():
    workload = _workload()
    workload_digest = 216613626
    expected_workload = []
    kind_names = ("radius", "rectangle", "swept", "nearest")
    for row in workload:
        mode = int(row["kind"])
        values = tuple(float(row[key]) for key in ("a", "b", "c", "d"))
        workload_digest = multiply_add(workload_digest, 31, mode)
        for value in values:
            workload_digest = multiply_add(workload_digest, 31, int(value * 1000.0))
        expected_workload.append((kind_names[mode], *values))
    result = 216613626
    for _ in range(2):
        for kind, a, b, c, d in expected_workload:
            result = multiply_add(result, 31, result_digest(expected_results(WORLD, kind, a, b, c, d)))
    perf = {
        "entity_count": "3",
        "query_count": "4",
        "repeat_count": "2",
        "brute_checks": "24",
        "optimized_narrow_checks": "8",
        "brute_ms": "10.0",
        "optimized_ms": "5.0",
        "brute_digest": str(result),
        "optimized_digest": str(result),
        "workload_digest": str(workload_digest),
        "parity": "1",
        "timing_scope": "QUERY_ONLY",
        "index_rebuild_excluded": "1",
    }
    return workload, perf


class P024PerformanceContractTests(unittest.TestCase):
    def test_same_workload_arithmetic_and_ordered_digest_pass(self):
        workload, perf = _good_perf()
        self.assertEqual(validate_performance_record(perf, workload, WORLD), [])

    def test_non_improving_time_or_mismatched_workload_is_rejected(self):
        workload, perf = _good_perf()

        slower = copy.deepcopy(perf)
        slower["optimized_ms"] = slower["brute_ms"]
        self.assertTrue(any("not faster" in error for error in validate_performance_record(slower, workload, WORLD)))

        wrong_checks = copy.deepcopy(perf)
        wrong_checks["brute_checks"] = "23"
        self.assertTrue(any("workload mismatch" in error for error in validate_performance_record(wrong_checks, workload, WORLD)))

        reordered = copy.deepcopy(workload)
        reordered[0], reordered[1] = reordered[1], reordered[0]
        errors = validate_performance_record(perf, reordered, WORLD)
        self.assertTrue(any("truncated or reordered" in error for error in errors))
        self.assertTrue(any("workload digest" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
