// P039 source-plane narrow-phase helpers for the Garlic/Soul Eater aura.
// P024 provides broad-phase candidates; these methods decide logical contact
// and checked scalar arithmetic without consulting actors, decals, particles,
// camera pose, or viewport state. Modelled on DSP038GroundMath (P038).
class DSP039AuraMath
{
    // Inclusive circle containment: aura radius (milliunits) plus the
    // target's own logical radius, per the contract's "inclusive" rule.
    static bool CircleContact(double centerX, double centerY,
        int radiusMilliUnits, double targetX, double targetY,
        double targetRadius)
    {
        if (radiusMilliUnits < 0 || targetRadius < 0.0) return false;
        double radius = double(radiusMilliUnits) / 1000.0;
        double combined = radius + targetRadius;
        double deltaX = targetX - centerX;
        double deltaY = targetY - centerY;
        return deltaX * deltaX + deltaY * deltaY <= combined * combined;
    }

    // Deterministic stable-ID ordering for per-tic candidate processing.
    // Ties break on generation then slot so the sweep order never depends on
    // P024's own internal iteration order.
    static bool CandidatePrecedes(int firstStableId, int firstGeneration,
        int firstSlot, int secondStableId, int secondGeneration,
        int secondSlot)
    {
        if (firstStableId != secondStableId) return firstStableId < secondStableId;
        if (firstGeneration != secondGeneration) return firstGeneration < secondGeneration;
        return firstSlot < secondSlot;
    }

    // Checked integer milli-scale, shared by the Cooldown-multiplier gate,
    // the debuff cap/floor arithmetic and the Little Heart heal formula.
    static bool CheckedScaleMilli(int sourceValue, int factorMilli,
        out int scaledValue)
    {
        scaledValue = 0;
        if (sourceValue < 0 || factorMilli < 0
            || (factorMilli > 0 && sourceValue > 2000000000 / factorMilli))
            return false;
        scaledValue = sourceValue * factorMilli / 1000;
        return scaledValue >= 0 && scaledValue <= 2000000000;
    }

    // Cooldown gate = row CooldownTics (already tic-quantized by
    // DSP039AuraRows) times the P033 resolved Cooldown multiplier, floored
    // at 1 tic so a weapon can never hit a target twice in the same tic.
    static int GateTicsAfterCooldown(int baseCooldownTics,
        int cooldownMultiplierMilli)
    {
        if (baseCooldownTics < 1 || cooldownMultiplierMilli < 1) return 1;
        int scaled;
        if (!CheckedScaleMilli(baseCooldownTics, cooldownMultiplierMilli,
            scaled) || scaled < 1) return 1;
        return scaled;
    }

    static int ClampInt(int value, int minimum, int maximum)
    {
        if (value < minimum) return minimum;
        if (value > maximum) return maximum;
        return value;
    }

    // Shared xorshift32 stream, matching DSP025NextAttackRng's algorithm so
    // every logical RNG stream in the project advances identically; the
    // P039_HEART stream keeps its own independent seed/state, never reusing
    // the attack RNG's state variable.
    static int NextRngState(int state)
    {
        int next = state;
        next = next ^ (next << 13);
        next = next ^ (next >> 17);
        next = next ^ (next << 5);
        if (next == 0) next = 1327217885;
        return next;
    }

    // Positive modulus for the RNG stream: ZScript's % on a negative int
    // keeps the sign, so callers that need a range in [0, modulus) go
    // through this helper rather than repeating the sign-fix inline.
    static int PositiveModulo(int value, int modulus)
    {
        if (modulus <= 0) return 0;
        int remainder = value % modulus;
        if (remainder < 0) remainder += modulus;
        return remainder;
    }
}
