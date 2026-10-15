// P038 logical bottle/deposit/field authority. Arrays intentionally live on
// the owning EventHandler so P029 saves preserve schedules, projectiles,
// fields, and per-field target deadlines. Presentation proxies are not state.
mixin class DSP038GroundFieldRuntime
{
    const DSP038_KIND_ENEMY = 1;
    const DSP038_MAX_SAFE_DAMAGE_TENTHS = 20000000;

    Array<int> dsp038WeaponActive;
    Array<int> dsp038WeaponSystem;
    Array<int> dsp038WeaponRank;
    Array<int> dsp038WeaponSlots;
    Array<int> dsp038WeaponGenerations;
    Array<int> dsp038WeaponIds;
    Array<int> dsp038WeaponFormGenerations;
    Array<int> dsp038WeaponOwnerSlots;
    Array<int> dsp038WeaponOwnerGenerations;
    Array<int> dsp038WeaponOwnerIds;
    Array<int> dsp038WeaponNextAttackTics;
    Array<int> dsp038WeaponVolleyRemaining;
    Array<int> dsp038WeaponVolleyOrdinal;
    Array<int> dsp038WeaponNextBottleTics;
    Array<int> dsp038WeaponVolleySerials;
    Array<int> dsp038WeaponAreaAdjustments;
    Array<int> dsp038WeaponSpeedAdjustments;
    Array<int> dsp038WeaponMoveSpeedAdjustments;
    Array<int> dsp038WeaponGrowthAdjustments;
    Array<int> dsp038WeaponMightMilli;
    Array<int> dsp038WeaponCooldownMultiplierMilli;

    // Each outbound bottle captures its destination and source form. A later
    // transformation changes only future emissions.
    Array<int> dsp038BottleActive;
    Array<int> dsp038BottleId;
    Array<int> dsp038BottleGeneration;
    Array<int> dsp038BottleSystem;
    Array<int> dsp038BottleRank;
    Array<int> dsp038BottleWeaponId;
    Array<int> dsp038BottleFormGeneration;
    Array<int> dsp038BottleVolleySerial;
    Array<int> dsp038BottleOrdinal;
    Array<int> dsp038BottleOwnerSlot;
    Array<int> dsp038BottleOwnerGeneration;
    Array<int> dsp038BottleOwnerId;
    Array<int> dsp038BottleTargetSlot;
    Array<int> dsp038BottleTargetGeneration;
    Array<int> dsp038BottleTargetId;
    Array<int> dsp038BottleEmitTic;
    Array<int> dsp038BottleImpactTic;
    Array<int> dsp038BottleDepositTic;
    Array<int> dsp038BottleDurationTics;
    Array<int> dsp038BottleDamageTenths;
    Array<int> dsp038BottleMightMilli;
    Array<int> dsp038BottleAreaMilli;
    Array<int> dsp038BottleFieldRadiusMilli;
    Array<int> dsp038BottleRehitTics;
    Array<int> dsp038BottlePoolLimit;
    Array<int> dsp038BottleFieldRadiusCapMilli;
    Array<int> dsp038BottleFieldMotionPolicy;
    Array<int> dsp038BottleBaselineInwardMilli;
    Array<int> dsp038BottleFixtureInwardMilli;
    Array<int> dsp038BottleBaselineGrowthMilli;
    Array<int> dsp038BottleFixtureGrowthMilli;
    Array<double> dsp038BottleStartX;
    Array<double> dsp038BottleStartY;
    Array<double> dsp038BottleDestinationX;
    Array<double> dsp038BottleDestinationY;
    Array<double> dsp038BottleX;
    Array<double> dsp038BottleY;

    Array<int> dsp038FieldActive;
    Array<int> dsp038FieldId;
    Array<int> dsp038FieldGeneration;
    Array<int> dsp038FieldSystem;
    Array<int> dsp038FieldRank;
    Array<int> dsp038FieldWeaponId;
    Array<int> dsp038FieldFormGeneration;
    Array<int> dsp038FieldVolleySerial;
    Array<int> dsp038FieldBottleOrdinal;
    Array<int> dsp038FieldOwnerSlot;
    Array<int> dsp038FieldOwnerGeneration;
    Array<int> dsp038FieldOwnerId;
    Array<int> dsp038FieldTargetSlot;
    Array<int> dsp038FieldTargetGeneration;
    Array<int> dsp038FieldTargetId;
    Array<int> dsp038FieldCreatedTic;
    Array<int> dsp038FieldExpiresTic;
    Array<int> dsp038FieldDamageTenths;
    Array<int> dsp038FieldMightMilli;
    Array<int> dsp038FieldRehitTics;
    Array<int> dsp038FieldReportedPoolLimit;
    Array<int> dsp038FieldRadiusCapMilli;
    Array<int> dsp038FieldMotionPolicy;
    Array<int> dsp038FieldMoveMilliPerTic;
    Array<int> dsp038FieldGrowthMilliPerTic;
    Array<int> dsp038FieldSourceAreaMilli;
    Array<int> dsp038FieldLastUpdateTic;
    Array<double> dsp038FieldX;
    Array<double> dsp038FieldY;
    Array<double> dsp038FieldRadius;
    Array<double> dsp038FieldAnchorX;
    Array<double> dsp038FieldAnchorY;

    // Per-field, full-handle target ledger. Independent puddles may each hit
    // the same target; one field cannot hit it again until its own deadline.
    Array<int> dsp038HitFieldId;
    Array<int> dsp038HitFieldGeneration;
    Array<int> dsp038HitTargetSlot;
    Array<int> dsp038HitTargetGeneration;
    Array<int> dsp038HitTargetId;
    Array<int> dsp038HitReadyTic;
    Array<double> dsp038ContactDistanceSquared;
    Array<double> dsp038ContactFractions;
    Array<int> dsp038ContactSlots;
    Array<int> dsp038ContactGenerations;
    Array<int> dsp038ContactIds;

    int dsp038NextBottleId;
    int dsp038NextBottleGeneration;
    int dsp038NextFieldId;
    int dsp038NextFieldGeneration;
    int dsp038NextVolleySerial;
    int dsp038NextEventId;
    int dsp038LastAcceptedEventId;
    int dsp038LastAcceptedSystemId;
    int dsp038LastAcceptedFieldId;
    int dsp038LastAcceptedFieldGeneration;
    int dsp038AcceptedHits;
    int dsp038RejectedHits;
    int dsp038AcceptedDamageMilli;
    int dsp038RejectedDamageMilli;
    int dsp038RejectedFields;
    int dsp038ExpiredFields;
    int dsp038DepositedFields;

    void DSP038ResetGroundRuntime()
    {
        dsp038WeaponActive.Clear(); dsp038WeaponSystem.Clear();
        dsp038WeaponRank.Clear(); dsp038WeaponSlots.Clear();
        dsp038WeaponGenerations.Clear(); dsp038WeaponIds.Clear();
        dsp038WeaponFormGenerations.Clear(); dsp038WeaponOwnerSlots.Clear();
        dsp038WeaponOwnerGenerations.Clear(); dsp038WeaponOwnerIds.Clear();
        dsp038WeaponNextAttackTics.Clear(); dsp038WeaponVolleyRemaining.Clear();
        dsp038WeaponVolleyOrdinal.Clear(); dsp038WeaponNextBottleTics.Clear();
        dsp038WeaponVolleySerials.Clear(); dsp038WeaponAreaAdjustments.Clear();
        dsp038WeaponSpeedAdjustments.Clear(); dsp038WeaponMoveSpeedAdjustments.Clear();
        dsp038WeaponGrowthAdjustments.Clear(); dsp038WeaponMightMilli.Clear();
        dsp038WeaponCooldownMultiplierMilli.Clear();
        dsp038BottleActive.Clear(); dsp038BottleId.Clear();
        dsp038BottleGeneration.Clear(); dsp038BottleSystem.Clear();
        dsp038BottleRank.Clear(); dsp038BottleWeaponId.Clear();
        dsp038BottleFormGeneration.Clear(); dsp038BottleVolleySerial.Clear();
        dsp038BottleOrdinal.Clear(); dsp038BottleOwnerSlot.Clear();
        dsp038BottleOwnerGeneration.Clear(); dsp038BottleOwnerId.Clear();
        dsp038BottleTargetSlot.Clear(); dsp038BottleTargetGeneration.Clear();
        dsp038BottleTargetId.Clear(); dsp038BottleEmitTic.Clear();
        dsp038BottleImpactTic.Clear(); dsp038BottleDepositTic.Clear();
        dsp038BottleDurationTics.Clear(); dsp038BottleDamageTenths.Clear();
        dsp038BottleMightMilli.Clear(); dsp038BottleAreaMilli.Clear();
        dsp038BottleFieldRadiusMilli.Clear();
        dsp038BottleRehitTics.Clear(); dsp038BottlePoolLimit.Clear();
        dsp038BottleFieldRadiusCapMilli.Clear(); dsp038BottleFieldMotionPolicy.Clear();
        dsp038BottleBaselineInwardMilli.Clear(); dsp038BottleFixtureInwardMilli.Clear();
        dsp038BottleBaselineGrowthMilli.Clear(); dsp038BottleFixtureGrowthMilli.Clear();
        dsp038BottleStartX.Clear(); dsp038BottleStartY.Clear();
        dsp038BottleDestinationX.Clear(); dsp038BottleDestinationY.Clear();
        dsp038BottleX.Clear(); dsp038BottleY.Clear();
        dsp038FieldActive.Clear(); dsp038FieldId.Clear();
        dsp038FieldGeneration.Clear(); dsp038FieldSystem.Clear();
        dsp038FieldRank.Clear(); dsp038FieldWeaponId.Clear();
        dsp038FieldFormGeneration.Clear(); dsp038FieldVolleySerial.Clear();
        dsp038FieldBottleOrdinal.Clear(); dsp038FieldOwnerSlot.Clear();
        dsp038FieldOwnerGeneration.Clear(); dsp038FieldOwnerId.Clear();
        dsp038FieldTargetSlot.Clear(); dsp038FieldTargetGeneration.Clear();
        dsp038FieldTargetId.Clear(); dsp038FieldCreatedTic.Clear();
        dsp038FieldExpiresTic.Clear(); dsp038FieldDamageTenths.Clear();
        dsp038FieldMightMilli.Clear(); dsp038FieldRehitTics.Clear();
        dsp038FieldReportedPoolLimit.Clear(); dsp038FieldRadiusCapMilli.Clear();
        dsp038FieldMotionPolicy.Clear(); dsp038FieldMoveMilliPerTic.Clear();
        dsp038FieldGrowthMilliPerTic.Clear(); dsp038FieldSourceAreaMilli.Clear();
        dsp038FieldLastUpdateTic.Clear(); dsp038FieldX.Clear(); dsp038FieldY.Clear();
        dsp038FieldRadius.Clear(); dsp038FieldAnchorX.Clear(); dsp038FieldAnchorY.Clear();
        dsp038HitFieldId.Clear(); dsp038HitFieldGeneration.Clear();
        dsp038HitTargetSlot.Clear(); dsp038HitTargetGeneration.Clear();
        dsp038HitTargetId.Clear(); dsp038HitReadyTic.Clear();
        dsp038ContactDistanceSquared.Clear(); dsp038ContactSlots.Clear();
        dsp038ContactFractions.Clear();
        dsp038ContactGenerations.Clear(); dsp038ContactIds.Clear();
        dsp038NextBottleId = 1; dsp038NextBottleGeneration = 1;
        dsp038NextFieldId = 1; dsp038NextFieldGeneration = 1;
        dsp038NextVolleySerial = 1; dsp038NextEventId = 1;
        dsp038LastAcceptedEventId = 0;
        dsp038LastAcceptedSystemId = 0;
        dsp038LastAcceptedFieldId = 0;
        dsp038LastAcceptedFieldGeneration = 0;
        dsp038AcceptedHits = 0; dsp038RejectedHits = 0;
        dsp038AcceptedDamageMilli = 0; dsp038RejectedDamageMilli = 0;
        dsp038RejectedFields = 0; dsp038ExpiredFields = 0;
        dsp038DepositedFields = 0;
    }

    bool DSP038ValidSystemRank(int systemId, int rank)
    {
        int damage; int area; int amount; int duration; int cooldown;
        int interval; int delay; int pool; int projectileSpeed;
        int moveSpeed; int wall;
        return DSP038GroundRows.TryGetRankRow(systemId, rank, damage,
            area, amount, duration, cooldown, interval, delay, pool,
            projectileSpeed, moveSpeed, wall);
    }

    int DSP038FindWeapon(int weaponSlot, int weaponGeneration, int weaponId)
    {
        for (int i = 0; i < dsp038WeaponActive.Size(); i++)
            if (dsp038WeaponActive[i] != 0
                && dsp038WeaponSlots[i] == weaponSlot
                && dsp038WeaponGenerations[i] == weaponGeneration
                && dsp038WeaponIds[i] == weaponId) return i;
        return -1;
    }

    bool DSP038EquipWeapon(int systemId, int rank, int weaponSlot,
        int weaponGeneration, int weaponId, int formGeneration,
        int ownerSlot, int ownerGeneration, int ownerId, int firstFireTic,
        int areaAdjustmentMilli, int speedAdjustmentMilli,
        int moveSpeedAdjustmentMilli, int growthAdjustmentMilli,
        int mightMilli, int cooldownMultiplierMilli)
    {
        if (!DSP038ValidSystemRank(systemId, rank)
            || !ValidParts(weaponSlot, weaponGeneration, weaponId)
            || !ValidParts(ownerSlot, ownerGeneration, ownerId)
            || formGeneration <= 0 || firstFireTic < 0
            || areaAdjustmentMilli < 0 || speedAdjustmentMilli < 0
            || moveSpeedAdjustmentMilli < 0 || growthAdjustmentMilli < 0
            || mightMilli < 1 || cooldownMultiplierMilli < 1)
            return false;
        if (DSP038FindWeapon(weaponSlot, weaponGeneration, weaponId) >= 0)
            return false;

        dsp038WeaponActive.Push(1); dsp038WeaponSystem.Push(systemId);
        dsp038WeaponRank.Push(rank); dsp038WeaponSlots.Push(weaponSlot);
        dsp038WeaponGenerations.Push(weaponGeneration); dsp038WeaponIds.Push(weaponId);
        dsp038WeaponFormGenerations.Push(formGeneration);
        dsp038WeaponOwnerSlots.Push(ownerSlot);
        dsp038WeaponOwnerGenerations.Push(ownerGeneration);
        dsp038WeaponOwnerIds.Push(ownerId);
        dsp038WeaponNextAttackTics.Push(firstFireTic);
        dsp038WeaponVolleyRemaining.Push(0); dsp038WeaponVolleyOrdinal.Push(0);
        dsp038WeaponNextBottleTics.Push(firstFireTic);
        dsp038WeaponVolleySerials.Push(0);
        dsp038WeaponAreaAdjustments.Push(areaAdjustmentMilli);
        dsp038WeaponSpeedAdjustments.Push(speedAdjustmentMilli);
        dsp038WeaponMoveSpeedAdjustments.Push(moveSpeedAdjustmentMilli);
        dsp038WeaponGrowthAdjustments.Push(growthAdjustmentMilli);
        dsp038WeaponMightMilli.Push(mightMilli);
        dsp038WeaponCooldownMultiplierMilli.Push(cooldownMultiplierMilli);
        return true;
    }

    // N2 dispatcher rank-change API (docs/contracts/normal-play-integration.md
    // "Weapon dispatcher": "Engines missing a rank-change API get one").
    // Mirrors DSP035SetFixtureRank's contract and logging shape for the
    // ground-field engine; leaves all other equip/transform logic untouched.
    bool DSP038SetWeaponRank(int weaponSlot, int systemId, int rank)
    {
        if (!DSP038ValidSystemRank(systemId, rank)) return false;
        for (int i = 0; i < dsp038WeaponActive.Size(); i++)
        {
            if (dsp038WeaponActive[i] == 0
                || dsp038WeaponSlots[i] != weaponSlot) continue;
            if (dsp038WeaponSystem[i] != systemId) return false;
            int oldRank = dsp038WeaponRank[i];
            dsp038WeaponRank[i] = rank;
            { if (!dsQuiet) Console.Printf("DS_N2_GROUND_FIXTURE_RANK accepted=1 system_id=%d prior_rank=%d rank=%d weapon_id=%d weapon_generation=%d classification=N2_DISPATCHER_RANK_CHANGE", systemId, oldRank, rank, dsp038WeaponIds[i], dsp038WeaponGenerations[i]); }
            return true;
        }
        return false;
    }

    bool DSP038TransformWeapon(int weaponSlot, int weaponGeneration,
        int weaponId, int expectedSourceSystem, int evolvedSystem,
        int rank, int newFormGeneration, bool dependencyPresent)
    {
        int weapon = DSP038FindWeapon(weaponSlot, weaponGeneration, weaponId);
        int registeredEvolved; int dependencyKey; int sourceRank;
        int dependencyRank;
        if (weapon < 0 || dsp038WeaponSystem[weapon] != expectedSourceSystem
            || !dependencyPresent
            || !DSP038GroundRows.TryGetEvolution(expectedSourceSystem,
                registeredEvolved, dependencyKey, sourceRank, dependencyRank)
            || registeredEvolved != evolvedSystem
            || dsp038WeaponRank[weapon] < sourceRank
            || !DSP038ValidSystemRank(evolvedSystem, rank)
            || rank <= 0 || newFormGeneration <= dsp038WeaponFormGenerations[weapon])
            return false;
        dsp038WeaponSystem[weapon] = evolvedSystem;
        dsp038WeaponRank[weapon] = rank;
        dsp038WeaponFormGenerations[weapon] = newFormGeneration;
        // A not-yet-emitted child belongs to the old source form and is
        // cancelled. Already-emitted bottles/fields keep captured provenance.
        dsp038WeaponVolleyRemaining[weapon] = 0;
        { if (!dsQuiet) Console.Printf("DS_P038_TRANSFORM accepted=1 weapon_id=%d source_system=%d evolved_system=%d rank=%d form_generation=%d dependency_present=%d dependency_key=%d", weaponId, expectedSourceSystem, evolvedSystem, rank, newFormGeneration, dependencyPresent, dependencyKey); }
        return true;
    }

    void DSP038RebaseGroundRuntime(double deltaX, double deltaY)
    {
        for (int i = 0; i < dsp038BottleActive.Size(); i++)
        {
            if (dsp038BottleActive[i] == 0) continue;
            dsp038BottleStartX[i] += deltaX; dsp038BottleStartY[i] += deltaY;
            dsp038BottleDestinationX[i] += deltaX; dsp038BottleDestinationY[i] += deltaY;
            dsp038BottleX[i] += deltaX; dsp038BottleY[i] += deltaY;
        }
        for (int i = 0; i < dsp038FieldActive.Size(); i++)
        {
            if (dsp038FieldActive[i] == 0) continue;
            dsp038FieldX[i] += deltaX; dsp038FieldY[i] += deltaY;
            dsp038FieldAnchorX[i] += deltaX; dsp038FieldAnchorY[i] += deltaY;
        }
    }

    int DSP038HashMix(int hash, int value)
    {
        int normalized = value % 1000003;
        if (normalized < 0) normalized += 1000003;
        return (hash * 31 + normalized) % 1000003;
    }

    int DSP038HashMixDoubleMilli(int hash, double value)
    {
        // World-plane state is normally map-bounded. Saturate before the
        // fixed-point conversion so even malformed save values cannot
        // overflow the signed integer conversion used by the hash.
        int quantized;
        if (value >= 2000000.0) quantized = 2000000000;
        else if (value <= -2000000.0) quantized = -2000000000;
        else quantized = int(value * 1000.0);
        return DSP038HashMix(hash, quantized);
    }

    int DSP038HashWeaponState(int hash, int i)
    {
        hash = DSP038HashMix(hash, dsp038WeaponActive[i]);
        if (dsp038WeaponActive[i] == 0) return hash;
        hash = DSP038HashMix(hash, dsp038WeaponSystem[i]);
        hash = DSP038HashMix(hash, dsp038WeaponRank[i]);
        hash = DSP038HashMix(hash, dsp038WeaponSlots[i]);
        hash = DSP038HashMix(hash, dsp038WeaponGenerations[i]);
        hash = DSP038HashMix(hash, dsp038WeaponIds[i]);
        hash = DSP038HashMix(hash, dsp038WeaponFormGenerations[i]);
        hash = DSP038HashMix(hash, dsp038WeaponOwnerSlots[i]);
        hash = DSP038HashMix(hash, dsp038WeaponOwnerGenerations[i]);
        hash = DSP038HashMix(hash, dsp038WeaponOwnerIds[i]);
        hash = DSP038HashMix(hash, dsp038WeaponNextAttackTics[i]);
        hash = DSP038HashMix(hash, dsp038WeaponVolleyRemaining[i]);
        hash = DSP038HashMix(hash, dsp038WeaponVolleyOrdinal[i]);
        hash = DSP038HashMix(hash, dsp038WeaponNextBottleTics[i]);
        hash = DSP038HashMix(hash, dsp038WeaponVolleySerials[i]);
        hash = DSP038HashMix(hash, dsp038WeaponAreaAdjustments[i]);
        hash = DSP038HashMix(hash, dsp038WeaponSpeedAdjustments[i]);
        hash = DSP038HashMix(hash, dsp038WeaponMoveSpeedAdjustments[i]);
        hash = DSP038HashMix(hash, dsp038WeaponGrowthAdjustments[i]);
        hash = DSP038HashMix(hash, dsp038WeaponMightMilli[i]);
        hash = DSP038HashMix(hash, dsp038WeaponCooldownMultiplierMilli[i]);
        return hash;
    }

    int DSP038HashBottleState(int hash, int i)
    {
        hash = DSP038HashMix(hash, dsp038BottleActive[i]);
        if (dsp038BottleActive[i] == 0) return hash;
        hash = DSP038HashMix(hash, dsp038BottleId[i]);
        hash = DSP038HashMix(hash, dsp038BottleGeneration[i]);
        hash = DSP038HashMix(hash, dsp038BottleSystem[i]);
        hash = DSP038HashMix(hash, dsp038BottleRank[i]);
        hash = DSP038HashMix(hash, dsp038BottleWeaponId[i]);
        hash = DSP038HashMix(hash, dsp038BottleFormGeneration[i]);
        hash = DSP038HashMix(hash, dsp038BottleVolleySerial[i]);
        hash = DSP038HashMix(hash, dsp038BottleOrdinal[i]);
        hash = DSP038HashMix(hash, dsp038BottleOwnerSlot[i]);
        hash = DSP038HashMix(hash, dsp038BottleOwnerGeneration[i]);
        hash = DSP038HashMix(hash, dsp038BottleOwnerId[i]);
        hash = DSP038HashMix(hash, dsp038BottleTargetSlot[i]);
        hash = DSP038HashMix(hash, dsp038BottleTargetGeneration[i]);
        hash = DSP038HashMix(hash, dsp038BottleTargetId[i]);
        hash = DSP038HashMix(hash, dsp038BottleEmitTic[i]);
        hash = DSP038HashMix(hash, dsp038BottleImpactTic[i]);
        hash = DSP038HashMix(hash, dsp038BottleDepositTic[i]);
        hash = DSP038HashMix(hash, dsp038BottleDurationTics[i]);
        hash = DSP038HashMix(hash, dsp038BottleDamageTenths[i]);
        hash = DSP038HashMix(hash, dsp038BottleMightMilli[i]);
        hash = DSP038HashMix(hash, dsp038BottleAreaMilli[i]);
        hash = DSP038HashMix(hash, dsp038BottleFieldRadiusMilli[i]);
        hash = DSP038HashMix(hash, dsp038BottleRehitTics[i]);
        hash = DSP038HashMix(hash, dsp038BottlePoolLimit[i]);
        hash = DSP038HashMix(hash, dsp038BottleFieldRadiusCapMilli[i]);
        hash = DSP038HashMix(hash, dsp038BottleFieldMotionPolicy[i]);
        hash = DSP038HashMix(hash, dsp038BottleBaselineInwardMilli[i]);
        hash = DSP038HashMix(hash, dsp038BottleFixtureInwardMilli[i]);
        hash = DSP038HashMix(hash, dsp038BottleBaselineGrowthMilli[i]);
        hash = DSP038HashMix(hash, dsp038BottleFixtureGrowthMilli[i]);
        hash = DSP038HashMixDoubleMilli(hash, dsp038BottleStartX[i]);
        hash = DSP038HashMixDoubleMilli(hash, dsp038BottleStartY[i]);
        hash = DSP038HashMixDoubleMilli(hash, dsp038BottleDestinationX[i]);
        hash = DSP038HashMixDoubleMilli(hash, dsp038BottleDestinationY[i]);
        hash = DSP038HashMixDoubleMilli(hash, dsp038BottleX[i]);
        hash = DSP038HashMixDoubleMilli(hash, dsp038BottleY[i]);
        return hash;
    }

    int DSP038HashFieldState(int hash, int i)
    {
        hash = DSP038HashMix(hash, dsp038FieldActive[i]);
        if (dsp038FieldActive[i] == 0) return hash;
        hash = DSP038HashMix(hash, dsp038FieldId[i]);
        hash = DSP038HashMix(hash, dsp038FieldGeneration[i]);
        hash = DSP038HashMix(hash, dsp038FieldSystem[i]);
        hash = DSP038HashMix(hash, dsp038FieldRank[i]);
        hash = DSP038HashMix(hash, dsp038FieldWeaponId[i]);
        hash = DSP038HashMix(hash, dsp038FieldFormGeneration[i]);
        hash = DSP038HashMix(hash, dsp038FieldVolleySerial[i]);
        hash = DSP038HashMix(hash, dsp038FieldBottleOrdinal[i]);
        hash = DSP038HashMix(hash, dsp038FieldOwnerSlot[i]);
        hash = DSP038HashMix(hash, dsp038FieldOwnerGeneration[i]);
        hash = DSP038HashMix(hash, dsp038FieldOwnerId[i]);
        hash = DSP038HashMix(hash, dsp038FieldTargetSlot[i]);
        hash = DSP038HashMix(hash, dsp038FieldTargetGeneration[i]);
        hash = DSP038HashMix(hash, dsp038FieldTargetId[i]);
        hash = DSP038HashMix(hash, dsp038FieldCreatedTic[i]);
        hash = DSP038HashMix(hash, dsp038FieldExpiresTic[i]);
        hash = DSP038HashMix(hash, dsp038FieldDamageTenths[i]);
        hash = DSP038HashMix(hash, dsp038FieldMightMilli[i]);
        hash = DSP038HashMix(hash, dsp038FieldRehitTics[i]);
        hash = DSP038HashMix(hash, dsp038FieldReportedPoolLimit[i]);
        hash = DSP038HashMix(hash, dsp038FieldRadiusCapMilli[i]);
        hash = DSP038HashMix(hash, dsp038FieldMotionPolicy[i]);
        hash = DSP038HashMix(hash, dsp038FieldMoveMilliPerTic[i]);
        hash = DSP038HashMix(hash, dsp038FieldGrowthMilliPerTic[i]);
        hash = DSP038HashMix(hash, dsp038FieldSourceAreaMilli[i]);
        hash = DSP038HashMix(hash, dsp038FieldLastUpdateTic[i]);
        hash = DSP038HashMixDoubleMilli(hash, dsp038FieldX[i]);
        hash = DSP038HashMixDoubleMilli(hash, dsp038FieldY[i]);
        hash = DSP038HashMixDoubleMilli(hash, dsp038FieldRadius[i]);
        hash = DSP038HashMixDoubleMilli(hash, dsp038FieldAnchorX[i]);
        hash = DSP038HashMixDoubleMilli(hash, dsp038FieldAnchorY[i]);
        return hash;
    }

    int DSP038HashTargetLedgerState(int hash, int i)
    {
        hash = DSP038HashMix(hash, dsp038HitFieldId[i]);
        hash = DSP038HashMix(hash, dsp038HitFieldGeneration[i]);
        hash = DSP038HashMix(hash, dsp038HitTargetSlot[i]);
        hash = DSP038HashMix(hash, dsp038HitTargetGeneration[i]);
        hash = DSP038HashMix(hash, dsp038HitTargetId[i]);
        hash = DSP038HashMix(hash, dsp038HitReadyTic[i]);
        return hash;
    }

    int DSP038GroundStateHash()
    {
        int hash = 19;
        hash = DSP038HashMix(hash, dsp038AcceptedHits);
        hash = DSP038HashMix(hash, dsp038AcceptedDamageMilli);
        hash = DSP038HashMix(hash, dsp038RejectedHits);
        hash = DSP038HashMix(hash, dsp038RejectedDamageMilli);
        hash = DSP038HashMix(hash, dsp038RejectedFields);
        hash = DSP038HashMix(hash, dsp038ExpiredFields);
        hash = DSP038HashMix(hash, dsp038DepositedFields);
        hash = DSP038HashMix(hash, dsp038LastAcceptedEventId);
        hash = DSP038HashMix(hash, dsp038LastAcceptedSystemId);
        hash = DSP038HashMix(hash, dsp038LastAcceptedFieldId);
        hash = DSP038HashMix(hash, dsp038LastAcceptedFieldGeneration);
        hash = DSP038HashMix(hash, dsp038NextVolleySerial);
        hash = DSP038HashMix(hash, dsp038NextBottleId);
        hash = DSP038HashMix(hash, dsp038NextBottleGeneration);
        hash = DSP038HashMix(hash, dsp038NextFieldId);
        hash = DSP038HashMix(hash, dsp038NextFieldGeneration);
        hash = DSP038HashMix(hash, dsp038NextEventId);
        hash = DSP038HashMix(hash, dsp038WeaponActive.Size());
        hash = DSP038HashMix(hash, dsp038BottleActive.Size());
        hash = DSP038HashMix(hash, dsp038FieldActive.Size());
        hash = DSP038HashMix(hash, dsp038HitFieldId.Size());
        for (int i = 0; i < dsp038WeaponActive.Size(); i++)
            hash = DSP038HashWeaponState(hash, i);
        for (int i = 0; i < dsp038BottleActive.Size(); i++)
            hash = DSP038HashBottleState(hash, i);
        for (int i = 0; i < dsp038FieldActive.Size(); i++)
            hash = DSP038HashFieldState(hash, i);
        for (int i = 0; i < dsp038HitFieldId.Size(); i++)
            hash = DSP038HashTargetLedgerState(hash, i);
        return hash;
    }

    // mightMilli/cooldownMultiplierMilli are caller-resolved (every other
    // engine's own Process*Tic already takes these the same way -- see
    // ProcessOwnedWeapons/ProcessP038GroundWeapons): this used to call
    // DSP033Resolved() directly here instead, which returns 0 whenever
    // dsp033ResolvedValid is false (DSP033Resolved's own STAT_MIGHT/
    // STAT_COOLDOWN branch), silently early-returning every tic and never
    // firing a single Holy Water volley whenever P033 hasn't run --
    // exactly the case for the N2 dispatcher's manual/soak_n2 route, where
    // p033RouteEnabled (and so dsp033ResolvedValid) is never set, unlike
    // every pNNN opt-in route (p034..p041 all cascade p033RouteEnabled on).
    void DSP038ProcessGroundTic(int logicalTic, double playerX,
        double playerY, int mightMilli, int cooldownMultiplierMilli)
    {
        if (logicalTic < 0 || mightMilli < 1 || cooldownMultiplierMilli < 1)
            return;
        DSP038AdvanceWeapons(logicalTic, playerX, playerY, mightMilli,
            cooldownMultiplierMilli);
        DSP038AdvanceBottles(logicalTic);
        DSP038AdvanceFields(logicalTic, playerX, playerY);
    }

    void DSP038AdvanceWeapons(int logicalTic, double playerX, double playerY,
        int mightMilli, int cooldownMultiplierMilli)
    {
        for (int weapon = 0; weapon < dsp038WeaponActive.Size(); weapon++)
        {
            if (dsp038WeaponActive[weapon] == 0) continue;
            int ownerSlot = dsp038WeaponOwnerSlots[weapon];
            int ownerGeneration = dsp038WeaponOwnerGenerations[weapon];
            int ownerId = dsp038WeaponOwnerIds[weapon];
            if (!ValidParts(ownerSlot, ownerGeneration, ownerId)
                || kinds[ownerSlot] != 99)
            {
                dsp038WeaponActive[weapon] = 0;
                continue;
            }
            dsp038WeaponMightMilli[weapon] = LbMightFor(dsp038WeaponSystem[weapon], mightMilli);
            if (rsActive) dsp038WeaponAreaAdjustments[weapon] = RsAreaFor(dsp038WeaponSystem[weapon]);
            dsp038WeaponCooldownMultiplierMilli[weapon] = cooldownMultiplierMilli;
            if (dsp038WeaponVolleyRemaining[weapon] == 0
                && logicalTic >= dsp038WeaponNextAttackTics[weapon])
            {
                if (!DSP038BeginVolley(weapon, logicalTic)) continue;
            }
            if (dsp038WeaponVolleyRemaining[weapon] <= 0
                || logicalTic < dsp038WeaponNextBottleTics[weapon]) continue;
            double ownerX = x[ownerSlot]; double ownerY = y[ownerSlot];
            if (DSP038EmitBottle(weapon, logicalTic, ownerX, ownerY))
            {
                dsp038WeaponVolleyRemaining[weapon]--;
                dsp038WeaponVolleyOrdinal[weapon]++;
                int ignored; int sectors; int ring; int targetRange;
                int flight; int deposit; int baseRadius; int motion;
                int baselineMove; int fixtureMove; int baselineGrowth;
                int fixtureGrowth; int radiusCap; int hitGate; int poolPolicy;
                int clockwise; int sectorZero;
                DSP038GroundRows.TryGetAdapterProfile(
                    dsp038WeaponSystem[weapon], ignored, sectors, ring,
                    targetRange, flight, deposit, baseRadius, motion,
                    baselineMove, fixtureMove, baselineGrowth, fixtureGrowth,
                    radiusCap, hitGate, poolPolicy, clockwise, sectorZero);
                int delayMs; int pool; int projectileSpeed; int moveSpeed;
                int wall; int damage; int area; int amount; int durationMs;
                int cooldownMs; int intervalMs;
                DSP038GroundRows.TryGetRankRow(dsp038WeaponSystem[weapon],
                    dsp038WeaponRank[weapon], damage, area, amount,
                    durationMs, cooldownMs, intervalMs, delayMs, pool,
                    projectileSpeed, moveSpeed, wall);
                int intervalTics;
                if (!DSP038GroundMath.MillisecondsToTicsNearest(intervalMs,
                    Thinker.TICRATE, intervalTics)) intervalTics = 1;
                if (intervalTics < 1) intervalTics = 1;
                dsp038WeaponNextBottleTics[weapon] = logicalTic + intervalTics;
            }
        }
    }

    bool DSP038BeginVolley(int weapon, int logicalTic)
    {
        int damage; int area; int amount; int durationMs; int cooldownMs;
        int intervalMs; int delayMs; int pool; int projectileSpeed;
        int moveSpeed; int wall;
        if (!DSP038GroundRows.TryGetRankRow(dsp038WeaponSystem[weapon],
            dsp038WeaponRank[weapon], damage, area, amount, durationMs,
            cooldownMs, intervalMs, delayMs, pool, projectileSpeed,
            moveSpeed, wall) || amount < 1 || amount > 64)
        {
            Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P038_ROW_INVALID weapon_id=%d system_id=%d rank=%d", dsp038WeaponIds[weapon], dsp038WeaponSystem[weapon], dsp038WeaponRank[weapon]);
            return false;
        }
        int scaledCooldown = DSP033StatRules.CooldownAfterTome(
            dsp038WeaponSystem[weapon], cooldownMs,
            dsp038WeaponCooldownMultiplierMilli[weapon]);
        int cooldownTics;
        if (!DSP038GroundMath.MillisecondsToTicsNearest(scaledCooldown,
            Thinker.TICRATE, cooldownTics) || cooldownTics < 1)
            return false;
        int serial = dsp038NextVolleySerial++;
        if (dsp038NextVolleySerial <= 0) dsp038NextVolleySerial = 1;
        dsp038WeaponVolleyRemaining[weapon] = rsActive ? amount + RsAmountFor(dsp038WeaponSystem[weapon]) : amount;
        dsp038WeaponVolleyOrdinal[weapon] = 0;
        dsp038WeaponVolleySerials[weapon] = serial;
        dsp038WeaponNextBottleTics[weapon] = logicalTic;
        dsp038WeaponNextAttackTics[weapon] = logicalTic + cooldownTics;
        DSSound.Weapon(dsp038WeaponSystem[weapon]);
        { if (!dsQuiet) Console.Printf("DS_P038_VOLLEY accepted=1 event_id=%d tic=%d system_id=%d rank=%d weapon_id=%d weapon_generation=%d form_generation=%d volley_serial=%d amount=%d damage_tenths=%d area_milli=%d duration_ms=%d cooldown_ms=%d cooldown_tics=%d might_milli=%d", DSP038NewEventId(), logicalTic, dsp038WeaponSystem[weapon], dsp038WeaponRank[weapon], dsp038WeaponIds[weapon], dsp038WeaponGenerations[weapon], dsp038WeaponFormGenerations[weapon], serial, amount, damage, area, durationMs, scaledCooldown, cooldownTics, dsp038WeaponMightMilli[weapon]); }
        return true;
    }

    bool DSP038FindNearestGroundTarget(double originX, double originY,
        double radius, out int bestSlot, out int bestGeneration,
        out int bestId, out double bestX, out double bestY)
    {
        bestSlot = -1; bestGeneration = 0; bestId = 0;
        bestX = originX; bestY = originY;
        double bestDistance = 0.0;
        DSP024RadiusCandidates(originX, originY, radius);
        for (int candidate = 0; candidate < spatialCandidateCount; candidate++)
        {
            int slot = spatialCandidateSlots[candidate];
            int generation = spatialCandidateGenerations[candidate];
            int stableId = spatialCandidateIds[candidate];
            if (!ValidParts(slot, generation, stableId)
                || kinds[slot] != DSP038_KIND_ENEMY || health[slot] <= 0)
                continue;
            double dx = x[slot] - originX; double dy = y[slot] - originY;
            double distance = dx * dx + dy * dy;
            if (distance > radius * radius) continue;
            if (DSP038GroundMath.NearestPrecedes(distance, stableId,
                bestDistance, bestId, bestSlot >= 0)
                || (bestSlot >= 0 && distance == bestDistance
                    && stableId == bestId
                    && (generation < bestGeneration
                        || (generation == bestGeneration && slot < bestSlot))))
            {
                bestSlot = slot; bestGeneration = generation; bestId = stableId;
                bestDistance = distance; bestX = x[slot]; bestY = y[slot];
            }
        }
        return bestSlot >= 0;
    }

    int DSP038NewEventId()
    {
        int eventId = dsp038NextEventId++;
        if (dsp038NextEventId <= 0) dsp038NextEventId = 1;
        if (eventId <= 0) eventId = dsp038NextEventId;
        return eventId;
    }

    int DSP038NewBottleId()
    {
        int id = dsp038NextBottleId++;
        if (dsp038NextBottleId <= 0)
        { dsp038NextBottleId = 1; dsp038NextBottleGeneration++; }
        if (dsp038NextBottleGeneration <= 0) dsp038NextBottleGeneration = 1;
        return id;
    }

    int DSP038NewFieldId()
    {
        int id = dsp038NextFieldId++;
        if (dsp038NextFieldId <= 0)
        { dsp038NextFieldId = 1; dsp038NextFieldGeneration++; }
        if (dsp038NextFieldGeneration <= 0) dsp038NextFieldGeneration = 1;
        return id;
    }

    bool DSP038EmitBottle(int weapon, int logicalTic,
        double ownerX, double ownerY)
    {
        int systemId = dsp038WeaponSystem[weapon];
        int rank = dsp038WeaponRank[weapon];
        int damage; int rowArea; int amount; int durationMs; int cooldownMs;
        int intervalMs; int sourceDelayMs; int rowPool; int projectileSpeed;
        int moveSpeed; int wall;
        if (!DSP038GroundRows.TryGetRankRow(systemId, rank, damage, rowArea,
            amount, durationMs, cooldownMs, intervalMs, sourceDelayMs,
            rowPool, projectileSpeed, moveSpeed, wall)) return false;
        int placement; int sectors; int ringMilli; int targetRangeMilli;
        int flightTics; int depositTics; int baseRadiusMilli; int motion;
        int baselineMove; int fixtureMove; int baselineGrowth;
        int fixtureGrowth; int capMilli; int rehitTics; int poolPolicy;
        int clockwise; int zeroPositiveX;
        if (!DSP038GroundRows.TryGetAdapterProfile(systemId, placement,
            sectors, ringMilli, targetRangeMilli, flightTics, depositTics,
            baseRadiusMilli, motion, baselineMove, fixtureMove,
            baselineGrowth, fixtureGrowth, capMilli, rehitTics,
            poolPolicy, clockwise, zeroPositiveX)
            || sectors <= 0 || flightTics <= 0 || depositTics < 0)
            return false;
        int ordinal = dsp038WeaponVolleyOrdinal[weapon];
        int volley = dsp038WeaponVolleySerials[weapon];
        int targetSlot = -1; int targetGeneration = 0; int targetId = 0;
        double destinationX = ownerX; double destinationY = ownerY;
        bool nearest = systemId == DSP038GroundRows.SYSTEM_HOLYWATER
            && amount < 4 && ordinal == 0;
        if (nearest && DSP038FindNearestGroundTarget(ownerX, ownerY,
            double(targetRangeMilli) / 1000.0, targetSlot,
            targetGeneration, targetId, destinationX, destinationY))
        {
            // The first sub-four-bottle Holy Water emission captures the
            // nearest live logical handle; subsequent bottles never retarget.
        }
        else
        {
            int sector = (ordinal + volley - 1) % sectors;
            if (sector < 0) sector += sectors;
            int sign = clockwise != 0 ? -1 : 1;
            double angle = double(sector * 360 * sign) / double(sectors);
            destinationX = ownerX + double(ringMilli) / 1000.0 * cos(angle);
            destinationY = ownerY + double(ringMilli) / 1000.0 * sin(angle);
        }
        int durationTics; int ignoredCooldownTics;
        int scaledDuration = rsActive ? durationMs * RsDurationFor(systemId) / 1000 : durationMs;
        if (!DSP038GroundMath.MillisecondsToTicsNearest(scaledDuration,
            Thinker.TICRATE, durationTics) || durationTics < 1) return false;
        int areaMilli;
        if (!DSP038GroundMath.CheckedScaleMilli(rowArea,
            dsp038WeaponAreaAdjustments[weapon], areaMilli)) return false;
        int fieldRadiusMilli;
        if (!DSP038GroundMath.CheckedScaleMilli(baseRadiusMilli,
            areaMilli, fieldRadiusMilli)) return false;
        int moveMilli = baselineMove;
        int growthMilli = baselineGrowth;
        if (systemId == DSP038GroundRows.SYSTEM_BORA)
        {
            if (dsp038WeaponSpeedAdjustments[weapon] > 1000
                || dsp038WeaponMoveSpeedAdjustments[weapon] > 1000)
                moveMilli = fixtureMove;
            if (dsp038WeaponSpeedAdjustments[weapon] > 1000
                || dsp038WeaponMoveSpeedAdjustments[weapon] > 1000
                || dsp038WeaponGrowthAdjustments[weapon] > 1000)
                growthMilli = fixtureGrowth;
            if (growthMilli > 0 && capMilli > 0)
                fieldRadiusMilli = fieldRadiusMilli < capMilli
                    ? fieldRadiusMilli : capMilli;
        }
        int bottleId = DSP038NewBottleId();
        int bottleGeneration = dsp038NextBottleGeneration;
        dsp038BottleActive.Push(1); dsp038BottleId.Push(bottleId);
        dsp038BottleGeneration.Push(bottleGeneration);
        dsp038BottleSystem.Push(systemId); dsp038BottleRank.Push(rank);
        dsp038BottleWeaponId.Push(dsp038WeaponIds[weapon]);
        dsp038BottleFormGeneration.Push(dsp038WeaponFormGenerations[weapon]);
        dsp038BottleVolleySerial.Push(volley); dsp038BottleOrdinal.Push(ordinal);
        dsp038BottleOwnerSlot.Push(dsp038WeaponOwnerSlots[weapon]);
        dsp038BottleOwnerGeneration.Push(dsp038WeaponOwnerGenerations[weapon]);
        dsp038BottleOwnerId.Push(dsp038WeaponOwnerIds[weapon]);
        dsp038BottleTargetSlot.Push(targetSlot);
        dsp038BottleTargetGeneration.Push(targetGeneration);
        dsp038BottleTargetId.Push(targetId);
        dsp038BottleEmitTic.Push(logicalTic);
        dsp038BottleImpactTic.Push(logicalTic + flightTics);
        dsp038BottleDepositTic.Push(logicalTic + flightTics + depositTics);
        dsp038BottleDurationTics.Push(durationTics);
        dsp038BottleDamageTenths.Push(damage);
        dsp038BottleMightMilli.Push(dsp038WeaponMightMilli[weapon]);
        dsp038BottleAreaMilli.Push(areaMilli); dsp038BottleRehitTics.Push(rehitTics);
        dsp038BottleFieldRadiusMilli.Push(fieldRadiusMilli);
        dsp038BottlePoolLimit.Push(rowPool);
        dsp038BottleFieldRadiusCapMilli.Push(capMilli);
        dsp038BottleFieldMotionPolicy.Push(motion);
        dsp038BottleBaselineInwardMilli.Push(moveMilli);
        dsp038BottleFixtureInwardMilli.Push(fixtureMove);
        dsp038BottleBaselineGrowthMilli.Push(growthMilli);
        dsp038BottleFixtureGrowthMilli.Push(fixtureGrowth);
        dsp038BottleStartX.Push(ownerX); dsp038BottleStartY.Push(ownerY);
        dsp038BottleDestinationX.Push(destinationX);
        dsp038BottleDestinationY.Push(destinationY);
        dsp038BottleX.Push(ownerX); dsp038BottleY.Push(ownerY);
        int eventId = DSP038NewEventId();
        { if (!dsQuiet) Console.Printf("DS_P038_BOTTLE_EMIT accepted=1 event_id=%d tic=%d bottle_id=%d bottle_generation=%d system_id=%d rank=%d weapon_id=%d form_generation=%d volley_serial=%d ordinal=%d owner_slot=%d owner_generation=%d owner_id=%d target_slot=%d target_generation=%d target_id=%d placement=%s start_x=%.3f start_y=%.3f destination_x=%.3f destination_y=%.3f flight_tics=%d deposit_tic=%d area_milli=%d radius_milli=%d damage_tenths=%d might_milli=%d move_milli_per_tic=%d growth_milli_per_tic=%d", eventId, logicalTic, bottleId, bottleGeneration, systemId, rank, dsp038WeaponIds[weapon], dsp038WeaponFormGenerations[weapon], volley, ordinal, dsp038WeaponOwnerSlots[weapon], dsp038WeaponOwnerGenerations[weapon], dsp038WeaponOwnerIds[weapon], targetSlot, targetGeneration, targetId, targetId > 0 ? "NEAREST_CAPTURED" : "SIX_SECTOR_RING", ownerX, ownerY, destinationX, destinationY, flightTics, logicalTic + flightTics + depositTics, areaMilli, fieldRadiusMilli, damage, dsp038WeaponMightMilli[weapon], moveMilli, growthMilli); }
        return true;
    }

    void DSP038AdvanceBottles(int logicalTic)
    {
        for (int bottle = 0; bottle < dsp038BottleActive.Size(); bottle++)
        {
            if (dsp038BottleActive[bottle] == 0) continue;
            int impact = dsp038BottleImpactTic[bottle];
            int emitted = dsp038BottleEmitTic[bottle];
            int flight = impact - emitted;
            double fraction = flight > 0
                ? double(logicalTic - emitted) / double(flight) : 1.0;
            if (fraction < 0.0) fraction = 0.0;
            if (fraction > 1.0) fraction = 1.0;
            dsp038BottleX[bottle] = dsp038BottleStartX[bottle]
                + (dsp038BottleDestinationX[bottle]
                    - dsp038BottleStartX[bottle]) * fraction;
            dsp038BottleY[bottle] = dsp038BottleStartY[bottle]
                + (dsp038BottleDestinationY[bottle]
                    - dsp038BottleStartY[bottle]) * fraction;
            if (logicalTic < dsp038BottleDepositTic[bottle]) continue;
            DSP038DepositField(bottle, logicalTic);
            dsp038BottleActive[bottle] = 0;
        }
    }

    int DSP038ActiveFieldsForSystem(int systemId)
    {
        int activeCount = 0;
        for (int i = 0; i < dsp038FieldActive.Size(); i++)
            if (dsp038FieldActive[i] != 0
                && dsp038FieldSystem[i] == systemId) activeCount++;
        return activeCount;
    }

    void DSP038DepositField(int bottle, int logicalTic)
    {
        int systemId = dsp038BottleSystem[bottle];
        int fieldLimit = dsp038BottlePoolLimit[bottle];
        int activeCount = DSP038ActiveFieldsForSystem(systemId);
        if (fieldLimit <= 0 || activeCount >= fieldLimit)
        {
            dsp038RejectedFields++;
            Console.Printf("DS_P038_FIELD_REJECT accepted=0 reason=REPORTED_POOL_BOUND tic=%d bottle_id=%d system_id=%d active_fields=%d reported_limit=%d policy=REJECT_AND_MARK", logicalTic, dsp038BottleId[bottle], systemId, activeCount, fieldLimit);
            return;
        }
        int id = DSP038NewFieldId(); int generation = dsp038NextFieldGeneration;
        int expires = logicalTic + dsp038BottleDurationTics[bottle];
        double fieldX = dsp038BottleDestinationX[bottle];
        double fieldY = dsp038BottleDestinationY[bottle];
        double fieldRadius = double(dsp038BottleAreaMilli[bottle]) / 1000.0
            * 20.0;
        // Profile's base radius is captured explicitly by EmitBottle below;
        // retain compatibility for a zero/uninitialized radius by the
        // canonical field-radius snapshot written alongside the bottle.
        if (bottle < dsp038BottleFieldRadiusMilli.Size())
            fieldRadius = double(dsp038BottleFieldRadiusMilli[bottle]) / 1000.0;
        dsp038FieldActive.Push(1); dsp038FieldId.Push(id);
        dsp038FieldGeneration.Push(generation);
        dsp038FieldSystem.Push(systemId); dsp038FieldRank.Push(dsp038BottleRank[bottle]);
        dsp038FieldWeaponId.Push(dsp038BottleWeaponId[bottle]);
        dsp038FieldFormGeneration.Push(dsp038BottleFormGeneration[bottle]);
        dsp038FieldVolleySerial.Push(dsp038BottleVolleySerial[bottle]);
        dsp038FieldBottleOrdinal.Push(dsp038BottleOrdinal[bottle]);
        dsp038FieldOwnerSlot.Push(dsp038BottleOwnerSlot[bottle]);
        dsp038FieldOwnerGeneration.Push(dsp038BottleOwnerGeneration[bottle]);
        dsp038FieldOwnerId.Push(dsp038BottleOwnerId[bottle]);
        dsp038FieldTargetSlot.Push(dsp038BottleTargetSlot[bottle]);
        dsp038FieldTargetGeneration.Push(dsp038BottleTargetGeneration[bottle]);
        dsp038FieldTargetId.Push(dsp038BottleTargetId[bottle]);
        dsp038FieldCreatedTic.Push(logicalTic); dsp038FieldExpiresTic.Push(expires);
        dsp038FieldDamageTenths.Push(dsp038BottleDamageTenths[bottle]);
        dsp038FieldMightMilli.Push(dsp038BottleMightMilli[bottle]);
        dsp038FieldRehitTics.Push(dsp038BottleRehitTics[bottle]);
        dsp038FieldReportedPoolLimit.Push(fieldLimit);
        dsp038FieldRadiusCapMilli.Push(dsp038BottleFieldRadiusCapMilli[bottle]);
        dsp038FieldMotionPolicy.Push(dsp038BottleFieldMotionPolicy[bottle]);
        dsp038FieldMoveMilliPerTic.Push(dsp038BottleBaselineInwardMilli[bottle]);
        dsp038FieldGrowthMilliPerTic.Push(dsp038BottleBaselineGrowthMilli[bottle]);
        dsp038FieldSourceAreaMilli.Push(dsp038BottleAreaMilli[bottle]);
        dsp038FieldLastUpdateTic.Push(logicalTic);
        dsp038FieldX.Push(fieldX); dsp038FieldY.Push(fieldY);
        dsp038FieldRadius.Push(fieldRadius);
        dsp038FieldAnchorX.Push(fieldX); dsp038FieldAnchorY.Push(fieldY);
        dsp038DepositedFields++;
        { if (!dsQuiet) Console.Printf("DS_P038_FIELD_CREATE accepted=1 tic=%d field_id=%d field_generation=%d source_system=%d rank=%d weapon_id=%d form_generation=%d bottle_id=%d volley_serial=%d ordinal=%d target_id=%d x=%.3f y=%.3f radius=%.3f duration_tics=%d expires_tic=%d hit_gate_tics=%d motion=%d move_milli_per_tic=%d growth_milli_per_tic=%d pool_count=%d pool_limit=%d", logicalTic, id, generation, systemId, dsp038BottleRank[bottle], dsp038BottleWeaponId[bottle], dsp038BottleFormGeneration[bottle], dsp038BottleId[bottle], dsp038BottleVolleySerial[bottle], dsp038BottleOrdinal[bottle], dsp038BottleTargetId[bottle], fieldX, fieldY, fieldRadius, dsp038BottleDurationTics[bottle], expires, dsp038BottleRehitTics[bottle], dsp038BottleFieldMotionPolicy[bottle], dsp038BottleBaselineInwardMilli[bottle], dsp038BottleBaselineGrowthMilli[bottle], activeCount + 1, fieldLimit); }
    }

    void DSP038AdvanceFields(int logicalTic, double playerX, double playerY)
    {
        for (int field = 0; field < dsp038FieldActive.Size(); field++)
        {
            if (dsp038FieldActive[field] == 0) continue;
            if (logicalTic >= dsp038FieldExpiresTic[field])
            {
                dsp038FieldActive[field] = 0; dsp038ExpiredFields++;
                { if (!dsQuiet) Console.Printf("DS_P038_FIELD_EXPIRE tic=%d field_id=%d field_generation=%d system_id=%d age_tics=%d", logicalTic, dsp038FieldId[field], dsp038FieldGeneration[field], dsp038FieldSystem[field], logicalTic - dsp038FieldCreatedTic[field]); }
                continue;
            }
            if (logicalTic <= dsp038FieldLastUpdateTic[field])
            {
                DSP038SweepField(field, logicalTic,
                    dsp038FieldX[field], dsp038FieldY[field],
                    dsp038FieldX[field], dsp038FieldY[field]);
                continue;
            }
            int deltaTics = logicalTic - dsp038FieldLastUpdateTic[field];
            for (int step = 0; step < deltaTics; step++)
            {
                double oldX = dsp038FieldX[field];
                double oldY = dsp038FieldY[field];
                if (dsp038FieldMotionPolicy[field]
                    == DSP038GroundRows.FIELD_INWARD_PLAYER)
                {
                    double dx = playerX - oldX; double dy = playerY - oldY;
                    double distance = sqrt(dx * dx + dy * dy);
                    double movement = double(dsp038FieldMoveMilliPerTic[field])
                        / 1000.0;
                    if (distance > 0.0 && movement > 0.0)
                    {
                        double fraction = movement >= distance ? 1.0
                            : movement / distance;
                        dsp038FieldX[field] += dx * fraction;
                        dsp038FieldY[field] += dy * fraction;
                    }
                    if (dsp038FieldGrowthMilliPerTic[field] > 0)
                    {
                        dsp038FieldRadius[field] += double(
                            dsp038FieldGrowthMilliPerTic[field]) / 1000.0;
                        int capMilli = dsp038FieldRadiusCapMilli[field];
                        if (capMilli > 0
                            && dsp038FieldRadius[field] > double(capMilli) / 1000.0)
                            dsp038FieldRadius[field] = double(capMilli) / 1000.0;
                    }
                }
                dsp038FieldAnchorX[field] = playerX;
                dsp038FieldAnchorY[field] = playerY;
                DSP038SweepField(field, logicalTic, oldX, oldY,
                    dsp038FieldX[field], dsp038FieldY[field]);
            }
            dsp038FieldLastUpdateTic[field] = logicalTic;
        }
    }

    int DSP038FindFieldTargetHit(int fieldId, int fieldGeneration,
        int slot, int targetGeneration, int stableId)
    {
        for (int i = 0; i < dsp038HitFieldId.Size(); i++)
            if (dsp038HitFieldId[i] == fieldId
                && dsp038HitFieldGeneration[i] == fieldGeneration
                && dsp038HitTargetSlot[i] == slot
                && dsp038HitTargetGeneration[i] == targetGeneration
                && dsp038HitTargetId[i] == stableId) return i;
        return -1;
    }

    bool DSP038CanHitFieldTarget(int field, int slot,
        int targetGeneration, int stableId, int logicalTic)
    {
        int hit = DSP038FindFieldTargetHit(dsp038FieldId[field],
            dsp038FieldGeneration[field], slot, targetGeneration, stableId);
        return hit < 0 || logicalTic >= dsp038HitReadyTic[hit];
    }

    bool DSP038RecordFieldTargetHit(int field, int slot,
        int targetGeneration, int stableId, int logicalTic)
    {
        int hit = DSP038FindFieldTargetHit(dsp038FieldId[field],
            dsp038FieldGeneration[field], slot, targetGeneration, stableId);
        int ready = logicalTic + dsp038FieldRehitTics[field];
        if (hit >= 0)
        { dsp038HitReadyTic[hit] = ready; return true; }
        dsp038HitFieldId.Push(dsp038FieldId[field]);
        dsp038HitFieldGeneration.Push(dsp038FieldGeneration[field]);
        dsp038HitTargetSlot.Push(slot); dsp038HitTargetGeneration.Push(targetGeneration);
        dsp038HitTargetId.Push(stableId); dsp038HitReadyTic.Push(ready);
        return true;
    }

    void DSP038SweepField(int field, int logicalTic,
        double startX, double startY, double endX, double endY)
    {
        double sweepRadius = dsp038FieldRadius[field];
        DSP024SweptCandidates(startX, startY, endX, endY, sweepRadius);
        dsp038ContactDistanceSquared.Clear(); dsp038ContactFractions.Clear();
        dsp038ContactSlots.Clear(); dsp038ContactGenerations.Clear();
        dsp038ContactIds.Clear();
        for (int candidate = 0; candidate < spatialCandidateCount; candidate++)
        {
            int slot = spatialCandidateSlots[candidate];
            int generation = spatialCandidateGenerations[candidate];
            int stableId = spatialCandidateIds[candidate];
            if (!ValidParts(slot, generation, stableId)
                || kinds[slot] != DSP038_KIND_ENEMY || health[slot] <= 0
                || collisionRadii[slot] < 0.0) continue;
            double fraction; double distanceSquared;
            if (!DSP038GroundMath.SegmentCircleContact(startX, startY,
                endX, endY, sweepRadius, x[slot], y[slot],
                collisionRadii[slot], fraction, distanceSquared)) continue;
            dsp038ContactFractions.Push(fraction);
            dsp038ContactDistanceSquared.Push(distanceSquared);
            dsp038ContactSlots.Push(slot); dsp038ContactGenerations.Push(generation);
            dsp038ContactIds.Push(stableId);
        }
        DSP038SortContacts();
        for (int i = 0; i < dsp038ContactSlots.Size(); i++)
        {
            int slot = dsp038ContactSlots[i];
            int generation = dsp038ContactGenerations[i];
            int stableId = dsp038ContactIds[i];
            if (!ValidParts(slot, generation, stableId)
                || kinds[slot] != DSP038_KIND_ENEMY || health[slot] <= 0
                || !DSP038CanHitFieldTarget(field, slot, generation,
                    stableId, logicalTic)) continue;
            int scaledTenths;
            bool checked = DSP025CheckedDamage(
                dsp038FieldDamageTenths[field], 0,
                dsp038FieldMightMilli[field], scaledTenths)
                && scaledTenths >= 0
                && scaledTenths <= DSP038_MAX_SAFE_DAMAGE_TENTHS;
            int damageMilli = checked ? scaledTenths * 100 : 0;
            int before; int after; int killed;
            if (!checked || !DSP025ApplyLogicalHit(slot, generation,
                stableId, damageMilli, before, after, killed))
            { dsp038RejectedHits++; continue; }
            if (!DSP038RecordFieldTargetHit(field, slot, generation,
                stableId, logicalTic))
            {
                Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P038_LEDGER_CAP tic=%d field_id=%d target_id=%d", logicalTic, dsp038FieldId[field], stableId);
                continue;
            }
            int delta = before - after;
            if (delta < 0 || dsp038AcceptedDamageMilli > 2147483647 - delta)
                Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P038_DAMAGE_OVERFLOW tic=%d", logicalTic);
            else dsp038AcceptedDamageMilli += delta;
            int eventId = DSP038NewEventId(); dsp038AcceptedHits++;
            dsp038LastAcceptedEventId = eventId;
            dsp038LastAcceptedSystemId = dsp038FieldSystem[field];
            dsp038LastAcceptedFieldId = dsp038FieldId[field];
            dsp038LastAcceptedFieldGeneration = dsp038FieldGeneration[field];
            { if (!dsQuiet) Console.Printf("DS_P038_FIELD_HIT accepted=1 authority=P025_CHECKED_LOGICAL_HIT event_id=%d tic=%d field_id=%d field_generation=%d source_system=%d rank=%d weapon_id=%d form_generation=%d volley_serial=%d target_slot=%d target_generation=%d target_id=%d fraction=%.6f field_x=%.3f field_y=%.3f radius=%.3f damage_tenths=%d might_milli=%d damage_milli=%d before=%d after=%d accepted_delta_milli=%d ready_tic=%d", eventId, logicalTic, dsp038FieldId[field], dsp038FieldGeneration[field], dsp038FieldSystem[field], dsp038FieldRank[field], dsp038FieldWeaponId[field], dsp038FieldFormGeneration[field], dsp038FieldVolleySerial[field], slot, generation, stableId, dsp038ContactFractions[i], endX, endY, dsp038FieldRadius[field], dsp038FieldDamageTenths[field], dsp038FieldMightMilli[field], damageMilli, before, after, delta, logicalTic + dsp038FieldRehitTics[field]); }
            if (killed != 0) HandleEnemyDeath(slot, before, eventId);
        }
    }

    void DSP038SortContacts()
    {
        for (int i = 1; i < dsp038ContactSlots.Size(); i++)
        {
            int j = i;
            while (j > 0 && DSP038ContactPrecedes(j, j - 1))
            {
                double valueD = dsp038ContactFractions[j];
                dsp038ContactFractions[j] = dsp038ContactFractions[j - 1];
                dsp038ContactFractions[j - 1] = valueD;
                valueD = dsp038ContactDistanceSquared[j];
                dsp038ContactDistanceSquared[j] = dsp038ContactDistanceSquared[j - 1];
                dsp038ContactDistanceSquared[j - 1] = valueD;
                int value = dsp038ContactSlots[j];
                dsp038ContactSlots[j] = dsp038ContactSlots[j - 1];
                dsp038ContactSlots[j - 1] = value;
                value = dsp038ContactGenerations[j];
                dsp038ContactGenerations[j] = dsp038ContactGenerations[j - 1];
                dsp038ContactGenerations[j - 1] = value;
                value = dsp038ContactIds[j];
                dsp038ContactIds[j] = dsp038ContactIds[j - 1];
                dsp038ContactIds[j - 1] = value;
                j--;
            }
        }
    }

    bool DSP038ContactPrecedes(int first, int second)
    {
        if (dsp038ContactFractions[first] != dsp038ContactFractions[second])
            return dsp038ContactFractions[first] < dsp038ContactFractions[second];
        if (dsp038ContactIds[first] != dsp038ContactIds[second])
            return dsp038ContactIds[first] < dsp038ContactIds[second];
        if (dsp038ContactGenerations[first] != dsp038ContactGenerations[second])
            return dsp038ContactGenerations[first] < dsp038ContactGenerations[second];
        return dsp038ContactSlots[first] < dsp038ContactSlots[second];
    }
}
