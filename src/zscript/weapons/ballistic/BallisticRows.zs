// Compiled scalar mirror of the canonical P035 ballistic JSON rank rows.
// Reported fields remain qualified current reports; path fields are approved
// first-person engineering fixtures, not source-exact physics.
class DSP035WeaponRows
{
    const SYSTEM_AXE = 38;
    const SYSTEM_DEATH_SPIRAL = 39;
    const SYSTEM_FIRE_WAND = 40;
    const SYSTEM_HELLFIRE = 41;

    const PATH_AXE_ARC = 1;
    const PATH_RADIAL = 2;
    const PATH_RANDOM_TARGET_FAN = 3;
    const PATH_RANDOM_TARGET_METEOR_FAN = 4;
    // N3 Track A adapter (docs/contracts/remaining-weapons.md): Song of
    // Mana/Mannajja's fixed downward beam at a randomized horizontal start
    // offset. New engine surface -- see the labelled branches in
    // DSP035BallisticProjectileRuntime.DSP035SpawnChild.
    const PATH_VERTICAL_FALL = 5;

    const TARGET_OWNER_UPWARD_THEN_VIEW_FAN = 1;
    const TARGET_OWNER_RADIAL = 2;
    const TARGET_RANDOM_LIVE_ENEMY_SNAPSHOT = 3;
    const WALL_BLOCK = 1;
    const WALL_PASS = 2;
    const DEPENDENCY_AREA = 1;
    const DEPENDENCY_POWER = 2;
    // N3 Track A: Mannajja's evolution dependency is the passive item
    // Skull O'Maniac (rank 1), not an existing stat-rule passive kind.
    const DEPENDENCY_SKULL_OMANIAC = 3;
    // Kyra-Stones' evolution passive, Karoma's Mana (rank 1).
    const DEPENDENCY_KAROMAS_MANA = 4;

    static bool TryGetRankRow(int systemId, int rank,
        out int damageTenths, out int amount, out int pierce,
        out int cooldownMillis, out int childIntervalMillis,
        out int speedMultiplierMilli, out int areaMultiplierMilli,
        out int launchSpeedUnitsPerSecond,
        out int accelerationYUnitsPerSecondSquared,
        out int maxRangeUnits, out int lifetimeTics,
        out int collisionRadiusMilliUnits, out int poolLimitInstances,
        out int pathKind, out int targetPolicy, out int wallPolicy,
        out int spreadStepMilliDegrees, out int radialChildCount)
    {
        damageTenths = 0; amount = 0; pierce = 0;
        cooldownMillis = 0; childIntervalMillis = 0;
        speedMultiplierMilli = 0; areaMultiplierMilli = 0;
        launchSpeedUnitsPerSecond = 0;
        accelerationYUnitsPerSecondSquared = 0;
        maxRangeUnits = 0; lifetimeTics = 0;
        collisionRadiusMilliUnits = 0; poolLimitInstances = 0;
        pathKind = 0; targetPolicy = 0; wallPolicy = 0;
        spreadStepMilliDegrees = 0; radialChildCount = 0;
        if (systemId == SYSTEM_AXE)
            return TryGetAxeRankRow(systemId, rank, damageTenths, amount, pierce, cooldownMillis, childIntervalMillis, speedMultiplierMilli, areaMultiplierMilli, launchSpeedUnitsPerSecond, accelerationYUnitsPerSecondSquared, maxRangeUnits, lifetimeTics, collisionRadiusMilliUnits, poolLimitInstances, pathKind, targetPolicy, wallPolicy, spreadStepMilliDegrees, radialChildCount);
        if (systemId == SYSTEM_DEATH_SPIRAL)
            return TryGetDeathSpiralRankRow(systemId, rank, damageTenths, amount, pierce, cooldownMillis, childIntervalMillis, speedMultiplierMilli, areaMultiplierMilli, launchSpeedUnitsPerSecond, accelerationYUnitsPerSecondSquared, maxRangeUnits, lifetimeTics, collisionRadiusMilliUnits, poolLimitInstances, pathKind, targetPolicy, wallPolicy, spreadStepMilliDegrees, radialChildCount);
        if (systemId == SYSTEM_FIRE_WAND)
            return TryGetFireWandRankRow(systemId, rank, damageTenths, amount, pierce, cooldownMillis, childIntervalMillis, speedMultiplierMilli, areaMultiplierMilli, launchSpeedUnitsPerSecond, accelerationYUnitsPerSecondSquared, maxRangeUnits, lifetimeTics, collisionRadiusMilliUnits, poolLimitInstances, pathKind, targetPolicy, wallPolicy, spreadStepMilliDegrees, radialChildCount);
        if (systemId == SYSTEM_HELLFIRE)
            return TryGetHellfireRankRow(systemId, rank, damageTenths, amount, pierce, cooldownMillis, childIntervalMillis, speedMultiplierMilli, areaMultiplierMilli, launchSpeedUnitsPerSecond, accelerationYUnitsPerSecondSquared, maxRangeUnits, lifetimeTics, collisionRadiusMilliUnits, poolLimitInstances, pathKind, targetPolicy, wallPolicy, spreadStepMilliDegrees, radialChildCount);
        // N3 Track A: Magi-Stone, Mannajja and Song of Mana join the P035
        // engine as data rows plus a small per-weapon adapter (this
        // worker's task per docs/contracts/remaining-weapons.md Track A).
        // DSN3Rows (owned by a concurrent worker) supplies the qualified
        // per-rank scalars; the path/target/wall/pool-limit/spread policy
        // fields below are not part of DSN3Rows' contract and are this
        // adapter's own labelled ENGINEERING_FALLBACK configuration.
        if (systemId == DSN3Rows.SYSTEM_MAGI_STONE
            || systemId == DSN3Rows.SYSTEM_KYRA_STONES
            || systemId == DSN3Rows.SYSTEM_MANNAJJA
            || systemId == DSN3Rows.SYSTEM_SONG_OF_MANA)
            return TryGetN3RankRow(systemId, rank, damageTenths, amount, pierce, cooldownMillis, childIntervalMillis, speedMultiplierMilli, areaMultiplierMilli, launchSpeedUnitsPerSecond, accelerationYUnitsPerSecondSquared, maxRangeUnits, lifetimeTics, collisionRadiusMilliUnits, poolLimitInstances, pathKind, targetPolicy, wallPolicy, spreadStepMilliDegrees, radialChildCount);
        return false;
    }

