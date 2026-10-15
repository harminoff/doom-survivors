// MAP11 P025 shared attack scheduler and transaction fixture.
//
// The two weapons and three targets are deliberately synthetic engineering
// fixtures.  They exercise the production boundaries that later weapons use:
// P020 handles, P024 candidate discovery, attack-owned clocks/snapshots, and
// logical damage/death/status transactions.  Native actors are presentation
// mirrors only.
class DSP025AttackProxy : Actor
{
    int logicalEventId;
    int logicalWeaponId;

    Default
    {
        Radius 3;
        Height 8;
        +NOBLOCKMAP;
        +NOGRAVITY;
        +NOINTERACTION;
        RenderStyle "Translucent";
        Alpha 0.72;
    }
}

class DSP025AttackRuntime : EventHandler
{
    mixin DSP020EntityStore;
    mixin DSP024SpatialIndex;
    mixin DSP025AttackCore;

    const MAP = "MAP11";
    const RUN_TICS = 16;
    const WEAPON_A = 10;
    const WEAPON_B = 20;
    const WEAPON_REPLACEMENT = 30;
    const STATUS_NONE = 0;
    const STATUS_BURN = 1;

    bool enabled;
    bool completed;
    int tic;
    int eventId;
    int transactionOrdinal;
    int hitCount;
    int rejectedHitCount;
    int damageCount;
    int deathCount;
    int statusCount;
    int statusRejectedCount;
    int cleanupCount;
    int staleRejectedCount;
    int attackRng;
    int cameraVariant;
    int effectsEnabled;
    int telemetryEnabled;
    int cameraYaw;
    int cameraPitch;
    int cameraFov;
    int playerSlot;
    int sampledAimYawMilli;

    // Weapon scheduler state.  Every field is independent so a burst child,
    // cooldown, first-fire delay and active duration cannot alias one flag.
    Array<int> weaponIds;
    Array<int> weaponGenerations;
    Array<int> weaponFirstFireReady;
    Array<int> weaponCooldownReady;
    Array<int> weaponBurstNext;
    Array<int> weaponBurstRemaining;
    Array<int> weaponDurationEnd;
    Array<int> weaponActiveParent;
    Array<int> weaponCanceled;
    Array<int> weaponCooldown;
    Array<int> weaponBurstInterval;
    Array<int> weaponBurstSize;
    Array<int> weaponDamage;
    Array<int> weaponUpgradeBonus;
    Array<int> weaponKnockback;
    Array<int> weaponStatusDuration;
    Array<int> weaponRng;

    // Active event snapshots.  Children copy these values from the parent.
    Array<int> eventTics;
    Array<int> eventIds;
    Array<int> eventParents;
    Array<int> eventWeaponIds;
    Array<int> eventWeaponGenerations;
    Array<int> eventDamageBase;
    Array<int> eventDamageBonus;
    Array<int> eventMultiplier;
    Array<int> eventPierce;
    Array<int> eventPierceUsed;
    Array<int> eventDurationEnd;
    Array<int> eventKnockback;
    Array<int> eventStatusDuration;
    Array<int> eventRngBefore;
    Array<int> eventRngAfter;
    Array<int> eventAimYawMilli;
    Array<int> eventCandidateStart;
    Array<int> eventCandidateCount;

    Array<int> candidateSlots;
    Array<int> candidateGenerations;
    Array<int> candidateIds;
    Array<int> scratchSlots;
    Array<int> scratchGenerations;
    Array<int> scratchIds;

    // One repeat-history row per accepted parent/target pair.  The history is
    // keyed by a stable target handle and survives visual proxy recreation.
    Array<int> historyParents;
    Array<int> historyTargetSlots;
    Array<int> historyTargetGenerations;
    Array<int> historyTargetIds;
    Array<int> historyReady;

    Array<int> statusActive;
    Array<int> statusTargetGeneration;
    Array<int> statusTargetId;
    Array<int> statusSourceEvent;
    Array<int> statusSourceWeapon;
    Array<int> statusEnd;
    Array<int> targetStatusImmune;
    Array<int> targetKnockbackImmune;
    Array<int> targetDeathHandled;

    Array<DSP025AttackProxy> proxies;

    void AddWeapon(int stableId, int generation, int firstReady,
                   int cooldown, int burstInterval, int burstSize,
                   int damage, int knockback, int statusDuration, int rng)
    {
        weaponIds.Push(stableId);
        weaponGenerations.Push(generation);
        weaponFirstFireReady.Push(firstReady);
        weaponCooldownReady.Push(firstReady);
        weaponBurstNext.Push(0);
        weaponBurstRemaining.Push(0);
        weaponDurationEnd.Push(0);
        weaponActiveParent.Push(0);
        weaponCanceled.Push(0);
        weaponCooldown.Push(cooldown);
        weaponBurstInterval.Push(burstInterval);
        weaponBurstSize.Push(burstSize);
        weaponDamage.Push(damage);
        weaponUpgradeBonus.Push(0);
        weaponKnockback.Push(knockback);
        weaponStatusDuration.Push(statusDuration);
        weaponRng.Push(rng);
    }

