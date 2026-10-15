// Cosmetic strike/erase flash. Never a broad-phase input and cannot create,
// resize or change a hit; toggling it off (ds_p040_vfx) must never change
// the DS_P040_* accepted-hit/erase tuples this fixture proves -- modelled on
// DSP039Map25RingProxy.
class DSP040Map26BoltProxy : Actor
{
    Default
    {
        Radius 4;
        Height 4;
        +NOBLOCKMAP;
        +NOGRAVITY;
        +NOINTERACTION;
        RenderStyle "Add";
        Alpha 0.7;
        Scale 0.2;
    }

    States
    {
    Spawn:
        PROP A 3 Bright;
        Stop;
    }
}

// MAP26 host for the P040 logical-screen strike, erasure and global-effect
// authority (docs/contracts/global-strikes.md). Weapons, P033 inputs,
// targets and timing are controlled fixtures. P025/DSP040Global own
// accepted logical damage/erasure, unconditionally logged through the
// DS_P040_* markers; the bolt proxy above is a presentation-only mirror of
// "a strike or erasure happened this tic" and is never consulted by any
// targeting, hit or erasure decision.
class DSP040Map26Runtime : EventHandler
{
    mixin DSRunStatFields;
    mixin DSP020EntityStore;
    mixin DSP024SpatialIndex;
    mixin DSP025AttackCore;
    mixin DSP027ExperienceStore;
    mixin DSP033ResolvedStats;
    mixin DSP040Global;

    const MAP = "MAP26";
    const ENEMY_KIND = 1;
    const PLAYER_KIND = 99;
    const WEAPON_KIND = 90;
    const REGION_HALF = 128;

    bool enabled;
    bool completed;
    transient bool startedThisProcess;
    bool saveHold;
    bool saveSnapshotEmitted;
    bool restoredStateReported;
    bool pauseRequested;
    bool pauseOpened;
    bool pauseClosed;
    ui bool uiPauseRequestSent;
    ui bool uiPauseObserved;
    ui bool uiPauseResumeSent;
    ui int uiTics;
    ui int uiLogicalTic;
    ui int uiPauseHash;
    ui int uiPauseAtTic;
    ui int uiPauseUntilUiTic;
    ui int uiPauseMode;
    int pauseStartLogicalTic;
    int pauseStartHash;
    int pauseResumeTic;
    int pauseResumeHash;
    int saveLogicalTic;
    int saveStateHash;
    int finishAtTic;
    int tic;
    int cameraVariant;
    int visualToggle;
    int lastVfxEventTotal;
    int playerSlot;
    String activeMode;
    double playerX;
    double playerY;

    // Named handles used by individual proof points; -1 when unused.
    int lightningWeaponSlot; int lightningWeaponGeneration; int lightningWeaponId;
    int pentagramWeaponSlot; int pentagramWeaponGeneration; int pentagramWeaponId;
    int moonWeaponSlot; int moonWeaponGeneration; int moonWeaponId;
    int protectedSlot; int protectedGeneration; int protectedId;
    int erasedTargetSlot; int erasedTargetGeneration; int erasedTargetId;
    int killTargetSlot; int killTargetGeneration; int killTargetId;
    int boundaryInSlot; int boundaryOutSlot;
    int movingPickupSlot; int movingPickupGeneration; int movingPickupId;
    int growthTestSlot; int growthTestGeneration; int growthTestId;
    int repeatEnemySlot; int repeatEnemyGeneration; int repeatEnemyId;
    bool transformDone;
    bool repeatFixtureSpawned;
    int killsWithXp;
    int erasuresWithoutXp;

    // target_audit fixed candidate pool (stable IDs, in spawn order).
    Array<int> auditPoolIds;

    override void OnRegister()
    {
        // See AuraMap25Runtime.zs's own note: registered globally, but a UI
        // pause probe belongs only to MAP26 -- claiming UI ownership
        // elsewhere would suppress native commands on the normal MAP16
        // playable slice (the P030 input-ownership defect class).
        IsUiProcessor = false;
        RequireMouse = false;
    }

    void HandleEnemyDeath(int slot, int beforeHealth, int eventId)
    {
        if (!ValidParts(slot, generations[slot], ids[slot])) return;
        // Ordinary kill path: exactly one XP drop request per kill, through
        // the same P027 store this fixture composes -- the contrast point
        // against DSP040EraseEnemy, which never reaches this method.
        DSP027ExperienceHandle handle;
        bool created = DSP027CreatePickup(1000, x[slot], y[slot], eventId, handle);
        if (created) killsWithXp++;
        Console.Printf("DS_P040_MAP26_DEATH event_id=%d tic=%d target_id=%d before=%d xp_created=%d", eventId, tic, ids[slot], beforeHealth, created ? 1 : 0);
        DestroyParts(slot, generations[slot], ids[slot]);
    }

    int ReadCameraVariant()
    {
        // Matches run_p039_aura.py's own camera-variant contract: 0=neutral
        // pose/narrow FOV, 1=wide FOV, 2=180-degree yaw. ds_p040_vfx (read
        // separately below) is the REAL, independent flash/bolt-proxy
        // toggle -- not a fourth camera variant/stand-in.
        CVar camera = CVar.FindCVar("ds_p040_camera_variant");
        int value = camera != null ? camera.GetInt() : 0;
        return value >= 0 && value <= 2 ? value : 0;
    }

    int ReadVisualToggle()
    {
        CVar cvar = CVar.FindCVar("ds_p040_vfx");
        return cvar != null && cvar.GetInt() != 0 ? 1 : 0;
    }

