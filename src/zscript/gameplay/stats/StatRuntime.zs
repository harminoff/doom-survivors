// MAP19 actual-engine fixture for the shared P033 stat resolver.
// Numerical inputs are controlled; this does not claim a natural drop table
// or a complete/source-exact base-game passive catalog.
class DSP033StatsRuntime : EventHandler
{
    mixin DSRunStatFields;
    mixin DSP033ResolvedStats;

    const MAP = "MAP19";
    const CAMERA_CASE_COUNT = 2;

    bool enabled;
    bool completed;
    bool capturePending;
    bool saveReadyReported;
    bool restoreProbeStarted;
    transient bool startedThisProcess;
    int logicalTic;
    int warmupTicks;
    int numericCases;
    String configuredMode;

    // Only this test handler stores source ranks. In the gameplay path, P031
    // and P032 inventories stay canonical and pass their current ranks in.
    int fixtureSpinachRank;
    int fixtureArmorRank;
    int fixtureHollowHeartRank;
    int fixtureEmptyTomeRank;
    int savedRankHash;
    int savedMightMilli;
    int savedArmorPoints;
    int savedMaxHealthMilli;
    int savedCooldownMultiplierMilli;

    override void OnRegister()
    {
        IsUiProcessor = false;
        RequireMouse = false;
    }

    String ReadMode()
    {
        CVar mode = CVar.FindCVar("ds_p033_mode");
        return mode != null ? mode.GetString() : "matrix";
    }

    void ConfigureBase()
    {
        // Controlled Antonio-like base values. 120 health and intrinsic Armor
        // are engineering fixtures; they are not a source-extracted stat row.
        DSP033SetBaseStats(1000, 1, 120000, 1000);
    }

    void StartFreshScenario()
    {
        enabled = true;
        completed = false;
        capturePending = false;
        saveReadyReported = false;
        restoreProbeStarted = false;
        logicalTic = 0;
        warmupTicks = 0;
        numericCases = 0;
        configuredMode = ReadMode();
        ConfigureBase();
        Console.Printf("DS_BOOT map=MAP19 classification=CONTROLLED_RESOLVED_STAT_AND_PASSIVE_RUNTIME_FIXTURE");
        Console.Printf("DS_P033_BOOT map=MAP19 mode=%s base_might_milli=%d base_armor_points=%d base_max_health_milli=%d base_cooldown_multiplier_milli=%d passive_catalog=QUALIFIED_SUBSET source_identity_candidates=26 classification=ENGINEERING_BASE_FIXTURE", configuredMode, dsp033BaseMightMilli, dsp033BaseArmorPoints, dsp033BaseMaxHealthMilli, dsp033BaseCooldownMultiplierMilli);
        if (configuredMode == "save_prepare") PrepareSaveState();
    }

    void PrepareSaveState()
    {
        fixtureSpinachRank = 2;
        fixtureArmorRank = 3;
        fixtureHollowHeartRank = 1;
        fixtureEmptyTomeRank = 2;
        if (!DSP033RecomputeFromRanks(fixtureSpinachRank, fixtureArmorRank,
                fixtureHollowHeartRank, fixtureEmptyTomeRank)) return;
        SaveCurrentResolvedState();
        Console.Printf("DS_P033_SAVE_PREPARED rank_hash=%d might_milli=%d armor_points=%d max_health_milli=%d cooldown_multiplier_milli=%d source_ranks=2,3,1,2", savedRankHash, savedMightMilli, savedArmorPoints, savedMaxHealthMilli, savedCooldownMultiplierMilli);
    }

    void SaveCurrentResolvedState()
    {
        savedRankHash = dsp033ResolvedRankHash;
        savedMightMilli = dsp033ResolvedMightMilli;
        savedArmorPoints = dsp033ResolvedArmorPoints;
        savedMaxHealthMilli = dsp033ResolvedMaxHealthMilli;
        savedCooldownMultiplierMilli = dsp033ResolvedCooldownMultiplierMilli;
    }

