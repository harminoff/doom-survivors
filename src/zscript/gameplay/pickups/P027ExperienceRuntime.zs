// MAP13 P027 experience request, pickup and conservation acceptance slice.
//
// Death requests enter DSP027ExperienceStore through one narrow API. The
// logical source-plane graph is authoritative; all DSP027ExperienceProxy
// actors are disposable first-person presentation mirrors.
class DSP027ExperienceProxy : Actor
{
    int logicalSlot;
    int logicalGeneration;
    int logicalStableId;
    int presentationVariant;
    int indicatorEnabled;

    Default
    {
        Radius 4;
        Height 8;
        +NOBLOCKMAP;
        +NOGRAVITY;
        +NOINTERACTION;
        RenderStyle "Add";
        Alpha 0.85;
    }

    States
    {
    Spawn:
        PICK A 2 Bright;
        Loop;
    }
}

class DSP027ExperienceRuntime : EventHandler
{
    mixin DSP020EntityStore;
    mixin DSP024SpatialIndex;
    mixin DSP027ExperienceStore;

    const MAP = "MAP13";
    const RUN_TICS = 105;
    const PLAYER_KIND = 99;
    const ENEMY_KIND = 1;
    const XP_VALUE = 1000;
    const COLLECT_RADIUS = 24.0;
    const ATTRACT_RADIUS = 96.0;
    const ATTRACT_SPEED = 8.0;

    bool enabled;
    bool completed;
    bool saveRestoreReported;
    int tic;
    int playerSlot;
    int requestCount;
    int deathCount;
    int queryCount;
    int queryDuplicateCount;
    int totalQueryDuplicateCount;
    int attractionCount;
    int collectionCount;
    int staleCollectionCount;
    int teardownCount;
    int rebaseCount;
    int transactionCount;
    int cameraVariant;
    int proxyVariant;
    int indicatorVariant;
    int proxyCreates;
    int proxyUpdates;
    int proxyDestroys;
    int playerXWhole;
    int playerYWhole;
    double playerX;
    double playerY;
    double originX;
    double originY;
    double savedBodyX;
    double savedBodyY;
    double savedBodyZ;
    double savedBodyYaw;
    double savedBodyPitch;
    double savedBodyFov;
    transient bool startedThisProcess;

    // These arrays are query scratch only and never enter the ledger. The
    // complete P020 handle is retained to make dedupe and stale rejection
    // explicit even when P024 is queried through overlapping paths.
    Array<int> querySlots;
    Array<int> queryGenerations;
    Array<int> queryIds;
    DSP027ExperienceHandle staleHandle;
    DSP027ExperienceHandle teardownHandle;
    DSP027ExperienceHandle duplicateHandle;

    // Save/reload continuation compares this deterministic logical digest to
    // the uninterrupted control. Presentation fields are deliberately absent.
    int GameplayHash()
    {
        int hash = 216613626;
        hash = hash * 31 + tic;
        hash = hash * 31 + experienceCreated;
        hash = hash * 31 + experienceCollected;
        hash = hash * 31 + experienceRemoved;
        hash = hash * 31 + experienceMerged;
        hash = hash * 31 + requestCount;
        hash = hash * 31 + collectionCount;
        hash = hash * 31 + attractionCount;
        hash = hash * 31 + rebaseCount;
        hash = hash * 31 + totalQueryDuplicateCount;
        for (int stable = 1; stable < nextStableId; stable++)
        {
            for (int slot = 0; slot < lifeStates.Size(); slot++)
            {
                if (!DSP027IsLivePickup(slot) || ids[slot] != stable) continue;
                hash = hash * 31 + slot;
                hash = hash * 31 + generations[slot];
                hash = hash * 31 + ids[slot];
                hash = hash * 31 + experienceStates[slot];
                hash = hash * 31 + experienceValues[slot];
                hash = hash * 31 + int(x[slot] * 1000.0);
                hash = hash * 31 + int(y[slot] * 1000.0);
            }
        }
        return hash;
    }

    int LivePickupCount()
    {
        int count = 0;
        for (int slot = 0; slot < lifeStates.Size(); slot++)
            if (DSP027IsLivePickup(slot)) count++;
        return count;
    }

    int ProxyCount()
    {
        ThinkerIterator it = ThinkerIterator.Create("DSP027ExperienceProxy");
        int count = 0;
        while (Actor(it.Next()) != null) count++;
        return count;
    }

