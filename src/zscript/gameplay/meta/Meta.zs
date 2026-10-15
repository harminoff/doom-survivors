// Meta progression: the lifetime counters behind unlocks, the collection and
// the bestiary (docs/TODO.md). Stored as "key=value;..." in the ds_meta cvar
// (separate from the hashed gold profile). Keys:
//   runs kills gold maxgold oro vac ros chk   lifetime totals / bests
//   lvl:<stage> won:<stage> lvlmax            best level per stage, survived
//   rank:<item id> seen:<item id>             best rank / ever owned
//   ek:<enemy type>                           kills per enemy type
//   coffin:<n> arc:<n> curse20                coffins opened, Arcana seen
//   srv:<char> srvmax heal lsrc maxkills      best seconds survived, HP healed,
//   evo6 wpn6 ach:<n>                         light sources, best run kills, flags
// Unlock rules follow the wiki; where the original needs a feature that is not
// built (Hyper mode, Little Clovers, Gold Fingers) a labelled stand-in is used.

class DSMeta
{
    static void Load(out Array<String> keys, out Array<int> vals)
    {
        keys.Clear(); vals.Clear();
        CVar store = CVar.FindCVar("ds_meta");
        if (store == null) return;
        String text = store.GetString();
        if (text.Length() == 0) return;
        Array<String> parts;
        text.Split(parts, ";");
        for (int i = 0; i < parts.Size(); i++)
        {
            int eq = parts[i].IndexOf("=");
            if (eq <= 0) continue;
            keys.Push(parts[i].Left(eq));
            vals.Push(parts[i].Mid(eq + 1).ToInt());
        }
    }

    static void Store(Array<String> keys, Array<int> vals)
    {
        CVar store = CVar.FindCVar("ds_meta");
        if (store == null) return;
        String text = "";
        for (int i = 0; i < keys.Size(); i++)
        {
            if (vals[i] == 0) continue;
            if (text.Length() > 0) text = text .. ";";
            text = text .. keys[i] .. "=" .. String.Format("%d", vals[i]);
        }
        store.SetString(text);
        CVar.SaveConfig();
    }

    static int Val(Array<String> keys, Array<int> vals, String key)
    {
        for (int i = 0; i < keys.Size(); i++) if (keys[i] == key) return vals[i];
        return 0;
    }

    static void SetVal(Array<String> keys, Array<int> vals, String key, int value)
    {
        for (int i = 0; i < keys.Size(); i++) if (keys[i] == key) { vals[i] = value; return; }
        keys.Push(key); vals.Push(value);
    }

    static void Bump(Array<String> keys, Array<int> vals, String key, int delta)
    {
        SetVal(keys, vals, key, Val(keys, vals, key) + delta);
    }

    static void Best(Array<String> keys, Array<int> vals, String key, int value)
    {
        if (value > Val(keys, vals, key)) SetVal(keys, vals, key, value);
    }

    static int KeyedTotal(Array<String> keys, Array<int> vals, String prefix)
    {
        int n = 0;
        for (int i = 0; i < keys.Size(); i++) if (keys[i].IndexOf(prefix) == 0) n += vals[i] != 0 ? 1 : 0;
        return n;
    }

    // Kills of the enemy with exactly this id.
    static int KillsOf(Array<String> keys, Array<int> vals, String enemyId)
    {
        for (int t = 1; t <= DSStage.ENEMY_TYPE_COUNT; t++)
            if (DSStage.TypeName(t) == enemyId) return Val(keys, vals, String.Format("ek:%d", t));
        return 0;
    }

    // Kills of every enemy whose id contains the text (e.g. "SKELETON").
    static int KillsMatching(Array<String> keys, Array<int> vals, String needle)
    {
        int total = 0;
        for (int t = 1; t <= DSStage.ENEMY_TYPE_COUNT; t++)
            if (DSStage.TypeName(t).IndexOf(needle) >= 0) total += Val(keys, vals, String.Format("ek:%d", t));
        return total;
    }
}

// Golden Eggs (wiki): each gives a small permanent boost to one of 19 stats,
// applied from the next run on. Counts live in ds_meta as egg:<stat>.
class DSEggs
{
    const COUNT = 19;
    static const String NAMES[] = {
        "Max Health", "Recovery", "Armor", "Amount", "Revival", "Reroll", "Move Speed", "Might",
        "Speed", "Duration", "Area", "Luck", "Growth", "Greed", "Curse", "Cooldown", "Magnet",
        "Skip", "Banish"
    };

    static String Name(int stat) { return stat >= 0 && stat < COUNT ? DSEggs.NAMES[stat] : "Stat"; }

    static void Load(out Array<int> eggs)
    {
        eggs.Clear();
        Array<String> k; Array<int> v;
        DSMeta.Load(k, v);
        for (int i = 0; i < DSAchievementData.COUNT; i++) eggs.Push(DSMeta.Val(k, v, String.Format("egg:%d", i)));
    }

    // Whole charges from fractional per-egg values: Reroll 0.1, Skip and Banish 0.2.
    static int Charges(Array<int> eggs, int stat)
    {
        if (eggs.Size() < COUNT) return 0;
        return stat == 5 ? eggs[5] / 10 : eggs[stat] / 5;
    }

