// P034 shared aimed/facing policy helpers.
// The 320-unit radius and deterministic tie rule are qualified engineering
// approximations in docs/contracts/aimed-directional.md, not source-exact.
mixin class DSP034AimedTargeting
{
    // P024 supplies a broad-phase AABB. This helper applies the declared
    // planar circle boundary and returns a full P020 handle so callers never
    // retain an unversioned target slot across projectile travel.
    bool DSP034SelectNearestTarget(int targetKind, double originX,
        double originY, double maxRange, out int targetSlot,
        out int targetGeneration, out int targetStableId,
        out double distanceSquared)
    {
        targetSlot = -1;
        targetGeneration = 0;
        targetStableId = 0;
        distanceSquared = 0.0;
        if (targetKind <= 0 || maxRange < 0.0) return false;

        double maxRangeSquared = maxRange * maxRange;
        double nearestSquared = maxRangeSquared;
        bool found = false;
        DSP024RadiusCandidates(originX, originY, maxRange);
        for (int i = 0; i < spatialCandidateCount; i++)
        {
            int slot = spatialCandidateSlots[i];
            int generation = spatialCandidateGenerations[i];
            int stableId = spatialCandidateIds[i];
            if (!ValidParts(slot, generation, stableId)
                || kinds[slot] != targetKind) continue;

            double dx = x[slot] - originX;
            double dy = y[slot] - originY;
            double candidateSquared = dx * dx + dy * dy;
            if (candidateSquared > maxRangeSquared) continue;

            bool better = !found || candidateSquared < nearestSquared;
            if (found && candidateSquared == nearestSquared)
            {
                better = stableId < targetStableId
                    || (stableId == targetStableId
                        && (generation < targetGeneration
                            || (generation == targetGeneration
                                && slot < targetSlot)));
            }
            if (!better) continue;

            found = true;
            nearestSquared = candidateSquared;
            targetSlot = slot;
            targetGeneration = generation;
            targetStableId = stableId;
        }

        if (found) distanceSquared = nearestSquared;
        return found;
    }

    // P021/P026 use degrees for planar trigonometry. P034 snapshots the same
    // yaw as integer milli-degrees; pitch is deliberately absent here.
    int DSP034NormalizeYawMilli(int yawMilli)
    {
        int normalized = yawMilli % 360000;
        if (normalized < 0) normalized += 360000;
        return normalized;
    }

    void DSP034FacingDirection(int yawMilli, out double directionX,
        out double directionY)
    {
        double yawDegrees = double(DSP034NormalizeYawMilli(yawMilli)) / 1000.0;
        directionX = cos(yawDegrees);
        directionY = sin(yawDegrees);
    }
}