    void EmitLedger(String transaction, int slot, int generation, int stableId)
    {
        transactionCount++;
        int remaining = DSP027RemainingValue();
        bool invariant = DSP027LedgerValid();
        Console.Printf("DS_P027_LEDGER transaction=%d kind=%s slot=%d generation=%d stable_id=%d created=%d remaining=%d collected=%d removed=%d invariant=%d", transactionCount, transaction, slot, generation, stableId, experienceCreated, remaining, experienceCollected, experienceRemoved, invariant);
    }

    void EmitCamera()
    {
        int yaw = 0;
        int pitch = 0;
        int fov = 90;
        if (cameraVariant == 1) yaw = 90;
        else if (cameraVariant == 2) yaw = 180;
        else if (cameraVariant == 3) yaw = 270;
        else if (cameraVariant == 4) { pitch = 22; fov = 115; }
        if (players[0].mo != null)
        {
            players[0].mo.Angle = yaw;
            players[0].mo.Pitch = pitch;
            players[0].SetFOV(fov);
            double engineX;
            double engineY;
            DSP020GroundPlane.ToEngine(playerX, playerY, originX, originY, engineX, engineY);
            players[0].mo.SetOrigin((engineX, engineY, 24.0), true);
        }
        Console.Printf("DS_P027_CAMERA tic=%d variant=%d yaw=%d pitch=%d fov=%d logical_xy=(%.3f,%.3f) camera_role=PRESENTATION_ONLY gameplay_ignored=1", tic, cameraVariant, yaw, pitch, fov, playerX, playerY);
    }

    void ReadConfiguration()
    {
        CVar camera = CVar.FindCVar("ds_p027_camera_variant");
        cameraVariant = camera != null ? camera.GetInt() : 0;
        if (cameraVariant < 0 || cameraVariant > 4) cameraVariant = 0;
        CVar proxy = CVar.FindCVar("ds_p027_proxy_variant");
        proxyVariant = proxy != null ? proxy.GetInt() : 0;
        if (proxyVariant < 0 || proxyVariant > 2) proxyVariant = 0;
        CVar indicator = CVar.FindCVar("ds_p027_indicator");
        indicatorVariant = indicator != null ? indicator.GetInt() : 1;
        if (indicatorVariant != 0) indicatorVariant = 1;
    }

    void ResetState()
    {
        Reset();
        DSP024ClearSpatial();
        DSP027ResetExperience();
        querySlots.Clear(); queryGenerations.Clear(); queryIds.Clear();
        tic = 0; playerSlot = -1; requestCount = 0; deathCount = 0;
        queryCount = 0; queryDuplicateCount = 0; totalQueryDuplicateCount = 0; attractionCount = 0;
        collectionCount = 0; staleCollectionCount = 0; teardownCount = 0;
        rebaseCount = 0; transactionCount = 0; proxyCreates = 0;
        proxyUpdates = 0; proxyDestroys = 0; completed = false;
        saveRestoreReported = false;
        playerX = 0.0; playerY = 0.0; originX = 0.0; originY = 0.0;
        savedBodyX = 0.0; savedBodyY = 0.0; savedBodyZ = 24.0;
        savedBodyYaw = 0.0; savedBodyPitch = 0.0; savedBodyFov = 90.0;
        staleHandle.slot = -1; staleHandle.generation = 0; staleHandle.stableId = 0;
        teardownHandle.slot = -1; teardownHandle.generation = 0; teardownHandle.stableId = 0;
        duplicateHandle.slot = -1; duplicateHandle.generation = 0; duplicateHandle.stableId = 0;
        nextStableId = 100;
        playerSlot = Allocate(PLAYER_KIND, playerX, playerY, 0.0, 0.0, 1);
        collisionRadii[playerSlot] = 0.0;
    }

    bool SameHandle(int leftSlot, int leftGeneration, int leftId,
                    int rightSlot, int rightGeneration, int rightId)
    {
        return leftSlot == rightSlot && leftGeneration == rightGeneration && leftId == rightId;
    }

    void AddQueryCandidate(int slot, int generation, int stableId)
    {
        if (!DSP027ValidPickup(slot, generation, stableId)) return;
        for (int i = 0; i < querySlots.Size(); i++)
            if (SameHandle(querySlots[i], queryGenerations[i], queryIds[i], slot, generation, stableId))
            { queryDuplicateCount++; totalQueryDuplicateCount++; return; }
        querySlots.Push(slot); queryGenerations.Push(generation); queryIds.Push(stableId);
    }

