// MAP18 controlled chest source, reward queue and transformation integration.
// The runtime uses real player-body coordinates; it never requires aim or Use.
class DSP032ChestMarker : Actor
{
    int stableChestId;

    Default
    {
        Radius 8;
        Height 12;
        +NOBLOCKMAP;
        +NOGRAVITY;
        +NOINTERACTION;
        RenderStyle "Add";
        Alpha 0.9;
    }

    States
    {
    Spawn:
        PICK A 2 Bright;
        Loop;
    }
}

class DSP032ChestRuntime : EventHandler
{
    mixin DSRunStatFields;
    mixin DSP032ChestRewardAuthority;
    mixin DSP032TransformationGraph;

    const MAP = "MAP18";
    const SOURCE_TIC_ORIGIN = 180000;
    const CHEST_NEAR_SILVER = 1801;
    const CHEST_QUEUED_SILVER = 1802;
    const CHEST_LATE_BRONZE = 1803;

    bool enabled;
    bool modalPaused;
    bool completed;
    bool transformAttempted;
    bool modalScreenshotTaken;
    bool saveReadyReported;
    int logicalTic;
    int modalPausedSamples;
    int chestVisualCount;
    String configuredMode;
    transient bool startedThisProcess;
    int graphMatrixCases;
    int graphMatrixWarmupTicks;
    bool graphMatrixOk;
    bool graphMatrixPending;
    bool graphMatrixCapturePending;

    override void OnRegister()
    {
        IsUiProcessor = false;
        RequireMouse = true;
    }

    String ReadMode()
    {
        CVar mode = CVar.FindCVar("ds_p032_mode");
        return mode != null ? mode.GetString() : "manual";
    }

    void SpawnMarker(int stableId, int x, int y)
    {
        DSP032ChestMarker marker = DSP032ChestMarker(Actor.Spawn("DSP032ChestMarker",
            (double(x), double(y), 1.0), NO_REPLACE));
        if (marker != null) marker.stableChestId = stableId;
        chestVisualCount++;
    }

    int ConfiguredSlots()
    {
        if (configuredMode == "evolution") return 1;
        if (configuredMode == "slots1") return 1;
        if (configuredMode == "slots5") return 5;
        return 3;
    }

    void SpawnSource(int stableId, int subtype, int slots, int x, int y,
        bool sourceAllowsTransformation)
    {
        if (!DSP032SpawnChestRecord(stableId, subtype, 1, 1, logicalTic,
                slots, sourceAllowsTransformation, x, y, 72))
        {
            Console.Printf("DS_P032_CHEST_SOURCE_FAIL id=%d", stableId);
            return;
        }
        SpawnMarker(stableId, x, y);
    }

    void InitializeScenario()
    {
        DSP032ResetInventory();
        DSP032ResetChests();
        logicalTic = 0;
        completed = false;
        modalPaused = false;
        transformAttempted = false;
        modalScreenshotTaken = false;
        saveReadyReported = false;
        chestVisualCount = 0;
        if (configuredMode == "graph_matrix")
        {
            graphMatrixCases = 0;
            graphMatrixWarmupTicks = 0;
            graphMatrixOk = true;
            graphMatrixPending = true;
            Console.Printf("DS_BOOT map=MAP18 classification=CONTROLLED_CHEST_REWARD_TRANSFORMATION_HARNESS");
            Console.Printf("DS_P032_BOOT map=MAP18 authority=DSP032TransformationGraph mode=graph_matrix classification=CONTROLLED_FIXTURE_MATRIX");
            return;
        }
        if (configuredMode == "evolution" || configuredMode == "bronze_late")
            DSP032SeedWhipEvolutionFixture();
        int subtype = configuredMode == "bronze_late"
            ? DSP032_CHEST_BRONZE : DSP032_CHEST_SILVER;
        int sourceTic = logicalTic;
        SpawnSource(CHEST_NEAR_SILVER, subtype, ConfiguredSlots(), 48, 0,
            configuredMode != "bronze_late");
        if (configuredMode == "queue")
            SpawnSource(CHEST_QUEUED_SILVER, DSP032_CHEST_SILVER, 1, 56, 0, false);
        SendInterfaceEvent(consoleplayer, "P032_UI_RESET", 0, 0, 0);
        Console.Printf("DS_BOOT map=MAP18 classification=CONTROLLED_CHEST_REWARD_TRANSFORMATION_HARNESS");
        Console.Printf("DS_P032_BOOT map=MAP18 authority=DSP032ChestRewardAuthority,DSP032TransformationGraph mode=%s inventory_hash=%d source_time=%d slots=1,3,5 classification=CONTROLLED_FIXTURE", configuredMode, DSP032InventoryHash(), sourceTic);
    }