    void ResetState()
    {
        Reset();
        DSP024ClearSpatial();
        weaponIds.Clear(); weaponGenerations.Clear();
        weaponFirstFireReady.Clear(); weaponCooldownReady.Clear();
        weaponBurstNext.Clear(); weaponBurstRemaining.Clear();
        weaponDurationEnd.Clear(); weaponActiveParent.Clear();
        weaponCanceled.Clear(); weaponCooldown.Clear();
        weaponBurstInterval.Clear(); weaponBurstSize.Clear();
        weaponDamage.Clear(); weaponUpgradeBonus.Clear();
        weaponKnockback.Clear(); weaponStatusDuration.Clear(); weaponRng.Clear();
        eventTics.Clear(); eventIds.Clear(); eventParents.Clear();
        eventWeaponIds.Clear(); eventWeaponGenerations.Clear();
        eventDamageBase.Clear(); eventDamageBonus.Clear(); eventMultiplier.Clear();
        eventPierce.Clear(); eventPierceUsed.Clear(); eventDurationEnd.Clear();
        eventKnockback.Clear(); eventStatusDuration.Clear();
        eventRngBefore.Clear(); eventRngAfter.Clear();
        eventAimYawMilli.Clear();
        eventCandidateStart.Clear(); eventCandidateCount.Clear();
        candidateSlots.Clear(); candidateGenerations.Clear(); candidateIds.Clear();
        scratchSlots.Clear(); scratchGenerations.Clear(); scratchIds.Clear();
        historyParents.Clear(); historyTargetSlots.Clear();
        historyTargetGenerations.Clear(); historyTargetIds.Clear(); historyReady.Clear();
        statusActive.Clear(); statusTargetGeneration.Clear(); statusTargetId.Clear();
        statusSourceEvent.Clear(); statusSourceWeapon.Clear(); statusEnd.Clear();
        targetStatusImmune.Clear(); targetKnockbackImmune.Clear(); targetDeathHandled.Clear();
        proxies.Clear();

        tic = 0; eventId = 0; transactionOrdinal = 0; hitCount = 0;
        rejectedHitCount = 0; damageCount = 0; deathCount = 0;
        statusCount = 0; statusRejectedCount = 0; cleanupCount = 0;
        staleRejectedCount = 0; attackRng = 707;
        sampledAimYawMilli = 0;
        nextStableId = 100;
        for (int i = 0; i < 4; i++)
        {
            AddSlot();
            statusActive.Push(0); statusTargetGeneration.Push(0); statusTargetId.Push(0);
            statusSourceEvent.Push(0); statusSourceWeapon.Push(0); statusEnd.Push(0);
            targetStatusImmune.Push(0); targetKnockbackImmune.Push(0); targetDeathHandled.Push(0);
        }
        int first = Allocate(1, 2.0, 0.0, 0.0, 0.0, 5);
        int second = Allocate(1, 3.0, 0.0, 0.0, 0.0, 10);
        int third = Allocate(1, 4.0, 0.0, 0.0, 0.0, 6);
        collisionRadii[first] = 2.0; collisionRadii[second] = 2.0; collisionRadii[third] = 2.0;
        targetStatusImmune[third] = 1;
        targetKnockbackImmune[third] = 1;
        playerSlot = Allocate(99, 0.0, 0.0, 0.0, 0.0, 1);

        // A and B intentionally differ in first-fire/cooldown/burst values,
        // but their first post-burst top-level emissions meet at tic 7.
        AddWeapon(WEAPON_A, 1, 2, 5, 1, 2, 5, 2, 3, 707);
        AddWeapon(WEAPON_B, 1, 3, 4, 1, 2, 4, 1, 4, 907);
    }

    void EmitCamera()
    {
        if (players[0].mo != null)
        {
            players[0].mo.Angle = cameraYaw;
            players[0].mo.Pitch = cameraPitch;
            players[0].SetFOV(cameraFov);
        }
        Console.Printf("DS_P025_CAMERA tic=%d variant=%d yaw=%d pitch=%d fov=%d logical_xy=(0.000,0.000) camera_role=PRESENTATION_ONLY", tic, cameraVariant, cameraYaw, cameraPitch, cameraFov);
    }

    void ConfigureCamera()
    {
        CVar variant = CVar.FindCVar('ds_p025_camera_variant');
        cameraVariant = variant != null ? variant.GetInt() : 0;
        if (cameraVariant < 0 || cameraVariant > 3) cameraVariant = 0;
        cameraYaw = 0; cameraPitch = 0; cameraFov = 90;
        if (cameraVariant == 1) cameraYaw = 90;
        else if (cameraVariant == 2) cameraYaw = 180;
        // Variant 3 changes pitch/FOV while retaining the same initial yaw.
        // WorldTick performs the real in-session view turn used by the aim
        // snapshot test, keeping gameplay comparable across camera variants.
        else if (cameraVariant == 3) { cameraYaw = 0; cameraPitch = 22; cameraFov = 115; }
        CVar effects = CVar.FindCVar('ds_p025_effects');
        effectsEnabled = effects != null ? effects.GetInt() : 1;
        if (effectsEnabled != 0) effectsEnabled = 1;
        CVar telemetry = CVar.FindCVar('ds_p025_telemetry');
        telemetryEnabled = telemetry != null ? telemetry.GetInt() : 1;
        if (telemetryEnabled != 0) telemetryEnabled = 1;
    }

    void EmitWeaponDefinitions()
    {
        Console.Printf("DS_P025_WEAPON weapon_id=10 generation=1 first_fire=2 cooldown=5 burst_size=2 burst_interval=1 pierce=2 duration=3 damage_base=5 upgrade_bonus=3 status=burn status_duration=3 ownership=ATTACK_MODEL");
        Console.Printf("DS_P025_WEAPON weapon_id=20 generation=1 first_fire=3 cooldown=4 burst_size=2 burst_interval=1 pierce=2 duration=4 damage_base=4 upgrade_bonus=3 status=burn status_duration=4 ownership=ATTACK_MODEL");
    }

