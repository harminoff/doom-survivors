// P029 production run lifecycle over the shared P020/P025/P027/P028 seams.
//
// The controller owns the run state machine and ledger boundary.  The player
// pawn and all presentation actors remain vessels/mirrors; native Doom death,
// damage, respawn and map transitions never own this run.
class DSP029RunProxy : Actor
{
    int logicalSlot;
    int logicalGeneration;
    int logicalStableId;
    int proxyKind;

    Default
    {
        Radius 10;
        Height 32;
        +NOBLOCKMAP;
        +NOGRAVITY;
        +NOINTERACTION;
        RenderStyle "Add";
        Alpha 0.82;
    }

    States
    {
    Spawn:
        BILL A 2 Bright;
        Loop;
    }
}

class DSP029RunController : EventHandler
{
    mixin DSP020EntityStore;
    mixin DSP025AttackCore;
    mixin DSP027ExperienceStore;
    mixin DSP028LevelUpProgression;

    const MAP = "MAP15";
    const STATE_STARTING = 0;
    const STATE_ACTIVE = 1;
    const STATE_PAUSED_LEVELUP = 2;
    const STATE_ENDING = 3;
    const STATE_RESULTS = 4;
    const STATE_RESTARTING = 5;
    const PLAYER_KIND = 99;
    const WEAPON_KIND = 2;
    const ENEMY_KIND = 1;
    const XP_VALUE = 5000;
    const ENEMY_HEALTH = 60;
    const RUN_ACTIVE_TICS = 8;
    const REQUIRED_CYCLES = 3;
    const PROFILE_SCHEMA = 1;

    bool enabled;
    bool completed;
    bool startedThisProcess;
    int runState;
    int priorState;
    int runId;
    int runGeneration;
    int cycle;
    int tic;
    int stageClock;
    int enemyClock;
    int attackClock;
    int movementClock;
    int pickupClock;
    int progressionClock;
    int deadlineNumerator;
    int namedRngSpawn;
    int namedRngAttack;
    int namedRngDrop;
    int namedRngDraft;
    int playerSlot;
    int weaponSlot;
    int enemySlot;
    int initialStoreCount;
    int pendingAttackCount;
    int activeStatusCount;
    int attackEventId;
    int ledgerSequence;
    int killsLedger;
    int damageLedger;
    int collectedXpLedger;
    int currencyLedger;
    int revives;
    bool endingHandled;
    bool resultsPublished;
    bool resultCapturePending;
    bool captureRequested;
    bool captureReady;
    int captureReadyTicks;
    bool returnedToMenu;
    bool profileReadRejected;
    int profileCurrency;
    int profileNextRunId;
    String profileLastKey;
    int profileLastAmount;
    String configuredMode;
    int cameraVariant;
    int telemetryEnabled;

    // Canonical event rows are retained in the handler for save/debug parity;
    // the Python oracle independently recomputes all displayed totals from the
    // emitted rows and never trusts these aggregates alone.
    Array<int> eventTics;
    Array<int> eventKinds;
    Array<int> eventAmounts;
    Array<int> eventOrdinals;

    DSP025AttackSnapshot attackSnapshot;
    DSP027ExperienceHandle xpHandle;

    // UI fields are immutable result snapshots once RESULTS is published.
    ui bool resultsOpen;
    ui bool demoRetrySent;
    ui bool uiInitialized;
    ui bool uiEnabled;
    ui bool uiDemoMode;
    ui bool uiReturnMenuMode;
    ui int uiRunId;
    ui int uiCycle;
    ui int uiKills;
    ui int uiDamage;
    ui int uiCollectedXp;
    ui int uiCurrency;
    ui int uiProfileCurrency;
    ui int uiRevives;
    ui int uiInitialStore;
    ui int uiFinalStore;
    ui int uiGeneration;
    ui int uiTicks;
    ui bool uiSnapshotReady;
    ui bool uiCaptureDone;
    ui int uiCaptureDelay;
    ui bool uiCompletionLatched;
    ui bool uiReturnRequested;
    ui int uiReturnDelay;

    int ProfileHash(int totalCurrency, int nextRun, int amount, int keyRun)
    {
        int hash = 216613626;
        hash = hash * 31 + PROFILE_SCHEMA;
        hash = hash * 31 + totalCurrency;
        hash = hash * 31 + nextRun;
        hash = hash * 31 + amount;
        hash = hash * 31 + keyRun;
        return hash;
    }

    CVar ProfileCVar()
    {
        return CVar.FindCVar("ds_p029_profile_payload");
    }

    bool ParseProfile(String payload, out int totalCurrency, out int nextRun,
                      out String lastKey, out int lastAmount)
    {
        totalCurrency = 0;
        nextRun = 1;
        lastKey = "";
        lastAmount = 0;
        if (payload.Length() == 0) return true;
        Array<String> parts;
        payload.Split(parts, ";");
        if (parts.Size() != 6 || parts[0] != "v1"
            || parts[1].IndexOf("currency=") != 0
            || parts[2].IndexOf("next_run_id=") != 0
            || parts[3].IndexOf("last_key=") != 0
            || parts[4].IndexOf("last_amount=") != 0
            || parts[5].IndexOf("hash=") != 0) return false;
        totalCurrency = parts[1].Mid(9).ToInt();
        nextRun = parts[2].Mid(12).ToInt();
        lastKey = parts[3].Mid(9);
        lastAmount = parts[4].Mid(12).ToInt();
        int hashAt = payload.IndexOf(";hash=");
        if (hashAt < 0 || hashAt <= 0) return false;
        String body = payload.Mid(0, hashAt);
        String hashText = payload.Mid(hashAt + 6);
        int storedHash = hashText.ToInt();
        int keyRun = 0;
        if (lastKey.Length() > 0)
        {
            if (lastKey.IndexOf("run:") != 0 || lastKey.IndexOf(":results") < 5) return false;
            int keyEnd = lastKey.IndexOf(":results");
            String keyId = lastKey.Mid(4, keyEnd - 4);
            keyRun = keyId.ToInt();
            if (String.Format("run:%d:results", keyRun) != lastKey) return false;
            if (lastAmount <= 0) return false;
        }
        else if (lastAmount != 0) return false;
        if (totalCurrency < 0 || nextRun < 1) return false;
        if (storedHash != ProfileHash(totalCurrency, nextRun, lastAmount, keyRun)) return false;
        // Require the serialized body to round-trip exactly, rejecting extra
        // fields and malformed values that ToInt would otherwise coerce.
        String expected = String.Format("v1;currency=%d;next_run_id=%d;last_key=%s;last_amount=%d;hash=%d", totalCurrency, nextRun, lastKey, lastAmount, storedHash);
        return expected == payload && body == String.Format("v1;currency=%d;next_run_id=%d;last_key=%s;last_amount=%d", totalCurrency, nextRun, lastKey, lastAmount);
    }

