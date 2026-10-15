// Scalar compiled mirror of the canonical P042 paired-weapon JSON
// (data/verified/base/weapons/paired/*.json). Rank values are mutable
// online reports (MediaWiki-API verbatim infobox/level-up text, retrieved
// 2026-09-28, research section 6a); locked v1.16.107 applicability is
// unverified. Union/chain predicates and adapter geometry mirror the
// lead-frozen docs/contracts/paired-unions.md fixture, not source-exact
// geometry. System ids 59-69 and the Tirajisu passive key 70 are shared
// verbatim with DSP032TransformationGraph's DSP032_ID_* constants
// (src/zscript/gameplay/transformations/TransformationGraph.zs) so the
// graph and this runtime data agree on identity; this file does not edit
// that mixin, it only reuses its numbering.
class DSP042PairedRows
{
    const SYSTEM_PEACHONE = 59;
    const SYSTEM_EBONY = 60;
    const SYSTEM_VANDALIER = 61;
    const SYSTEM_PHIERA = 62;
    const SYSTEM_EIGHT = 63;
    const SYSTEM_PHIERAGGI = 64;
    const SYSTEM_VENTO = 65;
    const SYSTEM_FUWALA = 66;
    const SYSTEM_BRACELET = 67;
    const SYSTEM_BI_BRACELET = 68;
    const SYSTEM_TRI_BRACELET = 69;

    // Passive key for REVIVAL (Tirajisu), gating the Phieraggi union.
    // Matches DSP032_ID_TIRAJISU (70) verbatim; rank >= 1 required, never
    // consumed (P032 keeps passives on every union per the contract).
    const REVIVAL_PASSIVE_KEY = 70;

    // VAMPIRICA (Bloody Tear) is Fuwalafuwaloo's second *weapon* input, not
    // a passive, and is not a new P042 identity: it reuses the existing
    // P032 Bloody Tear item id (DSP032_ID_BLOODY_TEAR = 6 / P033
    // DSP033StatRules.SYSTEM_BLOODY_TEAR = 6) verbatim.
    const VAMPIRICA_INPUT_KEY = 6;

    // Shared 240 u/s baseline (matches DSP041BounceRows and the contract's
    // gun-projectile adapter); combined with SpeedMilli at runtime.
    const GUN_BASE_SPEED_UNITS_PER_SECOND = 240;
    const GUN_PROJECTILE_RADIUS = 6;

    // Bird orbit/impact adapter (Peachone/Ebony Wings/Vandalier).
    const BIRD_ORBIT_RADIUS = 72;
    const BIRD_IMPACT_RADIUS = 20;

    // Phiera fires character-relative diagonals; Eight fires the fixed
    // source-plane diagonals; Phieraggi's four beams start at 90-degree
    // spacing and advance by this step per volley.
    const PHIERA_FACING_DEG_A = 45;
    const PHIERA_FACING_DEG_B = 135;
    const EIGHT_FIXED_DIAGONAL_DEG_1 = 45;
    const EIGHT_FIXED_DIAGONAL_DEG_2 = 135;
    const EIGHT_FIXED_DIAGONAL_DEG_3 = 225;
    const EIGHT_FIXED_DIAGONAL_DEG_4 = 315;
    const PHIERAGGI_ROTATION_STEP_DEG = 15;

    // Vento Sacro / Fuwalafuwaloo facing-arc slash adapter.
    const VENTO_ARC_REACH = 96;
    const VENTO_ARC_HALF_DEG = 60;

    // Shared movement-streak fixture: a continuous-movement bonus that
    // grows every STREAK_PERIOD_TICS of uninterrupted body movement and
    // resets when movement stops. Vento Sacro and Fuwalafuwaloo use
    // different step/cap pairs on the same period.
    const STREAK_PERIOD_TICS = 35;
    const VENTO_STREAK_STEP = 1;
    const VENTO_STREAK_CAP = 5;
    const FUWALA_STREAK_STEP = 8;
    const FUWALA_STREAK_CAP = 40;

    // Fuwalafuwaloo crit-heal fixture, routed through the P039 healing
    // authority: 8 HP per accepted crit, gated to once per 18 tics. Prose
    // only (low confidence), no infobox field sources either number.
    const FUWALA_HEAL_MILLI = 8000;
    const FUWALA_HEAL_GATE_TICS = 18;

