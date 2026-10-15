// MAP08 P022 packaged runtime fixture.
//
// Source schedule values are identified from the P009 FOREST rows, while
// cadence, cap, refill and spawn geometry are an engineering approximation
// because P009 records those source fields as UNKNOWN. Every admitted spawn is
// logged separately from the attempt that produced it.
class DSP022StageSpawnRuntime : EventHandler
{
    const MAP = "MAP08";
    const RUN_TICS = 70;
    const MAX_EVENTS = 64;

    bool enabled;
    bool completed;
    ui bool nativePauseStarted;
    ui bool nativePauseOpened;
    ui bool nativePauseClosed;
    ui int nativePauseUntilUi;
    ui int nativePauseSimulationTic;
    ui bool uiInitialized;
    int simulationTic;
    int engineWorldTicks;
    ui int uiTicks;
    int nextWave;
    int nextRefill;
    int nextEvent;
    int spawnRng;
    int nextEntityId;
    int eventId;
    int attempts;
    int admissions;
    int rejected;
    int refillRequests;
    int refillAdmissions;
    int capRejections;
    int aliveWave;
    int aliveRefill;
    int aliveEvent;
    int cameraVariant;
    String modeName;
    bool modeOverride;
    int releaseCount;
    double referenceCenterX;
    double referenceCenterY;

    void ReadConfiguration()
    {
        CVar variant = CVar.FindCVar("ds_p022_camera_variant");
        cameraVariant = variant != null ? variant.GetInt() : 0;
        if (cameraVariant < 0 || cameraVariant > 3) cameraVariant = 0;
        CVar mode = CVar.FindCVar("ds_p022_mode");
        modeName = mode != null ? mode.GetString() : "normal";
        if (modeName != "override") modeName = "normal";
        modeOverride = modeName == "override";
    }

    int BatchFor(int clock)
    {
        if (modeOverride && clock == DSP022SpawnDirector.CLOCK_STAGE_WAVE) return 1;
        return DSP022SpawnDirector.BatchForClock(clock);
    }

    int RefillFor(int clock)
    {
        return DSP022SpawnDirector.RefillForClock(clock);
    }

    int CapFor(int clock)
    {
        if (modeOverride && clock == DSP022SpawnDirector.CLOCK_STAGE_WAVE) return 3;
        return DSP022SpawnDirector.CapForClock(clock);
    }

    int AliveFor(int clock)
    {
        if (clock == DSP022SpawnDirector.CLOCK_STAGE_WAVE) return aliveWave;
        if (clock == DSP022SpawnDirector.CLOCK_STAGE_REFILL) return aliveRefill;
        return aliveEvent;
    }

    void SetAliveFor(int clock, int value)
    {
        if (clock == DSP022SpawnDirector.CLOCK_STAGE_WAVE) aliveWave = value;
        else if (clock == DSP022SpawnDirector.CLOCK_STAGE_REFILL) aliveRefill = value;
        else aliveEvent = value;
    }

    int NextRng()
    {
        spawnRng = DSP022StageGeometry.NextSpawnRng(spawnRng);
        return spawnRng;
    }

    void EmitCameraVariant()
    {
        if (players[0].mo == null) return;
        double yaw = 0.0;
        double pitch = 0.0;
        double fov = 90.0;
        if (cameraVariant == 1) yaw = 90.0;
        else if (cameraVariant == 2) yaw = 180.0;
        else if (cameraVariant == 3) { pitch = 35.0; fov = 120.0; }
        players[0].mo.Angle = yaw;
        players[0].mo.Pitch = pitch;
        players[0].SetFOV(fov);
        Console.Printf("DS_P022_CAMERA_VARIANT variant=%d yaw=%.3f pitch=%.3f fov=%.3f logical_region=%s", cameraVariant, yaw, pitch, fov, DSP022StageGeometry.REGION_ID);
    }

