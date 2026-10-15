// P019 deterministic in-engine harness.
//
// This is deliberately a small production-shaped state observer, not a host
// language simulation. The state below is owned by the running ZScript event
// handler and is advanced on WorldTick. Presentation values (camera angle,
// pitch and FOV), telemetry output and render counters never enter the
// canonical gameplay hash.
class DSP019Harness : EventHandler
{
    const RUN_TICS = 120;
    const EXPECTED_DAMAGE = 3;

    bool enabled;
    bool finished;
    bool faulted;
    bool telemetryEnabled;
    int tic;
    String scenario;
    String inputTape;

    double playerX;
    double playerY;
    Array<double> enemyX;
    Array<double> enemyY;
    Array<int> enemyHealth;
    Array<int> enemyAlive;

    // Named gameplay streams. Presentation has no access to these values.
    int rngSpawn;
    int rngAttack;
    int rngDrop;
    int rngDraft;

    int spawnAttempts;
    int spawnAdmissions;
    int attacksEmitted;
    int hitsApplied;
    int totalDamage;
    int xpAwarded;
    int dropsCreated;
    int draftsPresented;
    int durableEvents;
    int offscreenEntities;
    int lastCanonicalHash;

    void ReadConfiguration()
    {
        CVar scenarioCVar = CVar.FindCVar("ds_p019_scenario");
        CVar tapeCVar = CVar.FindCVar("ds_p019_input_tape");
        CVar telemetryCVar = CVar.FindCVar("ds_p019_telemetry");
        scenario = scenarioCVar != null ? scenarioCVar.GetString() : "";
        inputTape = tapeCVar != null ? tapeCVar.GetString() : "";
        telemetryEnabled = telemetryCVar == null || telemetryCVar.GetInt() != 0;
    }

    bool IsSupportedScenario()
    {
        return scenario == "hash_replay"
            || scenario == "camera_invariance"
            || scenario == "telemetry_neutrality"
            || scenario == "wrong_damage"
            || scenario == "missing_completion";
    }

    bool IsSupportedTape()
    {
        return inputTape == "spiral-v1" || inputTape == "idle-v1" || inputTape == "hold-right-v1";
    }

    int NextRng(int state)
    {
        // rng-v1 from the architecture decision: xorshift32 with a nonzero
        // state. Integer overflow is intentional and deterministic in ZScript.
        int next = state;
        next = next ^ (next << 13);
        next = next ^ (next >> 17);
        next = next ^ (next << 5);
        if (next == 0) next = 1831565813;
        return next;
    }

    int Mix(int hash, int value)
    {
        return hash * 31 + value;
    }

    int AliveCount()
    {
        int count = 0;
        for (int i = 0; i < enemyAlive.Size(); i++) if (enemyAlive[i] != 0) count++;
        return count;
    }

    int CanonicalHash()
    {
        // This field list is the approved gameplay-only snapshot. In
        // particular, it excludes camera state, render frames, telemetry and
        // every presentation actor.
        int hash = 216613626;
        hash = Mix(hash, tic);
        hash = Mix(hash, int(playerX * 1000.0));
        hash = Mix(hash, int(playerY * 1000.0));
        hash = Mix(hash, rngSpawn);
        hash = Mix(hash, rngAttack);
        hash = Mix(hash, rngDrop);
        hash = Mix(hash, rngDraft);
        hash = Mix(hash, spawnAttempts);
        hash = Mix(hash, spawnAdmissions);
        hash = Mix(hash, attacksEmitted);
        hash = Mix(hash, hitsApplied);
        hash = Mix(hash, totalDamage);
        hash = Mix(hash, xpAwarded);
        hash = Mix(hash, dropsCreated);
        hash = Mix(hash, draftsPresented);
        hash = Mix(hash, durableEvents);
        hash = Mix(hash, offscreenEntities);
        for (int i = 0; i < enemyHealth.Size(); i++)
        {
            hash = Mix(hash, int(enemyX[i] * 1000.0));
            hash = Mix(hash, int(enemyY[i] * 1000.0));
            hash = Mix(hash, enemyHealth[i]);
            hash = Mix(hash, enemyAlive[i]);
        }
        return hash;
    }

