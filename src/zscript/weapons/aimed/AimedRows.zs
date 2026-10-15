// Compiled, scalar-accessor mirror of the qualified P034 JSON weapon rows.
// `data/verified/base/weapons/aimed/*.json` is canonical; focused parity tests
// reject any missing, duplicate, or divergent rank value.
// Engineering fields are deterministic MAP20 policy, not source measurements.
class DSP034WeaponRows
{
    const SYSTEM_MAGIC_WAND = 34;
    const SYSTEM_HOLY_WAND = 35;
    const SYSTEM_KNIFE = 36;
    const SYSTEM_THOUSAND_EDGE = 37;

    const TRANSFORM_EMPTY_TOME = 1;
    const TRANSFORM_BRACER = 2;

    static bool TryGetRankRow(int systemId, int rank,
        out int damageTenths, out int amount, out int pierce,
        out int cooldownMillis, out int childIntervalMillis,
        out int projectileSpeedMilli, out int travelUnitsPerSecond,
        out int rangeUnits, out int lifetimeTics,
        out int projectileRadiusMilli, out int projectilePoolLimit)
    {
        damageTenths = 0; amount = 0; pierce = 0;
        cooldownMillis = 0; childIntervalMillis = 0;
        projectileSpeedMilli = 0; travelUnitsPerSecond = 0;
        rangeUnits = 0; lifetimeTics = 0;
        projectileRadiusMilli = 0; projectilePoolLimit = 0;
        if (systemId == SYSTEM_MAGIC_WAND && rank == 1)
        {
            damageTenths = 100;
            amount = 1;
            pierce = 1;
            cooldownMillis = 1200;
            childIntervalMillis = 100;
            projectileSpeedMilli = 1000;
            travelUnitsPerSecond = 320;
            rangeUnits = 320;
            lifetimeTics = 35;
            projectileRadiusMilli = 2000;
            projectilePoolLimit = 60;
            return true;
        }
        if (systemId == SYSTEM_MAGIC_WAND && rank == 2)
        {
            damageTenths = 100;
            amount = 2;
            pierce = 1;
            cooldownMillis = 1200;
            childIntervalMillis = 100;
            projectileSpeedMilli = 1000;
            travelUnitsPerSecond = 320;
            rangeUnits = 320;
            lifetimeTics = 35;
            projectileRadiusMilli = 2000;
            projectilePoolLimit = 60;
            return true;
        }
        if (systemId == SYSTEM_MAGIC_WAND && rank == 3)
        {
            damageTenths = 100;
            amount = 2;
            pierce = 1;
            cooldownMillis = 1000;
            childIntervalMillis = 100;
            projectileSpeedMilli = 1000;
            travelUnitsPerSecond = 320;
            rangeUnits = 320;
            lifetimeTics = 35;
            projectileRadiusMilli = 2000;
            projectilePoolLimit = 60;
            return true;
        }
        if (systemId == SYSTEM_MAGIC_WAND && rank == 4)
        {
            damageTenths = 100;
            amount = 3;
            pierce = 1;
            cooldownMillis = 1000;
            childIntervalMillis = 100;
            projectileSpeedMilli = 1000;
            travelUnitsPerSecond = 320;
            rangeUnits = 320;
            lifetimeTics = 35;
            projectileRadiusMilli = 2000;
            projectilePoolLimit = 60;
            return true;
        }
        if (systemId == SYSTEM_MAGIC_WAND && rank == 5)
        {
            damageTenths = 200;
            amount = 3;
            pierce = 1;
            cooldownMillis = 1000;
            childIntervalMillis = 100;
            projectileSpeedMilli = 1000;
            travelUnitsPerSecond = 320;
            rangeUnits = 320;
            lifetimeTics = 35;
            projectileRadiusMilli = 2000;
            projectilePoolLimit = 60;
            return true;
        }
        if (systemId == SYSTEM_MAGIC_WAND && rank == 6)
        {
            damageTenths = 200;
            amount = 4;
            pierce = 1;
            cooldownMillis = 1000;
            childIntervalMillis = 100;
            projectileSpeedMilli = 1000;
            travelUnitsPerSecond = 320;
            rangeUnits = 320;
            lifetimeTics = 35;
            projectileRadiusMilli = 2000;
            projectilePoolLimit = 60;
            return true;
        }
        if (systemId == SYSTEM_MAGIC_WAND && rank == 7)
        {
            damageTenths = 200;
            amount = 4;
            pierce = 2;
            cooldownMillis = 1000;
            childIntervalMillis = 100;
            projectileSpeedMilli = 1000;
            travelUnitsPerSecond = 320;
            rangeUnits = 320;
            lifetimeTics = 35;
            projectileRadiusMilli = 2000;
            projectilePoolLimit = 60;
            return true;
        }
        if (systemId == SYSTEM_MAGIC_WAND && rank == 8)
        {
            damageTenths = 300;
            amount = 4;
            pierce = 2;
            cooldownMillis = 1000;
            childIntervalMillis = 100;
            projectileSpeedMilli = 1000;
            travelUnitsPerSecond = 320;
            rangeUnits = 320;
            lifetimeTics = 35;
            projectileRadiusMilli = 2000;
            projectilePoolLimit = 60;
            return true;
        }
        if (systemId == SYSTEM_HOLY_WAND && rank == 1)
        {
            damageTenths = 300;
            amount = 4;
            pierce = 2;
            cooldownMillis = 500;
            childIntervalMillis = 100;
            projectileSpeedMilli = 2000;
            travelUnitsPerSecond = 640;
            rangeUnits = 320;
            lifetimeTics = 18;
            projectileRadiusMilli = 2000;
            projectilePoolLimit = 60;
            return true;
        }
        if (systemId == SYSTEM_KNIFE && rank == 1)
        {
            damageTenths = 65;
            amount = 1;
            pierce = 1;
            cooldownMillis = 1000;
            childIntervalMillis = 100;
            projectileSpeedMilli = 1000;
            travelUnitsPerSecond = 320;
            rangeUnits = 320;
            lifetimeTics = 35;
            projectileRadiusMilli = 2000;
            projectilePoolLimit = 70;
            return true;
        }
        if (systemId == SYSTEM_KNIFE && rank == 2)
        {
            damageTenths = 65;
            amount = 2;
            pierce = 1;
            cooldownMillis = 1000;
            childIntervalMillis = 100;
            projectileSpeedMilli = 1000;
            travelUnitsPerSecond = 320;
            rangeUnits = 320;
            lifetimeTics = 35;
            projectileRadiusMilli = 2000;
            projectilePoolLimit = 70;
            return true;
        }
        if (systemId == SYSTEM_KNIFE && rank == 3)
        {
            damageTenths = 115;
            amount = 3;
            pierce = 1;
            cooldownMillis = 1000;
            childIntervalMillis = 100;
            projectileSpeedMilli = 1000;
            travelUnitsPerSecond = 320;
            rangeUnits = 320;
            lifetimeTics = 35;
            projectileRadiusMilli = 2000;
            projectilePoolLimit = 70;
            return true;
        }
        if (systemId == SYSTEM_KNIFE && rank == 4)
        {
            damageTenths = 115;
            amount = 4;
            pierce = 1;
            cooldownMillis = 1000;
            childIntervalMillis = 80;
            projectileSpeedMilli = 1000;
            travelUnitsPerSecond = 320;
            rangeUnits = 320;
            lifetimeTics = 35;
            projectileRadiusMilli = 2000;
            projectilePoolLimit = 70;
            return true;
        }
        if (systemId == SYSTEM_KNIFE && rank == 5)
        {
            damageTenths = 115;
            amount = 4;
            pierce = 2;
            cooldownMillis = 1000;
            childIntervalMillis = 80;
            projectileSpeedMilli = 1000;
            travelUnitsPerSecond = 320;
            rangeUnits = 320;
            lifetimeTics = 35;
            projectileRadiusMilli = 2000;
            projectilePoolLimit = 70;
            return true;
        }
        if (systemId == SYSTEM_KNIFE && rank == 6)
        {
            damageTenths = 115;
            amount = 5;
            pierce = 2;
            cooldownMillis = 1000;
            childIntervalMillis = 60;
            projectileSpeedMilli = 1000;
            travelUnitsPerSecond = 320;
            rangeUnits = 320;
            lifetimeTics = 35;
            projectileRadiusMilli = 2000;
            projectilePoolLimit = 70;
            return true;
        }
        if (systemId == SYSTEM_KNIFE && rank == 7)
        {
            damageTenths = 165;
            amount = 6;
            pierce = 2;
            cooldownMillis = 1000;
            childIntervalMillis = 60;
            projectileSpeedMilli = 1000;
            travelUnitsPerSecond = 320;
            rangeUnits = 320;
            lifetimeTics = 35;
            projectileRadiusMilli = 2000;
            projectilePoolLimit = 70;
            return true;
        }
        if (systemId == SYSTEM_KNIFE && rank == 8)
        {
            damageTenths = 165;
            amount = 6;
            pierce = 3;
            cooldownMillis = 1000;
            childIntervalMillis = 40;
            projectileSpeedMilli = 1000;
            travelUnitsPerSecond = 320;
            rangeUnits = 320;
            lifetimeTics = 35;
            projectileRadiusMilli = 2000;
            projectilePoolLimit = 70;
            return true;
        }
        if (systemId == SYSTEM_THOUSAND_EDGE && rank == 1)
        {
            damageTenths = 165;
            amount = 6;
            pierce = 3;
            cooldownMillis = 350;
            childIntervalMillis = 50;
            projectileSpeedMilli = 1500;
            travelUnitsPerSecond = 480;
            rangeUnits = 320;
            lifetimeTics = 24;
            projectileRadiusMilli = 2000;
            projectilePoolLimit = 70;
            return true;
        }
        return false;
    }

    static bool TryGetTransformation(int evolvedSystemId,
        out int sourceSystemId, out int requiredSourceRank,
        out int requiredPassiveKind, out int requiredPassiveRank)
    {
        sourceSystemId = 0; requiredSourceRank = 0;
        requiredPassiveKind = 0; requiredPassiveRank = 0;
        if (evolvedSystemId == SYSTEM_HOLY_WAND)
        {
            sourceSystemId = SYSTEM_MAGIC_WAND; requiredSourceRank = 8;
            requiredPassiveKind = TRANSFORM_EMPTY_TOME; requiredPassiveRank = 1;
            return true;
        }
        if (evolvedSystemId == SYSTEM_THOUSAND_EDGE)
        {
            sourceSystemId = SYSTEM_KNIFE; requiredSourceRank = 8;
            requiredPassiveKind = TRANSFORM_BRACER; requiredPassiveRank = 1;
            return true;
        }
        return false;
    }
}
