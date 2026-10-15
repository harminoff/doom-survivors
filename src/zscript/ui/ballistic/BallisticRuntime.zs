// MAP21 controlled P035 harness. All inventory, rank and target state below
// are test fixtures; attacks and hits still use the shared production runtime.
class DSP035BallisticRuntime : EventHandler
{
    mixin DSRunStatFields;
    mixin DSP020EntityStore;
    mixin DSP024SpatialIndex;
    mixin DSP025AttackCore;
    mixin DSP033ResolvedStats;
    mixin DSP035BallisticTargeting;
    mixin DSP035BallisticProjectileRuntime;

    const MAP = "MAP21";
    const ENEMY_KIND = 1;
    const PLAYER_KIND = 99;
    const WEAPON_KIND = 90;
    const EXPECTED_REPORT_ROWS = 18;

    bool started;
    bool enabled;
    bool completed;
    bool captureRequested;
    bool captureFlushed;
    bool rankMatrixReported;
    bool transformReported;
    bool transformAccepted;
    int logicalTic;
    int tic;
    String activeMode;
    int cameraVariant;
    int cameraYaw;
    int cameraPitch;
    int cameraFov;
    int playerSlot;
    int axeRankEightSlot;
    int fireRankEightSlot;
    int rankRowsPassed;
    int rankChildEvents;
    int initialAcceptedHits;
    int deathCallbacks;
    int arcTargetId;
    int sweepTargetId;
    int edgePhase;
    int edgePhaseStartTic;
    int pierceAnchorId;
    bool arcHitReported;
    bool sweepReported;
    bool pierceTargetsSpawned;
    Array<int> pierceTargetIds;
    double playerX;
    double playerY;
    Array<int> targetSlots;
    Array<int> fixtureSystems;
    Array<int> fixtureRanks;
    Array<int> fixtureWeaponSlots;

    override void OnRegister()
    {
        IsUiProcessor = false;
        RequireMouse = false;
    }

    int ReadCameraVariant()
    {
        CVar camera = CVar.FindCVar("ds_p035_camera_variant");
        int variant = camera != null ? camera.GetInt() : 0;
        return variant >= 0 && variant <= 2 ? variant : 0;
    }

    void ConfigureCamera()
    {
        cameraVariant = ReadCameraVariant();
        cameraYaw = cameraVariant == 1 ? 90 : 0;
        cameraPitch = cameraVariant == 2 ? 22 : 0;
        cameraFov = cameraVariant == 2 ? 115 : 90;
        if (players[0].mo != null)
        {
            players[0].mo.Angle = cameraYaw;
            players[0].mo.Pitch = cameraPitch;
            players[0].SetFOV(cameraFov);
        }
        Console.Printf("DS_P035_MAP21_CAMERA variant=%d yaw=%d pitch=%d fov=%d source=UZDOOM_PLAYER_VIEW", cameraVariant, cameraYaw, cameraPitch, cameraFov);
    }

    String ReadMode()
    {
        CVar mode = CVar.FindCVar("ds_p035_mode");
        return mode != null ? mode.GetString() : "matrix";
    }

    int RankLimit(int systemId)
    {
        return systemId == DSP035WeaponRows.SYSTEM_AXE
            || systemId == DSP035WeaponRows.SYSTEM_FIRE_WAND ? 8 : 1;
    }

    bool ReadRankRow(int systemId, int rank,
        out int damageTenths, out int amount, out int pierce,
        out int cooldownMillis, out int childIntervalMillis,
        out int speedMultiplierMilli, out int areaMultiplierMilli,
        out int launchSpeedUnitsPerSecond,
        out int accelerationYUnitsPerSecondSquared,
        out int maxRangeUnits, out int lifetimeTics,
        out int collisionRadiusMilliUnits, out int poolLimitInstances,
        out int pathKind, out int targetPolicy, out int wallPolicy,
        out int spreadStepMilliDegrees, out int radialChildCount)
    {
        return DSP035WeaponRows.TryGetRankRow(systemId, rank,
            damageTenths, amount, pierce, cooldownMillis,
            childIntervalMillis, speedMultiplierMilli, areaMultiplierMilli,
            launchSpeedUnitsPerSecond,
            accelerationYUnitsPerSecondSquared, maxRangeUnits, lifetimeTics,
            collisionRadiusMilliUnits, poolLimitInstances, pathKind,
            targetPolicy, wallPolicy, spreadStepMilliDegrees,
            radialChildCount);
    }