    String GraphItemList(bool wantRanks)
    {
        String result = "";
        for (int i = 0; i < dsp032ItemIds.Size(); i++)
        {
            if (result != "") result = String.Format("%s,", result);
            result = String.Format("%s%d", result,
                wantRanks ? dsp032ItemRanks[i] : dsp032ItemIds[i]);
        }
        return result == "" ? "none" : result;
    }

    bool RunGraphCase(String name, int recipeId, int chestSubtype,
        bool sourceEligible, bool outputUnlocked, int transactionId,
        bool expectedLegal, bool expectedApply, String expectedReason,
        String classification)
    {
        int beforeHash = DSP032InventoryHash();
        int beforeWeapons = DSP032OwnedSlots(DSP032_CATEGORY_WEAPON);
        int beforePassives = DSP032OwnedSlots(DSP032_CATEGORY_PASSIVE);
        int beforeWeaponExtra = DSP032ExtraSlots(DSP032_CATEGORY_WEAPON);
        int beforePassiveExtra = DSP032ExtraSlots(DSP032_CATEGORY_PASSIVE);
        String beforeIds = GraphItemList(false);
        String beforeRanks = GraphItemList(true);
        bool actualLegal = DSP032CanApplyRecipe(recipeId, chestSubtype,
            sourceEligible, outputUnlocked);
        bool actualApplied = DSP032ApplyRecipe(recipeId, 1801, chestSubtype,
            sourceEligible, outputUnlocked, transactionId);
        String actualReason = actualApplied ? "ACCEPTED"
            : DSP032HasTransaction(transactionId) ? "DUPLICATE_TRANSACTION" : "PREDICATE_REJECTED";
        int afterHash = DSP032InventoryHash();
        int afterWeapons = DSP032OwnedSlots(DSP032_CATEGORY_WEAPON);
        int afterPassives = DSP032OwnedSlots(DSP032_CATEGORY_PASSIVE);
        int afterWeaponExtra = DSP032ExtraSlots(DSP032_CATEGORY_WEAPON);
        int afterPassiveExtra = DSP032ExtraSlots(DSP032_CATEGORY_PASSIVE);
        String afterIds = GraphItemList(false);
        String afterRanks = GraphItemList(true);
        bool unchanged = beforeHash == afterHash && beforeIds == afterIds
            && beforeRanks == afterRanks;
        bool expectedUnchanged = !expectedApply;
        bool passed = actualLegal == expectedLegal && actualApplied == expectedApply
            && unchanged == expectedUnchanged && actualReason == expectedReason;
        graphMatrixCases++;
        if (!passed) graphMatrixOk = false;
        Console.Printf("DS_P032_GRAPH_CASE name=%s recipe=%d chest_subtype=%d source_eligible=%d output_unlocked=%d expected_legal=%d actual_legal=%d expected_apply=%d actual_apply=%d tx=%d expected_reason=%s actual_reason=%s slots_before=%d,%d slots_after=%d,%d extras_before=%d,%d extras_after=%d,%d unchanged=%d pre_ids=%s pre_ranks=%s post_ids=%s post_ranks=%s pre_hash=%d post_hash=%d classification=%s", name, recipeId, chestSubtype, sourceEligible ? 1 : 0, outputUnlocked ? 1 : 0, expectedLegal ? 1 : 0, actualLegal ? 1 : 0, expectedApply ? 1 : 0, actualApplied ? 1 : 0, transactionId, expectedReason, actualReason, beforeWeapons, beforePassives, afterWeapons, afterPassives, beforeWeaponExtra, beforePassiveExtra, afterWeaponExtra, afterPassiveExtra, unchanged ? 1 : 0, beforeIds, beforeRanks, afterIds, afterRanks, beforeHash, afterHash, classification);
        return passed;
    }