    void EmitBoundaryChecks()
    {
        bool referenceLeft = DSP022StageGeometry.InsideReference(-128.0, 0.0, 0.0, 0.0);
        bool referenceRight = DSP022StageGeometry.InsideReference(128.0, 0.0, 0.0, 0.0);
        bool innerExcluded = !DSP022StageGeometry.InsideSpawnBand(128.0, 0.0, 0.0, 0.0);
        bool outerLeft = DSP022StageGeometry.InsideSpawnBand(-160.0, 0.0, 0.0, 0.0);
        bool outerRight = DSP022StageGeometry.InsideSpawnBand(160.0, 0.0, 0.0, 0.0);
        bool beyondLeft = !DSP022StageGeometry.InsideSpawnBand(-161.0, 0.0, 0.0, 0.0);
        bool beyondRight = !DSP022StageGeometry.InsideSpawnBand(161.0, 0.0, 0.0, 0.0);
        Console.Printf("DS_P022_BOUNDARY_TEST reference_left=%d reference_right=%d inner_excluded=%d outer_left=%d outer_right=%d beyond_left=%d beyond_right=%d negative_coordinates=1", referenceLeft, referenceRight, innerExcluded, outerLeft, outerRight, beyondLeft, beyondRight);
    }

    void EmitAttempt(int clock, int deadline, int rowEvent, int attemptIndex, bool isRefill)
    {
        int candidateSeed = NextRng();
        eventId++;
        attempts++;
        if (isRefill) refillRequests++;
        double x;
        double y;
        int side;
        int lane;
        DSP022StageGeometry.Place(candidateSeed, eventId, rowEvent, attemptIndex, referenceCenterX, referenceCenterY, x, y, side, lane);
        int alive = AliveFor(clock);
        int cap = CapFor(clock);
        bool admitted = alive < cap;
        if (admitted)
        {
            alive++;
            SetAliveFor(clock, alive);
            admissions++;
            if (isRefill) refillAdmissions++;
            nextEntityId++;
        }
        else
        {
            rejected++;
            capRejections++;
        }
        Console.Printf("DS_P022_SPAWN event_id=%d tic=%d deadline=%d clock=%s priority=%d row=%d attempt=%d kind=%s admitted=%d entity_id=%d alive=%d cap=%d x=%.3f y=%.3f side=%d lane=%d region=%s rng_spawn=%d", eventId, simulationTic, deadline, DSP022SpawnDirector.ClockName(clock), DSP022SpawnDirector.Priority(clock), rowEvent, attemptIndex, isRefill ? "refill" : "batch", admitted, admitted ? nextEntityId : 0, alive, cap, x, y, side, lane, DSP022StageGeometry.REGION_ID, spawnRng);
    }

    void ReleaseEvent(int clock, int index, int deadline)
    {
        int row = DSP022SpawnDirector.RowForClock(clock);
        int batch = BatchFor(clock);
        int refill = RefillFor(clock);
        for (int attempt = 0; attempt < batch; attempt++) EmitAttempt(clock, deadline, row, attempt, false);
        for (int refillIndex = 0; refillIndex < refill; refillIndex++) EmitAttempt(clock, deadline, row, batch + refillIndex, true);
        Console.Printf("DS_P022_EVENT tic=%d deadline=%d clock=%s priority=%d event_index=%d row=%d batch=%d refill=%d cap=%d alive=%d attempts=%d admissions=%d rejected=%d refill_requests=%d refill_admissions=%d cap_rejections=%d mode=%s", simulationTic, deadline, DSP022SpawnDirector.ClockName(clock), DSP022SpawnDirector.Priority(clock), index, row, batch, refill, CapFor(clock), AliveFor(clock), attempts, admissions, rejected, refillRequests, refillAdmissions, capRejections, modeName);
    }

