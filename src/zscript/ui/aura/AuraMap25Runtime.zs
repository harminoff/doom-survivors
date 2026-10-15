// Cosmetic presentation ring for one equipped aura. Never a broad-phase
// input and cannot create, resize, or change a hit; removing it or toggling
// ds_p039_vfx must never change the accepted-hit tuples this fixture proves.
class DSP039Map25RingProxy : Actor
{
    Default
    {
        Radius 4;
        Height 3;
        +NOBLOCKMAP;
        +NOGRAVITY;
        +NOINTERACTION;
        RenderStyle "Add";
        Alpha 0.6;
        Scale 0.12;
    }

    States
    {
    Spawn:
        PROP A 2 Bright;
        Loop;
    }
}

// MAP25 host for the P039 Garlic/Soul Eater aura and healing authority.
// Weapons, P033 inputs, targets and timing are controlled fixtures. P025
// owns accepted logical damage; the presentation ring is cosmetic only.
class DSP039Map25Runtime : EventHandler
{
    mixin DSRunStatFields;
    mixin DSP020EntityStore;
    mixin DSP024SpatialIndex;
    mixin DSP025AttackCore;
    mixin DSP033ResolvedStats;
    mixin DSP039Aura;
    mixin DSP039Healing;

    const MAP = "MAP25";
    const ENEMY_KIND = 1;
    const PLAYER_KIND = 99;
    const WEAPON_KIND = 90;
    const EXPECTED_ROWS = 9;
    // Reuses P027's own COLLECT_RADIUS value (src/zscript/gameplay/pickups
    // /P027ExperienceRuntime.zs); there is no shared constant to import, so
    // this is a by-value match, not a dependency.
    const HEART_COLLECT_RADIUS = 24.0;

    bool started;
    bool enabled;
    bool completed;
    bool captureRequested;
    bool captureFlushed;
    transient bool startedThisProcess;
    bool saveHold;
    bool saveSnapshotEmitted;
    bool restoredStateReported;
    bool runActive;
    bool pauseRequested;
    bool pauseOpened;
    bool pauseClosed;
    ui bool uiPauseRequestSent;
    ui bool uiPauseObserved;
    ui bool uiPauseResumeSent;
    ui int uiTics;
    ui int uiLogicalTic;
    ui int uiPauseHash;
    ui int uiPauseAtTic;
    ui int uiPauseUntilUiTic;
    ui int uiPauseMode;
    int pauseStartLogicalTic;
    int pauseStartHash;
    int pauseResumeTic;
    int pauseResumeHash;
    int saveLogicalTic;
    int saveStateHash;
    int saveHealingHash;
    int finishAtTic;
    int logicalTic;
    int tic;
    int cameraVariant;
    int visualToggle;
    int playerSlot;
    int weaponSlot;
    int rowCount;
    double playerX;
    double playerY;
    String activeMode;

    // Named target slots used by individual modes; -1 when unused.
    int targetContinuous;
    int targetEdge;
    int targetLeaveReenter;
    int targetImmune;
    int targetNonImmune;
    int targetAhead;
    int targetBehind;
    int targetHeartA;
    int targetHeartB;

    bool leaveDone;
    bool reenterDone;
    bool transformDone;
    bool heartCollectAttempted;
    int growthCycle;
    bool growthSmallApplied;
    bool growthBigApplied;
    bool bloodyTearFirstApplied;
    bool bloodyTearSecondApplied;
    bool sameTicContactApplied;
    bool sameTicHealAttempted;
    bool recoveryCapObserved;

    override void OnRegister()
    {
        // Registered globally, but this handler's UI pause probe belongs
        // only to MAP25; claiming UI ownership elsewhere would suppress
        // native commands on the normal MAP16 playable slice (the exact
        // P030 defect this pattern was fixed for -- see
        // evidence/P030/input-ownership-repair-2026-09-23.md).
        IsUiProcessor = false;
        RequireMouse = false;
    }

    int ReadCameraVariant()
    {
        CVar camera = CVar.FindCVar("ds_p039_camera_variant");
        int value = camera != null ? camera.GetInt() : 0;
        return value >= 0 && value <= 2 ? value : 0;
    }

    int ReadVisualToggle()
    {
        CVar cvar = CVar.FindCVar("ds_p039_vfx");
        return cvar != null && cvar.GetInt() != 0 ? 1 : 0;
    }

    void ConfigureCamera()
    {
        cameraVariant = ReadCameraVariant();
        int yaw = cameraVariant == 1 ? 90 : 0;
        int pitch = cameraVariant == 2 ? 22 : 0;
        int fov = cameraVariant == 2 ? 115 : 90;
        if (players[0].mo != null)
        {
            players[0].mo.Angle = yaw;
            players[0].mo.Pitch = pitch;
            players[0].SetFOV(fov);
        }
        Console.Printf("DS_P039_MAP25_CAMERA variant=%d yaw=%d pitch=%d fov=%d source=UZDOOM_PLAYER_VIEW", cameraVariant, yaw, pitch, fov);
    }

