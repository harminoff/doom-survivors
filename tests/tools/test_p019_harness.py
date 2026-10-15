import unittest

from tools.test_runner.runner import (
    canonical_trace,
    compare_engine_runs,
    completion,
    ensure_package_identity,
    finalize_result,
    validate_log,
)


def complete_line(scenario="hash_replay", telemetry=1, damage=48):
    return (
        f"DS_P019_COMPLETE scenario={scenario} input_tape=spiral-v1 telemetry={telemetry} "
        f"tics=120 canonical_hash=-1169418620 rng=(-1976428200,919613859,2105997568,1551907806) "
        f"spawn_attempts=4 spawn_admissions=4 alive=0 attacks=17 hits=16 damage={damage} xp={damage} "
        "drops=4 drafts=2 durable=2 offscreen=2 camera_is_presentation=true"
    )


def state_line(tic=10):
    return (
        f"DS_P019_CANONICAL_TRACE tic={tic} hash={tic + 100}\n"
        f"DS_P019_STATE tic={tic} hash={tic + 100} player=(2.000,0.000) alive=4 "
        "spawn_attempts=1 spawn_admissions=1 attacks=1 hits=1 damage=3 xp=3 "
        "drops=0 drafts=0 durable=0 rng=(-1761605649,53565446,303,404) offscreen=2"
    )


def passing_log(telemetry=1, scenario="hash_replay"):
    lines = [
        f"DS_P019_BOOT map=MAP05 ticrate=35 scenario={scenario} input_tape=spiral-v1 telemetry={telemetry} execution=REALTIME logical_tics=120",
        "DS_P019_CANONICAL schema=gameplay-v1 excludes=camera,pitch,fov,render,telemetry presentation=separate",
    ]
    for tic in range(10, 121, 10):
        lines.append(state_line(tic).splitlines()[0])
        if telemetry:
            lines.append(state_line(tic).splitlines()[1])
    lines.append(complete_line(scenario, telemetry))
    return "\n".join(lines)


class P019HarnessParserTests(unittest.TestCase):
    def test_hash_replay_requires_canonical_trace_and_counters(self):
        result = validate_log(passing_log(), "hash_replay", telemetry=1)
        self.assertEqual(result["status"], "PASS", result["errors"])
        self.assertEqual(len(result["canonical_trace"]), 12)
        self.assertEqual(result["completion"]["hash"], -1169418620)

    def test_telemetry_off_keeps_hash_trace_and_drops_optional_state(self):
        result = validate_log(passing_log(telemetry=0), "hash_replay", telemetry=0)
        self.assertEqual(result["status"], "PASS", result["errors"])
        self.assertEqual(len(result["canonical_trace"]), 12)
        self.assertEqual(result["trace"], [])

    def test_wrong_damage_requires_engine_assertion(self):
        log = passing_log("1", "wrong_damage").replace(
            complete_line("wrong_damage"),
            "DS_P019_DAMAGE expected=3 observed=4 target=0 tic=35",
        )
        result = validate_log(log, "wrong_damage", expected_failure=True, telemetry=1)
        self.assertEqual(result["status"], "FAIL")
        self.assertTrue(any("engine did not assert" in error for error in result["errors"]))

        actual = passing_log("1", "wrong_damage").replace(
            complete_line("wrong_damage"),
            "DS_P019_DAMAGE expected=3 observed=4 target=0 tic=35\nDS_ASSERT_FAIL wrong_damage_detected",
        )
        result = validate_log(actual, "wrong_damage", expected_failure=True, telemetry=1)
        self.assertEqual(result["status"], "PASS", result["errors"])

    def test_missing_completion_cannot_be_green(self):
        log = passing_log("1", "missing_completion").replace(complete_line("missing_completion"), "")
        result = validate_log(log, "missing_completion", expected_failure=True, telemetry=1)
        self.assertEqual(result["status"], "FAIL")
        self.assertTrue(any("missing-completion" in error or "missing P019" in error for error in result["errors"]))

        log = passing_log("1", "missing_completion").replace(
            complete_line("missing_completion"),
            "DS_P019_INTENTIONAL_MISSING_COMPLETION tics=120 canonical_hash=-1",
        )
        result = validate_log(log, "missing_completion", expected_failure=True, telemetry=1)
        self.assertEqual(result["status"], "PASS", result["errors"])

    def test_camera_matrix_requires_framebuffer_marker(self):
        log = passing_log(scenario="camera_invariance")
        result = validate_log(log, "camera_invariance", telemetry=1, require_visual=True)
        self.assertEqual(result["status"], "FAIL")
        self.assertTrue(any("framebuffer" in error for error in result["errors"]))

    def test_completion_parser_and_hash_trace_fail_closed(self):
        self.assertIsNone(completion("DS_P019_COMPLETE missing fields"))
        self.assertEqual(canonical_trace("DS_P019_CANONICAL_TRACE tic=10 hash=-2"), [{"tic": 10, "hash": -2}])
        broken = passing_log().replace("DS_P019_CANONICAL_TRACE tic=120 hash=220\n", "")
        result = validate_log(broken, "hash_replay", telemetry=1)
        self.assertEqual(result["status"], "FAIL")

    def test_two_engine_run_comparison_rejects_divergent_or_missing_trace(self):
        first = {"canonical_trace": [{"tic": 10, "hash": 1}], "completion": {"hash": 2, "spawn": 3, "attack": 4, "drop": 5, "draft": 6}}
        second = {"canonical_trace": [{"tic": 10, "hash": 9}], "completion": {"hash": 8, "spawn": 3, "attack": 4, "drop": 5, "draft": 6}}
        result = compare_engine_runs(first, second, label="replay")
        self.assertFalse(result["canonical_trace_equal"])
        self.assertTrue(result["errors"])
        missing = compare_engine_runs(first, {"canonical_trace": [], "completion": {}}, label="telemetry")
        self.assertFalse(missing["canonical_trace_equal"])
        self.assertTrue(any("missing" in error for error in missing["errors"]))

    def test_runtime_gate_error_recomputes_result_status(self):
        result = finalize_result({"status": "PASS", "errors": ["unsupported GUI"]})
        self.assertEqual(result["status"], "FAIL")
        self.assertEqual(finalize_result({"status": "PASS", "errors": []})["status"], "PASS")

    def test_runtime_package_identity_mismatch_cannot_stay_green(self):
        result = ensure_package_identity(
            {"status": "PASS", "errors": [], "package_sha256": "runtime"},
            "compiled",
            label="replay A",
        )
        self.assertEqual(result["status"], "FAIL")
        self.assertTrue(any("package identity changed" in error for error in result["errors"]))

    def test_engine_run_comparison_rejects_identity_drift(self):
        first = {
            "canonical_trace": [{"tic": 10, "hash": 1}],
            "completion": {"hash": 2, "spawn": 3, "attack": 4, "drop": 5, "draft": 6},
            "package_sha256": "same-package",
            "engine_sha256": "engine-a",
        }
        second = {
            **first,
            "engine_sha256": "engine-b",
        }
        result = compare_engine_runs(first, second, label="replay")
        self.assertTrue(any("engine identity" in error for error in result["errors"]))


if __name__ == "__main__":
    unittest.main()
