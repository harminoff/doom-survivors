// P036 logical outbound/reverse projectile authority.
// Source-plane movement, collision and damage are independent of native actors.
class DSP036ReturningProxy : DSProjectileProxyBase
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
        Scale 0.07;
    }

    States
    {
    Spawn:
        BILL A 1 Bright;
        Loop;
    }
}

mixin class DSP036ReturningProjectileRuntime
{
    const DSP036_EVENT_BASE = 3600000;
    const DSP036_MAX_ACTIVE_VOLLEYS = 64;
    // Hard backstop for DSP036ProcessReturningTic's per-tic child-drain loop
    // below, matching the same fix applied to Aimed/Ballistic's identical
    // loop shape (see AimedProjectileRuntime.zs's constant of the same
    // purpose). This loop already carries its own zero-interval guard; this
    // adds an iteration cap so termination never depends solely on that one
    // condition covering every future failure mode.
    const DSP036_MAX_VOLLEY_DRAIN_ITERATIONS_PER_TIC = 100000;
    const DSP036_PHASE_OUTBOUND = 1;
    const DSP036_PHASE_REVERSE = 2;

    Array<int> dsp036WeaponSystems;
    Array<int> dsp036WeaponRanks;
    Array<int> dsp036WeaponSlots;
    Array<int> dsp036WeaponGenerations;
    Array<int> dsp036WeaponIds;
    Array<int> dsp036WeaponNextVolleyMilliTics;

    // Each top-level schedule owns its own delayed child stream.
    Array<int> dsp036VolleyActive;
    Array<int> dsp036VolleyWeaponIndexes;
    Array<int> dsp036VolleyIds;
    Array<int> dsp036VolleyNextChildMilliTics;
    Array<int> dsp036VolleyRemainingChildren;
    Array<int> dsp036VolleyChildOrdinals;
    Array<int> dsp036VolleyTargetFound;
    Array<int> dsp036VolleyTargetSlots;
    Array<int> dsp036VolleyTargetGenerations;
    Array<int> dsp036VolleyTargetIds;
    Array<int> dsp036VolleyAimYawMilli;
    Array<int> dsp036VolleyRankHash;
    Array<int> dsp036VolleyMightMilli;
    Array<int> dsp036VolleyCooldownMilli;
    Array<int> dsp036VolleyCritChancePermille;
    Array<int> dsp036VolleyCritMultiplierMilli;
    Array<int> dsp036VolleyLuckAffectsCrit;
    Array<int> dsp036VolleyDamageTenths;
    Array<int> dsp036VolleyAreaMilli;
    Array<int> dsp036VolleySpeedMilli;
    Array<int> dsp036VolleyChildIntervalMillis;
    Array<int> dsp036VolleyPierceLimit;
    Array<int> dsp036VolleyPoolLimit;
    Array<int> dsp036VolleyLaunchSpeed;
    Array<int> dsp036VolleyOutboundBase;
    Array<int> dsp036VolleyReverseFactorMilli;
    Array<int> dsp036VolleyTotalFactorMilli;
    Array<int> dsp036VolleyLifetimeTics;
    Array<int> dsp036VolleyBaseRadiusMilli;
    Array<int> dsp036VolleyPathKind;
    Array<int> dsp036VolleyTargetPolicy;
    Array<int> dsp036VolleyReturnPolicy;
    Array<int> dsp036VolleyWallPolicy;
    Array<int> dsp036VolleyPassesPerLeg;

    Array<int> dsp036ProjectileActive;
    Array<int> dsp036ProjectileEvents;
    Array<int> dsp036ProjectileParents;
    Array<int> dsp036ProjectileSystems;
    Array<int> dsp036ProjectileRanks;
    Array<int> dsp036ProjectileChildOrdinals;
    Array<int> dsp036ProjectileWeaponSlots;
    Array<int> dsp036ProjectileWeaponGenerations;
    Array<int> dsp036ProjectileWeaponIds;
    Array<int> dsp036ProjectileOwnerSlots;
    Array<int> dsp036ProjectileOwnerGenerations;
    Array<int> dsp036ProjectileOwnerIds;
    Array<int> dsp036ProjectileTargetSlots;
    Array<int> dsp036ProjectileTargetGenerations;
    Array<int> dsp036ProjectileTargetIds;
    Array<int> dsp036ProjectileAimYawMilli;
    Array<int> dsp036ProjectilePhase;
    Array<int> dsp036ProjectilePassesCompleted;
    Array<int> dsp036ProjectileAgeTics;
    Array<int> dsp036ProjectileLifetimeTics;
    Array<int> dsp036ProjectileDamageTenths;
    Array<int> dsp036ProjectileMightMilli;
    Array<int> dsp036ProjectileCritChancePermille;
    Array<int> dsp036ProjectileCritMultiplierMilli;
    Array<int> dsp036ProjectileLuckAffectsCrit;
    Array<int> dsp036ProjectilePierceLimit;
    Array<int> dsp036ProjectileOutboundHitCount;
    Array<int> dsp036ProjectileReverseHitCount;
    Array<int> dsp036ProjectileSpeedUnitsPerSecond;
    Array<int> dsp036ProjectileOutboundDistance;
    Array<int> dsp036ProjectileReverseDistance;
    Array<int> dsp036ProjectileRangeBudget;
    Array<int> dsp036ProjectileRadiusMilli;
    Array<int> dsp036ProjectilePathKind;
    Array<int> dsp036ProjectileReturnPolicy;
    Array<int> dsp036ProjectileWallPolicy;
    Array<int> dsp036ProjectileRankHash;
    Array<double> dsp036ProjectileOriginX;
    Array<double> dsp036ProjectileOriginY;
    Array<double> dsp036ProjectileX;
    Array<double> dsp036ProjectileY;
    Array<double> dsp036ProjectileDirectionX;
    Array<double> dsp036ProjectileDirectionY;
    Array<double> dsp036ProjectileOutboundTravelled;
    Array<double> dsp036ProjectileReverseTravelled;
    Array<double> dsp036ProjectileTotalTravelled;
    Array<DSP036ReturningProxy> dsp036ProjectileProxies;

    // One target may be accepted once on each child leg, never once per frame.
    Array<int> dsp036HitProjectileEvents;
    Array<int> dsp036HitPasses;
    Array<int> dsp036HitTargetSlots;
    Array<int> dsp036HitTargetGenerations;
    Array<int> dsp036HitTargetIds;

    // Query-local collision order, sorted by segment fraction then stable ID.
    Array<double> dsp036CollisionFractions;
    Array<int> dsp036CollisionSlots;
    Array<int> dsp036CollisionGenerations;
    Array<int> dsp036CollisionIds;

    int dsp036VolleyOrdinal;
    int dsp036ProjectileOrdinal;
    int dsp036AcceptedHits;
    int dsp036RejectedHits;
    int dsp036SkippedChildren;
    int dsp036AcceptedDamageMilli;
    int dsp036EventOrdinal;

    bool DSP036LoadRankRow(int systemId, int rank,
        out int damageTenths, out int areaMilli, out int speedMilli,
        out int amount, out int cooldownMillis, out int childIntervalMillis,
        out int passLimit, out int poolLimit, out int critChancePermille,
        out int critMultiplierMilli, out int luckAffectsCrit,
        out int launchSpeedUnitsPerSecond, out int outboundBaseUnits,
        out int reverseDistanceFactorMilli, out int totalDistanceFactorMilli,
        out int lifetimeTics, out int baseRadiusMilliUnits,
        out int pathKind, out int targetPolicy, out int returnPolicy,
        out int wallPolicy, out int passesPerLeg)
    {
        if (!DSP036ReturningRows.TryGetRankRow(systemId, rank,
                damageTenths, areaMilli, speedMilli, amount, cooldownMillis,
                childIntervalMillis, passLimit, poolLimit, critChancePermille,
                critMultiplierMilli, luckAffectsCrit)) return false;
        return DSP036ReturningRows.TryGetFlightProfile(systemId,
            launchSpeedUnitsPerSecond, outboundBaseUnits,
            reverseDistanceFactorMilli, totalDistanceFactorMilli,
            lifetimeTics, baseRadiusMilliUnits, pathKind, targetPolicy,
            returnPolicy, wallPolicy, passesPerLeg);
    }

    int DSP036NewEventId()
    {
        dsp036EventOrdinal++;
        return DSP036_EVENT_BASE + dsp036EventOrdinal;
    }

    int DSP036ActiveProjectileCount(int systemId)
    {
        int count = 0;
        for (int i = 0; i < dsp036ProjectileActive.Size(); i++)
            if (dsp036ProjectileActive[i] != 0
                && dsp036ProjectileSystems[i] == systemId) count++;
        return count;
    }

    bool DSP036EquipFixture(int systemId, int rank, int weaponSlot,
        int firstFireTic)
    {
        int damage; int area; int speed; int amount; int cooldown;
        int childInterval; int passLimit; int poolLimit; int critChance;
        int critMultiplier; int luckCrit; int launchSpeed; int outboundBase;
        int reverseFactor; int totalFactor; int lifetime; int radius;
        int path; int target; int returnPolicy; int wall; int passes;
        if (!DSP036LoadRankRow(systemId, rank, damage, area, speed,
                amount, cooldown, childInterval, passLimit, poolLimit,
                critChance, critMultiplier, luckCrit, launchSpeed,
                outboundBase, reverseFactor, totalFactor, lifetime, radius,
                path, target, returnPolicy, wall, passes)
            || weaponSlot < 0 || weaponSlot >= lifeStates.Size()
            || lifeStates[weaponSlot] != STORE_ALIVE || firstFireTic < 0)
            return false;
        for (int i = 0; i < dsp036WeaponSlots.Size(); i++)
            if (dsp036WeaponSlots[i] == weaponSlot) return false;
        dsp036WeaponSystems.Push(systemId);
        dsp036WeaponRanks.Push(rank);
        dsp036WeaponSlots.Push(weaponSlot);
        dsp036WeaponGenerations.Push(generations[weaponSlot]);
        dsp036WeaponIds.Push(ids[weaponSlot]);
        dsp036WeaponNextVolleyMilliTics.Push(firstFireTic * 1000);
        { if (!dsQuiet) Console.Printf("DS_P036_EQUIP accepted=1 system_id=%d rank=%d weapon_slot=%d weapon_generation=%d weapon_id=%d first_fire_tic=%d source=CONTROLLED_MAP16_FIXTURE source_inventory_claim=0", systemId, rank, weaponSlot, generations[weaponSlot], ids[weaponSlot], firstFireTic); }
        return true;
    }

    bool DSP036SetFixtureRank(int weaponSlot, int systemId, int rank,
        int logicalTic)
    {
        int damage; int area; int speed; int amount; int cooldown;
        int childInterval; int passLimit; int poolLimit; int critChance;
        int critMultiplier; int luckCrit; int launchSpeed; int outboundBase;
        int reverseFactor; int totalFactor; int lifetime; int radius;
        int path; int target; int returnPolicy; int wall; int passes;
        if (!DSP036LoadRankRow(systemId, rank, damage, area, speed,
                amount, cooldown, childInterval, passLimit, poolLimit,
                critChance, critMultiplier, luckCrit, launchSpeed,
                outboundBase, reverseFactor, totalFactor, lifetime, radius,
                path, target, returnPolicy, wall, passes)) return false;
        for (int i = 0; i < dsp036WeaponSystems.Size(); i++)
        {
            if (dsp036WeaponSlots[i] != weaponSlot) continue;
            if (!ValidParts(weaponSlot, dsp036WeaponGenerations[i],
                    dsp036WeaponIds[i]) || dsp036WeaponSystems[i] != systemId)
                return false;
            int oldRank = dsp036WeaponRanks[i];
            dsp036WeaponRanks[i] = rank;
            { if (!dsQuiet) Console.Printf("DS_P036_FIXTURE_RANK accepted=1 tic=%d system_id=%d prior_rank=%d rank=%d weapon_id=%d weapon_generation=%d source=CONTROLLED_MAP16_FIXTURE source_inventory_claim=0", logicalTic, systemId, oldRank, rank, dsp036WeaponIds[i], dsp036WeaponGenerations[i]); }
            return true;
        }
        return false;
    }

    void DSP036RetireProjectile(int index, int logicalTic, String reason)
    {
        if (index < 0 || index >= dsp036ProjectileActive.Size()
            || dsp036ProjectileActive[index] == 0) return;
        dsp036ProjectileActive[index] = 0;
        if (dsp036ProjectileProxies[index] != null)
        {
            dsp036ProjectileProxies[index].Destroy();
            dsp036ProjectileProxies[index] = null;
        }
        { if (!dsQuiet) Console.Printf("DS_P036_PROJECTILE_END event_id=%d tic=%d system_id=%d reason=%s outbound_hit_count=%d reverse_hit_count=%d traveled=%.4f", dsp036ProjectileEvents[index], logicalTic, dsp036ProjectileSystems[index], reason, dsp036ProjectileOutboundHitCount[index], dsp036ProjectileReverseHitCount[index], dsp036ProjectileTotalTravelled[index]); }
    }

    void DSP036CancelWeaponSchedule(int weaponIndex, int logicalTic,
        out int canceledVolleys, out int canceledProjectiles)
    {
        canceledVolleys = 0; canceledProjectiles = 0;
        for (int i = 0; i < dsp036VolleyActive.Size(); i++)
        {
            if (dsp036VolleyActive[i] == 0
                || dsp036VolleyWeaponIndexes[i] != weaponIndex) continue;
            dsp036VolleyActive[i] = 0;
            canceledVolleys++;
        }
        for (int i = 0; i < dsp036ProjectileActive.Size(); i++)
        {
            if (dsp036ProjectileActive[i] == 0
                || dsp036ProjectileWeaponSlots[i] != dsp036WeaponSlots[weaponIndex]
                || dsp036ProjectileWeaponGenerations[i]
                    != dsp036WeaponGenerations[weaponIndex]
                || dsp036ProjectileWeaponIds[i] != dsp036WeaponIds[weaponIndex])
                continue;
            DSP036RetireProjectile(i, logicalTic, "FORM_REPLACED");
            canceledProjectiles++;
        }
    }

    bool DSP036ReplaceFixture(int weaponSlot, int evolvedSystemId,
        int evolvedRank, int logicalTic, bool dependencySatisfied,
        int dependencyRank)
    {
        int sourceIndex = -1;
        for (int find = 0; find < dsp036WeaponSystems.Size(); find++)
            if (dsp036WeaponSlots[find] == weaponSlot)
            { sourceIndex = find; break; }
        if (sourceIndex < 0) return false;
        int sourceSystem = dsp036WeaponSystems[sourceIndex];
        int evolvedFromSource; int sourceRank; int dependencyKind;
        int dependencyMinRank;
        if (!DSP036ReturningRows.TryGetEvolution(sourceSystem,
                evolvedFromSource, sourceRank, dependencyKind,
                dependencyMinRank)
            || evolvedFromSource != evolvedSystemId || !dependencySatisfied
            || dependencyRank < dependencyMinRank) return false;
        int damage; int area; int speed; int amount; int cooldown;
        int childInterval; int passLimit; int poolLimit; int critChance;
        int critMultiplier; int luckCrit; int launchSpeed; int outboundBase;
        int reverseFactor; int totalFactor; int lifetime; int radius;
        int path; int target; int returnPolicy; int wall; int passes;
        if (!DSP036LoadRankRow(evolvedSystemId, evolvedRank, damage, area,
                speed, amount, cooldown, childInterval, passLimit, poolLimit,
                critChance, critMultiplier, luckCrit, launchSpeed,
                outboundBase, reverseFactor, totalFactor, lifetime, radius,
                path, target, returnPolicy, wall, passes)) return false;
        for (int i = 0; i < dsp036WeaponSystems.Size(); i++)
        {
            if (dsp036WeaponSlots[i] != weaponSlot) continue;
            if (!ValidParts(weaponSlot, dsp036WeaponGenerations[i],
                    dsp036WeaponIds[i])
                || dsp036WeaponSystems[i] != sourceSystem
                || dsp036WeaponRanks[i] < sourceRank) return false;
            int oldSystem = dsp036WeaponSystems[i];
            int oldRank = dsp036WeaponRanks[i];
            int canceledVolleys; int canceledProjectiles;
            DSP036CancelWeaponSchedule(i, logicalTic, canceledVolleys,
                canceledProjectiles);
            dsp036WeaponSystems[i] = evolvedSystemId;
            dsp036WeaponRanks[i] = evolvedRank;
            dsp036WeaponNextVolleyMilliTics[i] = logicalTic * 1000;
            { if (!dsQuiet) Console.Printf("DS_P036_FORM_REPLACE accepted=1 tic=%d source_system_id=%d source_rank=%d evolved_system_id=%d evolved_rank=%d weapon_id=%d weapon_generation=%d dependency_kind=%d dependency_min_rank=%d dependency_rank=%d canceled_volleys=%d canceled_projectiles=%d source=CONTROLLED_MAP16_FIXTURE", logicalTic, oldSystem, oldRank, evolvedSystemId, evolvedRank, dsp036WeaponIds[i], dsp036WeaponGenerations[i], dependencyKind, dependencyMinRank, dependencyRank, canceledVolleys, canceledProjectiles); }
            return true;
        }
        return false;
    }

    bool DSP036StartVolley(int weaponIndex, int logicalTic,
        int ownerSlot, int ownerGeneration, int ownerId,
        double ownerX, double ownerY, int cooldownMultiplierMilli,
        int rankHash)
    {
        int systemId = dsp036WeaponSystems[weaponIndex];
        int rank = dsp036WeaponRanks[weaponIndex];
        int damage; int area; int speed; int amount; int cooldown;
        int childInterval; int passLimit; int poolLimit; int critChance;
        int critMultiplier; int luckCrit; int launchSpeed; int outboundBase;
        int reverseFactor; int totalFactor; int lifetime; int radius;
        int path; int targetPolicy; int returnPolicy; int wall; int passes;
        if (!ValidParts(dsp036WeaponSlots[weaponIndex],
                dsp036WeaponGenerations[weaponIndex], dsp036WeaponIds[weaponIndex])
            || !DSP036LoadRankRow(systemId, rank, damage, area, speed,
                amount, cooldown, childInterval, passLimit, poolLimit,
                critChance, critMultiplier, luckCrit, launchSpeed,
                outboundBase, reverseFactor, totalFactor, lifetime, radius,
                path, targetPolicy, returnPolicy, wall, passes)) return false;
        if (rsActive)
        {
            area = area * RsAreaFor(systemId) / 1000;
            speed = speed * RsSpeedFor(systemId) / 1000;
            amount += RsAmountFor(systemId); poolLimit += RsAmountFor(systemId);
        }
        int adjustedCooldown = DSP033StatRules.CooldownAfterTome(systemId,
            cooldown, cooldownMultiplierMilli);
        int targetSlot; int targetGeneration; int targetId;
        double targetDistanceSquared;
        bool hasTarget = DSP036ChooseClosestTarget(DSP036_TARGET_ENEMY,
            ownerX, ownerY, 320.0, targetSlot, targetGeneration, targetId,
            targetDistanceSquared);
        int volleyId = DSP036_EVENT_BASE + 100000 + ++dsp036VolleyOrdinal;
        dsp036WeaponNextVolleyMilliTics[weaponIndex] = logicalTic * 1000
            + adjustedCooldown * Thinker.TICRATE;
        if (!hasTarget)
        {
            Console.Printf("DS_P036_VOLLEY_SKIP event_id=%d tic=%d system_id=%d rank=%d reason=NO_LIVE_TARGET rng_draws=0 cooldown_ms=%d", volleyId, logicalTic, systemId, rank, adjustedCooldown);
            return true;
        }
        int volleyIndex = -1;
        for (int i = 0; i < dsp036VolleyActive.Size(); i++)
            if (dsp036VolleyActive[i] == 0) { volleyIndex = i; break; }
        if (volleyIndex < 0)
        {
            if (dsp036VolleyActive.Size() >= DSP036_MAX_ACTIVE_VOLLEYS)
                return false;
            volleyIndex = dsp036VolleyActive.Size();
            dsp036VolleyActive.Push(0); dsp036VolleyWeaponIndexes.Push(0);
            dsp036VolleyIds.Push(0); dsp036VolleyNextChildMilliTics.Push(0);
            dsp036VolleyRemainingChildren.Push(0); dsp036VolleyChildOrdinals.Push(0);
            dsp036VolleyTargetFound.Push(0); dsp036VolleyTargetSlots.Push(-1);
            dsp036VolleyTargetGenerations.Push(0); dsp036VolleyTargetIds.Push(0);
            dsp036VolleyAimYawMilli.Push(0); dsp036VolleyRankHash.Push(0);
            dsp036VolleyMightMilli.Push(1000); dsp036VolleyCooldownMilli.Push(1000);
            dsp036VolleyCritChancePermille.Push(0);
            dsp036VolleyCritMultiplierMilli.Push(1000);
            dsp036VolleyLuckAffectsCrit.Push(0); dsp036VolleyDamageTenths.Push(0);
            dsp036VolleyAreaMilli.Push(1000); dsp036VolleySpeedMilli.Push(1000);
            dsp036VolleyChildIntervalMillis.Push(0); dsp036VolleyPierceLimit.Push(1);
            dsp036VolleyPoolLimit.Push(1); dsp036VolleyLaunchSpeed.Push(0);
            dsp036VolleyOutboundBase.Push(0); dsp036VolleyReverseFactorMilli.Push(0);
            dsp036VolleyTotalFactorMilli.Push(0); dsp036VolleyLifetimeTics.Push(0);
            dsp036VolleyBaseRadiusMilli.Push(0); dsp036VolleyPathKind.Push(0);
            dsp036VolleyTargetPolicy.Push(0); dsp036VolleyReturnPolicy.Push(0);
            dsp036VolleyWallPolicy.Push(0); dsp036VolleyPassesPerLeg.Push(0);
        }
        int mightMilli = dsp033ResolvedValid
            && DSP033StatRules.StatApplies(DSP033StatRules.STAT_MIGHT, systemId)
            ? DSP033Resolved(DSP033StatRules.STAT_MIGHT) : 1000;
        if (rsActive) mightMilli = RsMightFor(systemId);
        int aimYaw = DSP036YawToPoint(ownerX, ownerY,
            x[targetSlot], y[targetSlot]);
        if (x[targetSlot] == ownerX && y[targetSlot] == ownerY)
            aimYaw = 0;
        dsp036VolleyActive[volleyIndex] = 1;
        dsp036VolleyWeaponIndexes[volleyIndex] = weaponIndex;
        dsp036VolleyIds[volleyIndex] = volleyId;
        dsp036VolleyNextChildMilliTics[volleyIndex] = logicalTic * 1000;
        dsp036VolleyRemainingChildren[volleyIndex] = amount;
        dsp036VolleyChildOrdinals[volleyIndex] = 0;
        dsp036VolleyTargetFound[volleyIndex] = 1;
        dsp036VolleyTargetSlots[volleyIndex] = targetSlot;
        dsp036VolleyTargetGenerations[volleyIndex] = targetGeneration;
        dsp036VolleyTargetIds[volleyIndex] = targetId;
        dsp036VolleyAimYawMilli[volleyIndex] = aimYaw;
        dsp036VolleyRankHash[volleyIndex] = rankHash;
        dsp036VolleyMightMilli[volleyIndex] = mightMilli;
        dsp036VolleyCooldownMilli[volleyIndex] = adjustedCooldown;
        dsp036VolleyCritChancePermille[volleyIndex] = critChance;
        dsp036VolleyCritMultiplierMilli[volleyIndex] = critMultiplier;
        dsp036VolleyLuckAffectsCrit[volleyIndex] = luckCrit;
        dsp036VolleyDamageTenths[volleyIndex] = damage;
        dsp036VolleyAreaMilli[volleyIndex] = area;
        dsp036VolleySpeedMilli[volleyIndex] = speed;
        dsp036VolleyChildIntervalMillis[volleyIndex] = childInterval;
        dsp036VolleyPierceLimit[volleyIndex] = passLimit;
        dsp036VolleyPoolLimit[volleyIndex] = poolLimit;
        dsp036VolleyLaunchSpeed[volleyIndex] = launchSpeed;
        dsp036VolleyOutboundBase[volleyIndex] = outboundBase;
        dsp036VolleyReverseFactorMilli[volleyIndex] = reverseFactor;
        dsp036VolleyTotalFactorMilli[volleyIndex] = totalFactor;
        dsp036VolleyLifetimeTics[volleyIndex] = lifetime;
        dsp036VolleyBaseRadiusMilli[volleyIndex] = radius;
        dsp036VolleyPathKind[volleyIndex] = path;
        dsp036VolleyTargetPolicy[volleyIndex] = targetPolicy;
        dsp036VolleyReturnPolicy[volleyIndex] = returnPolicy;
        dsp036VolleyWallPolicy[volleyIndex] = wall;
        dsp036VolleyPassesPerLeg[volleyIndex] = passes;
        DSSound.Weapon(systemId);
        { if (!dsQuiet) Console.Printf("DS_P036_VOLLEY event_id=%d tic=%d system_id=%d rank=%d weapon_id=%d weapon_generation=%d target_found=1 target_slot=%d target_generation=%d target_id=%d target_distance_sq=%.4f aim_yaw_milli=%d damage_tenths=%d amount=%d cooldown_ms=%d child_interval_ms=%d speed_milli=%d launch_speed=%d actual_speed=%d outbound_distance=%d reverse_distance=%d range_budget=%d lifetime_tics=%d radius_milli=%d area_milli=%d pass_limit=%d pool_limit=%d crit_chance_permille=%d crit_multiplier_milli=%d luck_eligibility=%d rank_hash=%d target_selection=ONCE_PER_VOLLEY native_motion=VISUAL_ONLY", volleyId, logicalTic, systemId, rank, dsp036WeaponIds[weaponIndex], dsp036WeaponGenerations[weaponIndex], targetSlot, targetGeneration, targetId, targetDistanceSquared, aimYaw, damage, amount, adjustedCooldown, childInterval, speed, launchSpeed, launchSpeed * speed / 1000, outboundBase * speed / 1000, outboundBase * speed / 1000 * reverseFactor / 1000, outboundBase * speed / 1000 * totalFactor / 1000, lifetime, radius * area / 1000, area, passLimit, poolLimit, critChance, critMultiplier, luckCrit, rankHash); }
        return true;
    }

    bool DSP036SpawnChild(int volleyIndex, int logicalTic,
        int ownerSlot, int ownerGeneration, int ownerId,
        double ownerX, double ownerY)
    {
        int weaponIndex = dsp036VolleyWeaponIndexes[volleyIndex];
        int systemId = dsp036WeaponSystems[weaponIndex];
        int rank = dsp036WeaponRanks[weaponIndex];
        int ordinal = dsp036VolleyChildOrdinals[volleyIndex];
        if (!ValidParts(ownerSlot, ownerGeneration, ownerId)
            || !ValidParts(dsp036WeaponSlots[weaponIndex],
                dsp036WeaponGenerations[weaponIndex], dsp036WeaponIds[weaponIndex]))
        {
            dsp036SkippedChildren++;
            Console.Printf("DS_P036_CHILD_SKIP tic=%d system_id=%d volley_id=%d child_ordinal=%d reason=STALE_OWNER_OR_WEAPON", logicalTic, systemId, dsp036VolleyIds[volleyIndex], ordinal);
            return false;
        }
        if (DSP036ActiveProjectileCount(systemId)
                >= dsp036VolleyPoolLimit[volleyIndex])
        {
            dsp036SkippedChildren++;
            Console.Printf("DS_P036_CHILD_SKIP tic=%d system_id=%d volley_id=%d child_ordinal=%d reason=PROJECTILE_POOL_FULL", logicalTic, systemId, dsp036VolleyIds[volleyIndex], ordinal);
            return false;
        }
        int baseRadius = dsp036VolleyBaseRadiusMilli[volleyIndex];
        int areaMilli = dsp036VolleyAreaMilli[volleyIndex];
        if (baseRadius <= 0 || areaMilli <= 0
            || baseRadius > 2147483647 / areaMilli)
        {
            dsp036SkippedChildren++;
            Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P036_RADIUS_AREA_OVERFLOW tic=%d system_id=%d radius=%d area=%d", logicalTic, systemId, baseRadius, areaMilli);
            return false;
        }
        int effectiveRadius = baseRadius * areaMilli / 1000;
        int speed = dsp036VolleyLaunchSpeed[volleyIndex]
            * dsp036VolleySpeedMilli[volleyIndex] / 1000;
        int outbound = dsp036VolleyOutboundBase[volleyIndex]
            * dsp036VolleySpeedMilli[volleyIndex] / 1000;
        int reverse = outbound * dsp036VolleyReverseFactorMilli[volleyIndex] / 1000;
        int total = outbound * dsp036VolleyTotalFactorMilli[volleyIndex] / 1000;
        if (effectiveRadius <= 0 || speed <= 0 || outbound <= 0
            || reverse <= 0 || total <= 0)
        {
            dsp036SkippedChildren++;
            Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P036_INVALID_FLIGHT tic=%d system_id=%d radius=%d speed=%d outbound=%d reverse=%d total=%d", logicalTic, systemId, effectiveRadius, speed, outbound, reverse, total);
            return false;
        }
        double dx; double dy;
        DSP036YawDirection(dsp036VolleyAimYawMilli[volleyIndex], dx, dy);
        int eventId = DSP036NewEventId();
        DSP025AttackSnapshot snapshot;
        DSP025PopulateSnapshot(snapshot, eventId,
            dsp036VolleyIds[volleyIndex], ownerSlot, ownerGeneration, ownerId,
            dsp036WeaponIds[weaponIndex], dsp036WeaponGenerations[weaponIndex],
            dsp036VolleyDamageTenths[volleyIndex], 0,
            dsp036VolleyMightMilli[volleyIndex],
            dsp036VolleyPierceLimit[volleyIndex], 1,
            logicalTic + dsp036VolleyLifetimeTics[volleyIndex], 0, 0,
            dsp036VolleyAimYawMilli[volleyIndex], dsp036CritRng, dsp036CritRng);
        snapshot.explicitTargetSlot = dsp036VolleyTargetSlots[volleyIndex];
        snapshot.explicitTargetGeneration = dsp036VolleyTargetGenerations[volleyIndex];
        snapshot.explicitTargetStableId = dsp036VolleyTargetIds[volleyIndex];
        int i = dsp036ProjectileActive.Size();
        dsp036ProjectileActive.Push(1); dsp036ProjectileEvents.Push(eventId);
        dsp036ProjectileParents.Push(snapshot.parentEventId);
        dsp036ProjectileSystems.Push(systemId); dsp036ProjectileRanks.Push(rank);
        dsp036ProjectileChildOrdinals.Push(ordinal);
        dsp036ProjectileWeaponSlots.Push(dsp036WeaponSlots[weaponIndex]);
        dsp036ProjectileWeaponGenerations.Push(dsp036WeaponGenerations[weaponIndex]);
        dsp036ProjectileWeaponIds.Push(dsp036WeaponIds[weaponIndex]);
        dsp036ProjectileOwnerSlots.Push(ownerSlot);
        dsp036ProjectileOwnerGenerations.Push(ownerGeneration);
        dsp036ProjectileOwnerIds.Push(ownerId);
        dsp036ProjectileTargetSlots.Push(dsp036VolleyTargetSlots[volleyIndex]);
        dsp036ProjectileTargetGenerations.Push(dsp036VolleyTargetGenerations[volleyIndex]);
        dsp036ProjectileTargetIds.Push(dsp036VolleyTargetIds[volleyIndex]);
        dsp036ProjectileAimYawMilli.Push(dsp036VolleyAimYawMilli[volleyIndex]);
        dsp036ProjectilePhase.Push(DSP036_PHASE_OUTBOUND);
        dsp036ProjectilePassesCompleted.Push(0);
        dsp036ProjectileAgeTics.Push(0);
        dsp036ProjectileLifetimeTics.Push(dsp036VolleyLifetimeTics[volleyIndex]);
        dsp036ProjectileDamageTenths.Push(snapshot.damageBase);
        dsp036ProjectileMightMilli.Push(snapshot.multiplierMilli);
        dsp036ProjectileCritChancePermille.Push(dsp036VolleyCritChancePermille[volleyIndex]);
        dsp036ProjectileCritMultiplierMilli.Push(dsp036VolleyCritMultiplierMilli[volleyIndex]);
        dsp036ProjectileLuckAffectsCrit.Push(dsp036VolleyLuckAffectsCrit[volleyIndex]);
        dsp036ProjectilePierceLimit.Push(dsp036VolleyPierceLimit[volleyIndex]);
        dsp036ProjectileOutboundHitCount.Push(0); dsp036ProjectileReverseHitCount.Push(0);
        dsp036ProjectileSpeedUnitsPerSecond.Push(speed);
        dsp036ProjectileOutboundDistance.Push(outbound);
        dsp036ProjectileReverseDistance.Push(reverse);
        dsp036ProjectileRangeBudget.Push(total);
        dsp036ProjectileRadiusMilli.Push(effectiveRadius);
        dsp036ProjectilePathKind.Push(dsp036VolleyPathKind[volleyIndex]);
        dsp036ProjectileReturnPolicy.Push(dsp036VolleyReturnPolicy[volleyIndex]);
        dsp036ProjectileWallPolicy.Push(dsp036VolleyWallPolicy[volleyIndex]);
        dsp036ProjectileRankHash.Push(dsp036VolleyRankHash[volleyIndex]);
        dsp036ProjectileOriginX.Push(ownerX); dsp036ProjectileOriginY.Push(ownerY);
        dsp036ProjectileX.Push(ownerX); dsp036ProjectileY.Push(ownerY);
        dsp036ProjectileDirectionX.Push(dx); dsp036ProjectileDirectionY.Push(dy);
        dsp036ProjectileOutboundTravelled.Push(0.0);
        dsp036ProjectileReverseTravelled.Push(0.0);
        dsp036ProjectileTotalTravelled.Push(0.0);
        DSP036ReturningProxy proxy = DSP036ReturningProxy(Actor.Spawn(
            "DSP036ReturningProxy", (ownerX, ownerY, DSProjectileProxyBase.VISUAL_Z), NO_REPLACE));
        if (proxy != null)
        {
            proxy.logicalEventId = eventId;
            proxy.logicalSystemId = systemId;
        }
        dsp036ProjectileProxies.Push(proxy);
        dsp036ProjectileOrdinal++;
        { if (!dsQuiet) Console.Printf("DS_P036_PROJECTILE event_id=%d parent_event_id=%d tic=%d system_id=%d rank=%d child_ordinal=%d owner_id=%d weapon_id=%d weapon_generation=%d target_id=%d aim_yaw_milli=%d origin_x=%.4f origin_y=%.4f direction_x=%.8f direction_y=%.8f speed=%d outbound_distance=%d reverse_distance=%d range_budget=%d lifetime_tics=%d radius_milli=%d damage_tenths=%d might_milli=%d crit_chance_permille=%d crit_multiplier_milli=%d luck_eligibility=%d rank_hash=%d target_snapshot=1 no_homing=1 camera_input=0 native_motion=VISUAL_ONLY", eventId, snapshot.parentEventId, logicalTic, systemId, rank, ordinal, ownerId, dsp036WeaponIds[weaponIndex], dsp036WeaponGenerations[weaponIndex], dsp036VolleyTargetIds[volleyIndex], dsp036VolleyAimYawMilli[volleyIndex], ownerX, ownerY, dx, dy, speed, outbound, reverse, total, dsp036ProjectileLifetimeTics[i], effectiveRadius, snapshot.damageBase, snapshot.multiplierMilli, dsp036ProjectileCritChancePermille[i], dsp036ProjectileCritMultiplierMilli[i], dsp036ProjectileLuckAffectsCrit[i], dsp036ProjectileRankHash[i]); }
        return true;
    }

    bool DSP036LineCircleEntry(double startX, double startY,
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

    bool DSP036CollisionPrecedes(int left, int right)
    {
        if (dsp036CollisionFractions[left] != dsp036CollisionFractions[right])
            return dsp036CollisionFractions[left] < dsp036CollisionFractions[right];
        if (dsp036CollisionIds[left] != dsp036CollisionIds[right])
            return dsp036CollisionIds[left] < dsp036CollisionIds[right];
        if (dsp036CollisionGenerations[left] != dsp036CollisionGenerations[right])
            return dsp036CollisionGenerations[left] < dsp036CollisionGenerations[right];
        return dsp036CollisionSlots[left] < dsp036CollisionSlots[right];
    }

    void DSP036SwapCollisions(int left, int right)
    {
        double fraction = dsp036CollisionFractions[left];
        dsp036CollisionFractions[left] = dsp036CollisionFractions[right];
        dsp036CollisionFractions[right] = fraction;
        int value = dsp036CollisionSlots[left];
        dsp036CollisionSlots[left] = dsp036CollisionSlots[right];
        dsp036CollisionSlots[right] = value;
        value = dsp036CollisionGenerations[left];
        dsp036CollisionGenerations[left] = dsp036CollisionGenerations[right];
        dsp036CollisionGenerations[right] = value;
        value = dsp036CollisionIds[left];
        dsp036CollisionIds[left] = dsp036CollisionIds[right];
        dsp036CollisionIds[right] = value;
    }

    void DSP036ProcessSegment(int projectileIndex, int logicalTic,
        int pass, double startX, double startY, double endX, double endY)
    {
        dsp036CollisionFractions.Clear(); dsp036CollisionSlots.Clear();
        dsp036CollisionGenerations.Clear(); dsp036CollisionIds.Clear();
        double projectileRadius = double(dsp036ProjectileRadiusMilli[projectileIndex]) / 1000.0;
        DSP024SweptCandidates(startX, startY, endX, endY,
            projectileRadius + 32.0);
        for (int c = 0; c < spatialCandidateCount; c++)
        {
            int slot = spatialCandidateSlots[c];
            int generation = spatialCandidateGenerations[c];
            int stableId = spatialCandidateIds[c];
            if (!ValidParts(slot, generation, stableId)
                || kinds[slot] != DSP036_TARGET_ENEMY || health[slot] <= 0
                || DSP036HasHitOnPass(dsp036ProjectileEvents[projectileIndex],
                    pass, slot, generation, stableId)) continue;
            double fraction;
            double targetRadius = collisionRadii[slot] + projectileRadius;
            if (!DSP036LineCircleEntry(startX, startY, endX, endY,
                    x[slot], y[slot], targetRadius, fraction)) continue;
            dsp036CollisionFractions.Push(fraction);
            dsp036CollisionSlots.Push(slot);
            dsp036CollisionGenerations.Push(generation);
            dsp036CollisionIds.Push(stableId);
        }
        for (int i = 1; i < dsp036CollisionFractions.Size(); i++)
        {
            int j = i;
            while (j > 0 && DSP036CollisionPrecedes(j, j - 1))
            { DSP036SwapCollisions(j, j - 1); j--; }
        }
        for (int i = 0; i < dsp036CollisionFractions.Size(); i++)
        {
            int acceptedOnLeg = pass == 1
                ? dsp036ProjectileOutboundHitCount[projectileIndex]
                : dsp036ProjectileReverseHitCount[projectileIndex];
            if (acceptedOnLeg >= dsp036ProjectilePierceLimit[projectileIndex])
                break;
            int slot = dsp036CollisionSlots[i];
            int generation = dsp036CollisionGenerations[i];
            int stableId = dsp036CollisionIds[i];
            if (!ValidParts(slot, generation, stableId) || health[slot] <= 0
                || DSP036HasHitOnPass(dsp036ProjectileEvents[projectileIndex],
                    pass, slot, generation, stableId)) continue;
            int sourceDamageTenths = dsp036ProjectileDamageTenths[projectileIndex];
            bool critical = false;
            int rngBefore = dsp036CritRng;
            int rngAfter = rngBefore;
            if (dsp036ProjectileCritChancePermille[projectileIndex] > 0)
            {
                rngAfter = DSP025NextAttackRng(rngBefore);
                int roll = (rngAfter & 0x7fffffff) % 1000;
                dsp036CritRng = rngAfter;
                critical = roll < dsp036ProjectileCritChancePermille[projectileIndex];
                if (critical)
                {
                    int multiplier = dsp036ProjectileCritMultiplierMilli[projectileIndex];
                    if (sourceDamageTenths > 2000000000 / multiplier)
                    {
                        Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P036_CRIT_OVERFLOW tic=%d event_id=%d damage_tenths=%d multiplier=%d", logicalTic, dsp036ProjectileEvents[projectileIndex], sourceDamageTenths, multiplier);
                        continue;
                    }
                    sourceDamageTenths = sourceDamageTenths * multiplier / 1000;
                }
            }
            int scaledTenths = 0;
            bool checkedDamage = DSP025CheckedDamage(sourceDamageTenths, 0,
                dsp036ProjectileMightMilli[projectileIndex], scaledTenths)
                && scaledTenths >= 0 && scaledTenths <= 20000000;
            int damageMilli = checkedDamage ? scaledTenths * 100 : 0;
            int before; int after; int killed;
            arHitSystem = dsp036ProjectileSystems[projectileIndex];   // which weapon hit (Arcana scope)
            bool applied = checkedDamage && DSP025ApplyLogicalHit(slot,
                generation, stableId, damageMilli, before, after, killed);
            if (!applied)
            {
                dsp036RejectedHits++;
                { if (!dsQuiet) Console.Printf("DS_P036_HIT event_id=%d tic=%d system_id=%d leg=%d target_id=%d accepted=0 reason=STALE_OR_INVALID_DAMAGE", dsp036ProjectileEvents[projectileIndex], logicalTic, dsp036ProjectileSystems[projectileIndex], pass, stableId); }
                continue;
            }
            DSP036RecordHitOnPass(dsp036ProjectileEvents[projectileIndex],
                pass, slot, generation, stableId);
            if (pass == 1) dsp036ProjectileOutboundHitCount[projectileIndex]++;
            else dsp036ProjectileReverseHitCount[projectileIndex]++;
            dsp036AcceptedHits++;
            int acceptedDamage = before - after;
            if (acceptedDamage < 0 || dsp036AcceptedDamageMilli
                    > 2147483647 - acceptedDamage)
                Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P036_ACCEPTED_DAMAGE_OVERFLOW tic=%d total=%d delta=%d", logicalTic, dsp036AcceptedDamageMilli, acceptedDamage);
            else dsp036AcceptedDamageMilli += acceptedDamage;
            { if (!dsQuiet) Console.Printf("DS_P036_HIT event_id=%d parent_event_id=%d tic=%d system_id=%d rank=%d child_ordinal=%d leg=%d target_slot=%d target_generation=%d target_id=%d fraction=%.6f damage_tenths=%d might_milli=%d damage_milli=%d before=%d after=%d critical=%d crit_roll_rng_before=%d crit_roll_rng_after=%d crit_chance_permille=%d crit_multiplier_milli=%d luck_eligibility=%d accepted=1 authority=P025_CHECKED_LOGICAL_HIT rank_hash=%d", dsp036ProjectileEvents[projectileIndex], dsp036ProjectileParents[projectileIndex], logicalTic, dsp036ProjectileSystems[projectileIndex], dsp036ProjectileRanks[projectileIndex], dsp036ProjectileChildOrdinals[projectileIndex], pass, slot, generation, stableId, dsp036CollisionFractions[i], sourceDamageTenths, dsp036ProjectileMightMilli[projectileIndex], damageMilli, before, after, critical ? 1 : 0, rngBefore, rngAfter, dsp036ProjectileCritChancePermille[projectileIndex], dsp036ProjectileCritMultiplierMilli[projectileIndex], dsp036ProjectileLuckAffectsCrit[projectileIndex], dsp036ProjectileRankHash[projectileIndex]); }
            if (killed != 0) HandleEnemyDeath(slot, before,
                dsp036ProjectileEvents[projectileIndex]);
            if (critical && rsActive && DSP030VerticalSlice(self) != null)
            {
                DSP030VerticalSlice(self).FxCount("crit");
                DSP030VerticalSlice(self).OnCrit(x[slot], y[slot], dsp036ProjectileSystems[projectileIndex]);
            }
        }
    }

    void DSP036ProcessProjectile(int index, int logicalTic)
    {
        if (dsp036ProjectileActive[index] == 0) return;
        if (!ValidParts(dsp036ProjectileOwnerSlots[index],
                dsp036ProjectileOwnerGenerations[index],
                dsp036ProjectileOwnerIds[index]))
        { DSP036RetireProjectile(index, logicalTic, "OWNER_GENERATION_REPLACED"); return; }
        if (!ValidParts(dsp036ProjectileWeaponSlots[index],
                dsp036ProjectileWeaponGenerations[index],
                dsp036ProjectileWeaponIds[index]))
        { DSP036RetireProjectile(index, logicalTic, "WEAPON_GENERATION_REPLACED"); return; }
        if (dsp036ProjectileAgeTics[index] >= dsp036ProjectileLifetimeTics[index])
        { DSP036RetireProjectile(index, logicalTic, "LIFETIME_EXPIRED"); return; }
        double speedStep = double(dsp036ProjectileSpeedUnitsPerSecond[index])
            / double(Thinker.TICRATE);
        double remaining = double(dsp036ProjectileRangeBudget[index])
            - dsp036ProjectileTotalTravelled[index];
        if (remaining <= 0.000001)
        { DSP036RetireProjectile(index, logicalTic, "RANGE_EXPIRED"); return; }
        if (speedStep > remaining) speedStep = remaining;
        double px = dsp036ProjectileX[index];
        double py = dsp036ProjectileY[index];
        double dirX = dsp036ProjectileDirectionX[index];
        double dirY = dsp036ProjectileDirectionY[index];
        double travelledThisTic = 0.0;
        int segmentCount = 0;
        while (travelledThisTic < speedStep - 0.000001 && segmentCount < 2)
        {
            segmentCount++;
            int pass = dsp036ProjectilePhase[index] == DSP036_PHASE_OUTBOUND ? 1 : 2;
            double available = speedStep - travelledThisTic;
            double legRemaining;
            double stepX; double stepY;
            if (pass == 1)
            {
                legRemaining = double(dsp036ProjectileOutboundDistance[index])
                    - dsp036ProjectileOutboundTravelled[index];
                if (legRemaining < 0.0) legRemaining = 0.0;
                double amount = available < legRemaining ? available : legRemaining;
                stepX = dirX * amount; stepY = dirY * amount;
                double nextX = px + stepX; double nextY = py + stepY;
                DSP036ProcessSegment(index, logicalTic, 1, px, py, nextX, nextY);
                px = nextX; py = nextY;
                dsp036ProjectileOutboundTravelled[index] += amount;
                dsp036ProjectileTotalTravelled[index] += amount;
                travelledThisTic += amount;
                { if (!dsQuiet) Console.Printf("DS_P036_PATH_STEP event_id=%d tic=%d system_id=%d age_tic=%d leg=OUTBOUND start_x=%.5f start_y=%.5f end_x=%.5f end_y=%.5f step=%.5f traveled_outbound=%.5f traveled_total=%.5f", dsp036ProjectileEvents[index], logicalTic, dsp036ProjectileSystems[index], dsp036ProjectileAgeTics[index], px - stepX, py - stepY, px, py, amount, dsp036ProjectileOutboundTravelled[index], dsp036ProjectileTotalTravelled[index]); }
                if (dsp036ProjectileOutboundTravelled[index]
                        >= double(dsp036ProjectileOutboundDistance[index]) - 0.000001)
                {
                    dsp036ProjectilePhase[index] = DSP036_PHASE_REVERSE;
                    { if (!dsQuiet) Console.Printf("DS_P036_TURN event_id=%d tic=%d system_id=%d leg=OUTBOUND_TO_REVERSE turn_x=%.5f turn_y=%.5f heading_yaw_milli=%d split_tic=1", dsp036ProjectileEvents[index], logicalTic, dsp036ProjectileSystems[index], px, py, dsp036ProjectileAimYawMilli[index]); }
                }
                if (amount <= 0.000001) break;
            }
            else
            {
                legRemaining = double(dsp036ProjectileReverseDistance[index])
                    - dsp036ProjectileReverseTravelled[index];
                if (legRemaining < 0.0) legRemaining = 0.0;
                double amount = available < legRemaining ? available : legRemaining;
                stepX = -dirX * amount; stepY = -dirY * amount;
                double nextX = px + stepX; double nextY = py + stepY;
                DSP036ProcessSegment(index, logicalTic, 2, px, py, nextX, nextY);
                px = nextX; py = nextY;
                dsp036ProjectileReverseTravelled[index] += amount;
                dsp036ProjectileTotalTravelled[index] += amount;
                travelledThisTic += amount;
                { if (!dsQuiet) Console.Printf("DS_P036_PATH_STEP event_id=%d tic=%d system_id=%d age_tic=%d leg=REVERSE start_x=%.5f start_y=%.5f end_x=%.5f end_y=%.5f step=%.5f traveled_reverse=%.5f traveled_total=%.5f", dsp036ProjectileEvents[index], logicalTic, dsp036ProjectileSystems[index], dsp036ProjectileAgeTics[index], px - stepX, py - stepY, px, py, amount, dsp036ProjectileReverseTravelled[index], dsp036ProjectileTotalTravelled[index]); }
            }
            if (dsp036ProjectileTotalTravelled[index]
                    >= double(dsp036ProjectileRangeBudget[index]) - 0.000001)
                break;
        }
        dsp036ProjectileX[index] = px; dsp036ProjectileY[index] = py;
        dsp036ProjectileAgeTics[index]++;
        if (dsp036ProjectileProxies[index] != null)
            dsp036ProjectileProxies[index].SetOrigin((px, py, DSProjectileProxyBase.VISUAL_Z), true);
        if (dsp036ProjectileTotalTravelled[index]
                >= double(dsp036ProjectileRangeBudget[index]) - 0.000001)
            DSP036RetireProjectile(index, logicalTic, "RANGE_EXPIRED");
        else if (dsp036ProjectileAgeTics[index]
                >= dsp036ProjectileLifetimeTics[index])
            DSP036RetireProjectile(index, logicalTic, "LIFETIME_EXPIRED");
    }

    void DSP036ProcessReturningTic(int logicalTic, int ownerSlot,
        int ownerGeneration, int ownerId, double ownerX, double ownerY,
        int cooldownMultiplierMilli, int rankHash)
    {
        for (int i = 0; i < dsp036ProjectileActive.Size(); i++)
            DSP036ProcessProjectile(i, logicalTic);

        for (int weapon = 0; weapon < dsp036WeaponSystems.Size(); weapon++)
        {
            if (logicalTic * 1000 >= dsp036WeaponNextVolleyMilliTics[weapon])
            {
                bool started = DSP036StartVolley(weapon, logicalTic,
                    ownerSlot, ownerGeneration, ownerId, ownerX, ownerY,
                    cooldownMultiplierMilli, rankHash);
                if (!started)
                    dsp036WeaponNextVolleyMilliTics[weapon] = logicalTic * 1000
                        + 1000 * Thinker.TICRATE;
            }
        }

        int drainIterations = 0;
        while (true)
        {
            if (++drainIterations > DSP036_MAX_VOLLEY_DRAIN_ITERATIONS_PER_TIC)
            {
                Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P036_VOLLEY_DRAIN_RUNAWAY tic=%d iterations=%d classification=N2_DISPATCHER", logicalTic, drainIterations);
                for (int i = 0; i < dsp036VolleyActive.Size(); i++)
                    dsp036VolleyActive[i] = 0;
                break;
            }
            int best = -1; int bestStable = 2147483647;
            int bestVolley = 2147483647;
            for (int i = 0; i < dsp036VolleyActive.Size(); i++)
            {
                if (dsp036VolleyActive[i] == 0
                    || dsp036VolleyRemainingChildren[i] <= 0
                    || logicalTic * 1000 < dsp036VolleyNextChildMilliTics[i]) continue;
                int weapon = dsp036VolleyWeaponIndexes[i];
                int stable = dsp036WeaponIds[weapon];
                if (stable < bestStable || (stable == bestStable
                        && dsp036VolleyIds[i] < bestVolley))
                { best = i; bestStable = stable; bestVolley = dsp036VolleyIds[i]; }
            }
            if (best < 0) break;
            int weaponIndex = dsp036VolleyWeaponIndexes[best];
            DSP036SpawnChild(best, logicalTic, ownerSlot, ownerGeneration,
                ownerId, ownerX, ownerY);
            dsp036VolleyRemainingChildren[best]--;
            dsp036VolleyChildOrdinals[best]++;
            dsp036VolleyNextChildMilliTics[best] +=
                dsp036VolleyChildIntervalMillis[best] * Thinker.TICRATE;
            if (dsp036VolleyRemainingChildren[best] <= 0)
                dsp036VolleyActive[best] = 0;
            // Avoid a malformed zero interval spinning forever.
            if (dsp036VolleyChildIntervalMillis[best] <= 0)
            {
                { if (!dsQuiet) Console.Printf("DS_P036_VOLLEY_MALFORMED volley=%d interval_millis=%d action=DEACTIVATED", best, dsp036VolleyChildIntervalMillis[best]); }
                dsp036VolleyActive[best] = 0;
            }
        }
    }

    void DSP036ResetReturningRuntime(int critSeed)
    {
        for (int i = 0; i < dsp036ProjectileProxies.Size(); i++)
            if (dsp036ProjectileProxies[i] != null)
                dsp036ProjectileProxies[i].Destroy();
        dsp036WeaponSystems.Clear(); dsp036WeaponRanks.Clear();
        dsp036WeaponSlots.Clear(); dsp036WeaponGenerations.Clear();
        dsp036WeaponIds.Clear(); dsp036WeaponNextVolleyMilliTics.Clear();
        dsp036VolleyActive.Clear(); dsp036VolleyWeaponIndexes.Clear();
        dsp036VolleyIds.Clear(); dsp036VolleyNextChildMilliTics.Clear();
        dsp036VolleyRemainingChildren.Clear(); dsp036VolleyChildOrdinals.Clear();
        dsp036VolleyTargetFound.Clear(); dsp036VolleyTargetSlots.Clear();
        dsp036VolleyTargetGenerations.Clear(); dsp036VolleyTargetIds.Clear();
        dsp036VolleyAimYawMilli.Clear(); dsp036VolleyRankHash.Clear();
        dsp036VolleyMightMilli.Clear(); dsp036VolleyCooldownMilli.Clear();
        dsp036VolleyCritChancePermille.Clear(); dsp036VolleyCritMultiplierMilli.Clear();
        dsp036VolleyLuckAffectsCrit.Clear(); dsp036VolleyDamageTenths.Clear();
        dsp036VolleyAreaMilli.Clear(); dsp036VolleySpeedMilli.Clear();
        dsp036VolleyChildIntervalMillis.Clear(); dsp036VolleyPierceLimit.Clear();
        dsp036VolleyPoolLimit.Clear(); dsp036VolleyLaunchSpeed.Clear();
        dsp036VolleyOutboundBase.Clear(); dsp036VolleyReverseFactorMilli.Clear();
        dsp036VolleyTotalFactorMilli.Clear(); dsp036VolleyLifetimeTics.Clear();
        dsp036VolleyBaseRadiusMilli.Clear(); dsp036VolleyPathKind.Clear();
        dsp036VolleyTargetPolicy.Clear(); dsp036VolleyReturnPolicy.Clear();
        dsp036VolleyWallPolicy.Clear(); dsp036VolleyPassesPerLeg.Clear();
        dsp036ProjectileActive.Clear(); dsp036ProjectileEvents.Clear();
        dsp036ProjectileParents.Clear(); dsp036ProjectileSystems.Clear();
        dsp036ProjectileRanks.Clear(); dsp036ProjectileChildOrdinals.Clear();
        dsp036ProjectileWeaponSlots.Clear(); dsp036ProjectileWeaponGenerations.Clear();
        dsp036ProjectileWeaponIds.Clear(); dsp036ProjectileOwnerSlots.Clear();
        dsp036ProjectileOwnerGenerations.Clear(); dsp036ProjectileOwnerIds.Clear();
        dsp036ProjectileTargetSlots.Clear(); dsp036ProjectileTargetGenerations.Clear();
        dsp036ProjectileTargetIds.Clear(); dsp036ProjectileAimYawMilli.Clear();
        dsp036ProjectilePhase.Clear(); dsp036ProjectilePassesCompleted.Clear();
        dsp036ProjectileAgeTics.Clear(); dsp036ProjectileLifetimeTics.Clear();
        dsp036ProjectileDamageTenths.Clear(); dsp036ProjectileMightMilli.Clear();
        dsp036ProjectileCritChancePermille.Clear();
        dsp036ProjectileCritMultiplierMilli.Clear();
        dsp036ProjectileLuckAffectsCrit.Clear();
        dsp036ProjectilePierceLimit.Clear();
        dsp036ProjectileOutboundHitCount.Clear();
        dsp036ProjectileReverseHitCount.Clear();
        dsp036ProjectileSpeedUnitsPerSecond.Clear();
        dsp036ProjectileOutboundDistance.Clear();
        dsp036ProjectileReverseDistance.Clear();
        dsp036ProjectileRangeBudget.Clear(); dsp036ProjectileRadiusMilli.Clear();
        dsp036ProjectilePathKind.Clear(); dsp036ProjectileReturnPolicy.Clear();
        dsp036ProjectileWallPolicy.Clear(); dsp036ProjectileRankHash.Clear();
        dsp036ProjectileOriginX.Clear(); dsp036ProjectileOriginY.Clear();
        dsp036ProjectileX.Clear(); dsp036ProjectileY.Clear();
        dsp036ProjectileDirectionX.Clear(); dsp036ProjectileDirectionY.Clear();
        dsp036ProjectileOutboundTravelled.Clear();
        dsp036ProjectileReverseTravelled.Clear();
        dsp036ProjectileTotalTravelled.Clear(); dsp036ProjectileProxies.Clear();
        dsp036HitProjectileEvents.Clear(); dsp036HitPasses.Clear();
        dsp036HitTargetSlots.Clear(); dsp036HitTargetGenerations.Clear();
        dsp036HitTargetIds.Clear(); dsp036CollisionFractions.Clear();
        dsp036CollisionSlots.Clear(); dsp036CollisionGenerations.Clear();
        dsp036CollisionIds.Clear();
        DSP036ResetTargeting(critSeed);
        dsp036VolleyOrdinal = 0; dsp036ProjectileOrdinal = 0;
        dsp036AcceptedHits = 0; dsp036RejectedHits = 0;
        dsp036SkippedChildren = 0; dsp036AcceptedDamageMilli = 0;
        dsp036EventOrdinal = 0;
        { if (!dsQuiet) Console.Printf("DS_P036_RUNTIME_RESET crit_seed=%d crit_rng=DEDICATED_P025_XORSHIFT native_projectiles=VISUAL_ONLY", critSeed); }
    }

    // Coordinate rebases translate both current flight positions and frozen
    // launch anchors. Heading, travel, leg and hit state are unchanged.
    void DSP036RebaseProjectiles(double deltaX, double deltaY)
    {
        int shifted = 0;
        for (int i = 0; i < dsp036ProjectileActive.Size(); i++)
        {
            if (dsp036ProjectileActive[i] == 0) continue;
            dsp036ProjectileOriginX[i] += deltaX;
            dsp036ProjectileOriginY[i] += deltaY;
            dsp036ProjectileX[i] += deltaX;
            dsp036ProjectileY[i] += deltaY;
            if (dsp036ProjectileProxies[i] != null)
                dsp036ProjectileProxies[i].SetOrigin(
                    (dsp036ProjectileX[i], dsp036ProjectileY[i], DSProjectileProxyBase.VISUAL_Z), true);
            shifted++;
        }
        { if (!dsQuiet) Console.Printf("DS_P036_REBASE shifted=%d delta_x=%.3f delta_y=%.3f flight_heading=UNCHANGED travel=UNCHANGED hit_ledger=UNCHANGED", shifted, deltaX, deltaY); }
    }

    bool DSP036HasHitOnPass(int eventId, int pass, int slot,
        int generation, int stableId)
    {
        for (int i = 0; i < dsp036HitProjectileEvents.Size(); i++)
            if (dsp036HitProjectileEvents[i] == eventId
                && dsp036HitPasses[i] == pass
                && dsp036HitTargetSlots[i] == slot
                && dsp036HitTargetGenerations[i] == generation
                && dsp036HitTargetIds[i] == stableId) return true;
        return false;
    }

    void DSP036RecordHitOnPass(int eventId, int pass, int slot,
        int generation, int stableId)
    {
        dsp036HitProjectileEvents.Push(eventId);
        dsp036HitPasses.Push(pass);
        dsp036HitTargetSlots.Push(slot);
        dsp036HitTargetGenerations.Push(generation);
        dsp036HitTargetIds.Push(stableId);
    }

    int DSP036HashMix(int hash, int value)
    {
        int normalized = value % 1000003;
        if (normalized < 0) normalized += 1000003;
        return (hash * 31 + normalized) % 1000003;
    }

    int DSP036HashMixDoubleMilli(int hash, double value)
    {
        int quantized;
        if (value >= 2000000.0) quantized = 2000000000;
        else if (value <= -2000000.0) quantized = -2000000000;
        else quantized = int(value * 1000.0);
        return DSP036HashMix(hash, quantized);
    }

    int DSP036HashWeaponState(int hash, int i)
    {
        hash = DSP036HashMix(hash, dsp036WeaponSystems[i]);
        hash = DSP036HashMix(hash, dsp036WeaponRanks[i]);
        hash = DSP036HashMix(hash, dsp036WeaponSlots[i]);
        hash = DSP036HashMix(hash, dsp036WeaponGenerations[i]);
        hash = DSP036HashMix(hash, dsp036WeaponIds[i]);
        hash = DSP036HashMix(hash, dsp036WeaponNextVolleyMilliTics[i]);
        return hash;
    }

    int DSP036HashVolleyStateA(int hash, int i)
    {
        hash = DSP036HashMix(hash, dsp036VolleyActive[i]);
        if (dsp036VolleyActive[i] == 0) return hash;
        hash = DSP036HashMix(hash, dsp036VolleyWeaponIndexes[i]);
        hash = DSP036HashMix(hash, dsp036VolleyIds[i]);
        hash = DSP036HashMix(hash, dsp036VolleyNextChildMilliTics[i]);
        hash = DSP036HashMix(hash, dsp036VolleyRemainingChildren[i]);
        hash = DSP036HashMix(hash, dsp036VolleyChildOrdinals[i]);
        hash = DSP036HashMix(hash, dsp036VolleyTargetFound[i]);
        hash = DSP036HashMix(hash, dsp036VolleyTargetSlots[i]);
        hash = DSP036HashMix(hash, dsp036VolleyTargetGenerations[i]);
        hash = DSP036HashMix(hash, dsp036VolleyTargetIds[i]);
        hash = DSP036HashMix(hash, dsp036VolleyAimYawMilli[i]);
        hash = DSP036HashMix(hash, dsp036VolleyRankHash[i]);
        hash = DSP036HashMix(hash, dsp036VolleyMightMilli[i]);
        hash = DSP036HashMix(hash, dsp036VolleyCooldownMilli[i]);
        hash = DSP036HashMix(hash, dsp036VolleyCritChancePermille[i]);
        hash = DSP036HashMix(hash, dsp036VolleyCritMultiplierMilli[i]);
        hash = DSP036HashMix(hash, dsp036VolleyLuckAffectsCrit[i]);
        hash = DSP036HashMix(hash, dsp036VolleyDamageTenths[i]);
        return hash;
    }

    int DSP036HashVolleyStateB(int hash, int i)
    {
        if (dsp036VolleyActive[i] == 0) return hash;
        hash = DSP036HashMix(hash, dsp036VolleyAreaMilli[i]);
        hash = DSP036HashMix(hash, dsp036VolleySpeedMilli[i]);
        hash = DSP036HashMix(hash, dsp036VolleyChildIntervalMillis[i]);
        hash = DSP036HashMix(hash, dsp036VolleyPierceLimit[i]);
        hash = DSP036HashMix(hash, dsp036VolleyPoolLimit[i]);
        hash = DSP036HashMix(hash, dsp036VolleyLaunchSpeed[i]);
        hash = DSP036HashMix(hash, dsp036VolleyOutboundBase[i]);
        hash = DSP036HashMix(hash, dsp036VolleyReverseFactorMilli[i]);
        hash = DSP036HashMix(hash, dsp036VolleyTotalFactorMilli[i]);
        hash = DSP036HashMix(hash, dsp036VolleyLifetimeTics[i]);
        hash = DSP036HashMix(hash, dsp036VolleyBaseRadiusMilli[i]);
        hash = DSP036HashMix(hash, dsp036VolleyPathKind[i]);
        hash = DSP036HashMix(hash, dsp036VolleyTargetPolicy[i]);
        hash = DSP036HashMix(hash, dsp036VolleyReturnPolicy[i]);
        hash = DSP036HashMix(hash, dsp036VolleyWallPolicy[i]);
        hash = DSP036HashMix(hash, dsp036VolleyPassesPerLeg[i]);
        return hash;
    }

    int DSP036HashProjectileStateA(int hash, int i)
    {
        hash = DSP036HashMix(hash, dsp036ProjectileActive[i]);
        if (dsp036ProjectileActive[i] == 0) return hash;
        hash = DSP036HashMix(hash, dsp036ProjectileEvents[i]);
        hash = DSP036HashMix(hash, dsp036ProjectileParents[i]);
        hash = DSP036HashMix(hash, dsp036ProjectileSystems[i]);
        hash = DSP036HashMix(hash, dsp036ProjectileRanks[i]);
        hash = DSP036HashMix(hash, dsp036ProjectileChildOrdinals[i]);
        hash = DSP036HashMix(hash, dsp036ProjectileWeaponSlots[i]);
        hash = DSP036HashMix(hash, dsp036ProjectileWeaponGenerations[i]);
        hash = DSP036HashMix(hash, dsp036ProjectileWeaponIds[i]);
        hash = DSP036HashMix(hash, dsp036ProjectileOwnerSlots[i]);
        hash = DSP036HashMix(hash, dsp036ProjectileOwnerGenerations[i]);
        hash = DSP036HashMix(hash, dsp036ProjectileOwnerIds[i]);
        hash = DSP036HashMix(hash, dsp036ProjectileTargetSlots[i]);
        hash = DSP036HashMix(hash, dsp036ProjectileTargetGenerations[i]);
        hash = DSP036HashMix(hash, dsp036ProjectileTargetIds[i]);
        hash = DSP036HashMix(hash, dsp036ProjectileAimYawMilli[i]);
        hash = DSP036HashMix(hash, dsp036ProjectilePhase[i]);
        hash = DSP036HashMix(hash, dsp036ProjectilePassesCompleted[i]);
        hash = DSP036HashMix(hash, dsp036ProjectileAgeTics[i]);
        return hash;
    }

    int DSP036HashProjectileStateB(int hash, int i)
    {
        if (dsp036ProjectileActive[i] == 0) return hash;
        hash = DSP036HashMix(hash, dsp036ProjectileLifetimeTics[i]);
        hash = DSP036HashMix(hash, dsp036ProjectileDamageTenths[i]);
        hash = DSP036HashMix(hash, dsp036ProjectileMightMilli[i]);
        hash = DSP036HashMix(hash, dsp036ProjectileCritChancePermille[i]);
        hash = DSP036HashMix(hash, dsp036ProjectileCritMultiplierMilli[i]);
        hash = DSP036HashMix(hash, dsp036ProjectileLuckAffectsCrit[i]);
        hash = DSP036HashMix(hash, dsp036ProjectilePierceLimit[i]);
        hash = DSP036HashMix(hash, dsp036ProjectileOutboundHitCount[i]);
        hash = DSP036HashMix(hash, dsp036ProjectileReverseHitCount[i]);
        hash = DSP036HashMix(hash, dsp036ProjectileSpeedUnitsPerSecond[i]);
        hash = DSP036HashMix(hash, dsp036ProjectileOutboundDistance[i]);
        hash = DSP036HashMix(hash, dsp036ProjectileReverseDistance[i]);
        hash = DSP036HashMix(hash, dsp036ProjectileRangeBudget[i]);
        hash = DSP036HashMix(hash, dsp036ProjectileRadiusMilli[i]);
        hash = DSP036HashMix(hash, dsp036ProjectilePathKind[i]);
        hash = DSP036HashMix(hash, dsp036ProjectileReturnPolicy[i]);
        hash = DSP036HashMix(hash, dsp036ProjectileWallPolicy[i]);
        hash = DSP036HashMix(hash, dsp036ProjectileRankHash[i]);
        hash = DSP036HashMixDoubleMilli(hash, dsp036ProjectileOriginX[i]);
        hash = DSP036HashMixDoubleMilli(hash, dsp036ProjectileOriginY[i]);
        hash = DSP036HashMixDoubleMilli(hash, dsp036ProjectileX[i]);
        hash = DSP036HashMixDoubleMilli(hash, dsp036ProjectileY[i]);
        hash = DSP036HashMixDoubleMilli(hash, dsp036ProjectileDirectionX[i]);
        hash = DSP036HashMixDoubleMilli(hash, dsp036ProjectileDirectionY[i]);
        hash = DSP036HashMixDoubleMilli(hash, dsp036ProjectileOutboundTravelled[i]);
        hash = DSP036HashMixDoubleMilli(hash, dsp036ProjectileReverseTravelled[i]);
        hash = DSP036HashMixDoubleMilli(hash, dsp036ProjectileTotalTravelled[i]);
        return hash;
    }

    int DSP036HashLedgerState(int hash, int i)
    {
        hash = DSP036HashMix(hash, dsp036HitProjectileEvents[i]);
        hash = DSP036HashMix(hash, dsp036HitPasses[i]);
        hash = DSP036HashMix(hash, dsp036HitTargetSlots[i]);
        hash = DSP036HashMix(hash, dsp036HitTargetGenerations[i]);
        hash = DSP036HashMix(hash, dsp036HitTargetIds[i]);
        return hash;
    }

    int DSP036ReturningStateHash()
    {
        int hash = 31;
        hash = DSP036HashMix(hash, dsp036VolleyOrdinal);
        hash = DSP036HashMix(hash, dsp036ProjectileOrdinal);
        hash = DSP036HashMix(hash, dsp036AcceptedHits);
        hash = DSP036HashMix(hash, dsp036RejectedHits);
        hash = DSP036HashMix(hash, dsp036SkippedChildren);
        hash = DSP036HashMix(hash, dsp036AcceptedDamageMilli);
        hash = DSP036HashMix(hash, dsp036EventOrdinal);
        hash = DSP036HashMix(hash, dsp036CritRng);
        hash = DSP036HashMix(hash, dsp036WeaponSystems.Size());
        hash = DSP036HashMix(hash, dsp036VolleyActive.Size());
        hash = DSP036HashMix(hash, dsp036ProjectileActive.Size());
        hash = DSP036HashMix(hash, dsp036HitProjectileEvents.Size());
        for (int i = 0; i < dsp036WeaponSystems.Size(); i++)
            hash = DSP036HashWeaponState(hash, i);
        for (int i = 0; i < dsp036VolleyActive.Size(); i++)
        {
            hash = DSP036HashVolleyStateA(hash, i);
            hash = DSP036HashVolleyStateB(hash, i);
        }
        for (int i = 0; i < dsp036ProjectileActive.Size(); i++)
        {
            hash = DSP036HashProjectileStateA(hash, i);
            hash = DSP036HashProjectileStateB(hash, i);
        }
        for (int i = 0; i < dsp036HitProjectileEvents.Size(); i++)
            hash = DSP036HashLedgerState(hash, i);
        return hash;
    }
}
