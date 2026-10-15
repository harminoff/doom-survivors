// MAP22 controlled P036 harness. The shared returning runtime owns all
// projectile legs, target snapshots and accepted hits; fixtures here create
// only the player, weapon handles and stationary test enemies.
class DSP036ReturningRuntime : EventHandler
{
    mixin DSRunStatFields;
    mixin DSP020EntityStore;
    mixin DSP024SpatialIndex;
    mixin DSP025AttackCore;
    mixin DSP033ResolvedStats;
    mixin DSP036ReturningTargeting;
    mixin DSP036ReturningProjectileRuntime;

    const MAP = "MAP22";
    const ENEMY_KIND = 1;
    const PLAYER_KIND = 99;
    const WEAPON_KIND = 90;
    const EXPECTED_ROWS = 9;

    bool started;
    bool enabled;
    bool completed;
    bool captureRequested;
    bool captureFlushed;
    int logicalTic;
    int tic;
    int cameraVariant;
    String activeMode;
    int playerSlot;
    int mainWeaponSlot;
    int selectedTargetId;
    int initialCritRng;
    bool transformationAccepted;
    bool playerMoved;
    bool worldRebased;
    double playerX;
    double playerY;
    Array<int> fixtureSystems;
    Array<int> fixtureRanks;
    Array<int> fixtureSlots;
    Array<int> targetSlots;

    override void OnRegister()
    {
        IsUiProcessor = false;
        RequireMouse = false;
    }

    int ReadCameraVariant()
    {
        CVar camera = CVar.FindCVar("ds_p036_camera_variant");
        int value = camera != null ? camera.GetInt() : 0;
        return value >= 0 && value <= 2 ? value : 0;
    }

    int ReadSeed()
    {
        CVar seedCVar = CVar.FindCVar("ds_p036_seed");
        int value = seedCVar != null ? seedCVar.GetInt() : 360036;
        return value != 0 ? value : 360036;
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
        Console.Printf("DS_P036_MAP22_CAMERA variant=%d yaw=%d pitch=%d fov=%d source=UZDOOM_PLAYER_VIEW", cameraVariant, yaw, pitch, fov);
    }

    int RankLimit(int systemId)
    {
        return systemId == DSP036ReturningRows.SYSTEM_CROSS ? 8 : 1;
    }

