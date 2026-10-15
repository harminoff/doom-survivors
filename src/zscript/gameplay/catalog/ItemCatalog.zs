// N2 normal-play integration catalog (docs/contracts/normal-play-integration.md).
//
// One static id -> {category, max rank, engine/system, rarity weight,
// draftable-by-Antonio, display name} map covering every weapon and passive
// implemented through P026-P042, plus the six new pending-stat-effect
// passives required to reach the P032 evolutions/unions. This file is the
// single source of truth the generalized DraftFull.zs full-catalog path
// reads from; it does not itself change draft/inventory behavior.
//
// Weapon item ids intentionally reuse the DSP033StatRules SYSTEM_* values
// (per the frozen contract) so System(id) == id for every weapon row.
// Rarity: none of the data/verified/base/weapons/**/*.json infobox records
// carry a "rarity" field as of 2026-09-28, so every row uses the labelled
// flat-100 fallback the contract specifies (ENGINEERING_APPROXIMATION).
// Passives Attractorb/Candelabrador/Clover/Bracer/Spellbinder/Tirajisu have
// no data/verified/base/passives/*.json source file yet; their catalog rows
// exist only as rank carriers labelled STAT_EFFECT_PENDING_N8 and their max
// ranks are an explicit ENGINEERING_APPROXIMATION pending N8 verification.
class DSN2Catalog
{
    const CATEGORY_WEAPON = 1;
    const CATEGORY_PASSIVE = 2;

    // Draftable base weapons (System ids double as item ids).
    const ID_WHIP = 1;               // SYSTEM_WHIP
    const ID_MAGIC_WAND = 34;        // SYSTEM_MAGIC_WAND
    const ID_KNIFE = 36;             // SYSTEM_KNIFE
    const ID_AXE = 38;               // SYSTEM_AXE
    const ID_FIRE_WAND = 40;         // SYSTEM_FIRE_WAND
    const ID_CROSS = 42;             // SYSTEM_CROSS
    const ID_KING_BIBLE = 44;        // SYSTEM_KING_BIBLE
    const ID_SANTA_WATER = 46;       // SYSTEM_HOLY_WATER
    const ID_GARLIC = 48;            // SYSTEM_GARLIC
    const ID_LIGHTNING_RING = 50;    // SYSTEM_LIGHTNING
    const ID_PENTAGRAM = 52;         // SYSTEM_PENTAGRAM
    const ID_RUNETRACER = 54;        // SYSTEM_RUNETRACER
    const ID_PEACHONE = 59;          // SYSTEM_PEACHONE
    const ID_EBONY_WINGS = 60;       // SYSTEM_EBONY
    const ID_PHIERA = 62;            // SYSTEM_PHIERA
    const ID_EIGHT = 63;             // SYSTEM_EIGHT
    const ID_VENTO_SACRO = 65;       // SYSTEM_VENTO
    const ID_BRACELET = 67;          // SYSTEM_BRACELET

    // Non-draftable evolved/union weapon forms and character-exclusive base
    // weapons (Bone/Cherry/Carrello); N4 owns making those draftable.
    const ID_BLOODY_TEAR = 6;
    const ID_HOLY_WAND = 35;
    const ID_THOUSAND_EDGE = 37;
    const ID_DEATH_SPIRAL = 39;
    const ID_HELLFIRE = 41;
    const ID_HEAVEN_SWORD = 43;
    const ID_UNHOLY_VESPERS = 45;
    const ID_LA_BORRA = 47;
    const ID_SOUL_EATER = 49;
    const ID_THUNDER_LOOP = 51;
    const ID_GORGEOUS_MOON = 53;
    const ID_NO_FUTURE = 55;
    const ID_BONE = 56;
    const ID_CHERRY_BOMB = 57;
    const ID_CARRELLO = 58;
    const ID_VANDALIER = 61;
    const ID_PHIERAGGI = 64;
    const ID_FUWALAFUWALOO = 66;
    const ID_BI_BRACELET = 68;
    const ID_TRI_BRACELET = 69;

    // Passives. The first seven ids are pre-existing (P033/P039/P040); the
    // remaining six are new N2 ids added to reach the P032 recipes. Tirajisu
    // must equal DSP032_ID_TIRAJISU (TransformationGraph.zs) = 70.
    const ID_SPINACH = 2;
    const ID_ARMOR = 3;
    const ID_HOLLOW_HEART = 5;
    const ID_EMPTY_TOME = 7;
    const ID_PUMMAROLA = 8;
    const ID_DUPLICATOR = 9;
    const ID_CROWN = 10;
    const ID_TIRAJISU = 70;
    const ID_ATTRACTORB = 71;
    const ID_CANDELABRADOR = 72;
    const ID_CLOVER = 73;
    const ID_BRACER = 74;
    const ID_SPELLBINDER = 75;

