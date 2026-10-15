// MAP27 controlled P041 ricochet harness. All inventory, ranks, walls and
// contact events below are test fixtures; the bounce physics, hits and
// persistence hash still run through the shared production DSP041Bounce
// mixin (src/zscript/weapons/bounce/BounceRuntime.zs).
class DSP041BounceRuntime : EventHandler
{
    mixin DSRunStatFields;
    mixin DSP020EntityStore;
    mixin DSP024SpatialIndex;
    mixin DSP025AttackCore;
    mixin DSP033ResolvedStats;
    mixin DSP041BounceTargeting;
    mixin DSP041Bounce;

    const MAP = "MAP27";
    const ENEMY_KIND = 1;
    const PLAYER_KIND = 99;
    const WEAPON_KIND = 90;

    bool started;
    bool enabled;
    bool completed;
    int logicalTic;
    int tic;
    String activeMode;
    int cameraVariant;
    int cameraYaw;
    int cameraPitch;
    int cameraFov;
    int playerSlot;
    double playerX;
    double playerY;
    int finishAtTic;
    bool pauseRequested;
    bool pauseOpened;
    bool pauseClosed;
    int pauseStartLogicalTic;
    int pauseStartHash;
    int pauseResumeTic;
    int pauseResumeHash;
    ui bool uiPauseRequestSent;
    ui bool uiPauseObserved;
    ui bool uiPauseResumeSent;
    ui int uiTics;
    ui int uiLogicalTic;
    ui int uiPauseHash;
    ui int uiPauseAtTic;
    ui int uiPauseUntilUiTic;
    ui int uiPauseMode;
    int saveLogicalTic;
    int saveStateHash;
    bool saveHold;
    transient bool startedThisProcess;
    int weaponIndexRunetracer;
    int weaponIndexBone;
    int weaponIndexCherry;
    int weaponIndexCarrello;
    int weaponIndexNoFuture;
    int contactEnemySlot;
    int contactEnemyGeneration;
    int contactEnemyId;
    int weaponIndexA01Edge;
    int weaponIndexA01Wall;
    int weaponIndexA01Corner;
    int weaponIndexNoTunnel;
    int noTunnelTargetSlot;
    Array<int> capacityWeaponIndices;

    override void OnRegister()
    {
        IsUiProcessor = false;
        RequireMouse = false;
    }

    // DSP041Bounce's DSP041ApplyHit/DSP041ApplyExplosion now call
    // HandleEnemyDeath on a checked-hit kill (mirrors every other family's
    // own MAP2x harness, e.g. GlobalMap26Runtime.HandleEnemyDeath). This
    // harness has no DSP027ExperienceStore mixin (unlike GlobalMap26Runtime),
    // so its own HandleEnemyDeath is the minimal release-the-entity form;
    // the ordinary XP-drop treatment is exercised by VerticalSlice's own
    // HandleEnemyDeath on MAP16 instead (docs/contracts/bounce-projectiles.md
    // does not require an XP drop as part of the MAP27 fixture's own
    // evidence).
    void HandleEnemyDeath(int slot, int beforeHealth, int eventId)
    {
        if (!ValidParts(slot, generations[slot], ids[slot])) return;
        Console.Printf("DS_P041_MAP27_DEATH event_id=%d tic=%d target_id=%d before=%d", eventId, logicalTic, ids[slot], beforeHealth);
        DestroyParts(slot, generations[slot], ids[slot]);
    }

    int ReadCameraVariant()
    {
        CVar camera = CVar.FindCVar("ds_p041_camera_variant");
        int variant = camera != null ? camera.GetInt() : 0;
        return variant >= 0 && variant <= 4 ? variant : 0;
    }

    // CONTROLLED_ENGINE_FIXTURE override for item 3's cross-Armor-value
    // NO FUTURE damage check. Defaults to 1 (the fixture's original flat
    // value) when the cvar is unset or out of the sane bounded range.
    int ReadNoFutureArmorOverride()
    {
        CVar cvar = CVar.FindCVar("ds_p041_no_future_armor");
        int value = cvar != null ? cvar.GetInt() : 1;
        return value >= 1 && value <= 20 ? value : 1;
    }

    // FP01/A02: monitor size, aspect, FOV, camera yaw/pitch and view frustum
    // are never logical inputs (contract). Variants 0-4 flex every one of
    // those presentation knobs (0=baseline, 1=yaw180, 2=pitch22, 3=wide FOV
    // 120, 4=narrow FOV 60); item 6 additionally combines these with actual
    // engine window-size variants. The logical boundary/paths must stay
    // identical because DSP041CurrentBoundary reads only playerX/playerY.
    void ConfigureCamera()
    {
        cameraVariant = ReadCameraVariant();
        cameraYaw = cameraVariant == 1 ? 180 : 0;
        cameraPitch = cameraVariant == 2 ? 22 : 0;
        cameraFov = cameraVariant == 3 ? 120 : (cameraVariant == 4 ? 60 : 90);
        if (players[0].mo != null)
        {
            players[0].mo.Angle = cameraYaw;
            players[0].mo.Pitch = cameraPitch;
            players[0].SetFOV(cameraFov);
        }
        Console.Printf("DS_P041_MAP27_CAMERA variant=%d yaw=%d pitch=%d fov=%d source=UZDOOM_PLAYER_VIEW", cameraVariant, cameraYaw, cameraPitch, cameraFov);
    }

