// P037 source-plane orbit math. Weapon rows own numeric policy; this helper
// only projects fixed-point phase and evenly spaced member positions.
class DSP037OrbitMath
{
    // Phase is stored in microradians so the 5 rad/s fixture retains useful
    // precision at the 35 Hz logical clock. Rows express rate in milli-rad/s.
    const PHASE_TURN_MICRORADIANS = 6283185;
    const RADIANS_TO_DEGREES = 57.29577951308232;
    const LOGICAL_COORDINATE_SCALE = 1000;

    static int NormalizePhase(int phaseMicroRadians)
    {
        int phase = phaseMicroRadians % PHASE_TURN_MICRORADIANS;
        if (phase < 0) phase += PHASE_TURN_MICRORADIANS;
        return phase;
    }

    // Carry fractional phase across accepted logical tics. A paused world
    // freezes by not calling this method; phase and remainder are serialized.
    static bool AdvancePhase(int phaseMicroRadians,
        int angularRateMilliRadiansPerSecond, int phaseRemainder,
        int elapsedLogicalTics, int logicalTicsPerSecond,
        out int nextPhaseMicroRadians, out int nextPhaseRemainder)
    {
        nextPhaseMicroRadians = NormalizePhase(phaseMicroRadians);
        nextPhaseRemainder = phaseRemainder;
        if (elapsedLogicalTics < 0 || logicalTicsPerSecond <= 0
            || phaseRemainder <= -logicalTicsPerSecond
            || phaseRemainder >= logicalTicsPerSecond
            || angularRateMilliRadiansPerSecond < -100000
            || angularRateMilliRadiansPerSecond > 100000) return false;

        int rateMicroRadiansPerSecond = angularRateMilliRadiansPerSecond * 1000;
        for (int tic = 0; tic < elapsedLogicalTics; tic++)
        {
            int numerator = rateMicroRadiansPerSecond + nextPhaseRemainder;
            int step = numerator / logicalTicsPerSecond;
            nextPhaseRemainder = numerator % logicalTicsPerSecond;
            nextPhaseMicroRadians = NormalizePhase(nextPhaseMicroRadians
                + step % PHASE_TURN_MICRORADIANS);
        }
        return true;
    }

    static bool MemberPhase(int cohortPhaseMicroRadians,
        int memberOrdinal, int memberCount,
        out int memberPhaseMicroRadians)
    {
        memberPhaseMicroRadians = 0;
        if (memberOrdinal < 0 || memberCount <= 0
            || memberOrdinal >= memberCount) return false;
        int normalized = NormalizePhase(cohortPhaseMicroRadians);
        // The admitted current row cap is small; still bound multiplication so
        // malformed fixture values cannot overflow before division.
        if (memberCount > 200 || memberOrdinal > 200) return false;
        int offset = (PHASE_TURN_MICRORADIANS * memberOrdinal) / memberCount;
        memberPhaseMicroRadians = NormalizePhase(normalized + offset);
        return true;
    }

    static bool OrbitPosition(double anchorX, double anchorY,
        int radiusMilliUnits, int phaseMicroRadians,
        out double positionX, out double positionY)
    {
        positionX = anchorX;
        positionY = anchorY;
        if (radiusMilliUnits < 0) return false;
        double radius = double(radiusMilliUnits)
            / double(LOGICAL_COORDINATE_SCALE);
        double degrees = double(NormalizePhase(phaseMicroRadians))
            * RADIANS_TO_DEGREES / 1000000.0;
        positionX = anchorX + radius * cos(degrees);
        positionY = anchorY + radius * sin(degrees);
        return true;
    }

    static int MaxSweepSubsteps(int phaseDeltaMicroRadians,
        int maxSubstepMilliDegrees)
    {
        if (maxSubstepMilliDegrees <= 0) return 0;
        int absoluteDelta = phaseDeltaMicroRadians < 0
            ? -phaseDeltaMicroRadians : phaseDeltaMicroRadians;
        double deltaDegrees = double(absoluteDelta)
            * RADIANS_TO_DEGREES / 1000000.0;
        double maxDegrees = double(maxSubstepMilliDegrees) / 1000.0;
        int steps = int(ceil(deltaDegrees / maxDegrees));
        return steps < 1 ? 1 : steps;
    }
}
