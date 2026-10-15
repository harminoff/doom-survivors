// Cosmetic marker for one logical bottle or field. These actors are never
// broad-phase inputs and cannot create, move, expire or damage a field.
class DSP038Map24FieldProxy : Actor
{
    int fieldId;
    int fieldGeneration;

    Default
    {
        Radius 4;
        Height 3;
        +NOBLOCKMAP;
        +NOGRAVITY;
        +NOINTERACTION;
        RenderStyle "Add";
        Alpha 0.85;
        Scale 0.18;
    }

    States
    {
    Spawn:
        PROP A 2 Bright;
        Loop;
    }
}

// MAP24 host for the build-census HOLYWATER -> BORA family. Weapons, P033
// inputs, targets and timing are controlled fixtures. P025 owns accepted
// logical damage; rendered bottle/field markers are presentation only.
class DSP038Map24Runtime : EventHandler
{
    mixin DSRunStatFields;
    mixin DSP020EntityStore;
    mixin DSP024SpatialIndex;
    mixin DSP025AttackCore;
    mixin DSP033ResolvedStats;
    mixin DSP038GroundFieldRuntime;

    const MAP = "MAP24";
    const ENEMY_KIND = 1;
    const PLAYER_KIND = 99;
    const WEAPON_KIND = 90;
    const EXPECTED_ROWS = 9;

    bool started;
    bool enabled;
    bool completed;
    bool captureRequested;
    bool captureFlushed;
    transient bool startedThisProcess;
    bool saveHold;
    bool saveSnapshotEmitted;
    bool restoredStateReported;
    bool transformDone;
    bool playerMoved;
    bool worldRebased;
    bool boraScheduleStopped;
    bool highStatScheduleStopped;
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
    int finishAtTic;
    int logicalTic;
    int tic;
    int cameraVariant;
    int playerSlot;
    int weaponSlot;
    int rowCount;
    int targetSlot;
    int visualToggle;
    double playerX;
    double playerY;
    String activeMode;

    override void OnRegister()
    {
        // This handler is registered globally, but its UI pause probe only
        // belongs to MAP24. Claiming UI ownership here suppresses native
        // commands on every other map, including the MAP16 playable slice.
        IsUiProcessor = false;
        RequireMouse = false;
    }

    int ReadCameraVariant()
    {
        CVar camera = CVar.FindCVar("ds_p038_camera_variant");
        int value = camera != null ? camera.GetInt() : 0;
        return value >= 0 && value <= 2 ? value : 0;
    }

    int ReadVisualToggle()
    {
        CVar cvar = CVar.FindCVar("ds_p038_vfx");
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
        Console.Printf("DS_P038_MAP24_CAMERA variant=%d yaw=%d pitch=%d fov=%d source=UZDOOM_PLAYER_VIEW", cameraVariant, yaw, pitch, fov);
    }

    int RankLimit(int systemId)
    {
        return systemId == DSP038GroundRows.SYSTEM_HOLYWATER ? 8
            : systemId == DSP038GroundRows.SYSTEM_BORA ? 1 : 0;
    }

