// P017 bounded multiplayer capability probe. These actors and measurements
// are diagnostic fixtures; they are not source-game multiplayer content.
class DSP017SharedEntity : Actor
{
    Default { Radius 8; Height 8; +NOBLOCKMAP; +NOGRAVITY; +NOINTERACTION; }
    States { Spawn: TNT1 A -1; Stop; }
}

class DSP017MultiplayerProbe : EventHandler
{
    bool enabled;
    bool reported;
    int observedTics;
    double initialYaw;
    int menuBefore;
    int menuAfter;

    int ActivePlayers()
    {
        int count = 0;
        for (int i = 0; i < MAXPLAYERS; i++)
            if (playeringame[i]) count++;
        return count;
    }

    int SharedPopulation()
    {
        int count = 0;
        ThinkerIterator it = ThinkerIterator.Create("DSP017SharedEntity");
        Actor actor;
        while ((actor = Actor(it.Next())) != null) count++;
        return count;
    }

    override void WorldLoaded(WorldEvent e)
    {
        enabled = level.MapName == "MAP01";
        reported = false;
        observedTics = 0;
        menuBefore = -1;
        menuAfter = -1;
        if (!enabled) return;
        // UZDoom runs this deterministic simulation on each network peer. Each
        // peer creates the same three logical fixtures; a local consoleplayer
        // branch would diverge the worlds and is deliberately forbidden.
        Actor.Spawn("DSP017SharedEntity", (-96.0, 0.0, 0.0), NO_REPLACE);
        Actor.Spawn("DSP017SharedEntity", (0.0, 96.0, 0.0), NO_REPLACE);
        Actor.Spawn("DSP017SharedEntity", (96.0, 0.0, 0.0), NO_REPLACE);
        Console.Printf("DS_P017_WORLD map=%s client=%d", level.MapName, consoleplayer);
    }

    override void WorldTick()
    {
        if (!enabled || reported) return;
        observedTics++;
        if (players[consoleplayer].mo == null) return;
        if (observedTics == 12)
        {
            menuBefore = MenuActive;
            Console.Printf("DS_P017_MENU_PAUSE_SAMPLE tic=%d menu=%d freeze=%d", observedTics, MenuActive, players[consoleplayer].mo.IsFrozen());
        }
        if (observedTics == 36)
        {
            menuAfter = MenuActive;
            Console.Printf("DS_P017_MENU_PAUSE_SAMPLE tic=%d menu=%d freeze=%d", observedTics, MenuActive, players[consoleplayer].mo.IsFrozen());
        }
        if (observedTics == 8)
        {
            // A deterministic diagnostic offset gives player 2 a distinct
            // eye-level state on both peers without claiming physical input.
            if (playeringame[1] && players[1].mo != null)
            {
                players[1].mo.SetOrigin((-200.0, 64.0, 0.0), true);
                players[1].mo.Angle = 90.0;
            }
            initialYaw = players[consoleplayer].mo.Angle;
        }
        if (observedTics == 50)
        {
            int active = ActivePlayers();
            int shared = SharedPopulation();
            double delta = players[consoleplayer].mo.Angle - initialYaw;
            Console.Printf("DS_P017_CAPABILITY client=%d active_players=%d shared_population=%d own_x=%.3f own_y=%.3f own_yaw=%.3f yaw_delta=%.3f cmd_yaw=%d cmd_pitch=%d cmd_forward=%d cmd_side=%d", consoleplayer, active, shared, players[consoleplayer].mo.Pos.X, players[consoleplayer].mo.Pos.Y, players[consoleplayer].mo.Angle, delta, players[consoleplayer].cmd.yaw, players[consoleplayer].cmd.pitch, players[consoleplayer].cmd.forwardmove, players[consoleplayer].cmd.sidemove);
            for (int i = 0; i < MAXPLAYERS; i++)
            {
                if (!playeringame[i] || players[i].mo == null) continue;
                Console.Printf("DS_P017_VIEW client=%d player=%d x=%.3f y=%.3f yaw=%.3f", consoleplayer, i, players[i].mo.Pos.X, players[i].mo.Pos.Y, players[i].mo.Angle);
            }
            Console.Printf("DS_P017_MENU_PAUSE_RESULT before=%d after=%d changed=%d", menuBefore, menuAfter, menuBefore != menuAfter);
            reported = true;
            Console.Printf("DS_P017_PROBE_COMPLETE client=%d", consoleplayer);
        }
    }
}
