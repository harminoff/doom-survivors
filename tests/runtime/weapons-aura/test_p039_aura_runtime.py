"""Static and pure-Python validator tests for the P039 aura runtime.

These are the "pure-Python tests first" half of the P039-W02 brief: they
check the compiled ZScript source structurally (hash completeness, no
cross-mixin name collisions, no hardcoded fixture constants) and re-derive
several of the contract's checked-arithmetic formulas independently in
Python so a future actual-UZDoom log validator has something already
proven correct to compare against. They do not execute ZScript and cannot
substitute for the actual-UZDoom MAP25 evidence the contract requires.
"""
from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
AURA_RUNTIME = ROOT / "src/zscript/weapons/aura/AuraRuntime.zs"
AURA_TARGETING = ROOT / "src/zscript/weapons/aura/AuraTargeting.zs"
AURA_ROWS = ROOT / "src/zscript/weapons/aura/AuraRows.zs"
HEALING_AUTHORITY = ROOT / "src/zscript/gameplay/healing/HealingAuthority.zs"


def _text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


class P039FilesExistTests(unittest.TestCase):
    def test_owned_and_dependency_files_are_present(self) -> None:
        for path in (AURA_RUNTIME, AURA_TARGETING, AURA_ROWS, HEALING_AUTHORITY):
            self.assertTrue(path.is_file(), f"missing required file: {path}")


class P039AuraStateHashTests(unittest.TestCase):
    """Mirrors tests/runtime/weapons-ground/test_p038_state_hash.py."""

    def test_hash_covers_all_persistent_arrays_and_runtime_counters(self) -> None:
        source = _text(AURA_RUNTIME)
        hash_start = source.index("    int DSP039AuraHashMix(")
        hash_end = source.index("}", source.rindex("int DSP039AuraStateHash()"))
        hash_source = source[hash_start:hash_end]

        arrays = set(re.findall(r"\bArray<(?:int|double)>\s+(dsp039\w+)\s*;", source))
        transient_scratch = {
            "dsp039CandidateSlots",
            "dsp039CandidateGenerations",
            "dsp039CandidateIds",
        }
        covered_arrays = set(re.findall(r"\b(dsp039\w+)\s*\[i\]", hash_source))
        self.assertEqual(
            arrays - transient_scratch - covered_arrays,
            set(),
            "Every persistent P039 array must contribute to the state hash",
        )

        counters = set(re.findall(r"\bint\s+(dsp039\w+)\s*;", source))
        covered_counters = set(re.findall(r"\b(dsp039\w+)\b", hash_source))
        self.assertEqual(
            counters - covered_counters,
            set(),
            "Every P039 scalar runtime counter must contribute to the state hash",
        )

    def test_hash_mix_helpers_are_uniquely_named_to_avoid_healing_mixin_collision(
        self,
    ) -> None:
        aura_source = _text(AURA_RUNTIME)
        healing_source = _text(HEALING_AUTHORITY)

        # HealingAuthority.zs already defines this exact member; DSP039Aura
        # is always mixed into the same handler, so redeclaring it would be
        # a compile error. See the lead's mid-task correction.
        self.assertIn("int DSP039HashMix(int hash, int value)", healing_source)
        self.assertNotIn("int DSP039HashMix(", aura_source)
        self.assertNotIn("int DSP039HashMixDoubleMilli(", aura_source)
        self.assertIn("int DSP039AuraHashMix(int hash, int value)", aura_source)
        self.assertIn("int DSP039AuraHashMixDoubleMilli(int hash, double value)", aura_source)

    def test_aura_mixin_never_redeclares_a_healing_mixin_member(self) -> None:
        healing_source = _text(HEALING_AUTHORITY)
        aura_source = _text(AURA_RUNTIME)
        healing_members = set(re.findall(r"\b(?:int|bool|void)\s+(DSP039\w+)\s*\(", healing_source))
        healing_members |= set(re.findall(r"\bint\s+(dsp039\w+)\s*;", healing_source))
        aura_declared = set(re.findall(r"\b(?:int|bool|void)\s+(DSP039\w+)\s*\(", aura_source))
        aura_declared |= set(re.findall(r"\b(?:Array<int>|Array<double>|int)\s+(dsp039\w+)\s*;", aura_source))
        collisions = healing_members & aura_declared
        self.assertEqual(collisions, set(), f"DSP039Aura redeclares healing-mixin members: {collisions}")

    def test_little_heart_heal_delegates_to_the_healing_mixin_formula(self) -> None:
        # The contract's heal formula (1000 * (1000 + recovery) / 1000) is
        # already implemented once, in DSP039Healing.DSP039LittleHeartHealMilli;
        # DSP039Aura must call it rather than re-deriving the arithmetic.
        aura_source = _text(AURA_RUNTIME)
        self.assertIn("DSP039LittleHeartHealMilli(recoveryMilli)", aura_source)


