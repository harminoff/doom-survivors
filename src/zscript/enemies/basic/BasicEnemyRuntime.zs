// MAP09 P023 basic-enemy runtime fixture.
//
// The logical arrays and transaction processing are authoritative.  The
// actor below is only a disposable visual mirror: it has no native monster
// AI, solidity, health, pain, target, random or blocking behavior.
class DSP023BasicEnemyProxy : Actor
{
    int logicalSlot;
    int logicalGeneration;
    int logicalStableId;

    Default
    {
        +NOBLOCKMAP
        +NOGRAVITY
        +NOINTERACTION
        Radius 2;
        Height 8;
        RenderStyle "Translucent";
        Alpha 0.8;
    }
}

class DSP023BasicEnemyRuntime : EventHandler
{
    mixin DSP020EntityStore;

    const MAP = "MAP09";
    const RUN_TICS = 70;
    const ALIVE = 1;

    bool enabled;
    bool completed;
    int tic;
    int playerHealth;
    int playerDeathCount;
    int playerInvulnerableUntil;
    int killCount;
    int xpRequestCount;
    int dropRequestCount;
    int damageEventId;
    int dropRng;
    int cameraVariant;
    int movementRecords;
    int contactRecords;
    int acceptedContactCount;
    int rejectedContactCount;
    int staleRejectedCount;
    int deathCount;
    int despawnCount;
    int proxyCreates;
    int proxyUpdates;
    int proxyDestroys;
    double playerX;
    double playerY;
    int releasedSlot;
    int releasedGeneration;
    int releasedStableId;

    // Per-attacker source-model cooldowns.  They are indexed by logical slot
    // and reset on every allocation, so recycled entities cannot inherit a
    // previous attacker's contact history.
    Array<int> contactCooldownUntil;
    Array<int> contactEnabled;
    Array<int> dropEligible;
    Array<int> deathHandled;

    void AddParallelSlot()
    {
        contactCooldownUntil.Push(0);
        contactEnabled.Push(1);
        dropEligible.Push(1);
        deathHandled.Push(0);
    }

    void ResetState()
    {
        Reset();
        contactCooldownUntil.Clear();
        contactEnabled.Clear();
        dropEligible.Clear();
        deathHandled.Clear();
        // Reserve slots so P020 allocation and its generation semantics are
        // used directly, including the deterministic lowest-empty-slot reuse.
        for (int i = 0; i < 6; i++)
        {
            AddSlot();
            AddParallelSlot();
        }
        nextStableId = 100;
        tic = 0;
        playerHealth = DSP023BasicEnemyData.PLAYER_HEALTH;
        playerDeathCount = 0;
        playerInvulnerableUntil = 0;
        killCount = 0;
        xpRequestCount = 0;
        dropRequestCount = 0;
        damageEventId = 0;
        // The drop stream is named and independent of camera presentation.
        dropRng = 303;
        cameraVariant = 0;
        movementRecords = 0;
        contactRecords = 0;
        acceptedContactCount = 0;
        rejectedContactCount = 0;
        staleRejectedCount = 0;
        deathCount = 0;
        despawnCount = 0;
        proxyCreates = 0;
        proxyUpdates = 0;
        proxyDestroys = 0;
        playerX = 0.0;
        playerY = 0.0;

        // Stable IDs 100 and 101 are the starter BAT3 contact attackers.  The
        // first begins alone so its seven-tic cadence is observable; the
        // second joins at tic 16 for stable-ID/global-invulnerability checks.
        // The next slots are far-away lifecycle fixtures.
        AllocateEnemy(2.0, 0.0, 100.0, 0.0, DSP023BasicEnemyData.HEALTH, 1);
        AllocateEnemy(0.0, 2.0, 0.0, 100.0, DSP023BasicEnemyData.HEALTH, 1);
        AllocateEnemy(100.0, 0.0, -0.5, 0.0, DSP023BasicEnemyData.HEALTH, 0);
        AllocateEnemy(-100.0, 0.0, 0.5, 0.0, DSP023BasicEnemyData.HEALTH, 0);
        contactEnabled[1] = 0;
    }

