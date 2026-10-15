// The Depths (MAP53) has floors at different heights, while gameplay places
// every sprite at a height above a flat z = 0 (visual Z is an adapter
// concern). Proxies there are lifted by the ground under them each tic; a z
// that differs from the last lifted one is a fresh height from gameplay.
// Pickups also pass a bob, so they read as collectable on every stage.
mixin class DSGroundFollow
{
    double dsRawZ;
    double dsLiftedZ;

    void DSFollowGround(double bob = 0.0)
    {
        bool depths = level.levelnum == 53;
        if (!depths && bob == 0.0) return;
        double raw = pos.z != dsLiftedZ ? pos.z : dsRawZ;
        double z = raw + bob + (depths ? level.PointInSector(pos.xy).floorplane.ZatPoint(pos.xy) : 0.0);
        dsRawZ = raw;
        dsLiftedZ = z;
        if (z != pos.z) SetZ(z);
    }
}

// Pickups bob gently and sit on a soft glow ring, so loot never reads as
// scenery (presentation only). Mixed into the pickup proxies.
mixin class DSPickupGlow
{
    DSWeaponFx dsGlowRing;

    void DSPickupTick(double ringSize, Color tint)
    {
        double phase = (pos.x * 7.0 + pos.y * 13.0) % 360.0;
        DSFollowGround(3.0 + 3.0 * sin(level.maptime * 8.0 + phase));
        if (dsGlowRing == null)
            dsGlowRing = DSWeaponFx.Make("WRNG", pos.x, pos.y, 1.0, ringSize, ringSize, true, tint, 0.45, 0);
        else if (dsGlowRing.pos.x != pos.x || dsGlowRing.pos.y != pos.y)
            dsGlowRing.SetOrigin((pos.x, pos.y, dsGlowRing.pos.z), true);
        if (dsGlowRing != null) dsGlowRing.bInvisible = bInvisible;
    }

    void DSPickupGone()
    {
        if (dsGlowRing != null) dsGlowRing.Destroy();
        dsGlowRing = null;
    }
}

// P020 presentation boundary. Proxies mirror logical state and never own
// damage, collision, target selection, or gameplay lifetime.
class DSP020PresentationProxy : Actor
{
    int logicalSlot;
    int logicalGeneration;

    Default
    {
        +NOBLOCKMAP
        +NOGRAVITY
        +NOINTERACTION
        RenderStyle "Translucent";
        Alpha 0.65;
        Radius 4;
        Height 8;
    }
}

// Weapon projectile proxies.  Presentation only: projectiles are drawn below
// eye level and stay hidden until they are clear of the camera, so shots do
// not appear to leave the player's eyes.  Logical paths are unaffected.
class DSProjectileProxyBase : Actor
{
    mixin DSGroundFollow;
    const VISUAL_Z = 20.0;
    const HIDE_RADIUS = 40.0;

    // Weapon art (gameplay/presentation/WeaponArt.zs); presentation only.
    int logicalSystemId;
    int artState;
    int artSprite;
    double artSpin;

    void ArtSetup()
    {
        String name = DSWeaponArt.Sprite(logicalSystemId);
        if (name == "") { artState = 2; return; }
        artState = 1;
        artSprite = Actor.GetSpriteIndex(name);
        artSpin = DSWeaponArt.Spin(logicalSystemId);
        bRollSprite = true;
        A_SetRenderStyle(1.0, STYLE_Normal);
        A_SetScale(DSWeaponArt.Scale(logicalSystemId));
    }

    override void Tick()
    {
        Super.Tick();
        DSFollowGround();
        Actor viewer = players[consoleplayer].mo;
        DSP021FirstPersonPlayer pawn = DSP021FirstPersonPlayer(viewer);
        bInvisible = viewer != null && !(pawn != null && pawn.thirdPerson) && Distance2D(viewer) < HIDE_RADIUS;
        if (artState == 0 && logicalSystemId > 0) ArtSetup();
        if (artState == 1)
        {
            sprite = artSprite;
            if (artSpin != 0.0) A_SetRoll(Roll + artSpin, SPF_INTERPOLATE);
        }
    }
}