    String ReadMode()
    {
        CVar mode = CVar.FindCVar("ds_p041_mode");
        return mode != null ? mode.GetString() : "boot";
    }

    int SpawnTarget(double targetX, double targetY, String label,
        double radius = 8.0, int healthMilli = 1000000)
    {
        int slot = Allocate(ENEMY_KIND, targetX, targetY, 0.0, 0.0, healthMilli);
        if (slot < 0) return -1;
        collisionRadii[slot] = radius;
        Console.Printf("DS_P041_MAP27_TARGET slot=%d generation=%d stable_id=%d x=%.3f y=%.3f label=%s", slot, generations[slot], ids[slot], targetX, targetY, label);
        return slot;
    }

    int EquipWeapon(int systemId, int rank)
    {
        int weaponSlot = Allocate(WEAPON_KIND, playerX, playerY, 0.0, 0.0, 1);
        if (weaponSlot < 0) return -1;
        if (!DSP041EquipFixture(systemId, rank, weaponSlot, logicalTic))
            return -1;
        return dsp041WeaponSystems.Size() - 1;
    }

    void SetupWalls()
    {
        // A wall segment inside the boundary so reflection candidates can
        // be compared: wall crossing vs boundary crossing vs exact corner.
        DSP041AddLogicalWall(1, 60.0, -200.0, 60.0, 200.0);
    }

    bool Boot()
    {
        activeMode = ReadMode();
        tic = 0; logicalTic = 0; playerX = 0.0; playerY = 0.0;
        completed = false;
        pauseRequested = false; pauseOpened = false; pauseClosed = false;
        pauseStartLogicalTic = -1; pauseStartHash = 0;
        pauseResumeTic = -1; pauseResumeHash = 0;
        saveLogicalTic = -1; saveStateHash = 0; saveHold = false;
        weaponIndexRunetracer = -1; weaponIndexBone = -1;
        weaponIndexCherry = -1; weaponIndexCarrello = -1;
        weaponIndexNoFuture = -1;
        contactEnemySlot = -1; contactEnemyGeneration = 0; contactEnemyId = 0;
        weaponIndexA01Edge = -1; weaponIndexA01Wall = -1; weaponIndexA01Corner = -1;
        weaponIndexNoTunnel = -1; noTunnelTargetSlot = -1;
        capacityWeaponIndices.Clear();
        Reset();
        DSP024ClearSpatial();
        DSP041ResetBounceRuntime(410401);
        ConfigureCamera();
        playerSlot = Allocate(PLAYER_KIND, playerX, playerY, 0.0, 0.0, 1);
        collisionRadii[playerSlot] = 2.0;
        // Item 3 (NO FUTURE damage formula, >=2 Armor values): a
        // CONTROLLED_ENGINE_FIXTURE override so run_p041_bounce.py can drive
        // the same "no_future" mode across independent engine processes at
        // different Armor points. Defaults to the fixture's original flat 1
        // when unset, so every other mode is unaffected.
        int armorPoints = ReadNoFutureArmorOverride();
        DSP033SetBaseStats(1000, armorPoints, 120000, 1000);
        DSP033RecomputeFromRanks(0, 0, 0, 0);
        SetupWalls();
        finishAtTic = 120;
        bool setupOk = playerSlot >= 0;
        if (activeMode == "boot") { finishAtTic = 5; }
        else if (activeMode == "reflection") setupOk = setupOk && SetupReflection();
        else if (activeMode == "capacity") { setupOk = setupOk && SetupCapacity(); finishAtTic = 400; }
        // 22 tics is enough to observe every weapon's first contact (all
        // four land between tic 9 and tic 11 given these fixed launch
        // vectors/distances) but stops before a bounce weapon's reflected
        // path can loop back through the same target a second time --
        // repeated gated pierce-through hits over a much longer window are
        // exercised by the "capacity" mode/A03 validator instead.
        else if (activeMode == "pierce_vs_bounce") { setupOk = setupOk && SetupPierceVsBounce(); finishAtTic = 22; }
        else if (activeMode == "cherry_audit") { setupOk = setupOk && SetupCherryAudit(); finishAtTic = 300; }
        else if (activeMode == "no_future") { setupOk = setupOk && SetupNoFuture(); finishAtTic = 160; }
        else if (activeMode == "rebase") { setupOk = setupOk && SetupReflection(); finishAtTic = 90; }
        else if (activeMode == "pause") { setupOk = setupOk && SetupReflection(); finishAtTic = 90; }
        else if (activeMode == "save") { setupOk = setupOk && SetupSave(); finishAtTic = 200; }
        else if (activeMode == "a01") { setupOk = setupOk && SetupA01(); finishAtTic = 120; }
        else if (activeMode == "no_tunnel") { setupOk = setupOk && SetupNoTunnel(); finishAtTic = 60; }
        Console.Printf("DS_P041_MAP27_BOOT accepted=%d mode=%s player_slot=%d camera_variant=%d classification=CONTROLLED_ENGINE_FIXTURE", setupOk ? 1 : 0, activeMode, playerSlot, cameraVariant);
        return setupOk;
    }

