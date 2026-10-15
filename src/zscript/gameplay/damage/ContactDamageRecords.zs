// P023 source-model transaction records.  These records intentionally carry
// stable identity and generation, rather than a native Actor pointer.
struct DSP023DamageHandle
{
    int slot;
    int generation;
    int stableId;
}

struct DSP023ContactTransaction
{
    int tic;
    int attackerSlot;
    int attackerGeneration;
    int attackerStableId;
    int damageMilliunits;
}
