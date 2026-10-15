// Scalar compiled mirror of the canonical P041 bounce-weapon JSON
// (data/verified/base/weapons/bounce/runetracer.json, no-future.json,
// bone.json, cherry-bomb.json, carrello.json). Rank values are mutable
// online reports (retrieved 2026-09-27), locked v1.16.107 applicability
// unverified. Spatial/timing policy mirrors the lead-frozen
// docs/contracts/bounce-projectiles.md fixture, not source-exact geometry.
class DSP041BounceRows
{
    const SYSTEM_RUNETRACER = 54;
    const SYSTEM_NO_FUTURE = 55;
    const SYSTEM_BONE = 56;
    const SYSTEM_CHERRY = 57;
    const SYSTEM_CARRELLO = 58;

    // This is a source-key enum local to this file, not a P031 inventory
    // item ID (see DSP039AuraRows.DEPENDENCY_REGEN_SOURCE_KEY and
    // DSP040GlobalRows.DEPENDENCY_AMOUNT_SOURCE_KEY for the established
    // pattern).
    const DEPENDENCY_ARMOR_SOURCE_KEY = 1;

    // Motion/boundary fixture (docs/contracts/bounce-projectiles.md
    // "Boundary" and "Motion"). Speed = BASE_SPEED_UNITS_PER_SECOND x
    // reported speed factor; the source-screen boundary is the inclusive
    // logical-reference-v1 rectangle +/- BOUNDARY_HALF_EXTENT logical units
    // on each axis, recomputed each accepted logical tic around the current
    // logical player position.
    const BASE_SPEED_UNITS_PER_SECOND = 240;
    const BOUNDARY_HALF_EXTENT = 128;
    // Up to this many sequential reflections may be resolved within a
    // single tic's swept path, per the frozen contract.
    const MAX_REFLECTIONS_PER_TIC = 8;

    // Shared hit-delay/rehit-gate fixture. Sourced as an explicit 0.5s
    // hitbox delay for Runetracer/NO FUTURE; labelled-only (no infobox
    // field at all) for Bone/Cherry Bomb/Carréllo. The frozen contract
    // applies the same 18-tic (0.5s) value uniformly across all five
    // systems.
    const HIT_DELAY_TICS = 18;

    // Runetracer/NO FUTURE contact-radius and Cherry Bomb explosion-radius
    // adapter scales: base logical units x reported Area, in milli-units.
    const CONTACT_RADIUS_BASE_MILLI_UNITS = 6000;
    const CHERRY_EXPLOSION_RADIUS_BASE_MILLI_UNITS = 24000;

    // Runetracer child (inter-rune) stagger: 0.2s -> 7 tics at 35Hz.
    const RUNETRACER_CHILD_INTERVAL_TICS = 7;

    // NO FUTURE retaliation-explosion fixture: gated to once per 18 tics
    // (0.5s) across all live projectiles; each Armor point adds +10%
    // (100 milli) additively to the explosion damage; no numeric radius is
    // sourced, so a labelled 24-unit fixture is used (not Area-scaled,
    // unlike Cherry Bomb's explosion radius).
    const NO_FUTURE_GATE_TICS = 18;
    const NO_FUTURE_ARMOR_BONUS_MILLI = 100;
    const NO_FUTURE_EXPLOSION_RADIUS_UNITS = 24;

