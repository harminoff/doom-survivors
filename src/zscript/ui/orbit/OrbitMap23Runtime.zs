// Cosmetic first-person marker for one logical orbit member. It never blocks,
// collides or participates in the sweep/damage decision.
class DSP037Map23OrbitProxy : Actor
{
    int memberIndex;
    int cohortId;
    int memberOrdinal;
    int memberGeneration;

    Default
    {
        Radius 3;
        Height 5;
        +NOBLOCKMAP;
        +NOGRAVITY;
        +NOINTERACTION;
        RenderStyle "Add";
        Alpha 0.95;
        Scale 0.12;
    }

    States
    {
    Spawn:
        PROP A 2 Bright;
        Loop;
    }
}

// MAP23 harness for build-census HOLYBOOK/VESPERS rows. Enemy bodies and the
// selected rank/passive fixtures are controlled test inputs; P025 remains the
// sole logical-damage authority and orbit proxies never decide a hit.
class DSP037Map23Runtime : EventHandler
{
    mixin DSRunStatFields;
    mixin DSP020EntityStore;
    mixin DSP024SpatialIndex;
    mixin DSP025AttackCore;
    mixin DSP033ResolvedStats;
    mixin DSP037OrbitRuntime;

    const MAP = "MAP23";
    const ENEMY_KIND = 1;
    const PLAYER_KIND = 99;
    const WEAPON_KIND = 90;
    const EXPECTED_ROWS = 9;

    bool started;
    bool enabled;
    bool completed;
    bool captureRequested;
    bool captureFlushed;
    bool pauseRequested;
    bool pauseOpened;
    bool pauseClosed;
    ui bool uiPauseRequestSent;
    ui bool uiPauseObserved;
    ui bool uiPauseResumeSent;
    ui int uiTics;
    ui int uiLogicalTic;
    ui int uiOrbitHash;
    ui int uiPauseAtTic;
    ui int uiPauseHash;
    ui int uiPauseUntilUiTic;
    ui int uiPauseMode;
    int logicalTic;
    int tic;
    int cameraVariant;
    int pauseAtTic;
    int pauseUntilUiTic;
    int pauseOrbitHash;
    int lastOrbitHash;
    int transformAccepted;
    int transformOldActive;
    int transformNewActive;
    int transformOldBefore;
    int rebaseAccepted;
    int pauseResumeTic;
    int pauseResumeHash;
    String activeMode;
    int playerSlot;
    int weaponSlot;
    double playerX;
    double playerY;
    Array<int> targetSlots;

    override void OnRegister()
    {
        // This handler is registered globally, but its UI pause probe only
        // belongs to MAP23. Claiming UI ownership here suppresses native
        // commands on every other map, including the MAP16 playable slice.
        IsUiProcessor = false;
        RequireMouse = false;
    }

    int ReadCameraVariant()
    {
        CVar camera = CVar.FindCVar("ds_p037_camera_variant");
        int value = camera != null ? camera.GetInt() : 0;
        return value >= 0 && value <= 2 ? value : 0;
    }

    int ReadSeed()
    {
        CVar seedCVar = CVar.FindCVar("ds_p037_seed");
        int value = seedCVar != null ? seedCVar.GetInt() : 370037;
        return value != 0 ? value : 370037;
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
        Console.Printf("DS_P037_MAP23_CAMERA variant=%d yaw=%d pitch=%d fov=%d source=UZDOOM_PLAYER_VIEW", cameraVariant, yaw, pitch, fov);
    }

    int RankLimit(int systemId)
    {
        return systemId == DSP037OrbitRows.SYSTEM_KING_BIBLE ? 8 : 1;
    }

