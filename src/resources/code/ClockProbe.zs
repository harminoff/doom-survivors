// P014 timing probe. The schedules are synthetic engineering observations,
// deliberately separate from source-game timing claims. Logical time advances
// only on an accepted, unpaused WorldTick; UI and render observations are kept
// in their own counters.
class DSP014TimingProbe : EventHandler
{
    bool enabled;
    int engineWorldTicks;
    int simulationTic;
    int next100;
    int next250;
    int nextThird;
    ui int uiTicks;
    ui int renderedFrames;
    ui int inputObservations;
    ui bool uiWindowComplete;
    ui int uiTicksAtCompletion;
    ui double renderStartMs;
    ui bool renderStartSet;
    ui int renderFramesAtComplete;
    ui bool renderCompleteEmitted;
    ui int enginePausedObservations;
    ui bool nativeCycleStarted;
    ui bool nativeCycleOpened;
    ui int nativePauseEngineTick;
    ui int nativePauseSimTic;
    ui bool nativeCycleDone;
    ui int nativePauseUntilUiTick;
    ui int nativeFirstTickAfterResume;
    bool syntheticModal;
    bool completed;

    int Deadline100(int index) { return (index * 7 + 1) / 2; }
    int Deadline250(int index) { return (index * 35 + 3) / 4; }
    int DeadlineThird(int index) { return (index * 35 + 2) / 3; }

    void EmitDueEvents()
    {
        // Clock priority is fixed: 100 ms, 250 ms, then 1/3 second. The
        // while loops release every absolute deadline reached by this tic.
        while (next100 <= 94 && Deadline100(next100) <= simulationTic)
        {
            Console.Printf("DS_P014_EVENT clock=100ms priority=0 event_index=%d simulation_tic=%d engine_world_tick=%d", next100, simulationTic, engineWorldTicks);
            next100++;
        }
        while (next250 <= 37 && Deadline250(next250) <= simulationTic)
        {
            Console.Printf("DS_P014_EVENT clock=250ms priority=1 event_index=%d simulation_tic=%d engine_world_tick=%d", next250, simulationTic, engineWorldTicks);
            next250++;
        }
        while (nextThird <= 28 && DeadlineThird(nextThird) <= simulationTic)
        {
            Console.Printf("DS_P014_EVENT clock=third priority=2 event_index=%d simulation_tic=%d engine_world_tick=%d", nextThird, simulationTic, engineWorldTicks);
            nextThird++;
        }
    }

    override void WorldLoaded(WorldEvent e)
    {
        enabled = level.MapName == "MAP03";
        engineWorldTicks = 0;
        simulationTic = 0;
        next100 = 1;
        next250 = 1;
        nextThird = 1;
        syntheticModal = false;
        completed = false;
        if (!enabled) return;
        Console.Printf("DS_P014_BEGIN map=%s ticrate=%d clock_model=CEIL_ABSOLUTE_DEADLINE world_tick_pause=true ui_tick_always=true input_hook=InputProcess render_hook=RenderOverlay intervals=100ms,250ms,1/3s", level.MapName, Thinker.TICRATE);
        Console.Printf("DS_P014_SOURCE_FACT ticrate=35 worldtick=VALID_LEVEL_UNPAUSED uitick=ALWAYS input=InputProcess render=RenderOverlay");
    }

    override bool InputProcess(InputEvent e)
    {
        if (enabled)
        {
            inputObservations++;
            if (inputObservations == 1 || inputObservations % 35 == 0)
                Console.Printf("DS_P014_INPUT_OBSERVATION input_events=%d", inputObservations);
        }
        return false;
    }