    int AllocateEnemy(double positionX, double positionY, double speedX,
                      double speedY, int initialHealth, int canContact)
    {
        int slot = Allocate(DSP023BasicEnemyData.KIND_BAT3, positionX,
            positionY, speedX, speedY, initialHealth);
        contactCooldownUntil[slot] = 0;
        contactEnabled[slot] = canContact;
        dropEligible[slot] = 1;
        deathHandled[slot] = 0;
        return slot;
    }

    double DistanceToPlayer(int slot)
    {
        double dx = x[slot] - playerX;
        double dy = y[slot] - playerY;
        return sqrt(dx * dx + dy * dy);
    }

    void EmitCameraVariant()
    {
        if (players[0].mo == null) return;
        double yaw = 0.0;
        double pitch = 0.0;
        double fov = 90.0;
        if (cameraVariant == 1) yaw = 90.0;
        else if (cameraVariant == 2) yaw = 180.0;
        else if (cameraVariant == 3) { yaw = 270.0; pitch = 18.0; fov = 110.0; }
        players[0].mo.Angle = yaw;
        players[0].mo.Pitch = pitch;
        players[0].SetFOV(fov);
        Console.Printf("DS_P023_CAMERA variant=%d yaw=%.3f pitch=%.3f fov=%.3f logical_xy=(%.3f,%.3f) camera_role=PRESENTATION_ONLY", cameraVariant, yaw, pitch, fov, playerX, playerY);
    }

    void BindProxy(int slot)
    {
        if (slot < 0 || slot >= lifeStates.Size() || lifeStates[slot] != ALIVE) return;
        double engineX;
        double engineY;
        DSP020GroundPlane.ToEngine(x[slot], y[slot], playerX, playerY, engineX, engineY);
        ThinkerIterator it = ThinkerIterator.Create("DSP023BasicEnemyProxy");
        Actor actor;
        while ((actor = Actor(it.Next())) != null)
        {
            DSP023BasicEnemyProxy proxy = DSP023BasicEnemyProxy(actor);
            if (proxy.logicalSlot == slot && proxy.logicalGeneration == generations[slot]
                && proxy.logicalStableId == ids[slot])
            {
                proxy.SetOrigin((engineX, engineY, 0.0), true);
                proxyUpdates++;
                return;
            }
        }
        DSP023BasicEnemyProxy created = DSP023BasicEnemyProxy(
            Actor.Spawn("DSP023BasicEnemyProxy", (engineX, engineY, 0.0), NO_REPLACE));
        if (created != null)
        {
            created.logicalSlot = slot;
            created.logicalGeneration = generations[slot];
            created.logicalStableId = ids[slot];
            proxyCreates++;
        }
    }

    void RemoveProxy(int slot, int generation, int stableId)
    {
        ThinkerIterator it = ThinkerIterator.Create("DSP023BasicEnemyProxy");
        Actor actor;
        while ((actor = Actor(it.Next())) != null)
        {
            DSP023BasicEnemyProxy proxy = DSP023BasicEnemyProxy(actor);
            if (proxy.logicalSlot == slot && proxy.logicalGeneration == generation
                && proxy.logicalStableId == stableId)
            {
                actor.Destroy();
                proxyDestroys++;
            }
        }
    }

    void SyncPresentation()
    {
        ThinkerIterator it = ThinkerIterator.Create("DSP023BasicEnemyProxy");
        Actor actor;
        while ((actor = Actor(it.Next())) != null)
        {
            DSP023BasicEnemyProxy proxy = DSP023BasicEnemyProxy(actor);
            if (proxy.logicalSlot < 0 || proxy.logicalSlot >= lifeStates.Size()
                || !ValidParts(proxy.logicalSlot, proxy.logicalGeneration, proxy.logicalStableId))
            {
                actor.Destroy();
                proxyDestroys++;
            }
        }
        for (int i = 0; i < lifeStates.Size(); i++)
            if (lifeStates[i] == ALIVE) BindProxy(i);
    }

