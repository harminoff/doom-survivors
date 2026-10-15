// P026 promoted source-facing records.  Identity is BUILD_EXTRACTED; current
// gameplay reports and the first-person rectangle retain their provenance.
class DSP026WhipRecords
{
    const CHARACTER_ID = "ANTONIO";
    const WEAPON_ID = "WHIP";
    const BASE_DAMAGE = 10;
    const BASE_AMOUNT = 1;
    const FIXTURE_LEVEL = 2;
    const COOLDOWN_NUMERATOR = 189;
    const COOLDOWN_DENOMINATOR = 4;
    const FOLLOWUP_NUMERATOR = 7;
    const FOLLOWUP_DENOMINATOR = 2;
    const LOBE_FORWARD_MIN = 0.0;
    const LOBE_FORWARD_MAX = 128.0;
    const LOBE_LATERAL_MIN = -24.0;
    const LOBE_LATERAL_MAX = 24.0;
    const TARGET_RADIUS = 8.0;
    const SOURCE_SHA256 = "c930da284e079870242b367f809ba737499ec19b8f53c51e9a03d8e082b61ffe";

    static int AmountForLevel(int level)
    {
        return level >= 2 ? 2 : BASE_AMOUNT;
    }

    // Shared immutable P026 level table used by later progression fixtures.
    // These are qualified community values retained with their source record.
    static int DamageForLevel(int level)
    {
        if (level <= 1) return 10;
        if (level == 2) return 10;
        if (level == 3) return 15;
        if (level == 4) return 20;
        if (level == 5) return 25;
        if (level == 6) return 30;
        if (level == 7) return 35;
        return 40;
    }
}