    int EmitRows()
    {
        rowCount = 0;
        for (int systemId = DSP038GroundRows.SYSTEM_HOLYWATER;
             systemId <= DSP038GroundRows.SYSTEM_BORA; systemId++)
        {
            for (int rank = 1; rank <= RankLimit(systemId); rank++)
            {
                int damage; int area; int amount; int duration;
                int cooldown; int interval; int hitDelay; int pool;
                int speedAffected; int moveAffected; int wall;
                bool found = DSP038GroundRows.TryGetRankRow(systemId,
                    rank, damage, area, amount, duration, cooldown,
                    interval, hitDelay, pool, speedAffected, moveAffected,
                    wall);
                if (!found)
                {
                    Console.Printf("DS_ASSERT_FAIL P038_MAP24_ROW_MISSING system_id=%d rank=%d", systemId, rank);
                    return rowCount;
                }
                rowCount++;
                Console.Printf("DS_P038_MAP24_ROW system_id=%d rank=%d damage_tenths=%d area_multiplier_milli=%d amount=%d duration_milliseconds=%d cooldown_milliseconds=%d bottle_interval_milliseconds=%d reported_field_hit_delay_milliseconds=%d reported_pool_limit=%d projectile_speed_affected=%d move_speed_affected=%d wall_policy=%d classification=QUALIFIED_ONLINE_REPORT", systemId, rank, damage, area, amount, duration, cooldown, interval, hitDelay, pool, speedAffected, moveAffected, wall);
            }
        }

        bool profilesOk = true;
        for (int systemId = DSP038GroundRows.SYSTEM_HOLYWATER;
             systemId <= DSP038GroundRows.SYSTEM_BORA; systemId++)
        {
            int placement; int sectors; int ringRadius; int targetRadius;
            int flight; int depositDelay; int fieldRadius; int motion;
            int baseInward; int speedInward; int baseGrowth;
            int speedGrowth; int radiusCap; int rehit; int poolPolicy;
            int clockwise; int sectorZero;
            bool found = DSP038GroundRows.TryGetAdapterProfile(systemId,
                placement, sectors, ringRadius, targetRadius, flight,
                depositDelay, fieldRadius, motion, baseInward, speedInward,
                baseGrowth, speedGrowth, radiusCap, rehit, poolPolicy,
                clockwise, sectorZero);
            profilesOk = profilesOk && found && sectors == 6
                && ringRadius == 96000 && targetRadius == 160000
                && flight == 12 && depositDelay == 2
                && fieldRadius == 20000 && rehit == 18
                && poolPolicy == DSP038GroundRows.POOL_REJECT_AND_MARK
                && clockwise == 1 && sectorZero == 1;
            Console.Printf("DS_P038_MAP24_PROFILE system_id=%d accepted=%d placement_policy=%d sector_count=%d ring_radius_milliunits=%d target_selection_radius_milliunits=%d flight_tics=%d deposit_delay_tics=%d base_field_radius_milliunits=%d field_motion_policy=%d baseline_inward_milliunits_per_tic=%d speed_fixture_inward_milliunits_per_tic=%d baseline_growth_milliunits_per_tic=%d speed_fixture_growth_milliunits_per_tic=%d field_radius_cap_milliunits=%d field_rehit_tics=%d pool_boundary_policy=%d clockwise=%d sector_zero_positive_x=%d classification=ENGINEERING_ADAPTER_FIXTURE", systemId, found ? 1 : 0, placement, sectors, ringRadius, targetRadius, flight, depositDelay, fieldRadius, motion, baseInward, speedInward, baseGrowth, speedGrowth, radiusCap, rehit, poolPolicy, clockwise, sectorZero);
        }

        int evolved; int dependency; int sourceRank; int dependencyRank;
        bool recipe = DSP038GroundRows.TryGetEvolution(
            DSP038GroundRows.SYSTEM_HOLYWATER, evolved, dependency,
            sourceRank, dependencyRank);
        Console.Printf("DS_P038_MAP24_EVOLUTION accepted=%d source_system_id=%d evolved_system_id=%d source_rank=%d dependency_source_key=%d dependency_min_rank=%d dependency_min_rank_status=UNKNOWN provenance=BUILD_CENSUS_AND_CURRENT_REPORT", recipe ? 1 : 0, DSP038GroundRows.SYSTEM_HOLYWATER, evolved, sourceRank, dependency, dependencyRank);
        return profilesOk && recipe && evolved == DSP038GroundRows.SYSTEM_BORA
            && sourceRank == 8
            && dependency == DSP038GroundRows.DEPENDENCY_MAGNET_SOURCE_KEY
            && dependencyRank == 0;
    }

    int SpawnTarget(double targetX, double targetY, String role,
        double targetRadius)
    {
        int slot = Allocate(ENEMY_KIND, targetX, targetY,
            0.0, 0.0, 1000000000);
        if (slot < 0) return -1;
        collisionRadii[slot] = targetRadius;
        Console.Printf("DS_P038_MAP24_TARGET target_id=%d x=%.3f y=%.3f radius=%.3f role=%s classification=CONTROLLED_CONTACT_TARGET source_spawn_claim=0", ids[slot], targetX, targetY, targetRadius, role);
        return slot;
    }

