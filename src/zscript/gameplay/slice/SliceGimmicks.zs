// Stage gimmicks (docs/TODO.md): stage items lying on the map (wiki "Stage
// items"), plates that fire events or teleport, merchants and the wheel,
// destructible windows and carts, and per-stage rules (The Coop's clock and
// fences, Il Molise's tiles, Westwoods' locked west, Room 1665's rooms).
// Data comes from StageGimmicks.zs (tools/gen_gimmicks.py). Items are granted
// through the shared inventory authority's stage route, which may use extra
// slots.

// A floating item sprite (tools/art/item_sprites.py). Presentation only.
class DSStageItemProxy : Actor
{
    mixin DSGroundFollow;
    int bobTic;
    double baseZ;

    Default
    {
        Radius 2;
        Height 2;
        +NOBLOCKMAP;
        +NOGRAVITY;
        +NOINTERACTION;
        RenderStyle "Normal";
        Scale 0.9;
    }

    States
    {
    Spawn:
        I005 A -1;
        Stop;
    }

    override void Tick()
    {
        Super.Tick();
        bobTic++;
        SetZ(baseZ + 3.0 * sin(bobTic * 6.0));
        DSFollowGround();
    }
}

// The sprite of a destructible window or cart (a light-source-style enemy slot).
class DSMFPropProxy : DSP030EnemyProxy
{
    Default
    {
        RenderStyle "Normal";
        Alpha 1.0;
        Scale 1.6;
    }

    States
    {
    Spawn:
        DWND A -1;
        Stop;
    }
}

