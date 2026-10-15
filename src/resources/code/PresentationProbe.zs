// P012-W02 diagnostic presentation fixtures only. These are generated
// placeholders used to exercise camera depth, solid-body relation, and a
// foot-level pickup marker in the calibration room. They are not source-game
// assets or source-game geometry claims.
class DSCloseBillboard : Actor
{
    Default
    {
        Radius 8;
        Height 64;
        +NOBLOCKMAP
        +NOGRAVITY
        +NOINTERACTION
    }
    States
    {
    Spawn:
        BILL A -1 Bright;
        Stop;
    }

    override void PostBeginPlay()
    {
        Super.PostBeginPlay();
        Console.Printf("DS_FP_FIXTURE actor=close_billboard pos=(%.3f,%.3f,%.3f) radius=%.3f height=%.3f", Pos.X, Pos.Y, Pos.Z, Radius, Height);
    }
}

class DSSolidProp : Actor
{
    Default
    {
        Radius 24;
        Height 96;
        +SOLID
        +NOGRAVITY
    }
    States
    {
    Spawn:
        PROP A -1 Bright;
        Stop;
    }

    override void PostBeginPlay()
    {
        Super.PostBeginPlay();
        Console.Printf("DS_FP_FIXTURE actor=solid_prop pos=(%.3f,%.3f,%.3f) radius=%.3f height=%.3f", Pos.X, Pos.Y, Pos.Z, Radius, Height);
    }
}

class DSFootPickup : Actor
{
    Default
    {
        Radius 8;
        Height 8;
        +NOBLOCKMAP
        +NOGRAVITY
        +NOINTERACTION
        RenderStyle "Add";
    }
    States
    {
    Spawn:
        PICK A -1 Bright;
        Stop;
    }

    override void PostBeginPlay()
    {
        Super.PostBeginPlay();
        Console.Printf("DS_FP_FIXTURE actor=foot_pickup pos=(%.3f,%.3f,%.3f) radius=%.3f height=%.3f", Pos.X, Pos.Y, Pos.Z, Radius, Height);
    }
}