    // N3 Track A adapter row source. Scalars (damage/area/speed/amount/
    // cooldown/duration/interval/pierce) come from DSN3Rows, which is
    // itself a QUALIFIED_ONLINE_REPORT/INFERENCE mirror of
    // data/verified/base/weapons/n3/*.json (docs/contracts/remaining-
    // weapons.md). The path/target/wall/pool/spread fields have no source
    // in that contract and are this adapter's own engineering choice:
    // - Magi-Stone: research adapter_params says only "damage_source:
    //   fixed_by_weapon_level_not_might" (no trajectory claim); reuses the
    //   existing PATH_RANDOM_TARGET_FAN/TARGET_RANDOM_LIVE_ENEMY_SNAPSHOT/
    //   WALL_PASS shape already accepted for Fire Wand. The might-exclusion
    //   itself needs no code change here: DSP033StatRules.StatApplies is an
    //   allowlist and SYSTEM_MAGI_STONE is deliberately left out of it, so
    //   Might already does not apply to it.
    // - Song of Mana/Mannajja: research adapter_params says
    //   "trajectory: fixed_vertical_fall" with a randomized start offset,
    //   a mechanic P035 had no path kind for; PATH_VERTICAL_FALL (added
    //   above) plus TARGET_OWNER_RADIAL (no live-target lookup needed) is
    //   the new labelled surface for it. Mannajja's researched "slow on
    //   hit" status effect is UNKNOWN-percentage per the contract and is
    //   out of this worker's scope (no status system wired here); only its
    //   damage/area/duration/cooldown rows are carried over.
    static bool TryGetN3RankRow(int systemId, int rank,
        out int damageTenths, out int amount, out int pierce,
        out int cooldownMillis, out int childIntervalMillis,
        out int speedMultiplierMilli, out int areaMultiplierMilli,
        out int launchSpeedUnitsPerSecond,
        out int accelerationYUnitsPerSecondSquared,
        out int maxRangeUnits, out int lifetimeTics,
        out int collisionRadiusMilliUnits, out int poolLimitInstances,
        out int pathKind, out int targetPolicy, out int wallPolicy,
        out int spreadStepMilliDegrees, out int radialChildCount)
    {
        damageTenths = 0; amount = 0; pierce = 0;
        cooldownMillis = 0; childIntervalMillis = 0;
        speedMultiplierMilli = 0; areaMultiplierMilli = 0;
        launchSpeedUnitsPerSecond = 0;
        accelerationYUnitsPerSecondSquared = 0;
        maxRangeUnits = 0; lifetimeTics = 0;
        collisionRadiusMilliUnits = 0; poolLimitInstances = 0;
        pathKind = 0; targetPolicy = 0; wallPolicy = 0;
        spreadStepMilliDegrees = 0; radialChildCount = 0;
        if (!DSN3Rows.ValidRank(systemId, rank)) return false;

        damageTenths = DSN3Rows.DamageMilli(systemId, rank) / 100;
        // Magi-Stone's rows are a flat 10 at every rank, but its fixed damage
        // grows with weapon level (wiki approximation: +5 per level).
        if (systemId == DSN3Rows.SYSTEM_MAGI_STONE) damageTenths = (10000 + 5000 * (rank - 1)) / 100;
        amount = DSN3Rows.Amount(systemId, rank);
        int reportedPierce = DSN3Rows.Pierce(systemId, rank);
        // -1 is DSN3Rows' "area of effect / infinite" sentinel; the P035
        // engine's own infinite-pierce convention (Death Spiral, Hellfire)
        // is the literal value 1000.
        pierce = reportedPierce < 0 ? 1000 : reportedPierce;
        // Kyra-Stones' row has no pierce (0 would never fire here); it keeps
        // Magi-Stone's unlimited pierce, an approximation.
        if (systemId == DSN3Rows.SYSTEM_KYRA_STONES && pierce <= 0) pierce = 1000;
        cooldownMillis = DSN3Rows.CooldownTics(systemId, rank)
            * 1000 / Thinker.TICRATE;
        childIntervalMillis = DSN3Rows.IntervalTics(systemId, rank)
            * 1000 / Thinker.TICRATE;
        if (childIntervalMillis <= 0) childIntervalMillis = 1;
        speedMultiplierMilli = DSN3Rows.SpeedMilli(systemId, rank);
        areaMultiplierMilli = DSN3Rows.AreaMilli(systemId, rank);
        // ENGINEERING_FALLBACK baseline shared with every other P035
        // weapon (Axe/Fire Wand/Hellfire all use the same 320-unit
        // half-screen range); DSN3Rows carries no travel-speed-in-units or
        // range field, only the multiplier fields already consumed above.
        launchSpeedUnitsPerSecond = 240;
        accelerationYUnitsPerSecondSquared = 0;
        maxRangeUnits = 320;
        int durationTics = DSN3Rows.DurationTics(systemId, rank);
        lifetimeTics = durationTics > 0 ? durationTics : 35;
        collisionRadiusMilliUnits = 6000;
        poolLimitInstances = 30;
        wallPolicy = WALL_PASS;
        spreadStepMilliDegrees = 15000;
        radialChildCount = 0;
        if (systemId == DSN3Rows.SYSTEM_MAGI_STONE
            || systemId == DSN3Rows.SYSTEM_KYRA_STONES)
        {
            pathKind = PATH_RANDOM_TARGET_FAN;
            targetPolicy = TARGET_RANDOM_LIVE_ENEMY_SNAPSHOT;
        }
        else
        {
            pathKind = PATH_VERTICAL_FALL;
            targetPolicy = TARGET_OWNER_RADIAL;
        }
        return true;
    }

