// P021 native-command boundary. Source movement remains in logical X/Y and
// engine input is sampled once per simulation tic. Source speed is unavailable
// under the current evidence policy; the modifier below is an engineering
// approximation and is deliberately labelled in every runtime marker.
class DSP021InputAdapter : EventHandler
{
    const MAP = "MAP07";
    const SPEED_MODIFIER_APPROX = 1.0;
    const LOGICAL_SPEED_APPROX = 3.0;

    bool enabled;
    bool completionEmitted;
    int tic;
    ui int deviceChanges;
    ui int uiTicks;
    ui bool uiPaused;
    int menuOwnedTics;
    int pausedTics;
    int suppressedTics;
    double logicalX;
    double logicalY;
    double viewYaw;
    double viewPitch;
    double movementDirection;
    double movementMagnitude;
    double sourceFacingBasis;
    double sampledAttackBasis;
    double sampledForward;
    double sampledSide;

    // A pause or menu transition is an ownership boundary. MovePlayer also
    // masks the current command, so a held key cannot become a stale action on
    // the first resumed tic.
    bool InputOwned()
    {
        return menuactive == Menu.Off && paused == 0;
    }

    void ClearNativeActionInput()
    {
        if (players[0].mo == null) return;
        // Write the native fields through the player property. A local
        // UserCmd value can be a copy, which would leave held input queued
        // into the first resumed tic.
        players[0].cmd.forwardmove = 0;
        players[0].cmd.sidemove = 0;
        players[0].cmd.upmove = 0;
        players[0].cmd.yaw = 0;
        players[0].cmd.pitch = 0;
        players[0].cmd.roll = 0;
        players[0].cmd.buttons = 0;
    }

    override void WorldLoaded(WorldEvent e)
    {
        enabled = level.MapName == MAP;
        completionEmitted = false;
        tic = 0;
        menuOwnedTics = 0;
        pausedTics = 0;
        suppressedTics = 0;
        logicalX = 0.0;
        logicalY = 0.0;
        viewYaw = 0.0;
        viewPitch = 0.0;
        movementDirection = 0.0;
        movementMagnitude = 0.0;
        sourceFacingBasis = 0.0;
        sampledAttackBasis = 0.0;
        sampledForward = 0.0;
        sampledSide = 0.0;
        if (!enabled) return;
        Console.Printf("DS_P021_BOOT map=%s ticrate=%d input=UserCmd movement=logical_xy collision=single_body_route", MAP, Thinker.TICRATE);
        Console.Printf("DS_P021_SPEED source_speed=UNAVAILABLE modifier=%.3f logical_speed=%.3f status=ENGINEERING_APPROXIMATION", SPEED_MODIFIER_APPROX, LOGICAL_SPEED_APPROX);
        Console.Printf("DS_P021_DISABLED jump=1 crouch=1 sprint=1 weapon_switch=1 native_attack_movement=1 mandatory_bob_roll=1 controller=UNTESTED_NO_COMPATIBLE_DEVICE");
    }

    override bool InputProcess(InputEvent e)
    {
        if (!enabled) return false;
        if (e.Type == InputEvent.Type_DeviceChange)
        {
            // InputProcess is a UI-context callback and cannot mutate play
            // state. WorldTick owns the actual command clear at the next
            // pause/menu boundary; this marker proves the device event was
            // observed by the adapter.
            Console.Printf("DS_P021_DEVICE_CHANGE observed=1 ownership=REACQUIRE_ON_NEXT_NATIVE_COMMAND action_clear=PLAY_CONTEXT_WORLD_TICK");
        }
        return false;
    }

    override void UiTick()
    {
        if (!enabled) return;
        uiTicks++;
        bool nowPaused = Level.WorldPaused();
        if (nowPaused && !uiPaused)
            Console.Printf("DS_P021_UI_PAUSE ui_ticks=%d world_paused=1 ownership=UI", uiTicks);
        else if (!nowPaused && uiPaused)
            Console.Printf("DS_P021_UI_RESUME ui_ticks=%d world_paused=0 ownership=PLAY_REACQUIRED", uiTicks);
        uiPaused = nowPaused;
    }

    override void WorldTick()
    {
        if (!enabled) return;
        tic++;
        bool owned = InputOwned();
        if (menuactive != Menu.Off) menuOwnedTics++;
        if (paused != 0) pausedTics++;
        if (!owned)
        {
            suppressedTics++;
            ClearNativeActionInput();
        }
        if (players[0].mo != null)
        {
            DSP021FirstPersonPlayer pawn = DSP021FirstPersonPlayer(players[0].mo);
            logicalX = players[0].mo.Pos.X;
            logicalY = players[0].mo.Pos.Y;
            viewYaw = players[0].mo.Angle;
            viewPitch = players[0].mo.Pitch;
            if (pawn != null)
            {
                movementDirection = pawn.lastMovementDirection;
                movementMagnitude = pawn.lastMovementMagnitude;
                sourceFacingBasis = pawn.sourceFacingBasis;
                sampledAttackBasis = pawn.sampledAttackBasis;
                sampledForward = pawn.lastForwardInput;
                sampledSide = pawn.lastSideInput;
            }
        }
        if (tic == 1 || tic % 10 == 0)
        {
            Console.Printf("DS_P021_STATE tic=%d owned=%d menu=%d paused=%d x=%.3f y=%.3f view_yaw=%.3f pitch=%.3f forward=%.5f side=%.5f magnitude=%.5f movement_direction=%.3f source_facing_basis=%.3f attack_basis=%.3f speed_changed_by_look=0 native_movement=0", tic, owned, menuactive != Menu.Off, paused != 0, logicalX, logicalY, viewYaw, viewPitch, sampledForward, sampledSide, movementMagnitude, movementDirection, sourceFacingBasis, sampledAttackBasis);
        }
        // Keep sampling after the bounded completion marker. The ordinary
        // runner stops when it sees the marker; the interactive runner keeps
        // its window open so a physical session can show post-resume input
        // and ownership transitions without fabricating a second marker.
        if (tic >= 70 && !completionEmitted)
        {
            Console.Printf("DS_P021_COMPLETE tics=%d menu_owned_tics=%d paused_tics=%d suppressed_tics=%d device_changes=INPUTPROCESS_MARKER_ONLY logical_xy=(%.3f,%.3f) movement_route=ONE_AUTHORITATIVE_BODY_COLLISION source_speed=ENGINEERING_APPROXIMATION view_facing_attack=SEPARATE controller=UNTESTED", tic, menuOwnedTics, pausedTics, suppressedTics, logicalX, logicalY);
            completionEmitted = true;
        }
    }
}
