// The Depths (MAP53): an original roguelike dungeon stage. The map holds a
// superset dungeon (DungeonTables.zs, tools/gen_dungeon.py); each run grows
// its own plan over it, after The Binding of Isaac: per floor, rooms spread
// breadth-first from the room the floor is entered by (a cell with more than
// one planned neighbour is skipped, and each step is a coin flip), then a few
// loops are added back. The stairs down go in the farthest east-column room,
// the Amulet in the bottom floor's farthest dead end, and other dead ends
// hold a store of light sources. Doors not in the plan close and each room
// raises the pillars of its template. The floors are joined by real stairs.
//
// Enemies follow a breadth-first step map from the player's cell (a
// roguelike "Dijkstra map") instead of walking through rock, and spawn out of
// reach on the player's floor. Enemies on the player's tail follow between
// floors; the rest of a floor's horde is dropped when the player leaves it
// (bosses are brought along). The Amulet, carried out of floor 1's stairs
// up, wins the run. Part of DSP030VerticalSlice.

// Spikes in a pit (presentation only; the damage is DgTick's).
class DSDungeonSpikes : DSDecor
{
    Default { Scale 1.3; }
    States { Spawn: DSPK A -1; Stop; }
}

extend class DSP030VerticalSlice
{
    // Difficulty (guesses, tuned by playtest): enemy health grows +35% per
    // depth below the first (on top of the stage's x1.3), contact damage is
    // x1.25 and grows +10% per depth, and enemies spawn 6-14 steps away.
    const DG_DEPTH_HEALTH_MILLI = 350;
    const DG_POWER_MILLI = 1250;
    const DG_DEPTH_POWER_MILLI = 100;
    const DG_SPAWN_NEAR = 6;
    const DG_SPAWN_FAR = 14;
    // Spike pits: 20% of maximum health on entering, again every half second.
    const DG_SPIKE_PCT = 20;
    const DG_SPIKE_TICS = 17;
    const DG_PIT_DEPTH = 24.0;
    // Half size of an enemy's body against rock, in map units.
    const DG_BODY = 20.0;
    // The stairs down (or the Amulet) count as found within this many steps.
    const DG_SPOT_STEPS = 14;
    // Enemies on another floor this close by walking keep following.
    const DG_FOLLOW_STEPS = 24;
    // How far the step map reaches from the player.
    const DG_BFS_STEPS = 48;
    // Cells this many steps from the player count as explored.
    const DG_SEE_STEPS = 8;
    // Enemy steering: straight chase when they can see the player within this
    // many steps, a look-ahead of this many cells along the step map, a
    // re-plan every few tics (staggered per enemy), and turning inertia.
    const DG_SIGHT_STEPS = 18;
    const DG_LOOKAHEAD = 8;
    const DG_REPLAN_TICS = 4;
    const DG_INERTIA = 0.6;
    // Chance (%) that a spare connection between two planned rooms is opened.
    const DG_LOOP_PCT = 35;

    // ---- geometry helpers ---------------------------------------------------------

    clearscope static int DgSlot(int k, int c, int r) { return k * DSDungeon.SX * DSDungeon.SY + r * DSDungeon.SX + c; }
    clearscope static int DgCol(int g) { return (g % (DSDungeon.SX * DSDungeon.SY)) % DSDungeon.SX; }
    clearscope static int DgRow(int g) { return (g % (DSDungeon.SX * DSDungeon.SY)) / DSDungeon.SX; }

    // The room slot next to g in a direction (0 E, 1 N, 2 W, 3 S), or -1.
    clearscope static int DgNeighbour(int g, int dir)
    {
        int c = DgCol(g); int r = DgRow(g);
        if (dir == 0) return c + 1 < DSDungeon.SX ? g + 1 : -1;
        if (dir == 1) return r + 1 < DSDungeon.SY ? g + DSDungeon.SX : -1;
        if (dir == 2) return c > 0 ? g - 1 : -1;
        return r > 0 ? g - DSDungeon.SX : -1;
    }

    // Floors lie west to east; a staircase cell belongs to the nearer floor.
    clearscope static int DgFloorOfCell(int c)
    {
        int span = DSDungeon.FLOOR_W + DSDungeon.GAP_FLOORS;
        int off = c % DSDungeon.W - DSDungeon.MARGIN;
        if (off < 0) return 0;
        int k = off / span;
        if (off % span >= DSDungeon.FLOOR_W + DSDungeon.GAP_FLOORS / 2) k++;
        return clamp(k, 0, DSDungeon.FLOORS - 1);
    }

    clearscope int DgCellAt(double px, double py)
    {
        int i = int(floor((px - DSDungeon.OX) / DSDungeon.CELL));
        int j = int(floor((py - DSDungeon.OY) / DSDungeon.CELL));
        if (i < 0 || j < 0 || i >= DSDungeon.W || j >= DSDungeon.H) return -1;
        return j * DSDungeon.W + i;
    }

    bool DgOpen(double px, double py)
    {
        int c = DgCellAt(px, py);
        return c >= 0 && c < dgCells.Size() && (dgCells[c] == 1 || dgCells[c] == 2);
    }

    bool DgFits(double px, double py)
    {
        return DgOpen(px - DG_BODY, py - DG_BODY) && DgOpen(px + DG_BODY, py - DG_BODY)
            && DgOpen(px - DG_BODY, py + DG_BODY) && DgOpen(px + DG_BODY, py + DG_BODY);
    }

    static bool DgRaised(int tpl, int block)
    {
        return DSDungeon.TEMPLATES[tpl].ByteAt(block) == 88;   // 'X'
    }

    static bool DgPit(int tpl, int block)
    {
        return DSDungeon.TEMPLATES[tpl].ByteAt(block) == 80;   // 'P'
    }

    // A walkable floor block (not a pillar or a pit).
    static bool DgFloorBlock(int tpl, int block)
    {
        return !DgRaised(tpl, block) && !DgPit(tpl, block);
    }

    // The centre of the room's open block nearest its middle.
    void DgRoomSpot(int g, out double sx, out double sy)
    {
        int best = 12; int bestD = 99;
        for (int b = 0; b < 25; b++)
        {
            if (!DgFloorBlock(dgTemplate[g], b)) continue;
            int d = abs(b % 5 - 2) + abs(b / 5 - 2);
            if (d < bestD) { best = b; bestD = d; }
        }
        sx = DSDungeon.OX + (DSDungeon.ROOM_X[g] + 2 * (best % 5) + 1) * DSDungeon.CELL;
        sy = DSDungeon.OY + (DSDungeon.ROOM_Y[g] + 2 * (best / 5) + 1) * DSDungeon.CELL;
    }

    // The room slot whose box holds a cell, or -1.
    int DgRoomOfCell(int c)
    {
        int i = c % DSDungeon.W; int j = c / DSDungeon.W;
        int k = DgFloorOfCell(c);
        for (int g = DgSlot(k, 0, 0); g < DgSlot(k + 1, 0, 0); g++)
        {
            int rx = DSDungeon.ROOM_X[g]; int ry = DSDungeon.ROOM_Y[g];
            if (i >= rx && i < rx + 10 && j >= ry && j < ry + 10) return g;
        }
        return -1;
    }

    // ---- the run's plan -----------------------------------------------------------

    void DgReset()
    {
        dgActive = mfEnabled && level.MapName == "MAP53";
        for (int i = 0; i < dgDecor.Size(); i++) if (dgDecor[i] != null) dgDecor[i].Destroy();
        dgDecor.Clear();
        if (dgAmuletActor != null) dgAmuletActor.Destroy();
        dgAmuletActor = null;
        dgCells.Clear(); dgDist.Clear(); dgQueue.Clear(); dgSeen.Clear(); dgPlan.Clear(); dgTemplate.Clear();
        dgAimX.Clear(); dgAimY.Clear(); dgAimMode.Clear(); dgDirX.Clear(); dgDirY.Clear();
        CVar fullMap = CVar.FindCVar("ds_dg_fullmap");
        if (fullMap != null) fullMap.SetInt(0);
        dgConnOpen.Clear(); dgStart.Clear(); dgDown.Clear(); dgKnown.Clear(); dgLastX.Clear(); dgLastY.Clear();
        dgDepth = 0; dgDeepest = 0; dgPlayerCell = -1; dgSpikeNext = 0; dgSpikeWarned = false;
        dgAmulet = false; dgEscaped = false; dgExitWarned = false;
        if (!dgActive) return;
        for (int g = 0; g < DSDungeon.SLOTS; g++) { dgPlan.Push(0); dgTemplate.Push(0); }
        for (int c = 0; c < DSDungeon.CONN_COUNT; c++) dgConnOpen.Push(0);
        int row = Random[DSDungeon](0, DSDungeon.SY - 1);
        for (int k = 0; k < DSDungeon.FLOORS; k++)
        {
            int start = DgSlot(k, 0, row);
            dgStart.Push(start); dgKnown.Push(0);
            int down = DgPlanFloor(k, start);
            dgDown.Push(down);
            if (down >= 0) { dgConnOpen[down] = 1; row = DgRow(DSDungeon.CONN_A[down]); }
        }
        int exitConn = DSDungeon.SLOT_CONN[dgStart[0] * 4 + 2];
        if (exitConn >= 0) dgConnOpen[exitConn] = 1;
        DgLoadGrid();
        double sx; double sy; DgRoomSpot(dgStart[0], sx, sy);
        DgPutPlayer(sx, sy);
        DgApplySectors();
        DgSpawnDecor();
        DgBfs();
        String rooms = "";
        for (int k = 0; k < DSDungeon.FLOORS; k++)
        {
            int count = 0;
            for (int g = DgSlot(k, 0, 0); g < DgSlot(k + 1, 0, 0); g++) if (dgPlan[g] != 0) count++;
            rooms = rooms .. String.Format("%s%d", k > 0 ? "," : "", count);
        }
        Console.Printf("DS_DUNGEON_START rooms=%s", rooms);
    }

    // Grows one floor's plan; returns the stairs connector down (-1 on the bottom).
    int DgPlanFloor(int k, int start)
    {
        int n = DSDungeon.SX * DSDungeon.SY;
        int base = k * n;
        bool bottom = k == DSDungeon.FLOORS - 1;
        int target = 7 + k;
        Array<int> plan; Array<int> queue; Array<int> edges;
        bool ok = false;
        for (int attempt = 0; attempt < 300 && !ok; attempt++)
        {
            plan.Clear(); queue.Clear(); edges.Clear();
            for (int i = 0; i < n; i++) plan.Push(0);
            plan[start - base] = 1; queue.Push(start);
            int count = 1;
            for (int head = 0; head < queue.Size(); head++)
            {
                int g = queue[head];
                int turn = Random[DSDungeon](0, 3);
                for (int t = 0; t < 4; t++)
                {
                    int dir = (t + turn) % 4;
                    int nb = DgNeighbour(g, dir);
                    if (nb < 0 || plan[nb - base] != 0 || count >= target) continue;
                    int filled = 0;
                    for (int d2 = 0; d2 < 4; d2++)
                    {
                        int nn = DgNeighbour(nb, d2);
                        if (nn >= 0 && plan[nn - base] != 0) filled++;
                    }
                    if (filled > 1 || Random[DSDungeon](0, 1) == 0) continue;
                    plan[nb - base] = 1; count++;
                    queue.Push(nb); edges.Push(DSDungeon.SLOT_CONN[g * 4 + dir]);
                }
            }
            ok = count >= target;
            if (ok && !bottom)
            {
                bool east = false;
                for (int r = 0; r < DSDungeon.SY; r++) if (plan[DgSlot(k, DSDungeon.SX - 1, r) - base] != 0) east = true;
                ok = east;
            }
        }
        if (!ok)
        {
            // Fallback (rare): a straight row east from the start.
            for (int c = 1; c < DSDungeon.SX; c++)
            {
                int g = DgSlot(k, c, DgRow(start));
                if (plan[g - base] == 0) { plan[g - base] = 1; edges.Push(DSDungeon.SLOT_CONN[(g - 1) * 4]); }
            }
        }
        // Loops: open some spare connections between planned neighbours.
        for (int g = base; g < base + n; g++)
        {
            if (plan[g - base] == 0) continue;
            for (int dir = 0; dir < 2; dir++)
            {
                int nb = DgNeighbour(g, dir);
                if (nb < 0 || plan[nb - base] == 0) continue;
                int conn = DSDungeon.SLOT_CONN[g * 4 + dir];
                if (edges.Find(conn) < edges.Size()) continue;
                if (Random[DSDungeon](0, 99) < DG_LOOP_PCT) edges.Push(conn);
            }
        }
        for (int i = 0; i < edges.Size(); i++) dgConnOpen[edges[i]] = 1;
        for (int g = base; g < base + n; g++)
        {
            if (plan[g - base] == 0) continue;
            dgPlan[g] = g == start ? 1 : 3;
            dgTemplate[g] = g == start ? 0 : Random[DSDungeon](0, DSDungeon.TEMPLATE_COUNT - 1);
        }
        // Walking distance in rooms from the start, and the dead ends.
        Array<int> dist;
        for (int i = 0; i < n; i++) dist.Push(-1);
        queue.Clear(); queue.Push(start); dist[start - base] = 0;
        for (int head = 0; head < queue.Size(); head++)
        {
            int g = queue[head];
            for (int dir = 0; dir < 4; dir++)
            {
                int nb = DgNeighbour(g, dir);
                if (nb < 0 || dist[nb - base] >= 0 || !dgConnOpen[DSDungeon.SLOT_CONN[g * 4 + dir]]) continue;
                dist[nb - base] = dist[g - base] + 1;
                queue.Push(nb);
            }
        }
        int goalRoom = -1;
        if (!bottom)
        {
            for (int r = 0; r < DSDungeon.SY; r++)
            {
                int g = DgSlot(k, DSDungeon.SX - 1, r);
                if (plan[g - base] != 0 && (goalRoom < 0 || dist[g - base] > dist[goalRoom - base])) goalRoom = g;
            }
        }
        for (int g = base; g < base + n; g++)
        {
            if (plan[g - base] == 0 || g == start || g == goalRoom) continue;
            int degree = 0;
            for (int dir = 0; dir < 4; dir++)
            {
                int nb = DgNeighbour(g, dir);
                if (nb >= 0 && dgConnOpen[DSDungeon.SLOT_CONN[g * 4 + dir]]) degree++;
            }
            if (degree == 1) dgPlan[g] = 2;   // a store room, found on first visit
        }
        if (!bottom) return DSDungeon.SLOT_CONN[goalRoom * 4];
        // Bottom floor: the Amulet in the farthest dead end (else the farthest room).
        for (int g = base; g < base + n; g++)
            if (dgPlan[g] == 2 && (goalRoom < 0 || dist[g - base] > dist[goalRoom - base])) goalRoom = g;
        if (goalRoom < 0)
            for (int g = base; g < base + n; g++)
                if (plan[g - base] != 0 && (goalRoom < 0 || dist[g - base] > dist[goalRoom - base])) goalRoom = g;
        dgPlan[goalRoom] = 1;
        DgRoomSpot(goalRoom, dgAmuletX, dgAmuletY);
        return -1;
    }

    void DgLoadGrid()
    {
        int w = DSDungeon.W;
        dgCells.Resize(w * DSDungeon.H); dgDist.Resize(w * DSDungeon.H); dgSeen.Resize(w * DSDungeon.H);
        for (int j = 0; j < DSDungeon.H; j++)
        {
            String row = DSDungeon.GRID[j];
            for (int i = 0; i < w; i++)
            {
                int ch = row.ByteAt(i);
                dgCells[j * w + i] = ch == 35 ? 0 : (ch == 69 ? 2 : 1);   // '#', 'E'
                dgDist[j * w + i] = -1;
                dgSeen[j * w + i] = 0;
            }
        }
        for (int c = 0; c < DSDungeon.CONN_COUNT; c++)
        {
            if (dgConnOpen[c]) continue;
            for (int k = DSDungeon.CONN_CELL0[c]; k < DSDungeon.CONN_CELL0[c + 1]; k++) dgCells[DSDungeon.CONN_CELLS[k]] = 0;
        }
        for (int g = 0; g < DSDungeon.SLOTS; g++)
        {
            for (int b = 0; b < 25; b++)
            {
                if (dgPlan[g] != 0 && DgFloorBlock(dgTemplate[g], b)) continue;
                // Pillars and unused rooms are rock (0); spike pits are 3.
                int v = dgPlan[g] != 0 && DgPit(dgTemplate[g], b) ? 3 : 0;
                int i0 = DSDungeon.ROOM_X[g] + 2 * (b % 5); int j0 = DSDungeon.ROOM_Y[g] + 2 * (b / 5);
                dgCells[j0 * w + i0] = v; dgCells[j0 * w + i0 + 1] = v;
                dgCells[(j0 + 1) * w + i0] = v; dgCells[(j0 + 1) * w + i0 + 1] = v;
            }
        }
    }

    static void DgMoveFloorTo(int index, double z)
    {
        Sector sec = level.Sectors[index];
        double cur = sec.floorplane.ZatPoint(sec.centerspot);
        if (abs(cur - z) < 0.5) return;
        // The engine's floor destination is the plane's distance term, which
        // for a floor is the height negated (ceilings take the height as is).
        sec.MoveFloor(abs(cur - z) + 1.0, -z, -1, z > cur ? 1 : -1, false, true);
    }

    static void DgMoveCeilingTo(int index, double z)
    {
        Sector sec = level.Sectors[index];
        double cur = sec.ceilingplane.ZatPoint(sec.centerspot);
        if (abs(cur - z) < 0.5) return;
        sec.MoveCeiling(abs(cur - z) + 1.0, z, -1, z > cur ? 1 : -1, false);
    }

    // Doors open or shut (ceiling down to the floor), room pillars up or down.
    // Every sector is set, so a retry without a map reload starts clean.
    void DgApplySectors()
    {
        for (int c = 0; c < DSDungeon.CONN_COUNT; c++)
        {
            bool open = dgConnOpen[c] != 0;
            DgMoveCeilingTo(DSDungeon.CONN_DOOR_A[c], open ? DSDungeon.CONN_CA[c] : DSDungeon.CONN_ZA[c]);
            if (DSDungeon.CONN_DOOR_B[c] != DSDungeon.CONN_DOOR_A[c])
                DgMoveCeilingTo(DSDungeon.CONN_DOOR_B[c], open ? DSDungeon.CONN_CB[c] : DSDungeon.CONN_ZB[c]);
        }
        TextureID stone = TexMan.CheckForTexture("TFLAGSTO", TexMan.Type_Any);
        TextureID spikeFloor = TexMan.CheckForTexture("TBONES", TexMan.Type_Any);
        for (int g = 0; g < DSDungeon.SLOTS; g++)
        {
            double z = -DSDungeon.FLOOR_DZ * (g / (DSDungeon.SX * DSDungeon.SY));
            int light = Random[DSDungeon](136, 200);
            for (int b = 0; b < 25; b++)
            {
                int s = DSDungeon.ROOM_SECTOR0[g] + b;
                bool raised = dgPlan[g] != 0 && DgRaised(dgTemplate[g], b);
                bool pit = dgPlan[g] != 0 && DgPit(dgTemplate[g], b);
                DgMoveFloorTo(s, raised ? z + DSDungeon.ROOM_CEIL : (pit ? z - DG_PIT_DEPTH : z));
                level.Sectors[s].SetTexture(Sector.floor, pit ? spikeFloor : stone);
                if (dgPlan[g] != 0) level.Sectors[s].SetLightLevel(pit ? light - 40 : light);
            }
        }
    }

    // Small clutter could pass for a pickup, so it only lies against walls;
    // the middle of a room gets large furniture only.
    static String DgSmallPropName(int n)
    {
        switch (n)
        {
        case 0: return "DSDecoUrn";
        case 1: return "DSDecoSkull";
        case 2: return "DSDecoBonesA";
        case 3: return "DSDecoBonesB";
        case 4: return "DSDecoBooks";
        case 5: return "DSDecoGrave";
        }
        return "DSDecoRockA";
    }

    static String DgLargePropName(int n)
    {
        switch (n)
        {
        case 0: return "DSDecoStatue";
        case 1: return "DSDecoColumn";
        case 2: return "DSDecoTableRed";
        case 3: return "DSDecoTableWhite";
        }
        return "DSDecoLamp";
    }

    // Candelabra along the walls and a few props in each planned room.
    void DgSpawnDecor()
    {
        for (int g = 0; g < DSDungeon.SLOTS; g++)
        {
            if (dgPlan[g] == 0) continue;
            for (int b = 0; b < 25; b++)
            {
                if (DgPit(dgTemplate[g], b))
                {
                    // Four clusters of spikes per pit block.
                    for (int k = 0; k < 4; k++)
                    {
                        double sx = DSDungeon.OX + (DSDungeon.ROOM_X[g] + 2 * (b % 5) + k % 2 + 0.5) * DSDungeon.CELL;
                        double sy = DSDungeon.OY + (DSDungeon.ROOM_Y[g] + 2 * (b / 5) + k / 2 + 0.5) * DSDungeon.CELL;
                        double sz = level.PointInSector((sx, sy)).floorplane.ZatPoint((sx, sy));
                        dgDecor.Push(Actor.Spawn("DSDungeonSpikes", (sx, sy, sz), NO_REPLACE));
                    }
                    continue;
                }
                if (DgRaised(dgTemplate[g], b)) continue;
                int bi = b % 5; int bj = b / 5;
                bool doorway = (bi == 2 && (bj == 0 || bj == 4)) || (bj == 2 && (bi == 0 || bi == 4));
                bool edge = bi == 0 || bi == 4 || bj == 0 || bj == 4;
                double x = DSDungeon.OX + (DSDungeon.ROOM_X[g] + 2 * bi + 1) * DSDungeon.CELL;
                double y = DSDungeon.OY + (DSDungeon.ROOM_Y[g] + 2 * bj + 1) * DSDungeon.CELL;
                String kind = "";
                if (doorway) continue;
                if (edge)
                {
                    // Against the room's wall: candelabra, or clutter tucked
                    // into the wall line (corners take both offsets).
                    int roll = Random[DSDungeon](0, 99);
                    if (roll < 40) kind = "DSDecoCandelabra";
                    else if (roll < 75) kind = DgSmallPropName(Random[DSDungeon](0, 6));
                    double tuck = kind == "DSDecoCandelabra" ? 80.0 : 96.0;
                    x += bi == 0 ? -tuck : (bi == 4 ? tuck : Random[DSDungeon](-60, 60));
                    y += bj == 0 ? -tuck : (bj == 4 ? tuck : Random[DSDungeon](-60, 60));
                }
                else if (Random[DSDungeon](0, 99) < 25)
                {
                    kind = DgLargePropName(Random[DSDungeon](0, 4));
                    x += Random[DSDungeon](-30, 30); y += Random[DSDungeon](-30, 30);
                }
                if (kind == "") continue;
                double z = level.PointInSector((x, y)).floorplane.ZatPoint((x, y));
                dgDecor.Push(Actor.Spawn(kind, (x, y, z), NO_REPLACE));
            }
        }
    }

    void DgPutPlayer(double px, double py)
    {
        double z = level.PointInSector((px, py)).floorplane.ZatPoint((px, py));
        Actor mo = players[0].mo;
        if (mo != null) { mo.SetOrigin((px, py, z), false); mo.Vel = (0, 0, 0); }
        playerX = px; playerY = py;
        if (playerSlot >= 0 && playerSlot < x.Size()) { x[playerSlot] = px; y[playerSlot] = py; }
    }

    // ---- the step map, spawning and enemy motion ----------------------------------

    // Breadth-first steps from the player's cell, out to DG_BFS_STEPS.
    void DgBfs()
    {
        int start = DgCellAt(playerX, playerY);
        if (start < 0 || dgCells[start] == 0) return;   // keep the last map
        dgPlayerCell = start;
        int w = DSDungeon.W;
        for (int q = 0; q < dgQueue.Size(); q++) dgDist[dgQueue[q]] = -1;
        dgQueue.Clear();
        dgQueue.Push(start); dgDist[start] = 0;
        for (int head = 0; head < dgQueue.Size(); head++)
        {
            int c = dgQueue[head];
            int next = dgDist[c] + 1;
            if (next > DG_BFS_STEPS) continue;
            int ci = c % w;
            if (ci > 0) DgVisit(c - 1, next);
            if (ci < w - 1) DgVisit(c + 1, next);
            if (c >= w) DgVisit(c - w, next);
            if (c + w < dgCells.Size()) DgVisit(c + w, next);
        }
        // Explored: everything within a few steps, and every room entered.
        for (int q = 0; q < dgQueue.Size() && dgDist[dgQueue[q]] <= DG_SEE_STEPS; q++) dgSeen[dgQueue[q]] = 1;
        int room = DgRoomOfCell(start);
        if (room >= 0)
            for (int j = DSDungeon.ROOM_Y[room]; j < DSDungeon.ROOM_Y[room] + 10; j++)
                for (int i = DSDungeon.ROOM_X[room]; i < DSDungeon.ROOM_X[room] + 10; i++) dgSeen[j * w + i] = 1;
    }

    void DgVisit(int c, int steps)
    {
        if ((dgCells[c] == 1 || dgCells[c] == 2) && dgDist[c] < 0) { dgDist[c] = steps; dgQueue.Push(c); }
    }

    // A reachable open cell of the player's floor between near and far steps
    // away (widening if none turns up), with a little jitter inside it.
    void DgPlace(int nearSteps, int farSteps, out double sx, out double sy)
    {
        int n = dgQueue.Size();
        int w = DSDungeon.W;
        for (int pass = 0; pass < 3 && n > 0; pass++)
        {
            int lo = pass == 2 ? 2 : nearSteps / (pass + 1);
            int hi = farSteps * (pass + 1);
            for (int attempt = 0; attempt < 96; attempt++)
            {
                spawnRng = DSP022StageGeometry.NextSpawnRng(spawnRng);
                int c = dgQueue[(spawnRng & 0x7fffffff) % n];
                if (dgCells[c] != 1 || dgDist[c] < lo || dgDist[c] > hi || DgFloorOfCell(c) != dgDepth) continue;
                sx = DSDungeon.OX + (c % w + 0.5) * DSDungeon.CELL + ((spawnRng >> 8) & 63) - 32;
                sy = DSDungeon.OY + (c / w + 0.5) * DSDungeon.CELL + ((spawnRng >> 14) & 63) - 32;
                return;
            }
        }
        sx = playerX; sy = playerY;
    }

    // Is the straight line between two points free of rock? Walks the grid
    // cells the line crosses (pits count as rock: enemies go round them).
    bool DgClear(double x0, double y0, double x1, double y1)
    {
        double fx = (x0 - DSDungeon.OX) / DSDungeon.CELL; double fy = (y0 - DSDungeon.OY) / DSDungeon.CELL;
        double tx = (x1 - DSDungeon.OX) / DSDungeon.CELL; double ty = (y1 - DSDungeon.OY) / DSDungeon.CELL;
        int i = int(floor(fx)); int j = int(floor(fy));
        int ti = int(floor(tx)); int tj = int(floor(ty));
        double dx = tx - fx; double dy = ty - fy;
        int si = dx > 0 ? 1 : -1; int sj = dy > 0 ? 1 : -1;
        double stepX = abs(dx) > 0.000001 ? abs(1.0 / dx) : 1.0e9;
        double stepY = abs(dy) > 0.000001 ? abs(1.0 / dy) : 1.0e9;
        double nextX = abs(dx) > 0.000001 ? (dx > 0 ? i + 1 - fx : fx - i) * stepX : 1.0e9;
        double nextY = abs(dy) > 0.000001 ? (dy > 0 ? j + 1 - fy : fy - j) * stepY : 1.0e9;
        int w = DSDungeon.W;
        for (int n = 0; n < 96; n++)
        {
            if (i < 0 || j < 0 || i >= w || j >= DSDungeon.H) return false;
            int v = dgCells[j * w + i];
            if (v != 1 && v != 2) return false;
            if (i == ti && j == tj) return true;
            if (nextX < nextY) { nextX += stepX; i += si; }
            else { nextY += stepY; j += sj; }
        }
        return false;
    }

    void DgGrowSteer(int slot)
    {
        while (dgAimX.Size() <= slot)
        {
            dgAimX.Push(0.0); dgAimY.Push(0.0); dgAimMode.Push(-1);
            dgDirX.Push(0.0); dgDirY.Push(0.0);
        }
    }

    // Every few tics (staggered across the crowd) an enemy picks how to chase:
    // straight at the player when it can see them (mode 1), else towards the
    // farthest cell it can see along its way down the step map (mode 0).
    // Ties between equally good cells break per enemy, so crowds split.
    void DgPlanSteer(int slot, int c)
    {
        int w = DSDungeon.W;
        if (dgDist[c] <= 1 || (dgDist[c] <= DG_SIGHT_STEPS && DgClear(x[slot], y[slot], playerX, playerY)))
        {
            dgAimMode[slot] = 1;
            return;
        }
        Array<int> path;
        int cur = c;
        int salt = (ids[slot] * 7919 + (ids[slot] >> 3) * 104729) & 0x7fffffff;
        for (int step = 0; step < DG_LOOKAHEAD; step++)
        {
            int ci = cur % w; int cj = cur / w;
            int best = -1; int bestSteps = dgDist[cur]; int bestPref = 99;
            for (int k = 0; k < 8; k++)
            {
                int di = k < 3 ? k - 1 : (k == 3 ? -1 : (k == 4 ? 1 : k - 6));
                int dj = k < 3 ? -1 : (k < 5 ? 0 : 1);
                int ni = ci + di; int nj = cj + dj;
                if (ni < 0 || nj < 0 || ni >= w || nj >= DSDungeon.H) continue;
                int nc = nj * w + ni;
                int d = dgDist[nc];
                if (d < 0 || d > bestSteps) continue;
                if (di != 0 && dj != 0 && (dgCells[cj * w + ni] == 0 || dgCells[nj * w + ci] == 0 || dgCells[cj * w + ni] == 3 || dgCells[nj * w + ci] == 3)) continue;
                int pref = ((salt >> k) + k * 7) % 8;
                if (d < bestSteps || (d == bestSteps && best >= 0 && pref < bestPref))
                {
                    if (d == dgDist[cur] && best < 0) continue;   // never sideways when nothing is better yet
                    best = nc; bestSteps = d; bestPref = pref;
                }
            }
            if (best < 0) break;
            path.Push(best);
            cur = best;
            if (dgDist[cur] <= 0) break;
        }
        int count = path.Size();
        if (count == 0) { dgAimMode[slot] = 1; return; }
        int aim = path[0];
        for (int k = count - 1; k > 0; k--)
        {
            double px = DSDungeon.OX + (path[k] % w + 0.5) * DSDungeon.CELL;
            double py = DSDungeon.OY + (path[k] / w + 0.5) * DSDungeon.CELL;
            if (DgClear(x[slot], y[slot], px, py)) { aim = path[k]; break; }
        }
        dgAimMode[slot] = 0;
        dgAimX[slot] = DSDungeon.OX + (aim % w + 0.5) * DSDungeon.CELL + (salt & 31) - 16;
        dgAimY[slot] = DSDungeon.OY + (aim / w + 0.5) * DSDungeon.CELL + ((salt >> 5) & 31) - 16;
    }

    // Chasing enemies follow their plan with a little turning inertia, then
    // slide along rock. Enemies beyond the step map wait (DgKeepEnemies moves
    // or drops them).
    void DgMoveEnemy(int slot, double speed)
    {
        int c = DgCellAt(x[slot], y[slot]);
        if (c < 0 || dgDist[c] < 0) return;
        DgGrowSteer(slot);
        if (dgAimMode[slot] < 0 || (slot + tic) % DG_REPLAN_TICS == 0) DgPlanSteer(slot, c);
        double tx; double ty;
        if (dgAimMode[slot] == 1)
        {
            // Straight at the player, aiming at a personal point beside them
            // that closes in as the enemy nears, so a crowd surrounds rather
            // than marching in step.
            double ex = playerX - x[slot]; double ey = playerY - y[slot];
            double far = sqrt(ex * ex + ey * ey);
            double spread = clamp((far - 60.0) * 0.3, 0.0, 56.0);
            double angle = (ids[slot] * 137.508) % 360.0;
            tx = playerX + cos(angle) * spread; ty = playerY + sin(angle) * spread;
        }
        else { tx = dgAimX[slot]; ty = dgAimY[slot]; }
        double dx = tx - x[slot]; double dy = ty - y[slot];
        double distance = sqrt(dx * dx + dy * dy);
        if (distance < 0.00001) return;
        dx /= distance; dy /= distance;
        // Turning inertia: blend with last tic's heading.
        double hx = dgDirX[slot] * DG_INERTIA + dx * (1.0 - DG_INERTIA);
        double hy = dgDirY[slot] * DG_INERTIA + dy * (1.0 - DG_INERTIA);
        double h = sqrt(hx * hx + hy * hy);
        if (h < 0.05) { hx = dx; hy = dy; } else { hx /= h; hy /= h; }
        dgDirX[slot] = hx; dgDirY[slot] = hy;
        double amount = speed < distance ? speed : distance;
        double nx = x[slot] + hx * amount;
        double ny = y[slot] + hy * amount;
        if (DgFits(nx, ny)) { x[slot] = nx; y[slot] = ny; }
        else if (DgFits(nx, y[slot])) x[slot] = nx;
        else if (DgFits(x[slot], ny)) y[slot] = ny;
        else if (DgOpen(nx, ny)) { x[slot] = nx; y[slot] = ny; }
        else dgAimMode[slot] = -1;   // stuck: plan afresh next tic
    }

    void DgRemember(int slot)
    {
        while (dgLastX.Size() <= slot) { dgLastX.Push(0.0); dgLastY.Push(0.0); }
        dgLastX[slot] = x[slot]; dgLastY[slot] = y[slot];
    }

    void DgDrop(int slot)
    {
        mfStable[slot] = 0;
        DestroyParts(slot, generations[slot], ids[slot]);
    }

    // ---- goals and HUD ------------------------------------------------------------

    clearscope bool DgIsGoalKnown()
    {
        return dgAmulet || (dgDepth >= 0 && dgDepth < dgKnown.Size() && dgKnown[dgDepth] != 0);
    }

    clearscope String DgGoalText()
    {
        String depth = String.Format("Depth %d of %d", dgDepth + 1, DSDungeon.FLOORS);
        if (dgAmulet) return depth .. (dgDepth == 0 ? " - you carry the Amulet: take the stairs out" : " - you carry the Amulet: climb back up");
        if (dgDepth == DSDungeon.FLOORS - 1) return depth .. (DgIsGoalKnown() ? " - the Amulet is near" : " - find the Amulet");
        return depth .. (DgIsGoalKnown() ? " - the stairs down are near" : " - find the stairs down");
    }

    // Where the HUD arrow points: the way up with the Amulet, otherwise the
    // stairs down or the Amulet once seen.
    clearscope bool DgGoal(out double gx, out double gy)
    {
        if (dgStart.Size() == 0) return false;
        if (dgAmulet)
        {
            if (dgDepth == 0)
            {
                int exitConn = DSDungeon.SLOT_CONN[dgStart[0] * 4 + 2];
                gx = DSDungeon.CONN_BX[exitConn]; gy = DSDungeon.CONN_BY[exitConn];
            }
            else { gx = DSDungeon.CONN_BX[dgDown[dgDepth - 1]]; gy = DSDungeon.CONN_BY[dgDown[dgDepth - 1]]; }
            return true;
        }
        if (!DgIsGoalKnown()) return false;
        if (dgDepth == DSDungeon.FLOORS - 1) { gx = dgAmuletX; gy = dgAmuletY; return true; }
        gx = DSDungeon.CONN_AX[dgDown[dgDepth]]; gy = DSDungeon.CONN_AY[dgDown[dgDepth]];
        return true;
    }

    void DgEnterFloor(int depth)
    {
        bool up = depth < dgDepth;
        dgDepth = depth;
        dgDeepest = max(dgDeepest, depth);
        if (up) dgKnown[depth] = 1;   // its stairs down are the ones just climbed
        Sfx(up ? DSSfx.E_STAIRS_UP : DSSfx.E_STAIRS_DOWN, 20);
        if (!up && depth == DSDungeon.FLOORS - 1) GmShowToast(String.Format("Depth %d: the Amulet lies somewhere on this floor", depth + 1));
        else GmShowToast(String.Format("Depth %d", depth + 1));
        Console.Printf("DS_DUNGEON_FLOOR tic=%d depth=%d amulet=%d", tic, depth + 1, dgAmulet ? 1 : 0);
    }

    // ---- per tic ------------------------------------------------------------------

    void DgTick()
    {
        if (!dgActive || runState != STATE_ACTIVE || dgCells.Size() == 0) return;
        CVar dbg = CVar.FindCVar("ds_dg_debug");
        if (dbg != null && dbg.GetInt() == 3 && (tic == 175 || tic == 525)) DgDebugVisit(tic == 525);
        else if (dbg != null && dbg.GetInt() != 0 && dbg.GetInt() != 3 && tic % 350 == 175) DgDebugHop();
        if (dbg != null && dbg.GetInt() == 2 && tic % 350 == 270)
        {
            CVar fullMap = CVar.FindCVar("ds_dg_fullmap");
            if (fullMap != null) fullMap.SetInt((tic / 350) % 2);
        }
        if (dbg != null && dbg.GetInt() >= 2 && tic % 350 == 280)
        {
            Actor mo = players[0].mo;
            if (mo != null)
            {
                int pcell = DgCellAt(mo.pos.x, mo.pos.y);
                Console.Printf("DS_DUNGEON_SHOT tic=%d x=%.0f y=%.0f z=%.1f floorz=%.1f ceilingz=%.1f cell=%d open=%d room=%d pitch=%.1f",
                    tic, mo.pos.x, mo.pos.y, mo.pos.z, mo.floorz, mo.ceilingz, pcell, pcell >= 0 ? dgCells[pcell] : -1,
                    pcell >= 0 ? DgRoomOfCell(pcell) : -1, mo.pitch);
            }
            LevelLocals.MakeScreenShot();
        }
        int pc = DgCellAt(playerX, playerY);
        if (pc >= 0 && dgCells[pc] != 0 && pc != dgPlayerCell)
        {
            DgBfs();
            int k = DgFloorOfCell(pc);
            if (k != dgDepth) DgEnterFloor(k);
            int room = DgRoomOfCell(pc);
            if (room >= 0 && dgPlan[room] == 2) DgOpenStore(room);
            else if (room >= 0 && dgPlan[room] == 3) DgFirstVisit(room);
        }

        if (pc >= 0 && dgCells[pc] == 3 && tic >= dgSpikeNext)
        {
            dgSpikeNext = tic + DG_SPIKE_TICS;
            if (!dgSpikeWarned) GmShowToast("Spikes!");
            dgSpikeWarned = true;
            Sfx(DSSfx.E_SPIKES, 8);
            DgHurtPlayer(CurrentPlayerHealthCap() * DG_SPIKE_PCT / 100);
            if (runState != STATE_ACTIVE) return;
        }

        // Floor 1's stairs out: the run is won with the Amulet.
        if (pc >= 0 && dgCells[pc] == 2)
        {
            if (dgAmulet)
            {
                dgEscaped = true;
                GmShowToast("You escaped the Depths with the Amulet!");
                Console.Printf("DS_DUNGEON_ESCAPE tic=%d", tic);
                EndRun("DUNGEON_ESCAPE");
                return;
            }
            if (!dgExitWarned) GmShowToast("The way out. Bring back the Amulet from the bottom floor.");
            dgExitWarned = true;
        }
        else dgExitWarned = false;

        bool bottom = dgDepth == DSDungeon.FLOORS - 1;
        if (dgKnown[dgDepth] == 0)
        {
            int goal = bottom ? DgCellAt(dgAmuletX, dgAmuletY)
                : DgCellAt(DSDungeon.CONN_AX[dgDown[dgDepth]], DSDungeon.CONN_AY[dgDown[dgDepth]]);
            if (goal >= 0 && dgDist[goal] >= 0 && dgDist[goal] <= DG_SPOT_STEPS)
            {
                dgKnown[dgDepth] = 1;
                GmShowToast(bottom ? "You sense the Amulet nearby" : "You spot the stairs down");
                Sfx(DSSfx.E_DISCOVER, 35);
            }
        }
        if (bottom && !dgAmulet)
        {
            double ax = dgAmuletX - playerX; double ay = dgAmuletY - playerY;
            if (ax * ax + ay * ay <= 64.0 * 64.0)
            {
                dgAmulet = true;
                Sfx(DSSfx.I_AMULET);
                GmShowToast("The Amulet is yours! Climb back to the surface.");
                Console.Printf("DS_DUNGEON_AMULET tic=%d", tic);
            }
        }
        DgKeepEnemies();
    }

    // Enemies never stay in rock. Those on the player's floor beyond the step
    // map, and bosses left behind, come back out of reach on the player's
    // floor; ordinary enemies left on another floor (not on the player's
    // tail) and light sources there are dropped, so floors never stack up.
    void DgKeepEnemies()
    {
        for (int slot = 0; slot < lifeStates.Size(); slot++)
        {
            if (lifeStates[slot] != STORE_ALIVE || kinds[slot] != KIND_ENEMY || !MFValid(slot)) continue;
            if (DSStage.IsReaperLike(mfTypes[slot])) continue;
            int c = DgCellAt(x[slot], y[slot]);
            if (c < 0 || dgCells[c] == 0)
            {
                if (slot < dgLastX.Size() && DgOpen(dgLastX[slot], dgLastY[slot])) { x[slot] = dgLastX[slot]; y[slot] = dgLastY[slot]; }
                else { double sx; double sy; DgPlace(7, 16, sx, sy); x[slot] = sx; y[slot] = sy; DgRemember(slot); }
                continue;
            }
            DgRemember(slot);
            bool here = DgFloorOfCell(c) == dgDepth;
            if (MFIsProp(mfTypes[slot])) { if (!here) DgDrop(slot); continue; }
            int steps = dgDist[c];
            if (steps >= 0 && (here || steps <= DG_FOLLOW_STEPS)) continue;
            if (here || mfBoss[slot] > 0)
            {
                double sx; double sy; DgPlace(DG_SPAWN_NEAR, DG_SPAWN_FAR, sx, sy);
                x[slot] = sx; y[slot] = sy; DgRemember(slot);
            }
            else DgDrop(slot);
        }
    }

    // A random walkable block centre of a room, kept off its middle block.
    void DgRandomSpot(int g, out double sx, out double sy)
    {
        int b = 12;
        for (int attempt = 0; attempt < 20; attempt++)
        {
            b = Random[DSDungeon](0, 24);
            if (b != 12 && DgFloorBlock(dgTemplate[g], b)) break;
        }
        sx = DSDungeon.OX + (DSDungeon.ROOM_X[g] + 2 * (b % 5) + 1) * DSDungeon.CELL + Random[DSDungeon](-50, 50);
        sy = DSDungeon.OY + (DSDungeon.ROOM_Y[g] + 2 * (b / 5) + 1) * DSDungeon.CELL + Random[DSDungeon](-50, 50);
    }

    void DgSpawnLight(int g)
    {
        double sx; double sy; DgRandomSpot(g, sx, sy);
        int slot = MFSpawn(MF_BRAZIER_TYPE, sx, sy, 2, 0.0, 0.0, 0, 0);
        if (slot >= 0) collisionRadii[slot] = 4.0;
    }

    // An ordinary room's first visit: one or two light sources (they drop
    // floor pickups when broken, as on the other stages).
    void DgFirstVisit(int room)
    {
        dgPlan[room] = 1;
        int lights = Random[DSDungeon](1, 2);
        for (int i = 0; i < lights; i++) DgSpawnLight(room);
    }

    // A dead end's store room: a chest, three light sources and often a
    // weapon or passive lying on the floor (a stage item).
    void DgOpenStore(int room)
    {
        dgPlan[room] = 1;
        double cx; double cy; DgRoomSpot(room, cx, cy);
        int items = Random[DSDungeon](0, 99) < 20 ? 3 : 1;
        if (ArcanaOwned(DSArcana.GAME_KILLER) && items < 3) items = 3;
        int chest = MFSpawnChestAt(items, int(cx), int(cy));
        for (int i = 0; i < 3; i++) DgSpawnLight(room);
        bool item = Random[DSDungeon](0, 99) < 60;
        if (item)
        {
            double ix; double iy; DgRandomSpot(room, ix, iy);
            gmItemId.Push(DSStageGimmicks.ITEM_ID[Random[DSDungeon](0, DSStageGimmicks.ItemCount() - 1)]);
            gmItemX.Push(ix); gmItemY.Push(iy); gmItemActor.Push(null);
        }
        GmShowToast(item ? "A treasure room!" : "A forgotten store room");
        Sfx(item ? DSSfx.E_TREASURE_ROOM : DSSfx.E_STORE_ROOM);
        Console.Printf("DS_DUNGEON_STORE tic=%d room=%d chest=%d item=%d", tic, room, chest, item ? 1 : 0);
    }

    // Spike pits hurt whoever stands in them; armour does not help.
    void DgHurtPlayer(int amount)
    {
        if (playerHealth <= 0 || amount <= 0) return;
        bool reviving = rsActive && rsRevivalsUsed < rsRevivalsGranted && amount >= playerHealth && playerHealth > 1;
        if (reviving) amount = playerHealth - 1;
        playerHealth = max(0, playerHealth - amount);
        health[playerSlot] = playerHealth;
        Sfx(DSSfx.HURT, 12);
        Console.Printf("DS_DUNGEON_SPIKES tic=%d damage=%d health_after=%d", tic, amount, playerHealth);
        if (reviving) RevivePlayer();
        if (playerHealth > 0) return;
        if (configuredMode == "harness" || configuredMode == "soak" || configuredMode == "soak_n2")
        {
            playerHealth = CurrentPlayerHealthCap();   // automation aid, as for contact damage
            health[playerSlot] = playerHealth;
            return;
        }
        EndRun("PLAYER_ZERO_HEALTH");
    }

    // ds_dg_debug 3: visit a store room on this floor, then stand in a spike
    // pit (test aid only).
    void DgDebugVisit(bool pit)
    {
        for (int g = DgSlot(dgDepth, 0, 0); g < DgSlot(dgDepth + 1, 0, 0); g++)
        {
            if (dgPlan[g] == 0) continue;
            for (int b = 0; b < 25; b++)
            {
                if (pit ? !DgPit(dgTemplate[g], b) : (dgPlan[g] != 2 || b != 12)) continue;
                double sx = DSDungeon.OX + (DSDungeon.ROOM_X[g] + 2 * (b % 5) + 1) * DSDungeon.CELL;
                double sy = DSDungeon.OY + (DSDungeon.ROOM_Y[g] + 2 * (b / 5) + 1) * DSDungeon.CELL;
                if (!pit) { double rx; double ry; DgRoomSpot(g, rx, ry); sx = rx - 300.0; sy = ry; }
                DgPutPlayer(sx, sy);
                Console.Printf("DS_DUNGEON_DEBUG_VISIT tic=%d room=%d pit=%d", tic, g, pit ? 1 : 0);
                return;
            }
        }
        Console.Printf("DS_DUNGEON_DEBUG_VISIT tic=%d none pit=%d", tic, pit ? 1 : 0);
    }

    // ds_dg_debug: put the player past the next goal (test aid only).
    void DgDebugHop()
    {
        if (dgAmulet)
        {
            if (dgDepth == 0)
            {
                int exitConn = DSDungeon.SLOT_CONN[dgStart[0] * 4 + 2];
                DgPutPlayer(DSDungeon.CONN_BX[exitConn], DSDungeon.CONN_BY[exitConn]);
            }
            else
            {
                double sx; double sy; DgRoomSpot(DSDungeon.CONN_A[dgDown[dgDepth - 1]], sx, sy);
                DgPutPlayer(sx, sy);
            }
        }
        else if (dgDepth == DSDungeon.FLOORS - 1) DgPutPlayer(dgAmuletX, dgAmuletY);
        else
        {
            double sx; double sy; DgRoomSpot(dgStart[dgDepth + 1], sx, sy);
            DgPutPlayer(sx, sy);
        }
    }

    // Stair rings and the Amulet (presentation only; from GmSyncActors).
    void DgSyncActors()
    {
        if (!dgActive || dgStart.Size() == 0) return;
        bool bottom = dgDepth == DSDungeon.FLOORS - 1;
        if (!bottom)
        {
            int down = dgDown[dgDepth];
            FxKeep(8601, "WRNG", DSDungeon.CONN_AX[down], DSDungeon.CONN_AY[down], 1.2, 240.0, true, Color(255, 120, 40), 0.7);
        }
        if (dgDepth == 0)
        {
            int exitConn = DSDungeon.SLOT_CONN[dgStart[0] * 4 + 2];
            FxKeep(8600, "WRNG", DSDungeon.CONN_BX[exitConn], DSDungeon.CONN_BY[exitConn], 1.2, 240.0, true,
                dgAmulet ? Color(120, 220, 255) : Color(110, 110, 120), 0.6);
        }
        bool showAmulet = bottom && !dgAmulet;
        if (showAmulet)
        {
            FxKeep(8602, "WRNG", dgAmuletX, dgAmuletY, 1.2, 140.0, true, Color(255, 220, 90), 0.7);
            if (dgAmuletActor == null)
            {
                DSStageItemProxy p = DSStageItemProxy(Actor.Spawn("DSStageItemProxy", (dgAmuletX, dgAmuletY, 24.0), NO_REPLACE));
                if (p != null) { p.sprite = Actor.GetSpriteIndex("I010"); p.baseZ = 24.0; p.A_SetScale(1.4); }
                dgAmuletActor = p;
            }
        }
        else if (dgAmuletActor != null)
        {
            dgAmuletActor.Destroy();
            dgAmuletActor = null;
        }
    }
    // ---- minimap and full map (presentation only) ----------------------------------

    // Explored open cells, drawn as horizontal runs. i0..i1 and j0..j1 are
    // the cells shown; (vx, vy) the top-left corner in virtual 640x400 units
    // and cs the size of a cell there. North is up.
    ui void DgDrawCells(int i0, int i1, int j0, int j1, double vx, double vy, double cs, double alpha)
    {
        double s = DSShellMenu.Scale();
        double ox = DSShellMenu.OffX(); double oy = DSShellMenu.OffY();
        int w = DSDungeon.W;
        if (dgSeen.Size() < w * DSDungeon.H) return;
        for (int j = max(j0, 0); j <= min(j1, DSDungeon.H - 1); j++)
        {
            int y0 = int(oy + (vy + (j1 - j) * cs) * s); int y1 = int(oy + (vy + (j1 - j + 1) * cs) * s);
            int i = max(i0, 0);
            int last = min(i1, w - 1);
            while (i <= last)
            {
                int c = j * w + i;
                int kind = dgSeen[c] != 0 ? dgCells[c] : 0;
                if (kind == 0) { i++; continue; }
                int start = i;
                while (i <= last && (dgSeen[j * w + i] != 0 ? dgCells[j * w + i] : 0) == kind) i++;
                int x0 = int(ox + (vx + (start - i0) * cs) * s); int x1 = int(ox + (vx + (i - i0) * cs) * s);
                Screen.Dim(kind == 2 ? Color(120, 220, 255) : (kind == 3 ? Color(150, 30, 30) : Color(150, 140, 125)), alpha, x0, y0, max(1, x1 - x0), max(1, y1 - y0));
            }
        }
    }

    // A square dot at a map position, if it lies in the drawn window.
    ui void DgDot(double px, double py, int i0, int i1, int j0, int j1, double vx, double vy, double cs, double size, Color c)
    {
        double fi = (px - DSDungeon.OX) / DSDungeon.CELL; double fj = (py - DSDungeon.OY) / DSDungeon.CELL;
        if (fi < i0 || fi > i1 + 1 || fj < j0 || fj > j1 + 1) return;
        double s = DSShellMenu.Scale();
        double dx = DSShellMenu.OffX() + (vx + (fi - i0) * cs) * s;
        double dy = DSShellMenu.OffY() + (vy + (j1 + 1 - fj) * cs) * s;
        int half = max(1, int(size * s / 2));
        Screen.Dim(c, 1.0, int(dx) - half, int(dy) - half, half * 2, half * 2);
    }

    ui void DgDrawMarkers(int i0, int i1, int j0, int j1, double vx, double vy, double cs, double mark)
    {
        // Enemies (bosses larger), then the goals, then the player on top.
        for (int slot = 0; slot < lifeStates.Size(); slot++)
        {
            if (lifeStates[slot] != STORE_ALIVE || kinds[slot] != KIND_ENEMY) continue;
            if (slot >= mfStable.Size() || ids[slot] == 0 || mfStable[slot] != ids[slot]) continue;
            if (mfTypes[slot] >= MF_BRAZIER_TYPE && mfTypes[slot] <= MF_CART_TYPE) continue;   // light sources and props (MFIsProp)
            bool big = mfBoss[slot] > 0 || DSStage.IsBig(mfTypes[slot]) != 0;
            DgDot(x[slot], y[slot], i0, i1, j0, j1, vx, vy, cs, big ? mark * 2.0 : mark, big ? Color(255, 60, 200) : Color(230, 40, 40));
        }
        if (dgStart.Size() > 0)
        {
            if (dgDepth < DSDungeon.FLOORS - 1 && DgIsGoalKnown())
            {
                int down = dgDown[dgDepth];
                DgDot(DSDungeon.CONN_AX[down], DSDungeon.CONN_AY[down], i0, i1, j0, j1, vx, vy, cs, mark * 2.5, Color(255, 140, 40));
            }
            if (dgDepth == DSDungeon.FLOORS - 1 && !dgAmulet && DgIsGoalKnown())
                DgDot(dgAmuletX, dgAmuletY, i0, i1, j0, j1, vx, vy, cs, mark * 2.5, Color(255, 220, 60));
            if (dgDepth > 0)
            {
                int up = dgDown[dgDepth - 1];
                DgDot(DSDungeon.CONN_BX[up], DSDungeon.CONN_BY[up], i0, i1, j0, j1, vx, vy, cs, mark * 2.5, Color(120, 220, 255));
            }
        }
        Actor mo = players[consoleplayer].mo;
        if (mo == null) return;
        double fi = (mo.pos.x - DSDungeon.OX) / DSDungeon.CELL; double fj = (mo.pos.y - DSDungeon.OY) / DSDungeon.CELL;
        double s = DSShellMenu.Scale();
        double px = DSShellMenu.OffX() + (vx + (fi - i0) * cs) * s;
        double py = DSShellMenu.OffY() + (vy + (j1 + 1 - fj) * cs) * s;
        double len = max(4.0, cs * 2.0) * s;
        Screen.DrawThickLine(int(px), int(py), int(px + cos(mo.angle) * len), int(py - sin(mo.angle) * len), max(1.0, s * 1.5), Color(255, 255, 255));
        int half = max(2, int(mark * 1.5 * s / 2));
        Screen.Dim(Color(255, 255, 255), 1.0, int(px) - half, int(py) - half, half * 2, half * 2);
    }

    // Top-right corner: the explored dungeon around the player, north up.
    ui void DgDrawMinimap()
    {
        int r = 12;
        double size = 120.0; double vx = 516.0; double vy = 54.0;
        double cs = size / (2 * r + 1);
        DSUi.Slice9("DSUISLOT", vx - 4, vy - 4, size + 8, size + 8, 4, 0.9);
        Actor mo = players[consoleplayer].mo;
        if (mo == null) return;
        int ci = int(floor((mo.pos.x - DSDungeon.OX) / DSDungeon.CELL));
        int cj = int(floor((mo.pos.y - DSDungeon.OY) / DSDungeon.CELL));
        DgDrawCells(ci - r, ci + r, cj - r, cj + r, vx, vy, cs, 0.9);
        DgDrawMarkers(ci - r, ci + r, cj - r, cj + r, vx, vy, cs, 2.0);
        DSShellMenu.Text(SmallFont, Font.CR_DARKGRAY, vx, vy + size + 4, "Tab: map", 0.9);
    }

    // Tab / M: the whole explored floor, scaled to fit the screen.
    ui void DgDrawFullMap()
    {
        Screen.Dim(Color(0, 0, 0), 0.8, 0, 0, Screen.GetWidth(), Screen.GetHeight());
        int span = DSDungeon.FLOOR_W + DSDungeon.GAP_FLOORS;
        int i0 = dgDepth == 0 ? 0 : DSDungeon.MARGIN + dgDepth * span - DSDungeon.GAP_FLOORS / 2;
        int i1 = min(DSDungeon.W - 1, DSDungeon.MARGIN + dgDepth * span + DSDungeon.FLOOR_W + DSDungeon.GAP_FLOORS / 2);
        int j0 = 0; int j1 = DSDungeon.H - 1;
        double cs = min(600.0 / (i1 - i0 + 1), 262.0 / (j1 - j0 + 1));
        double vx = (640.0 - cs * (i1 - i0 + 1)) / 2.0; double vy = 72.0;
        DSUi.Header(46, String.Format("THE DEPTHS - DEPTH %d OF %d", dgDepth + 1, DSDungeon.FLOORS), Font.CR_GOLD, 1.0);
        DgDrawCells(i0, i1, j0, j1, vx, vy, cs, 0.95);
        DgDrawMarkers(i0, i1, j0, j1, vx, vy, cs, 3.0);
        DSShellMenu.CenterText(SmallFont, Font.CR_GREY, 340, "You: white   Enemies: red   Bosses: pink   Stairs down: orange   Way up: cyan   Amulet: gold", 0.9);
        DSShellMenu.CenterText(SmallFont, Font.CR_DARKGRAY, 354, "Tab or M: close  (the run keeps going)", 0.9);
    }
}
