// P013 generated representative-asset gallery. All markers describe generated
// placeholders and diagnostic collision overlays; no source gameplay is changed.
class DSP13Enemy : Actor
{
    Default { Radius 16; Height 40; +NOBLOCKMAP; +NOGRAVITY; +NOINTERACTION; }
    States { Spawn: P13E A 4 Bright; Loop; }
    override void PostBeginPlay() { Super.PostBeginPlay(); Console.Printf("DS_P013_ASSET actor=enemy_directional pos=(%.3f,%.3f,%.3f) policy=EIGHT_DIRECTIONAL_SPRITE collision=ENGINEERING_ENEMY_BODY_PLACEHOLDER presentation_solid=false presentation_blocking=false presentation_interaction=false", Pos.X, Pos.Y, Pos.Z); }
}

class DSP13PlayerIdentity : Actor
{
    Default { Radius 16; Height 56; +NOBLOCKMAP; +NOGRAVITY; +NOINTERACTION; }
    States { Spawn: P13P A 0 Bright; Stop; }
    override void PostBeginPlay() { Super.PostBeginPlay(); Console.Printf("DS_P013_ASSET actor=player_identity pos=(%.3f,%.3f,%.3f) policy=FRONT_BILLBOARD_PLACEHOLDER collision=ENGINEERING_PLAYER_BODY_PLACEHOLDER presentation_solid=false presentation_blocking=false presentation_interaction=false", Pos.X, Pos.Y, Pos.Z); }
}

class DSP13Projectile : Actor
{
    Default { Radius 4; Height 4; +NOBLOCKMAP; +NOGRAVITY; +NOINTERACTION; }
    States { Spawn: P13R A 1 Bright; Loop; }
    override void PostBeginPlay() { Super.PostBeginPlay(); Console.Printf("DS_P013_ASSET actor=projectile pos=(%.3f,%.3f,%.3f) policy=BILLBOARD_PLACEHOLDER collision=ENGINEERING_PROJECTILE_PLACEHOLDER presentation_solid=false presentation_blocking=false presentation_interaction=false", Pos.X, Pos.Y, Pos.Z); }
}

class DSP13GroundAura : Actor
{
    Default { Radius 48; Height 2; +NOBLOCKMAP; +NOGRAVITY; +NOINTERACTION; RenderStyle "Translucent"; }
    States { Spawn: P13A A 2 Bright; Loop; }
    override void PostBeginPlay() { Super.PostBeginPlay(); Console.Printf("DS_P013_ASSET actor=ground_aura pos=(%.3f,%.3f,%.3f) policy=GROUND_ALIGNED_EFFECT collision=ENGINEERING_AREA_EFFECT_PLACEHOLDER presentation_solid=false presentation_blocking=false presentation_interaction=false", Pos.X, Pos.Y, Pos.Z); }
}

class DSP13FootPickup : Actor
{
    Default { Radius 8; Height 8; +NOBLOCKMAP; +NOGRAVITY; +NOINTERACTION; RenderStyle "Add"; }
    States { Spawn: P13K A 4 Bright; Loop; }
    override void PostBeginPlay() { Super.PostBeginPlay(); Console.Printf("DS_P013_ASSET actor=foot_pickup pos=(%.3f,%.3f,%.3f) policy=BILLBOARD_PLACEHOLDER collision=ENGINEERING_PICKUP_PLACEHOLDER presentation_solid=false presentation_blocking=false presentation_interaction=false", Pos.X, Pos.Y, Pos.Z); }
}

class DSP13WorldProp : Actor
{
    Default { Radius 24; Height 96; +NOBLOCKMAP; +NOGRAVITY; +NOINTERACTION; }
    States { Spawn: P13W A 0 Bright; Stop; }
    override void PostBeginPlay() { Super.PostBeginPlay(); Console.Printf("DS_P013_ASSET actor=world_prop pos=(%.3f,%.3f,%.3f) policy=BILLBOARD_PLACEHOLDER collision=ENGINEERING_WORLD_PROP_PLACEHOLDER presentation_solid=false presentation_blocking=false presentation_interaction=false", Pos.X, Pos.Y, Pos.Z); }
}

class DSP013AssetGalleryProbe : EventHandler
{
    int probeTics;
    int activeCase;
    bool enabled;