    int EmitCompiledRows()
    {
        int rowCount = 0;
        int reportedRankRows = 0;
        for (int systemId = DSP035WeaponRows.SYSTEM_AXE;
             systemId <= DSP035WeaponRows.SYSTEM_HELLFIRE; systemId++)
        {
            int rankLimit = RankLimit(systemId);
            for (int rank = 1; rank <= rankLimit; rank++)
            {
                int damage; int amount; int pierce;
                int cooldown; int interval; int speed; int area;
                int launchSpeed; int accelerationY; int maxRange;
                int lifetime; int radius; int pool;
                int path; int targetPolicy; int wallPolicy;
                int spread; int radialCount;
                if (!ReadRankRow(systemId, rank, damage, amount, pierce,
                        cooldown, interval, speed, area, launchSpeed,
                        accelerationY, maxRange, lifetime, radius, pool,
                        path, targetPolicy, wallPolicy, spread, radialCount))
                {
                    Console.Printf("DS_ASSERT_FAIL P035_MAP21_COMPILED_ROW_MISSING system_id=%d rank=%d", systemId, rank);
                    continue;
                }
                rowCount++;
                if (systemId == DSP035WeaponRows.SYSTEM_AXE
                    || systemId == DSP035WeaponRows.SYSTEM_FIRE_WAND)
                    reportedRankRows++;
                Console.Printf("DS_P035_MAP21_ROW system_id=%d rank=%d damage_tenths=%d amount=%d pierce=%d cooldown_milliseconds=%d child_interval_milliseconds=%d speed_multiplier_milli=%d area_multiplier_milli=%d launch_speed_units_per_second=%d acceleration_y_units_per_second_squared=%d max_range_units=%d lifetime_tics=%d collision_radius_milliunits=%d pool_limit_instances=%d path_kind=%d target_policy=%d wall_policy=%d spread_step_millidegrees=%d radial_child_count=%d fixture=COMPILED_JSON_MIRROR", systemId, rank, damage, amount, pierce, cooldown, interval, speed, area, launchSpeed, accelerationY, maxRange, lifetime, radius, pool, path, targetPolicy, wallPolicy, spread, radialCount);
            }
        }
        Console.Printf("DS_P035_MAP21_ROW_COUNT rows=%d expected=%d", rowCount, EXPECTED_REPORT_ROWS);

        for (int evolvedId = DSP035WeaponRows.SYSTEM_DEATH_SPIRAL;
             evolvedId <= DSP035WeaponRows.SYSTEM_HELLFIRE; evolvedId += 2)
        {
            int sourceId; int sourceRank;
            int dependencyKind; int dependencyRank;
            bool found = DSP035WeaponRows.TryGetTransformation(evolvedId,
                sourceId, sourceRank, dependencyKind, dependencyRank);
            Console.Printf("DS_P035_MAP21_TRANSFORM_ROW accepted=%d evolved_system_id=%d source_system_id=%d source_rank=%d dependency_kind=%d dependency_min_rank=%d dependency_rank_provenance=ENGINEERING_APPROXIMATION", found ? 1 : 0, evolvedId, sourceId, sourceRank, dependencyKind, dependencyRank);
        }
        return rowCount;
    }

    void SpawnTarget(double targetX, double targetY, int targetHealth,
        double targetRadius)
    {
        int slot = Allocate(ENEMY_KIND, targetX, targetY, 0.0, 0.0,
            targetHealth);
        collisionRadii[slot] = targetRadius;
        targetSlots.Push(slot);
    }

    bool SetupTargets()
    {
        targetSlots.Clear();
        // Symmetric controlled targets let each path produce deterministic
        // actual hits while leaving random-target selection genuinely random
        // over a stable live set. Locations are engine fixtures, not source.
        for (int degrees = 0; degrees < 360; degrees += 45)
        {
            double angle = double(degrees);
            double dx = cos(angle); double dy = sin(angle);
            SpawnTarget(playerX + dx * 72.0, playerY + dy * 72.0,
                10000000, 4.0);
            SpawnTarget(playerX + dx * 144.0, playerY + dy * 144.0,
                10000000, 4.0);
        }
        return targetSlots.Size() == 16;
    }

    bool EquipAllRankRows()
    {
        fixtureSystems.Clear();
        fixtureRanks.Clear();
        fixtureWeaponSlots.Clear();
        axeRankEightSlot = -1;
        fireRankEightSlot = -1;
        int ordinal = 0;
        for (int systemId = DSP035WeaponRows.SYSTEM_AXE;
             systemId <= DSP035WeaponRows.SYSTEM_HELLFIRE; systemId++)
        {
            int rankLimit = RankLimit(systemId);
            for (int rank = 1; rank <= rankLimit; rank++)
            {
                int weaponSlot = Allocate(WEAPON_KIND, 0.0, 0.0,
                    0.0, 0.0, 1);
                int firstFireTic = 1 + ordinal * 2;
                if (!DSP035EquipFixture(systemId, rank, weaponSlot,
                        firstFireTic))
                {
                    Console.Printf("DS_ASSERT_FAIL P035_MAP21_FIXTURE_EQUIP system_id=%d rank=%d", systemId, rank);
                    return false;
                }
                fixtureSystems.Push(systemId);
                fixtureRanks.Push(rank);
                fixtureWeaponSlots.Push(weaponSlot);
                if (systemId == DSP035WeaponRows.SYSTEM_AXE && rank == 8)
                    axeRankEightSlot = weaponSlot;
                if (systemId == DSP035WeaponRows.SYSTEM_FIRE_WAND && rank == 8)
                    fireRankEightSlot = weaponSlot;
                Console.Printf("DS_P035_MAP21_FIXTURE system_id=%d rank=%d weapon_id=%d first_fire_tic=%d class=CONTROLLED source_inventory_claim=0", systemId, rank, ids[weaponSlot], firstFireTic);
                ordinal++;
            }
        }
        return ordinal == EXPECTED_REPORT_ROWS
            && axeRankEightSlot >= 0 && fireRankEightSlot >= 0;
    }