    // Vento Sacro / Fuwalafuwaloo shared crit fixture (verbatim: chance=5%,
    // critMul=2x on both infoboxes) on the dedicated P042_CRIT stream.
    const CRIT_CHANCE_MILLI = 50;
    const CRIT_MULTIPLIER_MILLI = 2000;

    static int RankCount(int system)
    {
        if (system == SYSTEM_PEACHONE) return 8;
        if (system == SYSTEM_EBONY) return 8;
        if (system == SYSTEM_VANDALIER) return 8;
        if (system == SYSTEM_PHIERA) return 8;
        if (system == SYSTEM_EIGHT) return 8;
        if (system == SYSTEM_PHIERAGGI) return 1;
        if (system == SYSTEM_VENTO) return 8;
        if (system == SYSTEM_FUWALA) return 1;
        if (system == SYSTEM_BRACELET) return 6;
        if (system == SYSTEM_BI_BRACELET) return 6;
        if (system == SYSTEM_TRI_BRACELET) return 6;
        return 0;
    }

    static bool ValidRank(int system, int rank)
    {
        int count = RankCount(system);
        return count > 0 && rank >= 1 && rank <= count;
    }

    static bool IsBird(int system) { return system == SYSTEM_PEACHONE || system == SYSTEM_EBONY; }
    static bool IsGun(int system) { return system == SYSTEM_PHIERA || system == SYSTEM_EIGHT; }
    static bool IsBracelet(int system)
    {
        return system == SYSTEM_BRACELET || system == SYSTEM_BI_BRACELET
            || system == SYSTEM_TRI_BRACELET;
    }

    // Source damage x1000 (milli-damage), per rank.
    static int DamageMilli(int system, int rank)
    {
        if (system == SYSTEM_PHIERAGGI) return rank == 1 ? 15000 : 0;
        if (system == SYSTEM_FUWALA) return rank == 1 ? 20000 : 0;
        if (!ValidRank(system, rank)) return 0;
        if (IsBird(system))
        {
            if (rank == 1) return 10000;
            if (rank == 2) return 10000;
            if (rank == 3) return 20000;
            if (rank == 4) return 20000;
            if (rank == 5) return 20000;
            if (rank == 6) return 30000;
            if (rank == 7) return 30000;
            return 30000; // rank 8
        }
        if (system == SYSTEM_VANDALIER) return 28000; // flat every rank
        if (IsGun(system))
        {
            if (rank == 1) return 5000;
            if (rank == 2) return 5000;
            if (rank == 3) return 5000;
            if (rank == 4) return 5000;
            if (rank == 5) return 10000;
            if (rank == 6) return 10000;
            if (rank == 7) return 15000;
            return 15000; // rank 8
        }
        if (system == SYSTEM_VENTO)
        {
            if (rank == 1) return 2000;
            if (rank == 2) return 3000;
            if (rank == 3) return 3000;
            if (rank == 4) return 4000;
            if (rank == 5) return 4000;
            if (rank == 6) return 5000;
            if (rank == 7) return 5000;
            return 6000; // rank 8
        }
        if (system == SYSTEM_BRACELET)
        {
            if (rank == 1) return 10000;
            if (rank == 2) return 20000;
            if (rank == 3) return 20000;
            if (rank == 4) return 20000;
            if (rank == 5) return 20000;
            return 30000; // rank 6
        }
        if (system == SYSTEM_BI_BRACELET) return 30000; // flat every rank
        if (system == SYSTEM_TRI_BRACELET)
        {
            if (rank == 1) return 30000;
            if (rank == 2) return 30000;
            if (rank == 3) return 30000;
            if (rank == 4) return 50000;
            if (rank == 5) return 50000;
            return 50000; // rank 6
        }
        return 0;
    }

