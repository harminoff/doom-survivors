// Scalar compiled mirror of the canonical P039 aura-weapon JSON
// (data/verified/base/weapons/aura/garlic.json, soul-eater.json). Rank values
// are mutable online reports (retrieved 2026-09-27), locked v1.16.107
// applicability unverified. Spatial/timing policy mirrors the lead-frozen
// docs/contracts/auras-healing.md fixture, not source-exact geometry.
class DSP039AuraRows
{
    const SYSTEM_GARLIC = 48;
    const SYSTEM_SOUL_EATER = 49;

    // This is a source-key enum local to this file, not a P031 inventory
    // item ID (see DSP038GroundRows.DEPENDENCY_MAGNET_SOURCE_KEY for the
    // established pattern).
    const DEPENDENCY_REGEN_SOURCE_KEY = 1;

    // Per-target debuff fixture (docs/contracts/auras-healing.md "Debuff").
    const KNOCKBACK_STEP_MILLI = 300;
    const KNOCKBACK_CAP_MILLI = 3000;
    const FREEZE_RESIST_STEP_MILLI = 100;

    // Soul Eater growth-from-healed-HP fixture.
    const SOUL_EATER_GROWTH_HEAL_MILLI = 60000;
    const SOUL_EATER_GROWTH_CAP = 60;

    // Little Heart spawn-chance and heal fixtures.
    const HEART_CHANCE_NUMERATOR = 3;
    const HEART_CHANCE_DENOMINATOR_MILLI = 140000;
    const HEART_BASE_HEAL_MILLI = 1000;

    // Bloody Tear drain fixture (healing-authority migration target).
    const BLOODY_TEAR_DRAIN_MILLI = 8000;
    const BLOODY_TEAR_DRAIN_GATE_TICS = 35;

    // Recovery per-second boundary fixture.
    const RECOVERY_PERIOD_TICS = 35;

    // Engineering radius scale: base 32 logical units x reported Area.
    const BASE_RADIUS_MILLI_UNITS = 32000;

    static int RankCount(int system)
    {
        if (system == SYSTEM_GARLIC) return 8;
        if (system == SYSTEM_SOUL_EATER) return 1;
        return 0;
    }

    // Source damage x1000 (milli-damage), per rank.
    static int DamageMilli(int system, int rank)
    {
        if (system == SYSTEM_SOUL_EATER)
            return rank == 1 ? 20000 : 0;
        if (system != SYSTEM_GARLIC || rank < 1 || rank > 8) return 0;
        if (rank == 1) return 5000;
        if (rank == 2) return 7000;
        if (rank == 3) return 8000;
        if (rank == 4) return 9000;
        if (rank == 5) return 11000;
        if (rank == 6) return 12000;
        if (rank == 7) return 13000;
        return 15000; // rank 8
    }

    // Reported Area multiplier in milli (1000 = 100%), per rank.
    static int AreaMilli(int system, int rank)
    {
        if (system == SYSTEM_SOUL_EATER)
            return rank == 1 ? 3000 : 0;
        if (system != SYSTEM_GARLIC || rank < 1 || rank > 8) return 0;
        if (rank == 1) return 1000;
        if (rank == 2) return 1400;
        if (rank == 3) return 1400;
        if (rank == 4) return 1600;
        if (rank == 5) return 1600;
        if (rank == 6) return 1800;
        if (rank == 7) return 1800;
        return 2000; // rank 8
    }

    // Reported Cooldown converted to logical tics by nearest-tic rounding
    // (1.3s=46, 1.2s=42, 1.1s=39, 1.0s=35 at 35Hz), per rank.
    static int CooldownTics(int system, int rank)
    {
        if (system == SYSTEM_SOUL_EATER)
            return rank == 1 ? 35 : 0;
        if (system != SYSTEM_GARLIC || rank < 1 || rank > 8) return 0;
        if (rank <= 2) return 46;
        if (rank <= 4) return 42;
        if (rank <= 6) return 39;
        return 35; // ranks 7-8
    }

    // 32 logical units x reported Area, in milli-units.
    static int RadiusMilliUnits(int system, int rank)
    {
        int areaMilli = AreaMilli(system, rank);
        if (areaMilli <= 0) return 0;
        return BASE_RADIUS_MILLI_UNITS * areaMilli / 1000;
    }

    static bool TryGetEvolution(int systemId,
        out int evolvedSystemId, out int dependencySourceKey,
        out int requiredSourceRank, out int dependencyMinimumRank)
    {
        evolvedSystemId = 0;
        dependencySourceKey = 0;
        requiredSourceRank = 0;
        dependencyMinimumRank = 0;
        if (systemId != SYSTEM_GARLIC) return false;

        evolvedSystemId = SYSTEM_SOUL_EATER;
        dependencySourceKey = DEPENDENCY_REGEN_SOURCE_KEY;
        requiredSourceRank = 8;
        // Sources report Pummarola must be equipped, not a required rank.
        dependencyMinimumRank = 0;
        return true;
    }
}