    bool StartScenario()
    {
        activeMode = ReadMode();
        if (activeMode != "matrix" && activeMode != "wall"
            && activeMode != "arc" && activeMode != "edge"
            && activeMode != "no_target")
        {
            Console.Printf("DS_ASSERT_FAIL P035_MAP21_MODE_UNSUPPORTED mode=%s expected=matrix_wall_arc_edge_no_target", activeMode);
            return false;
        }
        enabled = false; completed = false;
        captureRequested = false; captureFlushed = false;
        rankMatrixReported = false; transformReported = false;
        transformAccepted = false;
        logicalTic = 0; tic = 0; deathCallbacks = 0;
        rankRowsPassed = 0; rankChildEvents = 0; initialAcceptedHits = 0;
        arcTargetId = 0; sweepTargetId = 0; edgePhase = 0;
        edgePhaseStartTic = 0; pierceAnchorId = 0;
        arcHitReported = false; sweepReported = false;
        pierceTargetsSpawned = false; pierceTargetIds.Clear();
        playerX = 0.0; playerY = 0.0;
        Reset();
        DSP024ClearSpatial();
        DSP035ResetBallisticRuntime(350035);
        DSP033SetBaseStats(1000, 0, 120000, 1000);
        if (!DSP033RecomputeFromRanks(5, 0, 0, 5))
        {
            Console.Printf("DS_ASSERT_FAIL P035_MAP21_STAT_FIXTURE_REJECTED");
            return false;
        }
        ConfigureCamera();
        playerSlot = Allocate(PLAYER_KIND, playerX, playerY,
            0.0, 0.0, 1);
        int rows = EmitCompiledRows();
        bool targetsOk;
        bool weaponsOk;
        if (activeMode == "wall")
        {
            targetSlots.Clear();
            SpawnTarget(playerX, playerY + 40.0, 10000000, 4.0);
            targetsOk = targetSlots.Size() == 1;
            bool wallOk = DSP035AddLogicalWall(1, -300.0, 10.0,
                300.0, 10.0);
            int fireSlot = Allocate(WEAPON_KIND, 0.0, 0.0, 0.0, 0.0, 1);
            int hellSlot = Allocate(WEAPON_KIND, 0.0, 0.0, 0.0, 0.0, 1);
            bool fireOk = DSP035EquipFixture(
                DSP035WeaponRows.SYSTEM_FIRE_WAND, 1, fireSlot, 1);
            bool hellOk = DSP035EquipFixture(
                DSP035WeaponRows.SYSTEM_HELLFIRE, 1, hellSlot, 1);
            weaponsOk = wallOk && fireOk && hellOk;
            Console.Printf("DS_P035_MAP21_WALL_FIXTURE accepted=%d wall_id=1 wall_y=10 anchor_id=%d anchor_y=40 fire_weapon_id=%d hellfire_weapon_id=%d classification=CONTROLLED_SOURCE_PLANE_FIXTURE", weaponsOk && targetsOk ? 1 : 0, ids[targetSlots[0]], ids[fireSlot], ids[hellSlot]);
        }
        else if (activeMode == "arc")
        {
            targetSlots.Clear();
            targetsOk = true;
            int axeSlot = Allocate(WEAPON_KIND, 0.0, 0.0, 0.0, 0.0, 1);
            weaponsOk = DSP035EquipFixture(DSP035WeaponRows.SYSTEM_AXE,
                1, axeSlot, 1);
            fixtureSystems.Push(DSP035WeaponRows.SYSTEM_AXE);
            fixtureRanks.Push(1); fixtureWeaponSlots.Push(axeSlot);
            Console.Printf("DS_P035_MAP21_ARC_SETUP accepted=%d system_id=38 rank=1 first_fire_tic=1 target_spawn_tic=30 target_x=0 target_y=100 target_radius=4 classification=CONTROLLED_LATE_SPAWN", weaponsOk ? 1 : 0);
        }
        else if (activeMode == "edge")
        {
            targetSlots.Clear();
            SpawnTarget(playerX, playerY + 280.0, 10000000, 4.0);
            int fireSlot = Allocate(WEAPON_KIND, 0.0, 0.0, 0.0, 0.0, 1);
            weaponsOk = targetSlots.Size() == 1
                && DSP035EquipFixture(DSP035WeaponRows.SYSTEM_FIRE_WAND,
                    8, fireSlot, 1);
            fixtureSystems.Push(DSP035WeaponRows.SYSTEM_FIRE_WAND);
            fixtureRanks.Push(8); fixtureWeaponSlots.Push(fireSlot);
            int fireWeaponId = ids[fireSlot];
            Console.Printf("DS_P035_MAP21_EDGE_SETUP accepted=%d phase=SWEEP system_id=40 rank=8 weapon_id=%d anchor_id=%d anchor_x=0 anchor_y=280 classification=CONTROLLED", weaponsOk ? 1 : 0, fireWeaponId, ids[targetSlots[0]]);
            targetsOk = targetSlots.Size() == 1;
        }
        else if (activeMode == "no_target")
        {
            targetSlots.Clear();
            int fireSlot = Allocate(WEAPON_KIND, 0.0, 0.0, 0.0, 0.0, 1);
            weaponsOk = DSP035EquipFixture(DSP035WeaponRows.SYSTEM_FIRE_WAND,
                1, fireSlot, 1);
            fixtureSystems.Push(DSP035WeaponRows.SYSTEM_FIRE_WAND);
            fixtureRanks.Push(1); fixtureWeaponSlots.Push(fireSlot);
            targetsOk = true;
            Console.Printf("DS_P035_MAP21_NO_TARGET_SETUP accepted=%d system_id=40 rank=1 first_fire_tic=1 target_count=0 rng_seed=350035 classification=CONTROLLED", weaponsOk ? 1 : 0);
        }
        else
        {
            targetsOk = SetupTargets();
            weaponsOk = EquipAllRankRows();
        }
        DSP024Rebuild();
        bool setupOk = rows == EXPECTED_REPORT_ROWS
            && targetsOk && weaponsOk && playerSlot >= 0;
        Console.Printf("DS_BOOT map=MAP21 classification=CONTROLLED_P035_BALLISTIC_RUNTIME_HARNESS");
        int equippedCount = activeMode == "matrix" ? fixtureSystems.Size()
            : activeMode == "wall" ? 2 : 1;
        Console.Printf("DS_P035_MAP21_BOOT accepted=%d mode=%s camera_variant=%d targets=%d equipped_rank_rows=%d source_inventory_claim=0 might_milli=%d cooldown_multiplier_milli=%d rank_hash=%d", setupOk ? 1 : 0, activeMode, cameraVariant, targetSlots.Size(), equippedCount, dsp033ResolvedMightMilli, dsp033ResolvedCooldownMultiplierMilli, dsp033ResolvedRankHash);
        if (!setupOk) Console.Printf("DS_ASSERT_FAIL P035_MAP21_SCENARIO_SETUP");
        enabled = setupOk;
        started = true;
        return setupOk;
    }

