// PowerUp shop (TODO step 4): permanent stat ranks bought with gold between
// runs. Values and prices are Vampire Survivors wiki approximations
// (vampire.survivors.wiki/w/PowerUps, retrieved 2026-09-28). Max Health and
// Magnet stack additively here (the wiki's compounding is not modelled).
// Reroll, Skip and Banish give +2 level-up charges per rank (wiki). Charm
// (+20 enemies per wave per rank), Defang (3% of enemies harmless per rank) and
// Preserve (10% chance per rank to keep a used Reroll/Skip/Banish) are built;
// their wiki unlock quests are ignored and Defang's price is a guess. The Seal
// PowerUps are not built.
//
// Ranks live in the ds_powerups cvar ("might=2,armor=1,..."); gold lives in
// the hashed ds_p030_profile_payload, rewritten here when gold is spent.

class DSPowerUps
{
    enum EPowerUp
    {
        MIGHT, ARMOR, MAX_HEALTH, RECOVERY, COOLDOWN, AREA, SPEED, DURATION,
        AMOUNT, MOVE, MAGNET, LUCK, GROWTH, GREED, CURSE, REVIVAL, OMNI,
        REROLL, SKIP, BANISH, CHARM, DEFANG, PRESERVE,
        NUM_POWERUPS
    }

    static const String NAMES[] = {
        "Might", "Armor", "Max Health", "Recovery", "Cooldown", "Area",
        "Speed", "Duration", "Amount", "Move Speed", "Magnet", "Luck",
        "Growth", "Greed", "Curse", "Revival", "Omni",
        "Reroll", "Skip", "Banish", "Charm", "Defang", "Preserve"
    };
    static const String KEYS[] = {
        "might", "armor", "maxhealth", "recovery", "cooldown", "area",
        "speed", "duration", "amount", "move", "magnet", "luck",
        "growth", "greed", "curse", "revival", "omni",
        "reroll", "skip", "banish", "charm", "defang", "preserve"
    };
    static const String EFFECTS[] = {
        "+5% damage per rank", "-1 incoming damage per rank", "+10% Max Health per rank",
        "+0.1 HP per second per rank", "-2.5% weapon cooldown per rank", "+5% attack area per rank",
        "+10% projectile speed per rank", "+15% weapon duration per rank", "+1 projectile (all weapons)",
        "+5% move speed per rank", "+25% pickup range per rank", "+10% luck per rank",
        "+3% experience per rank", "+10% gold per rank", "+10% enemy speed, health and spawns per rank",
        "Revive once with 50% health", "+2% Might, Speed, Duration and Area per rank",
        "+2 level-up rerolls per rank", "+2 level-up skips per rank (skipping gives XP)",
        "+2 level-up banishes per rank", "+20 enemies per wave per rank",
        "+3% of enemies cannot hurt you per rank", "+10% chance to keep a used Reroll/Skip/Banish per rank"
    };
    static const int MAX_RANKS[] = { 5, 3, 3, 5, 2, 2, 2, 2, 1, 2, 2, 3, 5, 5, 5, 1, 5, 5, 5, 5, 5, 5, 5 };
    static const int PRICES[] = { 200, 600, 200, 200, 900, 300, 300, 300, 5000, 600, 300, 600, 900, 200, 1666, 10000, 1000, 1000, 100, 100, 10000, 1000, 500 };

    static int Count() { return NUM_POWERUPS; }
    static String Name(int p) { return DSPowerUps.NAMES[p]; }
    static String Effect(int p) { return DSPowerUps.EFFECTS[p]; }
    static int MaxRank(int p) { return DSPowerUps.MAX_RANKS[p]; }

    // ---- ranks ---------------------------------------------------------------

    static void Load(out Array<int> ranks)
    {
        ranks.Clear();
        for (int p = 0; p < NUM_POWERUPS; p++) ranks.Push(0);
        CVar store = CVar.FindCVar("ds_powerups");
        String text = store != null ? store.GetString() : "";
        Array<String> parts;
        text.Split(parts, ",", TOK_SKIPEMPTY);
        for (int i = 0; i < parts.Size(); i++)
        {
            int eq = parts[i].IndexOf("=");
            if (eq <= 0) continue;
            String key = parts[i].Left(eq);
            int value = parts[i].Mid(eq + 1).ToInt();
            for (int p = 0; p < NUM_POWERUPS; p++)
                if (DSPowerUps.KEYS[p] == key) ranks[p] = clamp(value, 0, DSPowerUps.MAX_RANKS[p]);
        }
    }

    static String Serialize(Array<int> ranks)
    {
        String text = "";
        for (int p = 0; p < NUM_POWERUPS; p++)
        {
            if (ranks[p] <= 0) continue;
            if (text.Length() > 0) text.AppendFormat(",");
            text.AppendFormat("%s=%d", DSPowerUps.KEYS[p], ranks[p]);
        }
        return text;
    }

    static int TotalBought(Array<int> ranks)
    {
        int total = 0;
        for (int p = 0; p < NUM_POWERUPS; p++) total += ranks[p];
        return total;
    }

