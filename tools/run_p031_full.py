"""Build and validate the packaged P031 inventory/draft runtime gates."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.run_persistence_bench import read_log, run_engine
from tools.run_probe import config_text, run


def _load_weight_validator():
    path = ROOT / "tests/runtime/draft-full/test_p031_weight_audit.py"
    spec = importlib.util.spec_from_file_location("p031_weight_validator", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("unable to load the strict P031 weight-audit validator")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.validate_weight_audit


def _flat(text: str) -> str:
    return re.sub(r"\s+", " ", text)


def _rows(log: str, marker: str) -> list[dict[str, str]]:
    text = _flat(log)
    rows: list[dict[str, str]] = []
    # Stop at any following DS_ marker, not only DS_P031_: other handlers'
    # lines (e.g. DS_P037/P038_INPUT_OWNERSHIP ui_processor=0) otherwise leak
    # their fields into this row and overwrite its values.
    for match in re.finditer(rf"{re.escape(marker)}\s+(.*?)(?=\sDS_[A-Z0-9_]+\s|$)", text):
        rows.append(dict(re.findall(r"([A-Za-z_][A-Za-z0-9_]*)=([^\s]+)", match.group(1))))
    return rows


def _offer_id_sets(log: str) -> list[set[int]]:
    parsed: list[set[int]] = []
    for row in _rows(log, "DS_P031_OFFER_SET"):
        try:
            parsed.append({int(value) for value in row["ids"].split(",") if int(value) != 0})
        except (KeyError, ValueError):
            continue
    return parsed


def _evidence_log(result: dict) -> str:
    path = Path(result["evidence"]) / "engine.log"
    return path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""


def _validate_action_run(log: str) -> list[str]:
    text = _flat(log)
    errors: list[str] = []
    if "DS_BOOT map=MAP17" not in text or "DS_P031_COMPLETE" not in text:
        errors.append("MAP17 action tape did not boot and complete in UZDoom")
    # The strict parser consumes a single physical audit record line. Pass the
    # original engine output; flattening is only for cross-record checks.
    audit = _load_weight_validator()(log)
    if audit["status"] != "PASS":
        errors.extend(f"weight audit: {error}" for error in audit["errors"])
    live_rng = _rows(text, "DS_P031_AUDIT_LIVE_STATE")
    if len(live_rng) != 1 or live_rng[0].get("unchanged") != "1":
        errors.append("statistical audit changed the live gameplay draft RNG")
    for kind in ("REROLL", "BANISH"):
        if not any(row.get("kind") == kind and row.get("accepted") == "1" for row in _rows(text, "DS_P031_ACTION_RESULT")):
            errors.append(f"actual UZDoom {kind.lower()} intent was not accepted")
    action_rows = _rows(text, "DS_P031_ACTION_RESULT")
    if not any(row.get("kind") == "REROLL" and row.get("accepted") == "0" and row.get("token") == "77" for row in action_rows):
        errors.append("stale-token reroll was not rejected by the runtime authority")
    if not any(row.get("kind") == "BANISH" and row.get("accepted") == "1" and row.get("action_id") == "2" for row in action_rows):
        errors.append("rejected stale intent consumed the next legitimate action ID")
    if not any(row.get("accepted") == "1" and row.get("remaining") == "1" for row in _rows(text, "DS_P031_REROLL")):
        errors.append("stale-token request was not made while a Reroll charge remained")
    banish = _rows(text, "DS_P031_BANISH")
    if not any(row.get("accepted") == "1" and row.get("menu_open") == "1" and row.get("draft_consumed") == "0" for row in banish):
        errors.append("Banish did not preserve the current draft")
    banish_position = text.find("DS_P031_BANISH accepted=1")
    later_offer_sets = _offer_id_sets(text[banish_position:]) if banish_position >= 0 else []
    if not later_offer_sets or any(2 in choices for choices in later_offer_sets):
        errors.append("run-banished POWER reappeared in a later offer set")
    transactions = _rows(text, "DS_P031_TRANSACTION")
    if not any(row.get("kind") == "APPLY" and row.get("item") in {"WHIP", "POWER", "ARMOR"} for row in transactions):
        errors.append("action tape did not apply a real playable-subset item")
    if not any(row.get("kind") == "SKIP" for row in transactions):
        errors.append("action tape did not exercise Skip")
    if "DS_P031_NEUTRAL_REJECT" in text:
        errors.append("UI submitted neutral release before the authority acknowledged Apply/Skip")
    if re.search(r"VM execution aborted|Script error|Unknown identifier|Execution could not continue", text, re.I):
        errors.append("engine log contains a script/runtime failure")
    return errors


def _validate_slot_run(log: str) -> list[str]:
    rows = _rows(log, "DS_P031_SLOT_PROBE")
    if len(rows) != 1:
        return ["full-slot stage-grant probe did not emit exactly one engine marker"]
    row = rows[0]
    expected = {"ordinary_before": "6", "ordinary_after": "6", "extra_after": "1", "stage_grant": "1",
                "owned_extra_remains_eligible": "1", "new_passive_blocked": "1", "power_rank": "1", "might_milli": "1100",
                "fixture": "CONTROLLED"}
    return [f"slot probe {key}={row.get(key)!r}, expected {value!r}" for key, value in expected.items() if row.get(key) != value]


# Bounded live-UI capture runs end by timeout by design; the budget must cover
# engine boot plus the capture tic. On 2026-09-27 boot stalled in DirectInput
# joystick enumeration beyond both 8 s and 20 s; 60 s captured both screens.
UI_CAPTURE_SECONDS = 60


def _save_load_probe(package: Path, evidence_root: Path, timeout: float) -> dict:
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    name = f"{stamp}-p031-mid-draft-save"
    evidence = evidence_root / name
    evidence.mkdir(parents=True)
    profile = ROOT / ".local/probes" / name
    profile.mkdir(parents=True)
    (profile / "config.ini").write_text(config_text(evidence, vsync=False), encoding="utf-8", newline="\n")
    (profile / "save.cfg").write_text('wait 18; save ds_p031_mid_draft "P031 Mid Draft"; wait 3; quit\n', encoding="utf-8", newline="\n")
    (profile / "load.cfg").write_text("wait 18; quit\n", encoding="utf-8", newline="\n")
    executable = ROOT / json.loads((ROOT / "toolchain/lock.json").read_text(encoding="utf-8"))["uzdoom"]["executable"]["path"]
    setup = ["+enablescriptscreenshot", "true", "+screenshot_dir", evidence.as_posix(),
             "+set", "ds_p031_mode", "hold_after_reroll", "+set", "ds_p031_rerolls", "2", "+set", "ds_p031_skips", "1",
             "+set", "ds_p031_banishes", "1", "+map", "MAP17", "+exec", "save.cfg"]
    first_rc = run_engine(executable, package, profile, "p031-save.log", setup, timeout=timeout)
    save_log = read_log(profile, "p031-save.log")
    save_files = sorted(path for path in profile.glob("ds_p031_mid_draft*") if path.is_file())
    save_file = save_files[0] if save_files else None
    load_rc = None
    restored_log = ""
    if save_file is not None:
        load_args = ["-loadgame", save_file.stem, "+enablescriptscreenshot", "true", "+screenshot_dir", evidence.as_posix(),
                     "+set", "ds_p031_mode", "hold_after_reroll", "+exec", "load.cfg"]
        load_rc = run_engine(executable, package, profile, "p031-load.log", load_args, timeout=timeout)
        restored_log = read_log(profile, "p031-load.log")
    (evidence / "save-engine.log").write_text(save_log, encoding="utf-8", newline="\n")
    (evidence / "load-engine.log").write_text(restored_log, encoding="utf-8", newline="\n")
    (evidence / "save.cfg").write_text((profile / "save.cfg").read_text(encoding="utf-8"), encoding="utf-8", newline="\n")
    (evidence / "load.cfg").write_text((profile / "load.cfg").read_text(encoding="utf-8"), encoding="utf-8", newline="\n")
    ready = _rows(save_log, "DS_P031_SAVE_READY")
    restored = _rows(restored_log, "DS_P031_SAVE_RESTORE")
    errors: list[str] = []
    if first_rc not in (0, -9):
        errors.append(f"save process exited unexpectedly with {first_rc}")
    if save_file is None or save_file.stat().st_size <= 0:
        errors.append("UZDoom did not create a non-empty mid-draft save")
    if len(ready) != 1:
        errors.append("save process did not reach exactly one modal save-ready state")
    if not any(row.get("accepted") == "1" and row.get("remaining") == "1" for row in _rows(save_log, "DS_P031_REROLL")):
        errors.append("mid-draft save was not taken after an accepted Reroll")
    if len(restored) != 1:
        errors.append("load process did not restore the P031 modal on its first tick")
    screenshot_files = sorted(set(profile.glob("*.png")) | set(evidence.glob("*.png")))
    screenshot_manifest = []
    for capture in screenshot_files:
        if capture.parent != evidence:
            target = evidence / capture.name
            shutil.copy2(capture, target)
            capture = target
        data = capture.read_bytes()
        screenshot_manifest.append({"file": capture.name, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()})
    if not screenshot_manifest:
        errors.append("save/load probe did not capture a UZDoom framebuffer while the restored draft was held")
    if not _rows(restored_log, "DS_P031_MODAL_CAPTURE"):
        errors.append("restored draft did not reach its framebuffer capture callback")
    if ready and restored:
        for key in ("state_hash", "rng", "draws", "applied", "queue", "token", "action_id", "rerolls", "skips", "banishes", "offers"):
            if ready[0].get(key) != restored[0].get(key):
                errors.append(f"restored {key} differs from saved modal state")
        if restored[0].get("draft_paused") != "1" or restored[0].get("awaiting_neutral") != "0":
            errors.append("restored UI did not reclaim the open-draft input owner")
        if ready[0].get("action_id") != "1" or ready[0].get("rerolls") != "1":
            errors.append("save-ready state did not retain the accepted Reroll")
    if not any(row.get("last_action_id") == "1" and row.get("next_action_id") == "2"
               for row in _rows(restored_log, "DS_P031_UI_ACTION_SYNC")):
        errors.append("restored UI did not synchronize its next action ID")
    if re.search(r"VM execution aborted|Script error|Unknown identifier|Execution could not continue", _flat(save_log + restored_log), re.I):
        errors.append("save/load logs contain a script/runtime failure")
    if save_file is not None:
        shutil.copy2(save_file, evidence / save_file.name)
    result = {"status": "PASS" if not errors else "FAIL", "evidence": str(evidence), "save_file": str(save_file) if save_file else None,
              "save_rc": first_rc, "load_rc": load_rc, "ready": ready[-1] if ready else None,
              "restore": restored[-1] if restored else None, "screenshots": screenshot_manifest, "errors": errors}
    (evidence / "roundtrip.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return result


def run_probe_suite(package: Path, *, timeout: float = 20.0) -> dict:
    compile_result = run(package, timeout, True, False, "P031", map_name="MAP17", completion_marker="DS_P031_COMPLETE")
    if compile_result["status"] != "COMPILE_PASS":
        return {"status": "FAIL", "compile": compile_result, "errors": ["pinned UZDoom compile failed"]}

    action = run(package, timeout, False, False, "P031", map_name="MAP17", completion_marker="DS_P031_COMPLETE",
                 startup_commands=["+set", "ds_p031_mode", "demo", "+set", "ds_p031_rerolls", "2", "+set", "ds_p031_skips", "1",
                                  "+set", "ds_p031_banishes", "1", "+set", "ds_p031_test_fourth_candidate", "1"])
    action_log = _evidence_log(action)
    action_errors = _validate_action_run(action_log)
    if action["status"] != "RUNTIME_PASS":
        action_errors.append(f"action scenario result was {action['status']}, expected RUNTIME_PASS")

    slot = run(package, timeout, False, False, "P031", map_name="MAP17", completion_marker="DS_P031_COMPLETE",
               startup_commands=["+set", "ds_p031_mode", "slot_probe"])
    slot_log = _evidence_log(slot)
    slot_errors = _validate_slot_run(slot_log)
    if slot["status"] != "RUNTIME_PASS":
        slot_errors.append(f"full-slot scenario result was {slot['status']}, expected RUNTIME_PASS")

    seal = run(package, timeout, False, False, "P031", map_name="MAP17", completion_marker="DS_P031_COMPLETE",
               startup_commands=["+set", "ds_p031_mode", "seal_demo", "+set", "ds_p031_seal_capacity", "1"])
    seal_log = _evidence_log(seal)
    seal_errors: list[str] = []
    if seal["status"] != "RUNTIME_PASS":
        seal_errors.append(f"pre-run Seal scenario result was {seal['status']}, expected RUNTIME_PASS")
    if not any(row.get("accepted") == "1" and row.get("persistent") == "1" and row.get("pre_run") == "1" for row in _rows(seal_log, "DS_P031_SEAL_EDIT")):
        seal_errors.append("pre-run Seal engine-tape intent did not persist profile state")
    seal_offer_sets = _offer_id_sets(seal_log)
    if not seal_offer_sets or any(1 in choices for choices in seal_offer_sets):
        seal_errors.append("sealed WHIP appeared in a pre-run offer set")
    seal_evidence = Path(seal["evidence"])
    seal_profile = ROOT / ".local/probes" / seal_evidence.name / "config.ini"
    config_copy = seal_evidence / "profile-config.ini"
    if seal_profile.exists():
        shutil.copy2(seal_profile, config_copy)
    if not config_copy.exists() or "ds_p031_profile_seals=" not in config_copy.read_text(encoding="utf-8", errors="replace"):
        seal_errors.append("Seal profile payload was not present in the isolated persisted config")

    profile_ui = run(package, UI_CAPTURE_SECONDS, False, True, "P031", map_name="MAP17", completion_marker="DS_P031_COMPLETE",
                     startup_commands=["+set", "ds_p031_mode", "manual", "+set", "ds_p031_telemetry", "0"])
    profile_log = _evidence_log(profile_ui)
    profile_errors: list[str] = []
    if "DS_P031_PROFILE_CAPTURE" not in _flat(profile_log) or not profile_ui["captures"]:
        profile_errors.append("live pre-run Seal profile UI was not captured by UZDoom")
    if not any(row.get("state") == "PRE_RUN_PROFILE" and row.get("ui_processor") == "1" for row in _rows(profile_log, "DS_P031_INPUT_OWNER")):
        profile_errors.append("pre-run profile did not own the UI input processor")

    modal_ui = run(package, UI_CAPTURE_SECONDS, False, True, "P031", map_name="MAP17", completion_marker="DS_P031_COMPLETE",
                   startup_commands=["+set", "ds_p031_mode", "hold_modal", "+set", "ds_p031_rerolls", "1", "+set", "ds_p031_skips", "1",
                                    "+set", "ds_p031_banishes", "1", "+set", "ds_p031_telemetry", "0"])
    modal_log = _evidence_log(modal_ui)
    modal_errors: list[str] = []
    if "DS_P031_MODAL_CAPTURE" not in _flat(modal_log) or not modal_ui["captures"]:
        modal_errors.append("live level-up modal UI was not captured by UZDoom")
    if not any(row.get("state") == "LEVEL_UP_MODAL" and row.get("ui_processor") == "1" for row in _rows(modal_log, "DS_P031_INPUT_OWNER")):
        modal_errors.append("level-up modal did not own the UI input processor")

    evidence_root = ROOT / "evidence" / "P031"
    save_load = _save_load_probe(package, evidence_root, timeout)
    errors = action_errors + slot_errors + seal_errors + profile_errors + modal_errors + save_load["errors"]
    result = {"status": "PASS" if not errors else "FAIL", "classification": "P031_PACKAGED_UZDOOM_INVENTORY_DRAFT",
              "compile": compile_result, "action": {"run": action, "errors": action_errors},
              "slot": {"run": slot, "errors": slot_errors}, "seal": {"run": seal, "errors": seal_errors},
              "profile_ui": {"run": profile_ui, "errors": profile_errors},
              "modal_ui": {"run": modal_ui, "errors": modal_errors},
              "save_load": save_load, "errors": errors}
    out = Path(action["evidence"]) / "p031-suite.json"
    out.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    result["suite_result"] = str(out)
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, default=ROOT / "build/doom-survivors.ipk3")
    parser.add_argument("--timeout", type=float, default=20.0)
    args = parser.parse_args()
    result = run_probe_suite(args.package, timeout=args.timeout)
    print(json.dumps(result, indent=2), flush=True)
    raise SystemExit(0 if result["status"] == "PASS" else 1)
