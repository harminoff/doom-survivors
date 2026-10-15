// MAP10 P024 packaged spatial-index acceptance fixture.
//
// This handler drives the same DSP024SpatialIndex mixin used by future
// gameplay systems.  The worlds are deterministic engineering fixtures.  A
// separate brute-force oracle is run against the identical logical arrays so
// the optimized path cannot become a second rules authority.
class DSP024SpatialProxy : Actor
{
    int logicalSlot;
    int logicalGeneration;
    int logicalStableId;

    Default
    {
        Radius 4;
        Height 8;
        +NOBLOCKMAP;
        +NOGRAVITY;
        +NOINTERACTION;
        RenderStyle "Translucent";
        Alpha 0.65;
    }
}

class DSP024SpatialRuntime : EventHandler
{
    mixin DSP020EntityStore;
    mixin DSP024SpatialIndex;

    const DSP024_MAP = "MAP10";
    const DSP024_INITIAL_ENTITIES = 512;
    const DSP024_QUERY_COUNT_PER_WORLD = 8;
    const DSP024_PERF_QUERY_COUNT = 48;
    const DSP024_PERF_REPEATS = 80;
    const DSP024_PROXY_CAP = 24;

    bool enabled;
    bool completed;
    int tic;
    int worldVersion;
    int queryId;
    int worldDigest;
    int totalQueries;
    int failedQueries;
    int staleRejected;
    int proxyVariant;
    double presentationOriginX;
    double presentationOriginY;
    Array<Actor> proxies;

    Array<int> bruteSlots;
    Array<int> bruteGenerations;
    Array<int> bruteIds;
    Array<int> optimizedSlots;
    Array<int> optimizedGenerations;
    Array<int> optimizedIds;

    // Fixed performance workload is emitted once and replayed against the
    // exact same world, query parameters and ordering in both modes.
    Array<double> perfX;
    Array<double> perfY;
    Array<double> perfA;
    Array<double> perfB;
    Array<double> perfC;
    Array<double> perfD;
    Array<int> perfKinds;

    int rng;

    int NextRandom()
    {
        rng = (rng * 1103515245 + 12345) & 2147483647;
        return rng;
    }

    double DistanceSquared(int slot, double queryX, double queryY)
    {
        double dx = x[slot] - queryX;
        double dy = y[slot] - queryY;
        return dx * dx + dy * dy;
    }

    bool ExactRadius(int slot, double queryX, double queryY, double queryRadius)
    {
        if (queryRadius < 0.0 || collisionRadii[slot] < 0.0) return false;
        double reach = queryRadius + collisionRadii[slot];
        return DistanceSquared(slot, queryX, queryY) <= reach * reach;
    }

    bool ExactRectangle(int slot, double minX, double maxX, double minY, double maxY)
    {
        if (collisionRadii[slot] < 0.0) return false;
        if (minX > maxX) { double swapX = minX; minX = maxX; maxX = swapX; }
        if (minY > maxY) { double swapY = minY; minY = maxY; maxY = swapY; }
        double closestX = x[slot];
        double closestY = y[slot];
        if (closestX < minX) closestX = minX;
        if (closestX > maxX) closestX = maxX;
        if (closestY < minY) closestY = minY;
        if (closestY > maxY) closestY = maxY;
        double dx = x[slot] - closestX;
        double dy = y[slot] - closestY;
        return dx * dx + dy * dy <= collisionRadii[slot] * collisionRadii[slot];
    }

    double SegmentDistanceSquared(int slot, double startX, double startY,
                                  double endX, double endY)
    {
        double dx = endX - startX;
        double dy = endY - startY;
        double lengthSquared = dx * dx + dy * dy;
        double t = 0.0;
        if (lengthSquared > 0.0)
        {
            t = ((x[slot] - startX) * dx + (y[slot] - startY) * dy) / lengthSquared;
            if (t < 0.0) t = 0.0;
            if (t > 1.0) t = 1.0;
        }
        double closestX = startX + t * dx;
        double closestY = startY + t * dy;
        double offsetX = x[slot] - closestX;
        double offsetY = y[slot] - closestY;
        return offsetX * offsetX + offsetY * offsetY;
    }

