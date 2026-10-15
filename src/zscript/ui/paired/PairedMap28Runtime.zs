// MAP28 controlled P042 paired-weapon/union/chain harness
// (docs/contracts/paired-unions.md), covering the full contract acceptance
// matrix across one mode per area (RunModeTic below is structured as one
// `else if (activeMode == ...)` block per mode so each slots in
// independently):
//   boot          - compiles and prints every DS_P042_MAP28_ROW rank row
//                   from DSP042PairedRows for field-by-field comparison
//                   against data/verified/base/weapons/paired/*.json.
//   chain         - Bracelet(rank 6) -> Bi-Bracelet (recipe 204) ->
//                   Tri-Bracelet (recipe 205) through the real
//                   DSP032TransformationGraph recipe predicate/transaction,
//                   mirrored into the DSP042Paired schedule via
//                   DSP042EvolveInPlace (same weaponIndex/slot identity).
//   union_matrix  - A01: all three unions, both acquisition orders, full
//                   and extra-slot inventories (12 cases).
//   union_negative- Negative rejection cases (non-max input, missing
//                   passive, non-evolution chest, duplicate union).
//   attribution   - A02: all eleven systems firing concurrently with
//                   Might-eligible attribution and a mid-run union.
//   patterns      - FP01: mirrored bird rotation, Phiera/Eight facing vs
//                   fixed diagonals, Phieraggi's 15 deg/volley advance
//                   (plus patterns_camera_window_invariance).
//   burst_union   - A03: a union mid-burst cancels pending children only.
//   vento_streak  - Movement-streak growth/reset/cap for Vento Sacro and
//                   Fuwalafuwaloo, replayed from the position trace.
//   fuwala_heal   - Fuwalafuwaloo crit healing through the P039 authority
//                   plus an isolated production crit-rate audit.
//   pause         - Real native menu pause (P041/MAP27 UiTick bridge).
//   save          - Native save/load across a union with an in-flight
//                   parent-owned gun child (tools/run_p042_paired.py
//                   --save-roundtrip).
class DSP042PairedMap28Runtime : EventHandler
{
    mixin DSRunStatFields;
    mixin DSP020EntityStore;
    mixin DSP024SpatialIndex;
    mixin DSP025AttackCore;
    mixin DSP033ResolvedStats;
    mixin DSP039Healing;
    mixin DSP034AimedTargeting;
    mixin DSP032TransformationGraph;
    mixin DSP042PairedTargeting;
    mixin DSP042Paired;

    const MAP = "MAP28";
    const ENEMY_KIND = 1;
    const PLAYER_KIND = 99;
    const WEAPON_KIND = 90;

    // ---- union_matrix layout: 3 unions x (order AB/BA) x (FULL/EXTRA) ----
    const DS_UNION_TICS_PER_CASE = 9;
    const DS_UNION_CASE_COUNT = 12;
    // ---- union_negative layout: 4 independent rejection cases ----
    const DS_NEG_TICS_PER_CASE = 3;
    const DS_NEG_CASE_COUNT = 4;

    bool started;
    bool enabled;
    bool completed;
    int logicalTic;
    int tic;
    String activeMode;
    int playerSlot;
    double playerX;
    double playerY;
    int finishAtTic;

    // ---- chain mode state ----
    int chainWeaponIndex;
    int chainTargetSlot;
    int chainTargetGeneration;
    int chainTargetId;

    // ---- union_matrix/union_negative shared target (placed AT the player
    // origin with a large collision radius so every geometry adapter --
    // orbiting bird impacts, fixed/facing gun diagonals, Phieraggi's
    // origin-anchored beams, the Vento/Fuwala facing arc and the Bracelet
    // nearest-target search -- connects deterministically regardless of
    // angle, isolating these validators to slot-transaction/attribution
    // correctness rather than untested hit geometry) ----
    int unionTargetSlot;
    int unionTargetGeneration;
    int unionTargetId;

    // ---- union_matrix per-case state (one case active at a time) ----
    int unionCaseRecipeId;
    int unionCaseInputA;
    int unionCaseInputB;
    int unionCaseMaxRankA;
    int unionCaseMaxRankB;
    int unionCaseRequiredPassive;
    int unionCaseOutputSystem;
    int unionCaseOutputRank;
    int unionCaseSourceId;
    String unionCaseLabel;
    int unionCaseWeaponIndexA;
    int unionCaseWeaponIndexB;
    int unionCaseSurvivingIndex;
    int unionCaseCancelledIndex;
    int unionCaseReuseIndex;
    int unionCaseUnionTic;

    // ---- union_negative per-case state ----
    int negRecipeId;
    int negChest;
    String negCaseLabel;
    int negHashAfterAttempt;

    // ---- camera/window-invariance presentation knobs (patterns mode item
    // "camera/window invariance"). Purely cosmetic: every logical input (the
    // fixture's own facing/origin arguments to DSP042FireVolley) is driven by
    // ds_p042_body_yaw below, never by these, so changing them must never
    // change a single DS_P042_HIT/DS_P042_GUN_SPAWN tuple. ----
    int cameraVariant;
    int cameraYaw;
    int cameraPitch;
    int cameraFov;

    // ---- attribution mode (A02) state --------------------------------------
    const DS_ATTR_MIGHT_MILLI = 2000;
    const DS_ATTR_LUCK_MILLI = 1000;
    const DS_ATTR_UNION_AT_TIC = 90;
    const DS_ATTR_FINISH_TIC = 180;
    int attrWeaponPhiera, attrWeaponEight, attrWeaponPhieraggi, attrWeaponVento,
        attrWeaponFuwala, attrWeaponBracelet, attrWeaponBiBracelet,
        attrWeaponTriBracelet, attrWeaponPeachone, attrWeaponEbony;
    int attrTargetSlot, attrTargetGeneration, attrTargetId;
    int attrUnionSurvivingIndex, attrUnionCancelledIndex;

    // ---- patterns mode (FP01) state -----------------------------------------
    const DS_PAT_FINISH_TIC = 100;
    int patWeaponPeachone, patWeaponEbony, patWeaponPhiera, patWeaponEight,
        patWeaponPhieraggi;
    int patTargetSlot, patTargetGeneration, patTargetId;
    int patBodyYawMilli;

    // ---- burst_union mode state ---------------------------------------------
    const DS_BURST_FINISH_TIC = 40;
    const DS_BURST_VOLLEY_TIC = 5;
    const DS_BURST_UNION_TIC = 8;
    int burstWeaponPhiera, burstWeaponEight, burstWeaponBracelet;
    int burstTargetSlot, burstTargetGeneration, burstTargetId;
    int burstUnionSurvivingIndex, burstUnionCancelledIndex;
    int burstHashBeforeUnion, burstHashAfterUnion;

    // ---- vento_streak mode state ---------------------------------------------
    const DS_STREAK_MOVE1_END_TIC = 220;
    const DS_STREAK_STOP_END_TIC = 260;
    const DS_STREAK_MOVE2_END_TIC = 480;
    const DS_STREAK_FINISH_TIC = 510;
    int streakWeaponVento, streakWeaponFuwala;
    int streakTargetSlot, streakTargetGeneration, streakTargetId;

    // ---- fuwala_heal mode state -----------------------------------------------
    const DS_HEAL_FINISH_TIC = 820;
    const DS_HEAL_NORMAL_VOLLEYS = 8;
    const DS_HEAL_VOLLEY_PERIOD = 70;
    const DS_HEAL_FORCE_LUCK_MILLI = 25000;
    const DS_HEAL_CAP_SETUP_TIC = 700;
    int healWeaponFuwala;
    int healTargetSlot, healTargetGeneration, healTargetId;
    int healPlayerHealthMilli, healPlayerMaxHealthMilli;
    int healForcedVolleyTicA, healForcedVolleyTicB, healForcedVolleyTicC;

    // ---- pause mode state (native menu pause bridge; mirrors P041's MAP27
    // pattern exactly -- see BounceMap27Runtime.zs) -----------------------
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
    int pauseWeaponBracelet;
    int pauseTargetSlot, pauseTargetGeneration, pauseTargetId;

    // ---- save mode state (native save/load across a union with an
    // in-flight parent-owned gun child and a pending output schedule) -------
    int saveLogicalTic;
    int saveStateHash;
    int saveInventoryHash;
    bool saveHold;
    transient bool startedThisProcess;
    int saveWeaponPhiera, saveWeaponEight, saveWeaponBracelet;
    int saveUnionSurvivingIndex, saveUnionCancelledIndex;
    int saveTargetSlot, saveTargetGeneration, saveTargetId;

    override void OnRegister()
    {
        IsUiProcessor = false;
        RequireMouse = false;
    }

    // Minimal HandleEnemyDeath: DSP042ApplyInstantHit/DSP042ApplyGunHit call
    // this on a checked-hit kill (same convention as every other MAP2x
    // harness, e.g. BounceMap27Runtime.HandleEnemyDeath). This skeleton
    // never needs an XP drop, so it just releases the entity.
    void HandleEnemyDeath(int slot, int beforeHealth, int eventId)
    {
        if (!ValidParts(slot, generations[slot], ids[slot])) return;
        Console.Printf("DS_P042_MAP28_DEATH event_id=%d tic=%d target_id=%d before=%d", eventId, logicalTic, ids[slot], beforeHealth);
        DestroyParts(slot, generations[slot], ids[slot]);
    }

    String ReadMode()
    {
        CVar mode = CVar.FindCVar("ds_p042_mode");
        return mode != null ? mode.GetString() : "boot";
    }

    // FP01 logical input: which body-facing yaw (character-relative) the
    // patterns scenario fires Phiera/Vento/Fuwala at. Never read from the
    // native player angle -- deliberately a SEPARATE logical cvar from
    // ds_p042_camera_variant below, so a camera/window invariance run can
    // hold this fixed while flexing only presentation.
    int ReadBodyYawMilli()
    {
        CVar cvar = CVar.FindCVar("ds_p042_body_yaw");
        int deg = cvar != null ? cvar.GetInt() : 0;
        if (deg != 0 && deg != 90 && deg != 180) deg = 0;
        return deg * 1000;
    }