    static int RankCount(int system)
    {
        if (system == SYSTEM_RUNETRACER) return 8;
        if (system == SYSTEM_NO_FUTURE) return 1;
        if (system == SYSTEM_BONE) return 8;
        if (system == SYSTEM_CHERRY) return 8;
        if (system == SYSTEM_CARRELLO) return 8;
        // N3 Track A (docs/contracts/remaining-weapons.md): Anima of
        // Mortaccio, Carrozza!, Celestial Dusting, La Robba, Profusione
        // D'Amore and Yatta Daikarin join this engine as data rows.
        // DSN3Rows.RankCount already reports each identity's own rank
        // ceiling; every scalar getter below reuses the matching DSN3Rows
        // scalar directly as its own qualified source, same as the
        // DSP035WeaponRows/DSN3Rows adapter pattern for Magi-Stone/
        // Mannajja/Song of Mana.
        if (system == DSN3Rows.SYSTEM_ANIMA_OF_MORTACCIO
            || system == DSN3Rows.SYSTEM_CARROZZA
            || system == DSN3Rows.SYSTEM_CELESTIAL_DUSTING
            || system == DSN3Rows.SYSTEM_LA_ROBBA
            || system == DSN3Rows.SYSTEM_PROFUSIONE_DAMORE
            || system == DSN3Rows.SYSTEM_YATTA_DAIKARIN)
            return DSN3Rows.RankCount(system);
        return 0;
    }

    static bool ValidRank(int system, int rank)
    {
        int count = RankCount(system);
        return count > 0 && rank >= 1 && rank <= count;
    }

    // Source damage x1000 (milli-damage), per rank.
    // Research rows that are missing or implausible for the evolved bounce
    // weapons (Profusione D'Amore damage 0 / speed 0.014x, Carrozza! area
    // 0.01x / speed 0.1x, Anima of Mortaccio cooldown 0) left them unable to
    // fire or nearly invisible. Wiki-style approximations: their base
    // weapon's top values.
    static int N3Fallback(int system, String field, int v)
    {
        if (field == "damage" && v <= 0) return 10000;
        if ((field == "area" || field == "speed") && v < 200)
            return system == DSN3Rows.SYSTEM_PROFUSIONE_DAMORE && field == "speed" ? 1600 : 1000;
        if (field == "cooldown" && v <= 0) return 105;
        return v;
    }

    static int DamageMilli(int system, int rank)
    {
        if (system == SYSTEM_NO_FUTURE) return rank == 1 ? 30000 : 0;
        if (!ValidRank(system, rank)) return 0;
        if (system == SYSTEM_RUNETRACER)
        {
            if (rank == 1) return 10000;
            if (rank == 2) return 15000;
            if (rank == 3) return 20000;
            if (rank == 4) return 20000;
            if (rank == 5) return 25000;
            if (rank == 6) return 30000;
            if (rank == 7) return 30000;
            return 30000; // rank 8
        }
        if (system == SYSTEM_BONE)
        {
            if (rank == 1) return 5000;
            if (rank == 2) return 5000;
            if (rank == 3) return 25000;
            if (rank == 4) return 25000;
            if (rank == 5) return 45000;
            if (rank == 6) return 45000;
            if (rank == 7) return 65000;
            return 65000; // rank 8
        }
        if (system == SYSTEM_CHERRY)
        {
            if (rank == 1) return 10000;
            if (rank == 2) return 10000;
            if (rank == 3) return 10000;
            if (rank == 4) return 10000;
            if (rank == 5) return 15000;
            if (rank == 6) return 15000;
            if (rank == 7) return 15000;
            return 20000; // rank 8
        }
        if (system == SYSTEM_CARRELLO)
        {
            if (rank == 1) return 10000;
            if (rank == 2) return 10000;
            if (rank == 3) return 40000;
            if (rank == 4) return 40000;
            if (rank == 5) return 70000;
            if (rank == 6) return 70000;
            if (rank == 7) return 100000;
            return 100000; // rank 8
        }
        // N3 Track A (docs/contracts/remaining-weapons.md): direct
        // passthrough of DSN3Rows' own qualified per-rank milli-damage
        // scalar for each of the six new identities.
        if (system == DSN3Rows.SYSTEM_ANIMA_OF_MORTACCIO
            || system == DSN3Rows.SYSTEM_CARROZZA
            || system == DSN3Rows.SYSTEM_CELESTIAL_DUSTING
            || system == DSN3Rows.SYSTEM_LA_ROBBA
            || system == DSN3Rows.SYSTEM_PROFUSIONE_DAMORE
            || system == DSN3Rows.SYSTEM_YATTA_DAIKARIN)
            return N3Fallback(system, "damage", DSN3Rows.DamageMilli(system, rank));
        return 0;
    }

