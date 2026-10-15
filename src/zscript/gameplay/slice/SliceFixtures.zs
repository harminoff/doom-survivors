// Controlled MAP16 fixture routes (P031-P041). Not used in normal play.
// Part of DSP030VerticalSlice (fields and core lifecycle live in
// gameplay/VerticalSlice.zs).

extend class DSP030VerticalSlice
{
    bool UsesP031Progression()
    {
        return p031RouteEnabled;
    }

    void SpawnP033ContactFixture()
    {
        if (!p033RouteEnabled || !p033ContactFixtureEnabled
            || p033ContactFixtureAttempted || tic != 1) return;
        p033ContactFixtureAttempted = true;
        int slot = Allocate(KIND_ENEMY, playerX + 1.0, playerY,
            0.0, 0.0, 1000000);
        if (slot < 0)
        {
            Console.Printf("DS_P033_MAP16_CONTACT_FIXTURE accepted=0 tic=%d reason=STORE_CAPACITY source=CONTROLLED_OPT_IN", tic);
            return;
        }
        collisionRadii[slot] = 2.0;
        p033ContactFixtureId = ids[slot];
        Console.Printf("DS_P033_MAP16_CONTACT_FIXTURE accepted=1 tic=%d enemy_id=%d relative_distance=1.000 source=CONTROLLED_OPT_IN", tic, p033ContactFixtureId);
    }

    // P039-A02 evidence: a controlled player-damage fixture fired once
    // before the Soul Eater transform and once after it, each landing
    // health at ~40% of the resolved max in a single hit through
    // ProcessContact's own decrement-and-log path (never a direct health
    // write). Skipped if health is already at or below the target, so it
    // never doubles as a heal.
    void TryP039ContactFixture()
    {
        if (!p039RouteEnabled || p039ContactFixtureId != 0) return;
        bool preWindow = !p039ContactFixtureAttemptedPre && tic == 120;
        bool postWindow = !p039ContactFixtureAttemptedPost && tic == 700;
        if (!preWindow && !postWindow) return;
        if (preWindow) p039ContactFixtureAttemptedPre = true;
        if (postWindow) p039ContactFixtureAttemptedPost = true;
        String phase = preWindow ? "PRE_TRANSFORM" : "POST_TRANSFORM";
        int maxHealthMilli = CurrentPlayerHealthCap();
        int targetMilli = maxHealthMilli * 2 / 5;
        if (playerHealth <= targetMilli)
        {
            Console.Printf("DS_P039_MAP16_CONTACT_FIXTURE accepted=0 tic=%d reason=ALREADY_AT_OR_BELOW_TARGET health_milli=%d target_milli=%d phase=%s source=CONTROLLED_OPT_IN", tic, playerHealth, targetMilli, phase);
            return;
        }
        int slot = Allocate(KIND_ENEMY, playerX + 1.0, playerY, 0.0, 0.0, 1000000000);
        if (slot < 0)
        {
            Console.Printf("DS_P039_MAP16_CONTACT_FIXTURE accepted=0 tic=%d reason=STORE_CAPACITY phase=%s source=CONTROLLED_OPT_IN", tic, phase);
            return;
        }
        collisionRadii[slot] = 2.0;
        p039ContactFixtureId = ids[slot];
        p039ContactFixtureTargetMilli = targetMilli;
        p039ContactFixtureDamageMilli = playerHealth - targetMilli;
        Console.Printf("DS_P039_MAP16_CONTACT_FIXTURE accepted=1 tic=%d enemy_id=%d relative_distance=1.000 health_before_milli=%d target_milli=%d max_health_milli=%d damage_milli=%d phase=%s source=CONTROLLED_OPT_IN", tic, p039ContactFixtureId, playerHealth, targetMilli, maxHealthMilli, p039ContactFixtureDamageMilli, phase);
    }

    // Labelled controlled contact event, timed to land while at least one
    // post-transform NO FUTURE projectile is actually live: the transform
    // itself (tic 400) only changes future emissions (contract: "Transforms
    // change only future emissions"), so the FIRST NO FUTURE projectile is
    // not spawned until that weapon's own next volley after the transform
    // -- empirically (actual engine run) tic ~454 given the rank-8
    // Runetracer cooldown -- and it lives for its Duration (105 tics).
    // Tic 480 sits inside that window with margin either side, guaranteeing
    // at least one accepted player contact-damage transaction, and
    // therefore at least one NO FUTURE explosion, in the full run
    // (docs/contracts/bounce-projectiles.md "NO FUTURE"; reuses P039's own
    // adjacent-contact-fixture pattern exactly, see TryP039ContactFixture
    // above).
    void TryP041ContactFixture()
    {
        if (!p041RouteEnabled || p041ContactFixtureAttempted || tic != 480)
            return;
        p041ContactFixtureAttempted = true;
        int slot = Allocate(KIND_ENEMY, playerX + 1.0, playerY, 0.0, 0.0, 1000000);
        if (slot < 0)
        {
            Console.Printf("DS_P041_MAP16_CONTACT_FIXTURE accepted=0 tic=%d reason=STORE_CAPACITY source=CONTROLLED_OPT_IN", tic);
            return;
        }
        collisionRadii[slot] = 2.0;
        p041ContactFixtureId = ids[slot];
        Console.Printf("DS_P041_MAP16_CONTACT_FIXTURE accepted=1 tic=%d enemy_id=%d relative_distance=1.000 purpose=NO_FUTURE_PLAYER_HIT_EXPLOSION source=CONTROLLED_OPT_IN", tic, p041ContactFixtureId);
    }

    void SpawnP034Map16ControlledTarget()
    {
        p034TargetFixtureId = 0;
        if (!p034RouteEnabled) return;
        // The P032 pickup tape moves the body 36 units west before the
        // first P034 shot. Keep this controlled target within the row's
        // 320-unit plane range from that post-tape position.
        int slot = Allocate(KIND_ENEMY, playerX + 250.0, playerY,
            0.0, 0.0, p035RouteEnabled ? 100000000 : 10000000);
        if (slot < 0)
        {
            Console.Printf("DS_P034_MAP16_TARGET_FIXTURE accepted=0 reason=STORE_CAPACITY classification=CONTROLLED_MAP16_FIXTURE");
            return;
        }
        collisionRadii[slot] = p035RouteEnabled ? 32.0 : 4.0;
        p034TargetFixtureId = ids[slot];
        Console.Printf("DS_P034_MAP16_TARGET_FIXTURE accepted=1 target_id=%d target_slot=%d target_generation=%d x=%.3f y=%.3f health=%d stationary=1 source_spawn_claim=0 purpose=EASTBOUND_KNIFE_HIT classification=CONTROLLED_MAP16_FIXTURE", ids[slot], slot, generations[slot], x[slot], y[slot], health[slot]);
        if (p035RouteEnabled)
            Console.Printf("DS_P035_MAP16_TARGET_FIXTURE accepted=1 role=FAR_RANDOM_HELLFIRE_ANCHOR target_id=%d target_slot=%d target_generation=%d x=%.3f y=%.3f health=%d collision_radius_milli=%d stationary=1 source_spawn_claim=0 source_inventory_claim=0 purpose=RANDOM_TARGET_FAN_CONTROLLED_ANCHOR classification=CONTROLLED_MAP16_FIXTURE geometry=ENGINEERING_APPROXIMATION", ids[slot], slot, generations[slot], x[slot], y[slot], health[slot], int(collisionRadii[slot] * 1000.0));
    }

    void SpawnP035Map16ControlledTargets()
    {
        p035FrontFixtureId = 0;
        p035AxeFixtureId = 0;
        if (!p035RouteEnabled) return;

        // These durable targets make the four paths observable in a bounded
        // MAP16 run after the P032 pickup tape moves the player 30 units west.
        // Their positions and sizes are test-fixture geometry, not source data.
        int frontSlot = Allocate(KIND_ENEMY, playerX + 80.0, playerY,
            0.0, 0.0, 100000000);
        if (frontSlot >= 0)
        {
            collisionRadii[frontSlot] = 8.0;
            p035FrontFixtureId = ids[frontSlot];
            Console.Printf("DS_P035_MAP16_TARGET_FIXTURE accepted=1 role=FRONT_WHIP_BLOODY_HELLFIRE target_id=%d target_slot=%d target_generation=%d x=%.3f y=%.3f health=%d collision_radius_milli=%d stationary=1 source_spawn_claim=0 source_inventory_claim=0 purpose=WHIP_BLOODY_TEAR_AND_HELLFIRE_LANE classification=CONTROLLED_MAP16_FIXTURE geometry=ENGINEERING_APPROXIMATION", ids[frontSlot], frontSlot, generations[frontSlot], x[frontSlot], y[frontSlot], health[frontSlot], int(collisionRadii[frontSlot] * 1000.0));
        }
        else Console.Printf("DS_P035_MAP16_TARGET_FIXTURE accepted=0 role=FRONT_WHIP_BLOODY_HELLFIRE reason=STORE_CAPACITY classification=CONTROLLED_MAP16_FIXTURE");

        int axeSlot = Allocate(KIND_ENEMY, playerX - 36.0, playerY + 80.0,
            0.0, 0.0, 100000000);
        if (axeSlot >= 0)
        {
            collisionRadii[axeSlot] = 12.0;
            p035AxeFixtureId = ids[axeSlot];
            Console.Printf("DS_P035_MAP16_TARGET_FIXTURE accepted=1 role=AXE_UPWARD_ARC target_id=%d target_slot=%d target_generation=%d x=%.3f y=%.3f health=%d collision_radius_milli=%d stationary=1 source_spawn_claim=0 source_inventory_claim=0 purpose=AXE_FIXED_UPWARD_CHILD classification=CONTROLLED_MAP16_FIXTURE geometry=ENGINEERING_APPROXIMATION", ids[axeSlot], axeSlot, generations[axeSlot], x[axeSlot], y[axeSlot], health[axeSlot], int(collisionRadii[axeSlot] * 1000.0));
        }
        else Console.Printf("DS_P035_MAP16_TARGET_FIXTURE accepted=0 role=AXE_UPWARD_ARC reason=STORE_CAPACITY classification=CONTROLLED_MAP16_FIXTURE");
    }

    void SpawnP037Map16ControlledTarget()
    {
        p037TargetFixtureId = 0;
        if (!p037RouteEnabled) return;
        // A single durable body-plane target intersects both the base 48-unit
        // and evolved 84-unit rings, including the existing 36-unit P032 tape
        // displacement. It is a controlled test target, not source content.
        int slot = Allocate(KIND_ENEMY, playerX + 48.0, playerY,
            0.0, 0.0, 100000000);
        if (slot < 0)
        {
            Console.Printf("DS_P037_MAP16_TARGET_FIXTURE accepted=0 reason=STORE_CAPACITY classification=CONTROLLED_MAP16_FIXTURE");
            return;
        }
        collisionRadii[slot] = 32.0;
        p037TargetFixtureId = ids[slot];
        Console.Printf("DS_P037_MAP16_TARGET_FIXTURE accepted=1 target_id=%d target_slot=%d target_generation=%d x=%.3f y=%.3f health=%d collision_radius_milli=%d stationary=1 source_spawn_claim=0 source_inventory_claim=0 purpose=KING_BIBLE_AND_VESPERS_CONTACT classification=CONTROLLED_MAP16_FIXTURE geometry=ENGINEERING_APPROXIMATION", ids[slot], slot, generations[slot], x[slot], y[slot], health[slot], int(collisionRadii[slot] * 1000.0));
    }

    void SyncP037OrbitProxies()
    {
        ThinkerIterator it = ThinkerIterator.Create("DSP037OrbitProxy");
        Actor actor;
        while ((actor = Actor(it.Next())) != null)
        {
            DSP037OrbitProxy proxy = DSP037OrbitProxy(actor);
            int index = proxy.memberIndex;
            if (!p037RouteEnabled || index < 0
                || index >= dsp037MemberActive.Size()
                || dsp037MemberActive[index] == 0
                || dsp037MemberCohortIds[index] != proxy.cohortId
                || dsp037MemberOrdinals[index] != proxy.memberOrdinal
                || dsp037MemberGenerations[index] != proxy.memberGeneration)
                actor.Destroy();
            else
            {
                proxy.SetOrigin((dsp037MemberX[index], dsp037MemberY[index], 18.0), true);
                proxy.artSprite = Actor.GetSpriteIndex(OrbitSprite(dsp037MemberSystemIds[index]));
            }
        }
        if (!p037RouteEnabled) return;
        for (int index = 0; index < dsp037MemberActive.Size(); index++)
        {
            if (dsp037MemberActive[index] == 0) continue;
            bool found = false;
            ThinkerIterator find = ThinkerIterator.Create("DSP037OrbitProxy");
            Actor existing;
            while ((existing = Actor(find.Next())) != null)
            {
                DSP037OrbitProxy proxy = DSP037OrbitProxy(existing);
                if (proxy.memberIndex == index
                    && proxy.cohortId == dsp037MemberCohortIds[index]
                    && proxy.memberOrdinal == dsp037MemberOrdinals[index]
                    && proxy.memberGeneration == dsp037MemberGenerations[index])
                { found = true; break; }
            }
            if (found) continue;
            DSP037OrbitProxy created = DSP037OrbitProxy(Actor.Spawn(
                "DSP037OrbitProxy", (dsp037MemberX[index],
                    dsp037MemberY[index], 18.0), NO_REPLACE));
            if (created != null)
            {
                created.memberIndex = index;
                created.cohortId = dsp037MemberCohortIds[index];
                created.memberOrdinal = dsp037MemberOrdinals[index];
                created.memberGeneration = dsp037MemberGenerations[index];
            }
        }
    }

    void DestroyP037OrbitProxies()
    {
        ThinkerIterator it = ThinkerIterator.Create("DSP037OrbitProxy");
        Actor actor;
        while ((actor = Actor(it.Next())) != null) actor.Destroy();
    }

    bool ReplaceP032WeaponWithBloodyTear(int chestId, int tx)
    {
        int oldId = weaponSlot >= 0 && weaponSlot < ids.Size() ? ids[weaponSlot] : 0;
        int oldGeneration = weaponSlot >= 0 && weaponSlot < generations.Size() ? generations[weaponSlot] : 0;
        int cancelledWhipChildren = ClearWhipProxies();
        if (ValidParts(weaponSlot, oldGeneration, oldId)) DestroyParts(weaponSlot, oldGeneration, oldId);
        weaponSlot = Allocate(KIND_WEAPON, playerX, playerY, 0.0, 0.0, 1);
        if (weaponSlot < 0)
        {
            Console.Printf("DS_P032_MAP16_WEAPON_REPLACE accepted=0 chest=%d tx=%d reason=STORE_CAPACITY tic=%d", chestId, tx, tic);
            return false;
        }
        collisionRadii[weaponSlot] = 0.0;
        whipRank = 0;
        inventoryWeaponLevel = 8;
        nextWhipQuarter = DSP025AdvanceDeadline(tic * 4,
            CurrentWeaponCooldownQuarter(DSP033StatRules.SYSTEM_BLOODY_TEAR), 4, 4);
        p032EventId = 0;
        Console.Printf("DS_P032_MAP16_WEAPON_REPLACE accepted=1 chest=%d tx=%d tic=%d old_whip_id=%d old_whip_generation=%d new_bloody_tear_id=%d new_bloody_tear_generation=%d cancelled_whip_children=%d next_attack_quarter=%d schedule_restarted=1", chestId, tx, tic, oldId, oldGeneration, ids[weaponSlot], generations[weaponSlot], cancelledWhipChildren, nextWhipQuarter);
        SendInterfaceEvent(consoleplayer, "P032_MAP16_WEAPON", DSP032_ID_BLOODY_TEAR, 1, 0);
        return true;
    }

    void CreateP032Map16Chest()
    {
        if (!p032RouteEnabled) return;
        p032ChestId = runGeneration * 10 + 1;
        double yaw = players[0].mo != null ? players[0].mo.Angle : 0.0;
        // Keep the controlled tape long enough to demonstrate actual P021
        // body displacement beyond one pickup radius before it enters range.
        p032ChestX = int(playerX - cos(yaw) * 54.0);
        p032ChestY = int(playerY - sin(yaw) * 54.0);
        bool recorded = DSP032SpawnChestRecord(p032ChestId, DSP032_CHEST_SILVER,
            1, 1, tic, 1, true, p032ChestX, p032ChestY, 24);
        if (!recorded)
        {
            Console.Printf("DS_P032_MAP16_CHEST_SPAWN accepted=0 id=%d reason=CHEST_AUTHORITY", p032ChestId);
            return;
        }
        DSP032Map16ChestProxy chest = DSP032Map16ChestProxy(Actor.Spawn(
            "DSP032Map16ChestProxy", (p032ChestX, p032ChestY, 8.0), NO_REPLACE));
        if (chest != null) chest.chestStableId = p032ChestId;
        p032PickupTapeStartX = playerX; p032PickupTapeStartY = playerY;
        p032PickupTapeTicks = p032PickupTapeEnabled ? 12 : 0;
        Console.Printf("DS_P032_MAP16_CHEST_SPAWN accepted=1 id=%d subtype=SILVER transform_eligible=1 x=%d y=%d behind_facing=1 source=P032_CONTROLLED_FIXTURE visual=CONTROLLED_PICKUP_MARKER visual_exact=0 visual_spawned=%d pickup_tape=%d", p032ChestId, p032ChestX, p032ChestY, chest != null, p032PickupTapeEnabled);
    }

    void ProcessP032ChestProximity()
    {
        if (!p032RouteEnabled || runState != STATE_ACTIVE || players[0].mo == null) return;
        // Keep the fixture source later than the first automatic Whip pair so
        // the engine probe proves a live pre-transform schedule as well as
        // the post-transform Bloody Tear schedule.
        if (p032ChestId <= 0 && tic >= 60) CreateP032Map16Chest();
        if (p032ChestId <= 0 || p032ChestPickupRequested) return;
        if (!DSP032ChestWithinPickupRange(p032ChestId, int(playerX), int(playerY))) return;
        double forward; double lateral;
        LocalCoordinates(p032ChestX - playerX, p032ChestY - playerY,
            players[0].mo.Angle, forward, lateral);
        bool facingAway = forward < 0.0;
        p032ChestPickupRequested = true;
        double bodyDx = playerX - p032PickupTapeStartX; double bodyDy = playerY - p032PickupTapeStartY;
        double bodyTravel = sqrt(bodyDx * bodyDx + bodyDy * bodyDy);
        Console.Printf("DS_P032_MAP16_CHEST_PROXIMITY accepted=1 id=%d tic=%d player_x=%.3f player_y=%.3f chest_x=%d chest_y=%d yaw=%.3f chest_forward=%.3f chest_lateral=%.3f facing_away=%d source=P021_BODY_RADIUS use_pressed=0 eye_aimed=0 pickup_tape=%d body_travel=%.3f", p032ChestId, tic, playerX, playerY, p032ChestX, p032ChestY, players[0].mo.Angle, forward, lateral, facingAway, p032PickupTapeEnabled, bodyTravel);
        SendNetworkEvent("P032_CHEST_PICKUP", p032ChestId, 0, 0);
    }

    void DestroyP032ChestProxy(int chestId)
    {
        ThinkerIterator chests = ThinkerIterator.Create("DSP032Map16ChestProxy");
        Actor actor;
        while ((actor = Actor(chests.Next())) != null)
        {
            DSP032Map16ChestProxy chest = DSP032Map16ChestProxy(actor);
            if (chest != null && chest.chestStableId == chestId) chest.Destroy();
        }
    }

    void ApplyP032ChestChoice(int chestId, int slot, int recipeId)
    {
        int expectedSlot = DSP032AppliedRewardCount(chestId);
        if (!p032RouteEnabled || runState != STATE_LEVELUP || !p032ChestModalOpen
            || chestId != DSP032ActiveChestId() || slot != expectedSlot
            || recipeId != DSP032_RECIPE_WHIP_BLOODY_TEAR)
        {
            Console.Printf("DS_P032_MAP16_CONFIRM accepted=0 reason=DUPLICATE_OR_STALE chest=%d slot=%d recipe_id=%d expected_slot=%d active_chest=%d state=%s", chestId, slot, recipeId, expectedSlot, DSP032ActiveChestId(), StateName(runState));
            return;
        }
        int subtype = DSP032ChestSubtype(chestId);
        bool sourceEligible = DSP032ChestAllowsTransformation(chestId);
        bool rewardSlotAvailable = DSP032CanRecordChestReward(chestId, slot, DSP032_ID_BLOODY_TEAR);
        bool recipeEligible = DSP032CanApplyRecipe(recipeId, subtype, sourceEligible, true);
        int tx = chestId * 10 + slot + 1;
        if (!rewardSlotAvailable || !recipeEligible)
        {
            Console.Printf("DS_P032_MAP16_CONFIRM accepted=0 reason=ILLEGAL_OR_DUPLICATE chest=%d slot=%d recipe_id=%d tx=%d combat_tic=%d subtype=%d source_eligible=%d output_unlocked_fixture=1 reward_preflight=%d recipe_preflight=%d", chestId, slot, recipeId, tx, tic, subtype, sourceEligible, rewardSlotAvailable, recipeEligible);
            return;
        }
        bool transformed = DSP032ApplyRecipe(recipeId, chestId, subtype,
            sourceEligible, true, tx);
        if (!transformed) return;
        bool recorded = DSP032RecordChestReward(chestId, slot, DSP032_ID_BLOODY_TEAR);
        if (!recorded)
        {
            Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P032_MAP16_LEDGER_AFTER_RECIPE chest=%d tx=%d", chestId, tx);
            return;
        }
        if (p033RouteEnabled)
            RecomputeP033ResolvedStats("CHEST_TRANSFORM");
        Console.Printf("DS_P032_MAP16_CONFIRM accepted=1 chest=%d slot=%d recipe_id=%d tx=%d combat_tic=%d subtype=%d source_eligible=%d output_unlocked_fixture=1 reward_preflight=1 recipe_preflight=1", chestId, slot, recipeId, tx, tic, subtype, sourceEligible);
        DestroyP032ChestProxy(chestId);
        if (!ReplaceP032WeaponWithBloodyTear(chestId, tx)) return;
        bool completedChest = DSP032CompleteChest(chestId);
        Console.Printf("DS_P032_MAP16_CHEST_COMMIT accepted=%d chest=%d slot=%d tx=%d inventory_hash=%d queue=%d", completedChest, chestId, slot, tx, DSP032InventoryHash(), DSP032ChestQueueCount());
        if (!completedChest)
        {
            Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P032_MAP16_CHEST_COMPLETE chest=%d tx=%d", chestId, tx);
            return;
        }
        SendInterfaceEvent(consoleplayer, "P032_UI_STATE", DSP032AppliedRewardCount(chestId), DSP032InventoryHash(), DSP032ChestQueueCount());
        SendNetworkEvent("P032_UI_RESUME", chestId, completedChest ? 1 : 0, 0);
        Console.Printf("DS_P032_MAP16_UI_RESUME chest=%d committed=%d world_tic=%d", chestId, completedChest, tic);
        p032ChestModalOpen = false;
        if (completedChest)
        {
            Transition(STATE_ACTIVE, "P032_TRANSFORMATION_COMMITTED");
            ClearNativeInput();
            Console.Printf("DS_P032_MAP16_MODAL_RESUME chest=%d world_tic=%d clocks_frozen_during_modal=1", chestId, tic);
        }
    }

    void ProcessP031DiagnosticAutoPulse()
    {
        // The P031 test auto-pulse is a fixture weapon, never part of normal play.
        if (rsActive) return;
        if (!p031RouteEnabled || diagnosticWeaponSlot < 0 || runState != STATE_ACTIVE
            || players[0].mo == null
            || !ValidParts(diagnosticWeaponSlot, generations[diagnosticWeaponSlot], ids[diagnosticWeaponSlot])
            || !DSP025DeadlineDue(tic, diagnosticNextQuarter, 4)) return;

        int deadlineBefore = diagnosticNextQuarter;
        diagnosticNextQuarter = DSP025AdvanceDeadline(diagnosticNextQuarter, 189, 4, 4);
        diagnosticEventId++;
        int eventId = 100000 + diagnosticEventId;
        int rngBefore = diagnosticAttackRng;
        diagnosticAttackRng = DSP025NextAttackRng(diagnosticAttackRng);
        DSP025AttackSnapshot snapshot;
        DSP025PopulateSnapshot(snapshot, eventId, 0, playerSlot, generations[playerSlot], ids[playerSlot],
            ids[diagnosticWeaponSlot], generations[diagnosticWeaponSlot], 1, 0,
            p033RouteEnabled ? 1000 : characterMightMilli, 1, 1, tic, 0, 0,
            int(players[0].mo.Angle * 1000.0), rngBefore, diagnosticAttackRng);

        DSP024Rebuild();
        DSP024RadiusCandidates(playerX, playerY, 140.0);
        int candidates = 0;
        int targetSlot = -1;
        int targetGeneration = 0;
        int targetStableId = 0;
        int damageMilli = 0;
        int before = 0; int after = 0; int killed = 0;
        bool checked = DSP025CheckedMilliDamage(snapshot.damageBase, snapshot.multiplierMilli, damageMilli);
        for (int index = 0; index < spatialCandidateCount; index++)
        {
            int slot = spatialCandidateSlots[index];
            int generation = spatialCandidateGenerations[index];
            int stable = spatialCandidateIds[index];
            if (!ValidParts(slot, generation, stable) || kinds[slot] != KIND_ENEMY) continue;
            candidates++;
            targetSlot = slot; targetGeneration = generation; targetStableId = stable;
            break;
        }
        bool applied = targetSlot >= 0 && checked
            && DSP025ApplyLogicalHit(targetSlot, targetGeneration, targetStableId, damageMilli, before, after, killed);
        if (applied)
        {
            AddDamageDealt(before - after);
            Console.Printf("DS_P031_MAP16_DIAGNOSTIC_HIT event_id=%d tic=%d target_slot=%d target_generation=%d target_id=%d before=%d after=%d amount=%d accepted=1 authority=DSP025_CHECKED_HIT", eventId, tic, targetSlot, targetGeneration, targetStableId, before, after, damageMilli);
            if (killed != 0) HandleEnemyDeath(targetSlot, before, eventId);
        }
        Console.Printf("DS_P031_MAP16_DIAGNOSTIC_EMISSION event_id=%d tic=%d due_before_quarter=%d due_after_quarter=%d weapon=TEST_AUTO_PULSE weapon_slot=%d weapon_generation=%d weapon_id=%d owner_slot=%d owner_generation=%d owner_id=%d candidates=%d hits=%d checked=%d damage_milli=%d automatic=1 p025_snapshot=1 rng_stream=DIAGNOSTIC separate_from_whip=1 after_p031_choice=%d", eventId, tic, deadlineBefore, diagnosticNextQuarter, diagnosticWeaponSlot, generations[diagnosticWeaponSlot], ids[diagnosticWeaponSlot], playerSlot, generations[playerSlot], ids[playerSlot], candidates, applied ? 1 : 0, checked, damageMilli, p031ChoiceTic > 0 && tic > p031ChoiceTic);
        if (p033RouteEnabled)
            Console.Printf("DS_P033_MAP16_INELIGIBLE system=DIAGNOSTIC system_id=%d stat_id=%d eligible=0 stat_applied=0 snapshot_multiplier_milli=%d damage_milli=%d rank_hash=%d", DSP033StatRules.SYSTEM_DIAGNOSTIC_WEAPON, DSP033StatRules.STAT_MIGHT, snapshot.multiplierMilli, damageMilli, dsp033ResolvedRankHash);
    }

    void TryP034Map16FixtureTransformations()
    {
        if (!p034RouteEnabled || p034TransformAttempted || tic < 350)
            return;
        p034TransformAttempted = true;

        int holySource; int holySourceRank; int holyPassiveKind;
        int holyPassiveRank;
        bool holyRecipe = DSP034WeaponRows.TryGetTransformation(
            DSP034WeaponRows.SYSTEM_HOLY_WAND, holySource,
            holySourceRank, holyPassiveKind, holyPassiveRank);
        int tomeRank = DSP031Rank(DSP031_ID_EMPTY_TOME);
        bool tomeEligible = holyRecipe
            && holyPassiveKind == DSP034WeaponRows.TRANSFORM_EMPTY_TOME
            && tomeRank >= holyPassiveRank;
        bool wandRanked = holyRecipe && DSP034SetControlledFixtureRank(
            p034MagicWeaponSlot, holySource, holySourceRank, tic);
        bool holyApplied = wandRanked && tomeEligible
            && DSP034ReplaceControlledFixture(p034MagicWeaponSlot,
                DSP034WeaponRows.SYSTEM_HOLY_WAND, 1, tic);
        Console.Printf("DS_P034_MAP16_TRANSFORM accepted=%d source_system_id=%d source_rank=%d evolved_system_id=%d output_rank=1 passive_kind=%d passive_rank=%d passive_rank_observed=%d output_unlocked_fixture=1 transaction=CONTROLLED_MAP16_FIXTURE classification=ONLINE_REPORTED_RECIPE_CONTROLLED_INVENTORY_FIXTURE", holyApplied ? 1 : 0, holySource, holySourceRank, DSP034WeaponRows.SYSTEM_HOLY_WAND, holyPassiveKind, holyPassiveRank, tomeRank);

        int thousandSource; int thousandSourceRank;
        int bracerPassiveKind; int bracerPassiveRank;
        bool thousandRecipe = DSP034WeaponRows.TryGetTransformation(
            DSP034WeaponRows.SYSTEM_THOUSAND_EDGE, thousandSource,
            thousandSourceRank, bracerPassiveKind, bracerPassiveRank);
        // Bracer is not yet a P031 inventory row. Keep this explicitly
        // controlled ingredient fixture separate from the source passive
        // ledger; the online recipe identity itself comes from W01's row.
        bool bracerFixture = thousandRecipe
            && bracerPassiveKind == DSP034WeaponRows.TRANSFORM_BRACER;
        bool knifeRanked = thousandRecipe && DSP034SetControlledFixtureRank(
            p034KnifeWeaponSlot, thousandSource, thousandSourceRank, tic);
        bool thousandApplied = knifeRanked && bracerFixture
            && DSP034ReplaceControlledFixture(p034KnifeWeaponSlot,
                DSP034WeaponRows.SYSTEM_THOUSAND_EDGE, 1, tic);
        Console.Printf("DS_P034_MAP16_TRANSFORM accepted=%d source_system_id=%d source_rank=%d evolved_system_id=%d output_rank=1 passive_kind=%d passive_rank=%d passive_rank_observed=0 passive_fixture=%d passive_authority=CONTROLLED_BRACER_FIXTURE output_unlocked_fixture=1 transaction=CONTROLLED_MAP16_FIXTURE classification=ONLINE_REPORTED_RECIPE_CONTROLLED_INGREDIENT_FIXTURE", thousandApplied ? 1 : 0, thousandSource, thousandSourceRank, DSP034WeaponRows.SYSTEM_THOUSAND_EDGE, bracerPassiveKind, bracerPassiveRank, bracerFixture ? 1 : 0);
    }

    void ProcessP034AimedWeapons()
    {
        if (!p034RouteEnabled || runState != STATE_ACTIVE
            || players[0].mo == null
            || !ValidParts(playerSlot, generations[playerSlot], ids[playerSlot]))
            return;
        TryP034Map16FixtureTransformations();
        int acceptedDamageBefore = dsp034AcceptedDamageMilli;
        DSP034ProcessAimedTic(tic, playerSlot, generations[playerSlot],
            ids[playerSlot], playerX, playerY, true,
            int(players[0].mo.Angle * 1000.0),
            dsp033ResolvedValid
                ? DSP033Resolved(DSP033StatRules.STAT_COOLDOWN) : 1000,
            dsp033ResolvedValid ? dsp033ResolvedRankHash : 0);
        int acceptedDamageDelta = dsp034AcceptedDamageMilli - acceptedDamageBefore;
        if (acceptedDamageDelta > 0)
        {
            if (damageDealt > 2147483647 - acceptedDamageDelta)
                Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P034_MAP16_DAMAGE_TOTAL_OVERFLOW tic=%d total=%d delta=%d", tic, damageDealt, acceptedDamageDelta);
            else
            {
                AddDamageDealt(acceptedDamageDelta);
                Console.Printf("DS_P034_MAP16_DAMAGE_CREDIT tic=%d accepted_delta_milli=%d total_milli=%d authority=DSP034_ACCEPTED_P025_HITS", tic, acceptedDamageDelta, damageDealt);
            }
        }
    }

    void TryP035Map16FixtureTransformations()
    {
        if (!p035RouteEnabled || tic < 350) return;

        if (!p035AxeTransformAttempted)
        {
            p035AxeTransformAttempted = true;
            int axeSource = 0; int axeSourceRank = 0;
            int axeDependency = 0; int axeDependencyRank = 0;
            bool axeRecipe = DSP035WeaponRows.TryGetTransformation(
                DSP035WeaponRows.SYSTEM_DEATH_SPIRAL, axeSource,
                axeSourceRank, axeDependency, axeDependencyRank);
            bool axeFixture = axeRecipe
                && axeSource == DSP035WeaponRows.SYSTEM_AXE
                && axeDependency == DSP035WeaponRows.DEPENDENCY_AREA;
            bool axeRanked = axeFixture && DSP035SetFixtureRank(
                p035AxeWeaponSlot, axeSource, axeSourceRank, tic);
            bool axeApplied = axeRanked && DSP035ReplaceFixture(
                p035AxeWeaponSlot, DSP035WeaponRows.SYSTEM_DEATH_SPIRAL,
                1, tic, true, axeDependencyRank);
            Console.Printf("DS_P035_MAP16_TRANSFORM accepted=%d source_system_id=%d source_rank=%d evolved_system_id=%d output_rank=1 dependency_kind=%d dependency_min_rank=%d dependency_source=CONTROLLED_CANDELABRADOR_FIXTURE dependency_rank=%d inventory_claim=0 classification=ONLINE_REPORTED_RECIPE_CONTROLLED_INGREDIENT_FIXTURE", axeApplied ? 1 : 0, axeSource, axeSourceRank, DSP035WeaponRows.SYSTEM_DEATH_SPIRAL, axeDependency, axeDependencyRank, axeApplied ? axeDependencyRank : 0);
        }

        if (!p035FireTransformAttempted)
        {
            int fireSource = 0; int fireSourceRank = 0;
            int fireDependency = 0; int fireDependencyRank = 0;
            bool fireRecipe = DSP035WeaponRows.TryGetTransformation(
                DSP035WeaponRows.SYSTEM_HELLFIRE, fireSource,
                fireSourceRank, fireDependency, fireDependencyRank);
            int spinachRank = p031RouteEnabled
                ? DSP031Rank(DSP028_ID_POWER) : 0;
            bool fireFixture = fireRecipe
                && fireSource == DSP035WeaponRows.SYSTEM_FIRE_WAND
                && fireDependency == DSP035WeaponRows.DEPENDENCY_POWER;
            if (!fireFixture || spinachRank < fireDependencyRank)
            {
                if (tic == 350)
                    Console.Printf("DS_P035_MAP16_TRANSFORM_PENDING system_id=%d evolved_system_id=%d spinach_rank=%d required_rank=%d dependency_authority=DSP031_INVENTORY", fireSource, DSP035WeaponRows.SYSTEM_HELLFIRE, spinachRank, fireDependencyRank);
                return;
            }
            p035FireTransformAttempted = true;
            bool fireRanked = DSP035SetFixtureRank(p035FireWeaponSlot,
                fireSource, fireSourceRank, tic);
            bool fireApplied = fireRanked && DSP035ReplaceFixture(
                p035FireWeaponSlot, DSP035WeaponRows.SYSTEM_HELLFIRE,
                1, tic, true, spinachRank);
            Console.Printf("DS_P035_MAP16_TRANSFORM accepted=%d source_system_id=%d source_rank=%d evolved_system_id=%d output_rank=1 dependency_kind=%d dependency_min_rank=%d dependency_source=DSP031_SPINACH dependency_rank=%d inventory_claim=0 classification=ONLINE_REPORTED_RECIPE_CONTROLLED_EQUIPMENT", fireApplied ? 1 : 0, fireSource, fireSourceRank, DSP035WeaponRows.SYSTEM_HELLFIRE, fireDependency, fireDependencyRank, spinachRank);
        }
    }

    void ProcessP035BallisticWeapons()
    {
        if (!p035RouteEnabled || runState != STATE_ACTIVE
            || players[0].mo == null
            || !ValidParts(playerSlot, generations[playerSlot], ids[playerSlot]))
            return;
        TryP035Map16FixtureTransformations();
        int beforeDamage = dsp035AcceptedDamageMilli;
        DSP035ProcessBallisticTic(tic, playerSlot, generations[playerSlot],
            ids[playerSlot], playerX, playerY,
            int(players[0].mo.Angle * 1000.0),
            dsp033ResolvedValid
                ? DSP033Resolved(DSP033StatRules.STAT_COOLDOWN) : 1000,
            dsp033ResolvedValid ? dsp033ResolvedRankHash : 0);
        int acceptedDelta = dsp035AcceptedDamageMilli - beforeDamage;
        if (acceptedDelta > 0)
        {
            if (damageDealt > 2147483647 - acceptedDelta)
                Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P035_MAP16_DAMAGE_TOTAL_OVERFLOW tic=%d total=%d delta=%d", tic, damageDealt, acceptedDelta);
            else
            {
                AddDamageDealt(acceptedDelta);
                Console.Printf("DS_P035_MAP16_DAMAGE_CREDIT tic=%d accepted_delta_milli=%d total_milli=%d authority=DSP035_P025_CHECKED_LOGICAL_HITS", tic, acceptedDelta, damageDealt);
            }
        }
    }

    void TryP036Map16FixtureTransformation()
    {
        if (!p036RouteEnabled || p036TransformAttempted || tic < 350)
            return;
        p036TransformAttempted = true;
        int evolvedSystem = 0; int sourceRank = 0;
        int dependencyKind = 0; int dependencyMinRank = 0;
        bool recipe = DSP036ReturningRows.TryGetEvolution(
            DSP036ReturningRows.SYSTEM_CROSS, evolvedSystem, sourceRank,
            dependencyKind, dependencyMinRank);
        // Clover is a controlled ingredient fixture here. The P032 recipe
        // graph does not yet own this source edge, so this is not a natural
        // chest or unlocked-profile acquisition claim.
        bool cloverFixture = recipe
            && evolvedSystem == DSP036ReturningRows.SYSTEM_HEAVEN_SWORD
            && dependencyKind == DSP036ReturningRows.DEPENDENCY_LUCK
            && dependencyMinRank <= 1;
        bool sourceRankReady = recipe && DSP036SetFixtureRank(
            p036WeaponSlot, DSP036ReturningRows.SYSTEM_CROSS,
            sourceRank, tic);
        bool replaced = sourceRankReady && cloverFixture
            && DSP036ReplaceFixture(p036WeaponSlot,
                DSP036ReturningRows.SYSTEM_HEAVEN_SWORD, 1, tic,
                true, 1);
        Console.Printf("DS_P036_MAP16_TRANSFORM accepted=%d tic=%d source_system_id=%d source_rank=%d evolved_system_id=%d output_rank=1 dependency_kind=%d dependency_min_rank=%d dependency_rank=1 dependency_source=CONTROLLED_CLOVER_FIXTURE transaction=CONTROLLED_MAP16_FIXTURE source_inventory_claim=0", replaced ? 1 : 0, tic, DSP036ReturningRows.SYSTEM_CROSS, sourceRank, DSP036ReturningRows.SYSTEM_HEAVEN_SWORD, dependencyKind, dependencyMinRank);
    }

    void ProcessP036ReturningWeapons()
    {
        if (!p036RouteEnabled || runState != STATE_ACTIVE
            || players[0].mo == null
            || !ValidParts(playerSlot, generations[playerSlot], ids[playerSlot]))
            return;
        TryP036Map16FixtureTransformation();
        int acceptedBefore = dsp036AcceptedDamageMilli;
        DSP036ProcessReturningTic(tic, playerSlot, generations[playerSlot],
            ids[playerSlot], playerX, playerY,
            p033RouteEnabled && dsp033ResolvedValid
                ? DSP033Resolved(DSP033StatRules.STAT_COOLDOWN) : 1000,
            p033RouteEnabled && dsp033ResolvedValid
                ? dsp033ResolvedRankHash : 0);
        int acceptedDelta = dsp036AcceptedDamageMilli - acceptedBefore;
        if (acceptedDelta > 0)
        {
            if (damageDealt > 2147483647 - acceptedDelta)
                Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P036_MAP16_DAMAGE_TOTAL_OVERFLOW tic=%d total=%d delta=%d", tic, damageDealt, acceptedDelta);
            else
            {
                AddDamageDealt(acceptedDelta);
                Console.Printf("DS_P036_MAP16_DAMAGE_CREDIT tic=%d accepted_delta_milli=%d total_milli=%d authority=DSP036_P025_CHECKED_LOGICAL_HITS", tic, acceptedDelta, damageDealt);
            }
        }
    }

    void TryP037Map16FixtureTransformation()
    {
        if (!p037RouteEnabled || p037TransformAttempted || tic < 350)
            return;
        p037TransformAttempted = true;
        int evolvedSystem = 0; int requiredSourceRank = 0;
        int dependencyKind = 0; int dependencyMinimumRank = 0;
        bool recipe = DSP037OrbitRows.TryGetEvolution(
            DSP037OrbitRows.SYSTEM_KING_BIBLE, evolvedSystem,
            requiredSourceRank, dependencyKind, dependencyMinimumRank);
        bool sourceReady = recipe
            && DSP037SetFixtureRank(p037WeaponSlot, requiredSourceRank, tic);
        // Spellbinder is a controlled ingredient here: the P032 graph has not
        // yet connected this source edge, and the census leaves the exact
        // dependency rank unresolved.
        bool dependencyFixture = recipe
            && dependencyKind == DSP037OrbitRows.DEPENDENCY_DURATION;
        bool replaced = sourceReady && dependencyFixture
            && DSP037ReplaceFixture(p037WeaponSlot,
                DSP037OrbitRows.SYSTEM_UNHOLY_VESPERS, tic, true, 1);
        Console.Printf("DS_P037_MAP16_TRANSFORM accepted=%d tic=%d source_system_id=%d source_rank=%d evolved_system_id=%d output_rank=1 dependency_kind=%d dependency_min_rank=%d dependency_rank=1 dependency_source=CONTROLLED_SPELLBINDER_FIXTURE old_cohorts_cancelled=1 phase_preserved=1 source_inventory_claim=0 classification=ONLINE_REPORTED_RECIPE_CONTROLLED_INGREDIENT_FIXTURE", replaced ? 1 : 0, tic, DSP037OrbitRows.SYSTEM_KING_BIBLE, requiredSourceRank, evolvedSystem, dependencyKind, dependencyMinimumRank);
    }

    void ProcessP037OrbitWeapons()
    {
        if (!p037RouteEnabled || runState != STATE_ACTIVE
            || players[0].mo == null
            || !ValidParts(playerSlot, generations[playerSlot], ids[playerSlot]))
            return;
        TryP037Map16FixtureTransformation();
        int damageBefore = dsp037AcceptedDamageMilli;
        int hitsBefore = dsp037AcceptedHits;
        DSP037ProcessOrbitTic(tic, playerSlot, generations[playerSlot],
            ids[playerSlot], playerX, playerY,
            dsp033ResolvedValid
                ? DSP033Resolved(DSP033StatRules.STAT_MIGHT) : 1000,
            dsp033ResolvedValid
                ? DSP033Resolved(DSP033StatRules.STAT_COOLDOWN) : 1000);
        if (p037RestoreAttackPending
            && dsp037AcceptedHits > hitsBefore
            && dsp037LastAcceptedEventId > 0)
        {
            Console.Printf("DS_P037_MAP16_RESTORE_ATTACK accepted=1 event_id=%d tic=%d system_id=%d weapon_id=%d weapon_generation=%d joined_marker=DS_P037_HIT", dsp037LastAcceptedEventId, tic, DSP037OrbitRows.SYSTEM_UNHOLY_VESPERS, ids[p037WeaponSlot], generations[p037WeaponSlot]);
            p037RestoreAttackPending = false;
        }
        int acceptedDelta = dsp037AcceptedDamageMilli - damageBefore;
        p037LastPlayOrbitHash = DSP037OrbitStateHash();
        if (acceptedDelta > 0)
        {
            if (damageDealt > 2147483647 - acceptedDelta)
                Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P037_MAP16_DAMAGE_TOTAL_OVERFLOW tic=%d total=%d delta=%d", tic, damageDealt, acceptedDelta);
            else
            {
                AddDamageDealt(acceptedDelta);
                Console.Printf("DS_P037_MAP16_DAMAGE_CREDIT tic=%d accepted_delta_milli=%d total_milli=%d authority=DSP037_P025_CHECKED_LOGICAL_HITS", tic, acceptedDelta, damageDealt);
            }
        }
    }

    int P038Map16ActiveFields(int systemId)
    {
        int count = 0;
        for (int i = 0; i < dsp038FieldActive.Size(); i++)
            if (dsp038FieldActive[i] != 0
                && dsp038FieldSystem[i] == systemId) count++;
        return count;
    }

    int P038Map16ActiveBottles()
    {
        int count = 0;
        for (int i = 0; i < dsp038BottleActive.Size(); i++)
            if (dsp038BottleActive[i] != 0) count++;
        return count;
    }

    int P038Map16RuntimeWeaponIndex()
    {
        if (p038WeaponSlot < 0 || p038WeaponSlot >= ids.Size()) return -1;
        for (int i = 0; i < dsp038WeaponActive.Size(); i++)
            if (dsp038WeaponActive[i] != 0
                && dsp038WeaponSlots[i] == p038WeaponSlot
                && dsp038WeaponGenerations[i] == generations[p038WeaponSlot]
                && dsp038WeaponIds[i] == ids[p038WeaponSlot]) return i;
        return -1;
    }

    void EmitP038Map16SaveStateIfRequested()
    {
        if (!p038RouteEnabled || p038SaveStateEmitted
            || runState != STATE_ACTIVE || tic < 350
            || !p038TransformAttempted || !p037TransformAttempted
            || (p039RouteEnabled && !p039TransformAttempted)
            || (p040RouteEnabled && (!p040LoopTransformAttempted
                || !p040MoonTransformAttempted))
            || (p041RouteEnabled && !p041NoFutureTransformAttempted)
            || p038WeaponSlot < 0 || p038WeaponSlot >= ids.Size()
            || !ValidParts(p038WeaponSlot, generations[p038WeaponSlot],
                ids[p038WeaponSlot])) return;
        CVar saveRequest = CVar.FindCVar("ds_p033_save_snapshot_request");
        if (saveRequest == null || saveRequest.GetInt() == 0) return;
        int runtimeWeapon = P038Map16RuntimeWeaponIndex();
        int sourceSpinach = DSP031Rank(DSP028_ID_POWER);
        int sourceArmor = DSP031Rank(DSP028_ID_ARMOR);
        int sourceHollow = DSP031Rank(DSP031_ID_HOLLOW_HEART);
        int sourceTome = DSP031Rank(DSP031_ID_EMPTY_TOME);
        int sourceRankHash = DSP033StatRules.RankHash(sourceSpinach,
            sourceArmor, sourceHollow, sourceTome);
        bool runtimeValid = runtimeWeapon >= 0
            && dsp038WeaponSystem[runtimeWeapon]
                == DSP038GroundRows.SYSTEM_BORA
            && dsp038WeaponRank[runtimeWeapon] == 1
            && dsp038WeaponFormGenerations[runtimeWeapon] == 2
            && P038Map16ActiveFields(DSP038GroundRows.SYSTEM_BORA) > 0;
        bool statsValid = dsp033ResolvedValid
            && sourceRankHash == dsp033ResolvedRankHash;
        if (!runtimeValid || !statsValid)
        {
            Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P038_MAP16_SAVE_PRECONDITION tic=%d runtime_valid=%d runtime_weapon=%d source_rank_hash=%d resolved_rank_hash=%d", tic, runtimeValid, runtimeWeapon, sourceRankHash, dsp033ResolvedRankHash);
            return;
        }
        p038SavedGroundHash = DSP038GroundStateHash();
        // Captured unconditionally (harmless when p039RouteEnabled is
        // false, since RestoreP038Map16SavedRun only compares them when the
        // P039 route is enabled), pre-rebase, exactly like the other eight.
        p038SavedAuraHash = DSP039AuraStateHash();
        p038SavedHealingHash = DSP039HealingStateHash();
        // Same unconditional-capture convention as the aura/healing pair
        // above: harmless when p040RouteEnabled is false (both mixin fields
        // stay at their reset defaults), compared only when it is true.
        p038SavedGlobalHash = DSP040GlobalStateHash();
        // Same unconditional pre-rebase capture convention as the aura/
        // healing/global triple above: harmless when p041RouteEnabled is
        // false (DSP041ResetBounceRuntime leaves every array empty, so the
        // hash is the fixed empty-state constant), compared only when true.
        p038SavedBounceHash = DSP041PersistenceHash();
        p038SavedRankHashAmountGrowth = dsp033ResolvedRankHashAmountGrowth;
        p038SavedP031Hash = DSP031StateHash();
        p038SavedP032Hash = DSP032InventoryHash();
        p038SavedChestHash = DSP032ChestStateHash();
        p038SavedOrbitHash = DSP037OrbitStateHash();
        p038SavedAimedHash = DSP034AimedStateHash();
        p038SavedBallisticHash = DSP035BallisticStateHash();
        p038SavedReturningHash = DSP036ReturningStateHash();
        p038SavedSourceRankHash = sourceRankHash;
        p038SavedResolvedRankHash = dsp033ResolvedRankHash;
        p038SavedPlayerXMilli = int(playerX * 1000.0);
        p038SavedPlayerYMilli = int(playerY * 1000.0);
        p038SavedLogicalTic = tic;
        p038SavedWeaponFormGeneration = dsp038WeaponFormGenerations[runtimeWeapon];
        p038SaveStateEmitted = true;
        p038SaveSnapshotHeld = true;
        ClearNativeInput();
        Console.Printf("DS_P038_MAP16_SAVE_STATE accepted=1 source=POST_TRANSFORM system_id=%d rank=%d weapon_id=%d weapon_generation=%d form_generation=%d source_rank_hash=%d resolved_rank_hash=%d p031_hash=%d p032_hash=%d chest_hash=%d orbit_hash=%d ground_hash=%d aimed_hash=%d ballistic_hash=%d returning_hash=%d aura_hash=%d healing_hash=%d global_hash=%d rank_hash_amount_growth=%d spinach_rank=%d armor_rank=%d hollow_heart_rank=%d empty_tome_rank=%d might_milli=%d cooldown_multiplier_milli=%d active_bottles=%d holywater_fields=%d bora_fields=%d ledger_entries=%d accepted_hits=%d accepted_damage_milli=%d logical_tic=%d player_x_milli=%d player_y_milli=%d run_state=%s pause_authority=UZDOOM_WORLD_TIC", dsp038WeaponSystem[runtimeWeapon], dsp038WeaponRank[runtimeWeapon], ids[p038WeaponSlot], generations[p038WeaponSlot], dsp038WeaponFormGenerations[runtimeWeapon], sourceRankHash, dsp033ResolvedRankHash, p038SavedP031Hash, p038SavedP032Hash, p038SavedChestHash, p038SavedOrbitHash, p038SavedGroundHash, p038SavedAimedHash, p038SavedBallisticHash, p038SavedReturningHash, p038SavedAuraHash, p038SavedHealingHash, p038SavedGlobalHash, p038SavedRankHashAmountGrowth, sourceSpinach, sourceArmor, sourceHollow, sourceTome, DSP033Resolved(DSP033StatRules.STAT_MIGHT), DSP033Resolved(DSP033StatRules.STAT_COOLDOWN), P038Map16ActiveBottles(), P038Map16ActiveFields(DSP038GroundRows.SYSTEM_HOLYWATER), P038Map16ActiveFields(DSP038GroundRows.SYSTEM_BORA), dsp038HitFieldId.Size(), dsp038AcceptedHits, dsp038AcceptedDamageMilli, tic, p038SavedPlayerXMilli, p038SavedPlayerYMilli, StateName(runState));
        Console.Printf("DS_P041_MAP16_SAVE_STATE accepted=1 bounce_hash=%d accepted_hits=%d accepted_damage_milli=%d no_future_transform_attempted=%d no_future_explosions_credited=%d logical_tic=%d", p038SavedBounceHash, dsp041AcceptedHits, dsp041AcceptedDamageMilli, p041NoFutureTransformAttempted ? 1 : 0, p041NoFutureExplosionsCredited, tic);
    }

    void RestoreP038Map16SavedRun()
    {
        DSP033SetBaseStats(1000, 1, PLAYER_HEALTH, 1000);
        bool statsValid = DSP031SyncLegacyStats()
            && RecomputeP033ResolvedStats("P038_SAVE_RESTORE");
        double currentX = players[0].mo != null
            ? players[0].mo.Pos.X : playerX;
        double currentY = players[0].mo != null
            ? players[0].mo.Pos.Y : playerY;
        double deltaX = currentX - playerX;
        double deltaY = currentY - playerY;
        // All eight logical-state hashes must be captured before any of the
        // P036/P037/P038 rebase calls below, since a rebase intentionally
        // mutates live world-plane positions that are folded into several of
        // these hashes. Comparing post-rebase would let a nonzero rebase
        // delta silently mask a genuine logical-state mismatch.
        int restoredP031Hash = DSP031StateHash();
        int restoredP032Hash = DSP032InventoryHash();
        int restoredChestHash = DSP032ChestStateHash();
        int restoredAimedHash = DSP034AimedStateHash();
        int restoredBallisticHash = DSP035BallisticStateHash();
        int restoredReturningHash = DSP036ReturningStateHash();
        int restoredOrbitHash = DSP037OrbitStateHash();
        int restoredGroundHash = DSP038GroundStateHash();
        // Captured unconditionally, pre-rebase, same as the other eight;
        // only gated into the accepted check below when p039RouteEnabled.
        int restoredAuraHash = DSP039AuraStateHash();
        int restoredHealingHash = DSP039HealingStateHash();
        // Same unconditional pre-rebase capture as the other nine; only
        // gated into the accepted check below when p040RouteEnabled.
        int restoredGlobalHash = DSP040GlobalStateHash();
        // Same unconditional pre-rebase capture as the other ten; only
        // gated into the accepted check below when p041RouteEnabled.
        int restoredBounceHash = DSP041PersistenceHash();
        DSP036RebaseProjectiles(deltaX, deltaY);
        DSP037RebaseOrbitMembers(deltaX, deltaY);
        DSP038RebaseGroundRuntime(deltaX, deltaY);
        DSP039RebaseAura(deltaX, deltaY);
        DSP040RebaseGlobal(deltaX, deltaY);
        DSP041Rebase(deltaX, deltaY, tic);
        SyncPlayer();
        int runtimeWeapon = P038Map16RuntimeWeaponIndex();
        int sourceRankHash = DSP033StatRules.RankHash(
            DSP031Rank(DSP028_ID_POWER), DSP031Rank(DSP028_ID_ARMOR),
            DSP031Rank(DSP031_ID_HOLLOW_HEART),
            DSP031Rank(DSP031_ID_EMPTY_TOME));
        bool runtimeValid = runtimeWeapon >= 0
            && dsp038WeaponSystem[runtimeWeapon]
                == DSP038GroundRows.SYSTEM_BORA
            && dsp038WeaponRank[runtimeWeapon] == 1
            && dsp038WeaponFormGenerations[runtimeWeapon]
                == p038SavedWeaponFormGeneration
            && P038Map16ActiveFields(DSP038GroundRows.SYSTEM_BORA) > 0;
        bool accepted = p038RouteEnabled && runState == STATE_ACTIVE
            && tic == p038SavedLogicalTic && p038SaveStateEmitted
            && p038SaveSnapshotHeld && p038TransformAttempted
            && p037TransformAttempted
            && (!p039RouteEnabled || p039TransformAttempted)
            && statsValid && runtimeValid
            && sourceRankHash == p038SavedSourceRankHash
            && dsp033ResolvedRankHash == p038SavedResolvedRankHash
            && restoredP031Hash == p038SavedP031Hash
            && restoredP032Hash == p038SavedP032Hash
            && restoredChestHash == p038SavedChestHash
            && restoredAimedHash == p038SavedAimedHash
            && restoredBallisticHash == p038SavedBallisticHash
            && restoredReturningHash == p038SavedReturningHash
            && restoredOrbitHash == p038SavedOrbitHash
            && restoredGroundHash == p038SavedGroundHash
            && (!p039RouteEnabled
                || (restoredAuraHash == p038SavedAuraHash
                    && restoredHealingHash == p038SavedHealingHash))
            && (!p040RouteEnabled
                || (restoredGlobalHash == p038SavedGlobalHash
                    && dsp033ResolvedRankHashAmountGrowth
                        == p038SavedRankHashAmountGrowth))
            && (!p041RouteEnabled || restoredBounceHash == p038SavedBounceHash);
        if (!accepted)
        {
            Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P038_MAP16_RESTORE_REJECTED tic=%d run_state=%s save_emitted=%d save_held=%d stats_valid=%d runtime_valid=%d source_rank_hash=%d saved_source_rank_hash=%d resolved_rank_hash=%d saved_resolved_rank_hash=%d p031_hash=%d saved_p031_hash=%d p032_hash=%d saved_p032_hash=%d chest_hash=%d saved_chest_hash=%d aimed_hash=%d saved_aimed_hash=%d ballistic_hash=%d saved_ballistic_hash=%d returning_hash=%d saved_returning_hash=%d orbit_hash=%d saved_orbit_hash=%d ground_hash=%d saved_ground_hash=%d aura_hash=%d saved_aura_hash=%d healing_hash=%d saved_healing_hash=%d p039_route_enabled=%d global_hash=%d saved_global_hash=%d rank_hash_amount_growth=%d saved_rank_hash_amount_growth=%d p040_route_enabled=%d", tic, StateName(runState), p038SaveStateEmitted, p038SaveSnapshotHeld, statsValid, runtimeValid, sourceRankHash, p038SavedSourceRankHash, dsp033ResolvedRankHash, p038SavedResolvedRankHash, restoredP031Hash, p038SavedP031Hash, restoredP032Hash, p038SavedP032Hash, restoredChestHash, p038SavedChestHash, restoredAimedHash, p038SavedAimedHash, restoredBallisticHash, p038SavedBallisticHash, restoredReturningHash, p038SavedReturningHash, restoredOrbitHash, p038SavedOrbitHash, restoredGroundHash, p038SavedGroundHash, restoredAuraHash, p038SavedAuraHash, restoredHealingHash, p038SavedHealingHash, p039RouteEnabled ? 1 : 0, restoredGlobalHash, p038SavedGlobalHash, dsp033ResolvedRankHashAmountGrowth, p038SavedRankHashAmountGrowth, p040RouteEnabled ? 1 : 0);
            if (p041RouteEnabled)
                Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P041_MAP16_RESTORE_REJECTED tic=%d bounce_hash=%d saved_bounce_hash=%d exact=%d", tic, restoredBounceHash, p038SavedBounceHash, restoredBounceHash == p038SavedBounceHash);
            return;
        }
        playerHealth = playerHealth < CurrentPlayerHealthCap()
            ? playerHealth : CurrentPlayerHealthCap();
        if (playerSlot >= 0 && playerSlot < health.Size())
            health[playerSlot] = playerHealth;
        p038SaveSnapshotHeld = false;
        p038RestorePendingHit = true;
        p037RestoreAttackPending = true;
        p039RestorePendingHit = p039RouteEnabled;
        IsUiProcessor = runState == STATE_LEVELUP || runState == STATE_RESULTS;
        ClearNativeInput();
        SendInterfaceEvent(consoleplayer, "P031_MODE", p031RouteEnabled ? 1 : 0, 0, 0);
        SendInterfaceEvent(consoleplayer, "P032_MAP16_MODE", p032RouteEnabled ? 1 : 0, 1, 0);
        SendInterfaceEvent(consoleplayer, "P033_MAP16_HEALTH_CAP", CurrentPlayerHealthCap(), 0, 0);
        SendInterfaceEvent(consoleplayer, "P032_UI_STATE", DSP032AppliedRewardCount(p032ChestId), DSP032InventoryHash(), DSP032ChestQueueCount());
        DSP024Rebuild();
        SyncPresentation();
        PublishUiState();
        EmitInputOwnership(IsUiProcessor ? "P038_SAVE_RESTORE_MODAL" : "P038_SAVE_RESTORE_ACTIVE");
        Console.Printf("DS_P038_MAP16_RESTORE_STATE accepted=1 source=POST_TRANSFORM system_id=%d rank=%d weapon_id=%d weapon_generation=%d form_generation=%d source_rank_hash=%d resolved_rank_hash=%d p031_hash=%d saved_p031_hash=%d p032_hash=%d saved_p032_hash=%d chest_hash=%d saved_chest_hash=%d aimed_hash=%d saved_aimed_hash=%d ballistic_hash=%d saved_ballistic_hash=%d returning_hash=%d saved_returning_hash=%d orbit_hash=%d saved_orbit_hash=%d ground_hash=%d saved_ground_hash=%d aura_hash=%d saved_aura_hash=%d healing_hash=%d saved_healing_hash=%d p039_route_enabled=%d global_hash=%d saved_global_hash=%d rank_hash_amount_growth=%d saved_rank_hash_amount_growth=%d p040_route_enabled=%d spinach_rank=%d armor_rank=%d hollow_heart_rank=%d empty_tome_rank=%d might_milli=%d cooldown_multiplier_milli=%d active_bottles=%d holywater_fields=%d bora_fields=%d ledger_entries=%d accepted_hits=%d accepted_damage_milli=%d logical_tic=%d player_x_milli=%d player_y_milli=%d rebase_x_milli=%d rebase_y_milli=%d run_state=%s erased=%d", dsp038WeaponSystem[runtimeWeapon], dsp038WeaponRank[runtimeWeapon], ids[p038WeaponSlot], generations[p038WeaponSlot], dsp038WeaponFormGenerations[runtimeWeapon], sourceRankHash, dsp033ResolvedRankHash, restoredP031Hash, p038SavedP031Hash, restoredP032Hash, p038SavedP032Hash, restoredChestHash, p038SavedChestHash, restoredAimedHash, p038SavedAimedHash, restoredBallisticHash, p038SavedBallisticHash, restoredReturningHash, p038SavedReturningHash, restoredOrbitHash, p038SavedOrbitHash, restoredGroundHash, p038SavedGroundHash, restoredAuraHash, p038SavedAuraHash, restoredHealingHash, p038SavedHealingHash, p039RouteEnabled ? 1 : 0, restoredGlobalHash, p038SavedGlobalHash, dsp033ResolvedRankHashAmountGrowth, p038SavedRankHashAmountGrowth, p040RouteEnabled ? 1 : 0, DSP031Rank(DSP028_ID_POWER), DSP031Rank(DSP028_ID_ARMOR), DSP031Rank(DSP031_ID_HOLLOW_HEART), DSP031Rank(DSP031_ID_EMPTY_TOME), DSP033Resolved(DSP033StatRules.STAT_MIGHT), DSP033Resolved(DSP033StatRules.STAT_COOLDOWN), P038Map16ActiveBottles(), P038Map16ActiveFields(DSP038GroundRows.SYSTEM_HOLYWATER), P038Map16ActiveFields(DSP038GroundRows.SYSTEM_BORA), dsp038HitFieldId.Size(), dsp038AcceptedHits, dsp038AcceptedDamageMilli, tic, int(playerX * 1000.0), int(playerY * 1000.0), int(deltaX * 1000.0), int(deltaY * 1000.0), StateName(runState), dsp040ErasedEnemies);
        if (p041RouteEnabled)
            Console.Printf("DS_P041_MAP16_RESTORE_STATE accepted=1 bounce_hash=%d saved_bounce_hash=%d exact=1 accepted_hits=%d accepted_damage_milli=%d rebase_x_milli=%d rebase_y_milli=%d logical_tic=%d", restoredBounceHash, p038SavedBounceHash, dsp041AcceptedHits, dsp041AcceptedDamageMilli, int(deltaX * 1000.0), int(deltaY * 1000.0), tic);
    }

    void TryP038Map16FixtureTransformation()
    {
        if (!p038RouteEnabled || p038TransformAttempted
            || tic < 120 || p038WeaponSlot < 0
            || p038WeaponSlot >= ids.Size()) return;
        p038TransformAttempted = true;
        int holyFieldsBefore = P038Map16ActiveFields(
            DSP038GroundRows.SYSTEM_HOLYWATER);
        bool accepted = DSP038TransformWeapon(p038WeaponSlot,
            generations[p038WeaponSlot], ids[p038WeaponSlot],
            DSP038GroundRows.SYSTEM_HOLYWATER,
            DSP038GroundRows.SYSTEM_BORA, 1, 2, true);
        int holyFieldsAfter = P038Map16ActiveFields(
            DSP038GroundRows.SYSTEM_HOLYWATER);
        Console.Printf("DS_P038_MAP16_TRANSFORM accepted=%d tic=%d source_system_id=%d source_rank=8 evolved_system_id=%d output_rank=1 dependency_source_key=%d dependency_source=CONTROLLED_ATTRACTORB_FIXTURE dependency_min_rank=UNKNOWN old_holywater_fields_before=%d old_holywater_fields_after=%d future_emissions_only=1 source_inventory_claim=0 geometry=ENGINEERING_APPROXIMATION", accepted ? 1 : 0, tic, DSP038GroundRows.SYSTEM_HOLYWATER, DSP038GroundRows.SYSTEM_BORA, DSP038GroundRows.DEPENDENCY_MAGNET_SOURCE_KEY, holyFieldsBefore, holyFieldsAfter);
        if (!accepted)
            Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P038_MAP16_TRANSFORM");
    }

    void ProcessP038GroundWeapons()
    {
        if (!p038RouteEnabled || runState != STATE_ACTIVE
            || players[0].mo == null || p038WeaponSlot < 0
            || !ValidParts(playerSlot, generations[playerSlot], ids[playerSlot]))
            return;
        TryP038Map16FixtureTransformation();
        int damageBefore = dsp038AcceptedDamageMilli;
        int hitsBefore = dsp038AcceptedHits;
        DSP038ProcessGroundTic(tic, playerX, playerY,
            dsp033ResolvedValid
                ? DSP033Resolved(DSP033StatRules.STAT_MIGHT) : 1000,
            dsp033ResolvedValid
                ? DSP033Resolved(DSP033StatRules.STAT_COOLDOWN) : 1000);
        p038LastPlayGroundHash = DSP038GroundStateHash();
        if (p038RestorePendingHit && dsp038AcceptedHits > hitsBefore
            && dsp038LastAcceptedEventId > 0)
        {
            Console.Printf("DS_P038_MAP16_RESTORE_HIT accepted=1 event_id=%d tic=%d system_id=%d field_id=%d field_generation=%d weapon_id=%d weapon_generation=%d joined_marker=DS_P038_FIELD_HIT", dsp038LastAcceptedEventId, tic, dsp038LastAcceptedSystemId, dsp038LastAcceptedFieldId, dsp038LastAcceptedFieldGeneration, ids[p038WeaponSlot], generations[p038WeaponSlot]);
            p038RestorePendingHit = false;
        }
        int acceptedDelta = dsp038AcceptedDamageMilli - damageBefore;
        if (acceptedDelta > 0)
        {
            if (damageDealt > 2147483647 - acceptedDelta)
                Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P038_MAP16_DAMAGE_TOTAL_OVERFLOW tic=%d total=%d delta=%d", tic, damageDealt, acceptedDelta);
            else
            {
                AddDamageDealt(acceptedDelta);
                Console.Printf("DS_P038_MAP16_DAMAGE_CREDIT tic=%d accepted_delta_milli=%d total_milli=%d authority=DSP038_P025_CHECKED_LOGICAL_HITS", tic, acceptedDelta, damageDealt);
            }
        }
    }

    // Garlic -> Soul Eater is future-form-only (docs/contracts/auras-healing.md
    // "Cadence"): the transform happens at a fixed later tic, matching P038's
    // controlled Attractorb-dependency pattern (TryP038Map16FixtureTransformation
    // above), gated by the controlled Pummarola-owned fixture (p039PummarolaRank
    // > 0) rather than a real P031 draft dependency.
    void TryP039Map16FixtureTransformation()
    {
        if (!p039RouteEnabled || p039TransformAttempted
            || tic < 150 || p039WeaponSlot < 0
            || p039WeaponSlot >= ids.Size()) return;
        p039TransformAttempted = true;
        int evolved; int dependencyKey; int sourceRank; int dependencyRank;
        DSP039AuraRows.TryGetEvolution(DSP039AuraRows.SYSTEM_GARLIC,
            evolved, dependencyKey, sourceRank, dependencyRank);
        bool accepted = p039PummarolaRank > 0
            && DSP039TransformAura(p039WeaponSlot, generations[p039WeaponSlot],
                ids[p039WeaponSlot], DSP039AuraRows.SYSTEM_GARLIC,
                DSP039AuraRows.SYSTEM_SOUL_EATER, 1, 2, true);
        Console.Printf("DS_P039_MAP16_TRANSFORM accepted=%d tic=%d source_system_id=%d source_rank=8 evolved_system_id=%d output_rank=1 dependency_source_key=%d dependency_source=CONTROLLED_PUMMAROLA_FIXTURE dependency_min_rank=UNKNOWN future_emissions_only=1 source_inventory_claim=0 geometry=ENGINEERING_APPROXIMATION", accepted ? 1 : 0, tic, DSP039AuraRows.SYSTEM_GARLIC, DSP039AuraRows.SYSTEM_SOUL_EATER, dependencyKey);
        if (!accepted)
            Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P039_MAP16_TRANSFORM");
    }

    void ProcessP039AuraWeapons()
    {
        if (!p039RouteEnabled || runState != STATE_ACTIVE
            || players[0].mo == null || p039WeaponSlot < 0
            || !ValidParts(playerSlot, generations[playerSlot], ids[playerSlot]))
            return;
        TryP039Map16FixtureTransformation();
        int damageBefore = dsp039AcceptedDamageMilli;
        int hitsBefore = dsp039AcceptedHits;
        int heartsSpawnedBefore = dsp039HeartsSpawned;
        int mightMilli = DSP033Resolved(DSP033StatRules.STAT_MIGHT);
        int cooldownMultiplierMilli = DSP033Resolved(DSP033StatRules.STAT_COOLDOWN);
        int recoveryMilli = DSP033Resolved(DSP033StatRules.STAT_RECOVERY);
        DSP039ProcessAuraTic(tic, playerX, playerY, mightMilli,
            cooldownMultiplierMilli, recoveryMilli);
        p039LastPlayAuraHash = DSP039AuraStateHash();
        if (dsp039HeartsSpawned > heartsSpawnedBefore)
        {
            // P039-A02 evidence: a real Little Heart from a real kill, at a
            // random death position the automated MAP16 movement may never
            // revisit, so its collection is not otherwise reliable in an
            // unattended run. Reposition it (never fabricate one) onto the
            // player's current logical position so the pickup phase this
            // same tic collects it deterministically -- a controlled,
            // clearly labelled fixture, not a synthetic heart or a direct
            // health write.
            for (int i = 0; i < DSP039HeartCount(); i++)
            {
                if (!DSP039HeartActiveAt(i) || dsp039HeartSpawnTic[i] != tic) continue;
                dsp039HeartX[i] = playerX;
                dsp039HeartY[i] = playerY;
                Console.Printf("DS_P039_MAP16_HEART_FIXTURE_REPOSITION accepted=1 tic=%d heart_id=%d heart_generation=%d player_x_milli=%d player_y_milli=%d source=CONTROLLED_OPT_IN", tic, dsp039HeartId[i], dsp039HeartGeneration[i], int(playerX * 1000.0), int(playerY * 1000.0));
                break;
            }
        }
        if (p039RestorePendingHit && dsp039AcceptedHits > hitsBefore
            && dsp039LastAcceptedEventId > 0)
        {
            Console.Printf("DS_P039_MAP16_RESTORE_HIT accepted=1 event_id=%d tic=%d system_id=%d weapon_id=%d weapon_generation=%d target_id=%d joined_marker=DS_P039_AURA_HIT", dsp039LastAcceptedEventId, tic, dsp039LastAcceptedSystemId, ids[p039WeaponSlot], generations[p039WeaponSlot], dsp039LastAcceptedTargetId);
            p039RestorePendingHit = false;
        }
        // Credit aura damage to the run's results exactly once per tic, by
        // the accepted-total delta -- mirrors ProcessP038GroundWeapons above
        // and every other P034-P038 weapon family's own damage-credit step.
        int acceptedDelta = dsp039AcceptedDamageMilli - damageBefore;
        if (acceptedDelta > 0)
        {
            if (damageDealt > 2147483647 - acceptedDelta)
                Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P039_MAP16_DAMAGE_TOTAL_OVERFLOW tic=%d total=%d delta=%d", tic, damageDealt, acceptedDelta);
            else
            {
                AddDamageDealt(acceptedDelta);
                Console.Printf("DS_P039_MAP16_DAMAGE_CREDIT tic=%d accepted_delta_milli=%d total_milli=%d authority=DSP039_P025_CHECKED_LOGICAL_HITS", tic, acceptedDelta, damageDealt);
            }
        }
    }

    // Mirrors TryP039Map16FixtureTransformation's fixed-tic pattern, but two
    // independent transforms (Lightning->Loop at tic=150, Pentagram->Moon at
    // tic=170, staggered so their DS_P040_MAP16_TRANSFORM markers are never
    // ambiguous about which weapon a given tic's line describes), each
    // gated by the controlled Duplicator/Crown fixture ranks (2/5) set at
    // equip time rather than a real P031 draft dependency.
    void TryP040Map16LoopTransform()
    {
        if (!p040RouteEnabled || p040LoopTransformAttempted
            || tic < 150 || p040StrikeWeaponSlot < 0
            || p040StrikeWeaponSlot >= ids.Size()) return;
        p040LoopTransformAttempted = true;
        bool accepted = DSP033Resolved(DSP033StatRules.STAT_AMOUNT) > 0
            && DSP040TransformToLoop(p040StrikeWeaponSlot,
                generations[p040StrikeWeaponSlot], ids[p040StrikeWeaponSlot],
                DSP040GlobalRows.DEPENDENCY_AMOUNT_SOURCE_KEY, 1, 2);
        Console.Printf("DS_P040_MAP16_TRANSFORM accepted=%d kind=LOOP tic=%d source_system_id=%d output_rank=1 dependency_source=CONTROLLED_DUPLICATOR_FIXTURE source_inventory_claim=0 geometry=ENGINEERING_APPROXIMATION", accepted ? 1 : 0, tic, DSP040GlobalRows.SYSTEM_LIGHTNING);
        if (!accepted)
            Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P040_MAP16_LOOP_TRANSFORM");
    }

    void TryP040Map16MoonTransform()
    {
        if (!p040RouteEnabled || p040MoonTransformAttempted
            || tic < 170 || p040EraseWeaponSlot < 0
            || p040EraseWeaponSlot >= ids.Size()) return;
        p040MoonTransformAttempted = true;
        bool accepted = DSP033Resolved(DSP033StatRules.STAT_GROWTH) > 0
            && DSP040TransformToMoon(p040EraseWeaponSlot,
                generations[p040EraseWeaponSlot], ids[p040EraseWeaponSlot],
                DSP040GlobalRows.DEPENDENCY_GROWTH_SOURCE_KEY, 1, 2);
        // Labelled controlled-fixture offset (see
        // DSP040ForceEraseNextActivation's own note): Gorgeous Moon's
        // real-source 2100-tic base period cannot naturally re-fire inside
        // one bounded 2100-tic MAP16 run after inheriting Pentagram's own
        // post-tic=50 schedule, so phase 1 is retimed to tic=600 -- well
        // after the tic=50 Pentagram erasure and past the spawner's opening
        // waves, so more than 6 enemies are typically present for phase 2
        // to erase a real survivor, not just spend every beam. This never
        // touches targeting/damage/erase/spare-roll math, only the tic the
        // next activation is checked.
        bool retimed = accepted && DSP040ForceEraseNextActivation(
            p040EraseWeaponSlot, generations[p040EraseWeaponSlot],
            ids[p040EraseWeaponSlot], 600);
        Console.Printf("DS_P040_MAP16_TRANSFORM accepted=%d kind=MOON tic=%d source_system_id=%d output_rank=1 dependency_source=CONTROLLED_CROWN_FIXTURE retimed_activation_tic=600 retime_classification=CONTROLLED_ENGINEERING_FIXTURE source_inventory_claim=0 geometry=ENGINEERING_APPROXIMATION", accepted ? 1 : 0, tic, DSP040GlobalRows.SYSTEM_PENTAGRAM);
        if (!accepted || !retimed)
            Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P040_MAP16_MOON_TRANSFORM");
    }

    // Controlled fixture: whip's own first connected hit (and therefore the
    // first natural XP pickup) lands at an RNG-dependent tic that can occur
    // after tic=120 on some seeds, leaving Pentagram's own first activation
    // with nothing to spare-roll. A single controlled pickup dropped near
    // the player a few tics beforehand guarantees a real, in-region target
    // for the spare roll regardless of that RNG-dependent timing; it is
    // rolled and, if not spared, removed through the SAME P027 ERASED
    // ledger path as any other pickup Pentagram finds.
    void TryP040Map16PentagramPickupFixture()
    {
        if (!p040RouteEnabled || p040PentagramPickupFixtureSpawned || tic != 110) return;
        p040PentagramPickupFixtureSpawned = true;
        // Placed past P027's own 96-unit attraction radius (but inside the
        // +/-128 region) so it sits on the ground, untouched by the normal
        // collection path, until Pentagram's own tic=120 activation rolls
        // it -- placing it inside the attraction radius would let the
        // ordinary pickup phase collect it before Pentagram's turn.
        DSP027ExperienceHandle handle;
        bool created = DSP027CreatePickup(1000, playerX + 110.0, playerY, 40040040, handle);
        Console.Printf("DS_P040_MAP16_PENTAGRAM_PICKUP_FIXTURE accepted=%d tic=%d slot=%d source=CONTROLLED_OPT_IN", created ? 1 : 0, tic, created ? handle.slot : -1);
    }

    // Controlled fixture (CONTROLLED_ENGINEERING_FIXTURE, not a source spawn
    // claim): the automated MAP16 mover's natural nearby-enemy density
    // stays at 1-4 for the whole soak (whip kills about as fast as the
    // director spawns), which is not enough for Gorgeous Moon's up-to-6
    // beams to leave a real survivor for phase 2 to erase. One tic before
    // the tic=600 retimed Moon activation, drop 8 enemies in a ring around
    // the player so phase 1 and phase 2 both have real, in-region targets.
    void TryP040Map16MoonTargetFixture()
    {
        if (!p040RouteEnabled || p040MoonTargetFixtureSpawned || tic != 599) return;
        p040MoonTargetFixtureSpawned = true;
        int spawned = 0;
        for (int i = 0; i < 8; i++)
        {
            double angle = double(i) * 45.0 * 3.14159265 / 180.0;
            int slot = Allocate(KIND_ENEMY, playerX + 40.0 * cos(angle),
                playerY + 40.0 * sin(angle), 0.0, 0.0, 2000000);
            if (slot < 0) continue;
            collisionRadii[slot] = 8.0;
            spawned++;
        }
        DSP024Rebuild();
        Console.Printf("DS_P040_MAP16_MOON_TARGET_FIXTURE accepted=%d tic=%d spawned=%d classification=CONTROLLED_ENGINEERING_FIXTURE source_inventory_claim=0", spawned > 0 ? 1 : 0, tic, spawned);
    }

    // Controlled fixture: the same low natural density above also means XP
    // pickups drop up to Whip's 128-unit forward reach, well past P027's
    // 96-unit attraction radius, while the automated mover mostly holds
    // position once nothing nearby needs killing -- so a pickup can sit on
    // the ground indefinitely. Repositioning one live pickup onto the
    // player's own logical position, once, at a fixed later tic, is the
    // same controlled-relocation pattern P039 already uses for its own
    // Little Heart fixture (DS_P039_MAP16_HEART_FIXTURE_REPOSITION): it
    // never fabricates a pickup or writes XP directly, it only guarantees
    // the EXISTING ProcessPickups collection path (Growth included) has
    // something in range this same tic.
    void TryP040Map16PickupRepositionFixture()
    {
        if (!p040RouteEnabled || p040PickupRepositionAttempted || tic != 250) return;
        p040PickupRepositionAttempted = true;
        int chosen = -1;
        for (int slot = 0; slot < lifeStates.Size(); slot++)
        {
            if (!DSP027IsLivePickup(slot)) continue;
            chosen = slot;
            break;
        }
        if (chosen < 0)
        {
            Console.Printf("DS_P040_MAP16_PICKUP_REPOSITION accepted=0 tic=%d reason=NO_LIVE_PICKUP source=CONTROLLED_OPT_IN", tic);
            return;
        }
        x[chosen] = playerX; y[chosen] = playerY;
        experienceStates[chosen] = DSP027_ATTRACTING;
        Console.Printf("DS_P040_MAP16_PICKUP_REPOSITION accepted=1 tic=%d slot=%d generation=%d stable_id=%d source=CONTROLLED_OPT_IN", tic, chosen, generations[chosen], ids[chosen]);
    }

    // Controlled fixture for P040-A03 (no duplicate level-up transactions
    // for a large event): a real Moon gem (MOON_GEM_BASE_XP_MILLI x
    // (1+Amount) = 3000 milli here) is far too small to cross even one of
    // DSP031ThresholdForCurrentLevel's 5000+/level thresholds on its own,
    // so this drops one pre-placed 100,000-milli pickup inside the region
    // -- past the 96-unit attraction radius so it sits untouched -- a few
    // tics before the retimed tic=600/635 Moon activation. Phase 2's own
    // vacuum (DSP027ForceAttract over every in-region pickup, real gems and
    // this one alike) pulls it in exactly like any other pickup; it is
    // never collected, spared or erased outside that normal path. Once it
    // reaches the player, ONE ProcessPickups collection call carries
    // enough XP to cross several level thresholds at once (Draft.zs's own
    // DSP031CollectExperience while-loop), which is what actually proves
    // P028 applies each queued level exactly once.
    void TryP040Map16BigGemFixture()
    {
        if (!p040RouteEnabled || p040BigGemFixtureSpawned || tic != 610) return;
        p040BigGemFixtureSpawned = true;
        DSP027ExperienceHandle handle;
        bool created = DSP027CreatePickup(100000, playerX + 110.0, playerY - 40.0,
            60060060, handle);
        Console.Printf("DS_P040_MAP16_BIG_GEM_FIXTURE accepted=%d tic=%d slot=%d value_milli=100000 source=CONTROLLED_OPT_IN", created ? 1 : 0, tic, created ? handle.slot : -1);
    }

    // Runs after ProcessP039AuraWeapons in the existing weapon order, per
    // the frozen contract ("P040 weapons run after P039 in the existing
    // weapon order"). Kills reach HandleEnemyDeath -- the SAME method every
    // other family's checked hit already calls -- through
    // DSP040ApplyStrikeAoE/DSP040FireMoonPhase1 inside the mixin, so a
    // strike/beam kill gets exactly the ordinary XP-drop/kill-count/Soul-
    // Eater-heart-eligible treatment. Erasures never call HandleEnemyDeath
    // (DSP040EraseEnemy releases the entity directly), so they are excluded
    // from all of that by construction, not by a flag checked here.
    void ProcessP040GlobalWeapons()
    {
        if (!p040RouteEnabled || runState != STATE_ACTIVE
            || players[0].mo == null || p040StrikeWeaponSlot < 0
            || p040EraseWeaponSlot < 0
            || !ValidParts(playerSlot, generations[playerSlot], ids[playerSlot]))
            return;
        TryP040Map16LoopTransform();
        TryP040Map16PentagramPickupFixture();
        TryP040Map16MoonTransform();
        TryP040Map16MoonTargetFixture();
        TryP040Map16PickupRepositionFixture();
        TryP040Map16BigGemFixture();
        int damageBefore = dsp040AcceptedDamageMilli;
        int erasedBefore = dsp040ErasedEnemies;
        int amountResolved = DSP033AmountApplies(DSP040GlobalRows.SYSTEM_LIGHTNING)
            ? DSP033Resolved(DSP033StatRules.STAT_AMOUNT) : 0;
        DSP040ProcessStrikeTic(tic, playerX, playerY, amountResolved);
        DSP040ProcessEraseTic(tic, playerX, playerY,
            DSP040GlobalRows.LUCK_BASE_MILLI, amountResolved);
        // Credit strike damage to the run's results exactly once per tic, by
        // the accepted-total delta -- mirrors ProcessP039AuraWeapons above
        // and every other P034-P039 weapon family's own damage-credit step.
        // Erasure is never credited here: it has no damage transaction by
        // contract, and is reported separately via dsp040ErasedEnemies
        // (DS_P030_RESULTS/DS_P030_COMPLETE's own `erased=` field).
        int acceptedDelta = dsp040AcceptedDamageMilli - damageBefore;
        if (acceptedDelta > 0)
        {
            if (damageDealt > 2147483647 - acceptedDelta)
                Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P040_MAP16_DAMAGE_TOTAL_OVERFLOW tic=%d total=%d delta=%d", tic, damageDealt, acceptedDelta);
            else
            {
                AddDamageDealt(acceptedDelta);
                Console.Printf("DS_P040_MAP16_DAMAGE_CREDIT tic=%d accepted_delta_milli=%d total_milli=%d authority=DSP040_P025_CHECKED_LOGICAL_HITS", tic, acceptedDelta, damageDealt);
            }
        }
        int erasedDelta = dsp040ErasedEnemies - erasedBefore;
        if (erasedDelta > 0)
        {
            p040ErasedCredited += erasedDelta;
            Console.Printf("DS_P040_MAP16_ERASE_CREDIT tic=%d erased_delta=%d erased_total=%d authority=DSP040_ERASE_OP_DISTINCT_FROM_KILL", tic, erasedDelta, p040ErasedCredited);
        }
    }

    // Runetracer max-rank plus Armor >= 1 (base armor defaults to 1; see
    // DSP033SetBaseStats above), a controlled dependency per contract's
    // "NO FUTURE" section (census gap on the real requirement noted there).
    void TryP041Map16NoFutureTransform()
    {
        if (!p041RouteEnabled || p041NoFutureTransformAttempted
            || tic < 400 || p041RunetracerWeaponIndex < 0) return;
        p041NoFutureTransformAttempted = true;
        int armorResolved = dsp033ResolvedValid
            ? DSP033Resolved(DSP033StatRules.STAT_ARMOR) : 1;
        bool accepted = armorResolved >= 1
            && DSP041TransformFixture(p041RunetracerWeaponIndex,
                DSP041BounceRows.SYSTEM_NO_FUTURE, 1,
                DSP041BounceRows.DEPENDENCY_ARMOR_SOURCE_KEY, armorResolved, tic);
        Console.Printf("DS_P041_MAP16_TRANSFORM accepted=%d kind=NO_FUTURE tic=%d source_system_id=%d source_rank=8 evolved_system_id=%d output_rank=1 resolved_armor=%d dependency_source=DSP033_BASE_STATS classification=ONLINE_REPORTED_RECIPE_CONTROLLED_INGREDIENT_FIXTURE source_inventory_claim=0 geometry=ENGINEERING_APPROXIMATION", accepted ? 1 : 0, tic, DSP041BounceRows.SYSTEM_RUNETRACER, DSP041BounceRows.SYSTEM_NO_FUTURE, armorResolved);
        if (!accepted)
            Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P041_MAP16_NO_FUTURE_TRANSFORM");
    }

    // Runs after ProcessP040GlobalWeapons in the existing weapon order (the
    // frozen contract's own MAP16 requirement: "an opt-in route layered on
    // P040 with all five weapons"). Fires every equipped fixture every tic;
    // DSP041FireVolley is a no-op while its own cooldown gate is still
    // closed (mirrors BounceMap27Runtime's "capacity" mode exactly), so this
    // just lets all four independent weapons refire as soon as each is able
    // -- over the full 2100-tic run that clears well past the required
    // bounce/hit/explosion evidence thresholds. Kills reach HandleEnemyDeath
    // through DSP041ApplyHit/DSP041ApplyExplosion inside the mixin (same
    // treatment as every other checked-hit family); P040 erasures release
    // their entity directly and invalidate the slot before P041 ever scans
    // it (this method runs strictly after ProcessP040GlobalWeapons each
    // tic), so a bounce weapon can never re-hit or double-count an already
    // erased target.
    void ProcessP041BounceWeapons()
    {
        if (!p041RouteEnabled || runState != STATE_ACTIVE
            || players[0].mo == null
            || !ValidParts(playerSlot, generations[playerSlot], ids[playerSlot]))
            return;
        TryP041Map16NoFutureTransform();
        int cooldownMultiplierMilli = dsp033ResolvedValid
            ? DSP033Resolved(DSP033StatRules.STAT_COOLDOWN) : 1000;
        int facingYawMilli = int(players[0].mo.Angle * 1000.0);
        int hitsBefore = dsp041AcceptedHits;
        int damageBefore = dsp041AcceptedDamageMilli;
        if (p041RunetracerWeaponIndex >= 0)
            DSP041FireVolley(p041RunetracerWeaponIndex, tic, facingYawMilli,
                cooldownMultiplierMilli, 1000);
        if (p041BoneWeaponIndex >= 0)
            DSP041FireVolley(p041BoneWeaponIndex, tic, facingYawMilli,
                cooldownMultiplierMilli, 1000);
        if (p041CherryWeaponIndex >= 0)
            DSP041FireVolley(p041CherryWeaponIndex, tic, facingYawMilli,
                cooldownMultiplierMilli, 1000);
        if (p041CarrelloWeaponIndex >= 0)
            DSP041FireVolley(p041CarrelloWeaponIndex, tic, facingYawMilli,
                cooldownMultiplierMilli, 1000);
        DSP041AdvanceTic(tic);
        int acceptedHitsDelta = dsp041AcceptedHits - hitsBefore;
        int acceptedDamageDelta = dsp041AcceptedDamageMilli - damageBefore;
        if (acceptedDamageDelta > 0)
        {
            if (damageDealt > 2147483647 - acceptedDamageDelta)
                Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P041_MAP16_DAMAGE_TOTAL_OVERFLOW tic=%d total=%d delta=%d", tic, damageDealt, acceptedDamageDelta);
            else
            {
                AddDamageDealt(acceptedDamageDelta);
                Console.Printf("DS_P041_MAP16_DAMAGE_CREDIT tic=%d accepted_hits_delta=%d accepted_hits_total=%d accepted_delta_milli=%d total_milli=%d authority=DSP041_P025_CHECKED_LOGICAL_HITS", tic, acceptedHitsDelta, dsp041AcceptedHits, acceptedDamageDelta, damageDealt);
            }
        }
    }

    // Little Hearts are collected in the pickup phase, per the frozen
    // same-tic order (docs/contracts/auras-healing.md "Healing authority and
    // same-tic order"): contact damage -> weapons (P039 aura included, in
    // LogicalTic's existing phase order after ProcessP038GroundWeapons) ->
    // weapon-triggered heals -> pickups (including Little Hearts) ->
    // Recovery on its own boundary. Reuses VerticalSlice's own COLLECT_RADIUS
    // (24.0), matching P027's established pickup-collection radius.
    void CollectP039Hearts()
    {
        if (!p039RouteEnabled && !rsActive) return;
        int maxHealthMilli = CurrentPlayerHealthCap();
        for (int i = 0; i < DSP039HeartCount(); i++)
        {
            if (!DSP039HeartActiveAt(i)) continue;
            double dx = dsp039HeartX[i] - playerX;
            double dy = dsp039HeartY[i] - playerY;
            // Normal play: hearts inside the pickup range drift to the player.
            double d = sqrt(dx * dx + dy * dy);
            if (rsActive && d > COLLECT_RADIUS && d <= AttractRadius())
            {
                dsp039HeartX[i] -= dx / d * 6.0; dsp039HeartY[i] -= dy / d * 6.0;
                continue;
            }
            if (dx * dx + dy * dy > COLLECT_RADIUS * COLLECT_RADIUS) continue;
            int healthAfter; int appliedMilli;
            bool accepted = DSP039ApplyHeal(SOURCE_LITTLE_HEART,
                dsp039HeartHealMilli[i], tic, runState == STATE_ACTIVE,
                playerHealth, maxHealthMilli, healthAfter, appliedMilli);
            playerHealth = healthAfter;
            health[playerSlot] = playerHealth;
            if (accepted)
            {
                DSP039CollectHeartAt(i, tic);
                if (appliedMilli > 0) DSP039FeedSoulEaterGrowth(appliedMilli, tic);
                if (rsActive) { Sfx(DSSfx.I_HEART, 4); FxCount("heart_heal", appliedMilli); }
            }
        }
    }

    // Recovery applies on its own 35-tic boundary, after pickups, per the
    // frozen order. The request is skipped entirely (not merely rejected)
    // when resolved Recovery is 0, so a MAP16 route that never enables P039
    // -- and therefore never grants Pummarola -- logs nothing new here.
    void ProcessP039Recovery()
    {
        if ((!p039RouteEnabled && !rsActive) || runState != STATE_ACTIVE) return;
        int recoveryMilli = rsActive ? rsRecoveryMilli : DSP033Resolved(DSP033StatRules.STAT_RECOVERY);
        if (recoveryMilli <= 0) return;
        int due = DSP039RecoveryDue(tic, recoveryMilli);
        if (due <= 0) return;
        int maxHealthMilli = CurrentPlayerHealthCap();
        int healthAfter; int appliedMilli;
        DSP039ApplyHeal(SOURCE_RECOVERY, due, tic, true, playerHealth,
            maxHealthMilli, healthAfter, appliedMilli);
        playerHealth = healthAfter;
        health[playerSlot] = playerHealth;
        if (appliedMilli > 0) DSP039FeedSoulEaterGrowth(appliedMilli, tic);
    }

    void EmitP033Map16SaveStateIfReady()
    {
        if (!p033RouteEnabled || !p032RouteEnabled || p033SaveStateEmitted
            || runState != STATE_ACTIVE || modalPlayOpen || ActiveDraftQueueCount() != 0
            || levelUpChoices <= 0 || p032ChestId <= 0
            || DSP032Rank(DSP032_ID_BLOODY_TEAR) <= 0
            || DSP031Rank(DSP031_ID_HOLLOW_HEART) <= 0
            || weaponSlot < 0 || weaponSlot >= ids.Size()
            || !ValidParts(weaponSlot, generations[weaponSlot], ids[weaponSlot])) return;
        CVar saveSnapshot = CVar.FindCVar("ds_p033_save_snapshot_request");
        if (saveSnapshot == null || saveSnapshot.GetInt() == 0) return;
        int spinach = DSP031Rank(DSP028_ID_POWER);
        int armor = DSP031Rank(DSP028_ID_ARMOR);
        int hollowHeart = DSP031Rank(DSP031_ID_HOLLOW_HEART);
        int emptyTome = DSP031Rank(DSP031_ID_EMPTY_TOME);
        int sourceRankHash = DSP033StatRules.RankHash(spinach, armor,
            hollowHeart, emptyTome);
        int chestTx = p032ChestId * 10 + 1;
        if (sourceRankHash != dsp033ResolvedRankHash
            || !DSP032HasTransaction(chestTx)
            || DSP032ChestQueueCount() != 0
            || DSP032AppliedRewardCount(p032ChestId) != DSP032ChestSlots(p032ChestId))
        {
            Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P033_MAP16_SAVE_STATE_PRECONDITION tic=%d source_rank_hash=%d resolved_rank_hash=%d chest_tx=%d has_tx=%d chest_queue=%d", tic, sourceRankHash, dsp033ResolvedRankHash, chestTx, DSP032HasTransaction(chestTx), DSP032ChestQueueCount());
            return;
        }
        p033SaveStateEmitted = true;
        p033SaveSnapshotHeld = true;
        ClearNativeInput();
        Console.Printf("DS_P033_MAP16_SAVE_STATE accepted=1 source=POST_TRANSFORM_AND_DRAFT source_rank_hash=%d resolved_rank_hash=%d p031_hash=%d p032_hash=%d chest_hash=%d spinach_rank=%d armor_rank=%d hollow_heart_rank=%d empty_tome_rank=%d might_milli=%d armor=%d max_health_milli=%d cooldown_multiplier_milli=%d weapon_id=%d weapon_generation=%d weapon_item_id=%d weapon_rank=%d chest_id=%d chest_tx=%d logical_tic=%d health=%d run_state=%s", sourceRankHash, dsp033ResolvedRankHash, DSP031StateHash(), DSP032InventoryHash(), DSP032ChestStateHash(), spinach, armor, hollowHeart, emptyTome, DSP033Resolved(DSP033StatRules.STAT_MIGHT), DSP033Resolved(DSP033StatRules.STAT_ARMOR), DSP033Resolved(DSP033StatRules.STAT_MAX_HEALTH), DSP033Resolved(DSP033StatRules.STAT_COOLDOWN), ids[weaponSlot], generations[weaponSlot], DSP032_ID_BLOODY_TEAR, DSP032Rank(DSP032_ID_BLOODY_TEAR), p032ChestId, chestTx, tic, playerHealth, StateName(runState));
    }

    void RestoreP033Map16SavedRun()
    {
        DSP033SetBaseStats(1000, 1, PLAYER_HEALTH, 1000);
        int spinach = DSP031Rank(DSP028_ID_POWER);
        int armor = DSP031Rank(DSP028_ID_ARMOR);
        int hollowHeart = DSP031Rank(DSP031_ID_HOLLOW_HEART);
        int emptyTome = DSP031Rank(DSP031_ID_EMPTY_TOME);
        int sourceRankHash = DSP033StatRules.RankHash(spinach, armor,
            hollowHeart, emptyTome);
        int chestTx = p032ChestId * 10 + 1;
        bool inventoryAccepted = DSP031SyncLegacyStats()
            && RecomputeP033ResolvedStats("SAVE_RESTORE");
        bool weaponAccepted = weaponSlot >= 0 && weaponSlot < ids.Size()
            && ValidParts(weaponSlot, generations[weaponSlot], ids[weaponSlot]);
        bool accepted = p033RouteEnabled && p032RouteEnabled
            && runState == STATE_ACTIVE && tic > 0 && p032ChestId > 0
            && sourceRankHash == dsp033ResolvedRankHash
            && DSP032Rank(DSP032_ID_BLOODY_TEAR) > 0
            && DSP032HasTransaction(chestTx)
            && DSP032ChestQueueCount() == 0 && weaponAccepted
            && inventoryAccepted;
        if (!accepted)
        {
            Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P033_MAP16_RESTORE_REJECTED tic=%d run_state=%s source_rank_hash=%d resolved_rank_hash=%d p031_hash=%d p032_hash=%d chest_hash=%d chest_tx=%d has_tx=%d weapon_valid=%d inventory_valid=%d", tic, StateName(runState), sourceRankHash, dsp033ResolvedRankHash, DSP031StateHash(), DSP032InventoryHash(), DSP032ChestStateHash(), chestTx, DSP032HasTransaction(chestTx), weaponAccepted, inventoryAccepted);
            return;
        }
        SyncPlayer();
        if (playerSlot >= 0 && playerSlot < lifeStates.Size()
            && lifeStates[playerSlot] == STORE_ALIVE)
        {
            int cap = DSP033Resolved(DSP033StatRules.STAT_MAX_HEALTH);
            if (playerHealth > cap) playerHealth = cap;
            health[playerSlot] = playerHealth;
        }
        ClearNativeInput();
        p033SaveSnapshotHeld = false;
        IsUiProcessor = runState == STATE_LEVELUP || runState == STATE_RESULTS;
        SendInterfaceEvent(consoleplayer, "P031_MODE", p031RouteEnabled ? 1 : 0, 0, 0);
        SendInterfaceEvent(consoleplayer, "P032_MAP16_MODE", p032RouteEnabled ? 1 : 0, 1, 0);
        SendInterfaceEvent(consoleplayer, "P033_MAP16_HEALTH_CAP", DSP033Resolved(DSP033StatRules.STAT_MAX_HEALTH), 0, 0);
        SendInterfaceEvent(consoleplayer, "P032_UI_STATE", DSP032AppliedRewardCount(p032ChestId), DSP032InventoryHash(), DSP032ChestQueueCount());
        DSP024Rebuild();
        SyncPresentation();
        PublishUiState();
        EmitInputOwnership(IsUiProcessor ? "SAVE_RESTORE_MODAL" : "SAVE_RESTORE_ACTIVE");
        p033RestorePendingAttack = true;
        Console.Printf("DS_P033_MAP16_RESTORE_STATE accepted=1 source=POST_TRANSFORM_AND_DRAFT source_rank_hash=%d resolved_rank_hash=%d p031_hash=%d p032_hash=%d chest_hash=%d spinach_rank=%d armor_rank=%d hollow_heart_rank=%d empty_tome_rank=%d might_milli=%d armor=%d max_health_milli=%d cooldown_multiplier_milli=%d weapon_id=%d weapon_generation=%d weapon_item_id=%d weapon_rank=%d chest_id=%d chest_tx=%d logical_tic=%d health=%d run_state=%s", sourceRankHash, dsp033ResolvedRankHash, DSP031StateHash(), DSP032InventoryHash(), DSP032ChestStateHash(), spinach, armor, hollowHeart, emptyTome, DSP033Resolved(DSP033StatRules.STAT_MIGHT), DSP033Resolved(DSP033StatRules.STAT_ARMOR), DSP033Resolved(DSP033StatRules.STAT_MAX_HEALTH), DSP033Resolved(DSP033StatRules.STAT_COOLDOWN), ids[weaponSlot], generations[weaponSlot], DSP032_ID_BLOODY_TEAR, DSP032Rank(DSP032_ID_BLOODY_TEAR), p032ChestId, chestTx, tic, playerHealth, StateName(runState));
    }

    bool P037Map16OrbitState(int requiredSystem, out int activeMembers,
        out int activeCohorts, out int ledgerEntries)
    {
        return DSP037ValidateOrbitState(tic, playerSlot,
            playerSlot >= 0 && playerSlot < generations.Size()
                ? generations[playerSlot] : 0,
            playerSlot >= 0 && playerSlot < ids.Size()
                ? ids[playerSlot] : 0,
            requiredSystem, p037WeaponSlot, activeMembers,
            activeCohorts, ledgerEntries);
    }

    int P037Map16RuntimeWeaponIndex()
    {
        for (int i = 0; i < dsp037WeaponActive.Size(); i++)
        {
            if (dsp037WeaponActive[i] != 0
                && dsp037WeaponSlots[i] == p037WeaponSlot
                && p037WeaponSlot >= 0 && p037WeaponSlot < ids.Size()
                && dsp037WeaponGenerations[i]
                    == generations[p037WeaponSlot]
                && dsp037WeaponIds[i] == ids[p037WeaponSlot]) return i;
        }
        return -1;
    }

    int P037Map16RepresentativeMemberIndex()
    {
        for (int i = 0; i < dsp037MemberActive.Size(); i++)
        {
            if (dsp037MemberActive[i] != 0
                && dsp037MemberWeaponSlots[i] == p037WeaponSlot
                && p037WeaponSlot >= 0 && p037WeaponSlot < ids.Size()
                && dsp037MemberWeaponGenerations[i]
                    == generations[p037WeaponSlot]
                && dsp037MemberWeaponIds[i] == ids[p037WeaponSlot]
                && dsp037MemberSystemIds[i]
                    == DSP037OrbitRows.SYSTEM_UNHOLY_VESPERS) return i;
        }
        return -1;
    }

    void EmitP037Map16SaveStateIfRequested()
    {
        if (!p037RouteEnabled || p037SaveStateEmitted
            || runState != STATE_ACTIVE || tic < 350
            || !p037TransformAttempted || p037WeaponSlot < 0
            || p037WeaponSlot >= ids.Size()
            || !ValidParts(p037WeaponSlot, generations[p037WeaponSlot],
                ids[p037WeaponSlot])) return;
        CVar saveRequest = CVar.FindCVar("ds_p033_save_snapshot_request");
        if (saveRequest == null || saveRequest.GetInt() == 0) return;
        int activeMembers; int activeCohorts; int ledgerEntries;
        int runtimeWeapon = P037Map16RuntimeWeaponIndex();
        int representativeMember = P037Map16RepresentativeMemberIndex();
        bool runtimeValid = P037Map16OrbitState(
            DSP037OrbitRows.SYSTEM_UNHOLY_VESPERS, activeMembers,
            activeCohorts, ledgerEntries);
        runtimeValid = runtimeValid && runtimeWeapon >= 0
            && dsp037WeaponSystems[runtimeWeapon]
                == DSP037OrbitRows.SYSTEM_UNHOLY_VESPERS
            && dsp037WeaponRanks[runtimeWeapon] == 1
            && representativeMember >= 0;
        int spinach = DSP031Rank(DSP028_ID_POWER);
        int armor = DSP031Rank(DSP028_ID_ARMOR);
        int hollowHeart = DSP031Rank(DSP031_ID_HOLLOW_HEART);
        int emptyTome = DSP031Rank(DSP031_ID_EMPTY_TOME);
        int sourceRankHash = DSP033StatRules.RankHash(spinach, armor,
            hollowHeart, emptyTome);
        bool statsValid = sourceRankHash == dsp033ResolvedRankHash;
        if (!runtimeValid || !statsValid)
        {
            Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P037_MAP16_SAVE_STATE_PRECONDITION tic=%d runtime_valid=%d active_members=%d active_cohorts=%d ledger_entries=%d source_rank_hash=%d resolved_rank_hash=%d", tic, runtimeValid, activeMembers, activeCohorts, ledgerEntries, sourceRankHash, dsp033ResolvedRankHash);
            return;
        }
        p037SaveStateEmitted = true;
        p037SaveSnapshotHeld = true;
        ClearNativeInput();
        Console.Printf("DS_P037_MAP16_SAVE_STATE accepted=1 source=POST_TRANSFORM system_id=%d rank=%d weapon_id=%d weapon_generation=%d form_generation=%d source_rank_hash=%d resolved_rank_hash=%d p031_hash=%d p032_hash=%d spinach_rank=%d armor_rank=%d hollow_heart_rank=%d empty_tome_rank=%d might_milli=%d cooldown_multiplier_milli=%d orbit_hash=%d active_members=%d active_cohorts=%d ledger_entries=%d member_index=%d cohort_id=%d cohort_generation=%d member=%d member_generation=%d phase_micro_rad=%d phase_remainder=%d window_start_tic=%d window_end_tic=%d last_phase_tic=%d anchor_x_milli=%d anchor_y_milli=%d member_x_milli=%d member_y_milli=%d logical_tic=%d run_state=%s pause_authority=UZDOOM_WORLD_TIC", dsp037WeaponSystems[runtimeWeapon], dsp037WeaponRanks[runtimeWeapon], ids[p037WeaponSlot], generations[p037WeaponSlot], dsp037WeaponFormGenerations[runtimeWeapon], sourceRankHash, dsp033ResolvedRankHash, DSP031StateHash(), DSP032InventoryHash(), spinach, armor, hollowHeart, emptyTome, DSP033Resolved(DSP033StatRules.STAT_MIGHT), DSP033Resolved(DSP033StatRules.STAT_COOLDOWN), DSP037OrbitStateHash(), activeMembers, activeCohorts, ledgerEntries, representativeMember, dsp037MemberCohortIds[representativeMember], dsp037MemberCohortGenerations[representativeMember], dsp037MemberOrdinals[representativeMember], dsp037MemberGenerations[representativeMember], dsp037MemberPhaseMicroRadians[representativeMember], dsp037MemberPhaseRemainders[representativeMember], dsp037MemberWindowStartTics[representativeMember], dsp037MemberWindowEndTics[representativeMember], dsp037MemberLastPhaseTics[representativeMember], int(dsp037MemberAnchorX[representativeMember] * 1000.0), int(dsp037MemberAnchorY[representativeMember] * 1000.0), int(dsp037MemberX[representativeMember] * 1000.0), int(dsp037MemberY[representativeMember] * 1000.0), tic, StateName(runState));
    }

    void RestoreP037Map16SavedRun()
    {
        DSP033SetBaseStats(1000, 1, PLAYER_HEALTH, 1000);
        int oldX = int(playerX * 1000.0);
        int oldY = int(playerY * 1000.0);
        bool statsValid = DSP031SyncLegacyStats()
            && RecomputeP033ResolvedStats("P037_SAVE_RESTORE");
        if (players[0].mo != null)
        {
            double currentX = players[0].mo.Pos.X;
            double currentY = players[0].mo.Pos.Y;
            DSP037RebaseOrbitMembers(currentX - playerX,
                currentY - playerY);
            SyncPlayer();
        }
        int activeMembers; int activeCohorts; int ledgerEntries;
        int runtimeWeapon = P037Map16RuntimeWeaponIndex();
        int representativeMember = P037Map16RepresentativeMemberIndex();
        bool runtimeValid = P037Map16OrbitState(
            DSP037OrbitRows.SYSTEM_UNHOLY_VESPERS, activeMembers,
            activeCohorts, ledgerEntries);
        runtimeValid = runtimeValid && runtimeWeapon >= 0
            && dsp037WeaponSystems[runtimeWeapon]
                == DSP037OrbitRows.SYSTEM_UNHOLY_VESPERS
            && dsp037WeaponRanks[runtimeWeapon] == 1
            && representativeMember >= 0;
        int sourceRankHash = DSP033StatRules.RankHash(
            DSP031Rank(DSP028_ID_POWER), DSP031Rank(DSP028_ID_ARMOR),
            DSP031Rank(DSP031_ID_HOLLOW_HEART),
            DSP031Rank(DSP031_ID_EMPTY_TOME));
        bool accepted = p037RouteEnabled && p037TransformAttempted
            && runState == STATE_ACTIVE && tic >= 350
            && p037SaveStateEmitted && p037SaveSnapshotHeld
            && statsValid && runtimeValid
            && sourceRankHash == dsp033ResolvedRankHash;
        if (!accepted)
        {
            Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P037_MAP16_RESTORE_REJECTED tic=%d run_state=%s transform=%d save_emitted=%d save_held=%d stats_valid=%d runtime_valid=%d active_members=%d active_cohorts=%d ledger_entries=%d source_rank_hash=%d resolved_rank_hash=%d", tic, StateName(runState), p037TransformAttempted, p037SaveStateEmitted, p037SaveSnapshotHeld, statsValid, runtimeValid, activeMembers, activeCohorts, ledgerEntries, sourceRankHash, dsp033ResolvedRankHash);
            return;
        }
        playerHealth = playerHealth < CurrentPlayerHealthCap()
            ? playerHealth : CurrentPlayerHealthCap();
        if (playerSlot >= 0 && playerSlot < health.Size())
            health[playerSlot] = playerHealth;
        p037SaveSnapshotHeld = false;
        p037RestoreAttackPending = true;
        IsUiProcessor = runState == STATE_LEVELUP || runState == STATE_RESULTS;
        ClearNativeInput();
        SendInterfaceEvent(consoleplayer, "P031_MODE", p031RouteEnabled ? 1 : 0, 0, 0);
        SendInterfaceEvent(consoleplayer, "P032_MAP16_MODE", p032RouteEnabled ? 1 : 0, 1, 0);
        SendInterfaceEvent(consoleplayer, "P033_MAP16_HEALTH_CAP", CurrentPlayerHealthCap(), 0, 0);
        SyncPresentation();
        PublishUiState();
        EmitInputOwnership(IsUiProcessor ? "P037_SAVE_RESTORE_MODAL" : "P037_SAVE_RESTORE_ACTIVE");
        Console.Printf("DS_P037_MAP16_RESTORE_STATE accepted=1 source=POST_TRANSFORM system_id=%d rank=%d weapon_id=%d weapon_generation=%d form_generation=%d source_rank_hash=%d resolved_rank_hash=%d p031_hash=%d p032_hash=%d spinach_rank=%d armor_rank=%d hollow_heart_rank=%d empty_tome_rank=%d might_milli=%d cooldown_multiplier_milli=%d orbit_hash=%d active_members=%d active_cohorts=%d ledger_entries=%d member_index=%d cohort_id=%d cohort_generation=%d member=%d member_generation=%d phase_micro_rad=%d phase_remainder=%d window_start_tic=%d window_end_tic=%d last_phase_tic=%d anchor_x_milli=%d anchor_y_milli=%d member_x_milli=%d member_y_milli=%d logical_tic=%d run_state=%s rebased_from_x_milli=%d rebased_from_y_milli=%d player_x_milli=%d player_y_milli=%d", dsp037WeaponSystems[runtimeWeapon], dsp037WeaponRanks[runtimeWeapon], ids[p037WeaponSlot], generations[p037WeaponSlot], dsp037WeaponFormGenerations[runtimeWeapon], sourceRankHash, dsp033ResolvedRankHash, DSP031StateHash(), DSP032InventoryHash(), DSP031Rank(DSP028_ID_POWER), DSP031Rank(DSP028_ID_ARMOR), DSP031Rank(DSP031_ID_HOLLOW_HEART), DSP031Rank(DSP031_ID_EMPTY_TOME), DSP033Resolved(DSP033StatRules.STAT_MIGHT), DSP033Resolved(DSP033StatRules.STAT_COOLDOWN), DSP037OrbitStateHash(), activeMembers, activeCohorts, ledgerEntries, representativeMember, dsp037MemberCohortIds[representativeMember], dsp037MemberCohortGenerations[representativeMember], dsp037MemberOrdinals[representativeMember], dsp037MemberGenerations[representativeMember], dsp037MemberPhaseMicroRadians[representativeMember], dsp037MemberPhaseRemainders[representativeMember], dsp037MemberWindowStartTics[representativeMember], dsp037MemberWindowEndTics[representativeMember], dsp037MemberLastPhaseTics[representativeMember], int(dsp037MemberAnchorX[representativeMember] * 1000.0), int(dsp037MemberAnchorY[representativeMember] * 1000.0), int(dsp037MemberX[representativeMember] * 1000.0), int(dsp037MemberY[representativeMember] * 1000.0), tic, StateName(runState), oldX, oldY, int(playerX * 1000.0), int(playerY * 1000.0));
    }

    void SetupP033Map16ControlledRanks()
    {
        if (!p033RouteEnabled) return;
        DSP031SetFixtureOccupancy(0, 3);
        int hollowGranted = DSP031StageGrant(DSP031_ID_HOLLOW_HEART) ? 1 : 0;
        if (hollowGranted != 0)
        {
            DSP032SetItem(DSP032_ID_HOLLOW_HEART, DSP031Rank(DSP031_ID_HOLLOW_HEART));
            RecomputeP033ResolvedStats("CONTROLLED_STAGE_GRANT_HOLLOW_HEART");
        }
        int spinachGranted = 0;
        int armorGranted = 0;
        for (int rank = 0; rank < 5; rank++)
        {
            if (DSP031StageGrant(DSP028_ID_POWER))
            {
                spinachGranted++;
                RecomputeP033ResolvedStats("CONTROLLED_STAGE_GRANT_SPINACH");
            }
            else break;
        }
        for (int rank = 0; rank < 5; rank++)
        {
            if (DSP031StageGrant(DSP028_ID_ARMOR))
            {
                armorGranted++;
                RecomputeP033ResolvedStats("CONTROLLED_STAGE_GRANT_ARMOR");
            }
            else break;
        }
        int ordinaryBeforeTome = DSP031OrdinaryCount(DSP031_CATEGORY_PASSIVE);
        int tomeGranted = DSP031StageGrant(DSP031_ID_EMPTY_TOME) ? 1 : 0;
        if (tomeGranted != 0) RecomputeP033ResolvedStats("CONTROLLED_STAGE_GRANT_EMPTY_TOME_EXTRA");
        Console.Printf("DS_P033_MAP16_FIXTURE classification=CONTROLLED_STAGE_GRANT omitted_ordinary_passives=3 ordinary_before_tome=%d ordinary_after_tome=%d extra_passive=%d hollow_grants=%d spinach_grants=%d spinach_rank=%d armor_grants=%d armor_rank=%d hollow_heart_rank=%d empty_tome_grants=%d empty_tome_rank=%d graph_hollow_rank=%d source_content_claim=0", ordinaryBeforeTome, DSP031OrdinaryCount(DSP031_CATEGORY_PASSIVE), DSP031ExtraCount(DSP031_CATEGORY_PASSIVE), hollowGranted, spinachGranted, DSP031Rank(DSP028_ID_POWER), armorGranted, DSP031Rank(DSP028_ID_ARMOR), DSP031Rank(DSP031_ID_HOLLOW_HEART), tomeGranted, DSP031Rank(DSP031_ID_EMPTY_TOME), DSP032Rank(DSP032_ID_HOLLOW_HEART));
    }

    bool RecomputeP033ResolvedStats(String source)
    {
        if (!p033RouteEnabled) return true;
        int spinach = DSP031Rank(DSP028_ID_POWER);
        int armorRankForStats = DSP031Rank(DSP028_ID_ARMOR);
        int hollowHeart = DSP031Rank(DSP031_ID_HOLLOW_HEART);
        int emptyTome = DSP031Rank(DSP031_ID_EMPTY_TOME);
        if (!DSP033RecomputeFromRanks(spinach, armorRankForStats,
                hollowHeart, emptyTome)) return false;
        int maxHealth = DSP033Resolved(DSP033StatRules.STAT_MAX_HEALTH);
        if (playerHealth > maxHealth) playerHealth = maxHealth;
        if (playerSlot >= 0 && playerSlot < lifeStates.Size()
            && lifeStates[playerSlot] == STORE_ALIVE)
        {
            health[playerSlot] = playerHealth;
        }
        if (p039RouteEnabled) DSP033RecomputeRecovery(p039PummarolaRank);
        if (p040RouteEnabled) DSP033RecomputeAmountGrowth(2, 5);
        Console.Printf("DS_P033_MAP16_STATE source=%s rank_hash=%d spinach_rank=%d armor_rank=%d hollow_heart_rank=%d empty_tome_rank=%d might_milli=%d armor=%d max_health_milli=%d cooldown_multiplier_milli=%d hp=%d p031_hash=%d p032_hash=%d", source, dsp033ResolvedRankHash, spinach, armorRankForStats, hollowHeart, emptyTome, DSP033Resolved(DSP033StatRules.STAT_MIGHT), DSP033Resolved(DSP033StatRules.STAT_ARMOR), maxHealth, DSP033Resolved(DSP033StatRules.STAT_COOLDOWN), playerHealth, DSP031StateHash(), DSP032InventoryHash());
        SendInterfaceEvent(consoleplayer, "P033_MAP16_HEALTH_CAP", maxHealth, 0, 0);
        return true;
    }
}