    int ReadCameraVariant()
    {
        CVar camera = CVar.FindCVar("ds_p042_camera_variant");
        int variant = camera != null ? camera.GetInt() : 0;
        return variant >= 0 && variant <= 3 ? variant : 0;
    }

    // Camera/window invariance: monitor size (driven by run_probe's actual
    // window flags, outside this file), FOV and pitch are never logical
    // inputs. Variant 0=baseline (pitch 0, FOV 90), 1=pitch 22, 2=FOV 120
    // (wide), 3=FOV 60 (narrow). Every DSP042FireVolley call in this fixture
    // reads its facing/origin from fixture-owned fields, never from
    // players[0].mo, so this is provably inert to logical output.
    void ConfigureCamera()
    {
        cameraVariant = ReadCameraVariant();
        cameraYaw = 0;
        cameraPitch = cameraVariant == 1 ? 22 : 0;
        cameraFov = cameraVariant == 2 ? 120 : (cameraVariant == 3 ? 60 : 90);
        if (players[0].mo != null)
        {
            players[0].mo.Angle = cameraYaw;
            players[0].mo.Pitch = cameraPitch;
            players[0].SetFOV(cameraFov);
        }
        Console.Printf("DS_P042_MAP28_CAMERA variant=%d yaw=%d pitch=%d fov=%d source=UZDOOM_PLAYER_VIEW", cameraVariant, cameraYaw, cameraPitch, cameraFov);
    }

    int SpawnTarget(double targetX, double targetY, String label,
        double radius = 8.0, int healthMilli = 100000000)
    {
        int slot = Allocate(ENEMY_KIND, targetX, targetY, 0.0, 0.0, healthMilli);
        if (slot < 0) return -1;
        collisionRadii[slot] = radius;
        Console.Printf("DS_P042_MAP28_TARGET slot=%d generation=%d stable_id=%d x=%.3f y=%.3f label=%s", slot, generations[slot], ids[slot], targetX, targetY, label);
        return slot;
    }

    // DSP042EquipFixture (PairedRuntime.zs) itself returns the equipped
    // weapon's own schedule index (or -1 on rejection) -- NOT a bool -- so
    // that value is returned directly rather than re-derived from
    // dsp042WeaponSystems.Size()-1 (which would be wrong once cancelled
    // slots exist, and would misread a successful index 0 as failure if
    // negated).
    int EquipWeapon(int systemId, int rank)
    {
        int weaponSlot = Allocate(WEAPON_KIND, playerX, playerY, 0.0, 0.0, 1);
        if (weaponSlot < 0) return -1;
        return DSP042EquipFixture(systemId, rank, weaponSlot, logicalTic);
    }

    bool Boot()
    {
        activeMode = ReadMode();
        tic = 0; logicalTic = 0; playerX = 0.0; playerY = 0.0;
        completed = false;
        chainWeaponIndex = -1; chainTargetSlot = -1;
        chainTargetGeneration = 0; chainTargetId = 0;
        streakWeaponVento = -1; streakWeaponFuwala = -1; streakTargetSlot = -1;
        healWeaponFuwala = -1; healTargetSlot = -1;
        healForcedVolleyTicA = 0; healForcedVolleyTicB = 0; healForcedVolleyTicC = 0;
        pauseRequested = false; pauseOpened = false; pauseClosed = false;
        pauseStartLogicalTic = -1; pauseStartHash = 0;
        pauseResumeTic = -1; pauseResumeHash = 0;
        pauseWeaponBracelet = -1; pauseTargetSlot = -1;
        saveLogicalTic = -1; saveStateHash = 0; saveInventoryHash = 0; saveHold = false;
        saveWeaponPhiera = -1; saveWeaponEight = -1; saveWeaponBracelet = -1;
        saveUnionSurvivingIndex = -1; saveUnionCancelledIndex = -1; saveTargetSlot = -1;
        Reset();
        DSP024ClearSpatial();
        DSP042ResetPairedRuntime(420401);
        DSP032ResetInventory();
        ConfigureCamera();
        playerSlot = Allocate(PLAYER_KIND, playerX, playerY, 0.0, 0.0, 1);
        collisionRadii[playerSlot] = 2.0;
        DSP033SetBaseStats(1000, 1, 120000, 1000);
        DSP033RecomputeFromRanks(0, 0, 0, 0);
        bool setupOk = playerSlot >= 0;
        finishAtTic = 5;
        if (activeMode == "boot") { finishAtTic = 5; }
        else if (activeMode == "chain") { setupOk = setupOk && SetupChain(); finishAtTic = 30; }
        else if (activeMode == "union_matrix")
        {
            setupOk = setupOk && SetupUnionMatrixTarget();
            finishAtTic = DS_UNION_TICS_PER_CASE * DS_UNION_CASE_COUNT + 3;
        }
        else if (activeMode == "union_negative")
        {
            finishAtTic = DS_NEG_TICS_PER_CASE * DS_NEG_CASE_COUNT + 3;
        }
        else if (activeMode == "attribution")
        {
            setupOk = setupOk && SetupAttribution();
            finishAtTic = DS_ATTR_FINISH_TIC;
        }
        else if (activeMode == "patterns")
        {
            setupOk = setupOk && SetupPatterns();
            finishAtTic = DS_PAT_FINISH_TIC;
        }
        else if (activeMode == "burst_union")
        {
            setupOk = setupOk && SetupBurstUnion();
            finishAtTic = DS_BURST_FINISH_TIC;
        }
        else if (activeMode == "vento_streak")
        {
            setupOk = setupOk && SetupVentoStreak();
            finishAtTic = DS_STREAK_FINISH_TIC;
        }
        else if (activeMode == "fuwala_heal")
        {
            setupOk = setupOk && SetupFuwalaHeal();
            finishAtTic = DS_HEAL_FINISH_TIC;
        }
        else if (activeMode == "pause")
        {
            setupOk = setupOk && SetupPause();
            finishAtTic = 90;
        }
        else if (activeMode == "save")
        {
            setupOk = setupOk && SetupSave();
            finishAtTic = 200;
        }
        Console.Printf("DS_P042_MAP28_BOOT accepted=%d mode=%s player_slot=%d classification=CONTROLLED_ENGINE_FIXTURE", setupOk ? 1 : 0, activeMode, playerSlot);
        return setupOk;
    }

    bool SetupUnionMatrixTarget()
    {
        unionTargetSlot = SpawnTarget(playerX, playerY, "UNION_TARGET", 50.0);
        if (unionTargetSlot < 0) return false;
        unionTargetGeneration = generations[unionTargetSlot];
        unionTargetId = ids[unionTargetSlot];
        return true;
    }

    bool SetupChain()
    {
        DSP032SetItem(DSP032_ID_BRACELET, 6);
        chainWeaponIndex = EquipWeapon(DSP042PairedRows.SYSTEM_BRACELET, 6);
        chainTargetSlot = SpawnTarget(60.0, 0.0, "CHAIN_TARGET", 6.0);
        if (chainTargetSlot >= 0)
        {
            chainTargetGeneration = generations[chainTargetSlot];
            chainTargetId = ids[chainTargetSlot];
        }
        return chainWeaponIndex >= 0 && chainTargetSlot >= 0;
    }

    // Applies one chain-evolution recipe through the real P032 predicate and
    // atomic inventory transaction, then mirrors the accepted transaction
    // into the P042 firing schedule via DSP042EvolveInPlace on the SAME
    // weaponIndex (contract "same slot identity index" / "old attacks are
    // not retained" -- there is only ever one schedule row for this weapon,
    // so once this call returns the old system can no longer fire at all).
    // newRank is set directly on both sides (a CONTROLLED_ENGINE_FIXTURE
    // rank override, the same pattern DSP032SeedWhipEvolutionFixture already
    // uses) so the very next chain step's own max-rank predicate is
    // satisfied without needing a separate leveling mechanic in this
    // skeleton.
    bool ApplyChainStep(int stepNumber, int recipeId, int expectedNewSystem,
        int newRank, int logicalTic)
    {
        bool ready = DSP032CanApplyRecipe(recipeId, DSP032_GRAPH_CHEST_SILVER, true, true);
        int txId = 428000 + stepNumber;
        bool applied = ready && DSP032ApplyRecipe(recipeId, 2801,
            DSP032_GRAPH_CHEST_SILVER, true, true, txId);
        int oldSystem = chainWeaponIndex >= 0 ? dsp042WeaponSystems[chainWeaponIndex] : 0;
        bool evolved = applied && chainWeaponIndex >= 0
            && DSP042EvolveInPlace(chainWeaponIndex, expectedNewSystem, newRank, logicalTic);
        if (evolved) DSP032SetItem(DSP032RecipeOutput(recipeId), newRank);
        Console.Printf("DS_P042_MAP28_CHAIN_STEP step=%d recipe=%d accepted=%d old_system=%d new_system=%d new_rank=%d weapon_index=%d tic=%d inventory_hash=%d", stepNumber, recipeId, evolved ? 1 : 0, oldSystem, expectedNewSystem, newRank, chainWeaponIndex, logicalTic, DSP032InventoryHash());
        return evolved;
    }

    void RunModeTic()
    {
        if (activeMode == "boot")
        {
            if (logicalTic == 1) EmitCompiledRows();
        }
        else if (activeMode == "chain")
        {
            if (logicalTic == 1)
                DSP042FireVolley(chainWeaponIndex, logicalTic, 0, playerX, playerY, 1000, 1000, 1000);
            else if (logicalTic == 10)
            {
                ApplyChainStep(1, DSP032_RECIPE_CHAIN_BRACELET_BI,
                    DSP042PairedRows.SYSTEM_BI_BRACELET, 6, logicalTic);
                DSP042FireVolley(chainWeaponIndex, logicalTic, 0, playerX, playerY, 1000, 1000, 1000);
            }
            else if (logicalTic == 20)
            {
                ApplyChainStep(2, DSP032_RECIPE_CHAIN_BI_TRI,
                    DSP042PairedRows.SYSTEM_TRI_BRACELET, 6, logicalTic);
                DSP042FireVolley(chainWeaponIndex, logicalTic, 0, playerX, playerY, 1000, 1000, 1000);
            }
        }
        else if (activeMode == "union_matrix")
        {
            RunUnionMatrixTic();
        }
        else if (activeMode == "union_negative")
        {
            RunUnionNegativeTic();
        }
        else if (activeMode == "attribution")
        {
            RunAttributionTic();
        }
        else if (activeMode == "patterns")
        {
            RunPatternsTic();
        }
        else if (activeMode == "burst_union")
        {
            RunBurstUnionTic();
        }
        else if (activeMode == "vento_streak")
        {
            RunVentoStreakTic();
        }
        else if (activeMode == "fuwala_heal")
        {
            RunFuwalaHealTic();
        }
        else if (activeMode == "pause")
        {
            RunPauseTic();
        }
        else if (activeMode == "save")
        {
            RunSaveTic();
        }
        // else if (activeMode == "<next mode>") { ... } -- structured slot
        // for the remaining contract items (MAP16 route), deliberately left
        // unimplemented by this narrow addition.
    }

