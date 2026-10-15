// P041 source-plane targeting, launch-direction and dedicated RNG-stream
// helpers for the ricochet weapons (Runetracer/NO FUTURE, Bone, Cherry Bomb,
// CarrellO). Geometry and row values come from DSP041BounceRows; this file
// owns only deterministic policy (direction draws, explosion-chance rolls),
// never damage, walls or native projectile motion.
mixin class DSP041BounceTargeting
{
    int dsp041BounceRng;

    void DSP041ResetBounceTargeting(int seed)
    {
        dsp041BounceRng = seed;
        if (dsp041BounceRng == 0) dsp041BounceRng = 1620255963;
    }

    int DSP041NormalizeYawMilli(int yawMilli)
    {
        int normalized = yawMilli % 360000;
        if (normalized < 0) normalized += 360000;
        return normalized;
    }

    void DSP041YawDirection(int yawMilli, out double directionX,
        out double directionY)
    {
        double yawDegrees = double(DSP041NormalizeYawMilli(yawMilli)) / 1000.0;
        directionX = cos(yawDegrees);
        directionY = sin(yawDegrees);
    }

    // Runetracer and Bone draw an initial direction from the dedicated
    // P041_BOUNCE stream (contract: "unknown rule, labelled"). A full-circle
    // uniform draw is the labelled engineering fixture used here.
    int DSP041DrawInitialYawMilli(out int rngBefore, out int rngAfter)
    {
        rngBefore = dsp041BounceRng;
        dsp041BounceRng = DSP025NextAttackRng(dsp041BounceRng);
        rngAfter = dsp041BounceRng;
        int nonnegative = dsp041BounceRng & 0x7fffffff;
        return DSP041NormalizeYawMilli(nonnegative % 360000);
    }

    // Cherry Bomb rolls its rank explosion chance (boosted by Luck, 1000
    // milli-baseline) on the same dedicated stream when it stops. This is a
    // thin wrapper over DSP041RollExplosionChanceOnState so gameplay and any
    // isolated audit share one formula; gameplay is the only caller that
    // reads/writes the live dsp041BounceRng field.
    bool DSP041RollExplosionChance(int explosionChanceMilli, int luckMilli,
        out int rngBefore, out int rngAfter, out int rollMilli)
    {
        bool exploded = DSP041RollExplosionChanceOnState(dsp041BounceRng,
            explosionChanceMilli, luckMilli, rngBefore, rngAfter, rollMilli);
        dsp041BounceRng = rngAfter;
        return exploded;
    }

    // Same exact formula as DSP041RollExplosionChance above, but operating
    // on a caller-supplied state value instead of the live dsp041BounceRng
    // field -- never reads or writes gameplay RNG. This lets an isolated
    // statistical audit (see BounceMap27Runtime.RunOneCherryAuditChance)
    // call the real production roll rather than reimplementing its xorshift
    // formula locally, while proving the live gameplay stream is untouched.
    bool DSP041RollExplosionChanceOnState(int state, int explosionChanceMilli,
        int luckMilli, out int rngBefore, out int rngAfter, out int rollMilli)
    {
        rngBefore = state;
        int nextState = DSP025NextAttackRng(state);
        rngAfter = nextState;
        int nonnegative = nextState & 0x7fffffff;
        rollMilli = nonnegative % 1000;
        int boostedChanceMilli = explosionChanceMilli;
        if (luckMilli > 0)
            boostedChanceMilli = explosionChanceMilli * luckMilli / 1000;
        if (boostedChanceMilli > 1000) boostedChanceMilli = 1000;
        return rollMilli < boostedChanceMilli;
    }
}