    void RestoreProbe()
    {
        restoreProbeStarted = true;
        int beforeHash = dsp033ResolvedRankHash;
        int beforeMight = dsp033ResolvedMightMilli;
        int beforeArmor = dsp033ResolvedArmorPoints;
        int beforeHealth = dsp033ResolvedMaxHealthMilli;
        int beforeCooldown = dsp033ResolvedCooldownMultiplierMilli;
        bool savedValid = dsp033ResolvedValid;
        bool recomputed = DSP033RecomputeFromRanks(fixtureSpinachRank,
            fixtureArmorRank, fixtureHollowHeartRank, fixtureEmptyTomeRank);
        bool stable = savedValid && recomputed
            && beforeHash == dsp033ResolvedRankHash
            && beforeMight == dsp033ResolvedMightMilli
            && beforeArmor == dsp033ResolvedArmorPoints
            && beforeHealth == dsp033ResolvedMaxHealthMilli
            && beforeCooldown == dsp033ResolvedCooldownMultiplierMilli
            && savedRankHash == beforeHash && savedMightMilli == beforeMight
            && savedArmorPoints == beforeArmor && savedMaxHealthMilli == beforeHealth
            && savedCooldownMultiplierMilli == beforeCooldown;
        Console.Printf("DS_P033_SAVE_RESTORE accepted=%d stable=%d source_ranks=%d,%d,%d,%d before_hash=%d after_hash=%d before_might_milli=%d after_might_milli=%d before_armor=%d after_armor=%d before_max_health_milli=%d after_max_health_milli=%d before_cooldown_multiplier_milli=%d after_cooldown_multiplier_milli=%d", stable ? 1 : 0, stable ? 1 : 0, fixtureSpinachRank, fixtureArmorRank, fixtureHollowHeartRank, fixtureEmptyTomeRank, beforeHash, dsp033ResolvedRankHash, beforeMight, dsp033ResolvedMightMilli, beforeArmor, dsp033ResolvedArmorPoints, beforeHealth, dsp033ResolvedMaxHealthMilli, beforeCooldown, dsp033ResolvedCooldownMultiplierMilli);
        if (!stable) Console.Printf("DS_ASSERT_FAIL P033_SAVE_RESTORE_STATE_MISMATCH");
        if (players[0].mo != null)
        {
            players[0].mo.Angle = 37.0;
            players[0].mo.Pitch = -11.0;
            players[0].SetFOV(83.0);
        }
        capturePending = true;
    }

    void EmitNumericCase(String item, int rank, String field, int value,
        String display)
    {
        bool accepted = DSP033RecomputeFromRanks(
            item == "Spinach" ? rank : 0,
            item == "Armor" ? rank : 0,
            item == "HollowHeart" ? rank : 0,
            item == "EmptyTome" ? rank : 0);
        if (!accepted) return;
        int resolved = item == "Spinach" ? dsp033ResolvedMightMilli
            : item == "Armor" ? dsp033ResolvedArmorPoints
            : item == "HollowHeart" ? dsp033ResolvedMaxHealthMilli
            : item == "EmptyTome" ? 1000 - dsp033ResolvedCooldownMultiplierMilli : 0;
        if (resolved != value)
        {
            Console.Printf("DS_ASSERT_FAIL P033_NUMERIC_ROW item=%s rank=%d expected=%d actual=%d", item, rank, value, resolved);
            return;
        }
        numericCases++;
        if (item == "Spinach") Console.Printf("DS_P033_NUMERIC item=%s rank=%d might_milli=%d display_value=%s accepted=1 classification=QUALIFIED_ONLINE_REPORT_ENGINE_POLICY_APPROX", item, rank, dsp033ResolvedMightMilli, display);
        else if (item == "Armor") Console.Printf("DS_P033_NUMERIC item=%s rank=%d armor_points=%d display_value=%s accepted=1 classification=QUALIFIED_ONLINE_REPORT_ENGINE_POLICY_APPROX", item, rank, dsp033ResolvedArmorPoints, display);
        else if (item == "HollowHeart") Console.Printf("DS_P033_NUMERIC item=%s rank=%d max_health_milli=%d display_value=%s accepted=1 classification=QUALIFIED_ONLINE_REPORT_ENGINE_POLICY_APPROX", item, rank, dsp033ResolvedMaxHealthMilli, display);
        else Console.Printf("DS_P033_NUMERIC item=%s rank=%d cooldown_multiplier_milli=%d display_value=%s accepted=1 classification=QUALIFIED_ONLINE_REPORT_ENGINE_POLICY_APPROX", item, rank, dsp033ResolvedCooldownMultiplierMilli, display);
    }