    // Reported Area multiplier in milli (1000 = 100%), per rank. NO FUTURE
    // has no reported Area stat; callers get the neutral 1000 (100%)
    // baseline, matching its JSON row.
    static int AreaMilli(int system, int rank)
    {
        if (system == SYSTEM_NO_FUTURE) return rank == 1 ? 1000 : 0;
        if (!ValidRank(system, rank)) return 0;
        if (system == SYSTEM_RUNETRACER) return 1000; // flat every rank
        if (system == SYSTEM_BONE)
        {
            if (rank == 1) return 1200;
            if (rank == 2) return 1400;
            if (rank == 3) return 1400;
            if (rank == 4) return 1600;
            if (rank == 5) return 1600;
            if (rank == 6) return 1600;
            if (rank == 7) return 1600;
            return 1600; // rank 8
        }
        if (system == SYSTEM_CHERRY)
        {
            if (rank == 1) return 1000;
            if (rank == 2) return 1250;
            if (rank == 3) return 1250;
            if (rank == 4) return 1250;
            if (rank == 5) return 1500;
            if (rank == 6) return 1500;
            if (rank == 7) return 1750;
            return 2000; // rank 8
        }
        if (system == SYSTEM_CARRELLO)
        {
            if (rank == 1) return 600;
            if (rank == 2) return 800;
            if (rank == 3) return 800;
            if (rank == 4) return 800;
            if (rank == 5) return 800;
            if (rank == 6) return 1000;
            if (rank == 7) return 1000;
            return 1000; // rank 8
        }
        // N3 Track A: direct passthrough of DSN3Rows' own Area scalar.
        if (system == DSN3Rows.SYSTEM_ANIMA_OF_MORTACCIO
            || system == DSN3Rows.SYSTEM_CARROZZA
            || system == DSN3Rows.SYSTEM_CELESTIAL_DUSTING
            || system == DSN3Rows.SYSTEM_LA_ROBBA
            || system == DSN3Rows.SYSTEM_PROFUSIONE_DAMORE
            || system == DSN3Rows.SYSTEM_YATTA_DAIKARIN)
            return N3Fallback(system, "area", DSN3Rows.AreaMilli(system, rank));
        return 0;
    }

    // Reported Speed multiplier in milli (1000 = 100%), per rank. Combined
    // with BASE_SPEED_UNITS_PER_SECOND at runtime, not returned here.
    static int SpeedMilli(int system, int rank)
    {
        if (system == SYSTEM_NO_FUTURE) return rank == 1 ? 2800 : 0;
        if (!ValidRank(system, rank)) return 0;
        if (system == SYSTEM_RUNETRACER)
        {
            if (rank == 1) return 1000;
            if (rank == 2) return 1200;
            if (rank == 3) return 1200;
            if (rank == 4) return 1200;
            if (rank == 5) return 1400;
            if (rank == 6) return 1400;
            if (rank == 7) return 1400;
            return 1400; // rank 8
        }
        if (system == SYSTEM_BONE)
        {
            if (rank == 1) return 750;
            if (rank == 2) return 750;
            if (rank == 3) return 750;
            if (rank == 4) return 1250;
            if (rank == 5) return 1250;
            if (rank == 6) return 1250;
            if (rank == 7) return 1250;
            return 1750; // rank 8
        }
        if (system == SYSTEM_CHERRY)
        {
            if (rank == 1) return 1000;
            if (rank == 2) return 1300;
            if (rank == 3) return 1300;
            if (rank == 4) return 1300;
            if (rank == 5) return 1300;
            if (rank == 6) return 1300;
            if (rank == 7) return 1600;
            return 1600; // rank 8
        }
        if (system == SYSTEM_CARRELLO)
        {
            if (rank == 1) return 1000;
            if (rank == 2) return 1000;
            if (rank == 3) return 1000;
            if (rank == 4) return 1500;
            if (rank == 5) return 1500;
            if (rank == 6) return 1500;
            if (rank == 7) return 1500;
            return 2000; // rank 8
        }
        // N3 Track A: direct passthrough of DSN3Rows' own Speed scalar.
        if (system == DSN3Rows.SYSTEM_ANIMA_OF_MORTACCIO
            || system == DSN3Rows.SYSTEM_CARROZZA
            || system == DSN3Rows.SYSTEM_CELESTIAL_DUSTING
            || system == DSN3Rows.SYSTEM_LA_ROBBA
            || system == DSN3Rows.SYSTEM_PROFUSIONE_DAMORE
            || system == DSN3Rows.SYSTEM_YATTA_DAIKARIN)
            return N3Fallback(system, "speed", DSN3Rows.SpeedMilli(system, rank));
        return 0;
    }