    void RunGraphMatrix()
    {
        bool passed;

        DSP032SeedWhipEvolutionFixture();
        DSP032SetItem(DSP032_ID_WHIP, 7);
        RunGraphCase("whip_rank7", DSP032_RECIPE_WHIP_BLOODY_TEAR, DSP032_CHEST_SILVER,
            true, true, 32001, false, false, "PREDICATE_REJECTED", "ONLINE_REPORTED_RECIPE_CONTROLLED_INVENTORY_FIXTURE");

        DSP032ResetInventory();
        DSP032SetItem(DSP032_ID_WHIP, 8);
        RunGraphCase("missing_hollow_heart", DSP032_RECIPE_WHIP_BLOODY_TEAR, DSP032_CHEST_SILVER,
            true, true, 32002, false, false, "PREDICATE_REJECTED", "ONLINE_REPORTED_RECIPE_CONTROLLED_INVENTORY_FIXTURE");

        DSP032SeedWhipEvolutionFixture();
        RunGraphCase("bronze_source", DSP032_RECIPE_WHIP_BLOODY_TEAR, DSP032_CHEST_BRONZE,
            true, true, 32003, false, false, "PREDICATE_REJECTED", "ONLINE_REPORTED_RECIPE_CONTROLLED_INVENTORY_FIXTURE");

        DSP032SeedWhipEvolutionFixture();
        RunGraphCase("source_ineligible", DSP032_RECIPE_WHIP_BLOODY_TEAR, DSP032_CHEST_SILVER,
            false, true, 32004, false, false, "PREDICATE_REJECTED", "ONLINE_REPORTED_RECIPE_CONTROLLED_INVENTORY_FIXTURE");

        DSP032SeedWhipEvolutionFixture();
        RunGraphCase("output_locked", DSP032_RECIPE_WHIP_BLOODY_TEAR, DSP032_CHEST_SILVER,
            true, false, 32005, false, false, "PREDICATE_REJECTED", "ONLINE_REPORTED_RECIPE_CONTROLLED_INVENTORY_FIXTURE");

        DSP032SeedWhipEvolutionFixture();
        DSP032SetItem(DSP032_ID_BLOODY_TEAR, 1);
        RunGraphCase("output_already_owned", DSP032_RECIPE_WHIP_BLOODY_TEAR, DSP032_CHEST_SILVER,
            true, true, 32006, false, false, "PREDICATE_REJECTED", "ONLINE_REPORTED_RECIPE_CONTROLLED_INVENTORY_FIXTURE");

        DSP032SeedWhipEvolutionFixture();
        passed = RunGraphCase("whip_evolution_positive", DSP032_RECIPE_WHIP_BLOODY_TEAR,
            DSP032_CHEST_SILVER, true, true, 32007, true, true, "ACCEPTED",
            "ONLINE_REPORTED_RECIPE_CONTROLLED_INVENTORY_FIXTURE");
        if (!passed || DSP032Rank(DSP032_ID_WHIP) != 0 || DSP032Rank(DSP032_ID_HOLLOW_HEART) != 1
            || DSP032Rank(DSP032_ID_BLOODY_TEAR) != 1) graphMatrixOk = false;

        DSP032ResetInventory();
        DSP032SetItem(DSP032_FIXTURE_REPLACEMENT_SOURCE, 1);
        DSP032ApplyRecipe(DSP032_RECIPE_FIXTURE_REPLACEMENT, 1801, DSP032_CHEST_SILVER,
            true, true, 32008);
        DSP032SetItem(DSP032_ID_WHIP, 8);
        DSP032SetItem(DSP032_ID_HOLLOW_HEART, 1);
        RunGraphCase("duplicate_transaction", DSP032_RECIPE_WHIP_BLOODY_TEAR,
            DSP032_CHEST_SILVER, true, true, 32008, true, false,
            "DUPLICATE_TRANSACTION", "ONLINE_REPORTED_RECIPE_CONTROLLED_INVENTORY_FIXTURE");

        DSP032SeedUnionFixture(true);
        RunGraphCase("union_full_slots", DSP032_RECIPE_FIXTURE_UNION,
            DSP032_CHEST_SILVER, true, true, 32101, true, true, "ACCEPTED", "CONTROLLED_FIXTURE");
        if (DSP032Rank(DSP032_FIXTURE_UNION_LEFT) != 0
            || DSP032Rank(DSP032_FIXTURE_UNION_RIGHT) != 0
            || DSP032Rank(DSP032_FIXTURE_UNION_RESULT) != 1
            || DSP032OwnedSlots(DSP032_CATEGORY_WEAPON) != 5) graphMatrixOk = false;

        DSP032SeedUnionExtraFixture();
        RunGraphCase("union_extra_capacity", DSP032_RECIPE_FIXTURE_UNION,
            DSP032_CHEST_SILVER, true, true, 32102, true, true, "ACCEPTED", "CONTROLLED_STAGE_EXTRA_CAPACITY_FIXTURE");
        if (DSP032Rank(DSP032_FIXTURE_UNION_LEFT) != 0
            || DSP032Rank(DSP032_FIXTURE_UNION_RIGHT) != 0
            || DSP032Rank(DSP032_FIXTURE_UNION_RESULT) != 1
            || DSP032OwnedSlots(DSP032_CATEGORY_WEAPON) != 7
            || DSP032ExtraSlots(DSP032_CATEGORY_WEAPON) != 2) graphMatrixOk = false;

        DSP032SeedGiftFixture(true);
        RunGraphCase("gift_full_slots_reject", DSP032_RECIPE_FIXTURE_GIFT,
            DSP032_CHEST_SILVER, true, true, 32103, false, false, "PREDICATE_REJECTED", "CONTROLLED_FIXTURE");
        DSP032SeedGiftExtraFixture();
        RunGraphCase("gift_extra_capacity", DSP032_RECIPE_FIXTURE_GIFT,
            DSP032_CHEST_SILVER, true, true, 32104, true, true, "ACCEPTED", "CONTROLLED_STAGE_EXTRA_CAPACITY_FIXTURE");
        if (DSP032Rank(DSP032_FIXTURE_GIFT_SOURCE) != 1
            || DSP032Rank(DSP032_FIXTURE_GIFT_RESULT) != 1
            || DSP032OwnedSlots(DSP032_CATEGORY_PASSIVE) != 7
            || DSP032ExtraSlots(DSP032_CATEGORY_PASSIVE) != 1) graphMatrixOk = false;

        DSP032SeedReplacementFullFixture();
        RunGraphCase("replacement_full_slots", DSP032_RECIPE_FIXTURE_REPLACEMENT,
            DSP032_CHEST_SILVER, true, true, 32105, true, true, "ACCEPTED", "CONTROLLED_FIXTURE");
        if (DSP032Rank(DSP032_FIXTURE_REPLACEMENT_SOURCE) != 0
            || DSP032Rank(DSP032_FIXTURE_REPLACEMENT_RESULT) != 1
            || DSP032OwnedSlots(DSP032_CATEGORY_WEAPON) != DSP032_NORMAL_WEAPON_SLOTS) graphMatrixOk = false;
    }