    static bool TryGetAxeRankRow(int systemId, int rank,
        out int damageTenths, out int amount, out int pierce,
        out int cooldownMillis, out int childIntervalMillis,
        out int speedMultiplierMilli, out int areaMultiplierMilli,
        out int launchSpeedUnitsPerSecond,
        out int accelerationYUnitsPerSecondSquared,
        out int maxRangeUnits, out int lifetimeTics,
        out int collisionRadiusMilliUnits, out int poolLimitInstances,
        out int pathKind, out int targetPolicy, out int wallPolicy,
        out int spreadStepMilliDegrees, out int radialChildCount)
    {
        if (systemId == SYSTEM_AXE && rank == 1)
        {
            damageTenths = 200;
            amount = 1;
            pierce = 3;
            cooldownMillis = 4000;
            childIntervalMillis = 200;
            speedMultiplierMilli = 1000;
            areaMultiplierMilli = 1000;
            launchSpeedUnitsPerSecond = 240;
            accelerationYUnitsPerSecondSquared = -240;
            maxRangeUnits = 320;
            lifetimeTics = 70;
            collisionRadiusMilliUnits = 7000;
            poolLimitInstances = 70;
            pathKind = 1;
            targetPolicy = 1;
            wallPolicy = 2;
            spreadStepMilliDegrees = 30000;
            radialChildCount = 0;
            return true;
        }
        if (systemId == SYSTEM_AXE && rank == 2)
        {
            damageTenths = 200;
            amount = 2;
            pierce = 3;
            cooldownMillis = 4000;
            childIntervalMillis = 200;
            speedMultiplierMilli = 1000;
            areaMultiplierMilli = 1000;
            launchSpeedUnitsPerSecond = 240;
            accelerationYUnitsPerSecondSquared = -240;
            maxRangeUnits = 320;
            lifetimeTics = 70;
            collisionRadiusMilliUnits = 7000;
            poolLimitInstances = 70;
            pathKind = 1;
            targetPolicy = 1;
            wallPolicy = 2;
            spreadStepMilliDegrees = 30000;
            radialChildCount = 0;
            return true;
        }
        if (systemId == SYSTEM_AXE && rank == 3)
        {
            damageTenths = 400;
            amount = 2;
            pierce = 3;
            cooldownMillis = 4000;
            childIntervalMillis = 200;
            speedMultiplierMilli = 1000;
            areaMultiplierMilli = 1000;
            launchSpeedUnitsPerSecond = 240;
            accelerationYUnitsPerSecondSquared = -240;
            maxRangeUnits = 320;
            lifetimeTics = 70;
            collisionRadiusMilliUnits = 7000;
            poolLimitInstances = 70;
            pathKind = 1;
            targetPolicy = 1;
            wallPolicy = 2;
            spreadStepMilliDegrees = 30000;
            radialChildCount = 0;
            return true;
        }
        if (systemId == SYSTEM_AXE && rank == 4)
        {
            damageTenths = 400;
            amount = 2;
            pierce = 5;
            cooldownMillis = 4000;
            childIntervalMillis = 200;
            speedMultiplierMilli = 1000;
            areaMultiplierMilli = 1000;
            launchSpeedUnitsPerSecond = 240;
            accelerationYUnitsPerSecondSquared = -240;
            maxRangeUnits = 320;
            lifetimeTics = 70;
            collisionRadiusMilliUnits = 7000;
            poolLimitInstances = 70;
            pathKind = 1;
            targetPolicy = 1;
            wallPolicy = 2;
            spreadStepMilliDegrees = 30000;
            radialChildCount = 0;
            return true;
        }
        if (systemId == SYSTEM_AXE && rank == 5)
        {
            damageTenths = 400;
            amount = 3;
            pierce = 5;
            cooldownMillis = 4000;
            childIntervalMillis = 200;
            speedMultiplierMilli = 1000;
            areaMultiplierMilli = 1000;
            launchSpeedUnitsPerSecond = 240;
            accelerationYUnitsPerSecondSquared = -240;
            maxRangeUnits = 320;
            lifetimeTics = 70;
            collisionRadiusMilliUnits = 7000;
            poolLimitInstances = 70;
            pathKind = 1;
            targetPolicy = 1;
            wallPolicy = 2;
            spreadStepMilliDegrees = 30000;
            radialChildCount = 0;
            return true;
        }
        if (systemId == SYSTEM_AXE && rank == 6)
        {
            damageTenths = 600;
            amount = 3;
            pierce = 5;
            cooldownMillis = 4000;
            childIntervalMillis = 200;
            speedMultiplierMilli = 1000;
            areaMultiplierMilli = 1000;
            launchSpeedUnitsPerSecond = 240;
            accelerationYUnitsPerSecondSquared = -240;
            maxRangeUnits = 320;
            lifetimeTics = 70;
            collisionRadiusMilliUnits = 7000;
            poolLimitInstances = 70;
            pathKind = 1;
            targetPolicy = 1;
            wallPolicy = 2;
            spreadStepMilliDegrees = 30000;
            radialChildCount = 0;
            return true;
        }
        if (systemId == SYSTEM_AXE && rank == 7)
        {
            damageTenths = 600;
            amount = 3;
            pierce = 7;
            cooldownMillis = 4000;
            childIntervalMillis = 200;
            speedMultiplierMilli = 1000;
            areaMultiplierMilli = 1000;
            launchSpeedUnitsPerSecond = 240;
            accelerationYUnitsPerSecondSquared = -240;
            maxRangeUnits = 320;
            lifetimeTics = 70;
            collisionRadiusMilliUnits = 7000;
            poolLimitInstances = 70;
            pathKind = 1;
            targetPolicy = 1;
            wallPolicy = 2;
            spreadStepMilliDegrees = 30000;
            radialChildCount = 0;
            return true;
        }
        if (systemId == SYSTEM_AXE && rank == 8)
        {
            damageTenths = 800;
            amount = 3;
            pierce = 7;
            cooldownMillis = 4000;
            childIntervalMillis = 200;
            speedMultiplierMilli = 1000;
            areaMultiplierMilli = 1000;
            launchSpeedUnitsPerSecond = 240;
            accelerationYUnitsPerSecondSquared = -240;
            maxRangeUnits = 320;
            lifetimeTics = 70;
            collisionRadiusMilliUnits = 7000;
            poolLimitInstances = 70;
            pathKind = 1;
            targetPolicy = 1;
            wallPolicy = 2;
            spreadStepMilliDegrees = 30000;
            radialChildCount = 0;
            return true;
        }
        return false;
    }