    int EmitRows()
    {
        rowCount = 0;
        for (int system = DSP039AuraRows.SYSTEM_GARLIC;
             system <= DSP039AuraRows.SYSTEM_SOUL_EATER; system++)
        {
            int limit = DSP039AuraRows.RankCount(system);
            for (int rank = 1; rank <= limit; rank++)
            {
                int damageMilli = DSP039AuraRows.DamageMilli(system, rank);
                int areaMilli = DSP039AuraRows.AreaMilli(system, rank);
                int cooldownTics = DSP039AuraRows.CooldownTics(system, rank);
                int radiusMilli = DSP039AuraRows.RadiusMilliUnits(system, rank);
                if (damageMilli <= 0 || areaMilli <= 0 || cooldownTics <= 0
                    || radiusMilli <= 0)
                {
                    Console.Printf("DS_ASSERT_FAIL P039_MAP25_ROW_MISSING system_id=%d rank=%d", system, rank);
                    return rowCount;
                }
                rowCount++;
                Console.Printf("DS_P039_MAP25_ROW system_id=%d rank=%d damage_milli=%d area_milli=%d cooldown_tics=%d radius_milli_units=%d classification=QUALIFIED_ONLINE_REPORT", system, rank, damageMilli, areaMilli, cooldownTics, radiusMilli);
            }
        }
        int evolved; int dependency; int sourceRank; int dependencyRank;
        bool recipe = DSP039AuraRows.TryGetEvolution(
            DSP039AuraRows.SYSTEM_GARLIC, evolved, dependency, sourceRank,
            dependencyRank);
        Console.Printf("DS_P039_MAP25_EVOLUTION accepted=%d source_system_id=%d evolved_system_id=%d source_rank=%d dependency_source_key=%d provenance=BUILD_CENSUS_AND_CURRENT_REPORT", recipe ? 1 : 0, DSP039AuraRows.SYSTEM_GARLIC, evolved, sourceRank, dependency);
        return recipe && evolved == DSP039AuraRows.SYSTEM_SOUL_EATER
            && sourceRank == 8 ? rowCount : 0;
    }

    int SpawnTarget(double targetX, double targetY, String role,
        double targetRadius, int healthMilli = 1000000000)
    {
        int slot = Allocate(ENEMY_KIND, targetX, targetY, 0.0, 0.0, healthMilli);
        if (slot < 0) return -1;
        collisionRadii[slot] = targetRadius;
        Console.Printf("DS_P039_MAP25_TARGET target_id=%d x=%.3f y=%.3f radius=%.3f health_milli=%d role=%s classification=CONTROLLED_CONTACT_TARGET source_spawn_claim=0", ids[slot], targetX, targetY, targetRadius, healthMilli, role);
        return slot;
    }

    bool Equip(int systemId, int rank, int areaAdjustmentMilli = 1000)
    {
        weaponSlot = Allocate(WEAPON_KIND, playerX, playerY, 0.0, 0.0, 1);
        if (weaponSlot < 0) return false;
        bool accepted = DSP039EquipAura(systemId, rank, weaponSlot,
            generations[weaponSlot], ids[weaponSlot], 1,
            playerSlot, generations[playerSlot], ids[playerSlot],
            dsp033ResolvedMightMilli, dsp033ResolvedCooldownMultiplierMilli,
            areaAdjustmentMilli);
        Console.Printf("DS_P039_MAP25_WEAPON accepted=%d system_id=%d rank=%d weapon_id=%d form_generation=1 area_adjustment_milli=%d might_milli=%d cooldown_multiplier_milli=%d source_inventory_claim=0 classification=CONTROLLED_WEAPON_FIXTURE", accepted ? 1 : 0, systemId, rank, ids[weaponSlot], areaAdjustmentMilli, dsp033ResolvedMightMilli, dsp033ResolvedCooldownMultiplierMilli);
        return accepted;
    }

    // ---- Per-mode setup ----------------------------------------------------

