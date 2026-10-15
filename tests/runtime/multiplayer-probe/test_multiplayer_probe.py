import unittest

from tools.run_multiplayer_probe import validate


def capability(client: int, active: int = 2, shared: int = 3, delta: float = 12.0) -> str:
    return (
        f"DS_P017_WORLD map=MAP01 client={client}\n"
        f"DS_P017_CAPABILITY client={client} active_players={active} shared_population={shared} "
        f"own_x=0.000 own_y=0.000 own_yaw={delta:.3f} yaw_delta={delta:.3f} "
        "cmd_yaw=0 cmd_pitch=0 cmd_forward=0 cmd_side=0\n"
        f"DS_P017_VIEW client={client} player=0 x=0.000 y=0.000 yaw=0.000\n"
        f"DS_P017_VIEW client={client} player=1 x=0.000 y=64.000 yaw=90.000\n"
        f"DS_P017_PROBE_COMPLETE client={client}\n"
    )


def single_log() -> str:
    return (
        capability(0, active=1, shared=3, delta=0.0)
        + "DS_P017_MENU_PAUSE_SAMPLE tic=12 menu=0 freeze=0\n"
        + "DS_P017_MENU_PAUSE_SAMPLE tic=36 menu=1 freeze=0\n"
        + "DS_P017_MENU_PAUSE_RESULT before=0 after=1 changed=1\n"
    )


class MultiplayerProbeValidatorTests(unittest.TestCase):
    def test_complete_probe_passes_but_split_view_stays_unproven(self):
        result = validate(single_log(), capability(0), capability(1))
        self.assertEqual(result["status"], "PASS", result["errors"])
        self.assertEqual(result["capabilities"]["network_two_client_processes"], "DEMONSTRATED_TWO_CLIENTS")
        self.assertEqual(result["capabilities"]["network_shared_population"], "DEMONSTRATED_SINGLE_SHARED_FIXTURE")
        self.assertEqual(result["capabilities"]["network_independent_process_views"], "DEMONSTRATED_PROCESS_VIEWS_ONLY")
        self.assertEqual(result["capabilities"]["local_split_view"], "UNTESTED_NO_SPLIT_FRAMEBUFFER_EVIDENCE")

    def test_missing_network_logs_fail_closed(self):
        result = validate(single_log(), "", "")
        self.assertEqual(result["status"], "FAIL")
        self.assertEqual(result["capabilities"]["network_two_client_processes"], "UNSUPPORTED_OR_UNAVAILABLE")

    def test_shared_population_mismatch_fails(self):
        result = validate(single_log(), capability(0, shared=4), capability(1, shared=3))
        self.assertEqual(result["status"], "FAIL")
        self.assertEqual(result["capabilities"]["network_shared_population"], "FAILED_SHARED_POPULATION_INVARIANT")

    def test_same_client_id_does_not_prove_independent_views(self):
        result = validate(single_log(), capability(0), capability(0))
        self.assertEqual(result["status"], "PASS", result["errors"])
        self.assertEqual(result["capabilities"]["network_independent_process_views"], "UNTESTED")

    def test_menu_without_state_change_remains_untested(self):
        log = single_log().replace("before=0 after=1 changed=1", "before=0 after=0 changed=0")
        result = validate(log, capability(0), capability(1))
        self.assertEqual(result["status"], "PASS", result["errors"])
        self.assertEqual(result["capabilities"]["menu_pause_routing"], "UNTESTED_MENU_COMMAND_DID_NOT_CHANGE_STATE")


if __name__ == "__main__":
    unittest.main()