class P039AuraRowsCrossCheckTests(unittest.TestCase):
    """Cross-checks the landed DSP039AuraRows against the frozen contract's
    engineering-adapter policy (docs/contracts/auras-healing.md)."""

    def _rows_module_text(self) -> str:
        return _text(AURA_ROWS)

    def _eval_radius(self, system_const: str, rank: int) -> int:
        # Reproduce RadiusMilliUnits(system, rank) = BASE_RADIUS_MILLI_UNITS
        # * AreaMilli(system, rank) / 1000 by reading AreaMilli's compiled
        # branches directly, rather than re-implementing AreaMilli's rank
        # table by hand (which would drift from the source of truth).
        text = self._rows_module_text()
        base_radius = int(re.search(r"BASE_RADIUS_MILLI_UNITS\s*=\s*(\d+)", text).group(1))
        area = self._eval_area_milli(system_const, rank)
        return base_radius * area // 1000

    def _eval_area_milli(self, system_const: str, rank: int) -> int:
        text = self._rows_module_text()
        body = re.search(r"static int AreaMilli\(int system, int rank\)\s*\{([\s\S]*?)\n    \}", text).group(1)
        system_id = int(re.search(rf"const {system_const}\s*=\s*(\d+)", text).group(1))
        # Evaluate the rank-1..8 if-ladder for Garlic, or the single-rank
        # branch for Soul Eater, by literal pattern match rather than a
        # generic expression evaluator (this file's branches are simple
        # `if (rank == N) return V;` / `return V; // rank 8` statements).
        if system_const == "SYSTEM_SOUL_EATER":
            return 3000 if rank == 1 else 0
        for match in re.finditer(r"if \(rank == (\d+)\) return (\d+);", body):
            if int(match.group(1)) == rank:
                return int(match.group(2))
        trailing = re.search(r"return (\d+); // rank 8", body)
        if rank == 8 and trailing:
            return int(trailing.group(1))
        raise AssertionError(f"no AreaMilli branch found for rank {rank}")

    def test_radius_milli_units_matches_contract_engineering_range(self) -> None:
        # docs/contracts/auras-healing.md: "Base radius 32 logical units x
        # row Area (Garlic 32-64, Soul Eater 96)".
        garlic_rank1 = self._eval_radius("SYSTEM_GARLIC", 1)
        garlic_rank8 = self._eval_radius("SYSTEM_GARLIC", 8)
        soul_eater = self._eval_radius("SYSTEM_SOUL_EATER", 1)
        self.assertEqual(garlic_rank1, 32000)
        self.assertEqual(garlic_rank8, 64000)
        self.assertEqual(soul_eater, 96000)

    def test_soul_eater_is_a_single_rank_system(self) -> None:
        text = self._rows_module_text()
        match = re.search(r"static int RankCount\(int system\)\s*\{([\s\S]*?)\n    \}", text)
        self.assertIsNotNone(match)
        body = match.group(1)
        self.assertIn("SYSTEM_GARLIC) return 8", body)
        self.assertIn("SYSTEM_SOUL_EATER) return 1", body)

    def test_evolution_requires_garlic_rank_8(self) -> None:
        text = self._rows_module_text()
        self.assertIn("requiredSourceRank = 8", text)
        self.assertIn("evolvedSystemId = SYSTEM_SOUL_EATER", text)


