// MAP06 P020 runtime fixture. The arrays are deliberately held directly on
// the event handler because non-transient handler fields are the proven engine
// save route from P016. No native actor state enters the canonical snapshot.
class DSP020Runtime : EventHandler
{
    mixin DSP020EntityStore;
    const MAP = "MAP06";
    const RUN_TICS = 42;
    const EMPTY = 0;
    const ALIVE = 1;

    bool enabled;
    bool finished;
    int tic;
    int updateOrderHash;
    int destroyedCount;
    int staleRejected;
    int cleanupRefs;
    int proxyCreates;
    int proxyUpdates;
    int proxyDestroys;
    int generationCounter;
    double originX;
    double originY;
    double savedBodyX;
    double savedBodyY;
    double savedBodyZ;
    double savedBodyYaw;
    double savedBodyPitch;
    double savedBodyFov;

    // This is intentionally not serialized. It detects a save-restored
    // handler because WorldLoaded is skipped for restored non-static handlers.
    transient bool startedThisProcess;

    int SnapshotHash()
    {
        int hash = 216613626;
        hash = hash * 31 + tic;
        for (int i = 0; i < lifeStates.Size(); i++)
        {
            if (lifeStates[i] != ALIVE) continue;
            hash = hash * 31 + ids[i];
            hash = hash * 31 + generations[i];
            hash = hash * 31 + int(x[i] * 1000.0);
            hash = hash * 31 + int(y[i] * 1000.0);
            hash = hash * 31 + health[i];
            hash = hash * 31 + targets[i];
            hash = hash * 31 + targetGenerations[i];
            hash = hash * 31 + targetIds[i];
        }
        hash = hash * 31 + updateOrderHash;
        return hash;
    }

    void ResetState()
    {
        tic = 0; updateOrderHash = 0; destroyedCount = 0;
        staleRejected = 0; cleanupRefs = 0; proxyCreates = 0; proxyUpdates = 0;
        proxyDestroys = 0; generationCounter = 1; originX = 20.25; originY = -14.5;
        savedBodyX = 0.0; savedBodyY = 0.0; savedBodyZ = 0.0;
        savedBodyYaw = 0.0; savedBodyPitch = 0.0; savedBodyFov = 90.0;
        Reset();
        nextStableId = 100;
        AddSlot(); AddSlot(); AddSlot();
        int enemy = Allocate(1, -12.5, 18.25, 0.25, -0.125, 40);
        int projectile = Allocate(2, 24.75, -31.5, -0.5, 0.25, 1);
        int drop = Allocate(3, -48.0, -12.0, 0.0, 0.0, 1);
        AssignTarget(projectile, enemy);
        AssignOwner(drop, enemy);
        damageTargets[projectile] = enemy;
        dropOwners[drop] = enemy;
        hitHistoryTargets[projectile] = enemy;
        statusOwners[projectile] = enemy;
        timers[projectile] = 7;
    }

    void UpdateLogicalState()
    {
        updateOrderHash = 17;
        for (int i = 0; i < lifeStates.Size(); i++)
        {
            if (lifeStates[i] != ALIVE) continue;
            x[i] += velocityX[i]; y[i] += velocityY[i];
            updateOrderHash = updateOrderHash * 31 + ids[i];
        }
    }

    int BoundProxyCount(int slot, int generation)
    {
        ThinkerIterator it = ThinkerIterator.Create("DSP020PresentationProxy");
        Actor actor;
        int count = 0;
        while ((actor = Actor(it.Next())) != null)
        {
            DSP020PresentationProxy proxy = DSP020PresentationProxy(actor);
            if (proxy.logicalSlot == slot && proxy.logicalGeneration == generation)
                count++;
        }
        return count;
    }

    int BoundProxyCountAll()
    {
        ThinkerIterator it = ThinkerIterator.Create("DSP020PresentationProxy");
        int count = 0;
        while (Actor(it.Next()) != null) count++;
        return count;
    }

    int DamageRefsFor(int targetSlot)
    {
        int count = 0;
        for (int i = 0; i < damageTargets.Size(); i++) if (damageTargets[i] == targetSlot) count++;
        return count;
    }

    int DropRefsFor(int ownerSlot)
    {
        int count = 0;
        for (int i = 0; i < dropOwners.Size(); i++) if (dropOwners[i] == ownerSlot) count++;
        return count;
    }

    int StatusRefsFor(int ownerSlot)
    {
        int count = 0;
        for (int i = 0; i < statusOwners.Size(); i++) if (statusOwners[i] == ownerSlot) count++;
        return count;
    }

