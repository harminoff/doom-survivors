"""Run and validate the P016 profile/run-save persistence investigation.

P016 keeps two stores strictly separate, because a successful engine quicksave
does not prove permanent unlock persistence:

* **profile** - durable across process restarts, carried by archived cvars
  declared in the CVARINFO lump. ZScript cannot declare cvars at all; file scope
  accepts only include/extend/class/mixin/struct/const/enum.
* **run save** - per-run state carrying live entity handles and generations,
  carried by the engine savegame.

The runner exercises both, plus the failure modes the phase requires: a
corrupted payload, a schema mismatch, a simulated failed purchase, a read-only
profile directory, and a second independent profile.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.build import build

STARTUP_RE = re.compile(
    r"DS_P016_STARTUP_READ accepted=(\d+) entities=(-?\d+) hash=(-?\d+) marker=(\d+) persisted_len=(\d+)"
)
WRITE_RE = re.compile(r"DS_P016_WRITE result=(\w+) schema=(\d+) hash=(-?\d+) entities=(\d+) saved=(\d+)")
CORRUPT_RE = re.compile(r"DS_P016_CORRUPT outcome accepted=(\d+)")
SCHEMA_RE = re.compile(r"DS_P016_SCHEMA_BUMP outcome accepted=(\d+)")
PURCHASE_RE = re.compile(r"DS_P016_FAILED_PURCHASE end granted=(\w+) payload_unchanged=(\d+)")
WORLD_RE = re.compile(r"DS_P016_WORLD_LOADED is_save=(\d+) run_marker=(\d+) generation=(\d+)")
RESTORE_RE = re.compile(
    r"DS_P016_RESTORE_PROBE phase_tic=(\d+) marker=(\d+) generation=(\d+) entities=(\d+) started_this_process=(\d+) "
    r"pos=\(([-.\d]+),([-.\d]+),([-.\d]+)\) yaw=([-.\d]+) pitch=([-.\d]+) fov=([-.\d]+) "
    r"attacks=(\d+) offscreen=(\d+) proxies=(\d+)"
)
MAP_TRANSITION_RE = re.compile(
    r"DS_P016_MAP_TRANSITION map=MAP01 count=1 marker=(-?\d+) generation=(-?\d+) "
    r"entities=(-?\d+) hash=(-?\d+)"
)
POST_TRANSITION_RE = re.compile(
    r"DS_P016_RUN_SAVE_RESTORED phase_tic=(\d+) marker=(-?\d+) generation=(-?\d+) "
    r"hash=(-?\d+) entities=(-?\d+)"
)
SOURCE_FACT = ("DS_P016_SOURCE_FACT zscript_cvar_declaration=UNSUPPORTED "
               "durable_store=INVESTIGATED_ARCHIVED_CVAR_ROUTE savegame=ENGINE_SAVEGAME_NONTRANSIENT_FIELDS")
CVARS = ("ds_p016_marker", "ds_p016_profile_id", "ds_p016_payload", "ds_p016_schema_version")
PROFILE_ENTITY_COUNT = 512
# Sentinel returned when the runner terminated the engine at the deadline.
# A bounded probe always leaves the process running, so this is not a failure.
DEADLINE_EXIT_CODE = -9


def signed32(value: int) -> int:
    value &= 0xFFFFFFFF
    return value - 0x100000000 if value >= 0x80000000 else value


def synthetic_payload(base_id: int, generation: int = 1, health: int = 100,
                      count: int = PROFILE_ENTITY_COUNT) -> str:
    values = []
    digest = 0
    for index in range(count):
        entity_id = base_id + index * 7
        entity_health = health + index
        values.append(f",{entity_id}:{generation}:{entity_health}")
        digest = signed32(digest * 31 + entity_id)
        digest = signed32(digest * 31 + generation)
        digest = signed32(digest * 31 + entity_health)
    return f"v1;ids{''.join(values)};hash={digest}"


def config_text(directory: Path, profile_id: str = "", values: dict | None = None) -> str:
    values = values or {}
    marker = values.get("ds_p016_marker", "0")
    payload = values.get("ds_p016_payload", "")
    schema = values.get("ds_p016_schema_version", "1")
    return (
        "[LastRun]\nVersion=230\n[GlobalSettings]\n"
        "vid_defwidth=1280\nvid_defheight=720\nvid_preferbackend=1\n"
        "vid_vsync=false\nvid_maxfps=60\nvid_activeinbackground=true\n"
        "i_pauseinbackground=false\n"  # see run_probe.config_text: focus-loss pause
        "vid_lowerinbackground=false\nscreenblocks=11\n"
        f"screenshot_dir={directory.as_posix()}\n"
        "joy_dinput=false\n"  # see run_probe.config_text: avoids DirectInput boot stall
        "[DoomSurvivors.ConfigOnlyVariables.Mod]\n"
        f"ds_p016_marker={marker}\n"
        f"ds_p016_profile_id={profile_id}\n"
        f"ds_p016_payload={payload}\n"
        f"ds_p016_schema_version={schema}\n"
    )


def archived_values(config: Path) -> dict:
    """Return the persisted ds_p016_* cvar values from a config file."""
    values: dict = {}
    if not config.exists():
        return values
    for line in config.read_text(encoding="utf-8", errors="replace").splitlines():
        for name in CVARS:
            prefix = f"{name}="
            if line.startswith(prefix):
                values[name] = line[len(prefix):]
    return values


def run_engine(executable: Path, package: Path, profile: Path, log_name: str,
               extra: list, timeout: float = 30) -> int:
    """Run one bounded engine process and return its exit code.

    A ``quit`` script normally ends the process first; if the deadline is
    reached the run is terminated and its log is still valid evidence, so a
    timeout is reported rather than raised.
    """
    environment = os.environ.copy()
    environment.pop("DOOMWADDIR", None)
    environment.pop("DOOMWADPATH", None)
    command = [str(executable), "-iwad", str(package.resolve()),
               "-config", str(profile / "config.ini"), "-savedir", str(profile),
               "-noautoload", "-noautoexec", "-noextras", "-stdout",
               "-width", "1280", "-height", "720", "+vid_fullscreen", "false",
               "+vid_vsync", "false", "+vid_maxfps", "60", "+screenblocks", "11",
               "+logfile", log_name] + extra
    with (profile / f"{log_name}.out").open("w", encoding="utf-8") as stream:
        process = subprocess.Popen(command, cwd=profile, env=environment,
                                   stdout=stream, stderr=subprocess.STDOUT)
        try:
            return process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
            return DEADLINE_EXIT_CODE


def read_log(profile: Path, log_name: str) -> str:
    """Return the engine log for a run.

    ``+logfile <name>`` makes the engine write ``log-<name>.txt`` in its working
    directory, so the on-disk name differs from the requested one.
    """
    # The engine rewrites the requested name: "+logfile first.log" is written as
    # "log-first-log.txt", i.e. prefixed with "log-" and with dots turned into
    # dashes. Try the observed form first, then the naive one.
    normalised = log_name.replace(".", "-")
    candidates = (profile / f"log-{normalised}.txt", profile / f"log-{log_name}.txt",
                  profile / log_name)
    for path in candidates:
        if path.exists():
            return path.read_text(encoding="utf-8", errors="replace")
    return ""


def prepare(profile: Path, profile_id: str = "", values: dict | None = None) -> None:
    if profile.exists():
        shutil.rmtree(profile, ignore_errors=True)
    profile.mkdir(parents=True)
    (profile / "config.ini").write_text(
        config_text(profile, profile_id, values), encoding="utf-8", newline="\n")


def validate(profile_log: str, restart_log: str, saved: dict,
             readonly_log: str = "", readonly_before: bytes | None = None,
             readonly_after: bytes | None = None, interrupted_log: str = "",
             profile_b: dict | None = None, first_exit_code: int | None = None,
             load_log: str = "", strict: bool = False) -> dict:
    errors: list = []
    if SOURCE_FACT not in profile_log:
        errors.append("missing the source-fact marker that records how ZScript can persist")
    startup = STARTUP_RE.search(restart_log)
    if startup is None:
        errors.append("missing startup-read marker in the restart run")
        startup_values = None
    else:
        startup_values = {
            "accepted": int(startup.group(1)),
            "entities": int(startup.group(2)),
            "hash": int(startup.group(3)),
            "marker": int(startup.group(4)),
            "persisted_len": int(startup.group(5)),
        }
        # P016-A01: the fresh process must accept and restore the previous run.
        if startup_values["accepted"] != 1:
            errors.append("restart did not accept the persisted profile")
        if startup_values["persisted_len"] <= 0:
            errors.append("restart observed an empty persisted payload")
        if startup_values["entities"] != PROFILE_ENTITY_COUNT:
            errors.append("restart restored unexpected entity count")
        if startup_values["marker"] != 2500:
            errors.append("restart restored an unexpected marker value")
    writes = [{"result": m.group(1), "schema": int(m.group(2)), "hash": int(m.group(3)),
               "entities": int(m.group(4)), "saved": int(m.group(5))}
              for m in WRITE_RE.finditer(profile_log)]
    if not writes:
        errors.append("profile was never written")
    elif not all(row["saved"] == 1 for row in writes):
        errors.append("a profile write reported saved=0")
    if len(writes) < 4:
        errors.append("profile did not survive the minimum repeated-write sequence")
    if len({row["hash"] for row in writes}) < 2:
        errors.append("repeated writes never changed a valid profile revision")
    if writes and not all(row["entities"] == PROFILE_ENTITY_COUNT for row in writes):
        errors.append("profile write did not exercise the realistic synthetic capacity")
    # P016-A02: corruption and version mismatch must be refused, not reinterpreted.
    corrupt = CORRUPT_RE.search(profile_log)
    if corrupt is None:
        errors.append("missing corruption-refusal marker")
    elif int(corrupt.group(1)) != 0:
        errors.append("a hash-mismatched payload was accepted")
    schema = SCHEMA_RE.search(profile_log)
    if schema is None:
        errors.append("missing schema-mismatch marker")
    elif int(schema.group(1)) != 0:
        errors.append("a schema-mismatched payload was accepted")
    if "reason=malformed_or_hash_mismatch" not in profile_log:
        errors.append("corruption was not refused with an explicit reason")
    if "reason=schema_mismatch" not in profile_log:
        errors.append("schema mismatch was not refused with an explicit reason")
    # P016-A03: a failed purchase must not grant the reward or harm the profile.
    purchase = PURCHASE_RE.search(profile_log)
    if purchase is None:
        errors.append("missing failed-purchase marker")
    else:
        if purchase.group(1) != "false":
            errors.append("failed purchase granted its reward")
        if int(purchase.group(2)) != 1:
            errors.append("failed purchase modified the previously valid profile")
    # Persisted profile must carry schema/version metadata.
    if not saved.get("ds_p016_payload", "").startswith("v1;ids"):
        errors.append("persisted payload is missing its schema prefix")
    if saved.get("ds_p016_payload", "").count(",") != PROFILE_ENTITY_COUNT:
        errors.append("persisted payload does not contain the expected entity count")
    if saved.get("ds_p016_schema_version") != "1":
        errors.append("persisted schema version is not the accepted value")
    if saved.get("ds_p016_marker") != "2500":
        errors.append("persisted marker is not the final written value")
    if "VM execution aborted" in profile_log or "Script error" in profile_log:
        errors.append("runtime script failure")
    if strict and not readonly_log:
        errors.append("missing read-only profile evidence")
    if readonly_log:
        if "DS_P016_STARTUP_READ accepted=1" not in readonly_log:
            errors.append("read-only profile did not start from its valid prior state")
        if "DS_P016_WRITE result=SAVE_FAILED" not in readonly_log:
            errors.append("read-only profile did not refuse a durable write")
        if "DS_P016_WRITE result=OK" in readonly_log:
            errors.append("read-only profile reported a successful write")
        if readonly_before is None or readonly_after is None or readonly_before != readonly_after:
            errors.append("read-only profile changed its prior config")
    if strict and not interrupted_log:
        errors.append("missing interrupted-write evidence")
    if interrupted_log:
        if "DS_P016_STARTUP_READ accepted=0" not in interrupted_log:
            errors.append("interrupted profile was not rejected at startup")
        if "reason=malformed_or_hash_mismatch" not in interrupted_log:
            errors.append("interrupted profile lacked an explicit refusal reason")
    if strict and profile_b is None:
        errors.append("missing independent-profile evidence")
    if profile_b is not None:
        if profile_b.get("ds_p016_profile_id") == saved.get("ds_p016_profile_id"):
            errors.append("independent profiles reused the same profile id")
        if profile_b.get("ds_p016_payload") == saved.get("ds_p016_payload"):
            errors.append("independent profiles produced identical payloads")
    if first_exit_code is not None and first_exit_code != DEADLINE_EXIT_CODE:
        errors.append("first process was not terminated at the crash-recovery deadline")
    if strict and not load_log:
        errors.append("missing run-save/map-transition evidence")
    if load_log:
        transition = MAP_TRANSITION_RE.search(load_log)
        if transition is None:
            errors.append("run did not cross the map transition boundary")
        else:
            marker, generation, entities, digest = (int(value) for value in transition.groups())
            if marker < 2500 or generation < 2 or entities != PROFILE_ENTITY_COUNT:
                errors.append("map transition did not preserve run marker, generation, and entities")
            if writes and digest != writes[-1]["hash"]:
                errors.append("map transition did not preserve the logical entity hash")
            post = POST_TRANSITION_RE.search(load_log, transition.end())
            if post is None:
                errors.append("missing post-transition run-state marker")
            else:
                _, post_marker, post_generation, post_hash, post_entities = (
                    int(value) for value in post.groups()
                )
                if (post_marker < marker or post_generation != generation
                        or post_hash != digest or post_entities != entities):
                    errors.append("post-transition run state differs from the carried state")
        if "DS_P016_RENDER_STATE actors=3 attacks=3 offscreen=2 duplicate_actors=0" not in load_log:
            errors.append("run save did not prove exactly one set of presentation actors")
        if "DS_P016_FP_CONTEXT coherent=1" not in load_log:
            errors.append("run save did not prove saved and actual first-person context agree")
        if "DS_P016_MAP_TRANSITION_FP coherent=1" not in load_log:
            errors.append("map transition did not restore coherent first-person context")
        if "adapter_revision=fp-adapter-v1 input_mode=look_relative_wasd logical_window=independent_xy" not in load_log:
            errors.append("run save omitted the selected first-person adapter context")
    return {
        "status": "PASS" if not errors else "FAIL",
        "errors": errors,
        "writes": writes,
        "startup_read": startup_values,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seconds", type=float, default=30, help="per-process timeout")
    parser.add_argument("--no-build", action="store_true", help="reuse the existing package")
    args = parser.parse_args()

    if args.no_build:
        package = ROOT / "build/doom-survivors.ipk3"
        if not package.exists():
            print("FAIL: no package to reuse", file=sys.stderr)
            return 1
    else:
        package = Path(build(ROOT)["package"])
    lock = json.loads((ROOT / "toolchain/lock.json").read_text())
    executable = ROOT / lock["uzdoom"]["executable"]["path"]
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    evidence = ROOT / "evidence/P016" / f"{stamp}-persistence"
    evidence.mkdir(parents=True)
    profiles = ROOT / ".local/probes" / f"{stamp}-p016"
    profile_a = profiles / "profile-a"
    profile_b = profiles / "profile-b"
    profile_ro = profiles / "profile-readonly"
    profile_interrupted = profiles / "profile-interrupted"
    prepare(profile_a, "profile-a")
    prepare(profile_b, "profile-b")
    readonly_values = {
        "ds_p016_marker": "2400",
        "ds_p016_payload": synthetic_payload(17000),
        "ds_p016_schema_version": "1",
    }
    prepare(profile_ro, "profile-readonly", readonly_values)
    interrupted_values = {
        "ds_p016_marker": "2400",
        "ds_p016_payload": "v1;ids,17000:1:100,17007:1",
        "ds_p016_schema_version": "1",
    }
    prepare(profile_interrupted, "profile-interrupted", interrupted_values)

    # Run 1 populates the profile; run 2 is a genuinely fresh process that must
    # restore it. That pair is the P016-A01 durability proof.
    first_rc = run_engine(executable, package, profile_a, "first.log",
                          ["+map", "MAP01"], timeout=args.seconds)
    first_log = read_log(profile_a, "first.log")
    saved = archived_values(profile_a / "config.ini")
    second_rc = run_engine(executable, package, profile_a, "second.log",
                           ["+map", "MAP01"], timeout=args.seconds)
    second_log = read_log(profile_a, "second.log")

    # Failure mode: read-only profile storage must refuse rather than corrupt.
    read_only_note = None
    readonly_before = (profile_ro / "config.ini").read_bytes()
    ro_log = ""
    try:
        os.chmod(profile_ro / "config.ini", stat.S_IREAD)
        ro_rc = run_engine(executable, package, profile_ro, "readonly.log",
                           ["+map", "MAP01"], timeout=args.seconds)
        ro_log = read_log(profile_ro, "readonly.log")
        readonly_after = (profile_ro / "config.ini").read_bytes()
        read_only_note = f"rc={ro_rc} log_bytes={len(ro_log)} config_unchanged={readonly_before == readonly_after}"
    except OSError as exc:
        readonly_after = None
        read_only_note = f"chmod_unavailable: {exc}"

    # An interrupted write is represented by a truncated payload on disk. The
    # fresh process must refuse it explicitly before its normal probe repair.
    interrupted_rc = run_engine(executable, package, profile_interrupted, "interrupted.log",
                                ["+map", "MAP01"], timeout=args.seconds)
    interrupted_log = read_log(profile_interrupted, "interrupted.log")

    # Failure mode: a second profile must be independent of the first.
    third_rc = run_engine(executable, package, profile_b, "other.log",
                          ["+map", "MAP01"], timeout=args.seconds)
    other_values = archived_values(profile_b / "config.ini")

    # Run save: a separate store from the profile.
    save_script = profile_a / "save.cfg"
    save_script.write_text('wait 120; save ds_p016_run "P016 synthetic"; wait 20; quit\n',
                           encoding="utf-8", newline="\n")
    save_rc = run_engine(executable, package, profile_a, "save.log",
                         ["+map", "MAP01", "+exec", save_script.name], timeout=args.seconds)
    saves = sorted(path for path in profile_a.glob("ds_p016_run*") if path.is_file())
    save_file = saves[0] if saves else None
    load_rc = None
    load_log = ""
    if save_file is not None:
        load_script = profile_a / "load.cfg"
        load_script.write_text("wait 35; quit\n", encoding="utf-8", newline="\n")
        # -loadgame takes a save *name* and the engine appends the extension
        # itself (d_main.cpp G_BuildSaveName), so the stem is passed, not the
        # filename. A literal filename fails to resolve and the run would start
        # a fresh game instead of loading.
        load_rc = run_engine(executable, package, profile_a, "load.log",
                             ["-loadgame", save_file.stem, "+exec", load_script.name],
                             timeout=args.seconds)
        load_log = read_log(profile_a, "load.log")

    result = validate(first_log, second_log, saved, ro_log, readonly_before,
                      readonly_after, interrupted_log, other_values, first_rc,
                      load_log, strict=True)
    load_world = WORLD_RE.search(load_log)
    restored = RESTORE_RE.search(load_log)
    result["run_save"] = {
        "save_created": save_file is not None,
        "save_sha256": hashlib.sha256(save_file.read_bytes()).hexdigest() if save_file else None,
        "save_size": save_file.stat().st_size if save_file else None,
        "save_exit_code": save_rc,
        "load_exit_code": load_rc,
        "world_loaded_is_save": int(load_world.group(1)) if load_world else None,
        "resumed_marker": int(load_world.group(2)) if load_world else None,
        "resumed_generation": int(load_world.group(3)) if load_world else None,
        "restored_phase_tic": int(restored.group(1)) if restored else None,
        "restored_marker": int(restored.group(2)) if restored else None,
        "restored_generation": int(restored.group(3)) if restored else None,
        "restored_entities": int(restored.group(4)) if restored else None,
        "restored_process_marker": int(restored.group(5)) if restored else None,
        "restored_position": [float(restored.group(i)) for i in (6, 7, 8)] if restored else None,
        "restored_yaw": float(restored.group(9)) if restored else None,
        "restored_pitch": float(restored.group(10)) if restored else None,
        "restored_fov": float(restored.group(11)) if restored else None,
        "restored_attacks": int(restored.group(12)) if restored else None,
        "restored_offscreen": int(restored.group(13)) if restored else None,
        "restored_proxies": int(restored.group(14)) if restored else None,
    }
    if save_file is None:
        result["errors"].append("engine savegame file was not created")
    # P016-FP01: a load must restore the logical entity state, not start fresh.
    # The engine skips WorldLoaded for restored handlers, so the observation is
    # the transient-flag probe rather than the WorldLoaded hook.
    if restored is None:
        result["errors"].append("load did not report restored run state")
    else:
        if int(restored.group(5)) != 0:
            result["errors"].append("restore probe did not report a restored process")
        if int(restored.group(2)) < 2500:
            result["errors"].append("run save did not resume the serialized marker")
        if int(restored.group(3)) < 2:
            result["errors"].append("run save did not resume the generation counter")
        if int(restored.group(4)) != PROFILE_ENTITY_COUNT:
            result["errors"].append("run save did not restore the logical entities")
        if int(restored.group(12)) != 3 or int(restored.group(13)) != 2 or int(restored.group(14)) != 3:
            result["errors"].append("run save did not restore first-person attacks, offscreen state, and proxies")

    second_profile_isolated = (
        other_values.get("ds_p016_marker") == "2500"
        and other_values.get("ds_p016_profile_id") == "profile-b"
        and other_values.get("ds_p016_payload", "") != saved.get("ds_p016_payload")
        and profile_a != profile_b
    )
    result["failure_modes"] = {
        "corruption_refused": "reason=malformed_or_hash_mismatch" in first_log,
        "schema_mismatch_refused": "reason=schema_mismatch" in first_log,
        "failed_purchase_no_grant": "granted=false" in first_log,
        "failed_purchase_profile_intact": "payload_unchanged=1" in first_log,
        "read_only_storage": read_only_note,
        "read_only_config_unchanged": readonly_before == readonly_after if readonly_after is not None else False,
        "interrupted_write_refused": "DS_P016_STARTUP_READ accepted=0" in interrupted_log,
        "second_profile_independent": second_profile_isolated,
    }
    if not second_profile_isolated:
        result["errors"].append("second profile did not write its own independent state")
    if result["errors"]:
        result["status"] = "FAIL"
    result.update({
        # A bounded probe is terminated at the deadline when no quit script
        # fires, so the runner sentinel is an expected outcome, not a failure.
        "runtime_status": "RUNTIME_PASS" if first_rc in (0, DEADLINE_EXIT_CODE) else "RUNTIME_FAIL",
        "first_exit_code": first_rc,
        "second_exit_code": second_rc,
        "third_exit_code": third_rc,
        "interrupted_exit_code": interrupted_rc,
        "package_sha256": hashlib.sha256(package.read_bytes()).hexdigest(),
        "engine_sha256": lock["uzdoom"]["executable"]["sha256"],
        "source_commit": lock["uzdoom"]["source"]["commit"],
        "archived_cvars": sorted(saved.keys()),
        "persisted_schema_version": saved.get("ds_p016_schema_version"),
        "persisted_marker": saved.get("ds_p016_marker"),
        "profile_entity_count": PROFILE_ENTITY_COUNT,
        "profile_payload_length": len(saved.get("ds_p016_payload", "")),
        "profile_b": other_values,
        "interrupted_profile": str(profile_interrupted),
        "source_parity": "OPEN_ENGINE_PROBE",
        "evidence": str(evidence),
    })
    (evidence / "result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    for name in ("first.log", "second.log", "save.log", "load.log"):
        source = profile_a / f"log-{name.replace('.', '-')}.txt"
        if source.exists():
            (evidence / name).write_text(
                source.read_text(encoding="utf-8", errors="replace"), encoding="utf-8")
    for directory, name in ((profile_b, "other.log"), (profile_ro, "readonly.log"),
                            (profile_interrupted, "interrupted.log")):
        source = directory / f"log-{name.replace('.', '-')}.txt"
        if source.exists():
            (evidence / name).write_text(
                source.read_text(encoding="utf-8", errors="replace"), encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