    bool EmitRows()
    {
        int rowCount = 0;
        for (int systemId = DSP036ReturningRows.SYSTEM_CROSS;
             systemId <= DSP036ReturningRows.SYSTEM_HEAVEN_SWORD;
             systemId++)
        {
            for (int rank = 1; rank <= RankLimit(systemId); rank++)
            {
                int damage; int area; int speed; int amount;
                int cooldown; int interval; int passLimit; int pool;
                int critChance; int critMultiplier; int luckAffectsCrit;
                bool rowFound = DSP036ReturningRows.TryGetRankRow(systemId,
                    rank, damage, area, speed, amount, cooldown, interval,
                    passLimit, pool, critChance, critMultiplier,
                    luckAffectsCrit);
                if (!rowFound)
                {
                    Console.Printf("DS_ASSERT_FAIL P036_MAP22_ROW_MISSING system_id=%d rank=%d", systemId, rank);
                    return false;
                }
                rowCount++;
                Console.Printf("DS_P036_MAP22_ROW system_id=%d rank=%d damage_tenths=%d area_multiplier_milli=%d speed_multiplier_milli=%d amount=%d cooldown_milliseconds=%d child_interval_milliseconds=%d pass_limit=%d pool_limit_instances=%d crit_chance_permille=%d crit_multiplier_milli=%d luck_affects_crit=%d", systemId, rank, damage, area, speed, amount, cooldown, interval, passLimit, pool, critChance, critMultiplier, luckAffectsCrit);
            }
        }

        for (int systemId = DSP036ReturningRows.SYSTEM_CROSS;
             systemId <= DSP036ReturningRows.SYSTEM_HEAVEN_SWORD;
             systemId++)
        {
            int launchSpeed; int outboundBase; int reverseFactor;
            int totalFactor; int lifetime; int baseRadius;
            int pathKind; int targetPolicy; int returnPolicy;
            int wallPolicy; int passesPerLeg;
            bool profileFound = DSP036ReturningRows.TryGetFlightProfile(
                systemId, launchSpeed, outboundBase, reverseFactor,
                totalFactor, lifetime, baseRadius, pathKind, targetPolicy,
                returnPolicy, wallPolicy, passesPerLeg);
            if (!profileFound)
            {
                Console.Printf("DS_ASSERT_FAIL P036_MAP22_PROFILE_MISSING system_id=%d", systemId);
                return false;
            }
            Console.Printf("DS_P036_MAP22_PROFILE system_id=%d launch_speed_units_per_second=%d outbound_base_units=%d reverse_distance_factor_milli=%d total_distance_factor_milli=%d lifetime_tics=%d base_radius_milliunits=%d path_kind=%d target_policy=%d return_policy=%d wall_policy=%d passes_per_leg=%d", systemId, launchSpeed, outboundBase, reverseFactor, totalFactor, lifetime, baseRadius, pathKind, targetPolicy, returnPolicy, wallPolicy, passesPerLeg);
        }
        int evolved; int sourceRank; int dependency; int dependencyRank;
        bool evolutionFound = DSP036ReturningRows.TryGetEvolution(
            DSP036ReturningRows.SYSTEM_CROSS, evolved, sourceRank,
            dependency, dependencyRank);
        Console.Printf("DS_P036_MAP22_EVOLUTION accepted=%d source_system_id=%d evolved_system_id=%d required_source_rank=%d dependency_kind=%d dependency_min_rank=%d dependency_min_rank_provenance=ENGINEERING_APPROXIMATION", evolutionFound ? 1 : 0, DSP036ReturningRows.SYSTEM_CROSS, evolved, sourceRank, dependency, dependencyRank);
        Console.Printf("DS_P036_MAP22_ROW_COUNT rows=%d expected=%d", rowCount, EXPECTED_ROWS);
        return rowCount == EXPECTED_ROWS && evolutionFound;
    }

    int SpawnTarget(double targetX, double targetY, int targetHealth,
        double targetRadius)
    {
        int slot = Allocate(ENEMY_KIND, targetX, targetY, 0.0, 0.0,
            targetHealth);
        collisionRadii[slot] = targetRadius;
        targetSlots.Push(slot);
        return slot;
    }

    bool EquipOne(int systemId, int rank, int firstFireTic)
    {
        mainWeaponSlot = Allocate(WEAPON_KIND, playerX, playerY,
            0.0, 0.0, 1);
        bool accepted = DSP036EquipFixture(systemId, rank,
            mainWeaponSlot, firstFireTic);
        if (accepted)
        {
            fixtureSystems.Push(systemId);
            fixtureRanks.Push(rank);
            fixtureSlots.Push(mainWeaponSlot);
            Console.Printf("DS_P036_MAP22_FIXTURE system_id=%d rank=%d weapon_id=%d first_fire_tic=%d classification=CONTROLLED_ROW_FIXTURE source_inventory_claim=0", systemId, rank, ids[mainWeaponSlot], firstFireTic);
        }
        return accepted;
    }