    bool Equip(int systemId, int rank, int firstFireTic,
        int areaAdjustmentMilli, int speedAdjustmentMilli,
        int moveSpeedAdjustmentMilli, int growthAdjustmentMilli)
    {
        weaponSlot = Allocate(WEAPON_KIND, playerX, playerY,
            0.0, 0.0, 1);
        if (weaponSlot < 0) return false;
        bool accepted = DSP038EquipWeapon(systemId, rank, weaponSlot,
            generations[weaponSlot], ids[weaponSlot], 1,
            playerSlot, generations[playerSlot], ids[playerSlot],
            firstFireTic, areaAdjustmentMilli, speedAdjustmentMilli,
            moveSpeedAdjustmentMilli, growthAdjustmentMilli,
            dsp033ResolvedMightMilli,
            dsp033ResolvedCooldownMultiplierMilli);
        Console.Printf("DS_P038_MAP24_WEAPON accepted=%d system_id=%d rank=%d weapon_id=%d weapon_generation=%d form_generation=1 first_fire_tic=%d area_adjustment_milli=%d speed_adjustment_milli=%d move_speed_adjustment_milli=%d growth_adjustment_milli=%d might_milli=%d cooldown_multiplier_milli=%d source_inventory_claim=0 classification=CONTROLLED_WEAPON_FIXTURE", accepted ? 1 : 0, systemId, rank, ids[weaponSlot], generations[weaponSlot], firstFireTic, areaAdjustmentMilli, speedAdjustmentMilli, moveSpeedAdjustmentMilli, growthAdjustmentMilli, dsp033ResolvedMightMilli, dsp033ResolvedCooldownMultiplierMilli);
        return accepted;
    }

    int SyncFieldProxies()
    {
        if (visualToggle == 0)
        {
            ThinkerIterator remove = ThinkerIterator.Create("DSP038Map24FieldProxy");
            Actor actor;
            while ((actor = Actor(remove.Next())) != null) actor.Destroy();
            return 0;
        }

        int proxyCount = 0;
        ThinkerIterator it = ThinkerIterator.Create("DSP038Map24FieldProxy");
        Actor current;
        while ((current = Actor(it.Next())) != null)
        {
            DSP038Map24FieldProxy proxy = DSP038Map24FieldProxy(current);
            int index = -1;
            for (int i = 0; i < dsp038FieldActive.Size(); i++)
                if (dsp038FieldActive[i] != 0
                    && dsp038FieldId[i] == proxy.fieldId
                    && dsp038FieldGeneration[i] == proxy.fieldGeneration)
                { index = i; break; }
            if (index < 0) current.Destroy();
            else
            {
                current.SetOrigin((dsp038FieldX[index], dsp038FieldY[index], 3.0), true);
                proxyCount++;
            }
        }

        for (int index = 0; index < dsp038FieldActive.Size(); index++)
        {
            if (dsp038FieldActive[index] == 0) continue;
            bool found = false;
            ThinkerIterator find = ThinkerIterator.Create("DSP038Map24FieldProxy");
            Actor existing;
            while ((existing = Actor(find.Next())) != null)
            {
                DSP038Map24FieldProxy proxy = DSP038Map24FieldProxy(existing);
                if (proxy.fieldId == dsp038FieldId[index]
                    && proxy.fieldGeneration == dsp038FieldGeneration[index])
                { found = true; break; }
            }
            if (found) continue;
            DSP038Map24FieldProxy created = DSP038Map24FieldProxy(Actor.Spawn(
                "DSP038Map24FieldProxy",
                (dsp038FieldX[index], dsp038FieldY[index], 3.0), NO_REPLACE));
            if (created != null)
            {
                created.fieldId = dsp038FieldId[index];
                created.fieldGeneration = dsp038FieldGeneration[index];
                proxyCount++;
            }
        }
        return proxyCount;
    }