    static void Apply(Array<int> e, DSRunStatBlock s)
    {
        if (e.Size() < COUNT) return;
        s.maxHealthPct += 10 * e[0];
        s.recovery += 100 * e[1];
        s.armor += e[2] / 10;
        s.amount += e[3] / 10;
        s.revival += e[4] / 10;
        s.move += 10 * e[6];
        s.might += 10 * e[7];
        s.speed += 10 * e[8];
        s.duration += 10 * e[9];
        s.area += 10 * e[10];
        s.luck += 10 * e[11];
        s.growth += 10 * e[12];
        s.greed += 10 * e[13];
        s.curse += 10 * e[14];
        s.cooldown -= 5 * e[15];
        s.magnet += 30 * e[16];
    }
}

// Achievements: Vampire Survivors' base-game achievements (wiki) this port can track
// (DSAchievementData, generated by tools/gen_achievements.py), worked out from
// the profile counters. Gold prizes are paid once (ach:<index> marks it).
class DSAchievements
{
    const K_LEVEL = 1; const K_STAGE_LEVEL = 2; const K_SURVIVE = 3; const K_STAGE_MINUTE = 4;
    const K_RANK = 5; const K_SEEN = 6; const K_COUNTER = 7; const K_KILLS_MATCH = 8;
    const K_COFFIN = 9; const K_CHAR_LEVEL = 10; const K_RELIC = 11; const K_COLLECTION = 12;
    const K_ALL_EVOS = 13; const K_SURVIVE_EITHER = 14;
    const R_NONE = 0; const R_WEAPON = 1; const R_CHARACTER = 2; const R_STAGE = 3;
    const R_POWERUP = 4; const R_ARCANA = 5; const R_GOLD = 6;

    static String Name(int i) { return DSAchievementData.TEXT[i]; }

    // What the achievement unlocks, for the list.
    static String Goal(int i)
    {
        int r = DSAchievementData.REWARD[i];
        switch (DSAchievementData.REWARD_KIND[i])
        {
        case R_WEAPON: return DSN2Catalog.DisplayName(r);
        case R_CHARACTER: return DSCharacters.Name(r);
        case R_STAGE: return DSStage.Name(r);
        case R_POWERUP: return "PowerUp " .. DSPowerUps.Name(r);
        case R_ARCANA: return "Arcana " .. DSArcana.Name(r);
        case R_GOLD: return String.Format("%d gold", r);
        }
        return "";
    }

    static bool Done(Array<String> k, Array<int> v, int i)
    {
        int a = DSAchievementData.A[i]; int b = DSAchievementData.B[i]; int c = DSAchievementData.C[i];
        String s = DSAchievementData.S[i];
        switch (DSAchievementData.KIND[i])
        {
        case K_LEVEL: return DSMeta.Val(k, v, "lvlmax") >= a;
        case K_STAGE_LEVEL: return DSMeta.Val(k, v, String.Format("lvl:%d", a)) >= b;
        case K_SURVIVE: return DSMeta.Val(k, v, b < 0 ? "srvmax" : String.Format("srv:%d", b)) >= a;
        case K_SURVIVE_EITHER: return DSMeta.Val(k, v, String.Format("srv:%d", b)) >= a || DSMeta.Val(k, v, String.Format("srv:%d", c)) >= a;
        case K_STAGE_MINUTE: return DSMeta.Val(k, v, String.Format("mnt:%d", a)) >= b;
        case K_RANK: return DSMeta.Val(k, v, String.Format("rank:%d", a)) >= b || (c > 0 && DSMeta.Val(k, v, String.Format("seen:%d", c)) > 0);
        case K_SEEN: return DSMeta.Val(k, v, String.Format("seen:%d", a)) > 0;
        case K_COUNTER: return DSMeta.Val(k, v, s) >= a;
        case K_KILLS_MATCH: return DSMeta.KillsMatching(k, v, s) >= a;
        case K_COFFIN: return DSMeta.Val(k, v, String.Format("coffin:%d", a)) > 0;
        case K_CHAR_LEVEL: return DSMeta.Val(k, v, String.Format("chl:%d", a)) >= b;
        case K_RELIC: return DSMeta.Val(k, v, String.Format("relic:%d", a)) > 0;
        case K_COLLECTION: return DSMeta.KeyedTotal(k, v, "seen:") >= a;
        case K_ALL_EVOS:
            for (int e = 0; e < DSAchievementData.EVOLUTIONS.Size(); e++)
                if (DSMeta.Val(k, v, String.Format("seen:%d", DSAchievementData.EVOLUTIONS[e])) <= 0) return false;
            return true;
        }
        return false;
    }

    static int DoneCount(Array<String> k, Array<int> v)
    {
        int n = 0;
        for (int i = 0; i < DSAchievementData.COUNT; i++) if (Done(k, v, i)) n++;
        return n;
    }

    static bool IsEvolution(int id)
    {
        for (int e = 0; e < DSAchievementData.EVOLUTIONS.Size(); e++)
            if (DSAchievementData.EVOLUTIONS[e] == id) return true;
        return false;
    }

    // True when some achievement gives this reward; done says whether any is done.
    static bool Rewards(Array<String> k, Array<int> v, int kind, int value, out bool done)
    {
        bool found = false; done = false;
        for (int i = 0; i < DSAchievementData.COUNT; i++)
        {
            if (DSAchievementData.REWARD_KIND[i] != kind || DSAchievementData.REWARD[i] != value) continue;
            found = true;
            if (Done(k, v, i)) { done = true; return true; }
        }
        return found;
    }

