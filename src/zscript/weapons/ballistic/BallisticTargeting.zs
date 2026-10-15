// P035 source-plane targeting and launch-direction helpers.
// Geometry and row values are provided by the compiled ballistic table; this
// file owns only deterministic policy, never damage or native projectile use.
mixin class DSP035BallisticTargeting
{
    const DSP035_TARGET_ENEMY = 1;

    Array<int> dsp035TargetCandidateSlots;
    Array<int> dsp035TargetCandidateGenerations;
    Array<int> dsp035TargetCandidateIds;
    int dsp035AttackRng;

    void DSP035ResetTargeting(int seed)
    {
        dsp035TargetCandidateSlots.Clear();
        dsp035TargetCandidateGenerations.Clear();
        dsp035TargetCandidateIds.Clear();
        dsp035AttackRng = seed;
        if (dsp035AttackRng == 0) dsp035AttackRng = 1831565813;
    }

    int DSP035NormalizeYawMilli(int yawMilli)
    {
        int normalized = yawMilli % 360000;
        if (normalized < 0) normalized += 360000;
        return normalized;
    }

    void DSP035YawDirection(int yawMilli, out double directionX,
        out double directionY)
    {
        double yawDegrees = double(DSP035NormalizeYawMilli(yawMilli)) / 1000.0;
        directionX = cos(yawDegrees);
        directionY = sin(yawDegrees);
    }

    int DSP035YawToPoint(double originX, double originY,
        double targetX, double targetY)
    {
        return DSP035NormalizeYawMilli(
            int(atan2(targetY - originY, targetX - originX) * 1000.0));
    }

    int DSP035RadialYawMilli(int childOrdinal, int childCount,
        int rotationYawMilli)
    {
        if (childCount <= 0) return DSP035NormalizeYawMilli(rotationYawMilli);
        double share = 360000.0 * double(childOrdinal) / double(childCount);
        return DSP035NormalizeYawMilli(rotationYawMilli + int(share));
    }

    int DSP035FanYawMilli(int centerYawMilli, int childOrdinal,
        int childCount, int halfSpreadMilli)
    {
        if (childCount <= 1) return DSP035NormalizeYawMilli(centerYawMilli);
        int clampedOrdinal = childOrdinal;
        if (clampedOrdinal < 0) clampedOrdinal = 0;
        if (clampedOrdinal >= childCount) clampedOrdinal = childCount - 1;
        double fraction = double(clampedOrdinal) / double(childCount - 1);
        double offset = -double(halfSpreadMilli)
            + 2.0 * double(halfSpreadMilli) * fraction;
        return DSP035NormalizeYawMilli(centerYawMilli + int(offset));
    }

    // Axe's first child follows the source-plane vertical axis. Later children
    // use a caller-supplied facing-relative fan; all spread values come from
    // the approved adapter fixture, not this policy helper.
    int DSP035AxeChildYawMilli(int childOrdinal, int childCount,
        int viewYawMilli, int halfSpreadMilli)
    {
        if (childOrdinal <= 0) return 90000;
        int spreadOrdinal = childOrdinal - 1;
        int spreadCount = childCount - 1;
        return DSP035FanYawMilli(viewYawMilli, spreadOrdinal,
            spreadCount, halfSpreadMilli);
    }

    bool DSP035TargetPrecedes(int left, int right)
    {
        if (dsp035TargetCandidateIds[left]
            != dsp035TargetCandidateIds[right])
            return dsp035TargetCandidateIds[left]
                < dsp035TargetCandidateIds[right];
        if (dsp035TargetCandidateGenerations[left]
            != dsp035TargetCandidateGenerations[right])
            return dsp035TargetCandidateGenerations[left]
                < dsp035TargetCandidateGenerations[right];
        return dsp035TargetCandidateSlots[left]
            < dsp035TargetCandidateSlots[right];
    }

    void DSP035SwapTargets(int left, int right)
    {
        int temp = dsp035TargetCandidateSlots[left];
        dsp035TargetCandidateSlots[left] = dsp035TargetCandidateSlots[right];
        dsp035TargetCandidateSlots[right] = temp;
        temp = dsp035TargetCandidateGenerations[left];
        dsp035TargetCandidateGenerations[left] = dsp035TargetCandidateGenerations[right];
        dsp035TargetCandidateGenerations[right] = temp;
        temp = dsp035TargetCandidateIds[left];
        dsp035TargetCandidateIds[left] = dsp035TargetCandidateIds[right];
        dsp035TargetCandidateIds[right] = temp;
    }

    // Fire Wand and Hellfire choose one live target once per top-level volley.
    // Stable-handle order followed by an isolated attack-stream draw is an
    // explicit deterministic adapter rule, not a claim about source ordering.
    bool DSP035ChooseRandomLiveTarget(int targetKind, out int targetSlot,
        out int targetGeneration, out int targetStableId,
        out int rngBefore, out int rngAfter)
    {
        targetSlot = -1;
        targetGeneration = 0;
        targetStableId = 0;
        rngBefore = dsp035AttackRng;
        rngAfter = dsp035AttackRng;
        dsp035TargetCandidateSlots.Clear();
        dsp035TargetCandidateGenerations.Clear();
        dsp035TargetCandidateIds.Clear();
        if (targetKind <= 0) return false;

        for (int slot = 0; slot < lifeStates.Size(); slot++)
        {
            if (lifeStates[slot] != STORE_ALIVE || kinds[slot] != targetKind
                || health[slot] <= 0
                || !ValidParts(slot, generations[slot], ids[slot])) continue;
            dsp035TargetCandidateSlots.Push(slot);
            dsp035TargetCandidateGenerations.Push(generations[slot]);
            dsp035TargetCandidateIds.Push(ids[slot]);
        }
        for (int i = 1; i < dsp035TargetCandidateSlots.Size(); i++)
        {
            int j = i;
            while (j > 0 && DSP035TargetPrecedes(j, j - 1))
            {
                DSP035SwapTargets(j, j - 1);
                j--;
            }
        }
        if (dsp035TargetCandidateSlots.Size() == 0) return false;

        dsp035AttackRng = DSP025NextAttackRng(dsp035AttackRng);
        rngAfter = dsp035AttackRng;
        int nonnegativeRandom = dsp035AttackRng & 0x7fffffff;
        int selected = nonnegativeRandom % dsp035TargetCandidateSlots.Size();
        targetSlot = dsp035TargetCandidateSlots[selected];
        targetGeneration = dsp035TargetCandidateGenerations[selected];
        targetStableId = dsp035TargetCandidateIds[selected];
        return ValidParts(targetSlot, targetGeneration, targetStableId)
            && kinds[targetSlot] == targetKind && health[targetSlot] > 0;
    }
}