    bool StartScenario()
    {
        CVar modeCVar = CVar.FindCVar("ds_p038_mode");
        activeMode = modeCVar != null ? modeCVar.GetString() : "matrix";
        if (activeMode != "matrix" && activeMode != "tie_ring"
            && activeMode != "overlap" && activeMode != "bora_motion"
            && activeMode != "pool" && activeMode != "transform"
            && activeMode != "save" && activeMode != "pause"
            && activeMode != "high_area_duration")
        {
            Console.Printf("DS_ASSERT_FAIL P038_MAP24_MODE_UNSUPPORTED mode=%s", activeMode);
            return false;
        }
        logicalTic = 0; tic = 0;
        playerX = 0.0; playerY = 0.0;
        completed = false; captureRequested = false; captureFlushed = false;
        saveHold = false; saveSnapshotEmitted = false;
        restoredStateReported = false; transformDone = false;
        playerMoved = false; worldRebased = false; boraScheduleStopped = false;
        highStatScheduleStopped = false;
        pauseRequested = false; pauseOpened = false; pauseClosed = false;
        pauseStartLogicalTic = -1; pauseStartHash = 0;
        pauseResumeTic = -1; pauseResumeHash = 0;
        SendInterfaceEvent(consoleplayer, "P038_MAP24_UI_RESET", 0, 0, 0);
        saveLogicalTic = -1; saveStateHash = 0;
        finishAtTic = 90;
        visualToggle = ReadVisualToggle();
        Reset();
        DSP024ClearSpatial();
        DSP038ResetGroundRuntime();
        DSP033SetBaseStats(1000, 0, 120000, 1000);
        if (!DSP033RecomputeFromRanks(0, 0, 0, 0))
        {
            Console.Printf("DS_ASSERT_FAIL P038_MAP24_STATS_FIXTURE_REJECTED");
            return false;
        }
        ConfigureCamera();
        playerSlot = Allocate(PLAYER_KIND, playerX, playerY,
            0.0, 0.0, 1);
        bool rowsOk = EmitRows();
        bool weaponOk = playerSlot >= 0;
        if (activeMode == "matrix" || activeMode == "save" || activeMode == "pause")
        {
            targetSlot = SpawnTarget(48.0, 0.0, "INITIAL_SANTA_WATER_TARGET", 8.0);
            weaponOk = weaponOk && targetSlot >= 0
                && Equip(DSP038GroundRows.SYSTEM_HOLYWATER, 1, 1,
                    1000, 1000, 1000, 1000);
        }
        else if (activeMode == "tie_ring")
        {
            targetSlot = SpawnTarget(-48.0, 0.0, "TIE_LOW_STABLE_ID", 8.0);
            int tieOther = SpawnTarget(48.0, 0.0, "TIE_HIGH_STABLE_ID", 8.0);
            weaponOk = weaponOk && targetSlot >= 0 && tieOther >= 0
                && Equip(DSP038GroundRows.SYSTEM_HOLYWATER, 1, 1,
                    1000, 1000, 1000, 1000);
            for (int copy = 0; copy < 3 && weaponOk; copy++)
                weaponOk = Equip(DSP038GroundRows.SYSTEM_HOLYWATER, 6, 1,
                    1000, 1000, 1000, 1000);
            finishAtTic = 150;
        }
        else if (activeMode == "overlap")
        {
            targetSlot = SpawnTarget(48.0, 0.0, "OVERLAP_SHARED_TARGET", 8.0);
            weaponOk = weaponOk && targetSlot >= 0;
            for (int copy = 0; copy < 4 && weaponOk; copy++)
                weaponOk = Equip(DSP038GroundRows.SYSTEM_HOLYWATER, 1, 1,
                    1000, 1000, 1000, 1000);
        }
        else if (activeMode == "pool")
        {
            targetSlot = SpawnTarget(48.0, 0.0, "POOL_BOUNDARY_SHARED_TARGET", 8.0);
            weaponOk = weaponOk && targetSlot >= 0;
            for (int copy = 0; copy < 21 && weaponOk; copy++)
                weaponOk = Equip(DSP038GroundRows.SYSTEM_HOLYWATER, 1, 1,
                    1000, 1000, 1000, 1000);
            finishAtTic = 100;
        }
        else if (activeMode == "bora_motion")
        {
            targetSlot = SpawnTarget(96.0, 0.0, "BORA_SECTOR_ZERO_TARGET", 8.0);
            weaponOk = weaponOk && targetSlot >= 0
                && Equip(DSP038GroundRows.SYSTEM_BORA, 1, 1,
                    1500, 1500, 1500, 1500);
            finishAtTic = 200;
        }
        else if (activeMode == "transform")
        {
            targetSlot = SpawnTarget(96.0, 0.0, "PRE_TRANSFORM_SANTA_FIELD_TARGET", 8.0);
            weaponOk = weaponOk && targetSlot >= 0
                && Equip(DSP038GroundRows.SYSTEM_HOLYWATER, 8, 1,
                    1000, 1000, 1000, 1000);
            finishAtTic = 270;
        }
        else if (activeMode == "high_area_duration")
        {
            targetSlot = SpawnTarget(96.0, 0.0, "HIGH_AREA_DURATION_TARGET", 8.0);
            weaponOk = weaponOk && targetSlot >= 0
                && Equip(DSP038GroundRows.SYSTEM_HOLYWATER, 8, 1,
                    2000, 1000, 1000, 1000);
            finishAtTic = 160;
        }
        Console.Printf("DS_P038_MAP24_CASE mode=%s classification=CONTROLLED_ENGINE_FIXTURE source_content_claim=0", activeMode);
        bool setupOk = rowsOk && rowCount == EXPECTED_ROWS && weaponOk;
        Console.Printf("DS_P038_MAP24_BOOT accepted=%d mode=%s player_slot=%d target_slot=%d rows=%d expected_rows=%d visual_toggle=%d classification=CONTROLLED_ENGINE_FIXTURE", setupOk ? 1 : 0, activeMode, playerSlot, targetSlot, rowCount, EXPECTED_ROWS, visualToggle);
        if (activeMode == "high_area_duration")
        {
            int damage; int rowArea; int amount; int durationMs;
            int cooldownMs; int intervalMs; int hitDelayMs; int poolLimit;
            int projectileSpeed; int moveSpeed; int wallPolicy;
            bool rowFound = DSP038GroundRows.TryGetRankRow(
                DSP038GroundRows.SYSTEM_HOLYWATER, 8, damage, rowArea,
                amount, durationMs, cooldownMs, intervalMs, hitDelayMs,
                poolLimit, projectileSpeed, moveSpeed, wallPolicy);
            int durationTics = (durationMs * Thinker.TICRATE + 500) / 1000;
            Console.Printf("DS_P038_MAP24_HIGH_STAT_FIXTURE accepted=%d rank=8 area_adjustment_milli=2000 row_area_milli=%d effective_area_milli=%d reported_duration_milliseconds=%d duration_tics=%d area_provenance=CONTROLLED_2X_FIXTURE duration_provenance=QUALIFIED_ONLINE_RANK_ROW source_content_claim=0", setupOk && rowFound ? 1 : 0, rowArea, rowArea * 2, durationMs, durationTics);
        }
        return setupOk;
    }

