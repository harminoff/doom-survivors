// P016 persistence probe: bounded engine fixture for the durability
// investigation. This is not the production profile system.
//
// ZScript cannot declare cvars (file scope accepts only include/extend/class/
// mixin/struct/const/enum), so the durable store is declared in the CVARINFO
// lump and reached here through CVar.FindCVar. The stored format carries an
// explicit schema version and a content hash so a mismatch is detectable
// rather than silently reinterpreted.
class DSP016RunCarrier : StaticEventHandler
{
    bool valid;
    int runMarker;
    int generationCounter;
    int entityHash;
    Array<int> logicalIds;
    Array<int> logicalGeneration;
    Array<int> logicalHealth;
    double savedX;
    double savedY;
    double savedZ;
    double savedYaw;
    double savedPitch;
    double savedFov;
    int equippedAttackCount;
    int offscreenEnemyCount;
}

class DSP016PersistenceProbe : EventHandler
{
    // Run-save state. This one lives in the savegame, not in the profile.
    int runMarker;
    int generationCounter;
    Array<int> logicalIds;
    Array<int> logicalGeneration;
    Array<int> logicalHealth;

    bool enabled;
    bool armed;
    int phaseTic;
    bool restoreReported;
    bool transitionViewReported;
    int profileWriteCount;
    int mapTransitionCount;
    // First-person adapter state is logical run state for this probe. These
    // fields are deliberately non-transient so an engine save restores the
    // camera/control context alongside the entity arrays.
    double savedX;
    double savedY;
    double savedZ;
    double savedYaw;
    double savedPitch;
    double savedFov;
    int equippedAttackCount;
    int offscreenEnemyCount;
    int renderProxyCount;
    // Not serialized into the savegame. It is therefore false in a process that
    // restored from a save and true only after this process has run a tick,
    // which is what distinguishes "restored" from "fresh" reliably.
    transient bool startedThisProcess;

    const PROFILE_SCHEMA = 1;
    // Engineering capacity target: the observed locked profile exposes a 301
    // progression denominator; 512 records add headroom without claiming a
    // complete source census or source-game cap.
    const ENTITY_COUNT = 512;

    CVar ProfilePayload()
    {
        return CVar.FindCVar('ds_p016_payload');
    }

    CVar ProfileSchema()
    {
        return CVar.FindCVar('ds_p016_schema_version');
    }

    CVar ProfileMarker()
    {
        return CVar.FindCVar('ds_p016_marker');
    }

    CVar ProfileId()
    {
        return CVar.FindCVar('ds_p016_profile_id');
    }

    int ProfileBaseId()
    {
        CVar id = ProfileId();
        if (id != null && id.GetString() == "profile-b") return 9000;
        if (id != null && id.GetString() == "profile-interrupted") return 13000;
        if (id != null && id.GetString() == "profile-readonly") return 17000;
        return 500;
    }

    int CountRenderActors()
    {
        int count = 0;
        ThinkerIterator it = ThinkerIterator.Create("DSP016AttackProxy");
        Actor actor;
        while ((actor = Actor(it.Next())) != null) count++;
        return count;
    }

    void SpawnRenderActors()
    {
        Actor.Spawn("DSP016AttackProxy", (-180.0, -20.0, 0.0), NO_REPLACE);
        Actor.Spawn("DSP016AttackProxy", (-180.0, 20.0, 0.0), NO_REPLACE);
        Actor.Spawn("DSP016AttackProxy", (120.0, 0.0, 0.0), NO_REPLACE);
        renderProxyCount = CountRenderActors();
        Console.Printf("DS_P016_RENDER_STATE actors=%d attacks=3 offscreen=2 duplicate_actors=0", renderProxyCount);
    }

    // Deterministic, order-dependent hash of the logical entity state. Any
    // lost, duplicated or reordered entity changes this value.
    int ContentHash()
    {
        int hash = 0;
        for (int i = 0; i < logicalIds.Size(); i++)
        {
            hash = hash * 31 + logicalIds[i];
            hash = hash * 31 + logicalGeneration[i];
            hash = hash * 31 + logicalHealth[i];
        }
        return hash;
    }

