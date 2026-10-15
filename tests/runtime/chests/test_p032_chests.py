"""Strict P032 chest/reward/transformation engine-log validators."""
from __future__ import annotations

import re
import unittest


def _rows(log: str, marker: str) -> list[dict[str, str]]:
    rows = []
    for match in re.finditer(rf"{re.escape(marker)}[ \t]+([^\r\n]*)", log):
        rows.append(dict(re.findall(r"([A-Za-z_][A-Za-z0-9_]*)=([^\s]+)", match.group(1))))
    return rows


GRAPH_CASES: dict[str, dict[str, str]] = {
    "whip_rank7": {"legal": "0", "apply": "0", "reason": "PREDICATE_REJECTED", "recipe": "1", "tx": "32001", "pre_ids": "1,5", "pre_ranks": "7,1", "post_ids": "1,5", "post_ranks": "7,1", "slots_before": "1,1", "slots_after": "1,1", "extras_before": "0,0", "extras_after": "0,0", "unchanged": "1", "classification": "ONLINE_REPORTED_RECIPE_CONTROLLED_INVENTORY_FIXTURE"},
    "missing_hollow_heart": {"legal": "0", "apply": "0", "reason": "PREDICATE_REJECTED", "recipe": "1", "tx": "32002", "pre_ids": "1", "pre_ranks": "8", "post_ids": "1", "post_ranks": "8", "slots_before": "1,0", "slots_after": "1,0", "extras_before": "0,0", "extras_after": "0,0", "unchanged": "1", "classification": "ONLINE_REPORTED_RECIPE_CONTROLLED_INVENTORY_FIXTURE"},
    "bronze_source": {"legal": "0", "apply": "0", "reason": "PREDICATE_REJECTED", "recipe": "1", "tx": "32003", "pre_ids": "1,5", "pre_ranks": "8,1", "post_ids": "1,5", "post_ranks": "8,1", "slots_before": "1,1", "slots_after": "1,1", "extras_before": "0,0", "extras_after": "0,0", "unchanged": "1", "classification": "ONLINE_REPORTED_RECIPE_CONTROLLED_INVENTORY_FIXTURE"},
    "source_ineligible": {"legal": "0", "apply": "0", "reason": "PREDICATE_REJECTED", "recipe": "1", "tx": "32004", "pre_ids": "1,5", "pre_ranks": "8,1", "post_ids": "1,5", "post_ranks": "8,1", "slots_before": "1,1", "slots_after": "1,1", "extras_before": "0,0", "extras_after": "0,0", "unchanged": "1", "classification": "ONLINE_REPORTED_RECIPE_CONTROLLED_INVENTORY_FIXTURE"},
    "output_locked": {"legal": "0", "apply": "0", "reason": "PREDICATE_REJECTED", "recipe": "1", "tx": "32005", "pre_ids": "1,5", "pre_ranks": "8,1", "post_ids": "1,5", "post_ranks": "8,1", "slots_before": "1,1", "slots_after": "1,1", "extras_before": "0,0", "extras_after": "0,0", "unchanged": "1", "classification": "ONLINE_REPORTED_RECIPE_CONTROLLED_INVENTORY_FIXTURE"},
    "output_already_owned": {"legal": "0", "apply": "0", "reason": "PREDICATE_REJECTED", "recipe": "1", "tx": "32006", "pre_ids": "1,5,6", "pre_ranks": "8,1,1", "post_ids": "1,5,6", "post_ranks": "8,1,1", "slots_before": "2,1", "slots_after": "2,1", "extras_before": "0,0", "extras_after": "0,0", "unchanged": "1", "classification": "ONLINE_REPORTED_RECIPE_CONTROLLED_INVENTORY_FIXTURE"},
    "whip_evolution_positive": {"legal": "1", "apply": "1", "reason": "ACCEPTED", "recipe": "1", "tx": "32007", "pre_ids": "1,5", "pre_ranks": "8,1", "post_ids": "5,6", "post_ranks": "1,1", "slots_before": "1,1", "slots_after": "1,1", "extras_before": "0,0", "extras_after": "0,0", "unchanged": "0", "classification": "ONLINE_REPORTED_RECIPE_CONTROLLED_INVENTORY_FIXTURE"},
    "duplicate_transaction": {"legal": "1", "apply": "0", "reason": "DUPLICATE_TRANSACTION", "recipe": "1", "tx": "32008", "pre_ids": "1021,1,5", "pre_ranks": "1,8,1", "post_ids": "1021,1,5", "post_ranks": "1,8,1", "slots_before": "2,1", "slots_after": "2,1", "extras_before": "0,0", "extras_after": "0,0", "unchanged": "1", "classification": "ONLINE_REPORTED_RECIPE_CONTROLLED_INVENTORY_FIXTURE"},
    "union_full_slots": {"legal": "1", "apply": "1", "reason": "ACCEPTED", "recipe": "101", "tx": "32101", "pre_ids": "1001,1002,1004,1005,1006,1007", "pre_ranks": "1,1,1,1,1,1", "post_ids": "1004,1005,1006,1007,1003", "post_ranks": "1,1,1,1,1", "slots_before": "6,0", "slots_after": "5,0", "extras_before": "0,0", "extras_after": "0,0", "unchanged": "0", "classification": "CONTROLLED_FIXTURE"},
    "union_extra_capacity": {"legal": "1", "apply": "1", "reason": "ACCEPTED", "recipe": "101", "tx": "32102", "pre_ids": "1001,1002,1004,1005,1006,1007,1008,1009", "pre_ranks": "1,1,1,1,1,1,1,1", "post_ids": "1004,1005,1006,1007,1008,1009,1003", "post_ranks": "1,1,1,1,1,1,1", "slots_before": "8,0", "slots_after": "7,0", "extras_before": "2,0", "extras_after": "2,0", "unchanged": "0", "classification": "CONTROLLED_STAGE_EXTRA_CAPACITY_FIXTURE"},
    "gift_full_slots_reject": {"legal": "0", "apply": "0", "reason": "PREDICATE_REJECTED", "recipe": "102", "tx": "32103", "pre_ids": "1010,1012,1013,1014,1015,1016", "pre_ranks": "1,1,1,1,1,1", "post_ids": "1010,1012,1013,1014,1015,1016", "post_ranks": "1,1,1,1,1,1", "slots_before": "0,6", "slots_after": "0,6", "extras_before": "0,0", "extras_after": "0,0", "unchanged": "1", "classification": "CONTROLLED_FIXTURE"},
    "gift_extra_capacity": {"legal": "1", "apply": "1", "reason": "ACCEPTED", "recipe": "102", "tx": "32104", "pre_ids": "1010,1012,1013,1014,1015,1016", "pre_ranks": "1,1,1,1,1,1", "post_ids": "1010,1012,1013,1014,1015,1016,1011", "post_ranks": "1,1,1,1,1,1,1", "slots_before": "0,6", "slots_after": "0,7", "extras_before": "0,1", "extras_after": "0,1", "unchanged": "0", "classification": "CONTROLLED_STAGE_EXTRA_CAPACITY_FIXTURE"},
    "replacement_full_slots": {"legal": "1", "apply": "1", "reason": "ACCEPTED", "recipe": "103", "tx": "32105", "pre_ids": "1020,1022,1023,1024,1025,1026", "pre_ranks": "1,1,1,1,1,1", "post_ids": "1022,1023,1024,1025,1026,1021", "post_ranks": "1,1,1,1,1,1", "slots_before": "6,0", "slots_after": "6,0", "extras_before": "0,0", "extras_after": "0,0", "unchanged": "0", "classification": "CONTROLLED_FIXTURE"},
}
GRAPH_INPUTS: dict[str, dict[str, str]] = {
    name: {"chest_subtype": "2", "source_eligible": "1", "output_unlocked": "1"}
    for name in GRAPH_CASES
}
GRAPH_INPUTS["bronze_source"]["chest_subtype"] = "1"
GRAPH_INPUTS["source_ineligible"]["source_eligible"] = "0"
GRAPH_INPUTS["output_locked"]["output_unlocked"] = "0"