    // Row (base) simultaneous-projectile Amount, per rank. Carréllo is flat
    // 2 every rank; the frozen contract derives its bounce budget from this
    // value (see BounceBudget below).
    static int Amount(int system, int rank)
    {
        if (system == SYSTEM_NO_FUTURE) return rank == 1 ? 1 : 0;
        if (!ValidRank(system, rank)) return 0;
        if (system == SYSTEM_RUNETRACER)
        {
            if (rank == 1) return 1;
            if (rank == 2) return 1;
            if (rank == 3) return 1;
            if (rank == 4) return 2;
            if (rank == 5) return 2;
            if (rank == 6) return 2;
            if (rank == 7) return 3;
            return 3; // rank 8
        }
        if (system == SYSTEM_BONE)
        {
            if (rank == 1) return 1;
            if (rank == 2) return 1;
            if (rank == 3) return 2;
            if (rank == 4) return 2;
            if (rank == 5) return 3;
            if (rank == 6) return 3;
            if (rank == 7) return 3;
            return 3; // rank 8
        }
        if (system == SYSTEM_CHERRY)
        {
            if (rank == 1) return 1;
            if (rank == 2) return 1;
            if (rank == 3) return 1;
            if (rank == 4) return 2;
            if (rank == 5) return 2;
            if (rank == 6) return 2;
            if (rank == 7) return 2;
            return 2; // rank 8
        }
        if (system == SYSTEM_CARRELLO) return 2; // flat every rank
        // N3 Track A: direct passthrough of DSN3Rows' own Amount scalar.
        if (system == DSN3Rows.SYSTEM_ANIMA_OF_MORTACCIO
            || system == DSN3Rows.SYSTEM_CARROZZA
            || system == DSN3Rows.SYSTEM_CELESTIAL_DUSTING
            || system == DSN3Rows.SYSTEM_LA_ROBBA
            || system == DSN3Rows.SYSTEM_PROFUSIONE_DAMORE
            || system == DSN3Rows.SYSTEM_YATTA_DAIKARIN)
            return DSN3Rows.Amount(system, rank);
        return 0;
    }

