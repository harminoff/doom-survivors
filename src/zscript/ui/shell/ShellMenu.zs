// Game shell: main menu -> character select -> stage select -> run.
//
// MENUDEF binds this class to "MainMenu", so Escape in a run, the results
// screen's "Main Menu" key and the title screen all land here.  Starting a
// run records the choices in ds_character / ds_stage and starts episode 0
// (MAP16, Mad Forest).  Characters come from DSCharacters; ones whose
// starting weapon is not built yet show locked.  PowerUps are bought with
// gold here (DSPowerUps).  Only Mad Forest exists until TODO step 6.

class DSShellMenu : ListMenu
{
    enum EScreen { SCREEN_MAIN, SCREEN_CHARACTER, SCREEN_STAGE, SCREEN_POWERUPS, SCREEN_COLLECTION, SCREEN_BESTIARY, SCREEN_ACHIEVEMENTS, SCREEN_SECRETS }

    int page;
    int cursor;
    int characterIndex;
    int hoverIndex;
    String notice;
    String spellText;   // Secrets page: the spell being typed
    static const String MUSIC_TRACKS[] = { "DSFOREST", "DSLIBRA", "DSDAIRY", "DSGALLO", "DSGOTHC", "DSFIELD", "DSNIGHT", "DSFROST", "DSCOSMC", "DSBATTL", "DSDEPTH", "DSTITLE" };
    // Meta profile snapshot (gameplay/meta/Meta.zs) and the lists built from it.
    Array<String> mKeys;
    Array<int> mVals;
    Array<int> collectionIds;
    Array<int> beastTypes;
    bool collectionArcana;   // Collection page: false = items, true = the 22 Arcana

    override void Init(Menu parent, ListMenuDescriptor desc)
    {
        Super.Init(parent, desc);
        DontDim = true;
        page = SCREEN_MAIN;
        cursor = 0;
        characterIndex = 0;
        hoverIndex = -1;
        if (!InRun()) S_ChangeMusic("DSTITLE");
        MetaRefresh();
        // Test aid: ds_cast_spell casts a Forbidden Scrolls spell when the menu opens.
        CVar castSpell = CVar.FindCVar("ds_cast_spell");
        if (castSpell != null && castSpell.GetString().Length() > 0)
        {
            Console.Printf("DS_SPELL spell=%s result=%s", castSpell.GetString(), DSSecrets.Cast(mKeys, mVals, castSpell.GetString()));
            castSpell.SetString("");
            MetaRefresh();
        }
        CVar startPage = CVar.FindCVar("ds_shell_page");
        if (startPage != null && startPage.GetInt() > 0) page = startPage.GetInt();
        // ds_shell_page 20 (screenshot aid): the Collection page's Arcana view.
        if (page == 20) { page = SCREEN_COLLECTION; collectionArcana = true; }
    }

    void MetaRefresh()
    {
        DSMeta.Load(mKeys, mVals);
        DSN2Catalog.AllIds(collectionIds);
        beastTypes.Clear();
        for (int ty = 1; ty <= DSStage.ENEMY_TYPE_COUNT; ty++)
            if (DSMeta.Val(mKeys, mVals, String.Format("ek:%d", ty)) > 0) beastTypes.Push(ty);
    }

    static bool InRun() { return gamestate == GS_LEVEL; }

    // ---- data --------------------------------------------------------------

    int MainCount() { return InRun() ? 9 : 8; }
    String MainLabel(int index)
    {
        if (InRun())
        {
            if (index == 0) return "Resume";
            index--;
        }
        if (index == 0) return InRun() ? "New Run" : "Start";
        if (index == 1) return "PowerUps";
        if (index == 2) return "Collection";
        if (index == 3) return "Bestiary";
        if (index == 4) return "Achievements";
        if (index == 5) return "Secrets";
        if (index == 6) return "Options";
        return "Quit";
    }
    bool MainEnabled(int index)
    {
        if (MainLabel(index) == "Bestiary") return DSRelics.Owned(mKeys, mVals, DSRelics.GOUDA);   // needs the Ars Gouda
        if (MainLabel(index) == "Secrets") return DSRelics.Owned(mKeys, mVals, DSRelics.SCROLLS);   // needs the Forbidden Scrolls
        return true;
    }

    int CharacterCount() { return DSCharacters.Count(); }
    // Free characters, ones bought, and ones played before prices existed.
    bool CharacterBought(int c)
    {
        return DSCharacters.Price(c) <= 0 || DSUnlocks.All()
            || DSMeta.Val(mKeys, mVals, String.Format("bought:%d", c)) > 0
            || DSMeta.Val(mKeys, mVals, String.Format("chl:%d", c)) > 0;
    }
    const CHAR_ROWS = 6;
    int CharFirstRow()
    {
        int rows = (CharacterCount() + 4) / 5;
        return clamp(cursor / 5 - CHAR_ROWS / 2, 0, max(0, rows - CHAR_ROWS));
    }
    bool CharacterEnabled(int index) { return DSCharacters.Playable(index) && DSUnlocks.CharacterUnlocked(mKeys, mVals, index); }
    String WeaponText(int c)
    {
        String text = DSN2Catalog.DisplayName(DSCharacters.StartingWeapon(c));
        int second = DSCharacters.SecondWeapon(c);
        if (second > 0) text = String.Format("%s + %s", text, DSN2Catalog.DisplayName(second));
        return text;
    }

    // PowerUp items plus a trailing Refund button.
    int PowerUpItemCount() { return DSPowerUps.Count() + 1; }

    int StageCount() { return DSStage.STAGE_COUNT; }
    String StageName(int index) { return DSStage.Name(index); }

    String StageTimeText(int index)
    {
        int seconds = DSStage.DurationTics(index) / 35;
        return String.Format("%d:%02d", seconds / 60, seconds % 60);
    }
    bool StageEnabled(int index) { return DSStage.Has(index) && DSUnlocks.StageUnlocked(mKeys, mVals, index); }

    int ItemCount()
    {
        if (page == SCREEN_CHARACTER) return CharacterCount();
        if (page == SCREEN_STAGE) return StageCount();
        if (page == SCREEN_POWERUPS) return PowerUpItemCount();
        if (page == SCREEN_COLLECTION) return collectionArcana ? 22 : collectionIds.Size();
        if (page == SCREEN_BESTIARY) return max(1, beastTypes.Size());
        if (page == SCREEN_ACHIEVEMENTS) return DSAchievementData.COUNT;
        if (page == SCREEN_SECRETS) return 0;
        return MainCount();
    }
    bool ItemEnabled(int index)
    {
        if (page == SCREEN_CHARACTER) return CharacterEnabled(index);
        if (page == SCREEN_STAGE) return StageEnabled(index);
        if (page == SCREEN_POWERUPS) return true;
        if (page == SCREEN_COLLECTION || page == SCREEN_BESTIARY || page == SCREEN_ACHIEVEMENTS) return false;
        return MainEnabled(index);
    }