def validate_graph_matrix(log: str, runtime_status: str = "RUNTIME_PASS") -> dict[str, object]:
    errors: list[str] = []
    if runtime_status != "RUNTIME_PASS":
        errors.append(f"UZDoom graph matrix status was {runtime_status}, expected RUNTIME_PASS")
    if "DS_BOOT map=MAP18" not in log or "DS_P032_BOOT map=MAP18" not in log:
        errors.append("graph matrix did not boot in MAP18")
    if re.search(r"Script error|Unknown identifier|VM execution aborted|Fatal error|Execution could not continue", log, re.I):
        errors.append("engine log contains a script or runtime failure")
    done = _rows(log, "DS_P032_GRAPH_MATRIX_DONE")
    matrix_pass = _rows(log, "DS_P032_GRAPH_MATRIX_PASS")
    runtime_pass = _rows(log, "DS_P032_RUNTIME_PASS")
    if len(done) != 1 or done[0].get("accepted") != "1" or done[0].get("cases") != str(len(GRAPH_CASES)):
        errors.append("matrix completion did not report accepted=1 and all expected cases")
    if len(matrix_pass) != 1 or matrix_pass[0].get("accepted") != "1" or matrix_pass[0].get("cases") != str(len(GRAPH_CASES)):
        errors.append("graph matrix pass marker is missing or incomplete")
    if len(runtime_pass) != 1 or runtime_pass[0].get("mode") != "graph_matrix":
        errors.append("graph matrix did not reach its exact runtime completion marker")

    rows = _rows(log, "DS_P032_GRAPH_CASE")
    by_name = {row.get("name", ""): row for row in rows}
    if len(rows) != len(GRAPH_CASES) or set(by_name) != set(GRAPH_CASES):
        errors.append("matrix case names/count differ from the required predicate and slot matrix")
    authority = _rows(log, "DS_P032_TRANSFORM")
    if len(authority) != 14:
        errors.append("authority did not emit the exact 14 transaction outcomes, including the duplicate replay")

    for name, expected in GRAPH_CASES.items():
        row = by_name.get(name)
        if row is None:
            continue
        for key in ("recipe", "tx", "pre_ids", "pre_ranks", "post_ids", "post_ranks",
                    "slots_before", "slots_after", "extras_before", "extras_after",
                    "unchanged", "classification"):
            if row.get(key) != expected[key]:
                errors.append(f"{name}: {key} expected {expected[key]}, got {row.get(key)}")
        for key, value in GRAPH_INPUTS[name].items():
            if row.get(key) != value:
                errors.append(f"{name}: {key} expected {value}, got {row.get(key)}")
        for key, expected_key in (("expected_legal", "legal"), ("actual_legal", "legal"),
                                  ("expected_apply", "apply"), ("actual_apply", "apply"),
                                  ("expected_reason", "reason"), ("actual_reason", "reason")):
            if row.get(key) != expected[expected_key]:
                errors.append(f"{name}: {key} expected {expected[expected_key]}, got {row.get(key)}")
        unchanged = expected["unchanged"] == "1"
        before_hash = row.get("pre_hash")
        after_hash = row.get("post_hash")
        if not before_hash or not after_hash or (before_hash == after_hash) != unchanged:
            errors.append(f"{name}: pre/post inventory hashes do not match the expected mutation")
        matching_tx = [event for event in authority
                       if event.get("tx") == expected["tx"] and event.get("recipe") == expected["recipe"]]
        if expected["apply"] == "1":
            if not any(event.get("accepted") == "1" for event in matching_tx):
                errors.append(f"{name}: authority has no accepted recipe transaction for tx {expected['tx']}")
        elif not any(event.get("accepted") == "0" and event.get("reason") == expected["reason"]
                     for event in matching_tx):
            errors.append(f"{name}: authority reject marker does not prove {expected['reason']} for tx {expected['tx']}")
    return {"status": "PASS" if not errors else "FAIL", "errors": errors}