    void HandleEnemyDeath(int slot, int beforeHealth, int eventId)
    {
        if (slot < 0 || slot >= lifeStates.Size()
            || lifeStates[slot] != STORE_ALIVE) return;
        Console.Printf("DS_P038_MAP24_DEATH event_id=%d tic=%d target_id=%d before=%d", eventId, tic, ids[slot], beforeHealth);
        DestroyParts(slot, generations[slot], ids[slot]);
    }

    void EmitResult(int proxyCount)
    {
        bool passed = rowCount == EXPECTED_ROWS && captureFlushed
            && dsp038AcceptedHits > 0 && dsp038AcceptedDamageMilli > 0
            && dsp038RejectedDamageMilli == 0
            && dsp038DepositedFields > 0 && dsp038ExpiredFields > 0;
        Console.Printf("DS_P038_MAP24_RESULT accepted=%d mode=%s logical_tic=%d rows=%d accepted_hits=%d rejected_hits=%d accepted_damage_milli=%d rejected_damage_milli=%d deposited_fields=%d expired_fields=%d rejected_fields=%d active_fields=%d field_proxies=%d camera_variant=%d vfx=%d classification=CONTROLLED_ENGINE_RUNTIME", passed ? 1 : 0, activeMode, logicalTic, rowCount, dsp038AcceptedHits, dsp038RejectedHits, dsp038AcceptedDamageMilli, dsp038RejectedDamageMilli, dsp038DepositedFields, dsp038ExpiredFields, dsp038RejectedFields, dsp038FieldActive.Size(), proxyCount, cameraVariant, visualToggle);
        if (passed)
            Console.Printf("DS_P038_MAP24_RUNTIME_PASS accepted=1 mode=%s rows=%d hits=%d damage_milli=%d", activeMode, rowCount, dsp038AcceptedHits, dsp038AcceptedDamageMilli);
        else Console.Printf("DS_ASSERT_FAIL P038_MAP24_RUNTIME_EVIDENCE rows=%d/%d hits=%d damage=%d rejected=%d deposits=%d expired=%d capture=%d", rowCount, EXPECTED_ROWS, dsp038AcceptedHits, dsp038AcceptedDamageMilli, dsp038RejectedDamageMilli, dsp038DepositedFields, dsp038ExpiredFields, captureFlushed ? 1 : 0);
        completed = true;
    }