    void ConfigureCamera()
    {
        cameraVariant = ReadCameraVariant();
        visualToggle = ReadVisualToggle();
        int yaw = cameraVariant == 2 ? 180 : 0;
        int fov = cameraVariant == 1 ? 120 : 90;
        if (players[0].mo != null)
        {
            players[0].mo.Angle = yaw;
            players[0].SetFOV(fov);
        }
        Console.Printf("DS_P040_MAP26_CAMERA variant=%d yaw=%d fov=%d vfx=%d source=UZDOOM_PLAYER_VIEW gameplay_ignored=1", cameraVariant, yaw, fov, visualToggle);
    }

    // Spawns one cosmetic bolt proxy at the player's logical position when
    // this tic's accepted-hit/erase/beam counters moved and ds_p040_vfx is
    // on; a pure mirror of "something happened," never read by any decision.
    void SyncBoltProxy()
    {
        int total = dsp040AcceptedHits + dsp040ErasedEnemies + dsp040MoonBeamHits
            + dsp040ThunderRepeatsFired;
        bool changed = total != lastVfxEventTotal;
        lastVfxEventTotal = total;
        if (visualToggle == 0 || !changed) return;
        double engineX; double engineY;
        DSP020GroundPlane.ToEngine(playerX, playerY, 0.0, 0.0, engineX, engineY);
        Actor.Spawn("DSP040Map26BoltProxy", (engineX, engineY, 24.0), NO_REPLACE);
    }

    int SpawnTarget(double targetX, double targetY, String role,
        double targetRadius = 8.0, int healthMilli = 1000000000)
    {
        int slot = Allocate(ENEMY_KIND, targetX, targetY, 0.0, 0.0, healthMilli);
        if (slot < 0) return -1;
        collisionRadii[slot] = targetRadius;
        Console.Printf("DS_P040_MAP26_TARGET target_id=%d x=%.3f y=%.3f radius=%.3f health_milli=%d role=%s classification=CONTROLLED_CONTACT_TARGET source_spawn_claim=0", ids[slot], targetX, targetY, targetRadius, healthMilli, role);
        return slot;
    }

    bool EquipStrikeWeapon(int systemId, int rank, out int weaponSlot,
        out int weaponGeneration, out int weaponId)
    {
        weaponSlot = Allocate(WEAPON_KIND, playerX, playerY, 0.0, 0.0, 1);
        weaponGeneration = generations[weaponSlot];
        weaponId = ids[weaponSlot];
        bool accepted = DSP040EquipStrike(systemId, rank, weaponSlot,
            weaponGeneration, weaponId, 1, playerSlot, generations[playerSlot],
            ids[playerSlot], dsp033ResolvedMightMilli,
            dsp033ResolvedCooldownMultiplierMilli, tic);
        Console.Printf("DS_P040_MAP26_WEAPON accepted=%d kind=STRIKE system_id=%d rank=%d weapon_id=%d", accepted ? 1 : 0, systemId, rank, weaponId);
        return accepted;
    }

    bool EquipEraseWeapon(int systemId, int rank, out int weaponSlot,
        out int weaponGeneration, out int weaponId)
    {
        weaponSlot = Allocate(WEAPON_KIND, playerX, playerY, 0.0, 0.0, 1);
        weaponGeneration = generations[weaponSlot];
        weaponId = ids[weaponSlot];
        bool accepted = DSP040EquipPentagram(systemId, rank, weaponSlot,
            weaponGeneration, weaponId, 1, playerSlot, generations[playerSlot],
            ids[playerSlot], dsp033ResolvedCooldownMultiplierMilli, tic);
        Console.Printf("DS_P040_MAP26_WEAPON accepted=%d kind=ERASE system_id=%d rank=%d weapon_id=%d", accepted ? 1 : 0, systemId, rank, weaponId);
        return accepted;
    }

    // ---- Scenario setup -----------------------------------------------------

    bool StartScenario()
    {
        CVar modeCVar = CVar.FindCVar("ds_p040_mode");
        activeMode = modeCVar != null ? modeCVar.GetString() : "matrix";
        if (activeMode != "matrix" && activeMode != "camera"
            && activeMode != "pause" && activeMode != "save"
            && activeMode != "spare_audit" && activeMode != "mass"
            && activeMode != "target_audit")
        {
            Console.Printf("DS_ASSERT_FAIL P040_MAP26_MODE_UNSUPPORTED mode=%s", activeMode);
            return false;
        }
        tic = 0; playerX = 0.0; playerY = 0.0;
        completed = false; saveHold = false; saveSnapshotEmitted = false;
        restoredStateReported = false;
        pauseRequested = false; pauseOpened = false; pauseClosed = false;
        pauseStartLogicalTic = -1; pauseStartHash = 0;
        pauseResumeTic = -1; pauseResumeHash = 0;
        SendInterfaceEvent(consoleplayer, "P040_MAP26_UI_RESET", 0, 0, 0);
        saveLogicalTic = -1; saveStateHash = 0;
        lightningWeaponSlot = -1; pentagramWeaponSlot = -1; moonWeaponSlot = -1;
        protectedSlot = -1; erasedTargetSlot = -1; killTargetSlot = -1;
        boundaryInSlot = -1; boundaryOutSlot = -1; movingPickupSlot = -1;
        growthTestSlot = -1; repeatEnemySlot = -1;
        transformDone = false; repeatFixtureSpawned = false;
        killsWithXp = 0; erasuresWithoutXp = 0;
        auditPoolIds.Clear();
        lastVfxEventTotal = 0;
        Reset();
        DSP024ClearSpatial();
        DSP027ResetExperience();
        DSP040ResetGlobal();
        DSP040SeedStrikeRng(400401);
        DSP040SeedEraseRng(400402);
        ConfigureCamera();
        playerSlot = Allocate(PLAYER_KIND, playerX, playerY, 0.0, 0.0, 1);
        collisionRadii[playerSlot] = 2.0;
        DSP033SetBaseStats(1000, 0, 120000, 1000);
        bool statsOk = DSP033RecomputeFromRanks(0, 0, 0, 0);
        DSP033RecomputeAmountGrowth(2, 5); // Duplicator rank2 (+1 Amount), Crown rank5 (+400 milli Growth)
        finishAtTic = 400;
        bool setupOk = statsOk && playerSlot >= 0;
        if (activeMode == "matrix" || activeMode == "camera")
            setupOk = setupOk && SetupMatrixFixtures();
        else if (activeMode == "pause" || activeMode == "save")
            setupOk = setupOk && SetupSaveFixtures();
        else if (activeMode == "spare_audit")
            finishAtTic = 5; // the audit itself runs synchronously in tic 1
        else if (activeMode == "mass")
            setupOk = setupOk && SetupMassFixtures();
        else if (activeMode == "target_audit")
        {
            setupOk = setupOk && SetupTargetAuditFixtures();
            finishAtTic = 5; // the audit itself runs synchronously in tic 1
        }
        if (activeMode == "pause") finishAtTic = 90;
        if (activeMode == "save") finishAtTic = 60;
        Console.Printf("DS_P040_MAP26_BOOT accepted=%d mode=%s player_slot=%d classification=CONTROLLED_ENGINE_FIXTURE", setupOk ? 1 : 0, activeMode, playerSlot);
        return setupOk;
    }

