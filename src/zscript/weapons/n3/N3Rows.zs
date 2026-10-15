// N3 remaining-base-weapons compiled data mirror of the canonical
// data/verified/base/weapons/n3/*.json rows (docs/contracts/remaining-weapons.md,
// research docs/research/n3-remaining-weapons.{md,json} schema v2, retrieved
// 2026-09-28). Values here are QUALIFIED_ONLINE_REPORT / INFERENCE per the JSON's
// own per-rank derivation field: rank 1 and the reported max rank mirror the
// wiki infobox verbatim; intermediate ranks are an explicit linear-interpolation
// ENGINEERING_FALLBACK (labelled in the JSON, not claimed source-exact). This
// file supplies data only -- EngineFor() names the existing archetype or Track-B
// mechanic each system maps to, per the frozen contract; wiring those engines is
// a later task's job, not this file's.
class DSN3Rows
{
    const SYSTEM_AMMO_APPALATE = 96;
    const SYSTEM_ANIMA_OF_MORTACCIO = 123;
    const SYSTEM_ARMA_DIO = 122;
    const SYSTEM_ASHES_OF_MUSPELL = 93;
    const SYSTEM_CANDYBOX = 90;
    const SYSTEM_CARROZZA = 125;
    const SYSTEM_CELESTIAL_DUSTING = 86;
    const SYSTEM_CELESTIAL_VOULGE = 103;
    const SYSTEM_CHAOS_RUNE = 120;
    const SYSTEM_CLOCK_LANCET = 82;
    const SYSTEM_CRIMSON_SHROUD = 85;
    const SYSTEM_EMBRACE_OF_GAEA = 115;
    const SYSTEM_FLAMES_OF_MISSPELL = 92;
    const SYSTEM_GATTI_AMARI = 76;
    const SYSTEM_GAZE_OF_GAEA = 114;
    const SYSTEM_GLASS_FANDANGO = 102;
    const SYSTEM_GREATEST_JUBILEE = 89;
    const SYSTEM_GUNASTROPHE = 97;
    const SYSTEM_INFINITE_CORRIDOR = 83;
    const SYSTEM_KYRA_STONES = 117;
    const SYSTEM_LA_ROBBA = 88;
    const SYSTEM_LAUREL = 84;
    const SYSTEM_MAGI_STONE = 116;
    const SYSTEM_MANNAJJA = 79;
    const SYSTEM_MAZO_FAMILIAR = 95;
    const SYSTEM_MIRACLE_OF_MULTIPLICATION = 111;
    const SYSTEM_PAKO_BATTILIAR = 94;
    const SYSTEM_PENSHIN_FATCHA = 104;
    const SYSTEM_PHAS3R = 118;
    const SYSTEM_PHOTONSTORM = 119;
    const SYSTEM_PROFUSIONE_DAMORE = 87;
    const SYSTEM_SANTA_JAVELIN = 112;
    const SYSTEM_SERAPHIC_CRY = 113;
    const SYSTEM_SHADOW_PINION = 80;
    const SYSTEM_SONG_OF_MANA = 78;
    const SYSTEM_SPIRIT_DISTURBANCE = 99;
    const SYSTEM_TONN_ODDEEO = 108;
    const SYSTEM_TONN_OMOTO = 107;
    const SYSTEM_TONNADO = 106;
    const SYSTEM_TONNE = 109;
    const SYSTEM_TONNO_SUBITO = 105;
    const SYSTEM_UNEARTHLY_BOLT = 98;
    const SYSTEM_UNSURPASSED = 110;
    const SYSTEM_VALKYRIE_TURNER = 81;
    const SYSTEM_VICIOUS_HUNGER = 77;
    const SYSTEM_VICTORY_SWORD = 91;
    const SYSTEM_WICKED_RULER = 121;
    const SYSTEM_YATTA_DAIKARIN = 124;

    static int RankCount(int system)
    {
        if (system == SYSTEM_AMMO_APPALATE) return 8;
        if (system == SYSTEM_ANIMA_OF_MORTACCIO) return 1;
        if (system == SYSTEM_ARMA_DIO) return 0;
        if (system == SYSTEM_ASHES_OF_MUSPELL) return 1;
        if (system == SYSTEM_CANDYBOX) return 0;
        if (system == SYSTEM_CARROZZA) return 1;
        if (system == SYSTEM_CELESTIAL_DUSTING) return 8;
        if (system == SYSTEM_CELESTIAL_VOULGE) return 1;
        if (system == SYSTEM_CHAOS_RUNE) return 8;
        if (system == SYSTEM_CLOCK_LANCET) return 7;
        if (system == SYSTEM_CRIMSON_SHROUD) return 1;
        if (system == SYSTEM_EMBRACE_OF_GAEA) return 0;
        if (system == SYSTEM_FLAMES_OF_MISSPELL) return 8;
        if (system == SYSTEM_GATTI_AMARI) return 8;
        if (system == SYSTEM_GAZE_OF_GAEA) return 8;
        if (system == SYSTEM_GLASS_FANDANGO) return 8;
        if (system == SYSTEM_GREATEST_JUBILEE) return 9;
        if (system == SYSTEM_GUNASTROPHE) return 1;
        if (system == SYSTEM_INFINITE_CORRIDOR) return 1;
        if (system == SYSTEM_KYRA_STONES) return 1;
        if (system == SYSTEM_LA_ROBBA) return 8;
        if (system == SYSTEM_LAUREL) return 7;
        if (system == SYSTEM_MAGI_STONE) return 8;
        if (system == SYSTEM_MANNAJJA) return 1;
        if (system == SYSTEM_MAZO_FAMILIAR) return 1;
        if (system == SYSTEM_MIRACLE_OF_MULTIPLICATION) return 1;
        if (system == SYSTEM_PAKO_BATTILIAR) return 8;
        if (system == SYSTEM_PENSHIN_FATCHA) return 1;
        if (system == SYSTEM_PHAS3R) return 8;
        if (system == SYSTEM_PHOTONSTORM) return 1;
        if (system == SYSTEM_PROFUSIONE_DAMORE) return 1;
        if (system == SYSTEM_SANTA_JAVELIN) return 8;
        if (system == SYSTEM_SERAPHIC_CRY) return 1;
        if (system == SYSTEM_SHADOW_PINION) return 8;
        if (system == SYSTEM_SONG_OF_MANA) return 8;
        if (system == SYSTEM_SPIRIT_DISTURBANCE) return 1;
        if (system == SYSTEM_TONN_ODDEEO) return 6;
        if (system == SYSTEM_TONN_OMOTO) return 6;
        if (system == SYSTEM_TONNADO) return 6;
        if (system == SYSTEM_TONNE) return 6;
        if (system == SYSTEM_TONNO_SUBITO) return 6;
        if (system == SYSTEM_UNEARTHLY_BOLT) return 8;
        if (system == SYSTEM_UNSURPASSED) return 6;
        if (system == SYSTEM_VALKYRIE_TURNER) return 1;
        if (system == SYSTEM_VICIOUS_HUNGER) return 1;
        if (system == SYSTEM_VICTORY_SWORD) return 12;
        if (system == SYSTEM_WICKED_RULER) return 0;
        if (system == SYSTEM_YATTA_DAIKARIN) return 1;
        return 0;
    }

    static bool ValidRank(int system, int rank)
    {
        int count = RankCount(system);
        return count > 0 && rank >= 1 && rank <= count;
    }

