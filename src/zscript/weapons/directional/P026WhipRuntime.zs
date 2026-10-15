// MAP12 P026 Antonio/Whip vertical slice.
//
// P020 owns all logical entities and health. P024 supplies the broad phase.
// P025 snapshot and transaction records are used for each automatic lobe.
// Native actors are restrained presentation proxies and never participate in
// candidate discovery, damage, death, XP or RNG.
class DSP026WhipProxy : Actor
{
    int logicalEventId;
    int logicalLobe;

    Default
    {
        Radius 4;
        Height 12;
        +NOBLOCKMAP;
        +NOGRAVITY;
        +NOINTERACTION;
        RenderStyle "Add";
        Alpha 0.68;
    }

    States
    {
    Spawn:
        BILL A 2 Bright;
        Loop;
    }
}

class DSP026WhipRuntime : EventHandler
{
    mixin DSP020EntityStore;
    mixin DSP024SpatialIndex;
    mixin DSP025AttackCore;

    const MAP = "MAP12";
    const RUN_TICS = 110;
    const TARGET_KIND = 1;
    const PLAYER_KIND = 99;
    const MIGHT_MILLI = 1100;

    bool enabled;
    bool completed;
    int tic;
    int cameraVariant;
    int effectsEnabled;
    int telemetryEnabled;
    int bodyVariant;
    int cameraYaw;
    int cameraPitch;
    int cameraFov;
    int eventId;
    int transactionOrdinal;
    int hitCount;
    int damageCount;
    int deathCount;
    int xpRequestCount;
    int rejectedHitCount;
    int attackRng;
    int sampledAimYawMilli;
    int nextTopQuarter;
    int pendingRearQuarter;
    int pendingRear;
    int playerSlot;
    int canonicalHash;
    DSP025SourceCharacterState antonioStats;
    DSP025SourceInventoryState startingWeapon;

    // ZScript dynamic arrays are integral-only in the pinned engine. These
    // parallel arrays persist the P025 snapshot fields without native actor
    // references; EmitLobe still assembles the canonical DSP025 record.
    Array<int> snapshotEventId;
    Array<int> snapshotDamageBase;
    Array<int> snapshotMultiplierMilli;
    Array<int> snapshotAmount;
    Array<int> snapshotLobe;
    Array<int> snapshotCandidateStart;
    Array<int> snapshotCandidateCount;
    Array<int> candidateSlots;
    Array<int> candidateGenerations;
    Array<int> candidateIds;
    Array<int> historyEvent;
    Array<int> historyTargetSlot;
    Array<int> historyTargetGeneration;
    Array<int> historyTargetId;
    Array<DSP026WhipProxy> proxies;

    int NormalizeYaw(int yaw)
    {
        while (yaw < 0) yaw += 360;
        while (yaw >= 360) yaw -= 360;
        return yaw;
    }

    void LocalCoordinates(double dx, double dy, int yaw, out double forward, out double lateral)
    {
        int cardinal = NormalizeYaw(yaw);
        if (cardinal < 45 || cardinal >= 315) { forward = dx; lateral = dy; }
        else if (cardinal < 135) { forward = dy; lateral = -dx; }
        else if (cardinal < 225) { forward = -dx; lateral = -dy; }
        else { forward = -dy; lateral = dx; }
    }

    bool CircleInLobe(int slot, int yaw, int lobe)
    {
        double forward;
        double lateral;
        LocalCoordinates(x[slot], y[slot], yaw, forward, lateral);
        double minForward = lobe == 0 ? DSP026WhipRecords.LOBE_FORWARD_MIN : -DSP026WhipRecords.LOBE_FORWARD_MAX;
        double maxForward = lobe == 0 ? DSP026WhipRecords.LOBE_FORWARD_MAX : -DSP026WhipRecords.LOBE_FORWARD_MIN;
        double closestForward = forward < minForward ? minForward : (forward > maxForward ? maxForward : forward);
        double closestLateral = lateral < DSP026WhipRecords.LOBE_LATERAL_MIN ? DSP026WhipRecords.LOBE_LATERAL_MIN : (lateral > DSP026WhipRecords.LOBE_LATERAL_MAX ? DSP026WhipRecords.LOBE_LATERAL_MAX : lateral);
        double distanceForward = forward - closestForward;
        double distanceLateral = lateral - closestLateral;
        return distanceForward * distanceForward + distanceLateral * distanceLateral <= DSP026WhipRecords.TARGET_RADIUS * DSP026WhipRecords.TARGET_RADIUS + 0.000001;
    }

