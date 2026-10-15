// P031 user-facing pre-run Seal and in-run draft controls.
// UI owns presentation and input only; all mutations cross NetworkProcess.
mixin class DSP031DraftFullUi
{
    const DSP031_UI_WIDTH = 640;
    const DSP031_UI_HEIGHT = 400;

    ui int p031UiPhase; // 0 hidden, 1 profile, 2 draft, 3 neutral release
    ui int p031UiModeRead;
    ui bool p031UiDemo;
    ui bool p031UiSealDemo;
    ui bool p031UiAuditDemo;
    ui bool p031UiHoldModal;
    ui bool p031UiHoldAfterReroll;
    ui int p031UiSelected;
    ui int p031UiHover;
    ui int p031UiSealMask;
    ui int p031UiSealCapacity;
    ui int p031UiLevel;
    ui int p031UiXp;
    ui int p031UiQueue;
    ui int p031UiTarget;
    ui int p031UiToken;
    ui int p031UiActionId;
    ui int p031UiOfferCount;
    ui int p031UiOffer0;
    ui int p031UiOffer1;
    ui int p031UiOffer2;
    ui int p031UiOffer3;
    ui int p031UiRank0;
    ui int p031UiRank1;
    ui int p031UiRank2;
    ui int p031UiRank3;
    ui int p031UiRerolls;
    ui int p031UiSkips;
    ui int p031UiBanishes;
    ui int p031UiWhipRank;
    ui int p031UiPowerRank;
    ui int p031UiArmorRank;
    ui int p031UiRevision;
    ui int p031UiDemoStep;
    ui int p031UiAwaitRevision;
    ui bool p031UiOpeningLatch;
    ui bool p031UiConfirmHeld;
    ui bool p031UiLeftHeld;
    ui bool p031UiRightHeld;
    ui bool p031UiSpaceHeld;
    ui bool p031UiMouseHeld;
    ui bool p031UiReleaseSent;
    ui bool p031UiAwaitApplied;
    ui bool p031UiStaleSent;
    ui bool p031UiPhysicalInput;

    ui void DSP031UiReset()
    {
        p031UiPhase = 0;
        p031UiModeRead = 0;
        p031UiDemo = false;
        p031UiSealDemo = false;
        p031UiAuditDemo = false;
        p031UiHoldModal = false;
        p031UiHoldAfterReroll = false;
        p031UiSelected = 0;
        p031UiHover = -1;
        p031UiSealMask = 0;
        p031UiSealCapacity = 0;
        p031UiLevel = 1;
        p031UiXp = 0;
        p031UiQueue = 0;
        p031UiTarget = 0;
        p031UiToken = 0;
        p031UiActionId = 1;
        p031UiOfferCount = 0;
        p031UiOffer0 = 0; p031UiOffer1 = 0; p031UiOffer2 = 0; p031UiOffer3 = 0;
        p031UiRank0 = 0; p031UiRank1 = 0; p031UiRank2 = 0; p031UiRank3 = 0;
        p031UiRerolls = 0; p031UiSkips = 0; p031UiBanishes = 0;
        p031UiWhipRank = 1; p031UiPowerRank = 0; p031UiArmorRank = 0;
        p031UiRevision = 0; p031UiDemoStep = 0; p031UiAwaitRevision = -1; p031UiActionId = 1;
        p031UiOpeningLatch = false; p031UiConfirmHeld = false; p031UiLeftHeld = false;
        p031UiRightHeld = false; p031UiSpaceHeld = false; p031UiMouseHeld = false;
        p031UiReleaseSent = false; p031UiAwaitApplied = false; p031UiStaleSent = false; p031UiPhysicalInput = false;
    }

    ui void DSP031UiReadMode()
    {
        CVar mode = CVar.FindCVar("ds_p031_mode");
        String value = mode != null ? mode.GetString() : "manual";
        p031UiDemo = value != "manual";
        p031UiSealDemo = value == "seal_demo";
        p031UiAuditDemo = value == "audit";
        p031UiHoldModal = value == "hold_modal";
        p031UiHoldAfterReroll = value == "hold_after_reroll";
        p031UiModeRead = 1;
    }

    ui int DSP031UiOfferId(int index)
    {
        if (index == 0) return p031UiOffer0;
        if (index == 1) return p031UiOffer1;
        if (index == 2) return p031UiOffer2;
        if (index == 3) return p031UiOffer3;
        return 0;
    }

    ui int DSP031UiOfferRank(int index)
    {
        if (index == 0) return p031UiRank0;
        if (index == 1) return p031UiRank1;
        if (index == 2) return p031UiRank2;
        if (index == 3) return p031UiRank3;
        return 0;
    }

    ui void DSP031UiSetOffer(int index, int id, int rank)
    {
        if (index == 0) { p031UiOffer0 = id; p031UiRank0 = rank; }
        else if (index == 1) { p031UiOffer1 = id; p031UiRank1 = rank; }
        else if (index == 2) { p031UiOffer2 = id; p031UiRank2 = rank; }
        else if (index == 3) { p031UiOffer3 = id; p031UiRank3 = rank; }
    }

    ui String DSP031UiName(int id)
    {
        if (id == DSP028_ID_WHIP) return "WHIP";
        if (id == DSP028_ID_POWER) return "POWER (Spinach)";
        if (id == DSP028_ID_ARMOR) return "ARMOR";
        if (id == DSP031_ID_TEST_FOURTH) return "TEST CANDIDATE";
        if (id == DSP031_ID_FALLBACK_GOLD) return "GOLD (approximation)";
        if (id == DSP031_ID_FALLBACK_CHICKEN) return "FLOOR CHICKEN (approximation)";
        if (id == 0) return "NO ITEM";
        return "UNKNOWN";
    }

    ui String DSP031UiDescription(int id)
    {
        if (id == DSP028_ID_WHIP) return "Automatic Whip rank.";
        if (id == DSP028_ID_POWER) return "Might +10% per rank.";
        if (id == DSP028_ID_ARMOR) return "Armor +1 per rank.";
        if (id == DSP031_ID_TEST_FOURTH) return "Test-only fixture.";
        if (id == DSP031_ID_FALLBACK_GOLD) return "Approximate gold.";
        if (id == DSP031_ID_FALLBACK_CHICKEN) return "Approximate heal.";
        return "Unavailable.";
    }

    ui bool DSP031UiSealed(int id)
    {
        return id >= 1 && id <= 3 && (p031UiSealMask & (1 << (id - 1))) != 0;
    }

    ui void DSP031UiReceive(String name, int a, int b, int c)
    {
        if (name == "P031_RESET") DSP031UiReset();
        else if (name == "P031_PROFILE")
        {
            p031UiSealMask = a; p031UiSealCapacity = b;
            if (p031UiPhase == 0 && !p031UiDemo) p031UiPhase = 1;
            p031UiRevision++;
        }
        else if (name == "P031_STATE") { p031UiLevel = a; p031UiXp = b; p031UiQueue = c; }
        else if (name == "P031_TARGET") { p031UiTarget = a; p031UiToken = b; p031UiOfferCount = c; }
        else if (name == "P031_OFFER0") DSP031UiSetOffer(0, a, b);
        else if (name == "P031_OFFER1") DSP031UiSetOffer(1, a, b);
        else if (name == "P031_OFFER2") DSP031UiSetOffer(2, a, b);
        else if (name == "P031_OFFER3") DSP031UiSetOffer(3, a, b);
        else if (name == "P031_ACTIONS") { p031UiRerolls = a; p031UiSkips = b; p031UiBanishes = c; }
        else if (name == "P031_ACTION_ID")
        {
            p031UiActionId = p031UiActionId > a ? p031UiActionId : a + 1;
            Console.Printf("DS_P031_UI_ACTION_SYNC last_action_id=%d next_action_id=%d", a, p031UiActionId);
        }
        else if (name == "P031_RANKS") { p031UiWhipRank = a; p031UiPowerRank = b; p031UiArmorRank = c; }
        else if (name == "P031_OPEN")
        {
            p031UiPhase = 2; p031UiTarget = a; p031UiQueue = b; p031UiToken = c;
            p031UiSelected = 0; p031UiHover = -1; p031UiOpeningLatch = true;
            p031UiReleaseSent = false; p031UiRevision++;
            Console.Printf("DS_P031_UI_OPEN target_level=%d queue_count=%d token=%d offers=%d", a, b, c, p031UiOfferCount);
        }
        else if (name == "P031_RUN_STARTED")
        {
            p031UiPhase = 0; p031UiSelected = 0;
            Console.Printf("DS_P031_UI_RUN_STARTED profile_seal_mask=%d capacity=%d", p031UiSealMask, p031UiSealCapacity);
        }
        else if (name == "P031_PROFILE_REFRESH")
        {
            p031UiSealMask = a; p031UiSealCapacity = b; p031UiRevision++;
        }
        else if (name == "P031_REFRESH")
        {
            p031UiRevision++;
            p031UiOfferCount = c;
            if (p031UiSelected >= p031UiOfferCount) p031UiSelected = p031UiOfferCount > 0 ? p031UiOfferCount - 1 : 0;
            Console.Printf("DS_P031_UI_REFRESH token=%d action=%d offers=%d", a, b, c);
        }
        else if (name == "P031_APPLIED")
        {
            p031UiPhase = 3; p031UiToken = c; p031UiReleaseSent = false;
            p031UiAwaitApplied = false;
            Console.Printf("DS_P031_UI_APPLIED item=%s queue=%d token=%d", DSP031UiName(a), b, c);
        }
        else if (name == "P031_NEUTRAL_ACK")
        {
            p031UiPhase = 0; p031UiReleaseSent = false;
        }
        else if (name == "P031_COMPLETE")
        {
            p031UiPhase = 0;
        }
    }

    ui bool DSP031UiIsLeft(int key)
    {
        return key == UiEvent.Key_Left || key == InputEvent.Key_LeftArrow
            || key == InputEvent.Key_Pad_DPad_Left || key == InputEvent.Key_Pad_LThumb_Left
            || key == 65 || key == 97;
    }

    ui bool DSP031UiIsRight(int key)
    {
        return key == UiEvent.Key_Right || key == InputEvent.Key_RightArrow
            || key == InputEvent.Key_Pad_DPad_Right || key == InputEvent.Key_Pad_LThumb_Right
            || key == 68 || key == 100;
    }

    ui bool DSP031UiIsConfirm(int key)
    {
        return key == UiEvent.Key_Return || key == InputEvent.Key_Enter
            || key == InputEvent.Key_Pad_A || key == InputEvent.Key_Joy1;
    }

    ui bool DSP031UiIsEscape(int key)
    {
        return key == UiEvent.Key_Escape || key == InputEvent.Key_Escape
            || key == InputEvent.Key_Pad_B || key == InputEvent.Key_Joy2;
    }

    ui void DSP031UiMove(int delta, String source)
    {
        int count = p031UiPhase == 1 ? 3 : p031UiOfferCount;
        if (count <= 0) return;
        p031UiSelected = (p031UiSelected + delta + count) % count;
        p031UiPhysicalInput = true;
        Console.Printf("DS_P031_FOCUS source=%s selected=%d id=%s", source, p031UiSelected,
            DSP031UiName(p031UiPhase == 1 ? p031UiSelected + 1 : DSP031UiOfferId(p031UiSelected)));
    }

    ui void DSP031UiToggleSeal(String source)
    {
        int id = p031UiSelected + 1;
        bool sealing = !DSP031UiSealed(id);
        if (p031UiSealCapacity <= 0)
        {
            Console.Printf("DS_P031_SEAL_INPUT accepted=0 source=%s item=%s reason=NO_UNLOCKED_CAPACITY", source, DSP031UiName(id));
            return;
        }
        p031UiPhysicalInput = source == "PHYSICAL" ? true : p031UiPhysicalInput;
        Console.Printf("DS_P031_SEAL_INPUT source=%s item=%s sealed=%d intent=NETWORK_EVENT", source, DSP031UiName(id), sealing);
        SendNetworkEvent("P031_SEAL", id, sealing ? 1 : 0);
    }

    ui void DSP031UiStartRun(String source)
    {
        p031UiPhase = 0;
        if (source == "PHYSICAL") p031UiPhysicalInput = true;
        Console.Printf("DS_P031_PROFILE_START source=%s seal_mask=%d capacity=%d", source, p031UiSealMask, p031UiSealCapacity);
        SendNetworkEvent("P031_START");
    }

    ui void DSP031UiChoose(String source)
    {
        if (p031UiPhase != 2 || p031UiOfferCount <= 0) return;
        int id = DSP031UiOfferId(p031UiSelected);
        if (id == 0 || p031UiSelected >= p031UiOfferCount) return;
        if (source == "PHYSICAL") p031UiPhysicalInput = true;
        Console.Printf("DS_P031_INPUT source=%s action=APPLY offer=%d item=%s token=%d", source, p031UiSelected, DSP031UiName(id), p031UiToken);
        p031UiPhase = 3;
        p031UiReleaseSent = false;
        p031UiAwaitApplied = true;
        SendNetworkEvent("P031_APPLY", p031UiToken, id);
    }

    ui void DSP031UiAction(int kind, String source)
    {
        if (p031UiPhase != 2) return;
        if (source == "PHYSICAL") p031UiPhysicalInput = true;
        if (kind == 1)
        {
            if (p031UiRerolls <= 0) { Console.Printf("DS_P031_INPUT_REJECT action=REROLL reason=NO_CHARGE"); return; }
            Console.Printf("DS_P031_INPUT source=%s action=REROLL token=%d", source, p031UiToken);
            SendNetworkEvent("P031_REROLL", p031UiToken, p031UiActionId++);
        }
        else if (kind == 2)
        {
            if (p031UiSkips <= 0) { Console.Printf("DS_P031_INPUT_REJECT action=SKIP reason=NO_CHARGE"); return; }
            Console.Printf("DS_P031_INPUT source=%s action=SKIP token=%d", source, p031UiToken);
            p031UiPhase = 3; p031UiReleaseSent = false; p031UiAwaitApplied = true;
            SendNetworkEvent("P031_SKIP", p031UiToken, p031UiActionId++);
        }
        else if (kind == 3)
        {
            int id = DSP031UiOfferId(p031UiSelected);
            if (p031UiBanishes <= 0 || id <= 0 || id > DSP031_ID_TEST_FOURTH)
            {
                Console.Printf("DS_P031_INPUT_REJECT action=BANISH reason=NO_CHARGE_OR_NO_LEGAL_SELECTION");
                return;
            }
            Console.Printf("DS_P031_INPUT source=%s action=BANISH token=%d item=%s", source, p031UiToken, DSP031UiName(id));
            SendNetworkEvent("P031_BANISH", p031UiToken, id, p031UiActionId++);
        }
    }

    ui int DSP031UiMouseOffer(int mouseX, int mouseY)
    {
        int vx = int(double(mouseX) * DSP031_UI_WIDTH / double(Screen.GetWidth()));
        int vy = int(double(mouseY) * DSP031_UI_HEIGHT / double(Screen.GetHeight()));
        if (vy < 138 || vy >= 280 || vx < 16 || vx >= 624) return -1;
        int count = p031UiPhase == 1 ? 3 : p031UiOfferCount;
        if (count <= 0) return -1;
        int cardW = count == 4 ? 143 : count == 3 ? 186 : 280;
        int gap = count == 4 ? 8 : count == 3 ? 12 : 16;
        int left = (DSP031_UI_WIDTH - (count * cardW + (count - 1) * gap)) / 2;
        int index = (vx - left) / (cardW + gap);
        if (index < 0 || index >= count) return -1;
        int within = (vx - left) % (cardW + gap);
        return within < cardW ? index : -1;
    }

    ui int DSP031UiMouseButton(int mouseX, int mouseY)
    {
        int vx = int(double(mouseX) * DSP031_UI_WIDTH / double(Screen.GetWidth()));
        int vy = int(double(mouseY) * DSP031_UI_HEIGHT / double(Screen.GetHeight()));
        if (vy < 300 || vy >= 354) return -1;
        int button = vx / 160;
        return button >= 0 && button < 4 ? button : -1;
    }

    override bool UiProcess(UiEvent e)
    {
        if (p031UiPhase < 1 || p031UiPhase > 3) return false;
        if (e.Type == UiEvent.Type_KeyUp)
        {
            int key = e.KeyChar;
            if (DSP031UiIsConfirm(key)) { p031UiConfirmHeld = false; p031UiSpaceHeld = false; return true; }
            if (DSP031UiIsLeft(key)) { p031UiLeftHeld = false; return true; }
            if (DSP031UiIsRight(key)) { p031UiRightHeld = false; return true; }
            return true;
        }
        if (e.Type == UiEvent.Type_KeyDown)
        {
            int key = e.KeyChar;
            bool confirm = DSP031UiIsConfirm(key);
            if (DSP031UiIsEscape(key))
            {
                p031UiPhysicalInput = true;
                Console.Printf("DS_P031_ESCAPE accepted=0 reason=NO_SILENT_SELECTION phase=%d", p031UiPhase);
                return true;
            }
            if (DSP031UiIsLeft(key))
            {
                p031UiPhysicalInput = true;
                if (!p031UiLeftHeld && !p031UiOpeningLatch) DSP031UiMove(-1, "PHYSICAL_KEY");
                p031UiLeftHeld = true;
                return true;
            }
            if (DSP031UiIsRight(key))
            {
                p031UiPhysicalInput = true;
                if (!p031UiRightHeld && !p031UiOpeningLatch) DSP031UiMove(1, "PHYSICAL_KEY");
                p031UiRightHeld = true;
                return true;
            }
            if (confirm)
            {
                p031UiPhysicalInput = true;
                if (p031UiConfirmHeld || p031UiOpeningLatch)
                {
                    Console.Printf("DS_P031_CONFIRM_REJECT reason=%s", p031UiOpeningLatch ? "OPEN_HELD_LATCH" : "HELD_CONFIRM");
                    return true;
                }
                p031UiConfirmHeld = true;
                if (p031UiPhase == 1) DSP031UiStartRun("PHYSICAL");
                else if (p031UiPhase == 2) DSP031UiChoose("PHYSICAL");
                return true;
            }
            if (key == 32)
            {
                p031UiPhysicalInput = true;
                if (!p031UiSpaceHeld && !p031UiOpeningLatch)
                {
                    if (p031UiPhase == 1) DSP031UiToggleSeal("PHYSICAL");
                    else if (p031UiPhase == 2) DSP031UiChoose("PHYSICAL");
                }
                p031UiSpaceHeld = true;
                return true;
            }
            if (p031UiPhase == 1 && (key == 84 || key == 116)) { DSP031UiToggleSeal("PHYSICAL"); return true; }
            if (p031UiPhase == 2)
            {
                if (key == 82 || key == 114) { DSP031UiAction(1, "PHYSICAL"); return true; }
                if (key == 75 || key == 107) { DSP031UiAction(2, "PHYSICAL"); return true; }
                if (key == 66 || key == 98) { DSP031UiAction(3, "PHYSICAL"); return true; }
            }
            return true;
        }
        if (e.Type == UiEvent.Type_MouseMove)
        {
            int next = DSP031UiMouseOffer(e.MouseX, e.MouseY);
            if (next >= 0 && next != p031UiHover)
            {
                p031UiHover = next; p031UiSelected = next; p031UiPhysicalInput = true;
                Console.Printf("DS_P031_FOCUS source=PHYSICAL_MOUSE selected=%d", next);
            }
            return true;
        }
        if (e.Type == UiEvent.Type_LButtonUp) { p031UiMouseHeld = false; return true; }
        if (e.Type == UiEvent.Type_LButtonDown || e.Type == UiEvent.Type_LButtonClick)
        {
            if (p031UiMouseHeld) return true;
            p031UiMouseHeld = true; p031UiPhysicalInput = true;
            if (p031UiPhase == 1)
            {
                int option = DSP031UiMouseOffer(e.MouseX, e.MouseY);
                int button = DSP031UiMouseButton(e.MouseX, e.MouseY);
                if (option >= 0) p031UiSelected = option;
                else if (button == 0) DSP031UiToggleSeal("PHYSICAL_MOUSE");
                else if (button == 3) DSP031UiStartRun("PHYSICAL");
            }
            else if (p031UiPhase == 2)
            {
                int option = DSP031UiMouseOffer(e.MouseX, e.MouseY);
                int button = DSP031UiMouseButton(e.MouseX, e.MouseY);
                if (option >= 0) p031UiSelected = option;
                else if (button >= 0) DSP031UiAction(button, "PHYSICAL_MOUSE");
            }
            return true;
        }
        return true;
    }

    ui void DSP031UiDrawText(Font font, int color, int x, int y, String text)
    {
        Screen.DrawText(font, color, x, y, text, DTA_VirtualWidth, DSP031_UI_WIDTH,
            DTA_VirtualHeight, DSP031_UI_HEIGHT, DTA_KeepRatio, true);
    }

    ui void DSP031UiDrawPanel(int x, int y, int w, int h, bool focused, bool selectedState)
    {
        double sx = double(Screen.GetWidth()) / DSP031_UI_WIDTH;
        double sy = double(Screen.GetHeight()) / DSP031_UI_HEIGHT;
        int panelColor = focused ? Color(42, 79, 72) : Color(27, 42, 49);
        if (selectedState) { panelColor = Color(49, 73, 53); }
        Screen.Dim(panelColor, 0.98, int(x * sx), int(y * sy), int(w * sx), int(h * sy));
        Screen.DrawLineFrame(focused ? Color(255, 204, 91) : Color(90, 122, 127),
            int(x * sx), int(y * sy), int(w * sx), int(h * sy), focused ? 3 : 1);
    }

    ui void DSP031UiDrawProfile()
    {
        double sx = double(Screen.GetWidth()) / DSP031_UI_WIDTH;
        double sy = double(Screen.GetHeight()) / DSP031_UI_HEIGHT;
        Screen.Dim(Color(4, 8, 12), 0.82, 0, 0, Screen.GetWidth(), Screen.GetHeight());
        Screen.Dim(Color(18, 31, 38), 0.98, int(22*sx), int(20*sy), int(596*sx), int(360*sy));
        Screen.DrawLineFrame(Color(73, 219, 170), int(22*sx), int(20*sy), int(596*sx), int(360*sy), 2);
        DSP031UiDrawText(ConFont, Font.CR_GOLD, 202, 36, "COLLECTION / SEAL");
        DSP031UiDrawText(SmallFont, Font.CR_WHITE, 45, 70, "Pre-run profile. Sealed items skip level-up.");
        DSP031UiDrawText(SmallFont, Font.CR_GREY, 45, 94, String.Format("Unlocked Seal capacity: %d   Used: %d", p031UiSealCapacity, DSP031UiBitCount(p031UiSealMask)));
        int left = 58;
        for (int i = 0; i < 3; i++)
        {
            bool isSealed = DSP031UiSealed(i + 1);
            DSP031UiDrawPanel(left + i*178, 132, 164, 128, p031UiSelected == i, isSealed);
            DSP031UiDrawText(SmallFont, isSealed ? Font.CR_GOLD : Font.CR_WHITE, left + i*178 + 12, 151, DSP031UiName(i + 1));
            DSP031UiDrawText(SmallFont, isSealed ? Font.CR_GOLD : Font.CR_GREEN, left + i*178 + 12, 183, isSealed ? "SEALED" : "AVAILABLE");
            DSP031UiDrawText(SmallFont, Font.CR_GREY, left + i*178 + 12, 218, i == 0 ? "Weapon" : "Passive");
        }
        DSP031UiDrawButton(0, "TOGGLE SEAL", p031UiSealCapacity > 0);
        DSP031UiDrawButton(3, "START RUN", true);
        DSP031UiDrawText(SmallFont, Font.CR_GREY, 64, 356, "Arrows select   T/Space toggle   Enter start");
    }

    ui int DSP031UiBitCount(int mask)
    {
        int count = 0; for (int i = 0; i < 3; i++) if ((mask & (1 << i)) != 0) count++;
        return count;
    }

    ui void DSP031UiDrawButton(int index, String label, bool enabled)
    {
        double sx = double(Screen.GetWidth()) / DSP031_UI_WIDTH;
        double sy = double(Screen.GetHeight()) / DSP031_UI_HEIGHT;
        int x = 24 + index * 152;
        Screen.Dim(enabled ? Color(31, 65, 59) : Color(42, 44, 45), 0.98,
            int(x*sx), int(294*sy), int(136*sx), int(43*sy));
        Screen.DrawLineFrame(enabled ? Color(73,219,170) : Color(90,94,96),
            int(x*sx), int(294*sy), int(136*sx), int(43*sy), 1);
        DSP031UiDrawText(SmallFont, enabled ? Font.CR_WHITE : Font.CR_GREY, x + 12, 308, label);
    }

    ui void DSP031UiDrawDraft()
    {
        double sx = double(Screen.GetWidth()) / DSP031_UI_WIDTH;
        double sy = double(Screen.GetHeight()) / DSP031_UI_HEIGHT;
        Screen.Dim(Color(4, 8, 12), 0.82, 0, 0, Screen.GetWidth(), Screen.GetHeight());
        Screen.Dim(Color(18, 31, 38), 0.98, int(20*sx), int(18*sy), int(600*sx), int(364*sy));
        Screen.DrawLineFrame(Color(73, 219, 170), int(20*sx), int(18*sy), int(600*sx), int(364*sy), 2);
        DSP031UiDrawText(ConFont, Font.CR_GOLD, 245, 32, "LEVEL UP");
        DSP031UiDrawText(SmallFont, Font.CR_WHITE, 44, 64, String.Format("Level %d  XP %d  Queue %d  Draft %d", p031UiLevel, p031UiXp, p031UiQueue, p031UiTarget));
        DSP031UiDrawText(SmallFont, Font.CR_GREEN, 44, 87, "Playable subset only. Weights provisional.");
        int count = p031UiOfferCount;
        int cardW = count == 4 ? 143 : count == 3 ? 186 : 280;
        int gap = count == 4 ? 8 : count == 3 ? 12 : 16;
        int left = (DSP031_UI_WIDTH - (count * cardW + (count - 1) * gap)) / 2;
        for (int i = 0; i < 4; i++)
        {
            if (i >= count) continue;
            int x = left + i * (cardW + gap);
            bool focused = p031UiSelected == i;
            DSP031UiDrawPanel(x, 124, cardW, 154, focused, false);
            DSP031UiDrawText(SmallFont, focused ? Font.CR_GOLD : Font.CR_WHITE, x + 9, 141, String.Format("%d  %s", i + 1, DSP031UiName(DSP031UiOfferId(i))));
            DSP031UiDrawText(SmallFont, Font.CR_GREEN, x + 9, 173, DSP031UiOfferRank(i) > 0 ? String.Format("Rank %d", DSP031UiOfferRank(i)) : "New item");
            DSP031UiDrawText(SmallFont, Font.CR_GREY, x + 9, 204, DSP031UiDescription(DSP031UiOfferId(i)));
        }
        DSP031UiDrawButton(0, String.Format("REROLL %d", p031UiRerolls), p031UiRerolls > 0);
        DSP031UiDrawButton(1, String.Format("SKIP %d", p031UiSkips), p031UiSkips > 0);
        DSP031UiDrawButton(2, String.Format("BANISH %d", p031UiBanishes), p031UiBanishes > 0);
        DSP031UiDrawButton(3, "CHOOSE", true);
        DSP031UiDrawText(SmallFont, Font.CR_GREY, 38, 359, "Arrows select   Enter choose   R reroll   K skip   B banish");
    }

    ui void DSP031UiDrawNeutral()
    {
        Screen.Dim(Color(4, 8, 12), 0.55, 0, 0, Screen.GetWidth(), Screen.GetHeight());
        DSP031UiDrawText(ConFont, Font.CR_GOLD, 215, 185, "RELEASE INPUT TO CONTINUE");
    }

    override void RenderOverlay(RenderEvent e)
    {
        if (p031UiPhase == 1) DSP031UiDrawProfile();
        else if (p031UiPhase == 2) DSP031UiDrawDraft();
        else if (p031UiPhase == 3) DSP031UiDrawNeutral();
    }

    ui void DSP031UiDemoSend(String kind)
    {
        if (kind == "START")
        {
            if (p031UiSealDemo && p031UiDemoStep == 0)
            {
                SendNetworkEvent("P031_SEAL", DSP028_ID_WHIP, 1);
                p031UiDemoStep = 1; p031UiAwaitRevision = p031UiRevision + 1;
                Console.Printf("DS_P031_SEAL_INPUT source=ENGINE_TAPE item=WHIP sealed=1 intent=NETWORK_EVENT");
            }
            else DSP031UiStartRun("ENGINE_TAPE");
        }
        else if (kind == "REROLL")
        {
            SendNetworkEvent("P031_REROLL", p031UiToken, p031UiActionId++);
            p031UiDemoStep = 1; p031UiAwaitRevision = p031UiRevision + 1;
            Console.Printf("DS_P031_DEMO_INPUT action=REROLL token=%d", p031UiToken);
        }
        else if (kind == "BANISH")
        {
            int id = DSP031UiOfferId(0);
            SendNetworkEvent("P031_BANISH", p031UiToken, id, p031UiActionId++);
            p031UiDemoStep = 2; p031UiAwaitRevision = p031UiRevision + 1;
            Console.Printf("DS_P031_DEMO_INPUT action=BANISH token=%d item=%s", p031UiToken, DSP031UiName(id));
        }
        else if (kind == "APPLY")
        {
            int id = DSP031UiOfferId(0);
            SendNetworkEvent("P031_APPLY", p031UiToken, id);
            p031UiPhase = 3; p031UiReleaseSent = false; p031UiAwaitApplied = true;
            p031UiDemoStep = 3;
            Console.Printf("DS_P031_DEMO_INPUT action=APPLY token=%d item=%s", p031UiToken, DSP031UiName(id));
        }
        else if (kind == "SKIP")
        {
            SendNetworkEvent("P031_SKIP", p031UiToken, p031UiActionId++);
            p031UiPhase = 3; p031UiReleaseSent = false; p031UiAwaitApplied = true;
            p031UiDemoStep = 4;
            Console.Printf("DS_P031_DEMO_INPUT action=SKIP token=%d", p031UiToken);
        }
    }

    override void UiTick()
    {
        if (!p031UiModeRead) DSP031UiReadMode();
        if (p031UiOpeningLatch)
        {
            if (!p031UiConfirmHeld && !p031UiLeftHeld && !p031UiRightHeld && !p031UiSpaceHeld && !p031UiMouseHeld)
                p031UiOpeningLatch = false;
        }
        if (p031UiDemo && p031UiPhase == 1 && p031UiAwaitRevision < 0)
            DSP031UiDemoSend("START");
        if (p031UiDemo && p031UiAwaitRevision >= 0 && p031UiRevision >= p031UiAwaitRevision)
            p031UiAwaitRevision = -1;
        if (p031UiDemo && !p031UiHoldModal && p031UiPhase == 2 && p031UiAwaitRevision < 0)
        {
            if (p031UiAuditDemo)
            {
                DSP031UiChoose("ENGINE_TAPE");
            }
            else if (p031UiSealDemo)
            {
                DSP031UiChoose("ENGINE_TAPE");
            }
            else if (p031UiHoldAfterReroll && p031UiActionId > 1)
            {
                // Hold the restored draft after one accepted reroll so the
                // action counter survives an actual engine save/load.
            }
            else if (p031UiToken == 0 && p031UiDemoStep == 0) DSP031UiDemoSend("REROLL");
            else if (p031UiToken == 0 && p031UiDemoStep == 1 && !p031UiStaleSent)
            {
                // A stale token must reject without burning the next action ID.
                p031UiStaleSent = true;
                SendNetworkEvent("P031_REROLL", p031UiToken + 77, p031UiActionId);
                p031UiAwaitRevision = p031UiRevision + 1;
                Console.Printf("DS_P031_DEMO_INPUT action=STALE_REROLL token=%d action_id=%d", p031UiToken + 77, p031UiActionId);
            }
            else if (p031UiToken == 0 && p031UiDemoStep == 1 && p031UiStaleSent) DSP031UiDemoSend("BANISH");
            else if (p031UiToken == 0 && p031UiDemoStep == 2) DSP031UiDemoSend("APPLY");
            else if (p031UiToken == 1 && p031UiDemoStep == 3) DSP031UiDemoSend("SKIP");
            else if (!p031UiSealDemo && !p031UiAuditDemo) DSP031UiChoose("ENGINE_TAPE");
        }
        if (p031UiPhase == 3 && !p031UiAwaitApplied && !p031UiReleaseSent
            && !p031UiConfirmHeld && !p031UiLeftHeld && !p031UiRightHeld
            && !p031UiSpaceHeld && !p031UiMouseHeld)
        {
            p031UiReleaseSent = true;
            SendNetworkEvent("P031_NEUTRAL", p031UiToken);
        }
    }
}
