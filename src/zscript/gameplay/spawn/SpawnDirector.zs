// P022 spawn scheduling boundary.
//
// The director owns attempt ordering, admission accounting, deterministic
// placement and the logical reference region. It never asks the camera what
// is visible and never delegates gameplay to a native monster actor.
class DSP022SpawnDirector
{
    const CLOCK_STAGE_WAVE = 0;
    const CLOCK_STAGE_REFILL = 1;
    const CLOCK_STAGE_EVENT = 2;
    const CLOCK_COUNT = 3;
    const ROW_FOREST_WAVE = 0;
    const ROW_FOREST_REFILL = 1;
    const ROW_FOREST_EVENT = 2;
    const CAP_FOREST_WAVE = 4;
    const CAP_FOREST_REFILL = 6;
    const CAP_FOREST_EVENT = 6;

    static int Deadline(int clock, int index)
    {
        // ceil(index * interval * 35) for 100 ms, 250 ms and 1/3 second.
        if (clock == CLOCK_STAGE_WAVE) return (index * 7 + 1) / 2;
        if (clock == CLOCK_STAGE_REFILL) return (index * 35 + 3) / 4;
        return (index * 35 + 2) / 3;
    }

    static int Priority(int clock)
    {
        if (clock == CLOCK_STAGE_WAVE) return 0;
        if (clock == CLOCK_STAGE_REFILL) return 1;
        return 2;
    }

    static String ClockName(int clock)
    {
        if (clock == CLOCK_STAGE_WAVE) return "stage-wave-100ms";
        if (clock == CLOCK_STAGE_REFILL) return "stage-refill-250ms";
        return "stage-event-third";
    }

    static int RowForClock(int clock) { return clock; }
    static int BatchForClock(int clock)
    {
        if (clock == CLOCK_STAGE_WAVE) return 2;
        return 1;
    }
    static int RefillForClock(int clock)
    {
        if (clock == CLOCK_STAGE_EVENT) return 0;
        return 1;
    }
    static int CapForClock(int clock)
    {
        if (clock == CLOCK_STAGE_WAVE) return CAP_FOREST_WAVE;
        return clock == CLOCK_STAGE_REFILL ? CAP_FOREST_REFILL : CAP_FOREST_EVENT;
    }
}
