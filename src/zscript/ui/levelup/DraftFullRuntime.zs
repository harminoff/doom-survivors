// P031 MAP17 harness for the additive inventory/draft authority.
// MAP14 and MAP16 keep their existing handlers and behavior.
class DSP031DraftFullRuntime : EventHandler
{
    mixin DSRunStatFields;
    mixin DSP028LevelUpProgression;
    mixin DSP031InventoryDraftAuthority;
    mixin DSP031DraftFullUi;

    const MAP = "MAP17";
    bool enabled;
    bool profileOpen;
    bool runStarted;
    bool draftPaused;
    bool awaitingNeutral;
    bool completed;
    bool demoXpGranted;
    bool auditRan;
    bool profileScreenshotTaken;
    bool modalScreenshotTaken;
    bool completionScreenshotPending;
    bool saveReadyReported;
    int lastAppliedItemId;
    int tic;
    int pausedSamples;
    int telemetryEnabled;
    String configuredMode;
    transient bool startedThisProcess;

    override void OnRegister()
    {
        // This handler is global and requests native mouse input only while
        // its Seal or draft UI owns the processor.
        IsUiProcessor = false;
        RequireMouse = true;
    }

    int ReadCVarInt(String name, int fallback)
    {
        CVar value = CVar.FindCVar(name);
        return value != null ? value.GetInt() : fallback;
    }

    String ReadMode()
    {
        CVar value = CVar.FindCVar("ds_p031_mode");
        return value != null ? value.GetString() : "manual";
    }

    void PublishProfile()
    {
        SendInterfaceEvent(consoleplayer, "P031_PROFILE", dsp031ProfileSealMask,
            dsp031ProfileSealCapacity, 0);
    }

    void PublishSnapshot()
    {
        SendInterfaceEvent(consoleplayer, "P031_STATE", playerLevel, experienceMilliunits,
            DSP031QueuedCount());
        SendInterfaceEvent(consoleplayer, "P031_TARGET", DSP031CurrentDraftLevel(),
            dsp031AppliedDrafts, dsp031OfferCount);
        SendInterfaceEvent(consoleplayer, "P031_ACTIONS", dsp031RerollsRemaining,
            dsp031SkipsRemaining, dsp031BanishesRemaining);
        SendInterfaceEvent(consoleplayer, "P031_ACTION_ID", dsp031LastActionId, 0, 0);
        SendInterfaceEvent(consoleplayer, "P031_RANKS", whipRank, powerRank, armorRank);
        for (int i = 0; i < 4; i++)
            SendInterfaceEvent(consoleplayer, String.Format("P031_OFFER%d", i),
                DSP031OfferId(i), DSP031OfferRank(DSP031OfferId(i)), 0);
    }

    void EmitInputOwner(String state)
    {
        Console.Printf("DS_P031_INPUT_OWNER state=%s map=%s ui_processor=%d run_started=%d modal=%d", state, MAP,
            IsUiProcessor ? 1 : 0, runStarted ? 1 : 0, draftPaused ? 1 : 0);
    }

    void OpenDraft()
    {
        if (DSP031QueuedCount() <= 0 || completed) return;
        draftPaused = true;
        awaitingNeutral = false;
        pausedSamples = 0;
        modalScreenshotTaken = false;
        IsUiProcessor = true;
        SendInterfaceEvent(consoleplayer, "P031_OPEN", DSP031CurrentDraftLevel(),
            DSP031QueuedCount(), dsp031AppliedDrafts);
        EmitInputOwner("LEVEL_UP_MODAL");
        Console.Printf("DS_P031_DRAFT_OPEN current_level=%d target_level=%d queue=%d token=%d offers=%d clock_frozen=1 ui_input=1", playerLevel, DSP031CurrentDraftLevel(), DSP031QueuedCount(), dsp031AppliedDrafts, dsp031OfferCount);
    }