    bool DSP042SystemExistsForId(int id)
    {
        return id >= DSP042PairedRows.SYSTEM_PEACHONE
            && id <= DSP042PairedRows.SYSTEM_TRI_BRACELET;
    }

    // ---- union_matrix: A01 slot transaction + reuse + attribution ---------

    void RunUnionMatrixTic()
    {
        int caseIndex = logicalTic / DS_UNION_TICS_PER_CASE;
        int caseTic = logicalTic % DS_UNION_TICS_PER_CASE;
        if (caseIndex >= DS_UNION_CASE_COUNT) return;

        if (caseTic == 0)
        {
            SetupUnionCase(caseIndex);
            EmitUnionSnapshot(caseIndex, "BEFORE", logicalTic);
        }
        else if (caseTic == 1)
        {
            // Pre-union volley on both parents: proves any child already
            // emitted before the transaction keeps resolving under the old
            // owner/system (contract "old attacks are not retained" only
            // applies to FUTURE emissions).
            if (unionCaseWeaponIndexA >= 0)
                DSP042FireVolley(unionCaseWeaponIndexA, logicalTic, 0,
                    playerX, playerY, 1000, 1000, 1000);
            if (unionCaseWeaponIndexB >= 0)
                DSP042FireVolley(unionCaseWeaponIndexB, logicalTic, 0,
                    playerX, playerY, 1000, 1000, 1000);
        }
        else if (caseTic == 2)
        {
            ApplyUnionCase(caseIndex, logicalTic);
            EmitUnionSnapshot(caseIndex, "AFTER", logicalTic);
            if (unionCaseCancelledIndex >= 0)
            {
                bool fired = DSP042FireVolley(unionCaseCancelledIndex, logicalTic,
                    0, playerX, playerY, 1000, 1000, 1000);
                Console.Printf("DS_P042_MAP28_FIRE_CHECK case_index=%d tic=%d weapon_index=%d fired=%d expected=0 label=CANCELLED_WEAPON_MUST_NOT_FIRE", caseIndex, logicalTic, unionCaseCancelledIndex, fired ? 1 : 0);
            }
        }
        else if (caseTic >= 3 && caseTic <= 5)
        {
            // Post-union volleys: every new hit must come from the output
            // system only (the surviving weaponIndex has already been
            // evolved in place).
            if (unionCaseSurvivingIndex >= 0)
            {
                bool fired = DSP042FireVolley(unionCaseSurvivingIndex, logicalTic,
                    0, playerX, playerY, 1000, 1000, 1000);
                Console.Printf("DS_P042_MAP28_FIRE_CHECK case_index=%d tic=%d weapon_index=%d fired=%d expected=1 label=OUTPUT_SYSTEM_VOLLEY", caseIndex, logicalTic, unionCaseSurvivingIndex, fired ? 1 : 0);
            }
        }
        else if (caseTic == 6)
        {
            DSP042ReuseCapacityCheck(caseIndex, logicalTic);
        }
        else if (caseTic == 7 || caseTic == 8)
        {
            if (unionCaseReuseIndex >= 0)
            {
                bool fired = DSP042FireVolley(unionCaseReuseIndex, logicalTic,
                    0, playerX, playerY, 1000, 1000, 1000);
                Console.Printf("DS_P042_MAP28_FIRE_CHECK case_index=%d tic=%d weapon_index=%d fired=%d expected=1 label=REUSED_SLOT_VOLLEY", caseIndex, logicalTic, unionCaseReuseIndex, fired ? 1 : 0);
            }
        }
    }

    // Union identity table (docs/contracts/paired-unions.md "Identities and
    // scope"). unionIndex 0=Vandalier, 1=Phieraggi, 2=Fuwalafuwaloo.
    void UnionSpecFor(int unionIndex)
    {
        if (unionIndex == 0)
        {
            unionCaseRecipeId = DSP032_RECIPE_UNION_VANDALIER;
            unionCaseInputA = DSP032_ID_PEACHONE; unionCaseMaxRankA = 8;
            unionCaseInputB = DSP032_ID_EBONY_WINGS; unionCaseMaxRankB = 8;
            unionCaseRequiredPassive = 0;
            unionCaseOutputSystem = DSP042PairedRows.SYSTEM_VANDALIER;
            unionCaseOutputRank = 8;
            unionCaseSourceId = 2810; unionCaseLabel = "VANDALIER";
        }
        else if (unionIndex == 1)
        {
            unionCaseRecipeId = DSP032_RECIPE_UNION_PHIERAGGI;
            unionCaseInputA = DSP032_ID_PHIERA; unionCaseMaxRankA = 8;
            unionCaseInputB = DSP032_ID_EIGHT; unionCaseMaxRankB = 8;
            unionCaseRequiredPassive = DSP032_ID_TIRAJISU;
            unionCaseOutputSystem = DSP042PairedRows.SYSTEM_PHIERAGGI;
            unionCaseOutputRank = 1;
            unionCaseSourceId = 2811; unionCaseLabel = "PHIERAGGI";
        }
        else
        {
            unionCaseRecipeId = DSP032_RECIPE_UNION_FUWALAFUWALOO;
            unionCaseInputA = DSP032_ID_VENTO_SACRO; unionCaseMaxRankA = 8;
            // Bloody Tear has no P042 firing system of its own (the union
            // output IS its evolved form per the contract's "none (the
            // evolved weapon is the input)"), so it is set only as a P032
            // inventory occupant below, never equipped into the P042
            // schedule.
            unionCaseInputB = DSP032_ID_BLOODY_TEAR; unionCaseMaxRankB = 1;
            unionCaseRequiredPassive = 0;
            unionCaseOutputSystem = DSP042PairedRows.SYSTEM_FUWALA;
            unionCaseOutputRank = 1;
            unionCaseSourceId = 2812; unionCaseLabel = "FUWALAFUWALOO";
        }
    }

    // caseIndex layout: unionIndex = caseIndex/4, variant = caseIndex%4
    // (0=FULL+AB, 1=FULL+BA, 2=EXTRA+AB, 3=EXTRA+BA).
    void SetupUnionCase(int caseIndex)
    {
        int unionIndex = caseIndex / 4;
        int variant = caseIndex % 4;
        bool orderAB = (variant % 2) == 0;
        bool extra = variant >= 2;
        UnionSpecFor(unionIndex);

        DSP032ResetInventory();
        DSP042ResetPairedRuntime(429100 + caseIndex);
        unionCaseWeaponIndexA = -1; unionCaseWeaponIndexB = -1;
        unionCaseSurvivingIndex = -1; unionCaseCancelledIndex = -1;
        unionCaseReuseIndex = -1; unionCaseUnionTic = -1;

        if (orderAB)
        {
            DSP032SetItem(unionCaseInputA, unionCaseMaxRankA);
            if (DSP042SystemExistsForId(unionCaseInputA))
                unionCaseWeaponIndexA = EquipWeapon(unionCaseInputA, unionCaseMaxRankA);
            DSP032SetItem(unionCaseInputB, unionCaseMaxRankB);
            if (DSP042SystemExistsForId(unionCaseInputB))
                unionCaseWeaponIndexB = EquipWeapon(unionCaseInputB, unionCaseMaxRankB);
        }
        else
        {
            DSP032SetItem(unionCaseInputB, unionCaseMaxRankB);
            if (DSP042SystemExistsForId(unionCaseInputB))
                unionCaseWeaponIndexB = EquipWeapon(unionCaseInputB, unionCaseMaxRankB);
            DSP032SetItem(unionCaseInputA, unionCaseMaxRankA);
            if (DSP042SystemExistsForId(unionCaseInputA))
                unionCaseWeaponIndexA = EquipWeapon(unionCaseInputA, unionCaseMaxRankA);
        }
        if (unionCaseRequiredPassive > 0) DSP032SetItem(unionCaseRequiredPassive, 1);

        // Fillers occupy the remaining weapon slots with distinct fixture
        // weapons (existing DSP032_FIXTURE_UNION_FILLER_* weapon-category
        // ids) so the transaction is proven under a full inventory, not an
        // otherwise-empty one. FULL uses A-D (6 occupied of 6); EXTRA adds
        // one extra slot and E to fill it too (7 occupied of 7).
        // FILLER_F is deliberately never occupied here -- it is reserved so
        // the later reuse-equip step always has a fresh, never-used id.
        DSP032SetItem(DSP032_FIXTURE_UNION_FILLER_A, 1);
        DSP032SetItem(DSP032_FIXTURE_UNION_FILLER_B, 1);
        DSP032SetItem(DSP032_FIXTURE_UNION_FILLER_C, 1);
        DSP032SetItem(DSP032_FIXTURE_UNION_FILLER_D, 1);
        if (extra)
        {
            dsp032WeaponExtraSlots = 1;
            DSP032SetItem(DSP032_FIXTURE_UNION_FILLER_E, 1);
        }

        Console.Printf("DS_P042_MAP28_CASE_SETUP case_index=%d union=%s order=%s config=%s weapon_index_a=%d weapon_index_b=%d recipe=%d passive=%d", caseIndex, unionCaseLabel, orderAB ? "AB" : "BA", extra ? "EXTRA" : "FULL", unionCaseWeaponIndexA, unionCaseWeaponIndexB, unionCaseRecipeId, unionCaseRequiredPassive);
    }