    bool EmitRows()
    {
        int rowCount = 0;
        for (int systemId = DSP037OrbitRows.SYSTEM_KING_BIBLE;
             systemId <= DSP037OrbitRows.SYSTEM_UNHOLY_VESPERS;
             systemId++)
        {
            for (int rank = 1; rank <= RankLimit(systemId); rank++)
            {
                int damage; int area; int speed; int amount;
                int duration; int cooldown; int cooldownAfter;
                int poolMin; int poolMax; int fixtureCap;
                bool found = DSP037OrbitRows.TryGetRankRow(systemId, rank,
                    damage, area, speed, amount, duration, cooldown,
                    cooldownAfter, poolMin, poolMax, fixtureCap);
                if (!found)
                {
                    Console.Printf("DS_ASSERT_FAIL P037_MAP23_ROW_MISSING system_id=%d rank=%d", systemId, rank);
                    return false;
                }
                rowCount++;
                Console.Printf("DS_P037_MAP23_ROW system_id=%d rank=%d damage_tenths=%d area_multiplier_milli=%d speed_multiplier_milli=%d amount=%d active_duration_milliseconds=%d cooldown_milliseconds=%d cooldown_starts_after_duration=%d pool_report_min=%d pool_report_max=%d fixture_pool_cap=%d classification=QUALIFIED_ONLINE_REPORT_ENGINEERING_CAP", systemId, rank, damage, area, speed, amount, duration, cooldown, cooldownAfter, poolMin, poolMax, fixtureCap);
            }
        }
        int invalidDamage; int invalidArea; int invalidSpeed; int invalidAmount;
        int invalidDuration; int invalidCooldown; int invalidAfter;
        int invalidPoolMin; int invalidPoolMax; int invalidPoolCap;
        bool lowAccepted = DSP037OrbitRows.TryGetRankRow(
            DSP037OrbitRows.SYSTEM_KING_BIBLE, 0, invalidDamage,
            invalidArea, invalidSpeed, invalidAmount, invalidDuration,
            invalidCooldown, invalidAfter, invalidPoolMin, invalidPoolMax,
            invalidPoolCap);
        bool highAccepted = DSP037OrbitRows.TryGetRankRow(
            DSP037OrbitRows.SYSTEM_KING_BIBLE, 9, invalidDamage,
            invalidArea, invalidSpeed, invalidAmount, invalidDuration,
            invalidCooldown, invalidAfter, invalidPoolMin, invalidPoolMax,
            invalidPoolCap);
        bool profileOk = true;
        for (int systemId = DSP037OrbitRows.SYSTEM_KING_BIBLE;
             systemId <= DSP037OrbitRows.SYSTEM_UNHOLY_VESPERS;
             systemId++)
        {
            int radius; int radiusCap; int contact; int angularRate;
            int maxStep; int hitGate; int clockwise; int wall;
            bool found = DSP037OrbitRows.TryGetOrbitProfile(systemId,
                radius, radiusCap, contact, angularRate, maxStep,
                hitGate, clockwise, wall);
            profileOk = profileOk && found && radius == 48000
                && radiusCap == 160000 && contact == 8000
                && angularRate == 5000 && maxStep == 10000
                && hitGate == 60 && clockwise == 1
                && wall == DSP037OrbitRows.WALL_PASS;
            Console.Printf("DS_P037_MAP23_PROFILE system_id=%d accepted=%d base_radius_milliunits=%d radius_cap_milliunits=%d contact_radius_milliunits=%d angular_rate_milliradians_per_second=%d max_substep_millidegrees=%d member_target_gate_tics=%d clockwise=%d wall_policy=%d classification=ENGINEERING_ADAPTER_FIXTURE", systemId, found ? 1 : 0, radius, radiusCap, contact, angularRate, maxStep, hitGate, clockwise, wall);
        }
        int evolved; int requiredRank; int dependencyKind; int dependencyMin;
        bool evolution = DSP037OrbitRows.TryGetEvolution(
            DSP037OrbitRows.SYSTEM_KING_BIBLE, evolved, requiredRank,
            dependencyKind, dependencyMin);
        Console.Printf("DS_P037_MAP23_EVOLUTION accepted=%d source_system_id=%d output_system_id=%d required_source_rank=%d dependency_kind=%d dependency_min_rank=%d dependency_min_rank_status=UNKNOWN source_edge=BUILD_CENSUS dependency_identity=BUILD_CENSUS", evolution ? 1 : 0, DSP037OrbitRows.SYSTEM_KING_BIBLE, evolved, requiredRank, dependencyKind, dependencyMin);
        Console.Printf("DS_P037_MAP23_ROW_COUNT rows=%d expected=%d invalid_rank_rejected=%d", rowCount, EXPECTED_ROWS, !lowAccepted && !highAccepted);
        return rowCount == EXPECTED_ROWS && profileOk && evolution
            && evolved == DSP037OrbitRows.SYSTEM_UNHOLY_VESPERS
            && requiredRank == 8 && dependencyKind == DSP037OrbitRows.DEPENDENCY_DURATION
            && dependencyMin == 0 && !lowAccepted && !highAccepted;
    }