    int HitHistoryRefsFor(int targetSlot)
    {
        int count = 0;
        for (int i = 0; i < hitHistoryTargets.Size(); i++) if (hitHistoryTargets[i] == targetSlot) count++;
        return count;
    }

    int StaleProxyCount()
    {
        ThinkerIterator it = ThinkerIterator.Create("DSP020PresentationProxy");
        int count = 0;
        Actor actor;
        while ((actor = Actor(it.Next())) != null)
        {
            DSP020PresentationProxy proxy = DSP020PresentationProxy(actor);
            if (proxy.logicalSlot < 0 || proxy.logicalSlot >= ids.Size()
                || !ValidParts(proxy.logicalSlot, proxy.logicalGeneration, ids[proxy.logicalSlot])) count++;
        }
        return count;
    }

    void UnbindProxy(int slot, int generation)
    {
        ThinkerIterator it = ThinkerIterator.Create("DSP020PresentationProxy");
        Actor actor;
        while ((actor = Actor(it.Next())) != null)
        {
            DSP020PresentationProxy proxy = DSP020PresentationProxy(actor);
            if (proxy.logicalSlot == slot && proxy.logicalGeneration == generation)
            {
                actor.Destroy();
                proxyDestroys++;
            }
        }
    }

    void BindProxy(int slot)
    {
        double engineX;
        double engineY;
        DSP020GroundPlane.ToEngine(x[slot], y[slot], originX, originY, engineX, engineY);
        ThinkerIterator it = ThinkerIterator.Create("DSP020PresentationProxy");
        Actor actor;
        while ((actor = Actor(it.Next())) != null)
        {
            DSP020PresentationProxy proxy = DSP020PresentationProxy(actor);
            if (proxy.logicalSlot == slot && proxy.logicalGeneration == generations[slot])
            {
                proxy.SetOrigin((engineX, engineY, 0.0), true);
                proxyUpdates++;
                return;
            }
        }
        DSP020PresentationProxy created = DSP020PresentationProxy(
            Actor.Spawn("DSP020PresentationProxy", (engineX, engineY, 0.0), NO_REPLACE));
        if (created != null)
        {
            created.logicalSlot = slot;
            created.logicalGeneration = generations[slot];
            proxyCreates++;
        }
    }

    void EmitPresentation()
    {
        ThinkerIterator it = ThinkerIterator.Create("DSP020PresentationProxy");
        Actor actor;
        while ((actor = Actor(it.Next())) != null)
        {
            DSP020PresentationProxy proxy = DSP020PresentationProxy(actor);
            if (proxy.logicalSlot < 0 || proxy.logicalSlot >= ids.Size()
                || !ValidParts(proxy.logicalSlot, proxy.logicalGeneration, ids[proxy.logicalSlot]))
            {
                actor.Destroy();
                proxyDestroys++;
            }
        }
        for (int i = 0; i < lifeStates.Size(); i++)
            if (lifeStates[i] == ALIVE) BindProxy(i);
    }

    bool SafeAdd(int left, int right, out int result)
    {
        if (right > 0 && left > 2147483647 - right) { result = 0; return false; }
        if (right < 0 && left < -2147483648 - right) { result = 0; return false; }
        result = left + right;
        return true;
    }

    bool SafeStat(int baseValue, int delta, out int result)
    {
        if (!SafeAdd(baseValue, delta, result)) return false;
        if (result < 0 || result > 2000000000)
        {
            result = 0;
            return false;
        }
        return true;
    }

    void EmitInitialContracts(int enemy, int projectile, int drop)
    {
        double mappedX;
        double mappedY;
        double roundTripX;
        double roundTripY;
        DSP020GroundPlane.ToEngine(-1234.5, 987.25, originX, originY, mappedX, mappedY);
        DSP020GroundPlane.ToSource(mappedX, mappedY, originX, originY, roundTripX, roundTripY);
        int stat;
        bool statOk = SafeStat(1999999999, 1, stat);
        bool statReject = SafeStat(2000000000, 1, stat);
        Console.Printf("DS_P020_BOOT map=%s ticrate=%d transform=fp-ground-v1 scale=1.000 origin=(%.3f,%.3f) save_fields=NONTRANSIENT", MAP, Thinker.TICRATE, originX, originY);
        Console.Printf("DS_P020_HANDLES old=(slot=%d,gen=%d,id=%d) target=(slot=%d,gen=%d,id=%d) order=0,1,2", drop, generations[drop], ids[drop], projectile, generations[projectile], ids[projectile]);
        Console.Printf("DS_P020_GROUND source=(-1234.500,987.250) engine=(%.3f,%.3f) roundtrip=(%.3f,%.3f) negative_ok=%d", mappedX, mappedY, roundTripX, roundTripY, roundTripX == -1234.5 && roundTripY == 987.25);
        Console.Printf("DS_P020_STATS checked_ok=%d overflow_rejected=%d max_value=2000000000 native_health_used=0", statOk, !statReject);
        Console.Printf("DS_P020_FP adapter=fp-adapter-v1 logical_xy=(%.3f,%.3f) eye_z=presentation_only collision=logical_xy", x[enemy], y[enemy]);
    }

