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
        SMITH, MARRABBIO, MINNAH, LEDA, PEPPINO, BOROS, GYORUNTON, REDDEATH, TROUSER,
        AVATAR, SIGMA, ROBBERT, ZIAPPUNTA, TROUBLER, SHEMOON, COOLIO, SANTA, GAZEBO,
        CHULAREH, SPACEDUDE, BATS, ROSE, GYORUNTIN, SECRETINO, SPACEDETTE, RANDOM,
        NUM_CHARACTERS
    }

    static const String NAMES[] = {
        "Antonio", "Imelda", "Pasqualina", "Gennaro", "Arca", "Porta",
        "Lama", "Poe", "Clerici", "Dommario", "Krochi", "Christine",
        "Pugnala", "Poppea", "Mortaccio", "Yatta Cavallo", "Bianca Ramba",
        "O'Sole", "Zi'Assunta", "Sir Ambrojoe", "Exdash", "Toastie",
        "Giovanna", "Concetta", "Iguana", "Divano",
        "Smith IV", "Marrabbio", "Minnah Mannarah", "Leda", "Peppino", "Gains Boros", "Gyorunton", "Red Death", "Trouser", "Avatar Infernas", "Queen Sigma", "Robbert", "Zi'Appunta", "Big Trouble", "She-Moon Eeta", "Coolio", "Santa Ladonna", "Gazebo", "Chula-Reh", "Space Dude", "Bats Bats", "Rose De Infernas", "Gyoruntin", "Secretino", "Space Dette", "Random"
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
        "1 extra level, 5 Rerolls, 5 Skips, +Growth",
        "1 extra level. +1 Armor every 5 levels",
        "Tiny but lucky; small gains every level",
        "Fast and strong, little greed",
        "+10% Might every 3 levels (to 21)",
        "+100% Might, 5 Armor, slow",
        "Starts with reduced Area that grows back",
        "+2% Growth every level",
        "+1% Curse every level, 2 Revivals",
        "Very fast, +20% Might",
        "+1% Greed every level, longer Gold Fever",
        "Starts with Heart of Fire; grows every level",
        "She owns everything",
        "Heals and grows when near death",
        "+20% Speed, Duration and Luck",
        "+30% Greed",
        "Freezes everything when near death",
        "+30% Move and Duration",
        "Temporary -70% Cooldown, 2 Armor",
        "+50% Move Speed",
        "+7% Move, Luck and Magnet, 7 Rerolls",
        "+40% Move Speed",
        "Fast, 2 Revivals",
        "+100 enemies; Might grows back every 12 levels",
        "+1% Curse every level, 3 Armor, fast",
        "7 Rerolls, Skips and Banishes",
        "+40% Move Speed",
        "Starts with a random weapon"
    };

    // Gold price to buy each character once unlocked (the original's).
    static const int PRICES[] = {
        0, 10, 100, 500, 500, 500, 500, 500, 500, 500, 500, 500, 1000, 1000, 500, 500, 500, 500,
        5000, 500, 777, 777, 1000, 1000, 2000, 2000, 7777, 666, 666, 666, 666, 666, 5000, 666,
        5000, 666, 0, 100, 5000, 50000, 500, 153, 666, 5000, 777, 500, 5000, 5000, 5000, 50000, 5000, 5000
    };
    static int Price(int c) { return c >= 0 && c < NUM_CHARACTERS ? DSCharacters.PRICES[c] : 0; }

    static int Count() { return NUM_CHARACTERS; }
    static String Name(int c) { return c >= 0 && c < NUM_CHARACTERS ? DSCharacters.NAMES[c] : "Antonio"; }
    static String Blurb(int c) { return c >= 0 && c < NUM_CHARACTERS ? DSCharacters.BLURBS[c] : ""; }

    static int FromCVar(String value)
    {
        String wanted = value.MakeLower();
        wanted.Replace(" ", "");
        for (int c = 0; c < NUM_CHARACTERS; c++)
        {
            String lowered = DSCharacters.NAMES[c].MakeLower();
            if (lowered == value.MakeLower()) return c;
            lowered.Replace(" ", "");   // "spacedude" also finds "Space Dude"
            if (lowered == wanted) return c;
        }
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
        case SMITH: return DSN2Catalog.ID_VANDALIER;
        case MARRABBIO: return DSN2Catalog.ID_THOUSAND_EDGE;
        case MINNAH: return DSN2Catalog.ID_BLOODY_TEAR;
        case LEDA: return DSN2Catalog.ID_HOLY_WAND;
        case PEPPINO: return DSN2Catalog.ID_SOUL_EATER;
        case BOROS: return DSN2Catalog.ID_HEAVEN_SWORD;
        case GYORUNTON: return DSN2Catalog.ID_BRACELET;
        case REDDEATH: return DSN2Catalog.ID_DEATH_SPIRAL;
        case TROUSER: return DSN2Catalog.ID_N3_CANDYBOX;
        case AVATAR: return DSN2Catalog.ID_N3_FLAMES_OF_MISSPELL;
        case SIGMA: return DSN2Catalog.ID_N3_VICTORY_SWORD;
        case ROBBERT: return DSN2Catalog.ID_N3_PAKO_BATTILIAR;
        case ZIAPPUNTA: return DSN2Catalog.ID_N3_AMMO_APPALATE;
        case TROUBLER: return DSN2Catalog.ID_N3_UNEARTHLY_BOLT;
        case SHEMOON: return DSN2Catalog.ID_N3_GLASS_FANDANGO;
        case COOLIO: return DSN2Catalog.ID_N3_PENSHIN_FATCHA;
        case SANTA: return DSN2Catalog.ID_N3_SANTA_JAVELIN;
        case GAZEBO: return DSN2Catalog.ID_N3_GAZE_OF_GAEA;
        case CHULAREH: return DSN2Catalog.ID_N3_MAGI_STONE;
        case SPACEDUDE: return DSN2Catalog.ID_N3_PHAS3R;
        case BATS: return DSN2Catalog.ID_N3_MAZO_FAMILIAR;
        case ROSE: return DSN2Catalog.ID_FUWALAFUWALOO;
        case GYORUNTIN: return DSN2Catalog.ID_NO_FUTURE;
        case SECRETINO: return DSN2Catalog.ID_N3_KYRA_STONES;
        case SPACEDETTE: return DSN2Catalog.ID_N3_PHOTONSTORM;
        }
        return DSN2Catalog.ID_WHIP;
    }
    // Bats Bats, Gyoruntin and Space Dette: the starting weapon grows stronger
    // every level (+1% Might for it per level, a guess).
    static bool StarterGrows(int c) { return c == BATS || c == GYORUNTIN || c == SPACEDETTE; }

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
        case SMITH: return 7;
        case MARRABBIO: return 120;
        case MINNAH: return 150;
        case PEPPINO: return 120;
        case GYORUNTON: return 300;
        case REDDEATH: return 255;
        case AVATAR: return 160;
        case SIGMA: return 333;
        case BATS: return 180;
        case GYORUNTIN: return 130;
        }
        return 100;
    }

    // Starting level-up charges (wiki): Divano begins with +10 Banish.
    static int StartBanish(int c)
    {
        if (c == DIVANO) return 10;
        if (c == SIGMA) return 108;
        return c == SECRETINO ? 7 : 0;
    }
    static int StartReroll(int c)
    {
        if (c == IGUANA) return 5;
        if (c == AVATAR) return 10;
        if (c == SIGMA) return 108;
        return c == CHULAREH || c == SECRETINO ? 7 : 0;
    }
    static int StartSkip(int c)
    {
        if (c == IGUANA) return 5;
        if (c == SIGMA) return 108;
        return c == SECRETINO ? 7 : 0;
    }

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
        case SMITH:
            s.move += 200; s.might -= 100; s.cooldown += 100; s.area -= 100; s.speed -= 500;
            s.duration -= 100; s.luck += 1000;
            s.recovery += 10 * level; s.might += 7 * level; s.speed += 7 * level;
            s.duration += 7 * level; s.area += 7 * level; s.cooldown -= 25 * level / 10; s.luck += 10 * level;
            break;
        case MARRABBIO:
            s.move += 300; s.might += 200; s.speed -= 100; s.greed -= 800; s.curse += 100;
            break;
        case MINNAH:
            // The original also shuffles Might, Speed, Duration, Area and Cooldown every minute (not modelled).
            s.recovery += 500; s.might -= 700; s.might += 100 * min(level / 3, 7);
            break;
        case LEDA:
            s.armor += 5; s.move -= 200; s.might += 1000; s.cooldown -= 100; s.area += 100; s.greed -= 800;
            break;
        case PEPPINO:
        {
            s.armor += 2; s.magnet += 1000; s.area -= 600;
            static const int PEPPINO_STEPS[] = { 2, 3, 5, 8, 13, 21 };
            for (int i = 0; i < 6; i++) if (level >= PEPPINO_STEPS[i]) s.area += 100;
            break;
        }
        case BOROS:
            s.growth += 20 * level;
            break;
        case GYORUNTON:
            s.might += 300; s.revival += 2; s.curse += 10 * level;
            break;
        case REDDEATH:
            s.move += 1000; s.might += 200;
            break;
        case TROUSER:
            s.move += 300; s.greed += 200 + 10 * level; s.feverPct += 50;
            break;
        case AVATAR:
            s.might += 500 + 5 * level; s.luck += 500; s.magnet += 1000; s.revival += 1;
            s.curse += 5 * level; s.move += 20 * level; s.cooldown -= 25 * level / 10;
            break;
        case SIGMA:
            s.armor += 3; s.recovery += 3000; s.move += 500; s.might += 500 + 10 * level; s.cooldown -= 250;
            s.duration += 500; s.amount += 1; s.luck += 500; s.curse += 100; s.magnet += 1000;
            s.revival += 1; s.growth += 10 * level;
            break;
        case ROBBERT:
            s.armor += 1; s.recovery += 500; s.move += 200;
            break;
        case ZIAPPUNTA:
            s.move += 300; s.speed += 200; s.duration += 200; s.luck += 200; s.magnet += 300;
            break;
        case TROUBLER:
            s.move += 200; s.greed += 300;
            break;
        case SHEMOON:
            s.armor += 2; s.move += 200;
            break;
        case COOLIO:
            s.move += 300; s.duration += 300;
            break;
        case SANTA:
            s.armor += 2; s.luck += 300; s.cooldown -= max(100, 700 - 200 * (level - 1));
            break;
        case GAZEBO:
            s.move += 500;
            break;
        case CHULAREH:
            s.move += 70; s.luck += 70; s.magnet += 70;
            break;
        case SPACEDUDE: case SPACEDETTE:
            s.move += 400;
            break;
        case BATS:
            s.move += 800; s.revival += 2;
            break;
        case ROSE:
        {
            s.move += 200; s.might -= 900; s.growth -= 800; s.charm += 100;
            int steps = min(level / 12, 9);
            s.might += 100 * steps;
            if (steps >= 3) s.growth += 100 * min(steps - 2, 5) + 150 * max(0, steps - 7);
            break;
        }
        case GYORUNTIN:
            s.armor += 3; s.move += 800; s.curse += 10 * level;
            break;
        case EXDASH: case TOASTIE:
            s.move += c == EXDASH ? -100 : 200;
            s.might -= 100; s.speed -= 500; s.duration -= 100; s.area -= 100;
            s.cooldown += 100; s.luck += 1000;
            // Exdash +10% and Toastie +20% Luck every 10 levels up to 50.
            s.luck += (c == EXDASH ? 100 : 200) * min(level / 10, 5);
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
