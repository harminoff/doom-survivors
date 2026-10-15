"""Strict MAP16 P040 (logical-screen strike/erasure/global-effect) run and
save/reload validators.

Models tests/runtime/weapons-aura/test_p039_map16.py's structure and rigor
level for the new opt-in P040 MAP16 route (VerticalSlice.zs
ProcessP040GlobalWeapons/TryP040Map16LoopTransform/TryP040Map16MoonTransform
and the Duplicator/Crown Amount/Growth fixture).
"""
from __future__ import annotations

import re
import unittest
from collections import defaultdict
from pathlib import Path
from tools import slice_source

ROOT = Path(__file__).resolve().parents[3]
VERTICAL_SLICE = ROOT / "src/zscript/gameplay/VerticalSlice.zs"


def _rows(log: str, marker: str) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for line in log.splitlines():
        if line.startswith(marker + " "):
            rows.append(dict(re.findall(r"([A-Za-z_][A-Za-z0-9_]*)=(\S+)", line)))
    return rows


def validate_p040_map16_runtime(
    log: str, runtime_status: str,
    captures: list[dict[str, object]] | None = None,
) -> dict[str, object]:
    """Join MAP16 strike hits/erasures to the checked-damage/erase
    authority and result credit, confirm both fixed-tic transforms, the
    erase-vs-kill disjoint counters, and coexistence with the rest of the
    automatic arsenal."""
    errors: list[str] = []
    boot = _rows(log, "DS_P030_BOOT")
    route = _rows(log, "DS_P040_MAP16_BOOT")
    fixture = _rows(log, "DS_P040_MAP16_FIXTURE")
    transforms = _rows(log, "DS_P040_MAP16_TRANSFORM")
    if len(boot) != 1 or boot[0].get("map") != "MAP16" or boot[0].get("mode") != "p040":
        errors.append("process did not boot the opt-in P040 MAP16 route")
    if len(route) != 1 or route[0].get("route") != "OPT_IN_P040":
        errors.append("P040 MAP16 route marker is missing or duplicated")
    if len(fixture) != 1:
        errors.append("controlled MAP16 global-strike fixture marker is missing or duplicated")
    elif (fixture[0].get("accepted") != "1" or fixture[0].get("lightning_rank") != "8"
          or fixture[0].get("pentagram_rank") != "8"
          or fixture[0].get("duplicator_rank") != "2"
          or fixture[0].get("crown_rank") != "5"
          or int(fixture[0].get("resolved_amount", "0")) <= 0
          or int(fixture[0].get("resolved_growth_milli", "0")) <= 0
          or fixture[0].get("source_inventory_claim") != "0"):
        errors.append("MAP16 equipment or controlled Duplicator/Crown provenance is invalid")

    loop_transforms = [r for r in transforms if r.get("kind") == "LOOP"]
    moon_transforms = [r for r in transforms if r.get("kind") == "MOON"]
    loop_tic = -1
    moon_tic = -1
    if len(loop_transforms) != 1 or loop_transforms[0].get("accepted") != "1":
        errors.append("Lightning Ring -> Thunder Loop transform is missing, rejected or duplicated")
    else:
        loop_tic = int(loop_transforms[0].get("tic", "-1"))
    if len(moon_transforms) != 1 or moon_transforms[0].get("accepted") != "1":
        errors.append("Pentagram -> Gorgeous Moon transform is missing, rejected or duplicated")
    else:
        moon_tic = int(moon_transforms[0].get("tic", "-1"))

    hits_by_tic: dict[int, int] = defaultdict(int)
    accepted_events: set[str] = set()
    hits = [row for row in _rows(log, "DS_P040_STRIKE_HIT") if row.get("accepted") == "1"]
    for row in hits:
        try:
            event = row["event_id"]
            tic = int(row["tic"])
            system = int(row["system_id"])
            before = int(row["before"])
            after = int(row["after"])
            delta = before - after
            scaled = int(row["scaled_milli"])
            if event in accepted_events:
                errors.append(f"duplicate P040 accepted strike-hit event {event}")
            accepted_events.add(event)
            if row.get("authority") != "P025_CHECKED_LOGICAL_HIT":
                errors.append(f"P040 event {event} bypassed the checked P025 authority")
            if system not in (50, 51):
                errors.append(f"P040 strike event {event} has out-of-scope system {system}")
            if delta < 0 or delta > scaled:
                errors.append(f"P040 event {event} has inconsistent accepted damage")
            hits_by_tic[tic] += delta
        except (KeyError, ValueError):
            errors.append("an accepted P040 strike hit omitted its checked-damage join fields")

    erase_rows = _rows(log, "DS_P040_ERASE_ENEMY")
    erased_ids = {row.get("stable_id") for row in erase_rows}
    death_ids = {row.get("target_id") for row in _rows(log, "DS_P039_MAP16_HEART_FIXTURE_REPOSITION")}
    # A P040-caused kill reaches the SAME HandleEnemyDeath every other family
    # uses (VerticalSlice's own DS_P030 kill accounting), which has no
    # per-event target-id marker of its own here; the real, provable
    # disjointness check is that no stable_id ever appears in BOTH the
    # erase-op log and the strike-hit "killed=1" log (an entity cannot be
    # both erased and struck-killed).
    strike_kill_ids = {row.get("target_id") for row in hits if row.get("killed") == "1"}
    if erased_ids & strike_kill_ids:
        errors.append("an entity was both erased and struck-killed: " + repr(erased_ids & strike_kill_ids))
    if not any(row.get("killed") == "1" for row in hits) and not _rows(log, "DS_P040_MOON_BEAM"):
        errors.append("no P040 strike/beam kill was ever observed")

    # Contract-required sequencing: a real Pentagram erasure with spare
    # rolls on pickups BEFORE the tic=170 Moon transform, then a real Moon
    # phase 1 (beam kill) + phase 2 (erasure, gems, attraction) AFTER it.
    # The MAP16 fixture retimes each form's first activation as a labelled
    # controlled offset (DS_P040_MAP16_FIXTURE/DS_P040_MAP16_TRANSFORM's own
    # retimed_activation_tic field), never a resolved Cooldown value.
    # DS_P040_ERASE_ENEMY has no tic field of its own; join through the
    # same-tic DS_P040_PENTAGRAM_FIRE/DS_P040_MOON_PHASE2 markers instead.
    pentagram_fires = _rows(log, "DS_P040_PENTAGRAM_FIRE")
    spare_rolls = _rows(log, "DS_P040_ERASE_ROLL")
    moon_phase1 = _rows(log, "DS_P040_MOON_PHASE1")
    moon_phase2 = _rows(log, "DS_P040_MOON_PHASE2")
    pre_transform_pentagram_erasures = sum(
        int(r.get("erased_enemies", "0")) for r in pentagram_fires
        if moon_tic < 0 or int(r.get("tic", "-1")) < moon_tic)
    pre_transform_spare_rolls = [r for r in spare_rolls
                                 if moon_tic < 0 or int(r.get("tic", "-1")) < moon_tic]
    post_transform_beam_kills = [r for r in _rows(log, "DS_P040_MOON_BEAM")
                                  if moon_tic >= 0 and int(r.get("tic", "-1")) >= moon_tic]
    post_transform_phase2 = [r for r in moon_phase2
                              if moon_tic >= 0 and int(r.get("tic", "-1")) >= moon_tic]
    if pre_transform_pentagram_erasures < 1:
        errors.append("no Pentagram erasure was observed before the Moon transform")
    if not pre_transform_spare_rolls:
        errors.append("no Pentagram spare roll on a pickup was observed before the Moon transform")
    if not moon_phase1 or not post_transform_beam_kills:
        errors.append("no Gorgeous Moon phase-1 beam kill was observed after the transform")
    if not post_transform_phase2:
        errors.append("no Gorgeous Moon phase-2 activation was observed after the transform")
    else:
        gems = sum(int(r.get("gems_created", "0")) for r in post_transform_phase2)
        attracted = sum(int(r.get("attracted_pickups", "0")) for r in post_transform_phase2)
        post_transform_erasures = sum(int(r.get("erased_enemies", "0")) for r in post_transform_phase2)
        if post_transform_erasures < 1:
            errors.append("Gorgeous Moon phase-2 never erased a surviving enemy")
        if gems < 1:
            errors.append("Gorgeous Moon phase-2 never created a gem")
        if attracted < 1:
            errors.append("Gorgeous Moon phase-2 never attracted a pickup")

    levelup_choices = [r for r in _rows(log, "DS_P030_LEVELUP_CHOICE") if r.get("accepted") == "1"]
    levelup_resumes = _rows(log, "DS_P030_LEVELUP_RESUME")
    if not levelup_choices or not levelup_resumes:
        errors.append("no level-up queued by P040 XP/Growth was resolved through P028")

    # P040-A03: a single Gorgeous Moon vacuum's pickup collection must be
    # able to queue >=2 level-ups at once (Draft.zs's DSP031CollectExperience
    # while-loop crossing multiple DSP031ThresholdForCurrentLevel boundaries
    # in one call), and P028 must apply every queued level exactly once,
    # in order, with the correct remaining-XP carry -- not skip or
    # duplicate any of them. The controlled 100,000-milli pickup dropped by
    # TryP040Map16BigGemFixture (DS_P040_MAP16_BIG_GEM_FIXTURE) is what
    # makes this reachable in a bounded run; real Moon gems alone
    # (3,000 milli each here) are far too small to cross even one
    # threshold.
    big_gem = _rows(log, "DS_P040_MAP16_BIG_GEM_FIXTURE")
    if not big_gem or big_gem[0].get("accepted") != "1":
        errors.append("the P040-A03 large-vacuum XP fixture was never spawned")
    else:
        def _threshold(level: int) -> int:
            if level < 1:
                return 0
            if level <= 20:
                return 5000 + (level - 1) * 10000
            if level <= 40:
                return 195000 + (level - 20) * 13000
            return 455000 + (level - 40) * 16000

        multi = [r for r in _rows(log, "DS_P031_XP_COLLECT") if int(r.get("crossed", "0")) >= 2]
        if not multi:
            errors.append("no single P028 collection queued >=2 level-ups at once (P040-A03)")
        else:
            row = multi[-1]
            try:
                before_level = int(row["before_level"]); after_level = int(row["after_level"])
                crossed = int(row["crossed"]); before_xp = int(row["before_xp"])
                after_xp = int(row["after_xp"]); amount = int(row["amount"])
                if after_level - before_level != crossed:
                    errors.append("P040-A03 crossed count does not match before/after level delta")
                expected_after = before_xp + amount
                for level in range(before_level, after_level):
                    expected_after -= _threshold(level)
                if expected_after != after_xp:
                    errors.append(f"P040-A03 remaining-XP carry is wrong: expected {expected_after}, got {after_xp}")
            except (KeyError, ValueError):
                errors.append("malformed P040-A03 DS_P031_XP_COLLECT row")
                before_level = after_level = -1

            expected_levels = list(range(before_level + 1, after_level + 1))
            enqueued_levels = [int(r["target_level"]) for r in _rows(log, "DS_P031_DRAFT_ENQUEUE")
                                if int(r.get("target_level", "-1")) in expected_levels]
            if sorted(enqueued_levels) != sorted(expected_levels) or len(enqueued_levels) != len(set(enqueued_levels)):
                errors.append(f"P040-A03 queued levels were skipped or duplicated: enqueued={enqueued_levels} expected={expected_levels}")

            # DS_P030_LEVELUP_CHOICE's own "level" field is playerLevel,
            # which DSP031CollectExperience already advanced to its FINAL
            # value (after_level) for every crossed threshold in that one
            # collection -- it is identical on all `crossed` choices and
            # cannot distinguish which queued level each choice resolves.
            # queue_remaining is the real per-choice discriminator: applying
            # each queued level exactly once, in order, produces the exact
            # descending run crossed-1, crossed-2, ..., 0, with the final 0
            # immediately followed by DS_P030_LEVELUP_RESUME (queue fully
            # drained, no level skipped or resolved twice).
            accepted_after = [r for r in levelup_choices
                               if int(r.get("level", "-1")) == after_level]
            remainders = [int(r["queue_remaining"]) for r in accepted_after[-crossed:]] \
                if len(accepted_after) >= crossed else []
            if len(accepted_after) < crossed:
                errors.append(f"P040-A03 expected {crossed} accepted choices at level={after_level}, found {len(accepted_after)}")
            elif remainders != list(range(crossed - 1, -1, -1)):
                errors.append(f"P040-A03 queue_remaining sequence was not a clean drain: {remainders}")
            if not levelup_resumes or int(levelup_resumes[-1].get("level", "-1")) != after_level:
                errors.append("P040-A03 queue was not confirmed fully drained by a matching DS_P030_LEVELUP_RESUME")

    credits_by_tic: dict[int, int] = defaultdict(int)
    for row in _rows(log, "DS_P040_MAP16_DAMAGE_CREDIT"):
        try:
            if row.get("authority") != "DSP040_P025_CHECKED_LOGICAL_HITS":
                errors.append("MAP16 P040 result credit names a noncanonical authority")
            credits_by_tic[int(row["tic"])] += int(row["accepted_delta_milli"])
        except (KeyError, ValueError):
            errors.append("malformed MAP16 P040 accepted-damage credit")
    if dict(credits_by_tic) != dict(hits_by_tic):
        errors.append("per-tic P040 P025 accepted strike damage does not reconcile to MAP16 result credit")

    erase_credits = _rows(log, "DS_P040_MAP16_ERASE_CREDIT")
    total_erase_credit = sum(int(r["erased_delta"]) for r in erase_credits if r.get("erased_delta", "").lstrip("-").isdigit())
    if total_erase_credit != len(erase_rows):
        errors.append("MAP16 erase credit total does not reconcile to the number of erase-op events")

    # ds_p032_mode=evolution (the same run flags P039's own validated full
    # run uses) converts Whip into Bloody Tear early, after which
    # DS_P030_WHIP legitimately stops -- confirmed by diffing against an
    # actual P039 full-run log, which checks for Bloody Tear here for the
    # same reason, not for Whip. Checking for Whip in this mode is the
    # wrong marker, not a P040 regression.
    coexistence = {
        "whip-or-bloody-tear": _rows(log, "DS_P030_WHIP")
            + [r for r in _rows(log, "DS_P032_BLOODY_TEAR_HIT") if r.get("accepted", "1") == "1"],
        "aura": [r for r in _rows(log, "DS_P039_AURA_HIT") if r.get("accepted") == "1"],
        "aimed weapons": [r for r in _rows(log, "DS_P034_HIT") if r.get("accepted") == "1"],
    }
    for family, rows in coexistence.items():
        if not rows:
            errors.append(f"concurrent MAP16 automatic arsenal has no accepted {family} hit")

    growth_rows = _rows(log, "DS_P040_MAP16_GROWTH_COLLECT")
    if not growth_rows:
        errors.append("no Growth-at-collection bonus was ever observed")
    else:
        for row in growth_rows:
            try:
                base = int(row["base_milli"]); growth = int(row["growth_milli"])
                bonus = int(row["bonus_milli"]); credited = int(row["credited_milli"])
                if bonus != base * growth // 1000 or credited != base + bonus:
                    errors.append("Growth-at-collection arithmetic is inconsistent")
            except (KeyError, ValueError):
                errors.append("malformed Growth-at-collection marker")

    return {
        "status": "PASS" if not errors else "FAIL", "errors": errors,
        "loop_transform_tic": loop_tic, "moon_transform_tic": moon_tic,
        "erased_total": len(erase_rows), "strike_hits": len(hits),
    }