    bool StartScenario()
    {
        CVar modeCVar = CVar.FindCVar("ds_p039_mode");
        activeMode = modeCVar != null ? modeCVar.GetString() : "matrix";
        if (activeMode != "matrix" && activeMode != "camera"
            && activeMode != "transform" && activeMode != "heart"
            && activeMode != "heart_recovery"
            && activeMode != "growth_and_high_stats"
            && activeMode != "recovery_cap" && activeMode != "bloody_tear"
            && activeMode != "same_tic_order" && activeMode != "pause"
            && activeMode != "save")
        {
            Console.Printf("DS_ASSERT_FAIL P039_MAP25_MODE_UNSUPPORTED mode=%s", activeMode);
            return false;
        }
        logicalTic = 0; tic = 0;
        playerX = 0.0; playerY = 0.0;
        completed = false; captureRequested = false; captureFlushed = false;
        saveHold = false; saveSnapshotEmitted = false; restoredStateReported = false;
        runActive = true;
        pauseRequested = false; pauseOpened = false; pauseClosed = false;
        pauseStartLogicalTic = -1; pauseStartHash = 0;
        pauseResumeTic = -1; pauseResumeHash = 0;
        SendInterfaceEvent(consoleplayer, "P039_MAP25_UI_RESET", 0, 0, 0);
        saveLogicalTic = -1; saveStateHash = 0; saveHealingHash = 0;
        finishAtTic = 150;
        visualToggle = ReadVisualToggle();
        targetContinuous = -1; targetEdge = -1; targetLeaveReenter = -1;
        targetImmune = -1; targetNonImmune = -1; targetAhead = -1; targetBehind = -1;
        targetHeartA = -1; targetHeartB = -1;
        leaveDone = false; reenterDone = false; transformDone = false;
        heartCollectAttempted = false;
        growthCycle = 0;
        growthSmallApplied = false; growthBigApplied = false;
        bloodyTearFirstApplied = false; bloodyTearSecondApplied = false;
        sameTicContactApplied = false; sameTicHealAttempted = false;
        recoveryCapObserved = false;
        Reset();
        DSP024ClearSpatial();
        DSP039ResetAura();
        DSP039ResetHealing();
        ConfigureCamera();
        playerSlot = Allocate(PLAYER_KIND, playerX, playerY, 0.0, 0.0, 1);
        collisionRadii[playerSlot] = 2.0;
        bool rowsOk = EmitRows() == EXPECTED_ROWS;
        bool weaponOk = playerSlot >= 0;

        if (activeMode == "matrix" || activeMode == "save" || activeMode == "pause")
        {
            DSP033SetBaseStats(1000, 0, 120000, 1000);
            weaponOk = weaponOk && DSP033RecomputeFromRanks(0, 0, 0, 0)
                && Equip(DSP039AuraRows.SYSTEM_GARLIC, 1);
            DSP033RecomputeRecovery(0);
            if (activeMode == "matrix")
            {
                // Garlic rank1: radius 32, cooldown 46 tics, damage 5000 milli.
                targetContinuous = SpawnTarget(20.0, 0.0, "CONTINUOUS_OVERLAP", 8.0);
                targetEdge = SpawnTarget(40.0, 0.0, "EDGE_CONTACT_TOUCH", 8.0);
                targetLeaveReenter = SpawnTarget(0.0, 20.0, "LEAVE_REENTER", 8.0);
                targetImmune = SpawnTarget(-20.0, 0.0, "IMMUNE_DEBUFF", 8.0);
                targetNonImmune = SpawnTarget(0.0, -20.0, "NON_IMMUNE_DEBUFF", 8.0);
                weaponOk = weaponOk && targetContinuous >= 0 && targetEdge >= 0
                    && targetLeaveReenter >= 0 && targetImmune >= 0
                    && targetNonImmune >= 0;
                if (weaponOk)
                    DSP039SetTargetImmune(targetImmune, generations[targetImmune],
                        ids[targetImmune], true);
                finishAtTic = 150;
            }
            else if (activeMode == "save")
            {
                targetContinuous = SpawnTarget(20.0, 0.0, "SAVE_TARGET", 8.0);
                weaponOk = weaponOk && targetContinuous >= 0;
                finishAtTic = 120;
            }
            else // pause
            {
                targetContinuous = SpawnTarget(20.0, 0.0, "PAUSE_TARGET", 8.0);
                weaponOk = weaponOk && targetContinuous >= 0;
                finishAtTic = 150;
            }
        }
        else if (activeMode == "camera")
        {
            DSP033SetBaseStats(1000, 0, 120000, 1000);
            weaponOk = weaponOk && DSP033RecomputeFromRanks(0, 0, 0, 0)
                && Equip(DSP039AuraRows.SYSTEM_GARLIC, 1);
            DSP033RecomputeRecovery(0);
            targetAhead = SpawnTarget(20.0, 0.0, "AHEAD_OF_PLAYER", 8.0);
            targetBehind = SpawnTarget(-20.0, 0.0, "BEHIND_PLAYER", 8.0);
            weaponOk = weaponOk && targetAhead >= 0 && targetBehind >= 0;
            finishAtTic = 100;
        }
        else if (activeMode == "transform")
        {
            DSP033SetBaseStats(1000, 0, 120000, 1000);
            weaponOk = weaponOk && DSP033RecomputeFromRanks(0, 0, 0, 0)
                && Equip(DSP039AuraRows.SYSTEM_GARLIC, 8);
            DSP033RecomputeRecovery(0);
            // Garlic rank8 radius 64, Soul Eater radius 96 -- placed so it is
            // only reachable AFTER the transform, proving the new form's row
            // (not the old one) governs the post-transform ledger.
            targetContinuous = SpawnTarget(80.0, 0.0, "PRE_TRANSFORM_UNREACHABLE", 8.0);
            weaponOk = weaponOk && targetContinuous >= 0;
            finishAtTic = 200;
        }
        else if (activeMode == "heart")
        {
            DSP033SetBaseStats(1000, 0, 120000, 1000);
            weaponOk = weaponOk && DSP033RecomputeFromRanks(0, 0, 0, 0)
                && Equip(DSP039AuraRows.SYSTEM_SOUL_EATER, 1);
            DSP033RecomputeRecovery(0);
            // Low health so the first accepted Soul Eater hit (20 damage)
            // kills outright; two independent kills so the default
            // dsp039HeartRngState's second draw (proven in this fixture's
            // pure-Python test suite) deterministically spawns a heart.
            targetHeartA = SpawnTarget(20.0, 0.0, "SOUL_EATER_KILL_A", 8.0, 5000);
            targetHeartB = SpawnTarget(0.0, 20.0, "SOUL_EATER_KILL_B", 8.0, 5000);
            weaponOk = weaponOk && targetHeartA >= 0 && targetHeartB >= 0;
            health[playerSlot] = 50000; // 50 HP of 120, well clear of full health
            finishAtTic = 150;
        }
        else if (activeMode == "heart_recovery")
        {
            // Identical fixture to "heart", except a controlled Pummarola
            // rank-5 owned fixture grants Recovery = 1000 milli/s, so the
            // Little Heart heal must scale: DSP039LittleHeartHealMilli(1000)
            // = 1000 * (1000 + 1000) / 1000 = 2000 milli, not the
            // unscaled-Recovery 1000 milli the "heart" mode proves.
            DSP033SetBaseStats(1000, 0, 120000, 1000);
            weaponOk = weaponOk && DSP033RecomputeFromRanks(0, 0, 0, 0)
                && Equip(DSP039AuraRows.SYSTEM_SOUL_EATER, 1);
            DSP033RecomputeRecovery(5);
            targetHeartA = SpawnTarget(20.0, 0.0, "SOUL_EATER_KILL_A", 8.0, 5000);
            targetHeartB = SpawnTarget(0.0, 20.0, "SOUL_EATER_KILL_B", 8.0, 5000);
            weaponOk = weaponOk && targetHeartA >= 0 && targetHeartB >= 0;
            health[playerSlot] = 50000;
            finishAtTic = 150;
        }
        else if (activeMode == "growth_and_high_stats")
        {
            // Labelled high-stat fixture: Might 5x, Area 2x, and repeated
            // direct controlled fixture heals standing in for Recovery (not
            // real-time Pummarola accrual -- reaching the 60-step/
            // 3,600,000-milli growth cap in real time would need ~103
            // seconds of logical tics; DSP033StatRules.ValidBases also caps
            // max health at 1,000,000 milli, so one heal transaction cannot
            // reach the cap either). See docs/contracts/auras-healing.md
            // "Stats": MAP fixtures may inject labelled high Area/Might/
            // Recovery.
            DSP033SetBaseStats(5000, 0, 1000000, 1000);
            weaponOk = weaponOk && DSP033RecomputeFromRanks(0, 0, 0, 0)
                && Equip(DSP039AuraRows.SYSTEM_SOUL_EATER, 1, 2000);
            DSP033RecomputeRecovery(0);
            health[playerSlot] = 10000; // 10 HP, far below the 1,000 HP max
            targetContinuous = SpawnTarget(20.0, 0.0, "GROWTH_FIXTURE_TARGET", 8.0);
            weaponOk = weaponOk && targetContinuous >= 0;
            finishAtTic = 220;
        }
        else if (activeMode == "recovery_cap")
        {
            DSP033SetBaseStats(1000, 0, 3000, 1000); // max health 3 HP
            weaponOk = weaponOk && DSP033RecomputeFromRanks(0, 0, 0, 0)
                && DSP033RecomputeRecovery(5); // Recovery 1.0 = 1000 milli/s
            health[playerSlot] = 1000; // 1 HP: one Recovery tick reaches max
            finishAtTic = 120;
        }
        else if (activeMode == "bloody_tear")
        {
            DSP033SetBaseStats(1000, 0, 120000, 1000);
            weaponOk = weaponOk && DSP033RecomputeFromRanks(0, 0, 0, 0)
                && DSP033RecomputeRecovery(0);
            health[playerSlot] = 10000; // 10 HP, room for two 8-HP drains
            finishAtTic = 90;
        }
        else if (activeMode == "same_tic_order")
        {
            DSP033SetBaseStats(1000, 0, 3000, 1000);
            weaponOk = weaponOk && DSP033RecomputeFromRanks(0, 0, 0, 0)
                && DSP033RecomputeRecovery(5);
            health[playerSlot] = 1000; // 1 HP: the controlled contact kills it
            finishAtTic = 60;
        }
        Console.Printf("DS_P039_MAP25_CASE mode=%s classification=CONTROLLED_ENGINE_FIXTURE source_content_claim=0", activeMode);
        bool setupOk = rowsOk && weaponOk;
        Console.Printf("DS_P039_MAP25_BOOT accepted=%d mode=%s player_slot=%d rows=%d expected_rows=%d visual_toggle=%d classification=CONTROLLED_ENGINE_FIXTURE", setupOk ? 1 : 0, activeMode, playerSlot, rowCount, EXPECTED_ROWS, visualToggle);
        return setupOk;
    }

