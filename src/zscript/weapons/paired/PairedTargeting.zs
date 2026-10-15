// P042 paired-weapon geometry/policy helpers: source-plane facing, the bird
// orbit angle ledger, the dedicated P042_CRIT stream and the shared
// movement-streak fixture. Owns deterministic policy only -- never damage,
// walls, slot transactions or native motion (docs/contracts/paired-unions.md
// "Geometry adapters").
mixin class DSP042PairedTargeting
{
    int dsp042CritRng;
    int dsp042MoveStreakTics;
    int dsp042MoveStreakLastX1000;
    int dsp042MoveStreakLastY1000;
    bool dsp042MoveStreakSeeded;

    void DSP042ResetPairedTargeting(int seed)
    {
        dsp042CritRng = seed;
        if (dsp042CritRng == 0) dsp042CritRng = 802920167;
        dsp042MoveStreakTics = 0;
        dsp042MoveStreakLastX1000 = 0;
        dsp042MoveStreakLastY1000 = 0;
        dsp042MoveStreakSeeded = false;
    }

    int DSP042NormalizeYawMilli(int yawMilli)
    {
        int normalized = yawMilli % 360000;
        if (normalized < 0) normalized += 360000;
        return normalized;
    }

    void DSP042YawDirection(int yawMilli, out double directionX,
        out double directionY)
    {
        double yawDegrees = double(DSP042NormalizeYawMilli(yawMilli)) / 1000.0;
        directionX = cos(yawDegrees);
        directionY = sin(yawDegrees);
    }

    // Fixed-plane (camera-independent) diagonals for Eight/Phieraggi. The
    // "source plane" is the logical-reference-v1 plane itself, i.e. these
    // four angles never depend on body facing.
    int DSP042FixedDiagonalDeg(int ordinal)
    {
        if (ordinal == 0) return DSP042PairedRows.EIGHT_FIXED_DIAGONAL_DEG_1;
        if (ordinal == 1) return DSP042PairedRows.EIGHT_FIXED_DIAGONAL_DEG_2;
        if (ordinal == 2) return DSP042PairedRows.EIGHT_FIXED_DIAGONAL_DEG_3;
        return DSP042PairedRows.EIGHT_FIXED_DIAGONAL_DEG_4;
    }

    // Character-relative diagonals for Phiera: body facing +/-45, +/-135.
    int DSP042FacingRelativeDiagonalDeg(int ordinal, int facingYawMilli)
    {
        int base = DSP042NormalizeYawMilli(facingYawMilli) / 1000;
        if (ordinal == 0) return (base + DSP042PairedRows.PHIERA_FACING_DEG_A) % 360;
        if (ordinal == 1) return (base - DSP042PairedRows.PHIERA_FACING_DEG_A + 360) % 360;
        if (ordinal == 2) return (base + DSP042PairedRows.PHIERA_FACING_DEG_B) % 360;
        return (base - DSP042PairedRows.PHIERA_FACING_DEG_B + 360) % 360;
    }

    // Bird orbit point: radius 72 around (originX, originY) at angle
    // (startAngleDeg + direction * ordinal * 360/amount).
    void DSP042BirdOrbitPoint(double originX, double originY,
        int startAngleDeg, int direction, int ordinal, int amount,
        out double pointX, out double pointY, out int angleDegOut)
    {
        int stepDeg = amount > 0 ? 360 / amount : 0;
        int angleDeg = startAngleDeg + direction * ordinal * stepDeg;
        angleDeg = angleDeg % 360;
        if (angleDeg < 0) angleDeg += 360;
        angleDegOut = angleDeg;
        double radians = double(angleDeg) * 3.14159265358979 / 180.0;
        pointX = originX + double(DSP042PairedRows.BIRD_ORBIT_RADIUS) * cos(radians);
        pointY = originY + double(DSP042PairedRows.BIRD_ORBIT_RADIUS) * sin(radians);
    }

    // Vento/Fuwala facing-arc test: true when target is within reachUnits
    // and inside +/-halfAngleDeg of facingYawMilli.
    bool DSP042InFacingArc(double originX, double originY, double targetX,
        double targetY, int facingYawMilli, double reachUnits,
        int halfAngleDeg)
    {
        double dx = targetX - originX; double dy = targetY - originY;
        double distSq = dx * dx + dy * dy;
        if (distSq > reachUnits * reachUnits) return false;
        if (distSq <= 0.0000001) return true;
        double angleToTarget = atan2(dy, dx) * 180.0 / 3.14159265358979;
        if (angleToTarget < 0.0) angleToTarget += 360.0;
        double facing = double(DSP042NormalizeYawMilli(facingYawMilli)) / 1000.0;
        double delta = angleToTarget - facing;
        while (delta > 180.0) delta -= 360.0;
        while (delta < -180.0) delta += 360.0;
        return abs(delta) <= double(halfAngleDeg);
    }

    // Movement-streak, split into a per-TIC ledger update
    // (DSP042TickMoveStreak, called exactly once per logical tic by the
    // owning WorldTick regardless of whether any weapon fires that tic) and
    // a pure read (DSP042PeekMoveStreakBonus, called by the firing adapter
    // at hit time). This is P042-W07's fix for the original single-call
    // DSP042UpdateMoveStreak below, which advanced the ledger once per
    // DSP042FireArcVolley invocation (i.e. once per ~70-tic cooldown) rather
    // than once per real tic, undercounting "N x 35 continuous-movement
    // tics" by roughly the cooldown factor. Every existing fixture mode
    // keeps the player stationary at a fixed origin for its whole run, so
    // routing the per-tic call through WorldTick is behavior-identical for
    // them (position never changes -> DSP042TickMoveStreak always resets to
    // 0, exactly as the old call-site-coupled version did); only a mode that
    // actually moves the player every tic (vento_streak) observes the
    // corrected per-tic cadence.
    void DSP042TickMoveStreak(double currentX, double currentY)
    {
        int curX1000 = int(currentX * 1000.0);
        int curY1000 = int(currentY * 1000.0);
        bool moved = dsp042MoveStreakSeeded
            && (curX1000 != dsp042MoveStreakLastX1000
                || curY1000 != dsp042MoveStreakLastY1000);
        dsp042MoveStreakLastX1000 = curX1000;
        dsp042MoveStreakLastY1000 = curY1000;
        dsp042MoveStreakSeeded = true;
        if (moved) dsp042MoveStreakTics++;
        else dsp042MoveStreakTics = 0;
    }

    int DSP042PeekMoveStreakBonus(int stepMilli, int capMilli)
    {
        if (stepMilli <= 0 || DSP042PairedRows.STREAK_PERIOD_TICS <= 0) return 0;
        int steps = dsp042MoveStreakTics / DSP042PairedRows.STREAK_PERIOD_TICS;
        int bonus = steps * stepMilli;
        if (bonus > capMilli) bonus = capMilli;
        return bonus;
    }

    // Caller reports current body position each tic. Continuous movement
    // (position actually changed since last tic) grows the streak by one
    // step per STREAK_PERIOD_TICS, capped; any tic without movement resets
    // to zero. Returns the current bonus in milli-damage. Kept as a thin
    // wrapper over the two primitives above for any caller that still wants
    // "advance and read" as one call.
    int DSP042UpdateMoveStreak(double currentX, double currentY,
        int stepMilli, int capMilli)
    {
        DSP042TickMoveStreak(currentX, currentY);
        return DSP042PeekMoveStreakBonus(stepMilli, capMilli);
    }

    // Same exact formula as DSP042RollCrit below, but operating on a
    // caller-supplied state value instead of the live dsp042CritRng field --
    // never reads or writes gameplay RNG. Mirrors
    // DSP041RollExplosionChanceOnState (BounceTargeting.zs) so an isolated
    // statistical audit (fuwala_heal mode's crit audit) can call the REAL
    // production roll rather than reimplementing its formula, while proving
    // the live P042_CRIT gameplay stream is untouched.
    bool DSP042RollCritOnState(int state, int chanceMilli, int luckMilli,
        out int rngBefore, out int rngAfter, out int rollMilli)
    {
        rngBefore = state;
        int nextState = DSP025NextAttackRng(state);
        rngAfter = nextState;
        int nonnegative = nextState & 0x7fffffff;
        rollMilli = nonnegative % 1000;
        int boostedChanceMilli = chanceMilli;
        if (luckMilli > 0) boostedChanceMilli = chanceMilli * luckMilli / 1000;
        if (boostedChanceMilli > 1000) boostedChanceMilli = 1000;
        return rollMilli < boostedChanceMilli;
    }

    // Dedicated P042_CRIT stream, shared by Vento Sacro and Fuwalafuwaloo.
    // chance/luck are both milli (1000 = 100%); Luck boosts chance the same
    // way DSP041's explosion-chance roll does. Thin wrapper over
    // DSP042RollCritOnState so gameplay and any isolated audit share one
    // formula; gameplay is the only caller that reads/writes the live
    // dsp042CritRng field.
    bool DSP042RollCrit(int chanceMilli, int luckMilli, out int rngBefore,
        out int rngAfter, out int rollMilli)
    {
        bool critical = DSP042RollCritOnState(dsp042CritRng, chanceMilli,
            luckMilli, rngBefore, rngAfter, rollMilli);
        dsp042CritRng = rngAfter;
        return critical;
    }
}
