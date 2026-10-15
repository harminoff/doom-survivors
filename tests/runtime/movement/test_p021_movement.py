import unittest

from tools.run_p021_movement import movement_vector, normalize_axes, validate


GOOD_LOG = """DS_P021_BOOT map=MAP07 ticrate=35 input=UserCmd movement=logical_xy collision=single_body_route
DS_P021_SPEED source_speed=UNAVAILABLE modifier=1.000 logical_speed=3.000 status=ENGINEERING_APPROXIMATION
DS_P021_DISABLED jump=1 crouch=1 sprint=1 weapon_switch=1 native_attack_movement=1 mandatory_bob_roll=1 controller=UNTESTED_NO_COMPATIBLE_DEVICE
DS_P021_PRESENTATION eye=body_viewheight_41 pitch=VIEW_ONLY bob=DISABLED roll=DISABLED collision=body_xy
DS_P021_CAMERA_ROUTE camera=PLAYER_INFO eye_z=41.000 body=(0.000,0.000) logical_xy=AUTHORITATIVE
DS_P021_STATE tic=1 owned=1 menu=0 paused=0 x=0.000 y=0.000 view_yaw=0.000 pitch=0.000 forward=0.00000 side=0.00000 magnitude=0.00000 movement_direction=0.000 source_facing_basis=0.000 attack_basis=0.000 speed_changed_by_look=0 native_movement=0
DS_P021_STATE tic=10 owned=1 menu=0 paused=0 x=3.000 y=0.000 view_yaw=0.000 pitch=0.000 forward=1.00000 side=0.00000 magnitude=1.00000 movement_direction=0.000 source_facing_basis=0.000 attack_basis=0.000 speed_changed_by_look=0 native_movement=0
DS_P021_STATE tic=20 owned=1 menu=0 paused=0 x=3.000 y=0.000 view_yaw=180.000 pitch=5.000 forward=-1.00000 side=0.00000 magnitude=1.00000 movement_direction=0.000 source_facing_basis=180.000 attack_basis=180.000 speed_changed_by_look=0 native_movement=0
DS_P021_STATE tic=30 owned=1 menu=0 paused=0 x=3.000 y=0.000 view_yaw=180.000 pitch=5.000 forward=0.50000 side=0.50000 magnitude=0.70711 movement_direction=135.000 source_facing_basis=180.000 attack_basis=180.000 speed_changed_by_look=0 native_movement=0
DS_P021_STATE tic=40 owned=1 menu=0 paused=0 x=3.000 y=0.000 view_yaw=180.000 pitch=5.000 forward=0.50000 side=0.50000 magnitude=0.70711 movement_direction=135.000 source_facing_basis=180.000 attack_basis=180.000 speed_changed_by_look=0 native_movement=0
DS_P021_STATE tic=50 owned=1 menu=0 paused=0 x=3.000 y=0.000 view_yaw=180.000 pitch=5.000 forward=0.00000 side=0.00000 magnitude=0.00000 movement_direction=180.000 source_facing_basis=180.000 attack_basis=180.000 speed_changed_by_look=0 native_movement=0
DS_P021_STATE tic=60 owned=0 menu=1 paused=0 x=3.000 y=0.000 view_yaw=180.000 pitch=5.000 forward=0.00000 side=0.00000 magnitude=0.00000 movement_direction=180.000 source_facing_basis=180.000 attack_basis=180.000 speed_changed_by_look=0 native_movement=0
DS_P021_UI_PAUSE ui_ticks=200 world_paused=1 ownership=UI
DS_P021_UI_RESUME ui_ticks=235 world_paused=0 ownership=PLAY_REACQUIRED
DS_P021_STATE tic=70 owned=1 menu=0 paused=0 x=3.000 y=0.000 view_yaw=180.000 pitch=5.000 forward=0.00000 side=0.00000 magnitude=0.00000 movement_direction=180.000 source_facing_basis=180.000 attack_basis=180.000 speed_changed_by_look=0 native_movement=0
DS_P021_COMPLETE tics=70 menu_owned_tics=1 paused_tics=0 suppressed_tics=1 device_changes=INPUTPROCESS_MARKER_ONLY logical_xy=(3.000,0.000) movement_route=ONE_AUTHORITATIVE_BODY_COLLISION source_speed=ENGINEERING_APPROXIMATION view_facing_attack=SEPARATE controller=UNTESTED"""


class P021RuntimeParserTests(unittest.TestCase):
    def test_complete_marker_set_passes(self):
        result = validate(GOOD_LOG)
        self.assertEqual(result["status"], "PASS", result["errors"])
        self.assertEqual(result["physical_input_proof"], "ESTABLISHED_MOUSE_KEYBOARD")
        self.assertEqual(result["controller_analog_proof"], "UNTESTED_NO_COMPATIBLE_DEVICE")

    def test_zero_input_baseline_is_not_physical_proof(self):
        baseline = "\n".join(
            line.replace("forward=1.00000", "forward=0.00000")
            .replace("forward=-1.00000", "forward=0.00000")
            .replace("forward=0.50000", "forward=0.00000")
            .replace("side=0.50000", "side=0.00000")
            .replace("magnitude=1.00000", "magnitude=0.00000")
            .replace("magnitude=0.70711", "magnitude=0.00000")
            for line in GOOD_LOG.splitlines()
        )
        result = validate(baseline)
        self.assertEqual(result["status"], "PASS", result["errors"])
        self.assertNotEqual(result["physical_input_proof"], "ESTABLISHED")
        self.assertEqual(validate(baseline, require_physical=True)["status"], "FAIL")

    def test_assertion_or_missing_marker_fails_closed(self):
        self.assertEqual(validate(GOOD_LOG.replace("DS_P021_COMPLETE", "DS_ASSERT_FAIL")).get("status"), "FAIL")
        self.assertEqual(validate(GOOD_LOG.replace("speed_changed_by_look=0", "speed_changed_by_look=1", 1)).get("status"), "FAIL")
        self.assertEqual(validate("\n".join(GOOD_LOG.splitlines()[:-1])).get("status"), "FAIL")

    def test_diagonal_and_partial_axes_are_normalized_once(self):
        f, s, magnitude = normalize_axes(1.0, 1.0)
        self.assertAlmostEqual(magnitude, 1.0)
        self.assertAlmostEqual((f * f + s * s) ** 0.5, 1.0)
        _, _, half_magnitude, _ = movement_vector(0.0, 0.5, 0.0)
        self.assertAlmostEqual(half_magnitude, 0.5)

    def test_backpedal_keeps_view_facing_basis(self):
        dx, dy, magnitude, direction = movement_vector(0.0, -1.0, 0.0)
        self.assertAlmostEqual(dx, -1.0)
        self.assertAlmostEqual(dy, 0.0, places=6)
        self.assertAlmostEqual(magnitude, 1.0)
        self.assertAlmostEqual(direction, 180.0)


if __name__ == "__main__":
    unittest.main()
