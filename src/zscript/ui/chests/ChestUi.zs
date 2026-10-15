// P032 chest-choice panel. UI submits intent only; chest and inventory
// authorities validate every transaction on NetworkProcess.
class DSP032ChestUiRuntime : EventHandler
{
    const DSP032_UI_WIDTH = 640;
    const DSP032_UI_HEIGHT = 400;

    bool enabled;
    ui bool modalOpen;
    ui bool openingLatch;
    ui bool confirmHeld;
    ui bool confirmSent;
    ui bool demoMode;
    ui int chestId;
    ui int chestSubtype;
    ui int slotCount;
    ui int slotProgress;
    ui int recipeId;
    ui int fixtureMode;
    ui int inventoryHash;
    ui int queueCount;
    ui int uiTicks;

    override void OnRegister()
    {
        IsUiProcessor = false;
        RequireMouse = true;
    }

    ui bool IsConfirmKey(int key)
    {
        return key == 13 || key == 28 || key == 32 || key == 156;
    }

    ui void SendConfirm(String source)
    {
        if (!modalOpen || confirmSent || openingLatch) return;
        confirmSent = true;
        Console.Printf("DS_P032_UI_INTENT action=CONFIRM source=%s chest=%d slot=%d recipe=%d", source, chestId, slotProgress, recipeId);
        SendNetworkEvent("P032_UI_CONFIRM", chestId, slotProgress, recipeId);
    }

    override void NetworkProcess(ConsoleEvent e)
    {
        if (!enabled || e.Player != consoleplayer) return;
        if (e.Name == "P032_UI_PAUSE")
        {
            IsUiProcessor = true;
            SendInterfaceEvent(consoleplayer, "P032_UI_OPEN", e.Args[0], e.Args[1], e.Args[2]);
            CVar mode = CVar.FindCVar("ds_p032_mode");
            if (mode != null && mode.GetString() == "evolution")
                SendInterfaceEvent(consoleplayer, "P032_UI_MODE", 1, 1, 0);
        }
        else if (e.Name == "P032_UI_SET_MODE")
        {
            SendInterfaceEvent(consoleplayer, "P032_UI_MODE", e.Args[0], e.Args[1], e.Args[2]);
        }
        else if (e.Name == "P032_UI_RESUME")
        {
            IsUiProcessor = false;
            SendInterfaceEvent(consoleplayer, "P032_UI_CLOSE", e.Args[0], e.Args[1], 0);
        }
    }

    override void InterfaceProcess(ConsoleEvent e)
    {
        if (!enabled || e.Name.IndexOf("P032_UI_") != 0) return;
        if (e.Name == "P032_UI_RESET")
        {
            modalOpen = false; openingLatch = false; confirmHeld = false;
            confirmSent = false; chestId = 0; chestSubtype = 0; slotCount = 0;
            slotProgress = 0; recipeId = 0; fixtureMode = 0; inventoryHash = 0;
            queueCount = 0; uiTicks = 0;
        }
        else if (e.Name == "P032_UI_OPEN")
        {
            chestId = e.Args[0]; chestSubtype = e.Args[1]; slotCount = e.Args[2];
            slotProgress = 0; modalOpen = true; openingLatch = true;
            confirmHeld = false; confirmSent = false; uiTicks = 0;
            Console.Printf("DS_P032_UI_OPEN chest=%d subtype=%s slots=%d", chestId, chestSubtype == 2 ? "SILVER" : "BRONZE", slotCount);
        }
        else if (e.Name == "P032_UI_MODE")
        {
            recipeId = e.Args[0]; fixtureMode = e.Args[1];
        }
        else if (e.Name == "P032_UI_STATE")
        {
            slotProgress = e.Args[0]; inventoryHash = e.Args[1]; queueCount = e.Args[2];
            confirmSent = false;
        }
        else if (e.Name == "P032_UI_CLOSE")
        {
            modalOpen = false; openingLatch = false; confirmHeld = false;
            confirmSent = false;
            Console.Printf("DS_P032_UI_CLOSE chest=%d committed=%d", e.Args[0], e.Args[1]);
        }
    }

