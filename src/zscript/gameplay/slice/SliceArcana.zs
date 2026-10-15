// Arcana for DSP030VerticalSlice (TODO step 6). Wiki approximations from
// data/arcana/arcanas.json (retrieved 2026-09-29).
//
// A run picks one Arcana at the start, and the Arcana-holder bosses (11:00
// and 21:00 on 30-minute stages) drop an Arcana chest while the player has
// fewer than 3. Each pick offers 4 random unowned Arcanas, as the original
// does; Reroll and Skip charges work on the pick. Only Arcanas whose
// effects are built are offered.

class DSArcana
{
    const OFFER_BASE = 200000;
    const MAX_OWNED = 3;

    const GEMINI = 1;
    const TWILIGHT_REQUIEM = 2;
    const IRON_BLUE_WILL = 7;
    const DIVINE_BLOODLINE = 9;
    const WALTZ_OF_PEARLS = 11;
    const OUT_OF_BOUNDS = 12;
    const GAME_KILLER = 22;
    const TRAGIC_PRINCESS = 3;
    const AWAKE = 4;
    const CHAOS_DARK_NIGHT = 5;
    const SARABANDE = 6;
    const MAD_GROOVE = 8;
    const BEGINNING = 10;
    const JAIL_OF_CRYSTAL = 14;
    const SLASH = 16;
    const HEART_OF_FIRE = 19;
    const BLOOD_ASTRONOMIA = 21;
    const WICKED_SEASON = 13;
    const DISCO_OF_GOLD = 15;
    const LOST_FOUND_PAINTING = 17;
    const BOOGALOO = 18;
    const SILENT_SANCTUARY = 20;

