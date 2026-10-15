// Compiled scalar mirror of the canonical P036 returning-family JSON rows.
// Reported weapon rows are mutable community reports with cutoff uncertainty;
// motion/pierce caps are the lead-approved engineering adapter fixture.
class DSP036ReturningRows
{
    const SYSTEM_CROSS = 42;
    const SYSTEM_HEAVEN_SWORD = 43;

    const PATH_RETURNING_REVERSE = 1;
    const TARGET_CLOSEST_LIVE_SNAPSHOT = 1;
    const RETURN_FIXED_REVERSE = 1;
    const WALL_PASS = 2;
    const DEPENDENCY_LUCK = 3;

    // Rank-varying source report fields and critical eligibility. Cross has no
    // reported critical behavior; Heaven Sword has a reported 10% x2.5 crit.
    static bool TryGetRankRow(int systemId, int rank,
        out int damageTenths, out int areaMultiplierMilli,
        out int speedMultiplierMilli, out int amount,
        out int cooldownMillis, out int childIntervalMillis,
        out int passLimit, out int poolLimitInstances,
        out int critChancePermille, out int critMultiplierMilli,
        out int luckAffectsCrit)
    {
        damageTenths = 0; areaMultiplierMilli = 0; speedMultiplierMilli = 0;
        amount = 0; cooldownMillis = 0; childIntervalMillis = 0;
        passLimit = 0; poolLimitInstances = 0;
        critChancePermille = 0; critMultiplierMilli = 0; luckAffectsCrit = 0;
        if (systemId == SYSTEM_CROSS && rank == 1)
            return FillCrossRow(50, 1000, 1000, 1, damageTenths, areaMultiplierMilli, speedMultiplierMilli, amount, cooldownMillis, childIntervalMillis, passLimit, poolLimitInstances, critChancePermille, critMultiplierMilli, luckAffectsCrit);
        if (systemId == SYSTEM_CROSS && rank == 2)
            return FillCrossRow(150, 1000, 1000, 1, damageTenths, areaMultiplierMilli, speedMultiplierMilli, amount, cooldownMillis, childIntervalMillis, passLimit, poolLimitInstances, critChancePermille, critMultiplierMilli, luckAffectsCrit);
        if (systemId == SYSTEM_CROSS && rank == 3)
            return FillCrossRow(150, 1100, 1250, 1, damageTenths, areaMultiplierMilli, speedMultiplierMilli, amount, cooldownMillis, childIntervalMillis, passLimit, poolLimitInstances, critChancePermille, critMultiplierMilli, luckAffectsCrit);
        if (systemId == SYSTEM_CROSS && rank == 4)
            return FillCrossRow(150, 1100, 1250, 2, damageTenths, areaMultiplierMilli, speedMultiplierMilli, amount, cooldownMillis, childIntervalMillis, passLimit, poolLimitInstances, critChancePermille, critMultiplierMilli, luckAffectsCrit);
        if (systemId == SYSTEM_CROSS && rank == 5)
            return FillCrossRow(250, 1100, 1250, 2, damageTenths, areaMultiplierMilli, speedMultiplierMilli, amount, cooldownMillis, childIntervalMillis, passLimit, poolLimitInstances, critChancePermille, critMultiplierMilli, luckAffectsCrit);
        if (systemId == SYSTEM_CROSS && rank == 6)
            return FillCrossRow(250, 1200, 1500, 2, damageTenths, areaMultiplierMilli, speedMultiplierMilli, amount, cooldownMillis, childIntervalMillis, passLimit, poolLimitInstances, critChancePermille, critMultiplierMilli, luckAffectsCrit);
        if (systemId == SYSTEM_CROSS && rank == 7)
            return FillCrossRow(250, 1200, 1500, 3, damageTenths, areaMultiplierMilli, speedMultiplierMilli, amount, cooldownMillis, childIntervalMillis, passLimit, poolLimitInstances, critChancePermille, critMultiplierMilli, luckAffectsCrit);
        if (systemId == SYSTEM_CROSS && rank == 8)
            return FillCrossRow(350, 1200, 1500, 3, damageTenths, areaMultiplierMilli, speedMultiplierMilli, amount, cooldownMillis, childIntervalMillis, passLimit, poolLimitInstances, critChancePermille, critMultiplierMilli, luckAffectsCrit);
        if (systemId == SYSTEM_HEAVEN_SWORD && rank == 1)
        {
            damageTenths = 770; areaMultiplierMilli = 1200;
            speedMultiplierMilli = 2000; amount = 1;
            cooldownMillis = 3300; childIntervalMillis = 500;
            passLimit = 1000; poolLimitInstances = 20;
            critChancePermille = 100; critMultiplierMilli = 2500;
            luckAffectsCrit = 1; return true;
        }
        return false;
    }