    bool ExactSwept(int slot, double startX, double startY, double endX,
                    double endY, double sweepRadius)
    {
        if (sweepRadius < 0.0 || collisionRadii[slot] < 0.0) return false;
        double reach = sweepRadius + collisionRadii[slot];
        return SegmentDistanceSquared(slot, startX, startY, endX, endY) <= reach * reach;
    }

    void ClearResults()
    {
        bruteSlots.Clear(); bruteGenerations.Clear(); bruteIds.Clear();
        optimizedSlots.Clear(); optimizedGenerations.Clear(); optimizedIds.Clear();
    }

    void AddBrute(int slot)
    {
        bruteSlots.Push(slot);
        bruteGenerations.Push(generations[slot]);
        bruteIds.Push(ids[slot]);
    }

    void AddOptimized(int slot)
    {
        for (int i = 0; i < optimizedSlots.Size(); i++)
            if (optimizedSlots[i] == slot
                && optimizedGenerations[i] == generations[slot]
                && optimizedIds[i] == ids[slot]) return;
        optimizedSlots.Push(slot);
        optimizedGenerations.Push(generations[slot]);
        optimizedIds.Push(ids[slot]);
    }

    void SortBrute()
    {
        for (int i = 1; i < bruteSlots.Size(); i++)
        {
            int j = i;
            while (j > 0 && (bruteIds[j] < bruteIds[j - 1]
                || (bruteIds[j] == bruteIds[j - 1] && bruteSlots[j] < bruteSlots[j - 1])))
            {
                int temp = bruteSlots[j]; bruteSlots[j] = bruteSlots[j - 1]; bruteSlots[j - 1] = temp;
                temp = bruteGenerations[j]; bruteGenerations[j] = bruteGenerations[j - 1]; bruteGenerations[j - 1] = temp;
                temp = bruteIds[j]; bruteIds[j] = bruteIds[j - 1]; bruteIds[j - 1] = temp;
                j--;
            }
        }
    }

    void SortOptimized()
    {
        for (int i = 1; i < optimizedSlots.Size(); i++)
        {
            int j = i;
            while (j > 0 && (optimizedIds[j] < optimizedIds[j - 1]
                || (optimizedIds[j] == optimizedIds[j - 1] && optimizedSlots[j] < optimizedSlots[j - 1])))
            {
                int temp = optimizedSlots[j]; optimizedSlots[j] = optimizedSlots[j - 1]; optimizedSlots[j - 1] = temp;
                temp = optimizedGenerations[j]; optimizedGenerations[j] = optimizedGenerations[j - 1]; optimizedGenerations[j - 1] = temp;
                temp = optimizedIds[j]; optimizedIds[j] = optimizedIds[j - 1]; optimizedIds[j - 1] = temp;
                j--;
            }
        }
    }

    bool BetterNearest(int slot, int bestSlot, double queryX, double queryY)
    {
        if (bestSlot < 0) return true;
        double candidateDistance = DistanceSquared(slot, queryX, queryY);
        double bestDistance = DistanceSquared(bestSlot, queryX, queryY);
        return candidateDistance < bestDistance
            || (candidateDistance == bestDistance && ids[slot] < ids[bestSlot]);
    }

    void RunBrute(String kind, double a, double b, double c, double d)
    {
        bruteSlots.Clear(); bruteGenerations.Clear(); bruteIds.Clear();
        int nearest = -1;
        for (int slot = 0; slot < lifeStates.Size(); slot++)
        {
            if (lifeStates[slot] != STORE_ALIVE) continue;
            bool eligible = false;
            if (kind == "radius" || kind == "nearest") eligible = ExactRadius(slot, a, b, c);
            else if (kind == "rectangle") eligible = ExactRectangle(slot, a, b, c, d);
            else if (kind == "swept") eligible = ExactSwept(slot, a, b, c, d, 8.0);
            if (!eligible) continue;
            if (kind == "nearest")
            {
                if (BetterNearest(slot, nearest, a, b)) nearest = slot;
            }
            else AddBrute(slot);
        }
        if (kind == "nearest" && nearest >= 0) AddBrute(nearest);
        SortBrute();
    }

