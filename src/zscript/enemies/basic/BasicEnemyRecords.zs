// P023 basic-enemy fixture records.
//
// BAT3 is the sole resolved FOREST[0] enemy reference selected for this
// fixture.  Its behavior fields below are deliberately kept in one
// engineering fixture so later research can replace the values without
// changing ownership or transaction order.
class DSP023BasicEnemyData
{
    const KIND_BAT3 = 1;
    const MOVEMENT_SPEED = 0.5;
    const CONTACT_RADIUS = 2.0;
    const PLAYER_RADIUS = 2.0;
    const CONTACT_DISTANCE = 4.0;
    const HEALTH = 3000;
    const PLAYER_HEALTH = 10000;
    const CONTACT_DAMAGE = 1250;
    const CONTACT_COOLDOWN = 7;
    const PLAYER_INVULNERABILITY = 3;
    const XP_MILLIUNITS = 1000;
    const DROP_ID = "base.drop.xp-gem-engineering";

    static int NextRng(int state)
    {
        // rng-v1, shared with the accepted architecture fixture.  ZScript
        // ints are the intended deterministic 32-bit arithmetic here.
        int next = state;
        next = next ^ (next << 13);
        next = next ^ (next >> 17);
        next = next ^ (next << 5);
        if (next == 0) next = 1831565813;
        return next;
    }
}