    int SpawnTarget(double targetX, double targetY, String direction,
        double targetRadius)
    {
        int slot = Allocate(ENEMY_KIND, targetX, targetY,
            0.0, 0.0, 1000000000);
        if (slot < 0) return -1;
        collisionRadii[slot] = targetRadius;
        targetSlots.Push(slot);
        Console.Printf("DS_P037_MAP23_TARGET_FIXTURE target_id=%d x=%.4f y=%.4f radius=%.4f direction=%s classification=CONTROLLED_ORBIT_CONTACT_TARGET", ids[slot], targetX, targetY, targetRadius, direction);
        return slot;
    }

    bool Equip(int systemId, int rank, int firstFireTic,
        int areaAdjustmentMilli, int speedAdjustmentMilli)
    {
        weaponSlot = Allocate(WEAPON_KIND, playerX, playerY,
            0.0, 0.0, 1);
        if (weaponSlot < 0) return false;
        bool accepted = DSP037EquipFixture(systemId, rank, weaponSlot,
            firstFireTic, playerSlot, generations[playerSlot],
            ids[playerSlot], areaAdjustmentMilli, speedAdjustmentMilli);
        Console.Printf("DS_P037_MAP23_WEAPON_FIXTURE accepted=%d system_id=%d rank=%d weapon_id=%d first_fire_tic=%d area_adjustment_milli=%d speed_adjustment_milli=%d might_milli=%d cooldown_multiplier_milli=%d classification=CONTROLLED_WEAPON_RANK_FIXTURE source_inventory_claim=0", accepted ? 1 : 0, systemId, rank, ids[weaponSlot], firstFireTic, areaAdjustmentMilli, speedAdjustmentMilli, dsp033ResolvedMightMilli, dsp033ResolvedCooldownMultiplierMilli);
        return accepted;
    }

    int SyncOrbitProxies()
    {
        int visibleMembers = 0;
        ThinkerIterator it = ThinkerIterator.Create("DSP037Map23OrbitProxy");
        Actor actor;
        while ((actor = Actor(it.Next())) != null)
        {
            DSP037Map23OrbitProxy proxy = DSP037Map23OrbitProxy(actor);
            int index = proxy.memberIndex;
            if (index < 0 || index >= dsp037MemberActive.Size()
                || dsp037MemberActive[index] == 0
                || dsp037MemberCohortIds[index] != proxy.cohortId
                || dsp037MemberOrdinals[index] != proxy.memberOrdinal
                || dsp037MemberGenerations[index] != proxy.memberGeneration)
                actor.Destroy();
            else
            {
                proxy.SetOrigin((dsp037MemberX[index],
                    dsp037MemberY[index], 18.0), true);
                visibleMembers++;
            }
        }
        for (int index = 0; index < dsp037MemberActive.Size(); index++)
        {
            if (dsp037MemberActive[index] == 0) continue;
            bool found = false;
            ThinkerIterator find = ThinkerIterator.Create("DSP037Map23OrbitProxy");
            Actor existing;
            while ((existing = Actor(find.Next())) != null)
            {
                DSP037Map23OrbitProxy proxy = DSP037Map23OrbitProxy(existing);
                if (proxy.memberIndex == index
                    && proxy.cohortId == dsp037MemberCohortIds[index]
                    && proxy.memberOrdinal == dsp037MemberOrdinals[index]
                    && proxy.memberGeneration == dsp037MemberGenerations[index])
                { found = true; break; }
            }
            if (found) continue;
            DSP037Map23OrbitProxy created = DSP037Map23OrbitProxy(Actor.Spawn(
                "DSP037Map23OrbitProxy", (dsp037MemberX[index],
                    dsp037MemberY[index], 18.0), NO_REPLACE));
            if (created != null)
            {
                created.memberIndex = index;
                created.cohortId = dsp037MemberCohortIds[index];
                created.memberOrdinal = dsp037MemberOrdinals[index];
                created.memberGeneration = dsp037MemberGenerations[index];
                visibleMembers++;
            }
        }
        return visibleMembers;
    }