def validate_p040_map16_default(log: str) -> dict[str, object]:
    """The default manual route must be completely untouched by P040."""
    errors: list[str] = []
    boot = _rows(log, "DS_P030_BOOT")
    if len(boot) != 1 or boot[0].get("map") != "MAP16" or boot[0].get("mode") != "manual":
        errors.append("default regression did not boot the P030 manual route")
    for marker in ("DS_P040_MAP16_BOOT", "DS_P040_MAP16_FIXTURE",
                   "DS_P040_MAP16_TRANSFORM", "DS_P040_STRIKE_HIT",
                   "DS_P040_ERASE_ENEMY", "DS_P040_MAP16_DAMAGE_CREDIT",
                   "DS_P040_MAP16_ERASE_CREDIT", "DS_P040_MAP16_GROWTH_COLLECT",
                   "DS_P040_MOON_BEAM", "DS_P040_MOON_PHASE1", "DS_P040_MOON_PHASE2",
                   "DS_P040_AMOUNT_GROWTH_RECOMPUTE"):
        if _rows(log, marker):
            errors.append(f"default manual route unexpectedly emitted {marker}")
    return {"status": "PASS" if not errors else "FAIL", "errors": errors}


def validate_p040_map16_save_roundtrip(
    save_log: str, restore_log: str,
    save_exit_code: int | None, restore_exit_code: int | None,
) -> dict[str, object]:
    """Extends the shared P038 hash gate with the P040 addition
    (global-strike state hash + the independent RankHashAmountGrowth),
    gated on p040_route_enabled."""
    errors: list[str] = []
    if save_exit_code != 0 or restore_exit_code != 0:
        errors.append("save/restore engine sessions did not both quit cleanly")
    if "DS_P030_BOOT map=MAP16" not in save_log or "DS_P040_MAP16_BOOT" not in save_log:
        errors.append("save process did not boot the opt-in P040 MAP16 path")
    saved_rows = _rows(save_log, "DS_P038_MAP16_SAVE_STATE")
    restored_rows = _rows(restore_log, "DS_P038_MAP16_RESTORE_STATE")
    if len(saved_rows) != 1 or len(restored_rows) != 1:
        errors.append("save/load did not emit exactly one combined save and restore state marker")
    saved = saved_rows[0] if len(saved_rows) == 1 else {}
    restored = restored_rows[0] if len(restored_rows) == 1 else {}
    if saved and saved.get("run_state") != "ACTIVE":
        errors.append("snapshot is not an active run state")
    if restored and (restored.get("accepted") != "1" or restored.get("p040_route_enabled") != "1"):
        errors.append("restore was not accepted with the P040 route enabled")
    invariants = ("weapon_id", "weapon_generation", "form_generation",
                  "source_rank_hash", "resolved_rank_hash",
                  "global_hash", "rank_hash_amount_growth",
                  "spinach_rank", "armor_rank", "hollow_heart_rank", "empty_tome_rank",
                  "might_milli", "cooldown_multiplier_milli", "logical_tic", "run_state")
    if saved and restored:
        for key in invariants:
            if key not in saved or key not in restored or saved[key] != restored[key]:
                errors.append(f"saved P038/P040/P033 state field {key} changed across restore")
        saved_key = "saved_global_hash"
        if saved_key not in restored:
            errors.append("restore marker omitted saved_global_hash")
        elif restored.get("global_hash") != restored.get(saved_key):
            errors.append("restored global_hash does not equal its saved value (exact-equality gate failed)")
        elif saved.get("global_hash") != restored.get(saved_key):
            errors.append("restored marker lost the original saved global_hash")
        saved_growth_key = "saved_rank_hash_amount_growth"
        if saved_growth_key not in restored:
            errors.append("restore marker omitted saved_rank_hash_amount_growth")
        elif restored.get("rank_hash_amount_growth") != restored.get(saved_growth_key):
            errors.append("restored rank_hash_amount_growth does not equal its saved value")
    return {"status": "PASS" if not errors else "FAIL", "errors": errors}


class TestP040Map16Validators(unittest.TestCase):
    def test_vertical_slice_has_p040_route(self) -> None:
        text = slice_source.read()
        self.assertIn("p040RouteEnabled", text)
        self.assertIn("mixin DSP040Global", text)
        self.assertIn("ProcessP040GlobalWeapons", text)
        self.assertIn("DSP040GlobalStateHash", text)
        self.assertIn("dsp033ResolvedRankHashAmountGrowth", text)

    def test_default_validator_flags_unexpected_marker(self) -> None:
        log = 'DS_P030_BOOT map=MAP16 mode=manual\nDS_P040_MAP16_BOOT route=OPT_IN_P040\n'
        report = validate_p040_map16_default(log)
        self.assertFalse(report["errors"] == [])

    def test_default_validator_accepts_clean_manual_route(self) -> None:
        log = "DS_P030_BOOT map=MAP16 mode=manual\n"
        report = validate_p040_map16_default(log)
        self.assertEqual(report["status"], "PASS")

    def test_runtime_validator_requires_boot(self) -> None:
        report = validate_p040_map16_runtime("no markers here", "RUNTIME_PASS")
        self.assertFalse(report["status"] == "PASS")


if __name__ == "__main__":
    unittest.main()