    // Source damage x1000 (milli-damage), per rank.
    static int DamageMilli(int system, int rank)
    {
        if (!ValidRank(system, rank)) return 0;
        if (system == SYSTEM_AMMO_APPALATE)
        {
            if (rank <= 1) return 5000;
            if (rank <= 2) return 5000;
            if (rank <= 3) return 6000;
            if (rank <= 4) return 7000;
            if (rank <= 5) return 7000;
            if (rank <= 6) return 8000;
            if (rank <= 7) return 11000;
            return 11000; // rank 8 and above
        }
        if (system == SYSTEM_ANIMA_OF_MORTACCIO)
        {
            return 65000; // rank 1 and above
        }
        if (system == SYSTEM_ASHES_OF_MUSPELL)
        {
            return 50000; // rank 1 and above
        }
        if (system == SYSTEM_CARROZZA)
        {
            return 150000; // rank 1 and above
        }
        if (system == SYSTEM_CELESTIAL_DUSTING)
        {
            if (rank <= 1) return 5000;
            if (rank <= 2) return 5000;
            if (rank <= 3) return 5000;
            if (rank <= 4) return 10000;
            if (rank <= 5) return 10000;
            if (rank <= 6) return 10000;
            if (rank <= 7) return 10000;
            return 10000; // rank 8 and above
        }
        if (system == SYSTEM_CELESTIAL_VOULGE)
        {
            return 20000; // rank 1 and above
        }
        if (system == SYSTEM_CHAOS_RUNE)
        {
            if (rank <= 1) return 10000;
            if (rank <= 2) return 10000;
            if (rank <= 3) return 10000;
            if (rank <= 4) return 10000;
            if (rank <= 5) return 20000;
            if (rank <= 6) return 20000;
            if (rank <= 7) return 20000;
            return 30000; // rank 8 and above
        }
        if (system == SYSTEM_CLOCK_LANCET)
        {
            if (rank <= 1) return 0;
            if (rank <= 2) return 0;
            if (rank <= 3) return 0;
            if (rank <= 4) return 0;
            if (rank <= 5) return 0;
            if (rank <= 6) return 0;
            return 0; // rank 7 and above
        }
        if (system == SYSTEM_CRIMSON_SHROUD)
        {
            return 0; // rank 1 and above
        }
        if (system == SYSTEM_FLAMES_OF_MISSPELL)
        {
            if (rank <= 1) return 10000;
            if (rank <= 2) return 10000;
            if (rank <= 3) return 20000;
            if (rank <= 4) return 20000;
            if (rank <= 5) return 20000;
            if (rank <= 6) return 30000;
            if (rank <= 7) return 30000;
            return 30000; // rank 8 and above
        }
        if (system == SYSTEM_GATTI_AMARI)
        {
            if (rank <= 1) return 10000;
            if (rank <= 2) return 10000;
            if (rank <= 3) return 10000;
            if (rank <= 4) return 10000;
            if (rank <= 5) return 10000;
            if (rank <= 6) return 10000;
            if (rank <= 7) return 10000;
            return 10000; // rank 8 and above
        }
        if (system == SYSTEM_GAZE_OF_GAEA)
        {
            if (rank <= 1) return 5000;
            if (rank <= 2) return 5000;
            if (rank <= 3) return 10000;
            if (rank <= 4) return 10000;
            if (rank <= 5) return 10000;
            if (rank <= 6) return 10000;
            if (rank <= 7) return 10000;
            return 10000; // rank 8 and above
        }
        if (system == SYSTEM_GLASS_FANDANGO)
        {
            if (rank <= 1) return 10000;
            if (rank <= 2) return 12500;
            if (rank <= 3) return 12500;
            if (rank <= 4) return 15000;
            if (rank <= 5) return 15000;
            if (rank <= 6) return 17500;
            if (rank <= 7) return 17500;
            return 20000; // rank 8 and above
        }
        if (system == SYSTEM_GREATEST_JUBILEE)
        {
            if (rank <= 1) return 10000;
            if (rank <= 2) return 10000;
            if (rank <= 3) return 20000;
            if (rank <= 4) return 20000;
            if (rank <= 5) return 30000;
            if (rank <= 6) return 30000;
            if (rank <= 7) return 30000;
            if (rank <= 8) return 30000;
            return 30000; // rank 9 and above
        }
        if (system == SYSTEM_GUNASTROPHE)
        {
            return 6500; // rank 1 and above
        }
        if (system == SYSTEM_INFINITE_CORRIDOR)
        {
            return 0; // rank 1 and above
        }
        if (system == SYSTEM_KYRA_STONES)
        {
            return 10000; // rank 1 and above
        }
        if (system == SYSTEM_LA_ROBBA)
        {
            if (rank <= 1) return 10000;
            if (rank <= 2) return 10000;
            if (rank <= 3) return 20000;
            if (rank <= 4) return 20000;
            if (rank <= 5) return 30000;
            if (rank <= 6) return 30000;
            if (rank <= 7) return 40000;
            return 40000; // rank 8 and above
        }
        if (system == SYSTEM_LAUREL)
        {
            if (rank <= 1) return 0;
            if (rank <= 2) return 0;
            if (rank <= 3) return 0;
            if (rank <= 4) return 0;
            if (rank <= 5) return 0;
            if (rank <= 6) return 0;
            return 0; // rank 7 and above
        }
        if (system == SYSTEM_MAGI_STONE)
        {
            if (rank <= 1) return 10000;
            if (rank <= 2) return 10000;
            if (rank <= 3) return 10000;
            if (rank <= 4) return 10000;
            if (rank <= 5) return 10000;
            if (rank <= 6) return 10000;
            if (rank <= 7) return 10000;
            return 10000; // rank 8 and above
        }
        if (system == SYSTEM_MANNAJJA)
        {
            return 40000; // rank 1 and above
        }
        if (system == SYSTEM_MAZO_FAMILIAR)
        {
            return 40000; // rank 1 and above
        }
        if (system == SYSTEM_MIRACLE_OF_MULTIPLICATION)
        {
            return 10000; // rank 1 and above
        }
        if (system == SYSTEM_PAKO_BATTILIAR)
        {
            if (rank <= 1) return 20000;
            if (rank <= 2) return 20000;
            if (rank <= 3) return 20000;
            if (rank <= 4) return 30000;
            if (rank <= 5) return 30000;
            if (rank <= 6) return 30000;
            if (rank <= 7) return 30000;
            return 40000; // rank 8 and above
        }
        if (system == SYSTEM_PENSHIN_FATCHA)
        {
            return 0; // rank 1 and above
        }
        if (system == SYSTEM_PHAS3R)
        {
            if (rank <= 1) return 5000;
            if (rank <= 2) return 5000;
            if (rank <= 3) return 8000;
            if (rank <= 4) return 8000;
            if (rank <= 5) return 11000;
            if (rank <= 6) return 11000;
            if (rank <= 7) return 15000;
            return 15000; // rank 8 and above
        }
        if (system == SYSTEM_PHOTONSTORM)
        {
            return 25000; // rank 1 and above
        }
        if (system == SYSTEM_PROFUSIONE_DAMORE)
        {
            return 0; // rank 1 and above
        }
        if (system == SYSTEM_SANTA_JAVELIN)
        {
            if (rank <= 1) return 20000;
            if (rank <= 2) return 20000;
            if (rank <= 3) return 20000;
            if (rank <= 4) return 30000;
            if (rank <= 5) return 30000;
            if (rank <= 6) return 30000;
            if (rank <= 7) return 40000;
            return 70000; // rank 8 and above
        }
        if (system == SYSTEM_SERAPHIC_CRY)
        {
            return 70000; // rank 1 and above
        }
        if (system == SYSTEM_SHADOW_PINION)
        {
            if (rank <= 1) return 10000;
            if (rank <= 2) return 10000;
            if (rank <= 3) return 15000;
            if (rank <= 4) return 15000;
            if (rank <= 5) return 20000;
            if (rank <= 6) return 20000;
            if (rank <= 7) return 25000;
            return 25000; // rank 8 and above
        }
        if (system == SYSTEM_SONG_OF_MANA)
        {
            if (rank <= 1) return 10000;
            if (rank <= 2) return 10000;
            if (rank <= 3) return 10000;
            if (rank <= 4) return 20000;
            if (rank <= 5) return 20000;
            if (rank <= 6) return 30000;
            if (rank <= 7) return 30000;
            return 40000; // rank 8 and above
        }
        if (system == SYSTEM_SPIRIT_DISTURBANCE)
        {
            return 10000; // rank 1 and above
        }
        if (system == SYSTEM_TONN_ODDEEO)
        {
            if (rank <= 1) return 10000;
            if (rank <= 2) return 10000;
            if (rank <= 3) return 20000;
            if (rank <= 4) return 20000;
            if (rank <= 5) return 20000;
            return 20000; // rank 6 and above
        }
        if (system == SYSTEM_TONN_OMOTO)
        {
            if (rank <= 1) return 10000;
            if (rank <= 2) return 10000;
            if (rank <= 3) return 20000;
            if (rank <= 4) return 20000;
            if (rank <= 5) return 20000;
            return 20000; // rank 6 and above
        }
        if (system == SYSTEM_TONNADO)
        {
            if (rank <= 1) return 10000;
            if (rank <= 2) return 10000;
            if (rank <= 3) return 20000;
            if (rank <= 4) return 20000;
            if (rank <= 5) return 20000;
            return 20000; // rank 6 and above
        }
        if (system == SYSTEM_TONNE)
        {
            if (rank <= 1) return 15000;
            if (rank <= 2) return 15000;
            if (rank <= 3) return 15000;
            if (rank <= 4) return 15000;
            if (rank <= 5) return 25000;
            return 25000; // rank 6 and above
        }
        if (system == SYSTEM_TONNO_SUBITO)
        {
            if (rank <= 1) return 10000;
            if (rank <= 2) return 10000;
            if (rank <= 3) return 20000;
            if (rank <= 4) return 20000;
            if (rank <= 5) return 20000;
            return 20000; // rank 6 and above
        }
        if (system == SYSTEM_UNEARTHLY_BOLT)
        {
            if (rank <= 1) return 10000;
            if (rank <= 2) return 10000;
            if (rank <= 3) return 10000;
            if (rank <= 4) return 15000;
            if (rank <= 5) return 15000;
            if (rank <= 6) return 15000;
            if (rank <= 7) return 15000;
            return 20000; // rank 8 and above
        }
        if (system == SYSTEM_UNSURPASSED)
        {
            if (rank <= 1) return 10000;
            if (rank <= 2) return 20000;
            if (rank <= 3) return 20000;
            if (rank <= 4) return 30000;
            if (rank <= 5) return 30000;
            return 50000; // rank 6 and above
        }
        if (system == SYSTEM_VALKYRIE_TURNER)
        {
            return 35000; // rank 1 and above
        }
        if (system == SYSTEM_VICIOUS_HUNGER)
        {
            return 30000; // rank 1 and above
        }
        if (system == SYSTEM_VICTORY_SWORD)
        {
            if (rank <= 1) return 5000;
            if (rank <= 2) return 5000;
            if (rank <= 3) return 10000;
            if (rank <= 4) return 10000;
            if (rank <= 5) return 20000;
            if (rank <= 6) return 20000;
            if (rank <= 7) return 30000;
            if (rank <= 8) return 30000;
            if (rank <= 9) return 40000;
            if (rank <= 10) return 40000;
            if (rank <= 11) return 40000;
            return 40000; // rank 12 and above
        }
        if (system == SYSTEM_YATTA_DAIKARIN)
        {
            return 20000; // rank 1 and above
        }
        return 0;
    }