    void OpenNextChest()
    {
        int stableId = DSP032ActiveChestId();
        if (stableId <= 0) return;
        int subtype = DSP032ChestSubtype(stableId);
        int slots = DSP032ChestSlots(stableId);
        modalPaused = true;
        IsUiProcessor = true;
        modalPausedSamples = 0;
        modalScreenshotTaken = false;
        saveReadyReported = false;
        int recipeId = configuredMode == "evolution" || configuredMode == "bronze_late"
            ? DSP032_RECIPE_WHIP_BLOODY_TEAR : 0;
        int fixtureMode = configuredMode == "evolution" || configuredMode == "bronze_late" ? 1 : 0;
        SendNetworkEvent("P032_UI_PAUSE", stableId, subtype, slots);
        SendInterfaceEvent(consoleplayer, "P032_UI_MODE", recipeId, fixtureMode, 0);
        SendInterfaceEvent(consoleplayer, "P032_UI_STATE", DSP032AppliedRewardCount(stableId),
            DSP032InventoryHash(), DSP032ChestQueueCount());
        Console.Printf("DS_P032_MODAL_OPEN chest=%d subtype=%s slots=%d recipe=%d queue=%d logical_tic=%d frozen=1", stableId, subtype == DSP032_CHEST_SILVER ? "SILVER" : "BRONZE", slots, recipeId, DSP032ChestQueueCount(), logicalTic);
    }

    void PublishChestState(int stableId)
    {
        SendInterfaceEvent(consoleplayer, "P032_UI_STATE", DSP032AppliedRewardCount(stableId),
            DSP032InventoryHash(), DSP032ChestQueueCount());
    }

