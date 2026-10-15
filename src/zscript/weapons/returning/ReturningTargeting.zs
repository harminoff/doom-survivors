// P036 nearest-target and locked-heading helpers.
// The flight runtime snapshots a target once; it never homes during flight.
mixin class DSP036ReturningTargeting
{
    const DSP036_TARGET_ENEMY = 1;

    Array<int> dsp036TargetSlots;
    Array<int> dsp036TargetGenerations;
    Array<int> dsp036TargetIds;
    Array<double> dsp036TargetDistanceSquared;
    int dsp036CritRng;

    void DSP036ResetTargeting(int seed)
    {
        dsp036TargetSlots.Clear();
        dsp036TargetGenerations.Clear();
        dsp036TargetIds.Clear();
        dsp036TargetDistanceSquared.Clear();
        dsp036CritRng = seed;
        if (dsp036CritRng == 0) dsp036CritRng = 1831565813;
    }

    int DSP036NormalizeYawMilli(int yawMilli)
    {
        int normalized = yawMilli % 360000;
        if (normalized < 0) normalized += 360000;
        return normalized;
    }

    void DSP036YawDirection(int yawMilli, out double directionX,
        out double directionY)
    {
        double yawDegrees = double(DSP036NormalizeYawMilli(yawMilli)) / 1000.0;
        directionX = cos(yawDegrees);
        directionY = sin(yawDegrees);
    }

    int DSP036YawToPoint(double originX, double originY,
        double targetX, double targetY)
    {
        return DSP036NormalizeYawMilli(
            int(atan2(targetY - originY, targetX - originX) * 1000.0));
    }

    bool DSP036TargetPrecedes(int left, int right)
    {
        if (dsp036TargetDistanceSquared[left]
            != dsp036TargetDistanceSquared[right])
            return dsp036TargetDistanceSquared[left]
                < dsp036TargetDistanceSquared[right];
        if (dsp036TargetIds[left] != dsp036TargetIds[right])
            return dsp036TargetIds[left] < dsp036TargetIds[right];
        if (dsp036TargetGenerations[left]
            != dsp036TargetGenerations[right])
            return dsp036TargetGenerations[left]
                < dsp036TargetGenerations[right];
        return dsp036TargetSlots[left] < dsp036TargetSlots[right];
    }

    void DSP036SwapTargets(int left, int right)
    {
        int value = dsp036TargetSlots[left];
        dsp036TargetSlots[left] = dsp036TargetSlots[right];
        dsp036TargetSlots[right] = value;
        value = dsp036TargetGenerations[left];
        dsp036TargetGenerations[left] = dsp036TargetGenerations[right];
        dsp036TargetGenerations[right] = value;
        value = dsp036TargetIds[left];
        dsp036TargetIds[left] = dsp036TargetIds[right];
        dsp036TargetIds[right] = value;
        double distance = dsp036TargetDistanceSquared[left];
        dsp036TargetDistanceSquared[left] = dsp036TargetDistanceSquared[right];
        dsp036TargetDistanceSquared[right] = distance;
    }

    // Return the nearest live handle in the source-plane budget. Exact equal
    // distances use stable ID, then generation and slot for deterministic ties.
    bool DSP036ChooseClosestTarget(int targetKind, double originX,
        double originY, double rangeUnits, out int targetSlot,
        out int targetGeneration, out int targetStableId,
        out double targetDistanceSquared)
    {
        targetSlot = -1;
        targetGeneration = 0;
        targetStableId = 0;
        targetDistanceSquared = 0.0;
        dsp036TargetSlots.Clear();
        dsp036TargetGenerations.Clear();
        dsp036TargetIds.Clear();
        dsp036TargetDistanceSquared.Clear();
        if (targetKind <= 0 || rangeUnits < 0.0) return false;

        double rangeSquared = rangeUnits * rangeUnits;
        for (int slot = 0; slot < lifeStates.Size(); slot++)
        {
            if (lifeStates[slot] != STORE_ALIVE || kinds[slot] != targetKind
                || health[slot] <= 0
                || !ValidParts(slot, generations[slot], ids[slot])) continue;
            double dx = x[slot] - originX;
            double dy = y[slot] - originY;
            double distanceSquared = dx * dx + dy * dy;
            if (distanceSquared > rangeSquared) continue;
            dsp036TargetSlots.Push(slot);
            dsp036TargetGenerations.Push(generations[slot]);
            dsp036TargetIds.Push(ids[slot]);
            dsp036TargetDistanceSquared.Push(distanceSquared);
        }
        for (int i = 1; i < dsp036TargetSlots.Size(); i++)
        {
            int j = i;
            while (j > 0 && DSP036TargetPrecedes(j, j - 1))
            {
                DSP036SwapTargets(j, j - 1);
                j--;
            }
        }
        if (dsp036TargetSlots.Size() == 0) return false;
        targetSlot = dsp036TargetSlots[0];
        targetGeneration = dsp036TargetGenerations[0];
        targetStableId = dsp036TargetIds[0];
        targetDistanceSquared = dsp036TargetDistanceSquared[0];
        return ValidParts(targetSlot, targetGeneration, targetStableId)
            && kinds[targetSlot] == targetKind && health[targetSlot] > 0;
    }
}
