// P032 chest records freeze provenance and transformation permission when the
// source creates the chest. Opening later cannot upgrade a Bronze source.
mixin class DSP032ChestRewardAuthority
{
    const DSP032_CHEST_BRONZE = 1;
    const DSP032_CHEST_SILVER = 2;
    // N2-W6 evolution-evidence fixture: DSP032ChestIds records never shrink
    // (a completed chest stays in the array, only dsp032ChestOpened flips),
    // and the manual/soak_n2 INTERIM_CHEST_CADENCE route spawns one real
    // chest every cadence interval for as long as the run is ACTIVE. 16 was
    // sized for the small P032 unit-fixture chest sequences elsewhere in
    // this file; exercising all 17 evolution recipes (1, 201-205, 301-311)
    // once each through a real chest needs exactly 17 chest records, so the
    // cadence's own N2MaintainChestCadence now also stops spawning further
    // chests once every recipe has applied (see that function), and this
    // cap is raised just enough to cover the 17 needed plus headroom for the
    // one extra rank-up-fallback chest the cadence may open in between.
    // N3 Track A (bounce engine, this worker): raised again from 20 to 26 to
    // cover the four added recipes (406/417/418/419, cap now 22 total) plus
    // headroom -- an actual run at the old cap of 20 showed the cadence's
    // chest-spawn silently stop after the 20th chest record (recipe 406
    // applied, 417/418/419 never even attempted a chest), confirmed by
    // DSP032SpawnChestRecord's own dsp032ChestIds.Size() >= DSP032_MAX_CHESTS
    // guard below. Raised to 48 for the 14 further N3 recipes (36 in the
    // evolution fixture) and for long real runs, which also spawn chests.
    const DSP032_MAX_CHESTS = 48;
    const DSP032_MAX_CHEST_QUEUE = 8;
    const DSP032_MAX_REWARD_SLOTS = 5;
    const DSP032_MAX_APPLIED_REWARDS = 80;

    Array<int> dsp032ChestIds;
    Array<int> dsp032ChestSubtypes;
    Array<int> dsp032ChestStages;
    Array<int> dsp032ChestWaves;
    Array<int> dsp032ChestSourceTics;
    Array<int> dsp032ChestSlotCounts;
    Array<int> dsp032ChestTransformEligible;
    Array<int> dsp032ChestX;
    Array<int> dsp032ChestY;
    Array<int> dsp032ChestRadius;
    Array<int> dsp032ChestClaimed;
    Array<int> dsp032ChestOpened;
    Array<int> dsp032ChestQueue;
    Array<int> dsp032AppliedChestIds;
    Array<int> dsp032AppliedChestSlots;

    int DSP032ChestIndex(int stableId)
    {
        for (int i = 0; i < dsp032ChestIds.Size(); i++)
            if (dsp032ChestIds[i] == stableId) return i;
        return -1;
    }

    void DSP032ResetChests()
    {
        dsp032ChestIds.Clear(); dsp032ChestSubtypes.Clear();
        dsp032ChestStages.Clear(); dsp032ChestWaves.Clear();
        dsp032ChestSourceTics.Clear(); dsp032ChestSlotCounts.Clear();
        dsp032ChestTransformEligible.Clear(); dsp032ChestX.Clear(); dsp032ChestY.Clear();
        dsp032ChestRadius.Clear(); dsp032ChestClaimed.Clear(); dsp032ChestOpened.Clear();
        dsp032ChestQueue.Clear(); dsp032AppliedChestIds.Clear(); dsp032AppliedChestSlots.Clear();
    }

    bool DSP032ChestWasClaimed(int stableId)
    {
        int index = DSP032ChestIndex(stableId);
        return index >= 0 && dsp032ChestClaimed[index] != 0;
    }

    bool DSP032SpawnChestRecord(int stableId, int subtype, int stage, int wave,
        int sourceTic, int rewardSlots, bool sourceAllowsTransformation,
        int x, int y, int pickupRadius)
    {
        if (stableId <= 0 || DSP032ChestIndex(stableId) >= 0
            || dsp032ChestIds.Size() >= DSP032_MAX_CHESTS
            || (subtype != DSP032_CHEST_BRONZE && subtype != DSP032_CHEST_SILVER)
            || stage < 1 || wave < 0 || sourceTic < 0
            || (rewardSlots != 1 && rewardSlots != 3 && rewardSlots != 5)
            || pickupRadius <= 0)
            return false;
        bool frozenEligible = subtype == DSP032_CHEST_SILVER && sourceAllowsTransformation;
        dsp032ChestIds.Push(stableId);
        dsp032ChestSubtypes.Push(subtype);
        dsp032ChestStages.Push(stage);
        dsp032ChestWaves.Push(wave);
        dsp032ChestSourceTics.Push(sourceTic);
        dsp032ChestSlotCounts.Push(rewardSlots);
        dsp032ChestTransformEligible.Push(frozenEligible ? 1 : 0);
        dsp032ChestX.Push(x);
        dsp032ChestY.Push(y);
        dsp032ChestRadius.Push(pickupRadius);
        dsp032ChestClaimed.Push(0);
        dsp032ChestOpened.Push(0);
        Console.Printf("DS_P032_CHEST_SPAWN id=%d subtype=%s stage=%d wave=%d source_tic=%d slots=%d transform_eligible=%d x=%d y=%d radius=%d classification=CONTROLLED_SOURCE_RECORD", stableId, subtype == DSP032_CHEST_SILVER ? "SILVER" : "BRONZE", stage, wave, sourceTic, rewardSlots, frozenEligible ? 1 : 0, x, y, pickupRadius);
        return true;
    }

    int DSP032ChestSubtype(int stableId)
    {
        int index = DSP032ChestIndex(stableId);
        return index < 0 ? 0 : dsp032ChestSubtypes[index];
    }

    int DSP032ChestSlots(int stableId)
    {
        int index = DSP032ChestIndex(stableId);
        return index < 0 ? 0 : dsp032ChestSlotCounts[index];
    }

    bool DSP032ChestAllowsTransformation(int stableId)
    {
        int index = DSP032ChestIndex(stableId);
        return index >= 0 && dsp032ChestTransformEligible[index] != 0;
    }

    bool DSP032ChestWithinPickupRange(int stableId, int playerX, int playerY)
    {
        int index = DSP032ChestIndex(stableId);
        if (index < 0) return false;
        int dx = playerX - dsp032ChestX[index];
        int dy = playerY - dsp032ChestY[index];
        int radius = dsp032ChestRadius[index];
        return dx * dx + dy * dy <= radius * radius;
    }

    int DSP032ChestQueueCount()
    {
        return dsp032ChestQueue.Size();
    }

    bool DSP032PickUpChest(int stableId, int playerX, int playerY)
    {
        int index = DSP032ChestIndex(stableId);
        if (index < 0 || dsp032ChestClaimed[index] != 0
            || dsp032ChestOpened[index] != 0
            || dsp032ChestQueue.Size() >= DSP032_MAX_CHEST_QUEUE
            || !DSP032ChestWithinPickupRange(stableId, playerX, playerY))
        {
            Console.Printf("DS_P032_CHEST_PICKUP accepted=0 id=%d reason=UNKNOWN_ALREADY_CLAIMED_OR_OUT_OF_RANGE", stableId);
            return false;
        }
        dsp032ChestClaimed[index] = 1;
        dsp032ChestQueue.Push(stableId);
        Console.Printf("DS_P032_CHEST_PICKUP accepted=1 id=%d subtype=%s queue=%d facing_independent=1 frozen_transform_eligible=%d slots=%d", stableId, dsp032ChestSubtypes[index] == DSP032_CHEST_SILVER ? "SILVER" : "BRONZE", dsp032ChestQueue.Size(), dsp032ChestTransformEligible[index], dsp032ChestSlotCounts[index]);
        return true;
    }

    int DSP032ActiveChestId()
    {
        return dsp032ChestQueue.Size() > 0 ? dsp032ChestQueue[0] : 0;
    }

    int DSP032AppliedRewardCount(int stableId)
    {
        int count = 0;
        for (int i = 0; i < dsp032AppliedChestIds.Size(); i++)
            if (dsp032AppliedChestIds[i] == stableId) count++;
        return count;
    }

    bool DSP032RewardWasApplied(int stableId, int slotIndex)
    {
        for (int i = 0; i < dsp032AppliedChestIds.Size(); i++)
            if (dsp032AppliedChestIds[i] == stableId
                && dsp032AppliedChestSlots[i] == slotIndex) return true;
        return false;
    }

    bool DSP032CanRecordChestReward(int stableId, int slotIndex, int rewardId)
    {
        int index = DSP032ChestIndex(stableId);
        return index >= 0 && dsp032ChestQueue.Size() > 0
            && dsp032ChestQueue[0] == stableId && slotIndex >= 0
            && slotIndex < dsp032ChestSlotCounts[index] && rewardId > 0
            && !DSP032RewardWasApplied(stableId, slotIndex)
            && slotIndex == DSP032AppliedRewardCount(stableId)
            && dsp032AppliedChestIds.Size() < DSP032_MAX_APPLIED_REWARDS;
    }

    bool DSP032RecordChestReward(int stableId, int slotIndex, int rewardId)
    {
        if (!DSP032CanRecordChestReward(stableId, slotIndex, rewardId))
        {
            Console.Printf("DS_P032_CHEST_REWARD accepted=0 chest=%d slot=%d reward=%d reason=OUT_OF_ORDER_DUPLICATE_OR_NOT_ACTIVE", stableId, slotIndex, rewardId);
            return false;
        }
        int index = DSP032ChestIndex(stableId);
        dsp032AppliedChestIds.Push(stableId);
        dsp032AppliedChestSlots.Push(slotIndex);
        Console.Printf("DS_P032_CHEST_REWARD accepted=1 chest=%d slot=%d total_slots=%d reward=%d transaction_once=1", stableId, slotIndex, dsp032ChestSlotCounts[index], rewardId);
        return true;
    }

    // Ledger-only convenience for fixtures without inventory effects. Gameplay
    // callers must preflight and commit their inventory effect before recording.
    bool DSP032ApplyChestReward(int stableId, int slotIndex, int rewardId)
    {
        return DSP032RecordChestReward(stableId, slotIndex, rewardId);
    }

    bool DSP032CompleteChest(int stableId)
    {
        int index = DSP032ChestIndex(stableId);
        if (index < 0 || dsp032ChestQueue.Size() <= 0 || dsp032ChestQueue[0] != stableId
            || dsp032ChestOpened[index] != 0
            || DSP032AppliedRewardCount(stableId) != dsp032ChestSlotCounts[index])
            return false;
        dsp032ChestOpened[index] = 1;
        dsp032ChestQueue.Delete(0);
        Console.Printf("DS_P032_CHEST_COMPLETE accepted=1 id=%d queue=%d opened_once=1", stableId, dsp032ChestQueue.Size());
        return true;
    }

    int DSP032ChestStateHash()
    {
        int hash = 32018 + dsp032ChestQueue.Size() * 17;
        for (int i = 0; i < dsp032ChestIds.Size(); i++)
            hash = hash * 31 + dsp032ChestIds[i] * 3 + dsp032ChestSubtypes[i] * 5
                + dsp032ChestStages[i] * 7 + dsp032ChestWaves[i] * 11
                + dsp032ChestSourceTics[i] * 13 + dsp032ChestSlotCounts[i] * 17
                + dsp032ChestTransformEligible[i] * 19 + dsp032ChestX[i] * 23
                + dsp032ChestY[i] * 29 + dsp032ChestRadius[i] * 31
                + dsp032ChestClaimed[i] * 37 + dsp032ChestOpened[i] * 41;
        for (int i = 0; i < dsp032ChestQueue.Size(); i++)
            hash = hash * 31 + dsp032ChestQueue[i] * 43;
        for (int i = 0; i < dsp032AppliedChestIds.Size(); i++)
            hash = hash * 31 + dsp032AppliedChestIds[i] * 23 + dsp032AppliedChestSlots[i];
        return hash;
    }
}