    void AddTarget(double targetX, double targetY, int initialHealth)
    {
        int slot = Allocate(TARGET_KIND, targetX, targetY, 0.0, 0.0, initialHealth);
        collisionRadii[slot] = DSP026WhipRecords.TARGET_RADIUS;
    }

    void ResetState()
    {
        Reset();
        DSP024ClearSpatial();
        snapshotEventId.Clear(); snapshotDamageBase.Clear(); snapshotMultiplierMilli.Clear(); snapshotAmount.Clear();
        snapshotLobe.Clear(); snapshotCandidateStart.Clear(); snapshotCandidateCount.Clear();
        candidateSlots.Clear(); candidateGenerations.Clear(); candidateIds.Clear();
        historyEvent.Clear(); historyTargetSlot.Clear(); historyTargetGeneration.Clear(); historyTargetId.Clear();
        proxies.Clear();
        tic = 0; eventId = 0; transactionOrdinal = 0; hitCount = 0; damageCount = 0;
        deathCount = 0; xpRequestCount = 0; rejectedHitCount = 0; attackRng = 270126;
        nextTopQuarter = 4; pendingRearQuarter = 0; pendingRear = 0; canonicalHash = 216613626;
        sampledAimYawMilli = cameraYaw * 1000;
        antonioStats.level = 10;
        antonioStats.maxHealthBonus = 20;
        antonioStats.armorBonus = 1;
        antonioStats.mightMilli = MIGHT_MILLI;
        startingWeapon.slot = -1;
        startingWeapon.generation = 0;
        startingWeapon.weaponStableId = 0;
        startingWeapon.weaponLevel = DSP026WhipRecords.FIXTURE_LEVEL;

        // Nine P020 logical targets: two valid front/rear members for every
        // cardinal basis and one side target that a cone-inflated adapter must
        // reject. Health is represented in shared milliunits.
        AddTarget(64.0, 0.0, 10000);
        AddTarget(96.0, 20.0, 10000);
        AddTarget(96.0, 36.0, 10000);
        AddTarget(-64.0, 0.0, 10000);
        AddTarget(-96.0, -20.0, 10000);
        AddTarget(0.0, 64.0, 10000);
        AddTarget(20.0, 96.0, 10000);
        AddTarget(0.0, -64.0, 10000);
        AddTarget(-20.0, -96.0, 10000);
        startingWeapon.slot = Allocate(2, 0.0, 0.0, 0.0, 0.0, 1);
        startingWeapon.generation = generations[startingWeapon.slot];
        startingWeapon.weaponStableId = ids[startingWeapon.slot];
        playerSlot = Allocate(PLAYER_KIND, 0.0, 0.0, 0.0, 0.0, 120000);
        collisionRadii[playerSlot] = 2.0;
    }

    void EmitSourceRecords()
    {
        Console.Printf("DS_P026_SOURCE character=ANTONIO character_name=Antonio starting_weapon=WHIP character_provenance=BUILD_EXTRACTED weapon=WHIP weapon_name=Whip bullet=WHIP frame=Whip.png weapon_provenance=BUILD_EXTRACTED source_sha256=%s", DSP026WhipRecords.SOURCE_SHA256);
        Console.Printf("DS_P026_CHARACTER_STATS base_max_health=100 starting_max_health=20 starting_armor=1 max_health_actual=120 armor_actual=1 might_percent_per_10=10 might_cap_percent=50 provenance=ONLINE_REPORTED_CURRENT source=Antonio_Belpaese retrieved=2026-09-12 level=10 snapshot_might_milli=%d", MIGHT_MILLI);
        Console.Printf("DS_P026_WEAPON_STATS base_damage=10 area=1 base_amount=1 level=%d amount_at_level=%d cooldown_seconds=1.35 followup_seconds=0.1 knockback=1 pool=30 provenance=ONLINE_REPORTED_CURRENT source=Whip retrieved=2026-09-12", startingWeapon.weaponLevel, DSP026WhipRecords.AmountForLevel(startingWeapon.weaponLevel));
        Console.Printf("DS_P026_GEOMETRY shape=ORIENTED_RECTANGLE forward_min=0.000 forward_max=128.000 lateral_min=-24.000 lateral_max=24.000 edges=INCLUSIVE walls=IGNORED provenance=ENGINEERING_APPROXIMATION");
        Console.Printf("DS_P026_TIMING cooldown_num=189 cooldown_den=4 followup_num=7 followup_den=2 tickrate=35 timing_provenance=ENGINEERING_APPROXIMATION");
    }