    bool StartScenario()
    {
        CVar modeCVar = CVar.FindCVar("ds_p037_mode");
        activeMode = modeCVar != null ? modeCVar.GetString() : "rotation";
        if (activeMode != "rotation" && activeMode != "stress"
            && activeMode != "members" && activeMode != "cohorts"
            && activeMode != "overlap" && activeMode != "transform"
            && activeMode != "rebase" && activeMode != "pause"
            && activeMode != "bible_gap")
        {
            Console.Printf("DS_ASSERT_FAIL P037_MAP23_MODE_UNSUPPORTED mode=%s", activeMode);
            return false;
        }
        logicalTic = 0;
        tic = 0;
        playerX = 0.0;
        playerY = 0.0;
        completed = false;
        captureRequested = false;
        captureFlushed = false;
        pauseRequested = false;
        pauseOpened = false;
        pauseClosed = false;
        pauseAtTic = -1;
        pauseUntilUiTic = -1;
        pauseOrbitHash = 0;
        lastOrbitHash = 0;
        transformAccepted = 0;
        transformOldActive = -1;
        transformNewActive = -1;
        transformOldBefore = 0;
        rebaseAccepted = 0;
        pauseResumeTic = -1;
        pauseResumeHash = 0;
        targetSlots.Clear();
        Reset();
        DSP024ClearSpatial();
        DSP037ResetOrbitRuntime();
        SendInterfaceEvent(consoleplayer, "P037_MAP23_UI_RESET", 0, 0, 0);
        DSP033SetBaseStats(1000, 0, 120000, 1000);
        if (!DSP033RecomputeFromRanks(0, 0, 0, 0))
        {
            Console.Printf("DS_ASSERT_FAIL P037_MAP23_STATS_FIXTURE_REJECTED");
            return false;
        }
        ConfigureCamera();
        playerSlot = Allocate(PLAYER_KIND, playerX, playerY,
            0.0, 0.0, 1);
        bool rowsOk = EmitRows();
        bool setupOk = rowsOk && playerSlot >= 0;
        bool scenarioOk = false;
        if (activeMode == "rotation")
        {
            scenarioOk = SpawnTarget(playerX + 48.0, playerY, "FRONT", 8.0) >= 0
                && SpawnTarget(playerX, playerY + 48.0, "SIDE_LEFT", 8.0) >= 0
                && SpawnTarget(playerX - 48.0, playerY, "REAR", 8.0) >= 0
                && SpawnTarget(playerX, playerY - 48.0, "SIDE_RIGHT", 8.0) >= 0
                && Equip(DSP037OrbitRows.SYSTEM_KING_BIBLE, 1, 1, 1000, 1000);
        }
        else if (activeMode == "stress")
        {
            // Target lies between whole-tic endpoints. Rank8 Area ×3 is capped
            // at a 160-unit orbit; Speed ×3 yields four <=10-degree substeps.
            scenarioOk = SpawnTarget(150.3508, -54.7233, "FAST_SWEPT_CROSSING", 8.0) >= 0
                && Equip(DSP037OrbitRows.SYSTEM_KING_BIBLE, 8, 1, 3000, 3000);
            Console.Printf("DS_P037_MAP23_STRESS_FIXTURE target_angle_degrees=-20 whole_tic_endpoints_miss=1 high_area_adjustment_milli=3000 high_speed_adjustment_milli=3000 classification=CONTROLLED_SWEEP_AND_CAP");
        }
        else if (activeMode == "members")
        {
            scenarioOk = SpawnTarget(playerX + 48.0, playerY,
                "SHARED_TARGET_MEMBER_GATE", 8.0) >= 0
                && Equip(DSP037OrbitRows.SYSTEM_KING_BIBLE, 2, 1, 1000, 1000);
        }
        else if (activeMode == "cohorts" || activeMode == "overlap")
        {
            scenarioOk = SpawnTarget(playerX + 84.0, playerY,
                "VESPER_COHORT_TARGET", 8.0) >= 0
                && Equip(DSP037OrbitRows.SYSTEM_UNHOLY_VESPERS, 1, 1, 1000, 1000);
            if (activeMode == "overlap")
                Console.Printf("DS_P037_MAP23_COOLDOWN_FIXTURE multiplier_milli=500 classification=CONTROLLED_ENGINE_STRESS_OVERRIDE source_stat_claim=0");
        }
        else if (activeMode == "bible_gap")
        {
            scenarioOk = SpawnTarget(playerX + 48.0, playerY,
                "BIBLE_INACTIVE_GAP", 8.0) >= 0
                && Equip(DSP037OrbitRows.SYSTEM_KING_BIBLE, 1, 1, 1000, 1000);
        }
        else if (activeMode == "transform")
        {
            scenarioOk = SpawnTarget(playerX + 72.0, playerY,
                "TRANSFORM_TARGET", 8.0) >= 0
                && Equip(DSP037OrbitRows.SYSTEM_KING_BIBLE, 8, 1, 1000, 1000);
        }
        else if (activeMode == "rebase" || activeMode == "pause")
        {
            scenarioOk = SpawnTarget(playerX + 48.0, playerY, "FRONT", 8.0) >= 0
                && SpawnTarget(playerX, playerY + 48.0, "SIDE_LEFT", 8.0) >= 0
                && SpawnTarget(playerX - 48.0, playerY, "REAR", 8.0) >= 0
                && SpawnTarget(playerX, playerY - 48.0, "SIDE_RIGHT", 8.0) >= 0
                && Equip(DSP037OrbitRows.SYSTEM_KING_BIBLE, 1, 1, 1000, 1000);
        }
        setupOk = setupOk && scenarioOk;
        DSP024Rebuild();
        Console.Printf("DS_BOOT map=MAP23 classification=CONTROLLED_P037_ORBIT_HARNESS");
        Console.Printf("DS_P037_MAP23_BOOT accepted=%d mode=%s camera_variant=%d target_count=%d row_count=%d source_inventory_claim=0 might_milli=%d cooldown_multiplier_milli=%d rank_hash=%d", setupOk ? 1 : 0, activeMode, cameraVariant, targetSlots.Size(), rowsOk ? EXPECTED_ROWS : 0, dsp033ResolvedMightMilli, dsp033ResolvedCooldownMultiplierMilli, dsp033ResolvedRankHash);
        if (!setupOk) Console.Printf("DS_ASSERT_FAIL P037_MAP23_SCENARIO_SETUP");
        return setupOk;
    }

