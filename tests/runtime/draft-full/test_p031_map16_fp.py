"""Strict MAP16 validator for the opt-in, source-integrated P031 path."""
from __future__ import annotations

import re
import unittest


def _rows(log: str, marker: str) -> list[dict[str, str]]:
    result = []
    # UZDoom emits each Console.Printf record on its own line. Keep extraction
    # line-scoped so a later marker cannot be missed across the newline.
    for match in re.finditer(rf"{re.escape(marker)}[ \t]+([^\r\n]*)", log):
        result.append(dict(re.findall(r"([A-Za-z_][A-Za-z0-9_]*)=([^\s]+)", match.group(1))))
    return result


def _integer(row: dict[str, str], key: str) -> int | None:
    try:
        return int(row[key])
    except (KeyError, ValueError):
        return None


def validate_map16_p031(log: str) -> dict[str, object]:
    errors: list[str] = []
    if "DS_P030_BOOT map=MAP16" not in log or "mode=p031" not in log:
        errors.append("MAP16 did not boot through the opt-in p031 route")
    if "DS_P031_MAP16_BOOT route=OPT_IN_P031 authority=DSP031InventoryDraftAuthority" not in log:
        errors.append("the P031 authority was not installed in the MAP16 run")
    if "DS_P031_MAP16_ARMS primary=WHIP" not in log or "secondary=TEST_AUTO_PULSE" not in log:
        errors.append("the controlled diagnostic weapon pair was not equipped")
    if "classification=CONTROLLED_DIAGNOSTIC source_content=NONE" not in log:
        errors.append("the second weapon was not classified as a test fixture")
    if re.search(r"Script error|Unknown identifier|Execution could not continue|Fatal error|DS_RUNTIME_ASSERT_FAIL", log, re.I):
        errors.append("the runtime reported a script failure or assertion")

    opens = _rows(log, "DS_P031_MAP16_DRAFT_OPEN")
    ui_opens = _rows(log, "DS_P031_MAP16_UI_OPEN")
    applies = [row for row in _rows(log, "DS_P031_MAP16_DRAFT_APPLY") if row.get("accepted") == "1"]
    authority_applies = _rows(log, "DS_P031_APPLY")
    choices = [row for row in _rows(log, "DS_P030_LEVELUP_CHOICE") if row.get("accepted") == "1"]
    tapes = _rows(log, "DS_P030_LEVELUP_INPUT")
    if not opens:
        errors.append("the P031 draft was not opened by MAP16 gameplay")
    if not ui_opens:
        errors.append("the MAP16 UI did not receive the real P031 choice count")
    if not applies:
        errors.append("no legal P031 offer was applied through the MAP16 modal")
    if not choices:
        errors.append("the existing modal/network confirmation seam did not accept a choice")
    if not any(row.get("source") == "ENGINE_TAPE" and row.get("action") == "CONFIRM" for row in tapes):
        errors.append("the actual interface confirmation event is missing")

    if opens and applies:
        opened = opens[0]
        applied = applies[0]
        token = _integer(opened, "token")
        ids = [_integer(opened, f"offer{i}_id") for i in range(3)]
        count = _integer(opened, "offer_count")
        selected = _integer(applied, "item_id")
        if token is None or _integer(applied, "token") != token:
            errors.append("the applied P031 choice does not match the open draft token")
        if count is None or count < 1 or count > 3:
            errors.append("the MAP16 P031 bridge exposed an invalid choice count")
        if not any(_integer(row, "choice_count") == count and row.get("ui_modal") == "1" for row in ui_opens):
            errors.append("the MAP16 UI choice count does not match the legal P031 offer count")
        shown = ids[:count or 0]
        if any(item is None or item not in (1, 2, 3) for item in shown):
            errors.append("the playable MAP16 draft contains a non-playable identity")
        elif len(set(shown)) != len(shown):
            errors.append("the playable MAP16 draft contains duplicate identities")
        if selected not in shown:
            errors.append("the applied identity was not in the offered set")
        if _integer(applied, "combat_tic") is None or (_integer(applied, "combat_tic") or 0) <= 0:
            errors.append("the draft action did not occur during live MAP16 combat time")
        if (_integer(applied, "whip_events") or 0) <= 0:
            errors.append("Whip combat had not emitted before the P031 action")
        if not any(row.get("authority") == "DSP031InventoryDraftAuthority" for row in applies):
            errors.append("the selection bypassed P031 authority")
        applied_rank = _integer(applied, "rank")
        if not any(_integer(row, "rank") == applied_rank for row in authority_applies):
            errors.append("MAP16 post-apply rank telemetry disagrees with the inventory authority")
        if choices and _integer(choices[0], "rank") != applied_rank:
            errors.append("the shared modal choice logged an offered rank instead of the applied rank")

    if applies:
        choice_tic = _integer(applies[0], "combat_tic")
        whip = _rows(log, "DS_P030_WHIP")
        diagnostic = _rows(log, "DS_P031_MAP16_DIAGNOSTIC_EMISSION")
        post_whip_tics = {
            _integer(row, "tic") for row in whip
            if _integer(row, "tic") is not None and choice_tic is not None and _integer(row, "tic") > choice_tic
        }
        post_diag_tics = {
            _integer(row, "tic") for row in diagnostic
            if row.get("after_p031_choice") == "1" and _integer(row, "tic") is not None
        }
        if not post_whip_tics:
            errors.append("automatic Whip attacks did not resume after the P031 choice")
        if not post_diag_tics:
            errors.append("the second automatic diagnostic schedule did not resume after the choice")
        if not (post_whip_tics & post_diag_tics):
            errors.append("post-choice Whip and diagnostic automatic emissions were never concurrent")
        if not diagnostic or any(row.get("automatic") != "1" or row.get("p025_snapshot") != "1" for row in diagnostic):
            errors.append("the diagnostic schedule lacks automatic P025 snapshots")
        if "DS_P030_LEVELUP_RESUME" not in log:
            errors.append("the MAP16 modal did not return to active combat")

    return {"status": "PASS" if not errors else "FAIL", "errors": errors}