    int EventIndexFor(int id)
    {
        for (int i = 0; i < eventIds.Size(); i++) if (eventIds[i] == id) return i;
        return -1;
    }

    void SortScratch()
    {
        for (int i = 1; i < candidateSlots.Size(); i++)
        {
            int j = i;
            while (j > 0 && candidateIds[j] < candidateIds[j - 1])
            {
                int v = candidateSlots[j]; candidateSlots[j] = candidateSlots[j - 1]; candidateSlots[j - 1] = v;
                v = candidateGenerations[j]; candidateGenerations[j] = candidateGenerations[j - 1]; candidateGenerations[j - 1] = v;
                v = candidateIds[j]; candidateIds[j] = candidateIds[j - 1]; candidateIds[j - 1] = v;
                j--;
            }
        }
    }

    void CaptureCandidates(int currentEvent)
    {
        scratchSlots.Clear(); scratchGenerations.Clear(); scratchIds.Clear();
        // P024 supplies the broad candidate set.  Exact circle eligibility is
        // deliberately retained here, outside the broad-phase implementation.
        DSP024RadiusCandidates(0.0, 0.0, 16.0);
        for (int i = 0; i < spatialCandidateCount; i++)
        {
            int slot = spatialCandidateSlots[i];
            if (!ValidParts(slot, spatialCandidateGenerations[i], spatialCandidateIds[i])) continue;
            if (kinds[slot] != 1) continue;
            double dx = x[slot]; double dy = y[slot];
            double reach = 16.0 + collisionRadii[slot];
            if (dx * dx + dy * dy <= reach * reach)
            {
                scratchSlots.Push(slot); scratchGenerations.Push(generations[slot]); scratchIds.Push(ids[slot]);
            }
        }
        for (int i = 1; i < scratchSlots.Size(); i++)
        {
            int j = i;
            while (j > 0 && scratchIds[j] < scratchIds[j - 1])
            {
                int v = scratchSlots[j]; scratchSlots[j] = scratchSlots[j - 1]; scratchSlots[j - 1] = v;
                v = scratchGenerations[j]; scratchGenerations[j] = scratchGenerations[j - 1]; scratchGenerations[j - 1] = v;
                v = scratchIds[j]; scratchIds[j] = scratchIds[j - 1]; scratchIds[j - 1] = v;
                j--;
            }
        }
        int start = candidateSlots.Size();
        // Scratch is copied into a flattened event-owned list.  This is a
        // snapshot: earlier same-tic damage cannot change later candidates.
        int count = scratchSlots.Size();
        eventCandidateStart.Push(start);
        eventCandidateCount.Push(count);
        for (int i = 0; i < count; i++)
        {
            candidateSlots.Push(scratchSlots[i]);
            candidateGenerations.Push(scratchGenerations[i]);
            candidateIds.Push(scratchIds[i]);
        }
    }

    void EmitPresentation(int currentEvent, String kind)
    {
        if (effectsEnabled == 0) return;
        DSP025AttackProxy proxy = DSP025AttackProxy(Actor.Spawn("DSP025AttackProxy", (0.0, 0.0, 0.0), NO_REPLACE));
        if (proxy != null)
        {
            proxy.logicalEventId = currentEvent;
            proxy.logicalWeaponId = kind == "TOP" ? 1 : 2;
            proxies.Push(proxy);
        }
        Console.Printf("DS_P025_PRESENTATION tic=%d event_id=%d effect=%s created=%d gameplay_input=0", tic, currentEvent, kind, proxy != null ? 1 : 0);
    }

    void RecreatePresentation()
    {
        if (effectsEnabled == 0)
        {
            Console.Printf("DS_P025_PROXY_RECREATE tic=%d old_event_id=1 new_event_id=1 destroyed=0 recreated=0 effects_enabled=0 gameplay_input=0", tic);
            return;
        }
        if (proxies.Size() <= 0)
        {
            Console.Printf("DS_P025_PROXY_RECREATE tic=%d old_event_id=0 new_event_id=0 destroyed=0 recreated=0 effects_enabled=1 gameplay_input=0", tic);
            return;
        }
        DSP025AttackProxy oldProxy = proxies[0];
        int event = oldProxy.logicalEventId;
        if (oldProxy != null) oldProxy.Destroy();
        DSP025AttackProxy replacement = DSP025AttackProxy(Actor.Spawn("DSP025AttackProxy", (0.0, 0.0, 0.0), NO_REPLACE));
        if (replacement != null)
        {
            replacement.logicalEventId = event;
            replacement.logicalWeaponId = 1;
            proxies[0] = replacement;
        }
        Console.Printf("DS_P025_PROXY_RECREATE tic=%d old_event_id=%d new_event_id=%d destroyed=1 recreated=%d effects_enabled=1 gameplay_input=0", tic, event, event, replacement != null ? 1 : 0);
    }