    bool SetupMatrixFixtures()
    {
        bool ok = true;
        // Region boundary: inclusive at exactly +/-128, exclusive just past.
        boundaryInSlot = SpawnTarget(double(REGION_HALF), 0.0, "REGION_BOUNDARY_INCLUSIVE", 4.0);
        boundaryOutSlot = SpawnTarget(double(REGION_HALF) + 1.0, 0.0, "REGION_BOUNDARY_EXCLUSIVE", 4.0);
        ok = ok && boundaryInSlot >= 0 && boundaryOutSlot >= 0;

        // Uniform selection: 10 enemies spread around the player so a
        // strikeCount of 7 (row Amount 6 + Duplicator resolved 1) must pick
        // 7 distinct targets with no repeats in one activation.
        for (int i = 0; i < 10; i++)
        {
            double angle = double(i) * 36.0 * 3.14159265 / 180.0;
            SpawnTarget(60.0 * cos(angle), 60.0 * sin(angle), "UNIFORM_SELECTION_POOL", 4.0);
        }

        // Kill-vs-erase contrast: a weak enemy killed by a strike (XP
        // created), and a separate enemy erased by Pentagram (no XP).
        killTargetSlot = SpawnTarget(30.0, 30.0, "STRIKE_KILL_TARGET", 4.0, 1000);
        killTargetGeneration = generations[killTargetSlot];
        killTargetId = ids[killTargetSlot];
        erasedTargetSlot = SpawnTarget(-30.0, -30.0, "PENTAGRAM_ERASE_TARGET", 4.0);
        erasedTargetGeneration = generations[erasedTargetSlot];
        erasedTargetId = ids[erasedTargetSlot];
        ok = ok && killTargetSlot >= 0 && erasedTargetSlot >= 0;

        // Protected enemy: exempt from Pentagram erasure, but still takes
        // ordinary strike damage.
        protectedSlot = SpawnTarget(-40.0, 40.0, "PROTECTED_FROM_ERASURE", 4.0);
        protectedGeneration = generations[protectedSlot];
        protectedId = ids[protectedSlot];
        ok = ok && protectedSlot >= 0;
        if (ok) DSP040SetProtected(protectedSlot, protectedGeneration, protectedId, true);

        // Moving pickup for Pentagram's roll (contract: "including gems
        // already moving toward the player").
        DSP027ExperienceHandle handle;
        if (DSP027CreatePickup(1000, 90.0, 0.0, 1, handle))
        {
            movingPickupSlot = handle.slot; movingPickupGeneration = handle.generation;
            movingPickupId = handle.stableId;
            DSP027ForceAttract(movingPickupSlot, movingPickupGeneration, movingPickupId);
        }
        ok = ok && movingPickupSlot >= 0;

        // Growth-at-collection: a second pickup collected with a non-zero
        // Growth resolution to prove the base/bonus split.
        if (DSP027CreatePickup(1000, 100.0, 0.0, 2, handle))
        {
            growthTestSlot = handle.slot; growthTestGeneration = handle.generation;
            growthTestId = handle.stableId;
        }
        ok = ok && growthTestSlot >= 0;

        // Lightning Ring rank8 (with Duplicator resolved via
        // DSP033RecomputeAmountGrowth above) -- transforms into Thunder Loop
        // partway through the run.
        ok = ok && EquipStrikeWeapon(DSP040GlobalRows.SYSTEM_LIGHTNING, 8,
            lightningWeaponSlot, lightningWeaponGeneration, lightningWeaponId);

        // Pentagram rank8 (spare_milli=650) with Crown resolved -- transforms
        // into Gorgeous Moon partway through the run.
        ok = ok && EquipEraseWeapon(DSP040GlobalRows.SYSTEM_PENTAGRAM, 8,
            pentagramWeaponSlot, pentagramWeaponGeneration, pentagramWeaponId);

        return ok;
    }

