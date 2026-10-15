"""Build and independently validate the P028 level-up bridge.

The package emits the authoritative play/UI event trace. This runner derives
the expected queue, RNG rotation, restricted pool and shared-stat effects from
the frozen contract, then rejects incomplete or marker-only logs. Camera and
telemetry variants are compared against the same logical transaction stream;
the no-input run is expected to remain paused until its bounded deadline.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.build import build
from tools.run_probe import run

RUN_TICS = 72
START_RNG = 730201
POOL = (1, 2, 3)


def flat(log: str) -> str:
    return re.sub(r"\s+", " ", log)


def fields(body: str) -> dict[str, str]:
    return {key: value for key, value in re.findall(r"([A-Za-z_][A-Za-z0-9_]*)=([^\s]+)", body)}


def rows(log: str, kind: str) -> list[dict[str, str]]:
    text = flat(log)
    pattern = re.compile(rf"DS_P028_{re.escape(kind)}\s+(.*?)(?=DS_[A-Za-z0-9_]+|$)")
    return [fields(match.group(1)) for match in pattern.finditer(text)]


def int32(value: int) -> int:
    value &= 0xFFFFFFFF
    return value - 0x100000000 if value >= 0x80000000 else value


def next_rng(state: int) -> int:
    value = int32(state)
    value = int32(value ^ int32(value << 13))
    value = int32(value ^ (value >> 17))
    value = int32(value ^ int32(value << 5))
    return 1831565813 if value == 0 else value


def positive_mod(value: int, divisor: int) -> int:
    remainder = value % divisor
    return remainder if remainder >= 0 else remainder + divisor


def expected_rng_rows() -> list[tuple[int, int, int]]:
    state = START_RNG
    result = []
    for level in (2, 3):
        after = next_rng(state)
        result.append((state, after, positive_mod(after, len(POOL))))
        state = after
    return result


def logical_stream(log: str) -> list[tuple[str, dict[str, str]]]:
    text = flat(log)
    found: list[tuple[int, str, dict[str, str]]] = []
    for kind in ("DRAFT_ENQUEUE", "SNAPSHOT", "DRAFT_OPEN", "CONFIRM_APPLIED", "APPLY", "RELEASE_SENT", "NEUTRAL_FRAME", "POST_COMBAT"):
        for match in re.finditer(rf"DS_P028_{kind}\s+(.*?)(?=DS_[A-Za-z0-9_]+|$)", text):
            found.append((match.start(), kind, fields(match.group(1))))
    found.sort(key=lambda item: item[0])
    return [(kind, row) for _, kind, row in found]


def validate(log: str, *, expected_variant: int = 0, expected_telemetry: int = 1,
             pause_only: bool = False) -> dict[str, Any]:
    text = flat(log)
    errors: list[str] = []
    required = (
        "DS_P028_BOOT map=MAP14 ticrate=35 authority=DSP028LevelUpProgression xp_authority=P027_EXPERIENCE_LEDGER pool=RESTRICTED_DEVELOPMENT_POOL source_build=1.16.107 steam_build=25016043",
        "DS_P028_RULES thresholds=5000,15000,25000 threshold_provenance=ONLINE_REPORTED_CURRENT xp_units=P027_MILLIUNITS queue=ASCENDING_HEAD_ONLY draft_rng=ONE_STEP_PER_ENQUEUE offers=THREE legal_ids=WHIP,POWER,ARMOR capped=WHIP_8_PASSIVES_5 effects=SHARED_INVENTORY_STATS",
        "DS_P028_PAUSE_RULES menu=CUSTOM_MODAL ui_time=ADVANCES run_stage_enemy_attack_movement_pickup_progression=FROZEN deadline_phase=PRESERVED backlog=0 native_input=CONSUMED escape=NO_SELECTION",
        "DS_P028_FIXTURE level=1 xp_milliunits=0 whip_rank=1 power_rank=0 armor_rank=0 character_hp=120000 character_armor=1 character_might_milli=1000",
    )
    for marker in required:
        if marker not in text:
            errors.append(f"missing marker: {marker}")
    if re.search(r"VM execution aborted|Script error|Unknown identifier|Execution could not continue|Fatal error", text, re.I):
        errors.append("engine reported a script/runtime failure")

    camera = rows(log, "CAMERA")
    expected_pose = {0: (0, 0, 90), 1: (90, 0, 90), 2: (180, 0, 90), 3: (270, 0, 90), 4: (0, 22, 115)}.get(expected_variant)
    if expected_pose is None or not camera:
        errors.append("camera trace is missing")
    elif tuple(int(camera[0].get(name, "-999")) for name in ("yaw", "pitch", "fov")) != expected_pose:
        errors.append(f"camera pose does not match variant {expected_variant}")
    if camera and camera[0].get("role") != "PRESENTATION_ONLY":
        errors.append("camera trace is not presentation-only")

    xp = rows(log, "XP_COLLECT")
    if len(xp) != 1:
        errors.append("expected exactly one XP collection transaction")
    elif any(xp[0].get(key) != value for key, value in {
        "amount": "20000", "before_xp": "0", "after_xp": "0", "before_level": "1",
        "after_level": "3", "crossed": "2", "remainder_milliunits": "0",
    }.items()):
        errors.append("XP threshold/remainder arithmetic changed")

    enqueues = rows(log, "DRAFT_ENQUEUE")
    if len(enqueues) != 2:
        errors.append(f"expected two queued drafts, observed {len(enqueues)}")
    expected_rng = expected_rng_rows()
    for index, row in enumerate(enqueues[:2]):
        before, after, rotation = expected_rng[index]
        expected = {"queue_index": str(index), "target_level": str(index + 2), "rng_before": str(before),
                    "rng_after": str(after), "rotation": str(rotation), "draw_once": "1"}
        for key, value in expected.items():
            if row.get(key) != value:
                errors.append(f"draft {index} {key} is {row.get(key)}, expected {value}")
        if row.get("rng_stream") != "draft":
            errors.append(f"draft {index} did not use the draft RNG stream")
    if len(enqueues) >= 2 and [row.get("target_level") for row in enqueues] != ["2", "3"]:
        errors.append("queued target levels are not ascending")

    snapshots = rows(log, "SNAPSHOT")
    if len(snapshots) < (1 if pause_only else 2):
        errors.append("play-to-UI snapshots are missing")
    expected_snapshot_ids = ([2, 3, 1], [3, 1, 2])
    for index, row in enumerate(snapshots[:(1 if pause_only else 2)]):
        ids = [int(row.get(f"offer{i}_id", "-1")) for i in range(3)]
        if ids != list(expected_snapshot_ids[index]):
            errors.append(f"snapshot {index} offer rotation is {ids}, expected {expected_snapshot_ids[index]}")
        if set(ids) != set(POOL) or len(set(ids)) != 3:
            errors.append(f"snapshot {index} contains an illegal or duplicate restricted offer")
        if row.get("offer_count") != "3":
            errors.append(f"snapshot {index} does not expose exactly three offers")
        if row.get("token") != str(index) or row.get("target_level") != str(index + 2):
            errors.append(f"snapshot {index} token/head mismatch")
    if any(row.get("offer0_id") not in {"1", "2", "3"} for row in snapshots):
        errors.append("an advertised offer is outside the restricted pool")

    if pause_only:
        pause = rows(log, "PAUSE_SAMPLE")
        if not pause:
            errors.append("no-input run did not emit a pause sample")
        else:
            for row in pause:
                for key in ("ui_time_advances", "unchanged"):
                    if row.get(key) != "1":
                        errors.append(f"pause sample {key} invariant is missing")
                expected_clock = {"world_tic": "1", "stage_clock": "1", "enemy_clock": "1", "attack_clock": "1",
                                  "movement_clock": "1", "pickup_clock": "1", "progression_clock": "1",
                                  "deadline_numerator": "189"}
                for key, value in expected_clock.items():
                    if row.get(key) != value:
                        errors.append("no-input modal clock snapshot changed")
        if rows(log, "APPLY") or rows(log, "CONFIRM_APPLIED") or rows(log, "COMPLETE"):
            errors.append("no-input run applied a draft or resumed unexpectedly")
        return {"status": "PASS" if not errors else "FAIL", "errors": errors,
                "pause_samples": len(pause), "logical_stream": logical_stream(log)}

    applies = rows(log, "APPLY")
    confirms = rows(log, "CONFIRM_APPLIED")
    if len(applies) != 2 or len(confirms) != 2:
        errors.append("each queued head must have exactly one authoritative apply and confirmation")
    expected_applies = ((2, 1, 1, 1, 1100), (3, 1, 2, 1, 1100))
    for index, row in enumerate(applies[:2]):
        wanted_id, wanted_rank, wanted_armor, wanted_weapon, wanted_might = expected_applies[index]
        for key, value in {"offer_id": ("POWER" if wanted_id == 2 else "ARMOR"), "rank": str(wanted_rank),
                           "target_level": str(index + 2), "queue_remaining": str(1 - index),
                           "armor": str(wanted_armor), "weapon_level": str(wanted_weapon),
                           "might_milli": str(wanted_might), "transaction_once": "1"}.items():
            if row.get(key) != value:
                errors.append(f"apply {index} {key} is {row.get(key)}, expected {value}")
    if any(row.get("authority") != "SHARED_INVENTORY_STATS" for row in applies):
        errors.append("upgrade bypassed the shared inventory/stat seam")
    if len(rows(log, "CONFIRM_REJECT")) < 2:
        errors.append("held/repeated confirmation rejection is missing")
    if len(rows(log, "RELEASE_SENT")) != 2 or len(rows(log, "NEUTRAL_FRAME")) != 2:
        errors.append("neutral release boundary is incomplete")
    pause = rows(log, "PAUSE_SAMPLE")
    if expected_telemetry and not pause:
        errors.append("modal pause sample is missing")
    elif pause:
        for row in pause:
            for key in ("ui_time_advances", "unchanged"):
                if row.get(key) != "1":
                    errors.append(f"pause sample {key} invariant is missing")
            expected_clock = {"world_tic": "1", "stage_clock": "1", "enemy_clock": "1", "attack_clock": "1",
                              "movement_clock": "1", "pickup_clock": "1", "progression_clock": "1",
                              "deadline_numerator": "189"}
            if any(row.get(key) != value for key, value in expected_clock.items()):
                errors.append("simulation clock advanced during modal")

    combat = rows(log, "POST_COMBAT")
    if not combat or combat[-1].get("power_rank") != "1" or combat[-1].get("armor_rank") != "1" or combat[-1].get("armor") != "2" or combat[-1].get("might_milli") != "1100":
        errors.append("post-draft combat/stat snapshot does not reflect both shared upgrades")
    complete = rows(log, "COMPLETE")
    if len(complete) != 1:
        errors.append("missing or duplicate completion marker")
    elif any(complete[0].get(key) != value for key, value in {
        "tics": str(RUN_TICS), "level": "3", "xp_remainder": "0", "drafts_enqueued": "2",
        "drafts_applied": "2", "backlog": "0", "modal_input": "EDGE_TRIGGERED",
        "physical_input_seen": "UI_OWNED", "camera_variant": str(expected_variant),
    }.items()):
        errors.append("completion marker disagrees with canonical state")
    traces = rows(log, "TRACE")
    if expected_telemetry and not traces:
        errors.append("telemetry-enabled run emitted no canonical trace")
    if not expected_telemetry and traces:
        errors.append("telemetry-disabled run emitted trace rows")
    if not rows(log, "FRAMEBUFFER_CAPTURE"):
        errors.append("framebuffer capture marker is missing")
    return {"status": "PASS" if not errors else "FAIL", "errors": errors,
            "enqueue_count": len(enqueues), "snapshot_count": len(snapshots),
            "apply_count": len(applies), "logical_stream": logical_stream(log),
            "completion": complete[-1] if complete else None}


def run_one(package: Path, *, mode: str = "demo", variant: int = 0,
            telemetry: int = 1, seconds: float = 10.0) -> dict[str, Any]:
    runtime = run(package, seconds, False, False, "P028", 60, 1280, 720,
                  map_name="MAP14", completion_marker="DS_P028_COMPLETE",
                  active_in_background=True, vsync=False,
                  startup_commands=["+set", "ds_p028_mode", mode,
                                    "+set", "ds_p028_camera_variant", str(variant),
                                    "+set", "ds_p028_telemetry", str(telemetry)])
    evidence = Path(runtime["evidence"])
    log_path = evidence / "engine.log"
    log = log_path.read_text(encoding="utf-8", errors="replace") if log_path.exists() else ""
    result = validate(log, expected_variant=variant, expected_telemetry=telemetry,
                      pause_only=mode == "no_input")
    result.update({"mode": mode, "variant": variant, "telemetry": telemetry,
                   "runtime": runtime, "engine_log": str(log_path),
                   "package_sha256": runtime.get("package_sha256")})
    if mode == "no_input":
        if runtime.get("status") not in {"TIMEOUT", "INCOMPLETE"}:
            result["errors"].append(f"no-input runtime status was {runtime.get('status')}")
    elif runtime.get("status") != "RUNTIME_PASS":
        result["errors"].append(f"runtime status was {runtime.get('status')}")
    elif not runtime.get("captures") or not all(item.get("nonblank") for item in runtime["captures"]):
        result["errors"].append("required nonblank framebuffer capture is missing")
    result["status"] = "PASS" if not result["errors"] else "FAIL"
    (evidence / "p028-result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return result


def run_probe(*, package: Path | None = None, seconds: float = 10.0) -> dict[str, Any]:
    if not 6.0 <= seconds <= 120.0:
        raise ValueError("seconds must be between 6 and 120")
    if package is None:
        package = Path(build(ROOT, room_spec=ROOT / "maps/source/p028-levelup/room.json")["package"])
    package = Path(package)
    compile_runtime = run(package, seconds, True, False, "P028", 60, 1280, 720,
                          map_name="MAP14", completion_marker="DS_P028_COMPLETE",
                          active_in_background=True, vsync=False)
    if compile_runtime.get("status") != "COMPILE_PASS":
        return {"status": "FAIL", "classification": "P028_PACKAGED_UZDOOM_LEVELUP", "errors": ["compile gate failed"], "compile": compile_runtime}
    compile_sha = compile_runtime["package_sha256"]
    runs = [run_one(package, variant=index, seconds=seconds) for index in range(5)]
    runs.append(run_one(package, telemetry=0, seconds=seconds))
    runs.append(run_one(package, mode="no_input", seconds=8.0))
    errors = [f"run {index}: {error}" for index, result in enumerate(runs) for error in result["errors"]]
    if any(result.get("package_sha256") != compile_sha for result in runs):
        errors.append("runtime package differs from compile gate")
    baseline = runs[0]
    for index, result in enumerate(runs[1:5], 1):
        if result.get("logical_stream") != baseline.get("logical_stream"):
            errors.append(f"camera variant {index} changed the logical bridge stream")
    if runs[5].get("logical_stream") != baseline.get("logical_stream"):
        errors.append("telemetry setting changed the logical bridge stream")
    result = {"status": "PASS" if not errors else "FAIL", "classification": "P028_PACKAGED_UZDOOM_LEVELUP",
              "package": str(package), "package_sha256": hashlib.sha256(package.read_bytes()).hexdigest(),
              "compile": compile_runtime, "runs": runs, "errors": errors}
    evidence_dir = ROOT / "evidence" / "P028"
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
    parser.add_argument("--pause-only", action="store_true")
    args = parser.parse_args(argv)
    try:
        if args.validate_log:
            result = validate(args.validate_log.read_text(encoding="utf-8", errors="replace"),
                              expected_variant=args.variant, expected_telemetry=args.telemetry,
                              pause_only=args.pause_only)
        else:
            result = run_probe(package=args.package, seconds=args.seconds)
    except (OSError, ValueError, RuntimeError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    return 0 if result.get("status") == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
