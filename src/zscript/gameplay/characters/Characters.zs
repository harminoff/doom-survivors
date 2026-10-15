// Playable characters (TODO step 4). Values are Vampire Survivors wiki
// approximations (vampire.survivors.wiki character pages, retrieved
// 2026-09-28); they are not claimed to be exact.
//
// Percent stats are milli deltas: +100 = +10%. Health is whole HP, recovery
// is milli HP per second. Only characters whose starting weapon already works
// in normal play are listed.

class DSCharacters
{
    enum ECharacter
    {
        ANTONIO, IMELDA, PASQUALINA, GENNARO, ARCA, PORTA, LAMA, POE,
        CLERICI, DOMMARIO, KROCHI, CHRISTINE, PUGNALA, POPPEA, MORTACCIO,
        YATTA, BIANCA, OSOLE, ZIASSUNTA, AMBROJOE, EXDASH, TOASTIE,
        GIOVANNA, CONCETTA, IGUANA, DIVANO,
        NUM_CHARACTERS
    }

    static const String NAMES[] = {
        "Antonio", "Imelda", "Pasqualina", "Gennaro", "Arca", "Porta",
        "Lama", "Poe", "Clerici", "Dommario", "Krochi", "Christine",
        "Pugnala", "Poppea", "Mortaccio", "Yatta Cavallo", "Bianca Ramba",
        "O'Sole", "Zi'Assunta", "Sir Ambrojoe", "Exdash", "Toastie",
        "Giovanna", "Concetta", "Iguana", "Divano"
    };

    // Short bonus text for the select screen.
    static const String BLURBS[] = {
        "+10% Might every 10 levels (max +50%)",
        "+10% Growth every 5 levels (max +30%)",
        "+10% Speed every 5 levels (max +30%)",
        "Permanent +1 Amount",
        "-5% Cooldown every 10 levels (max -15%)",
        "+30% Area. Temporary -90% Cooldown",
        "+5% Might, Move, Curse every 10 levels",
        "+25% Magnet, -30 Max Health",
        "+0.5 Recovery. Temporary +400% Area",
        "+40% Duration and Speed, -40% Move",
        "1 Revival, +1 more at level 33",
        "Starts with 1 extra level",
        "+1% Might every level",
        "+1% Duration every level",
        "+1 Amount every 20 levels (max +3)",
        "+1 Amount every 20 levels (max +3)",
        "+1 Amount every 20 levels (max +3)",
        "+1 Amount every 20 levels (max +3)",
        "+0.5% Might/Speed/Duration/Area per level",
        "Temporary +10 Amount. +1 every 20 levels",
        "At least they're lucky",
        "So much potential",
        "+1% Speed every level",
        "+1% Area every level",
        "1 extra level. +10% Growth every 5 levels",
        "1 extra level. +1 Armor every 5 levels"
    };

    static int Count() { return NUM_CHARACTERS; }
    static String Name(int c) { return c >= 0 && c < NUM_CHARACTERS ? DSCharacters.NAMES[c] : "Antonio"; }
    static String Blurb(int c) { return c >= 0 && c < NUM_CHARACTERS ? DSCharacters.BLURBS[c] : ""; }

    static int FromCVar(String value)
    {
        for (int c = 0; c < NUM_CHARACTERS; c++)
            if (DSCharacters.NAMES[c].MakeLower() == value.MakeLower()) return c;
        return ANTONIO;
    }

    // Starting weapons (catalog ids). Pugnala starts with two.
    static int StartingWeapon(int c)
    {
        switch (c)
        {
        case IMELDA: return DSN2Catalog.ID_MAGIC_WAND;
        case PASQUALINA: return DSN2Catalog.ID_RUNETRACER;
        case GENNARO: return DSN2Catalog.ID_KNIFE;
        case ARCA: return DSN2Catalog.ID_FIRE_WAND;
        case PORTA: return DSN2Catalog.ID_LIGHTNING_RING;
        case LAMA: return DSN2Catalog.ID_AXE;
        case POE: return DSN2Catalog.ID_GARLIC;
        case CLERICI: return DSN2Catalog.ID_SANTA_WATER;
        case DOMMARIO: return DSN2Catalog.ID_KING_BIBLE;
        case KROCHI: return DSN2Catalog.ID_CROSS;
        case CHRISTINE: return DSN2Catalog.ID_PENTAGRAM;
        case PUGNALA: return DSN2Catalog.ID_PHIERA;
        case POPPEA: return DSN2Catalog.ID_N3_SONG_OF_MANA;
        case MORTACCIO: return DSN2Catalog.ID_BONE;
        case YATTA: return DSN2Catalog.ID_CHERRY_BOMB;
        case BIANCA: return DSN2Catalog.ID_CARRELLO;
        case OSOLE: return DSN2Catalog.ID_N3_CELESTIAL_DUSTING;
        case ZIASSUNTA: return DSN2Catalog.ID_VENTO_SACRO;
        case AMBROJOE: return DSN2Catalog.ID_N3_LA_ROBBA;
        case EXDASH: return DSN2Catalog.ID_EBONY_WINGS;
        case TOASTIE: return DSN2Catalog.ID_PEACHONE;
        case GIOVANNA: return DSN2Catalog.ID_N3_GATTI_AMARI;
        case CONCETTA: return DSN2Catalog.ID_N3_SHADOW_PINION;
        case IGUANA: return DSN2Catalog.ID_N3_CLOCK_LANCET;
        case DIVANO: return DSN2Catalog.ID_N3_LAUREL;
        }
        return DSN2Catalog.ID_WHIP;
    }
    static int SecondWeapon(int c) { return c == PUGNALA ? DSN2Catalog.ID_EIGHT : 0; }