    // N3 remaining base-game identities (docs/contracts/remaining-weapons.md).
    // Weapon ids equal DSN3Rows.SYSTEM_* verbatim; draftable_by_antonio follows
    // each identity's source kind (base/base_and_selector draftable; evolutions
    // and the 6 Penshin Fatcha selector forms are special-acquisition only).
    const ID_N3_AMMO_APPALATE = 96;
    const ID_N3_ANIMA_OF_MORTACCIO = 123;
    const ID_N3_ARMA_DIO = 122;
    const ID_N3_ASHES_OF_MUSPELL = 93;
    const ID_N3_CANDYBOX = 90;
    const ID_N3_CARROZZA = 125;
    const ID_N3_CELESTIAL_DUSTING = 86;
    const ID_N3_CELESTIAL_VOULGE = 103;
    const ID_N3_CHAOS_RUNE = 120;
    const ID_N3_CLOCK_LANCET = 82;
    const ID_N3_CRIMSON_SHROUD = 85;
    const ID_N3_EMBRACE_OF_GAEA = 115;
    const ID_N3_FLAMES_OF_MISSPELL = 92;
    const ID_N3_GATTI_AMARI = 76;
    const ID_N3_GAZE_OF_GAEA = 114;
    const ID_N3_GLASS_FANDANGO = 102;
    const ID_N3_GREATEST_JUBILEE = 89;
    const ID_N3_GUNASTROPHE = 97;
    const ID_N3_INFINITE_CORRIDOR = 83;
    const ID_N3_KYRA_STONES = 117;
    const ID_N3_LA_ROBBA = 88;
    const ID_N3_LAUREL = 84;
    const ID_N3_MAGI_STONE = 116;
    const ID_N3_MANNAJJA = 79;
    const ID_N3_MAZO_FAMILIAR = 95;
    const ID_N3_MIRACLE_OF_MULTIPLICATION = 111;
    const ID_N3_PAKO_BATTILIAR = 94;
    const ID_N3_PENSHIN_FATCHA = 104;
    const ID_N3_PHAS3R = 118;
    const ID_N3_PHOTONSTORM = 119;
    const ID_N3_PROFUSIONE_DAMORE = 87;
    const ID_N3_SANTA_JAVELIN = 112;
    const ID_N3_SERAPHIC_CRY = 113;
    const ID_N3_SHADOW_PINION = 80;
    const ID_N3_SONG_OF_MANA = 78;
    const ID_N3_SPIRIT_DISTURBANCE = 99;
    const ID_N3_TONN_ODDEEO = 108;
    const ID_N3_TONN_OMOTO = 107;
    const ID_N3_TONNADO = 106;
    const ID_N3_TONNE = 109;
    const ID_N3_TONNO_SUBITO = 105;
    const ID_N3_UNEARTHLY_BOLT = 98;
    const ID_N3_UNSURPASSED = 110;
    const ID_N3_VALKYRIE_TURNER = 81;
    const ID_N3_VICIOUS_HUNGER = 77;
    const ID_N3_VICTORY_SWORD = 91;
    const ID_N3_WICKED_RULER = 121;
    const ID_N3_YATTA_DAIKARIN = 124;
    const ID_N3_STONE_MASK = 126;
    const ID_N3_SKULL_O_MANIAC = 127;
    const ID_N3_WINGS = 128;
    const ID_N3_SILVER_RING = 129;
    const ID_N3_METAGLIO_LEFT = 130;
    const ID_N3_METAGLIO_RIGHT = 131;
    const ID_N3_CHAOS_ALTEMANNA = 132;
    const ID_N3_TORRONA_S_BOX = 133;
    const ID_N3_PARM_AEGIS = 134;
    const ID_N3_KAROMA_S_MANA = 135;
    const ID_N3_CHAOS_MALACHITE = 136;
    const ID_N3_CHAOS_ROSALIA = 137;
    const ID_N3_CHAOS_LAZULIA = 138;

    const FLAT_RARITY_WEIGHT = 100;