    bool ApplyTransformationSlot(int stableId, int slotIndex, int recipeId)
    {
        int subtype = DSP032ChestSubtype(stableId);
        bool eligible = DSP032ChestAllowsTransformation(stableId);
        bool recipeReady = DSP032CanApplyRecipe(recipeId, subtype, eligible, true);
        bool slotReady = DSP032CanRecordChestReward(stableId, slotIndex, DSP032_ID_BLOODY_TEAR);
        if (!recipeReady || !slotReady)
        {
            Console.Printf("DS_P032_TRANSFORM_REJECT accepted=0 chest=%d recipe=%d subtype=%d frozen_eligible=%d slot=%d reason=%s", stableId, recipeId, subtype, eligible ? 1 : 0, slotIndex, subtype == DSP032_CHEST_BRONZE ? "FROZEN_BRONZE_SOURCE" : "PREREQUISITE_OR_SLOT");
            return false;
        }
        int transactionId = SOURCE_TIC_ORIGIN + stableId * 10 + slotIndex + 1;
        int hashBefore = DSP032InventoryHash();
        bool transformed = DSP032ApplyRecipe(recipeId, stableId, subtype, eligible, true, transactionId);
        if (!transformed) return false;
        bool recorded = DSP032RecordChestReward(stableId, slotIndex, DSP032_ID_BLOODY_TEAR);
        if (!recorded)
        {
            Console.Printf("DS_P032_ATOMICITY_FAIL kind=TRANSFORMATION chest=%d slot=%d inventory_hash_before=%d inventory_hash_after=%d", stableId, slotIndex, hashBefore, DSP032InventoryHash());
            return false;
        }
        transformAttempted = true;
        Console.Printf("DS_P032_ATOMIC_TRANSFORM accepted=1 chest=%d slot=%d recipe=%d inventory_hash_before=%d inventory_hash_after=%d whip_rank=%d bloody_tear_rank=%d passive_retained=%d", stableId, slotIndex, recipeId, hashBefore, DSP032InventoryHash(), DSP032Rank(DSP032_ID_WHIP), DSP032Rank(DSP032_ID_BLOODY_TEAR), DSP032Rank(DSP032_ID_HOLLOW_HEART));
        return true;
    }

    bool ApplyOrdinaryReward(int stableId, int slotIndex)
    {
        int rewardId = DSP032_FIXTURE_REWARD_A + (slotIndex % 3);
        int rank = DSP032Rank(rewardId) + 1;
        int transactionId = SOURCE_TIC_ORIGIN + stableId * 10 + slotIndex + 1;
        bool itemReady = DSP032CanAcquireItem(rewardId, rank, 5);
        bool slotReady = DSP032CanRecordChestReward(stableId, slotIndex, rewardId);
        if (!itemReady || !slotReady)
        {
            Console.Printf("DS_P032_REWARD_REJECT accepted=0 chest=%d slot=%d reward=%d rank=%d inventory_ready=%d slot_ready=%d", stableId, slotIndex, rewardId, rank, itemReady ? 1 : 0, slotReady ? 1 : 0);
            return false;
        }
        bool acquired = DSP032AcquireItem(rewardId, rank, 5, transactionId);
        if (!acquired) return false;
        bool recorded = DSP032RecordChestReward(stableId, slotIndex, rewardId);
        if (!recorded)
        {
            Console.Printf("DS_P032_ATOMICITY_FAIL kind=REWARD chest=%d slot=%d reward=%d", stableId, slotIndex, rewardId);
            return false;
        }
        Console.Printf("DS_P032_ATOMIC_REWARD accepted=1 chest=%d slot=%d reward=%d rank=%d inventory_hash=%d", stableId, slotIndex, rewardId, DSP032Rank(rewardId), DSP032InventoryHash());
        return true;
    }

    void FinishChest(int stableId)
    {
        if (!DSP032CompleteChest(stableId)) return;
        Console.Printf("DS_P032_MODAL_CLOSE chest=%d logical_tic=%d queue=%d frozen=1", stableId, logicalTic, DSP032ChestQueueCount());
        if (DSP032ChestQueueCount() > 0)
        {
            SendNetworkEvent("P032_UI_RESUME", stableId, 1, 0);
            modalPaused = false;
            IsUiProcessor = false;
            OpenNextChest();
            return;
        }
        modalPaused = false;
        IsUiProcessor = false;
        SendNetworkEvent("P032_UI_RESUME", stableId, 1, 0);
        if (DSP032ChestQueueCount() == 0)
        {
            completed = true;
            Console.Printf("DS_P032_RUNTIME_PASS mode=%s logical_tic=%d inventory_hash=%d chest_hash=%d transforms=%d rewards=%d", configuredMode, logicalTic, DSP032InventoryHash(), DSP032ChestStateHash(), dsp032TransactionIds.Size(), dsp032AppliedChestIds.Size());
        }
    }

