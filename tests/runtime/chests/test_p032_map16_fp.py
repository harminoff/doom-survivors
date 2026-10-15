"""Strict MAP16 validator for the opt-in P032 Whip evolution route."""
from __future__ import annotations

import re
import math
import unittest


def _rows(log: str, marker: str) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for match in re.finditer(rf"{re.escape(marker)}[ \t]+([^\r\n]*)", log):
        rows.append(dict(re.findall(r"([A-Za-z_][A-Za-z0-9_]*)=([^\s]+)", match.group(1))))
    return rows


def _int(row: dict[str, str], key: str) -> int | None:
    try:
        return int(row[key])
    except (KeyError, ValueError):
        return None


def _float(row: dict[str, str], key: str) -> float | None:
    try:
        return float(row[key])
    except (KeyError, ValueError):
        return None


def validate_map16_p032(log: str) -> dict[str, object]:
    """Require live MAP16 chest input, modal transaction and weapon replacement evidence."""
    errors: list[str] = []
    if "DS_P030_BOOT map=MAP16" not in log or "mode=p032" not in log:
        errors.append("MAP16 did not boot through the opt-in P032 route")
    if "DS_P032_MAP16_BOOT route=OPT_IN_P032" not in log:
        errors.append("the controlled P032 MAP16 route was not installed")
    boot = next(iter(_rows(log, "DS_P030_BOOT")), {})
    if _int(boot, "logical_steps") != 1 or boot.get("normal_speed") != "1":
        errors.append("the MAP16 runtime was not proven at one logical step per engine tic")
    if "DS_P032_MAP16_FIXTURE" not in log or "natural_levelup_claim=0" not in log:
        errors.append("the Whip/Hollow Heart starting fixture was not qualified")
    if re.search(r"Script error|Unknown identifier|Execution could not continue|Fatal error|DS_RUNTIME_ASSERT_FAIL", log, re.I):
        errors.append("the engine reported a script failure or runtime assertion")

    spawns = _rows(log, "DS_P032_CHEST_SPAWN")
    visuals = _rows(log, "DS_P032_MAP16_CHEST_SPAWN")
    proximity = _rows(log, "DS_P032_MAP16_CHEST_PROXIMITY")
    movement_tape = _rows(log, "DS_P032_MAP16_MOVEMENT_TAPE")
    pickups = [row for row in _rows(log, "DS_P032_CHEST_PICKUP") if row.get("accepted") == "1"]
    ui_open = _rows(log, "DS_P032_UI_OPEN")
    intents = _rows(log, "DS_P032_UI_INTENT")
    confirms = [row for row in _rows(log, "DS_P032_MAP16_CONFIRM") if row.get("accepted") == "1"]
    transforms = [row for row in _rows(log, "DS_P032_TRANSFORM") if row.get("accepted") == "1"]
    rewards = [row for row in _rows(log, "DS_P032_CHEST_REWARD") if row.get("accepted") == "1"]
    completed = [row for row in _rows(log, "DS_P032_CHEST_COMPLETE") if row.get("accepted") == "1"]
    replacements = [row for row in _rows(log, "DS_P032_MAP16_WEAPON_REPLACE") if row.get("accepted") == "1"]

    if not spawns:
        errors.append("the MAP16 route did not spawn a recorded chest")
    elif not any(row.get("subtype") == "SILVER" and row.get("transform_eligible") == "1"
                 and row.get("classification") == "CONTROLLED_SOURCE_RECORD" for row in spawns):
        errors.append("the controlled source-time Silver eligibility was not recorded")
    if not any(row.get("accepted") == "1" and row.get("visual_spawned") == "1"
               and row.get("visual_exact") == "0" for row in visuals):
        errors.append("the controlled chest pickup marker was not spawned and qualified")
    if not proximity:
        errors.append("the MAP16 body-proximity pickup trigger is missing")
    elif not any(row.get("accepted") == "1" and row.get("facing_away") == "1"
                 and row.get("source") == "P021_BODY_RADIUS" and row.get("use_pressed") == "0"
                 and row.get("eye_aimed") == "0" for row in proximity):
        errors.append("the chest was not picked up by the body-radius path while behind the facing")
    if not any(row.get("source") == "ENGINE_TAPE_P021_BODY" and row.get("move_player") == "1"
               and (_float(row, "travel") or 0.0) > 0.0 for row in movement_tape):
        errors.append("the controlled tape did not move the actual P021 body adapter")
    if not pickups:
        errors.append("the chest authority rejected or never received the nearby chest")
    if not ui_open:
        errors.append("the actual chest UI did not open")
    if not intents:
        errors.append("the chest UI did not submit a confirmation intent")
    elif not any(row.get("source") in ("PHYSICAL_KEY", "ENGINE_TAPE") for row in intents):
        errors.append("the chest choice did not come through a physical or engine input boundary")
    if not confirms:
        errors.append("MAP16 did not commit a UI confirmation through its chest authority")
    if not transforms:
        errors.append("the named Whip evolution was not accepted")
    if not rewards:
        errors.append("the chest reward slot was not recorded after the recipe commit")
    if not completed:
        errors.append("the chest transaction did not complete exactly once")
    if len(rewards) != 1 or len(completed) != 1:
        errors.append("the controlled one-slot chest was not applied and completed exactly once")
    if not replacements:
        errors.append("the live Whip schedule was not replaced by Bloody Tear")

    if confirms:
        confirm = confirms[0]
        if confirm.get("recipe_id") != "1" or confirm.get("slot") != "0":
            errors.append("the submitted MAP16 action did not select the Whip/Bloody Tear recipe")
        if _int(confirm, "combat_tic") is None or (_int(confirm, "combat_tic") or 0) <= 0:
            errors.append("the chest transformation did not occur during live MAP16 time")
        if not any(row.get("source") == confirm.get("chest") and row.get("recipe") == confirm.get("recipe_id")
                   and row.get("tx") == confirm.get("tx") and row.get("output") == "6"
                   and row.get("classification") == "ONLINE_REPORTED_RECIPE_CONTROLLED_INVENTORY_FIXTURE"
                   for row in transforms):
            errors.append("the recipe authority commit does not match the accepted MAP16 confirmation")
        if not any(row.get("chest") == confirm.get("chest") and row.get("slot") == confirm.get("slot")
                   and row.get("reward") == "6" and row.get("transaction_once") == "1" for row in rewards):
            errors.append("the chest ledger did not record the transformed Bloody Tear output")
        if not any(row.get("id") == confirm.get("chest") and row.get("opened_once") == "1" for row in completed):
            errors.append("the completed chest ID does not match the accepted choice")
        if not any(row.get("id") == confirm.get("chest") and row.get("accepted") == "1" for row in pickups):
            errors.append("the accepted confirmation was not preceded by pickup of the same chest")
        if not any(row.get("chest") == confirm.get("chest") and row.get("slot") == confirm.get("slot")
                   and row.get("recipe") == confirm.get("recipe_id") for row in intents):
            errors.append("the accepted confirmation did not match a submitted UI intent")
        if not any(row.get("chest") == confirm.get("chest") and row.get("slots") == "1" for row in ui_open):
            errors.append("the one-slot chest UI did not open the transformed chest")
        if spawns and proximity:
            spawn = next((row for row in spawns if row.get("id") == confirm.get("chest")), {})
            trigger = next((row for row in proximity if row.get("id") == confirm.get("chest")), {})
            px = _float(trigger, "player_x"); py = _float(trigger, "player_y")
            cx = _int(spawn, "x"); cy = _int(spawn, "y"); radius = _int(spawn, "radius")
            forward = _float(trigger, "chest_forward")
            if None in (px, py, cx, cy, radius, forward):
                errors.append("the runtime did not report enough coordinates to verify body proximity")
            else:
                if math.hypot(px - cx, py - cy) > radius:
                    errors.append("the player body was outside the recorded chest pickup radius")
                if forward >= 0:
                    errors.append("the chest source was not behind the player's facing direction")
            if (_int(trigger, "pickup_tape") or 0) != 1 or (_float(trigger, "body_travel") or 0.0) <= 24.0:
                errors.append("the actual P021 body did not travel beyond one pickup radius before entering range")
            source_tic = _int(spawn, "source_tic")
            if source_tic is None or source_tic <= 0:
                errors.append("the chest source did not spawn during active combat")
            elif not any((_int(row, "tic") or 0) < source_tic for row in _rows(log, "DS_P030_WHIP")):
                errors.append("the chest spawned before any automatic Whip combat event")
    if transforms and replacements:
        transformation = transforms[0]
        replacement = replacements[0]
        if _int(transformation, "tx") is None or _int(replacement, "tx") != _int(transformation, "tx"):
            errors.append("weapon replacement did not use the committed recipe transaction")
        if _int(replacement, "cancelled_whip_children") is None or (_int(replacement, "cancelled_whip_children") or 0) < 0:
            errors.append("old Whip child cancellation was not reported")
        old_weapon = _int(replacement, "old_whip_id")
        new_weapon = _int(replacement, "new_bloody_tear_id")
        if old_weapon is None or new_weapon is None or old_weapon == new_weapon:
            errors.append("the live weapon handle was not replaced by a distinct Bloody Tear identity")
        replace_tic = _int(replacement, "tic")
        whip_tics = [_int(row, "tic") for row in _rows(log, "DS_P030_WHIP")]
        tear_rows = _rows(log, "DS_P032_BLOODY_TEAR_AUTO")
        if replace_tic is None or not any(tic is not None and tic < replace_tic for tic in whip_tics):
            errors.append("the Whip schedule did not emit before the chest transformation")
        if replace_tic is None or not any(tic is not None and tic > replace_tic for tic in [_int(row, "tic") for row in tear_rows]):
            errors.append("the automatic Bloody Tear schedule did not resume after replacement")
        if replace_tic is not None and any(tic is not None and tic > replace_tic for tic in whip_tics):
            errors.append("the retired Whip schedule fired after evolution")
        if not tear_rows or any(row.get("automatic") != "1" or row.get("geometry") != "ENGINEERING_APPROXIMATION"
                                or row.get("crit") != "ENGINEERING_APPROXIMATION"
                                or row.get("heal") != "ENGINEERING_APPROXIMATION" for row in tear_rows):
            errors.append("Bloody Tear combat did not remain automatic and explicitly qualified as approximate")
        if not tear_rows or any(row.get("weapon_id") != str(new_weapon) or row.get("rank") != "1"
                                for row in tear_rows if replace_tic is not None and (_int(row, "tic") or 0) > replace_tic):
            errors.append("post-replacement attacks did not use the new rank-one Bloody Tear handle")

    if not any(row.get("reason") in ("DUPLICATE_OR_STALE", "NOT_ACTIVE_OR_WRONG_SLOT")
               for row in _rows(log, "DS_P032_MAP16_CONFIRM")):
        errors.append("a repeated or stale chest confirmation was not rejected")
    if "DS_P032_UI_CLOSE" not in log or "DS_P032_MAP16_UI_RESUME" not in log:
        errors.append("the chest modal did not close and return control")
    pauses = _rows(log, "DS_P032_MAP16_MODAL_PAUSE")
    resumes = _rows(log, "DS_P032_MAP16_MODAL_RESUME")
    if not pauses or not resumes:
        errors.append("the MAP16 handler did not report the logical modal pause and resume")
    elif _int(pauses[0], "tic") != _int(resumes[0], "world_tic"):
        errors.append("the logical gameplay clock advanced during the chest modal")

    return {"status": "PASS" if not errors else "FAIL", "errors": errors}


