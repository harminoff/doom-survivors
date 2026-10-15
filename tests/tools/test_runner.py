import unittest

from pathlib import Path

from tools.run_probe import classify, config_text, input_proof_text


class ProbeClassificationTests(unittest.TestCase):
    def test_interactive_input_proof_keeps_menu_binding_isolated(self):
        bindings = input_proof_text()
        self.assertIn('bind escape "menu_main"', bindings)
        self.assertIn('bind mouse2 "menu_main"', bindings)
        self.assertEqual(bindings.count('bind escape '), 1)
        self.assertEqual(bindings.count('bind mouse2 '), 1)

    def test_focus_profile_can_disable_background_simulation(self):
        config = config_text(Path("."), active_in_background=False)
        self.assertIn("vid_activeinbackground=false", config)
        self.assertIn("vid_lowerinbackground=false", config)

    def test_default_profile_keeps_running_without_focus(self):
        # A focus-loss pause freezes scripted runs until their deadline.
        config = config_text(Path("."))
        self.assertIn("vid_activeinbackground=true", config)
        self.assertIn("i_pauseinbackground=false", config)

    def test_compile_only_requires_1337(self):
        self.assertEqual(classify("", 1337, False, True), "COMPILE_PASS")
        self.assertEqual(classify("", 0, False, True), "COMPILE_FAILURE")
        self.assertEqual(classify("", 1337, True, True), "TIMEOUT")

    def test_boot_marker_alone_cannot_pass_runtime(self):
        self.assertEqual(classify("DS_BOOT map=MAP01", 0, False, False), "INCOMPLETE")

    def test_success_markers_pass_runtime(self):
        log = "DS_BOOT map=MAP01\nDS_RUNTIME_COMPLETE tics=70"
        self.assertEqual(classify(log, 0, False, False), "RUNTIME_PASS")

    def test_assertion_overrides_success(self):
        log = "DS_BOOT map=MAP01 DS_RUNTIME_COMPLETE tics=70 DS_ASSERT_FAIL"
        self.assertEqual(classify(log, 0, False, False), "ASSERTION_FAILURE")

    def test_crash_overrides_success(self):
        log = "DS_BOOT map=MAP01 DS_RUNTIME_COMPLETE tics=70"
        self.assertEqual(classify(log, 5, False, False), "PROCESS_FAILURE")

    def test_runtime_timeout_and_script_error(self):
        self.assertEqual(classify("", None, True, False), "TIMEOUT")
        self.assertEqual(classify("Script error in DSProbe", 0, False, False), "COMPILE_FAILURE")
        self.assertEqual(classify("Unknown identifier 'Thing'", 0, False, False), "COMPILE_FAILURE")

    def test_resource_fatal_is_startup_failure(self):
        self.assertEqual(classify("Fatal error: Could not find MAP01", 0, False, False), "STARTUP_FAILURE")
        self.assertEqual(classify("No player start", 0, False, False), "STARTUP_FAILURE")
        self.assertEqual(classify("No map MAP01", None, False, False), "STARTUP_FAILURE")


if __name__ == "__main__":
    unittest.main()