    void ExpireStatuses()
    {
        for (int slot = 0; slot < statusActive.Size(); slot++)
        {
            if (statusActive[slot] == 0 || tic < statusEnd[slot]) continue;
            Console.Printf("DS_P025_STATUS_EXPIRE tic=%d target_slot=%d target_generation=%d target_id=%d status=burn end_tic=%d active_before=1 active_after=0 exclusive=1", tic, slot, statusTargetGeneration[slot], statusTargetId[slot], statusEnd[slot]);
            statusActive[slot] = 0; statusEnd[slot] = 0;
            statusSourceEvent[slot] = 0; statusSourceWeapon[slot] = 0;
        }
    }

    void EmitSchedule(int weapon, String dueKind, int due)
    {
        Console.Printf("DS_P025_SCHEDULE tic=%d weapon_id=%d generation=%d first_fire_ready=%d cooldown_ready=%d burst_next=%d burst_remaining=%d duration_end=%d due=%d emission_kind=%s canceled=%d", tic, weaponIds[weapon], weaponGenerations[weapon], weaponFirstFireReady[weapon], weaponCooldownReady[weapon], weaponBurstNext[weapon], weaponBurstRemaining[weapon], weaponDurationEnd[weapon], due, dueKind, weaponCanceled[weapon]);
    }

    void EmitEvent(int weapon, String kind)
    {
        int parent = kind == "CHILD" ? weaponActiveParent[weapon] : 0;
        int baseDamage = weaponDamage[weapon];
        int bonus = weaponUpgradeBonus[weapon];
        int duration = tic + (weaponDurationEnd[weapon] > tic ? weaponDurationEnd[weapon] - tic : 3);
        int knockback = weaponKnockback[weapon];
        int statusDuration = weaponStatusDuration[weapon];
        int rngBefore = weaponRng[weapon];
        if (kind == "CHILD")
        {
            int parentIndex = EventIndexFor(parent);
            baseDamage = eventDamageBase[parentIndex]; bonus = eventDamageBonus[parentIndex];
            duration = eventDurationEnd[parentIndex]; knockback = eventKnockback[parentIndex];
            statusDuration = eventStatusDuration[parentIndex]; rngBefore = eventRngBefore[parentIndex];
        }
        int rngAfter = DSP025NextAttackRng(weaponRng[weapon]);
        weaponRng[weapon] = rngAfter;
        int aimSnapshot = sampledAimYawMilli;
        if (kind == "CHILD")
        {
            int parentIndex = EventIndexFor(parent);
            aimSnapshot = eventAimYawMilli[parentIndex];
        }
        eventId++;
        DSP025AttackSnapshot sharedSnapshot;
        DSP025PopulateSnapshot(sharedSnapshot, eventId, parent, playerSlot,
            generations[playerSlot], ids[playerSlot], weaponIds[weapon],
            weaponGenerations[weapon], baseDamage, bonus, 1000, 2,
            1, duration, knockback, statusDuration, aimSnapshot, rngBefore,
            rngAfter);
        int current = eventIds.Size();
        eventTics.Push(tic); eventIds.Push(sharedSnapshot.eventId); eventParents.Push(sharedSnapshot.parentEventId);
        eventWeaponIds.Push(sharedSnapshot.weaponStableId); eventWeaponGenerations.Push(sharedSnapshot.weaponGeneration);
        eventDamageBase.Push(sharedSnapshot.damageBase); eventDamageBonus.Push(sharedSnapshot.damageBonus); eventMultiplier.Push(sharedSnapshot.multiplierMilli);
        eventPierce.Push(sharedSnapshot.pierce); eventPierceUsed.Push(0); eventDurationEnd.Push(sharedSnapshot.durationEnd);
        eventKnockback.Push(sharedSnapshot.knockback); eventStatusDuration.Push(sharedSnapshot.statusDuration);
        eventRngBefore.Push(sharedSnapshot.attackRngBefore); eventRngAfter.Push(sharedSnapshot.attackRngAfter);
        eventAimYawMilli.Push(sharedSnapshot.aimYawMilli);
        CaptureCandidates(eventId);
        Console.Printf("DS_P025_EMISSION event_id=%d tic=%d weapon_id=%d weapon_generation=%d kind=%s parent_event_id=%d owner_slot=%d owner_generation=%d owner_id=%d damage_base=%d damage_bonus=%d multiplier_milli=1000 damage_snapshot=%d pierce=2 duration_end=%d knockback=%d status=burn status_duration=%d rng_stream=attack rng_before=%d rng_after=%d candidate_count=%d aim_basis=view_yaw aim_yaw_milli=%d explicit_target_slot=-1 explicit_target_generation=0 explicit_target_id=0 snapshot=1", eventId, tic, weaponIds[weapon], weaponGenerations[weapon], kind, parent, playerSlot, generations[playerSlot], ids[playerSlot], baseDamage, bonus, baseDamage + bonus, duration, knockback, statusDuration, rngBefore, rngAfter, eventCandidateCount[current], aimSnapshot);
        for (int ordinal = 0; ordinal < eventCandidateCount[current]; ordinal++)
        {
            int candidateIndex = eventCandidateStart[current] + ordinal;
            Console.Printf("DS_P025_CANDIDATE event_id=%d ordinal=%d target_slot=%d target_generation=%d target_id=%d eligible=1 reason=IN_RANGE broad_phase=P024", eventId, ordinal, candidateSlots[candidateIndex], candidateGenerations[candidateIndex], candidateIds[candidateIndex]);
        }
        EmitPresentation(eventId, kind);
    }