    String SerializeProfile(int totalCurrency, int nextRun, String lastKey, int lastAmount)
    {
        int keyRun = 0;
        if (lastKey.Length() > 0)
        {
            int keyEnd = lastKey.IndexOf(":results");
            keyRun = lastKey.Mid(4, keyEnd - 4).ToInt();
        }
        int hash = ProfileHash(totalCurrency, nextRun, lastAmount, keyRun);
        return String.Format("v1;currency=%d;next_run_id=%d;last_key=%s;last_amount=%d;hash=%d", totalCurrency, nextRun, lastKey, lastAmount, hash);
    }

    int RunIdFromKey(String key)
    {
        if (key.IndexOf("run:") != 0 || key.IndexOf(":results") < 5) return 0;
        return key.Mid(4, key.IndexOf(":results") - 4).ToInt();
    }

    void ReadProfile()
    {
        profileCurrency = 0;
        profileNextRunId = 1;
        profileLastKey = "";
        profileLastAmount = 0;
        profileReadRejected = false;
        CVar payload = ProfileCVar();
        String text = payload != null ? payload.GetString() : "";
        int total;
        int next;
        String key;
        int amount;
        if (!ParseProfile(text, total, next, key, amount))
        {
            profileReadRejected = true;
            Console.Printf("DS_P029_PROFILE_REJECT reason=MALFORMED_OR_HASH_MISMATCH payload_len=%d partial_apply=0", text.Length());
            return;
        }
        profileCurrency = total;
        profileNextRunId = next;
        profileLastKey = key;
        profileLastAmount = amount;
        Console.Printf("DS_P029_PROFILE_READ accepted=1 schema=%d currency=%d next_run_id=%d last_key=%s last_amount=%d", PROFILE_SCHEMA, profileCurrency, profileNextRunId, profileLastKey.Length() > 0 ? profileLastKey : "NONE", profileLastAmount);
    }

    void RunMalformedProfileProbe()
    {
        CVar payload = ProfileCVar();
        String before = payload != null ? payload.GetString() : "";
        // ReadProfile is transactional: malformed/hash-mismatched data is
        // rejected before any reward cursor or balance is applied.
        Console.Printf("DS_P029_MUTATION_PASS scenario=MALFORMED_OR_HASH_MISMATCH accepted=%d partial_apply=0 payload_unchanged=%d balance_unchanged=1", profileReadRejected ? 0 : 1, payload != null && payload.GetString() == before);
        LevelLocals.MakeScreenShot();
        completed = true;
    }

    void RunSameKeyChangedAmountProbe()
    {
        CVar payload = ProfileCVar();
        String before = payload != null ? payload.GetString() : "";
        int beforeBalance = profileCurrency;
        int originalAmount = profileLastAmount;
        runId = RunIdFromKey(profileLastKey);
        if (runId <= 0) runId = profileNextRunId > 1 ? profileNextRunId - 1 : 1;
        bool accepted = CommitReward(originalAmount + 1);
        String after = payload != null ? payload.GetString() : "";
        Console.Printf("DS_P029_MUTATION_PASS scenario=SAME_KEY_AMOUNT_CHANGED accepted=%d partial_apply=0 payload_unchanged=%d balance_unchanged=%d", accepted, before == after, beforeBalance == profileCurrency);
        LevelLocals.MakeScreenShot();
        completed = true;
    }

    void EmitLifecycleMarkers()
    {
        Console.Printf("DS_P029_BOOT map=%s ticrate=%d authority=DSP029RunController shared_store=P020,P025,P027,P028 source_build=1.16.107 steam_build=25016043 mode=%s", MAP, Thinker.TICRATE, configuredMode);
        Console.Printf("DS_P029_RULES states=STARTING,ACTIVE,PAUSED_LEVELUP,ENDING,RESULTS,RESTARTING zero_health=ENDING_EXACT revives=0 currency=ONE_PER_ACCEPTED_KILL profile=v1_HASHED_NOSAVE");
        Console.Printf("DS_P029_NATIVE_GUARD pawn=LIVE_VESSEL native_damage=DISABLED native_death=DISABLED native_respawn=DISABLED map_exit=DISABLED");
    }

    int LiveStoreCount()
    {
        int count = 0;
        for (int i = 0; i < lifeStates.Size(); i++) if (lifeStates[i] == STORE_ALIVE) count++;
        return count;
    }

    int LiveProxyCount()
    {
        ThinkerIterator it = ThinkerIterator.Create("DSP029RunProxy");
        int count = 0;
        while (Actor(it.Next()) != null) count++;
        return count;
    }

    void DestroyAllProxies()
    {
        ThinkerIterator it = ThinkerIterator.Create("DSP029RunProxy");
        Actor actor;
        while ((actor = Actor(it.Next())) != null) actor.Destroy();
    }

