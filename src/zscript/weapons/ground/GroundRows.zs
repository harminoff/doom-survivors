// Scalar compiled mirror of the canonical P038 ground-weapon JSON.
// Rank values are mutable online reports (retrieved 2026-09-23), with locked
// v1.16.107 applicability unverified. Spatial/timing policy is the lead-frozen
// first-person fixture, not source-exact behavior.
class DSP038GroundRows
{
    const SYSTEM_HOLYWATER = 46;
    const SYSTEM_BORA = 47;

    // This is a source-key enum, not a P031 inventory item ID.
    const DEPENDENCY_MAGNET_SOURCE_KEY = 1;

    const PLACEMENT_NEAREST_UNDER_AMOUNT_THEN_SIX_SECTOR_FALLBACK = 1;
    const PLACEMENT_SIX_SECTOR_RING = 2;
    const FIELD_STATIONARY = 1;
    const FIELD_INWARD_PLAYER = 2;
    const WALL_PASS = 1;
    const POOL_REJECT_AND_MARK = 1;

    static bool TryGetRankRow(int systemId, int rank,
        out int damageTenths, out int areaMultiplierMilli,
        out int amount, out int durationMilliseconds,
        out int cooldownMilliseconds, out int bottleIntervalMilliseconds,
        out int reportedFieldHitDelayMilliseconds, out int reportedPoolLimit,
        out int projectileSpeedAffected, out int moveSpeedAffected,
        out int wallPolicy)
    {
        damageTenths = 0;
        areaMultiplierMilli = 0;
        amount = 0;
        durationMilliseconds = 0;
        cooldownMilliseconds = 0;
        bottleIntervalMilliseconds = 0;
        reportedFieldHitDelayMilliseconds = 0;
        reportedPoolLimit = 0;
        projectileSpeedAffected = 0;
        moveSpeedAffected = 0;
        wallPolicy = 0;

        if (systemId == SYSTEM_HOLYWATER)
            return TryGetHolyWaterRankRow(rank, damageTenths,
                areaMultiplierMilli, amount, durationMilliseconds,
                cooldownMilliseconds, bottleIntervalMilliseconds,
                reportedFieldHitDelayMilliseconds, reportedPoolLimit,
                projectileSpeedAffected, moveSpeedAffected, wallPolicy);

        if (systemId != SYSTEM_BORA || rank != 1) return false;

        // Current page values; Area is a weapon stat, not a verified world
        // radius. The runtime applies the separate contract fixture mapping.
        damageTenths = 400;
        areaMultiplierMilli = 2000;
        amount = 4;
        durationMilliseconds = 4000;
        cooldownMilliseconds = 4000;
        bottleIntervalMilliseconds = 300;
        reportedFieldHitDelayMilliseconds = 500;
        reportedPoolLimit = 30;
        projectileSpeedAffected = 1;
        moveSpeedAffected = 1;
        wallPolicy = WALL_PASS;
        return true;
    }

    static bool TryGetHolyWaterRankRow(int rank,
        out int damageTenths, out int areaMultiplierMilli,
        out int amount, out int durationMilliseconds,
        out int cooldownMilliseconds, out int bottleIntervalMilliseconds,
        out int reportedFieldHitDelayMilliseconds, out int reportedPoolLimit,
        out int projectileSpeedAffected, out int moveSpeedAffected,
        out int wallPolicy)
    {
        damageTenths = 0;
        areaMultiplierMilli = 0;
        amount = 0;
        durationMilliseconds = 0;
        cooldownMilliseconds = 0;
        bottleIntervalMilliseconds = 0;
        reportedFieldHitDelayMilliseconds = 0;
        reportedPoolLimit = 0;
        projectileSpeedAffected = 0;
        moveSpeedAffected = 0;
        wallPolicy = 0;
        if (rank < 1 || rank > 8) return false;

        // Rank 5/7 Duration uses the page's 250ms footnote rather than its
        // rounded in-game description. Each multiplier is cumulative from the
        // reported base and is stored as an integer milli for the runtime.
        damageTenths = rank >= 8 ? 400 : rank >= 7 ? 350
            : rank >= 5 ? 300 : rank >= 3 ? 200 : 100;
        areaMultiplierMilli = rank >= 8 ? 1800 : rank >= 6 ? 1600
            : rank >= 4 ? 1400 : rank >= 2 ? 1200 : 1000;
        amount = rank >= 6 ? 4 : rank >= 4 ? 3 : rank >= 2 ? 2 : 1;
        durationMilliseconds = rank >= 7 ? 3000 : rank >= 5 ? 2750
            : rank >= 3 ? 2500 : 2000;
        cooldownMilliseconds = 4500;
        bottleIntervalMilliseconds = 300;
        reportedFieldHitDelayMilliseconds = 500;
        reportedPoolLimit = 20;
        // Santa Water's current page reports that projectile Speed is ignored.
        projectileSpeedAffected = 0;
        moveSpeedAffected = 0;
        wallPolicy = WALL_PASS;
        return true;
    }

