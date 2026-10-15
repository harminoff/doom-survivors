// Engineering fixtures only. None of these values are Vampire Survivors data.
class DSDiagnosticPlayer : PlayerPawn
{
    Default
    {
        Radius 16;
        Height 56;
        Speed 1;
        Player.DisplayName "Diagnostic observer";
        Player.ViewHeight 41;
        Player.ForwardMove 0.5, 0.5;
        Player.SideMove 0.5, 0.5;
        Player.ColorRange 0, 0;
    }
    States
    {
    Spawn:
        TNT1 A -1;
        Stop;
    }
}

class DSDiagnosticStatusBar : BaseStatusBar
{
    override void Init()
    {
        Super.Init();
        SetSize(0, 320, 200);
    }

    override void Draw(int state, double TicFrac)
    {
        Super.Draw(state, TicFrac);
        if (state == HUD_Fullscreen)
        {
            BeginHUD();
            DrawImage("P13ICON", (8, 8), DI_SCREEN_LEFT_TOP, 1.0, (32, 32));
        }
    }
}

class DSBootProbe : EventHandler
{
    int observedTics;
    bool reported;
    ui int renderedFrames;

    override void RenderOverlay(RenderEvent e)
    {
        renderedFrames++;
        // P003's bootstrap screenshot belongs to MAP01.  Other phases own
        // their framebuffer capture so unrelated live proxies cannot pollute
        // their visual evidence.
        if (level.MapName == "MAP01" && renderedFrames == 300)
        {
            LevelLocals.MakeScreenShot();
        }
    }

    override void WorldLoaded(WorldEvent e)
    {
        observedTics = 0;
        reported = false;
        Console.Printf("DS_BOOT map=%s", level.MapName);
    }

    override void WorldTick()
    {
        observedTics++;
        if (observedTics == 70 && !reported)
        {
            reported = true;
            if (players[0].mo == null)
            {
                Console.Printf("DS_ASSERT_FAIL missing_player");
            }
            else
            {
                Console.Printf("DS_RUNTIME_COMPLETE tics=%d pos=(%.3f,%.3f,%.3f) yaw=%.3f pitch=%.3f", observedTics,
                    players[0].mo.Pos.X, players[0].mo.Pos.Y, players[0].mo.Pos.Z,
                    players[0].mo.Angle, players[0].mo.Pitch);
            }
        }
        if (observedTics % 35 == 0 && players[0].mo != null)
        {
            Console.Printf("DS_POSE tics=%d x=%.3f y=%.3f yaw=%.3f pitch=%.3f", observedTics,
                players[0].mo.Pos.X, players[0].mo.Pos.Y, players[0].mo.Angle, players[0].mo.Pitch);
        }
    }
}