    void CompleteRun(String classification)
    {
        if (completed) return;
        completed = true;
        draftPaused = false;
        awaitingNeutral = false;
        IsUiProcessor = false;
        Console.Printf("DS_P031_COMPLETE tics=%d level=%d xp=%d drafts_enqueued=%d drafts_applied=%d rerolls=%d skips=%d banishes=%d run_banished=%d rng_draws=%d state_hash=%d catalog=RESTRICTED_PLAYABLE_SUBSET fixture_content=LABELLED classification=%s", tic, playerLevel, experienceMilliunits, dsp031DraftLevels.Size(), dsp031AppliedDrafts, dsp031RerollsUsed, dsp031SkipsUsed, dsp031BanishesUsed, dsp031RunBanishedIds.Size(), dsp031DraftDraws, DSP031StateHash(), classification);
        SendInterfaceEvent(consoleplayer, "P031_COMPLETE", 1, dsp031AppliedDrafts, 0);
        completionScreenshotPending = true;
        EmitInputOwner("COMPLETE");
    }

    void BeginControlledRun()
    {
        if (!profileOpen || runStarted || completed) return;
        profileOpen = false;
        runStarted = true;
        IsUiProcessor = false;
        DSP028ResetProgression();
        DSP031StartRun(ReadCVarInt("ds_p031_seed", 730201),
            ReadCVarInt("ds_p031_rerolls", 0), ReadCVarInt("ds_p031_skips", 0),
            ReadCVarInt("ds_p031_banishes", 0), ReadCVarInt("ds_p031_luck_milli", 0));

        if (configuredMode == "slot_probe")
        {
            DSP031SetFixtureOccupancy(6, 6);
            int ordinaryBefore = DSP031OrdinaryCount(DSP031_CATEGORY_PASSIVE);
            bool stageGrant = DSP031StageGrant(DSP028_ID_POWER);
            bool ownedEligible = DSP031Eligible(DSP028_ID_POWER);
            bool newPassiveEligible = DSP031Eligible(DSP028_ID_ARMOR);
            Console.Printf("DS_P031_SLOT_PROBE ordinary_before=%d ordinary_after=%d extra_after=%d stage_grant=%d owned_extra_remains_eligible=%d new_passive_blocked=%d power_rank=%d might_milli=%d fixture=CONTROLLED", ordinaryBefore, DSP031OrdinaryCount(DSP031_CATEGORY_PASSIVE), DSP031ExtraCount(DSP031_CATEGORY_PASSIVE), stageGrant, ownedEligible, !newPassiveEligible, powerRank, characterMightMilli);
            CompleteRun("CONTROLLED_FULL_SLOT_STAGE_EXTRA");
            return;
        }

        // This audit is an independent selector fixture. The authority saves
        // and restores the live draft RNG and draw count around its 100k run.
        if (!auditRan)
        {
            auditRan = true;
            int rngBefore = dsp031DraftRng;
            int drawsBefore = dsp031DraftDraws;
            DSP031RunWeightAudit(100000);
            Console.Printf("DS_P031_AUDIT_LIVE_STATE rng_before=%d rng_after=%d draws_before=%d draws_after=%d unchanged=%d", rngBefore, dsp031DraftRng, drawsBefore, dsp031DraftDraws, rngBefore == dsp031DraftRng && drawsBefore == dsp031DraftDraws);
        }

        SendInterfaceEvent(consoleplayer, "P031_RUN_STARTED", dsp031RunSealMask,
            dsp031ProfileSealCapacity, 0);
        DSP031CollectExperience(5000);
        PublishSnapshot();
        Console.Printf("DS_P031_RUNTIME_START level=%d xp=%d seal_mask=%d counters=EXPLICIT_PROFILE_INPUT", playerLevel, experienceMilliunits, dsp031RunSealMask);
        if (DSP031QueuedCount() > 0) OpenDraft();
        else { draftPaused = false; IsUiProcessor = false; }
        EmitInputOwner("RUN_ACTIVE");
    }

    void AcceptDraftAction(int itemId, bool skipped)
    {
        lastAppliedItemId = itemId;
        awaitingNeutral = true;
        draftPaused = true;
        IsUiProcessor = true;
        PublishSnapshot();
        SendInterfaceEvent(consoleplayer, "P031_APPLIED", itemId, DSP031QueuedCount(), dsp031AppliedDrafts);
        Console.Printf("DS_P031_TRANSACTION accepted=1 kind=%s item=%s queue=%d token=%d neutral_release=1 clock_frozen=1", skipped ? "SKIP" : "APPLY", DSP031Name(itemId), DSP031QueuedCount(), dsp031AppliedDrafts);
    }