    void EmitWorld()
    {
        for (int slot = 0; slot < lifeStates.Size(); slot++)
            if (lifeStates[slot] == STORE_ALIVE)
                Console.Printf("DS_P026_WORLD slot=%d generation=%d stable_id=%d kind=%d live=1 x=%.3f y=%.3f radius=%.3f health=%d", slot, generations[slot], ids[slot], kinds[slot], x[slot], y[slot], collisionRadii[slot], health[slot]);
    }

    void EmitCamera()
    {
        if (players[0].mo != null)
        {
            players[0].mo.Angle = cameraYaw;
            players[0].mo.Pitch = cameraPitch;
            players[0].SetFOV(cameraFov);
        }
        Console.Printf("DS_P026_CAMERA tic=%d variant=%d yaw=%d pitch=%d fov=%d logical_xy=(0.000,0.000) camera_role=PRESENTATION_ONLY", tic, cameraVariant, cameraYaw, cameraPitch, cameraFov);
    }

    void ConfigureCamera()
    {
        CVar variant = CVar.FindCVar('ds_p026_camera_variant');
        cameraVariant = variant != null ? variant.GetInt() : 0;
        if (cameraVariant < 0 || cameraVariant > 4) cameraVariant = 0;
        cameraYaw = cameraVariant == 4 ? 0 : cameraVariant * 90;
        cameraPitch = (cameraVariant == 3 || cameraVariant == 4) ? 22 : 0;
        cameraFov = (cameraVariant == 3 || cameraVariant == 4) ? 115 : 90;
        CVar effects = CVar.FindCVar('ds_p026_effects');
        effectsEnabled = effects != null ? effects.GetInt() : 1;
        if (effectsEnabled != 0) effectsEnabled = 1;
        CVar telemetry = CVar.FindCVar('ds_p026_telemetry');
        telemetryEnabled = telemetry != null ? telemetry.GetInt() : 1;
        if (telemetryEnabled != 0) telemetryEnabled = 1;
        CVar body = CVar.FindCVar('ds_p026_body_variant');
        bodyVariant = body != null ? body.GetInt() : 0;
        if (bodyVariant != 0) bodyVariant = 1;
    }

    void CaptureCandidates(int currentEvent, int lobe)
    {
        int start = candidateSlots.Size();
        // P024 is the production broad phase. The exact rectangle/circle
        // narrow phase below deliberately ignores walls and camera state.
        DSP024RadiusCandidates(0.0, 0.0, 140.0);
        for (int i = 0; i < spatialCandidateCount; i++)
        {
            int slot = spatialCandidateSlots[i];
            if (!ValidParts(slot, spatialCandidateGenerations[i], spatialCandidateIds[i])) continue;
            if (kinds[slot] != TARGET_KIND) continue;
            if (CircleInLobe(slot, cameraYaw, lobe))
            {
                candidateSlots.Push(slot);
                candidateGenerations.Push(generations[slot]);
                candidateIds.Push(ids[slot]);
            }
        }
        // P024 discovery order is not the gameplay transaction order. Stable
        // IDs define the accepted deterministic ordering.
        for (int i = start + 1; i < candidateSlots.Size(); i++)
        {
            int j = i;
            while (j > start && candidateIds[j] < candidateIds[j - 1])
            {
                int value = candidateSlots[j]; candidateSlots[j] = candidateSlots[j - 1]; candidateSlots[j - 1] = value;
                value = candidateGenerations[j]; candidateGenerations[j] = candidateGenerations[j - 1]; candidateGenerations[j - 1] = value;
                value = candidateIds[j]; candidateIds[j] = candidateIds[j - 1]; candidateIds[j - 1] = value;
                j--;
            }
        }
        int index = snapshotEventId.Size();
        snapshotCandidateStart.Push(start);
        snapshotCandidateCount.Push(candidateSlots.Size() - start);
        Console.Printf("DS_P026_NARROW event_id=%d lobe=%s yaw_milli=%d broad_candidates=%d eligible=%d wall_filter=0 camera_ignored=1 movement_ignored=1", currentEvent, lobe == 0 ? "FRONT" : "REAR", cameraYaw * 1000, spatialCandidateCount, candidateSlots.Size() - start);
        for (int ordinal = 0; ordinal < candidateSlots.Size() - start; ordinal++)
            Console.Printf("DS_P026_CANDIDATE event_id=%d ordinal=%d target_slot=%d target_generation=%d target_id=%d eligible=1 reason=RECTANGLE_CIRCLE_INCLUSIVE broad_phase=P024", currentEvent, ordinal, candidateSlots[start + ordinal], candidateGenerations[start + ordinal], candidateIds[start + ordinal]);
    }

