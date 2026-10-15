// P024 production uniform-grid CSR broad phase.
//
// This mixin only discovers possible logical handles.  The owning runtime
// applies the exact circle/rectangle/capsule oracle and stable-ID ordering
// after candidate discovery.  No actor, camera, proxy, or render coordinate
// is read here.
mixin class DSP024SpatialIndex
{
    const DSP024_CELL_SIZE = 128.0;

    // CSR cell directory.  A cell is identified by mathematical (X,Y), so
    // negative worlds do not need a clamped fixed-size room allocation.
    Array<int> spatialCellX;
    Array<int> spatialCellY;
    Array<int> spatialCellStart;
    Array<int> spatialCellItemSlots;
    Array<int> spatialCellItemGenerations;
    Array<int> spatialCellItemIds;

    // Temporary entry rows used to produce deterministic CSR ordering.
    Array<int> spatialEntryCellX;
    Array<int> spatialEntryCellY;
    Array<int> spatialEntrySlots;
    Array<int> spatialEntryGenerations;
    Array<int> spatialEntryIds;

    // Query candidate handles.  Full handles are retained until exact
    // validation, including for stale entries left by an intentional probe.
    Array<int> spatialCandidateSlots;
    Array<int> spatialCandidateGenerations;
    Array<int> spatialCandidateIds;
    Array<int> spatialCandidateStamps;
    Array<int> spatialCandidateSeenGenerations;
    Array<int> spatialCandidateSeenIds;
    int spatialQueryStamp;
    int spatialCandidateCount;
    int spatialCandidateVisits;
    int spatialStaleRejected;
    int spatialMaxRadius;
    double spatialMaxRadiusValue;

    int DSP024MathFloorCell(double value)
    {
        // int() truncates toward zero in ZScript.  Correct the negative
        // fractional case explicitly: -0.01 -> -1, -128.01 -> -2, while
        // exact boundaries remain on the lower cell (-128 -> -1).
        double scaled = value / DSP024_CELL_SIZE;
        int result = int(scaled);
        if (scaled < 0.0 && double(result) > scaled) result--;
        return result;
    }

    void DSP024ClearSpatial()
    {
        spatialCellX.Clear();
        spatialCellY.Clear();
        spatialCellStart.Clear();
        spatialCellItemSlots.Clear();
        spatialCellItemGenerations.Clear();
        spatialCellItemIds.Clear();
        spatialEntryCellX.Clear();
        spatialEntryCellY.Clear();
        spatialEntrySlots.Clear();
        spatialEntryGenerations.Clear();
        spatialEntryIds.Clear();
        spatialCandidateSlots.Clear();
        spatialCandidateGenerations.Clear();
        spatialCandidateIds.Clear();
        spatialCandidateStamps.Clear();
        spatialCandidateSeenGenerations.Clear();
        spatialCandidateSeenIds.Clear();
        spatialCandidateCount = 0;
        spatialCandidateVisits = 0;
        spatialStaleRejected = 0;
        spatialQueryStamp = 0;
        spatialMaxRadius = 0;
        spatialMaxRadiusValue = 0.0;
    }

    bool DSP024EntryPrecedes(int left, int right)
    {
        if (spatialEntryCellY[left] != spatialEntryCellY[right])
            return spatialEntryCellY[left] < spatialEntryCellY[right];
        if (spatialEntryCellX[left] != spatialEntryCellX[right])
            return spatialEntryCellX[left] < spatialEntryCellX[right];
        if (spatialEntryIds[left] != spatialEntryIds[right])
            return spatialEntryIds[left] < spatialEntryIds[right];
        return spatialEntrySlots[left] < spatialEntrySlots[right];
    }

    void DSP024SwapEntries(int left, int right)
    {
        int tempInt;
        tempInt = spatialEntryCellX[left]; spatialEntryCellX[left] = spatialEntryCellX[right]; spatialEntryCellX[right] = tempInt;
        tempInt = spatialEntryCellY[left]; spatialEntryCellY[left] = spatialEntryCellY[right]; spatialEntryCellY[right] = tempInt;
        tempInt = spatialEntrySlots[left]; spatialEntrySlots[left] = spatialEntrySlots[right]; spatialEntrySlots[right] = tempInt;
        tempInt = spatialEntryGenerations[left]; spatialEntryGenerations[left] = spatialEntryGenerations[right]; spatialEntryGenerations[right] = tempInt;
        tempInt = spatialEntryIds[left]; spatialEntryIds[left] = spatialEntryIds[right]; spatialEntryIds[right] = tempInt;
    }

    void DSP024InsertEntry(int cellX, int cellY, int slot, int generation, int stableId)
    {
        spatialEntryCellX.Push(cellX);
        spatialEntryCellY.Push(cellY);
        spatialEntrySlots.Push(slot);
        spatialEntryGenerations.Push(generation);
        spatialEntryIds.Push(stableId);
    }

    // Deterministic O(m log m) merge sort over [left, right) of the
    // spatialEntry* parallel arrays, ordered by the same total order as
    // DSP024EntryPrecedes. Recurses to halves, then merges via
    // DSP024MergeEntryRange, which reads the still-unmodified [left, mid)
    // and [mid, right) halves through DSP024EntryPrecedes before writing
    // the merged rows back, so the comparator's indices stay valid for the
    // whole merge.
    void DSP024MergeSortEntries(int left, int right)
    {
        if (right - left < 2) return;
        int mid = left + (right - left) / 2;
        DSP024MergeSortEntries(left, mid);
        DSP024MergeSortEntries(mid, right);
        DSP024MergeEntryRange(left, mid, right);
    }

    void DSP024MergeEntryRange(int left, int mid, int right)
    {
        Array<int> mergedCellX;
        Array<int> mergedCellY;
        Array<int> mergedSlots;
        Array<int> mergedGenerations;
        Array<int> mergedIds;
        int i = left;
        int j = mid;
        while (i < mid || j < right)
        {
            bool takeLeft;
            if (i >= mid) takeLeft = false;
            else if (j >= right) takeLeft = true;
            else takeLeft = !DSP024EntryPrecedes(j, i); // left <= right
            int source = takeLeft ? i : j;
            mergedCellX.Push(spatialEntryCellX[source]);
            mergedCellY.Push(spatialEntryCellY[source]);
            mergedSlots.Push(spatialEntrySlots[source]);
            mergedGenerations.Push(spatialEntryGenerations[source]);
            mergedIds.Push(spatialEntryIds[source]);
            if (takeLeft) i++; else j++;
        }
        for (int k = 0; k < mergedSlots.Size(); k++)
        {
            spatialEntryCellX[left + k] = mergedCellX[k];
            spatialEntryCellY[left + k] = mergedCellY[k];
            spatialEntrySlots[left + k] = mergedSlots[k];
            spatialEntryGenerations[left + k] = mergedGenerations[k];
            spatialEntryIds[left + k] = mergedIds[k];
        }
    }

    // Rebuild from the authoritative P020 struct-of-arrays.  Every live
    // entity contributes one row per cell touched by its circle AABB.
    void DSP024Rebuild()
    {
        DSP024ClearSpatial();
        for (int slot = 0; slot < lifeStates.Size(); slot++)
        {
            if (lifeStates[slot] != STORE_ALIVE) continue;
            double radius = collisionRadii[slot];
            if (radius < 0.0) continue;
            if (radius > spatialMaxRadiusValue) spatialMaxRadiusValue = radius;
            int minCellX = DSP024MathFloorCell(x[slot] - radius);
            int maxCellX = DSP024MathFloorCell(x[slot] + radius);
            int minCellY = DSP024MathFloorCell(y[slot] - radius);
            int maxCellY = DSP024MathFloorCell(y[slot] + radius);
            for (int cellY = minCellY; cellY <= maxCellY; cellY++)
                for (int cellX = minCellX; cellX <= maxCellX; cellX++)
                    DSP024InsertEntry(cellX, cellY, slot, generations[slot], ids[slot]);
        }

        // N2-W3 perf fix: the original insertion sort here was O(m^2) in the
        // number of entries and DSP024Rebuild() runs multiple times per
        // logical tic once several N2 engines are active concurrently
        // (grant-all evidence), which made a normal-play tic with a full
        // arsenal far slower than real time. DSP024MergeSortEntries below
        // computes the exact same total order (DSP024EntryPrecedes is a
        // strict total order over (cellY, cellX, id, slot), so any correct
        // sort — insertion or merge — yields byte-identical output) in
        // O(m log m) instead of O(m^2). No candidate, ordering, or hash
        // output changes; only the wall-clock cost of getting there does.
        DSP024MergeSortEntries(0, spatialEntrySlots.Size());

        spatialCellStart.Push(0);
        int itemCount = 0;
        int priorX = 0;
        int priorY = 0;
        bool haveCell = false;
        for (int i = 0; i < spatialEntrySlots.Size(); i++)
        {
            int currentX = spatialEntryCellX[i];
            int currentY = spatialEntryCellY[i];
            if (!haveCell || currentX != priorX || currentY != priorY)
            {
                if (haveCell) spatialCellStart.Push(itemCount);
                spatialCellX.Push(currentX);
                spatialCellY.Push(currentY);
                priorX = currentX;
                priorY = currentY;
                haveCell = true;
            }
            spatialCellItemSlots.Push(spatialEntrySlots[i]);
            spatialCellItemGenerations.Push(spatialEntryGenerations[i]);
            spatialCellItemIds.Push(spatialEntryIds[i]);
            itemCount++;
        }
        if (haveCell) spatialCellStart.Push(itemCount);
        spatialMaxRadius = int(spatialMaxRadiusValue + 0.5);
    }

    int DSP024FindCell(int cellX, int cellY)
    {
        // Cell keys are sorted by (Y,X); binary search keeps query discovery
        // independent of insertion order and avoids a fixed world boundary.
        int low = 0;
        int high = spatialCellX.Size() - 1;
        while (low <= high)
        {
            int middle = (low + high) / 2;
            if (spatialCellY[middle] < cellY
                || (spatialCellY[middle] == cellY && spatialCellX[middle] < cellX)) low = middle + 1;
            else if (spatialCellY[middle] > cellY
                || (spatialCellY[middle] == cellY && spatialCellX[middle] > cellX)) high = middle - 1;
            else return middle;
        }
        return -1;
    }

    void DSP024AddCandidate(int slot, int generation, int stableId)
    {
        spatialCandidateVisits++;
        if (!ValidParts(slot, generation, stableId))
        {
            spatialStaleRejected++;
            return;
        }
        if (slot >= spatialCandidateStamps.Size())
        {
            spatialCandidateStamps.Resize(lifeStates.Size());
            spatialCandidateSeenGenerations.Resize(lifeStates.Size());
            spatialCandidateSeenIds.Resize(lifeStates.Size());
        }
        if (spatialCandidateStamps[slot] == spatialQueryStamp
            && spatialCandidateSeenGenerations[slot] == generation
            && spatialCandidateSeenIds[slot] == stableId) return;
        spatialCandidateStamps[slot] = spatialQueryStamp;
        spatialCandidateSeenGenerations[slot] = generation;
        spatialCandidateSeenIds[slot] = stableId;
        spatialCandidateSlots.Push(slot);
        spatialCandidateGenerations.Push(generation);
        spatialCandidateIds.Push(stableId);
        spatialCandidateCount++;
    }

    void DSP024BeginCandidates()
    {
        spatialCandidateSlots.Clear();
        spatialCandidateGenerations.Clear();
        spatialCandidateIds.Clear();
        spatialCandidateCount = 0;
        spatialCandidateVisits = 0;
        if (spatialCandidateStamps.Size() < lifeStates.Size())
        {
            spatialCandidateStamps.Resize(lifeStates.Size());
            spatialCandidateSeenGenerations.Resize(lifeStates.Size());
            spatialCandidateSeenIds.Resize(lifeStates.Size());
        }
        spatialQueryStamp++;
        if (spatialQueryStamp <= 0)
        {
            for (int i = 0; i < spatialCandidateStamps.Size(); i++) spatialCandidateStamps[i] = 0;
            spatialQueryStamp = 1;
        }
    }

    void DSP024CollectAABB(double minX, double maxX, double minY, double maxY)
    {
        if (minX > maxX || minY > maxY) return;
        int lowX = DSP024MathFloorCell(minX);
        int highX = DSP024MathFloorCell(maxX);
        int lowY = DSP024MathFloorCell(minY);
        int highY = DSP024MathFloorCell(maxY);
        for (int cellY = lowY; cellY <= highY; cellY++)
        {
            for (int cellX = lowX; cellX <= highX; cellX++)
            {
                int cell = DSP024FindCell(cellX, cellY);
                if (cell < 0) continue;
                for (int item = spatialCellStart[cell]; item < spatialCellStart[cell + 1]; item++)
                    DSP024AddCandidate(spatialCellItemSlots[item], spatialCellItemGenerations[item], spatialCellItemIds[item]);
            }
        }
    }

    void DSP024RadiusCandidates(double queryX, double queryY, double queryRadius)
    {
        DSP024BeginCandidates();
        if (queryRadius < 0.0) return;
        double reach = queryRadius;
        DSP024CollectAABB(queryX - reach, queryX + reach, queryY - reach, queryY + reach);
    }

    void DSP024RectangleCandidates(double minX, double maxX, double minY, double maxY)
    {
        DSP024BeginCandidates();
        if (minX > maxX) { double swapX = minX; minX = maxX; maxX = swapX; }
        if (minY > maxY) { double swapY = minY; minY = maxY; maxY = swapY; }
        double expand = 0.0;
        DSP024CollectAABB(minX - expand, maxX + expand, minY - expand, maxY + expand);
    }

    void DSP024SweptCandidates(double startX, double startY, double endX, double endY, double sweepRadius)
    {
        DSP024BeginCandidates();
        if (sweepRadius < 0.0) return;
        double expand = sweepRadius;
        double minX = startX < endX ? startX : endX;
        double maxX = startX > endX ? startX : endX;
        double minY = startY < endY ? startY : endY;
        double maxY = startY > endY ? startY : endY;
        DSP024CollectAABB(minX - expand, maxX + expand, minY - expand, maxY + expand);
    }
}
