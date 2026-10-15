// MAP20 controlled runtime for the four qualified P034 aimed/directional
// forms. This is a harness host, not the production inventory or acquisition
// route. It uses the same compiled rows, P020 handles, P024 spatial index,
// P025 checked-hit boundary, P033 resolver, and P034 automatic runtime.
class DSP034AimedRuntime : EventHandler
{
    mixin DSRunStatFields;
    mixin DSP020EntityStore;
    mixin DSP024SpatialIndex;
    mixin DSP025AttackCore;
    mixin DSP033ResolvedStats;
    mixin DSP034AimedTargeting;
    mixin DSP034AimedProjectileRuntime;

    const MAP = "MAP20";
    const RUN_TICS = 80;
    const TARGET_REAR = 1;
    const TARGET_FORWARD = 1;
    const TARGET_NORTH = 1;
    const WEAPON_KIND = 90;
    const PLAYER_KIND = 99;

    bool started;
    bool enabled;
    bool completed;
    bool captureRequested;
    bool captureFlushed;
    bool concurrencyReported;
    bool retargetStarted;
    bool retargetRearKilled;
    bool retargetProofReported;
    bool emptySkipStarted;
    bool emptySkipReported;
    int logicalTic;
    int tic;
    int cameraVariant;
    int cameraYaw;
    int cameraPitch;
    int cameraFov;
    int playerSlot;
    int rearTargetSlot;
    int forwardTargetSlot;
    int northTargetSlot;
    int weaponMagicSlot;
    int weaponHolySlot;
    int weaponKnifeSlot;
    int weaponThousandSlot;
    int deathCallbacks;
    int retargetWeaponId;
    int retargetDeathTic;
    Array<int> dsp034FixtureWeaponSystems;
    Array<int> dsp034FixtureWeaponRanks;
    Array<int> dsp034FixtureWeaponSlots;
    Array<int> crowdTargetSlots;
    Array<int> retargetChildTargets;
    Array<int> retargetChildTics;
    double playerX;
    double playerY;

    override void OnRegister()
    {
        IsUiProcessor = false;
        RequireMouse = false;
    }

    int ReadCameraVariant()
    {
        CVar camera = CVar.FindCVar("ds_p034_camera_variant");
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
        Console.Printf("DS_P034_MAP20_CAMERA variant=%d yaw=%d pitch=%d fov=%d source=UZDOOM_PLAYER_VIEW", cameraVariant, cameraYaw, cameraPitch, cameraFov);
    }

    String ReadMode()
    {
        CVar mode = CVar.FindCVar("ds_p034_mode");
        return mode != null ? mode.GetString() : "matrix";
    }

    void EmitCompiledRows()
    {
        int rowCount = 0;
        for (int systemId = DSP034WeaponRows.SYSTEM_MAGIC_WAND;
             systemId <= DSP034WeaponRows.SYSTEM_THOUSAND_EDGE; systemId++)
        {
            int rowLimit = systemId == DSP034WeaponRows.SYSTEM_MAGIC_WAND
                || systemId == DSP034WeaponRows.SYSTEM_KNIFE ? 8 : 1;
            for (int rank = 1; rank <= rowLimit; rank++)
            {
                int damageTenths; int amount; int pierce;
                int cooldownMillis; int intervalMillis; int speedMilli;
                int travelSpeed; int rangeUnits; int lifetimeTics;
                int radiusMilli; int poolLimit;
                bool accepted = DSP034WeaponRows.TryGetRankRow(systemId,
                    rank, damageTenths, amount, pierce, cooldownMillis,
                    intervalMillis, speedMilli, travelSpeed, rangeUnits,
                    lifetimeTics, radiusMilli, poolLimit);
                if (!accepted)
                {
                    Console.Printf("DS_ASSERT_FAIL P034_COMPILED_ROW_MISSING system_id=%d rank=%d", systemId, rank);
                    continue;
                }
                rowCount++;
                Console.Printf("DS_P034_MAP20_ROW system_id=%d rank=%d damage_tenths=%d amount=%d pierce=%d cooldown_milliseconds=%d child_interval_milliseconds=%d projectile_speed_multiplier_milli=%d travel_units_per_second=%d max_range_units=%d lifetime_tics=%d projectile_radius_milliunits=%d projectile_pool_limit_instances=%d classification=COMPILED_JSON_MIRROR", systemId, rank, damageTenths, amount, pierce, cooldownMillis, intervalMillis, speedMilli, travelSpeed, rangeUnits, lifetimeTics, radiusMilli, poolLimit);
            }
        }
        Console.Printf("DS_P034_MAP20_ROW_COUNT rows=%d expected=18", rowCount);

        for (int evolvedId = DSP034WeaponRows.SYSTEM_HOLY_WAND;
             evolvedId <= DSP034WeaponRows.SYSTEM_THOUSAND_EDGE; evolvedId += 2)
        {
            int sourceId; int sourceRank; int passiveKind; int passiveRank;
            bool found = DSP034WeaponRows.TryGetTransformation(evolvedId,
                sourceId, sourceRank, passiveKind, passiveRank);
            Console.Printf("DS_P034_MAP20_TRANSFORM accepted=%d evolved_system_id=%d source_system_id=%d source_rank=%d passive_kind=%d passive_rank=%d", found ? 1 : 0, evolvedId, sourceId, sourceRank, passiveKind, passiveRank);
        }
    }