    static int ProfileGold() { return DSPowerUps.Gold(); }

    // ---- actions -----------------------------------------------------------

    void Go(int nextScreen)
    {
        page = nextScreen;
        cursor = 0;
        hoverIndex = -1;
        notice = "";
    }

    void Activate(int index)
    {
        if (index < 0 || index >= ItemCount()) return;
        if (!ItemEnabled(index)) { MenuSound("menu/invalid"); return; }
        MenuSound("menu/choose");
        if (page == SCREEN_MAIN)
        {
            String label = MainLabel(index);
            if (label == "Resume") { Close(); return; }
            if (label == "Start" || label == "New Run") { Go(SCREEN_CHARACTER); cursor = characterIndex; return; }
            if (label == "PowerUps") { Go(SCREEN_POWERUPS); return; }
            if (label == "Collection") { MetaRefresh(); collectionArcana = false; Go(SCREEN_COLLECTION); return; }
            if (label == "Bestiary") { MetaRefresh(); Go(SCREEN_BESTIARY); return; }
            if (label == "Achievements") { MetaRefresh(); Go(SCREEN_ACHIEVEMENTS); return; }
            if (label == "Secrets") { MetaRefresh(); Go(SCREEN_SECRETS); spellText = ""; return; }
            if (label == "Options") { Menu.SetMenu('OptionsMenu'); return; }
            if (label == "Quit") { Menu.SetMenu('QuitMenu'); return; }
            return;
        }
        if (page == SCREEN_CHARACTER)
        {
            // Unlocked characters are bought once with gold (the original's prices).
            if (!CharacterBought(index))
            {
                int price = DSCharacters.Price(index);
                if (!DSPowerUps.AddGold(-price))
                {
                    notice = String.Format("%s costs %d gold", DSCharacters.Name(index), price);
                    MenuSound("menu/invalid");
                    return;
                }
                DSMeta.SetVal(mKeys, mVals, String.Format("bought:%d", index), 1);
                DSMeta.Store(mKeys, mVals);
                CVar.SaveConfig();
                notice = String.Format("Bought %s for %d gold", DSCharacters.Name(index), price);
                MenuSound("menu/change");
                return;
            }
            characterIndex = index;
            Go(SCREEN_STAGE);
            return;
        }
        if (page == SCREEN_POWERUPS)
        {
            if (index == DSPowerUps.Count())
            {
                int refunded = DSPowerUps.Refund();
                notice = refunded > 0 ? String.Format("Refunded %d gold", refunded) : "Nothing to refund";
                return;
            }
            if (!DSUnlocks.PowerUpUnlocked(mKeys, mVals, index))
            {
                notice = "Locked: " .. DSUnlocks.PowerUpCondition(mKeys, mVals, index);
                MenuSound("menu/invalid");
                return;
            }
            Array<int> ranks;
            DSPowerUps.Load(ranks);
            if (ranks[index] >= DSPowerUps.MaxRank(index)) { notice = "Already at max rank"; MenuSound("menu/invalid"); return; }
            int price = DSPowerUps.Price(ranks, index);
            if (DSPowerUps.Buy(index)) notice = String.Format("Bought %s for %d gold", DSPowerUps.Name(index), price);
            else { notice = "Not enough gold"; MenuSound("menu/invalid"); }
            return;
        }
        StartRun(index);
    }

    void StartRun(int stageIndex)
    {
        CVar character = CVar.FindCVar("ds_character");
        if (character != null) character.SetString(DSCharacters.Name(characterIndex).MakeLower());
        CVar stage = CVar.FindCVar("ds_stage");
        if (stage != null) stage.SetString(DSStage.Name(stageIndex).MakeLower());
        Console.Printf("DS_SHELL_START character=%s stage=%s", DSCharacters.Name(characterIndex), StageName(stageIndex));
        // Episode N is stage N (ZMAPINFO lists them in DSStage order);
        // skill 0 is the only skill.
        Close();
        Menu.StartGameDirect(false, false, null, stageIndex, 0);
    }

    bool Back()
    {
        if (page == SCREEN_STAGE) { Go(SCREEN_CHARACTER); cursor = characterIndex; MenuSound("menu/backup"); return true; }
        if (page == SCREEN_CHARACTER || page == SCREEN_POWERUPS || page == SCREEN_COLLECTION || page == SCREEN_BESTIARY || page == SCREEN_ACHIEVEMENTS || page == SCREEN_SECRETS) { Go(SCREEN_MAIN); MenuSound("menu/backup"); return true; }
        // The title screen has nothing behind the main menu.
        if (!InRun()) return true;
        Close();
        MenuSound("menu/clear");
        return true;
    }

    // ---- input -------------------------------------------------------------

    int Columns()
    {
        if (page == SCREEN_CHARACTER) return 5;
        if (page == SCREEN_POWERUPS) return 5;
        if (page == SCREEN_STAGE) return 4;
        if (page == SCREEN_COLLECTION) return collectionArcana ? 1 : 17;
        return 1;
    }

    override bool MenuEvent(int mkey, bool fromcontroller)
    {
        int count = ItemCount();
        int cols = Columns();
        bool grid = page == SCREEN_CHARACTER || page == SCREEN_POWERUPS || page == SCREEN_STAGE || (page == SCREEN_COLLECTION && !collectionArcana);
        switch (mkey)
        {
        case MKEY_Up:
            if (cols == 1) cursor = (cursor + count - 1) % count;
            else if (grid && cursor >= cols) cursor -= cols;
            MenuSound("menu/cursor");
            return true;
        case MKEY_Down:
            if (cols == 1) cursor = (cursor + 1) % count;
            else if (grid) cursor = min(cursor + cols, count - 1);
            MenuSound("menu/cursor");
            return true;
        case MKEY_Left:
            if (cols > 1) { cursor = (cursor + count - 1) % count; MenuSound("menu/cursor"); }
            return true;
        case MKEY_Right:
            if (cols > 1) { cursor = (cursor + 1) % count; MenuSound("menu/cursor"); }
            return true;
        case MKEY_Enter:
            Activate(cursor);
            return true;
        case MKEY_Back:
            return Back();
        }
        return Super.MenuEvent(mkey, fromcontroller);
    }