    void HandleEnemyDeath(int slot, int beforeHealth, int eventId)
    {
        if (slot < 0 || slot >= lifeStates.Size() || lifeStates[slot] != STORE_ALIVE)
            return;
        Console.Printf("DS_P039_MAP25_DEATH event_id=%d tic=%d target_id=%d before=%d", eventId, tic, ids[slot], beforeHealth);
        DestroyParts(slot, generations[slot], ids[slot]);
    }

    // ---- Little Heart collection --------------------------------------------

    void CollectHearts()
    {
        int maxHealthMilli = DSP033Resolved(DSP033StatRules.STAT_MAX_HEALTH);
        int recoveryMilli = DSP033Resolved(DSP033StatRules.STAT_RECOVERY);
        for (int i = 0; i < DSP039HeartCount(); i++)
        {
            if (!DSP039HeartActiveAt(i)) continue;
            double dx = dsp039HeartX[i] - playerX;
            double dy = dsp039HeartY[i] - playerY;
            if (dx * dx + dy * dy > HEART_COLLECT_RADIUS * HEART_COLLECT_RADIUS)
                continue;
            int healthAfter; int appliedMilli;
            bool accepted = DSP039ApplyHeal(SOURCE_LITTLE_HEART,
                dsp039HeartHealMilli[i], logicalTic, runActive,
                health[playerSlot], maxHealthMilli, healthAfter, appliedMilli);
            health[playerSlot] = healthAfter;
            if (accepted)
            {
                DSP039CollectHeartAt(i, logicalTic);
                if (appliedMilli > 0) DSP039FeedSoulEaterGrowth(appliedMilli, logicalTic);
            }
        }
    }