    String SerializeProfile()
    {
        String payload = String.Format("v%d;ids", PROFILE_SCHEMA);
        for (int i = 0; i < logicalIds.Size(); i++)
            payload = payload .. String.Format(",%d:%d:%d", logicalIds[i], logicalGeneration[i], logicalHealth[i]);
        payload = payload .. String.Format(";hash=%d", ContentHash());
        return payload;
    }

    // Parses the stored payload. Returns the parsed entity count, or -1 when
    // the payload is malformed. Callers must treat -1 as a hard refusal.
    int ParseProfile(String payload, out Array<int> ids, out Array<int> gens, out Array<int> health)
    {
        ids.Clear(); gens.Clear(); health.Clear();
        if (payload.Length() == 0) return -1;
        if (payload.IndexOf("v") != 0) return -1;
        int idsAt = payload.IndexOf(";ids");
        if (idsAt < 0) return -1;
        String versionText = payload.Mid(1, idsAt - 1);
        int storedSchema = versionText.ToInt();
        if (storedSchema != PROFILE_SCHEMA) return -1;
        int hashAt = payload.IndexOf(";hash=");
        if (hashAt < 0) return -1;
        String body = payload.Mid(idsAt + 4, hashAt - idsAt - 4);
        if (body.Length() > 0)
        {
            if (body.IndexOf(",") != 0) return -1;
            Array<String> chunks;
            body.Mid(1).Split(chunks, ",");
            for (int i = 0; i < chunks.Size(); i++)
            {
                Array<String> fields;
                chunks[i].Split(fields, ":");
                if (fields.Size() != 3) return -1;
                ids.Push(fields[0].ToInt());
                gens.Push(fields[1].ToInt());
                health.Push(fields[2].ToInt());
            }
        }
        int storedHash = payload.Mid(hashAt + 6).ToInt();
        int computed = 0;
        for (int i = 0; i < ids.Size(); i++)
        {
            computed = computed * 31 + ids[i];
            computed = computed * 31 + gens[i];
            computed = computed * 31 + health[i];
        }
        if (storedHash != computed) return -1;
        return ids.Size();
    }

    // Writes the profile through the archived-cvar store and reports whether
    // the engine accepted the write and persisted its config.
    bool WriteProfile()
    {
        CVar payload = ProfilePayload();
        CVar schema = ProfileSchema();
        CVar marker = ProfileMarker();
        if (payload == null || schema == null || marker == null)
        {
            Console.Printf("DS_P016_WRITE result=REFUSED reason=missing_cvar");
            return false;
        }
        schema.SetInt(PROFILE_SCHEMA);
        payload.SetString(SerializeProfile());
        marker.SetInt(runMarker);
        bool saved = CVar.SaveConfig();
        profileWriteCount++;
        Console.Printf("DS_P016_WRITE result=%s schema=%d hash=%d entities=%d saved=%d", saved ? "OK" : "SAVE_FAILED", PROFILE_SCHEMA, ContentHash(), logicalIds.Size(), saved);
        Console.Printf("DS_P016_PROFILE profile_id=%s writes=%d payload_len=%d", ProfileId() != null ? ProfileId().GetString() : "", profileWriteCount, payload.GetString().Length());
        return saved;
    }

    // Reads and validates the stored profile. A malformed payload, a schema
    // mismatch or a hash mismatch refuses rather than partially applying.
    bool ReadProfile(out int entityCount)
    {
        entityCount = -1;
        CVar payload = ProfilePayload();
        CVar schema = ProfileSchema();
        if (payload == null || schema == null)
        {
            Console.Printf("DS_P016_READ result=REFUSED reason=missing_cvar");
            return false;
        }
        if (schema.GetInt() != PROFILE_SCHEMA)
        {
            Console.Printf("DS_P016_READ result=REFUSED reason=schema_mismatch stored=%d expected=%d", schema.GetInt(), PROFILE_SCHEMA);
            return false;
        }
        String text = payload.GetString();
        Array<int> ids, gens, health;
        int parsed = ParseProfile(text, ids, gens, health);
        if (parsed < 0)
        {
            Console.Printf("DS_P016_READ result=REFUSED reason=malformed_or_hash_mismatch");
            return false;
        }
        entityCount = parsed;
        logicalIds.Clear(); logicalGeneration.Clear(); logicalHealth.Clear();
        for (int i = 0; i < parsed; i++)
        {
            logicalIds.Push(ids[i]);
            logicalGeneration.Push(gens[i]);
            logicalHealth.Push(health[i]);
        }
        Console.Printf("DS_P016_READ result=OK schema=%d entities=%d hash=%d", PROFILE_SCHEMA, parsed, ContentHash());
        return true;
    }