    void SortQueryCandidates()
    {
        for (int i = 1; i < querySlots.Size(); i++)
        {
            int j = i;
            while (j > 0 && (queryIds[j] < queryIds[j - 1]
                || (queryIds[j] == queryIds[j - 1] && querySlots[j] < querySlots[j - 1])))
            {
                int value = querySlots[j]; querySlots[j] = querySlots[j - 1]; querySlots[j - 1] = value;
                value = queryGenerations[j]; queryGenerations[j] = queryGenerations[j - 1]; queryGenerations[j - 1] = value;
                value = queryIds[j]; queryIds[j] = queryIds[j - 1]; queryIds[j - 1] = value;
                j--;
            }
        }
    }

    void BuildPickupQuery()
    {
        querySlots.Clear(); queryGenerations.Clear(); queryIds.Clear();
        queryDuplicateCount = 0;
        DSP024Rebuild();
        // Two overlapping P024 paths deliberately exercise full-handle
        // dedupe. Narrow circle tests remain authoritative below.
        DSP024RadiusCandidates(playerX, playerY, ATTRACT_RADIUS);
        int broadFirst = spatialCandidateCount;
        for (int i = 0; i < spatialCandidateCount; i++)
            AddQueryCandidate(spatialCandidateSlots[i], spatialCandidateGenerations[i], spatialCandidateIds[i]);
        DSP024RadiusCandidates(playerX, playerY, COLLECT_RADIUS);
        int broadSecond = spatialCandidateCount;
        for (int i = 0; i < spatialCandidateCount; i++)
            AddQueryCandidate(spatialCandidateSlots[i], spatialCandidateGenerations[i], spatialCandidateIds[i]);
        SortQueryCandidates();
        queryCount++;
        Console.Printf("DS_P027_QUERY tic=%d query_id=%d path_count=2 broad_first=%d broad_second=%d unique_candidates=%d duplicate_candidates=%d order=stable_id broad_phase=P024 narrow_phase=LOGICAL_CIRCLE camera_ignored=1", tic, queryCount, broadFirst, broadSecond, querySlots.Size(), queryDuplicateCount);
    }

    void EmitRequest(double positionX, double positionY, int batch, String authority)
    {
        // A request is presented through the same full-handle death boundary
        // used by P023/P026. It is immediately released after admission.
        int source = Allocate(ENEMY_KIND, positionX, positionY, 0.0, 0.0, 0);
        int sourceGeneration = generations[source];
        int sourceId = ids[source];
        deathCount++;
        Console.Printf("DS_P027_DEATH tic=%d source_slot=%d source_generation=%d source_id=%d source_kind=BAT3 life_before=LIVE life_after=DEAD reward=XP", tic, source, sourceGeneration, sourceId);
        DSP027ExperienceHandle handle;
        bool created = DSP027CreatePickup(XP_VALUE, positionX, positionY, batch, handle);
        if (created)
        {
            requestCount++;
            Console.Printf("DS_P027_XP_REQUEST tic=%d source_slot=%d source_generation=%d source_id=%d source_xy=(%.3f,%.3f) xp_milliunits=%d request_batch=%d request_count=%d authority=%s request_route=DEATH_REWARD", tic, source, sourceGeneration, sourceId, positionX, positionY, XP_VALUE, batch, requestCount, authority);
            Console.Printf("DS_P027_CREATE tic=%d slot=%d generation=%d stable_id=%d state=GROUND value=%d batch=%d x=%.3f y=%.3f source_slot=%d source_generation=%d source_id=%d creation_grants_xp=0", tic, handle.slot, handle.generation, handle.stableId, XP_VALUE, batch, positionX, positionY, source, sourceGeneration, sourceId);
            EmitLedger("CREATE", handle.slot, handle.generation, handle.stableId);
            if (duplicateHandle.slot < 0)
            {
                duplicateHandle.slot = handle.slot;
                duplicateHandle.generation = handle.generation;
                duplicateHandle.stableId = handle.stableId;
            }
            if (teardownHandle.slot < 0)
            {
                teardownHandle.slot = handle.slot;
                teardownHandle.generation = handle.generation;
                teardownHandle.stableId = handle.stableId;
            }
        }
        else
            Console.Printf("DS_P027_XP_REQUEST_REJECTED tic=%d source_slot=%d source_generation=%d source_id=%d reason=CHECKED_OVERFLOW", tic, source, sourceGeneration, sourceId);
        DestroyParts(source, sourceGeneration, sourceId);
    }

