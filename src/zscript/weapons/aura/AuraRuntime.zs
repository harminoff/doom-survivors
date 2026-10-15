// P039 Garlic / Soul Eater aura authority.
//
// External dependencies, all landed (verified against the actual files, not
// assumed from the original task brief -- see the reconciliation notes
// below for where the landed API differs from that brief):
//   DSP039AuraRows -- src/zscript/weapons/aura/AuraRows.zs.
//                     SYSTEM_GARLIC=48, SYSTEM_SOUL_EATER=49 (P033 SYSTEM_*
//                     numbering, NOT 1/2 as the brief guessed -- referenced
//                     here only by name, never by literal, so this file did
//                     not need to change). RankCount(system),
//                     DamageMilli/AreaMilli/CooldownTics/RadiusMilliUnits
//                     (system, rank), TryGetEvolution(...),
//                     BASE_RADIUS_MILLI_UNITS, KNOCKBACK_STEP_MILLI,
//                     KNOCKBACK_CAP_MILLI, FREEZE_RESIST_STEP_MILLI,
//                     SOUL_EATER_GROWTH_HEAL_MILLI, SOUL_EATER_GROWTH_CAP,
//                     HEART_CHANCE_NUMERATOR, HEART_CHANCE_DENOMINATOR_MILLI,
//                     HEART_BASE_HEAL_MILLI, RECOVERY_PERIOD_TICS.
//   mixin DSP039Healing -- src/zscript/gameplay/healing/HealingAuthority.zs.
//                     Signatures match the brief exactly. This mixin is
//                     always composed alongside DSP039Aura in the same
//                     handler (per the lead's note), so DSP039Aura calls its
//                     DSP039LittleHeartHealMilli(recoveryMilli) directly
//                     instead of duplicating that formula, and NEVER
//                     redeclares a member DSP039Healing already owns --
//                     notably its hash mixer, DSP039HashMix; this file's
//                     own mix helpers are named DSP039AuraHashMix /
//                     DSP039AuraHashMixDoubleMilli specifically to avoid
//                     that collision. The composing class still drives
//                     Little Heart collection and Recovery/Bloody-Tear heals
//                     through DSP039ApplyHeal itself and reports each
//                     applied amount back here via DSP039FeedSoulEaterGrowth.
//   DSP033Resolved(DSP033StatRules.STAT_MIGHT / STAT_COOLDOWN / STAT_RECOVERY)
//                     -- STAT_RECOVERY=5 landed in
//                     src/zscript/gameplay/stats/ResolvedStats.zs.
//   DSP024RadiusCandidates(x, y, radius), spatialCandidate* arrays -- P024.
//   DSP025CheckedDamage(base, bonus, multiplierMilli, out amount) and
//   DSP025ApplyLogicalHit(slot, generation, stableId, amountMilli, out
//   before, out after, out killed) -- P025 (src/zscript/gameplay/attacks/AttackRecords.zs).
//   ValidParts/kinds/health/x/y/collisionRadii -- P020 EntityStore.
//   HandleEnemyDeath(slot, beforeHealth, eventId) -- supplied by the
//   composing class, matching every other weapon-family mixin's convention.
//
// Arrays intentionally live on the owning EventHandler so P029 saves
// preserve equipped auras, form generation, the per-target ledger, debuff
// state, Soul Eater growth and live Little Hearts. The presentation ring is
// not state and is never read here.
mixin class DSP039Aura
{
    const DSP039_KIND_ENEMY = 1;
    const DSP039_MAX_SAFE_DAMAGE_MILLI = 2000000000;
    // P024 buckets candidates by centre cell; contact is inclusive aura
    // radius + the TARGET's own logical radius, so a target whose centre
    // sits just outside the aura radius but whose circle still touches it
    // must still be queried as a broad-phase candidate. No live target in
    // this project exceeds this bound (VerticalSlice's largest enemy radius
    // is 32; this doubles it for headroom) -- a documented engineering
    // bound, not a source value.
    const DSP039_MAX_TARGET_RADIUS_BOUND_UNITS = 64.0;
    // No source value describes an enemy's baseline freeze resistance; P039
    // fixes one so the −100-milli-per-hit/floor-0 debuff rule in the
    // contract has somewhere concrete to land. This is an engineering
    // approximation (ENGINEERING_APPROXIMATION), not a qualified source value.
    const DSP039_FREEZE_RESIST_BASELINE_MILLI = 1000;

    // Equipped aura instances (one per logical weapon handle/form).
    Array<int> dsp039AuraActive;
    Array<int> dsp039AuraSystem;
    Array<int> dsp039AuraRank;
    Array<int> dsp039AuraSlot;
    Array<int> dsp039AuraGeneration;
    Array<int> dsp039AuraId;
    Array<int> dsp039AuraFormGeneration;
    Array<int> dsp039AuraOwnerSlot;
    Array<int> dsp039AuraOwnerGeneration;
    Array<int> dsp039AuraOwnerId;
    Array<int> dsp039AuraMightMilli;
    Array<int> dsp039AuraCooldownMultiplierMilli;
    // Soul Eater growth: milli-HP actually recovered while this instance is
    // in Soul Eater form, and the derived (cached) whole-damage bonus.
    Array<int> dsp039AuraRecoveredHealMilli;
    Array<int> dsp039AuraGrowthBonusDamage;
    // Controlled fixture-only radius scale (see DSP039EquipAura); never a
    // P033-resolved value.
    Array<int> dsp039AuraAreaAdjustmentMilli;

    // Per (weapon handle + form generation, target handle) ready-tic ledger.
    Array<int> dsp039HitWeaponSlot;
    Array<int> dsp039HitWeaponGeneration;
    Array<int> dsp039HitWeaponId;
    Array<int> dsp039HitFormGeneration;
    Array<int> dsp039HitTargetSlot;
    Array<int> dsp039HitTargetGeneration;
    Array<int> dsp039HitTargetId;
    Array<int> dsp039HitReadyTic;

    // Per-target debuff and immunity state (shared by every aura weapon).
    Array<int> dsp039DebuffTargetSlot;
    Array<int> dsp039DebuffTargetGeneration;
    Array<int> dsp039DebuffTargetId;
    Array<int> dsp039DebuffKnockbackMilli;
    Array<int> dsp039DebuffFreezeResistMilli;
    Array<int> dsp039DebuffImmune;

    // Little Heart logical pickups.
    Array<int> dsp039HeartActive;
    Array<int> dsp039HeartId;
    Array<int> dsp039HeartGeneration;
    Array<double> dsp039HeartX;
    Array<double> dsp039HeartY;
    Array<int> dsp039HeartHealMilli;
    Array<int> dsp039HeartSpawnTic;

    // Transient per-tic candidate scratch (never persisted/hashed).
    Array<int> dsp039CandidateSlots;
    Array<int> dsp039CandidateGenerations;
    Array<int> dsp039CandidateIds;

    int dsp039NextEventId;
    int dsp039NextHeartId;
    int dsp039NextHeartGeneration;
    // Dedicated P039_HEART RNG stream; never shares state with the attack
    // RNG or any other logical stream.
    int dsp039HeartRngState;
    int dsp039AcceptedHits;
    int dsp039RejectedHits;
    int dsp039AcceptedDamageMilli;
    int dsp039RejectedDamageMilli;
    int dsp039HeartsSpawned;
    int dsp039HeartsCollected;
    int dsp039LastAcceptedEventId;
    int dsp039LastAcceptedSystemId;
    int dsp039LastAcceptedWeaponId;
    int dsp039LastAcceptedTargetId;

    void DSP039ResetAura()
    {
        dsp039AuraActive.Clear(); dsp039AuraSystem.Clear();
        dsp039AuraRank.Clear(); dsp039AuraSlot.Clear();
        dsp039AuraGeneration.Clear(); dsp039AuraId.Clear();
        dsp039AuraFormGeneration.Clear(); dsp039AuraOwnerSlot.Clear();
        dsp039AuraOwnerGeneration.Clear(); dsp039AuraOwnerId.Clear();
        dsp039AuraMightMilli.Clear(); dsp039AuraCooldownMultiplierMilli.Clear();
        dsp039AuraRecoveredHealMilli.Clear(); dsp039AuraGrowthBonusDamage.Clear();
        dsp039AuraAreaAdjustmentMilli.Clear();
        dsp039HitWeaponSlot.Clear(); dsp039HitWeaponGeneration.Clear();
        dsp039HitWeaponId.Clear(); dsp039HitFormGeneration.Clear();
        dsp039HitTargetSlot.Clear(); dsp039HitTargetGeneration.Clear();
        dsp039HitTargetId.Clear(); dsp039HitReadyTic.Clear();
        dsp039DebuffTargetSlot.Clear(); dsp039DebuffTargetGeneration.Clear();
        dsp039DebuffTargetId.Clear(); dsp039DebuffKnockbackMilli.Clear();
        dsp039DebuffFreezeResistMilli.Clear(); dsp039DebuffImmune.Clear();
        dsp039HeartActive.Clear(); dsp039HeartId.Clear();
        dsp039HeartGeneration.Clear(); dsp039HeartX.Clear(); dsp039HeartY.Clear();
        dsp039HeartHealMilli.Clear(); dsp039HeartSpawnTic.Clear();
        dsp039CandidateSlots.Clear(); dsp039CandidateGenerations.Clear();
        dsp039CandidateIds.Clear();
        dsp039NextEventId = 1;
        dsp039NextHeartId = 1; dsp039NextHeartGeneration = 1;
        // A fixed non-zero seed keeps the fixture deterministic; a caller
        // that needs a different controlled seed calls DSP039SeedHeartRng.
        dsp039HeartRngState = 747796405;
        dsp039AcceptedHits = 0; dsp039RejectedHits = 0;
        dsp039AcceptedDamageMilli = 0; dsp039RejectedDamageMilli = 0;
        dsp039HeartsSpawned = 0; dsp039HeartsCollected = 0;
        dsp039LastAcceptedEventId = 0; dsp039LastAcceptedSystemId = 0;
        dsp039LastAcceptedWeaponId = 0; dsp039LastAcceptedTargetId = 0;
    }

    void DSP039SeedHeartRng(int seed)
    {
        dsp039HeartRngState = seed != 0 ? seed : 747796405;
    }

    int DSP039NewEventId()
    {
        int eventId = dsp039NextEventId++;
        if (dsp039NextEventId <= 0) dsp039NextEventId = 1;
        if (eventId <= 0) eventId = dsp039NextEventId;
        return eventId;
    }

    // ---- Aura instance lifecycle -----------------------------------------

    int DSP039FindAura(int weaponSlot, int weaponGeneration, int weaponId)
    {
        for (int i = 0; i < dsp039AuraActive.Size(); i++)
            if (dsp039AuraActive[i] != 0
                && dsp039AuraSlot[i] == weaponSlot
                && dsp039AuraGeneration[i] == weaponGeneration
                && dsp039AuraId[i] == weaponId) return i;
        return -1;
    }

    // areaAdjustmentMilli is a controlled MAP fixture input (docs/contracts
    // /auras-healing.md "Stats": "MAP fixtures may inject labelled high
    // Area/Might/Recovery"), never a P033-resolved value -- Garlic/Soul
    // Eater have no Area stat channel. 1000 = unmodified row radius.
    bool DSP039EquipAura(int systemId, int rank, int weaponSlot,
        int weaponGeneration, int weaponId, int formGeneration,
        int ownerSlot, int ownerGeneration, int ownerId,
        int mightMilli, int cooldownMultiplierMilli,
        int areaAdjustmentMilli = 1000)
    {
        if (rank < 1 || rank > DSP039AuraRows.RankCount(systemId)
            || !ValidParts(weaponSlot, weaponGeneration, weaponId)
            || !ValidParts(ownerSlot, ownerGeneration, ownerId)
            || formGeneration <= 0 || mightMilli < 1
            || cooldownMultiplierMilli < 1 || areaAdjustmentMilli < 1
            || DSP039FindAura(weaponSlot, weaponGeneration, weaponId) >= 0)
            return false;
        dsp039AuraActive.Push(1); dsp039AuraSystem.Push(systemId);
        dsp039AuraRank.Push(rank); dsp039AuraSlot.Push(weaponSlot);
        dsp039AuraGeneration.Push(weaponGeneration); dsp039AuraId.Push(weaponId);
        dsp039AuraFormGeneration.Push(formGeneration);
        dsp039AuraOwnerSlot.Push(ownerSlot);
        dsp039AuraOwnerGeneration.Push(ownerGeneration);
        dsp039AuraOwnerId.Push(ownerId);
        dsp039AuraMightMilli.Push(mightMilli);
        dsp039AuraCooldownMultiplierMilli.Push(cooldownMultiplierMilli);
        dsp039AuraRecoveredHealMilli.Push(0);
        dsp039AuraGrowthBonusDamage.Push(0);
        dsp039AuraAreaAdjustmentMilli.Push(areaAdjustmentMilli);
        return true;
    }

    // N2 dispatcher rank-change API (docs/contracts/normal-play-integration.md
    // "Weapon dispatcher"). Mirrors DSP035SetFixtureRank's shape for the aura
    // engine; leaves DSP039EquipAura/DSP039TransformAura untouched.
    bool DSP039SetAuraRank(int weaponSlot, int weaponGeneration, int weaponId,
        int systemId, int rank)
    {
        if (rank < 1 || rank > DSP039AuraRows.RankCount(systemId)) return false;
        int aura = DSP039FindAura(weaponSlot, weaponGeneration, weaponId);
        if (aura < 0 || dsp039AuraSystem[aura] != systemId) return false;
        int oldRank = dsp039AuraRank[aura];
        dsp039AuraRank[aura] = rank;
        { if (!dsQuiet) Console.Printf("DS_N2_AURA_FIXTURE_RANK accepted=1 system_id=%d prior_rank=%d rank=%d weapon_id=%d weapon_generation=%d classification=N2_DISPATCHER_RANK_CHANGE", systemId, oldRank, rank, weaponId, weaponGeneration); }
        return true;
    }

    // Garlic -> Soul Eater is a future-form-only transition: the equipped
    // instance keeps its handle, gains a new form generation (so any target
    // already on cooldown against Garlic starts a fresh Soul Eater ledger),
    // and resets the growth counter, matching "reset ... when the form is
    // replaced". Dependency (Pummarola owned) is resolved by the caller.
    bool DSP039TransformAura(int weaponSlot, int weaponGeneration,
        int weaponId, int expectedSourceSystem, int evolvedSystem,
        int rank, int newFormGeneration, bool dependencyPresent)
    {
        int aura = DSP039FindAura(weaponSlot, weaponGeneration, weaponId);
        int registeredEvolved; int dependencyKey; int sourceRank; int dependencyRank;
        if (aura < 0 || dsp039AuraSystem[aura] != expectedSourceSystem
            || !dependencyPresent
            || !DSP039AuraRows.TryGetEvolution(expectedSourceSystem,
                registeredEvolved, dependencyKey, sourceRank, dependencyRank)
            || registeredEvolved != evolvedSystem
            || dsp039AuraRank[aura] < sourceRank
            || rank < 1 || rank > DSP039AuraRows.RankCount(evolvedSystem)
            || newFormGeneration <= dsp039AuraFormGeneration[aura])
            return false;
        dsp039AuraSystem[aura] = evolvedSystem;
        dsp039AuraRank[aura] = rank;
        dsp039AuraFormGeneration[aura] = newFormGeneration;
        dsp039AuraRecoveredHealMilli[aura] = 0;
        dsp039AuraGrowthBonusDamage[aura] = 0;
        { if (!dsQuiet) Console.Printf("DS_P039_TRANSFORM accepted=1 weapon_id=%d source_system=%d evolved_system=%d rank=%d form_generation=%d dependency_key=%d", weaponId, expectedSourceSystem, evolvedSystem, rank, newFormGeneration, dependencyKey); }
        return true;
    }

    void DSP039PurgeStaleAuras()
    {
        for (int i = 0; i < dsp039AuraActive.Size(); i++)
        {
            if (dsp039AuraActive[i] == 0) continue;
            if (!ValidParts(dsp039AuraSlot[i], dsp039AuraGeneration[i], dsp039AuraId[i])
                || !ValidParts(dsp039AuraOwnerSlot[i], dsp039AuraOwnerGeneration[i],
                    dsp039AuraOwnerId[i]))
                dsp039AuraActive[i] = 0;
        }
    }

    // ---- Per-target debuff and immunity ----------------------------------

    int DSP039FindDebuff(int targetSlot, int targetGeneration, int targetId)
    {
        for (int i = 0; i < dsp039DebuffTargetSlot.Size(); i++)
            if (dsp039DebuffTargetSlot[i] == targetSlot
                && dsp039DebuffTargetGeneration[i] == targetGeneration
                && dsp039DebuffTargetId[i] == targetId) return i;
        return -1;
    }

    int DSP039EnsureDebuff(int targetSlot, int targetGeneration, int targetId)
    {
        int index = DSP039FindDebuff(targetSlot, targetGeneration, targetId);
        if (index >= 0) return index;
        dsp039DebuffTargetSlot.Push(targetSlot);
        dsp039DebuffTargetGeneration.Push(targetGeneration);
        dsp039DebuffTargetId.Push(targetId);
        dsp039DebuffKnockbackMilli.Push(0);
        dsp039DebuffFreezeResistMilli.Push(DSP039_FREEZE_RESIST_BASELINE_MILLI);
        dsp039DebuffImmune.Push(0);
        return dsp039DebuffTargetSlot.Size() - 1;
    }

    // The fixture (or later VerticalSlice enemy-status bridge) marks a
    // spawned target immune before it can be hit; this mixin never invents
    // its own immunity source.
    void DSP039SetTargetImmune(int targetSlot, int targetGeneration,
        int targetId, bool immune)
    {
        int index = DSP039EnsureDebuff(targetSlot, targetGeneration, targetId);
        dsp039DebuffImmune[index] = immune ? 1 : 0;
    }

    bool DSP039TargetImmune(int targetSlot, int targetGeneration, int targetId)
    {
        int index = DSP039FindDebuff(targetSlot, targetGeneration, targetId);
        return index >= 0 && dsp039DebuffImmune[index] != 0;
    }

    void DSP039ApplyDebuff(int targetSlot, int targetGeneration, int targetId)
    {
        int index = DSP039EnsureDebuff(targetSlot, targetGeneration, targetId);
        if (dsp039DebuffImmune[index] != 0) return;
        int knockback = dsp039DebuffKnockbackMilli[index]
            + DSP039AuraRows.KNOCKBACK_STEP_MILLI;
        dsp039DebuffKnockbackMilli[index] = DSP039AuraMath.ClampInt(
            knockback, 0, DSP039AuraRows.KNOCKBACK_CAP_MILLI);
        int freezeResist = dsp039DebuffFreezeResistMilli[index]
            - DSP039AuraRows.FREEZE_RESIST_STEP_MILLI;
        dsp039DebuffFreezeResistMilli[index] = DSP039AuraMath.ClampInt(
            freezeResist, 0, DSP039_FREEZE_RESIST_BASELINE_MILLI);
        { if (!dsQuiet) Console.Printf("DS_P039_DEBUFF target_id=%d knockback_milli=%d freeze_resist_milli=%d cap_milli=%d floor=0 classification=ENGINEERING_ADAPTER_FIXTURE", targetId, dsp039DebuffKnockbackMilli[index], dsp039DebuffFreezeResistMilli[index], DSP039AuraRows.KNOCKBACK_CAP_MILLI); }
    }

    void DSP039PurgeStaleDebuff()
    {
        for (int i = dsp039DebuffTargetSlot.Size() - 1; i >= 0; i--)
        {
            if (ValidParts(dsp039DebuffTargetSlot[i], dsp039DebuffTargetGeneration[i],
                dsp039DebuffTargetId[i])) continue;
            int last = dsp039DebuffTargetSlot.Size() - 1;
            dsp039DebuffTargetSlot[i] = dsp039DebuffTargetSlot[last];
            dsp039DebuffTargetGeneration[i] = dsp039DebuffTargetGeneration[last];
            dsp039DebuffTargetId[i] = dsp039DebuffTargetId[last];
            dsp039DebuffKnockbackMilli[i] = dsp039DebuffKnockbackMilli[last];
            dsp039DebuffFreezeResistMilli[i] = dsp039DebuffFreezeResistMilli[last];
            dsp039DebuffImmune[i] = dsp039DebuffImmune[last];
            dsp039DebuffTargetSlot.Pop(); dsp039DebuffTargetGeneration.Pop();
            dsp039DebuffTargetId.Pop(); dsp039DebuffKnockbackMilli.Pop();
            dsp039DebuffFreezeResistMilli.Pop(); dsp039DebuffImmune.Pop();
        }
    }

    // ---- Per-target ready-tic ledger -------------------------------------

    int DSP039FindLedger(int weaponSlot, int weaponGeneration, int weaponId,
        int formGeneration, int targetSlot, int targetGeneration, int targetId)
    {
        for (int i = 0; i < dsp039HitWeaponId.Size(); i++)
            if (dsp039HitWeaponId[i] == weaponId
                && dsp039HitWeaponGeneration[i] == weaponGeneration
                && dsp039HitFormGeneration[i] == formGeneration
                && dsp039HitTargetSlot[i] == targetSlot
                && dsp039HitTargetGeneration[i] == targetGeneration
                && dsp039HitTargetId[i] == targetId) return i;
        return -1;
    }

    bool DSP039TargetReady(int weaponSlot, int weaponGeneration, int weaponId,
        int formGeneration, int targetSlot, int targetGeneration,
        int targetId, int logicalTic)
    {
        int ledger = DSP039FindLedger(weaponSlot, weaponGeneration, weaponId,
            formGeneration, targetSlot, targetGeneration, targetId);
        return ledger < 0 || logicalTic >= dsp039HitReadyTic[ledger];
    }

    void DSP039RecordLedgerHit(int weaponSlot, int weaponGeneration,
        int weaponId, int formGeneration, int targetSlot,
        int targetGeneration, int targetId, int readyTic)
    {
        int ledger = DSP039FindLedger(weaponSlot, weaponGeneration, weaponId,
            formGeneration, targetSlot, targetGeneration, targetId);
        if (ledger >= 0) { dsp039HitReadyTic[ledger] = readyTic; return; }
        dsp039HitWeaponSlot.Push(weaponSlot);
        dsp039HitWeaponGeneration.Push(weaponGeneration);
        dsp039HitWeaponId.Push(weaponId);
        dsp039HitFormGeneration.Push(formGeneration);
        dsp039HitTargetSlot.Push(targetSlot);
        dsp039HitTargetGeneration.Push(targetGeneration);
        dsp039HitTargetId.Push(targetId);
        dsp039HitReadyTic.Push(readyTic);
    }

    // Stale target generations (and stale weapon handles, e.g. a destroyed
    // aura instance) are purged so the ledger cannot grow without bound.
    void DSP039PurgeStaleLedger()
    {
        for (int i = dsp039HitWeaponId.Size() - 1; i >= 0; i--)
        {
            bool weaponValid = ValidParts(dsp039HitWeaponSlot[i],
                dsp039HitWeaponGeneration[i], dsp039HitWeaponId[i]);
            bool targetValid = ValidParts(dsp039HitTargetSlot[i],
                dsp039HitTargetGeneration[i], dsp039HitTargetId[i]);
            if (weaponValid && targetValid) continue;
            int last = dsp039HitWeaponId.Size() - 1;
            dsp039HitWeaponSlot[i] = dsp039HitWeaponSlot[last];
            dsp039HitWeaponGeneration[i] = dsp039HitWeaponGeneration[last];
            dsp039HitWeaponId[i] = dsp039HitWeaponId[last];
            dsp039HitFormGeneration[i] = dsp039HitFormGeneration[last];
            dsp039HitTargetSlot[i] = dsp039HitTargetSlot[last];
            dsp039HitTargetGeneration[i] = dsp039HitTargetGeneration[last];
            dsp039HitTargetId[i] = dsp039HitTargetId[last];
            dsp039HitReadyTic[i] = dsp039HitReadyTic[last];
            dsp039HitWeaponSlot.Pop(); dsp039HitWeaponGeneration.Pop();
            dsp039HitWeaponId.Pop(); dsp039HitFormGeneration.Pop();
            dsp039HitTargetSlot.Pop(); dsp039HitTargetGeneration.Pop();
            dsp039HitTargetId.Pop(); dsp039HitReadyTic.Pop();
        }
    }

    // ---- Soul Eater growth ------------------------------------------------

    void DSP039RecomputeGrowth(int aura)
    {
        int bonus = dsp039AuraRecoveredHealMilli[aura]
            / DSP039AuraRows.SOUL_EATER_GROWTH_HEAL_MILLI;
        dsp039AuraGrowthBonusDamage[aura] = DSP039AuraMath.ClampInt(
            bonus, 0, DSP039AuraRows.SOUL_EATER_GROWTH_CAP);
    }

    // The composing class calls this once per successfully applied heal
    // (any source: Recovery, Little Heart, Bloody Tear), passing the
    // authority's own "applied" amount -- never a requested amount, and
    // never overheal, per the contract. Every currently equipped Soul
    // Eater instance is fed identically since Recovery/hearts/drain are
    // player-wide, not per-weapon.
    // logicalTic is accepted only so the emitted marker can be joined back
    // to the DS_P039_HEAL transaction that fed it, for exact reconciliation
    // (recovered_milli must equal the running sum of every applied_milli
    // logged here while this Soul Eater instance is equipped); it is never
    // used for any growth arithmetic itself.
    void DSP039FeedSoulEaterGrowth(int appliedMilli, int logicalTic)
    {
        if (appliedMilli <= 0) return;
        for (int i = 0; i < dsp039AuraActive.Size(); i++)
        {
            if (dsp039AuraActive[i] == 0
                || dsp039AuraSystem[i] != DSP039AuraRows.SYSTEM_SOUL_EATER)
                continue;
            int total = dsp039AuraRecoveredHealMilli[i];
            if (total <= 2000000000 - appliedMilli)
                total += appliedMilli;
            else total = 2000000000;
            dsp039AuraRecoveredHealMilli[i] = total;
            DSP039RecomputeGrowth(i);
            // Logged on every feed (not only on a bonus-damage change) so
            // the running total can be reconciled exactly against every
            // contributing DS_P039_HEAL transaction.
            { if (!dsQuiet) Console.Printf("DS_P039_SOUL_GROWTH tic=%d weapon_id=%d applied_milli=%d recovered_milli=%d bonus_damage=%d cap=%d", logicalTic, dsp039AuraId[i], appliedMilli, total, dsp039AuraGrowthBonusDamage[i], DSP039AuraRows.SOUL_EATER_GROWTH_CAP); }
        }
    }

    // ---- Little Heart pickups ---------------------------------------------

    void DSP039TrySpawnHeart(int logicalTic, int damageMilli,
        double targetX, double targetY, int recoveryMilli)
    {
        dsp039HeartRngState = DSP039AuraMath.NextRngState(dsp039HeartRngState);
        int denominator = DSP039AuraRows.HEART_CHANCE_DENOMINATOR_MILLI;
        int roll = DSP039AuraMath.PositiveModulo(dsp039HeartRngState, denominator);
        int threshold = damageMilli * DSP039AuraRows.HEART_CHANCE_NUMERATOR;
        { if (!dsQuiet) Console.Printf("DS_P039_HEART_ROLL tic=%d damage_milli=%d roll=%d threshold=%d denominator=%d", logicalTic, damageMilli, roll, threshold, denominator); }
        if (roll >= threshold) return;
        // Delegates to the co-mixed DSP039Healing's canonical formula
        // (HealingAuthority.zs DSP039LittleHeartHealMilli) rather than
        // duplicating the 1000 * (1000 + recovery) / 1000 arithmetic here,
        // so the two mixins can never compute a different heal amount.
        int healMilli = DSP039LittleHeartHealMilli(recoveryMilli);
        if (healMilli <= 0) return;
        int id = dsp039NextHeartId++;
        if (dsp039NextHeartId <= 0)
        { dsp039NextHeartId = 1; dsp039NextHeartGeneration++; }
        if (dsp039NextHeartGeneration <= 0) dsp039NextHeartGeneration = 1;
        dsp039HeartActive.Push(1); dsp039HeartId.Push(id);
        dsp039HeartGeneration.Push(dsp039NextHeartGeneration);
        dsp039HeartX.Push(targetX); dsp039HeartY.Push(targetY);
        dsp039HeartHealMilli.Push(healMilli); dsp039HeartSpawnTic.Push(logicalTic);
        dsp039HeartsSpawned++;
        { if (!dsQuiet) Console.Printf("DS_P039_HEART_SPAWN accepted=1 tic=%d heart_id=%d heart_generation=%d x=%.3f y=%.3f heal_milli=%d recovery_milli=%d", logicalTic, id, dsp039NextHeartGeneration, targetX, targetY, healMilli, recoveryMilli); }
    }

    int DSP039HeartCount() { return dsp039HeartActive.Size(); }
    bool DSP039HeartActiveAt(int index)
    { return index >= 0 && index < dsp039HeartActive.Size() && dsp039HeartActive[index] != 0; }

    // The composing class marks the record collected only after its own
    // healing-authority call reports success, then must call
    // DSP039FeedSoulEaterGrowth with that call's applied amount.
    void DSP039CollectHeartAt(int index, int logicalTic)
    {
        if (!DSP039HeartActiveAt(index)) return;
        dsp039HeartActive[index] = 0;
        dsp039HeartsCollected++;
        { if (!dsQuiet) Console.Printf("DS_P039_HEART_COLLECT accepted=1 tic=%d heart_id=%d heart_generation=%d heal_milli=%d", logicalTic, dsp039HeartId[index], dsp039HeartGeneration[index], dsp039HeartHealMilli[index]); }
    }

    // ---- Per-tic aura sweep -----------------------------------------------

    void DSP039SortCandidatesByStableId()
    {
        for (int i = 1; i < dsp039CandidateIds.Size(); i++)
        {
            int j = i;
            while (j > 0 && DSP039AuraMath.CandidatePrecedes(
                dsp039CandidateIds[j], dsp039CandidateGenerations[j],
                dsp039CandidateSlots[j], dsp039CandidateIds[j - 1],
                dsp039CandidateGenerations[j - 1], dsp039CandidateSlots[j - 1]))
            {
                int value = dsp039CandidateSlots[j];
                dsp039CandidateSlots[j] = dsp039CandidateSlots[j - 1];
                dsp039CandidateSlots[j - 1] = value;
                value = dsp039CandidateGenerations[j];
                dsp039CandidateGenerations[j] = dsp039CandidateGenerations[j - 1];
                dsp039CandidateGenerations[j - 1] = value;
                value = dsp039CandidateIds[j];
                dsp039CandidateIds[j] = dsp039CandidateIds[j - 1];
                dsp039CandidateIds[j - 1] = value;
                j--;
            }
        }
    }

    // One weapon's per-tic sweep: build the candidate list from P024, sort
    // it into the contract's stable-ID order, then take at most one checked
    // hit per candidate currently outside its own cooldown gate.
    void DSP039ApplyAuraTic(int aura, int logicalTic, double centerX,
        double centerY, int recoveryMilli)
    {
        int systemId = dsp039AuraSystem[aura];
        int rank = dsp039AuraRank[aura];
        int damageMilli = DSP039AuraRows.DamageMilli(systemId, rank);
        int rowRadiusMilliUnits = DSP039AuraRows.RadiusMilliUnits(systemId, rank);
        int baseCooldownTics = DSP039AuraRows.CooldownTics(systemId, rank);
        if (damageMilli < 0 || rowRadiusMilliUnits < 0 || baseCooldownTics < 1)
        {
            Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P039_ROW_INVALID weapon_id=%d system_id=%d rank=%d", dsp039AuraId[aura], systemId, rank);
            return;
        }
        // Controlled fixture-only radius scale (see DSP039EquipAura); 1000
        // milli is a no-op, matching the row radius exactly.
        int radiusMilliUnits;
        if (!DSP039AuraMath.CheckedScaleMilli(rowRadiusMilliUnits,
            dsp039AuraAreaAdjustmentMilli[aura], radiusMilliUnits))
        {
            Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P039_AREA_ADJUSTMENT_OVERFLOW weapon_id=%d", dsp039AuraId[aura]);
            return;
        }
        int gateTics = DSP039AuraMath.GateTicsAfterCooldown(baseCooldownTics,
            dsp039AuraCooldownMultiplierMilli[aura]);
        // Row damage plus the Soul Eater growth bonus (whole damage points,
        // converted to milli) is scaled by Might as a single checked
        // transaction, so a grown Soul Eater's accepted hit actually
        // reflects its recovered-HP bonus.
        int growthBonusMilli = dsp039AuraGrowthBonusDamage[aura] * 1000;
        int totalDamageMilli = damageMilli + growthBonusMilli;

        double queryRadius = double(radiusMilliUnits) / 1000.0
            + DSP039_MAX_TARGET_RADIUS_BOUND_UNITS;
        DSP024RadiusCandidates(centerX, centerY, queryRadius);
        dsp039CandidateSlots.Clear(); dsp039CandidateGenerations.Clear();
        dsp039CandidateIds.Clear();
        for (int c = 0; c < spatialCandidateCount; c++)
        {
            dsp039CandidateSlots.Push(spatialCandidateSlots[c]);
            dsp039CandidateGenerations.Push(spatialCandidateGenerations[c]);
            dsp039CandidateIds.Push(spatialCandidateIds[c]);
        }
        DSP039SortCandidatesByStableId();

        for (int c = 0; c < dsp039CandidateSlots.Size(); c++)
        {
            int slot = dsp039CandidateSlots[c];
            int generation = dsp039CandidateGenerations[c];
            int stableId = dsp039CandidateIds[c];
            if (!ValidParts(slot, generation, stableId)
                || kinds[slot] != DSP039_KIND_ENEMY || health[slot] <= 0
                || collisionRadii[slot] < 0.0) continue;
            if (!DSP039AuraMath.CircleContact(centerX, centerY, radiusMilliUnits,
                x[slot], y[slot], collisionRadii[slot])) continue;
            if (!DSP039TargetReady(dsp039AuraSlot[aura], dsp039AuraGeneration[aura],
                dsp039AuraId[aura], dsp039AuraFormGeneration[aura], slot,
                generation, stableId, logicalTic)) continue;

            int scaledMilli;
            bool checked = DSP025CheckedDamage(totalDamageMilli, 0,
                dsp039AuraMightMilli[aura], scaledMilli)
                && scaledMilli >= 0 && scaledMilli <= DSP039_MAX_SAFE_DAMAGE_MILLI;
            int before; int after; int killed;
            if (!checked || !DSP025ApplyLogicalHit(slot, generation, stableId,
                scaledMilli, before, after, killed))
            {
                dsp039RejectedHits++;
                dsp039RejectedDamageMilli += checked ? scaledMilli : 0;
                continue;
            }
            DSP039RecordLedgerHit(dsp039AuraSlot[aura], dsp039AuraGeneration[aura],
                dsp039AuraId[aura], dsp039AuraFormGeneration[aura], slot,
                generation, stableId, logicalTic + gateTics);
            if (!DSP039TargetImmune(slot, generation, stableId))
                DSP039ApplyDebuff(slot, generation, stableId);
            // Garlic / Soul Eater push enemies out of the aura (Knockback 1).
            if (rsActive && killed == 0 && DSP030VerticalSlice(self) != null) DSP030VerticalSlice(self).EnemyKnockback(slot, centerX, centerY, 1000);
            int delta = before - after;
            if (delta >= 0 && dsp039AcceptedDamageMilli <= 2147483647 - delta)
                dsp039AcceptedDamageMilli += delta;
            else Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P039_DAMAGE_OVERFLOW tic=%d", logicalTic);
            int eventId = DSP039NewEventId();
            dsp039AcceptedHits++;
            DSSound.Weapon(systemId, gateTics);
            dsp039LastAcceptedEventId = eventId;
            dsp039LastAcceptedSystemId = systemId;
            dsp039LastAcceptedWeaponId = dsp039AuraId[aura];
            dsp039LastAcceptedTargetId = stableId;
            { if (!dsQuiet) Console.Printf("DS_P039_AURA_HIT accepted=1 authority=P025_CHECKED_LOGICAL_HIT event_id=%d tic=%d system_id=%d rank=%d weapon_id=%d form_generation=%d target_slot=%d target_generation=%d target_id=%d row_radius_milli=%d area_adjustment_milli=%d radius_milli=%d damage_milli_row=%d growth_bonus_damage=%d damage_milli_total=%d might_milli=%d damage_milli=%d before=%d after=%d accepted_delta_milli=%d ready_tic=%d", eventId, logicalTic, systemId, rank, dsp039AuraId[aura], dsp039AuraFormGeneration[aura], slot, generation, stableId, rowRadiusMilliUnits, dsp039AuraAreaAdjustmentMilli[aura], radiusMilliUnits, damageMilli, dsp039AuraGrowthBonusDamage[aura], totalDamageMilli, dsp039AuraMightMilli[aura], scaledMilli, before, after, delta, logicalTic + gateTics); }
            if (killed != 0)
            {
                HandleEnemyDeath(slot, before, eventId);
                if (systemId == DSP039AuraRows.SYSTEM_SOUL_EATER)
                    DSP039TrySpawnHeart(logicalTic, scaledMilli, x[slot], y[slot],
                        recoveryMilli);
            }
        }
    }

    // recoveryMilli is the P033-resolved Recovery stat (STAT_RECOVERY),
    // needed only for the Little Heart heal-scaling formula; Garlic/Soul
    // Eater damage itself never reads it.
    void DSP039ProcessAuraTic(int logicalTic, double playerX, double playerY,
        int mightMilli, int cooldownMultiplierMilli, int recoveryMilli)
    {
        if (logicalTic < 0 || mightMilli < 1 || cooldownMultiplierMilli < 1)
            return;
        DSP039PurgeStaleAuras();
        DSP039PurgeStaleLedger();
        DSP039PurgeStaleDebuff();
        for (int aura = 0; aura < dsp039AuraActive.Size(); aura++)
        {
            if (dsp039AuraActive[aura] == 0) continue;
            dsp039AuraMightMilli[aura] = LbMightFor(dsp039AuraSystem[aura], mightMilli);
            if (rsActive) dsp039AuraAreaAdjustmentMilli[aura] = RsAreaFor(dsp039AuraSystem[aura]);
            dsp039AuraCooldownMultiplierMilli[aura] = cooldownMultiplierMilli;
            DSP039ApplyAuraTic(aura, logicalTic, playerX, playerY, recoveryMilli);
        }
    }

    // ---- Rebase (world-origin shift) --------------------------------------

    void DSP039RebaseAura(double deltaX, double deltaY)
    {
        for (int i = 0; i < dsp039HeartActive.Size(); i++)
        {
            if (dsp039HeartActive[i] == 0) continue;
            dsp039HeartX[i] += deltaX; dsp039HeartY[i] += deltaY;
        }
    }

    // ---- State hash (P029 save/load exact-equality gate) ------------------

    int DSP039AuraHashMix(int hash, int value)
    {
        int normalized = value % 1000003;
        if (normalized < 0) normalized += 1000003;
        return (hash * 31 + normalized) % 1000003;
    }

    int DSP039AuraHashMixDoubleMilli(int hash, double value)
    {
        int quantized;
        if (value >= 2000000.0) quantized = 2000000000;
        else if (value <= -2000000.0) quantized = -2000000000;
        else quantized = int(value * 1000.0);
        return DSP039AuraHashMix(hash, quantized);
    }

    int DSP039HashAuraState(int hash, int i)
    {
        hash = DSP039AuraHashMix(hash, dsp039AuraActive[i]);
        if (dsp039AuraActive[i] == 0) return hash;
        hash = DSP039AuraHashMix(hash, dsp039AuraSystem[i]);
        hash = DSP039AuraHashMix(hash, dsp039AuraRank[i]);
        hash = DSP039AuraHashMix(hash, dsp039AuraSlot[i]);
        hash = DSP039AuraHashMix(hash, dsp039AuraGeneration[i]);
        hash = DSP039AuraHashMix(hash, dsp039AuraId[i]);
        hash = DSP039AuraHashMix(hash, dsp039AuraFormGeneration[i]);
        hash = DSP039AuraHashMix(hash, dsp039AuraOwnerSlot[i]);
        hash = DSP039AuraHashMix(hash, dsp039AuraOwnerGeneration[i]);
        hash = DSP039AuraHashMix(hash, dsp039AuraOwnerId[i]);
        hash = DSP039AuraHashMix(hash, dsp039AuraMightMilli[i]);
        hash = DSP039AuraHashMix(hash, dsp039AuraCooldownMultiplierMilli[i]);
        hash = DSP039AuraHashMix(hash, dsp039AuraRecoveredHealMilli[i]);
        hash = DSP039AuraHashMix(hash, dsp039AuraGrowthBonusDamage[i]);
        hash = DSP039AuraHashMix(hash, dsp039AuraAreaAdjustmentMilli[i]);
        return hash;
    }

    int DSP039HashLedgerState(int hash, int i)
    {
        hash = DSP039AuraHashMix(hash, dsp039HitWeaponSlot[i]);
        hash = DSP039AuraHashMix(hash, dsp039HitWeaponGeneration[i]);
        hash = DSP039AuraHashMix(hash, dsp039HitWeaponId[i]);
        hash = DSP039AuraHashMix(hash, dsp039HitFormGeneration[i]);
        hash = DSP039AuraHashMix(hash, dsp039HitTargetSlot[i]);
        hash = DSP039AuraHashMix(hash, dsp039HitTargetGeneration[i]);
        hash = DSP039AuraHashMix(hash, dsp039HitTargetId[i]);
        hash = DSP039AuraHashMix(hash, dsp039HitReadyTic[i]);
        return hash;
    }

    int DSP039HashDebuffState(int hash, int i)
    {
        hash = DSP039AuraHashMix(hash, dsp039DebuffTargetSlot[i]);
        hash = DSP039AuraHashMix(hash, dsp039DebuffTargetGeneration[i]);
        hash = DSP039AuraHashMix(hash, dsp039DebuffTargetId[i]);
        hash = DSP039AuraHashMix(hash, dsp039DebuffKnockbackMilli[i]);
        hash = DSP039AuraHashMix(hash, dsp039DebuffFreezeResistMilli[i]);
        hash = DSP039AuraHashMix(hash, dsp039DebuffImmune[i]);
        return hash;
    }

    int DSP039HashHeartState(int hash, int i)
    {
        hash = DSP039AuraHashMix(hash, dsp039HeartActive[i]);
        if (dsp039HeartActive[i] == 0) return hash;
        hash = DSP039AuraHashMix(hash, dsp039HeartId[i]);
        hash = DSP039AuraHashMix(hash, dsp039HeartGeneration[i]);
        hash = DSP039AuraHashMixDoubleMilli(hash, dsp039HeartX[i]);
        hash = DSP039AuraHashMixDoubleMilli(hash, dsp039HeartY[i]);
        hash = DSP039AuraHashMix(hash, dsp039HeartHealMilli[i]);
        hash = DSP039AuraHashMix(hash, dsp039HeartSpawnTic[i]);
        return hash;
    }

    int DSP039AuraStateHash()
    {
        int hash = 39;
        hash = DSP039AuraHashMix(hash, dsp039AcceptedHits);
        hash = DSP039AuraHashMix(hash, dsp039RejectedHits);
        hash = DSP039AuraHashMix(hash, dsp039AcceptedDamageMilli);
        hash = DSP039AuraHashMix(hash, dsp039RejectedDamageMilli);
        hash = DSP039AuraHashMix(hash, dsp039HeartsSpawned);
        hash = DSP039AuraHashMix(hash, dsp039HeartsCollected);
        hash = DSP039AuraHashMix(hash, dsp039LastAcceptedEventId);
        hash = DSP039AuraHashMix(hash, dsp039LastAcceptedSystemId);
        hash = DSP039AuraHashMix(hash, dsp039LastAcceptedWeaponId);
        hash = DSP039AuraHashMix(hash, dsp039LastAcceptedTargetId);
        hash = DSP039AuraHashMix(hash, dsp039NextEventId);
        hash = DSP039AuraHashMix(hash, dsp039NextHeartId);
        hash = DSP039AuraHashMix(hash, dsp039NextHeartGeneration);
        hash = DSP039AuraHashMix(hash, dsp039HeartRngState);
        hash = DSP039AuraHashMix(hash, dsp039AuraActive.Size());
        hash = DSP039AuraHashMix(hash, dsp039HitWeaponId.Size());
        hash = DSP039AuraHashMix(hash, dsp039DebuffTargetSlot.Size());
        hash = DSP039AuraHashMix(hash, dsp039HeartActive.Size());
        for (int i = 0; i < dsp039AuraActive.Size(); i++)
            hash = DSP039HashAuraState(hash, i);
        for (int i = 0; i < dsp039HitWeaponId.Size(); i++)
            hash = DSP039HashLedgerState(hash, i);
        for (int i = 0; i < dsp039DebuffTargetSlot.Size(); i++)
            hash = DSP039HashDebuffState(hash, i);
        for (int i = 0; i < dsp039HeartActive.Size(); i++)
            hash = DSP039HashHeartState(hash, i);
        return hash;
    }
}