    // Reported Area multiplier in milli (1000 = 100%), per rank.
    static int AreaMilli(int system, int rank)
    {
        if (system == SYSTEM_PHIERAGGI) return rank == 1 ? 1000 : 0;
        if (system == SYSTEM_FUWALA) return rank == 1 ? 2000 : 0;
        if (!ValidRank(system, rank)) return 0;
        if (IsBird(system))
        {
            if (rank == 1) return 1000;
            if (rank == 2) return 1400;
            if (rank == 3) return 1400;
            if (rank == 4) return 1400;
            if (rank == 5) return 1800;
            if (rank == 6) return 1800;
            if (rank == 7) return 1800;
            return 2200; // rank 8
        }
        if (system == SYSTEM_VANDALIER)
        {
            if (rank == 1) return 2200;
            if (rank == 2) return 2400;
            if (rank == 3) return 2400;
            if (rank == 4) return 2600;
            if (rank == 5) return 2600;
            if (rank == 6) return 2800;
            if (rank == 7) return 2800;
            return 3000; // rank 8
        }
        if (IsGun(system)) return 1000; // flat every rank; no max-area field
        if (system == SYSTEM_VENTO)
        {
            if (rank == 1) return 1400;
            if (rank == 2) return 1400;
            if (rank == 3) return 1600;
            if (rank == 4) return 1600;
            if (rank == 5) return 1800;
            if (rank == 6) return 1800;
            if (rank == 7) return 2000;
            return 2000; // rank 8
        }
        if (system == SYSTEM_BRACELET)
        {
            if (rank == 1) return 900;
            if (rank == 2) return 900;
            if (rank == 3) return 900;
            if (rank == 4) return 1000;
            if (rank == 5) return 1000;
            return 1000; // rank 6
        }
        if (system == SYSTEM_BI_BRACELET)
        {
            if (rank == 1) return 1000;
            if (rank == 2) return 1000;
            if (rank == 3) return 1100;
            if (rank == 4) return 1100;
            if (rank == 5) return 1200;
            return 1200; // rank 6
        }
        if (system == SYSTEM_TRI_BRACELET)
        {
            if (rank == 1) return 1200;
            if (rank == 2) return 1300;
            if (rank == 3) return 1300;
            if (rank == 4) return 1300;
            if (rank == 5) return 1300;
            return 1400; // rank 6
        }
        return 0;
    }

    // Reported Speed multiplier in milli (1000 = 100%), per rank. For the
    // gun pair this combines with GUN_BASE_SPEED_UNITS_PER_SECOND at
    // runtime, not here.
    static int SpeedMilli(int system, int rank)
    {
        if (system == SYSTEM_PHIERAGGI) return rank == 1 ? 1000 : 0;
        if (system == SYSTEM_FUWALA) return rank == 1 ? 1000 : 0;
        if (!ValidRank(system, rank)) return 0;
        if (IsBird(system)) return 800; // flat 80% every rank; not per-level upgraded
        if (system == SYSTEM_VANDALIER) return 1000; // flat 100%
        if (IsGun(system))
        {
            if (rank <= 6) return 1000;
            return 1500; // ranks 7-8: +50% at L7
        }
        if (system == SYSTEM_VENTO) return 1000; // flat every rank
        if (IsBracelet(system)) return 1000; // flat every rank, all three systems
        return 0;
    }

    // Row (base) simultaneous Amount, per rank.
    static int Amount(int system, int rank)
    {
        if (system == SYSTEM_PHIERAGGI) return rank == 1 ? 4 : 0;
        if (system == SYSTEM_FUWALA) return rank == 1 ? 8 : 0;
        if (!ValidRank(system, rank)) return 0;
        if (IsBird(system))
        {
            if (rank == 1) return 4;
            if (rank == 2) return 5;
            if (rank == 3) return 6;
            if (rank == 4) return 7;
            if (rank == 5) return 8;
            if (rank == 6) return 9;
            if (rank == 7) return 10;
            return 11; // rank 8
        }
        if (system == SYSTEM_VANDALIER) return 20; // flat every rank
        if (IsGun(system))
        {
            if (rank == 1) return 1;
            if (rank == 2) return 2;
            if (rank == 3) return 2;
            if (rank == 4) return 3;
            return 3; // ranks 5-8
        }
        if (system == SYSTEM_VENTO)
        {
            if (rank == 1) return 4;
            if (rank == 2) return 4;
            if (rank == 3) return 5;
            if (rank == 4) return 5;
            if (rank == 5) return 6;
            if (rank == 6) return 6;
            if (rank == 7) return 7;
            return 7; // rank 8
        }
        if (system == SYSTEM_BRACELET)
        {
            if (rank <= 3) return 3;
            return 4; // ranks 4-6
        }
        if (system == SYSTEM_BI_BRACELET)
        {
            if (rank <= 2) return 4;
            if (rank <= 4) return 5;
            return 6; // ranks 5-6
        }
        if (system == SYSTEM_TRI_BRACELET)
        {
            if (rank == 1) return 6;
            if (rank == 2) return 7;
            if (rank == 3) return 7;
            if (rank == 4) return 8;
            if (rank == 5) return 8;
            return 9; // rank 6
        }
        return 0;
    }