    override void NetworkProcess(ConsoleEvent e)
    {
        if (!enabled || e.Player != consoleplayer) return;
        if (e.Name == "P032_UI_CONFIRM")
        {
            int stableId = e.Args[0];
            int slotIndex = e.Args[1];
            int recipeId = e.Args[2];
            if (!modalPaused || stableId != DSP032ActiveChestId()
                || slotIndex != DSP032AppliedRewardCount(stableId))
            {
                Console.Printf("DS_P032_CONFIRM_REJECT accepted=0 chest=%d slot=%d active=%d modal=%d reason=STALE_OR_DUPLICATE", stableId, slotIndex, DSP032ActiveChestId(), modalPaused ? 1 : 0);
                return;
            }
            bool accepted = recipeId > 0 && !(configuredMode == "bronze_late" && transformAttempted)
                ? ApplyTransformationSlot(stableId, slotIndex, recipeId)
                : ApplyOrdinaryReward(stableId, slotIndex);
            if (!accepted)
            {
                // A frozen Bronze can never evolve. In the dedicated late-open
                // probe, the next UI confirmation claims an ordinary reward.
                if (configuredMode == "bronze_late" && !transformAttempted)
                    transformAttempted = true;
                SendInterfaceEvent(consoleplayer, "P032_UI_STATE", DSP032AppliedRewardCount(stableId), DSP032InventoryHash(), DSP032ChestQueueCount());
                return;
            }
            PublishChestState(stableId);
            if (DSP032AppliedRewardCount(stableId) >= DSP032ChestSlots(stableId))
                FinishChest(stableId);
            return;
        }
        if (e.Name == "P032_UI_SET_MODE")
        {
            SendInterfaceEvent(consoleplayer, "P032_UI_MODE", e.Args[0], e.Args[1], e.Args[2]);
        }
    }

    override void InterfaceProcess(ConsoleEvent e)
    {
        if (!enabled || e.Name.IndexOf("P032_UI_") != 0) return;
        if (e.Name == "P032_UI_INTENT" && e.Args.Size() >= 3)
            Console.Printf("DS_P032_UI_INTENT_OBSERVED chest=%d slot=%d recipe=%d", e.Args[0], e.Args[1], e.Args[2]);
    }

    override void WorldLoaded(WorldEvent e)
    {
        enabled = level.MapName == MAP;
        if (!enabled) return;
        configuredMode = ReadMode();
        if (e.IsSaveGame)
        {
            Console.Printf("DS_P032_RESTORE_DEFERRED chest_hash=%d inventory_hash=%d", DSP032ChestStateHash(), DSP032InventoryHash());
            return;
        }
        startedThisProcess = true;
        IsUiProcessor = false;
        InitializeScenario();
    }