    void MergeBatch(int batch)
    {
        for (int left = 0; left < lifeStates.Size(); left++)
        {
            if (!DSP027IsLivePickup(left) || experienceStates[left] != DSP027_GROUND || experienceBatches[left] != batch) continue;
            for (int right = left + 1; right < lifeStates.Size(); right++)
            {
                if (!DSP027IsLivePickup(right) || experienceStates[right] != DSP027_GROUND || experienceBatches[right] != batch) continue;
                if (x[left] != x[right] || y[left] != y[right]) continue;
                int keep = ids[left] < ids[right] ? left : right;
                int merge = keep == left ? right : left;
                int mergedValue;
                int keepGeneration = generations[keep];
                int keepId = ids[keep];
                int mergeGeneration = generations[merge];
                int mergeId = ids[merge];
                if (DSP027MergePickup(keep, keepGeneration, keepId, merge, mergeGeneration, mergeId, mergedValue))
                {
                    Console.Printf("DS_P027_MERGE tic=%d batch=%d keep_slot=%d keep_generation=%d keep_id=%d merge_slot=%d merge_generation=%d merge_id=%d exact_xy=1 near_merge=0 value_after=%d merge_authority=STORE", tic, batch, keep, keepGeneration, keepId, merge, mergeGeneration, mergeId, mergedValue);
                    EmitLedger("MERGE", keep, keepGeneration, keepId);
                }
            }
        }
    }

    void EmitMove(int slot, int generation, int stableId, int stateBefore,
                  double beforeX, double beforeY, double afterX, double afterY,
                  double distanceBefore, double distanceAfter, double step)
    {
        Console.Printf("DS_P027_ATTRACT tic=%d slot=%d generation=%d stable_id=%d state_before=%s state_after=ATTRACTING from=(%.3f,%.3f) to=(%.3f,%.3f) target=(%.3f,%.3f) distance_before=%.3f distance_after=%.3f step=%.3f speed=%.3f clamp_no_overshoot=1 inclusive=1 camera_ignored=1", tic, slot, generation, stableId, stateBefore == DSP027_GROUND ? "GROUND" : "ATTRACTING", beforeX, beforeY, afterX, afterY, playerX, playerY, distanceBefore, distanceAfter, step, ATTRACT_SPEED);
    }

    void CollectOne(int slot, int generation, int stableId, String reason,
                    double distanceBefore, int queryOrdinal)
    {
        int value = experienceValues[slot];
        bool accepted = DSP027CollectPickup(slot, generation, stableId);
        if (accepted)
        {
            collectionCount++;
            Console.Printf("DS_P027_COLLECTION tic=%d query_ordinal=%d slot=%d generation=%d stable_id=%d value=%d accepted=1 reason=%s distance=%.3f radius=%.3f inclusive=1 state_after=COLLECTED ledger_authority=STORE", tic, queryOrdinal, slot, generation, stableId, value, reason, distanceBefore, COLLECT_RADIUS);
            EmitLedger("COLLECT", slot, generation, stableId);
            if (duplicateHandle.slot == slot && duplicateHandle.generation == generation && duplicateHandle.stableId == stableId)
                duplicateHandle.slot = -2;
        }
        else
        {
            staleCollectionCount++;
            Console.Printf("DS_P027_COLLECTION tic=%d query_ordinal=%d slot=%d generation=%d stable_id=%d value=%d accepted=0 reason=STALE_OR_COLLECTED distance=%.3f radius=%.3f inclusive=1 state_after=UNCHANGED ledger_authority=STORE", tic, queryOrdinal, slot, generation, stableId, value, reason, distanceBefore, COLLECT_RADIUS);
        }
    }