    static bool FillCrossRow(int damage, int area, int speed, int count,
        out int damageTenths, out int areaMultiplierMilli,
        out int speedMultiplierMilli, out int amount,
        out int cooldownMillis, out int childIntervalMillis,
        out int passLimit, out int poolLimitInstances,
        out int critChancePermille, out int critMultiplierMilli,
        out int luckAffectsCrit)
    {
        damageTenths = damage; areaMultiplierMilli = area;
        speedMultiplierMilli = speed; amount = count;
        cooldownMillis = 2000; childIntervalMillis = 100;
        passLimit = 1000; poolLimitInstances = 30;
        critChancePermille = 0; critMultiplierMilli = 1000;
        luckAffectsCrit = 0; return true;
    }

    // Form-constant first-person motion fixture. Distances are scaled by the
    // rank speed multiplier; all motion/collision remains in logical source-plane
    // units and independent of eye yaw/pitch and player movement after launch.
    static bool TryGetFlightProfile(int systemId,
        out int launchSpeedUnitsPerSecond, out int outboundBaseUnits,
        out int reverseDistanceFactorMilli, out int totalDistanceFactorMilli,
        out int lifetimeTics, out int baseRadiusMilliUnits,
        out int pathKind, out int targetPolicy, out int returnPolicy,
        out int wallPolicy, out int passesPerLeg)
    {
        launchSpeedUnitsPerSecond = 0; outboundBaseUnits = 0;
        reverseDistanceFactorMilli = 0; totalDistanceFactorMilli = 0;
        lifetimeTics = 0; baseRadiusMilliUnits = 0;
        pathKind = 0; targetPolicy = 0; returnPolicy = 0;
        wallPolicy = 0; passesPerLeg = 0;
        if (systemId != SYSTEM_CROSS && systemId != SYSTEM_HEAVEN_SWORD)
            return false;
        launchSpeedUnitsPerSecond = 240;
        // Both rows share 160; multiplying by the report's speed factor makes
        // Heaven Sword's reported 2.0 factor reach the approved 320-unit turn.
        outboundBaseUnits = 160;
        reverseDistanceFactorMilli = 2000;
        totalDistanceFactorMilli = 3000;
        lifetimeTics = 70;
        baseRadiusMilliUnits = 7000;
        pathKind = PATH_RETURNING_REVERSE;
        targetPolicy = TARGET_CLOSEST_LIVE_SNAPSHOT;
        returnPolicy = RETURN_FIXED_REVERSE;
        wallPolicy = WALL_PASS;
        passesPerLeg = 1;
        return true;
    }

    static bool TryGetEvolution(int systemId,
        out int evolvedSystemId, out int requiredSourceRank,
        out int dependencyKind, out int dependencyMinRank)
    {
        evolvedSystemId = 0; requiredSourceRank = 0;
        dependencyKind = 0; dependencyMinRank = 0;
        if (systemId != SYSTEM_CROSS) return false;
        evolvedSystemId = SYSTEM_HEAVEN_SWORD;
        requiredSourceRank = 8;
        dependencyKind = DEPENDENCY_LUCK;
        // The census proves dependency identity, not minimum owned rank.
        dependencyMinRank = 1;
        return true;
    }
}
