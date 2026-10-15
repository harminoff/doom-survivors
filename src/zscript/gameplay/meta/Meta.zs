// Meta progression: the lifetime counters behind unlocks, the collection and
// the bestiary (docs/TODO.md). Stored as "key=value;..." in the ds_meta cvar
// (separate from the hashed gold profile). Keys:
//   runs kills gold maxgold oro vac ros chk   lifetime totals / bests
//   lvl:<stage> won:<stage> lvlmax            best level per stage, survived
//   rank:<item id> seen:<item id>             best rank / ever owned
//   ek:<enemy type>                           kills per enemy type
//   coffin:<n> arc:<n> curse20                coffins opened, Arcana seen
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
        for (int i = 0; i < COUNT; i++) eggs.Push(DSMeta.Val(k, v, String.Format("egg:%d", i)));
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

// Achievements: a list worked out from the profile counters (no extra
// storage). Names and goals are this game's own, loosely modelled on the original's.
class DSAchievements
{
    const COUNT = 34;

    static String Name(int i)
    {
        switch (i)
        {
        case 0: return "First Blood"; case 1: return "Veteran"; case 2: return "Centurion";
        case 3: return "Slayer"; case 4: return "Mass Extinction"; case 5: return "Gold Digger";
        case 6: return "Fat Purse"; case 7: return "Level 20"; case 8: return "Level 50";
        case 9: return "Level 80"; case 10: return "Survivor"; case 11: return "Seasoned Survivor";
        case 12: return "Marathon"; case 13: return "Mad Forest Cleared"; case 14: return "Inlaid Library Cleared";
        case 15: return "Dairy Plant Cleared"; case 16: return "Gallo Tower Cleared"; case 17: return "Cappella Magna Cleared";
        case 18: return "Grave Robber"; case 19: return "Six Feet Under"; case 20: return "Time Stopper";
        case 21: return "Vacuum Seal"; case 22: return "Rosary Beads"; case 23: return "Lucky Clover";
        case 24: return "Chicken Dinner"; case 25: return "Fortune Teller"; case 26: return "Arcana Fan";
        case 27: return "Yellow Sign"; case 28: return "The Ender Falls"; case 29: return "Collector";
        case 30: return "Golden Egg"; case 31: return "Egg Hoarder"; case 32: return "Cursed Survivor";
        }
        return "Hundred Runs";
    }

    static String Goal(int i)
    {
        switch (i)
        {
        case 0: return "Finish a run"; case 1: return "Finish 25 runs"; case 2: return "Defeat 1,000 enemies";
        case 3: return "Defeat 10,000 enemies"; case 4: return "Defeat 100,000 enemies"; case 5: return "Earn 1,000 gold in one run";
        case 6: return "Earn 5,000 gold in one run"; case 7: return "Reach level 20"; case 8: return "Reach level 50";
        case 9: return "Reach level 80"; case 10: return "Survive a stage"; case 11: return "Survive 5 stages";
        case 12: return "Survive 12 stages"; case 13: return "Survive Mad Forest"; case 14: return "Survive Inlaid Library";
        case 15: return "Survive Dairy Plant"; case 16: return "Survive Gallo Tower"; case 17: return "Survive Cappella Magna";
        case 18: return "Open a coffin"; case 19: return "Open all six coffins"; case 20: return "Collect 20 Orologions";
        case 21: return "Collect 50 Vacuums"; case 22: return "Collect 33 Rosaries"; case 23: return "Collect 23 Little Clovers";
        case 24: return "Eat 100 Floor Chicken"; case 25: return "Meet an Arcana"; case 26: return "Meet 11 different Arcana";
        case 27: return "Find the Yellow Sign in Holy Forbidden"; case 28: return "Defeat the Ender in Cappella Magna";
        case 29: return "Find 50 different items"; case 30: return "Buy a Golden Egg"; case 31: return "Buy 20 Golden Eggs";
        case 32: return "Survive 20 minutes with 10% Curse";
        }
        return "Finish 100 runs";
    }