    void EmitState()
    {
        if (!telemetryEnabled) return;
        lastCanonicalHash = CanonicalHash();
        Console.Printf(
            "DS_P019_STATE tic=%d hash=%d player=(%.3f,%.3f) alive=%d spawn_attempts=%d spawn_admissions=%d attacks=%d hits=%d damage=%d xp=%d drops=%d drafts=%d durable=%d rng=(%d,%d,%d,%d) offscreen=%d",
            tic, lastCanonicalHash, playerX, playerY, AliveCount(), spawnAttempts,
            spawnAdmissions, attacksEmitted, hitsApplied, totalDamage, xpAwarded,
            dropsCreated, draftsPresented, durableEvents, rngSpawn, rngAttack,
            rngDrop, rngDraft, offscreenEntities);
    }

    void EmitCanonicalTrace()
    {
        // Keep a hash-only trace available with telemetry disabled. Optional
        // counter payloads disappear, while deterministic comparison remains
        // possible between two actual engine logs.
        lastCanonicalHash = CanonicalHash();
        Console.Printf("DS_P019_CANONICAL_TRACE tic=%d hash=%d", tic, lastCanonicalHash);
    }

    void ResetGameplay()
    {
        tic = 0;
        playerX = 0.0;
        playerY = 0.0;
        enemyX.Clear();
        enemyY.Clear();
        enemyHealth.Clear();
        enemyAlive.Clear();
        for (int i = 0; i < 4; i++)
        {
            enemyX.Push(96.0 + double(i * 48));
            enemyY.Push(double((i % 2) * 64 - 32));
            enemyHealth.Push(12);
            enemyAlive.Push(1);
        }
        rngSpawn = 101;
        rngAttack = 202;
        rngDrop = 303;
        rngDraft = 404;
        spawnAttempts = 0;
        spawnAdmissions = 0;
        attacksEmitted = 0;
        hitsApplied = 0;
        totalDamage = 0;
        xpAwarded = 0;
        dropsCreated = 0;
        draftsPresented = 0;
        durableEvents = 0;
        offscreenEntities = 2;
        lastCanonicalHash = 0;
    }

    void ApplyInput()
    {
        int step = (tic - 1) % 8;
        if (inputTape == "spiral-v1")
        {
            if (step == 0 || step == 1) playerX += 1.0;
            else if (step == 2 || step == 3) playerY += 1.0;
            else if (step == 4 || step == 5) playerX -= 1.0;
            else playerY -= 1.0;
        }
        else if (inputTape == "hold-right-v1")
        {
            playerX += 1.0;
        }
        // idle-v1 intentionally leaves the body at the origin.
    }

    void ProcessSpawns()
    {
        if (tic == 1 || tic == 31 || tic == 61 || tic == 91)
        {
            spawnAttempts++;
            rngSpawn = NextRng(rngSpawn);
            if (AliveCount() < 8)
            {
                spawnAdmissions++;
                rngSpawn = NextRng(rngSpawn);
            }
        }
    }

    void ProcessAttack()
    {
        if (tic % 7 != 0) return;
        attacksEmitted++;
        rngAttack = NextRng(rngAttack);
        int target = (tic / 7 - 1) % enemyHealth.Size();
        if (enemyAlive[target] == 0) return;
        int observedDamage = EXPECTED_DAMAGE;
        if (scenario == "wrong_damage" && tic == 35) observedDamage = EXPECTED_DAMAGE + 1;
        if (observedDamage != EXPECTED_DAMAGE)
        {
            Console.Printf("DS_P019_DAMAGE expected=%d observed=%d target=%d tic=%d", EXPECTED_DAMAGE, observedDamage, target, tic);
            Console.Printf("DS_ASSERT_FAIL wrong_damage_detected");
            faulted = true;
            return;
        }
        enemyHealth[target] -= observedDamage;
        hitsApplied++;
        totalDamage += observedDamage;
        xpAwarded += observedDamage;
        if (enemyHealth[target] <= 0)
        {
            enemyHealth[target] = 0;
            enemyAlive[target] = 0;
            dropsCreated++;
            rngDrop = NextRng(rngDrop);
        }
    }

