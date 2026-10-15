// P025 reusable source-model attack records.
// These records contain stable logical handles and snapshots only; a native
// Doom weapon or actor pointer is never part of an attack transaction.
struct DSP025WeaponHandle
{
    int slot;
    int generation;
    int stableId;
}

struct DSP025AttackSnapshot
{
    int eventId;
    int parentEventId;
    int ownerSlot;
    int ownerGeneration;
    int ownerStableId;
    int weaponStableId;
    int weaponGeneration;
    int damageBase;
    int damageBonus;
    int multiplierMilli;
    int pierce;
    int amount;
    int durationEnd;
    int knockback;
    int statusDuration;
    int aimYawMilli;
    int explicitTargetSlot;
    int explicitTargetGeneration;
    int explicitTargetStableId;
    int attackRngBefore;
    int attackRngAfter;
}

struct DSP025HitTransaction
{
    int tic;
    int transactionOrdinal;
    int eventId;
    int targetSlot;
    int targetGeneration;
    int targetStableId;
    int amount;
    int accepted;
}

// Shared character/inventory snapshots keep ownership explicit when a source
// weapon is promoted into the production attack runtime.
struct DSP025SourceCharacterState
{
    int level;
    int maxHealthBonus;
    int armorBonus;
    int mightMilli;
}

struct DSP025SourceInventoryState
{
    int slot;
    int generation;
    int weaponStableId;
    int weaponLevel;
}