    bool SetupReflection()
    {
        weaponIndexRunetracer = EquipWeapon(DSP041BounceRows.SYSTEM_RUNETRACER, 1);
        return weaponIndexRunetracer >= 0;
    }

    // A03: several independent weapon copies across every bounce-off/pierce
    // system, refired every tic their own cooldown allows, over a long
    // finishAtTic window, plus two stationary targets so pierce weapons also
    // accrue gated per-pair hits. Sized (empirically, via actual engine
    // runs) to clear >=200 total bounces well within the run.
    bool SetupCapacity()
    {
        capacityWeaponIndices.Clear();
        int runetracerA = EquipWeapon(DSP041BounceRows.SYSTEM_RUNETRACER, 8);
        int runetracerB = EquipWeapon(DSP041BounceRows.SYSTEM_RUNETRACER, 8);
        int boneA = EquipWeapon(DSP041BounceRows.SYSTEM_BONE, 8);
        int boneB = EquipWeapon(DSP041BounceRows.SYSTEM_BONE, 8);
        int cherryA = EquipWeapon(DSP041BounceRows.SYSTEM_CHERRY, 8);
        int carrelloA = EquipWeapon(DSP041BounceRows.SYSTEM_CARRELLO, 8);
        weaponIndexRunetracer = runetracerA;
        bool setupOk = runetracerA >= 0 && runetracerB >= 0 && boneA >= 0
            && boneB >= 0 && cherryA >= 0 && carrelloA >= 0;
        if (setupOk)
        {
            capacityWeaponIndices.Push(runetracerA);
            capacityWeaponIndices.Push(runetracerB);
            capacityWeaponIndices.Push(boneA);
            capacityWeaponIndices.Push(boneB);
            capacityWeaponIndices.Push(cherryA);
            capacityWeaponIndices.Push(carrelloA);
        }
        SpawnTarget(50.0, 50.0, "CAPACITY_TARGET_A", 6.0);
        SpawnTarget(-50.0, -50.0, "CAPACITY_TARGET_B", 6.0);
        return setupOk;
    }

    // A04: Runetracer and Carréllo (PiercesEnemies) versus Bone and Cherry
    // Bomb (BouncesOffEnemies), fired side-by-side along four CONTROLLED_LAUNCH
    // axes (90/180/270/225 degrees) chosen so none of the four paths cross
    // the shared fixture wall at x=60 -- each weapon's own target is the only
    // thing on its path, so pierce-vs-bounce behavior at that target is
    // never confused with a wall/boundary bounce.
    bool SetupPierceVsBounce()
    {
        weaponIndexRunetracer = EquipWeapon(DSP041BounceRows.SYSTEM_RUNETRACER, 4);
        weaponIndexCarrello = EquipWeapon(DSP041BounceRows.SYSTEM_CARRELLO, 4);
        weaponIndexBone = EquipWeapon(DSP041BounceRows.SYSTEM_BONE, 4);
        weaponIndexCherry = EquipWeapon(DSP041BounceRows.SYSTEM_CHERRY, 4);
        SpawnTarget(0.0, 96.0, "PVB_RUNETRACER_TARGET", 4.0);
        SpawnTarget(-96.0, 0.0, "PVB_CARRELLO_TARGET", 4.0);
        SpawnTarget(0.0, -96.0, "PVB_BONE_TARGET", 4.0);
        SpawnTarget(-67.882, -67.882, "PVB_CHERRY_TARGET", 4.0);
        return weaponIndexRunetracer >= 0 && weaponIndexCarrello >= 0
            && weaponIndexBone >= 0 && weaponIndexCherry >= 0;
    }

    // A01: three separate Runetracer fixtures, one per required geometry
    // case (boundary edge, wall segment, exact corner), fired with
    // CONTROLLED_LAUNCH yaws chosen so each case is clean -- the edge (90
    // degrees, +Y) and corner (135 degrees, -X/+Y) cases never cross the
    // shared wall at x=60; the wall case (0 degrees, +X) hits it directly.
    bool SetupA01()
    {
        weaponIndexA01Edge = EquipWeapon(DSP041BounceRows.SYSTEM_RUNETRACER, 1);
        weaponIndexA01Wall = EquipWeapon(DSP041BounceRows.SYSTEM_RUNETRACER, 1);
        weaponIndexA01Corner = EquipWeapon(DSP041BounceRows.SYSTEM_RUNETRACER, 1);
        return weaponIndexA01Edge >= 0 && weaponIndexA01Wall >= 0
            && weaponIndexA01Corner >= 0;
    }