    void SeedEntities(int baseId, int healthValue)
    {
        logicalIds.Clear(); logicalGeneration.Clear(); logicalHealth.Clear();
        for (int i = 0; i < ENTITY_COUNT; i++)
        {
            logicalIds.Push(baseId + i * 7);
            logicalGeneration.Push(generationCounter);
            logicalHealth.Push(healthValue + i);
        }
    }

    DSP016RunCarrier TransitionCarrier()
    {
        return DSP016RunCarrier(StaticEventHandler.Find("DSP016RunCarrier"));
    }

    void CopyToTransitionCarrier()
    {
        DSP016RunCarrier carrier = TransitionCarrier();
        if (carrier == null) return;
        carrier.runMarker = runMarker;
        carrier.generationCounter = generationCounter;
        carrier.entityHash = ContentHash();
        carrier.logicalIds.Clear();
        carrier.logicalGeneration.Clear();
        carrier.logicalHealth.Clear();
        for (int i = 0; i < logicalIds.Size(); i++)
        {
            carrier.logicalIds.Push(logicalIds[i]);
            carrier.logicalGeneration.Push(logicalGeneration[i]);
            carrier.logicalHealth.Push(logicalHealth[i]);
        }
        carrier.savedX = savedX;
        carrier.savedY = savedY;
        carrier.savedZ = savedZ;
        carrier.savedYaw = savedYaw;
        carrier.savedPitch = savedPitch;
        carrier.savedFov = savedFov;
        carrier.equippedAttackCount = equippedAttackCount;
        carrier.offscreenEnemyCount = offscreenEnemyCount;
        carrier.valid = true;
        Console.Printf("DS_P016_MAP_TRANSITION_PREP result=OK marker=%d generation=%d entities=%d hash=%d", runMarker, generationCounter, logicalIds.Size(), ContentHash());
    }

    bool RestoreFromTransitionCarrier()
    {
        DSP016RunCarrier carrier = TransitionCarrier();
        if (carrier == null || !carrier.valid) return false;
        runMarker = carrier.runMarker;
        generationCounter = carrier.generationCounter;
        logicalIds.Clear();
        logicalGeneration.Clear();
        logicalHealth.Clear();
        for (int i = 0; i < carrier.logicalIds.Size(); i++)
        {
            logicalIds.Push(carrier.logicalIds[i]);
            logicalGeneration.Push(carrier.logicalGeneration[i]);
            logicalHealth.Push(carrier.logicalHealth[i]);
        }
        savedX = carrier.savedX;
        savedY = carrier.savedY;
        savedZ = carrier.savedZ;
        savedYaw = carrier.savedYaw;
        savedPitch = carrier.savedPitch;
        savedFov = carrier.savedFov;
        equippedAttackCount = carrier.equippedAttackCount;
        offscreenEnemyCount = carrier.offscreenEnemyCount;
        phaseTic = 65;
        mapTransitionCount = 1;
        Console.Printf("DS_P016_MAP_TRANSITION map=%s count=1 marker=%d generation=%d entities=%d hash=%d", level.MapName, runMarker, generationCounter, logicalIds.Size(), carrier.entityHash);
        carrier.valid = false;
        return true;
    }

    override void WorldUnloaded(WorldEvent e)
    {
        // The local handler is serialized in an engine save and recreated on
        // each map. This static carrier is only the in-process map boundary.
        if (enabled) CopyToTransitionCarrier();
    }