    override bool InputProcess(InputEvent e)
    {
        if (!enabled || !modalOpen) return false;
        if (e.Type != InputEvent.Type_KeyDown && e.Type != InputEvent.Type_KeyUp) return true;
        int key = e.KeyScan;
        if (!IsConfirmKey(key)) return true;
        if (e.Type == InputEvent.Type_KeyUp)
        {
            confirmHeld = false;
            return true;
        }
        if (confirmHeld || openingLatch || confirmSent)
        {
            Console.Printf("DS_P032_UI_INTENT_REJECT reason=%s chest=%d slot=%d", openingLatch ? "OPEN_HELD_LATCH" : "HELD_OR_PENDING_CONFIRM", chestId, slotProgress);
            return true;
        }
        confirmHeld = true;
        SendConfirm("PHYSICAL_KEY");
        return true;
    }

    ui void DrawLabel(Font font, int color, int x, int y, String text)
    {
        Screen.DrawText(font, color, x, y, text, DTA_VirtualWidth, DSP032_UI_WIDTH,
            DTA_VirtualHeight, DSP032_UI_HEIGHT, DTA_KeepRatio, true);
    }

    override void RenderOverlay(RenderEvent e)
    {
        if (!enabled || !modalOpen) return;
        int width = Screen.GetWidth();
        int height = Screen.GetHeight();
        double sx = double(width) / DSP032_UI_WIDTH;
        double sy = double(height) / DSP032_UI_HEIGHT;
        Screen.Dim(Color(4, 8, 12), 0.78, 0, 0, width, height);
        Screen.Dim(Color(18, 31, 38), 0.96, int(34 * sx), int(36 * sy), int(572 * sx), int(326 * sy));
        Screen.DrawLineFrame(Color(73, 219, 170), int(34 * sx), int(36 * sy), int(572 * sx), int(326 * sy), 2);
        DrawLabel(ConFont, Font.CR_GOLD, 230, 58, "CHEST REWARD");
        DrawLabel(SmallFont, Font.CR_WHITE, 75, 98, String.Format("Chest %d   %s   Slot %d / %d", chestId, chestSubtype == 2 ? "Silver" : "Bronze", slotProgress + 1, slotCount));
        if (recipeId == 1)
            DrawLabel(SmallFont, Font.CR_GOLD, 75, 143, "Whip 8 + Hollow Heart -> Bloody Tear");
        else
            DrawLabel(SmallFont, Font.CR_WHITE, 75, 143, "Choose the next reward to continue.");
        DrawLabel(SmallFont, Font.CR_GREEN, 75, 177, fixtureMode != 0 ? "Controlled transformation fixture" : "Source eligibility frozen when chest spawned");
        DrawLabel(SmallFont, Font.CR_GREY, 75, 215, String.Format("Queue %d   Inventory state %d", queueCount, inventoryHash));
        DrawLabel(SmallFont, Font.CR_WHITE, 198, 286, "ENTER / SPACE: confirm   Hold repeats are ignored");
    }

    override void UiTick()
    {
        if (!enabled) return;
        if (modalOpen)
        {
            uiTicks++;
            if (openingLatch && uiTicks >= 2) openingLatch = false;
            if (!demoMode)
            {
                CVar mode = CVar.FindCVar("ds_p032_mode");
                String value = mode != null ? mode.GetString() : "manual";
                demoMode = value == "evolution" || value == "slots1" || value == "slots3"
                    || value == "slots5" || value == "bronze_late" || value == "queue"
                    || value == "duplicate_confirm" || value == "hold_after_slot"
                    || value == "save_after_slot" || value == "restore_duplicate_confirm";
            }
            CVar currentMode = CVar.FindCVar("ds_p032_mode");
            bool holdAfterFirst = currentMode != null
                && (currentMode.GetString() == "hold_after_slot"
                    || currentMode.GetString() == "save_after_slot") && slotProgress > 0;
            if (demoMode && !holdAfterFirst && uiTicks >= 8 && !confirmSent)
            {
                SendConfirm("ENGINE_TAPE");
                if (CVar.FindCVar("ds_p032_mode") != null
                    && (CVar.FindCVar("ds_p032_mode").GetString() == "duplicate_confirm"
                        || CVar.FindCVar("ds_p032_mode").GetString() == "restore_duplicate_confirm"))
                {
                    SendNetworkEvent("P032_UI_CONFIRM", chestId, slotProgress, recipeId);
                    Console.Printf("DS_P032_UI_DUPLICATE_INTENT chest=%d slot=%d", chestId, slotProgress);
                }
            }
        }
    }

    override void WorldLoaded(WorldEvent e)
    {
        enabled = level.MapName == "MAP16" || level.MapName == "MAP18";
        IsUiProcessor = false;
        if (enabled) SendInterfaceEvent(consoleplayer, "P032_UI_RESET", 0, 0, 0);
    }
}
