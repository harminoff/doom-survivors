// Run-side meta progression (see gameplay/meta/Meta.zs): counts kills and
// pickups during a run and merges them into the ds_meta profile when the run
// ends, then reports what that run unlocked.

extend class DSP030VerticalSlice
{
    void MetaRunReset()
    {
        metaTypeKills.Clear();
        metaOro = 0; metaVac = 0; metaRos = 0; metaChk = 0; metaClv = 0;
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
    }

    String MetaUnlockedList(Array<String> k, Array<int> v)
    {
        String text = "";
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
        if (survived && MfT() >= 42000 && rsCurseMilli >= 1100) DSMeta.SetVal(keys, vals, "curse20", 1);
        for (int t = 1; t < metaTypeKills.Size(); t++)
            if (metaTypeKills[t] > 0) DSMeta.Bump(keys, vals, String.Format("ek:%d", t), metaTypeKills[t]);
        for (int i = 0; i < dsp031ItemIds.Size(); i++)
        {
            DSMeta.Best(keys, vals, String.Format("rank:%d", dsp031ItemIds[i]), dsp031ItemRanks[i]);
            DSMeta.SetVal(keys, vals, String.Format("seen:%d", dsp031ItemIds[i]), 1);
        }
        for (int i = 0; i < arOwned.Size(); i++) DSMeta.SetVal(keys, vals, String.Format("arc:%d", arOwned[i]), 1);
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
            String label = parts[i].Left(1) == "c" ? DSCharacters.Name(n)
                : (parts[i].Left(1) == "a" ? "Arcana " .. DSArcana.Name(n) : DSStage.Name(n));
            metaNewUnlocks = metaNewUnlocks.Length() > 0 ? metaNewUnlocks .. ", " .. label : label;
        }
        Console.Printf("DS_META_COMMIT runs=%d kills=%d survived=%d new_unlocks=%s", DSMeta.Val(keys, vals, "runs"), DSMeta.Val(keys, vals, "kills"), survived, metaNewUnlocks.Length() > 0 ? metaNewUnlocks : "none");
    }
}