    // On the stage screen, L toggles Limit Break and A toggles Arcana.
    override bool OnUIEvent(UIEvent ev)
    {
        // Secrets page: type a spell, Enter casts it, Backspace deletes.
        if (page == SCREEN_SECRETS && ev.Type == UIEvent.Type_Char)
        {
            if (spellText.Length() < 80 && ev.KeyChar >= 32 && ev.KeyChar < 127 && ev.KeyChar != 32)
                spellText.AppendCharacter(ev.KeyChar);
            return true;
        }
        if (page == SCREEN_SECRETS && ev.Type == UIEvent.Type_KeyDown)
        {
            if (ev.KeyChar == UIEvent.Key_Backspace)
            {
                if (spellText.Length() > 0) spellText.DeleteLastCharacter();
                return true;
            }
            if (ev.KeyChar == UIEvent.Key_Return)
            {
                String done = DSSecrets.Cast(mKeys, mVals, spellText);
                notice = done.Length() > 0 ? "Unlocked: " .. done : "Nothing happens.";
                MenuSound(done.Length() > 0 ? "menu/change" : "menu/invalid");
                spellText = "";
                MetaRefresh();
                return true;
            }
        }
        if (page == SCREEN_MAIN && ev.Type == UIEvent.Type_KeyDown && (ev.KeyChar == 85 || ev.KeyChar == 117))
        {
            CVar all = CVar.FindCVar("ds_unlock_all");
            if (all != null) all.SetInt(all.GetInt() != 0 ? 0 : 1);
            MetaRefresh();
            MenuSound("menu/change");
            return true;
        }
        // Seals (Seal I-IV PowerUps): S seals or unseals the focused item, which
        // then never appears in level-ups.
        if (page == SCREEN_COLLECTION && !collectionArcana && ev.Type == UIEvent.Type_KeyDown
            && (ev.KeyChar == 83 || ev.KeyChar == 115) && collectionIds.Size() > 0)
        {
            int id = collectionIds[clamp(cursor, 0, collectionIds.Size() - 1)];
            String key = String.Format("seal:%d", id);
            bool wasSealed = DSMeta.Val(mKeys, mVals, key) > 0;
            if (!wasSealed && SealsUsed() >= SealCapacity())
            {
                notice = SealCapacity() == 0 ? "Buy Seal PowerUps to seal items" : "No seals left";
                MenuSound("menu/invalid");
                return true;
            }
            DSMeta.SetVal(mKeys, mVals, key, wasSealed ? 0 : 1);
            DSMeta.Store(mKeys, mVals);
            MetaRefresh();
            notice = String.Format("%s %s", DSN2Catalog.DisplayName(id), wasSealed ? "unsealed" : "sealed");
            MenuSound("menu/change");
            return true;
        }
        if (page == SCREEN_COLLECTION && ev.Type == UIEvent.Type_KeyDown && (ev.KeyChar == 65 || ev.KeyChar == 97))
        {
            collectionArcana = !collectionArcana;
            cursor = 0;
            MenuSound("menu/change");
            return true;
        }
        // Mindbender: W on character select cycles the maximum weapons (1-6).
        if (page == SCREEN_CHARACTER && ev.Type == UIEvent.Type_KeyDown && (ev.KeyChar == 87 || ev.KeyChar == 119)
            && DSRelics.Owned(mKeys, mVals, DSRelics.MINDBENDER))
        {
            CVar maxWeapons = CVar.FindCVar("ds_max_weapons");
            if (maxWeapons != null) maxWeapons.SetInt(maxWeapons.GetInt() >= 6 ? 1 : maxWeapons.GetInt() + 1);
            MenuSound("menu/change");
            return true;
        }
        // Magic Banger: B on stage select cycles the music.
        if (page == SCREEN_STAGE && ev.Type == UIEvent.Type_KeyDown && (ev.KeyChar == 66 || ev.KeyChar == 98)
            && DSRelics.Owned(mKeys, mVals, DSRelics.BANGER))
        {
            CVar music = CVar.FindCVar("ds_music");
            if (music != null)
            {
                int at = -1;
                for (int t = 0; t < MUSIC_TRACKS.Size(); t++) if (MUSIC_TRACKS[t] == music.GetString()) at = t;
                music.SetString(at + 1 < MUSIC_TRACKS.Size() ? MUSIC_TRACKS[at + 1] : "");
            }
            MenuSound("menu/change");
            return true;
        }
        if (page == SCREEN_STAGE && ev.Type == UIEvent.Type_KeyDown)
        {
            String cvarName = "";
            if (ev.KeyChar == 76 || ev.KeyChar == 108) cvarName = RelicOption(DSRelics.GOSPEL, "ds_limit_break");
            else if (ev.KeyChar == 65 || ev.KeyChar == 97) cvarName = "ds_arcana";
            else if (ev.KeyChar == 67 || ev.KeyChar == 99) cvarName = "ds_camera";
            else if (ev.KeyChar == 82 || ev.KeyChar == 114) cvarName = RelicOption(DSRelics.MILKY_WAY, "ds_arrows");
            else if (ev.KeyChar == 69 || ev.KeyChar == 101) cvarName = RelicOption(DSRelics.TRUMPET, "ds_endless");
            else if (ev.KeyChar == 72 || ev.KeyChar == 104) cvarName = RelicOption(DSRelics.TEARS, "ds_hurry");
            else if (ev.KeyChar == 86 || ev.KeyChar == 118) cvarName = RelicOption(DSRelics.TRISECTION, "ds_random_events");
            else if (ev.KeyChar == 85 || ev.KeyChar == 117) cvarName = RelicOption(DSRelics.BRAVE_STORY, "ds_random_levelup");
            else if (ev.KeyChar == 84 || ev.KeyChar == 116) cvarName = "ds_aim_assist";
            else if (ev.KeyChar == 77 || ev.KeyChar == 109)
            {
                CVar mode = CVar.FindCVar("ds_mode");
                // Inverse needs Gracia's Mirror.
                int next = mode != null ? (mode.GetInt() + 1) % 3 : 0;
                if (next == 2 && !DSRelics.Owned(mKeys, mVals, DSRelics.MIRROR)) next = 0;
                if (mode != null) mode.SetInt(next);
                MenuSound("menu/change");
                return true;
            }
            if (cvarName.Length() > 0)
            {
                CVar toggle = CVar.FindCVar(cvarName);
                if (toggle != null) toggle.SetInt(toggle.GetInt() != 0 ? 0 : 1);
                MenuSound("menu/change");
                return true;
            }
        }
        return Super.OnUIEvent(ev);
    }

    // A stage option that needs a relic: empty (no toggle) until it is found.
    String RelicOption(int relic, String cvarName)
    {
        return DSRelics.Owned(mKeys, mVals, relic) ? cvarName : "";
    }

    // A relic option's chip text: the option, or which relic it needs.
    String RelicChip(int relic, String key, String label, String cvarName)
    {
        if (!DSRelics.Owned(mKeys, mVals, relic)) return key .. ": " .. label .. " locked";
        return key .. ": " .. label .. (ToggleOn(cvarName) ? " ON" : " OFF");
    }

    bool RelicOn(int relic, String cvarName)
    {
        return DSRelics.Owned(mKeys, mVals, relic) && ToggleOn(cvarName);
    }

    int SealCapacity()
    {
        Array<int> ranks;
        DSPowerUps.Load(ranks);
        return DSPowerUps.SealCapacity(ranks);
    }