    static bool TryGetDeathSpiralRankRow(int systemId, int rank,
        out int damageTenths, out int amount, out int pierce,
        out int cooldownMillis, out int childIntervalMillis,
        out int speedMultiplierMilli, out int areaMultiplierMilli,
        out int launchSpeedUnitsPerSecond,
        out int accelerationYUnitsPerSecondSquared,
        out int maxRangeUnits, out int lifetimeTics,
        out int collisionRadiusMilliUnits, out int poolLimitInstances,
        out int pathKind, out int targetPolicy, out int wallPolicy,
        out int spreadStepMilliDegrees, out int radialChildCount)
    {
        if (systemId == SYSTEM_DEATH_SPIRAL && rank == 1)
        {
            damageTenths = 600;
            amount = 9;
            pierce = 1000;
            cooldownMillis = 4000;
            childIntervalMillis = 50;
            speedMultiplierMilli = 800;
            areaMultiplierMilli = 1200;
            launchSpeedUnitsPerSecond = 240;
            accelerationYUnitsPerSecondSquared = 0;
            maxRangeUnits = 320;
            lifetimeTics = 59;
            collisionRadiusMilliUnits = 12000;
            poolLimitInstances = 50;
            pathKind = 2;
            targetPolicy = 2;
            wallPolicy = 2;
            spreadStepMilliDegrees = 0;
            radialChildCount = 9;
            return true;
        }
        return false;
    }

