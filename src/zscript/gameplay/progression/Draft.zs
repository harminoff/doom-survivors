// P028 progression and draft authority.
//
// This mixin contains the logical level ledger, queued draft transactions and
// shared inventory/stat state.  It deliberately exposes only the restricted
// development pool frozen for P028; the pool is not a complete source census.
mixin class DSP028LevelUpProgression
{
    const DSP028_MAX_XP = 2000000000;
    const DSP028_MAX_RANK = 8;
    const DSP028_MAX_PASSIVE_RANK = 5;
    const DSP028_ID_WHIP = 1;
    const DSP028_ID_POWER = 2;
    const DSP028_ID_ARMOR = 3;

    int playerLevel;
    int experienceMilliunits;
    int experienceCollectedMilliunits;
    int thresholdCrossings;
    int draftRng;
    int draftApplied;
    int whipRank;
    int powerRank;
    int armorRank;
    int characterMaxHealth;
    int characterArmor;
    int characterMightMilli;
    int inventoryWeaponLevel;

    // N2 weapon-dispatcher pending-request bridge. An actual UZDoom compile
    // proved that symbol visibility for a mixin's own body follows plain
    // top-to-bottom ZSCRIPT #include order across the whole file set (the
    // same reason whipRank right above is visible from DraftFull.zs, which
    // is #included immediately after this file): a field first declared in
    // a file included later (e.g. VerticalSlice.zs) is an "unknown
    // identifier" to a mixin whose own file was included earlier, no matter
    // where in the class body it sits or how the host class's own "mixin
    // X;" lines are ordered. Declaring these fields here instead, in the
    // file immediately before DraftFull.zs, makes them visible to it.
    // DraftFull.zs's DSP031ApplyWeaponDispatch/DSP031RecomputeN2Passives
    // push requests here; DSP030VerticalSlice.N2DrainPendingDispatch()
    // (VerticalSlice.zs) drains the queue once per LogicalTic, before
    // ProcessOwnedWeapons.
    Array<int> n2PendingSystem;
    Array<int> n2PendingRank;
    Array<int> n2PendingFresh;
    bool n2PendingPassiveRecompute;

    Array<int> draftLevels;
    Array<int> draftRotations;
    Array<int> draftRngBefore;
    Array<int> draftRngAfter;

    int DSP028ThresholdForNext(int level)
    {
        if (level == 1) return 5000;
        if (level == 2) return 15000;
        if (level == 3) return 25000;
        return 0;
    }

    int DSP028PositiveMod(int value, int divisor)
    {
        if (divisor <= 0) return 0;
        int result = value % divisor;
        return result < 0 ? result + divisor : result;
    }

    bool DSP028SyncStatMirrors()
    {
        int mightMilli;
        int armorPoints;
        int maxHealthMilli;
        int cooldownMultiplierMilli;
        int rankHash;
        if (!DSP033StatRules.Resolve(1000, 1, 120000, 1000,
                powerRank, armorRank, 0, 0, mightMilli, armorPoints,
                maxHealthMilli, cooldownMultiplierMilli, rankHash))
        {
            Console.Printf("DS_P028_STATS_SYNC accepted=0 reason=INVALID_RANKS power=%d armor=%d", powerRank, armorRank);
            return false;
        }
        characterMightMilli = mightMilli;
        characterArmor = armorPoints;
        characterMaxHealth = DSP033StatRules.DisplayHealthRounded(maxHealthMilli);
        return true;
    }

    int DSP028NextDraftRng(int state)
    {
        int next = state;
        next = next ^ (next << 13);
        next = next ^ (next >> 17);
        next = next ^ (next << 5);
        if (next == 0) next = 1831565813;
        return next;
    }

    void DSP028ResetProgression()
    {
        playerLevel = 1;
        experienceMilliunits = 0;
        experienceCollectedMilliunits = 0;
        thresholdCrossings = 0;
        draftRng = 730201;
        draftApplied = 0;
        whipRank = 1;
        powerRank = 0;
        armorRank = 0;
        // P028 starts the production Antonio survivor at level 1. These are
        // the already-applied starter stats from the shared character seam;
        // the level-up fixture only adds later draft grants.
        characterMaxHealth = 120;
        DSP028SyncStatMirrors();
        inventoryWeaponLevel = 1;
        draftLevels.Clear();
        draftRotations.Clear();
        draftRngBefore.Clear();
        draftRngAfter.Clear();
    }

    int DSP028QueuedCount()
    {
        return draftLevels.Size() - draftApplied;
    }

    int DSP028CurrentDraftLevel()
    {
        return DSP028QueuedCount() > 0 ? draftLevels[draftApplied] : 0;
    }

    int DSP028CurrentDraftRotation()
    {
        return DSP028QueuedCount() > 0 ? draftRotations[draftApplied] : 0;
    }

    int DSP028CurrentOfferCount()
    {
        int count = 0;
        for (int id = DSP028_ID_WHIP; id <= DSP028_ID_ARMOR; id++)
            if (DSP028Eligible(id)) count++;
        return count;
    }

    bool DSP028Eligible(int id)
    {
        if (id == DSP028_ID_WHIP) return whipRank < DSP028_MAX_RANK;
        if (id == DSP028_ID_POWER) return powerRank < DSP028_MAX_PASSIVE_RANK;
        if (id == DSP028_ID_ARMOR) return armorRank < DSP028_MAX_PASSIVE_RANK;
        return false;
    }

    int DSP028OfferId(int offerIndex)
    {
        int count = DSP028CurrentOfferCount();
        if (offerIndex < 0 || offerIndex >= count) return 0;
        int wanted = DSP028PositiveMod(DSP028CurrentDraftRotation() + offerIndex, count);
        int seen = 0;
        for (int id = DSP028_ID_WHIP; id <= DSP028_ID_ARMOR; id++)
        {
            if (!DSP028Eligible(id)) continue;
            if (seen == wanted) return id;
            seen++;
        }
        return 0;
    }

    String DSP028OfferName(int id)
    {
        if (id == DSP028_ID_WHIP) return "WHIP";
        if (id == DSP028_ID_POWER) return "POWER (Spinach)";
        if (id == DSP028_ID_ARMOR) return "ARMOR (Armor)";
        return "ILLEGAL";
    }

    int DSP028OfferRank(int id)
    {
        if (id == DSP028_ID_WHIP) return whipRank + 1;
        if (id == DSP028_ID_POWER) return powerRank + 1;
        if (id == DSP028_ID_ARMOR) return armorRank + 1;
        return 0;
    }

    String DSP028OfferDescription(int id)
    {
        if (id == DSP028_ID_WHIP) return "Increase Whip rank; later slashes use the shared level table.";
        if (id == DSP028_ID_POWER) return "Spinach: +10% Might for each rank.";
        if (id == DSP028_ID_ARMOR) return "Armor: +1 shared Armor point for each rank.";
        return "Unavailable offer.";
    }

    void DSP028QueueDraft(int targetLevel)
    {
        int rngBefore = draftRng;
        int rngAfter = DSP028NextDraftRng(draftRng);
        draftRng = rngAfter;
        int rotation = DSP028PositiveMod(rngAfter, 3);
        draftLevels.Push(targetLevel);
        draftRotations.Push(rotation);
        draftRngBefore.Push(rngBefore);
        draftRngAfter.Push(rngAfter);
        thresholdCrossings++;
        Console.Printf("DS_P028_DRAFT_ENQUEUE queue_index=%d target_level=%d queue_count=%d rng_stream=draft rng_before=%d rng_after=%d rotation=%d draw_once=1", draftLevels.Size() - 1, targetLevel, DSP028QueuedCount(), rngBefore, rngAfter, rotation);
    }

    bool DSP028CollectExperience(int amount)
    {
        if (amount <= 0 || experienceCollectedMilliunits > DSP028_MAX_XP - amount)
        {
            Console.Printf("DS_P028_XP_REJECT amount=%d reason=CHECKED_OVERFLOW authority=P027_EXPERIENCE_LEDGER", amount);
            return false;
        }
        int beforeXp = experienceMilliunits;
        int beforeLevel = playerLevel;
        experienceCollectedMilliunits += amount;
        experienceMilliunits += amount;
        int crossed = 0;
        int threshold = DSP028ThresholdForNext(playerLevel);
        while (threshold > 0 && experienceMilliunits >= threshold)
        {
            experienceMilliunits -= threshold;
            playerLevel++;
            crossed++;
            DSP028QueueDraft(playerLevel);
            threshold = DSP028ThresholdForNext(playerLevel);
        }
        Console.Printf("DS_P028_XP_COLLECT amount=%d before_xp=%d after_xp=%d before_level=%d after_level=%d crossed=%d remainder_milliunits=%d authority=P027_EXPERIENCE_LEDGER", amount, beforeXp, experienceMilliunits, beforeLevel, playerLevel, crossed, experienceMilliunits);
        return true;
    }

    int DSP028WhipDamageForLevel(int level)
    {
        return DSP026WhipRecords.DamageForLevel(level);
    }

    int DSP028WhipAmountForLevel(int level)
    {
        return DSP026WhipRecords.AmountForLevel(level);
    }

    bool DSP028ApplyOffer(int offerIndex, out int id)
    {
        id = DSP028OfferId(offerIndex);
        int targetLevel = DSP028CurrentDraftLevel();
        int offerCount = DSP028CurrentOfferCount();
        if (DSP028QueuedCount() <= 0 || offerIndex < 0 || offerIndex >= offerCount || !DSP028Eligible(id))
        {
            Console.Printf("DS_P028_APPLY_REJECT offer_index=%d offer_id=%s reason=ILLEGAL_OR_EMPTY queue_count=%d", offerIndex, DSP028OfferName(id), DSP028QueuedCount());
            return false;
        }
        int rank = DSP028OfferRank(id);
        if (id == DSP028_ID_WHIP)
        {
            whipRank = rank;
            inventoryWeaponLevel = whipRank;
        }
        else if (id == DSP028_ID_POWER)
        {
            powerRank = rank;
        }
        else if (id == DSP028_ID_ARMOR)
        {
        armorRank = rank;
        }
        DSP028SyncStatMirrors();
        draftApplied++;
        Console.Printf("DS_P028_APPLY offer_index=%d offer_id=%s rank=%d target_level=%d queue_remaining=%d whip_rank=%d power_rank=%d armor_rank=%d weapon_level=%d might_milli=%d armor=%d authority=SHARED_INVENTORY_STATS transaction_once=1", offerIndex, DSP028OfferName(id), rank, targetLevel, DSP028QueuedCount(), whipRank, powerRank, armorRank, inventoryWeaponLevel, characterMightMilli, characterArmor);
        return true;
    }

    bool DSP028ApplyOfferId(int wantedId, out int id)
    {
        id = 0;
        int count = DSP028CurrentOfferCount();
        for (int index = 0; index < count; index++)
        {
            if (DSP028OfferId(index) != wantedId) continue;
            return DSP028ApplyOffer(index, id);
        }
        Console.Printf("DS_P028_APPLY_REJECT offer_id=%s reason=NOT_IN_CURRENT_DRAFT queue_count=%d", DSP028OfferName(wantedId), DSP028QueuedCount());
        return false;
    }
}
