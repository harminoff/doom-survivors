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
        rsCooldownMilli = mfGoldFingerUntil > tic ? 100 : max(100, 1000 + rsTotal.cooldown);
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
        rsMaxHealthMilli = max(1000, DSCharacters.MaxHealth(rsCharacter) * max(100, 1000 + rsTotal.maxHealthPct)) + rsBonusHealthMilli;
        rsCharm = max(0, rsTotal.charm);
        rsInvulnTics = max(0, rsTotal.invulnTics);
        rsFeverPct = max(0, rsTotal.feverPct);
        rsDefangPct = clamp(rsTotal.defang, 0, 100);
        dsp031PreservePct = clamp(rsTotal.preserve, 0, 90);
        rsLuckMilli += 100 * mfClovers;   // Little Clovers
        if (rsMode == 1) { rsLuckMilli += DSStage.HyperLuckMilli(mfStage); rsSpeedMilli += DSStage.HyperProjectileMilli(mfStage); }
        if (rsMode == 2) rsLuckMilli += 200;
        CharacterSpecialStats();
        ArcanaAdjustStats();
        dsp031LuckMilli = clamp(rsTotal.luck + 100 * mfClovers, 0, 100000);
        if (playerSlot >= 0 && playerSlot < health.Size() && playerHealth > rsMaxHealthMilli)
        {
            playerHealth = CurrentPlayerHealthCap();
            health[playerSlot] = playerHealth;
        }
        let pawn = DSP021FirstPersonPlayer(players[0].mo);
        if (pawn != null) pawn.moveScale = rsMoveMilli / 1000.0 * (rsMode == 1 ? 1.0 + DSStage.HyperPlayerMilli(mfStage) / 1000.0 : 1.0) * DSStage.PlayerSpeedMilli(mfStage) / 1100.0;
    }

    // Character abilities that need run state (Characters.Apply only sees the
    // level). Swing sizes and bonus steps are guesses; the original gives none.
    void CharacterSpecialStats()
    {
        rsGrowSystem = 0; rsGrowMilli = 0;
        if (DSCharacters.StarterGrows(rsCharacter))
        {
            rsGrowSystem = DSCharacters.StartingWeapon(rsCharacter);
            rsGrowMilli = 10 * max(0, playerLevel - 1);
        }
        // Bats Bats: Revivals left also count as Amount.
        if (rsCharacter == DSCharacters.BATS) rsAmount += max(0, rsRevivalsGranted - rsRevivalsUsed);
        // Minnah Mannarah: Might, Speed, Duration, Area and Cooldown each swing
        // between -25% and +25% every minute.
        if (rsCharacter == DSCharacters.MINNAH)
        {
            int minute = MfT() / 2100;
            if (minute != mnMinute || mnSwing.Size() < 5)
            {
                mnMinute = minute; mnSwing.Clear();
                for (int i = 0; i < 5; i++) mnSwing.Push(Random[DSRunSeed](-250, 250));
            }
            rsMightMilli = max(100, rsMightMilli + mnSwing[0]);
            rsSpeedMilli = max(100, rsSpeedMilli + mnSwing[1]);
            rsDurationMilli = max(100, rsDurationMilli + mnSwing[2]);
            rsAreaMilli = max(100, rsAreaMilli + mnSwing[3]);
            rsCooldownMilli = max(100, rsCooldownMilli - mnSwing[4]);
        }
        // Gazebo: every 30 HP healed past full adds +2% to a random stat.
        if (rsCharacter == DSCharacters.GAZEBO)
        {
            while (gzBonus.Size() < 7) gzBonus.Push(0);
            while (gzOverhealMilli >= 30000)
            {
                gzOverhealMilli -= 30000;
                gzBonus[Random[DSRunSeed](0, 6)] += 20;
                FxCount("overheal_bonus");
            }
            rsMightMilli += gzBonus[0]; rsAreaMilli += gzBonus[1]; rsSpeedMilli += gzBonus[2];
            rsDurationMilli += gzBonus[3]; rsCooldownMilli = max(100, rsCooldownMilli - gzBonus[4] / 2);
            rsLuckMilli += gzBonus[5]; rsGrowthMilli += gzBonus[6];
        }
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
        // The rings and Metaglio give nothing at level 1; +5% per level from level 2.
        case DSN2Catalog.ID_N3_SILVER_RING: s.duration += 50 * (rank - 1); s.area += 50 * (rank - 1); break;
        case DSN2Catalog.ID_N3_GOLD_RING: s.curse += 50 * (rank - 1); break;
        case DSN2Catalog.ID_N3_METAGLIO_LEFT: s.recovery += 100 * (rank - 1); s.maxHealthPct += 50 * (rank - 1); break;
        case DSN2Catalog.ID_N3_METAGLIO_RIGHT: s.curse += 50 * (rank - 1); break;
        case DSN2Catalog.ID_N3_TORRONA_S_BOX:
        {
            // Might/Speed/Duration/Area +4% at level 1, +3% per level 2-8; level 9 adds +100% Curse.
            int boxed = 40 + 30 * (min(rank, 8) - 1);
            s.might += boxed; s.speed += boxed; s.duration += boxed; s.area += boxed;
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
