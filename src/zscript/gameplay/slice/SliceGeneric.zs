// Generic weapon engine (TODO step 5/6): runs every weapon listed in
// DSGenericWeaponDefs through one set of behaviour modes, using the same
// checked-hit and enemy-death path as the Whip. Normal play only.
// Fields live in gameplay/VerticalSlice.zs (gw* / ge*).

extend class DSP030VerticalSlice
{
    const GW_MAX_ENTITIES = 256;
    const GW_TARGET_RANGE = 360.0;

    void GwReset()
    {
        gwSystem.Clear(); gwNextFire.Clear(); gwHitSystem.Clear(); gwHitCount.Clear();
        for (int i = 0; i < geProxy.Size(); i++) if (geProxy[i] != null) geProxy[i].Destroy();
        geSystem.Clear(); geMode.Clear(); geX.Clear(); geY.Clear(); geVX.Clear(); geVY.Clear();
        geRadius.Clear(); geDamage.Clear(); geExpire.Clear(); geNextTick.Clear();
        geTick.Clear(); gePierce.Clear(); geLastHit.Clear(); geProxy.Clear();
        gwFrozenUntil.Clear(); gwTunaForms.Clear(); gwSlowUntil.Clear();
        gwPinionMoving.Clear(); gwPinionBurstReady.Clear(); gwAmmoStock = 0; gwAshesKills = 0;
        KbReset();
        gwShieldUntil = 0; gwEventId = 0; gwRng = 4410973;
    }

    // Called by AcquireWeapon; returns the engine index.
    int GwEquip(int system)
    {
        if (!DSGenericWeaponDefs.Handles(system)) return -1;
        gwSystem.Push(system);
        gwNextFire.Push(tic + 1);
        return gwSystem.Size() - 1;
    }

    // Accepted hits per weapon system (DS_N2_DISPATCH_SUMMARY).
    void GwCountHit(int system)
    {
        int i = gwHitSystem.Find(system);
        if (i >= gwHitSystem.Size()) { gwHitSystem.Push(system); gwHitCount.Push(1); }
        else gwHitCount[i]++;
    }

    int GwHitsFor(int system)
    {
        int i = gwHitSystem.Find(system);
        return i < gwHitSystem.Size() ? gwHitCount[i] : 0;
    }

    int GwRandom(int range)
    {
        gwRng = DSP022StageGeometry.NextSpawnRng(gwRng);
        return range > 0 ? (gwRng & 0x7fffffff) % range : 0;
    }

    bool GwFrozen(int slot)
    {
        return slot >= 0 && slot < gwFrozenUntil.Size() && gwFrozenUntil[slot] > tic;
    }

    void GwFreeze(int slot, int untilTic)
    {
        while (gwFrozenUntil.Size() <= slot) gwFrozenUntil.Push(0);
        bool fresh = gwFrozenUntil[slot] <= tic;
        if (gwFrozenUntil[slot] < untilTic) gwFrozenUntil[slot] = untilTic;
        if (fresh && ValidParts(slot, generations[slot], ids[slot])) ArcanaOnFreeze(x[slot], y[slot]);
    }

    // Mannajja's beam slows enemies inside it (wiki approximation: half speed).
    bool GwSlowed(int slot)
    {
        return slot >= 0 && slot < gwSlowUntil.Size() && gwSlowUntil[slot] > tic;
    }

    void GwSlow(int slot, int untilTic)
    {
        while (gwSlowUntil.Size() <= slot) gwSlowUntil.Push(0);
        if (gwSlowUntil[slot] < untilTic) gwSlowUntil[slot] = untilTic;
    }

    bool GwIsBoss(int slot)
    {
        return mfEnabled && MFValid(slot) && (mfBoss[slot] > 0 || DSStage.IsReaperLike(mfTypes[slot]));
    }

    // Penshin Fatcha: takes one new random tuna form for each rank above 1.
    void GwTunaSync(int rank)
    {
        while (gwTunaForms.Size() < rank - 1 && gwTunaForms.Size() < 6)
        {
            Array<int> unused;
            for (int f = 0; f < 6; f++) if (gwTunaForms.Find(f) >= gwTunaForms.Size()) unused.Push(f);
            int form = unused[GwRandom(unused.Size())];
            gwTunaForms.Push(form);
            bool miracle = gwTunaForms.Size() >= 6;
            GmShowToast(miracle ? "Penshin Fatcha becomes Miracle of Multiplication!"
                : String.Format("Penshin Fatcha becomes %s (%s)", DSGenericWeaponDefs.TunaName(form), DSGenericWeaponDefs.TunaStat(form)));
        }
    }

    // 1 when the form leaning on this stat has been taken (Miracle has all).
    int GwTunaHas(int rank, int stat)
    {
        GwTunaSync(rank);
        for (int i = 0; i < gwTunaForms.Size() && i < rank - 1; i++)
            if (gwTunaForms[i] == stat) return 1;
        return 0;
    }

    // Might-scaled damage for this weapon rank.
    int GwDamage(int system, int rank)
    {
        int base = DSGenericWeaponDefs.DamageMilli(system, rank);
        int might = RsMightFor(system);
        return base > 2000000000 / max(1, might) * 1000 ? 2000000000 : base / 1000 * might + base % 1000 * might / 1000;
    }

    bool GwHit(int slot, int damageMilli, int system)
    {
        if (damageMilli <= 0 || !ValidParts(slot, generations[slot], ids[slot]) || kinds[slot] != KIND_ENEMY) return false;
        bool crit = RollCrit(DSGenericWeaponDefs.CritChanceMilli(system),
            system != DSN3Rows.SYSTEM_SPIRIT_DISTURBANCE);
        if (crit)
        {
            int mul = DSGenericWeaponDefs.CritMultiplierMilli(system);
            if (system == DSN3Rows.SYSTEM_SERAPHIC_CRY && rsActive) mul = mul * max(1000, rsLuckMilli) / 1000;
            damageMilli = damageMilli > 2000000000 / max(1, mul) * 1000 ? 2000000000 : damageMilli / 1000 * mul + damageMilli % 1000 * mul / 1000;
        }
        double hx = x[slot]; double hy = y[slot];
        bool glass = system == DSN3Rows.SYSTEM_GLASS_FANDANGO || system == DSN3Rows.SYSTEM_CELESTIAL_VOULGE;
        if (glass && GwFrozen(slot)) damageMilli = damageMilli > 1000000000 ? 2000000000 : damageMilli * 2;
        // Vicious Hunger: a chance (Luck-scaled) to turn a normal enemy into gold.
        bool gilded = system == DSN3Rows.SYSTEM_VICIOUS_HUNGER && rsActive && !GwIsBoss(slot)
            && !(mfEnabled && MFValid(slot) && MFIsProp(mfTypes[slot])) && RollChance(30, true);
        if (gilded) damageMilli = max(damageMilli, health[slot]);
        int before; int after; int killed;
        if (!DSP025ApplyLogicalHit(slot, generations[slot], ids[slot], damageMilli, before, after, killed)) return false;
        gwAcceptedDamageMilli += before - after;
        GwCountHit(system);
        if (killed != 0) HandleEnemyDeath(slot, before, 900000 + gwEventId);
        if (crit) OnCrit(hx, hy, system);
        if (killed != 0 && system == DSN3Rows.SYSTEM_ASHES_OF_MUSPELL) gwAshesKills++;
        // Celestial Voulge: a quarter of its hits freeze the target for 2 s.
        if (killed == 0 && system == DSN3Rows.SYSTEM_CELESTIAL_VOULGE && !GwIsBoss(slot) && RollChance(250, false))
            GwFreeze(slot, tic + 70);
        if (gilded && killed != 0)
        {
            MFDropCoin(hx, hy); FxCount("gold");
            DSWeaponFx.Burst("WRNG", hx, hy, 1.2, 8.0, 40.0, true, Color(255, 255, 210, 60), 10);
        }
        return true;
    }

    // Enemies within radius of (px, py), nearest first when sorted is set.
    void GwEnemiesNear(double px, double py, double radius, out Array<int> found)
    {
        found.Clear();
        DSP024RadiusCandidates(px, py, radius + 8.0);
        for (int i = 0; i < spatialCandidateCount; i++)
        {
            int slot = spatialCandidateSlots[i];
            if (!ValidParts(slot, spatialCandidateGenerations[i], spatialCandidateIds[i])) continue;
            if (kinds[slot] != KIND_ENEMY) continue;
            double dx = x[slot] - px; double dy = y[slot] - py;
            double reach = radius + collisionRadii[slot];
            if (dx * dx + dy * dy <= reach * reach) found.Push(slot);
        }
    }

    int GwNearestEnemy(double px, double py, double radius)
    {
        Array<int> found;
        GwEnemiesNear(px, py, radius, found);
        int best = -1; double bestDistance = 0.0;
        for (int i = 0; i < found.Size(); i++)
        {
            int slot = found[i];
            if (mfEnabled && MFValid(slot) && MFIsProp(mfTypes[slot])) continue;
            double dx = x[slot] - px; double dy = y[slot] - py;
            double d = dx * dx + dy * dy;
            if (best < 0 || d < bestDistance) { best = slot; bestDistance = d; }
        }
        return best;
    }

    int GwSpawn(int system, int mode, double px, double py, double vx, double vy,
        double radius, int damageMilli, int lifeTics, int tickTics, int pierce)
    {
        if (geSystem.Size() >= GW_MAX_ENTITIES) return -1;
        geSystem.Push(system); geMode.Push(mode);
        geX.Push(px); geY.Push(py); geVX.Push(vx); geVY.Push(vy);
        geRadius.Push(radius); geDamage.Push(damageMilli);
        geExpire.Push(tic + max(1, lifeTics)); geNextTick.Push(tic);
        geTick.Push(tickTics); gePierce.Push(pierce); geLastHit.Push(0);
        Actor proxy = Actor.Spawn("DSGenericWeaponProxy", (px, py, 2.0), NO_REPLACE);
        if (proxy != null)
        {
            proxy.A_SetRenderStyle(0.85, STYLE_AddStencil);
            proxy.SetShade(DSGenericWeaponDefs.Tint(system));
            bool ground = mode == DSGenericWeaponDefs.MODE_FIELD_PLAYER || mode == DSGenericWeaponDefs.MODE_FIELD_ENEMY
                || mode == DSGenericWeaponDefs.MODE_RAIN || mode == DSGenericWeaponDefs.MODE_STRIKE
                || mode == DSGenericWeaponDefs.MODE_FREEZE || mode == DSGenericWeaponDefs.MODE_HALVE
                || mode == DSGenericWeaponDefs.MODE_ON_CRIT;
            proxy.sprite = Actor.GetSpriteIndex(DSWeaponArt.GenericShape(mode, system));
            proxy.A_SetScale(clamp(radius * 2.0 / 32.0, 0.2, 6.0));
            if (mode == DSGenericWeaponDefs.MODE_BEAM)
            {
                // 16x96 art: width = beam diameter, six times as tall.
                proxy.A_SetScale(radius * 2.0 / 16.0);
                proxy.A_SetRenderStyle(0.8, STYLE_Add);
                proxy.SetOrigin((px, py, radius * 6.0), false);
                geProxy.Push(proxy);
                return geSystem.Size() - 1;
            }
            if (ground) { proxy.bFlatSprite = true; proxy.A_SetRenderStyle(0.6, STYLE_AddStencil); proxy.SetShade(DSGenericWeaponDefs.Tint(system)); }
            proxy.SetOrigin((px, py, ground ? 1.0 : DSProjectileProxyBase.VISUAL_Z), false);
        }
        geProxy.Push(proxy);
        return geSystem.Size() - 1;
    }

    void GwRemove(int e)
    {
        if (geProxy[e] != null) geProxy[e].Destroy();
        geSystem.Delete(e); geMode.Delete(e); geX.Delete(e); geY.Delete(e);
        geVX.Delete(e); geVY.Delete(e); geRadius.Delete(e); geDamage.Delete(e);
        geExpire.Delete(e); geNextTick.Delete(e); geTick.Delete(e);
        gePierce.Delete(e); geLastHit.Delete(e); geProxy.Delete(e);
    }

    // ---- firing -----------------------------------------------------------------

    void GwFire(int system, int rank)
    {
        WeaponSfx(system);
        gwEventId++;
        int mode = DSGenericWeaponDefs.Mode(system);
        int amount = DSGenericWeaponDefs.Amount(system, rank) + RsAmountFor(system);
        double area = DSGenericWeaponDefs.AreaMilli(system, rank) / 1000.0 * RsAreaFor(system) / 1000.0;
        double radius = DSGenericWeaponDefs.BaseRadius(system) * area;
        double speed = DSGenericWeaponDefs.BaseSpeed(system) * DSGenericWeaponDefs.SpeedMilli(system, rank) / 1000.0 * RsSpeedFor(system) / 1000.0;
        int life = DSGenericWeaponDefs.DurationTics(system, rank) * RsDurationFor(system) / 1000;
        int damage = GwDamage(system, rank);
        if (system == DSN3Rows.SYSTEM_PENSHIN_FATCHA)
        {
            // Tuna forms: Speed, Duration, Area, Might +40% each, Amount +1;
            // Miracle of Multiplication (rank 7) also fires two more fish.
            speed *= 1.0 + 0.4 * GwTunaHas(rank, 0);
            life = life * (10 + 4 * GwTunaHas(rank, 1)) / 10;
            amount += GwTunaHas(rank, 3) + (rank >= 7 ? 2 : 0);
            radius *= 1.0 + 0.4 * GwTunaHas(rank, 4);
            damage = damage * (10 + 4 * GwTunaHas(rank, 5)) / 10;
        }
        int tickTics = DSGenericWeaponDefs.TickTics(system, rank);
        int pierce = DSGenericWeaponDefs.Pierce(system, rank) + RsPierceFor(system);
        // Per-weapon twists from their descriptions (wiki approximations).
        if (system == DSN3Rows.SYSTEM_ASHES_OF_MUSPELL)
        {
            // Grows with every enemy it kills: +0.2% damage and +0.1% size per kill.
            damage = damage / 1000 * (1000 + min(2000, gwAshesKills * 2));
            radius *= 1.0 + min(1.0, gwAshesKills / 1000.0);
        }
        if (system == DSN3Rows.SYSTEM_GLASS_FANDANGO || system == DSN3Rows.SYSTEM_CELESTIAL_VOULGE)
            damage = damage / 1000 * RsSpeedFor(system);   // grows with projectile Speed
        if (system == DSN3Rows.SYSTEM_EMBRACE_OF_GAEA && playerInvulnerableUntil > tic)
            damage = damage > 1000000000 ? 2000000000 : damage * 2;
        if (system == DSN3Rows.SYSTEM_PHOTONSTORM && rsActive)
            amount += clamp((rsLuckMilli - 1000) / 100, 0, 10);   // +1 beam per +10% Luck
        if (system == DSN3Rows.SYSTEM_CHAOS_RUNE || system == DSN3Rows.SYSTEM_WICKED_RULER)
            tickTics = max(4, tickTics * 1000 / max(100, RsSpeedFor(system)));   // Speed adds hits
        double yaw = players[0].mo != null ? players[0].mo.Angle : 0.0;

        if (mode == DSGenericWeaponDefs.MODE_PROJECTILE)
        {
            // Gunastrophe fires at any enemy in sight, not just nearby ones.
            double range = system == DSN3Rows.SYSTEM_GUNASTROPHE ? 900.0 : GW_TARGET_RANGE;
            int target = GwNearestEnemy(playerX, playerY, range);
            // Ammo Appalate / Gunastrophe keep shots while nothing is near and
            // fire the stockpile (up to 12) when an enemy shows up.
            if (system == DSN3Rows.SYSTEM_AMMO_APPALATE || system == DSN3Rows.SYSTEM_GUNASTROPHE)
            {
                if (target < 0) { gwAmmoStock = min(12, gwAmmoStock + amount); return; }
                if (gwAmmoStock > 0) FxCount("ammo_stock", gwAmmoStock);
                amount += gwAmmoStock; gwAmmoStock = 0;
            }
            double aim = target >= 0 ? atan2(y[target] - playerY, x[target] - playerX) : yaw;
            for (int n = 0; n < amount; n++)
            {
                double a = aim + (n - (amount - 1) / 2.0) * 8.0;
                GwSpawn(system, mode, playerX, playerY, cos(a) * speed, sin(a) * speed, radius, damage, life, 0, pierce);
            }
        }
        else if (mode == DSGenericWeaponDefs.MODE_FAN)
        {
            for (int n = 0; n < amount; n++)
            {
                double a = yaw + (amount > 1 ? -30.0 + 60.0 * n / (amount - 1) : 0.0);
                GwSpawn(system, mode, playerX, playerY, cos(a) * speed, sin(a) * speed, radius, damage, life, 0, 999);
            }
        }
        else if (mode == DSGenericWeaponDefs.MODE_FIELD_PLAYER)
        {
            for (int n = 0; n < amount; n++)
            {
                double a = n * 360.0 / amount;
                double offset = amount > 1 ? radius * 0.8 : 0.0;
                GwSpawn(system, mode, playerX + cos(a) * offset, playerY + sin(a) * offset, 0, 0, radius, damage, life, tickTics, 999);
            }
        }
        else if (mode == DSGenericWeaponDefs.MODE_FIELD_ENEMY || mode == DSGenericWeaponDefs.MODE_STRIKE)
        {
            Array<int> found;
            GwEnemiesNear(playerX, playerY, GW_TARGET_RANGE, found);
            for (int n = 0; n < amount; n++)
            {
                double tx; double ty;
                if (found.Size() > 0)
                {
                    int slot = found[GwRandom(found.Size())];
                    tx = x[slot]; ty = y[slot];
                }
                else
                {
                    double a = GwRandom(360);
                    tx = playerX + cos(a) * 120.0; ty = playerY + sin(a) * 120.0;
                }
                if (mode == DSGenericWeaponDefs.MODE_STRIKE)
                {
                    GwBlast(tx, ty, radius, damage, system);
                    GwSpawn(system, mode, tx, ty, 0, 0, radius, 0, 6, 0, 0);
                }
                else GwSpawn(system, mode, tx, ty, 0, 0, radius, damage, life, tickTics, 999);
            }
        }
        else if (mode == DSGenericWeaponDefs.MODE_COMPANION)
        {
            for (int n = 0; n < amount; n++)
            {
                double a = GwRandom(360);
                GwSpawn(system, mode, playerX + cos(a) * 24.0, playerY + sin(a) * 24.0, speed, 0, radius, damage, life, tickTics, 999);
            }
        }
        else if (mode == DSGenericWeaponDefs.MODE_RAIN)
        {
            for (int n = 0; n < amount; n++)
            {
                double a = GwRandom(360); double d = 40 + GwRandom(180);
                double tx = playerX + cos(a) * d; double ty = playerY + sin(a) * d;
                GwBlast(tx, ty, radius, damage, system);
                GwSpawn(system, mode, tx, ty, 0, 0, radius, 0, 8, 0, 0);
            }
        }
        else if (mode == DSGenericWeaponDefs.MODE_FREEZE || mode == DSGenericWeaponDefs.MODE_HALVE)
        {
            Array<int> found;
            GwEnemiesNear(playerX, playerY, radius, found);
            int limit = mode == DSGenericWeaponDefs.MODE_FREEZE ? amount * 8 : found.Size();
            for (int n = 0; n < found.Size() && n < limit; n++)
            {
                int slot = found[n];
                if (mfEnabled && MFValid(slot) && DSStage.IsReaperLike(mfTypes[slot])) continue;
                if (mode == DSGenericWeaponDefs.MODE_HALVE && !GwIsBoss(slot) && health[slot] > 1)
                    GwHit(slot, health[slot] / 2, system);
                if (ValidParts(slot, generations[slot], ids[slot])) GwFreeze(slot, tic + life);
            }
            GwSpawn(system, mode, playerX, playerY, 0, 0, min(radius, 120.0), 0, 10, 0, 0);
        }
        else if (mode == DSGenericWeaponDefs.MODE_BEAM)
        {
            // Song of Mana / Mannajja: columns land at random spots around the
            // player, leaning toward where enemies are, and hit what is inside.
            Array<int> near;
            GwEnemiesNear(playerX, playerY, GW_TARGET_RANGE * 0.6, near);
            for (int n = 0; n < amount; n++)
            {
                double tx; double ty;
                if (near.Size() > 0 && GwRandom(3) > 0)
                {
                    int slot = near[GwRandom(near.Size())];
                    tx = x[slot] + GwRandom(41) - 20; ty = y[slot] + GwRandom(41) - 20;
                }
                else
                {
                    double a = GwRandom(360); double d = 40 + GwRandom(160);
                    tx = playerX + cos(a) * d; ty = playerY + sin(a) * d;
                }
                GwSpawn(system, mode, tx, ty, 0, 0, radius, damage, life, tickTics, 999);
            }
        }
        else if (mode == DSGenericWeaponDefs.MODE_SHIELD)
        {
            gwShieldUntil = max(gwShieldUntil, tic + life);
            GwSpawn(system, mode, playerX, playerY, 0, 0, 20.0, 0, life, 0, 0);
        }
        { if (!dsQuiet) Console.Printf("DS_GW_FIRE tic=%d system_id=%d rank=%d mode=%d amount=%d damage_milli=%d radius=%.1f life=%d", tic, system, rank, mode, amount, damage, radius, life); }
    }

    // Instant area damage.
    void GwBlast(double px, double py, double radius, int damage, int system)
    {
        Array<int> found;
        GwEnemiesNear(px, py, radius, found);
        for (int i = 0; i < found.Size(); i++) GwHit(found[i], damage, system);
    }

    // Radial burst from Pako Battiliar / Mazo Familiar when the player is hit.
    void GwOnPlayerHit()
    {
        for (int i = 0; i < n2System.Size(); i++)
        {
            int system = n2System[i];
            if (DSGenericWeaponDefs.Mode(system) != DSGenericWeaponDefs.MODE_RETALIATE) continue;
            int index = n2EngineIndex[i];
            if (index < 0 || index >= gwNextFire.Size() || tic < gwNextFire[index]) continue;
            int rank = n2Rank[i];
            gwNextFire[index] = tic + max(1, DSGenericWeaponDefs.CooldownTics(system, rank) * rsCooldownMilli / 1000);
            int amount = DSGenericWeaponDefs.Amount(system, rank) + RsAmountFor(system);
            double speed = DSGenericWeaponDefs.BaseSpeed(system) * RsSpeedFor(system) / 1000.0;
            double radius = DSGenericWeaponDefs.BaseRadius(system) * RsAreaFor(system) / 1000.0;
            int life = DSGenericWeaponDefs.DurationTics(system, rank) * RsDurationFor(system) / 1000;
            int damage = GwDamage(system, rank);
            if (system == DSN3Rows.SYSTEM_MAZO_FAMILIAR)
            {
                // Damage and Amount grow with max health (per 100 HP above 100).
                double scale = max(1.0, CurrentPlayerHealthCap() / 100000.0);
                damage = int(damage * scale);
                amount += int((scale - 1.0) * 4.0);
            }
            for (int n = 0; n < amount; n++)
            {
                double a = n * 360.0 / amount;
                GwSpawn(system, DSGenericWeaponDefs.MODE_RETALIATE, playerX, playerY, cos(a) * speed, sin(a) * speed,
                    radius, damage, life, 0, DSGenericWeaponDefs.Pierce(system, rank));
            }
        }
    }

    // Unearthly Bolt / Spirit Disturbance: a critical hit from any weapon
    // leaves a damage zone at the target, at most once per cooldown. The
    // bolts' own crits (Spirit Disturbance always crits) don't chain.
    void GwOnCrit(double px, double py, int sourceSystem)
    {
        if (DSGenericWeaponDefs.Mode(sourceSystem) == DSGenericWeaponDefs.MODE_ON_CRIT) return;
        for (int i = 0; i < n2System.Size(); i++)
        {
            int system = n2System[i];
            if (DSGenericWeaponDefs.Mode(system) != DSGenericWeaponDefs.MODE_ON_CRIT) continue;
            int index = n2EngineIndex[i];
            if (index < 0 || index >= gwNextFire.Size() || tic < gwNextFire[index]) continue;
            int rank = n2Rank[i];
            gwNextFire[index] = tic + max(1, DSGenericWeaponDefs.CooldownTics(system, rank) * rsCooldownMilli / 1000);
            double radius = DSGenericWeaponDefs.BaseRadius(system)
                * DSGenericWeaponDefs.AreaMilli(system, rank) / 1000.0 * RsAreaFor(system) / 1000.0;
            int life = DSGenericWeaponDefs.DurationTics(system, rank) * RsDurationFor(system) / 1000;
            int zones = DSGenericWeaponDefs.Amount(system, rank) + RsAmountFor(system);
            for (int n = 0; n < zones; n++)
            {
                double a = n * 360.0 / zones; double off = zones > 1 ? radius * 0.7 : 0.0;
                GwSpawn(system, DSGenericWeaponDefs.MODE_ON_CRIT, px + cos(a) * off, py + sin(a) * off, 0, 0,
                    radius, GwDamage(system, rank), life, DSGenericWeaponDefs.TickTics(system, rank), 999);
            }
            WeaponSfx(system);
            FxCount("crit_zone");
        }
    }

    // Shadow Pinion / Valkyrie Turner: while the player moves they leave a
    // damaging trail; stopping sets off a burst (at most once per cooldown).
    void GwPinionTick(int system, int rank, int index)
    {
        while (gwPinionMoving.Size() <= index) { gwPinionMoving.Push(0); gwPinionBurstReady.Push(0); }
        double radius = DSGenericWeaponDefs.BaseRadius(system)
            * DSGenericWeaponDefs.AreaMilli(system, rank) / 1000.0 * RsAreaFor(system) / 1000.0;
        int life = DSGenericWeaponDefs.DurationTics(system, rank) * RsDurationFor(system) / 1000;
        int damage = GwDamage(system, rank);
        bool moving = PlayerMoving();
        if (moving && tic >= gwNextFire[index])
        {
            gwNextFire[index] = tic + 6;
            GwSpawn(system, DSGenericWeaponDefs.MODE_FIELD_PLAYER, playerX, playerY, 0, 0, radius * 0.5,
                damage, life, DSGenericWeaponDefs.TickTics(system, rank), 999);
        }
        else if (!moving && gwPinionMoving[index] != 0 && tic >= gwPinionBurstReady[index])
        {
            gwPinionBurstReady[index] = tic + max(1, DSGenericWeaponDefs.CooldownTics(system, rank) * rsCooldownMilli / 1000);
            WeaponSfx(system);
            GwBlast(playerX, playerY, radius * 1.6, damage * 2, system);
            GwSpawn(system, DSGenericWeaponDefs.MODE_FIELD_PLAYER, playerX, playerY, 0, 0, radius * 1.6, 0, 10, 0, 0);
            FxCount("pinion_burst");
        }
        gwPinionMoving[index] = moving ? 1 : 0;
    }

    // Crimson Shroud: caps each hit taken at 10 and strikes back around the
    // player (wiki approximation). Returns the damage to apply.
    int GwShroudIncoming(int damageMilli)
    {
        int i = N2Find(DSN3Rows.SYSTEM_CRIMSON_SHROUD);
        if (i < 0) return damageMilli;
        int rank = n2Rank[i];
        double radius = 90.0 * RsAreaFor(DSN3Rows.SYSTEM_CRIMSON_SHROUD) / 1000.0;
        GwBlast(playerX, playerY, radius, max(10000, GwDamage(DSN3Rows.SYSTEM_CRIMSON_SHROUD, rank)), DSN3Rows.SYSTEM_CRIMSON_SHROUD);
        DSWeaponFx.Burst("WRNG", playerX, playerY, 1.2, 20.0, radius * 2.0, true, Color(255, 230, 40, 60), 12);
        FxCount("shroud");
        Sfx(DSSfx.E_SHROUD_BLOCK, 10);
        return min(damageMilli, 10000);
    }

    // ---- per logical tic ------------------------------------------------------------

    void GwProcessTic()
    {
        if (!rsActive) return;
        if (gwSystem.Size() == 0 && geSystem.Size() == 0) return;
        int damageBefore = gwAcceptedDamageMilli;
        DSP024Rebuild();
        for (int i = 0; i < n2System.Size() && runState == STATE_ACTIVE; i++)
        {
            int system = n2System[i];
            if (!DSGenericWeaponDefs.Handles(system)) continue;
            int index = n2EngineIndex[i];
            if (index < 0 || index >= gwNextFire.Size()) continue;
            int fireMode = DSGenericWeaponDefs.Mode(system);
            if (fireMode == DSGenericWeaponDefs.MODE_RETALIATE || fireMode == DSGenericWeaponDefs.MODE_ON_CRIT) continue;
            if (fireMode == DSGenericWeaponDefs.MODE_FIELD_PLAYER) { GwPinionTick(system, n2Rank[i], index); continue; }
            if (tic < gwNextFire[index]) continue;
            int rank = n2Rank[i];
            int cooldown = DSGenericWeaponDefs.CooldownTics(system, rank) * rsCooldownMilli / 1000;
            if (system == DSN3Rows.SYSTEM_PENSHIN_FATCHA) cooldown = cooldown * (4 - GwTunaHas(rank, 2)) / 4;   // Tonn'omoto: -25%
            gwNextFire[index] = tic + max(1, cooldown);
            GwFire(system, rank);
        }
        for (int e = geSystem.Size() - 1; e >= 0 && runState == STATE_ACTIVE; e--)
        {
            if (tic >= geExpire[e])
            {
                if (geDamage[e] > 0 && ArcanaOwned(DSArcana.TWILIGHT_REQUIEM)
                    && (geMode[e] == DSGenericWeaponDefs.MODE_PROJECTILE || geMode[e] == DSGenericWeaponDefs.MODE_FAN))
                    ArcanaExplode(geX[e], geY[e], 40.0, RequiemDamage());
                GwRemove(e); continue;
            }
            int mode = geMode[e];
            if (mode == DSGenericWeaponDefs.MODE_FIELD_PLAYER)
            {
                // Shadow Pinion-style zones stay where they were dropped.
            }
            else if (mode == DSGenericWeaponDefs.MODE_COMPANION)
            {
                int target = GwNearestEnemy(geX[e], geY[e], GW_TARGET_RANGE);
                // No prey: cats roam around the player instead of sitting on it.
                double tx = target >= 0 ? x[target] : playerX + cos(tic * 3.0 + e * 77.0) * 70.0;
                double ty = target >= 0 ? y[target] : playerY + sin(tic * 3.0 + e * 77.0) * 70.0;
                double dx = tx - geX[e]; double dy = ty - geY[e];
                double d = sqrt(dx * dx + dy * dy);
                double step = geVX[e];
                if (d > 1.0) { geX[e] += dx / d * min(step, d); geY[e] += dy / d * min(step, d); }
            }
            else if (geVX[e] != 0 || geVY[e] != 0)
            {
                geX[e] += geVX[e]; geY[e] += geVY[e];
            }
            if (geDamage[e] > 0)
            {
                if (geTick[e] > 0)
                {
                    // Fields and companions: damage everything inside every tick.
                    if (tic >= geNextTick[e])
                    {
                        geNextTick[e] = tic + geTick[e];
                        if (geSystem[e] == DSN3Rows.SYSTEM_MANNAJJA)
                        {
                            Array<int> inside;
                            GwEnemiesNear(geX[e], geY[e], geRadius[e], inside);
                            for (int k = 0; k < inside.Size(); k++)
                                if (!GwIsBoss(inside[k])) { GwSlow(inside[k], tic + 35); FxCount("slow"); }
                        }
                        GwBlast(geX[e], geY[e], geRadius[e], geDamage[e], geSystem[e]);
                    }
                }
                else
                {
                    // Projectiles: hit each enemy once, until pierce runs out.
                    Array<int> found;
                    GwEnemiesNear(geX[e], geY[e], geRadius[e], found);
                    for (int i = 0; i < found.Size() && gePierce[e] > 0; i++)
                    {
                        int slot = found[i];
                        if (ids[slot] == geLastHit[e]) continue;
                        geLastHit[e] = ids[slot];
                        if (GwHit(slot, geDamage[e], geSystem[e])) gePierce[e]--;
                    }
                    if (gePierce[e] <= 0) { GwRemove(e); continue; }
                }
            }
            if (geProxy[e] != null)
            {
                double z = geProxy[e].Pos.Z;
                if (geMode[e] == DSGenericWeaponDefs.MODE_SHIELD) { geX[e] = playerX; geY[e] = playerY; z = 24.0; }
                if (geMode[e] == DSGenericWeaponDefs.MODE_BEAM)
                {
                    // Fades out over its last 10 tics (presentation only).
                    int left = geExpire[e] - tic;
                    if (left < 10) geProxy[e].A_SetRenderStyle(0.08 * left, STYLE_Add);
                }
                geProxy[e].SetOrigin((geX[e], geY[e], z), true);
            }
        }
        N2CreditDamage(gwAcceptedDamageMilli - damageBefore, "GENERIC");
    }
}
