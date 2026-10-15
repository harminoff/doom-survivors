"""Run bounded, isolated UZDoom checks; compilation never implies runtime success."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import struct
import sys
import time
import zlib
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.doctor.doctor import inspect


def config_text(directory: Path, max_fps: int = 60, window_width: int = 1280, window_height: int = 720,
                active_in_background: bool = True, vsync: bool = True, video_backend: int = 1) -> str:
    active_value = "true" if active_in_background else "false"
    pause_value = "false" if active_in_background else "true"
    vsync_value = "true" if vsync else "false"
    return f"""[LastRun]
Version=230
[IWADSearch.Directories]
Path=.
[FileSearch.Directories]
Path=.
[GlobalSettings]
vid_fullscreen=false
win_w={window_width}
win_h={window_height}
vid_defwidth=1280
vid_defheight=720
vid_preferbackend={video_backend}
vid_vsync={vsync_value}
vid_maxfps={max_fps}
vid_activeinbackground={active_value}
i_pauseinbackground={pause_value}
vid_lowerinbackground=false
screenblocks=11
screenshot_dir={directory.as_posix()}
joy_dinput=false
    """
    # i_pauseinbackground defaults to true: the game freezes whenever the probe
    # window loses focus (e.g. the user clicks another app), so a scripted run
    # stops mid-way and hits its wall-clock deadline (seen 2026-09-30 as
    # intermittent n2 save/load "-9" timeouts; log stalls until refocused).
    # joy_dinput=false: on 2026-09-27 DirectInput joystick enumeration stalled
    # boot for 10-60 s on the dev host (logs end at I_StartupDirectInputJoystick).
    # Probes never use controllers (controller input is recorded as untested),
    # and this config is isolated per run, so no user setting changes.


def input_proof_text() -> str:
    """Bindings for the isolated physical-input acceptance session."""
    return """bind w \"+forward\"