    override void NetworkProcess(ConsoleEvent e)
    {
        if (!enabled || e.Player != consoleplayer) return;
        if (e.Name == "P031_SEAL")
        {
            bool accepted = profileOpen && !runStarted && !completed
                && DSP031SetSealed(e.Args[0], e.Args[1] != 0);
            PublishProfile();
            SendInterfaceEvent(consoleplayer, "P031_PROFILE_REFRESH", dsp031ProfileSealMask,
                dsp031ProfileSealCapacity, accepted ? 1 : 0);
            Console.Printf("DS_P031_SEAL_REQUEST accepted=%d item=%s sealed=%d pre_run=%d persistence=CONFIG_CVAR", accepted, DSP031Name(e.Args[0]), e.Args[1], profileOpen ? 1 : 0);
            return;
        }
        if (e.Name == "P031_START")
        {
            if (!profileOpen || runStarted)
            {
                Console.Printf("DS_P031_INTENT_REJECT action=START reason=NOT_PRE_RUN");
                return;
            }
            BeginControlledRun();
            return;
        }
        if (!runStarted || completed) return;
        if (e.Name == "P031_REROLL")
        {
            bool accepted = draftPaused && !awaitingNeutral
                && DSP031Reroll(e.Args[0], e.Args[1]);
            PublishSnapshot();
            SendInterfaceEvent(consoleplayer, "P031_REFRESH", e.Args[0], 1, dsp031OfferCount);
            Console.Printf("DS_P031_ACTION_RESULT kind=REROLL accepted=%d token=%d action_id=%d queue=%d rng_draws=%d", accepted, e.Args[0], e.Args[1], DSP031QueuedCount(), dsp031DraftDraws);
            return;
        }
        if (e.Name == "P031_BANISH")
        {
            bool accepted = draftPaused && !awaitingNeutral
                && DSP031Banish(e.Args[0], e.Args[1], e.Args[2]);
            PublishSnapshot();
            SendInterfaceEvent(consoleplayer, "P031_REFRESH", e.Args[0], 2, dsp031OfferCount);
            Console.Printf("DS_P031_ACTION_RESULT kind=BANISH accepted=%d token=%d action_id=%d item=%s queue=%d menu_remains_open=%d", accepted, e.Args[0], e.Args[2], DSP031Name(e.Args[1]), DSP031QueuedCount(), accepted ? 1 : 0);
            return;
        }
        if (e.Name == "P031_APPLY")
        {
            int token = e.Args[0];
            int id = e.Args[1];
            bool accepted = draftPaused && !awaitingNeutral && DSP031ApplyOffer(token, id);
            if (!accepted)
            {
                Console.Printf("DS_P031_ACTION_RESULT kind=APPLY accepted=0 token=%d item=%s reason=STALE_OR_ILLEGAL", token, DSP031Name(id));
                return;
            }
            AcceptDraftAction(id, false);
            return;
        }
        if (e.Name == "P031_SKIP")
        {
            int token = e.Args[0];
            bool accepted = draftPaused && !awaitingNeutral && DSP031Skip(token, e.Args[1]);
            if (!accepted)
            {
                PublishSnapshot();
                SendInterfaceEvent(consoleplayer, "P031_REFRESH", token, 3, dsp031OfferCount);
                Console.Printf("DS_P031_ACTION_RESULT kind=SKIP accepted=0 token=%d action_id=%d reason=STALE_OR_ILLEGAL", token, e.Args[1]);
                return;
            }
            AcceptDraftAction(0, true);
            return;
        }
        if (e.Name == "P031_NEUTRAL")
        {
            if (!awaitingNeutral || e.Args[0] != dsp031AppliedDrafts)
            {
                Console.Printf("DS_P031_NEUTRAL_REJECT accepted=0 token=%d expected=%d", e.Args[0], dsp031AppliedDrafts);
                return;
            }
            awaitingNeutral = false;
            SendInterfaceEvent(consoleplayer, "P031_NEUTRAL_ACK", DSP031QueuedCount(), dsp031AppliedDrafts, 0);
            Console.Printf("DS_P031_NEUTRAL_FRAME token=%d queue=%d input_released=1 gameplay_reacquire=DEFERRED", e.Args[0], DSP031QueuedCount());

            if (DSP031QueuedCount() == 0 && configuredMode != "manual"
                && dsp031AppliedDrafts == 1 && !demoXpGranted)
            {
                demoXpGranted = true;
                DSP031CollectExperience(15000);
                PublishSnapshot();
            }
            if (DSP031QueuedCount() > 0) OpenDraft();
            else
            {
                draftPaused = false;
                IsUiProcessor = false;
                EmitInputOwner("ACTIVE_RESUME");
                if (configuredMode != "manual" && dsp031AppliedDrafts >= 2)
                    CompleteRun("AUTOMATED_ENGINE_TAPE");
            }
            return;
        }
    }