    bool EquipAllRows()
    {
        fixtureSystems.Clear();
        fixtureRanks.Clear();
        fixtureSlots.Clear();
        int equipped = 0;
        for (int systemId = DSP036ReturningRows.SYSTEM_CROSS;
             systemId <= DSP036ReturningRows.SYSTEM_HEAVEN_SWORD;
             systemId++)
        {
            for (int rank = 1; rank <= RankLimit(systemId); rank++)
            {
                int weaponSlot = Allocate(WEAPON_KIND, playerX, playerY,
                    0.0, 0.0, 1);
                bool accepted = DSP036EquipFixture(systemId, rank,
                    weaponSlot, 1);
                if (!accepted)
                {
                    Console.Printf("DS_ASSERT_FAIL P036_MAP22_FIXTURE_EQUIP system_id=%d rank=%d", systemId, rank);
                    return false;
                }
                fixtureSystems.Push(systemId);
                fixtureRanks.Push(rank);
                fixtureSlots.Push(weaponSlot);
                mainWeaponSlot = weaponSlot;
                equipped++;
                Console.Printf("DS_P036_MAP22_FIXTURE system_id=%d rank=%d weapon_id=%d first_fire_tic=1 classification=CONTROLLED_ROW_FIXTURE source_inventory_claim=0", systemId, rank, ids[weaponSlot]);
            }
        }
        return equipped == EXPECTED_ROWS;
    }

    void HandleEnemyDeath(int slot, int beforeHealth, int eventId)
    {
        if (slot < 0 || slot >= lifeStates.Size()
            || lifeStates[slot] != STORE_ALIVE) return;
        Console.Printf("DS_P036_MAP22_DEATH event_id=%d tic=%d target_id=%d before=%d", eventId, tic, ids[slot], beforeHealth);
        DestroyParts(slot, generations[slot], ids[slot]);
    }

    bool StartScenario()
    {
        CVar modeCVar = CVar.FindCVar("ds_p036_mode");
        activeMode = modeCVar != null ? modeCVar.GetString() : "matrix";
        if (activeMode != "matrix" && activeMode != "flight"
            && activeMode != "move_rebase" && activeMode != "transform"
            && activeMode != "selection" && activeMode != "no_target"
            && activeMode != "crit")
        {
            Console.Printf("DS_ASSERT_FAIL P036_MAP22_MODE_UNSUPPORTED mode=%s", activeMode);
            return false;
        }

        logicalTic = 0;
        tic = 0;
        playerX = 0.0;
        playerY = 0.0;
        completed = false;
        captureRequested = false;
        captureFlushed = false;
        transformationAccepted = false;
        playerMoved = false;
        worldRebased = false;
        mainWeaponSlot = -1;
        selectedTargetId = 0;
        fixtureSystems.Clear(); fixtureRanks.Clear(); fixtureSlots.Clear();
        targetSlots.Clear();
        Reset();
        DSP024ClearSpatial();
        DSP036ResetReturningRuntime(ReadSeed());
        initialCritRng = dsp036CritRng;
        DSP033SetBaseStats(1000, 0, 120000, 1000);
        if (!DSP033RecomputeFromRanks(0, 0, 0, 0))
        {
            Console.Printf("DS_ASSERT_FAIL P036_MAP22_STAT_FIXTURE_REJECTED");
            return false;
        }
        ConfigureCamera();
        playerSlot = Allocate(PLAYER_KIND, playerX, playerY,
            0.0, 0.0, 1);
        bool rowsOk = EmitRows();
        bool targetsOk = true;
        bool weaponsOk = false;
        if (activeMode == "matrix")
        {
            SpawnTarget(playerX + 96.0, playerY, 1000000000, 8.0);
            weaponsOk = EquipAllRows();
        }
        else if (activeMode == "flight" || activeMode == "move_rebase")
        {
            SpawnTarget(playerX + 96.0, playerY, 1000000000, 8.0);
            weaponsOk = EquipOne(DSP036ReturningRows.SYSTEM_CROSS, 1, 1);
        }
        else if (activeMode == "transform")
        {
            SpawnTarget(playerX + 96.0, playerY, 1000000000, 8.0);
            weaponsOk = EquipOne(DSP036ReturningRows.SYSTEM_CROSS, 8, 1);
        }
        else if (activeMode == "selection")
        {
            int nearestSlot = SpawnTarget(playerX + 80.0, playerY,
                1000000000, 8.0);
            selectedTargetId = ids[nearestSlot];
            SpawnTarget(playerX - 80.0, playerY, 1000000000, 8.0);
            SpawnTarget(playerX + 40.0, playerY, 0, 8.0);
            SpawnTarget(playerX + 400.0, playerY, 1000000000, 8.0);
            weaponsOk = EquipOne(DSP036ReturningRows.SYSTEM_CROSS, 1, 1);
            Console.Printf("DS_P036_MAP22_SELECTION_FIXTURE accepted=%d expected_nearest_tie_id=%d equal_distance=80 dead_candidate=1 out_of_range_candidate_distance=400 range_budget=320 classification=CONTROLLED", weaponsOk ? 1 : 0, selectedTargetId);
        }
        else if (activeMode == "no_target")
        {
            weaponsOk = EquipOne(DSP036ReturningRows.SYSTEM_CROSS, 1, 1);
            Console.Printf("DS_P036_MAP22_NO_TARGET_FIXTURE accepted=%d targets=0 seed=%d classification=CONTROLLED", weaponsOk ? 1 : 0, ReadSeed());
        }
        else if (activeMode == "crit")
        {
            SpawnTarget(playerX + 96.0, playerY, 1000000000, 8.0);
            weaponsOk = EquipOne(DSP036ReturningRows.SYSTEM_HEAVEN_SWORD, 1, 1);
            Console.Printf("DS_P036_MAP22_CRIT_FIXTURE accepted=%d system_id=43 rank=1 crit_chance_permille=100 crit_multiplier_milli=2500 luck_eligibility=1 luck_mapping=UNSUPPORTED_BASELINE_ONLY classification=CONTROLLED_SEED", weaponsOk ? 1 : 0);
        }
        DSP024Rebuild();
        bool setupOk = rowsOk && weaponsOk && playerSlot >= 0;
        Console.Printf("DS_BOOT map=MAP22 classification=CONTROLLED_P036_RETURNING_RUNTIME_HARNESS");
        Console.Printf("DS_P036_MAP22_BOOT accepted=%d mode=%s camera_variant=%d target_count=%d equipped_rank_rows=%d source_inventory_claim=0 might_milli=%d cooldown_multiplier_milli=%d rank_hash=%d", setupOk ? 1 : 0, activeMode, cameraVariant, targetSlots.Size(), fixtureSystems.Size(), dsp033ResolvedMightMilli, dsp033ResolvedCooldownMultiplierMilli, dsp033ResolvedRankHash);
        if (!setupOk) Console.Printf("DS_ASSERT_FAIL P036_MAP22_SCENARIO_SETUP");
        return setupOk;
    }