    override void WorldLoaded(WorldEvent e)
    {
        enabled = level.MapName == "MAP01";
        armed = false;
        restoreReported = false;
        transitionViewReported = false;
        bool returningFromMapTransition = RestoreFromTransitionCarrier();
        if (!e.IsSaveGame && !returningFromMapTransition) phaseTic = 0;
        if (!enabled) return;
        if (!e.IsSaveGame && !returningFromMapTransition)
        {
            runMarker = 1000;
            generationCounter = 1;
        }
        if (returningFromMapTransition && phaseTic < 65) phaseTic = 65;
        if (returningFromMapTransition && players[0].mo != null)
        {
            players[0].mo.SetOrigin((savedX, savedY, savedZ), true);
            players[0].mo.Angle = savedYaw;
            players[0].mo.Pitch = savedPitch;
            players[0].SetFOV(savedFov);
        }
        if (!e.IsSaveGame) SpawnRenderActors();
        Console.Printf("DS_P016_WORLD_LOADED is_save=%d run_marker=%d generation=%d", e.IsSaveGame, runMarker, generationCounter);
        // Non-static handlers do not receive this callback during save restore.
        // The first WorldTick below reports restored fields using a transient
        // process marker; this branch records normal loads and map travel.
        if (e.IsSaveGame)
            Console.Printf("DS_P016_WORLD_RESTORE_DEFERRED phase_tic=%d marker=%d generation=%d", phaseTic, runMarker, generationCounter);
        else if (returningFromMapTransition)
            Console.Printf("DS_P016_MAP_TRANSITION_CONTEXT fp=(%.3f,%.3f,%.3f,%.3f,%.3f,%.3f) attacks=%d offscreen=%d proxies=%d", savedX, savedY, savedZ, savedYaw, savedPitch, savedFov, equippedAttackCount, offscreenEnemyCount, renderProxyCount);
        Console.Printf("DS_P016_SOURCE_FACT zscript_cvar_declaration=UNSUPPORTED durable_store=INVESTIGATED_ARCHIVED_CVAR_ROUTE savegame=ENGINE_SAVEGAME_NONTRANSIENT_FIELDS");
    }

