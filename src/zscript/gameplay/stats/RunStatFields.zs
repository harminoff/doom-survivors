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
    int arPierceBonus;   // unused (kept for saves); see ArcanaPierceFor
    // Owned list-scoped Arcanas (set by ArcanaAdjustStats; the bonuses only
    // reach their listed weapons, DSArcana.Lists).
    bool arGemini; bool arIronBlue; bool arWaltz;
    bool arTragicMoving;   // Tragic Princess owned and the character moving
    // A character whose starting weapon grows: that weapon and its extra Might.
    int rsGrowSystem; int rsGrowMilli;
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

    int RsMightFor(int system)
    {
        int might = LbMightFor(system, rsMightMilli);
        return system == rsGrowSystem && rsGrowSystem > 0 ? might + rsGrowMilli : might;
    }

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
        return (i < 0 ? 0 : lbPierce[i]) + ArcanaPierceFor(system);
    }

    int RsAmountFor(int system)
    {
        int i = LbIndex(system);
        int amount = i < 0 ? rsAmount : rsAmount + lbAmount[i];
        return amount + ArcanaAmountFor(system);
    }

    // Beginning (X): the starting weapon +3 Amount; Bone, Cherry Bomb,
    // Carrello, Celestial Dusting and La Robba +1 (wiki).
    // A weapon's cooldown multiplier: Tragic Princess takes 30% off its listed
    // weapons while the character moves.
    int RsCooldownFor(int system, int baseMilli)
    {
        if (arTragicMoving && DSArcana.Lists(DSArcana.TRAGIC_PRINCESS, system)) return max(100, baseMilli * 7 / 10);
        return baseMilli;
    }

    // Iron Blue Will / Waltz of Pearls: extra targets for listed projectiles.
    int ArcanaPierceFor(int system)
    {
        int bonus = 0;
        if (arIronBlue && DSArcana.Lists(DSArcana.IRON_BLUE_WILL, system)) bonus += 99;
        if (arWaltz && DSArcana.Lists(DSArcana.WALTZ_OF_PEARLS, system)) bonus += 3;
        return bonus;
    }

    int ArcanaAmountFor(int system)
    {
        // Gemini: listed weapons +1 (stand-in for their counterpart copies).
        int gemini = arGemini && DSArcana.Lists(DSArcana.GEMINI, system) ? 1 : 0;
        if (arBeginningSystem <= 0) return gemini;
        if (system == arBeginningSystem) return 3 + gemini;
        if (system == DSN2Catalog.ID_BONE || system == DSN2Catalog.ID_CHERRY_BOMB
            || system == DSN2Catalog.ID_CARRELLO || system == DSN2Catalog.ID_N3_CELESTIAL_DUSTING
            || system == DSN2Catalog.ID_N3_LA_ROBBA) return 1 + gemini;
        return gemini;
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
    // Per-pick bonus (milli, or projectiles for Amount) and caps from the
    // wiki's Limit Break tables; Duration stays a percentage here (the
    // original adds milliseconds per weapon).
    const MIGHT_STEP = 50;     // +5%
    const AREA_STEP = 25;      // +2.5%
    const SPEED_STEP = 50;     // +5%
    const AMOUNT_STEP = 1;
    const DURATION_STEP = 25;  // +2.5%
    const PIERCE_STEP = 1;
    const AREA_CAP = 10000;
    const SPEED_CAP = 3000;
    const AMOUNT_CAP = 20;
    const DURATION_CAP = 5000;
    const PIERCE_CAP = 10;

    static clearscope bool IsOffer(int id) { return id >= OFFER_BASE; }
    static clearscope int OfferId(int system, int stat) { return OFFER_BASE + system * 10 + stat; }
    static clearscope int System(int id) { return (id - OFFER_BASE) / 10; }
    static clearscope int Stat(int id) { return (id - OFFER_BASE) % 10; }

    // Rarity weights from the wiki table.
    static clearscope int Weight(int stat)
    {
        if (stat == STAT_AMOUNT || stat == STAT_DURATION) return 1;
        return stat == STAT_PIERCE ? 5 : 10;
    }

    // Which stats the original offers per weapon (bit 1 << STAT_*); weapons
    // the original has no table for get Might and Area.
    static clearscope int StatMask(int system)
    {
        switch (system)
        {
        case DSN2Catalog.ID_PENTAGRAM: case DSN2Catalog.ID_N3_LAUREL:
            return 0;
        case DSN2Catalog.ID_GARLIC: case DSN2Catalog.ID_SOUL_EATER:
            return 6;
        case DSN2Catalog.ID_GORGEOUS_MOON:
            return 16;
        case DSN2Catalog.ID_WHIP: case DSN2Catalog.ID_LIGHTNING_RING: case DSN2Catalog.ID_BLOODY_TEAR:
        case DSN2Catalog.ID_THUNDER_LOOP: case DSN2Catalog.ID_N3_CELESTIAL_VOULGE: case DSN2Catalog.ID_N3_CRIMSON_SHROUD:
        case DSN2Catalog.ID_N3_GLASS_FANDANGO: case DSN2Catalog.ID_N3_PHAS3R: case DSN2Catalog.ID_N3_PHOTONSTORM:
        case DSN2Catalog.ID_N3_SPIRIT_DISTURBANCE: case DSN2Catalog.ID_N3_UNEARTHLY_BOLT: case DSN2Catalog.ID_N3_VICTORY_SWORD:
            return 22;
        case DSN2Catalog.ID_N3_KYRA_STONES: case DSN2Catalog.ID_N3_MAGI_STONE:
            return 28;
        case DSN2Catalog.ID_FIRE_WAND: case DSN2Catalog.ID_CROSS: case DSN2Catalog.ID_DEATH_SPIRAL:
        case DSN2Catalog.ID_HELLFIRE: case DSN2Catalog.ID_HEAVEN_SWORD: case DSN2Catalog.ID_N3_MAZO_FAMILIAR:
        case DSN2Catalog.ID_N3_PAKO_BATTILIAR:
            return 30;
        case DSN2Catalog.ID_N3_CLOCK_LANCET: case DSN2Catalog.ID_N3_INFINITE_CORRIDOR:
            return 32;
        case DSN2Catalog.ID_N3_GUNASTROPHE:
            return 34;
        case DSN2Catalog.ID_N3_MANNAJJA: case DSN2Catalog.ID_N3_SONG_OF_MANA:
            return 38;
        case DSN2Catalog.ID_N3_TONN_ODDEEO: case DSN2Catalog.ID_N3_TONN_OMOTO: case DSN2Catalog.ID_N3_TONNADO:
        case DSN2Catalog.ID_N3_TONNE: case DSN2Catalog.ID_N3_TONNO_SUBITO: case DSN2Catalog.ID_N3_UNSURPASSED:
            return 46;
        case DSN2Catalog.ID_SANTA_WATER: case DSN2Catalog.ID_BRACELET: case DSN2Catalog.ID_LA_BORRA:
        case DSN2Catalog.ID_BI_BRACELET: case DSN2Catalog.ID_TRI_BRACELET: case DSN2Catalog.ID_N3_ASHES_OF_MUSPELL:
        case DSN2Catalog.ID_N3_EMBRACE_OF_GAEA: case DSN2Catalog.ID_N3_FLAMES_OF_MISSPELL: case DSN2Catalog.ID_N3_GAZE_OF_GAEA:
        case DSN2Catalog.ID_N3_SANTA_JAVELIN: case DSN2Catalog.ID_N3_SERAPHIC_CRY:
            return 54;
        case DSN2Catalog.ID_KING_BIBLE: case DSN2Catalog.ID_RUNETRACER: case DSN2Catalog.ID_PEACHONE:
        case DSN2Catalog.ID_EBONY_WINGS: case DSN2Catalog.ID_VENTO_SACRO: case DSN2Catalog.ID_UNHOLY_VESPERS:
        case DSN2Catalog.ID_NO_FUTURE: case DSN2Catalog.ID_BONE: case DSN2Catalog.ID_CHERRY_BOMB:
        case DSN2Catalog.ID_VANDALIER: case DSN2Catalog.ID_FUWALAFUWALOO: case DSN2Catalog.ID_N3_ANIMA_OF_MORTACCIO:
        case DSN2Catalog.ID_N3_CELESTIAL_DUSTING: case DSN2Catalog.ID_N3_GATTI_AMARI: case DSN2Catalog.ID_N3_GREATEST_JUBILEE:
        case DSN2Catalog.ID_N3_LA_ROBBA: case DSN2Catalog.ID_N3_MIRACLE_OF_MULTIPLICATION: case DSN2Catalog.ID_N3_PROFUSIONE_DAMORE:
        case DSN2Catalog.ID_N3_SHADOW_PINION: case DSN2Catalog.ID_N3_VALKYRIE_TURNER: case DSN2Catalog.ID_N3_VICIOUS_HUNGER:
        case DSN2Catalog.ID_N3_YATTA_DAIKARIN:
            return 62;
        case DSN2Catalog.ID_MAGIC_WAND: case DSN2Catalog.ID_KNIFE: case DSN2Catalog.ID_AXE:
        case DSN2Catalog.ID_PHIERA: case DSN2Catalog.ID_EIGHT: case DSN2Catalog.ID_HOLY_WAND:
        case DSN2Catalog.ID_THOUSAND_EDGE: case DSN2Catalog.ID_PHIERAGGI: case DSN2Catalog.ID_N3_AMMO_APPALATE:
            return 94;
        }
        return 6;
    }


    static clearscope String StatText(int stat)
    {
        if (stat == STAT_MIGHT) return "+5% Might";
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
