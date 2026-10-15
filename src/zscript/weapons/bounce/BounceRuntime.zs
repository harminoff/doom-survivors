// P041 ricochet projectile runtime: Runetracer/NO FUTURE, Bone, Cherry Bomb
// and Carréllo. Implements docs/contracts/bounce-projectiles.md exactly:
// a moving logical-reference-v1 boundary, swept multi-reflection with a
// corner rule and deterministic ordering, logical walls, data-driven pierce
// vs enemy-bounce policy, per-pair hit delays, Cherry deceleration/explosion,
// Carréllo facing launch + bounce budget, and NO FUTURE player-hit
// explosions gated once per 18 ticks. All geometry is adapter-owned; native
// Doom projectile motion/collision is presentation-only and disabled.
class DSP041BounceProxy : DSProjectileProxyBase
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
        Scale 0.06;
    }

    States
    {
    Spawn:
        BILL A 1 Bright;
        Loop;
    }
}

mixin class DSP041Bounce
{
    const DSP041_EVENT_BASE = 4100000;
    const DSP041_TARGET_ENEMY = 1;
    const DSP041_MAX_ACTIVE = 128;
    // See DSP041SpawnProjectile: substitute duration for a budget-driven
    // (not duration-driven) system, i.e. Carréllo, whose row DurationTics is
    // "not applicable" (0). Far larger than any pool/finishAtTic fixture
    // window in practice; the bounce-budget check still ends the projectile
    // first, so this sentinel is never actually reached by AgeTics.
    const DSP041_UNBOUNDED_DURATION_TICS = 999999;

    // Weapon (equipped-slot) schedule state, one row per equipped bounce
    // weapon fixture.
    Array<int> dsp041WeaponSystems;
    Array<int> dsp041WeaponRanks;
    Array<int> dsp041WeaponSlots;
    Array<int> dsp041WeaponGenerations;
    Array<int> dsp041WeaponIds;
    Array<int> dsp041NextVolleyTics;

    // Live projectile state. Position/velocity/age/bounce-count/deceleration
    // are the exact persisted-and-hashed fields per contract.
    Array<int> dsp041Active;
    Array<int> dsp041Events;
    Array<int> dsp041Systems;
    Array<int> dsp041Ranks;
    Array<int> dsp041WeaponSlotOf;
    Array<int> dsp041WeaponGenerationOf;
    Array<int> dsp041WeaponIdOf;
    Array<int> dsp041OwnerSlotOf;
    Array<int> dsp041OwnerGenerationOf;
    Array<int> dsp041OwnerIdOf;
    Array<double> dsp041X;
    Array<double> dsp041Y;
    Array<double> dsp041DirX;
    Array<double> dsp041DirY;
    Array<double> dsp041SpeedUnitsPerSecond;
    Array<double> dsp041SpeedInitialUnitsPerSecond;
    Array<int> dsp041AgeTics;
    Array<int> dsp041DurationTics;
    Array<int> dsp041DamageMilli;
    Array<int> dsp041MightMilli;
    Array<int> dsp041AreaMilli;
    Array<int> dsp041ContactRadiusUnitsMilli;
    Array<int> dsp041BounceBudgetRemaining;
    Array<int> dsp041BounceCount;
    Array<int> dsp041HitCount;
    Array<int> dsp041ExplosionChanceMilli;
    Array<int> dsp041ExplosionRadiusUnitsMilli;
    Array<int> dsp041Stopped;
    Array<int> dsp041Exploded;
    // Normal play: explosions queued during the projectile pass (No Future
    // bounces, Cherry Bomb / Yatta child bombs, Profusione hits) and resolved
    // after it, so they never disturb a candidate list mid-iteration.
    Array<int> dsp041QueuedIndex; Array<double> dsp041QueuedX; Array<double> dsp041QueuedY;
    Array<int> dsp041QueuedRadius; Array<int> dsp041QueuedDamage; Array<String> dsp041QueuedKind;
    Array<int> dsp041PiercesEnemies;
    Array<int> dsp041BouncesOffEnemies;
    Array<DSP041BounceProxy> dsp041Proxies;

    // Per-pair hit ledger: same projectile/target pair cannot re-trigger
    // within HitDelayTics. Stored as a ready tic rather than a one-shot flag
    // so a pierce weapon can hit the same enemy again after the delay.
    Array<int> dsp041PairEvents;
    Array<int> dsp041PairSlots;
    Array<int> dsp041PairGenerations;
    Array<int> dsp041PairIds;
    Array<int> dsp041PairReadyTic;

    // Logical wall segments, shared with the boundary/enemy reflection sweep.
    Array<int> dsp041WallIds;
    Array<double> dsp041WallStartX;
    Array<double> dsp041WallStartY;
    Array<double> dsp041WallEndX;
    Array<double> dsp041WallEndY;

    int dsp041EventOrdinal;
    int dsp041EmittedProjectiles;
    int dsp041SkippedProjectiles;
    int dsp041AcceptedHits;
    int dsp041RejectedHits;
    // Accepted-damage ledger, matching every other checked-hit family's own
    // accumulator (e.g. GlobalRuntime.zs's dsp040AcceptedDamageMilli): the
    // true (health-before minus health-after) delta, not the raw computed
    // `amount`, exactly like that precedent -- an already-low-health target
    // can absorb less than the nominal hit. VerticalSlice's own
    // ProcessP041BounceWeapons reads this accumulator's delta each tic to
    // credit its run-level damageDealt ledger exactly once.
    int dsp041AcceptedDamageMilli;
    int dsp041ReflectionsThisTic;
    int dsp041NoFutureGateReadyTic;
    int dsp041NoFutureExplosionOrdinal;

    void DSP041ResetLogicalWalls()
    {
        dsp041WallIds.Clear();
        dsp041WallStartX.Clear(); dsp041WallStartY.Clear();
        dsp041WallEndX.Clear(); dsp041WallEndY.Clear();
    }

    bool DSP041AddLogicalWall(int stableId, double startX, double startY,
        double endX, double endY)
    {
        if (stableId <= 0 || (startX == endX && startY == endY)) return false;
        for (int i = 0; i < dsp041WallIds.Size(); i++)
            if (dsp041WallIds[i] == stableId) return false;
        dsp041WallIds.Push(stableId);
        dsp041WallStartX.Push(startX); dsp041WallStartY.Push(startY);
        dsp041WallEndX.Push(endX); dsp041WallEndY.Push(endY);
        return true;
    }

    void DSP041ResetBounceRuntime(int seed)
    {
        for (int i = 0; i < dsp041Proxies.Size(); i++)
            if (dsp041Proxies[i] != null) dsp041Proxies[i].Destroy();

        dsp041WeaponSystems.Clear(); dsp041WeaponRanks.Clear();
        dsp041WeaponSlots.Clear(); dsp041WeaponGenerations.Clear();
        dsp041WeaponIds.Clear(); dsp041NextVolleyTics.Clear();
        dsp041Active.Clear(); dsp041Events.Clear(); dsp041Systems.Clear();
        dsp041QueuedIndex.Clear(); dsp041QueuedX.Clear(); dsp041QueuedY.Clear();
        dsp041QueuedRadius.Clear(); dsp041QueuedDamage.Clear(); dsp041QueuedKind.Clear();
        dsp041Ranks.Clear(); dsp041WeaponSlotOf.Clear();
        dsp041WeaponGenerationOf.Clear(); dsp041WeaponIdOf.Clear();
        dsp041OwnerSlotOf.Clear(); dsp041OwnerGenerationOf.Clear();
        dsp041OwnerIdOf.Clear(); dsp041X.Clear(); dsp041Y.Clear();
        dsp041DirX.Clear(); dsp041DirY.Clear();
        dsp041SpeedUnitsPerSecond.Clear();
        dsp041SpeedInitialUnitsPerSecond.Clear();
        dsp041AgeTics.Clear(); dsp041DurationTics.Clear();
        dsp041DamageMilli.Clear(); dsp041MightMilli.Clear();
        dsp041AreaMilli.Clear(); dsp041ContactRadiusUnitsMilli.Clear();
        dsp041BounceBudgetRemaining.Clear(); dsp041BounceCount.Clear();
        dsp041HitCount.Clear(); dsp041ExplosionChanceMilli.Clear();
        dsp041ExplosionRadiusUnitsMilli.Clear(); dsp041Stopped.Clear();
        dsp041Exploded.Clear(); dsp041PiercesEnemies.Clear();
        dsp041BouncesOffEnemies.Clear(); dsp041Proxies.Clear();
        dsp041PairEvents.Clear(); dsp041PairSlots.Clear();
        dsp041PairGenerations.Clear(); dsp041PairIds.Clear();
        dsp041PairReadyTic.Clear();
        DSP041ResetLogicalWalls();
        DSP041ResetBounceTargeting(seed);
        dsp041EventOrdinal = 0; dsp041EmittedProjectiles = 0;
        dsp041SkippedProjectiles = 0; dsp041AcceptedHits = 0;
        dsp041RejectedHits = 0; dsp041AcceptedDamageMilli = 0;
        dsp041NoFutureGateReadyTic = 0;
        dsp041NoFutureExplosionOrdinal = 0;
        { if (!dsQuiet) Console.Printf("DS_P041_RUNTIME_RESET seed=%d rng_stream=DEDICATED_P041_BOUNCE_XORSHIFT boundary=LOGICAL_REFERENCE_V1_MOVING walls=LOGICAL_FIXTURES native_projectiles=VISUAL_ONLY", seed); }
    }

    int DSP041NewEventId()
    {
        dsp041EventOrdinal++;
        return DSP041_EVENT_BASE + dsp041EventOrdinal;
    }

    bool DSP041EquipFixture(int systemId, int rank, int weaponSlot,
        int firstFireTic)
    {
        if (DSP041BounceRows.RankCount(systemId) < rank || rank < 1
            || weaponSlot < 0 || weaponSlot >= lifeStates.Size()
            || lifeStates[weaponSlot] != STORE_ALIVE || firstFireTic < 0)
            return false;
        dsp041WeaponSystems.Push(systemId);
        dsp041WeaponRanks.Push(rank);
        dsp041WeaponSlots.Push(weaponSlot);
        dsp041WeaponGenerations.Push(generations[weaponSlot]);
        dsp041WeaponIds.Push(ids[weaponSlot]);
        dsp041NextVolleyTics.Push(firstFireTic);
        { if (!dsQuiet) Console.Printf("DS_P041_EQUIP accepted=1 system_id=%d rank=%d weapon_slot=%d weapon_generation=%d weapon_id=%d first_fire_tic=%d classification=CONTROLLED_MAP16_FIXTURE source_inventory_claim=0", systemId, rank, weaponSlot, generations[weaponSlot], ids[weaponSlot], firstFireTic); }
        return true;
    }

    bool DSP041TransformFixture(int weaponIndex, int evolvedSystemId,
        int evolvedRank, int dependencyItem, int dependencyRank,
        int logicalTic)
    {
        if (weaponIndex < 0 || weaponIndex >= dsp041WeaponSystems.Size())
            return false;
        int expectedEvolved;
        if (!DSP041BounceRows.TryGetEvolution(dsp041WeaponSystems[weaponIndex],
                dsp041WeaponRanks[weaponIndex], dependencyItem, expectedEvolved)
            || expectedEvolved != evolvedSystemId
            || DSP041BounceRows.RankCount(evolvedSystemId) < evolvedRank
            || evolvedRank < 1) return false;
        int oldSystem = dsp041WeaponSystems[weaponIndex];
        int oldRank = dsp041WeaponRanks[weaponIndex];
        dsp041WeaponSystems[weaponIndex] = evolvedSystemId;
        dsp041WeaponRanks[weaponIndex] = evolvedRank;
        { if (!dsQuiet) Console.Printf("DS_P041_TRANSFORM accepted=1 tic=%d source_system_id=%d source_rank=%d evolved_system_id=%d evolved_rank=%d dependency_item=%d dependency_rank=%d weapon_id=%d classification=CONTROLLED_MAP16_FIXTURE", logicalTic, oldSystem, oldRank, evolvedSystemId, evolvedRank, dependencyItem, dependencyRank, dsp041WeaponIds[weaponIndex]); }
        return true;
    }

    // N2 dispatcher rank-change API (docs/contracts/normal-play-integration.md
    // "Weapon dispatcher"). weaponSlot+systemId keyed, matching the other
    // engines' SetFixtureRank shape; leaves Equip/TransformFixture untouched.
    bool DSP041SetFixtureRank(int weaponSlot, int systemId, int rank)
    {
        if (DSP041BounceRows.RankCount(systemId) < rank || rank < 1) return false;
        for (int i = 0; i < dsp041WeaponSystems.Size(); i++)
        {
            if (dsp041WeaponSlots[i] != weaponSlot) continue;
            if (dsp041WeaponSystems[i] != systemId) return false;
            int oldRank = dsp041WeaponRanks[i];
            dsp041WeaponRanks[i] = rank;
            { if (!dsQuiet) Console.Printf("DS_N2_BOUNCE_FIXTURE_RANK accepted=1 system_id=%d prior_rank=%d rank=%d weapon_id=%d weapon_generation=%d classification=N2_DISPATCHER_RANK_CHANGE", systemId, oldRank, rank, dsp041WeaponIds[i], dsp041WeaponGenerations[i]); }
            return true;
        }
        return false;
    }

    int DSP041ActiveCount(int systemId)
    {
        int count = 0;
        for (int i = 0; i < dsp041Active.Size(); i++)
            if (dsp041Active[i] != 0 && dsp041Systems[i] == systemId) count++;
        return count;
    }

    // Launches every Amount of the equipped rank at once. Runetracer/Bone
    // draw a fresh direction from the dedicated stream per contract; Carréllo
    // launches along the supplied body-facing yaw (mapped to the logical
    // plane, as Knife in P034); the label on this reading is preserved here.
    // useExplicitYaw/explicitYawMilli: fixture-only CONTROLLED_LAUNCH
    // override (docs/contracts/bounce-projectiles.md fixture policy). When
    // true, every spawned projectile in this volley uses explicitYawMilli
    // verbatim instead of drawing from the dedicated P041_BOUNCE stream
    // (Runetracer/Bone) or the supplied body-facing yaw (Carréllo). Default
    // false leaves production behavior (the P041_BOUNCE draw) untouched;
    // no production call site passes these extra arguments.
    bool DSP041FireVolley(int weaponIndex, int logicalTic, int facingYawMilli,
        int cooldownMultiplierMilli, int luckMilli,
        bool useExplicitYaw = false, int explicitYawMilli = 0)
    {
        if (weaponIndex < 0 || weaponIndex >= dsp041WeaponSystems.Size()
            || !ValidParts(dsp041WeaponSlots[weaponIndex],
                dsp041WeaponGenerations[weaponIndex],
                dsp041WeaponIds[weaponIndex])) return false;
        if (logicalTic < dsp041NextVolleyTics[weaponIndex]) return false;

        int systemId = dsp041WeaponSystems[weaponIndex];
        int rank = dsp041WeaponRanks[weaponIndex];
        int amount = DSP041BounceRows.Amount(systemId, rank);
        int cooldownTics = DSP041BounceRows.CooldownTics(systemId, rank);
        int adjustedCooldown = DSP033StatRules.CooldownAfterTome(systemId,
            cooldownTics * 1000 / Thinker.TICRATE, cooldownMultiplierMilli)
            * Thinker.TICRATE / 1000;
        // Celestial Dusting / Profusione D'Amore: half cooldown while moving.
        if (rsActive && (systemId == DSN3Rows.SYSTEM_CELESTIAL_DUSTING || systemId == DSN3Rows.SYSTEM_PROFUSIONE_DAMORE)
            && DSP030VerticalSlice(self) != null && DSP030VerticalSlice(self).PlayerMoving())
            adjustedCooldown /= 2;
        if (adjustedCooldown < 1) adjustedCooldown = 1;
        if (amount <= 0 || cooldownTics <= 0) return false;
        if (rsActive) amount += RsAmountFor(systemId);
        dsp041NextVolleyTics[weaponIndex] = logicalTic + adjustedCooldown;

        int mightMilli = DSP033StatRules.StatApplies(DSP033StatRules.STAT_MIGHT,
                systemId) && dsp033ResolvedValid
            ? DSP033Resolved(DSP033StatRules.STAT_MIGHT) : 1000;
        if (rsActive) mightMilli = RsMightFor(systemId);
        int childIntervalTics = DSP041BounceRows.ChildIntervalTics(systemId, rank);
        if (childIntervalTics < 0) childIntervalTics = 0;
        for (int ordinal = 0; ordinal < amount; ordinal++)
        {
            int fireTic = logicalTic + ordinal * childIntervalTics;
            DSP041SpawnProjectile(weaponIndex, fireTic, ordinal, facingYawMilli,
                mightMilli, luckMilli, useExplicitYaw, explicitYawMilli);
        }
        return true;
    }

    // useExplicitYaw/explicitYawMilli: see DSP041FireVolley above. Fixture
    // only; defaults preserve the production draw/facing behavior exactly.
    bool DSP041SpawnProjectile(int weaponIndex, int logicalTic, int ordinal,
        int facingYawMilli, int mightMilli, int luckMilli,
        bool useExplicitYaw = false, int explicitYawMilli = 0)
    {
        int systemId = dsp041WeaponSystems[weaponIndex];
        int rank = dsp041WeaponRanks[weaponIndex];
        if (DSP041ActiveCount(systemId) >= DSP041_MAX_ACTIVE)
        {
            dsp041SkippedProjectiles++;
            Console.Printf("DS_P041_SPAWN_SKIP tic=%d system_id=%d reason=POOL_FULL", logicalTic, systemId);
            return false;
        }

        int damageMilli = DSP041BounceRows.DamageMilli(systemId, rank);
        int areaMilli = DSP041BounceRows.AreaMilli(systemId, rank);
        int speedMilli = DSP041BounceRows.SpeedMilli(systemId, rank)
            * (rsActive ? RsSpeedFor(systemId) : 1000) / 1000;
        int bounceBudget = DSP041BounceRows.BounceBudget(systemId, rank);
        // DSP041BounceRows.DurationTics returns 0 ("not applicable") for
        // Carréllo (contract: its lifetime is bounded by BounceBudget, not a
        // reported Duration). A bounded BounceBudget (>=0, i.e. not the
        // Runetracer/NO FUTURE/Bone/Cherry -1 "unlimited" sentinel) with a
        // "not applicable" duration means budget-driven, not duration-driven,
        // expiry -- substitute an effectively-unbounded duration so
        // DSP041ProcessProjectile's AgeTics>=DurationTics check never fires
        // first; DSP041AdvanceTic's own bounce-budget-exhausted retirement
        // (see below) still ends it exactly when the contract says to.
        int rawDurationTics = DSP041BounceRows.DurationTics(systemId, rank)
            * (rsActive ? RsDurationFor(systemId) : 1000) / 1000;
        bool durationNotApplicable = rawDurationTics <= 0 && bounceBudget >= 0;
        int durationTics = durationNotApplicable
            ? DSP041_UNBOUNDED_DURATION_TICS : rawDurationTics;
        int contactRadiusMilli = DSP041BounceRows.ContactRadiusMilliUnits(systemId, rank)
            * (rsActive ? RsAreaFor(systemId) : 1000) / 1000;
        int explosionChanceMilli = DSP041BounceRows.ExplosionChanceMilli(systemId, rank);
        int explosionRadiusMilli = DSP041BounceRows.ExplosionRadiusMilliUnits(systemId, rank)
            * (rsActive ? RsAreaFor(systemId) : 1000) / 1000;
        if (damageMilli <= 0 || areaMilli <= 0 || speedMilli <= 0
            || durationTics <= 0 || contactRadiusMilli <= 0)
        {
            dsp041SkippedProjectiles++;
            Console.Printf("DS_P041_SPAWN_SKIP tic=%d system_id=%d reason=INVALID_ROW", logicalTic, systemId);
            return false;
        }

        int aimYaw; int rngBefore; int rngAfter; String launchRule;
        // N3 Track A: Carrozza! (evolved Carréllo) reuses the same
        // body-facing launch rule as its base weapon.
        bool isCarrello = systemId == DSP041BounceRows.SYSTEM_CARRELLO
            || systemId == DSN3Rows.SYSTEM_CARROZZA;
        if (useExplicitYaw)
        {
            // CONTROLLED_LAUNCH: fixture-only, labelled override (see
            // DSP041FireVolley). Never taken by production call sites.
            aimYaw = DSP041NormalizeYawMilli(explicitYawMilli);
            rngBefore = dsp041BounceRng; rngAfter = dsp041BounceRng;
            launchRule = "CONTROLLED_LAUNCH";
        }
        else if (isCarrello)
        {
            aimYaw = DSP041NormalizeYawMilli(facingYawMilli);
            rngBefore = dsp041BounceRng; rngAfter = dsp041BounceRng;
            launchRule = "BODY_FACING_LOGICAL";
        }
        else
        {
            aimYaw = DSP041DrawInitialYawMilli(rngBefore, rngAfter);
            launchRule = "DEDICATED_STREAM_LABELLED";
        }

        double dirX; double dirY;
        DSP041YawDirection(aimYaw, dirX, dirY);
        double speedUnitsPerSecond = double(DSP041BounceRows.BASE_SPEED_UNITS_PER_SECOND)
            * double(speedMilli) / 1000.0;

        int eventId = DSP041NewEventId();
        int index = dsp041Active.Size();
        dsp041Active.Push(1); dsp041Events.Push(eventId);
        dsp041Systems.Push(systemId); dsp041Ranks.Push(rank);
        dsp041WeaponSlotOf.Push(dsp041WeaponSlots[weaponIndex]);
        dsp041WeaponGenerationOf.Push(dsp041WeaponGenerations[weaponIndex]);
        dsp041WeaponIdOf.Push(dsp041WeaponIds[weaponIndex]);
        dsp041OwnerSlotOf.Push(playerSlot);
        dsp041OwnerGenerationOf.Push(generations[playerSlot]);
        dsp041OwnerIdOf.Push(ids[playerSlot]);
        dsp041X.Push(playerX); dsp041Y.Push(playerY);
        dsp041DirX.Push(dirX); dsp041DirY.Push(dirY);
        dsp041SpeedUnitsPerSecond.Push(speedUnitsPerSecond);
        dsp041SpeedInitialUnitsPerSecond.Push(speedUnitsPerSecond);
        dsp041AgeTics.Push(0); dsp041DurationTics.Push(durationTics);
        dsp041DamageMilli.Push(damageMilli); dsp041MightMilli.Push(mightMilli);
        dsp041AreaMilli.Push(areaMilli);
        // contactRadiusMilli (DSP041BounceRows.ContactRadiusMilliUnits) is
        // already Area-scaled by the rows layer; do not rescale here.
        dsp041ContactRadiusUnitsMilli.Push(contactRadiusMilli);
        dsp041BounceBudgetRemaining.Push(bounceBudget);
        dsp041BounceCount.Push(0); dsp041HitCount.Push(0);
        dsp041ExplosionChanceMilli.Push(explosionChanceMilli);
        dsp041ExplosionRadiusUnitsMilli.Push(explosionRadiusMilli);
        dsp041Stopped.Push(0); dsp041Exploded.Push(0);
        dsp041PiercesEnemies.Push(DSP041BounceRows.PiercesEnemies(systemId) ? 1 : 0);
        dsp041BouncesOffEnemies.Push(DSP041BounceRows.BouncesOffEnemies(systemId) ? 1 : 0);
        DSP041BounceProxy proxy = DSP041BounceProxy(Actor.Spawn(
            "DSP041BounceProxy", (playerX, playerY, DSProjectileProxyBase.VISUAL_Z), NO_REPLACE));
        if (proxy != null)
        {
            proxy.logicalEventId = eventId;
            proxy.logicalSystemId = systemId;
        }
        dsp041Proxies.Push(proxy);
        dsp041EmittedProjectiles++;
        { if (!dsQuiet) Console.Printf("DS_P041_PROJECTILE event_id=%d tic=%d system_id=%d rank=%d ordinal=%d aim_yaw_milli=%d speed_ups=%.6f damage_milli=%d might_milli=%d area_milli=%d contact_radius_milli=%d bounce_budget=%d duration_tics=%d pierces_enemies=%d bounces_off_enemies=%d rng_before=%d rng_after=%d rng_stream=DEDICATED_P041_BOUNCE launch_rule=%s native_motion=VISUAL_ONLY", eventId, logicalTic, systemId, rank, ordinal, aimYaw, speedUnitsPerSecond, damageMilli, mightMilli, areaMilli, dsp041ContactRadiusUnitsMilli[index], bounceBudget, durationTics, dsp041PiercesEnemies[index], dsp041BouncesOffEnemies[index], rngBefore, rngAfter, launchRule); }
        return true;
    }

    // ---- Boundary and wall geometry -------------------------------------

    void DSP041CurrentBoundary(out double minX, out double maxX,
        out double minY, out double maxY)
    {
        minX = playerX - double(DSP041BounceRows.BOUNDARY_HALF_EXTENT);
        maxX = playerX + double(DSP041BounceRows.BOUNDARY_HALF_EXTENT);
        minY = playerY - double(DSP041BounceRows.BOUNDARY_HALF_EXTENT);
        maxY = playerY + double(DSP041BounceRows.BOUNDARY_HALF_EXTENT);
    }

    // Finds the earliest fraction in [0,1] at which the swept segment leaves
    // the moving boundary rectangle. axisX/axisY report whether that axis's
    // side was crossed (both true is the exact-corner case).
    bool DSP041BoundaryCrossing(double startX, double startY,
        double endX, double endY, out double fraction, out bool axisX,
        out bool axisY)
    {
        fraction = 2.0; axisX = false; axisY = false;
        double minX; double maxX; double minY; double maxY;
        DSP041CurrentBoundary(minX, maxX, minY, maxY);
        double dx = endX - startX; double dy = endY - startY;
        double fx = 2.0;
        if (dx > 0.0000001) fx = (maxX - startX) / dx;
        else if (dx < -0.0000001) fx = (minX - startX) / dx;
        double fy = 2.0;
        if (dy > 0.0000001) fy = (maxY - startY) / dy;
        else if (dy < -0.0000001) fy = (minY - startY) / dy;
        if (fx < 0.0 || fx > 1.0) fx = 2.0;
        if (fy < 0.0 || fy > 1.0) fy = 2.0;
        if (fx >= 2.0 && fy >= 2.0) return false;
        double best = fx < fy ? fx : fy;
        fraction = best;
        double epsilon = 0.0000001;
        axisX = fx <= best + epsilon && fx < 2.0;
        axisY = fy <= best + epsilon && fy < 2.0;
        return true;
    }

    bool DSP041LineIntersection(double startX, double startY,
        double endX, double endY, double wallStartX, double wallStartY,
        double wallEndX, double wallEndY, out double fraction)
    {
        fraction = 0.0;
        double rx = endX - startX; double ry = endY - startY;
        double sx = wallEndX - wallStartX; double sy = wallEndY - wallStartY;
        double denominator = rx * sy - ry * sx;
        if (denominator == 0.0) return false;
        double qx = wallStartX - startX; double qy = wallStartY - startY;
        double t = (qx * sy - qy * sx) / denominator;
        double u = (qx * ry - qy * rx) / denominator;
        // t's lower bound uses a small epsilon, not 0.0: a segment whose
        // start point sits exactly on the (infinite) wall line -- which is
        // exactly the position left behind by the previous tic's own wall
        // reflection -- otherwise satisfies t == 0 for every direction,
        // including one moving straight away from the wall. Without this,
        // a projectile that just bounced off a wall re-triggers a
        // zero-distance "crossing" against the same wall every subsequent
        // tic and never actually leaves it. Real crossings happening near
        // (but not at) a segment's start are unaffected.
        if (t <= 0.0000001 || t > 1.0 || u < 0.0 || u > 1.0) return false;
        fraction = t;
        return true;
    }

    int DSP041FindWallCrossing(double startX, double startY,
        double endX, double endY, out double fraction, out double normalX,
        out double normalY)
    {
        int bestId = 0;
        fraction = 2.0; normalX = 0.0; normalY = 0.0;
        for (int i = 0; i < dsp041WallIds.Size(); i++)
        {
            double candidate;
            if (!DSP041LineIntersection(startX, startY, endX, endY,
                    dsp041WallStartX[i], dsp041WallStartY[i],
                    dsp041WallEndX[i], dsp041WallEndY[i], candidate)) continue;
            bool better = bestId == 0 || candidate < fraction
                || (candidate == fraction && dsp041WallIds[i] < bestId);
            if (!better) continue;
            fraction = candidate;
            bestId = dsp041WallIds[i];
            double wallDx = dsp041WallEndX[i] - dsp041WallStartX[i];
            double wallDy = dsp041WallEndY[i] - dsp041WallStartY[i];
            double length = sqrt(wallDx * wallDx + wallDy * wallDy);
            if (length > 0.0000001)
            {
                normalX = -wallDy / length;
                normalY = wallDx / length;
            }
        }
        return bestId;
    }

    bool DSP041IsPairGated(int eventId, int slot, int generation, int stableId,
        int logicalTic)
    {
        for (int i = 0; i < dsp041PairEvents.Size(); i++)
            if (dsp041PairEvents[i] == eventId && dsp041PairSlots[i] == slot
                && dsp041PairGenerations[i] == generation
                && dsp041PairIds[i] == stableId)
                return logicalTic < dsp041PairReadyTic[i];
        return false;
    }

    void DSP041SetPairReady(int eventId, int slot, int generation,
        int stableId, int readyTic)
    {
        for (int i = 0; i < dsp041PairEvents.Size(); i++)
            if (dsp041PairEvents[i] == eventId && dsp041PairSlots[i] == slot
                && dsp041PairGenerations[i] == generation
                && dsp041PairIds[i] == stableId)
            { dsp041PairReadyTic[i] = readyTic; return; }
        dsp041PairEvents.Push(eventId); dsp041PairSlots.Push(slot);
        dsp041PairGenerations.Push(generation); dsp041PairIds.Push(stableId);
        dsp041PairReadyTic.Push(readyTic);
    }

    // Earliest enemy-circle entry along the segment, for BouncesOffEnemies
    // weapons only, honoring the per-pair hit delay gate.
    bool DSP041FindEnemyBounceEntry(int index, double startX, double startY,
        double endX, double endY, int logicalTic, out double fraction,
        out int targetSlot, out int targetGeneration, out int targetId)
    {
        fraction = 2.0; targetSlot = -1; targetGeneration = 0; targetId = 0;
        double projectileRadius = double(dsp041ContactRadiusUnitsMilli[index]) / 1000.0;
        DSP024SweptCandidates(startX, startY, endX, endY, projectileRadius + 32.0);
        for (int i = 0; i < spatialCandidateCount; i++)
        {
            int slot = spatialCandidateSlots[i];
            int generation = spatialCandidateGenerations[i];
            int stableId = spatialCandidateIds[i];
            if (!ValidParts(slot, generation, stableId)
                || kinds[slot] != DSP041_TARGET_ENEMY || health[slot] <= 0
                || DSP041IsPairGated(dsp041Events[index], slot, generation,
                    stableId, logicalTic)) continue;
            double entry;
            double targetRadius = collisionRadii[slot] + projectileRadius;
            double dx = endX - startX; double dy = endY - startY;
            double mx = startX - x[slot]; double my = startY - y[slot];
            double c = mx * mx + my * my - targetRadius * targetRadius;
            if (c <= 0.0) entry = 0.0;
            else
            {
                double a = dx * dx + dy * dy;
                if (a <= 0.0000001) continue;
                double b = 2.0 * (mx * dx + my * dy);
                double discriminant = b * b - 4.0 * a * c;
                if (discriminant < 0.0) continue;
                entry = (-b - sqrt(discriminant)) / (2.0 * a);
                if (entry < 0.0 || entry > 1.0) continue;
            }
            if (entry < fraction)
            {
                fraction = entry; targetSlot = slot;
                targetGeneration = generation; targetId = stableId;
            }
        }
        return targetSlot >= 0;
    }

    void DSP041RetireProjectile(int index, String reason, int logicalTic)
    {
        if (index < 0 || index >= dsp041Active.Size()
            || dsp041Active[index] == 0) return;
        dsp041Active[index] = 0;
        if (dsp041Proxies[index] != null)
        {
            dsp041Proxies[index].Destroy();
            dsp041Proxies[index] = null;
        }
        { if (!dsQuiet) Console.Printf("DS_P041_PROJECTILE_END event_id=%d tic=%d system_id=%d reason=%s hit_count=%d bounce_count=%d", dsp041Events[index], logicalTic, dsp041Systems[index], reason, dsp041HitCount[index], dsp041BounceCount[index]); }
    }

    void DSP041ApplyPierceContacts(int index, double startX, double startY,
        double endX, double endY, int logicalTic)
    {
        double projectileRadius = double(dsp041ContactRadiusUnitsMilli[index]) / 1000.0;
        DSP024SweptCandidates(startX, startY, endX, endY, projectileRadius + 32.0);
        int hitDelayTics = DSP041BounceRows.HitDelayTics(dsp041Systems[index],
            dsp041Ranks[index]);
        for (int i = 0; i < spatialCandidateCount; i++)
        {
            int slot = spatialCandidateSlots[i];
            int generation = spatialCandidateGenerations[i];
            int stableId = spatialCandidateIds[i];
            if (!ValidParts(slot, generation, stableId)
                || kinds[slot] != DSP041_TARGET_ENEMY || health[slot] <= 0
                || DSP041IsPairGated(dsp041Events[index], slot, generation,
                    stableId, logicalTic)) continue;
            double targetRadius = collisionRadii[slot] + projectileRadius;
            double dx = endX - startX; double dy = endY - startY;
            double mx = startX - x[slot]; double my = startY - y[slot];
            double c = mx * mx + my * my - targetRadius * targetRadius;
            bool hits;
            if (c <= 0.0) hits = true;
            else
            {
                double a = dx * dx + dy * dy;
                if (a <= 0.0000001) continue;
                double b = 2.0 * (mx * dx + my * dy);
                double discriminant = b * b - 4.0 * a * c;
                if (discriminant < 0.0) continue;
                // The quadratic's roots are entry/exit fractions along the
                // *infinite* line through (startX,startY)/(endX,endY); a
                // circle intersecting that line far outside this sub-step's
                // actual [0,1] segment (e.g. directly behind the start
                // point) must not count as a contact -- only entry within
                // [0,1] is an actual contact this sub-step (mirrors
                // DSP041FindEnemyBounceEntry's own bounded entry check).
                double entry = (-b - sqrt(discriminant)) / (2.0 * a);
                hits = entry >= 0.0 && entry <= 1.0;
            }
            if (!hits) continue;
            DSP041SetPairReady(dsp041Events[index], slot, generation, stableId,
                logicalTic + hitDelayTics);
            DSP041ApplyHit(index, slot, generation, stableId, logicalTic);
        }
    }

    // DamageMilli rows are already milli-scaled (30.000 damage -> 30000), so
    // scaling by a might multiplier (also milli) and converting to an
    // integer amount is a direct fixed-point multiply, not a P025
    // CheckedMilliDamage transaction (that helper's sourceDamage is an
    // un-scaled integer and would double-scale a milli input here).
    bool DSP041ScaledDamage(int damageMilli, int mightMilli, out int amount)
    {
        amount = 0;
        if (damageMilli < 0 || mightMilli < 0
            || (mightMilli > 0 && damageMilli > 2000000000 / mightMilli))
            return false;
        amount = (damageMilli * mightMilli) / 1000 / 1000;
        return amount >= 0;
    }

    void DSP041ApplyHit(int index, int slot, int generation, int stableId,
        int logicalTic)
    {
        int amount;
        bool valid = DSP041ScaledDamage(dsp041DamageMilli[index],
            dsp041MightMilli[index], amount);
        if (!valid) { dsp041RejectedHits++; return; }
        // Carrozza!: Duration, Speed and Area each boost its damage.
        if (rsActive && dsp041Systems[index] == DSN3Rows.SYSTEM_CARROZZA)
            amount = int(double(amount) * (RsDurationFor(DSN3Rows.SYSTEM_CARROZZA)
                + RsSpeedFor(DSN3Rows.SYSTEM_CARROZZA) + RsAreaFor(DSN3Rows.SYSTEM_CARROZZA)) / 3000.0);
        // Profusione D'Amore: every hit sets off a small explosion.
        if (dsp041Systems[index] == DSN3Rows.SYSTEM_PROFUSIONE_DAMORE)
            DSP041QueueExplosion(index, x[slot], y[slot], 28, dsp041DamageMilli[index] / 2, "PROFUSIONE");
        int healthBefore; int healthAfter; int killed;
        if (!DSP025ApplyLogicalHit(slot, generation, stableId, amount,
                healthBefore, healthAfter, killed))
        { dsp041RejectedHits++; return; }
        dsp041AcceptedHits++;
        dsp041HitCount[index]++;
        int trueDelta = healthBefore - healthAfter;
        if (trueDelta > 0 && dsp041AcceptedDamageMilli <= 2147483647 - trueDelta)
            dsp041AcceptedDamageMilli += trueDelta;
        { if (!dsQuiet) Console.Printf("DS_P041_HIT event_id=%d tic=%d system_id=%d target_id=%d damage=%d health_before=%d health_after=%d killed=%d", dsp041Events[index], logicalTic, dsp041Systems[index], stableId, amount, healthBefore, healthAfter, killed); }
        // Kills reach HandleEnemyDeath -- the SAME method every other
        // checked-hit family already calls (AuraRuntime.zs, GlobalRuntime.zs,
        // GroundFieldRuntime.zs, ...) -- so a bounce kill gets exactly the
        // ordinary XP-drop/kill-count treatment. HandleEnemyDeath is supplied
        // by the enclosing class (VerticalSlice's DSP030VerticalSlice, or a
        // MAP27-style harness), never defined in this mixin itself.
        if (killed != 0) HandleEnemyDeath(slot, healthBefore, dsp041Events[index]);
    }

    void DSP041ApplyExplosion(int index, double centerX, double centerY,
        int radiusUnits, int damageMilli, int mightMilli, int logicalTic,
        String kind)
    {
        DSSound.Sfx(DSSfx.W_EXPLOSION, 3);
        if (rsActive)
            DSWeaponFx.Burst("WRNG", centerX, centerY, 1.2, radiusUnits * 0.4, radiusUnits * 2.2, true,
                Color(255, 255, 150, 60), 12);
        DSP024SweptCandidates(centerX, centerY, centerX, centerY,
            double(radiusUnits) + 32.0);
        int amount;
        if (!DSP041ScaledDamage(damageMilli, mightMilli, amount)) return;
        for (int i = 0; i < spatialCandidateCount; i++)
        {
            int slot = spatialCandidateSlots[i];
            int generation = spatialCandidateGenerations[i];
            int stableId = spatialCandidateIds[i];
            if (!ValidParts(slot, generation, stableId)
                || kinds[slot] != DSP041_TARGET_ENEMY || health[slot] <= 0)
                continue;
            double dx = x[slot] - centerX; double dy = y[slot] - centerY;
            double reach = collisionRadii[slot] + double(radiusUnits);
            if (dx * dx + dy * dy > reach * reach) continue;
            int healthBefore; int healthAfter; int killed;
            if (!DSP025ApplyLogicalHit(slot, generation, stableId, amount,
                    healthBefore, healthAfter, killed)) continue;
            dsp041AcceptedHits++;
            int explosionTrueDelta = healthBefore - healthAfter;
            if (explosionTrueDelta > 0
                && dsp041AcceptedDamageMilli <= 2147483647 - explosionTrueDelta)
                dsp041AcceptedDamageMilli += explosionTrueDelta;
            { if (!dsQuiet) Console.Printf("DS_P041_EXPLOSION_HIT event_id=%d tic=%d kind=%s target_id=%d damage=%d health_before=%d health_after=%d killed=%d", dsp041Events[index], logicalTic, kind, stableId, amount, healthBefore, healthAfter, killed); }
            // Same HandleEnemyDeath treatment as DSP041ApplyHit above.
            if (killed != 0) HandleEnemyDeath(slot, healthBefore, dsp041Events[index]);
        }
    }

    // ---- Per-tic processing -----------------------------------------------

    void DSP041ProcessProjectile(int index, int logicalTic)
    {
        if (dsp041Active[index] == 0) return;
        if (!ValidParts(dsp041OwnerSlotOf[index], dsp041OwnerGenerationOf[index],
                dsp041OwnerIdOf[index]))
        { DSP041RetireProjectile(index, "OWNER_GENERATION_REPLACED", logicalTic); return; }
        if (!ValidParts(dsp041WeaponSlotOf[index], dsp041WeaponGenerationOf[index],
                dsp041WeaponIdOf[index]))
        { DSP041RetireProjectile(index, "WEAPON_GENERATION_REPLACED", logicalTic); return; }
        if (dsp041AgeTics[index] >= dsp041DurationTics[index])
        {
            if (dsp041ExplosionChanceMilli[index] > 0)
                DSP041ResolveCherryStop(index, logicalTic);
            else
                DSP041RetireProjectile(index, "DURATION_EXPIRED", logicalTic);
            return;
        }

        // N3 Track A: Yatta Daikarin (evolved Cherry Bomb) reuses the same
        // lifetime speed-decay mechanic as its base weapon.
        bool isCherry = dsp041Systems[index] == DSP041BounceRows.SYSTEM_CHERRY
            || dsp041Systems[index] == DSN3Rows.SYSTEM_YATTA_DAIKARIN;
        double speed = dsp041SpeedUnitsPerSecond[index];
        if (isCherry)
        {
            double lifeFraction = double(dsp041AgeTics[index] + 1)
                / double(dsp041DurationTics[index]);
            if (lifeFraction > 1.0) lifeFraction = 1.0;
            speed = dsp041SpeedInitialUnitsPerSecond[index] * (1.0 - lifeFraction);
            if (speed < 0.0) speed = 0.0;
        }

        double startX = dsp041X[index]; double startY = dsp041Y[index];
        double remainingX = dsp041DirX[index] * speed / double(Thinker.TICRATE);
        double remainingY = dsp041DirY[index] * speed / double(Thinker.TICRATE);
        double curX = startX; double curY = startY;

        int reflections = 0;
        bool piercesEnemies = dsp041PiercesEnemies[index] != 0;
        bool bouncesOffEnemies = dsp041BouncesOffEnemies[index] != 0;
        while (reflections < DSP041BounceRows.MAX_REFLECTIONS_PER_TIC)
        {
            double endX = curX + remainingX; double endY = curY + remainingY;
            if (piercesEnemies)
                DSP041ApplyPierceContacts(index, curX, curY, endX, endY, logicalTic);

            double boundaryFraction; bool axisX; bool axisY;
            bool crossesBoundary = DSP041BoundaryCrossing(curX, curY, endX, endY,
                boundaryFraction, axisX, axisY);
            double wallFraction; double wallNormalX; double wallNormalY;
            int wallId = DSP041FindWallCrossing(curX, curY, endX, endY,
                wallFraction, wallNormalX, wallNormalY);
            double enemyFraction = 2.0; int enemySlot = -1;
            int enemyGeneration = 0; int enemyId = 0;
            if (bouncesOffEnemies)
                DSP041FindEnemyBounceEntry(index, curX, curY, endX, endY,
                    logicalTic, enemyFraction, enemySlot, enemyGeneration, enemyId);

            double bestFraction = 2.0;
            if (crossesBoundary && boundaryFraction < bestFraction)
                bestFraction = boundaryFraction;
            if (wallId != 0 && wallFraction < bestFraction)
                bestFraction = wallFraction;
            if (enemySlot >= 0 && enemyFraction < bestFraction)
                bestFraction = enemyFraction;
            if (bestFraction > 1.0)
            {
                curX = endX; curY = endY;
                break;
            }

            double hitX = curX + remainingX * bestFraction;
            double hitY = curY + remainingY * bestFraction;
            bool takeBoundary = crossesBoundary && boundaryFraction <= bestFraction + 0.0000001;
            bool takeWall = wallId != 0 && wallFraction <= bestFraction + 0.0000001;
            bool takeEnemy = enemySlot >= 0 && enemyFraction <= bestFraction + 0.0000001
                && !takeBoundary && !takeWall;
            // Deterministic order: earliest fraction first (already selected
            // via bestFraction), then boundary/wall X-before-Y precedence
            // when an exact tie occurs at the same fraction.
            double dirLenBefore = sqrt(remainingX * remainingX + remainingY * remainingY);
            double newDirX = remainingX; double newDirY = remainingY;
            if (takeBoundary)
            {
                if (axisX) newDirX = -newDirX;
                if (axisY) newDirY = -newDirY;
                dsp041BounceCount[index]++;
                { if (!dsQuiet) Console.Printf("DS_P041_BOUNCE event_id=%d tic=%d kind=BOUNDARY axis_x=%d axis_y=%d fraction=%.6f x=%.3f y=%.3f", dsp041Events[index], logicalTic, axisX ? 1 : 0, axisY ? 1 : 0, bestFraction, hitX, hitY); }
            }
            else if (takeWall)
            {
                double dotProduct = remainingX * wallNormalX + remainingY * wallNormalY;
                newDirX = remainingX - 2.0 * dotProduct * wallNormalX;
                newDirY = remainingY - 2.0 * dotProduct * wallNormalY;
                dsp041BounceCount[index]++;
                { if (!dsQuiet) Console.Printf("DS_P041_BOUNCE event_id=%d tic=%d kind=WALL wall_id=%d fraction=%.6f x=%.3f y=%.3f", dsp041Events[index], logicalTic, wallId, bestFraction, hitX, hitY); }
            }
            else if (takeEnemy)
            {
                double normalX = hitX - x[enemySlot]; double normalY = hitY - y[enemySlot];
                double normalLength = sqrt(normalX * normalX + normalY * normalY);
                if (normalLength > 0.0000001) { normalX /= normalLength; normalY /= normalLength; }
                else { normalX = -dsp041DirX[index]; normalY = -dsp041DirY[index]; }
                double dotProduct = remainingX * normalX + remainingY * normalY;
                newDirX = remainingX - 2.0 * dotProduct * normalX;
                newDirY = remainingY - 2.0 * dotProduct * normalY;
                int hitDelayTics = DSP041BounceRows.HitDelayTics(dsp041Systems[index],
                    dsp041Ranks[index]);
                DSP041SetPairReady(dsp041Events[index], enemySlot, enemyGeneration,
                    enemyId, logicalTic + hitDelayTics);
                DSP041ApplyHit(index, enemySlot, enemyGeneration, enemyId, logicalTic);
                dsp041BounceCount[index]++;
                { if (!dsQuiet) Console.Printf("DS_P041_BOUNCE event_id=%d tic=%d kind=ENEMY target_id=%d fraction=%.6f x=%.3f y=%.3f", dsp041Events[index], logicalTic, enemyId, bestFraction, hitX, hitY); }
            }
            else break;

            // Normal play: No Future explodes on every wall / edge bounce;
            // Anima of Mortaccio's bones speed up 10% per bounce (up to 3x).
            if (dsp041Systems[index] == DSP041BounceRows.SYSTEM_NO_FUTURE && (takeBoundary || takeWall))
                DSP041QueueExplosion(index, hitX, hitY, DSP041BounceRows.NO_FUTURE_EXPLOSION_RADIUS_UNITS,
                    dsp041DamageMilli[index], "NO_FUTURE_BOUNCE");
            if (rsActive && dsp041Systems[index] == DSN3Rows.SYSTEM_ANIMA_OF_MORTACCIO)
                dsp041SpeedUnitsPerSecond[index] = min(dsp041SpeedInitialUnitsPerSecond[index] * 3.0,
                    dsp041SpeedUnitsPerSecond[index] * 1.1);

            if (dsp041BounceBudgetRemaining[index] >= 0)
            {
                dsp041BounceBudgetRemaining[index]--;
                if (dsp041BounceBudgetRemaining[index] < 0)
                {
                    curX = hitX; curY = hitY;
                    dsp041X[index] = curX; dsp041Y[index] = curY;
                    dsp041AgeTics[index]++;
                    DSP041RetireProjectile(index, "BOUNCE_BUDGET_EXHAUSTED", logicalTic);
                    return;
                }
            }

            double newLen = sqrt(newDirX * newDirX + newDirY * newDirY);
            if (newLen > 0.0000001 && dirLenBefore > 0.0000001)
            {
                dsp041DirX[index] = newDirX / newLen;
                dsp041DirY[index] = newDirY / newLen;
            }
            double remainingFraction = 1.0 - bestFraction;
            remainingX = newDirX * remainingFraction;
            remainingY = newDirY * remainingFraction;
            curX = hitX; curY = hitY;
            reflections++;
        }

        dsp041X[index] = curX; dsp041Y[index] = curY;
        dsp041AgeTics[index]++;
    }

    void DSP041ResolveCherryStop(int index, int logicalTic)
    {
        if (dsp041Stopped[index] != 0)
        { DSP041RetireProjectile(index, "STOPPED", logicalTic); return; }
        dsp041Stopped[index] = 1;
        int rngBefore; int rngAfter; int rollMilli;
        bool exploded = DSP041RollExplosionChance(dsp041ExplosionChanceMilli[index],
            1000, rngBefore, rngAfter, rollMilli);
        { if (!dsQuiet) Console.Printf("DS_P041_CHERRY_STOP event_id=%d tic=%d roll_milli=%d chance_milli=%d exploded=%d rng_before=%d rng_after=%d rng_stream=DEDICATED_P041_BOUNCE", dsp041Events[index], logicalTic, rollMilli, dsp041ExplosionChanceMilli[index], exploded ? 1 : 0, rngBefore, rngAfter); }
        if (exploded)
        {
            dsp041Exploded[index] = 1;
            // dsp041ExplosionRadiusUnitsMilli is already Area-scaled by the
            // rows layer (DSP041BounceRows.ExplosionRadiusMilliUnits); only
            // convert milli-units to units here.
            int explosionRadiusUnits = dsp041ExplosionRadiusUnitsMilli[index] / 1000;
            DSP041ApplyExplosion(index, dsp041X[index], dsp041Y[index],
                explosionRadiusUnits, dsp041DamageMilli[index],
                dsp041MightMilli[index], logicalTic, "CHERRY");
            // Normal play: the bomb bursts into smaller bombs around it
            // (3 for Cherry Bomb, 5 for Yatta Daikarin), half size and damage.
            int children = dsp041Systems[index] == DSN3Rows.SYSTEM_YATTA_DAIKARIN ? 5 : 3;
            for (int c = 0; c < children; c++)
            {
                double a = c * 360.0 / children + logicalTic * 7.0;
                double off = explosionRadiusUnits * 1.1;
                DSP041QueueExplosion(index, dsp041X[index] + cos(a) * off, dsp041Y[index] + sin(a) * off,
                    max(8, explosionRadiusUnits / 2), dsp041DamageMilli[index] / 2, "CHERRY_CHILD");
            }
        }
        DSP041RetireProjectile(index, "STOPPED", logicalTic);
    }

    void DSP041AdvanceTic(int logicalTic)
    {
        int count = dsp041Active.Size();
        for (int i = 0; i < count; i++)
            DSP041ProcessProjectile(i, logicalTic);
        DSP041FlushQueuedExplosions(logicalTic);
    }

    void DSP041QueueExplosion(int index, double px, double py, int radiusUnits, int damageMilli, String kind)
    {
        if (!rsActive || damageMilli <= 0) return;
        dsp041QueuedIndex.Push(index); dsp041QueuedX.Push(px); dsp041QueuedY.Push(py);
        dsp041QueuedRadius.Push(radiusUnits); dsp041QueuedDamage.Push(damageMilli); dsp041QueuedKind.Push(kind);
    }

    void DSP041FlushQueuedExplosions(int logicalTic)
    {
        let vs = DSP030VerticalSlice(self);
        for (int i = 0; i < dsp041QueuedIndex.Size(); i++)
        {
            int index = dsp041QueuedIndex[i];
            if (index < 0 || index >= dsp041Systems.Size()) continue;
            int damage = dsp041QueuedDamage[i];
            // Yatta Daikarin's explosions can crit (wiki approximation: 10%, x2).
            if (vs != null && dsp041Systems[index] == DSN3Rows.SYSTEM_YATTA_DAIKARIN && vs.RollCrit(100))
            {
                damage = damage > 1000000000 ? 2000000000 : damage * 2;
                vs.OnCrit(dsp041QueuedX[i], dsp041QueuedY[i], DSN3Rows.SYSTEM_YATTA_DAIKARIN);
            }
            if (vs != null) vs.FxCount(dsp041QueuedKind[i]);
            DSP041ApplyExplosion(index, dsp041QueuedX[i], dsp041QueuedY[i], dsp041QueuedRadius[i],
                damage, dsp041MightMilli[index], logicalTic, dsp041QueuedKind[i]);
        }
        dsp041QueuedIndex.Clear(); dsp041QueuedX.Clear(); dsp041QueuedY.Clear();
        dsp041QueuedRadius.Clear(); dsp041QueuedDamage.Clear(); dsp041QueuedKind.Clear();
    }

    // ---- NO FUTURE player-hit explosion gate ------------------------------

    // The lead's/harness's owned player-damage-transaction path calls this
    // once per accepted contact-damage transaction against the player. Here
    // it is exposed for controlled MAP16/MAP27 fixture use; every live NO
    // FUTURE projectile explodes simultaneously when the gate is open.
    bool DSP041NotifyPlayerContactDamage(int logicalTic, int armorPoints)
    {
        if (logicalTic < dsp041NoFutureGateReadyTic) return false;
        dsp041NoFutureGateReadyTic = logicalTic
            + DSP041BounceRows.NO_FUTURE_GATE_TICS;
        int exploded = 0;
        int armorBonusMilli = 1000 + DSP041BounceRows.NO_FUTURE_ARMOR_BONUS_MILLI
            * armorPoints;
        for (int i = 0; i < dsp041Active.Size(); i++)
        {
            if (dsp041Active[i] == 0
                || dsp041Systems[i] != DSP041BounceRows.SYSTEM_NO_FUTURE) continue;
            dsp041NoFutureExplosionOrdinal++;
            int scaledDamageMilli = dsp041DamageMilli[i] * armorBonusMilli / 1000;
            DSP041ApplyExplosion(i, dsp041X[i], dsp041Y[i],
                DSP041BounceRows.NO_FUTURE_EXPLOSION_RADIUS_UNITS,
                scaledDamageMilli, dsp041MightMilli[i], logicalTic, "NO_FUTURE");
            exploded++;
        }
        { if (!dsQuiet) Console.Printf("DS_P041_NO_FUTURE_EXPLOSION tic=%d armor_points=%d armor_bonus_milli=%d live_projectiles=%d gate_ready_tic=%d", logicalTic, armorPoints, armorBonusMilli, exploded, dsp041NoFutureGateReadyTic); }
        return exploded > 0;
    }

    // ---- Rebase and persistence hash --------------------------------------

    // Translates every live projectile's position by (deltaX, deltaY).
    // Age, ledger and bounce counts are untouched; the boundary itself needs
    // no separate translation because it is recomputed from the current
    // (already-rebased) player position every tic.
    void DSP041Rebase(double deltaX, double deltaY, int logicalTic)
    {
        int moved = 0;
        for (int i = 0; i < dsp041Active.Size(); i++)
        {
            if (dsp041Active[i] == 0) continue;
            dsp041X[i] += deltaX; dsp041Y[i] += deltaY;
            moved++;
        }
        { if (!dsQuiet) Console.Printf("DS_P041_REBASE tic=%d delta_x=%.6f delta_y=%.6f projectiles_translated=%d age_unchanged=1 ledger_unchanged=1 bounce_counts_unchanged=1", logicalTic, deltaX, deltaY, moved); }
    }

    int DSP041PersistenceHash()
    {
        int hash = 1469598103;
        for (int i = 0; i < dsp041Active.Size(); i++)
        {
            if (dsp041Active[i] == 0) continue;
            hash = hash ^ dsp041Events[i];
            hash = DSP025NextAttackRng(hash);
            hash = hash ^ int(dsp041X[i] * 1000.0);
            hash = DSP025NextAttackRng(hash);
            hash = hash ^ int(dsp041Y[i] * 1000.0);
            hash = DSP025NextAttackRng(hash);
            hash = hash ^ int(dsp041DirX[i] * 1000.0);
            hash = DSP025NextAttackRng(hash);
            hash = hash ^ int(dsp041DirY[i] * 1000.0);
            hash = DSP025NextAttackRng(hash);
            hash = hash ^ dsp041AgeTics[i];
            hash = DSP025NextAttackRng(hash);
            hash = hash ^ dsp041BounceCount[i];
            hash = DSP025NextAttackRng(hash);
            hash = hash ^ dsp041Stopped[i];
            hash = DSP025NextAttackRng(hash);
        }
        return hash;
    }
}