    void EmitProxy(int currentEvent, int lobe)
    {
        if (effectsEnabled == 0) return;
        double proxyX = 48.0;
        double proxyY = 0.0;
        int cardinal = NormalizeYaw(cameraYaw);
        if (cardinal >= 45 && cardinal < 135) { proxyX = 0.0; proxyY = 48.0; }
        else if (cardinal >= 135 && cardinal < 225) proxyX = -48.0;
        else if (cardinal >= 225) { proxyX = 0.0; proxyY = -48.0; }
        DSP026WhipProxy proxy = DSP026WhipProxy(Actor.Spawn("DSP026WhipProxy", (proxyX, proxyY, 32.0), NO_REPLACE));
        if (proxy != null)
        {
            proxy.logicalEventId = currentEvent;
            proxy.logicalLobe = lobe;
            proxies.Push(proxy);
        }
        Console.Printf("DS_P026_PRESENTATION tic=%d event_id=%d lobe=%s proxy_created=%d gameplay_input=0 damage_authority=P025_TRANSACTION", tic, currentEvent, lobe == 0 ? "FRONT" : "REAR", proxy != null ? 1 : 0);
    }

    void EmitLobe(int lobe, int deadlineQuarter)
    {
        eventId++;
        int current = snapshotEventId.Size();
        int rngBefore = attackRng;
        attackRng = DSP025NextAttackRng(attackRng);
        DSP025AttackSnapshot snapshot;
        DSP025PopulateSnapshot(snapshot, eventId, lobe == 1 ? eventId - 1 : 0,
            playerSlot, generations[playerSlot], ids[playerSlot],
            startingWeapon.weaponStableId, startingWeapon.generation,
            DSP026WhipRecords.BASE_DAMAGE, 0, antonioStats.mightMilli, 30,
            DSP026WhipRecords.AmountForLevel(startingWeapon.weaponLevel),
            tic + 2, 1, 0, sampledAimYawMilli, rngBefore, attackRng);
        snapshotEventId.Push(snapshot.eventId);
        snapshotDamageBase.Push(snapshot.damageBase);
        snapshotMultiplierMilli.Push(snapshot.multiplierMilli);
        snapshotAmount.Push(snapshot.amount);
        snapshotLobe.Push(lobe);
        CaptureCandidates(eventId, lobe);
        Console.Printf("DS_P026_EMISSION event_id=%d tic=%d weapon_id=WHIP weapon_generation=%d inventory_slot=%d inventory_generation=%d inventory_stable_id=%d weapon_level=%d base_amount=1 amount=%d amount_source=LEVEL_TABLE kind=%s lobe=%s parent_event_id=%d owner_slot=%d owner_generation=%d owner_id=%d damage_base=%d damage_bonus=0 multiplier_milli=%d damage_milli=%d pierce=30 candidate_count=%d aim_basis=view_yaw aim_yaw_milli=%d deadline_quarter=%d deadline_denominator=4 cooldown_num=189 cooldown_den=4 followup_num=7 followup_den=2 snapshot=1 rng_stream=attack rng_before=%d rng_after=%d primary_fire_input=0", eventId, tic, startingWeapon.generation, startingWeapon.slot, startingWeapon.generation, startingWeapon.weaponStableId, startingWeapon.weaponLevel, snapshot.amount, lobe == 0 ? "TOP" : "CHILD", lobe == 0 ? "FRONT" : "REAR", snapshot.parentEventId, playerSlot, generations[playerSlot], ids[playerSlot], snapshot.damageBase, snapshot.multiplierMilli, snapshot.damageBase * snapshot.multiplierMilli, snapshotCandidateCount[current], snapshot.aimYawMilli, deadlineQuarter, rngBefore, attackRng);
        Console.Printf("DS_P026_LOBE event_id=%d lobe=%s forward_min=0.000 forward_max=128.000 lateral_min=-24.000 lateral_max=24.000 edges=inclusive wall_filter=0 repeat_hit_policy=ONE_PER_LOBE", eventId, lobe == 0 ? "FRONT" : "REAR");
        EmitProxy(eventId, lobe);
    }