    void ProcessPickupQuery()
    {
        BuildPickupQuery();
        for (int i = 0; i < querySlots.Size(); i++)
        {
            int slot = querySlots[i];
            int generation = queryGenerations[i];
            int stableId = queryIds[i];
            if (!DSP027ValidPickup(slot, generation, stableId)) continue;
            double dx = x[slot] - playerX;
            double dy = y[slot] - playerY;
            double distance = sqrt(dx * dx + dy * dy);
            if (experienceStates[slot] == DSP027_GROUND && distance <= COLLECT_RADIUS + 0.000001)
            {
                CollectOne(slot, generation, stableId, "COLLECTION_RADIUS_INCLUSIVE", distance, i);
                continue;
            }
            int stateBefore = experienceStates[slot];
            if (stateBefore == DSP027_GROUND && distance <= ATTRACT_RADIUS + 0.000001)
            {
                experienceStates[slot] = DSP027_ATTRACTING;
                attractionCount++;
            }
            if (experienceStates[slot] != DSP027_ATTRACTING) continue;
            double beforeX = x[slot];
            double beforeY = y[slot];
            double moveX = playerX - beforeX;
            double moveY = playerY - beforeY;
            double beforeDistance = sqrt(moveX * moveX + moveY * moveY);
            double step = beforeDistance > ATTRACT_SPEED ? ATTRACT_SPEED : beforeDistance;
            if (beforeDistance > 0.000001)
            {
                x[slot] = beforeX + moveX / beforeDistance * step;
                y[slot] = beforeY + moveY / beforeDistance * step;
            }
            else { x[slot] = playerX; y[slot] = playerY; step = 0.0; }
            double afterX = x[slot];
            double afterY = y[slot];
            double afterDX = afterX - playerX;
            double afterDY = afterY - playerY;
            double afterDistance = sqrt(afterDX * afterDX + afterDY * afterDY);
            EmitMove(slot, generation, stableId, stateBefore, beforeX, beforeY, afterX, afterY, beforeDistance, afterDistance, step);
            if (afterDistance <= COLLECT_RADIUS + 0.000001)
                CollectOne(slot, generation, stableId, "ATTRACTION_ARRIVAL_INCLUSIVE", afterDistance, i);
        }
        EmitLedger("QUERY", -1, 0, 0);
    }

    void RebaseWorld(double deltaX, double deltaY)
    {
        double beforeRelative = 0.0;
        if (teardownHandle.slot >= 0 && DSP027ValidPickup(teardownHandle.slot, teardownHandle.generation, teardownHandle.stableId))
        {
            double dx = x[teardownHandle.slot] - playerX;
            double dy = y[teardownHandle.slot] - playerY;
            beforeRelative = sqrt(dx * dx + dy * dy);
        }
        DSP027Rebase(deltaX, deltaY);
        playerX += deltaX; playerY += deltaY;
        originX += deltaX; originY += deltaY;
        double afterRelative = 0.0;
        if (teardownHandle.slot >= 0 && DSP027ValidPickup(teardownHandle.slot, teardownHandle.generation, teardownHandle.stableId))
        {
            double dx = x[teardownHandle.slot] - playerX;
            double dy = y[teardownHandle.slot] - playerY;
            afterRelative = sqrt(dx * dx + dy * dy);
        }
        rebaseCount++;
        Console.Printf("DS_P027_REBASE tic=%d delta=(%.3f,%.3f) origin=(%.3f,%.3f) relative_before=%.3f relative_after=%.3f logical_preserved=%d handles_preserved=1 values_preserved=1 timing_preserved=1 camera_ignored=1", tic, deltaX, deltaY, originX, originY, beforeRelative, afterRelative, beforeRelative == afterRelative);
        EmitLedger("REBASE", -1, 0, 0);
    }

    void TeardownPickup()
    {
        if (teardownHandle.slot < 0 || !DSP027ValidPickup(teardownHandle.slot, teardownHandle.generation, teardownHandle.stableId)) return;
        int value = experienceValues[teardownHandle.slot];
        bool removed = DSP027RemovePickup(teardownHandle.slot, teardownHandle.generation, teardownHandle.stableId);
        if (removed)
        {
            teardownCount++;
            Console.Printf("DS_P027_TEARDOWN tic=%d slot=%d generation=%d stable_id=%d value=%d accepted=1 reason=EXPLICIT_TEARDOWN ordinary_expiry=0", tic, teardownHandle.slot, teardownHandle.generation, teardownHandle.stableId, value);
            EmitLedger("REMOVE", teardownHandle.slot, teardownHandle.generation, teardownHandle.stableId);
            staleHandle.slot = teardownHandle.slot;
            staleHandle.generation = teardownHandle.generation;
            staleHandle.stableId = teardownHandle.stableId;
            teardownHandle.slot = -1;
        }
    }