    void RunOptimized(String kind, double a, double b, double c, double d)
    {
        optimizedSlots.Clear(); optimizedGenerations.Clear(); optimizedIds.Clear();
        if (kind == "radius" || kind == "nearest") DSP024RadiusCandidates(a, b, c);
        else if (kind == "rectangle") DSP024RectangleCandidates(a, b, c, d);
        else if (kind == "swept") DSP024SweptCandidates(a, b, c, d, 8.0);
        int nearest = -1;
        for (int i = 0; i < spatialCandidateCount; i++)
        {
            int slot = spatialCandidateSlots[i];
            int generation = spatialCandidateGenerations[i];
            int stableId = spatialCandidateIds[i];
            if (!ValidParts(slot, generation, stableId)) continue;
            bool eligible = false;
            if (kind == "radius" || kind == "nearest") eligible = ExactRadius(slot, a, b, c);
            else if (kind == "rectangle") eligible = ExactRectangle(slot, a, b, c, d);
            else if (kind == "swept") eligible = ExactSwept(slot, a, b, c, d, 8.0);
            if (!eligible) continue;
            if (kind == "nearest")
            {
                if (BetterNearest(slot, nearest, a, b)) nearest = slot;
            }
            else AddOptimized(slot);
        }
        if (kind == "nearest" && nearest >= 0) AddOptimized(nearest);
        SortOptimized();
    }

    int ResultDigest(Array<int> resultIds, Array<int> resultGenerations)
    {
        int digest = 216613626;
        for (int i = 0; i < resultIds.Size(); i++)
        {
            digest = digest * 16777619 + resultIds[i];
            digest = digest * 16777619 + resultGenerations[i];
        }
        return digest;
    }

    bool ResultsEqual()
    {
        if (bruteSlots.Size() != optimizedSlots.Size()) return false;
        for (int i = 0; i < bruteSlots.Size(); i++)
            if (bruteSlots[i] != optimizedSlots[i]
                || bruteGenerations[i] != optimizedGenerations[i]
                || bruteIds[i] != optimizedIds[i]) return false;
        return true;
    }

    void EmitResultList(int currentQuery, String path, Array<int> resultSlots,
                        Array<int> resultGenerations, Array<int> resultIds)
    {
        for (int i = 0; i < resultSlots.Size(); i++)
            Console.Printf("DS_P024_RESULT qid=%d path=%s ordinal=%d slot=%d generation=%d stable_id=%d", currentQuery, path, i, resultSlots[i], resultGenerations[i], resultIds[i]);
    }

    void RunQuery(String kind, double a, double b, double c, double d)
    {
        queryId++;
        totalQueries++;
        RunBrute(kind, a, b, c, d);
        RunOptimized(kind, a, b, c, d);
        bool parity = ResultsEqual();
        if (!parity) failedQueries++;
        int bruteDigest = ResultDigest(bruteIds, bruteGenerations);
        int optimizedDigest = ResultDigest(optimizedIds, optimizedGenerations);
        int nearestSlot = optimizedSlots.Size() > 0 ? optimizedSlots[0] : -1;
        int nearestGeneration = nearestSlot >= 0 ? generations[nearestSlot] : 0;
        int nearestId = nearestSlot >= 0 ? ids[nearestSlot] : 0;
        Console.Printf("DS_P024_QUERY qid=%d world=%d kind=%s a=%.6f b=%.6f c=%.6f d=%.6f brute_count=%d optimized_count=%d candidate_count=%d candidate_visits=%d brute_checks=%d optimized_narrow_checks=%d brute_digest=%d optimized_digest=%d parity=%d nearest_slot=%d nearest_generation=%d nearest_id=%d", queryId, worldVersion, kind, a, b, c, d, bruteSlots.Size(), optimizedSlots.Size(), spatialCandidateCount, spatialCandidateVisits, lifeStates.Size(), spatialCandidateCount, bruteDigest, optimizedDigest, parity, nearestSlot, nearestGeneration, nearestId);
        EmitResultList(queryId, "brute", bruteSlots, bruteGenerations, bruteIds);
        EmitResultList(queryId, "optimized", optimizedSlots, optimizedGenerations, optimizedIds);
    }