    static bool Playable(int c)
    {
        int w = StartingWeapon(c);
        return DSN2Catalog.IsKnown(w) && (!DSN2Catalog.IsN3Weapon(w) || DSN2Catalog.N3EngineWired(w));
    }

    static int MaxHealth(int c)
    {
        switch (c)
        {
        case ANTONIO: case GENNARO: return 120;
        case LAMA: return 110;
        case POE: return 70;
        case CLERICI: return 150;
        case CHRISTINE: return 50;
        case EXDASH: return 77;
        case TOASTIE: return 1;
        }
        return 100;
    }

    // Starting level-up charges (wiki): Divano begins with +10 Banish.
    static int StartBanish(int c) { return c == DIVANO ? 10 : 0; }

    static bool ExtraLevel(int c) { return c == CHRISTINE || c == IGUANA || c == DIVANO; }

    // Fills the character's contribution for the given player level into s.
    static void Apply(int c, int level, DSRunStatBlock s)
    {
        switch (c)
        {
        case ANTONIO:
            s.armor += 1;
            s.might += 100 * min(level / 10, 5);
            break;
        case IMELDA:
            s.growth += 100 * min(level / 5, 3);
            break;
        case PASQUALINA:
            s.speed += 100 + 100 * min(level / 5, 3);
            break;
        case GENNARO:
            s.amount += 1;
            break;
        case ARCA:
            s.might += 100;
            s.cooldown -= 50 * min(level / 10, 3);
            break;
        case PORTA:
            s.area += 300;
            s.cooldown -= max(0, 900 - 300 * (level - 1));
            break;
        case LAMA:
        {
            int extra = 50 * min(level / 10, 4);
            s.move += 100 + extra; s.might += 100 + extra; s.curse += 100 + extra;
            break;
        }
        case POE:
            s.magnet += 250;
            break;
        case CLERICI:
            s.recovery += 500;
            s.area += max(0, 4000 - 1000 * (level - 1));
            break;
        case DOMMARIO:
            s.move -= 400; s.speed += 400; s.duration += 400;
            break;
        case KROCHI:
            s.move += 300;
            s.revival += level >= 33 ? 2 : 1;
            break;
        case CHRISTINE:
            s.move += 300; s.might -= 350; s.cooldown -= 250;
            break;
        case PUGNALA:
            s.move += 200; s.might += 10 * level;
            break;
        case POPPEA:
            s.move += 200; s.duration += 10 * level;
            break;
        case MORTACCIO: case YATTA: case BIANCA: case OSOLE:
            s.amount += min(level / 20, 3);
            break;
        case ZIASSUNTA:
            s.move += 200; s.curse += 100;
            s.might += 5 * level; s.speed += 5 * level; s.duration += 5 * level; s.area += 5 * level;
            break;
        case AMBROJOE:
            s.luck += 200; s.greed += 200; s.magnet += 200;
            s.amount += max(0, 10 - 2 * (level - 1)) + min(level / 20, 3);
            break;
        case GIOVANNA:
            s.move += 200; s.speed += 10 * level;
            break;
        case CONCETTA:
            s.move += 200; s.curse += 100; s.area += 10 * level;
            break;
        case IGUANA:
            s.duration += 150; s.cooldown -= 150; s.greed -= 500;
            s.growth += 100 * min(level / 5, 5);
            break;
        case DIVANO:
            s.recovery += 1000; s.luck += 300; s.greed -= 500;
            s.armor += min(level / 5, 5);
            break;
        case EXDASH: case TOASTIE:
            s.move += c == EXDASH ? -100 : 200;
            s.might -= 100; s.speed -= 500; s.duration -= 100; s.area -= 100;
            s.cooldown += 100; s.luck += 1000;
            break;
        }
    }
}

// One set of stat contributions (character, PowerUps or passives). Percent
// stats are milli deltas (+100 = +10%).
class DSRunStatBlock
{
    int might, cooldown, area, speed, duration, move, magnet, luck, growth, greed, curse;
    int maxHealthPct;
    int recovery;
    int armor, amount, revival;
    int charm, defang, preserve;   // extra enemies per wave, % defanged, % level-up action kept
    int invulnTics;                // extra invulnerability tics after a hit
    int feverPct;                  // longer Gold Fever (percent)

    void Clear()
    {
        might = 0; cooldown = 0; area = 0; speed = 0; duration = 0; move = 0;
        magnet = 0; luck = 0; growth = 0; greed = 0; curse = 0;
        maxHealthPct = 0; recovery = 0; armor = 0; amount = 0; revival = 0;
        charm = 0; defang = 0; preserve = 0; invulnTics = 0; feverPct = 0;
    }

    void Add(DSRunStatBlock o)
    {
        might += o.might; cooldown += o.cooldown; area += o.area; speed += o.speed;
        duration += o.duration; move += o.move; magnet += o.magnet; luck += o.luck;
        growth += o.growth; greed += o.greed; curse += o.curse;
        maxHealthPct += o.maxHealthPct; recovery += o.recovery;
        armor += o.armor; amount += o.amount; revival += o.revival;
        charm += o.charm; defang += o.defang; preserve += o.preserve;
        invulnTics += o.invulnTics; feverPct += o.feverPct;
    }
}