    bool EmitStatEligibility()
    {
        bool allEligible = true;
        int mightMilli = DSP033Resolved(DSP033StatRules.STAT_MIGHT);
        int cooldownMilli = DSP033Resolved(DSP033StatRules.STAT_COOLDOWN);
        for (int systemId = DSP034WeaponRows.SYSTEM_MAGIC_WAND;
             systemId <= DSP034WeaponRows.SYSTEM_THOUSAND_EDGE; systemId++)
        {
            bool mightEligible = DSP033StatRules.StatApplies(
                DSP033StatRules.STAT_MIGHT, systemId);
            bool cooldownEligible = DSP033StatRules.StatApplies(
                DSP033StatRules.STAT_COOLDOWN, systemId);
            int damage = DSP033StatRules.DamageAfterMight(systemId, 100,
                mightMilli);
            int cooldown = DSP033StatRules.CooldownAfterTome(systemId,
                1000, cooldownMilli);
            if (!mightEligible || !cooldownEligible || damage != 150
                || cooldown != 600) allEligible = false;
            Console.Printf("DS_P034_MAP20_MODIFIER system_id=%d might_eligible=%d cooldown_eligible=%d fixture_might_milli=%d fixture_cooldown_milli=%d damage_base=100 damage_after=%d cooldown_base_millis=1000 cooldown_after_millis=%d", systemId, mightEligible ? 1 : 0, cooldownEligible ? 1 : 0, mightMilli, cooldownMilli, damage, cooldown);
        }
        int diagnosticDamage = DSP033StatRules.DamageAfterMight(
            DSP033StatRules.SYSTEM_DIAGNOSTIC_WEAPON, 100, mightMilli);
        int diagnosticCooldown = DSP033StatRules.CooldownAfterTome(
            DSP033StatRules.SYSTEM_DIAGNOSTIC_WEAPON, 1000, cooldownMilli);
        bool diagnosticExcluded = !DSP033StatRules.StatApplies(
                DSP033StatRules.STAT_MIGHT,
                DSP033StatRules.SYSTEM_DIAGNOSTIC_WEAPON)
            && !DSP033StatRules.StatApplies(DSP033StatRules.STAT_COOLDOWN,
                DSP033StatRules.SYSTEM_DIAGNOSTIC_WEAPON)
            && diagnosticDamage == 100 && diagnosticCooldown == 1000;
        Console.Printf("DS_P034_MAP20_DIAGNOSTIC system_id=900 might_eligible=%d cooldown_eligible=%d damage_after=%d cooldown_after_millis=%d", DSP033StatRules.StatApplies(DSP033StatRules.STAT_MIGHT, DSP033StatRules.SYSTEM_DIAGNOSTIC_WEAPON) ? 1 : 0, DSP033StatRules.StatApplies(DSP033StatRules.STAT_COOLDOWN, DSP033StatRules.SYSTEM_DIAGNOSTIC_WEAPON) ? 1 : 0, diagnosticDamage, diagnosticCooldown);
        bool nonWeaponExcluded = true;
        for (int i = 0; i < 3; i++)
        {
            int systemId = i == 0
                ? DSP033StatRules.SYSTEM_DIAGNOSTIC_WEAPON
                : i == 1 ? DSP033StatRules.SYSTEM_PLAYER_HEALTH
                    : DSP033StatRules.SYSTEM_INCOMING_DAMAGE;
            bool might = DSP033StatRules.StatApplies(
                DSP033StatRules.STAT_MIGHT, systemId);
            bool cooldown = DSP033StatRules.StatApplies(
                DSP033StatRules.STAT_COOLDOWN, systemId);
            int damage = DSP033StatRules.DamageAfterMight(systemId, 100,
                mightMilli);
            int adjusted = DSP033StatRules.CooldownAfterTome(systemId,
                1000, cooldownMilli);
            if (might || cooldown || damage != 100 || adjusted != 1000)
                nonWeaponExcluded = false;
            Console.Printf("DS_P034_MAP20_NONWEAPON system_id=%d might_eligible=%d cooldown_eligible=%d damage_after=%d cooldown_after_millis=%d", systemId, might ? 1 : 0, cooldown ? 1 : 0, damage, adjusted);
        }
        return allEligible && diagnosticExcluded && nonWeaponExcluded;
    }