    // The first achievement (not done) behind a reward, for "locked" hints.
    static String RewardCondition(Array<String> k, Array<int> v, int kind, int value)
    {
        for (int i = 0; i < DSAchievementData.COUNT; i++)
            if (DSAchievementData.REWARD_KIND[i] == kind && DSAchievementData.REWARD[i] == value && !Done(k, v, i))
                return Name(i);
        return "";
    }
}

// Relics found on stages (relic:<n> in ds_meta). What each unlocks follows
// the original; the Grimoire, Magic Banger and Forbidden Scrolls are
// collectibles only here (no recipe book, music player or secret codes).
class DSRelics
{
    const YELLOW_SIGN = 1; const RANDOMAZZO = 2; const GRIMOIRE = 3; const MILKY_WAY = 4;
    const GOUDA = 5; const TEARS = 6; const BANGER = 7; const TRISECTION = 8; const SCROLLS = 9;
    const BRAVE_STORY = 10; const MIRROR = 11; const TRUMPET = 12; const GOSPEL = 13;
    const GLASS_VIZARD = 14; const MINDBENDER = 15; const APOPLEXY = 16; const ANTIDOTE = 17; const WAX_FETISH = 18;
    const COUNT = 18;

    static String Name(int n)
    {
        switch (n)
        {
        case YELLOW_SIGN: return "the Yellow Sign"; case RANDOMAZZO: return "the Randomazzo";
        case GRIMOIRE: return "the Grim Grimoire"; case MILKY_WAY: return "the Milky Way Map";
        case GOUDA: return "the Ars Gouda"; case TEARS: return "the Sorceress' Tears";
        case BANGER: return "the Magic Banger"; case TRISECTION: return "the Trisection";
        case SCROLLS: return "the Forbidden Scrolls of Morbane"; case BRAVE_STORY: return "the Brave Story";
        case MIRROR: return "Gracia's Mirror"; case TRUMPET: return "the Seventh Trumpet";
        case GOSPEL: return "the Great Gospel";
        case GLASS_VIZARD: return "the Glass Vizard"; case MINDBENDER: return "the Mindbender";
        case APOPLEXY: return "the Apoplexy"; case ANTIDOTE: return "the Antidote"; case WAX_FETISH: return "the Wax Fetish";
        }
        return "a relic";
    }

    static String Gift(int n)
    {
        switch (n)
        {
        case YELLOW_SIGN: return "The Ender will come for you.";
        case RANDOMAZZO: return "Sarabande of Healing is yours.";
        case MILKY_WAY: return "Pickup arrows are unlocked.";
        case GOUDA: return "The Bestiary is open.";
        case TEARS: return "Hurry mode is unlocked.";
        case TRISECTION: return "Random Events are unlocked.";
        case BRAVE_STORY: return "Random Level-ups are unlocked.";
        case MIRROR: return "Inverse mode is unlocked.";
        case TRUMPET: return "Endless mode is unlocked.";
        case GOSPEL: return "Limit Break is unlocked.";
        case GLASS_VIZARD: return "The Merchant now visits every stage.";
        case MINDBENDER: return "You can set the maximum number of weapons (W on character select).";
        case APOPLEXY: return "The Charm PowerUp can be bought.";
        case ANTIDOTE: return "The Defang PowerUp can be bought.";
        case WAX_FETISH: return "The Preserve PowerUp can be bought.";
        case GRIMOIRE: return "The Collection shows evolution recipes.";
        case BANGER: return "You can pick the music (B on stage select).";
        }
        return "";
    }

    static bool Owned(Array<String> k, Array<int> v, int n)
    {
        // The Great Gospel is the prize for defeating the Ender.
        if (n == GOSPEL && DSMeta.Val(k, v, "ender") > 0) return true;
        // The Mindbender comes with 50 Collection entries.
        if (n == MINDBENDER && DSMeta.KeyedTotal(k, v, "seen:") >= 50) return true;
        return DSUnlocks.All() || DSMeta.Val(k, v, String.Format("relic:%d", n)) > 0;
    }
}

// Forbidden Scrolls of Morbane: typing one of the original's spells
// (DSSecretData, tools/gen_secrets.py) on the Secrets page unlocks what it
// names. Stored as spc:/sps:/spa:/spw:/mod: keys and relic:<n> in ds_meta.
class DSSecrets
{
    // Applies the spell; returns what it did, or "" if no such spell.
    static String Cast(Array<String> k, Array<int> v, String typed)
    {
        String spell = typed.MakeLower();
        for (int i = 0; i < DSSecretData.COUNT; i++)
        {
            if (DSSecretData.SPELL[i] != spell) continue;
            String done = Apply(k, v, DSSecretData.KIND[i], DSSecretData.VALUE[i]);
            if (DSSecretData.KIND2[i] > 0) done = done .. ", " .. Apply(k, v, DSSecretData.KIND2[i], DSSecretData.VALUE2[i]);
            DSMeta.SetVal(k, v, String.Format("spell:%d", i), 1);
            DSMeta.Store(k, v);
            return done;
        }
        return "";
    }