def validate_p032_run(log: str, mode: str, runtime_status: str = "RUNTIME_PASS") -> dict[str, object]:
    if mode == "graph_matrix":
        return validate_graph_matrix(log, runtime_status)
    errors: list[str] = []
    if runtime_status != "RUNTIME_PASS":
        errors.append(f"UZDoom run status was {runtime_status}, expected RUNTIME_PASS")
    if "DS_BOOT map=MAP18" not in log or "DS_P032_RUNTIME_PASS" not in log:
        errors.append("MAP18 did not boot and complete in pinned UZDoom")
    if re.search(r"Script error|Unknown identifier|VM execution aborted|Fatal error|Execution could not continue", log, re.I):
        errors.append("engine log contains a script or runtime failure")

    pickup = _rows(log, "DS_P032_PICKUP_GEOMETRY")
    if not pickup or not any(row.get("facing_away") == "1" and row.get("body_radius") == "1"
                             and row.get("use_or_aim") == "0" for row in pickup):
        errors.append("actual body-radius pickup while facing away was not proven")
    opens = _rows(log, "DS_P032_MODAL_OPEN")
    if not opens:
        errors.append("chest did not open a modal pause boundary")
    captures = _rows(log, "DS_P032_MODAL_CAPTURE")
    if not captures:
        errors.append("modal framebuffer capture callback did not run")
    closes = _rows(log, "DS_P032_MODAL_CLOSE")
    if opens and len(closes) != len(opens):
        errors.append("each opened chest modal must have one close/freeze marker")
    for opened, closed in zip(opens, closes):
        try:
            if opened["chest"] != closed["chest"] or opened["logical_tic"] != closed["logical_tic"]:
                errors.append("logical gameplay tic advanced during a chest modal pause")
        except KeyError:
            errors.append("modal open/close logical-tic markers were malformed")
    if closes and _rows(log, "DS_P032_RUNTIME_PASS"):
        try:
            if _rows(log, "DS_P032_RUNTIME_PASS")[-1]["logical_tic"] != closes[-1]["logical_tic"]:
                errors.append("logical gameplay tic advanced after the final chest modal close")
        except KeyError:
            errors.append("final modal and runtime completion tic markers were malformed")

    if mode == "evolution":
        rows = _rows(log, "DS_P032_ATOMIC_TRANSFORM")
        if len(rows) != 1:
            errors.append("named Whip evolution did not commit exactly once")
        elif rows[0].get("accepted") != "1" or rows[0].get("recipe") != "1" or rows[0].get("slot") != "0":
            errors.append("named Whip evolution transaction fields are invalid")
        elif rows[0].get("whip_rank") != "0" or rows[0].get("bloody_tear_rank") != "1" or rows[0].get("passive_retained") != "1":
            errors.append("evolution did not replace Whip with rank-1 Bloody Tear while retaining Hollow Heart")
        if not any(row.get("classification") == "ONLINE_REPORTED_RECIPE_CONTROLLED_INVENTORY_FIXTURE"
                   for row in _rows(log, "DS_P032_TRANSFORM")):
            errors.append("source-reported recipe was not clearly separated from controlled inventory/combat content")
        ledger = _rows(log, "DS_P032_CHEST_REWARD")
        if len(ledger) != 1:
            errors.append("transformation and its one chest slot were not committed together")
        elif len(rows) == 1 and (ledger[0].get("chest") != rows[0].get("chest")
                                 or ledger[0].get("slot") != rows[0].get("slot")):
            errors.append("transformation transaction and chest ledger do not identify the same chest slot")
    elif mode in {"slots1", "slots3", "slots5"}:
        expected = int(mode[-1])
        source = _rows(log, "DS_P032_CHEST_SPAWN")
        rewards = [row for row in _rows(log, "DS_P032_ATOMIC_REWARD") if row.get("accepted") == "1"]
        ledger = [row for row in _rows(log, "DS_P032_CHEST_REWARD") if row.get("accepted") == "1"]
        if len(source) != 1 or source[0].get("slots") != str(expected):
            errors.append(f"source did not freeze exactly {expected} reward slots")
        if len(rewards) != expected or len(ledger) != expected:
            errors.append(f"expected {expected} inventory mutations and slot-ledger commits")
        if any(row.get("rank") not in {"1", "2"} for row in rewards):
            errors.append("controlled multi-slot reward ranks are inconsistent")
    elif mode == "bronze_late":
        source = _rows(log, "DS_P032_CHEST_SPAWN")
        rejects = _rows(log, "DS_P032_TRANSFORM_REJECT")
        opens = _rows(log, "DS_P032_MODAL_OPEN")
        if not source or source[0].get("subtype") != "BRONZE" or source[0].get("transform_eligible") != "0":
            errors.append("Bronze source did not freeze transformation ineligible at spawn")
        if not opens or opens[0].get("logical_tic") != "100":
            errors.append("controlled delayed-open Bronze fixture did not wait 100 logical tics")
        if not any(row.get("reason") == "FROZEN_BRONZE_SOURCE" for row in rejects):
            errors.append("late Bronze did not reject the Whip evolution from frozen source metadata")
        if _rows(log, "DS_P032_ATOMIC_TRANSFORM"):
            errors.append("ineligible Bronze source granted a transformation")
        if len([row for row in _rows(log, "DS_P032_ATOMIC_REWARD") if row.get("accepted") == "1"]) != 3:
            errors.append("Bronze ordinary reward sequence did not continue after the rejected transform")
    elif mode == "queue":
        if len(_rows(log, "DS_P032_CHEST_PICKUP")) != 2:
            errors.append("both nearby chest sources were not queued once")
        completes = [row for row in _rows(log, "DS_P032_CHEST_COMPLETE") if row.get("accepted") == "1"]
        if len(completes) != 2:
            errors.append("queued chest transactions did not complete sequentially")
        modal_rows = _rows(log, "DS_P032_MODAL_OPEN")
        if [row.get("chest") for row in modal_rows] != ["1801", "1802"]:
            errors.append("queued chest modal order differed from source order")
    elif mode == "duplicate_confirm":
        duplicate = _rows(log, "DS_P032_UI_DUPLICATE_INTENT")
        rejected = _rows(log, "DS_P032_CONFIRM_REJECT")
        rewards = [row for row in _rows(log, "DS_P032_ATOMIC_REWARD") if row.get("accepted") == "1"]
        if not duplicate:
            errors.append("UI engine tape did not submit a repeated held confirmation")
        if not rejected:
            errors.append("runtime authority did not reject the duplicate/stale slot confirmation")
        if len(rewards) != 3 or len({row.get("slot") for row in rewards}) != 3:
            errors.append("duplicate confirmation granted an item twice or lost a legal slot")

    return {"status": "PASS" if not errors else "FAIL", "errors": errors}