    bool CheckInitialRankMatrix()
    {
        bool accepted = true;
        int rows = 0;
        int childrenTotal = 0;
        for (int i = 0; i < fixtureSystems.Size(); i++)
        {
            int systemId = fixtureSystems[i];
            int rank = fixtureRanks[i];
            int damage; int amount; int pierce;
            int cooldown; int interval; int speed; int area;
            int launchSpeed; int accelerationY; int maxRange;
            int lifetime; int radius; int pool;
            int path; int targetPolicy; int wallPolicy;
            int spread; int radialCount;
            bool rowFound = ReadRankRow(systemId, rank, damage, amount,
                pierce, cooldown, interval, speed, area, launchSpeed,
                accelerationY, maxRange, lifetime, radius, pool, path,
                targetPolicy, wallPolicy, spread, radialCount);
            int childCount = 0;
            int ordinalMask = 0;
            for (int p = 0; p < dsp035ProjectileEvents.Size(); p++)
            {
                if (dsp035ProjectileSystems[p] != systemId
                    || dsp035ProjectileRanks[p] != rank) continue;
                childCount++;
                int childOrdinal = dsp035ProjectileChildOrdinals[p];
                if (childOrdinal >= 0 && childOrdinal < 30)
                    ordinalMask |= 1 << childOrdinal;
            }
            int expectedMask = (1 << amount) - 1;
            bool rowOk = rowFound && childCount == amount
                && ordinalMask == expectedMask;
            if (!rowOk) accepted = false;
            else rows++;
            childrenTotal += childCount;
            Console.Printf("DS_P035_MAP21_RANK_RESULT system_id=%d rank=%d accepted=%d expected_children=%d actual_children=%d ordinal_mask=%d expected_ordinal_mask=%d first_volley_tic=%d source=ACTUAL_UZDOOM", systemId, rank, rowOk ? 1 : 0, amount, childCount, ordinalMask, expectedMask, 1 + i * 2);
        }
        rankRowsPassed = rows;
        rankChildEvents = childrenTotal;
        rankMatrixReported = accepted && rows == EXPECTED_REPORT_ROWS;
        Console.Printf("DS_P035_MAP21_RANK_MATRIX accepted=%d rows=%d expected_rows=%d child_events=%d expected_child_events=54 evidence=ACTUAL_UZDOOM", rankMatrixReported ? 1 : 0, rows, EXPECTED_REPORT_ROWS, childrenTotal);
        if (!rankMatrixReported)
            Console.Printf("DS_ASSERT_FAIL P035_MAP21_RANK_MATRIX_INCOMPLETE rows=%d children=%d", rows, childrenTotal);
        return rankMatrixReported;
    }