    void EmitRuntimeResult()
    {
        int outboundHits = 0;
        int reverseHits = 0;
        for (int i = 0; i < dsp036HitPasses.Size(); i++)
        {
            if (dsp036HitPasses[i] == DSP036_PHASE_OUTBOUND) outboundHits++;
            else if (dsp036HitPasses[i] == DSP036_PHASE_REVERSE) reverseHits++;
        }
        bool passed = dsp036RejectedHits == 0 && captureFlushed;
        if (activeMode == "matrix")
            passed = passed && fixtureSystems.Size() == EXPECTED_ROWS
                && dsp036ProjectileOrdinal > 0 && outboundHits > 0
                && reverseHits > 0;
        else if (activeMode == "no_target")
            passed = passed && dsp036ProjectileOrdinal == 0
                && dsp036AcceptedHits == 0 && dsp036CritRng == initialCritRng;
        else if (activeMode == "selection")
            passed = passed && dsp036ProjectileOrdinal > 0
                && outboundHits > 0 && SelectedTargetMatches();
        else if (activeMode == "transform")
            passed = passed && transformationAccepted
                && CountSystemHits(DSP036ReturningRows.SYSTEM_HEAVEN_SWORD,
                    DSP036_PHASE_OUTBOUND) > 0
                && CountSystemHits(DSP036ReturningRows.SYSTEM_HEAVEN_SWORD,
                    DSP036_PHASE_REVERSE) > 0
                && !HasActiveSystem(DSP036ReturningRows.SYSTEM_CROSS);
        else if (activeMode == "move_rebase")
            passed = passed && playerMoved && worldRebased
                && outboundHits > 0 && reverseHits > 0;
        else
            passed = passed && dsp036ProjectileOrdinal > 0
                && outboundHits > 0 && reverseHits > 0;
        Console.Printf("DS_P036_MAP22_RUNTIME_RESULT accepted=%d mode=%s row_count=%d projectile_count=%d accepted_hits=%d outbound_hits=%d reverse_hits=%d rejected_hits=%d camera_variant=%d transformation=%d player_moved=%d world_rebased=%d crit_rng_initial=%d crit_rng_final=%d classification=CONTROLLED_ENGINE_RUNTIME", passed ? 1 : 0, activeMode, fixtureSystems.Size(), dsp036ProjectileOrdinal, dsp036AcceptedHits, outboundHits, reverseHits, dsp036RejectedHits, cameraVariant, transformationAccepted ? 1 : 0, playerMoved ? 1 : 0, worldRebased ? 1 : 0, initialCritRng, dsp036CritRng);
        if (!passed)
        {
            Console.Printf("DS_ASSERT_FAIL P036_MAP22_RUNTIME_EVIDENCE rows=%d projectiles=%d outbound=%d reverse=%d rejected=%d capture=%d", fixtureSystems.Size(), dsp036ProjectileOrdinal, outboundHits, reverseHits, dsp036RejectedHits, captureFlushed ? 1 : 0);
            completed = true;
            return;
        }
        Console.Printf("DS_P036_MAP22_RUNTIME_PASS accepted=1 mode=%s rows=%d projectile_count=%d outbound_hits=%d reverse_hits=%d camera_variant=%d", activeMode, fixtureSystems.Size(), dsp036ProjectileOrdinal, outboundHits, reverseHits, cameraVariant);
        completed = true;
    }