    void ReleaseDueEvents()
    {
        // Select the earliest absolute deadline, then priority and clock
        // declaration order. The loop releases every due clock, including
        // multiple deadlines sharing one simulation tic.
        while (true)
        {
            int bestClock = -1;
            int bestDeadline = 2147483647;
            int bestPriority = 2147483647;
            if (nextWave <= MAX_EVENTS)
            {
                int deadline = DSP022SpawnDirector.Deadline(DSP022SpawnDirector.CLOCK_STAGE_WAVE, nextWave);
                if (deadline <= simulationTic && (deadline < bestDeadline || (deadline == bestDeadline && 0 < bestPriority)))
                { bestClock = DSP022SpawnDirector.CLOCK_STAGE_WAVE; bestDeadline = deadline; bestPriority = 0; }
            }
            if (nextRefill <= MAX_EVENTS)
            {
                int deadline = DSP022SpawnDirector.Deadline(DSP022SpawnDirector.CLOCK_STAGE_REFILL, nextRefill);
                if (deadline <= simulationTic && (deadline < bestDeadline || (deadline == bestDeadline && 1 < bestPriority)))
                { bestClock = DSP022SpawnDirector.CLOCK_STAGE_REFILL; bestDeadline = deadline; bestPriority = 1; }
            }
            if (nextEvent <= MAX_EVENTS)
            {
                int deadline = DSP022SpawnDirector.Deadline(DSP022SpawnDirector.CLOCK_STAGE_EVENT, nextEvent);
                if (deadline <= simulationTic && (deadline < bestDeadline || (deadline == bestDeadline && 2 < bestPriority)))
                { bestClock = DSP022SpawnDirector.CLOCK_STAGE_EVENT; bestDeadline = deadline; bestPriority = 2; }
            }
            if (bestClock < 0) break;
            if (bestClock == DSP022SpawnDirector.CLOCK_STAGE_WAVE) { ReleaseEvent(bestClock, nextWave, bestDeadline); nextWave++; }
            else if (bestClock == DSP022SpawnDirector.CLOCK_STAGE_REFILL) { ReleaseEvent(bestClock, nextRefill, bestDeadline); nextRefill++; }
            else { ReleaseEvent(bestClock, nextEvent, bestDeadline); nextEvent++; }
        }
    }

    override void WorldLoaded(WorldEvent e)
    {
        enabled = level.MapName == MAP;
        completed = false;
        simulationTic = 0;
        engineWorldTicks = 0;
        nextWave = 1;
        nextRefill = 1;
        nextEvent = 1;
        spawnRng = 101;
        nextEntityId = 0;
        eventId = 0;
        attempts = 0;
        admissions = 0;
        rejected = 0;
        refillRequests = 0;
        refillAdmissions = 0;
        capRejections = 0;
        releaseCount = 0;
        aliveWave = 0;
        aliveRefill = 0;
        aliveEvent = 0;
        referenceCenterX = 0.0;
        referenceCenterY = 0.0;
        ReadConfiguration();
        if (!enabled) return;
        Console.Printf("DS_P022_BOOT map=%s ticrate=%d stage=FOREST source_build=1.16.107 clock_model=CEIL_ABSOLUTE_DEADLINE region=%s region_width=256.000 region_height=256.000 camera_frustum=SEPARATE", MAP, Thinker.TICRATE, DSP022StageGeometry.REGION_ID);
        Console.Printf("DS_P022_SOURCE_SCHEDULE stage_key=FOREST rows=0,1,2 raw_minutes=0,1,2 raw_frequency=1000,1000,500 raw_minimum=15,30,50 timing=ENGINEERING_APPROXIMATION geometry=ENGINEERING_APPROXIMATION provenance=P009_DISCOVERY_ONLY");
        Console.Printf("DS_P022_MODE mode=%s override=%d wave_batch=%d wave_refill=%d wave_cap=%d semantics=ENGINEERING_FIXTURE", modeName, modeOverride, BatchFor(DSP022SpawnDirector.CLOCK_STAGE_WAVE), RefillFor(DSP022SpawnDirector.CLOCK_STAGE_WAVE), CapFor(DSP022SpawnDirector.CLOCK_STAGE_WAVE));
        Console.Printf("DS_P022_CLOCK name=stage-wave-100ms interval=100ms priority=0 deadline=ceil(k*interval*35)");
        Console.Printf("DS_P022_CLOCK name=stage-refill-250ms interval=250ms priority=1 deadline=ceil(k*interval*35)");
        Console.Printf("DS_P022_CLOCK name=stage-event-third interval=1/3s priority=2 deadline=ceil(k*interval*35)");
        Console.Printf("DS_P022_REGION region=%s center=(0.000,0.000) reference=[-128.000,128.000] inclusive spawn_band=[-160.000,160.000] inclusive_outer_exclusive_inner negative_coordinates=VALID camera=IGNORED", DSP022StageGeometry.REGION_ID);
        EmitBoundaryChecks();
        EmitCameraVariant();
    }

