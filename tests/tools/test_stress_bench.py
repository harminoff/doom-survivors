import unittest

from tools.bench.sampler import MemoryTrace, describe, percentile
from tools.run_stress_bench import EXPECTED_SCENARIOS, validate


def scenario(name, mode, result="OK", reason="none", enemies="100", active="40",
             projectiles="40", pickups="30", tics="60", pair_checks="1000",
             hits="10", signature="55", moved="40", grid="1", grid_cells="20",
             proxies="40", store_items="170", drops="0", collected="3",
             timing=True):
    line = (
        f"DS_P015_SCENARIO name={name} mode={mode} result={result} reason={reason} "
        f"enemies={enemies} active={active} projectiles={projectiles} pickups={pickups} "
        f"tics={tics} pair_checks={pair_checks} hits={hits} hit_signature={signature} "
        f"moved={moved} grid={grid} grid_cells={grid_cells} proxies={proxies} "
        f"store_items={store_items} drops={drops} collected={collected}"
    )
    if timing:
        line += " ms=10.00 mean_work_ms=0.100 worst_tick_ms=0.500"
    return line


def passing_log() -> str:
    names = [
        ("equivalence_brute", "brute", "0"),
        ("equivalence_grid", "grid", "1"),
        ("equivalence_grid_large_store", "grid", "1"),
        ("sweep_500", "grid", "1"),
        ("sweep_1000", "grid", "1"),
        ("sweep_2000", "grid", "1"),
        ("sweep_3000", "grid", "1"),
        ("sweep_5000", "grid", "1"),
        ("orientation_front", "grid", "1"),
        ("orientation_rear", "grid", "1"),
        ("churn", "grid", "1"),
        ("cleanup", "none", "0"),
    ]
    lines = [
        "DS_P015_BEGIN map=MAP04 ticrate=35 scenarios=12 proxy_cap=300 cell_size=128.0 "
        "grid_axes=16 classification=SYNTHETIC_ENGINEERING_STRESS",
        "DS_P015_SOURCE_FACT logical_store=STRUCT_OF_ARRAYS broad_phase=UNIFORM_GRID_CSR "
        "proxy_pool=BOUNDED_CAP counts_are_source_caps=false",
    ]
    for name, mode, grid in names:
        lines.append(scenario(name, mode, result="BEGIN", reason="none", grid=grid, timing=False,
                              pair_checks="0", hits="0", signature="0", moved="0",
                              grid_cells="0", proxies="0", drops="0", collected="0",
                              store_items="0"))
        if name == "cleanup":
            lines.append(scenario(name, mode, enemies="0", active="0", projectiles="0",
                                  pickups="0", pair_checks="0", hits="0", signature="0",
                                  moved="0", grid=grid, grid_cells="0", proxies="0",
                                  store_items="0", collected="0"))
        else:
            lines.append(scenario(name, mode, grid=grid))
    lines.append(
        "DS_P015_COMPLETE scenarios=12 failures=0 total_ms=22862.73 peak_store_items=7400 "
        "peak_proxies=300 final_store_items=0 final_proxies=0 source_parity=OPEN_SYNTHETIC_BENCHMARK"
    )
    return "\n".join(lines)


