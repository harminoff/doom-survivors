"""Run a bounded UZDoom multiplayer capability probe.

The probe distinguishes a demonstrated two-process network session from the
separate local split-view and physical-device requirements. A network slot or
two windows never upgrades the latter to a couch co-op claim.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "build/doom-survivors.ipk3"

WORLD_RE = re.compile(r"DS_P017_WORLD map=MAP01 client=(\d+)")
CAP_RE = re.compile(
    r"DS_P017_CAPABILITY client=(\d+) active_players=(\d+) shared_population=(\d+) "
    r"own_x=([-\d.]+) own_y=([-\d.]+) own_yaw=([-\d.]+) yaw_delta=([-\d.]+) "
    r"cmd_yaw=(-?\d+) cmd_pitch=(-?\d+) cmd_forward=(-?\d+) cmd_side=(-?\d+)"
)
VIEW_RE = re.compile(r"DS_P017_VIEW client=(\d+) player=(\d+) x=([-\d.]+) y=([-\d.]+) yaw=([-\d.]+)")
COMPLETE_RE = re.compile(r"DS_P017_PROBE_COMPLETE client=(\d+)")
MENU_RESULT_RE = re.compile(r"DS_P017_MENU_PAUSE_RESULT before=(-?\d+) after=(-?\d+) changed=(\d+)")
DEADLINE_EXIT_CODE = -9


def config_text(directory: Path) -> str:
    return f"""[LastRun]