    void EmitRuntimeResult()
    {
        // rejectedHits counts expected member-target cooldown gates; checked
        // damage rejection is the invalid transaction signal for this run.
        bool passed = captureFlushed && dsp037RejectedDamageMilli == 0;
        if (activeMode == "rotation")
            passed = passed && dsp037AcceptedHits >= 4
                && dsp037AcceptedDamageMilli > 0;
        else if (activeMode == "stress")
            passed = passed && dsp037AcceptedHits >= 1
                && dsp037AcceptedDamageMilli > 0;
        else if (activeMode == "members")
            passed = passed && dsp037AcceptedHits >= 2;
        else if (activeMode == "cohorts")
            passed = passed && dsp037CohortsStarted >= 2;
        else if (activeMode == "bible_gap")
            passed = passed && dsp037CohortsStarted >= 2;
        else if (activeMode == "overlap")
            passed = passed && dsp037CohortsStarted >= 2
                && dsp037AcceptedHits >= 2;
        else if (activeMode == "transform")
            passed = passed && transformAccepted != 0
                && transformOldActive == 0 && transformNewActive > 0;
        else if (activeMode == "rebase")
            passed = passed && rebaseAccepted != 0
                && dsp037AcceptedHits >= 4;
        else if (activeMode == "pause")
            passed = passed && pauseOpened && pauseClosed
                && pauseAtTic == pauseResumeTic
                && pauseOrbitHash == pauseResumeHash
                && logicalTic > pauseAtTic;
        Console.Printf("DS_P037_MAP23_RUNTIME_RESULT accepted=%d mode=%s logical_tic=%d rows=%d targets=%d accepted_hits=%d cohorts_started=%d gate_skips=%d rejected_damage_milli=%d accepted_damage_milli=%d camera_variant=%d capture=%d classification=CONTROLLED_ENGINE_RUNTIME", passed ? 1 : 0, activeMode, logicalTic, EXPECTED_ROWS, targetSlots.Size(), dsp037AcceptedHits, dsp037CohortsStarted, dsp037RejectedHits, dsp037RejectedDamageMilli, dsp037AcceptedDamageMilli, cameraVariant, captureFlushed ? 1 : 0);
        if (activeMode == "transform")
            Console.Printf("DS_P037_MAP23_TRANSFORM_RESULT accepted=%d old_active_members=%d new_active_members=%d active_system_id=%d source=CONTROLLED_MAX_RANK_AND_DURATION_FIXTURE", transformAccepted != 0 && transformOldActive == 0 && transformNewActive > 0 ? 1 : 0, transformOldActive, transformNewActive, dsp037WeaponSystems.Size() > 0 ? dsp037WeaponSystems[0] : 0);
        if (activeMode == "pause")
            Console.Printf("DS_P037_MAP23_PAUSE_RESULT accepted=%d pause_tic=%d resume_tic=%d pause_hash=%d resume_hash=%d logical_tic_after_resume=%d pause_authority=UZDOOM_MAIN_MENU", pauseOpened && pauseClosed && pauseAtTic == pauseResumeTic && pauseOrbitHash == pauseResumeHash && logicalTic > pauseAtTic ? 1 : 0, pauseAtTic, pauseResumeTic, pauseOrbitHash, pauseResumeHash, logicalTic);
        if (passed)
            Console.Printf("DS_P037_MAP23_RUNTIME_PASS accepted=1 mode=%s rows=%d accepted_hits=%d camera_variant=%d", activeMode, EXPECTED_ROWS, dsp037AcceptedHits, cameraVariant);
        else Console.Printf("DS_ASSERT_FAIL P037_MAP23_RUNTIME_EVIDENCE hits=%d damage_rejected=%d damage=%d capture=%d", dsp037AcceptedHits, dsp037RejectedDamageMilli, dsp037AcceptedDamageMilli, captureFlushed ? 1 : 0);
        completed = true;
    }

