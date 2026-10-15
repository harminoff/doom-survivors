// P027 experience pickup records.  Values are fixed checked milliunits and
// handles always carry the complete P020 generation tuple.
struct DSP027ExperienceHandle
{
    int slot;
    int generation;
    int stableId;
}

struct DSP027ExperienceLedger
{
    int created;
    int remaining;
    int collected;
    int removed;
}