    static bool TryGetAdapterProfile(int systemId,
        out int placementPolicy, out int sectorCount,
        out int ringRadiusMilliUnits, out int targetSelectionRadiusMilliUnits,
        out int flightTics, out int depositDelayTics,
        out int baseFieldRadiusMilliUnits, out int fieldMotionPolicy,
        out int baselineInwardMilliUnitsPerTic,
        out int speedFixtureInwardMilliUnitsPerTic,
        out int baselineGrowthMilliUnitsPerTic,
        out int speedFixtureGrowthMilliUnitsPerTic,
        out int fieldRadiusCapMilliUnits, out int fieldRehitTics,
        out int poolBoundaryPolicy, out int clockwise,
        out int sectorZeroPositiveX)
    {
        placementPolicy = 0;
        sectorCount = 0;
        ringRadiusMilliUnits = 0;
        targetSelectionRadiusMilliUnits = 0;
        flightTics = 0;
        depositDelayTics = 0;
        baseFieldRadiusMilliUnits = 0;
        fieldMotionPolicy = 0;
        baselineInwardMilliUnitsPerTic = 0;
        speedFixtureInwardMilliUnitsPerTic = 0;
        baselineGrowthMilliUnitsPerTic = 0;
        speedFixtureGrowthMilliUnitsPerTic = 0;
        fieldRadiusCapMilliUnits = 0;
        fieldRehitTics = 0;
        poolBoundaryPolicy = 0;
        clockwise = 0;
        sectorZeroPositiveX = 0;

        if (systemId != SYSTEM_HOLYWATER && systemId != SYSTEM_BORA)
            return false;

        // Frozen source-plane fixture: stable world placement, not camera aim.
        sectorCount = 6;
        ringRadiusMilliUnits = 96000;
        targetSelectionRadiusMilliUnits = 160000;
        flightTics = 12;
        depositDelayTics = 2;
        baseFieldRadiusMilliUnits = 20000;
        fieldRehitTics = 18;
        poolBoundaryPolicy = POOL_REJECT_AND_MARK;
        clockwise = 1;
        sectorZeroPositiveX = 1;

        if (systemId == SYSTEM_HOLYWATER)
        {
            placementPolicy = PLACEMENT_NEAREST_UNDER_AMOUNT_THEN_SIX_SECTOR_FALLBACK;
            fieldMotionPolicy = FIELD_STATIONARY;
            // No cap/growth applies to this stationary controlled field.
            return true;
        }

        placementPolicy = PLACEMENT_SIX_SECTOR_RING;
        fieldMotionPolicy = FIELD_INWARD_PLAYER;
        baselineInwardMilliUnitsPerTic = 500;
        speedFixtureInwardMilliUnitsPerTic = 1000;
        baselineGrowthMilliUnitsPerTic = 0;
        speedFixtureGrowthMilliUnitsPerTic = 500;
        fieldRadiusCapMilliUnits = 96000;
        return true;
    }

    static bool TryGetEvolution(int systemId,
        out int evolvedSystemId, out int dependencySourceKey,
        out int requiredSourceRank, out int dependencyMinimumRank)
    {
        evolvedSystemId = 0;
        dependencySourceKey = 0;
        requiredSourceRank = 0;
        dependencyMinimumRank = 0;
        if (systemId != SYSTEM_HOLYWATER) return false;

        evolvedSystemId = SYSTEM_BORA;
        dependencySourceKey = DEPENDENCY_MAGNET_SOURCE_KEY;
        requiredSourceRank = 8;
        // The build-matched dependency edge identifies MAGNET but not its
        // minimum rank. Zero means unknown; the MAP24 fixture labels rank 1.
        dependencyMinimumRank = 0;
        return true;
    }
}