extend class DSP030VerticalSlice
{
    int GmMapNumber() { return level.MapName.Mid(3).ToInt(); }

    void GmShowToast(String text)
    {
        gmToast = text;
        Console.Printf("DS_GM_TOAST tic=%d %s", tic, text);
        gmToastUntil = tic + 140;
    }

    static bool MFIsProp(int type) { return type >= MF_BRAZIER_TYPE && type <= MF_CART_TYPE; }

    int GmFindType(String name)
    {
        for (int t = 1; t <= DSStage.ENEMY_TYPE_COUNT; t++)
            if (DSStage.TypeName(t) == name) return t;
        return 0;
    }

    // ---- stage rules -------------------------------------------------------

    // The stage clock, which stops while The Coop waits for its first kill.
    clearscope int MfT() { return rsHurry ? (tic - mfHeld) * 2 : tic - mfHeld; }

    bool MoliseOccupied(double tx, double ty)
    {
        for (int s = 0; s < lifeStates.Size(); s++)
        {
            if (lifeStates[s] != STORE_ALIVE || kinds[s] != KIND_ENEMY) continue;
            if (abs(x[s] - tx) < 48.0 && abs(y[s] - ty) < 48.0) return true;
        }
        return false;
    }

    double CoopWest() { return -1800.0; }

    // One fence to the east opens every 60 seconds for 15 minutes.
    double CoopEast()
    {
        int opened = mfCoopStarted ? clamp(MfT() / 2100, 0, 15) : 0;
        return min(11800.0, 1500.0 + 1300.0 * opened);
    }

    // Westwoods: the west is walled off until the wheel opens it.
    double WoodWest() { return gmWoodUnlock >= 2 ? -5900.0 : -1500.0 - 2300.0 * gmWoodUnlock; }

    // Room 1665: a room opens to the south per 100 kills (all by 1665).
    int RoomsOpen() { return kills >= 1665 ? 16 : min(15, kills / 100); }
    double RoomSouth() { return max(-12150.0, 10700.0 - 1400.0 * RoomsOpen()); }

    // Keeps the player inside the pen the fences currently allow.
    void BarrierTick()
    {
        Actor mo = players[0].mo;
        if (mo == null) return;
        double px = mo.pos.x; double py = mo.pos.y;
        if (mfCoop) px = clamp(px, CoopWest() + 24.0, CoopEast() - 24.0);
        if (mfWoods) px = max(px, WoodWest() + 24.0);
        if (mfRoom) py = max(py, RoomSouth() + 24.0);
        if (px != mo.pos.x || py != mo.pos.y) mo.SetOrigin((px, py, mo.pos.z), false);
    }

    int GmFenceCount()
    {
        if (mfCoop) return 68;
        if (mfWoods) return 100;
        if (mfRoom) return 34;
        return 0;
    }

    void GmFencePos(int i, out double fx, out double fy)
    {
        fx = 0.0; fy = 0.0;
        if (mfCoop)
        {
            fx = i < 34 ? CoopWest() : CoopEast();
            fy = -990.0 + (i % 34) * 60.0;
        }
        else if (mfWoods)
        {
            fx = gmWoodUnlock >= 2 ? 0.0 : WoodWest();
            fy = gmWoodUnlock >= 2 ? -20000.0 : -5990.0 + i * 120.0;
        }
        else if (mfRoom)
        {
            fx = -990.0 + i * 60.0;
            fy = RoomSouth();
        }
    }

    void GmSyncFences()
    {
        int n = GmFenceCount();
        if (n == 0) return;
        if (gmFenceActors.Size() == 0)
            for (int i = 0; i < n; i++) gmFenceActors.Push(Actor.Spawn("DSDecoFence", (0.0, 0.0, 0.0), NO_REPLACE));
        for (int i = 0; i < gmFenceActors.Size(); i++)
        {
            double fx; double fy;
            GmFencePos(i, fx, fy);
            if (gmFenceActors[i] != null) gmFenceActors[i].SetOrigin((fx, fy, 0.0), true);
        }
    }

    // ---- reset ---------------------------------------------------------------

    void GmReset()
    {
        for (int i = 0; i < gmItemActor.Size(); i++)
            if (gmItemActor[i] != null) gmItemActor[i].Destroy();
        for (int i = 0; i < gmFenceActors.Size(); i++)
            if (gmFenceActors[i] != null) gmFenceActors[i].Destroy();
        for (int i = 0; i < gmDecorActors.Size(); i++)
            if (gmDecorActors[i] != null) gmDecorActors[i].Destroy();
        gmFenceActors.Clear(); gmDecorActors.Clear();
        gmItemId.Clear(); gmItemX.Clear(); gmItemY.Clear(); gmItemActor.Clear();
        gmPlateX.Clear(); gmPlateY.Clear(); gmPlateKind.Clear(); gmPlateReady.Clear();
        gmPlateTX.Clear(); gmPlateTY.Clear();
        gmPropKind.Clear(); gmPropX.Clear(); gmPropY.Clear(); gmPropTX.Clear(); gmPropTY.Clear();
        gmPropSlot.Clear(); gmPropId.Clear(); gmPropReady.Clear();
        gmMvX.Clear(); gmMvY.Clear(); gmMvVX.Clear(); gmMvVY.Clear(); gmMvLife.Clear();
        gmCrabSlot.Clear(); gmCrabId.Clear();
        gmRng = 6401197; gmShopIndex = 0; gmShopCount = 0; gmWoodUnlock = 0; gmReaperNext = 0; gmToastUntil = 0;
        gmRoomsShown = 0;
        int map = GmMapNumber();
        mfWoods = level.MapName == "MAP44"; mfRoom = level.MapName == "MAP50";
        DgReset();
        if (!mfEnabled || !rsActive) return;
        gmTypeCrab = GmFindType("MOON_BOSS_CRABBINO");
        gmTypeDrowner = GmFindType("BOSS_DROWNER_NORMAL");
        gmTypeStalker = GmFindType("BOSS_STALKER_NORMAL");
        gmTypeTrickster = GmFindType("BOSS_TRICKSTER_NORMAL");
        for (int i = 0; i < DSStageGimmicks.ItemCount(); i++)
        {
            if (DSStageGimmicks.ITEM_MAP[i] != map) continue;
            gmRng = DSP022StageGeometry.NextSpawnRng(gmRng);
            if ((gmRng & 0x7fffffff) % 100 >= DSStageGimmicks.ITEM_CHANCE[i]) continue;
            gmItemId.Push(DSStageGimmicks.ITEM_ID[i]);
            gmItemX.Push(DSStageGimmicks.ITEM_X[i]); gmItemY.Push(DSStageGimmicks.ITEM_Y[i]);
            gmItemActor.Push(null);
        }
        for (int i = 0; i < DSStageGimmicks.PlateCount(); i++)
        {
            if (DSStageGimmicks.PLATE_MAP[i] != map) continue;
            gmPlateX.Push(DSStageGimmicks.PLATE_X[i]); gmPlateY.Push(DSStageGimmicks.PLATE_Y[i]);
            gmPlateKind.Push(DSStageGimmicks.PLATE_KIND[i]); gmPlateReady.Push(0);
            gmPlateTX.Push(DSStageGimmicks.PLATE_TX[i]); gmPlateTY.Push(DSStageGimmicks.PLATE_TY[i]);
            if (DSStageGimmicks.PLATE_KIND[i] == 8)
            {
                Array<String> ck; Array<int> cv;
                DSMeta.Load(ck, cv);
                if (DSMeta.Val(ck, cv, String.Format("coffin:%d", DSStageGimmicks.PLATE_TX[i])) > 0) gmPlateReady[gmPlateReady.Size() - 1] = 1000000000;
            }
            // A relic already found does not come back.
            if (DSStageGimmicks.PLATE_KIND[i] == 9)
            {
                Array<String> rk; Array<int> rv;
                DSMeta.Load(rk, rv);
                if (DSMeta.Val(rk, rv, String.Format("relic:%d", DSStageGimmicks.PLATE_TX[i])) > 0) gmPlateReady[gmPlateReady.Size() - 1] = 1000000000;
            }
        }
        for (int i = 0; i < DSStageGimmicks.PropCount(); i++)
        {
            if (DSStageGimmicks.PROP_MAP[i] != map) continue;
            gmPropKind.Push(DSStageGimmicks.PROP_KIND[i]);
            gmPropX.Push(DSStageGimmicks.PROP_X[i]); gmPropY.Push(DSStageGimmicks.PROP_Y[i]);
            gmPropTX.Push(DSStageGimmicks.PROP_TX[i]); gmPropTY.Push(DSStageGimmicks.PROP_TY[i]);
            gmPropSlot.Push(-1); gmPropId.Push(0); gmPropReady.Push(0);
        }
        // Glass Vizard: the Merchant visits every stage (near the start).
        {
            Array<String> vk; Array<int> vv;
            DSMeta.Load(vk, vv);
            if (DSRelics.Owned(vk, vv, DSRelics.GLASS_VIZARD) && gmPlateKind.Find(6) == gmPlateKind.Size() && !dgActive)
            {
                gmPlateX.Push(260); gmPlateY.Push(260); gmPlateKind.Push(6); gmPlateReady.Push(0);
                gmPlateTX.Push(0); gmPlateTY.Push(0);
            }
        }
        gmApoplexyPlate = -1;
        Console.Printf("DS_GM_INIT map=%d items=%d plates=%d props=%d", map, gmItemId.Size(), gmPlateX.Size(), gmPropKind.Size());
    }

    // ---- per-tic ---------------------------------------------------------------

    int GmPlateRadius(int kind)
    {
        if (kind == 4) return 320;
        if (kind == 6 || kind == 7) return 80;
        if (kind == 8) return 60;
        if (kind == 5) return 60;
        return 48;
    }

    void GmTick()
    {
        if (!mfEnabled || !rsActive || runState != STATE_ACTIVE) return;
        if (mfCoop || mfWoods || mfRoom) BarrierTick();
        GmApoplexyTick();
        GmHolyTick();
        CVar dbg = CVar.FindCVar("ds_gm_debug");
        if (dbg != null && dbg.GetInt() != 0 && tic >= 100 && tic % 40 == 0)
        {
            double off = dbg.GetInt() == 2 ? 260.0 : 0.0;
            if (tic == 120) mfGold += 5000;
            for (int k = 0; k < gmPropSlot.Size(); k++)
                if (gmPropSlot[k] >= 0) { x[gmPropSlot[k]] = playerX + 60.0; y[gmPropSlot[k]] = playerY + 20.0 * k; }
            for (int k = 0; k < gmItemId.Size(); k++) { gmItemX[k] = playerX + off + k * 30.0; gmItemY[k] = playerY + (k % 2) * 60.0; }
            for (int k = 0; k < gmPlateX.Size(); k++) { gmPlateX[k] = playerX + off + 120.0 * k; gmPlateY[k] = playerY - (dbg.GetInt() == 2 ? 150.0 : 0.0); }
        }
        for (int i = gmItemId.Size() - 1; i >= 0; i--)
        {
            double dx = playerX - gmItemX[i]; double dy = playerY - gmItemY[i];
            if (dx * dx + dy * dy > 42.0 * 42.0) continue;
            int id = gmItemId[i];
            bool granted = DSP031StageGrant(id);
            Sfx(DSSfx.I_FLOOR_ITEM);
            GmShowToast(String.Format("Found: %s", DSN2Catalog.DisplayName(id)));
            Console.Printf("DS_GM_ITEM tic=%d item=%d granted=%d", tic, id, granted);
            if (gmItemActor[i] != null) gmItemActor[i].Destroy();
            gmItemId.Delete(i); gmItemX.Delete(i); gmItemY.Delete(i); gmItemActor.Delete(i);
        }
        for (int i = 0; i < gmPlateX.Size(); i++)
        {
            if (tic < gmPlateReady[i]) continue;
            double dx = playerX - gmPlateX[i]; double dy = playerY - gmPlateY[i];
            double r = GmPlateRadius(gmPlateKind[i]);
            if (dx * dx + dy * dy > r * r) continue;
            GmTriggerPlate(i);
        }
        GmPropsTick();
        GmMoversTick();
        GmCrabTick();
        if (level.MapName == "MAP33") GmReaperTick();
        if (mfRoom) GmRoomTick();
        DgTick();
    }

    void GmTriggerPlate(int i)
    {
        int kind = gmPlateKind[i];
        double px = gmPlateX[i]; double py = gmPlateY[i];
        gmRng = DSP022StageGeometry.NextSpawnRng(gmRng);
        if (kind == 5)
        {
            // A door: jump to the paired door; both ends rest for a moment.
            Actor mo = players[0].mo;
            if (mo != null) mo.SetOrigin((gmPlateTX[i], gmPlateTY[i], mo.pos.z), false);
            for (int j = 0; j < gmPlateX.Size(); j++)
                if (gmPlateKind[j] == 5 && abs(gmPlateX[j] - gmPlateTX[i]) < 90.0 && abs(gmPlateY[j] - gmPlateTY[i]) < 90.0)
                    gmPlateReady[j] = tic + 105;
            gmPlateReady[i] = tic + 105;
            Sfx(DSSfx.E_DOOR);
            Console.Printf("DS_GM_DOOR tic=%d to=%.0f,%.0f", tic, gmPlateTX[i], gmPlateTY[i]);
            return;
        }
        if (kind == 8)
        {
            gmPlateReady[i] = tic + 1000000;
            Array<String> mk; Array<int> mv;
            DSMeta.Load(mk, mv);
            int coffin = int(gmPlateTX[i]);
            bool already = DSMeta.Val(mk, mv, String.Format("coffin:%d", coffin)) > 0;
            DSMeta.SetVal(mk, mv, String.Format("coffin:%d", coffin), 1);
            DSMeta.Store(mk, mv);
            Sfx(DSSfx.E_COFFIN);
            if (!already) GmShowToast(String.Format("The coffin opens: %s joins you!", GmCoffinName(coffin)));
            else
            {
                // Looking under a coffin opened before unlocks Random.
                DSMeta.SetVal(mk, mv, "coffinagain", 1);
                DSMeta.Store(mk, mv);
                GmShowToast("An empty coffin... something is underneath.");
            }
            return;
        }
        if (kind == 9)
        {
            gmPlateReady[i] = tic + 1000000;
            Array<String> rk; Array<int> rv;
            DSMeta.Load(rk, rv);
            bool had = DSMeta.Val(rk, rv, String.Format("relic:%d", int(gmPlateTX[i]))) > 0;
            DSMeta.SetVal(rk, rv, String.Format("relic:%d", int(gmPlateTX[i])), 1);
            DSMeta.Store(rk, rv);
            Sfx(DSSfx.E_RELIC);
            Console.Printf("DS_GM_RELIC tic=%d relic=%d already=%d", tic, int(gmPlateTX[i]), had);
            int relic = int(gmPlateTX[i]);
            GmShowToast(had ? String.Format("You already carry %s.", DSRelics.Name(relic))
                : String.Format("You found %s. %s", DSRelics.Name(relic), DSRelics.Gift(relic)));
            return;
        }
        if (kind == 6) { GmMerchant(i); return; }
        if (kind == 7) { GmWheel(i); return; }
        if (kind == 10) { GmLeverSwarm(i); return; }
        if (kind == 3)
        {
            gmPlateReady[i] = tic + 1000000;
            if (gmTypeCrab > 0)
            {
                int slot = MFSpawn(gmTypeCrab, px + 220.0, py, 0, 0.0, 0.0, 0, 0);
                if (slot >= 0) { gmCrabSlot.Push(slot); gmCrabId.Push(ids[slot]); }
            }
            Sfx(DSSfx.BOSS, 10);
            GmShowToast("A giant crab emerges!");
            return;
        }
        if (kind == 4)
        {
            gmPlateReady[i] = tic + 1000000;
            if (gmTypeDrowner > 0) MFSpawn(gmTypeDrowner, playerX + 500.0, playerY, 0, 0.0, 0.0, tic + 4200, 0);
            Sfx(DSSfx.REAPER);
            GmShowToast("The Drowner rises...");
            return;
        }
        gmPlateReady[i] = tic + 4200;
        Sfx(DSSfx.E_PLATE, 10);
        if (kind == 2)
        {
            // Laborratory lever: a train runs along the lane and hits every
            // enemy in it (wiki: trains deal damage to enemies).
            Array<int> lane;
            GwEnemiesNear(px, py, 4000.0, lane);
            int hit = 0;
            for (int j = 0; j < lane.Size(); j++)
            {
                if (abs(y[lane[j]] - py) > 450.0) continue;
                GwHit(lane[j], 30000, 0);
                hit++;
            }
            for (int bx = -1500; bx <= 1500; bx += 150)
                DSWeaponFx.Burst("WBLT", playerX + bx, py, 24.0, 60.0, 60.0, false, Color(255, 200, 120), 8);
            metaTrainHits += hit;
            Console.Printf("DS_GM_PLATE tic=%d kind=2 hit=%d", tic, hit);
            return;
        }
        int events = DSStage.EventCount(mfStage);
        if (events > 0)
        {
            int index = (gmRng & 0x7fffffff) % events;
            MFStartEvent(index, true);
            Console.Printf("DS_GM_PLATE tic=%d kind=1 event=%d", tic, index);
            return;
        }
        // A stage with no map events: a burst of its current wave around the plate.
        int minute = MfT() / 2100;
        int pool = DSStage.PoolCount(mfStage, minute);
        for (int n = 0; n < 12 && pool > 0; n++)
        {
            double angle = 30.0 * n;
            MFSpawn(DSStage.PoolType(mfStage, minute, n % pool), px + cos(angle) * 260.0, py + sin(angle) * 260.0, 0, 0.0, 0.0, 0, 0);
        }
        Console.Printf("DS_GM_PLATE tic=%d kind=1 burst=1", tic);
    }

    static String GmCoffinName(int n)
    {
        switch (n)
        {
        case 0: return "Pugnala";
        case 1: return "Giovanna";
        case 2: return "Poppea";
        case 3: return "Concetta";
        }
        return "Zi'Assunta";
    }

    // ---- merchant and wheel ------------------------------------------------------

    static int GmShopId(int n)
    {
        switch (n % 5)
        {
        case 0: return 56;
        case 1: return 57;
        case 2: return 58;
        case 3: return 86;
        }
        return 88;
    }

    // Moongolow's merchant sells rare weapons for gold (wiki: Bone, Cherry
    // Bomb, Carrello, Celestial Dusting... 1,000 each); the next offer in
    // rotation is bought when you stand on him with enough gold.
    // Laborratory swarm lever: one of the room's swarms bursts in around the
    // player (the original's lever outcomes; sizes are guesses).
    void GmLeverSwarm(int i)
    {
        gmPlateReady[i] = tic + 700;
        static const String CENTRAL[] = { "TRAINEE_Y", "TRINACRIA", "ANGEL2" };
        static const String ROOMS[] = { "JELLYFISH2_SWARM", "MUD", "ECTO2" };
        gmRng = DSP022StageGeometry.NextSpawnRng(gmRng);
        int pick = (gmRng & 0x7fffffff) % 3;
        String name = int(gmPlateTX[i]) == 0 ? CENTRAL[pick] : ROOMS[pick];
        int type = 0;
        for (int t = 1; t <= DSStage.ENEMY_TYPE_COUNT; t++) if (DSStage.TypeName(t) == name) type = t;
        if (type <= 0) return;
        int count = name == "TRINACRIA" ? 1 : 20;
        for (int n = 0; n < count; n++)
        {
            double angle = 360.0 * n / count;
            MFSpawn(type, playerX + cos(angle) * 260.0, playerY + sin(angle) * 260.0, 0, 0.0, 0.0, tic + 1050, 0);
        }
        Sfx(DSSfx.E_PLATE);
        GmShowToast("A lever clanks: " .. DSStage.TypeLabel(type));
    }

    // Holy Forbidden's script (stage time 2:00): from 1:12 to 1:27 the
    // Maddener marks spots that burst a second later (15 damage); from 1:35
    // its touch kills outright; the Rosary at the corridor's end clears the
    // hall and ends the stage 30 s later.
    void GmHolyTick()
    {
        if (mfStage != DSStage.HOLYFORBIDDEN || dgActive || runState != STATE_ACTIVE) return;
        int t = MfT();
        if (t >= 72 * 35 && t < 87 * 35 && t % 18 == 0)
        {
            gmRng = DSP022StageGeometry.NextSpawnRng(gmRng);
            double ox = ((gmRng & 0xff) - 128) * 0.8; double oy = (((gmRng >> 8) & 0xff) - 128) * 0.8;
            hfMarkX.Push(playerX + ox); hfMarkY.Push(playerY + oy); hfMarkTic.Push(tic + 35);
            DSWeaponFx.Burst("WBLT", playerX + ox, playerY + oy, 6.0, 30.0, 35.0, true, Color(255, 255, 60, 60), 4);
        }
        for (int m = hfMarkTic.Size() - 1; m >= 0; m--)
        {
            if (tic < hfMarkTic[m]) continue;
            DSWeaponFx.Burst("WFLM", hfMarkX[m], hfMarkY[m], 20.0, 48.0, 60.0, false, Color(255, 255, 120, 60), 8);
            double dx = playerX - hfMarkX[m]; double dy = playerY - hfMarkY[m];
            if (dx * dx + dy * dy <= 48.0 * 48.0 && playerInvulnerableUntil <= tic && playerHealth > 0)
            {
                playerHealth = max(0, playerHealth - 15000);
                health[playerSlot] = playerHealth;
            }
            hfMarkX.Delete(m); hfMarkY.Delete(m); hfMarkTic.Delete(m);
        }
        if (!hfRosaryPlaced)
        {
            // The Rosary waits at the far end of the hall.
            hfRosaryPlaced = true;
            mfItemSeq++;
            mfItemIds.Push(mfItemSeq); mfItemKinds.Push(MF_ITEM_ROSARY);
            mfItemX.Push(1850.0); mfItemY.Push(300.0);
            hfRosaryId = mfItemSeq;
        }
    }

    // The Maddener's chase from 1:35: contact is lethal.
    bool GmMaddenerLethal(int slot)
    {
        return mfStage == DSStage.HOLYFORBIDDEN && MFValid(slot) && MfT() >= 95 * 35
            && DSStage.TypeName(mfTypes[slot]).IndexOf("MADDENER") >= 0;
    }

    void GmApoplexyTick()
    {
        if (mfStage != DSStage.BATCOUNTRY || dgActive) return;
        int t = MfT();
        if (gmApoplexyPlate < 0 && t >= 9 * 2100 && t < 9 * 2100 + 35)
        {
            Array<String> ak; Array<int> av;
            DSMeta.Load(ak, av);
            if (DSRelics.Owned(ak, av, DSRelics.APOPLEXY)) { gmApoplexyPlate = 1000000; return; }
            gmPlateX.Push(playerX + 300); gmPlateY.Push(playerY + 200); gmPlateKind.Push(9);
            gmPlateReady.Push(0); gmPlateTX.Push(DSRelics.APOPLEXY); gmPlateTY.Push(0);
            gmApoplexyPlate = gmPlateX.Size() - 1;
            GmShowToast("Something glints nearby...");
        }
        if (gmApoplexyPlate >= 0 && gmApoplexyPlate < gmPlateReady.Size() && t >= 10 * 2100)
            gmPlateReady[gmApoplexyPlate] = 1000000000;   // gone after a minute
    }

    void GmMerchant(int i)
    {
        gmPlateReady[i] = tic + 105;
        // Moongolow's Merchant sells the Glass Vizard first (10000 gold).
        if (mfStage == DSStage.MOONGOLOW)
        {
            Array<String> vk; Array<int> vv;
            DSMeta.Load(vk, vv);
            if (!DSRelics.Owned(vk, vv, DSRelics.GLASS_VIZARD))
            {
                if (mfGold < 10000) { GmShowToast("Merchant: the Glass Vizard for 10000 gold"); return; }
                mfGold -= 10000; mfGoldMilli = mfGold * 1000;
                DSMeta.SetVal(vk, vv, String.Format("relic:%d", DSRelics.GLASS_VIZARD), 1);
                DSMeta.Store(vk, vv);
                Sfx(DSSfx.E_RELIC);
                GmShowToast("You bought the Glass Vizard. " .. DSRelics.Gift(DSRelics.GLASS_VIZARD));
                return;
            }
        }
        if (gmShopCount % 2 == 1)
        {
            // Every other offer is a Golden Egg: a permanent +small boost to a
            // random stat from the next run on (wiki: Golden Egg).
            if (mfGold < 1000) { GmShowToast("Merchant: Golden Egg for 1000 gold"); return; }
            mfGold -= 1000;
            gmShopCount++;
            GmBuyEgg();
            return;
        }
        int id = GmShopId(gmShopIndex);
        if (mfGold < 1000)
        {
            GmShowToast(String.Format("Merchant: %s for 1000 gold", DSN2Catalog.DisplayName(id)));
            return;
        }
        mfGold -= 1000;
        bool granted = DSP031StageGrant(id);
        gmShopIndex++; gmShopCount++;
        Sfx(DSSfx.E_MERCHANT);
        GmShowToast(String.Format("Bought %s", DSN2Catalog.DisplayName(id)));
        Console.Printf("DS_GM_SHOP tic=%d item=%d granted=%d gold_left=%d", tic, id, granted, mfGold);
    }

    void GmBuyEgg()
    {
        gmRng = DSP022StageGeometry.NextSpawnRng(gmRng);
        int stat = (gmRng & 0x7fffffff) % DSEggs.COUNT;
        Array<String> ek; Array<int> ev;
        DSMeta.Load(ek, ev);
        DSMeta.Bump(ek, ev, String.Format("egg:%d", stat), 1);
        DSMeta.Bump(ek, ev, "eggs", 1);
        DSMeta.Store(ek, ev);
        Sfx(DSSfx.E_EGG);
        GmShowToast(String.Format("Golden Egg: %s (next run)", DSEggs.Name(stat)));
        Console.Printf("DS_GM_EGG tic=%d stat=%d total=%d", tic, stat, DSMeta.Val(ek, ev, "eggs"));
    }

    static int GmWheelItem(int n)
    {
        switch (n % 10)
        {
        case 0: return 2;
        case 1: return 3;
        case 2: return 5;
        case 3: return 7;
        case 4: return 8;
        case 5: return 9;
        case 6: return 10;
        case 7: return 73;
        case 8: return 74;
        }
        return 75;
    }

    // Westwoods' "Spin the Wheel!": 50 gold buys a spin that grants a passive,
    // starts an ambush, or opens the walled-off west.
    void GmWheel(int i)
    {
        gmPlateReady[i] = tic + 70;
        if (mfGold < 50) { GmShowToast("Spin the Wheel! costs 50 gold"); return; }
        mfGold -= 50;
        gmRng = DSP022StageGeometry.NextSpawnRng(gmRng);
        int roll = (gmRng & 0x7fffffff) % 100;
        Sfx(DSSfx.E_WHEEL);
        if (roll < 35)
        {
            gmRng = DSP022StageGeometry.NextSpawnRng(gmRng);
            int id = GmWheelItem((gmRng & 0x7fffffff) % 10);
            DSP031StageGrant(id);
            GmShowToast(String.Format("The wheel gives %s", DSN2Catalog.DisplayName(id)));
        }
        else if (roll < 65 && DSStage.EventCount(mfStage) > 0)
        {
            gmRng = DSP022StageGeometry.NextSpawnRng(gmRng);
            MFStartEvent((gmRng & 0x7fffffff) % DSStage.EventCount(mfStage), true);
            GmShowToast("The wheel: an ambush!");
        }
        else if (gmWoodUnlock < 2)
        {
            gmWoodUnlock++;
            GmShowToast("The wheel opens the way west");
        }
        else GmShowToast("The wheel: nothing");
        Console.Printf("DS_GM_WHEEL tic=%d roll=%d unlock=%d gold_left=%d", tic, roll, gmWoodUnlock, mfGold);
    }

    // ---- destructible windows and carts ------------------------------------------

    void GmSpawnProp(int i)
    {
        int type = gmPropKind[i] == 1 ? MF_WINDOW_TYPE : MF_CART_TYPE;
        int slot = MFSpawn(type, gmPropX[i], gmPropY[i], 2, 0.0, 0.0, 0, 0);
        if (slot < 0) return;
        collisionRadii[slot] = gmPropKind[i] == 1 ? 12.0 : 16.0;
        gmPropSlot[i] = slot; gmPropId[i] = ids[slot];
        Console.Printf("DS_GM_PROP spawn kind=%d slot=%d tic=%d", gmPropKind[i], slot, tic);
    }

    int GmLiveWindows()
    {
        int n = 0;
        for (int i = 0; i < gmPropKind.Size(); i++)
            if (gmPropKind[i] == 1 && gmPropSlot[i] >= 0) n++;
        return n;
    }

    // Props are re-spawned after a delay; windows appear randomly at their
    // set locations (up to six at once), carts always sit on their rails.
    void GmPropsTick()
    {
        for (int i = 0; i < gmPropKind.Size(); i++)
        {
            int slot = gmPropSlot[i];
            if (slot >= 0)
            {
                bool alive = slot < lifeStates.Size() && lifeStates[slot] == STORE_ALIVE && ids[slot] == gmPropId[i] && MFValid(slot);
                if (!alive) { gmPropSlot[i] = -1; gmPropReady[i] = tic + (gmPropKind[i] == 1 ? 1050 : 2100); }
                continue;
            }
            if (tic < gmPropReady[i]) continue;
            if (gmPropKind[i] == 1)
            {
                gmRng = DSP022StageGeometry.NextSpawnRng(gmRng);
                if (GmLiveWindows() >= 6 || (gmRng & 0x7fffffff) % 40 != 0) continue;
            }
            GmSpawnProp(i);
        }
    }

    // Called when a prop enemy dies (HandleEnemyDeath): windows burst into a
    // pillar of light that hurts nearby enemies; carts launch along their rail.
    void GmPropDied(int type, int slot, double px, double py)
    {
        int prop = -1;
        for (int i = 0; i < gmPropSlot.Size(); i++) if (gmPropSlot[i] == slot) prop = i;
        Console.Printf("DS_GM_PROP died type=%d tic=%d", type, tic);
        if (type == MF_WINDOW_TYPE)
        {
            Array<int> nearby;
            GwEnemiesNear(px, py, 300.0, nearby);
            for (int j = 0; j < nearby.Size(); j++)
                if (nearby[j] != slot && !(MFValid(nearby[j]) && MFIsProp(mfTypes[nearby[j]]))) GwHit(nearby[j], 40000, 0);
            DSWeaponFx.Burst("WBLT", px, py, 40.0, 140.0, 140.0, false, Color(255, 245, 200), 14);
            DSWeaponFx.Burst("WRNG", px, py, 1.5, 60.0, 520.0, true, Color(255, 240, 180), 14);
            Sfx(DSSfx.E_GEM_BOMB, 10);
        }
        else if (type == MF_CART_TYPE && prop >= 0)
        {
            double dx = gmPropTX[prop] - px; double dy = gmPropTY[prop] - py;
            double d = max(1.0, sqrt(dx * dx + dy * dy));
            gmMvX.Push(px); gmMvY.Push(py); gmMvVX.Push(dx / d * 14.0); gmMvVY.Push(dy / d * 14.0);
            gmMvLife.Push(int(d / 14.0));
            Sfx(DSSfx.E_CART_LAUNCH, 10);
            GmShowToast("The milk cart is off!");
        }
        if (prop >= 0) { gmPropSlot[prop] = -1; gmPropReady[prop] = tic + (type == MF_WINDOW_TYPE ? 1050 : 2100); }
    }

    // Launched carts crush every enemy they touch.
    void GmMoversTick()
    {
        for (int i = gmMvX.Size() - 1; i >= 0; i--)
        {
            gmMvX[i] += gmMvVX[i]; gmMvY[i] += gmMvVY[i];
            Array<int> hit;
            GwEnemiesNear(gmMvX[i], gmMvY[i], 80.0, hit);
            for (int j = 0; j < hit.Size(); j++)
                if (!(MFValid(hit[j]) && MFIsProp(mfTypes[hit[j]])) && mfBoss[hit[j]] == 0) GwHit(hit[j], 80000, 0);
            gmMvLife[i]--;
            if (gmMvLife[i] <= 0)
            {
                gmMvX.Delete(i); gmMvY.Delete(i); gmMvVX.Delete(i); gmMvVY.Delete(i); gmMvLife.Delete(i);
            }
        }
    }

    // ---- Lycaeum crabs, Cappella reapers, Room 1665 ---------------------------------

    void GmCrabTick()
    {
        for (int i = gmCrabSlot.Size() - 1; i >= 0; i--)
        {
            int slot = gmCrabSlot[i];
            bool alive = slot < lifeStates.Size() && lifeStates[slot] == STORE_ALIVE && ids[slot] == gmCrabId[i];
            if (alive) continue;
            DSP031StageGrant(DSN2Catalog.ID_EMPTY_TOME);
            GmShowToast("The crab drops an Empty Tome");
            Sfx(DSSfx.I_FLOOR_ITEM);
            gmCrabSlot.Delete(i); gmCrabId.Delete(i);
        }
    }

    // Cappella Magna: every 5 minutes a Reaper of an earlier stage arrives, in
    // the order Drowner, Stalker, Trickster.
    void GmReaperTick()
    {
        if (MfT() < (gmReaperNext + 1) * 10500) return;
        int type = gmReaperNext % 3 == 0 ? gmTypeDrowner : gmReaperNext % 3 == 1 ? gmTypeStalker : gmTypeTrickster;
        gmReaperNext++;
        if (type <= 0) return;
        MFSpawn(type, playerX + 450.0, playerY, 0, 0.0, 0.0, tic + 4200, 0);
        Sfx(DSSfx.REAPER);
        GmShowToast("A Reaper draws near...");
    }

    // Room 1665 gets darker with every room opened and lights up at the end.
    void GmRoomTick()
    {
        int open = RoomsOpen();
        if (open == gmRoomsShown && tic % 175 != 0) return;
        if (open != gmRoomsShown) GmShowToast(String.Format("Room %d of 16 unlocked", open + 1));
        gmRoomsShown = open;
        int light = open >= 16 ? 255 : max(40, 150 - 7 * open);
        for (int s = 0; s < level.Sectors.Size(); s++) level.Sectors[s].SetLightLevel(light);
    }

    // ---- presentation ------------------------------------------------------------------

    // Item sprites, plate rings and fences (called from SyncWeaponFx each tic).
    void GmSyncActors()
    {
        GmSyncFences();
        DgSyncActors();
        for (int i = 0; i < gmItemId.Size(); i++)
        {
            if (gmItemActor[i] == null)
            {
                DSStageItemProxy p = DSStageItemProxy(Actor.Spawn("DSStageItemProxy", (gmItemX[i], gmItemY[i], 18.0), NO_REPLACE));
                if (p != null)
                {
                    p.sprite = Actor.GetSpriteIndex(String.Format("I%03d", gmItemId[i]));
                    p.baseZ = 18.0;
                }
                gmItemActor[i] = p;
            }
            else gmItemActor[i].SetOrigin((gmItemX[i], gmItemY[i], gmItemActor[i].pos.z), true);
            FxKeep(8000 + i, "WRNG", gmItemX[i], gmItemY[i], 1.2, 70.0, true, Color(255, 220, 100), 0.5);
        }
        if (gmDecorActors.Size() == 0)
        {
            for (int i = 0; i < gmPlateX.Size(); i++)
            {
                int k = gmPlateKind[i];
                Actor a = null;
                if (k == 5) a = Actor.Spawn("DSDecoDoor", (gmPlateX[i], gmPlateY[i], 0.0), NO_REPLACE);
                else if (k == 8) a = Actor.Spawn("DSDecoCoffin", (gmPlateX[i], gmPlateY[i], 0.0), NO_REPLACE);
                else if (k == 6 || k == 7) a = Actor.Spawn("DSDecoMerchant", (gmPlateX[i], gmPlateY[i], 0.0), NO_REPLACE);
                gmDecorActors.Push(a);
            }
        }
        for (int i = 0; i < gmPlateX.Size(); i++)
        {
            int k = gmPlateKind[i];
            if (k == 4 || k == 8) continue;
            Color tint = tic < gmPlateReady[i] ? Color(90, 90, 100)
                : k == 2 ? Color(120, 200, 255) : k == 3 ? Color(255, 60, 60) : k == 5 ? Color(180, 120, 255)
                : (k == 6 || k == 7 || k == 9) ? Color(255, 220, 90) : Color(255, 90, 60);
            FxKeep(9000 + i, "WRNG", gmPlateX[i], gmPlateY[i], 1.2, 96.0, true, tint, 0.6);
        }
        for (int i = 0; i < gmMvX.Size(); i++)
            FxKeep(7000 + i, "DCRT", gmMvX[i], gmMvY[i], 6.0, 70.0, false, Color(0, 0, 0, 0), 1.0);
    }
}