    int SealsUsed() { return DSMeta.KeyedTotal(mKeys, mVals, "seal:"); }

    bool ToggleOn(String cvarName)
    {
        CVar toggle = CVar.FindCVar(cvarName);
        return toggle == null || toggle.GetInt() != 0;
    }

    override bool MouseEvent(int type, int mx, int my)
    {
        int hit = HitTest(mx, my);
        if (hit >= 0 && hit != cursor) { cursor = hit; MenuSound("menu/cursor"); }
        if (type == MOUSE_Release && hit >= 0) Activate(hit);
        return true;
    }

    // ---- layout (640x400 virtual, aspect kept) -----------------------------

    const VW = 640;
    const VH = 400;

    static double Scale() { return min(Screen.GetWidth() / double(VW), Screen.GetHeight() / double(VH)); }
    static double OffX() { return (Screen.GetWidth() - VW * Scale()) / 2.0; }
    static double OffY() { return (Screen.GetHeight() - VH * Scale()) / 2.0; }

    static void Box(Color c, double alpha, double x, double y, double w, double h)
    {
        double s = Scale();
        Screen.Dim(c, alpha, int(OffX() + x * s), int(OffY() + y * s), int(w * s), int(h * s));
    }
    static void Frame(Color c, double x, double y, double w, double h, int thickness)
    {
        double s = Scale();
        Screen.DrawLineFrame(Color(255, c.r, c.g, c.b), int(OffX() + x * s), int(OffY() + y * s), int(w * s), int(h * s), thickness);
    }
    // Same mapping as Box: uniform scale, centred, so text and panels line up.
    static void Text(Font f, int colour, double x, double y, String text, double size = 1.0)
    {
        double s = Scale() * size;
        Screen.DrawText(f, colour, OffX() + x * Scale(), OffY() + y * Scale(), text,
            DTA_ScaleX, s, DTA_ScaleY, s);
    }
    // Text shrunk (down to 60%) so it fits within maxWidth virtual units.
    static void FitText(Font f, int colour, double x, double y, String text, double maxWidth, double size = 1.0)
    {
        double width = f.StringWidth(text) * size;
        if (width > maxWidth) size = max(size * 0.6, size * maxWidth / width);
        Text(f, colour, x, y, text, size);
    }
    // Centered like CenterText, but shrunk to fit maxWidth.
    static void FitCenter(Font f, int colour, double y, String text, double maxWidth, double size = 1.0)
    {
        double width = f.StringWidth(text) * size;
        if (width > maxWidth) size = max(size * 0.6, size * maxWidth / width);
        Text(f, colour, (VW - f.StringWidth(text) * size) / 2.0, y, text, size);
    }
    static void CenterText(Font f, int colour, double y, String text, double size = 1.0)
    {
        Text(f, colour, (VW - f.StringWidth(text) * size) / 2.0, y, text, size);
    }

    // Item rectangles, shared by drawing and mouse hit tests.
    void ItemRect(int index, out double x, out double y, out double w, out double h)
    {
        if (page == SCREEN_CHARACTER)
        {
            // Five columns to the right of the portrait bar; six rows show at a
            // time and scroll with the cursor (hidden items get no size).
            int row = index / 5 - CharFirstRow();
            w = 96; h = 46;
            x = 140 + (index % 5) * 100; y = 58 + row * 50;
            if (row < 0 || row >= CHAR_ROWS) { w = 0; h = 0; }
            return;
        }
        if (page == SCREEN_POWERUPS)
        {
            w = 116; h = 44;
            x = 24 + (index % 5) * 120; y = 56 + (index / 5) * 48;
            return;
        }
        if (page == SCREEN_COLLECTION && collectionArcana)
        {
            w = 0; h = 0; x = 0; y = 0;
            return;
        }
        if (page == SCREEN_COLLECTION)
        {
            w = 32; h = 32;
            x = 24 + (index % 17) * 34; y = 58 + (index / 17) * 34;
            return;
        }
        if (page == SCREEN_BESTIARY || page == SCREEN_ACHIEVEMENTS)
        {
            w = 0; h = 0; x = 0; y = 0;
            return;
        }
        if (page == SCREEN_STAGE)
        {
            // Four columns to the right of the preview bar; rows tighten so
            // every stage stays above the option chips (y 326).
            int rows = (StageCount() + 3) / 4;
            int step = min(44, 266 / max(rows, 1));
            w = 120; h = step - 4;
            x = 140 + (index % 4) * 124; y = 56 + (index / 4) * step;
            return;
        }
        // With the title artwork behind the menu the buttons start below the logo.
        bool art = !InRun();
        w = 260; h = art ? 24 : 28;
        x = (VW - w) / 2; y = art ? 168 + index * 26 : 134 + index * 27;
    }

    int HitTest(int mx, int my)
    {
        double s = Scale();
        double vx = (mx - OffX()) / s; double vy = (my - OffY()) / s;
        for (int i = 0; i < ItemCount(); i++)
        {
            double x, y, w, h;
            ItemRect(i, x, y, w, h);
            if (vx >= x && vx < x + w && vy >= y && vy < y + h) return i;
        }
        return -1;
    }

    // ---- drawing -----------------------------------------------------------

    override void Drawer()
    {
        Screen.Dim(Color(10, 5, 5), InRun() ? 0.80 : 1.0, 0, 0, Screen.GetWidth(), Screen.GetHeight());
        if (page == SCREEN_CHARACTER) DrawCharacters();
        else if (page == SCREEN_STAGE) DrawStages();
        else if (page == SCREEN_POWERUPS) DrawPowerUps();
        else if (page == SCREEN_COLLECTION) DrawCollection();
        else if (page == SCREEN_BESTIARY) DrawBestiary();
        else if (page == SCREEN_ACHIEVEMENTS) DrawAchievements();
        else if (page == SCREEN_SECRETS) DrawSecrets();
        else DrawMain();
    }

    void DrawButton(int index, String label, bool enabled)
    {
        double x, y, w, h;
        ItemRect(index, x, y, w, h);
        bool focused = index == cursor;
        DSUi.Button(x, y, w, h, !enabled ? DSUi.BTN_OFF : focused ? DSUi.BTN_FOCUS : DSUi.BTN_NORMAL);
        int colour = !enabled ? Font.CR_DARKGRAY : focused ? Font.CR_GOLD : Font.CR_WHITE;
        double size = 0.8;
        Text(BigFont, colour, x + (w - BigFont.StringWidth(label) * size) / 2, y + (h - BigFont.GetHeight() * size) / 2 + 1, label, size);
    }