    static void AllIds(out Array<int> ids)
    {
        ids.Clear();
        ids.Push(ID_WHIP); ids.Push(ID_MAGIC_WAND); ids.Push(ID_KNIFE);
        ids.Push(ID_AXE); ids.Push(ID_FIRE_WAND); ids.Push(ID_CROSS);
        ids.Push(ID_KING_BIBLE); ids.Push(ID_SANTA_WATER); ids.Push(ID_GARLIC);
        ids.Push(ID_LIGHTNING_RING); ids.Push(ID_PENTAGRAM); ids.Push(ID_RUNETRACER);
        ids.Push(ID_PEACHONE); ids.Push(ID_EBONY_WINGS); ids.Push(ID_PHIERA);
        ids.Push(ID_EIGHT); ids.Push(ID_VENTO_SACRO); ids.Push(ID_BRACELET);
        ids.Push(ID_BLOODY_TEAR); ids.Push(ID_HOLY_WAND); ids.Push(ID_THOUSAND_EDGE);
        ids.Push(ID_DEATH_SPIRAL); ids.Push(ID_HELLFIRE); ids.Push(ID_HEAVEN_SWORD);
        ids.Push(ID_UNHOLY_VESPERS); ids.Push(ID_LA_BORRA); ids.Push(ID_SOUL_EATER);
        ids.Push(ID_THUNDER_LOOP); ids.Push(ID_GORGEOUS_MOON); ids.Push(ID_NO_FUTURE);
        ids.Push(ID_BONE); ids.Push(ID_CHERRY_BOMB); ids.Push(ID_CARRELLO);
        ids.Push(ID_VANDALIER); ids.Push(ID_PHIERAGGI); ids.Push(ID_FUWALAFUWALOO);
        ids.Push(ID_BI_BRACELET); ids.Push(ID_TRI_BRACELET);
        ids.Push(ID_SPINACH); ids.Push(ID_ARMOR); ids.Push(ID_HOLLOW_HEART);
        ids.Push(ID_EMPTY_TOME); ids.Push(ID_PUMMAROLA); ids.Push(ID_DUPLICATOR);
        ids.Push(ID_CROWN); ids.Push(ID_TIRAJISU); ids.Push(ID_ATTRACTORB);
        ids.Push(ID_CANDELABRADOR); ids.Push(ID_CLOVER); ids.Push(ID_BRACER);
        ids.Push(ID_SPELLBINDER);
        ids.Push(ID_N3_AMMO_APPALATE); ids.Push(ID_N3_ANIMA_OF_MORTACCIO); ids.Push(ID_N3_ARMA_DIO);
        ids.Push(ID_N3_ASHES_OF_MUSPELL); ids.Push(ID_N3_CANDYBOX); ids.Push(ID_N3_CARROZZA);
        ids.Push(ID_N3_CELESTIAL_DUSTING); ids.Push(ID_N3_CELESTIAL_VOULGE); ids.Push(ID_N3_CHAOS_RUNE);
        ids.Push(ID_N3_CLOCK_LANCET); ids.Push(ID_N3_CRIMSON_SHROUD); ids.Push(ID_N3_EMBRACE_OF_GAEA);
        ids.Push(ID_N3_FLAMES_OF_MISSPELL); ids.Push(ID_N3_GATTI_AMARI); ids.Push(ID_N3_GAZE_OF_GAEA);
        ids.Push(ID_N3_GLASS_FANDANGO); ids.Push(ID_N3_GREATEST_JUBILEE); ids.Push(ID_N3_GUNASTROPHE);
        ids.Push(ID_N3_INFINITE_CORRIDOR); ids.Push(ID_N3_KYRA_STONES); ids.Push(ID_N3_LA_ROBBA);
        ids.Push(ID_N3_LAUREL); ids.Push(ID_N3_MAGI_STONE); ids.Push(ID_N3_MANNAJJA);
        ids.Push(ID_N3_MAZO_FAMILIAR); ids.Push(ID_N3_MIRACLE_OF_MULTIPLICATION); ids.Push(ID_N3_PAKO_BATTILIAR);
        ids.Push(ID_N3_PENSHIN_FATCHA); ids.Push(ID_N3_PHAS3R); ids.Push(ID_N3_PHOTONSTORM);
        ids.Push(ID_N3_PROFUSIONE_DAMORE); ids.Push(ID_N3_SANTA_JAVELIN); ids.Push(ID_N3_SERAPHIC_CRY);
        ids.Push(ID_N3_SHADOW_PINION); ids.Push(ID_N3_SONG_OF_MANA); ids.Push(ID_N3_SPIRIT_DISTURBANCE);
        ids.Push(ID_N3_TONN_ODDEEO); ids.Push(ID_N3_TONN_OMOTO); ids.Push(ID_N3_TONNADO);
        ids.Push(ID_N3_TONNE); ids.Push(ID_N3_TONNO_SUBITO); ids.Push(ID_N3_UNEARTHLY_BOLT);
        ids.Push(ID_N3_UNSURPASSED); ids.Push(ID_N3_VALKYRIE_TURNER); ids.Push(ID_N3_VICIOUS_HUNGER);
        ids.Push(ID_N3_VICTORY_SWORD); ids.Push(ID_N3_WICKED_RULER); ids.Push(ID_N3_YATTA_DAIKARIN);
        ids.Push(ID_N3_STONE_MASK); ids.Push(ID_N3_SKULL_O_MANIAC); ids.Push(ID_N3_WINGS);
        ids.Push(ID_N3_SILVER_RING); ids.Push(ID_N3_METAGLIO_LEFT); ids.Push(ID_N3_METAGLIO_RIGHT);
        ids.Push(ID_N3_CHAOS_ALTEMANNA); ids.Push(ID_N3_TORRONA_S_BOX); ids.Push(ID_N3_PARM_AEGIS);
        ids.Push(ID_N3_KAROMA_S_MANA); ids.Push(ID_N3_CHAOS_MALACHITE); ids.Push(ID_N3_CHAOS_ROSALIA);
        ids.Push(ID_N3_CHAOS_LAZULIA);
    }