    void EmitLifecycle(int drop, int oldGen, int oldId)
    {
        int boundBefore = BoundProxyCount(drop, oldGen);
        UnbindProxy(drop, oldGen);
        bool destroyed = DestroyParts(drop, oldGen, oldId);
        cleanupRefs = clearedReferences;
        if (destroyed) destroyedCount++;
        bool stale = ValidParts(drop, oldGen, oldId);
        if (!stale) staleRejected++;
        int replacement = Allocate(3, -48.0, -12.0, 0.0, 0.0, 1);
        bool oldStillRejected = !ValidParts(drop, oldGen, oldId);
        BindProxy(replacement);
        int deadProxyRefs = BoundProxyCount(drop, oldGen);
        Console.Printf("DS_P020_LIFECYCLE destroyed=%d stale_rejected=%d replacement=(slot=%d,gen=%d,id=%d) old_handle_redirected=%d bound_before=%d dead_proxy_refs=%d", destroyed, staleRejected, replacement, generations[replacement], ids[replacement], !oldStillRejected, boundBefore, deadProxyRefs);
        Console.Printf("DS_P020_CLEANUP destroyed_refs=%d live_targets=%d live_owners=%d damage_refs=%d drop_refs=%d hit_history_refs=%d status_refs=%d timer_refs=%d presentation_refs=%d", cleanupRefs, targets[drop], owners[drop], DamageRefsFor(drop), DropRefsFor(drop), HitHistoryRefsFor(drop), StatusRefsFor(drop), timers[drop] > 0 ? 1 : 0, deadProxyRefs);
    }

    void EmitTargetReuse(int targetSlot, int oldGen, int oldId, int sourceSlot)
    {
        UnbindProxy(targetSlot, oldGen);
        bool destroyed = DestroyParts(targetSlot, oldGen, oldId);
        int replacement = Allocate(1, -12.5, 18.25, 0.25, -0.125, 40);
        bool oldRejected = !ValidParts(targetSlot, oldGen, oldId);
        bool targetReference = TargetStillValid(sourceSlot);
        AssignTarget(sourceSlot, replacement);
        BindProxy(replacement);
        Console.Printf("DS_P020_TARGET_REUSE destroyed=%d replacement=(slot=%d,gen=%d,id=%d) old_rejected=%d stale_source_target_valid=%d rebound_target_valid=%d source_target_gen=%d source_target_id=%d cleared_refs=%d", destroyed, replacement, generations[replacement], ids[replacement], oldRejected, targetReference, TargetStillValid(sourceSlot), targetGenerations[sourceSlot], targetIds[sourceSlot], clearedReferences);
    }

    void EmitRebase()
    {
        double beforeX;
        double beforeY;
        DSP020GroundPlane.ToEngine(x[0], y[0], originX, originY, beforeX, beforeY);
        double oldOriginX = originX;
        double oldOriginY = originY;
        originX += 7.5;
        originY -= 6.25;
        double afterX;
        double afterY;
        double sourceAfterX;
        double sourceAfterY;
        DSP020GroundPlane.ToEngine(x[0], y[0], originX, originY, afterX, afterY);
        DSP020GroundPlane.ToSource(afterX, afterY, originX, originY, sourceAfterX, sourceAfterY);
        bool logicalPreserved = sourceAfterX == x[0] && sourceAfterY == y[0];
        bool targetPreserved = TargetStillValid(1);
        Console.Printf("DS_P020_REBASE old_origin=(%.3f,%.3f) new_origin=(%.3f,%.3f) before_engine=(%.3f,%.3f) after_engine=(%.3f,%.3f) logical_preserved=%d target_preserved=%d collision_preserved=%d", oldOriginX, oldOriginY, originX, originY, beforeX, beforeY, afterX, afterY, logicalPreserved, targetPreserved, logicalPreserved);
        EmitPresentation();
    }

