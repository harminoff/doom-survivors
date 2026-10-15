import unittest

from tools.run_persistence_bench import (
    PROFILE_ENTITY_COUNT,
    SOURCE_FACT,
    archived_values,
    synthetic_payload,
    validate,
)


def scenario_line(name, extra=""):
    return f"DS_P016_SCENARIO name={name} {extra}"


def passing_log() -> str:
    lines = [
        "DS_P016_WORLD_LOADED is_save=0 run_marker=1000 generation=1",
        SOURCE_FACT,
        f"DS_P016_STARTUP_READ accepted=1 entities={PROFILE_ENTITY_COUNT} hash=1500823983 marker=2500 persisted_len=8000",
        f"DS_P016_SEED generation=1 entities={PROFILE_ENTITY_COUNT} hash=-1651527496",
        f"DS_P016_WRITE result=OK schema=1 hash=-1651527496 entities={PROFILE_ENTITY_COUNT} saved=1",
        "DS_P016_FAILED_PURCHASE end granted=false payload_unchanged=1",
        "DS_P016_CORRUPT outcome accepted=0",
        "DS_P016_READ result=REFUSED reason=malformed_or_hash_mismatch",
        "DS_P016_SCHEMA_BUMP outcome accepted=0",
        "DS_P016_READ result=REFUSED reason=schema_mismatch",
        f"DS_P016_WRITE result=OK schema=1 hash=-1651527496 entities={PROFILE_ENTITY_COUNT} saved=1",
        f"DS_P016_WRITE result=OK schema=1 hash=-1651527496 entities={PROFILE_ENTITY_COUNT} saved=1",
        f"DS_P016_WRITE result=OK schema=1 hash=1500823983 entities={PROFILE_ENTITY_COUNT} saved=1",
    ]
    return "\n".join(lines)


def passing_restart_log() -> str:
    return f"DS_P016_STARTUP_READ accepted=1 entities={PROFILE_ENTITY_COUNT} hash=1500823983 marker=2500 persisted_len=8000"


def saved_profile() -> dict:
    return {
        "ds_p016_marker": "2500",
        "ds_p016_payload": synthetic_payload(500),
        "ds_p016_profile_id": "profile-a",
        "ds_p016_schema_version": "1",
    }


def strict_evidence() -> dict:
    readonly = "\n".join([
        "DS_P016_STARTUP_READ accepted=1 entities=512 hash=1 marker=2400 persisted_len=8000",
        "DS_P016_WRITE result=SAVE_FAILED schema=1 hash=1 entities=512 saved=0",
    ])
    interrupted = (
        "DS_P016_STARTUP_READ accepted=0 entities=-1 hash=0 marker=2400 persisted_len=24\n"
        "DS_P016_READ result=REFUSED reason=malformed_or_hash_mismatch"
    )
    other = saved_profile()
    other["ds_p016_profile_id"] = "profile-b"
    other["ds_p016_payload"] = synthetic_payload(9000)
    load = "\n".join([
        "DS_P016_RESTORE_PROBE phase_tic=121 marker=2561 generation=2 entities=512 "
        "started_this_process=0 pos=(-176.000,22.000,0.000) yaw=37.000 pitch=-11.000 "
        "fov=83.000 attacks=3 offscreen=2 proxies=3",
        "DS_P016_FP_CONTEXT coherent=1 adapter_revision=fp-adapter-v1 "
        "input_mode=look_relative_wasd logical_window=independent_xy",
        "DS_P016_MAP_TRANSITION_FP coherent=1 pose=(-176.000,22.000,0.000,37.000,-11.000) "
        "desired_fov=83.000 current_fov=90.000 saved_fov=83.000 actual_proxies=3",
        "DS_P016_MAP_TRANSITION map=MAP01 count=1 marker=2561 generation=2 "
        "entities=512 hash=1500823983",
        "DS_P016_RENDER_STATE actors=3 attacks=3 offscreen=2 duplicate_actors=0",
        "DS_P016_RUN_SAVE_RESTORED phase_tic=66 marker=2562 generation=2 "
        "hash=1500823983 entities=512",
    ])
    return {
        "readonly_log": readonly,
        "readonly_before": b"valid config",
        "readonly_after": b"valid config",
        "interrupted_log": interrupted,
        "profile_b": other,
        "first_exit_code": -9,
        "load_log": load,
        "strict": True,
    }


