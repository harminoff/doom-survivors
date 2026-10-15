// P037 persistent orbit-member state and member-owned target cooldown ledger.
// The host EventHandler serializes these non-transient arrays with the existing
// P029 run save; a restore must not call DSP037ResetOrbitRuntime.
mixin class DSP037OrbitRuntime
{
    const DSP037_SYSTEM_KING_BIBLE = 44;
    const DSP037_SYSTEM_UNHOLY_VESPERS = 45;
    const DSP037_ENEMY_KIND = 1;

    // One serialized scheduler row per logical weapon handle. These are the
    // canonical clocks; member rows are only the active-window projections.
    Array<int> dsp037WeaponActive;
    Array<int> dsp037WeaponSlots;
    Array<int> dsp037WeaponGenerations;
    Array<int> dsp037WeaponIds;
    Array<int> dsp037WeaponSystems;
    Array<int> dsp037WeaponRanks;
    Array<int> dsp037WeaponFormGenerations;
    Array<int> dsp037WeaponOwnerSlots;
    Array<int> dsp037WeaponOwnerGenerations;
    Array<int> dsp037WeaponOwnerIds;
    Array<int> dsp037WeaponFirstFireTics;
    Array<int> dsp037WeaponNextActivationTics;
    Array<int> dsp037WeaponPhaseStarted;
    Array<int> dsp037WeaponPhaseMicroRadians;
    Array<int> dsp037WeaponPhaseRemainders;
    Array<int> dsp037WeaponLastPhaseTics;
    Array<int> dsp037WeaponAreaAdjustments;
    Array<int> dsp037WeaponSpeedAdjustments;
    Array<int> dsp037WeaponFixturePoolCaps;
    Array<int> dsp037WeaponNextCohortIds;
    Array<int> dsp037WeaponCohortGenerations;

    Array<int> dsp037MemberActive;
    Array<int> dsp037MemberWeaponSlots;
    Array<int> dsp037MemberWeaponGenerations;
    Array<int> dsp037MemberWeaponIds;
    Array<int> dsp037MemberSystemIds;
    Array<int> dsp037MemberRanks;
    Array<int> dsp037MemberFormGenerations;
    Array<int> dsp037MemberCohortIds;
    Array<int> dsp037MemberCohortGenerations;
    Array<int> dsp037MemberOrdinals;
    Array<int> dsp037MemberGenerations;
    Array<int> dsp037MemberOwnerSlots;
    Array<int> dsp037MemberOwnerGenerations;
    Array<int> dsp037MemberOwnerIds;
    Array<int> dsp037MemberWindowStartTics;
    Array<int> dsp037MemberWindowEndTics;
    Array<int> dsp037MemberLastPhaseTics;
    Array<int> dsp037MemberPhaseMicroRadians;
    Array<int> dsp037MemberPhaseRemainders;
    Array<int> dsp037MemberAngularRatesMilliRadians;
    Array<int> dsp037MemberCounts;
    Array<int> dsp037MemberRadiusMilliUnits;
    Array<int> dsp037MemberContactRadiusMilliUnits;
    Array<int> dsp037MemberMaxSubstepMilliDegrees;
    Array<int> dsp037MemberHitGateTics;
    Array<int> dsp037MemberDamageTenths;
    Array<int> dsp037MemberMightMilli;
    Array<double> dsp037MemberAnchorX;
    Array<double> dsp037MemberAnchorY;
    Array<double> dsp037MemberX;
    Array<double> dsp037MemberY;

    // Cooldown ownership is per exact member instance and full target handle.
    // Two overlapping cohorts or members cannot share one another's deadline.
    Array<int> dsp037HitWeaponSlots;
    Array<int> dsp037HitWeaponGenerations;
    Array<int> dsp037HitWeaponIds;
    Array<int> dsp037HitFormGenerations;
    Array<int> dsp037HitCohortIds;
    Array<int> dsp037HitCohortGenerations;
    Array<int> dsp037HitMemberOrdinals;
    Array<int> dsp037HitMemberGenerations;
    Array<int> dsp037HitTargetSlots;
    Array<int> dsp037HitTargetGenerations;
    Array<int> dsp037HitTargetIds;
    Array<int> dsp037HitReadyTics;
    Array<double> dsp037ContactFractions;
    Array<int> dsp037ContactSlots;
    Array<int> dsp037ContactGenerations;
    Array<int> dsp037ContactIds;

    int dsp037NextCohortId;
    int dsp037NextEventId;
    int dsp037LastAcceptedEventId;
    int dsp037AcceptedHits;
    int dsp037RejectedHits;
    int dsp037AcceptedDamageMilli;
    int dsp037RejectedDamageMilli;
    int dsp037CohortsStarted;
    int dsp037CohortsRejected;

    void DSP037ResetOrbitRuntime()
    {
        dsp037WeaponActive.Clear();
        dsp037WeaponSlots.Clear();
        dsp037WeaponGenerations.Clear();
        dsp037WeaponIds.Clear();
        dsp037WeaponSystems.Clear();
        dsp037WeaponRanks.Clear();
        dsp037WeaponFormGenerations.Clear();
        dsp037WeaponOwnerSlots.Clear();
        dsp037WeaponOwnerGenerations.Clear();
        dsp037WeaponOwnerIds.Clear();
        dsp037WeaponFirstFireTics.Clear();
        dsp037WeaponNextActivationTics.Clear();
        dsp037WeaponPhaseStarted.Clear();
        dsp037WeaponPhaseMicroRadians.Clear();
        dsp037WeaponPhaseRemainders.Clear();
        dsp037WeaponLastPhaseTics.Clear();
        dsp037WeaponAreaAdjustments.Clear();
        dsp037WeaponSpeedAdjustments.Clear();
        dsp037WeaponFixturePoolCaps.Clear();
        dsp037WeaponNextCohortIds.Clear();
        dsp037WeaponCohortGenerations.Clear();
        dsp037MemberActive.Clear();
        dsp037MemberWeaponSlots.Clear();
        dsp037MemberWeaponGenerations.Clear();
        dsp037MemberWeaponIds.Clear();
        dsp037MemberSystemIds.Clear();
        dsp037MemberRanks.Clear();
        dsp037MemberFormGenerations.Clear();
        dsp037MemberCohortIds.Clear();
        dsp037MemberCohortGenerations.Clear();
        dsp037MemberOrdinals.Clear();
        dsp037MemberGenerations.Clear();
        dsp037MemberOwnerSlots.Clear();
        dsp037MemberOwnerGenerations.Clear();
        dsp037MemberOwnerIds.Clear();
        dsp037MemberWindowStartTics.Clear();
        dsp037MemberWindowEndTics.Clear();
        dsp037MemberLastPhaseTics.Clear();
        dsp037MemberPhaseMicroRadians.Clear();
        dsp037MemberPhaseRemainders.Clear();
        dsp037MemberAngularRatesMilliRadians.Clear();
        dsp037MemberCounts.Clear();
        dsp037MemberRadiusMilliUnits.Clear();
        dsp037MemberContactRadiusMilliUnits.Clear();
        dsp037MemberMaxSubstepMilliDegrees.Clear();
        dsp037MemberHitGateTics.Clear();
        dsp037MemberDamageTenths.Clear();
        dsp037MemberMightMilli.Clear();
        dsp037MemberAnchorX.Clear();
        dsp037MemberAnchorY.Clear();
        dsp037MemberX.Clear();
        dsp037MemberY.Clear();
        dsp037HitWeaponSlots.Clear();
        dsp037HitWeaponGenerations.Clear();
        dsp037HitWeaponIds.Clear();
        dsp037HitFormGenerations.Clear();
        dsp037HitCohortIds.Clear();
        dsp037HitCohortGenerations.Clear();
        dsp037HitMemberOrdinals.Clear();
        dsp037HitMemberGenerations.Clear();
        dsp037HitTargetSlots.Clear();
        dsp037HitTargetGenerations.Clear();
        dsp037HitTargetIds.Clear();
        dsp037HitReadyTics.Clear();
        dsp037ContactFractions.Clear();
        dsp037ContactSlots.Clear();
        dsp037ContactGenerations.Clear();
        dsp037ContactIds.Clear();
        dsp037NextCohortId = 1;
        dsp037NextEventId = 1;
        dsp037LastAcceptedEventId = 0;
        dsp037AcceptedHits = 0;
        dsp037RejectedHits = 0;
        dsp037AcceptedDamageMilli = 0;
        dsp037RejectedDamageMilli = 0;
        dsp037CohortsStarted = 0;
        dsp037CohortsRejected = 0;
    }

    int DSP037NewCohortId()
    {
        int result = dsp037NextCohortId;
        dsp037NextCohortId++;
        if (dsp037NextCohortId <= 0) dsp037NextCohortId = 1;
        if (result <= 0)
        {
            result = dsp037NextCohortId;
            dsp037NextCohortId++;
        }
        return result;
    }

    int DSP037FindMember(int weaponSlot, int weaponGeneration,
        int weaponId, int formGeneration, int cohortId,
        int cohortGeneration, int memberOrdinal, int memberGeneration)
    {
        for (int i = 0; i < dsp037MemberActive.Size(); i++)
        {
            if (dsp037MemberWeaponSlots[i] == weaponSlot
                && dsp037MemberWeaponGenerations[i] == weaponGeneration
                && dsp037MemberWeaponIds[i] == weaponId
                && dsp037MemberFormGenerations[i] == formGeneration
                && dsp037MemberCohortIds[i] == cohortId
                && dsp037MemberCohortGenerations[i] == cohortGeneration
                && dsp037MemberOrdinals[i] == memberOrdinal
                && dsp037MemberGenerations[i] == memberGeneration)
                return i;
        }
        return -1;
    }

    bool DSP037AddOrbitMember(int weaponSlot, int weaponGeneration,
        int weaponId, int systemId, int rank, int formGeneration,
        int cohortId, int cohortGeneration, int memberOrdinal,
        int memberGeneration, int memberCount, int ownerSlot,
        int ownerGeneration, int ownerId, int windowStartTic,
        int windowEndTicExclusive, int phaseStartTic,
        int initialPhaseMicroRadians, int phaseRemainder,
        int angularRateMilliRadiansPerSecond, int radiusMilliUnits,
        int contactRadiusMilliUnits, int maxSubstepMilliDegrees,
        int hitGateTics, int damageTenths, int mightMilli,
        double anchorX, double anchorY)
    {
        bool knownSystem = systemId == DSP037_SYSTEM_KING_BIBLE
            || systemId == DSP037_SYSTEM_UNHOLY_VESPERS;
        if (!knownSystem || rank <= 0 || formGeneration <= 0
            || cohortId <= 0 || cohortGeneration <= 0 || memberOrdinal < 0
            || memberGeneration <= 0 || memberCount <= 0
            || memberOrdinal >= memberCount || windowStartTic < 0
            || windowEndTicExclusive <= windowStartTic || phaseStartTic < 0
            || phaseRemainder <= -Thinker.TICRATE
            || phaseRemainder >= Thinker.TICRATE || radiusMilliUnits < 0
            || radiusMilliUnits > 160000 || contactRadiusMilliUnits < 0
            || maxSubstepMilliDegrees <= 0 || maxSubstepMilliDegrees > 10000
            || hitGateTics <= 0 || damageTenths < 0 || mightMilli < 1
            || !ValidParts(weaponSlot, weaponGeneration, weaponId)
            || !ValidParts(ownerSlot, ownerGeneration, ownerId)
            || DSP037FindMember(weaponSlot, weaponGeneration, weaponId,
                formGeneration, cohortId, cohortGeneration, memberOrdinal,
                memberGeneration) >= 0)
            return false;

        int memberPhase;
        double memberX; double memberY;
        if (!DSP037OrbitMath.MemberPhase(initialPhaseMicroRadians,
                memberOrdinal, memberCount, memberPhase)
            || !DSP037OrbitMath.OrbitPosition(anchorX, anchorY,
                radiusMilliUnits, memberPhase, memberX, memberY)) return false;

        dsp037MemberActive.Push(1);
        dsp037MemberWeaponSlots.Push(weaponSlot);
        dsp037MemberWeaponGenerations.Push(weaponGeneration);
        dsp037MemberWeaponIds.Push(weaponId);
        dsp037MemberSystemIds.Push(systemId);
        dsp037MemberRanks.Push(rank);
        dsp037MemberFormGenerations.Push(formGeneration);
        dsp037MemberCohortIds.Push(cohortId);
        dsp037MemberCohortGenerations.Push(cohortGeneration);
        dsp037MemberOrdinals.Push(memberOrdinal);
        dsp037MemberGenerations.Push(memberGeneration);
        dsp037MemberCounts.Push(memberCount);
        dsp037MemberOwnerSlots.Push(ownerSlot);
        dsp037MemberOwnerGenerations.Push(ownerGeneration);
        dsp037MemberOwnerIds.Push(ownerId);
        dsp037MemberWindowStartTics.Push(windowStartTic);
        dsp037MemberWindowEndTics.Push(windowEndTicExclusive);
        dsp037MemberLastPhaseTics.Push(phaseStartTic);
        dsp037MemberPhaseMicroRadians.Push(
            DSP037OrbitMath.NormalizePhase(initialPhaseMicroRadians));
        dsp037MemberPhaseRemainders.Push(phaseRemainder);
        dsp037MemberAngularRatesMilliRadians.Push(
            angularRateMilliRadiansPerSecond);
        dsp037MemberRadiusMilliUnits.Push(radiusMilliUnits);
        dsp037MemberContactRadiusMilliUnits.Push(contactRadiusMilliUnits);
        dsp037MemberMaxSubstepMilliDegrees.Push(maxSubstepMilliDegrees);
        dsp037MemberHitGateTics.Push(hitGateTics);
        dsp037MemberDamageTenths.Push(damageTenths);
        dsp037MemberMightMilli.Push(mightMilli);
        dsp037MemberAnchorX.Push(anchorX);
        dsp037MemberAnchorY.Push(anchorY);
        dsp037MemberX.Push(memberX);
        dsp037MemberY.Push(memberY);
        return true;
    }

    void DSP037RebaseOrbitMembers(double deltaX, double deltaY)
    {
        for (int i = 0; i < dsp037MemberActive.Size(); i++)
        {
            if (dsp037MemberActive[i] == 0) continue;
            dsp037MemberAnchorX[i] += deltaX;
            dsp037MemberAnchorY[i] += deltaY;
            dsp037MemberX[i] += deltaX;
            dsp037MemberY[i] += deltaY;
        }
    }

    int DSP037HashMix(int hash, int value)
    {
        int normalized = value % 1000003;
        if (normalized < 0) normalized += 1000003;
        return (hash * 31 + normalized) % 1000003;
    }

    int DSP037OrbitStateHash()
    {
        int hash = 17;
        hash = DSP037HashMix(hash, dsp037AcceptedHits);
        hash = DSP037HashMix(hash, dsp037AcceptedDamageMilli);
        hash = DSP037HashMix(hash, dsp037NextCohortId);
        hash = DSP037HashMix(hash, dsp037NextEventId);
        hash = DSP037HashMix(hash, dsp037LastAcceptedEventId);
        for (int i = 0; i < dsp037WeaponActive.Size(); i++)
        {
            if (dsp037WeaponActive[i] == 0) continue;
            hash = DSP037HashMix(hash, dsp037WeaponSlots[i]);
            hash = DSP037HashMix(hash, dsp037WeaponGenerations[i]);
            hash = DSP037HashMix(hash, dsp037WeaponIds[i]);
            hash = DSP037HashMix(hash, dsp037WeaponSystems[i]);
            hash = DSP037HashMix(hash, dsp037WeaponRanks[i]);
            hash = DSP037HashMix(hash, dsp037WeaponFormGenerations[i]);
            hash = DSP037HashMix(hash, dsp037WeaponNextActivationTics[i]);
            hash = DSP037HashMix(hash, dsp037WeaponPhaseMicroRadians[i]);
            hash = DSP037HashMix(hash, dsp037WeaponPhaseRemainders[i]);
            hash = DSP037HashMix(hash, dsp037WeaponLastPhaseTics[i]);
        }
        for (int i = 0; i < dsp037MemberActive.Size(); i++)
        {
            if (dsp037MemberActive[i] == 0) continue;
            hash = DSP037HashMix(hash, dsp037MemberWeaponSlots[i]);
            hash = DSP037HashMix(hash, dsp037MemberWeaponGenerations[i]);
            hash = DSP037HashMix(hash, dsp037MemberWeaponIds[i]);
            hash = DSP037HashMix(hash, dsp037MemberSystemIds[i]);
            hash = DSP037HashMix(hash, dsp037MemberRanks[i]);
            hash = DSP037HashMix(hash, dsp037MemberFormGenerations[i]);
            hash = DSP037HashMix(hash, dsp037MemberCohortIds[i]);
            hash = DSP037HashMix(hash, dsp037MemberCohortGenerations[i]);
            hash = DSP037HashMix(hash, dsp037MemberOrdinals[i]);
            hash = DSP037HashMix(hash, dsp037MemberGenerations[i]);
            hash = DSP037HashMix(hash, dsp037MemberWindowStartTics[i]);
            hash = DSP037HashMix(hash, dsp037MemberWindowEndTics[i]);
            hash = DSP037HashMix(hash, dsp037MemberLastPhaseTics[i]);
            hash = DSP037HashMix(hash, dsp037MemberPhaseMicroRadians[i]);
            hash = DSP037HashMix(hash, dsp037MemberPhaseRemainders[i]);
            hash = DSP037HashMix(hash, int(dsp037MemberAnchorX[i] * 1000.0));
            hash = DSP037HashMix(hash, int(dsp037MemberAnchorY[i] * 1000.0));
            hash = DSP037HashMix(hash, int(dsp037MemberX[i] * 1000.0));
            hash = DSP037HashMix(hash, int(dsp037MemberY[i] * 1000.0));
        }
        for (int i = 0; i < dsp037HitReadyTics.Size(); i++)
        {
            hash = DSP037HashMix(hash, dsp037HitWeaponSlots[i]);
            hash = DSP037HashMix(hash, dsp037HitWeaponGenerations[i]);
            hash = DSP037HashMix(hash, dsp037HitWeaponIds[i]);
            hash = DSP037HashMix(hash, dsp037HitFormGenerations[i]);
            hash = DSP037HashMix(hash, dsp037HitCohortIds[i]);
            hash = DSP037HashMix(hash, dsp037HitCohortGenerations[i]);
            hash = DSP037HashMix(hash, dsp037HitMemberOrdinals[i]);
            hash = DSP037HashMix(hash, dsp037HitMemberGenerations[i]);
            hash = DSP037HashMix(hash, dsp037HitTargetSlots[i]);
            hash = DSP037HashMix(hash, dsp037HitTargetGenerations[i]);
            hash = DSP037HashMix(hash, dsp037HitTargetIds[i]);
            hash = DSP037HashMix(hash, dsp037HitReadyTics[i]);
        }
        return hash;
    }

    bool DSP037ValidateOrbitState(int logicalTic, int ownerSlot,
        int ownerGeneration, int ownerId, int requiredSystem,
        int requiredWeaponSlot, out int activeMembers,
        out int activeCohorts, out int ledgerEntries)
    {
        activeMembers = 0;
        activeCohorts = 0;
        ledgerEntries = dsp037HitReadyTics.Size();
        if (requiredWeaponSlot < 0
            || requiredWeaponSlot >= generations.Size()
            || requiredWeaponSlot >= ids.Size()) return false;
        bool matchingWeapon = false;
        int matchingMembers = 0;
        int matchingCohorts = 0;
        for (int i = 0; i < dsp037WeaponActive.Size(); i++)
        {
            if (dsp037WeaponActive[i] == 0) continue;
            if (!ValidParts(dsp037WeaponSlots[i],
                    dsp037WeaponGenerations[i], dsp037WeaponIds[i])
                || !ValidParts(dsp037WeaponOwnerSlots[i],
                    dsp037WeaponOwnerGenerations[i], dsp037WeaponOwnerIds[i])
                || dsp037WeaponNextActivationTics[i] < 0
                || dsp037WeaponPhaseRemainders[i] < 0
                || dsp037WeaponPhaseRemainders[i] >= Thinker.TICRATE)
                return false;
            if (dsp037WeaponSystems[i] == requiredSystem
                && dsp037WeaponSlots[i] == requiredWeaponSlot
                && dsp037WeaponOwnerSlots[i] == ownerSlot
                && dsp037WeaponOwnerGenerations[i] == ownerGeneration
                && dsp037WeaponOwnerIds[i] == ownerId)
                matchingWeapon = true;
        }
        for (int i = 0; i < dsp037MemberActive.Size(); i++)
        {
            if (dsp037MemberActive[i] == 0) continue;
            if (!ValidParts(dsp037MemberWeaponSlots[i],
                    dsp037MemberWeaponGenerations[i], dsp037MemberWeaponIds[i])
                || !ValidParts(dsp037MemberOwnerSlots[i],
                    dsp037MemberOwnerGenerations[i], dsp037MemberOwnerIds[i])
                || dsp037MemberWindowEndTics[i]
                    <= dsp037MemberWindowStartTics[i]
                || dsp037MemberPhaseRemainders[i] < 0
                || dsp037MemberPhaseRemainders[i] >= Thinker.TICRATE)
                return false;
            bool belongsToRequiredWeapon = dsp037MemberWeaponSlots[i]
                    == requiredWeaponSlot
                && dsp037MemberWeaponGenerations[i]
                    == generations[requiredWeaponSlot]
                && dsp037MemberWeaponIds[i] == ids[requiredWeaponSlot]
                && dsp037MemberSystemIds[i] == requiredSystem;
            if (belongsToRequiredWeapon)
            {
                activeMembers++;
                matchingMembers++;
            }
            bool alreadyCounted = false;
            for (int prior = 0; prior < i; prior++)
            {
                if (dsp037MemberActive[prior] != 0
                    && dsp037MemberWeaponSlots[prior]
                        == dsp037MemberWeaponSlots[i]
                    && dsp037MemberWeaponGenerations[prior]
                        == dsp037MemberWeaponGenerations[i]
                    && dsp037MemberWeaponIds[prior]
                        == dsp037MemberWeaponIds[i]
                    && dsp037MemberFormGenerations[prior]
                        == dsp037MemberFormGenerations[i]
                    && dsp037MemberCohortIds[prior]
                        == dsp037MemberCohortIds[i]
                    && dsp037MemberCohortGenerations[prior]
                        == dsp037MemberCohortGenerations[i])
                    alreadyCounted = true;
            }
            if (!alreadyCounted && belongsToRequiredWeapon)
            {
                activeCohorts++;
                matchingCohorts++;
            }
        }
        for (int i = 0; i < ledgerEntries; i++)
            if (dsp037HitReadyTics[i] < 0) return false;
        return logicalTic >= 0 && matchingWeapon
            && matchingMembers > 0 && matchingCohorts > 0;
    }

    bool DSP037CanHitMemberTarget(int weaponSlot, int weaponGeneration,
        int weaponId, int formGeneration, int cohortId,
        int cohortGeneration, int memberOrdinal, int memberGeneration,
        int targetSlot, int targetGeneration, int targetId, int logicalTic)
    {
        for (int i = 0; i < dsp037HitReadyTics.Size(); i++)
        {
            if (dsp037HitWeaponSlots[i] == weaponSlot
                && dsp037HitWeaponGenerations[i] == weaponGeneration
                && dsp037HitWeaponIds[i] == weaponId
                && dsp037HitFormGenerations[i] == formGeneration
                && dsp037HitCohortIds[i] == cohortId
                && dsp037HitCohortGenerations[i] == cohortGeneration
                && dsp037HitMemberOrdinals[i] == memberOrdinal
                && dsp037HitMemberGenerations[i] == memberGeneration
                && dsp037HitTargetSlots[i] == targetSlot
                && dsp037HitTargetGenerations[i] == targetGeneration
                && dsp037HitTargetIds[i] == targetId)
                return logicalTic >= dsp037HitReadyTics[i];
        }
        return true;
    }

    bool DSP037RecordMemberTargetHit(int weaponSlot, int weaponGeneration,
        int weaponId, int formGeneration, int cohortId,
        int cohortGeneration, int memberOrdinal, int memberGeneration,
        int targetSlot, int targetGeneration, int targetId,
        int logicalTic, int nextReadyTic)
    {
        if (logicalTic < 0 || nextReadyTic < logicalTic
            || !ValidParts(weaponSlot, weaponGeneration, weaponId)
            || !ValidParts(targetSlot, targetGeneration, targetId)) return false;
        int found = -1;
        for (int i = 0; i < dsp037HitReadyTics.Size(); i++)
        {
            if (dsp037HitWeaponSlots[i] == weaponSlot
                && dsp037HitWeaponGenerations[i] == weaponGeneration
                && dsp037HitWeaponIds[i] == weaponId
                && dsp037HitFormGenerations[i] == formGeneration
                && dsp037HitCohortIds[i] == cohortId
                && dsp037HitCohortGenerations[i] == cohortGeneration
                && dsp037HitMemberOrdinals[i] == memberOrdinal
                && dsp037HitMemberGenerations[i] == memberGeneration
                && dsp037HitTargetSlots[i] == targetSlot
                && dsp037HitTargetGenerations[i] == targetGeneration
                && dsp037HitTargetIds[i] == targetId)
            { found = i; break; }
        }
        if (found >= 0)
        {
            dsp037HitReadyTics[found] = nextReadyTic;
            dsp037AcceptedHits++;
            return true;
        }
        dsp037HitWeaponSlots.Push(weaponSlot);
        dsp037HitWeaponGenerations.Push(weaponGeneration);
        dsp037HitWeaponIds.Push(weaponId);
        dsp037HitFormGenerations.Push(formGeneration);
        dsp037HitCohortIds.Push(cohortId);
        dsp037HitCohortGenerations.Push(cohortGeneration);
        dsp037HitMemberOrdinals.Push(memberOrdinal);
        dsp037HitMemberGenerations.Push(memberGeneration);
        dsp037HitTargetSlots.Push(targetSlot);
        dsp037HitTargetGenerations.Push(targetGeneration);
        dsp037HitTargetIds.Push(targetId);
        dsp037HitReadyTics.Push(nextReadyTic);
        dsp037AcceptedHits++;
        return true;
    }

    void DSP037CancelForm(int weaponSlot, int weaponGeneration,
        int weaponId, int formGeneration)
    {
        for (int i = 0; i < dsp037MemberActive.Size(); i++)
            if (dsp037MemberWeaponSlots[i] == weaponSlot
                && dsp037MemberWeaponGenerations[i] == weaponGeneration
                && dsp037MemberWeaponIds[i] == weaponId
                && dsp037MemberFormGenerations[i] == formGeneration)
                dsp037MemberActive[i] = 0;
        // Retain unrelated/new-form entries; remove only the old member's
        // cooldown keys so a replacement cannot inherit stale hit deadlines.
        for (int i = dsp037HitReadyTics.Size() - 1; i >= 0; i--)
        {
            if (dsp037HitWeaponSlots[i] != weaponSlot
                || dsp037HitWeaponGenerations[i] != weaponGeneration
                || dsp037HitWeaponIds[i] != weaponId
                || dsp037HitFormGenerations[i] != formGeneration) continue;
            dsp037HitWeaponSlots.Delete(i);
            dsp037HitWeaponGenerations.Delete(i);
            dsp037HitWeaponIds.Delete(i);
            dsp037HitFormGenerations.Delete(i);
            dsp037HitCohortIds.Delete(i);
            dsp037HitCohortGenerations.Delete(i);
            dsp037HitMemberOrdinals.Delete(i);
            dsp037HitMemberGenerations.Delete(i);
            dsp037HitTargetSlots.Delete(i);
            dsp037HitTargetGenerations.Delete(i);
            dsp037HitTargetIds.Delete(i);
            dsp037HitReadyTics.Delete(i);
        }
    }

    int DSP037FindWeapon(int weaponSlot, int weaponGeneration, int weaponId)
    {
        for (int i = 0; i < dsp037WeaponActive.Size(); i++)
            if (dsp037WeaponActive[i] != 0
                && dsp037WeaponSlots[i] == weaponSlot
                && dsp037WeaponGenerations[i] == weaponGeneration
                && dsp037WeaponIds[i] == weaponId) return i;
        return -1;
    }

    int DSP037MillisecondsToTics(int milliseconds)
    {
        if (milliseconds < 0 || milliseconds > 1000000) return -1;
        int numerator = milliseconds * Thinker.TICRATE;
        return (numerator + 999) / 1000;
    }

    int DSP037ScaledValue(int baseValue, int multiplierMilli)
    {
        if (baseValue < 0 || multiplierMilli < 0
            || (multiplierMilli > 0 && baseValue > 2147483647 / multiplierMilli))
            return -1;
        return baseValue * multiplierMilli / 1000;
    }

    bool DSP037EquipFixture(int systemId, int rank, int weaponSlot,
        int firstFireTic, int ownerSlot, int ownerGeneration, int ownerId,
        int areaAdjustmentMilli, int speedAdjustmentMilli)
    {
        int damageTenths; int rowArea; int rowSpeed; int amount;
        int durationMs; int cooldownMs; int afterDuration;
        int poolMin; int poolMax; int poolCap;
        int baseRadius; int radiusCap; int baseContactRadius;
        int angularRate; int maxSubstep; int hitGate; int clockwise;
        int wallPolicy;
        if ((systemId != DSP037_SYSTEM_KING_BIBLE
                && systemId != DSP037_SYSTEM_UNHOLY_VESPERS)
            || !DSP037OrbitRows.TryGetRankRow(systemId, rank,
                damageTenths, rowArea, rowSpeed, amount, durationMs,
                cooldownMs, afterDuration, poolMin, poolMax, poolCap)
            || !DSP037OrbitRows.TryGetOrbitProfile(systemId, baseRadius,
                radiusCap, baseContactRadius, angularRate, maxSubstep,
                hitGate, clockwise, wallPolicy)
            || firstFireTic < 0 || areaAdjustmentMilli <= 0
            || speedAdjustmentMilli <= 0
            || !ValidParts(weaponSlot, generations[weaponSlot], ids[weaponSlot])
            || !ValidParts(ownerSlot, ownerGeneration, ownerId)
            || DSP037FindWeapon(weaponSlot, generations[weaponSlot],
                ids[weaponSlot]) >= 0)
            return false;

        dsp037WeaponActive.Push(1);
        dsp037WeaponSlots.Push(weaponSlot);
        dsp037WeaponGenerations.Push(generations[weaponSlot]);
        dsp037WeaponIds.Push(ids[weaponSlot]);
        dsp037WeaponSystems.Push(systemId);
        dsp037WeaponRanks.Push(rank);
        dsp037WeaponFormGenerations.Push(1);
        dsp037WeaponOwnerSlots.Push(ownerSlot);
        dsp037WeaponOwnerGenerations.Push(ownerGeneration);
        dsp037WeaponOwnerIds.Push(ownerId);
        dsp037WeaponFirstFireTics.Push(firstFireTic);
        dsp037WeaponNextActivationTics.Push(firstFireTic);
        dsp037WeaponPhaseStarted.Push(0);
        dsp037WeaponPhaseMicroRadians.Push(0);
        dsp037WeaponPhaseRemainders.Push(0);
        dsp037WeaponLastPhaseTics.Push(firstFireTic);
        dsp037WeaponAreaAdjustments.Push(areaAdjustmentMilli);
        dsp037WeaponSpeedAdjustments.Push(speedAdjustmentMilli);
        dsp037WeaponFixturePoolCaps.Push(poolCap);
        dsp037WeaponNextCohortIds.Push(1);
        dsp037WeaponCohortGenerations.Push(0);
        { if (!dsQuiet) Console.Printf("DS_P037_EQUIP accepted=1 system_id=%d rank=%d weapon_slot=%d weapon_generation=%d weapon_id=%d owner_slot=%d owner_generation=%d owner_id=%d first_fire_tic=%d area_adjustment_milli=%d speed_adjustment_milli=%d reported_pool_min=%d reported_pool_max=%d fixture_pool_cap=%d classification=CONTROLLED_MAP16_FIXTURE source_inventory_claim=0", systemId, rank, weaponSlot, generations[weaponSlot], ids[weaponSlot], ownerSlot, ownerGeneration, ownerId, firstFireTic, areaAdjustmentMilli, speedAdjustmentMilli, poolMin, poolMax, poolCap); }
        return true;
    }

    bool DSP037SetFixtureRank(int weaponSlot, int rank, int logicalTic)
    {
        int index = -1;
        for (int i = 0; i < dsp037WeaponActive.Size(); i++)
            if (dsp037WeaponActive[i] != 0
                && dsp037WeaponSlots[i] == weaponSlot) { index = i; break; }
        if (index < 0 || logicalTic < 0
            || !ValidParts(dsp037WeaponSlots[index],
                dsp037WeaponGenerations[index], dsp037WeaponIds[index]))
            return false;
        int damage; int area; int speed; int amount; int durationMs;
        int cooldownMs; int afterDuration; int poolMin; int poolMax; int poolCap;
        if (!DSP037OrbitRows.TryGetRankRow(dsp037WeaponSystems[index], rank,
                damage, area, speed, amount, durationMs, cooldownMs,
                afterDuration, poolMin, poolMax, poolCap)) return false;
        int previousRank = dsp037WeaponRanks[index];
        dsp037WeaponRanks[index] = rank;
        dsp037WeaponFixturePoolCaps[index] = poolCap;
        { if (!dsQuiet) Console.Printf("DS_P037_RANK tic=%d system_id=%d previous_rank=%d rank=%d active_cohort_snapshot_preserved=1", logicalTic, dsp037WeaponSystems[index], previousRank, rank); }
        return true;
    }

    bool DSP037ReplaceFixture(int weaponSlot, int evolvedSystemId,
        int logicalTic, bool dependencyPresent, int dependencyRank)
    {
        int index = -1;
        for (int i = 0; i < dsp037WeaponActive.Size(); i++)
            if (dsp037WeaponActive[i] != 0
                && dsp037WeaponSlots[i] == weaponSlot) { index = i; break; }
        if (index < 0 || logicalTic < 0 || !dependencyPresent
            || dependencyRank < 1) return false;
        int oldSystem = dsp037WeaponSystems[index];
        int newSystem; int requiredRank; int dependencyKind;
        int dependencyMinimumRank;
        if (!DSP037OrbitRows.TryGetEvolution(oldSystem, newSystem,
                requiredRank, dependencyKind, dependencyMinimumRank)
            || newSystem != evolvedSystemId
            || dependencyKind != DSP037OrbitRows.DEPENDENCY_DURATION
            || dsp037WeaponRanks[index] < requiredRank
            || (dependencyMinimumRank > 0
                && dependencyRank < dependencyMinimumRank)) return false;
        int damage; int area; int speed; int amount; int durationMs;
        int cooldownMs; int afterDuration; int poolMin; int poolMax; int poolCap;
        if (!DSP037OrbitRows.TryGetRankRow(evolvedSystemId, 1, damage,
                area, speed, amount, durationMs, cooldownMs, afterDuration,
                poolMin, poolMax, poolCap)) return false;

        int oldForm = dsp037WeaponFormGenerations[index];
        DSP037CancelForm(dsp037WeaponSlots[index],
            dsp037WeaponGenerations[index], dsp037WeaponIds[index], oldForm);
        dsp037WeaponFormGenerations[index]++;
        if (dsp037WeaponFormGenerations[index] <= 0)
            dsp037WeaponFormGenerations[index] = 1;
        dsp037WeaponSystems[index] = evolvedSystemId;
        dsp037WeaponRanks[index] = 1;
        dsp037WeaponFixturePoolCaps[index] = poolCap;
        // The first evolved cohort starts at the current global phase and
        // replaces old-form future scheduling without resetting the orbit.
        dsp037WeaponNextActivationTics[index] = logicalTic;
        dsp037WeaponLastPhaseTics[index] = logicalTic;
        { if (!dsQuiet) Console.Printf("DS_P037_TRANSFORM accepted=1 tic=%d old_system_id=%d new_system_id=%d source_rank=%d output_rank=1 old_form_generation=%d new_form_generation=%d dependency_kind=%d dependency_rank=%d dependency_source=CONTROLLED_DURATION_FIXTURE old_cohorts_cancelled=1 phase_preserved=1 classification=ONLINE_REPORTED_RECIPE_CONTROLLED_INGREDIENT_FIXTURE", logicalTic, oldSystem, evolvedSystemId, requiredRank, oldForm, dsp037WeaponFormGenerations[index], dependencyKind, dependencyRank); }
        return true;
    }

    int DSP037ActiveMembersForWeapon(int weaponIndex)
    {
        int count = 0;
        for (int i = 0; i < dsp037MemberActive.Size(); i++)
            if (dsp037MemberActive[i] != 0
                && dsp037MemberWeaponSlots[i] == dsp037WeaponSlots[weaponIndex]
                && dsp037MemberWeaponGenerations[i] == dsp037WeaponGenerations[weaponIndex]
                && dsp037MemberWeaponIds[i] == dsp037WeaponIds[weaponIndex]) count++;
        return count;
    }

    bool DSP037StartCohort(int weaponIndex, int logicalTic,
        int ownerSlot, int ownerGeneration, int ownerId,
        double ownerX, double ownerY, int mightMilli,
        int cooldownMultiplierMilli)
    {
        int systemId = dsp037WeaponSystems[weaponIndex];
        int rank = dsp037WeaponRanks[weaponIndex];
        int damageTenths; int rowArea; int rowSpeed; int amount;
        int activeDurationMs; int cooldownMs; int cooldownAfterDuration;
        int poolMin; int poolMax; int poolCap;
        int baseRadius; int radiusCap; int baseContactRadius;
        int baseRate; int maxSubstep; int hitGate; int clockwise;
        int wallPolicy;
        if (!DSP037OrbitRows.TryGetRankRow(systemId, rank,
                damageTenths, rowArea, rowSpeed, amount, activeDurationMs,
                cooldownMs, cooldownAfterDuration, poolMin, poolMax, poolCap)
            || !DSP037OrbitRows.TryGetOrbitProfile(systemId, baseRadius,
                radiusCap, baseContactRadius, baseRate, maxSubstep,
                hitGate, clockwise, wallPolicy)
            || wallPolicy != DSP037OrbitRows.WALL_PASS)
        {
            dsp037CohortsRejected++;
            return false;
        }
        if (rsActive)
        {
            dsp037WeaponAreaAdjustments[weaponIndex] = RsAreaFor(systemId);
            dsp037WeaponSpeedAdjustments[weaponIndex] = RsSpeedFor(systemId);
            radiusCap = radiusCap * RsAreaFor(systemId) / 1000;
            activeDurationMs = activeDurationMs * RsDurationFor(systemId) / 1000;
            amount += RsAmountFor(systemId); poolCap += RsAmountFor(systemId);
        }
        int effectiveArea = DSP037ScaledValue(rowArea,
            dsp037WeaponAreaAdjustments[weaponIndex]);
        int effectiveSpeed = DSP037ScaledValue(rowSpeed,
            dsp037WeaponSpeedAdjustments[weaponIndex]);
        int radius = DSP037ScaledValue(baseRadius, effectiveArea);
        int contactRadius = DSP037ScaledValue(baseContactRadius,
            effectiveArea);
        int angularRate = DSP037ScaledValue(baseRate, effectiveSpeed);
        if (radius < 0 || contactRadius < 0 || angularRate < 0
            || amount <= 0 || poolCap <= 0 || hitGate <= 0)
        { dsp037CohortsRejected++; return false; }
        if (radius > radiusCap) radius = radiusCap;
        if (clockwise != 0) angularRate = -angularRate;
        int effectiveMight = DSP033StatRules.StatApplies(
            DSP033StatRules.STAT_MIGHT, systemId) ? mightMilli : 1000;
        if (effectiveMight < 1) effectiveMight = 1000;
        int activeTics = DSP037MillisecondsToTics(activeDurationMs);
        int effectiveCooldownMs = DSP033StatRules.CooldownAfterTome(
            systemId, cooldownMs, cooldownMultiplierMilli);
        int cooldownTics = DSP037MillisecondsToTics(effectiveCooldownMs);
        if (activeTics <= 0 || cooldownTics < 0
            || effectiveCooldownMs < 0 || amount > poolCap
            || DSP037ActiveMembersForWeapon(weaponIndex) > poolCap - amount)
        {
            dsp037CohortsRejected++;
            dsp037WeaponNextActivationTics[weaponIndex] = logicalTic + 1;
            Console.Printf("DS_P037_COHORT_REJECT tic=%d system_id=%d rank=%d amount=%d active_members=%d pool_cap=%d reason=POOL_OR_TIMER_BOUND", logicalTic, systemId, rank, amount, DSP037ActiveMembersForWeapon(weaponIndex), poolCap);
            return false;
        }
        int damageSnapshot = DSP033StatRules.DamageAfterMight(
            systemId, damageTenths, effectiveMight);
        if (damageSnapshot < 0 || damageSnapshot > 20000000)
        { dsp037CohortsRejected++; return false; }

        if (dsp037WeaponPhaseStarted[weaponIndex] == 0)
        {
            dsp037WeaponPhaseMicroRadians[weaponIndex] = 0;
            dsp037WeaponPhaseRemainders[weaponIndex] = 0;
            dsp037WeaponLastPhaseTics[weaponIndex] = logicalTic;
            dsp037WeaponPhaseStarted[weaponIndex] = 1;
        }
        int phase = dsp037WeaponPhaseMicroRadians[weaponIndex];
        int remainder = dsp037WeaponPhaseRemainders[weaponIndex];
        int startTic = logicalTic;
        int endTicExclusive = logicalTic + activeTics;
        int cohortId = DSP037NewCohortId();
        int cohortGeneration = dsp037WeaponCohortGenerations[weaponIndex] + 1;
        if (cohortGeneration <= 0) cohortGeneration = 1;
        dsp037WeaponCohortGenerations[weaponIndex] = cohortGeneration;
        int created = 0;
        for (int member = 0; member < amount; member++)
        {
            if (!DSP037AddOrbitMember(dsp037WeaponSlots[weaponIndex],
                    dsp037WeaponGenerations[weaponIndex],
                    dsp037WeaponIds[weaponIndex], systemId, rank,
                    dsp037WeaponFormGenerations[weaponIndex], cohortId,
                    cohortGeneration, member, cohortGeneration, amount,
                    ownerSlot, ownerGeneration, ownerId, startTic,
                    endTicExclusive, logicalTic, phase, remainder,
                    angularRate, radius, contactRadius, maxSubstep,
                    hitGate, damageTenths, effectiveMight, ownerX, ownerY))
                break;
            created++;
        }
        if (created != amount)
        {
            for (int i = 0; i < dsp037MemberActive.Size(); i++)
                if (dsp037MemberWeaponSlots[i] == dsp037WeaponSlots[weaponIndex]
                    && dsp037MemberWeaponGenerations[i] == dsp037WeaponGenerations[weaponIndex]
                    && dsp037MemberWeaponIds[i] == dsp037WeaponIds[weaponIndex]
                    && dsp037MemberFormGenerations[i] == dsp037WeaponFormGenerations[weaponIndex]
                    && dsp037MemberCohortIds[i] == cohortId
                    && dsp037MemberCohortGenerations[i] == cohortGeneration)
                    dsp037MemberActive[i] = 0;
            dsp037CohortsRejected++;
            return false;
        }

        int nextActivation = logicalTic + cooldownTics;
        if (cooldownAfterDuration != 0) nextActivation += activeTics;
        if (nextActivation <= logicalTic) nextActivation = logicalTic + 1;
        dsp037WeaponNextActivationTics[weaponIndex] = nextActivation;
        dsp037WeaponFixturePoolCaps[weaponIndex] = poolCap;
        dsp037CohortsStarted++;
        DSSound.Weapon(systemId);
        { if (!dsQuiet) Console.Printf("DS_P037_COHORT accepted=1 tic=%d system_id=%d rank=%d weapon_slot=%d weapon_generation=%d weapon_id=%d form_generation=%d cohort_id=%d cohort_generation=%d member_count=%d phase_micro_rad=%d phase_remainder=%d radius_milli=%d contact_radius_milli=%d angular_rate_milli_rad_s=%d clockwise=%d active_end_tic_exclusive=%d next_activation_tic=%d cooldown_starts_after_duration=%d damage_tenths=%d might_milli=%d effective_damage_tenths=%d source_rank_hash=%d reported_pool_min=%d reported_pool_max=%d fixture_pool_cap=%d geometry=ENGINEERING_APPROXIMATION", logicalTic, systemId, rank, dsp037WeaponSlots[weaponIndex], dsp037WeaponGenerations[weaponIndex], dsp037WeaponIds[weaponIndex], dsp037WeaponFormGenerations[weaponIndex], cohortId, cohortGeneration, amount, phase, remainder, radius, contactRadius, angularRate, clockwise, endTicExclusive, nextActivation, cooldownAfterDuration, damageTenths, effectiveMight, damageSnapshot, dsp033ResolvedValid ? dsp033ResolvedRankHash : 0, poolMin, poolMax, poolCap); }
        return true;
    }

    void DSP037ProcessOrbitTic(int logicalTic, int ownerSlot,
        int ownerGeneration, int ownerId, double ownerX, double ownerY,
        int mightMilli, int cooldownMultiplierMilli)
    {
        if (logicalTic < 0 || !ValidParts(ownerSlot, ownerGeneration, ownerId))
            return;
        DSP037PruneHitLedger(logicalTic);
        for (int weapon = 0; weapon < dsp037WeaponActive.Size(); weapon++)
        {
            if (dsp037WeaponActive[weapon] == 0) continue;
            if (!ValidParts(dsp037WeaponSlots[weapon],
                    dsp037WeaponGenerations[weapon], dsp037WeaponIds[weapon])
                || !ValidParts(dsp037WeaponOwnerSlots[weapon],
                    dsp037WeaponOwnerGenerations[weapon],
                    dsp037WeaponOwnerIds[weapon]))
            {
                dsp037WeaponActive[weapon] = 0;
                continue;
            }
            int damage; int area; int speed; int amount; int durationMs;
            int cooldownMs; int afterDuration; int poolMin; int poolMax; int poolCap;
            int baseRadius; int radiusCap; int contactRadius;
            int baseRate; int maxSubstep; int hitGate; int clockwise; int wallPolicy;
            if (!DSP037OrbitRows.TryGetRankRow(dsp037WeaponSystems[weapon],
                    dsp037WeaponRanks[weapon], damage, area, speed, amount,
                    durationMs, cooldownMs, afterDuration, poolMin, poolMax,
                    poolCap)
                || !DSP037OrbitRows.TryGetOrbitProfile(
                    dsp037WeaponSystems[weapon], baseRadius, radiusCap,
                    contactRadius, baseRate, maxSubstep, hitGate,
                    clockwise, wallPolicy))
            {
                dsp037WeaponActive[weapon] = 0;
                continue;
            }
            if (rsActive) dsp037WeaponSpeedAdjustments[weapon] = RsSpeedFor(dsp037WeaponSystems[weapon]);
            int effectiveSpeed = DSP037ScaledValue(speed,
                dsp037WeaponSpeedAdjustments[weapon]);
            int rate = DSP037ScaledValue(baseRate, effectiveSpeed);
            if (rate < 0) { dsp037WeaponActive[weapon] = 0; continue; }
            if (clockwise != 0) rate = -rate;
            int phaseElapsed = logicalTic
                - dsp037WeaponLastPhaseTics[weapon];
            if (phaseElapsed < 0) return;
            if (dsp037WeaponPhaseStarted[weapon] != 0)
            {
                int newPhase; int newRemainder;
                if (!DSP037OrbitMath.AdvancePhase(
                        dsp037WeaponPhaseMicroRadians[weapon], rate,
                        dsp037WeaponPhaseRemainders[weapon], phaseElapsed,
                        Thinker.TICRATE, newPhase, newRemainder))
                    return;
                dsp037WeaponPhaseMicroRadians[weapon] = newPhase;
                dsp037WeaponPhaseRemainders[weapon] = newRemainder;
                dsp037WeaponLastPhaseTics[weapon] = logicalTic;
            }

            for (int member = 0; member < dsp037MemberActive.Size(); member++)
                if (dsp037MemberActive[member] != 0
                    && dsp037MemberWeaponSlots[member] == dsp037WeaponSlots[weapon]
                    && dsp037MemberWeaponGenerations[member] == dsp037WeaponGenerations[weapon]
                    && dsp037MemberWeaponIds[member] == dsp037WeaponIds[weapon]
                    && dsp037MemberFormGenerations[member] == dsp037WeaponFormGenerations[weapon])
                    DSP037AdvanceAndProcessMember(member, logicalTic,
                        ownerX, ownerY);

            if (logicalTic >= dsp037WeaponNextActivationTics[weapon])
            {
                bool started = DSP037StartCohort(weapon, logicalTic,
                    ownerSlot, ownerGeneration, ownerId, ownerX, ownerY,
                    LbMightFor(dsp037WeaponSystems[weapon], mightMilli), cooldownMultiplierMilli);
                if (!started && dsp037WeaponNextActivationTics[weapon]
                        <= logicalTic)
                    dsp037WeaponNextActivationTics[weapon] = logicalTic + 1;
            }
        }
    }

    void DSP037AdvanceAndProcessMember(int memberIndex, int logicalTic,
        double ownerX, double ownerY)
    {
        if (memberIndex < 0 || memberIndex >= dsp037MemberActive.Size()
            || dsp037MemberActive[memberIndex] == 0) return;
        if (!ValidParts(dsp037MemberWeaponSlots[memberIndex],
                dsp037MemberWeaponGenerations[memberIndex],
                dsp037MemberWeaponIds[memberIndex])
            || !ValidParts(dsp037MemberOwnerSlots[memberIndex],
                dsp037MemberOwnerGenerations[memberIndex],
                dsp037MemberOwnerIds[memberIndex]))
        {
            dsp037MemberActive[memberIndex] = 0;
            return;
        }
        if (logicalTic >= dsp037MemberWindowEndTics[memberIndex])
        {
            dsp037MemberActive[memberIndex] = 0;
            { if (!dsQuiet) Console.Printf("DS_P037_MEMBER_RETIRE tic=%d system_id=%d cohort_id=%d cohort_generation=%d member=%d member_generation=%d reason=ACTIVE_WINDOW_ENDED", logicalTic, dsp037MemberSystemIds[memberIndex], dsp037MemberCohortIds[memberIndex], dsp037MemberCohortGenerations[memberIndex], dsp037MemberOrdinals[memberIndex], dsp037MemberGenerations[memberIndex]); }
            return;
        }
        if (logicalTic < dsp037MemberWindowStartTics[memberIndex]
            || logicalTic < dsp037MemberLastPhaseTics[memberIndex]) return;

        int previousTic = dsp037MemberLastPhaseTics[memberIndex];
        int elapsed = logicalTic - previousTic;
        double previousAnchorX = dsp037MemberAnchorX[memberIndex];
        double previousAnchorY = dsp037MemberAnchorY[memberIndex];
        double anchorDeltaX = ownerX - previousAnchorX;
        double anchorDeltaY = ownerY - previousAnchorY;
        int phase = dsp037MemberPhaseMicroRadians[memberIndex];
        int remainder = dsp037MemberPhaseRemainders[memberIndex];
        double pointX = dsp037MemberX[memberIndex];
        double pointY = dsp037MemberY[memberIndex];
        if (elapsed == 0)
        {
            DSP037SweepMemberSegment(memberIndex, logicalTic,
                pointX, pointY, pointX, pointY, 0, phase,
                previousAnchorX, previousAnchorY);
            return;
        }
        if (elapsed > 1000)
        {
            Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P037_LOGICAL_GAP tic=%d previous_tic=%d elapsed=%d", logicalTic, previousTic, elapsed);
            dsp037MemberActive[memberIndex] = 0;
            return;
        }
        for (int elapsedIndex = 1; elapsedIndex <= elapsed; elapsedIndex++)
        {
            int subTic = previousTic + elapsedIndex;
            if (subTic >= dsp037MemberWindowEndTics[memberIndex]) break;
            int nextPhase; int nextRemainder;
            if (!DSP037OrbitMath.AdvancePhase(phase,
                    dsp037MemberAngularRatesMilliRadians[memberIndex],
                    remainder, 1, Thinker.TICRATE, nextPhase,
                    nextRemainder))
            { dsp037MemberActive[memberIndex] = 0; return; }
            int unwrappedDelta = (dsp037MemberAngularRatesMilliRadians[memberIndex]
                * 1000 + remainder) / Thinker.TICRATE;
            int substeps = DSP037OrbitMath.MaxSweepSubsteps(unwrappedDelta,
                dsp037MemberMaxSubstepMilliDegrees[memberIndex]);
            if (substeps > 360)
            {
                Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P037_SUBSTEP_LIMIT tic=%d member=%d substeps=%d", subTic, dsp037MemberOrdinals[memberIndex], substeps);
                dsp037MemberActive[memberIndex] = 0;
                return;
            }
            double anchorStartX = previousAnchorX
                + anchorDeltaX * double(elapsedIndex - 1) / double(elapsed);
            double anchorStartY = previousAnchorY
                + anchorDeltaY * double(elapsedIndex - 1) / double(elapsed);
            double anchorEndX = previousAnchorX
                + anchorDeltaX * double(elapsedIndex) / double(elapsed);
            double anchorEndY = previousAnchorY
                + anchorDeltaY * double(elapsedIndex) / double(elapsed);
            double segmentStartX = pointX;
            double segmentStartY = pointY;
            int segmentStartPhase = phase;
            for (int step = 1; step <= substeps; step++)
            {
                int stepPhase = DSP037OrbitMath.NormalizePhase(phase
                    + unwrappedDelta * step / substeps);
                int memberPhase;
                double segmentEndX; double segmentEndY;
                if (!DSP037OrbitMath.MemberPhase(stepPhase,
                        dsp037MemberOrdinals[memberIndex],
                        dsp037MemberCounts[memberIndex], memberPhase)
                    || !DSP037OrbitMath.OrbitPosition(anchorEndX,
                        anchorEndY, dsp037MemberRadiusMilliUnits[memberIndex],
                        memberPhase, segmentEndX, segmentEndY))
                { dsp037MemberActive[memberIndex] = 0; return; }
                // Interpolate the anchor for angular substeps as well as for
                // skipped logical tics; a fast player cannot pull a symbol
                // through space in one endpoint-only jump.
                double subAnchorX = anchorStartX
                    + (anchorEndX - anchorStartX) * double(step) / double(substeps);
                double subAnchorY = anchorStartY
                    + (anchorEndY - anchorStartY) * double(step) / double(substeps);
                if (step < substeps
                    && !DSP037OrbitMath.OrbitPosition(subAnchorX, subAnchorY,
                        dsp037MemberRadiusMilliUnits[memberIndex], memberPhase,
                        segmentEndX, segmentEndY))
                { dsp037MemberActive[memberIndex] = 0; return; }
                DSP037SweepMemberSegment(memberIndex, subTic,
                    segmentStartX, segmentStartY, segmentEndX, segmentEndY,
                    step, stepPhase, subAnchorX, subAnchorY);
                segmentStartX = segmentEndX;
                segmentStartY = segmentEndY;
                segmentStartPhase = stepPhase;
            }
            pointX = segmentStartX;
            pointY = segmentStartY;
            phase = nextPhase;
            remainder = nextRemainder;
        }
        dsp037MemberPhaseMicroRadians[memberIndex] = phase;
        dsp037MemberPhaseRemainders[memberIndex] = remainder;
        dsp037MemberLastPhaseTics[memberIndex] = logicalTic;
        dsp037MemberAnchorX[memberIndex] = ownerX;
        dsp037MemberAnchorY[memberIndex] = ownerY;
        dsp037MemberX[memberIndex] = pointX;
        dsp037MemberY[memberIndex] = pointY;
    }

    void DSP037SweepMemberSegment(int memberIndex, int logicalTic,
        double startX, double startY, double endX, double endY,
        int substep, int phaseMicroRadians, double anchorX, double anchorY)
    {
        DSP024SweptCandidates(startX, startY, endX, endY,
            double(dsp037MemberContactRadiusMilliUnits[memberIndex]) / 1000.0);
        dsp037ContactFractions.Clear(); dsp037ContactSlots.Clear();
        dsp037ContactGenerations.Clear(); dsp037ContactIds.Clear();
        for (int candidate = 0; candidate < spatialCandidateCount; candidate++)
        {
            int slot = spatialCandidateSlots[candidate];
            int generation = spatialCandidateGenerations[candidate];
            int stableId = spatialCandidateIds[candidate];
            if (!ValidParts(slot, generation, stableId)
                || kinds[slot] != DSP037_ENEMY_KIND || health[slot] <= 0
                || collisionRadii[slot] < 0.0) continue;
            double fraction;
            double combinedRadius = double(
                dsp037MemberContactRadiusMilliUnits[memberIndex]) / 1000.0
                + collisionRadii[slot];
            if (!DSP037SegmentEntryFraction(startX, startY, endX, endY,
                    x[slot], y[slot], combinedRadius, fraction)) continue;
            dsp037ContactFractions.Push(fraction);
            dsp037ContactSlots.Push(slot);
            dsp037ContactGenerations.Push(generation);
            dsp037ContactIds.Push(stableId);
        }
        for (int i = 1; i < dsp037ContactFractions.Size(); i++)
        {
            int j = i;
            while (j > 0 && DSP037ContactPrecedes(j, j - 1))
            {
                double fraction = dsp037ContactFractions[j];
                dsp037ContactFractions[j] = dsp037ContactFractions[j - 1];
                dsp037ContactFractions[j - 1] = fraction;
                int value = dsp037ContactSlots[j];
                dsp037ContactSlots[j] = dsp037ContactSlots[j - 1];
                dsp037ContactSlots[j - 1] = value;
                value = dsp037ContactGenerations[j];
                dsp037ContactGenerations[j] = dsp037ContactGenerations[j - 1];
                dsp037ContactGenerations[j - 1] = value;
                value = dsp037ContactIds[j];
                dsp037ContactIds[j] = dsp037ContactIds[j - 1];
                dsp037ContactIds[j - 1] = value;
                j--;
            }
        }
        for (int i = 0; i < dsp037ContactFractions.Size(); i++)
        {
            int slot = dsp037ContactSlots[i];
            int generation = dsp037ContactGenerations[i];
            int stableId = dsp037ContactIds[i];
            if (!ValidParts(slot, generation, stableId)
                || kinds[slot] != DSP037_ENEMY_KIND || health[slot] <= 0)
                continue;
            if (!DSP037CanHitMemberTarget(
                    dsp037MemberWeaponSlots[memberIndex],
                    dsp037MemberWeaponGenerations[memberIndex],
                    dsp037MemberWeaponIds[memberIndex],
                    dsp037MemberFormGenerations[memberIndex],
                    dsp037MemberCohortIds[memberIndex],
                    dsp037MemberCohortGenerations[memberIndex],
                    dsp037MemberOrdinals[memberIndex],
                    dsp037MemberGenerations[memberIndex], slot, generation,
                    stableId, logicalTic))
            { dsp037RejectedHits++; continue; }
            int scaledDamageTenths;
            bool checked = DSP025CheckedDamage(
                dsp037MemberDamageTenths[memberIndex], 0,
                dsp037MemberMightMilli[memberIndex], scaledDamageTenths)
                && scaledDamageTenths >= 0
                && scaledDamageTenths <= 20000000;
            int damageMilli = checked ? scaledDamageTenths * 100 : 0;
            int before; int after; int killed;
            arHitSystem = dsp037MemberSystemIds[memberIndex];   // which weapon hit (Arcana scope)
            bool accepted = checked && DSP025ApplyLogicalHit(slot,
                generation, stableId, damageMilli, before, after, killed);
            if (!accepted)
            {
                dsp037RejectedDamageMilli++;
                continue;
            }
            int readyTic = logicalTic + dsp037MemberHitGateTics[memberIndex];
            bool recorded = DSP037RecordMemberTargetHit(
                dsp037MemberWeaponSlots[memberIndex],
                dsp037MemberWeaponGenerations[memberIndex],
                dsp037MemberWeaponIds[memberIndex],
                dsp037MemberFormGenerations[memberIndex],
                dsp037MemberCohortIds[memberIndex],
                dsp037MemberCohortGenerations[memberIndex],
                dsp037MemberOrdinals[memberIndex],
                dsp037MemberGenerations[memberIndex], slot, generation,
                stableId, logicalTic, readyTic);
            if (!recorded)
            {
                Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P037_HIT_LEDGER_WRITE tic=%d target_id=%d", logicalTic, stableId);
                continue;
            }
            int acceptedDelta = before - after;
            if (acceptedDelta < 0 || dsp037AcceptedDamageMilli
                    > 2147483647 - acceptedDelta)
                Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P037_DAMAGE_TOTAL_OVERFLOW tic=%d total=%d delta=%d", logicalTic, dsp037AcceptedDamageMilli, acceptedDelta);
            else dsp037AcceptedDamageMilli += acceptedDelta;
            int eventId = dsp037NextEventId++;
            if (dsp037NextEventId <= 0) dsp037NextEventId = 1;
            dsp037LastAcceptedEventId = eventId;
            { if (!dsQuiet) Console.Printf("DS_P037_HIT accepted=1 authority=P025_CHECKED_LOGICAL_HIT event_id=%d tic=%d system_id=%d rank=%d weapon_slot=%d weapon_generation=%d weapon_id=%d form_generation=%d cohort_id=%d cohort_generation=%d member=%d member_generation=%d phase_micro_rad=%d substep=%d target_slot=%d target_generation=%d target_id=%d fraction=%.6f damage_tenths=%d might_milli=%d damage_milli=%d before=%d after=%d accepted_delta_milli=%d hit_ready_tic=%d anchor_x=%.4f anchor_y=%.4f member_x=%.4f member_y=%.4f", eventId, logicalTic, dsp037MemberSystemIds[memberIndex], dsp037MemberRanks[memberIndex], dsp037MemberWeaponSlots[memberIndex], dsp037MemberWeaponGenerations[memberIndex], dsp037MemberWeaponIds[memberIndex], dsp037MemberFormGenerations[memberIndex], dsp037MemberCohortIds[memberIndex], dsp037MemberCohortGenerations[memberIndex], dsp037MemberOrdinals[memberIndex], dsp037MemberGenerations[memberIndex], phaseMicroRadians, substep, slot, generation, stableId, dsp037ContactFractions[i], dsp037MemberDamageTenths[memberIndex], dsp037MemberMightMilli[memberIndex], damageMilli, before, after, acceptedDelta, readyTic, anchorX, anchorY, endX, endY); }
            if (killed != 0) HandleEnemyDeath(slot, before, eventId);
        }
    }

    bool DSP037ContactPrecedes(int first, int second)
    {
        if (dsp037ContactFractions[first] != dsp037ContactFractions[second])
            return dsp037ContactFractions[first] < dsp037ContactFractions[second];
        if (dsp037ContactIds[first] != dsp037ContactIds[second])
            return dsp037ContactIds[first] < dsp037ContactIds[second];
        if (dsp037ContactGenerations[first] != dsp037ContactGenerations[second])
            return dsp037ContactGenerations[first] < dsp037ContactGenerations[second];
        return dsp037ContactSlots[first] < dsp037ContactSlots[second];
    }

    bool DSP037SegmentEntryFraction(double startX, double startY,
        double endX, double endY, double targetX, double targetY,
        double radius, out double fraction)
    {
        fraction = 0.0;
        if (radius < 0.0) return false;
        double dx = endX - startX; double dy = endY - startY;
        double fx = startX - targetX; double fy = startY - targetY;
        double c = fx * fx + fy * fy - radius * radius;
        if (c <= 0.0) return true;
        double a = dx * dx + dy * dy;
        if (a <= 0.0000001) return false;
        double b = 2.0 * (fx * dx + fy * dy);
        double discriminant = b * b - 4.0 * a * c;
        if (discriminant < 0.0) return false;
        double root = sqrt(discriminant);
        double first = (-b - root) / (2.0 * a);
        double second = (-b + root) / (2.0 * a);
        if (first >= 0.0 && first <= 1.0)
        { fraction = first; return true; }
        if (second >= 0.0 && second <= 1.0)
        { fraction = second; return true; }
        return false;
    }

    void DSP037PruneHitLedger(int logicalTic)
    {
        for (int i = dsp037HitReadyTics.Size() - 1; i >= 0; i--)
        {
            bool expired = logicalTic >= dsp037HitReadyTics[i];
            bool targetStale = !ValidParts(dsp037HitTargetSlots[i],
                dsp037HitTargetGenerations[i], dsp037HitTargetIds[i]);
            if (!expired && !targetStale) continue;
            dsp037HitWeaponSlots.Delete(i);
            dsp037HitWeaponGenerations.Delete(i);
            dsp037HitWeaponIds.Delete(i);
            dsp037HitFormGenerations.Delete(i);
            dsp037HitCohortIds.Delete(i);
            dsp037HitCohortGenerations.Delete(i);
            dsp037HitMemberOrdinals.Delete(i);
            dsp037HitMemberGenerations.Delete(i);
            dsp037HitTargetSlots.Delete(i);
            dsp037HitTargetGenerations.Delete(i);
            dsp037HitTargetIds.Delete(i);
            dsp037HitReadyTics.Delete(i);
        }
    }
}