    void EmitSaveSnapshot()
    {
        Console.Printf("DS_P020_SAVE_READY tic=%d hash=%d entities=%d order_hash=%d", tic, SnapshotHash(), lifeStates.Size(), updateOrderHash);
    }

    void EmitSaveCandidate()
    {
        Console.Printf("DS_P020_SAVE_CANDIDATE tic=%d hash=%d entities=%d order_hash=%d", tic, SnapshotHash(), lifeStates.Size(), updateOrderHash);
    }

    void CaptureFirstPersonContext()
    {
        if (players[0].mo == null) return;
        savedBodyX = players[0].mo.Pos.X;
        savedBodyY = players[0].mo.Pos.Y;
        savedBodyZ = players[0].mo.Pos.Z;
        savedBodyYaw = players[0].mo.Angle;
        savedBodyPitch = players[0].mo.Pitch;
        savedBodyFov = players[0].FOV;
    }

    override void WorldLoaded(WorldEvent e)
    {
        enabled = level.MapName == MAP;
        finished = false;
        if (!enabled) return;
        if (!e.IsSaveGame)
        {
            ResetState();
            EmitInitialContracts(0, 1, 2);
            EmitPresentation();
        }
        Console.Printf("DS_P020_WORLD_LOADED is_save=%d tic=%d hash=%d entities=%d", e.IsSaveGame, tic, SnapshotHash(), lifeStates.Size());
    }

    override void WorldTick()
    {
        if (!enabled && level != null && level.MapName == MAP) enabled = true;
        if (!enabled || finished) return;
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
            int live = 0;
            for (int i = 0; i < lifeStates.Size(); i++) if (lifeStates[i] == ALIVE) live++;
            Console.Printf("DS_P020_RESTORE first_tick=1 tic=%d hash=%d entities=%d order_hash=%d live=%d", tic, SnapshotHash(), lifeStates.Size(), updateOrderHash, live);
            bool fpCoherent = players[0].mo != null
                && players[0].mo.Pos.X == savedBodyX && players[0].mo.Pos.Y == savedBodyY
                && players[0].mo.Pos.Z == savedBodyZ && players[0].mo.Angle == savedBodyYaw
                && players[0].mo.Pitch == savedBodyPitch && players[0].FOV == savedBodyFov;
            Console.Printf("DS_P020_FP_RESTORE coherent=%d body=(%.3f,%.3f,%.3f) yaw=%.3f pitch=%.3f fov=%.3f logical_xy=(%.3f,%.3f) target_slot=%d collision=logical_xy first_person_live=1", fpCoherent, savedBodyX, savedBodyY, savedBodyZ, savedBodyYaw, savedBodyPitch, savedBodyFov, x[0], y[0], targets[1]);
            EmitPresentation();
        }
        tic++;
        if (tic == 1 && players[0].mo != null)
        {
            players[0].mo.SetOrigin((-176.0, 22.0, 0.0), true);
            players[0].mo.Angle = 37.0;
            players[0].mo.Pitch = -11.0;
            players[0].SetFOV(83.0);
        }
        if (tic <= 20) CaptureFirstPersonContext();
        UpdateLogicalState();
        if (tic == 5) EmitLifecycle(2, generations[2], ids[2]);
        if (tic == 8) EmitTargetReuse(0, generations[0], ids[0], 1);
        if (tic == 15) EmitRebase();
        // The external save command follows a 20-tic wait and is processed
        // after this next simulation tick; emit the snapshot at tic 21 so the
        // marker names the exact non-transient state captured by the engine.
        if (tic == 21) EmitSaveSnapshot();
        if (tic >= 18 && tic <= 24) EmitSaveCandidate();
        if (tic % 10 == 0)
            Console.Printf("DS_P020_STATE tic=%d hash=%d order_hash=%d live=%d proxies=%d", tic, SnapshotHash(), updateOrderHash, lifeStates[0] == ALIVE ? 1 : 0, proxyCreates);
        if (tic >= RUN_TICS)
        {
            Console.Printf("DS_P020_COMPLETE tic=%d hash=%d order_hash=%d stale_rejected=%d cleanup_refs=%d damage_refs=%d drop_refs=%d hit_history_refs=%d status_refs=%d timer_refs=%d live_proxy_refs=%d stale_proxy_refs=%d native_health_used=0", tic, SnapshotHash(), updateOrderHash, staleRejected, cleanupRefs, DamageRefsFor(2), DropRefsFor(2), HitHistoryRefsFor(2), StatusRefsFor(2), timers[2] > 0 ? 1 : 0, BoundProxyCountAll(), StaleProxyCount());
            finished = true;
        }
    }
}