class P032ChestValidationTests(unittest.TestCase):
    def test_marker_only_cannot_pass(self):
        result = validate_p032_run("DS_BOOT map=MAP18 DS_P032_RUNTIME_PASS", "evolution")
        self.assertEqual(result["status"], "FAIL")
        self.assertTrue(result["errors"])

    def test_evolution_requires_atomic_inventory_and_slot_effect(self):
        sample = """DS_BOOT map=MAP18
DS_P032_PICKUP_GEOMETRY chest=1801 facing_away=1 body_radius=1 use_or_aim=0
DS_P032_MODAL_OPEN chest=1801 logical_tic=1
DS_P032_MODAL_CAPTURE callbacks=6 chest=1801
DS_P032_TRANSFORM accepted=1 classification=ONLINE_REPORTED_RECIPE_CONTROLLED_INVENTORY_FIXTURE
DS_P032_CHEST_REWARD accepted=1 chest=1801 slot=0
DS_P032_ATOMIC_TRANSFORM accepted=1 chest=1801 slot=0 recipe=1 whip_rank=0 bloody_tear_rank=1 passive_retained=1
DS_P032_MODAL_CLOSE chest=1801 logical_tic=1
DS_P032_RUNTIME_PASS logical_tic=1
"""
        self.assertEqual(validate_p032_run(sample, "evolution")["status"], "PASS")
        self.assertEqual(validate_p032_run(sample.replace("slot=0", "slot=1", 1), "evolution")["status"], "FAIL")

    def test_suite_status_must_be_runtime_pass(self):
        sample = """DS_BOOT map=MAP18
DS_P032_PICKUP_GEOMETRY chest=1801 facing_away=1 body_radius=1 use_or_aim=0
DS_P032_MODAL_OPEN chest=1801 logical_tic=1
DS_P032_MODAL_CAPTURE callbacks=6 chest=1801
DS_P032_RUNTIME_PASS logical_tic=1
"""
        self.assertEqual(validate_p032_run(sample, "evolution", "TIMEOUT")["status"], "FAIL")

    def test_graph_matrix_marker_only_cannot_pass(self):
        sample = """DS_BOOT map=MAP18
DS_P032_BOOT map=MAP18
DS_P032_GRAPH_MATRIX_DONE accepted=1 cases=13
DS_P032_GRAPH_MATRIX_PASS accepted=1 cases=13
DS_P032_RUNTIME_PASS mode=graph_matrix
"""
        self.assertEqual(validate_graph_matrix(sample)["status"], "FAIL")

    def test_graph_matrix_requires_exact_states_and_authority_outcomes(self):
        lines = [
            "DS_BOOT map=MAP18",
            "DS_P032_BOOT map=MAP18",
            f"DS_P032_GRAPH_MATRIX_DONE accepted=1 cases={len(GRAPH_CASES)}",
            f"DS_P032_GRAPH_MATRIX_PASS accepted=1 cases={len(GRAPH_CASES)}",
            "DS_P032_RUNTIME_PASS mode=graph_matrix",
        ]
        for name, expected in GRAPH_CASES.items():
            lines.append("DS_P032_GRAPH_CASE " + " ".join((
                f"name={name}", f"expected_legal={expected['legal']}",
                f"actual_legal={expected['legal']}", f"expected_apply={expected['apply']}",
                f"actual_apply={expected['apply']}", f"tx={expected['tx']}",
                f"recipe={expected['recipe']}", f"chest_subtype={GRAPH_INPUTS[name]['chest_subtype']}",
                f"source_eligible={GRAPH_INPUTS[name]['source_eligible']}",
                f"output_unlocked={GRAPH_INPUTS[name]['output_unlocked']}",
                f"expected_reason={expected['reason']}", f"actual_reason={expected['reason']}",
                f"slots_before={expected['slots_before']}", f"slots_after={expected['slots_after']}",
                f"extras_before={expected['extras_before']}", f"extras_after={expected['extras_after']}",
                f"unchanged={expected['unchanged']}", f"pre_ids={expected['pre_ids']}",
                f"pre_ranks={expected['pre_ranks']}", f"post_ids={expected['post_ids']}",
                f"post_ranks={expected['post_ranks']}",
                f"pre_hash={'1' if expected['unchanged'] == '1' else '2'}",
                f"post_hash={'1' if expected['unchanged'] == '1' else '3'}",
                f"recipe={expected['recipe']}", f"classification={expected['classification']}")))
            accepted = expected["apply"]
            lines.append(f"DS_P032_TRANSFORM accepted={accepted} recipe={expected['recipe']} tx={expected['tx']} reason={expected['reason']}")
        # This setup commit seeds the duplicate-transaction replay fixture.
        lines.append("DS_P032_TRANSFORM accepted=1 recipe=103 tx=32008 reason=ACCEPTED")
        sample = "\n".join(lines) + "\n"
        self.assertEqual(validate_graph_matrix(sample)["status"], "PASS")
        damaged = sample.replace("post_ids=1004,1005,1006,1007,1003", "post_ids=1001,1005,1006,1007,1003")
        self.assertEqual(validate_graph_matrix(damaged)["status"], "FAIL")


if __name__ == "__main__":
    unittest.main()