    // High-speed no-tunnelling probe: a Runetracer projectile whose speed is
    // fixture-overridden to 4.5x BASE_SPEED_UNITS_PER_SECOND (>=27.8
    // units/tic) must still register a pierce hit on a small (radius 1)
    // target close to the origin and a later WALL reflection, proving the
    // swept segment-intersection sweep (not a per-tic endpoint sample) is
    // what resolves contacts.
    bool SetupNoTunnel()
    {
        weaponIndexNoTunnel = EquipWeapon(DSP041BounceRows.SYSTEM_RUNETRACER, 1);
        noTunnelTargetSlot = SpawnTarget(15.0, 0.0, "NO_TUNNEL_TARGET", 1.0);
        return weaponIndexNoTunnel >= 0 && noTunnelTargetSlot >= 0;
    }

    bool SetupCherryAudit()
    {
        weaponIndexCherry = EquipWeapon(DSP041BounceRows.SYSTEM_CHERRY, 6);
        return weaponIndexCherry >= 0;
    }

    // Item 3: NO FUTURE's explosion lands at wherever the live projectile
    // currently is when the player-hit gate opens (tic 40, then again at
    // tic 60), which after 40-60 tics of boundary bouncing at 19.2 u/tic is
    // not predictable in advance. Rather than guess that position, this
    // covers the entire +/-128 logical-boundary square with a dense grid of
    // stationary targets (spacing 30, reach = collisionRadius(6) +
    // explosionRadius(24) = 30 >= worst-case diagonal gap sqrt(15^2+15^2)
    // ~= 21.2), so the explosion always lands on at least one real target
    // no matter where the projectile actually is.
    bool SetupNoFuture()
    {
        weaponIndexNoFuture = EquipWeapon(DSP041BounceRows.SYSTEM_NO_FUTURE, 1);
        bool allOk = weaponIndexNoFuture >= 0;
        int firstSlot = -1;
        for (double gx = -120.0; gx <= 120.0; gx += 30.0)
        {
            for (double gy = -120.0; gy <= 120.0; gy += 30.0)
            {
                int slot = SpawnTarget(gx, gy, "NO_FUTURE_GRID", 6.0);
                allOk = allOk && slot >= 0;
                if (firstSlot < 0) firstSlot = slot;
            }
        }
        contactEnemySlot = firstSlot;
        if (contactEnemySlot >= 0)
        {
            contactEnemyGeneration = generations[contactEnemySlot];
            contactEnemyId = ids[contactEnemySlot];
        }
        return allOk && contactEnemySlot >= 0;
    }

    // Item 5 (save/load mid-bounce): a Bone weapon (BouncesOffEnemies)
    // launched straight at a nearby target so it produces an early ENEMY
    // bounce + hit, leaving that pair gated (a "pending hit delay") for the
    // full HIT_DELAY_TICS window while the projectile is still active and
    // mid-flight -- exactly the state the save must freeze and roundtrip.
    bool SetupSave()
    {
        weaponIndexBone = EquipWeapon(DSP041BounceRows.SYSTEM_BONE, 1);
        int slot = SpawnTarget(30.0, 0.0, "SAVE_MIDFLIGHT_TARGET", 4.0);
        contactEnemySlot = slot;
        if (slot >= 0)
        {
            contactEnemyGeneration = generations[slot];
            contactEnemyId = ids[slot];
        }
        return weaponIndexBone >= 0 && slot >= 0;
    }

    int ReadSaveSnapshotRequest()
    {
        CVar cvar = CVar.FindCVar("ds_p041_save_snapshot_request");
        return cvar != null && cvar.GetInt() != 0 ? 1 : 0;
    }