    void SpawnTarget(int kind, double targetX, double targetY,
        int targetHealth, out int targetSlot)
    {
        targetSlot = Allocate(kind, targetX, targetY, 0.0, 0.0,
            targetHealth);
        collisionRadii[targetSlot] = 4.0;
    }

    bool StartScenario()
    {
        enabled = false;
        completed = false;
        captureRequested = false;
        captureFlushed = false;
        concurrencyReported = false;
        logicalTic = 0;
        deathCallbacks = 0;
        retargetStarted = false;
        retargetRearKilled = false;
        retargetProofReported = false;
        emptySkipStarted = false;
        emptySkipReported = false;
        retargetWeaponId = 0;
        retargetDeathTic = 0;
        retargetChildTargets.Clear();
        retargetChildTics.Clear();
        tic = 0;
        playerX = 0.0;
        playerY = 0.0;

        if (ReadMode() != "matrix")
        {
            Console.Printf("DS_ASSERT_FAIL P034_MAP20_MODE_UNSUPPORTED mode=%s expected=matrix", ReadMode());
            return false;
        }

        Reset();
        DSP024ClearSpatial();
        DSP034ResetAimedRuntime();
        DSP033SetBaseStats(1000, 0, 120000, 1000);
        if (!DSP033RecomputeFromRanks(5, 0, 0, 5))
        {
            Console.Printf("DS_ASSERT_FAIL P034_MAP20_STAT_FIXTURE_REJECTED");
            return false;
        }
        ConfigureCamera();

        playerSlot = Allocate(PLAYER_KIND, playerX, playerY, 0.0, 0.0, 1);
        dsp034FixtureWeaponSystems.Clear();
        dsp034FixtureWeaponRanks.Clear();
        dsp034FixtureWeaponSlots.Clear();
        crowdTargetSlots.Clear();
        for (int systemId = DSP034WeaponRows.SYSTEM_MAGIC_WAND;
             systemId <= DSP034WeaponRows.SYSTEM_THOUSAND_EDGE; systemId++)
        {
            int rowLimit = systemId == DSP034WeaponRows.SYSTEM_MAGIC_WAND
                || systemId == DSP034WeaponRows.SYSTEM_KNIFE ? 8 : 1;
            for (int rank = 1; rank <= rowLimit; rank++)
            {
                int firstFireTic = rank;
                if (systemId == DSP034WeaponRows.SYSTEM_HOLY_WAND)
                    firstFireTic = 9;
                else if (systemId == DSP034WeaponRows.SYSTEM_THOUSAND_EDGE)
                    firstFireTic = 10;
                int weaponSlot = Allocate(WEAPON_KIND, 0.0, 0.0,
                    0.0, 0.0, 1);
                dsp034FixtureWeaponSystems.Push(systemId);
                dsp034FixtureWeaponRanks.Push(rank);
                dsp034FixtureWeaponSlots.Push(weaponSlot);
                if (!DSP034EquipAimedFixture(systemId, rank, weaponSlot,
                        firstFireTic))
                    Console.Printf("DS_ASSERT_FAIL P034_MAP20_FIXTURE_EQUIP system_id=%d rank=%d", systemId, rank);
            }
        }
        SpawnTarget(TARGET_REAR, -64.0, 0.0, 10000000, rearTargetSlot);
        SpawnTarget(TARGET_FORWARD, 96.0, 0.0, 10000000, forwardTargetSlot);
        SpawnTarget(TARGET_NORTH, 0.0, 96.0, 10000000, northTargetSlot);

        DSP024Rebuild();
        EmitCompiledRows();
        int selectedSlot; int selectedGeneration; int selectedId;
        double distanceSquared;
        bool nearest = DSP034SelectNearestTarget(DSP034_TARGET_ENEMY,
            playerX, playerY, 320.0, selectedSlot, selectedGeneration,
            selectedId, distanceSquared);
        int nearestTargetId = selectedId;
        Console.Printf("DS_P034_MAP20_SELECTOR accepted=%d target_id=%d target_slot=%d target_generation=%d distance_squared=%.3f expected_rear_id=%d policy=NEAREST_PLANAR", nearest ? 1 : 0, selectedId, selectedSlot, selectedGeneration, distanceSquared, ids[rearTargetSlot]);
        bool empty = DSP034SelectNearestTarget(DSP034_TARGET_ENEMY,
            1000.0, 1000.0, 320.0, selectedSlot, selectedGeneration,
            selectedId, distanceSquared);
        Console.Printf("DS_P034_MAP20_EMPTY_SET found=%d expected_found=0 no_child_safe=%d", empty ? 1 : 0, empty ? 0 : 1);

        int sparseEnemyCount = 0;
        for (int slot = 0; slot < lifeStates.Size(); slot++)
            if (lifeStates[slot] == STORE_ALIVE
                && kinds[slot] == DSP034_TARGET_ENEMY) sparseEnemyCount++;
        bool sparseOk = sparseEnemyCount == 3;
        Console.Printf("DS_P034_MAP20_SPARSE accepted=%d enemy_count=%d expected_enemy_count=3 classification=CONTROLLED_TARGET_DENSITY_FIXTURE", sparseOk ? 1 : 0, sparseEnemyCount);

        for (int i = 0; i < 32; i++)
        {
            int crowdSlot;
            double crowdX = -120.0 + i * 7.0;
            double crowdY = i % 2 == 0 ? -12.0 : 12.0;
            SpawnTarget(DSP034_TARGET_ENEMY, crowdX, crowdY,
                10000000, crowdSlot);
            crowdTargetSlots.Push(crowdSlot);
        }
        DSP024Rebuild();
        int crowdedEnemyCount = 0;
        for (int slot = 0; slot < lifeStates.Size(); slot++)
            if (lifeStates[slot] == STORE_ALIVE
                && kinds[slot] == DSP034_TARGET_ENEMY) crowdedEnemyCount++;
        bool crowdedFound = DSP034SelectNearestTarget(
            DSP034_TARGET_ENEMY, playerX, playerY, 320.0,
            selectedSlot, selectedGeneration, selectedId, distanceSquared);
        bool crowdedOk = crowdedEnemyCount == 35 && crowdedFound
            && selectedId > 0 && distanceSquared <= 102400.0;
        Console.Printf("DS_P034_MAP20_CROWDED accepted=%d enemy_count=%d added_fixture_targets=%d selected_id=%d distance_squared=%.3f range_units=320 classification=CONTROLLED_TARGET_DENSITY_FIXTURE", crowdedOk ? 1 : 0, crowdedEnemyCount, crowdTargetSlots.Size(), selectedId, distanceSquared);
        for (int i = 0; i < crowdTargetSlots.Size(); i++)
        {
            int slot = crowdTargetSlots[i];
            DestroyParts(slot, generations[slot], ids[slot]);
        }
        DSP024Rebuild();

        // These are controlled engine selector probes, independent of the
        // weapon schedule. Equal-distance targets must choose the lower stable
        // P020 ID; the declared 320-unit approximation includes its boundary
        // and rejects a point just outside it.
        x[rearTargetSlot] = -64.0; y[rearTargetSlot] = 0.0;
        x[forwardTargetSlot] = 64.0; y[forwardTargetSlot] = 0.0;
        x[northTargetSlot] = 0.0; y[northTargetSlot] = 96.0;
        DSP024Rebuild();
        bool tieFound = DSP034SelectNearestTarget(DSP034_TARGET_ENEMY,
            playerX, playerY, 320.0, selectedSlot, selectedGeneration,
            selectedId, distanceSquared);
        int expectedTieId = ids[rearTargetSlot] < ids[forwardTargetSlot]
            ? ids[rearTargetSlot] : ids[forwardTargetSlot];
        bool tieOk = tieFound && selectedId == expectedTieId
            && distanceSquared == 4096.0;
        Console.Printf("DS_P034_MAP20_SELECTOR_TIE accepted=%d winner_id=%d expected_winner_id=%d distance_squared=%.3f equal_distance=1 tie_policy=STABLE_ID_THEN_GENERATION_THEN_SLOT", tieOk ? 1 : 0, selectedId, expectedTieId, distanceSquared);

        x[rearTargetSlot] = 320.0; y[rearTargetSlot] = 0.0;
        x[forwardTargetSlot] = 500.0; y[forwardTargetSlot] = 0.0;
        x[northTargetSlot] = 600.0; y[northTargetSlot] = 0.0;
        DSP024Rebuild();
        bool atRange = DSP034SelectNearestTarget(DSP034_TARGET_ENEMY,
            playerX, playerY, 320.0, selectedSlot, selectedGeneration,
            selectedId, distanceSquared);
        bool inclusiveRangeOk = atRange
            && selectedId == ids[rearTargetSlot]
            && distanceSquared == 102400.0;
        Console.Printf("DS_P034_MAP20_RANGE_BOUNDARY accepted=%d distance_units=320.000 max_range_units=320 expected_inclusive=1 target_id=%d expected_target_id=%d distance_squared=%.3f", inclusiveRangeOk ? 1 : 0, selectedId, ids[rearTargetSlot], distanceSquared);

        x[rearTargetSlot] = 320.125;
        DSP024Rebuild();
        bool outsideRange = DSP034SelectNearestTarget(DSP034_TARGET_ENEMY,
            playerX, playerY, 320.0, selectedSlot, selectedGeneration,
            selectedId, distanceSquared);
        bool exclusiveRangeOk = !outsideRange;
        Console.Printf("DS_P034_MAP20_RANGE_OUTSIDE accepted=%d found=%d distance_units=320.125 max_range_units=320 expected_found=0", exclusiveRangeOk ? 1 : 0, outsideRange ? 1 : 0);

        x[rearTargetSlot] = -64.0; y[rearTargetSlot] = 0.0;
        x[forwardTargetSlot] = 96.0; y[forwardTargetSlot] = 0.0;
        x[northTargetSlot] = 0.0; y[northTargetSlot] = 96.0;
        DSP024Rebuild();

        bool statsOk = EmitStatEligibility();
        bool fixtureOk = statsOk && nearest
            && nearestTargetId == ids[rearTargetSlot] && !empty
            && sparseOk && crowdedOk
            && tieOk && inclusiveRangeOk && exclusiveRangeOk
            && dsp034FixtureWeaponSystems.Size() == 18;
        Console.Printf("DS_BOOT map=MAP20 classification=CONTROLLED_P034_FOUR_FORM_RUNTIME_HARNESS");
        Console.Printf("DS_P034_MAP20_BOOT accepted=%d camera_variant=%d targets=%d rear_target_id=%d forward_target_id=%d north_target_id=%d equipped_rank_rows=%d fixture=CONTROLLED source_inventory_claim=0 might_milli=%d cooldown_multiplier_milli=%d rank_hash=%d", fixtureOk ? 1 : 0, cameraVariant, 3, ids[rearTargetSlot], ids[forwardTargetSlot], ids[northTargetSlot], dsp034FixtureWeaponSystems.Size(), dsp033ResolvedMightMilli, dsp033ResolvedCooldownMultiplierMilli, dsp033ResolvedRankHash);
        if (!fixtureOk) Console.Printf("DS_ASSERT_FAIL P034_MAP20_SCENARIO_SETUP");
        enabled = fixtureOk;
        started = true;
        return fixtureOk;
    }