    static void DraftableIds(out Array<int> ids)
    {
        ids.Clear();
        ids.Push(ID_WHIP); ids.Push(ID_MAGIC_WAND); ids.Push(ID_KNIFE);
        ids.Push(ID_AXE); ids.Push(ID_FIRE_WAND); ids.Push(ID_CROSS);
        ids.Push(ID_KING_BIBLE); ids.Push(ID_SANTA_WATER); ids.Push(ID_GARLIC);
        ids.Push(ID_LIGHTNING_RING); ids.Push(ID_PENTAGRAM); ids.Push(ID_RUNETRACER);
        ids.Push(ID_PEACHONE); ids.Push(ID_EBONY_WINGS); ids.Push(ID_PHIERA);
        ids.Push(ID_EIGHT); ids.Push(ID_VENTO_SACRO); ids.Push(ID_BRACELET);
        // Bone, Cherry Bomb and Carréllo are exclusive to Mortaccio, Cavallo
        // and Ramba, so they stay out of the shared draft; they (and their
        // evolutions) arrive with those characters (docs/TODO.md step 4).
        ids.Push(ID_SPINACH); ids.Push(ID_ARMOR); ids.Push(ID_HOLLOW_HEART);
        ids.Push(ID_EMPTY_TOME); ids.Push(ID_PUMMAROLA); ids.Push(ID_DUPLICATOR);
        ids.Push(ID_CROWN); ids.Push(ID_TIRAJISU); ids.Push(ID_ATTRACTORB);
        ids.Push(ID_CANDELABRADOR); ids.Push(ID_CLOVER); ids.Push(ID_BRACER);
        ids.Push(ID_SPELLBINDER);
        // Stat passives applied by the run stats (TODO step 4).
        ids.Push(ID_N3_WINGS); ids.Push(ID_N3_STONE_MASK); ids.Push(ID_N3_SKULL_O_MANIAC);
        ids.Push(ID_N3_SILVER_RING); ids.Push(ID_N3_METAGLIO_LEFT); ids.Push(ID_N3_METAGLIO_RIGHT);
        ids.Push(ID_N3_TORRONA_S_BOX); ids.Push(ID_N3_PARM_AEGIS); ids.Push(ID_N3_KAROMA_S_MANA);
        ids.Push(ID_N3_AMMO_APPALATE); ids.Push(ID_N3_ARMA_DIO); ids.Push(ID_N3_CANDYBOX);
        ids.Push(ID_N3_CELESTIAL_DUSTING); ids.Push(ID_N3_CHAOS_RUNE); ids.Push(ID_N3_CLOCK_LANCET);
        ids.Push(ID_N3_FLAMES_OF_MISSPELL); ids.Push(ID_N3_GATTI_AMARI); ids.Push(ID_N3_GAZE_OF_GAEA);
        ids.Push(ID_N3_GLASS_FANDANGO); ids.Push(ID_N3_GREATEST_JUBILEE); ids.Push(ID_N3_LA_ROBBA);
        ids.Push(ID_N3_LAUREL); ids.Push(ID_N3_MAGI_STONE); ids.Push(ID_N3_PAKO_BATTILIAR);
        ids.Push(ID_N3_PENSHIN_FATCHA); ids.Push(ID_N3_PHAS3R); ids.Push(ID_N3_SANTA_JAVELIN);
        ids.Push(ID_N3_SHADOW_PINION); ids.Push(ID_N3_SONG_OF_MANA); ids.Push(ID_N3_UNEARTHLY_BOLT);
        ids.Push(ID_N3_VICTORY_SWORD);
        // Source-draftable N3 weapons only enter the live draft once their
        // engine is wired; otherwise a player (or the soak bot) could spend a
        // weapon slot on an item that never fires (observed 2026-09-28).
        for (int i = ids.Size() - 1; i >= 0; i--)
            if (IsN3Weapon(ids[i]) && !N3EngineWired(ids[i])) ids.Delete(i);
    }