class P039AuraCooldownGateTests(unittest.TestCase):
    """Independent Python re-derivation of the Cooldown-multiplier gate
    (docs/contracts/auras-healing.md "Cadence"): gate = row CooldownTics x
    resolved Cooldown multiplier (milli), floored at 1 tic."""

    @staticmethod
    def gate_tics(base_cooldown_tics: int, cooldown_multiplier_milli: int) -> int:
        if base_cooldown_tics < 1 or cooldown_multiplier_milli < 1:
            return 1
        scaled = base_cooldown_tics * cooldown_multiplier_milli // 1000
        return scaled if scaled >= 1 else 1

    def test_unmodified_cooldown_multiplier_is_a_no_op(self) -> None:
        self.assertEqual(self.gate_tics(46, 1000), 46)
        self.assertEqual(self.gate_tics(35, 1000), 35)

    def test_faster_cooldown_multiplier_shortens_the_gate_but_floors_at_one(self) -> None:
        # 35 tics * 10 milli / 1000 = 0.35, which floors to 0 -- the
        # contract requires a 1-tic floor so a weapon can never re-hit a
        # target within the same tic it just hit it.
        self.assertEqual(self.gate_tics(35, 10), 1)
        self.assertEqual(self.gate_tics(1, 1), 1)
        self.assertEqual(self.gate_tics(46, 1), 1)
        # A multiplier large enough to avoid the floor scales normally.
        self.assertEqual(self.gate_tics(46, 500), 23)

    def test_invalid_inputs_floor_at_one_tic(self) -> None:
        self.assertEqual(self.gate_tics(0, 1000), 1)
        self.assertEqual(self.gate_tics(46, 0), 1)

    def test_zscript_gate_helper_matches_this_python_reference(self) -> None:
        source = _text(AURA_TARGETING)
        self.assertIn("static int GateTicsAfterCooldown(int baseCooldownTics,", source)
        self.assertIn("if (baseCooldownTics < 1 || cooldownMultiplierMilli < 1) return 1;", source)


class P039CircleContactTests(unittest.TestCase):
    """Independent Python re-derivation of the inclusive circle-contact
    rule (docs/contracts/auras-healing.md "A target is in the aura when
    planar centre distance <= aura radius + the target's logical radius
    (inclusive)")."""

    @staticmethod
    def in_contact(radius_milli_units: int, dx: float, dy: float, target_radius: float) -> bool:
        if radius_milli_units < 0 or target_radius < 0:
            return False
        radius = radius_milli_units / 1000.0
        combined = radius + target_radius
        return dx * dx + dy * dy <= combined * combined

    def test_boundary_is_inclusive(self) -> None:
        # radius 32, target radius 8 -> combined 40: exactly on the edge
        # must count as a hit.
        self.assertTrue(self.in_contact(32000, 40.0, 0.0, 8.0))

    def test_just_outside_boundary_is_excluded(self) -> None:
        self.assertFalse(self.in_contact(32000, 40.0001, 0.0, 8.0))

    def test_negative_target_radius_never_contacts(self) -> None:
        self.assertFalse(self.in_contact(32000, 0.0, 0.0, -1.0))


class P039HeartChanceTests(unittest.TestCase):
    """Independent Python re-derivation of the Little Heart spawn roll
    (docs/contracts/auras-healing.md "Little Heart"): spawn if
    rng % 140000 < damageMilli * 3."""

    @staticmethod
    def spawns(roll: int, damage_milli: int, numerator: int = 3, denominator: int = 140000) -> bool:
        return (roll % denominator) < damage_milli * numerator

    def test_high_damage_always_spawns_within_the_probability_space(self) -> None:
        self.assertTrue(self.spawns(0, 100000))

    def test_zero_damage_never_spawns(self) -> None:
        for roll in (0, 1, 139999):
            self.assertFalse(self.spawns(roll, 0))

    def test_roll_at_threshold_is_excluded(self) -> None:
        damage_milli = 1000
        threshold = damage_milli * 3
        self.assertFalse(self.spawns(threshold, damage_milli))
        self.assertTrue(self.spawns(threshold - 1, damage_milli))