    void HandleEnemyDeath(int slot, int beforeHealth, int eventId)
    {
        if (slot < 0 || slot >= lifeStates.Size()
            || lifeStates[slot] != STORE_ALIVE) return;
        Console.Printf("DS_P037_MAP23_DEATH event_id=%d tic=%d target_id=%d before=%d", eventId, tic, ids[slot], beforeHealth);
        DestroyParts(slot, generations[slot], ids[slot]);
    }

    int ActiveOrbitMembers(int systemId)
    {
        int count = 0;
        for (int index = 0; index < dsp037MemberActive.Size(); index++)
            if (dsp037MemberActive[index] != 0
                && dsp037MemberSystemIds[index] == systemId) count++;
        return count;
    }

    void ApplyRebaseFixture()
    {
        if (rebaseAccepted != 0 || logicalTic != 10
            || dsp037MemberActive.Size() == 0) return;
        double beforeAnchorX = dsp037MemberAnchorX[0];
        double beforeAnchorY = dsp037MemberAnchorY[0];
        double beforeMemberX = dsp037MemberX[0];
        double beforeMemberY = dsp037MemberY[0];
        int beforePhase = dsp037MemberPhaseMicroRadians[0];
        double dx = 100.0;
        double dy = 60.0;
        playerX += dx;
        playerY += dy;
        x[playerSlot] = playerX;
        y[playerSlot] = playerY;
        if (players[0].mo != null)
            players[0].mo.SetOrigin((playerX, playerY, 0.0), true);
        for (int i = 0; i < targetSlots.Size(); i++)
        {
            int target = targetSlots[i];
            if (target < 0 || target >= lifeStates.Size()
                || lifeStates[target] != STORE_ALIVE) continue;
            x[target] += dx;
            y[target] += dy;
        }
        DSP037RebaseOrbitMembers(dx, dy);
        rebaseAccepted = 1;
        Console.Printf("DS_P037_MAP23_REBASE accepted=1 tic=%d dx=%.3f dy=%.3f before_anchor_x=%.3f before_anchor_y=%.3f after_anchor_x=%.3f after_anchor_y=%.3f before_member_x=%.3f before_member_y=%.3f after_member_x=%.3f after_member_y=%.3f phase_before=%d phase_after=%d actual_player_teleport=1 world_targets_shifted=1", logicalTic, dx, dy, beforeAnchorX, beforeAnchorY, dsp037MemberAnchorX[0], dsp037MemberAnchorY[0], beforeMemberX, beforeMemberY, dsp037MemberX[0], dsp037MemberY[0], beforePhase, dsp037MemberPhaseMicroRadians[0]);
    }

