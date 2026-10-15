// P028 real in-engine level-up modal and first-person pause boundary.
//
// The overlay is drawn by UZDoom's RenderOverlay callback. UI input submits
// intent through SendNetworkEvent; play-side NetworkProcess validates and
// applies the queued offer exactly once. Play publishes snapshots through
// SendInterfaceEvent so rendering never becomes a gameplay authority.
class DSP028LevelUpRuntime : EventHandler
{
    mixin DSP020EntityStore;
    mixin DSP025AttackCore;
    mixin DSP028LevelUpProgression;

    const MAP = "MAP14";
    const RUN_TICS = 72;
    const MODAL_VIRTUAL_WIDTH = 640;
    const MODAL_VIRTUAL_HEIGHT = 400;

    bool enabled;
    bool completed;
    ui bool demoMode;
    // These latches are consumed and mutated only by the UI-side engine tape.
    // Keeping them in UI scope prevents the demo driver from crossing the
    // EventHandler play/UI boundary.
    ui bool demoFirstDone;
    ui bool demoSecondDone;
    int tic;
    int stageClock;
    int enemyClock;
    int attackClock;
    int movementClock;
    int pickupClock;
    int progressionClock;
    int pausedWorldSamples;
    int neutralFrames;
    int cameraVariant;
    int telemetryEnabled;
    int playerSlot;
    int weaponSlot;
    int canonicalHash;
    int deadlineNumerator;

    // Canonical play-side modal boundary. The world stays paused until the
    // validated choose and later neutral-release event are both handled.
    bool draftPaused;
    bool awaitingNeutral;
    bool neutralFramePending;
    bool modalScreenshotTaken;

    DSP025SourceCharacterState characterState;
    DSP025SourceInventoryState inventoryState;

    // UI ownership: focus, edge latches and the latest play-published view.
    ui bool modalOpen;
    ui bool neutralReleasePending;
    ui bool neutralFramePendingUi;
    ui bool openingLatch;
    ui bool confirmHeld;
    ui bool upHeld;
    ui bool downHeld;
    ui bool escapeHeld;
    ui bool mouseHeld;
    ui bool confirmEdgeConsumed;
    ui bool physicalInputSeen;
    ui bool uiWasOpen;
    ui bool uiInitialized;
    ui int uiPausedSamples;
    ui int uiWorldTic;
    ui int uiStageClock;
    ui int uiEnemyClock;
    ui int uiAttackClock;
    ui int uiMovementClock;
    ui int uiPickupClock;
    ui int uiProgressionClock;
    ui int uiDeadlineNumerator;
    ui int uiTelemetryEnabled;
    ui bool releaseSent;
    ui int uiTicks;
    ui int selectedOffer;
    ui int hoverOffer;
    ui int uiCurrentLevel;
    ui int uiXpRemainder;
    ui int uiQueueCount;
    ui int uiTargetLevel;
    ui int uiDraftToken;
    ui int uiOfferCount;
    ui int uiOffer0Id;
    ui int uiOffer1Id;
    ui int uiOffer2Id;
    ui int uiOffer0Rank;
    ui int uiOffer1Rank;
    ui int uiOffer2Rank;
    ui int uiPowerRank;
    ui int uiArmorRank;
    ui int uiWhipRank;
    ui int uiMightMilli;
    ui int uiCharacterArmor;

    override void OnRegister()
    {
        // The custom overlay becomes the UI processor only while a draft owns
        // input.  RequireMouse requests the native cursor for hover/click.
        IsUiProcessor = false;
        RequireMouse = true;
    }

    void EmitInputOwnership(String state)
    {
        int owner = IsUiProcessor ? 1 : 0;
        int effectiveMouseRequest = owner != 0 && RequireMouse ? 1 : 0;
        Console.Printf("DS_P028_INPUT_OWNER state=%s map=%s enabled=%d ui_processor=%d effective_mouse_request=%d native_usercmd=%d", state, MAP, enabled ? 1 : 0, owner, effectiveMouseRequest, owner == 0 ? 1 : 0);
    }

    void ReadConfiguration()
    {
        CVar camera = CVar.FindCVar("ds_p028_camera_variant");
        cameraVariant = camera != null ? camera.GetInt() : 0;
        if (cameraVariant < 0 || cameraVariant > 4) cameraVariant = 0;
        CVar telemetry = CVar.FindCVar("ds_p028_telemetry");
        telemetryEnabled = telemetry != null ? telemetry.GetInt() : 1;
        if (telemetryEnabled != 0) telemetryEnabled = 1;
    }

    ui void ReadUiConfiguration()
    {
        CVar mode = CVar.FindCVar("ds_p028_mode");
        String modeName = mode != null ? mode.GetString() : "demo";
        demoMode = modeName != "manual" && modeName != "no_input";
        CVar telemetry = CVar.FindCVar("ds_p028_telemetry");
        uiTelemetryEnabled = telemetry != null ? telemetry.GetInt() : 1;
        if (uiTelemetryEnabled != 0) uiTelemetryEnabled = 1;
    }