    // Duration in tics by nearest-tic rounding at 35Hz, per rank. Carréllo
    // has no reported duration (its lifetime is bounded by BounceBudget
    // instead), so it returns 0/not-applicable throughout.
    static int DurationTics(int system, int rank)
    {
        if (system == SYSTEM_NO_FUTURE) return rank == 1 ? 105 : 0;
        if (!ValidRank(system, rank)) return 0;
        if (system == SYSTEM_RUNETRACER)
        {
            if (rank == 1) return 79;
            if (rank == 2) return 79;
            if (rank == 3) return 89;
            if (rank == 4) return 89;
            if (rank == 5) return 89;
            if (rank == 6) return 100;
            if (rank == 7) return 100;
            return 114; // rank 8
        }
        if (system == SYSTEM_BONE)
        {
            if (rank == 1) return 70;
            if (rank == 2) return 77;
            if (rank == 3) return 77;
            if (rank == 4) return 77;
            if (rank == 5) return 77;
            if (rank == 6) return 84;
            if (rank == 7) return 84;
            return 91; // rank 8
        }
        if (system == SYSTEM_CHERRY) return 70; // flat 2.0s every rank
        if (system == SYSTEM_CARRELLO) return 0; // not applicable (UNKNOWN)
        // N3 Track A: direct passthrough of DSN3Rows' own Duration scalar.
        // Carrozza!'s own DSN3Rows.DurationTics reports 0 (no source
        // duration, same "not applicable" shape as Carréllo, its base
        // weapon) so it falls through to the same DSP041_UNBOUNDED_
        // DURATION_TICS/BounceBudget-bounded lifetime path below.
        if (system == DSN3Rows.SYSTEM_ANIMA_OF_MORTACCIO
            || system == DSN3Rows.SYSTEM_CARROZZA
            || system == DSN3Rows.SYSTEM_CELESTIAL_DUSTING
            || system == DSN3Rows.SYSTEM_LA_ROBBA
            || system == DSN3Rows.SYSTEM_PROFUSIONE_DAMORE
            || system == DSN3Rows.SYSTEM_YATTA_DAIKARIN)
            return DSN3Rows.DurationTics(system, rank);
        return 0;
    }

    // Activation period in tics before the P033 Cooldown multiplier is
    // applied. Runetracer/NO FUTURE/Bone/Cherry Bomb use a flat Cooldown;
    // Carréllo's Cooldown rises per rank (5.5s..6.4s), converted by
    // nearest-tic (round-half-up) rounding at 35Hz.
    static int CooldownTics(int system, int rank)
    {
        if (system == SYSTEM_NO_FUTURE) return rank == 1 ? 35 : 0;
        if (!ValidRank(system, rank)) return 0;
        if (system == SYSTEM_RUNETRACER) return 105; // flat 3.0s
        if (system == SYSTEM_BONE) return 105; // flat 3.0s
        if (system == SYSTEM_CHERRY) return 105; // flat 3.0s
        if (system == SYSTEM_CARRELLO)
        {
            if (rank <= 2) return 193; // 5.5s -> 192.5 -> 193
            if (rank <= 4) return 203; // 5.8s -> 203
            if (rank <= 6) return 214; // 6.1s -> 213.5 -> 214
            return 224; // ranks 7-8: 6.4s -> 224
        }
        // N3 Track A: direct passthrough of DSN3Rows' own Cooldown scalar.
        if (system == DSN3Rows.SYSTEM_ANIMA_OF_MORTACCIO
            || system == DSN3Rows.SYSTEM_CARROZZA
            || system == DSN3Rows.SYSTEM_CELESTIAL_DUSTING
            || system == DSN3Rows.SYSTEM_LA_ROBBA
            || system == DSN3Rows.SYSTEM_PROFUSIONE_DAMORE
            || system == DSN3Rows.SYSTEM_YATTA_DAIKARIN)
            return N3Fallback(system, "cooldown", DSN3Rows.CooldownTics(system, rank));
        return 0;
    }

    // Runetracer-only inter-rune stagger; every other system has no child
    // interval and returns 0.
    static int ChildIntervalTics(int system, int rank)
    {
        if (system == SYSTEM_RUNETRACER && ValidRank(system, rank))
            return RUNETRACER_CHILD_INTERVAL_TICS;
        return 0;
    }

    // Shared same-pair rehit gate, flat across every system and rank.
    static int HitDelayTics(int system, int rank)
    {
        if (!ValidRank(system, rank)) return 0;
        return HIT_DELAY_TICS;
    }