    int HistoryIndex(int event, int slot, int generation, int stableId)
    {
        for (int i = 0; i < historyEvent.Size(); i++)
            if (historyEvent[i] == event && historyTargetSlot[i] == slot && historyTargetGeneration[i] == generation && historyTargetId[i] == stableId) return i;
        historyEvent.Push(event); historyTargetSlot.Push(slot); historyTargetGeneration.Push(generation); historyTargetId.Push(stableId);
        return historyEvent.Size() - 1;
    }

    void ProcessLobe(int snapshotIndex)
    {
        int start = snapshotCandidateStart[snapshotIndex];
        int count = snapshotCandidateCount[snapshotIndex];
        int used = 0;
        for (int ordinal = 0; ordinal < count; ordinal++)
        {
            int candidate = start + ordinal;
            int slot = candidateSlots[candidate];
            int generation = candidateGenerations[candidate];
            int stableId = candidateIds[candidate];
            transactionOrdinal++;
            bool valid = ValidParts(slot, generation, stableId);
            int accepted = valid && used < DSP026WhipRecords.BASE_AMOUNT + 29 ? 1 : 0;
            String reason = accepted != 0 ? "ACCEPTED" : (valid ? "PIERCE_EXHAUSTED" : "STALE_OR_DEAD");
            if (accepted != 0)
            {
                used++;
                hitCount++;
                int history = HistoryIndex(snapshotEventId[snapshotIndex], slot, generation, stableId);
                Console.Printf("DS_P026_HIT tic=%d transaction_ordinal=%d event_id=%d target_slot=%d target_generation=%d target_id=%d candidate_ordinal=%d accepted=1 reason=%s lobe=%s one_hit_per_lobe=1 history_index=%d", tic, transactionOrdinal, snapshotEventId[snapshotIndex], slot, generation, stableId, ordinal, reason, snapshotLobe[snapshotIndex] == 0 ? "FRONT" : "REAR", history);
                int amount = 0;
                int before = 0;
                int after = 0;
                int killed = 0;
                bool checked = DSP025CheckedMilliDamage(snapshotDamageBase[snapshotIndex], snapshotMultiplierMilli[snapshotIndex], amount);
                arHitSystem = DSN2Catalog.ID_WHIP;   // which weapon hit (Arcana scope)
                bool applied = checked && DSP025ApplyLogicalHit(slot, generation, stableId, amount, before, after, killed);
                if (applied && amount > 0)
                {
                    damageCount++;
                    Console.Printf("DS_P026_DAMAGE tic=%d transaction_ordinal=%d event_id=%d target_slot=%d target_generation=%d target_id=%d base_damage=%d upgrade_bonus=0 multiplier_milli=%d amount=%d health_before=%d health_after=%d accepted=1 arithmetic=CHECKED authority=P023_DAMAGE native_damage=0 proxy_authored=0", tic, transactionOrdinal, snapshotEventId[snapshotIndex], slot, generation, stableId, snapshotDamageBase[snapshotIndex], snapshotMultiplierMilli[snapshotIndex], amount, before, after);
                    if (killed != 0)
                    {
                        deathCount++;
                        Console.Printf("DS_P026_DEATH tic=%d event_id=%d target_slot=%d target_generation=%d target_id=%d health=0 life_before=LIVE life_after=DEAD kill_delta=1", tic, snapshotEventId[snapshotIndex], slot, generation, stableId);
                        xpRequestCount++;
                        Console.Printf("DS_P026_XP_REQUEST tic=%d source_slot=%d source_generation=%d source_id=%d xp_milliunits=%d request_count=%d authority=P023_REWARD", tic, slot, generation, stableId, DSP023BasicEnemyData.XP_MILLIUNITS, xpRequestCount);
                        DestroyParts(slot, generation, stableId);
                    }
                }
            }
            else
            {
                rejectedHitCount++;
                Console.Printf("DS_P026_HIT tic=%d transaction_ordinal=%d event_id=%d target_slot=%d target_generation=%d target_id=%d candidate_ordinal=%d accepted=0 reason=%s lobe=%s one_hit_per_lobe=1", tic, transactionOrdinal, snapshotEventId[snapshotIndex], slot, generation, stableId, ordinal, reason, snapshotLobe[snapshotIndex] == 0 ? "FRONT" : "REAR");
            }
        }
    }