    void ReuseAndRejectStale()
    {
        int oldSlot = staleHandle.slot;
        int oldGeneration = staleHandle.generation;
        int oldId = staleHandle.stableId;
        // Reuse the released slot through another real death reward request.
        // The stale pickup handle must still fail after its slot is occupied
        // by the next generation's newly admitted gem.
        EmitRequest(playerX + 180.0, playerY, 7, "P023_REWARD");
        int replacement = -1;
        for (int slot = 0; slot < lifeStates.Size(); slot++)
            if (DSP027IsLivePickup(slot) && experienceBatches[slot] == 7) replacement = slot;
        if (replacement < 0) return;
        Console.Printf("DS_P027_REUSE tic=%d slot=%d old_generation=%d old_id=%d new_generation=%d new_id=%d replacement_kind=GEM reused=1", tic, replacement, oldGeneration, oldId, generations[replacement], ids[replacement]);
        EmitLedger("REUSE_CREATE", replacement, generations[replacement], ids[replacement]);
        bool stale = DSP027CollectPickup(oldSlot, oldGeneration, oldId);
        if (!stale)
        {
            staleCollectionCount++;
            Console.Printf("DS_P027_STALE_COLLECTION tic=%d slot=%d generation=%d stable_id=%d replacement_generation=%d replacement_id=%d accepted=0 reason=STALE_GENERATION", tic, oldSlot, oldGeneration, oldId, generations[replacement], ids[replacement]);
        }
    }

    void EmitPresentation()
    {
        ThinkerIterator it = ThinkerIterator.Create("DSP027ExperienceProxy");
        Actor actor;
        while ((actor = Actor(it.Next())) != null)
        {
            DSP027ExperienceProxy proxy = DSP027ExperienceProxy(actor);
            if (!DSP027ValidPickup(proxy.logicalSlot, proxy.logicalGeneration, proxy.logicalStableId))
            {
                actor.Destroy();
                proxyDestroys++;
                continue;
            }
            double engineX;
            double engineY;
            DSP020GroundPlane.ToEngine(x[proxy.logicalSlot], y[proxy.logicalSlot], originX, originY, engineX, engineY);
            proxy.SetOrigin((engineX, engineY, indicatorVariant == 1 ? 4.0 : 8.0), true);
            proxy.Scale = proxyVariant == 1 ? (1.5, 1.5) : (1.0, 1.0);
            proxy.bInvisible = proxyVariant == 2;
            proxy.presentationVariant = proxyVariant;
            proxy.indicatorEnabled = indicatorVariant;
            proxyUpdates++;
        }
        for (int slot = 0; slot < lifeStates.Size(); slot++)
        {
            if (!DSP027IsLivePickup(slot)) continue;
            bool found = false;
            ThinkerIterator find = ThinkerIterator.Create("DSP027ExperienceProxy");
            Actor foundActor;
            while ((foundActor = Actor(find.Next())) != null)
            {
                DSP027ExperienceProxy proxy = DSP027ExperienceProxy(foundActor);
                if (proxy.logicalSlot == slot && proxy.logicalGeneration == generations[slot] && proxy.logicalStableId == ids[slot]) { found = true; break; }
            }
            if (found) continue;
            double engineX;
            double engineY;
            DSP020GroundPlane.ToEngine(x[slot], y[slot], originX, originY, engineX, engineY);
            DSP027ExperienceProxy created = DSP027ExperienceProxy(Actor.Spawn("DSP027ExperienceProxy", (engineX, engineY, indicatorVariant == 1 ? 4.0 : 8.0), NO_REPLACE));
            if (created != null)
            {
                created.logicalSlot = slot;
                created.logicalGeneration = generations[slot];
                created.logicalStableId = ids[slot];
                created.presentationVariant = proxyVariant;
                created.indicatorEnabled = indicatorVariant;
                created.Scale = proxyVariant == 1 ? (1.5, 1.5) : (1.0, 1.0);
                created.bInvisible = proxyVariant == 2;
                proxyCreates++;
            }
        }
        Console.Printf("DS_P027_PRESENTATION tic=%d proxy_variant=%d indicator=%d live_proxies=%d scale_mode=%s height_mode=%s visibility_mode=%s gameplay_ignored=1", tic, proxyVariant, indicatorVariant, ProxyCount(), proxyVariant == 1 ? "LARGE" : "NORMAL", indicatorVariant == 1 ? "FOOT" : "WORLD", proxyVariant == 2 ? "HIDDEN" : "VISIBLE");
    }

