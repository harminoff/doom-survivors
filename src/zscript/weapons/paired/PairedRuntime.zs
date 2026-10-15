// P042 paired-weapon firing runtime: Peachone/Ebony Wings/Vandalier bird
// impacts, Phiera/Eight/Phieraggi gun/beam geometry, Vento Sacro/
// Fuwalafuwaloo facing-arc slashes with movement streak and crit heal, and
// the three Bracelet nearest-target bursts. Implements
// docs/contracts/paired-unions.md's "Geometry adapters", "Attribution" and
// "Old attacks are not retained" sections. Union/chain predicates and the
// inventory slot transaction itself are owned by DSP042PairedRows and
// TransformationGraph.zs; this file only fires the eleven systems and
// exposes DSP042CancelWeapon/DSP042EvolveInPlace for that owner to call at
// the transaction tic.
class DSP042PairedProxy : DSProjectileProxyBase
{
    int logicalEventId;

    Default
    {
        Radius 1;
        Height 2;
        +NOBLOCKMAP;
        +NOGRAVITY;
        +NOINTERACTION;
        RenderStyle "Add";
        Alpha 0.85;
        Scale 0.05;
    }

    States
    {
    Spawn:
        BILL A 1 Bright;
        Loop;
    }
}

mixin class DSP042Paired
{
    const DSP042_EVENT_BASE = 4200000;
    const DSP042_TARGET_ENEMY = 1;
    const DSP042_MAX_ACTIVE_GUNS = 128;
    // Engineering-approximation beam/line lengths for the instant-line
    // systems (Phieraggi's wall-passing beams). Labelled: no infobox reports
    // a beam range, so this reuses the same boundary half-extent order of
    // magnitude as the P041 moving boundary.
    const DSP042_PHIERAGGI_BEAM_LENGTH = 320;

    // ---- Equipped-weapon schedule (one row per equipped paired weapon) ----
    Array<int> dsp042WeaponSystems;   // 0 = cancelled/dead
    Array<int> dsp042WeaponRanks;
    Array<int> dsp042WeaponSlots;
    Array<int> dsp042WeaponGenerations;
    Array<int> dsp042WeaponIds;
    Array<int> dsp042WeaponFormGeneration;
    Array<int> dsp042NextVolleyTics;
    Array<int> dsp042WeaponAngleDegCW;   // birds/Vandalier CW ledger
    Array<int> dsp042WeaponAngleDegCCW;  // birds/Vandalier CCW ledger
    Array<int> dsp042WeaponBeamAngleDeg; // Phieraggi rotation ledger

    // ---- Gun projectile state (Phiera/Eight) ----
    Array<int> dsp042GunActive;
    Array<int> dsp042GunEvents;
    Array<int> dsp042GunSystems;
    Array<int> dsp042GunOwnerSlot;
    Array<int> dsp042GunOwnerGeneration;
    Array<int> dsp042GunOwnerId;
    Array<int> dsp042GunFormGeneration;
    Array<double> dsp042GunX;
    Array<double> dsp042GunY;
    Array<double> dsp042GunDirX;
    Array<double> dsp042GunDirY;
    Array<double> dsp042GunSpeedUps;
    Array<int> dsp042GunDamageMilli;
    Array<int> dsp042GunMightMilli;
    Array<int> dsp042GunPierceRemaining;
    Array<int> dsp042GunRadiusUnits;
    Array<DSP042PairedProxy> dsp042GunProxies;

    // ---- Pending (un-emitted) gun shots within a multi-shot volley --------
    // A gun volley's `amount` field can exceed 1 (e.g. Phiera/Eight rank 8:
    // amount=3, interval_tics=7 = 0.2s). Ordinal 0 spawns immediately (same
    // as before this addition, so amount=1 systems and every existing
    // fixture mode are byte-identical); ordinals 1..amount-1 are queued here
    // and only actually spawned once their own due tic arrives AND the
    // owning weaponIndex is still the same system/form generation it was
    // when the volley was fired (contract "old attacks are not retained" /
    // burst_union P042-A02: a union or cancellation mid-burst must drop
    // every still-pending, un-emitted child forever; only already-emitted
    // ordinal-0 shots keep resolving under the original owner).
    Array<int> dsp042PendingGunWeaponIndex;
    Array<int> dsp042PendingGunSystem;
    Array<int> dsp042PendingGunFormGeneration;
    Array<int> dsp042PendingGunDeg;
    Array<double> dsp042PendingGunOriginX;
    Array<double> dsp042PendingGunOriginY;
    Array<double> dsp042PendingGunSpeedUps;
    Array<int> dsp042PendingGunDamageMilli;
    Array<int> dsp042PendingGunMightMilli;
    Array<int> dsp042PendingGunPierce;
    Array<int> dsp042PendingGunDueTic;
    Array<int> dsp042PendingGunActive;

    // ---- Logical walls (Phiera/Eight stop here; Phieraggi ignores them) --
    Array<int> dsp042WallIds;
    Array<double> dsp042WallStartX;
    Array<double> dsp042WallStartY;
    Array<double> dsp042WallEndX;
    Array<double> dsp042WallEndY;

    // ---- Per-pair hit ledger (guns pierce gate) ----
    Array<int> dsp042PairEvents;
    Array<int> dsp042PairSlots;
    Array<int> dsp042PairGenerations;
    Array<int> dsp042PairIds;
    Array<int> dsp042PairReadyTic;

    int dsp042EventOrdinal;
    int dsp042AcceptedHits;
    int dsp042RejectedHits;
    int dsp042AcceptedDamageMilli;
    int dsp042FuwalaHealReadyTic;

    // ---- Reset / lifecycle -------------------------------------------------

    void DSP042ResetPairedRuntime(int seed)
    {
        for (int i = 0; i < dsp042GunProxies.Size(); i++)
            if (dsp042GunProxies[i] != null) dsp042GunProxies[i].Destroy();

        dsp042WeaponSystems.Clear(); dsp042WeaponRanks.Clear();
        dsp042WeaponSlots.Clear(); dsp042WeaponGenerations.Clear();
        dsp042WeaponIds.Clear(); dsp042WeaponFormGeneration.Clear();
        dsp042NextVolleyTics.Clear(); dsp042WeaponAngleDegCW.Clear();
        dsp042WeaponAngleDegCCW.Clear(); dsp042WeaponBeamAngleDeg.Clear();

        dsp042GunActive.Clear(); dsp042GunEvents.Clear(); dsp042GunSystems.Clear();
        dsp042GunOwnerSlot.Clear(); dsp042GunOwnerGeneration.Clear();
        dsp042GunOwnerId.Clear(); dsp042GunFormGeneration.Clear();
        dsp042GunX.Clear(); dsp042GunY.Clear(); dsp042GunDirX.Clear();
        dsp042GunDirY.Clear(); dsp042GunSpeedUps.Clear();
        dsp042GunDamageMilli.Clear(); dsp042GunMightMilli.Clear();
        dsp042GunPierceRemaining.Clear(); dsp042GunRadiusUnits.Clear();
        dsp042GunProxies.Clear();

        dsp042PendingGunWeaponIndex.Clear(); dsp042PendingGunSystem.Clear();
        dsp042PendingGunFormGeneration.Clear(); dsp042PendingGunDeg.Clear();
        dsp042PendingGunOriginX.Clear(); dsp042PendingGunOriginY.Clear();
        dsp042PendingGunSpeedUps.Clear(); dsp042PendingGunDamageMilli.Clear();
        dsp042PendingGunMightMilli.Clear(); dsp042PendingGunPierce.Clear();
        dsp042PendingGunDueTic.Clear(); dsp042PendingGunActive.Clear();

        dsp042WallIds.Clear(); dsp042WallStartX.Clear(); dsp042WallStartY.Clear();
        dsp042WallEndX.Clear(); dsp042WallEndY.Clear();

        dsp042PairEvents.Clear(); dsp042PairSlots.Clear();
        dsp042PairGenerations.Clear(); dsp042PairIds.Clear();
        dsp042PairReadyTic.Clear();

        dsp042EventOrdinal = 0; dsp042AcceptedHits = 0; dsp042RejectedHits = 0;
        dsp042AcceptedDamageMilli = 0; dsp042FuwalaHealReadyTic = 0;
        DSP042ResetPairedTargeting(seed);
        { if (!dsQuiet) Console.Printf("DS_P042_RUNTIME_RESET seed=%d rng_stream=DEDICATED_P042_CRIT native_projectiles=VISUAL_ONLY", seed); }
    }

    int DSP042NewEventId()
    {
        dsp042EventOrdinal++;
        return DSP042_EVENT_BASE + dsp042EventOrdinal;
    }

    bool DSP042AddLogicalWall(int stableId, double startX, double startY,
        double endX, double endY)
    {
        if (stableId <= 0 || (startX == endX && startY == endY)) return false;
        for (int i = 0; i < dsp042WallIds.Size(); i++)
            if (dsp042WallIds[i] == stableId) return false;
        dsp042WallIds.Push(stableId);
        dsp042WallStartX.Push(startX); dsp042WallStartY.Push(startY);
        dsp042WallEndX.Push(endX); dsp042WallEndY.Push(endY);
        return true;
    }

    // ---- Equip / cancel / evolve ------------------------------------------

    int DSP042EquipFixture(int systemId, int rank, int weaponSlot,
        int firstFireTic)
    {
        if (DSP042PairedRows.RankCount(systemId) < rank || rank < 1
            || weaponSlot < 0 || weaponSlot >= lifeStates.Size()
            || lifeStates[weaponSlot] != STORE_ALIVE || firstFireTic < 0)
            return -1;
        dsp042WeaponSystems.Push(systemId);
        dsp042WeaponRanks.Push(rank);
        dsp042WeaponSlots.Push(weaponSlot);
        dsp042WeaponGenerations.Push(generations[weaponSlot]);
        dsp042WeaponIds.Push(ids[weaponSlot]);
        dsp042WeaponFormGeneration.Push(1);
        dsp042NextVolleyTics.Push(firstFireTic);
        dsp042WeaponAngleDegCW.Push(0); dsp042WeaponAngleDegCCW.Push(0);
        dsp042WeaponBeamAngleDeg.Push(0);
        int index = dsp042WeaponSystems.Size() - 1;
        { if (!dsQuiet) Console.Printf("DS_P042_EQUIP accepted=1 weapon_index=%d system_id=%d rank=%d weapon_slot=%d weapon_generation=%d weapon_id=%d form_generation=1 first_fire_tic=%d", index, systemId, rank, weaponSlot, generations[weaponSlot], ids[weaponSlot], firstFireTic); }
        return index;
    }

    // Cancels this weapon's future volleys ("the parents' schedules and any
    // un-emitted children" per contract). Any gun projectile already in
    // flight under this weapon's own owner handle is untouched -- it keeps
    // resolving/hitting under the original owner until it naturally retires
    // (DSP042ProcessGuns below never consults dsp042WeaponSystems).
    bool DSP042CancelWeapon(int weaponIndex, int logicalTic)
    {
        if (weaponIndex < 0 || weaponIndex >= dsp042WeaponSystems.Size()
            || dsp042WeaponSystems[weaponIndex] == 0) return false;
        int oldSystem = dsp042WeaponSystems[weaponIndex];
        dsp042WeaponSystems[weaponIndex] = 0;
        dsp042NextVolleyTics[weaponIndex] = 0x7fffffff;
        { if (!dsQuiet) Console.Printf("DS_P042_CANCEL_WEAPON weapon_index=%d tic=%d old_system_id=%d reason=UNION_OR_EVOLUTION future_only=1", weaponIndex, logicalTic, oldSystem); }
        return true;
    }

    // Reuses weaponIndex's slot bookkeeping (same weaponSlot/generation/id)
    // for the evolved system/rank, bumping form generation so attribution on
    // every subsequent child distinguishes pre- from post-evolution hits.
    // Used both for a union's output taking over the lower input's schedule
    // row, and for an in-place chain evolution (Bracelet -> Bi -> Tri).
    bool DSP042EvolveInPlace(int weaponIndex, int newSystemId, int newRank,
        int logicalTic)
    {
        if (weaponIndex < 0 || weaponIndex >= dsp042WeaponSystems.Size()
            || DSP042PairedRows.RankCount(newSystemId) < newRank || newRank < 1)
            return false;
        int oldSystem = dsp042WeaponSystems[weaponIndex];
        int oldRank = dsp042WeaponRanks[weaponIndex];
        dsp042WeaponSystems[weaponIndex] = newSystemId;
        dsp042WeaponRanks[weaponIndex] = newRank;
        dsp042WeaponFormGeneration[weaponIndex]++;
        dsp042NextVolleyTics[weaponIndex] = logicalTic;
        dsp042WeaponAngleDegCW[weaponIndex] = 0;
        dsp042WeaponAngleDegCCW[weaponIndex] = 0;
        dsp042WeaponBeamAngleDeg[weaponIndex] = 0;
        { if (!dsQuiet) Console.Printf("DS_P042_EVOLVE_IN_PLACE weapon_index=%d tic=%d old_system_id=%d old_rank=%d new_system_id=%d new_rank=%d form_generation=%d", weaponIndex, logicalTic, oldSystem, oldRank, newSystemId, newRank, dsp042WeaponFormGeneration[weaponIndex]); }
        return true;
    }

    // N2 dispatcher rank-change API (docs/contracts/normal-play-integration.md
    // "Weapon dispatcher"). Reuses the accepted DSP042EvolveInPlace logic
    // (same-system, higher rank) rather than adding a parallel code path;
    // this bumps form generation like a real evolution would, which is safe
    // for a rank-only change since it only resets in-flight schedule state.
    bool DSP042SetFixtureRank(int weaponIndex, int systemId, int rank,
        int logicalTic)
    {
        if (weaponIndex < 0 || weaponIndex >= dsp042WeaponSystems.Size()
            || dsp042WeaponSystems[weaponIndex] != systemId) return false;
        return DSP042EvolveInPlace(weaponIndex, systemId, rank, logicalTic);
    }

    int DSP042ActiveGunCount(int systemId)
    {
        int count = 0;
        for (int i = 0; i < dsp042GunActive.Size(); i++)
            if (dsp042GunActive[i] != 0 && dsp042GunSystems[i] == systemId) count++;
        return count;
    }

    // ---- Fire dispatch ------------------------------------------------------

    // facingYawMilli: current body facing (Phiera/Vento/Fuwala are
    // character-relative; Eight/Phieraggi ignore it -- fixed source plane).
    // P042-W07 item 2 (fuwala_heal): DSP042FireVolley below never forwards
    // DSP042FireArcVolley's healGateActive/healthBefore/maxHealth
    // parameters -- no existing mode needs Fuwalafuwaloo's crit-heal path,
    // so those three arguments are simply never wired through the generic
    // dispatch. Rather than add them to DSP042FireVolley itself (which would
    // require touching every call site across every already-landed mode,
    // e.g. union_matrix/attribution/patterns/burst_union, for zero benefit
    // to those modes), this is a narrow, Fuwala-only twin of
    // DSP042FireVolley's cooldown bookkeeping that forwards the heal
    // arguments and returns the milli-HP actually applied (0 if not fired,
    // not gated open, or not accepted). Only the fuwala_heal fixture calls
    // this; every other mode's DSP042FireVolley call sites and behavior are
    // completely unaffected.
    int DSP042FireFuwalaHealTestVolley(int weaponIndex, int logicalTic,
        int facingYawMilli, double originX, double originY,
        int cooldownMultiplierMilli, int mightMilli, int luckMilli,
        int healthBefore, int maxHealth)
    {
        if (weaponIndex < 0 || weaponIndex >= dsp042WeaponSystems.Size()
            || dsp042WeaponSystems[weaponIndex] != DSP042PairedRows.SYSTEM_FUWALA
            || !ValidParts(dsp042WeaponSlots[weaponIndex],
                dsp042WeaponGenerations[weaponIndex],
                dsp042WeaponIds[weaponIndex])) return 0;
        if (logicalTic < dsp042NextVolleyTics[weaponIndex]) return 0;

        int systemId = dsp042WeaponSystems[weaponIndex];
        int rank = dsp042WeaponRanks[weaponIndex];
        int amount = DSP042PairedRows.Amount(systemId, rank);
        int cooldownTics = DSP042PairedRows.CooldownTics(systemId, rank);
        if (amount <= 0 || cooldownTics <= 0) return 0;
        int adjustedCooldown = DSP033StatRules.CooldownAfterTome(systemId,
            cooldownTics * 1000 / Thinker.TICRATE, cooldownMultiplierMilli)
            * Thinker.TICRATE / 1000;
        if (adjustedCooldown < 1) adjustedCooldown = 1;
        dsp042NextVolleyTics[weaponIndex] = logicalTic + adjustedCooldown;
        int intervalTics = DSP042PairedRows.IntervalTics(systemId, rank);
        if (intervalTics < 0) intervalTics = 0;

        return DSP042FireArcVolley(weaponIndex, systemId, rank, amount,
            intervalTics, facingYawMilli, originX, originY, mightMilli,
            luckMilli, logicalTic, true, healthBefore, maxHealth);
    }

    // currentX/currentY: player position, fed to the movement-streak ledger
    // every call regardless of which system fires this tic.
    bool DSP042FireVolley(int weaponIndex, int logicalTic, int facingYawMilli,
        double originX, double originY, int cooldownMultiplierMilli,
        int mightMilli, int luckMilli)
    {
        if (weaponIndex < 0 || weaponIndex >= dsp042WeaponSystems.Size()
            || dsp042WeaponSystems[weaponIndex] == 0
            || !ValidParts(dsp042WeaponSlots[weaponIndex],
                dsp042WeaponGenerations[weaponIndex],
                dsp042WeaponIds[weaponIndex])) return false;
        if (logicalTic < dsp042NextVolleyTics[weaponIndex]) return false;

        int systemId = dsp042WeaponSystems[weaponIndex];
        int rank = dsp042WeaponRanks[weaponIndex];
        int amount = DSP042PairedRows.Amount(systemId, rank);
        int cooldownTics = DSP042PairedRows.CooldownTics(systemId, rank);
        if (amount <= 0 || cooldownTics <= 0) return false;
        if (rsActive) amount += RsAmountFor(systemId);
        mightMilli = LbMightFor(systemId, mightMilli);
        int adjustedCooldown = DSP033StatRules.CooldownAfterTome(systemId,
            cooldownTics * 1000 / Thinker.TICRATE, cooldownMultiplierMilli)
            * Thinker.TICRATE / 1000;
        if (adjustedCooldown < 1) adjustedCooldown = 1;
        dsp042NextVolleyTics[weaponIndex] = logicalTic + adjustedCooldown;
        int intervalTics = DSP042PairedRows.IntervalTics(systemId, rank);
        if (intervalTics < 0) intervalTics = 0;

        if (DSP042PairedRows.IsBird(systemId))
            DSP042FireBirdVolley(weaponIndex, systemId, rank, amount, intervalTics,
                originX, originY, mightMilli, logicalTic);
        else if (systemId == DSP042PairedRows.SYSTEM_VANDALIER)
            DSP042FireVandalierVolley(weaponIndex, rank, amount, intervalTics,
                originX, originY, mightMilli, logicalTic);
        else if (systemId == DSP042PairedRows.SYSTEM_PHIERA
            || systemId == DSP042PairedRows.SYSTEM_EIGHT)
            DSP042FireGunVolley(weaponIndex, systemId, rank, amount, intervalTics,
                facingYawMilli, originX, originY, mightMilli, logicalTic);
        else if (systemId == DSP042PairedRows.SYSTEM_PHIERAGGI)
            DSP042FirePhieraggiVolley(weaponIndex, rank, originX, originY,
                mightMilli, logicalTic);
        else if (systemId == DSP042PairedRows.SYSTEM_VENTO
            || systemId == DSP042PairedRows.SYSTEM_FUWALA)
        {
            // Normal play: Fuwalafuwaloo's critical slashes drain health back.
            let vs = DSP030VerticalSlice(self);
            bool drain = rsActive && vs != null && systemId == DSP042PairedRows.SYSTEM_FUWALA;
            int healthNow = drain ? vs.playerHealth : 0;
            int cap = drain ? vs.CurrentPlayerHealthCap() : 0;
            int healed = DSP042FireArcVolley(weaponIndex, systemId, rank, amount, intervalTics,
                facingYawMilli, originX, originY, mightMilli, luckMilli, logicalTic,
                drain, healthNow, cap);
            if (drain && healed > 0)
            {
                vs.playerHealth = min(cap, vs.playerHealth + healed);
                vs.health[vs.playerSlot] = vs.playerHealth;
                vs.FxCount("heal", healed);
                vs.Sfx(DSSfx.I_HEART, 20);
                vs.DSP039FeedSoulEaterGrowth(healed, logicalTic);
            }
            double yaw = facingYawMilli / 1000.0;
            double reach = DSP042PairedRows.VENTO_ARC_REACH * (rsActive ? RsAreaFor(systemId) : 1000) / 1000.0;
            DSP042Fx("WSLS", originX + cos(yaw) * reach * 0.5, originY + sin(yaw) * reach * 0.5, 18.0,
                reach * 0.9, reach * 1.3, false,
                systemId == DSP042PairedRows.SYSTEM_FUWALA ? Color(255, 230, 60, 90) : Color(255, 170, 255, 200), 9, yaw);
        }
        else if (DSP042PairedRows.IsBracelet(systemId))
            DSP042FireBraceletVolley(weaponIndex, systemId, rank, amount,
                intervalTics, originX, originY, mightMilli, logicalTic);
        else
            return false;
        return true;
    }

    // Presentation only, normal play: effect sprites for the paired weapons
    // that hit instantly (birds, beams, slashes, bracelets). Never read back.
    void DSP042Fx(String spr, double px, double py, double z, double s0, double s1,
        bool flat, Color tint, int life, double angle = 0.0)
    {
        if (!rsActive) return;
        DSWeaponFx f = DSWeaponFx.Make(spr, px, py, z, s0, s1, flat, tint, 0.9, life);
        if (f != null) f.Angle = angle;
    }

    // ---- Damage helper -------------------------------------------------

    bool DSP042ScaledDamage(int damageMilli, int mightMilli, out int amount)
    {
        amount = 0;
        if (damageMilli < 0 || mightMilli < 0
            || (mightMilli > 0 && damageMilli > 2000000000 / mightMilli))
            return false;
        amount = (damageMilli * mightMilli) / 1000 / 1000;
        return amount >= 0;
    }

    // Every instant-hit adapter (birds/Vandalier impacts, Phieraggi beams,
    // bracelet bursts) routes through this so attribution (owner weapon
    // handle, form generation, system) is recorded exactly once per hit.
    void DSP042ApplyInstantHit(int weaponIndex, int slot, int generation,
        int stableId, int damageMilli, int mightMilli, int logicalTic,
        String kind, int angleDeg = -999999)
    {
        int amount;
        if (!DSP042ScaledDamage(damageMilli, mightMilli, amount))
        { dsp042RejectedHits++; return; }
        int healthBefore; int healthAfter; int killed;
        arHitSystem = dsp042WeaponSystems[weaponIndex];   // which weapon hit (Arcana scope)
        if (!DSP025ApplyLogicalHit(slot, generation, stableId, amount,
                healthBefore, healthAfter, killed))
        { dsp042RejectedHits++; return; }
        dsp042AcceptedHits++;
        int trueDelta = healthBefore - healthAfter;
        if (trueDelta > 0 && dsp042AcceptedDamageMilli <= 2147483647 - trueDelta)
            dsp042AcceptedDamageMilli += trueDelta;
        int systemId = weaponIndex >= 0 ? dsp042WeaponSystems[weaponIndex] : 0;
        int weaponId = weaponIndex >= 0 ? dsp042WeaponIds[weaponIndex] : 0;
        int formGeneration = weaponIndex >= 0 ? dsp042WeaponFormGeneration[weaponIndex] : 0;
        { if (!dsQuiet) Console.Printf("DS_P042_HIT kind=%s tic=%d system_id=%d weapon_id=%d form_generation=%d target_id=%d damage=%d health_before=%d health_after=%d killed=%d angle_deg=%d", kind, logicalTic, systemId, weaponId, formGeneration, stableId, amount, healthBefore, healthAfter, killed, angleDeg); }
        if (killed != 0) HandleEnemyDeath(slot, healthBefore, DSP042NewEventId());
        else if (rsActive && weaponIndex >= 0 && DSP030VerticalSlice(self) != null)
            DSP030VerticalSlice(self).EnemyKnockback(slot, DSP030VerticalSlice(self).playerX, DSP030VerticalSlice(self).playerY,
                DSP042PairedRows.KnockbackMilli(systemId, dsp042WeaponRanks[weaponIndex]));
    }

    // ---- Birds: Peachone (CW) / Ebony Wings (CCW) --------------------------

    void DSP042FireBirdVolley(int weaponIndex, int systemId, int rank,
        int amount, int intervalTics, double originX, double originY,
        int mightMilli, int logicalTic)
    {
        int direction = DSP042PairedRows.RotationDirection(systemId);
        int damageMilli = DSP042PairedRows.DamageMilli(systemId, rank);
        int areaMilli = DSP042PairedRows.AreaMilli(systemId, rank)
            * (rsActive ? RsAreaFor(systemId) : 1000) / 1000;
        if (damageMilli <= 0 || areaMilli <= 0) return;
        double impactRadius = double(DSP042PairedRows.BIRD_IMPACT_RADIUS)
            * double(areaMilli) / 1000.0;
        int startAngle = direction >= 0 ? dsp042WeaponAngleDegCW[weaponIndex]
                                         : dsp042WeaponAngleDegCCW[weaponIndex];
        for (int ordinal = 0; ordinal < amount; ordinal++)
        {
            double pointX; double pointY; int angleDeg;
            DSP042BirdOrbitPoint(originX, originY, startAngle, direction,
                ordinal, amount, pointX, pointY, angleDeg);
            DSP042ResolveAreaImpact(weaponIndex, systemId, pointX, pointY,
                impactRadius, damageMilli, mightMilli, logicalTic, "BIRD", angleDeg);
        }
        int stepDeg = amount > 0 ? 360 / amount : 0;
        int advance = direction * amount * stepDeg;
        if (direction >= 0)
        {
            dsp042WeaponAngleDegCW[weaponIndex] =
                (dsp042WeaponAngleDegCW[weaponIndex] + advance) % 360;
            if (dsp042WeaponAngleDegCW[weaponIndex] < 0)
                dsp042WeaponAngleDegCW[weaponIndex] += 360;
        }
        else
        {
            dsp042WeaponAngleDegCCW[weaponIndex] =
                (dsp042WeaponAngleDegCCW[weaponIndex] + advance) % 360;
            if (dsp042WeaponAngleDegCCW[weaponIndex] < 0)
                dsp042WeaponAngleDegCCW[weaponIndex] += 360;
        }
    }

    // Vandalier: one handle, both directional streams, Amount split evenly.
    void DSP042FireVandalierVolley(int weaponIndex, int rank, int amount,
        int intervalTics, double originX, double originY, int mightMilli,
        int logicalTic)
    {
        int systemId = DSP042PairedRows.SYSTEM_VANDALIER;
        int damageMilli = DSP042PairedRows.DamageMilli(systemId, rank);
        int areaMilli = DSP042PairedRows.AreaMilli(systemId, rank)
            * (rsActive ? RsAreaFor(dsp042WeaponSystems[weaponIndex]) : 1000) / 1000;
        if (damageMilli <= 0 || areaMilli <= 0) return;
        double impactRadius = double(DSP042PairedRows.BIRD_IMPACT_RADIUS)
            * double(areaMilli) / 1000.0;
        int half = amount / 2;
        int other = amount - half;
        int startCw = dsp042WeaponAngleDegCW[weaponIndex];
        int startCcw = dsp042WeaponAngleDegCCW[weaponIndex];
        for (int ordinal = 0; ordinal < half; ordinal++)
        {
            double pointX; double pointY; int angleDeg;
            DSP042BirdOrbitPoint(originX, originY, startCw, 1, ordinal, half,
                pointX, pointY, angleDeg);
            DSP042ResolveAreaImpact(weaponIndex, systemId, pointX, pointY,
                impactRadius, damageMilli, mightMilli, logicalTic, "VANDALIER_CW", angleDeg);
        }
        for (int ordinal = 0; ordinal < other; ordinal++)
        {
            double pointX; double pointY; int angleDeg;
            DSP042BirdOrbitPoint(originX, originY, startCcw, -1, ordinal, other,
                pointX, pointY, angleDeg);
            DSP042ResolveAreaImpact(weaponIndex, systemId, pointX, pointY,
                impactRadius, damageMilli, mightMilli, logicalTic, "VANDALIER_CCW", angleDeg);
        }
        int stepCw = half > 0 ? 360 / half : 0;
        int stepCcw = other > 0 ? 360 / other : 0;
        dsp042WeaponAngleDegCW[weaponIndex] = (startCw + half * stepCw) % 360;
        dsp042WeaponAngleDegCCW[weaponIndex] = (startCcw - other * stepCcw + 3600000) % 360;
    }

    void DSP042ResolveAreaImpact(int weaponIndex, int systemId, double centerX,
        double centerY, double radiusUnits, int damageMilli, int mightMilli,
        int logicalTic, String kind, int angleDeg = -999999)
    {
        DSP042Fx("WRNG", centerX, centerY, 1.2, radiusUnits * 0.6, radiusUnits * 2.2, true,
            systemId == DSP042PairedRows.SYSTEM_EBONY ? Color(255, 150, 90, 230) : Color(255, 255, 190, 90), 10);
        DSP024RadiusCandidates(centerX, centerY, radiusUnits + 32.0);
        for (int i = 0; i < spatialCandidateCount; i++)
        {
            int slot = spatialCandidateSlots[i];
            int generation = spatialCandidateGenerations[i];
            int stableId = spatialCandidateIds[i];
            if (!ValidParts(slot, generation, stableId)
                || kinds[slot] != DSP042_TARGET_ENEMY || health[slot] <= 0) continue;
            double dx = x[slot] - centerX; double dy = y[slot] - centerY;
            double reach = collisionRadii[slot] + radiusUnits;
            if (dx * dx + dy * dy > reach * reach) continue;
            DSP042ApplyInstantHit(weaponIndex, slot, generation, stableId,
                damageMilli, mightMilli, logicalTic, kind, angleDeg);
        }
    }

    // ---- Guns: Phiera Der Tuphello / Eight The Sparrow ---------------------

    void DSP042FireGunVolley(int weaponIndex, int systemId, int rank,
        int amount, int intervalTics, int facingYawMilli, double originX,
        double originY, int mightMilli, int logicalTic)
    {
        int damageMilli = DSP042PairedRows.DamageMilli(systemId, rank);
        int speedMilli = DSP042PairedRows.SpeedMilli(systemId, rank)
            * (rsActive ? RsSpeedFor(systemId) : 1000) / 1000;
        int pierce = DSP042PairedRows.Pierce(systemId, rank);
        if (damageMilli <= 0 || speedMilli <= 0 || pierce <= 0) return;
        bool fixedPlane = DSP042PairedRows.IsFixedPlaneFacing(systemId);
        double speedUps = double(DSP042PairedRows.GUN_BASE_SPEED_UNITS_PER_SECOND)
            * double(speedMilli) / 1000.0;
        int intervalStep = intervalTics > 0 ? intervalTics : 1;
        for (int ordinal = 0; ordinal < amount; ordinal++)
        {
            int deg = fixedPlane ? DSP042FixedDiagonalDeg(ordinal % 4)
                                  : DSP042FacingRelativeDiagonalDeg(ordinal % 4, facingYawMilli);
            if (ordinal == 0)
            {
                if (DSP042ActiveGunCount(systemId) < DSP042_MAX_ACTIVE_GUNS)
                    DSP042SpawnGunNow(weaponIndex, systemId, deg, originX, originY,
                        speedUps, damageMilli, mightMilli, pierce, fixedPlane, logicalTic);
            }
            else
            {
                DSP042SchedulePendingGun(weaponIndex, systemId, deg, originX, originY,
                    speedUps, damageMilli, mightMilli, pierce,
                    logicalTic + ordinal * intervalStep);
            }
        }
    }

    // Spawns exactly one gun shot immediately under weaponIndex's CURRENT
    // owner/form-generation. Shared by ordinal 0 (always immediate) and the
    // pending queue once a later ordinal's due tic arrives and its owner is
    // still validated.
    void DSP042SpawnGunNow(int weaponIndex, int systemId, int deg,
        double originX, double originY, double speedUps, int damageMilli,
        int mightMilli, int pierce, bool fixedPlane, int logicalTic)
    {
        if (DSP042ActiveGunCount(systemId) >= DSP042_MAX_ACTIVE_GUNS) return;
        double dirX; double dirY;
        DSP042YawDirection(deg * 1000, dirX, dirY);
        int eventId = DSP042NewEventId();
        dsp042GunActive.Push(1); dsp042GunEvents.Push(eventId);
        dsp042GunSystems.Push(systemId);
        dsp042GunOwnerSlot.Push(dsp042WeaponSlots[weaponIndex]);
        dsp042GunOwnerGeneration.Push(dsp042WeaponGenerations[weaponIndex]);
        dsp042GunOwnerId.Push(dsp042WeaponIds[weaponIndex]);
        dsp042GunFormGeneration.Push(dsp042WeaponFormGeneration[weaponIndex]);
        dsp042GunX.Push(originX); dsp042GunY.Push(originY);
        dsp042GunDirX.Push(dirX); dsp042GunDirY.Push(dirY);
        dsp042GunSpeedUps.Push(speedUps);
        dsp042GunDamageMilli.Push(damageMilli); dsp042GunMightMilli.Push(mightMilli);
        dsp042GunPierceRemaining.Push(pierce);
        dsp042GunRadiusUnits.Push(DSP042PairedRows.GUN_PROJECTILE_RADIUS);
        DSP042PairedProxy proxy = DSP042PairedProxy(Actor.Spawn(
            "DSP042PairedProxy", (originX, originY, DSProjectileProxyBase.VISUAL_Z), NO_REPLACE));
        if (proxy != null) { proxy.logicalEventId = eventId; proxy.logicalSystemId = systemId; }
        dsp042GunProxies.Push(proxy);
        { if (!dsQuiet) Console.Printf("DS_P042_GUN_SPAWN event_id=%d tic=%d system_id=%d weapon_id=%d form_generation=%d angle_deg=%d speed_ups=%.6f pierce=%d fixed_plane=%d", eventId, logicalTic, systemId, dsp042WeaponIds[weaponIndex], dsp042WeaponFormGeneration[weaponIndex], deg, speedUps, pierce, fixedPlane ? 1 : 0); }
    }

    // Queues ordinal>=1 of a multi-shot gun volley. Snapshots weaponIndex's
    // system id + form generation NOW so DSP042ProcessPendingGuns can tell,
    // at the due tic, whether this weapon has since been cancelled/evolved
    // (union or in-place evolution) -- if so the child is dropped forever
    // and never emitted (contract "future emissions only").
    void DSP042SchedulePendingGun(int weaponIndex, int systemId, int deg,
        double originX, double originY, double speedUps, int damageMilli,
        int mightMilli, int pierce, int dueTic)
    {
        dsp042PendingGunWeaponIndex.Push(weaponIndex);
        dsp042PendingGunSystem.Push(systemId);
        dsp042PendingGunFormGeneration.Push(dsp042WeaponFormGeneration[weaponIndex]);
        dsp042PendingGunDeg.Push(deg);
        dsp042PendingGunOriginX.Push(originX); dsp042PendingGunOriginY.Push(originY);
        dsp042PendingGunSpeedUps.Push(speedUps);
        dsp042PendingGunDamageMilli.Push(damageMilli);
        dsp042PendingGunMightMilli.Push(mightMilli);
        dsp042PendingGunPierce.Push(pierce);
        dsp042PendingGunDueTic.Push(dueTic);
        dsp042PendingGunActive.Push(1);
        { if (!dsQuiet) Console.Printf("DS_P042_GUN_PENDING_SCHEDULE weapon_index=%d system_id=%d angle_deg=%d due_tic=%d", weaponIndex, systemId, deg, dueTic); }
    }

    // Runs every tic (from DSP042AdvanceTic): fires any pending gun shot
    // whose due tic has arrived, but only if its owning weaponIndex is
    // still the exact same system id AND form generation it was when
    // scheduled -- otherwise the shot is cancelled and never emitted.
    void DSP042ProcessPendingGuns(int logicalTic)
    {
        for (int i = 0; i < dsp042PendingGunActive.Size(); i++)
        {
            if (dsp042PendingGunActive[i] == 0) continue;
            if (logicalTic < dsp042PendingGunDueTic[i]) continue;
            dsp042PendingGunActive[i] = 0;
            int weaponIndex = dsp042PendingGunWeaponIndex[i];
            bool stillValid = weaponIndex >= 0 && weaponIndex < dsp042WeaponSystems.Size()
                && dsp042WeaponSystems[weaponIndex] == dsp042PendingGunSystem[i]
                && dsp042WeaponFormGeneration[weaponIndex] == dsp042PendingGunFormGeneration[i]
                && ValidParts(dsp042WeaponSlots[weaponIndex], dsp042WeaponGenerations[weaponIndex],
                    dsp042WeaponIds[weaponIndex]);
            if (!stillValid)
            {
                { if (!dsQuiet) Console.Printf("DS_P042_GUN_PENDING_CANCELLED weapon_index=%d system_id=%d angle_deg=%d due_tic=%d tic=%d reason=OWNER_INVALIDATED_BEFORE_DUE_TIC", weaponIndex, dsp042PendingGunSystem[i], dsp042PendingGunDeg[i], dsp042PendingGunDueTic[i], logicalTic); }
                continue;
            }
            bool fixedPlane = DSP042PairedRows.IsFixedPlaneFacing(dsp042PendingGunSystem[i]);
            DSP042SpawnGunNow(weaponIndex, dsp042PendingGunSystem[i], dsp042PendingGunDeg[i],
                dsp042PendingGunOriginX[i], dsp042PendingGunOriginY[i], dsp042PendingGunSpeedUps[i],
                dsp042PendingGunDamageMilli[i], dsp042PendingGunMightMilli[i],
                dsp042PendingGunPierce[i], fixedPlane, logicalTic);
        }
    }

    void DSP042ProcessGuns(int logicalTic)
    {
        for (int i = 0; i < dsp042GunActive.Size(); i++)
        {
            if (dsp042GunActive[i] == 0) continue;
            if (!ValidParts(dsp042GunOwnerSlot[i], dsp042GunOwnerGeneration[i],
                    dsp042GunOwnerId[i]))
            { DSP042RetireGun(i, "OWNER_GENERATION_REPLACED", logicalTic); continue; }

            double startX = dsp042GunX[i]; double startY = dsp042GunY[i];
            double stepX = dsp042GunDirX[i] * dsp042GunSpeedUps[i] / double(Thinker.TICRATE);
            double stepY = dsp042GunDirY[i] * dsp042GunSpeedUps[i] / double(Thinker.TICRATE);
            double endX = startX + stepX; double endY = startY + stepY;

            double wallFraction; double normalX; double normalY;
            int wallId = DSP042FindWallCrossing(startX, startY, endX, endY,
                wallFraction, normalX, normalY);
            double radius = double(dsp042GunRadiusUnits[i]);
            DSP024SweptCandidates(startX, startY, endX, endY, radius + 32.0);
            int hitDelayTics = 1;
            for (int c = 0; c < spatialCandidateCount; c++)
            {
                int slot = spatialCandidateSlots[c];
                int generation = spatialCandidateGenerations[c];
                int stableId = spatialCandidateIds[c];
                if (!ValidParts(slot, generation, stableId)
                    || kinds[slot] != DSP042_TARGET_ENEMY || health[slot] <= 0
                    || DSP042IsPairGated(dsp042GunEvents[i], slot, generation, stableId, logicalTic))
                    continue;
                double targetRadius = collisionRadii[slot] + radius;
                double dx = endX - startX; double dy = endY - startY;
                double mx = startX - x[slot]; double my = startY - y[slot];
                double a2 = dx * dx + dy * dy;
                double cc = mx * mx + my * my - targetRadius * targetRadius;
                bool hits;
                if (cc <= 0.0) hits = true;
                else if (a2 <= 0.0000001) hits = false;
                else
                {
                    double b2 = 2.0 * (mx * dx + my * dy);
                    double disc = b2 * b2 - 4.0 * a2 * cc;
                    if (disc < 0.0) hits = false;
                    else
                    {
                        double entry = (-b2 - sqrt(disc)) / (2.0 * a2);
                        hits = entry >= 0.0 && entry <= 1.0;
                    }
                }
                if (!hits) continue;
                DSP042SetPairReady(dsp042GunEvents[i], slot, generation, stableId,
                    logicalTic + hitDelayTics);
                int weaponIndex = DSP042WeaponIndexForOwner(dsp042GunOwnerSlot[i],
                    dsp042GunOwnerGeneration[i], dsp042GunOwnerId[i]);
                DSP042ApplyGunHit(i, weaponIndex, slot, generation, stableId, logicalTic);
                dsp042GunPierceRemaining[i]--;
                if (dsp042GunPierceRemaining[i] <= 0)
                { DSP042RetireGun(i, "PIERCE_EXHAUSTED", logicalTic); break; }
            }
            if (dsp042GunActive[i] == 0) continue;

            if (wallId != 0 && wallFraction <= 1.0)
            {
                dsp042GunX[i] = startX + stepX * wallFraction;
                dsp042GunY[i] = startY + stepY * wallFraction;
                DSP042RetireGun(i, "HIT_WALL", logicalTic);
                continue;
            }
            dsp042GunX[i] = endX; dsp042GunY[i] = endY;
        }
    }

    int DSP042WeaponIndexForOwner(int slot, int generation, int stableId)
    {
        for (int i = 0; i < dsp042WeaponSlots.Size(); i++)
            if (dsp042WeaponSlots[i] == slot && dsp042WeaponGenerations[i] == generation
                && dsp042WeaponIds[i] == stableId) return i;
        return -1;
    }

    void DSP042ApplyGunHit(int gunIndex, int weaponIndex, int slot,
        int generation, int stableId, int logicalTic)
    {
        int amount;
        if (!DSP042ScaledDamage(dsp042GunDamageMilli[gunIndex],
                dsp042GunMightMilli[gunIndex], amount))
        { dsp042RejectedHits++; return; }
        int healthBefore; int healthAfter; int killed;
        arHitSystem = dsp042GunSystems[gunIndex];   // which weapon hit (Arcana scope)
        if (!DSP025ApplyLogicalHit(slot, generation, stableId, amount,
                healthBefore, healthAfter, killed))
        { dsp042RejectedHits++; return; }
        dsp042AcceptedHits++;
        int trueDelta = healthBefore - healthAfter;
        if (trueDelta > 0 && dsp042AcceptedDamageMilli <= 2147483647 - trueDelta)
            dsp042AcceptedDamageMilli += trueDelta;
        { if (!dsQuiet) Console.Printf("DS_P042_HIT kind=GUN tic=%d system_id=%d weapon_id=%d form_generation=%d target_id=%d damage=%d health_before=%d health_after=%d killed=%d", logicalTic, dsp042GunSystems[gunIndex], dsp042GunOwnerId[gunIndex], dsp042GunFormGeneration[gunIndex], stableId, amount, healthBefore, healthAfter, killed); }
        if (killed != 0) HandleEnemyDeath(slot, healthBefore, dsp042GunEvents[gunIndex]);
        else if (rsActive && weaponIndex >= 0 && DSP030VerticalSlice(self) != null)
            DSP030VerticalSlice(self).EnemyKnockback(slot, DSP030VerticalSlice(self).playerX, DSP030VerticalSlice(self).playerY,
                DSP042PairedRows.KnockbackMilli(dsp042GunSystems[gunIndex], dsp042WeaponRanks[weaponIndex]));
    }

    void DSP042RetireGun(int index, String reason, int logicalTic)
    {
        if (index < 0 || index >= dsp042GunActive.Size() || dsp042GunActive[index] == 0) return;
        dsp042GunActive[index] = 0;
        if (dsp042GunProxies[index] != null)
        { dsp042GunProxies[index].Destroy(); dsp042GunProxies[index] = null; }
        { if (!dsQuiet) Console.Printf("DS_P042_GUN_END event_id=%d tic=%d system_id=%d reason=%s", dsp042GunEvents[index], logicalTic, dsp042GunSystems[index], reason); }
    }

    int DSP042FindWallCrossing(double startX, double startY, double endX,
        double endY, out double fraction, out double normalX, out double normalY)
    {
        int bestId = 0;
        fraction = 2.0; normalX = 0.0; normalY = 0.0;
        double rx = endX - startX; double ry = endY - startY;
        for (int i = 0; i < dsp042WallIds.Size(); i++)
        {
            double sx = dsp042WallEndX[i] - dsp042WallStartX[i];
            double sy = dsp042WallEndY[i] - dsp042WallStartY[i];
            double denom = rx * sy - ry * sx;
            if (denom == 0.0) continue;
            double qx = dsp042WallStartX[i] - startX; double qy = dsp042WallStartY[i] - startY;
            double t = (qx * sy - qy * sx) / denom;
            double u = (qx * ry - qy * rx) / denom;
            if (t <= 0.0000001 || t > 1.0 || u < 0.0 || u > 1.0) continue;
            bool better = bestId == 0 || t < fraction;
            if (!better) continue;
            fraction = t; bestId = dsp042WallIds[i];
        }
        return bestId;
    }

    bool DSP042IsPairGated(int eventId, int slot, int generation, int stableId, int logicalTic)
    {
        for (int i = 0; i < dsp042PairEvents.Size(); i++)
            if (dsp042PairEvents[i] == eventId && dsp042PairSlots[i] == slot
                && dsp042PairGenerations[i] == generation && dsp042PairIds[i] == stableId)
                return logicalTic < dsp042PairReadyTic[i];
        return false;
    }

    void DSP042SetPairReady(int eventId, int slot, int generation, int stableId, int readyTic)
    {
        for (int i = 0; i < dsp042PairEvents.Size(); i++)
            if (dsp042PairEvents[i] == eventId && dsp042PairSlots[i] == slot
                && dsp042PairGenerations[i] == generation && dsp042PairIds[i] == stableId)
            { dsp042PairReadyTic[i] = readyTic; return; }
        dsp042PairEvents.Push(eventId); dsp042PairSlots.Push(slot);
        dsp042PairGenerations.Push(generation); dsp042PairIds.Push(stableId);
        dsp042PairReadyTic.Push(readyTic);
    }

    // ---- Phieraggi: four wall-passing rotating beams -----------------------

    void DSP042FirePhieraggiVolley(int weaponIndex, int rank, double originX,
        double originY, int mightMilli, int logicalTic)
    {
        int systemId = DSP042PairedRows.SYSTEM_PHIERAGGI;
        int damageMilli = DSP042PairedRows.DamageMilli(systemId, rank);
        if (damageMilli <= 0) return;
        int startDeg = dsp042WeaponBeamAngleDeg[weaponIndex];
        { if (!dsQuiet) Console.Printf("DS_P042_PHIERAGGI_VOLLEY weapon_index=%d tic=%d start_deg=%d", weaponIndex, logicalTic, startDeg); }
        for (int beam = 0; beam < 4; beam++)
        {
            int deg = (startDeg + beam * 90) % 360;
            double dirX; double dirY;
            DSP042YawDirection(deg * 1000, dirX, dirY);
            double endX = originX + dirX * double(DSP042_PHIERAGGI_BEAM_LENGTH);
            double endY = originY + dirY * double(DSP042_PHIERAGGI_BEAM_LENGTH);
            for (int bead = 1; bead <= 10; bead++)
                DSP042Fx("WORB", originX + dirX * 32.0 * bead, originY + dirY * 32.0 * bead, 20.0, 14.0, 6.0, false,
                    beam % 2 == 0 ? Color(255, 255, 80, 80) : Color(255, 240, 240, 255), 7);
            DSP024SweptCandidates(originX, originY, endX, endY, 40.0);
            for (int c = 0; c < spatialCandidateCount; c++)
            {
                int slot = spatialCandidateSlots[c];
                int generation = spatialCandidateGenerations[c];
                int stableId = spatialCandidateIds[c];
                if (!ValidParts(slot, generation, stableId)
                    || kinds[slot] != DSP042_TARGET_ENEMY || health[slot] <= 0) continue;
                double dx = endX - originX; double dy = endY - originY;
                double mx = originX - x[slot]; double my = originY - y[slot];
                double a2 = dx * dx + dy * dy;
                double targetRadius = collisionRadii[slot] + 6.0;
                double cc = mx * mx + my * my - targetRadius * targetRadius;
                bool hits;
                if (cc <= 0.0) hits = true;
                else if (a2 <= 0.0000001) hits = false;
                else
                {
                    double b2 = 2.0 * (mx * dx + my * dy);
                    double disc = b2 * b2 - 4.0 * a2 * cc;
                    hits = disc >= 0.0 && (-b2 - sqrt(disc)) / (2.0 * a2) <= 1.0
                        && (-b2 - sqrt(disc)) / (2.0 * a2) >= 0.0;
                }
                if (!hits) continue;
                DSP042ApplyInstantHit(weaponIndex, slot, generation, stableId,
                    damageMilli, mightMilli, logicalTic, "PHIERAGGI_BEAM", deg);
            }
        }
        dsp042WeaponBeamAngleDeg[weaponIndex] =
            (startDeg + DSP042PairedRows.PHIERAGGI_ROTATION_STEP_DEG) % 360;
    }

    // ---- Vento Sacro / Fuwalafuwaloo facing-arc slash ----------------------

    // healthBefore/maxHealth/runActive are supplied by the caller (owning
    // class), which is the only place that knows the real player-health
    // fields; this mixin never touches them outside this call. Returns the
    // healed amount actually applied via DSP039ApplyHeal (0 if not accepted
    // or not gated-open).
    int DSP042FireArcVolley(int weaponIndex, int systemId, int rank,
        int amount, int intervalTics, int facingYawMilli, double originX,
        double originY, int mightMilli, int luckMilli, int logicalTic,
        bool healGateActive = false, int healthBefore = 0, int maxHealth = 0)
    {
        int damageMilli = DSP042PairedRows.DamageMilli(systemId, rank);
        int areaMilli = DSP042PairedRows.AreaMilli(systemId, rank)
            * (rsActive ? RsAreaFor(systemId) : 1000) / 1000;
        if (damageMilli <= 0 || areaMilli <= 0) return 0;
        double reach = double(DSP042PairedRows.VENTO_ARC_REACH) * double(areaMilli) / 1000.0;
        int critChanceMilli = DSP042PairedRows.CritChanceMilli(systemId, rank);
        int critMulMilli = DSP042PairedRows.CritMultiplierMilli(systemId, rank);
        int stepMilli = DSP042PairedRows.MovementStreakStepMilli(systemId, rank);
        int capMilli = DSP042PairedRows.MovementStreakCapMilli(systemId, rank);
        // Reads the streak ledger only (DSP042PeekMoveStreakBonus); the
        // ledger itself is advanced once per real logical tic by the owning
        // WorldTick's DSP042TickMoveStreak call, not by this fire call, so
        // "N x 35 continuous-movement tics" is measured in real tics rather
        // than in ~70-tic-cooldown-spaced fire events (vento_streak mode).
        int streakBonusMilli = DSP042PeekMoveStreakBonus(stepMilli, capMilli);
        bool isFuwala = systemId == DSP042PairedRows.SYSTEM_FUWALA;
        int healedTotal = 0;

        DSP024RadiusCandidates(originX, originY, reach + 32.0);
        for (int slash = 0; slash < amount; slash++)
        {
            for (int i = 0; i < spatialCandidateCount; i++)
            {
                int slot = spatialCandidateSlots[i];
                int generation = spatialCandidateGenerations[i];
                int stableId = spatialCandidateIds[i];
                if (!ValidParts(slot, generation, stableId)
                    || kinds[slot] != DSP042_TARGET_ENEMY || health[slot] <= 0) continue;
                if (!DSP042InFacingArc(originX, originY, x[slot], y[slot],
                        facingYawMilli, reach, DSP042PairedRows.VENTO_ARC_HALF_DEG)) continue;

                int rngBefore; int rngAfter; int rollMilli;
                bool critical = critChanceMilli > 0
                    && DSP042RollCrit(critChanceMilli, luckMilli, rngBefore, rngAfter, rollMilli);
                int effectiveDamageMilli = critical ? damageMilli * critMulMilli / 1000 : damageMilli;
                int amountBase;
                if (!DSP042ScaledDamage(effectiveDamageMilli, mightMilli, amountBase))
                { dsp042RejectedHits++; continue; }
                int totalAmount = amountBase + streakBonusMilli / 1000;
                int hBefore; int hAfter; int killed;
                arHitSystem = systemId;   // which weapon hit (Arcana scope)
                if (!DSP025ApplyLogicalHit(slot, generation, stableId, totalAmount,
                        hBefore, hAfter, killed))
                { dsp042RejectedHits++; continue; }
                dsp042AcceptedHits++;
                int trueDelta = hBefore - hAfter;
                if (trueDelta > 0 && dsp042AcceptedDamageMilli <= 2147483647 - trueDelta)
                    dsp042AcceptedDamageMilli += trueDelta;
                { if (!dsQuiet) Console.Printf("DS_P042_HIT kind=%s tic=%d system_id=%d weapon_id=%d form_generation=%d target_id=%d damage=%d streak_bonus_milli=%d critical=%d health_before=%d health_after=%d killed=%d rng_stream=DEDICATED_P042_CRIT rng_before=%d rng_after=%d", isFuwala ? "FUWALA_ARC" : "VENTO_ARC", logicalTic, systemId, dsp042WeaponIds[weaponIndex], dsp042WeaponFormGeneration[weaponIndex], stableId, totalAmount, streakBonusMilli, critical ? 1 : 0, hBefore, hAfter, killed, rngBefore, rngAfter); }
                if (critical && rsActive && DSP030VerticalSlice(self) != null)
                {
                    DSP030VerticalSlice(self).FxCount("crit");
                    DSP030VerticalSlice(self).OnCrit(x[slot], y[slot], systemId);
                }
                if (killed != 0) HandleEnemyDeath(slot, hBefore, DSP042NewEventId());
                else if (rsActive && DSP030VerticalSlice(self) != null)
                    DSP030VerticalSlice(self).EnemyKnockback(slot, originX, originY, DSP042PairedRows.KnockbackMilli(systemId, rank));

                if (isFuwala && critical && healGateActive
                    && logicalTic >= dsp042FuwalaHealReadyTic)
                {
                    int healthAfter; int appliedMilli;
                    bool accepted = DSP039ApplyHeal(9 /* SOURCE_FIXTURE-equivalent for P042 */,
                        DSP042PairedRows.FUWALA_HEAL_MILLI, logicalTic, true,
                        healthBefore, maxHealth, healthAfter, appliedMilli);
                    if (accepted)
                    {
                        dsp042FuwalaHealReadyTic = logicalTic + DSP042PairedRows.FUWALA_HEAL_GATE_TICS;
                        healedTotal += appliedMilli;
                        healthBefore = healthAfter;
                    }
                }
            }
        }
        return healedTotal;
    }

    // ---- Bracelets: nearest-target aimed bursts ---------------------------

    void DSP042FireBraceletVolley(int weaponIndex, int systemId, int rank,
        int amount, int intervalTics, double originX, double originY,
        int mightMilli, int logicalTic)
    {
        int damageMilli = DSP042PairedRows.DamageMilli(systemId, rank);
        if (damageMilli <= 0) return;
        for (int ordinal = 0; ordinal < amount; ordinal++)
        {
            int targetSlot; int targetGeneration; int targetStableId; double distSq;
            if (!DSP034SelectNearestTarget(DSP042_TARGET_ENEMY, originX, originY,
                    600.0, targetSlot, targetGeneration, targetStableId, distSq))
            {
                { if (!dsQuiet) Console.Printf("DS_P042_BRACELET_MISS tic=%d system_id=%d ordinal=%d reason=NO_TARGET", logicalTic, systemId, ordinal); }
                continue;
            }
            double tx = x[targetSlot]; double ty = y[targetSlot];
            double dx = tx - originX; double dy = ty - originY;
            for (int bead = 1; bead <= 4; bead++)
                DSP042Fx("WBUL", originX + dx * bead / 4.0, originY + dy * bead / 4.0, 20.0, 10.0, 6.0, false,
                    Color(255, 255, 230, 120), 5);
            DSP042ApplyInstantHit(weaponIndex, targetSlot, targetGeneration,
                targetStableId, damageMilli, mightMilli, logicalTic, "BRACELET");
            // Tri-Bracelet: each burst splits on impact into two more hits on
            // enemies near the target (wiki approximation: half damage).
            if (systemId == DSP042PairedRows.SYSTEM_TRI_BRACELET && rsActive)
            {
                DSP024RadiusCandidates(tx, ty, 72.0);
                int splits = 0;
                for (int c = 0; c < spatialCandidateCount && splits < 2; c++)
                {
                    int slot = spatialCandidateSlots[c];
                    if (slot == targetSlot || !ValidParts(slot, spatialCandidateGenerations[c], spatialCandidateIds[c])
                        || kinds[slot] != DSP042_TARGET_ENEMY || health[slot] <= 0) continue;
                    DSP042Fx("WBUL", x[slot], y[slot], 20.0, 12.0, 4.0, false, Color(255, 255, 200, 255), 6);
                    DSP042ApplyInstantHit(weaponIndex, slot, spatialCandidateGenerations[c], spatialCandidateIds[c],
                        damageMilli / 2, mightMilli, logicalTic, "BRACELET_SPLIT");
                    splits++;
                }
                if (splits > 0 && DSP030VerticalSlice(self) != null) DSP030VerticalSlice(self).FxCount("bracelet_split", splits);
            }
        }
    }

    // ---- Per-tic driver / rebase / hash ------------------------------------

    void DSP042AdvanceTic(int logicalTic)
    {
        DSP042ProcessPendingGuns(logicalTic);
        DSP042ProcessGuns(logicalTic);
    }

    void DSP042Rebase(double deltaX, double deltaY, int logicalTic)
    {
        int moved = 0;
        for (int i = 0; i < dsp042GunActive.Size(); i++)
        {
            if (dsp042GunActive[i] == 0) continue;
            dsp042GunX[i] += deltaX; dsp042GunY[i] += deltaY;
            moved++;
        }
        { if (!dsQuiet) Console.Printf("DS_P042_REBASE tic=%d delta_x=%.6f delta_y=%.6f guns_translated=%d", logicalTic, deltaX, deltaY, moved); }
    }

    int DSP042PersistenceHash()
    {
        int hash = 1913877598;
        for (int i = 0; i < dsp042WeaponSystems.Size(); i++)
        {
            hash = hash ^ dsp042WeaponSystems[i];
            hash = DSP025NextAttackRng(hash);
            hash = hash ^ dsp042WeaponRanks[i];
            hash = DSP025NextAttackRng(hash);
            hash = hash ^ dsp042WeaponFormGeneration[i];
            hash = DSP025NextAttackRng(hash);
            hash = hash ^ dsp042WeaponAngleDegCW[i];
            hash = DSP025NextAttackRng(hash);
            hash = hash ^ dsp042WeaponAngleDegCCW[i];
            hash = DSP025NextAttackRng(hash);
            hash = hash ^ dsp042WeaponBeamAngleDeg[i];
            hash = DSP025NextAttackRng(hash);
        }
        for (int i = 0; i < dsp042GunActive.Size(); i++)
        {
            if (dsp042GunActive[i] == 0) continue;
            hash = hash ^ dsp042GunEvents[i];
            hash = DSP025NextAttackRng(hash);
            hash = hash ^ int(dsp042GunX[i] * 1000.0);
            hash = DSP025NextAttackRng(hash);
            hash = hash ^ int(dsp042GunY[i] * 1000.0);
            hash = DSP025NextAttackRng(hash);
            hash = hash ^ dsp042GunPierceRemaining[i];
            hash = DSP025NextAttackRng(hash);
        }
        // Pending (un-emitted) gun ordinals -- e.g. a Phiera/Eight rank-8
        // amount=3 volley's ordinals 1/2 -- are real in-flight schedule
        // state (P042-A02/save-load item 4 "pending output schedule") and
        // must be part of exact save/load hash equality; they were
        // previously omitted here.
        for (int i = 0; i < dsp042PendingGunActive.Size(); i++)
        {
            if (dsp042PendingGunActive[i] == 0) continue;
            hash = hash ^ dsp042PendingGunWeaponIndex[i];
            hash = DSP025NextAttackRng(hash);
            hash = hash ^ dsp042PendingGunSystem[i];
            hash = DSP025NextAttackRng(hash);
            hash = hash ^ dsp042PendingGunFormGeneration[i];
            hash = DSP025NextAttackRng(hash);
            hash = hash ^ dsp042PendingGunDeg[i];
            hash = DSP025NextAttackRng(hash);
            hash = hash ^ dsp042PendingGunDueTic[i];
            hash = DSP025NextAttackRng(hash);
        }
        hash = hash ^ dsp042MoveStreakTics;
        hash = DSP025NextAttackRng(hash);
        hash = hash ^ dsp042FuwalaHealReadyTic;
        hash = DSP025NextAttackRng(hash);
        // Persistence contract ("movement-streak state, crit stream and heal
        // gate") requires the dedicated P042_CRIT RNG stream itself to be
        // part of exact save/load hash equality, not just its downstream
        // effects.
        hash = hash ^ dsp042CritRng;
        return hash;
    }
}