    void ApplyTransformFixture()
    {
        if (transformAccepted != 0 || logicalTic != 10) return;
        transformOldBefore = ActiveOrbitMembers(
            DSP037OrbitRows.SYSTEM_KING_BIBLE);
        bool accepted = DSP037ReplaceFixture(weaponSlot,
            DSP037OrbitRows.SYSTEM_UNHOLY_VESPERS, logicalTic,
            true, 1);
        transformAccepted = accepted ? 1 : -1;
        transformOldActive = ActiveOrbitMembers(
            DSP037OrbitRows.SYSTEM_KING_BIBLE);
        transformNewActive = ActiveOrbitMembers(
            DSP037OrbitRows.SYSTEM_UNHOLY_VESPERS);
        Console.Printf("DS_P037_MAP23_TRANSFORM_TEST accepted=%d tic=%d old_active_before=%d old_active_after=%d new_active_immediate=%d old_cohorts_cancelled=%d dependency=CONTROLLED_DURATION_FIXTURE", accepted ? 1 : 0, logicalTic, transformOldBefore, transformOldActive, transformNewActive, transformOldActive == 0 ? 1 : 0);
    }

    override void WorldLoaded(WorldEvent e)
    {
        IsUiProcessor = false;
        if (level == null || level.MapName != MAP)
        {
            Console.Printf("DS_P037_INPUT_OWNERSHIP map=%s handler=MAP23 ui_processor=%d native_usercmd=%d", level != null ? level.MapName : "UNKNOWN", IsUiProcessor ? 1 : 0, IsUiProcessor ? 0 : 1);
            return;
        }
        // The MAP23 harness uses UI ticks for its controlled pause scenario.
        IsUiProcessor = true;
        if (e.IsSaveGame) return;
        started = false;
        enabled = false;
        completed = false;
    }

    override void WorldTick()
    {
        if (level == null || level.MapName != MAP || completed) return;
        if (!started)
        {
            enabled = StartScenario();
            started = true;
            return;
        }
        if (!enabled) return;
        logicalTic++;
        tic = logicalTic;
        DSP024Rebuild();
        int cooldown = activeMode == "overlap" ? 500
            : dsp033ResolvedCooldownMultiplierMilli;
        DSP037ProcessOrbitTic(logicalTic, playerSlot,
            generations[playerSlot], ids[playerSlot], playerX, playerY,
            dsp033ResolvedMightMilli, cooldown);
        if (activeMode == "transform") ApplyTransformFixture();
        if (activeMode == "rebase") ApplyRebaseFixture();
        if (transformAccepted > 0)
        {
            transformOldActive = ActiveOrbitMembers(
                DSP037OrbitRows.SYSTEM_KING_BIBLE);
            transformNewActive = ActiveOrbitMembers(
                DSP037OrbitRows.SYSTEM_UNHOLY_VESPERS);
        }
        lastOrbitHash = DSP037OrbitStateHash();
        SendInterfaceEvent(consoleplayer, "P037_MAP23_UI_STATE",
            logicalTic, lastOrbitHash, activeMode == "pause" ? 1 : 0);
        int proxyCount = SyncOrbitProxies();
        // Wait until the clockwise member has moved into the visible forward
        // arc; tic 1 places the +X phase offscreen for the default camera.
        int captureTic = activeMode == "rebase" ? 12
            : activeMode == "rotation" ? 3 : 1;
        if (logicalTic == captureTic)
            Console.Printf("DS_P037_MAP23_PRESENTATION_PROXY tic=%d active_members=%d source=LOGICAL_ORBIT_POSITION collision_authority=NONE", logicalTic, proxyCount);
        if (!captureRequested && logicalTic >= captureTic)
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
        int completionTic = activeMode == "rotation" ? 65
            : activeMode == "stress" ? 10
            : activeMode == "members" ? 90
            : activeMode == "cohorts" ? 110
            : activeMode == "bible_gap" ? 213
            : activeMode == "overlap" ? 110
            : activeMode == "transform" ? 35
            : activeMode == "rebase" ? 45
            : activeMode == "pause" ? 25 : 3;
        if (logicalTic >= completionTic) EmitRuntimeResult();
    }