    // Pierce, per rank. 0 for systems with no pierce field (birds/Vandalier
    // report "Area of Effect" instead of a numeric pierce cap).
    static int Pierce(int system, int rank)
    {
        if (system == SYSTEM_PHIERAGGI) return rank == 1 ? 7 : 0;
        if (system == SYSTEM_FUWALA) return 0; // "Area of Effect", no numeric cap
        if (!ValidRank(system, rank)) return 0;
        if (IsGun(system))
        {
            if (rank == 1) return 1;
            if (rank == 2) return 1;
            if (rank == 3) return 3;
            if (rank == 4) return 3;
            if (rank == 5) return 3;
            if (rank == 6) return 5;
            if (rank == 7) return 5;
            return 7; // rank 8
        }
        if (system == SYSTEM_BRACELET)
        {
            if (rank == 1) return 1;
            if (rank == 2) return 1;
            if (rank == 3) return 2;
            if (rank == 4) return 2;
            if (rank == 5) return 3;
            return 3; // rank 6
        }
        if (system == SYSTEM_BI_BRACELET)
        {
            if (rank == 1) return 3;
            if (rank <= 5) return 4;
            return 5; // rank 6
        }
        if (system == SYSTEM_TRI_BRACELET) return 5; // flat every rank
        return 0; // birds/Vandalier/Vento: "Area of Effect", no numeric pierce
    }

    // Activation period in tics before the P033 Cooldown multiplier is
    // applied.
    static int CooldownTics(int system, int rank)
    {
        if (system == SYSTEM_PHIERAGGI) return rank == 1 ? 49 : 0; // 1.4s
        if (system == SYSTEM_FUWALA) return rank == 1 ? 70 : 0; // 2.0s
        if (!ValidRank(system, rank)) return 0;
        if (IsBird(system))
        {
            if (rank <= 3) return 35; // 1.0s
            if (rank <= 6) return 25; // 0.7s
            return 14; // ranks 7-8: 0.4s
        }
        if (system == SYSTEM_VANDALIER)
        {
            if (rank <= 2) return 35; // 1.0s
            if (rank <= 4) return 26; // 0.75s -> 26.25 -> 26
            if (rank <= 6) return 18; // 0.50s -> 17.5 -> 18
            return 9; // ranks 7-8: 0.25s -> 8.75 -> 9
        }
        if (IsGun(system)) return 49; // flat 1.4s
        if (system == SYSTEM_VENTO) return 70; // flat 2.0s
        if (system == SYSTEM_BRACELET) return 49; // flat 1.4s
        if (system == SYSTEM_BI_BRACELET) return rank <= 3 ? 49 : 42; // 1.4s -> 1.2s at L4
        if (system == SYSTEM_TRI_BRACELET)
        {
            if (rank <= 2) return 42; // 1.2s
            if (rank <= 4) return 35; // 1.0s
            return 28; // ranks 5-6: 0.8s
        }
        return 0;
    }

    // Inter-shot interval in tics (guns/birds/bracelets); 0 for the two
    // union outputs' own row (they still report interval, folded in
    // separately below via IntervalTics for completeness).
    static int IntervalTics(int system, int rank)
    {
        if (system == SYSTEM_PHIERAGGI) return rank == 1 ? 4 : 0; // 0.1s -> 3.5 -> 4
        if (system == SYSTEM_FUWALA) return rank == 1 ? 2 : 0; // 0.05s -> 1.75 -> 2
        if (!ValidRank(system, rank)) return 0;
        if (IsBird(system) || system == SYSTEM_VANDALIER) return 1; // 0.025s -> 0.875 -> 1
        if (IsGun(system)) return 7; // 0.2s
        if (system == SYSTEM_VENTO) return 2; // 0.05s -> 1.75 -> 2
        if (IsBracelet(system)) return 1; // 0.04s -> 1.4 -> 1
        return 0;
    }