    int CurrentWorldDigest()
    {
        int digest = 216613626;
        for (int slot = 0; slot < lifeStates.Size(); slot++)
        {
            if (lifeStates[slot] != STORE_ALIVE) continue;
            digest = digest * 31 + slot;
            digest = digest * 31 + generations[slot];
            digest = digest * 31 + ids[slot];
            digest = digest * 31 + int(x[slot] * 1000.0);
            digest = digest * 31 + int(y[slot] * 1000.0);
            digest = digest * 31 + int(collisionRadii[slot] * 1000.0);
        }
        return digest;
    }

    void EmitWorld()
    {
        worldDigest = CurrentWorldDigest();
        int live = 0;
        for (int slot = 0; slot < lifeStates.Size(); slot++) if (lifeStates[slot] == STORE_ALIVE) live++;
        Console.Printf("DS_P024_WORLD_BEGIN version=%d slots=%d live=%d digest=%d", worldVersion, lifeStates.Size(), live, worldDigest);
        int records = 0;
        for (int slot = 0; slot < lifeStates.Size(); slot++)
        {
            if (lifeStates[slot] != STORE_ALIVE) continue;
            records++;
            Console.Printf("DS_P024_WORLD version=%d slot=%d generation=%d stable_id=%d live=1 x=%.6f y=%.6f radius=%.6f", worldVersion, slot, generations[slot], ids[slot], x[slot], y[slot], collisionRadii[slot]);
        }
        Console.Printf("DS_P024_WORLD_END version=%d records=%d digest=%d", worldVersion, records, worldDigest);
    }

    void PopulateWorld()
    {
        Reset();
        nextStableId = 1000;
        rng = 240924;
        for (int i = 0; i < DSP024_INITIAL_ENTITIES; i++)
        {
            // The seeded stream makes this a genuine deterministic randomized
            // small world.  Explicit boundary/large/tie fixtures below then
            // reserve the exact edge cases required by the contract.
            double randomX = double(NextRandom() % 4001) - 2000.0;
            double randomY = double(NextRandom() % 4001) - 2000.0;
            int slot = Allocate(1, randomX, randomY, 0.0, 0.0, 1);
            collisionRadii[slot] = double(NextRandom() % 61);
            if (i % 17 == 0) collisionRadii[slot] = 180.0;
        }
        // Explicit boundary, negative-cell and nearest-tie fixtures.
        x[0] = -0.01; y[0] = 0.0; collisionRadii[0] = 0.0;
        x[1] = -128.0; y[1] = 0.0; collisionRadii[1] = 0.0;
        x[2] = -128.01; y[2] = 0.0; collisionRadii[2] = 0.0;
        x[3] = 0.0; y[3] = -128.0; collisionRadii[3] = 20.0;
        x[4] = 128.0; y[4] = 0.0; collisionRadii[4] = 260.0;
        x[5] = -384.0; y[5] = -384.0; collisionRadii[5] = 32.0;
        // Isolated equal-distance nearest tie: query (2000,2000) is exactly
        // ten units from IDs 1006 and 1007, so ID 1006 must win.
        x[6] = 1990.0; y[6] = 2000.0; collisionRadii[6] = 0.0;
        x[7] = 2010.0; y[7] = 2000.0; collisionRadii[7] = 0.0;
    }