    static String Apply(Array<String> k, Array<int> v, int kind, int value)
    {
        switch (kind)
        {
        case 1: DSMeta.SetVal(k, v, String.Format("spc:%d", value), 1); return DSCharacters.Name(value);
        case 2: DSMeta.SetVal(k, v, String.Format("sps:%d", value), 1); return DSStage.Name(value);
        case 3: DSMeta.SetVal(k, v, String.Format("relic:%d", value), 1); return DSRelics.Name(value);
        case 4: DSMeta.SetVal(k, v, String.Format("spa:%d", value), 1); return "Arcana " .. DSArcana.Name(value);
        case 5: DSMeta.SetVal(k, v, String.Format("spw:%d", value), 1); return DSN2Catalog.DisplayName(value);
        case 6: DSMeta.SetVal(k, v, String.Format("mod:%d", value), 1);
            return value == 1 ? "Everything: every weapon in level-ups" : "Everywhere: every main stage and Hyper";
        }
        return "";
    }

    static int CastCount(Array<String> k, Array<int> v) { return DSMeta.KeyedTotal(k, v, "spell:"); }
}

class DSUnlocks
{
    static bool All()
    {
        CVar all = CVar.FindCVar("ds_unlock_all");
        return all != null && all.GetInt() != 0;
    }

    // ---- characters (DSCharacters order) ----------------------------------------

    static bool CharacterUnlocked(Array<String> k, Array<int> v, int c)
    {
        if (All() || DSMeta.Val(k, v, String.Format("spc:%d", c)) > 0) return true;
        switch (c)
        {
        case 0: case 1: case 2: case 3: return true;
        case 4: return DSMeta.Val(k, v, "rank:40") >= 4;
        case 5: return DSMeta.Val(k, v, "rank:50") >= 4;
        case 6: return DSMeta.Val(k, v, "curse20") > 0;
        case 7: return DSMeta.Val(k, v, "rank:48") >= 7;
        case 8: return DSMeta.Val(k, v, "heal") >= 1000;
        case 9: return DSMeta.Val(k, v, "maxgold") >= 5000;
        case 10: return DSMeta.Val(k, v, "kills") >= 100000;
        case 11: return DSMeta.Val(k, v, "rank:52") >= 7;
        case 12: return DSMeta.Val(k, v, "coffin:0") > 0;
        case 13: return DSMeta.Val(k, v, "coffin:2") > 0;
        case 14: return DSMeta.KillsMatching(k, v, "SKELETON") >= 3000;
        case 15: return DSMeta.KillsMatching(k, v, "BUER") >= 3000;
        case 16: return DSMeta.KillsMatching(k, v, "MILK") >= 3000;
        case 17: return DSMeta.KillsMatching(k, v, "XLDRAGON") >= 3000;
        case 18: return DSMeta.Val(k, v, "coffin:4") > 0;
        case 19: return DSMeta.KillsMatching(k, v, "STAGEKILLER") >= 6000;
        case 20: return DSMeta.Val(k, v, "clv") >= 40;
        case 21: return CharacterUnlocked(k, v, 20) && DSMeta.Val(k, v, "runs") >= 10;
        case 24: return DSMeta.Val(k, v, "seen:" .. String.Format("%d", DSN2Catalog.ID_N3_INFINITE_CORRIDOR)) > 0;
        case 22: return DSMeta.Val(k, v, "coffin:1") > 0;
        case 23: return DSMeta.Val(k, v, "coffin:3") > 0;
        case 25: return DSMeta.Val(k, v, "seen:85") > 0;
        // Secret characters. The original hides most behind stage secrets;
        // those are stood in for by surviving the stage they point to.
        case DSCharacters.SMITH: return CharacterUnlocked(k, v, DSCharacters.EXDASH) && CharacterUnlocked(k, v, DSCharacters.TOASTIE);
        case DSCharacters.MARRABBIO: return DSMeta.Val(k, v, "won:0") > 0;
        case DSCharacters.MINNAH: return DSMeta.Val(k, v, "won:2") > 0;
        case DSCharacters.LEDA: return DSMeta.Val(k, v, "won:3") > 0;
        case DSCharacters.PEPPINO: return DSMeta.Val(k, v, "won:7") > 0;
        case DSCharacters.BOROS: return DSMeta.Val(k, v, "won:6") > 0;
        case DSCharacters.GYORUNTON: return DSMeta.Val(k, v, "won:9") > 0;
        case DSCharacters.REDDEATH: return DSMeta.Val(k, v, "reaper") > 0;
        case DSCharacters.TROUSER: return DSMeta.Val(k, v, "won:8") > 0;
        case DSCharacters.AVATAR: return DSMeta.Val(k, v, "winv:1") > 0;
        case DSCharacters.SIGMA: return CollectionComplete(k, v);
        case DSCharacters.ROBBERT: return DSMeta.Val(k, v, String.Format("seen:%d", DSN2Catalog.ID_N3_MAZO_FAMILIAR)) > 0;
        case DSCharacters.ZIAPPUNTA: return DSMeta.Val(k, v, String.Format("seen:%d", DSN2Catalog.ID_N3_GUNASTROPHE)) > 0;
        case DSCharacters.TROUBLER: return DSMeta.Val(k, v, String.Format("seen:%d", DSN2Catalog.ID_N3_SPIRIT_DISTURBANCE)) > 0;
        case DSCharacters.SHEMOON: return DSMeta.Val(k, v, "mnt:10") >= 20;
        case DSCharacters.COOLIO: return DSMeta.Val(k, v, "mnt:11") >= 20;
        case DSCharacters.SANTA: return DSMeta.Val(k, v, "mnt:14") >= 20;
        case DSCharacters.GAZEBO: return DSMeta.Val(k, v, "mnt:12") >= 20;
        case DSCharacters.CHULAREH: return DSMeta.Val(k, v, "mnt:15") >= 20;
        case DSCharacters.SPACEDUDE: return DSMeta.Val(k, v, "mnt:13") >= 20;
        case DSCharacters.BATS: return DSMeta.Val(k, v, "rank:129") >= 9 && DSMeta.Val(k, v, "rank:139") >= 9;
        case DSCharacters.ROSE: return DSMeta.Val(k, v, "won:17") > 0;
        case DSCharacters.GYORUNTIN: return DSMeta.Val(k, v, "won:20") > 0;
        case DSCharacters.SECRETINO: return DSMeta.Val(k, v, String.Format("srv:%d", DSCharacters.CHULAREH)) >= 1200;
        case DSCharacters.SPACEDETTE: return DSMeta.Val(k, v, String.Format("srv:%d", DSCharacters.SPACEDUDE)) >= 1200;
        case DSCharacters.RANDOM: return DSMeta.Val(k, v, "coffinagain") > 0;
        }
        return false;
    }