    static bool Done(Array<String> k, Array<int> v, int i)
    {
        switch (i)
        {
        case 0: return DSMeta.Val(k, v, "runs") >= 1;
        case 1: return DSMeta.Val(k, v, "runs") >= 25;
        case 2: return DSMeta.Val(k, v, "kills") >= 1000;
        case 3: return DSMeta.Val(k, v, "kills") >= 10000;
        case 4: return DSMeta.Val(k, v, "kills") >= 100000;
        case 5: return DSMeta.Val(k, v, "maxgold") >= 1000;
        case 6: return DSMeta.Val(k, v, "maxgold") >= 5000;
        case 7: return DSMeta.Val(k, v, "lvlmax") >= 20;
        case 8: return DSMeta.Val(k, v, "lvlmax") >= 50;
        case 9: return DSMeta.Val(k, v, "lvlmax") >= 80;
        case 10: return DSUnlocks.Survived(k, v) >= 1;
        case 11: return DSUnlocks.Survived(k, v) >= 5;
        case 12: return DSUnlocks.Survived(k, v) >= 12;
        case 13: case 14: case 15: case 16: case 17: return DSMeta.Val(k, v, String.Format("won:%d", i - 13)) > 0;
        case 18: return DSMeta.KeyedTotal(k, v, "coffin:") >= 1;
        case 19: return DSMeta.KeyedTotal(k, v, "coffin:") >= 6;
        case 20: return DSMeta.Val(k, v, "oro") >= 20;
        case 21: return DSMeta.Val(k, v, "vac") >= 50;
        case 22: return DSMeta.Val(k, v, "ros") >= 33;
        case 23: return DSMeta.Val(k, v, "clv") >= 23;
        case 24: return DSMeta.Val(k, v, "chk") >= 100;
        case 25: return DSMeta.KeyedTotal(k, v, "arc:") >= 1;
        case 26: return DSMeta.KeyedTotal(k, v, "arc:") >= 11;
        case 27: return DSMeta.Val(k, v, "relic:1") > 0;
        case 28: return DSMeta.Val(k, v, "ender") > 0;
        case 29: return DSMeta.KeyedTotal(k, v, "seen:") >= 50;
        case 30: return DSMeta.Val(k, v, "eggs") >= 1;
        case 31: return DSMeta.Val(k, v, "eggs") >= 20;
        case 32: return DSMeta.Val(k, v, "curse20") > 0;
        }
        return DSMeta.Val(k, v, "runs") >= 100;
    }