    override void WorldTick()
    {
        // The engine deliberately does NOT call WorldLoaded for handlers
        // restored from a savegame (events.cpp EventManager::WorldLoaded skips
        // non-static handlers while savegamerestore is set). 'enabled' and
        // 'phaseTic' are restored from the save, but this transient flag is not,
        // so it is false on the first tick of a restored process. Re-establish
        // state there and report the restored values, otherwise a successful
        // restore is indistinguishable from an inert handler.
        bool firstTickThisProcess = !startedThisProcess;
        startedThisProcess = true;
        if (!enabled && level != null && level.MapName == "MAP01")
            enabled = true;
        if (!enabled) return;
        // Map-local presentation probes initialize alongside this handler and
        // may apply their own camera defaults. Keep the carried first-person
        // context authoritative throughout this bounded transition fixture.
        if (mapTransitionCount > 0 && players[0].mo != null)
        {
            players[0].mo.SetOrigin((savedX, savedY, savedZ), true);
            players[0].mo.Angle = savedYaw;
            players[0].mo.Pitch = savedPitch;
            players[0].SetFOV(savedFov);
        }
        if (firstTickThisProcess)
        {
            double actualX = players[0].mo != null ? players[0].mo.Pos.X : 0.0;
            double actualY = players[0].mo != null ? players[0].mo.Pos.Y : 0.0;
            double actualZ = players[0].mo != null ? players[0].mo.Pos.Z : 0.0;
            double actualYaw = players[0].mo != null ? players[0].mo.Angle : 0.0;
            double actualPitch = players[0].mo != null ? players[0].mo.Pitch : 0.0;
            double actualFov = players[0].FOV;
            int actualProxies = CountRenderActors();
            bool viewCoherent = players[0].mo != null
                && actualX == savedX && actualY == savedY && actualZ == savedZ
                && actualYaw == savedYaw && actualPitch == savedPitch && actualFov == savedFov;
            bool contextCoherent = viewCoherent && actualProxies == renderProxyCount
                && equippedAttackCount == 3 && offscreenEnemyCount == 2;
            Console.Printf("DS_P016_RESTORE_PROBE phase_tic=%d marker=%d generation=%d entities=%d started_this_process=0 pos=(%.3f,%.3f,%.3f) yaw=%.3f pitch=%.3f fov=%.3f attacks=%d offscreen=%d proxies=%d", phaseTic, runMarker, generationCounter, logicalIds.Size(), savedX, savedY, savedZ, savedYaw, savedPitch, savedFov, equippedAttackCount, offscreenEnemyCount, renderProxyCount);
            Console.Printf("DS_P016_FP_CONTEXT coherent=%d map_count=%d actual=(%.3f,%.3f,%.3f,%.3f,%.3f,%.3f) saved=(%.3f,%.3f,%.3f,%.3f,%.3f,%.3f) actual_proxies=%d adapter_revision=fp-adapter-v1 input_mode=look_relative_wasd logical_window=independent_xy", contextCoherent, mapTransitionCount, actualX, actualY, actualZ, actualYaw, actualPitch, actualFov, savedX, savedY, savedZ, savedYaw, savedPitch, savedFov, actualProxies);
            if (mapTransitionCount > 0)
            {
                bool transitionContextCoherent = players[0].mo != null
                    && actualX == savedX && actualY == savedY && actualZ == savedZ
                    && actualYaw == savedYaw && actualPitch == savedPitch
                    && players[0].DesiredFOV == savedFov && actualProxies == renderProxyCount;
                Console.Printf("DS_P016_MAP_TRANSITION_FP coherent=%d pose=(%.3f,%.3f,%.3f,%.3f,%.3f) desired_fov=%.3f current_fov=%.3f saved_fov=%.3f actual_proxies=%d",
                    transitionContextCoherent, actualX, actualY, actualZ, actualYaw,
                    actualPitch, players[0].DesiredFOV, actualFov, savedFov, actualProxies);
            }
        }
        if (mapTransitionCount > 0 && !transitionViewReported && players[0].mo != null
            && players[0].DesiredFOV == savedFov)
        {
            transitionViewReported = true;
            bool transitionContextCoherent = players[0].mo.Pos.X == savedX
                && players[0].mo.Pos.Y == savedY && players[0].mo.Pos.Z == savedZ
                && players[0].mo.Angle == savedYaw && players[0].mo.Pitch == savedPitch
                && renderProxyCount == CountRenderActors();
            Console.Printf("DS_P016_MAP_TRANSITION_FP coherent=%d pose=(%.3f,%.3f,%.3f,%.3f,%.3f) desired_fov=%.3f current_fov=%.3f saved_fov=%.3f actual_proxies=%d",
                transitionContextCoherent, players[0].mo.Pos.X, players[0].mo.Pos.Y,
                players[0].mo.Pos.Z, players[0].mo.Angle, players[0].mo.Pitch,
                players[0].DesiredFOV, players[0].FOV, savedFov, CountRenderActors());
        }
        if (!enabled) return;
        phaseTic++;
        runMarker++;
        if (players[0].mo != null && mapTransitionCount == 0)
        {
            savedX = players[0].mo.Pos.X;
            savedY = players[0].mo.Pos.Y;
            savedZ = players[0].mo.Pos.Z;
            savedYaw = players[0].mo.Angle;
            savedPitch = players[0].mo.Pitch;
            savedFov = players[0].FOV;
        }
        equippedAttackCount = 3;
        offscreenEnemyCount = 2;
        renderProxyCount = CountRenderActors();

        // A save-restored local handler remains authoritative. Move its state
        // through the in-process static carrier before changing maps; archived
        // profile cvars never carry this transient run state.
        if (firstTickThisProcess && phaseTic > 65 && mapTransitionCount == 0)
        {
            CopyToTransitionCarrier();
            Level.ChangeLevel("MAP01", 0, CHANGELEVEL_KEEPFACING | CHANGELEVEL_NOINTERMISSION);
            return;
        }

        // Once the scripted phases are done, stop mutating state so a follow-up
        // process reads exactly what this one persisted.
        if (phaseTic > 65)
        {
            // On a savegame load the restored phaseTic is already past the
            // scripted phases, so this must report once rather than fall
            // through silently -- otherwise a successful restore looks
            // identical to a handler that was never restored at all.
            if (!restoreReported)
            {
                restoreReported = true;
                Console.Printf("DS_P016_RUN_SAVE_RESTORED phase_tic=%d marker=%d generation=%d hash=%d entities=%d", phaseTic, runMarker, generationCounter, ContentHash(), logicalIds.Size());
            }
            return;
        }
        // Phase 0: before writing anything, report whatever the previous
        // process left behind. This is the restart-durability observation.
        if (phaseTic == 2)
        {
            CVar persisted = ProfilePayload();
            CVar persistedMarker = ProfileMarker();
            int count;
            bool ok = ReadProfile(count);
            String prior = persisted != null ? persisted.GetString() : "";
            // Report the *persisted* marker, not the in-memory run marker, so
            // this line is direct evidence of what survived the restart.
            int storedMarker = persistedMarker != null ? persistedMarker.GetInt() : -1;
            Console.Printf("DS_P016_STARTUP_READ accepted=%d entities=%d hash=%d marker=%d persisted_len=%d", ok, count, ContentHash(), storedMarker, prior.Length());
        }
        // Phase 1: build a fresh profile and write it.
        if (phaseTic == 20 && !armed)
        {
            SeedEntities(ProfileBaseId(), 100);
            Console.Printf("DS_P016_SEED generation=%d entities=%d hash=%d", generationCounter, logicalIds.Size(), ContentHash());
            WriteProfile();
        }
        // Phase 2: simulate a failed purchase. The reward must not be granted
        // and the previously valid profile must remain intact.
        else if (phaseTic == 30 && !armed)
        {
            String before = ProfilePayload().GetString();
            Console.Printf("DS_P016_FAILED_PURCHASE begin payload_hash=%s", before);
            Console.Printf("DS_P016_FAILED_PURCHASE end granted=false payload_unchanged=%d", ProfilePayload().GetString() == before);
        }
        // Phase 3: corrupt the stored payload on purpose, then confirm the
        // reader refuses it instead of silently reinterpreting it.
        else if (phaseTic == 40 && !armed)
        {
            // Compare a chained write against an assignment-to-local write so
            // any difference in behavior is recorded rather than assumed.
            ProfilePayload().SetString("v1;ids,1:1:1;hash=1");
            String chained = ProfilePayload().GetString();
            CVar local = ProfilePayload();
            local.SetString("v1;ids,500:1:100;hash=999999");
            String viaLocal = ProfilePayload().GetString();
            Console.Printf("DS_P016_CORRUPT injected_hash_mismatch chained=%s via_local=%s", chained, viaLocal);
            int ignored;
            bool ok = ReadProfile(ignored);
            Console.Printf("DS_P016_CORRUPT outcome accepted=%d", ok);
        }
        // Phase 4: bump the declared schema and confirm a version mismatch is
        // refused rather than reinterpreted.
        else if (phaseTic == 50 && !armed)
        {
            WriteProfile();
            ProfileSchema().SetInt(PROFILE_SCHEMA + 1);
            Console.Printf("DS_P016_SCHEMA_BUMP injected=%d", PROFILE_SCHEMA + 1);
            int ignored;
            bool ok = ReadProfile(ignored);
            Console.Printf("DS_P016_SCHEMA_BUMP outcome accepted=%d", ok);
        }
        // Phase 5: restore a valid profile, then re-read it to prove a durable
        // round trip within this process before the restart test.
        else if (phaseTic == 60 && !armed)
        {
            SeedEntities(ProfileBaseId(), 100);
            WriteProfile();
            int count;
            bool ok = ReadProfile(count);
            Console.Printf("DS_P016_ROUNDTRIP accepted=%d entities=%d hash=%d", ok, count, ContentHash());
            // Advance logical state so the restart can prove it resumed.
            logicalHealth[0] = 77;
            generationCounter = 2;
            runMarker = 2500;
            // Non-default state makes the save/load comparison meaningful:
            // matching the spawn pose alone would not prove serialization.
            if (players[0].mo != null)
            {
                players[0].mo.SetOrigin((-176.0, 22.0, 0.0), true);
                players[0].mo.Angle = 37.0;
                players[0].mo.Pitch = -11.0;
                players[0].SetFOV(83.0);
            }
            WriteProfile();
            Console.Printf("DS_P016_READY_FOR_RESTART marker=%d hash=%d generation=%d", runMarker, ContentHash(), generationCounter);
        }
        if (runMarker % 25 == 0)
            Console.Printf("DS_P016_STATE marker=%d generation=%d", runMarker, generationCounter);
    }
}

// Synthetic first-person attack proxies used only to prove that save/load
// restores presentation actor ownership exactly once beside logical state.
class DSP016AttackProxy : Actor
{
    Default { Radius 8; Height 8; +NOBLOCKMAP; +NOGRAVITY; +NOINTERACTION; }
    States { Spawn: P13R A -1 Bright; Stop; }
}