    bool SetupMassFixtures()
    {
        for (int i = 0; i < 520; i++)
        {
            double angle = double(i) * 0.6180339887 * 6.28318530718;
            double radius = 20.0 + double(i % 100);
            SpawnTarget(radius * cos(angle), radius * sin(angle), "MASS_ENEMY", 4.0, 1000);
        }
        DSP027ExperienceHandle handle;
        int created = 0;
        for (int i = 0; i < 210; i++)
        {
            double angle = double(i) * 0.7548776662 * 6.28318530718;
            double radius = 10.0 + double(i % 120);
            if (DSP027CreatePickup(1000, radius * cos(angle), radius * sin(angle), 3, handle))
                created++;
        }
        bool weaponOk = EquipStrikeWeapon(DSP040GlobalRows.SYSTEM_LIGHTNING, 8,
            lightningWeaponSlot, lightningWeaponGeneration, lightningWeaponId)
            && EquipEraseWeapon(DSP040GlobalRows.SYSTEM_PENTAGRAM, 8,
                pentagramWeaponSlot, pentagramWeaponGeneration, pentagramWeaponId);
        Console.Printf("DS_P040_MAP26_MASS_SETUP enemies=520 pickups_created=%d weapons_ok=%d", created, weaponOk ? 1 : 0);
        return weaponOk && created == 210;
    }

    // ---- save/pause dedicated fixture: designed so a Thunder Loop repeat
    // AND a Gorgeous Moon phase-2 are BOTH outstanding from shortly after
    // tic=1 (their shared first-activation tic) until tic=19 and tic=36
    // respectively -- a wide, generous save/pause window rather than a
    // single exact tic. Equips Thunder Loop and Gorgeous Moon directly
    // (bypassing the Lightning/Pentagram transform edges, which "matrix"
    // mode already proves) so this fixture stays simple and independent of
    // Pentagram's region-wide first-activation wipe.

    bool SetupSaveFixtures()
    {
        for (int i = 0; i < 5; i++)
            SpawnTarget(30.0 + double(i) * 6.0, 0.0, "SAVE_THUNDER_POOL", 4.0, 1000000000);
        for (int i = 0; i < 8; i++)
            SpawnTarget(-40.0 - double(i) * 6.0, 0.0, "SAVE_MOON_POOL", 4.0, 500);
        int loopSlot; int loopGeneration; int loopId;
        int moonSlot; int moonGeneration; int moonId;
        bool loopOk = EquipStrikeWeapon(DSP040GlobalRows.SYSTEM_THUNDER_LOOP, 1,
            loopSlot, loopGeneration, loopId);
        lightningWeaponSlot = loopSlot; lightningWeaponGeneration = loopGeneration;
        lightningWeaponId = loopId;
        bool moonOk = EquipEraseWeapon(DSP040GlobalRows.SYSTEM_GORGEOUS_MOON, 1,
            moonSlot, moonGeneration, moonId);
        moonWeaponSlot = moonSlot; moonWeaponGeneration = moonGeneration;
        moonWeaponId = moonId;
        return loopOk && moonOk;
    }

    void RunSaveTimeline()
    {
        int amountResolved = DSP033AmountApplies(DSP040GlobalRows.SYSTEM_THUNDER_LOOP)
            ? DSP033Resolved(DSP033StatRules.STAT_AMOUNT) : 0;
        DSP040ProcessStrikeTic(tic, playerX, playerY, amountResolved);
        DSP040ProcessEraseTic(tic, playerX, playerY, DSP040GlobalRows.LUCK_BASE_MILLI, amountResolved);
    }

    bool SetupTargetAuditFixtures()
    {
        auditPoolIds.Clear();
        for (int i = 0; i < 20; i++)
        {
            double angle = double(i) * 18.0 * 3.14159265 / 180.0;
            int slot = SpawnTarget(100.0 * cos(angle), 100.0 * sin(angle), "TARGET_AUDIT_POOL", 4.0, 1000000000);
            if (slot < 0) return false;
            auditPoolIds.Push(ids[slot]);
        }
        return EquipStrikeWeapon(DSP040GlobalRows.SYSTEM_LIGHTNING, 8,
            lightningWeaponSlot, lightningWeaponGeneration, lightningWeaponId);
    }

    // ---- Seeded strike-target-selection audit (production selection code,
    // isolated run: no other weapon or gameplay RNG activity this process) --