    void EmitActiveFieldSnapshot(String phase)
    {
        for (int i = 0; i < dsp038FieldActive.Size(); i++)
        {
            if (dsp038FieldActive[i] == 0) continue;
            Console.Printf("DS_P038_MAP24_FIELD_SNAPSHOT phase=%s tic=%d field_id=%d field_generation=%d system_id=%d created_tic=%d expires_tic=%d x=%.3f y=%.3f radius=%.3f anchor_x=%.3f anchor_y=%.3f motion=%d move_milli_per_tic=%d growth_milli_per_tic=%d", phase, logicalTic, dsp038FieldId[i], dsp038FieldGeneration[i], dsp038FieldSystem[i], dsp038FieldCreatedTic[i], dsp038FieldExpiresTic[i], dsp038FieldX[i], dsp038FieldY[i], dsp038FieldRadius[i], dsp038FieldAnchorX[i], dsp038FieldAnchorY[i], dsp038FieldMotionPolicy[i], dsp038FieldMoveMilliPerTic[i], dsp038FieldGrowthMilliPerTic[i]);
        }
    }

    void ApplyWorldRebase(double deltaX, double deltaY)
    {
        int sample = -1;
        for (int i = 0; i < dsp038FieldActive.Size(); i++)
            if (dsp038FieldActive[i] != 0) { sample = i; break; }
        if (sample < 0) return;
        double beforeX = dsp038FieldX[sample];
        double beforeY = dsp038FieldY[sample];
        DSP038RebaseGroundRuntime(deltaX, deltaY);
        for (int i = 0; i < lifeStates.Size(); i++)
            if (lifeStates[i] == STORE_ALIVE
                && (kinds[i] == PLAYER_KIND || kinds[i] == ENEMY_KIND))
            { x[i] += deltaX; y[i] += deltaY; }
        playerX += deltaX; playerY += deltaY;
        Console.Printf("DS_P038_MAP24_REBASE accepted=1 tic=%d field_id=%d before_x=%.3f before_y=%.3f after_x=%.3f after_y=%.3f dx=%.3f dy=%.3f logical_age_preserved=1", logicalTic, dsp038FieldId[sample], beforeX, beforeY, dsp038FieldX[sample], dsp038FieldY[sample], deltaX, deltaY);
    }

    override void UiTick()
    {
        uiTics++;
        if (uiPauseMode == 0) return;
        if (!uiPauseRequestSent && uiLogicalTic >= 35
            && !Level.WorldPaused() && Menu.GetCurrentMenu() == null)
        {
            uiPauseRequestSent = true;
            uiPauseAtTic = uiLogicalTic;
            SendNetworkEvent("P038_MAP24_PAUSE_REQUEST",
                uiLogicalTic, uiPauseHash, uiTics);
            Menu.SetMenu('MainMenu');
        }
        else if (uiPauseRequestSent && !uiPauseObserved
            && Level.WorldPaused())
        {
            uiPauseObserved = true;
            uiPauseUntilUiTic = uiTics + 35;
            SendNetworkEvent("P038_MAP24_PAUSE_HELD",
                uiLogicalTic, uiPauseHash, uiTics);
        }
        else if (uiPauseObserved && !uiPauseResumeSent
            && uiTics >= uiPauseUntilUiTic)
        {
            Menu menu = Menu.GetCurrentMenu();
            if (menu != null) menu.Close();
            if (!Level.WorldPaused())
            {
                uiPauseResumeSent = true;
                SendNetworkEvent("P038_MAP24_RESUME",
                    uiLogicalTic, uiPauseHash, uiTics);
            }
        }
    }