    // Every weapon and passive in the catalog seen at least once.
    static bool CollectionComplete(Array<String> k, Array<int> v)
    {
        Array<int> ids;
        DSN2Catalog.AllIds(ids);
        for (int i = 0; i < ids.Size(); i++)
            if (DSMeta.Val(k, v, String.Format("seen:%d", ids[i])) <= 0) return false;
        return true;
    }

    static String CharacterCondition(Array<String> k, Array<int> v, int c)
    {
        switch (c)
        {
        case 4: return String.Format("Get Fire Wand to level 4 (best %d)", DSMeta.Val(k, v, "rank:40"));
        case 5: return String.Format("Get Lightning Ring to level 4 (best %d)", DSMeta.Val(k, v, "rank:50"));
        case 6: return "Survive 20 minutes with at least 10% Curse";
        case 7: return String.Format("Get Garlic to level 7 (best %d)", DSMeta.Val(k, v, "rank:48"));
        case 8: return String.Format("Recover a total of 1000 HP (%d)", DSMeta.Val(k, v, "heal"));
        case 9: return String.Format("Earn 5000 gold in one run (best %d)", DSMeta.Val(k, v, "maxgold"));
        case 10: return String.Format("Defeat 100000 enemies (%d)", DSMeta.Val(k, v, "kills"));
        case 11: return String.Format("Get Pentagram to level 7 (best %d)", DSMeta.Val(k, v, "rank:52"));
        case 12: return "Find and open the coffin in Mad Forest";
        case 13: return "Find and open the coffin in Dairy Plant";
        case 14: return String.Format("Defeat 3000 skeletons (%d)", DSMeta.KillsMatching(k, v, "SKELETON"));
        case 15: return String.Format("Defeat 3000 Lionheads (%d)", DSMeta.KillsMatching(k, v, "BUER"));
        case 16: return String.Format("Defeat 3000 Milk Elementals (%d)", DSMeta.KillsMatching(k, v, "MILK"));
        case 17: return String.Format("Defeat 3000 Dragon Shrimps (%d)", DSMeta.KillsMatching(k, v, "XLDRAGON"));
        case 18: return "Find and open the coffin in Cappella Magna";
        case 19: return String.Format("Defeat 6000 Stage Killers (%d)", DSMeta.KillsMatching(k, v, "STAGEKILLER"));
        case 20: return String.Format("Collect 40 Little Clovers (%d) - the original is a rare chance per clover", DSMeta.Val(k, v, "clv"));
        case 21: return "Unlock Exdash and play 10 runs - stands in for a Forbidden Scrolls spell";
        case 24: return "Obtain the Infinite Corridor";
        case 22: return "Find and open the coffin in Inlaid Library";
        case 23: return "Find and open the coffin in Gallo Tower";
        case 25: return "Obtain the Crimson Shroud";
        case DSCharacters.SMITH: return "Unlock Exdash and Toastie - stands in for a Forbidden Scrolls secret";
        case DSCharacters.MARRABBIO: return "Survive the Mad Forest - stands in for its secret";
        case DSCharacters.MINNAH: return "Survive the Dairy Plant - stands in for its secret";
        case DSCharacters.LEDA: return "Survive the Gallo Tower - stands in for its secret";
        case DSCharacters.PEPPINO: return "Survive Il Molise - stands in for its secret";
        case DSCharacters.BOROS: return "Survive The Bone Zone - stands in for its secret";
        case DSCharacters.GYORUNTON: return "Survive Boss Rash - the original asks for just one weapon";
        case DSCharacters.REDDEATH: return "Defeat the Reaper";
        case DSCharacters.TROUSER: return "Survive Moongolow - stands in for its secret";
        case DSCharacters.AVATAR: return "Survive the Inlaid Library in Inverse mode";
        case DSCharacters.SIGMA: return "Complete the Collection";
        case DSCharacters.ROBBERT: return "Evolve Pako Battiliar";
        case DSCharacters.ZIAPPUNTA: return "Evolve Ammo Appalate";
        case DSCharacters.TROUBLER: return "Evolve Unearthly Bolt";
        case DSCharacters.SHEMOON: return "Survive 20 minutes in Whiteout";
        case DSCharacters.COOLIO: return "Survive 20 minutes in The Lycaeum";
        case DSCharacters.SANTA: return "Survive 20 minutes in Laborratory";
        case DSCharacters.GAZEBO: return "Survive 20 minutes in The Coop";
        case DSCharacters.CHULAREH: return "Survive 20 minutes in Westwoods";
        case DSCharacters.SPACEDUDE: return "Survive 20 minutes in Space 54";
        case DSCharacters.BATS: return "Get Silver Ring and Gold Ring to level 9 - stands in for the ring of rings";
        case DSCharacters.ROSE: return "Survive the Astral Stair - stands in for its 46th door";
        case DSCharacters.GYORUNTIN: return "Survive Carlo Cart - stands in for its secret";
        case DSCharacters.SECRETINO: return "Survive 20 minutes with Chula-Reh - stands in for a secret";
        case DSCharacters.SPACEDETTE: return "Survive 20 minutes with Space Dude - stands in for its secret";
        case DSCharacters.RANDOM: return "Look under a coffin you have already opened";
        }
        return "";
    }