    // Applies the real P032 predicate + atomic slot transaction, then
    // mirrors it into the P042 firing schedule: the weaponIndex whose input
    // occupied the LOWER P032 inventory slot is evolved in place (keeps its
    // entity slot/generation/id, so attribution stays continuous); the
    // other is cancelled (contract "free a weapon slot", "old attacks are
    // not retained"). When one input has no P042 schedule entry at all
    // (Bloody Tear), the surviving side is simply whichever weaponIndex
    // exists.
    void ApplyUnionCase(int caseIndex, int logicalTic)
    {
        int hashBefore = DSP032InventoryHash();
        int idxA = DSP032IndexOf(unionCaseInputA);
        int idxB = DSP032IndexOf(unionCaseInputB);
        int passiveRankBefore = unionCaseRequiredPassive > 0
            ? DSP032Rank(unionCaseRequiredPassive) : 0;
        bool ready = DSP032CanApplyRecipe(unionCaseRecipeId, DSP032_GRAPH_CHEST_SILVER,
            true, true);
        int txId = 429200 + caseIndex;
        bool applied = ready && DSP032ApplyRecipe(unionCaseRecipeId, unionCaseSourceId,
            DSP032_GRAPH_CHEST_SILVER, true, true, txId);
        bool evolved = false;
        int lowerIndex = -1; int higherIndex = -1;
        if (applied)
        {
            if (unionCaseWeaponIndexB < 0) { lowerIndex = unionCaseWeaponIndexA; }
            else if (unionCaseWeaponIndexA < 0) { lowerIndex = unionCaseWeaponIndexB; }
            else if (idxA <= idxB)
            { lowerIndex = unionCaseWeaponIndexA; higherIndex = unionCaseWeaponIndexB; }
            else
            { lowerIndex = unionCaseWeaponIndexB; higherIndex = unionCaseWeaponIndexA; }
            if (lowerIndex >= 0)
                evolved = DSP042EvolveInPlace(lowerIndex, unionCaseOutputSystem,
                    unionCaseOutputRank, logicalTic);
            if (evolved) DSP032SetItem(unionCaseOutputSystem, unionCaseOutputRank);
            if (higherIndex >= 0) DSP042CancelWeapon(higherIndex, logicalTic);
        }
        unionCaseSurvivingIndex = lowerIndex;
        unionCaseCancelledIndex = higherIndex;
        unionCaseUnionTic = logicalTic;
        int expectedInsertAt = idxA <= idxB ? idxA : idxB;
        int outputIndexAfter = DSP032IndexOf(unionCaseOutputSystem);
        int passiveRankAfter = unionCaseRequiredPassive > 0
            ? DSP032Rank(unionCaseRequiredPassive) : 0;
        int hashAfter = DSP032InventoryHash();
        Console.Printf("DS_P042_MAP28_UNION case_index=%d tic=%d recipe=%d accepted=%d evolved=%d idx_a=%d idx_b=%d expected_insert_at=%d output_index_after=%d lower_weapon_index=%d higher_weapon_index=%d passive_id=%d passive_rank_before=%d passive_rank_after=%d hash_before=%d hash_after=%d", caseIndex, logicalTic, unionCaseRecipeId, applied ? 1 : 0, evolved ? 1 : 0, idxA, idxB, expectedInsertAt, outputIndexAfter, lowerIndex, higherIndex, unionCaseRequiredPassive, passiveRankBefore, passiveRankAfter, hashBefore, hashAfter);
    }

    // Proves the exactly-one slot freed by the union is real spendable
    // capacity: a brand-new fixture weapon (id never touched by this case)
    // must be acquirable and equippable, and then able to fire.
    void DSP042ReuseCapacityCheck(int caseIndex, int logicalTic)
    {
        int reuseId = DSP032_ID_BRACELET;
        int maxRank = DSP032MaxRankForItem(reuseId);
        bool canAcquire = DSP032CanAcquireItem(reuseId, 1, maxRank);
        bool acquired = canAcquire
            && DSP032AcquireItem(reuseId, 1, maxRank, 429300 + caseIndex);
        if (acquired)
            unionCaseReuseIndex = EquipWeapon(DSP042PairedRows.SYSTEM_BRACELET, 1);
        Console.Printf("DS_P042_MAP28_REUSE case_index=%d tic=%d can_acquire=%d acquired=%d reuse_weapon_index=%d hash_after=%d", caseIndex, logicalTic, canAcquire ? 1 : 0, acquired ? 1 : 0, unionCaseReuseIndex, DSP032InventoryHash());
    }

    void EmitUnionSnapshot(int caseIndex, String label, int logicalTic)
    {
        for (int i = 0; i < dsp032ItemIds.Size(); i++)
            Console.Printf("DS_P042_MAP28_SNAPSHOT case_index=%d label=%s tic=%d slot=%d item_id=%d rank=%d", caseIndex, label, logicalTic, i, dsp032ItemIds[i], dsp032ItemRanks[i]);
        Console.Printf("DS_P042_MAP28_SNAPSHOT_SUMMARY case_index=%d label=%s tic=%d weapon_count=%d passive_count=%d weapon_extra=%d passive_extra=%d hash=%d", caseIndex, label, logicalTic, DSP032OwnedSlots(DSP032_CATEGORY_WEAPON), DSP032OwnedSlots(DSP032_CATEGORY_PASSIVE), dsp032WeaponExtraSlots, dsp032PassiveExtraSlots, DSP032InventoryHash());
    }

    // ---- union_negative: predicate rejections + duplicate-after-success ---

    void RunUnionNegativeTic()
    {
        int caseIndex = logicalTic / DS_NEG_TICS_PER_CASE;
        int caseTic = logicalTic % DS_NEG_TICS_PER_CASE;
        if (caseIndex >= DS_NEG_CASE_COUNT) return;
        if (caseTic == 0) RunNegativeCase(caseIndex, logicalTic);
        else if (caseTic == 1 && caseIndex == 3) RunNegativeDuplicateAttempt(logicalTic);
    }

    // caseIndex 0: non-max input (Peachone rank 7 of 8). 1: missing required
    // passive (Tirajisu absent for the Phieraggi union). 2: non-evolution
    // chest context (chestSubtype != DSP032_GRAPH_CHEST_SILVER). 3: a
    // legitimate success, immediately followed (RunNegativeDuplicateAttempt)
    // by a second union attempt on the now-already-owned output.
    void RunNegativeCase(int caseIndex, int logicalTic)
    {
        DSP032ResetInventory();
        DSP042ResetPairedRuntime(429500 + caseIndex);
        String reason; int recipeId; int chest;
        if (caseIndex == 0)
        {
            reason = "NON_MAX_INPUT";
            recipeId = DSP032_RECIPE_UNION_VANDALIER; chest = DSP032_GRAPH_CHEST_SILVER;
            DSP032SetItem(DSP032_ID_PEACHONE, 7);
            DSP032SetItem(DSP032_ID_EBONY_WINGS, 8);
        }
        else if (caseIndex == 1)
        {
            reason = "MISSING_REQUIRED_PASSIVE";
            recipeId = DSP032_RECIPE_UNION_PHIERAGGI; chest = DSP032_GRAPH_CHEST_SILVER;
            DSP032SetItem(DSP032_ID_PHIERA, 8);
            DSP032SetItem(DSP032_ID_EIGHT, 8);
            // Tirajisu deliberately left unowned.
        }
        else if (caseIndex == 2)
        {
            reason = "NON_EVOLUTION_CHEST";
            recipeId = DSP032_RECIPE_UNION_FUWALAFUWALOO; chest = 1;
            DSP032SetItem(DSP032_ID_VENTO_SACRO, 8);
            DSP032SetItem(DSP032_ID_BLOODY_TEAR, 1);
        }
        else
        {
            reason = "FIRST_SUCCESS_THEN_DUPLICATE";
            recipeId = DSP032_RECIPE_UNION_VANDALIER; chest = DSP032_GRAPH_CHEST_SILVER;
            DSP032SetItem(DSP032_ID_PEACHONE, 8);
            DSP032SetItem(DSP032_ID_EBONY_WINGS, 8);
        }
        negRecipeId = recipeId; negChest = chest; negCaseLabel = reason;
        int hashBefore = DSP032InventoryHash();
        bool ready = DSP032CanApplyRecipe(recipeId, chest, true, true);
        int txId = 429600 + caseIndex;
        bool accepted = ready && DSP032ApplyRecipe(recipeId, 2900 + caseIndex,
            chest, true, true, txId);
        int hashAfter = DSP032InventoryHash();
        int expectedAccepted = caseIndex == 3 ? 1 : 0;
        negHashAfterAttempt = hashAfter;
        Console.Printf("DS_P042_MAP28_NEG_CASE case_index=%d tic=%d reason=%s recipe=%d chest=%d accepted=%d expected_accepted=%d hash_before=%d hash_after=%d hash_unchanged=%d", caseIndex, logicalTic, reason, recipeId, chest, accepted ? 1 : 0, expectedAccepted, hashBefore, hashAfter, (hashBefore == hashAfter) ? 1 : 0);
    }

    void RunNegativeDuplicateAttempt(int logicalTic)
    {
        int hashBefore = negHashAfterAttempt;
        bool ready = DSP032CanApplyRecipe(negRecipeId, negChest, true, true);
        int txId = 429700;
        bool accepted = ready && DSP032ApplyRecipe(negRecipeId, 2999, negChest,
            true, true, txId);
        int hashAfter = DSP032InventoryHash();
        Console.Printf("DS_P042_MAP28_NEG_CASE case_index=3 tic=%d reason=DUPLICATE_AFTER_SUCCESS recipe=%d chest=%d accepted=%d expected_accepted=0 hash_before=%d hash_after=%d hash_unchanged=%d", logicalTic, negRecipeId, negChest, accepted ? 1 : 0, hashBefore, hashAfter, (hashBefore == hashAfter) ? 1 : 0);
    }

    // ---- attribution (A02): all eleven systems concurrently, Might scaling,
    // Fuwalafuwaloo's streak exemption, and a mid-run union's attribution
    // switch -----------------------------------------------------------------