    void HandleEnemyDeath(int slot, int beforeHealth, int eventId)
    {
        if (slot < 0 || slot >= lifeStates.Size()
            || lifeStates[slot] != STORE_ALIVE) return;
        deathCallbacks++;
        Console.Printf("DS_P034_MAP20_DEATH event_id=%d tic=%d target_id=%d before=%d", eventId, tic, ids[slot], beforeHealth);
        if (retargetStarted && slot == rearTargetSlot)
        {
            retargetRearKilled = true;
            retargetDeathTic = logicalTic;
            Console.Printf("DS_P034_MAP20_RETARGET_DEATH tic=%d target_id=%d before=%d phase=MID_BURST", logicalTic, ids[slot], beforeHealth);
        }
        DestroyParts(slot, generations[slot], ids[slot]);
    }

    void FreezeFixtureWeaponsAndProjectiles(String reason)
    {
        for (int i = 0; i < dsp034NextVolleyMilliTics.Size(); i++)
            dsp034NextVolleyMilliTics[i] = 2147483647;
        for (int i = 0; i < dsp034BurstActive.Size(); i++)
        {
            dsp034BurstActive[i] = 0;
            dsp034BurstRemainingChildren[i] = 0;
        }
        for (int i = 0; i < dsp034ProjectileActive.Size(); i++)
            DSP034RetireProjectile(i, reason);
    }