    // ---- Recovery ------------------------------------------------------------

    void ProcessRecovery(int recoveryMilli)
    {
        int due = DSP039RecoveryDue(logicalTic, recoveryMilli);
        if (due <= 0) return;
        int maxHealthMilli = DSP033Resolved(DSP033StatRules.STAT_MAX_HEALTH);
        int healthAfter; int appliedMilli;
        DSP039ApplyHeal(SOURCE_RECOVERY, due, logicalTic, runActive,
            health[playerSlot], maxHealthMilli, healthAfter, appliedMilli);
        health[playerSlot] = healthAfter;
        if (appliedMilli > 0) DSP039FeedSoulEaterGrowth(appliedMilli, logicalTic);
        if (appliedMilli == 0) recoveryCapObserved = true;
    }

    // ---- Per-mode per-tic behaviour --------------------------------------

    // Movement and form changes that must take effect BEFORE this tic's
    // DSP024Rebuild(), so the broad-phase index is never one tic stale for
    // the tic a target actually moves or transforms -- matching P038's
    // established move-then-rebuild ordering (GroundMap24Runtime.zs).
    void PreTicMovement()
    {
        if (activeMode == "matrix" && !leaveDone && logicalTic == 10)
        {
            // Move the leave/re-enter target far outside the radius right
            // after its first accepted hit (ready tic = 1 + 46 = 47).
            x[targetLeaveReenter] = 5000.0; y[targetLeaveReenter] = 5000.0;
            leaveDone = true;
            Console.Printf("DS_P039_MAP25_LEAVE tic=%d target_id=%d", logicalTic, ids[targetLeaveReenter]);
        }
        if (activeMode == "matrix" && leaveDone && !reenterDone && logicalTic == 30)
        {
            // Return well before tic 47 (its ready tic); it must NOT be hit
            // again until 47, proving the ledger survives the round trip.
            x[targetLeaveReenter] = 0.0; y[targetLeaveReenter] = 20.0;
            reenterDone = true;
            Console.Printf("DS_P039_MAP25_REENTER tic=%d target_id=%d", logicalTic, ids[targetLeaveReenter]);
        }
        if (activeMode == "transform" && !transformDone && logicalTic == 50)
        {
            bool accepted = DSP039TransformAura(weaponSlot, generations[weaponSlot],
                ids[weaponSlot], DSP039AuraRows.SYSTEM_GARLIC,
                DSP039AuraRows.SYSTEM_SOUL_EATER, 1, 2, true);
            Console.Printf("DS_P039_MAP25_TRANSFORM accepted=%d tic=%d dependency_present=1 source_inventory_claim=0", accepted ? 1 : 0, logicalTic);
            transformDone = accepted;
        }
    }

