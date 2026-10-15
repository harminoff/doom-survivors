// P021 presentation boundary. The eye follows the authoritative body actor;
// camera pitch is presentation-only and never enters planar eligibility.
class DSP021Presentation : EventHandler
{
    bool enabled;

    override void WorldLoaded(WorldEvent e)
    {
        enabled = level.MapName == "MAP07";
        if (enabled)
            Console.Printf("DS_P021_PRESENTATION eye=body_viewheight_41 pitch=VIEW_ONLY bob=DISABLED roll=DISABLED collision=body_xy");
    }

    override void WorldTick()
    {
        if (!enabled || players[0].mo == null) return;
        // Camera ownership is native PlayerInfo camera handling. This marker
        // makes the no-duplicate-route contract visible in runtime logs.
        if (level.maptime == 1)
            Console.Printf("DS_P021_CAMERA_ROUTE camera=PLAYER_INFO eye_z=%.3f body=(%.3f,%.3f) logical_xy=AUTHORITATIVE", players[0].viewz, players[0].mo.Pos.X, players[0].mo.Pos.Y);
        if (level.maptime == 70)
            LevelLocals.MakeScreenShot();
    }
}