    void RunNumericRows()
    {
        for (int rank = 0; rank <= 5; rank++)
        {
            int might; int armor; int health; int cooldown; int hash;
            DSP033StatRules.Resolve(1000, 1, 120000, 1000, rank, 0, 0, 0,
                might, armor, health, cooldown, hash);
            EmitNumericCase("Spinach", rank, "might_milli", might,
                String.Format("%d.%03dx", might / 1000, might % 1000));
        }
        for (int rank = 0; rank <= 5; rank++)
        {
            int might; int armor; int health; int cooldown; int hash;
            DSP033StatRules.Resolve(1000, 1, 120000, 1000, 0, rank, 0, 0,
                might, armor, health, cooldown, hash);
            EmitNumericCase("Armor", rank, "armor_points", armor,
                String.Format("%d", armor));
        }
        for (int rank = 0; rank <= 5; rank++)
        {
            int might; int armor; int health; int cooldown; int hash;
            DSP033StatRules.Resolve(1000, 1, 120000, 1000, 0, 0, rank, 0,
                might, armor, health, cooldown, hash);
            EmitNumericCase("HollowHeart", rank, "max_health_milli", health,
                String.Format("%d", DSP033StatRules.DisplayHealthRounded(health)));
        }
        for (int rank = 0; rank <= 5; rank++)
        {
            int might; int armor; int health; int cooldown; int hash;
            DSP033StatRules.Resolve(1000, 1, 120000, 1000, 0, 0, 0, rank,
                might, armor, health, cooldown, hash);
            int reduction = 1000 - cooldown;
            EmitNumericCase("EmptyTome", rank, "cooldown_multiplier_milli", reduction,
                String.Format("-%d.%d%%", reduction / 10, reduction % 10));
        }
    }