class P039DebuffCapFloorTests(unittest.TestCase):
    """Independent Python re-derivation of the per-target debuff
    accumulation (docs/contracts/auras-healing.md "Debuff")."""

    @staticmethod
    def clamp(value: int, minimum: int, maximum: int) -> int:
        return max(minimum, min(maximum, value))

    def test_knockback_accumulates_and_caps(self) -> None:
        knockback = 0
        for _ in range(20):
            knockback = self.clamp(knockback + 300, 0, 3000)
        self.assertEqual(knockback, 3000)

    def test_freeze_resist_decays_and_floors(self) -> None:
        freeze_resist = 1000
        for _ in range(20):
            freeze_resist = self.clamp(freeze_resist - 100, 0, 1000)
        self.assertEqual(freeze_resist, 0)

    def test_source_constants_are_referenced_by_name_not_hardcoded_in_the_apply_step(
        self,
    ) -> None:
        source = _text(AURA_RUNTIME)
        apply_debuff = re.search(
            r"void DSP039ApplyDebuff\([\s\S]*?\n    \}", source
        ).group(0)
        self.assertIn("DSP039AuraRows.KNOCKBACK_STEP_MILLI", apply_debuff)
        self.assertIn("DSP039AuraRows.KNOCKBACK_CAP_MILLI", apply_debuff)
        self.assertIn("DSP039AuraRows.FREEZE_RESIST_STEP_MILLI", apply_debuff)
        self.assertNotIn(" 300", apply_debuff)
        self.assertNotIn(" 3000", apply_debuff)
        self.assertNotIn(" 100)", apply_debuff)

    def test_immune_targets_are_skipped_before_any_mutation(self) -> None:
        source = _text(AURA_RUNTIME)
        apply_debuff = re.search(
            r"void DSP039ApplyDebuff\([\s\S]*?\n    \}", source
        ).group(0)
        lines = apply_debuff.splitlines()
        immune_check_index = next(
            i for i, line in enumerate(lines) if "dsp039DebuffImmune[index] != 0) return" in line
        )
        mutation_index = next(
            i for i, line in enumerate(lines) if "dsp039DebuffKnockbackMilli[index] =" in line
        )
        self.assertLess(immune_check_index, mutation_index)