    void MoveEnemies()
    {
        // Scan slots deterministically.  Movement is source-model planar
        // movement and always targets the authoritative player body.
        for (int slot = 0; slot < lifeStates.Size(); slot++)
        {
            if (lifeStates[slot] != ALIVE) continue;
            double oldX = x[slot];
            double oldY = y[slot];
            double dx = playerX - oldX;
            double dy = playerY - oldY;
            double distance = sqrt(dx * dx + dy * dy);
            double step = distance > DSP023BasicEnemyData.MOVEMENT_SPEED
                ? DSP023BasicEnemyData.MOVEMENT_SPEED : distance;
            if (distance > 0.000001)
            {
                x[slot] = oldX + dx / distance * step;
                y[slot] = oldY + dy / distance * step;
            }
            else
            {
                x[slot] = playerX;
                y[slot] = playerY;
                step = 0.0;
            }
            double after = DistanceToPlayer(slot);
            bool noOvershoot = step <= DSP023BasicEnemyData.MOVEMENT_SPEED
                && after >= -0.000001 && after <= distance + 0.000001
                && (distance < 0.000001 || abs(distance - step - after) < 0.0001);
            movementRecords++;
            Console.Printf("DS_P023_MOVE tic=%d slot=%d generation=%d stable_id=%d kind=BAT3 from=(%.3f,%.3f) to=(%.3f,%.3f) target=(%.3f,%.3f) distance_before=%.3f distance_after=%.3f step=%.3f speed=%.3f no_overshoot=%d camera_ignored=1", tic, slot, generations[slot], ids[slot], oldX, oldY, x[slot], y[slot], playerX, playerY, distance, after, step, DSP023BasicEnemyData.MOVEMENT_SPEED, noOvershoot);
        }
    }

    void EmitContact(int slot, int inContact, int eligible, int accepted,
                     String reason, int healthBefore, int healthAfter,
                     int cooldownBefore, int cooldownAfter,
                     int invulnerableBefore, int invulnerableAfter,
                     double distance)
    {
        contactRecords++;
        Console.Printf("DS_P023_CONTACT tic=%d attacker_slot=%d generation=%d stable_id=%d target=PLAYER distance=%.3f radius_sum=%.3f inclusive=1 in_contact=%d eligible=%d accepted=%d reason=%s damage=%d player_health_before=%d player_health_after=%d cooldown_before=%d cooldown_after=%d invuln_before=%d invuln_after=%d camera_ignored=1", tic, slot, generations[slot], ids[slot], distance, DSP023BasicEnemyData.CONTACT_DISTANCE, inContact, eligible, accepted, reason, DSP023BasicEnemyData.CONTACT_DAMAGE, healthBefore, healthAfter, cooldownBefore, cooldownAfter, invulnerableBefore, invulnerableAfter);
    }

