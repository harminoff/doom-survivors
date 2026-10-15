// Shared on-hit effects used by several weapon engines: knockback and
// critical hits. Normal play only; fields live in gameplay/VerticalSlice.zs
// (kb* / critRng).

extend class DSP030VerticalSlice
{
    // A Knockback 1 hit pushes a normal enemy about KB_DISTANCE units over
    // KB_TICS tics (wiki approximation); it does not chase while pushed.
    const KB_TICS = 4;
    const KB_DISTANCE = 16.0;

    void KbReset()
    {
        kbUntil.Clear(); kbId.Clear(); kbVX.Clear(); kbVY.Clear();
        critRng = 5180417;
        tallyKeys.Clear(); tallyCounts.Clear();
    }

    // End-of-run tallies of on-hit effects (DS_FX_COUNT), so automated runs
    // can tell an effect actually fired.
    void FxCount(String key, int amount = 1)
    {
        int i = tallyKeys.Find(key);
        if (i >= tallyKeys.Size()) { tallyKeys.Push(key); tallyCounts.Push(amount); }
        else tallyCounts[i] += amount;
    }

    void FxLogCounts()
    {
        for (int i = 0; i < tallyKeys.Size(); i++)
            Console.Printf("DS_FX_COUNT effect=%s count=%d", tallyKeys[i], tallyCounts[i]);
    }

    // Pushes a living enemy away from (fromX, fromY). knockbackMilli is the
    // weapon's Knockback (1000 = 1x); the enemy's wiki knockback multiplier
    // scales it (0 = immune, negative = pulled in). Bosses, the Reaper, props,
    // path movers and frozen enemies are not moved.
    void EnemyKnockback(int slot, double fromX, double fromY, int knockbackMilli)
    {
        if (knockbackMilli == 0 || slot < 0 || slot >= lifeStates.Size()) return;
        if (lifeStates[slot] != STORE_ALIVE || kinds[slot] != KIND_ENEMY || health[slot] <= 0) return;
        int resist = 1000;
        if (mfEnabled && MFValid(slot))
        {
            if (MFIsProp(mfTypes[slot]) || mfBoss[slot] > 0 || DSStage.IsReaperLike(mfTypes[slot])
                || mfMotion[slot] != 0) return;
            resist = DSStage.KnockbackMilli(mfTypes[slot]);
        }
        if (resist == 0 || GwFrozen(slot)) return;
        double dx = x[slot] - fromX; double dy = y[slot] - fromY;
        double d = sqrt(dx * dx + dy * dy);
        if (d < 0.001) { dx = 1.0; dy = 0.0; d = 1.0; }
        double step = KB_DISTANCE * knockbackMilli / 1000.0 * resist / 1000.0 / KB_TICS;
        while (kbUntil.Size() <= slot) { kbUntil.Push(0); kbId.Push(0); kbVX.Push(0); kbVY.Push(0); }
        kbUntil[slot] = tic + KB_TICS; kbId[slot] = ids[slot];
        kbVX[slot] = dx / d * step; kbVY[slot] = dy / d * step;
        FxCount("knockback");
    }

    // MoveEnemies: moves a pushed enemy one step; true while it is pushed.
    bool KnockbackStep(int slot)
    {
        if (slot >= kbUntil.Size() || kbUntil[slot] <= tic || kbId[slot] != ids[slot]) return false;
        x[slot] += kbVX[slot]; y[slot] += kbVY[slot];
        return true;
    }

    // Per active tic in normal play (before chests): movement tracking for
    // move-dependent weapons, plus the automated-run screenshot hook.
    void EffectsTick()
    {
        if (abs(playerX - fxLastX) > 0.05 || abs(playerY - fxLastY) > 0.05) fxMoveTic = tic;
        fxLastX = playerX; fxLastY = playerY;
        DebugShots();
    }

    bool PlayerMoving() { return tic - fxMoveTic <= 2; }

    // Automated runs only: ds_debug_shot_tics (comma-separated tics) saves a
    // screenshot at each, for checking weapon visuals. Ignored in manual play.
    void DebugShots()
    {
        if (configuredMode == "manual") return;
        CVar list = CVar.FindCVar("ds_debug_shot_tics");
        if (list == null || list.GetString() == "") return;
        Array<String> parts;
        list.GetString().Split(parts, ",", TOK_SKIPEMPTY);
        for (int i = 0; i < parts.Size(); i++)
            if (parts[i].ToInt() == tic) LevelLocals.MakeScreenShot();
    }

    // Every critical hit, from any weapon, lands here.
    void OnCrit(double px, double py, int system)
    {
        if (rsActive) GwOnCrit(px, py, system);
    }

    // Critical hit roll for weapons that can crit. chanceMilli is out of 1000;
    // Luck multiplies it the way the wiki describes for most crit weapons.
    bool RollCrit(int chanceMilli, bool luckScaled = true)
    {
        bool crit = RollChance(chanceMilli, luckScaled);
        if (crit) { FxCount("crit"); Sfx(DSSfx.H_CRIT, 4); }
        return crit;
    }

    // Shared on-hit chance roll (out of 1000), optionally scaled by Luck.
    bool RollChance(int chanceMilli, bool luckScaled = true)
    {
        if (chanceMilli <= 0) return false;
        if (luckScaled && rsActive) chanceMilli = chanceMilli * rsLuckMilli / 1000;
        critRng = DSP025NextAttackRng(critRng == 0 ? 5180417 : critRng);
        return (critRng & 0x7fffffff) % 1000 < chanceMilli;
    }
}