    // Duration in tics by nearest-tic (round-half-up) rounding at 35Hz.
    // Phiera/Eight/Phieraggi explicitly ignore Duration and return 0/NA.
    static int DurationTics(int system, int rank)
    {
        if (system == SYSTEM_PHIERAGGI) return 0; // ignores Duration
        if (system == SYSTEM_FUWALA) return rank == 1 ? 14 : 0; // 0.4s
        if (!ValidRank(system, rank)) return 0;
        if (IsBird(system) || system == SYSTEM_VANDALIER) return 140; // flat 4.0s
        if (IsGun(system)) return 0; // ignores Duration
        if (system == SYSTEM_VENTO) return 14; // flat 0.4s
        if (system == SYSTEM_BRACELET) return 14; // flat 0.4s
        if (system == SYSTEM_BI_BRACELET) return rank <= 3 ? 14 : 21; // 0.4s -> 0.6s at L4
        if (system == SYSTEM_TRI_BRACELET)
        {
            if (rank <= 2) return 21; // 0.6s
            if (rank <= 4) return 28; // 0.8s
            return 35; // ranks 5-6: 1.0s
        }
        return 0;
    }

    // Max simultaneous-instance pool, per rank (flat within every one of
    // these eleven systems; no per-level pool delta is reported anywhere).
    static int Pool(int system, int rank)
    {
        if (system == SYSTEM_PHIERAGGI) return rank == 1 ? 200 : 0;
        if (system == SYSTEM_FUWALA) return rank == 1 ? 120 : 0;
        if (!ValidRank(system, rank)) return 0;
        if (IsBird(system)) return 60;
        if (system == SYSTEM_VANDALIER) return 100;
        if (IsGun(system)) return 100;
        if (system == SYSTEM_VENTO) return 120;
        if (IsBracelet(system)) return 80;
        return 0;
    }

    // Knockback in milli (1000 = 1.0 knockback), per rank. Returns 0 for
    // the three bracelet systems: no knockback field exists in any of
    // their infoboxes (UNKNOWN, not an invented fixture) per source-notes.
    static int KnockbackMilli(int system, int rank)
    {
        if (system == SYSTEM_PHIERAGGI) return rank == 1 ? 50 : 0;
        if (system == SYSTEM_FUWALA) return rank == 1 ? 200 : 0;
        if (!ValidRank(system, rank)) return 0;
        if (IsBird(system) || system == SYSTEM_VANDALIER) return 2000;
        if (IsGun(system)) return 100;
        if (system == SYSTEM_VENTO) return 100;
        return 0; // bracelets: UNKNOWN
    }

    // Vento Sacro / Fuwalafuwaloo shared crit fixture; 0 for every other
    // system (no crit field on any other of these eleven infoboxes).
    static int CritChanceMilli(int system, int rank)
    {
        if ((system == SYSTEM_VENTO && ValidRank(system, rank))
            || (system == SYSTEM_FUWALA && rank == 1))
            return CRIT_CHANCE_MILLI;
        return 0;
    }

    static int CritMultiplierMilli(int system, int rank)
    {
        if ((system == SYSTEM_VENTO && ValidRank(system, rank))
            || (system == SYSTEM_FUWALA && rank == 1))
            return CRIT_MULTIPLIER_MILLI;
        return 0;
    }

    // Movement-streak cap in milli-damage, added on top of DamageMilli at
    // runtime and exempt from Might per the contract. 0 for every system
    // without a reported movement bonus.
    static int MovementStreakCapMilli(int system, int rank)
    {
        if (system == SYSTEM_VENTO && ValidRank(system, rank)) return VENTO_STREAK_CAP * 1000;
        if (system == SYSTEM_FUWALA && rank == 1) return FUWALA_STREAK_CAP * 1000;
        return 0;
    }

    static int MovementStreakStepMilli(int system, int rank)
    {
        if (system == SYSTEM_VENTO && ValidRank(system, rank)) return VENTO_STREAK_STEP * 1000;
        if (system == SYSTEM_FUWALA && rank == 1) return FUWALA_STREAK_STEP * 1000;
        return 0;
    }

    // P042-A04 data-driven wall policy: Phiera/Eight stop at logical walls
    // (hit-wall=Yes); Phieraggi's beams pass through walls (reported
    // explicit delay field). No other of these eleven systems interacts
    // with walls at all.
    static bool HitsWall(int system)
    {
        return system == SYSTEM_PHIERA || system == SYSTEM_EIGHT;
    }

    static bool PassesWall(int system)
    {
        return system == SYSTEM_PHIERAGGI;
    }

    static bool IgnoresDuration(int system)
    {
        return system == SYSTEM_PHIERA || system == SYSTEM_EIGHT || system == SYSTEM_PHIERAGGI;
    }