    void RunTargetAudit()
    {
        int ACTIVATIONS = 3000;
        int amountResolved = DSP033AmountApplies(DSP040GlobalRows.SYSTEM_LIGHTNING)
            ? DSP033Resolved(DSP033StatRules.STAT_AMOUNT) : 0;
        int rowAmount = DSP040GlobalRows.Amount(DSP040GlobalRows.SYSTEM_LIGHTNING, 8);
        int strikeCount = rowAmount + amountResolved; // 6 + 1 = 7
        int poolSize = auditPoolIds.Size();
        Array<int> frequency;
        for (int i = 0; i < poolSize; i++) frequency.Push(0);
        Array<int> activationOfLastPick; // per pool index, last activation it was picked in
        for (int i = 0; i < poolSize; i++) activationOfLastPick.Push(-1);
        int repeatViolations = 0;
        int totalPicks = 0;
        DSP024Rebuild();
        for (int activation = 0; activation < ACTIVATIONS; activation++)
        {
            DSP040ClearChosen(lightningWeaponId, 1);
            for (int k = 0; k < strikeCount; k++)
            {
                int targetSlot; int targetGeneration; int targetId;
                bool found = DSP040ChooseStrikeTarget(lightningWeaponId, 1,
                    playerX, playerY, targetSlot, targetGeneration, targetId);
                if (!found) continue;
                int poolIndex = -1;
                for (int p = 0; p < poolSize; p++)
                    if (auditPoolIds[p] == targetId) { poolIndex = p; break; }
                if (poolIndex < 0) continue; // should never happen: pool is closed
                if (activationOfLastPick[poolIndex] == activation) repeatViolations++;
                activationOfLastPick[poolIndex] = activation;
                frequency[poolIndex]++;
                totalPicks++;
            }
        }
        double expectedPerBucket = double(totalPicks) / double(poolSize);
        double chiSquare = 0.0;
        for (int i = 0; i < poolSize; i++)
        {
            double diff = double(frequency[i]) - expectedPerBucket;
            chiSquare += diff * diff / expectedPerBucket;
        }
        // Degrees of freedom = poolSize-1 = 19. Chi-square critical value at
        // p=0.001 significance for df=19 is 43.82 (standard table value);
        // this fixture reports both the statistic and that fixed threshold
        // rather than asserting a specific pass/fail so the runner/validator
        // makes the call against the stated number.
        Console.Printf("DS_P040_TARGET_AUDIT activations=%d strike_count=%d pool_size=%d total_picks=%d expected_per_bucket=%.2f chi_square=%.3f chi_square_critical_p001_df19=43.820 repeat_violations=%d", ACTIVATIONS, strikeCount, poolSize, totalPicks, expectedPerBucket, chiSquare, repeatViolations);
        for (int i = 0; i < poolSize; i++)
            Console.Printf("DS_P040_TARGET_AUDIT_BUCKET pool_index=%d stable_id=%d observed=%d expected=%.2f", i, auditPoolIds[i], frequency[i], expectedPerBucket);

        // Skip-marker sub-case: shrink the live pool to 3 (direct removal,
        // not the erase operation -- this is audit setup, not a gameplay
        // transaction) so one further activation with the SAME strikeCount
        // (7) demonstrates exactly 3 successful picks and 4 explicit skips.
        int keep = 3;
        for (int i = keep; i < poolSize; i++)
        {
            int slot = -1;
            for (int s = 0; s < lifeStates.Size(); s++)
                if (lifeStates[s] == STORE_ALIVE && ids[s] == auditPoolIds[i]) { slot = s; break; }
            if (slot >= 0) DestroyParts(slot, generations[slot], ids[slot]);
        }
        DSP024Rebuild();
        DSP040ClearChosen(lightningWeaponId, 1);
        int shrunkPicks = 0; int shrunkSkips = 0;
        for (int k = 0; k < strikeCount; k++)
        {
            int targetSlot; int targetGeneration; int targetId;
            bool found = DSP040ChooseStrikeTarget(lightningWeaponId, 1,
                playerX, playerY, targetSlot, targetGeneration, targetId);
            if (found) shrunkPicks++;
            else
            {
                shrunkSkips++;
                Console.Printf("DS_P040_TARGET_AUDIT_SKIP attempt=%d reason=NO_ELIGIBLE_TARGET_IN_REGION pool_remaining=%d", k, keep);
            }
        }
        Console.Printf("DS_P040_TARGET_AUDIT_SHRUNK strike_count=%d pool_remaining=%d picks=%d skips=%d", strikeCount, keep, shrunkPicks, shrunkSkips);
    }

    // ---- Seeded spare-roll audit (no gameplay RNG touched) ------------------

    void RunSpareAudit()
    {
        int strikeSeedBackup = dsp040StrikeRngState;
        int eraseSeedBackup = dsp040EraseRngState;
        for (int rank = 1; rank <= 8; rank++)
        {
            int spareMilli = DSP040GlobalRows.SpareMilli(DSP040GlobalRows.SYSTEM_PENTAGRAM, rank);
            int auditState = 900000000 + rank; // isolated stream, never dsp040EraseRngState
            int sparedCount = 0;
            for (int roll = 0; roll < 100000; roll++)
            {
                auditState = DSP040GlobalMath.NextRngState(auditState);
                bool spared;
                DSP040GlobalMath.SpareRoll(auditState, spareMilli, DSP040GlobalRows.LUCK_BASE_MILLI, spared);
                if (spared) sparedCount++;
            }
            double expected = double(spareMilli) / 1000.0 * 100000.0;
            double delta = double(sparedCount) - expected;
            if (delta < 0.0) delta = -delta;
            double tolerancePct = delta / 100000.0 * 100.0;
            Console.Printf("DS_P040_SPARE_AUDIT rank=%d spare_milli=%d rolls=100000 spared=%d expected=%.1f tolerance_pct=%.3f luck_milli=%d", rank, spareMilli, sparedCount, expected, tolerancePct, DSP040GlobalRows.LUCK_BASE_MILLI);
        }
        // Luck saturation: at luck_milli>=1539 with spare_milli=650 the
        // threshold already saturates the full 1,000,000 range.
        int saturationState = 950000001;
        int saturatedSpared = 0;
        for (int roll = 0; roll < 1000; roll++)
        {
            saturationState = DSP040GlobalMath.NextRngState(saturationState);
            bool spared;
            DSP040GlobalMath.SpareRoll(saturationState, 650, 2000, spared);
            if (spared) saturatedSpared++;
        }
        Console.Printf("DS_P040_SPARE_SATURATION rolls=1000 spared=%d spare_milli=650 luck_milli=2000 expected_always_spared=%d", saturatedSpared, saturatedSpared == 1000 ? 1 : 0);
        dsp040StrikeRngState = strikeSeedBackup;
        dsp040EraseRngState = eraseSeedBackup;
    }

    // ---- Matrix-mode scripted timeline ---------------------------------------