    void DrawMain()
    {
        TextureID bg = TexMan.CheckForTexture("DSMENUBG", TexMan.Type_Any);
        if (bg.IsValid() && !InRun())
        {
            double s = Scale();
            Screen.DrawTexture(bg, false, OffX(), OffY(), DTA_DestWidth, int(VW * s), DTA_DestHeight, int(VH * s));
        }
        else CenterText(BigFont, Font.CR_RED, 60, "DOOM SURVIVORS", 2.0);
        for (int i = 0; i < MainCount(); i++)
        {
            String label = MainLabel(i);
            DrawButton(i, label, MainEnabled(i));
        }
        DSUi.Pic("DSICGLD", 16, 372, 16, 16);
        Text(SmallFont, Font.CR_GOLD, 36, 375, String.Format("%d", ProfileGold()), 1.5);
        CVar unlockCvar = CVar.FindCVar("ds_unlock_all");
        String unlockHint = unlockCvar != null && unlockCvar.GetInt() != 0 ? "U: Unlock all ON" : "U: Unlock all OFF";
        Text(SmallFont, Font.CR_DARKGRAY, 16, 356, unlockHint);
        DSUi.Hints(380, "Arrows|Select;Enter|Confirm", 520);
    }

    void DrawCharacters()
    {
        DSUi.Header(18, "CHARACTER SELECTION", Font.CR_GOLD, 1.1, 200);
        for (int i = 0; i < CharacterCount(); i++)
        {
            double x, y, w, h;
            ItemRect(i, x, y, w, h);
            if (w <= 0) continue;
            bool enabled = CharacterEnabled(i);
            bool focused = i == cursor;
            // Locked characters show a dim button (the left bar says how to unlock).
            DSUi.Button(x, y, w, h, focused ? DSUi.BTN_FOCUS : (enabled ? DSUi.BTN_NORMAL : DSUi.BTN_OFF));
            FitText(SmallFont, enabled ? (focused ? Font.CR_GOLD : Font.CR_WHITE) : Font.CR_DARKGRAY, x + 6, y + 7, DSCharacters.Name(i), w - 38);
            DrawIcon(DSCharacters.StartingWeapon(i), x + w - 28, y + 5, 22, enabled);
            String under = !enabled ? "Locked" : (CharacterBought(i) ? DSN2Catalog.DisplayName(DSCharacters.StartingWeapon(i))
                : String.Format("%d gold", DSCharacters.Price(i)));
            FitText(SmallFont, enabled ? (CharacterBought(i) ? Font.CR_CYAN : Font.CR_GOLD) : Font.CR_DARKGRAY, x + 6, y + 27, under, w - 12);
        }
        // Left bar: portrait and details of the focused character.
        int c = cursor;
        bool open = CharacterEnabled(c);
        DSUi.Panel(16, 58, 118, 314);
        TextureID portrait = TexMan.CheckForTexture(String.Format("CHP%02d", c), TexMan.Type_Any);
        double sc = Scale();
        if (portrait.IsValid())
        {
            Screen.DrawTexture(portrait, false, OffX() + 38 * sc, OffY() + 64 * sc, DTA_DestWidth, int(80 * sc), DTA_DestHeight, int(97 * sc),
                DTA_Desaturate, open ? 0 : 255);
        }
        FitText(SmallFont, Font.CR_GOLD, 30, 166, DSCharacters.Name(c), 96, 1.3);
        if (DSRelics.Owned(mKeys, mVals, DSRelics.MINDBENDER))
        {
            CVar maxWeapons = CVar.FindCVar("ds_max_weapons");
            FitText(SmallFont, Font.CR_GOLD, 30, 352, String.Format("W: Max weapons %d", maxWeapons != null ? clamp(maxWeapons.GetInt(), 1, 6) : 6), 96);
        }
        FitText(SmallFont, Font.CR_WHITE, 30, 182, String.Format("Max Health %d", DSCharacters.MaxHealth(c)), 92);
        DrawIcon(DSCharacters.StartingWeapon(c), 30, 196, 18, open);
        FitText(SmallFont, Font.CR_CYAN, 52, 200, DSN2Catalog.DisplayName(DSCharacters.StartingWeapon(c)), 76);
        BrokenLines bonus = SmallFont.BreakLines(DSCharacters.Blurb(c), 96);
        for (int l = 0; l < bonus.Count() && l < 5; l++)
            Text(SmallFont, Font.CR_GREEN, 30, 220 + l * 12, bonus.StringAt(l));
        if (!open)
        {
            if (!DSCharacters.Playable(c)) Text(SmallFont, Font.CR_DARKGRAY, 30, 300, "Weapon not built yet");
            else
            {
                BrokenLines cond = SmallFont.BreakLines("Locked: " .. DSUnlocks.CharacterCondition(mKeys, mVals, c), 96);
                for (int l = 0; l < cond.Count() && l < 6; l++)
                    Text(SmallFont, Font.CR_ORANGE, 30, 288 + l * 12, cond.StringAt(l));
            }
        }
        if (notice.Length() > 0) Text(SmallFont, Font.CR_GREEN, 140, 370, notice);
        DSUi.Hints(384, String.Format("Arrows|Browse (%d / %d);Enter|%s;Esc|Back", cursor + 1, CharacterCount(),
            CharacterEnabled(cursor) && !CharacterBought(cursor) ? "Buy" : "Choose"));
    }

    void DrawPowerUps()
    {
        DSUi.Header(14, "POWERUPS", Font.CR_GOLD, 1.1, 200);
        String goldText = String.Format("%d", ProfileGold());
        Text(SmallFont, Font.CR_GOLD, VW - 24 - SmallFont.StringWidth(goldText) * 1.4, 20, goldText, 1.4);
        DSUi.Pic("DSICGLD", VW - 44 - SmallFont.StringWidth(goldText) * 1.4, 17, 16, 16);
        Array<int> ranks;
        DSPowerUps.Load(ranks);
        for (int i = 0; i < PowerUpItemCount(); i++)
        {
            double x, y, w, h;
            ItemRect(i, x, y, w, h);
            bool focused = i == cursor;
            DSUi.Button(x, y, w, h, focused ? DSUi.BTN_FOCUS : DSUi.BTN_NORMAL);
            if (i == DSPowerUps.Count())
            {
                Text(SmallFont, focused ? Font.CR_GOLD : Font.CR_WHITE, x + 8, y + 14, "Refund all", 1.3);
                continue;
            }
            bool maxed = ranks[i] >= DSPowerUps.MaxRank(i);
            bool locked = !DSUnlocks.PowerUpUnlocked(mKeys, mVals, i);
            Text(SmallFont, locked ? Font.CR_DARKGRAY : (focused ? Font.CR_GOLD : Font.CR_WHITE), x + 8, y + 6, DSPowerUps.Name(i), 1.2);
            // Rank pips.
            int pip = DSPowerUps.MaxRank(i) > 5 ? 6 : 12;
            for (int r = 0; r < DSPowerUps.MaxRank(i); r++)
            {
                Box(Color(0, 0, 0), 1.0, x + 8 + r * pip, y + 26, pip - 3, 9);
                Box(r < ranks[i] ? Color(255, 170, 50) : Color(60, 50, 50), 1.0, x + 9 + r * pip, y + 27, pip - 5, 7);
            }
            String price = locked ? "LOCKED" : (maxed ? "MAX" : String.Format("%d", DSPowerUps.Price(ranks, i)));
            Text(SmallFont, locked ? Font.CR_DARKGRAY : (maxed ? Font.CR_GREEN : Font.CR_GOLD), x + w - 8 - SmallFont.StringWidth(price), y + 26, price);
        }
        String detail = cursor < DSPowerUps.Count() ? DSPowerUps.Effect(cursor) : "Return all spent gold";
        if (cursor < DSPowerUps.Count() && !DSUnlocks.PowerUpUnlocked(mKeys, mVals, cursor))
            detail = "Locked: " .. DSUnlocks.PowerUpCondition(mKeys, mVals, cursor);
        Text(SmallFont, Font.CR_WHITE, 24, 358, detail, 1.2);
        if (notice.Length() > 0) Text(SmallFont, Font.CR_GREEN, 24, 374, notice);
        DSUi.Hints(384, "Enter|Buy;Esc|Back", 520);
    }