    // Wiki formula: InitialPrice * (1 + Bought) + floor(20 * 1.1^TotalBought),
    // with no fee before the first purchase.
    static int Price(Array<int> ranks, int p)
    {
        int total = TotalBought(ranks);
        int fee = total == 0 ? 0 : int(20.0 * (1.1 ** total));
        return DSPowerUps.PRICES[p] * (1 + ranks[p]) + fee;
    }

    // Adds the bought ranks' effect to s.
    static void Apply(Array<int> ranks, DSRunStatBlock s)
    {
        if (ranks.Size() < NUM_POWERUPS) return;
        s.might += 50 * ranks[MIGHT] + 20 * ranks[OMNI];
        s.armor += ranks[ARMOR];
        s.maxHealthPct += 100 * ranks[MAX_HEALTH];
        s.recovery += 100 * ranks[RECOVERY];
        s.cooldown -= 25 * ranks[COOLDOWN];
        s.area += 50 * ranks[AREA] + 20 * ranks[OMNI];
        s.speed += 100 * ranks[SPEED] + 20 * ranks[OMNI];
        s.duration += 150 * ranks[DURATION] + 20 * ranks[OMNI];
        s.amount += ranks[AMOUNT];
        s.move += 50 * ranks[MOVE];
        s.magnet += 250 * ranks[MAGNET];
        s.luck += 100 * ranks[LUCK];
        s.growth += 30 * ranks[GROWTH];
        s.greed += 100 * ranks[GREED];
        s.curse += 100 * ranks[CURSE];
        s.revival += ranks[REVIVAL];
        s.charm += 20 * ranks[CHARM];
        s.defang += 3 * ranks[DEFANG];
        s.preserve += 10 * ranks[PRESERVE];
    }

    // Level-up charges at run start: +2 per rank (wiki).
    static int Charges(Array<int> ranks, int p)
    {
        return ranks.Size() > p ? 2 * ranks[p] : 0;
    }

    // ---- gold (shared profile payload) ----------------------------------------

    static int ProfileHash(int totalCurrency, int nextRun, int amount, int keyRun)
    {
        int hash = 216613626;
        hash = hash * 31 + 1; // profile schema
        hash = hash * 31 + totalCurrency;
        hash = hash * 31 + nextRun;
        hash = hash * 31 + amount;
        hash = hash * 31 + keyRun;
        return hash;
    }

    static int Gold()
    {
        CVar payload = CVar.FindCVar("ds_p030_profile_payload");
        String text = payload != null ? payload.GetString() : "";
        int at = text.IndexOf("currency=");
        return at < 0 ? 0 : text.Mid(at + 9).ToInt();
    }

    // Adds delta gold to the profile, keeping its run cursor. Fails (and
    // changes nothing) if the balance would go negative.
    static bool AddGold(int delta)
    {
        CVar payload = CVar.FindCVar("ds_p030_profile_payload");
        if (payload == null) return false;
        Array<String> parts;
        payload.GetString().Split(parts, ";");
        int currency = 0; int nextRun = 1; String lastKey = ""; int lastAmount = 0;
        if (parts.Size() == 6 && parts[0] == "v1")
        {
            currency = parts[1].Mid(9).ToInt();
            nextRun = parts[2].Mid(12).ToInt();
            lastKey = parts[3].Mid(9);
            lastAmount = parts[4].Mid(12).ToInt();
        }
        if (currency + delta < 0) return false;
        currency += delta;
        int keyRun = 0;
        int resultsAt = lastKey.IndexOf(":results");
        if (lastKey.IndexOf("run:") == 0 && resultsAt >= 5) keyRun = lastKey.Mid(4, resultsAt - 4).ToInt();
        payload.SetString(String.Format("v1;currency=%d;next_run_id=%d;last_key=%s;last_amount=%d;hash=%d",
            currency, nextRun, lastKey, lastAmount, ProfileHash(currency, nextRun, lastAmount, keyRun)));
        return true;
    }

    // Buys one rank if affordable.
    static bool Buy(int p)
    {
        Array<int> ranks;
        Load(ranks);
        if (p < 0 || p >= NUM_POWERUPS || ranks[p] >= DSPowerUps.MAX_RANKS[p]) return false;
        CVar store = CVar.FindCVar("ds_powerups");
        if (store == null || !AddGold(-Price(ranks, p))) return false;
        ranks[p]++;
        store.SetString(Serialize(ranks));
        CVar.SaveConfig();
        return true;
    }

    // Refunds every rank: base costs plus the fees paid, which depend only on
    // the running purchase count, so the order of purchase does not matter.
    static int Refund()
    {
        Array<int> ranks;
        Load(ranks);
        int refund = 0; int total = 0;
        for (int p = 0; p < NUM_POWERUPS; p++)
        {
            for (int r = 0; r < ranks[p]; r++)
            {
                int fee = total == 0 ? 0 : int(20.0 * (1.1 ** total));
                refund += DSPowerUps.PRICES[p] * (1 + r) + fee;
                total++;
            }
        }
        CVar store = CVar.FindCVar("ds_powerups");
        if (refund == 0 || store == null || !AddGold(refund)) return 0;
        store.SetString("");
        CVar.SaveConfig();
        return refund;
    }
}