bind s \"+back\"
bind a \"+moveleft\"
bind d \"+moveright\"
bind mouse1 \"+forward\"
bind escape \"menu_main\"
bind mouse2 \"menu_main\"
bind f12 \"screenshot\"
"""


def png_nonblank(data: bytes) -> bool:
    """Return whether an 8-bit RGB/RGBA PNG contains more than one pixel value."""
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        return False
    offset = 8
    width = height = bit_depth = color_type = None
    compressed = bytearray()
    while offset + 12 <= len(data):
        size = struct.unpack(">I", data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        payload = data[offset + 8:offset + 8 + size]
        offset += 12 + size
        if kind == b"IHDR":
            width, height, bit_depth, color_type = struct.unpack(">IIBB", payload[:10])
        elif kind == b"IDAT":
            compressed.extend(payload)
        elif kind == b"IEND":
            break
    if not width or not height or bit_depth != 8 or color_type not in (2, 6):
        return False
    bytes_per_pixel = 3 if color_type == 2 else 4
    row_size = width * bytes_per_pixel
    try:
        decoded = zlib.decompress(bytes(compressed))
    except zlib.error:
        return False
    if len(decoded) < height * (row_size + 1):
        return False
    previous = bytearray(row_size)
    first_pixel = None
    for row_index in range(height):
        start = row_index * (row_size + 1)
        filter_type = decoded[start]
        encoded = decoded[start + 1:start + 1 + row_size]
        row = bytearray(row_size)
        for i, value in enumerate(encoded):
            left = row[i - bytes_per_pixel] if i >= bytes_per_pixel else 0
            up = previous[i]
            up_left = previous[i - bytes_per_pixel] if i >= bytes_per_pixel else 0
            if filter_type == 0:
                row[i] = value
            elif filter_type == 1:
                row[i] = (value + left) & 255
            elif filter_type == 2:
                row[i] = (value + up) & 255
            elif filter_type == 3:
                row[i] = (value + ((left + up) // 2)) & 255
            elif filter_type == 4:
                estimate = left + up - up_left
                distances = (abs(estimate - left), abs(estimate - up), abs(estimate - up_left))
                predictor = (left, up, up_left)[distances.index(min(distances))]
                row[i] = (value + predictor) & 255
            else:
                return False
        for i in range(0, row_size, bytes_per_pixel):
            pixel = bytes(row[i:i + bytes_per_pixel])
            if first_pixel is None:
                first_pixel = pixel
            elif pixel != first_pixel:
                return True
        previous = row
    return False


def classify(log: str, returncode: int | None, expired: bool, compile_only: bool, map_name: str = "MAP01", completion_marker: str = "DS_RUNTIME_COMPLETE") -> str:
    if "DS_ASSERT_FAIL" in log:
        return "ASSERTION_FAILURE"
    if re.search(r"Script error|Unknown class|Unknown identifier|errors? while parsing", log, re.I):
        return "COMPILE_FAILURE"
    if re.search(r"Execution could not continue|Fatal error|Could not find|not found|does not have a map|No player start|No map MAP", log, re.I):
        return "STARTUP_FAILURE"
    if compile_only:
        if expired:
            return "TIMEOUT"
        # UZDoom 5.0.1 d_main.cpp returns 1337 before video initialization;
        # Windows i_main.cpp deliberately preserves that code for batch -norun.
        return "COMPILE_PASS" if returncode == 1337 else "COMPILE_FAILURE"
    if returncode not in (None, 0):
        return "PROCESS_FAILURE"
    if f"DS_BOOT map={map_name}" in log and completion_marker in log:
        return "RUNTIME_PASS"
    return "TIMEOUT" if expired else "INCOMPLETE"


def run(package: Path, seconds: float, compile_only: bool, interactive: bool = False,
        evidence_phase: str = "P003", max_fps: int = 60, window_width: int = 1280,
        window_height: int = 720, map_name: str = "MAP01", completion_marker: str = "DS_RUNTIME_COMPLETE",
        active_in_background: bool = True, vsync: bool = True, sampler=None,
        startup_commands: list[str] | None = None, video_backend: int = 1) -> dict:
    if not re.fullmatch(r"P\d{3}", evidence_phase):
        raise ValueError("evidence_phase must have the form P###")
    if not 30 <= max_fps <= 1000:
        raise ValueError("max_fps must be between 30 and 1000")
    if not 320 <= window_width <= 7680 or not 240 <= window_height <= 4320:
        raise ValueError("window dimensions are outside the supported bounded probe range")
    if video_backend not in (0, 1):
        raise ValueError("video_backend must be 0 (OpenGL) or 1 (Vulkan)")
    doctor = inspect(ROOT, ROOT / "toolchain/lock.json")
    if doctor["status"] != "PASS":
        raise ValueError("Toolchain verification failed: " + "; ".join(doctor["errors"]))
    if not package.is_file():
        raise ValueError(f"Missing package: {package}")
    lock = json.loads((ROOT / "toolchain/lock.json").read_text())
    executable = ROOT / lock["uzdoom"]["executable"]["path"]
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    evidence = ROOT / "evidence" / evidence_phase / f"{stamp}-{package.stem}"
    evidence.mkdir(parents=True)
    profile = ROOT / ".local/probes" / evidence.name
    profile.mkdir(parents=True)
    configuration = profile / "config.ini"
    configuration.write_text(
        config_text(evidence, max_fps, window_width, window_height, active_in_background, vsync, video_backend),
        encoding="utf-8", newline="\n",
    )
    input_proof = None
    if interactive:
        # The intentionally minimal config has no inherited game bindings. Keep the
        # acceptance controls explicit and isolated; mouse1 provides a held physical
        # input for automation clients whose keyboard API only emits tap events.
        input_proof = profile / "input-proof.cfg"
        binding_text = input_proof_text()
        input_proof.write_text(binding_text, encoding="utf-8", newline="\n")
        (evidence / input_proof.name).write_text(binding_text, encoding="utf-8", newline="\n")
    # Console logfile commands tokenize their arguments; a relative filename avoids
    # reparsing the spaces in the project path. The process cwd is already isolated.
    logfile = profile / "log-engine-log.txt"
    command = [str(executable), "-iwad", str(package.resolve()), "-config", str(configuration),
               "-savedir", str(profile), "-noautoload", "-noautoexec", "-noextras", "-stdout"]
    if compile_only:
        command += ["-norun", "-errorlog", "engine.log"]
    else:
        command += ["-width", str(window_width), "-height", str(window_height), "+vid_fullscreen", "false",
                    "+vid_activeinbackground", "true" if active_in_background else "false", "+vid_lowerinbackground", "false",
                    "+vid_maxfps", str(max_fps), "+screenblocks", "11", "+enablescriptscreenshot", "true",
                    "+screenshot_dir", ".", "+logfile", "engine.log"]
        if input_proof is not None:
            command += ["+exec", input_proof.name]
        # Each pair is a normal UZDoom console command and value. Keep the
        # values in the argv list so scenario selection is explicit in the
        # captured command and cannot be confused with host-side simulation.
        if startup_commands is not None:
            command += list(startup_commands)
        command += ["+map", map_name]
    environment = os.environ.copy()
    environment.pop("DOOMWADDIR", None)
    environment.pop("DOOMWADPATH", None)
    started = time.monotonic()
    expired = False
    with (evidence / "process.log").open("w", encoding="utf-8") as output:
        process = subprocess.Popen(command, cwd=profile, env=environment, stdout=output, stderr=subprocess.STDOUT)
        print(f"PID={process.pid} evidence={evidence}", flush=True)
        try:
            while process.poll() is None:
                log = logfile.read_text(encoding="utf-8", errors="replace") if logfile.exists() else ""
                log += (evidence / "process.log").read_text(encoding="utf-8", errors="replace")
                if time.monotonic() - started >= seconds:
                    expired = True
                    break
                if sampler is not None:
                    sampler(process.pid, time.monotonic() - started)
                if not interactive and not compile_only:
                    status = classify(log, None, False, False, map_name, completion_marker)
                    if status in ("ASSERTION_FAILURE", "COMPILE_FAILURE", "STARTUP_FAILURE") or (status == "RUNTIME_PASS" and any(profile.glob("*.png"))):
                        break
                time.sleep(0.1)
        finally:
            natural_exit = process.poll()
            if natural_exit is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
    log = logfile.read_text(encoding="utf-8", errors="replace") if logfile.exists() else ""
    (evidence / "engine.log").write_text(log, encoding="utf-8")
    captures = []
    for capture in sorted(profile.glob("*.png")):
        data = capture.read_bytes()
        (evidence / capture.name).write_bytes(data)
        width, height = struct.unpack(">II", data[16:24]) if data[:8] == b"\x89PNG\r\n\x1a\n" else (None, None)
        captures.append({"file": capture.name, "sha256": hashlib.sha256(data).hexdigest(), "observed_width": width, "observed_height": height, "nonblank": png_nonblank(data)})
    process_log = (evidence / "process.log").read_text(encoding="utf-8", errors="replace")
    verdict = classify(log + "\n" + process_log, natural_exit, expired, compile_only, map_name, completion_marker)
    if verdict == "RUNTIME_PASS" and not captures:
        verdict = "CAPTURE_MISSING"
    result = {
        "status": verdict, "package": str(package), "package_sha256": hashlib.sha256(package.read_bytes()).hexdigest(),
        "engine_sha256": lock["uzdoom"]["executable"]["sha256"], "source_commit": lock["uzdoom"]["source"]["commit"],
        "command": command, "elapsed_seconds": round(time.monotonic() - started, 3), "natural_exit_code": natural_exit,
        "terminated_by_runner": natural_exit is None, "deadline_reached": expired, "evidence": str(evidence),
        "compile_only": compile_only, "interactive": interactive,
        "input_proof_config": input_proof.name if input_proof is not None else None,
        "physical_input_verified": False,
        "active_in_background": active_in_background,
        "requested_max_fps": max_fps,
        "requested_window_width": window_width,
        "requested_window_height": window_height,
        "requested_video_backend": video_backend,
        "captures": captures,
        "execution_mode": "compile_only" if compile_only else "realtime",
        "logical_accelerated": False,
        "visual_capture": bool(captures),
        "startup_commands": list(startup_commands or []),
    }
    (evidence / "result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2), flush=True)
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, default=ROOT / "build/doom-survivors.ipk3")
    parser.add_argument("--seconds", type=float, default=30)
    parser.add_argument("--compile-only", action="store_true")
    parser.add_argument("--interactive", action="store_true", help="keep runtime open until bounded timeout for physical-input checks")
    parser.add_argument("--evidence-phase", default="P003", help="evidence directory label in the form P###")
    parser.add_argument("--max-fps", type=int, default=60, help="requested render-frame cap (30-1000)")
    parser.add_argument("--width", type=int, default=1280, help="requested isolated window width")
    parser.add_argument("--height", type=int, default=720, help="requested isolated window height")
    parser.add_argument("--map", default="MAP01", help="generated map to load (MAP01-MAP05)")
    args = parser.parse_args()
    if not 1 <= args.seconds <= 600:
        parser.error("--seconds must be between 1 and 600")
    try:
        result = run(args.package, args.seconds, args.compile_only, args.interactive, args.evidence_phase, args.max_fps, args.width, args.height, args.map)
        raise SystemExit(0 if result["status"] in ("COMPILE_PASS", "RUNTIME_PASS") else 1)
    except (OSError, ValueError, subprocess.SubprocessError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        raise SystemExit(1)