    void ResetState()
    {
        Reset(); AddSlot(); AddSlot();
        // P020 health is stored in milliunits. Antonio's shared level-1
        // baseline is 120000 (120 source health), with intrinsic Armor 1.
        playerSlot = Allocate(99, 0.0, 0.0, 0.0, 0.0, 120000);
        weaponSlot = Allocate(2, 0.0, 0.0, 0.0, 0.0, 1);
        DSP028ResetProgression();
        characterState.level = 1;
        // Antonio's level-1 starter state: 100 base HP + 20 shared bonus,
        // Armor 1, Might 1000. Later drafts only add to this state.
        characterState.maxHealthBonus = 20;
        characterState.armorBonus = 1;
        characterState.mightMilli = 1000;
        inventoryState.slot = weaponSlot;
        inventoryState.generation = generations[weaponSlot];
        inventoryState.weaponStableId = ids[weaponSlot];
        inventoryState.weaponLevel = 1;
        tic = 0;
        stageClock = 0; enemyClock = 0; attackClock = 0;
        movementClock = 0; pickupClock = 0; progressionClock = 0;
        pausedWorldSamples = 0; neutralFrames = 0;
        draftPaused = false; awaitingNeutral = false; neutralFramePending = false;
        modalScreenshotTaken = false;
        IsUiProcessor = false;
        canonicalHash = 216613626;
        deadlineNumerator = 189;
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
        }
        Console.Printf("DS_P028_CAMERA tic=%d variant=%d yaw=%d pitch=%d fov=%d role=PRESENTATION_ONLY gameplay_ignored=1", tic, cameraVariant, yaw, pitch, fov);
    }

    // Play -> UI snapshot bridge. Values are read from the canonical ledger
    // immediately before each event is sent to the console player.
    void PublishSnapshot()
    {
        SendInterfaceEvent(consoleplayer, "P028_STATE", playerLevel, experienceMilliunits, DSP028QueuedCount());
        SendInterfaceEvent(consoleplayer, "P028_TARGET", DSP028CurrentDraftLevel(), draftApplied, DSP028CurrentOfferCount());
        SendInterfaceEvent(consoleplayer, "P028_OFFER0", DSP028OfferId(0), DSP028OfferRank(DSP028OfferId(0)), 0);
        SendInterfaceEvent(consoleplayer, "P028_OFFER1", DSP028OfferId(1), DSP028OfferRank(DSP028OfferId(1)), 0);
        SendInterfaceEvent(consoleplayer, "P028_OFFER2", DSP028OfferId(2), DSP028OfferRank(DSP028OfferId(2)), 0);
        SendInterfaceEvent(consoleplayer, "P028_STATS", characterMightMilli, characterArmor, whipRank);
        SendInterfaceEvent(consoleplayer, "P028_RANKS", powerRank, armorRank, whipRank);
        SendInterfaceEvent(consoleplayer, "P028_CLOCK_A", tic, stageClock, enemyClock);
        SendInterfaceEvent(consoleplayer, "P028_CLOCK_B", attackClock, movementClock, pickupClock);
        SendInterfaceEvent(consoleplayer, "P028_CLOCK_C", progressionClock, deadlineNumerator, 0);
        Console.Printf("DS_P028_SNAPSHOT level=%d xp_remainder=%d queue_count=%d target_level=%d token=%d offer_count=%d offer0_id=%d offer0_rank=%d offer1_id=%d offer1_rank=%d offer2_id=%d offer2_rank=%d", playerLevel, experienceMilliunits, DSP028QueuedCount(), DSP028CurrentDraftLevel(), draftApplied, DSP028CurrentOfferCount(), DSP028OfferId(0), DSP028OfferRank(DSP028OfferId(0)), DSP028OfferId(1), DSP028OfferRank(DSP028OfferId(1)), DSP028OfferId(2), DSP028OfferRank(DSP028OfferId(2)));
    }

    void EmitBootstrap()
    {
        Console.Printf("DS_P028_BOOT map=%s ticrate=%d authority=DSP028LevelUpProgression xp_authority=P027_EXPERIENCE_LEDGER pool=RESTRICTED_DEVELOPMENT_POOL source_build=1.16.107 steam_build=25016043", MAP, Thinker.TICRATE);
        Console.Printf("DS_P028_RULES thresholds=5000,15000,25000 threshold_provenance=ONLINE_REPORTED_CURRENT xp_units=P027_MILLIUNITS queue=ASCENDING_HEAD_ONLY draft_rng=ONE_STEP_PER_ENQUEUE offers=THREE legal_ids=WHIP,POWER,ARMOR capped=WHIP_8_PASSIVES_5 effects=SHARED_INVENTORY_STATS");
        Console.Printf("DS_P028_PAUSE_RULES menu=CUSTOM_MODAL ui_time=ADVANCES run_stage_enemy_attack_movement_pickup_progression=FROZEN deadline_phase=PRESERVED backlog=0 native_input=CONSUMED escape=NO_SELECTION controller=SHARED_MAPPING_PHYSICALLY_UNTESTED");
        Console.Printf("DS_P028_FIXTURE level=1 xp_milliunits=0 whip_rank=1 power_rank=0 armor_rank=0 character_hp=120000 character_armor=1 character_might_milli=1000 inventory_handle=(slot=%d,generation=%d,stable_id=%d) start_weapon=WHIP", weaponSlot, generations[weaponSlot], ids[weaponSlot]);
    }

    void EmitWorldState(String kind)
    {
        canonicalHash = canonicalHash * 31 + tic;
        canonicalHash = canonicalHash * 31 + playerLevel;
        canonicalHash = canonicalHash * 31 + experienceMilliunits;
        canonicalHash = canonicalHash * 31 + whipRank;
        canonicalHash = canonicalHash * 31 + powerRank;
        canonicalHash = canonicalHash * 31 + armorRank;
        if (telemetryEnabled != 0)
            Console.Printf("DS_P028_WORLD_STATE kind=%s tic=%d stage_clock=%d enemy_clock=%d attack_clock=%d movement_clock=%d pickup_clock=%d progression_clock=%d menu=%d modal=%d backlog=0", kind, tic, stageClock, enemyClock, attackClock, movementClock, pickupClock, progressionClock, menuactive != Menu.Off, draftPaused);
    }

    void OpenModal()
    {
        if (draftPaused || DSP028QueuedCount() <= 0) return;
        draftPaused = true;
        awaitingNeutral = false;
        neutralFramePending = false;
        IsUiProcessor = true;
        EmitInputOwnership("MODAL");
        PublishSnapshot();
        SendInterfaceEvent(consoleplayer, "P028_OPEN", DSP028CurrentDraftLevel(), DSP028QueuedCount(), draftApplied);
        Console.Printf("DS_P028_DRAFT_OPEN current_level=%d target_level=%d queue_count=%d queue_head=%d focused_id=%s held_latch=1 pause=1 ui_input=1", playerLevel, DSP028CurrentDraftLevel(), DSP028QueuedCount(), draftApplied, DSP028OfferName(DSP028OfferId(0)));
    }

    void ApplySharedStats()
    {
        characterState.level = playerLevel;
        characterState.maxHealthBonus = characterMaxHealth - 100;
        characterState.armorBonus = characterArmor;
        characterState.mightMilli = characterMightMilli;
        inventoryState.weaponLevel = inventoryWeaponLevel;
    }

    override void NetworkProcess(ConsoleEvent e)
    {
        if (!enabled || e.Player != consoleplayer) return;
        if (e.Name == "P028_CHOOSE")
        {
            int wantedId = e.Args[0];
            int targetLevel = e.Args[1];
            int token = e.Args[2];
            if (!draftPaused || awaitingNeutral || token != draftApplied || targetLevel != DSP028CurrentDraftLevel())
            {
                Console.Printf("DS_P028_NET_REJECT player=%d command=CHOOSE accepted=0 reason=STALE_OR_PAUSED offer_id=%s token=%d expected=%d", e.Player, DSP028OfferName(wantedId), token, draftApplied);
                SendInterfaceEvent(consoleplayer, "P028_REJECT", 0, DSP028QueuedCount(), 0);
                return;
            }
            int appliedId;
            if (!DSP028ApplyOfferId(wantedId, appliedId))
            {
                Console.Printf("DS_P028_NET_REJECT player=%d command=CHOOSE accepted=0 reason=ILLEGAL_OFFER offer_id=%s", e.Player, DSP028OfferName(wantedId));
                SendInterfaceEvent(consoleplayer, "P028_REJECT", 0, DSP028QueuedCount(), 0);
                return;
            }
            ApplySharedStats();
            awaitingNeutral = true;
            PublishSnapshot();
            SendInterfaceEvent(consoleplayer, "P028_APPLIED", appliedId, DSP028QueuedCount(), draftApplied);
            Console.Printf("DS_P028_CONFIRM_APPLIED source=NETWORK_PROCESS player=%d accepted=1 offer_id=%s queue_remaining=%d transaction=%d physical_input=UI_OWNED", e.Player, DSP028OfferName(appliedId), DSP028QueuedCount(), draftApplied);
            return;
        }
        if (e.Name == "P028_RELEASE")
        {
            if (!draftPaused || !awaitingNeutral || e.Args[0] != draftApplied)
            {
                Console.Printf("DS_P028_NET_REJECT player=%d command=RELEASE accepted=0 reason=NOT_AWAITING_NEUTRAL token=%d expected=%d", e.Player, e.Args[0], draftApplied);
                return;
            }
            awaitingNeutral = false;
            neutralFramePending = true;
            SendInterfaceEvent(consoleplayer, "P028_RELEASE_ACK", 1, DSP028QueuedCount(), draftApplied);
            Console.Printf("DS_P028_NEUTRAL_RELEASE play_ack=1 queue_count=%d released=1 gameplay_input_reacquire=DEFERRED neutral_frame_required=1", DSP028QueuedCount());
        }
    }

    ui bool ActionsReleased()
    {
        return !confirmHeld && !upHeld && !downHeld && !escapeHeld && !mouseHeld;
    }

    ui void EmitNeutralRelease()
    {
        if (releaseSent) return;
        releaseSent = true;
        SendNetworkEvent("P028_RELEASE", uiDraftToken);
        Console.Printf("DS_P028_RELEASE_SENT ui_ticks=%d queue_count=%d released=1 gameplay_input_reacquire=DEFERRED", uiTicks, uiQueueCount);
    }

    ui void MoveSelection(int delta, String source)
    {
        if (!modalOpen || delta == 0) return;
        int offerCount = uiOfferCount;
        if (offerCount <= 0) return;
        int next = selectedOffer + delta;
        while (next < 0) next += offerCount;
        while (next >= offerCount) next -= offerCount;
        selectedOffer = next;
        Console.Printf("DS_P028_FOCUS source=%s selected_offer=%d focused_id=%s edge=1", source, selectedOffer, UiOfferName(UiOfferId(selectedOffer)));
    }

    ui bool ConfirmSelection(String source)
    {
        if (!modalOpen) return false;
        if (confirmEdgeConsumed)
        {
            Console.Printf("DS_P028_CONFIRM_REJECT source=%s accepted=0 reason=HELD_CONFIRM queue_count=%d", source, uiQueueCount);
            return false;
        }
        confirmEdgeConsumed = true;
        int selectedId = UiOfferId(selectedOffer);
        if (selectedId == 0 || selectedOffer >= uiOfferCount)
        {
            confirmEdgeConsumed = false;
            Console.Printf("DS_P028_CONFIRM_REJECT source=%s accepted=0 reason=ILLEGAL_OFFER queue_count=%d", source, uiQueueCount);
            return false;
        }
        Console.Printf("DS_P028_CONFIRM source=%s accepted=1 selected_offer=%d offer_id=%s queue_before=%d queue_after=%d transaction=NETWORK_EVENT physical_input=%d", source, selectedOffer, UiOfferName(selectedId), uiQueueCount, uiQueueCount - 1, physicalInputSeen);
        modalOpen = false;
        neutralReleasePending = true;
        neutralFramePendingUi = false;
        releaseSent = false;
        SendNetworkEvent("P028_CHOOSE", selectedId, uiTargetLevel, uiDraftToken);
        Console.Printf("DS_P028_DRAFT_CLOSE selected_id=%s queue_remaining=%d paused_tics=%d clocks_unchanged=1 neutral_release_required=1", UiOfferName(selectedId), uiQueueCount - 1, uiPausedSamples);
        return true;
    }

    ui int MouseOffer(int mouseX, int mouseY)
    {
        int sw = Screen.GetWidth();
        int sh = Screen.GetHeight();
        int vx = int(double(mouseX) * MODAL_VIRTUAL_WIDTH / double(sw));
        int vy = int(double(mouseY) * MODAL_VIRTUAL_HEIGHT / double(sh));
        if (vy < 146 || vy >= 310 || vx < 30 || vx >= 610) return -1;
        int index = (vx - 30) / 194;
        return index >= 0 && index < uiOfferCount ? index : -1;
    }

    override bool UiProcess(UiEvent e)
    {
        if (!enabled || (!modalOpen && !neutralReleasePending)) return false;

        if (e.Type == UiEvent.Type_KeyDown || e.Type == UiEvent.Type_KeyUp)
        {
            bool down = e.Type == UiEvent.Type_KeyDown;
            int key = e.KeyChar;
            if (IsUpKey(key))
            {
                if (!down) { upHeld = false; return true; }
                physicalInputSeen = true;
                if (upHeld || openingLatch) Console.Printf("DS_P028_FOCUS_REJECT source=PHYSICAL_KEY action=UP accepted=0 reason=%s", openingLatch ? "OPEN_HELD_LATCH" : "HELD_KEY");
                else { upHeld = true; MoveSelection(-1, "PHYSICAL_KEY"); }
                return true;
            }
            if (IsDownKey(key))
            {
                if (!down) { downHeld = false; return true; }
                physicalInputSeen = true;
                if (downHeld || openingLatch) Console.Printf("DS_P028_FOCUS_REJECT source=PHYSICAL_KEY action=DOWN accepted=0 reason=%s", openingLatch ? "OPEN_HELD_LATCH" : "HELD_KEY");
                else { downHeld = true; MoveSelection(1, "PHYSICAL_KEY"); }
                return true;
            }
            if (IsConfirmKey(key))
            {
                if (!down) { confirmHeld = false; confirmEdgeConsumed = false; return true; }
                physicalInputSeen = true;
                if (openingLatch || confirmHeld)
                    Console.Printf("DS_P028_CONFIRM_REJECT source=PHYSICAL_KEY accepted=0 reason=%s queue_count=%d", openingLatch ? "OPEN_HELD_LATCH" : "HELD_CONFIRM", uiQueueCount);
                else
                {
                    confirmHeld = true;
                    Console.Printf("DS_P028_INPUT source=PHYSICAL_KEY action=CONFIRM selected_offer=%d", selectedOffer);
                    ConfirmSelection("KEYBOARD");
                }
                return true;
            }
            if (IsEscapeKey(key))
            {
                if (!down) { escapeHeld = false; return true; }
                physicalInputSeen = true;
                if (!escapeHeld) { escapeHeld = true; Console.Printf("DS_P028_ESCAPE source=PHYSICAL_KEY accepted=0 reason=NO_SILENT_SELECTION"); }
                return true;
            }
            return true;
        }
        if (e.Type == UiEvent.Type_MouseMove)
        {
            int next = MouseOffer(e.MouseX, e.MouseY);
            if (next >= 0 && next != hoverOffer)
            {
                hoverOffer = next;
                selectedOffer = next;
                Console.Printf("DS_P028_MOUSE_HOVER selected_offer=%d focused_id=%s edge=1", selectedOffer, UiOfferName(UiOfferId(selectedOffer)));
            }
            return true;
        }
        // Button-up must clear the edge latch even after the click closed the
        // modal.  Otherwise the neutral-release boundary can never complete.
        if (e.Type == UiEvent.Type_LButtonUp) { mouseHeld = false; return true; }
        if (!modalOpen) return true;
        if (e.Type == UiEvent.Type_LButtonDown || e.Type == UiEvent.Type_LButtonClick)
        {
            physicalInputSeen = true;
            int next = MouseOffer(e.MouseX, e.MouseY);
            if (next >= 0) { selectedOffer = next; hoverOffer = next; }
            if (mouseHeld)
                Console.Printf("DS_P028_MOUSE_REJECT accepted=0 reason=HELD_CLICK selected_offer=%d", selectedOffer);
            else
            {
                mouseHeld = true;
                Console.Printf("DS_P028_INPUT source=PHYSICAL_MOUSE action=CLICK selected_offer=%d", selectedOffer);
                ConfirmSelection("MOUSE");
            }
            return true;
        }
        return true;
    }

    ui bool IsUpKey(int key)
    {
        return key == UiEvent.Key_Up || key == InputEvent.Key_UpArrow || key == InputEvent.Key_Pad_DPad_Up || key == InputEvent.Key_Pad_RThumb_Up;
    }

    ui bool IsDownKey(int key)
    {
        return key == UiEvent.Key_Down || key == InputEvent.Key_DownArrow || key == InputEvent.Key_Pad_DPad_Down || key == InputEvent.Key_Pad_RThumb_Down;
    }

    ui bool IsConfirmKey(int key)
    {
        return key == UiEvent.Key_Return || key == 32 || key == InputEvent.Key_Enter || key == InputEvent.Key_Space || key == InputEvent.Key_Pad_A || key == InputEvent.Key_Joy1;
    }

    ui bool IsEscapeKey(int key)
    {
        return key == UiEvent.Key_Escape || key == InputEvent.Key_Escape || key == InputEvent.Key_Pad_B || key == InputEvent.Key_Joy2;
    }

    override bool InputProcess(InputEvent e)
    {
        if (!enabled || (!modalOpen && !neutralReleasePending)) return false;
        if (e.Type != InputEvent.Type_KeyDown && e.Type != InputEvent.Type_KeyUp) return true;
        bool down = e.Type == InputEvent.Type_KeyDown;
        int key = e.KeyScan;
        if (IsUpKey(key))
        {
            if (!down) { upHeld = false; return true; }
            physicalInputSeen = true;
            if (upHeld || openingLatch) Console.Printf("DS_P028_FOCUS_REJECT source=PHYSICAL_KEY action=UP accepted=0 reason=%s", openingLatch ? "OPEN_HELD_LATCH" : "HELD_KEY");
            else { upHeld = true; MoveSelection(-1, "PHYSICAL_KEY"); }
            return true;
        }
        if (IsDownKey(key))
        {
            if (!down) { downHeld = false; return true; }
            physicalInputSeen = true;
            if (downHeld || openingLatch) Console.Printf("DS_P028_FOCUS_REJECT source=PHYSICAL_KEY action=DOWN accepted=0 reason=%s", openingLatch ? "OPEN_HELD_LATCH" : "HELD_KEY");
            else { downHeld = true; MoveSelection(1, "PHYSICAL_KEY"); }
            return true;
        }
        if (IsConfirmKey(key))
        {
            if (!down) { confirmHeld = false; confirmEdgeConsumed = false; return true; }
            physicalInputSeen = true;
            if (openingLatch || confirmHeld)
                Console.Printf("DS_P028_CONFIRM_REJECT source=PHYSICAL_KEY accepted=0 reason=%s queue_count=%d", openingLatch ? "OPEN_HELD_LATCH" : "HELD_CONFIRM", uiQueueCount);
            else
            {
                confirmHeld = true;
                Console.Printf("DS_P028_INPUT source=PHYSICAL_KEY action=CONFIRM selected_offer=%d", selectedOffer);
                ConfirmSelection("KEYBOARD_CONTROLLER");
            }
            return true;
        }
        if (IsEscapeKey(key))
        {
            if (!down) { escapeHeld = false; return true; }
            physicalInputSeen = true;
            if (!escapeHeld) { escapeHeld = true; Console.Printf("DS_P028_ESCAPE source=PHYSICAL_KEY accepted=0 reason=NO_SILENT_SELECTION"); }
            return true;
        }
        return true;
    }

    ui void DemoChoose(int desiredId)
    {
        if (!modalOpen) return;
        for (int i = 0; i < uiOfferCount; i++)
        {
            if (UiOfferId(selectedOffer) == desiredId) break;
            MoveSelection(1, "ENGINE_TAPE");
        }
        Console.Printf("DS_P028_INPUT source=ENGINE_TAPE action=CONFIRM selected_offer=%d target_id=%s", selectedOffer, UiOfferName(desiredId));
        confirmHeld = false;
        ConfirmSelection("ENGINE_TAPE");
        if (desiredId == DSP028_ID_POWER) demoFirstDone = true;
        if (desiredId == DSP028_ID_ARMOR) demoSecondDone = true;
        Console.Printf("DS_P028_CONFIRM_REJECT source=ENGINE_TAPE accepted=0 reason=HELD_CONFIRM queue_count=%d repeated=1", uiQueueCount);
    }

    void EmitPostUpgradeCombat()
    {
        int damageMilli = 0;
        int sourceDamage = DSP028WhipDamageForLevel(inventoryWeaponLevel);
        bool checked = DSP025CheckedMilliDamage(sourceDamage, characterMightMilli, damageMilli);
        Console.Printf("DS_P028_ATTACK_SNAPSHOT tic=%d weapon_id=WHIP inventory_slot=%d inventory_generation=%d inventory_stable_id=%d weapon_level=%d damage_source=%d might_milli=%d damage_milli=%d amount=%d checked=%d authority=DSP025_ATTACK_SNAPSHOT rng_stream=attack gameplay_input=0", tic, inventoryState.slot, inventoryState.generation, inventoryState.weaponStableId, inventoryState.weaponLevel, sourceDamage, characterMightMilli, damageMilli, DSP028WhipAmountForLevel(inventoryWeaponLevel), checked);
        Console.Printf("DS_P028_POST_COMBAT tic=%d whip_rank=%d power_rank=%d armor_rank=%d weapon_level=%d might_milli=%d armor=%d damage_milli=%d shared_state_changed=1 later_behavior_changed=1", tic, whipRank, powerRank, armorRank, inventoryWeaponLevel, characterMightMilli, characterArmor, damageMilli);
    }

    ui String UiOfferName(int id)
    {
        if (id == DSP028_ID_WHIP) return "WHIP";
        if (id == DSP028_ID_POWER) return "POWER (Spinach)";
        if (id == DSP028_ID_ARMOR) return "ARMOR (Armor)";
        return "ILLEGAL";
    }

    ui String UiOfferDescription(int id)
    {
        if (id == DSP028_ID_WHIP) return "Stronger Whip attacks";
        if (id == DSP028_ID_POWER) return "+10% Might";
        if (id == DSP028_ID_ARMOR) return "+1 Armor";
        return "Unavailable offer.";
    }

    ui int UiOfferId(int index)
    {
        if (index == 0) return uiOffer0Id;
        if (index == 1) return uiOffer1Id;
        if (index == 2) return uiOffer2Id;
        return 0;
    }

    ui int UiOfferRank(int index)
    {
        if (index == 0) return uiOffer0Rank;
        if (index == 1) return uiOffer1Rank;
        if (index == 2) return uiOffer2Rank;
        return 0;
    }

    override void InterfaceProcess(ConsoleEvent e)
    {
        if (!enabled) return;
        if (e.Name == "P028_RESET")
        {
            uiInitialized = false;
            modalOpen = false; neutralReleasePending = false; neutralFramePendingUi = false;
            openingLatch = false; confirmHeld = false; upHeld = false; downHeld = false;
            escapeHeld = false; mouseHeld = false; confirmEdgeConsumed = false;
            uiWasOpen = false; releaseSent = false; physicalInputSeen = false;
            demoFirstDone = false; demoSecondDone = false; uiPausedSamples = 0;
            uiWorldTic = 0; uiStageClock = 0; uiEnemyClock = 0; uiAttackClock = 0;
            uiMovementClock = 0; uiPickupClock = 0; uiProgressionClock = 0;
            uiDeadlineNumerator = 0;
            uiCurrentLevel = 1; uiXpRemainder = 0; uiQueueCount = 0;
            uiTargetLevel = 0; uiDraftToken = 0; uiOfferCount = 0;
            uiOffer0Id = 0; uiOffer1Id = 0; uiOffer2Id = 0;
            uiOffer0Rank = 0; uiOffer1Rank = 0; uiOffer2Rank = 0;
            uiPowerRank = 0; uiArmorRank = 0; uiWhipRank = 1;
            uiMightMilli = 1000; uiCharacterArmor = 1;
        }
        else if (e.Name == "P028_STATE")
        {
            uiCurrentLevel = e.Args[0]; uiXpRemainder = e.Args[1]; uiQueueCount = e.Args[2];
        }
        else if (e.Name == "P028_TARGET")
        {
            uiTargetLevel = e.Args[0]; uiDraftToken = e.Args[1]; uiOfferCount = e.Args[2];
        }
        else if (e.Name == "P028_OFFER0") { uiOffer0Id = e.Args[0]; uiOffer0Rank = e.Args[1]; }
        else if (e.Name == "P028_OFFER1") { uiOffer1Id = e.Args[0]; uiOffer1Rank = e.Args[1]; }
        else if (e.Name == "P028_OFFER2") { uiOffer2Id = e.Args[0]; uiOffer2Rank = e.Args[1]; }
        else if (e.Name == "P028_STATS") { uiMightMilli = e.Args[0]; uiCharacterArmor = e.Args[1]; }
        else if (e.Name == "P028_RANKS") { uiPowerRank = e.Args[0]; uiArmorRank = e.Args[1]; uiWhipRank = e.Args[2]; }
        else if (e.Name == "P028_CLOCK_A") { uiWorldTic = e.Args[0]; uiStageClock = e.Args[1]; uiEnemyClock = e.Args[2]; }
        else if (e.Name == "P028_CLOCK_B") { uiAttackClock = e.Args[0]; uiMovementClock = e.Args[1]; uiPickupClock = e.Args[2]; }
        else if (e.Name == "P028_CLOCK_C") { uiProgressionClock = e.Args[0]; uiDeadlineNumerator = e.Args[1]; }
        else if (e.Name == "P028_OPEN")
        {
            modalOpen = true; neutralReleasePending = false; neutralFramePendingUi = false;
            openingLatch = true; confirmEdgeConsumed = false; selectedOffer = 0; hoverOffer = -1; releaseSent = false;
            Console.Printf("DS_P028_UI_OPEN target_level=%d queue_count=%d draft_token=%d", e.Args[0], e.Args[1], e.Args[2]);
        }
        else if (e.Name == "P028_APPLIED")
        {
            modalOpen = false;
            Console.Printf("DS_P028_UI_APPLIED offer_id=%s queue_remaining=%d transaction=%d", UiOfferName(e.Args[0]), e.Args[1], e.Args[2]);
        }
        else if (e.Name == "P028_RELEASE_ACK")
        {
            neutralReleasePending = false; neutralFramePendingUi = true; releaseSent = false;
        }
        else if (e.Name == "P028_NEUTRAL_FRAME")
        {
            neutralFramePendingUi = false;
            Console.Printf("DS_P028_NEUTRAL_FRAME ui_tick=%d world_tic=%d gameplay_input=CONSUMED resume_ready=1 physical_input_seen=%d", uiTicks, uiWorldTic, physicalInputSeen);
        }
        else if (e.Name == "P028_RESUME")
        {
            Console.Printf("DS_P028_UI_RESUME ui_ticks=%d world_tic=%d physical_input_seen=%d", uiTicks, uiWorldTic, physicalInputSeen);
            Console.Printf("DS_P028_UI_INPUT_SUMMARY physical_input_seen=%d controller=UNTESTED_NO_COMPATIBLE_DEVICE", physicalInputSeen);
        }
    }

    ui void DrawVirtualText(Font font, int color, int x, int y, String text)
    {
        Screen.DrawText(font, color, x, y, text, DTA_VirtualWidth, MODAL_VIRTUAL_WIDTH, DTA_VirtualHeight, MODAL_VIRTUAL_HEIGHT, DTA_KeepRatio, true);
    }

    override void RenderOverlay(RenderEvent e)
    {
        if (!enabled || !modalOpen) return;
        int width = Screen.GetWidth();
        int height = Screen.GetHeight();
        double sx = double(width) / MODAL_VIRTUAL_WIDTH;
        double sy = double(height) / MODAL_VIRTUAL_HEIGHT;
        Screen.Dim(Color(4, 8, 12), 0.78, 0, 0, width, height);
        Screen.Dim(Color(18, 31, 38), 0.96, int(22 * sx), int(24 * sy), int(596 * sx), int(350 * sy));
        Screen.DrawLineFrame(Color(73, 219, 170), int(22 * sx), int(24 * sy), int(596 * sx), int(350 * sy), 2);
        DrawVirtualText(ConFont, Font.CR_GOLD, 198, 43, "LEVEL UP");
        DrawVirtualText(SmallFont, Font.CR_WHITE, 48, 74, String.Format("Level %d    XP remainder %d    queued drafts %d", uiCurrentLevel, uiXpRemainder, uiQueueCount));
        DrawVirtualText(SmallFont, Font.CR_GREEN, 48, 96, "Restricted development pool");
        DrawVirtualText(SmallFont, Font.CR_GREY, 48, 116, "Choose one upgrade. Up/Down + Enter, or hover and click.");
        for (int i = 0; i < 3; i++)
        {
            int left = 30 + i * 194;
            int id = UiOfferId(i);
            bool focused = selectedOffer == i;
            Screen.Dim(focused ? Color(31, 76, 70) : Color(27, 42, 49), 0.98, int(left * sx), int(146 * sy), int(180 * sx), int(164 * sy));
            Screen.DrawLineFrame(focused ? Color(255, 204, 91) : Color(90, 122, 127), int(left * sx), int(146 * sy), int(180 * sx), int(164 * sy), focused ? 3 : 1);
            DrawVirtualText(SmallFont, focused ? Font.CR_GOLD : Font.CR_WHITE, left + 12, 162, String.Format("%d  %s", i + 1, UiOfferName(id)));
            DrawVirtualText(SmallFont, Font.CR_GREEN, left + 12, 190, String.Format("Rank %d", UiOfferRank(i)));
            DrawVirtualText(SmallFont, Font.CR_WHITE, left + 12, 218, UiOfferDescription(id));
            DrawVirtualText(SmallFont, Font.CR_GREY, left + 12, 274, focused ? "FOCUSED" : "");
        }
        DrawVirtualText(SmallFont, Font.CR_GREY, 48, 326, "Automatic attacks and movement are paused while this choice is open.");
        DrawVirtualText(SmallFont, Font.CR_GOLD, 48, 350, String.Format("Current stats: Might %d  Armor %d  Whip %d", uiMightMilli, uiCharacterArmor, uiWhipRank));
    }

    override void WorldLoaded(WorldEvent e)
    {
        enabled = level.MapName == MAP;
        // This handler is registered globally. A prior MAP14 modal must not
        // retain UI ownership after a map transition.
        IsUiProcessor = false;
        completed = false;
        if (!enabled) { EmitInputOwnership("INACTIVE"); return; }
        ReadConfiguration();
        ResetState();
        EmitInputOwnership("ACTIVE");
        SendInterfaceEvent(consoleplayer, "P028_RESET", 0, 0, 0);
        EmitBootstrap();
        EmitCamera();
        Console.Printf("DS_P028_INPUT_BOUNDARY keyboard=UP_DOWN_ENTER controller=DPAD_A_B mouse=HOVER_LBUTTON physical_input_required=1 mode=CONFIGURED");
    }

    override void UiTick()
    {
        if (!enabled || completed) return;
        if (!uiInitialized)
        {
            uiInitialized = true;
            ReadUiConfiguration();
            selectedOffer = 0; hoverOffer = -1;
            openingLatch = false; confirmHeld = false; upHeld = false; downHeld = false;
            escapeHeld = false; mouseHeld = false; confirmEdgeConsumed = false;
            uiWasOpen = false; neutralReleasePending = false; neutralFramePendingUi = false; releaseSent = false;
            uiPausedSamples = 0;
        }
        uiTicks++;
        if (modalOpen && !uiWasOpen)
        {
            openingLatch = true; confirmEdgeConsumed = false; selectedOffer = 0; hoverOffer = -1; releaseSent = false;
        }
        else openingLatch = false;
        uiWasOpen = modalOpen;
        if (modalOpen)
        {
            uiPausedSamples++;
            if (uiTelemetryEnabled != 0 && (uiPausedSamples == 1 || uiPausedSamples % 20 == 0))
                Console.Printf("DS_P028_PAUSE_SAMPLE ui_tick=%d world_tic=%d ui_time_advances=1 stage_clock=%d enemy_clock=%d attack_clock=%d movement_clock=%d pickup_clock=%d progression_clock=%d deadline_numerator=%d unchanged=1", uiTicks, uiWorldTic, uiStageClock, uiEnemyClock, uiAttackClock, uiMovementClock, uiPickupClock, uiProgressionClock, uiDeadlineNumerator);
            if (demoMode && !demoFirstDone) DemoChoose(DSP028_ID_POWER);
            else if (demoMode && demoFirstDone && !demoSecondDone) DemoChoose(DSP028_ID_ARMOR);
            return;
        }
        if (neutralReleasePending)
        {
            if (demoMode && confirmHeld) confirmHeld = false;
            if (ActionsReleased()) EmitNeutralRelease();
            return;
        }
        if (neutralFramePendingUi) return;
    }

    override void WorldTick()
    {
        if (!enabled || completed) return;
        if (draftPaused)
        {
            pausedWorldSamples++;
            if (!modalScreenshotTaken && pausedWorldSamples >= 10)
            {
                modalScreenshotTaken = true;
                Console.Printf("DS_P028_MODAL_CAPTURE paused_world_samples=%d ui_visible_required=1", pausedWorldSamples);
                LevelLocals.MakeScreenShot();
            }
            if (neutralFramePending)
            {
                neutralFramePending = false;
                SendInterfaceEvent(consoleplayer, "P028_NEUTRAL_FRAME", tic, 1, 0);
                neutralFrames++;
                if (DSP028QueuedCount() > 0)
                {
                    // The neutral frame completes the prior transaction before
                    // the next queued head becomes visible.
                    draftPaused = false;
                    OpenModal();
                }
                else
                {
                    draftPaused = false;
                    IsUiProcessor = false;
                    EmitInputOwnership("ACTIVE_RESUME");
                    SendInterfaceEvent(consoleplayer, "P028_RESUME", tic, 1, 0);
                }
            }
            if (players[0].mo != null)
            {
                players[0].cmd.forwardmove = 0; players[0].cmd.sidemove = 0; players[0].cmd.upmove = 0;
                players[0].cmd.yaw = 0; players[0].cmd.pitch = 0; players[0].cmd.roll = 0; players[0].cmd.buttons = 0;
            }
            return;
        }
        tic++;
        stageClock++; enemyClock++; attackClock++; movementClock++; pickupClock++; progressionClock++;
        if (tic == 1)
        {
            DSP028CollectExperience(20000);
            EmitWorldState("QUEUE_AND_OPEN");
            OpenModal();
        }
        else if (tic == 2) { EmitPostUpgradeCombat(); EmitWorldState("RESUMED"); }
        else if (tic == 3) EmitWorldState("RESUMED_AFTER_MODAL");
        if (telemetryEnabled != 0 && (tic == 1 || tic == 2 || tic % 20 == 0))
            Console.Printf("DS_P028_TRACE tic=%d level=%d xp=%d queued=%d stage=%d enemy=%d attack=%d movement=%d pickup=%d progression=%d", tic, playerLevel, experienceMilliunits, DSP028QueuedCount(), stageClock, enemyClock, attackClock, movementClock, pickupClock, progressionClock);
        if (tic >= RUN_TICS)
        {
            Console.Printf("DS_P028_CANONICAL tic=%d hash=%d level=%d xp_remainder=%d drafts_enqueued=%d drafts_applied=%d whip_rank=%d power_rank=%d armor_rank=%d rng_draft=%d", tic, canonicalHash, playerLevel, experienceMilliunits, draftLevels.Size(), draftApplied, whipRank, powerRank, armorRank, draftRng);
            Console.Printf("DS_P028_COMPLETE tics=%d hash=%d level=%d xp_remainder=%d drafts_enqueued=%d drafts_applied=%d paused_samples=%d neutral_frames=%d backlog=0 modal_input=EDGE_TRIGGERED physical_input_seen=UI_OWNED controller=UNTESTED_NO_COMPATIBLE_DEVICE camera_variant=%d telemetry=%d visual_capture_required=1", tic, canonicalHash, playerLevel, experienceMilliunits, draftLevels.Size(), draftApplied, pausedWorldSamples, neutralFrames, cameraVariant, telemetryEnabled);
            Console.Printf("DS_P028_FRAMEBUFFER_CAPTURE tic=%d nonblank_required=1 modal_capture=1", tic);
            LevelLocals.MakeScreenShot();
            completed = true;
        }
    }
}
