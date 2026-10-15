// P040 source-plane math helpers for the logical-screen strike, erasure and
// global-effect families (Lightning Ring/Thunder Loop, Pentagram/Gorgeous
// Moon). Modelled on DSP038GroundMath (P038) and DSP039AuraMath (P039): pure
// checked arithmetic, no actors, no camera, no render state.
//
// Region ("on screen") is `logical-reference-v1` per
// docs/contracts/global-strikes.md: the inclusive 256x256 rectangle centred
// on the current logical player position -- REGION_HALF_EXTENT=128 either
// side of both axes.
class DSP040GlobalMath
{
    // Inclusive rectangle containment. An entity exactly on the +/-128
    // boundary is IN the region, per the contract's boundary-inclusion
    // evidence requirement.
    static bool InRegion(double playerX, double playerY, double targetX,
        double targetY, int halfExtent)
    {
        if (halfExtent < 0) return false;
        double extent = double(halfExtent);
        double deltaX = targetX - playerX;
        double deltaY = targetY - playerY;
        if (deltaX < 0.0) deltaX = -deltaX;
        if (deltaY < 0.0) deltaY = -deltaY;
        return deltaX <= extent && deltaY <= extent;
    }

    // Inclusive circle containment: strike radius (milliunits) plus the
    // target's own logical radius, matching DSP039AuraMath.CircleContact.
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

    // Deterministic stable-ID ordering, shared by the strike-candidate sort
    // and the Gorgeous Moon closest-target tie-break.
    static bool CandidatePrecedes(int firstStableId, int firstGeneration,
        int firstSlot, int secondStableId, int secondGeneration,
        int secondSlot)
    {
        if (firstStableId != secondStableId) return firstStableId < secondStableId;
        if (firstGeneration != secondGeneration) return firstGeneration < secondGeneration;
        return firstSlot < secondSlot;
    }

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

    static bool CheckedAdd(int left, int right, out int result)
    {
        result = 0;
        if (left < 0 || right < 0 || left > 2000000000 - right) return false;
        result = left + right;
        return true;
    }

    // Activation period = row PeriodTics x P033 Cooldown multiplier, floored
    // at 1 tic. Shared by Lightning Ring/Thunder Loop activation scheduling
    // and Pentagram/Gorgeous Moon cooldown scheduling (contract: "no extra
    // floor under the multiplier" for Pentagram -- callers that need the
    // Gorgeous Moon 525-tic floor apply it themselves after this call).
    static int GateTicsAfterMultiplier(int baseTics, int cooldownMultiplierMilli)
    {
        if (baseTics < 1 || cooldownMultiplierMilli < 1) return 1;
        int scaled;
        if (!CheckedScaleMilli(baseTics, cooldownMultiplierMilli, scaled)
            || scaled < 1) return 1;
        return scaled;
    }

    static int ClampInt(int value, int minimum, int maximum)
    {
        if (value < minimum) return minimum;
        if (value > maximum) return maximum;
        return value;
    }

    // Shared xorshift32 stream algorithm (identical to every other logical
    // RNG stream in the project: P025 attack RNG, P039 Heart RNG). The
    // P040_STRIKE and P040_ERASE streams each keep independent state; this
    // helper never mixes the two.
    static int NextRngState(int state)
    {
        int next = state;
        next = next ^ (next << 13);
        next = next ^ (next >> 17);
        next = next ^ (next << 5);
        if (next == 0) next = 2058003117;
        return next;
    }

    static int PositiveModulo(int value, int modulus)
    {
        if (modulus <= 0) return 0;
        int remainder = value % modulus;
        if (remainder < 0) remainder += modulus;
        return remainder;
    }

    // Pentagram/spare-roll formula (contract): spared when
    // rng % 1,000,000 < spare_milli * luck_milli, saturating at "always
    // spared" instead of overflowing when a fixture injects a very high
    // Luck (Luck saturation evidence requirement).
    static bool SpareRoll(int rngValue, int spareMilli, int luckMilli,
        out bool spared)
    {
        spared = false;
        if (spareMilli < 0 || luckMilli < 0) return false;
        int threshold;
        if (spareMilli > 0 && luckMilli > 2000000000 / spareMilli)
            threshold = 2000000000;
        else threshold = spareMilli * luckMilli;
        int roll = PositiveModulo(rngValue, 1000000);
        spared = roll < threshold;
        return true;
    }
}