    static bool TryGetFireWandRankRow(int systemId, int rank,
        out int damageTenths, out int amount, out int pierce,
        out int cooldownMillis, out int childIntervalMillis,
        out int speedMultiplierMilli, out int areaMultiplierMilli,
        out int launchSpeedUnitsPerSecond,
        out int accelerationYUnitsPerSecondSquared,
        out int maxRangeUnits, out int lifetimeTics,
        out int collisionRadiusMilliUnits, out int poolLimitInstances,
        out int pathKind, out int targetPolicy, out int wallPolicy,
        out int spreadStepMilliDegrees, out int radialChildCount)
    {
        if (systemId == SYSTEM_FIRE_WAND && rank == 1)
        {
            damageTenths = 200;
            amount = 3;
            pierce = 1;
            cooldownMillis = 3000;
            childIntervalMillis = 20;
            speedMultiplierMilli = 750;
            areaMultiplierMilli = 1000;
            launchSpeedUnitsPerSecond = 240;
            accelerationYUnitsPerSecondSquared = 0;
            maxRangeUnits = 320;
            lifetimeTics = 63;
            collisionRadiusMilliUnits = 6000;
            poolLimitInstances = 30;
            pathKind = 3;
            targetPolicy = 3;
            wallPolicy = 1;
            spreadStepMilliDegrees = 15000;
            radialChildCount = 0;
            return true;
        }
        if (systemId == SYSTEM_FIRE_WAND && rank == 2)
        {
            damageTenths = 300;
            amount = 3;
            pierce = 1;
            cooldownMillis = 3000;
            childIntervalMillis = 20;
            speedMultiplierMilli = 750;
            areaMultiplierMilli = 1000;
            launchSpeedUnitsPerSecond = 240;
            accelerationYUnitsPerSecondSquared = 0;
            maxRangeUnits = 320;
            lifetimeTics = 63;
            collisionRadiusMilliUnits = 6000;
            poolLimitInstances = 30;
            pathKind = 3;
            targetPolicy = 3;
            wallPolicy = 1;
            spreadStepMilliDegrees = 15000;
            radialChildCount = 0;
            return true;
        }
        if (systemId == SYSTEM_FIRE_WAND && rank == 3)
        {
            damageTenths = 400;
            amount = 3;
            pierce = 1;
            cooldownMillis = 3000;
            childIntervalMillis = 20;
            speedMultiplierMilli = 950;
            areaMultiplierMilli = 1000;
            launchSpeedUnitsPerSecond = 240;
            accelerationYUnitsPerSecondSquared = 0;
            maxRangeUnits = 320;
            lifetimeTics = 50;
            collisionRadiusMilliUnits = 6000;
            poolLimitInstances = 30;
            pathKind = 3;
            targetPolicy = 3;
            wallPolicy = 1;
            spreadStepMilliDegrees = 15000;
            radialChildCount = 0;
            return true;
        }
        if (systemId == SYSTEM_FIRE_WAND && rank == 4)
        {
            damageTenths = 500;
            amount = 3;
            pierce = 1;
            cooldownMillis = 3000;
            childIntervalMillis = 20;
            speedMultiplierMilli = 950;
            areaMultiplierMilli = 1000;
            launchSpeedUnitsPerSecond = 240;
            accelerationYUnitsPerSecondSquared = 0;
            maxRangeUnits = 320;
            lifetimeTics = 50;
            collisionRadiusMilliUnits = 6000;
            poolLimitInstances = 30;
            pathKind = 3;
            targetPolicy = 3;
            wallPolicy = 1;
            spreadStepMilliDegrees = 15000;
            radialChildCount = 0;
            return true;
        }
        if (systemId == SYSTEM_FIRE_WAND && rank == 5)
        {
            damageTenths = 600;
            amount = 3;
            pierce = 1;
            cooldownMillis = 3000;
            childIntervalMillis = 20;
            speedMultiplierMilli = 1150;
            areaMultiplierMilli = 1000;
            launchSpeedUnitsPerSecond = 240;
            accelerationYUnitsPerSecondSquared = 0;
            maxRangeUnits = 320;
            lifetimeTics = 41;
            collisionRadiusMilliUnits = 6000;
            poolLimitInstances = 30;
            pathKind = 3;
            targetPolicy = 3;
            wallPolicy = 1;
            spreadStepMilliDegrees = 15000;
            radialChildCount = 0;
            return true;
        }
        if (systemId == SYSTEM_FIRE_WAND && rank == 6)
        {
            damageTenths = 700;
            amount = 3;
            pierce = 1;
            cooldownMillis = 3000;
            childIntervalMillis = 20;
            speedMultiplierMilli = 1150;
            areaMultiplierMilli = 1000;
            launchSpeedUnitsPerSecond = 240;
            accelerationYUnitsPerSecondSquared = 0;
            maxRangeUnits = 320;
            lifetimeTics = 41;
            collisionRadiusMilliUnits = 6000;
            poolLimitInstances = 30;
            pathKind = 3;
            targetPolicy = 3;
            wallPolicy = 1;
            spreadStepMilliDegrees = 15000;
            radialChildCount = 0;
            return true;
        }
        if (systemId == SYSTEM_FIRE_WAND && rank == 7)
        {
            damageTenths = 800;
            amount = 3;
            pierce = 1;
            cooldownMillis = 3000;
            childIntervalMillis = 20;
            speedMultiplierMilli = 1350;
            areaMultiplierMilli = 1000;
            launchSpeedUnitsPerSecond = 240;
            accelerationYUnitsPerSecondSquared = 0;
            maxRangeUnits = 320;
            lifetimeTics = 35;
            collisionRadiusMilliUnits = 6000;
            poolLimitInstances = 30;
            pathKind = 3;
            targetPolicy = 3;
            wallPolicy = 1;
            spreadStepMilliDegrees = 15000;
            radialChildCount = 0;
            return true;
        }
        if (systemId == SYSTEM_FIRE_WAND && rank == 8)
        {
            damageTenths = 900;
            amount = 3;
            pierce = 1;
            cooldownMillis = 3000;
            childIntervalMillis = 20;
            speedMultiplierMilli = 1350;
            areaMultiplierMilli = 1000;
            launchSpeedUnitsPerSecond = 240;
            accelerationYUnitsPerSecondSquared = 0;
            maxRangeUnits = 320;
            lifetimeTics = 35;
            collisionRadiusMilliUnits = 6000;
            poolLimitInstances = 30;
            pathKind = 3;
            targetPolicy = 3;
            wallPolicy = 1;
            spreadStepMilliDegrees = 15000;
            radialChildCount = 0;
            return true;
        }
        return false;
    }