    // Reported Area multiplier in milli (1000 = 100%), per rank.
    static int AreaMilli(int system, int rank)
    {
        if (!ValidRank(system, rank)) return 0;
        if (system == SYSTEM_AMMO_APPALATE)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1100;
            if (rank <= 3) return 1100;
            if (rank <= 4) return 1100;
            if (rank <= 5) return 1200;
            if (rank <= 6) return 1200;
            if (rank <= 7) return 1200;
            return 1200; // rank 8 and above
        }
        if (system == SYSTEM_ANIMA_OF_MORTACCIO)
        {
            return 1600; // rank 1 and above
        }
        if (system == SYSTEM_ASHES_OF_MUSPELL)
        {
            return 20; // rank 1 and above
        }
        if (system == SYSTEM_CARROZZA)
        {
            return 10; // rank 1 and above
        }
        if (system == SYSTEM_CELESTIAL_DUSTING)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            if (rank <= 6) return 1000;
            if (rank <= 7) return 1000;
            return 1000; // rank 8 and above
        }
        if (system == SYSTEM_CELESTIAL_VOULGE)
        {
            return 1100; // rank 1 and above
        }
        if (system == SYSTEM_CHAOS_RUNE)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            if (rank <= 6) return 1000;
            if (rank <= 7) return 1000;
            return 1000; // rank 8 and above
        }
        if (system == SYSTEM_CLOCK_LANCET)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            if (rank <= 6) return 1000;
            return 1000; // rank 7 and above
        }
        if (system == SYSTEM_CRIMSON_SHROUD)
        {
            return 20; // rank 1 and above
        }
        if (system == SYSTEM_FLAMES_OF_MISSPELL)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            if (rank <= 6) return 1000;
            if (rank <= 7) return 1000;
            return 1000; // rank 8 and above
        }
        if (system == SYSTEM_GATTI_AMARI)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            if (rank <= 6) return 1000;
            if (rank <= 7) return 1000;
            return 1000; // rank 8 and above
        }
        if (system == SYSTEM_GAZE_OF_GAEA)
        {
            if (rank <= 1) return 500;
            if (rank <= 2) return 500;
            if (rank <= 3) return 500;
            if (rank <= 4) return 500;
            if (rank <= 5) return 650;
            if (rank <= 6) return 650;
            if (rank <= 7) return 650;
            return 800; // rank 8 and above
        }
        if (system == SYSTEM_GLASS_FANDANGO)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            if (rank <= 6) return 1000;
            if (rank <= 7) return 1000;
            return 1000; // rank 8 and above
        }
        if (system == SYSTEM_GREATEST_JUBILEE)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1250;
            if (rank <= 6) return 1250;
            if (rank <= 7) return 1500;
            if (rank <= 8) return 1500;
            return 1500; // rank 9 and above
        }
        if (system == SYSTEM_GUNASTROPHE)
        {
            return 1000; // rank 1 and above
        }
        if (system == SYSTEM_INFINITE_CORRIDOR)
        {
            return 1000; // rank 1 and above
        }
        if (system == SYSTEM_KYRA_STONES)
        {
            return 1500; // rank 1 and above
        }
        if (system == SYSTEM_LA_ROBBA)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            if (rank <= 6) return 1000;
            if (rank <= 7) return 1000;
            return 1000; // rank 8 and above
        }
        if (system == SYSTEM_LAUREL)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            if (rank <= 6) return 1000;
            return 1000; // rank 7 and above
        }
        if (system == SYSTEM_MAGI_STONE)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1100;
            if (rank <= 4) return 1100;
            if (rank <= 5) return 1100;
            if (rank <= 6) return 1200;
            if (rank <= 7) return 1200;
            return 1400; // rank 8 and above
        }
        if (system == SYSTEM_MANNAJJA)
        {
            return 60; // rank 1 and above
        }
        if (system == SYSTEM_MAZO_FAMILIAR)
        {
            return 1000; // rank 1 and above
        }
        if (system == SYSTEM_MIRACLE_OF_MULTIPLICATION)
        {
            return 1000; // rank 1 and above
        }
        if (system == SYSTEM_PAKO_BATTILIAR)
        {
            if (rank <= 1) return 10;
            if (rank <= 2) return 10;
            if (rank <= 3) return 10;
            if (rank <= 4) return 10;
            if (rank <= 5) return 10;
            if (rank <= 6) return 10;
            if (rank <= 7) return 10;
            return 10; // rank 8 and above
        }
        if (system == SYSTEM_PENSHIN_FATCHA)
        {
            return 1000; // rank 1 and above
        }
        if (system == SYSTEM_PHAS3R)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1500;
            if (rank <= 4) return 1500;
            if (rank <= 5) return 2000;
            if (rank <= 6) return 2000;
            if (rank <= 7) return 2500;
            return 2500; // rank 8 and above
        }
        if (system == SYSTEM_PHOTONSTORM)
        {
            return 2500; // rank 1 and above
        }
        if (system == SYSTEM_PROFUSIONE_DAMORE)
        {
            return 1000; // rank 1 and above
        }
        if (system == SYSTEM_SANTA_JAVELIN)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1500;
            if (rank <= 3) return 1500;
            if (rank <= 4) return 1500;
            if (rank <= 5) return 2000;
            if (rank <= 6) return 2000;
            if (rank <= 7) return 2000;
            return 2000; // rank 8 and above
        }
        if (system == SYSTEM_SERAPHIC_CRY)
        {
            return 1500; // rank 1 and above
        }
        if (system == SYSTEM_SHADOW_PINION)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            if (rank <= 6) return 1000;
            if (rank <= 7) return 1000;
            return 1000; // rank 8 and above
        }
        if (system == SYSTEM_SONG_OF_MANA)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 2000;
            if (rank <= 3) return 2000;
            if (rank <= 4) return 2250;
            if (rank <= 5) return 2250;
            if (rank <= 6) return 2500;
            if (rank <= 7) return 2500;
            return 2750; // rank 8 and above
        }
        if (system == SYSTEM_SPIRIT_DISTURBANCE)
        {
            return 1000; // rank 1 and above
        }
        if (system == SYSTEM_TONN_ODDEEO)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            return 1000; // rank 6 and above
        }
        if (system == SYSTEM_TONN_OMOTO)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            return 1000; // rank 6 and above
        }
        if (system == SYSTEM_TONNADO)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            return 1000; // rank 6 and above
        }
        if (system == SYSTEM_TONNE)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            return 1000; // rank 6 and above
        }
        if (system == SYSTEM_TONNO_SUBITO)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            return 1000; // rank 6 and above
        }
        if (system == SYSTEM_UNEARTHLY_BOLT)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1100;
            if (rank <= 4) return 1100;
            if (rank <= 5) return 1100;
            if (rank <= 6) return 1200;
            if (rank <= 7) return 1200;
            return 1200; // rank 8 and above
        }
        if (system == SYSTEM_UNSURPASSED)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            return 1000; // rank 6 and above
        }
        if (system == SYSTEM_VALKYRIE_TURNER)
        {
            return 1400; // rank 1 and above
        }
        if (system == SYSTEM_VICIOUS_HUNGER)
        {
            return 1000; // rank 1 and above
        }
        if (system == SYSTEM_VICTORY_SWORD)
        {
            if (rank <= 1) return 14;
            if (rank <= 2) return 14;
            if (rank <= 3) return 16;
            if (rank <= 4) return 16;
            if (rank <= 5) return 18;
            if (rank <= 6) return 18;
            if (rank <= 7) return 20;
            if (rank <= 8) return 20;
            if (rank <= 9) return 20;
            if (rank <= 10) return 20;
            if (rank <= 11) return 20;
            return 20; // rank 12 and above
        }
        if (system == SYSTEM_YATTA_DAIKARIN)
        {
            return 2000; // rank 1 and above
        }
        return 0;
    }

    // Reported Speed multiplier in milli (1000 = 100%), per rank.
    static int SpeedMilli(int system, int rank)
    {
        if (!ValidRank(system, rank)) return 0;
        if (system == SYSTEM_AMMO_APPALATE)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            if (rank <= 6) return 1000;
            if (rank <= 7) return 1000;
            return 1000; // rank 8 and above
        }
        if (system == SYSTEM_ANIMA_OF_MORTACCIO)
        {
            return 1750; // rank 1 and above
        }
        if (system == SYSTEM_ASHES_OF_MUSPELL)
        {
            return 15; // rank 1 and above
        }
        if (system == SYSTEM_CARROZZA)
        {
            return 100; // rank 1 and above
        }
        if (system == SYSTEM_CELESTIAL_DUSTING)
        {
            if (rank <= 1) return 700;
            if (rank <= 2) return 700;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1300;
            if (rank <= 6) return 1300;
            if (rank <= 7) return 1600;
            return 1600; // rank 8 and above
        }
        if (system == SYSTEM_CELESTIAL_VOULGE)
        {
            return 1000; // rank 1 and above
        }
        if (system == SYSTEM_CHAOS_RUNE)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            if (rank <= 6) return 1000;
            if (rank <= 7) return 1000;
            return 1000; // rank 8 and above
        }
        if (system == SYSTEM_CLOCK_LANCET)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            if (rank <= 6) return 1000;
            return 1000; // rank 7 and above
        }
        if (system == SYSTEM_CRIMSON_SHROUD)
        {
            return 1000; // rank 1 and above
        }
        if (system == SYSTEM_FLAMES_OF_MISSPELL)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            if (rank <= 6) return 1000;
            if (rank <= 7) return 1000;
            return 1000; // rank 8 and above
        }
        if (system == SYSTEM_GATTI_AMARI)
        {
            if (rank <= 1) return 400;
            if (rank <= 2) return 600;
            if (rank <= 3) return 600;
            if (rank <= 4) return 800;
            if (rank <= 5) return 800;
            if (rank <= 6) return 800;
            if (rank <= 7) return 1000;
            return 1000; // rank 8 and above
        }
        if (system == SYSTEM_GAZE_OF_GAEA)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            if (rank <= 6) return 1000;
            if (rank <= 7) return 1000;
            return 1000; // rank 8 and above
        }
        if (system == SYSTEM_GLASS_FANDANGO)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            if (rank <= 6) return 1000;
            if (rank <= 7) return 1000;
            return 1000; // rank 8 and above
        }
        if (system == SYSTEM_GREATEST_JUBILEE)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            if (rank <= 6) return 1000;
            if (rank <= 7) return 1000;
            if (rank <= 8) return 1000;
            return 1000; // rank 9 and above
        }
        if (system == SYSTEM_GUNASTROPHE)
        {
            return 1000; // rank 1 and above
        }
        if (system == SYSTEM_INFINITE_CORRIDOR)
        {
            return 1000; // rank 1 and above
        }
        if (system == SYSTEM_KYRA_STONES)
        {
            return 1800; // rank 1 and above
        }
        if (system == SYSTEM_LA_ROBBA)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1500;
            if (rank <= 6) return 1500;
            if (rank <= 7) return 1500;
            return 1500; // rank 8 and above
        }
        if (system == SYSTEM_LAUREL)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            if (rank <= 6) return 1000;
            return 1000; // rank 7 and above
        }
        if (system == SYSTEM_MAGI_STONE)
        {
            if (rank <= 1) return 1200;
            if (rank <= 2) return 1200;
            if (rank <= 3) return 1200;
            if (rank <= 4) return 1400;
            if (rank <= 5) return 1400;
            if (rank <= 6) return 1400;
            if (rank <= 7) return 1600;
            return 1600; // rank 8 and above
        }
        if (system == SYSTEM_MANNAJJA)
        {
            return 1000; // rank 1 and above
        }
        if (system == SYSTEM_MAZO_FAMILIAR)
        {
            return 1000; // rank 1 and above
        }
        if (system == SYSTEM_MIRACLE_OF_MULTIPLICATION)
        {
            return 1000; // rank 1 and above
        }
        if (system == SYSTEM_PAKO_BATTILIAR)
        {
            if (rank <= 1) return 10;
            if (rank <= 2) return 96;
            if (rank <= 3) return 181;
            if (rank <= 4) return 267;
            if (rank <= 5) return 353;
            if (rank <= 6) return 439;
            if (rank <= 7) return 524;
            return 610; // rank 8 and above
        }
        if (system == SYSTEM_PENSHIN_FATCHA)
        {
            return 1000; // rank 1 and above
        }
        if (system == SYSTEM_PHAS3R)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            if (rank <= 6) return 1000;
            if (rank <= 7) return 1000;
            return 1000; // rank 8 and above
        }
        if (system == SYSTEM_PHOTONSTORM)
        {
            return 1000; // rank 1 and above
        }
        if (system == SYSTEM_PROFUSIONE_DAMORE)
        {
            return 14; // rank 1 and above
        }
        if (system == SYSTEM_SANTA_JAVELIN)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            if (rank <= 6) return 1000;
            if (rank <= 7) return 1000;
            return 1000; // rank 8 and above
        }
        if (system == SYSTEM_SERAPHIC_CRY)
        {
            return 1000; // rank 1 and above
        }
        if (system == SYSTEM_SHADOW_PINION)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            if (rank <= 6) return 1000;
            if (rank <= 7) return 1000;
            return 1000; // rank 8 and above
        }
        if (system == SYSTEM_SONG_OF_MANA)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            if (rank <= 6) return 1000;
            if (rank <= 7) return 1000;
            return 1000; // rank 8 and above
        }
        if (system == SYSTEM_SPIRIT_DISTURBANCE)
        {
            return 2000; // rank 1 and above
        }
        if (system == SYSTEM_TONN_ODDEEO)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            return 1000; // rank 6 and above
        }
        if (system == SYSTEM_TONN_OMOTO)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            return 1000; // rank 6 and above
        }
        if (system == SYSTEM_TONNADO)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            return 1000; // rank 6 and above
        }
        if (system == SYSTEM_TONNE)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            return 1000; // rank 6 and above
        }
        if (system == SYSTEM_TONNO_SUBITO)
        {
            if (rank <= 1) return 800;
            if (rank <= 2) return 900;
            if (rank <= 3) return 900;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            return 1200; // rank 6 and above
        }
        if (system == SYSTEM_UNEARTHLY_BOLT)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            if (rank <= 6) return 1000;
            if (rank <= 7) return 1000;
            return 1000; // rank 8 and above
        }
        if (system == SYSTEM_UNSURPASSED)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            return 1000; // rank 6 and above
        }
        if (system == SYSTEM_VALKYRIE_TURNER)
        {
            return 3500; // rank 1 and above
        }
        if (system == SYSTEM_VICIOUS_HUNGER)
        {
            return 1000; // rank 1 and above
        }
        if (system == SYSTEM_VICTORY_SWORD)
        {
            if (rank <= 1) return 1000;
            if (rank <= 2) return 1000;
            if (rank <= 3) return 1000;
            if (rank <= 4) return 1000;
            if (rank <= 5) return 1000;
            if (rank <= 6) return 1000;
            if (rank <= 7) return 1000;
            if (rank <= 8) return 1000;
            if (rank <= 9) return 1000;
            if (rank <= 10) return 1000;
            if (rank <= 11) return 1000;
            return 1000; // rank 12 and above
        }
        if (system == SYSTEM_YATTA_DAIKARIN)
        {
            return 1600; // rank 1 and above
        }
        return 0;
    }

    // Projectile/instance amount, per rank.
    static int Amount(int system, int rank)
    {
        if (!ValidRank(system, rank)) return 0;
        if (system == SYSTEM_AMMO_APPALATE)
        {
            if (rank <= 1) return 3;
            if (rank <= 2) return 3;
            if (rank <= 3) return 4;
            if (rank <= 4) return 5;
            if (rank <= 5) return 5;
            if (rank <= 6) return 6;
            if (rank <= 7) return 6;
            return 8; // rank 8 and above
        }
        if (system == SYSTEM_ANIMA_OF_MORTACCIO)
        {
            return 3; // rank 1 and above
        }
        if (system == SYSTEM_ASHES_OF_MUSPELL)
        {
            return 12; // rank 1 and above
        }
        if (system == SYSTEM_CARROZZA)
        {
            return 3; // rank 1 and above
        }
        if (system == SYSTEM_CELESTIAL_DUSTING)
        {
            if (rank <= 1) return 1;
            if (rank <= 2) return 1;
            if (rank <= 3) return 1;
            if (rank <= 4) return 1;
            if (rank <= 5) return 1;
            if (rank <= 6) return 2;
            if (rank <= 7) return 2;
            return 2; // rank 8 and above
        }
        if (system == SYSTEM_CELESTIAL_VOULGE)
        {
            return 6; // rank 1 and above
        }
        if (system == SYSTEM_CHAOS_RUNE)
        {
            if (rank <= 1) return 1;
            if (rank <= 2) return 2;
            if (rank <= 3) return 2;
            if (rank <= 4) return 3;
            if (rank <= 5) return 3;
            if (rank <= 6) return 4;
            if (rank <= 7) return 4;
            return 4; // rank 8 and above
        }
        if (system == SYSTEM_CLOCK_LANCET)
        {
            if (rank <= 1) return 1;
            if (rank <= 2) return 1;
            if (rank <= 3) return 1;
            if (rank <= 4) return 1;
            if (rank <= 5) return 1;
            if (rank <= 6) return 1;
            return 1; // rank 7 and above
        }
        if (system == SYSTEM_CRIMSON_SHROUD)
        {
            return 1; // rank 1 and above
        }
        if (system == SYSTEM_FLAMES_OF_MISSPELL)
        {
            if (rank <= 1) return 12;
            if (rank <= 2) return 12;
            if (rank <= 3) return 12;
            if (rank <= 4) return 12;
            if (rank <= 5) return 12;
            if (rank <= 6) return 12;
            if (rank <= 7) return 12;
            return 12; // rank 8 and above
        }
        if (system == SYSTEM_GATTI_AMARI)
        {
            if (rank <= 1) return 1;
            if (rank <= 2) return 1;
            if (rank <= 3) return 1;
            if (rank <= 4) return 1;
            if (rank <= 5) return 2;
            if (rank <= 6) return 2;
            if (rank <= 7) return 2;
            return 3; // rank 8 and above
        }
        if (system == SYSTEM_GAZE_OF_GAEA)
        {
            if (rank <= 1) return 1;
            if (rank <= 2) return 2;
            if (rank <= 3) return 2;
            if (rank <= 4) return 2;
            if (rank <= 5) return 2;
            if (rank <= 6) return 3;
            if (rank <= 7) return 3;
            return 3; // rank 8 and above
        }
        if (system == SYSTEM_GLASS_FANDANGO)
        {
            if (rank <= 1) return 1;
            if (rank <= 2) return 1;
            if (rank <= 3) return 2;
            if (rank <= 4) return 2;
            if (rank <= 5) return 3;
            if (rank <= 6) return 3;
            if (rank <= 7) return 4;
            return 5; // rank 8 and above
        }
        if (system == SYSTEM_GREATEST_JUBILEE)
        {
            if (rank <= 1) return 1;
            if (rank <= 2) return 2;
            if (rank <= 3) return 2;
            if (rank <= 4) return 3;
            if (rank <= 5) return 3;
            if (rank <= 6) return 4;
            if (rank <= 7) return 4;
            if (rank <= 8) return 5;
            return 5; // rank 9 and above
        }
        if (system == SYSTEM_GUNASTROPHE)
        {
            return 1; // rank 1 and above
        }
        if (system == SYSTEM_INFINITE_CORRIDOR)
        {
            return 1; // rank 1 and above
        }
        if (system == SYSTEM_KYRA_STONES)
        {
            return 4; // rank 1 and above
        }
        if (system == SYSTEM_LA_ROBBA)
        {
            if (rank <= 1) return 3;
            if (rank <= 2) return 4;
            if (rank <= 3) return 4;
            if (rank <= 4) return 5;
            if (rank <= 5) return 5;
            if (rank <= 6) return 6;
            if (rank <= 7) return 6;
            return 7; // rank 8 and above
        }
        if (system == SYSTEM_LAUREL)
        {
            if (rank <= 1) return 1;
            if (rank <= 2) return 1;
            if (rank <= 3) return 1;
            if (rank <= 4) return 1;
            if (rank <= 5) return 1;
            if (rank <= 6) return 1;
            return 1; // rank 7 and above
        }
        if (system == SYSTEM_MAGI_STONE)
        {
            if (rank <= 1) return 1;
            if (rank <= 2) return 1;
            if (rank <= 3) return 1;
            if (rank <= 4) return 1;
            if (rank <= 5) return 1;
            if (rank <= 6) return 1;
            if (rank <= 7) return 1;
            return 1; // rank 8 and above
        }
        if (system == SYSTEM_MANNAJJA)
        {
            return 1; // rank 1 and above
        }
        if (system == SYSTEM_MAZO_FAMILIAR)
        {
            return 16; // rank 1 and above
        }
        if (system == SYSTEM_MIRACLE_OF_MULTIPLICATION)
        {
            return 1; // rank 1 and above
        }
        if (system == SYSTEM_PAKO_BATTILIAR)
        {
            if (rank <= 1) return 1;
            if (rank <= 2) return 1;
            if (rank <= 3) return 2;
            if (rank <= 4) return 3;
            if (rank <= 5) return 3;
            if (rank <= 6) return 4;
            if (rank <= 7) return 5;
            return 6; // rank 8 and above
        }
        if (system == SYSTEM_PENSHIN_FATCHA)
        {
            return 1; // rank 1 and above
        }
        if (system == SYSTEM_PHAS3R)
        {
            if (rank <= 1) return 1;
            if (rank <= 2) return 2;
            if (rank <= 3) return 2;
            if (rank <= 4) return 3;
            if (rank <= 5) return 3;
            if (rank <= 6) return 4;
            if (rank <= 7) return 4;
            return 5; // rank 8 and above
        }
        if (system == SYSTEM_PHOTONSTORM)
        {
            return 6; // rank 1 and above
        }
        if (system == SYSTEM_PROFUSIONE_DAMORE)
        {
            return 2; // rank 1 and above
        }
        if (system == SYSTEM_SANTA_JAVELIN)
        {
            if (rank <= 1) return 1;
            if (rank <= 2) return 1;
            if (rank <= 3) return 2;
            if (rank <= 4) return 2;
            if (rank <= 5) return 2;
            if (rank <= 6) return 3;
            if (rank <= 7) return 3;
            return 3; // rank 8 and above
        }
        if (system == SYSTEM_SERAPHIC_CRY)
        {
            return 3; // rank 1 and above
        }
        if (system == SYSTEM_SHADOW_PINION)
        {
            if (rank <= 1) return 1;
            if (rank <= 2) return 2;
            if (rank <= 3) return 2;
            if (rank <= 4) return 2;
            if (rank <= 5) return 2;
            if (rank <= 6) return 2;
            if (rank <= 7) return 2;
            return 2; // rank 8 and above
        }
        if (system == SYSTEM_SONG_OF_MANA)
        {
            if (rank <= 1) return 1;
            if (rank <= 2) return 1;
            if (rank <= 3) return 1;
            if (rank <= 4) return 1;
            if (rank <= 5) return 1;
            if (rank <= 6) return 1;
            if (rank <= 7) return 1;
            return 1; // rank 8 and above
        }
        if (system == SYSTEM_SPIRIT_DISTURBANCE)
        {
            return 3; // rank 1 and above
        }
        if (system == SYSTEM_TONN_ODDEEO)
        {
            if (rank <= 1) return 2;
            if (rank <= 2) return 3;
            if (rank <= 3) return 3;
            if (rank <= 4) return 4;
            if (rank <= 5) return 4;
            return 6; // rank 6 and above
        }
        if (system == SYSTEM_TONN_OMOTO)
        {
            if (rank <= 1) return 1;
            if (rank <= 2) return 1;
            if (rank <= 3) return 1;
            if (rank <= 4) return 1;
            if (rank <= 5) return 1;
            return 1; // rank 6 and above
        }
        if (system == SYSTEM_TONNADO)
        {
            if (rank <= 1) return 1;
            if (rank <= 2) return 1;
            if (rank <= 3) return 1;
            if (rank <= 4) return 1;
            if (rank <= 5) return 1;
            return 1; // rank 6 and above
        }
        if (system == SYSTEM_TONNE)
        {
            if (rank <= 1) return 1;
            if (rank <= 2) return 1;
            if (rank <= 3) return 1;
            if (rank <= 4) return 1;
            if (rank <= 5) return 1;
            return 1; // rank 6 and above
        }
        if (system == SYSTEM_TONNO_SUBITO)
        {
            if (rank <= 1) return 1;
            if (rank <= 2) return 1;
            if (rank <= 3) return 1;
            if (rank <= 4) return 1;
            if (rank <= 5) return 1;
            return 1; // rank 6 and above
        }
        if (system == SYSTEM_UNEARTHLY_BOLT)
        {
            if (rank <= 1) return 1;
            if (rank <= 2) return 2;
            if (rank <= 3) return 3;
            if (rank <= 4) return 3;
            if (rank <= 5) return 4;
            if (rank <= 6) return 5;
            if (rank <= 7) return 6;
            return 6; // rank 8 and above
        }
        if (system == SYSTEM_UNSURPASSED)
        {
            if (rank <= 1) return 2;
            if (rank <= 2) return 2;
            if (rank <= 3) return 2;
            if (rank <= 4) return 2;
            if (rank <= 5) return 2;
            return 2; // rank 6 and above
        }
        if (system == SYSTEM_VALKYRIE_TURNER)
        {
            return 1; // rank 1 and above
        }
        if (system == SYSTEM_VICIOUS_HUNGER)
        {
            return 2; // rank 1 and above
        }
        if (system == SYSTEM_VICTORY_SWORD)
        {
            if (rank <= 1) return 2;
            if (rank <= 2) return 3;
            if (rank <= 3) return 3;
            if (rank <= 4) return 4;
            if (rank <= 5) return 4;
            if (rank <= 6) return 5;
            if (rank <= 7) return 5;
            if (rank <= 8) return 5;
            if (rank <= 9) return 5;
            if (rank <= 10) return 5;
            if (rank <= 11) return 5;
            return 5; // rank 12 and above
        }
        if (system == SYSTEM_YATTA_DAIKARIN)
        {
            return 2; // rank 1 and above
        }
        return 0;
    }

    // Cooldown in 35Hz tics, per rank.
    static int CooldownTics(int system, int rank)
    {
        if (!ValidRank(system, rank)) return 0;
        if (system == SYSTEM_AMMO_APPALATE)
        {
            if (rank <= 1) return 70;
            if (rank <= 2) return 70;
            if (rank <= 3) return 70;
            if (rank <= 4) return 70;
            if (rank <= 5) return 70;
            if (rank <= 6) return 70;
            if (rank <= 7) return 70;
            return 70; // rank 8 and above
        }
        if (system == SYSTEM_ANIMA_OF_MORTACCIO)
        {
            return 0; // rank 1 and above
        }
        if (system == SYSTEM_ASHES_OF_MUSPELL)
        {
            return 70; // rank 1 and above
        }
        if (system == SYSTEM_CARROZZA)
        {
            return 448; // rank 1 and above
        }
        if (system == SYSTEM_CELESTIAL_DUSTING)
        {
            if (rank <= 1) return 210;
            if (rank <= 2) return 210;
            if (rank <= 3) return 210;
            if (rank <= 4) return 210;
            if (rank <= 5) return 210;
            if (rank <= 6) return 210;
            if (rank <= 7) return 210;
            return 210; // rank 8 and above
        }
        if (system == SYSTEM_CELESTIAL_VOULGE)
        {
            return 0; // rank 1 and above
        }
        if (system == SYSTEM_CHAOS_RUNE)
        {
            if (rank <= 1) return 105;
            if (rank <= 2) return 105;
            if (rank <= 3) return 105;
            if (rank <= 4) return 105;
            if (rank <= 5) return 105;
            if (rank <= 6) return 105;
            if (rank <= 7) return 105;
            return 105; // rank 8 and above
        }
        if (system == SYSTEM_CLOCK_LANCET)
        {
            if (rank <= 1) return 70;
            if (rank <= 2) return 70;
            if (rank <= 3) return 52;
            if (rank <= 4) return 52;
            if (rank <= 5) return 52;
            if (rank <= 6) return 35;
            return 35; // rank 7 and above
        }
        if (system == SYSTEM_CRIMSON_SHROUD)
        {
            return 280; // rank 1 and above
        }
        if (system == SYSTEM_FLAMES_OF_MISSPELL)
        {
            if (rank <= 1) return 140;
            if (rank <= 2) return 140;
            if (rank <= 3) return 140;
            if (rank <= 4) return 122;
            if (rank <= 5) return 122;
            if (rank <= 6) return 122;
            if (rank <= 7) return 105;
            return 88; // rank 8 and above
        }
        if (system == SYSTEM_GATTI_AMARI)
        {
            if (rank <= 1) return 175;
            if (rank <= 2) return 175;
            if (rank <= 3) return 175;
            if (rank <= 4) return 175;
            if (rank <= 5) return 175;
            if (rank <= 6) return 175;
            if (rank <= 7) return 175;
            return 175; // rank 8 and above
        }
        if (system == SYSTEM_GAZE_OF_GAEA)
        {
            if (rank <= 1) return 70;
            if (rank <= 2) return 70;
            if (rank <= 3) return 70;
            if (rank <= 4) return 70;
            if (rank <= 5) return 70;
            if (rank <= 6) return 70;
            if (rank <= 7) return 70;
            return 70; // rank 8 and above
        }
        if (system == SYSTEM_GLASS_FANDANGO)
        {
            if (rank <= 1) return 49;
            if (rank <= 2) return 49;
            if (rank <= 3) return 49;
            if (rank <= 4) return 49;
            if (rank <= 5) return 49;
            if (rank <= 6) return 49;
            if (rank <= 7) return 49;
            return 49; // rank 8 and above
        }
        if (system == SYSTEM_GREATEST_JUBILEE)
        {
            if (rank <= 1) return 105;
            if (rank <= 2) return 105;
            if (rank <= 3) return 88;
            if (rank <= 4) return 88;
            if (rank <= 5) return 88;
            if (rank <= 6) return 88;
            if (rank <= 7) return 70;
            if (rank <= 8) return 70;
            return 70; // rank 9 and above
        }
        if (system == SYSTEM_GUNASTROPHE)
        {
            return 210; // rank 1 and above
        }
        if (system == SYSTEM_INFINITE_CORRIDOR)
        {
            return 35; // rank 1 and above
        }
        if (system == SYSTEM_KYRA_STONES)
        {
            return 105; // rank 1 and above
        }
        if (system == SYSTEM_LA_ROBBA)
        {
            if (rank <= 1) return 158;
            if (rank <= 2) return 158;
            if (rank <= 3) return 158;
            if (rank <= 4) return 158;
            if (rank <= 5) return 158;
            if (rank <= 6) return 158;
            if (rank <= 7) return 158;
            return 158; // rank 8 and above
        }
        if (system == SYSTEM_LAUREL)
        {
            if (rank <= 1) return 350;
            if (rank <= 2) return 332;
            if (rank <= 3) return 315;
            if (rank <= 4) return 315;
            if (rank <= 5) return 298;
            if (rank <= 6) return 280;
            return 280; // rank 7 and above
        }
        if (system == SYSTEM_MAGI_STONE)
        {
            if (rank <= 1) return 122;
            if (rank <= 2) return 122;
            if (rank <= 3) return 122;
            if (rank <= 4) return 116;
            if (rank <= 5) return 116;
            if (rank <= 6) return 116;
            if (rank <= 7) return 108;
            return 108; // rank 8 and above
        }
        if (system == SYSTEM_MANNAJJA)
        {
            return 158; // rank 1 and above
        }
        if (system == SYSTEM_MAZO_FAMILIAR)
        {
            return 245; // rank 1 and above
        }
        if (system == SYSTEM_MIRACLE_OF_MULTIPLICATION)
        {
            return 35; // rank 1 and above
        }
        if (system == SYSTEM_PAKO_BATTILIAR)
        {
            if (rank <= 1) return 35;
            if (rank <= 2) return 35;
            if (rank <= 3) return 18;
            if (rank <= 4) return 18;
            if (rank <= 5) return 18;
            if (rank <= 6) return 0;
            if (rank <= 7) return 0;
            return 0; // rank 8 and above
        }
        if (system == SYSTEM_PENSHIN_FATCHA)
        {
            return 0; // rank 1 and above
        }
        if (system == SYSTEM_PHAS3R)
        {
            if (rank <= 1) return 175;
            if (rank <= 2) return 175;
            if (rank <= 3) return 175;
            if (rank <= 4) return 175;
            if (rank <= 5) return 175;
            if (rank <= 6) return 175;
            if (rank <= 7) return 175;
            return 175; // rank 8 and above
        }
        if (system == SYSTEM_PHOTONSTORM)
        {
            return 175; // rank 1 and above
        }
        if (system == SYSTEM_PROFUSIONE_DAMORE)
        {
            return 210; // rank 1 and above
        }
        if (system == SYSTEM_SANTA_JAVELIN)
        {
            if (rank <= 1) return 228;
            if (rank <= 2) return 228;
            if (rank <= 3) return 210;
            if (rank <= 4) return 210;
            if (rank <= 5) return 192;
            if (rank <= 6) return 192;
            if (rank <= 7) return 175;
            return 175; // rank 8 and above
        }
        if (system == SYSTEM_SERAPHIC_CRY)
        {
            return 175; // rank 1 and above
        }
        if (system == SYSTEM_SHADOW_PINION)
        {
            if (rank <= 1) return 210;
            if (rank <= 2) return 210;
            if (rank <= 3) return 210;
            if (rank <= 4) return 210;
            if (rank <= 5) return 210;
            if (rank <= 6) return 210;
            if (rank <= 7) return 210;
            return 210; // rank 8 and above
        }
        if (system == SYSTEM_SONG_OF_MANA)
        {
            if (rank <= 1) return 70;
            if (rank <= 2) return 70;
            if (rank <= 3) return 96;
            if (rank <= 4) return 96;
            if (rank <= 5) return 122;
            if (rank <= 6) return 122;
            if (rank <= 7) return 149;
            return 149; // rank 8 and above
        }
        if (system == SYSTEM_SPIRIT_DISTURBANCE)
        {
            return 140; // rank 1 and above
        }
        if (system == SYSTEM_TONN_ODDEEO)
        {
            if (rank <= 1) return 140;
            if (rank <= 2) return 140;
            if (rank <= 3) return 140;
            if (rank <= 4) return 140;
            if (rank <= 5) return 140;
            return 140; // rank 6 and above
        }
        if (system == SYSTEM_TONN_OMOTO)
        {
            if (rank <= 1) return 140;
            if (rank <= 2) return 133;
            if (rank <= 3) return 133;
            if (rank <= 4) return 126;
            if (rank <= 5) return 126;
            return 112; // rank 6 and above
        }
        if (system == SYSTEM_TONNADO)
        {
            if (rank <= 1) return 140;
            if (rank <= 2) return 140;
            if (rank <= 3) return 140;
            if (rank <= 4) return 140;
            if (rank <= 5) return 140;
            return 140; // rank 6 and above
        }
        if (system == SYSTEM_TONNE)
        {
            if (rank <= 1) return 140;
            if (rank <= 2) return 140;
            if (rank <= 3) return 140;
            if (rank <= 4) return 140;
            if (rank <= 5) return 140;
            return 140; // rank 6 and above
        }
        if (system == SYSTEM_TONNO_SUBITO)
        {
            if (rank <= 1) return 42;
            if (rank <= 2) return 42;
            if (rank <= 3) return 42;
            if (rank <= 4) return 42;
            if (rank <= 5) return 42;
            return 42; // rank 6 and above
        }
        if (system == SYSTEM_UNEARTHLY_BOLT)
        {
            if (rank <= 1) return 140;
            if (rank <= 2) return 140;
            if (rank <= 3) return 140;
            if (rank <= 4) return 136;
            if (rank <= 5) return 136;
            if (rank <= 6) return 136;
            if (rank <= 7) return 136;
            return 133; // rank 8 and above
        }
        if (system == SYSTEM_UNSURPASSED)
        {
            if (rank <= 1) return 140;
            if (rank <= 2) return 140;
            if (rank <= 3) return 140;
            if (rank <= 4) return 140;
            if (rank <= 5) return 133;
            return 133; // rank 6 and above
        }
        if (system == SYSTEM_VALKYRIE_TURNER)
        {
            return 210; // rank 1 and above
        }
        if (system == SYSTEM_VICIOUS_HUNGER)
        {
            return 280; // rank 1 and above
        }
        if (system == SYSTEM_VICTORY_SWORD)
        {
            if (rank <= 1) return 65;
            if (rank <= 2) return 65;
            if (rank <= 3) return 65;
            if (rank <= 4) return 65;
            if (rank <= 5) return 65;
            if (rank <= 6) return 65;
            if (rank <= 7) return 65;
            if (rank <= 8) return 65;
            if (rank <= 9) return 65;
            if (rank <= 10) return 56;
            if (rank <= 11) return 47;
            return 38; // rank 12 and above
        }
        if (system == SYSTEM_YATTA_DAIKARIN)
        {
            return 105; // rank 1 and above
        }
        return 0;
    }

    // Effect duration in 35Hz tics, per rank (0 where not applicable).
    static int DurationTics(int system, int rank)
    {
        if (!ValidRank(system, rank)) return 0;
        if (system == SYSTEM_AMMO_APPALATE)
        {
            if (rank <= 1) return 0;
            if (rank <= 2) return 0;
            if (rank <= 3) return 0;
            if (rank <= 4) return 0;
            if (rank <= 5) return 0;
            if (rank <= 6) return 0;
            if (rank <= 7) return 0;
            return 0; // rank 8 and above
        }
        if (system == SYSTEM_ANIMA_OF_MORTACCIO)
        {
            return 91; // rank 1 and above
        }
        if (system == SYSTEM_ASHES_OF_MUSPELL)
        {
            return 14; // rank 1 and above
        }
        if (system == SYSTEM_CARROZZA)
        {
            return 0; // rank 1 and above
        }
        if (system == SYSTEM_CELESTIAL_DUSTING)
        {
            if (rank <= 1) return 18;
            if (rank <= 2) return 52;
            if (rank <= 3) return 52;
            if (rank <= 4) return 52;
            if (rank <= 5) return 52;
            if (rank <= 6) return 52;
            if (rank <= 7) return 52;
            return 52; // rank 8 and above
        }
        if (system == SYSTEM_CELESTIAL_VOULGE)
        {
            return 0; // rank 1 and above
        }
        if (system == SYSTEM_CHAOS_RUNE)
        {
            if (rank <= 1) return 0;
            if (rank <= 2) return 0;
            if (rank <= 3) return 0;
            if (rank <= 4) return 0;
            if (rank <= 5) return 0;
            if (rank <= 6) return 0;
            if (rank <= 7) return 0;
            return 0; // rank 8 and above
        }
        if (system == SYSTEM_CLOCK_LANCET)
        {
            if (rank <= 1) return 70;
            if (rank <= 2) return 105;
            if (rank <= 3) return 105;
            if (rank <= 4) return 140;
            if (rank <= 5) return 175;
            if (rank <= 6) return 175;
            return 210; // rank 7 and above
        }
        if (system == SYSTEM_CRIMSON_SHROUD)
        {
            return 0; // rank 1 and above
        }
        if (system == SYSTEM_FLAMES_OF_MISSPELL)
        {
            if (rank <= 1) return 14;
            if (rank <= 2) return 14;
            if (rank <= 3) return 14;
            if (rank <= 4) return 14;
            if (rank <= 5) return 14;
            if (rank <= 6) return 14;
            if (rank <= 7) return 14;
            return 14; // rank 8 and above
        }
        if (system == SYSTEM_GATTI_AMARI)
        {
            if (rank <= 1) return 175;
            if (rank <= 2) return 175;
            if (rank <= 3) return 228;
            if (rank <= 4) return 228;
            if (rank <= 5) return 228;
            if (rank <= 6) return 280;
            if (rank <= 7) return 280;
            return 280; // rank 8 and above
        }
        if (system == SYSTEM_GAZE_OF_GAEA)
        {
            if (rank <= 1) return 7;
            if (rank <= 2) return 7;
            if (rank <= 3) return 7;
            if (rank <= 4) return 14;
            if (rank <= 5) return 14;
            if (rank <= 6) return 14;
            if (rank <= 7) return 21;
            return 21; // rank 8 and above
        }
        if (system == SYSTEM_GLASS_FANDANGO)
        {
            if (rank <= 1) return 0;
            if (rank <= 2) return 0;
            if (rank <= 3) return 0;
            if (rank <= 4) return 0;
            if (rank <= 5) return 0;
            if (rank <= 6) return 0;
            if (rank <= 7) return 0;
            return 0; // rank 8 and above
        }
        if (system == SYSTEM_GREATEST_JUBILEE)
        {
            if (rank <= 1) return 4;
            if (rank <= 2) return 4;
            if (rank <= 3) return 4;
            if (rank <= 4) return 4;
            if (rank <= 5) return 4;
            if (rank <= 6) return 4;
            if (rank <= 7) return 4;
            if (rank <= 8) return 4;
            return 4; // rank 9 and above
        }
        if (system == SYSTEM_GUNASTROPHE)
        {
            return 105; // rank 1 and above
        }
        if (system == SYSTEM_INFINITE_CORRIDOR)
        {
            return 210; // rank 1 and above
        }
        if (system == SYSTEM_KYRA_STONES)
        {
            return 0; // rank 1 and above
        }
        if (system == SYSTEM_LA_ROBBA)
        {
            if (rank <= 1) return 70;
            if (rank <= 2) return 79;
            if (rank <= 3) return 79;
            if (rank <= 4) return 88;
            if (rank <= 5) return 88;
            if (rank <= 6) return 96;
            if (rank <= 7) return 96;
            return 105; // rank 8 and above
        }
        if (system == SYSTEM_LAUREL)
        {
            if (rank <= 1) return 0;
            if (rank <= 2) return 0;
            if (rank <= 3) return 0;
            if (rank <= 4) return 0;
            if (rank <= 5) return 0;
            if (rank <= 6) return 0;
            return 0; // rank 7 and above
        }
        if (system == SYSTEM_MAGI_STONE)
        {
            if (rank <= 1) return 0;
            if (rank <= 2) return 0;
            if (rank <= 3) return 0;
            if (rank <= 4) return 0;
            if (rank <= 5) return 0;
            if (rank <= 6) return 0;
            if (rank <= 7) return 0;
            return 0; // rank 8 and above
        }
        if (system == SYSTEM_MANNAJJA)
        {
            return 70; // rank 1 and above
        }
        if (system == SYSTEM_MAZO_FAMILIAR)
        {
            return 0; // rank 1 and above
        }
        if (system == SYSTEM_MIRACLE_OF_MULTIPLICATION)
        {
            return 0; // rank 1 and above
        }
        if (system == SYSTEM_PAKO_BATTILIAR)
        {
            if (rank <= 1) return 0;
            if (rank <= 2) return 0;
            if (rank <= 3) return 0;
            if (rank <= 4) return 0;
            if (rank <= 5) return 0;
            if (rank <= 6) return 0;
            if (rank <= 7) return 0;
            return 0; // rank 8 and above
        }
        if (system == SYSTEM_PENSHIN_FATCHA)
        {
            return 0; // rank 1 and above
        }
        if (system == SYSTEM_PHAS3R)
        {
            if (rank <= 1) return 0;
            if (rank <= 2) return 0;
            if (rank <= 3) return 0;
            if (rank <= 4) return 0;
            if (rank <= 5) return 0;
            if (rank <= 6) return 0;
            if (rank <= 7) return 0;
            return 0; // rank 8 and above
        }
        if (system == SYSTEM_PHOTONSTORM)
        {
            return 0; // rank 1 and above
        }
        if (system == SYSTEM_PROFUSIONE_DAMORE)
        {
            return 52; // rank 1 and above
        }
        if (system == SYSTEM_SANTA_JAVELIN)
        {
            if (rank <= 1) return 35;
            if (rank <= 2) return 35;
            if (rank <= 3) return 35;
            if (rank <= 4) return 35;
            if (rank <= 5) return 35;
            if (rank <= 6) return 35;
            if (rank <= 7) return 35;
            return 35; // rank 8 and above
        }
        if (system == SYSTEM_SERAPHIC_CRY)
        {
            return 35; // rank 1 and above
        }
        if (system == SYSTEM_SHADOW_PINION)
        {
            if (rank <= 1) return 35;
            if (rank <= 2) return 35;
            if (rank <= 3) return 35;
            if (rank <= 4) return 44;
            if (rank <= 5) return 44;
            if (rank <= 6) return 52;
            if (rank <= 7) return 52;
            return 61; // rank 8 and above
        }
        if (system == SYSTEM_SONG_OF_MANA)
        {
            if (rank <= 1) return 18;
            if (rank <= 2) return 18;
            if (rank <= 3) return 35;
            if (rank <= 4) return 35;
            if (rank <= 5) return 52;
            if (rank <= 6) return 52;
            if (rank <= 7) return 70;
            return 70; // rank 8 and above
        }
        if (system == SYSTEM_SPIRIT_DISTURBANCE)
        {
            return 4; // rank 1 and above
        }
        if (system == SYSTEM_TONN_ODDEEO)
        {
            if (rank <= 1) return 61;
            if (rank <= 2) return 61;
            if (rank <= 3) return 61;
            if (rank <= 4) return 61;
            if (rank <= 5) return 61;
            return 61; // rank 6 and above
        }
        if (system == SYSTEM_TONN_OMOTO)
        {
            if (rank <= 1) return 61;
            if (rank <= 2) return 61;
            if (rank <= 3) return 61;
            if (rank <= 4) return 61;
            if (rank <= 5) return 70;
            return 70; // rank 6 and above
        }
        if (system == SYSTEM_TONNADO)
        {
            if (rank <= 1) return 61;
            if (rank <= 2) return 70;
            if (rank <= 3) return 70;
            if (rank <= 4) return 79;
            if (rank <= 5) return 79;
            return 96; // rank 6 and above
        }
        if (system == SYSTEM_TONNE)
        {
            if (rank <= 1) return 61;
            if (rank <= 2) return 61;
            if (rank <= 3) return 70;
            if (rank <= 4) return 70;
            if (rank <= 5) return 70;
            return 70; // rank 6 and above
        }
        if (system == SYSTEM_TONNO_SUBITO)
        {
            if (rank <= 1) return 7;
            if (rank <= 2) return 7;
            if (rank <= 3) return 7;
            if (rank <= 4) return 7;
            if (rank <= 5) return 7;
            return 7; // rank 6 and above
        }
        if (system == SYSTEM_UNEARTHLY_BOLT)
        {
            if (rank <= 1) return 4;
            if (rank <= 2) return 4;
            if (rank <= 3) return 4;
            if (rank <= 4) return 4;
            if (rank <= 5) return 4;
            if (rank <= 6) return 4;
            if (rank <= 7) return 4;
            return 4; // rank 8 and above
        }
        if (system == SYSTEM_UNSURPASSED)
        {
            if (rank <= 1) return 61;
            if (rank <= 2) return 61;
            if (rank <= 3) return 61;
            if (rank <= 4) return 61;
            if (rank <= 5) return 61;
            return 61; // rank 6 and above
        }
        if (system == SYSTEM_VALKYRIE_TURNER)
        {
            return 70; // rank 1 and above
        }
        if (system == SYSTEM_VICIOUS_HUNGER)
        {
            return 245; // rank 1 and above
        }
        if (system == SYSTEM_VICTORY_SWORD)
        {
            if (rank <= 1) return 105;
            if (rank <= 2) return 105;
            if (rank <= 3) return 105;
            if (rank <= 4) return 105;
            if (rank <= 5) return 105;
            if (rank <= 6) return 105;
            if (rank <= 7) return 105;
            if (rank <= 8) return 105;
            if (rank <= 9) return 105;
            if (rank <= 10) return 105;
            if (rank <= 11) return 105;
            return 105; // rank 12 and above
        }
        if (system == SYSTEM_YATTA_DAIKARIN)
        {
            return 91; // rank 1 and above
        }
        return 0;
    }

    // Sub-tick/hit interval in 35Hz tics, per rank.
    static int IntervalTics(int system, int rank)
    {
        if (!ValidRank(system, rank)) return 0;
        if (system == SYSTEM_AMMO_APPALATE)
        {
            if (rank <= 1) return 4;
            if (rank <= 2) return 4;
            if (rank <= 3) return 4;
            if (rank <= 4) return 4;
            if (rank <= 5) return 4;
            if (rank <= 6) return 4;
            if (rank <= 7) return 4;
            return 4; // rank 8 and above
        }
        if (system == SYSTEM_ANIMA_OF_MORTACCIO)
        {
            return 0; // rank 1 and above
        }
        if (system == SYSTEM_ASHES_OF_MUSPELL)
        {
            return 1; // rank 1 and above
        }
        if (system == SYSTEM_CARROZZA)
        {
            return 0; // rank 1 and above
        }
        if (system == SYSTEM_CELESTIAL_DUSTING)
        {
            if (rank <= 1) return 4;
            if (rank <= 2) return 4;
            if (rank <= 3) return 4;
            if (rank <= 4) return 4;
            if (rank <= 5) return 4;
            if (rank <= 6) return 4;
            if (rank <= 7) return 4;
            return 4; // rank 8 and above
        }
        if (system == SYSTEM_CELESTIAL_VOULGE)
        {
            return 1; // rank 1 and above
        }
        if (system == SYSTEM_CHAOS_RUNE)
        {
            if (rank <= 1) return 9;
            if (rank <= 2) return 9;
            if (rank <= 3) return 9;
            if (rank <= 4) return 9;
            if (rank <= 5) return 9;
            if (rank <= 6) return 9;
            if (rank <= 7) return 9;
            return 9; // rank 8 and above
        }
        if (system == SYSTEM_CLOCK_LANCET)
        {
            if (rank <= 1) return 0;
            if (rank <= 2) return 0;
            if (rank <= 3) return 0;
            if (rank <= 4) return 0;
            if (rank <= 5) return 0;
            if (rank <= 6) return 0;
            return 0; // rank 7 and above
        }
        if (system == SYSTEM_CRIMSON_SHROUD)
        {
            return 4; // rank 1 and above
        }
        if (system == SYSTEM_FLAMES_OF_MISSPELL)
        {
            if (rank <= 1) return 1;
            if (rank <= 2) return 1;
            if (rank <= 3) return 1;
            if (rank <= 4) return 1;
            if (rank <= 5) return 1;
            if (rank <= 6) return 1;
            if (rank <= 7) return 1;
            return 1; // rank 8 and above
        }
        if (system == SYSTEM_GATTI_AMARI)
        {
            if (rank <= 1) return 10;
            if (rank <= 2) return 10;
            if (rank <= 3) return 10;
            if (rank <= 4) return 10;
            if (rank <= 5) return 10;
            if (rank <= 6) return 10;
            if (rank <= 7) return 10;
            return 10; // rank 8 and above
        }
        if (system == SYSTEM_GAZE_OF_GAEA)
        {
            if (rank <= 1) return 7;
            if (rank <= 2) return 7;
            if (rank <= 3) return 7;
            if (rank <= 4) return 7;
            if (rank <= 5) return 7;
            if (rank <= 6) return 7;
            if (rank <= 7) return 7;
            return 7; // rank 8 and above
        }
        if (system == SYSTEM_GLASS_FANDANGO)
        {
            if (rank <= 1) return 1;
            if (rank <= 2) return 1;
            if (rank <= 3) return 1;
            if (rank <= 4) return 1;
            if (rank <= 5) return 1;
            if (rank <= 6) return 1;
            if (rank <= 7) return 1;
            return 1; // rank 8 and above
        }
        if (system == SYSTEM_GREATEST_JUBILEE)
        {
            if (rank <= 1) return 7;
            if (rank <= 2) return 7;
            if (rank <= 3) return 7;
            if (rank <= 4) return 7;
            if (rank <= 5) return 7;
            if (rank <= 6) return 7;
            if (rank <= 7) return 7;
            if (rank <= 8) return 7;
            return 7; // rank 9 and above
        }
        if (system == SYSTEM_GUNASTROPHE)
        {
            return 7; // rank 1 and above
        }
        if (system == SYSTEM_INFINITE_CORRIDOR)
        {
            return 0; // rank 1 and above
        }
        if (system == SYSTEM_KYRA_STONES)
        {
            return 4; // rank 1 and above
        }
        if (system == SYSTEM_LA_ROBBA)
        {
            if (rank <= 1) return 10;
            if (rank <= 2) return 10;
            if (rank <= 3) return 10;
            if (rank <= 4) return 10;
            if (rank <= 5) return 10;
            if (rank <= 6) return 10;
            if (rank <= 7) return 10;
            return 10; // rank 8 and above
        }
        if (system == SYSTEM_LAUREL)
        {
            if (rank <= 1) return 0;
            if (rank <= 2) return 0;
            if (rank <= 3) return 0;
            if (rank <= 4) return 0;
            if (rank <= 5) return 0;
            if (rank <= 6) return 0;
            return 0; // rank 7 and above
        }
        if (system == SYSTEM_MAGI_STONE)
        {
            if (rank <= 1) return 7;
            if (rank <= 2) return 7;
            if (rank <= 3) return 7;
            if (rank <= 4) return 6;
            if (rank <= 5) return 6;
            if (rank <= 6) return 6;
            if (rank <= 7) return 4;
            return 4; // rank 8 and above
        }
        if (system == SYSTEM_MANNAJJA)
        {
            return 4; // rank 1 and above
        }
        if (system == SYSTEM_MAZO_FAMILIAR)
        {
            return 1; // rank 1 and above
        }
        if (system == SYSTEM_MIRACLE_OF_MULTIPLICATION)
        {
            return 0; // rank 1 and above
        }
        if (system == SYSTEM_PAKO_BATTILIAR)
        {
            if (rank <= 1) return 0;
            if (rank <= 2) return 0;
            if (rank <= 3) return 0;
            if (rank <= 4) return 0;
            if (rank <= 5) return 0;
            if (rank <= 6) return 0;
            if (rank <= 7) return 0;
            return 0; // rank 8 and above
        }
        if (system == SYSTEM_PENSHIN_FATCHA)
        {
            return 0; // rank 1 and above
        }
        if (system == SYSTEM_PHAS3R)
        {
            if (rank <= 1) return 4;
            if (rank <= 2) return 4;
            if (rank <= 3) return 4;
            if (rank <= 4) return 4;
            if (rank <= 5) return 4;
            if (rank <= 6) return 4;
            if (rank <= 7) return 4;
            return 4; // rank 8 and above
        }
        if (system == SYSTEM_PHOTONSTORM)
        {
            return 2; // rank 1 and above
        }
        if (system == SYSTEM_PROFUSIONE_DAMORE)
        {
            return 0; // rank 1 and above
        }
        if (system == SYSTEM_SANTA_JAVELIN)
        {
            if (rank <= 1) return 4;
            if (rank <= 2) return 4;
            if (rank <= 3) return 4;
            if (rank <= 4) return 4;
            if (rank <= 5) return 4;
            if (rank <= 6) return 4;
            if (rank <= 7) return 4;
            return 4; // rank 8 and above
        }
        if (system == SYSTEM_SERAPHIC_CRY)
        {
            return 7; // rank 1 and above
        }
        if (system == SYSTEM_SHADOW_PINION)
        {
            if (rank <= 1) return 10;
            if (rank <= 2) return 10;
            if (rank <= 3) return 10;
            if (rank <= 4) return 10;
            if (rank <= 5) return 10;
            if (rank <= 6) return 10;
            if (rank <= 7) return 10;
            return 10; // rank 8 and above
        }
        if (system == SYSTEM_SONG_OF_MANA)
        {
            if (rank <= 1) return 2;
            if (rank <= 2) return 2;
            if (rank <= 3) return 2;
            if (rank <= 4) return 2;
            if (rank <= 5) return 2;
            if (rank <= 6) return 2;
            if (rank <= 7) return 2;
            return 2; // rank 8 and above
        }
        if (system == SYSTEM_SPIRIT_DISTURBANCE)
        {
            return 4; // rank 1 and above
        }
        if (system == SYSTEM_TONN_ODDEEO)
        {
            if (rank <= 1) return 4;
            if (rank <= 2) return 4;
            if (rank <= 3) return 4;
            if (rank <= 4) return 4;
            if (rank <= 5) return 4;
            return 4; // rank 6 and above
        }
        if (system == SYSTEM_TONN_OMOTO)
        {
            if (rank <= 1) return 4;
            if (rank <= 2) return 4;
            if (rank <= 3) return 4;
            if (rank <= 4) return 4;
            if (rank <= 5) return 4;
            return 4; // rank 6 and above
        }
        if (system == SYSTEM_TONNADO)
        {
            if (rank <= 1) return 9;
            if (rank <= 2) return 9;
            if (rank <= 3) return 9;
            if (rank <= 4) return 9;
            if (rank <= 5) return 9;
            return 9; // rank 6 and above
        }
        if (system == SYSTEM_TONNE)
        {
            if (rank <= 1) return 0;
            if (rank <= 2) return 0;
            if (rank <= 3) return 0;
            if (rank <= 4) return 0;
            if (rank <= 5) return 0;
            return 0; // rank 6 and above
        }
        if (system == SYSTEM_TONNO_SUBITO)
        {
            if (rank <= 1) return 7;
            if (rank <= 2) return 7;
            if (rank <= 3) return 7;
            if (rank <= 4) return 7;
            if (rank <= 5) return 7;
            return 7; // rank 6 and above
        }
        if (system == SYSTEM_UNEARTHLY_BOLT)
        {
            if (rank <= 1) return 4;
            if (rank <= 2) return 3;
            if (rank <= 3) return 3;
            if (rank <= 4) return 3;
            if (rank <= 5) return 2;
            if (rank <= 6) return 2;
            if (rank <= 7) return 2;
            return 2; // rank 8 and above
        }
        if (system == SYSTEM_UNSURPASSED)
        {
            if (rank <= 1) return 9;
            if (rank <= 2) return 9;
            if (rank <= 3) return 9;
            if (rank <= 4) return 9;
            if (rank <= 5) return 9;
            return 9; // rank 6 and above
        }
        if (system == SYSTEM_VALKYRIE_TURNER)
        {
            return 10; // rank 1 and above
        }
        if (system == SYSTEM_VICIOUS_HUNGER)
        {
            return 10; // rank 1 and above
        }
        if (system == SYSTEM_VICTORY_SWORD)
        {
            if (rank <= 1) return 4;
            if (rank <= 2) return 4;
            if (rank <= 3) return 4;
            if (rank <= 4) return 4;
            if (rank <= 5) return 4;
            if (rank <= 6) return 4;
            if (rank <= 7) return 4;
            if (rank <= 8) return 4;
            if (rank <= 9) return 4;
            if (rank <= 10) return 4;
            if (rank <= 11) return 4;
            return 4; // rank 12 and above
        }
        if (system == SYSTEM_YATTA_DAIKARIN)
        {
            return 10; // rank 1 and above
        }
        return 0;
    }

    // Pierce count, per rank; -1 means area-of-effect (no discrete pierce reported).
    static int Pierce(int system, int rank)
    {
        if (!ValidRank(system, rank)) return 0;
        if (system == SYSTEM_AMMO_APPALATE)
        {
            if (rank <= 1) return 1;
            if (rank <= 2) return 4;
            if (rank <= 3) return 4;
            if (rank <= 4) return 4;
            if (rank <= 5) return 7;
            if (rank <= 6) return 7;
            if (rank <= 7) return 7;
            return 7; // rank 8 and above
        }
        if (system == SYSTEM_ANIMA_OF_MORTACCIO)
        {
            return 0; // rank 1 and above
        }
        if (system == SYSTEM_ASHES_OF_MUSPELL)
        {
            return -1; // rank 1 and above
        }
        if (system == SYSTEM_CARROZZA)
        {
            return 0; // rank 1 and above
        }
        if (system == SYSTEM_CELESTIAL_DUSTING)
        {
            if (rank <= 1) return -1;
            if (rank <= 2) return -1;
            if (rank <= 3) return -1;
            if (rank <= 4) return -1;
            if (rank <= 5) return -1;
            if (rank <= 6) return -1;
            if (rank <= 7) return -1;
            return -1; // rank 8 and above
        }
        if (system == SYSTEM_CELESTIAL_VOULGE)
        {
            return 0; // rank 1 and above
        }
        if (system == SYSTEM_CHAOS_RUNE)
        {
            if (rank <= 1) return 1;
            if (rank <= 2) return 1;
            if (rank <= 3) return 2;
            if (rank <= 4) return 2;
            if (rank <= 5) return 2;
            if (rank <= 6) return 2;
            if (rank <= 7) return 3;
            return 3; // rank 8 and above
        }
        if (system == SYSTEM_CLOCK_LANCET)
        {
            if (rank <= 1) return -1;
            if (rank <= 2) return -1;
            if (rank <= 3) return -1;
            if (rank <= 4) return -1;
            if (rank <= 5) return -1;
            if (rank <= 6) return -1;
            return -1; // rank 7 and above
        }
        if (system == SYSTEM_CRIMSON_SHROUD)
        {
            return 0; // rank 1 and above
        }
        if (system == SYSTEM_FLAMES_OF_MISSPELL)
        {
            if (rank <= 1) return -1;
            if (rank <= 2) return -1;
            if (rank <= 3) return -1;
            if (rank <= 4) return -1;
            if (rank <= 5) return -1;
            if (rank <= 6) return -1;
            if (rank <= 7) return -1;
            return -1; // rank 8 and above
        }
        if (system == SYSTEM_GATTI_AMARI)
        {
            if (rank <= 1) return -1;
            if (rank <= 2) return -1;
            if (rank <= 3) return -1;
            if (rank <= 4) return -1;
            if (rank <= 5) return -1;
            if (rank <= 6) return -1;
            if (rank <= 7) return -1;
            return -1; // rank 8 and above
        }
        if (system == SYSTEM_GAZE_OF_GAEA)
        {
            if (rank <= 1) return -1;
            if (rank <= 2) return -1;
            if (rank <= 3) return -1;
            if (rank <= 4) return -1;
            if (rank <= 5) return -1;
            if (rank <= 6) return -1;
            if (rank <= 7) return -1;
            return -1; // rank 8 and above
        }
        if (system == SYSTEM_GLASS_FANDANGO)
        {
            if (rank <= 1) return -1;
            if (rank <= 2) return -1;
            if (rank <= 3) return -1;
            if (rank <= 4) return -1;
            if (rank <= 5) return -1;
            if (rank <= 6) return -1;
            if (rank <= 7) return -1;
            return -1; // rank 8 and above
        }
        if (system == SYSTEM_GREATEST_JUBILEE)
        {
            if (rank <= 1) return -1;
            if (rank <= 2) return -1;
            if (rank <= 3) return -1;
            if (rank <= 4) return -1;
            if (rank <= 5) return -1;
            if (rank <= 6) return -1;
            if (rank <= 7) return -1;
            if (rank <= 8) return -1;
            return -1; // rank 9 and above
        }
        if (system == SYSTEM_GUNASTROPHE)
        {
            return -1; // rank 1 and above
        }
        if (system == SYSTEM_INFINITE_CORRIDOR)
        {
            return -1; // rank 1 and above
        }
        if (system == SYSTEM_KYRA_STONES)
        {
            return 0; // rank 1 and above
        }
        if (system == SYSTEM_LA_ROBBA)
        {
            if (rank <= 1) return -1;
            if (rank <= 2) return -1;
            if (rank <= 3) return -1;
            if (rank <= 4) return -1;
            if (rank <= 5) return -1;
            if (rank <= 6) return -1;
            if (rank <= 7) return -1;
            return -1; // rank 8 and above
        }
        if (system == SYSTEM_LAUREL)
        {
            if (rank <= 1) return -1;
            if (rank <= 2) return -1;
            if (rank <= 3) return -1;
            if (rank <= 4) return -1;
            if (rank <= 5) return -1;
            if (rank <= 6) return -1;
            return -1; // rank 7 and above
        }
        if (system == SYSTEM_MAGI_STONE)
        {
            if (rank <= 1) return -1;
            if (rank <= 2) return -1;
            if (rank <= 3) return -1;
            if (rank <= 4) return -1;
            if (rank <= 5) return -1;
            if (rank <= 6) return -1;
            if (rank <= 7) return -1;
            return -1; // rank 8 and above
        }
        if (system == SYSTEM_MANNAJJA)
        {
            return -1; // rank 1 and above
        }
        if (system == SYSTEM_MAZO_FAMILIAR)
        {
            return 10; // rank 1 and above
        }
        if (system == SYSTEM_MIRACLE_OF_MULTIPLICATION)
        {
            return 0; // rank 1 and above
        }
        if (system == SYSTEM_PAKO_BATTILIAR)
        {
            if (rank <= 1) return 1;
            if (rank <= 2) return 2;
            if (rank <= 3) return 2;
            if (rank <= 4) return 2;
            if (rank <= 5) return 4;
            if (rank <= 6) return 4;
            if (rank <= 7) return 7;
            return 7; // rank 8 and above
        }
        if (system == SYSTEM_PENSHIN_FATCHA)
        {
            return 0; // rank 1 and above
        }
        if (system == SYSTEM_PHAS3R)
        {
            if (rank <= 1) return -1;
            if (rank <= 2) return -1;
            if (rank <= 3) return -1;
            if (rank <= 4) return -1;
            if (rank <= 5) return -1;
            if (rank <= 6) return -1;
            if (rank <= 7) return -1;
            return -1; // rank 8 and above
        }
        if (system == SYSTEM_PHOTONSTORM)
        {
            return 0; // rank 1 and above
        }
        if (system == SYSTEM_PROFUSIONE_DAMORE)
        {
            return 0; // rank 1 and above
        }
        if (system == SYSTEM_SANTA_JAVELIN)
        {
            if (rank <= 1) return -1;
            if (rank <= 2) return -1;
            if (rank <= 3) return -1;
            if (rank <= 4) return -1;
            if (rank <= 5) return -1;
            if (rank <= 6) return -1;
            if (rank <= 7) return -1;
            return -1; // rank 8 and above
        }
        if (system == SYSTEM_SERAPHIC_CRY)
        {
            return 0; // rank 1 and above
        }
        if (system == SYSTEM_SHADOW_PINION)
        {
            if (rank <= 1) return -1;
            if (rank <= 2) return -1;
            if (rank <= 3) return -1;
            if (rank <= 4) return -1;
            if (rank <= 5) return -1;
            if (rank <= 6) return -1;
            if (rank <= 7) return -1;
            return -1; // rank 8 and above
        }
        if (system == SYSTEM_SONG_OF_MANA)
        {
            if (rank <= 1) return -1;
            if (rank <= 2) return -1;
            if (rank <= 3) return -1;
            if (rank <= 4) return -1;
            if (rank <= 5) return -1;
            if (rank <= 6) return -1;
            if (rank <= 7) return -1;
            return -1; // rank 8 and above
        }
        if (system == SYSTEM_SPIRIT_DISTURBANCE)
        {
            return -1; // rank 1 and above
        }
        if (system == SYSTEM_TONN_ODDEEO)
        {
            if (rank <= 1) return -1;
            if (rank <= 2) return -1;
            if (rank <= 3) return -1;
            if (rank <= 4) return -1;
            if (rank <= 5) return -1;
            return -1; // rank 6 and above
        }
        if (system == SYSTEM_TONN_OMOTO)
        {
            if (rank <= 1) return -1;
            if (rank <= 2) return -1;
            if (rank <= 3) return -1;
            if (rank <= 4) return -1;
            if (rank <= 5) return -1;
            return -1; // rank 6 and above
        }
        if (system == SYSTEM_TONNADO)
        {
            if (rank <= 1) return -1;
            if (rank <= 2) return -1;
            if (rank <= 3) return -1;
            if (rank <= 4) return -1;
            if (rank <= 5) return -1;
            return -1; // rank 6 and above
        }
        if (system == SYSTEM_TONNE)
        {
            if (rank <= 1) return -1;
            if (rank <= 2) return -1;
            if (rank <= 3) return -1;
            if (rank <= 4) return -1;
            if (rank <= 5) return -1;
            return -1; // rank 6 and above
        }
        if (system == SYSTEM_TONNO_SUBITO)
        {
            if (rank <= 1) return 1;
            if (rank <= 2) return 1;
            if (rank <= 3) return 1;
            if (rank <= 4) return 1;
            if (rank <= 5) return 1;
            return 1; // rank 6 and above
        }
        if (system == SYSTEM_UNEARTHLY_BOLT)
        {
            if (rank <= 1) return -1;
            if (rank <= 2) return -1;
            if (rank <= 3) return -1;
            if (rank <= 4) return -1;
            if (rank <= 5) return -1;
            if (rank <= 6) return -1;
            if (rank <= 7) return -1;
            return -1; // rank 8 and above
        }
        if (system == SYSTEM_UNSURPASSED)
        {
            if (rank <= 1) return -1;
            if (rank <= 2) return -1;
            if (rank <= 3) return -1;
            if (rank <= 4) return -1;
            if (rank <= 5) return -1;
            return -1; // rank 6 and above
        }
        if (system == SYSTEM_VALKYRIE_TURNER)
        {
            return -1; // rank 1 and above
        }
        if (system == SYSTEM_VICIOUS_HUNGER)
        {
            return -1; // rank 1 and above
        }
        if (system == SYSTEM_VICTORY_SWORD)
        {
            if (rank <= 1) return -1;
            if (rank <= 2) return -1;
            if (rank <= 3) return -1;
            if (rank <= 4) return -1;
            if (rank <= 5) return -1;
            if (rank <= 6) return -1;
            if (rank <= 7) return -1;
            if (rank <= 8) return -1;
            if (rank <= 9) return -1;
            if (rank <= 10) return -1;
            if (rank <= 11) return -1;
            return -1; // rank 12 and above
        }
        if (system == SYSTEM_YATTA_DAIKARIN)
        {
            return 0; // rank 1 and above
        }
        return 0;
    }

    // Existing-archetype name or Track-B mechanic key this system maps onto,
    // per docs/contracts/remaining-weapons.md Track A/B split. Not itself an
    // engine dispatch -- callers still need N2EngineForSystem-style wiring,
    // which is deliberately out of this data task's scope.
    static String EngineFor(int system)
    {
        if (system == SYSTEM_AMMO_APPALATE) return "aimed-directional";
        if (system == SYSTEM_ANIMA_OF_MORTACCIO) return "bounce-projectiles";
        if (system == SYSTEM_ARMA_DIO) return "inventory-draft";
        if (system == SYSTEM_ASHES_OF_MUSPELL) return "aimed-directional";
        if (system == SYSTEM_CANDYBOX) return "levelup-draft";
        if (system == SYSTEM_CARROZZA) return "bounce-projectiles";
        if (system == SYSTEM_CELESTIAL_DUSTING) return "bounce-projectiles";
        if (system == SYSTEM_CELESTIAL_VOULGE) return "aimed-directional";
        if (system == SYSTEM_CHAOS_RUNE) return "ground-fields";
        if (system == SYSTEM_CLOCK_LANCET) return "status-only-broadcast";
        if (system == SYSTEM_CRIMSON_SHROUD) return "player-shield";
        if (system == SYSTEM_EMBRACE_OF_GAEA) return "ground-fields";
        if (system == SYSTEM_FLAMES_OF_MISSPELL) return "ground-fields";
        if (system == SYSTEM_GATTI_AMARI) return "wandering-companion";
        if (system == SYSTEM_GAZE_OF_GAEA) return "ground-fields";
        if (system == SYSTEM_GLASS_FANDANGO) return "aimed-directional";
        if (system == SYSTEM_GREATEST_JUBILEE) return "spawned-secondary-entity";
        if (system == SYSTEM_GUNASTROPHE) return "aimed-directional";
        if (system == SYSTEM_INFINITE_CORRIDOR) return "status-only-broadcast";
        if (system == SYSTEM_KYRA_STONES) return "aimed-directional";
        if (system == SYSTEM_LA_ROBBA) return "bounce-projectiles";
        if (system == SYSTEM_LAUREL) return "player-shield";
        if (system == SYSTEM_MAGI_STONE) return "ballistic-projectiles";
        if (system == SYSTEM_MANNAJJA) return "ballistic-projectiles";
        if (system == SYSTEM_MAZO_FAMILIAR) return "damage-retaliation-trigger";
        if (system == SYSTEM_MIRACLE_OF_MULTIPLICATION) return "selector-chain";
        if (system == SYSTEM_PAKO_BATTILIAR) return "damage-retaliation-trigger";
        if (system == SYSTEM_PENSHIN_FATCHA) return "selector-chain";
        if (system == SYSTEM_PHAS3R) return "ground-fields";
        if (system == SYSTEM_PHOTONSTORM) return "ground-fields";
        if (system == SYSTEM_PROFUSIONE_DAMORE) return "bounce-projectiles";
        if (system == SYSTEM_SANTA_JAVELIN) return "aimed-directional";
        if (system == SYSTEM_SERAPHIC_CRY) return "aimed-directional";
        if (system == SYSTEM_SHADOW_PINION) return "ground-fields";
        if (system == SYSTEM_SONG_OF_MANA) return "ballistic-projectiles";
        if (system == SYSTEM_SPIRIT_DISTURBANCE) return "cross-weapon-crit-broadcast";
        if (system == SYSTEM_TONN_ODDEEO) return "selector-chain";
        if (system == SYSTEM_TONN_OMOTO) return "selector-chain";
        if (system == SYSTEM_TONNADO) return "selector-chain";
        if (system == SYSTEM_TONNE) return "selector-chain";
        if (system == SYSTEM_TONNO_SUBITO) return "selector-chain";
        if (system == SYSTEM_UNEARTHLY_BOLT) return "cross-weapon-crit-broadcast";
        if (system == SYSTEM_UNSURPASSED) return "selector-chain";
        if (system == SYSTEM_VALKYRIE_TURNER) return "ground-fields";
        if (system == SYSTEM_VICIOUS_HUNGER) return "wandering-companion";
        if (system == SYSTEM_VICTORY_SWORD) return "aimed-directional";
        if (system == SYSTEM_WICKED_RULER) return "ground-fields";
        if (system == SYSTEM_YATTA_DAIKARIN) return "bounce-projectiles";
        return "UNKNOWN";
    }

    // True for systems whose engine_mapping.kind is DRAFT_MECHANIC_NOT_ATTACK
    // (Candybox, Arma Dio): these are draft-authority choosers, not attacks.
    static bool IsDraftMechanic(int system)
    {
        return system == SYSTEM_ARMA_DIO || system == SYSTEM_CANDYBOX;
    }
}