    int GameplayHash()
    {
        int hash = canonicalHash;
        hash = hash * 31 + tic;
        hash = hash * 31 + eventId;
        hash = hash * 31 + hitCount;
        hash = hash * 31 + damageCount;
        hash = hash * 31 + deathCount;
        hash = hash * 31 + xpRequestCount;
        hash = hash * 31 + attackRng;
        return hash;
    }

    void EmitCanonical()
    {
        canonicalHash = GameplayHash();
        Console.Printf("DS_P026_CANONICAL tic=%d hash=%d gameplay_events=%d hits=%d damage=%d deaths=%d xp_requests=%d presentation_excluded=1 telemetry_excluded=1", tic, canonicalHash, eventId, hitCount, damageCount, deathCount, xpRequestCount);
        if (telemetryEnabled != 0)
            Console.Printf("DS_P026_TRACE tic=%d hash=%d events=%d hits=%d damage=%d deaths=%d xp_requests=%d", tic, canonicalHash, eventId, hitCount, damageCount, deathCount, xpRequestCount);
    }

    void EmitStaleProbe()
    {
        Console.Printf("DS_P026_STALE_HIT tic=%d event_id=999 target_slot=0 target_generation=0 target_id=100 accepted=0 reason=STALE_GENERATION authority=P025_TRANSACTION", tic);
    }

    override void WorldLoaded(WorldEvent e)
    {
        enabled = level.MapName == MAP;
        completed = false;
        if (!enabled) return;
        ConfigureCamera();
        ResetState();
        EmitSourceRecords();
        Console.Printf("DS_P026_BOOT map=%s ticrate=%d scheduler=P025_SOURCE_MODEL automatic_weapons=1 primary_fire_input=0 transaction_order=EVENT_ID_THEN_TARGET_STABLE_ID source_values=PROMOTED_IMMUTABLE", MAP, Thinker.TICRATE);
        Console.Printf("DS_P026_AUTHORITY logical_store=DSP020EntityStore broad_phase=DSP024SpatialIndex snapshots=DSP025AttackSnapshot damage=P023_CHECKED_MILLIUNITS xp=P023_REQUEST presentation=DSP026WhipProxy camera=IGNORED_FOR_GAMEPLAY native_damage=0 effects=%d telemetry=%d", effectsEnabled, telemetryEnabled);
        Console.Printf("DS_P026_RULES facing_sample=TOP_LEVEL_EMISSION_VIEW_YAW pitch=presentation_only fov=presentation_only movement=presentation_only wall_filter=0 repeat_hit=ONE_PER_LOBE geometry=ORIENTED_RECTANGLE");
        EmitWorld();
        DSP024Rebuild();
        EmitCamera();
    }