    override void InterfaceProcess(ConsoleEvent e)
    {
        if (!enabled) return;
        if (e.Name.IndexOf("P031_") != 0) return;
        int a = e.Args.Size() > 0 ? e.Args[0] : 0;
        int b = e.Args.Size() > 1 ? e.Args[1] : 0;
        int c = e.Args.Size() > 2 ? e.Args[2] : 0;
        DSP031UiReceive(e.Name, a, b, c);
    }

    override void WorldLoaded(WorldEvent e)
    {
        enabled = level.MapName == MAP;
        if (!enabled) return;
        configuredMode = ReadMode();
        telemetryEnabled = ReadCVarInt("ds_p031_telemetry", 1) != 0 ? 1 : 0;
        // Non-static event handlers retain ordinary fields in engine saves,
        // but UZDoom does not call WorldLoaded for them during save restore.
        // Keep this guard for engine versions that do deliver the callback.
        if (e.IsSaveGame)
        {
            Console.Printf("DS_P031_RESTORE_DEFERRED state_hash=%d run_started=%d profile_open=%d draft_paused=%d awaiting_neutral=%d", DSP031StateHash(), runStarted, profileOpen, draftPaused, awaitingNeutral);
            return;
        }
        startedThisProcess = true;
        IsUiProcessor = false;
        completed = false;
        profileOpen = false;
        runStarted = false;
        draftPaused = false;
        awaitingNeutral = false;
        demoXpGranted = false;
        auditRan = false;
        profileScreenshotTaken = false;
        modalScreenshotTaken = false;
        completionScreenshotPending = false;
        tic = 0;
        pausedSamples = 0;
        DSP031LoadSealProfile();
        SendInterfaceEvent(consoleplayer, "P031_RESET", 0, 0, 0);
        Console.Printf("DS_P031_BOOT map=MAP17 authority=DSP031InventoryDraftAuthority ui=PRE_RUN_SEAL_AND_LEVEL_UP catalog=WHIP_POWER_ARMOR_PLUS_CONTROLLED_TEST_FOURTH source_build=1.16.107 steam_build=25016043 mode=%s", configuredMode);
        Console.Printf("DS_P031_RULES source_pool=RESTRICTED_PLAYABLE_SUBSET ordinary_slots_per_category=6 stage_extra=SUPPORTED rarity=PROVISIONAL_APPROXIMATION action_scopes=REROLL_SET_SKIP_DRAFT_BANISH_RUN_SEAL_PROFILE_PRE_RUN");
        PublishProfile();

        if (configuredMode == "manual" || configuredMode == "seal_demo")
        {
            profileOpen = true;
            pausedSamples = 0;
            IsUiProcessor = true;
            SendInterfaceEvent(consoleplayer, "P031_PROFILE", dsp031ProfileSealMask,
                dsp031ProfileSealCapacity, 0);
            EmitInputOwner("PRE_RUN_PROFILE");
        }
        else
        {
            profileOpen = true;
            pausedSamples = 0;
            BeginControlledRun();
        }
    }