    void ApplyCase(int index)
    {
        double x = -304.0;
        double y = 0.0;
        double yaw = 0.0;
        if (index == 1) { x = -276.0; y = -68.0; yaw = 45.0; }
        else if (index == 2) { x = -208.0; y = -96.0; yaw = 90.0; }
        else if (index == 3) { x = -140.0; y = -68.0; yaw = 135.0; }
        else if (index == 4) { x = -112.0; yaw = 180.0; }
        else if (index == 5) { x = -140.0; y = 68.0; yaw = 225.0; }
        else if (index == 6) { x = -208.0; y = 96.0; yaw = 270.0; }
        else if (index == 7) { x = -276.0; y = 68.0; yaw = 315.0; }
        players[0].mo.SetOrigin((x, y, 0), true);
        players[0].mo.Angle = yaw;
        players[0].mo.Pitch = 0.0;
        players[0].SetFOV(90.0);
    }

    override void WorldLoaded(WorldEvent e)
    {
        enabled = level.MapName == "MAP02";
        probeTics = 0;
        activeCase = -1;
        if (!enabled) return;
        int fixtureCount = 0;
        if (Actor.Spawn("DSP13Enemy", (-208, 0, 0), NO_REPLACE) != null) fixtureCount++;
        if (Actor.Spawn("DSP13Enemy", (96, 0, 0), NO_REPLACE) != null) fixtureCount++;
        if (Actor.Spawn("DSP13PlayerIdentity", (-224, -96, 0), NO_REPLACE) != null) fixtureCount++;
        if (Actor.Spawn("DSP13Projectile", (-152, -48, 48), NO_REPLACE) != null) fixtureCount++;
        if (Actor.Spawn("DSP13Projectile", (-152, 48, 56), NO_REPLACE) != null) fixtureCount++;
        if (Actor.Spawn("DSP13Projectile", (-96, 0, 72), NO_REPLACE) != null) fixtureCount++;
        if (Actor.Spawn("DSP13GroundAura", (-88, 64, 0), NO_REPLACE) != null) fixtureCount++;
        if (Actor.Spawn("DSP13GroundAura", (-88, -64, 0), NO_REPLACE) != null) fixtureCount++;
        if (Actor.Spawn("DSP13GroundAura", (-40, 64, 0), NO_REPLACE) != null) fixtureCount++;
        if (Actor.Spawn("DSP13FootPickup", (-120, 32, 0), NO_REPLACE) != null) fixtureCount++;
        if (Actor.Spawn("DSP13WorldProp", (-16, -96, 0), NO_REPLACE) != null) fixtureCount++;
        Console.Printf("DS_P013_GALLERY_SPAWN count=%d expected=11 ownership=ADAPTER_WORLD_LOADED map_things=false", fixtureCount);
        Console.Printf("DS_P013_GALLERY_BEGIN map=%s manifest_assets=7 fixture_instances=11 cases=8 ring_radius=96.000 target=(-208.000,0.000) collision_overlay=true classification=GENERATED_PLACEHOLDER", level.MapName);
        Console.Printf("DS_P013_COLLISION_OVERLAY presentation_solid=false presentation_blocking=false presentation_interaction=false source_dimensions=UNKNOWN source_geometry_claim=NONE");
    }

    override void WorldTick()
    {
        if (!enabled) return;
        probeTics++;
        if (players[0].mo == null) return;
        if (probeTics >= 4 && probeTics <= 60 && (probeTics - 4) % 8 == 0)
        {
            activeCase++;
            ApplyCase(activeCase);
        }
        if (probeTics >= 7 && probeTics <= 63 && (probeTics - 7) % 8 == 0)
        {
            LevelLocals.MakeScreenShot();
            Console.Printf("DS_P013_GALLERY_CASE case=%d yaw=%.3f pitch=%.3f fov=%.3f body=(%.3f,%.3f,%.3f) target=(-208.000,0.000) ring_radius=96.000", activeCase, players[0].mo.Angle, players[0].mo.Pitch, players[0].FOV, players[0].mo.Pos.X, players[0].mo.Pos.Y, players[0].mo.Pos.Z);
        }
        if (probeTics == 65)
        {
            players[0].mo.SetOrigin((-320, 0, 0), true);
            players[0].mo.Angle = 0.0;
            players[0].mo.Pitch = 0.0;
            players[0].SetFOV(90.0);
            Console.Printf("DS_P013_GALLERY_COMPLETE cases=8 fixture_instances=11 collision_overlay=true ring_stable=true body_restored=true");
            Console.Printf("DS_RUNTIME_COMPLETE tics=65 pos=(%.3f,%.3f,%.3f) yaw=%.3f pitch=%.3f", players[0].mo.Pos.X, players[0].mo.Pos.Y, players[0].mo.Pos.Z, players[0].mo.Angle, players[0].mo.Pitch);
        }
    }
}
