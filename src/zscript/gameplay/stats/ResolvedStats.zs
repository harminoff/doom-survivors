// P033 qualified stat resolver. Source ranks remain owned by P031/P032
// inventories; this mixin stores only base values and a disposable resolved
// snapshot. Call RecomputeFromRanks after every accepted inventory mutation
// and after the owning handler restores a save.
class DSP033StatRules
{
    const STAT_MIGHT = 1;
    const STAT_ARMOR = 2;
    const STAT_MAX_HEALTH = 3;
    const STAT_COOLDOWN = 4;
    // P039 Recovery stat: resolved milli-HP-per-second, additive from
    // Pummarola ranks. It is never fed back into combat and is not gated by
    // StatApplies/system eligibility the way Might/Cooldown are.
    const STAT_RECOVERY = 5;
    // P040 Amount/Growth stats: resolved additive int (Amount) and milli
    // percentage-point (Growth) from Duplicator/Crown ranks. Neither is
    // gated by StatApplies for Might/Cooldown; Amount instead uses the
    // separate AmountApplies eligibility gate below, restricted to the
    // subset of P040 systems the frozen contract names.
    const STAT_AMOUNT = 6;
    const STAT_GROWTH = 7;

    const ITEM_SPINACH = 2;
    const ITEM_ARMOR = 3;
    const ITEM_HOLLOW_HEART = 5;
    const ITEM_EMPTY_TOME = 7;
    // P039 Pummarola (REGEN); a qualified five-rank passive feeding only the
    // new Recovery stat, added via a separate resolve path so the existing
    // four-stat Resolve() signature and its rank hash stay byte-identical.
    const ITEM_PUMMAROLA = 8;
    // P040 Duplicator (AMOUNT, 2 ranks) and Crown (GROWTH, 5 ranks); each
    // feeds only its own new stat via a separate resolve path, exactly like
    // Pummarola/Recovery above.
    const ITEM_DUPLICATOR = 9;
    const ITEM_CROWN = 10;
    const MAX_PASSIVE_RANK = 5;
    const MAX_DUPLICATOR_RANK = 2;

    // P040 adapter-only IDs for the global-strike weapons; see
    // DSP040GlobalRows for the compiled per-rank rows these key into. These
    // are engineering adapter IDs, not asserted source inventory identity.
    const SYSTEM_LIGHTNING = 50;
    const SYSTEM_THUNDER_LOOP = 51;
    const SYSTEM_PENTAGRAM = 52;
    const SYSTEM_GORGEOUS_MOON = 53;

