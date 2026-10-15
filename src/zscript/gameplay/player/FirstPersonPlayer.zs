// P021 first-person player. Native command yaw/pitch are retained for the
// view, while planar movement is resolved once against the actor body. This
// prevents Doom's native thrust, bob, roll, jump, crouch and weapon paths from
// becoming a second source of gameplay state.
class DSP021FirstPersonPlayer : PlayerPawn
{
    double lastForwardInput;
    double lastSideInput;
    double lastMovementMagnitude;
    double lastMovementDirection;
    double sourceFacingBasis;
    double sampledAttackBasis;

    // Full-input speed in map units per tic. Playtest-tuned (approximation):
    // 0.6 and then 1.2 both felt too slow; the user confirmed 3.0
    // (2026-09-29). Override with the ds_move_units_milli cvar (3000 = 3.0).
    const MOVE_UNITS_PER_TIC = 3.0;
    const WALK_COMMAND = 6400.0;
    // Move Speed stat from the run (VerticalSlice RecomputeRunStats); 0 = x1.
    double moveScale;
    // Carlo Cart: the stage scrolls the player along +X every tic. Set by
    // the slice each world tick (0 whenever the run is not active).
    double autoScrollX;
    // Third-person view (ds_camera 1): the engine chase camera follows the
    // pawn and this sprite shows. Presentation only.
    bool thirdPerson;
    bool dying;   // the run ended in defeat: play the fall and stay down

    void StartDying()
    {
        if (dying) return;
        dying = true;
        SetStateLabel("Death");
    }

    // A retry restarts the run on the same map: stand back up.
    void StopDying()
    {
        if (!dying) return;
        dying = false;
        SetState(SpawnState);
    }

    Default
    {
        Radius 16;
        Height 56;
        Speed 1;
        Player.DisplayName "First-person survivor";
        Player.ViewHeight 41;
        Player.ViewBob 0;
        Player.ForwardMove 0.5, 0.5;
        Player.SideMove 0.5, 0.5;
        Player.ColorRange 0, 0;
        +NOGRAVITY;
        Scale 0.9;
        RenderStyle "Normal";
    }

    States
    {
    Spawn:
        PSVR A -1;
        Stop;
    See:
        PSVR B 5;
        PSVR A 5;
        PSVR C 5;
        PSVR A 5;
        Loop;
    Front:
        // Walking backwards (third person): the survivor faces the camera.
        PSVF B 5;
        PSVF A 5;
        PSVF C 5;
        PSVF A 5;
        Loop;
    Side:
        // Strafing (third person): a profile view; the code mirrors it for left.
        PSVS B 5;
        PSVS A 5;
        PSVS C 5;
        PSVS A 5;
        Loop;
    FrontIdle:
        PSVF A -1;
        Stop;
    Missile:
    Melee:
    Pain:
        PSVR A -1;
        Stop;
    Death:
        // Tips over backwards and stays down (shown when the run ends).
        PSVD A 5;
        PSVD B 5;
        PSVD C 5;
        PSVD D -1;
        Stop;
    }

    void ApplyCamera()
    {
        CVar cam = CVar.FindCVar("ds_camera");
        bool want = cam != null && cam.GetInt() != 0;
        if (want)
        {
            player.cheats |= CF_CHASECAM;
            if (!thirdPerson)
            {
                // chase_dist / chase_height are engine cvars that only menu code
                // or the launch command line can set (see the launcher). Start at
                // the default tilt; the mouse then adjusts it (the launcher also
                // sets lookspring 0 so the engine does not recentre it).
                CVar startTilt = CVar.FindCVar("ds_camera_pitch");
                Pitch = clamp(startTilt != null ? startTilt.GetFloat() : 26.0, 6.0, 56.0);
            }
        }
        else
        {
            player.cheats &= ~CF_CHASECAM;
            if (thirdPerson) Pitch = 0.0;
        }
        thirdPerson = want;
        // Mouse tilt: the player may look between nearly level and straight
        // down on the survivor; the camera never goes below the horizon.
        if (want) Pitch = clamp(Pitch, 6.0, 56.0);
    }

    override bool CanCrouch()
    {
        return false;
    }

    override void CheckCrouch(bool totallyfrozen)
    {
        // Source has no crouch path in this phase.
        if (player != null) player.crouching = 0;
    }

