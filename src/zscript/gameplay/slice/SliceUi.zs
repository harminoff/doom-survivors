// HUD, level-up, results and input handling for DSP030VerticalSlice.
// Part of DSP030VerticalSlice (fields and core lifecycle live in
// gameplay/VerticalSlice.zs).

extend class DSP030VerticalSlice
{
    ui bool IsUpKey(int key) { return key == InputEvent.Key_UpArrow || key == UiEvent.Key_Up; }

    ui bool IsDownKey(int key) { return key == InputEvent.Key_DownArrow || key == UiEvent.Key_Down; }

    ui int UiChoiceCount()
    {
        if (!uiP031Mode) return 3;
        if (uiOfferCount < 0) return 0;
        return uiOfferCount > 3 ? 3 : uiOfferCount;
    }

    // UiProcess receives GUI KeyChar values, so it accepts ASCII W/S here.
    // InputProcess keeps using KeyScan and intentionally does not use these
    // aliases for native gameplay input.
    ui bool IsUiUpKey(int key) { return IsUpKey(key) || key == 87 || key == 119; }

    ui bool IsUiDownKey(int key) { return IsDownKey(key) || key == 83 || key == 115; }

    ui bool IsConfirmKey(int key) { return key == InputEvent.Key_Enter || key == UiEvent.Key_Return || key == InputEvent.Key_Space || key == 32; }

    ui bool IsEscapeKey(int key) { return key == InputEvent.Key_Escape || key == UiEvent.Key_Escape; }

    // Level-up action for a GUI KeyChar: R reroll, X skip, B banish; 0 = none.
    ui int LevelUpActionKey(int key)
    {
        if (key == 82 || key == 114) return LEVELUP_ACTION_REROLL;
        if (key == 88 || key == 120) return LEVELUP_ACTION_SKIP;
        if (key == 66 || key == 98) return LEVELUP_ACTION_BANISH;
        return 0;
    }

    ui int LevelUpActionCharges(int kind)
    {
        if (kind == LEVELUP_ACTION_REROLL) return uiRerolls;
        if (kind == LEVELUP_ACTION_SKIP) return uiSkips;
        return uiBanishes;
    }

    // Level-up layout (640x400 virtual): one row per offer, stacked like the
    // original's list, then the Reroll / Skip / Banish buttons.
    const LV_ROW_LEFT = 136;
    const LV_ROW_W = 368;
    const LV_ROW_TOP = 88;
    const LV_ROW_STEP = 66;
    const LV_ROW_H = 60;
    const LV_BTN_TOP = 290;
    const LV_BTN_W = 112;
    const LV_BTN_H = 22;

    // Action buttons under the offer rows, left to right: Reroll, Skip, Banish.
    ui int ActionButtonLeft(int kind) { return 144 + (kind - 1) * (LV_BTN_W + 8); }

    ui int MouseActionButton(int mouseX, int mouseY)
    {
        if (!uiP031Mode) return 0;
        double s = DSShellMenu.Scale();
        int vx = int((mouseX - DSShellMenu.OffX()) / s); int vy = int((mouseY - DSShellMenu.OffY()) / s);
        if (vy < LV_BTN_TOP || vy >= LV_BTN_TOP + LV_BTN_H) return 0;
        for (int kind = LEVELUP_ACTION_REROLL; kind <= LEVELUP_ACTION_BANISH; kind++)
        {
            int left = ActionButtonLeft(kind);
            if (vx >= left && vx < left + LV_BTN_W) return kind;
        }
        return 0;
    }

    ui void SendLevelUpAction(int kind)
    {
        if (LevelUpActionCharges(kind) <= 0) return;
        SendNetworkEvent("P030_LEVELUP_ACTION", kind, selectedOffer, 0);
    }

    override bool InputProcess(InputEvent e)
    {
        if (!enabled) return false;
        // C toggles the third-person camera during a run.
        if (runState == STATE_ACTIVE && e.Type == InputEvent.Type_KeyDown && (e.KeyChar == 67 || e.KeyChar == 99 || e.KeyScan == 46))
        {
            CVar cam = CVar.FindCVar("ds_camera");
            if (cam != null) cam.SetInt(cam.GetInt() != 0 ? 0 : 1);
            return true;
        }
        // The Depths: Tab or M toggles the full map (the minimap is always on).
        if (runState == STATE_ACTIVE && dgActive && e.Type == InputEvent.Type_KeyDown
            && (e.KeyScan == InputEvent.Key_Tab || e.KeyChar == 77 || e.KeyChar == 109 || e.KeyScan == 50))
        {
            CVar fullMap = CVar.FindCVar("ds_dg_fullmap");
            if (fullMap != null) fullMap.SetInt(fullMap.GetInt() != 0 ? 0 : 1);
            return true;
        }
        if (runState == STATE_LEVELUP)
        {
            if (e.Type != InputEvent.Type_KeyDown && e.Type != InputEvent.Type_KeyUp) return true;
            bool down = e.Type == InputEvent.Type_KeyDown; int key = e.KeyScan;
            int choices = UiChoiceCount();
            if (IsUpKey(key)) { if (!down || choices <= 0) return true; selectedOffer = (selectedOffer + choices - 1) % choices; Console.Printf("DS_P030_LEVELUP_FOCUS source=PHYSICAL_KEY selected_offer=%d", selectedOffer); return true; }
            if (IsDownKey(key)) { if (!down || choices <= 0) return true; selectedOffer = (selectedOffer + 1) % choices; Console.Printf("DS_P030_LEVELUP_FOCUS source=PHYSICAL_KEY selected_offer=%d", selectedOffer); return true; }
            if (IsConfirmKey(key))
            {
                if (!down) { choiceHeld = false; return true; }
                if (choices <= 0) return true;
                if (choiceHeld) { Console.Printf("DS_P030_LEVELUP_REJECT reason=HELD_CONFIRM"); return true; }
                choiceHeld = true; SendNetworkEvent("P030_CHOICE", selectedOffer, 0, 0); return true;
            }
            return true;
        }
        if (runState == STATE_RESULTS)
        {
            if (e.Type != InputEvent.Type_KeyDown && e.Type != InputEvent.Type_KeyUp) return true;
            bool down = e.Type == InputEvent.Type_KeyDown; int key = e.KeyScan;
            if (IsEscapeKey(key))
            {
                if (!down) { returnHeld = false; return true; }
                if (!returnHeld) { returnHeld = true; Menu.SetMenu('MainMenu'); SendNetworkEvent("P030_RETURN"); Console.Printf("DS_P030_RETURN_MENU_OPENED source=PHYSICAL_KEY menu=MainMenu results_closed=1"); }
                return true;
            }
            if (IsConfirmKey(key))
            {
                if (!down) { choiceHeld = false; return true; }
                if (!choiceHeld) { choiceHeld = true; SendNetworkEvent("P030_RETRY"); }
                return true;
            }
            return true;
        }
        return false;
    }

    ui int MouseOffer(int mouseX, int mouseY)
    {
        double s = DSShellMenu.Scale();
        int vx = int((mouseX - DSShellMenu.OffX()) / s); int vy = int((mouseY - DSShellMenu.OffY()) / s);
        if (vx < LV_ROW_LEFT || vx >= LV_ROW_LEFT + LV_ROW_W) return -1;
        int count = UiChoiceCount();
        for (int index = 0; index < count; index++)
        {
            int top = LV_ROW_TOP + index * LV_ROW_STEP;
            if (vy >= top && vy < top + LV_ROW_H) return index;
        }
        return -1;
    }

    override bool UiProcess(UiEvent e)
    {
        if (!enabled || (!uiModalOpen && !uiResultsOpen)) return false;
        if (e.Type == UiEvent.Type_KeyDown || e.Type == UiEvent.Type_KeyUp)
        {
            bool down = e.Type == UiEvent.Type_KeyDown;
            int key = e.KeyChar;
            if (uiModalOpen)
            {
                int choices = UiChoiceCount();
                if (IsUiUpKey(key))
                {
                    if (!down) { upHeld = false; return true; }
                    if (choices <= 0) return true;
                    if (upHeld) { Console.Printf("DS_P030_LEVELUP_FOCUS_REJECT source=PHYSICAL_KEY action=UP reason=HELD_KEY"); return true; }
                    upHeld = true;
                    selectedOffer = (selectedOffer + choices - 1) % choices;
                    Console.Printf("DS_P030_LEVELUP_FOCUS source=PHYSICAL_KEY selected_offer=%d", selectedOffer);
                    return true;
                }
                if (IsUiDownKey(key))
                {
                    if (!down) { downHeld = false; return true; }
                    if (choices <= 0) return true;
                    if (downHeld) { Console.Printf("DS_P030_LEVELUP_FOCUS_REJECT source=PHYSICAL_KEY action=DOWN reason=HELD_KEY"); return true; }
                    downHeld = true;
                    selectedOffer = (selectedOffer + 1) % choices;
                    Console.Printf("DS_P030_LEVELUP_FOCUS source=PHYSICAL_KEY selected_offer=%d", selectedOffer);
                    return true;
                }
                if (IsConfirmKey(key))
                {
                    if (!down) { choiceHeld = false; return true; }
                    if (choices <= 0) return true;
                    if (choiceHeld) { Console.Printf("DS_P030_LEVELUP_REJECT reason=HELD_CONFIRM"); return true; }
                    choiceHeld = true;
                    SendNetworkEvent("P030_CHOICE", selectedOffer, 0, 0);
                    return true;
                }
                int actionKind = uiP031Mode ? LevelUpActionKey(key) : 0;
                if (actionKind > 0)
                {
                    if (!down) { actionHeld = false; return true; }
                    if (!actionHeld) { actionHeld = true; SendLevelUpAction(actionKind); }
                    return true;
                }
                return true;
            }
            if (IsEscapeKey(key))
            {
                if (!down) { returnHeld = false; return true; }
                if (!returnHeld)
                {
                    returnHeld = true;
                    Menu.SetMenu('MainMenu');
                    SendNetworkEvent("P030_RETURN");
                    Console.Printf("DS_P030_RETURN_MENU_OPENED source=PHYSICAL_KEY menu=MainMenu results_closed=1");
                }
                return true;
            }
            if (IsConfirmKey(key))
            {
                if (!down) { choiceHeld = false; return true; }
                if (!choiceHeld) { choiceHeld = true; SendNetworkEvent("P030_RETRY"); }
                return true;
            }
            return true;
        }
        if (e.Type == UiEvent.Type_MouseMove)
        {
            int next = MouseOffer(e.MouseX, e.MouseY);
            if (next >= 0 && next != hoverOffer) { hoverOffer = next; selectedOffer = next; Console.Printf("DS_P030_LEVELUP_FOCUS source=PHYSICAL_MOUSE selected_offer=%d", selectedOffer); }
            return true;
        }
        if (e.Type == UiEvent.Type_LButtonUp) { mouseHeld = false; return true; }
        if (e.Type == UiEvent.Type_LButtonDown || e.Type == UiEvent.Type_LButtonClick)
        {
            int button = uiModalOpen ? MouseActionButton(e.MouseX, e.MouseY) : 0;
            if (button > 0)
            {
                if (!mouseHeld) { mouseHeld = true; SendLevelUpAction(button); }
                return true;
            }
            int next = MouseOffer(e.MouseX, e.MouseY);
            if (uiP031Mode && next < 0) return true;
            if (next >= 0) selectedOffer = next;
            if (mouseHeld) Console.Printf("DS_P030_LEVELUP_REJECT reason=HELD_CLICK");
            else { mouseHeld = true; SendNetworkEvent("P030_CHOICE", selectedOffer, 0, 0); }
            return true;
        }
        return true;
    }

    override void InterfaceProcess(ConsoleEvent e)
    {
        if (!enabled) return;
        if (e.Name == "P031_MODE")
        {
            uiP031Mode = e.Args[0] != 0;
        }
        else if (e.Name == "P032_MAP16_MODE")
        {
            uiP032Route = e.Args[0] != 0;
            uiP032BloodyTear = e.Args[1] != 0;
        }
        else if (e.Name == "P032_MAP16_WEAPON")
        {
            uiP032Route = true;
            uiP032BloodyTear = e.Args[0] == DSP032_ID_BLOODY_TEAR;
        }
        else if (e.Name == "P030_RESET")
        {
            uiModalOpen = false; uiResultsOpen = false; selectedOffer = 0; hoverOffer = -1;
            upHeld = false; downHeld = false; choiceHeld = false; mouseHeld = false; returnHeld = false;
            modalScreenshotDelay = 0; resultsScreenshotDelay = 0; combatScreenshotTaken = false;
            uiTic = 0; uiHealth = PLAYER_HEALTH; uiHealthCap = PLAYER_HEALTH; uiLevel = 1; uiXp = 0; uiKills = 0;
            uiEnemies = 0; uiPickups = 0; uiCap = 15; uiWhipRank = 1; uiPowerRank = 0;
            uiArmor = 1; uiChoices = 0; uiThreatFront = 0; uiThreatSide = 0; uiThreatRear = 0;
            uiNearbyPickups = 0; uiSweepLobe = 0; uiSweepActive = 0;
            uiOfferCount = 0; uiTargetLevel = 0;
            uiP033DisplayLogged = false;
        }
        else if (e.Name == "P030_STATE") { uiTic = e.Args[0]; uiHealth = e.Args[1]; uiLevel = e.Args[2]; }
        else if (e.Name == "P033_MAP16_HEALTH_CAP") { uiHealthCap = e.Args[0]; }
        else if (e.Name == "P030_STATE_B") { uiXp = e.Args[0]; uiKills = e.Args[1]; uiEnemies = e.Args[2]; }
        else if (e.Name == "P030_STATE_C") { uiPickups = e.Args[0]; uiCap = e.Args[1]; uiWhipRank = e.Args[2]; }
        else if (e.Name == "P030_STATE_D") { uiThreatFront = e.Args[0]; uiThreatSide = e.Args[1]; uiThreatRear = e.Args[2]; }
        else if (e.Name == "P030_STATE_E") { uiNearbyPickups = e.Args[0]; uiSweepLobe = e.Args[1]; uiSweepActive = e.Args[2]; }
        else if (e.Name == "P030_STATS") { uiPowerRank = e.Args[0]; uiArmor = e.Args[1]; uiChoices = e.Args[2]; }
        else if (e.Name == "P030_OFFER0") { uiOffer0Id = e.Args[0]; uiOffer0Rank = e.Args[1]; uiTargetLevel = e.Args[2]; }
        else if (e.Name == "P030_OFFER1") { uiOffer1Id = e.Args[0]; uiOffer1Rank = e.Args[1]; uiOfferCount = e.Args[2]; }
        else if (e.Name == "P030_OFFER2") { uiOffer2Id = e.Args[0]; uiOffer2Rank = e.Args[1]; }
        else if (e.Name == "P031_MAP16_OFFER_COUNT") { uiOfferCount = e.Args[0]; }
        else if (e.Name == "P030_OPEN")
        {
            uiModalOpen = true; uiResultsOpen = false; selectedOffer = 0; hoverOffer = -1;
            upHeld = false; downHeld = false; choiceHeld = false; mouseHeld = false; returnHeld = false;
            modalScreenshotDelay = 2; resultsScreenshotDelay = 0;
            uiTargetLevel = e.Args[0]; if (!uiP031Mode) uiOfferCount = 3;
            if (uiP031Mode) Console.Printf("DS_P031_MAP16_UI_OPEN target_level=%d choice_count=%d selected_offer=%d ui_modal=1", uiTargetLevel, uiOfferCount, selectedOffer);
        }
        else if (e.Name == "P030_CHARGES") { uiRerolls = e.Args[0]; uiSkips = e.Args[1]; uiBanishes = e.Args[2]; }
        else if (e.Name == "P030_REFRESH")
        {
            // Reroll or Banish changed the offers; keep the modal open.
            int count = UiChoiceCount();
            if (selectedOffer >= count) selectedOffer = count > 0 ? count - 1 : 0;
            hoverOffer = -1;
        }
        else if (e.Name == "P030_APPLIED")
        {
            uiModalOpen = false; upHeld = false; downHeld = false;
            choiceHeld = false; mouseHeld = false; returnHeld = false;
        }
        else if (e.Name == "P030_RESULTS")
        {
            uiModalOpen = false; uiResultsOpen = true; modalScreenshotDelay = 0; resultsScreenshotDelay = 2;
            upHeld = false; downHeld = false; choiceHeld = false; mouseHeld = false; returnHeld = false;
            uiResultsRunId = e.Args[0]; uiResultsElapsed = e.Args[1]; uiKills = e.Args[2];
            uiResultsStart = level.maptime;
        }
        else if (e.Name == "P030_RESULTS_STATS") { uiResultsDamage = e.Args[0]; uiResultsXp = e.Args[1]; uiResultsCurrency = e.Args[2]; }
        else if (e.Name == "P030_RESULTS_LEVEL") { uiResultsLevel = e.Args[0]; uiWhipRank = e.Args[1]; uiArmor = e.Args[2]; }
    }

    override void UiTick()
    {
        if (!enabled) return;
        uiTicks++;
        // HUD juice (presentation only): the health trail holds briefly after
        // a hit and then drains; the level badge flashes on a level-up.
        int hpCap = hudHealthCap > 0 ? hudHealthCap : PLAYER_HEALTH;
        double hpFrac = hpCap > 0 ? clamp(double(playerHealth) / hpCap, 0.0, 1.0) : 0.0;
        if (hpFrac >= hudHpTrail) { hudHpTrail = hpFrac; hudHpTrailHold = 18; }
        else if (hudHpTrailHold > 0) hudHpTrailHold--;
        else hudHpTrail = max(hpFrac, hudHpTrail - 0.012);
        if (playerLevel != hudLevelShown) { if (hudLevelShown > 0) hudLevelFlash = 35; hudLevelShown = playerLevel; }
        else if (hudLevelFlash > 0) hudLevelFlash--;
        if (uiP031Mode && uiP032Route && !uiP033DisplayLogged
            && uiHealthCap > 0 && uiHealthCap % 1000 != 0)
        {
            uiP033DisplayLogged = true;
            Console.Printf("DS_P033_MAP16_HEALTH_DISPLAY accepted=1 internal_hp_milli=%d displayed_hp=%d internal_cap_milli=%d displayed_cap=%d rounding=NEAREST_WHOLE route=ACTUAL_MAP16_HUD", uiHealth, DSP033StatRules.DisplayHealthRounded(uiHealth), uiHealthCap, DSP033StatRules.DisplayHealthRounded(uiHealthCap));
        }
        bool nowPaused = Level.WorldPaused();
        if (nowPaused != nativePauseWasOpen)
        {
            nativePauseWasOpen = nowPaused;
            Console.Printf("DS_P030_NATIVE_PAUSE ui_tick=%d open=%d world_tic=%d source_clock_frozen=1", uiTicks, nowPaused, tic);
            if (p037RouteEnabled)
                Console.Printf("DS_P037_MAP16_PAUSE open=%d world_tic=%d orbit_hash=%d source_clock_frozen=1 authority=UZDOOM_WORLD_PAUSE", nowPaused, tic, p037LastPlayOrbitHash);
        }
        if (modalScreenshotDelay > 0)
        {
            modalScreenshotDelay--;
            if (modalScreenshotDelay == 0 && uiModalOpen)
            {
                Console.Printf("DS_P030_MODAL_CAPTURE ui_tick=%d world_tic=%d ui_visible_required=1", uiTicks, uiTic);
                LevelLocals.MakeScreenShot();
            }
            if (modalScreenshotDelay > 0) return;
        }
        if (resultsScreenshotDelay > 0)
        {
            resultsScreenshotDelay--;
            if (resultsScreenshotDelay == 0 && uiResultsOpen)
            {
                Console.Printf("DS_P030_RESULTS_CAPTURE ui_tick=%d world_tic=%d ui_visible_required=1", uiTicks, uiTic);
                LevelLocals.MakeScreenShot();
            }
        }
        // Art review aid for automated runs: ds_shot_interval_tics > 0 takes
        // a screenshot every that many logical tics during active play.
        CVar shotInterval = CVar.FindCVar("ds_shot_interval_tics");
        int shotEvery = shotInterval != null ? shotInterval.GetInt() : 0;
        if (shotEvery > 0 && !uiModalOpen && !uiResultsOpen && uiTic >= uiNextShot)
        {
            uiNextShot = uiTic + shotEvery;
            LevelLocals.MakeScreenShot();
        }
        if (!combatScreenshotTaken && !uiModalOpen && !uiResultsOpen && uiTic >= 350)
        {
            combatScreenshotTaken = true;
            Console.Printf("DS_P030_COMBAT_CAPTURE ui_tick=%d world_tic=%d ui_visible_required=1 telemetry_suppressed=1", uiTicks, uiTic);
            LevelLocals.MakeScreenShot();
        }
        // Harness mode drives the same modal intent boundary as keyboard or
        // mouse input. Manual mode never enters this path, so the shipped
        // launcher always leaves choices to the player.
        if (uiModalOpen && configuredMode != "manual" && !choiceHeld)
        {
            choiceHeld = true;
            Console.Printf("DS_P030_LEVELUP_INPUT source=ENGINE_TAPE action=CONFIRM selected_offer=%d", selectedOffer);
            SendNetworkEvent("P030_CHOICE", selectedOffer, 0, 0);
        }
    }

    ui void DrawText(Font font, int color, int xPos, int yPos, String text)
    {
        Screen.DrawText(font, color, xPos, yPos, text, DTA_VirtualWidth, 640, DTA_VirtualHeight, 400, DTA_KeepRatio, true);
    }

    // HUD (640x400 virtual, aspect kept, like the shell menu): XP bar across
    // the top, weapon and passive slots at top left, the timer at top
    // centre, kills and gold at top right, health at bottom centre.
    ui void HudBox(Color c, double alpha, double bx, double by, double bw, double bh)
    {
        double s = DSShellMenu.Scale();
        Screen.Dim(c, alpha, int(DSShellMenu.OffX() + bx * s), int(DSShellMenu.OffY() + by * s), int(bw * s), int(bh * s));
    }

    ui String HudName(int id)
    {
        if (DSN2Catalog.IsKnown(id)) return DSN2Catalog.DisplayName(id);
        if (DSLimitBreak.IsOffer(id)) return DSLimitBreak.Name(id);
        if (DSArcana.IsOffer(id)) return DSArcana.Name(DSArcana.Number(id));
        if (id == DSP031_ID_FALLBACK_GOLD) return "Gold";
        if (id == DSP031_ID_FALLBACK_CHICKEN) return "Floor Chicken";
        return UiOfferName(id);
    }

    ui String HudAbbrev(int id)
    {
        String label = HudName(id);
        Array<String> words;
        label.Split(words, " ", TOK_SKIPEMPTY);
        if (words.Size() >= 2) return String.Format("%s%s", words[0].Left(1), words[1].Left(1));
        return label.Left(2);
    }

    // Left and right edges of the real screen in virtual units, so the HUD
    // hugs the screen corners on any aspect ratio.
    ui double HudLeft() { return -DSShellMenu.OffX() / DSShellMenu.Scale(); }
    ui double HudRight() { return DSShellMenu.VW + DSShellMenu.OffX() / DSShellMenu.Scale(); }

    // One row of owned weapons or passives: framed slots, the level in the
    // corner, a gold frame once the item is at max level.
    ui void DrawItemSlots(int category, double left, double top)
    {
        int shown = 0;
        for (int i = 0; i < dsp031ItemIds.Size() && shown < 6; i++)
        {
            if (dsp031ItemCategories[i] != category) continue;
            double x = left + shown * 21;
            int id = dsp031ItemIds[i];
            int maxRank = DSN2Catalog.MaxRank(id);
            bool maxed = maxRank > 0 && dsp031ItemRanks[i] >= maxRank;
            TextureID icon = TexMan.CheckForTexture(String.Format("HI%03d", id), TexMan.Type_Any);
            if (icon.IsValid()) DSUi.ItemSlot(id, x, top, 20, maxed);
            else
            {
                DSUi.Slot(x, top, 20, maxed);
                DSShellMenu.Text(SmallFont, maxed ? Font.CR_GOLD : Font.CR_WHITE, x + 4, top + 5, HudAbbrev(id));
            }
            String rank = maxed ? "M" : String.Format("%d", dsp031ItemRanks[i]);
            DSShellMenu.Text(SmallFont, maxed ? Font.CR_GOLD : Font.CR_WHITE, x + 18 - SmallFont.StringWidth(rank) * 0.8, top + 12, rank, 0.8);
            shown++;
        }
    }

    // Edge arrows toward things worth walking to (like the original's
    // treasure pointers). The ring around the screen centre is a radar: an
    // arrow at the top means straight ahead, at the left means turn left, at
    // the bottom means behind you. Presentation only.
    ui void DrawTargetArrow(double tx, double ty, Color tint, int count)
    {
        let pawn = players[consoleplayer].mo;
        if (pawn == null) return;
        double dx = tx - playerX; double dy = ty - playerY;
        double dist = sqrt(dx * dx + dy * dy);
        if (dist < 220.0) return;
        double rel = Actor.deltaangle(pawn.Angle, atan2(dy, dx));   // positive = to the left
        if (abs(rel) < 32.0 && dist < 1500.0) return;               // already in view and near
        double sx = 320.0 - sin(rel) * 270.0;
        double sy = 214.0 - cos(rel) * 130.0;
        TextureID arrow = TexMan.CheckForTexture("DSARROW", TexMan.Type_Any);
        if (!arrow.IsValid()) return;
        double s = DSShellMenu.Scale();
        Screen.DrawTexture(arrow, false, DSShellMenu.OffX() + sx * s, DSShellMenu.OffY() + sy * s,
            DTA_DestWidth, int(22 * s), DTA_DestHeight, int(22 * s), DTA_CenterOffset, true,
            DTA_Rotate, rel, DTA_FillColor, tint, DTA_Alpha, 0.9);
        String label = String.Format("%d", int(dist / 64.0));
        DSShellMenu.Text(SmallFont, Font.CR_WHITE, sx - SmallFont.StringWidth(label) * 0.5, sy + 12, label, 1.0);
    }

    ui void DrawPickupArrows()
    {
        CVar toggle = CVar.FindCVar("ds_arrows");
        if (toggle != null && toggle.GetInt() == 0) return;
        if (!mfEnabled || runState != STATE_ACTIVE) return;
        int count = 0;
        // The Depths: the way on (stairs or Amulet) once found, or the way out.
        double gx; double gy;
        if (dgActive && DgGoal(gx, gy)) { DrawTargetArrow(gx, gy, Color(255, 255, 255), count); count++; }
        // Chests: boss chests gold, Arcana chests purple (negative item count).
        for (int i = 0; i < mfChestIds.Size() && count < 24; i++)
        {
            int index = dsp032ChestIds.Find(mfChestIds[i]);
            if (index >= dsp032ChestIds.Size()) continue;
            DrawTargetArrow(dsp032ChestX[index], dsp032ChestY[index], mfChestItems[i] < 0 ? Color(190, 90, 255) : Color(255, 205, 60), count);
            count++;
        }
        // Stage items (the weapons and passives lying around the map): only
        // the five nearest, so a stage full of them does not flood the screen.
        Array<double> itemDist;
        for (int i = 0; i < gmItemId.Size(); i++)
            itemDist.Push((gmItemX[i] - playerX) * (gmItemX[i] - playerX) + (gmItemY[i] - playerY) * (gmItemY[i] - playerY));
        for (int i = 0; i < gmItemId.Size() && count < 24; i++)
        {
            int nearer = 0;
            for (int j = 0; j < itemDist.Size(); j++) if (itemDist[j] < itemDist[i]) nearer++;
            if (nearer >= 5) continue;
            DrawTargetArrow(gmItemX[i], gmItemY[i], Color(80, 230, 255), count);
            count++;
        }
        // Trap plates and doors that are ready: the nearest four, doors in
        // violet and plates in orange (coffins, the merchant and relics have
        // their own arrows).
        Array<double> plateDist;
        for (int i = 0; i < gmPlateKind.Size(); i++)
        {
            int pk = gmPlateKind[i];
            bool wanted = (pk >= 1 && pk <= 5) && tic >= gmPlateReady[i];
            plateDist.Push(wanted ? (gmPlateX[i] - playerX) * (gmPlateX[i] - playerX) + (gmPlateY[i] - playerY) * (gmPlateY[i] - playerY) : 1.0e18);
        }
        for (int i = 0; i < gmPlateKind.Size() && count < 24; i++)
        {
            if (plateDist[i] >= 1.0e18) continue;
            int nearer = 0;
            for (int j = 0; j < plateDist.Size(); j++) if (plateDist[j] < plateDist[i]) nearer++;
            if (nearer >= 4) continue;
            DrawTargetArrow(gmPlateX[i], gmPlateY[i], gmPlateKind[i] == 5 ? Color(180, 120, 255) : Color(255, 90, 60), count);
            count++;
        }
        // The merchant and the wheel.
        for (int i = 0; i < gmPlateKind.Size() && count < 24; i++)
        {
            if (gmPlateKind[i] != 6 && gmPlateKind[i] != 7) continue;
            DrawTargetArrow(gmPlateX[i], gmPlateY[i], Color(255, 170, 60), count);
            count++;
        }
        // Coffins that are still closed.
        for (int i = 0; i < gmPlateKind.Size() && count < 24; i++)
        {
            if ((gmPlateKind[i] != 8 && gmPlateKind[i] != 9) || gmPlateReady[i] >= tic + 500000) continue;
            DrawTargetArrow(gmPlateX[i], gmPlateY[i], Color(255, 120, 120), count);
            count++;
        }
        // Useful floor pickups (no coins; Floor Chicken only when hurt).
        int cap = hudHealthCap > 0 ? hudHealthCap : PLAYER_HEALTH;
        for (int i = 0; i < mfItemIds.Size() && count < 24; i++)
        {
            int kind = mfItemKinds[i];
            if (kind == MF_ITEM_COIN || kind == MF_ITEM_COIN_BAG || kind == MF_ITEM_RICH_BAG) continue;
            if (kind == MF_ITEM_CHICKEN && playerHealth * 10 > cap * 6) continue;
            DrawTargetArrow(mfItemX[i], mfItemY[i], Color(110, 255, 120), count);
            count++;
        }
    }

    ui void DrawHud()
    {
        DrawPickupArrows();
        int seconds = max(0, uiTic - mfHeld) / 35;
        int displayedHealth = DSP033StatRules.DisplayHealthRounded(playerHealth);
        int cap = hudHealthCap > 0 ? hudHealthCap : PLAYER_HEALTH;
        int displayedHealthCap = DSP033StatRules.DisplayHealthRounded(cap);

        double hl = HudLeft(); double hr = HudRight();

        // XP bar across the whole top edge, the level in a badge at its end.
        double xpFraction = hudXpNeed > 0 ? clamp(double(experienceMilliunits) / hudXpNeed, 0.0, 1.0) : 0.0;
        String levelText = String.Format("LV %d", playerLevel);
        double badgeW = SmallFont.StringWidth(levelText) * 1.2 + 14;
        DSUi.Bar(hl + 2, 2, hr - hl - 6 - badgeW, 13, xpFraction, "DSUIXP");
        bool flash = hudLevelFlash > 0 && (hudLevelFlash / 4) % 2 == 0;
        DSUi.Button(hr - 2 - badgeW, 1, badgeW, 15, flash ? DSUi.BTN_FOCUS : DSUi.BTN_NORMAL);
        DSShellMenu.Text(SmallFont, flash ? Font.CR_WHITE : Font.CR_GOLD, hr - 2 - badgeW + 7, 3.5, levelText, 1.2);

        if (tic < gmToastUntil)
        {
            double toastW = min(560.0, SmallFont.StringWidth(gmToast) * 1.4) + 24;
            DSUi.Button(320 - toastW / 2, 90, toastW, 22, DSUi.BTN_NORMAL);
            DSShellMenu.FitCenter(SmallFont, Font.CR_GOLD, 95, gmToast, 560, 1.4);
        }
        // The Depths: the goal line and minimap, or the full map (Tab / M).
        if (dgActive)
        {
            CVar fullMap = CVar.FindCVar("ds_dg_fullmap");
            if (fullMap != null && fullMap.GetInt() != 0) DgDrawFullMap();
            else
            {
                DSShellMenu.FitCenter(SmallFont, dgAmulet ? Font.CR_GOLD : Font.CR_ORANGE, 42, DgGoalText(), 300, 1.0);
                DgDrawMinimap();
            }
        }
        DrawItemSlots(DSP031_CATEGORY_WEAPON, hl + 4, 19);
        DrawItemSlots(DSP031_CATEGORY_PASSIVE, hl + 4, 41);

        // Timer: big, centred under the XP bar (the original's layout).
        DSShellMenu.CenterText(BigFont, Font.CR_WHITE, 20, String.Format("%02d:%02d", seconds / 60, seconds % 60), 1.15);

        // Kills and gold, right-aligned under the level badge.
        String killText = String.Format("%d", kills);
        String goldText = String.Format("%d", mfGold);
        DSShellMenu.Text(SmallFont, Font.CR_WHITE, hr - 22 - SmallFont.StringWidth(killText) * 1.3, 22, killText, 1.3);
        DSUi.Pic("DSICSKL", hr - 18, 20, 14, 14);
        DSShellMenu.Text(SmallFont, Font.CR_GOLD, hr - 22 - SmallFont.StringWidth(goldText) * 1.3, 39, goldText, 1.3);
        DSUi.Pic("DSICGLD", hr - 18, 37, 14, 14);

        // Health: a framed bar at the bottom centre with a drain trail; the
        // heart beats when health is low.
        double healthFraction = cap > 0 ? clamp(double(playerHealth) / cap, 0.0, 1.0) : 0.0;
        bool low = healthFraction < 0.3 && playerHealth > 0;
        DSUi.Bar(222, 372, 196, 14, healthFraction, "DSUIHP", hudHpTrail);
        double beat = low ? 2.0 * abs(sin(uiTicks * 12.0)) : 0;
        DSUi.Pic("DSICHP", 205 - beat / 2, 370 - beat / 2, 16 + beat, 16 + beat);
        DSShellMenu.CenterText(SmallFont, Font.CR_WHITE, 374, String.Format("%d / %d", displayedHealth, displayedHealthCap));

        // First person hides what is behind you, so flag it.
        if (uiThreatRear > 0)
        {
            String behind = String.Format("%d BEHIND", uiThreatRear);
            double bw = SmallFont.StringWidth(behind) * 1.2 + 20;
            DSUi.Fill(Color(90, 0, 0), 0.55 + 0.25 * abs(sin(uiTicks * 10.0)), 320 - bw / 2, 352, bw, 15);
            DSShellMenu.CenterText(SmallFont, Font.CR_WHITE, 354, behind, 1.2);
        }
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

    ui String UiOfferName(int id)
    {
        if (id == DSP028_ID_WHIP) return "WHIP";
        if (id == DSP028_ID_POWER) return "POWER (Spinach)";
        if (id == DSP028_ID_ARMOR) return "ARMOR (Armor)";
        if (id == DSP031_ID_HOLLOW_HEART) return "HOLLOW HEART";
        if (id == DSP031_ID_EMPTY_TOME) return "EMPTY TOME";
        if (id == DSP031_ID_FALLBACK_GOLD) return "GOLD (approximation)";
        if (id == DSP031_ID_FALLBACK_CHICKEN) return "FLOOR CHICKEN (approximation)";
        return "ILLEGAL";
    }

    // Arrow cursor pointing right at (x, y), bobbing; presentation only.
    ui void DrawCursor(double x, double y)
    {
        TextureID arrow = TexMan.CheckForTexture("DSARROW", TexMan.Type_Any);
        if (!arrow.IsValid()) return;
        double bob = 2.0 * sin(uiTicks * 14.0);
        double s = DSShellMenu.Scale();
        Screen.DrawTexture(arrow, false, DSShellMenu.OffX() + (x + bob) * s, DSShellMenu.OffY() + y * s,
            DTA_DestWidth, int(16 * s), DTA_DestHeight, int(16 * s), DTA_CenterOffset, true,
            DTA_Rotate, -90.0, DTA_FillColor, Color(255, 190, 60));
    }

    ui void DrawLevelUp()
    {
        Screen.Dim(Color(6, 2, 2), 0.72, 0, 0, Screen.GetWidth(), Screen.GetHeight());
        // What you already carry, as on the original's level-up screen.
        DrawItemSlots(DSP031_CATEGORY_WEAPON, HudLeft() + 4, 19);
        DrawItemSlots(DSP031_CATEGORY_PASSIVE, HudLeft() + 4, 41);
        DSUi.Panel(LV_ROW_LEFT - 16, 30, LV_ROW_W + 32, 330);
        bool arcanaPick = DSArcana.IsOffer(UiOfferId(0));
        DSUi.Header(40, arcanaPick ? "ARCANA" : "LEVEL UP!", arcanaPick ? Font.CR_PURPLE : Font.CR_GOLD, 1.3, LV_ROW_W / 2 + 16);
        DSShellMenu.CenterText(SmallFont, Font.CR_GREY, 68, arcanaPick ? "Choose one Arcana" : String.Format("Level %d  -  choose one", uiTargetLevel), 1.0);
        int choiceCount = UiChoiceCount();
        for (int index = 0; index < choiceCount; index++)
        {
            int id = UiOfferId(index);
            int rank = UiOfferRank(index);
            double left = LV_ROW_LEFT; double top = LV_ROW_TOP + index * LV_ROW_STEP;
            double right = left + LV_ROW_W;
            bool focused = selectedOffer == index;
            bool known = DSN2Catalog.IsKnown(id);
            bool weapon = known && DSN2Catalog.Category(id) == DSP031_CATEGORY_WEAPON;
            DSUi.Button(left, top, LV_ROW_W, LV_ROW_H, focused ? DSUi.BTN_FOCUS : DSUi.BTN_NORMAL);
            if (focused) DrawCursor(left - 10, top + LV_ROW_H / 2);
            DSShellMenu.Text(SmallFont, Font.CR_DARKGRAY, right - 10, top + LV_ROW_H - 13, String.Format("%d", index + 1), 0.9);
            double textLeft = left + 58;
            double textW = right - 10 - textLeft;
            if (DSArcana.IsOffer(id))
            {
                int n = DSArcana.Number(id);
                DSUi.Slot(left + 8, top + 10, 40);
                String numeral = DSArcana.NUMERALS[n];
                DSShellMenu.Text(BigFont, Font.CR_PURPLE, left + 28 - BigFont.StringWidth(numeral) * 0.4, top + 23, numeral, 0.8);
                DSShellMenu.FitText(SmallFont, focused ? Font.CR_GOLD : Font.CR_WHITE, textLeft, top + 7, DSArcana.Name(n), textW - 60, 1.3);
                String tag = String.Format("Arcana %s", numeral);
                DSShellMenu.Text(SmallFont, Font.CR_PURPLE, right - 10 - SmallFont.StringWidth(tag), top + 8, tag);
                BrokenLines lines = SmallFont.BreakLines(DSArcana.Blurb(n), int(textW));
                for (int l = 0; l < lines.Count() && l < 3; l++)
                    DSShellMenu.Text(SmallFont, Font.CR_GREY, textLeft, top + 24 + l * 11, lines.StringAt(l));
                continue;
            }
            if (known) DSUi.ItemSlot(id, left + 8, top + 10, 40, false);
            else DSUi.Slot(left + 8, top + 10, 40);
            String status = rank <= 1 ? "NEW!" : String.Format("Level %d", rank);
            if (DSLimitBreak.IsOffer(id)) status = "LIMIT BREAK";
            int statusColour = rank <= 1 || DSLimitBreak.IsOffer(id) ? Font.CR_ORANGE : Font.CR_WHITE;
            double statusW = SmallFont.StringWidth(status) * 1.1;
            DSShellMenu.Text(SmallFont, statusColour, right - 10 - statusW, top + 8, status, 1.1);
            DSShellMenu.FitText(SmallFont, focused ? Font.CR_GOLD : Font.CR_WHITE, textLeft, top + 7, HudName(id), textW - statusW - 8, 1.3);
            if (DSLimitBreak.IsOffer(id))
            {
                DSShellMenu.Text(SmallFont, Font.CR_GOLD, textLeft, top + 26, DSLimitBreak.StatText(DSLimitBreak.Stat(id)), 1.2);
                continue;
            }
            // Type and level pips (filled up to the level this pick gives; the newest one hot).
            DSShellMenu.Text(SmallFont, weapon ? Font.CR_CYAN : Font.CR_GREEN, textLeft, top + 23, weapon ? "Weapon" : "Passive", 0.9);
            int maxRank = known ? DSN2Catalog.MaxRank(id) : 0;
            if (maxRank > 1)
            {
                int shown = min(maxRank, 9);
                double pipLeft = textLeft + 44;
                for (int pip = 1; pip <= shown; pip++)
                {
                    Color pc = pip == rank ? Color(255, 170, 50) : (pip < rank ? Color(230, 210, 170) : Color(60, 50, 50));
                    DSUi.Fill(Color(0, 0, 0), 1.0, pipLeft + (pip - 1) * 9, top + 24, 7, 6);
                    DSUi.Fill(pc, 1.0, pipLeft + (pip - 1) * 9 + 1, top + 25, 5, 4);
                }
            }
            String description = known ? DSItemText.Describe(id)
                : (id == DSP028_ID_WHIP ? "Stronger automatic slash" : id == DSP028_ID_POWER ? "+10% Might" : id == DSP028_ID_ARMOR ? "+1 Armor" : "");
            BrokenLines lines = SmallFont.BreakLines(description, int(textW));
            for (int l = 0; l < lines.Count() && l < 2; l++)
                DSShellMenu.Text(SmallFont, Font.CR_GREY, textLeft, top + 35 + l * 11, lines.StringAt(l));
        }
        if (uiP031Mode)
        {
            for (int kind = LEVELUP_ACTION_REROLL; kind <= LEVELUP_ACTION_BANISH; kind++)
            {
                int charges = arcanaPick && kind == LEVELUP_ACTION_BANISH ? 0 : LevelUpActionCharges(kind);
                int left = ActionButtonLeft(kind);
                DSUi.Button(left, LV_BTN_TOP, LV_BTN_W, LV_BTN_H, charges > 0 ? DSUi.BTN_NORMAL : DSUi.BTN_OFF);
                String label = String.Format("%s  %d", kind == LEVELUP_ACTION_REROLL ? "Reroll" : kind == LEVELUP_ACTION_SKIP ? "Skip" : "Banish", charges);
                DSShellMenu.Text(SmallFont, charges > 0 ? Font.CR_WHITE : Font.CR_DARKGRAY,
                    left + (LV_BTN_W - SmallFont.StringWidth(label) * 1.1) / 2, LV_BTN_TOP + 6, label, 1.1);
            }
            DSUi.Hints(334, "W/S|Select;Enter|Confirm;R|Reroll;X|Skip;B|Banish");
        }
        else DSUi.Hints(334, "W/S|Select;Enter|Confirm");
    }

    ui void DrawResults()
    {
        Screen.Dim(Color(6, 2, 2), 0.82, 0, 0, Screen.GetWidth(), Screen.GetHeight());
        DSUi.Panel(70, 28, 500, 344);
        bool survived = uiResultsElapsed >= RunEndTic() || dgEscaped;
        DSUi.Header(40, dgEscaped ? "ESCAPED" : (survived ? "SURVIVED" : "GAME OVER"), survived ? Font.CR_GOLD : Font.CR_RED, 1.4, 250);
        String who = DSCharacters.Name(rsActive ? rsCharacter : DSCharacters.ANTONIO);
        DSShellMenu.FitCenter(SmallFont, Font.CR_GREY, 70, String.Format("%s  -  %s  -  Run %d", who, DSStage.Name(mfStage), uiResultsRunId), 460, 1.1);

        // Run summary.
        double sx = 92; double sr = 300;
        DSUi.Fill(Color(0, 0, 0), 0.35, sx - 6, 90, sr - sx + 12, 136);
        DSUi.StatLine(sx, sr, 98, "Survived", String.Format("%02d:%02d", uiResultsElapsed / 2100, (uiResultsElapsed / 35) % 60), Font.CR_WHITE, 1.2);
        DSUi.StatLine(sx, sr, 120, "Level reached", String.Format("%d", uiResultsLevel), Font.CR_WHITE, 1.2);
        DSUi.StatLine(sx, sr, 142, "Enemies defeated", String.Format("%d", uiKills), Font.CR_WHITE, 1.2);
        DSUi.StatLine(sx, sr, 164, "Gold earned", String.Format("+%d", uiResultsCurrency), Font.CR_GOLD, 1.2);
        DSUi.StatLine(sx, sr, 186, "Damage dealt", String.Format("%d", uiResultsDamage / 1000), Font.CR_WHITE, 1.2);
        DSUi.StatLine(sx, sr, 208, "Experience", String.Format("%d", uiResultsXp / 1000), Font.CR_WHITE, 1.2);
        if (metaNewUnlocks.Length() > 0)
        {
            DSShellMenu.Text(SmallFont, Font.CR_ORANGE, sx, 240, "NEW UNLOCKS", 1.1);
            BrokenLines unlockLines = SmallFont.BreakLines(metaNewUnlocks, int(sr - sx));
            for (int l = 0; l < unlockLines.Count() && l < 5; l++)
                DSShellMenu.Text(SmallFont, Font.CR_CYAN, sx, 256 + l * 12, unlockLines.StringAt(l));
        }

        // Build at the end of the run.
        DSUi.Fill(Color(120, 40, 20), 0.8, 318, 92, 1, 210);
        double bx = 334; double br = 552;
        DSShellMenu.Text(SmallFont, Font.CR_ORANGE, bx, 96, "WEAPONS", 1.1);
        DSShellMenu.Text(SmallFont, Font.CR_ORANGE, bx, 206, "PASSIVES", 1.1);
        int weaponRow = 0; int passiveRow = 0;
        for (int i = 0; i < dsp031ItemIds.Size(); i++)
        {
            int rid = dsp031ItemIds[i];
            double ry = -1;
            if (dsp031ItemCategories[i] == DSP031_CATEGORY_WEAPON && weaponRow < 6) ry = 110 + 15 * weaponRow++;
            else if (dsp031ItemCategories[i] != DSP031_CATEGORY_WEAPON && passiveRow < 6) ry = 220 + 15 * passiveRow++;
            if (ry < 0) continue;
            int maxRank = DSN2Catalog.MaxRank(rid);
            bool maxed = maxRank > 0 && dsp031ItemRanks[i] >= maxRank;
            if (DSN2Catalog.IsKnown(rid)) DSUi.ItemSlot(rid, bx, ry, 14, maxed);
            DSShellMenu.FitText(SmallFont, Font.CR_WHITE, bx + 20, ry + 2, HudName(rid), 170);
            String rlv = maxed ? "MAX" : String.Format("Lv %d", dsp031ItemRanks[i]);
            DSShellMenu.Text(SmallFont, maxed ? Font.CR_GOLD : Font.CR_GREY, br - SmallFont.StringWidth(rlv), ry + 2, rlv);
        }

        // Retry / Main Menu.
        DSUi.Button(176, 318, 136, 26, DSUi.BTN_FOCUS);
        DSUi.Button(328, 318, 136, 26, DSUi.BTN_NORMAL);
        DSUi.KeyHint(176 + (136 - DSUi.KeyHint(0, 0, "Enter", "Retry", false)) / 2, 326, "Enter", "Retry");
        DSUi.KeyHint(328 + (136 - DSUi.KeyHint(0, 0, "Esc", "Main Menu", false)) / 2, 326, "Esc", "Main Menu");
    }

    override void RenderOverlay(RenderEvent e)
    {
        if (!enabled) return;
        if (uiResultsOpen)
        {
            // Third person: let the fall play for two seconds before the panel.
            CVar cam = CVar.FindCVar("ds_camera");
            bool thirdPerson = cam != null && cam.GetInt() != 0;
            if (thirdPerson && playerHealth <= 0 && level.maptime - uiResultsStart < 70)
                DSShellMenu.CenterText(BigFont, Font.CR_RED, 40, "YOU DIED", 1.6);
            else DrawResults();
        }
        else if (uiModalOpen) DrawLevelUp();
        else DrawHud();
    }
}
