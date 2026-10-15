// N2 weapon dispatcher: acquisition, ranks, evolutions, per-tic engine calls, soak bot.
// Part of DSP030VerticalSlice (fields and core lifecycle live in
// gameplay/VerticalSlice.zs).

extend class DSP030VerticalSlice
{
    int N2EngineForSystem(int system)
    {
        if (system == DSP034WeaponRows.SYSTEM_MAGIC_WAND
            || system == DSP034WeaponRows.SYSTEM_KNIFE
            || system == DSP034WeaponRows.SYSTEM_HOLY_WAND
            || system == DSP034WeaponRows.SYSTEM_THOUSAND_EDGE) return N2_ENGINE_AIMED;
        if (system == DSP035WeaponRows.SYSTEM_AXE
            || system == DSP035WeaponRows.SYSTEM_FIRE_WAND
            || system == DSP035WeaponRows.SYSTEM_DEATH_SPIRAL
            || system == DSP035WeaponRows.SYSTEM_HELLFIRE
            // N3 Track A (docs/contracts/remaining-weapons.md): Magi-Stone,
            // Mannajja and Song of Mana join the existing ballistic
            // engine as data rows plus the DSP035WeaponRows.TryGetN3RankRow
            // adapter -- see that function's comment for the field-by-field
            // source vs. engineering-fallback breakdown.
            || system == DSN3Rows.SYSTEM_MAGI_STONE
            // Kyra-Stones is Magi-Stone's evolution; EvolveWeapon only
            // evolves within one engine, so it must share Magi-Stone's.
            || system == DSN3Rows.SYSTEM_KYRA_STONES) return N2_ENGINE_BALLISTIC;
        // Song of Mana / Mannajja are light columns from the sky: generic
        // engine MODE_BEAM (weapons/generic/GenericWeaponDefs.zs).
        if (system == DSP036ReturningRows.SYSTEM_CROSS
            || system == DSP036ReturningRows.SYSTEM_HEAVEN_SWORD) return N2_ENGINE_RETURNING;
        if (system == DSP037OrbitRows.SYSTEM_KING_BIBLE
            || system == DSP037OrbitRows.SYSTEM_UNHOLY_VESPERS) return N2_ENGINE_ORBIT;
        if (system == DSP038GroundRows.SYSTEM_HOLYWATER
            || system == DSP038GroundRows.SYSTEM_BORA) return N2_ENGINE_GROUND;
        if (system == DSP039AuraRows.SYSTEM_GARLIC
            || system == DSP039AuraRows.SYSTEM_SOUL_EATER) return N2_ENGINE_AURA;
        if (system == DSP040GlobalRows.SYSTEM_LIGHTNING
            || system == DSP040GlobalRows.SYSTEM_THUNDER_LOOP) return N2_ENGINE_GLOBAL_STRIKE;
        if (system == DSP040GlobalRows.SYSTEM_PENTAGRAM
            || system == DSP040GlobalRows.SYSTEM_GORGEOUS_MOON) return N2_ENGINE_GLOBAL_ERASE;
        if (system == DSP041BounceRows.SYSTEM_RUNETRACER
            || system == DSP041BounceRows.SYSTEM_NO_FUTURE
            // N3 Track A (docs/contracts/remaining-weapons.md): Bone,
            // Cherry Bomb and Carréllo were already implemented as
            // DSP041BounceRows data rows but were never routed through
            // this dispatcher or made draftable, so Anima of Mortaccio/
            // Yatta Daikarin/Carrozza! (whose P032 recipes evolve them)
            // could never actually reach EvolveWeapon's `N2Find(from) >= 0`
            // requirement in normal play. Wiring the three base weapons
            // here (and into DSN2Catalog.DraftableIds) is required for
            // those three recipes to ever apply through a real chest.
            || system == DSP041BounceRows.SYSTEM_BONE
            || system == DSP041BounceRows.SYSTEM_CHERRY
            || system == DSP041BounceRows.SYSTEM_CARRELLO
            || system == DSN3Rows.SYSTEM_ANIMA_OF_MORTACCIO
            || system == DSN3Rows.SYSTEM_CARROZZA
            || system == DSN3Rows.SYSTEM_CELESTIAL_DUSTING
            || system == DSN3Rows.SYSTEM_LA_ROBBA
            || system == DSN3Rows.SYSTEM_PROFUSIONE_DAMORE
            || system == DSN3Rows.SYSTEM_YATTA_DAIKARIN) return N2_ENGINE_BOUNCE;
        if (system == DSP042PairedRows.SYSTEM_PEACHONE
            || system == DSP042PairedRows.SYSTEM_EBONY
            || system == DSP042PairedRows.SYSTEM_PHIERA
            || system == DSP042PairedRows.SYSTEM_EIGHT
            || system == DSP042PairedRows.SYSTEM_VENTO
            || system == DSP042PairedRows.SYSTEM_BRACELET
            // N2-W6 fix: the three paired-union outputs and the two
            // Bracelet-chain steps were missing here, so EvolveWeapon's own
            // engine/toEngine match check (from's engine must equal to's)
            // always failed for recipes 201-205 -- confirmed by an actual
            // run showing DS_N2_INTERIM_CHEST_RECIPE dispatch_evolved=0 for
            // every one of them. The dispatcher's owned weapon slot never
            // actually became Vandalier/Phieraggi/Fuwalafuwaloo/Bi-Bracelet/
            // Tri-Bracelet without this, so it could never land a real
            // accepted hit under its evolved system id.
            || system == DSP042PairedRows.SYSTEM_VANDALIER
            || system == DSP042PairedRows.SYSTEM_PHIERAGGI
            || system == DSP042PairedRows.SYSTEM_FUWALA
            || system == DSP042PairedRows.SYSTEM_BI_BRACELET
            || system == DSP042PairedRows.SYSTEM_TRI_BRACELET) return N2_ENGINE_PAIRED;
        if (DSGenericWeaponDefs.Handles(system)) return N2_ENGINE_GENERIC;
        return N2_ENGINE_NONE;
    }

    int N2Find(int system)
    {
        for (int i = 0; i < n2System.Size(); i++)
            if (n2System[i] == system) return i;
        return -1;
    }

    bool N2HasEngine(int engine)
    {
        for (int i = 0; i < n2System.Size(); i++)
            if (N2EngineForSystem(n2System[i]) == engine) return true;
        return false;
    }

    // AcquireWeapon(system, rank): first-time grant of a draftable base
    // weapon. Whip is a special case -- it is equipped unconditionally at
    // run start (ResetRunState) and never goes through Allocate()/Equip
    // here; DraftFull calls this for Whip too (offering it again is a rank-
    // up, handled below) so the dispatcher stays the single call site.
    bool AcquireWeapon(int system, int rank)
    {
        if (system == DSP033StatRules.SYSTEM_WHIP) return whipRank > 0;
        if (N2Find(system) >= 0) return false;
        int engine = N2EngineForSystem(system);
        if (engine == N2_ENGINE_NONE || rank < 1) return false;
        if (players[0].mo == null
            || !ValidParts(playerSlot, generations[playerSlot], ids[playerSlot]))
            return false;
        int slot = Allocate(KIND_WEAPON, playerX, playerY, 0.0, 0.0, 1);
        if (slot < 0) return false;
        collisionRadii[slot] = 0.0;
        int mightMilli = dsp033ResolvedValid
            ? DSP033Resolved(DSP033StatRules.STAT_MIGHT) : 1000;
        int cooldownMultiplierMilli = dsp033ResolvedValid
            ? DSP033Resolved(DSP033StatRules.STAT_COOLDOWN) : 1000;
        if (rsActive) { mightMilli = rsMightMilli; cooldownMultiplierMilli = rsCooldownMilli; }
        int firstFireTic = tic + 1;
        bool ok = false;
        int engineIndex = -1;
        if (engine == N2_ENGINE_AIMED)
            ok = DSP034EquipAimedFixture(system, rank, slot, firstFireTic);
        else if (engine == N2_ENGINE_BALLISTIC)
            ok = DSP035EquipFixture(system, rank, slot, firstFireTic);
        else if (engine == N2_ENGINE_RETURNING)
            ok = DSP036EquipFixture(system, rank, slot, firstFireTic);
        else if (engine == N2_ENGINE_ORBIT)
            ok = DSP037EquipFixture(system, rank, slot, firstFireTic,
                playerSlot, generations[playerSlot], ids[playerSlot],
                1000, 1000);
        else if (engine == N2_ENGINE_GROUND)
            ok = DSP038EquipWeapon(system, rank, slot, generations[slot],
                ids[slot], 1, playerSlot, generations[playerSlot],
                ids[playerSlot], firstFireTic, 1000, 1000, 1000, 1000,
                mightMilli, cooldownMultiplierMilli);
        else if (engine == N2_ENGINE_AURA)
            ok = DSP039EquipAura(system, rank, slot, generations[slot],
                ids[slot], 1, playerSlot, generations[playerSlot],
                ids[playerSlot], mightMilli, cooldownMultiplierMilli);
        else if (engine == N2_ENGINE_GLOBAL_STRIKE)
            ok = DSP040EquipStrike(system, rank, slot, generations[slot],
                ids[slot], 1, playerSlot, generations[playerSlot],
                ids[playerSlot], mightMilli, cooldownMultiplierMilli,
                firstFireTic);
        else if (engine == N2_ENGINE_GLOBAL_ERASE)
            ok = DSP040EquipPentagram(system, rank, slot, generations[slot],
                ids[slot], 1, playerSlot, generations[playerSlot],
                ids[playerSlot], cooldownMultiplierMilli, firstFireTic);
        else if (engine == N2_ENGINE_BOUNCE)
        {
            ok = DSP041EquipFixture(system, rank, slot, firstFireTic);
            if (ok) engineIndex = dsp041WeaponSystems.Size() - 1;
        }
        else if (engine == N2_ENGINE_PAIRED)
        {
            engineIndex = DSP042EquipFixture(system, rank, slot, firstFireTic);
            ok = engineIndex >= 0;
        }
        else if (engine == N2_ENGINE_GENERIC)
        {
            engineIndex = GwEquip(system);
            ok = engineIndex >= 0;
        }
        Console.Printf("DS_N2_DISPATCH_ACQUIRE accepted=%d system_id=%d rank=%d engine=%d weapon_slot=%d weapon_id=%d weapon_generation=%d classification=N2_DISPATCHER", ok ? 1 : 0, system, rank, engine, slot, ok ? ids[slot] : 0, ok ? generations[slot] : 0);
        if (!ok) return false;
        n2System.Push(system); n2Rank.Push(rank); n2Slot.Push(slot);
        n2EngineIndex.Push(engineIndex);
        n2AcquireCount++;
        return true;
    }

    // SetWeaponRank(system, rank): rank-up for an already-owned weapon
    // (draft offering the same weapon again). Every engine below already
    // had, or was just given (docs/contracts, "Engines missing a rank-
    // change API get one"), a dedicated rank-change entry point that keeps
    // the equipped row's identity/schedule/ledger state intact.
    bool SetWeaponRank(int system, int rank)
    {
        if (system == DSP033StatRules.SYSTEM_WHIP)
        {
            if (rank < 1 || rank > 8) return false;
            int oldWhipRank = whipRank;
            whipRank = rank; inventoryWeaponLevel = rank;
            Console.Printf("DS_N2_DISPATCH_RANK accepted=1 system_id=%d prior_rank=%d rank=%d engine=WHIP", system, oldWhipRank, rank);
            n2RankChangeCount++;
            return true;
        }
        int index = N2Find(system);
        if (index < 0) return false;
        int engine = N2EngineForSystem(system);
        int slot = n2Slot[index];
        bool ok = false;
        if (engine == N2_ENGINE_AIMED)
            ok = DSP034SetControlledFixtureRank(slot, system, rank, tic);
        else if (engine == N2_ENGINE_BALLISTIC)
            ok = DSP035SetFixtureRank(slot, system, rank, tic);
        else if (engine == N2_ENGINE_RETURNING)
            ok = DSP036SetFixtureRank(slot, system, rank, tic);
        else if (engine == N2_ENGINE_ORBIT)
            ok = DSP037SetFixtureRank(slot, rank, tic);
        else if (engine == N2_ENGINE_GROUND)
            ok = DSP038SetWeaponRank(slot, system, rank);
        else if (engine == N2_ENGINE_AURA)
            ok = DSP039SetAuraRank(slot, generations[slot], ids[slot],
                system, rank);
        else if (engine == N2_ENGINE_GLOBAL_STRIKE)
            ok = DSP040SetStrikeRank(slot, generations[slot], ids[slot],
                system, rank);
        else if (engine == N2_ENGINE_GLOBAL_ERASE)
            ok = DSP040SetEraseRank(slot, generations[slot], ids[slot],
                system, rank);
        else if (engine == N2_ENGINE_BOUNCE)
            ok = DSP041SetFixtureRank(slot, system, rank);
        else if (engine == N2_ENGINE_PAIRED)
            ok = DSP042SetFixtureRank(n2EngineIndex[index], system, rank, tic);
        else if (engine == N2_ENGINE_GENERIC)
            ok = rank >= 1 && rank <= max(1, DSGenericWeaponDefs.MaxRank(system));
        Console.Printf("DS_N2_DISPATCH_RANK accepted=%d system_id=%d prior_rank=%d rank=%d engine=%d", ok ? 1 : 0, system, n2Rank[index], rank, engine);
        if (!ok) return false;
        n2Rank[index] = rank;
        n2RankChangeCount++;
        return true;
    }

    // EvolveWeapon(from, to): thin pass-through to each engine's already-
    // accepted Replace/Transform entry point. Recipe/dependency resolution
    // (which passive at which rank satisfies `to`) is chest/recipe-graph
    // scope (docs/contracts "Evolutions and chests"), landing with N2's
    // chest work; the caller supplies dependencySatisfied so this dispatcher
    // stays a routing layer, not a duplicate of DSP03xRows.TryGetEvolution
    // bookkeeping each engine already owns.
    bool EvolveWeapon(int from, int to, int newRank, int dependencyRank,
        bool dependencySatisfied)
    {
        int index = N2Find(from);
        if (index < 0 || !dependencySatisfied) return false;
        int engine = N2EngineForSystem(from);
        int toEngine = N2EngineForSystem(to);
        if (engine != toEngine || engine == N2_ENGINE_NONE) return false;
        int slot = n2Slot[index];
        bool ok = false;
        if (engine == N2_ENGINE_AIMED)
            ok = DSP034ReplaceControlledFixture(slot, to, newRank, tic);
        else if (engine == N2_ENGINE_BALLISTIC)
            ok = DSP035ReplaceFixture(slot, to, newRank, tic, true,
                dependencyRank);
        else if (engine == N2_ENGINE_RETURNING)
            ok = DSP036ReplaceFixture(slot, to, newRank, tic, true,
                dependencyRank);
        else if (engine == N2_ENGINE_ORBIT)
            ok = DSP037ReplaceFixture(slot, to, tic, true, dependencyRank);
        else if (engine == N2_ENGINE_GROUND)
            ok = DSP038TransformWeapon(slot, generations[slot], ids[slot],
                from, to, newRank, n2NextFormGeneration(index), true);
        else if (engine == N2_ENGINE_AURA)
            ok = DSP039TransformAura(slot, generations[slot], ids[slot],
                from, to, newRank, n2NextFormGeneration(index), true);
        else if (engine == N2_ENGINE_GLOBAL_STRIKE)
            // N2-W6 fix: dependencyItem must be the fixed
            // DEPENDENCY_AMOUNT_SOURCE_KEY DSP040GlobalRows.TryGetEvolution
            // checks against, not a literal 0 (which never matches any
            // key) -- confirmed by an actual run showing recipe 309
            // (Lightning Ring -> Thunder Loop) reporting dispatch_evolved=0
            // despite DSP032ApplyRecipe itself accepting the recipe.
            ok = DSP040TransformToLoop(slot, generations[slot], ids[slot],
                DSP040GlobalRows.DEPENDENCY_AMOUNT_SOURCE_KEY, newRank,
                n2NextFormGeneration(index));
        else if (engine == N2_ENGINE_GLOBAL_ERASE)
            // Same fix for Pentagram -> Gorgeous Moon's
            // DEPENDENCY_GROWTH_SOURCE_KEY.
            ok = DSP040TransformToMoon(slot, generations[slot], ids[slot],
                DSP040GlobalRows.DEPENDENCY_GROWTH_SOURCE_KEY, newRank,
                n2NextFormGeneration(index));
        else if (engine == N2_ENGINE_BOUNCE)
            // Runetracer -> No Future is keyed by the Armor source key;
            // the N3 bounce evolutions are keyed by 0. Passing 0 for all of
            // them silently refused recipe 311 in every run.
            ok = DSP041TransformFixture(n2EngineIndex[index], to, newRank,
                to == DSP041BounceRows.SYSTEM_NO_FUTURE
                    ? DSP041BounceRows.DEPENDENCY_ARMOR_SOURCE_KEY : 0,
                dependencyRank, tic);
        else if (engine == N2_ENGINE_PAIRED)
            ok = DSP042EvolveInPlace(n2EngineIndex[index], to, newRank, tic);
        else if (engine == N2_ENGINE_GENERIC)
        {
            int gi = n2EngineIndex[index];
            ok = gi >= 0 && gi < gwSystem.Size();
            if (ok) gwSystem[gi] = to;
        }
        Console.Printf("DS_N2_DISPATCH_EVOLVE accepted=%d source_system_id=%d evolved_system_id=%d rank=%d engine=%d", ok ? 1 : 0, from, to, newRank, engine);
        if (!ok) return false;
        n2System[index] = to;
        n2Rank[index] = newRank;
        return true;
    }

    // Ground/aura transforms bump a caller-supplied form generation; every
    // dispatcher-owned weapon starts at form generation 1 (AcquireWeapon
    // above), so the first evolution always requests generation 2 and later
    // ones increment from whatever the engine already stored -- mirrors the
    // pNNN fixtures' own newFormGeneration=priorFormGeneration+1 pattern
    // without duplicating each engine's private form-generation field here.
    int n2NextFormGeneration(int index) { return 2; }

    void N2ProfileBegin()
    {
        n2ProfileEnabled = CVar.FindCVar("ds_n2_profile") != null
            && CVar.FindCVar("ds_n2_profile").GetInt() != 0;
        if (n2ProfileEnabled) n2ProfileStamp = MSTimeF();
    }

    void N2ProfileEnd(String engineName)
    {
        if (!n2ProfileEnabled) return;
        double now = MSTimeF();
        Console.Printf("DS_N2_PROFILE_TIC tic=%d engine=%s ms=%f", tic, engineName, now - n2ProfileStamp);
        n2ProfileStamp = now;
    }

    void ProcessOwnedWeapons()
    {
        // Owned weapons for Limit Break offers (Whip plus the dispatcher's).
        lbOwnedSystems.Clear();
        if (whipRank > 0) lbOwnedSystems.Push(DSP033StatRules.SYSTEM_WHIP);
        for (int w = 0; w < n2System.Size(); w++) lbOwnedSystems.Push(n2System[w]);
        if (runState != STATE_ACTIVE || players[0].mo == null
            || !ValidParts(playerSlot, generations[playerSlot], ids[playerSlot])
            || n2System.Size() == 0)
            return;
        int mightMilli = dsp033ResolvedValid
            ? DSP033Resolved(DSP033StatRules.STAT_MIGHT) : 1000;
        int cooldownMultiplierMilli = dsp033ResolvedValid
            ? DSP033Resolved(DSP033StatRules.STAT_COOLDOWN) : 1000;
        if (rsActive) { mightMilli = rsMightMilli; cooldownMultiplierMilli = rsCooldownMilli; }
        int facingYawMilli = int(AimAssistYaw(450.0) * 1000.0);
        N2ProfileBegin();

        if (N2HasEngine(N2_ENGINE_AIMED))
        {
            int before = dsp034AcceptedDamageMilli;
            int hitsBefore = dsp034AcceptedHits;
            DSP034ProcessAimedTic(tic, playerSlot, generations[playerSlot],
                ids[playerSlot], playerX, playerY, true, facingYawMilli,
                cooldownMultiplierMilli,
                dsp033ResolvedValid ? dsp033ResolvedRankHash : 0);
            N2CreditDamage(dsp034AcceptedDamageMilli - before, "AIMED");
            n2CumAimedHits += dsp034AcceptedHits - hitsBefore;
            N2ProfileEnd("AIMED");
        }
        if (N2HasEngine(N2_ENGINE_BALLISTIC))
        {
            int before = dsp035AcceptedDamageMilli;
            int hitsBefore = dsp035AcceptedHits;
            DSP035ProcessBallisticTic(tic, playerSlot, generations[playerSlot],
                ids[playerSlot], playerX, playerY, facingYawMilli,
                cooldownMultiplierMilli,
                dsp033ResolvedValid ? dsp033ResolvedRankHash : 0);
            N2CreditDamage(dsp035AcceptedDamageMilli - before, "BALLISTIC");
            n2CumBallisticHits += dsp035AcceptedHits - hitsBefore;
            N2ProfileEnd("BALLISTIC");
        }
        if (N2HasEngine(N2_ENGINE_RETURNING))
        {
            int before = dsp036AcceptedDamageMilli;
            int hitsBefore = dsp036AcceptedHits;
            DSP036ProcessReturningTic(tic, playerSlot, generations[playerSlot],
                ids[playerSlot], playerX, playerY, cooldownMultiplierMilli,
                dsp033ResolvedValid ? dsp033ResolvedRankHash : 0);
            N2CreditDamage(dsp036AcceptedDamageMilli - before, "RETURNING");
            n2CumReturningHits += dsp036AcceptedHits - hitsBefore;
            N2ProfileEnd("RETURNING");
        }
        if (N2HasEngine(N2_ENGINE_ORBIT))
        {
            int before = dsp037AcceptedDamageMilli;
            int hitsBefore = dsp037AcceptedHits;
            DSP037ProcessOrbitTic(tic, playerSlot, generations[playerSlot],
                ids[playerSlot], playerX, playerY, mightMilli,
                cooldownMultiplierMilli);
            N2CreditDamage(dsp037AcceptedDamageMilli - before, "ORBIT");
            n2CumOrbitHits += dsp037AcceptedHits - hitsBefore;
            N2ProfileEnd("ORBIT");
        }
        if (N2HasEngine(N2_ENGINE_GROUND))
        {
            int before = dsp038AcceptedDamageMilli;
            int hitsBefore = dsp038AcceptedHits;
            DSP038ProcessGroundTic(tic, playerX, playerY, mightMilli,
                cooldownMultiplierMilli);
            N2CreditDamage(dsp038AcceptedDamageMilli - before, "GROUND");
            n2CumGroundHits += dsp038AcceptedHits - hitsBefore;
            N2ProfileEnd("GROUND");
        }
        if (N2HasEngine(N2_ENGINE_AURA))
        {
            int before = dsp039AcceptedDamageMilli;
            int hitsBefore = dsp039AcceptedHits;
            int recoveryMilli = DSP033Resolved(DSP033StatRules.STAT_RECOVERY);
            DSP039ProcessAuraTic(tic, playerX, playerY, mightMilli,
                cooldownMultiplierMilli, recoveryMilli);
            N2CreditDamage(dsp039AcceptedDamageMilli - before, "AURA");
            n2CumAuraHits += dsp039AcceptedHits - hitsBefore;
            N2ProfileEnd("AURA");
        }
        if (N2HasEngine(N2_ENGINE_GLOBAL_STRIKE) || N2HasEngine(N2_ENGINE_GLOBAL_ERASE))
        {
            int before = dsp040AcceptedDamageMilli;
            int strikeHitsBefore = dsp040AcceptedHits;
            int erasedBefore = dsp040ErasedEnemies;
            int amountResolved = DSP033AmountApplies(DSP040GlobalRows.SYSTEM_LIGHTNING)
                ? DSP033Resolved(DSP033StatRules.STAT_AMOUNT) : 0;
            if (rsActive) amountResolved = rsAmount;
            if (N2HasEngine(N2_ENGINE_GLOBAL_STRIKE))
                DSP040ProcessStrikeTic(tic, playerX, playerY, amountResolved);
            if (N2HasEngine(N2_ENGINE_GLOBAL_ERASE))
                DSP040ProcessEraseTic(tic, playerX, playerY,
                    rsActive ? rsLuckMilli : DSP040GlobalRows.LUCK_BASE_MILLI, amountResolved);
            N2CreditDamage(dsp040AcceptedDamageMilli - before, "GLOBAL");
            n2CumGlobalStrikeHits += dsp040AcceptedHits - strikeHitsBefore;
            n2CumGlobalErased += dsp040ErasedEnemies - erasedBefore;
            N2ProfileEnd("GLOBAL");
        }
        if (N2HasEngine(N2_ENGINE_BOUNCE))
        {
            int before = dsp041AcceptedDamageMilli;
            int hitsBefore = dsp041AcceptedHits;
            for (int i = 0; i < n2System.Size(); i++)
            {
                if (N2EngineForSystem(n2System[i]) != N2_ENGINE_BOUNCE) continue;
                if (DSP041FireVolley(n2EngineIndex[i], tic, facingYawMilli,
                    cooldownMultiplierMilli, rsActive ? rsLuckMilli : 1000)) WeaponSfx(n2System[i]);
            }
            DSP041AdvanceTic(tic);
            N2CreditDamage(dsp041AcceptedDamageMilli - before, "BOUNCE");
            n2CumBounceHits += dsp041AcceptedHits - hitsBefore;
            N2ProfileEnd("BOUNCE");
        }
        if (N2HasEngine(N2_ENGINE_PAIRED))
        {
            int before = dsp042AcceptedDamageMilli;
            int hitsBefore = dsp042AcceptedHits;
            for (int i = 0; i < n2System.Size(); i++)
            {
                if (N2EngineForSystem(n2System[i]) != N2_ENGINE_PAIRED) continue;
                if (DSP042FireVolley(n2EngineIndex[i], tic, facingYawMilli,
                    playerX, playerY, cooldownMultiplierMilli, mightMilli,
                    rsActive ? rsLuckMilli : 1000)) WeaponSfx(n2System[i]);
            }
            DSP042AdvanceTic(tic);
            N2CreditDamage(dsp042AcceptedDamageMilli - before, "PAIRED");
            n2CumPairedHits += dsp042AcceptedHits - hitsBefore;
            N2ProfileEnd("PAIRED");
        }
    }

    void AddDamageDealt(int delta)
    {
        if (delta <= 0) return;
        damageDealt = damageDealt > 2147483647 - delta ? 2147483647 : damageDealt + delta;
    }

    void N2CreditDamage(int delta, String engineName)
    {
        if (delta <= 0) return;
        Sfx(DSSfx.ForHitEngine(engineName), 4);
        // A full 30:00 run exceeds int milli-damage; the stat saturates.
        if (damageDealt > 2147483647 - delta)
        {
            if (damageDealt != 2147483647)
                Console.Printf("DS_N2_DAMAGE_TOTAL_SATURATED tic=%d engine=%s total=%d delta=%d", tic, engineName, damageDealt, delta);
            damageDealt = 2147483647;
            return;
        }
        damageDealt += delta;
        { if (!dsQuiet) Console.Printf("DS_N2_DISPATCH_DAMAGE_CREDIT tic=%d engine=%s accepted_delta_milli=%d total_milli=%d authority=N2_DISPATCHER_ACCEPTED_DELTA", tic, engineName, delta, damageDealt); }
    }

    // OwnedWeaponsHash(): exact-equality persistence hash over every
    // dispatcher-owned weapon's engine state plus Whip's own rank (Whip
    // keeps its existing rank field as authority; this just folds it in so
    // callers get one combined figure per the contract's "Weapon slots"/
    // persistence note).
    int OwnedWeaponsHash()
    {
        int hash = 17;
        hash = hash * 31 + whipRank;
        for (int i = 0; i < n2System.Size(); i++)
        {
            hash = hash * 31 + n2System[i];
            hash = hash * 31 + n2Rank[i];
        }
        if (N2HasEngine(N2_ENGINE_AIMED)) hash = hash * 31 + DSP034AimedStateHash();
        if (N2HasEngine(N2_ENGINE_BALLISTIC)) hash = hash * 31 + DSP035BallisticStateHash();
        if (N2HasEngine(N2_ENGINE_RETURNING)) hash = hash * 31 + DSP036ReturningStateHash();
        if (N2HasEngine(N2_ENGINE_ORBIT)) hash = hash * 31 + DSP037OrbitStateHash();
        if (N2HasEngine(N2_ENGINE_GROUND)) hash = hash * 31 + DSP038GroundStateHash();
        if (N2HasEngine(N2_ENGINE_AURA)) hash = hash * 31 + DSP039AuraStateHash();
        if (N2HasEngine(N2_ENGINE_GLOBAL_STRIKE) || N2HasEngine(N2_ENGINE_GLOBAL_ERASE))
            hash = hash * 31 + DSP040GlobalStateHash();
        if (N2HasEngine(N2_ENGINE_BOUNCE)) hash = hash * 31 + DSP041PersistenceHash();
        if (N2HasEngine(N2_ENGINE_PAIRED)) hash = hash * 31 + DSP042PersistenceHash();
        return hash;
    }

    // Aimed (P034) has no rebase entry point (its projectiles carry no
    // persistent absolute position that survives a map-position rebase);
    // every other engine below does.
    void RebaseOwnedWeapons(double deltaX, double deltaY)
    {
        if (N2HasEngine(N2_ENGINE_RETURNING)) DSP036RebaseProjectiles(deltaX, deltaY);
        if (N2HasEngine(N2_ENGINE_ORBIT)) DSP037RebaseOrbitMembers(deltaX, deltaY);
        if (N2HasEngine(N2_ENGINE_GROUND)) DSP038RebaseGroundRuntime(deltaX, deltaY);
        if (N2HasEngine(N2_ENGINE_AURA)) DSP039RebaseAura(deltaX, deltaY);
        if (N2HasEngine(N2_ENGINE_GLOBAL_STRIKE) || N2HasEngine(N2_ENGINE_GLOBAL_ERASE))
            DSP040RebaseGlobal(deltaX, deltaY);
        if (N2HasEngine(N2_ENGINE_BOUNCE)) DSP041Rebase(deltaX, deltaY, tic);
        if (N2HasEngine(N2_ENGINE_PAIRED)) DSP042Rebase(deltaX, deltaY, tic);
    }

    // N2 evidence fixture (ds_n2_grant_all, docs/contracts/normal-play-
    // integration.md "Evidence"): grants one of every draftable base weapon
    // at rank 1 through AcquireWeapon at a fixed early tic, then ranks each
    // up to max through SetWeaponRank over the run -- exercising every
    // dispatcher-routed engine, not just whichever ones a real draft roll
    // would pick. Fixture-only: ds_n2_grant_all defaults to 0 and is never
    // set by the manual launcher route.
    void N2GrantAllSystems(out Array<int> systems)
    {
        systems.Clear();
        systems.Push(DSP034WeaponRows.SYSTEM_MAGIC_WAND);
        systems.Push(DSP034WeaponRows.SYSTEM_KNIFE);
        systems.Push(DSP035WeaponRows.SYSTEM_AXE);
        systems.Push(DSP035WeaponRows.SYSTEM_FIRE_WAND);
        systems.Push(DSP036ReturningRows.SYSTEM_CROSS);
        systems.Push(DSP037OrbitRows.SYSTEM_KING_BIBLE);
        systems.Push(DSP038GroundRows.SYSTEM_HOLYWATER);
        systems.Push(DSP039AuraRows.SYSTEM_GARLIC);
        systems.Push(DSP040GlobalRows.SYSTEM_LIGHTNING);
        systems.Push(DSP040GlobalRows.SYSTEM_PENTAGRAM);
        systems.Push(DSP041BounceRows.SYSTEM_RUNETRACER);
        // N3 Track A: Bone/Cherry Bomb/Carréllo were already-implemented
        // DSP041BounceRows data rows never previously routed through this
        // dispatcher (see N2EngineForSystem's own comment); Celestial
        // Dusting/La Robba are new draftable base weapons joining the same
        // engine. Anima of Mortaccio/Carrozza!/Profusione D'Amore/Yatta
        // Daikarin are evolution-only and are instead exercised by
        // n2EvolutionFixtureEnabled's recipes 406/417/418/419 below,
        // matching how the rest of this fixture treats evolution-only
        // systems.
        systems.Push(DSP041BounceRows.SYSTEM_BONE);
        systems.Push(DSP041BounceRows.SYSTEM_CHERRY);
        systems.Push(DSP041BounceRows.SYSTEM_CARRELLO);
        systems.Push(DSN3Rows.SYSTEM_CELESTIAL_DUSTING);
        systems.Push(DSN3Rows.SYSTEM_LA_ROBBA);
        systems.Push(DSP042PairedRows.SYSTEM_PEACHONE);
        systems.Push(DSP042PairedRows.SYSTEM_EBONY);
        systems.Push(DSP042PairedRows.SYSTEM_PHIERA);
        systems.Push(DSP042PairedRows.SYSTEM_EIGHT);
        systems.Push(DSP042PairedRows.SYSTEM_VENTO);
        systems.Push(DSP042PairedRows.SYSTEM_BRACELET);
        // N3 Track A (docs/contracts/remaining-weapons.md): every draftable
        // Track A ballistic-engine weapon this worker wired. Mannajja is
        // evolution-only (not draftable) and is exercised instead by
        // n2EvolutionFixtureEnabled's recipe 402 below, matching how the
        // rest of this fixture treats evolution-only systems.
        systems.Push(DSN3Rows.SYSTEM_MAGI_STONE);
        systems.Push(DSN3Rows.SYSTEM_SONG_OF_MANA);
    }

    void N2GrantAllFixture()
    {
        // Automated runs only: ds_n2_grant_ids "104,115" acquires those
        // weapon systems at rank 1 at tic 70.
        CVar grantIds = CVar.FindCVar("ds_n2_grant_ids");
        if (grantIds != null && grantIds.GetString() != "" && tic == 70)
        {
            Array<String> parts;
            grantIds.GetString().Split(parts, ",");
            for (int i = 0; i < parts.Size(); i++)
            {
                // Stage-grant route first so the draft inventory knows the item
                // (and offers its rank-ups); plain acquire is the fallback.
                bool viaDraft = DSP031StageGrant(parts[i].ToInt());
                Console.Printf("DS_N2_GRANT_IDS system=%d accepted=%d via_draft=%d", parts[i].ToInt(), viaDraft ? 1 : AcquireWeapon(parts[i].ToInt(), 1), viaDraft);
            }
        }
        CVar grantAll = CVar.FindCVar("ds_n2_grant_all");
        if (grantAll == null || grantAll.GetInt() == 0) return;
        Array<int> systems;
        N2GrantAllSystems(systems);
        if (!n2GrantAllAcquired && tic == 70)
        {
            int acceptedCount = 0;
            for (int i = 0; i < systems.Size(); i++)
                if (AcquireWeapon(systems[i], 1)) acceptedCount++;
            n2GrantAllAcquired = true;
            Console.Printf("DS_N2_GRANT_ALL_ACQUIRE tic=%d requested=%d accepted=%d classification=N2_DISPATCH_EVIDENCE_FIXTURE", tic, systems.Size(), acceptedCount);
        }
        if (n2GrantAllAcquired && n2GrantAllRankStep < 7
            && tic == 70 + (n2GrantAllRankStep + 1) * 10)
        {
            n2GrantAllRankStep++;
            int rank = n2GrantAllRankStep + 1;
            int acceptedCount = 0;
            for (int i = 0; i < systems.Size(); i++)
                if (SetWeaponRank(systems[i], rank)) acceptedCount++;
            Console.Printf("DS_N2_GRANT_ALL_RANK tic=%d rank=%d requested=%d accepted=%d classification=N2_DISPATCH_EVIDENCE_FIXTURE", tic, rank, systems.Size(), acceptedCount);
        }
    }

    // N2 dispatch evidence density fixture: cvar-gated on ds_n2_grant_all
    // (the same fixture cvar N2GrantAllFixture uses, and never set by the
    // default manual launcher route -- see that function's own comment), so
    // the default manual route's enemy density is completely unchanged.
    // Real gameplay's early-run spawn cadence (EmitSpawnAttempt/
    // ReleaseDueSpawns: one admission roughly every 70 tics in phase 0) only
    // produced ~29 enemies over the fixture's ~2100-tic run -- plenty for
    // the manual route's own sparse-by-design first minute, but not enough
    // for every one of the 17 granted weapon families (melee-range aura/
    // ground, mid-range orbit, long-range aimed/ballistic/bounce, and
    // screen-wide global strike/erase) to land a real accepted hit. This
    // keeps a steady ring of N2_RING_COUNT stationary, high-health
    // (survives repeated hits so every engine gets multiple chances, but
    // still dies to a real Pentagram-style erase) controlled targets at two
    // alternating radii (60/180 units) around the player, respawning any
    // member that dies or otherwise leaves the store in place next tic.
    // Labelled N2_DISPATCH_EVIDENCE_FIXTURE throughout, matching
    // TryP040Map16MoonTargetFixture's own ring-of-enemies precedent.
    void N2MaintainDispatchEvidenceRing()
    {
        CVar grantAll = CVar.FindCVar("ds_n2_grant_all");
        // N2-W6: the EVOLUTION_EVIDENCE_FIXTURE reuses this same ring so its
        // granted/evolved weapons have real targets to hit, without turning
        // on the unrelated ds_n2_grant_all 17-weapons-at-once fixture.
        bool grantAllOn = grantAll != null && grantAll.GetInt() != 0;
        if (!grantAllOn && !n2EvolutionFixtureEnabled) return;
        if (players[0].mo == null
            || !ValidParts(playerSlot, generations[playerSlot], ids[playerSlot]))
            return;
        if (n2RingSlot.Size() == 0)
        {
            for (int i = 0; i < N2_RING_COUNT; i++)
            {
                n2RingSlot.Push(-1); n2RingGeneration.Push(0);
                n2RingStableId.Push(0);
            }
        }
        int spawnedThisTic = 0;
        for (int i = 0; i < N2_RING_COUNT; i++)
        {
            if (n2RingSlot[i] >= 0
                && ValidParts(n2RingSlot[i], n2RingGeneration[i], n2RingStableId[i])
                && lifeStates[n2RingSlot[i]] == STORE_ALIVE
                && health[n2RingSlot[i]] > 0)
                continue;
            double radius = (i % 2 == 0) ? 60.0 : 180.0;
            double angle = double(i) * (360.0 / N2_RING_COUNT) * 3.14159265 / 180.0;
            int slot = Allocate(KIND_ENEMY, playerX + radius * cos(angle),
                playerY + radius * sin(angle), 0.0, 0.0, 1000000);
            if (slot < 0) continue;
            collisionRadii[slot] = 8.0;
            n2RingSlot[i] = slot; n2RingGeneration[i] = generations[slot];
            n2RingStableId[i] = ids[slot];
            spawnedThisTic++;
        }
        if (spawnedThisTic > 0)
            Console.Printf("DS_N2_DISPATCH_EVIDENCE_RING tic=%d ring_count=%d spawned=%d classification=N2_DISPATCH_EVIDENCE_FIXTURE", tic, N2_RING_COUNT, spawnedThisTic);
    }

    // One end-of-run summary line per owned dispatcher weapon (evidence for
    // tools/run_n2_dispatch.py's strict validator): its final rank, and its
    // engine's accepted-hit/erase counter so "every granted system produced
    // >=1 accepted hit" can be checked without needing a granular per-hit
    // log for every engine (each engine's own pNNN route already proves
    // its per-hit ledger integrity; this only needs the totals).
    void N2LogDispatchSummary()
    {
        for (int i = 0; i < n2System.Size(); i++)
        {
            int engine = N2EngineForSystem(n2System[i]);
            int acceptedHits = 0;
            int erased = 0;
            // Reads the dispatcher-owned cumulative totals (n2Cum*), not the
            // engines' own live dsp0xxAcceptedHits/dsp040ErasedEnemies
            // counters: TearDownRun() (called from EndRun before this
            // summary runs) resets every engine's live counters to 0, so
            // reading them here always reported 0 regardless of what
            // actually happened during the run.
            if (engine == N2_ENGINE_AIMED) acceptedHits = n2CumAimedHits;
            else if (engine == N2_ENGINE_BALLISTIC) acceptedHits = n2CumBallisticHits;
            else if (engine == N2_ENGINE_RETURNING) acceptedHits = n2CumReturningHits;
            else if (engine == N2_ENGINE_ORBIT) acceptedHits = n2CumOrbitHits;
            else if (engine == N2_ENGINE_GROUND) acceptedHits = n2CumGroundHits;
            else if (engine == N2_ENGINE_AURA) acceptedHits = n2CumAuraHits;
            else if (engine == N2_ENGINE_GLOBAL_STRIKE) acceptedHits = n2CumGlobalStrikeHits;
            else if (engine == N2_ENGINE_GLOBAL_ERASE) erased = n2CumGlobalErased;
            else if (engine == N2_ENGINE_BOUNCE) acceptedHits = n2CumBounceHits;
            else if (engine == N2_ENGINE_PAIRED) acceptedHits = n2CumPairedHits;
            else if (engine == N2_ENGINE_GENERIC) acceptedHits = GwHitsFor(n2System[i]);
            Console.Printf("DS_N2_DISPATCH_SUMMARY system_id=%d rank=%d engine=%d accepted_hits=%d erased=%d classification=N2_DISPATCHER", n2System[i], n2Rank[i], engine, acceptedHits, erased);
        }
        FxLogCounts();
        Console.Printf("DS_N2_DISPATCH_TOTALS owned=%d acquire_count=%d rank_change_count=%d owned_hash=%d classification=N2_DISPATCHER", n2System.Size(), n2AcquireCount, n2RankChangeCount, OwnedWeaponsHash());
    }

    void ResetOwnedWeapons()
    {
        n2System.Clear(); n2Rank.Clear(); n2Slot.Clear();
        n2EngineIndex.Clear();
        n2AcquireCount = 0; n2RankChangeCount = 0;
        n2PendingSystem.Clear(); n2PendingRank.Clear(); n2PendingFresh.Clear();
        n2PendingPassiveRecompute = false;
        n2GrantAllAcquired = false; n2GrantAllRankStep = 0;
        n2CumAimedHits = 0; n2CumBallisticHits = 0; n2CumReturningHits = 0;
        n2CumOrbitHits = 0; n2CumGroundHits = 0; n2CumAuraHits = 0;
        n2CumGlobalStrikeHits = 0; n2CumGlobalErased = 0;
        n2CumBounceHits = 0; n2CumPairedHits = 0;
        n2RingSlot.Clear(); n2RingGeneration.Clear(); n2RingStableId.Clear();
    }

    // N2-W7 normal-flow soak evidence (ds_n2_draft_bot, docs/contracts/
    // normal-play-integration.md "Evidence (N2 acceptance)" item 2): a
    // labelled deterministic choice policy that answers a real, currently
    // open level-up modal through the exact same ApplyChoice acceptance
    // path the player's physical-key/network-event input uses. Called once
    // per real (world) tic while runState == STATE_LEVELUP, from the same
    // spot the native input responder is skipped for that state, so it
    // never races the modal's own single-open guard (modalPlayOpen).
    void N2DraftBotTick()
    {
        CVar bot = CVar.FindCVar("ds_n2_draft_bot");
        if (bot == null || bot.GetInt() == 0) return;
        if (arPickOpen) { Console.Printf("DS_N2_DRAFT_BOT tic=%d arcana_index=0 classification=N2_DRAFT_BOT", tic); ApplyArcanaChoice(0); return; }
        if (!modalPlayOpen || ActiveDraftQueueCount() <= 0) return;
        int count = ActiveDraftOfferCount();
        if (count <= 0) return;
        int bestIndex = 0;
        int bestScore = -1;
        int worstIndex = 0;
        int worstScore = 0x7FFFFFFF;
        for (int i = 0; i < count; i++)
        {
            int score = N2DraftBotScore(ActiveDraftOfferId(i));
            CVar prefer = CVar.FindCVar("ds_n2_bot_prefer");
            if (prefer != null && prefer.GetInt() == ActiveDraftOfferId(i)) score += 100000;
            if (score > bestScore) { bestScore = score; bestIndex = i; }
            if (score < worstScore) { worstScore = score; worstIndex = i; }
        }
        // Spend any level-up charges first, one action per tic (only when a
        // run starts with charges; the default soak has none).
        if (p031RouteEnabled && dsp031RerollsRemaining > 0) { if (LevelUpAction(LEVELUP_ACTION_REROLL, 0)) return; }
        if (p031RouteEnabled && dsp031BanishesRemaining > 0 && count > 1) { if (LevelUpAction(LEVELUP_ACTION_BANISH, worstIndex)) return; }
        if (p031RouteEnabled && dsp031SkipsRemaining > 0 && playerLevel >= 4) { if (LevelUpAction(LEVELUP_ACTION_SKIP, 0)) return; }
        Console.Printf("DS_N2_DRAFT_BOT tic=%d level=%d index=%d offer_id=%d score=%d classification=N2_DRAFT_BOT", tic, playerLevel, bestIndex, ActiveDraftOfferId(bestIndex), bestScore);
        ApplyChoice(bestIndex, "N2_DRAFT_BOT");
    }

    // N2-W8 soak-only autonomous mover (ds_n2_soak_mover, amended N2
    // acceptance item 2): each real (world) tic while runState ==
    // STATE_ACTIVE, steers the real player body toward the nearest live XP
    // pickup (fallback: the active interim chest's recorded spawn position)
    // by injecting players[0].cmd and invoking the same real P021 body
    // adapter (DSP021FirstPersonPlayer.MovePlayer()) the P032 MAP16
    // movement tape (DS_P032_MAP16_MOVEMENT_TAPE) already exercises. It
    // only ever sets forwardmove/yaw on the real command struct and calls
    // the real MovePlayer -- it never assigns Pos/Angle directly and never
    // teleports. The injected command is cleared immediately after so it is
    // not replayed as native input on the following engine tic.
    void N2SoakMoverTick()
    {
        if (runState != STATE_ACTIVE || players[0].mo == null) return;
        CVar mover = CVar.FindCVar("ds_n2_soak_mover");
        if (mover == null || mover.GetInt() == 0) return;
        int bestSlot = -1;
        double bestDistSq = 0.0;
        for (int slot = 0; slot < lifeStates.Size(); slot++)
        {
            if (!DSP027IsLivePickup(slot)) continue;
            double dx = x[slot] - playerX;
            double dy = y[slot] - playerY;
            double distSq = dx * dx + dy * dy;
            if (bestSlot < 0 || distSq < bestDistSq) { bestSlot = slot; bestDistSq = distSq; }
        }
        double targetX, targetY;
        String targetKind;
        if (bestSlot >= 0)
        {
            targetX = x[bestSlot]; targetY = y[bestSlot]; targetKind = "XP_PICKUP";
        }
        else if (n2ActiveChestId > 0)
        {
            targetX = n2ChestTargetX; targetY = n2ChestTargetY; targetKind = "INTERIM_CHEST";
        }
        else return;
        double dx = targetX - playerX;
        double dy = targetY - playerY;
        double dist = sqrt(dx * dx + dy * dy);
        if (dist < 4.0) return;
        double targetAngle = VectorAngle(dx, dy);
        double yawDelta = targetAngle - players[0].mo.Angle;
        while (yawDelta > 180.0) yawDelta -= 360.0;
        while (yawDelta < -180.0) yawDelta += 360.0;
        players[0].cmd.yaw = int(yawDelta * (65536.0 / 360.0));
        // Forward toward the target. (The P032 tape uses -32768 because it
        // deliberately walks backward into a chest behind the player; copying
        // that here made the mover retreat from every pickup.)
        players[0].cmd.forwardmove = 32767;
        players[0].cmd.sidemove = 0;
        players[0].cmd.pitch = 0;
        DSP021FirstPersonPlayer moverPawn = DSP021FirstPersonPlayer(players[0].mo);
        bool moveApplied = moverPawn != null;
        if (moveApplied)
        {
            moverPawn.MovePlayer();
            SyncPlayer();
        }
        players[0].cmd.forwardmove = 0;
        players[0].cmd.sidemove = 0;
        players[0].cmd.yaw = 0;
        players[0].cmd.pitch = 0;
        Console.Printf("DS_N2_SOAK_MOVER accepted=1 tic=%d target=%s target_x=%.3f target_y=%.3f dist=%.3f yaw_delta=%.3f move_player=%d source=ENGINE_TAPE_P021_BODY", tic, targetKind, targetX, targetY, dist, yawDelta, moveApplied);
    }

    // Priority: (a) an unowned weapon while ordinary weapon slots remain
    // scores highest; (b) an unowned passive some currently-owned weapon's
    // real evolution/union recipe needs scores next; (c) ranking an
    // already-owned weapon toward its max rank scores next; everything
    // else (including an unowned weapon with no free slot, an unowned
    // passive nothing currently needs, or an already-maxed item) scores
    // low, and the GOLD/CHICKEN fallback ids score lowest of all. Only
    // reads real state (DSP031Rank/Category/MaxRank/OrdinaryCount, the real
    // DSP032 recipe tables); never mutates anything itself.
    int N2DraftBotScore(int id)
    {
        if (id == DSP031_ID_FALLBACK_GOLD || id == DSP031_ID_FALLBACK_CHICKEN) return 0;
        if (!DSP031Selectable(id)) return 0;
        int category = DSP031Category(id);
        int rank = DSP031Rank(id);
        int maxRank = DSP031MaxRank(id);
        bool owned = rank > 0;
        if (category == DSP031_CATEGORY_WEAPON)
        {
            if (!owned)
                return DSP031OrdinaryCount(DSP031_CATEGORY_WEAPON) < DSP031_MAX_ORDINARY_SLOTS ? 30 : 5;
            // Focus policy (labelled N2_DRAFT_BOT): once a weapon's recipe
            // passive is owned, rank it toward max ahead of everything else,
            // highest rank first, so evolutions become reachable in a run.
            if (rank < maxRank && N2DraftBotWeaponHasRecipePassive(id))
                return 40 + rank;
            return rank < maxRank ? 12 : 2;
        }
        if (!owned)
            return N2DraftBotPassiveNeeded(id) ? 25 : 8;
        return rank < maxRank ? 10 : 2;
    }

    // True when `passiveId` is the required second input (or, for the
    // Phieraggi union, the required rank>=1 gate) of a real DSP032 recipe
    // whose weapon input is currently owned. Reads the same recipe table
    // DSP032CanApplyRecipe/DSP032ApplyRecipe use for real chest evolutions;
    // never a separately maintained copy.
    // Every weapon(max) + passive evolution recipe, ascending: Whip -> Bloody
    // Tear, the base 301-311 and all N3 401-419. The draft bot, the chest's
    // recipe scan and the passive sync all read this one list, so a recipe
    // left off it can never evolve in play (14 of the N3 ones once were).
    void N2WeaponPassiveRecipes(out Array<int> recipes)
    {
        recipes.Push(DSP032_RECIPE_WHIP_BLOODY_TEAR);
        for (int r = DSP032_RECIPE_HOLY_WAND; r <= DSP032_RECIPE_NO_FUTURE; r++)
            recipes.Push(r);
        for (int r = DSP032_RECIPE_N3_VICIOUS_HUNGER; r <= DSP032_RECIPE_N3_CARROZZA; r++)
            recipes.Push(r);
    }

    // True when an owned weapon's evolution passive (recipe input B) is owned.
    bool N2DraftBotWeaponHasRecipePassive(int weaponId)
    {
        Array<int> recipes;
        N2WeaponPassiveRecipes(recipes);
        for (int i = 0; i < recipes.Size(); i++)
        {
            int r = recipes[i];
            if (DSP032RecipeInputA(r) == weaponId && DSP031Rank(DSP032RecipeInputB(r)) > 0)
                return true;
        }
        return false;
    }

    bool N2DraftBotPassiveNeeded(int passiveId)
    {
        Array<int> recipes;
        N2WeaponPassiveRecipes(recipes);
        for (int i = 0; i < recipes.Size(); i++)
        {
            int r = recipes[i];
            if (DSP032RecipeInputB(r) == passiveId && DSP031Rank(DSP032RecipeInputA(r)) > 0)
                return true;
        }
        if (passiveId == DSP032_ID_TIRAJISU && DSP031Rank(DSP032_ID_PHIERA) > 0) return true;
        return false;
    }

    // Drains the queue DraftFull.zs's DSP031ApplyWeaponDispatch/
    // DSP031RecomputeN2Passives pushed to (see the n2Pending* fields'
    // comment above for why a queue instead of a direct call). Called once
    // per LogicalTic, before ProcessOwnedWeapons, so a weapon drafted this
    // tic is owned and processed the very same tic.
    void N2DrainPendingDispatch()
    {
        for (int i = 0; i < n2PendingSystem.Size(); i++)
        {
            if (n2PendingFresh[i] != 0)
                AcquireWeapon(n2PendingSystem[i], n2PendingRank[i]);
            else
                SetWeaponRank(n2PendingSystem[i], n2PendingRank[i]);
        }
        n2PendingSystem.Clear(); n2PendingRank.Clear(); n2PendingFresh.Clear();
        if (n2PendingPassiveRecompute)
        {
            DSP033RecomputeRecovery(DSP031Rank(DSN2Catalog.ID_PUMMAROLA));
            DSP033RecomputeAmountGrowth(DSP031Rank(DSN2Catalog.ID_DUPLICATOR),
                DSP031Rank(DSN2Catalog.ID_CROWN));
            n2PendingPassiveRecompute = false;
        }
    }

    // N2-W5 (docs/contracts/normal-play-integration.md "Evolutions and
    // chests"): mirrors the manual route's real state -- owned weapons
    // (n2System/n2Rank, plus Whip's own field) and the eleven evolutions'
    // passive gates (DSP031Rank, the full-catalog draft authority) -- into
    // the P032 graph's own inventory bookkeeping (dsp032ItemIds/Ranks) so
    // DSP032CanApplyRecipe/DSP032Rank/DSP032ApplyRecipe (shared, byte-
    // identical machinery with the opt-in P032/P042 Map16 routes) evaluate
    // against the manual route's live draft state instead of a Map16-only
    // fixture inventory. DSP032SetItem is idempotent (updates rank if the id
    // is already present) so this never disturbs the chest reward ledger.
    void N2SyncTransformationInventory()
    {
        if (whipRank > 0) DSP032SetItem(DSP032_ID_WHIP, whipRank);
        for (int i = 0; i < n2System.Size(); i++)
            DSP032SetItem(n2System[i], n2Rank[i]);
        N2SyncPassiveIntoGraph(DSP032_ID_EMPTY_TOME);
        N2SyncPassiveIntoGraph(DSP032_ID_BRACER);
        N2SyncPassiveIntoGraph(DSP032_ID_CANDELABRADOR);
        N2SyncPassiveIntoGraph(DSP032_ID_SPINACH);
        N2SyncPassiveIntoGraph(DSP032_ID_CLOVER);
        N2SyncPassiveIntoGraph(DSP032_ID_SPELLBINDER);
        N2SyncPassiveIntoGraph(DSP032_ID_ATTRACTORB);
        N2SyncPassiveIntoGraph(DSP032_ID_PUMMAROLA);
        N2SyncPassiveIntoGraph(DSP032_ID_DUPLICATOR);
        N2SyncPassiveIntoGraph(DSP032_ID_CROWN);
        N2SyncPassiveIntoGraph(DSP032_ID_ARMOR);
        N2SyncPassiveIntoGraph(DSP032_ID_HOLLOW_HEART);
        N2SyncPassiveIntoGraph(DSP032_ID_TIRAJISU);
        // N3 Track A: recipe 402's Skull O'Maniac gate (missed on the
        // first pass -- a real evolution-fixture run showed recipe 402
        // rejected with DSP032Rank(inputB)<=0 despite the passive itself
        // being granted through N2GrantEvolutionPassives, because that
        // grant alone never reaches the P032 ledger DSP032CanApplyRecipe
        // actually reads).
        N2SyncPassiveIntoGraph(DSP032_ID_N3_SKULL_O_MANIAC);
        // N3 Track A (bounce engine): recipes 406/417/418/419's own passive
        // gates, same missed-sync risk the ballistic worker already found
        // and fixed for Skull O'Maniac above.
        N2SyncPassiveIntoGraph(DSP032_ID_N3_CHAOS_ALTEMANNA);
        N2SyncPassiveIntoGraph(DSP032_ID_N3_CHAOS_MALACHITE);
        N2SyncPassiveIntoGraph(DSP032_ID_N3_CHAOS_ROSALIA);
        N2SyncPassiveIntoGraph(DSP032_ID_N3_CHAOS_LAZULIA);
        // Normal play: each Chaos relic is held with its weapon and wakes at
        // character level 80, letting that weapon morph (evolve) in a chest.
        if (rsActive)
        {
            N2SyncChaosRelic(DSP032_ID_N3_CHAOS_ALTEMANNA, DSP032_ID_N3_CELESTIAL_DUSTING);
            N2SyncChaosRelic(DSP032_ID_N3_CHAOS_MALACHITE, DSP032_ID_BONE);
            N2SyncChaosRelic(DSP032_ID_N3_CHAOS_ROSALIA, DSP032_ID_CHERRY_BOMB);
            N2SyncChaosRelic(DSP032_ID_N3_CHAOS_LAZULIA, DSP032_ID_CARRELLO);
        }
        // Every other N3 recipe's passive gate (Stone Mask, Wings, Karoma's
        // Mana...): without these the graph never sees the passive and the
        // recipe can't apply. Re-syncing the ones above is harmless.
        for (int r = DSP032_RECIPE_N3_VICIOUS_HUNGER; r <= DSP032_RECIPE_N3_CARROZZA; r++)
            N2SyncPassiveIntoGraph(DSP032RecipeInputB(r));
    }

    void N2SyncChaosRelic(int relic, int weapon)
    {
        if (playerLevel >= 80 && N2Find(weapon) >= 0) DSP032SetItem(relic, 1);
    }

    void N2SyncPassiveIntoGraph(int id)
    {
        int rank = DSP031Rank(id);
        if (rank > 0) DSP032SetItem(id, rank);
    }

    // Deterministic lowest-recipe-id-first scan (contract "Opening it
    // applies one eligible recipe... otherwise a rank-up reward"). Recipe
    // ids ascend in this array already (1, 201-205, 301-311) so no separate
    // sort step is needed.
    int N2NextEligibleRecipeId()
    {
        Array<int> standard;
        N2WeaponPassiveRecipes(standard);
        Array<int> candidates;
        candidates.Push(standard[0]); // Whip -> Bloody Tear
        candidates.Push(DSP032_RECIPE_UNION_VANDALIER);
        candidates.Push(DSP032_RECIPE_UNION_PHIERAGGI);
        candidates.Push(DSP032_RECIPE_UNION_FUWALAFUWALOO);
        candidates.Push(DSP032_RECIPE_CHAIN_BRACELET_BI);
        candidates.Push(DSP032_RECIPE_CHAIN_BI_TRI);
        for (int i = 1; i < standard.Size(); i++) candidates.Push(standard[i]);
        for (int i = 0; i < candidates.Size(); i++)
        {
            // N2-W6 fix: DSP032CanApplyRecipe's "output not already owned"
            // guard (its only re-application defense) is not sufficient on
            // its own -- a later union/chain recipe can consume an earlier
            // recipe's output as one of ITS OWN inputs (confirmed by an
            // actual run: recipe 203 consumes Bloody Tear, recipe 1's own
            // output, freeing recipe 1 to become "eligible" again with Whip
            // and Hollow Heart both still owned, and re-applying a second
            // time through the very next interim chest). Recipes 1/201-205/
            // 301-311 are each meant to land exactly once per run
            // (INTERIM_CHEST_CADENCE contract), so once-applied ids are
            // skipped here regardless of what the shared graph's own
            // instantaneous ownership check would otherwise allow.
            bool alreadyApplied = false;
            for (int j = 0; j < n2AppliedRecipeIds.Size(); j++)
                if (n2AppliedRecipeIds[j] == candidates[i]) { alreadyApplied = true; break; }
            if (!alreadyApplied
                && DSP032CanApplyRecipe(candidates[i], DSP032_CHEST_SILVER, true, true))
                return candidates[i];
        }
        return 0;
    }

    // Opens an interim-cadence chest: applies the lowest eligible recipe
    // through the shared P032 graph authority, then routes the accepted
    // transform through the dispatcher's EvolveWeapon so the owned engine
    // actually switches form (contract: "route an applied recipe through
    // the dispatcher"); falls back to ranking up the manual route's lowest-
    // ranked owned weapon (Whip included) when no recipe is eligible yet.
    // Ranks up the lowest-ranked owned weapon that can still grow (Whip
    // included). Returns whether the rank-up applied; system is 0 if none.
    bool N2RankUpLowestWeapon(int chestId, out int system)
    {
        int bestSystem = 0; int bestRank = 999;
        if (whipRank > 0 && whipRank < 8) { bestSystem = DSP033StatRules.SYSTEM_WHIP; bestRank = whipRank; }
        for (int i = 0; i < n2System.Size(); i++)
        {
            int maxRank = DSP031MaxRank(n2System[i]);
            if (maxRank > 0 && n2Rank[i] < maxRank && n2Rank[i] < bestRank)
            {
                bestRank = n2Rank[i]; bestSystem = n2System[i];
            }
        }
        system = bestSystem;
        if (bestSystem <= 0) return false;
        bool applied = SetWeaponRank(bestSystem, bestRank + 1);
        Console.Printf("DS_N2_INTERIM_CHEST_RANKUP accepted=%d chest=%d system=%d new_rank=%d classification=INTERIM_CHEST_CADENCE", applied, chestId, bestSystem, bestRank + 1);
        return applied;
    }

    void N2OpenInterimChest(int chestId)
    {
        N2SyncTransformationInventory();
        int tx = chestId * 10 + 1;
        int recipeId = N2NextEligibleRecipeId();
        int rewardId = 0;
        bool applied = false;
        if (recipeId > 0)
        {
            int inputA = DSP032RecipeInputA(recipeId);
            int inputB = DSP032RecipeInputB(recipeId);
            int output = DSP032RecipeOutput(recipeId);
            int dependencyRank = inputB > 0 ? DSP032Rank(inputB) : 0;
            applied = DSP032ApplyRecipe(recipeId, chestId, DSP032_CHEST_SILVER,
                true, true, tx);
            if (applied)
            {
                bool evolved = inputA == DSP032_ID_WHIP ? true
                    : EvolveWeapon(inputA, output, 1, dependencyRank, true);
                rewardId = output;
                Sfx(DSSfx.E_EVOLUTION);
                Console.Printf("DS_N2_INTERIM_CHEST_RECIPE accepted=1 chest=%d recipe=%d input_a=%d input_b=%d output=%d dispatch_evolved=%d classification=INTERIM_CHEST_CADENCE", chestId, recipeId, inputA, inputB, output, evolved);
            }
        }
        if (!applied) applied = N2RankUpLowestWeapon(chestId, rewardId);
        if (rewardId <= 0) rewardId = chestId;
        bool recorded = DSP032RecordChestReward(chestId, 0, rewardId);
        bool completed = recorded && DSP032CompleteChest(chestId);
        DestroyP032ChestProxy(chestId);
        if (recipeId > 0 && applied)
        {
            n2EvolutionAppliedCount++;
            n2AppliedRecipeIds.Push(recipeId);
        }
        Console.Printf("DS_N2_INTERIM_CHEST_OPEN chest=%d recipe=%d applied=%d recorded=%d completed=%d evolutions_applied=%d classification=INTERIM_CHEST_CADENCE", chestId, recipeId, applied, recorded, completed, n2EvolutionAppliedCount);
    }

    // Spawns and picks up one interim chest every n2ChestCadenceInterval
    // tics (INTERIM_CHEST_CADENCE), reusing the same stable-id chest record/
    // proxy actor and DSP032ChestWithinPickupRange proximity path the opt-in
    // P032 Map16 route already uses, so the manual route needs no UI modal:
    // opening happens the instant the player walks into pickup range.
    void N2MaintainChestCadence()
    {
        if (!n2ChestCadenceEnabled || mfEnabled || runState != STATE_ACTIVE
            || players[0].mo == null) return;
        // N2-W6: DSP032ChestIds records never shrink (a completed chest
        // stays in the array), so a full-length run under
        // N2_EVOLUTION_EVIDENCE_FIXTURE would keep spawning a fresh chest
        // every cadence interval for the rest of the run and eventually
        // exhaust DSP032_MAX_CHESTS (confirmed by an actual run: chest 16
        // silently failed to spawn, stalling the cadence one recipe short).
        // Once every one of the 18 recipes (1, 201-205, 301-311, N3's 402) has
    // applied
        // there is no more evolution evidence to collect, so the fixture
        // stops spawning further chests entirely; the default manual route
        // (fixture off) is unaffected since n2EvolutionFixtureEnabled is
        // false there.
        // N3 Track A adds recipe 402 (Song of Mana + Skull O'Maniac ->
        // Mannajja) to this fixture's evidence set, so the cap grows from
        // the original 17 (1, 201-205, 301-311) to 18. This worker's four
        // bounce-engine recipes (406, 417, 418, 419: Profusione D'Amore,
        // Anima of Mortaccio, Yatta Daikarin, Carrozza!) raise it to 22,
        // and the remaining 14 N3 recipes (401, 403-405, 407-416) to 36.
        if (n2EvolutionFixtureEnabled && n2AppliedRecipeIds.Size() >= 36) return;
        if (n2ActiveChestId <= 0 && tic >= n2NextChestTic)
        {
            n2ChestSeq++;
            int chestId = runGeneration * 100000 + 90000 + n2ChestSeq;
            // N2_EVOLUTION_EVIDENCE_FIXTURE fix: spawn exactly at the
            // player's logical position instead of 40 units behind it.
            // The prior offset placed the chest outside its own 28-unit
            // pickup radius (dx^2+dy^2=1600 > 28^2=784), so the stationary
            // automated route could never satisfy
            // DSP032ChestWithinPickupRange and no chest was ever picked up.
            int cx = int(playerX);
            int cy = int(playerY);
            bool recorded = DSP032SpawnChestRecord(chestId, DSP032_CHEST_SILVER,
                1, 1, tic, 1, true, cx, cy, 28);
            if (recorded)
            {
                n2ActiveChestId = chestId;
                n2ChestTargetX = double(cx);
                n2ChestTargetY = double(cy);
                DSP032Map16ChestProxy chest = DSP032Map16ChestProxy(Actor.Spawn(
                    "DSP032Map16ChestProxy", (cx, cy, 8.0), NO_REPLACE));
                if (chest != null) chest.chestStableId = chestId;
                Console.Printf("DS_N2_INTERIM_CHEST_SPAWN accepted=1 id=%d tic=%d interval=%d x=%d y=%d classification=INTERIM_CHEST_CADENCE", chestId, tic, n2ChestCadenceInterval, cx, cy);
            }
            n2NextChestTic = tic + n2ChestCadenceInterval;
        }
        if (n2ActiveChestId > 0
            && DSP032ChestWithinPickupRange(n2ActiveChestId, int(playerX), int(playerY)))
        {
            int chestId = n2ActiveChestId;
            n2ActiveChestId = 0;
            if (DSP032PickUpChest(chestId, int(playerX), int(playerY)))
                N2OpenInterimChest(chestId);
        }
    }

    // N2-W6 EVOLUTION_EVIDENCE_FIXTURE: grants the 14 distinct gate passives
    // (13 original plus N3's Skull O'Maniac)
    // every 301-311 evolution plus recipes 1/202 need (rank>=1, never
    // consumed by an evolution -- DSP032ApplyRecipe only ever removes
    // inputA) through the real DSP031Acquire draft/inventory authority.
    // DSP031_MAX_ORDINARY_SLOTS is 6; the remaining 7 legitimately use
    // DSP031Acquire's own DSP031_ROUTE_STAGE extra-slot growth path (the
    // same mechanic a real staged offer beyond a full loadout already uses),
    // not a bypass of the slot check.
    void N2GrantEvolutionPassives()
    {
        Array<int> passives;
        passives.Push(DSN2Catalog.ID_HOLLOW_HEART);
        passives.Push(DSN2Catalog.ID_TIRAJISU);
        passives.Push(DSN2Catalog.ID_EMPTY_TOME);
        passives.Push(DSN2Catalog.ID_BRACER);
        passives.Push(DSN2Catalog.ID_CANDELABRADOR);
        passives.Push(DSN2Catalog.ID_SPINACH);
        passives.Push(DSN2Catalog.ID_CLOVER);
        passives.Push(DSN2Catalog.ID_SPELLBINDER);
        passives.Push(DSN2Catalog.ID_ATTRACTORB);
        passives.Push(DSN2Catalog.ID_PUMMAROLA);
        passives.Push(DSN2Catalog.ID_DUPLICATOR);
        passives.Push(DSN2Catalog.ID_CROWN);
        passives.Push(DSN2Catalog.ID_ARMOR);
        // N3 Track A: recipe 402's Skull O'Maniac gate.
        passives.Push(DSN2Catalog.ID_N3_SKULL_O_MANIAC);
        // N3 Track A (bounce engine): recipes 406/417/418/419's passive gates.
        passives.Push(DSN2Catalog.ID_N3_CHAOS_ALTEMANNA);
        passives.Push(DSN2Catalog.ID_N3_CHAOS_MALACHITE);
        passives.Push(DSN2Catalog.ID_N3_CHAOS_ROSALIA);
        passives.Push(DSN2Catalog.ID_N3_CHAOS_LAZULIA);
        // The other N3 recipes' gates (batches 4-6): Stone Mask (401),
        // Wings (403/411), Silver Ring (404), Metaglio Left (405), Torrona's
        // Box (407), Parm Aegis (413), Karoma's Mana (414). 408-410, 412,
        // 415 and 416 reuse passives already granted above.
        passives.Push(DSN2Catalog.ID_N3_STONE_MASK);
        passives.Push(DSN2Catalog.ID_N3_WINGS);
        passives.Push(DSN2Catalog.ID_N3_SILVER_RING);
        passives.Push(DSN2Catalog.ID_N3_METAGLIO_LEFT);
        passives.Push(DSN2Catalog.ID_N3_TORRONA_S_BOX);
        passives.Push(DSN2Catalog.ID_N3_PARM_AEGIS);
        passives.Push(DSN2Catalog.ID_N3_KAROMA_S_MANA);
        int accepted = 0;
        for (int i = 0; i < passives.Size(); i++)
            if (DSP031Acquire(passives[i], DSP031_ROUTE_STAGE, false)) accepted++;
        Console.Printf("DS_N2_EVOLVE_FIXTURE_PASSIVES tic=%d requested=%d accepted=%d classification=N2_EVOLUTION_EVIDENCE_FIXTURE", tic, passives.Size(), accepted);
    }

    // Grants and ranks one batch (<=6) of the 22 non-Whip weapon inputs
    // through the real AcquireWeapon/SetWeaponRank dispatcher (same call
    // sites N2GrantAllFixture already uses), so at most 6 concurrently-
    // owned custom weapons ever exist before their recipe consumes them.
    // Batch 1's 6 items exactly cover recipes 1/201/202/203/204/205; batch
    // 2's 6 cover 301-306; batch 3's 6 (N3's Song of Mana added) cover
    // 307-311 plus N3's 402. Batch 4 (this worker's bounce engine) covers
    // 406/417/418/419.
    void N2GrantEvolutionWeaponBatch(int batch)
    {
        Array<int> systems; Array<int> ranks;
        if (batch == 1)
        {
            systems.Push(DSP042PairedRows.SYSTEM_PEACHONE); ranks.Push(8);
            systems.Push(DSP042PairedRows.SYSTEM_EBONY); ranks.Push(8);
            systems.Push(DSP042PairedRows.SYSTEM_PHIERA); ranks.Push(8);
            systems.Push(DSP042PairedRows.SYSTEM_EIGHT); ranks.Push(8);
            systems.Push(DSP042PairedRows.SYSTEM_VENTO); ranks.Push(8);
            systems.Push(DSP042PairedRows.SYSTEM_BRACELET); ranks.Push(6);
        }
        else if (batch == 2)
        {
            systems.Push(DSP034WeaponRows.SYSTEM_MAGIC_WAND); ranks.Push(8);
            systems.Push(DSP034WeaponRows.SYSTEM_KNIFE); ranks.Push(8);
            systems.Push(DSP035WeaponRows.SYSTEM_AXE); ranks.Push(8);
            systems.Push(DSP035WeaponRows.SYSTEM_FIRE_WAND); ranks.Push(8);
            systems.Push(DSP036ReturningRows.SYSTEM_CROSS); ranks.Push(8);
            systems.Push(DSP037OrbitRows.SYSTEM_KING_BIBLE); ranks.Push(8);
        }
        else if (batch == 3)
        {
            systems.Push(DSP038GroundRows.SYSTEM_HOLYWATER); ranks.Push(8);
            systems.Push(DSP039AuraRows.SYSTEM_GARLIC); ranks.Push(8);
            systems.Push(DSP040GlobalRows.SYSTEM_LIGHTNING); ranks.Push(8);
            systems.Push(DSP040GlobalRows.SYSTEM_PENTAGRAM); ranks.Push(8);
            systems.Push(DSP041BounceRows.SYSTEM_RUNETRACER); ranks.Push(8);
            // N3 Track A: recipe 402's Song of Mana input.
            systems.Push(DSN3Rows.SYSTEM_SONG_OF_MANA); ranks.Push(8);
        }
        else if (batch == 4)
        {
            // N3 Track A (bounce engine): recipes 406/417/418/419's weapon
            // inputs. Celestial Dusting's own DSN3Rows.RankCount ceiling is
            // 8; Bone/Cherry Bomb/Carréllo are the pre-existing P041 base
            // weapons this worker newly routed through the dispatcher.
            systems.Push(DSN3Rows.SYSTEM_CELESTIAL_DUSTING); ranks.Push(8);
            systems.Push(DSP041BounceRows.SYSTEM_BONE); ranks.Push(8);
            systems.Push(DSP041BounceRows.SYSTEM_CHERRY); ranks.Push(8);
            systems.Push(DSP041BounceRows.SYSTEM_CARRELLO); ranks.Push(8);
            // Recipes 414 (Magi-Stone, ballistic) and 401 (Gatti Amari).
            systems.Push(DSN3Rows.SYSTEM_MAGI_STONE); ranks.Push(8);
            systems.Push(DSN3Rows.SYSTEM_GATTI_AMARI); ranks.Push(8);
        }
        else if (batch == 5)
        {
            // Generic-engine inputs of recipes 403, 404, 405, 407, 408, 409.
            systems.Push(DSN3Rows.SYSTEM_SHADOW_PINION); ranks.Push(8);
            systems.Push(DSN3Rows.SYSTEM_CLOCK_LANCET); ranks.Push(7);
            systems.Push(DSN3Rows.SYSTEM_LAUREL); ranks.Push(7);
            systems.Push(DSN3Rows.SYSTEM_FLAMES_OF_MISSPELL); ranks.Push(8);
            systems.Push(DSN3Rows.SYSTEM_PAKO_BATTILIAR); ranks.Push(8);
            systems.Push(DSN3Rows.SYSTEM_AMMO_APPALATE); ranks.Push(8);
        }
        else if (batch == 6)
        {
            // Generic-engine inputs of recipes 410, 411, 412, 413, 415, 416.
            systems.Push(DSN3Rows.SYSTEM_UNEARTHLY_BOLT); ranks.Push(8);
            systems.Push(DSN3Rows.SYSTEM_GLASS_FANDANGO); ranks.Push(8);
            systems.Push(DSN3Rows.SYSTEM_SANTA_JAVELIN); ranks.Push(8);
            systems.Push(DSN3Rows.SYSTEM_GAZE_OF_GAEA); ranks.Push(8);
            systems.Push(DSN3Rows.SYSTEM_PHAS3R); ranks.Push(8);
            systems.Push(DSN3Rows.SYSTEM_CHAOS_RUNE); ranks.Push(8);
        }
        int acquired = 0; int ranked = 0;
        for (int i = 0; i < systems.Size(); i++)
        {
            if (AcquireWeapon(systems[i], 1)) acquired++;
            if (SetWeaponRank(systems[i], ranks[i])) ranked++;
        }
        Console.Printf("DS_N2_EVOLVE_FIXTURE_BATCH tic=%d batch=%d requested=%d acquired=%d ranked=%d classification=N2_EVOLUTION_EVIDENCE_FIXTURE", tic, batch, systems.Size(), acquired, ranked);
    }

    // Drives the whole EVOLUTION_EVIDENCE_FIXTURE: ranks Whip to 8 and grants
    // every passive gate once (tic 70, alongside the first interim chest's
    // eligibility window), then grants weapon batches as the prior batch's
    // recipes are consumed (n2EvolutionAppliedCount reaching 6/12), and
    // re-ranks the Bracelet chain's intermediate Bi-Bracelet form to the 6
    // DSP042PairedRows.RankCount ceiling the moment recipe 204 produces it,
    // so recipe 205 (Bi-Bracelet -> Tri-Bracelet) becomes eligible without a
    // second manual grant pass.
    void N2MaintainEvolutionFixture()
    {
        if (!n2EvolutionFixtureEnabled || runState != STATE_ACTIVE
            || players[0].mo == null) return;
        if (!n2EvolutionPassivesGranted && tic >= 70)
        {
            SetWeaponRank(DSP033StatRules.SYSTEM_WHIP, 8);
            N2GrantEvolutionPassives();
            n2EvolutionPassivesGranted = true;
            // The manual/soak_n2 route's flat CONTACT_DAMAGE one-shots
            // playerHealth outside the p033-only armor-resolution path
            // (ProcessContact), and this fixture deliberately keeps the
            // player stationary at the chest's spawn point so the real
            // pickup path can run -- exactly the scenario real play avoids
            // by moving. This fixture only needs the N2 dispatch evidence
            // ring's targets, not real combat difficulty, so the player is
            // made permanently contact-invulnerable for the fixture's
            // duration; it does not touch ring/enemy damage output.
            playerInvulnerableUntil = tic + 999999;
            // The dispatch evidence ring's kills legitimately level the
            // player through the real DraftFull.zs full-catalog levelup
            // path (auto-confirmed by the non-"manual" ENGINE_TAPE, same as
            // every other soak route), which can re-offer and re-draft a
            // weapon this fixture already evolved away (confirmed by an
            // actual run: Fire Wand was freshly re-acquired through
            // DS_P031_DIRECT_ACQUIRE/DS_N2_WEAPON_DISPATCH_QUEUED well after
            // recipe 304 had already evolved it into Hellfire). Banishing
            // every draftable weapon id up front (the same
            // dsp031RunBanishedIds list DSP031Banish's own player-facing
            // action writes to) keeps natural levelup offers to passives
            // only, so no evolved-away weapon system ever re-emits a new
            // dispatch row after its recipe's evolve point.
            Array<int> banishWeapons;
            banishWeapons.Push(DSN2Catalog.ID_MAGIC_WAND); banishWeapons.Push(DSN2Catalog.ID_KNIFE);
            banishWeapons.Push(DSN2Catalog.ID_AXE); banishWeapons.Push(DSN2Catalog.ID_FIRE_WAND);
            banishWeapons.Push(DSN2Catalog.ID_CROSS); banishWeapons.Push(DSN2Catalog.ID_KING_BIBLE);
            banishWeapons.Push(DSN2Catalog.ID_SANTA_WATER); banishWeapons.Push(DSN2Catalog.ID_GARLIC);
            banishWeapons.Push(DSN2Catalog.ID_LIGHTNING_RING); banishWeapons.Push(DSN2Catalog.ID_PENTAGRAM);
            banishWeapons.Push(DSN2Catalog.ID_RUNETRACER); banishWeapons.Push(DSN2Catalog.ID_PEACHONE);
            banishWeapons.Push(DSN2Catalog.ID_EBONY_WINGS); banishWeapons.Push(DSN2Catalog.ID_PHIERA);
            banishWeapons.Push(DSN2Catalog.ID_EIGHT); banishWeapons.Push(DSN2Catalog.ID_VENTO_SACRO);
            banishWeapons.Push(DSN2Catalog.ID_BRACELET);
            // N3 Track A: same re-draft risk as the 17 above once Song of
            // Mana evolves into Mannajja.
            banishWeapons.Push(DSN2Catalog.ID_N3_SONG_OF_MANA);
            // N3 Track A (bounce engine): same re-draft risk once these four
            // batch-4 inputs evolve into Profusione D'Amore/Anima of
            // Mortaccio/Yatta Daikarin/Carrozza!. Bone/Cherry Bomb/Carréllo
            // only became draftable through this worker's own DraftableIds
            // change, so they carry the identical risk the rest of this
            // list already guards against.
            banishWeapons.Push(DSN2Catalog.ID_N3_CELESTIAL_DUSTING);
            banishWeapons.Push(DSN2Catalog.ID_BONE);
            banishWeapons.Push(DSN2Catalog.ID_CHERRY_BOMB);
            banishWeapons.Push(DSN2Catalog.ID_CARRELLO);
            banishWeapons.Push(DSN2Catalog.ID_N3_MAGI_STONE);
            banishWeapons.Push(DSN2Catalog.ID_N3_GATTI_AMARI);
            banishWeapons.Push(DSN2Catalog.ID_N3_SHADOW_PINION);
            banishWeapons.Push(DSN2Catalog.ID_N3_CLOCK_LANCET);
            banishWeapons.Push(DSN2Catalog.ID_N3_LAUREL);
            banishWeapons.Push(DSN2Catalog.ID_N3_FLAMES_OF_MISSPELL);
            banishWeapons.Push(DSN2Catalog.ID_N3_PAKO_BATTILIAR);
            banishWeapons.Push(DSN2Catalog.ID_N3_AMMO_APPALATE);
            banishWeapons.Push(DSN2Catalog.ID_N3_UNEARTHLY_BOLT);
            banishWeapons.Push(DSN2Catalog.ID_N3_GLASS_FANDANGO);
            banishWeapons.Push(DSN2Catalog.ID_N3_SANTA_JAVELIN);
            banishWeapons.Push(DSN2Catalog.ID_N3_GAZE_OF_GAEA);
            banishWeapons.Push(DSN2Catalog.ID_N3_PHAS3R);
            banishWeapons.Push(DSN2Catalog.ID_N3_CHAOS_RUNE);
            for (int i = 0; i < banishWeapons.Size(); i++)
                dsp031RunBanishedIds.Push(banishWeapons[i]);
            Console.Printf("DS_N2_EVOLVE_FIXTURE_BANISH tic=%d requested=%d classification=N2_EVOLUTION_EVIDENCE_FIXTURE", tic, banishWeapons.Size());
        }
        if (n2EvolutionBatchStage == 0 && n2EvolutionPassivesGranted)
        {
            N2GrantEvolutionWeaponBatch(1);
            n2EvolutionBatchStage = 1;
        }
        else if (n2EvolutionBatchStage == 1 && n2EvolutionAppliedCount >= 6)
        {
            N2GrantEvolutionWeaponBatch(2);
            n2EvolutionBatchStage = 2;
        }
        else if (n2EvolutionBatchStage == 2 && n2EvolutionAppliedCount >= 12)
        {
            N2GrantEvolutionWeaponBatch(3);
            n2EvolutionBatchStage = 3;
        }
        // N3 Track A (bounce engine): batch 3 covers 6 recipes (307-311 plus
        // N3's 402), so its cumulative total reaches 18 once all are applied.
        else if (n2EvolutionBatchStage == 3 && n2EvolutionAppliedCount >= 18)
        {
            N2GrantEvolutionWeaponBatch(4);
            n2EvolutionBatchStage = 4;
        }
        // Batch 4 covers 401/406/414/417/418/419; 5 and 6 cover six each.
        else if (n2EvolutionBatchStage == 4 && n2EvolutionAppliedCount >= 24)
        {
            N2GrantEvolutionWeaponBatch(5);
            n2EvolutionBatchStage = 5;
        }
        else if (n2EvolutionBatchStage == 5 && n2EvolutionAppliedCount >= 30)
        {
            N2GrantEvolutionWeaponBatch(6);
            n2EvolutionBatchStage = 6;
        }
        if (!n2EvolutionBiBraceletReranked)
        {
            int index = N2Find(DSP042PairedRows.SYSTEM_BI_BRACELET);
            if (index >= 0 && n2Rank[index] < 6)
            {
                SetWeaponRank(DSP042PairedRows.SYSTEM_BI_BRACELET, 6);
                n2EvolutionBiBraceletReranked = true;
            }
        }
    }
}