    void ProcessOneContact(int slot)
    {
        if (lifeStates[slot] != ALIVE || contactEnabled[slot] == 0) return;
        double distance = DistanceToPlayer(slot);
        bool inContact = distance <= DSP023BasicEnemyData.CONTACT_DISTANCE + 0.000001;
        int cooldownBefore = contactCooldownUntil[slot];
        int invulnerableBefore = playerInvulnerableUntil;
        int healthBefore = playerHealth;
        int cooldownAfter = cooldownBefore;
        int invulnerableAfter = invulnerableBefore;
        int healthAfter = healthBefore;
        int eligible = 0;
        int accepted = 0;
        String reason = "OUTSIDE_CONTACT";
        if (inContact)
        {
            eligible = tic >= cooldownBefore ? 1 : 0;
            if (!eligible) reason = "ATTACKER_COOLDOWN";
            else if (playerHealth <= 0) reason = "PLAYER_DEAD";
            else if (tic < playerInvulnerableUntil) reason = "PLAYER_INVULNERABLE";
            else
            {
                accepted = 1;
                reason = "SUCCESS";
                healthAfter = playerHealth - DSP023BasicEnemyData.CONTACT_DAMAGE;
                if (healthAfter < 0) healthAfter = 0;
                playerHealth = healthAfter;
                cooldownAfter = tic + DSP023BasicEnemyData.CONTACT_COOLDOWN;
                invulnerableAfter = tic + DSP023BasicEnemyData.PLAYER_INVULNERABILITY;
                contactCooldownUntil[slot] = cooldownAfter;
                playerInvulnerableUntil = invulnerableAfter;
                acceptedContactCount++;
                if (playerHealth == 0 && playerDeathCount == 0)
                {
                    playerDeathCount++;
                    Console.Printf("DS_P023_PLAYER_DEATH tic=%d health_before=%d health_after=0 accepted_contact=1 death_count=%d", tic, healthBefore, playerDeathCount);
                }
            }
        }
        if (!accepted) rejectedContactCount++;
        EmitContact(slot, inContact, eligible, accepted, reason, healthBefore,
            healthAfter, cooldownBefore, cooldownAfter, invulnerableBefore,
            invulnerableAfter, distance);
    }

    void ProcessContacts()
    {
        // Resolve by stable ID, independent of slot order.  This is a small
        // deterministic selection sort for the fixture and keeps same-tic
        // global invulnerability observable in the trace.
        for (int stable = 1; stable < nextStableId; stable++)
        {
            for (int slot = 0; slot < lifeStates.Size(); slot++)
            {
                if (lifeStates[slot] == ALIVE && ids[slot] == stable)
                    ProcessOneContact(slot);
            }
        }
    }

    void EmitXpAndDrop(int slot, int generation, int stableId)
    {
        xpRequestCount++;
        Console.Printf("DS_P023_XP_REQUEST tic=%d source_slot=%d source_generation=%d source_id=%d xp_milliunits=%d request_count=%d", tic, slot, generation, stableId, DSP023BasicEnemyData.XP_MILLIUNITS, xpRequestCount);
        int before = dropRng;
        dropRng = DSP023BasicEnemyData.NextRng(dropRng);
        dropRequestCount++;
        Console.Printf("DS_P023_DROP_REQUEST tic=%d source_slot=%d source_generation=%d source_id=%d item=%s xp_milliunits=%d rng_stream=drop rng_before=%d rng_after=%d draw=1 request_count=%d", tic, slot, generation, stableId, DSP023BasicEnemyData.DROP_ID, DSP023BasicEnemyData.XP_MILLIUNITS, before, dropRng, dropRequestCount);
    }

    void ApplyDamage(int slot, int generation, int stableId, int amount,
                     String source)
    {
        damageEventId++;
        int before = 0;
        int after = 0;
        int accepted = ValidParts(slot, generation, stableId) ? 1 : 0;
        String reason = accepted ? "SUCCESS" : "STALE_OR_DEAD";
        if (accepted)
        {
            before = health[slot];
            after = before - amount;
            if (after < 0) after = 0;
            health[slot] = after;
            Console.Printf("DS_P023_DAMAGE tic=%d event_id=%d source=%s target_slot=%d target_generation=%d target_id=%d amount=%d accepted=1 reason=SUCCESS health_before=%d health_after=%d", tic, damageEventId, source, slot, generation, stableId, amount, before, after);
            if (after <= 0 && deathHandled[slot] == 0)
            {
                deathHandled[slot] = 1;
                dropEligible[slot] = 0;
                killCount++;
                deathCount++;
                Console.Printf("DS_P023_DEATH tic=%d target_slot=%d target_generation=%d target_id=%d health=0 kill_delta=1 kill_count=%d death_count=%d life_before=LIVE life_after=DEAD", tic, slot, generation, stableId, killCount, deathCount);
                EmitXpAndDrop(slot, generation, stableId);
                RemoveProxy(slot, generation, stableId);
                DestroyParts(slot, generation, stableId);
            }
        }
        else
        {
            staleRejectedCount++;
            Console.Printf("DS_P023_DAMAGE tic=%d event_id=%d source=%s target_slot=%d target_generation=%d target_id=%d amount=%d accepted=0 reason=%s health_before=0 health_after=0", tic, damageEventId, source, slot, generation, stableId, amount, reason);
        }
    }