    bool TransformMaxRankFixtures()
    {
        bool axeAccepted = DSP035ReplaceFixture(axeRankEightSlot,
            DSP035WeaponRows.SYSTEM_DEATH_SPIRAL, 1, logicalTic,
            true, 1);
        bool fireAccepted = DSP035ReplaceFixture(fireRankEightSlot,
            DSP035WeaponRows.SYSTEM_HELLFIRE, 1, logicalTic,
            true, 1);
        transformAccepted = axeAccepted && fireAccepted;
        transformReported = true;
        Console.Printf("DS_P035_MAP21_TRANSFORM_RESULT accepted=%d axe=%d fire=%d source_rank=8 dependency_rank=1 dependency_rank_class=CONTROLLED_APPROXIMATION", transformAccepted ? 1 : 0, axeAccepted ? 1 : 0, fireAccepted ? 1 : 0);
        if (!transformAccepted)
            Console.Printf("DS_ASSERT_FAIL P035_MAP21_TRANSFORM_REJECTED");
        return transformAccepted;
    }

    void HandleEnemyDeath(int slot, int beforeHealth, int eventId)
    {
        if (slot < 0 || slot >= lifeStates.Size()
            || lifeStates[slot] != STORE_ALIVE) return;
        deathCallbacks++;
        Console.Printf("DS_P035_MAP21_DEATH event_id=%d tic=%d target_id=%d before=%d", eventId, tic, ids[slot], beforeHealth);
        DestroyParts(slot, generations[slot], ids[slot]);
    }

    int HitsForSystem(int systemId)
    {
        int result = 0;
        for (int i = 0; i < dsp035ProjectileSystems.Size(); i++)
            if (dsp035ProjectileSystems[i] == systemId)
                result += dsp035ProjectileHitCount[i];
        return result;
    }

    void EmitPass()
    {
        int axeHits = HitsForSystem(DSP035WeaponRows.SYSTEM_AXE);
        int spiralHits = HitsForSystem(DSP035WeaponRows.SYSTEM_DEATH_SPIRAL);
        int fireHits = HitsForSystem(DSP035WeaponRows.SYSTEM_FIRE_WAND);
        int hellfireHits = HitsForSystem(DSP035WeaponRows.SYSTEM_HELLFIRE);
        int acceptedHits = dsp035AcceptedHits;
        bool allFormsHit = axeHits > 0 && spiralHits > 0
            && fireHits > 0 && hellfireHits > 0;
        bool pass = rankMatrixReported && transformAccepted
            && allFormsHit && rankRowsPassed == EXPECTED_REPORT_ROWS
            && rankChildEvents == 54 && acceptedHits > 0
            && dsp035RejectedHits == 0 && captureFlushed;
        Console.Printf("DS_P035_MAP21_SUMMARY logical_tics=%d rank_rows=%d rank_children=%d axe_hits=%d death_spiral_hits=%d fire_wand_hits=%d hellfire_hits=%d accepted_hits=%d rejected_hits=%d death_callbacks=%d transforms=%d camera_variant=%d", logicalTic, rankRowsPassed, rankChildEvents, axeHits, spiralHits, fireHits, hellfireHits, acceptedHits, dsp035RejectedHits, deathCallbacks, transformAccepted ? 2 : 0, cameraVariant);
        if (!pass)
        {
            Console.Printf("DS_ASSERT_FAIL P035_MAP21_REQUIRED_RUNTIME_EVIDENCE_MISSING rank_matrix=%d transforms=%d forms_hit=%d capture=%d", rankMatrixReported ? 1 : 0, transformAccepted ? 1 : 0, allFormsHit ? 1 : 0, captureFlushed ? 1 : 0);
            return;
        }
        completed = true;
        Console.Printf("DS_P035_MAP21_RUNTIME_PASS rank_rows=18 first_volley_children=54 actual_hits=1 transformations=2 camera_variant=%d classification=CONTROLLED_QUALIFIED_BALLISTIC_ADAPTER", cameraVariant);
    }

    void EmitWallScenarioResult()
    {
        int fireHits = HitsForSystem(DSP035WeaponRows.SYSTEM_FIRE_WAND);
        int hellHits = HitsForSystem(DSP035WeaponRows.SYSTEM_HELLFIRE);
        bool passed = fireHits == 0 && hellHits > 0
            && dsp035RejectedHits == 0 && captureFlushed;
        Console.Printf("DS_P035_MAP21_WALL_RESULT accepted=%d fire_blocked_hits=%d hellfire_pass_hits=%d rejected_hits=%d evidence=ACTUAL_UZDOOM", passed ? 1 : 0, fireHits, hellHits, dsp035RejectedHits);
        if (!passed)
        {
            Console.Printf("DS_ASSERT_FAIL P035_MAP21_WALL_POLICY_RESULT fire_hits=%d hellfire_hits=%d", fireHits, hellHits);
            Console.Printf("DS_P035_MAP21_EDGE_FAIL mode=wall");
            completed = true;
            return;
        }
        completed = true;
        Console.Printf("DS_P035_MAP21_EDGE_PASS mode=wall fire_block=1 hellfire_pass=1 classification=CONTROLLED_SOURCE_PLANE_FIXTURE");
    }