    // N3 weapons whose engine adapter is wired through the N2 dispatcher.
    // Extend this list as each engine lands (docs/contracts/remaining-weapons.md).
    static bool N3EngineWired(int id)
    {
        // Generic engine weapons (weapons/generic/GenericWeaponDefs.zs).
        if (DSGenericWeaponDefs.Handles(id)) return true;
        // Candybox and Arma Dio are draft gifts (DraftFull.zs), not attacks.
        if (id == ID_N3_CANDYBOX || id == ID_N3_ARMA_DIO) return true;
        return id == ID_N3_MAGI_STONE || id == ID_N3_KYRA_STONES || id == ID_N3_SONG_OF_MANA
            // N3 Track A (bounce engine): Celestial Dusting/La Robba are
            // the two draftable base weapons; Anima of Mortaccio/Carrozza!/
            // Profusione D'Amore/Yatta Daikarin are evolution-only (never
            // in DraftableIds to begin with) but are listed here too for
            // completeness.
            || id == ID_N3_CELESTIAL_DUSTING || id == ID_N3_LA_ROBBA
            || id == ID_N3_ANIMA_OF_MORTACCIO || id == ID_N3_CARROZZA
            || id == ID_N3_PROFUSIONE_DAMORE || id == ID_N3_YATTA_DAIKARIN;
    }

    static bool IsN3Weapon(int id)
    {
        return (id >= 76 && id <= 99) || (id >= 102 && id <= 125);
    }

    static bool IsKnown(int id)
    {
        Array<int> ids;
        AllIds(ids);
        for (int i = 0; i < ids.Size(); i++) if (ids[i] == id) return true;
        return false;
    }

    static bool IsDraftableByAntonio(int id)
    {
        Array<int> ids;
        DraftableIds(ids);
        for (int i = 0; i < ids.Size(); i++) if (ids[i] == id) return true;
        return false;
    }

    // The 13 N3 passives (docs/contracts/remaining-weapons.md); ORed as its
    // own boolean so Category/IsStatEffectPendingN8 share one list.
    static bool IsN3Passive(int id)
    {
        return id == ID_N3_STONE_MASK || id == ID_N3_SKULL_O_MANIAC || id == ID_N3_WINGS
            || id == ID_N3_SILVER_RING || id == ID_N3_METAGLIO_LEFT || id == ID_N3_METAGLIO_RIGHT
            || id == ID_N3_CHAOS_ALTEMANNA || id == ID_N3_TORRONA_S_BOX || id == ID_N3_PARM_AEGIS
            || id == ID_N3_KAROMA_S_MANA || id == ID_N3_CHAOS_MALACHITE || id == ID_N3_CHAOS_ROSALIA
            || id == ID_N3_CHAOS_LAZULIA;
    }

    static int Category(int id)
    {
        if (id == ID_SPINACH || id == ID_ARMOR || id == ID_HOLLOW_HEART
            || id == ID_EMPTY_TOME || id == ID_PUMMAROLA || id == ID_DUPLICATOR
            || id == ID_CROWN || id == ID_TIRAJISU || id == ID_ATTRACTORB
            || id == ID_CANDELABRADOR || id == ID_CLOVER || id == ID_BRACER
            || id == ID_SPELLBINDER || IsN3Passive(id))
            return CATEGORY_PASSIVE;
        if (IsKnown(id)) return CATEGORY_WEAPON;
        return 0;
    }

    // Weapon item ids equal their DSP033StatRules SYSTEM_* engine key
    // (contract: "Weapon item IDs reuse the P033 SYSTEM_* values"). Returns
    // 0 for passives or unknown ids.
    static int System(int id)
    {
        return Category(id) == CATEGORY_WEAPON ? id : 0;
    }

    // Every rarity weight is the labelled flat-100 fallback: no infobox in
    // data/verified/base/weapons/**/*.json carries a "rarity" value as of
    // 2026-09-28 (confirmed by a full scan of that tree).
    static int RarityWeight(int id)
    {
        return IsKnown(id) ? FLAT_RARITY_WEIGHT : 0;
    }

    // True for the six passives with no modelled stat effect yet (N8 scope).
    // They still occupy inventory slots, still count toward evolution rank
    // requirements, and are logged as STAT_EFFECT_PENDING_N8 rather than
    // silently doing nothing.
    static bool IsStatEffectPendingN8(int id)
    {
        return id == ID_TIRAJISU || id == ID_ATTRACTORB
            || id == ID_CANDELABRADOR || id == ID_CLOVER || id == ID_BRACER
            || id == ID_SPELLBINDER || IsN3Passive(id);
    }

