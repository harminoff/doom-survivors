import json
import unittest
from pathlib import Path

from tools.run_p030_vertical_slice import validate, validate_negative_mutations
from tools import slice_source


ROOT = Path(__file__).resolve().parents[3]


def accepted_log() -> str | None:
    latest = ROOT / "evidence/P030/latest-result.json"
    try:
        artifact = json.loads(latest.read_text(encoding="utf-8"))
    except (OSError, TypeError, ValueError):
        return None
    if artifact.get("status") != "PASS":
        return None
    runs = artifact.get("runs", [])
    if not runs:
        return None
    path = Path(runs[0].get("evidence", "")) / "engine.log"
    return path.read_text(encoding="utf-8", errors="replace") if path.exists() else None


class P030VerticalSliceValidatorTests(unittest.TestCase):
    def test_one_minute_mode_is_opt_in_and_bounded(self):
        launcher = (ROOT / "Launch Doom Survivors.ps1").read_text(encoding="utf-8")
        source = slice_source.read()
        self.assertIn("[ValidateSet(0, 1)]", launcher)
        self.assertIn("[int]$TestMinutes = 0", launcher)
        self.assertIn('"ds_p030_duration_tics", [string]$durationTics', launcher)
        self.assertIn("survivalTics != MIN_SURVIVAL_TICS && survivalTics != MAX_SURVIVAL_TICS", source)
        self.assertIn("tic >= RunEndTic()", source)
        self.assertLess(source.index("ConfigureDuration(); ResetRunState();"),
                        source.index('if (configuredMode == "harness") ResetRunState();'))

    def test_actual_one_minute_engine_run_reaches_results(self):
        log_path = ROOT / "evidence/P030/20260913T180803164391Z-doom-survivors-duration2/engine.log"
        if not log_path.exists():
            self.skipTest("one-minute actual-engine evidence is not present")
        result = validate(log_path.read_text(encoding="utf-8", errors="replace"),
                          accelerated=False, expected_duration=2100)
        self.assertEqual(result["status"], "PASS", result["errors"])
        self.assertEqual(result["complete"][0]["peak_whip_proxies"], "1")

    def test_validator_rejects_unapproved_duration_contract(self):
        result = validate("", expected_duration=4200)
        self.assertEqual(result["status"], "FAIL")
        self.assertIn("unsupported expected duration: 4200", result["errors"])

    def test_whip_proxy_has_bounded_five_tic_lifetime_and_runtime_guard(self):
        source = slice_source.read()
        start = source.index("class DSP030WhipProxy")
        proxy = source[start : source.index("\nclass ", start + 1)]
        self.assertEqual(proxy.count("WWHP A 2 Bright;"), 2)
        self.assertEqual(proxy.count("WWHP A 1 Bright;"), 1)
        self.assertIn("Stop;", proxy)
        self.assertNotIn("Loop;", proxy)
        self.assertIn("kind=P030_WHIP_PROXY_LEAK", source)
        self.assertIn("peak_whip_proxies=%d whip_proxy_limit=2", source)

    def test_native_input_and_modal_ui_ownership_contract(self):
        source = slice_source.read()
        p028 = (ROOT / "src/zscript/ui/levelup/LevelUpOverlay.zs").read_text(encoding="utf-8")
        p029 = (ROOT / "src/zscript/gameplay/RunController.zs").read_text(encoding="utf-8")
        p037 = (ROOT / "src/zscript/ui/orbit/OrbitMap23Runtime.zs").read_text(encoding="utf-8")
        p038 = (ROOT / "src/zscript/ui/ground/GroundMap24Runtime.zs").read_text(encoding="utf-8")
        registrations = (ROOT / "src/resources/mapinfo/dsbase.txt").read_text(encoding="utf-8")

        # UZDoom skips InputProcess and blocks native mouse input while this
        # handler is a UI processor. Active play and every active transition
        # must therefore release UI ownership.
        self.assertIn("IsUiProcessor = false; RequireMouse = true;", source)
        self.assertIn("runState = STATE_STARTING; priorState = STATE_STARTING; IsUiProcessor = false;", source)
        self.assertIn('Transition(STATE_ACTIVE, "LEVELUP_COMMITTED"); IsUiProcessor = false;', source)

        # Modal/results input arrives as GUI KeyChar events. Preserve the
        # advertised W/S aliases, arrows, edge latches, confirm and return.
        self.assertIn("key == 87 || key == 119", source)
        self.assertIn("key == 83 || key == 115", source)
        self.assertIn("if (!down) { upHeld = false; return true; }", source)
        self.assertIn("if (!down) { downHeld = false; return true; }", source)
        self.assertIn('SendNetworkEvent("P030_CHOICE"', source)
        self.assertIn('SendNetworkEvent("P030_RETRY")', source)
        self.assertIn('SendNetworkEvent("P030_RETURN")', source)

        # EventManager aggregates UI ownership across every globally registered
        # handler. Disabled earlier-phase handlers must release it before their
        # early return on MAP16 or they suppress P030's native input globally.
        self.assertIn('"DSP028LevelUpRuntime", "DSP029RunController", "DSP030VerticalSlice"', registrations)
        p028_loaded = p028[p028.index("override void WorldLoaded(WorldEvent e)") :]
        p029_loaded = p029[p029.index("override void WorldLoaded(WorldEvent e)") :]
        self.assertLess(p028_loaded.index("IsUiProcessor = false;"), p028_loaded.index("if (!enabled)"))
        self.assertLess(p029_loaded.index("IsUiProcessor = false;"), p029_loaded.index("if (!enabled)"))
        p029_register = p029[p029.index("override void OnRegister()") : p029.index("void ReadConfiguration()")]
        self.assertIn("IsUiProcessor = false;", p029_register)
        self.assertNotIn("IsUiProcessor = true;", p029_register)

        # New map-only handlers share the global responder. A stale UI claim
        # from MAP23 or MAP24 also suppresses MAP16 native movement and look.
        for handler, name in ((p037, "DSP037Map23Runtime"), (p038, "DSP038Map24Runtime")):
            self.assertIn(f'"{name}"', registrations)
            registered = handler[handler.index("override void OnRegister()") : handler.index("int ReadCameraVariant()")]
            self.assertIn("IsUiProcessor = false;", registered)
            loaded = handler[handler.index("override void WorldLoaded(WorldEvent e)") :]
            self.assertLess(loaded.index("IsUiProcessor = false;"), loaded.index("if (level == null || level.MapName != MAP)"))
            self.assertIn("IsUiProcessor = true;", loaded)

    def test_marker_only_fails_closed(self):
        result = validate("DS_BOOT map=MAP16 DS_P030_COMPLETE tics=10500 state=RESULTS")
        self.assertEqual(result["status"], "FAIL")
        self.assertTrue(result["errors"])

    def test_actual_packaged_transaction_stream_reconciles(self):
        log = accepted_log()
        if log is None:
            self.skipTest("run tools/run_p030_vertical_slice.py to supply accepted packaged evidence")
        result = validate(log, accelerated=True)
        self.assertEqual(result["status"], "PASS", result["errors"])
        self.assertEqual(result["spawn_count"], 248)
        self.assertEqual(result["death_count"], 240)
        self.assertEqual(result["xp_collect_count"], 222)
        self.assertGreaterEqual(result["levelup_count"], 3)

    def test_declared_negative_mutations_all_fail_closed(self):
        log = accepted_log()
        if log is None:
            self.skipTest("run tools/run_p030_vertical_slice.py to supply accepted packaged evidence")
        outcomes = validate_negative_mutations(log)
        self.assertEqual(set(outcomes.values()), {"FAIL"}, outcomes)

    def test_arithmetic_and_schedule_mutations_fail(self):
        log = accepted_log()
        if log is None:
            self.skipTest("run tools/run_p030_vertical_slice.py to supply accepted packaged evidence")
        mutations = {
            "results_damage": log.replace("damage=720000", "damage=719999", 1),
            "results_xp": log.replace("collected_xp=222000", "collected_xp=221000", 1),
            "first_deadline": log.replace("DS_P030_SPAWN event_id=1 tic=70", "DS_P030_SPAWN event_id=1 tic=71", 1),
            "duplicate_spawn_identity": log.replace("stable_id=4 live=2", "stable_id=3 live=2", 1),
            "wrong_pickup_value": log.replace("value=1000 source=BAT3_DEATH", "value=999 source=BAT3_DEATH", 1),
            "whip_proxy_overflow": log.replace("peak_whip_proxies=2", "peak_whip_proxies=3", 1),
        }
        for name, mutation in mutations.items():
            with self.subTest(name=name):
                result = validate(mutation, accelerated=True)
                self.assertEqual(result["status"], "FAIL", (name, result["errors"]))


if __name__ == "__main__":
    unittest.main()