    void BeginRetargetFixture()
    {
        FreezeFixtureWeaponsAndProjectiles("MATRIX_TO_RETARGET_FIXTURE");
        health[rearTargetSlot] = 10000;
        x[rearTargetSlot] = -56.0;
        DSP024Rebuild();
        int weaponSlot = Allocate(WEAPON_KIND, 0.0, 0.0, 0.0, 0.0, 1);
        retargetWeaponId = ids[weaponSlot];
        retargetStarted = DSP034EquipAimedFixture(
            DSP034WeaponRows.SYSTEM_MAGIC_WAND, 4, weaponSlot,
            logicalTic + 4);
        Console.Printf("DS_P034_MAP20_RETARGET_PREP accepted=%d tic=%d rear_id=%d rear_health=10000 rear_x=-56.000 weapon_id=%d system_id=34 rank=4 first_fire_tic=%d children=3 source=CONTROLLED_LETHAL_NEAREST_TARGET", retargetStarted ? 1 : 0, logicalTic, ids[rearTargetSlot], retargetWeaponId, logicalTic + 4);
        if (!retargetStarted) Console.Printf("DS_ASSERT_FAIL P034_MAP20_RETARGET_EQUIP_REJECTED");
    }

    void BeginEmptyTargetSkipFixture()
    {
        FreezeFixtureWeaponsAndProjectiles("RETARGET_TO_EMPTY_TARGET_FIXTURE");
        if (lifeStates[rearTargetSlot] == STORE_ALIVE)
            DestroyParts(rearTargetSlot, generations[rearTargetSlot], ids[rearTargetSlot]);
        if (lifeStates[forwardTargetSlot] == STORE_ALIVE)
            DestroyParts(forwardTargetSlot, generations[forwardTargetSlot], ids[forwardTargetSlot]);
        if (lifeStates[northTargetSlot] == STORE_ALIVE)
            DestroyParts(northTargetSlot, generations[northTargetSlot], ids[northTargetSlot]);
        DSP024Rebuild();
        int weaponSlot = Allocate(WEAPON_KIND, 0.0, 0.0, 0.0, 0.0, 1);
        bool accepted = DSP034EquipAimedFixture(
            DSP034WeaponRows.SYSTEM_MAGIC_WAND, 1, weaponSlot,
            logicalTic + 4);
        emptySkipStarted = accepted;
        Console.Printf("DS_P034_MAP20_EMPTY_SKIP_PREP accepted=%d tic=%d live_targets=0 system_id=34 rank=1 first_fire_tic=%d source=CONTROLLED_EMPTY_ELIGIBLE_SET", accepted ? 1 : 0, logicalTic, logicalTic + 4);
        if (!accepted) Console.Printf("DS_ASSERT_FAIL P034_MAP20_EMPTY_SKIP_EQUIP_REJECTED");
    }