    // ---- weapons, passives and PowerUps -------------------------------------------

    // Draftable items: locked while an achievement unlocks them and none is done.
    // The rings and Metaglio unlock once found on a stage.
    static bool ItemUnlocked(Array<String> k, Array<int> v, int id)
    {
        if (All() || DSMeta.Val(k, v, String.Format("spw:%d", id)) > 0) return true;
        if (DSMeta.Val(k, v, "mod:1") > 0 && DSN2Catalog.Category(id) == DSN2Catalog.CATEGORY_WEAPON) return true;   // Everything
        if (id == DSN2Catalog.ID_N3_SILVER_RING || id == DSN2Catalog.ID_N3_GOLD_RING
            || id == DSN2Catalog.ID_N3_METAGLIO_LEFT || id == DSN2Catalog.ID_N3_METAGLIO_RIGHT)
            return DSMeta.Val(k, v, String.Format("seen:%d", id)) > 0;
        bool done;
        return !DSAchievements.Rewards(k, v, DSAchievements.R_WEAPON, id, done) || done;
    }

    static String ItemCondition(Array<String> k, Array<int> v, int id)
    {
        if (id == DSN2Catalog.ID_N3_SILVER_RING || id == DSN2Catalog.ID_N3_GOLD_RING
            || id == DSN2Catalog.ID_N3_METAGLIO_LEFT || id == DSN2Catalog.ID_N3_METAGLIO_RIGHT)
            return "Find it on a stage";
        return DSAchievements.RewardCondition(k, v, DSAchievements.R_WEAPON, id);
    }

    static bool PowerUpUnlocked(Array<String> k, Array<int> v, int p)
    {
        if (All()) return true;
        // Charm, Defang and Preserve are bought once their relic is found.
        if (p == DSPowerUps.CHARM) return DSRelics.Owned(k, v, DSRelics.APOPLEXY);
        if (p == DSPowerUps.DEFANG) return DSRelics.Owned(k, v, DSRelics.ANTIDOTE);
        if (p == DSPowerUps.PRESERVE) return DSRelics.Owned(k, v, DSRelics.WAX_FETISH);
        bool done;
        return !DSAchievements.Rewards(k, v, DSAchievements.R_POWERUP, p, done) || done;
    }

    static String PowerUpCondition(Array<String> k, Array<int> v, int p)
    {
        if (p == DSPowerUps.CHARM) return "Find the Apoplexy (Bat Country, 9:00)";
        if (p == DSPowerUps.DEFANG) return "Find the Antidote (south in Whiteout)";
        if (p == DSPowerUps.PRESERVE) return "Find the Wax Fetish (Mazerella)";
        return DSAchievements.RewardCondition(k, v, DSAchievements.R_POWERUP, p);
    }

    // ---- Arcana (DSArcana numbers) -------------------------------------------------