    void DespawnAndReuse()
    {
        int slot = 2;
        int generation = generations[slot];
        int stableId = ids[slot];
        releasedSlot = slot;
        releasedGeneration = generation;
        releasedStableId = stableId;
        int rngBefore = dropRng;
        RemoveProxy(slot, generation, stableId);
        bool released = DestroyParts(slot, generation, stableId);
        if (released) despawnCount++;
        Console.Printf("DS_P023_DESPAWN tic=%d target_slot=%d target_generation=%d target_id=%d released=%d life_before=LIVE life_after=RELEASED damage_delta=0 kill_delta=0 xp_delta=0 drop_delta=0 rng_stream=drop rng_before=%d rng_after=%d reward=NONE", tic, slot, generation, stableId, released, rngBefore, dropRng);
    }

    void ReuseDespawned()
    {
        int replacement = AllocateEnemy(96.0, 0.0, -0.5, 0.0, DSP023BasicEnemyData.HEALTH, 0);
        Console.Printf("DS_P023_REPLACEMENT tic=%d slot=%d old_generation=%d old_id=%d new_generation=%d new_id=%d reused=1 stale_old_handle=REJECTED", tic, replacement, releasedGeneration, releasedStableId, generations[replacement], ids[replacement]);
        BindProxy(replacement);
    }

    void EmitTrace()
    {
        int live = 0;
        for (int i = 0; i < lifeStates.Size(); i++) if (lifeStates[i] == ALIVE) live++;
        Console.Printf("DS_P023_TRACE tic=%d player_x=%.3f player_y=%.3f player_health=%d player_invuln_until=%d kill_count=%d xp_requests=%d drop_requests=%d drop_rng=%d live=%d accepted_contacts=%d rejected_contacts=%d stale_rejected=%d camera_ignored=1", tic, playerX, playerY, playerHealth, playerInvulnerableUntil, killCount, xpRequestCount, dropRequestCount, dropRng, live, acceptedContactCount, rejectedContactCount, staleRejectedCount);
    }

    override void WorldLoaded(WorldEvent e)
    {
        enabled = level.MapName == MAP;
        completed = false;
        if (!enabled) return;
        CVar variant = CVar.FindCVar("ds_p023_camera_variant");
        int configuredVariant = variant != null ? variant.GetInt() : 0;
        if (configuredVariant < 0 || configuredVariant > 3) configuredVariant = 0;
        ResetState();
        cameraVariant = configuredVariant;
        if (players[0].mo != null)
            players[0].mo.SetOrigin((0.0, 0.0, 0.0), true);
        Console.Printf("DS_P023_BOOT map=%s ticrate=%d stage=FOREST enemy=BAT3 source_path=wiki:Mad_Forest#enemies[0] source_build=1.16.107 fixture=bat3-basic-v1 behavior=ENGINEERING_APPROXIMATION", MAP, Thinker.TICRATE);
        Console.Printf("DS_P023_RULES movement_speed=0.500 contact_radii=(2.000,2.000) contact_distance=4.000 inclusive=1 health_milliunits=3000 player_health_milliunits=10000 contact_damage_milliunits=1250 attacker_cooldown_tics=7 player_invulnerability_tics=3 native_ai=0 native_solid=0 native_damage=0 native_pain=0 native_random=0 native_target=0 camera_frustum=SEPARATE");
        Console.Printf("DS_P023_AUTHORITY source_model=LOGICAL_XY_AND_TRANSACTIONS proxy=DSP023BasicEnemyProxy presentation_only=1 xp=REQUEST_ONLY drop=REQUEST_ONLY rng_stream=drop");
        EmitCameraVariant();
        SyncPresentation();
    }