Version=230
[GlobalSettings]
vid_fullscreen=false
win_w=960
win_h=540
vid_defwidth=960
vid_defheight=540
vid_preferbackend=1
vid_vsync=false
vid_maxfps=60
vid_activeinbackground=true
i_pauseinbackground=false
vid_lowerinbackground=false
screenblocks=11
screenshot_dir={directory.as_posix()}
joy_dinput=false
"""


def script_text(role: str) -> str:
    if role == "single":
        return "wait 90; quit\n"
    if role == "client":
        # This is a command-driven input check for the client process only. It
        # does not claim ownership of a physical second controller.
        return "wait 40\nturn180\nwait 1000\n"
    return "wait 1000; quit\n"


def log_path(profile: Path) -> Path:
    return profile / "log-engine-log.txt"


def read_log(profile: Path) -> str:
    candidates = (log_path(profile), profile / "log-engine.txt", profile / "engine.log")
    for path in candidates:
        if path.exists():
            return path.read_text(encoding="utf-8", errors="replace")
    return ""


def command(executable: Path, package: Path, profile: Path, role: str, script: Path) -> list[str]:
    args = [
        str(executable), "-iwad", str(package.resolve()), "-config", str(profile / "config.ini"),
        "-savedir", str(profile), "-noautoload", "-noautoexec", "-noextras", "-stdout",
        "-width", "960", "-height", "540", "+vid_fullscreen", "false",
        "+vid_vsync", "false", "+vid_activeinbackground", "true", "+vid_maxfps", "60",
        "+screenblocks", "11", "+logfile", "engine.log", "+exec", script.name,
    ]
    if role == "host":
        args += ["-host", "2", "+map", "MAP01"]
    elif role == "client":
        args += ["-join", "127.0.0.1", "+map", "MAP01"]
    else:
        args += ["+map", "MAP01"]
    return args


def launch(executable: Path, package: Path, profile: Path, role: str) -> subprocess.Popen:
    script = profile / f"{role}.cfg"
    script.write_text(script_text(role), encoding="utf-8", newline="\n")
    process_log = profile / "process.log"
    stream = process_log.open("w", encoding="utf-8")
    process = subprocess.Popen(
        command(executable, package, profile, role, script), cwd=profile,
        env={k: v for k, v in os.environ.items() if k not in {"DOOMWADDIR", "DOOMWADPATH"}},
        stdout=stream, stderr=subprocess.STDOUT,
    )
    process._p017_stream = stream  # type: ignore[attr-defined]
    return process


def stop(process: subprocess.Popen, timeout: float = 5.0) -> int | None:
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=timeout)
            result = DEADLINE_EXIT_CODE
        else:
            result = DEADLINE_EXIT_CODE
    else:
        result = process.returncode
    stream = getattr(process, "_p017_stream", None)
    if stream is not None:
        stream.close()
    return result


def run_process(executable: Path, package: Path, profile: Path, role: str,
                seconds: float, wait_for: str | None = None) -> int | None:
    process = launch(executable, package, profile, role)
    started = time.monotonic()
    while process.poll() is None and time.monotonic() - started < seconds:
        log = read_log(profile)
        if wait_for and wait_for in log:
            break
        time.sleep(0.1)
    return stop(process)


def prepare(profile: Path) -> None:
    profile.mkdir(parents=True, exist_ok=False)
    (profile / "config.ini").write_text(config_text(profile), encoding="utf-8", newline="\n")


def parse_capability(log: str) -> dict | None:
    match = CAP_RE.search(log)
    if match is None:
        return None
    return {
        "client": int(match.group(1)), "active_players": int(match.group(2)),
        "shared_population": int(match.group(3)), "own_x": float(match.group(4)),
        "own_y": float(match.group(5)), "own_yaw": float(match.group(6)),
        "yaw_delta": float(match.group(7)), "cmd_yaw": int(match.group(8)),
        "cmd_pitch": int(match.group(9)), "cmd_forward": int(match.group(10)),
        "cmd_side": int(match.group(11)),
    }


def validate(single_log: str, host_log: str, client_log: str,
             host_exit: int | None = None, client_exit: int | None = None) -> dict:
    errors: list[str] = []
    single_cap = parse_capability(single_log)
    host_cap = parse_capability(host_log)
    client_cap = parse_capability(client_log)
    if WORLD_RE.search(single_log) is None or single_cap is None or COMPLETE_RE.search(single_log) is None:
        errors.append("single-client baseline did not complete its capability marker")
    if single_cap is not None and single_cap["active_players"] < 1:
        errors.append("single-client baseline reported no active player")
    if "Script error" in single_log or "VM execution aborted" in single_log:
        errors.append("single-client runtime script failure")
    menu_result = MENU_RESULT_RE.search(single_log)
    if menu_result is None:
        menu_verdict = "UNTESTED_NO_MENU_STATE_MARKER"
    elif menu_result.group(3) == "1":
        menu_verdict = "DEMONSTRATED_MENU_STATE_CHANGE"
    else:
        menu_verdict = "UNTESTED_MENU_COMMAND_DID_NOT_CHANGE_STATE"

    network_logs_present = bool(host_log or client_log)
    if not network_logs_present:
        errors.append("network attempt produced no retained host or client log")
    if host_cap is None and client_cap is None:
        network_verdict = "UNSUPPORTED_OR_UNAVAILABLE"
    elif host_cap is None or client_cap is None:
        network_verdict = "PARTIAL_CLIENT_START"
    elif host_cap["active_players"] >= 2 and client_cap["active_players"] >= 2:
        network_verdict = "DEMONSTRATED_TWO_CLIENTS"
    else:
        network_verdict = "NETWORK_SLOT_NOT_DEMONSTRATED"

    shared_verdict = "UNTESTED"
    if host_cap is not None and client_cap is not None:
        if host_cap["shared_population"] == 3 and client_cap["shared_population"] == 3:
            shared_verdict = "DEMONSTRATED_SINGLE_SHARED_FIXTURE"
        else:
            shared_verdict = "FAILED_SHARED_POPULATION_INVARIANT"
            errors.append("two-client run did not observe one shared three-entity fixture")

    host_views = {int(m[1]): (float(m[2]), float(m[3]), float(m[4])) for m in VIEW_RE.findall(host_log)}
    client_views = {int(m[1]): (float(m[2]), float(m[3]), float(m[4])) for m in VIEW_RE.findall(client_log)}
    process_views = (
        host_cap is not None and client_cap is not None
        and host_cap["client"] != client_cap["client"]
        and host_views == client_views and len(host_views) >= 2
        and host_views.get(host_cap["client"]) != host_views.get(client_cap["client"])
    )
    capabilities = {
        "local_split_view": "UNTESTED_NO_SPLIT_FRAMEBUFFER_EVIDENCE",
        "local_second_device_ownership": "UNTESTED_NO_COMPATIBLE_CONTROLLER",
        "network_two_client_processes": network_verdict,
        "network_shared_population": shared_verdict,
        "network_independent_process_views": "DEMONSTRATED_PROCESS_VIEWS_ONLY" if process_views else "UNTESTED",
        "network_command_input": "DEMONSTRATED" if client_cap is not None and client_cap["yaw_delta"] != 0 else "UNTESTED_COMMAND_DID_NOT_CHANGE_STATE",
        "menu_pause_routing": menu_verdict,
        "online_platform_services": "EXTERNAL_EULA_BLOCKED_UNTESTED",
    }
    if host_exit is not None and host_exit not in (0, DEADLINE_EXIT_CODE):
        errors.append(f"host process failed with exit code {host_exit}")
    if client_exit is not None and client_exit not in (0, DEADLINE_EXIT_CODE):
        errors.append(f"client process failed with exit code {client_exit}")
    return {
        "status": "PASS" if not errors else "FAIL",
        "errors": errors,
        "capabilities": capabilities,
        "single_capability": single_cap,
        "host_capability": host_cap,
        "client_capability": client_cap,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seconds", type=float, default=18)
    parser.add_argument("--package", type=Path, default=PACKAGE)
    args = parser.parse_args()
    package = args.package if args.package.is_absolute() else ROOT / args.package
    if not package.is_file():
        print(json.dumps({"status": "FAIL", "errors": [f"missing package: {package}"]}, indent=2))
        return 1
    lock = json.loads((ROOT / "toolchain/lock.json").read_text(encoding="utf-8"))
    executable = ROOT / lock["uzdoom"]["executable"]["path"]
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    evidence = ROOT / "evidence/P017" / f"{stamp}-multiplayer"
    profiles = ROOT / ".local/probes" / f"{stamp}-p017"
    evidence.mkdir(parents=True)
    profiles.mkdir(parents=True)
    single = profiles / "single"
    host = profiles / "host"
    client = profiles / "client"
    for profile in (single, host, client):
        prepare(profile)

    single_exit = run_process(executable, package, single, "single", args.seconds)
    single_log = read_log(single)
    host_process = launch(executable, package, host, "host")
    time.sleep(1.5)
    client_process = launch(executable, package, client, "client")
    network_started = time.monotonic()
    while (host_process.poll() is None or client_process.poll() is None) and time.monotonic() - network_started < args.seconds:
        if parse_capability(read_log(host)) is not None and parse_capability(read_log(client)) is not None:
            break
        time.sleep(0.1)
    host_exit = stop(host_process)
    client_exit = stop(client_process)
    host_log = read_log(host)
    client_log = read_log(client)
    result = validate(single_log, host_log, client_log, host_exit, client_exit)
    result.update({
        "runtime_status": "RUNTIME_PASS" if result["status"] == "PASS" else "RUNTIME_FAIL",
        "single_exit_code": single_exit, "host_exit_code": host_exit, "client_exit_code": client_exit,
        "package": str(package), "package_sha256": hashlib.sha256(package.read_bytes()).hexdigest(),
        "engine_sha256": lock["uzdoom"]["executable"]["sha256"],
        "source_commit": lock["uzdoom"]["source"]["commit"],
        "evidence": str(evidence),
        "profiles": str(profiles),
        "reference_inventory": {
            "locked_reference_build": "1.16.107 / 25016043",
            "local_coop": "OBSERVED_MENU_AND_METADATA_CONTROLLER_JOIN_REASSIGNMENT",
            "online": "EULA_PRESENT_NOT_ACCEPTED_CREATE_JOIN_INVITE_LOBBY_ID_METADATA_ONLY",
        },
    })
    for name, content in (("single.log", single_log), ("host.log", host_log), ("client.log", client_log)):
        (evidence / name).write_text(content, encoding="utf-8")
    (evidence / "result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
