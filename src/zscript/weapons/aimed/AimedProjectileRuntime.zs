// P034 reusable projectile schedule, snapshot and logical-hit adapter.
// MAP16 supplies controlled equipment bindings; this file owns no source
// inventory, passive rank, or transformation-recipe state.
class DSP034ProjectileProxy : DSProjectileProxyBase
{
    int logicalEventId;

    Default
    {
        Radius 2;
        Height 4;
        +NOBLOCKMAP;
        +NOGRAVITY;
        +NOINTERACTION;
        RenderStyle "Add";
        Alpha 0.9;
        Scale 0.16;
    }

    States
    {
    Spawn:
        BILL A 1 Bright;
        Loop;
    }
}

mixin class DSP034AimedProjectileRuntime
{
    const DSP034_TARGET_ENEMY = 1;
    const DSP034_EVENT_BASE = 3400000;
    const DSP034_MAX_ACTIVE_BURSTS = 64;
    // Hard backstop for DSP034ProcessAimedTic's per-tic burst-child drain
    // loop: with <=64 active bursts and each real weapon row's amount well
    // under 1000, no legitimate tic ever drains anywhere close to this many
    // children. See the loop's own comment for the exact failure mode this
    // guards against.
    const DSP034_MAX_BURST_DRAIN_ITERATIONS_PER_TIC = 100000;

    Array<int> dsp034WeaponSystems;
    Array<int> dsp034WeaponRanks;
    Array<int> dsp034WeaponSlots;
    Array<int> dsp034WeaponGenerations;
    Array<int> dsp034WeaponStableIds;
    Array<int> dsp034NextVolleyMilliTics;

    // A weapon owns one independent top-level clock, while each emitted
    // volley owns its own child clock and immutable row/stat snapshot. This
    // permits a new cast to begin before the prior burst's last child.
    Array<int> dsp034BurstActive;
    Array<int> dsp034BurstWeaponIndexes;
    Array<int> dsp034BurstVolleyIds;
    Array<int> dsp034BurstNextChildMilliTics;
    Array<int> dsp034BurstRemainingChildren;
    Array<int> dsp034BurstChildOrdinals;
    Array<int> dsp034BurstDamageTenths;
    Array<int> dsp034BurstAmount;
    Array<int> dsp034BurstPierce;
    Array<int> dsp034BurstIntervalMillis;
    Array<int> dsp034BurstSpeed;
    Array<int> dsp034BurstRange;
    Array<int> dsp034BurstLifetime;
    Array<int> dsp034BurstRadiusMilli;
    Array<int> dsp034BurstPoolLimit;
    Array<int> dsp034BurstMightMilli;
    Array<int> dsp034BurstCooldownMillis;
    Array<int> dsp034BurstRankHash;

    Array<int> dsp034ProjectileActive;
    Array<int> dsp034ProjectileEvents;
    Array<int> dsp034ProjectileParents;
    Array<int> dsp034ProjectileSystems;
    Array<int> dsp034ProjectileRanks;
    Array<int> dsp034ProjectileWeaponSlots;
    Array<int> dsp034ProjectileWeaponGenerations;
    Array<int> dsp034ProjectileWeaponIds;
    Array<int> dsp034ProjectileOwnerSlots;
    Array<int> dsp034ProjectileOwnerGenerations;
    Array<int> dsp034ProjectileOwnerIds;
    Array<int> dsp034ProjectileTargetSlots;
    Array<int> dsp034ProjectileTargetGenerations;
    Array<int> dsp034ProjectileTargetIds;
    Array<int> dsp034ProjectileDamageTenths;
    Array<int> dsp034ProjectileMightMilli;
    Array<int> dsp034ProjectilePierce;
    Array<int> dsp034ProjectilePierceUsed;
    Array<int> dsp034ProjectileExpireTics;
    Array<int> dsp034ProjectileRange;
    Array<int> dsp034ProjectileRadiusMilli;
    Array<int> dsp034ProjectileAimYawMilli;
    Array<int> dsp034ProjectileRankHash;
    Array<double> dsp034ProjectileX;
    Array<double> dsp034ProjectileY;
    Array<double> dsp034ProjectileVelocityX;
    Array<double> dsp034ProjectileVelocityY;
    Array<double> dsp034ProjectileTravelled;
    Array<DSP034ProjectileProxy> dsp034ProjectileProxies;

    Array<int> dsp034HitProjectileEvents;
    Array<int> dsp034HitTargetSlots;
    Array<int> dsp034HitTargetGenerations;
    Array<int> dsp034HitTargetIds;

    Array<double> dsp034CollisionFractions;
    Array<int> dsp034CollisionSlots;
    Array<int> dsp034CollisionGenerations;
    Array<int> dsp034CollisionIds;

    int dsp034EventOrdinal;
    int dsp034VolleyOrdinal;
    int dsp034LastViewYawMilli;
    bool dsp034HasViewYaw;
    int dsp034EmittedChildren;
    int dsp034SkippedChildren;
    int dsp034AcceptedHits;
    int dsp034RejectedHits;
    int dsp034AcceptedDamageMilli;

    void DSP034ResetAimedRuntime()
    {
        for (int i = 0; i < dsp034ProjectileProxies.Size(); i++)
        {
            if (dsp034ProjectileProxies[i] != null)
                dsp034ProjectileProxies[i].Destroy();
        }
        dsp034WeaponSystems.Clear(); dsp034WeaponRanks.Clear();
        dsp034WeaponSlots.Clear(); dsp034WeaponGenerations.Clear();
        dsp034WeaponStableIds.Clear(); dsp034NextVolleyMilliTics.Clear();
        dsp034BurstActive.Clear(); dsp034BurstWeaponIndexes.Clear();
        dsp034BurstVolleyIds.Clear(); dsp034BurstNextChildMilliTics.Clear();
        dsp034BurstRemainingChildren.Clear(); dsp034BurstChildOrdinals.Clear();
        dsp034BurstDamageTenths.Clear(); dsp034BurstAmount.Clear();
        dsp034BurstPierce.Clear(); dsp034BurstIntervalMillis.Clear();
        dsp034BurstSpeed.Clear(); dsp034BurstRange.Clear();
        dsp034BurstLifetime.Clear(); dsp034BurstRadiusMilli.Clear();
        dsp034BurstPoolLimit.Clear(); dsp034BurstMightMilli.Clear();
        dsp034BurstCooldownMillis.Clear(); dsp034BurstRankHash.Clear();
        dsp034ProjectileActive.Clear(); dsp034ProjectileEvents.Clear();
        dsp034ProjectileParents.Clear(); dsp034ProjectileSystems.Clear();
        dsp034ProjectileRanks.Clear(); dsp034ProjectileWeaponSlots.Clear();
        dsp034ProjectileWeaponGenerations.Clear(); dsp034ProjectileWeaponIds.Clear();
        dsp034ProjectileOwnerSlots.Clear(); dsp034ProjectileOwnerGenerations.Clear();
        dsp034ProjectileOwnerIds.Clear(); dsp034ProjectileTargetSlots.Clear();
        dsp034ProjectileTargetGenerations.Clear(); dsp034ProjectileTargetIds.Clear();
        dsp034ProjectileDamageTenths.Clear(); dsp034ProjectileMightMilli.Clear();
        dsp034ProjectilePierce.Clear(); dsp034ProjectilePierceUsed.Clear();
        dsp034ProjectileExpireTics.Clear(); dsp034ProjectileRange.Clear();
        dsp034ProjectileRadiusMilli.Clear(); dsp034ProjectileAimYawMilli.Clear();
        dsp034ProjectileRankHash.Clear(); dsp034ProjectileX.Clear(); dsp034ProjectileY.Clear();
        dsp034ProjectileVelocityX.Clear(); dsp034ProjectileVelocityY.Clear();
        dsp034ProjectileTravelled.Clear(); dsp034ProjectileProxies.Clear();
        dsp034HitProjectileEvents.Clear(); dsp034HitTargetSlots.Clear();
        dsp034HitTargetGenerations.Clear(); dsp034HitTargetIds.Clear();
        dsp034CollisionFractions.Clear(); dsp034CollisionSlots.Clear();
        dsp034CollisionGenerations.Clear(); dsp034CollisionIds.Clear();
        dsp034EventOrdinal = 0; dsp034VolleyOrdinal = 0;
        dsp034LastViewYawMilli = 0; dsp034HasViewYaw = false;
        dsp034EmittedChildren = 0; dsp034SkippedChildren = 0;
        dsp034AcceptedHits = 0; dsp034RejectedHits = 0;
        dsp034AcceptedDamageMilli = 0;
    }

    bool DSP034EquipAimedFixture(int systemId, int rank, int weaponSlot,
        int firstFireTic)
    {
        int damageTenths; int amount; int pierce; int cooldownMillis;
        int childIntervalMillis; int speedMilli; int travelSpeed;
        int rangeUnits; int lifetimeTics; int radiusMilli; int poolLimit;
        if (!DSP034WeaponRows.TryGetRankRow(systemId, rank,
                damageTenths, amount, pierce, cooldownMillis,
                childIntervalMillis, speedMilli, travelSpeed, rangeUnits,
                lifetimeTics, radiusMilli, poolLimit)
            || weaponSlot < 0 || weaponSlot >= lifeStates.Size()
            || lifeStates[weaponSlot] != STORE_ALIVE || firstFireTic < 0)
            return false;

        dsp034WeaponSystems.Push(systemId);
        dsp034WeaponRanks.Push(rank);
        dsp034WeaponSlots.Push(weaponSlot);
        dsp034WeaponGenerations.Push(generations[weaponSlot]);
        dsp034WeaponStableIds.Push(ids[weaponSlot]);
        dsp034NextVolleyMilliTics.Push(firstFireTic * 1000);
        { if (!dsQuiet) Console.Printf("DS_P034_EQUIP accepted=1 system_id=%d rank=%d weapon_slot=%d weapon_generation=%d weapon_id=%d first_fire_tic=%d classification=CONTROLLED_MAP16_FIXTURE source_inventory_claim=0", systemId, rank, weaponSlot, generations[weaponSlot], ids[weaponSlot], firstFireTic); }
        return true;
    }

    bool DSP034SetControlledFixtureRank(int weaponSlot, int systemId,
        int rank, int logicalTic)
    {
        int damageTenths; int amount; int pierce; int cooldownMillis;
        int childIntervalMillis; int speedMilli; int travelSpeed;
        int rangeUnits; int lifetimeTics; int radiusMilli; int poolLimit;
        if (!DSP034WeaponRows.TryGetRankRow(systemId, rank,
                damageTenths, amount, pierce, cooldownMillis,
                childIntervalMillis, speedMilli, travelSpeed, rangeUnits,
                lifetimeTics, radiusMilli, poolLimit)) return false;
        for (int i = 0; i < dsp034WeaponSystems.Size(); i++)
        {
            if (dsp034WeaponSlots[i] != weaponSlot) continue;
            if (!ValidParts(weaponSlot, dsp034WeaponGenerations[i],
                    dsp034WeaponStableIds[i])
                || dsp034WeaponSystems[i] != systemId) return false;
            int priorRank = dsp034WeaponRanks[i];
            dsp034WeaponRanks[i] = rank;
            { if (!dsQuiet) Console.Printf("DS_P034_FIXTURE_RANK accepted=1 tic=%d system_id=%d prior_rank=%d rank=%d weapon_id=%d weapon_generation=%d classification=CONTROLLED_MAP16_FIXTURE source_inventory_claim=0", logicalTic, systemId, priorRank, rank, dsp034WeaponStableIds[i], dsp034WeaponGenerations[i]); }
            return true;
        }
        return false;
    }

    bool DSP034ReplaceControlledFixture(int weaponSlot,
        int evolvedSystemId, int evolvedRank, int logicalTic)
    {
        int sourceSystemId; int requiredSourceRank;
        int requiredPassiveKind; int requiredPassiveRank;
        if (!DSP034WeaponRows.TryGetTransformation(evolvedSystemId,
                sourceSystemId, requiredSourceRank, requiredPassiveKind,
                requiredPassiveRank)) return false;
        int damageTenths; int amount; int pierce; int cooldownMillis;
        int childIntervalMillis; int speedMilli; int travelSpeed;
        int rangeUnits; int lifetimeTics; int radiusMilli; int poolLimit;
        if (!DSP034WeaponRows.TryGetRankRow(evolvedSystemId, evolvedRank,
                damageTenths, amount, pierce, cooldownMillis,
                childIntervalMillis, speedMilli, travelSpeed, rangeUnits,
                lifetimeTics, radiusMilli, poolLimit)) return false;

        for (int i = 0; i < dsp034WeaponSystems.Size(); i++)
        {
            if (dsp034WeaponSlots[i] != weaponSlot) continue;
            if (!ValidParts(weaponSlot, dsp034WeaponGenerations[i],
                    dsp034WeaponStableIds[i])
                || dsp034WeaponSystems[i] != sourceSystemId
                || dsp034WeaponRanks[i] < requiredSourceRank) return false;
            int oldSystemId = dsp034WeaponSystems[i];
            int oldRank = dsp034WeaponRanks[i];
            int cancelledBursts = 0;
            int cancelledProjectiles = 0;
            for (int burst = 0; burst < dsp034BurstActive.Size(); burst++)
            {
                if (dsp034BurstActive[burst] == 0
                    || dsp034BurstWeaponIndexes[burst] != i) continue;
                dsp034BurstActive[burst] = 0;
                cancelledBursts++;
            }
            for (int projectile = 0;
                 projectile < dsp034ProjectileActive.Size(); projectile++)
            {
                if (dsp034ProjectileActive[projectile] == 0
                    || dsp034ProjectileWeaponSlots[projectile] != weaponSlot
                    || dsp034ProjectileWeaponGenerations[projectile]
                        != dsp034WeaponGenerations[i]
                    || dsp034ProjectileWeaponIds[projectile]
                        != dsp034WeaponStableIds[i]) continue;
                DSP034RetireProjectile(projectile, "FORM_REPLACED");
                cancelledProjectiles++;
            }
            dsp034WeaponSystems[i] = evolvedSystemId;
            dsp034WeaponRanks[i] = evolvedRank;
            dsp034NextVolleyMilliTics[i] = logicalTic * 1000;
            { if (!dsQuiet) Console.Printf("DS_P034_FIXTURE_REPLACE accepted=1 tic=%d source_system_id=%d source_rank=%d evolved_system_id=%d evolved_rank=%d source_weapon_id=%d weapon_generation=%d canceled_bursts=%d canceled_projectiles=%d required_source_rank=%d required_passive_kind=%d required_passive_rank=%d next_fire_due=1 classification=CONTROLLED_MAP16_FIXTURE source_inventory_claim=0", logicalTic, oldSystemId, oldRank, evolvedSystemId, evolvedRank, dsp034WeaponStableIds[i], dsp034WeaponGenerations[i], cancelledBursts, cancelledProjectiles, requiredSourceRank, requiredPassiveKind, requiredPassiveRank); }
            return true;
        }
        return false;
    }

    int DSP034NewEventId()
    {
        dsp034EventOrdinal++;
        return DSP034_EVENT_BASE + dsp034EventOrdinal;
    }

    int DSP034ScaledDamageMilli(int damageTenths, int mightMilli,
        out bool valid)
    {
        int scaledTenths = 0;
        valid = DSP025CheckedDamage(damageTenths, 0, mightMilli, scaledTenths)
            && scaledTenths >= 0 && scaledTenths <= 20000000;
        return valid ? scaledTenths * 100 : 0;
    }

    bool DSP034StartVolley(int weaponIndex, int logicalTic,
        int mightMilli, int cooldownMultiplierMilli, int rankHash)
    {
        int systemId = dsp034WeaponSystems[weaponIndex];
        int rank = dsp034WeaponRanks[weaponIndex];
        int damageTenths; int amount; int pierce; int cooldownMillis;
        int childIntervalMillis; int speedMilli; int travelSpeed;
        int rangeUnits; int lifetimeTics; int radiusMilli; int poolLimit;
        if (!ValidParts(dsp034WeaponSlots[weaponIndex],
                dsp034WeaponGenerations[weaponIndex],
                dsp034WeaponStableIds[weaponIndex])
            || !DSP034WeaponRows.TryGetRankRow(systemId, rank,
                damageTenths, amount, pierce, cooldownMillis,
                childIntervalMillis, speedMilli, travelSpeed, rangeUnits,
                lifetimeTics, radiusMilli, poolLimit))
        {
            Console.Printf("DS_P034_VOLLEY_REJECT system_id=%d rank=%d reason=STALE_WEAPON_OR_ROW", systemId, rank);
            return false;
        }
        if (rsActive)
        {
            // Run stats (RunStatFields.zs): Amount, Speed (and the range it
            // covers in the same lifetime) and Area.
            amount += RsAmountFor(systemId); poolLimit += RsAmountFor(systemId);
            travelSpeed = travelSpeed * RsSpeedFor(systemId) / 1000;
            rangeUnits = rangeUnits * RsSpeedFor(systemId) / 1000;
            radiusMilli = radiusMilli * RsAreaFor(systemId) / 1000;
        }

        int adjustedCooldown = DSP033StatRules.CooldownAfterTome(
            systemId, cooldownMillis, cooldownMultiplierMilli);
        if (adjustedCooldown <= 0 || amount <= 0 || pierce <= 0
            || childIntervalMillis <= 0 || travelSpeed <= 0
            || rangeUnits <= 0 || lifetimeTics <= 0 || radiusMilli <= 0
            || poolLimit <= 0)
        {
            Console.Printf("DS_P034_VOLLEY_REJECT system_id=%d rank=%d reason=INVALID_ROW_OR_SCHEDULE", systemId, rank);
            return false;
        }

        int activeBurstsBefore = DSP034ActiveBurstsForWeapon(weaponIndex);
        int burstIndex = -1;
        for (int i = 0; i < dsp034BurstActive.Size(); i++)
            if (dsp034BurstActive[i] == 0) { burstIndex = i; break; }
        if (burstIndex < 0)
        {
            int activeCount = 0;
            for (int i = 0; i < dsp034BurstActive.Size(); i++)
                if (dsp034BurstActive[i] != 0) activeCount++;
            if (activeCount >= DSP034_MAX_ACTIVE_BURSTS)
            {
                Console.Printf("DS_P034_VOLLEY_REJECT system_id=%d rank=%d reason=ACTIVE_BURST_POOL_FULL", systemId, rank);
                return false;
            }
            burstIndex = dsp034BurstActive.Size();
            dsp034BurstActive.Push(0); dsp034BurstWeaponIndexes.Push(0);
            dsp034BurstVolleyIds.Push(0); dsp034BurstNextChildMilliTics.Push(0);
            dsp034BurstRemainingChildren.Push(0); dsp034BurstChildOrdinals.Push(0);
            dsp034BurstDamageTenths.Push(0); dsp034BurstAmount.Push(0);
            dsp034BurstPierce.Push(0); dsp034BurstIntervalMillis.Push(0);
            dsp034BurstSpeed.Push(0); dsp034BurstRange.Push(0);
            dsp034BurstLifetime.Push(0); dsp034BurstRadiusMilli.Push(0);
            dsp034BurstPoolLimit.Push(0); dsp034BurstMightMilli.Push(1000);
            dsp034BurstCooldownMillis.Push(0); dsp034BurstRankHash.Push(0);
        }
        int volleyId = DSP034_EVENT_BASE + 100000 + ++dsp034VolleyOrdinal;
        int cooldownMilliTics = adjustedCooldown * Thinker.TICRATE;
        dsp034NextVolleyMilliTics[weaponIndex] = logicalTic * 1000
            + cooldownMilliTics;
        dsp034BurstActive[burstIndex] = 1;
        dsp034BurstWeaponIndexes[burstIndex] = weaponIndex;
        dsp034BurstVolleyIds[burstIndex] = volleyId;
        dsp034BurstNextChildMilliTics[burstIndex] = logicalTic * 1000;
        dsp034BurstRemainingChildren[burstIndex] = amount;
        dsp034BurstChildOrdinals[burstIndex] = 0;
        dsp034BurstDamageTenths[burstIndex] = damageTenths;
        dsp034BurstAmount[burstIndex] = amount;
        dsp034BurstPierce[burstIndex] = pierce + RsPierceFor(systemId);
        dsp034BurstIntervalMillis[burstIndex] = childIntervalMillis;
        dsp034BurstSpeed[burstIndex] = travelSpeed;
        dsp034BurstRange[burstIndex] = rangeUnits;
        dsp034BurstLifetime[burstIndex] = lifetimeTics;
        dsp034BurstRadiusMilli[burstIndex] = radiusMilli;
        dsp034BurstPoolLimit[burstIndex] = poolLimit;
        dsp034BurstMightMilli[burstIndex] = mightMilli;
        dsp034BurstCooldownMillis[burstIndex] = adjustedCooldown;
        dsp034BurstRankHash[burstIndex] = rankHash;
        DSSound.Weapon(systemId);
        { if (!dsQuiet) Console.Printf("DS_P034_VOLLEY event_id=%d tic=%d system_id=%d rank=%d weapon_slot=%d weapon_generation=%d weapon_id=%d amount=%d damage_tenths=%d pierce=%d cooldown_ms=%d child_interval_ms=%d cooldown_stat_applies=1 interval_stat_applies=0 might_milli=%d rank_hash=%d schedule=AUTOMATIC active_bursts_for_weapon=%d overlap=%d", volleyId, logicalTic, systemId, rank, dsp034WeaponSlots[weaponIndex], dsp034WeaponGenerations[weaponIndex], dsp034WeaponStableIds[weaponIndex], amount, damageTenths, pierce, adjustedCooldown, childIntervalMillis, mightMilli, rankHash, activeBurstsBefore + 1, activeBurstsBefore > 0 ? 1 : 0); }
        return true;
    }

    bool DSP034HasProjectileHit(int eventId, int slot, int generation,
        int stableId)
    {
        for (int i = 0; i < dsp034HitProjectileEvents.Size(); i++)
            if (dsp034HitProjectileEvents[i] == eventId
                && dsp034HitTargetSlots[i] == slot
                && dsp034HitTargetGenerations[i] == generation
                && dsp034HitTargetIds[i] == stableId) return true;
        return false;
    }

    void DSP034RecordProjectileHit(int eventId, int slot, int generation,
        int stableId)
    {
        dsp034HitProjectileEvents.Push(eventId);
        dsp034HitTargetSlots.Push(slot);
        dsp034HitTargetGenerations.Push(generation);
        dsp034HitTargetIds.Push(stableId);
    }

    int DSP034ActiveProjectileCount(int systemId)
    {
        int count = 0;
        for (int i = 0; i < dsp034ProjectileActive.Size(); i++)
            if (dsp034ProjectileActive[i] != 0
                && dsp034ProjectileSystems[i] == systemId) count++;
        return count;
    }

    int DSP034ActiveBurstsForWeapon(int weaponIndex)
    {
        int count = 0;
        for (int i = 0; i < dsp034BurstActive.Size(); i++)
            if (dsp034BurstActive[i] != 0
                && dsp034BurstWeaponIndexes[i] == weaponIndex) count++;
        return count;
    }

    void DSP034RetireProjectile(int index, String reason)
    {
        if (index < 0 || index >= dsp034ProjectileActive.Size()
            || dsp034ProjectileActive[index] == 0) return;
        dsp034ProjectileActive[index] = 0;
        if (dsp034ProjectileProxies[index] != null)
        {
            dsp034ProjectileProxies[index].Destroy();
            dsp034ProjectileProxies[index] = null;
        }
        { if (!dsQuiet) Console.Printf("DS_P034_PROJECTILE_END event_id=%d tic=%d system_id=%d reason=%s pierce_used=%d traveled=%.3f", dsp034ProjectileEvents[index], tic, dsp034ProjectileSystems[index], reason, dsp034ProjectilePierceUsed[index], dsp034ProjectileTravelled[index]); }
    }

    bool DSP034SpawnChild(int burstIndex, int logicalTic,
        int ownerSlot, int ownerGeneration, int ownerStableId,
        bool hasViewYaw, int viewYawMilli)
    {
        int weaponIndex = dsp034BurstWeaponIndexes[burstIndex];
        int systemId = dsp034WeaponSystems[weaponIndex];
        int rank = dsp034WeaponRanks[weaponIndex];
        int projectileCount = DSP034ActiveProjectileCount(systemId);
        if (projectileCount >= dsp034BurstPoolLimit[burstIndex])
        {
            dsp034SkippedChildren++;
            Console.Printf("DS_P034_CHILD_SKIP tic=%d system_id=%d volley_id=%d child=%d reason=PROJECTILE_POOL_FULL", logicalTic, systemId, dsp034BurstVolleyIds[burstIndex], dsp034BurstChildOrdinals[burstIndex]);
            return false;
        }

        int targetSlot = -1; int targetGeneration = 0; int targetId = 0;
        double targetDistanceSquared = 0.0;
        double velocityX = 0.0; double velocityY = 0.0;
        int aimYawMilli = 0;
        bool aimed = systemId == DSP034WeaponRows.SYSTEM_MAGIC_WAND
            || systemId == DSP034WeaponRows.SYSTEM_HOLY_WAND;
        if (hasViewYaw)
        {
            dsp034LastViewYawMilli = DSP034NormalizeYawMilli(viewYawMilli);
            dsp034HasViewYaw = true;
        }
        if (aimed)
        {
            if (!DSP034SelectNearestTarget(DSP034_TARGET_ENEMY,
                    playerX, playerY, double(dsp034BurstRange[burstIndex]),
                    targetSlot, targetGeneration, targetId,
                    targetDistanceSquared))
            {
                dsp034SkippedChildren++;
                Console.Printf("DS_P034_CHILD_SKIP tic=%d system_id=%d volley_id=%d child=%d reason=NO_LIVE_TARGET range_units=%d target_policy=NEAREST_PLANAR yaw_cone=0 pitch_input=0", logicalTic, systemId, dsp034BurstVolleyIds[burstIndex], dsp034BurstChildOrdinals[burstIndex], dsp034BurstRange[burstIndex]);
                return false;
            }
            double dx = x[targetSlot] - playerX;
            double dy = y[targetSlot] - playerY;
            double distance = sqrt(targetDistanceSquared);
            if (distance > 0.000001)
            {
                velocityX = dx / distance;
                velocityY = dy / distance;
                aimYawMilli = int(atan2(dy, dx) * 1000.0);
            }
            else
            {
                int fallbackYaw = dsp034HasViewYaw ? dsp034LastViewYawMilli : 0;
                DSP034FacingDirection(fallbackYaw, velocityX, velocityY);
                aimYawMilli = fallbackYaw;
            }
        }
        else
        {
            if (!dsp034HasViewYaw)
            {
                dsp034SkippedChildren++;
                Console.Printf("DS_P034_CHILD_SKIP tic=%d system_id=%d volley_id=%d child=%d reason=NO_VALID_VIEW_YAW", logicalTic, systemId, dsp034BurstVolleyIds[burstIndex], dsp034BurstChildOrdinals[burstIndex]);
                return false;
            }
            aimYawMilli = dsp034LastViewYawMilli;
            DSP034FacingDirection(aimYawMilli, velocityX, velocityY);
        }

        int eventId = DSP034NewEventId();
        DSP025AttackSnapshot snapshot;
        DSP025PopulateSnapshot(snapshot, eventId,
            dsp034BurstVolleyIds[burstIndex], ownerSlot, ownerGeneration,
            ownerStableId, dsp034WeaponStableIds[weaponIndex],
            dsp034WeaponGenerations[weaponIndex],
            dsp034BurstDamageTenths[burstIndex], 0,
            dsp034BurstMightMilli[burstIndex], dsp034BurstPierce[burstIndex],
            dsp034BurstAmount[burstIndex],
            logicalTic + dsp034BurstLifetime[burstIndex], 0, 0,
            aimYawMilli, 0, 0);
        snapshot.explicitTargetSlot = targetSlot;
        snapshot.explicitTargetGeneration = targetGeneration;
        snapshot.explicitTargetStableId = targetId;

        int projectileIndex = dsp034ProjectileActive.Size();
        dsp034ProjectileActive.Push(1); dsp034ProjectileEvents.Push(eventId);
        dsp034ProjectileParents.Push(snapshot.parentEventId);
        dsp034ProjectileSystems.Push(systemId); dsp034ProjectileRanks.Push(rank);
        dsp034ProjectileWeaponSlots.Push(dsp034WeaponSlots[weaponIndex]);
        dsp034ProjectileWeaponGenerations.Push(dsp034WeaponGenerations[weaponIndex]);
        dsp034ProjectileWeaponIds.Push(dsp034WeaponStableIds[weaponIndex]);
        dsp034ProjectileOwnerSlots.Push(ownerSlot);
        dsp034ProjectileOwnerGenerations.Push(ownerGeneration);
        dsp034ProjectileOwnerIds.Push(ownerStableId);
        dsp034ProjectileTargetSlots.Push(targetSlot);
        dsp034ProjectileTargetGenerations.Push(targetGeneration);
        dsp034ProjectileTargetIds.Push(targetId);
        dsp034ProjectileDamageTenths.Push(snapshot.damageBase);
        dsp034ProjectileMightMilli.Push(snapshot.multiplierMilli);
        dsp034ProjectilePierce.Push(snapshot.pierce);
        dsp034ProjectilePierceUsed.Push(0);
        dsp034ProjectileExpireTics.Push(logicalTic + dsp034BurstLifetime[burstIndex]);
        dsp034ProjectileRange.Push(dsp034BurstRange[burstIndex]);
        dsp034ProjectileRadiusMilli.Push(dsp034BurstRadiusMilli[burstIndex]);
        dsp034ProjectileAimYawMilli.Push(snapshot.aimYawMilli);
        dsp034ProjectileRankHash.Push(dsp034BurstRankHash[burstIndex]);
        dsp034ProjectileX.Push(playerX); dsp034ProjectileY.Push(playerY);
        dsp034ProjectileVelocityX.Push(velocityX * double(dsp034BurstSpeed[burstIndex]) / Thinker.TICRATE);
        dsp034ProjectileVelocityY.Push(velocityY * double(dsp034BurstSpeed[burstIndex]) / Thinker.TICRATE);
        dsp034ProjectileTravelled.Push(0.0);
        DSP034ProjectileProxy proxy = DSP034ProjectileProxy(Actor.Spawn(
            "DSP034ProjectileProxy", (playerX, playerY, DSProjectileProxyBase.VISUAL_Z), NO_REPLACE));
        if (proxy != null)
        {
            proxy.logicalEventId = eventId;
            proxy.logicalSystemId = systemId;
        }
        dsp034ProjectileProxies.Push(proxy);
        dsp034EmittedChildren++;
        { if (!dsQuiet) Console.Printf("DS_P034_PROJECTILE event_id=%d parent_event_id=%d tic=%d system_id=%d rank=%d child_ordinal=%d owner_slot=%d owner_generation=%d owner_id=%d weapon_slot=%d weapon_generation=%d weapon_id=%d target_slot=%d target_generation=%d target_id=%d target_policy=%s aim_yaw_milli=%d velocity_x=%.6f velocity_y=%.6f damage_tenths=%d might_milli=%d pierce=%d max_range=%d lifetime_tics=%d radius_milli=%d rank_hash=%d snapshot=1 pitch_input=0", eventId, snapshot.parentEventId, logicalTic, systemId, rank, dsp034BurstChildOrdinals[burstIndex], ownerSlot, ownerGeneration, ownerStableId, dsp034WeaponSlots[weaponIndex], dsp034WeaponGenerations[weaponIndex], dsp034WeaponStableIds[weaponIndex], targetSlot, targetGeneration, targetId, aimed ? "NEAREST_PLANAR" : "VIEW_YAW", aimYawMilli, dsp034ProjectileVelocityX[projectileIndex], dsp034ProjectileVelocityY[projectileIndex], snapshot.damageBase, snapshot.multiplierMilli, snapshot.pierce, dsp034ProjectileRange[projectileIndex], dsp034BurstLifetime[burstIndex], dsp034ProjectileRadiusMilli[projectileIndex], dsp034ProjectileRankHash[projectileIndex]); }
        return true;
    }

    bool DSP034AlreadyCollidedOnSegment(int projectileIndex,
        int slot, int generation, int stableId,
        double startX, double startY, double endX, double endY,
        out double fraction)
    {
        fraction = 0.0;
        double sx = endX - startX; double sy = endY - startY;
        double segmentLengthSquared = sx * sx + sy * sy;
        double t = 0.0;
        if (segmentLengthSquared > 0.000001)
        {
            t = ((x[slot] - startX) * sx + (y[slot] - startY) * sy)
                / segmentLengthSquared;
            if (t < 0.0) t = 0.0;
            if (t > 1.0) t = 1.0;
        }
        double closestX = startX + sx * t;
        double closestY = startY + sy * t;
        double dx = x[slot] - closestX; double dy = y[slot] - closestY;
        double targetRadius = collisionRadii[slot];
        double projectileRadius = double(dsp034ProjectileRadiusMilli[projectileIndex]) / 1000.0;
        double radius = targetRadius + projectileRadius;
        fraction = t;
        return dx * dx + dy * dy <= radius * radius
            && !DSP034HasProjectileHit(dsp034ProjectileEvents[projectileIndex],
                slot, generation, stableId);
    }

    int DSP034FindNextCollision(int projectileIndex, double startX,
        double startY, double endX, double endY, out double hitFraction)
    {
        int bestSlot = -1; int bestGeneration = 0; int bestStable = 0;
        double bestFraction = 2.0;
        DSP024SweptCandidates(startX, startY, endX, endY,
            double(dsp034ProjectileRadiusMilli[projectileIndex]) / 1000.0 + 16.0);
        for (int i = 0; i < spatialCandidateCount; i++)
        {
            int slot = spatialCandidateSlots[i];
            int generation = spatialCandidateGenerations[i];
            int stableId = spatialCandidateIds[i];
            if (!ValidParts(slot, generation, stableId)
                || kinds[slot] != DSP034_TARGET_ENEMY) continue;
            double fraction;
            if (!DSP034AlreadyCollidedOnSegment(projectileIndex, slot,
                    generation, stableId, startX, startY, endX, endY,
                    fraction)) continue;
            bool better = fraction < bestFraction;
            if (fraction == bestFraction)
                better = stableId < bestStable
                    || (stableId == bestStable
                        && (generation < bestGeneration
                            || (generation == bestGeneration && slot < bestSlot)));
            if (better)
            {
                bestFraction = fraction; bestSlot = slot;
                bestGeneration = generation; bestStable = stableId;
            }
        }
        hitFraction = bestFraction;
        return bestSlot;
    }

    void DSP034ProcessProjectile(int index, int logicalTic)
    {
        if (dsp034ProjectileActive[index] == 0) return;
        if (!ValidParts(dsp034ProjectileOwnerSlots[index],
                dsp034ProjectileOwnerGenerations[index],
                dsp034ProjectileOwnerIds[index]))
        {
            DSP034RetireProjectile(index, "OWNER_GENERATION_REPLACED");
            return;
        }
        if (!ValidParts(dsp034ProjectileWeaponSlots[index],
                dsp034ProjectileWeaponGenerations[index],
                dsp034ProjectileWeaponIds[index]))
        {
            DSP034RetireProjectile(index, "WEAPON_GENERATION_REPLACED");
            return;
        }
        // A projectile emitted at tic T with lifetime N receives N complete
        // logical movement steps (T+1 through T+N) before it expires.
        if (logicalTic > dsp034ProjectileExpireTics[index])
        {
            DSP034RetireProjectile(index, "LIFETIME_EXPIRED");
            return;
        }
        double speedX = dsp034ProjectileVelocityX[index];
        double speedY = dsp034ProjectileVelocityY[index];
        double stepLength = sqrt(speedX * speedX + speedY * speedY);
        double remaining = double(dsp034ProjectileRange[index])
            - dsp034ProjectileTravelled[index];
        if (remaining <= 0.000001)
        {
            DSP034RetireProjectile(index, "RANGE_EXPIRED");
            return;
        }
        if (stepLength > remaining)
        {
            double scale = remaining / stepLength;
            speedX *= scale; speedY *= scale; stepLength = remaining;
        }
        double startX = dsp034ProjectileX[index];
        double startY = dsp034ProjectileY[index];
        double endX = startX + speedX; double endY = startY + speedY;
        int hitsThisStep = 0;
        while (dsp034ProjectilePierceUsed[index] < dsp034ProjectilePierce[index])
        {
            double fraction;
            int slot = DSP034FindNextCollision(index, startX, startY,
                endX, endY, fraction);
            if (slot < 0) break;
            int generation = generations[slot]; int stableId = ids[slot];
            DSP034RecordProjectileHit(dsp034ProjectileEvents[index], slot,
                generation, stableId);
            dsp034ProjectilePierceUsed[index]++;
            int damageTenths = 0;
            bool checked = DSP025CheckedDamage(
                dsp034ProjectileDamageTenths[index], 0,
                dsp034ProjectileMightMilli[index], damageTenths);
            bool validDamage = checked && damageTenths >= 0
                && damageTenths <= 20000000;
            int damageMilli = validDamage ? damageTenths * 100 : 0;
            int before; int after; int killed;
            bool applied = validDamage && DSP025ApplyLogicalHit(slot,
                generation, stableId, damageMilli, before, after, killed);
            if (!applied)
            {
                dsp034RejectedHits++;
                { if (!dsQuiet) Console.Printf("DS_P034_HIT event_id=%d tic=%d target_slot=%d target_generation=%d target_id=%d accepted=0 reason=STALE_OR_INVALID_DAMAGE", dsp034ProjectileEvents[index], logicalTic, slot, generation, stableId); }
                continue;
            }
            dsp034AcceptedHits++; hitsThisStep++;
            int acceptedDamageMilli = before - after;
            if (acceptedDamageMilli < 0
                || dsp034AcceptedDamageMilli > 2147483647 - acceptedDamageMilli)
            {
                Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P034_ACCEPTED_DAMAGE_OVERFLOW tic=%d total=%d delta=%d", logicalTic, dsp034AcceptedDamageMilli, acceptedDamageMilli);
            }
            else
                dsp034AcceptedDamageMilli += acceptedDamageMilli;
            { if (!dsQuiet) Console.Printf("DS_P034_HIT event_id=%d parent_event_id=%d tic=%d system_id=%d target_slot=%d target_generation=%d target_id=%d fraction=%.6f damage_tenths=%d might_milli=%d damage_milli=%d before=%d after=%d pierce_used=%d pierce=%d accepted=1 authority=P025_CHECKED_LOGICAL_HIT rank_hash=%d", dsp034ProjectileEvents[index], dsp034ProjectileParents[index], logicalTic, dsp034ProjectileSystems[index], slot, generation, stableId, fraction, dsp034ProjectileDamageTenths[index], dsp034ProjectileMightMilli[index], damageMilli, before, after, dsp034ProjectilePierceUsed[index], dsp034ProjectilePierce[index], dsp034ProjectileRankHash[index]); }
            if (killed != 0) HandleEnemyDeath(slot, before,
                dsp034ProjectileEvents[index]);
        }
        dsp034ProjectileX[index] = endX; dsp034ProjectileY[index] = endY;
        dsp034ProjectileTravelled[index] += stepLength;
        if (dsp034ProjectileProxies[index] != null)
            dsp034ProjectileProxies[index].SetOrigin((endX, endY, DSProjectileProxyBase.VISUAL_Z), true);
        if (dsp034ProjectilePierceUsed[index] >= dsp034ProjectilePierce[index])
            DSP034RetireProjectile(index, "PIERCE_EXHAUSTED");
        else if (dsp034ProjectileTravelled[index]
            >= double(dsp034ProjectileRange[index]) - 0.000001)
            DSP034RetireProjectile(index, "RANGE_EXPIRED");
    }

    void DSP034ProcessAimedTic(int logicalTic, int ownerSlot,
        int ownerGeneration, int ownerStableId, double originX,
        double originY, bool hasViewYaw, int viewYawMilli,
        int cooldownMultiplierMilli, int rankHash)
    {
        if (hasViewYaw)
        {
            dsp034LastViewYawMilli = DSP034NormalizeYawMilli(viewYawMilli);
            dsp034HasViewYaw = true;
        }
        for (int projectile = 0; projectile < dsp034ProjectileActive.Size(); projectile++)
            DSP034ProcessProjectile(projectile, logicalTic);

        // Scheduler order is stable weapon entity ID, independent of the
        // insertion order and of other automatic weapon families.
        int previousStableId = 0;
        for (int ordinal = 0; ordinal < dsp034WeaponSystems.Size(); ordinal++)
        {
            int best = -1; int bestStable = 2147483647;
            for (int i = 0; i < dsp034WeaponSystems.Size(); i++)
            {
                int stable = dsp034WeaponStableIds[i];
                if (stable > previousStableId && stable < bestStable)
                { best = i; bestStable = stable; }
            }
            if (best < 0) break;
            previousStableId = bestStable;
            if (logicalTic * 1000 >= dsp034NextVolleyMilliTics[best])
            {
                int mightMilli = dsp033ResolvedValid
                    && DSP033StatRules.StatApplies(
                    DSP033StatRules.STAT_MIGHT,
                    dsp034WeaponSystems[best])
                    ? DSP033Resolved(DSP033StatRules.STAT_MIGHT) : 1000;
                if (rsActive) mightMilli = RsMightFor(dsp034WeaponSystems[best]);
                if (!DSP034StartVolley(best, logicalTic, mightMilli,
                        cooldownMultiplierMilli, rankHash))
                    dsp034NextVolleyMilliTics[best] = logicalTic * 1000
                        + 1000 * Thinker.TICRATE;
            }
        }
        // Child clocks belong to individual volleys. A new top-level attack
        // can begin before the previous burst's final child without replacing
        // or delaying that immutable child schedule.
        //
        // N2 hang fix: this loop's termination depends on every active
        // burst's remaining-child count strictly decreasing and its interval
        // being positive (both enforced at DSP034StartVolley time today).
        // ReturningProjectileRuntime.zs's identical drain loop already
        // carries an explicit "malformed zero interval spinning forever"
        // guard for this exact loop shape; this one and Ballistic's did not.
        // A bounded drain-iteration counter (independent of *why* a future
        // row/state bug might stall progress) plus the same zero-interval
        // guard make this loop provably terminating instead of relying on
        // every upstream caller staying perfectly well-formed forever.
        int drainIterations = 0;
        while (true)
        {
            if (++drainIterations > DSP034_MAX_BURST_DRAIN_ITERATIONS_PER_TIC)
            {
                Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P034_BURST_DRAIN_RUNAWAY tic=%d iterations=%d classification=N2_DISPATCHER", logicalTic, drainIterations);
                for (int burst = 0; burst < dsp034BurstActive.Size(); burst++)
                    dsp034BurstActive[burst] = 0;
                break;
            }
            int bestBurst = -1;
            int bestWeaponStable = 2147483647;
            int bestVolleyId = 2147483647;
            for (int burst = 0; burst < dsp034BurstActive.Size(); burst++)
            {
                if (dsp034BurstActive[burst] == 0
                    || dsp034BurstRemainingChildren[burst] <= 0
                    || logicalTic * 1000 < dsp034BurstNextChildMilliTics[burst]) continue;
                int weaponIndex = dsp034BurstWeaponIndexes[burst];
                if (weaponIndex < 0 || weaponIndex >= dsp034WeaponSystems.Size()) continue;
                int stable = dsp034WeaponStableIds[weaponIndex];
                int volley = dsp034BurstVolleyIds[burst];
                if (stable < bestWeaponStable
                    || (stable == bestWeaponStable && volley < bestVolleyId))
                {
                    bestBurst = burst;
                    bestWeaponStable = stable;
                    bestVolleyId = volley;
                }
            }
            if (bestBurst < 0) break;
            DSP034SpawnChild(bestBurst, logicalTic, ownerSlot,
                ownerGeneration, ownerStableId, hasViewYaw, viewYawMilli);
            dsp034BurstChildOrdinals[bestBurst]++;
            dsp034BurstRemainingChildren[bestBurst]--;
            dsp034BurstNextChildMilliTics[bestBurst] +=
                dsp034BurstIntervalMillis[bestBurst] * Thinker.TICRATE;
            if (dsp034BurstRemainingChildren[bestBurst] <= 0)
            {
                dsp034BurstActive[bestBurst] = 0;
                { if (!dsQuiet) Console.Printf("DS_P034_BURST_COMPLETE volley_id=%d tic=%d system_id=%d children=%d", dsp034BurstVolleyIds[bestBurst], logicalTic, dsp034WeaponSystems[dsp034BurstWeaponIndexes[bestBurst]], dsp034BurstAmount[bestBurst]); }
            }
            // Defense in depth: DSP034StartVolley already rejects a
            // childIntervalMillis <= 0 row, but if that guard is ever bypassed
            // (or the row table changes), a zero/negative interval would leave
            // dsp034BurstNextChildMilliTics unadvanced forever while
            // remainingChildren stays > 0 -- spinning this loop indefinitely.
            if (dsp034BurstIntervalMillis[bestBurst] <= 0)
            {
                { if (!dsQuiet) Console.Printf("DS_P034_BURST_MALFORMED tic=%d burst=%d interval_millis=%d action=DEACTIVATED", logicalTic, bestBurst, dsp034BurstIntervalMillis[bestBurst]); }
                dsp034BurstActive[bestBurst] = 0;
            }
        }
        // `originX/Y` are explicit inputs so the adapter remains independent
        // of eye position and only ever reads the caller's logical body pose.
        if (originX != playerX || originY != playerY)
            { if (!dsQuiet) Console.Printf("DS_P034_ORIGIN_DIAGNOSTIC tic=%d supplied_x=%.3f supplied_y=%.3f logical_x=%.3f logical_y=%.3f", logicalTic, originX, originY, playerX, playerY); }
    }

    int DSP034HashMix(int hash, int value)
    {
        int normalized = value % 1000003;
        if (normalized < 0) normalized += 1000003;
        return (hash * 31 + normalized) % 1000003;
    }

    int DSP034HashMixDoubleMilli(int hash, double value)
    {
        int quantized;
        if (value >= 2000000.0) quantized = 2000000000;
        else if (value <= -2000000.0) quantized = -2000000000;
        else quantized = int(value * 1000.0);
        return DSP034HashMix(hash, quantized);
    }

    int DSP034HashWeaponState(int hash, int i)
    {
        hash = DSP034HashMix(hash, dsp034WeaponSystems[i]);
        hash = DSP034HashMix(hash, dsp034WeaponRanks[i]);
        hash = DSP034HashMix(hash, dsp034WeaponSlots[i]);
        hash = DSP034HashMix(hash, dsp034WeaponGenerations[i]);
        hash = DSP034HashMix(hash, dsp034WeaponStableIds[i]);
        hash = DSP034HashMix(hash, dsp034NextVolleyMilliTics[i]);
        return hash;
    }

    int DSP034HashBurstState(int hash, int i)
    {
        hash = DSP034HashMix(hash, dsp034BurstActive[i]);
        if (dsp034BurstActive[i] == 0) return hash;
        hash = DSP034HashMix(hash, dsp034BurstWeaponIndexes[i]);
        hash = DSP034HashMix(hash, dsp034BurstVolleyIds[i]);
        hash = DSP034HashMix(hash, dsp034BurstNextChildMilliTics[i]);
        hash = DSP034HashMix(hash, dsp034BurstRemainingChildren[i]);
        hash = DSP034HashMix(hash, dsp034BurstChildOrdinals[i]);
        hash = DSP034HashMix(hash, dsp034BurstDamageTenths[i]);
        hash = DSP034HashMix(hash, dsp034BurstAmount[i]);
        hash = DSP034HashMix(hash, dsp034BurstPierce[i]);
        hash = DSP034HashMix(hash, dsp034BurstIntervalMillis[i]);
        hash = DSP034HashMix(hash, dsp034BurstSpeed[i]);
        hash = DSP034HashMix(hash, dsp034BurstRange[i]);
        hash = DSP034HashMix(hash, dsp034BurstLifetime[i]);
        hash = DSP034HashMix(hash, dsp034BurstRadiusMilli[i]);
        hash = DSP034HashMix(hash, dsp034BurstPoolLimit[i]);
        hash = DSP034HashMix(hash, dsp034BurstMightMilli[i]);
        hash = DSP034HashMix(hash, dsp034BurstCooldownMillis[i]);
        hash = DSP034HashMix(hash, dsp034BurstRankHash[i]);
        return hash;
    }

    int DSP034HashProjectileState(int hash, int i)
    {
        hash = DSP034HashMix(hash, dsp034ProjectileActive[i]);
        if (dsp034ProjectileActive[i] == 0) return hash;
        hash = DSP034HashMix(hash, dsp034ProjectileEvents[i]);
        hash = DSP034HashMix(hash, dsp034ProjectileParents[i]);
        hash = DSP034HashMix(hash, dsp034ProjectileSystems[i]);
        hash = DSP034HashMix(hash, dsp034ProjectileRanks[i]);
        hash = DSP034HashMix(hash, dsp034ProjectileWeaponSlots[i]);
        hash = DSP034HashMix(hash, dsp034ProjectileWeaponGenerations[i]);
        hash = DSP034HashMix(hash, dsp034ProjectileWeaponIds[i]);
        hash = DSP034HashMix(hash, dsp034ProjectileOwnerSlots[i]);
        hash = DSP034HashMix(hash, dsp034ProjectileOwnerGenerations[i]);
        hash = DSP034HashMix(hash, dsp034ProjectileOwnerIds[i]);
        hash = DSP034HashMix(hash, dsp034ProjectileTargetSlots[i]);
        hash = DSP034HashMix(hash, dsp034ProjectileTargetGenerations[i]);
        hash = DSP034HashMix(hash, dsp034ProjectileTargetIds[i]);
        hash = DSP034HashMix(hash, dsp034ProjectileDamageTenths[i]);
        hash = DSP034HashMix(hash, dsp034ProjectileMightMilli[i]);
        hash = DSP034HashMix(hash, dsp034ProjectilePierce[i]);
        hash = DSP034HashMix(hash, dsp034ProjectilePierceUsed[i]);
        hash = DSP034HashMix(hash, dsp034ProjectileExpireTics[i]);
        hash = DSP034HashMix(hash, dsp034ProjectileRange[i]);
        hash = DSP034HashMix(hash, dsp034ProjectileRadiusMilli[i]);
        hash = DSP034HashMix(hash, dsp034ProjectileAimYawMilli[i]);
        hash = DSP034HashMix(hash, dsp034ProjectileRankHash[i]);
        hash = dsp034HashMixDoubleMilli(hash, dsp034ProjectileX[i]);
        hash = dsp034HashMixDoubleMilli(hash, dsp034ProjectileY[i]);
        hash = dsp034HashMixDoubleMilli(hash, dsp034ProjectileVelocityX[i]);
        hash = dsp034HashMixDoubleMilli(hash, dsp034ProjectileVelocityY[i]);
        hash = dsp034HashMixDoubleMilli(hash, dsp034ProjectileTravelled[i]);
        return hash;
    }

    int DSP034HashLedgerState(int hash, int i)
    {
        hash = DSP034HashMix(hash, dsp034HitProjectileEvents[i]);
        hash = DSP034HashMix(hash, dsp034HitTargetSlots[i]);
        hash = DSP034HashMix(hash, dsp034HitTargetGenerations[i]);
        hash = DSP034HashMix(hash, dsp034HitTargetIds[i]);
        return hash;
    }

    int DSP034AimedStateHash()
    {
        int hash = 23;
        hash = DSP034HashMix(hash, dsp034EventOrdinal);
        hash = DSP034HashMix(hash, dsp034VolleyOrdinal);
        hash = DSP034HashMix(hash, dsp034LastViewYawMilli);
        hash = DSP034HashMix(hash, dsp034HasViewYaw ? 1 : 0);
        hash = DSP034HashMix(hash, dsp034EmittedChildren);
        hash = DSP034HashMix(hash, dsp034SkippedChildren);
        hash = DSP034HashMix(hash, dsp034AcceptedHits);
        hash = DSP034HashMix(hash, dsp034RejectedHits);
        hash = DSP034HashMix(hash, dsp034AcceptedDamageMilli);
        hash = DSP034HashMix(hash, dsp034WeaponSystems.Size());
        hash = DSP034HashMix(hash, dsp034BurstActive.Size());
        hash = DSP034HashMix(hash, dsp034ProjectileActive.Size());
        hash = DSP034HashMix(hash, dsp034HitProjectileEvents.Size());
        for (int i = 0; i < dsp034WeaponSystems.Size(); i++)
            hash = DSP034HashWeaponState(hash, i);
        for (int i = 0; i < dsp034BurstActive.Size(); i++)
            hash = DSP034HashBurstState(hash, i);
        for (int i = 0; i < dsp034ProjectileActive.Size(); i++)
            hash = DSP034HashProjectileState(hash, i);
        for (int i = 0; i < dsp034HitProjectileEvents.Size(); i++)
            hash = DSP034HashLedgerState(hash, i);
        return hash;
    }
}