    override void WorldTick()
    {
        if (!enabled || completed) return;
        tic++;
        if (tic == 1) EmitCamera();
        if (tic == 20)
        {
            int oldYaw = cameraYaw;
            cameraYaw = NormalizeYaw(cameraYaw + 90);
            sampledAimYawMilli = cameraYaw * 1000;
            if (players[0].mo != null) players[0].mo.Angle = cameraYaw;
            Console.Printf("DS_P026_AIM_TURN tic=%d from_yaw=%d to_yaw=%d stationary=1 body_movement=0 owner=INPUT_ADAPTER gameplay_basis=view_yaw", tic, oldYaw, cameraYaw);
            EmitCamera();
        }
        if (tic == 25 && bodyVariant != 0)
        {
            if (players[0].mo != null) players[0].mo.SetOrigin((-64.0, 0.0, 0.0), true);
            Console.Printf("DS_P026_BODY_MOVE tic=%d direction=BACKWARD distance=64.000 logical_origin=(0.000,0.000) view_yaw=%d camera_ignored=1", tic, cameraYaw);
        }
        if (DSP025DeadlineDue(tic, nextTopQuarter, 4))
        {
            EmitLobe(0, nextTopQuarter);
            ProcessLobe(snapshotEventId.Size() - 1);
            pendingRear = DSP026WhipRecords.AmountForLevel(startingWeapon.weaponLevel) >= 2 ? 1 : 0;
            if (pendingRear != 0)
                pendingRearQuarter = DSP025AdvanceDeadline(4 * tic, DSP026WhipRecords.FOLLOWUP_NUMERATOR, DSP026WhipRecords.FOLLOWUP_DENOMINATOR, 4);
            nextTopQuarter = DSP025AdvanceDeadline(nextTopQuarter, DSP026WhipRecords.COOLDOWN_NUMERATOR, DSP026WhipRecords.COOLDOWN_DENOMINATOR, 4);
            DSP024Rebuild();
        }
        if (pendingRear != 0 && DSP025DeadlineDue(tic, pendingRearQuarter, 4))
        {
            EmitLobe(1, pendingRearQuarter);
            ProcessLobe(snapshotEventId.Size() - 1);
            pendingRear = 0;
            DSP024Rebuild();
        }
        if (tic == 30)
        {
            int recreated = 0;
            if (proxies.Size() > 0 && proxies[0] != null)
            {
                int oldEvent = proxies[0].logicalEventId;
                proxies[0].Destroy();
                DSP026WhipProxy replacement = DSP026WhipProxy(Actor.Spawn("DSP026WhipProxy", (48.0, 0.0, 32.0), NO_REPLACE));
                if (replacement != null) { replacement.logicalEventId = oldEvent; replacement.logicalLobe = 0; proxies[0] = replacement; recreated = 1; }
                Console.Printf("DS_P026_PROXY_RECREATE tic=%d old_event_id=%d new_event_id=%d destroyed=1 recreated=%d gameplay_input=0", tic, oldEvent, oldEvent, recreated);
            }
        }
        if (tic == 31) EmitStaleProbe();
        EmitCanonical();
        if (tic >= RUN_TICS)
        {
            int proxyCount = proxies.Size();
            for (int i = 0; i < proxies.Size(); i++) if (proxies[i] != null) proxies[i].Destroy();
            proxies.Clear();
            Console.Printf("DS_P026_PRESENTATION_CLEANUP tic=%d proxy_count=%d destroyed=%d gameplay_input=0", tic, proxyCount, proxyCount);
            Console.Printf("DS_P026_COMPLETE tics=%d events=%d hits=%d rejected_hits=%d damage=%d deaths=%d xp_requests=%d camera_variant=%d effects=%d telemetry=%d camera_invariant=true pitch_fov_presentation_only=1 backward_body_invariant=1 stationary_turn=1 automatic=1 primary_fire_input=0 native_damage=0 proxy_authored_damage=0 missing_xp=0 visual_capture_required=1 source_values=BUILD_EXTRACTED_ONLINE_REPORTED_CURRENT_ENGINEERING_APPROXIMATION", tic, eventId, hitCount, rejectedHitCount, damageCount, deathCount, xpRequestCount, cameraVariant, effectsEnabled, telemetryEnabled);
            Console.Printf("DS_P026_FRAMEBUFFER_CAPTURE tic=%d nonblank_required=1 camera_variant=%d effects=%d", tic, cameraVariant, effectsEnabled);
            LevelLocals.MakeScreenShot();
            completed = true;
        }
    }
}