class P031Map16FpTests(unittest.TestCase):
    def test_marker_only_runtime_fails_closed(self):
        result = validate_map16_p031(
            "DS_P030_BOOT map=MAP16 mode=p031 DS_P031_MAP16_BOOT "
            "route=OPT_IN_P031 authority=DSP031InventoryDraftAuthority"
        )
        self.assertEqual(result["status"], "FAIL")
        self.assertTrue(result["errors"])

    def test_p031_application_must_be_authoritative_and_post_combat(self):
        sample = """DS_P030_BOOT map=MAP16 mode=p031
DS_P031_MAP16_BOOT route=OPT_IN_P031 authority=DSP031InventoryDraftAuthority
DS_P031_MAP16_ARMS primary=WHIP weapon_id=2 automatic=1 secondary=TEST_AUTO_PULSE weapon_id=3 automatic=1 classification=CONTROLLED_DIAGNOSTIC source_content=NONE
DS_P031_MAP16_DRAFT_OPEN tic=190 target_level=2 token=0 queue=1 offer_count=3 offer0_id=1 offer1_id=2 offer2_id=3 gameplay_paused=1
DS_P031_MAP16_UI_OPEN target_level=2 choice_count=3 selected_offer=0 ui_modal=1
DS_P030_LEVELUP_INPUT source=ENGINE_TAPE action=CONFIRM selected_offer=0
DS_P031_APPLY offer_id=WHIP rank=2 token=0 queue_remaining=0 authority=SHARED_INVENTORY_STATS transaction_once=1
DS_P031_MAP16_DRAFT_APPLY accepted=1 source=NETWORK_EVENT index=0 token=0 item_id=1 rank=2 combat_tic=190 whip_events=4 queue_remaining=0 authority=DSP031InventoryDraftAuthority
DS_P030_LEVELUP_CHOICE source=NETWORK_EVENT accepted=1 index=0 rank=2
DS_P030_LEVELUP_RESUME tic=190
DS_P030_WHIP event_id=5 tic=237 automatic=1
DS_P031_MAP16_DIAGNOSTIC_EMISSION event_id=100005 tic=237 automatic=1 p025_snapshot=1 after_p031_choice=1
"""
        self.assertEqual(validate_map16_p031(sample)["status"], "PASS", validate_map16_p031(sample)["errors"])
        self.assertEqual(validate_map16_p031(sample.replace("token=0 item_id=1", "token=1 item_id=1"))["status"], "FAIL")
        self.assertEqual(validate_map16_p031(sample.replace("tic=237 automatic=1", "tic=238 automatic=1", 1))["status"], "FAIL")


if __name__ == "__main__":
    unittest.main()
