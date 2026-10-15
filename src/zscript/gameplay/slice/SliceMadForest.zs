// Mad Forest stage rules: timeline spawns, bosses, chests, floor items, Reaper.
// Part of DSP030VerticalSlice (fields and core lifecycle live in
// gameplay/VerticalSlice.zs).

extend class DSP030VerticalSlice
{
    bool MFValid(int slot)
    {
        return slot >= 0 && slot < mfStable.Size() && ids[slot] != 0
            && mfStable[slot] == ids[slot];
    }

    void MFResetState()
    {
        mfNextWaveTic = 70; mfNextBossIndex = 0; mfNextEventIndex = 0;
        mfNextReaperTic = 0;
        mfEventRng = 5170311; mfChestRng = 9120447; mfChestSeq = 0;
        mfStable.Clear(); mfTypes.Clear(); mfMotion.Clear(); mfExpire.Clear();
        mfBoss.Clear(); mfVX.Clear(); mfVY.Clear();
        mfChestIds.Clear(); mfChestItems.Clear();
        mfEnderAlive = false;
        mfClovers = 0; mfFeverTics = 0; mfGoldFingerUntil = 0;
        rsSole = false; soleNextTic = 0; soleUntilTic = 0; rsCandy2 = false;
        CVar debugSole = CVar.FindCVar("ds_debug_sole");
        if (configuredMode != "manual" && debugSole != null && debugSole.GetInt() != 0) MFGrantSole(); mfBreathUntil = 0; mfDefang.Clear();
        mfGold = 0; mfGoldMilli = 0; mfFreezeUntil = 0; mfVacuumActive = false;
        mfLootRng = 7310529; mfItemSeq = 0;
        mfHeld = 0; mfCoopStarted = false;
        MetaRunReset();
        mfCoop = level.MapName == "MAP41"; mfMolise = level.MapName == "MAP36";
        mfItemIds.Clear(); mfItemKinds.Clear(); mfItemX.Clear(); mfItemY.Clear();
    }

    void MFPlace(out double sx, out double sy)
    {
        spawnAttempts++;
        // The Depths: on the player's floor, a few rooms away along the corridors.
        if (dgActive) { DgPlace(DG_SPAWN_NEAR, DG_SPAWN_FAR, sx, sy); return; }
        spawnRng = DSP022StageGeometry.NextSpawnRng(spawnRng);
        int side; int lane;
        DSP022StageGeometry.Place(spawnRng, spawnAttempts, 0, 0, playerX, playerY,
            sx, sy, side, lane);
        // The source spawn band is only 160 units out, so enemies popped in
        // right beside the player. Spawn much farther (MF_SPAWN_SCALE); the
        // catch-up speed in MoveEnemies brings them in.
        sx = playerX + (sx - playerX) * MF_SPAWN_SCALE;
        sy = playerY + (sy - playerY) * MF_SPAWN_SCALE;
        // Hall stages (Library, Tower): enemies arrive inside the hall, mostly
        // from its ends, instead of through the walls.
        int clampX = DSStage.ClampX(mfStage); int clampY = DSStage.ClampY(mfStage);
        if (clampX > 0) sx = clamp(sx, -clampX, clampX);
        if (clampY > 0) sy = clamp(sy, -clampY, clampY);
        // Il Molise: enemies are immobile and sit on a tile grid, one per tile.
        if (mfMolise)
        {
            double cell = 96.0;
            for (int attempt = 0; attempt < 8; attempt++)
            {
                double tx = floor(sx / cell) * cell + cell * 0.5;
                double ty = floor(sy / cell) * cell + cell * 0.5;
                if (!MoliseOccupied(tx, ty)) { sx = tx; sy = ty; break; }
                spawnRng = DSP022StageGeometry.NextSpawnRng(spawnRng);
                sx += ((spawnRng & 0xff) % 7 - 3) * cell;
                sy += (((spawnRng >> 8) & 0xff) % 7 - 3) * cell;
            }
        }
        // The Coop: enemies stay inside the pen the fences currently allow.
        if (mfCoop) sx = clamp(sx, CoopWest() + 40.0, CoopEast() - 40.0);
        if (mfWoods) sx = max(sx, WoodWest() + 40.0);
        if (mfRoom) sy = clamp(sy, RoomSouth() + 40.0, 12100.0);
    }

    // motion 0 chases the player; motion 1 flies straight (swarms).
    // bossIndex is 0 for ordinary enemies, else timeline boss index + 1.
    int MFSpawn(int type, double sx, double sy, int motion, double vx, double vy,
        int expireTic, int bossIndex)
    {
        bool prop = MFIsProp(type);
        int hp = prop ? (type == MF_CART_TYPE ? 60000 : MF_BRAZIER_HP) : DSStage.HpMilli(type);
        if (rsActive && !prop && rsCurseMilli != 1000)
            hp = hp > 2000000000 / rsCurseMilli * 1000 ? 2000000000 : hp / 1000 * rsCurseMilli + hp % 1000 * rsCurseMilli / 1000;
        int stageHealth = DSStage.EnemyHealthMilli(mfStage) + DSStage.HealthPerMinuteMilli(mfStage) * (MfT() / 2100)
            + DSStage.HealthPerLevelMilli(mfStage) * max(0, playerLevel - 1);
        if (rsMode == 1) stageHealth = stageHealth * (1000 + DSStage.HyperHealthMilli(mfStage)) / 1000;
        if (rsMode == 2) stageHealth = stageHealth * 2 + DSStage.InverseHealthPerMinuteMilli(mfStage) * (MfT() / 2100);
        if (dgActive) stageHealth = stageHealth * (1000 + DG_DEPTH_HEALTH_MILLI * dgDepth) / 1000;
        stageHealth *= 1 + mfEndlessCycle;   // Endless: every loop adds the base health again
        if (rsActive && !prop && stageHealth != 1000)
            hp = hp > 2000000000 / stageHealth * 1000 ? 2000000000 : hp / 1000 * stageHealth + hp % 1000 * stageHealth / 1000;
        if (bossIndex > 0 || DSStage.IsReaperLike(type))
        {
            // Wiki: boss HP scales with player level (approximation).
            int level = playerLevel > 1 ? playerLevel : 1;
            hp = hp > 2000000000 / level ? 2000000000 : hp * level;
        }
        int slot = Allocate(KIND_ENEMY, sx, sy, 0.0, 0.0, hp);
        if (slot < 0) return -1;
        collisionRadii[slot] = DSStage.IsBig(type) ? 6.0 : 2.0;
        while (mfDefang.Size() <= slot) mfDefang.Push(0);
        while (mfStable.Size() <= slot)
        {
            mfStable.Push(0); mfTypes.Push(0); mfMotion.Push(0); mfExpire.Push(0);
            mfBoss.Push(0); mfVX.Push(0.0); mfVY.Push(0.0);
        }
        while (mfLives.Size() <= slot) { mfLives.Push(0); mfSpawnHp.Push(0); mfShotTic.Push(0); }
        mfLives[slot] = prop ? 0 : DSStage.ExtraLives(type);
        mfSpawnHp[slot] = hp;
        mfShotTic[slot] = 0;
        mfStable[slot] = ids[slot]; mfTypes[slot] = type; mfMotion[slot] = motion;
        mfDefang[slot] = 0;
        if (rsActive && rsDefangPct > 0 && !prop && bossIndex == 0 && motion == 0 && !DSStage.IsReaperLike(type)
            && (DSStage.ResistBits(type) & MF_RESIST_DEFANG) == 0)
        {
            spawnRng = DSP022StageGeometry.NextSpawnRng(spawnRng);
            if ((spawnRng & 0x7fffffff) % 100 < rsDefangPct) mfDefang[slot] = 1;
        }
        mfExpire[slot] = expireTic; mfBoss[slot] = bossIndex;
        mfVX[slot] = vx; mfVY[slot] = vy;
        spawnAdmissions++;
        return slot;
    }

    void MFReleaseSpawns()
    {
        // The Coop: the stage clock waits for the first kill.
        if (mfCoop && !mfCoopStarted) { if (kills > 0) { mfCoopStarted = true; Console.Printf("DS_COOP_START tic=%d held=%d", tic, mfHeld); } else mfHeld++; }
        if (tic >= RunEndTic()) return;
        if (tic % DSStage.LightIntervalTics(mfStage) == 0) MFTrySpawnBrazier();
        if (tic % 35 == 0) MetaTrackLoadout();
        MFSoleTick();
        if (mfGoldFingerUntil > 0 && tic >= mfGoldFingerUntil)
        {
            int prize = MFAddGold(max(0, kills - mfGoldFingerKills));
            mfGoldFingerUntil = 0;
            RecomputeRunStats();
            GmShowToast(String.Format("Gold Finger prize: %d gold", prize));
        }
        int minute = MfT() / 2100;
        while (mfNextBossIndex < DSStage.BossCount(mfStage)
            && MfT() >= DSStage.BossMinute(mfStage, mfNextBossIndex) * 2100)
        {
            double sx; double sy; MFPlace(sx, sy);
            int type = DSStage.BossType(mfStage, mfNextBossIndex);
            int slot = MFSpawn(type, sx, sy, 0, 0.0, 0.0, 0, mfNextBossIndex + 1);
            Sfx(DSSfx.BOSS, 35);
            Console.Printf("DS_MF_BOSS tic=%d index=%d type=%s slot=%d hp=%d sprite=%s classification=WIKI_APPROXIMATION", tic, mfNextBossIndex, DSStage.TypeName(type), slot, slot >= 0 ? health[slot] : 0, EnemySpriteName(type));
            mfNextBossIndex++;
        }
        // Random Events (Trisection): halfway through each minute, a coin flip
        // starts one of the stage's map events.
        if (rsRandomEvents && MfT() % 2100 == 1050 && DSStage.EventCount(mfStage) > 0)
        {
            mfEventRng = DSP022StageGeometry.NextSpawnRng(mfEventRng);
            if ((mfEventRng & 0x7fffffff) % 100 < 50)
                MFStartEvent(((mfEventRng >>> 8) & 0x7fffff) % DSStage.EventCount(mfStage), true);
        }
        while (mfNextEventIndex < DSStage.EventCount(mfStage)
            && MfT() >= DSStage.EventTic(mfStage, mfNextEventIndex))
        {
            MFStartEvent(mfNextEventIndex);
            mfNextEventIndex++;
        }
        if (tic < mfNextWaveTic) return;
        mfNextWaveTic = tic + (rsActive ? max(1, DSStage.IntervalTics(mfStage, minute) * 1000 / rsCurseMilli) : DSStage.IntervalTics(mfStage, minute));
        // Each interval spawns one of each pool type, topping up to the
        // minute's minimum when the field is thinner than that.
        int pool = DSStage.PoolCount(mfStage, minute);
        if (pool <= 0) return;
        int live = LiveEnemyCount();
        int budget = pool;
        int wanted = DSStage.EnemyMin(mfStage, minute);
        if (rsActive) { budget = budget * rsCurseMilli / 1000; wanted = wanted * rsCurseMilli / 1000; }
        if (live + budget < wanted) budget = wanted - live;
        budget += rsCharm;   // Charm: flat extra enemies per wave, after Curse
        if (budget > MF_BURST_CAP) budget = MF_BURST_CAP;
        for (int n = 0; n < budget && live < MF_LIVE_CAP; n++)
        {
            double sx; double sy; MFPlace(sx, sy);
            if (MFSpawn(DSStage.PoolType(mfStage, minute, n % pool), sx, sy, 0, 0.0, 0.0, 0, 0) >= 0)
                live++;
        }
    }

    // kind 1 bat swarm, 2 ghost swarm, 3 flower wall.
    // Map events from the stage tables (tools/gen_stages.py): each row has a
    // kind, enemy type, amount and chance. Geometry is an approximation.
    void MFStartEvent(int index, bool force = false)
    {
        int kind = DSStage.EventKind(mfStage, index);
        int duration = DSStage.EventDurationTics(mfStage, index);
        int type = DSStage.EventEnemy(mfStage, index);
        int count = DSStage.EventAmount(mfStage, index);
        int chance = DSStage.EventChancePct(mfStage, index);
        mfEventRng = DSP022StageGeometry.NextSpawnRng(mfEventRng);
        if (!force && (mfEventRng & 0x7fffffff) % 100 >= chance)
        {
            Console.Printf("DS_MF_EVENT tic=%d kind=%d skipped=1 chance=%d", tic, kind, chance);
            return;
        }
        int expire = tic + duration;
        int spawned = 0;
        if (kind == 3)
        {
            // Ring radius is not on the wiki (engineering approximation).
            double radius = DSStage.FLOWER_RING_RADIUS;
            for (int i = 0; i < count; i++)
            {
                double angle = 360.0 * i / count;
                if (MFSpawn(type, playerX + cos(angle) * radius,
                    playerY + sin(angle) * radius, 0, 0.0, 0.0, expire, 0) >= 0) spawned++;
            }
        }
        else if (kind == 7)
        {
            // Monster Dance: a ring that circles the player's spot.
            for (int i = 0; i < count; i++)
            {
                double angle = 360.0 * i / max(1, count);
                if (MFSpawn(type, playerX + cos(angle) * 240.0, playerY + sin(angle) * 240.0,
                    3, playerX, playerY, expire, 0) >= 0) spawned++;
            }
        }
        else if (kind >= 8 && kind <= 10)
        {
            spawned = MFDiamonds(kind, type, expire);
        }
        else if (kind == 11)
        {
            // Invaders: a block of rows that marches in from one side.
            mfEventRng = DSP022StageGeometry.NextSpawnRng(mfEventRng);
            double heading = (mfEventRng & 0x7fffffff) % 4 * 90.0;
            double fx = cos(heading); double fy = sin(heading);
            double speed = clamp(DSStage.SpeedMilliPerTic(type) / 1000.0 * StageEnemySpeedScale(), 0.5, 1.5);
            for (int i = 0; i < count; i++)
            {
                double lateral = (i % 8 - 3.5) * 44.0;
                double back = 420.0 + (i / 8) * 40.0;
                if (MFSpawn(type, playerX - fx * back - fy * lateral, playerY - fy * back + fx * lateral,
                    1, fx * speed, fy * speed, expire, 0) >= 0) spawned++;
            }
        }
        else if (kind == 12)
        {
            // A lone boss visit (the Drowner, the Trickster) that chases the
            // player and leaves when the event ends.
            mfEventRng = DSP022StageGeometry.NextSpawnRng(mfEventRng);
            double angle = (mfEventRng & 0x7fffffff) % 360;
            for (int i = 0; i < max(1, count); i++)
                if (MFSpawn(type, playerX + cos(angle) * 420.0, playerY + sin(angle) * 420.0,
                    0, 0.0, 0.0, expire, 0) >= 0) spawned++;
        }
        else if (kind == 5)
        {
            // Chasers that burst out near the player and vanish after the
            // event's short duration.
            for (int i = 0; i < count; i++)
            {
                double angle = 360.0 * i / max(1, count) + 45.0;
                if (MFSpawn(type, playerX + cos(angle) * 160.0, playerY + sin(angle) * 160.0,
                    0, 0.0, 0.0, expire, 0) >= 0) spawned++;
            }
        }
        else
        {
            mfEventRng = DSP022StageGeometry.NextSpawnRng(mfEventRng);
            double heading = (mfEventRng & 0x7fffffff) % 360;
            // Wall lines and Medusa swarms travel horizontally, from one side.
            if (kind == 4 || kind == 6)
            {
                // Along the stage's long axis: vertical halls (Tower) run
                // north-south, everything else east-west.
                bool vertical = DSStage.ClampX(mfStage) > 0;
                heading = (mfEventRng & 1) != 0 ? (vertical ? 90.0 : 0.0) : (vertical ? 270.0 : 180.0);
            }
            double speed = DSStage.SpeedMilliPerTic(type) / 1000.0 * StageEnemySpeedScale();
            speed = clamp(speed, 0.3, 2.6);   // swarms and walls keep their crossing speed
            double fx = cos(heading); double fy = sin(heading);
            for (int i = 0; i < count; i++)
            {
                double lateral; double back;
                if (kind == 4)
                {
                    // A vertical line spanning the view, entering from one side.
                    lateral = (i - (count - 1) / 2.0) * 48.0;
                    back = 320.0;
                }
                else
                {
                    // A block of fliers that crosses straight through the player.
                    lateral = (i % 10 - 4.5) * 12.0;
                    back = 200.0 + (i / 10) * 12.0;
                }
                double sx = playerX - fx * back - fy * lateral;
                double sy = playerY - fy * back + fx * lateral;
                if (MFSpawn(type, sx, sy, 1, fx * speed, fy * speed, expire, 0) >= 0) spawned++;
            }
        }
        Sfx(DSSfx.E_SWARM, 70);
        Console.Printf("DS_MF_EVENT tic=%d kind=%d duration=%d spawned=%d classification=WIKI_APPROXIMATION", tic, kind, duration, spawned);
    }

    // Robbert and She-Moon Eeta react when health falls below 20%: Robbert
    // heals 25% and gains +32 Max Health (up to +665), She-Moon freezes every
    // enemy for 10 seconds. The cooldowns (10 s / 60 s) are guesses.
    void MFNearDeath()
    {
        if (!rsActive || playerHealth <= 0 || tic < mfCritReadyTic) return;
        int cap = CurrentPlayerHealthCap();
        if (playerHealth * 5 > cap) return;
        if (rsCharacter == DSCharacters.ROBBERT)
        {
            rsBonusHealthMilli = min(665000, rsBonusHealthMilli + 32000);
            RecomputeRunStats();
            cap = CurrentPlayerHealthCap();
            int healthAfter; int appliedMilli;
            DSP039ApplyHeal(SOURCE_NEAR_DEATH, cap / 4, tic, runState == STATE_ACTIVE,
                playerHealth, cap, healthAfter, appliedMilli);
            playerHealth = healthAfter;
            health[playerSlot] = playerHealth;
            mfCritReadyTic = tic + 350;
            FxCount("near_death_heal");
        }
        else if (rsCharacter == DSCharacters.SHEMOON)
        {
            Sfx(DSSfx.FREEZE);
            mfFreezeStart = tic; mfFreezeUntil = max(mfFreezeUntil, tic + MF_FREEZE_TICS);
            mfCritReadyTic = tic + 2100;
            FxCount("near_death_freeze");
        }
    }

    // Diamond Road (8), Square (9) and Maze (10): stationary blockers laid
    // out around the player for the event's duration (approximate shapes).
    int MFDiamonds(int kind, int type, int expire)
    {
        int spawned = 0;
        double step = 48.0;
        if (kind == 8)
        {
            // Two parallel lines through the player along a random axis.
            mfEventRng = DSP022StageGeometry.NextSpawnRng(mfEventRng);
            bool vertical = (mfEventRng & 1) != 0;
            for (int side = -1; side <= 1; side += 2)
                for (int i = -10; i <= 10; i++)
                {
                    double a = i * step; double b = side * 120.0;
                    if (MFSpawn(type, playerX + (vertical ? b : a), playerY + (vertical ? a : b), 2, 0.0, 0.0, expire, 0) >= 0) spawned++;
                }
            return spawned;
        }
        // Square: one box; Maze: three boxes with gaps to slip through.
        int boxes = kind == 9 ? 1 : 3;
        for (int box = 0; box < boxes; box++)
        {
            double half = 240.0 + box * 160.0;
            int perSide = int(half * 2 / step);
            for (int s = 0; s < 4; s++)
                for (int i = 0; i < perSide; i++)
                {
                    if (kind == 10 && (i + box * 3 + s * 5) % 7 < 2) continue;   // gaps
                    double t = -half + i * step;
                    double px = s == 0 ? t : (s == 1 ? half : (s == 2 ? -t : -half));
                    double py = s == 0 ? -half : (s == 1 ? t : (s == 2 ? half : -t));
                    if (MFSpawn(type, playerX + px, playerY + py, 2, 0.0, 0.0, expire, 0) >= 0) spawned++;
                }
        }
        return spawned;
    }

    // Endless (Seventh Trumpet): no Reaper; the stage's timeline starts over
    // with every enemy tougher (+100% health per loop).
    void MFEndlessLoop()
    {
        mfEndlessCycle++;
        mfHeld += RunEndTic() - mfHeld;
        mfNextBossIndex = 0; mfNextEventIndex = 0; mfNextWaveTic = tic;
        GmShowToast(String.Format("Endless: loop %d", mfEndlessCycle + 1));
        Console.Printf("DS_MF_ENDLESS tic=%d cycle=%d", tic, mfEndlessCycle);
    }

    // Random Level-ups (Brave Story): the level-up picks one offer at random.
    void RandomLevelUpTick()
    {
        if (arPickOpen || !modalPlayOpen || ActiveDraftQueueCount() <= 0) return;
        int count = ActiveDraftOfferCount();
        if (count <= 0) return;
        mfEventRng = DSP022StageGeometry.NextSpawnRng(mfEventRng);
        ApplyChoice((mfEventRng & 0x7fffffff) % count, "RANDOM_LEVELUP");
    }

    // Sole Solution: Victory Sword's gift once Victory Sword and Torrona's
    // Box are maxed. It takes no slot. Every 20 s a galaxy covers the screen
    // for 10 s, hitting every enemy for 10 (+1 per 5000 kills, Might only)
    // every 0.1 s while the character is intangible.
    bool MFTrySole()
    {
        if (rsSole) return false;
        int sword = N2Find(DSN2Catalog.ID_N3_VICTORY_SWORD);
        if (sword < 0 || n2Rank[sword] < DSN2Catalog.MaxRank(DSN2Catalog.ID_N3_VICTORY_SWORD)) return false;
        if (DSP031Rank(DSN2Catalog.ID_N3_TORRONA_S_BOX) < 9) return false;
        MFGrantSole();
        return true;
    }

    void MFGrantSole()
    {
        rsSole = true; soleNextTic = tic + 105;
        Sfx(DSSfx.E_EVOLUTION);
        GmShowToast("Sole Solution: the gift of the Victory Sword");
        Console.Printf("DS_GIFT tic=%d gift=SOLE_SOLUTION", tic);
    }

    void MFSoleTick()
    {
        if (!rsSole || runState != STATE_ACTIVE) return;
        if (tic >= soleNextTic)
        {
            soleUntilTic = tic + 350; soleNextTic = tic + 700;
            Sfx(DSSfx.E_EVOLUTION, 3);
        }
        if (tic >= soleUntilTic) return;
        playerInvulnerableUntil = max(playerInvulnerableUntil, tic + 2);
        if (tic % 4 != 0) return;
        int damage = (10 + kills / 5000) * 1000 * rsMightMilli / 1000;
        Array<int> screen;
        GwEnemiesNear(playerX, playerY, 700.0, screen);
        for (int i = 0; i < screen.Size(); i++) GwHit(screen[i], damage, DSN2Catalog.ID_N3_SOLE_SOLUTION);
        FxCount("sole_hit", screen.Size());
        if (tic % 20 == 0)
            DSWeaponFx.Burst("WBLT", playerX, playerY, 30.0, 300.0, 50.0, false, Color(255, 190, 120, 255), 10);
    }

    // True while some owned weapon or passive can still level up.
    bool N2CanRankUpAny()
    {
        if (whipRank > 0 && whipRank < 8) return true;
        for (int i = 0; i < n2System.Size(); i++)
            if (n2Rank[i] < DSP031MaxRank(n2System[i])) return true;
        for (int i = 0; i < dsp031ItemIds.Size(); i++)
            if (dsp031ItemRanks[i] < DSP031MaxRank(dsp031ItemIds[i])) return true;
        return false;
    }

    // Super Candybox II Turbo: with Candybox taken this run and nothing left to
    // level, a chest may hold it instead of gold (Luck-scaled 1%, guaranteed
    // in a 5-item chest). It opens a pick of evolutions made in earlier runs.
    void MFTryCandybox2(int items, bool maxedOut)
    {
        // (no gift draft may be pending; dsp031GiftDraft >= applied drafts means one is)
        if (!maxedOut || dsp031GiftDraft >= dsp031AppliedDrafts || DSP031OwnedIndex(DSN2Catalog.ID_N3_CANDYBOX) < 0) return;
        mfLootRng = DSP022StageGeometry.NextSpawnRng(mfLootRng);
        int chance = items >= 5 ? 1000 : 10 * rsLuckMilli / 1000;
        if ((mfLootRng & 0x7fffffff) % 1000 >= chance) return;
        rsCandy2 = true;
        dsp031GiftKind = 3;
        dsp031DraftLevels.Push(playerLevel);
        dsp031GiftDraft = dsp031DraftLevels.Size() - 1;
        GmShowToast("Super Candybox II Turbo!");
        Console.Printf("DS_GIFT tic=%d gift=CANDYBOX2", tic);
    }

    bool MFResists(int slot, int bit)
    {
        return mfEnabled && MFValid(slot) && (DSStage.ResistBits(mfTypes[slot]) & bit) != 0;
    }

    // Orologion freeze, shortened by the enemy's freeze resistance (the
    // Reaper and fully resistant enemies keep moving).
    bool MFOrologionFrozen(int slot)
    {
        if (tic >= mfFreezeUntil || DSStage.IsReaperLike(mfTypes[slot])) return false;
        int resist = DSStage.FreezeResistMilli(mfTypes[slot]);
        if (resist <= 1000) return true;
        if (resist >= 100000) return false;
        int length = mfFreezeUntil - mfFreezeStart;
        if (length > 100000) return true;
        return tic < mfFreezeStart + length * 1000 / resist;
    }

    // Ranged enemies fire their bullet (itself a fast enemy flying straight)
    // at the player every few seconds while within range.
    void MFShoot(int slot)
    {
        int bullet = DSStage.BulletType(mfTypes[slot]);
        if (bullet <= 0 || slot >= mfShotTic.Size() || MFOrologionFrozen(slot) || GwFrozen(slot)) return;
        if (mfShotTic[slot] == 0) { mfShotTic[slot] = tic + DSStage.FireTics(mfTypes[slot]); return; }
        if (tic < mfShotTic[slot]) return;
        mfShotTic[slot] = tic + DSStage.FireTics(mfTypes[slot]);
        double dx = playerX - x[slot]; double dy = playerY - y[slot];
        double d = sqrt(dx * dx + dy * dy);
        if (d < 1.0 || d > MF_SHOT_RANGE) return;
        double speed = DSStage.SpeedMilliPerTic(bullet) / 1000.0 * StageEnemySpeedScale();
        int shot = MFSpawn(bullet, x[slot], y[slot], 1, dx / d * speed, dy / d * speed, tic + MF_SHOT_TICS, 0);
        if (shot >= 0) FxCount("enemy_shot");
    }

    // Expires timed event enemies (no XP) and leashes stragglers back into
    // the spawn band, as the original re-positions enemies left far behind.
    void MFMaintainEnemies()
    {
        for (int slot = 0; slot < lifeStates.Size(); slot++)
        {
            if (lifeStates[slot] != STORE_ALIVE || kinds[slot] != KIND_ENEMY
                || !MFValid(slot)) continue;
            if (mfExpire[slot] > 0 && tic >= mfExpire[slot])
            {
                mfStable[slot] = 0;
                DestroyParts(slot, generations[slot], ids[slot]);
                continue;
            }
            MFShoot(slot);
            // The Depths keeps its own enemies (DgKeepEnemies).
            if (mfMotion[slot] != 0 || mfBoss[slot] > 0 || mfRoom || dgActive) continue;
            double dx = x[slot] - playerX; double dy = y[slot] - playerY;
            if (dx * dx + dy * dy <= MF_LEASH * MF_LEASH) continue;
            double sx; double sy; MFPlace(sx, sy);
            x[slot] = sx; y[slot] = sy;
        }
    }

    // At 30:00 every enemy is removed and the Reaper arrives, then one more
    // every minute; the run ends when the player falls.
    void MFMaintainReaper()
    {
        if (mfNextReaperTic == 0) mfNextReaperTic = RunEndTic();
        if (tic < mfNextReaperTic) return;
        if (mfNextReaperTic == RunEndTic())
        {
            for (int slot = 0; slot < lifeStates.Size(); slot++)
            {
                if (lifeStates[slot] != STORE_ALIVE || kinds[slot] != KIND_ENEMY) continue;
                if (slot < mfStable.Size()) mfStable[slot] = 0;
                DestroyParts(slot, generations[slot], ids[slot]);
            }
        }
        double sx; double sy; MFPlace(sx, sy);
        // Cappella Magna: with the Yellow Sign the Ender comes first, alone,
        // and the Reapers wait until it is beaten (it ends the run when it falls).
        if (mfNextReaperTic == RunEndTic() && DSStage.ENDER_TYPE > 0 && mfStage == DSStage.CAPPELLA)
        {
            Array<String> ek; Array<int> ev;
            DSMeta.Load(ek, ev);
            if (DSMeta.Val(ek, ev, "relic:1") > 0 || DSUnlocks.All())
            {
                int eslot = MFSpawn(DSStage.ENDER_TYPE, sx, sy, 0, 0.0, 0.0, 0, 0);
                mfEnderAlive = eslot >= 0;
                Sfx(DSSfx.REAPER);
                GmShowToast("The Ender approaches...");
                Console.Printf("DS_MF_ENDER tic=%d slot=%d hp=%d classification=WIKI_APPROXIMATION", tic, eslot, eslot >= 0 ? health[eslot] : 0);
                mfNextReaperTic = tic + 2100;
                return;
            }
        }
        if (mfEnderAlive) { mfNextReaperTic = tic + 350; return; }
        int slot = MFSpawn(DSStage.REAPER_TYPE, sx, sy, 0, 0.0, 0.0, 0, 0);
        Sfx(DSSfx.REAPER);
        Console.Printf("DS_MF_REAPER tic=%d slot=%d hp=%d classification=WIKI_APPROXIMATION", tic, slot, slot >= 0 ? health[slot] : 0);
        mfNextReaperTic = tic + 2100;
    }

    // Timeline bosses roll their wiki chest chances (5/3/1 items). Arcana
    // chests are not built yet and open as ordinary 1-item chests.
    void MFDropBossChest(int bossIndex, double deathX, double deathY)
    {
        int p5 = DSStage.BossChest5Pct(mfStage, bossIndex);
        int p3 = DSStage.BossChest3Pct(mfStage, bossIndex);
        int p1 = DSStage.BossChest1Pct(mfStage, bossIndex);
        if (rsActive && rsLuckMilli > 1000)
        {
            p5 = min(100, p5 * rsLuckMilli / 1000);
            p3 = min(100 - p5, p3 * rsLuckMilli / 1000);
        }
        mfChestRng = DSP022StageGeometry.NextSpawnRng(mfChestRng);
        int roll = (mfChestRng & 0x7fffffff) % 100;
        int items = 0;
        // Arcana-holder bosses drop an Arcana chest while the run can still
        // take one; otherwise their chest is an ordinary 1-item chest.
        bool arcanaChest = DSStage.BossArcana(mfStage, bossIndex) != 0 && ArcanaCanDrop();
        if (arcanaChest) items = -1;
        else if (roll < p5) items = 5;
        else if (roll < p5 + p3) items = 3;
        else
        {
            mfChestRng = DSP022StageGeometry.NextSpawnRng(mfChestRng);
            if ((mfChestRng & 0x7fffffff) % 100 < p1) items = 1;
        }
        if (items >= 0 && ArcanaOwned(DSArcana.GAME_KILLER) && items < 3) items = 3;   // Game Killer: chests hold 3+ items
        if (items == 0)
        {
            Console.Printf("DS_MF_BOSS_CHEST tic=%d boss_index=%d dropped=0", tic, bossIndex);
            return;
        }
        MFPlaceChest(items, bossIndex, deathX, deathY);
    }

    // Automated runs only: ds_debug_chest_tics (comma-separated tics) drops a
    // 1-item chest at the player, so chest evolutions can be checked without
    // waiting for a boss. Ignored in manual play.
    void MFDebugChests()
    {
        if (configuredMode == "manual") return;
        CVar list = CVar.FindCVar("ds_debug_chest_tics");
        if (list == null || list.GetString() == "") return;
        Array<String> parts;
        list.GetString().Split(parts, ",", TOK_SKIPEMPTY);
        for (int i = 0; i < parts.Size(); i++)
            if (parts[i].ToInt() == tic) MFPlaceChest(1, -1, playerX, playerY);
    }

    void MFPlaceChest(int items, int bossIndex, double deathX, double deathY)
    {
        // The deterministic soak bot cannot steer, so its chests appear at
        // the player (automation aid only).
        bool atPlayer = configuredMode == "soak_n2";
        int cx = atPlayer ? int(playerX) : int(deathX);
        int cy = atPlayer ? int(playerY) : int(deathY);
        int chestId = MFSpawnChestAt(items, cx, cy);
        if (chestId == 0)
        {
            Console.Printf("DS_MF_BOSS_CHEST tic=%d boss_index=%d dropped=0 reason=RECORD_REJECTED", tic, bossIndex);
            return;
        }
        Console.Printf("DS_N2_INTERIM_CHEST_SPAWN accepted=1 id=%d tic=%d interval=0 x=%d y=%d items=%d boss_index=%d classification=MAD_FOREST_BOSS_CHEST", chestId, tic, cx, cy, items, bossIndex);
    }

    // A chest holding items (-1 = an Arcana chest) at a spot; returns its
    // stable id, or 0 when the chest record is rejected. Also used by The
    // Depths' treasure rooms.
    int MFSpawnChestAt(int items, int cx, int cy)
    {
        mfChestSeq++;
        int chestId = runGeneration * 100000 + 80000 + mfChestSeq;
        if (!DSP032SpawnChestRecord(chestId, DSP032_CHEST_SILVER, 1, 1, tic, 1, true, cx, cy, 28)) return 0;
        mfChestIds.Push(chestId); mfChestItems.Push(items);
        DSP032Map16ChestProxy chest = DSP032Map16ChestProxy(Actor.Spawn(
            "DSP032Map16ChestProxy", (cx, cy, 0.0), NO_REPLACE));
        if (chest != null)
        {
            chest.chestStableId = chestId;
            if (items < 0) chest.sprite = Actor.GetSpriteIndex("CHSR");
        }
        return chestId;
    }

    void MFMaintainChests()
    {
        for (int i = mfChestIds.Size() - 1; i >= 0; i--)
        {
            int chestId = mfChestIds[i];
            if (!DSP032ChestWithinPickupRange(chestId, int(playerX), int(playerY))) continue;
            int items = mfChestItems[i];
            mfChestIds.Delete(i); mfChestItems.Delete(i);
            if (!DSP032PickUpChest(chestId, int(playerX), int(playerY))) continue;
            if (items < 0)
            {
                Sfx(DSSfx.CHEST);
                DSP032RecordChestReward(chestId, 0, chestId);
                DSP032CompleteChest(chestId);
                DestroyP032ChestProxy(chestId);
                OpenArcanaPick("ARCANA_CHEST");
                return;
            }
            // First item: evolution if eligible, else a rank-up. Extra items
            // are rank-ups (approximation of the original's extra rewards).
            // A chest that evolves a weapon plays the evolution stinger instead of the
            // chest sound (N2OpenInterimChest), so the two do not mask each other.
            int evolutionsBefore = n2EvolutionAppliedCount;
            bool soleGift = MFTrySole();
            if (!soleGift) N2OpenInterimChest(chestId);
            if (n2EvolutionAppliedCount == evolutionsBefore && !soleGift) Sfx(DSSfx.CHEST);
            bool maxedOut = false;
            for (int n = 1; n < items; n++)
            {
                int system;
                bool accepted = N2RankUpLowestWeapon(chestId, system);
                if (!accepted) maxedOut = true;
                Console.Printf("DS_MF_CHEST_EXTRA chest=%d item=%d system=%d accepted=%d", chestId, n + 1, system, accepted);
            }
            if (items <= 1) maxedOut = !N2CanRankUpAny();
            MFTryCandybox2(items, maxedOut);
        }
    }

    // One destructible spawn attempt per stage interval, just off-screen; the
    // stage's chance is multiplied by Luck up to its cap. At the stage's
    // light-source cap the oldest one is replaced.
    void MFTrySpawnBrazier()
    {
        int luck = rsActive ? rsLuckMilli : 1000;
        int chance = min(DSStage.LightChancePermille(mfStage) * luck / 1000,
            DSStage.LightChanceMaxPct(mfStage) * 10);
        mfLootRng = DSP022StageGeometry.NextSpawnRng(mfLootRng);
        if ((mfLootRng & 0x7fffffff) % 1000 >= chance) return;
        int count = 0; int oldest = -1;
        for (int slot = 0; slot < lifeStates.Size(); slot++)
        {
            if (lifeStates[slot] != STORE_ALIVE || kinds[slot] != KIND_ENEMY
                || !MFValid(slot) || mfTypes[slot] != MF_BRAZIER_TYPE) continue;
            count++;
            if (oldest < 0 || ids[slot] < ids[oldest]) oldest = slot;
        }
        if (count >= DSStage.LightMax(mfStage) && oldest >= 0)
        {
            mfStable[oldest] = 0;
            DestroyParts(oldest, generations[oldest], ids[oldest]);
        }
        double sx; double sy; MFPlace(sx, sy);
        // Light sources stay near: undo most of the spawn scaling.
        sx = playerX + (sx - playerX) * 2.5 / MF_SPAWN_SCALE;
        sy = playerY + (sy - playerY) * 2.5 / MF_SPAWN_SCALE;
        if (dgActive) DgPlace(3, 7, sx, sy);
        int slot = MFSpawn(MF_BRAZIER_TYPE, sx, sy, 2, 0.0, 0.0, 0, 0);
        if (slot >= 0) collisionRadii[slot] = 4.0;
    }

    // Wiki light-source weights x2.
    static int MFLootWeight(int kind, int level)
    {
        if (kind == MF_ITEM_COIN) return 100;
        if (kind == MF_ITEM_COIN_BAG) return 20;
        if (kind == MF_ITEM_RICH_BAG) return level >= 5 ? 2 : 0;
        if (kind == MF_ITEM_CHICKEN) return 24;
        if (kind == MF_ITEM_ROSARY) return level >= 8 ? 2 : 0;
        if (kind == MF_ITEM_OROLOGION) return level >= 4 ? 4 : 0;
        if (kind == MF_ITEM_VACUUM) return level >= 12 ? 4 : 0;
        // Wiki rarities x2 and player-level gates.
        if (kind == MF_ITEM_LITTLE_CLOVER) return 1;
        if (kind == MF_ITEM_NDUJA) return 2;
        if (kind == MF_ITEM_GILDED_CLOVER) return level >= 30 ? 2 : 0;
        if (kind == MF_ITEM_REROLLO) return 2;
        if (kind == MF_ITEM_SORBETTO) return 0;   // only with Out of Bounds
        return 0;   // Gold Finger has its own rare roll (MFDropLightSourceItem)
    }

    static String MFItemName(int kind)
    {
        if (kind == MF_ITEM_COIN) return "GOLD_COIN";
        if (kind == MF_ITEM_COIN_BAG) return "COIN_BAG";
        if (kind == MF_ITEM_RICH_BAG) return "RICH_COIN_BAG";
        if (kind == MF_ITEM_CHICKEN) return "FLOOR_CHICKEN";
        if (kind == MF_ITEM_ROSARY) return "ROSARY";
        if (kind == MF_ITEM_OROLOGION) return "OROLOGION";
        if (kind == MF_ITEM_VACUUM) return "VACUUM";
        if (kind == MF_ITEM_LITTLE_CLOVER) return "LITTLE_CLOVER";
        if (kind == MF_ITEM_NDUJA) return "NDUJA_FRITTA_TANTO";
        if (kind == MF_ITEM_GILDED_CLOVER) return "GILDED_CLOVER";
        if (kind == MF_ITEM_REROLLO) return "REROLLO";
        if (kind == MF_ITEM_SORBETTO) return "SORBETTO";
        if (kind == MF_ITEM_GOLD_FINGER) return "GOLD_FINGER";
        return "UNKNOWN";
    }

    void MFDropLightSourceItem(double dropX, double dropY)
    {
        int total = 0;
        for (int kind = 1; kind <= MF_ITEM_LAST; kind++) total += MFStageLootWeight(kind);
        mfLootRng = DSP022StageGeometry.NextSpawnRng(mfLootRng);
        int roll = (mfLootRng & 0x7fffffff) % max(1, total);
        int chosen = MF_ITEM_COIN;
        for (int kind = 1; kind <= MF_ITEM_LAST; kind++)
        {
            roll -= MFStageLootWeight(kind);
            if (roll < 0) { chosen = kind; break; }
        }
        // Gold Finger: the original's rarity 0.02 against ~80 for the rest,
        // from player level 30 (no coins-only stages).
        mfLootRng = DSP022StageGeometry.NextSpawnRng(mfLootRng);
        if (playerLevel >= 30 && !DSStage.CoinsOnly(mfStage) && (mfLootRng & 0x7fffffff) % 100000 < 25)
            chosen = MF_ITEM_GOLD_FINGER;
        mfItemSeq++;
        mfItemIds.Push(mfItemSeq); mfItemKinds.Push(chosen);
        mfItemX.Push(dropX); mfItemY.Push(dropY);
        Console.Printf("DS_MF_ITEM_DROP tic=%d id=%d item=%s level=%d", tic, mfItemSeq, MFItemName(chosen), playerLevel);
    }

    // A gold coin on the floor (Vicious Hunger turning an enemy into gold).
    void MFDropCoin(double dropX, double dropY)
    {
        mfItemSeq++;
        mfItemIds.Push(mfItemSeq); mfItemKinds.Push(MF_ITEM_COIN);
        mfItemX.Push(dropX); mfItemY.Push(dropY);
    }

    // Coins-only stages (The Bone Zone) drop just coins and coin bags.
    int MFStageLootWeight(int kind)
    {
        if (DSStage.CoinsOnly(mfStage) && kind != MF_ITEM_COIN && kind != MF_ITEM_COIN_BAG) return 0;
        // Bat Country: no Orologion or Nduja Fritta from light sources.
        if (mfStage == DSStage.BATCOUNTRY && (kind == MF_ITEM_OROLOGION || kind == MF_ITEM_NDUJA)) return 0;
        int w = MFLootWeight(kind, playerLevel);
        if (kind == MF_ITEM_OROLOGION && ArcanaOwned(DSArcana.OUT_OF_BOUNDS)) w *= 2;
        if (kind == MF_ITEM_SORBETTO && ArcanaOwned(DSArcana.OUT_OF_BOUNDS)) w = 2;
        if (kind == MF_ITEM_NDUJA && ArcanaOwned(DSArcana.HEART_OF_FIRE)) w *= 4;
        return w;
    }

    // Gold Fever: while it runs, kills drop a 0.5 gold coin 75% of the time.
    void MFOnKillGold()
    {
        if (mfFeverTics <= 0 || !rsActive) return;
        spawnRng = DSP022StageGeometry.NextSpawnRng(spawnRng);
        if ((spawnRng & 0x7fffffff) % 100 >= 75) return;
        int before = mfGold;
        mfGoldMilli += 500 * ModeGreedMilli() / 1000 * DSStage.GreedMilli(mfStage) / 1000;
        mfGold = mfGoldMilli / 1000;
        if (mfGold > before) ArcanaOnGold(mfGold - before);
        mfFeverTics = min(350 * (100 + rsFeverPct) / 100, mfFeverTics + 1);
    }

    // Nduja Fritta Tanto (fire, grows as it travels) and Sorbetto (ice, freezes):
    // a cone in front of the player every few tics. Damage values are guesses.
    void MFProcessBreath()
    {
        if (mfFeverTics > 0) { mfFeverTics--; if (mfFeverTics == 0) Sfx(DSSfx.I_FEVER_END); }
        if (tic >= mfBreathUntil || players[0].mo == null || tic % 4 != 0) return;
        bool fire = mfBreathKind == MF_ITEM_NDUJA;
        Sfx(fire ? DSSfx.W_NDUJA_BREATH : DSSfx.W_SORBETTO_BREATH, 12);
        double yaw = players[0].mo.Angle;
        double reach = 110.0 * RsAreaFor(0) / 1000.0 * (1.0 + 1.0 * (tic - mfBreathStart) / 350.0);
        int damage = (fire ? 22000 : 12000) * rsMightMilli / 1000;
        int dirs = ArcanaOwned(DSArcana.GEMINI) ? 2 : 1;
        for (int d = 0; d < dirs; d++)
        {
            double a0 = yaw + d * 180.0;
            Array<int> near;
            GwEnemiesNear(playerX, playerY, reach, near);
            for (int j = 0; j < near.Size(); j++)
            {
                int slot = near[j];
                if (!ValidParts(slot, generations[slot], ids[slot])) continue;
                double dx = x[slot] - playerX; double dy = y[slot] - playerY;
                double diff = abs(Actor.deltaangle(a0, atan2(dy, dx)));
                if (diff > 32.0) continue;
                GwHit(slot, damage, 0);
                if (!fire && ValidParts(slot, generations[slot], ids[slot]) && !GwIsBoss(slot)) GwFreeze(slot, tic + 35);
            }
            for (int f = 1; f <= 3; f++)
            {
                double fr = reach * f / 3.0;
                DSWeaponFx.Burst("WFLM", playerX + cos(a0) * fr, playerY + sin(a0) * fr, 24.0, 14.0 + 10.0 * f, 40.0 + 10.0 * f, false,
                    fire ? Color(255, 120, 30) : Color(150, 215, 255), 6);
            }
        }
    }

    void MFProcessItems()
    {
        MFProcessBreath();
        for (int i = mfItemIds.Size() - 1; i >= 0; i--)
        {
            double dx = playerX - mfItemX[i]; double dy = playerY - mfItemY[i];
            double distance = sqrt(dx * dx + dy * dy);
            if (distance > COLLECT_RADIUS && distance <= AttractRadius())
            {
                double amount = PICKUP_SPEED < distance ? PICKUP_SPEED : distance;
                mfItemX[i] += dx / distance * amount; mfItemY[i] += dy / distance * amount;
                dx = playerX - mfItemX[i]; dy = playerY - mfItemY[i];
                distance = sqrt(dx * dx + dy * dy);
            }
            if (distance > COLLECT_RADIUS) continue;
            int kind = mfItemKinds[i]; int id = mfItemIds[i];
            mfItemIds.Delete(i); mfItemKinds.Delete(i); mfItemX.Delete(i); mfItemY.Delete(i);
            MFApplyItem(kind, id);
            if (runState != STATE_ACTIVE) return;
        }
        if (mfVacuumActive) MFPullVacuumedGems();
    }

    void MFApplyItem(int kind, int id)
    {
        MetaCountPickup(kind);
        int effect = 0;
        if (kind == MF_ITEM_COIN) effect = MFAddGold(1);
        else if (kind == MF_ITEM_COIN_BAG) effect = MFAddGold(10);
        else if (kind == MF_ITEM_RICH_BAG) effect = MFAddGold(100);
        if (kind == MF_ITEM_COIN || kind == MF_ITEM_COIN_BAG || kind == MF_ITEM_RICH_BAG)
        {
            ArcanaOnGold(effect); Sfx(DSSfx.ForItem(kind), 2);
            // Big Trouble: picking up gold fires his Unearthly Bolt.
            if (rsActive && rsCharacter == DSCharacters.TROUBLER)
            {
                int bolt = N2Find(DSN2Catalog.ID_N3_UNEARTHLY_BOLT);
                if (bolt >= 0) { GwFire(DSN2Catalog.ID_N3_UNEARTHLY_BOLT, n2Rank[bolt]); FxCount("gold_bolt"); }
            }
            if (mfFeverTics > 0) mfFeverTics = min(350 * (100 + rsFeverPct) / 100, mfFeverTics + (kind == MF_ITEM_COIN ? 17 : (kind == MF_ITEM_COIN_BAG ? 175 : 350)));
        }
        else if (kind == MF_ITEM_CHICKEN)
        {
            Sfx(DSSfx.HEAL);
            // Wiki: heals 30 HP, through the shared healing authority.
            int healthAfter; int appliedMilli;
            DSP039ApplyHeal(SOURCE_FLOOR_CHICKEN, 30000, tic, runState == STATE_ACTIVE,
                playerHealth, CurrentPlayerHealthCap(), healthAfter, appliedMilli);
            playerHealth = healthAfter;
            health[playerSlot] = playerHealth;
            effect = appliedMilli;
        }
        else if (kind == MF_ITEM_ROSARY)
        {
            // Holy Forbidden's Rosary: the stage ends 30 s later.
            if (id == hfRosaryId && hfRosaryId > 0 && hfEndTic == 0)
            {
                hfEndTic = tic + 1050;
                GmShowToast("The Rosary glows. Hold on for 30 seconds!");
            }
            // Kills every ordinary enemy on screen; bosses, the Reaper and
            // light sources are left alone (approximation of immunity).
            Sfx(DSSfx.I_ROSARY);
            for (int slot = 0; slot < lifeStates.Size(); slot++)
            {
                if (lifeStates[slot] != STORE_ALIVE || kinds[slot] != KIND_ENEMY
                    || !MFValid(slot) || MFIsProp(mfTypes[slot])
                    || DSStage.IsReaperLike(mfTypes[slot])
                    || MFResists(slot, MF_RESIST_ROSARY)) continue;
                double dx = x[slot] - playerX; double dy = y[slot] - playerY;
                if (dx * dx + dy * dy > MF_ROSARY_RADIUS * MF_ROSARY_RADIUS) continue;
                HandleEnemyDeath(slot, health[slot], 0);
                effect++;
            }
        }
        else if (kind == MF_ITEM_OROLOGION)
        {
            Sfx(DSSfx.FREEZE);
            mfFreezeStart = tic; mfFreezeUntil = tic + MF_FREEZE_TICS; effect = MF_FREEZE_TICS;
            if (ArcanaOwned(DSArcana.OUT_OF_BOUNDS))
            {
                Array<int> frozen;
                GwEnemiesNear(playerX, playerY, 360.0, frozen);
                for (int fz = 0; fz < frozen.Size() && fz < 12; fz++)
                    if (ValidParts(frozen[fz], generations[frozen[fz]], ids[frozen[fz]])) ArcanaOnFreeze(x[frozen[fz]], y[frozen[fz]]);
            }
        }
        else if (kind == MF_ITEM_LITTLE_CLOVER)
        {
            mfClovers++; effect = 100; Sfx(DSSfx.I_LITTLE_CLOVER);
            RecomputeRunStats();
        }
        else if (kind == MF_ITEM_REROLLO)
        {
            dsp031RerollsRemaining++; effect = 1; Sfx(DSSfx.I_REROLLO);
            PublishLevelUpCharges();
        }
        else if (kind == MF_ITEM_NDUJA || kind == MF_ITEM_SORBETTO)
        {
            // Temporary weapon: 10 s of breath in front of the player.
            mfBreathKind = kind; mfBreathStart = tic;
            mfBreathUntil = tic + int(350 * rsDurationMilli / 1000);
            effect = mfBreathUntil - tic;
            Sfx(kind == MF_ITEM_NDUJA ? DSSfx.I_NDUJA : DSSfx.I_SORBETTO, 4);
        }
        else if (kind == MF_ITEM_GOLD_FINGER)
        {
            // Gold Finger: 10 s of invulnerability and minimum Cooldown; every
            // enemy defeated meanwhile pays 1 gold at the end (prize guessed).
            mfGoldFingerUntil = tic + 350; mfGoldFingerKills = kills;
            playerInvulnerableUntil = max(playerInvulnerableUntil, mfGoldFingerUntil);
            RecomputeRunStats();
            effect = 350; Sfx(DSSfx.I_GILDED_CLOVER);
            GmShowToast("Gold Finger!");
        }
        else if (kind == MF_ITEM_GILDED_CLOVER)
        {
            // Pulls every coin on the ground in and starts Gold Fever (10 s).
            for (int g = 0; g < mfItemKinds.Size(); g++)
                if (mfItemKinds[g] == MF_ITEM_COIN || mfItemKinds[g] == MF_ITEM_COIN_BAG || mfItemKinds[g] == MF_ITEM_RICH_BAG)
                { mfItemX[g] = playerX; mfItemY[g] = playerY; effect++; }
            mfFeverTics = 350 * (100 + rsFeverPct) / 100; Sfx(DSSfx.I_GILDED_CLOVER);
        }
        else if (kind == MF_ITEM_VACUUM)
        {
            // id 0 is a Mad Groove / automation vacuum, which stays silent.
            if (id > 0) Sfx(DSSfx.I_VACUUM);
            for (int slot = 0; slot < lifeStates.Size(); slot++)
            {
                if (!DSP027IsLivePickup(slot)) continue;
                if (DSP027ForceAttract(slot, generations[slot], ids[slot])) effect++;
            }
            mfVacuumActive = effect > 0;
        }
        Console.Printf("DS_MF_ITEM_COLLECT tic=%d id=%d item=%s effect=%d gold=%d health=%d", tic, id, MFItemName(kind), effect, mfGold, playerHealth);
    }

    // Vacuumed gems outside the normal attract radius fly in; the existing
    // P027 path collects them once they are close.
    void MFPullVacuumedGems()
    {
        bool any = false;
        for (int slot = 0; slot < lifeStates.Size(); slot++)
        {
            if (!DSP027IsLivePickup(slot) || experienceStates[slot] != DSP027_ATTRACTING) continue;
            double dx = playerX - x[slot]; double dy = playerY - y[slot];
            double distance = sqrt(dx * dx + dy * dy);
            if (distance <= AttractRadius()) { any = true; continue; }
            double amount = PICKUP_SPEED * 2.0;
            x[slot] += dx / distance * amount; y[slot] += dy / distance * amount;
            any = true;
        }
        mfVacuumActive = any;
    }

    void MFSyncItemProxies()
    {
        Array<int> seen;
        for (int i = 0; i < mfItemIds.Size(); i++) seen.Push(0);
        ThinkerIterator it = ThinkerIterator.Create("DSMFItemProxy");
        Actor actor;
        while ((actor = Actor(it.Next())) != null)
        {
            DSMFItemProxy proxy = DSMFItemProxy(actor);
            int index = mfItemIds.Find(proxy.itemId);
            if (index >= mfItemIds.Size() || seen[index] != 0) { actor.Destroy(); continue; }
            seen[index] = 1;
            proxy.SetOrigin((mfItemX[index], mfItemY[index], 2.0), true);
        }
        for (int i = 0; i < mfItemIds.Size(); i++)
        {
            if (seen[i] != 0) continue;
            DSMFItemProxy created = DSMFItemProxy(Actor.Spawn("DSMFItemProxy",
                (mfItemX[i], mfItemY[i], 2.0), NO_REPLACE));
            if (created == null) continue;
            created.itemId = mfItemIds[i];
            int kind = mfItemKinds[i];
            created.sprite = Actor.GetSpriteIndex(MFItemSprite(kind));
            created.A_SetScale(kind == MF_ITEM_COIN ? 0.45 : 0.6);
        }
    }

    static String MFItemSprite(int kind)
    {
        if (kind == MF_ITEM_COIN) return "ICOI";
        if (kind == MF_ITEM_COIN_BAG) return "IBAG";
        if (kind == MF_ITEM_RICH_BAG) return "IRIC";
        if (kind == MF_ITEM_CHICKEN) return "ICHK";
        if (kind == MF_ITEM_ROSARY) return "IROS";
        if (kind == MF_ITEM_OROLOGION) return "IORO";
        if (kind == MF_ITEM_LITTLE_CLOVER) return "ICLV";
        if (kind == MF_ITEM_NDUJA) return "INDJ";
        if (kind == MF_ITEM_GILDED_CLOVER) return "IGLC";
        if (kind == MF_ITEM_REROLLO) return "IRRL";
        if (kind == MF_ITEM_SORBETTO) return "ISRB";
        if (kind == MF_ITEM_GOLD_FINGER) return "IGLC";
        return "IVAC";
    }

    static Color MFItemColor(int kind)
    {
        if (kind == MF_ITEM_COIN) return Color(255, 255, 215, 40);
        if (kind == MF_ITEM_COIN_BAG) return Color(255, 215, 160, 40);
        if (kind == MF_ITEM_RICH_BAG) return Color(255, 255, 245, 140);
        if (kind == MF_ITEM_CHICKEN) return Color(255, 235, 120, 80);
        if (kind == MF_ITEM_ROSARY) return Color(255, 120, 170, 255);
        if (kind == MF_ITEM_OROLOGION) return Color(255, 210, 230, 255);
        if (kind == MF_ITEM_VACUUM) return Color(255, 180, 90, 235);
        if (kind == MF_ITEM_LITTLE_CLOVER) return Color(255, 90, 230, 110);
        if (kind == MF_ITEM_NDUJA) return Color(255, 255, 110, 40);
        if (kind == MF_ITEM_GILDED_CLOVER) return Color(255, 255, 215, 70);
        if (kind == MF_ITEM_REROLLO) return Color(255, 90, 220, 255);
        if (kind == MF_ITEM_SORBETTO) return Color(255, 170, 225, 255);
        if (kind == MF_ITEM_GOLD_FINGER) return Color(255, 255, 190, 20);
        return Color(255, 255, 255, 255);
    }

    static Color MFFamilyColor(int family)
    {
        if (family == 1) return Color(255, 150, 60, 200);   // bats
        if (family == 2) return Color(255, 90, 170, 70);    // zombies
        if (family == 3) return Color(255, 235, 235, 220);  // skeletons
        if (family == 4) return Color(255, 150, 210, 255);  // ghosts
        if (family == 5) return Color(255, 150, 100, 50);   // mudmen
        if (family == 6) return Color(255, 120, 120, 130);  // werewolves
        if (family == 7) return Color(255, 110, 230, 90);   // mantis
        if (family == 8) return Color(255, 225, 205, 150);  // mummies
        if (family == 9) return Color(255, 255, 110, 190);  // flowers
        if (family == 10) return Color(255, 20, 20, 20);    // the Reaper
        return Color(255, 255, 255, 255);
    }

    // Greed with the run mode's reward bonus (Hyper x1.7, Inverse x1.5).
    int ModeGreedMilli() { return rsMode == 1 ? rsGreedMilli * (1000 + DSStage.HyperGoldMilli(mfStage)) / 1000 : (rsMode == 2 ? rsGreedMilli * 2 : rsGreedMilli); }

    // Adds picked-up gold with Greed, keeping the fractional part.
    int MFAddGold(int amount)
    {
        int before = mfGold;
        mfGoldMilli += amount * (rsActive ? ModeGreedMilli() * DSStage.GreedMilli(mfStage) / 1000 : 1000);
        mfGold = mfGoldMilli / 1000;
        return mfGold - before;
    }
}
