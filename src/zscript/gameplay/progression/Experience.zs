// P027 production experience store.
//
// The store owns logical pickup state.  Native actors are only presentation
// proxies and never participate in pickup eligibility or XP accounting.
mixin class DSP027ExperienceStore
{
    const DSP027_PICKUP_KIND = 27;
    const DSP027_GROUND = 1;
    const DSP027_ATTRACTING = 2;
    const DSP027_COLLECTED = 3;
    const DSP027_REMOVED = 4;
    const DSP027_MERGED = 5;
    const DSP027_MAX_VALUE = 2000000000;

    Array<int> experienceStates;
    Array<int> experienceValues;
    Array<int> experienceBatches;
    int experienceCreated;
    int experienceCollected;
    int experienceRemoved;
    int experienceMerged;
    int experienceCheckedRejects;
    // P040: a distinct removal reason from Pentagram's non-spared-pickup
    // roll. Kept apart from experienceRemoved (the pre-existing explicit
    // teardown reason) so each reason's own counter reconciles independently
    // against evidence, even though both feed the same conservation total.
    int experienceErased;
    // P040: Growth (Crown) bonus XP credited at collection time, tracked
    // separately from experienceCollected so the base/bonus ledger split
    // required by the contract is exact and the pre-P040 conservation
    // equation (created == remaining+collected+removed+erased) never has to
    // account for a value that did not come from any created pickup.
    int experienceGrowthBonusMilli;

    void DSP027ResetExperience()
    {
        experienceStates.Clear();
        experienceValues.Clear();
        experienceBatches.Clear();
        experienceCreated = 0;
        experienceCollected = 0;
        experienceRemoved = 0;
        experienceMerged = 0;
        experienceCheckedRejects = 0;
        experienceErased = 0;
        experienceGrowthBonusMilli = 0;
    }

    void DSP027EnsureExperienceSlot(int slot)
    {
        while (experienceStates.Size() <= slot)
        {
            experienceStates.Push(0);
            experienceValues.Push(0);
            experienceBatches.Push(0);
        }
    }

    bool DSP027CheckedPositiveAdd(int left, int right, out int result)
    {
        if (left < 0 || right <= 0 || left > DSP027_MAX_VALUE - right)
        {
            result = 0;
            experienceCheckedRejects++;
            return false;
        }
        result = left + right;
        return true;
    }

    bool DSP027CheckedAdd(int left, int right, out int result)
    {
        if (left < 0 || right < 0 || left > DSP027_MAX_VALUE - right)
        {
            result = 0;
            experienceCheckedRejects++;
            return false;
        }
        result = left + right;
        return true;
    }

    bool DSP027IsLivePickup(int slot)
    {
        return slot >= 0 && slot < lifeStates.Size()
            && lifeStates[slot] == STORE_ALIVE
            && slot < experienceStates.Size()
            && (experienceStates[slot] == DSP027_GROUND
                || experienceStates[slot] == DSP027_ATTRACTING);
    }

    bool DSP027ValidPickup(int slot, int generation, int stableId)
    {
        return DSP027IsLivePickup(slot)
            && generations[slot] == generation && ids[slot] == stableId;
    }

    int DSP027RemainingValue()
    {
        int total = 0;
        for (int slot = 0; slot < lifeStates.Size(); slot++)
        {
            if (!DSP027IsLivePickup(slot)) continue;
            int next;
            if (!DSP027CheckedAdd(total, experienceValues[slot], next)) return -1;
            total = next;
        }
        return total;
    }

    // created == remaining + collected + removed + erased. experienceErased
    // is 0 on every pre-P040 route, so this stays byte-identical to the
    // original three-term check there.
    bool DSP027LedgerValid()
    {
        int remaining = DSP027RemainingValue();
        int step1;
        int step2;
        int step3;
        if (remaining < 0 || !DSP027CheckedAdd(remaining, experienceCollected, step1)
            || !DSP027CheckedAdd(step1, experienceRemoved, step2)
            || !DSP027CheckedAdd(step2, experienceErased, step3)) return false;
        return experienceCreated == step3;
    }

    bool DSP027CreatePickup(int value, double positionX, double positionY,
                            int batch, out DSP027ExperienceHandle handle)
    {
        handle.slot = -1;
        handle.generation = 0;
        handle.stableId = 0;
        if (value <= 0) { experienceCheckedRejects++; return false; }
        int nextCreated;
        if (!DSP027CheckedPositiveAdd(experienceCreated, value, nextCreated)) return false;
        int slot = Allocate(DSP027_PICKUP_KIND, positionX, positionY, 0.0, 0.0, 1);
        DSP027EnsureExperienceSlot(slot);
        experienceStates[slot] = DSP027_GROUND;
        experienceValues[slot] = value;
        experienceBatches[slot] = batch;
        experienceCreated = nextCreated;
        collisionRadii[slot] = 0.0;
        handle.slot = slot;
        handle.generation = generations[slot];
        handle.stableId = ids[slot];
        return true;
    }

    // Original three-argument collection path, preserved exactly (delegates
    // with growthMilli=0 so a rank-0 Crown route is byte-identical).
    bool DSP027CollectPickup(int slot, int generation, int stableId)
    {
        int baseAmount; int bonusAmount;
        return DSP027CollectPickupWithGrowth(slot, generation, stableId, 0,
            baseAmount, bonusAmount);
    }

    // P040: Growth (Crown) is applied at collection, not at pickup creation,
    // per the contract. baseAmount is the pickup's own created value and is
    // the only amount that feeds experienceCollected/the conservation
    // equation; bonusAmount is tracked separately in
    // experienceGrowthBonusMilli. A checked-multiply overflow or a
    // conservation-add overflow fails the bonus closed (0), never fabricates
    // credit, and never blocks the base collection itself.
    bool DSP027CollectPickupWithGrowth(int slot, int generation, int stableId,
        int growthMilli, out int baseAmount, out int bonusAmount)
    {
        baseAmount = 0; bonusAmount = 0;
        if (!DSP027ValidPickup(slot, generation, stableId)) return false;
        baseAmount = experienceValues[slot];
        int nextCollected;
        if (!DSP027CheckedPositiveAdd(experienceCollected, baseAmount, nextCollected)) return false;
        experienceStates[slot] = DSP027_COLLECTED;
        experienceCollected = nextCollected;
        if (growthMilli > 0 && baseAmount > 0
            && baseAmount <= 2000000000 / growthMilli)
        {
            int scaledBonus = baseAmount * growthMilli / 1000;
            int nextBonus;
            if (scaledBonus > 0 && DSP027CheckedPositiveAdd(
                experienceGrowthBonusMilli, scaledBonus, nextBonus))
            {
                experienceGrowthBonusMilli = nextBonus;
                bonusAmount = scaledBonus;
            }
        }
        return DestroyParts(slot, generation, stableId);
    }

    bool DSP027RemovePickup(int slot, int generation, int stableId)
    {
        if (!DSP027ValidPickup(slot, generation, stableId)) return false;
        int nextRemoved;
        if (!DSP027CheckedPositiveAdd(experienceRemoved, experienceValues[slot], nextRemoved)) return false;
        experienceStates[slot] = DSP027_REMOVED;
        experienceRemoved = nextRemoved;
        return DestroyParts(slot, generation, stableId);
    }

    // P040 Pentagram: a distinct removal reason from an explicit teardown.
    // No collection, no Growth bonus -- this is a spare-roll loss, and value
    // conservation moves the pickup's value into experienceErased instead of
    // experienceCollected/experienceRemoved.
    bool DSP027ErasePickup(int slot, int generation, int stableId)
    {
        if (!DSP027ValidPickup(slot, generation, stableId)) return false;
        int nextErased;
        if (!DSP027CheckedPositiveAdd(experienceErased, experienceValues[slot], nextErased)) return false;
        experienceStates[slot] = DSP027_REMOVED;
        experienceErased = nextErased;
        return DestroyParts(slot, generation, stableId);
    }

    // P040 Gorgeous Moon phase 2: forces a still-grounded pickup into the
    // ordinary ATTRACTING state so it is collected through the existing
    // P027 attraction/collection path -- no new state, no new hash field.
    bool DSP027ForceAttract(int slot, int generation, int stableId)
    {
        if (!DSP027ValidPickup(slot, generation, stableId)) return false;
        if (experienceStates[slot] == DSP027_GROUND)
            experienceStates[slot] = DSP027_ATTRACTING;
        return true;
    }

    bool DSP027MergePickup(int keepSlot, int keepGeneration, int keepId,
                           int mergeSlot, int mergeGeneration, int mergeId,
                           out int mergedValue)
    {
        mergedValue = 0;
        if (!DSP027ValidPickup(keepSlot, keepGeneration, keepId)
            || !DSP027ValidPickup(mergeSlot, mergeGeneration, mergeId)
            || experienceStates[keepSlot] != DSP027_GROUND
            || experienceStates[mergeSlot] != DSP027_GROUND
            || experienceBatches[keepSlot] != experienceBatches[mergeSlot]
            || x[keepSlot] != x[mergeSlot] || y[keepSlot] != y[mergeSlot]) return false;
        int nextValue;
        if (!DSP027CheckedPositiveAdd(experienceValues[keepSlot], experienceValues[mergeSlot], nextValue)) return false;
        experienceValues[keepSlot] = nextValue;
        experienceStates[mergeSlot] = DSP027_MERGED;
        if (!DestroyParts(mergeSlot, mergeGeneration, mergeId)) return false;
        experienceMerged++;
        mergedValue = nextValue;
        return true;
    }

    // Shift the source-plane graph and player together. Handles, values and
    // state remain untouched, so all relative query distances are preserved.
    void DSP027Rebase(double deltaX, double deltaY)
    {
        for (int slot = 0; slot < lifeStates.Size(); slot++)
        {
            if (!DSP027IsLivePickup(slot)) continue;
            x[slot] += deltaX;
            y[slot] += deltaY;
        }
    }
}
