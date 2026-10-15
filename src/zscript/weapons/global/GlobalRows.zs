// Scalar compiled mirror of the canonical P040 global-strike weapon JSON
// (data/verified/base/weapons/global/lightning-ring.json, thunder-loop.json,
// pentagram.json, gorgeous-moon.json). Rank values are mutable online reports
// (retrieved 2026-09-27), locked v1.16.107 applicability unverified.
// Spatial/timing policy mirrors the lead-frozen
// docs/contracts/global-strikes.md fixture, not source-exact geometry.
class DSP040GlobalRows
{
    const SYSTEM_LIGHTNING = 50;
    const SYSTEM_THUNDER_LOOP = 51;
    const SYSTEM_PENTAGRAM = 52;
    const SYSTEM_GORGEOUS_MOON = 53;

    // These are source-key enum locals to this file, not P031 inventory item
    // IDs (see DSP039AuraRows.DEPENDENCY_REGEN_SOURCE_KEY for the established
    // pattern).
    const DEPENDENCY_AMOUNT_SOURCE_KEY = 1;
    const DEPENDENCY_GROWTH_SOURCE_KEY = 2;

    // Region fixture (docs/contracts/global-strikes.md "Region"): the
    // inclusive 256x256 logical-reference-v1 rectangle centred on the
    // player is +/-128 logical units on each axis.
    const REGION_HALF_EXTENT = 128;

    // Thunder Loop repeat-strike fixture (a labelled 0.5s fixture, not a
    // sourced numeric delay).
    const THUNDER_REPEAT_DELAY_TICS = 18;

    // Gorgeous Moon two-phase fixture.
    const MOON_BEAM_COUNT = 6;
    const MOON_PHASE2_DELAY_TICS = 35;
    const MOON_PERIOD_FLOOR_TICS = 525;
    // Base XP (1.000 XP) carried by each erasure-phase Moon gem before
    // adding resolved Amount, per the frozen contract.
    const MOON_GEM_BASE_XP_MILLI = 1000;

    // Luck is fixed at 1000 milli (neutral, 100%) until a Luck stat exists;
    // Pentagram's spare roll multiplies spare_milli by this value.
    const LUCK_BASE_MILLI = 1000;

    static int RankCount(int system)
    {
        if (system == SYSTEM_LIGHTNING) return 8;
        if (system == SYSTEM_THUNDER_LOOP) return 1;
        if (system == SYSTEM_PENTAGRAM) return 8;
        if (system == SYSTEM_GORGEOUS_MOON) return 1;
        return 0;
    }

    // Source damage x1000 (milli-damage), per rank. Pentagram has no fixed
    // damage row (erasure is not a damage transaction); Gorgeous Moon's
    // phase-1 beams deal damage equal to the target's current health, not a
    // fixed row value, so both report 0 here by convention.
    static int DamageMilli(int system, int rank)
    {
        if (system == SYSTEM_THUNDER_LOOP)
            return rank == 1 ? 65000 : 0;
        if (system != SYSTEM_LIGHTNING || rank < 1 || rank > 8) return 0;
        if (rank == 1) return 15000;
        if (rank == 2) return 15000;
        if (rank == 3) return 25000;
        if (rank == 4) return 25000;
        if (rank == 5) return 45000;
        if (rank == 6) return 45000;
        if (rank == 7) return 65000;
        return 65000; // rank 8
    }

    // Reported Area multiplier in milli (1000 = 100%), per rank. Pentagram
    // and Gorgeous Moon do not use Area.
    static int AreaMilli(int system, int rank)
    {
        if (system == SYSTEM_THUNDER_LOOP)
            return rank == 1 ? 4000 : 0;
        if (system != SYSTEM_LIGHTNING || rank < 1 || rank > 8) return 0;
        if (rank == 1) return 1000;
        if (rank == 2) return 1000;
        if (rank == 3) return 2000;
        if (rank == 4) return 2000;
        if (rank == 5) return 3000;
        if (rank == 6) return 3000;
        if (rank == 7) return 4000;
        return 4000; // rank 8
    }

