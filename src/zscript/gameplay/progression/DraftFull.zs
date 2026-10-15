// P031 additive inventory and full-draft authority.
//
// The default selectable catalog remains the qualified P028 development
// subset. P033 opts in to two passive rows with ranked source records; that
// still does not imply a complete source catalog.
mixin class DSP031InventoryDraftAuthority
{
    const DSP031_CATEGORY_WEAPON = 1;
    const DSP031_CATEGORY_PASSIVE = 2;
    const DSP031_ROUTE_STARTER = 1;
    const DSP031_ROUTE_LEVELUP = 2;
    const DSP031_ROUTE_STAGE = 3;
    const DSP031_ID_FALLBACK_GOLD = 990;
    const DSP031_ID_FALLBACK_CHICKEN = 991;
    const DSP031_ID_TEST_FOURTH = 4;
    const DSP031_ID_HOLLOW_HEART = 5;
    const DSP031_ID_EMPTY_TOME = 7;
    const DSP031_MAX_ORDINARY_SLOTS = 6;
    const DSP031_MAX_OFFERS = 4;

    // The original three identities stay available in all P031 routes.
    // Hollow Heart and Empty Tome are P033 opt-in passives only.
    Array<int> dsp031ItemIds;
    Array<int> dsp031ItemRanks;
    Array<int> dsp031ItemCategories;
    Array<int> dsp031ItemRoutes;
    Array<int> dsp031ItemExtraSlots;
    Array<int> dsp031RunBanishedIds;
    Array<int> dsp031OfferIds;
    Array<int> dsp031DraftLevels;
    // Candybox / Arma Dio gift: the queued draft at this index only offers
    // weapons (kind 1) or passives (kind 2).
    int dsp031PreservePct;   // Preserve PowerUp: chance a used Reroll/Skip/Banish is kept
    int dsp031PreserveRng;
    int dsp031GiftDraft;
    int dsp031GiftKind;
    Array<int> dsp031AppliedTokens;
    Array<int> dsp031ActionIds;

    int dsp031DraftRng;
    int dsp031DraftDraws;
    int dsp031AppliedDrafts;
    int dsp031OfferTargetLevel;
    int dsp031LastActionId;
    int dsp031RunStarted;
    int dsp031RunSealMask;
    int dsp031ProfileSealMask;
    int dsp031ProfileSealCapacity;
    int dsp031ProfileLoaded;
    int dsp031RerollsRemaining;
    int dsp031SkipsRemaining;
    int dsp031BanishesRemaining;
    int dsp031RerollsUsed;
    int dsp031SkipsUsed;
    int dsp031BanishesUsed;
    int dsp031LuckMilli;
    int dsp031FixtureFourthCandidate;
    int dsp031FixtureWeaponSlots;
    int dsp031FixturePassiveSlots;
    int dsp031ExtraWeaponSlots;
    int dsp031ExtraPassiveSlots;
    int dsp031OfferCount;
    int dsp031GoldApproxMilli;
    int dsp031ChickenApproxMilli;
    int dsp031LastAppliedToken;
    bool dsp031P033PassivesEnabled;

    // N2 full-catalog generalization (docs/contracts/normal-play-integration.md).
    // When set, Implemented/Category/MaxRank/RarityWeight/Name delegate to
    // DSN2Catalog and every offer/eligibility loop enumerates the catalog's
    // explicit id list instead of a contiguous range, removing the ID
    // ceiling the P031 bitmask design carried. Existing P031/P033 fixture
    // behaviour (flag unset) is untouched by every branch below.
    bool dsp031FullCatalogEnabled;
    // Seals for catalog ids outside the legacy DSP031AllowedSealMask() bit
    // range (ids can exceed 31 here, so no shifting is used). This is a
    // separate, run-scope-only structure: it does not touch the persisted
    // "ds_p031_profile_seals" CVar or its byte-identical mask/hash format.
    Array<int> dsp031FullSealedIds;
    // Items not yet unlocked in the profile (manual play only; SliceMeta.zs).
    Array<int> dsp031LockedIds;
    int dsp031WeaponCap;   // Mindbender's maximum weapons (6 = normal)

    void DSP031SetP033PassivesEnabled(bool enabled)
    {
        dsp031P033PassivesEnabled = enabled;
    }

    void DSP031SetFullCatalogEnabled(bool enabled)
    {
        dsp031FullCatalogEnabled = enabled;
        Console.Printf("DS_N2_FULL_CATALOG_ENABLED value=%d", enabled);
    }

    int DSP031CatalogMaxId()
    {
        return dsp031P033PassivesEnabled ? DSP031_ID_EMPTY_TOME : DSP031_ID_TEST_FOURTH;
    }

    // Replaces the contiguous DSP028_ID_WHIP..DSP031CatalogMaxId() range with
    // the catalog's explicit draftable id list once full-catalog mode is on,
    // so ids above the legacy small range are still considered.
    void DSP031CandidateUniverse(out Array<int> ids)
    {
        ids.Clear();
        // Super Candybox II Turbo's pick: evolutions made in earlier runs and not
        // owned now (no middle stages, morphs, gifts, Corridor, Shroud, Ashes).
        if (dsp031FullCatalogEnabled && dsp031GiftKind == 3 && dsp031GiftDraft >= 0 && dsp031AppliedDrafts == dsp031GiftDraft)
        {
            Array<String> mk; Array<int> mv;
            DSMeta.Load(mk, mv);
            for (int e = 0; e < DSAchievementData.EVOLUTIONS.Size(); e++)
            {
                int evo = DSAchievementData.EVOLUTIONS[e];
                if (DSP031OwnedIndex(evo) < 0 && DSMeta.Val(mk, mv, String.Format("seen:%d", evo)) > 0) ids.Push(evo);
            }
            return;
        }
        if (dsp031FullCatalogEnabled)
        {
            DSN2Catalog.DraftableIds(ids);
            for (int i = ids.Size() - 1; i >= 0; i--)
                if (dsp031LockedIds.Find(ids[i]) != dsp031LockedIds.Size() && DSP031OwnedIndex(ids[i]) < 0)
                    ids.Delete(i);
            return;
        }
        for (int id = DSP028_ID_WHIP; id <= DSP031CatalogMaxId(); id++) ids.Push(id);
    }

    bool DSP031PreserveRoll()
    {
        if (dsp031PreservePct <= 0) return false;
        dsp031PreserveRng = dsp031PreserveRng * 1664525 + 1013904223;
        return ((dsp031PreserveRng >>> 16) % 100) < dsp031PreservePct;
    }

    int DSP031Min(int left, int right) { return left < right ? left : right; }
    int DSP031Max(int left, int right) { return left > right ? left : right; }

    int DSP031PositiveMod(int value, int divisor)
    {
        if (divisor <= 0) return 0;
        int result = value % divisor;
        return result < 0 ? result + divisor : result;
    }

    int DSP031NextRng(int state)
    {
        int next = state;
        next = next ^ (next << 13);
        next = next ^ (next >> 17);
        next = next ^ (next << 5);
        if (next == 0) next = 1831565813;
        return next;
    }

    bool DSP031ArrayHas(Array<int> values, int wanted)
    {
        for (int i = 0; i < values.Size(); i++)
            if (values[i] == wanted) return true;
        return false;
    }

    int DSP031OwnedIndex(int id)
    {
        for (int i = 0; i < dsp031ItemIds.Size(); i++)
            if (dsp031ItemIds[i] == id) return i;
        return -1;
    }

    bool DSP031Implemented(int id)
    {
        if (dsp031FullCatalogEnabled) return DSN2Catalog.IsKnown(id);
        return id == DSP028_ID_WHIP || id == DSP028_ID_POWER || id == DSP028_ID_ARMOR
            || (dsp031P033PassivesEnabled
                && (id == DSP031_ID_HOLLOW_HEART || id == DSP031_ID_EMPTY_TOME));
    }

    bool DSP031Selectable(int id)
    {
        return DSP031Implemented(id) || (id == DSP031_ID_TEST_FOURTH && dsp031FixtureFourthCandidate != 0);
    }

    int DSP031Category(int id)
    {
        if (dsp031FullCatalogEnabled) return DSN2Catalog.Category(id);
        return id == DSP028_ID_WHIP ? DSP031_CATEGORY_WEAPON : DSP031_CATEGORY_PASSIVE;
    }

    int DSP031MaxRank(int id)
    {
        if (dsp031FullCatalogEnabled) return DSN2Catalog.MaxRank(id);
        if (id == DSP028_ID_WHIP) return DSP028_MAX_RANK;
        if (id == DSP028_ID_POWER || id == DSP028_ID_ARMOR
            || id == DSP031_ID_HOLLOW_HEART || id == DSP031_ID_EMPTY_TOME)
            return DSP028_MAX_PASSIVE_RANK;
        if (id == DSP031_ID_TEST_FOURTH && dsp031FixtureFourthCandidate != 0) return 1;
        return 0;
    }

    int DSP031Rank(int id)
    {
        int index = DSP031OwnedIndex(id);
        return index < 0 ? 0 : dsp031ItemRanks[index];
    }

    bool DSP031SyncLegacyStats()
    {
        int mightMilli;
        int armorPoints;
        int maxHealthMilli;
        int cooldownMultiplierMilli;
        int rankHash;
        int spinach = DSP031Rank(DSP028_ID_POWER);
        int armor = DSP031Rank(DSP028_ID_ARMOR);
        int hollowHeart = dsp031P033PassivesEnabled ? DSP031Rank(DSP031_ID_HOLLOW_HEART) : 0;
        int emptyTome = dsp031P033PassivesEnabled ? DSP031Rank(DSP031_ID_EMPTY_TOME) : 0;
        if (!DSP033StatRules.Resolve(1000, 1, 120000, 1000,
                spinach, armor, hollowHeart, emptyTome, mightMilli,
                armorPoints, maxHealthMilli, cooldownMultiplierMilli,
                rankHash))
        {
            Console.Printf("DS_P031_STATS_SYNC accepted=0 reason=INVALID_RANKS spinach=%d armor=%d hollow_heart=%d empty_tome=%d", spinach, armor, hollowHeart, emptyTome);
            return false;
        }
        powerRank = spinach;
        armorRank = armor;
        characterMightMilli = mightMilli;
        characterArmor = armorPoints;
        characterMaxHealth = DSP033StatRules.DisplayHealthRounded(maxHealthMilli);
        Console.Printf("DS_P031_STATS_SYNC accepted=1 rank_hash=%d spinach=%d armor_rank=%d hollow_heart=%d empty_tome=%d might_milli=%d armor=%d max_health_milli=%d cooldown_multiplier_milli=%d", rankHash, spinach, armor, hollowHeart, emptyTome, mightMilli, armorPoints, maxHealthMilli, cooldownMultiplierMilli);
        return true;
    }

    int DSP031OrdinaryCount(int category)
    {
        int count = category == DSP031_CATEGORY_WEAPON ? dsp031FixtureWeaponSlots : dsp031FixturePassiveSlots;
        for (int i = 0; i < dsp031ItemIds.Size(); i++)
            if (dsp031ItemCategories[i] == category && dsp031ItemExtraSlots[i] == 0) count++;
        return count;
    }

    int DSP031ExtraCount(int category)
    {
        int count = 0;
        for (int i = 0; i < dsp031ItemIds.Size(); i++)
            if (dsp031ItemCategories[i] == category && dsp031ItemExtraSlots[i] != 0) count++;
        return count;
    }

    int DSP031ProfileHash(int mask, int capacity)
    {
        return 31023 + mask * 37 + capacity * 13;
    }

    int DSP031AllowedSealMask()
    {
        int mask = (1 << (DSP028_ID_WHIP - 1))
            | (1 << (DSP028_ID_POWER - 1))
            | (1 << (DSP028_ID_ARMOR - 1));
        if (dsp031P033PassivesEnabled)
            mask |= (1 << (DSP031_ID_HOLLOW_HEART - 1))
                | (1 << (DSP031_ID_EMPTY_TOME - 1));
        return mask;
    }

    int DSP031MaxSealCapacity()
    {
        return dsp031P033PassivesEnabled ? 5 : 3;
    }

    int DSP031SealBit(int id)
    {
        if (!DSP031Implemented(id)) return 0;
        return 1 << (id - 1);
    }

    int DSP031BitCount(int value)
    {
        int count = 0;
        for (int i = 0; i < 7; i++) if ((value & (1 << i)) != 0) count++;
        return count;
    }

    bool DSP031LoadSealProfile()
    {
        CVar capacityCVar = CVar.FindCVar("ds_p031_seal_capacity");
        int capacity = capacityCVar != null ? capacityCVar.GetInt() : 0;
        if (capacity < 0 || capacity > DSP031MaxSealCapacity()) capacity = 0;
        CVar profile = CVar.FindCVar("ds_p031_profile_seals");
        String payload = profile != null ? profile.GetString() : "";
        int mask = 0;
        if (payload.Length() > 0)
        {
            Array<String> parts;
            payload.Split(parts, ";");
            if (parts.Size() != 4 || parts[0] != "v1"
                || parts[1].IndexOf("mask=") != 0
                || parts[2].IndexOf("capacity=") != 0
                || parts[3].IndexOf("hash=") != 0)
            {
                Console.Printf("DS_P031_SEAL_PROFILE accepted=0 reason=MALFORMED safe_mask=0");
                dsp031ProfileSealMask = 0; dsp031ProfileSealCapacity = capacity;
                dsp031RunSealMask = 0; dsp031ProfileLoaded = 1;
                return false;
            }
            String maskText = parts[1].Mid(5);
            String capacityText = parts[2].Mid(9);
            String hashText = parts[3].Mid(5);
            mask = maskText.ToInt();
            int storedCapacity = capacityText.ToInt();
            int storedHash = hashText.ToInt();
            if (maskText != String.Format("%d", mask)
                || capacityText != String.Format("%d", storedCapacity)
                || hashText != String.Format("%d", storedHash)
                || mask < 0 || (mask & ~DSP031AllowedSealMask()) != 0
                || storedCapacity != capacity
                || storedHash != DSP031ProfileHash(mask, capacity)
                || DSP031BitCount(mask) > capacity)
            {
                Console.Printf("DS_P031_SEAL_PROFILE accepted=0 reason=SCHEMA_CAPACITY_OR_HASH_MISMATCH safe_mask=0");
                dsp031ProfileSealMask = 0; dsp031ProfileSealCapacity = capacity;
                dsp031RunSealMask = 0; dsp031ProfileLoaded = 1;
                return false;
            }
        }
        dsp031ProfileSealMask = mask;
        dsp031ProfileSealCapacity = capacity;
        dsp031RunSealMask = mask;
        dsp031ProfileLoaded = 1;
        Console.Printf("DS_P031_SEAL_PROFILE accepted=1 mask=%d capacity=%d provenance=PROFILE_CVAR", mask, capacity);
        return true;
    }

    bool DSP031SetSealed(int id, bool shouldSeal)
    {
        int bit = DSP031SealBit(id);
        if (dsp031RunStarted != 0 || bit == 0 || dsp031ProfileLoaded == 0)
        {
            Console.Printf("DS_P031_SEAL_EDIT accepted=0 item=%d reason=NOT_PRE_RUN_OR_UNKNOWN", id);
            return false;
        }
        int nextMask = shouldSeal ? (dsp031ProfileSealMask | bit) : (dsp031ProfileSealMask & ~bit);
        if (DSP031BitCount(nextMask) > dsp031ProfileSealCapacity)
        {
            Console.Printf("DS_P031_SEAL_EDIT accepted=0 item=%d reason=CAPACITY", id);
            return false;
        }
        CVar profile = CVar.FindCVar("ds_p031_profile_seals");
        if (profile == null) return false;
        String previous = profile.GetString();
        String next = String.Format("v1;mask=%d;capacity=%d;hash=%d", nextMask,
            dsp031ProfileSealCapacity, DSP031ProfileHash(nextMask, dsp031ProfileSealCapacity));
        profile.SetString(next);
        if (!CVar.SaveConfig())
        {
            profile.SetString(previous);
            Console.Printf("DS_P031_SEAL_EDIT accepted=0 item=%d reason=PROFILE_WRITE_FAILED", id);
            return false;
        }
        dsp031ProfileSealMask = nextMask;
        dsp031RunSealMask = nextMask;
        Console.Printf("DS_P031_SEAL_EDIT accepted=1 item=%d sealed=%d mask=%d capacity=%d persistent=1 pre_run=1", id, shouldSeal, nextMask, dsp031ProfileSealCapacity);
        return true;
    }

    bool DSP031IsSealed(int id)
    {
        int bit = DSP031SealBit(id);
        if (bit != 0 && (dsp031RunSealMask & bit) != 0) return true;
        return dsp031FullCatalogEnabled && DSP031ArrayHas(dsp031FullSealedIds, id);
    }

    // N2 run-scope seal toggle for catalog ids outside the legacy 31-bit
    // AllowedSealMask domain. No CVar persistence yet (a documented gap);
    // this only affects the current run's eligibility, matching the scope
    // the frozen contract asks N2 to close (masks -> array storage, no ID
    // ceiling) without touching the profile-seal persistence format.
    bool DSP031SetSealedFull(int id, bool shouldSeal)
    {
        if (!dsp031FullCatalogEnabled || dsp031RunStarted != 0 || !DSN2Catalog.IsKnown(id))
            return false;
        bool already = DSP031ArrayHas(dsp031FullSealedIds, id);
        if (shouldSeal && !already)
        {
            if (dsp031FullSealedIds.Size() >= DSP031MaxSealCapacity()) return false;
            dsp031FullSealedIds.Push(id);
        }
        else if (!shouldSeal && already)
        {
            for (int i = 0; i < dsp031FullSealedIds.Size(); i++)
            {
                if (dsp031FullSealedIds[i] != id) continue;
                for (int j = i; j + 1 < dsp031FullSealedIds.Size(); j++)
                    dsp031FullSealedIds[j] = dsp031FullSealedIds[j + 1];
                dsp031FullSealedIds.Resize(dsp031FullSealedIds.Size() - 1);
                break;
            }
        }
        Console.Printf("DS_N2_SEAL_EDIT item=%d sealed=%d count=%d no_id_ceiling=1", id, shouldSeal, dsp031FullSealedIds.Size());
        return true;
    }

    void DSP031ResetInventory()
    {
        dsp031ItemIds.Clear(); dsp031ItemRanks.Clear(); dsp031ItemCategories.Clear();
        dsp031ItemRoutes.Clear(); dsp031ItemExtraSlots.Clear(); dsp031RunBanishedIds.Clear();
        dsp031GiftDraft = -1; dsp031GiftKind = 0;
        dsp031OfferIds.Clear(); dsp031DraftLevels.Clear(); dsp031AppliedTokens.Clear(); dsp031ActionIds.Clear();
        dsp031DraftRng = 730201; dsp031DraftDraws = 0; dsp031AppliedDrafts = 0;
        dsp031RunStarted = 0; dsp031RerollsUsed = 0; dsp031SkipsUsed = 0; dsp031BanishesUsed = 0;
        dsp031LuckMilli = 0; dsp031FixtureFourthCandidate = 0; dsp031FixtureWeaponSlots = 0; dsp031FixturePassiveSlots = 0;
        dsp031ExtraWeaponSlots = 0; dsp031ExtraPassiveSlots = 0; dsp031OfferCount = 0;
        dsp031GoldApproxMilli = 0; dsp031ChickenApproxMilli = 0; dsp031LastAppliedToken = -1;
        dsp031OfferTargetLevel = 0; dsp031LastActionId = 0;
        dsp031FullSealedIds.Clear();
    }

    void DSP031StartRun(int seed, int rerolls, int skips, int banishes, int luckMilli)
    {
        DSP031ResetInventory();
        dsp031DraftRng = seed == 0 ? 730201 : seed;
        dsp031RerollsRemaining = rerolls < 0 ? 0 : rerolls;
        dsp031SkipsRemaining = skips < 0 ? 0 : skips;
        dsp031BanishesRemaining = banishes < 0 ? 0 : banishes;
        dsp031LuckMilli = DSP031Min(100000, DSP031Max(0, luckMilli));
        CVar fourthCVar = CVar.FindCVar("ds_p031_test_fourth_candidate");
        dsp031FixtureFourthCandidate = fourthCVar != null && fourthCVar.GetInt() != 0 ? 1 : 0;
        dsp031RunSealMask = dsp031ProfileSealMask;
        dsp031RunStarted = 1;
        // Normal play starts with the chosen character's weapon(s)
        // (Characters.zs); fixture routes keep the Whip.
        int starter = rsActive ? DSCharacters.StartingWeapon(rsCharacter) : DSP028_ID_WHIP;
        if (rsActive && rsCharacter == DSCharacters.RANDOM)
        {
            // Random: any draftable weapon.
            Array<int> pool; Array<int> ids;
            DSN2Catalog.DraftableIds(ids);
            for (int i = 0; i < ids.Size(); i++)
                if (DSN2Catalog.Category(ids[i]) == DSN2Catalog.CATEGORY_WEAPON) pool.Push(ids[i]);
            if (pool.Size() > 0) starter = pool[Random[DSRunSeed](0, pool.Size() - 1)];
        }
        // DSP028ResetProgression pre-arms the Whip; only an actual Whip
        // acquisition (starter or draft) arms it in normal play.
        if (rsActive) { whipRank = 0; inventoryWeaponLevel = 0; }
        DSP031Acquire(starter, DSP031_ROUTE_STARTER, false);
        if (rsActive && DSCharacters.SecondWeapon(rsCharacter) > 0)
            DSP031Acquire(DSCharacters.SecondWeapon(rsCharacter), DSP031_ROUTE_STARTER, false);
        // "Starts with 1 extra level": level 2 with its level-up choice,
        // opened on the first logical tic (VerticalSlice LogicalTic).
        if (rsActive && DSCharacters.ExtraLevel(rsCharacter))
        {
            playerLevel = 2;
            DSP031QueueDraft(2);
        }
        Console.Printf("DS_P031_RUN_START seed=%d rerolls=%d skips=%d banishes=%d luck_milli=%d seal_mask=%d inventory_catalog=RESTRICTED_P028_SUBSET counters_source=EXPLICIT_PROFILE_INPUT", dsp031DraftRng, dsp031RerollsRemaining, dsp031SkipsRemaining, dsp031BanishesRemaining, dsp031LuckMilli, dsp031RunSealMask);
    }

    void DSP031SetFixtureOccupancy(int weaponSlots, int passiveSlots)
    {
        dsp031FixtureWeaponSlots = DSP031Min(DSP031_MAX_ORDINARY_SLOTS, DSP031Max(0, weaponSlots));
        dsp031FixturePassiveSlots = DSP031Min(DSP031_MAX_ORDINARY_SLOTS, DSP031Max(0, passiveSlots));
        Console.Printf("DS_P031_FIXTURE_OCCUPANCY weapon=%d passive=%d source_ids=OMITTED classification=CONTROLLED_TEST_FIXTURE", dsp031FixtureWeaponSlots, dsp031FixturePassiveSlots);
    }

    bool DSP031IsBanished(int id)
    {
        return DSP031ArrayHas(dsp031RunBanishedIds, id);
    }

    bool DSP031Eligible(int id)
    {
        if (!DSP031Selectable(id) || DSP031IsSealed(id) || DSP031IsBanished(id)) return false;
        if (dsp031GiftDraft >= 0 && dsp031AppliedDrafts == dsp031GiftDraft)
        {
            if (id == DSN2Catalog.ID_N3_CANDYBOX || id == DSN2Catalog.ID_N3_ARMA_DIO) return false;
            if (dsp031GiftKind == 3) return DSP031OwnedIndex(id) < 0;   // an evolution, beyond the slot limit
            if (DSP031Category(id) != (dsp031GiftKind == 1 ? DSP031_CATEGORY_WEAPON : DSP031_CATEGORY_PASSIVE)) return false;
        }
        int owned = DSP031OwnedIndex(id);
        if (owned >= 0) return dsp031ItemRanks[owned] < DSP031MaxRank(id);
        int category = DSP031Category(id);
        int cap = category == DSP031_CATEGORY_WEAPON && dsp031WeaponCap > 0 ? dsp031WeaponCap : DSP031_MAX_ORDINARY_SLOTS;
        return DSP031OrdinaryCount(category) < cap;
    }

    bool DSP031HasAnyEligibleUpgrade()
    {
        Array<int> universe;
        DSP031CandidateUniverse(universe);
        for (int i = 0; i < universe.Size(); i++)
            if (DSP031Eligible(universe[i])) return true;
        return false;
    }

    int DSP031RarityWeight(int id)
    {
        if (!DSP031Eligible(id)) return 0;
        // Full-catalog mode reads the original rarities from DSN2Catalog.
        // Owned-item Luck scaling below is a linear approximation.
        int weight = dsp031FullCatalogEnabled ? DSN2Catalog.RarityWeight(id) : 100;
        if (weight <= 0) weight = 100;
        if (DSP031OwnedIndex(id) >= 0 && dsp031LuckMilli > 0)
            weight = (weight * (1000 + dsp031LuckMilli)) / 1000;
        return weight > 0 ? weight : 1;
    }

    String DSP031Name(int id)
    {
        if (dsp031FullCatalogEnabled && DSN2Catalog.IsKnown(id)) return DSN2Catalog.DisplayName(id);
        if (id == DSP028_ID_WHIP) return "WHIP";
        if (id == DSP028_ID_POWER) return "POWER (Spinach)";
        if (id == DSP028_ID_ARMOR) return "ARMOR (Armor)";
        if (id == DSP031_ID_HOLLOW_HEART) return "HOLLOW HEART";
        if (id == DSP031_ID_EMPTY_TOME) return "EMPTY TOME";
        if (id == DSP031_ID_TEST_FOURTH) return "TEST FIXTURE (not source content)";
        if (id == DSP031_ID_FALLBACK_GOLD) return "GOLD (approximation)";
        if (id == DSP031_ID_FALLBACK_CHICKEN) return "FLOOR CHICKEN (approximation)";
        if (DSLimitBreak.IsOffer(id)) return DSLimitBreak.Name(id) .. " " .. DSLimitBreak.StatText(DSLimitBreak.Stat(id));
        return "UNKNOWN";
    }

    int DSP031ThresholdForCurrentLevel(int currentLevel)
    {
        // Community-reported progression: 5 XP to level 2, then +10 per
        // level through 20, +13 through 40, then +16. The reported extra
        // milestone amounts at 20/40 are unavailable, so this sets those
        // extra amounts to zero as an explicit engineering approximation.
        if (currentLevel < 1) return 0;
        if (currentLevel <= 20) return 5000 + (currentLevel - 1) * 10000;
        if (currentLevel <= 40) return 195000 + (currentLevel - 20) * 13000;
        return 455000 + (currentLevel - 40) * 16000;
    }

    int DSP031QueuedCount()
    {
        return dsp031DraftLevels.Size() - dsp031AppliedDrafts;
    }

    int DSP031CurrentDraftLevel()
    {
        return DSP031QueuedCount() > 0 ? dsp031DraftLevels[dsp031AppliedDrafts] : 0;
    }

    bool DSP031OfferContains(int id)
    {
        return DSP031ArrayHas(dsp031OfferIds, id);
    }

    int DSP031SelectWeighted(Array<int> candidateIds, Array<int> weights, Array<int> chosenIds,
        out int rngBefore, out int rngAfter, out int totalWeight, out int roll)
    {
        totalWeight = 0;
        for (int i = 0; i < candidateIds.Size() && i < weights.Size(); i++)
        {
            int id = candidateIds[i];
            if (id <= 0 || DSP031ArrayHas(chosenIds, id) || weights[i] <= 0) continue;
            totalWeight += weights[i];
        }
        if (totalWeight <= 0)
        {
            rngBefore = dsp031DraftRng;
            rngAfter = dsp031DraftRng;
            roll = -1;
            return 0;
        }
        rngBefore = dsp031DraftRng;
        dsp031DraftRng = DSP031NextRng(dsp031DraftRng);
        dsp031DraftDraws++;
        rngAfter = dsp031DraftRng;
        roll = DSP031PositiveMod(dsp031DraftRng, totalWeight);
        int cumulative = 0;
        for (int i = 0; i < candidateIds.Size() && i < weights.Size(); i++)
        {
            int id = candidateIds[i];
            if (id <= 0 || DSP031ArrayHas(chosenIds, id) || weights[i] <= 0) continue;
            cumulative += weights[i];
            if (roll < cumulative) return id;
        }
        return 0;
    }

    bool DSP031RunWeightAudit(int samples)
    {
        if (samples < 100000) return false;
        Array<int> ids; ids.Push(1); ids.Push(2); ids.Push(3);
        Array<int> weights; weights.Push(1); weights.Push(2); weights.Push(4);
        int oldRng = dsp031DraftRng;
        int oldDraws = dsp031DraftDraws;
        int first1 = 0; int first2 = 0; int first3 = 0; int duplicates = 0;
        int firstSeed = 1000001;
        int seedStep = 7919;
        for (int sample = 0; sample < samples; sample++)
        {
            dsp031DraftRng = firstSeed + sample * seedStep;
            dsp031DraftDraws = 0;
            Array<int> chosenIds;
            int firstSelected = 0;
            for (int offer = 0; offer < 3; offer++)
            {
                int before; int after; int total; int roll;
                int selected = DSP031SelectWeighted(ids, weights, chosenIds, before, after, total, roll);
                if (selected == 0) { duplicates++; break; }
                if (DSP031ArrayHas(chosenIds, selected)) duplicates++;
                chosenIds.Push(selected);
                if (offer == 0) firstSelected = selected;
            }
            if (firstSelected == 1) first1++;
            else if (firstSelected == 2) first2++;
            else if (firstSelected == 3) first3++;
            else duplicates++;
        }
        dsp031DraftRng = oldRng;
        dsp031DraftDraws = oldDraws;
        int lastSeed = firstSeed + (samples - 1) * seedStep;
        Console.Printf("DS_P031_WEIGHT_AUDIT samples=%d seeds_distinct=1 seed_first=%d seed_step=%d seed_last=%d weight_1=1 weight_2=2 weight_3=4 first_1=%d first_2=%d first_3=%d duplicates=%d rng_restored=1", samples, firstSeed, seedStep, lastSeed, first1, first2, first3, duplicates);
        return duplicates == 0;
    }

    void DSP031SetFallbackOffers()
    {
        dsp031OfferIds.Clear();
        dsp031OfferIds.Push(DSP031_ID_FALLBACK_GOLD);
        dsp031OfferIds.Push(DSP031_ID_FALLBACK_CHICKEN);
        dsp031OfferCount = 2;
        Console.Printf("DS_P031_FALLBACK_SET ids=GOLD,FLOOR_CHICKEN value_class=ENGINEERING_APPROXIMATION");
    }

    void DSP031GenerateOffers(bool excludeCurrent)
    {
        Array<int> chosenIds;
        if (excludeCurrent)
            for (int i = 0; i < dsp031OfferIds.Size(); i++)
                chosenIds.Push(dsp031OfferIds[i]);
        dsp031OfferIds.Clear(); dsp031OfferCount = 0;
        dsp031OfferTargetLevel = DSP031CurrentDraftLevel();
        Array<int> universe;
        DSP031CandidateUniverse(universe);
        Array<int> candidateIds;
        Array<int> candidateWeights;
        int available = 0;
        for (int u = 0; u < universe.Size(); u++)
        {
            int id = universe[u];
            int weight = DSP031RarityWeight(id);
            if (weight <= 0 || DSP031ArrayHas(chosenIds, id)) continue;
            candidateIds.Push(id); candidateWeights.Push(weight); available++;
        }
        // Three choices are the ordinary offer set. A fourth is allowed only
        // when a fourth legal candidate exists and the provisional Luck roll
        // succeeds; currently it is enabled solely by a labelled test fixture.
        int count = DSP031Min(DSP031_MAX_OFFERS - 1, available);
        if (available > DSP031_MAX_OFFERS - 1 && dsp031LuckMilli > 0)
        {
            int rngBefore = dsp031DraftRng;
            dsp031DraftRng = DSP031NextRng(dsp031DraftRng);
            dsp031DraftDraws++;
            int roll = DSP031PositiveMod(dsp031DraftRng, 1000);
            int chancePerMille = DSP031Min(1000, dsp031LuckMilli);
            if (roll < chancePerMille) count++;
            Console.Printf("DS_P031_FOURTH_CHANCE rng_before=%d rng_after=%d roll=%d chance_per_mille=%d selected=%d provenance=ENGINEERING_APPROXIMATION", rngBefore, dsp031DraftRng, roll, chancePerMille, roll < chancePerMille);
        }
        for (int offer = 0; offer < count; offer++)
        {
            int rngBefore; int rngAfter; int totalWeight; int roll;
            int selected = DSP031SelectWeighted(candidateIds, candidateWeights, chosenIds,
                rngBefore, rngAfter, totalWeight, roll);
            if (selected == 0) break;
            dsp031OfferIds.Push(selected); dsp031OfferCount++;
            chosenIds.Push(selected);
            Console.Printf("DS_P031_WEIGHTED_DRAW offer=%d rng_before=%d rng_after=%d total_weight=%d roll=%d selected=%s without_replacement=1", offer, rngBefore, rngAfter, totalWeight, roll, DSP031Name(selected));
        }
        if (dsp031OfferCount == 0 && lbEnabled && rsActive)
            DSP031GenerateLimitBreakOffers(chosenIds);
        if (dsp031OfferCount == 0)
        {
            DSP031SetFallbackOffers();
        }
        Console.Printf("DS_P031_OFFER_SET count=%d ids=%d,%d,%d,%d rng_draws=%d luck_milli=%d weight_class=ONLINE_REPORTED_EQUAL_100_OWNED_LUCK=ENGINEERING_APPROXIMATION fourth_policy=PROVISIONAL_PER_MILLE", dsp031OfferCount, dsp031OfferCount > 0 ? dsp031OfferIds[0] : 0, dsp031OfferCount > 1 ? dsp031OfferIds[1] : 0, dsp031OfferCount > 2 ? dsp031OfferIds[2] : 0, dsp031OfferCount > 3 ? dsp031OfferIds[3] : 0, dsp031DraftDraws, dsp031LuckMilli);
    }

    // Limit Break: a maxed build gets per-weapon stat offers instead of the
    // Gold/Chicken fallback. Whip has no Speed or Amount (it ignores both).
    bool DSP031LimitBreakAllowed(int system, int stat)
    {
        int i = LbIndex(system);
        // Only the stats the original offers for this weapon.
        if ((DSLimitBreak.StatMask(system) & (1 << stat)) == 0) return false;
        if (i < 0) return true;
        if (stat == DSLimitBreak.STAT_AREA) return lbArea[i] + DSLimitBreak.AREA_STEP <= DSLimitBreak.AREA_CAP;
        if (stat == DSLimitBreak.STAT_SPEED) return lbSpeed[i] + DSLimitBreak.SPEED_STEP <= DSLimitBreak.SPEED_CAP;
        if (stat == DSLimitBreak.STAT_AMOUNT) return lbAmount[i] + DSLimitBreak.AMOUNT_STEP <= DSLimitBreak.AMOUNT_CAP;
        if (stat == DSLimitBreak.STAT_DURATION) return lbDuration[i] + DSLimitBreak.DURATION_STEP <= DSLimitBreak.DURATION_CAP;
        if (stat == DSLimitBreak.STAT_PIERCE) return lbPierce[i] + DSLimitBreak.PIERCE_STEP <= DSLimitBreak.PIERCE_CAP;
        return true;
    }

    void DSP031GenerateLimitBreakOffers(Array<int> chosenIds)
    {
        Array<int> candidateIds;
        Array<int> candidateWeights;
        for (int w = 0; w < lbOwnedSystems.Size(); w++)
        {
            for (int stat = DSLimitBreak.STAT_MIGHT; stat <= DSLimitBreak.STAT_LAST; stat++)
            {
                if (!DSP031LimitBreakAllowed(lbOwnedSystems[w], stat)) continue;
                candidateIds.Push(DSLimitBreak.OfferId(lbOwnedSystems[w], stat));
                candidateWeights.Push(DSLimitBreak.Weight(stat));
            }
        }
        int count = DSP031Min(DSP031_MAX_OFFERS - 1, candidateIds.Size());
        for (int offer = 0; offer < count; offer++)
        {
            int rngBefore; int rngAfter; int totalWeight; int roll;
            int selected = DSP031SelectWeighted(candidateIds, candidateWeights, chosenIds,
                rngBefore, rngAfter, totalWeight, roll);
            if (selected == 0) break;
            dsp031OfferIds.Push(selected); dsp031OfferCount++;
            chosenIds.Push(selected);
        }
    }

    void DSP031ApplyLimitBreak(int id)
    {
        int system = DSLimitBreak.System(id);
        int stat = DSLimitBreak.Stat(id);
        int i = LbIndex(system);
        if (i < 0)
        {
            lbSystems.Push(system); lbMight.Push(0); lbArea.Push(0); lbSpeed.Push(0); lbAmount.Push(0);
            lbDuration.Push(0); lbPierce.Push(0);
            i = lbSystems.Size() - 1;
        }
        if (stat == DSLimitBreak.STAT_MIGHT) lbMight[i] += DSLimitBreak.MIGHT_STEP;
        else if (stat == DSLimitBreak.STAT_AREA) lbArea[i] += DSLimitBreak.AREA_STEP;
        else if (stat == DSLimitBreak.STAT_SPEED) lbSpeed[i] += DSLimitBreak.SPEED_STEP;
        else if (stat == DSLimitBreak.STAT_DURATION) lbDuration[i] += DSLimitBreak.DURATION_STEP;
        else if (stat == DSLimitBreak.STAT_PIERCE) lbPierce[i] += DSLimitBreak.PIERCE_STEP;
        else lbAmount[i] += DSLimitBreak.AMOUNT_STEP;
        Console.Printf("DS_LIMIT_BREAK system=%d stat=%d might=%d area=%d speed=%d amount=%d", system, stat, lbMight[i], lbArea[i], lbSpeed[i], lbAmount[i]);
    }

    void DSP031QueueDraft(int targetLevel)
    {
        bool wasEmpty = DSP031QueuedCount() == 0;
        dsp031DraftLevels.Push(targetLevel);
        Console.Printf("DS_P031_DRAFT_ENQUEUE target_level=%d queue_count=%d applied=%d", targetLevel, DSP031QueuedCount(), dsp031AppliedDrafts);
        if (wasEmpty) DSP031GenerateOffers(false);
    }

    bool DSP031CollectExperience(int amount)
    {
        if (amount <= 0 || experienceCollectedMilliunits > DSP028_MAX_XP - amount
            || experienceMilliunits > DSP028_MAX_XP - amount)
        {
            Console.Printf("DS_P031_XP_REJECT amount=%d reason=NONPOSITIVE_OR_CHECKED_OVERFLOW", amount);
            return false;
        }
        int beforeXp = experienceMilliunits;
        int beforeLevel = playerLevel;
        experienceCollectedMilliunits += amount;
        experienceMilliunits += amount;
        int crossed = 0;
        int threshold = DSP031ThresholdForCurrentLevel(playerLevel);
        while (threshold > 0 && experienceMilliunits >= threshold)
        {
            experienceMilliunits -= threshold;
            playerLevel++;
            crossed++;
            DSP031QueueDraft(playerLevel);
            // Santa Ladonna: 5% of level-ups (a guess) come with a Candybox
            // or Arma Dio gift draft.
            if (rsActive && rsCharacter == DSCharacters.SANTA && dsp031GiftDraft < dsp031AppliedDrafts
                && Random[DSRunSeed](0, 99) < 5)
            {
                dsp031GiftKind = Random[DSRunSeed](1, 2);
                dsp031DraftLevels.Push(playerLevel);
                dsp031GiftDraft = dsp031DraftLevels.Size() - 1;
            }
            threshold = DSP031ThresholdForCurrentLevel(playerLevel);
        }
        { if (!dsQuiet) Console.Printf("DS_P031_XP_COLLECT amount=%d before_xp=%d after_xp=%d before_level=%d after_level=%d crossed=%d remainder_milliunits=%d authority=P031_DRAFT_EXPERIENCE progression=ONLINE_REPORTED milestone_bonus=0_ENGINEERING_APPROXIMATION", amount, beforeXp, experienceMilliunits, beforeLevel, playerLevel, crossed, experienceMilliunits); }
        return true;
    }

    // N2: a ZScript mixin class cannot call another mixin's (or the host
    // actor's own plain) functions directly -- confirmed by an actual
    // UZDoom compile ("Call to unknown function") when this file tried to
    // call AcquireWeapon/SetWeaponRank/DSP033RecomputeRecovery directly.
    // Every existing cross-system call in this codebase instead happens
    // from VerticalSlice.zs's own host class body, which DOES see every
    // mixin. So this mixin only queues the request (n2PendingDispatch*
    // fields declared on the host actor, which mixins CAN read/write, since
    // only function calls are restricted, not field access -- the existing
    // whipRank field writes a few lines above already rely on exactly this);
    // VerticalSlice.zs's N2DrainPendingDispatch(), called once per
    // LogicalTic before ProcessOwnedWeapons, performs the actual dispatch.
    void DSP031RecomputeN2Passives()
    {
        if (!dsp031FullCatalogEnabled) return;
        n2PendingPassiveRecompute = true;
    }

    // N2: routes a drafted/granted catalog weapon through the real weapon
    // dispatcher (VerticalSlice.zs "N2 weapon dispatcher": AcquireWeapon on
    // first grant, SetWeaponRank on every subsequent rank-up), per the
    // frozen contract. Passives never reach the dispatcher (it is weapon-
    // only); Whip is already handled directly by DSP031Acquire above and is
    // skipped here to avoid a redundant queue entry.
    void DSP031ApplyWeaponDispatch(int id, int category, int rank, bool freshAcquire)
    {
        if (!dsp031FullCatalogEnabled || category != DSP031_CATEGORY_WEAPON) return;
        if (id == DSP028_ID_WHIP) return;
        int system = DSN2Catalog.System(id);
        if (system == 0)
        {
            Console.Printf("DS_N2_WEAPON_PENDING_DISPATCH item=%s system=%d rank=%d reason=UNKNOWN_SYSTEM", DSP031Name(id), system, rank);
            return;
        }
        n2PendingSystem.Push(system);
        n2PendingRank.Push(rank);
        n2PendingFresh.Push(freshAcquire ? 1 : 0);
        Console.Printf("DS_N2_WEAPON_DISPATCH_QUEUED item=%s system=%d rank=%d fresh=%d authority=N2_WEAPON_DISPATCHER", DSP031Name(id), system, rank, freshAcquire ? 1 : 0);
    }

    bool DSP031Acquire(int id, int route, bool fixtureStageOccupancy)
    {
        if (!DSP031Selectable(id)) return false;
        int category = DSP031Category(id);
        int index = DSP031OwnedIndex(id);
        if (index >= 0)
        {
            if (dsp031ItemRanks[index] >= DSP031MaxRank(id)) return false;
            dsp031ItemRanks[index]++;
            if (id == DSP028_ID_WHIP) { whipRank = dsp031ItemRanks[index]; inventoryWeaponLevel = whipRank; }
            else if (id == DSP028_ID_POWER) powerRank = dsp031ItemRanks[index];
            else if (id == DSP028_ID_ARMOR) armorRank = dsp031ItemRanks[index];
            if (!DSP031SyncLegacyStats()) return false;
            DSP031RecomputeN2Passives();
            Console.Printf("DS_P031_DIRECT_RANK item=%s rank=%d route=%d sealed=%d banished=%d", DSP031Name(id), dsp031ItemRanks[index], route, DSP031IsSealed(id), DSP031IsBanished(id));
            DSP031ApplyWeaponDispatch(id, category, dsp031ItemRanks[index], false);
            return true;
        }
        int ordinary = DSP031OrdinaryCount(category);
        int extra = route == DSP031_ROUTE_STAGE && ordinary >= DSP031_MAX_ORDINARY_SLOTS;
        if (ordinary >= DSP031_MAX_ORDINARY_SLOTS && !extra) return false;
        dsp031ItemIds.Push(id); dsp031ItemRanks.Push(1); dsp031ItemCategories.Push(category);
        dsp031ItemRoutes.Push(route); dsp031ItemExtraSlots.Push(extra ? 1 : 0);
        if (extra && category == DSP031_CATEGORY_WEAPON) dsp031ExtraWeaponSlots++;
        if (extra && category == DSP031_CATEGORY_PASSIVE) dsp031ExtraPassiveSlots++;
        Console.Printf("DS_P031_DIRECT_ACQUIRE item=%s rank=1 category=%d route=%d ordinary=%d extra=%d sealed=%d banished=%d test_fixture_occupancy=%d", DSP031Name(id), category, route, DSP031OrdinaryCount(category), DSP031ExtraCount(category), DSP031IsSealed(id), DSP031IsBanished(id), fixtureStageOccupancy);
        if (id == DSP028_ID_WHIP) { whipRank = 1; inventoryWeaponLevel = 1; }
        if (!DSP031SyncLegacyStats()) return false;
        DSP031RecomputeN2Passives();
        DSP031ApplyWeaponDispatch(id, category, 1, true);
        return true;
    }

    bool DSP031StageGrant(int id)
    {
        return DSP031Acquire(id, DSP031_ROUTE_STAGE, false);
    }

    int DSP031OfferId(int index)
    {
        return index >= 0 && index < dsp031OfferIds.Size() ? dsp031OfferIds[index] : 0;
    }

    int DSP031OfferRank(int id)
    {
        return DSP031Rank(id) + ((DSP031Selectable(id) && DSP031Eligible(id)) ? 1 : 0);
    }

    bool DSP031RemoveCurrentOffer(int id)
    {
        for (int i = 0; i < dsp031OfferIds.Size(); i++)
        {
            if (dsp031OfferIds[i] != id) continue;
            for (int j = i; j + 1 < dsp031OfferIds.Size(); j++) dsp031OfferIds[j] = dsp031OfferIds[j + 1];
            dsp031OfferIds.Resize(dsp031OfferIds.Size() - 1);
            dsp031OfferCount = dsp031OfferIds.Size();
            return true;
        }
        return false;
    }

    bool DSP031ApplyOffer(int token, int id)
    {
        if (DSP031QueuedCount() <= 0 || token != dsp031AppliedDrafts || !DSP031OfferContains(id))
        {
            Console.Printf("DS_P031_APPLY_REJECT token=%d expected=%d id=%s queue=%d reason=STALE_EMPTY_OR_NOT_OFFERED", token, dsp031AppliedDrafts, DSP031Name(id), DSP031QueuedCount());
            return false;
        }
        if (id == DSP031_ID_FALLBACK_GOLD)
        {
            dsp031GoldApproxMilli += 1000;
            dsp031AppliedTokens.Push(token);
            dsp031LastAppliedToken = token;
            dsp031AppliedDrafts++;
            if (DSP031QueuedCount() > 0) DSP031GenerateOffers(false);
            else { dsp031OfferIds.Clear(); dsp031OfferCount = 0; dsp031OfferTargetLevel = 0; }
            Console.Printf("DS_P031_APPLY fallback=GOLD amount=1 value_class=ENGINEERING_APPROXIMATION queue_remaining=%d", DSP031QueuedCount());
            return true;
        }
        if (DSLimitBreak.IsOffer(id))
        {
            DSP031ApplyLimitBreak(id);
            dsp031AppliedTokens.Push(token);
            dsp031LastAppliedToken = token;
            dsp031AppliedDrafts++;
            if (DSP031QueuedCount() > 0) DSP031GenerateOffers(false);
            else { dsp031OfferIds.Clear(); dsp031OfferCount = 0; dsp031OfferTargetLevel = 0; }
            return true;
        }
        if (id == DSP031_ID_FALLBACK_CHICKEN)
        {
            dsp031ChickenApproxMilli += 1000;
            dsp031AppliedTokens.Push(token);
            dsp031LastAppliedToken = token;
            dsp031AppliedDrafts++;
            if (DSP031QueuedCount() > 0) DSP031GenerateOffers(false);
            else { dsp031OfferIds.Clear(); dsp031OfferCount = 0; dsp031OfferTargetLevel = 0; }
            Console.Printf("DS_P031_APPLY fallback=FLOOR_CHICKEN heal_milli=1000 value_class=ENGINEERING_APPROXIMATION queue_remaining=%d", DSP031QueuedCount());
            return true;
        }
        if (!DSP031Eligible(id)) return false;
        bool giftPick = dsp031GiftKind == 3 && dsp031GiftDraft >= 0 && dsp031AppliedDrafts == dsp031GiftDraft;
        bool granted = DSP031Acquire(id, giftPick ? DSP031_ROUTE_STAGE : DSP031_ROUTE_LEVELUP, false);
        if (!granted) return false;
        if (id == DSP028_ID_WHIP) { whipRank = DSP031Rank(id); inventoryWeaponLevel = whipRank; }
        else if (id == DSP028_ID_POWER) powerRank = DSP031Rank(id);
        else if (id == DSP028_ID_ARMOR) armorRank = DSP031Rank(id);
        if (!DSP031SyncLegacyStats()) return false;
        int completedToken = dsp031AppliedDrafts;
        if (id == DSN2Catalog.ID_N3_CANDYBOX || id == DSN2Catalog.ID_N3_ARMA_DIO)
        {
            dsp031GiftKind = id == DSN2Catalog.ID_N3_CANDYBOX ? 1 : 2;
            dsp031DraftLevels.Push(dsp031DraftLevels[completedToken]);
            dsp031GiftDraft = dsp031DraftLevels.Size() - 1;
            Console.Printf("DS_P031_GIFT_QUEUED item_id=%d kind=%d draft_index=%d classification=ENGINEERING_APPROXIMATION", id, dsp031GiftKind, dsp031GiftDraft);
        }
        dsp031AppliedTokens.Push(completedToken);
        dsp031LastAppliedToken = completedToken;
        dsp031AppliedDrafts++;
        if (DSP031QueuedCount() > 0) DSP031GenerateOffers(false);
        else { dsp031OfferIds.Clear(); dsp031OfferCount = 0; dsp031OfferTargetLevel = 0; }
        Console.Printf("DS_P031_APPLY offer_id=%s rank=%d token=%d queue_remaining=%d whip_rank=%d power_rank=%d armor_rank=%d might_milli=%d armor=%d authority=SHARED_INVENTORY_STATS transaction_once=1", DSP031Name(id), DSP031Rank(id), completedToken, DSP031QueuedCount(), whipRank, powerRank, armorRank, characterMightMilli, characterArmor);
        return true;
    }

    bool DSP031AcceptActionId(int actionId)
    {
        if (actionId <= dsp031LastActionId || DSP031ArrayHas(dsp031ActionIds, actionId)) return false;
        dsp031ActionIds.Push(actionId);
        dsp031LastActionId = actionId;
        return true;
    }

    bool DSP031Reroll(int token, int actionId)
    {
        if (DSP031QueuedCount() <= 0 || token != dsp031AppliedDrafts || dsp031RerollsRemaining <= 0
            || !DSP031HasAnyEligibleUpgrade()
            || !DSP031AcceptActionId(actionId))
        {
            Console.Printf("DS_P031_REROLL accepted=0 token=%d action_id=%d expected=%d charges=%d eligible=%d reason=STALE_EMPTY_NO_CHARGE_MAXED_OR_DUPLICATE", token, actionId, dsp031AppliedDrafts, dsp031RerollsRemaining, DSP031HasAnyEligibleUpgrade());
            return false;
        }
        dsp031RerollsRemaining--; dsp031RerollsUsed++;
        if (DSP031PreserveRoll()) { dsp031RerollsRemaining++; Console.Printf("DS_PRESERVE kind=reroll"); }
        DSP031GenerateOffers(true);
        Console.Printf("DS_P031_REROLL accepted=1 token=%d remaining=%d excluded_discarded=1 queue_unchanged=1", token, dsp031RerollsRemaining);
        return true;
    }

    bool DSP031Skip(int token, int actionId)
    {
        if (DSP031QueuedCount() <= 0 || token != dsp031AppliedDrafts || dsp031SkipsRemaining <= 0
            || !DSP031HasAnyEligibleUpgrade())
        {
            Console.Printf("DS_P031_SKIP accepted=0 token=%d action_id=%d expected=%d charges=%d eligible=%d reason=STALE_EMPTY_NO_CHARGE_MAXED_OR_DUPLICATE", token, actionId, dsp031AppliedDrafts, dsp031SkipsRemaining, DSP031HasAnyEligibleUpgrade());
            return false;
        }
        int target = DSP031CurrentDraftLevel();
        int threshold = DSP031ThresholdForCurrentLevel(playerLevel);
        if (threshold <= 0)
        {
            Console.Printf("DS_P031_SKIP accepted=0 token=%d target_level=%d reason=THRESHOLD_UNRESOLVED", token, target);
            return false;
        }
        int amount = threshold / 5;
        if (experienceCollectedMilliunits > DSP028_MAX_XP - amount || experienceMilliunits > DSP028_MAX_XP - amount)
        {
            Console.Printf("DS_P031_SKIP accepted=0 token=%d reason=XP_OVERFLOW_CHECK", token);
            return false;
        }
        if (!DSP031AcceptActionId(actionId))
        {
            Console.Printf("DS_P031_SKIP accepted=0 token=%d action_id=%d reason=DUPLICATE_OR_STALE_ACTION", token, actionId);
            return false;
        }
        dsp031SkipsRemaining--; dsp031SkipsUsed++;
        if (DSP031PreserveRoll()) { dsp031SkipsRemaining++; Console.Printf("DS_PRESERVE kind=skip"); }
        dsp031AppliedTokens.Push(token); dsp031LastAppliedToken = token; dsp031AppliedDrafts++;
        dsp031OfferIds.Clear(); dsp031OfferCount = 0; dsp031OfferTargetLevel = 0;
        if (DSP031QueuedCount() > 0) DSP031GenerateOffers(false);
        bool xpAccepted = DSP031CollectExperience(amount);
        if (!xpAccepted) { dsp031AppliedDrafts--; dsp031SkipsRemaining++; dsp031SkipsUsed--; dsp031AppliedTokens.Resize(dsp031AppliedTokens.Size() - 1); return false; }
        if (DSP031QueuedCount() > 0 && dsp031OfferTargetLevel != DSP031CurrentDraftLevel()) DSP031GenerateOffers(false);
        else if (DSP031QueuedCount() > 0 && dsp031OfferCount == 0) DSP031GenerateOffers(false);
        else if (DSP031QueuedCount() <= 0) { dsp031OfferIds.Clear(); dsp031OfferCount = 0; dsp031OfferTargetLevel = 0; }
        Console.Printf("DS_P031_SKIP accepted=1 token=%d target_level=%d next_requirement=%d xp=%d xp_percent=20 provenance=ONLINE_REPORTED_AMOUNT_APPROXIMATED rounding=FLOOR queue_remaining=%d remaining=%d", token, target, threshold, amount, DSP031QueuedCount(), dsp031SkipsRemaining);
        return true;
    }

    bool DSP031Banish(int token, int id, int actionId)
    {
        if (DSP031QueuedCount() <= 0 || token != dsp031AppliedDrafts || dsp031BanishesRemaining <= 0
            || !DSP031Selectable(id) || !DSP031Eligible(id) || !DSP031OfferContains(id) || DSP031IsBanished(id)
            || !DSP031AcceptActionId(actionId))
        {
            Console.Printf("DS_P031_BANISH accepted=0 token=%d action_id=%d item=%s expected=%d charges=%d reason=STALE_EMPTY_NO_CHARGE_ILLEGAL_OR_DUPLICATE", token, actionId, DSP031Name(id), dsp031AppliedDrafts, dsp031BanishesRemaining);
            return false;
        }
        dsp031BanishesRemaining--; dsp031BanishesUsed++;
        if (DSP031PreserveRoll()) { dsp031BanishesRemaining++; Console.Printf("DS_PRESERVE kind=banish"); }
        dsp031RunBanishedIds.Push(id);
        DSP031RemoveCurrentOffer(id);
        if (dsp031OfferCount == 0)
        {
            // The last visible offer was removed. Rebuild from the currently
            // legal pool; fallbacks are reserved for a genuinely empty pool.
            DSP031GenerateOffers(false);
        }
        Console.Printf("DS_P031_BANISH accepted=1 token=%d item=%s remaining=%d run_scope=1 menu_open=1 draft_consumed=0 rng_draws=%d residual_policy=REMOVE_SELECTED_REPOPULATE_IF_EMPTY_APPROX", token, DSP031Name(id), dsp031BanishesRemaining, dsp031DraftDraws);
        return true;
    }

    int DSP031StateHash()
    {
        int hash = 216613626;
        hash = hash * 31 + playerLevel; hash = hash * 31 + experienceMilliunits;
        hash = hash * 31 + dsp031DraftRng; hash = hash * 31 + dsp031DraftDraws;
        hash = hash * 31 + dsp031AppliedDrafts; hash = hash * 31 + dsp031RunSealMask;
        hash = hash * 31 + dsp031RerollsRemaining; hash = hash * 31 + dsp031SkipsRemaining;
        hash = hash * 31 + dsp031BanishesRemaining; hash = hash * 31 + dsp031OfferTargetLevel;
        for (int i = 0; i < dsp031ItemIds.Size(); i++)
        {
            hash = hash * 31 + dsp031ItemIds[i]; hash = hash * 31 + dsp031ItemRanks[i];
            hash = hash * 31 + dsp031ItemCategories[i]; hash = hash * 31 + dsp031ItemRoutes[i];
            hash = hash * 31 + dsp031ItemExtraSlots[i];
        }
        for (int i = 0; i < dsp031OfferIds.Size(); i++) hash = hash * 31 + dsp031OfferIds[i];
        for (int i = 0; i < dsp031DraftLevels.Size(); i++) hash = hash * 31 + dsp031DraftLevels[i];
        for (int i = 0; i < dsp031RunBanishedIds.Size(); i++) hash = hash * 31 + dsp031RunBanishedIds[i];
        for (int i = 0; i < dsp031ActionIds.Size(); i++) hash = hash * 31 + dsp031ActionIds[i];
        return hash;
    }
}