    override void InterfaceProcess(ConsoleEvent e)
    {
        if (e.Name == "P038_MAP24_UI_RESET")
        {
            uiPauseRequestSent = false;
            uiPauseObserved = false;
            uiPauseResumeSent = false;
            uiTics = 0; uiLogicalTic = 0; uiPauseHash = 0;
            uiPauseAtTic = -1; uiPauseUntilUiTic = 0; uiPauseMode = 0;
        }
        else if (e.Name == "P038_MAP24_UI_STATE")
        {
            uiLogicalTic = e.Args[0];
            uiPauseHash = e.Args[1];
            uiPauseMode = e.Args[2];
        }
    }

    override void NetworkProcess(ConsoleEvent e)
    {
        if (e.Player != consoleplayer) return;
        if (e.Name == "P038_MAP24_PAUSE_REQUEST")
        {
            pauseRequested = true;
            pauseStartLogicalTic = e.Args[0];
            pauseStartHash = e.Args[1];
            Console.Printf("DS_P038_MAP24_PAUSE_START logical_tic=%d state_hash=%d ui_tic=%d requested_native_pause=1", pauseStartLogicalTic, pauseStartHash, e.Args[2]);
        }
        else if (e.Name == "P038_MAP24_PAUSE_HELD")
        {
            pauseOpened = true;
            Console.Printf("DS_P038_MAP24_PAUSE_HELD logical_tic=%d state_hash=%d ui_tic=%d world_paused=1", e.Args[0], e.Args[1], e.Args[2]);
        }
        else if (e.Name == "P038_MAP24_RESUME")
        {
            pauseClosed = true;
            pauseResumeTic = e.Args[0];
            pauseResumeHash = e.Args[1];
            bool stable = pauseOpened && pauseStartLogicalTic == pauseResumeTic
                && pauseStartHash == pauseResumeHash;
            Console.Printf("DS_P038_MAP24_PAUSE_END accepted=%d world_logical_tic=%d start_world_logical_tic=%d ui_tics=%d start_hash=%d end_hash=%d", stable ? 1 : 0, pauseResumeTic, pauseStartLogicalTic, e.Args[2], pauseStartHash, pauseResumeHash);
        }
    }

    override void WorldLoaded(WorldEvent e)
    {
        IsUiProcessor = false;
        if (level == null || level.MapName != MAP)
        {
            Console.Printf("DS_P038_INPUT_OWNERSHIP map=%s handler=MAP24 ui_processor=%d native_usercmd=%d", level != null ? level.MapName : "UNKNOWN", IsUiProcessor ? 1 : 0, IsUiProcessor ? 0 : 1);
            return;
        }
        // The MAP24 harness uses UI ticks for its controlled pause scenario.
        IsUiProcessor = true;
        if (e.IsSaveGame) return;
        started = false; enabled = false; completed = false;
        startedThisProcess = false;
    }

    override void WorldUnloaded(WorldEvent e)
    {
        if (level != null && level.MapName == MAP)
            Console.Printf("DS_P038_MAP24_UNLOAD logical_tic=%d state_hash=%d", logicalTic, DSP038GroundStateHash());
    }