    bool SetupAttribution()
    {
        attrTargetSlot = SpawnTarget(playerX, playerY, "ATTRIBUTION_TARGET", 50.0);
        if (attrTargetSlot < 0) return false;
        attrTargetGeneration = generations[attrTargetSlot];
        attrTargetId = ids[attrTargetSlot];

        attrWeaponPhiera = EquipWeapon(DSP042PairedRows.SYSTEM_PHIERA, 8);
        attrWeaponEight = EquipWeapon(DSP042PairedRows.SYSTEM_EIGHT, 8);
        attrWeaponPhieraggi = EquipWeapon(DSP042PairedRows.SYSTEM_PHIERAGGI, 1);
        attrWeaponVento = EquipWeapon(DSP042PairedRows.SYSTEM_VENTO, 8);
        attrWeaponFuwala = EquipWeapon(DSP042PairedRows.SYSTEM_FUWALA, 1);
        attrWeaponBracelet = EquipWeapon(DSP042PairedRows.SYSTEM_BRACELET, 6);
        attrWeaponBiBracelet = EquipWeapon(DSP042PairedRows.SYSTEM_BI_BRACELET, 6);
        attrWeaponTriBracelet = EquipWeapon(DSP042PairedRows.SYSTEM_TRI_BRACELET, 6);
        attrWeaponPeachone = EquipWeapon(DSP042PairedRows.SYSTEM_PEACHONE, 8);
        attrWeaponEbony = EquipWeapon(DSP042PairedRows.SYSTEM_EBONY, 8);

        // Peachone/Ebony Wings need a matching P032 occupancy so the mid-run
        // Vandalier union recipe (ApplyAttributionUnion) actually predicate-
        // passes; every other system here is equipped directly via
        // DSP042EquipFixture (bypassing P032 entirely), the same
        // CONTROLLED_ENGINE_FIXTURE convention chain/boot already use.
        DSP032SetItem(DSP032_ID_PEACHONE, 8);
        DSP032SetItem(DSP032_ID_EBONY_WINGS, 8);

        attrUnionSurvivingIndex = -1; attrUnionCancelledIndex = -1;

        return attrTargetSlot >= 0 && attrWeaponPhiera >= 0 && attrWeaponEight >= 0
            && attrWeaponPhieraggi >= 0 && attrWeaponVento >= 0 && attrWeaponFuwala >= 0
            && attrWeaponBracelet >= 0 && attrWeaponBiBracelet >= 0
            && attrWeaponTriBracelet >= 0 && attrWeaponPeachone >= 0 && attrWeaponEbony >= 0;
    }

    // Real P032 predicate + atomic transaction (same shape as
    // ApplyUnionCase), evolving the lower-indexed input in place to
    // Vandalier and cancelling the other -- proves the mid-run "switches
    // attribution to the output system for new emissions only" requirement
    // while the other ten systems keep firing concurrently around it.
    void ApplyAttributionUnion(int logicalTic)
    {
        int idxA = DSP032IndexOf(DSP032_ID_PEACHONE);
        int idxB = DSP032IndexOf(DSP032_ID_EBONY_WINGS);
        bool ready = DSP032CanApplyRecipe(DSP032_RECIPE_UNION_VANDALIER,
            DSP032_GRAPH_CHEST_SILVER, true, true);
        bool applied = ready && DSP032ApplyRecipe(DSP032_RECIPE_UNION_VANDALIER, 2820,
            DSP032_GRAPH_CHEST_SILVER, true, true, 428100);
        int lowerIndex = -1; int higherIndex = -1;
        bool evolved = false;
        if (applied)
        {
            if (idxA <= idxB) { lowerIndex = attrWeaponPeachone; higherIndex = attrWeaponEbony; }
            else { lowerIndex = attrWeaponEbony; higherIndex = attrWeaponPeachone; }
            evolved = DSP042EvolveInPlace(lowerIndex, DSP042PairedRows.SYSTEM_VANDALIER, 8, logicalTic);
            if (evolved) DSP032SetItem(DSP042PairedRows.SYSTEM_VANDALIER, 8);
            if (higherIndex >= 0) DSP042CancelWeapon(higherIndex, logicalTic);
        }
        attrUnionSurvivingIndex = lowerIndex;
        attrUnionCancelledIndex = higherIndex;
        Console.Printf("DS_P042_MAP28_ATTR_UNION tic=%d accepted=%d evolved=%d surviving_weapon_index=%d cancelled_weapon_index=%d", logicalTic, applied ? 1 : 0, evolved ? 1 : 0, lowerIndex, higherIndex);
    }

    void RunAttributionTic()
    {
        // Drives the shared movement-streak ledger every tic with a
        // throwaway coordinate that is NEVER passed to any DSP042FireVolley
        // call below (movement detection only cares whether position
        // changed, per DSP042UpdateMoveStreak's own contract) so Vento's
        // (+1/35 ticks, cap 5) and Fuwalafuwaloo's (+8/35 ticks, cap 40)
        // streak bonus reach a real nonzero value well inside this window,
        // without waiting on their own ~2s firing cadence.
        DSP042UpdateMoveStreak(double(logicalTic) * 0.25, 0.0,
            DSP042PairedRows.MovementStreakStepMilli(DSP042PairedRows.SYSTEM_FUWALA, 1),
            DSP042PairedRows.MovementStreakCapMilli(DSP042PairedRows.SYSTEM_FUWALA, 1));

        if (logicalTic == DS_ATTR_UNION_AT_TIC) ApplyAttributionUnion(logicalTic);

        int mightMilli = DS_ATTR_MIGHT_MILLI;
        int luckMilli = DS_ATTR_LUCK_MILLI;
        DSP042FireVolley(attrWeaponPhiera, logicalTic, 0, playerX, playerY, 1000, mightMilli, luckMilli);
        DSP042FireVolley(attrWeaponEight, logicalTic, 0, playerX, playerY, 1000, mightMilli, luckMilli);
        DSP042FireVolley(attrWeaponPhieraggi, logicalTic, 0, playerX, playerY, 1000, mightMilli, luckMilli);
        DSP042FireVolley(attrWeaponVento, logicalTic, 0, playerX, playerY, 1000, mightMilli, luckMilli);
        DSP042FireVolley(attrWeaponFuwala, logicalTic, 0, playerX, playerY, 1000, mightMilli, luckMilli);
        DSP042FireVolley(attrWeaponBracelet, logicalTic, 0, playerX, playerY, 1000, mightMilli, luckMilli);
        DSP042FireVolley(attrWeaponBiBracelet, logicalTic, 0, playerX, playerY, 1000, mightMilli, luckMilli);
        DSP042FireVolley(attrWeaponTriBracelet, logicalTic, 0, playerX, playerY, 1000, mightMilli, luckMilli);
        // Peachone/Ebony Wings fire pre-union only; post-union one index is
        // Vandalier (fires normally) and the other is a cancelled no-op --
        // calling both every tic unconditionally is what proves that.
        DSP042FireVolley(attrWeaponPeachone, logicalTic, 0, playerX, playerY, 1000, mightMilli, luckMilli);
        DSP042FireVolley(attrWeaponEbony, logicalTic, 0, playerX, playerY, 1000, mightMilli, luckMilli);
    }

    // ---- patterns (FP01): mirrored bird rotation, Phiera/Eight facing vs
    // fixed-plane diagonals, Phieraggi's 15 deg/volley advance -------------

    bool SetupPatterns()
    {
        patTargetSlot = SpawnTarget(playerX, playerY, "PATTERNS_TARGET", 80.0);
        if (patTargetSlot < 0) return false;
        patTargetGeneration = generations[patTargetSlot];
        patTargetId = ids[patTargetSlot];
        patWeaponPeachone = EquipWeapon(DSP042PairedRows.SYSTEM_PEACHONE, 8);
        patWeaponEbony = EquipWeapon(DSP042PairedRows.SYSTEM_EBONY, 8);
        patWeaponPhiera = EquipWeapon(DSP042PairedRows.SYSTEM_PHIERA, 8);
        patWeaponEight = EquipWeapon(DSP042PairedRows.SYSTEM_EIGHT, 8);
        patWeaponPhieraggi = EquipWeapon(DSP042PairedRows.SYSTEM_PHIERAGGI, 1);
        patBodyYawMilli = ReadBodyYawMilli();
        Console.Printf("DS_P042_MAP28_PATTERNS_SETUP body_yaw_milli=%d camera_variant=%d", patBodyYawMilli, cameraVariant);
        return patTargetSlot >= 0 && patWeaponPeachone >= 0 && patWeaponEbony >= 0
            && patWeaponPhiera >= 0 && patWeaponEight >= 0 && patWeaponPhieraggi >= 0;
    }

    void RunPatternsTic()
    {
        DSP042FireVolley(patWeaponPeachone, logicalTic, patBodyYawMilli, playerX, playerY, 1000, 1000, 1000);
        DSP042FireVolley(patWeaponEbony, logicalTic, patBodyYawMilli, playerX, playerY, 1000, 1000, 1000);
        DSP042FireVolley(patWeaponPhiera, logicalTic, patBodyYawMilli, playerX, playerY, 1000, 1000, 1000);
        DSP042FireVolley(patWeaponEight, logicalTic, patBodyYawMilli, playerX, playerY, 1000, 1000, 1000);
        DSP042FireVolley(patWeaponPhieraggi, logicalTic, patBodyYawMilli, playerX, playerY, 1000, 1000, 1000);
    }

    // ---- burst_union: a union mid-burst (pending gun children cancelled),
    // an unrelated simultaneous rank upgrade applying exactly once ---------

    bool SetupBurstUnion()
    {
        burstTargetSlot = SpawnTarget(playerX, playerY, "BURST_TARGET", 50.0);
        if (burstTargetSlot < 0) return false;
        burstTargetGeneration = generations[burstTargetSlot];
        burstTargetId = ids[burstTargetSlot];

        DSP032SetItem(DSP032_ID_PHIERA, 8);
        DSP032SetItem(DSP032_ID_EIGHT, 8);
        DSP032SetItem(DSP032_ID_TIRAJISU, 1);
        DSP032SetItem(DSP032_ID_BRACELET, 5);

        burstWeaponPhiera = EquipWeapon(DSP042PairedRows.SYSTEM_PHIERA, 8);
        burstWeaponEight = EquipWeapon(DSP042PairedRows.SYSTEM_EIGHT, 8);
        burstWeaponBracelet = EquipWeapon(DSP042PairedRows.SYSTEM_BRACELET, 5);

        burstUnionSurvivingIndex = -1; burstUnionCancelledIndex = -1;
        burstHashBeforeUnion = 0; burstHashAfterUnion = 0;

        return burstTargetSlot >= 0 && burstWeaponPhiera >= 0 && burstWeaponEight >= 0
            && burstWeaponBracelet >= 0;
    }

