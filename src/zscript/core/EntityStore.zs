// P020 stable logical entity record and handle declarations.
// Native actor health and native physics are intentionally absent here.
struct DSP020EntityHandle
{
    int slot;
    int generation;
    int stableId;
}

mixin class DSP020EntityStore
{
    const STORE_EMPTY = 0;
    const STORE_ALIVE = 1;
    const STORE_DESTROYED = 2;

    Array<int> ids;
    Array<int> generations;
    Array<int> lifeStates;
    Array<int> kinds;
    Array<int> health;
    Array<int> owners;
    Array<int> targets;
    Array<int> ownerGenerations;
    Array<int> ownerIds;
    Array<int> targetGenerations;
    Array<int> targetIds;
    Array<int> damageTargets;
    Array<int> dropOwners;
    Array<int> hitHistoryTargets;
    Array<int> statusOwners;
    Array<int> timers;
    Array<double> x;
    Array<double> y;
    Array<double> velocityX;
    Array<double> velocityY;
    // P024 collision shape radius.  This remains logical state; a negative
    // value is an invalid shape and is never admitted to the spatial index.
    Array<double> collisionRadii;
    int nextStableId;
    int clearedReferences;

    void Reset()
    {
        ids.Clear(); generations.Clear(); lifeStates.Clear(); kinds.Clear();
        health.Clear(); owners.Clear(); targets.Clear(); ownerGenerations.Clear();
        ownerIds.Clear(); targetGenerations.Clear(); targetIds.Clear(); x.Clear(); y.Clear();
        damageTargets.Clear(); dropOwners.Clear(); hitHistoryTargets.Clear(); statusOwners.Clear(); timers.Clear();
        velocityX.Clear(); velocityY.Clear();
        collisionRadii.Clear();
        nextStableId = 1;
        clearedReferences = 0;
    }

    void AddSlot()
    {
        ids.Push(0); generations.Push(0); lifeStates.Push(STORE_EMPTY); kinds.Push(0);
        health.Push(0); owners.Push(-1); targets.Push(-1); ownerGenerations.Push(0);
        ownerIds.Push(0); targetGenerations.Push(0); targetIds.Push(0);
        damageTargets.Push(-1); dropOwners.Push(-1); hitHistoryTargets.Push(-1); statusOwners.Push(-1); timers.Push(0);
        x.Push(0.0); y.Push(0.0);
        velocityX.Push(0.0); velocityY.Push(0.0);
        collisionRadii.Push(0.0);
    }

    int Allocate(int kind, double positionX, double positionY,
                 double speedX, double speedY, int initialHealth)
    {
        int slot = -1;
        for (int i = 0; i < lifeStates.Size(); i++)
        {
            if (lifeStates[i] == STORE_EMPTY) { slot = i; break; }
        }
        if (slot < 0) { AddSlot(); slot = lifeStates.Size() - 1; }
        generations[slot]++;
        if (generations[slot] <= 0) generations[slot] = 1;
        ids[slot] = nextStableId++;
        lifeStates[slot] = STORE_ALIVE;
        kinds[slot] = kind;
        health[slot] = initialHealth;
        owners[slot] = -1;
        targets[slot] = -1;
        ownerGenerations[slot] = 0;
        ownerIds[slot] = 0;
        targetGenerations[slot] = 0;
        targetIds[slot] = 0;
        damageTargets[slot] = -1;
        dropOwners[slot] = -1;
        hitHistoryTargets[slot] = -1;
        statusOwners[slot] = -1;
        timers[slot] = 0;
        x[slot] = positionX;
        y[slot] = positionY;
        velocityX[slot] = speedX;
        velocityY[slot] = speedY;
        collisionRadii[slot] = 0.0;
        return slot;
    }

    bool ValidParts(int slot, int generation, int stableId)
    {
        return slot >= 0 && slot < lifeStates.Size() && lifeStates[slot] == STORE_ALIVE
            && generations[slot] == generation && ids[slot] == stableId;
    }

    void ClearReferencesParts(int slot, int generation, int stableId)
    {
        int cleared = 0;
        if (owners[slot] >= 0) { owners[slot] = -1; ownerGenerations[slot] = 0; ownerIds[slot] = 0; cleared++; }
        if (targets[slot] >= 0) { targets[slot] = -1; targetGenerations[slot] = 0; targetIds[slot] = 0; cleared++; }
        if (damageTargets[slot] >= 0) { damageTargets[slot] = -1; cleared++; }
        if (dropOwners[slot] >= 0) { dropOwners[slot] = -1; cleared++; }
        if (hitHistoryTargets[slot] >= 0) { hitHistoryTargets[slot] = -1; cleared++; }
        if (statusOwners[slot] >= 0) { statusOwners[slot] = -1; cleared++; }
        for (int i = 0; i < owners.Size(); i++)
        {
            if (owners[i] == slot && ownerGenerations[i] == generation && ownerIds[i] == stableId)
            { owners[i] = -1; ownerGenerations[i] = 0; ownerIds[i] = 0; cleared++; }
            if (targets[i] == slot && targetGenerations[i] == generation && targetIds[i] == stableId)
            { targets[i] = -1; targetGenerations[i] = 0; targetIds[i] = 0; cleared++; }
            if (damageTargets[i] == slot) { damageTargets[i] = -1; cleared++; }
            if (dropOwners[i] == slot) { dropOwners[i] = -1; cleared++; }
            if (hitHistoryTargets[i] == slot) { hitHistoryTargets[i] = -1; cleared++; }
            if (statusOwners[i] == slot) { statusOwners[i] = -1; cleared++; }
        }
        owners[slot] = -1;
        targets[slot] = -1;
        ownerGenerations[slot] = 0;
        ownerIds[slot] = 0;
        targetGenerations[slot] = 0;
        targetIds[slot] = 0;
        clearedReferences += cleared;
    }

    void AssignTarget(int sourceSlot, int targetSlot)
    {
        targets[sourceSlot] = targetSlot;
        targetGenerations[sourceSlot] = generations[targetSlot];
        targetIds[sourceSlot] = ids[targetSlot];
    }

    void AssignOwner(int sourceSlot, int ownerSlot)
    {
        owners[sourceSlot] = ownerSlot;
        ownerGenerations[sourceSlot] = generations[ownerSlot];
        ownerIds[sourceSlot] = ids[ownerSlot];
    }

    bool TargetStillValid(int sourceSlot)
    {
        return targets[sourceSlot] >= 0
            && ValidParts(targets[sourceSlot], targetGenerations[sourceSlot], targetIds[sourceSlot]);
    }

    bool DestroyParts(int slot, int generation, int stableId)
    {
        if (!ValidParts(slot, generation, stableId)) return false;
        ClearReferencesParts(slot, generation, stableId);
        lifeStates[slot] = STORE_DESTROYED;
        // A destroyed slot is immediately reusable, but its generation and
        // stable ID remain evidence for stale-handle checks until reuse.
        lifeStates[slot] = STORE_EMPTY;
        return true;
    }
}