    // CONTACT_RADIUS_BASE_MILLI_UNITS x reported Area, in milli-units.
    static int ContactRadiusMilliUnits(int system, int rank)
    {
        int areaMilli = AreaMilli(system, rank);
        if (areaMilli <= 0) return 0;
        return CONTACT_RADIUS_BASE_MILLI_UNITS * areaMilli / 1000;
    }

    // Cherry Bomb-only stop-triggered explosion chance in milli (1000 =
    // 100%); every other system returns 0.
    static int ExplosionChanceMilli(int system, int rank)
    {
        // N3 Track A: Yatta Daikarin (evolved Cherry Bomb) "generates extra
        // explosions" per the research mechanic, but has no source
        // explosion-chance percentage of its own -- ENGINEERING_FALLBACK
        // reuses Cherry Bomb's own max-rank (8) reported 60% chance, since
        // Yatta Daikarin is itself always rank 1 (evolution-only, maxed).
        if (system == DSN3Rows.SYSTEM_YATTA_DAIKARIN && ValidRank(system, rank))
            return 600;
        if (system != SYSTEM_CHERRY || !ValidRank(system, rank)) return 0;
        if (rank == 1) return 400;
        if (rank == 2) return 400;
        if (rank == 3) return 500;
        if (rank == 4) return 500;
        if (rank == 5) return 500;
        if (rank == 6) return 600;
        if (rank == 7) return 600;
        return 600; // rank 8
    }

    // Explosion radius in milli-units. Cherry Bomb scales with its own
    // reported Area (CHERRY_EXPLOSION_RADIUS_BASE_MILLI_UNITS x Area); NO
    // FUTURE uses the flat labelled NO_FUTURE_EXPLOSION_RADIUS_UNITS
    // fixture instead (no reported Area to scale by). Every other system
    // has no explosion and returns 0.
    static int ExplosionRadiusMilliUnits(int system, int rank)
    {
        if (system == SYSTEM_CHERRY && ValidRank(system, rank))
        {
            int areaMilli = AreaMilli(system, rank);
            return CHERRY_EXPLOSION_RADIUS_BASE_MILLI_UNITS * areaMilli / 1000;
        }
        if (system == SYSTEM_NO_FUTURE && rank == 1)
            return NO_FUTURE_EXPLOSION_RADIUS_UNITS * 1000;
        // N3 Track A: same Area-scaled formula as Cherry Bomb above, applied
        // to Yatta Daikarin's own AreaMilli (see ExplosionChanceMilli).
        if (system == DSN3Rows.SYSTEM_YATTA_DAIKARIN && ValidRank(system, rank))
        {
            int areaMilli = AreaMilli(system, rank);
            return CHERRY_EXPLOSION_RADIUS_BASE_MILLI_UNITS * areaMilli / 1000;
        }
        return 0;
    }

    // Bounce budget: -1 means unlimited (Runetracer, NO FUTURE, Bone, Cherry
    // Bomb per the contract's reported no-numeric-cap facts). Carréllo's
    // budget is Amount - 1, flat 1 since Amount never changes.
    static int BounceBudget(int system, int rank)
    {
        if (!ValidRank(system, rank)) return -1;
        // N3 Track A: Carrozza! (evolved Carréllo) inherits the same
        // finite-budget shape as its base weapon.
        if (system == SYSTEM_CARRELLO || system == DSN3Rows.SYSTEM_CARROZZA)
            return Amount(system, rank) - 1;
        return -1;
    }