    bool HasHitTarget(int stableId, out int projectileEvent)
    {
        projectileEvent = 0;
        if (stableId <= 0) return false;
        for (int i = 0; i < dsp035HitTargetIds.Size(); i++)
        {
            if (dsp035HitTargetIds[i] != stableId) continue;
            projectileEvent = dsp035HitProjectileEvents[i];
            return true;
        }
        return false;
    }

    void BeginPiercePhase()
    {
        for (int i = 0; i < targetSlots.Size(); i++)
        {
            int slot = targetSlots[i];
            if (slot >= 0 && slot < lifeStates.Size()
                && lifeStates[slot] == STORE_ALIVE)
                DestroyParts(slot, generations[slot], ids[slot]);
        }
        targetSlots.Clear();
        pierceTargetIds.Clear();
        pierceAnchorId = 0;
        SpawnTarget(playerX, playerY + 280.0, 10000000, 4.0);
        if (targetSlots.Size() == 1) pierceAnchorId = ids[targetSlots[0]];
        int weaponSlot = Allocate(WEAPON_KIND, 0.0, 0.0, 0.0, 0.0, 1);
        int firstFire = logicalTic + 1;
        bool equipped = DSP035EquipFixture(
            DSP035WeaponRows.SYSTEM_HELLFIRE, 1, weaponSlot, firstFire);
        fixtureSystems.Push(DSP035WeaponRows.SYSTEM_HELLFIRE);
        fixtureRanks.Push(1); fixtureWeaponSlots.Push(weaponSlot);
        edgePhase = 1;
        edgePhaseStartTic = logicalTic;
        pierceTargetsSpawned = false;
        DSP024Rebuild();
        Console.Printf("DS_P035_MAP21_EDGE_SETUP accepted=%d phase=PIERCE system_id=41 rank=1 weapon_id=%d first_fire_tic=%d anchor_id=%d anchor_x=0 anchor_y=280 classification=CONTROLLED", equipped && pierceAnchorId > 0 ? 1 : 0, ids[weaponSlot], firstFire, pierceAnchorId);
    }

    void SpawnPierceTargets()
    {
        double ux = cos(82.5);
        double uy = sin(82.5);
        for (int i = 0; i < 3; i++)
        {
            double distance = i == 0 ? 25.0 : i == 1 ? 55.0 : 90.0;
            SpawnTarget(playerX + ux * distance,
                playerY + uy * distance, 10000000, 0.75);
            pierceTargetIds.Push(ids[targetSlots[targetSlots.Size() - 1]]);
            Console.Printf("DS_P035_MAP21_PIERCE_TARGET ordinal=%d target_id=%d distance=%.3f yaw_degrees=82.5 radius=0.75 classification=CONTROLLED", i, pierceTargetIds[i], distance);
        }
        DSP024Rebuild();
        pierceTargetsSpawned = true;
        Console.Printf("DS_P035_MAP21_PIERCE_FIXTURE accepted=%d anchor_id=%d targets=%d expected_child_yaw_milli=82500", pierceTargetIds.Size() == 3 ? 1 : 0, pierceAnchorId, pierceTargetIds.Size());
    }

    void EmitArcScenarioResult()
    {
        int eventId = 0;
        bool accepted = HasHitTarget(arcTargetId, eventId);
        Console.Printf("DS_P035_MAP21_ARC_RESULT accepted=%d target_id=%d projectile_event_id=%d target_spawn_tic=30 expected_direction=FALLING_SOURCE_PLANE", accepted ? 1 : 0, arcTargetId, eventId);
        if (!accepted || dsp035RejectedHits != 0)
        {
            Console.Printf("DS_ASSERT_FAIL P035_MAP21_FALLING_ARC_HIT_MISSING target_id=%d", arcTargetId);
            completed = true;
            return;
        }
        completed = true;
        Console.Printf("DS_P035_MAP21_EDGE_PASS mode=arc falling_hit=1 classification=CONTROLLED_LATE_SPAWN");
    }

