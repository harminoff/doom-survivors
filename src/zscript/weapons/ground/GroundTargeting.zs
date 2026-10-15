// P038 source-plane narrow-phase helpers. P024 provides broad-phase
// candidates; these methods decide logical contact without consulting actors,
// decals, particles, camera pose, or viewport state.
class DSP038GroundMath
{
    static bool CircleContact(double centerX, double centerY,
        double radius, double targetX, double targetY,
        double targetRadius)
    {
        if (radius < 0.0 || targetRadius < 0.0) return false;
        double combined = radius + targetRadius;
        double deltaX = targetX - centerX;
        double deltaY = targetY - centerY;
        return deltaX * deltaX + deltaY * deltaY <= combined * combined;
    }

    // Return the closest point on the closed segment. The fraction is useful
    // for deterministic along-path ordering after P024 supplies candidates.
    static bool SegmentCircleContact(double startX, double startY,
        double endX, double endY, double sweepRadius,
        double targetX, double targetY, double targetRadius,
        out double fraction, out double distanceSquared)
    {
        fraction = 0.0;
        distanceSquared = 0.0;
        if (sweepRadius < 0.0 || targetRadius < 0.0) return false;
        double segmentX = endX - startX;
        double segmentY = endY - startY;
        double segmentLengthSquared = segmentX * segmentX
            + segmentY * segmentY;
        if (segmentLengthSquared > 0.0)
        {
            fraction = ((targetX - startX) * segmentX
                + (targetY - startY) * segmentY) / segmentLengthSquared;
            if (fraction < 0.0) fraction = 0.0;
            else if (fraction > 1.0) fraction = 1.0;
        }
        double closestX = startX + segmentX * fraction;
        double closestY = startY + segmentY * fraction;
        double deltaX = targetX - closestX;
        double deltaY = targetY - closestY;
        distanceSquared = deltaX * deltaX + deltaY * deltaY;
        double combined = sweepRadius + targetRadius;
        return distanceSquared <= combined * combined;
    }

    static bool NearestPrecedes(double candidateDistanceSquared,
        int candidateStableId, double bestDistanceSquared,
        int bestStableId, bool hasBest)
    {
        if (!hasBest) return true;
        return candidateDistanceSquared < bestDistanceSquared
            || (candidateDistanceSquared == bestDistanceSquared
                && candidateStableId < bestStableId);
    }

    static bool CheckedScaleMilli(int sourceValue, int factorMilli,
        out int scaledValue)
    {
        scaledValue = 0;
        if (sourceValue < 0 || factorMilli < 0
            || (factorMilli > 0 && sourceValue > 2000000000 / factorMilli))
            return false;
        scaledValue = sourceValue * factorMilli / 1000;
        return scaledValue >= 0 && scaledValue <= 2000000000;
    }

    // All source milliseconds and fixture delays share the host-provided
    // logical rate. Nearest-tic conversion is deliberately centralized.
    static bool MillisecondsToTicsNearest(int milliseconds,
        int logicalTicsPerSecond, out int logicalTics)
    {
        logicalTics = 0;
        if (milliseconds < 0 || milliseconds > 1000000
            || logicalTicsPerSecond <= 0
            || milliseconds > (2000000000 - 500) / logicalTicsPerSecond)
            return false;
        logicalTics = (milliseconds * logicalTicsPerSecond + 500) / 1000;
        return logicalTics >= 0;
    }
}