    void ApplyBurstUnion(int logicalTic)
    {
        int hashBefore = DSP032InventoryHash();
        int idxA = DSP032IndexOf(DSP032_ID_PHIERA);
        int idxB = DSP032IndexOf(DSP032_ID_EIGHT);
        bool ready = DSP032CanApplyRecipe(DSP032_RECIPE_UNION_PHIERAGGI,
            DSP032_GRAPH_CHEST_SILVER, true, true);
        bool applied = ready && DSP032ApplyRecipe(DSP032_RECIPE_UNION_PHIERAGGI, 2830,
            DSP032_GRAPH_CHEST_SILVER, true, true, 428200);
        int lowerIndex = -1; int higherIndex = -1;
        bool evolved = false;
        if (applied)
        {
            if (idxA <= idxB) { lowerIndex = burstWeaponPhiera; higherIndex = burstWeaponEight; }
            else { lowerIndex = burstWeaponEight; higherIndex = burstWeaponPhiera; }
            evolved = DSP042EvolveInPlace(lowerIndex, DSP042PairedRows.SYSTEM_PHIERAGGI, 1, logicalTic);
            if (evolved) DSP032SetItem(DSP042PairedRows.SYSTEM_PHIERAGGI, 1);
            if (higherIndex >= 0) DSP042CancelWeapon(higherIndex, logicalTic);
        }
        burstUnionSurvivingIndex = lowerIndex;
        burstUnionCancelledIndex = higherIndex;
        burstHashBeforeUnion = hashBefore;
        Console.Printf("DS_P042_MAP28_BURST_UNION tic=%d accepted=%d evolved=%d surviving_weapon_index=%d cancelled_weapon_index=%d hash_before=%d", logicalTic, applied ? 1 : 0, evolved ? 1 : 0, lowerIndex, higherIndex, hashBefore);
    }

    // Unrelated Bracelet rank 5 -> 6 "upgrade" applied at the exact same
    // logical tic as the union above, via the same DSP042EvolveInPlace path
    // a real level-up would use (same-system, new rank, same weaponIndex/
    // slot identity) -- proves it applies exactly once and independently of
    // the concurrent union transaction.
    void ApplyUnrelatedUpgrade(int logicalTic)
    {
        bool evolved = DSP042EvolveInPlace(burstWeaponBracelet, DSP042PairedRows.SYSTEM_BRACELET, 6, logicalTic);
        if (evolved) DSP032SetItem(DSP032_ID_BRACELET, 6);
        burstHashAfterUnion = DSP032InventoryHash();
        Console.Printf("DS_P042_MAP28_BURST_UPGRADE tic=%d weapon_index=%d evolved=%d new_rank=6 hash_after=%d", logicalTic, burstWeaponBracelet, evolved ? 1 : 0, burstHashAfterUnion);
    }

    void RunBurstUnionTic()
    {
        if (logicalTic == DS_BURST_VOLLEY_TIC)
        {
            // Rank 8 amount=3, interval_tics=7: ordinal 0 spawns now;
            // ordinals 1/2 become pending children due at +7/+14 -- both
            // AFTER DS_BURST_UNION_TIC below, so both must be cancelled,
            // never emitted.
            DSP042FireVolley(burstWeaponPhiera, logicalTic, 0, playerX, playerY, 1000, 1000, 1000);
            DSP042FireVolley(burstWeaponEight, logicalTic, 0, playerX, playerY, 1000, 1000, 1000);
        }
        else if (logicalTic == DS_BURST_UNION_TIC)
        {
            ApplyBurstUnion(logicalTic);
            ApplyUnrelatedUpgrade(logicalTic);
        }
        if (logicalTic > DS_BURST_UNION_TIC)
        {
            if (burstUnionSurvivingIndex >= 0)
                DSP042FireVolley(burstUnionSurvivingIndex, logicalTic, 0, playerX, playerY, 1000, 1000, 1000);
            DSP042FireVolley(burstWeaponBracelet, logicalTic, 0, playerX, playerY, 1000, 1000, 1000);
        }
    }

    // ==== vento_streak: movement-streak growth/reset (item 1) ================
    //
    // The player oscillates in place every tic (int(x*1000) flips each tic,
    // so DSP042TickMoveStreak's own "position actually changed" test reports
    // continuous movement) through DS_STREAK_MOVE1_END_TIC, holds perfectly
    // still (no position change at all) through DS_STREAK_STOP_END_TIC, then
    // resumes oscillating through DS_STREAK_MOVE2_END_TIC. Every tic's exact
    // position is logged (DS_P042_MAP28_STREAK_TICK) so run_p042_paired.py's
    // validator can replay DSP042TickMoveStreak's own algorithm byte-for-byte
    // from the trace and independently recompute the expected streak bonus/
    // damage for every DS_P042_HIT row this mode emits.
    bool SetupVentoStreak()
    {
        streakTargetSlot = SpawnTarget(0.0, 0.0, "STREAK_TARGET", 250.0);
        if (streakTargetSlot < 0) return false;
        streakTargetGeneration = generations[streakTargetSlot];
        streakTargetId = ids[streakTargetSlot];
        streakWeaponVento = EquipWeapon(DSP042PairedRows.SYSTEM_VENTO,
            DSP042PairedRows.RankCount(DSP042PairedRows.SYSTEM_VENTO));
        streakWeaponFuwala = EquipWeapon(DSP042PairedRows.SYSTEM_FUWALA, 1);
        return streakTargetSlot >= 0 && streakWeaponVento >= 0 && streakWeaponFuwala >= 0;
    }

    // Oscillating-in-place motion: alternates the player's X coordinate by a
    // sub-collision, sub-reach delta (0.0 <-> 0.01) large enough that
    // int(x*1000) differs every tic (registers as "moved") but small enough
    // to stay inside STREAK_TARGET's giant capture radius. facingYawMilli is
    // recomputed to look straight at the fixed (0,0) target every tic, so
    // the facing-arc adapter itself is never in question here -- this mode
    // isolates the movement-streak FORMULA, not arc geometry (already
    // covered by "patterns").
    void DriveStreakMovement(bool moving)
    {
        if (moving) playerX = (logicalTic % 2 == 0) ? 0.0 : 0.01;
        DSP042TickMoveStreak(playerX, playerY);
        double dx = 0.0 - playerX; double dy = 0.0 - playerY;
        int facingYawMilli = (dx == 0.0 && dy == 0.0) ? 0
            : int(atan2(dy, dx) * 180.0 / 3.14159265358979 * 1000.0);
        Console.Printf("DS_P042_MAP28_STREAK_TICK tic=%d x=%.6f y=%.6f moving=%d", logicalTic, playerX, playerY, moving ? 1 : 0);
        DSP042FireVolley(streakWeaponVento, logicalTic, facingYawMilli, playerX, playerY, 1000, 1000, 1000);
        DSP042FireVolley(streakWeaponFuwala, logicalTic, facingYawMilli, playerX, playerY, 1000, 1000, 1000);
    }

    void RunVentoStreakTic()
    {
        bool moving = logicalTic <= DS_STREAK_MOVE1_END_TIC
            || logicalTic > DS_STREAK_STOP_END_TIC;
        DriveStreakMovement(moving);
    }

    // ==== fuwala_heal: crit healing through the P039 authority (item 2) =====
    //
    // DSP042FireVolley never forwards heal-gate parameters (no existing mode
    // needs them), so this drives DSP042FireFuwalaHealTestVolley
    // (PairedRuntime.zs) directly -- a thin, save-scope-local wrapper added
    // alongside it that duplicates only FireVolley's cooldown bookkeeping,
    // so every other mode's DSP042FireVolley call sites are untouched.
    bool SetupFuwalaHeal()
    {
        healTargetSlot = SpawnTarget(0.0, 0.0, "HEAL_TARGET", 250.0);
        if (healTargetSlot < 0) return false;
        healTargetGeneration = generations[healTargetSlot];
        healTargetId = ids[healTargetSlot];
        healWeaponFuwala = EquipWeapon(DSP042PairedRows.SYSTEM_FUWALA, 1);
        healPlayerMaxHealthMilli = 1000000;
        healPlayerHealthMilli = 500000;
        healForcedVolleyTicA = DS_HEAL_NORMAL_VOLLEYS * DS_HEAL_VOLLEY_PERIOD + 10;
        healForcedVolleyTicB = healForcedVolleyTicA + DS_HEAL_VOLLEY_PERIOD;
        healForcedVolleyTicC = DS_HEAL_CAP_SETUP_TIC + 70;
        return healTargetSlot >= 0 && healWeaponFuwala >= 0;
    }

    // luckMilli=DS_HEAL_FORCE_LUCK_MILLI (25000) boosts the rows' 5% base
    // chance to 1250 milli, clamped to 1000 (100%) by
    // DSP042RollCritOnState/DSP042RollCrit -- a real, caller-supplied Luck
    // value driving the SAME production roll, not a fixture-only bypass.
    // Fuwala's amount=8: all 8 slashes land on HEAL_TARGET in the same tic,
    // every one forced critical, so the FIRST accepted heal opens the gate
    // and every remaining slash that same tic is a real, deterministic
    // "crit inside the gate" rejection -- no RNG-dependent luck needed for
    // that half of the acceptance matrix.
    void FireHealVolley(int luckMilli, String label)
    {
        int before = healPlayerHealthMilli;
        int healedMilli = DSP042FireFuwalaHealTestVolley(healWeaponFuwala,
            logicalTic, 0, 0.0, 0.0, 1000, 1000, luckMilli,
            healPlayerHealthMilli, healPlayerMaxHealthMilli);
        if (healedMilli > 0)
        {
            healPlayerHealthMilli += healedMilli;
            if (healPlayerHealthMilli > healPlayerMaxHealthMilli)
                healPlayerHealthMilli = healPlayerMaxHealthMilli;
        }
        Console.Printf("DS_P042_MAP28_HEAL_VOLLEY tic=%d label=%s luck_milli=%d health_before=%d healed_milli=%d health_after=%d max_health=%d", logicalTic, label, luckMilli, before, healedMilli, healPlayerHealthMilli, healPlayerMaxHealthMilli);
    }

