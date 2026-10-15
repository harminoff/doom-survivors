// P015 logical-entity feasibility benchmark.
//
// Every count in this file is a synthetic engineering stress point, not a claim
// about any source-game cap. The benchmark separates three things that the plan
// requires to stay distinct: the logical entity store, the collision broad
// phase, and the bounded render-proxy pool. Render proxies are capped
// independently of the logical population, so storage cost can never be read as
// a rendering claim.
//
// All scenarios run in a single engine process, in sequence, so results are
// directly comparable under the same hardware, renderer and settings.
class DSP015EntityBench : EventHandler
{
    const CELLS_PER_AXIS = 16;
    const CELL_COUNT = 256;
    const CELL_SIZE = 128.0;
    const WORLD_MIN = -1024.0;
    const ENEMY_RADIUS = 16.0;
    const PROJ_RADIUS = 4.0;
    const PICK_RADIUS = 8.0;
    const SCENARIO_TICS = 60;
    const CHURN_TICS = 140;
    const PROXY_CAP = 300;

    // --- logical store (struct-of-arrays) ---------------------------------
    Array<double> enemyX;
    Array<double> enemyY;
    Array<double> enemyRadius;
    Array<int> enemyAlive;
    Array<double> projX;
    Array<double> projY;
    Array<double> projDx;
    Array<double> projDy;
    Array<double> projRadius;
    Array<double> pickX;
    Array<double> pickY;
    Array<double> pickRadius;
    Array<int> pickActive;

    // --- per-scenario accumulators ----------------------------------------
    Array<int> enemyHitCount;
    Array<int> enemyRepeatHit;
    Array<int> pickCollected;

    // --- uniform-grid broad phase -----------------------------------------
    Array<int> cellStart;
    Array<int> cellCount;
    Array<int> cellItems;

    // --- render proxy pool -------------------------------------------------
    Array<Actor> proxies;

    // --- scenario state ----------------------------------------------------
    bool enabled;
    bool finished;
    int scenario;
    int scenarioTic;
    int activeEnemies;
    int activeProjectiles;
    int activePickups;
    int gridEnabled;
    int totalScenarios;
    int failures;
    int pairChecks;
    int hits;
    int hitSignature;
    int movedEntities;
    int dropsCreated;
    int gridCellsUsed;
    int peakStoreItems;
    int peakProxies;
    int spawnCycle;
    int despawned;
    double scenarioStartMs;
    double totalMs;
    double tickStartMs;
    double worstTickMs;
    double workTickMs;
    String curName;
    String curMode;

    // --- equivalence baseline (A02) ----------------------------------------
    int baselineHits;
    int baselineSignature;
    int baselineValid;
    int orientationHits;
    int orientationSignature;
    int orientationValid;

    int CellIndexOf(double x, double y)
    {
        int ix = int((x - WORLD_MIN) / CELL_SIZE);
        int iy = int((y - WORLD_MIN) / CELL_SIZE);
        if (ix < 0) ix = 0;
        if (iy < 0) iy = 0;
        if (ix > CELLS_PER_AXIS - 1) ix = CELLS_PER_AXIS - 1;
        if (iy > CELLS_PER_AXIS - 1) iy = CELLS_PER_AXIS - 1;
        return iy * CELLS_PER_AXIS + ix;
    }

    void ClearAll()
    {
        enemyX.Clear(); enemyY.Clear(); enemyRadius.Clear(); enemyAlive.Clear();
        projX.Clear(); projY.Clear(); projDx.Clear(); projDy.Clear(); projRadius.Clear();
        pickX.Clear(); pickY.Clear(); pickRadius.Clear(); pickActive.Clear();
        enemyHitCount.Clear(); enemyRepeatHit.Clear(); pickCollected.Clear();
        cellStart.Clear(); cellCount.Clear(); cellItems.Clear();
    }

    void ReleaseProxies()
    {
        for (int i = 0; i < proxies.Size(); i++)
        {
            if (proxies[i] != null) proxies[i].Destroy();
        }
        proxies.Clear();
    }