    void EmitEdgeScenarioResult()
    {
        int childEvent = 0;
        for (int p = 0; p < dsp035ProjectileEvents.Size(); p++)
            if (dsp035ProjectileSystems[p] == DSP035WeaponRows.SYSTEM_HELLFIRE
                && dsp035ProjectileChildOrdinals[p] == 0)
            { childEvent = dsp035ProjectileEvents[p]; break; }
        int hits = 0; int firstId = 0; int secondId = 0; int thirdId = 0;
        for (int h = 0; h < dsp035HitProjectileEvents.Size(); h++)
        {
            if (dsp035HitProjectileEvents[h] != childEvent) continue;
            if (hits == 0) firstId = dsp035HitTargetIds[h];
            else if (hits == 1) secondId = dsp035HitTargetIds[h];
            else if (hits == 2) thirdId = dsp035HitTargetIds[h];
            hits++;
        }
        bool orderOk = childEvent > 0 && hits >= 3
            && firstId == pierceTargetIds[0]
            && secondId == pierceTargetIds[1]
            && thirdId == pierceTargetIds[2];
        Console.Printf("DS_P035_MAP21_PIERCE_RESULT accepted=%d projectile_event_id=%d hit_count=%d first_id=%d second_id=%d third_id=%d expected_first=%d expected_second=%d expected_third=%d", orderOk ? 1 : 0, childEvent, hits, firstId, secondId, thirdId, pierceTargetIds.Size() > 0 ? pierceTargetIds[0] : 0, pierceTargetIds.Size() > 1 ? pierceTargetIds[1] : 0, pierceTargetIds.Size() > 2 ? pierceTargetIds[2] : 0);
        bool passed = sweepReported && orderOk && dsp035RejectedHits == 0;
        if (!passed)
        {
            Console.Printf("DS_ASSERT_FAIL P035_MAP21_SWEEP_OR_PIERCE_FAILED sweep=%d order=%d rejected=%d", sweepReported ? 1 : 0, orderOk ? 1 : 0, dsp035RejectedHits);
            completed = true;
            return;
        }
        completed = true;
        Console.Printf("DS_P035_MAP21_EDGE_PASS mode=edge swept_graze=1 multi_target_order=1 classification=CONTROLLED_SOURCE_PLANE_FIXTURE");
    }

    void EmitNoTargetResult()
    {
        int rngBefore = 0; int rngAfter = 0; int emptyVolleys = 0;
        for (int i = 0; i < dsp035BurstRngBefore.Size(); i++)
        {
            if (dsp035BurstTargetPolicy[i] != DSP035WeaponRows.TARGET_RANDOM_LIVE_ENEMY_SNAPSHOT) continue;
            if (dsp035BurstTargetFound[i] == 0)
            {
                rngBefore = dsp035BurstRngBefore[i];
                rngAfter = dsp035BurstRngAfter[i];
                emptyVolleys++;
            }
        }
        bool skipped = false;
        for (int i = 0; i < dsp035SkippedChildren; i++) skipped = true;
        bool projectile = false;
        for (int i = 0; i < dsp035ProjectileSystems.Size(); i++)
            if (dsp035ProjectileSystems[i] == DSP035WeaponRows.SYSTEM_FIRE_WAND) projectile = true;
        bool passed = emptyVolleys > 0 && rngBefore == rngAfter
            && skipped && !projectile && dsp035AcceptedHits == 0;
        Console.Printf("DS_P035_MAP21_NO_TARGET_RESULT accepted=%d empty_volleys=%d rng_before=%d rng_after=%d projectile_created=%d accepted_hits=%d skipped_children=%d", passed ? 1 : 0, emptyVolleys, rngBefore, rngAfter, projectile ? 1 : 0, dsp035AcceptedHits, dsp035SkippedChildren);
        if (!passed)
        {
            Console.Printf("DS_ASSERT_FAIL P035_MAP21_NO_TARGET_RNG_OR_CHILD_POLICY");
            completed = true;
            return;
        }
        completed = true;
        Console.Printf("DS_P035_MAP21_EDGE_PASS mode=no_target rng_unchanged=1 child_skipped=1 classification=CONTROLLED_EMPTY_TARGET_SET");
    }

    override void WorldLoaded(WorldEvent e)
    {
        if (level == null || level.MapName != MAP || e.IsSaveGame) return;
        started = false; enabled = false; completed = false;
    }

