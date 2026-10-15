// P039 shared healing authority (docs/contracts/auras-healing.md "Healing
// authority and same-tic order"). Every player heal source (Recovery,
// Little Heart, Bloody Tear drain, and any later source) must route through
// DSP039ApplyHeal; no code path may add to player health directly. This is
// a mixin, following the DSP03x pattern (e.g. DSP038GroundFieldRuntime),
// meant to be mixed into the owning event handler; wiring it into that
// handler's damage/heal call sites is not this file's job.
mixin class DSP039Healing
{
    const SOURCE_RECOVERY = 1;
    const SOURCE_LITTLE_HEART = 2;
    const SOURCE_BLOODY_TEAR = 3;
    const SOURCE_FLOOR_CHICKEN = 4;
    const SOURCE_REVIVAL = 5;
    const SOURCE_ARCANA_GOLD = 6;
    const SOURCE_FIXTURE = 9;

    int dsp039HealTransactions;
    int dsp039HealRequestedMilli;
    int dsp039HealAppliedMilli;
    int dsp039HealRejected;
    int dsp039RecoveryNextTic;
    int dsp039DrainReadyTic;

    // Implements the frozen reject/accept policy: reject (applied 0, logged
    // reason) when the run is not active, health is already <= 0, or the
    // request itself is not positive; otherwise applied = min(requested,
    // max - before), never exceeding max, and a zero-applied request at full
    // health is accepted and recorded (not dropped) with reason FULL_HEALTH.
    bool DSP039ApplyHeal(int source, int requestedMilli, int tic,
        bool runActive, int healthBefore, int maxHealth,
        out int healthAfter, out int appliedMilli)
    {
        healthAfter = healthBefore;
        appliedMilli = 0;
        // Sarabande of Healing arcana: all healing is doubled (wiki).
        if (arHealDouble && requestedMilli > 0) requestedMilli *= 2;
        dsp039HealTransactions++;
        dsp039HealRequestedMilli += requestedMilli;

        bool accepted = true;
        String reason = "OK";
        if (!runActive)
        {
            accepted = false;
            reason = "NOT_RUN_ACTIVE";
        }
        else if (healthBefore <= 0)
        {
            accepted = false;
            reason = "HEALTH_ZERO_OR_BELOW";
        }
        else if (requestedMilli <= 0)
        {
            accepted = false;
            reason = "REQUESTED_NOT_POSITIVE";
        }

        if (accepted)
        {
            int room = maxHealth - healthBefore;
            if (room < 0) room = 0;
            appliedMilli = requestedMilli < room ? requestedMilli : room;
            if (appliedMilli == 0) reason = "FULL_HEALTH";
            healthAfter = healthBefore + appliedMilli;
        }
        else
        {
            dsp039HealRejected++;
        }
        dsp039HealAppliedMilli += appliedMilli;

        Console.Printf("DS_P039_HEAL tic=%d source=%d requested_milli=%d applied_milli=%d health_before=%d health_after=%d max_health=%d accepted=%d reason=%s", tic, source, requestedMilli, appliedMilli, healthBefore, healthAfter, maxHealth, accepted ? 1 : 0, reason);
        return accepted;
    }

    // Returns the milli-HP amount to request as a single transaction on the
    // 35-tic Recovery boundary, and advances the boundary; 0 otherwise. No
    // sub-second accumulation or banking, per the frozen engineering policy.
    int DSP039RecoveryDue(int tic, int recoveryMilliPerSecond)
    {
        if (dsp039RecoveryNextTic <= 0)
            dsp039RecoveryNextTic = DSP039AuraRows.RECOVERY_PERIOD_TICS;
        if (tic < dsp039RecoveryNextTic) return 0;
        dsp039RecoveryNextTic = tic + DSP039AuraRows.RECOVERY_PERIOD_TICS;
        return recoveryMilliPerSecond;
    }

    bool DSP039BloodyTearDrainReady(int tic)
    {
        return tic >= dsp039DrainReadyTic;
    }

    void DSP039ConsumeBloodyTearDrain(int tic)
    {
        dsp039DrainReadyTic = tic + DSP039AuraRows.BLOODY_TEAR_DRAIN_GATE_TICS;
    }

    // 1 HP (1000 milli) scaled by Recovery: 1000 * (1000 + recovery) / 1000.
    int DSP039LittleHeartHealMilli(int recoveryMilliPerSecond)
    {
        return DSP039AuraRows.HEART_BASE_HEAL_MILLI
            * (1000 + recoveryMilliPerSecond) / 1000;
    }

    void DSP039ResetHealing()
    {
        dsp039HealTransactions = 0;
        dsp039HealRequestedMilli = 0;
        dsp039HealAppliedMilli = 0;
        dsp039HealRejected = 0;
        dsp039RecoveryNextTic = DSP039AuraRows.RECOVERY_PERIOD_TICS;
        dsp039DrainReadyTic = 0;
    }

    int DSP039HashMix(int hash, int value)
    {
        int normalized = value % 1000003;
        if (normalized < 0) normalized += 1000003;
        return (hash * 31 + normalized) % 1000003;
    }

    int DSP039HealingStateHash()
    {
        int hash = 39;
        hash = DSP039HashMix(hash, dsp039HealTransactions);
        hash = DSP039HashMix(hash, dsp039HealRequestedMilli);
        hash = DSP039HashMix(hash, dsp039HealAppliedMilli);
        hash = DSP039HashMix(hash, dsp039HealRejected);
        hash = DSP039HashMix(hash, dsp039RecoveryNextTic);
        hash = DSP039HashMix(hash, dsp039DrainReadyTic);
        return hash;
    }
}