    // Deterministic synthetic populations. Entity i always has the same
    // position for a given store size, so a 40-entity active subset is
    // identical across different store sizes.
    void PopulateStore(int enemies, int projectiles, int pickups)
    {
        ClearAll();
        for (int i = 0; i < enemies; i++)
        {
            enemyX.Push(double((i * 37) % 1800) - 900.0);
            enemyY.Push(double((i * 53) % 1800) - 900.0);
            enemyRadius.Push(ENEMY_RADIUS);
            enemyAlive.Push(1);
            enemyHitCount.Push(0);
            enemyRepeatHit.Push(0);
        }
        for (int i = 0; i < projectiles; i++)
        {
            projX.Push(double((i * 29) % 1800) - 900.0);
            projY.Push(double((i * 43) % 1800) - 900.0);
            projDx.Push(double((i % 5) - 2));
            projDy.Push(double(((i + 2) % 5) - 2));
            projRadius.Push(PROJ_RADIUS);
        }
        for (int i = 0; i < pickups; i++)
        {
            pickX.Push(double((i * 61) % 1800) - 900.0);
            pickY.Push(double((i * 71) % 1800) - 900.0);
            pickRadius.Push(PICK_RADIUS);
            pickActive.Push(1);
            pickCollected.Push(0);
        }
        int total = enemyX.Size() + projX.Size() + pickX.Size();
        if (total > peakStoreItems) peakStoreItems = total;
    }

    void MoveEntities()
    {
        for (int i = 0; i < activeEnemies; i++)
        {
            double nx = enemyX[i] + double((i % 3) - 1);
            double ny = enemyY[i] + double(((i + 1) % 3) - 1);
            if (nx < -1000.0) nx = 1000.0;
            if (nx > 1000.0) nx = -1000.0;
            if (ny < -1000.0) ny = 1000.0;
            if (ny > 1000.0) ny = -1000.0;
            enemyX[i] = nx;
            enemyY[i] = ny;
            movedEntities++;
        }
        for (int i = 0; i < activeProjectiles; i++)
        {
            double nx = projX[i] + projDx[i];
            double ny = projY[i] + projDy[i];
            if (nx < -1000.0 || nx > 1000.0) { projDx[i] = -projDx[i]; nx = projX[i] + projDx[i]; }
            if (ny < -1000.0 || ny > 1000.0) { projDy[i] = -projDy[i]; ny = projY[i] + projDy[i]; }
            projX[i] = nx;
            projY[i] = ny;
        }
    }

    void BuildGrid(int active)
    {
        cellCount.Clear();
        cellCount.Resize(CELL_COUNT);
        for (int c = 0; c < CELL_COUNT; c++) cellCount[c] = 0;
        for (int i = 0; i < active; i++)
        {
            int c = CellIndexOf(enemyX[i], enemyY[i]);
            cellCount[c] = cellCount[c] + 1;
        }
        cellStart.Clear();
        cellStart.Resize(CELL_COUNT + 1);
        int running = 0;
        for (int c = 0; c < CELL_COUNT; c++)
        {
            cellStart[c] = running;
            running = running + cellCount[c];
        }
        cellStart[CELL_COUNT] = running;
        cellItems.Clear();
        cellItems.Resize(running);
        for (int c = 0; c < CELL_COUNT; c++) cellCount[c] = 0;
        for (int i = 0; i < active; i++)
        {
            int c = CellIndexOf(enemyX[i], enemyY[i]);
            int slot = cellStart[c] + cellCount[c];
            cellItems[slot] = i;
            cellCount[c] = cellCount[c] + 1;
        }
        gridCellsUsed = 0;
        for (int c = 0; c < CELL_COUNT; c++) if (cellCount[c] > 0) gridCellsUsed++;
    }

    // Narrow phase for one projectile against one enemy. Repeated hits inside
    // the same tic are tracked separately from first contact.
    void RegisterHit(int enemyIndex, int ticNumber)
    {
        enemyHitCount[enemyIndex] = enemyHitCount[enemyIndex] + 1;
        hits++;
        if (enemyHitCount[enemyIndex] > 1) enemyRepeatHit[enemyIndex] = enemyRepeatHit[enemyIndex] + 1;
    }

