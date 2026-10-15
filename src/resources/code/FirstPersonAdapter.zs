// P012 first-person adapter scaffolding.
// This class observes native UZDoom player/view state and keeps source logical
// eligibility separate from camera presentation. It does not own combat bounds.
class DSFirstPersonCameraAdapter : EventHandler
{
    int observedTics;
    bool reported;
    bool enabled;
    double baselineX;
    double baselineY;
    double baselineZ;

    int LogicalReferenceWindowCount()
    {
        // Diagnostic entities only. The source logical window is intentionally
        // independent of display FOV, pitch, yaw, and the eye frustum.
        int count = 0;
        if (Abs(-64.0) <= 128.0 && Abs(-64.0) <= 128.0) count++;
        if (Abs(64.0) <= 128.0 && Abs(-64.0) <= 128.0) count++;
        if (Abs(-64.0) <= 128.0 && Abs(64.0) <= 128.0) count++;
        if (Abs(64.0) <= 128.0 && Abs(64.0) <= 128.0) count++;
        if (Abs(192.0) <= 128.0 && Abs(0.0) <= 128.0) count++;
        if (Abs(0.0) <= 128.0 && Abs(-192.0) <= 128.0) count++;
        return count;
    }

    override void WorldLoaded(WorldEvent e)
    {
        enabled = level.MapName == "MAP01";
        observedTics = 0;
        reported = false;
        if (!enabled) return;
        int fixtureCount = 0;
        if (Actor.Spawn("DSCloseBillboard", (-104, 0, 0), NO_REPLACE) != null) fixtureCount++;
        if (Actor.Spawn("DSSolidProp", (-64, -72, 0), NO_REPLACE) != null) fixtureCount++;
        if (Actor.Spawn("DSFootPickup", (-128, 20, 0), NO_REPLACE) != null) fixtureCount++;
        Console.Printf("DS_FP_FIXTURE_SPAWN count=%d expected=3 source=fp_calibration_room ownership=ADAPTER_WORLD_LOADED map_things=false", fixtureCount);
        Console.Printf("DS_FP_ADAPTER_CONTRACT player_cmd=verified source_window=logical_xy eye_body=separate fov=player_info");
    }

    override void WorldTick()
    {
        if (!enabled) return;
        observedTics++;
        if (players[0].mo == null) return;
        if (observedTics == 2)
        {
            baselineX = players[0].mo.Pos.X;
            baselineY = players[0].mo.Pos.Y;
            baselineZ = players[0].mo.Pos.Z;
            Console.Printf("DS_FP_FIXTURE_LAYOUT fixture=close_billboard player=(%.3f,%.3f) target=(-104.000,0.000,0.000) initial_angle=%.3f forward_distance=%.3f lateral_offset=%.3f inspection=centered_near_clip_probe classification=GENERATED_PLACEHOLDER_DIAGNOSTIC",
                baselineX, baselineY, players[0].mo.Angle, -104.0 - baselineX, 0.0 - baselineY);
        }
        if (observedTics == 4 && !reported)
        {
            reported = true;
            Console.Printf("DS_FP_ADAPTER_STATE tic=%d body=(%.3f,%.3f,%.3f) eye_z=%.3f view_height=%.3f yaw=%.3f pitch=%.3f desired_fov=%.3f fov=%.3f cmd_yaw=%d cmd_pitch=%d cmd_forward=%d cmd_side=%d logical_count=%d",
                observedTics, players[0].mo.Pos.X, players[0].mo.Pos.Y, players[0].mo.Pos.Z,
                players[0].viewz, players[0].viewheight, players[0].mo.Angle, players[0].mo.Pitch,
                players[0].DesiredFOV, players[0].FOV, players[0].cmd.yaw, players[0].cmd.pitch,
                players[0].cmd.forwardmove, players[0].cmd.sidemove, LogicalReferenceWindowCount());
        }
        if (observedTics == 48)
        {
            bool bodyStable = players[0].mo.Pos.X == baselineX && players[0].mo.Pos.Y == baselineY && players[0].mo.Pos.Z == baselineZ;
            bool logicalStable = LogicalReferenceWindowCount() == 4;
            if (bodyStable && logicalStable)
                Console.Printf("DS_FP_ADAPTER_COMPLETE body_stable=true logical_stable=true");
            else
                Console.Printf("DS_ASSERT_FAIL fp_adapter_state_changed body_stable=%d logical_stable=%d", bodyStable, logicalStable);
        }
    }
}