    // Built Arcanas, in numeral order.
    static const int BUILT[] = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22 };

    static const String NUMERALS[] = {
        "", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI",
        "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX", "XXI", "0"
    };
    static const String NAMES[] = {
        "", "Gemini", "Twilight Requiem", "Tragic Princess", "Awake",
        "Chaos in the Dark Night", "Sarabande of Healing", "Iron Blue Will",
        "Mad Groove", "Divine Bloodline", "Beginning", "Waltz of Pearls",
        "Out of Bounds", "Wicked Season", "Jail of Crystal", "Disco of Gold",
        "Slash", "Lost & Found Painting", "Boogaloo of Illusions",
        "Heart of Fire", "Silent Old Sanctuary", "Blood Astronomia", "Game Killer"
    };

    // Each scoped Arcana's listed weapons (catalog ids), from the wiki's
    // Arcana pages; passives in those lists are left out.
    static const int LIST_GEMINI[] = { 59, 60, 61, 62, 63, 64, 76, 77, 96, 97, 112, 113 };
    static const int LIST_REQUIEM[] = { 44, 45, 50, 51, 54, 56, 59, 60, 68, 69, 80, 86, 112, 113 };
    static const int LIST_TRAGIC[] = { 46, 47, 48, 49, 50, 51, 58, 112, 113 };
    static const int LIST_IRON_BLUE[] = { 36, 37, 38, 39, 58, 62, 63 };
    static const int LIST_BLOODLINE[] = { 3, 5, 42, 44, 46, 48, 50, 65, 78, 91 };
    static const int LIST_WALTZ[] = { 34, 35, 40, 41, 42, 43, 58 };
    static const int LIST_JAIL[] = { 34, 35, 54, 55, 63, 67, 68, 69, 104 };
    static const int LIST_SLASH[] = { 1, 6, 36, 37, 38, 39, 43, 65, 66, 91, 96, 97, 98, 99, 103, 112, 113 };
    static const int LIST_HEART_FIRE[] = { 40, 41, 62, 69, 81, 92, 93, 96, 97 };
    static const int LIST_ASTRONOMIA[] = { 48, 49, 52, 53, 71, 78, 79, 82, 84 };

    static clearscope bool Lists(int arcana, int system)
    {
        if (system <= 0) return false;
        switch (arcana)
        {
        case 1:
            for (int i = 0; i < DSArcana.LIST_GEMINI.Size(); i++) if (DSArcana.LIST_GEMINI[i] == system) return true;
            return false;
        case 2:
            for (int i = 0; i < DSArcana.LIST_REQUIEM.Size(); i++) if (DSArcana.LIST_REQUIEM[i] == system) return true;
            return false;
        case 3:
            for (int i = 0; i < DSArcana.LIST_TRAGIC.Size(); i++) if (DSArcana.LIST_TRAGIC[i] == system) return true;
            return false;
        case 7:
            for (int i = 0; i < DSArcana.LIST_IRON_BLUE.Size(); i++) if (DSArcana.LIST_IRON_BLUE[i] == system) return true;
            return false;
        case 9:
            for (int i = 0; i < DSArcana.LIST_BLOODLINE.Size(); i++) if (DSArcana.LIST_BLOODLINE[i] == system) return true;
            return false;
        case 11:
            for (int i = 0; i < DSArcana.LIST_WALTZ.Size(); i++) if (DSArcana.LIST_WALTZ[i] == system) return true;
            return false;
        case 14:
            for (int i = 0; i < DSArcana.LIST_JAIL.Size(); i++) if (DSArcana.LIST_JAIL[i] == system) return true;
            return false;
        case 16:
            for (int i = 0; i < DSArcana.LIST_SLASH.Size(); i++) if (DSArcana.LIST_SLASH[i] == system) return true;
            return false;
        case 19:
            for (int i = 0; i < DSArcana.LIST_HEART_FIRE.Size(); i++) if (DSArcana.LIST_HEART_FIRE[i] == system) return true;
            return false;
        case 21:
            for (int i = 0; i < DSArcana.LIST_ASTRONOMIA.Size(); i++) if (DSArcana.LIST_ASTRONOMIA[i] == system) return true;
            return false;
        }
        return true;
    }

    static clearscope int BuiltCount() { return DSArcana.BUILT.Size(); }
    static clearscope int BuiltAt(int i) { return DSArcana.BUILT[i]; }
    static clearscope bool IsOffer(int id) { return id > OFFER_BASE && id <= OFFER_BASE + 22; }
    static clearscope int Number(int id) { return id - OFFER_BASE; }
    static clearscope String Name(int n) { return n >= 1 && n <= 22 ? DSArcana.NAMES[n] : "Arcana"; }
    static clearscope String Title(int n) { return n >= 1 && n <= 22 ? DSArcana.NUMERALS[n] .. " - " .. DSArcana.NAMES[n] : "Arcana"; }

    static clearscope String Blurb(int n)
    {
        switch (n)
        {
        case TWILIGHT_REQUIEM: return "Projectiles burst when they expire; damage grows with Curse";
        case IRON_BLUE_WILL: return "Listed projectiles pass through enemies (stand-in for bounce and wall pass)";
        case DIVINE_BLOODLINE: return "Listed weapons +5 damage per Armor and +0.1 per missing HP. Touching enemies take 10 per Armor";
        case WALTZ_OF_PEARLS: return "Listed projectiles hit 3 more targets (stand-in for 3 bounces)";
        case OUT_OF_BOUNDS: return "Freezing an enemy makes it explode. Orologions are twice as common";
        case GAME_KILLER: return "No XP from gems: they hurl themselves at enemies as bombs. Chests hold 3+ items";
        case GEMINI: return "Listed weapons get +1 Amount (a stand-in for the counterpart copies)";
        case TRAGIC_PRINCESS: return "Listed weapons -30% Cooldown while you are moving";
        case JAIL_OF_CRYSTAL: return "Listed weapons have an 8% chance to freeze for 1.5s";
        case SLASH: return "Listed weapons have a 10% chance to crit for triple damage";
        case HEART_OF_FIRE: return "Listed weapons' hits may explode; light sources and you explode too";
        case BLOOD_ASTRONOMIA: return "A damaging zone around you hurts enemies, scaling with Amount and Magnet";
        case AWAKE: return "+3 Revivals. Each revival: +10% Max Health, +1 Armor, +5% Might/Area/Duration/Speed";
        case CHAOS_DARK_NIGHT: return "Speed swings x0.5-x1.5 every 10s. +1% Speed per level";
        case SARABANDE: return "All healing is doubled";
        case MAD_GROOVE: return "Pulls all gems to you now and every even minute";
        case BEGINNING: return "Starting weapon +3 Amount. Bone, Cherry Bomb, Carrello, Celestial Dusting, La Robba +1";
        case WICKED_SEASON: return "Growth, Luck, Greed, Curse take turns doubling. +0.5% each per level";
        case DISCO_OF_GOLD: return "Picking up gold heals that much";
        case LOST_FOUND_PAINTING: return "Duration swings x0.5-x1.5 every 10s. +1% Duration per level";
        case BOOGALOO: return "Area swings x0.75-x1.25 every 10s. +1% Area per level";
        case SILENT_SANCTUARY: return "+3 Reroll, Skip, Banish. +20% Might, -8% Cooldown per empty weapon slot";
        }
        return "";
    }
}