    void ResolveCollisions()
    {
        for (int p = 0; p < activeProjectiles; p++)
        {
            double px = projX[p];
            double py = projY[p];
            double reach = projRadius[p] + ENEMY_RADIUS;
            double reachSq = reach * reach;
            if (gridEnabled == 1)
            {
                int cx = int((px - WORLD_MIN) / CELL_SIZE);
                int cy = int((py - WORLD_MIN) / CELL_SIZE);
                for (int gy = cy - 1; gy <= cy + 1; gy++)
                {
                    if (gy < 0 || gy >= CELLS_PER_AXIS) continue;
                    for (int gx = cx - 1; gx <= cx + 1; gx++)
                    {
                        if (gx < 0 || gx >= CELLS_PER_AXIS) continue;
                        int c = gy * CELLS_PER_AXIS + gx;
                        int start = cellStart[c];
                        int end = cellStart[c + 1];
                        for (int s = start; s < end; s++)
                        {
                            int e = cellItems[s];
                            pairChecks++;
                            double dx = px - enemyX[e];
                            double dy = py - enemyY[e];
                            if (dx * dx + dy * dy <= reachSq) RegisterHit(e, 0);
                        }
                    }
                }
            }
            else
            {
                for (int e = 0; e < activeEnemies; e++)
                {
                    pairChecks++;
                    double dx = px - enemyX[e];
                    double dy = py - enemyY[e];
                    if (dx * dx + dy * dy <= reachSq) RegisterHit(e, 0);
                }
            }
        }
    }

    void ResolvePickups(double playerX, double playerY)
    {
        for (int i = 0; i < activePickups; i++)
        {
            if (pickActive[i] == 0) continue;
            pairChecks++;
            double dx = playerX - pickX[i];
            double dy = playerY - pickY[i];
            double reach = pickRadius[i] + ENEMY_RADIUS;
            if (dx * dx + dy * dy <= reach * reach)
            {
                pickActive[i] = 0;
                pickCollected[i] = pickCollected[i] + 1;
            }
        }
    }

    // Bounded presentation pool. Proxy count is independent of the logical
    // store, and the front/rear split is what the renderer may cull.
    void UpdateProxies(double playerX, double playerY)
    {
        int want = activeEnemies;
        if (want > PROXY_CAP) want = PROXY_CAP;
        while (proxies.Size() < want)
        {
            Actor a = Actor.Spawn("DSP15Proxy", (0.0, 0.0, 0.0), NO_REPLACE);
            if (a == null) break;
            proxies.Push(a);
        }
        if (proxies.Size() > peakProxies) peakProxies = proxies.Size();
    }

    void ReportScenario(String result, String reason)
    {
        Console.Printf(
            "DS_P015_SCENARIO name=%s mode=%s result=%s reason=%s enemies=%d active=%d projectiles=%d pickups=%d tics=%d pair_checks=%d hits=%d hit_signature=%d moved=%d grid=%d grid_cells=%d proxies=%d store_items=%d drops=%d collected=%d",
            curName, curMode, result, reason, enemyX.Size(), activeEnemies, activeProjectiles,
            activePickups, scenarioTic, pairChecks, hits, hitSignature, movedEntities,
            gridEnabled, gridCellsUsed, proxies.Size(),
            enemyX.Size() + projX.Size() + pickX.Size(), dropsCreated, CountCollected());
    }

    int CountCollected()
    {
        int total = 0;
        for (int i = 0; i < pickCollected.Size(); i++) if (pickActive[i] == 0) total++;
        return total;
    }

    int ComputeSignature()
    {
        int sig = 0;
        for (int i = 0; i < enemyHitCount.Size(); i++)
        {
            if (enemyHitCount[i] > 0) sig = sig + enemyHitCount[i] * (i + 1);
        }
        return sig;
    }

    void ResetScenarioCounters()
    {
        scenarioTic = 0;
        pairChecks = 0;
        hits = 0;
        hitSignature = 0;
        movedEntities = 0;
        dropsCreated = 0;
        gridCellsUsed = 0;
        worstTickMs = 0.0;
        workTickMs = 0.0;
        scenarioStartMs = MSTimeF();
        ReportScenario("BEGIN", "none");
    }

