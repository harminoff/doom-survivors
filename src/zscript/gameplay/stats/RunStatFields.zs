// Effective run stats for normal play (TODO step 4): character + PowerUps +
// passive items, recomputed by DSP030VerticalSlice.RecomputeRunStats().
// Declared here, early in the ZSCRIPT include order, so every weapon engine
// mixin can read them. Multipliers are milli (1000 = x1).
//
// rsActive is only true in normal play (manual/soak_n2 with the Mad Forest
// rules). The controlled fixture routes keep their original DSP033 paths.
mixin class DSRunStatFields
{
    bool rsActive;
    // Normal play with telemetry off (the launcher): skip per-hit and
    // per-projectile log lines. Automated runs keep telemetry on.
    bool dsQuiet;
    int rsMightMilli;
    int rsCooldownMilli;
    int rsAreaMilli;
    int rsSpeedMilli;
    int rsDurationMilli;
    int rsAmount;
    int rsMoveMilli;
    int rsMagnetMilli;
    int rsLuckMilli;
    int rsGrowthMilli;
    int rsGreedMilli;
    int rsCurseMilli;
    int rsMaxHealthMilli;
    int rsRecoveryMilli;
    int rsArmor;
    int rsRevivalsGranted;
    int rsRevivalsUsed;
    int rsCharacter;
    Array<int> rsPowerUpRanks;

    // Limit Break (wiki approximation): once the build is maxed, level-ups
    // offer per-weapon stat bonuses. Bonuses are keyed by weapon system and
    // read through the Rs*For helpers below; an evolution starts a new
    // system, so its bonuses start from zero. lbOwnedSystems is the owned
    // weapon list the draft picks from (synced by the N2 dispatcher).
    bool lbEnabled;
    // Arcana effects the shared engines read (set by SliceArcana.zs):
    // Sarabande of Healing doubles heals; Beginning adds Amount.
    bool arHealDouble;
    int arPierceBonus;   // Iron Blue Will / Waltz of Pearls: extra targets per projectile
    int arBeginningSystem;
    Array<int> lbSystems;
    Array<int> lbMight;     // milli added to the Might multiplier
    Array<int> lbArea;      // milli added to the Area multiplier
    Array<int> lbSpeed;     // milli added to the Speed multiplier
    Array<int> lbAmount;    // extra projectiles
    Array<int> lbDuration;  // milli added to the Duration multiplier
    Array<int> lbPierce;    // extra targets per projectile
    Array<int> lbOwnedSystems;

    int LbIndex(int system)
    {
        for (int i = 0; i < lbSystems.Size(); i++)
            if (lbSystems[i] == system) return i;
        return -1;
    }

    void LbReset()
    {
        lbSystems.Clear(); lbMight.Clear(); lbArea.Clear(); lbSpeed.Clear(); lbAmount.Clear();
        lbDuration.Clear(); lbPierce.Clear();
        lbOwnedSystems.Clear();
    }

    // Scales a milli multiplier by (1 + bonus); bonus is milli.
    int LbScale(int valueMilli, int bonusMilli)
    {
        if (bonusMilli <= 0) return valueMilli;
        return int(double(valueMilli) * (1000 + bonusMilli) / 1000.0);
    }

    // Might for one weapon: base (usually rsMightMilli) times its bonus.
    int LbMightFor(int system, int baseMilli)
    {
        int i = rsActive ? LbIndex(system) : -1;
        return i < 0 ? baseMilli : LbScale(baseMilli, lbMight[i]);
    }

    int RsMightFor(int system) { return LbMightFor(system, rsMightMilli); }

    int RsAreaFor(int system)
    {
        int i = LbIndex(system);
        return i < 0 ? rsAreaMilli : LbScale(rsAreaMilli, lbArea[i]);
    }

    int RsSpeedFor(int system)
    {
        int i = LbIndex(system);
        return i < 0 ? rsSpeedMilli : LbScale(rsSpeedMilli, lbSpeed[i]);
    }

    int RsDurationFor(int system)
    {
        int i = LbIndex(system);
        return i < 0 ? rsDurationMilli : LbScale(rsDurationMilli, lbDuration[i]);
    }

    int RsPierceFor(int system)
    {
        int i = LbIndex(system);
        return (i < 0 ? 0 : lbPierce[i]) + arPierceBonus;
    }

    int RsAmountFor(int system)
    {
        int i = LbIndex(system);
        int amount = i < 0 ? rsAmount : rsAmount + lbAmount[i];
        return amount + ArcanaAmountFor(system);
    }

    // Beginning (X): the starting weapon +3 Amount; Bone, Cherry Bomb,
    // Carrello, Celestial Dusting and La Robba +1 (wiki).
    int ArcanaAmountFor(int system)
    {
        if (arBeginningSystem <= 0) return 0;
        if (system == arBeginningSystem) return 3;
        if (system == DSN2Catalog.ID_BONE || system == DSN2Catalog.ID_CHERRY_BOMB
            || system == DSN2Catalog.ID_CARRELLO || system == DSN2Catalog.ID_N3_CELESTIAL_DUSTING
            || system == DSN2Catalog.ID_N3_LA_ROBBA) return 1;
        return 0;
    }
}

// Limit Break offers are encoded as OFFER_BASE + system * 10 + stat so they
// travel through the ordinary draft offer IDs (catalog IDs stay below 1000).
class DSLimitBreak
{
    const OFFER_BASE = 100000;
    const STAT_MIGHT = 1;
    const STAT_AREA = 2;
    const STAT_SPEED = 3;
    const STAT_AMOUNT = 4;
    const STAT_DURATION = 5;
    const STAT_PIERCE = 6;
    const STAT_LAST = 6;
    // Per-pick bonus (milli, or projectiles for Amount), wiki approximations.
    const MIGHT_STEP = 5;      // +0.5%
    const AREA_STEP = 25;      // +2.5%
    const SPEED_STEP = 50;     // +5%
    const AMOUNT_STEP = 1;
    const DURATION_STEP = 25;  // +2.5%
    const PIERCE_STEP = 1;
    // Bonus caps (approximation of the wiki's per-weapon totals).
    const AREA_CAP = 5000;
    const SPEED_CAP = 2000;
    const AMOUNT_CAP = 10;
    const DURATION_CAP = 5000;
    const PIERCE_CAP = 10;

    static clearscope bool IsOffer(int id) { return id >= OFFER_BASE; }
    static clearscope int OfferId(int system, int stat) { return OFFER_BASE + system * 10 + stat; }
    static clearscope int System(int id) { return (id - OFFER_BASE) / 10; }
    static clearscope int Stat(int id) { return (id - OFFER_BASE) % 10; }

    // Rarity weights from the wiki table.
    static clearscope int Weight(int stat) { return stat == STAT_AMOUNT || stat == STAT_PIERCE ? 1 : 10; }

    static clearscope String StatText(int stat)
    {
        if (stat == STAT_MIGHT) return "+0.5% Might";
        if (stat == STAT_AREA) return "+2.5% Area";
        if (stat == STAT_SPEED) return "+5% Speed";
        if (stat == STAT_DURATION) return "+2.5% Duration";
        if (stat == STAT_PIERCE) return "+1 Pierce";
        return "+1 Amount";
    }

    static clearscope String WeaponName(int system)
    {
        return DSN2Catalog.IsKnown(system) ? DSN2Catalog.DisplayName(system) : "Weapon";
    }

    static clearscope String Name(int id) { return WeaponName(System(id)); }
}