    void CheckConcurrency()
    {
        int activeMagic = 0; int activeHoly = 0;
        int activeKnife = 0; int activeThousand = 0;
        for (int i = 0; i < dsp034ProjectileActive.Size(); i++)
        {
            if (dsp034ProjectileActive[i] == 0) continue;
            int systemId = dsp034ProjectileSystems[i];
            if (systemId == DSP034WeaponRows.SYSTEM_MAGIC_WAND) activeMagic++;
            else if (systemId == DSP034WeaponRows.SYSTEM_HOLY_WAND) activeHoly++;
            else if (systemId == DSP034WeaponRows.SYSTEM_KNIFE) activeKnife++;
            else if (systemId == DSP034WeaponRows.SYSTEM_THOUSAND_EDGE) activeThousand++;
        }
        if (!concurrencyReported && activeMagic > 0 && activeHoly > 0
            && activeKnife > 0 && activeThousand > 0)
        {
            concurrencyReported = true;
            Console.Printf("DS_P034_MAP20_CONCURRENT tic=%d magic=%d holy=%d knife=%d thousand=%d automatic=1", logicalTic, activeMagic, activeHoly, activeKnife, activeThousand);
        }
    }

    void EmitPass()
    {
        int equippedMagic = 0; int equippedHoly = 0;
        int equippedKnife = 0; int equippedThousand = 0;
        int projectilesMagic = 0; int projectilesHoly = 0;
        int projectilesKnife = 0; int projectilesThousand = 0;
        for (int i = 0; i < dsp034WeaponSystems.Size(); i++)
        {
            if (dsp034WeaponSystems[i] == DSP034WeaponRows.SYSTEM_MAGIC_WAND) equippedMagic++;
            else if (dsp034WeaponSystems[i] == DSP034WeaponRows.SYSTEM_HOLY_WAND) equippedHoly++;
            else if (dsp034WeaponSystems[i] == DSP034WeaponRows.SYSTEM_KNIFE) equippedKnife++;
            else if (dsp034WeaponSystems[i] == DSP034WeaponRows.SYSTEM_THOUSAND_EDGE) equippedThousand++;
        }
        for (int i = 0; i < dsp034ProjectileSystems.Size(); i++)
        {
            projectilesMagic += dsp034ProjectileSystems[i] == DSP034WeaponRows.SYSTEM_MAGIC_WAND ? 1 : 0;
            projectilesHoly += dsp034ProjectileSystems[i] == DSP034WeaponRows.SYSTEM_HOLY_WAND ? 1 : 0;
            projectilesKnife += dsp034ProjectileSystems[i] == DSP034WeaponRows.SYSTEM_KNIFE ? 1 : 0;
            projectilesThousand += dsp034ProjectileSystems[i] == DSP034WeaponRows.SYSTEM_THOUSAND_EDGE ? 1 : 0;
        }
        int hitsMagic = 0; int hitsHoly = 0; int hitsKnife = 0; int hitsThousand = 0;
        for (int i = 0; i < dsp034HitProjectileEvents.Size(); i++)
        {
            int eventId = dsp034HitProjectileEvents[i];
            for (int p = 0; p < dsp034ProjectileEvents.Size(); p++)
            {
                if (dsp034ProjectileEvents[p] != eventId) continue;
                if (dsp034ProjectileSystems[p] == DSP034WeaponRows.SYSTEM_MAGIC_WAND) hitsMagic++;
                else if (dsp034ProjectileSystems[p] == DSP034WeaponRows.SYSTEM_HOLY_WAND) hitsHoly++;
                else if (dsp034ProjectileSystems[p] == DSP034WeaponRows.SYSTEM_KNIFE) hitsKnife++;
                else if (dsp034ProjectileSystems[p] == DSP034WeaponRows.SYSTEM_THOUSAND_EDGE) hitsThousand++;
                break;
            }
        }
        int rankRowsWithProjectiles = 0;
        bool everyRankFired = true;
        for (int systemId = DSP034WeaponRows.SYSTEM_MAGIC_WAND;
             systemId <= DSP034WeaponRows.SYSTEM_THOUSAND_EDGE; systemId++)
        {
            int rowLimit = systemId == DSP034WeaponRows.SYSTEM_MAGIC_WAND
                || systemId == DSP034WeaponRows.SYSTEM_KNIFE ? 8 : 1;
            for (int rank = 1; rank <= rowLimit; rank++)
            {
                int rankProjectileCount = 0;
                for (int p = 0; p < dsp034ProjectileSystems.Size(); p++)
                    if (dsp034ProjectileSystems[p] == systemId
                        && dsp034ProjectileRanks[p] == rank) rankProjectileCount++;
                if (rankProjectileCount > 0) rankRowsWithProjectiles++;
                else everyRankFired = false;
                Console.Printf("DS_P034_MAP20_RANK_RUNTIME system_id=%d rank=%d projectile_count=%d", systemId, rank, rankProjectileCount);
            }
        }
        bool facingTargets = cameraVariant == 1
            ? dsp034AcceptedHits > 0
            : forwardTargetSlot >= 0 && rearTargetSlot >= 0;
        bool allPassed = dsp034AcceptedHits > 0 && dsp034RejectedHits == 0
            && concurrencyReported && projectilesMagic > 0
            && projectilesHoly > 0 && projectilesKnife > 0
            && projectilesThousand > 0 && hitsMagic > 0 && hitsHoly > 0
            && hitsKnife > 0 && hitsThousand > 0 && facingTargets
            && everyRankFired && rankRowsWithProjectiles == 18;
        Console.Printf("DS_P034_MAP20_SUMMARY tics=%d equipped_magic=%d equipped_holy=%d equipped_knife=%d equipped_thousand=%d projectiles_magic=%d projectiles_holy=%d projectiles_knife=%d projectiles_thousand=%d hits_magic=%d hits_holy=%d hits_knife=%d hits_thousand=%d rank_rows_with_projectiles=%d accepted_hits=%d rejected_hits=%d death_callbacks=%d concurrent=%d camera_variant=%d", logicalTic, equippedMagic, equippedHoly, equippedKnife, equippedThousand, projectilesMagic, projectilesHoly, projectilesKnife, projectilesThousand, hitsMagic, hitsHoly, hitsKnife, hitsThousand, rankRowsWithProjectiles, dsp034AcceptedHits, dsp034RejectedHits, deathCallbacks, concurrencyReported ? 1 : 0, cameraVariant);
        bool complete = retargetProofReported && emptySkipReported;
        if (!allPassed || !complete)
        {
            Console.Printf("DS_ASSERT_FAIL P034_MAP20_REQUIRED_RUNTIME_EVIDENCE_MISSING");
            return;
        }
        completed = true;
        Console.Printf("DS_P034_MAP20_RUNTIME_PASS forms=4 rank_rows=18 rank_runtime_rows=%d selectors=nearest,empty modifiers=4 concurrent=1 actual_hits=4 mid_burst_retarget=1 actual_empty_child_skip=1 classification=CONTROLLED_QUALIFIED_AIMED_DIRECTIONAL_ADAPTER", rankRowsWithProjectiles);
    }