    void RunMatrixTimeline()
    {
        int amountResolved = DSP033AmountApplies(DSP040GlobalRows.SYSTEM_LIGHTNING)
            ? DSP033Resolved(DSP033StatRules.STAT_AMOUNT) : 0;
        int growthResolved = DSP033Resolved(DSP033StatRules.STAT_GROWTH);

        // Pentagram's own tic-1 activation (see SetupMatrixFixtures) erases
        // every enemy present at boot, per the region-wide snapshot policy.
        // A fresh pool is dropped at tic=100 -- well after that one-time
        // wipe and well before Thunder Loop's inherited tic=159 activation
        // (Lightning's own tic=1 activation period, 158 tics, is unaffected
        // by the tic=40 transform) -- so Thunder Loop's first post-transform
        // strike, its repeat, and a dedicated Gorgeous Moon instance all
        // have live, in-region, non-protected targets to act on.
        if (tic == 100)
        {
            for (int i = 0; i < 7; i++)
                SpawnTarget(40.0 + double(i) * 6.0, 60.0, "MOON_POOL", 4.0, 500);
            EquipEraseWeapon(DSP040GlobalRows.SYSTEM_GORGEOUS_MOON, 1,
                moonWeaponSlot, moonWeaponGeneration, moonWeaponId);
            // The freshly spawned targets above are not yet in the broad-
            // phase grid: this tic's DSP024Rebuild() already ran at the top
            // of WorldTick, before these Allocate() calls existed. Without a
            // second rebuild here, Moon's phase-1 beam gather (which fires
            // later in this SAME tic, since its activationTic defaults to
            // "now") would see an empty region on this tic only -- a real
            // bug this fixture caught by actually running in UZDoom, not a
            // hypothetical.
            DSP024Rebuild();
        }
        // Spawned after Moon's phase-2 erasure (tic=135, see the "matrix"
        // trace) so Thunder Loop's own inherited tic=159 activation (from
        // Lightning's tic=1 activation period, untouched by the tic=40
        // transform) has a live, in-region target for its first
        // post-transform strike and repeat.
        if (tic == 150)
        {
            for (int i = 0; i < 3; i++)
                SpawnTarget(50.0 + double(i) * 8.0, -50.0, "THUNDER_LOOP_POOL", 4.0, 1000000000);
            DSP024Rebuild();
        }

        // Strike/erase weapons process every tic once equipped.
        DSP040ProcessStrikeTic(tic, playerX, playerY, amountResolved);
        DSP040ProcessEraseTic(tic, playerX, playerY, DSP040GlobalRows.LUCK_BASE_MILLI, amountResolved);

        // A strike against the dedicated kill target: apply it directly
        // once, at a fixed tic, independent of the RNG-chosen pool, so the
        // kill-vs-erase contrast is deterministic regardless of the
        // uniform-selection outcome.
        if (tic == 10 && ValidParts(killTargetSlot, killTargetGeneration, killTargetId))
        {
            DSP040ApplyStrikeAoE(x[killTargetSlot], y[killTargetSlot],
                DSP040GlobalRows.StrikeRadiusMilliUnits(DSP040GlobalRows.SYSTEM_LIGHTNING, 8),
                DSP040GlobalRows.DamageMilli(DSP040GlobalRows.SYSTEM_LIGHTNING, 8),
                dsp033ResolvedMightMilli, tic, DSP040GlobalRows.SYSTEM_LIGHTNING, 8,
                lightningWeaponId);
        }

        // Growth-at-collection proof, fixed tic.
        if (tic == 15 && ValidParts(growthTestSlot, growthTestGeneration, growthTestId))
        {
            int baseAmount; int bonusAmount;
            bool collected = DSP027CollectPickupWithGrowth(growthTestSlot,
                growthTestGeneration, growthTestId, growthResolved, baseAmount, bonusAmount);
            Console.Printf("DS_P040_MAP26_GROWTH_COLLECT accepted=%d base_milli=%d growth_milli=%d bonus_milli=%d", collected ? 1 : 0, baseAmount, growthResolved, bonusAmount);
        }

        // Transform Lightning Ring -> Thunder Loop, then Pentagram ->
        // Gorgeous Moon, at a fixed tic well after the first strike proof.
        if (tic == 40 && !transformDone)
        {
            bool loopOk = DSP040TransformToLoop(lightningWeaponSlot,
                lightningWeaponGeneration, lightningWeaponId,
                DSP040GlobalRows.DEPENDENCY_AMOUNT_SOURCE_KEY, 1, 2);
            bool moonOk = DSP040TransformToMoon(pentagramWeaponSlot,
                pentagramWeaponGeneration, pentagramWeaponId,
                DSP040GlobalRows.DEPENDENCY_GROWTH_SOURCE_KEY, 1, 2);
            moonWeaponSlot = pentagramWeaponSlot;
            moonWeaponGeneration = pentagramWeaponGeneration;
            moonWeaponId = pentagramWeaponId;
            transformDone = true;
            Console.Printf("DS_P040_MAP26_TRANSFORM_ATTEMPT loop_accepted=%d moon_accepted=%d tic=%d", loopOk ? 1 : 0, moonOk ? 1 : 0, tic);
        }

        // A fresh enemy dropped exactly at the Thunder Loop's stored strike
        // location shortly before its repeat is due, so the repeat's
        // "against whatever is inside then" AoE has something to hit.
        if (tic == 55 && !repeatFixtureSpawned && dsp040RepeatActive.Size() > 0)
        {
            repeatEnemySlot = SpawnTarget(dsp040RepeatX[0], dsp040RepeatY[0], "THUNDER_REPEAT_TARGET", 4.0, 1000);
            repeatFixtureSpawned = true;
        }

        if (tic == 20 || tic == 60 || tic == 120 || tic == 180 || tic == finishAtTic)
            Console.Printf("DS_P040_MAP26_TRACE tic=%d accepted_hits=%d skipped=%d repeats_scheduled=%d repeats_fired=%d erased_enemies=%d killed=%d spared_pickups=%d erased_pickups=%d moon_beam_hits=%d moon_gems=%d ledger_valid=%d", tic, dsp040AcceptedHits, dsp040SkippedStrikes, dsp040ThunderRepeatsScheduled, dsp040ThunderRepeatsFired, dsp040ErasedEnemies, dsp040KilledByGlobal, dsp040SparedPickups, dsp040ErasedPickups, dsp040MoonBeamHits, dsp040MoonGemsCreated, DSP027LedgerValid());
    }