extend class DSP030VerticalSlice
{
    void ArcanaReset()
    {
        MusicDuckReset();
        arOwned.Clear(); arPickLevel.Clear(); arOffers.Clear();
        arPickOpen = false; arAwakeRevivals = 0;
        arHealDouble = false; arBeginningSystem = 0;
        arHitMask = 0; arPierceBonus = 0; arFlatBonus = 0; arFxSlot.Clear(); arFxKind.Clear(); arFxAmount.Clear(); arFxX.Clear(); arFxY.Clear(); arMoveTic = 0;
        arHitRng = 987654321;
        CVar toggle = CVar.FindCVar("ds_arcana");
        arEnabled = rsActive && (toggle == null || toggle.GetInt() != 0);
        arRng = configuredMode == "manual" ? Random[DSRunSeed](1, 0x3FFFFFFF) : 424242;
    }

    // Arcana unlock through play (DSUnlocks.ArcanaUnlocked). Automated runs
    // treat all of them as unlocked so the harnesses keep their coverage.
    bool ArcanaIsUnlocked(Array<String> k, Array<int> v, int n)
    {
        if (configuredMode != "manual") return true;
        return DSUnlocks.ArcanaUnlocked(k, v, n);
    }

    // The start-of-run pick is a testing aid: off for manual play unless
    // ds_arcana_start is set (the original gives Arcana through chests only).
    bool ArcanaStartPick()
    {
        if (configuredMode != "manual") return true;
        CVar start = CVar.FindCVar("ds_arcana_start");
        return start != null && start.GetInt() != 0;
    }

    bool ArcanaOwned(int n) { return arOwned.Find(n) != arOwned.Size(); }

    int ArcanaLevelsSince(int n)
    {
        int i = arOwned.Find(n);
        return i < arOwned.Size() ? max(0, playerLevel - arPickLevel[i]) : 0;
    }

    // Oscillation over a 10 second cycle between 1 - swing and 1 + swing.
    double ArcanaWave(double swing)
    {
        return 1.0 + swing * sin(360.0 * (tic % 350) / 350.0);
    }

    // Applied at the end of RecomputeRunStats.
    void ArcanaAdjustStats()
    {
        arGemini = ArcanaOwned(DSArcana.GEMINI); arIronBlue = ArcanaOwned(DSArcana.IRON_BLUE_WILL);
        arWaltz = ArcanaOwned(DSArcana.WALTZ_OF_PEARLS);
        arTragicMoving = ArcanaOwned(DSArcana.TRAGIC_PRINCESS) && tic - arMoveTic < 8;
        if (arOwned.Size() == 0) return;
        arHitMask = (ArcanaOwned(DSArcana.SLASH) ? 1 : 0) | (ArcanaOwned(DSArcana.JAIL_OF_CRYSTAL) ? 2 : 0)
            | (ArcanaOwned(DSArcana.HEART_OF_FIRE) ? 4 : 0) | (ArcanaOwned(DSArcana.DIVINE_BLOODLINE) ? 8 : 0);
        if (ArcanaOwned(DSArcana.AWAKE))
        {
            rsRevivalsGranted += 3;
            int n = arAwakeRevivals;
            if (n > 0)
            {
                rsMaxHealthMilli = int(rsMaxHealthMilli * (1.1 ** n));
                rsArmor += n;
                rsMightMilli += 50 * n; rsAreaMilli += 50 * n;
                rsDurationMilli += 50 * n; rsSpeedMilli += 50 * n;
            }
        }
        if (ArcanaOwned(DSArcana.CHAOS_DARK_NIGHT))
            rsSpeedMilli = int((rsSpeedMilli + 10 * ArcanaLevelsSince(DSArcana.CHAOS_DARK_NIGHT)) * ArcanaWave(0.5));
        if (ArcanaOwned(DSArcana.LOST_FOUND_PAINTING))
            rsDurationMilli = int((rsDurationMilli + 10 * ArcanaLevelsSince(DSArcana.LOST_FOUND_PAINTING)) * ArcanaWave(0.5));
        if (ArcanaOwned(DSArcana.BOOGALOO))
            rsAreaMilli = int((rsAreaMilli + 10 * ArcanaLevelsSince(DSArcana.BOOGALOO)) * ArcanaWave(0.25));
        if (ArcanaOwned(DSArcana.WICKED_SEASON))
        {
            int bonus = 5 * ArcanaLevelsSince(DSArcana.WICKED_SEASON);
            rsGrowthMilli += bonus; rsLuckMilli += bonus; rsGreedMilli += bonus; rsCurseMilli += bonus;
            int doubled = (tic / 350) % 4;
            if (doubled == 0) rsGrowthMilli *= 2;
            else if (doubled == 1) rsLuckMilli *= 2;
            else if (doubled == 2) rsGreedMilli *= 2;
            else rsCurseMilli *= 2;
        }
        if (ArcanaOwned(DSArcana.SILENT_SANCTUARY))
        {
            int empty = clamp(DSP031_MAX_ORDINARY_SLOTS - lbOwnedSystems.Size(), 0, 5);
            rsMightMilli += 200 * empty;
            rsCooldownMilli = max(100, rsCooldownMilli - 80 * empty);
        }
    }

    // True while the player owns at least one of the Arcana's listed weapons.
    bool ArcanaListOwned(int arcana)
    {
        for (int i = 0; i < lbOwnedSystems.Size(); i++)
            if (DSArcana.Lists(arcana, lbOwnedSystems[i])) return true;
        return false;
    }

    // Revival from any source while Awake is owned grows its bonus.
    void ArcanaOnRevive()
    {
        if (ArcanaOwned(DSArcana.AWAKE)) arAwakeRevivals++;
    }

    // Disco of Gold: gold picked up heals that many HP.
    void ArcanaOnGold(int gold)
    {
        if (gold <= 0 || !ArcanaOwned(DSArcana.DISCO_OF_GOLD)) return;
        int healthAfter; int appliedMilli;
        DSP039ApplyHeal(SOURCE_ARCANA_GOLD, gold * 1000, tic, runState == STATE_ACTIVE,
            playerHealth, CurrentPlayerHealthCap(), healthAfter, appliedMilli);
        playerHealth = healthAfter;
        health[playerSlot] = playerHealth;
    }

    // Automated runs only: ds_arcana_grant ("5,13,17") grants Arcanas at
    // tic 2 so their effects can be checked without the pick.
    void ArcanaDebugGrant()
    {
        // Avatar Infernas starts with Heart of Fire.
        if (rsActive && rsCharacter == DSCharacters.AVATAR && !ArcanaOwned(DSArcana.HEART_OF_FIRE))
            ArcanaTake(DSArcana.HEART_OF_FIRE);
        if (configuredMode == "manual") return;
        CVar grant = CVar.FindCVar("ds_arcana_grant");
        String text = grant != null ? grant.GetString() : "";
        Array<String> parts;
        text.Split(parts, ",", TOK_SKIPEMPTY);
        for (int i = 0; i < parts.Size(); i++)
        {
            int n = parts[i].ToInt();
            if (n >= 1 && n <= 22 && !ArcanaOwned(n)) ArcanaTake(n);
        }
    }

    // Automated runs only: ds_art_gallery 1 places one frozen enemy of each
    // sprite archetype in an arc in front of the player (art review).
    void ArtGallery()
    {
        CVar gallery = CVar.FindCVar("ds_art_gallery");
        if (configuredMode == "manual" || gallery == null || gallery.GetInt() == 0) return;
        mfFreezeUntil = 0x7FFFFFFF;
        double facing = players[0].mo != null ? players[0].mo.Angle : 90.0;
        if (players[0].mo != null) players[0].mo.Pitch = 0.0;
        for (int f = 1; f <= 20; f++)
        {
            int type = DSStage.FamilyExample(f);
            if (type <= 0) continue;
            double a = facing + (f - 10.5) * 5.5;
            double r = 260.0 + (f % 2) * 90.0;
            MFSpawn(type, playerX + cos(a) * r, playerY + sin(a) * r, 0, 0.0, 0.0, 0, 0);
        }
        // ds_art_gallery 2 also lays one of each floor pickup in a row close by.
        if (gallery.GetInt() == 2)
        {
            for (int kind = 1; kind <= MF_ITEM_LAST; kind++)
            {
                double a = facing + (kind - (MF_ITEM_LAST + 1) / 2.0) * 9.0;
                mfItemSeq++;
                mfItemIds.Push(mfItemSeq); mfItemKinds.Push(kind);
                mfItemX.Push(playerX + cos(a) * 150.0); mfItemY.Push(playerY + sin(a) * 150.0);
            }
        }
        Console.Printf("DS_ART_GALLERY spawned=20 facing=%.1f", facing);
    }

    // Mad Groove: vacuum at every even minute.
    void ArcanaTick()
    {
        if (tic == 2) ArcanaDebugGrant();
        if (tic == 3) ArtGallery();
        if (configuredMode != "manual" && runState == STATE_ACTIVE)
        {
            CVar dieAt = CVar.FindCVar("ds_debug_die_tic");
            if (dieAt != null && dieAt.GetInt() > 0 && tic == dieAt.GetInt()) { playerHealth = 0; health[playerSlot] = 0; EndRun("PLAYER_ZERO_HEALTH"); }
        }
        CVar grantTic = CVar.FindCVar("ds_item_grant_tic");
        if (tic == (grantTic != null ? grantTic.GetInt() : 200) && configuredMode != "manual")
        {
            // Automated runs only: ds_item_grant ("8,9,10,11,12") collects those
            // pickups at ds_item_grant_tic (default 200).
            CVar items = CVar.FindCVar("ds_item_grant");
            Array<String> kinds;
            if (items != null) items.GetString().Split(kinds, ",", TOK_SKIPEMPTY);
            for (int i = 0; i < kinds.Size(); i++) MFApplyItem(kinds[i].ToInt(), 0);
        }
        if (arOwned.Size() == 0) return;
        if (tic > 0 && (abs(playerX - arLastX) > 0.01 || abs(playerY - arLastY) > 0.01)) arMoveTic = tic;
        arLastX = playerX; arLastY = playerY;
        if (ArcanaOwned(DSArcana.DIVINE_BLOODLINE))
        {
            int armor = max(0, rsArmor);
            int missing = max(0, CurrentPlayerHealthCap() - playerHealth);
            arFlatBonus = min(250, 5 * armor) * 1000 + missing / 10;
        }
        ArcanaRunFx();
        if (!dsQuiet && tic % 175 == 44)
            Console.Printf("DS_ARCANA_STATS tic=%d owned=%d speed=%d duration=%d area=%d might=%d cooldown=%d growth=%d luck=%d greed=%d curse=%d revivals=%d max_health=%d", tic, arOwned.Size(), rsSpeedMilli, rsDurationMilli, rsAreaMilli, rsMightMilli, rsCooldownMilli, rsGrowthMilli, rsLuckMilli, rsGreedMilli, rsCurseMilli, rsRevivalsGranted, rsMaxHealthMilli);
        if (ArcanaOwned(DSArcana.MAD_GROOVE) && tic > 0 && tic % 4200 == 0) MFApplyItem(MF_ITEM_VACUUM, 0);
    }

    // Instant explosion that cannot itself trigger Arcana hit effects.
    void ArcanaExplode(double ex, double ey, double radius, int damageMilli)
    {
        bool was = arInFx; arInFx = true;
        GwBlast(ex, ey, radius, damageMilli, 0);
        arInFx = was;
        DSWeaponFx.Burst("WFLM", ex, ey, 20.0, radius * 0.6, 70.0, false, Color(255, 160, 80), 6);
    }

    // Twilight Requiem: 10 damage plus 13.5 per +100% Curse (wiki).
    int RequiemDamage() { return 10000 + 13500 * max(0, rsCurseMilli - 1000) / 1000; }

    // Out of Bounds: 10 damage plus 2 per minute survived (wiki).
    void ArcanaOnFreeze(double ex, double ey)
    {
        if (!ArcanaOwned(DSArcana.OUT_OF_BOUNDS)) return;
        ArcanaExplode(ex, ey, 40.0, 10000 + 2000 * (tic / 2100));
    }

    // Game Killer: a gem that would give XP flies at the nearest enemy and
    // explodes instead (10 damage x Growth).
    void ArcanaGemBomb()
    {
        Sfx(DSSfx.E_GEM_BOMB, 6);
        int target = GwNearestEnemy(playerX, playerY, 420.0);
        double tx = target >= 0 ? x[target] : playerX + cos(players[0].mo != null ? players[0].mo.Angle : 0.0) * 90.0;
        double ty = target >= 0 ? y[target] : playerY + sin(players[0].mo != null ? players[0].mo.Angle : 0.0) * 90.0;
        ArcanaExplode(tx, ty, 44.0, 10000 * max(1000, rsGrowthMilli) / 1000);
    }

    double BloodAstronomiaRadius() { return 90.0 * rsMagnetMilli / 1000.0; }

    // Runs the queued Jail of Crystal / Heart of Fire effects and the Blood
    // Astronomia zone. Damage goes through GwHit (checked hit + death path).
    void ArcanaRunFx()
    {
        arInFx = true;
        for (int i = 0; i < arFxSlot.Size(); i++)
        {
            int slot = arFxSlot[i];
            bool alive = ValidParts(slot, generations[slot], ids[slot]) && kinds[slot] == KIND_ENEMY;
            if (arFxKind[i] == 2)
            {
                // Jail of Crystal: only a survivor can be frozen.
                if (!alive) continue;
                if (!dsQuiet) Console.Printf("DS_ARCANA_FX tic=%d kind=2 slot=%d", tic, slot);
                if (!GwIsBoss(slot)) GwFreeze(slot, tic + 52);
                FxCount("arcana_jail");
            }
            else
            {
                // Heart of Fire: explodes where the hit landed, even on a kill.
                if (!dsQuiet) Console.Printf("DS_ARCANA_FX tic=%d kind=4 slot=%d", tic, slot);
                if (!alive) slot = -1;
                FxCount("arcana_fire");
                double ex = arFxX[i]; double ey = arFxY[i];
                Array<int> near;
                GwEnemiesNear(ex, ey, 48.0, near);
                for (int j = 0; j < near.Size(); j++)
                    if (near[j] != slot) GwHit(near[j], arFxAmount[i] * 6 / 10, 0);
                DSWeaponFx.Burst("WFLM", ex, ey, 20.0, 30.0, 70.0, false, Color(255, 120, 30), 8);
                Sfx(DSSfx.W_EXPLOSION, 3);
            }
        }
        arFxSlot.Clear(); arFxKind.Clear(); arFxAmount.Clear(); arFxX.Clear(); arFxY.Clear();
        if (ArcanaOwned(DSArcana.BLOOD_ASTRONOMIA) && tic % 18 == 0 && ArcanaListOwned(DSArcana.BLOOD_ASTRONOMIA))
        {
            Array<int> zone;
            GwEnemiesNear(playerX, playerY, BloodAstronomiaRadius(), zone);
            if (!dsQuiet && zone.Size() > 0 && tic % 180 == 0) Console.Printf("DS_ARCANA_FX tic=%d kind=21 enemies=%d", tic, zone.Size());
            for (int j = 0; j < zone.Size(); j++) GwHit(zone[j], 4000 * (1 + rsAmount), 0);
        }
        // Divine Bloodline: touching enemies take 10 per Armor every 0.3 s.
        if (ArcanaOwned(DSArcana.DIVINE_BLOODLINE) && tic % 10 == 0 && rsArmor > 0)
        {
            Array<int> touching;
            GwEnemiesNear(playerX, playerY, 28.0, touching);
            for (int j = 0; j < touching.Size(); j++) GwHit(touching[j], 10000 * rsArmor, 0);
        }
        // Twilight Requiem: stand-in for projectile expiry in engines with no
        // expiry hook; the generic engine explodes its own expiring shots.
        if (ArcanaOwned(DSArcana.TWILIGHT_REQUIEM) && tic % 52 == 0 && ArcanaListOwned(DSArcana.TWILIGHT_REQUIEM))
        {
            Array<int> near;
            GwEnemiesNear(playerX, playerY, 300.0, near);
            if (near.Size() > 0)
            {
                int slot = near[GwRandom(near.Size())];
                ArcanaExplode(x[slot], y[slot], 40.0, RequiemDamage());
            }
        }
        arInFx = false;
    }

    bool ArcanaCanDrop()
    {
        if (!arEnabled || arOwned.Size() >= DSArcana.MAX_OWNED) return false;
        Array<String> mk; Array<int> mv;
        DSMeta.Load(mk, mv);
        for (int i = 0; i < DSArcana.BuiltCount(); i++)
        {
            int n = DSArcana.BuiltAt(i);
            if (!ArcanaOwned(n) && ArcanaIsUnlocked(mk, mv, n)) return true;
        }
        return false;   // nothing unlocked to give: the boss drops an ordinary chest
    }

    // Picks up to 3 unowned built Arcanas, excluding the current offers when
    // rerolling.
    void ArcanaGenerateOffers(bool excludeCurrent)
    {
        Array<int> pool;
        Array<String> mk; Array<int> mv;
        DSMeta.Load(mk, mv);
        for (int i = 0; i < DSArcana.BuiltCount(); i++)
        {
            int n = DSArcana.BuiltAt(i);
            if (ArcanaOwned(n) || (excludeCurrent && arOffers.Find(n) != arOffers.Size())) continue;
            if (!ArcanaIsUnlocked(mk, mv, n)) continue;
            pool.Push(n);
        }
        if (pool.Size() == 0 && excludeCurrent) { ArcanaGenerateOffers(false); return; }
        arOffers.Clear();
        while (arOffers.Size() < 4 && pool.Size() > 0)
        {
            arRng = DSP022StageGeometry.NextSpawnRng(arRng);
            int pick = (arRng & 0x7fffffff) % pool.Size();
            arOffers.Push(pool[pick]);
            pool.Delete(pick);
        }
    }

    void PublishArcanaOffers()
    {
        int count = arOffers.Size();
        SendInterfaceEvent(consoleplayer, "P030_OFFER0", count > 0 ? DSArcana.OFFER_BASE + arOffers[0] : 0, 0, 0);
        SendInterfaceEvent(consoleplayer, "P030_OFFER1", count > 1 ? DSArcana.OFFER_BASE + arOffers[1] : 0, 0, count);
        SendInterfaceEvent(consoleplayer, "P030_OFFER2", count > 2 ? DSArcana.OFFER_BASE + arOffers[2] : 0, 0, 0);
        SendInterfaceEvent(consoleplayer, "P030_OFFER3", count > 3 ? DSArcana.OFFER_BASE + arOffers[3] : 0, 0, 0);
        SendInterfaceEvent(consoleplayer, "P031_MAP16_OFFER_COUNT", count, 0, 0);
    }

    void OpenArcanaPick(String reason)
    {
        if (!ArcanaCanDrop() || modalPlayOpen) return;
        ArcanaGenerateOffers(false);
        if (arOffers.Size() == 0) return;
        Transition(STATE_LEVELUP, reason);
        Sfx(DSSfx.ARCANA);
        arPickOpen = true; modalPlayOpen = true;
        IsUiProcessor = true; ClearNativeInput();
        EmitInputOwnership("MODAL");
        PublishArcanaOffers();
        PublishLevelUpCharges();
        SendInterfaceEvent(consoleplayer, "P030_OPEN", 0, 0, 0);
        Console.Printf("DS_ARCANA_OPEN tic=%d reason=%s owned=%d offers=%d,%d,%d,%d", tic, reason, arOwned.Size(),
            arOffers.Size() > 0 ? arOffers[0] : 0, arOffers.Size() > 1 ? arOffers[1] : 0, arOffers.Size() > 2 ? arOffers[2] : 0,
            arOffers.Size() > 3 ? arOffers[3] : 0);
    }

    void ArcanaTake(int n)
    {
        Sfx(DSSfx.E_ARCANA_TAKE);
        arOwned.Push(n); arPickLevel.Push(playerLevel);
        if (n == DSArcana.SARABANDE) arHealDouble = true;
        if (n == DSArcana.BEGINNING) arBeginningSystem = DSCharacters.StartingWeapon(rsCharacter);
        if (n == DSArcana.SILENT_SANCTUARY)
        {
            dsp031RerollsRemaining += 3; dsp031SkipsRemaining += 3; dsp031BanishesRemaining += 3;
        }
        RecomputeRunStats();
        if (n == DSArcana.MAD_GROOVE) MFApplyItem(MF_ITEM_VACUUM, 0);
        Console.Printf("DS_ARCANA_TAKE tic=%d arcana=%d name=%s owned=%d", tic, n, DSArcana.Name(n), arOwned.Size());
    }

    void CloseArcanaPick()
    {
        arPickOpen = false; arOffers.Clear();
        CloseOrChainLevelUp(0);
    }

    void ApplyArcanaChoice(int index)
    {
        if (!arPickOpen || index < 0 || index >= arOffers.Size()) return;
        ArcanaTake(arOffers[index]);
        CloseArcanaPick();
    }

    // Reroll (new offers) or Skip (no Arcana) on the Arcana pick.
    bool ArcanaAction(int kind)
    {
        bool accepted = false;
        if (kind == LEVELUP_ACTION_REROLL && dsp031RerollsRemaining > 0)
        {
            dsp031RerollsRemaining--;
            if (DSP031PreserveRoll()) dsp031RerollsRemaining++;
            ArcanaGenerateOffers(true);
            PublishArcanaOffers();
            SendInterfaceEvent(consoleplayer, "P030_REFRESH", kind, 0, 0);
            accepted = true;
        }
        else if (kind == LEVELUP_ACTION_SKIP && dsp031SkipsRemaining > 0)
        {
            dsp031SkipsRemaining--;
            if (DSP031PreserveRoll()) dsp031SkipsRemaining++;
            accepted = true;
        }
        Console.Printf("DS_ARCANA_ACTION kind=%d accepted=%d", kind, accepted);
        PublishLevelUpCharges();
        if (accepted && kind == LEVELUP_ACTION_SKIP) CloseArcanaPick();
        return accepted;
    }
}