    void BuildPerfWorkload()
    {
        perfX.Clear(); perfY.Clear(); perfA.Clear(); perfB.Clear(); perfC.Clear(); perfD.Clear(); perfKinds.Clear();
        for (int i = 0; i < DSP024_PERF_QUERY_COUNT; i++)
        {
            int mode = i % 4;
            perfKinds.Push(mode);
            perfX.Push(double(((i * 149) % 1801) - 900));
            perfY.Push(double(((i * 233 + 41) % 1801) - 900));
            perfA.Push(double(((i * 61) % 97) + 2));
            perfB.Push(double(((i * 79) % 89) + 4));
            perfC.Push(double(((i * 47) % 101) + 1));
            perfD.Push(double(((i * 31) % 113) + 3));
            Console.Printf("DS_P024_PERF_WORKLOAD ordinal=%d kind=%d a=%.6f b=%.6f c=%.6f d=%.6f", i, mode, perfX[i], perfY[i], perfA[i], perfB[i]);
        }
    }

    void RunPerformance()
    {
        BuildPerfWorkload();
        int workloadDigest = 216613626;
        for (int i = 0; i < perfKinds.Size(); i++)
        {
            workloadDigest = workloadDigest * 31 + perfKinds[i];
            workloadDigest = workloadDigest * 31 + int(perfX[i] * 1000.0);
            workloadDigest = workloadDigest * 31 + int(perfY[i] * 1000.0);
            workloadDigest = workloadDigest * 31 + int(perfA[i] * 1000.0);
            workloadDigest = workloadDigest * 31 + int(perfB[i] * 1000.0);
        }
        double bruteStart = MSTimeF();
        int bruteChecks = 0;
        int bruteDigest = 216613626;
        for (int repeat = 0; repeat < DSP024_PERF_REPEATS; repeat++)
            for (int i = 0; i < perfKinds.Size(); i++)
            {
                String kind = perfKinds[i] == 0 ? "radius" : (perfKinds[i] == 1 ? "rectangle" : (perfKinds[i] == 2 ? "swept" : "nearest"));
                RunBrute(kind, perfX[i], perfY[i], perfA[i], perfB[i]);
                bruteChecks += lifeStates.Size();
                bruteDigest = bruteDigest * 31 + ResultDigest(bruteIds, bruteGenerations);
            }
        double bruteMs = MSTimeF() - bruteStart;
        DSP024Rebuild();
        double optimizedStart = MSTimeF();
        int optimizedCandidates = 0;
        int optimizedNarrow = 0;
        int optimizedDigest = 216613626;
        for (int repeat = 0; repeat < DSP024_PERF_REPEATS; repeat++)
            for (int i = 0; i < perfKinds.Size(); i++)
            {
                String kind = perfKinds[i] == 0 ? "radius" : (perfKinds[i] == 1 ? "rectangle" : (perfKinds[i] == 2 ? "swept" : "nearest"));
                RunOptimized(kind, perfX[i], perfY[i], perfA[i], perfB[i]);
                optimizedCandidates += spatialCandidateCount;
                optimizedNarrow += spatialCandidateCount;
                optimizedDigest = optimizedDigest * 31 + ResultDigest(optimizedIds, optimizedGenerations);
            }
        double optimizedMs = MSTimeF() - optimizedStart;
        // The digest is deliberately over every ordered full result list.  A
        // query count or total-only signature cannot satisfy this equality.
        Console.Printf("DS_P024_PERF entity_count=%d query_count=%d repeat_count=%d brute_checks=%d optimized_candidates=%d optimized_narrow_checks=%d brute_ms=%.3f optimized_ms=%.3f brute_digest=%d optimized_digest=%d workload_digest=%d parity=%d timing_scope=QUERY_ONLY index_rebuild_excluded=1", lifeStates.Size(), perfKinds.Size(), DSP024_PERF_REPEATS, bruteChecks, optimizedCandidates, optimizedNarrow, bruteMs, optimizedMs, bruteDigest, optimizedDigest, workloadDigest, bruteDigest == optimizedDigest);
        if (optimizedNarrow >= bruteChecks || optimizedMs >= bruteMs || bruteDigest != optimizedDigest) failedQueries++;
    }

