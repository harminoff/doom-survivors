// Run-side meta progression (see gameplay/meta/Meta.zs): counts kills and
// pickups during a run and merges them into the ds_meta profile when the run
// ends, then reports what that run unlocked.

extend class DSP030VerticalSlice
{
    void MetaRunReset()
    {
        metaTypeKills.Clear();
        metaOro = 0; metaVac = 0; metaRos = 0; metaChk = 0; metaClv = 0;
        metaLsrc = 0; metaMaxWeapons = 0; metaMaxEvos = 0; metaReaperKilled = false;
        metaGoldFingers = 0; metaTrainHits = 0;
        MetaLoadLockedItems();
        metaNewUnlocks = "";
    }

    void MetaCountKill(int type)
    {
        if (type <= 0 || type > DSStage.ENEMY_TYPE_COUNT) return;
        while (metaTypeKills.Size() <= type) metaTypeKills.Push(0);
        metaTypeKills[type]++;
    }

    void MetaCountPickup(int kind)
    {
        if (kind == MF_ITEM_OROLOGION) metaOro++;
        else if (kind == MF_ITEM_VACUUM) metaVac++;
        else if (kind == MF_ITEM_ROSARY) metaRos++;
        else if (kind == MF_ITEM_CHICKEN) metaChk++;
        else if (kind == MF_ITEM_LITTLE_CLOVER) metaClv++;
        else if (kind == MF_ITEM_GOLD_FINGER) metaGoldFingers++;
    }

    // Manual play drafts only unlocked items (DSUnlocks.ItemUnlocked); automated
    // runs keep everything so the harnesses keep their coverage.
    void MetaLoadLockedItems()
    {
        dsp031LockedIds.Clear();
        if (configuredMode != "manual") return;
        Array<String> k; Array<int> v;
        DSMeta.Load(k, v);
        Array<int> ids;
        DSN2Catalog.DraftableIds(ids);
        for (int i = 0; i < ids.Size(); i++)
            if (!DSUnlocks.ItemUnlocked(k, v, ids[i]) || DSMeta.Val(k, v, String.Format("seal:%d", ids[i])) > 0)
                dsp031LockedIds.Push(ids[i]);
    }

    // Most weapons and evolutions held at once (two achievements need six).
    void MetaTrackLoadout()
    {
        int weapons = 0; int evos = 0;
        for (int i = 0; i < dsp031ItemIds.Size(); i++)
        {
            if (DSN2Catalog.Category(dsp031ItemIds[i]) != DSN2Catalog.CATEGORY_WEAPON) continue;
            weapons++;
            if (DSAchievements.IsEvolution(dsp031ItemIds[i])) evos++;
        }
        metaMaxWeapons = max(metaMaxWeapons, weapons);
        metaMaxEvos = max(metaMaxEvos, evos);
    }

    String MetaUnlockedList(Array<String> k, Array<int> v)
    {
        String text = "";
        Array<int> ids;
        DSN2Catalog.DraftableIds(ids);
        for (int i = 0; i < ids.Size(); i++)
            if (DSUnlocks.ItemUnlocked(k, v, ids[i])) text = text .. "w" .. String.Format("%d", ids[i]) .. ",";
        for (int p = 0; p < DSPowerUps.Count(); p++)
            if (DSUnlocks.PowerUpUnlocked(k, v, p)) text = text .. "p" .. String.Format("%d", p) .. ",";
        for (int c = 0; c < DSCharacters.Count(); c++)
            if (DSUnlocks.CharacterUnlocked(k, v, c)) text = text .. "c" .. String.Format("%d", c) .. ",";
        for (int s = 0; s < DSStage.STAGE_COUNT; s++)
            if (DSUnlocks.StageUnlocked(k, v, s)) text = text .. "s" .. String.Format("%d", s) .. ",";
        for (int a = 1; a <= 22; a++)
            if (DSUnlocks.ArcanaUnlocked(k, v, a)) text = text .. "a" .. String.Format("%d", a) .. ",";
        return text;
    }

    void MetaCommitRun(String reason)
    {
        if (!mfEnabled || !rsActive) return;
        Array<String> keys; Array<int> vals;
        DSMeta.Load(keys, vals);
        String before = MetaUnlockedList(keys, vals);
        bool survived = reason != "PLAYER_ZERO_HEALTH" && (tic >= RunEndTic() || reason == "DUNGEON_ESCAPE");
        DSMeta.Bump(keys, vals, "runs", 1);
        DSMeta.Bump(keys, vals, "kills", kills);
        DSMeta.Bump(keys, vals, "gold", mfGold);
        DSMeta.Best(keys, vals, "maxgold", mfGold);
        DSMeta.Bump(keys, vals, "oro", metaOro);
        DSMeta.Bump(keys, vals, "vac", metaVac);
        DSMeta.Bump(keys, vals, "ros", metaRos);
        DSMeta.Bump(keys, vals, "chk", metaChk);
        DSMeta.Bump(keys, vals, "clv", metaClv);
        DSMeta.Best(keys, vals, String.Format("lvl:%d", mfStage), playerLevel);
        DSMeta.Best(keys, vals, "lvlmax", playerLevel);
        DSMeta.Best(keys, vals, String.Format("chl:%d", rsCharacter), playerLevel);
        DSMeta.Best(keys, vals, String.Format("mnt:%d", mfStage), MfT() / 2100);
        if (survived) DSMeta.SetVal(keys, vals, String.Format("won:%d", mfStage), 1);
        if (survived && rsMode == 2) DSMeta.SetVal(keys, vals, String.Format("winv:%d", mfStage), 1);
        if (rsMode == 2) DSMeta.Best(keys, vals, String.Format("lvinv:%d", mfStage), playerLevel);
        DSMeta.Bump(keys, vals, "gfn", metaGoldFingers);
        DSMeta.Bump(keys, vals, "train", metaTrainHits);
        if (metaReaperKilled) DSMeta.SetVal(keys, vals, "reaper", 1);
        if (survived && MfT() >= 42000 && rsCurseMilli >= 1100) DSMeta.SetVal(keys, vals, "curse20", 1);
        int seconds = MfT() / 35;
        DSMeta.Best(keys, vals, String.Format("srv:%d", rsCharacter), seconds);
        DSMeta.Best(keys, vals, "srvmax", seconds);
        DSMeta.Bump(keys, vals, "heal", dsp039HealAppliedMilli / 1000);
        DSMeta.Bump(keys, vals, "lsrc", metaLsrc);
        DSMeta.Best(keys, vals, "maxkills", kills);
        MetaTrackLoadout();
        if (metaMaxWeapons >= 6) DSMeta.SetVal(keys, vals, "wpn6", 1);
        if (metaMaxEvos >= 6) DSMeta.SetVal(keys, vals, "evo6", 1);
        for (int t = 1; t < metaTypeKills.Size(); t++)
            if (metaTypeKills[t] > 0) DSMeta.Bump(keys, vals, String.Format("ek:%d", t), metaTypeKills[t]);
        for (int i = 0; i < dsp031ItemIds.Size(); i++)
        {
            DSMeta.Best(keys, vals, String.Format("rank:%d", dsp031ItemIds[i]), dsp031ItemRanks[i]);
            DSMeta.SetVal(keys, vals, String.Format("seen:%d", dsp031ItemIds[i]), 1);
        }
        for (int i = 0; i < arOwned.Size(); i++) DSMeta.SetVal(keys, vals, String.Format("arc:%d", arOwned[i]), 1);
        if (rsSole) DSMeta.SetVal(keys, vals, String.Format("seen:%d", DSN2Catalog.ID_N3_SOLE_SOLUTION), 1);
        if (rsCandy2) DSMeta.SetVal(keys, vals, String.Format("seen:%d", DSN2Catalog.ID_N3_CANDYBOX2), 1);
        // Gold prizes, paid once each.
        int prize = 0;
        for (int i = 0; i < DSAchievementData.COUNT; i++)
        {
            if (DSAchievementData.REWARD_KIND[i] != DSAchievements.R_GOLD) continue;
            String claimed = String.Format("ach:%d", i);
            if (DSMeta.Val(keys, vals, claimed) > 0 || !DSAchievements.Done(keys, vals, i)) continue;
            DSMeta.SetVal(keys, vals, claimed, 1);
            prize += DSAchievementData.REWARD[i];
        }
        if (prize > 0) DSPowerUps.AddGold(prize);
        String after = MetaUnlockedList(keys, vals);
        DSMeta.Store(keys, vals);
        // What this run unlocked, for the results screen.
        metaNewUnlocks = "";
        Array<String> parts;
        after.Split(parts, ",", TOK_SKIPEMPTY);
        for (int i = 0; i < parts.Size(); i++)
        {
            if (before.IndexOf(parts[i] .. ",") >= 0) continue;
            int n = parts[i].Mid(1).ToInt();
            String tag = parts[i].Left(1);
            String label = tag == "c" ? DSCharacters.Name(n)
                : (tag == "a" ? "Arcana " .. DSArcana.Name(n)
                : (tag == "w" ? DSN2Catalog.DisplayName(n)
                : (tag == "p" ? "PowerUp " .. DSPowerUps.Name(n) : DSStage.Name(n))));
            metaNewUnlocks = metaNewUnlocks.Length() > 0 ? metaNewUnlocks .. ", " .. label : label;
        }
        if (prize > 0) metaNewUnlocks = metaNewUnlocks.Length() > 0 ? metaNewUnlocks .. String.Format(", %d gold", prize) : String.Format("%d gold", prize);
        Console.Printf("DS_META_COMMIT runs=%d kills=%d survived=%d new_unlocks=%s", DSMeta.Val(keys, vals, "runs"), DSMeta.Val(keys, vals, "kills"), survived, metaNewUnlocks.Length() > 0 ? metaNewUnlocks : "none");
    }
}