    const SYSTEM_WHIP = 1;
    const SYSTEM_BLOODY_TEAR = 6;
    // P034 adapter-only IDs. These do not claim source registry identity or
    // replace P031 weapon inventory IDs; they key eligibility for the shared
    // resolved stat snapshot at attack emission.
    const SYSTEM_MAGIC_WAND = 34;
    const SYSTEM_HOLY_WAND = 35;
    const SYSTEM_KNIFE = 36;
    const SYSTEM_THOUSAND_EDGE = 37;
    // P035 ballistic adapter IDs remain separate from the source inventory
    // weapon identities and affect only resolved Might/Cooldown eligibility.
    const SYSTEM_AXE = 38;
    const SYSTEM_DEATH_SPIRAL = 39;
    const SYSTEM_FIRE_WAND = 40;
    const SYSTEM_HELLFIRE = 41;
    // P036 returning adapter IDs; eligible only for the existing resolved
    // Might and Cooldown channels. Luck remains a separate unresolved flag.
    const SYSTEM_CROSS = 42;
    const SYSTEM_HEAVEN_SWORD = 43;
    // P037 orbit adapters are a separate engine scheduling identity, not an
    // asserted source inventory key. Only Might/Cooldown are resolved here;
    // report-driven Duration remains the row-owned activation window.
    const SYSTEM_KING_BIBLE = 44;
    const SYSTEM_UNHOLY_VESPERS = 45;
    // P038 ground-weapon adapter IDs; only Might and Cooldown are resolved.
    // Area, Duration, projectile Speed, and Move Speed remain explicit
    // controlled fixture inputs rather than inferred passive effects.
    const SYSTEM_HOLY_WATER = 46;
    const SYSTEM_LA_BORRA = 47;
    // P039 aura adapter IDs; only Might and Cooldown are resolved. Area,
    // Duration, Amount and Speed remain explicit row/fixture inputs per the
    // frozen auras-healing contract (Garlic/Soul Eater ignore or do not use
    // those channels as inferred passive effects).
    const SYSTEM_GARLIC = 48;
    const SYSTEM_SOUL_EATER = 49;
    // P041 bounce-weapon adapter IDs; only Might and Cooldown are resolved.
    // Area, Speed, Amount and Duration remain explicit row/fixture inputs
    // per the frozen bounce-projectiles contract.
    const SYSTEM_RUNETRACER = 54;
    const SYSTEM_NO_FUTURE = 55;
    const SYSTEM_BONE = 56;
    const SYSTEM_CHERRY = 57;
    const SYSTEM_CARRELLO = 58;
    // P042 paired-weapon/union adapter IDs; only Might and Cooldown are
    // resolved. Area, Speed, Amount, Duration, Pierce, crit and the
    // movement-streak bonus remain explicit row/fixture inputs per the
    // frozen paired-unions contract (the streak bonus is explicitly
    // Might-exempt).
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
    const SYSTEM_PLAYER_HEALTH = 100;
    const SYSTEM_INCOMING_DAMAGE = 101;
    const SYSTEM_DIAGNOSTIC_WEAPON = 900;

    // Compiled rank-indexed mirror of data/verified/base/passives/*.json.
    // The data records are canonical; the focused parity test requires every
    // compiled effect to match every JSON rank row before this table is used.
    static int PassiveRowEffect(int itemId, int rank)
    {
        if (rank < 1 || rank > MAX_PASSIVE_RANK) return 0;
        if (itemId == ITEM_SPINACH && rank == 1) return 100;
        if (itemId == ITEM_SPINACH && rank == 2) return 100;
        if (itemId == ITEM_SPINACH && rank == 3) return 100;
        if (itemId == ITEM_SPINACH && rank == 4) return 100;
        if (itemId == ITEM_SPINACH && rank == 5) return 100;
        if (itemId == ITEM_ARMOR && rank == 1) return 1;
        if (itemId == ITEM_ARMOR && rank == 2) return 1;
        if (itemId == ITEM_ARMOR && rank == 3) return 1;
        if (itemId == ITEM_ARMOR && rank == 4) return 1;
        if (itemId == ITEM_ARMOR && rank == 5) return 1;
        if (itemId == ITEM_HOLLOW_HEART && rank == 1) return 1200;
        if (itemId == ITEM_HOLLOW_HEART && rank == 2) return 1200;
        if (itemId == ITEM_HOLLOW_HEART && rank == 3) return 1200;
        if (itemId == ITEM_HOLLOW_HEART && rank == 4) return 1200;
        if (itemId == ITEM_HOLLOW_HEART && rank == 5) return 1200;
        if (itemId == ITEM_EMPTY_TOME && rank == 1) return 80;
        if (itemId == ITEM_EMPTY_TOME && rank == 2) return 80;
        if (itemId == ITEM_EMPTY_TOME && rank == 3) return 80;
        if (itemId == ITEM_EMPTY_TOME && rank == 4) return 80;
        if (itemId == ITEM_EMPTY_TOME && rank == 5) return 80;
        if (itemId == ITEM_PUMMAROLA && rank == 1) return 200;
        if (itemId == ITEM_PUMMAROLA && rank == 2) return 200;
        if (itemId == ITEM_PUMMAROLA && rank == 3) return 200;
        if (itemId == ITEM_PUMMAROLA && rank == 4) return 200;
        if (itemId == ITEM_PUMMAROLA && rank == 5) return 200;
        if (itemId == ITEM_DUPLICATOR && rank == 1) return 1;
        if (itemId == ITEM_DUPLICATOR && rank == 2) return 1;
        if (itemId == ITEM_CROWN && rank == 1) return 80;
        if (itemId == ITEM_CROWN && rank == 2) return 80;
        if (itemId == ITEM_CROWN && rank == 3) return 80;
        if (itemId == ITEM_CROWN && rank == 4) return 80;
        if (itemId == ITEM_CROWN && rank == 5) return 80;
        return 0;
    }