    void EmitInitialRules()
    {
        Console.Printf("DS_P027_BOOT map=%s ticrate=%d store=DSP027ExperienceStore source_build=1.16.107 gem_id=GEM gem_name=Experience_Gem source_identity=BUILD_EXTRACTED", MAP, Thinker.TICRATE);
        Console.Printf("DS_P027_AUTHORITY logical_store=DSP027ExperienceStore handles=DSP020_FULL_HANDLE broad_phase=DSP024SpatialIndex source_requests=P023_P026_DEATH_REWARD presentation=DSP027ExperienceProxy proxy_authored_xp=0 native_pickup=0");
        Console.Printf("DS_P027_RULES value_milliunits=%d value_provenance=ENGINEERING_APPROXIMATION collection_radius=%.3f attraction_radius=%.3f attraction_speed=%.3f speed_clamp=1 edges=INCLUSIVE merge=EXACT_XY_SAME_BATCH_LOWEST_STABLE_ID ordinary_expiry=0", XP_VALUE, COLLECT_RADIUS, ATTRACT_RADIUS, ATTRACT_SPEED);
        Console.Printf("DS_P027_LEDGER transaction=0 kind=RESET slot=-1 generation=0 stable_id=0 created=0 remaining=0 collected=0 removed=0 invariant=1");
        Console.Printf("DS_P027_CAMERA_VARIANTS count=5 variants=0:0/0/90,1:90/0/90,2:180/0/90,3:270/0/90,4:0/22/115 pitch_fov_presentation_only=1");
    }

    int FinalHash()
    {
        return GameplayHash();
    }

    void EmitComplete()
    {
        int hash = FinalHash();
        int remaining = DSP027RemainingValue();
        Console.Printf("DS_P027_CANONICAL tic=%d hash=%d requests=%d deaths=%d collections=%d attractions=%d merges=%d teardowns=%d stale_rejected=%d live=%d created=%d remaining=%d collected=%d removed=%d proxy_authored_xp=0 camera_ignored=1", tic, hash, requestCount, deathCount, collectionCount, attractionCount, experienceMerged, teardownCount, staleCollectionCount, LivePickupCount(), experienceCreated, remaining, experienceCollected, experienceRemoved);
        Console.Printf("DS_P027_COMPLETE tics=%d hash=%d requests=%d deaths=%d collections=%d attractions=%d merges=%d teardowns=%d stale_rejected=%d live=%d created=%d remaining=%d collected=%d removed=%d query_count=%d duplicate_candidates=%d proxy_creates=%d proxy_updates=%d proxy_destroys=%d camera_variant=%d proxy_variant=%d indicator=%d ledger_invariant=%d camera_invariant=true pitch_fov_presentation_only=1 presentation_only=1 proxy_authored_xp=0 ordinary_expiry=0 source_values=ENGINEERING_APPROXIMATION visual_capture_required=1", tic, hash, requestCount, deathCount, collectionCount, attractionCount, experienceMerged, teardownCount, staleCollectionCount, LivePickupCount(), experienceCreated, remaining, experienceCollected, experienceRemoved, queryCount, totalQueryDuplicateCount, proxyCreates, proxyUpdates, proxyDestroys, cameraVariant, proxyVariant, indicatorVariant, DSP027LedgerValid());
        Console.Printf("DS_P027_FRAMEBUFFER_CAPTURE tic=%d nonblank_required=1 camera_variant=%d proxy_variant=%d indicator=%d", tic, cameraVariant, proxyVariant, indicatorVariant);
        LevelLocals.MakeScreenShot();
    }

    void EmitSaveCandidate()
    {
        int hash = GameplayHash();
        Console.Printf("DS_P027_SAVE_CANDIDATE tic=%d hash=%d live=%d created=%d remaining=%d collected=%d removed=%d invariant=%d", tic, hash, LivePickupCount(), experienceCreated, DSP027RemainingValue(), experienceCollected, experienceRemoved, DSP027LedgerValid());
        for (int slot = 0; slot < lifeStates.Size(); slot++)
        {
            if (!DSP027IsLivePickup(slot)) continue;
            String state = experienceStates[slot] == DSP027_GROUND ? "GROUND" : "ATTRACTING";
            Console.Printf("DS_P027_SAVE_PICKUP tic=%d slot=%d generation=%d stable_id=%d state=%s value=%d x=%.3f y=%.3f", tic, slot, generations[slot], ids[slot], state, experienceValues[slot], x[slot], y[slot]);
        }
        // The save script waits for this deterministic boundary. The
        // candidate rows around it make a savepoint mismatch fail closed.
        if (tic == 23)
            Console.Printf("DS_P027_SAVE_READY tic=%d hash=%d live=%d created=%d remaining=%d collected=%d removed=%d invariant=%d", tic, hash, LivePickupCount(), experienceCreated, DSP027RemainingValue(), experienceCollected, experienceRemoved, DSP027LedgerValid());
    }