    void DrawIcon(int id, double x, double y, double size, bool seen)
    {
        TextureID icon = TexMan.CheckForTexture(String.Format("HI%03d", id), TexMan.Type_Any);
        double s = Scale();
        if (seen && icon.IsValid())
            Screen.DrawTexture(icon, false, OffX() + x * s, OffY() + y * s, DTA_DestWidth, int(size * s), DTA_DestHeight, int(size * s));
        else
            Text(SmallFont, Font.CR_DARKGRAY, x + size / 2 - 3, y + size / 2 - 5, "?");
    }

    void DrawArcanaCollection()
    {
        DSUi.Header(14, "COLLECTION - ARCANA", Font.CR_GOLD, 1.1, 200);
        int unlocked = 0;
        for (int n = 1; n <= 22; n++) if (DSUnlocks.ArcanaUnlocked(mKeys, mVals, n)) unlocked++;
        String progress = String.Format("%d / 22 unlocked", unlocked);
        Text(SmallFont, Font.CR_GOLD, VW - 24 - SmallFont.StringWidth(progress) * 1.2, 20, progress, 1.2);
        int rows = 13;
        int start = clamp(cursor - rows / 2, 0, max(0, 22 - rows));
        for (int r = 0; r < rows && start + r < 22; r++)
        {
            int index = start + r;
            int n = index + 1;
            double y = 46 + r * 21;
            bool open = DSUnlocks.ArcanaUnlocked(mKeys, mVals, n);
            bool met = DSMeta.Val(mKeys, mVals, String.Format("arc:%d", n)) > 0;
            bool focused = index == cursor;
            DSUi.Row(24, y, 592, 20, focused, r % 2 == 1);
            Text(SmallFont, open ? Font.CR_PURPLE : Font.CR_DARKGRAY, 32, y + 5, DSArcana.NUMERALS[n], 1.1);
            Text(SmallFont, open ? Font.CR_WHITE : Font.CR_DARKGRAY, 86, y + 5, open ? DSArcana.Name(n) : "???", 1.1);
            String state = !open ? "Locked" : (met ? "Chosen before" : "Unlocked");
            Text(SmallFont, !open ? Font.CR_DARKGRAY : (met ? Font.CR_GREEN : Font.CR_GOLD), 604 - SmallFont.StringWidth(state) * 1.0, y + 5, state, 1.0);
        }
        int c = clamp(cursor, 0, 21) + 1;
        bool openC = DSUnlocks.ArcanaUnlocked(mKeys, mVals, c);
        DSUi.Panel(24, 326, 592, 48);
        Text(SmallFont, openC ? Font.CR_GOLD : Font.CR_DARKGRAY, 36, 332, openC ? DSArcana.Title(c) : DSArcana.NUMERALS[c] .. " - ???", 1.4);
        FitText(SmallFont, openC ? Font.CR_WHITE : Font.CR_ORANGE, 36, 352, openC ? DSArcana.Blurb(c) : "To unlock: " .. DSUnlocks.ArcanaCondition(c), 568);
        DSUi.Hints(384, String.Format("Up/Down|Scroll (%d / 22);A|Items;Esc|Back", clamp(cursor, 0, 21) + 1));
    }

    void DrawCollection()
    {
        if (collectionArcana) { DrawArcanaCollection(); return; }
        DSUi.Header(14, "COLLECTION", Font.CR_GOLD, 1.1, 200);
        int seenCount = 0;
        for (int i = 0; i < collectionIds.Size(); i++)
            if (DSMeta.Val(mKeys, mVals, String.Format("seen:%d", collectionIds[i])) > 0) seenCount++;
        String progress = String.Format("%d / %d", seenCount, collectionIds.Size());
        Text(SmallFont, Font.CR_GOLD, VW - 24 - SmallFont.StringWidth(progress) * 1.4, 20, progress, 1.4);
        for (int i = 0; i < collectionIds.Size(); i++)
        {
            double x, y, w, h;
            ItemRect(i, x, y, w, h);
            int id = collectionIds[i];
            bool seen = DSMeta.Val(mKeys, mVals, String.Format("seen:%d", id)) > 0;
            bool focused = i == cursor;
            if (focused) DSUi.Button(x - 1, y - 1, w + 2, h + 2, DSUi.BTN_FOCUS);
            else DSUi.Slot(x, y, w, seen && DSMeta.Val(mKeys, mVals, String.Format("rank:%d", id)) >= DSN2Catalog.MaxRank(id));
            DrawIcon(id, x + 4, y + 4, w - 8, seen);
            if (DSMeta.Val(mKeys, mVals, String.Format("seal:%d", id)) > 0)
                Text(SmallFont, Font.CR_RED, x + w - 10, y + 1, "x", 1.2);
        }
        int c = clamp(cursor, 0, max(0, collectionIds.Size() - 1));
        DSUi.Panel(24, 306, 592, 60);
        if (collectionIds.Size() > 0)
        {
            int id = collectionIds[c];
            bool seen = DSMeta.Val(mKeys, mVals, String.Format("seen:%d", id)) > 0;
            Text(SmallFont, seen ? Font.CR_GOLD : Font.CR_DARKGRAY, 36, 312, seen ? DSN2Catalog.DisplayName(id) : "???", 1.5);
            String kind = DSN2Catalog.Category(id) == DSN2Catalog.CATEGORY_WEAPON ? "Weapon" : "Passive";
            Text(SmallFont, Font.CR_WHITE, 36, 334, seen ? String.Format("%s   best level %d of %d", kind, DSMeta.Val(mKeys, mVals, String.Format("rank:%d", id)), DSN2Catalog.MaxRank(id)) : (DSUnlocks.ItemUnlocked(mKeys, mVals, id) ? "Not found yet" : "Locked: " .. DSUnlocks.ItemCondition(mKeys, mVals, id)));
            // Grim Grimoire: the recipe of a discovered evolution, or what an item helps make.
            if (seen && DSRelics.Owned(mKeys, mVals, DSRelics.GRIMOIRE))
            {
                String recipe = DSRecipeBook.Recipe(id);
                int usedIn = DSRecipeBook.UsedIn(id);
                if (recipe.Length() > 0) FitText(SmallFont, Font.CR_CYAN, 36, 348, "Recipe: " .. recipe, 560);
                else if (usedIn > 0) FitText(SmallFont, Font.CR_CYAN, 36, 348, "Helps make: " .. (DSMeta.Val(mKeys, mVals, String.Format("seen:%d", usedIn)) > 0 ? DSN2Catalog.DisplayName(usedIn) : "???"), 560);
            }
        }
        if (notice.Length() > 0) Text(SmallFont, Font.CR_GREEN, 36, 372, notice);
        DSUi.Hints(384, String.Format("Arrows|Browse;S|Seal (%d / %d);A|Arcana;Esc|Back", SealsUsed(), SealCapacity()));
    }