    override void WorldLoaded(WorldEvent e)
    {
        if (level == null || level.MapName != MAP || e.IsSaveGame) return;
        started = false;
        enabled = false;
    }

    override void WorldTick()
    {
        if (level == null || level.MapName != MAP) return;
        if (!started)
        {
            if (!StartScenario()) return;
        }
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
        DSP024Rebuild();
        int projectileCountBefore = dsp034ProjectileEvents.Size();
        DSP034ProcessAimedTic(logicalTic, playerSlot,
            generations[playerSlot], ids[playerSlot], playerX, playerY,
            true, viewYawMilli,
            dsp033ResolvedCooldownMultiplierMilli,
            dsp033ResolvedRankHash);
        if (retargetStarted && !retargetProofReported)
        {
            for (int p = projectileCountBefore;
                 p < dsp034ProjectileEvents.Size(); p++)
            {
                if (dsp034ProjectileWeaponIds[p] == retargetWeaponId)
                {
                    retargetChildTargets.Push(dsp034ProjectileTargetIds[p]);
                    retargetChildTics.Push(logicalTic);
                }
            }
            if (retargetRearKilled && retargetChildTargets.Size() >= 3)
            {
                int firstTarget = retargetChildTargets[0];
                int secondTarget = retargetChildTargets[1];
                int thirdTarget = retargetChildTargets[2];
                bool accepted = firstTarget == ids[rearTargetSlot]
                    && secondTarget == ids[rearTargetSlot]
                    && thirdTarget == ids[forwardTargetSlot]
                    && retargetDeathTic > retargetChildTics[1]
                    && retargetDeathTic < retargetChildTics[2];
                Console.Printf("DS_P034_MAP20_RETARGET_RESULT accepted=%d weapon_id=%d system_id=34 rank=4 children=%d first_target_id=%d second_target_id=%d third_target_id=%d first_tic=%d second_tic=%d third_tic=%d rear_id=%d forward_id=%d death_tic=%d rule=FRESH_NEAREST_PER_CHILD classification=CONTROLLED_LIVE_DEATH_DURING_BURST", accepted ? 1 : 0, retargetWeaponId, retargetChildTargets.Size(), firstTarget, secondTarget, thirdTarget, retargetChildTics[0], retargetChildTics[1], retargetChildTics[2], ids[rearTargetSlot], ids[forwardTargetSlot], retargetDeathTic);
                if (!accepted) Console.Printf("DS_ASSERT_FAIL P034_MAP20_RETARGET_EXPECTED_TARGET_SEQUENCE");
                retargetProofReported = accepted;
                if (accepted) BeginEmptyTargetSkipFixture();
            }
        }
        CheckConcurrency();

        if (!retargetStarted && logicalTic >= RUN_TICS)
            BeginRetargetFixture();
        if (emptySkipStarted && !emptySkipReported
            && dsp034SkippedChildren > 0)
        {
            emptySkipReported = true;
            Console.Printf("DS_P034_MAP20_EMPTY_SKIP accepted=1 skipped_children=%d system_id=34 reason=NO_LIVE_TARGET", dsp034SkippedChildren);
        }

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
        if (emptySkipReported && retargetProofReported) EmitPass();
        else if (logicalTic >= RUN_TICS + 50)
            Console.Printf("DS_ASSERT_FAIL P034_MAP20_POST_MATRIX_GATE_TIMEOUT retarget=%d empty_skip=%d tic=%d", retargetProofReported ? 1 : 0, emptySkipReported ? 1 : 0, logicalTic);
    }
}