    override void WorldTick()
    {
        bool firstTickThisProcess = !startedThisProcess;
        startedThisProcess = true;
        if (!enabled && level != null && level.MapName == MAP) enabled = true;
        if (!enabled) return;
        if (firstTickThisProcess)
        {
            IsUiProcessor = profileOpen || draftPaused || awaitingNeutral;
            if (profileOpen || draftPaused || awaitingNeutral)
            {
                pausedSamples = 0;
                profileScreenshotTaken = false;
                modalScreenshotTaken = false;
                SendInterfaceEvent(consoleplayer, "P031_RESET", 0, 0, 0);
                if (profileOpen)
                    PublishProfile();
                if (runStarted) PublishSnapshot();
                if (draftPaused && !awaitingNeutral)
                    SendInterfaceEvent(consoleplayer, "P031_OPEN", DSP031CurrentDraftLevel(),
                        DSP031QueuedCount(), dsp031AppliedDrafts);
                else if (awaitingNeutral)
                    SendInterfaceEvent(consoleplayer, "P031_APPLIED", lastAppliedItemId,
                        DSP031QueuedCount(), dsp031AppliedDrafts);
                Console.Printf("DS_P031_SAVE_RESTORE first_tick=1 state_hash=%d rng=%d draws=%d applied=%d queue=%d token=%d action_id=%d rerolls=%d skips=%d banishes=%d profile_open=%d draft_paused=%d awaiting_neutral=%d offers=%d,%d,%d,%d", DSP031StateHash(), dsp031DraftRng, dsp031DraftDraws, dsp031AppliedDrafts, DSP031QueuedCount(), dsp031AppliedDrafts, dsp031LastActionId, dsp031RerollsRemaining, dsp031SkipsRemaining, dsp031BanishesRemaining, profileOpen, draftPaused, awaitingNeutral, DSP031OfferId(0), DSP031OfferId(1), DSP031OfferId(2), DSP031OfferId(3));
            }
        }
        if (completed)
        {
            if (completionScreenshotPending)
            {
                completionScreenshotPending = false;
                Console.Printf("DS_P031_COMPLETE_CAPTURE frame_deferred=1");
                LevelLocals.MakeScreenShot();
            }
            return;
        }
        if (profileOpen || draftPaused || awaitingNeutral)
        {
            pausedSamples++;
            if (telemetryEnabled != 0 && (pausedSamples == 1 || pausedSamples % 20 == 0))
                Console.Printf("DS_P031_WORLD_PAUSE_CALLBACK logical_tic=%d queue=%d frozen=1", tic, DSP031QueuedCount());
            if (profileOpen && !profileScreenshotTaken && pausedSamples >= 6)
            {
                profileScreenshotTaken = true;
                Console.Printf("DS_P031_PROFILE_CAPTURE callbacks=%d ui_visible_required=1", pausedSamples);
                LevelLocals.MakeScreenShot();
            }
            if (draftPaused && !modalScreenshotTaken && pausedSamples >= 6)
            {
                modalScreenshotTaken = true;
                Console.Printf("DS_P031_MODAL_CAPTURE callbacks=%d logical_tic=%d ui_visible_required=1", pausedSamples, tic);
                LevelLocals.MakeScreenShot();
            }
            if (draftPaused && (configuredMode == "hold_modal" || configuredMode == "hold_after_reroll")
                && !saveReadyReported && pausedSamples >= 10)
            {
                saveReadyReported = true;
                Console.Printf("DS_P031_SAVE_READY state_hash=%d rng=%d draws=%d applied=%d queue=%d token=%d action_id=%d rerolls=%d skips=%d banishes=%d profile_open=%d draft_paused=%d awaiting_neutral=%d offers=%d,%d,%d,%d", DSP031StateHash(), dsp031DraftRng, dsp031DraftDraws, dsp031AppliedDrafts, DSP031QueuedCount(), dsp031AppliedDrafts, dsp031LastActionId, dsp031RerollsRemaining, dsp031SkipsRemaining, dsp031BanishesRemaining, profileOpen, draftPaused, awaitingNeutral, DSP031OfferId(0), DSP031OfferId(1), DSP031OfferId(2), DSP031OfferId(3));
            }
            return;
        }
        if (runStarted) tic++;
    }
}