    override void WorldTick()
    {
        bool firstTick = !startedThisProcess;
        startedThisProcess = true;
        if (!enabled && level != null && level.MapName == MAP)
        {
            enabled = true;
            configuredMode = ReadMode();
        }
        if (!enabled || completed) return;
        if (graphMatrixCapturePending)
        {
            graphMatrixCapturePending = false;
            completed = true;
            Console.Printf("DS_P032_GRAPH_MATRIX_DONE accepted=%d cases=%d classification=CONTROLLED_FIXTURE_MATRIX", graphMatrixOk ? 1 : 0, graphMatrixCases);
            if (graphMatrixOk)
            {
                Console.Printf("DS_P032_GRAPH_MATRIX_PASS accepted=1 cases=%d classification=CONTROLLED_FIXTURE_MATRIX", graphMatrixCases);
                Console.Printf("DS_P032_RUNTIME_PASS mode=graph_matrix logical_tic=%d inventory_hash=%d chest_hash=%d transforms=%d rewards=0", logicalTic, DSP032InventoryHash(), DSP032ChestStateHash(), dsp032TransactionIds.Size());
            }
            else Console.Printf("DS_P032_GRAPH_MATRIX_FAIL accepted=0 cases=%d", graphMatrixCases);
            return;
        }
        if (graphMatrixPending)
        {
            graphMatrixWarmupTicks++;
            if (graphMatrixWarmupTicks < 4) return;
            graphMatrixPending = false;
            RunGraphMatrix();
            LevelLocals.MakeScreenShot();
            graphMatrixCapturePending = true;
            return;
        }
        if (firstTick)
        {
            // WorldLoaded is skipped when this non-static handler is restored.
            // Serialized fields restore the live run, while the current launch
            // CVar supplies only this process's UI/demo mode.
            configuredMode = ReadMode();
            modalPaused = DSP032ChestQueueCount() > 0;
            IsUiProcessor = modalPaused;
            if (modalPaused)
            {
                int stableId = DSP032ActiveChestId();
                SendNetworkEvent("P032_UI_PAUSE", stableId, DSP032ChestSubtype(stableId), DSP032ChestSlots(stableId));
                SendInterfaceEvent(consoleplayer, "P032_UI_MODE", configuredMode == "evolution" ? 1 : 0,
                    configuredMode == "evolution" ? 1 : 0, 0);
                PublishChestState(stableId);
                Console.Printf("DS_P032_SAVE_RESTORE chest_hash=%d inventory_hash=%d queue=%d active_chest=%d slot=%d", DSP032ChestStateHash(), DSP032InventoryHash(), DSP032ChestQueueCount(), stableId, DSP032AppliedRewardCount(stableId));
                CVar mode = CVar.FindCVar("ds_p032_mode");
                if (mode != null && mode.GetString() == "restore_duplicate_confirm"
                    && DSP032AppliedRewardCount(stableId) > 0)
                {
                    SendNetworkEvent("P032_UI_CONFIRM", stableId,
                        DSP032AppliedRewardCount(stableId) - 1, 0);
                    Console.Printf("DS_P032_RESTORE_STALE_INTENT queued=1 chest=%d slot=%d", stableId, DSP032AppliedRewardCount(stableId) - 1);
                }
            }
        }
        if (modalPaused)
        {
            modalPausedSamples++;
            if (!modalScreenshotTaken && modalPausedSamples >= 6)
            {
                modalScreenshotTaken = true;
                Console.Printf("DS_P032_MODAL_CAPTURE callbacks=%d chest=%d visible_required=1", modalPausedSamples, DSP032ActiveChestId());
                LevelLocals.MakeScreenShot();
            }
            if (!saveReadyReported && modalPausedSamples >= 10)
            {
                saveReadyReported = true;
                Console.Printf("DS_P032_SAVE_READY chest_hash=%d inventory_hash=%d queue=%d active_chest=%d applied=%d tic=%d", DSP032ChestStateHash(), DSP032InventoryHash(), DSP032ChestQueueCount(), DSP032ActiveChestId(), DSP032AppliedRewardCount(DSP032ActiveChestId()), logicalTic);
            }
            return;
        }
        Actor player = consoleplayer >= 0 ? players[consoleplayer].mo : null;
        if (player == null) return;
        logicalTic++;
        if (configuredMode == "bronze_late" && logicalTic < 100) return;
        int playerX = int(player.Pos.X);
        int playerY = int(player.Pos.Y);
        for (int i = 0; i < dsp032ChestIds.Size(); i++)
        {
            int stableId = dsp032ChestIds[i];
            if (DSP032ChestWasClaimed(stableId)
                || !DSP032ChestWithinPickupRange(stableId, playerX, playerY)) continue;
            int dx = dsp032ChestX[i] - playerX;
            int dy = dsp032ChestY[i] - playerY;
            double yaw = player.Angle;
            double facingDot = double(dx) * cos(yaw) + double(dy) * sin(yaw);
            Console.Printf("DS_P032_PICKUP_GEOMETRY chest=%d distance_inside=1 facing_dot=%.2f facing_away=%d body_radius=1 use_or_aim=0 logical_tic=%d classification=%s", stableId, facingDot, facingDot < 0.0 ? 1 : 0, logicalTic, configuredMode == "bronze_late" ? "CONTROLLED_SHORT_DELAY_NO_TEN_MINUTE_CLAIM" : "NORMAL_SPEED_BODY_PROXIMITY");
            DSP032PickUpChest(stableId, playerX, playerY);
        }
        if (DSP032ChestQueueCount() > 0) OpenNextChest();
    }
}