    // Row (base) strike count, per rank. The frozen contract adds resolved
    // Duplicator Amount to this row value at runtime; this function returns
    // only the row's own reported Amount, not the combined total.
    static int Amount(int system, int rank)
    {
        if (system == SYSTEM_THUNDER_LOOP)
            return rank == 1 ? 6 : 0;
        if (system != SYSTEM_LIGHTNING || rank < 1 || rank > 8) return 0;
        if (rank == 1) return 2;
        if (rank == 2) return 3;
        if (rank == 3) return 3;
        if (rank == 4) return 4;
        if (rank == 5) return 4;
        if (rank == 6) return 5;
        if (rank == 7) return 5;
        return 6; // rank 8
    }

    // Activation period in tics, before the P033 Cooldown multiplier is
    // applied. Lightning Ring/Thunder Loop: flat 4.5s -> 158 tics by
    // nearest-tic rounding at 35Hz, every rank. Pentagram: per-rank Cooldown
    // 90/80/80/70/70/65/65/60s -> exact-multiple tic values, no extra floor
    // under the multiplier (unknown per contract). Gorgeous Moon: 60s -> 2100
    // tics base; the caller applies MOON_PERIOD_FLOOR_TICS after the
    // multiplier, not this function.
    static int PeriodTics(int system, int rank)
    {
        if (system == SYSTEM_LIGHTNING && rank >= 1 && rank <= 8) return 158;
        if (system == SYSTEM_THUNDER_LOOP) return rank == 1 ? 158 : 0;
        if (system == SYSTEM_GORGEOUS_MOON) return rank == 1 ? 2100 : 0;
        if (system != SYSTEM_PENTAGRAM || rank < 1 || rank > 8) return 0;
        if (rank == 1) return 3150;
        if (rank == 2) return 2800;
        if (rank == 3) return 2800;
        if (rank == 4) return 2450;
        if (rank == 5) return 2450;
        if (rank == 6) return 2275;
        if (rank == 7) return 2275;
        return 2100; // rank 8
    }

    // Inter-strike stagger in tics within one activation. Lightning Ring:
    // 2 tics (0.05s -> 1.75 -> 2 by nearest-tic rounding). Thunder Loop:
    // 0 (strikes share one tic; the second strike is a separate scheduled
    // repeat, see THUNDER_REPEAT_DELAY_TICS). Pentagram/Gorgeous Moon do not
    // use this field.
    static int StrikeIntervalTics(int system, int rank)
    {
        if (system == SYSTEM_LIGHTNING && rank >= 1 && rank <= 8) return 2;
        if (system == SYSTEM_THUNDER_LOOP && rank == 1) return 0;
        return 0;
    }

    // 16 logical units x reported Area, in milli-units. Only Lightning Ring
    // and Thunder Loop have a strike radius; Pentagram/Gorgeous Moon erase
    // the whole region and report 0 here.
    static int StrikeRadiusMilliUnits(int system, int rank)
    {
        if (system != SYSTEM_LIGHTNING && system != SYSTEM_THUNDER_LOOP)
            return 0;
        int areaMilli = AreaMilli(system, rank);
        if (areaMilli <= 0) return 0;
        return 16000 * areaMilli / 1000;
    }

    // Pentagram per-rank pickup spare chance in milli (1000 = 100%), used as
    // rng % 1000000 < spareMilli * luckMilli. All other systems return 0.
    static int SpareMilli(int system, int rank)
    {
        if (system != SYSTEM_PENTAGRAM || rank < 1 || rank > 8) return 0;
        if (rank <= 2) return 100;
        if (rank <= 4) return 250;
        if (rank <= 6) return 450;
        return 650; // ranks 7-8
    }

    // Evolution edges. Unlike DSP039AuraRows.TryGetEvolution (which returns
    // the dependency key as an output alongside the evolved system), this
    // signature takes the equipped dependencyItem as an input and only
    // reports whether that specific combination evolves, per the P040
    // deliverable contract.
    static bool TryGetEvolution(int sourceSystem, int sourceRank,
        int dependencyItem, out int evolvedSystem)
    {
        evolvedSystem = 0;
        if (sourceSystem == SYSTEM_LIGHTNING && sourceRank >= 8
            && dependencyItem == DEPENDENCY_AMOUNT_SOURCE_KEY)
        {
            evolvedSystem = SYSTEM_THUNDER_LOOP;
            return true;
        }
        if (sourceSystem == SYSTEM_PENTAGRAM && sourceRank >= 8
            && dependencyItem == DEPENDENCY_GROWTH_SOURCE_KEY)
        {
            evolvedSystem = SYSTEM_GORGEOUS_MOON;
            return true;
        }
        return false;
    }
}