    // Seeded, isolated statistical audit of Fuwala/Vento's shared P042_CRIT
    // roll, mirroring RunOneCherryAuditChance/RunIsolatedCherryRngAudit
    // (BounceMap27Runtime.zs): calls the REAL production roll function
    // (DSP042RollCritOnState, the exact formula DSP042RollCrit uses) against
    // a dedicated LOCAL audit-state variable, never the live dsp042CritRng
    // gameplay stream, then proves that live stream is byte-identical
    // before/after the audit.
    void RunOneCritAuditChance(int chanceMilli, int trials, out int auditState)
    {
        int crits = 0;
        for (int i = 0; i < trials; i++)
        {
            int rngBefore; int rngAfter; int rollMilli;
            bool critical = DSP042RollCritOnState(auditState, chanceMilli, 1000,
                rngBefore, rngAfter, rollMilli);
            auditState = rngAfter;
            if (critical) crits++;
        }
        double observedRate = double(crits) / double(trials);
        double expectedRate = double(chanceMilli) / 1000.0;
        double deltaMilli = (observedRate - expectedRate) * 1000.0;
        Console.Printf("DS_P042_CRIT_RNG_AUDIT chance_milli=%d trials=%d crits=%d observed_rate_milli=%d expected_rate_milli=%d delta_milli=%.3f isolated_seed=1 rng_stream=ISOLATED_AUDIT_STATE production_function=DSP042RollCritOnState", chanceMilli, trials, crits, int(observedRate * 1000.0), chanceMilli, deltaMilli);
    }

    void RunIsolatedFuwalaCritAudit()
    {
        int liveBefore = dsp042CritRng;
        int auditState = 991913 + logicalTic;
        RunOneCritAuditChance(DSP042PairedRows.CRIT_CHANCE_MILLI, 12000, auditState);
        int liveAfter = dsp042CritRng;
        Console.Printf("DS_P042_CRIT_RNG_LIVE_UNCHANGED before=%d after=%d equal=%d", liveBefore, liveAfter, liveBefore == liveAfter ? 1 : 0);
    }

    void RunFuwalaHealTic()
    {
        if (logicalTic == 2) RunIsolatedFuwalaCritAudit();
        for (int v = 1; v <= DS_HEAL_NORMAL_VOLLEYS; v++)
            if (logicalTic == 1 + (v - 1) * DS_HEAL_VOLLEY_PERIOD)
                FireHealVolley(1000, "NORMAL");
        if (logicalTic == healForcedVolleyTicA) FireHealVolley(DS_HEAL_FORCE_LUCK_MILLI, "FORCED_A");
        if (logicalTic == healForcedVolleyTicB) FireHealVolley(DS_HEAL_FORCE_LUCK_MILLI, "FORCED_B");
        if (logicalTic == DS_HEAL_CAP_SETUP_TIC)
        {
            healPlayerHealthMilli = healPlayerMaxHealthMilli - 3000;
            Console.Printf("DS_P042_MAP28_HEAL_CAP_SETUP tic=%d health_before=%d max_health=%d", logicalTic, healPlayerHealthMilli, healPlayerMaxHealthMilli);
        }
        if (logicalTic == healForcedVolleyTicC) FireHealVolley(DS_HEAL_FORCE_LUCK_MILLI, "FORCED_C_CAP");
    }

    // ==== pause: real native menu pause (item 3) ==============================
    //
    // Bridge copied from BounceMap27Runtime.zs's MAP27 pattern verbatim
    // (own event names): UiTick requests a native pause via the MainMenu at
    // ui_tic>=5, holds it ~1s, then closes it; NetworkProcess/InterfaceProcess
    // carry the request/ack across the ui/logic boundary and compare the
    // exact DSP042PersistenceHash before/after.
    bool SetupPause()
    {
        pauseTargetSlot = SpawnTarget(60.0, 0.0, "PAUSE_TARGET", 6.0);
        if (pauseTargetSlot < 0) return false;
        pauseTargetGeneration = generations[pauseTargetSlot];
        pauseTargetId = ids[pauseTargetSlot];
        DSP032SetItem(DSP032_ID_BRACELET, 6);
        pauseWeaponBracelet = EquipWeapon(DSP042PairedRows.SYSTEM_BRACELET, 6);
        return pauseTargetSlot >= 0 && pauseWeaponBracelet >= 0;
    }

    void RunPauseTic()
    {
        if (logicalTic == 1 || logicalTic == 60)
            DSP042FireVolley(pauseWeaponBracelet, logicalTic, 0, playerX, playerY, 1000, 1000, 1000);
    }

    // ==== save: native save/load across a union with an in-flight child =====
    //
    // Phiera+Eight fire at tic 5 (ordinal 0 spawns immediately as a real,
    // still-active gun child; SAVE_TARGET is deliberately far enough away
    // that it is not yet reached); the union to Phieraggi lands at tic 8
    // (cancelling both pending ordinal-1/2 schedules, same as burst_union);
    // the fixture freezes at tic 9 -- right after the union, with the
    // ordinal-0 gun child still mid-flight under its OLD parent owner and
    // Phieraggi's own next-volley schedule pending. run_p042_paired.py saves
    // here, loads in a brand-new engine process, and this file's WorldTick
    // (below) compares the exact DSP042PersistenceHash/P032 inventory hash
    // immediately on the first tick that process ever runs.
    bool SetupSave()
    {
        saveTargetSlot = SpawnTarget(212.0, 212.0, "SAVE_TARGET", 60.0);
        if (saveTargetSlot < 0) return false;
        saveTargetGeneration = generations[saveTargetSlot];
        saveTargetId = ids[saveTargetSlot];
        DSP032SetItem(DSP032_ID_PHIERA, 8);
        DSP032SetItem(DSP032_ID_EIGHT, 8);
        DSP032SetItem(DSP032_ID_TIRAJISU, 1);
        DSP032SetItem(DSP032_ID_BRACELET, 5);
        saveWeaponPhiera = EquipWeapon(DSP042PairedRows.SYSTEM_PHIERA, 8);
        saveWeaponEight = EquipWeapon(DSP042PairedRows.SYSTEM_EIGHT, 8);
        saveWeaponBracelet = EquipWeapon(DSP042PairedRows.SYSTEM_BRACELET, 5);
        return saveTargetSlot >= 0 && saveWeaponPhiera >= 0 && saveWeaponEight >= 0
            && saveWeaponBracelet >= 0;
    }

    void ApplySaveUnion(int logicalTic)
    {
        int idxA = DSP032IndexOf(DSP032_ID_PHIERA);
        int idxB = DSP032IndexOf(DSP032_ID_EIGHT);
        bool ready = DSP032CanApplyRecipe(DSP032_RECIPE_UNION_PHIERAGGI,
            DSP032_GRAPH_CHEST_SILVER, true, true);
        bool applied = ready && DSP032ApplyRecipe(DSP032_RECIPE_UNION_PHIERAGGI, 2830,
            DSP032_GRAPH_CHEST_SILVER, true, true, 428900);
        int lowerIndex = -1; int higherIndex = -1; bool evolved = false;
        if (applied)
        {
            if (idxA <= idxB) { lowerIndex = saveWeaponPhiera; higherIndex = saveWeaponEight; }
            else { lowerIndex = saveWeaponEight; higherIndex = saveWeaponPhiera; }
            evolved = DSP042EvolveInPlace(lowerIndex, DSP042PairedRows.SYSTEM_PHIERAGGI, 1, logicalTic);
            if (evolved) DSP032SetItem(DSP042PairedRows.SYSTEM_PHIERAGGI, 1);
            if (higherIndex >= 0) DSP042CancelWeapon(higherIndex, logicalTic);
        }
        saveUnionSurvivingIndex = lowerIndex;
        saveUnionCancelledIndex = higherIndex;
        Console.Printf("DS_P042_MAP28_SAVE_UNION tic=%d accepted=%d evolved=%d surviving_weapon_index=%d cancelled_weapon_index=%d", logicalTic, applied ? 1 : 0, evolved ? 1 : 0, lowerIndex, higherIndex);
    }

    void RunSaveTic()
    {
        if (logicalTic == 5)
        {
            DSP042FireVolley(saveWeaponPhiera, logicalTic, 0, playerX, playerY, 1000, 1000, 1000);
            DSP042FireVolley(saveWeaponEight, logicalTic, 0, playerX, playerY, 1000, 1000, 1000);
        }
        else if (logicalTic == 8)
        {
            ApplySaveUnion(logicalTic);
        }
        if (logicalTic > 8 && saveUnionSurvivingIndex >= 0)
            DSP042FireVolley(saveUnionSurvivingIndex, logicalTic, 0, playerX, playerY, 1000, 1000, 1000);
    }

    int EmitRowsForSystem(int systemId)
    {
        int rankCount = DSP042PairedRows.RankCount(systemId);
        int rowCount = 0;
        for (int rank = 1; rank <= rankCount; rank++)
        {
            rowCount++;
            Console.Printf("DS_P042_MAP28_ROW system_id=%d rank=%d damage_milli=%d area_milli=%d speed_milli=%d amount=%d pierce=%d cooldown_tics=%d interval_tics=%d duration_tics=%d pool=%d knockback_milli=%d crit_chance_milli=%d crit_multiplier_milli=%d movement_streak_cap_milli=%d movement_streak_step_milli=%d hits_wall=%d passes_wall=%d ignores_duration=%d fixture=COMPILED_ROWS_MIRROR", systemId, rank, DSP042PairedRows.DamageMilli(systemId, rank), DSP042PairedRows.AreaMilli(systemId, rank), DSP042PairedRows.SpeedMilli(systemId, rank), DSP042PairedRows.Amount(systemId, rank), DSP042PairedRows.Pierce(systemId, rank), DSP042PairedRows.CooldownTics(systemId, rank), DSP042PairedRows.IntervalTics(systemId, rank), DSP042PairedRows.DurationTics(systemId, rank), DSP042PairedRows.Pool(systemId, rank), DSP042PairedRows.KnockbackMilli(systemId, rank), DSP042PairedRows.CritChanceMilli(systemId, rank), DSP042PairedRows.CritMultiplierMilli(systemId, rank), DSP042PairedRows.MovementStreakCapMilli(systemId, rank), DSP042PairedRows.MovementStreakStepMilli(systemId, rank), DSP042PairedRows.HitsWall(systemId) ? 1 : 0, DSP042PairedRows.PassesWall(systemId) ? 1 : 0, DSP042PairedRows.IgnoresDuration(systemId) ? 1 : 0);
        }
        return rowCount;
    }