    // Separate P039 resolve path for Recovery. Kept apart from Resolve()
    // above so that function's signature, rank hash and byte-identical
    // Might/Armor/MaxHealth/Cooldown outputs for existing ranks are
    // untouched by adding a fifth passive.
    static bool ResolveRecovery(int pummarolaRank, out int recoveryMilliPerSecond)
    {
        recoveryMilliPerSecond = 0;
        if (!ValidPummarolaRank(pummarolaRank)) return false;
        int recovery = 0;
        for (int i = 1; i <= pummarolaRank; i++)
            recovery += PassiveRowEffect(ITEM_PUMMAROLA, i);
        recoveryMilliPerSecond = recovery;
        return true;
    }

    static bool ValidPummarolaRank(int rank)
    {
        return rank >= 0 && rank <= MAX_PASSIVE_RANK;
    }

    // P040 separate resolve path for Amount and Growth, following the same
    // pattern as ResolveRecovery above: kept apart from Resolve() and from
    // ResolveRecovery() so neither touches the other's fields, hash, or
    // validity flag.
    static bool ResolveAmountGrowth(int duplicatorRank, int crownRank,
        out int amount, out int growthMilli)
    {
        amount = 0;
        growthMilli = 0;
        if (!ValidDuplicatorRank(duplicatorRank) || !ValidCrownRank(crownRank))
            return false;
        int amountTotal = 0;
        for (int i = 1; i <= duplicatorRank; i++)
            amountTotal += PassiveRowEffect(ITEM_DUPLICATOR, i);
        int growthTotal = 0;
        for (int i = 1; i <= crownRank; i++)
            growthTotal += PassiveRowEffect(ITEM_CROWN, i);
        amount = amountTotal;
        growthMilli = growthTotal;
        return true;
    }

    static bool ValidDuplicatorRank(int rank)
    {
        return rank >= 0 && rank <= MAX_DUPLICATOR_RANK;
    }

    static bool ValidCrownRank(int rank)
    {
        return rank >= 0 && rank <= MAX_PASSIVE_RANK;
    }

    // Extends RankHash with the Pummarola rank in a digit slot above every
    // existing term (spinach's top value is 5 * 1,000,000 = 5,000,000, well
    // below this 100,000,000 slot), so passing pummarolaRank=0 reproduces
    // RankHash(...) exactly.
    static int RankHashWithRecovery(int spinachRank, int armorRank,
        int hollowHeartRank, int emptyTomeRank, int pummarolaRank)
    {
        return RankHash(spinachRank, armorRank, hollowHeartRank, emptyTomeRank)
            + pummarolaRank * 100000000;
    }

    // P040 independent hash for the two new passives. This is deliberately
    // NOT chained onto RankHashWithRecovery's digit-slot scheme: that hash's
    // existing terms already reach ~5.05e8, and Crown's own rank cap (5)
    // would need a slot above that, which would overflow ZScript's 32-bit
    // int (max ~2.147e9) once multiplied out. Keeping Amount/Growth in a
    // separate hash keeps every prior term, including RankHashWithRecovery
    // itself, byte-identical and leaves this one trivially invertible.
    static int RankHashAmountGrowth(int duplicatorRank, int crownRank)
    {
        return 700 + duplicatorRank * 100 + crownRank;
    }