    void DrawSecrets()
    {
        DSUi.Header(14, "FORBIDDEN SCROLLS", Font.CR_GOLD, 1.1, 220);
        DSUi.Panel(80, 70, 480, 220);
        CenterText(SmallFont, Font.CR_WHITE, 96, "Type a spell and press Enter.", 1.3);
        DSUi.Button(120, 140, 400, 32, DSUi.BTN_FOCUS);
        String shown = spellText .. ((MenuTime() / 15) % 2 == 0 ? "_" : " ");
        FitText(SmallFont, Font.CR_GOLD, 132, 150, shown, 376, 1.4);
        if (notice.Length() > 0) CenterText(SmallFont, Font.CR_GREEN, 196, notice, 1.2);
        CenterText(SmallFont, Font.CR_DARKGRAY, 250, String.Format("Spells cast: %d", DSSecrets.CastCount(mKeys, mVals)), 1.1);
        DSUi.Hints(384, "Type|Spell;Enter|Cast;Esc|Back");
    }

    void DrawAchievements()
    {
        DSUi.Header(14, "ACHIEVEMENTS", Font.CR_GOLD, 1.1, 200);
        String progress = String.Format("%d / %d", DSAchievements.DoneCount(mKeys, mVals), DSAchievementData.COUNT);
        Text(SmallFont, Font.CR_GOLD, VW - 24 - SmallFont.StringWidth(progress) * 1.4, 20, progress, 1.4);
        int rows = 15;
        int start = clamp(cursor - rows / 2, 0, max(0, DSAchievementData.COUNT - rows));
        for (int r = 0; r < rows && start + r < DSAchievementData.COUNT; r++)
        {
            int index = start + r;
            double y = 50 + r * 21;
            bool done = DSAchievements.Done(mKeys, mVals, index);
            bool focused = index == cursor;
            DSUi.Row(24, y, 592, 20, focused, r % 2 == 1);
            Text(SmallFont, done ? Font.CR_GOLD : Font.CR_DARKGRAY, 32, y + 5, done ? "[x]" : "[ ]", 1.1);
            Text(SmallFont, done ? Font.CR_WHITE : Font.CR_GREY, 66, y + 5, DSAchievements.Name(index), 1.1);
            String goal = DSAchievements.Goal(index);
            Text(SmallFont, done ? Font.CR_GREEN : Font.CR_DARKGRAY, 604 - SmallFont.StringWidth(goal) * 1.0, y + 5, goal, 1.0);
        }
        DSUi.Hints(384, String.Format("Up/Down|Scroll (%d / %d);Esc|Back", cursor + 1, DSAchievementData.COUNT));
    }

    void DrawBestiary()
    {
        DSUi.Header(14, "BESTIARY", Font.CR_GOLD, 1.1, 200);
        String progress = String.Format("%d / %d found", beastTypes.Size(), DSStage.ENEMY_TYPE_COUNT);
        Text(SmallFont, Font.CR_GOLD, VW - 24 - SmallFont.StringWidth(progress) * 1.4, 20, progress, 1.4);
        Text(SmallFont, Font.CR_GREY, 24, 46, String.Format("Runs %d   Kills %d   Gold earned %d", DSMeta.Val(mKeys, mVals, "runs"), DSMeta.Val(mKeys, mVals, "kills"), DSMeta.Val(mKeys, mVals, "gold")), 1.2);
        if (beastTypes.Size() == 0) CenterText(SmallFont, Font.CR_DARKGRAY, 180, "Defeat enemies to fill the bestiary.", 1.3);
        int rows = 15;
        int start = clamp(cursor - rows / 2, 0, max(0, beastTypes.Size() - rows));
        for (int r = 0; r < rows && start + r < beastTypes.Size(); r++)
        {
            int index = start + r;
            int ty = beastTypes[index];
            double y = 66 + r * 19;
            bool focused = index == cursor;
            DSUi.Row(24, y, 592, 18, focused, r % 2 == 1);
            Text(SmallFont, focused ? Font.CR_GOLD : Font.CR_WHITE, 32, y + 4, DSStage.TypeLabel(ty), 1.1);
            String kills = String.Format("%d", DSMeta.Val(mKeys, mVals, String.Format("ek:%d", ty)));
            Text(SmallFont, Font.CR_GREEN, 604 - SmallFont.StringWidth(kills) * 1.1, y + 4, kills, 1.1);
        }
        DSUi.Hints(384, String.Format("Up/Down|Scroll (%d / %d);Esc|Back", cursor + 1, beastTypes.Size()));
    }

    void StageChip(double x, double y, double w, String label, bool on, int onColour)
    {
        DSUi.Button(x, y, w, 18, on ? DSUi.BTN_NORMAL : DSUi.BTN_OFF);
        FitText(SmallFont, on ? onColour : Font.CR_DARKGRAY, x + 6, y + 5, label, w - 12);
    }