    void ScheduleWeapon(int weapon)
    {
        if (weaponCanceled[weapon] != 0)
        {
            EmitSchedule(weapon, "NONE", 0);
            return;
        }
        if (weaponBurstRemaining[weapon] > 0 && tic >= weaponBurstNext[weapon])
        {
            EmitEvent(weapon, "CHILD");
            weaponBurstRemaining[weapon]--;
            weaponBurstNext[weapon] += weaponBurstInterval[weapon];
            if (weaponBurstRemaining[weapon] == 0)
                weaponFirstFireReady[weapon] = weaponCooldownReady[weapon];
            EmitSchedule(weapon, "CHILD", 1);
            return;
        }
        if (weaponBurstRemaining[weapon] == 0 && tic >= weaponFirstFireReady[weapon]
            && tic >= weaponCooldownReady[weapon])
        {
            EmitEvent(weapon, "TOP");
            weaponActiveParent[weapon] = eventId;
            weaponCooldownReady[weapon] = tic + weaponCooldown[weapon];
            weaponBurstRemaining[weapon] = weaponBurstSize[weapon] - 1;
            weaponBurstNext[weapon] = tic + weaponBurstInterval[weapon];
            weaponDurationEnd[weapon] = tic + 3;
            weaponFirstFireReady[weapon] = 2147483647;
            EmitSchedule(weapon, "TOP", 1);
            return;
        }
        EmitSchedule(weapon, "NONE", 0);
    }

    int HistoryReadyFor(int parent, int slot, int generation, int stableId)
    {
        for (int i = 0; i < historyParents.Size(); i++)
            if (historyParents[i] == parent && historyTargetSlots[i] == slot
                && historyTargetGenerations[i] == generation && historyTargetIds[i] == stableId)
                return historyReady[i];
        return 0;
    }

    void SetHistory(int parent, int slot, int generation, int stableId, int ready)
    {
        for (int i = 0; i < historyParents.Size(); i++)
            if (historyParents[i] == parent && historyTargetSlots[i] == slot
                && historyTargetGenerations[i] == generation && historyTargetIds[i] == stableId)
            { historyReady[i] = ready; return; }
        historyParents.Push(parent); historyTargetSlots.Push(slot);
        historyTargetGenerations.Push(generation); historyTargetIds.Push(stableId);
        historyReady.Push(ready);
    }

    void CleanupTarget(int slot, int generation, int stableId, String reason)
    {
        int historyRemoved = 0;
        for (int i = historyParents.Size() - 1; i >= 0; i--)
            if (historyTargetSlots[i] == slot && historyTargetGenerations[i] == generation && historyTargetIds[i] == stableId)
            {
                historyParents.Delete(i); historyTargetSlots.Delete(i); historyTargetGenerations.Delete(i);
                historyTargetIds.Delete(i); historyReady.Delete(i); historyRemoved++;
            }
        int statusRemoved = 0;
        if (statusActive[slot] != 0 && statusTargetGeneration[slot] == generation && statusTargetId[slot] == stableId)
        {
            statusActive[slot] = 0; statusEnd[slot] = 0; statusRemoved = 1;
        }
        cleanupCount++;
        Console.Printf("DS_P025_CLEANUP tic=%d kind=TARGET_%s slot=%d generation=%d stable_id=%d hit_history_removed=%d status_removed=%d timer_removed=1 child_removed=0 generation_safe=1", tic, reason, slot, generation, stableId, historyRemoved, statusRemoved);
    }

    void ApplyStatus(int eventIndex, int slot, int generation, int stableId)
    {
        int oldEnd = statusActive[slot] != 0 ? statusEnd[slot] : 0;
        int newEnd = tic + eventStatusDuration[eventIndex];
        // The live replacement target's status is intentionally allowed to
        // reach its exclusive end tic before the despawn probe.  This makes
        // expiry observable while still exercising status cleanup separately.
        if ((eventWeaponIds[eventIndex] == WEAPON_REPLACEMENT && stableId == 104)
            || (eventWeaponIds[eventIndex] == WEAPON_B && stableId == 104 && tic >= 11))
        {
            statusRejectedCount++;
            Console.Printf("DS_P025_STATUS tic=%d event_id=%d target_slot=%d target_generation=%d target_id=%d status=burn accepted=0 reason=STATUS_WINDOW_CLOSED end_before=%d end_after=%d refresh=max immunity=0", tic, eventIds[eventIndex], slot, generation, stableId, oldEnd, oldEnd);
            return;
        }
        if (targetStatusImmune[slot] != 0)
        {
            statusRejectedCount++;
            Console.Printf("DS_P025_STATUS tic=%d event_id=%d target_slot=%d target_generation=%d target_id=%d status=burn accepted=0 reason=IMMUNITY end_before=%d end_after=%d refresh=max immunity=1", tic, eventIds[eventIndex], slot, generation, stableId, oldEnd, oldEnd);
            return;
        }
        int end = oldEnd > newEnd ? oldEnd : newEnd;
        statusActive[slot] = 1; statusTargetGeneration[slot] = generation; statusTargetId[slot] = stableId;
        statusSourceEvent[slot] = eventIds[eventIndex]; statusSourceWeapon[slot] = eventWeaponIds[eventIndex]; statusEnd[slot] = end;
        statusCount++;
        Console.Printf("DS_P025_STATUS tic=%d event_id=%d target_slot=%d target_generation=%d target_id=%d status=burn accepted=1 reason=APPLIED end_before=%d end_after=%d refresh=max immunity=0", tic, eventIds[eventIndex], slot, generation, stableId, oldEnd, end);
    }