    static bool TryGetHellfireRankRow(int systemId, int rank,
        out int damageTenths, out int amount, out int pierce,
        out int cooldownMillis, out int childIntervalMillis,
        out int speedMultiplierMilli, out int areaMultiplierMilli,
        out int launchSpeedUnitsPerSecond,
        out int accelerationYUnitsPerSecondSquared,
        out int maxRangeUnits, out int lifetimeTics,
        out int collisionRadiusMilliUnits, out int poolLimitInstances,
        out int pathKind, out int targetPolicy, out int wallPolicy,
        out int spreadStepMilliDegrees, out int radialChildCount)
    {
        if (systemId == SYSTEM_HELLFIRE && rank == 1)
        {
            damageTenths = 1000;
            amount = 2;
            pierce = 1000;
            cooldownMillis = 3000;
            childIntervalMillis = 200;
            speedMultiplierMilli = 1000;
            areaMultiplierMilli = 1000;
            launchSpeedUnitsPerSecond = 240;
            accelerationYUnitsPerSecondSquared = 0;
            maxRangeUnits = 320;
            lifetimeTics = 47;
            collisionRadiusMilliUnits = 9000;
            poolLimitInstances = 20;
            pathKind = 4;
            targetPolicy = 3;
            wallPolicy = 2;
            spreadStepMilliDegrees = 15000;
            radialChildCount = 0;
            return true;
        }
        return false;
    }