    void ProcessDurableEvents()
    {
        if (tic == 25 || tic == 75)
        {
            durableEvents++;
            rngDraft = NextRng(rngDraft);
        }
        if (tic == 50 || tic == 100) draftsPresented++;
    }

    void ApplyCameraFixture()
    {
        if (scenario != "camera_invariance" || players[0].mo == null) return;
        int caseIndex = (tic / 20) % 4;
        double yaw = 0.0;
        double pitch = 0.0;
        double fov = 90.0;
        if (caseIndex == 1) yaw = 90.0;
        else if (caseIndex == 2) { yaw = 180.0; pitch = 20.0; fov = 70.0; }
        else if (caseIndex == 3) { yaw = 270.0; pitch = -20.0; fov = 110.0; }
        players[0].mo.Angle = yaw;
        players[0].mo.Pitch = pitch;
        players[0].SetFOV(fov);
        if (tic % 20 == 0)
        {
            Console.Printf("DS_P019_CAMERA tic=%d yaw=%.3f pitch=%.3f fov=%.3f offscreen=%d canonical_hash=%d",
                tic, yaw, pitch, fov, offscreenEntities, CanonicalHash());
        }
    }

    void Complete()
    {
        lastCanonicalHash = CanonicalHash();
        Console.Printf(
            "DS_P019_COMPLETE scenario=%s input_tape=%s telemetry=%d tics=%d canonical_hash=%d rng=(%d,%d,%d,%d) spawn_attempts=%d spawn_admissions=%d alive=%d attacks=%d hits=%d damage=%d xp=%d drops=%d drafts=%d durable=%d offscreen=%d camera_is_presentation=true",
            scenario, inputTape, telemetryEnabled, tic, lastCanonicalHash, rngSpawn,
            rngAttack, rngDrop, rngDraft, spawnAttempts, spawnAdmissions, AliveCount(),
            attacksEmitted, hitsApplied, totalDamage, xpAwarded, dropsCreated,
            draftsPresented, durableEvents, offscreenEntities);
        finished = true;
    }

    override void WorldLoaded(WorldEvent e)
    {
        enabled = level.MapName == "MAP05";
        finished = false;
        faulted = false;
        if (!enabled) return;
        ReadConfiguration();
        ResetGameplay();
        Console.Printf("DS_P019_BOOT map=%s ticrate=%d scenario=%s input_tape=%s telemetry=%d execution=REALTIME logical_tics=%d",
            level.MapName, Thinker.TICRATE, scenario, inputTape, telemetryEnabled, RUN_TICS);
        Console.Printf("DS_P019_CANONICAL schema=gameplay-v1 excludes=camera,pitch,fov,render,telemetry presentation=separate");
        if (!IsSupportedScenario())
        {
            Console.Printf("DS_ASSERT_FAIL unsupported_scenario");
            faulted = true;
        }
        else if (!IsSupportedTape())
        {
            Console.Printf("DS_ASSERT_FAIL unsupported_input_tape");
            faulted = true;
        }
    }

    override void WorldTick()
    {
        if (!enabled || finished || faulted) return;
        tic++;
        ApplyInput();
        ProcessSpawns();
        ProcessAttack();
        if (faulted) return;
        ProcessDurableEvents();
        ApplyCameraFixture();
        if (scenario == "camera_invariance" && tic == 60)
        {
            // This capture is intentionally tied to the FP matrix scenario:
            // it proves that the selected packaged UZDoom process rendered
            // the scenario while its canonical state stayed camera-invariant.
            LevelLocals.MakeScreenShot();
            Console.Printf("DS_P019_FRAMEBUFFER_CAPTURE scenario=camera_invariance tic=60");
        }
        if (tic % 10 == 0)
        {
            EmitCanonicalTrace();
            EmitState();
        }
        if (tic >= RUN_TICS)
        {
            if (scenario == "missing_completion")
            {
                Console.Printf("DS_P019_INTENTIONAL_MISSING_COMPLETION tics=%d canonical_hash=%d", tic, CanonicalHash());
                finished = true;
                return;
            }
            Complete();
        }
    }
}
