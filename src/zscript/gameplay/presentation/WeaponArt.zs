// Weapon projectile sprites (tools/art/weapon_art.py). Presentation only:
// picks a sprite, scale and spin per weapon system and never touches combat.
class DSWeaponArt
{
    // Coloured sprite per system, or "" to keep the old blob.
    static String Sprite(int s)
    {
        switch (s)
        {
        case 34: return "WWND"; case 35: return "WHWN";
        case 36: return "WKNF"; case 37: return "WEDG";
        case 38: return "WAXE"; case 39: return "WSCY";
        case 40: return "WFIR"; case 41: return "WHFR";
        case 42: return "WCRS"; case 43: return "WSWD";
        case 54: return "WRUN"; case 55: return "WNOF";
        case 56: return "WBON"; case 57: return "WCHR"; case 58: return "WCAR";
        case 59: return "WBRD"; case 60: return "WBRK"; case 61: return "WBRW";
        case 62: case 63: case 64: return "WBUL";
        case 65: case 66: return "WSLS";
        case 67: case 68: case 69: return "WORB";
        case 116: case 117: return "WORB"; // Magi-Stone, Kyra-Stones
        case 78: return "WMNA"; case 79: return "WMNJ";   // Song of Mana, Mannajja
        case 86: return "WDST"; case 87: return "WPRF";   // Celestial Dusting, Profusione D'Amore
        case 88: return "WROB";                            // La Robba
        case 123: return "WBON"; case 124: return "WCHR"; case 125: return "WCAR";   // Anima, Yatta, Carrozza!
        }
        return "";
    }

    // Sprite scale (art is 32 px; 0.4 is about 13 map units).
    static double Scale(int s)
    {
        switch (s)
        {
        case 36: case 37: return 0.35;
        case 38: case 42: case 43: return 0.5;
        case 39: case 41: return 0.6;
        case 65: case 66: return 0.9;
        case 78: case 79: return 1.0;
        case 125: return 0.55;
        case 62: case 63: case 64: return 0.3;
        }
        return 0.4;
    }

    // Degrees of sprite roll per tic (axe, scythe, cross, bone...).
    static double Spin(int s)
    {
        switch (s)
        {
        case 38: case 39: case 42: return 24.0;
        case 56: case 58: case 123: case 125: return 18.0;
        case 86: case 87: return 12.0;
        case 54: case 55: return 10.0;
        }
        return 0.0;
    }

    // Tinted white shapes for the generic engine, by behaviour mode.
    static String GenericShape(int mode, int system)
    {
        if (system == DSN3Rows.SYSTEM_PAKO_BATTILIAR || system == DSN3Rows.SYSTEM_MAZO_FAMILIAR) return "WFAM";
        if (system == DSN3Rows.SYSTEM_LAUREL || system == DSN3Rows.SYSTEM_CRIMSON_SHROUD) return "WLRL";
        if (system == DSN3Rows.SYSTEM_CLOCK_LANCET || system == DSN3Rows.SYSTEM_INFINITE_CORRIDOR) return "WCLK";
        if (system == DSN3Rows.SYSTEM_SHADOW_PINION || system == DSN3Rows.SYSTEM_VALKYRIE_TURNER) return "WWNG";
        switch (mode)
        {
        case DSGenericWeaponDefs.MODE_PROJECTILE:
            if (system == DSN3Rows.SYSTEM_AMMO_APPALATE || system == DSN3Rows.SYSTEM_GUNASTROPHE
                || system == DSN3Rows.SYSTEM_GLASS_FANDANGO) return "WBUL";
            return "WJAV";
        case DSGenericWeaponDefs.MODE_FAN: return "WFLM";
        case DSGenericWeaponDefs.MODE_STRIKE: case DSGenericWeaponDefs.MODE_ON_CRIT: return "WBLT";
        case DSGenericWeaponDefs.MODE_RAIN: return "WFLM";
        case DSGenericWeaponDefs.MODE_COMPANION: return "WCAT";
        case DSGenericWeaponDefs.MODE_BEAM: return system == DSN3Rows.SYSTEM_MANNAJJA ? "WMNJ" : "WMNA";
        }
        return "WRNG";
    }
}

// Never spawned: its states register the weapon sprite names.
class DSWeaponArtRegistry : Actor
{
    States
    {
    Spawn:
        WWND A 1; WHWN A 1; WKNF A 1; WEDG A 1; WAXE A 1; WSCY A 1; WFIR A 1; WHFR A 1;
        WCRS A 1; WSWD A 1; WRUN A 1; WNOF A 1; WBON A 1; WCHR A 1; WCAR A 1; WBRD A 1;
        WBRK A 1; WBRW A 1; WORB A 1; WRNG A 1; WBLT A 1; WFLM A 1; WJAV A 1; WBUL A 1;
        WSLS A 1; WWHP A 1; WBIB A 1; WVES A 1; WCAT A 1; WFAM A 1; WLRL A 1; WCLK A 1; WWNG A 1;
        WDST A 1; WPRF A 1; WROB A 1; WMNA A 1; WMNJ A 1;
        Stop;
    }
}

// Timed or persistent weapon effect (rings, bolts, zones). Presentation only.
class DSWeaponFx : Actor
{
    mixin DSGroundFollow;
    int age;
    int maxAge;       // 0 = persistent
    double size0;
    double size1;
    double alpha0;

    Default
    {
        Radius 1;
        Height 1;
        +NOBLOCKMAP;
        +NOGRAVITY;
        +NOINTERACTION;
    }

    States
    {
    Spawn:
        WORB A -1 Bright;
        Stop;
    }

    static DSWeaponFx Make(String spr, double px, double py, double z, double s0, double s1,
        bool flat, Color tint, double a0, int life)
    {
        DSWeaponFx f = DSWeaponFx(Actor.Spawn("DSWeaponFx", (px, py, z), NO_REPLACE));
        if (f == null) return null;
        f.sprite = Actor.GetSpriteIndex(spr);
        f.bFlatSprite = flat;
        f.size0 = s0; f.size1 = s1; f.alpha0 = a0; f.maxAge = life;
        // Color(r, g, b) has alpha 0 in ZScript, so only an all-zero colour means "untinted".
        if (tint.a == 0 && tint.r == 0 && tint.g == 0 && tint.b == 0) f.A_SetRenderStyle(1.0, STYLE_Normal);
        else { f.A_SetRenderStyle(a0, STYLE_AddStencil); f.SetShade(tint); }
        f.A_SetScale(s0 / 32.0);
        return f;
    }

    // Weapon effects at (px, py); size is the sprite's diameter in map units.
    static void Burst(String spr, double px, double py, double z, double s0, double s1,
        bool flat, Color tint, int life)
    {
        DSWeaponFx.Make(spr, px, py, z, s0, s1, flat, tint, 0.9, life);
    }

    override void Tick()
    {
        Super.Tick();
        DSFollowGround();
        if (maxAge <= 0) return;
        age++;
        if (age >= maxAge) { Destroy(); return; }
        double f = double(age) / maxAge;
        A_SetScale((size0 + (size1 - size0) * f) / 32.0);
        A_SetRenderStyle(alpha0 * (1.0 - f), STYLE_AddStencil);
    }
}