class PersistenceBenchParserTests(unittest.TestCase):
    def test_complete_investigation_passes(self):
        result = validate(passing_log(), passing_restart_log(), saved_profile())
        self.assertEqual(result["status"], "PASS", result["errors"])

    def test_restart_must_accept_the_persisted_profile(self):
        log = passing_restart_log().replace("accepted=1", "accepted=0")
        self.assertEqual(validate(passing_log(), log, saved_profile())["status"], "FAIL")

    def test_restart_must_restore_the_final_marker(self):
        log = passing_restart_log().replace("marker=2500", "marker=1000")
        self.assertEqual(validate(passing_log(), log, saved_profile())["status"], "FAIL")

    def test_missing_restart_read_fails(self):
        self.assertEqual(validate(passing_log(), "", saved_profile())["status"], "FAIL")

    def test_corruption_must_be_refused(self):
        log = passing_log().replace("DS_P016_CORRUPT outcome accepted=0",
                                    "DS_P016_CORRUPT outcome accepted=1")
        self.assertEqual(validate(log, passing_restart_log(), saved_profile())["status"], "FAIL")

    def test_schema_mismatch_must_be_refused(self):
        log = passing_log().replace("DS_P016_SCHEMA_BUMP outcome accepted=0",
                                    "DS_P016_SCHEMA_BUMP outcome accepted=1")
        self.assertEqual(validate(log, passing_restart_log(), saved_profile())["status"], "FAIL")

    def test_refusals_need_explicit_reasons(self):
        log = passing_log().replace("reason=malformed_or_hash_mismatch", "reason=unknown")
        self.assertEqual(validate(log, passing_restart_log(), saved_profile())["status"], "FAIL")
        log = passing_log().replace("reason=schema_mismatch", "reason=unknown")
        self.assertEqual(validate(log, passing_restart_log(), saved_profile())["status"], "FAIL")

    def test_failed_purchase_must_not_grant_or_damage(self):
        granted = passing_log().replace("granted=false", "granted=true")
        self.assertEqual(validate(granted, passing_restart_log(), saved_profile())["status"], "FAIL")
        damaged = passing_log().replace("payload_unchanged=1", "payload_unchanged=0")
        self.assertEqual(validate(damaged, passing_restart_log(), saved_profile())["status"], "FAIL")

    def test_source_fact_marker_is_required(self):
        log = passing_log().replace("zscript_cvar_declaration=UNSUPPORTED",
                                    "zscript_cvar_declaration=SUPPORTED")
        self.assertEqual(validate(log, passing_restart_log(), saved_profile())["status"], "FAIL")

    def test_persisted_payload_must_carry_schema_prefix(self):
        saved = saved_profile()
        saved["ds_p016_payload"] = "500:1:77"
        self.assertEqual(validate(passing_log(), passing_restart_log(), saved)["status"], "FAIL")

    def test_persisted_schema_version_is_checked(self):
        saved = saved_profile()
        saved["ds_p016_schema_version"] = "9"
        self.assertEqual(validate(passing_log(), passing_restart_log(), saved)["status"], "FAIL")

    def test_a_write_reporting_saved_zero_fails(self):
        log = passing_log().replace("saved=1", "saved=0")
        self.assertEqual(validate(log, passing_restart_log(), saved_profile())["status"], "FAIL")

    def test_vm_abort_fails_even_with_valid_markers(self):
        log = passing_log().replace(
            "DS_P016_WRITE result=OK", "VM execution aborted: bad\nDS_P016_WRITE result=OK", 1
        )
        self.assertEqual(validate(log, passing_restart_log(), saved_profile())["status"], "FAIL")

    def test_archived_values_reads_only_ds_p016_cvars(self):
        import tempfile
        from pathlib import Path

        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "config.ini"
            config.write_text(
                "[GlobalSettings]\n"
                "vid_maxfps=60\n"
                "ds_p016_marker=2500\n"
                "ds_p016_payload=v1;ids;hash=1\n"
                "some_other=1\n",
                encoding="utf-8",
            )
            values = archived_values(config)
            self.assertEqual(values["ds_p016_marker"], "2500")
            self.assertIn("ds_p016_payload", values)
            self.assertNotIn("vid_maxfps", values)
            self.assertNotIn("some_other", values)

    def test_archived_values_missing_file_is_empty(self):
        from pathlib import Path

        self.assertEqual(archived_values(Path("does-not-exist.ini")), {})

    def test_read_only_storage_requires_refusal_and_byte_preservation(self):
        readonly = "\n".join([
            "DS_P016_STARTUP_READ accepted=1 entities=512 hash=1 marker=2400 persisted_len=8000",
            "DS_P016_WRITE result=SAVE_FAILED schema=1 hash=1 entities=512 saved=0",
        ])
        before = b"valid config"
        self.assertEqual(validate(passing_log(), passing_restart_log(), saved_profile(), readonly,
                                  before, before)["status"], "PASS")
        self.assertEqual(validate(passing_log(), passing_restart_log(), saved_profile(), readonly,
                                  before, b"changed")["status"], "FAIL")
        self.assertEqual(validate(passing_log(), passing_restart_log(), saved_profile(),
                                  readonly.replace("SAVE_FAILED", "OK"), before, before)["status"], "FAIL")

    def test_interrupted_write_requires_explicit_startup_refusal(self):
        interrupted = "DS_P016_STARTUP_READ accepted=0 entities=-1 hash=0 marker=2400 persisted_len=24\nDS_P016_READ result=REFUSED reason=malformed_or_hash_mismatch"
        self.assertEqual(validate(passing_log(), passing_restart_log(), saved_profile(),
                                  interrupted_log=interrupted)["status"], "PASS")
        self.assertEqual(validate(passing_log(), passing_restart_log(), saved_profile(),
                                  interrupted_log=interrupted.replace("accepted=0", "accepted=1"))["status"], "FAIL")

    def test_independent_profile_requires_distinct_id_and_payload(self):
        other = saved_profile()
        other["ds_p016_profile_id"] = "profile-b"
        other["ds_p016_payload"] = synthetic_payload(9000)
        self.assertEqual(validate(passing_log(), passing_restart_log(), saved_profile(),
                                  profile_b=other)["status"], "PASS")
        other["ds_p016_payload"] = saved_profile()["ds_p016_payload"]
        self.assertEqual(validate(passing_log(), passing_restart_log(), saved_profile(),
                                  profile_b=other)["status"], "FAIL")

    def test_strict_runtime_validation_rejects_missing_evidence(self):
        self.assertEqual(validate(passing_log(), passing_restart_log(), saved_profile(),
                                  strict=True)["status"], "FAIL")

    def test_strict_runtime_validation_requires_preserved_transition_state(self):
        evidence = strict_evidence()
        self.assertEqual(validate(passing_log(), passing_restart_log(), saved_profile(),
                                  **evidence)["status"], "PASS")
        evidence["load_log"] = evidence["load_log"].replace(
            "marker=2561 generation=2 entities=512 hash=1500823983",
            "marker=0 generation=0 entities=0 hash=0",
        )
        self.assertEqual(validate(passing_log(), passing_restart_log(), saved_profile(),
                                  **evidence)["status"], "FAIL")


if __name__ == "__main__":
    unittest.main()