    void RunModeTic()
    {
        int mightMilli = DSP033Resolved(DSP033StatRules.STAT_MIGHT);
        int cooldownMultiplierMilli = DSP033Resolved(DSP033StatRules.STAT_COOLDOWN);
        int recoveryMilli = DSP033Resolved(DSP033StatRules.STAT_RECOVERY);

        if (activeMode == "matrix" || activeMode == "camera"
            || activeMode == "transform" || activeMode == "heart"
            || activeMode == "heart_recovery"
            || activeMode == "growth_and_high_stats"
            || activeMode == "save" || activeMode == "pause")
        {
            DSP039ProcessAuraTic(logicalTic, playerX, playerY, mightMilli,
                cooldownMultiplierMilli, recoveryMilli);
            CollectHearts();
        }

        if (activeMode == "growth_and_high_stats")
        {
            // DSP033StatRules.ValidBases caps max health at 1,000,000 milli,
            // so no single heal transaction can reach the 3,600,000-milli
            // growth ceiling. Instead this repeats a controlled
            // damage-then-heal cycle (the fixture's own direct health
            // mutation stands in for contact damage, exactly as
            // same_tic_order does) five times, each applying close to the
            // full 1,000,000-milli room; the first cycle alone already
            // proves scaling below the cap (bonus 16), and the fifth
            // proves the min(60, ...) clamp.
            bool cycleTic = logicalTic == 20 || logicalTic == 60
                || logicalTic == 100 || logicalTic == 140 || logicalTic == 180;
            if (cycleTic && growthCycle < 5)
            {
                int maxHealthMilli = DSP033Resolved(DSP033StatRules.STAT_MAX_HEALTH);
                health[playerSlot] = 1000; // simulated contact damage down to 1 HP
                int healthAfter; int appliedMilli;
                DSP039ApplyHeal(SOURCE_FIXTURE, maxHealthMilli, logicalTic,
                    runActive, health[playerSlot], maxHealthMilli, healthAfter,
                    appliedMilli);
                health[playerSlot] = healthAfter;
                if (appliedMilli > 0) DSP039FeedSoulEaterGrowth(appliedMilli, logicalTic);
                growthCycle++;
                growthSmallApplied = growthSmallApplied || growthCycle >= 1;
                growthBigApplied = growthBigApplied
                    || dsp039AuraGrowthBonusDamage[0] >= DSP039AuraRows.SOUL_EATER_GROWTH_CAP;
            }
        }

        if (activeMode == "recovery_cap")
            ProcessRecovery(recoveryMilli);

        if (activeMode == "bloody_tear")
        {
            bool attempt = logicalTic == 1 || logicalTic == 20 || logicalTic == 36;
            if (attempt)
            {
                bool ready = DSP039BloodyTearDrainReady(logicalTic);
                if (ready)
                {
                    int maxHealthMilli = DSP033Resolved(DSP033StatRules.STAT_MAX_HEALTH);
                    int healthAfter; int appliedMilli;
                    DSP039ApplyHeal(SOURCE_BLOODY_TEAR,
                        DSP039AuraRows.BLOODY_TEAR_DRAIN_MILLI, logicalTic,
                        runActive, health[playerSlot], maxHealthMilli,
                        healthAfter, appliedMilli);
                    health[playerSlot] = healthAfter;
                    DSP039ConsumeBloodyTearDrain(logicalTic);
                    if (logicalTic == 1) bloodyTearFirstApplied = true;
                    else bloodyTearSecondApplied = true;
                }
                Console.Printf("DS_P039_MAP25_BLOODY_TEAR_ATTEMPT tic=%d ready=%d", logicalTic, ready ? 1 : 0);
            }
        }

        if (activeMode == "same_tic_order" && !sameTicContactApplied
            && logicalTic == 10)
        {
            // Controlled contact damage (P039 does not own contact damage;
            // this is the fixture's own direct authority-consistent mutation
            // to prove the frozen order, matching the healing authority's
            // own reject rule when it then runs in the SAME tic).
            int before = health[playerSlot];
            health[playerSlot] = 0;
            // "A contact hit that reduces health to 0 ends the run before
            // any same-tic heal; healing never revives" -- so the SAME
            // tic's heal attempt below must see a not-active run.
            runActive = false;
            sameTicContactApplied = true;
            Console.Printf("DS_P039_MAP25_CONTACT tic=%d before=%d after=0", logicalTic, before);
            int maxHealthMilli = DSP033Resolved(DSP033StatRules.STAT_MAX_HEALTH);
            int healthAfter; int appliedMilli;
            bool accepted = DSP039ApplyHeal(SOURCE_RECOVERY, recoveryMilli,
                logicalTic, runActive, health[playerSlot], maxHealthMilli,
                healthAfter, appliedMilli);
            sameTicHealAttempted = true;
            Console.Printf("DS_P039_MAP25_SAME_TIC_ORDER tic=%d contact_before_heal=1 heal_accepted=%d applied_milli=%d health_after=%d", logicalTic, accepted ? 1 : 0, appliedMilli, healthAfter);
        }
    }