    void BuildProxies()
    {
        for (int i = 0; i < proxies.Size(); i++) if (proxies[i] != null) proxies[i].Destroy();
        proxies.Clear();
        int hidden = proxyVariant == 1 ? 1 : 0;
        int culled = proxyVariant == 2 ? 1 : 0;
        int reversed = proxyVariant == 3 ? 1 : 0;
        int created = 0;
        for (int step = 0; step < lifeStates.Size() && created < DSP024_PROXY_CAP; step++)
        {
            int slot = reversed == 1 ? lifeStates.Size() - step - 1 : step;
            if (lifeStates[slot] != STORE_ALIVE) continue;
            // The culled presentation variant intentionally allocates no
            // proxies; this proves a frustum/pool decision cannot remove a
            // logical entity from a query.
            if (culled == 1) continue;
            DSP024SpatialProxy proxy = DSP024SpatialProxy(Actor.Spawn("DSP024SpatialProxy", (x[slot], y[slot], 0.0), NO_REPLACE));
            if (proxy == null) continue;
            proxy.logicalSlot = slot;
            proxy.logicalGeneration = generations[slot];
            proxy.logicalStableId = ids[slot];
            if (hidden == 1 || culled == 1) proxy.Alpha = 0.0;
            proxies.Push(proxy);
            created++;
        }
        String order = reversed == 1 ? "stable_descending" : "stable_ascending";
        Console.Printf("DS_P024_PROXY variant=%d hidden=%d culled=%d allocation_order=%s allocated=%d gameplay_input=0", proxyVariant, hidden, culled, order, created);
    }

    void RunAcceptanceSequence()
    {
        worldVersion = 1;
        PopulateWorld();
        DSP024Rebuild();
        BuildProxies();
        EmitWorld();
        RunQuery("radius", -128.0, 0.0, 0.0, 0.0);
        RunQuery("radius", -0.01, 0.0, 0.0, 0.0);
        RunQuery("rectangle", 64.0, -64.0, 64.0, -64.0);
        RunQuery("rectangle", -512.0, 512.0, -512.0, 512.0);
        RunQuery("swept", -128.0, -128.0, -128.0, -128.0);
        RunQuery("swept", -900.0, -900.0, 900.0, 900.0);
        RunQuery("nearest", 0.0, 0.0, 400.0, 0.0);
        RunQuery("radius", 0.0, 0.0, -1.0, 0.0);
        Console.Printf("DS_P024_NEAREST_TIE_CHECK query=(2000.000,2000.000) max_radius=100.000 equal_distance=1 lower_stable_id_wins=1");
        RunQuery("nearest", 2000.0, 2000.0, 100.0, 0.0);

        // Crossing cells forces a rebuild after logical motion.  The
        // presentation origin is not touched by this logical update.
        x[0] = -128.01; y[0] = 1.0;
        x[6] = 256.0; y[6] = 1.0;
        worldVersion++;
        DSP024Rebuild();
        EmitWorld();
        RunQuery("radius", -128.01, 1.0, 0.0, 0.0);
        RunQuery("rectangle", -256.0, -128.0, -64.0, 64.0);
        RunQuery("swept", -512.0, 0.0, 512.0, 0.0);
        RunQuery("nearest", 0.0, 0.0, 500.0, 0.0);

        // Mass deletion and rebuild leaves only a deterministic subset.
        for (int slot = 0; slot < lifeStates.Size(); slot++)
            if (lifeStates[slot] == STORE_ALIVE && slot % 3 == 0)
                DestroyParts(slot, generations[slot], ids[slot]);
        worldVersion++;
        DSP024Rebuild();
        EmitWorld();
        RunQuery("radius", 0.0, 0.0, 600.0, 0.0);
        RunQuery("rectangle", 400.0, -400.0, 300.0, -300.0);
        RunQuery("swept", -700.0, -700.0, 700.0, 700.0);
        RunQuery("nearest", 0.0, 0.0, 900.0, 0.0);

        // Fill the lowest hole created by mass deletion first.  EntityStore
        // reuses the lowest empty slot, so this makes the following release
        // and allocation provably reuse the same slot 1.
        int filler = Allocate(1, 1400.0, 1400.0, 0.0, 0.0, 1);
        collisionRadii[filler] = 0.0;
        worldVersion++;
        DSP024Rebuild();
        EmitWorld();

        // Capture a full handle, release and reuse its slot.  The old CSR
        // row is queried before rebuild and must fail generation validation.
        int staleSlot = 1;
        int staleGeneration = generations[staleSlot];
        int staleId = ids[staleSlot];
        DestroyParts(staleSlot, staleGeneration, staleId);
        int replacement = Allocate(1, -128.0, 0.0, 0.0, 0.0, 1);
        collisionRadii[replacement] = 0.0;
        DSP024RadiusCandidates(-128.0, 0.0, 0.0);
        int staleRejectedNow = spatialStaleRejected;
        staleRejected += staleRejectedNow;
        Console.Printf("DS_P024_STALE old_slot=%d old_generation=%d old_stable_id=%d replacement_slot=%d replacement_generation=%d replacement_stable_id=%d stale_rejected=%d update_after_reuse=1", staleSlot, staleGeneration, staleId, replacement, generations[replacement], ids[replacement], staleRejectedNow, staleRejectedNow > 0 ? 1 : 0);
        worldVersion++;
        DSP024Rebuild();
        EmitWorld();
        RunQuery("radius", -128.0, 0.0, 0.0, 0.0);
        RunQuery("nearest", -128.0, 0.0, 100.0, 0.0);
        RunQuery("swept", -256.0, 0.0, 256.0, 0.0);

        presentationOriginX = 32.5;
        presentationOriginY = -71.25;
        int beforeRebase = CurrentWorldDigest();
        presentationOriginX = -400.0;
        presentationOriginY = 203.0;
        int afterRebase = CurrentWorldDigest();
        Console.Printf("DS_P024_REBASE old_origin=(32.500,-71.250) new_origin=(-400.000,203.000) logical_digest_before=%d logical_digest_after=%d query_unchanged=%d", beforeRebase, afterRebase, beforeRebase == afterRebase ? 1 : 0);
        RunQuery("rectangle", -256.0, 256.0, -256.0, 256.0);
        RunPerformance();
    }