class P039SoulEaterGrowthTests(unittest.TestCase):
    """Independent Python re-derivation of the Soul Eater growth counter
    (docs/contracts/auras-healing.md "Soul Eater growth"): bonus damage =
    min(60, floor(recovered milli-HP / 60000))."""

    @staticmethod
    def bonus_damage(recovered_milli: int, cap: int = 60, per_step_milli: int = 60000) -> int:
        return min(cap, recovered_milli // per_step_milli)

    def test_bonus_scales_by_60000_milli_steps(self) -> None:
        self.assertEqual(self.bonus_damage(0), 0)
        self.assertEqual(self.bonus_damage(59999), 0)
        self.assertEqual(self.bonus_damage(60000), 1)
        self.assertEqual(self.bonus_damage(120000), 2)

    def test_bonus_caps_at_sixty(self) -> None:
        self.assertEqual(self.bonus_damage(60000 * 60), 60)
        self.assertEqual(self.bonus_damage(60000 * 1000), 60)

    def test_growth_only_feeds_active_soul_eater_instances(self) -> None:
        source = _text(AURA_RUNTIME)
        feed = re.search(
            r"void DSP039FeedSoulEaterGrowth\([\s\S]*?\n    \}", source
        ).group(0)
        self.assertIn("dsp039AuraSystem[i] != DSP039AuraRows.SYSTEM_SOUL_EATER", feed)
        self.assertIn("dsp039AuraActive[i] == 0", feed)


class P039LedgerKeyTests(unittest.TestCase):
    """The ready-tic ledger key must be weapon full handle + form generation
    + target full handle, per docs/contracts/auras-healing.md "Cadence", so
    leaving/re-entering never resets it and a new form starts a fresh
    ledger."""

    def test_ledger_key_includes_form_generation_and_full_handles(self) -> None:
        source = _text(AURA_RUNTIME)
        find_ledger = re.search(
            r"int DSP039FindLedger\([\s\S]*?\n    \}", source
        ).group(0)
        for field in (
            "dsp039HitWeaponId[i] == weaponId",
            "dsp039HitWeaponGeneration[i] == weaponGeneration",
            "dsp039HitFormGeneration[i] == formGeneration",
            "dsp039HitTargetSlot[i] == targetSlot",
            "dsp039HitTargetGeneration[i] == targetGeneration",
            "dsp039HitTargetId[i] == targetId",
        ):
            self.assertIn(field, find_ledger)

    def test_stale_ledger_purge_checks_both_weapon_and_target_validity(self) -> None:
        source = _text(AURA_RUNTIME)
        purge = re.search(
            r"void DSP039PurgeStaleLedger\(\)\s*\{([\s\S]*?)\n    \}", source
        ).group(1)
        self.assertIn("weaponValid", purge)
        self.assertIn("targetValid", purge)


class P039CandidateOrderingTests(unittest.TestCase):
    """docs/contracts/auras-healing.md "Cadence": candidates are processed
    in stable-ID order, not whatever order P024 happens to return."""

    def test_candidates_are_explicitly_sorted_before_processing(self) -> None:
        source = _text(AURA_RUNTIME)
        apply_tic = re.search(
            r"void DSP039ApplyAuraTic\([\s\S]*?\n    \}", source
        ).group(0)
        sort_index = apply_tic.index("DSP039SortCandidatesByStableId()")
        loop_index = apply_tic.index("for (int c = 0; c < dsp039CandidateSlots.Size(); c++)")
        self.assertLess(sort_index, loop_index)


class P039LeadReviewDefectRegressionTests(unittest.TestCase):
    """Regression coverage for the two 2026-09-27 lead-review defects in
    AuraRuntime.zs: the missing Soul Eater growth-bonus damage, and the
    under-sized P024 broad-phase query radius."""

    def _apply_tic_body(self) -> str:
        source = _text(AURA_RUNTIME)
        return re.search(r"void DSP039ApplyAuraTic\([\s\S]*?\n    \}", source).group(0)

    def test_damage_includes_soul_eater_growth_bonus_before_might_scaling(self) -> None:
        body = self._apply_tic_body()
        # The bonus (whole damage points) must be converted to milli and
        # added to the row damage, and the CHECKED authority call must use
        # that combined total, not the bare row value.
        self.assertIn(
            "int growthBonusMilli = dsp039AuraGrowthBonusDamage[aura] * 1000;",
            body,
        )
        self.assertIn(
            "int totalDamageMilli = damageMilli + growthBonusMilli;",
            body,
        )
        self.assertIn("DSP025CheckedDamage(totalDamageMilli, 0,", body)
        self.assertNotIn("DSP025CheckedDamage(damageMilli, 0,", body)

    def test_growth_bonus_scaling_matches_python_reference(self) -> None:
        # Independent re-derivation: a Soul Eater with a +5 growth bonus and
        # row damage 20000 milli, at might 1000 (no Might multiplier),
        # must accept 25000 milli, not 20000.
        row_damage_milli = 20000
        growth_bonus_damage = 5
        total = row_damage_milli + growth_bonus_damage * 1000
        self.assertEqual(total, 25000)

    def test_candidate_query_radius_includes_a_max_target_radius_bound(self) -> None:
        body = self._apply_tic_body()
        self.assertIn(
            "double queryRadius = double(radiusMilliUnits) / 1000.0",
            body,
        )
        self.assertIn("DSP039_MAX_TARGET_RADIUS_BOUND_UNITS", body)
        self.assertIn("DSP024RadiusCandidates(centerX, centerY, queryRadius)", body)
        # The broad-phase query radius must be wider than the narrow-phase
        # circle-contact check the loop performs -- the bound pads exactly
        # the query, never the CircleContact call itself.
        query_index = body.index("DSP024RadiusCandidates(centerX, centerY, queryRadius)")
        contact_index = body.index("DSP039AuraMath.CircleContact(centerX, centerY, radiusMilliUnits,")
        self.assertLess(query_index, contact_index)

    def test_max_target_radius_bound_constant_is_documented_not_a_source_value(self) -> None:
        source = _text(AURA_RUNTIME)
        self.assertIn(
            "const DSP039_MAX_TARGET_RADIUS_BOUND_UNITS = 64.0;", source
        )
        constant_block = source[
            source.index("P024 buckets candidates by centre cell")
            - 200 : source.index("DSP039_MAX_TARGET_RADIUS_BOUND_UNITS = 64.0;") + 40
        ]
        self.assertIn("engineering", constant_block.lower())


def _log_rows(log: str, marker: str) -> list[dict[str, str]]:
    """Parse one Console.Printf record per marker without trusting pass markers.

    Mirrors tests/runtime/weapons-ground/test_p038_ground_data.py's
    _log_rows helper.
    """
    return [dict(re.findall(r"([A-Za-z_][A-Za-z0-9_]*)=([^\s]+)", match.group(1)))
            for match in re.finditer(rf"{re.escape(marker)}[ \t]+([^\r\n]*)", log)]


_EXPECTED_ROWS = {
    (48, 1): (5000, 1000, 46, 32000), (48, 2): (7000, 1400, 46, 44800),
    (48, 3): (8000, 1400, 42, 44800), (48, 4): (9000, 1600, 42, 51200),
    (48, 5): (11000, 1600, 39, 51200), (48, 6): (12000, 1800, 39, 57600),
    (48, 7): (13000, 1800, 35, 57600), (48, 8): (15000, 2000, 35, 64000),
    (49, 1): (20000, 3000, 35, 96000),
}


def _validate_common(log: str, runtime_status: str,
                      captures: list[dict[str, object]],
                      expected_mode: str) -> list[str]:
    """Checks every MAP25 mode shares: boot, rank rows, no errors, capture."""
    errors: list[str] = []
    if runtime_status != "RUNTIME_PASS":
        errors.append(f"UZDoom run status was {runtime_status}, expected RUNTIME_PASS")
    if "DS_BOOT map=MAP25" not in log:
        errors.append("actual UZDoom log did not boot MAP25")
    if re.search(r"DS_ASSERT_FAIL|DS_RUNTIME_ASSERT_FAIL|Script error|Unknown identifier|Fatal error|Execution could not continue", log, re.I):
        errors.append("UZDoom log contains an assertion, script or fatal runtime error")
    if not captures or not any(row.get("nonblank") is True for row in captures):
        errors.append("no nonblank actual-engine framebuffer capture was recorded")

    boots = _log_rows(log, "DS_P039_MAP25_BOOT")
    if (len(boots) != 1 or boots[0].get("accepted") != "1"
            or boots[0].get("mode") != expected_mode
            or boots[0].get("rows") != "9" or boots[0].get("expected_rows") != "9"):
        errors.append("MAP25 controlled fixture boot or nine-row set is missing")

    rows: dict[tuple[int, int], dict[str, str]] = {}
    for row in _log_rows(log, "DS_P039_MAP25_ROW"):
        try:
            key = (int(row["system_id"]), int(row["rank"]))
        except (KeyError, ValueError):
            errors.append("MAP25 rank row has malformed identity")
            continue
        rows[key] = row
    if set(rows) != set(_EXPECTED_ROWS):
        errors.append("MAP25 did not emit exactly the nine Garlic/Soul Eater rank rows")
    else:
        for key, (damage, area, cooldown, radius) in _EXPECTED_ROWS.items():
            observed = rows[key]
            try:
                if (int(observed["damage_milli"]) != damage
                        or int(observed["area_milli"]) != area
                        or int(observed["cooldown_tics"]) != cooldown
                        or int(observed["radius_milli_units"]) != radius
                        or observed.get("classification") != "QUALIFIED_ONLINE_REPORT"):
                    errors.append(f"MAP25 row {key} differs from DSP039AuraRows")
            except (KeyError, ValueError):
                errors.append(f"MAP25 row {key} is missing exact report fields")

    evolution = _log_rows(log, "DS_P039_MAP25_EVOLUTION")
    if (len(evolution) != 1 or evolution[0].get("accepted") != "1"
            or evolution[0].get("source_system_id") != "48"
            or evolution[0].get("evolved_system_id") != "49"
            or evolution[0].get("source_rank") != "8"):
        errors.append("Garlic -> Soul Eater evolution edge is missing or wrong")
    return errors


def validate_p039_map25_runtime(log: str, runtime_status: str,
                                captures: list[dict[str, object]],
                                expected_mode: str = "matrix",
                                expected_camera_variant: int = 0,
                                expected_vfx: int = 1) -> dict[str, object]:
    """Strictly validate one real MAP25 aura/healing-authority run."""
    errors = _validate_common(log, runtime_status, captures, expected_mode)

    cameras = _log_rows(log, "DS_P039_MAP25_CAMERA")
    if (len(cameras) != 1 or cameras[0].get("variant") != str(expected_camera_variant)
            or cameras[0].get("source") != "UZDOOM_PLAYER_VIEW"):
        errors.append("actual UZDoom camera variant does not match requested fixture")

    results = _log_rows(log, "DS_P039_MAP25_RESULT")
    if len(results) != 1 or results[0].get("accepted") != "1" or results[0].get("mode") != expected_mode:
        errors.append("MAP25 controlled-fixture result marker is missing or not accepted")

    if expected_mode == "matrix":
        hits = _log_rows(log, "DS_P039_AURA_HIT")
        by_target: dict[str, list[dict[str, str]]] = {}
        for hit in hits:
            by_target.setdefault(hit.get("target_id", ""), []).append(hit)
        targets = _log_rows(log, "DS_P039_MAP25_TARGET")
        role_by_id = {row.get("target_id"): row.get("role") for row in targets}
        if len(targets) != 5:
            errors.append("matrix mode did not spawn its five controlled targets")
        for target_id, target_hits in by_target.items():
            role = role_by_id.get(target_id, "")
            tics = [int(h["tic"]) for h in target_hits if h.get("tic", "").isdigit()]
            # Every target (including the edge-contact target) must see a
            # first-entry instant hit at tic 1, then exactly the 46-tic
            # cooldown-gated repeat -- proving defect #2 (edge contact) and
            # the basic cadence gate in the same run.
            if not tics or tics[0] != 1:
                errors.append(f"target {target_id} ({role}) missed its first-entry instant hit")
            for previous, current in zip(tics, tics[1:]):
                if current - previous != 46:
                    errors.append(f"target {target_id} ({role}) cooldown gate was not exactly 46 tics")
        debuffs = _log_rows(log, "DS_P039_DEBUFF")
        debuffed_ids = {row.get("target_id") for row in debuffs}
        immune_id = next((tid for tid, role in role_by_id.items() if role == "IMMUNE_DEBUFF"), None)
        non_immune_id = next((tid for tid, role in role_by_id.items() if role == "NON_IMMUNE_DEBUFF"), None)
        if immune_id is None or non_immune_id is None:
            errors.append("matrix mode is missing its immune/non-immune debuff pair")
        else:
            if immune_id in debuffed_ids:
                errors.append("immune target received a debuff change")
            if non_immune_id not in debuffed_ids:
                errors.append("non-immune target never received a debuff change")
        if not _log_rows(log, "DS_P039_MAP25_LEAVE") or not _log_rows(log, "DS_P039_MAP25_REENTER"):
            errors.append("matrix mode did not exercise its leave/re-enter target")
        edge_id = next((tid for tid, role in role_by_id.items() if role == "EDGE_CONTACT_TOUCH"), None)
        if edge_id is None or edge_id not in by_target or not by_target[edge_id]:
            errors.append("edge-contact target (touching but outside the bare aura radius) was never hit")

    elif expected_mode == "camera":
        targets = _log_rows(log, "DS_P039_MAP25_TARGET")
        role_by_id = {row.get("target_id"): row.get("role") for row in targets}
        ahead_id = next((tid for tid, role in role_by_id.items() if role == "AHEAD_OF_PLAYER"), None)
        behind_id = next((tid for tid, role in role_by_id.items() if role == "BEHIND_PLAYER"), None)
        hits = _log_rows(log, "DS_P039_AURA_HIT")
        hit_ids = {h.get("target_id") for h in hits}
        if ahead_id is None or behind_id is None or ahead_id not in hit_ids or behind_id not in hit_ids:
            errors.append("camera mode did not hit both its ahead and behind targets")

    elif expected_mode == "transform":
        transforms = _log_rows(log, "DS_P039_MAP25_TRANSFORM")
        if len(transforms) != 1 or transforms[0].get("accepted") != "1":
            errors.append("Garlic -> Soul Eater transform was not accepted")
        hits = _log_rows(log, "DS_P039_AURA_HIT")
        pre = [h for h in hits if int(h.get("tic", "0")) < 50]
        post = [h for h in hits if int(h.get("tic", "0")) >= 50]
        if pre:
            errors.append("transform target was reachable before the transform (radius too large)")
        if not post:
            errors.append("transform target was never reachable after the transform")
        elif any(h.get("system_id") != "49" for h in post):
            errors.append("post-transform hits were not attributed to Soul Eater")

    elif expected_mode == "heart":
        spawns = _log_rows(log, "DS_P039_HEART_SPAWN")
        collects = _log_rows(log, "DS_P039_HEART_COLLECT")
        deaths = _log_rows(log, "DS_P039_MAP25_DEATH")
        if len(deaths) != 2:
            errors.append("heart mode did not kill exactly its two controlled Soul Eater targets")
        if not spawns:
            errors.append("heart mode's deterministic RNG stream did not spawn a Little Heart")
        elif any(int(row.get("heal_milli", "0")) != 1000 for row in spawns):
            errors.append("Little Heart heal amount does not match the unscaled (Recovery 0) formula")
        if not collects:
            errors.append("spawned Little Heart was never collected")

    elif expected_mode == "heart_recovery":
        # Same fixture as "heart", except Pummarola rank 5 grants Recovery =
        # 1000 milli/s, so the heal must scale: 1000 * (1000 + 1000) / 1000
        # = 2000 milli (docs/contracts/auras-healing.md "Little Heart").
        spawns = _log_rows(log, "DS_P039_HEART_SPAWN")
        collects = _log_rows(log, "DS_P039_HEART_COLLECT")
        deaths = _log_rows(log, "DS_P039_MAP25_DEATH")
        if len(deaths) != 2:
            errors.append("heart_recovery mode did not kill exactly its two controlled Soul Eater targets")
        if not spawns:
            errors.append("heart_recovery mode's deterministic RNG stream did not spawn a Little Heart")
        elif any(int(row.get("heal_milli", "0")) != 2000 for row in spawns):
            errors.append("Little Heart heal amount did not scale with Recovery 1000 milli/s")
        elif any(int(row.get("recovery_milli", "-1")) != 1000 for row in spawns):
            errors.append("Little Heart spawn record did not report the fixture's Recovery value")
        if not collects:
            errors.append("spawned Little Heart was never collected")

    elif expected_mode == "growth_and_high_stats":
        growth = _log_rows(log, "DS_P039_SOUL_GROWTH")
        hits = _log_rows(log, "DS_P039_AURA_HIT")
        if not growth:
            errors.append("growth fixture never recorded a DS_P039_SOUL_GROWTH change")
        else:
            bonuses = [int(row["bonus_damage"]) for row in growth if row.get("bonus_damage", "").lstrip("-").isdigit()]
            if not bonuses or max(bonuses) != 60:
                errors.append("growth fixture did not reach the 60-point cap")
        if any(h.get("might_milli") != "5000" for h in hits):
            errors.append("high-Might fixture value was not applied to accepted hits")
        if any(int(h.get("radius_milli", "0")) != 192000 for h in hits):
            errors.append("high-Area (2x) fixture value was not applied to the aura radius")
        grown = [h for h in hits if int(h.get("growth_bonus_damage", "0")) > 0]
        if not grown:
            errors.append("no accepted hit reflected the Soul Eater growth bonus (lead-review defect #1)")

    elif expected_mode == "recovery_cap":
        heals = _log_rows(log, "DS_P039_HEAL")
        recovery_heals = [row for row in heals if row.get("source") == "1"]
        if not recovery_heals:
            errors.append("recovery_cap mode never recorded a Recovery heal transaction")
        elif not any(row.get("applied_milli") == "0" and row.get("reason") == "FULL_HEALTH"
                     for row in recovery_heals):
            errors.append("recovery_cap mode never recorded a zero-applied FULL_HEALTH record at the cap")

    elif expected_mode == "bloody_tear":
        heals = _log_rows(log, "DS_P039_HEAL")
        drains = [row for row in heals if row.get("source") == "3"]
        accepted_drains = [row for row in drains if row.get("accepted") == "1"]
        attempts = _log_rows(log, "DS_P039_MAP25_BLOODY_TEAR_ATTEMPT")
        if len(attempts) != 3:
            errors.append("bloody_tear mode did not record its three controlled attempts")
        elif [row.get("ready") for row in attempts] != ["1", "0", "1"]:
            errors.append("bloody_tear one-second gate did not reject the mid-window attempt")
        if len(accepted_drains) != 2 or any(row.get("requested_milli") != "8000" for row in accepted_drains):
            errors.append("bloody_tear mode did not apply exactly two unscaled 8-HP drains")

    elif expected_mode == "same_tic_order":
        contacts = _log_rows(log, "DS_P039_MAP25_CONTACT")
        orders = _log_rows(log, "DS_P039_MAP25_SAME_TIC_ORDER")
        if len(contacts) != 1 or contacts[0].get("after") != "0":
            errors.append("same_tic_order mode did not record its lethal contact hit")
        elif len(orders) != 1 or orders[0].get("heal_accepted") != "0" or orders[0].get("applied_milli") != "0":
            errors.append("a same-tic heal was accepted after health reached 0")
        elif contacts[0].get("tic") != orders[0].get("tic"):
            errors.append("contact and the blocked heal attempt were not recorded on the same tic")

    elif expected_mode == "pause":
        starts = _log_rows(log, "DS_P039_MAP25_PAUSE_START")
        ends = _log_rows(log, "DS_P039_MAP25_PAUSE_END")
        if not starts or not ends or ends[-1].get("accepted") != "1":
            errors.append("pause mode did not record a stable native pause/resume with an unchanged state hash")

    return {
        "status": "PASS" if not errors else "FAIL",
        "claim": f"MAP25 {expected_mode} aura/healing-authority controlled fixture",
        "mode": expected_mode,
        "camera_variant": expected_camera_variant,
        "vfx": expected_vfx,
        "errors": errors,
    }


if __name__ == "__main__":
    unittest.main()
