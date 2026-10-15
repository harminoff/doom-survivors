// P035 source-plane ballistic schedules, paths, walls and swept logical hits.
// All geometry is adapter-owned and all accepted damage passes through P025.
// Native Doom projectile motion/collision is presentation-only and disabled.
class DSP035BallisticProxy : DSProjectileProxyBase
{
    int logicalEventId;

    Default
    {
        Radius 1;
        Height 2;
        +NOBLOCKMAP;
        +NOGRAVITY;
        +NOINTERACTION;
        RenderStyle "Add";
        Alpha 0.88;
        // First-person projectiles need to read as attacks without covering
        // the view when their logical source-plane path passes near the camera.
        // This is presentation-only; the logical radius and collision stay
        // owned by the projectile arrays below.
        Scale 0.07;
    }

    States
    {
    Spawn:
        BILL A 1 Bright;
        Loop;
    }
}

mixin class DSP035BallisticProjectileRuntime
{
    const DSP035_EVENT_BASE = 3500000;
    const DSP035_MAX_ACTIVE_BURSTS = 96;
    // Hard backstop for DSP035ProcessBallisticTic's per-tic burst-child
    // drain loop -- see AimedProjectileRuntime.zs's identical constant for
    // the rationale.
    const DSP035_MAX_BURST_DRAIN_ITERATIONS_PER_TIC = 100000;

    Array<int> dsp035WeaponSystems;
    Array<int> dsp035WeaponRanks;
    Array<int> dsp035WeaponSlots;
    Array<int> dsp035WeaponGenerations;
    Array<int> dsp035WeaponIds;
    Array<int> dsp035NextVolleyMilliTics;

    // Each top-level attack keeps an independent child schedule. This allows
    // overlapping volleys without replacing unfinished children.
    Array<int> dsp035BurstActive;
    Array<int> dsp035BurstWeaponIndexes;
    Array<int> dsp035BurstVolleyIds;
    Array<int> dsp035BurstNextChildMilliTics;
    Array<int> dsp035BurstRemainingChildren;
    Array<int> dsp035BurstChildOrdinal;
    Array<int> dsp035BurstDamageTenths;
    Array<int> dsp035BurstAmount;
    Array<int> dsp035BurstPierce;
    Array<int> dsp035BurstChildIntervalMillis;
    Array<int> dsp035BurstSpeedMilli;
    Array<int> dsp035BurstAreaMilli;
    Array<int> dsp035BurstLaunchSpeed;
    Array<int> dsp035BurstAccelerationY;
    Array<int> dsp035BurstRange;
    Array<int> dsp035BurstLifetime;
    Array<int> dsp035BurstRadiusMilli;
    Array<int> dsp035BurstPoolLimit;
    Array<int> dsp035BurstPathKind;
    Array<int> dsp035BurstTargetPolicy;
    Array<int> dsp035BurstWallPolicy;
    Array<int> dsp035BurstSpreadStepMilli;
    Array<int> dsp035BurstRadialChildCount;
    Array<int> dsp035BurstMightMilli;
    Array<int> dsp035BurstAdjustedCooldown;
    Array<int> dsp035BurstRankHash;
    Array<int> dsp035BurstAimYawMilli;
    Array<int> dsp035BurstViewYawMilli;
    Array<int> dsp035BurstTargetSlot;
    Array<int> dsp035BurstTargetGeneration;
    Array<int> dsp035BurstTargetId;
    Array<int> dsp035BurstTargetFound;
    Array<int> dsp035BurstRngBefore;
    Array<int> dsp035BurstRngAfter;

    Array<int> dsp035ProjectileActive;
    Array<int> dsp035ProjectileEvents;
    Array<int> dsp035ProjectileParents;
    Array<int> dsp035ProjectileSystems;
    Array<int> dsp035ProjectileRanks;
    Array<int> dsp035ProjectileChildOrdinals;
    Array<int> dsp035ProjectileWeaponSlots;
    Array<int> dsp035ProjectileWeaponGenerations;
    Array<int> dsp035ProjectileWeaponIds;
    Array<int> dsp035ProjectileOwnerSlots;
    Array<int> dsp035ProjectileOwnerGenerations;
    Array<int> dsp035ProjectileOwnerIds;
    Array<int> dsp035ProjectileDamageTenths;
    Array<int> dsp035ProjectileMightMilli;
    Array<int> dsp035ProjectilePierce;
    Array<int> dsp035ProjectilePierceUsed;
    Array<int> dsp035ProjectileExpireTics;
    Array<int> dsp035ProjectileLifetimeTics;
    Array<int> dsp035ProjectileAgeTics;
    Array<int> dsp035ProjectileRange;
    Array<int> dsp035ProjectileRadiusMilli;
    Array<int> dsp035ProjectilePathKind;
    Array<int> dsp035ProjectileWallPolicy;
    Array<int> dsp035ProjectileLaunchSpeed;
    Array<int> dsp035ProjectileAccelerationY;
    Array<int> dsp035ProjectileAimYawMilli;
    Array<int> dsp035ProjectileRankHash;
    Array<int> dsp035ProjectileHitCount;
    Array<double> dsp035ProjectileOriginX;
    Array<double> dsp035ProjectileOriginY;
    Array<double> dsp035ProjectileX;
    Array<double> dsp035ProjectileY;
    Array<double> dsp035ProjectileVelocityX;
    Array<double> dsp035ProjectileVelocityY;
    Array<double> dsp035ProjectileTravelled;
    Array<DSP035BallisticProxy> dsp035ProjectileProxies;

    Array<int> dsp035HitProjectileEvents;
    Array<int> dsp035HitTargetSlots;
    Array<int> dsp035HitTargetGenerations;
    Array<int> dsp035HitTargetIds;

    Array<double> dsp035CollisionFractions;
    Array<int> dsp035CollisionSlots;
    Array<int> dsp035CollisionGenerations;
    Array<int> dsp035CollisionIds;

    // The host owns the wall fixture source and supplies stable logical line
    // segments. Wall tests never query native Doom lines or projectile impact.
    Array<int> dsp035WallIds;
    Array<double> dsp035WallStartX;
    Array<double> dsp035WallStartY;
    Array<double> dsp035WallEndX;
    Array<double> dsp035WallEndY;

    int dsp035EventOrdinal;
    int dsp035VolleyOrdinal;
    int dsp035EmittedChildren;
    int dsp035SkippedChildren;
    int dsp035AcceptedHits;
    int dsp035RejectedHits;
    int dsp035AcceptedDamageMilli;

    void DSP035ResetLogicalWalls()
    {
        dsp035WallIds.Clear();
        dsp035WallStartX.Clear(); dsp035WallStartY.Clear();
        dsp035WallEndX.Clear(); dsp035WallEndY.Clear();
    }

    bool DSP035AddLogicalWall(int stableId, double startX, double startY,
        double endX, double endY)
    {
        if (stableId <= 0 || (startX == endX && startY == endY)) return false;
        for (int i = 0; i < dsp035WallIds.Size(); i++)
            if (dsp035WallIds[i] == stableId) return false;
        dsp035WallIds.Push(stableId);
        dsp035WallStartX.Push(startX); dsp035WallStartY.Push(startY);
        dsp035WallEndX.Push(endX); dsp035WallEndY.Push(endY);
        return true;
    }

    void DSP035ResetBallisticRuntime(int seed)
    {
        for (int i = 0; i < dsp035ProjectileProxies.Size(); i++)
            if (dsp035ProjectileProxies[i] != null)
                dsp035ProjectileProxies[i].Destroy();

        dsp035WeaponSystems.Clear(); dsp035WeaponRanks.Clear();
        dsp035WeaponSlots.Clear(); dsp035WeaponGenerations.Clear();
        dsp035WeaponIds.Clear(); dsp035NextVolleyMilliTics.Clear();
        dsp035BurstActive.Clear(); dsp035BurstWeaponIndexes.Clear();
        dsp035BurstVolleyIds.Clear(); dsp035BurstNextChildMilliTics.Clear();
        dsp035BurstRemainingChildren.Clear(); dsp035BurstChildOrdinal.Clear();
        dsp035BurstDamageTenths.Clear(); dsp035BurstAmount.Clear();
        dsp035BurstPierce.Clear(); dsp035BurstChildIntervalMillis.Clear();
        dsp035BurstSpeedMilli.Clear(); dsp035BurstAreaMilli.Clear();
        dsp035BurstLaunchSpeed.Clear(); dsp035BurstAccelerationY.Clear();
        dsp035BurstRange.Clear(); dsp035BurstLifetime.Clear();
        dsp035BurstRadiusMilli.Clear(); dsp035BurstPoolLimit.Clear();
        dsp035BurstPathKind.Clear(); dsp035BurstTargetPolicy.Clear();
        dsp035BurstWallPolicy.Clear(); dsp035BurstSpreadStepMilli.Clear();
        dsp035BurstRadialChildCount.Clear(); dsp035BurstMightMilli.Clear();
        dsp035BurstAdjustedCooldown.Clear(); dsp035BurstRankHash.Clear();
        dsp035BurstAimYawMilli.Clear(); dsp035BurstTargetSlot.Clear();
        dsp035BurstViewYawMilli.Clear();
        dsp035BurstTargetGeneration.Clear(); dsp035BurstTargetId.Clear();
        dsp035BurstTargetFound.Clear(); dsp035BurstRngBefore.Clear();
        dsp035BurstRngAfter.Clear();
        dsp035ProjectileActive.Clear(); dsp035ProjectileEvents.Clear();
        dsp035ProjectileParents.Clear(); dsp035ProjectileSystems.Clear();
        dsp035ProjectileRanks.Clear(); dsp035ProjectileChildOrdinals.Clear();
        dsp035ProjectileWeaponSlots.Clear();
        dsp035ProjectileWeaponGenerations.Clear();
        dsp035ProjectileWeaponIds.Clear(); dsp035ProjectileOwnerSlots.Clear();
        dsp035ProjectileOwnerGenerations.Clear();
        dsp035ProjectileOwnerIds.Clear(); dsp035ProjectileDamageTenths.Clear();
        dsp035ProjectileMightMilli.Clear(); dsp035ProjectilePierce.Clear();
        dsp035ProjectilePierceUsed.Clear(); dsp035ProjectileExpireTics.Clear();
        dsp035ProjectileLifetimeTics.Clear(); dsp035ProjectileAgeTics.Clear();
        dsp035ProjectileRange.Clear(); dsp035ProjectileRadiusMilli.Clear();
        dsp035ProjectilePathKind.Clear(); dsp035ProjectileWallPolicy.Clear();
        dsp035ProjectileLaunchSpeed.Clear();
        dsp035ProjectileAccelerationY.Clear();
        dsp035ProjectileAimYawMilli.Clear(); dsp035ProjectileRankHash.Clear();
        dsp035ProjectileHitCount.Clear(); dsp035ProjectileOriginX.Clear();
        dsp035ProjectileOriginY.Clear(); dsp035ProjectileX.Clear();
        dsp035ProjectileY.Clear(); dsp035ProjectileVelocityX.Clear();
        dsp035ProjectileVelocityY.Clear(); dsp035ProjectileTravelled.Clear();
        dsp035ProjectileProxies.Clear(); dsp035HitProjectileEvents.Clear();
        dsp035HitTargetSlots.Clear(); dsp035HitTargetGenerations.Clear();
        dsp035HitTargetIds.Clear(); dsp035CollisionFractions.Clear();
        dsp035CollisionSlots.Clear(); dsp035CollisionGenerations.Clear();
        dsp035CollisionIds.Clear();
        DSP035ResetLogicalWalls();
        DSP035ResetTargeting(seed);
        dsp035EventOrdinal = 0; dsp035VolleyOrdinal = 0;
        dsp035EmittedChildren = 0; dsp035SkippedChildren = 0;
        dsp035AcceptedHits = 0; dsp035RejectedHits = 0;
        dsp035AcceptedDamageMilli = 0;
        { if (!dsQuiet) Console.Printf("DS_P035_RUNTIME_RESET seed=%d rng_stream=DEDICATED_P025_XORSHIFT walls=LOGICAL_FIXTURES native_projectiles=VISUAL_ONLY", seed); }
    }

    bool DSP035LoadRankRow(int systemId, int rank,
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

    bool DSP035EquipFixture(int systemId, int rank, int weaponSlot,
        int firstFireTic)
    {
        int damageTenths; int amount; int pierce; int cooldownMillis;
        int childIntervalMillis; int speedMilli; int areaMilli;
        int launchSpeed; int accelerationY; int maxRange; int lifetime;
        int radiusMilli; int poolLimit; int pathKind; int targetPolicy;
        int wallPolicy; int spreadStep; int radialCount;
        if (!DSP035LoadRankRow(systemId, rank, damageTenths, amount, pierce,
                cooldownMillis, childIntervalMillis, speedMilli, areaMilli,
                launchSpeed, accelerationY, maxRange, lifetime, radiusMilli,
                poolLimit, pathKind, targetPolicy, wallPolicy, spreadStep,
                radialCount)
            || weaponSlot < 0 || weaponSlot >= lifeStates.Size()
            || lifeStates[weaponSlot] != STORE_ALIVE || firstFireTic < 0)
            return false;

        dsp035WeaponSystems.Push(systemId);
        dsp035WeaponRanks.Push(rank);
        dsp035WeaponSlots.Push(weaponSlot);
        dsp035WeaponGenerations.Push(generations[weaponSlot]);
        dsp035WeaponIds.Push(ids[weaponSlot]);
        dsp035NextVolleyMilliTics.Push(firstFireTic * 1000);
        { if (!dsQuiet) Console.Printf("DS_P035_EQUIP accepted=1 system_id=%d rank=%d weapon_slot=%d weapon_generation=%d weapon_id=%d first_fire_tic=%d classification=CONTROLLED_MAP16_FIXTURE source_inventory_claim=0", systemId, rank, weaponSlot, generations[weaponSlot], ids[weaponSlot], firstFireTic); }
        return true;
    }

    bool DSP035SetFixtureRank(int weaponSlot, int systemId, int rank,
        int logicalTic)
    {
        int d; int a; int p; int c; int ci; int sm; int am; int ls; int ay;
        int mr; int lt; int cr; int pl; int pk; int tp; int wp; int ss; int rc;
        if (!DSP035LoadRankRow(systemId, rank, d, a, p, c, ci, sm, am,
                ls, ay, mr, lt, cr, pl, pk, tp, wp, ss, rc)) return false;
        for (int i = 0; i < dsp035WeaponSystems.Size(); i++)
        {
            if (dsp035WeaponSlots[i] != weaponSlot) continue;
            if (!ValidParts(weaponSlot, dsp035WeaponGenerations[i],
                    dsp035WeaponIds[i])
                || dsp035WeaponSystems[i] != systemId) return false;
            int oldRank = dsp035WeaponRanks[i];
            dsp035WeaponRanks[i] = rank;
            { if (!dsQuiet) Console.Printf("DS_P035_FIXTURE_RANK accepted=1 tic=%d system_id=%d prior_rank=%d rank=%d weapon_id=%d weapon_generation=%d classification=CONTROLLED_MAP16_FIXTURE source_inventory_claim=0", logicalTic, systemId, oldRank, rank, dsp035WeaponIds[i], dsp035WeaponGenerations[i]); }
            return true;
        }
        return false;
    }

    void DSP035CancelWeaponSchedule(int weaponIndex, int logicalTic,
        out int canceledBursts, out int canceledProjectiles)
    {
        canceledBursts = 0;
        canceledProjectiles = 0;
        for (int i = 0; i < dsp035BurstActive.Size(); i++)
        {
            if (dsp035BurstActive[i] == 0
                || dsp035BurstWeaponIndexes[i] != weaponIndex) continue;
            dsp035BurstActive[i] = 0;
            canceledBursts++;
        }
        for (int i = 0; i < dsp035ProjectileActive.Size(); i++)
        {
            if (dsp035ProjectileActive[i] == 0
                || dsp035ProjectileWeaponSlots[i] != dsp035WeaponSlots[weaponIndex]
                || dsp035ProjectileWeaponGenerations[i]
                    != dsp035WeaponGenerations[weaponIndex]
                || dsp035ProjectileWeaponIds[i] != dsp035WeaponIds[weaponIndex])
                continue;
            DSP035RetireProjectile(i, "FORM_REPLACED", logicalTic);
            canceledProjectiles++;
        }
    }

    bool DSP035ReplaceFixture(int weaponSlot, int evolvedSystemId,
        int evolvedRank, int logicalTic, bool dependencySatisfied,
        int dependencyRank)
    {
        int sourceSystemId; int sourceRank; int dependencyKind;
        int dependencyMinRank;
        if (!DSP035WeaponRows.TryGetTransformation(evolvedSystemId,
                sourceSystemId, sourceRank, dependencyKind,
                dependencyMinRank) || !dependencySatisfied
            || dependencyRank < dependencyMinRank) return false;
        int d; int a; int p; int c; int ci; int sm; int am; int ls; int ay;
        int mr; int lt; int cr; int pl; int pk; int tp; int wp; int ss; int rc;
        if (!DSP035LoadRankRow(evolvedSystemId, evolvedRank, d, a, p, c,
                ci, sm, am, ls, ay, mr, lt, cr, pl, pk, tp, wp, ss, rc))
            return false;
        for (int i = 0; i < dsp035WeaponSystems.Size(); i++)
        {
            if (dsp035WeaponSlots[i] != weaponSlot) continue;
            if (!ValidParts(weaponSlot, dsp035WeaponGenerations[i],
                    dsp035WeaponIds[i])
                || dsp035WeaponSystems[i] != sourceSystemId
                || dsp035WeaponRanks[i] < sourceRank) return false;
            int oldSystem = dsp035WeaponSystems[i];
            int oldRank = dsp035WeaponRanks[i];
            int canceledBursts; int canceledProjectiles;
            DSP035CancelWeaponSchedule(i, logicalTic, canceledBursts,
                canceledProjectiles);
            dsp035WeaponSystems[i] = evolvedSystemId;
            dsp035WeaponRanks[i] = evolvedRank;
            dsp035NextVolleyMilliTics[i] = logicalTic * 1000;
            { if (!dsQuiet) Console.Printf("DS_P035_FORM_REPLACE accepted=1 tic=%d source_system_id=%d source_rank=%d evolved_system_id=%d evolved_rank=%d weapon_id=%d weapon_generation=%d dependency_kind=%d dependency_min_rank=%d dependency_rank=%d canceled_bursts=%d canceled_projectiles=%d source=CONTROLLED_MAP16_FIXTURE", logicalTic, oldSystem, oldRank, evolvedSystemId, evolvedRank, dsp035WeaponIds[i], dsp035WeaponGenerations[i], dependencyKind, dependencyMinRank, dependencyRank, canceledBursts, canceledProjectiles); }
            return true;
        }
        return false;
    }

    int DSP035NewEventId()
    {
        dsp035EventOrdinal++;
        return DSP035_EVENT_BASE + dsp035EventOrdinal;
    }

    int DSP035ScaledDamageMilli(int damageTenths, int mightMilli,
        out bool valid)
    {
        int scaledTenths = 0;
        valid = DSP025CheckedDamage(damageTenths, 0, mightMilli,
            scaledTenths) && scaledTenths >= 0 && scaledTenths <= 20000000;
        return valid ? scaledTenths * 100 : 0;
    }

    int DSP035ActiveProjectileCount(int systemId)
    {
        int count = 0;
        for (int i = 0; i < dsp035ProjectileActive.Size(); i++)
            if (dsp035ProjectileActive[i] != 0
                && dsp035ProjectileSystems[i] == systemId) count++;
        return count;
    }

    int DSP035ActiveBurstsForWeapon(int weaponIndex)
    {
        int count = 0;
        for (int i = 0; i < dsp035BurstActive.Size(); i++)
            if (dsp035BurstActive[i] != 0
                && dsp035BurstWeaponIndexes[i] == weaponIndex) count++;
        return count;
    }

    bool DSP035StartVolley(int weaponIndex, int logicalTic,
        int viewYawMilli, int cooldownMultiplierMilli, int rankHash)
    {
        int systemId = dsp035WeaponSystems[weaponIndex];
        int rank = dsp035WeaponRanks[weaponIndex];
        int damageTenths; int amount; int pierce; int cooldownMillis;
        int childIntervalMillis; int speedMultiplierMilli;
        int areaMultiplierMilli; int launchSpeed; int accelerationY;
        int maxRange; int lifetime; int radiusMilli; int poolLimit;
        int pathKind; int targetPolicy; int wallPolicy; int spreadStep;
        int radialCount;
        if (!ValidParts(dsp035WeaponSlots[weaponIndex],
                dsp035WeaponGenerations[weaponIndex], dsp035WeaponIds[weaponIndex])
            || !DSP035LoadRankRow(systemId, rank, damageTenths, amount,
                pierce, cooldownMillis, childIntervalMillis,
                speedMultiplierMilli, areaMultiplierMilli, launchSpeed,
                accelerationY, maxRange, lifetime, radiusMilli, poolLimit,
                pathKind, targetPolicy, wallPolicy, spreadStep, radialCount))
        {
            Console.Printf("DS_P035_VOLLEY_REJECT system_id=%d rank=%d reason=STALE_WEAPON_OR_ROW", systemId, rank);
            return false;
        }
        if (rsActive)
        {
            int lbAmountNow = RsAmountFor(systemId);
            amount += lbAmountNow; poolLimit += lbAmountNow;
            if (radialCount > 0) radialCount += lbAmountNow;
            speedMultiplierMilli = speedMultiplierMilli * RsSpeedFor(systemId) / 1000;
            maxRange = maxRange * RsSpeedFor(systemId) / 1000;
            areaMultiplierMilli = areaMultiplierMilli * RsAreaFor(systemId) / 1000;
            // Kyra-Stones: one more stone per 25 enemies alive (up to +6).
            if (systemId == DSN3Rows.SYSTEM_KYRA_STONES && DSP030VerticalSlice(self) != null)
            {
                int crowd = min(6, DSP030VerticalSlice(self).LiveEnemyCount() / 25);
                amount += crowd; poolLimit += crowd;
            }
        }

        int actualSpeed = launchSpeed * speedMultiplierMilli / 1000;
        int adjustedCooldown = DSP033StatRules.CooldownAfterTome(systemId,
            cooldownMillis, cooldownMultiplierMilli);
        if (amount <= 0 || pierce <= 0 || adjustedCooldown <= 0
            || childIntervalMillis <= 0 || actualSpeed <= 0
            || maxRange <= 0 || lifetime <= 0 || radiusMilli <= 0
            || poolLimit <= 0 || pathKind <= 0 || targetPolicy <= 0
            || wallPolicy <= 0)
        {
            Console.Printf("DS_P035_VOLLEY_REJECT system_id=%d rank=%d reason=INVALID_ROW_OR_SCHEDULE", systemId, rank);
            return false;
        }

        int burstIndex = -1;
        for (int i = 0; i < dsp035BurstActive.Size(); i++)
            if (dsp035BurstActive[i] == 0) { burstIndex = i; break; }
        if (burstIndex < 0)
        {
            int activeCount = 0;
            for (int i = 0; i < dsp035BurstActive.Size(); i++)
                if (dsp035BurstActive[i] != 0) activeCount++;
            if (activeCount >= DSP035_MAX_ACTIVE_BURSTS) return false;
            burstIndex = dsp035BurstActive.Size();
            dsp035BurstActive.Push(0); dsp035BurstWeaponIndexes.Push(0);
            dsp035BurstVolleyIds.Push(0); dsp035BurstNextChildMilliTics.Push(0);
            dsp035BurstRemainingChildren.Push(0); dsp035BurstChildOrdinal.Push(0);
            dsp035BurstDamageTenths.Push(0); dsp035BurstAmount.Push(0);
            dsp035BurstPierce.Push(0); dsp035BurstChildIntervalMillis.Push(0);
            dsp035BurstSpeedMilli.Push(0); dsp035BurstAreaMilli.Push(0);
            dsp035BurstLaunchSpeed.Push(0); dsp035BurstAccelerationY.Push(0);
            dsp035BurstRange.Push(0); dsp035BurstLifetime.Push(0);
            dsp035BurstRadiusMilli.Push(0); dsp035BurstPoolLimit.Push(0);
            dsp035BurstPathKind.Push(0); dsp035BurstTargetPolicy.Push(0);
            dsp035BurstWallPolicy.Push(0); dsp035BurstSpreadStepMilli.Push(0);
            dsp035BurstRadialChildCount.Push(0); dsp035BurstMightMilli.Push(1000);
            dsp035BurstAdjustedCooldown.Push(0); dsp035BurstRankHash.Push(0);
            dsp035BurstAimYawMilli.Push(0); dsp035BurstTargetSlot.Push(-1);
            dsp035BurstViewYawMilli.Push(0);
            dsp035BurstTargetGeneration.Push(0); dsp035BurstTargetId.Push(0);
            dsp035BurstTargetFound.Push(0); dsp035BurstRngBefore.Push(0);
            dsp035BurstRngAfter.Push(0);
        }

        int targetSlot = -1; int targetGeneration = 0; int targetId = 0;
        int rngBefore = dsp035AttackRng; int rngAfter = dsp035AttackRng;
        int aimYaw = DSP035NormalizeYawMilli(viewYawMilli);
        bool targetFound = true;
        if (targetPolicy
            == DSP035WeaponRows.TARGET_RANDOM_LIVE_ENEMY_SNAPSHOT)
        {
            targetFound = DSP035ChooseRandomLiveTarget(DSP035_TARGET_ENEMY,
                targetSlot, targetGeneration, targetId, rngBefore, rngAfter);
            if (targetFound)
            {
                aimYaw = DSP035YawToPoint(playerX, playerY,
                    x[targetSlot], y[targetSlot]);
                if (x[targetSlot] == playerX && y[targetSlot] == playerY)
                    aimYaw = DSP035NormalizeYawMilli(viewYawMilli);
            }
        }

        int volleyId = DSP035_EVENT_BASE + 100000 + ++dsp035VolleyOrdinal;
        dsp035NextVolleyMilliTics[weaponIndex] = logicalTic * 1000
            + adjustedCooldown * Thinker.TICRATE;
        dsp035BurstActive[burstIndex] = 1;
        dsp035BurstWeaponIndexes[burstIndex] = weaponIndex;
        dsp035BurstVolleyIds[burstIndex] = volleyId;
        dsp035BurstNextChildMilliTics[burstIndex] = logicalTic * 1000;
        dsp035BurstRemainingChildren[burstIndex] = amount;
        dsp035BurstChildOrdinal[burstIndex] = 0;
        dsp035BurstDamageTenths[burstIndex] = damageTenths;
        dsp035BurstAmount[burstIndex] = amount;
        dsp035BurstPierce[burstIndex] = pierce + RsPierceFor(systemId);
        dsp035BurstChildIntervalMillis[burstIndex] = childIntervalMillis;
        dsp035BurstSpeedMilli[burstIndex] = speedMultiplierMilli;
        dsp035BurstAreaMilli[burstIndex] = areaMultiplierMilli;
        dsp035BurstLaunchSpeed[burstIndex] = launchSpeed;
        dsp035BurstAccelerationY[burstIndex] = accelerationY;
        dsp035BurstRange[burstIndex] = maxRange;
        dsp035BurstLifetime[burstIndex] = lifetime;
        dsp035BurstRadiusMilli[burstIndex] = radiusMilli;
        dsp035BurstPoolLimit[burstIndex] = poolLimit;
        dsp035BurstPathKind[burstIndex] = pathKind;
        dsp035BurstTargetPolicy[burstIndex] = targetPolicy;
        dsp035BurstWallPolicy[burstIndex] = wallPolicy;
        dsp035BurstSpreadStepMilli[burstIndex] = spreadStep;
        dsp035BurstRadialChildCount[burstIndex] = radialCount;
        dsp035BurstMightMilli[burstIndex] = dsp033ResolvedValid
            && DSP033StatRules.StatApplies(DSP033StatRules.STAT_MIGHT, systemId)
            ? DSP033Resolved(DSP033StatRules.STAT_MIGHT) : 1000;
        if (rsActive) dsp035BurstMightMilli[burstIndex] = RsMightFor(systemId);
        dsp035BurstAdjustedCooldown[burstIndex] = adjustedCooldown;
        dsp035BurstRankHash[burstIndex] = rankHash;
        dsp035BurstAimYawMilli[burstIndex] = aimYaw;
        dsp035BurstViewYawMilli[burstIndex] = DSP035NormalizeYawMilli(viewYawMilli);
        dsp035BurstTargetSlot[burstIndex] = targetSlot;
        dsp035BurstTargetGeneration[burstIndex] = targetGeneration;
        dsp035BurstTargetId[burstIndex] = targetId;
        dsp035BurstTargetFound[burstIndex] = targetFound ? 1 : 0;
        dsp035BurstRngBefore[burstIndex] = rngBefore;
        dsp035BurstRngAfter[burstIndex] = rngAfter;
        DSSound.Weapon(systemId);
        { if (!dsQuiet) Console.Printf("DS_P035_VOLLEY event_id=%d tic=%d system_id=%d rank=%d weapon_id=%d weapon_generation=%d amount=%d pierce=%d cooldown_ms=%d child_interval_ms=%d speed_milli=%d launch_speed=%d actual_speed=%d acceleration_y=%d range=%d lifetime=%d radius_milli=%d area_milli=%d path_kind=%d target_policy=%d wall_policy=%d spread_step_mdeg=%d radial_children=%d target_found=%d target_id=%d aim_yaw_milli=%d target_selection=ONCE_PER_VOLLEY rng_before=%d rng_after=%d rng_stream=DEDICATED_P025 cooldown_stat_applies=1 child_interval_stat_applies=0", volleyId, logicalTic, systemId, rank, dsp035WeaponIds[weaponIndex], dsp035WeaponGenerations[weaponIndex], amount, pierce, adjustedCooldown, childIntervalMillis, speedMultiplierMilli, launchSpeed, actualSpeed, accelerationY, maxRange, lifetime, radiusMilli, areaMultiplierMilli, pathKind, targetPolicy, wallPolicy, spreadStep, radialCount, targetFound ? 1 : 0, targetId, aimYaw, rngBefore, rngAfter); }
        return true;
    }

    int DSP035NewProjectileEvent()
    {
        dsp035EventOrdinal++;
        return DSP035_EVENT_BASE + dsp035EventOrdinal;
    }

    bool DSP035HasProjectileHit(int eventId, int slot, int generation,
        int stableId)
    {
        for (int i = 0; i < dsp035HitProjectileEvents.Size(); i++)
            if (dsp035HitProjectileEvents[i] == eventId
                && dsp035HitTargetSlots[i] == slot
                && dsp035HitTargetGenerations[i] == generation
                && dsp035HitTargetIds[i] == stableId) return true;
        return false;
    }

    void DSP035RecordProjectileHit(int eventId, int slot, int generation,
        int stableId)
    {
        dsp035HitProjectileEvents.Push(eventId);
        dsp035HitTargetSlots.Push(slot);
        dsp035HitTargetGenerations.Push(generation);
        dsp035HitTargetIds.Push(stableId);
    }

    bool DSP035SpawnChild(int burstIndex, int logicalTic,
        int ownerSlot, int ownerGeneration, int ownerStableId,
        int currentViewYawMilli)
    {
        int weaponIndex = dsp035BurstWeaponIndexes[burstIndex];
        int systemId = dsp035WeaponSystems[weaponIndex];
        int rank = dsp035WeaponRanks[weaponIndex];
        int ordinal = dsp035BurstChildOrdinal[burstIndex];
        if (!ValidParts(ownerSlot, ownerGeneration, ownerStableId)
            || !ValidParts(dsp035WeaponSlots[weaponIndex],
                dsp035WeaponGenerations[weaponIndex], dsp035WeaponIds[weaponIndex]))
        {
            dsp035SkippedChildren++;
            Console.Printf("DS_P035_CHILD_SKIP tic=%d system_id=%d volley_id=%d child_ordinal=%d reason=STALE_OWNER_OR_WEAPON", logicalTic, systemId, dsp035BurstVolleyIds[burstIndex], ordinal);
            return false;
        }
        if (dsp035BurstTargetPolicy[burstIndex] == 3
            && dsp035BurstTargetFound[burstIndex] == 0)
        {
            dsp035SkippedChildren++;
            Console.Printf("DS_P035_CHILD_SKIP tic=%d system_id=%d volley_id=%d child_ordinal=%d reason=NO_LIVE_RANDOM_TARGET rng_draw=0", logicalTic, systemId, dsp035BurstVolleyIds[burstIndex], ordinal);
            return false;
        }
        if (DSP035ActiveProjectileCount(systemId)
            >= dsp035BurstPoolLimit[burstIndex])
        {
            dsp035SkippedChildren++;
            Console.Printf("DS_P035_CHILD_SKIP tic=%d system_id=%d volley_id=%d child_ordinal=%d reason=PROJECTILE_POOL_FULL", logicalTic, systemId, dsp035BurstVolleyIds[burstIndex], ordinal);
            return false;
        }

        int pathKind = dsp035BurstPathKind[burstIndex];
        int aimYaw = dsp035BurstAimYawMilli[burstIndex];
        int countForSpread = dsp035BurstAmount[burstIndex];
        if (pathKind == DSP035WeaponRows.PATH_AXE_ARC)
        {
            // The first child is fixed to source-plane +Y; following children
            // use the approved view-facing half-plane spread. Normal play
            // throws the first axe along the view instead (first person).
            if (ordinal == 0) aimYaw = rsActive ? dsp035BurstViewYawMilli[burstIndex] : 90000;
            else
            {
                int extraCount = countForSpread - 1;
                int halfSpread = dsp035BurstSpreadStepMilli[burstIndex];
                aimYaw = DSP035FanYawMilli(dsp035BurstViewYawMilli[burstIndex],
                    ordinal - 1, extraCount, halfSpread);
            }
        }
        else if (pathKind == DSP035WeaponRows.PATH_RADIAL)
        {
            int rays = dsp035BurstRadialChildCount[burstIndex];
            if (rays <= 0) rays = countForSpread;
            // Normal play: each volley's ring turns 17 degrees (Death Spiral).
            aimYaw = DSP035RadialYawMilli(ordinal, rays,
                rsActive ? (dsp035BurstVolleyIds[burstIndex] * 17000) % 360000 : 0);
        }
        // N3 ballistic adapter (Song of Mana/Mannajja, DSN3Rows systems
        // SONG_OF_MANA/MANNAJJA): the source fires a fixed vertical beam at
        // a random horizontal offset near the player. No existing P035 path
        // kind models a fixed direction with a randomized start offset, so
        // this branch is new engine surface, labelled per
        // docs/contracts/remaining-weapons.md Track A ("a new adapter
        // branch is added only where the mapping names a mechanic the
        // engine lacks"). Direction 270000 milli-degrees is source-plane -Y
        // ("downward"); this is an ENGINEERING_FALLBACK convention, not a
        // claim about the source's actual screen orientation.
        else if (pathKind == DSP035WeaponRows.PATH_VERTICAL_FALL)
        {
            aimYaw = 270000;
        }
        else
        {
            int adjacentStep = dsp035BurstSpreadStepMilli[burstIndex];
            int halfSpread = adjacentStep * (countForSpread - 1) / 2;
            aimYaw = DSP035FanYawMilli(dsp035BurstAimYawMilli[burstIndex],
                ordinal, countForSpread, halfSpread);
        }

        double directionX; double directionY;
        DSP035YawDirection(aimYaw, directionX, directionY);
        int launchSpeed = dsp035BurstLaunchSpeed[burstIndex]
            * dsp035BurstSpeedMilli[burstIndex] / 1000;
        double velocityX = directionX * double(launchSpeed);
        double velocityY = directionY * double(launchSpeed);
        int eventId = DSP035NewProjectileEvent();
        int targetSlot = dsp035BurstTargetFound[burstIndex] != 0
            ? dsp035BurstTargetSlot[burstIndex] : -1;
        int targetGeneration = dsp035BurstTargetGeneration[burstIndex];
        int targetId = dsp035BurstTargetId[burstIndex];
        int baseRadiusMilli = dsp035BurstRadiusMilli[burstIndex];
        int areaMilli = dsp035BurstAreaMilli[burstIndex];
        if (baseRadiusMilli <= 0 || areaMilli <= 0
            || baseRadiusMilli > 2147483647 / areaMilli)
        {
            dsp035SkippedChildren++;
            Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P035_RADIUS_AREA_OVERFLOW tic=%d system_id=%d base_radius_milli=%d area_milli=%d", logicalTic, systemId, baseRadiusMilli, areaMilli);
            Console.Printf("DS_P035_CHILD_SKIP tic=%d system_id=%d volley_id=%d child_ordinal=%d reason=INVALID_RADIUS_AREA", logicalTic, systemId, dsp035BurstVolleyIds[burstIndex], ordinal);
            return false;
        }
        int effectiveRadiusMilli = baseRadiusMilli * areaMilli / 1000;
        if (effectiveRadiusMilli <= 0)
        {
            dsp035SkippedChildren++;
            Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P035_RADIUS_AREA_ZERO tic=%d system_id=%d base_radius_milli=%d area_milli=%d", logicalTic, systemId, baseRadiusMilli, areaMilli);
            Console.Printf("DS_P035_CHILD_SKIP tic=%d system_id=%d volley_id=%d child_ordinal=%d reason=INVALID_RADIUS_AREA", logicalTic, systemId, dsp035BurstVolleyIds[burstIndex], ordinal);
            return false;
        }
        DSP025AttackSnapshot snapshot;
        DSP025PopulateSnapshot(snapshot, eventId,
            dsp035BurstVolleyIds[burstIndex], ownerSlot, ownerGeneration,
            ownerStableId, dsp035WeaponIds[weaponIndex],
            dsp035WeaponGenerations[weaponIndex],
            dsp035BurstDamageTenths[burstIndex], 0,
            dsp035BurstMightMilli[burstIndex],
            dsp035BurstPierce[burstIndex],
            dsp035BurstAmount[burstIndex],
            logicalTic + dsp035BurstLifetime[burstIndex], 0, 0,
            aimYaw, dsp035BurstRngBefore[burstIndex],
            dsp035BurstRngAfter[burstIndex]);
        snapshot.explicitTargetSlot = targetSlot;
        snapshot.explicitTargetGeneration = targetGeneration;
        snapshot.explicitTargetStableId = targetId;

        int index = dsp035ProjectileActive.Size();
        dsp035ProjectileActive.Push(1); dsp035ProjectileEvents.Push(eventId);
        dsp035ProjectileParents.Push(snapshot.parentEventId);
        dsp035ProjectileSystems.Push(systemId); dsp035ProjectileRanks.Push(rank);
        dsp035ProjectileChildOrdinals.Push(ordinal);
        dsp035ProjectileWeaponSlots.Push(dsp035WeaponSlots[weaponIndex]);
        dsp035ProjectileWeaponGenerations.Push(dsp035WeaponGenerations[weaponIndex]);
        dsp035ProjectileWeaponIds.Push(dsp035WeaponIds[weaponIndex]);
        dsp035ProjectileOwnerSlots.Push(ownerSlot);
        dsp035ProjectileOwnerGenerations.Push(ownerGeneration);
        dsp035ProjectileOwnerIds.Push(ownerStableId);
        dsp035ProjectileDamageTenths.Push(snapshot.damageBase);
        dsp035ProjectileMightMilli.Push(snapshot.multiplierMilli);
        dsp035ProjectilePierce.Push(snapshot.pierce);
        dsp035ProjectilePierceUsed.Push(0);
        dsp035ProjectileExpireTics.Push(logicalTic + dsp035BurstLifetime[burstIndex]);
        dsp035ProjectileLifetimeTics.Push(dsp035BurstLifetime[burstIndex]);
        dsp035ProjectileAgeTics.Push(0);
        dsp035ProjectileRange.Push(dsp035BurstRange[burstIndex]);
        dsp035ProjectileRadiusMilli.Push(effectiveRadiusMilli);
        dsp035ProjectilePathKind.Push(pathKind);
        dsp035ProjectileWallPolicy.Push(dsp035BurstWallPolicy[burstIndex]);
        dsp035ProjectileLaunchSpeed.Push(launchSpeed);
        dsp035ProjectileAccelerationY.Push(dsp035BurstAccelerationY[burstIndex]);
        dsp035ProjectileAimYawMilli.Push(aimYaw);
        dsp035ProjectileRankHash.Push(dsp035BurstRankHash[burstIndex]);
        dsp035ProjectileHitCount.Push(0);
        double originX = playerX; double originY = playerY;
        if (pathKind == DSP035WeaponRows.PATH_VERTICAL_FALL)
        {
            // Same labelled N3 adapter as the aimYaw branch above: draw a
            // deterministic horizontal start offset from the dedicated
            // P025 attack-rng stream (the same stream Fire Wand/Hellfire's
            // random-target draw already uses) and start the beam a full
            // range's length "above" the player so its downward travel
            // sweeps through the player's row. ENGINEERING_APPROXIMATION,
            // not a source-measured spawn point.
            dsp035AttackRng = DSP025NextAttackRng(dsp035AttackRng);
            int nonnegativeOffset = dsp035AttackRng & 0x7fffffff;
            int rangeUnits = dsp035BurstRange[burstIndex];
            int offsetUnits = (nonnegativeOffset % (rangeUnits + 1))
                - (rangeUnits / 2);
            originX = playerX + double(offsetUnits);
            originY = playerY + double(rangeUnits);
        }
        dsp035ProjectileOriginX.Push(originX); dsp035ProjectileOriginY.Push(originY);
        dsp035ProjectileX.Push(originX); dsp035ProjectileY.Push(originY);
        dsp035ProjectileVelocityX.Push(velocityX);
        dsp035ProjectileVelocityY.Push(velocityY);
        dsp035ProjectileTravelled.Push(0.0);
        DSP035BallisticProxy proxy = DSP035BallisticProxy(Actor.Spawn(
            "DSP035BallisticProxy", (originX, originY, DSProjectileProxyBase.VISUAL_Z), NO_REPLACE));
        if (proxy != null)
        {
            proxy.logicalEventId = eventId;
            proxy.logicalSystemId = systemId;
        }
        dsp035ProjectileProxies.Push(proxy);
        dsp035EmittedChildren++;
        { if (!dsQuiet) Console.Printf("DS_P035_PROJECTILE event_id=%d parent_event_id=%d tic=%d system_id=%d rank=%d child_ordinal=%d owner_id=%d weapon_id=%d weapon_generation=%d target_id=%d aim_yaw_milli=%d vx=%.6f vy=%.6f damage_tenths=%d might_milli=%d pierce=%d path_kind=%d range=%d lifetime_tics=%d radius_milli=%d base_radius_milli=%d area_milli=%d wall_policy=%d rank_hash=%d snapshot=1 pitch_input=0 native_motion=VISUAL_ONLY", eventId, snapshot.parentEventId, logicalTic, systemId, rank, ordinal, ownerStableId, dsp035WeaponIds[weaponIndex], dsp035WeaponGenerations[weaponIndex], targetId, aimYaw, velocityX, velocityY, snapshot.damageBase, snapshot.multiplierMilli, snapshot.pierce, pathKind, dsp035ProjectileRange[index], dsp035BurstLifetime[burstIndex], dsp035ProjectileRadiusMilli[index], baseRadiusMilli, areaMilli, dsp035ProjectileWallPolicy[index], dsp035ProjectileRankHash[index]); }
        return true;
    }

    bool DSP035LineCircleEntry(double startX, double startY,
        double endX, double endY, double centerX, double centerY,
        double radius, out double fraction)
    {
        fraction = 0.0;
        double dx = endX - startX; double dy = endY - startY;
        double mx = startX - centerX; double my = startY - centerY;
        double c = mx * mx + my * my - radius * radius;
        if (c <= 0.0) return true;
        double a = dx * dx + dy * dy;
        if (a <= 0.0000001) return false;
        double b = 2.0 * (mx * dx + my * dy);
        double discriminant = b * b - 4.0 * a * c;
        if (discriminant < 0.0) return false;
        double entry = (-b - sqrt(discriminant)) / (2.0 * a);
        if (entry < 0.0 || entry > 1.0) return false;
        fraction = entry;
        return true;
    }

    bool DSP035LineIntersection(double startX, double startY,
        double endX, double endY, double wallStartX, double wallStartY,
        double wallEndX, double wallEndY, out double fraction)
    {
        fraction = 0.0;
        double rx = endX - startX; double ry = endY - startY;
        double sx = wallEndX - wallStartX;
        double sy = wallEndY - wallStartY;
        double denominator = rx * sy - ry * sx;
        if (denominator == 0.0) return false;
        double qx = wallStartX - startX;
        double qy = wallStartY - startY;
        double t = (qx * sy - qy * sx) / denominator;
        double u = (qx * ry - qy * rx) / denominator;
        if (t < 0.0 || t > 1.0 || u < 0.0 || u > 1.0) return false;
        fraction = t;
        return true;
    }

    int DSP035FindWallBlock(double startX, double startY,
        double endX, double endY, out double fraction)
    {
        int bestId = 0;
        fraction = 2.0;
        for (int i = 0; i < dsp035WallIds.Size(); i++)
        {
            double candidate;
            if (!DSP035LineIntersection(startX, startY, endX, endY,
                    dsp035WallStartX[i], dsp035WallStartY[i],
                    dsp035WallEndX[i], dsp035WallEndY[i], candidate)) continue;
            if (candidate < fraction || (candidate == fraction
                    && dsp035WallIds[i] < bestId))
            {
                fraction = candidate;
                bestId = dsp035WallIds[i];
            }
        }
        return bestId;
    }

    bool DSP035CollisionPrecedes(int left, int right)
    {
        if (dsp035CollisionFractions[left] != dsp035CollisionFractions[right])
            return dsp035CollisionFractions[left] < dsp035CollisionFractions[right];
        if (dsp035CollisionIds[left] != dsp035CollisionIds[right])
            return dsp035CollisionIds[left] < dsp035CollisionIds[right];
        if (dsp035CollisionGenerations[left] != dsp035CollisionGenerations[right])
            return dsp035CollisionGenerations[left] < dsp035CollisionGenerations[right];
        return dsp035CollisionSlots[left] < dsp035CollisionSlots[right];
    }

    void DSP035SwapCollisions(int left, int right)
    {
        double fraction = dsp035CollisionFractions[left];
        dsp035CollisionFractions[left] = dsp035CollisionFractions[right];
        dsp035CollisionFractions[right] = fraction;
        int value = dsp035CollisionSlots[left];
        dsp035CollisionSlots[left] = dsp035CollisionSlots[right];
        dsp035CollisionSlots[right] = value;
        value = dsp035CollisionGenerations[left];
        dsp035CollisionGenerations[left] = dsp035CollisionGenerations[right];
        dsp035CollisionGenerations[right] = value;
        value = dsp035CollisionIds[left];
        dsp035CollisionIds[left] = dsp035CollisionIds[right];
        dsp035CollisionIds[right] = value;
    }

    void DSP035CollectSegmentCollisions(int projectileIndex,
        double startX, double startY, double endX, double endY,
        double wallFraction)
    {
        dsp035CollisionFractions.Clear(); dsp035CollisionSlots.Clear();
        dsp035CollisionGenerations.Clear(); dsp035CollisionIds.Clear();
        double projectileRadius = double(dsp035ProjectileRadiusMilli[projectileIndex]) / 1000.0;
        DSP024SweptCandidates(startX, startY, endX, endY,
            projectileRadius + 32.0);
        for (int i = 0; i < spatialCandidateCount; i++)
        {
            int slot = spatialCandidateSlots[i];
            int generation = spatialCandidateGenerations[i];
            int stableId = spatialCandidateIds[i];
            if (!ValidParts(slot, generation, stableId)
                || kinds[slot] != DSP035_TARGET_ENEMY || health[slot] <= 0
                || DSP035HasProjectileHit(dsp035ProjectileEvents[projectileIndex],
                    slot, generation, stableId)) continue;
            double fraction;
            double targetRadius = collisionRadii[slot] + projectileRadius;
            if (!DSP035LineCircleEntry(startX, startY, endX, endY,
                    x[slot], y[slot], targetRadius, fraction)) continue;
            if (dsp035ProjectileWallPolicy[projectileIndex]
                    == DSP035WeaponRows.WALL_BLOCK
                && fraction >= wallFraction) continue;
            dsp035CollisionFractions.Push(fraction);
            dsp035CollisionSlots.Push(slot);
            dsp035CollisionGenerations.Push(generation);
            dsp035CollisionIds.Push(stableId);
        }
        for (int i = 1; i < dsp035CollisionFractions.Size(); i++)
        {
            int j = i;
            while (j > 0 && DSP035CollisionPrecedes(j, j - 1))
            {
                DSP035SwapCollisions(j, j - 1);
                j--;
            }
        }
    }

    void DSP035RetireProjectile(int index, String reason, int logicalTic)
    {
        if (index < 0 || index >= dsp035ProjectileActive.Size()
            || dsp035ProjectileActive[index] == 0) return;
        dsp035ProjectileActive[index] = 0;
        if (dsp035ProjectileProxies[index] != null)
        {
            dsp035ProjectileProxies[index].Destroy();
            dsp035ProjectileProxies[index] = null;
        }
        { if (!dsQuiet) Console.Printf("DS_P035_PROJECTILE_END event_id=%d tic=%d system_id=%d reason=%s hit_count=%d traveled=%.3f", dsp035ProjectileEvents[index], logicalTic, dsp035ProjectileSystems[index], reason, dsp035ProjectileHitCount[index], dsp035ProjectileTravelled[index]); }
    }

    void DSP035ProcessProjectile(int index, int logicalTic)
    {
        if (dsp035ProjectileActive[index] == 0) return;
        if (!ValidParts(dsp035ProjectileOwnerSlots[index],
                dsp035ProjectileOwnerGenerations[index],
                dsp035ProjectileOwnerIds[index]))
        { DSP035RetireProjectile(index, "OWNER_GENERATION_REPLACED", logicalTic); return; }
        if (!ValidParts(dsp035ProjectileWeaponSlots[index],
                dsp035ProjectileWeaponGenerations[index],
                dsp035ProjectileWeaponIds[index]))
        { DSP035RetireProjectile(index, "WEAPON_GENERATION_REPLACED", logicalTic); return; }
        if (logicalTic > dsp035ProjectileExpireTics[index])
        { DSP035RetireProjectile(index, "LIFETIME_EXPIRED", logicalTic); return; }

        // Age increments only on authoritative logical movement steps.
        int ageTics = dsp035ProjectileAgeTics[index];
        double t0 = double(ageTics) / double(Thinker.TICRATE);
        double t1 = double(ageTics + 1) / double(Thinker.TICRATE);
        double startX; double startY; double endX; double endY;
        int pathKind = dsp035ProjectilePathKind[index];
        if (pathKind == DSP035WeaponRows.PATH_AXE_ARC && rsActive)
        {
            // Normal play (first person): the axe slows along its throw line,
            // stops and falls back past the player, arcing up visually.
            double vx = dsp035ProjectileVelocityX[index];
            double vy = dsp035ProjectileVelocityY[index];
            double sp = sqrt(vx * vx + vy * vy);
            double ux = sp > 0.0001 ? vx / sp : 0.0; double uy = sp > 0.0001 ? vy / sp : 1.0;
            double ay = double(dsp035ProjectileAccelerationY[index]);
            double d0 = sp * t0 + 0.5 * ay * t0 * t0; double d1 = sp * t1 + 0.5 * ay * t1 * t1;
            startX = dsp035ProjectileOriginX[index] + ux * d0; startY = dsp035ProjectileOriginY[index] + uy * d0;
            endX = dsp035ProjectileOriginX[index] + ux * d1; endY = dsp035ProjectileOriginY[index] + uy * d1;
        }
        else if (pathKind == DSP035WeaponRows.PATH_AXE_ARC)
        {
            double vx = dsp035ProjectileVelocityX[index];
            double vy = dsp035ProjectileVelocityY[index];
            double ay = double(dsp035ProjectileAccelerationY[index]);
            startX = dsp035ProjectileOriginX[index] + vx * t0;
            startY = dsp035ProjectileOriginY[index] + vy * t0 + 0.5 * ay * t0 * t0;
            endX = dsp035ProjectileOriginX[index] + vx * t1;
            endY = dsp035ProjectileOriginY[index] + vy * t1 + 0.5 * ay * t1 * t1;
        }
        else if (rsActive && dsp035ProjectileSystems[index] == DSP035WeaponRows.SYSTEM_DEATH_SPIRAL)
        {
            // Death Spiral: rays curl outward (60 degrees per second).
            double vx = dsp035ProjectileVelocityX[index];
            double vy = dsp035ProjectileVelocityY[index];
            double sp = sqrt(vx * vx + vy * vy);
            double a0 = atan2(vy, vx);
            startX = dsp035ProjectileOriginX[index] + cos(a0 + 60.0 * t0) * sp * t0;
            startY = dsp035ProjectileOriginY[index] + sin(a0 + 60.0 * t0) * sp * t0;
            endX = dsp035ProjectileOriginX[index] + cos(a0 + 60.0 * t1) * sp * t1;
            endY = dsp035ProjectileOriginY[index] + sin(a0 + 60.0 * t1) * sp * t1;
        }
        else
        {
            startX = dsp035ProjectileOriginX[index]
                + dsp035ProjectileVelocityX[index] * t0;
            startY = dsp035ProjectileOriginY[index]
                + dsp035ProjectileVelocityY[index] * t0;
            endX = dsp035ProjectileOriginX[index]
                + dsp035ProjectileVelocityX[index] * t1;
            endY = dsp035ProjectileOriginY[index]
                + dsp035ProjectileVelocityY[index] * t1;
        }
        double dx = endX - startX; double dy = endY - startY;
        double stepLength = sqrt(dx * dx + dy * dy);
        double remaining = double(dsp035ProjectileRange[index])
            - dsp035ProjectileTravelled[index];
        if (remaining <= 0.000001)
        { DSP035RetireProjectile(index, "RANGE_EXPIRED", logicalTic); return; }
        if (stepLength > remaining && stepLength > 0.000001)
        {
            double scale = remaining / stepLength;
            endX = startX + dx * scale;
            endY = startY + dy * scale;
            stepLength = remaining;
        }
        // Preserve the intended swept segment after range clipping but before
        // wall and pierce responses truncate the visible/final endpoint.
        double sweepEndX = endX;
        double sweepEndY = endY;

        double wallFraction = 2.0;
        int crossingWall = DSP035FindWallBlock(startX, startY, endX, endY,
            wallFraction);
        int blockingWall = dsp035ProjectileWallPolicy[index]
            == DSP035WeaponRows.WALL_BLOCK ? crossingWall : 0;
        DSP035CollectSegmentCollisions(index, startX, startY, endX, endY,
            wallFraction);
        int acceptedThisStep = 0;
        double finalHitFraction = 0.0;
        for (int i = 0; i < dsp035CollisionFractions.Size(); i++)
        {
            if (dsp035ProjectilePierceUsed[index]
                >= dsp035ProjectilePierce[index]) break;
            int slot = dsp035CollisionSlots[i];
            int generation = dsp035CollisionGenerations[i];
            int stableId = dsp035CollisionIds[i];
            if (!ValidParts(slot, generation, stableId) || health[slot] <= 0
                || DSP035HasProjectileHit(dsp035ProjectileEvents[index],
                    slot, generation, stableId)) continue;
            int damageTenths = 0;
            bool checked = DSP025CheckedDamage(
                dsp035ProjectileDamageTenths[index], 0,
                dsp035ProjectileMightMilli[index], damageTenths);
            bool validDamage = checked && damageTenths >= 0
                && damageTenths <= 20000000;
            int damageMilli = validDamage ? damageTenths * 100 : 0;
            int before; int after; int killed;
            arHitSystem = dsp035ProjectileSystems[index];   // which weapon hit (Arcana scope)
            bool applied = validDamage && DSP025ApplyLogicalHit(slot,
                generation, stableId, damageMilli, before, after, killed);
            if (!applied)
            {
                dsp035RejectedHits++;
                { if (!dsQuiet) Console.Printf("DS_P035_HIT event_id=%d tic=%d system_id=%d target_id=%d accepted=0 reason=STALE_OR_INVALID_DAMAGE", dsp035ProjectileEvents[index], logicalTic, dsp035ProjectileSystems[index], stableId); }
                continue;
            }
            DSP035RecordProjectileHit(dsp035ProjectileEvents[index], slot,
                generation, stableId);
            dsp035ProjectilePierceUsed[index]++;
            dsp035ProjectileHitCount[index]++;
            dsp035AcceptedHits++;
            acceptedThisStep++;
            finalHitFraction = dsp035CollisionFractions[i];
            int acceptedDamage = before - after;
            if (acceptedDamage < 0 || dsp035AcceptedDamageMilli
                    > 2147483647 - acceptedDamage)
                Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P035_ACCEPTED_DAMAGE_OVERFLOW tic=%d total=%d delta=%d", logicalTic, dsp035AcceptedDamageMilli, acceptedDamage);
            else dsp035AcceptedDamageMilli += acceptedDamage;
            { if (!dsQuiet) Console.Printf("DS_P035_HIT event_id=%d parent_event_id=%d tic=%d system_id=%d rank=%d child_ordinal=%d target_slot=%d target_generation=%d target_id=%d fraction=%.6f hit_x=%.6f hit_y=%.6f damage_tenths=%d might_milli=%d damage_milli=%d before=%d after=%d pierce_used=%d pierce=%d accepted=1 authority=P025_CHECKED_LOGICAL_HIT rank_hash=%d", dsp035ProjectileEvents[index], dsp035ProjectileParents[index], logicalTic, dsp035ProjectileSystems[index], dsp035ProjectileRanks[index], dsp035ProjectileChildOrdinals[index], slot, generation, stableId, dsp035CollisionFractions[i], startX + dx * dsp035CollisionFractions[i], startY + dy * dsp035CollisionFractions[i], dsp035ProjectileDamageTenths[index], dsp035ProjectileMightMilli[index], damageMilli, before, after, dsp035ProjectilePierceUsed[index], dsp035ProjectilePierce[index], dsp035ProjectileRankHash[index]); }
            if (killed != 0) HandleEnemyDeath(slot, before,
                dsp035ProjectileEvents[index]);
        }

        bool wallBlocked = blockingWall != 0;
        if (wallBlocked)
        {
            endX = startX + dx * wallFraction;
            endY = startY + dy * wallFraction;
            { if (!dsQuiet) Console.Printf("DS_P035_WALL_BLOCK event_id=%d tic=%d system_id=%d wall_id=%d fraction=%.6f policy=BLOCK authority=LOGICAL_SEGMENT", dsp035ProjectileEvents[index], logicalTic, dsp035ProjectileSystems[index], blockingWall, wallFraction); }
        }
        else if (crossingWall != 0
            && dsp035ProjectileWallPolicy[index] == DSP035WeaponRows.WALL_PASS)
            { if (!dsQuiet) Console.Printf("DS_P035_WALL_PASS event_id=%d tic=%d system_id=%d wall_id=%d fraction=%.6f policy=PASS native_wall_response=IGNORED authority=LOGICAL_SEGMENT", dsp035ProjectileEvents[index], logicalTic, dsp035ProjectileSystems[index], crossingWall, wallFraction); }

        if (dsp035ProjectilePierceUsed[index]
            >= dsp035ProjectilePierce[index] && acceptedThisStep > 0)
        {
            endX = startX + dx * finalHitFraction;
            endY = startY + dy * finalHitFraction;
        }
        double actualDx = endX - startX;
        double actualDy = endY - startY;
        double actualStepLength = sqrt(actualDx * actualDx + actualDy * actualDy);
        dsp035ProjectileX[index] = endX; dsp035ProjectileY[index] = endY;
        dsp035ProjectileTravelled[index] += actualStepLength;
        dsp035ProjectileAgeTics[index]++;
        { if (!dsQuiet) Console.Printf("DS_P035_PATH_STEP event_id=%d tic=%d system_id=%d rank=%d child_ordinal=%d age_tic=%d path_kind=%d start_x=%.6f start_y=%.6f sweep_end_x=%.6f sweep_end_y=%.6f end_x=%.6f end_y=%.6f traveled=%.6f acceleration_y=%d native_gravity=IGNORED", dsp035ProjectileEvents[index], logicalTic, dsp035ProjectileSystems[index], dsp035ProjectileRanks[index], dsp035ProjectileChildOrdinals[index], ageTics, pathKind, startX, startY, sweepEndX, sweepEndY, endX, endY, dsp035ProjectileTravelled[index], dsp035ProjectileAccelerationY[index]); }
        if (dsp035ProjectileProxies[index] != null)
        {
            double z = DSProjectileProxyBase.VISUAL_Z;
            if (pathKind == DSP035WeaponRows.PATH_AXE_ARC && rsActive)
            {
                // Presentation only: a high arc over its lifetime.
                double f = double(dsp035ProjectileAgeTics[index]) / max(1, dsp035ProjectileLifetimeTics[index]);
                z += 240.0 * f * (1.0 - f);
            }
            else if (pathKind == DSP035WeaponRows.PATH_AXE_ARC)
            {
                double arcHeight = endY - dsp035ProjectileOriginY[index];
                z += arcHeight * 0.05;
            }
            dsp035ProjectileProxies[index].SetOrigin((endX, endY, z), true);
        }
        if (dsp035ProjectilePierceUsed[index]
            >= dsp035ProjectilePierce[index])
            DSP035RetireProjectile(index, "PIERCE_EXHAUSTED", logicalTic);
        else if (wallBlocked)
            DSP035RetireProjectile(index, "LOGICAL_WALL_BLOCKED", logicalTic);
        else if (dsp035ProjectileTravelled[index]
            >= double(dsp035ProjectileRange[index]) - 0.000001)
            DSP035RetireProjectile(index, "RANGE_EXPIRED", logicalTic);
        else if (dsp035ProjectileAgeTics[index]
            >= dsp035ProjectileLifetimeTics[index])
            DSP035RetireProjectile(index, "LIFETIME_EXPIRED", logicalTic);
    }

    void DSP035ProcessBallisticTic(int logicalTic, int ownerSlot,
        int ownerGeneration, int ownerStableId, double originX,
        double originY, int viewYawMilli, int cooldownMultiplierMilli,
        int rankHash)
    {
        for (int i = 0; i < dsp035ProjectileActive.Size(); i++)
            DSP035ProcessProjectile(i, logicalTic);

        // The controlled route equips in canonical stable-ID order; explicitly
        // select that order for scheduling independent automatic weapons.
        int previousStable = 0;
        for (int ordinal = 0; ordinal < dsp035WeaponSystems.Size(); ordinal++)
        {
            int best = -1; int bestStable = 2147483647;
            for (int i = 0; i < dsp035WeaponSystems.Size(); i++)
            {
                int stableId = dsp035WeaponIds[i];
                if (stableId > previousStable && stableId < bestStable)
                { best = i; bestStable = stableId; }
            }
            if (best < 0) break;
            previousStable = bestStable;
            if (logicalTic * 1000 < dsp035NextVolleyMilliTics[best]) continue;
            if (!DSP035StartVolley(best, logicalTic, viewYawMilli,
                    cooldownMultiplierMilli, rankHash))
                dsp035NextVolleyMilliTics[best] = logicalTic * 1000
                    + 1000 * Thinker.TICRATE;
        }

        // N2 hang fix: see AimedProjectileRuntime.zs's identical drain loop
        // for the full rationale. This loop's termination likewise depends
        // on every active burst's remaining-child count strictly decreasing
        // and its interval being positive (enforced at DSP035StartVolley
        // time today); a bounded iteration counter plus a zero-interval
        // guard make it provably terminating rather than trusting every
        // upstream caller forever.
        int drainIterations = 0;
        while (true)
        {
            if (++drainIterations > DSP035_MAX_BURST_DRAIN_ITERATIONS_PER_TIC)
            {
                Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P035_BURST_DRAIN_RUNAWAY tic=%d iterations=%d classification=N2_DISPATCHER", logicalTic, drainIterations);
                for (int burst = 0; burst < dsp035BurstActive.Size(); burst++)
                    dsp035BurstActive[burst] = 0;
                break;
            }
            int bestBurst = -1;
            int bestWeaponStable = 2147483647;
            int bestVolley = 2147483647;
            for (int burst = 0; burst < dsp035BurstActive.Size(); burst++)
            {
                if (dsp035BurstActive[burst] == 0
                    || dsp035BurstRemainingChildren[burst] <= 0
                    || logicalTic * 1000
                        < dsp035BurstNextChildMilliTics[burst]) continue;
                int weaponIndex = dsp035BurstWeaponIndexes[burst];
                if (weaponIndex < 0 || weaponIndex >= dsp035WeaponSystems.Size()) continue;
                int stableId = dsp035WeaponIds[weaponIndex];
                int volley = dsp035BurstVolleyIds[burst];
                if (stableId < bestWeaponStable
                    || (stableId == bestWeaponStable && volley < bestVolley))
                {
                    bestBurst = burst; bestWeaponStable = stableId;
                    bestVolley = volley;
                }
            }
            if (bestBurst < 0) break;
            DSP035SpawnChild(bestBurst, logicalTic, ownerSlot,
                ownerGeneration, ownerStableId, viewYawMilli);
            dsp035BurstChildOrdinal[bestBurst]++;
            dsp035BurstRemainingChildren[bestBurst]--;
            dsp035BurstNextChildMilliTics[bestBurst] +=
                dsp035BurstChildIntervalMillis[bestBurst] * Thinker.TICRATE;
            if (dsp035BurstRemainingChildren[bestBurst] <= 0)
            {
                dsp035BurstActive[bestBurst] = 0;
                { if (!dsQuiet) Console.Printf("DS_P035_BURST_COMPLETE volley_id=%d tic=%d system_id=%d children=%d", dsp035BurstVolleyIds[bestBurst], logicalTic, dsp035WeaponSystems[dsp035BurstWeaponIndexes[bestBurst]], dsp035BurstAmount[bestBurst]); }
            }
            // Defense in depth: DSP035StartVolley already rejects a
            // childIntervalMillis <= 0 row; if that guard is ever bypassed,
            // a zero/negative interval would leave
            // dsp035BurstNextChildMilliTics unadvanced forever while
            // remainingChildren stays > 0, spinning this loop indefinitely.
            if (dsp035BurstChildIntervalMillis[bestBurst] <= 0)
            {
                { if (!dsQuiet) Console.Printf("DS_P035_BURST_MALFORMED burst=%d interval_millis=%d action=DEACTIVATED", bestBurst, dsp035BurstChildIntervalMillis[bestBurst]); }
                dsp035BurstActive[bestBurst] = 0;
            }
        }
        if (originX != playerX || originY != playerY)
            { if (!dsQuiet) Console.Printf("DS_P035_ORIGIN_DIAGNOSTIC tic=%d supplied_x=%.3f supplied_y=%.3f logical_x=%.3f logical_y=%.3f", logicalTic, originX, originY, playerX, playerY); }
    }

    int DSP035HashMix(int hash, int value)
    {
        int normalized = value % 1000003;
        if (normalized < 0) normalized += 1000003;
        return (hash * 31 + normalized) % 1000003;
    }

    int DSP035HashMixDoubleMilli(int hash, double value)
    {
        int quantized;
        if (value >= 2000000.0) quantized = 2000000000;
        else if (value <= -2000000.0) quantized = -2000000000;
        else quantized = int(value * 1000.0);
        return DSP035HashMix(hash, quantized);
    }

    int DSP035HashWeaponState(int hash, int i)
    {
        hash = DSP035HashMix(hash, dsp035WeaponSystems[i]);
        hash = DSP035HashMix(hash, dsp035WeaponRanks[i]);
        hash = DSP035HashMix(hash, dsp035WeaponSlots[i]);
        hash = DSP035HashMix(hash, dsp035WeaponGenerations[i]);
        hash = DSP035HashMix(hash, dsp035WeaponIds[i]);
        hash = DSP035HashMix(hash, dsp035NextVolleyMilliTics[i]);
        return hash;
    }

    int DSP035HashBurstState(int hash, int i)
    {
        hash = DSP035HashMix(hash, dsp035BurstActive[i]);
        if (dsp035BurstActive[i] == 0) return hash;
        hash = DSP035HashMix(hash, dsp035BurstWeaponIndexes[i]);
        hash = DSP035HashMix(hash, dsp035BurstVolleyIds[i]);
        hash = DSP035HashMix(hash, dsp035BurstNextChildMilliTics[i]);
        hash = DSP035HashMix(hash, dsp035BurstRemainingChildren[i]);
        hash = DSP035HashMix(hash, dsp035BurstChildOrdinal[i]);
        hash = DSP035HashMix(hash, dsp035BurstDamageTenths[i]);
        hash = DSP035HashMix(hash, dsp035BurstAmount[i]);
        hash = DSP035HashMix(hash, dsp035BurstPierce[i]);
        hash = DSP035HashMix(hash, dsp035BurstChildIntervalMillis[i]);
        hash = DSP035HashMix(hash, dsp035BurstSpeedMilli[i]);
        hash = DSP035HashMix(hash, dsp035BurstAreaMilli[i]);
        hash = DSP035HashMix(hash, dsp035BurstLaunchSpeed[i]);
        hash = DSP035HashMix(hash, dsp035BurstAccelerationY[i]);
        hash = DSP035HashMix(hash, dsp035BurstRange[i]);
        hash = DSP035HashMix(hash, dsp035BurstLifetime[i]);
        hash = DSP035HashMix(hash, dsp035BurstRadiusMilli[i]);
        hash = DSP035HashMix(hash, dsp035BurstPoolLimit[i]);
        hash = DSP035HashMix(hash, dsp035BurstPathKind[i]);
        hash = DSP035HashMix(hash, dsp035BurstTargetPolicy[i]);
        hash = DSP035HashMix(hash, dsp035BurstWallPolicy[i]);
        hash = DSP035HashMix(hash, dsp035BurstSpreadStepMilli[i]);
        hash = DSP035HashMix(hash, dsp035BurstRadialChildCount[i]);
        hash = DSP035HashMix(hash, dsp035BurstMightMilli[i]);
        hash = DSP035HashMix(hash, dsp035BurstAdjustedCooldown[i]);
        hash = DSP035HashMix(hash, dsp035BurstRankHash[i]);
        hash = DSP035HashMix(hash, dsp035BurstAimYawMilli[i]);
        hash = DSP035HashMix(hash, dsp035BurstViewYawMilli[i]);
        hash = DSP035HashMix(hash, dsp035BurstTargetSlot[i]);
        hash = DSP035HashMix(hash, dsp035BurstTargetGeneration[i]);
        hash = DSP035HashMix(hash, dsp035BurstTargetId[i]);
        hash = DSP035HashMix(hash, dsp035BurstTargetFound[i]);
        hash = DSP035HashMix(hash, dsp035BurstRngBefore[i]);
        hash = DSP035HashMix(hash, dsp035BurstRngAfter[i]);
        return hash;
    }

    int DSP035HashProjectileState(int hash, int i)
    {
        hash = DSP035HashMix(hash, dsp035ProjectileActive[i]);
        if (dsp035ProjectileActive[i] == 0) return hash;
        hash = DSP035HashMix(hash, dsp035ProjectileEvents[i]);
        hash = DSP035HashMix(hash, dsp035ProjectileParents[i]);
        hash = DSP035HashMix(hash, dsp035ProjectileSystems[i]);
        hash = DSP035HashMix(hash, dsp035ProjectileRanks[i]);
        hash = DSP035HashMix(hash, dsp035ProjectileChildOrdinals[i]);
        hash = DSP035HashMix(hash, dsp035ProjectileWeaponSlots[i]);
        hash = DSP035HashMix(hash, dsp035ProjectileWeaponGenerations[i]);
        hash = DSP035HashMix(hash, dsp035ProjectileWeaponIds[i]);
        hash = DSP035HashMix(hash, dsp035ProjectileOwnerSlots[i]);
        hash = DSP035HashMix(hash, dsp035ProjectileOwnerGenerations[i]);
        hash = DSP035HashMix(hash, dsp035ProjectileOwnerIds[i]);
        hash = DSP035HashMix(hash, dsp035ProjectileDamageTenths[i]);
        hash = DSP035HashMix(hash, dsp035ProjectileMightMilli[i]);
        hash = DSP035HashMix(hash, dsp035ProjectilePierce[i]);
        hash = DSP035HashMix(hash, dsp035ProjectilePierceUsed[i]);
        hash = DSP035HashMix(hash, dsp035ProjectileExpireTics[i]);
        hash = DSP035HashMix(hash, dsp035ProjectileLifetimeTics[i]);
        hash = DSP035HashMix(hash, dsp035ProjectileAgeTics[i]);
        hash = DSP035HashMix(hash, dsp035ProjectileRange[i]);
        hash = DSP035HashMix(hash, dsp035ProjectileRadiusMilli[i]);
        hash = DSP035HashMix(hash, dsp035ProjectilePathKind[i]);
        hash = DSP035HashMix(hash, dsp035ProjectileWallPolicy[i]);
        hash = DSP035HashMix(hash, dsp035ProjectileLaunchSpeed[i]);
        hash = DSP035HashMix(hash, dsp035ProjectileAccelerationY[i]);
        hash = DSP035HashMix(hash, dsp035ProjectileAimYawMilli[i]);
        hash = DSP035HashMix(hash, dsp035ProjectileRankHash[i]);
        hash = DSP035HashMix(hash, dsp035ProjectileHitCount[i]);
        hash = DSP035HashMixDoubleMilli(hash, dsp035ProjectileOriginX[i]);
        hash = DSP035HashMixDoubleMilli(hash, dsp035ProjectileOriginY[i]);
        hash = DSP035HashMixDoubleMilli(hash, dsp035ProjectileX[i]);
        hash = DSP035HashMixDoubleMilli(hash, dsp035ProjectileY[i]);
        hash = DSP035HashMixDoubleMilli(hash, dsp035ProjectileVelocityX[i]);
        hash = DSP035HashMixDoubleMilli(hash, dsp035ProjectileVelocityY[i]);
        hash = DSP035HashMixDoubleMilli(hash, dsp035ProjectileTravelled[i]);
        return hash;
    }

    int DSP035HashLedgerState(int hash, int i)
    {
        hash = DSP035HashMix(hash, dsp035HitProjectileEvents[i]);
        hash = DSP035HashMix(hash, dsp035HitTargetSlots[i]);
        hash = DSP035HashMix(hash, dsp035HitTargetGenerations[i]);
        hash = DSP035HashMix(hash, dsp035HitTargetIds[i]);
        return hash;
    }

    int DSP035HashWallState(int hash, int i)
    {
        hash = DSP035HashMix(hash, dsp035WallIds[i]);
        hash = DSP035HashMixDoubleMilli(hash, dsp035WallStartX[i]);
        hash = DSP035HashMixDoubleMilli(hash, dsp035WallStartY[i]);
        hash = DSP035HashMixDoubleMilli(hash, dsp035WallEndX[i]);
        hash = DSP035HashMixDoubleMilli(hash, dsp035WallEndY[i]);
        return hash;
    }

    int DSP035BallisticStateHash()
    {
        int hash = 29;
        hash = DSP035HashMix(hash, dsp035EventOrdinal);
        hash = DSP035HashMix(hash, dsp035VolleyOrdinal);
        hash = DSP035HashMix(hash, dsp035EmittedChildren);
        hash = DSP035HashMix(hash, dsp035SkippedChildren);
        hash = DSP035HashMix(hash, dsp035AcceptedHits);
        hash = DSP035HashMix(hash, dsp035RejectedHits);
        hash = DSP035HashMix(hash, dsp035AcceptedDamageMilli);
        hash = DSP035HashMix(hash, dsp035AttackRng);
        hash = DSP035HashMix(hash, dsp035WeaponSystems.Size());
        hash = DSP035HashMix(hash, dsp035BurstActive.Size());
        hash = DSP035HashMix(hash, dsp035ProjectileActive.Size());
        hash = DSP035HashMix(hash, dsp035HitProjectileEvents.Size());
        hash = DSP035HashMix(hash, dsp035WallIds.Size());
        for (int i = 0; i < dsp035WeaponSystems.Size(); i++)
            hash = DSP035HashWeaponState(hash, i);
        for (int i = 0; i < dsp035BurstActive.Size(); i++)
            hash = DSP035HashBurstState(hash, i);
        for (int i = 0; i < dsp035ProjectileActive.Size(); i++)
            hash = DSP035HashProjectileState(hash, i);
        for (int i = 0; i < dsp035HitProjectileEvents.Size(); i++)
            hash = DSP035HashLedgerState(hash, i);
        for (int i = 0; i < dsp035WallIds.Size(); i++)
            hash = DSP035HashWallState(hash, i);
        return hash;
    }
}