class StressBenchParserTests(unittest.TestCase):
    def test_complete_benchmark_passes(self):
        result = validate(passing_log())
        self.assertEqual(result["status"], "PASS", result["errors"])
        self.assertEqual(len(result["scenarios"]), EXPECTED_SCENARIOS)

    def test_every_scenario_reports_timing(self):
        result = validate(passing_log())
        for row in result["scenarios"]:
            self.assertIsNotNone(row["worst_tick_ms"], row["name"])
            self.assertIsNotNone(row["mean_work_ms"], row["name"])

    def test_missing_scenario_fails(self):
        log = "\n".join(
            line for line in passing_log().splitlines()
            if "name=churn" not in line
        )
        self.assertEqual(validate(log)["status"], "FAIL")

    def test_scenario_failure_fails_the_benchmark(self):
        log = passing_log().replace(
            "name=sweep_5000 mode=grid result=OK reason=none",
            "name=sweep_5000 mode=grid result=FAIL reason=broad_phase_result_mismatch",
        )
        result = validate(log)
        self.assertEqual(result["status"], "FAIL")
        self.assertTrue(any("sweep_5000" in error for error in result["errors"]))

    def test_static_only_scenario_fails_A01(self):
        # A scenario that checks collisions but never hits anything is not
        # real combat work and must not pass.
        log = passing_log().replace(
            "name=sweep_1000 mode=grid result=OK reason=none enemies=100 active=40 "
            "projectiles=40 pickups=30 tics=60 pair_checks=1000 hits=10",
            "name=sweep_1000 mode=grid result=OK reason=none enemies=100 active=40 "
            "projectiles=40 pickups=30 tics=60 pair_checks=1000 hits=0",
        )
        self.assertEqual(validate(log)["status"], "FAIL")

    def test_wrong_mode_fails(self):
        log = passing_log().replace(
            "name=equivalence_brute mode=brute", "name=equivalence_brute mode=grid"
        )
        self.assertEqual(validate(log)["status"], "FAIL")

    def test_residual_store_or_proxy_after_cleanup_fails(self):
        self.assertEqual(
            validate(passing_log().replace("final_store_items=0", "final_store_items=25"))["status"],
            "FAIL",
        )
        self.assertEqual(
            validate(passing_log().replace("final_proxies=0", "final_proxies=300"))["status"],
            "FAIL",
        )

    def test_internal_failure_count_fails(self):
        log = passing_log().replace("failures=0", "failures=1")
        self.assertEqual(validate(log)["status"], "FAIL")

    def test_source_cap_denial_marker_is_required(self):
        log = passing_log().replace("counts_are_source_caps=false", "counts_are_source_caps=true")
        self.assertEqual(validate(log)["status"], "FAIL")

    def test_vm_abort_fails(self):
        log = passing_log().replace(
            "DS_P015_COMPLETE", "VM execution aborted: bad\nDS_P015_COMPLETE", 1
        )
        self.assertEqual(validate(log)["status"], "FAIL")


class SamplerTests(unittest.TestCase):
    def test_percentile_matches_nearest_rank_expectations(self):
        values = [float(n) for n in range(1, 101)]
        self.assertEqual(percentile(values, 0.50), 50.5)
        self.assertIsNotNone(percentile(values, 0.95))
        self.assertIsNone(percentile([], 0.5))

    def test_percentile_single_value_and_bounds(self):
        self.assertEqual(percentile([4.0], 0.99), 4.0)
        with self.assertRaises(ValueError):
            percentile([1.0], 1.5)

    def test_describe_reports_order_statistics(self):
        described = describe([1.0, 2.0, 3.0, 4.0])
        self.assertEqual(described["count"], 4)
        self.assertEqual(described["min"], 1.0)
        self.assertEqual(described["max"], 4.0)
        self.assertLessEqual(described["p50"], described["p95"])
        self.assertLessEqual(described["p95"], described["p99"])

    def test_memory_trace_marks_unsupported_rather_than_zero(self):
        trace = MemoryTrace(supported=False, note="unavailable")
        summary = trace.summary()
        self.assertFalse(summary["supported"])
        self.assertEqual(summary["samples"], 0)

    def test_memory_trace_summary_math(self):
        trace = MemoryTrace(supported=True, note="sampled")
        trace.record(0.0, 100)
        trace.record(1.0, 300)
        trace.record(2.0, 200)
        summary = trace.summary()
        self.assertEqual(summary["start_bytes"], 100)
        self.assertEqual(summary["end_bytes"], 200)
        self.assertEqual(summary["peak_bytes"], 300)
        self.assertEqual(summary["delta_bytes"], 100)


if __name__ == "__main__":
    unittest.main()