    int CountSystemHits(int systemId, int phase)
    {
        int result = 0;
        for (int hit = 0; hit < dsp036HitProjectileEvents.Size(); hit++)
        {
            if (dsp036HitPasses[hit] != phase) continue;
            int eventId = dsp036HitProjectileEvents[hit];
            for (int projectile = 0;
                 projectile < dsp036ProjectileEvents.Size(); projectile++)
            {
                if (dsp036ProjectileEvents[projectile] == eventId
                    && dsp036ProjectileSystems[projectile] == systemId)
                { result++; break; }
            }
        }
        return result;
    }

    bool HasActiveSystem(int systemId)
    {
        for (int i = 0; i < dsp036ProjectileActive.Size(); i++)
            if (dsp036ProjectileActive[i] != 0
                && dsp036ProjectileSystems[i] == systemId) return true;
        return false;
    }

    bool SelectedTargetMatches()
    {
        for (int i = 0; i < dsp036VolleyIds.Size(); i++)
        {
            int weapon = dsp036VolleyWeaponIndexes[i];
            if (weapon < 0 || weapon >= dsp036WeaponSystems.Size()
                || dsp036WeaponSystems[weapon]
                    != DSP036ReturningRows.SYSTEM_CROSS) continue;
            if (dsp036VolleyTargetFound[i] != 0
                && dsp036VolleyTargetIds[i] == selectedTargetId) return true;
        }
        return false;
    }

    int CompletionTic()
    {
        if (activeMode == "matrix") return 65;
        if (activeMode == "move_rebase" || activeMode == "flight"
            || activeMode == "transform" || activeMode == "crit") return 55;
        if (activeMode == "selection") return 55;
        return 5;
    }

    int CaptureTic()
    {
        if (activeMode == "matrix" || activeMode == "selection"
            || activeMode == "no_target") return 4;
        if (activeMode == "move_rebase") return 18;
        return 12;
    }