    static bool ArcanaUnlocked(Array<String> k, Array<int> v, int n)
    {
        if (All() || DSMeta.Val(k, v, String.Format("spa:%d", n)) > 0) return true;
        switch (n)
        {
        case 1: return DSMeta.Val(k, v, String.Format("chl:%d", DSCharacters.PUGNALA)) >= 50;
        case 2: return DSMeta.Val(k, v, String.Format("chl:%d", DSCharacters.DOMMARIO)) >= 50;
        case 3: return DSMeta.Val(k, v, String.Format("chl:%d", DSCharacters.PORTA)) >= 50;
        case 4: return DSMeta.Val(k, v, String.Format("chl:%d", DSCharacters.KROCHI)) >= 50;
        case 5: return DSMeta.Val(k, v, String.Format("chl:%d", DSCharacters.GIOVANNA)) >= 50;
        case 6: return DSMeta.Val(k, v, "relic:2") > 0;
        case 7: return DSMeta.Val(k, v, String.Format("chl:%d", DSCharacters.GENNARO)) >= 50;
        case 8: return DSMeta.Val(k, v, "mnt:0") >= 31;
        case 9: return DSMeta.Val(k, v, String.Format("chl:%d", DSCharacters.CLERICI)) >= 50;
        case 10: return DSMeta.Val(k, v, String.Format("chl:%d", DSCharacters.ANTONIO)) >= 50;
        case 11: return DSMeta.Val(k, v, String.Format("chl:%d", DSCharacters.IMELDA)) >= 50;
        case 12: return DSMeta.Val(k, v, "mnt:3") >= 31;
        case 13: return DSMeta.Val(k, v, String.Format("chl:%d", DSCharacters.CHRISTINE)) >= 50;
        case 14: return DSMeta.Val(k, v, String.Format("chl:%d", DSCharacters.PASQUALINA)) >= 50;
        case 15: return DSMeta.Val(k, v, "mnt:1") >= 31;
        case 16: return DSMeta.Val(k, v, String.Format("chl:%d", DSCharacters.LAMA)) >= 50;
        case 17: return DSMeta.Val(k, v, String.Format("chl:%d", DSCharacters.POPPEA)) >= 50;
        case 18: return DSMeta.Val(k, v, String.Format("chl:%d", DSCharacters.CONCETTA)) >= 50;
        case 19: return DSMeta.Val(k, v, String.Format("chl:%d", DSCharacters.ARCA)) >= 50;
        case 20: return DSMeta.Val(k, v, "mnt:2") >= 31;
        case 21: return DSMeta.Val(k, v, String.Format("chl:%d", DSCharacters.POE)) >= 50;
        case 22: return DSMeta.Val(k, v, "ender") > 0;
        }
        return false;
    }

    static String ArcanaCondition(int n)
    {
        switch (n)
        {
        case 1: return "Reach level 50 with Pugnala";
        case 2: return "Reach level 50 with Dommario";
        case 3: return "Reach level 50 with Porta";
        case 4: return "Reach level 50 with Krochi";
        case 5: return "Reach level 50 with Giovanna";
        case 6: return "Find the Randomazzo relic in Gallo Tower";
        case 7: return "Reach level 50 with Gennaro";
        case 8: return "Reach minute 31 in Mad Forest";
        case 9: return "Reach level 50 with Clerici";
        case 10: return "Reach level 50 with Antonio";
        case 11: return "Reach level 50 with Imelda";
        case 12: return "Reach minute 31 in Gallo Tower";
        case 13: return "Reach level 50 with Christine";
        case 14: return "Reach level 50 with Pasqualina";
        case 15: return "Reach minute 31 in Inlaid Library";
        case 16: return "Reach level 50 with Lama";
        case 17: return "Reach level 50 with Poppea";
        case 18: return "Reach level 50 with Concetta";
        case 19: return "Reach level 50 with Arca";
        case 20: return "Reach minute 31 in Dairy Plant";
        case 21: return "Reach level 50 with Poe";
        case 22: return "Defeat the Ender in Cappella Magna";
        }
        return "";
    }

    // ---- stages (DSStage order) -----------------------------------------------------

    static int Survived(Array<String> k, Array<int> v)
    {
        return DSMeta.KeyedTotal(k, v, "won:");
    }

    // Hyper mode per stage (the original): the five normal stages unlock it by
    // beating their boss; the next five come with the stage; the later stages
    // have it from the start, except Westwoods (stand-in: survive it) and
    // Holy Forbidden (never).
    static bool HyperUnlocked(Array<String> k, Array<int> v, int s)
    {
        if (All() || DSMeta.Val(k, v, String.Format("sps:%d", s)) > 0) return true;
        if (s <= 4 && DSMeta.Val(k, v, "mod:2") > 0) return true;   // Everywhere
        switch (s)
        {
        case DSStage.FOREST: return DSMeta.KillsOf(k, v, "XLFLOWER") + DSMeta.KillsOf(k, v, "BOSS_XLFLOWER") > 0;
        case DSStage.LIBRARY: return DSMeta.KillsOf(k, v, "BOSS_COUNT1") + DSMeta.KillsOf(k, v, "BOSS_WITCH2") > 0;
        case DSStage.PLANT: return DSMeta.KillsOf(k, v, "BOSS_XLARMOR") > 0;
        case DSStage.TOWER: return DSMeta.KillsOf(k, v, "BOSS_XLCRAB") > 0;
        case DSStage.CAPPELLA: return DSMeta.KillsOf(k, v, "BOSS_TRINACRIA") > 0;
        case DSStage.WESTWOODS: return DSMeta.Val(k, v, String.Format("won:%d", s)) > 0;
        case DSStage.HOLYFORBIDDEN: return false;
        }
        return StageUnlocked(k, v, s);
    }

    static String HyperCondition(int s)
    {
        switch (s)
        {
        case DSStage.FOREST: return "Defeat the giant Blue Venus in the Mad Forest";
        case DSStage.LIBRARY: return "Defeat the Hag in the Inlaid Library";
        case DSStage.PLANT: return "Defeat the Sword Guardian in the Dairy Plant";
        case DSStage.TOWER: return "Defeat the Giant Enemy Crab in the Gallo Tower";
        case DSStage.CAPPELLA: return "Defeat the Trinacria in the Cappella Magna";
        case DSStage.WESTWOODS: return "Survive Westwoods";
        case DSStage.HOLYFORBIDDEN: return "No Hyper mode here";
        }
        return "Unlock the stage";
    }