    override void CheckJump()
    {
        // Source has no jump path in this phase.
    }

    override void CheckMoveUpDown()
    {
        // Source has no fly/jump/upward movement path in this phase.
    }

    override void MovePlayer()
    {
        if (player == null)
        {
            lastForwardInput = 0.0;
            lastSideInput = 0.0;
            lastMovementMagnitude = 0.0;
            lastMovementDirection = Angle;
            sourceFacingBasis = Angle;
            sampledAttackBasis = Angle;
            return;
        }

        ApplyCamera();
        UserCmd cmd = player.cmd;
        bool owned = menuactive == Menu.Off && paused == 0;
        // Keyboard walk (6400) and run (12800) both give full speed; analog
        // input below the walk value stays proportional.
        double forward = owned ? clamp(cmd.forwardmove / WALK_COMMAND, -1.0, 1.0) : 0.0;
        double side = owned ? clamp(cmd.sidemove / WALK_COMMAND, -1.0, 1.0) : 0.0;

        // Yaw is view state. Movement uses it as a basis, but never changes it
        // based on the movement direction, so backward travel keeps a forward
        // facing attack basis.
        if (owned) Angle += cmd.yaw * (360.0 / 65536.0);
        Pitch = clamp(Pitch, -32.0, 56.0);
        sourceFacingBasis = Angle;
        sampledAttackBasis = Angle;

        double magnitude = sqrt(forward * forward + side * side);
        if (magnitude > 1.0)
        {
            forward /= magnitude;
            side /= magnitude;
            magnitude = 1.0;
        }
        lastForwardInput = forward;
        lastSideInput = side;
        lastMovementMagnitude = magnitude;
        lastMovementDirection = Angle;
        if (dying) { Vel = (0.0, 0.0, 0.0); return; }
        // Third person: walking backwards shows the front of the survivor.
        State frontState = FindState("Front");
        State sideState = FindState("Side");
        bool backwards = thirdPerson && forward < -0.25 && frontState != null;
        bool sideways = thirdPerson && !backwards && abs(side) > 0.4 && abs(forward) < 0.4 && sideState != null;
        if (sideways)
        {
            if (!InStateSequence(CurState, sideState)) SetState(sideState);
            // Positive side moves right (see the movement basis below).
            A_SetScale(side > 0 ? abs(Scale.X) : -abs(Scale.X), Scale.Y);
        }
        else if (backwards)
        {
            if (Scale.X < 0) A_SetScale(abs(Scale.X), Scale.Y);
            if (!InStateSequence(CurState, frontState)) SetState(frontState);
        }
        else if (magnitude > 0.00001 && !InStateSequence(CurState, SeeState))
        {
            if (Scale.X < 0) A_SetScale(abs(Scale.X), Scale.Y);
            SetState(SeeState);
        }
        else if (magnitude <= 0.00001 && !InStateSequence(CurState, SpawnState))
        {
            if (Scale.X < 0) A_SetScale(abs(Scale.X), Scale.Y);
            SetState(SpawnState);
        }
        if (magnitude > 0.00001)
        {
            Vector2 forwardVector = AngleToVector(Angle, forward);
            Vector2 sideVector = AngleToVector(Angle - 90.0, side);
            CVar tuned = CVar.FindCVar("ds_move_units_milli");
            double unitsPerTic = tuned != null && tuned.GetInt() > 0
                ? tuned.GetInt() / 1000.0 : MOVE_UNITS_PER_TIC;
            Vector2 displacement = (forwardVector + sideVector) * unitsPerTic
                * (moveScale > 0.0 ? moveScale : 1.0);
            lastMovementDirection = displacement.Angle();
            TryMove(Pos.XY + displacement, true);
        }
        if (autoScrollX != 0.0 && owned) TryMove(Pos.XY + (autoScrollX, 0.0), true);
        // The Depths has stairs and spike pits. The body has no gravity, so
        // it follows the floor down here (TryMove already steps it up).
        if (level.levelnum == 53 && Pos.Z > floorz) SetZ(floorz);
        // The logical route is position-only for this planar phase. Clearing
        // velocity also disables native momentum and mandatory bob/roll.
        Vel = (0.0, 0.0, 0.0);
    }
}