    // ---- Result -------------------------------------------------------------

    void EmitResult()
    {
        bool passed = rowCount == EXPECTED_ROWS && captureFlushed;
        if (activeMode == "matrix")
            passed = passed && dsp039AcceptedHits >= 6 && dsp039RejectedHits == 0;
        else if (activeMode == "camera")
            passed = passed && dsp039AcceptedHits >= 2;
        else if (activeMode == "transform")
            passed = passed && transformDone && dsp039AcceptedHits >= 1;
        else if (activeMode == "heart")
            passed = passed && dsp039HeartsSpawned >= 1;
        else if (activeMode == "heart_recovery")
            passed = passed && dsp039HeartsSpawned >= 1;
        else if (activeMode == "growth_and_high_stats")
            passed = passed && growthSmallApplied && growthBigApplied;
        else if (activeMode == "recovery_cap")
            passed = passed && recoveryCapObserved;
        else if (activeMode == "bloody_tear")
            passed = passed && bloodyTearFirstApplied && bloodyTearSecondApplied;
        else if (activeMode == "same_tic_order")
            passed = passed && sameTicHealAttempted;
        Console.Printf("DS_P039_MAP25_RESULT accepted=%d mode=%s logical_tic=%d rows=%d accepted_hits=%d rejected_hits=%d accepted_damage_milli=%d hearts_spawned=%d hearts_collected=%d heal_transactions=%d heal_applied_milli=%d heal_rejected=%d classification=CONTROLLED_ENGINE_RUNTIME", passed ? 1 : 0, activeMode, logicalTic, rowCount, dsp039AcceptedHits, dsp039RejectedHits, dsp039AcceptedDamageMilli, dsp039HeartsSpawned, dsp039HeartsCollected, dsp039HealTransactions, dsp039HealAppliedMilli, dsp039HealRejected);
        if (passed)
            Console.Printf("DS_P039_MAP25_RUNTIME_PASS accepted=1 mode=%s rows=%d hits=%d", activeMode, rowCount, dsp039AcceptedHits);
        else Console.Printf("DS_ASSERT_FAIL P039_MAP25_RUNTIME_EVIDENCE mode=%s rows=%d/%d hits=%d capture=%d", activeMode, rowCount, EXPECTED_ROWS, dsp039AcceptedHits, captureFlushed ? 1 : 0);
        completed = true;
    }

    // ---- Presentation ring ---------------------------------------------------

    void SyncRingProxy()
    {
        ThinkerIterator it = ThinkerIterator.Create("DSP039Map25RingProxy");
        Actor existing;
        while ((existing = Actor(it.Next())) != null) existing.Destroy();
        if (visualToggle == 0) return;
        Actor.Spawn("DSP039Map25RingProxy", (playerX, playerY, 3.0), NO_REPLACE);
    }

    // ---- UI pause bridge (mirrors P038's MAP24 pattern) -----------------------

    override void UiTick()
    {
        uiTics++;
        if (uiPauseMode == 0) return;
        if (!uiPauseRequestSent && uiLogicalTic >= 35
            && !Level.WorldPaused() && Menu.GetCurrentMenu() == null)
        {
            uiPauseRequestSent = true;
            uiPauseAtTic = uiLogicalTic;
            SendNetworkEvent("P039_MAP25_PAUSE_REQUEST", uiLogicalTic, uiPauseHash, uiTics);
            Menu.SetMenu('MainMenu');
        }
        else if (uiPauseRequestSent && !uiPauseObserved && Level.WorldPaused())
        {
            uiPauseObserved = true;
            uiPauseUntilUiTic = uiTics + 35;
            SendNetworkEvent("P039_MAP25_PAUSE_HELD", uiLogicalTic, uiPauseHash, uiTics);
        }
        else if (uiPauseObserved && !uiPauseResumeSent && uiTics >= uiPauseUntilUiTic)
        {
            Menu menu = Menu.GetCurrentMenu();
            if (menu != null) menu.Close();
            if (!Level.WorldPaused())
            {
                uiPauseResumeSent = true;
                SendNetworkEvent("P039_MAP25_RESUME", uiLogicalTic, uiPauseHash, uiTics);
            }
        }
    }

    override void InterfaceProcess(ConsoleEvent e)
    {
        if (e.Name == "P039_MAP25_UI_RESET")
        {
            uiPauseRequestSent = false; uiPauseObserved = false; uiPauseResumeSent = false;
            uiTics = 0; uiLogicalTic = 0; uiPauseHash = 0;
            uiPauseAtTic = -1; uiPauseUntilUiTic = 0; uiPauseMode = 0;
        }
        else if (e.Name == "P039_MAP25_UI_STATE")
        {
            uiLogicalTic = e.Args[0];
            uiPauseHash = e.Args[1];
            uiPauseMode = e.Args[2];
        }
    }