    // Max ranks are an explicit engineering approximation: base weapons and
    // the ordinary five-rank passives keep the pre-existing P028/P033
    // conventions (8 for weapons, 5 for passives); Duplicator keeps its
    // established 2-rank cap (DSP033StatRules.MAX_DUPLICATOR_RANK); Tirajisu
    // is a single-tier union reward; evolutions/unions other than the
    // Bracelet chain are single-tier once acquired; the Bracelet chain keeps
    // ranking through its Bi/Tri steps like the base Bracelet.
    static int MaxRank(int id)
    {
        if (id == ID_DUPLICATOR) return 2;
        if (id == ID_TIRAJISU) return 1;
        if (id == ID_SPINACH || id == ID_ARMOR || id == ID_HOLLOW_HEART
            || id == ID_EMPTY_TOME || id == ID_PUMMAROLA || id == ID_CROWN
            || id == ID_ATTRACTORB || id == ID_CANDELABRADOR || id == ID_CLOVER
            || id == ID_BRACER || id == ID_SPELLBINDER)
            return 5;
        if (id == ID_BRACELET || id == ID_BI_BRACELET || id == ID_TRI_BRACELET)
            return 8;
        // Stat passives' wiki max levels; the Chaos relics are single pickups.
        if (id == ID_N3_WINGS || id == ID_N3_STONE_MASK || id == ID_N3_SKULL_O_MANIAC
            || id == ID_N3_PARM_AEGIS || id == ID_N3_KAROMA_S_MANA) return 5;
        if (id == ID_N3_SILVER_RING || id == ID_N3_METAGLIO_LEFT || id == ID_N3_METAGLIO_RIGHT
            || id == ID_N3_TORRONA_S_BOX) return 9;
        if (IsN3Passive(id)) return 1;
        // N3 weapon max ranks mirror DSN3Rows.RankCount(system) verbatim
        // (data/verified/base/weapons/n3/*.json rank_rows length per identity).
        if (id == ID_N3_AMMO_APPALATE) return 8;
        if (id == ID_N3_ANIMA_OF_MORTACCIO) return 1;
        if (id == ID_N3_ARMA_DIO) return 1;
        if (id == ID_N3_ASHES_OF_MUSPELL) return 1;
        if (id == ID_N3_CANDYBOX) return 1;
        if (id == ID_N3_CARROZZA) return 1;
        if (id == ID_N3_CELESTIAL_DUSTING) return 8;
        if (id == ID_N3_CELESTIAL_VOULGE) return 1;
        if (id == ID_N3_CHAOS_RUNE) return 8;
        if (id == ID_N3_CLOCK_LANCET) return 7;
        if (id == ID_N3_CRIMSON_SHROUD) return 1;
        if (id == ID_N3_EMBRACE_OF_GAEA) return 1;
        if (id == ID_N3_FLAMES_OF_MISSPELL) return 8;
        if (id == ID_N3_GATTI_AMARI) return 8;
        if (id == ID_N3_GAZE_OF_GAEA) return 8;
        if (id == ID_N3_GLASS_FANDANGO) return 8;
        if (id == ID_N3_GREATEST_JUBILEE) return 9;
        if (id == ID_N3_GUNASTROPHE) return 1;
        if (id == ID_N3_INFINITE_CORRIDOR) return 1;
        if (id == ID_N3_KYRA_STONES) return 1;
        if (id == ID_N3_LA_ROBBA) return 8;
        if (id == ID_N3_LAUREL) return 7;
        if (id == ID_N3_MAGI_STONE) return 8;
        if (id == ID_N3_MANNAJJA) return 1;
        if (id == ID_N3_MAZO_FAMILIAR) return 1;
        if (id == ID_N3_MIRACLE_OF_MULTIPLICATION) return 1;
        if (id == ID_N3_PAKO_BATTILIAR) return 8;
        if (id == ID_N3_PENSHIN_FATCHA) return 7;   // 6 form picks, the last is Miracle of Multiplication
        if (id == ID_N3_PHAS3R) return 8;
        if (id == ID_N3_PHOTONSTORM) return 1;
        if (id == ID_N3_PROFUSIONE_DAMORE) return 1;
        if (id == ID_N3_SANTA_JAVELIN) return 8;
        if (id == ID_N3_SERAPHIC_CRY) return 1;
        if (id == ID_N3_SHADOW_PINION) return 8;
        if (id == ID_N3_SONG_OF_MANA) return 8;
        if (id == ID_N3_SPIRIT_DISTURBANCE) return 1;
        if (id == ID_N3_TONN_ODDEEO) return 6;
        if (id == ID_N3_TONN_OMOTO) return 6;
        if (id == ID_N3_TONNADO) return 6;
        if (id == ID_N3_TONNE) return 6;
        if (id == ID_N3_TONNO_SUBITO) return 6;
        if (id == ID_N3_UNEARTHLY_BOLT) return 8;
        if (id == ID_N3_UNSURPASSED) return 6;
        if (id == ID_N3_VALKYRIE_TURNER) return 1;
        if (id == ID_N3_VICIOUS_HUNGER) return 1;
        if (id == ID_N3_VICTORY_SWORD) return 12;
        if (id == ID_N3_WICKED_RULER) return 1;
        if (id == ID_N3_YATTA_DAIKARIN) return 1;
        if (IsDraftableByAntonio(id)) return 8; // draftable base weapons
        if (IsKnown(id)) return 1; // remaining evolutions/unions/exclusives
        return 0;
    }