    static bool Resolve(int baseMightMilli, int baseArmorPoints,
        int baseMaxHealthMilli, int baseCooldownMultiplierMilli,
        int spinachRank, int armorRank, int hollowHeartRank, int emptyTomeRank,
        out int mightMilli, out int armorPoints, out int maxHealthMilli,
        out int cooldownMultiplierMilli, out int sourceRankHash)
    {
        mightMilli = 0;
        armorPoints = 0;
        maxHealthMilli = 0;
        cooldownMultiplierMilli = 0;
        sourceRankHash = 0;
        if (!ValidBases(baseMightMilli, baseArmorPoints, baseMaxHealthMilli,
                baseCooldownMultiplierMilli)
            || !ValidRank(ITEM_SPINACH, spinachRank)
            || !ValidRank(ITEM_ARMOR, armorRank)
            || !ValidRank(ITEM_HOLLOW_HEART, hollowHeartRank)
            || !ValidRank(ITEM_EMPTY_TOME, emptyTomeRank))
            return false;

        // Each stat applies its own typed row operation and rounding rule.
        // Might and Armor add rank rows to character base values. Max Health
        // multiplies once per rank, truncating each x1000 step. Empty Tome
        // subtracts the reported additive percentage-point row per rank.
        int might = baseMightMilli;
        for (int i = 1; i <= spinachRank; i++)
            might += PassiveRowEffect(ITEM_SPINACH, i);

        int armor = baseArmorPoints;
        for (int i = 1; i <= armorRank; i++)
            armor += PassiveRowEffect(ITEM_ARMOR, i);

        int health = baseMaxHealthMilli;
        for (int i = 1; i <= hollowHeartRank; i++)
        {
            int nextHealth;
            if (!MultiplyHealthRow(health,
                    PassiveRowEffect(ITEM_HOLLOW_HEART, i), nextHealth))
                return false;
            health = nextHealth;
        }

        int cooldown = baseCooldownMultiplierMilli;
        for (int i = 1; i <= emptyTomeRank; i++)
            cooldown -= PassiveRowEffect(ITEM_EMPTY_TOME, i);
        // Safety floor for future combined reductions. Current five rows leave
        // 600 milli, so the floor does not affect the implemented rank table.
        if (cooldown < 100) cooldown = 100;

        mightMilli = might;
        armorPoints = armor;
        maxHealthMilli = health;
        cooldownMultiplierMilli = cooldown;
        sourceRankHash = RankHash(spinachRank, armorRank,
            hollowHeartRank, emptyTomeRank);
        return true;
    }

    static bool ValidBases(int mightMilli, int armorPoints, int maxHealthMilli,
        int cooldownMultiplierMilli)
    {
        return mightMilli >= 1 && mightMilli <= 5000
            && armorPoints >= 0 && armorPoints <= 1000
            && maxHealthMilli >= 1 && maxHealthMilli <= 1000000
            && cooldownMultiplierMilli >= 1 && cooldownMultiplierMilli <= 1000;
    }

    static bool ValidRank(int itemId, int rank)
    {
        if (rank < 0 || rank > MAX_PASSIVE_RANK) return false;
        return itemId == ITEM_SPINACH || itemId == ITEM_ARMOR
            || itemId == ITEM_HOLLOW_HEART || itemId == ITEM_EMPTY_TOME;
    }

    static int RankHash(int spinachRank, int armorRank, int hollowHeartRank,
        int emptyTomeRank)
    {
        return 33033 + spinachRank * 1000000 + armorRank * 10000
            + hollowHeartRank * 100 + emptyTomeRank;
    }

