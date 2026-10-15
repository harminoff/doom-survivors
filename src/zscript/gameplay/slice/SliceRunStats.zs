// Run stats (TODO step 4): character + PowerUps + passive items.
// Part of DSP030VerticalSlice (fields and core lifecycle live in
// gameplay/VerticalSlice.zs).

extend class DSP030VerticalSlice
{
    // ---- Run stats (TODO step 4) -------------------------------------------------
    // Character + PowerUps + passive items, recomputed every logical tic so
    // level-based character bonuses and new items apply at once.
    void RecomputeRunStats()
    {
        if (!rsActive) return;
        if (rsTotal == null) rsTotal = new("DSRunStatBlock");
        rsTotal.Clear();
        DSCharacters.Apply(rsCharacter, playerLevel, rsTotal);
        DSPowerUps.Apply(rsPowerUpRanks, rsTotal);
        DSEggs.Apply(rsEggs, rsTotal);
        for (int i = 0; i < dsp031ItemIds.Size(); i++)
            AddPassiveStats(dsp031ItemIds[i], dsp031ItemRanks[i], rsTotal);
        rsMightMilli = max(100, 1000 + rsTotal.might);
        rsCooldownMilli = max(100, 1000 + rsTotal.cooldown);
        rsAreaMilli = max(100, 1000 + rsTotal.area);
        rsSpeedMilli = max(100, 1000 + rsTotal.speed);
        rsDurationMilli = max(100, 1000 + rsTotal.duration);
        rsMoveMilli = max(100, 1000 + rsTotal.move);
        rsMagnetMilli = max(100, 1000 + rsTotal.magnet);
        rsLuckMilli = max(100, 1000 + rsTotal.luck);
        rsGrowthMilli = max(100, 1000 + rsTotal.growth);
        rsGreedMilli = max(100, 1000 + rsTotal.greed);
        rsCurseMilli = max(100, 1000 + rsTotal.curse);
        rsAmount = max(0, rsTotal.amount);
        rsArmor = max(0, rsTotal.armor);
        rsRecoveryMilli = max(0, rsTotal.recovery);
        rsRevivalsGranted = max(0, rsTotal.revival);
        rsMaxHealthMilli = max(1000, DSCharacters.MaxHealth(rsCharacter) * max(100, 1000 + rsTotal.maxHealthPct));
        rsCharm = max(0, rsTotal.charm);
        rsInvulnTics = max(0, rsTotal.invulnTics);
        rsFeverPct = max(0, rsTotal.feverPct);
        rsDefangPct = clamp(rsTotal.defang, 0, 100);
        dsp031PreservePct = clamp(rsTotal.preserve, 0, 90);
        rsLuckMilli += 100 * mfClovers;   // Little Clovers
        if (rsMode == 1) rsLuckMilli += 100;   // Hyper
        ArcanaAdjustStats();
        dsp031LuckMilli = clamp(rsTotal.luck + 100 * mfClovers, 0, 100000);
        if (playerSlot >= 0 && playerSlot < health.Size() && playerHealth > rsMaxHealthMilli)
        {
            playerHealth = CurrentPlayerHealthCap();
            health[playerSlot] = playerHealth;
        }
        let pawn = DSP021FirstPersonPlayer(players[0].mo);
        if (pawn != null) pawn.moveScale = rsMoveMilli / 1000.0 * (rsMode == 1 ? 1.5 : 1.0) * DSStage.PlayerSpeedMilli(mfStage) / 1100.0;
    }

    // Passive item effects per rank (wiki approximations; percent stats are
    // milli deltas). Attractorb's first rank is +50%, later ranks +25%.
    static void AddPassiveStats(int id, int rank, DSRunStatBlock s)
    {
        if (rank <= 0) return;
        switch (id)
        {
        case DSN2Catalog.ID_SPINACH: s.might += 100 * rank; break;
        case DSN2Catalog.ID_ARMOR: s.armor += rank; break;
        case DSN2Catalog.ID_HOLLOW_HEART: s.maxHealthPct += 200 * rank; break;
        case DSN2Catalog.ID_PUMMAROLA: s.recovery += 200 * rank; break;
        case DSN2Catalog.ID_EMPTY_TOME: s.cooldown -= 80 * rank; break;
        case DSN2Catalog.ID_CANDELABRADOR: s.area += 100 * rank; break;
        case DSN2Catalog.ID_BRACER: s.speed += 100 * rank; break;
        case DSN2Catalog.ID_SPELLBINDER: s.duration += 100 * rank; break;
        case DSN2Catalog.ID_DUPLICATOR: s.amount += rank; break;
        case DSN2Catalog.ID_ATTRACTORB: s.magnet += 500 + 250 * (rank - 1); break;
        case DSN2Catalog.ID_CLOVER: s.luck += 100 * rank; break;
        case DSN2Catalog.ID_CROWN: s.growth += 80 * rank; break;
        case DSN2Catalog.ID_TIRAJISU: s.revival += rank; break;
        case DSN2Catalog.ID_N3_WINGS: s.move += 100 * rank; break;
        case DSN2Catalog.ID_N3_STONE_MASK: s.greed += 100 * rank; break;
        case DSN2Catalog.ID_N3_SKULL_O_MANIAC: s.curse += 100 * rank; break;
        case DSN2Catalog.ID_N3_SILVER_RING: s.duration += 50 * rank; s.area += 50 * rank; break;
        case DSN2Catalog.ID_N3_METAGLIO_LEFT: s.recovery += 100 * rank; s.maxHealthPct += 50 * rank; break;
        case DSN2Catalog.ID_N3_METAGLIO_RIGHT: s.curse += 50 * rank; break;
        case DSN2Catalog.ID_N3_TORRONA_S_BOX:
        {
            // +4% Might/Speed/Duration/Area per level up to 8; level 9 adds +100% Curse.
            int boxed = min(rank, 8);
            s.might += 40 * boxed; s.speed += 40 * boxed; s.duration += 40 * boxed; s.area += 40 * boxed;
            if (rank >= 9) s.curse += 1000;
            break;
        }
        case DSN2Catalog.ID_N3_PARM_AEGIS: s.invulnTics += (rank * 7 + 2) / 4; break;   // ~50 ms (1.75 tics) per level
        case DSN2Catalog.ID_N3_KAROMA_S_MANA: s.charm += 10 * rank; s.feverPct += 10 * rank; break;
        }
    }

    double AttractRadius()
    {
        return rsActive ? ATTRACT_RADIUS * rsMagnetMilli / 1000.0 : ATTRACT_RADIUS;
    }

    void RevivePlayer()
    {
        rsRevivalsUsed++;
        Sfx(DSSfx.REVIVE);
        ArcanaOnRevive();
        int cap = CurrentPlayerHealthCap();
        int healthAfter; int appliedMilli;
        DSP039ApplyHeal(SOURCE_REVIVAL, cap / 2, tic, true, playerHealth, cap,
            healthAfter, appliedMilli);
        playerHealth = healthAfter;
        health[playerSlot] = playerHealth;
        playerInvulnerableUntil = tic + 70;
        Console.Printf("DS_REVIVAL tic=%d used=%d granted=%d health_after=%d", tic, rsRevivalsUsed, rsRevivalsGranted, playerHealth);
    }
}
