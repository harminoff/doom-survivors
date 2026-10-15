// Compiled scalar mirror of the canonical P037 orbit JSON rows.
// Source identity/edge facts come from the build-matched census; behavior rows
// are mutable community reports with cutoff applicability unverified.
// Orbit geometry and the selected bounded pool capacity are adapter fixtures.
class DSP037OrbitRows
{
    const SYSTEM_KING_BIBLE = 44;
    const SYSTEM_UNHOLY_VESPERS = 45;

    const DEPENDENCY_DURATION = 1;
    const WALL_BLOCK = 1;
    const WALL_PASS = 2;

    static bool TryGetRankRow(int systemId, int rank,
        out int damageTenths, out int areaMultiplierMilli,
        out int speedMultiplierMilli, out int amount,
        out int activeDurationMilliseconds, out int cooldownMilliseconds,
        out int cooldownStartsAfterDuration, out int reportedPoolMin,
        out int reportedPoolMax, out int fixturePoolCap)
    {
        damageTenths = 0;
        areaMultiplierMilli = 0;
        speedMultiplierMilli = 0;
        amount = 0;
        activeDurationMilliseconds = 0;
        cooldownMilliseconds = 0;
        cooldownStartsAfterDuration = 0;
        reportedPoolMin = 0;
        reportedPoolMax = 0;
        fixturePoolCap = 0;

        if (systemId == SYSTEM_KING_BIBLE)
            return TryGetKingBibleRankRow(rank, damageTenths,
                areaMultiplierMilli, speedMultiplierMilli, amount,
                activeDurationMilliseconds, cooldownMilliseconds,
                cooldownStartsAfterDuration, reportedPoolMin,
                reportedPoolMax, fixturePoolCap);

        if (systemId != SYSTEM_UNHOLY_VESPERS || rank != 1)
            return false;
        damageTenths = 300;
        areaMultiplierMilli = 1750;
        speedMultiplierMilli = 1500;
        amount = 4;
        activeDurationMilliseconds = 3000;
        cooldownMilliseconds = 3000;
        cooldownStartsAfterDuration = 0;
        reportedPoolMin = 25;
        reportedPoolMax = 50;
        // Current page and overview table conflict; 50 is only the selected
        // bounded adapter capacity used by this engine fixture.
        fixturePoolCap = 50;
        return true;
    }

    static bool TryGetKingBibleRankRow(int rank,
        out int damageTenths, out int areaMultiplierMilli,
        out int speedMultiplierMilli, out int amount,
        out int activeDurationMilliseconds, out int cooldownMilliseconds,
        out int cooldownStartsAfterDuration, out int reportedPoolMin,
        out int reportedPoolMax, out int fixturePoolCap)
    {
        damageTenths = 0;
        areaMultiplierMilli = 0;
        speedMultiplierMilli = 0;
        amount = 0;
        activeDurationMilliseconds = 0;
        cooldownMilliseconds = 0;
        cooldownStartsAfterDuration = 0;
        reportedPoolMin = 0;
        reportedPoolMax = 0;
        fixturePoolCap = 0;
        if (rank < 1 || rank > 8) return false;

        // Rank changes are additive report deltas from base. In particular,
        // rank 6 reports 1.5 Area / 1.6 Speed, not compound 1.5625 / 1.69.
        damageTenths = rank >= 7 ? 300 : rank >= 4 ? 200 : 100;
        areaMultiplierMilli = rank >= 6 ? 1500 : rank >= 3 ? 1250 : 1000;
        speedMultiplierMilli = rank >= 6 ? 1600 : rank >= 3 ? 1300 : 1000;
        amount = rank >= 8 ? 4 : rank >= 5 ? 3 : rank >= 2 ? 2 : 1;
        activeDurationMilliseconds = rank >= 7 ? 4000
            : rank >= 4 ? 3500 : 3000;
        cooldownMilliseconds = 3000;
        cooldownStartsAfterDuration = 1;
        reportedPoolMin = 50;
        reportedPoolMax = 50;
        fixturePoolCap = 50;
        return true;
    }

    static bool TryGetOrbitProfile(int systemId,
        out int baseRadiusMilliUnits, out int radiusCapMilliUnits,
        out int baseContactRadiusMilliUnits,
        out int angularRateMilliRadiansPerSecond,
        out int maxSubstepMilliDegrees, out int memberTargetGateTics,
        out int clockwise, out int wallPolicy)
    {
        baseRadiusMilliUnits = 0;
        radiusCapMilliUnits = 0;
        baseContactRadiusMilliUnits = 0;
        angularRateMilliRadiansPerSecond = 0;
        maxSubstepMilliDegrees = 0;
        memberTargetGateTics = 0;
        clockwise = 0;
        wallPolicy = 0;
        if (systemId != SYSTEM_KING_BIBLE
            && systemId != SYSTEM_UNHOLY_VESPERS) return false;

        // Contract-frozen first-person engineering fixture. All distances
        // scale in milli logical world units; Area multiplies the two radii,
        // Speed multiplies angular rate. The cap is applied to orbit radius.
        baseRadiusMilliUnits = 48000;
        radiusCapMilliUnits = 160000;
        baseContactRadiusMilliUnits = 8000;
        angularRateMilliRadiansPerSecond = 5000;
        maxSubstepMilliDegrees = 10000;
        memberTargetGateTics = 60;
        clockwise = 1;
        wallPolicy = WALL_PASS;
        return true;
    }

    static bool TryGetEvolution(int systemId,
        out int evolvedSystemId, out int requiredSourceRank,
        out int dependencyKind, out int dependencyMinimumRank)
    {
        evolvedSystemId = 0;
        requiredSourceRank = 0;
        dependencyKind = 0;
        dependencyMinimumRank = 0;
        if (systemId != SYSTEM_KING_BIBLE) return false;
        evolvedSystemId = SYSTEM_UNHOLY_VESPERS;
        requiredSourceRank = 8;
        dependencyKind = DEPENDENCY_DURATION;
        // The build-matched census records DURATION identity but does not
        // establish its minimum rank. A positive controlled rank is tested by
        // the host; zero here means the source minimum remains unknown.
        dependencyMinimumRank = 0;
        return true;
    }
}