    static int DoneCount(Array<String> k, Array<int> v)
    {
        int n = 0;
        for (int i = 0; i < COUNT; i++) if (Done(k, v, i)) n++;
        return n;
    }
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
        if (All()) return true;
        switch (c)
        {
        case 0: case 1: case 2: case 3: return true;
        case 4: return DSMeta.Val(k, v, "rank:40") >= 4;
        case 5: return DSMeta.Val(k, v, "rank:50") >= 4;
        case 6: return DSMeta.Val(k, v, "curse20") > 0;
        case 7: return DSMeta.Val(k, v, "rank:48") >= 7;
        case 8: return DSMeta.Val(k, v, "rank:46") >= 7;
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
        }
        return false;
    }

    static String CharacterCondition(Array<String> k, Array<int> v, int c)
    {
        switch (c)
        {
        case 4: return String.Format("Get Fire Wand to level 4 (best %d)", DSMeta.Val(k, v, "rank:40"));
        case 5: return String.Format("Get Lightning Ring to level 4 (best %d)", DSMeta.Val(k, v, "rank:50"));
        case 6: return "Survive 20 minutes with at least 10% Curse";
        case 7: return String.Format("Get Garlic to level 7 (best %d)", DSMeta.Val(k, v, "rank:48"));
        case 8: return String.Format("Get Santa Water to level 7 (best %d)", DSMeta.Val(k, v, "rank:46"));
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
        }
        return "";
    }

    // ---- Arcana (DSArcana numbers) -------------------------------------------------

    static bool ArcanaUnlocked(Array<String> k, Array<int> v, int n)
    {
        if (All()) return true;
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

    static bool StageUnlocked(Array<String> k, Array<int> v, int s)
    {
        if (All()) return true;
        switch (s)
        {
        case 0: return true;
        case 1: return DSMeta.Val(k, v, "lvl:0") >= 20;
        case 2: return DSMeta.Val(k, v, "lvl:1") >= 40;
        case 3: return DSMeta.Val(k, v, "lvl:2") >= 60;
        case 4: return DSMeta.Val(k, v, "lvl:3") >= 80;
        case 5: return Survived(k, v) >= 2;
        case 6: return Survived(k, v) >= 3;
        case 7: return Survived(k, v) >= 1;
        case 8: return Survived(k, v) >= 4;
        case 9: return Survived(k, v) >= 5;
        case 10: return DSMeta.Val(k, v, "oro") >= 20;
        case 11: return DSMeta.Val(k, v, "vac") >= 50;
        case 12: return DSMeta.Val(k, v, "chk") >= 500;
        case 13: return DSMeta.Val(k, v, "lvlmax") >= 60;
        case 14: return DSMeta.Val(k, v, "ros") >= 33;
        case 15: return DSMeta.Val(k, v, "clv") >= 23;
        case 16: return DSMeta.Val(k, v, "lvl:0") >= 80;
        case 17: return DSMeta.Val(k, v, "lvl:1") >= 80;
        case 18: return DSMeta.Val(k, v, "lvl:2") >= 80;
        case 19: return DSMeta.Val(k, v, "lvl:3") >= 80;
        case 20: return DSMeta.Val(k, v, "won:14") > 0;
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
        case 5: return String.Format("Survive 2 stages (%d) - stands in for Hyper mode", Survived(k, v));
        case 6: return String.Format("Survive 3 stages (%d) - stands in for Hyper mode", Survived(k, v));
        case 7: return String.Format("Survive 1 stage (%d) - stands in for Hyper mode", Survived(k, v));
        case 8: return String.Format("Survive 4 stages (%d) - stands in for Hyper mode", Survived(k, v));
        case 9: return String.Format("Survive 5 stages (%d) - stands in for Hyper mode", Survived(k, v));
        case 10: return String.Format("Collect 20 Orologions (%d)", DSMeta.Val(k, v, "oro"));
        case 11: return String.Format("Collect 50 Vacuums (%d)", DSMeta.Val(k, v, "vac"));
        case 12: return String.Format("Collect 500 Floor Chicken (%d)", DSMeta.Val(k, v, "chk"));
        case 13: return String.Format("Reach level 60 in any stage (best %d) - stands in for Gold Fingers", DSMeta.Val(k, v, "lvlmax"));
        case 14: return String.Format("Collect 33 Rosaries (%d)", DSMeta.Val(k, v, "ros"));
        case 15: return String.Format("Collect 23 Little Clovers (%d)", DSMeta.Val(k, v, "clv"));
        case 16: return String.Format("Reach level 80 in Mad Forest (best %d)", DSMeta.Val(k, v, "lvl:0"));
        case 17: return String.Format("Reach level 80 in Inlaid Library (best %d)", DSMeta.Val(k, v, "lvl:1"));
        case 18: return String.Format("Reach level 80 in Dairy Plant (best %d)", DSMeta.Val(k, v, "lvl:2"));
        case 19: return String.Format("Reach level 80 in Gallo Tower (best %d)", DSMeta.Val(k, v, "lvl:3"));
        case 20: return "Survive Laborratory";
        case 21: return String.Format("Defeat 1665 enemies in total (%d)", DSMeta.Val(k, v, "kills"));
        case 22: return String.Format("Play 15 runs (%d) - stands in for the Forbidden Scrolls spell", DSMeta.Val(k, v, "runs"));
        case 23: return String.Format("Survive 12 stages (%d) - stands in for the wiki quest", Survived(k, v));
        }
        return "";
    }
}