    void RunModeTic()
    {
        int cooldownMultiplierMilli = dsp033ResolvedValid
            ? DSP033Resolved(DSP033StatRules.STAT_COOLDOWN) : 1000;
        if (activeMode == "boot")
        {
            if (logicalTic == 1) EmitCompiledRows();
        }
        else if (activeMode == "reflection")
        {
            if (logicalTic == 1)
                DSP041FireVolley(weaponIndexRunetracer, logicalTic, 0,
                    cooldownMultiplierMilli, 1000);
        }
        else if (activeMode == "capacity")
        {
            // Refire every tic; DSP041FireVolley is a no-op while its own
            // cooldown gate is still closed, so this just lets every one of
            // the independent weapon copies refire as soon as it is able.
            for (int i = 0; i < capacityWeaponIndices.Size(); i++)
                DSP041FireVolley(capacityWeaponIndices[i], logicalTic, 0,
                    cooldownMultiplierMilli, 1000);
        }
        else if (activeMode == "pierce_vs_bounce")
        {
            if (logicalTic == 1)
            {
                DSP041FireVolley(weaponIndexRunetracer, logicalTic, 0,
                    cooldownMultiplierMilli, 1000, true, 90000);
                DSP041FireVolley(weaponIndexCarrello, logicalTic, 180000,
                    cooldownMultiplierMilli, 1000);
                DSP041FireVolley(weaponIndexBone, logicalTic, 0,
                    cooldownMultiplierMilli, 1000, true, 270000);
                DSP041FireVolley(weaponIndexCherry, logicalTic, 0,
                    cooldownMultiplierMilli, 1000, true, 225000);
            }
        }
        else if (activeMode == "a01")
        {
            if (logicalTic == 1)
            {
                DSP041FireVolley(weaponIndexA01Edge, logicalTic, 0,
                    cooldownMultiplierMilli, 1000, true, 90000);
                DSP041FireVolley(weaponIndexA01Wall, logicalTic, 0,
                    cooldownMultiplierMilli, 1000, true, 0);
                DSP041FireVolley(weaponIndexA01Corner, logicalTic, 0,
                    cooldownMultiplierMilli, 1000, true, 135000);
            }
        }
        else if (activeMode == "no_tunnel")
        {
            if (logicalTic == 1)
            {
                DSP041FireVolley(weaponIndexNoTunnel, logicalTic, 0,
                    cooldownMultiplierMilli, 1000, true, 0);
                // Fixture-only speed override: covers the "speed" half of
                // the no-tunnelling probe (CONTROLLED_LAUNCH above already
                // covers direction). Rewrites the just-spawned projectile's
                // own speed fields directly; production spawns never do
                // this and every other mode is unaffected.
                int lastIndex = dsp041Active.Size() - 1;
                if (lastIndex >= 0)
                {
                    double overrideSpeed = double(DSP041BounceRows.BASE_SPEED_UNITS_PER_SECOND) * 4.5;
                    dsp041SpeedUnitsPerSecond[lastIndex] = overrideSpeed;
                    dsp041SpeedInitialUnitsPerSecond[lastIndex] = overrideSpeed;
                    Console.Printf("DS_P041_NO_TUNNEL_OVERRIDE event_id=%d speed_ups=%.6f base_multiple_milli=4500 classification=CONTROLLED_ENGINE_FIXTURE", dsp041Events[lastIndex], overrideSpeed);
                }
            }
        }
        else if (activeMode == "cherry_audit")
        {
            if (logicalTic == 1)
                RunIsolatedCherryRngAudit();
            if (logicalTic % 20 == 1 && logicalTic <= 200)
                DSP041FireVolley(weaponIndexCherry, logicalTic, 0,
                    cooldownMultiplierMilli, 1000);
        }
        else if (activeMode == "no_future")
        {
            if (logicalTic == 1)
                DSP041FireVolley(weaponIndexNoFuture, logicalTic, 0,
                    cooldownMultiplierMilli, 1000);
            if (logicalTic == 40)
            {
                int armorPoints = dsp033ResolvedValid
                    ? DSP033Resolved(DSP033StatRules.STAT_ARMOR) : 1;
                DSP041NotifyPlayerContactDamage(logicalTic, armorPoints);
            }
            if (logicalTic == 45)
            {
                // Gate re-check: a second contact inside 18 tics must not
                // explode again.
                int armorPoints = dsp033ResolvedValid
                    ? DSP033Resolved(DSP033StatRules.STAT_ARMOR) : 1;
                DSP041NotifyPlayerContactDamage(logicalTic, armorPoints);
            }
            if (logicalTic == 60)
            {
                // Item 3: "a later notification exploding again" -- tic 60
                // is 20 tics after the tic-40 acceptance (gate re-opens at
                // 40+NO_FUTURE_GATE_TICS=58), so this call must be accepted
                // and explode a second time.
                int armorPoints = dsp033ResolvedValid
                    ? DSP033Resolved(DSP033StatRules.STAT_ARMOR) : 1;
                DSP041NotifyPlayerContactDamage(logicalTic, armorPoints);
            }
        }
        else if (activeMode == "rebase")
        {
            if (logicalTic == 1)
                DSP041FireVolley(weaponIndexRunetracer, logicalTic, 0,
                    cooldownMultiplierMilli, 1000, true, 0);
            if (logicalTic == 20)
            {
                // Both snapshots are taken within the same tic, immediately
                // either side of the rebase call itself, so the only
                // difference between them can be the rebase's own effect --
                // not that tic's own ordinary motion/aging (which happens
                // afterwards, in this same iteration's DSP041AdvanceTic).
                EmitProjectileSnapshot("PRE_REBASE", logicalTic);
                playerX += 96.0; playerY += 32.0;
                DSP041Rebase(96.0, 32.0, logicalTic);
                EmitProjectileSnapshot("POST_REBASE", logicalTic);
            }
        }
        else if (activeMode == "pause")
        {
            if (logicalTic == 1)
                DSP041FireVolley(weaponIndexRunetracer, logicalTic, 0,
                    cooldownMultiplierMilli, 1000);
        }
        else if (activeMode == "save")
        {
            if (logicalTic == 1)
                DSP041FireVolley(weaponIndexBone, logicalTic, 0,
                    cooldownMultiplierMilli, 1000, true, 0);
        }
    }

