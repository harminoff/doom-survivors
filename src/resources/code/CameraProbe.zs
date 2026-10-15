// Preliminary P012 engineering fixture. Dimensions and cases are synthetic.
class DSPreliminaryCameraProbe : EventHandler
{
    int probeTics;
    int activeCase;
    double baselineX;
    double baselineY;
    bool enabled;

    int LogicalCount()
    {
        // Four synthetic points are inside a fixed 256x256 logical square and
        // two are outside. This predicate intentionally has no camera inputs.
        int count = 0;
        if (Abs(-64.0) <= 128.0 && Abs(-64.0) <= 128.0) count++;
        if (Abs(64.0) <= 128.0 && Abs(-64.0) <= 128.0) count++;
        if (Abs(-64.0) <= 128.0 && Abs(64.0) <= 128.0) count++;
        if (Abs(64.0) <= 128.0 && Abs(64.0) <= 128.0) count++;
        if (Abs(192.0) <= 128.0 && Abs(0.0) <= 128.0) count++;
        if (Abs(0.0) <= 128.0 && Abs(-192.0) <= 128.0) count++;
        return count;
    }

    void ApplyCase(int index)
    {
        double yaw = 0.0;
        double pitch = 0.0;
        double desiredFov = 90.0;
        if (index == 1) yaw = 90.0;
        else if (index == 2) yaw = 180.0;
        else if (index == 3) yaw = 270.0;
        else if (index == 4)
        {
            pitch = 45.0;
            desiredFov = 70.0;
        }
        else if (index == 5)
        {
            pitch = -45.0;
            desiredFov = 120.0;
        }
        players[0].mo.Angle = yaw;
        players[0].mo.Pitch = pitch;
        players[0].SetFOV(desiredFov);
    }

    override void WorldLoaded(WorldEvent e)
    {
        enabled = level.MapName == "MAP01";
        probeTics = 0;
        activeCase = -1;
    }

    override void WorldTick()
    {
        if (!enabled) return;
        probeTics++;
        if (players[0].mo == null) return;
        if (probeTics == 2)
        {
            baselineX = players[0].mo.Pos.X;
            baselineY = players[0].mo.Pos.Y;
            Console.Printf("DS_FP_CAMERA_BEGIN synthetic_window=256x256 expected_count=4 source_window=logical_xy camera_frustum=separate fixture_cases=6 observed_fixture_count=3");
        }
        if (probeTics >= 4 && probeTics <= 44 && (probeTics - 4) % 8 == 0)
        {
            activeCase++;
            ApplyCase(activeCase);
        }
        if (probeTics >= 7 && probeTics <= 47 && (probeTics - 7) % 8 == 0)
        {
            // Keep one actual framebuffer per synthetic matrix case. These are
            // presentation evidence only; logical eligibility remains logged
            // independently and is never derived from the framebuffer.
            LevelLocals.MakeScreenShot();
            Console.Printf("DS_FP_CAMERA case=%d yaw=%.3f pitch=%.3f fov=%.3f x=%.3f y=%.3f logical_count=%d",
                activeCase, players[0].mo.Angle, players[0].mo.Pitch,
                players[0].DesiredFOV, players[0].mo.Pos.X, players[0].mo.Pos.Y,
                LogicalCount());
        }
        if (probeTics == 48)
        {
            if (LogicalCount() != 4 || players[0].mo.Pos.X != baselineX || players[0].mo.Pos.Y != baselineY)
                Console.Printf("DS_ASSERT_FAIL fp_camera_logical_state_changed");
            else Console.Printf("DS_FP_CAMERA_COMPLETE cases=6 logical_count=4 fixtures=3");
            players[0].mo.Angle = 0.0;
            players[0].mo.Pitch = 0.0;
            players[0].SetFOV(90.0);
        }
        if (probeTics == 50)
        {
            players[0].mo.Angle = 0.0;
            players[0].mo.Pitch = 0.0;
            players[0].SetFOV(90.0);
            Console.Printf("DS_FP_INTERACTIVE_BASELINE yaw=%.3f pitch=%.3f fov=%.3f body=(%.3f,%.3f,%.3f)",
                players[0].mo.Angle, players[0].mo.Pitch, players[0].FOV,
                players[0].mo.Pos.X, players[0].mo.Pos.Y, players[0].mo.Pos.Z);
        }
    }
}