    static bool StatApplies(int statId, int systemId)
    {
        if (statId == STAT_MIGHT || statId == STAT_COOLDOWN)
            return systemId == SYSTEM_WHIP || systemId == SYSTEM_BLOODY_TEAR
                || systemId == SYSTEM_MAGIC_WAND || systemId == SYSTEM_HOLY_WAND
                || systemId == SYSTEM_KNIFE || systemId == SYSTEM_THOUSAND_EDGE
                || systemId == SYSTEM_AXE || systemId == SYSTEM_DEATH_SPIRAL
                || systemId == SYSTEM_FIRE_WAND || systemId == SYSTEM_HELLFIRE
                || systemId == SYSTEM_CROSS || systemId == SYSTEM_HEAVEN_SWORD
                || systemId == SYSTEM_KING_BIBLE
                || systemId == SYSTEM_UNHOLY_VESPERS
                || systemId == SYSTEM_HOLY_WATER
                || systemId == SYSTEM_LA_BORRA
                || systemId == SYSTEM_GARLIC
                || systemId == SYSTEM_SOUL_EATER
                || systemId == SYSTEM_LIGHTNING
                || systemId == SYSTEM_THUNDER_LOOP
                || systemId == SYSTEM_PENTAGRAM
                || systemId == SYSTEM_GORGEOUS_MOON
                || systemId == SYSTEM_RUNETRACER
                || systemId == SYSTEM_NO_FUTURE
                || systemId == SYSTEM_BONE
                || systemId == SYSTEM_CHERRY
                || systemId == SYSTEM_CARRELLO
                || systemId == SYSTEM_PEACHONE
                || systemId == SYSTEM_EBONY
                || systemId == SYSTEM_VANDALIER
                || systemId == SYSTEM_PHIERA
                || systemId == SYSTEM_EIGHT
                || systemId == SYSTEM_PHIERAGGI
                || systemId == SYSTEM_VENTO
                || systemId == SYSTEM_FUWALA
                || systemId == SYSTEM_BRACELET
                || systemId == SYSTEM_BI_BRACELET
                || systemId == SYSTEM_TRI_BRACELET
                // N3 Track A (docs/contracts/remaining-weapons.md): Song of
                // Mana/Mannajja have no researched Might/Cooldown exemption
                // (only Magi-Stone's "fixed by weapon level" note does, and
                // Magi-Stone is deliberately left out of this allowlist so
                // it keeps that default no-Might behavior).
                || systemId == DSN3Rows.SYSTEM_SONG_OF_MANA
                || systemId == DSN3Rows.SYSTEM_MANNAJJA
                // N3 Track A (bounce engine): none of these six identities'
                // researched adapter_params report a Magi-Stone-style
                // "fixed by weapon level, not Might" exemption, so they get
                // the same default Might/Cooldown application as every
                // other bounce-engine system above.
                || systemId == DSN3Rows.SYSTEM_ANIMA_OF_MORTACCIO
                || systemId == DSN3Rows.SYSTEM_CARROZZA
                || systemId == DSN3Rows.SYSTEM_CELESTIAL_DUSTING
                || systemId == DSN3Rows.SYSTEM_LA_ROBBA
                || systemId == DSN3Rows.SYSTEM_PROFUSIONE_DAMORE
                || systemId == DSN3Rows.SYSTEM_YATTA_DAIKARIN;
        if (statId == STAT_ARMOR) return systemId == SYSTEM_INCOMING_DAMAGE;
        if (statId == STAT_MAX_HEALTH) return systemId == SYSTEM_PLAYER_HEALTH;
        return false;
    }

    // P040 Amount eligibility is a separate gate from StatApplies: the
    // frozen contract restricts Amount to Lightning Ring, Thunder Loop and
    // Gorgeous Moon gems (Pentagram does not use Amount at all). This is
    // intentionally not folded into StatApplies(STAT_MIGHT/STAT_COOLDOWN,...)
    // above, which is keyed by a different stat entirely.
    static bool AmountApplies(int systemId)
    {
        return systemId == SYSTEM_LIGHTNING || systemId == SYSTEM_THUNDER_LOOP
            || systemId == SYSTEM_GORGEOUS_MOON;
    }

    static int DamageAfterMight(int systemId, int baseDamage, int mightMilli)
    {
        if (baseDamage < 0 || baseDamage > 1000000) return 0;
        if (!StatApplies(STAT_MIGHT, systemId)) return baseDamage;
        int whole = baseDamage / 1000;
        int remainder = baseDamage % 1000;
        return whole * mightMilli + remainder * mightMilli / 1000;
    }

    static int CooldownAfterTome(int systemId, int baseCooldownMilli,
        int cooldownMultiplierMilli)
    {
        if (baseCooldownMilli < 0 || baseCooldownMilli > 1000000) return 0;
        if (!StatApplies(STAT_COOLDOWN, systemId)) return baseCooldownMilli;
        int whole = baseCooldownMilli / 1000;
        int remainder = baseCooldownMilli % 1000;
        return whole * cooldownMultiplierMilli
            + remainder * cooldownMultiplierMilli / 1000;
    }

