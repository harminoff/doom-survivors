"""Build and strictly validate the packaged P027 experience runtime.

The validator derives ledgers, handle ordering, circle boundaries and motion
from the engine's complete logical trace. Presentation markers are checked
separately, and a real UZDoom save/load continuation is compared with a fresh
uninterrupted control.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.build import build
from tools.run_persistence_bench import config_text as persistence_config, read_log, run_engine
from tools.run_probe import run

RUN_TICS = 105
XP_VALUE = 1000
COLLECT_RADIUS = 24.0
ATTRACT_RADIUS = 96.0
ATTRACT_SPEED = 8.0
DEADLINE_EXIT_CODE = -9


def flat(log: str) -> str:
    return re.sub(r"\s+", " ", log)


def fields(body: str) -> dict[str, str]:
    return {key: value for key, value in re.findall(r"([A-Za-z_][A-Za-z0-9_]*)=([^\s]+)", body)}


def rows(log: str, marker: str) -> list[dict[str, str]]:
    text = flat(log)
    pattern = re.compile(rf"{re.escape(marker)}\s+(.*?)(?=\sDS_[A-Z0-9_]+\s|$)")
    return [fields(match.group(1)) for match in pattern.finditer(text)]


def signed32(value: int) -> int:
    value &= 0xFFFFFFFF
    return value - 0x100000000 if value >= 0x80000000 else value


def logical_stream(log: str) -> list[str]:
    text = flat(log)
    starts: list[tuple[int, str]] = []
    for kind in ("XP_REQUEST", "CREATE", "MERGE", "ATTRACT", "COLLECTION", "TEARDOWN", "REUSE", "STALE_COLLECTION", "REBASE"):
        starts.extend((match.start(), kind + ":" + json.dumps(fields(match.group(1)), sort_keys=True, separators=(",", ":")))
                      for match in re.finditer(rf"DS_P027_{kind}\s+(.*?)(?=\sDS_[A-Z0-9_]+\s|$)", text))
    return [value for _, value in sorted(starts)]


def ordered_rows(log: str, kinds: tuple[str, ...]) -> list[tuple[str, dict[str, str]]]:
    text = flat(log)
    found: list[tuple[int, str, dict[str, str]]] = []
    for kind in kinds:
        for match in re.finditer(rf"DS_P027_{kind}\s+(.*?)(?=\sDS_[A-Z0-9_]+\s|$)", text):
            found.append((match.start(), kind, fields(match.group(1))))
    return [(kind, row) for _, kind, row in sorted(found)]


def _record_errors() -> list[str]:
    path = ROOT / "data/verified/base/pickups/gem.json"
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        return [f"gem record load failed: {exc}"]
    errors: list[str] = []
    if document.get("lifecycle") != "PROMOTED_IMMUTABLE":
        errors.append("gem record is not promoted immutable")
    if document.get("source_key") != "GEM" or document.get("display_name") != "Experience Gem":
        errors.append("gem identity changed")
    if document.get("reference_build") != "1.16.107" or document.get("steam_build") != "25016043":
        errors.append("gem record build identity changed")
    fields_data = document.get("fields", {})
    expected = {
        "value_milliunits": 1000,
        "collection_radius": 24,
        "attraction_radius": 96,
        "attraction_speed": 8,
        "merge_rule": "exact_xy_same_batch_lowest_stable_id",
    }
    for name, value in expected.items():
        if fields_data.get(name, {}).get("value") != value:
            errors.append(f"gem {name} changed")
    for name, value in fields_data.items():
        if value.get("provenance") not in {"BUILD_EXTRACTED", "ENGINEERING_APPROXIMATION"}:
            errors.append(f"gem field {name} lacks provenance class")
    return errors


def _f(row: dict[str, str], key: str) -> float:
    return float(row[key])


def validate(log: str, *, expected_variant: int = 0, expected_proxy: int = 0,
             expected_indicator: int = 1, continuation: bool = False) -> dict[str, Any]:
    text = flat(log)
    errors = _record_errors()
    if re.search(r"VM execution aborted|Script error|Unknown identifier|Execution could not continue|Unknown class", text):
        errors.append("engine reported a script/runtime failure")
    required_markers = (
        "DS_BOOT map=MAP13",
        "DS_P027_BOOT map=MAP13 ticrate=35 store=DSP027ExperienceStore",
        "gem_id=GEM gem_name=Experience_Gem source_identity=BUILD_EXTRACTED",
        "logical_store=DSP027ExperienceStore handles=DSP020_FULL_HANDLE broad_phase=DSP024SpatialIndex",
        "source_requests=P023_P026_DEATH_REWARD presentation=DSP027ExperienceProxy proxy_authored_xp=0 native_pickup=0",
        "value_milliunits=1000 value_provenance=ENGINEERING_APPROXIMATION collection_radius=24.000 attraction_radius=96.000 attraction_speed=8.000 speed_clamp=1 edges=INCLUSIVE",
        "merge=EXACT_XY_SAME_BATCH_LOWEST_STABLE_ID ordinary_expiry=0",
        "pitch_fov_presentation_only=1",
    )
    if continuation:
        required_markers = tuple(marker for marker in required_markers if marker != "DS_BOOT map=MAP13" and not marker.startswith("DS_P027_BOOT") and not marker.startswith("gem_id=") and not marker.startswith("logical_store=") and not marker.startswith("source_requests=") and not marker.startswith("value_milliunits=") and not marker.startswith("merge=") and marker != "pitch_fov_presentation_only=1")
    for marker in required_markers:
        if marker not in text:
            errors.append(f"missing marker: {marker}")
    camera = rows(log, "DS_P027_CAMERA")
    expected_camera = {0: (0, 0, 90), 1: (90, 0, 90), 2: (180, 0, 90), 3: (270, 0, 90), 4: (0, 22, 115)}.get(expected_variant)
    if expected_camera is None or not camera:
        errors.append("camera presentation trace is missing")
    elif tuple(int(camera[-1].get(k, -999)) for k in ("yaw", "pitch", "fov")) != expected_camera:
        errors.append(f"camera pose does not match expected variant {expected_variant}")
    complete_rows = rows(log, "DS_P027_COMPLETE")
    complete = complete_rows[-1] if complete_rows else None
    if complete is None:
        errors.append("missing P027 completion marker")
    else:
        for key, value in (("tics", RUN_TICS), ("camera_variant", expected_variant), ("proxy_variant", expected_proxy), ("indicator", expected_indicator), ("ledger_invariant", 1), ("ordinary_expiry", 0), ("proxy_authored_xp", 0)):
            if complete.get(key) != str(value):
                errors.append(f"completion {key} is not {value}")
        if complete.get("camera_invariant") != "true":
            errors.append("camera invariance marker is missing")
    requests = rows(log, "DS_P027_XP_REQUEST")
    creates = rows(log, "DS_P027_CREATE")
    merges = rows(log, "DS_P027_MERGE")
    attracts = rows(log, "DS_P027_ATTRACT")
    collections = rows(log, "DS_P027_COLLECTION")
    ledgers = rows(log, "DS_P027_LEDGER")
    queries = rows(log, "DS_P027_QUERY")
    if not continuation and len(requests) != 23:
        errors.append(f"expected 23 death XP requests, observed {len(requests)}")
    if len(creates) != len(requests):
        errors.append("every XP request did not create exactly one logical gem")
    if not continuation and len(merges) != 15:
        errors.append(f"expected 15 exact-XY pile merges, observed {len(merges)}")
    if not attracts and not continuation:
        errors.append("attraction trace is empty")
    if not collections and not continuation:
        errors.append("collection trace is empty")
    if not queries and not continuation:
        errors.append("P024 query trace is empty")
    # Independent value and handle audit.
    created = collected = removed = 0
    handles: dict[tuple[int, int, int], dict[str, Any]] = {}
    accepted_collections: set[tuple[int, int, int]] = set()
    for row in creates:
        try:
            handle = (int(row["slot"]), int(row["generation"]), int(row["stable_id"]))
            value = int(row["value"])
            if row.get("state") != "GROUND" or value <= 0 or value != XP_VALUE:
                errors.append("malformed or non-positive create transaction")
            if handle in handles:
                errors.append("duplicate live handle admitted")
            handles[handle] = {"x": _f(row, "x"), "y": _f(row, "y"), "batch": int(row["batch"]), "value": value}
            created += value
        except (KeyError, ValueError):
            errors.append("malformed create row")
    for row in merges:
        try:
            keep = (int(row["keep_slot"]), int(row["keep_generation"]), int(row["keep_id"]))
            merge = (int(row["merge_slot"]), int(row["merge_generation"]), int(row["merge_id"]))
            if int(row.get("exact_xy", 0)) != 1 or int(row.get("near_merge", 1)) != 0 or keep[2] >= merge[2]:
                errors.append("merge violates exact-XY lowest-stable rule")
            if keep not in handles or merge not in handles:
                errors.append("merge references an unknown create handle")
            else:
                if handles[keep]["batch"] != int(row["batch"]) or handles[merge]["batch"] != int(row["batch"]):
                    errors.append("merge batch does not match create batch")
                if abs(handles[keep]["x"] - handles[merge]["x"]) > 1e-6 or abs(handles[keep]["y"] - handles[merge]["y"]) > 1e-6:
                    errors.append("merge handles do not have exact create coordinates")
                handles[keep]["value"] += handles[merge]["value"]
                del handles[merge]
        except (KeyError, ValueError):
            errors.append("malformed merge row")
    # Motion is independently recomputed from source-plane coordinates.
    saw_boundary = False
    saw_attraction_boundary = False
    for row in attracts:
        try:
            before = (_f(row, "from").strip("(),"),)
        except (KeyError, ValueError):
            # Parse tuple fields explicitly because fields() retains commas.
            before = ()
        try:
            from_text = row["from"].strip("()")
            to_text = row["to"].strip("()")
            target_text = row["target"].strip("()")
            bx, by = (float(value) for value in from_text.split(","))
            ax, ay = (float(value) for value in to_text.split(","))
            tx, ty = (float(value) for value in target_text.split(","))
            before_distance = math.hypot(bx - tx, by - ty)
            after_distance = math.hypot(ax - tx, ay - ty)
            step = float(row["step"])
            if abs(before_distance - float(row["distance_before"])) > 0.01 or abs(after_distance - float(row["distance_after"])) > 0.01:
                errors.append("attraction distance is not independently derived")
            if step < -1e-9 or step > ATTRACT_SPEED + 1e-6 or after_distance > before_distance + 1e-6:
                errors.append("attraction step overshoots or exceeds speed clamp")
            if int(row.get("inclusive", 0)) != 1 or int(row.get("clamp_no_overshoot", 0)) != 1 or int(row.get("camera_ignored", 0)) != 1:
                errors.append("attraction omitted an authoritative invariant")
            if abs(before_distance - 24.001) < 0.01:
                saw_attraction_boundary = True
            if abs(before_distance - 24.0) < 0.01:
                saw_boundary = True
        except (KeyError, ValueError):
            errors.append("malformed attraction row")
    for row in collections:
        try:
            handle = (int(row["slot"]), int(row["generation"]), int(row["stable_id"]))
            accepted = int(row["accepted"])
            value = int(row["value"])
            if accepted == 1:
                if handle in accepted_collections:
                    errors.append("logical pickup was collected twice")
                accepted_collections.add(handle)
                collected += value
                if abs(float(row["radius"]) - COLLECT_RADIUS) > 1e-6 or int(row.get("inclusive", 0)) != 1:
                    errors.append("collection radius or inclusive boundary was mutated")
            elif accepted != 0:
                errors.append("collection accepted flag is not boolean")
        except (KeyError, ValueError):
            errors.append("malformed collection row")
    teardown = rows(log, "DS_P027_TEARDOWN")
    for row in teardown:
        try:
            if int(row["accepted"]) != 1 or int(row.get("ordinary_expiry", 1)) != 0:
                errors.append("teardown is not explicit")
            removed += int(row["value"])
        except (KeyError, ValueError):
            errors.append("malformed teardown row")
    if not continuation and created != XP_VALUE * len(creates):
        errors.append("independent created value does not match requests")
    if complete is not None:
        if not continuation:
            for key, value in (("created", created), ("collected", collected), ("removed", removed)):
                if complete.get(key) != str(value):
                    errors.append(f"completion {key} disagrees with independent transaction sum")
        try:
            remaining = int(complete["remaining"])
            if not continuation and created != remaining + collected + removed:
                errors.append("created != remaining + collected + removed")
        except (KeyError, ValueError):
            errors.append("completion ledger is malformed")
    if not continuation and not saw_boundary:
        errors.append("inclusive 24-unit collection boundary is absent")
    if not continuation and not saw_attraction_boundary:
        errors.append("24.001-unit near boundary is absent from attraction trace")
    if not continuation and not any(int(row.get("duplicate_candidates", 0)) > 0 for row in queries):
        errors.append("overlapping P024 query paths did not demonstrate dedupe")
    stale = rows(log, "DS_P027_STALE_COLLECTION")
    if not stale or any(row.get("accepted") != "0" or row.get("reason") != "STALE_GENERATION" for row in stale):
        errors.append("stale generation rejection is missing or accepted")
    if not continuation and ("DS_P027_REBASE" not in text or "logical_preserved=1 handles_preserved=1 values_preserved=1 timing_preserved=1" not in text):
        errors.append("rebase preservation marker is missing")
    if "DS_P027_PRESENTATION" not in text or "gameplay_ignored=1" not in text:
        errors.append("presentation-only proxy marker is missing")
    if not ledgers or any(row.get("invariant") != "1" for row in ledgers):
        errors.append("ledger trace does not prove invariant after each transaction")
    if not continuation:
        expected_ledgers = 1 + len(creates) + len(merges) + len(collections) + len(teardown) + len(queries) + (1 if "DS_P027_REBASE" in text else 0) + (1 if "DS_P027_REUSE" in text else 0)
        if len(ledgers) != expected_ledgers:
            errors.append(f"ledger trace is truncated: expected {expected_ledgers}, observed {len(ledgers)}")
    return {"status": "PASS" if not errors else "FAIL", "classification": "P027_PACKAGED_UZDOOM_EXPERIENCE_STORE", "errors": errors,
            "request_count": len(requests), "create_count": len(creates), "merge_count": len(merges), "attraction_count": len(attracts),
            "collection_rows": len(collections), "ledger_rows": len(ledgers), "logical_stream_count": len(logical_stream(log))}


def validate_savepoint(save_log: str, restored_log: str, save_file: Path | None) -> dict[str, Any]:
    """Validate the real engine save boundary and its first restored tick."""
    errors: list[str] = []
    save_ready = rows(save_log, "DS_P027_SAVE_READY")
    candidates = rows(save_log, "DS_P027_SAVE_CANDIDATE")
    restore = rows(restored_log, "DS_P027_RESTORE")
    pickups = rows(save_log, "DS_P027_SAVE_PICKUP")
    if save_file is None or not save_file.is_file() or save_file.stat().st_size <= 0:
        errors.append("engine save file is missing or empty")
    if len(save_ready) != 1:
        errors.append("save process must emit one exact P027 save-ready marker")
    else:
        ready = save_ready[-1]
        if ready.get("tic") != "23":
            errors.append("save-ready marker is not at the declared tic-23 boundary")
        if ready.get("invariant") != "1":
            errors.append("save-ready ledger invariant is false")
        matching = [row for row in candidates if row.get("tic") == ready.get("tic") and row.get("hash") == ready.get("hash") and row.get("live") == ready.get("live") and row.get("created") == ready.get("created") and row.get("remaining") == ready.get("remaining") and row.get("collected") == ready.get("collected") and row.get("removed") == ready.get("removed") and row.get("invariant") == "1"]
        if not matching:
            errors.append("save-ready state does not match a candidate snapshot")
        ready_pickups = [row for row in pickups if row.get("tic") == ready.get("tic")]
        if len(ready_pickups) != int(ready.get("live", -1)):
            errors.append("save-ready live pickup handle snapshot is incomplete")
        for row in ready_pickups:
            try:
                if row.get("state") not in {"GROUND", "ATTRACTING"} or int(row["value"]) <= 0:
                    errors.append("save-ready pickup has invalid live state/value")
                float(row["x"]); float(row["y"])
            except (KeyError, ValueError):
                errors.append("save-ready pickup handle snapshot is malformed")
    if len(restore) != 1:
        errors.append("load process must emit one restored P027 marker")
    elif save_ready:
        ready = save_ready[-1]
        restored = restore[-1]
        for key in ("tic", "hash", "live", "created", "remaining", "collected", "removed"):
            if restored.get(key) != ready.get(key):
                errors.append(f"restored {key} disagrees with save-ready state")
    if re.search(r"VM execution aborted|Script error|Unknown identifier|Execution could not continue", flat(save_log + restored_log)):
        errors.append("save/load log contains an engine script failure")
    return {"status": "PASS" if not errors else "FAIL", "classification": "P027_REAL_ENGINE_SAVEPOINT", "errors": errors,
            "save_ready": save_ready[-1] if save_ready else None, "restore": restore[-1] if restore else None,
            "candidate_count": len(candidates), "pickup_snapshot_count": len(pickups),
            "save_file_bytes": save_file.stat().st_size if save_file and save_file.exists() else 0}


def _metadata(package: Path, compile_result: dict[str, Any]) -> dict[str, Any]:
    lock = json.loads((ROOT / "toolchain/lock.json").read_text(encoding="utf-8"))
    engine = ROOT / lock["uzdoom"]["executable"]["path"]
    return {"package_sha256": hashlib.sha256(package.read_bytes()).hexdigest(), "compile_package_sha256": compile_result.get("package_sha256"),
            "engine_sha256": hashlib.sha256(engine.read_bytes()).hexdigest(), "source_commit": lock["uzdoom"]["source"]["commit"]}


def _profile_config(path: Path) -> str:
    # Keep all probe settings local and avoid carrying a user's normal profile.
    return persistence_config(path)


def run_probe(*, package: Path | None = None, seconds: float = 20.0) -> dict[str, Any]:
    if not 8.0 <= seconds <= 120.0:
        raise ValueError("seconds must be between 8 and 120")
    if package is None:
        package = Path(build(ROOT, room_spec=ROOT / "maps/source/p027-xp/room.json")["package"])
    package = Path(package)
    compile_result = run(package, seconds, True, False, "P027", 60, 1280, 720, map_name="MAP13", completion_marker="DS_P027_COMPLETE")
    if compile_result["status"] != "COMPILE_PASS":
        return {"status": "FAIL", "classification": "P027_PACKAGED_UZDOOM_EXPERIENCE_STORE", "errors": ["compile gate failed"], "compile": compile_result}
    canonical_run = run(package, seconds, False, False, "P027", 60, 1280, 720, map_name="MAP13", completion_marker="DS_P027_COMPLETE")
    canonical_path = Path(canonical_run["evidence"]) / "process.log"
    canonical_log = canonical_path.read_text(encoding="utf-8", errors="replace") if canonical_path.exists() else ""
    result = validate(canonical_log, expected_variant=0, expected_proxy=0, expected_indicator=1)
    result.update({"compile": compile_result, "canonical_run": canonical_run, **_metadata(package, compile_result)})
    if result["package_sha256"] != result["compile_package_sha256"]:
        result["errors"].append("package changed between compile and runtime")
    # Run the presentation matrix. Every variant must retain the same ordered
    # logical counts and final ledger while changing only visual controls.
    variants: list[dict[str, Any]] = []
    for camera_variant in range(5):
        probe = run(package, seconds, False, False, "P027", 60, 1280, 720, map_name="MAP13", completion_marker="DS_P027_COMPLETE",
                    startup_commands=["+set", "ds_p027_camera_variant", str(camera_variant)])
        path = Path(probe["evidence"]) / "process.log"
        log = path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""
        checked = validate(log, expected_variant=camera_variant, expected_proxy=0, expected_indicator=1)
        variants.append({"camera_variant": camera_variant, "run": probe, "validation": checked})
        if checked["status"] != "PASS": result["errors"].append(f"camera variant {camera_variant} failed validation")
    presentation_variants: list[dict[str, Any]] = []
    for proxy_variant, indicator_variant in ((0, 0), (1, 1), (2, 1), (0, 1)):
        probe = run(package, seconds, False, False, "P027", 60, 1280, 720, map_name="MAP13", completion_marker="DS_P027_COMPLETE",
                    startup_commands=["+set", "ds_p027_proxy_variant", str(proxy_variant), "+set", "ds_p027_indicator", str(indicator_variant)])
        path = Path(probe["evidence"]) / "process.log"
        log = path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""
        checked = validate(log, expected_variant=0, expected_proxy=proxy_variant, expected_indicator=indicator_variant)
        complete_variant = rows(log, "DS_P027_COMPLETE")
        canonical_rows = rows(canonical_log, "DS_P027_COMPLETE")
        if complete_variant and canonical_rows:
            if complete_variant[-1].get("hash") != canonical_rows[-1].get("hash"):
                checked["errors"].append("presentation variant changed logical final hash")
                checked["status"] = "FAIL"
        presentation_variants.append({"proxy_variant": proxy_variant, "indicator_variant": indicator_variant, "run": probe, "validation": checked})
        if checked["status"] != "PASS": result["errors"].append(f"presentation variant {proxy_variant}/{indicator_variant} failed validation")
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    evidence = ROOT / "evidence" / "P027" / f"{stamp}-xp-save-roundtrip"
    evidence.mkdir(parents=True)
    profile = ROOT / ".local" / "probes" / f"{stamp}-p027-save"
    profile.mkdir(parents=True)
    (profile / "config.ini").write_text(_profile_config(evidence), encoding="utf-8", newline="\n")
    (profile / "save.cfg").write_text('wait 22; save ds_p027_roundtrip "P027 XP"; wait 8; quit\n', encoding="utf-8", newline="\n")
    (profile / "load.cfg").write_text("wait 100; quit\n", encoding="utf-8", newline="\n")
    executable = ROOT / json.loads((ROOT / "toolchain/lock.json").read_text())["uzdoom"]["executable"]["path"]
    first_rc = run_engine(executable, package, profile, "save.log", ["+map", "MAP13", "+exec", "save.cfg"], timeout=seconds)
    first_log = read_log(profile, "save.log")
    saves = sorted(path for path in profile.glob("ds_p027_roundtrip*") if path.is_file())
    save_file = saves[0] if saves else None
    restored_log = ""
    load_rc = None
    if save_file is not None:
        load_rc = run_engine(executable, package, profile, "load.log", ["-loadgame", save_file.stem, "+exec", "load.cfg"], timeout=seconds)
        restored_log = read_log(profile, "load.log")
    (evidence / "canonical-engine.log").write_text(canonical_log, encoding="utf-8", newline="\n")
    (evidence / "save-engine.log").write_text(first_log, encoding="utf-8", newline="\n")
    (evidence / "load-engine.log").write_text(restored_log, encoding="utf-8", newline="\n")
    savepoint_validation = validate_savepoint(first_log, restored_log, save_file)
    if savepoint_validation["status"] != "PASS":
        result["errors"].append("real engine savepoint validation failed")
    restored_validation = validate(restored_log, expected_variant=0, expected_proxy=0, expected_indicator=1, continuation=True)
    if restored_validation["status"] != "PASS": result["errors"].append("restored run failed independent validation")
    canonical_complete = rows(canonical_log, "DS_P027_COMPLETE")[-1] if rows(canonical_log, "DS_P027_COMPLETE") else {}
    restored_complete = rows(restored_log, "DS_P027_COMPLETE")[-1] if rows(restored_log, "DS_P027_COMPLETE") else {}
    for key in ("tics", "hash", "requests", "collections", "merges", "created", "remaining", "collected", "removed"):
        if canonical_complete.get(key) != restored_complete.get(key):
            result["errors"].append(f"save/load continuation changed canonical {key}")
    if "DS_P027_RESTORE first_tick=1" not in flat(restored_log):
        result["errors"].append("load process did not report a restored P027 store")
    control_suffix = []
    for kind, row in ordered_rows(canonical_log, ("XP_REQUEST", "CREATE", "MERGE", "ATTRACT", "COLLECTION", "TEARDOWN", "REUSE", "STALE_COLLECTION", "REBASE")):
        try:
            if int(row.get("tic", 0)) >= 23:
                control_suffix.append((kind, row))
        except ValueError:
            result["errors"].append("canonical continuation event has a malformed tic")
    restored_suffix = ordered_rows(restored_log, ("XP_REQUEST", "CREATE", "MERGE", "ATTRACT", "COLLECTION", "TEARDOWN", "REUSE", "STALE_COLLECTION", "REBASE"))
    # Drop fields that are expected to differ only in process-local telemetry;
    # handles, positions, values, states, tics and transaction order remain.
    def continuation_projection(events: list[tuple[str, dict[str, str]]]) -> list[tuple[str, tuple[tuple[str, str], ...]]]:
        fields_to_keep = {"tic", "slot", "generation", "stable_id", "value", "state_before", "state_after", "from", "to", "target", "distance_before", "distance_after", "step", "batch", "keep_slot", "keep_generation", "keep_id", "merge_slot", "merge_generation", "merge_id", "accepted", "reason", "old_generation", "old_id", "new_generation", "new_id", "delta"}
        return [(kind, tuple(sorted((key, value) for key, value in row.items() if key in fields_to_keep))) for kind, row in events]
    if continuation_projection(control_suffix) != continuation_projection(restored_suffix):
        result["errors"].append("save/load continuation changed the ordered logical event stream")
    if save_file is None:
        result["errors"].append("engine did not create a P027 savegame")
    result.update({"status": "PASS" if not result["errors"] else "FAIL", "presentation_variants": variants,
                   "proxy_indicator_variants": presentation_variants,
                   "savepoint_validation": savepoint_validation,
                   "restored_validation": restored_validation, "save_exit_code": first_rc, "load_exit_code": load_rc,
                   "save_file": str(save_file) if save_file else None, "evidence": str(evidence)})
    (evidence / "p027-result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8", newline="\n")
    latest = ROOT / "evidence" / "P027" / "latest-result.json"
    latest.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps(result, indent=2, sort_keys=True))
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path)
    parser.add_argument("--seconds", type=float, default=20.0)
    args = parser.parse_args(argv)
    try:
        result = run_probe(package=args.package, seconds=args.seconds)
    except (OSError, ValueError, RuntimeError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    return 0 if result.get("status") == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