    override void UiTick()
    {
        if (uiPauseMode == 0) return;
        uiTics++;
        if (!uiPauseRequestSent && uiLogicalTic >= 10 && !Level.WorldPaused()
            && Menu.GetCurrentMenu() == null)
        {
            uiPauseRequestSent = true;
            uiPauseAtTic = uiLogicalTic;
            uiPauseHash = uiOrbitHash;
            Menu.SetMenu('MainMenu');
            SendNetworkEvent("P037_MAP23_PAUSE_REQUEST",
                uiPauseAtTic, uiPauseHash, uiTics);
        }
        else if (uiPauseRequestSent && !uiPauseObserved
            && Level.WorldPaused())
        {
            uiPauseObserved = true;
            uiPauseUntilUiTic = uiTics + 35;
            SendNetworkEvent("P037_MAP23_PAUSE_HELD",
                uiLogicalTic, uiOrbitHash, uiTics);
        }
        else if (uiPauseObserved && !uiPauseResumeSent
            && uiTics >= uiPauseUntilUiTic)
        {
            Menu menu = Menu.GetCurrentMenu();
            if (menu != null) menu.Close();
            if (!Level.WorldPaused())
            {
                uiPauseResumeSent = true;
                SendNetworkEvent("P037_MAP23_RESUME",
                    uiLogicalTic, uiOrbitHash, uiTics);
            }
        }
    }

    override void InterfaceProcess(ConsoleEvent e)
    {
        if (e.Name == "P037_MAP23_UI_RESET")
        {
            uiPauseRequestSent = false;
            uiPauseObserved = false;
            uiPauseResumeSent = false;
            uiTics = 0;
            uiLogicalTic = 0;
            uiOrbitHash = 0;
            uiPauseAtTic = -1;
            uiPauseHash = 0;
            uiPauseUntilUiTic = 0;
            uiPauseMode = 0;
        }
        else if (e.Name == "P037_MAP23_UI_STATE")
        {
            uiLogicalTic = e.Args[0];
            uiOrbitHash = e.Args[1];
            uiPauseMode = e.Args[2];
        }
    }

    override void NetworkProcess(ConsoleEvent e)
    {
        if (e.Player != consoleplayer) return;
        if (e.Name == "P037_MAP23_PAUSE_REQUEST")
        {
            pauseRequested = true;
            pauseAtTic = e.Args[0];
            pauseOrbitHash = e.Args[1];
            Console.Printf("DS_P037_MAP23_PAUSE_BEGIN ui_tic=%d world_tic=%d orbit_hash=%d", e.Args[2], pauseAtTic, pauseOrbitHash);
        }
        else if (e.Name == "P037_MAP23_PAUSE_HELD")
        {
            pauseOpened = true;
            pauseUntilUiTic = e.Args[2] + 35;
            Console.Printf("DS_P037_MAP23_PAUSE_HELD ui_tic=%d world_tic=%d orbit_hash=%d frozen_world_tics=1", e.Args[2], e.Args[0], e.Args[1]);
        }
        else if (e.Name == "P037_MAP23_RESUME")
        {
            pauseClosed = true;
            pauseResumeTic = e.Args[0];
            pauseResumeHash = e.Args[1];
            Console.Printf("DS_P037_MAP23_RESUME ui_tic=%d world_tic=%d orbit_hash=%d paused_world_tics=0 backlog=0", e.Args[2], pauseResumeTic, pauseResumeHash);
        }
    }
}
