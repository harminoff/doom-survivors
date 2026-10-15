import unittest

from tools.run_camera_probe import validate
from tools.run_probe import png_nonblank
from tools.build import png


GOOD_LOG = """
DS_FP_FIXTURE actor=close_billboard pos=(0.000,0.000,0.000) radius=8.000 height=64.000
DS_FP_FIXTURE actor=solid_prop pos=(-64.000,-72.000,0.000) radius=24.000 height=96.000
DS_FP_FIXTURE actor=foot_pickup pos=(-128.000,20.000,0.000) radius=8.000 height=8.000
DS_FP_ADAPTER_CONTRACT player_cmd=verified source_window=logical_xy eye_body=separate fov=player_info
DS_FP_ADAPTER_STATE tic=4 body=(-200.000,0.000,0.000) eye_z=41.000 view_height=41.000 yaw=0.000 pitch=0.000 desired_fov=90.000 fov=90.000 cmd_yaw=0 cmd_pitch=0 cmd_forward=0 cmd_side=0 logical_count=4
DS_FP_CAMERA case=0 yaw=0.000 pitch=0.000 fov=90.000 x=-200.000 y=0.000 logical_count=4
DS_FP_CAMERA case=1 yaw=90.000 pitch=0.000 fov=90.000 x=-200.000 y=0.000 logical_count=4
DS_FP_CAMERA case=2 yaw=180.000 pitch=0.000 fov=90.000 x=-200.000 y=0.000 logical_count=4
DS_FP_CAMERA case=3 yaw=270.000 pitch=0.000 fov=90.000 x=-200.000 y=0.000 logical_count=4
DS_FP_CAMERA case=4 yaw=0.000 pitch=45.000 fov=70.000 x=-200.000 y=0.000 logical_count=4
DS_FP_CAMERA case=5 yaw=0.000 pitch=-45.000 fov=120.000 x=-200.000 y=0.000 logical_count=4
DS_FP_ADAPTER_COMPLETE body_stable=true logical_stable=true
DS_FP_CAMERA_COMPLETE cases=6 logical_count=4 fixtures=3
DS_FP_INTERACTIVE_BASELINE yaw=0.000 pitch=0.000 fov=90.000 body=(-200.000,0.000,0.000)
"""


class CameraProbeParserTests(unittest.TestCase):
    def test_accepts_complete_invariant_matrix(self):
        self.assertEqual(validate(GOOD_LOG)["status"], "PASS")

    def test_rejects_changed_logic_or_missing_case(self):
        changed = GOOD_LOG.replace("logical_count=4", "logical_count=3", 1)
        self.assertEqual(validate(changed)["status"], "FAIL")
        self.assertEqual(validate("\n".join(GOOD_LOG.splitlines()[:-2]))["status"], "FAIL")

    def test_rejects_changed_camera_or_body(self):
        wrong_yaw = GOOD_LOG.replace("case=1 yaw=90.000", "case=1 yaw=89.000")
        moved = GOOD_LOG.replace("case=5 yaw=0.000 pitch=-45.000 fov=120.000 x=-200.000", "case=5 yaw=0.000 pitch=-45.000 fov=120.000 x=-199.000")
        self.assertEqual(validate(wrong_yaw)["status"], "FAIL")
        self.assertEqual(validate(moved)["status"], "FAIL")

    def test_rejects_missing_adapter_contract(self):
        missing = GOOD_LOG.replace("DS_FP_ADAPTER_COMPLETE body_stable=true logical_stable=true\n", "")
        self.assertEqual(validate(missing)["status"], "FAIL")

    def test_rejects_missing_interactive_baseline(self):
        missing = GOOD_LOG.replace("DS_FP_INTERACTIVE_BASELINE yaw=0.000 pitch=0.000 fov=90.000 body=(-200.000,0.000,0.000)\n", "")
        self.assertEqual(validate(missing)["status"], "FAIL")

    def test_rejects_missing_presentation_fixture_marker(self):
        missing = GOOD_LOG.replace("DS_FP_FIXTURE actor=foot_pickup pos=(-128.000,20.000,0.000) radius=8.000 height=8.000\n", "")
        self.assertEqual(validate(missing)["status"], "FAIL")

    def test_framebuffer_blank_check_rejects_solid_image(self):
        blank = png(4, 4, lambda _x, _y: (10, 20, 30))
        varied = png(4, 4, lambda x, y: (10 + x, 20 + y, 30))
        self.assertFalse(png_nonblank(blank))
        self.assertTrue(png_nonblank(varied))


if __name__ == "__main__":
    unittest.main()