    override void UiTick()
    {
        if (!enabled) return;
        uiTicks++;
        // The UI clock keeps running while the world is paused; recording the
        // native pause state here is what distinguishes a real engine pause
        // from the synthetic modal windows.
        if (uiTicks % 35 == 0)
            Console.Printf("DS_P014_PAUSE_STATE ui_ticks=%d world_paused=%d engine_world_tick=%d simulation_tic=%d", uiTicks, Level.WorldPaused(), engineWorldTicks, simulationTic);
        if (Level.WorldPaused())
        {
            enginePausedObservations++;
            if (enginePausedObservations == 1)
                Console.Printf("DS_P014_ENGINE_PAUSED ui_ticks=%d engine_world_tick=%d simulation_tic=%d", uiTicks, engineWorldTicks, simulationTic);
            if (enginePausedObservations % 35 == 0)
                Console.Printf("DS_P014_ENGINE_PAUSED_SAMPLE ui_ticks=%d samples=%d simulation_tic=%d", uiTicks, enginePausedObservations, simulationTic);
        }
        // Drive a genuine engine pause/resume cycle through the real menu, so
        // P014-A02 rests on native engine state rather than a synthetic flag.
        // GetCurrentMenu() is null whenever no menu is open, so every access is
        // guarded before Close() is called.
        // Open the real menu midway through the run, well before logical
        // completion, so the frozen simulation tic is a meaningful measurement.
        if (!nativeCycleStarted && uiTicks >= 150 && !Level.WorldPaused() && Menu.GetCurrentMenu() == null)
        {
            nativeCycleStarted = true;
            Menu.SetMenu('MainMenu');
            Console.Printf("DS_P014_NATIVE_PAUSE_BEGIN ui_ticks=%d engine_world_tick=%d simulation_tic=%d", uiTicks, engineWorldTicks, simulationTic);
        }
        else if (nativeCycleStarted && !nativeCycleOpened && Level.WorldPaused())
        {
            nativeCycleOpened = true;
            nativePauseEngineTick = engineWorldTicks;
            nativePauseSimTic = simulationTic;
            nativePauseUntilUiTick = uiTicks + 70;
            Console.Printf("DS_P014_NATIVE_PAUSE_HELD ui_ticks=%d engine_world_tick=%d simulation_tic=%d", uiTicks, engineWorldTicks, simulationTic);
        }
        else if (nativeCycleOpened && !nativeCycleDone && uiTicks >= nativePauseUntilUiTick)
        {
            Menu m = Menu.GetCurrentMenu();
            if (m != null)
            {
                nativeCycleDone = true;
                m.Close();
                Console.Printf("DS_P014_NATIVE_RESUME ui_ticks=%d engine_world_tick=%d simulation_tic=%d paused_engine_ticks=%d paused_sim_ticks=%d", uiTicks, engineWorldTicks, simulationTic, engineWorldTicks - nativePauseEngineTick, simulationTic - nativePauseSimTic);
            }
        }
        if (uiTicks == 350)
        {
            uiWindowComplete = true;
            uiTicksAtCompletion = uiTicks;
            Console.Printf("DS_P014_UI_WINDOW_COMPLETE ui_ticks=%d", uiTicks);
        }
        // Keep observing past the completion window so a UI clock that outlives
        // the WorldTick completion remains visible in the log.
        if (uiWindowComplete && uiTicks > uiTicksAtCompletion && (uiTicks - uiTicksAtCompletion) % 35 == 0)
            Console.Printf("DS_P014_UI_AFTER_COMPLETE ui_ticks=%d world_ticks=UI_CONTEXT_SEPARATE simulation_tic=UI_CONTEXT_SEPARATE", uiTicks);
        else if (!uiWindowComplete && uiTicks % 35 == 0)
            Console.Printf("DS_P014_UI_OBSERVATION ui_ticks=%d world_ticks=UI_CONTEXT_SEPARATE simulation_tic=UI_CONTEXT_SEPARATE", uiTicks);
    }

    override void RenderOverlay(RenderEvent e)
    {
        if (!enabled) return;
        // Real wall-clock observation. The configured cap is a request; this is
        // the only place an achieved render rate is measured.
        if (!renderStartSet)
        {
            renderStartMs = MSTimeF();
            renderStartSet = true;
        }
        renderedFrames++;
        // From the UI context we can see the play-context flag and emit the
        // measured window, which the play context is not allowed to read.
        if (completed && !renderCompleteEmitted)
        {
            renderCompleteEmitted = true;
            renderFramesAtComplete = renderedFrames;
            Console.Printf("DS_P014_RENDER_MEASURED frames=%d elapsed_ms=%.1f", renderFramesAtComplete, MSTimeF() - renderStartMs);
        }
        if (renderedFrames % 30 == 0)
            Console.Printf("DS_P014_RENDER_OBSERVATION render_frames=%d world_ticks=UI_CONTEXT_SEPARATE simulation_tic=UI_CONTEXT_SEPARATE", renderedFrames);
    }

    override void WorldTick()
    {
        if (!enabled || completed) return;
        engineWorldTicks++;
        if (engineWorldTicks == 72)
        {
            syntheticModal = true;
            Console.Printf("DS_P014_MODAL_BEGIN kind=level_up engine_world_tick=%d simulation_tic=%d", engineWorldTicks, simulationTic);
        }
        if (engineWorldTicks == 82 && syntheticModal)
        {
            syntheticModal = false;
            Console.Printf("DS_P014_MODAL_END kind=level_up engine_world_tick=%d simulation_tic=%d backlog=0", engineWorldTicks, simulationTic);
        }
        if (engineWorldTicks == 100)
        {
            syntheticModal = true;
            Console.Printf("DS_P014_MODAL_BEGIN kind=chest engine_world_tick=%d simulation_tic=%d", engineWorldTicks, simulationTic);
        }
        if (engineWorldTicks == 110 && syntheticModal)
        {
            syntheticModal = false;
            Console.Printf("DS_P014_MODAL_END kind=chest engine_world_tick=%d simulation_tic=%d backlog=0", engineWorldTicks, simulationTic);
        }
        if (syntheticModal) return;
        simulationTic++;
        EmitDueEvents();
        if (engineWorldTicks == 350)
        {
            completed = true;
            Console.Printf("DS_P014_COMPLETE engine_world_ticks=%d simulation_tics=%d events_100ms=%d events_250ms=%d events_third=%d modal_backlog=0 render_frames=UI_CONTEXT_SEPARATE input_observations=UI_CONTEXT_SEPARATE input_physics_limit=35HZ_BOUNDARY raw_input_observation=SEPARATE render_fps_observed=NOT_MEASURED", engineWorldTicks, simulationTic, next100 - 1, next250 - 1, nextThird - 1);
            Console.Printf("DS_RUNTIME_COMPLETE tics=%d pos=(%.3f,%.3f,%.3f) yaw=%.3f pitch=%.3f", engineWorldTicks, players[0].mo.Pos.X, players[0].mo.Pos.Y, players[0].mo.Pos.Z, players[0].mo.Angle, players[0].mo.Pitch);
        }
    }
}