    static int IncomingDamageAfterArmor(int rawDamage, int armorPoints)
    {
        if (rawDamage <= 0) return 0;
        int adjusted = rawDamage - armorPoints;
        // The community report says the minimum hit remains one; this is a
        // qualified policy and only applies when caller selects this system.
        return adjusted < 1 ? 1 : adjusted;
    }

    static int IncomingDamageMilliAfterArmor(int rawDamageMilli, int armorPoints)
    {
        if (rawDamageMilli <= 0) return 0;
        int adjusted = rawDamageMilli - armorPoints * 1000;
        return adjusted < 1000 ? 1000 : adjusted;
    }

    static bool MultiplyHealthRow(int currentHealthMilli, int factorMilli,
        out int result)
    {
        result = 0;
        if (currentHealthMilli < 0 || factorMilli < 0) return false;
        // Keep the fixed-point multiplication itself representable before
        // applying its /1000 scale. This deliberately rejects extreme
        // base/rank combinations instead of relying on wraparound or a
        // decomposition that could accept values outside the runtime's
        // supported intermediate range.
        if (factorMilli > 0 && currentHealthMilli > 2147483647 / factorMilli)
            return false;
        result = currentHealthMilli * factorMilli / 1000;
        return true;
    }

    static int DisplayHealthRounded(int maxHealthMilli)
    {
        return maxHealthMilli / 1000 + (maxHealthMilli % 1000 >= 500 ? 1 : 0);
    }

    static String Display(int statId, int mightMilli, int armorPoints,
        int maxHealthMilli, int cooldownMultiplierMilli)
    {
        if (statId == STAT_MIGHT)
            return String.Format("%d.%03dx", mightMilli / 1000,
                mightMilli % 1000);
        if (statId == STAT_ARMOR)
            return String.Format("%d", armorPoints);
        if (statId == STAT_MAX_HEALTH)
            return String.Format("%d", DisplayHealthRounded(maxHealthMilli));
        if (statId == STAT_COOLDOWN)
        {
            int reduction = 1000 - cooldownMultiplierMilli;
            return String.Format("-%d.%d%%", reduction / 10, reduction % 10);
        }
        return "?";
    }

    static String DisplayRecovery(int recoveryMilliPerSecond)
    {
        int whole = recoveryMilliPerSecond / 1000;
        int tenth = (recoveryMilliPerSecond % 1000) / 100;
        return String.Format("+%d.%d HP/s", whole, tenth);
    }
}