    // Seeded, isolated statistical audit of Cherry Bomb's stop-explosion
    // roll. This calls the REAL production roll function
    // (DSP041RollExplosionChanceOnState, the exact same formula
    // DSP041ResolveCherryStop uses via DSP041RollExplosionChance) at each
    // rank's explosion chance actually in the rows (40/50/60%), but against
    // a dedicated LOCAL audit-state variable, never the live dsp041BounceRng
    // gameplay stream (contract A08/item 8: "isolated from gameplay RNG").
    // luckMilli=1000 (neutral) so chanceMilli itself is the target rate.
    // This runs entirely within one tic so 10,000+ rolls per chance cost no
    // engine wall time.
    void RunOneCherryAuditChance(int chanceMilli, int trials, out int auditState)
    {
        int exploded = 0;
        for (int i = 0; i < trials; i++)
        {
            int rngBefore; int rngAfter; int rollMilli;
            bool didExplode = DSP041RollExplosionChanceOnState(auditState,
                chanceMilli, 1000, rngBefore, rngAfter, rollMilli);
            auditState = rngAfter;
            if (didExplode) exploded++;
        }
        double observedRate = double(exploded) / double(trials);
        double expectedRate = double(chanceMilli) / 1000.0;
        double deltaMilli = (observedRate - expectedRate) * 1000.0;
        Console.Printf("DS_P041_CHERRY_RNG_AUDIT chance_milli=%d trials=%d exploded=%d observed_rate_milli=%d expected_rate_milli=%d delta_milli=%.3f isolated_seed=1 rng_stream=ISOLATED_AUDIT_STATE production_function=DSP041RollExplosionChanceOnState", chanceMilli, trials, exploded, int(observedRate * 1000.0), chanceMilli, deltaMilli);
    }

    // Runs the whole audit against a dedicated audit-state variable that is
    // never dsp041BounceRng, then proves the live gameplay RNG state is
    // byte-identical before and after -- the audit truly never touched it.
    void RunIsolatedCherryRngAudit()
    {
        int liveRngBefore = dsp041BounceRng;
        int auditState = 900900901;
        RunOneCherryAuditChance(400, 10000, auditState);
        RunOneCherryAuditChance(500, 10000, auditState);
        RunOneCherryAuditChance(600, 10000, auditState);
        int liveRngAfter = dsp041BounceRng;
        Console.Printf("DS_P041_CHERRY_RNG_AUDIT_LIVE_STATE live_rng_before=%d live_rng_after=%d unchanged=%d", liveRngBefore, liveRngAfter, liveRngBefore == liveRngAfter ? 1 : 0);
    }

    // Rebase (item 5) direct-state proof: prints every live projectile's own
    // age/bounce/hit counters (not just the combined persistence hash) so
    // the validator can assert they are byte-identical across
    // DSP041Rebase, independent of the position change it does make.
    void EmitProjectileSnapshot(String label, int logicalTic)
    {
        for (int i = 0; i < dsp041Active.Size(); i++)
        {
            if (dsp041Active[i] == 0) continue;
            Console.Printf("DS_P041_MAP27_SNAPSHOT label=%s tic=%d event_id=%d age_tics=%d bounce_count=%d hit_count=%d x=%.3f y=%.3f", label, logicalTic, dsp041Events[i], dsp041AgeTics[i], dsp041BounceCount[i], dsp041HitCount[i], dsp041X[i], dsp041Y[i]);
        }
    }

    int EmitRowsForSystem(int systemId)
    {
        int rankCount = DSP041BounceRows.RankCount(systemId);
        int rowCount = 0;
        {
            for (int rank = 1; rank <= rankCount; rank++)
            {
                rowCount++;
                Console.Printf("DS_P041_MAP27_ROW system_id=%d rank=%d damage_milli=%d area_milli=%d speed_milli=%d amount=%d duration_tics=%d cooldown_tics=%d child_interval_tics=%d hit_delay_tics=%d contact_radius_milli=%d explosion_chance_milli=%d explosion_radius_milli=%d bounce_budget=%d pierces_enemies=%d bounces_off_enemies=%d fixture=COMPILED_JSON_MIRROR", systemId, rank, DSP041BounceRows.DamageMilli(systemId, rank), DSP041BounceRows.AreaMilli(systemId, rank), DSP041BounceRows.SpeedMilli(systemId, rank), DSP041BounceRows.Amount(systemId, rank), DSP041BounceRows.DurationTics(systemId, rank), DSP041BounceRows.CooldownTics(systemId, rank), DSP041BounceRows.ChildIntervalTics(systemId, rank), DSP041BounceRows.HitDelayTics(systemId, rank), DSP041BounceRows.ContactRadiusMilliUnits(systemId, rank), DSP041BounceRows.ExplosionChanceMilli(systemId, rank), DSP041BounceRows.ExplosionRadiusMilliUnits(systemId, rank), DSP041BounceRows.BounceBudget(systemId, rank), DSP041BounceRows.PiercesEnemies(systemId) ? 1 : 0, DSP041BounceRows.BouncesOffEnemies(systemId) ? 1 : 0);
            }
        }
        return rowCount;
    }

    int EmitCompiledRows()
    {
        int rowCount = 0;
        rowCount += EmitRowsForSystem(DSP041BounceRows.SYSTEM_RUNETRACER);
        rowCount += EmitRowsForSystem(DSP041BounceRows.SYSTEM_NO_FUTURE);
        rowCount += EmitRowsForSystem(DSP041BounceRows.SYSTEM_BONE);
        rowCount += EmitRowsForSystem(DSP041BounceRows.SYSTEM_CHERRY);
        rowCount += EmitRowsForSystem(DSP041BounceRows.SYSTEM_CARRELLO);
        Console.Printf("DS_P041_MAP27_ROW_COUNT rows=%d", rowCount);
        return rowCount;
    }