    void RunMassTimeline()
    {
        int amountResolved = DSP033Resolved(DSP033StatRules.STAT_AMOUNT);
        DSP040ProcessStrikeTic(tic, playerX, playerY, amountResolved);
        DSP040ProcessEraseTic(tic, playerX, playerY, DSP040GlobalRows.LUCK_BASE_MILLI, amountResolved);
        if (tic % 20 == 0 || tic == finishAtTic)
            Console.Printf("DS_P040_MAP26_MASS_TRACE tic=%d accepted_hits=%d erased_enemies=%d spared_pickups=%d erased_pickups=%d ledger_valid=%d live_enemies=%d live_pickups=%d", tic, dsp040AcceptedHits, dsp040ErasedEnemies, dsp040SparedPickups, dsp040ErasedPickups, DSP027LedgerValid(), LiveEnemyCount(), LivePickupCount());
    }

    int LiveEnemyCount()
    {
        int count = 0;
        for (int slot = 0; slot < lifeStates.Size(); slot++)
            if (lifeStates[slot] == STORE_ALIVE && kinds[slot] == ENEMY_KIND && health[slot] > 0) count++;
        return count;
    }

    int LivePickupCount()
    {
        int count = 0;
        for (int slot = 0; slot < lifeStates.Size(); slot++)
            if (DSP027IsLivePickup(slot)) count++;
        return count;
    }

    int FinalHash()
    {
        int hash = DSP040GlobalStateHash();
        hash = hash * 31 + dsp033ResolvedRankHashAmountGrowth;
        return hash;
    }

    void EmitComplete()
    {
        Console.Printf("DS_P040_MAP26_COMPLETE mode=%s tic=%d hash=%d accepted_hits=%d skipped=%d repeats_scheduled=%d repeats_fired=%d erased_enemies=%d killed=%d killed_with_xp=%d spared_pickups=%d erased_pickups=%d moon_beam_hits=%d moon_gems=%d ledger_valid=%d live_enemies=%d live_pickups=%d camera_variant=%d", activeMode, tic, FinalHash(), dsp040AcceptedHits, dsp040SkippedStrikes, dsp040ThunderRepeatsScheduled, dsp040ThunderRepeatsFired, dsp040ErasedEnemies, dsp040KilledByGlobal, killsWithXp, dsp040SparedPickups, dsp040ErasedPickups, dsp040MoonBeamHits, dsp040MoonGemsCreated, DSP027LedgerValid(), LiveEnemyCount(), LivePickupCount(), cameraVariant);
        LevelLocals.MakeScreenShot();
    }

    void EmitSaveCandidate()
    {
        int hash = FinalHash();
        int pendingRepeat = dsp040RepeatActive.Size() > 0 ? 1 : 0;
        int pendingMoonPhase2 = dsp040MoonPendingActive.Size() > 0 ? 1 : 0;
        Console.Printf("DS_P040_MAP26_SAVE_CANDIDATE tic=%d hash=%d rank_hash_amount_growth=%d accepted_hits=%d erased_enemies=%d repeats_scheduled=%d repeats_fired=%d moon_gems=%d pending_thunder_repeat=%d pending_moon_phase2=%d", tic, hash, dsp033ResolvedRankHashAmountGrowth, dsp040AcceptedHits, dsp040ErasedEnemies, dsp040ThunderRepeatsScheduled, dsp040ThunderRepeatsFired, dsp040MoonGemsCreated, pendingRepeat, pendingMoonPhase2);
        // Any tic in this window is a valid save point: a Thunder Loop
        // repeat and a Moon phase-2 are both scheduled from shortly after
        // the shared tic=1 first activation until tic=19/36 respectively
        // (see SetupSaveFixtures), so this marker is deliberately wide
        // rather than tied to one exact tic the save script must hit.
        if (pendingRepeat == 1 && pendingMoonPhase2 == 1)
            Console.Printf("DS_P040_MAP26_SAVE_READY tic=%d hash=%d pending_thunder_repeat=1 pending_moon_phase2=1", tic, hash);
    }

    // ---- Native pause bridge (mirrors P039's MAP25 pattern exactly) -------

    override void UiTick()
    {
        uiTics++;
        if (uiPauseMode == 0) return;
        if (!uiPauseRequestSent && uiLogicalTic >= 5
            && !Level.WorldPaused() && Menu.GetCurrentMenu() == null)
        {
            uiPauseRequestSent = true;
            uiPauseAtTic = uiLogicalTic;
            SendNetworkEvent("P040_MAP26_PAUSE_REQUEST", uiLogicalTic, uiPauseHash, uiTics);
            Menu.SetMenu('MainMenu');
        }
        else if (uiPauseRequestSent && !uiPauseObserved && Level.WorldPaused())
        {
            uiPauseObserved = true;
            uiPauseUntilUiTic = uiTics + 35;
            SendNetworkEvent("P040_MAP26_PAUSE_HELD", uiLogicalTic, uiPauseHash, uiTics);
        }
        else if (uiPauseObserved && !uiPauseResumeSent && uiTics >= uiPauseUntilUiTic)
        {
            Menu menu = Menu.GetCurrentMenu();
            if (menu != null) menu.Close();
            if (!Level.WorldPaused())
            {
                uiPauseResumeSent = true;
                SendNetworkEvent("P040_MAP26_RESUME", uiLogicalTic, uiPauseHash, uiTics);
            }
        }
    }