    // P041-A04 data-driven policy flags: which systems pierce enemies
    // without deflecting versus which reflect off the first enemy contacted
    // and hit once per gated pair. Exactly one of the two is true for every
    // valid system; both are false for an unrecognized system id.
    //
    // N3 Track A (docs/contracts/remaining-weapons.md): the four new
    // identities are classified by which existing archetype they mechanically
    // match. Celestial Dusting/La Robba report Pierce "Area of Effect"
    // (DSN3Rows.Pierce returns the -1 sentinel), the same unlimited-pierce
    // shape as Runetracer/NO FUTURE, so they pierce. Profusione D'Amore
    // evolves Celestial Dusting and inherits its base weapon's classification
    // (its own "periodic chain explosion" mechanic is an unimplemented
    // ENGINEERING_FALLBACK, same treatment as Mannajja's unwired slow-on-hit
    // status -- out of this worker's engine-mechanic scope). Carrozza!
    // evolves Carréllo (a piercing, finite-budget system) and inherits that
    // classification too. Anima of Mortaccio and Yatta Daikarin evolve
    // Bone/Cherry Bomb respectively, both BouncesOffEnemies systems, and
    // inherit that classification (see BouncesOffEnemies below); their own
    // "accelerate on bounce" / extra-explosion mechanics beyond Cherry's
    // existing explosion-on-expiry path are likewise unimplemented labelled
    // fallbacks.
    static bool PiercesEnemies(int system)
    {
        return system == SYSTEM_RUNETRACER || system == SYSTEM_NO_FUTURE
            || system == SYSTEM_CARRELLO
            || system == DSN3Rows.SYSTEM_CELESTIAL_DUSTING
            || system == DSN3Rows.SYSTEM_LA_ROBBA
            || system == DSN3Rows.SYSTEM_PROFUSIONE_DAMORE
            || system == DSN3Rows.SYSTEM_CARROZZA;
    }

    static bool BouncesOffEnemies(int system)
    {
        return system == SYSTEM_BONE || system == SYSTEM_CHERRY
            || system == DSN3Rows.SYSTEM_ANIMA_OF_MORTACCIO
            || system == DSN3Rows.SYSTEM_YATTA_DAIKARIN;
    }

    // Evolution edge. Mirrors DSP040GlobalRows.TryGetEvolution's signature:
    // takes the equipped dependencyItem as an input and only reports
    // whether that specific combination evolves.
    static bool TryGetEvolution(int sourceSystem, int sourceRank,
        int dependencyItem, out int evolvedSystem)
    {
        evolvedSystem = 0;
        if (sourceSystem == SYSTEM_RUNETRACER && sourceRank >= 8
            && dependencyItem == DEPENDENCY_ARMOR_SOURCE_KEY)
        {
            evolvedSystem = SYSTEM_NO_FUTURE;
            return true;
        }
        // N3 Track A (bounce engine, docs/contracts/remaining-weapons.md):
        // recipes 406/417/418/419 apply through the generic N2 EvolveWeapon
        // dispatcher (VerticalSlice.zs EvolveWeapon's N2_ENGINE_BOUNCE
        // branch), which always calls DSP041TransformFixture with a literal
        // dependencyItem of 0 for this engine -- the real passive-rank gate
        // (Chaos Malachite/Rosalia/Lazulia/Altemanna) is already checked by
        // DSP032CanApplyRecipe/DSP032ApplyRecipe before EvolveWeapon is ever
        // called, so these four edges are keyed by dependencyItem==0 plus
        // max source rank, not a source-key match like Runetracer/NO
        // FUTURE's DEPENDENCY_ARMOR_SOURCE_KEY above.
        if (dependencyItem == 0 && sourceRank >= 8)
        {
            if (sourceSystem == SYSTEM_BONE)
            {
                evolvedSystem = DSN3Rows.SYSTEM_ANIMA_OF_MORTACCIO;
                return true;
            }
            if (sourceSystem == SYSTEM_CHERRY)
            {
                evolvedSystem = DSN3Rows.SYSTEM_YATTA_DAIKARIN;
                return true;
            }
            if (sourceSystem == SYSTEM_CARRELLO)
            {
                evolvedSystem = DSN3Rows.SYSTEM_CARROZZA;
                return true;
            }
            if (sourceSystem == DSN3Rows.SYSTEM_CELESTIAL_DUSTING)
            {
                evolvedSystem = DSN3Rows.SYSTEM_PROFUSIONE_DAMORE;
                return true;
            }
        }
        return false;
    }
}