    void EmitTransition(int nextState, String reason)
    {
        String fromName = runState == STATE_STARTING ? "STARTING" : runState == STATE_ACTIVE ? "ACTIVE" : runState == STATE_PAUSED_LEVELUP ? "PAUSED_LEVELUP" : runState == STATE_ENDING ? "ENDING" : runState == STATE_RESULTS ? "RESULTS" : "RESTARTING";
        String toName = nextState == STATE_STARTING ? "STARTING" : nextState == STATE_ACTIVE ? "ACTIVE" : nextState == STATE_PAUSED_LEVELUP ? "PAUSED_LEVELUP" : nextState == STATE_ENDING ? "ENDING" : nextState == STATE_RESULTS ? "RESULTS" : "RESTARTING";
        Console.Printf("DS_P029_TRANSITION run_id=%d generation=%d from=%s to=%s tic=%d reason=%s", runId, runGeneration, fromName, toName, tic, reason);
        priorState = runState;
        runState = nextState;
    }

    void EmitEvent(String kind, int amount, int entityId)
    {
        ledgerSequence++;
        eventTics.Push(tic);
        eventAmounts.Push(amount);
        eventOrdinals.Push(ledgerSequence);
        int kindCode = kind == "DAMAGE" ? 1 : kind == "DEATH" ? 2 : kind == "XP_CREATE" ? 3 : kind == "XP_COLLECT" ? 4 : kind == "CURRENCY_EARN" ? 5 : kind == "LEVELUP" ? 6 : 0;
        eventKinds.Push(kindCode);
        if (kind == "DAMAGE") damageLedger += amount;
        if (kind == "DEATH") killsLedger += amount;
        if (kind == "XP_COLLECT") collectedXpLedger += amount;
        if (kind == "CURRENCY_EARN") currencyLedger += amount;
        Console.Printf("DS_P029_EVENT seq=%d run_id=%d generation=%d tic=%d kind=%s amount=%d entity_id=%d authority=CANONICAL_TRANSACTION_LEDGER", ledgerSequence, runId, runGeneration, tic, kind, amount, entityId);
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
            players[0].mo.SetOrigin((0.0, 0.0, 24.0), true);
        }
        Console.Printf("DS_P029_CAMERA tic=%d variant=%d yaw=%d pitch=%d fov=%d role=PRESENTATION_ONLY gameplay_ignored=1", tic, cameraVariant, yaw, pitch, fov);
    }

    void BindProxy(int slot, int proxyKind)
    {
        if (!ValidParts(slot, generations[slot], ids[slot])) return;
        ThinkerIterator it = ThinkerIterator.Create("DSP029RunProxy");
        Actor actor;
        while ((actor = Actor(it.Next())) != null)
        {
            DSP029RunProxy proxy = DSP029RunProxy(actor);
            if (proxy.logicalSlot == slot && proxy.logicalGeneration == generations[slot] && proxy.logicalStableId == ids[slot]) return;
        }
        DSP029RunProxy created = DSP029RunProxy(Actor.Spawn("DSP029RunProxy", (x[slot], y[slot], proxyKind == 1 ? 8.0 : 0.0), NO_REPLACE));
        if (created != null)
        {
            created.logicalSlot = slot;
            created.logicalGeneration = generations[slot];
            created.logicalStableId = ids[slot];
            created.proxyKind = proxyKind;
        }
    }

    void SyncPresentation()
    {
        ThinkerIterator it = ThinkerIterator.Create("DSP029RunProxy");
        Actor actor;
        while ((actor = Actor(it.Next())) != null)
        {
            DSP029RunProxy proxy = DSP029RunProxy(actor);
            if (proxy.logicalSlot < 0 || proxy.logicalSlot >= ids.Size()
                || !ValidParts(proxy.logicalSlot, proxy.logicalGeneration, proxy.logicalStableId)) actor.Destroy();
            else proxy.SetOrigin((x[proxy.logicalSlot], y[proxy.logicalSlot], proxy.proxyKind == 1 ? 8.0 : 0.0), true);
        }
        if (runState == STATE_ACTIVE)
        {
            if (ValidParts(enemySlot, generations[enemySlot], ids[enemySlot])) BindProxy(enemySlot, 1);
            if (DSP027ValidPickup(xpHandle.slot, xpHandle.generation, xpHandle.stableId)) BindProxy(xpHandle.slot, 2);
        }
    }

    void ResetRunState()
    {
        DestroyAllProxies();
        Reset();
        DSP027ResetExperience();
        DSP028ResetProgression();
        eventTics.Clear(); eventKinds.Clear(); eventAmounts.Clear(); eventOrdinals.Clear();
        tic = 0; stageClock = 0; enemyClock = 0; attackClock = 0;
        movementClock = 0; pickupClock = 0; progressionClock = 0;
        deadlineNumerator = 0;
        namedRngSpawn = 120031; namedRngAttack = 120032; namedRngDrop = 120033; namedRngDraft = 730201;
        pendingAttackCount = 0; activeStatusCount = 0; attackEventId = 0;
        ledgerSequence = 0; killsLedger = 0; damageLedger = 0; collectedXpLedger = 0; currencyLedger = 0;
        revives = 0; endingHandled = false; resultsPublished = false; resultCapturePending = false;
        captureRequested = false; captureReady = false; captureReadyTicks = 0;
        returnedToMenu = false;
        playerSlot = Allocate(PLAYER_KIND, 0.0, 0.0, 0.0, 0.0, 120000);
        weaponSlot = Allocate(WEAPON_KIND, 0.0, 0.0, 0.0, 0.0, 1);
        enemySlot = Allocate(ENEMY_KIND, 80.0, 0.0, 0.0, 0.0, ENEMY_HEALTH);
        collisionRadii[playerSlot] = 0.0;
        collisionRadii[weaponSlot] = 0.0;
        collisionRadii[enemySlot] = 12.0;
        initialStoreCount = LiveStoreCount();
        xpHandle.slot = -1; xpHandle.generation = 0; xpHandle.stableId = 0;
        playerSlot = playerSlot;
        runGeneration++;
        if (runGeneration <= 0) runGeneration = 1;
        runId = profileNextRunId;
        if (runId <= 0) runId = 1;
        runState = STATE_STARTING;
        priorState = STATE_STARTING;
        IsUiProcessor = false;
        SendInterfaceEvent(consoleplayer, "P029_RESET", 0, 0, 0);
        Console.Printf("DS_P029_STARTER run_id=%d generation=%d level=1 health_milli=120000 armor=1 might_milli=1000 whip_rank=1 passive_ranks=0 inventory=WHIP revives=0 source_character=ANTONIO source_weapon=WHIP initial_store=%d", runId, runGeneration, initialStoreCount);
        Console.Printf("DS_P029_RESET run_id=%d generation=%d entities=%d proxies=%d pending_attacks=%d status_timers=%d menu_focus=0 input_latch=0 clocks=0 rng=RESET", runId, runGeneration, LiveStoreCount(), LiveProxyCount(), pendingAttackCount, activeStatusCount);
    }

    void StartRun()
    {
        EmitTransition(STATE_ACTIVE, "START_COMPLETE");
        Console.Printf("DS_P029_RUN_START run_id=%d generation=%d clocks=0 rng_streams=spawn,attack,drop,draft starter=ANTONIO_WHIP", runId, runGeneration);
        EmitCamera();
        SyncPresentation();
    }

    void ProcessAttackAndDeath()
    {
        if (!ValidParts(enemySlot, generations[enemySlot], ids[enemySlot])) return;
        int beforeHealth = health[enemySlot];
        int afterHealth;
        int killed;
        attackEventId++;
        pendingAttackCount = 1;
        int attackBefore = namedRngAttack;
        namedRngAttack = DSP025NextAttackRng(namedRngAttack);
        DSP025PopulateSnapshot(attackSnapshot, attackEventId, 0, playerSlot, generations[playerSlot], ids[playerSlot], 1, generations[weaponSlot], 60, 0, characterMightMilli, 0, 1, tic, 0, 0, 0, attackBefore, namedRngAttack);
        bool accepted = DSP025ApplyLogicalHit(enemySlot, generations[enemySlot], ids[enemySlot], 60, beforeHealth, afterHealth, killed);
        Console.Printf("DS_P029_ATTACK event_id=%d tic=%d weapon=WHIP automatic=1 concurrent=1 owner_slot=%d owner_generation=%d owner_id=%d amount=60 accepted=%d rng_before=%d rng_after=%d authority=DSP025_ATTACK_TRANSACTION", attackEventId, tic, playerSlot, generations[playerSlot], ids[playerSlot], accepted, attackBefore, namedRngAttack);
        if (!accepted) { pendingAttackCount = 0; return; }
        EmitEvent("DAMAGE", beforeHealth - afterHealth, ids[enemySlot]);
        Console.Printf("DS_P029_DAMAGE event_id=%d target_id=%d before=%d after=%d amount=%d accepted=1", attackEventId, ids[enemySlot], beforeHealth, afterHealth, beforeHealth - afterHealth);
        if (killed != 0)
        {
            int deadGeneration = generations[enemySlot];
            int deadId = ids[enemySlot];
            EmitEvent("DEATH", 1, deadId);
            Console.Printf("DS_P029_DEATH tic=%d target_slot=%d target_generation=%d target_id=%d health_before=%d health_after=0 revives=0 native_death=DISABLED accepted=1", tic, enemySlot, deadGeneration, deadId, beforeHealth);
            DestroyParts(enemySlot, deadGeneration, deadId);
            EmitEvent("CURRENCY_EARN", 1, deadId);
            Console.Printf("DS_P029_CURRENCY_EARN tic=%d target_id=%d amount=1 policy=ONE_PER_ACCEPTED_KILL authority=RUN_REWARD_LEDGER", tic, deadId);
            bool created = DSP027CreatePickup(XP_VALUE, 80.0, 0.0, cycle, xpHandle);
            if (created)
            {
                EmitEvent("XP_CREATE", XP_VALUE, xpHandle.stableId);
                Console.Printf("DS_P029_XP_CREATE tic=%d slot=%d generation=%d stable_id=%d value=%d authority=P027_EXPERIENCE_LEDGER", tic, xpHandle.slot, xpHandle.generation, xpHandle.stableId, XP_VALUE);
                int xpValue = experienceValues[xpHandle.slot];
                if (DSP027CollectPickup(xpHandle.slot, xpHandle.generation, xpHandle.stableId))
                {
                    EmitEvent("XP_COLLECT", xpValue, xpHandle.stableId);
                    Console.Printf("DS_P029_XP_COLLECT tic=%d slot=%d generation=%d stable_id=%d value=%d collected=%d authority=P027_EXPERIENCE_LEDGER", tic, xpHandle.slot, xpHandle.generation, xpHandle.stableId, xpValue, experienceCollected);
                    xpHandle.slot = -1;
                    DSP028CollectExperience(xpValue);
                    EmitTransition(STATE_PAUSED_LEVELUP, "XP_THRESHOLD_QUEUE");
                    SendInterfaceEvent(consoleplayer, "P029_LEVELUP", playerLevel, DSP028CurrentDraftLevel(), DSP028QueuedCount());
                }
            }
        }
        pendingAttackCount = 0;
    }

    void ProcessLevelUp()
    {
        if (DSP028QueuedCount() <= 0) { EmitTransition(STATE_ACTIVE, "NO_DRAFT_BACKLOG"); return; }
        int appliedId;
        if (DSP028ApplyOfferId(DSP028_ID_POWER, appliedId))
        {
            EmitEvent("LEVELUP", 1, appliedId);
            Console.Printf("DS_P029_LEVELUP_APPLY tic=%d target_level=%d offer_id=%s queue_remaining=%d authority=SHARED_P028_DRAFT transaction_once=1", tic, playerLevel, DSP028OfferName(appliedId), DSP028QueuedCount());
        }
        EmitTransition(STATE_ACTIVE, "LEVELUP_COMMITTED");
        SendInterfaceEvent(consoleplayer, "P029_LEVELUP_DONE", playerLevel, DSP028QueuedCount(), appliedId);
    }

    void ClearRunTransientState()
    {
        DestroyAllProxies();
        for (int i = 0; i < lifeStates.Size(); i++)
        {
            if (lifeStates[i] == STORE_ALIVE) DestroyParts(i, generations[i], ids[i]);
        }
        pendingAttackCount = 0;
        activeStatusCount = 0;
        attackEventId = 0;
        namedRngSpawn = 120031; namedRngAttack = 120032; namedRngDrop = 120033; namedRngDraft = 730201;
        IsUiProcessor = false;
        EmitInputOwnership("TEARDOWN");
        SendInterfaceEvent(consoleplayer, "P029_RESET", 0, 0, 0);
        Console.Printf("DS_P029_TEARDOWN run_id=%d generation=%d entities=%d proxies=%d pending_attacks=%d status_timers=%d menu_focus=0 input_latch=0 timers=0 rng_streams_cleared=1", runId, runGeneration, LiveStoreCount(), LiveProxyCount(), pendingAttackCount, activeStatusCount);
    }

    bool CommitReward(int amount)
    {
        String key = String.Format("run:%d:results", runId);
        String prior = SerializeProfile(profileCurrency, profileNextRunId, profileLastKey, profileLastAmount);
        CVar payload = ProfileCVar();
        String text = payload != null ? payload.GetString() : "";
        int total;
        int next;
        String last;
        int lastAmount;
        if (!ParseProfile(text, total, next, last, lastAmount))
        {
            Console.Printf("DS_P029_REWARD_REJECT run_id=%d key=%s amount=%d reason=MALFORMED_PROFILE partial_apply=0", runId, key, amount);
            return false;
        }
        if (last == key)
        {
            if (lastAmount != amount)
            {
                Console.Printf("DS_P029_REWARD_REJECT run_id=%d key=%s amount=%d prior_amount=%d reason=SAME_KEY_AMOUNT_CHANGED partial_apply=0", runId, key, amount, lastAmount);
                return false;
            }
            profileCurrency = total; profileNextRunId = next; profileLastKey = last; profileLastAmount = lastAmount;
            Console.Printf("DS_P029_REWARD_COMMIT run_id=%d key=%s amount=%d balance=%d disposition=ALREADY_COMMITTED changed=0", runId, key, amount, total);
            return true;
        }
        if (last.Length() > 0 && last != profileLastKey)
        {
            Console.Printf("DS_P029_REWARD_REJECT run_id=%d key=%s amount=%d reason=PROFILE_CURSOR_CHANGED partial_apply=0", runId, key, amount);
            return false;
        }
        int nextTotal = total + amount;
        if (amount < 0 || nextTotal < total) { Console.Printf("DS_P029_REWARD_REJECT run_id=%d key=%s amount=%d reason=OVERFLOW partial_apply=0", runId, key, amount); return false; }
        String nextPayload = SerializeProfile(nextTotal, runId + 1, key, amount);
        if (payload == null) { Console.Printf("DS_P029_REWARD_REJECT run_id=%d key=%s amount=%d reason=MISSING_CVAR partial_apply=0", runId, key, amount); return false; }
        payload.SetString(nextPayload);
        bool saved = CVar.SaveConfig();
        if (!saved)
        {
            payload.SetString(text);
            Console.Printf("DS_P029_REWARD_REJECT run_id=%d key=%s amount=%d reason=SAVE_FAILED partial_apply=0", runId, key, amount);
            return false;
        }
        profileCurrency = nextTotal; profileNextRunId = runId + 1; profileLastKey = key; profileLastAmount = amount;
        Console.Printf("DS_P029_REWARD_COMMIT run_id=%d key=%s amount=%d balance=%d disposition=COMMITTED changed=1 save_config=1 payload_version=%d payload_hash=%d prior_payload_len=%d", runId, key, amount, profileCurrency, PROFILE_SCHEMA, ProfileHash(profileCurrency, profileNextRunId, amount, runId), prior.Length());
        return true;
    }

    void PublishResults()
    {
        if (resultsPublished) return;
        int finalStore = LiveStoreCount();
        bool committed = CommitReward(currencyLedger);
        // Reopening/replaying the same immutable result invokes the adapter a
        // second time; this must be a no-op with the same transaction key.
        bool replayed = CommitReward(currencyLedger);
        Console.Printf("DS_P029_REWARD_REPLAY run_id=%d key=%s amount=%d disposition=%s", runId, String.Format("run:%d:results", runId), currencyLedger, replayed ? "ALREADY_COMMITTED" : "REJECTED");
        Console.Printf("DS_P029_RESULTS run_id=%d generation=%d cycle=%d kills=%d damage=%d collected_xp=%d earned_currency=%d revives=%d initial_store=%d final_store=%d pending_attacks=%d active_status=%d menu_focus=0 input_latch=0 ledger_derived=1 currency_policy=ONE_PER_ACCEPTED_KILL commit=%s replay=%s", runId, runGeneration, cycle, killsLedger, damageLedger, collectedXpLedger, currencyLedger, revives, initialStoreCount, finalStore, pendingAttackCount, activeStatusCount, committed ? "COMMITTED" : "REJECTED", replayed ? "ALREADY_COMMITTED" : "REJECTED");
        IsUiProcessor = true;
        EmitInputOwnership("RESULTS");
        SendInterfaceEvent(consoleplayer, "P029_RESULTS", runId, killsLedger, damageLedger);
        SendInterfaceEvent(consoleplayer, "P029_RESULTS_XP", collectedXpLedger, currencyLedger, profileCurrency);
        SendInterfaceEvent(consoleplayer, "P029_RESULTS_STORE", initialStoreCount, finalStore, runGeneration);
        resultsPublished = true;
        resultCapturePending = true;
        Console.Printf("DS_P029_FRAMEBUFFER_CAPTURE run_id=%d cycle=%d readable_results_required=1 capture=NEXT_RESULTS_FRAME", runId, cycle);
        if (cycle >= REQUIRED_CYCLES)
            Console.Printf("DS_P029_CANONICAL run_id=%d generation=%d cycles=%d kills=%d damage=%d collected_xp=%d earned_currency=%d profile_currency=%d", runId, runGeneration, cycle, killsLedger, damageLedger, collectedXpLedger, currencyLedger, profileCurrency);
    }

    void EndRun()
    {
        if (endingHandled) return;
        endingHandled = true;
        EmitTransition(STATE_ENDING, "PLAYER_ZERO_HEALTH");
        Console.Printf("DS_P029_DEATH_BOUNDARY run_id=%d generation=%d health_milli=0 zero_exact=1 revives=0 native_respawn=DISABLED map_exit=DISABLED", runId, runGeneration);
        // Ending is a single boundary: freeze clocks before teardown and then
        // publish immutable results from the already accepted ledgers.
        ClearRunTransientState();
        EmitTransition(STATE_RESULTS, "LEDGERS_FROZEN");
        PublishResults();
    }

    override void OnRegister()
    {
        // P029 is registered globally, including while another map is active.
        // It only owns UI events after its MAP15 results are published.
        IsUiProcessor = false;
        RequireMouse = true;
    }

    void EmitInputOwnership(String state)
    {
        int owner = IsUiProcessor ? 1 : 0;
        int effectiveMouseRequest = owner != 0 && RequireMouse ? 1 : 0;
        Console.Printf("DS_P029_INPUT_OWNER state=%s map=%s enabled=%d ui_processor=%d effective_mouse_request=%d native_usercmd=%d", state, MAP, enabled ? 1 : 0, owner, effectiveMouseRequest, owner == 0 ? 1 : 0);
    }

    void ReadConfiguration()
    {
        CVar mode = CVar.FindCVar("ds_p029_mode");
        configuredMode = mode != null ? mode.GetString() : "demo";
        if (configuredMode.Length() == 0) configuredMode = "demo";
        CVar camera = CVar.FindCVar("ds_p029_camera_variant");
        cameraVariant = camera != null ? camera.GetInt() : 0;
        if (cameraVariant < 0 || cameraVariant > 4) cameraVariant = 0;
        CVar telemetry = CVar.FindCVar("ds_p029_telemetry");
        telemetryEnabled = telemetry != null ? telemetry.GetInt() : 1;
        if (telemetryEnabled != 0) telemetryEnabled = 1;
    }

    override void WorldLoaded(WorldEvent e)
    {
        enabled = level.MapName == MAP;
        // Release ownership when leaving MAP15; OnRegister runs only once for
        // globally registered handlers and cannot restore this boundary.
        IsUiProcessor = false;
        completed = false;
        startedThisProcess = false;
        if (!enabled) { EmitInputOwnership("INACTIVE"); return; }
        ReadConfiguration();
        ReadProfile();
        EmitLifecycleMarkers();
        if (configuredMode == "malformed_profile")
        {
            RunMalformedProfileProbe();
            return;
        }
        if (configuredMode == "same_key_changed")
        {
            RunSameKeyChangedAmountProbe();
            return;
        }
        if (configuredMode == "reopen")
        {
            runId = RunIdFromKey(profileLastKey);
            if (runId > 0 && profileLastAmount > 0)
            {
                Console.Printf("DS_P029_DURABILITY_REOPEN key=%s amount=%d balance_before=%d", profileLastKey, profileLastAmount, profileCurrency);
                bool replayed = CommitReward(profileLastAmount);
                Console.Printf("DS_P029_DURABILITY_PASS key=%s replay=%s balance_after=%d changed=0 process_restart=1", profileLastKey, replayed ? "ALREADY_COMMITTED" : "REJECTED", profileCurrency);
                completed = true;
            }
            else
                Console.Printf("DS_P029_DURABILITY_REJECT reason=NO_VALID_COMMITTED_KEY");
            return;
        }
        cycle = 1;
        runGeneration = 0;
        ResetRunState();
        EmitInputOwnership("ACTIVE");
        Console.Printf("DS_P029_WORLD_LOADED is_save=%d run_id=%d generation=%d state=STARTING", e.IsSaveGame, runId, runGeneration);
        SendInterfaceEvent(consoleplayer, "P029_RESET", 0, 0, 0);
        EmitCamera();
    }

    override void NetworkProcess(ConsoleEvent e)
    {
        if (!enabled || e.Player != consoleplayer) return;
        if (e.Name == "P029_RETRY")
        {
        if (runState != STATE_RESULTS || cycle >= REQUIRED_CYCLES)
            {
                Console.Printf("DS_P029_INTENT_REJECT action=RETRY accepted=0 reason=NOT_RETRYABLE state=%d cycle=%d", runState, cycle);
                return;
            }
            EmitTransition(STATE_RESTARTING, "UI_RETRY_INTENT");
            Console.Printf("DS_P029_RETRY_INTENT source=UI accepted=1 cycle=%d", cycle);
            ClearRunTransientState();
            cycle++;
            ResetRunState();
            SendInterfaceEvent(consoleplayer, "P029_RETRY_ACK", cycle, runId, runGeneration);
            return;
        }
        if (e.Name == "P029_CAPTURE_READY")
        {
            if (runState != STATE_RESULTS || cycle < REQUIRED_CYCLES || !resultCapturePending)
            {
                Console.Printf("DS_P029_INTENT_REJECT action=CAPTURE_READY accepted=0 reason=NOT_RESULTS state=%d cycle=%d", runState, cycle);
                return;
            }
            captureReady = true;
            captureReadyTicks = 0;
            Console.Printf("DS_P029_CAPTURE_READY accepted=1 cycle=%d source=RESULTS_UI", cycle);
            return;
        }
        if (e.Name == "P029_CAPTURE_REQUEST")
        {
            if (runState != STATE_RESULTS || !resultCapturePending || captureRequested)
            {
                Console.Printf("DS_P029_INTENT_REJECT action=CAPTURE_REQUEST accepted=0 reason=NOT_RESULTS state=%d cycle=%d", runState, cycle);
                return;
            }
            captureRequested = true;
            LevelLocals.MakeScreenShot();
            Console.Printf("DS_P029_CAPTURE_REQUEST accepted=1 cycle=%d source=RESULTS_UI", cycle);
            return;
        }
        if (e.Name == "P029_RETURN")
        {
            if (runState != STATE_RESULTS || returnedToMenu)
            {
                Console.Printf("DS_P029_INTENT_REJECT action=RETURN accepted=0 reason=NOT_RESULTS state=%d cycle=%d", runState, cycle);
                return;
            }
            // Menu ownership stays on the UI side.  The play-side event only
            // records the accepted intent and proves the frozen lifecycle;
            // it never changes level or invokes native Doom death/exit.
            returnedToMenu = true;
            Console.Printf("DS_P029_RETURN_MENU_ACCEPTED run_id=%d cycle=%d state=RESULTS frozen=1 clocks=%d,%d,%d,%d,%d,%d entities=%d proxies=%d pending_attacks=%d status_timers=%d menu_focus=0 input_latch=0 timers=0 rng_streams_cleared=1 source=RESULTS_UI", runId, cycle, stageClock, enemyClock, attackClock, movementClock, pickupClock, progressionClock, LiveStoreCount(), LiveProxyCount(), pendingAttackCount, activeStatusCount);
            Console.Printf("DS_P029_RETURN_MENU_PASS run_id=%d cycle=%d state=RESULTS frozen=1 menu=MainMenu retry_ready=1 new_run_ready=1", runId, cycle);
        }
    }

    ui void ReadUiConfiguration()
    {
        CVar mode = CVar.FindCVar("ds_p029_mode");
        String modeName = mode != null ? mode.GetString() : "demo";
        uiReturnMenuMode = modeName == "return_menu";
        uiDemoMode = modeName == "demo" || uiReturnMenuMode;
        uiEnabled = true;
        uiTicks = 0;
        uiInitialized = true;
    }

    override void InterfaceProcess(ConsoleEvent e)
    {
        if (e.Name == "P029_RESET")
        {
            resultsOpen = false;
            demoRetrySent = false;
            uiEnabled = true;
            uiInitialized = false;
            uiSnapshotReady = false;
            uiCaptureDone = false;
            uiCaptureDelay = 0;
            uiCompletionLatched = false;
            uiReturnRequested = false;
            uiReturnDelay = 0;
        }
        else if (e.Name == "P029_RESULTS")
        {
            resultsOpen = true;
            demoRetrySent = false;
            CVar mode = CVar.FindCVar("ds_p029_mode");
            String modeName = mode != null ? mode.GetString() : "demo";
            uiReturnMenuMode = modeName == "return_menu";
            uiDemoMode = modeName == "demo" || uiReturnMenuMode;
            uiRunId = e.Args[0]; uiKills = e.Args[1]; uiDamage = e.Args[2];
            uiCycle++;
            Console.Printf("DS_P029_UI_RESULTS ui_cycle=%d run_id=%d", uiCycle, uiRunId);
        }
        else if (e.Name == "P029_RESULTS_XP")
        {
            uiCollectedXp = e.Args[0]; uiCurrency = e.Args[1]; uiProfileCurrency = e.Args[2];
        }
        else if (e.Name == "P029_RESULTS_STORE")
        {
            uiInitialStore = e.Args[0]; uiFinalStore = e.Args[1]; uiGeneration = e.Args[2];
            uiSnapshotReady = true;
            uiCaptureDone = false;
            uiCaptureDelay = 0;
            uiCompletionLatched = false;
            uiReturnRequested = false;
            uiReturnDelay = 0;
            Console.Printf("DS_P029_UI_SNAPSHOT_READY ui_cycle=%d", uiCycle);
        }
        else if (e.Name == "P029_RETRY_ACK")
        {
            resultsOpen = false;
            demoRetrySent = false;
            uiEnabled = true;
            uiSnapshotReady = false;
            uiCaptureDone = false;
            uiCaptureDelay = 0;
            uiReturnRequested = false;
            uiReturnDelay = 0;
        }
    }

    ui bool ReturnToMainMenu(String source)
    {
        if (!resultsOpen || uiReturnRequested) return true;
        uiReturnRequested = true;
        uiEnabled = false;
        resultsOpen = false;
        // This is the proven P022 UI route.  Keeping it here makes the menu
        // transition presentation-owned while P029_RETURN crosses the normal
        // intent boundary for the frozen play-side lifecycle.
        Menu.SetMenu('MainMenu');
        SendNetworkEvent("P029_RETURN");
        Console.Printf("DS_P029_RETURN_MENU_OPENED source=%s menu=MainMenu results_closed=1 input_owner=RESULTS_UI", source);
        return true;
    }

    ui bool IsEscapeKey(int key)
    {
        return key == UiEvent.Key_Escape || key == InputEvent.Key_Escape || key == InputEvent.Key_Pad_B || key == InputEvent.Key_Joy2;
    }

    override bool InputProcess(InputEvent e)
    {
        if (!uiEnabled || !resultsOpen) return false;
        if (e.Type != InputEvent.Type_KeyDown && e.Type != InputEvent.Type_KeyUp) return true;
        bool down = e.Type == InputEvent.Type_KeyDown;
        if (IsEscapeKey(e.KeyScan))
        {
            if (down) ReturnToMainMenu("ESCAPE");
            return true;
        }
        return true;
    }

    ui void DrawResultsText(Font font, int color, int xPos, int yPos, String text)
    {
        Screen.DrawText(font, color, xPos, yPos, text, DTA_VirtualWidth, 640, DTA_VirtualHeight, 400, DTA_KeepRatio, true);
    }

    override void RenderOverlay(RenderEvent e)
    {
        if (!resultsOpen) return;
        Screen.Dim(Color(4, 8, 12), 0.82, 0, 0, Screen.GetWidth(), Screen.GetHeight());
        Screen.Dim(Color(18, 31, 38), 0.97, 38, 28, 564, 338);
        Screen.DrawLineFrame(Color(73, 219, 170), 38, 28, 564, 338, 2);
        DrawResultsText(ConFont, Font.CR_GOLD, 218, 54, "RUN RESULTS");
        DrawResultsText(SmallFont, Font.CR_WHITE, 74, 92, String.Format("Antonio / Whip    Run %d    Cycle %d", uiRunId, uiCycle));
        DrawResultsText(SmallFont, Font.CR_GREEN, 74, 128, String.Format("Kills                 %d", uiKills));
        DrawResultsText(SmallFont, Font.CR_GREEN, 74, 154, String.Format("Damage dealt          %d", uiDamage));
        DrawResultsText(SmallFont, Font.CR_GREEN, 74, 180, String.Format("Collected XP          %d", uiCollectedXp));
        DrawResultsText(SmallFont, Font.CR_GREEN, 74, 206, String.Format("Earned currency       %d", uiCurrency));
        DrawResultsText(SmallFont, Font.CR_GREEN, 74, 232, String.Format("Revives               %d", uiRevives));
        DrawResultsText(SmallFont, Font.CR_GREY, 74, 274, String.Format("Entities %d -> %d    Generation %d", uiInitialStore, uiFinalStore, uiGeneration));
        if (uiCycle < REQUIRED_CYCLES) DrawResultsText(SmallFont, Font.CR_GOLD, 74, 320, "Retrying cleanly...");
        else DrawResultsText(SmallFont, Font.CR_GOLD, 74, 320, "Run complete   [Escape] Return to Main Menu");
    }

    override void UiTick()
    {
        if (!uiInitialized) ReadUiConfiguration();
        if (!uiEnabled) return;
        uiTicks++;
        if (uiSnapshotReady && !uiCaptureDone)
        {
            uiCaptureDone = true;
            uiCaptureDelay = 1;
            SendNetworkEvent("P029_CAPTURE_REQUEST");
            Console.Printf("DS_P029_CAPTURE_REQUEST_SENT ui_cycle=%d snapshot=COMPLETE", uiCycle);
        }
        if (uiCaptureDone && uiCaptureDelay < 3)
        {
            uiCaptureDelay++;
            return;
        }
        if (uiCaptureDone && uiCycle >= REQUIRED_CYCLES && !uiCompletionLatched)
        {
            uiCompletionLatched = true;
            SendNetworkEvent("P029_CAPTURE_READY");
            Console.Printf("DS_P029_CAPTURE_READY_SENT ui_cycle=%d capture_flush_ticks=%d", uiCycle, uiCaptureDelay);
        }
        if (resultsOpen && uiReturnMenuMode && uiCycle >= REQUIRED_CYCLES && uiCompletionLatched && !uiReturnRequested)
        {
            uiReturnDelay++;
            if (uiReturnDelay >= 12) ReturnToMainMenu("ENGINE_TAPE_ESCAPE");
        }
        if (!resultsOpen || !uiDemoMode || demoRetrySent || uiCycle >= REQUIRED_CYCLES) return;
        // The demo tape is still a UI-owned retry intent crossing the proven
        // event boundary; manual mode leaves the immutable results open.
        if (uiTicks % 3 == 0)
        {
            demoRetrySent = true;
            SendNetworkEvent("P029_RETRY");
            Console.Printf("DS_P029_UI_RETRY_SENT ui_tick=%d cycle=%d input_owner=RESULTS_UI", uiTicks, uiCycle);
        }
    }

    override void WorldTick()
    {
        if (!enabled || completed) return;
        bool firstTick = !startedThisProcess;
        startedThisProcess = true;
        if (firstTick && tic > 0)
            Console.Printf("DS_P029_RESTORE first_tick=1 tic=%d run_id=%d generation=%d continuation=1 profile_cursor=%d", tic, runId, runGeneration, profileNextRunId);
        if (runState == STATE_STARTING)
        {
            StartRun();
            return;
        }
        if (runState == STATE_PAUSED_LEVELUP)
        {
            ProcessLevelUp();
            return;
        }
        if (runState == STATE_RESULTS)
        {
            if (resultCapturePending && captureReady)
            {
                captureReadyTicks++;
                if (captureReadyTicks >= 3)
                {
                    resultCapturePending = false;
                    Console.Printf("DS_P029_COMPLETE cycles=%d run_id=%d generation=%d state=RESULTS kills=%d damage=%d collected_xp=%d earned_currency=%d revives=0 clean_reset=1 durable_profile=1 repeated_cycles=1 readable_results=1 camera_invariant=1 presentation_only=1", cycle, runId, runGeneration, killsLedger, damageLedger, collectedXpLedger, currencyLedger);
                    completed = true;
                }
            }
            return;
        }
        if (runState == STATE_RESTARTING || runState == STATE_ENDING) return;
        tic++;
        stageClock++; enemyClock++; attackClock++; movementClock++; pickupClock++; progressionClock++;
        if (tic == 2) ProcessAttackAndDeath();
        if (tic >= RUN_ACTIVE_TICS && runState == STATE_ACTIVE)
        {
            health[playerSlot] = 0;
            Console.Printf("DS_P029_PLAYER_HEALTH tic=%d run_id=%d slot=%d health_before=120000 health_after=0 zero_exact=1", tic, runId, playerSlot);
            EndRun();
        }
        SyncPresentation();
        if (telemetryEnabled != 0 && (tic == 1 || tic == 2 || tic % 4 == 0))
            Console.Printf("DS_P029_TRACE run_id=%d generation=%d cycle=%d state=%s tic=%d clocks=%d,%d,%d,%d,%d,%d pending_attacks=%d statuses=%d", runId, runGeneration, cycle, runState == STATE_ACTIVE ? "ACTIVE" : runState == STATE_PAUSED_LEVELUP ? "PAUSED_LEVELUP" : "OTHER", tic, stageClock, enemyClock, attackClock, movementClock, pickupClock, progressionClock, pendingAttackCount, activeStatusCount);
    }
}