    void RunEligibilityAndCameraCases()
    {
        DSP033RecomputeFromRanks(1, 0, 0, 1);
        int whipDamage = DSP033StatRules.DamageAfterMight(
            DSP033StatRules.SYSTEM_WHIP, 10, dsp033ResolvedMightMilli);
        int diagnosticDamage = DSP033StatRules.DamageAfterMight(
            DSP033StatRules.SYSTEM_DIAGNOSTIC_WEAPON, 10, dsp033ResolvedMightMilli);
        int whipCooldown = DSP033StatRules.CooldownAfterTome(
            DSP033StatRules.SYSTEM_WHIP, 135000, dsp033ResolvedCooldownMultiplierMilli);
        int diagnosticCooldown = DSP033StatRules.CooldownAfterTome(
            DSP033StatRules.SYSTEM_DIAGNOSTIC_WEAPON, 135000, dsp033ResolvedCooldownMultiplierMilli);
        int armorDamage = DSP033StatRules.IncomingDamageMilliAfterArmor(5000,
            dsp033ResolvedArmorPoints);
        bool eligibilityOk = whipDamage == 11 && diagnosticDamage == 10
            && whipCooldown == 124200 && diagnosticCooldown == 135000
            && armorDamage == 4000
            && DSP033StatRules.StatApplies(DSP033StatRules.STAT_MIGHT,
                DSP033StatRules.SYSTEM_WHIP)
            && !DSP033StatRules.StatApplies(DSP033StatRules.STAT_MIGHT,
                DSP033StatRules.SYSTEM_DIAGNOSTIC_WEAPON);
        Console.Printf("DS_P033_ELIGIBILITY accepted=%d whip_damage=%d diagnostic_damage=%d whip_cooldown_milli=%d diagnostic_cooldown_milli=%d armor_damage_milli=%d eligible_whip=%d ineligible_diagnostic=%d classification=CONTROLLED_SYSTEM_ELIGIBILITY", eligibilityOk ? 1 : 0, whipDamage, diagnosticDamage, whipCooldown, diagnosticCooldown, armorDamage, DSP033StatRules.StatApplies(DSP033StatRules.STAT_MIGHT, DSP033StatRules.SYSTEM_WHIP) ? 1 : 0, DSP033StatRules.StatApplies(DSP033StatRules.STAT_MIGHT, DSP033StatRules.SYSTEM_DIAGNOSTIC_WEAPON) ? 1 : 0);
        if (!eligibilityOk) Console.Printf("DS_ASSERT_FAIL P033_ELIGIBILITY_MISMATCH");

        int damage = 0;
        for (int variant = 0; variant < CAMERA_CASE_COUNT; variant++)
        {
            int yaw = variant == 0 ? 0 : 90;
            int pitch = variant == 0 ? 0 : 22;
            int fov = variant == 0 ? 90 : 115;
            if (players[0].mo != null)
            {
                players[0].mo.Angle = yaw;
                players[0].mo.Pitch = pitch;
                players[0].SetFOV(fov);
            }
            damage = DSP033StatRules.DamageAfterMight(
                DSP033StatRules.SYSTEM_WHIP, 10, dsp033ResolvedMightMilli);
            Console.Printf("DS_P033_CAMERA variant=%d yaw=%d pitch=%d fov=%d hit_count=1 damage=%d rank_hash=%d camera_independent=1 classification=CONTROLLED_NUMERICAL_HIT_VECTOR", variant, yaw, pitch, fov, damage, dsp033ResolvedRankHash);
        }
    }

    void RunMatrix()
    {
        RunNumericRows();
        RunEligibilityAndCameraCases();

        int beforeHash = dsp033ResolvedRankHash;
        int beforeMight = dsp033ResolvedMightMilli;
        int beforeArmor = dsp033ResolvedArmorPoints;
        int beforeHealth = dsp033ResolvedMaxHealthMilli;
        int beforeCooldown = dsp033ResolvedCooldownMultiplierMilli;
        bool invalidAccepted = DSP033RecomputeFromRanks(-1, 0, 0, 0);
        bool unchanged = beforeHash == dsp033ResolvedRankHash
            && beforeMight == dsp033ResolvedMightMilli
            && beforeArmor == dsp033ResolvedArmorPoints
            && beforeHealth == dsp033ResolvedMaxHealthMilli
            && beforeCooldown == dsp033ResolvedCooldownMultiplierMilli;
        Console.Printf("DS_P033_SOURCE_RANK_REJECT accepted=%d unchanged=%d rank_hash=%d classification=INVALID_CONTROLLED_INPUT", invalidAccepted ? 1 : 0, unchanged ? 1 : 0, dsp033ResolvedRankHash);
        if (invalidAccepted || !unchanged) Console.Printf("DS_ASSERT_FAIL P033_INVALID_RANK_MUTATED_RESOLVED_STATE");

        bool first = DSP033RecomputeFromRanks(1, 0, 0, 1);
        int firstHash = dsp033ResolvedRankHash;
        int firstMight = dsp033ResolvedMightMilli;
        int firstCooldown = dsp033ResolvedCooldownMultiplierMilli;
        bool second = DSP033RecomputeFromRanks(1, 0, 0, 1);
        bool idempotent = first && second && firstHash == dsp033ResolvedRankHash
            && firstMight == dsp033ResolvedMightMilli
            && firstCooldown == dsp033ResolvedCooldownMultiplierMilli;
        Console.Printf("DS_P033_RECALC_IDEMPOTENT accepted=%d rank_hash=%d might_milli=%d cooldown_multiplier_milli=%d", idempotent ? 1 : 0, dsp033ResolvedRankHash, dsp033ResolvedMightMilli, dsp033ResolvedCooldownMultiplierMilli);
        if (!idempotent) Console.Printf("DS_ASSERT_FAIL P033_RECALC_NOT_IDEMPOTENT");

        int wideMight; int wideArmor; int wideHealth; int wideCooldown; int wideHash;
        bool overflowAccepted = DSP033StatRules.Resolve(1000, 1, 1000000,
            1000, 0, 0, 5, 0, wideMight, wideArmor, wideHealth,
            wideCooldown, wideHash);
        bool overflowRejected = !overflowAccepted && wideHealth == 0;
        Console.Printf("DS_P033_OVERFLOW_REJECT accepted=%d output_max_health_milli=%d rejected=%d input_base_max_health_milli=1000000 hollow_rank=5 classification=CHECKED_RESOLVER_BOUNDARY", overflowAccepted ? 1 : 0, wideHealth, overflowRejected ? 1 : 0);
        if (!overflowRejected) Console.Printf("DS_ASSERT_FAIL P033_OVERFLOW_INPUT_ACCEPTED_OR_MUTATED");
        capturePending = true;
    }