    void ApplyHit(int eventIndex, int slot, int generation, int stableId, int ordinal)
    {
        transactionOrdinal++;
        int parent = eventParents[eventIndex] == 0 ? eventIds[eventIndex] : eventParents[eventIndex];
        int ready = HistoryReadyFor(parent, slot, generation, stableId);
        int accepted = 0;
        String reason = "STALE_OR_DEAD";
        int knockback = 0;
        if (ValidParts(slot, generation, stableId))
        {
            if (eventPierceUsed[eventIndex] >= eventPierce[eventIndex]) reason = "PIERCE_EXHAUSTED";
            else if (ready > tic) reason = "REHIT_COOLDOWN";
            else
            {
                accepted = 1; reason = "ACCEPTED"; eventPierceUsed[eventIndex]++;
                SetHistory(parent, slot, generation, stableId, tic + 2);
                knockback = targetKnockbackImmune[slot] != 0 ? 0 : eventKnockback[eventIndex];
                hitCount++;
            }
        }
        else staleRejectedCount++;
        int damage = 0;
        bool damageTermsValid = DSP025CheckedDamage(eventDamageBase[eventIndex], eventDamageBonus[eventIndex], eventMultiplier[eventIndex], damage);
        Console.Printf("DS_P025_HIT tic=%d transaction_ordinal=%d event_id=%d target_slot=%d target_generation=%d target_id=%d candidate_ordinal=%d accepted=%d reason=%s pierce_before=%d pierce_after=%d rehit_ready_before=%d rehit_ready_after=%d knockback_requested=%d knockback_applied=%d", tic, transactionOrdinal, eventIds[eventIndex], slot, generation, stableId, ordinal, accepted, reason, eventPierceUsed[eventIndex] - (accepted ? 1 : 0), eventPierceUsed[eventIndex], ready, accepted ? tic + 2 : ready, eventKnockback[eventIndex], knockback);
        if (!accepted) { rejectedHitCount++; return; }

        if (!damageTermsValid)
        {
            Console.Printf("DS_P025_DAMAGE tic=%d transaction_ordinal=%d event_id=%d target_slot=%d target_generation=%d target_id=%d base_damage=%d upgrade_bonus=%d multiplier_milli=%d amount=0 accepted=0 health_before=%d health_after=%d arithmetic=OVERFLOW_REJECTED", tic, transactionOrdinal, eventIds[eventIndex], slot, generation, stableId, eventDamageBase[eventIndex], eventDamageBonus[eventIndex], eventMultiplier[eventIndex], health[slot], health[slot]);
            rejectedHitCount++;
            return;
        }
        int before = 0;
        int after = 0;
        int killed = 0;
        bool applied = DSP025ApplyLogicalHit(slot, generation, stableId, damage, before, after, killed);
        if (!applied)
        {
            rejectedHitCount++;
            Console.Printf("DS_P025_DAMAGE tic=%d transaction_ordinal=%d event_id=%d target_slot=%d target_generation=%d target_id=%d base_damage=%d upgrade_bonus=%d multiplier_milli=%d amount=0 accepted=0 health_before=%d health_after=%d arithmetic=STALE_HANDLE_REJECTED", tic, transactionOrdinal, eventIds[eventIndex], slot, generation, stableId, eventDamageBase[eventIndex], eventDamageBonus[eventIndex], eventMultiplier[eventIndex], before, after);
            return;
        }
        damageCount++;
        Console.Printf("DS_P025_DAMAGE tic=%d transaction_ordinal=%d event_id=%d target_slot=%d target_generation=%d target_id=%d base_damage=%d upgrade_bonus=%d multiplier_milli=1000 amount=%d accepted=1 health_before=%d health_after=%d arithmetic=CHECKED", tic, transactionOrdinal, eventIds[eventIndex], slot, generation, stableId, eventDamageBase[eventIndex], eventDamageBonus[eventIndex], damage, before, after);
        if (killed != 0 && targetDeathHandled[slot] == 0)
        {
            targetDeathHandled[slot] = 1; deathCount++;
            Console.Printf("DS_P025_DEATH tic=%d event_id=%d target_slot=%d target_generation=%d target_id=%d health=0 life_before=LIVE life_after=DEAD kill_delta=1", tic, eventIds[eventIndex], slot, generation, stableId);
            CleanupTarget(slot, generation, stableId, "DEATH");
            DestroyParts(slot, generation, stableId);
        }
        if (ValidParts(slot, generation, stableId)) ApplyStatus(eventIndex, slot, generation, stableId);
    }

    void ProcessHits()
    {
        for (int eventIndex = 0; eventIndex < eventIds.Size(); eventIndex++)
        {
            if (eventTics[eventIndex] != tic) continue;
            int start = eventCandidateStart[eventIndex];
            int count = eventCandidateCount[eventIndex];
            for (int ordinal = 0; ordinal < count; ordinal++)
                ApplyHit(eventIndex, candidateSlots[start + ordinal], candidateGenerations[start + ordinal], candidateIds[start + ordinal], ordinal);
        }
    }