    // Normal stages (the first five) with Hyper unlocked.
    static int HyperCount(Array<String> k, Array<int> v)
    {
        int n = 0;
        for (int s = 0; s <= 4; s++) if (HyperUnlocked(k, v, s)) n++;
        return n;
    }

    static bool StageUnlocked(Array<String> k, Array<int> v, int s)
    {
        if (All() || DSMeta.Val(k, v, String.Format("sps:%d", s)) > 0) return true;
        if (s <= 4 && DSMeta.Val(k, v, "mod:2") > 0) return true;   // Everywhere
        switch (s)
        {
        case 0: return true;
        case 1: return DSMeta.Val(k, v, "lvl:0") >= 20;
        case 2: return DSMeta.Val(k, v, "lvl:1") >= 40;
        case 3: return DSMeta.Val(k, v, "lvl:2") >= 60;
        case 4: return DSMeta.Val(k, v, "lvl:3") >= 80;
        case 5: return HyperCount(k, v) >= 2;
        case 6: return HyperCount(k, v) >= 3;
        case 7: return HyperCount(k, v) >= 1;
        case 8: return HyperCount(k, v) >= 4;
        case 9: return HyperCount(k, v) >= 5;
        case 10: return DSMeta.Val(k, v, "oro") >= 20;
        case 11: return DSMeta.Val(k, v, "vac") >= 50;
        case 12: return DSMeta.Val(k, v, "chk") >= 500;
        case 13: return DSMeta.Val(k, v, "gfn") >= 5;
        case 14: return DSMeta.Val(k, v, "ros") >= 33;
        case 15: return DSMeta.Val(k, v, "clv") >= 20;
        case 16: return DSMeta.Val(k, v, "lvinv:0") >= 80;
        case 17: return DSMeta.Val(k, v, "lvinv:1") >= 80;
        case 18: return DSMeta.Val(k, v, "lvinv:2") >= 80;
        case 19: return DSMeta.Val(k, v, "lvinv:3") >= 80;
        case 20: return DSMeta.Val(k, v, "train") >= 2512;
        case 21: return DSMeta.Val(k, v, "kills") >= 1665;
        case 22: return DSMeta.Val(k, v, "runs") >= 15;
        case 23: return Survived(k, v) >= 12;
        case 24: return true;   // The Depths (original roguelike stage)
        }
        return false;
    }

    static String StageCondition(Array<String> k, Array<int> v, int s)
    {
        switch (s)
        {
        case 1: return String.Format("Reach level 20 in Mad Forest (best %d)", DSMeta.Val(k, v, "lvl:0"));
        case 2: return String.Format("Reach level 40 in Inlaid Library (best %d)", DSMeta.Val(k, v, "lvl:1"));
        case 3: return String.Format("Reach level 60 in Dairy Plant (best %d)", DSMeta.Val(k, v, "lvl:2"));
        case 4: return String.Format("Reach level 80 in Gallo Tower (best %d)", DSMeta.Val(k, v, "lvl:3"));
        case 5: return String.Format("Unlock Hyper on 2 normal stages (%d)", HyperCount(k, v));
        case 6: return String.Format("Unlock Hyper on 3 normal stages (%d)", HyperCount(k, v));
        case 7: return String.Format("Unlock Hyper on a normal stage (%d)", HyperCount(k, v));
        case 8: return String.Format("Unlock Hyper on 4 normal stages (%d)", HyperCount(k, v));
        case 9: return String.Format("Unlock Hyper on all 5 normal stages (%d)", HyperCount(k, v));
        case 10: return String.Format("Collect 20 Orologions (%d)", DSMeta.Val(k, v, "oro"));
        case 11: return String.Format("Collect 50 Vacuums (%d)", DSMeta.Val(k, v, "vac"));
        case 12: return String.Format("Collect 500 Floor Chicken (%d)", DSMeta.Val(k, v, "chk"));
        case 13: return String.Format("Find 5 Gold Fingers (%d)", DSMeta.Val(k, v, "gfn"));
        case 14: return String.Format("Collect 33 Rosaries (%d)", DSMeta.Val(k, v, "ros"));
        case 15: return String.Format("Collect 20 Little Clovers (%d)", DSMeta.Val(k, v, "clv"));
        case 16: return String.Format("Reach level 80 in the Inverse Mad Forest (best %d)", DSMeta.Val(k, v, "lvinv:0"));
        case 17: return String.Format("Reach level 80 in the Inverse Inlaid Library (best %d)", DSMeta.Val(k, v, "lvinv:1"));
        case 18: return String.Format("Reach level 80 in the Inverse Dairy Plant (best %d)", DSMeta.Val(k, v, "lvinv:2"));
        case 19: return String.Format("Reach level 80 in the Inverse Gallo Tower (best %d)", DSMeta.Val(k, v, "lvinv:3"));
        case 20: return String.Format("Hit 2512 enemies with Laborratory's train (%d)", DSMeta.Val(k, v, "train"));
        case 21: return String.Format("Defeat 1665 enemies in total (%d)", DSMeta.Val(k, v, "kills"));
        case 22: return String.Format("Play 15 runs (%d) - stands in for the Forbidden Scrolls spell", DSMeta.Val(k, v, "runs"));
        case 23: return String.Format("Survive 12 stages (%d) - stands in for the wiki quest", Survived(k, v));
        }
        return "";
    }
}