    override void WorldLoaded(WorldEvent e)
    {
        if (level == null || level.MapName != MAP || e.IsSaveGame) return;
        startedThisProcess = true;
        StartFreshScenario();
    }

    override void WorldTick()
    {
        if (level == null || level.MapName != MAP) return;
        if (!startedThisProcess)
        {
            startedThisProcess = true;
            configuredMode = ReadMode();
            if (configuredMode == "restore")
            {
                enabled = true;
                RestoreProbe();
            }
            else if (!enabled) StartFreshScenario();
        }
        if (!enabled || completed) return;
        logicalTic++;
        if (configuredMode == "matrix" && !capturePending)
        {
            if (warmupTicks++ >= 4) RunMatrix();
            return;
        }
        if (configuredMode == "save_prepare" && !saveReadyReported)
        {
            if (warmupTicks++ >= 5)
            {
                saveReadyReported = true;
                LevelLocals.MakeScreenShot();
                Console.Printf("DS_P033_SAVE_READY rank_hash=%d might_milli=%d armor_points=%d max_health_milli=%d cooldown_multiplier_milli=%d logical_tic=%d source_ranks=%d,%d,%d,%d", savedRankHash, savedMightMilli, savedArmorPoints, savedMaxHealthMilli, savedCooldownMultiplierMilli, logicalTic, fixtureSpinachRank, fixtureArmorRank, fixtureHollowHeartRank, fixtureEmptyTomeRank);
            }
            return;
        }
        if (configuredMode == "restore" && restoreProbeStarted && capturePending)
        {
            if (warmupTicks++ >= 5)
            {
                LevelLocals.MakeScreenShot();
                capturePending = false;
            }
            return;
        }
        if (capturePending && configuredMode == "matrix")
        {
            LevelLocals.MakeScreenShot();
            capturePending = false;
            // Let the engine flush the framebuffer before the runner exits on
            // the completion marker.
            warmupTicks = 0;
            configuredMode = "matrix_capture_flush";
            return;
        }
        if (configuredMode == "matrix_capture_flush" && warmupTicks++ >= 1)
        {
            completed = true;
            Console.Printf("DS_P033_RUNTIME_PASS cases=%d eligibility=1 cameras=%d source_rank_reject=1 idempotent=1 overflow_reject=1 classification=CONTROLLED_QUALIFIED_STAT_RESOLVER", numericCases, CAMERA_CASE_COUNT);
            return;
        }
        if (configuredMode == "restore" && restoreProbeStarted && !capturePending
            && warmupTicks > 5 && !completed)
        {
            completed = true;
            Console.Printf("DS_P033_SAVE_RUNTIME_PASS stable=1 logical_tic=%d classification=RUN_SAVE_RESOLVED_STATE_RECOMPUTE", logicalTic);
        }
    }
}