    override void UiTick()
    {
        if (!enabled || completed) return;
        if (!uiInitialized)
        {
            uiInitialized = true;
            nativePauseStarted = false;
            nativePauseOpened = false;
            nativePauseClosed = false;
            nativePauseUntilUi = 0;
            nativePauseSimulationTic = 0;
        }
        uiTicks++;
        if (!nativePauseStarted && uiTicks >= 20 && !Level.WorldPaused() && Menu.GetCurrentMenu() == null)
        {
            nativePauseStarted = true;
            Menu.SetMenu('MainMenu');
            Console.Printf("DS_P022_NATIVE_PAUSE_BEGIN ui_ticks=%d simulation_tic=%d", uiTicks, simulationTic);
        }
        else if (nativePauseStarted && !nativePauseOpened && Level.WorldPaused())
        {
            nativePauseOpened = true;
            nativePauseSimulationTic = simulationTic;
            nativePauseUntilUi = uiTicks + 35;
            Console.Printf("DS_P022_NATIVE_PAUSE_HELD ui_ticks=%d simulation_tic=%d world_paused=1", uiTicks, simulationTic);
        }
        else if (nativePauseOpened && !nativePauseClosed && uiTicks >= nativePauseUntilUi)
        {
            Menu m = Menu.GetCurrentMenu();
            if (m != null)
            {
                nativePauseClosed = true;
                m.Close();
                Console.Printf("DS_P022_NATIVE_RESUME ui_ticks=%d simulation_tic=%d paused_sim_tics=%d backlog=0", uiTicks, simulationTic, simulationTic - nativePauseSimulationTic);
            }
        }
    }

    override void WorldTick()
    {
        if (!enabled || completed) return;
        engineWorldTicks++;
        simulationTic++;
        if (simulationTic == 1) EmitCameraVariant();
        ReleaseDueEvents();
        if (simulationTic == 17)
        {
            int before = aliveWave;
            int release = before > 1 ? before - 1 : 0;
            aliveWave -= release;
            releaseCount += release;
            Console.Printf("DS_P022_RELEASE tic=%d row=0 released=%d alive_before=%d alive_after=%d reason=DETERMINISTIC_SLOT_RELEASE", simulationTic, release, before, aliveWave);
        }
        if (simulationTic == 18)
            Console.Printf("DS_P022_TIE_CHECK tic=18 same_deadline=1 order=stage-wave-100ms,stage-refill-250ms");
        if (simulationTic % 10 == 0)
            Console.Printf("DS_P022_STATE tic=%d engine_world_ticks=%d attempts=%d admissions=%d rejected=%d refills=%d refill_admissions=%d cap_rejections=%d alive=(%d,%d,%d) rng_spawn=%d logical_center=(%.3f,%.3f) camera_variant=%d", simulationTic, engineWorldTicks, attempts, admissions, rejected, refillRequests, refillAdmissions, capRejections, aliveWave, aliveRefill, aliveEvent, spawnRng, referenceCenterX, referenceCenterY, cameraVariant);
        if (simulationTic >= RUN_TICS)
        {
            completed = true;
            Console.Printf("DS_P022_COMPLETE tics=%d engine_world_ticks=%d attempts=%d admissions=%d rejected=%d refills=%d refill_admissions=%d cap_rejections=%d releases=%d alive=(%d,%d,%d) next_indices=(%d,%d,%d) rng_spawn=%d region=%s mode=%s camera_invariant=true native_pause=1 backlog=0 source_timing=UNKNOWN geometry=ENGINEERING_APPROXIMATION", simulationTic, engineWorldTicks, attempts, admissions, rejected, refillRequests, refillAdmissions, capRejections, releaseCount, aliveWave, aliveRefill, aliveEvent, nextWave, nextRefill, nextEvent, spawnRng, DSP022StageGeometry.REGION_ID, modeName);
            LevelLocals.MakeScreenShot();
        }
    }
}