    static String DisplayName(int id)
    {
        if (id == ID_WHIP) return "Whip";
        if (id == ID_MAGIC_WAND) return "Magic Wand";
        if (id == ID_KNIFE) return "Knife";
        if (id == ID_AXE) return "Axe";
        if (id == ID_FIRE_WAND) return "Fire Wand";
        if (id == ID_CROSS) return "Cross";
        if (id == ID_KING_BIBLE) return "King Bible";
        if (id == ID_SANTA_WATER) return "Santa Water";
        if (id == ID_GARLIC) return "Garlic";
        if (id == ID_LIGHTNING_RING) return "Lightning Ring";
        if (id == ID_PENTAGRAM) return "Pentagram";
        if (id == ID_RUNETRACER) return "Runetracer";
        if (id == ID_PEACHONE) return "Peachone";
        if (id == ID_EBONY_WINGS) return "Ebony Wings";
        if (id == ID_PHIERA) return "Phiera Der Tuphello";
        if (id == ID_EIGHT) return "Eight The Sparrow";
        if (id == ID_VENTO_SACRO) return "Vento Sacro";
        if (id == ID_BRACELET) return "Bracelet";
        if (id == ID_BLOODY_TEAR) return "Bloody Tear";
        if (id == ID_HOLY_WAND) return "Holy Wand";
        if (id == ID_THOUSAND_EDGE) return "Thousand Edge";
        if (id == ID_DEATH_SPIRAL) return "Death Spiral";
        if (id == ID_HELLFIRE) return "Hellfire";
        if (id == ID_HEAVEN_SWORD) return "Heaven Sword";
        if (id == ID_UNHOLY_VESPERS) return "Unholy Vespers";
        if (id == ID_LA_BORRA) return "La Borra";
        if (id == ID_SOUL_EATER) return "Soul Eater";
        if (id == ID_THUNDER_LOOP) return "Thunder Loop";
        if (id == ID_GORGEOUS_MOON) return "Gorgeous Moon";
        if (id == ID_NO_FUTURE) return "No Future";
        if (id == ID_BONE) return "Bone";
        if (id == ID_CHERRY_BOMB) return "Cherry Bomb";
        if (id == ID_CARRELLO) return "Carréllo";
        if (id == ID_VANDALIER) return "Vandalier";
        if (id == ID_PHIERAGGI) return "Phieraggi";
        if (id == ID_FUWALAFUWALOO) return "Fuwalafuwaloo";
        if (id == ID_BI_BRACELET) return "Bi-Bracelet";
        if (id == ID_TRI_BRACELET) return "Tri-Bracelet";
        if (id == ID_SPINACH) return "Spinach";
        if (id == ID_ARMOR) return "Armor";
        if (id == ID_HOLLOW_HEART) return "Hollow Heart";
        if (id == ID_EMPTY_TOME) return "Empty Tome";
        if (id == ID_PUMMAROLA) return "Pummarola";
        if (id == ID_DUPLICATOR) return "Duplicator";
        if (id == ID_CROWN) return "Crown";
        if (id == ID_TIRAJISU) return "Tirajisu";
        if (id == ID_ATTRACTORB) return "Attractorb";
        if (id == ID_CANDELABRADOR) return "Candelabrador";
        if (id == ID_CLOVER) return "Clover";
        if (id == ID_BRACER) return "Bracer";
        if (id == ID_SPELLBINDER) return "Spellbinder";
        if (id == ID_N3_AMMO_APPALATE) return "Ammo Appalate";
        if (id == ID_N3_ANIMA_OF_MORTACCIO) return "Anima of Mortaccio";
        if (id == ID_N3_ARMA_DIO) return "Arma Dio";
        if (id == ID_N3_ASHES_OF_MUSPELL) return "Ashes of Muspell";
        if (id == ID_N3_CANDYBOX) return "Candybox";
        if (id == ID_N3_CARROZZA) return "Carrozza!";
        if (id == ID_N3_CELESTIAL_DUSTING) return "Celestial Dusting";
        if (id == ID_N3_CELESTIAL_VOULGE) return "Celestial Voulge";
        if (id == ID_N3_CHAOS_RUNE) return "Chaos Rune";
        if (id == ID_N3_CLOCK_LANCET) return "Clock Lancet";
        if (id == ID_N3_CRIMSON_SHROUD) return "Crimson Shroud";
        if (id == ID_N3_EMBRACE_OF_GAEA) return "Embrace of Gaea";
        if (id == ID_N3_FLAMES_OF_MISSPELL) return "Flames of Misspell";
        if (id == ID_N3_GATTI_AMARI) return "Gatti Amari";
        if (id == ID_N3_GAZE_OF_GAEA) return "Gaze of Gaea";
        if (id == ID_N3_GLASS_FANDANGO) return "Glass Fandango";
        if (id == ID_N3_GREATEST_JUBILEE) return "Greatest Jubilee";
        if (id == ID_N3_GUNASTROPHE) return "Gunastrophe";
        if (id == ID_N3_INFINITE_CORRIDOR) return "Infinite Corridor";
        if (id == ID_N3_KYRA_STONES) return "Kyra-Stones";
        if (id == ID_N3_LA_ROBBA) return "La Robba";
        if (id == ID_N3_LAUREL) return "Laurel";
        if (id == ID_N3_MAGI_STONE) return "Magi-Stone";
        if (id == ID_N3_MANNAJJA) return "Mannajja";
        if (id == ID_N3_MAZO_FAMILIAR) return "Mazo Familiar";
        if (id == ID_N3_MIRACLE_OF_MULTIPLICATION) return "Miracle of Multiplication";
        if (id == ID_N3_PAKO_BATTILIAR) return "Pako Battiliar";
        if (id == ID_N3_PENSHIN_FATCHA) return "Penshin Fatcha";
        if (id == ID_N3_PHAS3R) return "Phas3r";
        if (id == ID_N3_PHOTONSTORM) return "Photonstorm";
        if (id == ID_N3_PROFUSIONE_DAMORE) return "Profusione D'Amore";
        if (id == ID_N3_SANTA_JAVELIN) return "Santa Javelin";
        if (id == ID_N3_SERAPHIC_CRY) return "Seraphic Cry";
        if (id == ID_N3_SHADOW_PINION) return "Shadow Pinion";
        if (id == ID_N3_SONG_OF_MANA) return "Song of Mana";
        if (id == ID_N3_SPIRIT_DISTURBANCE) return "Spirit Disturbance";
        if (id == ID_N3_TONN_ODDEEO) return "Tonn'oddeeo";
        if (id == ID_N3_TONN_OMOTO) return "Tonn'omoto";
        if (id == ID_N3_TONNADO) return "Tonnado";
        if (id == ID_N3_TONNE) return "Tonne";
        if (id == ID_N3_TONNO_SUBITO) return "Tonno Subito";
        if (id == ID_N3_UNEARTHLY_BOLT) return "Unearthly Bolt";
        if (id == ID_N3_UNSURPASSED) return "Unsurpassed";
        if (id == ID_N3_VALKYRIE_TURNER) return "Valkyrie Turner";
        if (id == ID_N3_VICIOUS_HUNGER) return "Vicious Hunger";
        if (id == ID_N3_VICTORY_SWORD) return "Victory Sword";
        if (id == ID_N3_WICKED_RULER) return "Wicked Ruler";
        if (id == ID_N3_YATTA_DAIKARIN) return "Yatta Daikarin";
        if (id == ID_N3_STONE_MASK) return "Stone Mask";
        if (id == ID_N3_SKULL_O_MANIAC) return "Skull O'Maniac";
        if (id == ID_N3_WINGS) return "Wings";
        if (id == ID_N3_SILVER_RING) return "Silver Ring";
        if (id == ID_N3_METAGLIO_LEFT) return "Metaglio Left";
        if (id == ID_N3_METAGLIO_RIGHT) return "Metaglio Right";
        if (id == ID_N3_CHAOS_ALTEMANNA) return "Chaos Altemanna";
        if (id == ID_N3_TORRONA_S_BOX) return "Torrona's Box";
        if (id == ID_N3_PARM_AEGIS) return "Parm Aegis";
        if (id == ID_N3_KAROMA_S_MANA) return "Karoma's Mana";
        if (id == ID_N3_CHAOS_MALACHITE) return "Chaos Malachite";
        if (id == ID_N3_CHAOS_ROSALIA) return "Chaos Rosalia";
        if (id == ID_N3_CHAOS_LAZULIA) return "Chaos Lazulia";
        return "UNKNOWN";
    }
}