class P032Map16FpTests(unittest.TestCase):
    def test_marker_only_logs_fail_closed(self):
        result = validate_map16_p032(
            "DS_P030_BOOT map=MAP16 mode=p032 logical_steps=1 normal_speed=1 "
            "DS_P032_MAP16_BOOT route=OPT_IN_P032 natural_levelup_claim=0"
        )
        self.assertEqual(result["status"], "FAIL")
        self.assertTrue(result["errors"])

    def test_complete_runtime_proves_source_qualified_transaction_and_replacement(self):
        sample = """DS_P030_BOOT map=MAP16 mode=p032 logical_steps=1 normal_speed=1
DS_P032_MAP16_BOOT route=OPT_IN_P032 natural_levelup_claim=0
DS_P032_MAP16_FIXTURE route=OPT_IN_P032 whip_rank=8 hollow_heart_rank=1 controlled_start=1 natural_levelup_claim=0
DS_P030_WHIP event_id=1 tic=48 lobe=0 automatic=1
DS_P030_WHIP event_id=2 tic=50 lobe=1 automatic=1
DS_P032_CHEST_SPAWN id=11 subtype=SILVER source_tic=60 x=-54 y=0 radius=24 transform_eligible=1 classification=CONTROLLED_SOURCE_RECORD
DS_P032_MAP16_CHEST_SPAWN accepted=1 id=11 subtype=SILVER transform_eligible=1 x=-54 y=0 behind_facing=1 visual=CONTROLLED_PICKUP_MARKER visual_exact=0 visual_spawned=1 pickup_tape=1
DS_P032_MAP16_MOVEMENT_TAPE logical_tic=67 remaining=4 forwardmove=-32768 yaw=0.000 travel=24.000 move_player=1 source=ENGINE_TAPE_P021_BODY
DS_P032_MAP16_CHEST_PROXIMITY accepted=1 id=11 tic=70 player_x=-30.000 player_y=0.000 chest_x=-54 chest_y=0 yaw=0.000 chest_forward=-24.000 chest_lateral=0.000 facing_away=1 source=P021_BODY_RADIUS use_pressed=0 eye_aimed=0 pickup_tape=1 body_travel=30.000
DS_P032_CHEST_PICKUP accepted=1 id=11 body_x=-30 body_y=0 facing_independent=1
DS_P032_MAP16_MODAL_PAUSE chest=11 tic=68 subtype=2 slots=1 world_clock_frozen=1 native_input_cleared=1
DS_P032_UI_OPEN chest=11 subtype=SILVER slots=1
DS_P032_UI_INTENT action=CONFIRM source=ENGINE_TAPE chest=11 slot=0 recipe=1
DS_P032_MAP16_CONFIRM accepted=1 chest=11 slot=0 recipe_id=1 tx=111 combat_tic=68
DS_P032_TRANSFORM accepted=1 recipe=1 source=11 tx=111 output=6 classification=ONLINE_REPORTED_RECIPE_CONTROLLED_INVENTORY_FIXTURE
DS_P032_CHEST_REWARD accepted=1 chest=11 slot=0 reward=6 transaction_once=1
DS_P032_CHEST_COMPLETE accepted=1 id=11 queue=0 opened_once=1
DS_P032_MAP16_WEAPON_REPLACE accepted=1 tx=111 tic=68 old_whip_id=2 new_bloody_tear_id=4 cancelled_whip_children=0
DS_P032_MAP16_MODAL_RESUME chest=11 world_tic=68 clocks_frozen_during_modal=1
DS_P032_BLOODY_TEAR_AUTO event_id=1 tic=116 weapon_id=4 rank=1 automatic=1 geometry=ENGINEERING_APPROXIMATION crit=ENGINEERING_APPROXIMATION heal=ENGINEERING_APPROXIMATION
DS_P032_MAP16_CONFIRM accepted=0 reason=DUPLICATE_OR_STALE chest=11 slot=0 recipe_id=1
DS_P032_MAP16_UI_RESUME chest=11 committed=1 world_tic=68
DS_P032_UI_CLOSE chest=11 committed=1
"""
        result = validate_map16_p032(sample)
        self.assertEqual(result["status"], "PASS", result["errors"])
        self.assertEqual(validate_map16_p032(sample.replace("facing_away=1", "facing_away=0"))["status"], "FAIL")
        self.assertEqual(validate_map16_p032(sample.replace("new_bloody_tear_id=4", "new_bloody_tear_id=2"))["status"], "FAIL")
        self.assertEqual(validate_map16_p032(sample.replace("cancelled_whip_children=0", "cancelled_whip_children=-1"))["status"], "FAIL")


if __name__ == "__main__":
    unittest.main()
