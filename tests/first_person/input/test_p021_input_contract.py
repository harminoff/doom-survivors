import unittest
from pathlib import Path

from tools.run_p021_movement import input_owned, movement_vector


class P021InputContractTests(unittest.TestCase):
    ROOT = Path(__file__).resolve().parents[3]

    def test_native_command_and_pause_ownership_are_explicit(self):
        player = (self.ROOT / "src/zscript/gameplay/player/FirstPersonPlayer.zs").read_text(encoding="utf-8")
        adapter = (self.ROOT / "src/zscript/core/InputAdapter.zs").read_text(encoding="utf-8")
        self.assertIn("UserCmd cmd = player.cmd", player)
        self.assertIn("override void MovePlayer()", player)
        self.assertIn("TryMove(Pos.XY + displacement, true)", player)
        self.assertIn("menuactive == Menu.Off && paused == 0", player)
        self.assertIn("override bool InputProcess(InputEvent e)", adapter)
        self.assertIn("InputEvent.Type_DeviceChange", adapter)
        self.assertIn("ClearNativeActionInput", adapter)
        self.assertIn("players[0].cmd.forwardmove = 0", adapter)
        self.assertIn("players[0].cmd.yaw = 0", adapter)
        self.assertIn("paused == 0", adapter)

    def test_menu_and_pause_own_input(self):
        self.assertTrue(input_owned(False, False))
        self.assertFalse(input_owned(True, False))
        self.assertFalse(input_owned(False, True))

    def test_stationary_look_does_not_create_movement(self):
        dx, dy, magnitude, _ = movement_vector(73.0, 0.0, 0.0)
        self.assertEqual((dx, dy, magnitude), (0.0, 0.0, 0.0))

    def test_rapid_turn_changes_view_basis_without_reversing_attack(self):
        _, _, _, direction = movement_vector(270.0, -1.0, 0.0)
        self.assertAlmostEqual(direction, 90.0)
        # The adapter samples attack basis from view yaw, so backward travel
        # cannot replace it with the movement direction.
        self.assertNotAlmostEqual(direction, 270.0)


if __name__ == "__main__":
    unittest.main()