    void MovePlayerFixture()
    {
        double oldX = playerX;
        double oldY = playerY;
        playerY += 100.0;
        x[playerSlot] = playerX;
        y[playerSlot] = playerY;
        if (players[0].mo != null)
            players[0].mo.SetOrigin((playerX, playerY, 0.0), true);
        playerMoved = true;
        Console.Printf("DS_P036_MAP22_PLAYER_MOVE tic=%d old_x=%.3f old_y=%.3f new_x=%.3f new_y=%.3f projectiles_homed=0 classification=CONTROLLED_ENGINE_TELEPORT", tic, oldX, oldY, playerX, playerY);
    }

    void RebaseFixtureWorld()
    {
        double shiftX = -200.0;
        double shiftY = 60.0;
        int projectile = -1;
        for (int i = 0; i < dsp036ProjectileActive.Size(); i++)
            if (dsp036ProjectileActive[i] != 0)
            { projectile = i; break; }
        if (projectile < 0)
        {
            Console.Printf("DS_ASSERT_FAIL P036_MAP22_REBASE_NO_ACTIVE_PROJECTILE");
            return;
        }
        double beforeX = dsp036ProjectileX[projectile];
        double beforeY = dsp036ProjectileY[projectile];
        double beforeOriginX = dsp036ProjectileOriginX[projectile];
        double beforeOriginY = dsp036ProjectileOriginY[projectile];
        int eventId = dsp036ProjectileEvents[projectile];
        int heading = dsp036ProjectileAimYawMilli[projectile];
        for (int slot = 0; slot < lifeStates.Size(); slot++)
        {
            if (lifeStates[slot] != STORE_ALIVE) continue;
            x[slot] += shiftX;
            y[slot] += shiftY;
        }
        playerX += shiftX;
        playerY += shiftY;
        if (players[0].mo != null)
            players[0].mo.SetOrigin((playerX, playerY, 0.0), true);
        DSP036RebaseProjectiles(shiftX, shiftY);
        worldRebased = true;
        Console.Printf("DS_P036_MAP22_REBASE_PROOF event_id=%d tic=%d before_x=%.4f before_y=%.4f before_origin_x=%.4f before_origin_y=%.4f after_x=%.4f after_y=%.4f after_origin_x=%.4f after_origin_y=%.4f heading_before=%d heading_after=%d delta_x=%.3f delta_y=%.3f moving_player=1 classification=CONTROLLED_WORLD_TRANSLATION", eventId, tic, beforeX, beforeY, beforeOriginX, beforeOriginY, dsp036ProjectileX[projectile], dsp036ProjectileY[projectile], dsp036ProjectileOriginX[projectile], dsp036ProjectileOriginY[projectile], heading, dsp036ProjectileAimYawMilli[projectile], shiftX, shiftY);
    }

    override void WorldLoaded(WorldEvent e)
    {
        if (level == null || level.MapName != MAP || e.IsSaveGame) return;
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
        if (activeMode == "transform" && logicalTic == 3)
        {
            transformationAccepted = DSP036ReplaceFixture(mainWeaponSlot,
                DSP036ReturningRows.SYSTEM_HEAVEN_SWORD, 1, tic, true, 1);
            if (!transformationAccepted)
                Console.Printf("DS_ASSERT_FAIL P036_MAP22_TRANSFORM_FIXTURE_REJECTED");
            Console.Printf("DS_P036_MAP22_TRANSFORM_RESULT accepted=%d tic=%d source_system_id=42 source_rank=8 evolved_system_id=43 output_rank=1 dependency_rank=1 dependency=CONTROLLED_CLOVER_FIXTURE", transformationAccepted ? 1 : 0, tic);
        }
        if (activeMode == "move_rebase" && logicalTic == 8)
            MovePlayerFixture();
        if (activeMode == "move_rebase" && logicalTic == 12)
            RebaseFixtureWorld();
        DSP024Rebuild();
        DSP036ProcessReturningTic(logicalTic, playerSlot,
            generations[playerSlot], ids[playerSlot], playerX, playerY,
            dsp033ResolvedCooldownMultiplierMilli,
            dsp033ResolvedRankHash);

        if (!captureRequested && logicalTic >= CaptureTic())
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
        if (logicalTic >= CompletionTic()) EmitRuntimeResult();
    }
}