mixin class DSP033ResolvedStats
{
    int dsp033BaseMightMilli;
    int dsp033BaseArmorPoints;
    int dsp033BaseMaxHealthMilli;
    int dsp033BaseCooldownMultiplierMilli;
    int dsp033ResolvedMightMilli;
    int dsp033ResolvedArmorPoints;
    int dsp033ResolvedMaxHealthMilli;
    int dsp033ResolvedCooldownMultiplierMilli;
    int dsp033ResolvedRankHash;
    bool dsp033ResolvedValid;
    // P039 Recovery extension. Kept as separate fields/hash so the four
    // fields and dsp033ResolvedRankHash above stay byte-identical to their
    // pre-P039 values; dsp033ResolvedRankHashWithRecovery only differs from
    // dsp033ResolvedRankHash when pummarolaRank > 0.
    int dsp033ResolvedRecoveryMilliPerSecond;
    int dsp033ResolvedRankHashWithRecovery;
    bool dsp033ResolvedRecoveryValid;
    // P040 Amount/Growth extension. Separate fields/hash again, so none of
    // the four original fields, dsp033ResolvedRankHash, the three Recovery
    // fields, or dsp033ResolvedRankHashWithRecovery are touched by adding
    // Duplicator/Crown.
    int dsp033ResolvedAmount;
    int dsp033ResolvedGrowthMilli;
    int dsp033ResolvedRankHashAmountGrowth;
    bool dsp033ResolvedAmountGrowthValid;

    void DSP033SetBaseStats(int mightMilli, int armorPoints,
        int maxHealthMilli, int cooldownMultiplierMilli)
    {
        if (!DSP033StatRules.ValidBases(mightMilli, armorPoints,
                maxHealthMilli, cooldownMultiplierMilli))
        {
            Console.Printf("DS_P033_BASE_REJECT might_milli=%d armor=%d max_health_milli=%d cooldown_multiplier_milli=%d", mightMilli, armorPoints, maxHealthMilli, cooldownMultiplierMilli);
            return;
        }
        dsp033BaseMightMilli = mightMilli;
        dsp033BaseArmorPoints = armorPoints;
        dsp033BaseMaxHealthMilli = maxHealthMilli;
        dsp033BaseCooldownMultiplierMilli = cooldownMultiplierMilli;
        dsp033ResolvedValid = false;
    }

    bool DSP033RecomputeFromRanks(int spinachRank, int armorRank,
        int hollowHeartRank, int emptyTomeRank)
    {
        int nextMight;
        int nextArmor;
        int nextMaxHealth;
        int nextCooldown;
        int nextRankHash;
        if (!DSP033StatRules.Resolve(dsp033BaseMightMilli,
                dsp033BaseArmorPoints, dsp033BaseMaxHealthMilli,
                dsp033BaseCooldownMultiplierMilli, spinachRank, armorRank,
                hollowHeartRank, emptyTomeRank, nextMight, nextArmor,
                nextMaxHealth, nextCooldown, nextRankHash))
        {
            Console.Printf("DS_P033_RECOMPUTE accepted=0 reason=INVALID_BASE_OR_SOURCE_RANK");
            return false;
        }
        dsp033ResolvedMightMilli = nextMight;
        dsp033ResolvedArmorPoints = nextArmor;
        dsp033ResolvedMaxHealthMilli = nextMaxHealth;
        dsp033ResolvedCooldownMultiplierMilli = nextCooldown;
        dsp033ResolvedRankHash = nextRankHash;
        dsp033ResolvedValid = true;
        Console.Printf("DS_P033_RECOMPUTE accepted=1 rank_hash=%d spinach=%d armor_rank=%d hollow_heart=%d empty_tome=%d might_milli=%d armor=%d max_health_milli=%d displayed_health=%d cooldown_multiplier_milli=%d", nextRankHash, spinachRank, armorRank, hollowHeartRank, emptyTomeRank, nextMight, nextArmor, nextMaxHealth, DSP033StatRules.DisplayHealthRounded(nextMaxHealth), nextCooldown);
        return true;
    }

    int DSP033Resolved(int statId)
    {
        if (statId == DSP033StatRules.STAT_RECOVERY)
            return dsp033ResolvedRecoveryValid
                ? dsp033ResolvedRecoveryMilliPerSecond : 0;
        if (statId == DSP033StatRules.STAT_AMOUNT)
            return dsp033ResolvedAmountGrowthValid ? dsp033ResolvedAmount : 0;
        if (statId == DSP033StatRules.STAT_GROWTH)
            return dsp033ResolvedAmountGrowthValid ? dsp033ResolvedGrowthMilli : 0;
        if (!dsp033ResolvedValid) return 0;
        if (statId == DSP033StatRules.STAT_MIGHT) return dsp033ResolvedMightMilli;
        if (statId == DSP033StatRules.STAT_ARMOR) return dsp033ResolvedArmorPoints;
        if (statId == DSP033StatRules.STAT_MAX_HEALTH) return dsp033ResolvedMaxHealthMilli;
        if (statId == DSP033StatRules.STAT_COOLDOWN) return dsp033ResolvedCooldownMultiplierMilli;
        return 0;
    }

    // P039 addition. Recomputes Recovery from a Pummarola rank without
    // touching any of the four pre-existing resolved fields, then combines
    // the current dsp033ResolvedRankHash with the Pummarola rank into a
    // separate hash field. Callers that never call this (every pre-P039
    // caller) leave dsp033ResolvedRecoveryValid false and
    // DSP033Resolved(STAT_RECOVERY) at 0, and dsp033ResolvedRankHash itself
    // is never written by this method.
    bool DSP033RecomputeRecovery(int pummarolaRank)
    {
        int nextRecovery;
        if (!DSP033StatRules.ResolveRecovery(pummarolaRank, nextRecovery))
        {
            Console.Printf("DS_P039_RECOVERY_RECOMPUTE accepted=0 reason=INVALID_PUMMAROLA_RANK");
            return false;
        }
        dsp033ResolvedRecoveryMilliPerSecond = nextRecovery;
        dsp033ResolvedRecoveryValid = true;
        // dsp033ResolvedRankHash was computed by the untouched
        // DSP033RecomputeFromRanks path; adding the Pummarola term on top
        // reproduces RankHashWithRecovery(...) and is exactly
        // dsp033ResolvedRankHash when pummarolaRank is 0.
        dsp033ResolvedRankHashWithRecovery = dsp033ResolvedRankHash
            + pummarolaRank * 100000000;
        Console.Printf("DS_P039_RECOVERY_RECOMPUTE accepted=1 pummarola_rank=%d recovery_milli_per_second=%d rank_hash_with_recovery=%d", pummarolaRank, nextRecovery, dsp033ResolvedRankHashWithRecovery);
        return true;
    }

    // P040 addition. Recomputes Amount/Growth from Duplicator/Crown ranks
    // without touching any of the four original fields, the three Recovery
    // fields, dsp033ResolvedRankHash, or dsp033ResolvedRankHashWithRecovery.
    // Callers that never call this (every pre-P040 caller) leave
    // dsp033ResolvedAmountGrowthValid false and DSP033Resolved(STAT_AMOUNT/
    // STAT_GROWTH) at 0.
    bool DSP033RecomputeAmountGrowth(int duplicatorRank, int crownRank)
    {
        int nextAmount;
        int nextGrowthMilli;
        if (!DSP033StatRules.ResolveAmountGrowth(duplicatorRank, crownRank,
                nextAmount, nextGrowthMilli))
        {
            Console.Printf("DS_P040_AMOUNT_GROWTH_RECOMPUTE accepted=0 reason=INVALID_DUPLICATOR_OR_CROWN_RANK");
            return false;
        }
        dsp033ResolvedAmount = nextAmount;
        dsp033ResolvedGrowthMilli = nextGrowthMilli;
        dsp033ResolvedAmountGrowthValid = true;
        dsp033ResolvedRankHashAmountGrowth = DSP033StatRules
            .RankHashAmountGrowth(duplicatorRank, crownRank);
        Console.Printf("DS_P040_AMOUNT_GROWTH_RECOMPUTE accepted=1 duplicator_rank=%d crown_rank=%d amount=%d growth_milli=%d rank_hash_amount_growth=%d", duplicatorRank, crownRank, nextAmount, nextGrowthMilli, dsp033ResolvedRankHashAmountGrowth);
        return true;
    }

    String DSP033Display(int statId)
    {
        if (statId == DSP033StatRules.STAT_RECOVERY)
            return dsp033ResolvedRecoveryValid
                ? DSP033StatRules.DisplayRecovery(dsp033ResolvedRecoveryMilliPerSecond)
                : "unresolved";
        return dsp033ResolvedValid
            ? DSP033StatRules.Display(statId, dsp033ResolvedMightMilli,
                dsp033ResolvedArmorPoints, dsp033ResolvedMaxHealthMilli,
                dsp033ResolvedCooldownMultiplierMilli) : "unresolved";
    }

    bool DSP033StatApplies(int statId, int systemId)
    {
        return DSP033StatRules.StatApplies(statId, systemId);
    }

    // P040 accessor mirroring DSP033StatApplies above, for the separate
    // Amount eligibility gate.
    bool DSP033AmountApplies(int systemId)
    {
        return DSP033StatRules.AmountApplies(systemId);
    }
}
