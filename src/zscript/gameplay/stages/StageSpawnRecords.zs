// P022 stage timeline and logical-region records.
//
// The P009 catalog provides the stage identity and raw schedule fields, but
// marks cadence, caps and geometry UNKNOWN.  These records therefore carry an
// explicit engineering fixture classification instead of pretending to be a
// source-exact schedule.
struct DSP022TimelineRow
{
    int row;
    int clock;
    int priority;
    int batch;
    int refill;
    int cap;
}

class DSP022StageGeometry
{
    const REGION_ID = "logical-reference-v1";
    const WIDTH = 256.0;
    const HEIGHT = 256.0;
    const HALF_WIDTH = 128.0;
    const HALF_HEIGHT = 128.0;
    const BAND_HALF_WIDTH = 160.0;
    const BAND_HALF_HEIGHT = 160.0;

    // The reference window is a gameplay predicate. It intentionally does
    // not inspect the player's yaw, pitch, FOV, or rendered frustum.
    static bool InsideReference(double x, double y, double centerX, double centerY)
    {
        return x >= centerX - HALF_WIDTH && x <= centerX + HALF_WIDTH
            && y >= centerY - HALF_HEIGHT && y <= centerY + HALF_HEIGHT;
    }

    // The spawn band is an inclusive outer rectangle with the reference
    // rectangle removed. Boundary ownership is explicit: +/-128 is in the
    // reference window; +/-160 is in the spawn band; +/-161 is outside.
    static bool InsideSpawnBand(double x, double y, double centerX, double centerY)
    {
        double dx = x - centerX;
        double dy = y - centerY;
        bool outer = dx >= -BAND_HALF_WIDTH && dx <= BAND_HALF_WIDTH
            && dy >= -BAND_HALF_HEIGHT && dy <= BAND_HALF_HEIGHT;
        return outer && !InsideReference(x, y, centerX, centerY);
    }

    static int NextSpawnRng(int state)
    {
        int next = state;
        next = next ^ (next << 13);
        next = next ^ (next >> 17);
        next = next ^ (next << 5);
        if (next == 0) next = 1831565813;
        return next;
    }

    // A deterministic, source-model placement sampler. The draw is owned by
    // the spawn stream and uses no camera values. Four sides are selected with
    // stable hash tie-breaking, and the lane includes negative coordinates.
    static void Place(int seed, int eventId, int row, int attempt,
                      double centerX, double centerY,
                      out double x, out double y, out int side, out int lane)
    {
        int hash = seed ^ (eventId * 1103515245) ^ (row * 265443576) ^ (attempt * 40503);
        if (hash < 0) hash = -hash;
        side = hash % 4;
        lane = (hash / 4) % 257 - 128;
        if (side == 0) { x = centerX - BAND_HALF_WIDTH; y = centerY + lane; }
        else if (side == 1) { x = centerX + BAND_HALF_WIDTH; y = centerY + lane; }
        else if (side == 2) { x = centerX + lane; y = centerY - BAND_HALF_HEIGHT; }
        else { x = centerX + lane; y = centerY + BAND_HALF_HEIGHT; }
    }
}