// Shared production primitives used by every source weapon.  Keeping these
// at the P025 boundary prevents a weapon adapter from inventing its own RNG,
// damage units or timing arithmetic while retaining source snapshots locally.
mixin class DSP025AttackCore
{
    // Arcana hit modifiers (Slash, Jail of Crystal, Heart of Fire); the mask
    // is only ever non-zero in normal play (SliceArcana.zs). Effects that
    // need the world (freeze, explosions) are queued and run by ArcanaTick.
    int arHitMask;
    int arFlatBonus;     // Divine Bloodline: flat damage (milli) added to every listed hit
    int arHitSystem;     // the weapon (catalog id) behind the hit being applied, set at each hit site
    int arHitRng;
    bool arInFx;
    Array<int> arFxSlot;
    Array<int> arFxKind;
    Array<int> arFxAmount;
    Array<double> arFxX;   // hit position: the effect still runs if the hit killed
    Array<double> arFxY;

    int ArcanaHitModify(int slot, int amount)
    {
        if (arInFx) return amount;
        arHitRng = arHitRng * 1664525 + 1013904223;
        int roll = (arHitRng >>> 16) % 100;
        arHitRng = arHitRng * 1664525 + 1013904223;
        int roll2 = (arHitRng >>> 16) % 100;
        // Each effect only for its Arcana's listed weapons (DSArcana.Lists).
        int s = arHitSystem;
        if ((arHitMask & 1) != 0 && roll < 10 && amount < 600000000 && DSArcana.Lists(DSArcana.SLASH, s)) amount *= 3;
        if ((arHitMask & 8) != 0 && DSArcana.Lists(DSArcana.DIVINE_BLOODLINE, s)) amount += arFlatBonus;
        if ((arHitMask & 2) != 0 && roll2 < 8 && arFxSlot.Size() < 64 && DSArcana.Lists(DSArcana.JAIL_OF_CRYSTAL, s))
        { arFxSlot.Push(slot); arFxKind.Push(2); arFxAmount.Push(0); arFxX.Push(x[slot]); arFxY.Push(y[slot]); }
        else if ((arHitMask & 4) != 0 && roll2 >= 88 && arFxSlot.Size() < 64 && DSArcana.Lists(DSArcana.HEART_OF_FIRE, s))
        { arFxSlot.Push(slot); arFxKind.Push(4); arFxAmount.Push(amount); arFxX.Push(x[slot]); arFxY.Push(y[slot]); }
        return amount;
    }

    void DSP025PopulateSnapshot(out DSP025AttackSnapshot snapshot,
                                int eventId, int parentEventId,
                                int ownerSlot, int ownerGeneration,
                                int ownerStableId, int weaponStableId,
                                int weaponGeneration, int damageBase,
                                int damageBonus, int multiplierMilli,
                                int pierce, int amount, int durationEnd, int knockback,
                                int statusDuration, int aimYawMilli,
                                int attackRngBefore, int attackRngAfter)
    {
        snapshot.eventId = eventId;
        snapshot.parentEventId = parentEventId;
        snapshot.ownerSlot = ownerSlot;
        snapshot.ownerGeneration = ownerGeneration;
        snapshot.ownerStableId = ownerStableId;
        snapshot.weaponStableId = weaponStableId;
        snapshot.weaponGeneration = weaponGeneration;
        snapshot.damageBase = damageBase;
        snapshot.damageBonus = damageBonus;
        snapshot.multiplierMilli = multiplierMilli;
        snapshot.pierce = pierce;
        snapshot.amount = amount;
        snapshot.durationEnd = durationEnd;
        snapshot.knockback = knockback;
        snapshot.statusDuration = statusDuration;
        snapshot.aimYawMilli = aimYawMilli;
        snapshot.explicitTargetSlot = -1;
        snapshot.explicitTargetGeneration = 0;
        snapshot.explicitTargetStableId = 0;
        snapshot.attackRngBefore = attackRngBefore;
        snapshot.attackRngAfter = attackRngAfter;
    }

    int DSP025NextAttackRng(int state)
    {
        int next = state;
        next = next ^ (next << 13);
        next = next ^ (next >> 17);
        next = next ^ (next << 5);
        if (next == 0) next = 1831565813;
        return next;
    }

    // Legacy P025 fixture arithmetic remains source units for compatibility.
    bool DSP025CheckedDamage(int baseDamage, int bonus, int multiplierMilli, out int amount)
    {
        if (baseDamage < 0 || bonus < 0 || multiplierMilli < 0
            || baseDamage > 2000000000 - bonus)
        { amount = 0; return false; }
        int sourceDamage = baseDamage + bonus;
        if (multiplierMilli > 0 && sourceDamage > 2000000000 / multiplierMilli)
        { amount = 0; return false; }
        amount = (sourceDamage * multiplierMilli) / 1000;
        return amount >= 0 && amount <= 2000000000;
    }

    // P026 source-facing damage crosses the same checked transaction boundary
    // in milliunits; the scale is explicit so legacy records cannot silently
    // change units.
    bool DSP025CheckedMilliDamage(int sourceDamage, int multiplierMilli, out int amount)
    {
        if (sourceDamage < 0 || multiplierMilli < 0 || sourceDamage > 2000000)
        { amount = 0; return false; }
        int sourceMilli = sourceDamage * 1000;
        if (multiplierMilli > 0 && sourceMilli > 2000000000 / multiplierMilli)
        { amount = 0; return false; }
        amount = (sourceMilli * multiplierMilli) / 1000;
        return amount >= 0 && amount <= 2000000000;
    }

    bool DSP025DeadlineDue(int tic, int deadlineNumerator, int deadlineDenominator)
    {
        return tic >= 0 && deadlineDenominator > 0 && tic * deadlineDenominator >= deadlineNumerator;
    }

    int DSP025AdvanceDeadline(int deadlineNumerator, int intervalNumerator,
                              int intervalDenominator, int deadlineDenominator)
    {
        if (intervalDenominator <= 0 || deadlineDenominator <= 0) return deadlineNumerator;
        return deadlineNumerator + (intervalNumerator * deadlineDenominator) / intervalDenominator;
    }

    bool DSP025ApplyLogicalHit(int slot, int generation, int stableId,
                               int amount, out int healthBefore,
                               out int healthAfter, out int killed)
    {
        healthBefore = 0; healthAfter = 0; killed = 0;
        if (!ValidParts(slot, generation, stableId) || amount < 0) return false;
        if (arHitMask != 0 && amount > 0) amount = ArcanaHitModify(slot, amount);
        healthBefore = health[slot];
        healthAfter = healthBefore - amount;
        if (healthAfter < 0) healthAfter = 0;
        health[slot] = healthAfter;
        killed = healthAfter == 0 ? 1 : 0;
        return true;
    }
}