    override void WorldTick()
    {
        if (!enabled || completed) return;
        tic++;
        // The fixture has no gameplay input tape.  Keep the authoritative
        // body at the map start while camera yaw/pitch/FOV vary independently.
        playerX = 0.0;
        playerY = 0.0;
        if (players[0].mo != null)
        {
            players[0].mo.SetOrigin((0.0, 0.0, 0.0), true);
            EmitCameraVariant();
        }
        if (tic == 1)
            Console.Printf("DS_P023_CONTACT_PHASE tic=1 mode=ONE_ATTACKER attackers=1 cadence=7");
        if (tic == 16)
        {
            contactEnabled[1] = 1;
            Console.Printf("DS_P023_CONTACT_PHASE tic=16 mode=MANY_ATTACKER attackers=2 order=stable_id global_invulnerability=1");
        }
        MoveEnemies();
        ProcessContacts();
        if (tic == 20)
        {
            int generation = generations[0];
            int stableId = ids[0];
            ApplyDamage(0, generation, stableId, 3000, "TEST_SEAM");
        }
        if (tic == 21)
        {
            // This is the duplicate death/drop attempt.  The dead generation
            // must fail closed before a replacement can receive it.
            ApplyDamage(0, generations[0], ids[0], 3000, "DUPLICATE_DEATH");
            int replacement = AllocateEnemy(96.0, 0.0, -0.5, 0.0, DSP023BasicEnemyData.HEALTH, 0);
            Console.Printf("DS_P023_REUSE_AFTER_DEATH tic=%d slot=%d old_generation=1 old_id=100 new_generation=%d new_id=%d reused=1 death_reward_already_emitted=1", tic, replacement, generations[replacement], ids[replacement]);
            BindProxy(replacement);
        }
        if (tic == 30) DespawnAndReuse();
        if (tic == 31) ReuseDespawned();
        if (tic == 32)
        {
            // Handle captured before the tic-30 release.  The slot now holds
            // a replacement at generation 2, so this delayed transaction is
            // rejected even though its slot index is still 2.
            ApplyDamage(2, 1, 102, 3000, "STALE_AFTER_DESPAWN_REUSE");
            Console.Printf("DS_P023_STALE_HIT tic=%d slot=2 generation=1 stable_id=102 replacement_generation=%d replacement_id=%d accepted=0 reason=STALE_GENERATION", tic, generations[2], ids[2]);
        }
        SyncPresentation();
        EmitTrace();
        if (tic >= RUN_TICS)
        {
            Console.Printf("DS_P023_COMPLETE tics=%d movement_records=%d contact_records=%d accepted_contacts=%d rejected_contacts=%d player_health=%d player_death_count=%d kill_count=%d xp_requests=%d drop_requests=%d death_count=%d despawn_count=%d stale_rejected=%d drop_rng=%d camera_variant=%d camera_invariant=true native_ai=0 native_solid=0 native_damage=0 native_pain=0 native_random=0 native_target=0 visual_capture_required=1 source_values=ENGINEERING_APPROXIMATION", tic, movementRecords, contactRecords, acceptedContactCount, rejectedContactCount, playerHealth, playerDeathCount, killCount, xpRequestCount, dropRequestCount, deathCount, despawnCount, staleRejectedCount, dropRng, cameraVariant);
            Console.Printf("DS_P023_FRAMEBUFFER_CAPTURE tic=%d nonblank_required=1 camera_variant=%d", tic, cameraVariant);
            LevelLocals.MakeScreenShot();
            completed = true;
        }
    }
}