    // Facing mode: birds/Vandalier orbit, Phiera is character-relative,
    // Eight/Phieraggi are fixed source-plane, Vento/Fuwala are a facing
    // arc, bracelets are nearest-enemy aimed bursts.
    static bool IsCharacterRelativeFacing(int system) { return system == SYSTEM_PHIERA; }
    static bool IsFixedPlaneFacing(int system) { return system == SYSTEM_EIGHT || system == SYSTEM_PHIERAGGI; }

    static int RotationDirection(int system)
    {
        // +1 clockwise, -1 counterclockwise, 0 not applicable.
        if (system == SYSTEM_PEACHONE) return 1;
        if (system == SYSTEM_EBONY) return -1;
        return 0; // Vandalier emits both directions from one handle
    }

    // Order-independent union predicate. Both orders of (systemA, rankA)
    // and (systemB, rankB) must resolve identically. passiveKey/passiveRank
    // gate only the Phieraggi union (REVIVAL_PASSIVE_KEY, rank >= 1, never
    // consumed); pass 0/0 when checking the other two unions.
    static bool TryGetUnion(int systemA, int rankA, int systemB, int rankB,
        int passiveKey, int passiveRank, out int outputSystem)
    {
        outputSystem = 0;

        // Peachone + Ebony Wings -> Vandalier. No passive gate.
        if (DSP042PairMatches(systemA, systemB, SYSTEM_PEACHONE, SYSTEM_EBONY))
        {
            int peachRank = systemA == SYSTEM_PEACHONE ? rankA : rankB;
            int ebonyRank = systemA == SYSTEM_EBONY ? rankA : rankB;
            if (peachRank >= RankCount(SYSTEM_PEACHONE) && ebonyRank >= RankCount(SYSTEM_EBONY))
            {
                outputSystem = SYSTEM_VANDALIER;
                return true;
            }
            return false;
        }

        // Phiera Der Tuphello + Eight The Sparrow -> Phieraggi. Requires
        // Tirajisu (REVIVAL) at rank >= 1.
        if (DSP042PairMatches(systemA, systemB, SYSTEM_PHIERA, SYSTEM_EIGHT))
        {
            int phieraRank = systemA == SYSTEM_PHIERA ? rankA : rankB;
            int eightRank = systemA == SYSTEM_EIGHT ? rankA : rankB;
            if (phieraRank >= RankCount(SYSTEM_PHIERA) && eightRank >= RankCount(SYSTEM_EIGHT)
                && passiveKey == REVIVAL_PASSIVE_KEY && passiveRank >= 1)
            {
                outputSystem = SYSTEM_PHIERAGGI;
                return true;
            }
            return false;
        }

        // Vento Sacro + Bloody Tear (VAMPIRICA) -> Fuwalafuwaloo. Bloody
        // Tear is the second *weapon* input here, not a passive gate.
        if (DSP042PairMatches(systemA, systemB, SYSTEM_VENTO, VAMPIRICA_INPUT_KEY))
        {
            int ventoRank = systemA == SYSTEM_VENTO ? rankA : rankB;
            int vampiricaRank = systemA == VAMPIRICA_INPUT_KEY ? rankA : rankB;
            if (ventoRank >= RankCount(SYSTEM_VENTO) && vampiricaRank >= 1)
            {
                outputSystem = SYSTEM_FUWALA;
                return true;
            }
            return false;
        }

        return false;
    }

    // Order-independent unordered-pair test shared by TryGetUnion's three
    // branches above.
    private static bool DSP042PairMatches(int systemA, int systemB, int wantA, int wantB)
    {
        return (systemA == wantA && systemB == wantB)
            || (systemA == wantB && systemB == wantA);
    }

    // Single-input chain evolution: Bracelet -> Bi-Bracelet -> Tri-Bracelet.
    // Neither step needs a passive; both need the source at its own max
    // rank (INFERENCE, no requires-level field exists on either evolution).
    static bool TryGetChainEvolution(int sourceSystem, int sourceRank, out int evolvedSystem)
    {
        evolvedSystem = 0;
        if (sourceSystem == SYSTEM_BRACELET && sourceRank >= RankCount(SYSTEM_BRACELET))
        {
            evolvedSystem = SYSTEM_BI_BRACELET;
            return true;
        }
        if (sourceSystem == SYSTEM_BI_BRACELET && sourceRank >= RankCount(SYSTEM_BI_BRACELET))
        {
            evolvedSystem = SYSTEM_TRI_BRACELET;
            return true;
        }
        return false;
    }
}
