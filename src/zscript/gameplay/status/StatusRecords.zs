// P025 status state is owned by the source model and carries full handles.
// End tics are exclusive: a status is active while tic < endTic.
struct DSP025StatusRecord
{
    int active;
    int targetSlot;
    int targetGeneration;
    int targetStableId;
    int sourceEventId;
    int sourceWeaponId;
    int endTic;
}