    override void InterfaceProcess(ConsoleEvent e)
    {
        if (e.Name == "P040_MAP26_UI_RESET")
        {
            uiPauseRequestSent = false; uiPauseObserved = false; uiPauseResumeSent = false;
            uiTics = 0; uiLogicalTic = 0; uiPauseHash = 0;
            uiPauseAtTic = -1; uiPauseUntilUiTic = 0; uiPauseMode = 0;
        }
        else if (e.Name == "P040_MAP26_UI_STATE")
        {
            uiLogicalTic = e.Args[0];
            uiPauseHash = e.Args[1];
            uiPauseMode = e.Args[2];
        }
    }

    override void NetworkProcess(ConsoleEvent e)
    {
        if (e.Player != consoleplayer) return;
        if (e.Name == "P040_MAP26_PAUSE_REQUEST")
        {
            pauseRequested = true;
            pauseStartLogicalTic = e.Args[0];
            pauseStartHash = e.Args[1];
            Console.Printf("DS_P040_MAP26_PAUSE_START logical_tic=%d state_hash=%d ui_tic=%d requested_native_pause=1", pauseStartLogicalTic, pauseStartHash, e.Args[2]);
        }
        else if (e.Name == "P040_MAP26_PAUSE_HELD")
        {
            pauseOpened = true;
            Console.Printf("DS_P040_MAP26_PAUSE_HELD logical_tic=%d state_hash=%d ui_tic=%d world_paused=1", e.Args[0], e.Args[1], e.Args[2]);
        }
        else if (e.Name == "P040_MAP26_RESUME")
        {
            pauseClosed = true;
            pauseResumeTic = e.Args[0];
            pauseResumeHash = e.Args[1];
            bool stable = pauseOpened && pauseStartLogicalTic == pauseResumeTic
                && pauseStartHash == pauseResumeHash;
            Console.Printf("DS_P040_MAP26_PAUSE_END accepted=%d world_logical_tic=%d start_world_logical_tic=%d ui_tics=%d start_hash=%d end_hash=%d", stable ? 1 : 0, pauseResumeTic, pauseStartLogicalTic, e.Args[2], pauseStartHash, pauseResumeHash);
        }
    }

    override void WorldLoaded(WorldEvent e)
    {
        enabled = level.MapName == MAP;
        completed = false;
        if (!enabled) return;
        if (!e.IsSaveGame) StartScenario();
        Console.Printf("DS_P040_MAP26_WORLD_LOADED is_save=%d tic=%d hash=%d", e.IsSaveGame, tic, FinalHash());
    }

    int ReadSaveSnapshotRequest()
    {
        CVar cvar = CVar.FindCVar("ds_p040_save_snapshot_request");
        return cvar != null && cvar.GetInt() != 0 ? 1 : 0;
    }

    override void WorldTick()
    {
        if (!enabled && level != null && level.MapName == MAP) enabled = true;
        if (!enabled || completed) return;
        if (activeMode == "save" && saveHold && ReadSaveSnapshotRequest() == 0)
        {
            // The restore leg clears the cvar to unfreeze; this is checked
            // before the frozen-return below so the SAME tic that unfreezes
            // also resumes normal processing.
            saveHold = false;
            Console.Printf("DS_P040_MAP26_SAVE_UNFROZEN tic=%d hash=%d", tic, FinalHash());
        }
        bool firstTickThisProcess = !startedThisProcess;
        startedThisProcess = true;
        if (firstTickThisProcess && tic > 0)
        {
            ConfigureCamera();
            Console.Printf("DS_P040_MAP26_RESTORE first_tick=1 tic=%d hash=%d continuation=1 pending_thunder_repeat=%d pending_moon_phase2=%d", tic, FinalHash(), dsp040RepeatActive.Size() > 0 ? 1 : 0, dsp040MoonPendingActive.Size() > 0 ? 1 : 0);
            restoredStateReported = true;
        }
        if (activeMode == "save" && saveHold)
        {
            // Frozen exactly at the save point: no further tic advancement,
            // so the native "save" console command -- issued after this
            // process idles here for however long its script's `wait`
            // takes in real time -- always captures this exact logical tic,
            // decoupling the save script's timing from the pending-events
            // window's own width.
            return;
        }
        tic++;
        // The broad-phase grid is one tic stale until rebuilt; every
        // DSP024RadiusCandidates call this tic (strikes, erasure, Moon)
        // must see this tic's positions, matching VerticalSlice's own
        // once-per-tic DSP024Rebuild() convention.
        DSP024Rebuild();
        if (activeMode == "spare_audit")
        {
            if (tic == 1) RunSpareAudit();
        }
        else if (activeMode == "target_audit")
        {
            if (tic == 1) RunTargetAudit();
        }
        else if (activeMode == "mass")
            RunMassTimeline();
        else if (activeMode == "pause" || activeMode == "save")
            RunSaveTimeline();
        else
            RunMatrixTimeline();
        SyncBoltProxy();
        SendInterfaceEvent(consoleplayer, "P040_MAP26_UI_STATE", tic,
            FinalHash(), activeMode == "pause" ? 1 : 0);
        if (activeMode == "save")
        {
            EmitSaveCandidate();
            bool pendingBoth = dsp040RepeatActive.Size() > 0
                && dsp040MoonPendingActive.Size() > 0;
            if (!saveHold && pendingBoth && ReadSaveSnapshotRequest() == 1)
            {
                saveHold = true;
                saveLogicalTic = tic;
                saveStateHash = FinalHash();
                Console.Printf("DS_P040_MAP26_SAVE_FROZEN accepted=1 tic=%d hash=%d pending_thunder_repeat=1 pending_moon_phase2=1", tic, saveStateHash);
            }
        }
        if (tic >= finishAtTic)
        {
            EmitComplete();
            completed = true;
        }
    }
}