    int EmitCompiledRows()
    {
        int rowCount = 0;
        rowCount += EmitRowsForSystem(DSP042PairedRows.SYSTEM_PEACHONE);
        rowCount += EmitRowsForSystem(DSP042PairedRows.SYSTEM_EBONY);
        rowCount += EmitRowsForSystem(DSP042PairedRows.SYSTEM_VANDALIER);
        rowCount += EmitRowsForSystem(DSP042PairedRows.SYSTEM_PHIERA);
        rowCount += EmitRowsForSystem(DSP042PairedRows.SYSTEM_EIGHT);
        rowCount += EmitRowsForSystem(DSP042PairedRows.SYSTEM_PHIERAGGI);
        rowCount += EmitRowsForSystem(DSP042PairedRows.SYSTEM_VENTO);
        rowCount += EmitRowsForSystem(DSP042PairedRows.SYSTEM_FUWALA);
        rowCount += EmitRowsForSystem(DSP042PairedRows.SYSTEM_BRACELET);
        rowCount += EmitRowsForSystem(DSP042PairedRows.SYSTEM_BI_BRACELET);
        rowCount += EmitRowsForSystem(DSP042PairedRows.SYSTEM_TRI_BRACELET);
        Console.Printf("DS_P042_MAP28_ROW_COUNT rows=%d", rowCount);
        return rowCount;
    }

    void EmitCompleteAndFinish()
    {
        int hash = DSP042PersistenceHash();
        Console.Printf("DS_P042_MAP28_COMPLETE mode=%s tic=%d accepted_hits=%d rejected_hits=%d inventory_hash=%d hash=%d classification=CONTROLLED_ENGINE_FIXTURE", activeMode, logicalTic, dsp042AcceptedHits, dsp042RejectedHits, DSP032InventoryHash(), hash);
        LevelLocals.MakeScreenShot();
        completed = true;
    }

    int ReadSaveSnapshotRequest()
    {
        CVar cvar = CVar.FindCVar("ds_p042_save_snapshot_request");
        return cvar != null && cvar.GetInt() != 0 ? 1 : 0;
    }

    // ---- Native pause bridge (mirrors P041's MAP27 pattern exactly; see
    // BounceMap27Runtime.zs) -------------------------------------------------

    override void UiTick()
    {
        uiTics++;
        if (uiPauseMode == 0) return;
        if (!uiPauseRequestSent && uiLogicalTic >= 5
            && !Level.WorldPaused() && Menu.GetCurrentMenu() == null)
        {
            uiPauseRequestSent = true;
            uiPauseAtTic = uiLogicalTic;
            SendNetworkEvent("P042_MAP28_PAUSE_REQUEST", uiLogicalTic, uiPauseHash, uiTics);
            Menu.SetMenu('MainMenu');
        }
        else if (uiPauseRequestSent && !uiPauseObserved && Level.WorldPaused())
        {
            uiPauseObserved = true;
            uiPauseUntilUiTic = uiTics + 35;
            SendNetworkEvent("P042_MAP28_PAUSE_HELD", uiLogicalTic, uiPauseHash, uiTics);
        }
        else if (uiPauseObserved && !uiPauseResumeSent && uiTics >= uiPauseUntilUiTic)
        {
            Menu menu = Menu.GetCurrentMenu();
            if (menu != null) menu.Close();
            if (!Level.WorldPaused())
            {
                uiPauseResumeSent = true;
                SendNetworkEvent("P042_MAP28_RESUME", uiLogicalTic, uiPauseHash, uiTics);
            }
        }
    }

    override void InterfaceProcess(ConsoleEvent e)
    {
        if (e.Name == "P042_MAP28_UI_RESET")
        {
            uiPauseRequestSent = false; uiPauseObserved = false; uiPauseResumeSent = false;
            uiTics = 0; uiLogicalTic = 0; uiPauseHash = 0;
            uiPauseAtTic = -1; uiPauseUntilUiTic = 0; uiPauseMode = 0;
        }
        else if (e.Name == "P042_MAP28_UI_STATE")
        {
            uiLogicalTic = e.Args[0];
            uiPauseHash = e.Args[1];
            uiPauseMode = e.Args[2];
        }
    }

    override void NetworkProcess(ConsoleEvent e)
    {
        if (e.Player != consoleplayer) return;
        if (e.Name == "P042_MAP28_PAUSE_REQUEST")
        {
            pauseRequested = true;
            pauseStartLogicalTic = e.Args[0];
            pauseStartHash = e.Args[1];
            Console.Printf("DS_P042_MAP28_PAUSE_START logical_tic=%d state_hash=%d ui_tic=%d requested_native_pause=1", pauseStartLogicalTic, pauseStartHash, e.Args[2]);
        }
        else if (e.Name == "P042_MAP28_PAUSE_HELD")
        {
            pauseOpened = true;
            Console.Printf("DS_P042_MAP28_PAUSE_HELD logical_tic=%d state_hash=%d ui_tic=%d world_paused=1", e.Args[0], e.Args[1], e.Args[2]);
        }
        else if (e.Name == "P042_MAP28_RESUME")
        {
            pauseClosed = true;
            pauseResumeTic = e.Args[0];
            pauseResumeHash = e.Args[1];
            bool stable = pauseOpened && pauseStartLogicalTic == pauseResumeTic
                && pauseStartHash == pauseResumeHash;
            Console.Printf("DS_P042_MAP28_PAUSE_END accepted=%d world_logical_tic=%d start_world_logical_tic=%d ui_tics=%d start_hash=%d end_hash=%d", stable ? 1 : 0, pauseResumeTic, pauseStartLogicalTic, e.Args[2], pauseStartHash, pauseResumeHash);
        }
    }

    override void WorldTick()
    {
        // Globally registered: never boot (camera/FOV writes, fixture
        // entities) on any other map. Without this gate the fixture reset the
        // player's facing on MAP16 normal play and on MAP18 (2026-09-28).
        if (level == null || level.MapName != "MAP28") return;
        if (!started)
        {
            started = Boot();
            enabled = started;
        }
        if (!enabled || completed) return;

        // Save/load restore detection: firstTickThisProcess is true exactly
        // once -- the very first WorldTick this OS process has ever run (see
        // BounceMap27Runtime.zs for the same lesson: WorldLoaded's own
        // e.IsSaveGame timing is not reliable here). In a fresh start that
        // is tic 1 (logicalTic still 0, so the "> 0" guard below skips it);
        // in a restored process every ordinary field already holds its
        // persisted value, so this is exactly the load-continuation point.
        bool firstTickThisProcess = !startedThisProcess;
        startedThisProcess = true;
        if (firstTickThisProcess && logicalTic > 0)
        {
            int hashNow = DSP042PersistenceHash();
            int invHashNow = DSP032InventoryHash();
            bool exactState = hashNow == saveStateHash;
            bool exactInventory = invHashNow == saveInventoryHash;
            bool midFlight = false;
            for (int i = 0; i < dsp042GunActive.Size(); i++)
            {
                if (dsp042GunActive[i] == 0) continue;
                if (dsp042GunSystems[i] == DSP042PairedRows.SYSTEM_PHIERA
                    || dsp042GunSystems[i] == DSP042PairedRows.SYSTEM_EIGHT)
                    midFlight = true;
            }
            Console.Printf("DS_P042_MAP28_RESTORE first_tick=1 tic=%d hash=%d inventory_hash=%d continuation=1 mid_flight=%d exact_hash=%d exact_inventory_hash=%d surviving_weapon_index=%d", logicalTic, hashNow, invHashNow, midFlight ? 1 : 0, exactState ? 1 : 0, exactInventory ? 1 : 0, saveUnionSurvivingIndex);
        }

        // Save/load: the restore leg clears the cvar to unfreeze; checked
        // before the frozen-return below so the SAME tic that unfreezes also
        // resumes normal processing (mirrors P041's BounceMap27Runtime
        // exactly).
        if (activeMode == "save" && saveHold && ReadSaveSnapshotRequest() == 0)
            saveHold = false;
        if (activeMode == "save" && saveHold)
            return; // frozen: no world/logical progress at all while held

        DSP024Rebuild();
        RunModeTic();
        DSP042AdvanceTic(logicalTic);
        SendInterfaceEvent(consoleplayer, "P042_MAP28_UI_STATE", logicalTic,
            DSP042PersistenceHash(), activeMode == "pause" ? 1 : 0);

        if (activeMode == "save" && !saveHold && logicalTic == 8
            && saveUnionSurvivingIndex >= 0 && ReadSaveSnapshotRequest() == 1)
        {
            saveHold = true;
            // logicalTic itself still increments once more below (this
            // tic's own advance completes normally; only LATER ticks are
            // skipped by the saveHold early-return above), so the value
            // actually persisted to the save file is logicalTic+1 -- log
            // that value here, not the pre-increment one, so the restore
            // leg's own logicalTic matches exactly.
            saveLogicalTic = logicalTic + 1;
            saveStateHash = DSP042PersistenceHash();
            saveInventoryHash = DSP032InventoryHash();
            Console.Printf("DS_P042_MAP28_SAVE_FROZEN accepted=1 tic=%d hash=%d inventory_hash=%d surviving_weapon_index=%d pending_output_schedule=1", saveLogicalTic, saveStateHash, saveInventoryHash, saveUnionSurvivingIndex);
        }

        logicalTic++;
        tic++;
        if (tic >= finishAtTic) EmitCompleteAndFinish();
    }
}