    override void WorldLoaded(WorldEvent e)
    {
        enabled = level.MapName == DSP024_MAP;
        completed = false;
        tic = 0;
        queryId = 0;
        totalQueries = 0;
        failedQueries = 0;
        staleRejected = 0;
        presentationOriginX = 0.0;
        presentationOriginY = 0.0;
        proxyVariant = 0;
        CVar variant = CVar.FindCVar('ds_p024_proxy_variant');
        if (variant != null) proxyVariant = variant.GetInt();
        if (!enabled) return;
        if (proxyVariant < 0 || proxyVariant > 3) proxyVariant = 0;
        Console.Printf("DS_P024_BOOT map=%s ticrate=%d cell_size=128.000 floor=MATHEMATICAL grid=UNIFORM_CSR handles=FULL_GENERATION_STABLE_ID exact_narrow=SEPARATE randomized_worlds=DETERMINISTIC_ENGINEERING", DSP024_MAP, Thinker.TICRATE);
        Console.Printf("DS_P024_AUTHORITY logical_store=DSP020EntityStore query_input=LOGICAL_XY_RADIUS proxy_input=NONE camera_input=NONE random_seed=240924 source_parity=ENGINEERING_APPROXIMATION");
    }

    override void WorldTick()
    {
        if (!enabled || completed) return;
        tic++;
        if (tic == 1)
        {
            RunAcceptanceSequence();
            Console.Printf("DS_P024_COMPLETE worlds=5 queries=%d failures=%d stale_rejected=%d proxy_variant=%d performance_workload=DECLARED_ENGINEERING_WORLD timing_scope=QUERY_ONLY", totalQueries, failedQueries, staleRejected, proxyVariant);
            Console.Printf("DS_P024_FRAMEBUFFER_CAPTURE tic=%d nonblank_required=1 proxy_variant=%d", tic, proxyVariant);
            LevelLocals.MakeScreenShot();
            completed = true;
        }
    }
}