    static bool TryGetTransformation(int evolvedSystemId,
        out int sourceSystemId, out int requiredSourceRank,
        out int requiredDependencyKind, out int requiredDependencyMinRank)
    {
        sourceSystemId = 0; requiredSourceRank = 0;
        requiredDependencyKind = 0; requiredDependencyMinRank = 0;
        if (evolvedSystemId == SYSTEM_DEATH_SPIRAL)
        {
            sourceSystemId = SYSTEM_AXE; requiredSourceRank = 8;
            requiredDependencyKind = DEPENDENCY_AREA;
            requiredDependencyMinRank = 1;
            return true;
        }
        if (evolvedSystemId == SYSTEM_HELLFIRE)
        {
            sourceSystemId = SYSTEM_FIRE_WAND; requiredSourceRank = 8;
            requiredDependencyKind = DEPENDENCY_POWER;
            requiredDependencyMinRank = 1;
            return true;
        }
        // N3 Track A: recipe 402 in TransformationGraph.zs (Song of Mana +
        // maxed Skull O'Maniac -> Mannajja).
        if (evolvedSystemId == DSN3Rows.SYSTEM_MANNAJJA)
        {
            sourceSystemId = DSN3Rows.SYSTEM_SONG_OF_MANA;
            requiredSourceRank = 8;
            requiredDependencyKind = DEPENDENCY_SKULL_OMANIAC;
            requiredDependencyMinRank = 1;
            return true;
        }
        // Recipe 414: maxed Magi-Stone + Karoma's Mana -> Kyra-Stones.
        if (evolvedSystemId == DSN3Rows.SYSTEM_KYRA_STONES)
        {
            sourceSystemId = DSN3Rows.SYSTEM_MAGI_STONE;
            requiredSourceRank = 8;
            requiredDependencyKind = DEPENDENCY_KAROMAS_MANA;
            requiredDependencyMinRank = 1;
            return true;
        }
        return false;
    }
}