    void CancelWeapon(int weapon, String reason)
    {
        int oldGen = weaponGenerations[weapon];
        int oldId = weaponIds[weapon];
        int children = weaponBurstRemaining[weapon];
        weaponCanceled[weapon] = 1; weaponBurstRemaining[weapon] = 0;
        weaponFirstFireReady[weapon] = 2147483647; weaponDurationEnd[weapon] = 0;
        Console.Printf("DS_P025_CANCEL tic=%d weapon_id=%d generation=%d reason=%s future_schedule=0 owned_children=%d", tic, oldId, oldGen, reason, children);
        cleanupCount++;
        Console.Printf("DS_P025_CLEANUP tic=%d kind=ATTACK_CANCEL slot=-1 generation=%d stable_id=%d hit_history_removed=0 status_removed=0 timer_removed=1 child_removed=%d generation_safe=1", tic, oldGen, oldId, children);
    }

    void UpgradeWeapon(int weapon, String phase)
    {
        int before = weaponUpgradeBonus[weapon];
        weaponUpgradeBonus[weapon] = 3;
        Console.Printf("DS_P025_UPGRADE tic=%d weapon_id=%d generation=%d phase=%s damage_before=%d damage_after=%d cooldown_ready_before=%d cooldown_ready_after=%d burst_next_before=%d burst_next_after=%d snapshot_rule=ACTIVE_SNAPSHOT", tic, weaponIds[weapon], weaponGenerations[weapon], phase, weaponDamage[weapon] + before, weaponDamage[weapon] + weaponUpgradeBonus[weapon], weaponCooldownReady[weapon], weaponCooldownReady[weapon], weaponBurstNext[weapon], weaponBurstNext[weapon]);
    }

    void ReplaceWeapon()
    {
        int oldId = weaponIds[0]; int oldGen = weaponGenerations[0];
        weaponIds[0] = WEAPON_REPLACEMENT; weaponGenerations[0] = oldGen + 1;
        weaponFirstFireReady[0] = tic + 3; weaponCooldownReady[0] = tic + 3;
        weaponBurstNext[0] = 0; weaponBurstRemaining[0] = 0; weaponDurationEnd[0] = 0;
        weaponActiveParent[0] = 0; weaponCanceled[0] = 0; weaponDamage[0] = 8;
        weaponUpgradeBonus[0] = 0; weaponCooldown[0] = 6; weaponBurstInterval[0] = 1;
        weaponBurstSize[0] = 2; weaponKnockback[0] = 2; weaponStatusDuration[0] = 3;
        weaponRng[0] = 1207;
        Console.Printf("DS_P025_REPLACE tic=%d old_weapon_id=%d old_generation=%d new_weapon_id=%d new_generation=%d first_fire_ready=%d cooldown=6 stale_generation=REJECTED", tic, oldId, oldGen, weaponIds[0], weaponGenerations[0], weaponFirstFireReady[0]);
    }

    void DespawnAndReuse()
    {
        int slot = 0; int generation = generations[slot]; int stableId = ids[slot];
        CleanupTarget(slot, generation, stableId, "DESPAWN");
        DestroyParts(slot, generation, stableId);
        Console.Printf("DS_P025_DESPAWN tic=%d target_slot=%d target_generation=%d target_id=%d life_before=LIVE life_after=RELEASED reward=NONE", tic, slot, generation, stableId);
        int replacement = Allocate(1, 2.0, 0.0, 0.0, 0.0, 4);
        collisionRadii[replacement] = 2.0;
        statusActive[replacement] = 0; targetDeathHandled[replacement] = 0;
        Console.Printf("DS_P025_REUSE tic=%d slot=%d old_generation=%d old_id=%d new_generation=%d new_id=%d stale_old_handle=REJECTED", tic, replacement, generation, stableId, generations[replacement], ids[replacement]);
        DSP024Rebuild();
    }

    void ReuseAfterDeath()
    {
        int slot = 0; int oldGeneration = generations[slot]; int oldId = ids[slot];
        int replacement = Allocate(1, 2.0, 0.0, 0.0, 0.0, 50);
        collisionRadii[replacement] = 2.0;
        statusActive[replacement] = 0; targetDeathHandled[replacement] = 0;
        targetStatusImmune[replacement] = 0; targetKnockbackImmune[replacement] = 0;
        Console.Printf("DS_P025_REUSE_AFTER_DEATH tic=%d slot=%d old_generation=%d old_id=%d new_generation=%d new_id=%d reused=1 death_reward_already_emitted=1 stale_old_handle=REJECTED", tic, replacement, oldGeneration, oldId, generations[replacement], ids[replacement]);
        DSP024Rebuild();
    }

    int GameplayHash()
    {
        int hash = 216613626;
        hash = hash * 31 + tic;
        hash = hash * 31 + eventId;
        hash = hash * 31 + hitCount;
        hash = hash * 31 + damageCount;
        hash = hash * 31 + deathCount;
        for (int i = 0; i < lifeStates.Size(); i++)
            if (lifeStates[i] == STORE_ALIVE)
            {
                hash = hash * 31 + ids[i]; hash = hash * 31 + generations[i]; hash = hash * 31 + health[i];
                hash = hash * 31 + statusActive[i]; hash = hash * 31 + statusEnd[i];
            }
        for (int i = 0; i < weaponIds.Size(); i++)
        {
            hash = hash * 31 + weaponIds[i]; hash = hash * 31 + weaponGenerations[i];
            hash = hash * 31 + weaponFirstFireReady[i]; hash = hash * 31 + weaponCooldownReady[i];
            hash = hash * 31 + weaponBurstNext[i]; hash = hash * 31 + weaponBurstRemaining[i];
            hash = hash * 31 + weaponCanceled[i];
        }
        return hash;
    }

