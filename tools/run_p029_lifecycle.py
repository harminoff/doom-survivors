"""Run and independently validate the P029 run lifecycle.

The engine emits canonical P020/P025/P027/P028 transaction rows.  This module
recomputes every result from those rows, checks the ordered controller states,
and exercises the hashed profile through a second process.  A completion marker
without the corresponding event ledger is intentionally insufficient.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.build import build
from tools.run_probe import config_text, run

REQUIRED_CYCLES = 3
EXPECTED_RESULTS = {"kills": 1, "damage": 60, "collected_xp": 5000, "earned_currency": 1,
                   "revives": 0, "initial_store": 3, "final_store": 0,
                   "pending_attacks": 0, "active_status": 0, "menu_focus": 0, "input_latch": 0}
EXPECTED_POSES = {
    0: (0, 0, 90),
    1: (90, 0, 90),
    2: (180, 0, 90),
    3: (270, 0, 90),
    4: (0, 22, 115),
}


def flat(log: str) -> str:
    return re.sub(r"\s+", " ", log)


def fields(body: str) -> dict[str, str]:
    return {key: value for key, value in re.findall(r"([A-Za-z_][A-Za-z0-9_]*)=([^\s]+)", body)}


def rows(log: str, kind: str) -> list[dict[str, str]]:
    text = flat(log)
    pattern = re.compile(rf"DS_P029_{re.escape(kind)}\s+(.*?)(?=DS_[A-Za-z0-9_]+|$)")
    return [fields(match.group(1)) for match in pattern.finditer(text)]


def int_value(row: dict[str, str], key: str, default: int = -999999) -> int:
    try:
        return int(row.get(key, str(default)))
    except (TypeError, ValueError):
        return default


def validate(log: str, *, expected_variant: int = 0, expected_telemetry: int = 1,
             expected_cycles: int = REQUIRED_CYCLES, require_complete: bool = True) -> dict[str, Any]:
    text = flat(log)
    errors: list[str] = []
    for marker in (
        "DS_P029_BOOT map=MAP15 ticrate=35 authority=DSP029RunController",
        "DS_P029_RULES states=STARTING,ACTIVE,PAUSED_LEVELUP,ENDING,RESULTS,RESTARTING",
        "DS_P029_NATIVE_GUARD pawn=LIVE_VESSEL native_damage=DISABLED native_death=DISABLED native_respawn=DISABLED map_exit=DISABLED",
    ):
        if marker not in text:
            errors.append(f"missing required marker: {marker}")
    if re.search(r"VM execution aborted|Script error|Unknown identifier|Execution could not continue|Fatal error", text, re.I):
        errors.append("engine reported a script/runtime failure")

    transitions = rows(log, "TRANSITION")
    expected_pairs: list[tuple[str, str]] = []
    for cycle in range(expected_cycles):
        expected_pairs.extend([
            ("STARTING", "ACTIVE"), ("ACTIVE", "PAUSED_LEVELUP"),
            ("PAUSED_LEVELUP", "ACTIVE"), ("ACTIVE", "ENDING"),
            ("ENDING", "RESULTS"),
        ])
        if cycle + 1 < expected_cycles:
            expected_pairs.append(("RESULTS", "RESTARTING"))
    observed_pairs = [(row.get("from"), row.get("to")) for row in transitions]
    if observed_pairs != expected_pairs:
        errors.append(f"ordered state transitions changed: {observed_pairs!r}")

    starters = rows(log, "STARTER")
    if len(starters) != expected_cycles:
        errors.append(f"expected {expected_cycles} fresh starter snapshots, observed {len(starters)}")
    for index, starter in enumerate(starters):
        expected = {"run_id": str(index + 1), "generation": str(index + 1), "level": "1",
                    "health_milli": "120000", "armor": "1", "might_milli": "1000",
                    "whip_rank": "1", "passive_ranks": "0", "inventory": "WHIP",
                    "revives": "0", "source_character": "ANTONIO", "source_weapon": "WHIP",
                    "initial_store": "3"}
        for key, value in expected.items():
            if starter.get(key) != value:
                errors.append(f"starter {index} {key} is {starter.get(key)!r}, expected {value!r}")

    events = rows(log, "EVENT")
    if not events:
        errors.append("canonical transaction event ledger is missing")
    results = rows(log, "RESULTS")
    if len(results) != expected_cycles:
        errors.append(f"expected {expected_cycles} result snapshots, observed {len(results)}")
    for index, result in enumerate(results):
        run_id = str(index + 1)
        if result.get("run_id") != run_id or result.get("generation") != run_id:
            errors.append(f"result {index} run/generation identity changed")
        for key, value in EXPECTED_RESULTS.items():
            if result.get(key) != str(value):
                errors.append(f"result {index} {key} is {result.get(key)!r}, expected {value}")
        if result.get("ledger_derived") != "1" or result.get("currency_policy") != "ONE_PER_ACCEPTED_KILL":
            errors.append(f"result {index} is not marked as ledger-derived currency policy")
        run_events = [event for event in events if event.get("run_id") == run_id and event.get("generation") == run_id]
        totals = {"kills": sum(int_value(event, "amount", 0) for event in run_events if event.get("kind") == "DEATH"),
                  "damage": sum(int_value(event, "amount", 0) for event in run_events if event.get("kind") == "DAMAGE"),
                  "collected_xp": sum(int_value(event, "amount", 0) for event in run_events if event.get("kind") == "XP_COLLECT"),
                  "earned_currency": sum(int_value(event, "amount", 0) for event in run_events if event.get("kind") == "CURRENCY_EARN")}
        for key, value in totals.items():
            if result.get(key) != str(value):
                errors.append(f"result {index} {key} is not recomputed from event rows ({result.get(key)} vs {value})")
        if len([event for event in run_events if event.get("kind") == "DAMAGE"]) != 1:
            errors.append(f"run {index + 1} damage transaction cardinality changed")
        if len([event for event in run_events if event.get("kind") == "DEATH"]) != 1:
            errors.append(f"run {index + 1} death transaction cardinality changed")
        if len([event for event in run_events if event.get("kind") == "XP_COLLECT"]) != 1:
            errors.append(f"run {index + 1} XP collection transaction cardinality changed")
        if len([event for event in run_events if event.get("kind") == "LEVELUP"]) != 1:
            errors.append(f"run {index + 1} queued level-up transaction is missing")

    teardowns = rows(log, "TEARDOWN")
    if len(teardowns) < expected_cycles + expected_cycles - 1:
        errors.append("ending/retry teardown count is incomplete")
    for row in teardowns:
        for key in ("entities", "proxies", "pending_attacks", "status_timers", "menu_focus", "input_latch", "timers"):
            if row.get(key) != "0":
                errors.append(f"teardown retained {key}")
        if row.get("rng_streams_cleared") != "1":
            errors.append("teardown did not clear named gameplay RNG streams")

    commits = rows(log, "REWARD_COMMIT")
    by_key: dict[str, list[dict[str, str]]] = {}
    for row in commits:
        by_key.setdefault(row.get("key", ""), []).append(row)
    if len(by_key) != expected_cycles:
        errors.append("reward keys do not cover exactly one key per run")
    for index in range(expected_cycles):
        key = f"run:{index + 1}:results"
        key_rows = by_key.get(key, [])
        if len(key_rows) != 2:
            errors.append(f"reward key {key} was not committed exactly once and replayed exactly once")
        else:
            dispositions = sorted(row.get("disposition") for row in key_rows)
            if dispositions != ["ALREADY_COMMITTED", "COMMITTED"]:
                errors.append(f"reward key {key} dispositions are {dispositions!r}")
            if any(row.get("amount") != "1" for row in key_rows):
                errors.append(f"reward key {key} changed amount")
            if any(row.get("changed") not in {"0", "1"} for row in key_rows):
                errors.append(f"reward key {key} lacks a change disposition")
    if len(rows(log, "REWARD_REPLAY")) != expected_cycles:
        errors.append("same-key reward replay evidence is incomplete")
    profile_reads = rows(log, "PROFILE_READ")
    if not profile_reads or any(row.get("accepted") != "1" for row in profile_reads):
        errors.append("profile payload was not accepted with schema/hash validation")

    cameras = rows(log, "CAMERA")
    expected_pose = EXPECTED_POSES.get(expected_variant)
    if expected_pose is None or not cameras:
        errors.append("camera trace is missing")
    elif not any(tuple(int_value(row, key) for key in ("yaw", "pitch", "fov")) == expected_pose for row in cameras):
        errors.append(f"camera pose does not match variant {expected_variant}")
    if cameras and any(row.get("role") != "PRESENTATION_ONLY" for row in cameras):
        errors.append("camera trace is not presentation-only")
    traces = rows(log, "TRACE")
    if expected_telemetry and not traces:
        errors.append("telemetry-enabled run emitted no trace rows")
    if not expected_telemetry and traces:
        errors.append("telemetry-disabled run emitted trace rows")
    if require_complete:
        complete = rows(log, "COMPLETE")
        if len(complete) != 1:
            errors.append("missing or duplicate lifecycle completion row")
        elif any(complete[0].get(key) != value for key, value in {
            "cycles": str(expected_cycles), "state": "RESULTS", "kills": "1", "damage": "60",
            "collected_xp": "5000", "earned_currency": "1", "revives": "0", "clean_reset": "1",
            "durable_profile": "1", "repeated_cycles": "1", "readable_results": "1",
            "camera_invariant": "1", "presentation_only": "1",
        }.items()):
            errors.append("completion row disagrees with canonical lifecycle state")
    return {"status": "PASS" if not errors else "FAIL", "errors": errors,
            "transition_count": len(transitions), "event_count": len(events),
            "result_count": len(results), "starter_count": len(starters),
            "logical_results": results, "events": events}


NEGATIVE_MUTATIONS = {
    "stale_enemies_after_retry": lambda log: log.replace("DS_P029_TEARDOWN run_id=1 generation=1 entities=0", "DS_P029_TEARDOWN run_id=1 generation=1 entities=1", 1),
    "pending_attack_after_retry": lambda log: re.sub(r"(DS_P029_TEARDOWN[^\n]*pending_attacks=)0", r"\g<1>1", log, count=1),
    "retained_menu_focus": lambda log: re.sub(r"(DS_P029_TEARDOWN[^\n]*menu_focus=)0", r"\g<1>1", log, count=1),
    "wrong_starter_stats": lambda log: log.replace("health_milli=120000 armor=1", "health_milli=120001 armor=1", 1),
    "result_not_ledger_derived": lambda log: log.replace("DS_P029_RESULTS run_id=1 generation=1 cycle=1 kills=1", "DS_P029_RESULTS run_id=1 generation=1 cycle=1 kills=2", 1),
    "reward_twice": lambda log: log.replace("run:1:results amount=1 balance=1 disposition=ALREADY_COMMITTED", "run:1:results amount=1 balance=1 disposition=COMMITTED", 1),
    "same_key_changed_amount": lambda log: log.replace("run:1:results amount=1 balance=1 disposition=ALREADY_COMMITTED", "run:1:results amount=2 balance=1 disposition=ALREADY_COMMITTED", 1),
    "malformed_profile_accepted": lambda log: log.replace("DS_P029_PROFILE_READ accepted=1", "DS_P029_PROFILE_READ accepted=0", 1),
    "native_death_respawn": lambda log: log.replace("native_death=DISABLED native_respawn=DISABLED", "native_death=ENABLED native_respawn=ENABLED", 1),
    "missing_transition": lambda log: re.sub(r"DS_P029_TRANSITION[^\n]*\n?", "", log, count=1),
    "divergent_generation": lambda log: log.replace("DS_P029_STARTER run_id=2 generation=2", "DS_P029_STARTER run_id=2 generation=9", 1),
}


def validate_negative_mutations(log: str) -> dict[str, str]:
    outcomes: dict[str, str] = {}
    for name, mutate in NEGATIVE_MUTATIONS.items():
        outcomes[name] = validate(mutate(log))["status"]
    return outcomes


def _restart_reopen(package: Path, runtime: dict[str, Any], seconds: float) -> dict[str, Any]:
    evidence = Path(runtime["evidence"])
    profile = ROOT / ".local" / "probes" / evidence.name
    config = profile / "config.ini"
    before = next((line for line in config.read_text(encoding="utf-8").splitlines() if line.startswith("ds_p029_profile_payload=")), "")
    lock = json.loads((ROOT / "toolchain/lock.json").read_text(encoding="utf-8"))
    executable = ROOT / lock["uzdoom"]["executable"]["path"]
    log_path = evidence / "restart-engine.log"
    process_log_path = evidence / "restart-process.log"
    command = [str(executable), "-iwad", str(package.resolve()), "-config", str(config), "-savedir", str(profile),
               "-noautoload", "-noautoexec", "-noextras", "-stdout", "-width", "1280", "-height", "720",
               "+vid_fullscreen", "false", "+vid_activeinbackground", "true", "+logfile", "restart-engine-file.log",
               "+set", "ds_p029_mode", "reopen", "+map", "MAP15"]
    env = os.environ.copy()
    env.pop("DOOMWADDIR", None)
    env.pop("DOOMWADPATH", None)
    started = time.monotonic()
    process_output = process_log_path.open("w", encoding="utf-8")
    process = subprocess.Popen(command, cwd=profile, env=env, stdout=process_output, stderr=subprocess.STDOUT)
    try:
        while process.poll() is None and time.monotonic() - started < seconds:
            if process_log_path.exists():
                current = process_log_path.read_text(encoding="utf-8", errors="replace")
                if "DS_P029_DURABILITY_PASS" in current:
                    break
            time.sleep(0.1)
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
        process_output.close()
    log = process_log_path.read_text(encoding="utf-8", errors="replace") if process_log_path.exists() else ""
    after = next((line for line in config.read_text(encoding="utf-8").splitlines() if line.startswith("ds_p029_profile_payload=")), "")
    passed = ("DS_P029_PROFILE_READ accepted=1" in log and
              "DS_P029_DURABILITY_PASS" in log and
              "replay=ALREADY_COMMITTED" in log and "changed=0" in log and before == after)
    return {"status": "PASS" if passed else "FAIL", "command": command, "log": log,
            "log_path": str(process_log_path), "profile_unchanged": before == after,
            "package_sha256": runtime.get("package_sha256")}


def run_one(package: Path, *, variant: int = 0, telemetry: int = 1, seconds: float = 10.0) -> dict[str, Any]:
    runtime = run(package, seconds, False, False, "P029", 60, 1280, 720,
                  map_name="MAP15", completion_marker="DS_P029_COMPLETE", active_in_background=True,
                  vsync=False, startup_commands=["+set", "ds_p029_mode", "demo",
                                                 "+set", "ds_p029_camera_variant", str(variant),
                                                 "+set", "ds_p029_telemetry", str(telemetry)])
    evidence = Path(runtime["evidence"])
    log_path = evidence / "engine.log"
    log = log_path.read_text(encoding="utf-8", errors="replace") if log_path.exists() else ""
    checked = validate(log, expected_variant=variant, expected_telemetry=telemetry)
    if runtime.get("status") != "RUNTIME_PASS":
        checked["errors"].append(f"runtime status was {runtime.get('status')}")
    if not runtime.get("captures") or not all(capture.get("nonblank") for capture in runtime["captures"]):
        checked["errors"].append("required nonblank results framebuffer is missing")
    checked["status"] = "PASS" if not checked["errors"] else "FAIL"
    checked.update({"variant": variant, "telemetry": telemetry, "runtime": runtime,
                    "engine_log": str(log_path), "package_sha256": runtime.get("package_sha256")})
    return checked


def validate_return_menu(log: str) -> dict[str, Any]:
    """Validate the UI-owned Escape return against the normal lifecycle oracle."""
    checked = validate(log)
    text = flat(log)
    errors = checked["errors"]
    accepted = rows(log, "RETURN_MENU_ACCEPTED")
    opened = rows(log, "RETURN_MENU_OPENED")
    passed = rows(log, "RETURN_MENU_PASS")
    if len(accepted) != 1:
        errors.append("return-to-menu intent was not accepted exactly once")
    else:
        row = accepted[0]
        for key, value in {
            "state": "RESULTS", "frozen": "1", "entities": "0", "proxies": "0",
            "pending_attacks": "0", "status_timers": "0", "menu_focus": "0",
            "input_latch": "0", "timers": "0", "rng_streams_cleared": "1",
        }.items():
            if row.get(key) != value:
                errors.append(f"return-to-menu retained {key} or unfroze the RESULTS state")
    if len(opened) != 1 or opened[0].get("menu") != "MainMenu" or opened[0].get("results_closed") != "1":
        errors.append("UI Escape did not open MainMenu and close the results overlay")
    if len(passed) != 1 or passed[0].get("state") != "RESULTS" or passed[0].get("frozen") != "1":
        errors.append("return-to-menu completion proof is missing")
    if "DS_P029_INTENT_REJECT action=RETURN" in text:
        errors.append("supported return-to-menu intent was rejected")
    if "Level.ChangeLevel" in text or "native_exit=ENABLED" in text:
        errors.append("return-to-menu path used a native level/exit route")
    if text.find("DS_P029_RETURN_MENU_OPENED") > text.find("DS_P029_RETURN_MENU_ACCEPTED") >= 0:
        errors.append("UI menu route was logged after the play-side acceptance")
    checked["status"] = "PASS" if not errors else "FAIL"
    checked["return_menu"] = {"accepted": accepted, "opened": opened, "passed": passed}
    return checked


def run_return_menu(package: Path, *, seconds: float = 10.0) -> dict[str, Any]:
    """Run the actual engine Escape/Menu.SetMenu route after final RESULTS."""
    runtime = run(package, seconds, False, False, "P029", 60, 1280, 720,
                  map_name="MAP15", completion_marker="DS_P029_RETURN_MENU_PASS",
                  active_in_background=True, vsync=False,
                  startup_commands=["+set", "ds_p029_mode", "return_menu",
                                    "+set", "ds_p029_camera_variant", "0",
                                    "+set", "ds_p029_telemetry", "1"])
    evidence = Path(runtime["evidence"])
    log_path = evidence / "engine.log"
    log = log_path.read_text(encoding="utf-8", errors="replace") if log_path.exists() else ""
    checked = validate_return_menu(log)
    if runtime.get("status") != "RUNTIME_PASS":
        checked["errors"].append(f"return-menu runtime status was {runtime.get('status')}")
    if not runtime.get("captures") or not all(capture.get("nonblank") for capture in runtime["captures"]):
        checked["errors"].append("return-menu results framebuffer is missing or blank")
    checked["status"] = "PASS" if not checked["errors"] else "FAIL"
    checked.update({"runtime": runtime, "engine_log": str(log_path),
                    "package_sha256": runtime.get("package_sha256")})
    return checked


def run_profile_mutation(package: Path, *, mode: str, payload: str, seconds: float,
                         config_template: Path | None = None) -> dict[str, Any]:
    stamp = f"{time.strftime('%Y%m%dT%H%M%S', time.gmtime())}{time.time_ns() % 1000000:06d}Z-p029-{mode}"
    evidence = ROOT / "evidence" / "P029" / stamp
    profile = ROOT / ".local" / "probes" / stamp
    evidence.mkdir(parents=True, exist_ok=True)
    profile.mkdir(parents=True, exist_ok=True)
    config = profile / "config.ini"
    if config_template is not None:
        config_body = config_template.read_text(encoding="utf-8")
        config_body = re.sub(r"^ds_p029_profile_payload=.*$", f"ds_p029_profile_payload={payload}", config_body, flags=re.MULTILINE)
        if "ds_p029_profile_payload=" not in config_body:
            config_body += f"\nds_p029_profile_payload={payload}\n"
    else:
        config_body = config_text(evidence, 60, 1280, 720, True, False, 1)
        config_body += f"\nds_p029_mode={mode}\nds_p029_profile_payload={payload}\n"
    config.write_text(config_body, encoding="utf-8", newline="\n")
    lock = json.loads((ROOT / "toolchain/lock.json").read_text(encoding="utf-8"))
    executable = ROOT / lock["uzdoom"]["executable"]["path"]
    process_log_path = evidence / "process.log"
    engine_source_log = profile / "log-engine-log.txt"
    command = [str(executable), "-iwad", str(package.resolve()), "-config", str(config), "-savedir", str(profile),
               "-noautoload", "-noautoexec", "-noextras", "-stdout", "-width", "1280", "-height", "720",
               "+vid_fullscreen", "false", "+vid_activeinbackground", "true", "+logfile", "engine.log",
               "+set", "ds_p029_mode", mode, "+map", "MAP15"]
    env = os.environ.copy()
    env.pop("DOOMWADDIR", None)
    env.pop("DOOMWADPATH", None)
    process_output = process_log_path.open("w", encoding="utf-8")
    started = time.monotonic()
    process = subprocess.Popen(command, cwd=profile, env=env, stdout=process_output, stderr=subprocess.STDOUT)
    try:
        while process.poll() is None and time.monotonic() - started < seconds:
            if engine_source_log.exists() and "DS_P029_MUTATION_PASS" in engine_source_log.read_text(encoding="utf-8", errors="replace"):
                break
            time.sleep(0.1)
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
        process_output.close()
    log = engine_source_log.read_text(encoding="utf-8", errors="replace") if engine_source_log.exists() else process_log_path.read_text(encoding="utf-8", errors="replace")
    log_path = evidence / "engine.log"
    log_path.write_text(log, encoding="utf-8")
    errors: list[str] = []
    runtime_status = "RUNTIME_PASS" if "DS_P029_MUTATION_PASS" in log else "INCOMPLETE"
    if runtime_status != "RUNTIME_PASS":
        errors.append(f"mutation runtime status was {runtime_status}")
    marker = "scenario=SAME_KEY_AMOUNT_CHANGED" if mode == "same_key_changed" else "scenario=MALFORMED_OR_HASH_MISMATCH"
    if f"DS_P029_MUTATION_PASS {marker} accepted=0 partial_apply=0 payload_unchanged=1 balance_unchanged=1" not in flat(log):
        errors.append(f"{mode} did not prove fail-closed unchanged profile state")
    if mode == "same_key_changed" and "reason=SAME_KEY_AMOUNT_CHANGED partial_apply=0" not in flat(log):
        errors.append("same-key changed amount rejection reason is missing")
    if mode == "malformed_profile" and "DS_P029_PROFILE_REJECT reason=MALFORMED_OR_HASH_MISMATCH" not in flat(log):
        errors.append("malformed/hash-mismatched profile rejection marker is missing")
    return {"status": "PASS" if not errors else "FAIL", "mode": mode, "errors": errors,
            "runtime": {"status": runtime_status, "command": command, "evidence": str(evidence),
                        "package_sha256": hashlib.sha256(package.read_bytes()).hexdigest()},
            "engine_log": str(log_path), "log": log}


def run_probe(*, package: Path | None = None, seconds: float = 10.0) -> dict[str, Any]:
    if not 6.0 <= seconds <= 120.0:
        raise ValueError("seconds must be between 6 and 120")
    if package is None:
        package = Path(build(ROOT, room_spec=ROOT / "maps/source/p029-lifecycle/room.json")["package"])
    package = Path(package)
    compile_runtime = run(package, seconds, True, False, "P029", 60, 1280, 720,
                          map_name="MAP15", completion_marker="DS_P029_COMPLETE",
                          active_in_background=True, vsync=False)
    if compile_runtime.get("status") != "COMPILE_PASS":
        return {"status": "FAIL", "classification": "P029_PACKAGED_UZDOOM_LIFECYCLE",
                "errors": ["compile gate failed"], "compile": compile_runtime}
    compile_sha = compile_runtime["package_sha256"]
    baseline = run_one(package, variant=0, seconds=seconds)
    runs = [baseline]
    runs.extend(run_one(package, variant=index, seconds=seconds) for index in range(1, 5))
    runs.append(run_one(package, variant=0, telemetry=0, seconds=seconds))
    errors = [f"run {index}: {error}" for index, result in enumerate(runs) for error in result["errors"]]
    if any(result.get("package_sha256") != compile_sha for result in runs):
        errors.append("runtime package differs from compile gate")
    base_log = Path(baseline["engine_log"]).read_text(encoding="utf-8", errors="replace")
    for index, result in enumerate(runs[1:5], 1):
        if result.get("logical_results") != baseline.get("logical_results"):
            errors.append(f"camera variant {index} changed logical results")
    if runs[5].get("logical_results") != baseline.get("logical_results"):
        errors.append("telemetry setting changed logical results")
    negatives = validate_negative_mutations(base_log)
    for name, status in negatives.items():
        if status != "FAIL":
            errors.append(f"negative mutation {name} was accepted")
    baseline_profile = ROOT / ".local" / "probes" / Path(baseline["runtime"]["evidence"]).name / "config.ini"
    profile_line = next((line for line in baseline_profile.read_text(encoding="utf-8").splitlines()
                         if line.startswith("ds_p029_profile_payload=")), "")
    profile_payload = profile_line.split("=", 1)[1] if "=" in profile_line else ""
    same_key = run_profile_mutation(package, mode="same_key_changed", payload=profile_payload, seconds=seconds,
                                     config_template=baseline_profile)
    malformed_payload = re.sub(r";hash=-?\d+$", ";hash=0", profile_payload)
    malformed = run_profile_mutation(package, mode="malformed_profile", payload=malformed_payload, seconds=seconds,
                                     config_template=baseline_profile)
    for mutation in (same_key, malformed):
        errors.extend(f"{mutation['mode']}: {error}" for error in mutation["errors"])
    restart = _restart_reopen(package, baseline["runtime"], seconds)
    if restart["status"] != "PASS":
        errors.append("process-restart durable profile replay failed")
    return_menu = run_return_menu(package, seconds=seconds)
    errors.extend(f"return_menu: {error}" for error in return_menu["errors"])
    if return_menu.get("package_sha256") != compile_sha:
        errors.append("return-menu runtime package differs from compile gate")
    result = {"status": "PASS" if not errors else "FAIL", "classification": "P029_PACKAGED_UZDOOM_LIFECYCLE",
              "package": str(package), "package_sha256": hashlib.sha256(package.read_bytes()).hexdigest(),
              "compile": compile_runtime, "runs": runs, "profile_mutations": [same_key, malformed], "restart": restart,
              "return_menu": return_menu,
              "negative_mutations": negatives, "errors": errors}
    evidence_dir = ROOT / "evidence" / "P029"
    evidence_dir.mkdir(parents=True, exist_ok=True)
    result["evidence"] = str(evidence_dir / "latest-result.json")
    (evidence_dir / "latest-result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2, sort_keys=True))
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path)
    parser.add_argument("--seconds", type=float, default=10.0)
    parser.add_argument("--validate-log", type=Path)
    parser.add_argument("--variant", type=int, default=0)
    parser.add_argument("--telemetry", type=int, default=1)
    args = parser.parse_args(argv)
    try:
        if args.validate_log:
            result = validate(args.validate_log.read_text(encoding="utf-8", errors="replace"),
                              expected_variant=args.variant, expected_telemetry=args.telemetry)
        else:
            result = run_probe(package=args.package, seconds=args.seconds)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    return 0 if result.get("status") == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