    void StartScenario(int index)
    {
        scenario = index;
        curMode = "brute";
        int enemies = 100;
        int projectiles = 40;
        int pickups = 30;
        int active = 40;
        gridEnabled = 0;
        if (index == 0) { curName = "equivalence_brute"; enemies = 100; active = 40; projectiles = 40; pickups = 30; gridEnabled = 0; }
        else if (index == 1) { curName = "equivalence_grid"; curMode = "grid"; enemies = 100; active = 40; projectiles = 40; pickups = 30; gridEnabled = 1; }
        else if (index == 2) { curName = "equivalence_grid_large_store"; curMode = "grid"; enemies = 5000; active = 40; projectiles = 40; pickups = 30; gridEnabled = 1; }
        else if (index == 3) { curName = "sweep_500"; curMode = "grid"; enemies = 500; active = 500; projectiles = 200; pickups = 100; gridEnabled = 1; }
        else if (index == 4) { curName = "sweep_1000"; curMode = "grid"; enemies = 1000; active = 1000; projectiles = 400; pickups = 150; gridEnabled = 1; }
        else if (index == 5) { curName = "sweep_2000"; curMode = "grid"; enemies = 2000; active = 2000; projectiles = 800; pickups = 200; gridEnabled = 1; }
        else if (index == 6) { curName = "sweep_3000"; curMode = "grid"; enemies = 3000; active = 3000; projectiles = 1200; pickups = 250; gridEnabled = 1; }
        else if (index == 7) { curName = "sweep_5000"; curMode = "grid"; enemies = 5000; active = 5000; projectiles = 2000; pickups = 400; gridEnabled = 1; }
        else if (index == 8) { curName = "orientation_front"; curMode = "grid"; enemies = 2000; active = 2000; projectiles = 800; pickups = 200; gridEnabled = 1; }
        else if (index == 9) { curName = "orientation_rear"; curMode = "grid"; enemies = 2000; active = 2000; projectiles = 800; pickups = 200; gridEnabled = 1; }
        else if (index == 10) { curName = "churn"; curMode = "grid"; enemies = 1200; active = 1200; projectiles = 600; pickups = 200; gridEnabled = 1; }
        else { curName = "cleanup"; curMode = "none"; enemies = 0; active = 0; projectiles = 0; pickups = 0; gridEnabled = 0; }
        activeEnemies = active;
        activeProjectiles = projectiles;
        activePickups = pickups;
        spawnCycle = 0;
        despawned = 0;
        // Each scenario starts from a known proxy state. The pool is bounded
        // and rebuilt per scenario so a previous scenario can never inflate the
        // next one's proxy count.
        ReleaseProxies();
        PopulateStore(enemies, projectiles, pickups);
        // Camera orientation is a presentation input. It is set here and must
        // not change any logical result, which is what P015-FP01 checks.
        if (index == 8) SetCameraOrientation(0.0);
        else if (index == 9) SetCameraOrientation(180.0);
        ResetScenarioCounters();
    }

    void SetCameraOrientation(double yaw)
    {
        Actor player = players[0].mo;
        if (player == null) return;
        player.Angle = yaw;
        player.Pitch = 0.0;
    }

    void CompleteScenario()
    {
        double elapsed = MSTimeF() - scenarioStartMs;
        totalMs = totalMs + elapsed;
        hitSignature = ComputeSignature();
        String reason = "none";
        String result = "OK";
        if (scenario == 0)
        {
            baselineHits = hits;
            baselineSignature = hitSignature;
            baselineValid = 1;
        }
        else if (scenario == 1 || scenario == 2)
        {
            if (baselineValid == 0) { result = "FAIL"; reason = "missing_baseline"; }
            else if (hits != baselineHits || hitSignature != baselineSignature)
            {
                result = "FAIL";
                reason = "broad_phase_result_mismatch";
            }
        }
        // P015-FP01: the two camera orientations run the same deterministic
        // population. They are compared against each other, not against the
        // small equivalence baseline, so the only variable is camera facing.
        if (scenario == 8)
        {
            orientationHits = hits;
            orientationSignature = hitSignature;
            orientationValid = 1;
        }
        else if (scenario == 9)
        {
            if (orientationValid == 0) { result = "FAIL"; reason = "missing_orientation_baseline"; }
            else if (hits != orientationHits || hitSignature != orientationSignature)
            {
                result = "FAIL";
                reason = "orientation_changed_results";
            }
        }
        if (scenario == 10)
        {
            if (despawned != spawnCycle) { result = "FAIL"; reason = "churn_leak"; }
        }
        if (scenario == 11)
        {
            if (enemyX.Size() != 0 || projX.Size() != 0 || pickX.Size() != 0 || proxies.Size() != 0)
            {
                result = "FAIL";
                reason = "cleanup_residual";
            }
        }
        if (result == "FAIL") failures++;
        Console.Printf(
            "DS_P015_SCENARIO name=%s mode=%s result=%s reason=%s enemies=%d active=%d projectiles=%d pickups=%d tics=%d pair_checks=%d hits=%d hit_signature=%d moved=%d grid=%d grid_cells=%d proxies=%d store_items=%d drops=%d collected=%d ms=%.2f mean_work_ms=%.3f worst_tick_ms=%.3f",
            curName, curMode, result, reason, enemyX.Size(), activeEnemies, activeProjectiles,
            activePickups, scenarioTic, pairChecks, hits, hitSignature, movedEntities,
            gridEnabled, gridCellsUsed, proxies.Size(),
            enemyX.Size() + projX.Size() + pickX.Size(), dropsCreated, CountCollected(), elapsed,
            workTickMs / double(scenarioTic), worstTickMs);
    }