    void EmitCompleteAndFinish()
    {
        int hash = DSP041PersistenceHash();
        Console.Printf("DS_P041_MAP27_COMPLETE mode=%s tic=%d emitted=%d skipped=%d accepted_hits=%d rejected_hits=%d hash=%d camera_variant=%d classification=CONTROLLED_ENGINE_FIXTURE", activeMode, logicalTic, dsp041EmittedProjectiles, dsp041SkippedProjectiles, dsp041AcceptedHits, dsp041RejectedHits, hash, cameraVariant);
        LevelLocals.MakeScreenShot();
        completed = true;
    }

    // Deliberately no WorldLoaded override for the restore leg: this is the
    // same lesson already recorded in GlobalMap26Runtime.zs (see its
    // `transient bool startedThisProcess` and DS_P040_MAP26_RESTORE) --
    // WorldLoaded's own e.IsSaveGame timing is not reliable here. Instead
    // WorldTick below detects "the first tick this OS process has run"
    // itself via a `transient` field (never serialized, so it always comes
    // back false in the freshly-started restore process even though every
    // ordinary field WAS restored) and emits the RESTORE marker there.

    // ---- Native pause bridge (mirrors P040's MAP26 pattern exactly; see
    // GlobalMap26Runtime.zs) ------------------------------------------------

    override void UiTick()
    {
        uiTics++;
        if (uiPauseMode == 0) return;
        if (!uiPauseRequestSent && uiLogicalTic >= 5
            && !Level.WorldPaused() && Menu.GetCurrentMenu() == null)
        {
            uiPauseRequestSent = true;
            uiPauseAtTic = uiLogicalTic;
            SendNetworkEvent("P041_MAP27_PAUSE_REQUEST", uiLogicalTic, uiPauseHash, uiTics);
            Menu.SetMenu('MainMenu');
        }
        else if (uiPauseRequestSent && !uiPauseObserved && Level.WorldPaused())
        {
            uiPauseObserved = true;
            uiPauseUntilUiTic = uiTics + 35;
            SendNetworkEvent("P041_MAP27_PAUSE_HELD", uiLogicalTic, uiPauseHash, uiTics);
        }
        else if (uiPauseObserved && !uiPauseResumeSent && uiTics >= uiPauseUntilUiTic)
        {
            Menu menu = Menu.GetCurrentMenu();
            if (menu != null) menu.Close();
            if (!Level.WorldPaused())
            {
                uiPauseResumeSent = true;
                SendNetworkEvent("P041_MAP27_RESUME", uiLogicalTic, uiPauseHash, uiTics);
            }
        }
    }

    override void InterfaceProcess(ConsoleEvent e)
    {
        if (e.Name == "P041_MAP27_UI_RESET")
        {
            uiPauseRequestSent = false; uiPauseObserved = false; uiPauseResumeSent = false;
            uiTics = 0; uiLogicalTic = 0; uiPauseHash = 0;
            uiPauseAtTic = -1; uiPauseUntilUiTic = 0; uiPauseMode = 0;
        }
        else if (e.Name == "P041_MAP27_UI_STATE")
        {
            uiLogicalTic = e.Args[0];
            uiPauseHash = e.Args[1];
            uiPauseMode = e.Args[2];
        }
    }

    override void NetworkProcess(ConsoleEvent e)
    {
        if (e.Player != consoleplayer) return;
        if (e.Name == "P041_MAP27_PAUSE_REQUEST")
        {
            pauseRequested = true;
            pauseStartLogicalTic = e.Args[0];
            pauseStartHash = e.Args[1];
            Console.Printf("DS_P041_MAP27_PAUSE_START logical_tic=%d state_hash=%d ui_tic=%d requested_native_pause=1", pauseStartLogicalTic, pauseStartHash, e.Args[2]);
        }
        else if (e.Name == "P041_MAP27_PAUSE_HELD")
        {
            pauseOpened = true;
            Console.Printf("DS_P041_MAP27_PAUSE_HELD logical_tic=%d state_hash=%d ui_tic=%d world_paused=1", e.Args[0], e.Args[1], e.Args[2]);
        }
        else if (e.Name == "P041_MAP27_RESUME")
        {
            pauseClosed = true;
            pauseResumeTic = e.Args[0];
            pauseResumeHash = e.Args[1];
            bool stable = pauseOpened && pauseStartLogicalTic == pauseResumeTic
                && pauseStartHash == pauseResumeHash;
            Console.Printf("DS_P041_MAP27_PAUSE_END accepted=%d world_logical_tic=%d start_world_logical_tic=%d ui_tics=%d start_hash=%d end_hash=%d", stable ? 1 : 0, pauseResumeTic, pauseStartLogicalTic, e.Args[2], pauseStartHash, pauseResumeHash);
        }
    }