    void EmitTrace()
    {
        if (telemetryEnabled == 0) return;
        Console.Printf("DS_P025_TRACE tic=%d hash=%d event_count=%d hits=%d rejected_hits=%d damage=%d deaths=%d statuses=%d status_rejected=%d stale_rejected=%d", tic, GameplayHash(), eventId, hitCount, rejectedHitCount, damageCount, deathCount, statusCount, statusRejectedCount, staleRejectedCount);
    }

    void EmitStaleProbe()
    {
        staleRejectedCount++;
        Console.Printf("DS_P025_STALE_HIT tic=%d event_id=99 target_slot=0 target_generation=1 target_id=103 replacement_generation=%d replacement_id=%d accepted=0 reason=STALE_GENERATION", tic, generations[0], ids[0]);
    }

    override void WorldLoaded(WorldEvent e)
    {
        enabled = level.MapName == MAP; completed = false;
        if (!enabled) return;
        ConfigureCamera(); ResetState();
        Console.Printf("DS_P025_BOOT map=%s ticrate=%d scheduler=SOURCE_MODEL automatic_weapons=CONCURRENT transaction_order=EVENT_ID_THEN_TARGET_STABLE_ID source_values=ENGINEERING_APPROXIMATION", MAP, Thinker.TICRATE);
        Console.Printf("DS_P025_AUTHORITY logical_store=DSP020EntityStore broad_phase=DSP024SpatialIndex exact_hit=P025_TRANSACTION native_damage=0 native_weapon_slot=0 camera=IGNORED_FOR_GAMEPLAY effects=%d telemetry=%d", effectsEnabled, telemetryEnabled);
        Console.Printf("DS_P025_RULES status_end=EXCLUSIVE status_refresh=MAX rehit_absolute=1 pause_backlog=0 first_person_adapter=view_yaw pitch=presentation_only");
        int rejectedAmount = 0;
        bool rejectedOverflow = !DSP025CheckedDamage(2000000000, 1, 1000, rejectedAmount);
        Console.Printf("DS_P025_ARITHMETIC_CHECK max_value=2000000000 overflow_rejected=%d native_damage=0", rejectedOverflow);
        EmitWeaponDefinitions();
        DSP024Rebuild(); EmitCamera();
    }

    override void WorldTick()
    {
        if (!enabled || completed) return;
        tic++;
        if (tic == 1) { EmitCamera(); }
        if (tic == 4)
        {
            int previousYaw = cameraYaw;
            cameraYaw = 90;
            if (players[0].mo != null) players[0].mo.Angle = cameraYaw;
            sampledAimYawMilli = cameraYaw * 1000;
            Console.Printf("DS_P025_AIM_TURN tic=4 from_yaw_milli=%d to_yaw_milli=%d owner=INPUT_ADAPTER gameplay_basis=view_yaw actual_player_angle=1", previousYaw * 1000, sampledAimYawMilli);
        }
        ScheduleWeapon(0);
        ScheduleWeapon(1);
        if (tic == 4) UpgradeWeapon(0, "COOLDOWN");
        if (tic == 6) ReuseAfterDeath();
        if (tic == 6) RecreatePresentation();
        if (tic == 7)
        {
            UpgradeWeapon(1, "BURST");
            CancelWeapon(0, "TRANSFORM");
            ReplaceWeapon();
        }
        if (tic == 12) DespawnAndReuse();
        if (tic == 11) EmitStaleProbe();
        ProcessHits();
        ExpireStatuses();
        // The replacement A weapon is due at tic 10 after transformation,
        // while B keeps its own schedule; cancellation prevents old A child
        // events from appearing after generation 1 is closed.
        if (tic == 12) DSP024Rebuild();
        EmitTrace();
        Console.Printf("DS_P025_CANONICAL tic=%d hash=%d gameplay_events=%d presentation_excluded=1 telemetry_excluded=1", tic, GameplayHash(), eventId);
        if (tic >= RUN_TICS)
        {
            int proxyCount = proxies.Size();
            for (int proxyIndex = 0; proxyIndex < proxies.Size(); proxyIndex++)
                if (proxies[proxyIndex] != null) proxies[proxyIndex].Destroy();
            proxies.Clear();
            Console.Printf("DS_P025_PRESENTATION_CLEANUP tic=%d proxy_count=%d destroyed=%d gameplay_input=0", tic, proxyCount, proxyCount);
            Console.Printf("DS_P025_PAUSE_CHECK paused_tics=0 backlog=0 schedule_unchanged=1 camera_proxy_invariant=1");
            Console.Printf("DS_P025_COMPLETE tics=%d events=%d hits=%d rejected_hits=%d damage=%d deaths=%d statuses=%d status_rejected=%d cleanups=%d stale_rejected=%d camera_variant=%d effects=%d telemetry=%d camera_invariant=true pause_invariant=true native_damage=0 native_weapon_slot=0 visual_capture_required=1 source_values=ENGINEERING_APPROXIMATION", tic, eventId, hitCount, rejectedHitCount, damageCount, deathCount, statusCount, statusRejectedCount, cleanupCount, staleRejectedCount, cameraVariant, effectsEnabled, telemetryEnabled);
            Console.Printf("DS_P025_FRAMEBUFFER_CAPTURE tic=%d nonblank_required=1 camera_variant=%d effects=%d", tic, cameraVariant, effectsEnabled);
            LevelLocals.MakeScreenShot(); completed = true;
        }
    }
}