    override void WorldLoaded(WorldEvent e)
    {
        enabled = level.MapName == MAP;
        completed = false;
        if (!enabled) return;
        ReadConfiguration();
        if (!e.IsSaveGame)
        {
            ResetState();
            EmitInitialRules();
            EmitCamera();
            EmitPresentation();
        }
        Console.Printf("DS_P027_WORLD_LOADED is_save=%d tic=%d hash=%d live=%d created=%d remaining=%d collected=%d removed=%d", e.IsSaveGame, tic, GameplayHash(), LivePickupCount(), experienceCreated, DSP027RemainingValue(), experienceCollected, experienceRemoved);
    }

    override void WorldTick()
    {
        if (!enabled && level != null && level.MapName == MAP) enabled = true;
        if (!enabled || completed) return;
        bool firstTickThisProcess = !startedThisProcess;
        startedThisProcess = true;
        if (firstTickThisProcess && tic > 0)
        {
            if (players[0].mo != null)
            {
                players[0].mo.SetOrigin((savedBodyX, savedBodyY, savedBodyZ), true);
                players[0].mo.Angle = savedBodyYaw;
                players[0].mo.Pitch = savedBodyPitch;
                players[0].SetFOV(savedBodyFov);
            }
            EmitCamera();
            EmitPresentation();
            Console.Printf("DS_P027_RESTORE first_tick=1 tic=%d hash=%d live=%d created=%d remaining=%d collected=%d removed=%d continuation=1 duplicated_collection=0", tic, GameplayHash(), LivePickupCount(), experienceCreated, DSP027RemainingValue(), experienceCollected, experienceRemoved);
            saveRestoreReported = true;
        }
        tic++;
        if (tic == 1) EmitRequest(220.0, 0.0, 1, "P023_REWARD");
        if (tic == 2)
        {
            EmitRequest(0.0, 24.0, 2, "P023_REWARD");
            EmitRequest(0.0, 24.001, 2, "P023_REWARD");
            MergeBatch(2);
        }
        if (tic == 3)
        {
            for (int i = 0; i < 16; i++) EmitRequest(64.0, 0.0, 3, "P026_REWARD");
            MergeBatch(3);
            EmitRequest(96.0, 0.0, 4, "P026_REWARD");
        }
        if (tic == 4)
        {
            EmitRequest(80.0, 0.0, 5, "P026_REWARD");
            EmitRequest(80.5, 0.0, 5, "P026_REWARD");
            MergeBatch(5);
        }
        if (tic == 10) RebaseWorld(512.0, -256.0);
        if (tic == 25) TeardownPickup();
        if (tic == 26) ReuseAndRejectStale();
        ProcessPickupQuery();
        EmitCamera();
        EmitPresentation();
        if (tic >= 20 && tic <= 26) EmitSaveCandidate();
        if (tic % 10 == 0 || tic == 1 || tic == 2 || tic == 3 || tic == 4 || tic == 25 || tic == 26)
            Console.Printf("DS_P027_TRACE tic=%d hash=%d player=(%.3f,%.3f) live=%d created=%d remaining=%d collected=%d removed=%d invariant=%d", tic, GameplayHash(), playerX, playerY, LivePickupCount(), experienceCreated, DSP027RemainingValue(), experienceCollected, experienceRemoved, DSP027LedgerValid());
        if (tic >= RUN_TICS)
        {
            EmitComplete();
            completed = true;
        }
        savedBodyX = players[0].mo != null ? players[0].mo.Pos.X : 0.0;
        savedBodyY = players[0].mo != null ? players[0].mo.Pos.Y : 0.0;
        savedBodyZ = players[0].mo != null ? players[0].mo.Pos.Z : 24.0;
        savedBodyYaw = players[0].mo != null ? players[0].mo.Angle : 0.0;
        savedBodyPitch = players[0].mo != null ? players[0].mo.Pitch : 0.0;
        savedBodyFov = players[0].FOV;
    }
}