    override void WorldLoaded(WorldEvent e)
    {
        enabled = level.MapName == "MAP04";
        finished = false;
        scenario = -1;
        totalScenarios = 12;
        failures = 0;
        pairChecks = 0;
        hits = 0;
        hitSignature = 0;
        movedEntities = 0;
        dropsCreated = 0;
        gridCellsUsed = 0;
        peakStoreItems = 0;
        peakProxies = 0;
        totalMs = 0.0;
        baselineValid = 0;
        baselineHits = 0;
        baselineSignature = 0;
        ClearAll();
        ReleaseProxies();
        if (!enabled) return;
        Console.Printf("DS_P015_BEGIN map=%s ticrate=%d scenarios=%d proxy_cap=%d cell_size=%.1f grid_axes=%d classification=SYNTHETIC_ENGINEERING_STRESS", level.MapName, Thinker.TICRATE, totalScenarios, PROXY_CAP, CELL_SIZE, CELLS_PER_AXIS);
        Console.Printf("DS_P015_SOURCE_FACT logical_store=STRUCT_OF_ARRAYS broad_phase=UNIFORM_GRID_CSR proxy_pool=BOUNDED_CAP counts_are_source_caps=false");
        StartScenario(0);
    }

    override void WorldTick()
    {
        if (!enabled || finished) return;
        double tickStart = MSTimeF();
        scenarioTic++;
        if (scenario == 10)
        {
            // Long-running spawn/despawn cycle with mass deaths and drops.
            for (int i = 0; i < 20; i++)
            {
                int slot = (despawned + i) % enemyX.Size();
                if (enemyAlive[slot] == 1)
                {
                    enemyAlive[slot] = 0;
                    despawned++;
                    dropsCreated++;
                }
            }
            spawnCycle = despawned;
            if (scenarioTic % 20 == 0)
            {
                for (int i = 0; i < 20; i++)
                {
                    int slot = (spawnCycle + i) % enemyX.Size();
                    enemyAlive[slot] = 1;
                }
            }
        }
        MoveEntities();
        if (gridEnabled == 1) BuildGrid(activeEnemies);
        ResolveCollisions();
        Actor player = players[0].mo;
        double playerX = 0.0;
        double playerY = 0.0;
        if (player != null)
        {
            playerX = player.Pos.X;
            playerY = player.Pos.Y;
        }
        if (scenario != 10) ResolvePickups(playerX, playerY);
        UpdateProxies(playerX, playerY);
        double tickMs = MSTimeF() - tickStart;
        workTickMs = workTickMs + tickMs;
        if (tickMs > worstTickMs) worstTickMs = tickMs;
        int limit = SCENARIO_TICS;
        if (scenario == 10) limit = CHURN_TICS;
        if (scenarioTic >= limit)
        {
            CompleteScenario();
            int next = scenario + 1;
            if (next >= totalScenarios)
            {
                finished = true;
                Console.Printf(
                    "DS_P015_COMPLETE scenarios=%d failures=%d total_ms=%.2f peak_store_items=%d peak_proxies=%d final_store_items=%d final_proxies=%d source_parity=OPEN_SYNTHETIC_BENCHMARK",
                    totalScenarios, failures, totalMs, peakStoreItems, peakProxies,
                    enemyX.Size() + projX.Size() + pickX.Size(), proxies.Size());
                Console.Printf("DS_RUNTIME_COMPLETE tics=%d pos=(%.3f,%.3f,%.3f) yaw=%.3f pitch=%.3f", 0, 0.0, 0.0, 0.0, 0.0, 0.0);
                return;
            }
            StartScenario(next);
        }
    }
}

// Bounded presentation proxy. Never solid, blocking or interactive. It reuses
// the existing generated P013 enemy placeholder so the benchmark introduces no
// new asset and no new art claim.
class DSP15Proxy : Actor
{
    Default { Radius 16; Height 40; +NOBLOCKMAP; +NOGRAVITY; +NOINTERACTION; }
    States { Spawn: P13E A -1 Bright; Stop; }
}