    override void WorldTick()
    {
        if (level == null || level.MapName != MAP) return;
        if (!started && !StartScenario()) return;
        if (!enabled || completed) return;

        logicalTic++;
        tic = logicalTic;
        if (players[0].mo != null)
        {
            players[0].mo.Angle = cameraYaw;
            players[0].mo.Pitch = cameraPitch;
            players[0].SetFOV(cameraFov);
        }
        int viewYawMilli = cameraYaw * 1000;
        if (activeMode == "arc" && logicalTic == 30
            && arcTargetId == 0)
        {
            SpawnTarget(playerX, playerY + 100.0, 10000000, 4.0);
            arcTargetId = ids[targetSlots[targetSlots.Size() - 1]];
            Console.Printf("DS_P035_MAP21_ARC_TARGET accepted=1 tic=%d target_id=%d x=0 y=100 radius=4 classification=CONTROLLED_LATE_SPAWN", logicalTic, arcTargetId);
        }
        if (activeMode == "edge" && edgePhase == 0
            && logicalTic == 2 && sweepTargetId == 0)
        {
            SpawnTarget(playerX - 6.2, playerY + 50.9, 10000000, 0.5);
            sweepTargetId = ids[targetSlots[targetSlots.Size() - 1]];
            Console.Printf("DS_P035_MAP21_SWEEP_TARGET accepted=1 tic=%d target_id=%d x=-6.200 y=50.900 radius=0.500 centerline_yaw=90000 classification=CONTROLLED_GRAZING_FIXTURE", logicalTic, sweepTargetId);
        }
        DSP024Rebuild();
        if (activeMode == "wall")
        {
            DSP035ProcessBallisticTic(logicalTic, playerSlot,
                generations[playerSlot], ids[playerSlot], playerX, playerY,
                cameraYaw * 1000, dsp033ResolvedCooldownMultiplierMilli,
                dsp033ResolvedRankHash);
            if (!captureRequested && logicalTic >= 5)
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
            if (logicalTic >= 65) EmitWallScenarioResult();
            return;
        }
        if (activeMode == "arc")
        {
            DSP035ProcessBallisticTic(logicalTic, playerSlot,
                generations[playerSlot], ids[playerSlot], playerX, playerY,
                viewYawMilli, dsp033ResolvedCooldownMultiplierMilli,
                dsp033ResolvedRankHash);
            int arcEvent = 0;
            if (!arcHitReported && HasHitTarget(arcTargetId, arcEvent))
            {
                arcHitReported = true;
            }
            if (!captureRequested && logicalTic >= 40)
            {
                LevelLocals.MakeScreenShot();
                captureRequested = true;
                return;
            }
            if (captureRequested && !captureFlushed)
            { captureFlushed = true; return; }
            if (logicalTic >= 80) EmitArcScenarioResult();
            return;
        }
        if (activeMode == "edge")
        {
            DSP035ProcessBallisticTic(logicalTic, playerSlot,
                generations[playerSlot], ids[playerSlot], playerX, playerY,
                viewYawMilli, dsp033ResolvedCooldownMultiplierMilli,
                dsp033ResolvedRankHash);
            if (edgePhase == 0)
            {
                int sweepEvent = 0;
                if (!sweepReported && HasHitTarget(sweepTargetId, sweepEvent))
                {
                    sweepReported = true;
                    Console.Printf("DS_P035_MAP21_SWEEP_RESULT accepted=1 target_id=%d projectile_event_id=%d system_id=40 expected_child_ordinal=1 target_x=-6.200 target_y=50.900 target_radius=0.500 classification=CONTROLLED_GRAZING_FIXTURE", sweepTargetId, sweepEvent);
                    BeginPiercePhase();
                }
                if (!captureRequested && logicalTic >= 10)
                {
                    LevelLocals.MakeScreenShot();
                    captureRequested = true;
                    return;
                }
                if (captureRequested && !captureFlushed)
                { captureFlushed = true; return; }
                if (!sweepReported && logicalTic >= 30)
                {
                    Console.Printf("DS_ASSERT_FAIL P035_MAP21_SWEEP_GRAZE_MISSED target_id=%d", sweepTargetId);
                    completed = true;
                }
                return;
            }
            if (!pierceTargetsSpawned && logicalTic == edgePhaseStartTic + 1)
                SpawnPierceTargets();
            if (!captureRequested && logicalTic >= edgePhaseStartTic + 5)
            {
                LevelLocals.MakeScreenShot();
                captureRequested = true;
                return;
            }
            if (captureRequested && !captureFlushed)
            { captureFlushed = true; return; }
            if (logicalTic >= edgePhaseStartTic + 35)
                EmitEdgeScenarioResult();
            return;
        }
        if (activeMode == "no_target")
        {
            DSP035ProcessBallisticTic(logicalTic, playerSlot,
                generations[playerSlot], ids[playerSlot], playerX, playerY,
                viewYawMilli, dsp033ResolvedCooldownMultiplierMilli,
                dsp033ResolvedRankHash);
            if (!captureRequested && logicalTic >= 5)
            {
                LevelLocals.MakeScreenShot();
                captureRequested = true;
                return;
            }
            if (captureRequested && !captureFlushed)
            { captureFlushed = true; return; }
            if (logicalTic >= 8) EmitNoTargetResult();
            return;
        }
        if (logicalTic == 51)
        {
            bool ranksOk = CheckInitialRankMatrix();
            if (ranksOk)
            {
                for (int i = 0; i < dsp035NextVolleyMilliTics.Size(); i++)
                    dsp035NextVolleyMilliTics[i] = 2147483647;
                TransformMaxRankFixtures();
            }
        }
        DSP035ProcessBallisticTic(logicalTic, playerSlot,
            generations[playerSlot], ids[playerSlot], playerX, playerY,
            viewYawMilli, dsp033ResolvedCooldownMultiplierMilli,
            dsp033ResolvedRankHash);
        if (!captureRequested && logicalTic >= 22)
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
        if (logicalTic >= 90 && transformReported) EmitPass();
    }
}
