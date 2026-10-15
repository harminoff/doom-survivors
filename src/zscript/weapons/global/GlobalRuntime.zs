// P040 logical-screen strike, erasure and global-effect authority.
//
// Implements docs/contracts/global-strikes.md (frozen by the lead
// 2026-09-27): Lightning Ring -> Thunder Loop strikes, Pentagram -> Gorgeous
// Moon erasure, and the Crown/Duplicator consumption seams. Reconciled
// against the LANDED src/zscript/weapons/global/GlobalRows.zs (verified
// against the actual file, not the original brief):
//   SYSTEM_LIGHTNING=50, SYSTEM_THUNDER_LOOP=51, SYSTEM_PENTAGRAM=52,
//   SYSTEM_GORGEOUS_MOON=53; static RankCount, DamageMilli, AreaMilli,
//   Amount, PeriodTics, StrikeIntervalTics(system, rank) -- takes rank, NOT
//   just system as the brief implied -- StrikeRadiusMilliUnits, SpareMilli,
//   TryGetEvolution(sourceSystem, sourceRank, dependencyItem, out
//   evolvedSystem). dependencyItem is DEPENDENCY_AMOUNT_SOURCE_KEY=1 /
//   DEPENDENCY_GROWTH_SOURCE_KEY=2 -- LOCAL keys to GlobalRows.zs, never a
//   raw P031/P033 item ID (ITEM_DUPLICATOR=9/ITEM_CROWN=10 stay on the
//   caller side; this file never references them). Pentagram/Gorgeous Moon
//   report DamageMilli=0 by design (erasure and current-health damage are
//   not row-damage transactions), which this file never reads for those two
//   systems anyway. Consts REGION_HALF_EXTENT=128,
//   THUNDER_REPEAT_DELAY_TICS=18, MOON_BEAM_COUNT=6,
//   MOON_PHASE2_DELAY_TICS=35, MOON_PERIOD_FLOOR_TICS=525,
//   MOON_GEM_BASE_XP_MILLI=1000, LUCK_BASE_MILLI=1000 all landed as
//   documented.
//
// Reconciled against the landed src/zscript/gameplay/stats/ResolvedStats.zs:
// ITEM_DUPLICATOR=9, ITEM_CROWN=10, STAT_AMOUNT=6, STAT_GROWTH=7,
// DSP033RecomputeAmountGrowth(dupRank, crownRank), DSP033AmountApplies
// (Lightning/Thunder/Moon only) and a SEPARATE
// dsp033ResolvedRankHashAmountGrowth / DSP033StatRules.RankHashAmountGrowth
// (dup, crown) that the P040 MAP16 save/restore gate must additionally
// record and compare, alongside this file's own DSP040GlobalStateHash --
// both wired in VerticalSlice.zs, not here.
//
// External dependencies used here, per the established P02x contracts:
//   DSP024RadiusCandidates / spatialCandidate* -- P024 broad phase.
//   DSP025CheckedDamage / DSP025ApplyLogicalHit -- P025 checked hits.
//   ValidParts / DestroyParts / Allocate / kinds / health / x / y /
//   collisionRadii -- P020 EntityStore.
//   HandleEnemyDeath(slot, beforeHealth, eventId) -- supplied by the
//   composing class (VerticalSlice), matching every other family.
//   mixin DSP027ExperienceStore -- P027, always composed alongside
//   DSP040Global in the same handler so pickups can be created, collected
//   with a Growth bonus, erased or force-attracted directly.
//   DSP033Resolved(DSP033StatRules.STAT_AMOUNT / STAT_GROWTH) -- P033,
//   landed in ResolvedStats.zs by P040-W01.
mixin class DSP040Global
{
    const DSP040_KIND_ENEMY = 1;
    const DSP040_MAX_TARGET_RADIUS_BOUND_UNITS = 64.0;
    const DSP040_MAX_SAFE_DAMAGE_MILLI = 2000000000;
    // Base strike-circle radius before the row's Area scale is applied, per
    // the contract ("a circle of radius 16 logical units x Area"). Kept here
    // as a documented fallback only if DSP040GlobalRows.StrikeRadiusMilliUnits
    // is unavailable; the row-provided value is always preferred.
    const DSP040_STRIKE_BASE_RADIUS_UNITS = 16;

    // ---- Lightning Ring / Thunder Loop instances ---------------------------
    Array<int> dsp040StrikeActive;
    Array<int> dsp040StrikeSystem;
    Array<int> dsp040StrikeRank;
    Array<int> dsp040StrikeSlot;
    Array<int> dsp040StrikeGeneration;
    Array<int> dsp040StrikeId;
    Array<int> dsp040StrikeFormGeneration;
    Array<int> dsp040StrikeOwnerSlot;
    Array<int> dsp040StrikeOwnerGeneration;
    Array<int> dsp040StrikeOwnerId;
    Array<int> dsp040StrikeMightMilli;
    Array<int> dsp040StrikeCooldownMultiplierMilli;
    Array<int> dsp040StrikeNextActivationTic;

    // Per-activation "already chosen" ledger, keyed by weapon id + form
    // generation so a transform starts a fresh ledger. Cleared entries are
    // swept on the next activation for that weapon rather than globally, so
    // concurrent weapon instances never interfere with each other's ledgers.
    Array<int> dsp040ChosenWeaponId;
    Array<int> dsp040ChosenFormGeneration;
    Array<int> dsp040ChosenTargetId;

    // Scheduled immediate strike events (one per strike within an
    // activation, fired on its own tic per StrikeIntervalTics).
    Array<int> dsp040ScheduleActive;
    Array<int> dsp040ScheduleWeaponSlot;
    Array<int> dsp040ScheduleWeaponGeneration;
    Array<int> dsp040ScheduleWeaponId;
    Array<int> dsp040ScheduleFormGeneration;
    Array<int> dsp040ScheduleSystem;
    Array<int> dsp040ScheduleRank;
    Array<int> dsp040ScheduleMightMilli;
    Array<int> dsp040ScheduleFireTic;

    // Thunder Loop repeats: a location-locked follow-up AoE, independent of
    // any live target handle (contract: "against whatever is inside then").
    Array<int> dsp040RepeatActive;
    Array<int> dsp040RepeatWeaponId;
    Array<double> dsp040RepeatX;
    Array<double> dsp040RepeatY;
    Array<int> dsp040RepeatRadiusMilliUnits;
    Array<int> dsp040RepeatDamageMilli;
    Array<int> dsp040RepeatMightMilli;
    Array<int> dsp040RepeatFireTic;
    Array<int> dsp040RepeatSystem;
    Array<int> dsp040RepeatRank;

    // ---- Pentagram / Gorgeous Moon instances -------------------------------
    Array<int> dsp040EraseActive;
    Array<int> dsp040EraseSystem;
    Array<int> dsp040EraseRank;
    Array<int> dsp040EraseSlot;
    Array<int> dsp040EraseGeneration;
    Array<int> dsp040EraseId;
    Array<int> dsp040EraseFormGeneration;
    Array<int> dsp040EraseOwnerSlot;
    Array<int> dsp040EraseOwnerGeneration;
    Array<int> dsp040EraseOwnerId;
    Array<int> dsp040EraseCooldownMultiplierMilli;
    Array<int> dsp040EraseNextActivationTic;

    // Gorgeous Moon phase-2 pending records (one per activation awaiting its
    // +35-tic erasure/gem tic).
    Array<int> dsp040MoonPendingActive;
    Array<int> dsp040MoonPendingWeaponId;
    Array<int> dsp040MoonPendingFormGeneration;
    Array<int> dsp040MoonPendingFireTic;
    Array<int> dsp040MoonPendingAmountBonus;

    // Protected-from-erasure flag (Reaper/boss fixtures). Protected enemies
    // still take ordinary strike/beam damage; only erasure is exempted.
    Array<int> dsp040ProtectedSlot;
    Array<int> dsp040ProtectedGeneration;
    Array<int> dsp040ProtectedId;

    // Transient per-call candidate scratch (never persisted/hashed).
    Array<int> dsp040CandidateSlots;
    Array<int> dsp040CandidateGenerations;
    Array<int> dsp040CandidateIds;

    int dsp040NextEventId;
    // Dedicated RNG streams; never share state with the attack RNG, the
    // P039 Heart RNG, or each other.
    int dsp040StrikeRngState;
    int dsp040EraseRngState;

    int dsp040AcceptedHits;
    int dsp040AcceptedDamageMilli;
    int dsp040SkippedStrikes;
    int dsp040ThunderRepeatsScheduled;
    int dsp040ThunderRepeatsFired;
    int dsp040ErasedEnemies;
    int dsp040KilledByGlobal;
    int dsp040SparedPickups;
    int dsp040ErasedPickups;
    int dsp040MoonBeamHits;
    int dsp040MoonGemsCreated;
    int dsp040LastEventId;
    int dsp040LastEventKind;
    int dsp040LastEventTargetId;

    void DSP040ResetGlobal()
    {
        dsp040StrikeActive.Clear(); dsp040StrikeSystem.Clear();
        dsp040StrikeRank.Clear(); dsp040StrikeSlot.Clear();
        dsp040StrikeGeneration.Clear(); dsp040StrikeId.Clear();
        dsp040StrikeFormGeneration.Clear(); dsp040StrikeOwnerSlot.Clear();
        dsp040StrikeOwnerGeneration.Clear(); dsp040StrikeOwnerId.Clear();
        dsp040StrikeMightMilli.Clear(); dsp040StrikeCooldownMultiplierMilli.Clear();
        dsp040StrikeNextActivationTic.Clear();
        dsp040ChosenWeaponId.Clear(); dsp040ChosenFormGeneration.Clear();
        dsp040ChosenTargetId.Clear();
        dsp040ScheduleActive.Clear(); dsp040ScheduleWeaponSlot.Clear();
        dsp040ScheduleWeaponGeneration.Clear(); dsp040ScheduleWeaponId.Clear();
        dsp040ScheduleFormGeneration.Clear(); dsp040ScheduleSystem.Clear();
        dsp040ScheduleRank.Clear(); dsp040ScheduleMightMilli.Clear();
        dsp040ScheduleFireTic.Clear();
        dsp040RepeatActive.Clear(); dsp040RepeatWeaponId.Clear();
        dsp040RepeatX.Clear(); dsp040RepeatY.Clear();
        dsp040RepeatRadiusMilliUnits.Clear(); dsp040RepeatDamageMilli.Clear();
        dsp040RepeatMightMilli.Clear(); dsp040RepeatFireTic.Clear();
        dsp040RepeatSystem.Clear(); dsp040RepeatRank.Clear();
        dsp040EraseActive.Clear(); dsp040EraseSystem.Clear();
        dsp040EraseRank.Clear(); dsp040EraseSlot.Clear();
        dsp040EraseGeneration.Clear(); dsp040EraseId.Clear();
        dsp040EraseFormGeneration.Clear(); dsp040EraseOwnerSlot.Clear();
        dsp040EraseOwnerGeneration.Clear(); dsp040EraseOwnerId.Clear();
        dsp040EraseCooldownMultiplierMilli.Clear();
        dsp040EraseNextActivationTic.Clear();
        dsp040MoonPendingActive.Clear(); dsp040MoonPendingWeaponId.Clear();
        dsp040MoonPendingFormGeneration.Clear(); dsp040MoonPendingFireTic.Clear();
        dsp040MoonPendingAmountBonus.Clear();
        dsp040ProtectedSlot.Clear(); dsp040ProtectedGeneration.Clear();
        dsp040ProtectedId.Clear();
        dsp040CandidateSlots.Clear(); dsp040CandidateGenerations.Clear();
        dsp040CandidateIds.Clear();
        dsp040NextEventId = 1;
        // Fixed non-zero seeds keep fixtures deterministic; a caller that
        // needs a controlled seed calls DSP040SeedStrikeRng/DSP040SeedEraseRng.
        dsp040StrikeRngState = 668265263;
        dsp040EraseRngState = 374761393;
        dsp040AcceptedHits = 0; dsp040AcceptedDamageMilli = 0;
        dsp040SkippedStrikes = 0; dsp040ThunderRepeatsScheduled = 0;
        dsp040ThunderRepeatsFired = 0; dsp040ErasedEnemies = 0;
        dsp040KilledByGlobal = 0; dsp040SparedPickups = 0;
        dsp040ErasedPickups = 0; dsp040MoonBeamHits = 0;
        dsp040MoonGemsCreated = 0; dsp040LastEventId = 0;
        dsp040LastEventKind = 0; dsp040LastEventTargetId = 0;
    }

    void DSP040SeedStrikeRng(int seed) { dsp040StrikeRngState = seed != 0 ? seed : 668265263; }
    void DSP040SeedEraseRng(int seed) { dsp040EraseRngState = seed != 0 ? seed : 374761393; }

    int DSP040NewEventId()
    {
        int eventId = dsp040NextEventId++;
        if (dsp040NextEventId <= 0) dsp040NextEventId = 1;
        if (eventId <= 0) eventId = dsp040NextEventId;
        return eventId;
    }

    // ---- Protected-from-erasure -------------------------------------------

    int DSP040FindProtected(int slot, int generation, int stableId)
    {
        for (int i = 0; i < dsp040ProtectedId.Size(); i++)
            if (dsp040ProtectedSlot[i] == slot
                && dsp040ProtectedGeneration[i] == generation
                && dsp040ProtectedId[i] == stableId) return i;
        return -1;
    }

    void DSP040SetProtected(int slot, int generation, int stableId, bool isProtected)
    {
        int index = DSP040FindProtected(slot, generation, stableId);
        if (!isProtected)
        {
            if (index < 0) return;
            int last = dsp040ProtectedId.Size() - 1;
            dsp040ProtectedSlot[index] = dsp040ProtectedSlot[last];
            dsp040ProtectedGeneration[index] = dsp040ProtectedGeneration[last];
            dsp040ProtectedId[index] = dsp040ProtectedId[last];
            dsp040ProtectedSlot.Pop(); dsp040ProtectedGeneration.Pop();
            dsp040ProtectedId.Pop();
            return;
        }
        if (index >= 0) return;
        dsp040ProtectedSlot.Push(slot); dsp040ProtectedGeneration.Push(generation);
        dsp040ProtectedId.Push(stableId);
    }

    bool DSP040IsProtected(int slot, int generation, int stableId)
    {
        return DSP040FindProtected(slot, generation, stableId) >= 0;
    }

    void DSP040PurgeStaleProtected()
    {
        for (int i = dsp040ProtectedId.Size() - 1; i >= 0; i--)
        {
            if (ValidParts(dsp040ProtectedSlot[i], dsp040ProtectedGeneration[i],
                dsp040ProtectedId[i])) continue;
            int last = dsp040ProtectedId.Size() - 1;
            dsp040ProtectedSlot[i] = dsp040ProtectedSlot[last];
            dsp040ProtectedGeneration[i] = dsp040ProtectedGeneration[last];
            dsp040ProtectedId[i] = dsp040ProtectedId[last];
            dsp040ProtectedSlot.Pop(); dsp040ProtectedGeneration.Pop();
            dsp040ProtectedId.Pop();
        }
    }

    // ---- Erasure (distinct from ordinary death) ----------------------------

    // No damage transaction, no XP/chest drop request, no on-kill effect, no
    // kill-count increment. Generation-safe release only, plus the separate
    // `erased` counter. This is the labelled engineering policy from the
    // contract's "Kill versus erasure" section.
    bool DSP040EraseEnemy(int slot, int generation, int stableId)
    {
        if (!ValidParts(slot, generation, stableId)
            || kinds[slot] != DSP040_KIND_ENEMY
            || DSP040IsProtected(slot, generation, stableId))
            return false;
        if (!DestroyParts(slot, generation, stableId)) return false;
        dsp040ErasedEnemies++;
        { if (!dsQuiet) Console.Printf("DS_P040_ERASE_ENEMY accepted=1 slot=%d generation=%d stable_id=%d erased_total=%d classification=DISTINCT_NO_REWARD_OPERATION", slot, generation, stableId, dsp040ErasedEnemies); }
        return true;
    }

    // ---- Equip / transform: Lightning Ring / Thunder Loop -----------------

    int DSP040FindStrike(int weaponSlot, int weaponGeneration, int weaponId)
    {
        for (int i = 0; i < dsp040StrikeActive.Size(); i++)
            if (dsp040StrikeActive[i] != 0
                && dsp040StrikeSlot[i] == weaponSlot
                && dsp040StrikeGeneration[i] == weaponGeneration
                && dsp040StrikeId[i] == weaponId) return i;
        return -1;
    }

    bool DSP040EquipStrike(int systemId, int rank, int weaponSlot,
        int weaponGeneration, int weaponId, int formGeneration,
        int ownerSlot, int ownerGeneration, int ownerId, int mightMilli,
        int cooldownMultiplierMilli, int activationTic)
    {
        if (rank < 1 || rank > DSP040GlobalRows.RankCount(systemId)
            || !ValidParts(weaponSlot, weaponGeneration, weaponId)
            || !ValidParts(ownerSlot, ownerGeneration, ownerId)
            || formGeneration <= 0 || mightMilli < 1
            || cooldownMultiplierMilli < 1
            || DSP040FindStrike(weaponSlot, weaponGeneration, weaponId) >= 0)
            return false;
        dsp040StrikeActive.Push(1); dsp040StrikeSystem.Push(systemId);
        dsp040StrikeRank.Push(rank); dsp040StrikeSlot.Push(weaponSlot);
        dsp040StrikeGeneration.Push(weaponGeneration); dsp040StrikeId.Push(weaponId);
        dsp040StrikeFormGeneration.Push(formGeneration);
        dsp040StrikeOwnerSlot.Push(ownerSlot);
        dsp040StrikeOwnerGeneration.Push(ownerGeneration);
        dsp040StrikeOwnerId.Push(ownerId);
        dsp040StrikeMightMilli.Push(mightMilli);
        dsp040StrikeCooldownMultiplierMilli.Push(cooldownMultiplierMilli);
        dsp040StrikeNextActivationTic.Push(activationTic);
        return true;
    }

    // N2 dispatcher rank-change API (docs/contracts/normal-play-integration.md
    // "Weapon dispatcher"). Mirrors DSP035SetFixtureRank's shape for the
    // strike (Lightning Ring/Thunder Loop) side of the global engine.
    bool DSP040SetStrikeRank(int weaponSlot, int weaponGeneration,
        int weaponId, int systemId, int rank)
    {
        if (rank < 1 || rank > DSP040GlobalRows.RankCount(systemId)) return false;
        int index = DSP040FindStrike(weaponSlot, weaponGeneration, weaponId);
        if (index < 0 || dsp040StrikeSystem[index] != systemId) return false;
        int oldRank = dsp040StrikeRank[index];
        dsp040StrikeRank[index] = rank;
        { if (!dsQuiet) Console.Printf("DS_N2_GLOBAL_STRIKE_RANK accepted=1 system_id=%d prior_rank=%d rank=%d weapon_id=%d weapon_generation=%d classification=N2_DISPATCHER_RANK_CHANGE", systemId, oldRank, rank, weaponId, weaponGeneration); }
        return true;
    }

    // Lightning Ring -> Thunder Loop. Future-form-only: the handle is kept,
    // a new form generation clears the chosen-target ledger and any
    // schedule entries tied to the previous form.
    bool DSP040TransformToLoop(int weaponSlot, int weaponGeneration,
        int weaponId, int dependencyItem, int rank, int newFormGeneration)
    {
        int index = DSP040FindStrike(weaponSlot, weaponGeneration, weaponId);
        if (index < 0 || dsp040StrikeSystem[index] != DSP040GlobalRows.SYSTEM_LIGHTNING)
            return false;
        int evolvedSystem;
        if (!DSP040GlobalRows.TryGetEvolution(dsp040StrikeSystem[index],
                dsp040StrikeRank[index], dependencyItem, evolvedSystem)
            || evolvedSystem != DSP040GlobalRows.SYSTEM_THUNDER_LOOP
            || rank < 1 || rank > DSP040GlobalRows.RankCount(evolvedSystem)
            || newFormGeneration <= dsp040StrikeFormGeneration[index])
            return false;
        dsp040StrikeSystem[index] = evolvedSystem;
        dsp040StrikeRank[index] = rank;
        dsp040StrikeFormGeneration[index] = newFormGeneration;
        { if (!dsQuiet) Console.Printf("DS_P040_TRANSFORM accepted=1 kind=LOOP weapon_id=%d evolved_system=%d rank=%d form_generation=%d", weaponId, evolvedSystem, rank, newFormGeneration); }
        return true;
    }

    void DSP040PurgeStaleStrikes()
    {
        for (int i = 0; i < dsp040StrikeActive.Size(); i++)
        {
            if (dsp040StrikeActive[i] == 0) continue;
            if (!ValidParts(dsp040StrikeSlot[i], dsp040StrikeGeneration[i], dsp040StrikeId[i])
                || !ValidParts(dsp040StrikeOwnerSlot[i], dsp040StrikeOwnerGeneration[i],
                    dsp040StrikeOwnerId[i]))
                dsp040StrikeActive[i] = 0;
        }
    }

    // ---- Equip / transform: Pentagram / Gorgeous Moon ----------------------

    int DSP040FindErase(int weaponSlot, int weaponGeneration, int weaponId)
    {
        for (int i = 0; i < dsp040EraseActive.Size(); i++)
            if (dsp040EraseActive[i] != 0
                && dsp040EraseSlot[i] == weaponSlot
                && dsp040EraseGeneration[i] == weaponGeneration
                && dsp040EraseId[i] == weaponId) return i;
        return -1;
    }

    bool DSP040EquipPentagram(int systemId, int rank, int weaponSlot,
        int weaponGeneration, int weaponId, int formGeneration,
        int ownerSlot, int ownerGeneration, int ownerId,
        int cooldownMultiplierMilli, int activationTic)
    {
        if (rank < 1 || rank > DSP040GlobalRows.RankCount(systemId)
            || !ValidParts(weaponSlot, weaponGeneration, weaponId)
            || !ValidParts(ownerSlot, ownerGeneration, ownerId)
            || formGeneration <= 0 || cooldownMultiplierMilli < 1
            || DSP040FindErase(weaponSlot, weaponGeneration, weaponId) >= 0)
            return false;
        dsp040EraseActive.Push(1); dsp040EraseSystem.Push(systemId);
        dsp040EraseRank.Push(rank); dsp040EraseSlot.Push(weaponSlot);
        dsp040EraseGeneration.Push(weaponGeneration); dsp040EraseId.Push(weaponId);
        dsp040EraseFormGeneration.Push(formGeneration);
        dsp040EraseOwnerSlot.Push(ownerSlot);
        dsp040EraseOwnerGeneration.Push(ownerGeneration);
        dsp040EraseOwnerId.Push(ownerId);
        dsp040EraseCooldownMultiplierMilli.Push(cooldownMultiplierMilli);
        dsp040EraseNextActivationTic.Push(activationTic);
        return true;
    }

    // N2 dispatcher rank-change API for the erase (Pentagram/Gorgeous Moon)
    // side of the global engine. Same shape as DSP040SetStrikeRank above.
    bool DSP040SetEraseRank(int weaponSlot, int weaponGeneration,
        int weaponId, int systemId, int rank)
    {
        if (rank < 1 || rank > DSP040GlobalRows.RankCount(systemId)) return false;
        int index = DSP040FindErase(weaponSlot, weaponGeneration, weaponId);
        if (index < 0 || dsp040EraseSystem[index] != systemId) return false;
        int oldRank = dsp040EraseRank[index];
        dsp040EraseRank[index] = rank;
        { if (!dsQuiet) Console.Printf("DS_N2_GLOBAL_ERASE_RANK accepted=1 system_id=%d prior_rank=%d rank=%d weapon_id=%d weapon_generation=%d classification=N2_DISPATCHER_RANK_CHANGE", systemId, oldRank, rank, weaponId, weaponGeneration); }
        return true;
    }

    bool DSP040TransformToMoon(int weaponSlot, int weaponGeneration,
        int weaponId, int dependencyItem, int rank, int newFormGeneration)
    {
        int index = DSP040FindErase(weaponSlot, weaponGeneration, weaponId);
        if (index < 0 || dsp040EraseSystem[index] != DSP040GlobalRows.SYSTEM_PENTAGRAM)
            return false;
        int evolvedSystem;
        if (!DSP040GlobalRows.TryGetEvolution(dsp040EraseSystem[index],
                dsp040EraseRank[index], dependencyItem, evolvedSystem)
            || evolvedSystem != DSP040GlobalRows.SYSTEM_GORGEOUS_MOON
            || rank < 1 || rank > DSP040GlobalRows.RankCount(evolvedSystem)
            || newFormGeneration <= dsp040EraseFormGeneration[index])
            return false;
        dsp040EraseSystem[index] = evolvedSystem;
        dsp040EraseRank[index] = rank;
        dsp040EraseFormGeneration[index] = newFormGeneration;
        { if (!dsQuiet) Console.Printf("DS_P040_TRANSFORM accepted=1 kind=MOON weapon_id=%d evolved_system=%d rank=%d form_generation=%d", weaponId, evolvedSystem, rank, newFormGeneration); }
        return true;
    }

    // Labelled engineering-fixture control, never a resolved-stat or
    // source-derived value: a transform changes systemId/rank/form
    // generation but never the instance's own nextActivationTic (by
    // design -- see DSP040ProcessEraseTic, which only recomputes that tic
    // when an activation actually fires). Because Pentagram's real-source
    // Cooldown (up to 3150 tics at rank1, 2100 at rank8) and Gorgeous
    // Moon's 2100-tic base period both exceed a single bounded MAP16/MAP26
    // fixture run on their own, a caller that wants to PROVE a real
    // Pentagram erasure (with its own spare rolls) followed by a real
    // Moon phase 1 + phase 2 inside one bounded run needs to retime the
    // post-transform activation explicitly. This never touches damage,
    // targeting, or the erase/spare-roll math itself -- only when the next
    // activation is checked -- so it changes no accepted-hit/erase/spare
    // tuple's content, only its tic. Callers must label this in their own
    // evidence markers as a controlled fixture, not a resolved Cooldown.
    bool DSP040ForceEraseNextActivation(int weaponSlot, int weaponGeneration,
        int weaponId, int nextActivationTic)
    {
        int index = DSP040FindErase(weaponSlot, weaponGeneration, weaponId);
        if (index < 0) return false;
        dsp040EraseNextActivationTic[index] = nextActivationTic;
        return true;
    }

    void DSP040PurgeStaleErase()
    {
        for (int i = 0; i < dsp040EraseActive.Size(); i++)
        {
            if (dsp040EraseActive[i] == 0) continue;
            if (!ValidParts(dsp040EraseSlot[i], dsp040EraseGeneration[i], dsp040EraseId[i])
                || !ValidParts(dsp040EraseOwnerSlot[i], dsp040EraseOwnerGeneration[i],
                    dsp040EraseOwnerId[i]))
                dsp040EraseActive[i] = 0;
        }
    }

    // ---- Region candidate gathering ----------------------------------------

    void DSP040SortCandidatesByStableId()
    {
        for (int i = 1; i < dsp040CandidateIds.Size(); i++)
        {
            int j = i;
            while (j > 0 && DSP040GlobalMath.CandidatePrecedes(
                dsp040CandidateIds[j], dsp040CandidateGenerations[j],
                dsp040CandidateSlots[j], dsp040CandidateIds[j - 1],
                dsp040CandidateGenerations[j - 1], dsp040CandidateSlots[j - 1]))
            {
                int value = dsp040CandidateSlots[j];
                dsp040CandidateSlots[j] = dsp040CandidateSlots[j - 1];
                dsp040CandidateSlots[j - 1] = value;
                value = dsp040CandidateGenerations[j];
                dsp040CandidateGenerations[j] = dsp040CandidateGenerations[j - 1];
                dsp040CandidateGenerations[j - 1] = value;
                value = dsp040CandidateIds[j];
                dsp040CandidateIds[j] = dsp040CandidateIds[j - 1];
                dsp040CandidateIds[j - 1] = value;
                j--;
            }
        }
    }

    // Populates dsp040Candidate* with every live, in-region, non-protected
    // enemy, stable-ID sorted. The P024 query radius over-fetches (region
    // half-diagonal + target-radius bound) so InRegion's exact rectangle
    // check is always the authoritative narrow phase, matching the
    // logical-reference-v1 adapter policy.
    void DSP040GatherRegionEnemies(double playerX, double playerY)
    {
        double queryRadius = double(DSP040GlobalRows.REGION_HALF_EXTENT) * 1.4143
            + DSP040_MAX_TARGET_RADIUS_BOUND_UNITS;
        DSP024RadiusCandidates(playerX, playerY, queryRadius);
        dsp040CandidateSlots.Clear(); dsp040CandidateGenerations.Clear();
        dsp040CandidateIds.Clear();
        for (int c = 0; c < spatialCandidateCount; c++)
        {
            int slot = spatialCandidateSlots[c];
            int generation = spatialCandidateGenerations[c];
            int stableId = spatialCandidateIds[c];
            if (!ValidParts(slot, generation, stableId)
                || kinds[slot] != DSP040_KIND_ENEMY || health[slot] <= 0
                || DSP040IsProtected(slot, generation, stableId)) continue;
            if (!DSP040GlobalMath.InRegion(playerX, playerY, x[slot], y[slot],
                DSP040GlobalRows.REGION_HALF_EXTENT)) continue;
            dsp040CandidateSlots.Push(slot);
            dsp040CandidateGenerations.Push(generation);
            dsp040CandidateIds.Push(stableId);
        }
        DSP040SortCandidatesByStableId();
    }

    // ---- Lightning Ring / Thunder Loop: activation + strike scheduling ----

    bool DSP040AlreadyChosen(int weaponId, int formGeneration, int targetId)
    {
        for (int i = 0; i < dsp040ChosenWeaponId.Size(); i++)
            if (dsp040ChosenWeaponId[i] == weaponId
                && dsp040ChosenFormGeneration[i] == formGeneration
                && dsp040ChosenTargetId[i] == targetId) return true;
        return false;
    }

    void DSP040ClearChosen(int weaponId, int formGeneration)
    {
        for (int i = dsp040ChosenWeaponId.Size() - 1; i >= 0; i--)
        {
            if (dsp040ChosenWeaponId[i] != weaponId
                || dsp040ChosenFormGeneration[i] != formGeneration) continue;
            int last = dsp040ChosenWeaponId.Size() - 1;
            dsp040ChosenWeaponId[i] = dsp040ChosenWeaponId[last];
            dsp040ChosenFormGeneration[i] = dsp040ChosenFormGeneration[last];
            dsp040ChosenTargetId[i] = dsp040ChosenTargetId[last];
            dsp040ChosenWeaponId.Pop(); dsp040ChosenFormGeneration.Pop();
            dsp040ChosenTargetId.Pop();
        }
    }

    // Begins a new activation for one Lightning Ring/Thunder Loop instance:
    // clears its chosen-target ledger and schedules strikeCount events at
    // StrikeIntervalTics apart (0 => all share the activation tic, per
    // Thunder Loop's "strikes share one tic").
    void DSP040BeginStrikeActivation(int index, int tic, int resolvedAmount)
    {
        int systemId = dsp040StrikeSystem[index];
        int rank = dsp040StrikeRank[index];
        int rowAmount = DSP040GlobalRows.Amount(systemId, rank);
        if (rowAmount < 0) rowAmount = 0;
        if (rsActive) resolvedAmount += RsAmountFor(systemId) - rsAmount;
        int strikeCount;
        if (!DSP040GlobalMath.CheckedAdd(rowAmount, resolvedAmount < 0 ? 0 : resolvedAmount, strikeCount))
            strikeCount = rowAmount;
        int interval = DSP040GlobalRows.StrikeIntervalTics(systemId, rank);
        if (interval < 0) interval = 0;
        DSP040ClearChosen(dsp040StrikeId[index], dsp040StrikeFormGeneration[index]);
        for (int k = 0; k < strikeCount; k++)
        {
            dsp040ScheduleActive.Push(1);
            dsp040ScheduleWeaponSlot.Push(dsp040StrikeSlot[index]);
            dsp040ScheduleWeaponGeneration.Push(dsp040StrikeGeneration[index]);
            dsp040ScheduleWeaponId.Push(dsp040StrikeId[index]);
            dsp040ScheduleFormGeneration.Push(dsp040StrikeFormGeneration[index]);
            dsp040ScheduleSystem.Push(systemId);
            dsp040ScheduleRank.Push(rank);
            dsp040ScheduleMightMilli.Push(rsActive ? RsMightFor(systemId) : dsp040StrikeMightMilli[index]);
            dsp040ScheduleFireTic.Push(tic + k * interval);
        }
        int period = DSP040GlobalMath.GateTicsAfterMultiplier(
            DSP040GlobalRows.PeriodTics(systemId, rank),
            RsCooldownFor(systemId, rsActive ? rsCooldownMilli : dsp040StrikeCooldownMultiplierMilli[index]));
        dsp040StrikeNextActivationTic[index] = tic + period;
        DSSound.Weapon(systemId);
        { if (!dsQuiet) Console.Printf("DS_P040_ACTIVATION accepted=1 kind=STRIKE weapon_id=%d system_id=%d rank=%d tic=%d strike_count=%d row_amount=%d resolved_amount=%d interval_tics=%d next_activation_tic=%d", dsp040StrikeId[index], systemId, rank, tic, strikeCount, rowAmount, resolvedAmount, interval, dsp040StrikeNextActivationTic[index]); }
    }

    // Uniform choice among live, non-protected, unchosen-this-activation
    // enemies in the region, via the dedicated P040_STRIKE stream. Returns
    // false (with an explicit skip marker already emitted by the caller)
    // when none remain -- strikes never retarget off-screen.
    bool DSP040ChooseStrikeTarget(int weaponId, int formGeneration,
        double playerX, double playerY, out int targetSlot,
        out int targetGeneration, out int targetId)
    {
        targetSlot = -1; targetGeneration = 0; targetId = 0;
        DSP040GatherRegionEnemies(playerX, playerY);
        Array<int> eligibleIndex;
        for (int i = 0; i < dsp040CandidateIds.Size(); i++)
            if (!DSP040AlreadyChosen(weaponId, formGeneration, dsp040CandidateIds[i]))
                eligibleIndex.Push(i);
        if (eligibleIndex.Size() == 0) return false;
        dsp040StrikeRngState = DSP040GlobalMath.NextRngState(dsp040StrikeRngState);
        int pick = DSP040GlobalMath.PositiveModulo(dsp040StrikeRngState, eligibleIndex.Size());
        int chosen = eligibleIndex[pick];
        targetSlot = dsp040CandidateSlots[chosen];
        targetGeneration = dsp040CandidateGenerations[chosen];
        targetId = dsp040CandidateIds[chosen];
        dsp040ChosenWeaponId.Push(weaponId);
        dsp040ChosenFormGeneration.Push(formGeneration);
        dsp040ChosenTargetId.Push(targetId);
        return true;
    }

    // Circle AoE at (centerX, centerY): every live enemy whose collision
    // circle touches it takes one P025 checked hit (row damage x Might).
    // Returns the count of enemies actually hit, for evidence logging.
    int DSP040ApplyStrikeAoE(double centerX, double centerY,
        int radiusMilliUnits, int damageMilli, int mightMilli, int tic,
        int systemId, int rank, int weaponId)
    {
        int hitCount = 0;
        DSWeaponFx.Burst("WBLT", centerX, centerY, 24.0, 60.0, 60.0, false, Color(255, 240, 120), 6);
        double queryRadius = double(radiusMilliUnits) / 1000.0
            + DSP040_MAX_TARGET_RADIUS_BOUND_UNITS;
        DSP024RadiusCandidates(centerX, centerY, queryRadius);
        dsp040CandidateSlots.Clear(); dsp040CandidateGenerations.Clear();
        dsp040CandidateIds.Clear();
        for (int c = 0; c < spatialCandidateCount; c++)
        {
            dsp040CandidateSlots.Push(spatialCandidateSlots[c]);
            dsp040CandidateGenerations.Push(spatialCandidateGenerations[c]);
            dsp040CandidateIds.Push(spatialCandidateIds[c]);
        }
        DSP040SortCandidatesByStableId();
        for (int c = 0; c < dsp040CandidateSlots.Size(); c++)
        {
            int slot = dsp040CandidateSlots[c];
            int generation = dsp040CandidateGenerations[c];
            int stableId = dsp040CandidateIds[c];
            if (!ValidParts(slot, generation, stableId)
                || kinds[slot] != DSP040_KIND_ENEMY || health[slot] <= 0
                || collisionRadii[slot] < 0.0) continue;
            if (!DSP040GlobalMath.CircleContact(centerX, centerY, radiusMilliUnits,
                x[slot], y[slot], collisionRadii[slot])) continue;
            int scaledMilli;
            bool checked = DSP025CheckedDamage(damageMilli, 0, mightMilli, scaledMilli)
                && scaledMilli >= 0 && scaledMilli <= DSP040_MAX_SAFE_DAMAGE_MILLI;
            int before; int after; int killed;
            arHitSystem = systemId;   // which weapon hit (Arcana scope)
            if (!checked || !DSP025ApplyLogicalHit(slot, generation, stableId,
                scaledMilli, before, after, killed)) continue;
            int delta = before - after;
            if (delta >= 0 && dsp040AcceptedDamageMilli <= 2147483647 - delta)
                dsp040AcceptedDamageMilli += delta;
            int eventId = DSP040NewEventId();
            dsp040AcceptedHits++;
            hitCount++;
            dsp040LastEventId = eventId; dsp040LastEventKind = systemId;
            dsp040LastEventTargetId = stableId;
            { if (!dsQuiet) Console.Printf("DS_P040_STRIKE_HIT accepted=1 authority=P025_CHECKED_LOGICAL_HIT event_id=%d tic=%d system_id=%d rank=%d weapon_id=%d target_slot=%d target_generation=%d target_id=%d center=(%.3f,%.3f) radius_milli=%d damage_milli=%d might_milli=%d scaled_milli=%d before=%d after=%d killed=%d", eventId, tic, systemId, rank, weaponId, slot, generation, stableId, centerX, centerY, radiusMilliUnits, damageMilli, mightMilli, scaledMilli, before, after, killed); }
            if (killed != 0)
            {
                dsp040KilledByGlobal++;
                HandleEnemyDeath(slot, before, eventId);
            }
        }
        return hitCount;
    }

    // Fires every scheduled strike event due on this tic: chooses a target
    // (or emits the skip marker), strikes at the target's current position,
    // and schedules a Thunder Loop repeat when applicable.
    void DSP040FireScheduledStrikes(int tic, double playerX, double playerY)
    {
        for (int i = dsp040ScheduleActive.Size() - 1; i >= 0; i--)
        {
            if (dsp040ScheduleActive[i] == 0 || dsp040ScheduleFireTic[i] != tic) continue;
            int weaponId = dsp040ScheduleWeaponId[i];
            int formGeneration = dsp040ScheduleFormGeneration[i];
            int systemId = dsp040ScheduleSystem[i];
            int rank = dsp040ScheduleRank[i];
            int mightMilli = dsp040ScheduleMightMilli[i];
            int targetSlot; int targetGeneration; int targetId;
            bool found = DSP040ChooseStrikeTarget(weaponId, formGeneration,
                playerX, playerY, targetSlot, targetGeneration, targetId);
            if (!found)
            {
                dsp040SkippedStrikes++;
                Console.Printf("DS_P040_STRIKE_SKIP accepted=0 tic=%d weapon_id=%d system_id=%d rank=%d reason=NO_ELIGIBLE_TARGET_IN_REGION", tic, weaponId, systemId, rank);
                DSP040RemoveScheduleAt(i);
                continue;
            }
            double centerX = x[targetSlot];
            double centerY = y[targetSlot];
            int rowRadius = DSP040GlobalRows.StrikeRadiusMilliUnits(systemId, rank)
                * (rsActive ? RsAreaFor(systemId) : 1000) / 1000;
            int rowDamage = DSP040GlobalRows.DamageMilli(systemId, rank);
            DSP040ApplyStrikeAoE(centerX, centerY, rowRadius, rowDamage, mightMilli,
                tic, systemId, rank, weaponId);
            if (systemId == DSP040GlobalRows.SYSTEM_THUNDER_LOOP)
            {
                dsp040RepeatActive.Push(1); dsp040RepeatWeaponId.Push(weaponId);
                dsp040RepeatX.Push(centerX); dsp040RepeatY.Push(centerY);
                dsp040RepeatRadiusMilliUnits.Push(rowRadius);
                dsp040RepeatDamageMilli.Push(rowDamage);
                dsp040RepeatMightMilli.Push(mightMilli);
                dsp040RepeatFireTic.Push(tic + DSP040GlobalRows.THUNDER_REPEAT_DELAY_TICS);
                dsp040RepeatSystem.Push(systemId); dsp040RepeatRank.Push(rank);
                dsp040ThunderRepeatsScheduled++;
                { if (!dsQuiet) Console.Printf("DS_P040_REPEAT_SCHEDULED accepted=1 tic=%d weapon_id=%d fire_tic=%d location=(%.3f,%.3f)", tic, weaponId, tic + DSP040GlobalRows.THUNDER_REPEAT_DELAY_TICS, centerX, centerY); }
            }
            DSP040RemoveScheduleAt(i);
        }
    }

    void DSP040RemoveScheduleAt(int i)
    {
        int last = dsp040ScheduleActive.Size() - 1;
        dsp040ScheduleActive[i] = dsp040ScheduleActive[last];
        dsp040ScheduleWeaponSlot[i] = dsp040ScheduleWeaponSlot[last];
        dsp040ScheduleWeaponGeneration[i] = dsp040ScheduleWeaponGeneration[last];
        dsp040ScheduleWeaponId[i] = dsp040ScheduleWeaponId[last];
        dsp040ScheduleFormGeneration[i] = dsp040ScheduleFormGeneration[last];
        dsp040ScheduleSystem[i] = dsp040ScheduleSystem[last];
        dsp040ScheduleRank[i] = dsp040ScheduleRank[last];
        dsp040ScheduleMightMilli[i] = dsp040ScheduleMightMilli[last];
        dsp040ScheduleFireTic[i] = dsp040ScheduleFireTic[last];
        dsp040ScheduleActive.Pop(); dsp040ScheduleWeaponSlot.Pop();
        dsp040ScheduleWeaponGeneration.Pop(); dsp040ScheduleWeaponId.Pop();
        dsp040ScheduleFormGeneration.Pop(); dsp040ScheduleSystem.Pop();
        dsp040ScheduleRank.Pop(); dsp040ScheduleMightMilli.Pop();
        dsp040ScheduleFireTic.Pop();
    }

    void DSP040FireRepeats(int tic)
    {
        for (int i = dsp040RepeatActive.Size() - 1; i >= 0; i--)
        {
            if (dsp040RepeatActive[i] == 0 || dsp040RepeatFireTic[i] != tic) continue;
            DSP040ApplyStrikeAoE(dsp040RepeatX[i], dsp040RepeatY[i],
                dsp040RepeatRadiusMilliUnits[i], dsp040RepeatDamageMilli[i],
                dsp040RepeatMightMilli[i], tic, dsp040RepeatSystem[i],
                dsp040RepeatRank[i], dsp040RepeatWeaponId[i]);
            dsp040ThunderRepeatsFired++;
            { if (!dsQuiet) Console.Printf("DS_P040_REPEAT_FIRED accepted=1 tic=%d weapon_id=%d location=(%.3f,%.3f)", tic, dsp040RepeatWeaponId[i], dsp040RepeatX[i], dsp040RepeatY[i]); }
            int last = dsp040RepeatActive.Size() - 1;
            dsp040RepeatActive[i] = dsp040RepeatActive[last];
            dsp040RepeatWeaponId[i] = dsp040RepeatWeaponId[last];
            dsp040RepeatX[i] = dsp040RepeatX[last]; dsp040RepeatY[i] = dsp040RepeatY[last];
            dsp040RepeatRadiusMilliUnits[i] = dsp040RepeatRadiusMilliUnits[last];
            dsp040RepeatDamageMilli[i] = dsp040RepeatDamageMilli[last];
            dsp040RepeatMightMilli[i] = dsp040RepeatMightMilli[last];
            dsp040RepeatFireTic[i] = dsp040RepeatFireTic[last];
            dsp040RepeatSystem[i] = dsp040RepeatSystem[last];
            dsp040RepeatRank[i] = dsp040RepeatRank[last];
            dsp040RepeatActive.Pop(); dsp040RepeatWeaponId.Pop();
            dsp040RepeatX.Pop(); dsp040RepeatY.Pop();
            dsp040RepeatRadiusMilliUnits.Pop(); dsp040RepeatDamageMilli.Pop();
            dsp040RepeatMightMilli.Pop(); dsp040RepeatFireTic.Pop();
            dsp040RepeatSystem.Pop(); dsp040RepeatRank.Pop();
        }
    }

    // Drives every equipped Lightning Ring/Thunder Loop instance: starts a
    // new activation when due, then fires whatever is scheduled this tic.
    // resolvedDuplicatorAmount is the P033 STAT_AMOUNT resolution (0 when
    // Duplicator is unranked), applied only here per the contract's Amount
    // eligibility list.
    void DSP040ProcessStrikeTic(int tic, double playerX, double playerY,
        int resolvedDuplicatorAmount)
    {
        DSP040PurgeStaleStrikes();
        for (int i = 0; i < dsp040StrikeActive.Size(); i++)
        {
            if (dsp040StrikeActive[i] == 0) continue;
            if (tic >= dsp040StrikeNextActivationTic[i])
                DSP040BeginStrikeActivation(i, tic, resolvedDuplicatorAmount);
        }
        DSP040FireScheduledStrikes(tic, playerX, playerY);
        DSP040FireRepeats(tic);
    }

    // ---- Pentagram --------------------------------------------------------

    // Snapshot erasure: every non-protected live enemy in the region is
    // erased (distinct operation, no reward), then every pickup in the
    // region (any state, including already-attracting gems) is rolled with
    // the dedicated P040_ERASE stream and either spared or removed through
    // the P027 ERASED ledger reason.
    void DSP040FirePentagram(int index, int tic, double playerX, double playerY,
        int luckMilli)
    {
        int systemId = dsp040EraseSystem[index];
        int rank = dsp040EraseRank[index];
        DSP040GatherRegionEnemies(playerX, playerY);
        int erasedThisActivation = 0;
        DSWeaponFx.Burst("WRNG", playerX, playerY, 1.5, 40.0, 600.0, true, Color(255, 255, 255), 12);
        for (int i = 0; i < dsp040CandidateSlots.Size(); i++)
            if (DSP040EraseEnemy(dsp040CandidateSlots[i], dsp040CandidateGenerations[i],
                dsp040CandidateIds[i])) erasedThisActivation++;
        int spareMilli = DSP040GlobalRows.SpareMilli(systemId, rank);
        int sparedThisActivation = 0;
        int erasedPickupsThisActivation = 0;
        for (int slot = 0; slot < lifeStates.Size(); slot++)
        {
            if (!DSP027IsLivePickup(slot)) continue;
            if (!DSP040GlobalMath.InRegion(playerX, playerY, x[slot], y[slot],
                DSP040GlobalRows.REGION_HALF_EXTENT)) continue;
            int generation = generations[slot]; int stableId = ids[slot];
            dsp040EraseRngState = DSP040GlobalMath.NextRngState(dsp040EraseRngState);
            bool spared;
            DSP040GlobalMath.SpareRoll(dsp040EraseRngState, spareMilli, luckMilli, spared);
            if (spared)
            {
                dsp040SparedPickups++; sparedThisActivation++;
                { if (!dsQuiet) Console.Printf("DS_P040_ERASE_ROLL tic=%d slot=%d generation=%d stable_id=%d spare_milli=%d luck_milli=%d spared=1", tic, slot, generation, stableId, spareMilli, luckMilli); }
                continue;
            }
            if (DSP027ErasePickup(slot, generation, stableId))
            {
                dsp040ErasedPickups++; erasedPickupsThisActivation++;
                { if (!dsQuiet) Console.Printf("DS_P040_ERASE_ROLL tic=%d slot=%d generation=%d stable_id=%d spare_milli=%d luck_milli=%d spared=0 pickup_removed=1", tic, slot, generation, stableId, spareMilli, luckMilli); }
            }
        }
        { if (!dsQuiet) Console.Printf("DS_P040_PENTAGRAM_FIRE accepted=1 tic=%d system_id=%d rank=%d weapon_id=%d erased_enemies=%d spare_milli=%d luck_milli=%d spared_pickups=%d erased_pickups=%d", tic, systemId, rank, dsp040EraseId[index], erasedThisActivation, spareMilli, luckMilli, sparedThisActivation, erasedPickupsThisActivation); }
    }

    // ---- Gorgeous Moon ------------------------------------------------------

    void DSP040FireMoonPhase1(int index, int tic, double playerX, double playerY)
    {
        DSP040GatherRegionEnemies(playerX, playerY);
        // dsp040Candidate* is already sorted stable-ID ascending; distance is
        // the primary key per the contract ("closest ... then stable ID"),
        // so a simple selection sort over distance with that ordering as the
        // tie-break reproduces the required order deterministically.
        int beamCount = DSP040GlobalRows.MOON_BEAM_COUNT;
        int hits = 0;
        for (int beam = 0; beam < beamCount; beam++)
        {
            int bestIndex = -1; double bestDistance = 0.0;
            for (int i = 0; i < dsp040CandidateSlots.Size(); i++)
            {
                int slot = dsp040CandidateSlots[i];
                if (!ValidParts(slot, dsp040CandidateGenerations[i], dsp040CandidateIds[i])
                    || health[slot] <= 0) continue;
                double dx = x[slot] - playerX; double dy = y[slot] - playerY;
                double distance = dx * dx + dy * dy;
                if (bestIndex < 0 || distance < bestDistance)
                { bestIndex = i; bestDistance = distance; }
            }
            if (bestIndex < 0) break;
            int slot = dsp040CandidateSlots[bestIndex];
            int generation = dsp040CandidateGenerations[bestIndex];
            int stableId = dsp040CandidateIds[bestIndex];
            int currentHealth = health[slot];
            int before; int after; int killed;
            arHitSystem = dsp040EraseSystem[index];   // which weapon hit (Arcana scope)
            if (DSP025ApplyLogicalHit(slot, generation, stableId, currentHealth,
                before, after, killed) && killed != 0)
            {
                DSWeaponFx.Burst("WBLT", x[slot], y[slot], 24.0, 60.0, 60.0, false, Color(200, 220, 255), 6);
                int eventId = DSP040NewEventId();
                dsp040MoonBeamHits++; dsp040KilledByGlobal++;
                { if (!dsQuiet) Console.Printf("DS_P040_MOON_BEAM accepted=1 authority=P025_CHECKED_LOGICAL_HIT event_id=%d tic=%d beam=%d weapon_id=%d target_slot=%d target_generation=%d target_id=%d before=%d after=%d killed=1", eventId, tic, beam, dsp040EraseId[index], slot, generation, stableId, before, after); }
                HandleEnemyDeath(slot, before, eventId);
                hits++;
            }
            // Whether killed or not, this candidate is consumed for the
            // 6-closest selection so later beams do not re-target it.
            int lastCandidate = dsp040CandidateSlots.Size() - 1;
            dsp040CandidateSlots[bestIndex] = dsp040CandidateSlots[lastCandidate];
            dsp040CandidateGenerations[bestIndex] = dsp040CandidateGenerations[lastCandidate];
            dsp040CandidateIds[bestIndex] = dsp040CandidateIds[lastCandidate];
            dsp040CandidateSlots.Pop(); dsp040CandidateGenerations.Pop();
            dsp040CandidateIds.Pop();
        }
        { if (!dsQuiet) Console.Printf("DS_P040_MOON_PHASE1 accepted=1 tic=%d weapon_id=%d beams_requested=%d beams_hit=%d", tic, dsp040EraseId[index], beamCount, hits); }
    }

    void DSP040FireMoonPhase2(int weaponId, int amountBonus, int tic,
        double playerX, double playerY)
    {
        DSP040GatherRegionEnemies(playerX, playerY);
        int erased = 0;
        int gemValue = DSP040GlobalRows.MOON_GEM_BASE_XP_MILLI
            * (1 + (amountBonus < 0 ? 0 : amountBonus));
        for (int i = 0; i < dsp040CandidateSlots.Size(); i++)
        {
            int slot = dsp040CandidateSlots[i];
            int generation = dsp040CandidateGenerations[i];
            int stableId = dsp040CandidateIds[i];
            double gx = x[slot]; double gy = y[slot];
            if (!DSP040EraseEnemy(slot, generation, stableId)) continue;
            erased++;
            DSP027ExperienceHandle handle;
            if (DSP027CreatePickup(gemValue, gx, gy, weaponId, handle))
                dsp040MoonGemsCreated++;
        }
        int attracted = 0;
        for (int slot = 0; slot < lifeStates.Size(); slot++)
        {
            if (!DSP027IsLivePickup(slot)) continue;
            // Normal play: Gorgeous Moon gathers every gem on the map, like a
            // Vacuum (the far ones fly in through MFPullVacuumedGems).
            if (!rsActive && !DSP040GlobalMath.InRegion(playerX, playerY, x[slot], y[slot],
                DSP040GlobalRows.REGION_HALF_EXTENT)) continue;
            if (DSP027ForceAttract(slot, generations[slot], ids[slot])) attracted++;
        }
        if (rsActive && attracted > 0 && DSP030VerticalSlice(self) != null)
            DSP030VerticalSlice(self).mfVacuumActive = true;
        { if (!dsQuiet) Console.Printf("DS_P040_MOON_PHASE2 accepted=1 tic=%d weapon_id=%d erased_enemies=%d gem_value_milli=%d gems_created=%d attracted_pickups=%d", tic, weaponId, erased, gemValue, dsp040MoonGemsCreated, attracted); }
    }

    // Drives every equipped Pentagram/Gorgeous Moon instance: fires the
    // activation (Pentagram erasure, or Moon phase 1) when due, and any
    // pending Moon phase-2 records due this tic.
    void DSP040ProcessEraseTic(int tic, double playerX, double playerY,
        int luckMilli, int resolvedAmount)
    {
        DSP040PurgeStaleErase();
        for (int i = 0; i < dsp040EraseActive.Size(); i++)
        {
            if (dsp040EraseActive[i] == 0) continue;
            if (tic < dsp040EraseNextActivationTic[i]) continue;
            int systemId = dsp040EraseSystem[i];
            int rank = dsp040EraseRank[i];
            int basePeriod = DSP040GlobalRows.PeriodTics(systemId, rank);
            int period = DSP040GlobalMath.GateTicsAfterMultiplier(basePeriod,
                dsp040EraseCooldownMultiplierMilli[i]);
            if (systemId == DSP040GlobalRows.SYSTEM_GORGEOUS_MOON
                && period < DSP040GlobalRows.MOON_PERIOD_FLOOR_TICS)
                period = DSP040GlobalRows.MOON_PERIOD_FLOOR_TICS;
            dsp040EraseNextActivationTic[i] = tic + period;
            DSSound.Weapon(systemId);
            if (systemId == DSP040GlobalRows.SYSTEM_PENTAGRAM)
                DSP040FirePentagram(i, tic, playerX, playerY, luckMilli);
            else if (systemId == DSP040GlobalRows.SYSTEM_GORGEOUS_MOON)
            {
                DSP040FireMoonPhase1(i, tic, playerX, playerY);
                dsp040MoonPendingActive.Push(1);
                dsp040MoonPendingWeaponId.Push(dsp040EraseId[i]);
                dsp040MoonPendingFormGeneration.Push(dsp040EraseFormGeneration[i]);
                dsp040MoonPendingFireTic.Push(tic + DSP040GlobalRows.MOON_PHASE2_DELAY_TICS);
                dsp040MoonPendingAmountBonus.Push(resolvedAmount);
            }
        }
        for (int i = dsp040MoonPendingActive.Size() - 1; i >= 0; i--)
        {
            if (dsp040MoonPendingActive[i] == 0 || dsp040MoonPendingFireTic[i] != tic) continue;
            DSP040FireMoonPhase2(dsp040MoonPendingWeaponId[i],
                dsp040MoonPendingAmountBonus[i], tic, playerX, playerY);
            int last = dsp040MoonPendingActive.Size() - 1;
            dsp040MoonPendingActive[i] = dsp040MoonPendingActive[last];
            dsp040MoonPendingWeaponId[i] = dsp040MoonPendingWeaponId[last];
            dsp040MoonPendingFormGeneration[i] = dsp040MoonPendingFormGeneration[last];
            dsp040MoonPendingFireTic[i] = dsp040MoonPendingFireTic[last];
            dsp040MoonPendingAmountBonus[i] = dsp040MoonPendingAmountBonus[last];
            dsp040MoonPendingActive.Pop(); dsp040MoonPendingWeaponId.Pop();
            dsp040MoonPendingFormGeneration.Pop(); dsp040MoonPendingFireTic.Pop();
            dsp040MoonPendingAmountBonus.Pop();
        }
    }

    // ---- Rebase (world-origin shift) --------------------------------------

    void DSP040RebaseGlobal(double deltaX, double deltaY)
    {
        for (int i = 0; i < dsp040RepeatActive.Size(); i++)
        {
            if (dsp040RepeatActive[i] == 0) continue;
            dsp040RepeatX[i] += deltaX; dsp040RepeatY[i] += deltaY;
        }
    }

    // ---- State hash (P029 save/load exact-equality gate) ------------------

    int DSP040HashMix(int hash, int value)
    {
        int normalized = value % 1000003;
        if (normalized < 0) normalized += 1000003;
        return (hash * 31 + normalized) % 1000003;
    }

    int DSP040HashMixDoubleMilli(int hash, double value)
    {
        int quantized;
        if (value >= 2000000.0) quantized = 2000000000;
        else if (value <= -2000000.0) quantized = -2000000000;
        else quantized = int(value * 1000.0);
        return DSP040HashMix(hash, quantized);
    }

    int DSP040HashArrayInt(int hash, Array<int> values)
    {
        for (int i = 0; i < values.Size(); i++) hash = DSP040HashMix(hash, values[i]);
        return hash;
    }

    int DSP040GlobalStateHash()
    {
        int hash = 40;
        hash = DSP040HashMix(hash, dsp040AcceptedHits);
        hash = DSP040HashMix(hash, dsp040AcceptedDamageMilli);
        hash = DSP040HashMix(hash, dsp040SkippedStrikes);
        hash = DSP040HashMix(hash, dsp040ThunderRepeatsScheduled);
        hash = DSP040HashMix(hash, dsp040ThunderRepeatsFired);
        hash = DSP040HashMix(hash, dsp040ErasedEnemies);
        hash = DSP040HashMix(hash, dsp040KilledByGlobal);
        hash = DSP040HashMix(hash, dsp040SparedPickups);
        hash = DSP040HashMix(hash, dsp040ErasedPickups);
        hash = DSP040HashMix(hash, dsp040MoonBeamHits);
        hash = DSP040HashMix(hash, dsp040MoonGemsCreated);
        hash = DSP040HashMix(hash, dsp040NextEventId);
        hash = DSP040HashMix(hash, dsp040StrikeRngState);
        hash = DSP040HashMix(hash, dsp040EraseRngState);
        hash = DSP040HashArrayInt(hash, dsp040StrikeActive);
        hash = DSP040HashArrayInt(hash, dsp040StrikeSystem);
        hash = DSP040HashArrayInt(hash, dsp040StrikeRank);
        hash = DSP040HashArrayInt(hash, dsp040StrikeFormGeneration);
        hash = DSP040HashArrayInt(hash, dsp040StrikeNextActivationTic);
        hash = DSP040HashArrayInt(hash, dsp040ChosenWeaponId);
        hash = DSP040HashArrayInt(hash, dsp040ChosenFormGeneration);
        hash = DSP040HashArrayInt(hash, dsp040ChosenTargetId);
        hash = DSP040HashArrayInt(hash, dsp040ScheduleWeaponId);
        hash = DSP040HashArrayInt(hash, dsp040ScheduleFireTic);
        for (int i = 0; i < dsp040RepeatActive.Size(); i++)
        {
            hash = DSP040HashMix(hash, dsp040RepeatWeaponId[i]);
            hash = DSP040HashMixDoubleMilli(hash, dsp040RepeatX[i]);
            hash = DSP040HashMixDoubleMilli(hash, dsp040RepeatY[i]);
            hash = DSP040HashMix(hash, dsp040RepeatFireTic[i]);
        }
        hash = DSP040HashArrayInt(hash, dsp040EraseActive);
        hash = DSP040HashArrayInt(hash, dsp040EraseSystem);
        hash = DSP040HashArrayInt(hash, dsp040EraseRank);
        hash = DSP040HashArrayInt(hash, dsp040EraseFormGeneration);
        hash = DSP040HashArrayInt(hash, dsp040EraseNextActivationTic);
        hash = DSP040HashArrayInt(hash, dsp040MoonPendingWeaponId);
        hash = DSP040HashArrayInt(hash, dsp040MoonPendingFireTic);
        hash = DSP040HashArrayInt(hash, dsp040MoonPendingAmountBonus);
        hash = DSP040HashArrayInt(hash, dsp040ProtectedSlot);
        hash = DSP040HashArrayInt(hash, dsp040ProtectedGeneration);
        hash = DSP040HashArrayInt(hash, dsp040ProtectedId);
        return hash;
    }
}