    override void WorldTick()
    {
        // Globally registered: never boot (camera/FOV writes, fixture
        // entities) on any other map (same defect as MAP28, found 2026-09-28).
        if (level == null || level.MapName != "MAP27") return;
        if (!started)
        {
            started = Boot();
            enabled = started;
        }
        if (!enabled || completed) return;

        // Item 5 save/load restore detection: firstTickThisProcess is true
        // exactly once -- the very first WorldTick this OS process has ever
        // run. In a fresh (non-save) start that is tic 1 (logicalTic still
        // 0 at this point, so the "> 0" guard below skips it); in a
        // restored process every ordinary field (logicalTic, the save
        // hash, every projectile array) already holds its persisted value
        // from before the save, so this is exactly the load-continuation
        // point.
        bool firstTickThisProcess = !startedThisProcess;
        startedThisProcess = true;
        if (firstTickThisProcess && logicalTic > 0)
        {
            int hashNow = DSP041PersistenceHash();
            bool exact = hashNow == saveStateHash;
            bool pendingHitDelay = false;
            bool midFlight = false;
            for (int i = 0; i < dsp041Active.Size(); i++)
            {
                if (dsp041Active[i] == 0 || dsp041Systems[i] != DSP041BounceRows.SYSTEM_BONE) continue;
                midFlight = true;
                if (dsp041HitCount[i] >= 1
                    && DSP041IsPairGated(dsp041Events[i], contactEnemySlot,
                        contactEnemyGeneration, contactEnemyId, logicalTic))
                    pendingHitDelay = true;
            }
            Console.Printf("DS_P041_MAP27_RESTORE first_tick=1 tic=%d hash=%d continuation=1 pending_hit_delay=%d mid_flight=%d exact_hash=%d", logicalTic, hashNow, pendingHitDelay ? 1 : 0, midFlight ? 1 : 0, exact ? 1 : 0);
        }

        // Item 5 save/load: the restore leg clears the cvar to unfreeze;
        // checked before the frozen-return below so the SAME tic that
        // unfreezes also resumes normal processing (mirrors P040's
        // GlobalMap26Runtime.WorldTick exactly).
        if (activeMode == "save" && saveHold && ReadSaveSnapshotRequest() == 0)
            saveHold = false;
        if (activeMode == "save" && saveHold)
            return; // frozen: no world/logical progress at all while held

        // Once-per-tic broad-phase rebuild (same convention as every other
        // P024-consuming fixture, e.g. GlobalMap26Runtime/AuraMap25Runtime):
        // without this, targets Allocate()'d in Setup* are never actually
        // reachable by DSP024SweptCandidates and every pierce/enemy-bounce
        // path silently sees zero candidates.
        DSP024Rebuild();
        RunModeTic();
        DSP041AdvanceTic(logicalTic);
        SendInterfaceEvent(consoleplayer, "P041_MAP27_UI_STATE", logicalTic,
            DSP041PersistenceHash(), activeMode == "pause" ? 1 : 0);

        if (activeMode == "save" && !saveHold)
        {
            // Freeze only once the SAVE_MIDFLIGHT_TARGET pair has actually
            // been hit (pending hit-delay gate live) and the Bone projectile
            // is still active (mid-flight) -- i.e. a real save must land on
            // exactly that state, not merely be requested at any tic.
            bool pendingHitDelay = false;
            bool midFlight = false;
            int liveIndex = -1;
            for (int i = 0; i < dsp041Active.Size(); i++)
            {
                if (dsp041Active[i] == 0 || dsp041Systems[i] != DSP041BounceRows.SYSTEM_BONE) continue;
                midFlight = true;
                liveIndex = i;
                if (dsp041HitCount[i] >= 1
                    && DSP041IsPairGated(dsp041Events[i], contactEnemySlot,
                        contactEnemyGeneration, contactEnemyId, logicalTic))
                    pendingHitDelay = true;
            }
            if (midFlight && pendingHitDelay && ReadSaveSnapshotRequest() == 1)
            {
                saveHold = true;
                // logicalTic itself still increments once more below (this
                // tic's own advance completes normally; only LATER ticks
                // are skipped by the saveHold early-return above), so the
                // value actually persisted to the save file is
                // logicalTic+1 -- log that value here, not the pre-increment
                // one, so the restore leg's own logicalTic matches exactly.
                saveLogicalTic = logicalTic + 1;
                saveStateHash = DSP041PersistenceHash();
                Console.Printf("DS_P041_MAP27_SAVE_FROZEN accepted=1 tic=%d hash=%d pending_hit_delay=1 mid_flight=1", saveLogicalTic, saveStateHash);
                // Item 5: exact frozen kinematic state, so an independent
                // Python reference (reference_reflect_path) can predict the
                // NEXT bounce from this exact resumption point rather than
                // only proving "some bounce happened" after restore.
                if (liveIndex >= 0)
                    Console.Printf("DS_P041_MAP27_SAVE_STATE event_id=%d x=%.6f y=%.6f dir_x=%.6f dir_y=%.6f speed_ups=%.6f age_tics=%d duration_tics=%d", dsp041Events[liveIndex], dsp041X[liveIndex], dsp041Y[liveIndex], dsp041DirX[liveIndex], dsp041DirY[liveIndex], dsp041SpeedUnitsPerSecond[liveIndex], dsp041AgeTics[liveIndex], dsp041DurationTics[liveIndex]);
            }
        }
        logicalTic++;
        tic++;
        if (tic >= finishAtTic) EmitCompleteAndFinish();
    }
}