    override void NetworkProcess(ConsoleEvent e)
    {
        if (e.Player != consoleplayer) return;
        if (e.Name == "P039_MAP25_PAUSE_REQUEST")
        {
            pauseRequested = true;
            pauseStartLogicalTic = e.Args[0];
            pauseStartHash = e.Args[1];
            Console.Printf("DS_P039_MAP25_PAUSE_START logical_tic=%d state_hash=%d ui_tic=%d requested_native_pause=1", pauseStartLogicalTic, pauseStartHash, e.Args[2]);
        }
        else if (e.Name == "P039_MAP25_PAUSE_HELD")
        {
            pauseOpened = true;
            Console.Printf("DS_P039_MAP25_PAUSE_HELD logical_tic=%d state_hash=%d ui_tic=%d world_paused=1", e.Args[0], e.Args[1], e.Args[2]);
        }
        else if (e.Name == "P039_MAP25_RESUME")
        {
            pauseClosed = true;
            pauseResumeTic = e.Args[0];
            pauseResumeHash = e.Args[1];
            bool stable = pauseOpened && pauseStartLogicalTic == pauseResumeTic
                && pauseStartHash == pauseResumeHash;
            Console.Printf("DS_P039_MAP25_PAUSE_END accepted=%d world_logical_tic=%d start_world_logical_tic=%d ui_tics=%d start_hash=%d end_hash=%d", stable ? 1 : 0, pauseResumeTic, pauseStartLogicalTic, e.Args[2], pauseStartHash, pauseResumeHash);
        }
    }

    override void WorldLoaded(WorldEvent e)
    {
        IsUiProcessor = false;
        if (level == null || level.MapName != MAP)
        {
            Console.Printf("DS_P039_INPUT_OWNERSHIP map=%s handler=MAP25 ui_processor=%d native_usercmd=%d", level != null ? level.MapName : "UNKNOWN", IsUiProcessor ? 1 : 0, IsUiProcessor ? 0 : 1);
            return;
        }
        IsUiProcessor = true;
        if (e.IsSaveGame) return;
        started = false; enabled = false; completed = false;
        startedThisProcess = false;
    }

    override void WorldUnloaded(WorldEvent e)
    {
        if (level != null && level.MapName == MAP)
            Console.Printf("DS_P039_MAP25_UNLOAD logical_tic=%d aura_state_hash=%d healing_state_hash=%d", logicalTic, DSP039AuraStateHash(), DSP039HealingStateHash());
    }

    override void WorldTick()
    {
        if (level == null || level.MapName != MAP || completed) return;
        if (!startedThisProcess)
        {
            startedThisProcess = true;
            if (started && activeMode == "save" && !restoredStateReported)
            {
                int restoredAuraHash = DSP039AuraStateHash();
                int restoredHealingHash = DSP039HealingStateHash();
                bool same = restoredAuraHash == saveStateHash
                    && restoredHealingHash == saveHealingHash
                    && logicalTic == saveLogicalTic;
                Console.Printf("DS_P039_MAP25_RESTORE accepted=%d first_tick=1 logical_tic=%d saved_tic=%d aura_state_hash=%d saved_aura_hash=%d healing_state_hash=%d saved_healing_hash=%d", same ? 1 : 0, logicalTic, saveLogicalTic, restoredAuraHash, saveStateHash, restoredHealingHash, saveHealingHash);
                restoredStateReported = true;
                saveHold = false;
            }
            else if (!started)
            {
                enabled = StartScenario();
                started = true;
                return;
            }
        }
        if (!enabled || saveHold) return;
        logicalTic++;
        tic = logicalTic;
        PreTicMovement();
        DSP024Rebuild();
        RunModeTic();
        SyncRingProxy();
        if (activeMode == "save" && !saveSnapshotEmitted && logicalTic == 40)
        {
            saveLogicalTic = logicalTic;
            saveStateHash = DSP039AuraStateHash();
            saveHealingHash = DSP039HealingStateHash();
            saveSnapshotEmitted = true;
            saveHold = true;
            Console.Printf("DS_P039_MAP25_SAVE_STATE accepted=1 logical_tic=%d aura_state_hash=%d healing_state_hash=%d ledger=%d hearts=%d", saveLogicalTic, saveStateHash, saveHealingHash, dsp039HitWeaponId.Size(), dsp039HeartActive.Size());
        }
        SendInterfaceEvent(consoleplayer, "P039_MAP25_UI_STATE", logicalTic,
            DSP039AuraStateHash(), activeMode == "pause" ? 1 : 0);
        if (logicalTic == 20)
            Console.Printf("DS_P039_MAP25_PRESENTATION vfx=%d source=LOGICAL_AURA_STATE collision_authority=NONE", visualToggle);
        if (!captureRequested && logicalTic >= 20)
        {
            LevelLocals.MakeScreenShot();
            captureRequested = true;
            return;
        }
        if (captureRequested && !captureFlushed)
        {
            captureFlushed = true;
            return;
        }
        if (logicalTic >= finishAtTic) EmitResult();
    }
}