    void DrawStages()
    {
        DSUi.Header(14, "STAGE SELECTION", Font.CR_GOLD, 1.1, 200);
        double sc = Scale();
        for (int i = 0; i < StageCount(); i++)
        {
            double x, y, w, h;
            ItemRect(i, x, y, w, h);
            bool enabled = StageEnabled(i);
            bool focused = i == cursor;
            DSUi.Button(x, y, w, h, focused ? DSUi.BTN_FOCUS : (enabled ? DSUi.BTN_NORMAL : DSUi.BTN_OFF));
            TextureID thumb = TexMan.CheckForTexture(String.Format("STG%02d", i), TexMan.Type_Any);
            if (thumb.IsValid())
                Screen.DrawTexture(thumb, false, OffX() + (x + 4) * sc, OffY() + (y + 4) * sc, DTA_DestWidth, int(40 * sc), DTA_DestHeight, int(27 * sc),
                    DTA_Desaturate, enabled ? 0 : 255, DTA_Alpha, enabled ? 1.0 : 0.45);
            double nameSize = min(1.0, (w - 52) / SmallFont.StringWidth(StageName(i)));   // no floor: the longest name still fits
            Text(SmallFont, enabled ? (focused ? Font.CR_GOLD : Font.CR_WHITE) : Font.CR_DARKGRAY, x + 48, y + 6, StageName(i), nameSize);
            Text(SmallFont, enabled ? Font.CR_GREEN : Font.CR_DARKGRAY, x + 48, y + h - 15, enabled ? StageTimeText(i) : "locked");
        }

        // Left bar: preview and details of the focused stage.
        int c = clamp(cursor, 0, StageCount() - 1);
        bool open = StageEnabled(c);
        DSUi.Panel(16, 58, 118, 314);
        TextureID big = TexMan.CheckForTexture(String.Format("STG%02d", c), TexMan.Type_Any);
        if (big.IsValid())
            Screen.DrawTexture(big, false, OffX() + 30 * sc, OffY() + 64 * sc, DTA_DestWidth, int(96 * sc), DTA_DestHeight, int(64 * sc),
                DTA_Desaturate, open ? 0 : 255, DTA_Alpha, open ? 1.0 : 0.5);
        FitText(SmallFont, Font.CR_GOLD, 30, 134, StageName(c), 96, 1.3);
        if (open)
        {
            Text(SmallFont, Font.CR_GREEN, 30, 150, String.Format("Time %s", StageTimeText(c)));
            BrokenLines blurb = SmallFont.BreakLines(DSStage.Blurb(c), 96);
            for (int l = 0; l < blurb.Count() && l < 8; l++)
                Text(SmallFont, Font.CR_GREY, 30, 168 + l * 12, blurb.StringAt(l));
        }
        else if (DSStage.Has(c))
        {
            BrokenLines cond = SmallFont.BreakLines("Locked: " .. DSUnlocks.StageCondition(mKeys, mVals, c), 96);
            for (int l = 0; l < cond.Count() && l < 8; l++)
                Text(SmallFont, Font.CR_ORANGE, 30, 150 + l * 12, cond.StringAt(l));
        }
        FitText(SmallFont, Font.CR_DARKGRAY, 30, 352, "As " .. DSCharacters.Name(characterIndex), 96);
        if (DSRelics.Owned(mKeys, mVals, DSRelics.BANGER))
        {
            CVar music = CVar.FindCVar("ds_music");
            String track = music != null && music.GetString().Length() > 0 ? music.GetString() : "stage's own";
            FitText(SmallFont, Font.CR_GOLD, 30, 338, "B: Music " .. track, 96);
        }

        // Run options under the grid.
        CVar modeCvar = CVar.FindCVar("ds_mode");
        int modeNow = modeCvar != null ? modeCvar.GetInt() : 0;
        // Two rows of five chips; relic options say which relic they need.
        // Hyper is unlocked per stage; the chip says so for the focused one.
        bool hyperHere = DSUnlocks.HyperUnlocked(mKeys, mVals, clamp(cursor, 0, max(0, StageCount() - 1)));
        StageChip(140, 326, 96, modeNow == 1 ? (hyperHere ? "M: HYPER" : "M: HYPER locked") : (modeNow == 2 ? "M: INVERSE" : "M: Normal"), modeNow != 0 && (modeNow != 1 || hyperHere), Font.CR_RED);
        if (modeNow == 1 && !hyperHere)
            FitText(SmallFont, Font.CR_ORANGE, 140, 314, "Hyper here: " .. DSUnlocks.HyperCondition(clamp(cursor, 0, max(0, StageCount() - 1))), 480);
        StageChip(239, 326, 96, ToggleOn("ds_camera") ? "C: 3rd person" : "C: 1st person", ToggleOn("ds_camera"), Font.CR_CYAN);
        StageChip(338, 326, 96, ToggleOn("ds_arcana") ? "A: Arcana ON" : "A: Arcana OFF", ToggleOn("ds_arcana"), Font.CR_PURPLE);
        StageChip(437, 326, 96, RelicChip(DSRelics.GOSPEL, "L", "Limit Brk", "ds_limit_break"), RelicOn(DSRelics.GOSPEL, "ds_limit_break"), Font.CR_ORANGE);
        StageChip(536, 326, 96, ToggleOn("ds_aim_assist") ? "T: Aim ON" : "T: Aim OFF", ToggleOn("ds_aim_assist"), Font.CR_CYAN);
        StageChip(140, 348, 96, RelicChip(DSRelics.MILKY_WAY, "R", "Arrows", "ds_arrows"), RelicOn(DSRelics.MILKY_WAY, "ds_arrows"), Font.CR_GREEN);
        StageChip(239, 348, 96, RelicChip(DSRelics.TRUMPET, "E", "Endless", "ds_endless"), RelicOn(DSRelics.TRUMPET, "ds_endless"), Font.CR_RED);
        StageChip(338, 348, 96, RelicChip(DSRelics.TEARS, "H", "Hurry", "ds_hurry"), RelicOn(DSRelics.TEARS, "ds_hurry"), Font.CR_ORANGE);
        StageChip(437, 348, 96, RelicChip(DSRelics.TRISECTION, "V", "Events", "ds_random_events"), RelicOn(DSRelics.TRISECTION, "ds_random_events"), Font.CR_GOLD);
        StageChip(536, 348, 96, RelicChip(DSRelics.BRAVE_STORY, "U", "Rnd Lv-up", "ds_random_levelup"), RelicOn(DSRelics.BRAVE_STORY, "ds_random_levelup"), Font.CR_GOLD);
        DSUi.Hints(384, "Arrows|Browse;Enter|Start run;Esc|Back");
    }
}

// Opens the shell menu on the title screen when the launcher asks for it
// (ds_shell_autoopen 1).  Test runs pass +map and never see the title.
class DSShellBoot : StaticEventHandler
{
    ui bool opened;
    ui int shotTicks;

    override void UiTick()
    {
        // Screenshot aid for automated runs: ds_shell_shot N saves one
        // screenshot N tics after the shell menu opens.
        if (opened && menuactive != Menu.Off)
        {
            CVar shot = CVar.FindCVar("ds_shell_shot");
            if (shot != null && shot.GetInt() > 0 && ++shotTicks == shot.GetInt()) LevelLocals.MakeScreenShot();
        }
        // Once per session: the title screen is only seen at startup, and
        // a run's loading tics must not reopen the menu.
        if (opened) return;
        if (gamestate != GS_DEMOSCREEN && gamestate != GS_TITLELEVEL) return;
        if (menuactive != Menu.Off) return;
        CVar autoOpen = CVar.FindCVar("ds_shell_autoopen");
        if (autoOpen == null || autoOpen.GetInt() == 0) return;
        opened = true;
        Menu.SetMenu('MainMenu');
    }
}