    override void WorldTick()
    {
        if (level == null || level.MapName != MAP || completed) return;
        if (!startedThisProcess)
        {
            startedThisProcess = true;
            if (started && activeMode == "save" && !restoredStateReported)
            {
                int restoredHash = DSP038GroundStateHash();
                bool same = restoredHash == saveStateHash
                    && logicalTic == saveLogicalTic;
                Console.Printf("DS_P038_MAP24_RESTORE accepted=%d first_tick=1 logical_tic=%d saved_tic=%d state_hash=%d saved_hash=%d fields=%d bottles=%d hit_ledger=%d", same ? 1 : 0, logicalTic, saveLogicalTic, restoredHash, saveStateHash, dsp038FieldActive.Size(), dsp038BottleActive.Size(), dsp038HitFieldId.Size());
                restoredStateReported = true;
                saveHold = false;
                SyncFieldProxies();
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
        if (activeMode == "bora_motion" && !playerMoved && logicalTic == 25)
        {
            double beforeX = playerX; double beforeY = playerY;
            playerX = 20.0; playerY = 30.0;
            x[playerSlot] = playerX; y[playerSlot] = playerY;
            playerMoved = true;
            Console.Printf("DS_P038_MAP24_PLAYER_MOVE accepted=1 tic=%d before_x=%.3f before_y=%.3f after_x=%.3f after_y=%.3f classification=CONTROLLED_PLAYER_MOVE", logicalTic, beforeX, beforeY, playerX, playerY);
        }
        if (activeMode == "bora_motion" && !worldRebased && logicalTic == 35)
        {
            ApplyWorldRebase(200.0, -75.0);
            worldRebased = true;
        }
        if (activeMode == "transform" && !transformDone && logicalTic == 100)
        {
            bool accepted = DSP038TransformWeapon(weaponSlot,
                generations[weaponSlot], ids[weaponSlot],
                DSP038GroundRows.SYSTEM_HOLYWATER,
                DSP038GroundRows.SYSTEM_BORA, 1, 2, true);
            Console.Printf("DS_P038_MAP24_TRANSFORM accepted=%d tic=%d dependency_present=1 source_inventory_claim=0", accepted ? 1 : 0, logicalTic);
            transformDone = accepted;
        }
        DSP024Rebuild();
        DSP038ProcessGroundTic(logicalTic, playerX, playerY,
            dsp033ResolvedValid
                ? DSP033Resolved(DSP033StatRules.STAT_MIGHT) : 1000,
            dsp033ResolvedValid
                ? DSP033Resolved(DSP033StatRules.STAT_COOLDOWN) : 1000);
        if (activeMode == "bora_motion" && !boraScheduleStopped
            && logicalTic >= 35)
        {
            int activeWeapon = DSP038FindWeapon(weaponSlot,
                generations[weaponSlot], ids[weaponSlot]);
            if (activeWeapon >= 0
                && dsp038WeaponVolleyRemaining[activeWeapon] == 0)
            {
                dsp038WeaponActive[activeWeapon] = 0;
                boraScheduleStopped = true;
                Console.Printf("DS_P038_MAP24_FIXTURE_CUTOFF accepted=1 tic=%d system_id=47 reason=ONE_VOLLEY_MOTION_WINDOW", logicalTic);
            }
        }
        if (activeMode == "high_area_duration" && !highStatScheduleStopped
            && logicalTic >= 35)
        {
            int activeWeapon = DSP038FindWeapon(weaponSlot,
                generations[weaponSlot], ids[weaponSlot]);
            if (activeWeapon >= 0
                && dsp038WeaponVolleyRemaining[activeWeapon] == 0)
            {
                dsp038WeaponActive[activeWeapon] = 0;
                highStatScheduleStopped = true;
                Console.Printf("DS_P038_MAP24_FIXTURE_CUTOFF accepted=1 tic=%d system_id=46 reason=ONE_VOLLEY_HIGH_AREA_DURATION_WINDOW", logicalTic);
            }
        }
        if (activeMode == "bora_motion" && (logicalTic == 25 || logicalTic == 35 || logicalTic == 100))
            EmitActiveFieldSnapshot(logicalTic == 25 ? "AFTER_PLAYER_MOVE" : logicalTic == 35 ? "AFTER_REBASE" : "GROWTH_CAP_CHECK");
        if (activeMode == "save" && !saveSnapshotEmitted && logicalTic == 35)
        {
            saveLogicalTic = logicalTic;
            saveStateHash = DSP038GroundStateHash();
            saveSnapshotEmitted = true;
            saveHold = true;
            Console.Printf("DS_P038_MAP24_SAVE_STATE accepted=1 logical_tic=%d state_hash=%d fields=%d bottles=%d hit_ledger=%d source=ACTIVE_FIELD_AND_HIT_LEDGER", saveLogicalTic, saveStateHash, dsp038FieldActive.Size(), dsp038BottleActive.Size(), dsp038HitFieldId.Size());
        }
        int proxies = SyncFieldProxies();
        SendInterfaceEvent(consoleplayer, "P038_MAP24_UI_STATE",
            logicalTic, DSP038GroundStateHash(), activeMode == "pause" ? 1 : 0);
        if (logicalTic == 20)
            Console.Printf("DS_P038_MAP24_PRESENTATION fields=%d proxies=%d vfx=%d source=LOGICAL_FIELD_POSITIONS collision_authority=NONE", dsp038DepositedFields, proxies, visualToggle);
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
        if (logicalTic >= finishAtTic) EmitResult(proxies);
    }
}
